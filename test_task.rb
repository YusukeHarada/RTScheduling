require 'minitest/autorun'

$logs = []
$result = []
require_relative 'Task'

# ===========================================================
# Task クラスの単体テスト
# ===========================================================
class TestTask < Minitest::Test
  def test_initialize_period
    t = Task.new(10, 3, 0)
    assert_equal 10, t.period
  end

  def test_initialize_exe_time
    t = Task.new(10, 3, 0)
    assert_equal 3, t.exeTime
  end

  def test_initialize_id
    t = Task.new(10, 3, 5)
    assert_equal 5, t.id
  end

  def test_initial_deadline_is_minus_one
    t = Task.new(10, 3, 0)
    assert_equal(-1, t.deadline)
  end

  def test_initial_remaining_time_is_minus_one
    t = Task.new(10, 3, 0)
    assert_equal(-1, t.remainingTime)
  end
end

# ===========================================================
# TaskManager#queueSort の単体テスト
# ===========================================================
class TestQueueSort < Minitest::Test
  def setup
    @mgr = TaskManager.new
  end

  def test_rm_sorts_by_period_ascending
    t0 = Task.new(12, 1, 0)
    t1 = Task.new(4,  1, 1)
    t2 = Task.new(8,  1, 2)
    @mgr.queueSort([t0, t1, t2], RM)
    assert_equal [4, 8, 12], [t0, t1, t2].sort_by(&:period).map(&:period)
    # sort! で元の配列が変更されていることも確認
    q = [t0, t1, t2]
    @mgr.queueSort(q, RM)
    assert_equal [4, 8, 12], q.map(&:period)
  end

  def test_rm_single_task_unchanged
    t0 = Task.new(6, 2, 0)
    q = [t0]
    @mgr.queueSort(q, RM)
    assert_equal [t0], q
  end

  def test_rm_already_sorted_unchanged
    t0 = Task.new(4,  1, 0)
    t1 = Task.new(8,  1, 1)
    t2 = Task.new(12, 1, 2)
    q = [t0, t1, t2]
    @mgr.queueSort(q, RM)
    assert_equal [4, 8, 12], q.map(&:period)
  end

  def test_rm_sorts_by_period_not_deadline
    t0 = Task.new(6,  1, 0)
    t1 = Task.new(10, 1, 1)
    t0.deadline = 100
    t1.deadline = 1  # デッドラインは短いが period は長い
    q = [t1, t0]
    @mgr.queueSort(q, RM)
    # period の小さい t0 が先頭になるべき
    assert_equal 6, q.first.period
  end

  def test_edf_sorts_by_deadline_ascending
    t0 = Task.new(6, 1, 0); t0.deadline = 20
    t1 = Task.new(4, 1, 1); t1.deadline = 5
    t2 = Task.new(8, 1, 2); t2.deadline = 15
    q = [t0, t1, t2]
    @mgr.queueSort(q, EDF)
    assert_equal [5, 15, 20], q.map(&:deadline)
  end

  def test_edf_single_task_unchanged
    t0 = Task.new(6, 2, 0); t0.deadline = 10
    q = [t0]
    @mgr.queueSort(q, EDF)
    assert_equal [t0], q
  end

  def test_edf_sorts_by_deadline_not_period
    t0 = Task.new(4,  1, 0); t0.deadline = 30
    t1 = Task.new(12, 1, 1); t1.deadline = 8
    q = [t0, t1]
    @mgr.queueSort(q, EDF)
    # deadline の短い t1 が先頭
    assert_equal 8, q.first.deadline
  end
end

# ===========================================================
# TaskManager#activateTask の単体テスト
# ===========================================================
class TestActivateTask < Minitest::Test
  def setup
    @mgr = TaskManager.new
  end

  def test_remaining_time_equals_exe_time
    t = Task.new(10, 4, 0)
    @mgr.activateTask(t, 0)
    assert_equal 4, t.remainingTime
  end

  def test_deadline_equals_time_plus_period_at_zero
    t = Task.new(10, 4, 0)
    @mgr.activateTask(t, 0)
    assert_equal 10, t.deadline
  end

  def test_deadline_equals_time_plus_period_nonzero
    t = Task.new(10, 4, 0)
    @mgr.activateTask(t, 20)
    assert_equal 30, t.deadline
  end

  def test_deadline_uses_period_not_exe_time
    # deadline = time + period であり、time + exeTime ではない
    t = Task.new(10, 4, 0)
    @mgr.activateTask(t, 5)
    assert_equal 15, t.deadline   # 5 + 10
    refute_equal 9, t.deadline    # 5 + 4 ではない
  end

  def test_activate_overwrites_previous_state
    t = Task.new(8, 3, 0)
    @mgr.activateTask(t, 0)
    @mgr.activateTask(t, 8)  # 2周目
    assert_equal 3,  t.remainingTime
    assert_equal 16, t.deadline
  end
end

# ===========================================================
# TaskManager#terminateTask の単体テスト
# ===========================================================
class TestTerminateTask < Minitest::Test
  def setup
    @mgr = TaskManager.new
    $logs = []
  end

  def test_no_miss_when_remaining_zero
    t = Task.new(10, 3, 0); t.remainingTime = 0
    @mgr.terminateTask(t, 10)
    assert_equal 0, @mgr.instance_variable_get(:@deadlineMissCnt)
  end

  def test_miss_increments_when_remaining_positive
    t = Task.new(10, 3, 0); t.remainingTime = 2
    @mgr.terminateTask(t, 10)
    assert_equal 1, @mgr.instance_variable_get(:@deadlineMissCnt)
  end

  def test_over_count_adds_remaining_time
    t = Task.new(10, 3, 0); t.remainingTime = 2
    @mgr.terminateTask(t, 10)
    assert_equal 2, @mgr.instance_variable_get(:@deadlineOverCnt)
  end

  def test_remaining_time_reset_to_minus_one
    t = Task.new(10, 3, 0); t.remainingTime = 2
    @mgr.terminateTask(t, 10)
    assert_equal(-1, t.remainingTime)
  end

  def test_deadline_reset_to_minus_one
    t = Task.new(10, 3, 0); t.remainingTime = 2; t.deadline = 10
    @mgr.terminateTask(t, 10)
    assert_equal(-1, t.deadline)
  end

  def test_multiple_misses_accumulate
    t = Task.new(10, 5, 0)
    t.remainingTime = 2
    @mgr.terminateTask(t, 10)
    t.remainingTime = 3
    @mgr.terminateTask(t, 20)
    assert_equal 2, @mgr.instance_variable_get(:@deadlineMissCnt)
    assert_equal 5, @mgr.instance_variable_get(:@deadlineOverCnt)
  end
end

# ===========================================================
# TaskManager#calcHyperPeriod の単体テスト
# ===========================================================
class TestCalcHyperPeriod < Minitest::Test
  def setup
    @mgr = TaskManager.new
    $logs = []
    $result = []
  end

  def test_single_task_returns_its_period
    t0 = Task.new(12, 2, 0)
    assert_equal 12, @mgr.calcHyperPeriod([t0])
  end

  def test_two_coprime_periods
    # LCM(4, 5) = 20
    t0 = Task.new(4, 1, 0)
    t1 = Task.new(5, 1, 1)
    assert_equal 20, @mgr.calcHyperPeriod([t0, t1])
  end

  def test_two_periods_with_common_factor
    # LCM(4, 6) = 12
    t0 = Task.new(4, 1, 0)
    t1 = Task.new(6, 1, 1)
    assert_equal 12, @mgr.calcHyperPeriod([t0, t1])
  end

  def test_two_equal_periods
    # LCM(6, 6) = 6
    t0 = Task.new(6, 1, 0)
    t1 = Task.new(6, 1, 1)
    assert_equal 6, @mgr.calcHyperPeriod([t0, t1])
  end

  def test_three_tasks_set1
    # LCM(6, 8, 12) = 24
    t0 = Task.new(6,  2, 0)
    t1 = Task.new(8,  2, 1)
    t2 = Task.new(12, 4, 2)
    assert_equal 24, @mgr.calcHyperPeriod([t0, t1, t2])
  end

  def test_three_tasks_set2
    # LCM(4, 5, 6) = 60
    t0 = Task.new(4, 1, 0)
    t1 = Task.new(5, 1, 1)
    t2 = Task.new(6, 3, 2)
    assert_equal 60, @mgr.calcHyperPeriod([t0, t1, t2])
  end
end

# ===========================================================
# TaskManager#createUnformalRandom の単体テスト
# ===========================================================
class TestCreateUnformalRandom < Minitest::Test
  def setup
    @mgr = TaskManager.new
  end

  def test_returns_float
    assert_kind_of Float, @mgr.createUnformalRandom
  end

  def test_value_in_range_0_to_1
    200.times do
      r = @mgr.createUnformalRandom
      assert r >= 0.0 && r < 1.0, "期待値 [0.0, 1.0)、実際: #{r}"
    end
  end
end

# ===========================================================
# スケジューリングシミュレーションの統合テスト
#
# テスト用タスクセット:
#   Set1: task(6,2,0), task(8,2,1), task(12,4,2)
#         CPU利用率 = 2/6 + 2/8 + 4/12 ≈ 0.917、ハイパー周期=24
#   Set2: task(4,1,0), task(5,1,1), task(6,3,2)
#         CPU利用率 = 1/4 + 1/5 + 3/6 = 0.95、ハイパー周期=60
# ===========================================================
class TestSchedulingIntegration < Minitest::Test
  def setup
    $logs = []
    $result = []
  end

  def make_taskset1
    [Task.new(6,2,0), Task.new(8,2,1), Task.new(12,4,2)]
  end

  def make_taskset2
    [Task.new(4,1,0), Task.new(5,1,1), Task.new(6,3,2)]
  end

  # --- Task set1 RM: デッドラインミスなし ---

  def test_rm_taskset1_no_deadline_misses
    result = TaskManager.new.simulate(make_taskset1, RM)
    assert_equal 0, result[:deadlineMissCnt],
      "RM / TaskSet1 (U≈0.917): デッドラインミスは発生しないはず"
    assert_equal 0, result[:deadlineOverCnt]
  end

  def test_rm_taskset1_hyper_period
    result = TaskManager.new.simulate(make_taskset1, RM)
    assert_equal 24, result[:hyperPeriod]
  end

  def test_rm_taskset1_execution_count_per_task
    result = TaskManager.new.simulate(make_taskset1, RM)
    et = result[:executedTasks]
    # task0: period=6, exeTime=2 → 4周期 × 2 = 8スロット
    assert_equal 8, et.count(0), "task0 の実行スロット数が不正"
    # task1: period=8, exeTime=2 → 3周期 × 2 = 6スロット
    assert_equal 6, et.count(1), "task1 の実行スロット数が不正"
    # task2: period=12, exeTime=4 → 2周期 × 4 = 8スロット
    assert_equal 8, et.count(2), "task2 の実行スロット数が不正"
    # 残りアイドル: 24 - 22 = 2スロット
    assert_equal 2, et.count(-1), "アイドルスロット数が不正"
  end

  def test_rm_taskset1_correct_first_6_slots
    # RM: 最短周期のtask0(p=6)が最高優先度 → t=0,1 に実行
    # 続いてtask1(p=8) → t=2,3、task2(p=12) → t=4,5
    result = TaskManager.new.simulate(make_taskset1, RM)
    et = result[:executedTasks]
    assert_equal [0, 0, 1, 1, 2, 2], et[0, 6],
      "RM: 最初の6スロットの実行順序が不正"
  end

  def test_rm_taskset1_idle_at_end
    result = TaskManager.new.simulate(make_taskset1, RM)
    et = result[:executedTasks]
    assert_equal(-1, et[22], "t=22 はアイドルのはず")
    assert_equal(-1, et[23], "t=23 はアイドルのはず")
  end

  # --- Task set1 EDF: デッドラインミスなし ---

  def test_edf_taskset1_no_deadline_misses
    result = TaskManager.new.simulate(make_taskset1, EDF)
    assert_equal 0, result[:deadlineMissCnt],
      "EDF / TaskSet1: デッドラインミスは発生しないはず"
  end

  def test_edf_taskset1_execution_count_per_task
    result = TaskManager.new.simulate(make_taskset1, EDF)
    et = result[:executedTasks]
    assert_equal 8, et.count(0), "EDF: task0 の実行スロット数が不正"
    assert_equal 6, et.count(1), "EDF: task1 の実行スロット数が不正"
    assert_equal 8, et.count(2), "EDF: task2 の実行スロット数が不正"
    assert_equal 2, et.count(-1), "EDF: アイドルスロット数が不正"
  end

  # --- Task set2 EDF: U=0.95 < 1.0 → EDFは最適、デッドラインミスなし ---

  def test_edf_taskset2_no_deadline_misses
    result = TaskManager.new.simulate(make_taskset2, EDF)
    assert_equal 0, result[:deadlineMissCnt],
      "EDF / TaskSet2 (U=0.95): EDF最適性より、デッドラインミスはゼロのはず"
  end

  def test_edf_taskset2_total_execution_count
    result = TaskManager.new.simulate(make_taskset2, EDF)
    et = result[:executedTasks]
    # task0: 60/4 * 1 = 15スロット
    assert_equal 15, et.count(0), "EDF TaskSet2: task0 の実行数が不正"
    # task1: 60/5 * 1 = 12スロット
    assert_equal 12, et.count(1), "EDF TaskSet2: task1 の実行数が不正"
    # task2: 60/6 * 3 = 30スロット
    assert_equal 30, et.count(2), "EDF TaskSet2: task2 の実行数が不正"
    # アイドル: 60 - 57 = 3スロット
    assert_equal 3, et.count(-1), "EDF TaskSet2: アイドルスロット数が不正"
  end

  # --- Task set2 RM: バグ検出テスト ---
  # 【潜在バグ】デッドラインミス発生時、タスクが readyTasks に二重登録される。
  # t=6 で task2(period=6, exeTime=3) がミスを起こすと、同一オブジェクトが
  # 「新規活性化」と「実行中タスクの退避」の両方で readyTasks に追加される。
  # 結果としてtask2が1周期内に exeTime=3 を超えて実行される。

  def test_rm_taskset2_no_task_runs_more_than_exe_time_per_period
    result = TaskManager.new.simulate(make_taskset2, RM)
    et = result[:executedTasks]
    hp = 60

    # task0: period=4, exeTime=1
    (hp / 4).times do |p|
      window = et[p * 4, 4]
      count  = window.count(0)
      assert count <= 1,
        "[BUG] task0 が周期#{p}（スロット#{p*4}〜#{p*4+3}）で #{count} 回実行 (最大1回のはず)"
    end

    # task1: period=5, exeTime=1
    (hp / 5).times do |p|
      window = et[p * 5, 5]
      count  = window.count(1)
      assert count <= 1,
        "[BUG] task1 が周期#{p}（スロット#{p*5}〜#{p*5+4}）で #{count} 回実行 (最大1回のはず)"
    end

    # task2: period=6, exeTime=3
    # デッドラインミス時の二重登録バグがあると、この周期で4回以上実行される
    (hp / 6).times do |p|
      window = et[p * 6, 6]
      count  = window.count(2)
      assert count <= 3,
        "[BUG] task2 が周期#{p}（スロット#{p*6}〜#{p*6+5}）で #{count} 回実行 (最大3回のはず)\n" \
        "原因: デッドラインミス発生時に readyTasks へ同一タスクが二重登録される不具合"
    end
  end

  def test_rm_taskset2_no_invalid_task_ids
    # executedTasks に含まれるIDは -1(アイドル) か 0,1,2 のみのはず
    result = TaskManager.new.simulate(make_taskset2, RM)
    valid = [-1, 0, 1, 2]
    result[:executedTasks].each_with_index do |id, t|
      assert valid.include?(id),
        "[BUG] 時刻#{t} に無効なタスクID #{id} が記録された"
    end
  end

  def test_rm_taskset2_has_at_least_one_deadline_miss
    # RM十分条件: 3*(2^(1/3)-1) ≈ 0.78。Task set2 の U=0.95 > 0.78 なので
    # RM では少なくとも1回のデッドラインミスが発生するはず
    result = TaskManager.new.simulate(make_taskset2, RM)
    assert result[:deadlineMissCnt] >= 1,
      "RM / TaskSet2 (U=0.95): RM十分条件を超えているのでミスが期待されるが 0 だった"
  end
end

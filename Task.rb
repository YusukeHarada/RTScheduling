###################
# Yusuke Harada
# Information Engineering 
# 2015/06/23
###################
# Selectable Scheduler
RM = 0
EDF = 1
# Task
class Task
	# 初期化
	def initialize(period, exeTime,id)
		@id = id
		@period = period
		@exeTime = exeTime
		@deadline = -1
		@remainingTime = -1
	end
	# タスク情報の表示
	def show()
		$logs << "id:#{@id}, period:#{@period}, exeTime:#{@exeTime}\n"
	end
	attr_accessor :exeTime, :period, :id, :deadline, :remainingTime
end

# TaskManager
class TaskManager
	# 一様乱数生成のための初期値設定
	def initialize()
		@a = 12869
		@c = 6925
		@m = 16384
		# @x = 1210
		@x = rand(1400)
		@deadlineMissCnt = 0
		@deadlineOverCnt = 0
	end
	# タスクキューのソート（RMとEDF用）
	def queueSort(queue,scheduler)
		if scheduler == RM
			queue.sort!{|a,b|
				a.period <=> b.period
			}
		elsif scheduler == EDF
			queue.sort!{|a,b|
				a.deadline <=> b.deadline
			}
		end
	end
	# タスクの残り実行時間と絶対デッドラインを設定
	def activateTask(task, time)
		task.remainingTime = task.exeTime
		task.deadline = time + task.period
	end
	# タスクのデッドラインミスとデッドラインオーバを測定とタスクの終了
	def terminateTask(task, time)
		if task.remainingTime > 0
			@deadlineMissCnt += 1
			@deadlineOverCnt += task.remainingTime
			$logs << "#{task.id}:デッドラインミス\n"
		end
		task.remainingTime = -1
		task.deadline = -1
	end
	# タスクを生成
	def createTasks(number,cpu)
		@number = number
		tasks = []
		# RM可能性判定式
		# U = sum(Ci:タスクの実行時間/Ti:タスクの周期)<= m(2^(1/m:タスク数)-1 )
		sufficientCondition = 1.0	 * number * (2**(1.0/number)-1)
		# p sufficientCondition
		mng = TaskManager.new()
		loop {
			u = 0.0
			# タスク数分タスクを生成
			number.times do |i|
				tasks << Task.new(
					(	(mng.createUnformalRandom()*10).to_int + 5), 
					(	(mng.createUnformalRandom()*10).to_int + 1),
						i
				)
				u += 1.0*tasks[i].exeTime/(1.0*tasks[i].period)
			end
			# 条件内の場合はタスクセット決定
			case cpu
			when 0
				if 0.6 <= u && u < 0.7
					$result << "CPU利用率:#{u}\n"
					break
				end
			when 1
				if 0.7 <= u && u < 0.8
					$result << "CPU利用率:#{u}\n"
					break
				end
			when 2
				if 0.8 <= u && u < 0.9
					$result << "CPU利用率:#{u}\n"
					break
				end
			when 3
				if 0.9 <= u && u < 1.0
					$result << "CPU利用率:#{u}\n"
					break
				end
			when 4
				if 1.0 <= u && u < 1.1
					$result << "CPU利用率:#{u}\n"
					break
				end
			when 5
				if 1.1 <= u && u < 1.2
					$result << "CPU利用率:#{u}\n"
					break
				end
			when 6
				if u < sufficientCondition
					$result << "CPU利用率:#{u}\n"
					break
				end
			end
			# 再度タスクセットを構成
			# p tasks
			# print "再生成中\n"
			tasks = []
		}
		mng = nil
		#### タスクテスト用 ####
		# tasks = []
		# @number = 3
		# Test Task set1
		# tasks << Task.new(6,2,0)
		# tasks << Task.new(8,2,1)
		# tasks << Task.new(12,4,2)
		# Test Task set2
		# tasks << Task.new(4,1,0)
		# tasks << Task.new(5,1,1)
		# tasks << Task.new(6,3,2)
		return tasks
	end
	# 一様乱数を生成
	def createUnformalRandom()
		@x = (@a * @x + @c) % @m
		return 1.0 * @x / @m
	end
	# 指数乱数生成
	def exponentialRandom()
		nlambda = 0.4
		r = createUnformalRandom()
		return (-1/nlambda * Math.log(r)).to_int
	end
	# タスク間のハイパー周期を算出
	def calcHyperPeriod(tasks)
		@hyperPeriod = -1
		if tasks.length == 1
			@hyperPeriod = tasks[0].period
			return @hyperPeriod
		end
		i = 0
		for t in tasks do
			if(i==0)
				@hyperPeriod = (t.period).lcm(tasks[i+1].period)
			else
				@hyperPeriod = @hyperPeriod.lcm(t.period)
			end
			i+=1
		end
		return @hyperPeriod
	end
	# スケジューリングの実行結果をコンソールへ表示
	def showResult(tasks, etasks)
		30.times do	$result << "="; end
		$result << "\n"
		for t in tasks
			$result << "task#{t.id}(exeTime:#{t.exeTime}, period:#{t.period})\n"
		end
		30.times do	$result << "="; end
		$result << "\n"
		@number.times do |i|
			$result << "task#{i}:"
			@hyperPeriod.times do |time|
				if etasks[time] == i
					$result << "#{i} "
				elsif etasks[time] == -1
					$result << "* "
				else
					$result << "- "
				end
			end
			$result << "\n"
		end
		$result << "deadline miss:#{@deadlineMissCnt}\n"
		$result << "deadline over:#{@deadlineOverCnt}\n"
	end
end

##### Test Codes #####
# タスク実行管理オブジェクトの生成
$logs = []
$result = []
$result << "\n"
manager = TaskManager.new()
# 初期化
scheduler = -1
taskNum = -1
cpu = -1
# スケジューラの選択と生成タスク数の入力方法選択
# コマンドライン引数 or プログラム内にて入力
if ARGV.size != 0
	# コマンドラインを用いる
	scheduler = ARGV.shift.to_i
	taskNum = ARGV.shift.to_i
	cpu = ARGV.shift.to_i
else
	# プログラム内にて入力
	print "スケジューリングアルゴリズムを選択してください\n"
	print "RM:0 / EDF:1\n"
	scheduler = gets().to_i
	print "スケジューリングするタスク数を入力してください\n"
	taskNum = gets().to_i
	print "CPU利用率を選択したください"
	print "60%:0, 70%:1, 80%:2, 90%:3, 100%:4, 110%:5, 十分条件:6\n"
	cpu = gets().to_i.to_int
end
# タスク生成
tasks = manager.createTasks(taskNum,cpu)
# 生成タスクの確認
# for t in tasks do
# 	t.show()
# end
# 初期化
hyperPeriod = manager.calcHyperPeriod(tasks)
$result << "hyper period = #{hyperPeriod}\n"
readyTasks = []
endTime = -1
runningTask = nil
doesSchedule = false
$logs << "start execution\n"
executedTasks = []

# ハイパー周期の間実行
hyperPeriod.times do |time|
	#タスクの周期開始時にタスク生成
	for t in tasks do
		if time % t.period == 0
			# 残り実行時間と絶対デッドラインを設定
			$logs << "activate task #{t.id}\n"
			if t.remainingTime > 0
				manager.terminateTask(t,time)
			end
			manager.activateTask(t,time)
			doesSchedule = true
			readyTasks << t
			if runningTask != nil
				readyTasks << runningTask
				runningTask = nil
			end
			readyTasks = manager.queueSort(readyTasks,scheduler)
		end
	end
	if doesSchedule
		highPriTask = readyTasks.shift()
		if runningTask == nil
			runningTask = highPriTask
		elsif highPriTask != runningTask
			$logs << "プリエンプション発生\n"
			readyTasks << runningTask
			readyTasks = manager.queueSort(readyTasks,scheduler)
			runningTask = highPriTask
		end
		doesSchedule = false
	end
	#タスクの実行
	$logs << "【time#{time}】 "
	if runningTask!=nil
		runningTask.remainingTime -= 1
		$logs << "RunTsk:#{runningTask.id}, dLine#{runningTask.deadline}, remainTime#{runningTask.remainingTime}\n"
		executedTasks << runningTask.id
	else
		executedTasks << -1 
		$logs << "idle\n"
	end
	if runningTask != nil
		if runningTask.remainingTime == 0
			$logs << "terminate task:#{runningTask.id}\n"
			manager.terminateTask(runningTask, time)
			if readyTasks.size > 0
				runningTask = readyTasks.shift()
				$logs << "nextTask:#{runningTask.id}\n"
			else
				runningTask = nil
				$logs << "empty queue\n"
			end
		end
	end
end
if runningTask != nil && runningTask.remainingTime > 0 && runningTask.remainingTime != -1
	manager.terminateTask(runningTask,hyperPeriod-1)
end
$logs << "finish execution!!\n"
manager.showResult(tasks, executedTasks)
$result << "\n"

for l in $logs do print l end
for r in $result do print r end

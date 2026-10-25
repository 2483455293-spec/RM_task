extends Node

# ==========================================
# 比赛阶段枚举
# ==========================================
enum MatchPhase {READY, RUNNING, PAUSED, END}

# ==========================================
# 配置参数 (由 ConfigManager 注入)
# ==========================================
var match_duration_s: float = 420.0
var base_max_hp: int = 1000

# ==========================================
# 运行状态
# ==========================================
var phase: MatchPhase = MatchPhase.READY
var remaining_s: float = 0.0
var base_hp: int = base_max_hp
var last_second: int = -1

# ==========================================
# 信号
# ==========================================
signal time_updated(remain_sec: float)
signal base_hp_changed(new_hp: int)
signal match_ended(is_win: bool)
signal pause_state_changed(is_paused: bool)

# ==========================================
# 生命周期
# ==========================================
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	match_duration_s = ConfigManager.get_match("match_duration_s", 420.0)
	base_max_hp = ConfigManager.get_buildings("base_max_hp", 1000)

		
	# 初始化血量
	base_hp = base_max_hp
	
	start_match()

# ==========================================
# 状态切换
# ==========================================
func start_match():
	phase = MatchPhase.RUNNING
	remaining_s = match_duration_s
	base_hp = base_max_hp
	last_second = -1
	get_tree().paused = false 
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # 确保开局捕获鼠标
	emit_signal("time_updated", remaining_s)
	emit_signal("base_hp_changed", base_hp)
	print("【比赛开始】时长: ", match_duration_s, "秒")

func pause_match():
	if phase == MatchPhase.RUNNING:
		phase = MatchPhase.PAUSED
		get_tree().paused = true 
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # 暂停时释放鼠标，方便点击 UI
		emit_signal("pause_state_changed", true)
		print("【比赛暂停】")

func resume_match():
	if phase == MatchPhase.PAUSED:
		phase = MatchPhase.RUNNING
		get_tree().paused = false 
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # 继续时重新捕获鼠标
		emit_signal("pause_state_changed", false)
		print("【比赛继续】")

func end_match(is_win: bool):
	if phase == MatchPhase.END:
		return
	phase = MatchPhase.END
	get_tree().paused = true 
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # 结束时释放鼠标
	emit_signal("match_ended", is_win)
	print("【比赛结束】胜负：", "胜利" if is_win else "失败")

func reset_match():
	phase = MatchPhase.READY
	remaining_s = 0.0
	base_hp = base_max_hp
	last_second = -1
	get_tree().paused = false 
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # 重置时捕获鼠标
	emit_signal("base_hp_changed", base_hp)
	print("【比赛重置】")

# ==========================================
# 主循环
# ==========================================
func _physics_process(delta: float) -> void:
	if phase != MatchPhase.RUNNING:
		return
	
	remaining_s = maxf(remaining_s - delta, 0.0)
	
	var current_second = int(ceil(remaining_s))
	if current_second != last_second:
		last_second = current_second
		emit_signal("time_updated", remaining_s)
	
	if remaining_s <= 0.0:
		var is_win = base_hp > 0
		end_match(is_win)

# ==========================================
# 统一处理按键 (P暂停, R重置)
# ==========================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# P键：暂停/继续
		if event.keycode == KEY_P:
			if phase == MatchPhase.RUNNING:
				pause_match()
			elif phase == MatchPhase.PAUSED:
				resume_match()
				
		# R键：重置（无论在游戏中、暂停中、还是结束后都可以按）
		elif event.keycode == KEY_R:
			print("【系统】按下 R 键，重置游戏...")
			# 先解除暂停并恢复鼠标状态，再重载场景
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_tree().reload_current_scene()

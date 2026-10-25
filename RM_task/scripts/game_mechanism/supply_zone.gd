extends Area3D

# ==========================================
# 导出与配置参数
# ==========================================
@export var zone_faction: String = "blue" 

var heal_percentage_per_sec: float = 0.1 
var ammo_per_sec: int = 10         

var current_infantry: CharacterBody3D = null
var is_currently_full: bool = false

@onready var timer: Timer = $Timer

signal supply_message(show_ui: bool, text: String, color: Color)

func _ready():
	heal_percentage_per_sec = ConfigManager.get_gameplay("supply_heal_percentage", 0.1)
	ammo_per_sec = ConfigManager.get_gameplay("supply_ammo", 10)


	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	timer.timeout.connect(_on_timer_tick)
	timer.stop() 

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Infantry" or body.is_in_group("infantry"):
		var body_faction = body.get("faction")
		
		if body_faction != null and body_faction != zone_faction:
			supply_message.emit(true, "警告：敌方补给区，无法补给！", Color.RED)
			return
			
		current_infantry = body
		is_currently_full = false
		timer.start()
		supply_message.emit(true, "进入补给区", Color.GREEN)

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Infantry" or body.is_in_group("infantry"):
		timer.stop()
		if body == current_infantry:
			current_infantry = null
			is_currently_full = false
		
		supply_message.emit(false, "", Color.WHITE)

func _on_timer_tick() -> void:
	if not current_infantry: return
	
	if current_infantry.has_method("is_in_combat") and current_infantry.is_in_combat():
		supply_message.emit(true, "战斗中无法补给！", Color.RED)
		return 
	
	var success = current_infantry.resupply_tick(heal_percentage_per_sec, ammo_per_sec)
	
	if not success:
		if not is_currently_full:
			is_currently_full = true
			supply_message.emit(true, "补给完毕，状态已满！", Color.CYAN)
	else:
		if is_currently_full:
			is_currently_full = false
		supply_message.emit(true, "正在补给中...", Color.GREEN)

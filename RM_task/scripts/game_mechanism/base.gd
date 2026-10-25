extends Node3D

# ==========================================
# 基础属性
# ==========================================
var max_hp: float = 5000
var armor_open_threshold: float = 2000 # 装甲展开的血量阈值

var current_hp: float
var is_destroyed: bool = false
var armor_opened: bool = false 

# 基地无敌状态（默认开启）
var is_invincible: bool = true 

@export var linked_outpost: Node3D 

# ==========================================
# 信号
# ==========================================
signal hp_changed(current, max)
signal outpost_destroyed
signal shield_hit # 护盾受到攻击的信号，用于通知 HUD 闪烁

# ==========================================
# 节点引用
# ==========================================
@onready var a1 = $a1
@onready var a2 = $a2
@onready var a3 = $a3

func _ready() -> void:
	max_hp = ConfigManager.get_buildings("base_max_hp", 5000)
	armor_open_threshold = ConfigManager.get_buildings("base_armor_open_hp", 2000)

		
	current_hp = max_hp
	hp_changed.emit(current_hp, max_hp)
	
	# 监听前哨站的死亡信号，一旦前哨站死了，解除无敌
	if linked_outpost and linked_outpost.has_signal("outpost_destroyed"):
		linked_outpost.outpost_destroyed.connect(_on_outpost_destroyed)
	else:
		push_warning("请检查是否把对应的前哨站节点拖入了 linked_outpost 变量槽！")

# ==========================================
# 前哨站被摧毁，解除基地无敌
# ==========================================
func _on_outpost_destroyed() -> void:
	is_invincible = false
	print("【系统提示】己方前哨站被摧毁！基地无敌护盾消失！")

# ==========================================
# 受击逻辑
# ==========================================
func take_damage(amount: float) -> void:
	# 如果基地还在无敌状态，拒绝扣血，并发出信号
	if is_invincible:
		print("基地护盾激活中，免疫伤害！")
		shield_hit.emit() # 通知 HUD 闪烁护盾标签
		return
	
	if is_destroyed: return
	
	current_hp = maxf(current_hp - amount, 0.0)
	hp_changed.emit(current_hp, max_hp)
	print("基地受击，当前血量：", current_hp)
	
	if current_hp <= armor_open_threshold and not armor_opened:
		_open_armor()
	
	# 检查是否被摧毁
	if current_hp <= 0.0:
		_die()

# ==========================================
# 装甲板展开逻辑（3秒线性运动）
# ==========================================
func _open_armor() -> void:
	armor_opened = true
	print("基地血量低于 ", armor_open_threshold, "，装甲板开始展开！")
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_LINEAR)
	
	tween.tween_property(a1, "position", Vector3(-0.16, -0.2, -0.28), 3.0)
	tween.tween_property(a2, "position", Vector3(-0.16, -0.2, 0.28), 3.0)
	tween.tween_property(a3, "position", Vector3(0.35, -0.2, 0), 3.0)

# ==========================================
# 死亡逻辑（全灭）
# ==========================================
func _die() -> void:
	is_destroyed = true
	print("基地已被摧毁！")
	
	# 关闭所有装甲板的受击检测
	for armor_node in $armor.get_children():
		if armor_node is Area3D:
			armor_node.set_deferred("monitoring", false)
			
	# 递归关闭整个基地里的所有自发光灯光
	_turn_off_all_lights(self)
	
	# 触发全局事件
	outpost_destroyed.emit()

# ==========================================
# 辅助函数：递归关闭所有灯光
# ==========================================
func _turn_off_all_lights(node: Node) -> void:
	if node is MeshInstance3D:
		# 获取材质并尝试关闭发光
		var mat = node.get_active_material(0) as StandardMaterial3D
		if mat:
			# 复制独立材质，防止影响其他物体
			if not node.material_override:
				node.material_override = mat.duplicate()
			if node.material_override is StandardMaterial3D:
				node.material_override.emission_enabled = false
				
	# 递归遍历所有子节点
	for child in node.get_children():
		_turn_off_all_lights(child)

extends Control

@onready var map_rect: TextureRect = $MinimapRect
@onready var sub_viewport: SubViewport = $SubViewport
@onready var cam: Camera3D = $SubViewport/Camera3D

# ==========================================
# 预加载图标场景
# ==========================================
@export var robot_icon_scene: PackedScene
@export var outpost_icon_scene: PackedScene 
@export var supply_icon_scene: PackedScene

# ==========================================
# 3D 节点引用
# ==========================================
@export var blue_outpost_3d: Node3D
@export var red_outpost_3d: Node3D
@export var blue_supply_3d: Node3D 
@export var red_supply_3d: Node3D  

# 手动微调偏移量
@export var offset_x: float = 16
@export var offset_y: float = 16
@export var blue_supply_offset: Vector2 = Vector2(0, 0)
@export var red_supply_offset: Vector2 = Vector2(0, 0)

var infantry: CharacterBody3D = null
var player_icon: Control = null
var icons_container: Control

# 记录各个图标实例
var blue_outpost_icon: Control
var red_outpost_icon: Control
var blue_supply_icon: Control 
var red_supply_icon: Control  

func _ready():
	if map_rect and sub_viewport:
		map_rect.texture = sub_viewport.get_texture()
		
	icons_container = Control.new()
	icons_container.name = "IconsContainer"
	icons_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icons_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_rect.add_child(icons_container)
	
	# --- 1. 生成玩家图标 ---
	infantry = get_tree().current_scene.get_node_or_null("Infantry")
	if infantry and robot_icon_scene:
		player_icon = robot_icon_scene.instantiate()
		icons_container.add_child(player_icon)
		player_icon.setup(Color.CYAN, 3) 
		# 【修复警告】：改用 custom_minimum_size
		player_icon.custom_minimum_size = Vector2(32, 32)
		player_icon.pivot_offset = player_icon.custom_minimum_size * 0.5

	# --- 2. 生成前哨站图标 ---
	if outpost_icon_scene:
		if blue_outpost_3d:
			blue_outpost_icon = outpost_icon_scene.instantiate()
			icons_container.add_child(blue_outpost_icon)
			blue_outpost_icon.custom_minimum_size = Vector2(23, 28)
			blue_outpost_icon.pivot_offset = blue_outpost_icon.custom_minimum_size * 0.5
			blue_outpost_icon.setup(Color(0.2, 0.6, 1.0)) 
			if blue_outpost_3d.has_signal("outpost_destroyed"):
				blue_outpost_3d.outpost_destroyed.connect(_on_outpost_destroyed.bind(blue_outpost_icon))
				
		if red_outpost_3d:
			red_outpost_icon = outpost_icon_scene.instantiate()
			icons_container.add_child(red_outpost_icon)
			red_outpost_icon.custom_minimum_size = Vector2(28, 28)
			red_outpost_icon.pivot_offset = red_outpost_icon.custom_minimum_size * 0.5
			red_outpost_icon.setup(Color(1.0, 0.2, 0.2)) 
			if red_outpost_3d.has_signal("outpost_destroyed"):
				red_outpost_3d.outpost_destroyed.connect(_on_outpost_destroyed.bind(red_outpost_icon))

	# --- 3. 生成补给区图标 ---
	if supply_icon_scene:
		if blue_supply_3d:
			blue_supply_icon = supply_icon_scene.instantiate()
			icons_container.add_child(blue_supply_icon)
			blue_supply_icon.custom_minimum_size = Vector2(24, 24) 
			blue_supply_icon.pivot_offset = blue_supply_icon.custom_minimum_size * 0.5
			blue_supply_icon.rotation = PI 
			if blue_supply_icon.has_method("setup"):
				blue_supply_icon.setup(Color(0.2, 0.6, 1.0))
			
		if red_supply_3d:
			red_supply_icon = supply_icon_scene.instantiate()
			icons_container.add_child(red_supply_icon)
			red_supply_icon.custom_minimum_size = Vector2(10, 28)
			red_supply_icon.pivot_offset = red_supply_icon.custom_minimum_size * 0.5
			if red_supply_icon.has_method("setup"):
				red_supply_icon.setup(Color(1.0, 0.2, 0.2))

func _process(_delta):
	if not cam: return
	var viewport_size = sub_viewport.size
	var map_size = map_rect.size

	# --- 更新玩家位置 ---
	if infantry != null and player_icon != null:
		var screen_pos = cam.unproject_position(infantry.global_position)
		var final_2d_pos = Vector2(
			(screen_pos.x / viewport_size.x) * map_size.x,
			(screen_pos.y / viewport_size.y) * map_size.y
		)
		final_2d_pos.x += offset_x
		final_2d_pos.y += offset_y
		
		player_icon.position = final_2d_pos - (player_icon.custom_minimum_size * 0.5)
		
		var yaw_rad = 0.0
		if infantry.get("yaw_node") != null:
			yaw_rad = infantry.yaw_node.global_rotation.y
		player_icon.update_rotation(yaw_rad + (PI / 2.0))
		
	# --- 更新前哨站位置 ---
	if blue_outpost_3d and blue_outpost_icon:
		var b_pos = cam.unproject_position(blue_outpost_3d.global_position)
		blue_outpost_icon.position = Vector2(
			(b_pos.x / viewport_size.x) * map_size.x + offset_x,
			(b_pos.y / viewport_size.y) * map_size.y + offset_y
		) - (blue_outpost_icon.custom_minimum_size * 0.5)
		
	if red_outpost_3d and red_outpost_icon:
		var r_pos = cam.unproject_position(red_outpost_3d.global_position)
		red_outpost_icon.position = Vector2(
			(r_pos.x / viewport_size.x) * map_size.x + offset_x,
			(r_pos.y / viewport_size.y) * map_size.y + offset_y
		) - (red_outpost_icon.custom_minimum_size * 0.5)

	# --- 更新补给区位置 ---
	if blue_supply_3d and blue_supply_icon:
		var bs_pos = cam.unproject_position(blue_supply_3d.global_position)
		blue_supply_icon.position = Vector2(
			(bs_pos.x / viewport_size.x) * map_size.x + offset_x,
			(bs_pos.y / viewport_size.y) * map_size.y + offset_y
		) - (blue_supply_icon.custom_minimum_size * 0.5) + blue_supply_offset

	if red_supply_3d and red_supply_icon:
		var rs_pos = cam.unproject_position(red_supply_3d.global_position)
		red_supply_icon.position = Vector2(
			(rs_pos.x / viewport_size.x) * map_size.x + offset_x,
			(rs_pos.y / viewport_size.y) * map_size.y + offset_y
		) - (red_supply_icon.custom_minimum_size * 0.5) + red_supply_offset

# ==========================================
# 回调：被击毁时变暗
# ==========================================
func _on_outpost_destroyed(icon: Control):
	if icon and icon.has_method("set_destroyed"):
		icon.set_destroyed()

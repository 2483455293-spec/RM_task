extends Control

# 获取子节点
@onready var arrow = $Arrow
@onready var base_circle = $BaseCircle
@onready var label = $Label

# 外部调用：设置颜色和编号
func setup(team_color: Color, id_num: int):
	# 只给圆圈底板上色（箭头和数字保持白色/黑色）
	base_circle.modulate = team_color
	label.text = str(id_num)

# 外部调用：更新朝向
func update_rotation(yaw_rad: float):
	# 只旋转箭头，数字和圆底不动
	arrow.rotation = -yaw_rad

extends Control

# 设置阵营颜色和大小
func setup(team_color: Color):
	# 给三个多边形染上对应的颜色
	$TowerBase.color = team_color
	$TowerBody.color = team_color
	$TowerTop.color = team_color

func set_destroyed():
	# 颜色变暗灰色，并降低一点透明度
	modulate = Color(0.3, 0.3, 0.3, 0.6) 

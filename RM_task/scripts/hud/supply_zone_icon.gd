extends Control

# 设置阵营颜色和大小
func setup(team_color: Color):
	# 给三个多边形染上对应的颜色
	$up.color = team_color
	$mid.color = team_color
	$down.color = team_color

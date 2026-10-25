extends Area3D

@export var target_id: int = 1
@export var faction: String = "blue" 

@onready var hit_sound: AudioStreamPlayer3D = $TargetHitSound

func _on_bullet_hit(normal_speed: float = 0.0):
	var agency = get_parent()
	var found = false
	
	# 向上寻找主控节点
	while agency != null:
		if agency.has_method("on_target_hit"):
			found = true
			
			var is_valid = true
			if agency.has_method("check_target_valid"):
				is_valid = agency.check_target_valid(faction, target_id)
			
			if is_valid:
				# 如果是有效靶，播放声音
				if hit_sound:
					if hit_sound.playing: hit_sound.stop()
					hit_sound.play()
				print("【靶心有效】靶心 ", target_id, " 击中，播放音效！")
			else:
				# 如果是未点亮的靶子，不发声
				print("【靶心无效】靶心 ", target_id, " 未激活，不发声！")
			
			agency.on_target_hit(faction, target_id)
			break
			
		agency = agency.get_parent()
		
	if not found:
		printerr("【致命错误】靶心 ", target_id, " 往上找没找到挂载 energy_agency.gd 的节点！检查一下层级！")

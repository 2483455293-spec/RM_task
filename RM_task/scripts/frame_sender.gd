extends Node

# ==========================================
# 配置参数
# ==========================================
var target_ip: String = "127.0.0.1"
var img_port: int = 9000
var state_port: int = 9001
var fps: int = 15

var camera_fov: float = 90.0
var camera_keep_width: bool = true
var cam_res_x: int = 1920
var cam_res_y: int = 1080
var jpeg_quality: float = 0.8

# ==========================================
# 节点引用
# ==========================================
@export var follow_camera: Camera3D 
@onready var subviewport: SubViewport = $SubViewport

var img_client: StreamPeerTCP
var state_client: StreamPeerTCP

var seq: int = 0
var timer: Timer
var state_timer: Timer

# 【新增】防止高分辨率下并发截图的锁
var is_sending_frame: bool = false 

# 供 HUD 订阅的信号
signal network_status_changed(is_connected: bool, current_fps: int, msg: String)

func _ready():
	# 1. 从全局单例读取配置
	if Engine.has_singleton("ConfigManager"):
		target_ip = ConfigManager.get_gameplay("network_ip", target_ip)
		fps = ConfigManager.get_gameplay("network_fps", fps)
		
		camera_fov = ConfigManager.get_gameplay("camera_fov", camera_fov)
		camera_keep_width = ConfigManager.get_gameplay("camera_keep_width", camera_keep_width)
		cam_res_x = ConfigManager.get_gameplay("camera_res_x", cam_res_x)
		cam_res_y = ConfigManager.get_gameplay("camera_res_y", cam_res_y)
		jpeg_quality = ConfigManager.get_gameplay("jpeg_quality", jpeg_quality)

	if subviewport == null:
		push_error("未找到 SubViewport 节点，请检查节点路径！")
		return
		
	subviewport.size = Vector2i(cam_res_x, cam_res_y)
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	var stream_cam = subviewport.get_node_or_null("StreamCamera")
	if stream_cam:
		stream_cam.fov = camera_fov
		stream_cam.keep_aspect = Camera3D.KEEP_WIDTH if camera_keep_width else Camera3D.KEEP_HEIGHT
	else:
		push_warning("未找到 StreamCamera，无法应用 FOV 配置！")

	# 图像发送定时器
	timer = Timer.new()
	timer.wait_time = 1.0 / fps
	timer.timeout.connect(send_frame)
	add_child(timer)

	# 状态发送定时器 (5Hz)
	state_timer = Timer.new()
	state_timer.wait_time = 0.2 
	state_timer.timeout.connect(send_state)
	add_child(state_timer)

	# 初始化两个 TCP 客户端
	img_client = StreamPeerTCP.new()
	state_client = StreamPeerTCP.new()
	
	img_client.connect_to_host(target_ip, img_port)
	state_client.connect_to_host(target_ip, state_port)
	print("FrameSender connecting to IP: ", target_ip, " | Image: ", img_port, " | State: ", state_port)

func _process(_delta):
	# 跟随视角同步
	if follow_camera != null:
		var stream_cam = subviewport.get_node_or_null("StreamCamera")
		if stream_cam != null:
			stream_cam.global_transform = follow_camera.global_transform

	# 每帧 Poll 推进 TCP 状态
	img_client.poll()
	state_client.poll()
	
	_check_connection()

# ==========================================
# 连接检测
# ==========================================
func _check_connection():
	var img_ok = (img_client.get_status() == StreamPeerTCP.STATUS_CONNECTED)
	var state_ok = (state_client.get_status() == StreamPeerTCP.STATUS_CONNECTED)

	if img_ok and state_ok:
		if timer.is_stopped(): timer.start()
		if state_timer.is_stopped(): state_timer.start()
		network_status_changed.emit(true, fps, "双通道已连接")
	elif img_ok:
		if timer.is_stopped(): timer.start()
		if not state_timer.is_stopped(): state_timer.stop()
		network_status_changed.emit(true, fps, "仅图像已连接")
	elif state_ok:
		if not timer.is_stopped(): timer.stop()
		if state_timer.is_stopped(): state_timer.start()
		network_status_changed.emit(true, 0, "仅状态已连接")
	else:
		if not timer.is_stopped(): timer.stop()
		if not state_timer.is_stopped(): state_timer.stop()
		network_status_changed.emit(false, 0, "通道断开")

# ==========================================
# 发送图像 (9000)
# ==========================================
func send_frame():
	# 【修复】如果上一帧还在处理中，直接跳过本次触发，防止高分辨率下卡死
	if is_sending_frame: return 
	if img_client.get_status() != StreamPeerTCP.STATUS_CONNECTED: return
	
	is_sending_frame = true
	# 等待渲染完成后再抓图
	await RenderingServer.frame_post_draw
	
	var img: Image = subviewport.get_texture().get_image()
	if img != null:
		var jpeg: PackedByteArray = img.save_jpg_to_buffer(jpeg_quality)
		var packet: PackedByteArray = pack_frame(jpeg, seq)
		_send_data(img_client, packet)
		seq += 1
		
	is_sending_frame = false # 处理完毕，解锁

# ==========================================
# 发送状态 (9001)
# ==========================================
func send_state():
	if state_client.get_status() != StreamPeerTCP.STATUS_CONNECTED: return
	
	var match_state = get_tree().current_scene.get_node_or_null("MatchState")
	var infantry = get_tree().current_scene.get_node_or_null("Infantry")
	
	var data = {
		"schema_version": 1,
		"phase": "RUNNING",
		"time_left": match_state.remaining_s if match_state else 0.0,
		"hp": infantry.hp if infantry else 0,
		# 【修复】动态读取最大血量与热量上限，不再写死
		"max_hp": infantry.max_hp if infantry else 100, 
		"ammo": infantry.ammo if infantry else 0,
		"heat": infantry.heat if infantry else 0.0,
		"heat_limit": infantry.max_heat if infantry else 120.0,
		"pose": {"x": 0.0, "z": 0.0, "yaw": 0.0}
	}
	
	var json_str = JSON.stringify(data) + "\n" 
	_send_data(state_client, json_str.to_utf8_buffer())

# ==========================================
# 底层工具函数
# ==========================================
func _send_data(client: StreamPeerTCP, data: PackedByteArray):
	var total = data.size()
	var offset = 0
	while offset < total:
		if client.get_status() != StreamPeerTCP.STATUS_CONNECTED: return
		var chunk = data.slice(offset)
		var res: Array = client.put_partial_data(chunk)
		if res[0] != OK or res[1] <= 0: break
		offset += res[1]

func pack_frame(jpeg_data: PackedByteArray, sequence: int) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.big_endian = true 
	buf.put_data("RMV1".to_ascii_buffer())
	buf.put_u32(sequence)
	buf.put_u64(Time.get_ticks_usec())
	buf.put_u32(jpeg_data.size())
	return buf.data_array + jpeg_data

func _exit_tree():
	if timer: timer.stop()
	if state_timer: state_timer.stop()
	if img_client: img_client.disconnect_from_host()
	if state_client: state_client.disconnect_from_host()

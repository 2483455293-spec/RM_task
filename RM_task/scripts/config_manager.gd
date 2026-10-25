extends Node

# ==========================================
# ConfigManager —— 全局配置管理器
# 读取策略：
#   1. 优先读取 exe 同目录下的  config/xxx.json（外部可修改）
#   2. 若外部不存在，回退到  res://config/xxx.json（打包内置）
#
# 使用方法：
#   项目设置 → Autoload → 添加本脚本，命名 ConfigManager
#   调用：ConfigManager.get_infantry("hp", 100)
# ==========================================

# 配置数据字典
var match_config: Dictionary = {}
var infantry_config: Dictionary = {}
var buildings_config: Dictionary = {}
var gameplay_config: Dictionary = {}

# 记录每个文件实际加载来源，方便调试
var _loaded_sources: Dictionary = {}

# ==========================================
# 初始化
# ==========================================
func _init():
	load_all_configs()

# ==========================================
# 加载 / 重载
# ==========================================
func load_all_configs() -> void:
	print("【ConfigManager】开始加载全局配置文件...")

	# 清空旧数据，避免重复 merge 导致脏数据残留
	match_config.clear()
	infantry_config.clear()
	buildings_config.clear()
	gameplay_config.clear()
	_loaded_sources.clear()

	var external_path := _get_external_config_dir()
	print("【ConfigManager】程序正在尝试读取外部配置路径: ", external_path)

	_load_json("match.json",     match_config,    external_path)
	_load_json("infantry.json",  infantry_config, external_path)
	_load_json("buildings.json", buildings_config, external_path)
	_load_json("gameplay.json",  gameplay_config, external_path)

	print("【ConfigManager】所有配置加载完毕！")

# 供外部热重载调用
func reload_all() -> void:
	load_all_configs()

# 获取 exe 同目录下的 config 文件夹绝对路径
# 注意：在编辑器内运行时，返回的是 Godot 编辑器所在目录，
# 此时外部文件一般不存在，会自动回退到 res://config/，属正常现象。
func _get_external_config_dir() -> String:
	var exe_dir := OS.get_executable_path().get_base_dir()
	return exe_dir.path_join("config") + "/"

# ==========================================
# 内部：单个文件加载（外部优先 → 内置回退）
# ==========================================
func _load_json(file_name: String, target_dict: Dictionary, external_path: String) -> void:
	# 1. 优先尝试读取 exe 同目录下的外部 JSON
	var external_file := external_path + file_name
	if FileAccess.file_exists(external_file):
		print("【ConfigManager】成功读取外部配置: ", external_file)
		if _read_and_merge(external_file, target_dict):
			_loaded_sources[file_name] = external_file
		return

	# 2. 外部不存在，读取打包内置的默认配置
	var internal_file := "res://config/" + file_name
	if FileAccess.file_exists(internal_file):
		print("【ConfigManager】读取内置配置: ", internal_file)
		if _read_and_merge(internal_file, target_dict):
			_loaded_sources[file_name] = internal_file
		return

	# 3. 两处都不存在
	push_error("【ConfigManager】找不到配置文件（外部与内置均不存在）: " + file_name)

# 读取并合并到目标字典，成功返回 true
func _read_and_merge(path: String, target_dict: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("【ConfigManager】无法打开文件: " + path)
		return false

	var json_text := file.get_as_text()
	file.close()

	var parsed_data = JSON.parse_string(json_text)
	if parsed_data == null:
		push_error("【ConfigManager】JSON 解析失败，请检查语法（如多余逗号）: " + path)
		return false

	if not parsed_data is Dictionary:
		push_error("【ConfigManager】JSON 根节点必须是字典: " + path)
		return false

	target_dict.merge(parsed_data, true)
	return true

# ==========================================
# 外部调用（带默认值兜底）
# ==========================================
func get_infantry(key: String, default_value: Variant = null) -> Variant:
	return infantry_config.get(key, default_value)

func get_buildings(key: String, default_value: Variant = null) -> Variant:
	return buildings_config.get(key, default_value)

func get_gameplay(key: String, default_value: Variant = null) -> Variant:
	return gameplay_config.get(key, default_value)

func get_match(key: String, default_value: Variant = null) -> Variant:
	return match_config.get(key, default_value)

# ==========================================
# 存在性判断（比 get() == null 更可靠）
# ==========================================
func has_infantry(key: String) -> bool:
	return infantry_config.has(key)

func has_buildings(key: String) -> bool:
	return buildings_config.has(key)

func has_gameplay(key: String) -> bool:
	return gameplay_config.has(key)

func has_match(key: String) -> bool:
	return match_config.has(key)

# ==========================================
# 整表获取（需要遍历全部数据时使用）
# ==========================================
func get_infantry_table() -> Dictionary:
	return infantry_config

func get_buildings_table() -> Dictionary:
	return buildings_config

func get_gameplay_table() -> Dictionary:
	return gameplay_config

func get_match_table() -> Dictionary:
	return match_config

# ==========================================
# 调试：查询某个文件实际加载来源
# ==========================================
func get_source(file_name: String) -> String:
	return _loaded_sources.get(file_name, "")

func is_using_external(file_name: String) -> bool:
	var src := get_source(file_name)
	return src != "" and not src.begins_with("res://")

@tool
extends Control
class_name ExcelTable

# 引入翻译管理器
const TranslationManager = preload("res://addons/json_editor/scripts/translation_manager.gd")

signal data_changed(new_data: Variant)
signal cell_selected(row: int, column: int)
signal column_type_edit_requested(column_index: int, column_name: String)
signal row_add_requested(row_index: int)
signal row_copy_requested(row_index: int)
signal row_delete_requested(row_index: int)

var grid_container: GridContainer
var scroll_container: ScrollContainer
var current_data: Variant
var headers: Array[String] = []
var rows_data: Array[Array] = []
var cell_inputs: Array[Array] = []
var column_types: Array[int] = []  # 存储每列的数据类型 0=String, 1=Number, 2=Boolean

func _ready():
	custom_minimum_size = Vector2(600, 300)
	_create_ui()

func _create_ui():
	# 设置整体背景样式
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("#FAFBFC")
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color("#E1E5E9")
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", bg_style)

	scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.add_theme_constant_override("margin_left", 8)
	scroll_container.add_theme_constant_override("margin_top", 8)
	scroll_container.add_theme_constant_override("margin_right", 8)
	scroll_container.add_theme_constant_override("margin_bottom", 8)
	add_child(scroll_container)

	grid_container = GridContainer.new()
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 0)
	scroll_container.add_child(grid_container)

func setup_data(data: Variant):
	current_data = data
	await _clear_table()
	_analyze_data(data)
	_build_table()

func _clear_table():
	if grid_container:
		for child in grid_container.get_children():
			child.queue_free()
		# 等待下一帧确保节点被清理
		await get_tree().process_frame
	headers.clear()
	rows_data.clear()
	cell_inputs.clear()
	column_types.clear()

func _analyze_data(data: Variant):
	match typeof(data):
		TYPE_DICTIONARY:
			_analyze_dictionary(data)
		TYPE_ARRAY:
			_analyze_array(data)
		_:
			headers.clear()
			headers.append(TranslationManager.get_text("value_header"))
			rows_data.clear()
			var row: Array[String] = []
			row.append(str(data))
			rows_data.append(row)

func _analyze_dictionary(data: Dictionary):
	var all_objects = true
	for value in data.values():
		if typeof(value) != TYPE_DICTIONARY:
			all_objects = false
			break

	if all_objects and data.size() > 0:
		var all_keys = {"ID": true}
		for obj in data.values():
			for key in obj.keys():
				all_keys[key] = true

		var keys_array = all_keys.keys()
		headers.clear()
		for key in keys_array:
			headers.append(str(key))
		headers.sort()

		# 推断每列的类型
		column_types.clear()
		for i in range(headers.size()):
			var column_type = _infer_column_type(data, headers[i], i == 0)
			column_types.append(column_type)

		rows_data.clear()
		for item_id in data.keys():
			var row: Array[String] = []
			row.append(str(item_id))
			var obj = data[item_id]
			for i in range(1, headers.size()):
				var key = headers[i]
				if obj.has(key):
					row.append(str(obj[key]))
				else:
					row.append("")
			rows_data.append(row)
	else:
		headers.clear()
		headers.append(TranslationManager.get_text("key"))
		headers.append(TranslationManager.get_text("value"))

		# 为键值对模式推断类型
		column_types.clear()
		column_types.append(0)  # 键总是字符串
		column_types.append(_infer_simple_values_type(data.values()))

		rows_data.clear()
		for key in data.keys():
			var row: Array[String] = []
			row.append(str(key))
			row.append(str(data[key]))
			rows_data.append(row)

func _analyze_array(data: Array):
	if data.is_empty():
		headers.clear()
		headers.append(TranslationManager.get_text("value_header"))
		rows_data.clear()
		return

	var first_item = data[0]
	if typeof(first_item) == TYPE_DICTIONARY:
		var all_keys = {}
		for item in data:
			if typeof(item) == TYPE_DICTIONARY:
				for key in item.keys():
					all_keys[key] = true

		var keys_array = all_keys.keys()
		headers.clear()
		for key in keys_array:
			headers.append(str(key))
		headers.sort()

		# 为数组中的对象推断列类型
		column_types.clear()
		for i in range(headers.size()):
			var column_type = _infer_array_column_type(data, headers[i])
			column_types.append(column_type)

		rows_data.clear()
		for item in data:
			var row: Array[String] = []
			for header in headers:
				if typeof(item) == TYPE_DICTIONARY and item.has(header):
					row.append(str(item[header]))
				else:
					row.append("")
			rows_data.append(row)
	else:
		headers.clear()
		headers.append(TranslationManager.get_text("index"))
		headers.append(TranslationManager.get_text("value"))

		# 为简单数组推断类型
		column_types.clear()
		column_types.append(0)  # 索引总是字符串
		column_types.append(_infer_simple_values_type(data))

		rows_data.clear()
		for i in range(data.size()):
			var row: Array[String] = []
			row.append(str(i))
			row.append(str(data[i]))
			rows_data.append(row)

func _build_table():
	if headers.is_empty():
		return

	if not grid_container:
		_create_ui()

	# 添加行号列
	grid_container.columns = headers.size() + 1

	# 创建行号标题
	var row_header = _create_row_number_header()
	grid_container.add_child(row_header)

	# 创建其他标题
	for i in range(headers.size()):
		var header = headers[i]
		var header_cell = _create_header_cell(header, i)
		grid_container.add_child(header_cell)

	cell_inputs.clear()
	for row_idx in range(rows_data.size()):
		# 添加行号
		var row_number_cell = _create_row_number_cell(row_idx)
		grid_container.add_child(row_number_cell)

		var row_cells: Array[LineEdit] = []
		for col_idx in range(headers.size()):
			var value = ""
			if col_idx < rows_data[row_idx].size():
				value = rows_data[row_idx][col_idx]

			var cell = _create_data_cell(value, row_idx, col_idx)
			grid_container.add_child(cell)
			row_cells.append(cell)

		cell_inputs.append(row_cells)

func _create_header_cell(text: String, column_index: int = -1) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(120, 35)

	var style = StyleBoxFlat.new()
	style.bg_color = Color("#2E5BBA")  # 更深的蓝色
	style.border_width_bottom = 2
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_color = Color("#FFFFFF")
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	# 添加渐变效果
	style.bg_color = Color("#4A90E2")
	panel.add_theme_stylebox_override("panel", style)

	# 如果是数据列，在标题上添加编辑图标
	if column_index >= 0:
		var hbox = HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(hbox)

		var label = Label.new()
		# 添加类型图标到列标题
		var type_icon = _get_type_icon(column_index)
		label.text = text + type_icon
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 13)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(label)

		var edit_icon = Label.new()
		edit_icon.text = " ✎"  # 编辑图标
		edit_icon.add_theme_color_override("font_color", Color("#DDDDDD"))
		edit_icon.add_theme_font_size_override("font_size", 12)
		edit_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(edit_icon)
	else:
		var label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 13)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		panel.add_child(label)

	# 如果是数据列（非行号列），添加双击编辑功能
	if column_index >= 0:
		panel.gui_input.connect(_on_header_input.bind(column_index, text))
		# 添加鼠标悬停提示
		panel.tooltip_text = TranslationManager.get_text("double_click_edit_column_type") % text

		# 悬停样式
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color("#5BA3F5")  # 稍亮的蓝色
		hover_style.border_width_bottom = 2
		hover_style.border_width_right = 1
		hover_style.border_width_top = 1
		hover_style.border_width_left = 1
		hover_style.border_color = Color("#FFFFFF")
		hover_style.corner_radius_top_left = 3
		hover_style.corner_radius_top_right = 3

		# 为标题添加鼠标检测
		panel.mouse_entered.connect(_on_header_mouse_entered.bind(panel, hover_style))
		panel.mouse_exited.connect(_on_header_mouse_exited.bind(panel, style))

	return panel

func _create_row_number_header() -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(50, 35)

	var style = StyleBoxFlat.new()
	style.bg_color = Color("#6B7280")  # 灰色，区别于普通标题
	style.border_width_bottom = 2
	style.border_width_right = 2
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_color = Color("#FFFFFF")
	style.corner_radius_top_left = 3
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = "#"
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	panel.add_child(label)
	return panel

func _create_row_number_cell(row_number: int) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(50, 30)

	var style = StyleBoxFlat.new()
	style.bg_color = Color("#F3F4F6")
	style.border_width_bottom = 1
	style.border_width_right = 2
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_color = Color("#E1E5E9")
	panel.add_theme_stylebox_override("panel", style)

	# 悬停样式
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color("#E5E7EB")
	hover_style.border_width_bottom = 1
	hover_style.border_width_right = 2
	hover_style.border_width_top = 1
	hover_style.border_width_left = 1
	hover_style.border_color = Color("#D1D5DB")

	var label = Label.new()
	label.text = str(row_number + 1)
	label.add_theme_color_override("font_color", Color("#6B7280"))
	label.add_theme_font_size_override("font_size", 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	panel.add_child(label)

	# 添加右键菜单功能
	panel.gui_input.connect(_on_row_number_input.bind(row_number))
	panel.mouse_entered.connect(_on_row_number_mouse_entered.bind(panel, hover_style))
	panel.mouse_exited.connect(_on_row_number_mouse_exited.bind(panel, style))
	panel.tooltip_text = TranslationManager.get_text("right_click_row_menu")

	return panel

func _create_data_cell(value: String, row: int, col: int) -> LineEdit:
	var line_edit = LineEdit.new()
	line_edit.text = value
	line_edit.custom_minimum_size = Vector2(120, 30)
	line_edit.placeholder_text = TranslationManager.get_text("enter_value")

	# 普通状态样式
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color.WHITE if row % 2 == 0 else Color("#F8F9FA")
	normal_style.border_width_bottom = 1
	normal_style.border_width_right = 1
	normal_style.border_width_top = 1
	normal_style.border_width_left = 1
	normal_style.border_color = Color("#E1E5E9")
	normal_style.content_margin_left = 8
	normal_style.content_margin_right = 8
	normal_style.content_margin_top = 4
	normal_style.content_margin_bottom = 4
	line_edit.add_theme_stylebox_override("normal", normal_style)

	# 焦点状态样式
	var focus_style = StyleBoxFlat.new()
	focus_style.bg_color = Color("#FFFFFF")
	focus_style.border_width_left = 2
	focus_style.border_width_top = 2
	focus_style.border_width_right = 2
	focus_style.border_width_bottom = 2
	focus_style.border_color = Color("#4A90E2")
	focus_style.content_margin_left = 8
	focus_style.content_margin_right = 8
	focus_style.content_margin_top = 4
	focus_style.content_margin_bottom = 4
	# 添加阴影效果
	var shadow_color = Color("#4A90E2")
	shadow_color.a = 0.3
	focus_style.shadow_color = shadow_color
	focus_style.shadow_size = 2
	line_edit.add_theme_stylebox_override("focus", focus_style)

	# 悬停状态样式
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color("#F0F7FF")
	hover_style.border_width_bottom = 1
	hover_style.border_width_right = 1
	hover_style.border_width_top = 1
	hover_style.border_width_left = 1
	hover_style.border_color = Color("#B8D4F0")
	hover_style.content_margin_left = 8
	hover_style.content_margin_right = 8
	hover_style.content_margin_top = 4
	hover_style.content_margin_bottom = 4
	line_edit.add_theme_stylebox_override("hover", hover_style)

	# 字体样式
	line_edit.add_theme_font_size_override("font_size", 12)
	line_edit.add_theme_color_override("font_color", Color("#333333"))
	line_edit.add_theme_color_override("font_placeholder_color", Color("#999999"))

	line_edit.text_submitted.connect(_on_cell_text_submitted.bind(row, col))
	line_edit.focus_entered.connect(_on_cell_focus_entered.bind(row, col))
	line_edit.gui_input.connect(_on_cell_input.bind(row, col, line_edit))

	return line_edit

func _on_cell_focus_entered(row: int, col: int):
	cell_selected.emit(row, col)

func _on_cell_text_submitted(text: String, row: int, col: int):
	_update_cell_value(row, col, text)
	_move_to_next_cell(row, col)

func _on_cell_input(event: InputEvent, row: int, col: int, line_edit: LineEdit):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_TAB:
				_update_cell_value(row, col, line_edit.text)
				if event.shift_pressed:
					_move_to_previous_cell(row, col)
				else:
					_move_to_next_cell(row, col)
				get_viewport().set_input_as_handled()
			KEY_ENTER:
				_update_cell_value(row, col, line_edit.text)
				_move_to_next_row(row, col)
				get_viewport().set_input_as_handled()

func _update_cell_value(row: int, col: int, value: String):
	if row < rows_data.size() and col < rows_data[row].size():
		rows_data[row][col] = value
		_sync_data_back()

func _sync_data_back():
	match typeof(current_data):
		TYPE_DICTIONARY:
			_sync_to_dictionary()
		TYPE_ARRAY:
			_sync_to_array()

	# 发出数据变化信号，这会触发主编辑器的保存逻辑
	data_changed.emit(current_data)

	# 在控制台输出提示，表示数据已更新
	print(TranslationManager.get_text("data_updated_prompt"))

func _sync_to_dictionary():
	if headers.size() > 0 and headers[0] == "ID":
		var new_data = {}
		for row in rows_data:
			if row.size() > 0:
				var item_id = row[0]
				var obj = {}
				for i in range(1, min(headers.size(), row.size())):
					var column_type = column_types[i] if i < column_types.size() else 0
					obj[headers[i]] = _parse_value_with_type(row[i], column_type)
				new_data[item_id] = obj
		current_data = new_data
	else:
		var new_data = {}
		for row in rows_data:
			if row.size() >= 2:
				var column_type = column_types[1] if column_types.size() > 1 else 0
				new_data[row[0]] = _parse_value_with_type(row[1], column_type)
		current_data = new_data

func _sync_to_array():
	if headers.size() == 2 and headers[0] == TranslationManager.get_text("index"):
		var new_array = []
		for row in rows_data:
			if row.size() > 1:
				var column_type = column_types[1] if column_types.size() > 1 else 0
				new_array.append(_parse_value_with_type(row[1], column_type))
		current_data = new_array
	else:
		var new_array = []
		for row in rows_data:
			var obj = {}
			for i in range(min(headers.size(), row.size())):
				var column_type = column_types[i] if i < column_types.size() else 0
				obj[headers[i]] = _parse_value_with_type(row[i], column_type)
			new_array.append(obj)
		current_data = new_array

func _parse_value(value: String) -> Variant:
	if value.is_valid_int():
		return value.to_int()
	elif value.is_valid_float():
		return value.to_float()
	elif value.to_lower() in ["true", "false"]:
		return value.to_lower() == "true"
	else:
		return value

func _parse_value_with_type(value: String, expected_type: int) -> Variant:
	"""根据指定的类型解析值"""
	match expected_type:
		0: # 字符串类型
			return value  # 保持为字符串，不进行类型转换
		1: # 数字类型
			if value.is_valid_int():
				return value.to_int()
			elif value.is_valid_float():
				return value.to_float()
			else:
				return 0  # 无法转换时返回0
		2: # 布尔类型
			var lower_value = value.to_lower()
			if lower_value in ["true", "1", "yes", "on"]:
				return true
			elif lower_value in ["false", "0", "no", "off"]:
				return false
			else:
				return value != ""  # 非空字符串为true
		_:
			return value  # 默认返回字符串

func _move_to_next_cell(row: int, col: int):
	var next_col = col + 1
	var next_row = row

	if next_col >= headers.size():
		next_col = 0
		next_row += 1

	if next_row < cell_inputs.size():
		_focus_cell(next_row, next_col)

func _move_to_previous_cell(row: int, col: int):
	var prev_col = col - 1
	var prev_row = row

	if prev_col < 0:
		prev_col = headers.size() - 1
		prev_row -= 1

	if prev_row >= 0:
		_focus_cell(prev_row, prev_col)

func _move_to_next_row(row: int, col: int):
	var next_row = row + 1
	if next_row < cell_inputs.size():
		_focus_cell(next_row, col)

func _focus_cell(row: int, col: int):
	if row < cell_inputs.size() and col < cell_inputs[row].size():
		cell_inputs[row][col].grab_focus()

func _on_header_input(event: InputEvent, column_index: int, column_name: String):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			# 直接发出列编辑请求信号，让主编辑器处理
			column_type_edit_requested.emit(column_index, column_name)

func _on_header_mouse_entered(panel: Panel, hover_style: StyleBoxFlat):
	panel.add_theme_stylebox_override("panel", hover_style)

func _on_header_mouse_exited(panel: Panel, normal_style: StyleBoxFlat):
	panel.add_theme_stylebox_override("panel", normal_style)

func convert_column_type(column_index: int, target_type: int, force_convert: bool = false) -> void:
	"""转换指定列的数据类型"""
	if column_index < 0 or column_index >= headers.size():
		print(TranslationManager.get_text("invalid_column_index") + ":", column_index)
		return

	var convert_mode = TranslationManager.get_text("force_conversion") if force_convert else TranslationManager.get_text("smart_conversion")
	print(TranslationManager.get_text("start_conversion") % [convert_mode, str(column_index), headers[column_index], str(target_type)])

	# 更新列类型记录
	if column_index < column_types.size():
		column_types[column_index] = target_type
	else:
		# 扩展数组到指定索引
		while column_types.size() <= column_index:
			column_types.append(0)
		column_types[column_index] = target_type

	# 直接修改current_data中的数据，而不是rows_data
	_convert_current_data_column(column_index, target_type, force_convert)

	# 重新分析数据并重建表格
	await _clear_table()
	_analyze_data(current_data)
	_build_table()

	# 触发数据变化信号，同步到主编辑器
	data_changed.emit(current_data)

	print(TranslationManager.get_text("conversion_complete"))

func _convert_value_type(value: String, target_type: int, force_convert: bool = false) -> Variant:
	"""转换单个值的类型"""
	match target_type:
		0: # 字符串
			return str(value)
		1: # 数字
			if value.is_valid_int():
				return value.to_int()
			elif value.is_valid_float():
				return value.to_float()
			else:
				if force_convert:
					# 强制转换：尝试提取数字，失败则为0
					var regex = RegEx.new()
					regex.compile(r"-?\d+\.?\d*")
					var result = regex.search(value)
					if result:
						var num_str = result.get_string()
						if num_str.is_valid_int():
							return num_str.to_int()
						elif num_str.is_valid_float():
							return num_str.to_float()
					return 0
				else:
					# 智能转换：无法转换则保持原值
					return value
		2: # 布尔值
			var lower_value = value.to_lower()
			if lower_value in ["true", "1", "yes", "on"]:
				return true
			elif lower_value in ["false", "0", "no", "off"]:
				return false
			else:
				if force_convert:
					# 强制转换：非空字符串为true
					return value != ""
				else:
					# 智能转换：无法识别则保持原值
					return value
		_:
			return value

func _convert_current_data_column(column_index: int, target_type: int, force_convert: bool = false) -> void:
	"""直接转换current_data中指定列的数据类型"""
	if column_index >= headers.size():
		return

	var column_name = headers[column_index]
	var convert_mode = TranslationManager.get_text("force_conversion") if force_convert else TranslationManager.get_text("smart_conversion")
	print("转换列: ", column_name, " 到类型: ", target_type, " (", convert_mode, ")")

	match typeof(current_data):
		TYPE_DICTIONARY:
			_convert_dictionary_column(current_data, column_name, column_index, target_type, force_convert)
		TYPE_ARRAY:
			_convert_array_column(current_data, column_name, column_index, target_type, force_convert)

func _convert_dictionary_column(data: Dictionary, column_name: String, column_index: int, target_type: int, force_convert: bool = false) -> void:
	"""转换字典数据中的指定列"""
	if headers.size() > 0 and headers[0] == "ID":
		# 对象集合模式
		for key in data.keys():
			var obj = data[key]
			if typeof(obj) == TYPE_DICTIONARY and obj.has(column_name):
				var old_value = str(obj[column_name])
				var new_value = _convert_value_type(old_value, target_type, force_convert)
				obj[column_name] = new_value
				print("转换 ", key, ".", column_name, ": ", old_value, " -> ", new_value)
	else:
		# 键值对模式
		if column_index == 1:  # 值列
			for key in data.keys():
				var old_value = str(data[key])
				var new_value = _convert_value_type(old_value, target_type, force_convert)
				data[key] = new_value
				print("转换值 ", key, ": ", old_value, " -> ", new_value)

func _convert_array_column(data: Array, column_name: String, column_index: int, target_type: int, force_convert: bool = false) -> void:
	"""转换数组数据中的指定列"""
	if headers.size() == 2 and headers[0] == TranslationManager.get_text("index"):
		# 简单数组模式
		if column_index == 1:  # 值列
			for i in range(data.size()):
				var old_value = str(data[i])
				var new_value = _convert_value_type(old_value, target_type, force_convert)
				data[i] = new_value
				print("转换数组[", i, "]: ", old_value, " -> ", new_value)
	else:
		# 对象数组模式
		for item in data:
			if typeof(item) == TYPE_DICTIONARY and item.has(column_name):
				var old_value = str(item[column_name])
				var new_value = _convert_value_type(old_value, target_type, force_convert)
				item[column_name] = new_value
				print("转换对象.", column_name, ": ", old_value, " -> ", new_value)

func _infer_column_type(data: Dictionary, column_name: String, is_id_column: bool) -> int:
	"""推断列的数据类型"""
	if is_id_column:
		return 0  # ID列默认为字符串

	var sample_values = []
	for obj in data.values():
		if typeof(obj) == TYPE_DICTIONARY and obj.has(column_name):
			sample_values.append(obj[column_name])

	if sample_values.is_empty():
		return 0  # 默认为字符串

	# 检查是否所有值都是布尔类型
	var all_bool = true
	for value in sample_values:
		if typeof(value) != TYPE_BOOL:
			all_bool = false
			break
	if all_bool:
		return 2  # 布尔类型

	# 检查是否所有值都是数字类型
	var all_number = true
	for value in sample_values:
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			all_number = false
			break
	if all_number:
		return 1  # 数字类型

	return 0  # 默认为字符串类型

func _infer_simple_values_type(values: Array) -> int:
	"""推断简单值列表的类型"""
	if values.is_empty():
		return 0  # 默认为字符串

	# 检查是否所有值都是布尔类型
	var all_bool = true
	for value in values:
		if typeof(value) != TYPE_BOOL:
			all_bool = false
			break
	if all_bool:
		return 2  # 布尔类型

	# 检查是否所有值都是数字类型
	var all_number = true
	for value in values:
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			all_number = false
			break
	if all_number:
		return 1  # 数字类型

	return 0  # 默认为字符串类型

func _infer_array_column_type(data: Array, column_name: String) -> int:
	"""推断数组中对象某列的数据类型"""
	var sample_values = []
	for item in data:
		if typeof(item) == TYPE_DICTIONARY and item.has(column_name):
			sample_values.append(item[column_name])

	return _infer_simple_values_type(sample_values)

func _get_type_icon(column_index: int) -> String:
	"""获取列类型的图标"""
	if column_index >= column_types.size():
		return " [T]"  # 默认文本类型

	match column_types[column_index]:
		0:
			return " [T]"  # 文本/字符串
		1:
			return " [#]"  # 数字
		2:
			return " [✓]"  # 布尔值
		_:
			return " [?]"  # 未知类型

func get_column_type(column_index: int) -> int:
	"""获取指定列的类型"""
	if column_index >= 0 and column_index < column_types.size():
		return column_types[column_index]
	return 0  # 默认为字符串类型

func get_column_preview(column_index: int, target_type: int) -> String:
	"""获取列类型转换预览"""
	if column_index < 0 or column_index >= headers.size():
		return TranslationManager.get_text("invalid_column_index")

	var column_name = headers[column_index]
	var preview_lines = []
	var sample_count = 0
	var max_samples = 5  # 最多显示5个示例

	match typeof(current_data):
		TYPE_DICTIONARY:
			if headers.size() > 0 and headers[0] == "ID":
				# 对象集合模式
				for key in current_data.keys():
					if sample_count >= max_samples:
						break
					var obj = current_data[key]
					if typeof(obj) == TYPE_DICTIONARY and obj.has(column_name):
						var old_value = str(obj[column_name])
						var smart_value = _convert_value_type(old_value, target_type, false)
						var force_value = _convert_value_type(old_value, target_type, true)

						var smart_result = str(smart_value) + " (" + _get_type_name(typeof(smart_value)) + ")"
						var force_result = str(force_value) + " (" + _get_type_name(typeof(force_value)) + ")"

						var line = key + "." + column_name + ": \"" + old_value + "\""
						line += "\n  " + TranslationManager.get_text("smart_conversion_result") + " " + smart_result
						line += "\n  " + TranslationManager.get_text("force_conversion_result") + " " + force_result
						preview_lines.append(line)
						sample_count += 1
			else:
				# 键值对模式
				if column_index == 1:
					for key in current_data.keys():
						if sample_count >= max_samples:
							break
						var old_value = str(current_data[key])
						var smart_value = _convert_value_type(old_value, target_type, false)
						var force_value = _convert_value_type(old_value, target_type, true)

						var smart_result = str(smart_value) + " (" + _get_type_name(typeof(smart_value)) + ")"
						var force_result = str(force_value) + " (" + _get_type_name(typeof(force_value)) + ")"

						var line = key + ": \"" + old_value + "\""
						line += "\n  " + TranslationManager.get_text("smart_conversion") + " → " + smart_result
						line += "\n  " + TranslationManager.get_text("force_conversion") + " → " + force_result
						preview_lines.append(line)
						sample_count += 1
		TYPE_ARRAY:
			if headers.size() == 2 and headers[0] == TranslationManager.get_text("index"):
				# 简单数组模式
				if column_index == 1:
					for i in range(min(current_data.size(), max_samples)):
						var old_value = str(current_data[i])
						var smart_value = _convert_value_type(old_value, target_type, false)
						var force_value = _convert_value_type(old_value, target_type, true)

						var smart_result = str(smart_value) + " (" + _get_type_name(typeof(smart_value)) + ")"
						var force_result = str(force_value) + " (" + _get_type_name(typeof(force_value)) + ")"

						var line = "[" + str(i) + "]: \"" + old_value + "\""
						line += "\n  " + TranslationManager.get_text("smart_conversion") + " → " + smart_result
						line += "\n  " + TranslationManager.get_text("force_conversion") + " → " + force_result
						preview_lines.append(line)
			else:
				# 对象数组模式
				for i in range(min(current_data.size(), max_samples)):
					var item = current_data[i]
					if typeof(item) == TYPE_DICTIONARY and item.has(column_name):
						var old_value = str(item[column_name])
						var smart_value = _convert_value_type(old_value, target_type, false)
						var force_value = _convert_value_type(old_value, target_type, true)

						var smart_result = str(smart_value) + " (" + _get_type_name(typeof(smart_value)) + ")"
						var force_result = str(force_value) + " (" + _get_type_name(typeof(force_value)) + ")"

						var line = "[" + str(i) + "]." + column_name + ": \"" + old_value + "\""
						line += "\n  智能转换 → " + smart_result
						line += "\n  强制转换 → " + force_result
						preview_lines.append(line)

	if preview_lines.is_empty():
		return TranslationManager.get_text("no_convertible_data_found")

	var result = TranslationManager.get_text("conversion_preview_header").replace("{count}", str(sample_count)) + ":\n\n"
	result += "\n\n".join(preview_lines)
	return result

func _get_type_name(type_id: int) -> String:
	"""获取Godot类型名称"""
	match type_id:
		TYPE_STRING:
			return TranslationManager.get_text("type_string")
		TYPE_INT:
			return TranslationManager.get_text("type_integer")
		TYPE_FLOAT:
			return TranslationManager.get_text("type_float")
		TYPE_BOOL:
			return TranslationManager.get_text("type_boolean")
		_:
			return TranslationManager.get_text("type_other")

# 行号单元格事件处理
func _on_row_number_input(event: InputEvent, row_number: int):
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_show_row_context_menu(row_number, mouse_event.global_position)

func _on_row_number_mouse_entered(panel: Panel, hover_style: StyleBoxFlat):
	panel.add_theme_stylebox_override("panel", hover_style)

func _on_row_number_mouse_exited(panel: Panel, normal_style: StyleBoxFlat):
	panel.add_theme_stylebox_override("panel", normal_style)

# 显示行操作的右键菜单
func _show_row_context_menu(row_number: int, position: Vector2):
	var popup = PopupMenu.new()
	popup.add_item(TranslationManager.get_text("add_new_row_before"), 0)
	popup.add_item(TranslationManager.get_text("add_new_row_after"), 1)
	popup.add_separator()
	popup.add_item(TranslationManager.get_text("copy_this_row"), 2)
	popup.add_separator()
	popup.add_item(TranslationManager.get_text("delete_this_row"), 3)

	popup.id_pressed.connect(func(id): _on_row_context_menu_selected(id, row_number))
	get_viewport().add_child(popup)
	popup.position = Vector2i(position)
	popup.popup()

	# 自动清理
	popup.popup_hide.connect(func(): popup.queue_free())

# 处理行操作菜单选择
func _on_row_context_menu_selected(id: int, row_number: int):
	print("菜单选择 - ID: ", id, ", 行号: ", row_number)
	match id:
		0: # 在此行之前添加
			print("执行：在此行之前添加")
			_add_row(row_number)
		1: # 在此行之后添加
			print("执行：在此行之后添加")
			_add_row(row_number + 1)
		2: # 复制此行
			print("执行：复制此行")
			_copy_row(row_number)
		3: # 删除此行
			print("执行：删除此行")
			_delete_row(row_number)

# 获取当前数据类型
func _get_data_type() -> String:
	match typeof(current_data):
		TYPE_DICTIONARY:
			# 检查是否为对象集合
			var all_objects = true
			for value in current_data.values():
				if typeof(value) != TYPE_DICTIONARY:
					all_objects = false
					break
			if all_objects and current_data.size() > 0:
				return "object_collection"
			else:
				return "key_value_pairs"
		TYPE_ARRAY:
			if current_data.is_empty():
				return "simple_array"
			var first_item = current_data[0]
			if typeof(first_item) == TYPE_DICTIONARY:
				return "object_array"
			else:
				return "simple_array"
		_:
			return "simple_value"

# 添加新行
func _add_row(row_index: int):
	print("添加行到索引: ", row_index)

	var data_type = _get_data_type()
	match data_type:
		"object_collection":
			_add_row_to_object_collection(row_index)
		"key_value_pairs":
			_add_row_to_key_value_pairs(row_index)
		"simple_array":
			_add_row_to_simple_array(row_index)
		"object_array":
			_add_row_to_object_array(row_index)

# 复制行
func _copy_row(row_index: int):
	print("复制行索引: ", row_index)

	if row_index < 0 or row_index >= rows_data.size():
		return

	var row_to_copy = rows_data[row_index]
	var data_type = _get_data_type()

	match data_type:
		"object_collection":
			_copy_row_in_object_collection(row_index, row_to_copy)
		"key_value_pairs":
			_copy_row_in_key_value_pairs(row_index, row_to_copy)
		"simple_array":
			_copy_row_in_simple_array(row_index, row_to_copy)
		"object_array":
			_copy_row_in_object_array(row_index, row_to_copy)

# 删除行
func _delete_row(row_index: int):
	print("删除行索引: ", row_index)

	if row_index < 0 or row_index >= rows_data.size():
		return

	# 确认对话框
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = TranslationManager.get_text("confirm_delete_row") % (row_index + 1)
	dialog.title = TranslationManager.get_text("confirm_delete")

	get_viewport().add_child(dialog)
	dialog.confirmed.connect(_confirm_delete_row.bind(row_index))
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

	# 自动清理
	dialog.confirmed.connect(func(): dialog.queue_free(), CONNECT_ONE_SHOT)
	dialog.canceled.connect(func(): dialog.queue_free(), CONNECT_ONE_SHOT)

func _confirm_delete_row(row_index: int):
	var data_type = _get_data_type()
	match data_type:
		"object_collection":
			_delete_row_from_object_collection(row_index)
		"key_value_pairs":
			_delete_row_from_key_value_pairs(row_index)
		"simple_array":
			_delete_row_from_simple_array(row_index)
		"object_array":
			_delete_row_from_object_array(row_index)

# ===== 对象集合模式的行操作 =====
func _add_row_to_object_collection(row_index: int):
	print("对象集合模式 - 添加行到索引: ", row_index)

	# 对象集合模式的说明：Dictionary无法直接在指定位置插入
	# 但我们可以通过重建有序数据来模拟这个效果

	# 生成新的ID
	var new_id = _generate_unique_id()
	var new_obj = {}

	# 为新对象创建默认值
	for i in range(1, headers.size()):  # 跳过ID列
		var column_name = headers[i]
		new_obj[column_name] = _get_default_value_for_type(column_types[i])

	# 创建新的有序数据字典，基于当前表格显示的行顺序
	var new_data = {}

	# 获取当前表格中实际显示的行顺序（从rows_data中获取ID）
	var current_row_keys: Array[String] = []
	for row in rows_data:
		if row.size() > 0:
			current_row_keys.append(row[0])  # 第一列是ID

	# 根据row_index插入新项目
	var inserted = false
	for i in range(current_row_keys.size()):
		if i == row_index and not inserted:
			new_data[new_id] = new_obj
			inserted = true
			print("在位置 ", i, " 插入新对象，ID: ", new_id)

		var key = current_row_keys[i]
		new_data[key] = current_data[key]

	# 如果还没有插入（row_index超出范围），则添加到末尾
	if not inserted:
		new_data[new_id] = new_obj
		print("在末尾添加新对象，ID: ", new_id)

	# 更新数据
	current_data = new_data
	print("已添加新对象，ID: ", new_id, ", 数据: ", new_obj)

	# 重建表格
	await setup_data(current_data)
	data_changed.emit(current_data)

func _copy_row_in_object_collection(row_index: int, row_to_copy: Array):
	print("对象集合模式 - 复制行索引: ", row_index)

	if row_to_copy.is_empty():
		print("错误：要复制的行数据为空")
		return

	var original_id = row_to_copy[0]
	var original_obj = current_data.get(original_id)
	if not original_obj:
		print("错误：找不到原始对象，ID: ", original_id)
		return

	# 生成新的ID
	var new_id = _generate_unique_id()
	var new_obj = original_obj.duplicate(true)

	# 添加到数据中
	current_data[new_id] = new_obj
	print("已复制对象，原ID: ", original_id, ", 新ID: ", new_id)

	# 重建表格
	await setup_data(current_data)
	data_changed.emit(current_data)

func _delete_row_from_object_collection(row_index: int):
	print("对象集合模式 - 删除行索引: ", row_index)

	if row_index >= rows_data.size():
		print("错误：行索引超出范围: ", row_index, "/", rows_data.size())
		return

	var id_to_delete = rows_data[row_index][0]
	current_data.erase(id_to_delete)
	print("已删除对象，ID: ", id_to_delete)

	# 重建表格
	await setup_data(current_data)
	data_changed.emit(current_data)

# ===== 键值对模式的行操作 =====
func _add_row_to_key_value_pairs(row_index: int):
	print("键值对模式 - 添加行到索引: ", row_index)

	var new_key = _generate_unique_key()
	var new_value = _get_default_value_for_type(column_types[1])

	# 创建新的有序数据字典，基于当前表格显示的行顺序
	var new_data = {}

	# 获取当前表格中实际显示的行顺序（从rows_data中获取键）
	var current_row_keys: Array[String] = []
	for row in rows_data:
		if row.size() > 0:
			current_row_keys.append(row[0])  # 第一列是键

	# 根据row_index插入新键值对
	var inserted = false
	for i in range(current_row_keys.size()):
		if i == row_index and not inserted:
			new_data[new_key] = new_value
			inserted = true
			print("在位置 ", i, " 插入新键值对，键: ", new_key)

		var key = current_row_keys[i]
		new_data[key] = current_data[key]

	# 如果还没有插入，则添加到末尾
	if not inserted:
		new_data[new_key] = new_value
		print("在末尾添加新键值对，键: ", new_key)

	# 更新数据
	current_data = new_data
	print("已添加新键值对，键: ", new_key, ", 值: ", new_value)

	# 重建表格
	await setup_data(current_data)
	data_changed.emit(current_data)

func _copy_row_in_key_value_pairs(row_index: int, row_to_copy: Array):
	print("键值对模式 - 复制行索引: ", row_index)

	if row_to_copy.size() < 2:
		print("错误：要复制的行数据不完整")
		return

	var original_key = row_to_copy[0]
	var original_value = current_data.get(original_key)

	var new_key = _generate_unique_key()
	current_data[new_key] = original_value
	print("已复制键值对，原键: ", original_key, ", 新键: ", new_key, ", 值: ", original_value)

	# 重建表格
	await setup_data(current_data)
	data_changed.emit(current_data)

func _delete_row_from_key_value_pairs(row_index: int):
	print("键值对模式 - 删除行索引: ", row_index)

	if row_index >= rows_data.size():
		print("错误：行索引超出范围: ", row_index, "/", rows_data.size())
		return

	var key_to_delete = rows_data[row_index][0]
	current_data.erase(key_to_delete)
	print("已删除键值对，键: ", key_to_delete)

	# 重建表格
	await setup_data(current_data)
	data_changed.emit(current_data)

# ===== 简单数组模式的行操作 =====
func _add_row_to_simple_array(row_index: int):
	print("简单数组模式 - 添加行到索引: ", row_index)

	var new_value = _get_default_value_for_type(column_types[1])

	if row_index >= current_data.size():
		current_data.append(new_value)
		print("已在数组末尾添加新值: ", new_value)
	else:
		current_data.insert(row_index, new_value)
		print("已在索引 ", row_index, " 插入新值: ", new_value)

	# 重建表格
	await setup_data(current_data)
	data_changed.emit(current_data)

func _copy_row_in_simple_array(row_index: int, row_to_copy: Array):
	print("简单数组模式 - 复制行索引: ", row_index)

	if row_index >= current_data.size():
		print("错误：行索引超出范围: ", row_index, "/", current_data.size())
		return

	if row_to_copy.size() < 2:
		print("错误：要复制的行数据不完整")
		return

	var value_to_copy = current_data[row_index]
	current_data.insert(row_index + 1, value_to_copy)
	print("已复制数组元素，索引 ", row_index, " 的值 ", value_to_copy, " 到索引 ", row_index + 1)

	# 重建表格
	await setup_data(current_data)
	data_changed.emit(current_data)

func _delete_row_from_simple_array(row_index: int):
	print("简单数组模式 - 删除行索引: ", row_index)

	if row_index >= current_data.size():
		print("错误：行索引超出范围: ", row_index, "/", current_data.size())
		return

	var deleted_value = current_data[row_index]
	current_data.remove_at(row_index)
	print("已删除数组元素，索引 ", row_index, " 的值: ", deleted_value)

	# 重建表格
	await setup_data(current_data)
	data_changed.emit(current_data)

# ===== 对象数组模式的行操作 =====
func _add_row_to_object_array(row_index: int):
	print("对象数组模式 - 添加行到索引: ", row_index)

	var new_obj = {}

	# 为新对象创建默认值
	for i in range(headers.size()):
		var column_name = headers[i]
		new_obj[column_name] = _get_default_value_for_type(column_types[i])

	if row_index >= current_data.size():
		current_data.append(new_obj)
		print("已在数组末尾添加新对象: ", new_obj)
	else:
		current_data.insert(row_index, new_obj)
		print("已在索引 ", row_index, " 插入新对象: ", new_obj)

	# 重建表格
	await setup_data(current_data)
	data_changed.emit(current_data)

func _copy_row_in_object_array(row_index: int, row_to_copy: Array):
	print("对象数组模式 - 复制行索引: ", row_index)

	if row_index >= current_data.size():
		print("错误：行索引超出范围: ", row_index, "/", current_data.size())
		return

	var obj_to_copy = current_data[row_index]
	if typeof(obj_to_copy) == TYPE_DICTIONARY:
		var new_obj = obj_to_copy.duplicate(true)
		current_data.insert(row_index + 1, new_obj)
		print("已复制对象，从索引 ", row_index, " 到索引 ", row_index + 1, ", 对象: ", new_obj)

		# 重建表格
		await setup_data(current_data)
		data_changed.emit(current_data)
	else:
		print("错误：要复制的元素不是对象类型")

func _delete_row_from_object_array(row_index: int):
	print("对象数组模式 - 删除行索引: ", row_index)

	if row_index >= current_data.size():
		print("错误：行索引超出范围: ", row_index, "/", current_data.size())
		return

	var deleted_obj = current_data[row_index]
	current_data.remove_at(row_index)
	print("已删除对象，索引 ", row_index, " 的对象: ", deleted_obj)

	# 重建表格
	await setup_data(current_data)
	data_changed.emit(current_data)

# ===== 辅助函数 =====
func _generate_unique_id() -> String:
	var base_name = "new_item"
	var counter = 1

	while current_data.has(base_name + "_" + str(counter)):
		counter += 1

	return base_name + "_" + str(counter)

func _generate_unique_key() -> String:
	var base_name = "new_key"
	var counter = 1

	while current_data.has(base_name + "_" + str(counter)):
		counter += 1

	return base_name + "_" + str(counter)

func _get_default_value_for_type(type_id: int) -> Variant:
	match type_id:
		0: # String
			return "新值"
		1: # Number
			return 0
		2: # Boolean
			return false
		_:
			return "新值"

# ===== 列标题编辑辅助函数 =====
func can_edit_column_name(column_index: int) -> bool:
	"""检查是否可以编辑指定列的名称"""
	var data_type = _get_data_type()

	match data_type:
		"object_collection":
			# 对象集合模式下，ID列不能编辑
			return column_index != 0
		"key_value_pairs":
			# 键值对模式下，键和值列都不能编辑（因为是固定结构）
			return false
		"simple_array":
			# 简单数组模式下，索引和值列都不能编辑
			return false
		"object_array":
			# 对象数组模式下，所有列都可以编辑
			return true
		_:
			return false

func rename_column(column_index: int, new_name: String) -> bool:
	"""重命名列"""
	if column_index >= headers.size():
		return false

	# 检查名称是否已存在
	if new_name in headers and headers.find(new_name) != column_index:
		return false

	var old_name = headers[column_index]
	print("重命名列 ", column_index, ": '", old_name, "' -> '", new_name, "'")

	# 更新数据中的键名
	_update_data_column_names(old_name, new_name)

	# 更新标题
	headers[column_index] = new_name

	# 重建表格
	await setup_data(current_data)
	data_changed.emit(current_data)
	return true

func _update_data_column_names(old_name: String, new_name: String):
	"""更新数据中的列名"""
	var data_type = _get_data_type()

	match data_type:
		"object_collection":
			# 对象集合模式：更新所有对象中的键名
			for key in current_data.keys():
				var obj = current_data[key]
				if typeof(obj) == TYPE_DICTIONARY and obj.has(old_name):
					var value = obj[old_name]
					obj.erase(old_name)
					obj[new_name] = value
		"object_array":
			# 对象数组模式：更新数组中所有对象的键名
			for item in current_data:
				if typeof(item) == TYPE_DICTIONARY and item.has(old_name):
					var value = item[old_name]
					item.erase(old_name)
					item[new_name] = value

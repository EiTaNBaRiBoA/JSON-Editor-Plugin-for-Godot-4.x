@tool
extends RefCounted
class_name TranslationManager

# 单例实例
static var instance = TranslationManager.new()

# 当前语言
static var current_language = "zh"

# 翻译字典
static var translations = {
	"zh": {
		# 通用UI
		"tree_view": "树形视图",
		"table_view": "表格视图",
		"tree_view_with_edit": "树形视图 (双击编辑):",
		"excel_style_table_view": "Excel风格表格视图:",
		"add_row": "添加行",
		"key": "键",
		"value": "值",
		"value_header": "值",
		"index": "索引",
		
		# 右键菜单
		"right_click_row_menu": "右键显示行操作菜单",
		"add_new_row_before": "添加新行 (在此行之前)",
		"add_new_row_after": "添加新行 (在此行之后)",
		"copy_this_row": "复制此行",
		"delete_this_row": "删除此行",
		"enter_value": "输入值...",
		
		# 状态消息
		"data_modified_save_reminder": "数据已修改，请记得保存",
		"data_updated_prompt": "表格数据已更新，可以保存文件",
		"column_type_conversion_complete": "列类型转换完成",
		"column_name_changed_to": "列名已更改为",
		"column_type_converted_to": "列类型已转换为",
		"column_edit_completed": "列编辑完成",
		"table_component_not_ready": "表格组件未准备好",
		"column_conversion_status": "第%s列已%s为%s类型",
		
		# 编辑对话框
		"edit_column": "编辑列",
		"column_index": "列索引",
		"current_type": "当前类型",
		"column_name": "列名称",
		"enter_new_column_name": "输入新的列名称",
		"cannot_modify_column_name": "此列的名称无法修改",
		"select_data_type_conversion": "选择数据类型转换",
		"conversion_preview": "转换预览",
		"select_type_to_preview": "选择类型查看转换预览...",
		"type_conversion_note": "注意: 类型转换将应用到该列的所有数据",
		"apply_changes": "应用更改",
		"force_convert": "强制转换",
		"cancel": "取消",
		"unknown": "未知",
		"double_click_edit_column_type": "双击编辑列类型: %s",
		
		# 数据类型
		"string_type": "字符串",
		"number_type": "数字",
		"boolean_type": "布尔值",
		"type_string": "字符串",
		"type_number": "数字", 
		"type_boolean": "布尔值",
		"type_integer": "整数",
		"type_float": "浮点数",
		"type_other": "其他",
		"string_type_full": "字符串 (String)",
		"number_type_full": "数字 (Number)",
		"boolean_type_full": "布尔值 (Boolean)",
		
		# 转换模式
		"smart_conversion": "智能转换",
		"force_conversion": "强制转换",
		"smart_conversion_result": "智能转换",
		"force_conversion_result": "强制转换",
		
		# 错误信息
		"operation_failed": "以下操作失败",
		"operation_error": "操作错误",
		"column_name_cannot_be_empty": "列名称不能为空",
		"column_name_exists_or_invalid": "已存在或无效",
		"cannot_rename_column": "无法重命名列",
		"invalid_column_index": "无效的列索引",
		"no_convertible_data_found": "没有找到可转换的数据",
		"cannot_get_preview": "无法获取预览",
		
		# 删除确认
		"confirm_delete": "确认删除",
		"confirm_delete_row": "确定要删除第 %d 行吗？\n此操作无法撤销。",
		
		# 类型转换预览
		"conversion_preview_header": "转换预览 (前{count}项)",
		
		# 调试信息
		"start_conversion": "开始%s列 %s (%s) 到类型 %s",
		"conversion_complete": "列类型转换完成",
		"convert_column": "转换列: %s 到类型: %s (%s)",
		"convert_object": "转换 %s.%s: %s -> %s",
		"convert_value": "转换值 %s: %s -> %s",
		"convert_array": "转换数组[%s]: %s -> %s"
	},
	"en": {
		# 通用UI
		"tree_view": "Tree View",
		"table_view": "Table View",
		"tree_view_with_edit": "Tree View (Double-click to edit):",
		"excel_style_table_view": "Excel Style Table View:",
		"add_row": "Add Row",
		"key": "Key",
		"value": "Value",
		"value_header": "Value",
		"index": "Index",
		
		# 右键菜单
		"right_click_row_menu": "Right-click to show row operations menu",
		"add_new_row_before": "Add new row (before this row)",
		"add_new_row_after": "Add new row (after this row)",
		"copy_this_row": "Copy this row",
		"delete_this_row": "Delete this row",
		"enter_value": "Enter value...",
		
		# 状态消息
		"data_modified_save_reminder": "Data has been modified, remember to save",
		"data_updated_prompt": "Table data updated, ready to save file",
		"column_type_conversion_complete": "Column type conversion completed",
		"column_name_changed_to": "Column name changed to",
		"column_type_converted_to": "Column type converted to",
		"column_edit_completed": "Column editing completed",
		"table_component_not_ready": "Table component not ready",
		"column_conversion_status": "Column %s has been %s to %s type",
		
		# 编辑对话框
		"edit_column": "Edit Column",
		"column_index": "Column Index",
		"current_type": "Current Type",
		"column_name": "Column Name",
		"enter_new_column_name": "Enter new column name",
		"cannot_modify_column_name": "This column's name cannot be modified",
		"select_data_type_conversion": "Select data type conversion",
		"conversion_preview": "Conversion Preview",
		"select_type_to_preview": "Select type to view conversion preview...",
		"type_conversion_note": "Note: Type conversion will apply to all data in this column",
		"apply_changes": "Apply Changes",
		"force_convert": "Force Convert",
		"cancel": "Cancel",
		"unknown": "Unknown",
		"double_click_edit_column_type": "Double-click to edit column type: %s",
		
		# 数据类型
		"string_type": "String",
		"number_type": "Number",
		"boolean_type": "Boolean",
		"type_string": "String",
		"type_number": "Number", 
		"type_boolean": "Boolean",
		"type_integer": "Integer",
		"type_float": "Float",
		"type_other": "Other",
		"string_type_full": "String (String)",
		"number_type_full": "Number (Number)",
		"boolean_type_full": "Boolean (Boolean)",
		
		# 转换模式
		"smart_conversion": "Smart Conversion",
		"force_conversion": "Force Conversion",
		"smart_conversion_result": "Smart Conversion",
		"force_conversion_result": "Force Conversion",
		
		# 错误信息
		"operation_failed": "The following operations failed",
		"operation_error": "Operation Error",
		"column_name_cannot_be_empty": "Column name cannot be empty",
		"column_name_exists_or_invalid": "Column name already exists or is invalid",
		"cannot_rename_column": "Cannot rename column",
		"invalid_column_index": "Invalid column index",
		"no_convertible_data_found": "No convertible data found",
		"cannot_get_preview": "Cannot get preview",
		
		# 删除确认
		"confirm_delete": "Confirm Delete",
		"confirm_delete_row": "Are you sure you want to delete row %d?\nThis action cannot be undone.",
		
		# 类型转换预览
		"conversion_preview_header": "Conversion Preview (first {count} items)",
		
		# 调试信息
		"start_conversion": "Start %s column %s (%s) to type %s",
		"conversion_complete": "Column type conversion completed",
		"convert_column": "Convert column: %s to type: %s (%s)",
		"convert_object": "Convert %s.%s: %s -> %s",
		"convert_value": "Convert value %s: %s -> %s",
		"convert_array": "Convert array[%s]: %s -> %s"
	}
}

# 设置语言
static func set_language(language: String):
	if language in translations:
		current_language = language
		print("Language set to: ", language)

# 获取翻译文本
static func get_text(key: String) -> String:
	if current_language in translations and key in translations[current_language]:
		return translations[current_language][key]
	print("Translation missing for key: ", key, " in language: ", current_language)
	return key  # 如果没有找到翻译，返回原始key

# 获取当前语言
static func get_current_language() -> String:
	return current_language

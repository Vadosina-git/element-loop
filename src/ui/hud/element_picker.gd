class_name ElementPicker
extends PanelContainer

## Рулетка выбора стихии: 2 случайных варианта + отказ.

signal element_chosen(element: ElementTable.Element, from_position: Vector2)
signal choice_declined

var _option1: ElementTable.Element
var _option2: ElementTable.Element
var _btn1: Button = null
var _btn2: Button = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


## Показывает рулетку с двумя вариантами из доступных стихий.
func show_choices(available: Array) -> void:
	# Выбираем 2 случайных из доступных
	available.shuffle()
	_option1 = available[0] as ElementTable.Element
	_option2 = available[1 % available.size()] as ElementTable.Element

	# Пересоздаём содержимое
	for child: Node in get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	# Заголовок
	var title := Label.new()
	title.text = "Выбери стихию"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Кнопки стихий
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_row)

	_btn1 = _create_element_button(_option1, "[A]")
	_btn2 = _create_element_button(_option2, "[D]")
	btn_row.add_child(_btn1)
	btn_row.add_child(_btn2)

	# Кнопка отказа
	var decline_btn := Button.new()
	decline_btn.focus_mode = Control.FOCUS_NONE
	decline_btn.text = "Не сейчас [Esc]"
	decline_btn.add_theme_font_size_override("font_size", 30)
	decline_btn.pressed.connect(_on_decline)
	vbox.add_child(decline_btn)

	visible = true
	get_tree().paused = true


## Создаёт кнопку выбора стихии: иконка + подпись + клавиша.
func _create_element_button(element: ElementTable.Element, key_label: String) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(160, 170)
	btn.pressed.connect(_on_element_chosen.bind(element))

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	center.add_child(vbox)

	# Иконка стихии
	var tex: Texture2D = ElementIcons.get_texture(element)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon)

	# Название стихии
	var label := Label.new()
	label.text = ElementIcons.get_element_name(element)
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(label)

	# Подсказка клавиши
	var key := Label.new()
	key.text = key_label
	key.add_theme_font_size_override("font_size", 28)
	key.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.8))
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(key)

	return btn


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_A or key.physical_keycode == KEY_A or key.keycode == KEY_LEFT:
				get_viewport().set_input_as_handled()
				_on_element_chosen(_option1)
			elif key.keycode == KEY_D or key.physical_keycode == KEY_D or key.keycode == KEY_RIGHT:
				get_viewport().set_input_as_handled()
				_on_element_chosen(_option2)
			elif key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_on_decline()


func _on_element_chosen(element: ElementTable.Element) -> void:
	# Определяем позицию выбранной кнопки
	var btn: Button = _btn1 if element == _option1 else _btn2
	var from_pos: Vector2 = btn.global_position + btn.size / 2.0

	# Подсветка выбранной кнопки
	btn.modulate = Color(1.5, 1.5, 1.5, 1.0)

	visible = false
	get_tree().paused = false
	element_chosen.emit(element, from_pos)


func _on_decline() -> void:
	visible = false
	get_tree().paused = false
	choice_declined.emit()

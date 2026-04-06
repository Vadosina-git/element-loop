class_name LightingPanel
extends PanelContainer

## Панель настройки освещения с ползунками и пресетами.

signal settings_changed

var PRESETS: Dictionary = {
	"Cozy Grove": {
		"main_energy": 1.3, "main_color": Color.html("#FFE8C8"),
		"fill_energy": 0.25, "fill_color": Color.html("#B0C0E0"),
		"ambient_color": Color.html("#D4C8B0"), "ambient_energy": 0.6,
		"ssao_enabled": true, "ssao_intensity": 1.5,
		"glow_enabled": true, "glow_intensity": 0.3,
		"fog_enabled": true, "fog_density": 0.001,
		"bg_color": Color.html("#0A0806"),
	},
	"Осень": {
		"main_energy": 1.4, "main_color": Color.html("#FFD0A0"),
		"fill_energy": 0.2, "fill_color": Color.html("#A0B8D0"),
		"ambient_color": Color.html("#C8A878"), "ambient_energy": 0.5,
		"ssao_enabled": true, "ssao_intensity": 1.8,
		"glow_enabled": true, "glow_intensity": 0.4,
		"fog_enabled": true, "fog_density": 0.002,
		"bg_color": Color.html("#0C0804"),
	},
	"Вечер": {
		"main_energy": 0.9, "main_color": Color.html("#E8C8B0"),
		"fill_energy": 0.3, "fill_color": Color.html("#8090C0"),
		"ambient_color": Color.html("#A090A8"), "ambient_energy": 0.4,
		"ssao_enabled": true, "ssao_intensity": 2.0,
		"glow_enabled": true, "glow_intensity": 0.5,
		"fog_enabled": true, "fog_density": 0.003,
		"bg_color": Color.html("#060408"),
	},
	"Рассвет": {
		"main_energy": 1.5, "main_color": Color.html("#FFD8D0"),
		"fill_energy": 0.3, "fill_color": Color.html("#C0D0E8"),
		"ambient_color": Color.html("#E0C8C0"), "ambient_energy": 0.65,
		"ssao_enabled": true, "ssao_intensity": 1.0,
		"glow_enabled": true, "glow_intensity": 0.35,
		"fog_enabled": true, "fog_density": 0.001,
		"bg_color": Color.html("#100808"),
	},
	"Brawl Stars": {
		"main_energy": 1.8, "main_color": Color.html("#FFF0D0"),
		"fill_energy": 0.5, "fill_color": Color.html("#80D0FF"),
		"ambient_color": Color.html("#E0D8C0"), "ambient_energy": 1.5,
		"ssao_enabled": true, "ssao_intensity": 1.0,
		"glow_enabled": true, "glow_intensity": 0.5,
		"fog_enabled": false, "fog_density": 0.0,
		"bg_color": Color.html("#40A0E0"),
		"shadow_blur": 5.0, "light_angle_y": 130.0, "light_angle_x": -70.0,
	},
}

var _main_light: DirectionalLight3D = null
var _fill_light: DirectionalLight3D = null
var _environment: Environment = null
var _post_processing: PostProcessing = null
var _arena: ArenaView = null
var _outline_manager: OutlineManager = null
var _sliders: Dictionary = {}
var _content: VBoxContainer = null
var _is_open: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


## Подключает источники света и окружение.
func setup(main_light: DirectionalLight3D, fill_light: DirectionalLight3D, env: Environment, post_proc: PostProcessing = null, arena: ArenaView = null, outline_mgr: OutlineManager = null) -> void:
	_main_light = main_light
	_fill_light = fill_light
	_environment = env
	_post_processing = post_proc
	_arena = arena
	_outline_manager = outline_mgr


## Переключает видимость панели.
func toggle() -> void:
	_is_open = not _is_open
	if _is_open:
		_build_ui()
	visible = _is_open


## Строит UI панели.
func _build_ui() -> void:
	for child: Node in get_children():
		child.queue_free()
	_sliders.clear()

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	add_child(_content)

	# Заголовок
	var title := Label.new()
	title.text = "Освещение"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	# Пресеты
	var preset_row := HBoxContainer.new()
	preset_row.alignment = BoxContainer.ALIGNMENT_CENTER
	preset_row.add_theme_constant_override("separation", 6)
	_content.add_child(preset_row)
	for preset_name: String in PRESETS:
		var btn := Button.new()
		btn.text = preset_name
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_apply_preset.bind(preset_name))
		preset_row.add_child(btn)

	# Разделитель
	var sep := HSeparator.new()
	_content.add_child(sep)

	# Ползунки
	_add_slider("Основной свет", "main_energy", 0.0, 3.0, _main_light.light_energy)
	_add_slider("Угол света (Y)", "light_angle_y", 0.0, 360.0, _main_light.rotation_degrees.y)
	_add_slider("Высота света", "light_angle_x", -90.0, 0.0, _main_light.rotation_degrees.x)
	_add_slider("Заполняющий", "fill_energy", 0.0, 1.0, _fill_light.light_energy)
	_add_slider("Ambient", "ambient_energy", 0.0, 1.5, _environment.ambient_light_energy)
	_add_slider("SSAO", "ssao_intensity", 0.0, 5.0, _environment.ssao_intensity if _environment.ssao_enabled else 0.0)
	_add_slider("Glow", "glow_intensity", 0.0, 1.5, _environment.glow_intensity if _environment.glow_enabled else 0.0)
	_add_slider("Туман", "fog_density", 0.0, 0.02, _environment.fog_density if _environment.fog_enabled else 0.0)
	_add_slider("Тень blur", "shadow_blur", 0.0, 5.0, _main_light.shadow_blur)

	if _post_processing != null:
		var sep2 := HSeparator.new()
		_content.add_child(sep2)
		var pp_title := Label.new()
		pp_title.text = "Пост-обработка"
		pp_title.add_theme_font_size_override("font_size", 22)
		pp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(pp_title)
		_add_slider("Виньетка", "vignette", 0.0, 1.0, _post_processing.vignette_intensity)
		_add_slider("Виньетка цвет (чёрный↔белый)", "vignette_brightness", 0.0, 1.0, _post_processing.vignette_brightness)
		_add_slider("Десатурация", "desaturation", 0.0, 0.5, _post_processing.desaturation)
		_add_slider("Тёплый сдвиг", "warm_shift", 0.0, 0.3, _post_processing.warm_shift)
		_add_checkbox("Blur виньетка", "blur_vignette", _post_processing.blur_vignette_enabled)
		_add_checkbox("Контуры (экран)", "outline_screen", _post_processing.outline_enabled)
		_add_slider("Толщина (экран)", "outline_screen_thickness", 0.0, 5.0, _post_processing.outline_thickness)
		_add_slider("Цвет контура (экран)", "outline_screen_brightness", 0.0, 1.0, 0.1)

	if _outline_manager != null:
		var sep_ol := HSeparator.new()
		_content.add_child(sep_ol)
		var ol_title := Label.new()
		ol_title.text = "Контуры объектов"
		ol_title.add_theme_font_size_override("font_size", 22)
		ol_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(ol_title)
		_add_checkbox("Персонаж", "outline_player", true)
		_add_checkbox("Враги", "outline_enemies", true)
		_add_checkbox("Камни", "outline_rocks", false)
		_add_checkbox("Книги", "outline_books", true)
		_add_slider("Толщина", "outline_width", 0.0, 0.05, 0.03)
		_add_slider("Цвет (чёрный↔белый)", "outline_brightness", 0.0, 1.0, 0.0)



## Добавляет ползунок.
func _add_slider(label_text: String, key: String, min_val: float, max_val: float, current: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	label.custom_minimum_size = Vector2(140, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.01
	slider.value = current
	slider.custom_minimum_size = Vector2(200, 0)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_slider_changed.bind(key))
	row.add_child(slider)

	var val_label := Label.new()
	val_label.text = "%.2f" % current
	val_label.add_theme_font_size_override("font_size", 18)
	val_label.custom_minimum_size = Vector2(50, 0)
	row.add_child(val_label)

	_sliders[key] = {"slider": slider, "label": val_label}


## Добавляет чекбокс.
func _add_checkbox(label_text: String, key: String, current: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)

	var checkbox := CheckBox.new()
	checkbox.text = label_text
	checkbox.button_pressed = current
	checkbox.add_theme_font_size_override("font_size", 18)
	checkbox.focus_mode = Control.FOCUS_NONE
	checkbox.toggled.connect(_on_checkbox_toggled.bind(key))
	row.add_child(checkbox)


## Обработка чекбокса.
func _on_checkbox_toggled(enabled: bool, key: String) -> void:
	match key:
		"blur_vignette":
			if _post_processing != null:
				_post_processing.blur_vignette_enabled = enabled
		"outline_screen":
			if _post_processing != null:
				_post_processing.outline_enabled = enabled
		"outline_player":
			if _outline_manager != null:
				_outline_manager.set_category_enabled("Персонаж", enabled)
		"outline_enemies":
			if _outline_manager != null:
				_outline_manager.set_category_enabled("Враги", enabled)
		"outline_rocks":
			if _outline_manager != null:
				_outline_manager.set_category_enabled("Камни", enabled)
		"outline_books":
			if _outline_manager != null:
				_outline_manager.set_category_enabled("Книги", enabled)
	settings_changed.emit()


## Обработка изменения ползунка.
func _on_slider_changed(value: float, key: String) -> void:
	if _sliders.has(key):
		(_sliders[key]["label"] as Label).text = "%.2f" % value

	match key:
		"main_energy":
			_main_light.light_energy = value
		"light_angle_y":
			_main_light.rotation_degrees.y = value
		"light_angle_x":
			_main_light.rotation_degrees.x = value
		"fill_energy":
			_fill_light.light_energy = value
		"ambient_energy":
			_environment.ambient_light_energy = value
		"ssao_intensity":
			_environment.ssao_enabled = value > 0.01
			_environment.ssao_intensity = value
		"glow_intensity":
			_environment.glow_enabled = value > 0.01
			_environment.glow_intensity = value
		"fog_density":
			_environment.fog_enabled = value > 0.0001
			_environment.fog_density = value
		"shadow_blur":
			_main_light.shadow_blur = value
		"vignette":
			if _post_processing != null:
				_post_processing.vignette_intensity = value
		"desaturation":
			if _post_processing != null:
				_post_processing.desaturation = value
		"warm_shift":
			if _post_processing != null:
				_post_processing.warm_shift = value
		"vignette_brightness":
			if _post_processing != null:
				_post_processing.vignette_brightness = value
		"outline_screen_thickness":
			if _post_processing != null:
				_post_processing.outline_thickness = value
		"outline_screen_brightness":
			if _post_processing != null:
				_post_processing.outline_color = Color(value, value, value)
		"outline_width":
			if _outline_manager != null:
				_outline_manager.set_width(value)
		"outline_brightness":
			if _outline_manager != null:
				_outline_manager.set_color(Color(value, value, value))

	settings_changed.emit()


## Применяет пресет.
func _apply_preset(preset_name: String) -> void:
	var p: Dictionary = PRESETS[preset_name]

	_main_light.light_energy = p["main_energy"] as float
	_main_light.light_color = p["main_color"] as Color
	_fill_light.light_energy = p["fill_energy"] as float
	_fill_light.light_color = p["fill_color"] as Color

	_environment.ambient_light_color = p["ambient_color"] as Color
	_environment.ambient_light_energy = p["ambient_energy"] as float
	_environment.background_color = p["bg_color"] as Color

	_environment.ssao_enabled = p["ssao_enabled"] as bool
	_environment.ssao_intensity = p["ssao_intensity"] as float

	_environment.glow_enabled = p["glow_enabled"] as bool
	_environment.glow_intensity = p["glow_intensity"] as float

	_environment.fog_enabled = p["fog_enabled"] as bool
	_environment.fog_density = p["fog_density"] as float

	# Дополнительные параметры (если есть в пресете)
	if p.has("shadow_blur"):
		_main_light.shadow_blur = p["shadow_blur"] as float
		_update_slider("shadow_blur", p["shadow_blur"] as float)
	if p.has("light_angle_y"):
		_main_light.rotation_degrees.y = p["light_angle_y"] as float
		_update_slider("light_angle_y", p["light_angle_y"] as float)
	if p.has("light_angle_x"):
		_main_light.rotation_degrees.x = p["light_angle_x"] as float
		_update_slider("light_angle_x", p["light_angle_x"] as float)

	# Обновляем ползунки
	_update_slider("main_energy", p["main_energy"] as float)
	_update_slider("fill_energy", p["fill_energy"] as float)
	_update_slider("ambient_energy", p["ambient_energy"] as float)
	_update_slider("ssao_intensity", p["ssao_intensity"] as float)
	_update_slider("glow_intensity", p["glow_intensity"] as float)
	_update_slider("fog_density", p["fog_density"] as float)

	settings_changed.emit()


## Обновляет значение ползунка без вызова сигнала.
func _update_slider(key: String, value: float) -> void:
	if _sliders.has(key):
		var slider: HSlider = _sliders[key]["slider"] as HSlider
		slider.set_value_no_signal(value)
		(_sliders[key]["label"] as Label).text = "%.2f" % value

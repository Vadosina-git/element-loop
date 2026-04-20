class_name SettingsPopup
extends Control

## Попап настроек: пока содержит только кнопку Privacy Policy.
## Работает на паузе, чтобы можно было открыть в любой момент.

# --- Константы ---

const PRIVACY_POLICY_URL: String = "https://vadosina-git.github.io/privacy-policy/boxmaster-privacy.html"


# --- Встроенные колбеки ---

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


# --- Публичные методы ---

func open() -> void:
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


# --- Приватные методы ---

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0A1F0A")
	style.set_border_width_all(3)
	style.border_color = Color("F0C850")
	style.set_corner_radius_all(16)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260.0
	panel.offset_top = -160.0
	panel.offset_right = 260.0
	panel.offset_bottom = 160.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var title := Label.new()
	title.text = Translations.tr_key("settings.title")
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("F0C850"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var privacy_btn := _make_button(Translations.tr_key("settings.privacy_policy"), Color("1A6A2A"))
	privacy_btn.pressed.connect(func() -> void:
		OS.shell_open(PRIVACY_POLICY_URL)
	)
	col.add_child(privacy_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	col.add_child(spacer)

	var close_btn := _make_button(Translations.tr_key("settings.close"), Color("5A1A1A"))
	close_btn.pressed.connect(close)
	col.add_child(close_btn)


func _make_button(label: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(200, 52)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.focus_mode = Control.FOCUS_NONE
	var st := StyleBoxFlat.new()
	st.bg_color = bg_color
	st.set_border_width_all(2)
	st.border_color = Color(1, 1, 1, 0.3)
	st.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_stylebox_override("focus", st)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return btn

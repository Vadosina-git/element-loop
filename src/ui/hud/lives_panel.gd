class_name LivesPanel
extends PanelContainer

## Панель отображения глобальных жизней игрока.
##
## Подписывается на LivesManager.lives_changed и обновляет счётчик.
## Показывает таймер до следующей регенерации. Кнопка "+" открывает
## Shop overlay через сигнал shop_requested.

# --- Сигналы ---

signal shop_requested


# --- Приватные переменные ---

var _lives_label: Label = null
var _regen_label: Label = null
var _plus_button: Button = null


# --- Встроенные колбеки ---

func _ready() -> void:
	_build()
	LivesManager.lives_changed.connect(_on_lives_changed)
	LivesManager.regen_timer_updated.connect(_on_regen_updated)
	_on_lives_changed(LivesManager.get_lives(), LivesManager.is_unlimited())


func _process(_delta: float) -> void:
	# Обновляем таймер каждый кадр (чтобы счётчик "тикал" плавно)
	_update_regen_label(LivesManager.get_seconds_to_next_regen())


# --- Приватные методы ---

func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var heart := TextureRect.new()
	heart.texture = ElementIcons.get_heart_texture()
	heart.custom_minimum_size = Vector2(48, 48)
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(heart)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	root.add_child(col)

	_lives_label = Label.new()
	_lives_label.add_theme_font_size_override("font_size", 36)
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1.0))
	_lives_label.text = "5"
	col.add_child(_lives_label)

	_regen_label = Label.new()
	_regen_label.add_theme_font_size_override("font_size", 18)
	_regen_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
	_regen_label.text = ""
	col.add_child(_regen_label)

	_plus_button = Button.new()
	_plus_button.text = "+"
	_plus_button.custom_minimum_size = Vector2(48, 48)
	_plus_button.add_theme_font_size_override("font_size", 32)
	_plus_button.focus_mode = Control.FOCUS_NONE
	_plus_button.pressed.connect(func() -> void: shop_requested.emit())
	root.add_child(_plus_button)


func _on_lives_changed(lives: int, unlimited: bool) -> void:
	if unlimited:
		_lives_label.text = Translations.tr_key("lives.unlimited")
		_regen_label.text = ""
		_plus_button.visible = false
	else:
		_lives_label.text = str(lives)
		_plus_button.visible = true
		_update_regen_label(LivesManager.get_seconds_to_next_regen())


func _on_regen_updated(seconds_left: float) -> void:
	_update_regen_label(seconds_left)


func _update_regen_label(seconds_left: float) -> void:
	if LivesManager.is_unlimited():
		_regen_label.text = ""
		return
	if seconds_left <= 0.0:
		_regen_label.text = ""
		return
	var m: int = int(seconds_left) / 60
	var s: int = int(seconds_left) % 60
	var time_str: String = "%d:%02d" % [m, s]
	_regen_label.text = Translations.tr_key("lives.regen_in") % time_str

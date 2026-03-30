class_name VirtualJoystick
extends Control

## Виртуальный джойстик для мобильного управления.
##
## Активируется только при касании левой половины экрана.
## Возвращает нормализованный вектор направления.

# --- Сигналы ---
signal direction_changed(direction: Vector2)

# --- Константы ---
const DEAD_ZONE: float = 0.1
const MAX_RADIUS: float = 60.0
const BASE_SIZE: float = 120.0
const KNOB_SIZE: float = 40.0

# --- Приватные переменные ---
var _touch_index: int = -1
var _output: Vector2 = Vector2.ZERO

# --- @onready переменные ---
@onready var _base: TextureRect = $Base
@onready var _knob: TextureRect = $Base/Knob


# --- Встроенные колбеки ---

func _ready() -> void:
	_setup_textures()
	_base.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_on_touch_start(touch)
		else:
			_on_touch_end(touch)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_on_touch_drag(drag)


# --- Публичные методы ---

## Возвращает текущее направление джойстика (нормализованный вектор).
func get_direction() -> Vector2:
	return _output


# --- Приватные методы ---

## Создаёт программные текстуры для базы и ручки джойстика.
func _setup_textures() -> void:
	# Текстура базы — полупрозрачный круг
	var base_image := Image.create(int(BASE_SIZE), int(BASE_SIZE), false, Image.FORMAT_RGBA8)
	var base_center := Vector2(BASE_SIZE * 0.5, BASE_SIZE * 0.5)
	var base_radius: float = BASE_SIZE * 0.5
	for x: int in range(int(BASE_SIZE)):
		for y: int in range(int(BASE_SIZE)):
			var dist: float = Vector2(float(x), float(y)).distance_to(base_center)
			if dist <= base_radius:
				base_image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.15))
			else:
				base_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	var base_texture := ImageTexture.create_from_image(base_image)
	_base.texture = base_texture
	_base.custom_minimum_size = Vector2(BASE_SIZE, BASE_SIZE)
	_base.size = Vector2(BASE_SIZE, BASE_SIZE)
	_base.pivot_offset = Vector2(BASE_SIZE * 0.5, BASE_SIZE * 0.5)

	# Текстура ручки — менее прозрачный круг
	var knob_image := Image.create(int(KNOB_SIZE), int(KNOB_SIZE), false, Image.FORMAT_RGBA8)
	var knob_center := Vector2(KNOB_SIZE * 0.5, KNOB_SIZE * 0.5)
	var knob_radius: float = KNOB_SIZE * 0.5
	for x: int in range(int(KNOB_SIZE)):
		for y: int in range(int(KNOB_SIZE)):
			var dist: float = Vector2(float(x), float(y)).distance_to(knob_center)
			if dist <= knob_radius:
				knob_image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.4))
			else:
				knob_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	var knob_texture := ImageTexture.create_from_image(knob_image)
	_knob.texture = knob_texture
	_knob.custom_minimum_size = Vector2(KNOB_SIZE, KNOB_SIZE)
	_knob.size = Vector2(KNOB_SIZE, KNOB_SIZE)
	# Центрируем ручку внутри базы
	_knob.position = Vector2(
		(BASE_SIZE - KNOB_SIZE) * 0.5,
		(BASE_SIZE - KNOB_SIZE) * 0.5
	)


## Обработка начала касания — активация джойстика.
func _on_touch_start(touch: InputEventScreenTouch) -> void:
	if _touch_index != -1:
		return
	# Только левая половина экрана
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if touch.position.x > viewport_size.x * 0.5:
		return
	_touch_index = touch.index
	_base.visible = true
	_base.global_position = touch.position - Vector2(BASE_SIZE * 0.5, BASE_SIZE * 0.5)
	_knob.position = Vector2(
		(BASE_SIZE - KNOB_SIZE) * 0.5,
		(BASE_SIZE - KNOB_SIZE) * 0.5
	)
	_output = Vector2.ZERO
	direction_changed.emit(_output)


## Обработка конца касания — деактивация джойстика.
func _on_touch_end(touch: InputEventScreenTouch) -> void:
	if touch.index != _touch_index:
		return
	_touch_index = -1
	_base.visible = false
	_output = Vector2.ZERO
	direction_changed.emit(_output)


## Обработка перетаскивания — обновление направления.
func _on_touch_drag(drag: InputEventScreenDrag) -> void:
	if drag.index != _touch_index:
		return
	var base_center: Vector2 = _base.global_position + Vector2(BASE_SIZE * 0.5, BASE_SIZE * 0.5)
	var diff: Vector2 = drag.position - base_center
	var dist: float = diff.length()

	# Ограничиваем ручку максимальным радиусом
	if dist > MAX_RADIUS:
		diff = diff.normalized() * MAX_RADIUS

	# Позиция ручки относительно базы
	_knob.position = Vector2(
		(BASE_SIZE - KNOB_SIZE) * 0.5 + diff.x,
		(BASE_SIZE - KNOB_SIZE) * 0.5 + diff.y
	)

	# Нормализованный вывод с мёртвой зоной
	var normalized: Vector2 = diff / MAX_RADIUS
	if normalized.length() < DEAD_ZONE:
		_output = Vector2.ZERO
	else:
		_output = normalized.normalized() * ((normalized.length() - DEAD_ZONE) / (1.0 - DEAD_ZONE))

	direction_changed.emit(_output)

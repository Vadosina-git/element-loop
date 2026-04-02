class_name PlayerInput
extends Node

## Обработчик ввода игрока.
##
## Поддерживает два режима навигации: виртуальный джойстик (приоритет)
## и tap-to-move. Джойстик перехватывает управление, если отклонение > 0.1.

# --- Сигналы ---
signal zone_button_pressed()
signal dash_pressed()

# --- Константы ---
const TAP_ARRIVE_DISTANCE: float = 0.3

# --- Приватные переменные ---
var _player: PlayerCharacter = null
var _joystick: VirtualJoystick = null
var _camera: Camera3D = null
var _tap_target: Vector3 = Vector3.ZERO
var _has_tap_target: bool = false


# --- Публичные методы ---

## Инициализирует систему ввода. Вызывать после добавления в дерево.
func setup(player: PlayerCharacter, joystick: VirtualJoystick, camera: Camera3D) -> void:
	_player = player
	_joystick = joystick
	_camera = camera


# --- Встроенные колбеки ---

func _process(_delta: float) -> void:
	if _player == null:
		return

	# Во время рывка — не обрабатываем движение
	if _player._is_dashing:
		return

	# Приоритет: клавиатура > джойстик > tap-to-move
	var kb_dir: Vector2 = _get_keyboard_direction()
	if kb_dir.length() > 0.1:
		var direction := Vector3(kb_dir.x, 0.0, kb_dir.y)
		_player.set_move_direction(direction)
		_has_tap_target = false
		return

	if _joystick != null:
		var joy_dir: Vector2 = _joystick.get_direction()
		if joy_dir.length() > 0.1:
			var direction := Vector3(joy_dir.x, 0.0, joy_dir.y)
			_player.set_move_direction(direction)
			_has_tap_target = false
			return

	# Tap-to-move
	if _has_tap_target:
		var to_target: Vector3 = _tap_target - _player.global_position
		to_target.y = 0.0
		if to_target.length() < TAP_ARRIVE_DISTANCE:
			_has_tap_target = false
			_player.set_move_direction(Vector3.ZERO)
		else:
			_player.set_move_direction(to_target)
		return

	# Нет ввода — остановка
	_player.set_move_direction(Vector3.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if _player == null:
		return

	# Клавиатура — пробел (зона) и Shift (рывок)
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_SPACE:
				zone_button_pressed.emit()
				get_viewport().set_input_as_handled()
				return
			if key_event.keycode == KEY_SHIFT:
				dash_pressed.emit()
				get_viewport().set_input_as_handled()
				return

	if _camera == null:
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if not touch_event.pressed:
			return
		# Тап в правой половине экрана — tap-to-move
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		if touch_event.position.x > viewport_size.x * 0.5:
			_handle_tap(touch_event.position)


# --- Приватные методы ---

## Считывает направление с клавиатуры (WASD / стрелки).
func _get_keyboard_direction() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	return dir.normalized()


## Рейкаст от камеры к плоскости Y=0 для определения точки tap-to-move.
func _handle_tap(screen_pos: Vector2) -> void:
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = _camera.project_ray_normal(screen_pos)

	# Пересечение с плоскостью Y=0
	if absf(ray_dir.y) < 0.001:
		return
	var t: float = -ray_origin.y / ray_dir.y
	if t < 0.0:
		return
	_tap_target = ray_origin + ray_dir * t
	_tap_target.y = 0.0
	_has_tap_target = true

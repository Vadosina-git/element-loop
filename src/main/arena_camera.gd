class_name ArenaCamera
extends Camera3D

## Камера арены: следит за игроком, несколько пресетов.
##
## Плавно следует за целью (игроком). Поддерживает переключение
## между пресетами с анимацией перехода.

# --- Сигналы ---

signal preset_changed(preset_name: String)

# --- Константы ---

## Пресеты камеры: {имя: {angle, height, fov}}.
const PRESETS: Dictionary = {
	"Стандарт": {"angle": 48.0, "height": 10.7, "fov": 45.0},
	"Ближняя": {"angle": 55.0, "height": 10.0, "fov": 45.0},
	"Top-Down": {"angle": 80.0, "height": 16.0, "fov": 45.0},
	"Изометрия": {"angle": 35.0, "height": 12.0, "fov": 40.0},
}

## Скорость плавного следования за игроком.
const FOLLOW_SPEED: float = 5.0

## Скорость перехода между пресетами.
const TRANSITION_SPEED: float = 4.0

# --- Экспортируемые переменные ---

@export var arena_size: Vector2 = Vector2(36.0, 54.0)

# --- Публичные переменные ---

var current_preset: String = "Стандарт"

# --- Приватные переменные ---

var _follow_target: Node3D = null
var _target_angle: float = 50.0
var _target_height: float = 14.0
var _target_fov: float = 50.0
var _current_angle: float = 50.0
var _current_height: float = 14.0
var _is_transitioning: bool = false


# --- Встроенные колбеки ---

func _ready() -> void:
	set_as_top_level(true)
	_apply_immediate("Стандарт")


func _process(delta: float) -> void:
	# Переход между пресетами
	if _is_transitioning:
		_current_angle = lerpf(_current_angle, _target_angle, delta * TRANSITION_SPEED)
		_current_height = lerpf(_current_height, _target_height, delta * TRANSITION_SPEED)
		fov = lerpf(fov, _target_fov, delta * TRANSITION_SPEED)
		if absf(_current_angle - _target_angle) < 0.05 and absf(_current_height - _target_height) < 0.05:
			_current_angle = _target_angle
			_current_height = _target_height
			fov = _target_fov
			_is_transitioning = false

	# Следование за игроком
	var target_xz: Vector3 = Vector3.ZERO
	if _follow_target != null and is_instance_valid(_follow_target):
		target_xz = _follow_target.global_position
		target_xz.y = 0.0

	var angle_rad: float = deg_to_rad(_current_angle)
	var z_offset: float = _current_height / tan(angle_rad)
	var desired_pos: Vector3 = Vector3(target_xz.x, _current_height, target_xz.z + z_offset)

	global_position = global_position.lerp(desired_pos, delta * FOLLOW_SPEED)
	rotation_degrees.x = -_current_angle


# --- Публичные методы ---

## Задаёт цель для слежения (игрока). Мгновенно перемещает камеру.
func set_follow_target(target: Node3D) -> void:
	_follow_target = target
	if target != null:
		var target_xz: Vector3 = target.global_position
		target_xz.y = 0.0
		var angle_rad: float = deg_to_rad(_current_angle)
		var z_offset: float = _current_height / tan(angle_rad)
		global_position = Vector3(target_xz.x, _current_height, target_xz.z + z_offset)


## Обновляет размер арены (для будущих ограничений).
func update_for_arena(new_size: Vector2) -> void:
	arena_size = new_size


## Плавно переключает на пресет по имени.
func apply_preset(preset_name: String) -> void:
	if not PRESETS.has(preset_name):
		return
	current_preset = preset_name
	var p: Dictionary = PRESETS[preset_name]
	_target_angle = p["angle"] as float
	_target_height = p["height"] as float
	_target_fov = p["fov"] as float
	_is_transitioning = true
	preset_changed.emit(preset_name)


## Возвращает список имён всех пресетов.
func get_preset_names() -> Array[String]:
	var names: Array[String] = []
	for key: String in PRESETS.keys():
		names.append(key)
	return names


# --- Приватные методы ---

## Мгновенно применяет пресет (без анимации).
func _apply_immediate(preset_name: String) -> void:
	if not PRESETS.has(preset_name):
		return
	current_preset = preset_name
	var p: Dictionary = PRESETS[preset_name]
	_current_angle = p["angle"] as float
	_current_height = p["height"] as float
	_target_angle = _current_angle
	_target_height = _current_height
	_target_fov = p["fov"] as float
	fov = _target_fov
	rotation_degrees.x = -_current_angle
	_is_transitioning = false

	# Начальная позиция
	var target_xz: Vector3 = Vector3.ZERO
	if _follow_target != null and is_instance_valid(_follow_target):
		target_xz = _follow_target.global_position
		target_xz.y = 0.0
	var angle_rad: float = deg_to_rad(_current_angle)
	var z_offset: float = _current_height / tan(angle_rad)
	global_position = Vector3(target_xz.x, _current_height, target_xz.z + z_offset)

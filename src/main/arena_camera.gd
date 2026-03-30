class_name ArenaCamera
extends Camera3D

## Камера арены: top-down с лёгкой изометрией.
##
## Перспективная камера с углом 65° от горизонта.
## Автоматически рассчитывает позицию по размеру арены.

# --- Константы ---
const CAMERA_ANGLE_DEG: float = 65.0
const CAMERA_HEIGHT: float = 18.0
const CAMERA_FOV: float = 45.0

# --- Экспортируемые переменные ---
@export var arena_size: Vector2 = Vector2(12.0, 18.0)


# --- Встроенные колбеки ---
func _ready() -> void:
	_setup_camera()


# --- Публичные методы ---

## Обновляет позицию камеры под новый размер арены.
func update_for_arena(new_size: Vector2) -> void:
	arena_size = new_size
	_setup_camera()


# --- Приватные методы ---

## Настраивает параметры камеры: угол, высоту, FOV, позицию.
func _setup_camera() -> void:
	fov = CAMERA_FOV
	rotation_degrees.x = -CAMERA_ANGLE_DEG

	# Смещение по Z, чтобы камера смотрела в центр арены
	var angle_rad: float = deg_to_rad(CAMERA_ANGLE_DEG)
	var z_offset: float = CAMERA_HEIGHT / tan(angle_rad)

	position = Vector3(0.0, CAMERA_HEIGHT, z_offset)

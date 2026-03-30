class_name PlayerCharacter
extends CharacterBody3D

## Персонаж игрока.
##
## Управляет здоровьем, зарядами зон, движением и взаимодействием
## со стихиями. Не наносит урон напрямую — использует зоны.

# --- Сигналы ---
signal hp_changed(new_hp: int)
signal element_changed(new_element: int)
signal zone_placed(element: int, position: Vector3)
signal died()

# --- Константы ---
const MOVE_SPEED: float = 5.0
const MAX_HP: int = 2

# --- Публичные переменные ---
var hp: int = MAX_HP
## Текущая выбранная стихия. -1 означает «нет стихии».
var current_element: int = -1
var has_zone_charge: bool = false

# --- Приватные переменные ---
var _move_direction: Vector3 = Vector3.ZERO


# --- Встроенные колбеки ---

func _ready() -> void:
	_setup_collision()
	_setup_visual()


func _physics_process(_delta: float) -> void:
	velocity = _move_direction * MOVE_SPEED
	move_and_slide()


# --- Публичные методы ---

## Задаёт направление движения. Нормализует, если длина > 0.1.
## Также поворачивает персонажа в сторону движения.
func set_move_direction(direction: Vector3) -> void:
	if direction.length() > 0.1:
		_move_direction = direction.normalized()
		var look_target: Vector3 = global_position + _move_direction
		look_target.y = global_position.y
		look_at(look_target, Vector3.UP)
	else:
		_move_direction = Vector3.ZERO


## Подбирает стихию из книги. Устанавливает заряд зоны.
func pickup_element(element: int) -> void:
	current_element = element
	has_zone_charge = true
	element_changed.emit(current_element)


## Ставит зону текущей стихии под собой.
## Возвращает true при успехе, false если нет заряда.
func place_zone() -> bool:
	if not has_zone_charge:
		return false
	var placed_element: int = current_element
	var placed_position: Vector3 = global_position
	has_zone_charge = false
	current_element = -1
	zone_placed.emit(placed_element, placed_position)
	element_changed.emit(current_element)
	return true


## Наносит урон игроку. При 0 HP эмитит сигнал смерти.
func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	hp_changed.emit(hp)
	if hp <= 0:
		died.emit()


## Лечит игрока. HP не превышает MAX_HP.
func heal(amount: int) -> void:
	hp = mini(MAX_HP, hp + amount)
	hp_changed.emit(hp)


# --- Приватные методы ---

## Создаёт коллизию: капсула (radius=0.3, height=1.2).
func _setup_collision() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.2
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 0.6, 0.0)
	add_child(collision)


## Создаёт визуал: капсула-меш (синий цвет).
func _setup_visual() -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.2
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.6, 0.9)
	mesh.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, 0.6, 0.0)
	add_child(mesh_instance)

class_name BookObject
extends Node3D

## Книга — источник стихии.
##
## Игрок подходит, удерживает взаимодействие 1 сек,
## получает случайную стихию для постановки зоны.
## После использования книга исчезает и респаунится через 2 сек.

# --- Сигналы ---

signal element_picked(element: ElementTable.Element)

# --- Константы ---

const HOLD_DURATION: float = 1.0
const RESPAWN_DELAY: float = 2.0
const INTERACTION_RADIUS: float = 1.5

# --- Приватные переменные ---

var _is_active: bool = true
var _hold_timer: float = 0.0
var _is_holding: bool = false
var _respawn_timer: float = 0.0
var _player_in_range: bool = false

# --- @onready переменные ---

@onready var _area: Area3D = $Area3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D


# --- Встроенные колбеки ---

func _ready() -> void:
	_setup_visual()
	_setup_collision()
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if not _is_active:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	if _is_holding and _player_in_range:
		_hold_timer += delta
		if _hold_timer >= HOLD_DURATION:
			_activate()


# --- Публичные методы ---

## Начинает удержание для активации книги.
func start_hold() -> void:
	if _is_active and _player_in_range:
		_is_holding = true
		_hold_timer = 0.0


## Прерывает удержание.
func stop_hold() -> void:
	_is_holding = false
	_hold_timer = 0.0


# --- Приватные методы ---

## Настраивает визуал книги (коричневый прямоугольник).
func _setup_visual() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.1, 0.4)
	_mesh.mesh = mesh
	_mesh.position.y = 0.5

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.5, 0.3)
	_mesh.material_override = material


## Настраивает зону взаимодействия (сфера).
func _setup_collision() -> void:
	var shape := SphereShape3D.new()
	shape.radius = INTERACTION_RADIUS

	var collision := CollisionShape3D.new()
	collision.shape = shape
	_area.add_child(collision)

	# Книга только обнаруживает тела, не участвует в физике
	_area.collision_layer = 0
	_area.collision_mask = 1  # Игрок на слое 1


## Активирует книгу: скрывает, выдаёт случайную стихию.
func _activate() -> void:
	_is_active = false
	_is_holding = false
	_hold_timer = 0.0
	_mesh.visible = false

	var random_element: ElementTable.Element = _get_random_element()
	element_picked.emit(random_element)

	_respawn_timer = RESPAWN_DELAY


## Респаунит книгу: показывает и делает активной.
func _respawn() -> void:
	_is_active = true
	_mesh.visible = true
	_respawn_timer = 0.0


## Возвращает случайную стихию из пяти.
func _get_random_element() -> ElementTable.Element:
	var elements: Array[ElementTable.Element] = [
		ElementTable.Element.FIRE,
		ElementTable.Element.WATER,
		ElementTable.Element.TREE,
		ElementTable.Element.EARTH,
		ElementTable.Element.METAL,
	]
	return elements[randi() % elements.size()]


# --- Колбеки сигналов ---

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerCharacter:
		_player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerCharacter:
		_player_in_range = false
		stop_hold()

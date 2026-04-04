class_name ZoneObject
extends Node3D

## Зона стихии на арене.
##
## Полупрозрачный цилиндр, обнаруживающий врагов через Area3D.
## Создаётся игроком, живёт бесконечно (удаляется по FIFO при переполнении).
## Цвет зависит от стихии.

# --- Сигналы ---

signal enemy_entered_zone(enemy: EnemyBase, zone: ZoneObject)
signal enemy_exited_zone(enemy: EnemyBase, zone: ZoneObject)

# --- Константы ---

const ZONE_LIFETIME: float = 7.0
const BLINK_START: float = 2.0
const BLINK_SPEED: float = 8.0

## Цвета стихий для визуального отображения зон.
const ELEMENT_COLORS: Dictionary = {
	ElementTable.Element.FIRE: Color(0.9, 0.2, 0.1),
	ElementTable.Element.WATER: Color(0.1, 0.4, 0.9),
	ElementTable.Element.TREE: Color(0.2, 0.7, 0.2),
	ElementTable.Element.EARTH: Color(0.6, 0.4, 0.2),
	ElementTable.Element.METAL: Color(0.7, 0.7, 0.7),
}

# --- Публичные переменные ---

var element: ElementTable.Element = ElementTable.Element.FIRE
var zone_radius: float = 1.5
var _lifetime_timer: float = 0.0

# --- @onready переменные ---

@onready var _area: Area3D = $Area3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D


# --- Встроенные колбеки ---

func _ready() -> void:
	# Визуал и коллизия настраиваются только если setup() уже вызван
	# (element задан). При создании через код setup() вызывается до
	# добавления в дерево, поэтому _ready() корректно использует element.
	_setup_visual()
	_setup_collision()
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_lifetime_timer = ZONE_LIFETIME


func _process(delta: float) -> void:
	_lifetime_timer -= delta

	# Мигание перед исчезновением
	if _lifetime_timer <= BLINK_START and _lifetime_timer > 0.0:
		var blink_on: bool = fmod(_lifetime_timer * BLINK_SPEED, 1.0) > 0.5
		_mesh.visible = blink_on
	elif _lifetime_timer <= 0.0:
		queue_free()
		return


# --- Публичные методы ---

## Настраивает зону: задаёт стихию и позицию.
## Вызывать ДО добавления в дерево сцен (add_child).
func setup(p_element: ElementTable.Element, p_position: Vector3) -> void:
	element = p_element
	position = p_position


# --- Приватные методы ---

## Настраивает визуал зоны (полупрозрачный цилиндр + подпись стихии).
func _setup_visual() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = zone_radius
	mesh.bottom_radius = zone_radius
	mesh.height = 0.05
	_mesh.mesh = mesh
	_mesh.position.y = 0.03

	var material := StandardMaterial3D.new()
	var color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	color.a = 0.4
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = material

	# Подпись стихии над зоной
	var label := Label3D.new()
	label.text = _get_element_name()
	label.font_size = 48
	label.position.y = 0.6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = ELEMENT_COLORS.get(element, Color.WHITE)
	label.no_depth_test = true
	add_child(label)


## Возвращает русское название стихии.
func _get_element_name() -> String:
	match element:
		ElementTable.Element.FIRE:
			return "Огонь"
		ElementTable.Element.WATER:
			return "Вода"
		ElementTable.Element.TREE:
			return "Дерево"
		ElementTable.Element.EARTH:
			return "Земля"
		ElementTable.Element.METAL:
			return "Металл"
	return "?"


## Настраивает коллизию для обнаружения врагов.
func _setup_collision() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = zone_radius
	shape.height = 1.0

	var collision := CollisionShape3D.new()
	collision.shape = shape
	_area.add_child(collision)

	# Зона только обнаруживает врагов, не участвует в физике
	_area.collision_layer = 0
	_area.collision_mask = 2  # Враги на слое 2


# --- Колбеки сигналов ---

func _on_body_entered(body: Node3D) -> void:
	if body is EnemyBase:
		enemy_entered_zone.emit(body, self)


func _on_body_exited(body: Node3D) -> void:
	if body is EnemyBase:
		enemy_exited_zone.emit(body, self)

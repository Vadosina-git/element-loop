class_name EnemyBase
extends CharacterBody3D

## Базовый враг.
##
## CharacterBody3D с навигацией, визуалом и AI (FSM).
## Все враги-архетипы наследуют этот скрипт.

# --- Сигналы ---

signal died(enemy: EnemyBase)
signal attacked_player(enemy: EnemyBase)

# --- Константы ---

## Цвета стихий для визуального отображения.
const ELEMENT_COLORS: Dictionary = {
	ElementTable.Element.FIRE: Color(0.9, 0.2, 0.1),
	ElementTable.Element.WATER: Color(0.1, 0.4, 0.9),
	ElementTable.Element.TREE: Color(0.2, 0.7, 0.2),
	ElementTable.Element.EARTH: Color(0.6, 0.4, 0.2),
	ElementTable.Element.METAL: Color(0.7, 0.7, 0.7),
}

# --- Экспортируемые переменные ---

@export var element: ElementTable.Element = ElementTable.Element.FIRE
@export var level: int = 1
@export var move_speed: float = 3.0
@export var attack_range: float = 1.5
@export var attack_damage: int = 1

# --- Публичные переменные ---

var hp: int = 1
var max_hp: int = 1
var is_marked: bool = false
var is_enraged: bool = false
var enemy_id: int = -1

# --- Приватные переменные ---

var _target: Node3D = null
var _material: StandardMaterial3D = null

# --- @onready переменные ---

@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _ai: EnemyAI = $EnemyAI
@onready var _mesh: MeshInstance3D = $MeshInstance3D

# --- Встроенные колбеки ---


func _ready() -> void:
	hp = max_hp
	_setup_visual()


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	if _ai.current_state != EnemyAI.State.CHASE:
		return
	# Обновляем цель навигации
	_nav_agent.target_position = _target.global_position
	if _nav_agent.is_navigation_finished():
		return

	var next_pos: Vector3 = _nav_agent.get_next_path_position()
	var direction: Vector3 = (next_pos - global_position).normalized()

	# Модификаторы скорости: ярость +25%, метка -25%
	var speed: float = move_speed
	if is_enraged:
		speed *= (1.0 + CombatLogic.RAGE_SPEED_BONUS)
	if is_marked:
		speed *= (1.0 - CombatLogic.MARK_SLOW)

	velocity = direction * speed
	move_and_slide()


# --- Публичные методы ---


## Установить цель для преследования.
func set_target(target: Node3D) -> void:
	_target = target


## Получить расстояние до цели.
func get_distance_to_target() -> float:
	if _target == null:
		return INF
	return global_position.distance_to(_target.global_position)


## Получить урон. При HP <= 0 испускает сигнал died.
func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		hp = 0
		died.emit(self)


## Наложить метку (замедление, визуальный эффект).
func apply_mark() -> void:
	is_marked = true
	if _material != null:
		_material.emission_enabled = true
		_material.emission = Color.WHITE
		_material.emission_energy_multiplier = 0.8


## Снять метку.
func remove_mark() -> void:
	is_marked = false
	if _material != null:
		_material.emission_enabled = false


## Наложить ярость (ускорение).
func apply_rage() -> void:
	is_enraged = true


## Снять ярость.
func remove_rage() -> void:
	is_enraged = false


# --- Приватные методы ---


## Настроить визуал: сфера с цветом стихии.
func _setup_visual() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8

	_material = StandardMaterial3D.new()
	_material.albedo_color = ELEMENT_COLORS.get(element, Color.WHITE)
	sphere.surface_set_material(0, _material)

	_mesh.mesh = sphere

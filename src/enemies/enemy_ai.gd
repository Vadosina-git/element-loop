class_name EnemyAI
extends Node

## Конечный автомат (FSM) AI врага.
##
## Состояния: Chase → Telegraph → Attack → Recover → Chase.
## Тайминги телеграфа зависят от уровня врага.

# --- Сигналы ---

signal state_changed(new_state: State)
signal attack_executed()

# --- Перечисления ---

enum State {
	CHASE,
	TELEGRAPH,
	ATTACK,
	RECOVER,
}

# --- Константы ---

## Длительность телеграфа по уровню врага (в секундах).
const TELEGRAPH_DURATIONS: Dictionary = {
	1: 2.0,
	2: 1.5,
	3: 1.0,
	4: 0.5,
}

## Длительность фазы атаки (в секундах).
const ATTACK_DURATION: float = 0.3

## Длительность фазы восстановления (в секундах).
const RECOVER_DURATION: float = 0.5

# --- Публичные переменные ---

var current_state: State = State.CHASE

# --- Приватные переменные ---

var _timer: float = 0.0
var _enemy: EnemyBase = null

# --- Встроенные колбеки ---


func _ready() -> void:
	_enemy = get_parent() as EnemyBase
	assert(_enemy != null, "EnemyAI должен быть дочерним узлом EnemyBase")


func _process(delta: float) -> void:
	if _enemy == null:
		return
	match current_state:
		State.CHASE:
			_process_chase()
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.ATTACK:
			_process_attack(delta)
		State.RECOVER:
			_process_recover(delta)


# --- Публичные методы ---


## Получить длительность телеграфа для текущего уровня врага.
func get_telegraph_duration() -> float:
	return TELEGRAPH_DURATIONS.get(_enemy.level, 2.0) as float


# --- Приватные методы ---


func _change_state(new_state: State) -> void:
	current_state = new_state
	_timer = 0.0
	state_changed.emit(new_state)


func _process_chase() -> void:
	if _enemy._target == null:
		return
	var distance: float = _enemy.get_distance_to_target()
	if distance <= _enemy.attack_range:
		_change_state(State.TELEGRAPH)


func _process_telegraph(delta: float) -> void:
	_timer += delta
	if _timer >= get_telegraph_duration():
		_change_state(State.ATTACK)


func _process_attack(delta: float) -> void:
	_timer += delta
	if _timer >= ATTACK_DURATION:
		attack_executed.emit()
		_enemy.attacked_player.emit(_enemy)
		_change_state(State.RECOVER)


func _process_recover(delta: float) -> void:
	_timer += delta
	if _timer >= RECOVER_DURATION:
		_change_state(State.CHASE)

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
	WANDER,
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
const RECOVER_DURATION: float = 1.0

## Время ожидания в точке патрулирования.
const WANDER_WAIT_MIN: float = 0.5
const WANDER_WAIT_MAX: float = 2.0

## Максимальная дистанция патрулирования от текущей позиции.
const WANDER_RADIUS: float = 4.0

# --- Публичные переменные ---

var current_state: State = State.WANDER

# --- Приватные переменные ---

var _timer: float = 0.0
var _enemy: EnemyBase = null
var _wander_target: Vector3 = Vector3.ZERO
var _wander_waiting: bool = false
var _wander_wait_duration: float = 1.0

# --- Встроенные колбеки ---


func _ready() -> void:
	_enemy = get_parent() as EnemyBase
	assert(_enemy != null, "EnemyAI должен быть дочерним узлом EnemyBase")


func _process(delta: float) -> void:
	if _enemy == null:
		return
	match current_state:
		State.WANDER:
			_process_wander(delta)
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


## Вызывается при столкновении с препятствием — немедленная смена направления.
func on_hit_obstacle() -> void:
	if current_state == State.WANDER:
		_enemy.set_wander_direction(Vector3.ZERO)
		_pick_wander_target()
		_wander_waiting = false


# --- Приватные методы ---


func _change_state(new_state: State) -> void:
	current_state = new_state
	_timer = 0.0
	_wander_waiting = false
	if new_state == State.WANDER:
		_pick_wander_target()
		_enemy.set_wander_direction(Vector3.ZERO)
	elif new_state != State.CHASE:
		_enemy.set_wander_direction(Vector3.ZERO)
	state_changed.emit(new_state)


## Выбирает случайную точку патрулирования рядом с врагом.
func _pick_wander_target() -> void:
	var half_x: float = 10.5  # Арена 24 - отступ
	var half_z: float = 16.5  # Арена 36 - отступ
	var pos: Vector3 = _enemy.global_position
	_wander_target = Vector3(
		clampf(pos.x + randf_range(-WANDER_RADIUS, WANDER_RADIUS), -half_x, half_x),
		0.0,
		clampf(pos.z + randf_range(-WANDER_RADIUS, WANDER_RADIUS), -half_z, half_z),
	)


func _process_wander(delta: float) -> void:
	# Проверяем, не вошёл ли игрок в зону обнаружения
	if _enemy._target != null:
		var dist: float = _enemy.get_distance_to_target()
		if dist <= _enemy.detection_range:
			_change_state(State.CHASE)
			return

	if _wander_waiting:
		_timer += delta
		if _timer >= _wander_wait_duration:
			_wander_waiting = false
			_pick_wander_target()
		return

	# Идём к точке патрулирования
	var to_target: Vector3 = _wander_target - _enemy.global_position
	to_target.y = 0.0
	if to_target.length() < 0.5:
		_wander_waiting = true
		_timer = 0.0
		_wander_wait_duration = randf_range(WANDER_WAIT_MIN, WANDER_WAIT_MAX)
		_enemy.set_wander_direction(Vector3.ZERO)
	else:
		_enemy.set_wander_direction(to_target.normalized())


func _process_chase() -> void:
	if _enemy._target == null:
		return
	var distance: float = _enemy.get_distance_to_target()

	# Игрок вышел из зоны обнаружения — вернуться к патрулированию
	if distance > _enemy.detection_range:
		_change_state(State.WANDER)
		return

	if distance <= _enemy.attack_range:
		# Урон наносится мгновенно при контакте
		attack_executed.emit()
		_enemy.attacked_player.emit(_enemy)
		_change_state(State.RECOVER)


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
		# После атаки: если игрок ушёл — патрулируем
		var dist: float = _enemy.get_distance_to_target()
		if dist > _enemy.detection_range:
			_change_state(State.WANDER)
		else:
			_change_state(State.CHASE)

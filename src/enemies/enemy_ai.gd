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
	SEARCH,
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

## Длительности фаз атаки и валидация попадания — теперь в подклассах через виртуалы:
## EnemyBase.get_telegraph_duration / get_attack_duration / resolve_attack_landing.

## Длительность фазы восстановления (в секундах).
const RECOVER_DURATION: float = 1.0

## Время ожидания в точке патрулирования.
const WANDER_WAIT_MIN: float = 0.5
const WANDER_WAIT_MAX: float = 2.0

## Максимальная дистанция патрулирования от текущей позиции.
const WANDER_RADIUS: float = 4.0

## Интервал проверки LoS (секунды).
const LOS_CHECK_INTERVAL: float = 0.2

## Интервал записи крошки при наличии LoS (секунды).
const BREADCRUMB_INTERVAL: float = 0.3

## Максимум хранимых крошек.
const MAX_BREADCRUMBS: int = 8

## Дистанция, на которой крошка считается «достигнутой».
const BREADCRUMB_REACH_DIST: float = 0.7

## Таймаут расследования: если враг не нашёл игрока — возвращается к патрулю.
const SEARCH_TIMEOUT: float = 4.0

# --- Публичные переменные ---

var current_state: State = State.WANDER

# --- Приватные переменные ---

var _timer: float = 0.0
var _enemy: EnemyBase = null
var _wander_target: Vector3 = Vector3.ZERO
var _wander_waiting: bool = false
var _wander_wait_duration: float = 1.0

# --- Линия зрения и крошки ---
var _los_timer: float = 0.0
var _has_los: bool = false
var _breadcrumb_timer: float = 0.0
var _breadcrumbs: Array[Vector3] = []
var _search_timer: float = 0.0

# --- Встроенные колбеки ---


func _ready() -> void:
	_enemy = get_parent() as EnemyBase
	assert(_enemy != null, "EnemyAI должен быть дочерним узлом EnemyBase")
	# Стаггеринг: распределяем фазу LoS-проверок и записи крошек по разным
	# врагам, чтобы 100 рейкастов не падали на один кадр.
	_los_timer = randf() * LOS_CHECK_INTERVAL
	_breadcrumb_timer = randf() * BREADCRUMB_INTERVAL


func _process(delta: float) -> void:
	if _enemy == null:
		return
	match current_state:
		State.WANDER:
			_process_wander(delta)
		State.CHASE:
			_process_chase(delta)
		State.SEARCH:
			_process_search(delta)
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.ATTACK:
			_process_attack(delta)
		State.RECOVER:
			_process_recover(delta)


# --- Публичные методы ---


## Получить длительность телеграфа — делегируется классу врага.
func get_telegraph_duration() -> float:
	return _enemy.get_telegraph_duration()


## Получить длительность фазы атаки — делегируется классу врага.
func get_attack_duration() -> float:
	return _enemy.get_attack_duration()


## Вызывается при столкновении с препятствием — немедленная смена направления.
func on_hit_obstacle() -> void:
	if current_state == State.WANDER:
		_enemy.set_wander_direction(Vector3.ZERO)
		_pick_wander_target()
		_wander_waiting = false


# --- Приватные методы ---


func _change_state(new_state: State) -> void:
	var prev_state: State = current_state
	current_state = new_state
	_timer = 0.0
	_wander_waiting = false
	if new_state == State.WANDER:
		_pick_wander_target()
		_enemy.set_wander_direction(Vector3.ZERO)
		# Если выходим из любой агрессивной фазы — даём врагу коаст-паузу:
		# не назначаем новое направление, пусть инерция сама затухает.
		var was_aggressive: bool = prev_state in [State.CHASE, State.SEARCH, State.TELEGRAPH, State.ATTACK, State.RECOVER]
		if was_aggressive:
			_wander_waiting = true
			_wander_wait_duration = 1.0
	elif new_state != State.CHASE:
		_enemy.set_wander_direction(Vector3.ZERO)

	# Сброс/инициализация крошек и таймеров расследования
	if new_state == State.CHASE:
		_los_timer = 0.0
		_breadcrumb_timer = 0.0
	elif new_state == State.SEARCH:
		_search_timer = 0.0
		_los_timer = 0.0
	elif new_state == State.TELEGRAPH:
		# Снимок цели/направления — конкретное поведение задаёт класс.
		_enemy.prepare_attack()
	elif new_state == State.ATTACK:
		# Спавн снаряда (ranged/bomber) или взлёт (melee).
		_enemy.execute_attack()
	else:
		# Ушли в любую невыслеживающую ветку — забываем крошки
		var leaving_pursuit: bool = prev_state in [State.CHASE, State.SEARCH]
		var entering_pursuit_chain: bool = new_state in [State.TELEGRAPH, State.ATTACK, State.RECOVER]
		if leaving_pursuit and not entering_pursuit_chain:
			_breadcrumbs.clear()
			_has_los = false

	state_changed.emit(new_state)


## Выбирает случайную точку патрулирования рядом с врагом.
func _pick_wander_target() -> void:
	var half_x: float = 16.5  # Арена 36 - отступ
	var half_z: float = 10.5  # Арена 24 - отступ
	var pos: Vector3 = _enemy.global_position
	_wander_target = Vector3(
		clampf(pos.x + randf_range(-WANDER_RADIUS, WANDER_RADIUS), -half_x, half_x),
		0.0,
		clampf(pos.z + randf_range(-WANDER_RADIUS, WANDER_RADIUS), -half_z, half_z),
	)


func _process_wander(delta: float) -> void:
	# Проверяем LoS только если игрок физически в зоне (Area3D-триггер).
	if _enemy._target != null and _enemy.player_in_range:
		_los_timer -= delta
		if _los_timer <= 0.0:
			_los_timer = LOS_CHECK_INTERVAL
			if _enemy.has_line_of_sight_to(_enemy._target):
				_has_los = true
				_push_breadcrumb(_enemy._target.global_position)
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


func _process_chase(delta: float) -> void:
	if _enemy._target == null:
		return

	# Периодическая проверка линии зрения и запись крошек
	_los_timer -= delta
	if _los_timer <= 0.0:
		_los_timer = LOS_CHECK_INTERVAL
		_has_los = _enemy.player_in_range and _enemy.has_line_of_sight_to(_enemy._target)

	if _has_los:
		_breadcrumb_timer -= delta
		if _breadcrumb_timer <= 0.0:
			_breadcrumb_timer = BREADCRUMB_INTERVAL
			_push_breadcrumb(_enemy._target.global_position)

	# Игрок вышел из зоны (Area3D) ИЛИ скрылся за преградой — расследование.
	var lost_player: bool = (not _enemy.player_in_range) or (not _has_los)
	if lost_player:
		if _breadcrumbs.size() > 0:
			_enemy.investigation_target = _breadcrumbs.back()
			_change_state(State.SEARCH)
		else:
			_change_state(State.WANDER)
		return

	# Окно атаки задаётся классом: melee=ближняя, ranged/bomber=дальняя с min-границей.
	# Если игрок в этом окне и виден — переходим в TELEGRAPH.
	var distance: float = _enemy.get_distance_to_target()
	var min_r: float = _enemy.get_attack_min_range()
	var max_r: float = _enemy.get_attack_engagement_range()
	if distance >= min_r and distance <= max_r and _has_los:
		_change_state(State.TELEGRAPH)


## Расследование: идти к последней крошке, попутно проверяя LoS.
func _process_search(delta: float) -> void:
	if _enemy._target == null:
		_change_state(State.WANDER)
		return

	_search_timer += delta
	if _search_timer >= SEARCH_TIMEOUT:
		_change_state(State.WANDER)
		return

	# Проверка LoS — если игрок снова виден и в зоне, возвращаемся в CHASE
	_los_timer -= delta
	if _los_timer <= 0.0:
		_los_timer = LOS_CHECK_INTERVAL
		if _enemy.player_in_range and _enemy.has_line_of_sight_to(_enemy._target):
			_has_los = true
			_push_breadcrumb(_enemy._target.global_position)
			_change_state(State.CHASE)
			return

	# Цель — всегда самая свежая крошка (на случай, если она обновилась)
	if _breadcrumbs.size() > 0:
		_enemy.investigation_target = _breadcrumbs.back()
	else:
		_change_state(State.WANDER)
		return

	# Дошли до точки последнего наблюдения, а игрока так и не увидели — сдаёмся
	var to_target: Vector3 = _enemy.investigation_target - _enemy.global_position
	to_target.y = 0.0
	if to_target.length() <= BREADCRUMB_REACH_DIST:
		_change_state(State.WANDER)


## Добавляет крошку в очередь, ограничивая длину.
func _push_breadcrumb(pos: Vector3) -> void:
	# Не дублировать почти ту же точку
	if _breadcrumbs.size() > 0:
		var last: Vector3 = _breadcrumbs.back()
		if last.distance_to(pos) < 0.4:
			return
	_breadcrumbs.append(pos)
	if _breadcrumbs.size() > MAX_BREADCRUMBS:
		_breadcrumbs.pop_front()


func _process_telegraph(delta: float) -> void:
	_timer += delta
	if _timer >= get_telegraph_duration():
		_change_state(State.ATTACK)


func _process_attack(delta: float) -> void:
	_timer += delta
	if _timer >= get_attack_duration():
		# Урон обрабатывает класс: melee — distance check, ranged/bomber — снаряды сами.
		_enemy.resolve_attack_landing()
		attack_executed.emit()
		_change_state(State.RECOVER)


func _process_recover(delta: float) -> void:
	_timer += delta
	if _timer >= RECOVER_DURATION:
		# После атаки: если игрок вне зоны — патрулируем, иначе продолжаем погоню
		if not _enemy.player_in_range:
			_change_state(State.WANDER)
		else:
			_change_state(State.CHASE)

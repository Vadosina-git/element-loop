class_name CombatLogic
extends RefCounted

## Боевая логика: метки, ярость, урон. Без Node-зависимостей.
##
## Управляет состоянием врагов в бою: регистрация, наложение меток (контр-зона),
## наложение ярости (зона своей стихии), обработка таймеров и нанесение урона.
## Все взаимодействия происходят через сигналы.

# --- Сигналы ---

signal enemy_marked(enemy_id: int)
signal enemy_killed(enemy_id: int)
signal enemy_enraged(enemy_id: int)
signal enemy_rage_expired(enemy_id: int)
signal enemy_mark_expired(enemy_id: int)

# --- Константы ---

## Длительность метки в секундах.
const MARK_DURATION: float = 3.0
## Урон при срабатывании метки.
const MARK_DAMAGE: int = 1
## Процент замедления при метке (0.25 = 25%).
const MARK_SLOW: float = 0.25
## Длительность ярости в секундах.
const RAGE_DURATION: float = 4.0
## Бонус скорости при ярости (0.25 = 25%).
const RAGE_SPEED_BONUS: float = 0.25
## Бонус темпа атак при ярости (0.25 = 25%).
const RAGE_ATTACK_BONUS: float = 0.25

# --- Внутренний класс ---


class EnemyData extends RefCounted:
	## Данные врага в боевой системе.
	var element: ElementTable.Element
	var hp: int
	var max_hp: int
	var mark_timer: float = 0.0
	var is_marked: bool = false
	var rage_timer: float = 0.0
	var is_enraged: bool = false

	func _init(p_element: ElementTable.Element, p_hp: int) -> void:
		element = p_element
		hp = p_hp
		max_hp = p_hp


# --- Приватные переменные ---

var _enemies: Dictionary = {}  # int -> EnemyData

# --- Публичные методы ---


## Зарегистрировать врага в системе боя.
func register_enemy(enemy_id: int, element: ElementTable.Element, hp: int) -> void:
	_enemies[enemy_id] = EnemyData.new(element, hp)


## Попытаться наложить метку (контр-зона).
## Возвращает true, если метка успешно наложена.
func try_apply_mark(enemy_id: int, zone_element: ElementTable.Element) -> bool:
	var data: EnemyData = _enemies.get(enemy_id)
	if data == null:
		return false
	if not ElementTable.is_counter(zone_element, data.element):
		return false
	if data.is_marked:
		return false
	data.is_marked = true
	data.mark_timer = MARK_DURATION
	enemy_marked.emit(enemy_id)
	return true


## Попытаться наложить ярость (зона своей стихии).
## Возвращает true, если ярость успешно наложена или обновлена.
func try_apply_rage(enemy_id: int, zone_element: ElementTable.Element) -> bool:
	var data: EnemyData = _enemies.get(enemy_id)
	if data == null:
		return false
	if not ElementTable.is_same(zone_element, data.element):
		return false
	data.is_enraged = true
	data.rage_timer = RAGE_DURATION
	enemy_enraged.emit(enemy_id)
	return true


## Обновить таймеры меток и ярости. Вызывать каждый кадр с delta.
func tick(delta: float) -> void:
	var dead_ids: Array[int] = []
	for enemy_id: int in _enemies:
		var data: EnemyData = _enemies[enemy_id]
		if data.is_marked:
			data.mark_timer -= delta
			if data.mark_timer <= 0.0:
				data.hp -= MARK_DAMAGE
				data.is_marked = false
				data.mark_timer = 0.0
				enemy_mark_expired.emit(enemy_id)
				if data.hp <= 0:
					dead_ids.append(enemy_id)
		if data.is_enraged:
			data.rage_timer -= delta
			if data.rage_timer <= 0.0:
				data.is_enraged = false
				data.rage_timer = 0.0
				enemy_rage_expired.emit(enemy_id)
	for dead_id: int in dead_ids:
		enemy_killed.emit(dead_id)


## Проверить, помечен ли враг.
func is_marked(enemy_id: int) -> bool:
	var data: EnemyData = _enemies.get(enemy_id)
	return data != null and data.is_marked


## Проверить, в ярости ли враг.
func is_enraged(enemy_id: int) -> bool:
	var data: EnemyData = _enemies.get(enemy_id)
	return data != null and data.is_enraged


## Получить текущее HP врага. Для незарегистрированного — 0.
func get_enemy_hp(enemy_id: int) -> int:
	var data: EnemyData = _enemies.get(enemy_id)
	return data.hp if data != null else 0


## Проверить, мёртв ли враг (HP <= 0 или не зарегистрирован).
func is_enemy_dead(enemy_id: int) -> bool:
	var data: EnemyData = _enemies.get(enemy_id)
	if data == null:
		return true
	return data.hp <= 0


## Получить данные врага. Может вернуть null.
func get_enemy_data(enemy_id: int) -> EnemyData:
	return _enemies.get(enemy_id)

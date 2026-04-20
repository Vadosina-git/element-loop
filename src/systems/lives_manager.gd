extends Node

## Менеджер жизней.
##
## Жизнь тратится при рестарте комнаты ("перемотке") или смерти игрока.
## Регенерируется по таймеру (каждые N секунд) до капа lives_max.
## При покупке unlimited — счётчик не уменьшается и не регенерируется.
## Сигналы пробрасываются в HUD и геймплей.
## Автозагрузка.

# --- Сигналы ---

## Изменилось значение жизней / unlimited-состояние.
signal lives_changed(lives: int, unlimited: bool)

## Жизни исчерпаны (lives == 0 и не unlimited).
signal lives_exhausted

## Таймер до следующей регенерации обновился (секунды).
signal regen_timer_updated(seconds_left: float)


# --- Приватные переменные ---

var _accumulated: float = 0.0  # накопленное время для защиты от задержек таймера


# --- Встроенные колбеки ---

func _ready() -> void:
	# SaveManager грузится раньше в алфавитном порядке autoload? Нет, порядок —
	# из project.godot. Убедимся, что SaveManager уже инициализирован.
	await get_tree().process_frame
	_ensure_initial_state()
	# Догнать регенерацию за время, пока игра была закрыта
	_catch_up_regen()
	_emit_lives()


func _process(delta: float) -> void:
	if SaveManager.unlimited_lives:
		return
	if SaveManager.lives >= ConfigManager.get_lives_max():
		return
	_accumulated += delta
	if _accumulated >= 1.0:
		_accumulated = 0.0
		_tick_regen()


# --- Публичные методы ---

## Тратит одну жизнь. Возвращает true если списали, false если жизней нет.
## Unlimited — всегда true без списания.
func consume(count: int = 1) -> bool:
	if SaveManager.unlimited_lives:
		return true
	if SaveManager.lives < count:
		lives_exhausted.emit()
		return false
	SaveManager.lives -= count
	# Если опустились с капа — запускаем таймер регенерации
	if SaveManager.last_life_regen_ts == 0 or SaveManager.lives == ConfigManager.get_lives_max() - count:
		SaveManager.last_life_regen_ts = _now_ms()
	SaveManager.save_game()
	_emit_lives()
	return true


## Начисляет N жизней (после покупки пака).
func add_lives(count: int) -> void:
	SaveManager.lives += count
	SaveManager.save_game()
	_emit_lives()


## Активирует unlimited жизни (после покупки безлимита).
func set_unlimited(enabled: bool) -> void:
	SaveManager.unlimited_lives = enabled
	SaveManager.save_game()
	_emit_lives()


## Возвращает текущее количество жизней.
func get_lives() -> int:
	return SaveManager.lives


## Возвращает true если активен unlimited.
func is_unlimited() -> bool:
	return SaveManager.unlimited_lives


## Возвращает секунды до следующей регенерации (или 0 если максимум/unlimited).
func get_seconds_to_next_regen() -> float:
	if SaveManager.unlimited_lives:
		return 0.0
	if SaveManager.lives >= ConfigManager.get_lives_max():
		return 0.0
	var interval: float = ConfigManager.get_life_regen_seconds()
	var elapsed: float = (_now_ms() - SaveManager.last_life_regen_ts) / 1000.0
	return maxf(0.0, interval - elapsed)


## Принудительно проверить есть ли жизни (без списания). Emit lives_exhausted при 0.
func has_lives() -> bool:
	if SaveManager.unlimited_lives:
		return true
	if SaveManager.lives > 0:
		return true
	lives_exhausted.emit()
	return false


# --- Приватные методы ---

func _ensure_initial_state() -> void:
	# Первый запуск — сейв ещё не имел last_life_regen_ts
	if SaveManager.last_life_regen_ts == 0:
		SaveManager.last_life_regen_ts = _now_ms()


func _catch_up_regen() -> void:
	if SaveManager.unlimited_lives:
		return
	var lives_max: int = ConfigManager.get_lives_max()
	if SaveManager.lives >= lives_max:
		SaveManager.last_life_regen_ts = _now_ms()
		return
	var interval_ms: int = int(ConfigManager.get_life_regen_seconds() * 1000.0)
	if interval_ms <= 0:
		return
	var now: int = _now_ms()
	var elapsed: int = now - SaveManager.last_life_regen_ts
	if elapsed <= 0:
		return
	var ticks: int = elapsed / interval_ms
	if ticks <= 0:
		return
	var gained: int = mini(ticks, lives_max - SaveManager.lives)
	SaveManager.lives += gained
	# Сдвигаем точку отсчёта строго на количество «отданных» тиков
	SaveManager.last_life_regen_ts += ticks * interval_ms
	SaveManager.save_game()


func _tick_regen() -> void:
	var lives_max: int = ConfigManager.get_lives_max()
	if SaveManager.lives >= lives_max:
		SaveManager.last_life_regen_ts = _now_ms()
		return
	var interval_ms: int = int(ConfigManager.get_life_regen_seconds() * 1000.0)
	if interval_ms <= 0:
		return
	var now: int = _now_ms()
	if now - SaveManager.last_life_regen_ts >= interval_ms:
		SaveManager.lives += 1
		SaveManager.last_life_regen_ts += interval_ms
		SaveManager.save_game()
		_emit_lives()
	else:
		regen_timer_updated.emit(get_seconds_to_next_regen())


func _emit_lives() -> void:
	lives_changed.emit(SaveManager.lives, SaveManager.unlimited_lives)
	regen_timer_updated.emit(get_seconds_to_next_regen())


func _now_ms() -> int:
	return Time.get_unix_time_from_system() * 1000 as int

class_name GameController
extends Node

## Оркестратор игры.
##
## Связывает все системы прототипа: арену, игрока, врагов, зоны,
## книгу, HUD и ввод. Управляет жизненным циклом комнаты.

# --- Константы ---

const ZONE_SCENE: String = "res://src/arena/map_objects/zone_object.tscn"
const ENEMY_SCENE: String = "res://src/enemies/enemy_base.tscn"
const BOOK_SCENE: String = "res://src/arena/map_objects/book_object.tscn"

# --- Приватные переменные ---

var _arena: ArenaView = null
var _player: PlayerCharacter = null
var _player_input: PlayerInput = null
var _hud: HUD = null
var _joystick: VirtualJoystick = null
var _books: Array[BookObject] = []
var _combat_logic: CombatLogic = CombatLogic.new()
var _zone_logic: ZoneLogic = ZoneLogic.new()
var _enemies: Dictionary = {}  # {enemy_id: EnemyBase}
var _active_zones: Array[ZoneObject] = []
var _next_enemy_id: int = 1

const ENEMY_COUNT: int = 20
const SPAWN_MARGIN: float = 2.0


# --- Встроенные колбеки ---

func _ready() -> void:
	# Получаем ссылки на узлы сцены
	_arena = $ArenaView as ArenaView
	_player = $ArenaView/PlayerCharacter as PlayerCharacter
	_hud = $HUD as HUD
	_joystick = $UILayer/VirtualJoystick as VirtualJoystick
	_player_input = $PlayerInput as PlayerInput

	# Настраиваем камеру — слежение за игроком
	_arena._camera.set_follow_target(_player)

	# Настраиваем систему ввода
	_player_input.setup(_player, _joystick, _arena._camera)

	# Подключаем сигналы игрока → HUD
	_player.hp_changed.connect(_hud.update_hp)
	_player.element_changed.connect(_hud.update_element)
	_player.zone_placed.connect(_on_player_zone_placed)
	_player.died.connect(_on_player_died)

	# Подключаем сигналы HUD и ввода → действия
	_hud.zone_button_pressed.connect(_on_zone_button_pressed)
	_player_input.zone_button_pressed.connect(_on_zone_button_pressed)

	# Подключаем рывок
	_hud.dash_button_pressed.connect(_on_dash_button_pressed)
	_player_input.dash_pressed.connect(_on_dash_button_pressed)
	_player.dash_cooldown_changed.connect(_hud.update_dash_cooldown)

	# Подключаем перезапуск
	_hud.restart_pressed.connect(_on_restart_pressed)

	# Подключаем пресеты камеры
	_hud.camera_preset_selected.connect(_on_camera_preset_selected)
	_hud.setup_camera_presets(_arena._camera.get_preset_names(), _arena._camera.current_preset)

	# Спавним книги и настраиваем индикаторы
	_spawn_books()
	_hud.setup_book_indicators(_books, _arena._camera)

	# Настраиваем отслеживание врагов для подсветки
	var enemy_list: Array[EnemyBase] = []
	for eid: int in _enemies:
		enemy_list.append(_enemies[eid] as EnemyBase)
	_hud.setup_enemy_tracking(enemy_list)

	# Подключаем сигналы боевой логики
	_combat_logic.enemy_marked.connect(_on_enemy_marked)
	_combat_logic.enemy_mark_expired.connect(_on_mark_expired)
	_combat_logic.enemy_enraged.connect(_on_enemy_enraged)
	_combat_logic.enemy_rage_expired.connect(_on_rage_expired)
	_combat_logic.enemy_killed.connect(_on_enemy_killed)

	# Спавним врагов
	_spawn_enemies()


func _process(delta: float) -> void:
	_combat_logic.tick(delta)


# --- Приватные методы ---

## Спавнит всех врагов в случайных точках.
func _spawn_enemies() -> void:
	var scene: PackedScene = load(ENEMY_SCENE) as PackedScene
	var elements: Array[ElementTable.Element] = [
		ElementTable.Element.FIRE,
		ElementTable.Element.WATER,
		ElementTable.Element.TREE,
		ElementTable.Element.EARTH,
		ElementTable.Element.METAL,
	]

	var enemy_positions: Array[Vector3] = _arena.get_distributed_spawn_positions(ENEMY_COUNT)
	for i: int in range(ENEMY_COUNT):
		var enemy: EnemyBase = scene.instantiate() as EnemyBase
		enemy.element = elements[i % elements.size()]
		enemy.level = 1
		enemy.enemy_id = _next_enemy_id
		_next_enemy_id += 1
		enemy.position = enemy_positions[i]
		_arena.add_child(enemy)
		enemy.set_target(_player)

		# Подключаем сигналы врага
		enemy.attacked_player.connect(_on_enemy_attacked_player)
		enemy.died.connect(_on_enemy_died)

		# Регистрируем
		_enemies[enemy.enemy_id] = enemy
		_combat_logic.register_enemy(enemy.enemy_id, enemy.element, enemy.hp)


## Спавнит книги в случайных точках арены.
func _spawn_books() -> void:
	var scene: PackedScene = load(BOOK_SCENE) as PackedScene
	var book_positions: Array[Vector3] = _arena.get_distributed_spawn_positions(ENEMY_COUNT)
	for i: int in range(ENEMY_COUNT):
		var book: BookObject = scene.instantiate() as BookObject
		book.position = book_positions[i]
		_arena.add_child(book)
		book.element_picked.connect(_on_element_picked)
		_books.append(book)


## Удаляет одну случайную книгу с поля.
func _remove_one_book() -> void:
	if _books.is_empty():
		return
	var idx: int = randi() % _books.size()
	var book: BookObject = _books[idx]
	_books.remove_at(idx)
	if is_instance_valid(book):
		book.queue_free()


## Возвращает врага по ID или null.
func _get_enemy(enemy_id: int) -> EnemyBase:
	if _enemies.has(enemy_id):
		var enemy: EnemyBase = _enemies[enemy_id] as EnemyBase
		if is_instance_valid(enemy):
			return enemy
	return null


## Удаляет старейшую зону при переполнении (FIFO).
func _enforce_zone_limit() -> void:
	while _active_zones.size() > ZoneLogic.MAX_ZONES:
		var oldest: ZoneObject = _active_zones.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


# --- Колбеки сигналов ---

## Игрок подобрал стихию из книги.
func _on_element_picked(element: ElementTable.Element) -> void:
	_player.pickup_element(element as int)


## Нажата кнопка постановки зоны.
func _on_zone_button_pressed() -> void:
	_player.place_zone()


## Игрок поставил зону: создаём объект на арене.
func _on_player_zone_placed(element: int, pos: Vector3) -> void:
	var scene: PackedScene = load(ZONE_SCENE) as PackedScene
	var zone: ZoneObject = scene.instantiate() as ZoneObject
	zone.setup(element as ElementTable.Element, pos)
	_arena.add_child(zone)

	# Подключаем сигналы зоны
	zone.enemy_entered_zone.connect(_on_enemy_entered_zone)
	zone.enemy_exited_zone.connect(_on_enemy_exited_zone)

	# Управляем лимитом зон (FIFO)
	_active_zones.append(zone)
	_zone_logic.add_zone(element as ElementTable.Element, pos)
	_enforce_zone_limit()


## Враг вошёл в зону: проверяем эффект.
func _on_enemy_entered_zone(enemy: EnemyBase, zone: ZoneObject) -> void:
	var effect: ZoneLogic.ZoneEffect = ZoneLogic.check_effect(zone.element, enemy.element)
	match effect:
		ZoneLogic.ZoneEffect.COUNTER:
			_combat_logic.try_apply_mark(enemy.enemy_id, zone.element)
		ZoneLogic.ZoneEffect.SAME:
			_combat_logic.try_apply_rage(enemy.enemy_id, zone.element)
		ZoneLogic.ZoneEffect.NEUTRAL:
			pass  # Нейтральная зона — без эффекта


## Враг вышел из зоны (метка не сбрасывается при выходе).
func _on_enemy_exited_zone(_enemy_ref: EnemyBase, _zone: ZoneObject) -> void:
	pass


## Боевая логика: метка наложена на врага.
func _on_enemy_marked(enemy_id: int) -> void:
	var enemy: EnemyBase = _get_enemy(enemy_id)
	if enemy != null:
		enemy.apply_mark()


## Боевая логика: таймер метки истёк → урон уже нанесён в CombatLogic.
func _on_mark_expired(enemy_id: int) -> void:
	var enemy: EnemyBase = _get_enemy(enemy_id)
	if enemy != null:
		enemy.remove_mark()


## Боевая логика: ярость наложена на врага.
func _on_enemy_enraged(enemy_id: int) -> void:
	var enemy: EnemyBase = _get_enemy(enemy_id)
	if enemy != null:
		enemy.apply_rage()


## Боевая логика: таймер ярости истёк.
func _on_rage_expired(enemy_id: int) -> void:
	var enemy: EnemyBase = _get_enemy(enemy_id)
	if enemy != null:
		enemy.remove_rage()


## Боевая логика: враг убит (HP <= 0 после метки).
func _on_enemy_killed(enemy_id: int) -> void:
	var enemy: EnemyBase = _get_enemy(enemy_id)
	if enemy != null:
		enemy.queue_free()
		_enemies.erase(enemy_id)
	_remove_one_book()


## Враг испустил сигнал died (из EnemyBase.take_damage).
func _on_enemy_died(_dead_enemy: EnemyBase) -> void:
	pass


## Враг атаковал игрока.
func _on_enemy_attacked_player(_attacker: EnemyBase) -> void:
	_player.take_damage(1)


## Нажата кнопка рывка (UI или Shift).
func _on_dash_button_pressed() -> void:
	_player.try_dash()


## Выбран пресет камеры.
func _on_camera_preset_selected(preset_name: String) -> void:
	_arena._camera.apply_preset(preset_name)
	_hud.update_camera_preset(preset_name)


## Игрок умер.
func _on_player_died() -> void:
	_hud.show_game_over()
	set_process(false)


## Перезапуск уровня.
func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			_on_restart_pressed()

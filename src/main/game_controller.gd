class_name GameController
extends Node

## Оркестратор игры.
##
## Связывает все системы прототипа: арену, игрока, врагов, зоны,
## книгу, HUD и ввод. Управляет жизненным циклом комнаты.

# --- Константы ---

const ZONE_SCENE: String = "res://src/arena/map_objects/zone_object.tscn"
const ENEMY_SCENE: String = "res://src/enemies/enemy_base.tscn"

# --- Приватные переменные ---

var _arena: ArenaView = null
var _player: PlayerCharacter = null
var _player_input: PlayerInput = null
var _hud: HUD = null
var _joystick: VirtualJoystick = null
var _book: BookObject = null
var _combat_logic: CombatLogic = CombatLogic.new()
var _zone_logic: ZoneLogic = ZoneLogic.new()
var _enemy: EnemyBase = null
var _active_zones: Array[ZoneObject] = []


# --- Встроенные колбеки ---

func _ready() -> void:
	# Получаем ссылки на узлы сцены
	_arena = $ArenaView as ArenaView
	_player = $ArenaView/PlayerCharacter as PlayerCharacter
	_hud = $HUD as HUD
	_joystick = $UILayer/VirtualJoystick as VirtualJoystick
	_player_input = $PlayerInput as PlayerInput
	_book = $ArenaView/BookObject as BookObject

	# Настраиваем систему ввода
	_player_input.setup(_player, _joystick, _arena._camera)

	# Подключаем сигналы игрока → HUD
	_player.hp_changed.connect(_hud.update_hp)
	_player.element_changed.connect(_hud.update_element)
	_player.zone_placed.connect(_on_player_zone_placed)
	_player.died.connect(_on_player_died)

	# Подключаем сигналы HUD → действия
	_hud.zone_button_pressed.connect(_on_zone_button_pressed)

	# Подключаем сигналы книги
	_book.element_picked.connect(_on_element_picked)

	# Подключаем сигналы боевой логики
	_combat_logic.enemy_marked.connect(_on_enemy_marked)
	_combat_logic.enemy_mark_expired.connect(_on_mark_expired)
	_combat_logic.enemy_enraged.connect(_on_enemy_enraged)
	_combat_logic.enemy_rage_expired.connect(_on_rage_expired)
	_combat_logic.enemy_killed.connect(_on_enemy_killed)

	# Спавним тестового врага
	_spawn_enemy()


func _process(delta: float) -> void:
	_combat_logic.tick(delta)


# --- Приватные методы ---

## Создаёт тестового врага на арене.
func _spawn_enemy() -> void:
	var scene: PackedScene = load(ENEMY_SCENE) as PackedScene
	_enemy = scene.instantiate() as EnemyBase
	_enemy.element = ElementTable.Element.FIRE
	_enemy.level = 1
	_enemy.enemy_id = 1
	_enemy.position = Vector3(3.0, 0.0, -3.0)
	_arena.add_child(_enemy)
	_enemy.set_target(_player)

	# Подключаем сигналы врага
	_enemy.attacked_player.connect(_on_enemy_attacked_player)
	_enemy.died.connect(_on_enemy_died)

	# Регистрируем в боевой логике
	_combat_logic.register_enemy(_enemy.enemy_id, _enemy.element, _enemy.hp)


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
	if _enemy != null and _enemy.enemy_id == enemy_id:
		_enemy.apply_mark()


## Боевая логика: таймер метки истёк → урон уже нанесён в CombatLogic.
## Здесь только обновляем визуал. Если враг мёртв — _on_enemy_killed обработает.
func _on_mark_expired(enemy_id: int) -> void:
	if _enemy != null and _enemy.enemy_id == enemy_id:
		_enemy.remove_mark()


## Боевая логика: ярость наложена на врага.
func _on_enemy_enraged(enemy_id: int) -> void:
	if _enemy != null and _enemy.enemy_id == enemy_id:
		_enemy.apply_rage()


## Боевая логика: таймер ярости истёк.
func _on_rage_expired(enemy_id: int) -> void:
	if _enemy != null and _enemy.enemy_id == enemy_id:
		_enemy.remove_rage()


## Боевая логика: враг убит (HP <= 0 после метки).
func _on_enemy_killed(enemy_id: int) -> void:
	if _enemy != null and _enemy.enemy_id == enemy_id:
		_enemy.queue_free()
		_enemy = null


## Враг испустил сигнал died (из EnemyBase.take_damage).
func _on_enemy_died(_dead_enemy: EnemyBase) -> void:
	# Обрабатывается через _on_enemy_killed от combat_logic
	pass


## Враг атаковал игрока.
func _on_enemy_attacked_player(_attacker: EnemyBase) -> void:
	_player.take_damage(1)


## Игрок умер.
func _on_player_died() -> void:
	# TODO: экран смерти, рестарт
	pass

# Element Loop — Фаза 1: Минимальное ядро

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Цель:** Играбельный прототип одной комнаты — игрок ставит зоны, заманивает врага, метка убивает.

**Архитектура:** Чистая логика боя (RefCounted) отделена от визуала (Node3D). ElementTable и ZoneLogic тестируются изолированно через GUT. ArenaView связывает логику с 3D-сценой. GameController оркестрирует.

**Стек:** Godot 4.x, GDScript 2.0 (строгая типизация), GUT для тестов.

**Scope:** 1 враг (Fire), базовый AI (Chase → Attack), книга, зоны, метка + урон, камера, HUD. Без эскалации, способностей, босса, меню, монетизации.

---

### Task 1: Скаффолдинг проекта

**Files:**
- Create: `project.godot`
- Create: `src/combat/element_table.gd`
- Create: `src/systems/game_manager.gd`
- Create: `src/systems/audio_manager.gd`
- Create: `tests/unit/test_element_table.gd`

- [ ] **Step 1: Инициализировать git-репозиторий**

```bash
cd "/Users/vadimprokop/Documents/Godot/element loop"
git init
```

- [ ] **Step 2: Создать структуру папок**

```bash
mkdir -p src/{main,combat,arena/map_objects,player,enemies/archetypes,systems,ui/{hud,menus,controls}}
mkdir -p assets/{models,sprites,audio/{sfx,music}}
mkdir -p resources/{data,themes}
mkdir -p tests/unit
```

- [ ] **Step 3: Создать project.godot**

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; but it can also be manually edited if needed.

config_version=5

[application]

config/name="Element Loop"
run/main_scene="res://src/main/game_controller.tscn"
config/features=PackedStringArray("4.4", "Forward Plus")

[autoload]

GameManager="*res://src/systems/game_manager.gd"
AudioManager="*res://src/systems/audio_manager.gd"

[display]

window/size/viewport_width=1080
window/size/viewport_height=1920
window/handheld/orientation=1

[input_devices]

pointing/emulate_touch_from_mouse=true

[rendering]

renderer/rendering_method="forward_plus"
```

- [ ] **Step 4: Создать ElementTable**

```gdscript
## src/combat/element_table.gd
class_name ElementTable
extends RefCounted

## Таблица стихий и контров.

enum Element {
	FIRE,
	WATER,
	TREE,
	EARTH,
	METAL,
}

## Возвращает стихию-контр для данной стихии врага.
static func get_counter(enemy_element: Element) -> Element:
	match enemy_element:
		Element.FIRE:
			return Element.WATER
		Element.WATER:
			return Element.METAL
		Element.TREE:
			return Element.FIRE
		Element.EARTH:
			return Element.TREE
		Element.METAL:
			return Element.EARTH
	return enemy_element


## Проверяет, является ли зона контр-зоной для врага.
static func is_counter(zone_element: Element, enemy_element: Element) -> bool:
	return zone_element == get_counter(enemy_element)


## Проверяет, является ли зона «своей» для врага (усиление).
static func is_same(zone_element: Element, enemy_element: Element) -> bool:
	return zone_element == enemy_element
```

- [ ] **Step 5: Создать автозагрузки-заглушки**

```gdscript
## src/systems/game_manager.gd
class_name GameManagerClass
extends Node

## Менеджер прогресса и сохранений (заглушка).

var current_room: int = 1
```

```gdscript
## src/systems/audio_manager.gd
class_name AudioManagerClass
extends Node

## Менеджер звуков (заглушка).

func play_sfx(_name: String) -> void:
	pass
```

- [ ] **Step 6: Установить GUT и написать тест ElementTable**

Скачать GUT addon в `addons/gut/` (или создать минимальный runner).

```gdscript
## tests/unit/test_element_table.gd
extends GutTest

## Тесты таблицы стихий.

func test_fire_countered_by_water() -> void:
	assert_eq(
		ElementTable.get_counter(ElementTable.Element.FIRE),
		ElementTable.Element.WATER
	)

func test_water_countered_by_metal() -> void:
	assert_eq(
		ElementTable.get_counter(ElementTable.Element.WATER),
		ElementTable.Element.METAL
	)

func test_tree_countered_by_fire() -> void:
	assert_eq(
		ElementTable.get_counter(ElementTable.Element.TREE),
		ElementTable.Element.FIRE
	)

func test_earth_countered_by_tree() -> void:
	assert_eq(
		ElementTable.get_counter(ElementTable.Element.EARTH),
		ElementTable.Element.TREE
	)

func test_metal_countered_by_earth() -> void:
	assert_eq(
		ElementTable.get_counter(ElementTable.Element.METAL),
		ElementTable.Element.EARTH
	)

func test_is_counter_true() -> void:
	assert_true(
		ElementTable.is_counter(ElementTable.Element.WATER, ElementTable.Element.FIRE)
	)

func test_is_counter_false() -> void:
	assert_false(
		ElementTable.is_counter(ElementTable.Element.FIRE, ElementTable.Element.FIRE)
	)

func test_is_same_true() -> void:
	assert_true(
		ElementTable.is_same(ElementTable.Element.FIRE, ElementTable.Element.FIRE)
	)

func test_is_same_false() -> void:
	assert_false(
		ElementTable.is_same(ElementTable.Element.WATER, ElementTable.Element.FIRE)
	)
```

- [ ] **Step 7: Запустить тесты**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Ожидается: 9 тестов PASS.

- [ ] **Step 8: Создать .gitignore и коммит**

```gitignore
# Godot
.godot/
*.import
export_presets.cfg

# OS
.DS_Store
Thumbs.db
```

```bash
git add -A
git commit -m "feat: скаффолдинг проекта, ElementTable с тестами"
```

---

### Task 2: ZoneLogic — чистая логика зон

**Files:**
- Create: `src/combat/zone_logic.gd`
- Create: `tests/unit/test_zone_logic.gd`

- [ ] **Step 1: Написать тесты ZoneLogic**

```gdscript
## tests/unit/test_zone_logic.gd
extends GutTest

## Тесты логики зон.

var _zone_logic: ZoneLogic


func before_each() -> void:
	_zone_logic = ZoneLogic.new()


func test_initial_zone_count_is_zero() -> void:
	assert_eq(_zone_logic.get_zone_count(), 0)


func test_add_zone_increases_count() -> void:
	_zone_logic.add_zone(ElementTable.Element.FIRE, Vector3.ZERO)
	assert_eq(_zone_logic.get_zone_count(), 1)


func test_max_zones_is_two() -> void:
	_zone_logic.add_zone(ElementTable.Element.FIRE, Vector3.ZERO)
	_zone_logic.add_zone(ElementTable.Element.WATER, Vector3(1, 0, 0))
	_zone_logic.add_zone(ElementTable.Element.TREE, Vector3(2, 0, 0))
	assert_eq(_zone_logic.get_zone_count(), 2)


func test_fifo_removes_oldest_zone() -> void:
	_zone_logic.add_zone(ElementTable.Element.FIRE, Vector3.ZERO)
	_zone_logic.add_zone(ElementTable.Element.WATER, Vector3(1, 0, 0))
	_zone_logic.add_zone(ElementTable.Element.TREE, Vector3(2, 0, 0))
	var zones: Array = _zone_logic.get_zones()
	assert_eq(zones[0].element, ElementTable.Element.WATER)
	assert_eq(zones[1].element, ElementTable.Element.TREE)


func test_check_zone_counter() -> void:
	var result: ZoneLogic.ZoneEffect = ZoneLogic.check_effect(
		ElementTable.Element.WATER, ElementTable.Element.FIRE
	)
	assert_eq(result, ZoneLogic.ZoneEffect.COUNTER)


func test_check_zone_same() -> void:
	var result: ZoneLogic.ZoneEffect = ZoneLogic.check_effect(
		ElementTable.Element.FIRE, ElementTable.Element.FIRE
	)
	assert_eq(result, ZoneLogic.ZoneEffect.SAME)


func test_check_zone_neutral() -> void:
	var result: ZoneLogic.ZoneEffect = ZoneLogic.check_effect(
		ElementTable.Element.TREE, ElementTable.Element.FIRE
	)
	assert_eq(result, ZoneLogic.ZoneEffect.NEUTRAL)
```

- [ ] **Step 2: Запустить тесты — убедиться, что падают**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Ожидается: FAIL (ZoneLogic не существует).

- [ ] **Step 3: Реализовать ZoneLogic**

```gdscript
## src/combat/zone_logic.gd
class_name ZoneLogic
extends RefCounted

## Логика зон: хранение, FIFO-удаление, определение эффекта.

enum ZoneEffect {
	COUNTER,
	SAME,
	NEUTRAL,
}

const MAX_ZONES: int = 2

var _zones: Array[ZoneData] = []


class ZoneData extends RefCounted:
	var element: ElementTable.Element
	var position: Vector3

	func _init(p_element: ElementTable.Element, p_position: Vector3) -> void:
		element = p_element
		position = p_position


## Добавить зону. При переполнении удаляется старейшая (FIFO).
func add_zone(element: ElementTable.Element, position: Vector3) -> ZoneData:
	var zone := ZoneData.new(element, position)
	_zones.append(zone)
	if _zones.size() > MAX_ZONES:
		_zones.remove_at(0)
	return zone


func get_zone_count() -> int:
	return _zones.size()


func get_zones() -> Array[ZoneData]:
	return _zones


## Определить эффект зоны на врага.
static func check_effect(
	zone_element: ElementTable.Element,
	enemy_element: ElementTable.Element
) -> ZoneEffect:
	if ElementTable.is_counter(zone_element, enemy_element):
		return ZoneEffect.COUNTER
	elif ElementTable.is_same(zone_element, enemy_element):
		return ZoneEffect.SAME
	else:
		return ZoneEffect.NEUTRAL
```

- [ ] **Step 4: Запустить тесты — убедиться, что проходят**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Ожидается: все тесты PASS.

- [ ] **Step 5: Коммит**

```bash
git add src/combat/zone_logic.gd tests/unit/test_zone_logic.gd
git commit -m "feat: ZoneLogic — логика зон с FIFO и определением эффекта"
```

---

### Task 3: CombatLogic — метки и урон

**Files:**
- Create: `src/combat/combat_logic.gd`
- Create: `tests/unit/test_combat_logic.gd`

- [ ] **Step 1: Написать тесты CombatLogic**

```gdscript
## tests/unit/test_combat_logic.gd
extends GutTest

## Тесты боевой логики: метки и урон.

var _combat: CombatLogic


func before_each() -> void:
	_combat = CombatLogic.new()


func test_apply_mark_on_counter() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	var marked: bool = _combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	assert_true(marked)
	assert_true(_combat.is_marked(enemy_id))


func test_no_mark_on_same_element() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	var marked: bool = _combat.try_apply_mark(enemy_id, ElementTable.Element.FIRE)
	assert_false(marked)
	assert_false(_combat.is_marked(enemy_id))


func test_no_mark_on_neutral() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	var marked: bool = _combat.try_apply_mark(enemy_id, ElementTable.Element.TREE)
	assert_false(marked)


func test_mark_tick_deals_damage_after_duration() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	_combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	# Симулируем 3 секунды
	_combat.tick(3.0)
	assert_eq(_combat.get_enemy_hp(enemy_id), 0)


func test_mark_no_damage_before_duration() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	_combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	_combat.tick(2.0)
	assert_eq(_combat.get_enemy_hp(enemy_id), 1)


func test_enemy_dies_at_zero_hp() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	_combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	_combat.tick(3.0)
	assert_true(_combat.is_enemy_dead(enemy_id))


func test_rage_on_same_element() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	var enraged: bool = _combat.try_apply_rage(enemy_id, ElementTable.Element.FIRE)
	assert_true(enraged)
	assert_true(_combat.is_enraged(enemy_id))


func test_rage_expires_after_duration() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	_combat.try_apply_rage(enemy_id, ElementTable.Element.FIRE)
	_combat.tick(4.0)
	assert_false(_combat.is_enraged(enemy_id))


func test_mark_and_rage_parallel() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	_combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	_combat.try_apply_rage(enemy_id, ElementTable.Element.FIRE)
	assert_true(_combat.is_marked(enemy_id))
	assert_true(_combat.is_enraged(enemy_id))
```

- [ ] **Step 2: Запустить тесты — убедиться, что падают**

- [ ] **Step 3: Реализовать CombatLogic**

```gdscript
## src/combat/combat_logic.gd
class_name CombatLogic
extends RefCounted

## Боевая логика: метки, ярость, урон. Без Node-зависимостей.

signal enemy_marked(enemy_id: int)
signal enemy_killed(enemy_id: int)
signal enemy_enraged(enemy_id: int)
signal enemy_rage_expired(enemy_id: int)
signal enemy_mark_expired(enemy_id: int)

const MARK_DURATION: float = 3.0
const MARK_DAMAGE: int = 1
const MARK_SLOW: float = 0.25
const RAGE_DURATION: float = 4.0
const RAGE_SPEED_BONUS: float = 0.25
const RAGE_ATTACK_BONUS: float = 0.25


class EnemyData extends RefCounted:
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


var _enemies: Dictionary = {}  # int -> EnemyData


## Зарегистрировать врага в системе боя.
func register_enemy(enemy_id: int, element: ElementTable.Element, hp: int) -> void:
	_enemies[enemy_id] = EnemyData.new(element, hp)


## Попытаться наложить метку (контр-зона).
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


## Обновить таймеры меток и ярости.
func tick(delta: float) -> void:
	var dead_ids: Array[int] = []
	for enemy_id: int in _enemies:
		var data: EnemyData = _enemies[enemy_id]
		# Метка
		if data.is_marked:
			data.mark_timer -= delta
			if data.mark_timer <= 0.0:
				data.hp -= MARK_DAMAGE
				data.is_marked = false
				data.mark_timer = 0.0
				enemy_mark_expired.emit(enemy_id)
				if data.hp <= 0:
					dead_ids.append(enemy_id)
		# Ярость
		if data.is_enraged:
			data.rage_timer -= delta
			if data.rage_timer <= 0.0:
				data.is_enraged = false
				data.rage_timer = 0.0
				enemy_rage_expired.emit(enemy_id)
	for dead_id: int in dead_ids:
		enemy_killed.emit(dead_id)


func is_marked(enemy_id: int) -> bool:
	var data: EnemyData = _enemies.get(enemy_id)
	return data != null and data.is_marked


func is_enraged(enemy_id: int) -> bool:
	var data: EnemyData = _enemies.get(enemy_id)
	return data != null and data.is_enraged


func get_enemy_hp(enemy_id: int) -> int:
	var data: EnemyData = _enemies.get(enemy_id)
	return data.hp if data != null else 0


func is_enemy_dead(enemy_id: int) -> bool:
	var data: EnemyData = _enemies.get(enemy_id)
	return data != null and data.hp <= 0


func get_enemy_data(enemy_id: int) -> EnemyData:
	return _enemies.get(enemy_id)
```

- [ ] **Step 4: Запустить тесты — убедиться, что проходят**

- [ ] **Step 5: Коммит**

```bash
git add src/combat/combat_logic.gd tests/unit/test_combat_logic.gd
git commit -m "feat: CombatLogic — метки, ярость, урон с тестами"
```

---

### Task 4: Арена и камера

**Files:**
- Create: `src/arena/arena_view.tscn`
- Create: `src/arena/arena_view.gd`
- Create: `src/main/arena_camera.gd`

- [ ] **Step 1: Создать ArenaView — сцену арены**

```gdscript
## src/arena/arena_view.gd
class_name ArenaView
extends Node3D

## 3D-арена: пол, стены, освещение. Мост между логикой и визуалом.

const ARENA_SIZE: Vector2 = Vector2(12.0, 18.0)
const WALL_HEIGHT: float = 2.0

var combat_logic: CombatLogic = CombatLogic.new()
var zone_logic: ZoneLogic = ZoneLogic.new()

@onready var _floor: MeshInstance3D = $Floor
@onready var _walls: Node3D = $Walls
@onready var _camera: Camera3D = $ArenaCamera


func _ready() -> void:
	_setup_floor()
	_setup_walls()
	_setup_navigation()
	_setup_lighting()


func _setup_floor() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = ARENA_SIZE
	_floor.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.12, 0.1)
	_floor.material_override = material
	# Коллизия пола
	var static_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA_SIZE.x, 0.1, ARENA_SIZE.y)
	shape.shape = box
	static_body.add_child(shape)
	_floor.add_child(static_body)


func _setup_walls() -> void:
	var half_x: float = ARENA_SIZE.x / 2.0
	var half_z: float = ARENA_SIZE.y / 2.0
	# 4 стены: север, юг, запад, восток
	var wall_configs: Array[Dictionary] = [
		{"pos": Vector3(0, WALL_HEIGHT / 2, -half_z), "size": Vector3(ARENA_SIZE.x, WALL_HEIGHT, 0.3)},
		{"pos": Vector3(0, WALL_HEIGHT / 2, half_z), "size": Vector3(ARENA_SIZE.x, WALL_HEIGHT, 0.3)},
		{"pos": Vector3(-half_x, WALL_HEIGHT / 2, 0), "size": Vector3(0.3, WALL_HEIGHT, ARENA_SIZE.y)},
		{"pos": Vector3(half_x, WALL_HEIGHT / 2, 0), "size": Vector3(0.3, WALL_HEIGHT, ARENA_SIZE.y)},
	]
	for config: Dictionary in wall_configs:
		var wall := _create_wall(config["size"] as Vector3)
		wall.position = config["pos"] as Vector3
		_walls.add_child(wall)


func _create_wall(size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.18, 0.15)
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


func _setup_navigation() -> void:
	var nav_region := NavigationRegion3D.new()
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.agent_radius = 0.4
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)
	# Bake будет вызван после добавления всех коллайдеров
	nav_region.bake_navigation_mesh.call_deferred()


func _setup_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, 30, 0)
	light.light_energy = 0.8
	light.shadow_enabled = true
	add_child(light)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.06, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.25, 0.2)
	environment.ambient_light_energy = 0.4
	env.environment = environment
	add_child(env)
```

- [ ] **Step 2: Создать ArenaCamera**

```gdscript
## src/main/arena_camera.gd
class_name ArenaCamera
extends Camera3D

## Top-down камера с лёгкой изометрией (~65° от горизонта).

const CAMERA_ANGLE_DEG: float = 65.0
const CAMERA_HEIGHT: float = 18.0

@export var arena_size: Vector2 = Vector2(12.0, 18.0)


func _ready() -> void:
	_setup_camera()


func _setup_camera() -> void:
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = 45.0
	rotation_degrees.x = -CAMERA_ANGLE_DEG
	position = Vector3(0, CAMERA_HEIGHT, _calculate_z_offset())


func _calculate_z_offset() -> float:
	var angle_rad: float = deg_to_rad(CAMERA_ANGLE_DEG)
	return CAMERA_HEIGHT / tan(angle_rad)
```

- [ ] **Step 3: Создать файл сцены ArenaView.tscn вручную (минимальная структура)**

Сцена создаётся программно, но нужен .tscn для инстанциирования:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/arena/arena_view.gd" id="1"]
[ext_resource type="Script" path="res://src/main/arena_camera.gd" id="2"]

[node name="ArenaView" type="Node3D"]
script = ExtResource("1")

[node name="Floor" type="MeshInstance3D" parent="."]

[node name="Walls" type="Node3D" parent="."]

[node name="ArenaCamera" type="Camera3D" parent="."]
script = ExtResource("2")
```

- [ ] **Step 4: Коммит**

```bash
git add src/arena/ src/main/arena_camera.gd
git commit -m "feat: арена с полом, стенами, навигацией и камерой"
```

---

### Task 5: Игрок и управление

**Files:**
- Create: `src/player/player_character.gd`
- Create: `src/player/player_character.tscn`
- Create: `src/player/player_input.gd`
- Create: `src/ui/controls/virtual_joystick.gd`
- Create: `src/ui/controls/virtual_joystick.tscn`

- [ ] **Step 1: Создать PlayerCharacter**

```gdscript
## src/player/player_character.gd
class_name PlayerCharacter
extends CharacterBody3D

## Персонаж игрока: движение, HP, слот стихии.

signal hp_changed(new_hp: int)
signal element_changed(new_element: ElementTable.Element)
signal zone_placed(element: ElementTable.Element, position: Vector3)
signal died()

const MOVE_SPEED: float = 5.0
const MAX_HP: int = 2

var hp: int = MAX_HP
var current_element: ElementTable.Element = -1  # -1 = нет стихии
var has_zone_charge: bool = false

var _move_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	_setup_collision()
	_setup_visual()


func _physics_process(_delta: float) -> void:
	velocity = _move_direction * MOVE_SPEED
	move_and_slide()


func set_move_direction(direction: Vector3) -> void:
	_move_direction = direction.normalized() if direction.length() > 0.1 else Vector3.ZERO
	if _move_direction != Vector3.ZERO:
		# Поворот модели в направлении движения
		look_at(global_position + _move_direction, Vector3.UP)


## Получить стихию из книги.
func pickup_element(element: ElementTable.Element) -> void:
	current_element = element
	has_zone_charge = true
	element_changed.emit(current_element)


## Поставить зону под собой.
func place_zone() -> bool:
	if not has_zone_charge:
		return false
	has_zone_charge = false
	var element: ElementTable.Element = current_element
	current_element = -1
	zone_placed.emit(element, global_position)
	element_changed.emit(current_element)
	return true


## Получить урон.
func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	hp_changed.emit(hp)
	if hp <= 0:
		died.emit()


## Восстановить HP.
func heal(amount: int) -> void:
	hp = min(MAX_HP, hp + amount)
	hp_changed.emit(hp)


func _setup_collision() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.2
	shape.shape = capsule
	shape.position.y = 0.6
	add_child(shape)


func _setup_visual() -> void:
	# Временная визуализация — капсула
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.2
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.6
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.6, 0.9)
	mesh_instance.material_override = material
	add_child(mesh_instance)
```

- [ ] **Step 2: Создать VirtualJoystick**

```gdscript
## src/ui/controls/virtual_joystick.gd
class_name VirtualJoystick
extends Control

## Виртуальный джойстик для мобильного управления.

signal direction_changed(direction: Vector2)

const DEAD_ZONE: float = 0.1
const MAX_RADIUS: float = 60.0

var _is_pressed: bool = false
var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO
var _output: Vector2 = Vector2.ZERO

@onready var _base: TextureRect = $Base
@onready var _knob: TextureRect = $Base/Knob


func _ready() -> void:
	_setup_visuals()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and _is_in_left_half(touch.position) and not _is_pressed:
			_start_touch(touch)
		elif not touch.pressed and touch.index == _touch_index:
			_end_touch()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_touch(drag.position)


func get_direction() -> Vector2:
	return _output


func _is_in_left_half(pos: Vector2) -> bool:
	return pos.x < get_viewport_rect().size.x / 2.0


func _start_touch(touch: InputEventScreenTouch) -> void:
	_is_pressed = true
	_touch_index = touch.index
	_center = touch.position
	_base.visible = true
	_base.global_position = _center - _base.size / 2.0
	_knob.position = _base.size / 2.0 - _knob.size / 2.0


func _end_touch() -> void:
	_is_pressed = false
	_touch_index = -1
	_output = Vector2.ZERO
	_base.visible = false
	direction_changed.emit(_output)


func _update_touch(pos: Vector2) -> void:
	var delta: Vector2 = pos - _center
	var distance: float = delta.length()
	if distance > MAX_RADIUS:
		delta = delta.normalized() * MAX_RADIUS
	_output = delta / MAX_RADIUS if distance > DEAD_ZONE * MAX_RADIUS else Vector2.ZERO
	# Обновить позицию ручки
	_knob.position = _base.size / 2.0 - _knob.size / 2.0 + delta
	direction_changed.emit(_output)


func _setup_visuals() -> void:
	# Программные текстуры-заглушки
	_base.visible = false
	var base_tex := _create_circle_texture(120, Color(1, 1, 1, 0.15))
	_base.texture = base_tex
	_base.size = Vector2(120, 120)
	var knob_tex := _create_circle_texture(40, Color(1, 1, 1, 0.4))
	_knob.texture = knob_tex
	_knob.size = Vector2(40, 40)


func _create_circle_texture(diameter: int, color: Color) -> ImageTexture:
	var image := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(diameter, diameter) / 2.0
	var radius: float = diameter / 2.0
	for x: int in range(diameter):
		for y: int in range(diameter):
			var dist: float = Vector2(x, y).distance_to(center)
			if dist <= radius:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
```

- [ ] **Step 3: Создать PlayerInput**

```gdscript
## src/player/player_input.gd
class_name PlayerInput
extends Node

## Обработка ввода: джойстик + tap-to-move. Приоритет: джойстик > tap.

signal zone_button_pressed()

var _player: PlayerCharacter
var _joystick: VirtualJoystick
var _camera: Camera3D
var _tap_target: Vector3 = Vector3.ZERO
var _has_tap_target: bool = false
const TAP_ARRIVE_DISTANCE: float = 0.3


func setup(player: PlayerCharacter, joystick: VirtualJoystick, camera: Camera3D) -> void:
	_player = player
	_joystick = joystick
	_camera = camera


func _process(_delta: float) -> void:
	if _player == null:
		return
	var joy_dir: Vector2 = _joystick.get_direction() if _joystick != null else Vector2.ZERO
	if joy_dir.length() > 0.1:
		# Джойстик — приоритет
		_has_tap_target = false
		var direction := Vector3(joy_dir.x, 0, joy_dir.y)
		_player.set_move_direction(direction)
	elif _has_tap_target:
		# Tap-to-move
		var to_target: Vector3 = _tap_target - _player.global_position
		to_target.y = 0
		if to_target.length() < TAP_ARRIVE_DISTANCE:
			_has_tap_target = false
			_player.set_move_direction(Vector3.ZERO)
		else:
			_player.set_move_direction(to_target.normalized())
	else:
		_player.set_move_direction(Vector3.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and _is_in_right_half(touch.position):
			# Тап в правой половине — tap-to-move
			_handle_tap(touch.position)


func _handle_tap(screen_pos: Vector2) -> void:
	if _camera == null:
		return
	var from: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	# Пересечение с плоскостью Y=0
	if dir.y == 0:
		return
	var t: float = -from.y / dir.y
	if t > 0:
		_tap_target = from + dir * t
		_has_tap_target = true


func _is_in_right_half(pos: Vector2) -> bool:
	return pos.x >= get_viewport_rect().size.x / 2.0
```

- [ ] **Step 4: Создать сцену player_character.tscn**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/player/player_character.gd" id="1"]

[node name="PlayerCharacter" type="CharacterBody3D"]
script = ExtResource("1")
```

- [ ] **Step 5: Создать сцену virtual_joystick.tscn**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/controls/virtual_joystick.gd" id="1"]

[node name="VirtualJoystick" type="Control"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("1")

[node name="Base" type="TextureRect" parent="."]
layout_mode = 0
visible = false

[node name="Knob" type="TextureRect" parent="Base"]
layout_mode = 0
```

- [ ] **Step 6: Коммит**

```bash
git add src/player/ src/ui/controls/
git commit -m "feat: игрок с джойстиком, tap-to-move и управлением"
```

---

### Task 6: Враг с базовым AI

**Files:**
- Create: `src/enemies/enemy_base.gd`
- Create: `src/enemies/enemy_base.tscn`
- Create: `src/enemies/enemy_ai.gd`

- [ ] **Step 1: Создать EnemyBase**

```gdscript
## src/enemies/enemy_base.gd
class_name EnemyBase
extends CharacterBody3D

## Базовый враг: движение, стихия, HP, взаимодействие с зонами.

signal died(enemy: EnemyBase)
signal attacked_player(enemy: EnemyBase)

@export var element: ElementTable.Element = ElementTable.Element.FIRE
@export var level: int = 1
@export var move_speed: float = 3.0
@export var attack_range: float = 1.5
@export var attack_damage: int = 1

var hp: int = 1
var max_hp: int = 1
var is_marked: bool = false
var is_enraged: bool = false
var enemy_id: int = -1

var _target: Node3D = null

@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _ai: EnemyAI = $EnemyAI
@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	hp = max_hp
	_setup_visual()


func _physics_process(_delta: float) -> void:
	if _target == null:
		return
	if _ai.current_state == EnemyAI.State.CHASE:
		_nav_agent.target_position = _target.global_position
		if not _nav_agent.is_navigation_finished():
			var next_pos: Vector3 = _nav_agent.get_next_path_position()
			var direction: Vector3 = (next_pos - global_position).normalized()
			direction.y = 0
			var speed: float = move_speed
			if is_enraged:
				speed *= (1.0 + CombatLogic.RAGE_SPEED_BONUS)
			if is_marked:
				speed *= (1.0 - CombatLogic.MARK_SLOW)
			velocity = direction * speed
			move_and_slide()
			if direction.length() > 0:
				look_at(global_position + direction, Vector3.UP)


func set_target(target: Node3D) -> void:
	_target = target


func get_distance_to_target() -> float:
	if _target == null:
		return INF
	return global_position.distance_to(_target.global_position)


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		died.emit(self)


func apply_mark() -> void:
	is_marked = true
	# Визуальный индикатор метки
	if _mesh != null:
		var mat: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_enabled = true
			mat.emission = _get_element_color()
			mat.emission_energy_multiplier = 2.0


func remove_mark() -> void:
	is_marked = false
	if _mesh != null:
		var mat: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_enabled = false


func apply_rage() -> void:
	is_enraged = true


func remove_rage() -> void:
	is_enraged = false


func _setup_visual() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 0.8
	_mesh.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = _get_element_color()
	_mesh.material_override = material


func _get_element_color() -> Color:
	match element:
		ElementTable.Element.FIRE:
			return Color(0.9, 0.2, 0.1)
		ElementTable.Element.WATER:
			return Color(0.1, 0.4, 0.9)
		ElementTable.Element.TREE:
			return Color(0.2, 0.7, 0.2)
		ElementTable.Element.EARTH:
			return Color(0.6, 0.4, 0.2)
		ElementTable.Element.METAL:
			return Color(0.7, 0.7, 0.7)
	return Color.WHITE
```

- [ ] **Step 2: Создать EnemyAI — FSM**

```gdscript
## src/enemies/enemy_ai.gd
class_name EnemyAI
extends Node

## Простая FSM врага: Chase → Telegraph → Attack → Recover.

signal state_changed(new_state: State)
signal attack_executed()

enum State {
	CHASE,
	TELEGRAPH,
	ATTACK,
	RECOVER,
}

const TELEGRAPH_DURATIONS: Dictionary = {
	1: 2.0,
	2: 1.5,
	3: 1.0,
	4: 0.5,
}
const ATTACK_DURATION: float = 0.3
const RECOVER_DURATION: float = 0.5

var current_state: State = State.CHASE
var _timer: float = 0.0
var _enemy: EnemyBase


func _ready() -> void:
	_enemy = get_parent() as EnemyBase


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


func _process_chase() -> void:
	if _enemy.get_distance_to_target() <= _enemy.attack_range:
		_change_state(State.TELEGRAPH)


func _process_telegraph(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_change_state(State.ATTACK)


func _process_attack(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		attack_executed.emit()
		_enemy.attacked_player.emit(_enemy)
		_change_state(State.RECOVER)


func _process_recover(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_change_state(State.CHASE)


func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.TELEGRAPH:
			var duration: float = TELEGRAPH_DURATIONS.get(_enemy.level, 2.0) as float
			_timer = duration
		State.ATTACK:
			_timer = ATTACK_DURATION
		State.RECOVER:
			_timer = RECOVER_DURATION
	state_changed.emit(new_state)
```

- [ ] **Step 3: Создать сцену enemy_base.tscn**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://src/enemies/enemy_base.gd" id="1"]
[ext_resource type="Script" path="res://src/enemies/enemy_ai.gd" id="2"]

[node name="EnemyBase" type="CharacterBody3D"]
script = ExtResource("1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.4, 0)
shape = SubResource("CapsuleShape3D_1")

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_1"]
radius = 0.35
height = 0.8

[node name="NavigationAgent3D" type="NavigationAgent3D" parent="."]
path_desired_distance = 0.5
target_desired_distance = 0.5

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.4, 0)

[node name="EnemyAI" type="Node" parent="."]
script = ExtResource("2")
```

- [ ] **Step 4: Коммит**

```bash
git add src/enemies/
git commit -m "feat: базовый враг с AI FSM (Chase → Telegraph → Attack → Recover)"
```

---

### Task 7: Книга и объект зоны

**Files:**
- Create: `src/arena/map_objects/book_object.gd`
- Create: `src/arena/map_objects/book_object.tscn`
- Create: `src/arena/map_objects/zone_object.gd`
- Create: `src/arena/map_objects/zone_object.tscn`

- [ ] **Step 1: Создать BookObject**

```gdscript
## src/arena/map_objects/book_object.gd
class_name BookObject
extends Node3D

## Книга — источник стихии. Удержание 1 сек → получить случайную стихию.

signal element_picked(element: ElementTable.Element)

const HOLD_DURATION: float = 1.0
const RESPAWN_DELAY: float = 2.0
const INTERACTION_RADIUS: float = 1.5

var _is_active: bool = true
var _hold_timer: float = 0.0
var _is_holding: bool = false
var _respawn_timer: float = 0.0
var _player_in_range: bool = false

@onready var _area: Area3D = $Area3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	_setup_visual()
	_setup_area()
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


func start_hold() -> void:
	if _is_active and _player_in_range:
		_is_holding = true
		_hold_timer = 0.0


func stop_hold() -> void:
	_is_holding = false
	_hold_timer = 0.0


func _activate() -> void:
	_is_holding = false
	_hold_timer = 0.0
	_is_active = false
	_respawn_timer = RESPAWN_DELAY
	_mesh.visible = false
	# Дать случайную стихию (в прототипе — из двух случайных)
	var element: ElementTable.Element = _get_random_element()
	element_picked.emit(element)


func _respawn() -> void:
	_is_active = true
	_mesh.visible = true
	# Можно переместить в новую точку (будущее)


func _get_random_element() -> ElementTable.Element:
	var elements: Array[ElementTable.Element] = [
		ElementTable.Element.FIRE,
		ElementTable.Element.WATER,
		ElementTable.Element.TREE,
		ElementTable.Element.EARTH,
		ElementTable.Element.METAL,
	]
	return elements[randi() % elements.size()]


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerCharacter:
		_player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerCharacter:
		_player_in_range = false
		stop_hold()


func _setup_visual() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.1, 0.4)
	_mesh.mesh = mesh
	_mesh.position.y = 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.5, 0.3)
	_mesh.material_override = material


func _setup_area() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = INTERACTION_RADIUS
	shape.shape = sphere
	_area.add_child(shape)
```

- [ ] **Step 2: Создать ZoneObject**

```gdscript
## src/arena/map_objects/zone_object.gd
class_name ZoneObject
extends Node3D

## Зона на арене — Area3D, определяет эффект при входе врага.

signal enemy_entered_zone(enemy: EnemyBase, zone: ZoneObject)
signal enemy_exited_zone(enemy: EnemyBase, zone: ZoneObject)

var element: ElementTable.Element
var zone_radius: float = 1.5

@onready var _area: Area3D = $Area3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	_setup_visual()
	_setup_area()
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func setup(p_element: ElementTable.Element, p_position: Vector3) -> void:
	element = p_element
	global_position = p_position


func _on_body_entered(body: Node3D) -> void:
	if body is EnemyBase:
		enemy_entered_zone.emit(body as EnemyBase, self)


func _on_body_exited(body: Node3D) -> void:
	if body is EnemyBase:
		enemy_exited_zone.emit(body as EnemyBase, self)


func _setup_visual() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = zone_radius
	mesh.bottom_radius = zone_radius
	mesh.height = 0.05
	_mesh.mesh = mesh
	_mesh.position.y = 0.03
	var material := StandardMaterial3D.new()
	material.albedo_color = _get_element_color()
	material.albedo_color.a = 0.4
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = material


func _get_element_color() -> Color:
	match element:
		ElementTable.Element.FIRE:
			return Color(0.9, 0.2, 0.1)
		ElementTable.Element.WATER:
			return Color(0.1, 0.4, 0.9)
		ElementTable.Element.TREE:
			return Color(0.2, 0.7, 0.2)
		ElementTable.Element.EARTH:
			return Color(0.6, 0.4, 0.2)
		ElementTable.Element.METAL:
			return Color(0.7, 0.7, 0.7)
	return Color.WHITE


func _setup_area() -> void:
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = zone_radius
	cylinder.height = 1.0
	shape.shape = cylinder
	_area.add_child(shape)
	_area.collision_layer = 0
	_area.collision_mask = 2  # Слой врагов
```

- [ ] **Step 3: Создать .tscn файлы**

**book_object.tscn:**
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/arena/map_objects/book_object.gd" id="1"]

[node name="BookObject" type="Node3D"]
script = ExtResource("1")

[node name="Area3D" type="Area3D" parent="."]

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
```

**zone_object.tscn:**
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/arena/map_objects/zone_object.gd" id="1"]

[node name="ZoneObject" type="Node3D"]
script = ExtResource("1")

[node name="Area3D" type="Area3D" parent="."]

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
```

- [ ] **Step 4: Коммит**

```bash
git add src/arena/map_objects/
git commit -m "feat: книга (источник стихии) и объект зоны (Area3D)"
```

---

### Task 8: Минимальный HUD

**Files:**
- Create: `src/ui/hud/hud.gd`
- Create: `src/ui/hud/hud.tscn`

- [ ] **Step 1: Создать HUD**

```gdscript
## src/ui/hud/hud.gd
class_name HUD
extends CanvasLayer

## Минимальный HUD: HP, текущая стихия, кнопка зоны.

signal zone_button_pressed()

@onready var _hp_label: Label = $MarginContainer/VBoxContainer/HPLabel
@onready var _element_label: Label = $MarginContainer/VBoxContainer/ElementLabel
@onready var _zone_button: Button = $ZoneButton


func _ready() -> void:
	_zone_button.pressed.connect(_on_zone_button_pressed)
	update_hp(2)
	update_element(-1)


func update_hp(hp: int) -> void:
	_hp_label.text = "HP: %d" % hp


func update_element(element: int) -> void:
	if element == -1:
		_element_label.text = "Стихия: —"
		_zone_button.disabled = true
	else:
		_element_label.text = "Стихия: %s" % _element_name(element as ElementTable.Element)
		_zone_button.disabled = false


func _element_name(element: ElementTable.Element) -> String:
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


func _on_zone_button_pressed() -> void:
	zone_button_pressed.emit()
```

- [ ] **Step 2: Создать сцену hud.tscn**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/hud/hud.gd" id="1"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1")

[node name="MarginContainer" type="MarginContainer" parent="."]
anchors_preset = 0
offset_left = 10.0
offset_top = 10.0
offset_right = 300.0
offset_bottom = 100.0

[node name="VBoxContainer" type="VBoxContainer" parent="MarginContainer"]
layout_mode = 2

[node name="HPLabel" type="Label" parent="MarginContainer/VBoxContainer"]
layout_mode = 2
text = "HP: 2"

[node name="ElementLabel" type="Label" parent="MarginContainer/VBoxContainer"]
layout_mode = 2
text = "Стихия: —"

[node name="ZoneButton" type="Button" parent="."]
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -120.0
offset_top = -120.0
offset_right = -20.0
offset_bottom = -20.0
text = "Зона"
```

- [ ] **Step 3: Коммит**

```bash
git add src/ui/hud/
git commit -m "feat: минимальный HUD (HP, стихия, кнопка зоны)"
```

---

### Task 9: GameController — оркестратор

**Files:**
- Create: `src/main/game_controller.gd`
- Create: `src/main/game_controller.tscn`

- [ ] **Step 1: Создать GameController**

```gdscript
## src/main/game_controller.gd
class_name GameController
extends Node

## Оркестратор: связывает арену, игрока, врагов, зоны, HUD.

var _arena: ArenaView
var _player: PlayerCharacter
var _player_input: PlayerInput
var _hud: HUD
var _joystick: VirtualJoystick
var _combat_logic: CombatLogic = CombatLogic.new()
var _zone_logic: ZoneLogic = ZoneLogic.new()
var _enemy: EnemyBase
var _active_zones: Array[ZoneObject] = []

const ZONE_SCENE: String = "res://src/arena/map_objects/zone_object.tscn"
const ENEMY_SCENE: String = "res://src/enemies/enemy_base.tscn"


func _ready() -> void:
	_arena = $ArenaView
	_player = $ArenaView/PlayerCharacter
	_hud = $HUD
	_joystick = $UILayer/VirtualJoystick
	_player_input = $PlayerInput

	_player_input.setup(_player, _joystick, _arena._camera)

	# Подключение сигналов
	_player.hp_changed.connect(_hud.update_hp)
	_player.element_changed.connect(_hud.update_element)
	_player.zone_placed.connect(_on_player_zone_placed)
	_hud.zone_button_pressed.connect(_on_zone_button_pressed)

	# Подключение книги
	var book: BookObject = $ArenaView/BookObject
	book.element_picked.connect(_on_element_picked)

	# Подключение боевой логики
	_combat_logic.enemy_marked.connect(_on_enemy_marked)
	_combat_logic.enemy_killed.connect(_on_enemy_killed)
	_combat_logic.enemy_mark_expired.connect(_on_mark_expired)
	_combat_logic.enemy_enraged.connect(_on_enemy_enraged)
	_combat_logic.enemy_rage_expired.connect(_on_rage_expired)

	_spawn_enemy()


func _process(delta: float) -> void:
	_combat_logic.tick(delta)


func _spawn_enemy() -> void:
	var scene: PackedScene = load(ENEMY_SCENE) as PackedScene
	_enemy = scene.instantiate() as EnemyBase
	_enemy.element = ElementTable.Element.FIRE
	_enemy.level = 1
	_enemy.enemy_id = 1
	_enemy.position = Vector3(3, 0, -3)
	_arena.add_child(_enemy)
	_enemy.set_target(_player)
	_enemy.attacked_player.connect(_on_enemy_attacked_player)
	_enemy.died.connect(_on_enemy_died)
	_combat_logic.register_enemy(1, ElementTable.Element.FIRE, 1)


func _on_element_picked(element: ElementTable.Element) -> void:
	_player.pickup_element(element)


func _on_zone_button_pressed() -> void:
	_player.place_zone()


func _on_player_zone_placed(element: ElementTable.Element, pos: Vector3) -> void:
	var scene: PackedScene = load(ZONE_SCENE) as PackedScene
	var zone: ZoneObject = scene.instantiate() as ZoneObject
	_arena.add_child(zone)
	zone.setup(element, pos)
	zone.enemy_entered_zone.connect(_on_enemy_entered_zone)
	zone.enemy_exited_zone.connect(_on_enemy_exited_zone)
	_active_zones.append(zone)
	# FIFO: удалить старую зону если больше лимита
	if _active_zones.size() > ZoneLogic.MAX_ZONES:
		var old_zone: ZoneObject = _active_zones[0]
		_active_zones.remove_at(0)
		old_zone.queue_free()


func _on_enemy_entered_zone(enemy: EnemyBase, zone: ZoneObject) -> void:
	var effect: ZoneLogic.ZoneEffect = ZoneLogic.check_effect(zone.element, enemy.element)
	match effect:
		ZoneLogic.ZoneEffect.COUNTER:
			_combat_logic.try_apply_mark(enemy.enemy_id, zone.element)
		ZoneLogic.ZoneEffect.SAME:
			_combat_logic.try_apply_rage(enemy.enemy_id, zone.element)


func _on_enemy_exited_zone(_enemy_node: EnemyBase, _zone: ZoneObject) -> void:
	pass  # Метка не сбрасывается при выходе


func _on_enemy_marked(enemy_id: int) -> void:
	if _enemy != null and _enemy.enemy_id == enemy_id:
		_enemy.apply_mark()


func _on_mark_expired(enemy_id: int) -> void:
	if _enemy != null and _enemy.enemy_id == enemy_id:
		_enemy.remove_mark()
		if _combat_logic.is_enemy_dead(enemy_id):
			_enemy.take_damage(CombatLogic.MARK_DAMAGE)


func _on_enemy_enraged(enemy_id: int) -> void:
	if _enemy != null and _enemy.enemy_id == enemy_id:
		_enemy.apply_rage()


func _on_rage_expired(enemy_id: int) -> void:
	if _enemy != null and _enemy.enemy_id == enemy_id:
		_enemy.remove_rage()


func _on_enemy_killed(enemy_id: int) -> void:
	if _enemy != null and _enemy.enemy_id == enemy_id:
		_enemy.queue_free()
		_enemy = null


func _on_enemy_died(_enemy_node: EnemyBase) -> void:
	# Обработка смерти через визуал
	pass


func _on_enemy_attacked_player(_enemy_node: EnemyBase) -> void:
	_player.take_damage(1)
```

- [ ] **Step 2: Создать game_controller.tscn**

```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://src/main/game_controller.gd" id="1"]
[ext_resource type="PackedScene" path="res://src/arena/arena_view.tscn" id="2"]
[ext_resource type="PackedScene" path="res://src/player/player_character.tscn" id="3"]
[ext_resource type="PackedScene" path="res://src/ui/hud/hud.tscn" id="4"]
[ext_resource type="PackedScene" path="res://src/ui/controls/virtual_joystick.tscn" id="5"]
[ext_resource type="PackedScene" path="res://src/arena/map_objects/book_object.tscn" id="6"]
[ext_resource type="Script" path="res://src/player/player_input.gd" id="7"]

[node name="GameController" type="Node"]
script = ExtResource("1")

[node name="ArenaView" parent="." instance=ExtResource("2")]

[node name="PlayerCharacter" parent="ArenaView" instance=ExtResource("3")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 3)

[node name="BookObject" parent="ArenaView" instance=ExtResource("6")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -3, 0, 0)

[node name="HUD" parent="." instance=ExtResource("4")]

[node name="UILayer" type="CanvasLayer" parent="."]

[node name="VirtualJoystick" parent="UILayer" instance=ExtResource("5")]

[node name="PlayerInput" type="Node" parent="."]
script = ExtResource("7")
```

- [ ] **Step 3: Коммит**

```bash
git add src/main/
git commit -m "feat: GameController — оркестратор, связывает все системы прототипа"
```

---

## TODO: Следующие фазы (после прототипа)

- [ ] Эскалация (5 врагов → повышение уровней)
- [ ] Все 5 архетипов врагов (Water, Tree, Earth, Metal)
- [ ] Способности + лутбокс
- [ ] Объекты карты: аптечка, укрытие
- [ ] Босс (гибрид 2 стихий)
- [ ] Полный HUD (слот способности, таймер метки)
- [ ] Экран смерти + чекпоинты
- [ ] Меню
- [ ] Монетизация (revive, reroll)
- [ ] Визуал Don't Starve стиль
- [ ] Звук и музыка
- [ ] Мобильный экспорт

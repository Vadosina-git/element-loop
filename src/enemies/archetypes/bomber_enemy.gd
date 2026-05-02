class_name BomberEnemy
extends EnemyBase

## Враг-бомбардир.
##
## Держит дистанцию ~3.5м, бросает бомбу по дуге в текущую точку игрока.
## Бомба взрывается через ~0.7с после приземления — у игрока есть окно реакции.

# --- Константы ---

const ENGAGEMENT_RANGE: float = 5.0
const MIN_RANGE: float = 1.5
const TELEGRAPH_DUR: float = 0.6
const ATTACK_DUR: float = 0.3
const KITE_BACKOFF_BUFFER: float = 0.5

# --- Приватные переменные ---

var _bomb_target: Vector3 = Vector3.ZERO

# --- Виртуалы EnemyBase ---


func get_telegraph_duration() -> float:
	return TELEGRAPH_DUR


func get_attack_duration() -> float:
	return ATTACK_DUR


func get_attack_engagement_range() -> float:
	return ENGAGEMENT_RANGE


func get_attack_min_range() -> float:
	return MIN_RANGE


## Кайт-логика — аналог ranged, но менее агрессивный.
func get_chase_position() -> Vector3:
	if _target == null:
		return global_position
	var to_player: Vector3 = _target.global_position - global_position
	to_player.y = 0.0
	var d: float = to_player.length()
	if d < 0.01:
		return global_position
	if d < MIN_RANGE:
		var back_dir: Vector3 = -to_player / d
		var ideal: float = (MIN_RANGE + ENGAGEMENT_RANGE) * 0.5
		return global_position + back_dir * (ideal - d + KITE_BACKOFF_BUFFER)
	if d > ENGAGEMENT_RANGE:
		return _apply_chase_arc(_target.global_position)
	return global_position


## Снимок точки броска.
func prepare_attack() -> void:
	if _target == null:
		_bomb_target = global_position - global_transform.basis.z
		return
	_bomb_target = _target.global_position
	var to_aim: Vector3 = _bomb_target - global_position
	to_aim.y = 0.0
	if to_aim.length() > 0.01:
		look_at(global_position + to_aim.normalized(), Vector3.UP)


## Спавн бомбы по дуге.
func execute_attack() -> void:
	if _target == null:
		return
	var bomb: Bomb = Bomb.new()
	bomb.element_color = ELEMENT_COLORS.get(element, Color.WHITE)
	get_tree().current_scene.add_child(bomb)
	bomb.arm(global_position + Vector3(0.0, 0.6, 0.0), _bomb_target, _target)


## Debug: круг будущего взрыва + параболическая траектория броска.
func _draw_class_debug(imesh: ImmediateMesh) -> void:
	if _ai == null:
		return
	if _ai.current_state != EnemyAI.State.TELEGRAPH and _ai.current_state != EnemyAI.State.ATTACK:
		return
	var c: Color = Color(1.0, 0.4, 0.1, 0.95)  # оранжевый — bomber
	# Круг будущего взрыва на земле.
	var landing: Vector3 = Vector3(_bomb_target.x, 0.05, _bomb_target.z)
	_debug_draw_circle(imesh, landing, Bomb.EXPLOSION_RADIUS, c, 24)
	_debug_draw_cross(imesh, landing, 0.3, c)
	# Превью траектории: параболическая дуга из 12 сегментов.
	var start: Vector3 = global_position + Vector3(0.0, 0.6, 0.0)
	var prev: Vector3 = start
	for i: int in range(1, 13):
		var t: float = float(i) / 12.0
		var flat: Vector3 = start.lerp(_bomb_target, t)
		var height: float = sin(t * PI) * Bomb.ARC_HEIGHT
		var pt: Vector3 = Vector3(flat.x, _bomb_target.y + height, flat.z)
		imesh.surface_set_color(c)
		imesh.surface_add_vertex(prev)
		imesh.surface_set_color(c)
		imesh.surface_add_vertex(pt)
		prev = pt


## Анимация: круговой замах в TELEGRAPH, рывок вперёд при броске.
func _animate_attack(_delta: float) -> float:
	if _mesh == null or _ai == null:
		return 0.0
	if _ai.current_state == EnemyAI.State.TELEGRAPH:
		var p: float = clampf(_ai._timer / get_telegraph_duration(), 0.0, 1.0)
		# Замах: меш отклоняется назад и в сторону.
		_mesh.rotation.x = sin(p * PI) * 0.35
		_mesh.rotation.z = sin(p * PI * 2.0) * 0.2
		_mesh.position.y = -sin(p * PI) * 0.05
		_mesh.scale = _mesh_base_scale
	elif _ai.current_state == EnemyAI.State.ATTACK:
		# Резкий выпад вперёд.
		var p: float = clampf(_ai._timer / get_attack_duration(), 0.0, 1.0)
		_mesh.rotation.x = lerpf(-0.4, 0.0, p)
		_mesh.rotation.z = 0.0
		_mesh.position.y = 0.0
		_mesh.scale = _mesh_base_scale
	return 0.0

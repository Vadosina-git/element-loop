class_name RangedEnemy
extends EnemyBase

## Враг дальнего боя.
##
## Кайтит — держит «комфортную дистанцию» 2.0–4.5м. Игрок ближе → отступает,
## дальше → подходит. Стреляет стрелами по линии зрения. Урон — на снаряде.

# --- Константы ---

const ENGAGEMENT_RANGE: float = 4.5
const MIN_RANGE: float = 2.0
const TELEGRAPH_DUR: float = 0.5
const ATTACK_DUR: float = 0.2
const KITE_BACKOFF_BUFFER: float = 0.5

# --- Приватные переменные ---

var _aim_target: Vector3 = Vector3.ZERO

# --- Виртуалы EnemyBase ---


func get_telegraph_duration() -> float:
	return TELEGRAPH_DUR


func get_attack_duration() -> float:
	return ATTACK_DUR


func get_attack_engagement_range() -> float:
	return ENGAGEMENT_RANGE


func get_attack_min_range() -> float:
	return MIN_RANGE


## Кайт-логика: ближе MIN — отступаем, дальше ENGAGEMENT — подходим, иначе стоим.
func get_chase_position() -> Vector3:
	if _target == null:
		return global_position
	var to_player: Vector3 = _target.global_position - global_position
	to_player.y = 0.0
	var d: float = to_player.length()
	if d < 0.01:
		return global_position
	if d < MIN_RANGE:
		# Отступаем строго от игрока.
		var back_dir: Vector3 = -to_player / d
		var ideal: float = (MIN_RANGE + ENGAGEMENT_RANGE) * 0.5
		return global_position + back_dir * (ideal - d + KITE_BACKOFF_BUFFER)
	if d > ENGAGEMENT_RANGE:
		# Подходит ближе — с боковой дугой, чтобы не сходиться по прямой с другими.
		return _apply_chase_arc(_target.global_position)
	# Стоит и стреляет.
	return global_position


## Снимок точки прицеливания.
func prepare_attack() -> void:
	if _target == null:
		_aim_target = global_position - global_transform.basis.z
		return
	_aim_target = _target.global_position
	var to_aim: Vector3 = _aim_target - global_position
	to_aim.y = 0.0
	if to_aim.length() > 0.01:
		look_at(global_position + to_aim.normalized(), Vector3.UP)


## Спавн стрелы.
func execute_attack() -> void:
	if _target == null:
		return
	var spawn_pos: Vector3 = global_position + Vector3(0.0, 0.8, 0.0)
	var aim_pos: Vector3 = _aim_target + Vector3(0.0, 0.8, 0.0)
	var dir: Vector3 = aim_pos - spawn_pos
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	# Лёгкий отступ от тела, чтобы стрела не спавнилась внутри собственного коллайдера.
	var dir_norm: Vector3 = dir.normalized()
	spawn_pos += dir_norm * 0.5

	var arrow: Arrow = Arrow.new()
	arrow.element_color = ELEMENT_COLORS.get(element, Color.WHITE)
	get_tree().current_scene.add_child(arrow)
	arrow.launch(spawn_pos, dir_norm, _target)


## Debug: линия прицеливания от врага к зафиксированной точке.
## В TELEGRAPH (натяжка) — пунктирно-яркая, в ATTACK — краткий вспышечный след.
func _draw_class_debug(imesh: ImmediateMesh) -> void:
	if _ai == null:
		return
	if _ai.current_state != EnemyAI.State.TELEGRAPH and _ai.current_state != EnemyAI.State.ATTACK:
		return
	var c: Color = Color(1.0, 0.85, 0.2, 0.95)  # золотой — ranged
	var from: Vector3 = global_position + Vector3(0.0, 0.8, 0.0)
	var to: Vector3 = _aim_target + Vector3(0.0, 0.8, 0.0)
	# Линия наведения.
	imesh.surface_set_color(c)
	imesh.surface_add_vertex(from)
	imesh.surface_set_color(c)
	imesh.surface_add_vertex(to)
	# Перекрестие в точке прицела на земле.
	var ground: Vector3 = Vector3(_aim_target.x, 0.05, _aim_target.z)
	_debug_draw_cross(imesh, ground, 0.3, c)
	_debug_draw_circle(imesh, ground, 0.3, c, 16)


## Анимация: лёгкий откат назад в TELEGRAPH (натяжка), рывок вперёд при выстреле.
func _animate_attack(_delta: float) -> float:
	if _mesh == null or _ai == null:
		return 0.0
	if _ai.current_state == EnemyAI.State.TELEGRAPH:
		var p: float = clampf(_ai._timer / get_telegraph_duration(), 0.0, 1.0)
		# Откат: меш чуть назад и слегка приседает.
		_mesh.position.z = -sin(p * PI) * 0.15
		_mesh.position.y = -sin(p * PI) * 0.05
		_mesh.scale = _mesh_base_scale
		_mesh.rotation.x = sin(p * PI) * 0.15
	elif _ai.current_state == EnemyAI.State.ATTACK:
		# Резкое движение вперёд (отдача).
		var p: float = clampf(_ai._timer / get_attack_duration(), 0.0, 1.0)
		_mesh.position.z = lerpf(0.15, 0.0, p)
		_mesh.position.y = 0.0
		_mesh.scale = _mesh_base_scale
		_mesh.rotation.x = -0.1
	return 0.0

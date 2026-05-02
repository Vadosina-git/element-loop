class_name MeleeEnemy
extends EnemyBase

## Враг ближнего боя.
##
## Подходит на короткую дистанцию, приседает 300мс, прыгает по дуге к снимку
## позиции игрока. Урон засчитывается, если приземлился в attack_range × 1.3.

# --- Константы ---

## Множитель радиуса при проверке попадания на приземлении.
const LANDING_HIT_FACTOR: float = 1.3

## Высота арки прыжка (макс).
const LEAP_ARC_HEIGHT: float = 0.7

# --- Приватные переменные ---

## Скорость прыжка, рассчитанная в prepare_attack и применённая в execute_attack.
var _leap_velocity: Vector3 = Vector3.ZERO

## Абсолютная точка приземления, зафиксированная на момент приседа.
## Используется и для debug-метки, и для проверки попадания.
var _leap_landing_pos: Vector3 = Vector3.ZERO


# --- Виртуалы EnemyBase ---


## Радиус подготовки атаки = 1/3 от радиуса детекции.
func get_attack_engagement_range() -> float:
	return detection_range / 3.0


func get_telegraph_duration() -> float:
	return 0.3


func get_attack_duration() -> float:
	return 0.4


## Снимок направления и дистанции до игрока.
func prepare_attack() -> void:
	_leap_velocity = Vector3.ZERO
	_leap_landing_pos = global_position
	if _target == null:
		return
	var to_target: Vector3 = _target.global_position - global_position
	to_target.y = 0.0
	var dist: float = to_target.length()
	var leap_duration: float = get_attack_duration()
	if dist < 0.01:
		_leap_velocity = -global_transform.basis.z * (get_attack_engagement_range() / leap_duration)
		_leap_landing_pos = global_position + _leap_velocity * leap_duration
		return
	var dir: Vector3 = to_target / dist
	# Прыгаем чуть дальше игрока, чтобы перекрыть его текущую позицию.
	var leap_dist: float = clampf(dist + 0.2, 0.5, get_attack_engagement_range() + 0.5)
	_leap_velocity = dir * (leap_dist / leap_duration)
	_leap_landing_pos = global_position + _leap_velocity * leap_duration
	# Развернуться лицом к цели на момент приседа.
	look_at(global_position + dir, Vector3.UP)


## Включает прыжок: задаём _attack_velocity, который читается в _physics_process.
func execute_attack() -> void:
	_attack_velocity = _leap_velocity


## На приземлении — урон, если игрок остался внутри зафиксированной зоны приземления.
## Эта проверка совпадает с debug-меткой: видишь круг — отбегай за его край.
func resolve_attack_landing() -> void:
	if _target == null:
		return
	var landing_flat: Vector3 = Vector3(_leap_landing_pos.x, 0.0, _leap_landing_pos.z)
	var player_flat: Vector3 = Vector3(_target.global_position.x, 0.0, _target.global_position.z)
	if landing_flat.distance_to(player_flat) <= attack_range * LANDING_HIT_FACTOR:
		attacked_player.emit(self)


## Debug: метка на земле в точке предполагаемого приземления + линия от врага.
func _draw_class_debug(imesh: ImmediateMesh) -> void:
	if _ai == null:
		return
	if _ai.current_state != EnemyAI.State.TELEGRAPH and _ai.current_state != EnemyAI.State.ATTACK:
		return
	# Зафиксированная точка приземления (set в prepare_attack), не двигается во время прыжка.
	var landing: Vector3 = Vector3(_leap_landing_pos.x, 0.05, _leap_landing_pos.z)
	var c: Color = Color(0.6, 0.4, 1.0, 0.95)  # фиолетовый — melee
	# Круг + крест на месте приземления.
	_debug_draw_circle(imesh, landing, attack_range * LANDING_HIT_FACTOR, c, 20)
	_debug_draw_cross(imesh, landing, 0.25, c)
	# Линия от врага до точки.
	imesh.surface_set_color(c)
	imesh.surface_add_vertex(global_position + Vector3(0.0, 0.1, 0.0))
	imesh.surface_set_color(c)
	imesh.surface_add_vertex(landing)


## Анимация: squash в TELEGRAPH, дуга в ATTACK.
func _animate_attack(_delta: float) -> float:
	if _mesh == null or _ai == null:
		return 0.0

	var label_bounce: float = 0.0

	if _ai.current_state == EnemyAI.State.TELEGRAPH:
		var prep_dur: float = get_telegraph_duration()
		var p: float = clampf(_ai._timer / prep_dur, 0.0, 1.0)
		var squash: float = sin(p * PI) * 0.45
		var sx: float = 1.0 + squash * 0.35
		var sy: float = 1.0 - squash
		_mesh.scale = Vector3(_mesh_base_scale.x * sx, _mesh_base_scale.y * sy, _mesh_base_scale.z * sx)
		_mesh.position.y = -squash * 0.15
		_mesh.rotation.x = 0.0
		_mesh.rotation.z = 0.0
	elif _ai.current_state == EnemyAI.State.ATTACK:
		var p: float = clampf(_ai._timer / get_attack_duration(), 0.0, 1.0)
		_mesh.position.y = sin(p * PI) * LEAP_ARC_HEIGHT
		_mesh.scale = Vector3(_mesh_base_scale.x * 0.9, _mesh_base_scale.y * 1.15, _mesh_base_scale.z * 0.9)
		_mesh.rotation.x = -0.25
		_mesh.rotation.z = 0.0
		label_bounce = _mesh.position.y * 0.4

	return label_bounce

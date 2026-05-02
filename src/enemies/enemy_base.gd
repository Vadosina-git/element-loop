class_name EnemyBase
extends CharacterBody3D

## Базовый враг.
##
## CharacterBody3D с навигацией, визуалом и AI (FSM).
## Все враги-архетипы наследуют этот скрипт.

# --- Сигналы ---

signal died(enemy: EnemyBase)
signal attacked_player(enemy: EnemyBase)

# --- Константы ---

## Цвета стихий для визуального отображения.
const ELEMENT_COLORS: Dictionary = {
	ElementTable.Element.FIRE: Color(0.9, 0.2, 0.1),
	ElementTable.Element.WATER: Color(0.1, 0.4, 0.9),
	ElementTable.Element.TREE: Color(0.2, 0.7, 0.2),
	ElementTable.Element.EARTH: Color(0.6, 0.4, 0.2),
	ElementTable.Element.METAL: Color(0.7, 0.7, 0.7),
}

const DEATH_FREEZE_TIME: float = 0.0
const DEATH_EXPLODE_TIME: float = 0.5
const DEATH_SCALE_MAX: float = 3.0

## Значки стихий — через ElementIcons (эмодзи/юникод по платформе).

# --- Экспортируемые переменные ---

@export var element: ElementTable.Element = ElementTable.Element.FIRE
@export var level: int = 1
@export var move_speed: float = 1.5
@export var attack_range: float = 0.55
@export var attack_damage: int = 1
@export var detection_range: float = 5.0
const PULSE_RADIUS: float = 2.0

## Дефолтные значения окна атаки. Подклассы переопределяют через виртуалы.
const DEFAULT_TELEGRAPH_DURATION: float = 0.3
const DEFAULT_ATTACK_DURATION: float = 0.4

# --- Публичные переменные ---

var hp: int = 1
var max_hp: int = 1
var is_marked: bool = false
var is_enraged: bool = false
var enemy_id: int = -1

## Точка, к которой враг идёт в состоянии SEARCH (последняя крошка).
## Устанавливается из EnemyAI.
var investigation_target: Vector3 = Vector3.ZERO

## Игрок внутри Area3D-зоны детекции. Управляется сигналами body_entered/exited.
var player_in_range: bool = false

# --- Приватные переменные ---

var _target: Node3D = null
var _material: StandardMaterial3D = null
var _anim_time: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _detection_circle: MeshInstance3D = null
var _pulse_circle: MeshInstance3D = null
var _pulse_material: ShaderMaterial = null
var _is_highlighted: bool = false
var _nav_update_timer: float = 0.0
var _cached_move_dir: Vector3 = Vector3.ZERO
var _element_texture: Texture2D = null
var _alert_texture: Texture2D = null
var _is_chasing_icon: bool = false
var _agony_timer: float = 0.0
var _agony_target_rotation: float = 0.0
var _agony_jump_timer: float = 0.0
var _is_dying: bool = false
var _death_timer: float = 0.0
var _element_sprite: Sprite3D = null
var _detection_area: Area3D = null
var _detection_shape: SphereShape3D = null

## Скорость движения в фазе ATTACK. Дефолт — стоит на месте.
## Melee переопределяет prepare_attack / execute_attack для прыжка.
var _attack_velocity: Vector3 = Vector3.ZERO

## Базовый scale меша — для возврата после squash/stretch анимаций.
var _mesh_base_scale: Vector3 = Vector3.ONE

# --- Параметры боковой дуги преследования (уникальны на врага) ---
## Частота колебаний бокового смещения (рад/сек).
var _arc_freq: float = 0.5
## Амплитуда бокового смещения (метры).
var _arc_amplitude: float = 0.5
## Фазовый сдвиг — каждый враг ловит свою фазу синусоиды.
var _arc_phase: float = 0.0

# --- Отладочная визуализация LoS и крошек (временно) ---
static var debug_visible: bool = true
var _debug_mesh: MeshInstance3D = null
var _debug_imesh: ImmediateMesh = null

# --- @onready переменные ---

@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _ai: EnemyAI = $EnemyAI
@onready var _mesh: MeshInstance3D = $MeshInstance3D

# --- Встроенные колбеки ---


func _ready() -> void:
	hp = max_hp
	# Уникальные параметры боковой дуги — чтобы враги не шли по одной траектории.
	_arc_phase = randf() * TAU
	_arc_freq = randf_range(0.4, 0.8)
	_arc_amplitude = randf_range(0.35, 0.7)
	_setup_visual()
	_setup_element_label()
	_setup_detection_circle()
	_setup_detection_area()
	_setup_debug_visual()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_K:
			debug_visible = not debug_visible


func _physics_process(delta: float) -> void:
	if _is_dying:
		_process_death(delta)
		return

	var current: EnemyAI.State = _ai.current_state
	var is_moving: bool = false

	# Навигация работает только в состояниях, где враг идёт за целью.
	# TELEGRAPH (присед) и ATTACK (прыжок) — отдельные ветки ниже.
	var is_aggressive: bool = current in [EnemyAI.State.CHASE, EnemyAI.State.SEARCH, EnemyAI.State.RECOVER]

	if is_aggressive:
		if _target != null:
			# В SEARCH цель — последняя крошка, иначе — позиция от виртуала класса.
			var goal_pos: Vector3 = investigation_target if current == EnemyAI.State.SEARCH else get_chase_position()

			# Пересчитываем направление раз в 0.3 сек
			_nav_update_timer -= delta
			if _nav_update_timer <= 0.0:
				_nav_update_timer = 0.3
				var to_goal_xz: Vector3 = goal_pos - global_position
				to_goal_xz.y = 0.0
				# Цель совпадает с текущей позицией (например, ranged стоит в зоне) —
				# не дёргаем NavAgent, просто стоим. Иначе фолбэк зашумлял бы лог.
				if to_goal_xz.length() < 0.3:
					_cached_move_dir = Vector3.ZERO
				else:
					var new_dir: Vector3 = Vector3.ZERO
					if _nav_agent != null:
						_nav_agent.target_position = goal_pos
						if not _nav_agent.is_navigation_finished():
							var next_pos: Vector3 = _nav_agent.get_next_path_position()
							next_pos.y = global_position.y
							new_dir = next_pos - global_position

					if new_dir.length_squared() < 0.01:
						# Нав-меш не дал пути — идём прямо. Фолбэк, без шума в логе.
						new_dir = to_goal_xz

					new_dir.y = 0.0
					if new_dir.length() > 0.1:
						_cached_move_dir = new_dir.normalized()
					else:
						_cached_move_dir = Vector3.ZERO

			if _cached_move_dir.length() > 0.1:
				# Плавный поворот — быстрее враг → быстрее поворачивает
				var current_dir: Vector3 = velocity.normalized() if velocity.length() > 0.1 else _cached_move_dir
				var speed: float = _get_modified_speed()
				var lerp_factor: float = 15.0 * (speed / move_speed)
				var smooth_dir: Vector3 = current_dir.lerp(_cached_move_dir, lerp_factor * delta).normalized()
				velocity = smooth_dir * speed
				look_at(global_position + smooth_dir, Vector3.UP)
				is_moving = true
			else:
				velocity = Vector3.ZERO
		else:
			velocity = Vector3.ZERO

	elif current == EnemyAI.State.WANDER:
		# Патрулирование
		if _wander_direction.length() > 0.1:
			var speed: float = move_speed * 0.3  # Идём медленнее при патруле
			velocity = _wander_direction * speed
			look_at(global_position + _wander_direction, Vector3.UP)
			is_moving = true
		else:
			# Нет направления — гасим скорость по инерции, не сбрасываем мгновенно.
			# Это даёт «коаст» при выходе из погони: враг едет по инерции, замедляется и встаёт.
			velocity = velocity.lerp(Vector3.ZERO, delta * 4.0)
			if velocity.length() > 0.1:
				is_moving = true
	elif current == EnemyAI.State.TELEGRAPH:
		# Присед перед прыжком — стоим на месте.
		velocity = Vector3.ZERO
	elif current == EnemyAI.State.ATTACK:
		# Фаза атаки — движение задаётся классом через _attack_velocity.
		# Melee = leap velocity, ranged/bomber = ноль (стоят, спавнят снаряд в execute_attack).
		velocity = _attack_velocity
		if _attack_velocity.length() > 0.1:
			var atk_dir: Vector3 = _attack_velocity.normalized()
			look_at(global_position + atk_dir, Vector3.UP)

	move_and_slide()

	# Иконка: восклицательный знак при погоне, стихия при патруле
	_update_chase_icon(is_aggressive)

	# При столкновении в патруле — смена направления
	if is_moving and not is_aggressive:
		for i: int in range(get_slide_collision_count()):
			var col: KinematicCollision3D = get_slide_collision(i)
			if absf(col.get_normal().y) < 0.5:
				_ai.on_hit_obstacle()
				break

	_update_detection_circle()
	_animate(delta, is_moving)
	_update_debug_visual()


# --- Публичные методы ---


## Установить цель для преследования.
func set_target(target: Node3D) -> void:
	_target = target
	# Если игрок уже находится внутри зоны детекции на момент назначения —
	# body_entered не сработает задним числом, поэтому проверяем вручную.
	if target == null:
		player_in_range = false
		return
	if _detection_area != null:
		var overlaps: Array[Node3D] = _detection_area.get_overlapping_bodies()
		player_in_range = target in overlaps


## Проверяет, видит ли враг указанную цель (нет преград между ними).
##
## Луч пускается на высоте 0.8 от обоих участников, исключая их самих.
## Любое попадание (стена/камень) — цель не видна.
func has_line_of_sight_to(target: Node3D) -> bool:
	if target == null:
		return false
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return false
	var eye_offset: Vector3 = Vector3(0.0, 0.8, 0.0)
	var from: Vector3 = global_position + eye_offset
	var to: Vector3 = target.global_position + eye_offset
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	var excludes: Array[RID] = [self.get_rid()]
	if target is CollisionObject3D:
		excludes.append((target as CollisionObject3D).get_rid())
	query.exclude = excludes
	var hit: Dictionary = space.intersect_ray(query)
	return hit.is_empty()


## Получить расстояние до цели (только по XZ, без учёта высоты).
func get_distance_to_target() -> float:
	if _target == null:
		return INF
	var diff: Vector3 = global_position - _target.global_position
	diff.y = 0.0
	return diff.length()


## Получить урон. При HP <= 0 испускает сигнал died.
func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		hp = 0
		died.emit(self)


## Запускает анимацию смерти (замирание → взрыв → исчезновение).
func start_death() -> void:
	if _is_dying:
		return
	_is_dying = true
	_death_timer = 0.0
	velocity = Vector3.ZERO
	if _material != null:
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


## Включает/выключает пульсирующую подсветку уязвимости.
func set_highlighted(enabled: bool) -> void:
	_is_highlighted = enabled
	if _pulse_circle != null:
		_pulse_circle.visible = enabled


## Задаёт направление патрулирования (от AI).
func set_wander_direction(direction: Vector3) -> void:
	_wander_direction = direction


## Наложить метку (замедление, визуальный эффект).
func apply_mark() -> void:
	is_marked = true
	if _material != null:
		_material.emission_enabled = true
		_material.emission = Color.WHITE
		_material.emission_energy_multiplier = 0.8


## Снять метку.
func remove_mark() -> void:
	is_marked = false
	_agony_timer = 0.0
	_agony_jump_timer = 0.0
	if _mesh != null:
		_mesh.rotation.y = 0.0
	if _material != null:
		_material.emission_enabled = false


## Наложить ярость (ускорение).
func apply_rage() -> void:
	is_enraged = true


## Снять ярость.
func remove_rage() -> void:
	is_enraged = false


## --- Виртуальные хуки для классов врагов (melee/ranged/bomber) ---
## Подклассы переопределяют, чтобы задать своё поведение атаки.

## Длительность фазы подготовки атаки.
func get_telegraph_duration() -> float:
	return DEFAULT_TELEGRAPH_DURATION


## Длительность фазы выполнения атаки.
func get_attack_duration() -> float:
	return DEFAULT_ATTACK_DURATION


## Дистанция, на которой враг переходит из CHASE в TELEGRAPH.
func get_attack_engagement_range() -> float:
	return 1.5


## Минимальная дистанция, ниже которой враг НЕ начинает атаку.
## Для ranged — комфортная дистанция, чтобы не стрелять в упор.
func get_attack_min_range() -> float:
	return 0.0


## Куда враг идёт в фазе CHASE. Дефолт — к игроку с лёгким боковым отклонением,
## чтобы несколько врагов не сходились в одну точку.
## Ranged/bomber переопределяют для kite-логики.
func get_chase_position() -> Vector3:
	if _target == null:
		return global_position
	return _apply_chase_arc(_target.global_position)


## Прибавляет к точке-цели небольшое боковое смещение (перпендикуляр к направлению).
## Затухает на близкой дистанции, чтобы враг точно подошёл к игроку.
func _apply_chase_arc(target_pos: Vector3) -> Vector3:
	var to_target: Vector3 = target_pos - global_position
	to_target.y = 0.0
	var dist: float = to_target.length()
	if dist < 0.5:
		return target_pos
	var dir: Vector3 = to_target / dist
	# Перпендикуляр в горизонтальной плоскости.
	var perp: Vector3 = Vector3(-dir.z, 0.0, dir.x)
	# Смещение колеблется во времени, фаза/частота уникальны на врага.
	var t: float = float(Time.get_ticks_msec()) * 0.001
	var offset: float = sin(t * _arc_freq + _arc_phase) * _arc_amplitude
	# Затухание при подходе ближе 2.5м — чтобы не кружить вокруг игрока.
	var fade: float = clampf((dist - 0.8) / 1.7, 0.0, 1.0)
	return target_pos + perp * offset * fade


## Старт фазы TELEGRAPH (CHASE → TELEGRAPH). Сделать снимок цели/направления.
func prepare_attack() -> void:
	pass


## Старт фазы ATTACK (TELEGRAPH → ATTACK). Спавнить снаряды или задавать leap-скорость.
func execute_attack() -> void:
	pass


## Конец фазы ATTACK (перед переходом в RECOVER).
## Melee проверяет здесь дистанцию приземления и наносит урон.
## Ranged/bomber оставляют пустым — урон обрабатывается в снаряде.
func resolve_attack_landing() -> void:
	pass


## Класс-специфичная отладочная отрисовка (метка прыжка / линия выстрела / круг бомбы).
## Подклассы переопределяют. Вызывается внутри открытого ImmediateMesh.surface_begin блока.
func _draw_class_debug(_imesh: ImmediateMesh) -> void:
	pass


## Helper: рисует горизонтальный круг на земле как набор отрезков (ImmediateMesh PRIMITIVE_LINES).
func _debug_draw_circle(imesh: ImmediateMesh, center: Vector3, radius: float, color: Color, segments: int = 20) -> void:
	var prev: Vector3 = center + Vector3(radius, 0.0, 0.0)
	for i: int in range(1, segments + 1):
		var a: float = float(i) / float(segments) * TAU
		var pt: Vector3 = center + Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		imesh.surface_set_color(color)
		imesh.surface_add_vertex(prev)
		imesh.surface_set_color(color)
		imesh.surface_add_vertex(pt)
		prev = pt


## Helper: маркер-крестик на земле (без круга, для тонких меток).
func _debug_draw_cross(imesh: ImmediateMesh, center: Vector3, size: float, color: Color) -> void:
	imesh.surface_set_color(color)
	imesh.surface_add_vertex(center + Vector3(-size, 0.0, 0.0))
	imesh.surface_set_color(color)
	imesh.surface_add_vertex(center + Vector3(size, 0.0, 0.0))
	imesh.surface_set_color(color)
	imesh.surface_add_vertex(center + Vector3(0.0, 0.0, -size))
	imesh.surface_set_color(color)
	imesh.surface_add_vertex(center + Vector3(0.0, 0.0, size))


## Анимация в фазах TELEGRAPH/ATTACK. Вызывается из _animate каждый кадр.
## Возвращает дополнительное смещение для значка стихии (label_bounce).
## Дефолт — лёгкое подёргивание; melee переопределяет под squash+arc.
func _animate_attack(_delta: float) -> float:
	if _mesh == null:
		return 0.0
	# Нейтральная подготовка/выпад: лёгкое наклонение вперёд.
	_mesh.rotation.x = -0.15
	_mesh.position.y = 0.0
	return 0.0


# --- Приватные методы ---


## Обрабатывает анимацию смерти: замирание → увеличение + прозрачность.
func _process_death(delta: float) -> void:
	_death_timer += delta

	if _death_timer <= DEATH_FREEZE_TIME:
		# Фаза замирания — стоим на месте
		return

	# Фаза взрыва — увеличение + уход в прозрачность
	var explode_progress: float = (_death_timer - DEATH_FREEZE_TIME) / DEATH_EXPLODE_TIME
	if explode_progress >= 1.0:
		queue_free()
		return

	var s: float = lerpf(1.0, DEATH_SCALE_MAX, explode_progress)
	if _mesh != null:
		_mesh.scale = Vector3(s, s, s)
	if _material != null:
		var alpha: float = lerpf(1.0, 0.0, explode_progress)
		_material.albedo_color.a = alpha
	if _element_sprite != null:
		_element_sprite.modulate.a = lerpf(1.0, 0.0, explode_progress)
	# Скрываем круги
	if _detection_circle != null:
		_detection_circle.visible = false
	if _pulse_circle != null:
		_pulse_circle.visible = false


## Переключает иконку над врагом: стихия ↔ восклицательный знак.
func _update_chase_icon(is_aggressive: bool) -> void:
	if _element_sprite == null:
		return
	if is_aggressive and not _is_chasing_icon:
		_is_chasing_icon = true
		if _alert_texture != null:
			_element_sprite.texture = _alert_texture
			_element_sprite.modulate = Color.WHITE
	elif not is_aggressive and _is_chasing_icon:
		_is_chasing_icon = false
		if _element_texture != null:
			_element_sprite.texture = _element_texture
			_element_sprite.modulate = Color.WHITE


## Возвращает скорость с учётом модификаторов ярости и метки.
func _get_modified_speed() -> float:
	var speed: float = move_speed
	if is_enraged:
		speed *= (1.0 + CombatLogic.RAGE_SPEED_BONUS)
	if is_marked:
		speed *= (1.0 - CombatLogic.MARK_SLOW)
	return speed


## Создаёт значок стихии над головой врага.
func _setup_element_label() -> void:
	_element_texture = ElementIcons.get_texture(element)
	_alert_texture = ElementIcons.get_alert_texture()
	if _element_texture != null:
		_element_sprite = Sprite3D.new()
		_element_sprite.texture = _element_texture
		_element_sprite.pixel_size = 0.00225
		_element_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_element_sprite.no_depth_test = true
		_element_sprite.position = Vector3(0.0, 1.2, 0.0)
		add_child(_element_sprite)


## Создаёт пунктирный круг зоны обнаружения.
func _setup_detection_circle() -> void:
	_detection_circle = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var circle_size: float = detection_range * 2.0
	plane.size = Vector2(circle_size, circle_size)
	_detection_circle.mesh = plane
	_detection_circle.set_as_top_level(true)

	var shader := Shader.new()
	shader.code = "
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform vec4 circle_color : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform float time_scale = 0.5;
uniform float ring_count = 3.0;
uniform float ring_width = 0.5;

void fragment() {
	vec2 uv_centered = UV - vec2(0.5);
	float dist = length(uv_centered) * 2.0;

	// Неоновое кольцо по краю (Brawl Stars style)
	float edge = 0.88;
	float sharp_line = (1.0 - smoothstep(0.0, 0.008, abs(dist - edge))) * 0.64;
	float inner_fill = (1.0 - smoothstep(0.0, 0.88, dist)) * 0.024;

	// Пульсирующие волны от центра
	float wave = fract(dist * ring_count - TIME * time_scale);
	float pulse = smoothstep(0.0, ring_width, wave) * (1.0 - smoothstep(ring_width, ring_width * 2.0, wave));
	float fade = 1.0 - dist;
	float pulse_alpha = pulse * fade * 0.15;

	float base_fill = step(dist, 0.88) * 0.064;
	float alpha = (sharp_line + inner_fill + pulse_alpha + base_fill) * step(dist, 1.0) * 0.7;

	ALBEDO = circle_color.rgb;
	ALPHA = alpha;
}
"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	var bright: Color = color.lightened(0.3)
	mat.set_shader_parameter("circle_color", Color(bright.r, bright.g, bright.b, 1.0))

	mat.render_priority = 1
	_detection_circle.material_override = mat
	add_child(_detection_circle)

	# Пульсирующие концентрические круги (подсветка уязвимости)
	_setup_pulse_circle()




## Создаёт пульсирующие концентрические круги для подсветки уязвимости.
func _setup_pulse_circle() -> void:
	_pulse_circle = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var circle_size: float = PULSE_RADIUS * 2.0
	plane.size = Vector2(circle_size, circle_size)
	_pulse_circle.mesh = plane
	_pulse_circle.set_as_top_level(true)
	_pulse_circle.visible = false

	var shader := Shader.new()
	shader.code = "
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 pulse_color : source_color = vec4(0.2, 0.7, 0.2, 0.8);
uniform float time_scale = 0.5;
uniform float ring_count = 3.0;
uniform float ring_width = 0.5;

void fragment() {
	vec2 uv_centered = UV - vec2(0.5);
	float dist = length(uv_centered) * 2.0;
	float circle_mask = step(dist, 1.0);
	float wave = fract(dist * ring_count - TIME * time_scale);
	float ring = smoothstep(0.0, ring_width, wave) * (1.0 - smoothstep(ring_width, ring_width * 2.0, wave));
	float fade = 1.0 - dist;
	float alpha = ring * fade * circle_mask * pulse_color.a;
	ALBEDO = pulse_color.rgb;
	ALPHA = alpha;
}
"
	_pulse_material = ShaderMaterial.new()
	_pulse_material.shader = shader
	var color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	var bright: Color = color.lightened(0.4)
	_pulse_material.set_shader_parameter("pulse_color", Color(bright.r, bright.g, bright.b, 0.45))

	_pulse_material.render_priority = 1
	_pulse_circle.material_override = _pulse_material
	add_child(_pulse_circle)


## Обновляет позицию кругов (top-level, не вращаются с врагом).
func _update_detection_circle() -> void:
	var flat_pos: Vector3 = Vector3(global_position.x, 0.25, global_position.z)
	if _detection_circle != null:
		_detection_circle.global_position = flat_pos
		_detection_circle.global_rotation = Vector3.ZERO
	if _pulse_circle != null and _pulse_circle.visible:
		_pulse_circle.global_position = Vector3(flat_pos.x, 0.3, flat_pos.z)
		_pulse_circle.global_rotation = Vector3.ZERO


## Анимация врага: покачивание при ходьбе, тряска при телеграфе.
func _animate(delta: float, is_moving: bool) -> void:
	if _mesh == null:
		return

	var label_bounce: float = 0.0
	var label_shake_x: float = 0.0

	if is_marked:
		# Агония — хаотичные прыжки и вращение
		_agony_timer += delta
		_agony_jump_timer += delta

		# Прыжки с случайной частотой
		var jump_height: float = absf(sin(_agony_timer * 6.0)) * 0.25
		_mesh.position.y = jump_height

		# Вращение вокруг Y — каждые ~0.4 сек новый случайный угол
		if _agony_jump_timer > 0.4:
			_agony_jump_timer = 0.0
			_agony_target_rotation = randf_range(-PI, PI)
		_mesh.rotation.y = lerpf(_mesh.rotation.y, _agony_target_rotation, delta * 8.0)

		# Покачивание
		_mesh.rotation.x = sin(_agony_timer * 10.0) * 0.2
		_mesh.rotation.z = cos(_agony_timer * 7.0) * 0.15

		label_bounce = jump_height * 0.3
	elif is_moving:
		# Покачивание при ходьбе (медленнее, мягче)
		_anim_time += delta * 6.0
		_mesh.position.y = absf(sin(_anim_time)) * 0.08
		_mesh.rotation.x = sin(_anim_time) * 0.06
		_mesh.rotation.z = sin(_anim_time * 0.6) * 0.03
		label_bounce = absf(sin(_anim_time * 0.5)) * 0.03
	elif _ai.current_state == EnemyAI.State.TELEGRAPH or _ai.current_state == EnemyAI.State.ATTACK:
		# Анимация атаки — обрабатывается подклассами через _animate_attack().
		# Возвращает дополнительный label_bounce, который сложится с базовым.
		label_bounce = _animate_attack(delta)
	else:
		# Возврат в покой
		_mesh.position.x = lerpf(_mesh.position.x, 0.0, delta * 10.0)
		_mesh.position.y = lerpf(_mesh.position.y, 0.0, delta * 10.0)
		_mesh.rotation.x = lerpf(_mesh.rotation.x, 0.0, delta * 10.0)
		_mesh.rotation.z = lerpf(_mesh.rotation.z, 0.0, delta * 10.0)
		# Возврат scale к базовому после приседа/прыжка.
		_mesh.scale = _mesh.scale.lerp(_mesh_base_scale, delta * 12.0)

	# Значок стихии — покачивается в такт
	if _element_sprite != null:
		_element_sprite.position = Vector3(label_shake_x, 1.2 + label_bounce, 0.0)


## Создаёт Area3D-зону детекции игрока.
##
## Игрок на слое 1 — луч-маски ставим тоже 1. Стены/камни тоже на слое 1,
## поэтому в хендлерах фильтруем по identity (`body == _target`).
func _setup_detection_area() -> void:
	_detection_area = Area3D.new()
	_detection_area.collision_layer = 0
	_detection_area.collision_mask = 1
	_detection_area.monitoring = true
	_detection_area.monitorable = false

	_detection_shape = SphereShape3D.new()
	_detection_shape.radius = detection_range
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = _detection_shape
	_detection_area.add_child(col)
	add_child(_detection_area)

	_detection_area.body_entered.connect(_on_detection_entered)
	_detection_area.body_exited.connect(_on_detection_exited)


func _on_detection_entered(body: Node3D) -> void:
	if body == _target:
		player_in_range = true


func _on_detection_exited(body: Node3D) -> void:
	if body == _target:
		player_in_range = false


## Создаёт ноду для отладочных линий LoS и крошек.
func _setup_debug_visual() -> void:
	_debug_imesh = ImmediateMesh.new()
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.mesh = _debug_imesh
	_debug_mesh.set_as_top_level(true)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_debug_mesh.material_override = mat
	add_child(_debug_mesh)


## Перерисовывает линию LoS и точки крошек.
func _update_debug_visual() -> void:
	if _debug_imesh == null:
		return
	_debug_imesh.clear_surfaces()
	if _debug_mesh != null:
		_debug_mesh.visible = debug_visible
	if not debug_visible or _target == null or _is_dying:
		return

	# Если рисовать нечего — не открываем surface (ImmediateMesh падает на пустом surface).
	var has_breadcrumbs: bool = _ai != null and _ai._breadcrumbs.size() > 0
	var has_search: bool = _ai != null and _ai.current_state == EnemyAI.State.SEARCH
	var is_attacking: bool = _ai != null and (_ai.current_state == EnemyAI.State.TELEGRAPH or _ai.current_state == EnemyAI.State.ATTACK)
	if not player_in_range and not has_search and not has_breadcrumbs and not is_attacking:
		return

	_debug_imesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# Линия LoS — рисуем только когда игрок реально в зоне детекции
	# (только в этот момент скрипт пускает рейкаст).
	if player_in_range:
		var eye: Vector3 = Vector3(0.0, 0.8, 0.0)
		var from: Vector3 = global_position + eye
		var to: Vector3 = _target.global_position + eye
		var has_los: bool = _ai != null and _ai._has_los
		var color_los: Color = Color(0.2, 1.0, 0.2, 0.9) if has_los else Color(1.0, 0.2, 0.2, 0.9)
		_debug_imesh.surface_set_color(color_los)
		_debug_imesh.surface_add_vertex(from)
		_debug_imesh.surface_set_color(color_los)
		_debug_imesh.surface_add_vertex(to)

	# Линия к investigation_target в SEARCH
	if _ai != null and _ai.current_state == EnemyAI.State.SEARCH:
		var search_color: Color = Color(1.0, 0.6, 0.0, 0.9)
		_debug_imesh.surface_set_color(search_color)
		_debug_imesh.surface_add_vertex(global_position + Vector3(0.0, 0.1, 0.0))
		_debug_imesh.surface_set_color(search_color)
		_debug_imesh.surface_add_vertex(investigation_target + Vector3(0.0, 0.1, 0.0))

	# Цепочка крошек жёлтыми отрезками + вертикальные «штырьки»
	if _ai != null and _ai._breadcrumbs.size() > 0:
		var crumb_color: Color = Color(1.0, 0.95, 0.2, 0.9)
		var prev: Vector3 = _ai._breadcrumbs[0] + Vector3(0.0, 0.05, 0.0)
		for i: int in range(_ai._breadcrumbs.size()):
			var p: Vector3 = _ai._breadcrumbs[i] + Vector3(0.0, 0.05, 0.0)
			# вертикальный штырёк 0.5м
			_debug_imesh.surface_set_color(crumb_color)
			_debug_imesh.surface_add_vertex(p)
			_debug_imesh.surface_set_color(crumb_color)
			_debug_imesh.surface_add_vertex(p + Vector3(0.0, 0.5, 0.0))
			# соединительная линия с предыдущей
			if i > 0:
				_debug_imesh.surface_set_color(crumb_color)
				_debug_imesh.surface_add_vertex(prev)
				_debug_imesh.surface_set_color(crumb_color)
				_debug_imesh.surface_add_vertex(p)
			prev = p

	# Класс-специфичная отрисовка (стрельба/прыжок/бомба).
	_draw_class_debug(_debug_imesh)

	_debug_imesh.surface_end()


## Настроить визуал: манекен из KayKit с цветом стихии.
func _setup_visual() -> void:
	var dummy_mesh: Mesh = load("res://assets/kaykit_prototype/Dummy_Base_Dummy_Body_Dummy_Head.obj") as Mesh
	_material = StandardMaterial3D.new()
	_material.albedo_color = ELEMENT_COLORS.get(element, Color.WHITE)

	if dummy_mesh != null:
		_mesh.mesh = dummy_mesh
		_mesh.scale = Vector3(0.8, 0.8, 0.8)
		_mesh.position.y = -0.4  # Компенсация: коллизия поднимает CharacterBody3D
		_mesh.material_override = _material
	else:
		# Фоллбек — сфера
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.4
		sphere.height = 0.8
		sphere.surface_set_material(0, _material)
		_mesh.mesh = sphere
	_mesh_base_scale = _mesh.scale

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
@export var move_speed: float = 2.33
@export var attack_range: float = 0.55
@export var attack_damage: int = 1
@export var detection_range: float = 2.0

# --- Публичные переменные ---

var hp: int = 1
var max_hp: int = 1
var is_marked: bool = false
var is_enraged: bool = false
var enemy_id: int = -1

# --- Приватные переменные ---

var _target: Node3D = null
var _material: StandardMaterial3D = null
var _anim_time: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _detection_circle: MeshInstance3D = null
var _pulse_circle: MeshInstance3D = null
var _pulse_material: ShaderMaterial = null
var _is_highlighted: bool = false
var _element_texture: Texture2D = null
var _alert_texture: Texture2D = null
var _is_chasing_icon: bool = false
var _agony_timer: float = 0.0
var _agony_target_rotation: float = 0.0
var _agony_jump_timer: float = 0.0
var _is_dying: bool = false
var _death_timer: float = 0.0
var _element_sprite: Sprite3D = null

# --- @onready переменные ---

@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _ai: EnemyAI = $EnemyAI
@onready var _mesh: MeshInstance3D = $MeshInstance3D

# --- Встроенные колбеки ---


func _ready() -> void:
	hp = max_hp
	_setup_visual()
	_setup_element_label()
	_setup_detection_circle()


func _physics_process(delta: float) -> void:
	if _is_dying:
		_process_death(delta)
		return

	var current: EnemyAI.State = _ai.current_state
	var is_moving: bool = false

	var is_aggressive: bool = current in [EnemyAI.State.CHASE, EnemyAI.State.TELEGRAPH, EnemyAI.State.RECOVER]

	if is_aggressive:
		# Преследование игрока (даже во время телеграфа и восстановления)
		if _target != null:
			var direction: Vector3 = (_target.global_position - global_position)
			direction.y = 0.0
			if direction.length() > 0.1:
				direction = direction.normalized()
				var speed: float = _get_modified_speed()
				velocity = direction * speed
				look_at(global_position + direction, Vector3.UP)
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
			velocity = Vector3.ZERO
	elif current == EnemyAI.State.ATTACK:
		# Рывок на месте во время атаки
		velocity = Vector3.ZERO

	move_and_slide()

	# Иконка: восклицательный знак при погоне, стихия при патруле
	_update_chase_icon(is_aggressive)

	# При столкновении с вертикальным препятствием — сменить направление
	if is_moving:
		for i: int in range(get_slide_collision_count()):
			var col: KinematicCollision3D = get_slide_collision(i)
			var normal: Vector3 = col.get_normal()
			# Пол имеет нормаль вверх (Y~1), стены/камни — горизонтальную
			if absf(normal.y) < 0.5:
				_ai.on_hit_obstacle()
				break

	_update_detection_circle()
	_animate(delta, is_moving)


# --- Публичные методы ---


## Установить цель для преследования.
func set_target(target: Node3D) -> void:
	_target = target


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
render_mode unshaded, cull_disabled;

uniform vec4 circle_color : source_color = vec4(1.0, 0.3, 0.3, 0.4);
uniform float ring_width = 0.015;
uniform float dash_count = 24.0;
uniform float dash_ratio = 0.5;

void fragment() {
	vec2 uv_centered = UV - vec2(0.5);
	float dist = length(uv_centered) * 2.0;
	float angle = atan(uv_centered.y, uv_centered.x);
	float normalized_angle = (angle + 3.14159) / (2.0 * 3.14159);

	float ring_mask = step(1.0 - ring_width * 2.0, dist) * step(dist, 1.0);
	float dash_mask = step(fract(normalized_angle * dash_count), dash_ratio);

	float alpha = ring_mask * dash_mask * circle_color.a;
	ALBEDO = circle_color.rgb;
	ALPHA = alpha;
}
"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	mat.set_shader_parameter("circle_color", Color(color.r, color.g, color.b, 0.4))

	_detection_circle.material_override = mat
	add_child(_detection_circle)

	# Пульсирующие концентрические круги (подсветка уязвимости)
	_setup_pulse_circle()




## Создаёт пульсирующие концентрические круги для подсветки уязвимости.
func _setup_pulse_circle() -> void:
	_pulse_circle = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var circle_size: float = detection_range * 2.0
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

	_pulse_circle.material_override = _pulse_material
	add_child(_pulse_circle)


## Обновляет позицию кругов (top-level, не вращаются с врагом).
func _update_detection_circle() -> void:
	var flat_pos: Vector3 = Vector3(global_position.x, 0.02, global_position.z)
	if _detection_circle != null:
		_detection_circle.global_position = flat_pos
		_detection_circle.global_rotation = Vector3.ZERO
	if _pulse_circle != null and _pulse_circle.visible:
		_pulse_circle.global_position = Vector3(flat_pos.x, 0.1, flat_pos.z)
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
	elif _ai.current_state == EnemyAI.State.ATTACK:
		# Рывок вперёд при атаке
		_mesh.rotation.x = -0.3
		_mesh.position.y = 0.0
	else:
		# Возврат в покой
		_mesh.position.x = lerpf(_mesh.position.x, 0.0, delta * 10.0)
		_mesh.position.y = lerpf(_mesh.position.y, 0.0, delta * 10.0)
		_mesh.rotation.x = lerpf(_mesh.rotation.x, 0.0, delta * 10.0)
		_mesh.rotation.z = lerpf(_mesh.rotation.z, 0.0, delta * 10.0)

	# Значок стихии — покачивается в такт
	if _element_sprite != null:
		_element_sprite.position = Vector3(label_shake_x, 1.2 + label_bounce, 0.0)


## Настроить визуал: манекен из KayKit с цветом стихии.
func _setup_visual() -> void:
	var dummy_mesh: Mesh = load("res://assets/kaykit_prototype/Dummy_Base_Dummy_Body_Dummy_Head.obj") as Mesh
	_material = StandardMaterial3D.new()
	_material.albedo_color = ELEMENT_COLORS.get(element, Color.WHITE)

	if dummy_mesh != null:
		_mesh.mesh = dummy_mesh
		_mesh.scale = Vector3(0.5, 0.5, 0.5)  # Масштаб: высота ~1.1
		_mesh.position.y = -0.4  # Компенсация: коллизия поднимает CharacterBody3D
		_mesh.material_override = _material
	else:
		# Фоллбек — сфера
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.4
		sphere.height = 0.8
		sphere.surface_set_material(0, _material)
		_mesh.mesh = sphere

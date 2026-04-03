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

## Значки стихий (эмодзи).
const ELEMENT_ICONS: Dictionary = {
	ElementTable.Element.FIRE: "🔥",
	ElementTable.Element.WATER: "💧",
	ElementTable.Element.TREE: "🌿",
	ElementTable.Element.EARTH: "🪨",
	ElementTable.Element.METAL: "⚙️",
}

# --- Экспортируемые переменные ---

@export var element: ElementTable.Element = ElementTable.Element.FIRE
@export var level: int = 1
@export var move_speed: float = 2.33
@export var attack_range: float = 1.0
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
var _highlight_circle: MeshInstance3D = null
var _is_highlighted: bool = false
var _element_label: Label3D = null

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
	_setup_highlight_circle()


func _physics_process(delta: float) -> void:
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


## Включает/выключает подсветку уязвимости.
func set_highlighted(enabled: bool) -> void:
	_is_highlighted = enabled
	if _highlight_circle != null:
		_highlight_circle.visible = enabled


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
	if _material != null:
		_material.emission_enabled = false


## Наложить ярость (ускорение).
func apply_rage() -> void:
	is_enraged = true


## Снять ярость.
func remove_rage() -> void:
	is_enraged = false


# --- Приватные методы ---


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
	_element_label = Label3D.new()
	_element_label.text = ELEMENT_ICONS.get(element, "?")
	_element_label.font_size = 64
	_element_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_element_label.no_depth_test = true
	_element_label.modulate = ELEMENT_COLORS.get(element, Color.WHITE)
	_element_label.position = Vector3(0.0, 1.2, 0.0)
	add_child(_element_label)


## Создаёт пунктирный круг зоны обнаружения.
func _setup_detection_circle() -> void:
	_detection_circle = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var circle_size: float = detection_range * 2.0
	plane.size = Vector2(circle_size, circle_size)
	_detection_circle.mesh = plane
	_detection_circle.set_as_top_level(true)
	_detection_circle.global_position = Vector3(global_position.x, 0.02, global_position.z)
	_detection_circle.global_rotation = Vector3.ZERO

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


## Создаёт подсветку уязвимости — заполненный полупрозрачный круг.
func _setup_highlight_circle() -> void:
	_highlight_circle = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var circle_size: float = detection_range * 2.0
	plane.size = Vector2(circle_size, circle_size)
	_highlight_circle.mesh = plane
	_highlight_circle.set_as_top_level(true)
	_highlight_circle.visible = false

	var shader := Shader.new()
	shader.code = "
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 0.3, 0.2);

void fragment() {
	vec2 uv_centered = UV - vec2(0.5);
	float dist = length(uv_centered) * 2.0;
	float mask = 1.0 - smoothstep(0.9, 1.0, dist);
	ALBEDO = fill_color.rgb;
	ALPHA = mask * fill_color.a;
}
"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	mat.set_shader_parameter("fill_color", Color(color.r, color.g, color.b, 0.25))
	_highlight_circle.material_override = mat
	add_child(_highlight_circle)


## Обновляет позицию кругов (top-level, не вращаются с врагом).
func _update_detection_circle() -> void:
	var flat_pos: Vector3 = Vector3(global_position.x, 0.02, global_position.z)
	if _detection_circle != null:
		_detection_circle.global_position = flat_pos
		_detection_circle.global_rotation = Vector3.ZERO
	if _highlight_circle != null and _highlight_circle.visible:
		_highlight_circle.global_position = Vector3(flat_pos.x, 0.03, flat_pos.z)
		_highlight_circle.global_rotation = Vector3.ZERO


## Анимация врага: покачивание при ходьбе, тряска при телеграфе.
func _animate(delta: float, is_moving: bool) -> void:
	if _mesh == null:
		return

	var label_bounce: float = 0.0
	var label_shake_x: float = 0.0

	if is_moving:
		_anim_time += delta * 12.0
		_mesh.position.y = absf(sin(_anim_time)) * 0.12
		_mesh.rotation.x = sin(_anim_time) * 0.12
		_mesh.rotation.z = sin(_anim_time * 0.6) * 0.06
		label_bounce = absf(sin(_anim_time * 0.5)) * 0.05
	elif _ai.current_state == EnemyAI.State.TELEGRAPH:
		# Тряска-предупреждение перед атакой
		_anim_time += delta * 30.0
		_mesh.position.x = sin(_anim_time) * 0.05
		_mesh.position.y = lerpf(_mesh.position.y, 0.0, delta * 8.0)
		_mesh.rotation.x = lerpf(_mesh.rotation.x, 0.0, delta * 8.0)
		label_shake_x = sin(_anim_time * 0.5) * 0.02
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
	if _element_label != null:
		_element_label.position = Vector3(label_shake_x, 1.2 + label_bounce, 0.0)


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

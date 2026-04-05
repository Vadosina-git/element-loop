class_name BookObject
extends Node3D

## Книга — источник стихии.
##
## Игрок подходит, удерживает взаимодействие 1 сек,
## получает случайную стихию для постановки зоны.
## После использования книга исчезает и респаунится через 2 сек.

# --- Сигналы ---

signal element_picked(element: ElementTable.Element)
signal book_activated(book: BookObject)

# --- Константы ---

const HOLD_DURATION: float = 1.0
const RESPAWN_DELAY: float = 2.0
const INTERACTION_RADIUS: float = 1.5
## Минимальное время жизни книги до автоисчезновения.
const AUTO_VANISH_MIN: float = 8.0
## Максимальное время жизни книги до автоисчезновения.
const AUTO_VANISH_MAX: float = 16.0
## Отступ от стен при случайном спавне.
const SPAWN_MARGIN: float = 1.5
## За сколько секунд до исчезновения начинать мигание.
const BLINK_START: float = 2.0
## Частота мигания (раз в секунду).
const BLINK_SPEED: float = 8.0

# --- Приватные переменные ---

var _is_active: bool = true
var _hold_timer: float = 0.0
var _is_holding: bool = false
var _respawn_timer: float = 0.0
var _player_in_range: bool = false
var _vanish_timer: float = 0.0
var _arena_size: Vector2 = Vector2(36.0, 24.0)
## Callable для получения доступных стихий (контры живых врагов).
var get_available_elements: Callable = Callable()

# --- @onready переменные ---

@onready var _area: Area3D = $Area3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D
var _label: Label3D = null
var _loader_mesh: MeshInstance3D = null
var _loader_material: ShaderMaterial = null


# --- Встроенные колбеки ---

func _ready() -> void:
	_setup_visual()
	_setup_collision()
	_setup_loader()
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
		_update_loader(_hold_timer / HOLD_DURATION)
		if _hold_timer >= HOLD_DURATION:
			_activate()
	else:
		_update_loader(0.0)


# --- Публичные методы ---

## Начинает удержание для активации книги.
func start_hold() -> void:
	if _is_active and _player_in_range:
		_is_holding = true
		_hold_timer = 0.0


## Прерывает удержание.
func stop_hold() -> void:
	_is_holding = false
	_hold_timer = 0.0


# --- Приватные методы ---

## Настраивает визуал книги (столик из KayKit + подпись).
func _setup_visual() -> void:
	var table_mesh: Mesh = load("res://assets/kaykit_prototype/table_medium.obj") as Mesh
	if table_mesh != null:
		_mesh.mesh = table_mesh
		_mesh.scale = Vector3(0.4, 0.4, 0.4)
		_mesh.position.y = 0.0
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.5, 0.1, 0.4)
		_mesh.mesh = box
		_mesh.position.y = 0.5

	# Градиентная заливка: фиолетово-красный
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "
shader_type spatial;

uniform vec4 color_top : source_color = vec4(0.6, 0.1, 0.7, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.8, 0.1, 0.15, 1.0);

void fragment() {
	float t = clamp(UV.y, 0.0, 1.0);
	vec3 col = mix(color_bottom.rgb, color_top.rgb, t);
	ALBEDO = col;
	METALLIC = 0.3;
	ROUGHNESS = 0.5;
}
"
	material.shader = shader
	_mesh.material_override = material

	# Подпись над книгой
	_label = Label3D.new()
	_label.text = "Книга"
	_label.font_size = 48
	_label.position.y = 1.0
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(0.9, 0.8, 0.4)
	_label.no_depth_test = true
	add_child(_label)


## Настраивает зону взаимодействия (сфера).
func _setup_collision() -> void:
	var shape := SphereShape3D.new()
	shape.radius = INTERACTION_RADIUS

	var collision := CollisionShape3D.new()
	collision.shape = shape
	_area.add_child(collision)

	# Книга только обнаруживает тела, не участвует в физике
	_area.collision_layer = 0
	_area.collision_mask = 1  # Игрок на слое 1


## Создаёт круговой лоадер на земле под книгой.
func _setup_loader() -> void:
	_loader_mesh = MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1.6, 1.6)
	_loader_mesh.mesh = mesh
	_loader_mesh.position.y = 0.02
	_loader_mesh.visible = false

	var shader := Shader.new()
	shader.code = "
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ring_color : source_color = vec4(0.9, 0.8, 0.3, 0.8);
uniform float ring_width = 0.08;
uniform float ring_radius = 0.4;

void fragment() {
	vec2 uv_centered = UV - vec2(0.5);
	float dist = length(uv_centered);
	float angle = atan(uv_centered.x, uv_centered.y);
	float normalized_angle = (angle + 3.14159) / (2.0 * 3.14159);

	float inner = ring_radius - ring_width;
	float outer = ring_radius;
	float ring_mask = step(inner, dist) * step(dist, outer);

	float progress_mask = step(normalized_angle, progress);

	float alpha = ring_mask * progress_mask * ring_color.a;
	ALBEDO = ring_color.rgb;
	ALPHA = alpha;
}
"
	_loader_material = ShaderMaterial.new()
	_loader_material.shader = shader
	_loader_material.set_shader_parameter("progress", 0.0)
	_loader_material.set_shader_parameter("ring_color", Color(0.9, 0.8, 0.3, 0.8))

	_loader_mesh.material_override = _loader_material
	add_child(_loader_mesh)


## Обновляет прогресс кругового лоадера (0.0–1.0).
func _update_loader(progress: float) -> void:
	if _loader_mesh == null:
		return
	if progress > 0.0:
		_loader_mesh.visible = true
		_loader_material.set_shader_parameter("progress", clampf(progress, 0.0, 1.0))
	else:
		_loader_mesh.visible = false


## Активирует книгу: показывает рулетку выбора стихии.
func _activate() -> void:
	_is_holding = false
	_hold_timer = 0.0
	_update_loader(0.0)
	book_activated.emit(self)


## Скрывает книгу после выбора стихии и запускает респаун.
func consume() -> void:
	_is_active = false
	_player_in_range = false
	_mesh.visible = false
	if _label != null:
		_label.visible = false
	_respawn_timer = RESPAWN_DELAY


## Отменяет активацию (игрок отказался от выбора).
func cancel_activation() -> void:
	_is_holding = false
	_hold_timer = 0.0


## Респаунит книгу в новой случайной точке.
func _respawn() -> void:
	_is_active = true
	_mesh.visible = true
	if _label != null:
		_label.visible = true
	_respawn_timer = 0.0
	_move_to_random_position()
	_reset_vanish_timer()


## Книга исчезает сама (таймер истёк) и перемещается.
func _vanish_and_relocate() -> void:
	_is_active = false
	_is_holding = false
	_hold_timer = 0.0
	_player_in_range = false
	_mesh.visible = false
	if _label != null:
		_label.visible = false
	_update_loader(0.0)
	_respawn_timer = RESPAWN_DELAY


## Перемещает книгу в случайную позицию, не пересекающуюся с камнями.
func _move_to_random_position() -> void:
	var arena: ArenaView = get_parent() as ArenaView
	if arena != null:
		position = arena.get_safe_spawn_position()
	else:
		var half_x: float = _arena_size.x / 2.0 - SPAWN_MARGIN
		var half_z: float = _arena_size.y / 2.0 - SPAWN_MARGIN
		position = Vector3(
			randf_range(-half_x, half_x),
			0.0,
			randf_range(-half_z, half_z),
		)


## Переключает видимость меша и подписи.
func _set_visual_visible(visible_flag: bool) -> void:
	_mesh.visible = visible_flag
	if _label != null:
		_label.visible = visible_flag


## Сбрасывает таймер автоисчезновения на случайное значение.
func _reset_vanish_timer() -> void:
	_vanish_timer = randf_range(AUTO_VANISH_MIN, AUTO_VANISH_MAX)


## Возвращает случайную контр-стихию для живых врагов.
func _get_random_element() -> ElementTable.Element:
	# Если есть callable — берём только контры живых врагов
	if get_available_elements.is_valid():
		var available: Array = get_available_elements.call()
		if not available.is_empty():
			return available[randi() % available.size()] as ElementTable.Element

	# Фоллбек — все стихии
	var elements: Array[ElementTable.Element] = [
		ElementTable.Element.FIRE,
		ElementTable.Element.WATER,
		ElementTable.Element.TREE,
		ElementTable.Element.EARTH,
		ElementTable.Element.METAL,
	]
	return elements[randi() % elements.size()]


# --- Колбеки сигналов ---

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerCharacter:
		_player_in_range = true
		start_hold()


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerCharacter:
		_player_in_range = false
		stop_hold()

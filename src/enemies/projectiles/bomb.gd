class_name Bomb
extends Node3D

## Бомба bomber-врага.
##
## Летит по дуге к зафиксированной точке (фаза FLY), приземляется и ждёт
## с круг-индикатором (фаза WAIT), затем взрывается (фаза EXPLODE).
## Friendly fire отключён — урон только игроку.

# --- Перечисления ---

enum Phase {
	FLY,
	WAIT,
	DONE,
}

# --- Константы ---

const FLIGHT_TIME: float = 0.8
const ARC_HEIGHT: float = 1.5
const WAIT_TIME: float = 0.7
const EXPLOSION_RADIUS: float = 1.2
const DAMAGE: int = 1

# --- Публичные переменные ---

var element_color: Color = Color.WHITE

# --- Приватные переменные ---

var _start_pos: Vector3 = Vector3.ZERO
var _target_pos: Vector3 = Vector3.ZERO
var _player_ref: Node = null
var _phase: int = Phase.FLY
var _phase_timer: float = 0.0
var _bomb_mesh: MeshInstance3D = null
var _bomb_material: StandardMaterial3D = null
var _indicator: MeshInstance3D = null
var _indicator_material: ShaderMaterial = null

# --- Встроенные колбеки ---


func _ready() -> void:
	_setup_visual()


func _physics_process(delta: float) -> void:
	_phase_timer += delta
	match _phase:
		Phase.FLY:
			_process_fly()
		Phase.WAIT:
			_process_wait()
		Phase.DONE:
			pass


# --- Публичные методы ---


func arm(start: Vector3, target: Vector3, player: Node) -> void:
	_start_pos = start
	_target_pos = target
	_player_ref = player
	global_position = start


# --- Приватные методы ---


func _process_fly() -> void:
	var t: float = clampf(_phase_timer / FLIGHT_TIME, 0.0, 1.0)
	var flat: Vector3 = _start_pos.lerp(_target_pos, t)
	var height: float = sin(t * PI) * ARC_HEIGHT
	global_position = Vector3(flat.x, _target_pos.y + height, flat.z)
	# Кручение для эффекта.
	if _bomb_mesh != null:
		_bomb_mesh.rotation.x += 0.2
		_bomb_mesh.rotation.z += 0.15
	if t >= 1.0:
		_phase = Phase.WAIT
		_phase_timer = 0.0
		global_position = _target_pos
		_show_indicator()


func _process_wait() -> void:
	# Пульсация бомбы перед взрывом.
	if _bomb_material != null:
		var pulse: float = absf(sin(_phase_timer * 12.0))
		_bomb_material.emission_energy_multiplier = 0.4 + pulse * 1.5
	if _phase_timer >= WAIT_TIME:
		_explode()


func _explode() -> void:
	_phase = Phase.DONE
	# Урон только игроку, в радиусе.
	if _player_ref != null and is_instance_valid(_player_ref):
		var to_player: Vector3 = (_player_ref as Node3D).global_position - global_position
		to_player.y = 0.0
		if to_player.length() <= EXPLOSION_RADIUS and (_player_ref as Node3D).has_method("take_damage"):
			(_player_ref as Node3D).take_damage(DAMAGE)
	queue_free()


func _setup_visual() -> void:
	_bomb_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	_bomb_mesh.mesh = sphere
	_bomb_material = StandardMaterial3D.new()
	_bomb_material.albedo_color = Color(0.15, 0.15, 0.15)
	_bomb_material.emission_enabled = true
	_bomb_material.emission = element_color
	_bomb_material.emission_energy_multiplier = 0.4
	_bomb_mesh.material_override = _bomb_material
	add_child(_bomb_mesh)


## Создаёт круг-индикатор будущего взрыва на земле.
func _show_indicator() -> void:
	_indicator = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	var sz: float = EXPLOSION_RADIUS * 2.0
	plane.size = Vector2(sz, sz)
	_indicator.mesh = plane

	var shader: Shader = Shader.new()
	shader.code = "
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform vec4 ind_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform float pulse_speed = 4.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 2.0;
	float ring = (1.0 - smoothstep(0.0, 0.04, abs(dist - 0.95))) * 0.9;
	float fill = (1.0 - smoothstep(0.6, 1.0, dist)) * 0.25;
	float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5) * 0.4;
	float alpha = (ring + fill * (0.5 + pulse)) * step(dist, 1.0);
	ALBEDO = ind_color.rgb;
	ALPHA = alpha;
}
"
	_indicator_material = ShaderMaterial.new()
	_indicator_material.shader = shader
	_indicator_material.set_shader_parameter("ind_color", element_color)
	_indicator.material_override = _indicator_material
	add_child(_indicator)
	# Top-level + позицию выставляем ТОЛЬКО после добавления в дерево.
	_indicator.set_as_top_level(true)
	_indicator.global_position = Vector3(_target_pos.x, 0.26, _target_pos.z)

class_name Arrow
extends Area3D

## Стрела ranged-врага.
##
## Летит прямолинейно. Урон только игроку (friendly fire отключён).
## При столкновении со стеной — самоуничтожение.

# --- Константы ---

const SPEED: float = 12.0
const LIFETIME: float = 3.0
const DAMAGE: int = 1

# --- Публичные переменные ---

var velocity: Vector3 = Vector3.ZERO
var element_color: Color = Color.WHITE

# --- Приватные переменные ---

var _player_ref: Node = null
var _life_timer: float = 0.0
var _consumed: bool = false

# --- Встроенные колбеки ---


func _ready() -> void:
	collision_layer = 0
	# Слой 1 — игрок и стены/камни.
	collision_mask = 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	_setup_visual()


func _physics_process(delta: float) -> void:
	if _consumed:
		return
	_life_timer += delta
	if _life_timer >= LIFETIME:
		queue_free()
		return
	global_position += velocity * delta


# --- Публичные методы ---


## Запуск стрелы. Вызывается сразу после instantiate + add_child.
func launch(start: Vector3, dir: Vector3, player: Node) -> void:
	global_position = start
	velocity = dir.normalized() * SPEED
	_player_ref = player
	if dir.length() > 0.01:
		look_at(global_position + dir.normalized(), Vector3.UP)


# --- Приватные методы ---


func _on_body_entered(body: Node3D) -> void:
	if _consumed:
		return
	if body == _player_ref:
		_consumed = true
		if body.has_method("take_damage"):
			body.take_damage(DAMAGE)
		queue_free()
	else:
		# Стена / другой объект на слое 1, не игрок — стрела ломается.
		_consumed = true
		queue_free()


## Создаёт визуальное тело стрелы — узкая капсула с эмиссией.
func _setup_visual() -> void:
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.06
	capsule.height = 0.5
	col_shape.shape = capsule
	col_shape.rotation.x = PI / 2.0
	add_child(col_shape)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var capsule_mesh: CapsuleMesh = CapsuleMesh.new()
	capsule_mesh.radius = 0.06
	capsule_mesh.height = 0.5
	mesh_inst.mesh = capsule_mesh
	mesh_inst.rotation.x = PI / 2.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = element_color
	mat.emission_enabled = true
	mat.emission = element_color
	mat.emission_energy_multiplier = 0.6
	mesh_inst.material_override = mat
	add_child(mesh_inst)

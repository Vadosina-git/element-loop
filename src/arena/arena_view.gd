class_name ArenaView
extends Node3D

## Арена боя: пол, стены, навигация, освещение и окружение.
##
## Программно создаёт геометрию арены, навигационную сетку,
## освещение и камеру. Размер арены задаётся константой ARENA_SIZE.

# --- Сигналы ---
signal room_completed
signal player_died

# --- Константы ---
const ARENA_SIZE: Vector2 = Vector2(12.0, 18.0)
const WALL_HEIGHT: float = 2.0
const WALL_THICKNESS: float = 0.5

const FLOOR_COLOR: Color = Color(0.15, 0.12, 0.1)
const WALL_COLOR: Color = Color(0.2, 0.18, 0.15)
const BG_COLOR: Color = Color(0.08, 0.06, 0.05)
const AMBIENT_COLOR: Color = Color(0.3, 0.25, 0.2)
const AMBIENT_ENERGY: float = 0.4
const LIGHT_ENERGY: float = 0.8

# --- @onready переменные ---
@onready var _floor: MeshInstance3D = $Floor
@onready var _walls: Node3D = $Walls
@onready var _camera: ArenaCamera = $ArenaCamera


# --- Встроенные колбеки ---
func _ready() -> void:
	_setup_floor()
	_setup_walls()
	_setup_navigation()
	_setup_lighting()
	_setup_environment()
	_camera.update_for_arena(ARENA_SIZE)


# --- Приватные методы ---

## Создаёт пол арены: меш + коллизия.
func _setup_floor() -> void:
	# Меш пола
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = ARENA_SIZE
	_floor.mesh = plane_mesh

	# Материал пола
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = FLOOR_COLOR
	_floor.material_override = floor_material

	# Коллизия пола
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(ARENA_SIZE.x, 0.1, ARENA_SIZE.y)
	floor_shape.shape = box_shape
	floor_shape.position = Vector3(0.0, -0.05, 0.0)
	floor_body.add_child(floor_shape)
	_floor.add_child(floor_body)


## Создаёт 4 стены арены.
func _setup_walls() -> void:
	var half_x: float = ARENA_SIZE.x / 2.0
	var half_z: float = ARENA_SIZE.y / 2.0
	var half_height: float = WALL_HEIGHT / 2.0
	var half_thick: float = WALL_THICKNESS / 2.0

	# Стена: [позиция, размер_меша]
	var wall_data: Array[Dictionary] = [
		# Северная стена (−Z)
		{
			"pos": Vector3(0.0, half_height, -(half_z + half_thick)),
			"size": Vector3(ARENA_SIZE.x + WALL_THICKNESS * 2.0, WALL_HEIGHT, WALL_THICKNESS),
		},
		# Южная стена (+Z)
		{
			"pos": Vector3(0.0, half_height, half_z + half_thick),
			"size": Vector3(ARENA_SIZE.x + WALL_THICKNESS * 2.0, WALL_HEIGHT, WALL_THICKNESS),
		},
		# Западная стена (−X)
		{
			"pos": Vector3(-(half_x + half_thick), half_height, 0.0),
			"size": Vector3(WALL_THICKNESS, WALL_HEIGHT, ARENA_SIZE.y),
		},
		# Восточная стена (+X)
		{
			"pos": Vector3(half_x + half_thick, half_height, 0.0),
			"size": Vector3(WALL_THICKNESS, WALL_HEIGHT, ARENA_SIZE.y),
		},
	]

	var wall_material: StandardMaterial3D = StandardMaterial3D.new()
	wall_material.albedo_color = WALL_COLOR

	for i: int in wall_data.size():
		var data: Dictionary = wall_data[i]
		var wall_pos: Vector3 = data["pos"]
		var wall_size: Vector3 = data["size"]

		# Визуал стены
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		var box_mesh: BoxMesh = BoxMesh.new()
		box_mesh.size = wall_size
		mesh_instance.mesh = box_mesh
		mesh_instance.material_override = wall_material
		mesh_instance.position = wall_pos

		# Коллизия стены
		var wall_body: StaticBody3D = StaticBody3D.new()
		var wall_shape: CollisionShape3D = CollisionShape3D.new()
		var col_shape: BoxShape3D = BoxShape3D.new()
		col_shape.size = wall_size
		wall_shape.shape = col_shape
		wall_body.position = wall_pos
		wall_body.add_child(wall_shape)

		_walls.add_child(mesh_instance)
		_walls.add_child(wall_body)


## Создаёт NavigationRegion3D с NavigationMesh для AI-навигации.
func _setup_navigation() -> void:
	var nav_region: NavigationRegion3D = NavigationRegion3D.new()
	var nav_mesh: NavigationMesh = NavigationMesh.new()

	nav_mesh.agent_radius = 0.4
	nav_mesh.parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS

	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)

	# Отложенный bake, чтобы все коллайдеры были готовы
	nav_region.bake_navigation_mesh.call_deferred()


## Создаёт DirectionalLight3D для освещения арены.
func _setup_lighting() -> void:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	light.light_energy = LIGHT_ENERGY
	light.shadow_enabled = true
	add_child(light)


## Создаёт WorldEnvironment с тёмным фоном и мягким ambient-светом.
func _setup_environment() -> void:
	var world_env: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()

	env.background_mode = Environment.BG_COLOR
	env.background_color = BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = AMBIENT_ENERGY

	world_env.environment = env
	add_child(world_env)

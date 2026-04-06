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
const ARENA_SIZE: Vector2 = Vector2(36.0, 24.0)
const WALL_HEIGHT: float = 2.0
const WALL_THICKNESS: float = 0.5

const FLOOR_COLOR: Color = Color(0.15, 0.12, 0.1)
const WALL_COLOR: Color = Color(0.2, 0.18, 0.15)

## Количество каменных гряд на арене.
const RIDGE_COUNT: int = 1080

# --- @onready переменные ---
## Занятые ячейки сетки после генерации камней.
var _occupied_cells: Dictionary = {}

@onready var _floor: MeshInstance3D = $Floor
@onready var _walls: Node3D = $Walls
@onready var _rocks: Node3D = $Rocks
@onready var _camera: ArenaCamera = $ArenaCamera

var main_light: DirectionalLight3D = null
var fill_light: DirectionalLight3D = null
var world_environment: Environment = null


# --- Встроенные колбеки ---
func _ready() -> void:
	_setup_floor()
	_setup_walls()
	_setup_rocks()
	_setup_navigation()
	_setup_lighting()
	_setup_environment()
	_camera.update_for_arena(ARENA_SIZE)


# --- Приватные методы ---

## Создаёт пол арены из KayKit Floor-тайлов + коллизия.
func _setup_floor() -> void:
	var floor_mesh: Mesh = load("res://assets/kaykit_prototype/Floor.obj") as Mesh
	var tile_scale: float = 0.25  # Уменьшаем тайлы: 4 * 0.25 = 1 юнит
	var tile_size: float = 4.0 * tile_scale
	var tiles_x: int = ceili(ARENA_SIZE.x / tile_size)
	var tiles_z: int = ceili(ARENA_SIZE.y / tile_size)
	var offset_x: float = -(tiles_x * tile_size) / 2.0 + tile_size / 2.0
	var offset_z: float = -(tiles_z * tile_size) / 2.0 + tile_size / 2.0

	# Тёплый материал пола (Cozy Grove style)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color.html("#3D2E1F")
	floor_material.roughness = 0.9
	floor_material.metallic = 0.0

	for ix: int in range(tiles_x):
		for iz: int in range(tiles_z):
			var tile: MeshInstance3D = MeshInstance3D.new()
			tile.mesh = floor_mesh
			tile.material_override = floor_material
			tile.scale = Vector3(tile_scale, tile_scale, tile_scale)
			tile.position = Vector3(
				offset_x + ix * tile_size,
				-0.5 * tile_scale,
				offset_z + iz * tile_size
			)
			_floor.add_child(tile)

	# Единая коллизия пола
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(tiles_x * tile_size, 0.1, tiles_z * tile_size)
	floor_shape.shape = box_shape
	floor_shape.position = Vector3(0.0, -0.05, 0.0)
	floor_body.add_child(floor_shape)
	_floor.add_child(floor_body)


## Создаёт 4 стены арены из KayKit Primitive_Wall + коллизия.
func _setup_walls() -> void:
	var wall_mesh: Mesh = load("res://assets/kaykit_prototype/Primitive_Wall.obj") as Mesh
	var wall_half_mesh: Mesh = load("res://assets/kaykit_prototype/Primitive_Wall_Half.obj") as Mesh
	var wall_scale: float = 0.25
	var segment_size: float = 4.0 * wall_scale
	var half_x: float = ARENA_SIZE.x / 2.0
	var half_z: float = ARENA_SIZE.y / 2.0

	# Северная стена (−Z)
	_place_wall_row(wall_mesh, wall_half_mesh, segment_size,
		Vector3(-half_x, 0.0, -half_z), Vector3.RIGHT, ARENA_SIZE.x, 0.0)
	# Южная стена (+Z)
	_place_wall_row(wall_mesh, wall_half_mesh, segment_size,
		Vector3(-half_x, 0.0, half_z), Vector3.RIGHT, ARENA_SIZE.x, 180.0)
	# Западная стена (−X)
	_place_wall_row(wall_mesh, wall_half_mesh, segment_size,
		Vector3(-half_x, 0.0, -half_z), Vector3.BACK, ARENA_SIZE.y, 90.0)
	# Восточная стена (+X)
	_place_wall_row(wall_mesh, wall_half_mesh, segment_size,
		Vector3(half_x, 0.0, -half_z), Vector3.BACK, ARENA_SIZE.y, -90.0)

	# Коллизии стен
	var half_thick: float = WALL_THICKNESS / 2.0
	var wall_collisions: Array[Dictionary] = [
		{"pos": Vector3(0.0, WALL_HEIGHT / 2.0, -half_z - half_thick),
		 "size": Vector3(ARENA_SIZE.x + WALL_THICKNESS * 2.0, WALL_HEIGHT, WALL_THICKNESS)},
		{"pos": Vector3(0.0, WALL_HEIGHT / 2.0, half_z + half_thick),
		 "size": Vector3(ARENA_SIZE.x + WALL_THICKNESS * 2.0, WALL_HEIGHT, WALL_THICKNESS)},
		{"pos": Vector3(-half_x - half_thick, WALL_HEIGHT / 2.0, 0.0),
		 "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, ARENA_SIZE.y)},
		{"pos": Vector3(half_x + half_thick, WALL_HEIGHT / 2.0, 0.0),
		 "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, ARENA_SIZE.y)},
	]
	for data: Dictionary in wall_collisions:
		var wall_body: StaticBody3D = StaticBody3D.new()
		var wall_shape: CollisionShape3D = CollisionShape3D.new()
		var col_shape: BoxShape3D = BoxShape3D.new()
		col_shape.size = data["size"] as Vector3
		wall_shape.shape = col_shape
		wall_body.position = data["pos"] as Vector3
		wall_body.add_child(wall_shape)
		_walls.add_child(wall_body)


## Расставляет сегменты стены вдоль линии.
func _place_wall_row(
	wall_mesh: Mesh, wall_half_mesh: Mesh, segment_size: float,
	start: Vector3, direction: Vector3, length: float, rotation_y: float
) -> void:
	var count: int = floori(length / segment_size)
	var remainder: float = length - count * segment_size

	var s: float = 0.25
	for i: int in range(count):
		var tile: MeshInstance3D = MeshInstance3D.new()
		tile.mesh = wall_mesh
		tile.scale = Vector3(s, s, s)
		tile.position = start + direction * (i * segment_size + segment_size / 2.0)
		tile.rotation_degrees.y = rotation_y
		_walls.add_child(tile)

	if remainder > segment_size * 0.25:
		var tile: MeshInstance3D = MeshInstance3D.new()
		tile.mesh = wall_half_mesh
		tile.scale = Vector3(s, s, s)
		tile.position = start + direction * (count * segment_size + remainder / 2.0)
		tile.rotation_degrees.y = rotation_y
		_walls.add_child(tile)


## Возвращает массив равномерно распределённых безопасных позиций.
## min_dist_from — минимальная дистанция от точки (например, от игрока).
func get_distributed_spawn_positions(count: int, avoid_pos: Vector3 = Vector3.ZERO, min_dist: float = 0.0) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	# Разбиваем арену на сетку секторов
	var cols: int = ceili(sqrt(count * ARENA_SIZE.x / ARENA_SIZE.y))
	var rows: int = ceili(float(count) / cols)
	var sector_w: float = (ARENA_SIZE.x - 4.0) / cols
	var sector_h: float = (ARENA_SIZE.y - 4.0) / rows
	var half_x: float = ARENA_SIZE.x / 2.0 - 2.0
	var half_z: float = ARENA_SIZE.y / 2.0 - 2.0

	var idx: int = 0
	for row: int in range(rows):
		for col: int in range(cols):
			if idx >= count:
				break
			# Случайная точка внутри сектора
			var base_x: float = -half_x + col * sector_w
			var base_z: float = -half_z + row * sector_h
			var pos: Vector3 = Vector3.ZERO
			var found: bool = false
			for _attempt: int in range(20):
				var try_pos := Vector3(
					randf_range(base_x, base_x + sector_w),
					0.0,
					randf_range(base_z, base_z + sector_h),
				)
				if _is_position_safe(try_pos):
					if min_dist > 0.0:
						var diff: Vector3 = try_pos - avoid_pos
						diff.y = 0.0
						if diff.length() < min_dist:
							continue
					pos = try_pos
					found = true
					break
			if not found:
				pos = get_safe_spawn_position()
			positions.append(pos)
			idx += 1

	# Перемешиваем чтобы стихии не шли рядами
	positions.shuffle()
	return positions


## Возвращает случайную позицию на навмеше (гарантированно проходимую).
func get_safe_spawn_position() -> Vector3:
	# Пробуем через NavigationServer
	var map_rid: RID = NavigationServer3D.get_maps()[0] if NavigationServer3D.get_maps().size() > 0 else RID()
	if map_rid.is_valid():
		for _attempt: int in range(20):
			var nav_pos: Vector3 = NavigationServer3D.map_get_random_point(map_rid, 1, false)
			if nav_pos != Vector3.ZERO:
				nav_pos.y = 0.0
				return nav_pos

	# Fallback — старый метод
	var half_x: float = ARENA_SIZE.x / 2.0 - 2.0
	var half_z: float = ARENA_SIZE.y / 2.0 - 2.0
	for _attempt: int in range(50):
		var pos := Vector3(randf_range(-half_x, half_x), 0.0, randf_range(-half_z, half_z))
		if _is_position_safe(pos):
			return pos
	return Vector3.ZERO


## Проверяет, свободна ли позиция от камней.
func _is_position_safe(pos: Vector3) -> bool:
	var grid_w: int = floori(ARENA_SIZE.x / MazeGenerator.CELL_SIZE)
	var grid_h: int = floori(ARENA_SIZE.y / MazeGenerator.CELL_SIZE)
	var gx: int = floori(pos.x / MazeGenerator.CELL_SIZE + grid_w / 2.0)
	var gz: int = floori(pos.z / MazeGenerator.CELL_SIZE + grid_h / 2.0)
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			if _occupied_cells.has(Vector2i(gx + dx, gz + dz)):
				return false
	return true


## Генерирует каменный лабиринт из случайных гряд.
func _setup_rocks() -> void:
	var cube_mesh: Mesh = load("res://assets/kaykit_prototype/Cube_Prototype_Large_A.obj") as Mesh
	var cube_mesh_b: Mesh = load("res://assets/kaykit_prototype/Cube_Prototype_Large_B.obj") as Mesh
	# Тёплый материал камней (Cozy Grove style)
	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = Color.html("#5A4A3A")
	rock_material.roughness = 0.85
	rock_material.metallic = 0.0

	var ridges: Array[MazeGenerator.Ridge] = MazeGenerator.generate(ARENA_SIZE, RIDGE_COUNT)

	# Сохраняем занятые ячейки для спавна
	for ridge: MazeGenerator.Ridge in ridges:
		for i: int in range(ridge.length):
			var cx: int = ridge.grid_x + (i if ridge.horizontal else 0)
			var cz: int = ridge.grid_z + (i if not ridge.horizontal else 0)
			_occupied_cells[Vector2i(cx, cz)] = true

	for ridge: MazeGenerator.Ridge in ridges:
		for i: int in range(ridge.length):
			var gx: int = ridge.grid_x + (i if ridge.horizontal else 0)
			var gz: int = ridge.grid_z + (i if not ridge.horizontal else 0)
			var world_pos: Vector3 = MazeGenerator.grid_to_world(gx, gz, ARENA_SIZE)

			var cs: float = MazeGenerator.CELL_SIZE
			var rock_scale: float = 0.25

			var mesh_inst := MeshInstance3D.new()
			mesh_inst.mesh = cube_mesh if (gx + gz) % 2 == 0 else cube_mesh_b
			mesh_inst.material_override = rock_material
			mesh_inst.position = world_pos
			mesh_inst.scale = Vector3(rock_scale, rock_scale, rock_scale)
			_rocks.add_child(mesh_inst)

			# Коллизия — высокий бокс, чтобы персонаж не мог пройти
			var body := StaticBody3D.new()
			body.position = world_pos
			body.collision_layer = 1
			body.collision_mask = 0
			var col_shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(cs, 2.0, cs)
			col_shape.shape = box
			col_shape.position = Vector3(0.0, 1.0, 0.0)
			body.add_child(col_shape)
			_rocks.add_child(body)


## Создаёт NavigationRegion3D с NavigationMesh для AI-навигации.
func _setup_navigation() -> void:
	# Большой невидимый пол для бейка навмеша
	var nav_floor := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(ARENA_SIZE.x, 0.1, ARENA_SIZE.y)
	nav_floor.mesh = plane
	var nav_region: NavigationRegion3D = NavigationRegion3D.new()
	add_child(nav_region)

	# Пол внутри nav_region для бейка
	nav_floor.position = Vector3(0.0, -0.05, 0.0)
	nav_region.add_child(nav_floor)

	# Копируем камни внутрь nav_region для вырезов
	for child: Node in _rocks.get_children():
		if child is StaticBody3D:
			var obstacle := MeshInstance3D.new()
			var box_mesh := BoxMesh.new()
			var col: CollisionShape3D = child.get_child(0) as CollisionShape3D
			if col != null and col.shape is BoxShape3D:
				box_mesh.size = (col.shape as BoxShape3D).size
			obstacle.mesh = box_mesh
			obstacle.position = child.position + col.position if col != null else child.position
			nav_region.add_child(obstacle)
	var nav_mesh: NavigationMesh = NavigationMesh.new()

	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_height = 1.0
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.cell_size = 0.5
	nav_mesh.cell_height = 0.5
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH

	nav_region.navigation_mesh = nav_mesh

	nav_region.bake_navigation_mesh.call_deferred()
	nav_region.bake_finished.connect(func() -> void:
		print("NavMesh baked: %d polygons, %d vertices" % [nav_mesh.get_polygon_count(), nav_mesh.get_vertices().size()])
		# Скрываем вспомогательные мешки после бейка
		for child: Node in nav_region.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).visible = false
	)


## Создаёт освещение арены: тёплый main + холодный fill (Cozy Grove style).
func _setup_lighting() -> void:
	# Основной свет — тёплый, мягкие акварельные тени
	main_light = DirectionalLight3D.new()
	main_light.rotation_degrees = Vector3(-65.0, 130.0, 0.0)
	main_light.light_energy = 1.3
	main_light.light_color = Color.html("#FFE8C8")  # Тёплый кремовый
	main_light.shadow_enabled = true
	main_light.shadow_blur = 2.0
	main_light.shadow_bias = 0.05
	main_light.directional_shadow_max_distance = 60.0
	add_child(main_light)

	# Заполняющий свет — холодный голубой, мягкий
	fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-35.0, 310.0, 0.0)
	fill_light.light_energy = 0.25
	fill_light.light_color = Color.html("#B0C0E0")  # Холодный голубой
	fill_light.shadow_enabled = false
	add_child(fill_light)


## Создаёт WorldEnvironment — Cozy Grove атмосфера.
func _setup_environment() -> void:
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_environment = Environment.new()
	var env: Environment = world_environment

	# Тёмный тёплый фон
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.html("#0A0806")

	# Тёплый кремовый ambient
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.html("#D4C8B0")
	env.ambient_light_energy = 0.6

	# SSAO — мягкие тени у основания (не агрессивные)
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.5
	env.ssao_power = 1.2
	env.ssao_detail = 0.5

	# Glow — лёгкий bloom на тёплых цветах
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.9

	# Filmic tone mapping
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.0

	# Лёгкий тёплый туман
	env.fog_enabled = true
	env.fog_light_color = Color.html("#1A140E")
	env.fog_density = 0.001
	env.fog_aerial_perspective = 0.05

	world_env.environment = env
	add_child(world_env)


## Создаёт outline + posterization пост-эффект на камере.

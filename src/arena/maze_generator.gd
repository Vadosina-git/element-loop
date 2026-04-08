class_name MazeGenerator
extends RefCounted

## Генератор каменного лабиринта на арене.
##
## Размещает случайные гряды камней (1x1 до 1x10) на сетке.
## Гарантирует минимальный зазор между скоплениями для прохода.
## Работает на 2D-сетке, результат — массив позиций занятых ячеек.

# --- Константы ---

## Размер одной ячейки сетки (совпадает с тайлом пола: 4.0 * 0.25 = 1.0).
const CELL_SIZE: float = 1.0

## Минимальный зазор между скоплениями (в ячейках).
const MIN_GAP: int = 2

## Свободная зона вокруг центра арены (в ячейках) — спавн игрока.
const SAFE_ZONE_RADIUS: int = 1

## Минимальная длина гряды камней.
const MIN_RIDGE_LENGTH: int = 1

## Максимальная длина гряды камней.
const MAX_RIDGE_LENGTH: int = 12

## Максимальная доля коротких гряд (длина 1–2) от общего числа.
const SHORT_RIDGE_MAX_RATIO: float = 0.15

## Количество попыток размещения одной гряды.
const MAX_PLACEMENT_ATTEMPTS: int = 30


## Результат генерации: позиция и длина гряды.
class Ridge:
	var grid_x: int = 0
	var grid_z: int = 0
	var length: int = 1
	var horizontal: bool = true  # true = вдоль X, false = вдоль Z


# --- Публичные методы ---

## Генерирует лабиринт. Возвращает массив Ridge.
static func generate(arena_size: Vector2, ridge_count: int) -> Array[Ridge]:
	var grid_w: int = floori(arena_size.x / CELL_SIZE)
	var grid_h: int = floori(arena_size.y / CELL_SIZE)

	# Сетка занятости: true = занято или буферная зона
	var occupied: Dictionary = {}  # {Vector2i: bool}

	# Помечаем безопасную зону в центре
	var center_x: int = grid_w / 2
	var center_z: int = grid_h / 2
	for dx: int in range(-SAFE_ZONE_RADIUS, SAFE_ZONE_RADIUS + 1):
		for dz: int in range(-SAFE_ZONE_RADIUS, SAFE_ZONE_RADIUS + 1):
			occupied[Vector2i(center_x + dx, center_z + dz)] = true

	# Помечаем границы как буфер (1 ячейка от края)
	for x: int in range(grid_w):
		occupied[Vector2i(x, 0)] = true
		occupied[Vector2i(x, 1)] = true
		occupied[Vector2i(x, grid_h - 1)] = true
		occupied[Vector2i(x, grid_h - 2)] = true
	for z: int in range(grid_h):
		occupied[Vector2i(0, z)] = true
		occupied[Vector2i(1, z)] = true
		occupied[Vector2i(grid_w - 1, z)] = true
		occupied[Vector2i(grid_w - 2, z)] = true

	var ridges: Array[Ridge] = []
	var short_count: int = 0
	var short_limit: int = floori(ridge_count * SHORT_RIDGE_MAX_RATIO)

	for _i: int in range(ridge_count):
		var ridge: Ridge = _try_place_ridge(grid_w, grid_h, occupied, short_count >= short_limit)
		if ridge != null:
			ridges.append(ridge)
			if ridge.length <= 2:
				short_count += 1
			# Помечаем ячейки гряды + буферную зону
			_mark_occupied(ridge, occupied)

	return ridges


## Конвертирует позицию на сетке в мировые координаты.
static func grid_to_world(grid_x: int, grid_z: int, arena_size: Vector2) -> Vector3:
	var grid_w: int = floori(arena_size.x / CELL_SIZE)
	var grid_h: int = floori(arena_size.y / CELL_SIZE)
	var world_x: float = (grid_x - grid_w / 2.0 + 0.5) * CELL_SIZE
	var world_z: float = (grid_z - grid_h / 2.0 + 0.5) * CELL_SIZE
	return Vector3(world_x, 0.0, world_z)


# --- Приватные методы ---

## Пробует разместить одну гряду. Возвращает Ridge или null.
## no_short — если true, длина минимум 3 (лимит коротких исчерпан).
static func _try_place_ridge(grid_w: int, grid_h: int, occupied: Dictionary, no_short: bool = false) -> Ridge:
	var min_len: int = 3 if no_short else MIN_RIDGE_LENGTH
	for _attempt: int in range(MAX_PLACEMENT_ATTEMPTS):
		var ridge := Ridge.new()
		ridge.length = randi_range(min_len, MAX_RIDGE_LENGTH)
		ridge.horizontal = randf() > 0.5

		if ridge.horizontal:
			ridge.grid_x = randi_range(2, grid_w - ridge.length - 2)
			ridge.grid_z = randi_range(2, grid_h - 3)
		else:
			ridge.grid_x = randi_range(2, grid_w - 3)
			ridge.grid_z = randi_range(2, grid_h - ridge.length - 2)

		if _can_place(ridge, occupied, grid_w, grid_h):
			return ridge

	return null


## Проверяет, можно ли разместить гряду без пересечения с буферами.
static func _can_place(ridge: Ridge, occupied: Dictionary, grid_w: int, grid_h: int) -> bool:
	for i: int in range(ridge.length):
		var cx: int = ridge.grid_x + (i if ridge.horizontal else 0)
		var cz: int = ridge.grid_z + (i if not ridge.horizontal else 0)

		if cx < 0 or cx >= grid_w or cz < 0 or cz >= grid_h:
			return false

		# Проверяем ячейку и буфер вокруг неё
		for dx: int in range(-MIN_GAP, MIN_GAP + 1):
			for dz: int in range(-MIN_GAP, MIN_GAP + 1):
				var check: Vector2i = Vector2i(cx + dx, cz + dz)
				if occupied.has(check):
					return false

	return true


## Помечает ячейки гряды как занятые.
static func _mark_occupied(ridge: Ridge, occupied: Dictionary) -> void:
	for i: int in range(ridge.length):
		var cx: int = ridge.grid_x + (i if ridge.horizontal else 0)
		var cz: int = ridge.grid_z + (i if not ridge.horizontal else 0)
		occupied[Vector2i(cx, cz)] = true

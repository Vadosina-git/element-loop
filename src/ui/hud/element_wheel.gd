class_name ElementWheel
extends Control

## Круговая схема стихий со стрелками контров.
##
## Рисует 5 стихий по кругу и стрелки «побеждает» между ними.

# --- Константы ---

const ELEMENTS: Array[String] = ["💧", "🔥", "🌿", "🪨", "⚙️"]
const COLORS: Array[Color] = [
	Color(0.1, 0.4, 0.9),   # Water
	Color(0.9, 0.2, 0.1),   # Fire
	Color(0.2, 0.7, 0.2),   # Tree
	Color(0.6, 0.4, 0.2),   # Earth
	Color(0.7, 0.7, 0.7),   # Metal
]

const ICON_SIZE: float = 56.0
const ARROW_COLOR: Color = Color(0.8, 0.8, 0.8, 0.5)
const ARROW_WIDTH: float = 3.0


# --- Встроенные колбеки ---

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - ICON_SIZE - 4.0

	# Позиции 5 стихий по кругу (начинаем сверху, по часовой)
	var positions: Array[Vector2] = []
	for i: int in range(5):
		var angle: float = -PI / 2.0 + i * TAU / 5.0
		positions.append(center + Vector2(cos(angle), sin(angle)) * radius)

	# Стрелки: каждая стихия побеждает следующую по кругу
	for i: int in range(5):
		var from: Vector2 = positions[i]
		var to: Vector2 = positions[(i + 1) % 5]
		_draw_arrow(from, to)

	# Иконки стихий
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 38
	var ascent: float = font.get_ascent(font_size)
	var descent: float = font.get_descent(font_size)
	var text_height: float = ascent + descent
	for i: int in range(5):
		var pos: Vector2 = positions[i]
		# Фон-кружок
		draw_circle(pos, ICON_SIZE, Color(0.1, 0.1, 0.1, 0.7))
		draw_arc(pos, ICON_SIZE, 0.0, TAU, 32, COLORS[i], 3.0)
		# Эмодзи — центрируем по ширине через width, по высоте через ascent
		var draw_width: float = ICON_SIZE * 2.0
		var draw_pos: Vector2 = Vector2(pos.x - draw_width / 2.0, pos.y + text_height / 2.0 - descent)
		draw_string(font, draw_pos, ELEMENTS[i], HORIZONTAL_ALIGNMENT_CENTER, draw_width, font_size)


# --- Приватные методы ---

## Рисует стрелку между двумя точками (укороченную, чтобы не залезать на иконки).
func _draw_arrow(from: Vector2, to: Vector2) -> void:
	var dir: Vector2 = (to - from).normalized()
	var start: Vector2 = from + dir * (ICON_SIZE + 4.0)
	var end: Vector2 = to - dir * (ICON_SIZE + 4.0)

	draw_line(start, end, ARROW_COLOR, ARROW_WIDTH)

	# Наконечник стрелки
	var arrow_size: float = 14.0
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tip1: Vector2 = end - dir * arrow_size + perp * arrow_size * 0.5
	var tip2: Vector2 = end - dir * arrow_size - perp * arrow_size * 0.5
	draw_polygon(PackedVector2Array([end, tip1, tip2]), PackedColorArray([ARROW_COLOR, ARROW_COLOR, ARROW_COLOR]))

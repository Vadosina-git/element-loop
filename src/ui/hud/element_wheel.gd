class_name ElementWheel
extends Control

## Круговая схема стихий со стрелками контров.
##
## Рисует 5 стихий по кругу и стрелки «побеждает» между ними.
## Подсвечивает активную стихию и её цель.

# --- Константы ---

## Порядок стихий на колесе (индекс в массиве).
## Water побеждает Fire, Fire побеждает Tree и т.д.
var ELEMENTS: Array[String] = ElementIcons.get_wheel_icons()
const COLORS: Array[Color] = [
	Color(0.1, 0.4, 0.9),   # Water
	Color(0.9, 0.2, 0.1),   # Fire
	Color(0.2, 0.7, 0.2),   # Tree
	Color(0.6, 0.4, 0.2),   # Earth
	Color(0.7, 0.7, 0.7),   # Metal
]

## Маппинг ElementTable.Element → индекс на колесе.
const ELEMENT_TO_WHEEL: Dictionary = {
	ElementTable.Element.WATER: 0,
	ElementTable.Element.FIRE: 1,
	ElementTable.Element.TREE: 2,
	ElementTable.Element.EARTH: 3,
	ElementTable.Element.METAL: 4,
}

const ICON_SIZE: float = 56.0
const ARROW_COLOR: Color = Color(0.8, 0.8, 0.8, 0.3)
const ARROW_COLOR_ACTIVE: Color = Color(1.0, 1.0, 0.3, 0.9)
const ARROW_WIDTH: float = 3.0
const ARROW_WIDTH_ACTIVE: float = 5.0

# --- Публичные переменные ---

## Текущая активная стихия (-1 = нет).
var active_element: int = -1


# --- Встроенные колбеки ---

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - ICON_SIZE - 4.0

	var active_idx: int = _get_wheel_index(active_element)
	var target_idx: int = (active_idx + 1) % 5 if active_idx >= 0 else -1

	# Позиции 5 стихий по кругу
	var positions: Array[Vector2] = []
	for i: int in range(5):
		var angle: float = -PI / 2.0 + i * TAU / 5.0
		positions.append(center + Vector2(cos(angle), sin(angle)) * radius)

	# Стрелки
	for i: int in range(5):
		var from: Vector2 = positions[i]
		var to: Vector2 = positions[(i + 1) % 5]
		var is_active_arrow: bool = (i == active_idx)
		var color: Color
		var width: float
		if is_active_arrow:
			color = COLORS[(i + 1) % 5].lightened(0.4)
			width = ARROW_WIDTH_ACTIVE
		else:
			color = ARROW_COLOR
			width = ARROW_WIDTH
		_draw_arrow(from, to, color, width)

	# Иконки стихий
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 38
	var ascent: float = font.get_ascent(font_size)
	var descent: float = font.get_descent(font_size)
	var text_height: float = ascent + descent
	for i: int in range(5):
		var pos: Vector2 = positions[i]
		var is_active: bool = (i == active_idx)
		var is_target: bool = (i == target_idx)

		# Фон-кружок
		if is_active:
			# Активная стихия — яркий кружок с пульсацией
			draw_circle(pos, ICON_SIZE + 4.0, Color(COLORS[i].r, COLORS[i].g, COLORS[i].b, 0.4))
			draw_circle(pos, ICON_SIZE, Color(0.15, 0.15, 0.15, 0.9))
			draw_arc(pos, ICON_SIZE, 0.0, TAU, 32, COLORS[i], 5.0)
		elif is_target:
			# Цель — подсветка цветом стихии (ярче)
			var bright: Color = COLORS[i].lightened(0.4)
			draw_circle(pos, ICON_SIZE + 4.0, Color(bright.r, bright.g, bright.b, 0.5))
			draw_circle(pos, ICON_SIZE, Color(bright.r, bright.g, bright.b, 0.25))
			draw_arc(pos, ICON_SIZE, 0.0, TAU, 32, bright, 5.0)
		else:
			# Неактивный — тусклый
			draw_circle(pos, ICON_SIZE, Color(0.1, 0.1, 0.1, 0.5))
			draw_arc(pos, ICON_SIZE, 0.0, TAU, 32, Color(COLORS[i].r, COLORS[i].g, COLORS[i].b, 0.3), 2.0)

		# Эмодзи
		var draw_width: float = ICON_SIZE * 2.0
		var draw_pos: Vector2 = Vector2(pos.x - draw_width / 2.0, pos.y + text_height / 2.0 - descent)
		draw_string(font, draw_pos, ELEMENTS[i], HORIZONTAL_ALIGNMENT_CENTER, draw_width, font_size)


# --- Публичные методы ---

## Устанавливает активную стихию и перерисовывает.
func set_active_element(element: int) -> void:
	active_element = element
	queue_redraw()


# --- Приватные методы ---

## Возвращает индекс на колесе по ElementTable.Element, или -1.
func _get_wheel_index(element: int) -> int:
	if element < 0:
		return -1
	var el: ElementTable.Element = element as ElementTable.Element
	if ELEMENT_TO_WHEEL.has(el):
		return ELEMENT_TO_WHEEL[el] as int
	return -1


## Рисует стрелку между двумя точками.
func _draw_arrow(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var dir: Vector2 = (to - from).normalized()
	var start: Vector2 = from + dir * (ICON_SIZE + 4.0)
	var end: Vector2 = to - dir * (ICON_SIZE + 4.0)

	draw_line(start, end, color, width)

	# Наконечник стрелки
	var arrow_size: float = 14.0
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tip1: Vector2 = end - dir * arrow_size + perp * arrow_size * 0.5
	var tip2: Vector2 = end - dir * arrow_size - perp * arrow_size * 0.5
	draw_polygon(PackedVector2Array([end, tip1, tip2]), PackedColorArray([color, color, color]))

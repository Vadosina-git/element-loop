class_name HUD
extends CanvasLayer

## Минимальный HUD: отображение HP, текущей стихии и кнопка постановки зоны.

# --- Сигналы ---

## Испускается при нажатии кнопки «Зона».
signal zone_button_pressed

# --- @onready переменные ---

@onready var _hp_label: Label = %HPLabel
@onready var _element_label: Label = %ElementLabel
@onready var _zone_button: Button = %ZoneButton

# --- Встроенные колбеки ---

func _ready() -> void:
	_zone_button.pressed.connect(_on_zone_button_pressed)
	update_hp(2)
	update_element(-1)

# --- Публичные методы ---

## Обновляет отображение очков здоровья игрока.
func update_hp(hp: int) -> void:
	_hp_label.text = "HP: %d" % hp


## Обновляет отображение текущей стихии.
## Передать -1, чтобы показать отсутствие стихии и заблокировать кнопку зоны.
func update_element(element: int) -> void:
	if element == -1:
		_element_label.text = "Стихия: —"
		_zone_button.disabled = true
	else:
		_element_label.text = "Стихия: %s" % _element_name(element as ElementTable.Element)
		_zone_button.disabled = false

# --- Приватные методы ---

## Возвращает русское название стихии.
func _element_name(element: ElementTable.Element) -> String:
	match element:
		ElementTable.Element.FIRE:
			return "Огонь"
		ElementTable.Element.WATER:
			return "Вода"
		ElementTable.Element.TREE:
			return "Дерево"
		ElementTable.Element.EARTH:
			return "Земля"
		ElementTable.Element.METAL:
			return "Металл"
	return "—"

# --- Колбеки сигналов ---

func _on_zone_button_pressed() -> void:
	zone_button_pressed.emit()

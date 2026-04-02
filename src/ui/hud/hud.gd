class_name HUD
extends CanvasLayer

## Минимальный HUD: отображение HP, текущей стихии и кнопка постановки зоны.

# --- Сигналы ---

## Испускается при нажатии кнопки «Зона».
signal zone_button_pressed

## Испускается при нажатии кнопки «Рывок».
signal dash_button_pressed

# --- Константы ---

const DASH_COOLDOWN_DEFAULT: float = 5.0

# --- @onready переменные ---

@onready var _hp_label: Label = %HPLabel
@onready var _element_label: Label = %ElementLabel
@onready var _zone_button: Button = %ZoneButton
@onready var _dash_button: Button = %DashButton
@onready var _dash_cooldown_bar: TextureProgressBar = %DashCooldownBar
@onready var _dash_cooldown_label: Label = %DashCooldownLabel

# --- Встроенные колбеки ---

func _ready() -> void:
	_zone_button.pressed.connect(_on_zone_button_pressed)
	_dash_button.pressed.connect(_on_dash_button_pressed)
	update_hp(2)
	update_element(-1)
	_update_dash_cooldown_display(0.0, DASH_COOLDOWN_DEFAULT)

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

## Обновляет индикатор кулдауна рывка.
func update_dash_cooldown(remaining: float, total: float) -> void:
	_update_dash_cooldown_display(remaining, total)

# --- Приватные методы ---

## Обновляет визуал кулдауна.
func _update_dash_cooldown_display(remaining: float, total: float) -> void:
	_dash_cooldown_bar.max_value = total
	_dash_cooldown_bar.value = total - remaining
	_dash_button.disabled = remaining > 0.0
	if remaining > 0.0:
		_dash_cooldown_label.text = "%1.0f" % ceilf(remaining)
	else:
		_dash_cooldown_label.text = "Рывок"


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


func _on_dash_button_pressed() -> void:
	dash_button_pressed.emit()

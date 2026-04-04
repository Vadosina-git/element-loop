class_name ElementIcons
extends RefCounted

## Иконки стихий как PNG-текстуры (рендер из эмодзи Apple Color Emoji).
## Работают одинаково на всех платформах включая веб.

const ICON_PATHS: Dictionary = {
	ElementTable.Element.FIRE: "res://assets/icons/fire.png",
	ElementTable.Element.WATER: "res://assets/icons/water.png",
	ElementTable.Element.TREE: "res://assets/icons/tree.png",
	ElementTable.Element.EARTH: "res://assets/icons/earth.png",
	ElementTable.Element.METAL: "res://assets/icons/metal.png",
}

const ALERT_PATH: String = "res://assets/icons/alert.png"
const HEART_PATH: String = "res://assets/icons/heart.png"
const HEART_BROKEN_PATH: String = "res://assets/icons/heart_broken.png"
const BOOK_PATH: String = "res://assets/icons/book.png"
const VICTORY_PATH: String = "res://assets/icons/victory.png"

const ELEMENT_NAMES: Dictionary = {
	ElementTable.Element.FIRE: "Огонь",
	ElementTable.Element.WATER: "Вода",
	ElementTable.Element.TREE: "Дерево",
	ElementTable.Element.EARTH: "Земля",
	ElementTable.Element.METAL: "Металл",
}


## Возвращает текстуру иконки стихии.
static func get_texture(element: ElementTable.Element) -> Texture2D:
	var path: String = ICON_PATHS.get(element, "") as String
	if path != "":
		return load(path) as Texture2D
	return null


## Возвращает текстуру восклицательного знака (погоня).
static func get_alert_texture() -> Texture2D:
	return load(ALERT_PATH) as Texture2D


## Возвращает текстуру сердечка.
static func get_heart_texture() -> Texture2D:
	return load(HEART_PATH) as Texture2D


## Возвращает текстуру разбитого сердечка.
static func get_heart_broken_texture() -> Texture2D:
	return load(HEART_BROKEN_PATH) as Texture2D


## Возвращает текстуру книги.
static func get_book_texture() -> Texture2D:
	return load(BOOK_PATH) as Texture2D


## Возвращает текстуру победы.
static func get_victory_texture() -> Texture2D:
	return load(VICTORY_PATH) as Texture2D


## Возвращает название стихии.
static func get_element_name(element: ElementTable.Element) -> String:
	return ELEMENT_NAMES.get(element, "?") as String

class_name ElementIcons
extends RefCounted

## Иконки стихий: эмодзи на десктопе, PNG-текстуры на вебе.

const EMOJI: Dictionary = {
	ElementTable.Element.FIRE: "🔥",
	ElementTable.Element.WATER: "💧",
	ElementTable.Element.TREE: "🌿",
	ElementTable.Element.EARTH: "🪨",
	ElementTable.Element.METAL: "⚙️",
}

const ICON_PATHS: Dictionary = {
	ElementTable.Element.FIRE: "res://assets/icons/fire.png",
	ElementTable.Element.WATER: "res://assets/icons/water.png",
	ElementTable.Element.TREE: "res://assets/icons/tree.png",
	ElementTable.Element.EARTH: "res://assets/icons/earth.png",
	ElementTable.Element.METAL: "res://assets/icons/metal.png",
}

const ELEMENT_NAMES: Dictionary = {
	ElementTable.Element.FIRE: "F",
	ElementTable.Element.WATER: "W",
	ElementTable.Element.TREE: "T",
	ElementTable.Element.EARTH: "E",
	ElementTable.Element.METAL: "M",
}


static func _is_web() -> bool:
	return OS.has_feature("web")


## Возвращает текстовую иконку стихии (эмодзи на десктопе, буква на вебе).
static func get_icon(element: ElementTable.Element) -> String:
	if _is_web():
		return ELEMENT_NAMES.get(element, "?") as String
	return EMOJI.get(element, "?") as String


## Возвращает текстуру иконки стихии (PNG). Работает на всех платформах.
static func get_texture(element: ElementTable.Element) -> Texture2D:
	var path: String = ICON_PATHS.get(element, "") as String
	if path != "":
		return load(path) as Texture2D
	return null


static func get_heart() -> String:
	return "<3" if _is_web() else "❤️"


static func get_heart_broken() -> String:
	return "X" if _is_web() else "💔"


static func get_book_arrow() -> String:
	return ">> Book" if _is_web() else "📖 ➤"


static func get_victory_text() -> String:
	return "*** ПОБЕДА! ***" if _is_web() else "🎉 ПОБЕДА! 🎉"


## Список текстовых иконок для колеса стихий.
static func get_wheel_icons() -> Array[String]:
	if _is_web():
		return ["W", "F", "T", "E", "M"]
	return ["💧", "🔥", "🌿", "🪨", "⚙️"]

class_name ElementIcons
extends RefCounted

## Иконки стихий: эмодзи для десктопа, Unicode-символы для веб.

const EMOJI: Dictionary = {
	ElementTable.Element.FIRE: "🔥",
	ElementTable.Element.WATER: "💧",
	ElementTable.Element.TREE: "🌿",
	ElementTable.Element.EARTH: "🪨",
	ElementTable.Element.METAL: "⚙️",
}

const UNICODE: Dictionary = {
	ElementTable.Element.FIRE: "▲",
	ElementTable.Element.WATER: "●",
	ElementTable.Element.TREE: "♣",
	ElementTable.Element.EARTH: "■",
	ElementTable.Element.METAL: "◆",
}


static func _is_web() -> bool:
	return OS.has_feature("web")


static func get_icon(element: ElementTable.Element) -> String:
	if _is_web():
		return UNICODE.get(element, "?") as String
	return EMOJI.get(element, "?") as String


static func get_heart() -> String:
	return "♥" if _is_web() else "❤️"


static func get_heart_broken() -> String:
	return "♡" if _is_web() else "💔"


static func get_book_arrow() -> String:
	return "► Книга" if _is_web() else "📖 ➤"


static func get_victory_text() -> String:
	return "*** ПОБЕДА! ***" if _is_web() else "🎉 ПОБЕДА! 🎉"


## Список иконок для колеса стихий (порядок: Water, Fire, Tree, Earth, Metal).
static func get_wheel_icons() -> Array[String]:
	if _is_web():
		return ["●", "▲", "♣", "■", "◆"]
	return ["💧", "🔥", "🌿", "🪨", "⚙️"]

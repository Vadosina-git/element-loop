class_name ElementTable
extends RefCounted

## Таблица стихий и контров.
##
## Содержит перечисление всех стихий и статические методы
## для определения контр-отношений между ними.

enum Element {
	FIRE,
	WATER,
	TREE,
	EARTH,
	METAL,
}


## Возвращает стихию-контр для данной стихии врага.
static func get_counter(enemy_element: Element) -> Element:
	match enemy_element:
		Element.FIRE:
			return Element.WATER
		Element.WATER:
			return Element.METAL
		Element.TREE:
			return Element.FIRE
		Element.EARTH:
			return Element.TREE
		Element.METAL:
			return Element.EARTH
	return enemy_element


## Проверяет, является ли зона контр-зоной для врага.
static func is_counter(zone_element: Element, enemy_element: Element) -> bool:
	return zone_element == get_counter(enemy_element)


## Проверяет, является ли зона «своей» для врага (усиление).
static func is_same(zone_element: Element, enemy_element: Element) -> bool:
	return zone_element == enemy_element

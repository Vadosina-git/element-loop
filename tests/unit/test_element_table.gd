extends GutTest

## Тесты таблицы стихий.
##
## Проверяет корректность контр-отношений между стихиями
## и вспомогательные методы is_counter / is_same.


func test_fire_countered_by_water() -> void:
	assert_eq(
		ElementTable.get_counter(ElementTable.Element.FIRE),
		ElementTable.Element.WATER
	)


func test_water_countered_by_metal() -> void:
	assert_eq(
		ElementTable.get_counter(ElementTable.Element.WATER),
		ElementTable.Element.METAL
	)


func test_tree_countered_by_fire() -> void:
	assert_eq(
		ElementTable.get_counter(ElementTable.Element.TREE),
		ElementTable.Element.FIRE
	)


func test_earth_countered_by_tree() -> void:
	assert_eq(
		ElementTable.get_counter(ElementTable.Element.EARTH),
		ElementTable.Element.TREE
	)


func test_metal_countered_by_earth() -> void:
	assert_eq(
		ElementTable.get_counter(ElementTable.Element.METAL),
		ElementTable.Element.EARTH
	)


func test_is_counter_true() -> void:
	assert_true(
		ElementTable.is_counter(ElementTable.Element.WATER, ElementTable.Element.FIRE)
	)


func test_is_counter_false() -> void:
	assert_false(
		ElementTable.is_counter(ElementTable.Element.FIRE, ElementTable.Element.FIRE)
	)


func test_is_same_true() -> void:
	assert_true(
		ElementTable.is_same(ElementTable.Element.FIRE, ElementTable.Element.FIRE)
	)


func test_is_same_false() -> void:
	assert_false(
		ElementTable.is_same(ElementTable.Element.WATER, ElementTable.Element.FIRE)
	)

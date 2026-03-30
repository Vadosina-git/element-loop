extends GutTest

## Тесты боевой логики: метки, ярость и урон.

var _combat: CombatLogic


func before_each() -> void:
	_combat = CombatLogic.new()


func test_apply_mark_on_counter() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	var marked: bool = _combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	assert_true(marked, "Контр-зона должна накладывать метку")
	assert_true(_combat.is_marked(enemy_id), "Враг должен быть помечен")


func test_no_mark_on_same_element() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	var marked: bool = _combat.try_apply_mark(enemy_id, ElementTable.Element.FIRE)
	assert_false(marked, "Зона своей стихии не должна накладывать метку")
	assert_false(_combat.is_marked(enemy_id), "Враг не должен быть помечен")


func test_no_mark_on_neutral() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	var marked: bool = _combat.try_apply_mark(enemy_id, ElementTable.Element.TREE)
	assert_false(marked, "Нейтральная зона не должна накладывать метку")


func test_mark_tick_deals_damage_after_duration() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	_combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	_combat.tick(3.0)
	assert_eq(_combat.get_enemy_hp(enemy_id), 0, "После 3 сек метки враг должен получить урон")


func test_mark_no_damage_before_duration() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	_combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	_combat.tick(2.0)
	assert_eq(_combat.get_enemy_hp(enemy_id), 1, "До истечения метки урон не наносится")


func test_enemy_dies_at_zero_hp() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	_combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	_combat.tick(3.0)
	assert_true(_combat.is_enemy_dead(enemy_id), "Враг с 0 HP должен быть мёртв")


func test_rage_on_same_element() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	var enraged: bool = _combat.try_apply_rage(enemy_id, ElementTable.Element.FIRE)
	assert_true(enraged, "Зона своей стихии должна вызывать ярость")
	assert_true(_combat.is_enraged(enemy_id), "Враг должен быть в ярости")


func test_no_rage_on_counter_element() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	var enraged: bool = _combat.try_apply_rage(enemy_id, ElementTable.Element.WATER)
	assert_false(enraged, "Контр-зона не должна вызывать ярость")


func test_no_rage_on_neutral_element() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	var enraged: bool = _combat.try_apply_rage(enemy_id, ElementTable.Element.TREE)
	assert_false(enraged, "Нейтральная зона не должна вызывать ярость")


func test_rage_expires_after_duration() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	_combat.try_apply_rage(enemy_id, ElementTable.Element.FIRE)
	_combat.tick(4.0)
	assert_false(_combat.is_enraged(enemy_id), "Ярость должна истечь через 4 сек")


func test_rage_not_expired_before_duration() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	_combat.try_apply_rage(enemy_id, ElementTable.Element.FIRE)
	_combat.tick(3.0)
	assert_true(_combat.is_enraged(enemy_id), "Ярость не должна истечь до 4 сек")


func test_mark_and_rage_parallel() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	_combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	_combat.try_apply_rage(enemy_id, ElementTable.Element.FIRE)
	assert_true(_combat.is_marked(enemy_id), "Метка и ярость работают параллельно: метка")
	assert_true(_combat.is_enraged(enemy_id), "Метка и ярость работают параллельно: ярость")


func test_mark_does_not_stack() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	_combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	var second: bool = _combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	assert_false(second, "Повторная метка не должна накладываться")


func test_rage_refreshes_timer() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	_combat.try_apply_rage(enemy_id, ElementTable.Element.FIRE)
	_combat.tick(3.0)
	# Повторное наложение ярости обновляет таймер
	_combat.try_apply_rage(enemy_id, ElementTable.Element.FIRE)
	_combat.tick(3.0)
	assert_true(_combat.is_enraged(enemy_id), "Повторная ярость должна обновить таймер")


func test_enemy_killed_signal_emitted() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	watch_signals(_combat)
	_combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	_combat.tick(3.0)
	assert_signal_emitted(_combat, "enemy_killed", "Сигнал enemy_killed должен быть отправлен")


func test_enemy_marked_signal_emitted() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	watch_signals(_combat)
	_combat.try_apply_mark(enemy_id, ElementTable.Element.WATER)
	assert_signal_emitted(_combat, "enemy_marked", "Сигнал enemy_marked должен быть отправлен")


func test_enemy_enraged_signal_emitted() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.FIRE, 1)
	watch_signals(_combat)
	_combat.try_apply_rage(enemy_id, ElementTable.Element.FIRE)
	assert_signal_emitted(_combat, "enemy_enraged", "Сигнал enemy_enraged должен быть отправлен")


func test_hp2_enemy_survives_one_mark() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.WATER, 2)
	_combat.try_apply_mark(enemy_id, ElementTable.Element.METAL)
	_combat.tick(3.0)
	assert_eq(_combat.get_enemy_hp(enemy_id), 1, "Враг с 2 HP должен выжить после одной метки")
	assert_false(_combat.is_enemy_dead(enemy_id), "Враг с 1 HP не мёртв")


func test_hp2_enemy_dies_after_two_marks() -> void:
	var enemy_id: int = 1
	_combat.register_enemy(enemy_id, ElementTable.Element.WATER, 2)
	# Первая метка
	_combat.try_apply_mark(enemy_id, ElementTable.Element.METAL)
	_combat.tick(3.0)
	# Вторая метка (метка снялась, можно наложить заново)
	var marked: bool = _combat.try_apply_mark(enemy_id, ElementTable.Element.METAL)
	assert_true(marked, "После истечения метки можно наложить заново")
	_combat.tick(3.0)
	assert_eq(_combat.get_enemy_hp(enemy_id), 0, "Враг с 2 HP должен умереть после двух меток")
	assert_true(_combat.is_enemy_dead(enemy_id), "Враг должен быть мёртв")


func test_unregistered_enemy_returns_defaults() -> void:
	assert_eq(_combat.get_enemy_hp(999), 0, "HP незарегистрированного врага = 0")
	assert_false(_combat.is_marked(999), "Незарегистрированный враг не помечен")
	assert_false(_combat.is_enraged(999), "Незарегистрированный враг не в ярости")
	assert_true(_combat.is_enemy_dead(999), "Незарегистрированный враг считается мёртвым")


func test_all_counter_pairs() -> void:
	# Проверяем все 5 пар контров
	var pairs: Array = [
		[ElementTable.Element.FIRE, ElementTable.Element.WATER],
		[ElementTable.Element.WATER, ElementTable.Element.METAL],
		[ElementTable.Element.TREE, ElementTable.Element.FIRE],
		[ElementTable.Element.EARTH, ElementTable.Element.TREE],
		[ElementTable.Element.METAL, ElementTable.Element.EARTH],
	]
	for i: int in range(pairs.size()):
		var enemy_element: ElementTable.Element = pairs[i][0]
		var counter_element: ElementTable.Element = pairs[i][1]
		var eid: int = 100 + i
		_combat.register_enemy(eid, enemy_element, 1)
		var marked: bool = _combat.try_apply_mark(eid, counter_element)
		assert_true(marked, "Контр-пара %d должна работать" % i)

class_name ShopOverlay
extends Control

## Оверлей магазина IAP — жизни и безлимит.
##
## Цены берутся из IapManager (платформенные строки, Guideline 3.1.1).
## Кнопка Restore Purchases — обязательна для App Store.
## Работает на паузе (process_mode = ALWAYS).

# --- Сигналы ---

signal closed


# --- Приватные переменные ---

var _panel: PanelContainer = null
var _items_column: VBoxContainer = null
var _status_label: Label = null
var _buttons_by_id: Dictionary = {}  # {product_id: Button}
var _is_purchasing: bool = false


# --- Встроенные колбеки ---

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false

	IapManager.products_fetched.connect(_on_products_fetched)
	IapManager.purchase_success.connect(_on_purchase_success)
	IapManager.purchase_failed.connect(_on_purchase_failed)
	IapManager.purchase_canceled.connect(_on_purchase_canceled)
	IapManager.restore_completed.connect(_on_restore_completed)


# --- Публичные методы ---

## Открывает магазин и запрашивает актуальные цены.
func open() -> void:
	visible = true
	get_tree().paused = true
	IapManager.fetch_products()


## Закрывает магазин.
func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


# --- Приватные методы ---

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0A1F0A")
	style.set_border_width_all(3)
	style.border_color = Color("F0C850")
	style.set_corner_radius_all(16)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -320.0
	_panel.offset_top = -300.0
	_panel.offset_right = 320.0
	_panel.offset_bottom = 300.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)

	var title := Label.new()
	title.text = Translations.tr_key("shop.title")
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("F0C850"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	_items_column = VBoxContainer.new()
	_items_column.add_theme_constant_override("separation", 8)
	col.add_child(_items_column)

	# Плейсхолдеры до products_fetched
	_rebuild_items([
		{"id": IapManager.PRODUCT_LIVES_10,        "price_string": "…", "title": Translations.tr_key("shop.pack_10")},
		{"id": IapManager.PRODUCT_LIVES_25,        "price_string": "…", "title": Translations.tr_key("shop.pack_25")},
		{"id": IapManager.PRODUCT_LIVES_100,       "price_string": "…", "title": Translations.tr_key("shop.pack_100")},
		{"id": IapManager.PRODUCT_LIVES_UNLIMITED, "price_string": "…", "title": Translations.tr_key("shop.pack_unlimited")},
	])

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
	_status_label.text = ""
	col.add_child(_status_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	col.add_child(footer)

	var restore_btn := _make_button(Translations.tr_key("shop.restore"), Color("2A5A2A"))
	restore_btn.pressed.connect(func() -> void:
		_status_label.text = ""
		IapManager.restore_purchases()
	)
	footer.add_child(restore_btn)

	var close_btn := _make_button(Translations.tr_key("shop.close"), Color("5A1A1A"))
	close_btn.pressed.connect(close)
	footer.add_child(close_btn)


func _rebuild_items(products: Array) -> void:
	for child: Node in _items_column.get_children():
		child.queue_free()
	_buttons_by_id.clear()

	for p: Variant in products:
		if not (p is Dictionary):
			continue
		var product_id: String = String((p as Dictionary).get("id", ""))
		var price: String = String((p as Dictionary).get("price_string", "…"))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		_items_column.add_child(row)

		var label := Label.new()
		label.text = _title_for(product_id)
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var btn := _make_button(price, Color("1A6A2A"))
		btn.custom_minimum_size = Vector2(140, 56)
		btn.pressed.connect(_on_buy_pressed.bind(product_id))
		# Для unlimited: если уже куплен — блокируем
		if product_id == IapManager.PRODUCT_LIVES_UNLIMITED and SaveManager.unlimited_lives:
			btn.text = "✓"
			btn.disabled = true
		row.add_child(btn)
		_buttons_by_id[product_id] = btn


func _title_for(product_id: String) -> String:
	match product_id:
		IapManager.PRODUCT_LIVES_10:
			return Translations.tr_key("shop.pack_10")
		IapManager.PRODUCT_LIVES_25:
			return Translations.tr_key("shop.pack_25")
		IapManager.PRODUCT_LIVES_100:
			return Translations.tr_key("shop.pack_100")
		IapManager.PRODUCT_LIVES_UNLIMITED:
			return Translations.tr_key("shop.pack_unlimited")
	return product_id


func _make_button(label: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(180, 52)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.focus_mode = Control.FOCUS_NONE
	var st := StyleBoxFlat.new()
	st.bg_color = bg_color
	st.set_border_width_all(2)
	st.border_color = Color(1, 1, 1, 0.3)
	st.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_stylebox_override("focus", st)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return btn


func _on_buy_pressed(product_id: String) -> void:
	if _is_purchasing:
		return
	_is_purchasing = true
	_status_label.text = ""
	IapManager.purchase(product_id)


func _on_products_fetched(products: Array) -> void:
	_rebuild_items(products)


func _on_purchase_success(product_id: String) -> void:
	_is_purchasing = false
	_apply_reward(product_id)


func _on_purchase_failed(_product_id: String, reason: String) -> void:
	_is_purchasing = false
	_status_label.text = "%s: %s" % [Translations.tr_key("shop.purchase_failed"), reason]


func _on_purchase_canceled(_product_id: String) -> void:
	_is_purchasing = false


func _on_restore_completed(restored_ids: Array) -> void:
	for rid: Variant in restored_ids:
		_apply_reward(String(rid))


func _apply_reward(product_id: String) -> void:
	var packs: Array = ConfigManager.get_iap_packs()
	for p: Variant in packs:
		if not (p is Dictionary):
			continue
		var pd: Dictionary = p as Dictionary
		if String(pd.get("id", "")) != product_id:
			continue
		if bool(pd.get("unlimited", false)):
			LivesManager.set_unlimited(true)
		else:
			LivesManager.add_lives(int(pd.get("lives", 0)))
		break
	# Учёт owned_products — для restore
	if not SaveManager.owned_products.has(product_id):
		SaveManager.owned_products.append(product_id)
		SaveManager.save_game()
	# Перерисовать кнопку unlimited
	if _buttons_by_id.has(product_id) and product_id == IapManager.PRODUCT_LIVES_UNLIMITED:
		var btn: Button = _buttons_by_id[product_id] as Button
		btn.text = "✓"
		btn.disabled = true

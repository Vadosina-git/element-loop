extends Node

## Фасад над IAP-бэкендом.
##
## Автодетектит плагин RevenueCat (singleton GodotxRevenueCat). Если плагина
## нет — работает как STUB: немедленно успешно завершает покупки и возвращает
## фиктивные цены. Это позволяет разрабатывать и тестировать магазин в Godot
## editor / web, где нативный IAP недоступен.
##
## SKU для Box Master:
##   boxmaster_lives_10         — +10 жизней
##   boxmaster_lives_25         — +25 жизней
##   boxmaster_lives_100        — +100 жизней
##   boxmaster_lives_unlimited  — безлимит (non-consumable)
##
## Публичные ключи RevenueCat (appl_* / goog_*) НЕ секретны — можно хранить
## здесь, но безопаснее подставлять в Project Settings → Application.
## Автозагрузка.

# --- Сигналы ---

signal purchase_success(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal purchase_canceled(product_id: String)
signal products_fetched(products: Array)  # [{id, price_string, title}]
signal restore_completed(restored_ids: Array)


# --- Константы ---

const RC_API_KEY_IOS: String = ""      # appl_*** — заполнить после создания RC-проекта
const RC_API_KEY_ANDROID: String = ""  # goog_*** — заполнить после создания RC-проекта

const PRODUCT_LIVES_10: String = "boxmaster_lives_10"
const PRODUCT_LIVES_25: String = "boxmaster_lives_25"
const PRODUCT_LIVES_100: String = "boxmaster_lives_100"
const PRODUCT_LIVES_UNLIMITED: String = "boxmaster_lives_unlimited"

const ALL_PRODUCTS: Array[String] = [
	PRODUCT_LIVES_10,
	PRODUCT_LIVES_25,
	PRODUCT_LIVES_100,
	PRODUCT_LIVES_UNLIMITED,
]

# --- Приватные переменные ---

var _backend: Node = null  # плагин RevenueCat, если найден
var _use_stub: bool = true
var _stub_products: Array = [
	{"id": PRODUCT_LIVES_10,        "price_string": "$0.99",  "title": "10 lives"},
	{"id": PRODUCT_LIVES_25,        "price_string": "$1.99",  "title": "25 lives"},
	{"id": PRODUCT_LIVES_100,       "price_string": "$4.99",  "title": "100 lives"},
	{"id": PRODUCT_LIVES_UNLIMITED, "price_string": "$9.99",  "title": "Unlimited lives"},
]


# --- Встроенные колбеки ---

func _ready() -> void:
	_backend = _resolve_backend()
	_use_stub = _backend == null
	if _use_stub:
		print("[IapManager] Плагин RevenueCat не найден — используется STUB.")
	else:
		print("[IapManager] Плагин RevenueCat найден, настраиваю…")
		_configure_backend()


# --- Публичные методы ---

## Возвращает список доступных SKU.
func get_all_product_ids() -> Array[String]:
	return ALL_PRODUCTS


## Запрашивает актуальные цены/title с платформы (или возвращает stub-цены).
## Результат придёт через сигнал products_fetched.
func fetch_products() -> void:
	if _use_stub:
		products_fetched.emit(_stub_products)
		return
	# Реальная имплементация через RevenueCat SDK:
	if _backend.has_method("get_offerings"):
		_backend.call("get_offerings")


## Запускает покупку продукта.
func purchase(product_id: String) -> void:
	if _use_stub:
		# В STUB сразу "успех" — удобно для отладки без стора
		call_deferred("_emit_stub_success", product_id)
		return
	if _backend != null and _backend.has_method("purchase_product"):
		_backend.call("purchase_product", product_id)


## Восстановление ранее купленных non-consumable (unlimited).
func restore_purchases() -> void:
	if _use_stub:
		restore_completed.emit(SaveManager.owned_products.duplicate())
		return
	if _backend != null and _backend.has_method("restore_purchases"):
		_backend.call("restore_purchases")


## Возвращает true если данный продукт — unlimited.
static func is_unlimited_product(product_id: String) -> bool:
	return product_id == PRODUCT_LIVES_UNLIMITED


# --- Приватные методы ---

func _resolve_backend() -> Node:
	# Плагин RevenueCat регистрирует свой синглтон под именем GodotxRevenueCat
	if Engine.has_singleton("GodotxRevenueCat"):
		return Engine.get_singleton("GodotxRevenueCat") as Node
	return null


func _configure_backend() -> void:
	if _backend == null:
		return
	var api_key: String = ""
	if OS.get_name() == "iOS":
		api_key = RC_API_KEY_IOS
	elif OS.get_name() == "Android":
		api_key = RC_API_KEY_ANDROID
	if api_key.is_empty():
		push_warning("[IapManager] RC API key не задан — вернусь к STUB.")
		_backend = null
		_use_stub = true
		return
	if _backend.has_method("configure"):
		_backend.call("configure", api_key)
	# Подключаем сигналы плагина (имена могут отличаться у конкретной версии)
	_try_connect_backend_signal("purchase_completed", _on_backend_purchase_success)
	_try_connect_backend_signal("purchase_failed", _on_backend_purchase_failed)
	_try_connect_backend_signal("purchase_canceled", _on_backend_purchase_canceled)
	_try_connect_backend_signal("offerings_received", _on_backend_offerings)
	_try_connect_backend_signal("restore_completed", _on_backend_restore)


func _try_connect_backend_signal(sig_name: String, callable: Callable) -> void:
	if _backend == null:
		return
	if _backend.has_signal(sig_name):
		_backend.connect(sig_name, callable)


func _emit_stub_success(product_id: String) -> void:
	purchase_success.emit(product_id)


func _on_backend_purchase_success(product_id: String) -> void:
	purchase_success.emit(product_id)


func _on_backend_purchase_failed(product_id: String, reason: String) -> void:
	purchase_failed.emit(product_id, reason)


func _on_backend_purchase_canceled(product_id: String) -> void:
	purchase_canceled.emit(product_id)


func _on_backend_offerings(offerings: Variant) -> void:
	# Нормализация в наш формат {id, price_string, title}
	var out: Array = []
	if offerings is Array:
		for item: Variant in offerings:
			if item is Dictionary:
				out.append(item)
	products_fetched.emit(out)


func _on_backend_restore(restored_ids: Array) -> void:
	restore_completed.emit(restored_ids)

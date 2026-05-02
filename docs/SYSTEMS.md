# SYSTEMS — автозагрузки (Autoload синглтоны)

Зарегистрированы в `project.godot` (раздел `[autoload]`). Доступны глобально по имени.

```
GameManager      — прогресс, апгрейды (заглушка на текущем этапе)
AudioManager     — звуки (заглушка)
ConfigManager    — балансовые конфиги
Translations     — локализация
SaveManager      — сохранение/загрузка JSON в user://
LivesManager     — система жизней с реген-таймером
IapManager       — IAP-фасад (RevenueCat + STUB)
```

---

## 1. SaveManager

Файл: `src/systems/save_manager.gd`. Путь: `user://save.json`.

**Что хранится:**
- Жизни (`lives`, `unlimited`, `last_regen_at_ms`).
- Прогресс уровня (когда будет реализован).

API:
- `save_game()` / `load_game()` — синхронные.
- `to_dict()` / `from_dict()` — сериализация (расширять при добавлении полей).

**Обфускация:** XOR с ключом `_OBFUSCATION_KEY = 0x5A`. Это не защита от взлома (любой заглянет в код), а блок «случайной» правки сейва игроком. Для production-уровня защиты — серверная валидация (когда появится).

Сигналы: `state_loaded`, `state_saved`.

---

## 2. LivesManager

Файл: `src/systems/lives_manager.gd`.

**Логика жизней:**
- Конечный пул (по умолчанию ~5).
- `consume(n)` тратит, `add_lives(n)` пополняет.
- Регенерация: 1 жизнь каждые 10 минут (константа), пока пул не до максимума.
- `set_unlimited(true)` — режим «∞» (за IAP-покупку).

**Catch-up:** при загрузке игры считает `(now - last_regen_at_ms)` и применяет накопившиеся ре-гены — игрок получает жизни за время вне игры.

Сигналы: `lives_changed(lives, unlimited)`, `lives_exhausted`, `regen_timer_updated(seconds_left)`.

**Edge:** часы переведены назад → `_now_ms` уходит в прошлое → `_catch_up_regen` отрабатывает корректно (отрицательный delta = 0). Manipulation защита минимальная; полноценная — на сервере.

---

## 3. IapManager

Файл: `src/systems/iap_manager.gd`. Фасад над двумя бэкендами:

| Бэкенд | Когда используется |
|---|---|
| RevenueCat (плагин) | Реальный девайс, плагин найден |
| **STUB** | Редактор / отсутствие плагина — все покупки сразу `success` |

`_resolve_backend` выбирает доступный. STUB пишет в лог `[IapManager] Плагин RevenueCat не найден — используется STUB.` (это есть в логах при запуске на десктопе — норма).

**Продукты (определены константами):**
- `boxmaster_lives_10` / `_25` / `_100` — пакеты жизней
- `boxmaster_lives_unlimited` — безлимит

**Ключи RC** (`RC_API_KEY_IOS` / `RC_API_KEY_ANDROID`) — пустые на текущий момент. Заполнить перед mobile-сборкой.

API:
- `purchase(product_id)` / `restore_purchases()` / `fetch_products()`.
- Сигналы: `purchase_success/failed/canceled`, `products_fetched`, `restore_completed`.

`game_controller`/`HUD` подписываются и реагируют (например, `purchase_success(LIVES_25)` → `LivesManager.add_lives(25)`).

---

## 4. ConfigManager

Файл: `src/systems/config_manager.gd`.

Загружает балансовые настройки (если будут). На текущем этапе — практически пустой; точка расширения для будущей системы конфигов (стиль video poker `configs/`).

---

## 5. Translations

Файл: `src/systems/translations.gd`.

Лёгкий враппер над Godot's TranslationServer. Метод `T(key)` для подстановки локализованного текста. Локали — в `resources/translations/`.

---

## 6. GameManager / AudioManager

Заглушки на текущем этапе. Зарезервированы под прогрессию (постоянные апгрейды между забегами) и звуки/музыку соответственно.

При расширении смотреть архитектуру в дизайн-доке (CLAUDE.md, раздел «Архитектура»).

---

## 7. Порядок загрузки автозагрузок

Godot загружает в порядке объявления в `project.godot`. Зависимости:
- `LivesManager` использует `SaveManager` → SaveManager должен быть **выше** в списке.
- `IapManager` обрабатывает покупки → может вызывать `LivesManager.add_lives` → IAP должен быть **после** LivesManager.

Текущий порядок: `GameManager → Audio → Config → Translations → Save → Lives → IAP`. Корректен.

---

## 8. Edge-кейсы

- ✅ **Первый запуск** — `save.json` отсутствует → `LivesManager._ensure_initial_state` ставит дефолт.
- ⚠️ **Покупка в редакторе** — STUB сразу эмитит `purchase_success` (это by design, для UI-теста).
- ⚠️ **Сейв повреждён** (некорректный JSON или XOR-ключ изменился) — `load_game` молча возвращает дефолт. Игрок теряет прогресс. Defensive: сделать бэкап. TODO.
- ❓ **Часы устройства переведены вперёд** для эксплойта реген-таймера — обработка минимальная, нужна серверная валидация для production.

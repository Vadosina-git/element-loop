# VISUAL_STACK — пост-обработка, outline, камера, освещение

Файлы:
- `src/arena/post_processing.gd` — пост-эффекты (CanvasLayer 0)
- `src/arena/outline_manager.gd` — обводка объектов через next_pass
- `src/main/arena_camera.gd` — Camera3D + пресеты
- `src/ui/hud/lighting_panel.gd` — runtime-настройка освещения (клавиша L)

---

## 1. PostProcessing

Файл: `src/arena/post_processing.gd`.

`CanvasLayer` со специальным `layer = 0`. ВНИМАНИЕ: layer должен быть НИЖЕ HUD (HUD на дефолтном 0/1+) — иначе пост-эффекты накладываются на HUD и портят его.

**Эффекты в одном фрагментном шейдере:**
- Blur vignette (мягкое размытие по краям)
- Десатурация (Cozy Grove — приглушённость)
- Тёплый сдвиг цветов (warm shift)
- Контраст
- Vignette (тёмная виньетка)

**Экранный outline (Sobel):**
- Отдельный шейдер, тогглится клавишей в lighting panel.
- Детектор краёв по нормалям/глубине.
- При false-positive (артефакты на тонких объектах) — тогглить outline через next_pass (см. §2 OutlineManager).

---

## 2. OutlineManager

Файл: `src/arena/outline_manager.gd`. Обводка через **inverted hull** (классика мультяшного рендера).

**Как работает:** на каждый зарегистрированный меш накладывается `next_pass` — материал, рендерящий перевёрнутый меш чуть больше оригинала, с отключенным cull. Получается контур.

API:
- `register(mesh: MeshInstance3D, category: String)` — добавить.
- Категории: `"Персонаж"`, `"Враги"`, `"Камни"`, `"Книги"`. Цвет/толщина задаются на категорию.

**Тонкость:** при добавлении next_pass материалы поверхностей **клонируются**, иначе outline ломает базовый цвет. Это решённая проблема (упоминается в CLAUDE.md «Решённые проблемы»).

`game_controller` регистрирует ноды после спавна арены.

---

## 3. ArenaCamera

Файл: `src/main/arena_camera.gd`. `Camera3D` с пресетами.

**Пресеты** (в начале файла):
| Пресет | Угол | Высота | FOV |
|---|---|---|---|
| Стандарт | 48° | 16 | 45 |
| Ближняя | (ниже) | (ближе) | (шире) |
| Top-Down | 90° | (выше) | (умеренный) |
| Изометрия | 60° | 18 | 35 |

**Слежение:** lerp с `FOLLOW_SPEED = 5.0`. Камера не вращается, не управляется игроком.

API:
- `set_preset(preset_name)` — переключение.
- `set_target(node3d)` — кого следить.

Пресеты переключаются через UI (в lighting panel).

---

## 4. LightingPanel

Файл: `src/ui/hud/lighting_panel.gd`. Тоггл — клавиша **L**.

**5 пресетов освещения:**
- Cozy Grove (теплый main #FFE8C8 + холодный fill #B0C0E0) — дефолт
- Осень (тёплая палитра)
- Вечер (низкое солнце)
- Рассвет (мягкий свет)
- Brawl Stars (яркий, насыщенный)

**Слайдеры** для всех параметров: SSAO, glow, tone mapping (filmic), туман, fog density, fog color, sun energy и т.д.

Все настройки применяются в реальном времени к `WorldEnvironment` арены — используется для тюнинга арт-направления без перезапуска.

---

## 5. Освещение по умолчанию

Cozy Grove (см. CLAUDE.md «Визуальная стилизация»):
- Main light: тёплый `#FFE8C8`, energy ~1.0
- Fill light: холодный `#B0C0E0`, energy ~0.4
- SSAO: 1.5
- Glow: 0.3
- Tone mapping: filmic
- Fog: тёплый, плотный

---

## 6. Известные warning'и (не баги)

- `post_processing.gd:77, 136` — «Nodes with non-equal opposite anchors» — anchors шейдер-оверлея. Косметика, не влияет на работу.
- `agent_radius is ceiled to cell_size` — NavMesh округление. Стандартное поведение Godot 4.

---

## 7. Performance

- ImmediateMesh debug-визуализация (`DEBUG_VISUAL.md`) пересоздаётся каждый кадр. На сотнях врагов — отключать через `K`.
- Outline next_pass удваивает draw call'ы. Для 100+ объектов с outline стоит профайлить.
- SSAO/glow — ощутимая нагрузка на mobile. Проверить на самом слабом таргете (Android 8 entry-level).

---

## 8. Edge-кейсы

- ✅ **HUD исчезает** — проверь, не уехал ли `CanvasLayer.layer` пост-процессинга выше HUD (должен быть 0).
- ✅ **Outline делает игрока белым** — материалы surface не были клонированы. Решено в OutlineManager.
- ⚠️ **Camera слежение прыгает** при дальних телепортах игрока — `FOLLOW_SPEED` лерп слишком медленный. На рестарте арены делать `_camera.snap_to_target()` (если такой метод не реализован — добавить).

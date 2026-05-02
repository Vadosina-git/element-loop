# DEBUG_VISUAL — отладочная визуализация врагов

Все рисунки идут через `ImmediateMesh` на child-узле `_debug_mesh` (top-level, `no_depth_test = true` — видно сквозь стены).

**Toggle:** клавиша **K** (`InputEventKey.keycode == KEY_K`). Состояние общее на всех врагов через `static var debug_visible: bool = true`.

Файл: `src/enemies/enemy_base.gd` функция `_update_debug_visual()`.

---

## 1. Гейт отрисовки

Surface не открывается, если рисовать нечего (иначе `surface_end` падает на пустых вершинах). Условие выхода:

```
not player_in_range  AND  not has_search  AND  not has_breadcrumbs  AND  not is_attacking
```

То есть: рисуем, если игрок в зоне детекции, или враг расследует, или есть крошки, или враг в TELEGRAPH/ATTACK.

---

## 2. Базовая визуализация (одинаковая для всех классов)

| Цвет | Что | Когда |
|---|---|---|
| 🟢 Зелёная линия | LoS враг → игрок | `player_in_range AND has_los` |
| 🔴 Красная линия | LoS заблокирован | `player_in_range AND not has_los` |
| 🟠 Оранжевая линия | Цель SEARCH (от врага к investigation_target) | состояние SEARCH |
| 🟡 Жёлтые штырьки + соединения | Цепочка крошек (FIFO 8 шт) | `_breadcrumbs.size() > 0` |

**LoS-линия рисуется только при `player_in_range`** — у дальних врагов нет «летающих» линий, потому что и сам код не пускает рейкаст вне зоны.

---

## 3. Класс-специфичная визуализация

Виртуал `_draw_class_debug(imesh)`. Рисуется только в TELEGRAPH/ATTACK.

### MeleeEnemy — фиолетовый

- Круг радиусом `attack_range × LANDING_HIT_FACTOR (1.3)` на земле в **зафиксированной точке приземления** (`_leap_landing_pos`, set в `prepare_attack`).
- Перекрестие в центре круга.
- Линия от врага до точки.

**Важно:** круг **не двигается** во время прыжка — это абсолютная точка. Игрок видит «куда я сейчас прыгну» и может уйти за край круга. Урон считается именно по факту нахождения в этом круге, а не по близости к врагу в конце прыжка.

### RangedEnemy — золотой

- Линия от лука врага (на высоте 0.8м) к зафиксированной `_aim_target`.
- Перекрестие + маленький круг (0.3м) на земле под точкой прицела.

### BomberEnemy — оранжевый

- Круг радиусом `Bomb.EXPLOSION_RADIUS (1.2м)` в зафиксированной `_bomb_target` (точка падения бомбы).
- Перекрестие в центре.
- **Параболическая дуга-превью** из 12 сегментов от руки врага до точки падения. Видно куда полетит бомба.

---

## 4. Helper-методы (на `EnemyBase`)

```gdscript
_debug_draw_circle(imesh, center, radius, color, segments)
_debug_draw_cross(imesh, center, size, color)
```

Используются подклассами в `_draw_class_debug`. Все примитивы — `PRIMITIVE_LINES`.

---

## 5. Перформанс

ImmediateMesh пересоздаётся каждый кадр (`clear_surfaces` + `surface_begin/end`). При сотнях врагов это может подъесть CPU; для прода debug отключается тогглом K (или статическим `debug_visible = false`).

Толщина линий стандартная — Godot 4 не поддерживает width в 3D. Если потребуется — переделать на Quad-strip-меши.

# COMBAT_CORE — ядро боя: стихии, контры, метки, ярость, зоны

Чистая логика, без `Node`/3D. Тестируется изолированно (`RefCounted`).

Файлы:
- `src/combat/element_table.gd` — таблица 5 стихий и контров.
- `src/combat/zone_logic.gd` — состояние активных зон (FIFO).
- `src/combat/combat_logic.gd` — метки и ярость с таймерами.

Тесты: `tests/unit/test_*.gd` (см. `addons/gut/`).

---

## 1. ElementTable — стихии и контры

5 стихий: `FIRE`, `WATER`, `TREE`, `EARTH`, `METAL`.

| Враг   | Контр-зона |
|--------|------------|
| FIRE   | WATER      |
| WATER  | METAL      |
| TREE   | FIRE       |
| EARTH  | TREE       |
| METAL  | EARTH      |

API:
- `static get_counter(element)` — стихия, контрящая данную.
- `static is_counter(zone_element, enemy_element)` — проверка контра.
- `static is_same(a, b)` — для определения «своей» зоны (вызывает ярость).

**Главное правило игры:** на арене не могут быть 2 врага одной стихии. Контролируется в `game_controller._spawn_enemies` (round-robin).

---

## 2. ZoneLogic — активные зоны

Лимит `MAX_ZONES = 2` (3 с апгрейдом, в будущем). Если ставится третья — **первая удаляется** (FIFO).

API:
- `add_zone(element, position)` — добавляет, возвращает `ZoneData`. При переполнении старую возвращает в массиве `removed_zones` (для удаления визуала).
- `check_effect(zone_element, enemy_element)` → `EffectType.COUNTER` / `MATCHING` / `NEUTRAL`. Используется в `ZoneObject.body_entered`.

**Edge:** зоны живут бесконечно, не имеют таймера. Удаляются только при переполнении.

---

## 3. CombatLogic — метки и ярость

Сигналы:
```
enemy_marked(enemy_id)
enemy_mark_expired(enemy_id)
enemy_killed(enemy_id)       # mark прошёл → 1 HP урона → если HP=0
enemy_enraged(enemy_id)
enemy_rage_expired(enemy_id)
```

| Параметр | Значение | Описание |
|---|---|---|
| `MARK_DURATION` | 3.0с | таймер метки |
| `MARK_DAMAGE` | 1 | урон по истечении |
| `MARK_SLOW` | 0.25 | замедление 25% во время метки |
| `RAGE_DURATION` | 4.0с | таймер ярости |
| `RAGE_SPEED_BONUS` | 0.25 | +25% скорости |
| `RAGE_ATTACK_BONUS` | 0.25 | +25% темпа атак |

**Ключевые правила:**
- Метка и ярость **работают параллельно**. Ярость не отменяет метку.
- Повторный вход в контр-зону **не сбрасывает** таймер метки (по дизайну — нельзя продлевать).
- Повторный вход в свою зону **обновляет** таймер ярости (нанизывается).

API:
- `register_enemy(id, element, hp)` — регистрация (вызывается при спавне).
- `try_apply_mark(id, zone_element)` / `try_apply_rage(id, zone_element)` — возвращают `true` если эффект подошёл и был применён. Вызываются из `ZoneObject` при входе врага.
- `tick(delta)` — продвигает таймеры, эмитит expired/killed.

**Урон от метки:** в `tick`, когда таймер истёк, эмитится `enemy_killed`, и `game_controller` вызывает визуальную смерть (`enemy.start_death`).

---

## 4. Применение модификаторов в EnemyBase

`_get_modified_speed()`:
```
speed = move_speed
if is_enraged: speed *= (1 + RAGE_SPEED_BONUS)
if is_marked:  speed *= (1 - MARK_SLOW)
```

Модификаторы перемножаются, не складываются. Marked + enraged = `1.25 × 0.75 = 0.94×` базовой скорости (почти стандарт).

`apply_mark / apply_rage` методы EnemyBase меняют материал/визуал; их вызывает `game_controller` по сигналам CombatLogic.

---

## 5. Мост логика ↔ визуал

```
ZoneObject (Area3D) — body_entered(EnemyBase)
    │
    ▼
GameController — читает enemy.element, вызывает CombatLogic.try_apply_*
    │
    ▼
CombatLogic — таймеры, сигналы (mark_expired/killed/rage_*)
    │
    ▼
GameController — реагирует на сигналы:
    enemy.apply_mark()/remove_mark()/start_death()
    HUD update
```

---

## 6. Edge-кейсы

- ✅ **Враг убит до окончания метки** — `enemy_killed` НЕ эмитится повторно (проверка `is_dead`).
- ⚠️ **Враг убит зоной во время ярости** — ярость снимается на `enemy_killed`, тайминг сигналов согласован.
- ❓ **Бомба добивает маркированного врага** — пока невозможно: бомба бьёт только игрока (friendly fire off, см. `PROJECTILES.md`). Маркированных врагов убивает только метка.

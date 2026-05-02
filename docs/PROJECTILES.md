# PROJECTILES — снаряды врагов

Файлы: `src/enemies/projectiles/arrow.gd`, `src/enemies/projectiles/bomb.gd`.

Спавнятся из соответствующих архетипов (`RangedEnemy.execute_attack` / `BomberEnemy.execute_attack`). Урон обрабатывают сами — `EnemyBase.attacked_player` сигнал не используется.

**Friendly fire выключен**: снаряды проверяют идентичность с `_player_ref` и ни при каких условиях не бьют других врагов.

---

## 1. Arrow (стрела)

`Area3D` + дочерний `MeshInstance3D` (capsule).

| Параметр | Значение |
|---|---|
| Скорость | 12 м/с |
| Урон | 1 |
| Lifetime fallback | 3с |
| `collision_mask` | 1 (стены + игрок) |
| `collision_layer` | 0 |

**Полёт:** прямолинейный, `position += velocity × delta` каждый кадр. `look_at` направления выставляется на `launch()`.

**Поведение по `body_entered`:**
- `body == _player_ref` → `take_damage(1)` → `queue_free`.
- Любой другой body на слое 1 (стена, камень) → `queue_free` без урона.
- Других врагов на слое 2 — не задевает (mask=1).

**Спавн** (из `RangedEnemy`):
- Позиция = `enemy + Vector3(0, 0.8, 0) + dir × 0.5` — смещение вперёд, чтобы не родиться внутри своего коллайдера.
- `element_color` копируется из стихии врага → emission стрелы окрашивается.

**Edge-кейс:** если ranged загнан в стену сзади — стрела не задевает свою стену (полёт вперёд). Если игрок встал прямо на ствол — стрела пролетит сквозь точку спавна, попадёт в первую же стену.

---

## 2. Bomb (бомба)

`Node3D` + дочерний `MeshInstance3D` (sphere) + ground-индикатор (плоскость с шейдером).

**Три фазы:**

### Phase.FLY (0.8с)

Параболическая дуга:
```
t = elapsed / FLIGHT_TIME (0.8с)
position.x,z = start.lerp(target, t)
position.y = target.y + sin(t × π) × ARC_HEIGHT (1.5м)
```

В этой фазе **нет коллизий** с геометрией (бомба `Node3D`, не Area). Пролетает через стены — это by design.

Кручение для эффекта: `_bomb_mesh.rotation` инкрементится каждый кадр.

### Phase.WAIT (0.7с)

Бомба на земле в `target_pos`. Появляется круг-индикатор взрыва на земле (плоскость с пульсирующим шейдером, цвет = стихия). Бомба пульсирует эмиссией.

**`_show_indicator()` важно:** `set_as_top_level(true)` и `global_position` ставятся **только после** `add_child(_indicator)`. Иначе ошибка `!is_inside_tree()`.

### Phase.DONE (взрыв)

Урон по проверке расстояния: если `_player_ref.global_position` (плоское XZ) ближе `EXPLOSION_RADIUS = 1.2м` к бомбе → `take_damage(1)`. `queue_free`.

**Других врагов взрыв не задевает** — проверяется только player_ref.

---

## 3. Параметры (константы)

```gdscript
# arrow.gd
const SPEED: float = 12.0
const LIFETIME: float = 3.0
const DAMAGE: int = 1

# bomb.gd
const FLIGHT_TIME: float = 0.8
const ARC_HEIGHT: float = 1.5
const WAIT_TIME: float = 0.7
const EXPLOSION_RADIUS: float = 1.2
const DAMAGE: int = 1
```

Если потребуется балансить — править здесь. Класс врага параметры не меняет (на текущем этапе).

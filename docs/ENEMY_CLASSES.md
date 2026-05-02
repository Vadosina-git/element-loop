# ENEMY_CLASSES — классы врагов

Класс врага задаёт **поведение в бою** (атака, дистанция, кайт). Класс **ортогонален стихии** — любая стихия может быть любого класса (Fire-bomber, Water-ranged и т.д.). Стихия → цвет/иконка/контр; класс → ATK-логика.

Файлы:
- `src/enemies/enemy_base.gd` — виртуалы.
- `src/enemies/archetypes/melee_enemy.gd` + `.tscn`
- `src/enemies/archetypes/ranged_enemy.gd` + `.tscn`
- `src/enemies/archetypes/bomber_enemy.gd` + `.tscn`

---

## 1. Виртуальные хуки на `EnemyBase`

Подклассы переопределяют поведение через эти методы. Дефолты — пустые/нейтральные.

| Метод | Дефолт | Назначение |
|---|---|---|
| `get_telegraph_duration() -> float` | `0.3` | Длительность фазы подготовки (присед / прицел / замах). |
| `get_attack_duration() -> float` | `0.4` | Длительность фазы выполнения. |
| `get_attack_engagement_range() -> float` | `1.5` | Макс. дистанция, при которой враг начинает атаку. |
| `get_attack_min_range() -> float` | `0.0` | Мин. дистанция (для ranged — комфорт). |
| `get_chase_position() -> Vector3` | позиция игрока + дуга | Куда идти в CHASE. |
| `prepare_attack()` | пусто | Снимок цели/направления на момент TELEGRAPH. |
| `execute_attack()` | пусто | Запуск (leap-velocity / спавн снаряда). |
| `resolve_attack_landing()` | пусто | Урон на конце ATTACK (только melee). |
| `_animate_attack(delta) -> float` | лёгкий наклон | Анимация TELEGRAPH/ATTACK; возвращает label_bounce. |
| `_draw_class_debug(imesh)` | пусто | Класс-специфичная отладочная отрисовка. |

Поле `_attack_velocity: Vector3` — задаётся в `execute_attack`, читается базой в `_physics_process`.

---

## 2. MeleeEnemy

**Файл:** `src/enemies/archetypes/melee_enemy.gd`.

Подходит вплотную, приседает, прыгает по дуге к снимку позиции игрока.

| Параметр | Значение |
|---|---|
| `move_speed` | 1.5 |
| Telegraph | 0.3с (присед — squash) |
| Attack | 0.4с (полёт по параболе, hop 0.7м) |
| Engagement range | `detection_range / 3` ≈ 1.67м |
| Min range | 0 |

**Логика:**
- `prepare_attack`: считает `_leap_velocity` так, чтобы за 0.4с долететь до точки `игрок + 0.2м` по направлению. Фиксирует `_leap_landing_pos` (абсолютная точка).
- `execute_attack`: копирует `_leap_velocity` в `_attack_velocity` → база летит.
- `resolve_attack_landing`: урон, если игрок в `attack_range × LANDING_HIT_FACTOR (1.3)` от **зафиксированной** точки приземления. Это совпадает с debug-меткой: «видишь круг — отбегай за его край».

**Edge-кейс:** если враг по пути врезался в стену — урон всё равно засчитан, если игрок остался в круге. Метка детерминирована (видишь, куда летит — успевай уворачиваться).

---

## 3. RangedEnemy

**Файл:** `src/enemies/archetypes/ranged_enemy.gd`.

Кайтит на комфортной дистанции, стреляет стрелами по линии зрения.

| Параметр | Значение |
|---|---|
| `move_speed` | 1.7 (быстрее melee — кайт) |
| Telegraph | 0.5с (натяжка лука) |
| Attack | 0.2с (выстрел) |
| Engagement range | 4.5м |
| Min range | 2.0м |

**Кайт-логика** (`get_chase_position`):
- `dist < 2.0м`: отступает строго от игрока к идеальной точке `(min + engagement) / 2 ≈ 3.25м`.
- `dist > 4.5м`: подходит к игроку (с боковой дугой).
- Между → стоит и стреляет.

**Атака:**
- `prepare_attack`: запоминает `_aim_target` = текущая позиция игрока.
- `execute_attack`: спавнит `Arrow` со смещением 0.5м вперёд от тела (чтобы не родилась внутри коллайдера). Стрела летит по фиксированному направлению, см. `PROJECTILES.md`.

---

## 4. BomberEnemy

**Файл:** `src/enemies/archetypes/bomber_enemy.gd`.

Бросает бомбу по баллистической дуге в текущую точку игрока. Бомба взрывается через 0.7с после приземления — у игрока есть окно реакции.

| Параметр | Значение |
|---|---|
| `move_speed` | 1.2 (медленнее) |
| Telegraph | 0.6с (замах) |
| Attack | 0.3с (бросок) |
| Engagement range | 5.0м |
| Min range | 1.5м |

**Кайт:** аналогичен ranged, идеальная точка ≈ 3.25м.

**Атака:**
- `prepare_attack`: запоминает `_bomb_target` = позиция игрока на момент замаха.
- `execute_attack`: спавнит `Bomb` (см. `PROJECTILES.md`) с параметрами `start = self+0.6 по Y`, `target = _bomb_target`.

**By design:** бомба пролетает сквозь стены в фазе полёта (нет коллизии с геометрией). Гранату «бросают через препятствие». Если потом нужно блокировать — отдельная задача.

---

## 5. Спавн микса в комнате

`game_controller.gd`:
```
const ROOM_COMPOSITION: Array[String] = [
    MELEE_ENEMY_SCENE,
    RANGED_ENEMY_SCENE,
    MELEE_ENEMY_SCENE,
    BOMBER_ENEMY_SCENE,
    RANGED_ENEMY_SCENE,
]
```

В `_spawn_enemies` сцена выбирается по индексу. Стихия — round-robin из 5. Все три класса наследуют `EnemyBase`, поэтому сигналы `attacked_player` / `died` подключаются единообразно.

**Будущее:** эскалация по уровню (lvl1→lvl3) пока не меняет класс — он фиксируется при спавне. Вопрос «Bomber-lvl3 vs Melee-lvl3» — открыт.

---

## 6. Friendly fire

**Отключён** для всех снарядов. Стрелы и бомбы проверяют только идентификатор игрока (`body == _player_ref`). Других врагов снаряды не задевают (см. `PROJECTILES.md`).

Дизайн-причина: иначе эскалация ломается (враги бы убивали друг друга), и игрок мог бы тривиально выманивать bomber'а в melee для саморазрыва.

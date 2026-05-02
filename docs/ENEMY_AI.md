# ENEMY_AI — FSM, восприятие, навигация

Описывает поведение `EnemyBase` + `EnemyAI`. Этот документ — про **общую логику**, одинаковую для всех классов. Специфика классов (Melee/Ranged/Bomber) — в `ENEMY_CLASSES.md`.

Файлы: `src/enemies/enemy_base.gd`, `src/enemies/enemy_ai.gd`.

---

## 1. FSM состояний

```
WANDER ──(player виден в зоне)──► CHASE ──(дист в окне атаки + LoS)──► TELEGRAPH
   ▲                                │                                    │
   │                                │                                    ▼
   │                              SEARCH ◄─(LoS потерян, есть крошки)── ATTACK
   │                                │                                    │
   └───────(крошки кончились / таймаут 4с / коаст 1с)─── RECOVER ◄───────┘
```

| Состояние | Поведение |
|---|---|
| `WANDER` | Случайные точки в радиусе 4м, скорость = `move_speed × 0.3`. Между точками ждёт 0.5–2с. |
| `CHASE` | Идёт к `get_chase_position()` (виртуал класса). Каждые 0.2с проверяет LoS. |
| `SEARCH` | Идёт к последней крошке. На переходе LoS возвращён → CHASE. Таймаут 4с → WANDER. |
| `TELEGRAPH` | Стоит. Подготовка атаки (виртуал `prepare_attack`). Длительность из `get_telegraph_duration()`. |
| `ATTACK` | Движение из `_attack_velocity` (melee=leap, ranged/bomber=0). Длительность из `get_attack_duration()`. |
| `RECOVER` | Стоит 1с. Затем CHASE (если игрок в зоне) или WANDER. |

**Гейты переходов:**
- WANDER → CHASE: `player_in_range AND has_los` (Area3D + raycast).
- CHASE → TELEGRAPH: `dist >= attack_min_range AND dist <= attack_engagement_range AND has_los`. **Атака сквозь стену запрещена.**
- CHASE → SEARCH: `not player_in_range OR not has_los`, при наличии крошек.
- SEARCH → CHASE: `player_in_range AND has_los` (повторно увидел).

---

## 2. Line of Sight (LoS)

`has_line_of_sight_to(target)` пускает рейкаст с высоты 0.8м от обоих участников по `collision_mask = 1` (стены, камни, игрок), исключая самого врага и target. Любое попадание = блок.

**Когда считается:**
- В WANDER: только если `player_in_range == true` (из Area3D-триггера).
- В CHASE/SEARCH: каждые `LOS_CHECK_INTERVAL = 0.2с`.
- **Стаггеринг**: на `_ready` фаза `_los_timer` рандомизируется `randf() * 0.2`, чтобы 100 врагов не пускали лучи в один кадр.

**Подсказка для отладки:** клавиша **K** (см. `DEBUG_VISUAL.md`).

---

## 3. Detection Area3D (event-driven)

Каждый враг создаёт child-узел `Area3D` с `SphereShape3D` радиусом = `detection_range` (5м по умолчанию). `collision_mask = 1`, `monitoring = true`.

`body_entered` / `body_exited` ставят флаг `player_in_range`. Фильтр: `body == _target` (игнорим стены/камни на том же слое).

**Зачем:** заменяет per-frame distance polling. При 100 врагах — нет накладных. Дальние враги вообще не считают LoS.

**Edge-case:** `set_target` вызывается после `_ready`. Если игрок уже внутри Area3D — `body_entered` не сработает задним числом, поэтому `set_target` делает `get_overlapping_bodies()` и выставляет флаг вручную.

---

## 4. Хлебные крошки (breadcrumbs)

Когда `CHASE` и есть LoS — каждые `BREADCRUMB_INTERVAL = 0.3с` дописывается позиция игрока в `_breadcrumbs` (макс 8, FIFO). Дубли ближе 0.4м не пишутся.

При потере LoS / выходе из радиуса → SEARCH с целью = последняя крошка. Если игрок не появился до достижения крошки → WANDER. Таймаут SEARCH = 4с.

При выходе из CHASE/SEARCH в любую невыслеживающую ветку (например, после WANDER через коаст) — крошки очищаются.

---

## 5. Навигация

`NavigationAgent3D` + кеш направления раз в 0.3с.

Цель в `_physics_process`:
- `SEARCH` → `investigation_target` (последняя крошка).
- Остальные агрессивные → `get_chase_position()` (виртуал класса, по умолчанию — позиция игрока + дуга).

**Оптимизация «стою на месте»**: если расстояние от врага до цели < 0.3м (например, ranged в кайт-зоне) — NavAgent не дёргается, `_cached_move_dir = ZERO`. Иначе агент сразу финиширует и фолбэк зашумлял лог.

**Фолбэк** (нав-меш не покрывает зону): прямое движение к цели, без warning-спама.

---

## 6. Боковая дуга преследования

Чтобы враги не сходились в одну точку игрока, базовый `get_chase_position()` добавляет к цели **перпендикулярное** смещение:

```
offset = sin(t × _arc_freq + _arc_phase) × _arc_amplitude
```

- `_arc_phase` ∈ [0, 2π) — рандом на враге в `_ready`.
- `_arc_freq` ∈ [0.4, 0.8] рад/с.
- `_arc_amplitude` ∈ [0.35, 0.7] м.
- **Затухание у цели**: на дистанции <0.8м offset = 0; от 0.8 до 2.5м линейно нарастает до полного. Враг точно подходит к игроку, не кружит.

Применяется:
- **Melee**: всегда (через дефолт).
- **Ranged/Bomber**: только при подходе (`d > engagement_range`); в кайт-зоне они стоят, дуга не нужна.

---

## 7. Коаст-переход в WANDER

При выходе из любой агрессивной фазы (CHASE/SEARCH/TELEGRAPH/ATTACK/RECOVER) в WANDER:
1. AI ставит `_wander_waiting = true` на 1с — новое направление патруля **не назначается**.
2. EnemyBase в WANDER при пустом `wander_direction` лерпит velocity к нулю (коэф. 4/сек).
3. `look_at` не вызывается — поворот сохраняется из последнего активного состояния.

Эффект: враг едет по инерции ~0.5–0.7с в том же направлении, плавно тормозит, через секунду начинает обычный патруль. Без резких разворотов.

---

## 8. Edge-кейсы и решения

- **Стрельба сквозь стену** — гейтится `_has_los` на переходе CHASE → TELEGRAPH.
- **Игрок появляется уже за стеной** — `player_in_range = true` через Area3D, но LoS = false → WANDER не переключится в CHASE (правильно).
- **Игрок проходит через Area3D, не выходя из неё** — `player_in_range` остаётся true; за событийную модель не платим повторными projvercheckами.
- **Множественные крошки** — сейчас цель всегда последняя (самая свежая). Старые не используются для retracing — это by design (retrace бессмысленен без новой информации).
- **Враги стакаются на игроке** — устранено боковой дугой (см. §6).

# PLAYER — игрок: движение, рывок, персонажи, ввод

Файлы:
- `src/player/player_character.gd` (757 строк) — `CharacterBody3D`, ядро персонажа.
- `src/player/player_input.gd` — обработка ввода (клавиатура, тач, джойстик).

---

## 1. Параметры (константы PlayerCharacter)

| Параметр | Значение |
|---|---|
| `MAX_HP` | 2 |
| `MOVE_SPEED` | 3.33 |
| `ACCELERATION` / `DECELERATION` | 15 / 10 (lerp velocity) |
| `ROTATION_SPEED` | 12 (плавный look_at) |
| `DASH_DISTANCE` | 3.0м |
| `DASH_DURATION` | 0.25с |
| `DASH_JUMP_HEIGHT` | 0.5м (арка вверх во время рывка) |
| `DASH_COOLDOWN` | 5.0с |
| `PLACE_ZONE_DURATION` | 0.4с (анимация постановки) |
| `JOKE_DURATION` | 1.5с (бабл с фразой при провале) |

Слотов: 1 заряд зоны, 1 слот способности (по дизайн-доку, способности пока не реализованы).

---

## 2. Сигналы

```
hp_changed(new_hp)
element_changed(new_element)
zone_placed(element, position)
died()
character_changed(char_name)
dash_cooldown_changed(remaining, total)
dash_started()
```

`game_controller` подписывается на zone_placed → создаёт `ZoneObject` через `_combat_logic`/HUD.

---

## 3. Движение

- `velocity` лерпится к целевой `(direction × MOVE_SPEED)` с разными коэффициентами на разгон/торможение (инерция).
- `look_at` тоже плавный (через `ROTATION_SPEED`).
- Цель направления приходит из `set_move_direction()` (вызывает `PlayerInput`).

**Рывок (`try_dash`)** — Shift или кнопка:
- Velocity-based (не teleport): задаёт `velocity = forward × dash_speed`, длится `DASH_DURATION`.
- Дугой по Y через `_dash_jump_progress`.
- Может получить урон во время рывка — рывок не делает неуязвимым.
- Частицы дыма (`GPUParticles3D`) во время рывка.
- Кулдаун 5с, прогресс эмитится в `dash_cooldown_changed` для UI.

---

## 4. Слот стихии

`pickup_element(element)` — берёт стихию из книги. Заполняет 1 слот.
`place_zone()` — тратит слот, эмитит `zone_placed`. Если слот пуст:
- `play_fail_joke()` — прыжок + случайная фраза из `FAIL_JOKES` (20 вариантов).

`element_changed(0)` после `place_zone` — слот опустел (0 — не стихия, а «нет»).

---

## 5. Персонажи (KayKit)

8 персонажей в `assets/kaykit_skeletons/` — массив `CHARACTERS` с метаданными.

API:
- `next_character()` / `prev_character()` — переключение через `< >` в HUD.
- `_reload_character()` загружает GLB, скрывает оружие (`_hide_equipment`), поворачивает модель на `PI` (KayKit смотрит назад в Godot).

**Анимации** (95 в каждом GLB): `Walking_A`, `Unarmed_Idle`, `Jump_Full_Short`, `Jump_Land`, `Cheer`. Управляются через `_animation_player`.

**Победный танец** (`start_victory_dance`) — Cheer + вращение, вызывается на смерти последнего врага.

---

## 6. Кольцо стихии (3D)

Над персонажем парит **тор из 4 дуг** (SurfaceTool). Каждая дуга — 90° минус 30° зазор = 60° визуально.

- `_setup_element_ring`, `_create_arc_segment`.
- Цвет = стихия игрока (через `ElementIcons.get_color`).
- Заглушки на тон темнее основного — на торцах сегментов.
- Вращается 2.5 рад/сек, `top_level = true`.
- Появляется при наличии заряда, скрывается при `place_zone`.

---

## 7. Индикатор под ногами

Brawl Stars стиль: неоновое кольцо + шестиконечная звезда (шейдер).

- Y = 0.25 (выше декора пола Trapdoor.glb на Y=0).
- Цвет — стихия.
- Меш — `Plane`, шейдер обрабатывает форму.

---

## 8. Урон и смерть

`take_damage(amount)`:
- HP -= amount, эмит `hp_changed`.
- Анимация `_animate_damage_flash` (0.6с моргания через alpha).
- Если HP <= 0: `_die()` → `died.emit()` + блокировка ввода.

`heal(amount)` симметрично, до `MAX_HP`.

---

## 9. PlayerInput

Файл: `src/player/player_input.gd`.

**Клавиатура:** WASD/стрелки (движение), Space (зона), Shift (рывок), R (рестарт), L (панель освещения), K (debug визуализация врагов).

Поддержка `physical_keycode` через `InputEventKey.physical_keycode` — на нелатинских раскладках в браузере.

**Тач (mobile):**
- Tap-to-move (правая половина экрана, raycast камеры в Y=0).
- Виртуальный джойстик (левая половина, появляется при касании).

**Приоритет ввода:** клавиатура > джойстик > tap-to-move. Движение от первого активного источника.

---

## 10. Edge-кейсы

- ✅ Игрок жмёт Space без стихии → шутка-прыжок, без эмита `zone_placed`.
- ✅ Игрок умирает во время рывка → анимация урона запускается, рывок отменяется.
- ✅ Переключение персонажа во время боя → анимация подхватывается на следующем кадре, действия не теряются.
- ⚠️ Двойной dash (быстрое нажатие) → второе игнорится через `is_dash_on_cooldown()`.
- ⚠️ Тап и одновременно WASD → клавиатура побеждает (приоритет в PlayerInput).

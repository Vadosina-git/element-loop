# Changelog — ветка master

Хронология всех изменений, закоммиченных в master.

---

## Ядро боя (combat core)

- **ElementTable** — таблица 5 стихий (Fire, Water, Tree, Earth, Metal) и контров. Юнит-тесты GUT.
- **ZoneLogic** — логика зон: контр/своя/нейтральная, FIFO (лимит 2, третья удаляет первую). Тесты.
- **CombatLogic** — метки (3 сек → 1 HP урона, замедление 25%), ярость (+25% скорость/темп, 4 сек). Метка и ярость работают параллельно. Тесты.

## Арена

- **ArenaView** — процедурная арена 36x24. Пол из KayKit Floor_Dirt.obj (тёплый материал #3D2E1F, случайный поворот тайлов). 4 стены из Primitive_Wall.
- **MazeGenerator** — каменный лабиринт: гряды 1–12 ячеек, MIN_GAP=2, SAFE_ZONE вокруг центра. Короткие гряды (1–2 ячейки) ограничены 15% от общего числа (SHORT_RIDGE_MAX_RATIO). Используют Pallet_Small_Decorated (короткие) и Cube_Prototype_Large (длинные).
- **NavigationRegion3D** — навмеш бейкается с невидимым BoxMesh-полом + копии коллайдеров камней для вырезов. cell_size=0.5, agent_radius=0.4.
- **Декор пола** — Trapdoor.glb размещается на свободных тайлах (0.1% шанс). Без коллайдера, без бликов (metallic=0, roughness=1). Чисто декоративный.

## Игрок (PlayerCharacter)

- **CharacterBody3D** с капсулой (0.3×1.2). HP=2, 1 слот зоны, 1 слот способности.
- **Движение** — инерция (ACCELERATION=15, DECELERATION=10, lerp velocity), плавный поворот (ROTATION_SPEED=12).
- **Рывок (Shift)** — velocity-based, кулдаун 5 сек, частицы дыма (GPUParticles3D), может получить урон.
- **8 персонажей KayKit** — переключение через `< >` кнопки. Анимации: Walking_A, Unarmed_Idle, Jump_Full_Short, Jump_Land, Cheer. Скрытие оружия (_hide_equipment).
- **Шутки** — при попытке поставить зону без стихии: прыжок + бабл с случайной фразой (20 вариантов).
- **Победный танец** — Cheer + вращение.
- **Кольцо стихии** — 3D dashed тор из 4 дуг (SurfaceTool), зазор 30° между сегментами. Заглушки (caps) на тон темнее основного цвета. Вращается (2.5 рад/сек), следует за игроком (top_level). Цвет по стихии, появляется при наличии заряда.
- **Индикатор под ногами** — Brawl Stars style: неоновое кольцо + шестиконечная звезда (шейдер). Y=0.25 (выше декора пола).
- **Мигание при уроне** — blink 0.6 сек.

## Враги (EnemyBase)

- **CharacterBody3D + NavigationAgent3D**. FSM: Chase → Telegraph → Attack → Recover.
- **Навигация** — кешированное направление (обновление каждые 0.3 сек), lerp пропорционально скорости, fallback на прямое движение.
- **Зона детекции** — Brawl Stars стиль: неоновая линия (Sobel-like sharp_line) + базовая заливка + пульсирующие волны от центра. Шейдер. Y=0.25.
- **Пульсирующий круг** — подсветка уязвимости (контр-стихия), появляется когда у игрока есть нужная стихия. Y=0.3.
- **Анимация смерти** — взрыв с частицами.
- **Анимация агонии** — при метке.
- **5 стихий** — уникальные цвета. Иконка стихии (Sprite3D) над головой.

## Управление (PlayerInput)

- **Клавиатура** — WASD/стрелки (движение), Space (зона), Shift (рывок), R (рестарт), L (панель освещения). Поддержка physical_keycode для работы в браузере на нелатинских раскладках.
- **Тач** — tap-to-move (правая половина экрана, raycast к Y=0), виртуальный джойстик (левая половина).
- **Приоритет** — клавиатура > джойстик > tap-to-move.

## Книги (BookObject)

- **3 книги на арене**. Модель Spellbook.glb, парит + вращается.
- **Активация** — удержание 1 сек (Area3D enter → auto start_hold). Круговой лоадер (шейдер).
- **Рулетка стихий** — 2 варианта из контров живых врагов + кнопка отказа. Клавиши A/D/Esc. Работает на паузе (PROCESS_MODE_ALWAYS).
- **Респаун** — после использования исчезает, появляется через 2 сек в новой безопасной точке (NavigationServer3D.map_get_random_point).

## Зоны (ZoneObject)

- **Area3D** с цилиндрическим коллайдером. Радиус 0.8.
- **Лимит** — 2 активных (FIFO). Не исчезают по таймеру.
- **Earth-зоны** — добавляют NavigationObstacle3D для обхода врагами.

## GameController (оркестратор)

- Создаёт 5 врагов (все разных стихий), 3 книги.
- Связывает PlayerInput, PlayerCharacter, ArenaView, HUD, ElementPicker, OutlineManager, PostProcessing.
- Навмеш навигация для врагов после спавна.
- R = рестарт, L = панель освещения.

## HUD

- HP (сердечки PNG), текущая стихия (иконка), кнопка зоны, кнопка рывка с индикатором кулдауна.
- Переключатель персонажей (`< имя >`).
- Кнопка рестарта.
- Автомасштабирование (stretch canvas_items).

## Визуальная стилизация

- **Cozy Grove style** — тёплое освещение (main #FFE8C8 + fill #B0C0E0), SSAO 1.5, glow 0.3, filmic tone mapping, тёплый туман.
- **Пост-обработка** (post_processing.gd) — CanvasLayer: blur vignette, desaturation, warm shift, contrast, vignette. Экранный outline (Sobel, toggleable).
- **OutlineManager** — per-object inverted hull через next_pass. Категории: Персонаж, Враги, Камни, Книги. Настройки через панель освещения.
- **Панель освещения** (L) — 5 пресетов (Cozy Grove, Осень, Вечер, Рассвет, Brawl Stars). Слайдеры для всех параметров.
- **Пресеты камеры** — Стандарт (48°/16/45), Ближняя, Top-Down, Изометрия.

## Иконки (ElementIcons)

- PNG 160×160 из Apple Color Emoji (assets/icons/).
- `get_texture(element)`, `get_heart_texture()`, `get_book_texture()`, `get_alert_texture()`.
- Используются через Sprite3D (3D) и TextureRect (UI).

## CI/CD

- **GitHub Actions** (deploy-web.yml) — автосборка Web-экспорта + деплой на GitHub Pages при пуше в master.
- Контейнер barichello/godot-ci:4.6.1.
- coi-serviceworker для SharedArrayBuffer.

## Исправления

- NavMesh 0 полигонов → BoxMesh как child NavigationRegion3D.
- Враги замерзали → fix Y высоты в NavigationAgent.
- Враги вибрировали → кеширование направления каждые 0.3 сек.
- Эмодзи не рендерились на вебе → PNG иконки.
- Пост-обработка поверх HUD → CanvasLayer layer=0.
- Игрок шёл задом → rotation.y = PI на модели.
- Outline делал игрока белым → клонирование surface materials.
- Клавиши не работали в браузере → physical_keycode как фоллбек.

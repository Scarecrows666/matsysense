local M = {}

M.Services = {
    P = game:GetService("Players"),
    R = game:GetService("RunService"),
    U = game:GetService("UserInputService"),
    T = game:GetService("TweenService"),
    L = game:GetService("Lighting"),
    D = game:GetService("Debris"),
    S = game:GetService("Stats"),
    I = game:GetService("InsertService"),
    C = game:GetService("ContentProvider"),
    H = game:GetService("HttpService")
}

M.LP = M.Services.P.LocalPlayer
if not M.LP then
    M.Services.P:GetPropertyChangedSignal("LocalPlayer"):Wait()
    M.LP = M.Services.P.LocalPlayer
end

-- Иерархия изоляции: gethui -> CoreGui -> PlayerGui
local function getIsolatedContainer()
    local okHui, hui = pcall(function()
        if typeof(gethui) == "function" then
            return gethui()
        end
    end)
    if okHui and hui then
        return hui
    end

    -- 2. Системный CoreGui
    local okCore, core = pcall(function()
        return game:GetService("CoreGui")
    end)
    if okCore and core then
        return core
    end

    -- 3. Резервный PlayerGui (для Roblox Studio)
    return M.LP:WaitForChild("PlayerGui")
end

M.TargetGui = getIsolatedContainer()

M.RayParams = RaycastParams.new()
M.RayParams.FilterType = Enum.RaycastFilterType.Exclude
M.RayParams.IgnoreWater = true

-- Запасные параметры, чтобы не создавать RaycastParams заново на каждый луч
M.ScratchParams = RaycastParams.new()
M.ScratchParams.FilterType = Enum.RaycastFilterType.Exclude
M.ScratchParams.IgnoreWater = true

-- Старая очистка по имени ("найти и удалить всё, что начинается с Matsysense") убрана: при повторном запуске
-- скрипта (например, другим исполнителем) прежние объекты этого скрипта просто остаются в игре невидимыми и
-- неактивными, вместо того чтобы искать и удалять чужую разметку по совпадению имени.

M.L10N = {
    Current = "RU",
    Dict = {
        Tab_Combat = {RU = "Бой", EN = "Combat"},
        Tab_Movement = {RU = "Движение", EN = "Movement"},
        Tab_Camera = {RU = "Камера", EN = "Camera"},
        Tab_Display = {RU = "Отображение", EN = "Display"},
        Tab_World = {RU = "Окружение", EN = "World"},
        Tab_Player = {RU = "Персонаж", EN = "Character"},
        Tab_Misc = {RU = "Разное", EN = "Misc"},
        Tab_System = {RU = "Система", EN = "System"},
        Tab_Configs = {RU = "Конфиги", EN = "Configs"},
        Tab_Settings = {RU = "Настройки", EN = "Settings"},

        Sec_AimAssist = {RU = "Помощь в прицеливании", EN = "Aim Assist"},
        Sec_TriggerAssist = {RU = "Автоматический выстрел", EN = "Auto Fire"},
        Sec_Movement = {RU = "Скорость и полет", EN = "Speed & Flight"},
        Sec_Defense = {RU = "Защита персонажа", EN = "Character Protection"},
        Sec_CameraMain = {RU = "Управление камерой", EN = "Camera Control"},
        Sec_PlayerViewBase = {RU = "Видимость игроков", EN = "Player Visibility"},
        Sec_PlayerViewBoxes = {RU = "Настройки рамок", EN = "Box Settings"},
        Sec_PlayerViewHealth = {RU = "Шкала здоровья", EN = "Health Bar"},
        Sec_PlayerViewLines = {RU = "Линии до игроков", EN = "Player Lines"},
        Sec_WorldFog = {RU = "Настройка тумана", EN = "Fog Settings"},
        Sec_WorldClouds = {RU = "Настройка облаков", EN = "Cloud Settings"},
        Sec_WorldWeather = {RU = "Эффекты погоды", EN = "Weather Effects"},
        Sec_WorldEffects = {RU = "Дополнительные эффекты", EN = "Additional Effects"},
        Sec_PlyrModel = {RU = "Внешний вид модели", EN = "Model Appearance"},
        Sec_PlyrJump = {RU = "Следы от прыжка", EN = "Jump Trails"},
        Sec_PlyrAccessories = {RU = "Сферы вокруг тела", EN = "Body Spheres"},
        Sec_SilhouetteMod = {RU = "Поза персонажа", EN = "Character Pose"},
        Sec_Performance = {RU = "Оптимизация текстур", EN = "Texture Optimization"},
        Sec_Framerate = {RU = "Частота кадров", EN = "Framerate"},
        Sec_UiTheme = {RU = "Оформление меню", EN = "Main UI Appearance"},
        Sec_UiSidebar = {RU = "Боковая панель", EN = "Sidebar Styling"},
        Sec_UiPill = {RU = "Информационная панель", EN = "Info Panel"},

        AimAssist = {RU = "Включить наводку прицела", EN = "Enable Aiming"},
        AimTeamCheck = {RU = "Не наводить на своих", EN = "Ignore Teammates"},
        AimFov = {RU = "Радиус захвата экрана", EN = "Screen Capture Radius"},
        ShowFov = {RU = "Показывать зону захвата", EN = "Show Capture Zone"},
        AimTime = {RU = "Время доводки (0 = сразу)", EN = "Aim Time (0 = instant)"},
        AimWallCheck = {RU = "Не наводить через стены", EN = "Ignore Through Walls"},

        TriggerAssist = {RU = "Стрелять при наведении", EN = "Fire on Target"},
        TriggerTeamCheck = {RU = "Не стрелять по своим", EN = "Ignore Teammates"},
        TriggerLoop = {RU = "Стрелять непрерывно", EN = "Continuous Fire"},
        TriggerDelay = {RU = "Задержка перед выстрелом", EN = "Fire Delay"},
        TriggerWallCheck = {RU = "Не стрелять через стены", EN = "Check Obstacles"},

        FlightMode = {RU = "Режим полета", EN = "Flight Mode"},
        KnockbackProtection = {RU = "Гасить сильные толчки", EN = "Reduce Strong Knockback"},
        SprintBoost = {RU = "Ускорение бега", EN = "Sprint Boost"},
        AirControl = {RU = "Управление в прыжке", EN = "Mid-air Control"},
        AirSpeed = {RU = "Скорость в воздухе", EN = "Mid-air Speed"},
        AirAccel = {RU = "Резкость маневров", EN = "Maneuver Sharpness"},

        WalkThroughWalls = {RU = "Проходить сквозь стены", EN = "Walk Through Walls"},
        InfiniteJumps = {RU = "Бесконечные прыжки", EN = "Infinite Jumps"},
        AutoJump = {RU = "Авто-прыжок (без остановок)", EN = "Auto Jump (non-stop)"},
        FallProtection = {RU = "Защита от падений", EN = "Fall Protection"},
        AntiStun = {RU = "Снимать оглушение (скорость и прыжок)", EN = "Remove Stun (speed & jump)"},
        IdleProtection = {RU = "Анти-АФК (не отключаться при бездействии)", EN = "Anti-AFK (stay connected when idle)"},

        CamFov = {RU = "Отдаленность камеры (FOV)", EN = "Field of View"},
        ThirdPerson = {RU = "Вид от 3-го лица (с фиксацией камеры)", EN = "Third Person View (Locked Camera)"},
        ThirdPersonDist = {RU = "Дистанция камеры", EN = "Camera Distance"},

        EnablePlayerView = {RU = "Подсвечивать игроков", EN = "Highlight Players"},
        PlayerViewOnSelf = {RU = "Показывать на себе", EN = "Show on Self"},
        PlayerViewTeamCheck = {RU = "Скрыть своих из видимости", EN = "Hide Teammates"},
        FillCol = {RU = "Цвет заливки тела", EN = "Fill Color"},
        LineCol = {RU = "Цвет контура (виден сквозь препятствия)", EN = "Outline Color (visible through obstacles)"},

        PlayerViewBox = {RU = "Показывать рамки игроков", EN = "Show Boxes"},
        BoxCol = {RU = "Цвет рамок", EN = "Box Color"},
        BoxThick = {RU = "Толщина линий рамок", EN = "Box Thickness"},
        FontWeight = {RU = "Стиль шрифта имен", EN = "Font Style"},
        TextSize = {RU = "Размер текста", EN = "Text Size"},
        NameCol = {RU = "Цвет имен", EN = "Name Color"},

        ShowHp = {RU = "Показывать полоску здоровья", EN = "Show Health"},
        HpPos = {RU = "Позиция полоски", EN = "Bar Position"},
        HpThick = {RU = "Толщина полоски", EN = "Bar Thickness"},
        HpText = {RU = "Показывать цифры здоровья", EN = "Health Numbers"},
        HpCol = {RU = "Цвет здоровья", EN = "Health Color"},

        PlayerViewLines = {RU = "Линии до игроков", EN = "Player Lines"},
        PlayerLineCol = {RU = "Цвет линий", EN = "Line Color"},

        WhiteFog = {RU = "Свой цветной туман", EN = "Custom Color Fog"},
        FogDense = {RU = "Плотность тумана", EN = "Fog Density"},
        FogHaze = {RU = "Дымка тумана", EN = "Fog Haze"},
        FogCol = {RU = "Цвет тумана", EN = "Fog Color"},
        TimeOfDay = {RU = "Свое время суток", EN = "Custom Time"},
        ClockTime = {RU = "Часы", EN = "Clock Time"},
        DarkWorld = {RU = "Затемнить карту", EN = "Darken World"},
        DarkIntense = {RU = "Сила затемнения", EN = "Darken Intensity"},

        CloudsOn = {RU = "Включить облака", EN = "Enable Clouds"},
        CloudDensity = {RU = "Густота облаков", EN = "Cloud Density"},
        CloudCover = {RU = "Заполнение неба (%)", EN = "Sky Coverage (%)"},
        CloudColor = {RU = "Цвет облаков", EN = "Cloud Color"},

        Sec_WorldTime = {RU = "Время суток", EN = "Time of Day"},
        Sec_WorldLight = {RU = "Освещение", EN = "Lighting"},
        Sec_WorldSky = {RU = "Свой скайбокс (небо)", EN = "Custom Skybox"},
        SkyOn = {RU = "Включить свой скайбокс", EN = "Enable Custom Skybox"},
        SkyIds = {RU = "ID скайбокса", EN = "Skybox ID"},
        SkyHideBodies = {RU = "Скрыть солнце, луну и звёзды", EN = "Hide Sun, Moon & Stars"},
        SkyPlaceholder = {
            RU = "Формат: 1234567890 или rbxassetid://1234567890\nСлово default: стандартное небо Roblox\n6 граней через запятую: Bk, Dn, Ft, Lf, Rt, Up",
            EN = "Format: 1234567890 or rbxassetid://1234567890\nThe word default: standard Roblox sky\n6 faces, comma-separated: Bk, Dn, Ft, Lf, Rt, Up"
        },
        Sky_Idle = {RU = "Введите ID картинки и нажмите Enter", EN = "Enter an image ID and press Enter"},
        Sky_Off = {RU = "Скайбокс выключен", EN = "Skybox is off"},
        Sky_Loading = {RU = "Загрузка текстур...", EN = "Loading textures..."},
        Sky_Ok1 = {RU = "Применено: один ID на все 6 граней", EN = "Applied: one ID on all 6 faces"},
        Sky_Ok6 = {RU = "Применено: 6 граней", EN = "Applied: 6 faces"},
        Sky_BadCount = {RU = "Ошибка: нужен 1 ID или 6 ID, а введено: %d", EN = "Error: need 1 or 6 IDs, got: %d"},
        Sky_BadId = {RU = "Ошибка: «%s» не похоже на ID (нужно от 5 до 19 цифр)", EN = "Error: \"%s\" is not an ID (5 to 19 digits needed)"},
        Sky_Fail = {
            RU = "Не загрузилось текстур: %d. Нужен ID именно картинки (Image), и она должна быть доступна этому месту",
            EN = "Textures failed to load: %d. Use an Image asset ID that this place is allowed to use"
        },

        Sky_Resolving = {RU = "Ищу скайбокс в магазине...", EN = "Looking up the skybox in the store..."},
        Sky_OkModel = {RU = "Применено: скайбокс из магазина", EN = "Applied: skybox from the store"},
        Sky_NoLoader = {
            RU = "Модель по ID не загрузилась: Roblox не даёт скриптам грузить чужие модели. Включите Game Settings > Security > Allow Loading Third Party Assets или впишите 6 ID картинок",
            EN = "The model could not be loaded: Roblox restricts this. Enable Game Settings > Security > Allow Loading Third Party Assets, or enter 6 image IDs"
        },
        Sky_OkBuiltin = {RU = "Применено: стандартное небо Roblox", EN = "Applied: standard Roblox sky"},
        SkyPreset1 = {RU = "Закат", EN = "Sunset"},
        SkyPreset2 = {RU = "Классич. закат", EN = "Classic Sunset"},
        SkyPreset3 = {RU = "Звёздная ночь", EN = "Starry Night"},
        SkyPreset4 = {RU = "Ночь", EN = "Night"},
        SkyPreset5 = {RU = "Roblox 2016", EN = "Roblox 2016"},
        SkyPreset6 = {RU = "Закат 2010", EN = "Sunset 2010"},
        SkyPreset7 = {RU = "Пастель", EN = "Pastel"},
        SkyPreset8 = {RU = "Стандартное", EN = "Standard"},

        Sec_WorldRays = {RU = "Лучи солнца и луны", EN = "Sun & Moon Rays"},
        Sec_Zoom = {RU = "Приближение", EN = "Zoom"},
        Sec_Cinema = {RU = "Кинематографичные эффекты", EN = "Cinematic Effects"},
        Sec_Grade = {RU = "Цветокоррекция", EN = "Color Grading"},
        Sec_UiGlass = {RU = "Жидкое стекло", EN = "Liquid Glass"},
        Sec_UiNotify = {RU = "Уведомления", EN = "Notifications"},

        FovOn = {RU = "Использовать свой FOV", EN = "Use Custom FOV"},
        ZoomOn = {RU = "Приближение (держать Z)", EN = "Zoom (hold Z)"},
        ZoomFov = {RU = "Угол при приближении", EN = "Zoom Angle"},
        ZoomSpeed = {RU = "Скорость приближения", EN = "Zoom Speed"},
        GradeOn = {RU = "Включить цветокоррекцию", EN = "Enable Color Grading"},
        GradePreset = {RU = "Готовый стиль", EN = "Preset"},
        GradeSat = {RU = "Насыщенность", EN = "Saturation"},
        GradeContrast = {RU = "Контраст", EN = "Contrast"},
        GradeBright = {RU = "Яркость", EN = "Brightness"},
        GradeTint = {RU = "Оттенок картинки", EN = "Image Tint"},
        TimeCycle = {RU = "Смена дня и ночи", EN = "Day-Night Cycle"},
        TimeCycleSpeed = {RU = "Скорость (часов в минуту)", EN = "Speed (hours per minute)"},
        SunRaysOn = {RU = "Лучи света (как в RTX)", EN = "Light Rays (RTX style)"},
        SunRaysIntensity = {RU = "Интенсивность лучей", EN = "Ray Intensity"},
        SunRaysSpread = {RU = "Длина лучей", EN = "Ray Length"},
        SunRaysBright = {RU = "Яркость свечения", EN = "Glow Brightness"},
        LightningFlash = {RU = "Вспышка экрана при молнии", EN = "Screen Flash on Lightning"},
        LightningFlashPower = {RU = "Сила вспышки", EN = "Flash Power"},
        MeteorImpact = {RU = "Взрыв при падении метеорита", EN = "Meteor Impact Blast"},
        AimPart = {RU = "Куда целиться", EN = "Aim At"},
        TriggerMethod = {RU = "Способ выстрела", EN = "Fire Method"},
        NotifyOn = {RU = "Уведомления о функциях", EN = "Feature Notifications"},
        NotifyAlpha = {RU = "Прозрачность уведомлений", EN = "Notification Transparency"},
        NotifyScale = {RU = "Размер уведомлений", EN = "Notification Size"},
        NotifyColor = {RU = "Цвет уведомлений", EN = "Notification Color"},
        NotifyPreviewText = {RU = "Так выглядят уведомления", EN = "This is how notifications look"},
        GlassOn = {RU = "Эффект жидкого стекла", EN = "Liquid Glass Effect"},
        GlassBlur = {RU = "Размытие мира за меню", EN = "World Blur Behind Menu"},
        GlassSheen = {RU = "Блики и кромка стекла", EN = "Glass Sheen & Rim"},
        Notif_On = {RU = "Включено", EN = "Enabled"},
        Notif_Off = {RU = "Выключено", EN = "Disabled"},
        Notif_Now = {RU = "сейчас", EN = "now"},
        Sec_UiWidgets = {RU = "Виджеты", EN = "Widgets"},
        Sec_Safety = {RU = "Запуск", EN = "Startup"},
        SafeStart = {RU = "Спокойный старт: не включать функции движения и действий из конфига сразу", EN = "Calm Start: do not auto-enable movement and action features from config"},
        SafeStartSkipped = {RU = "Спокойный старт: функций из конфига оставлено выключенными: %d", EN = "Calm Start: config features left off: %d"},
        Sec_UiIos = {RU = "Стиль iOS 26: инфо-панель и виджеты", EN = "iOS 26 Style: Info Bar & Widgets"},
        Sec_Observe = {RU = "Наблюдение", EN = "Spectate"},
        SpeedWidgetOn = {RU = "Виджет скорости", EN = "Speed Widget"},
        SpeedWidgetScale = {RU = "Размер виджета скорости", EN = "Speed Widget Size"},
        Ios26On = {RU = "Стиль iOS 26 (стекло)", EN = "iOS 26 Style (glass)"},
        SpeedUnit = {RU = "studs/с", EN = "studs/s"},
        Unit_ms = {RU = "мс", EN = "ms"},
        Unit_s = {RU = "с", EN = "s"},
        Unit_m = {RU = "м", EN = "m"},
        Unit_pcs = {RU = "штук", EN = "pcs"},
        Pill_Locked = {RU = "ЗАМОК", EN = "LOCKED"},
        Pill_Loaded = {RU = "Загружено", EN = "Loaded"},
        Pill_Mem = {RU = "Память: %dMB", EN = "Memory: %dMB"},
        Pill_Time = {RU = "Время: %02d:%02d:%02d", EN = "Time: %02d:%02d:%02d"},
        Pill_Session = {RU = "Сессия: %02d:%02d:%02d", EN = "Session: %02d:%02d:%02d"},
        Prev_Header = {RU = "ОТОБРАЖЕНИЕ", EN = "DISPLAY"},
        Prev_Dummy = {RU = "Игрок (@User)", EN = "Player (@User)"},
        PV_You = {RU = "[ВЫ] ", EN = "[YOU] "},
        Cfg_BtnSave = {RU = "Сохранить", EN = "Save"},
        Cfg_BtnLoad = {RU = "Загрузить", EN = "Load"},
        Cfg_BtnAuto = {RU = "Авто", EN = "Auto"},
        Cfg_BtnDelete = {RU = "Удалить", EN = "Delete"},
        Cfg_AutoTag = {RU = " [АВТО]", EN = " [AUTO]"},
        Cfg_StorageDisk = {RU = "Хранилище: диск, файл %s", EN = "Storage: disk, file %s"},
        Cfg_StorageMem = {RU = "Хранилище: только память (запись на диск в этом окружении недоступна)", EN = "Storage: memory only (writing to disk is unavailable in this environment)"},
        Cfg_SavedDisk = {RU = "Сохранён: %s (записан на диск)", EN = "Saved: %s (written to disk)"},
        Cfg_SavedMem = {RU = "Сохранён: %s (только в памяти, на диск записать нельзя)", EN = "Saved: %s (memory only, cannot write to disk)"},
        Cfg_Loaded = {RU = "Загружен: %s", EN = "Loaded: %s"},
        Cfg_NotFound = {RU = "Не найден", EN = "Not found"},
        Cfg_AutoDisk = {RU = "Автозагрузка: %s (записано на диск)", EN = "Autoload: %s (written to disk)"},
        Cfg_AutoMem = {RU = "Автозагрузка: %s (только в памяти)", EN = "Autoload: %s (memory only)"},
        Cfg_Deleted = {RU = "Удалён: %s", EN = "Deleted: %s"},
        Sec_UiFont = {RU = "Шрифт", EN = "Font"},
        Panic_Btn = {RU = "Выключить все функции (клавиша End)", EN = "Turn Everything Off (End key)"},
        Panic_Done = {RU = "Все функции выключены", EN = "Everything turned off"},
        RollbackGuard = {RU = "Выключать движение при откате сервером", EN = "Stop Movement When the Server Rolls Back"},
        Rollback_Done = {RU = "Игра вернула персонажа назад: движение выключено", EN = "The game moved you back: movement turned off"},
        Guard_Tripped = {RU = "Ошибка в функции: движение выключено", EN = "A feature kept failing: movement turned off"},
        WallPass_Wait = {RU = "Вы внутри стены: столкновения вернутся, когда выйдете", EN = "You are inside a wall: collisions return once you are out"},
        FontStyle = {RU = "Шрифт интерфейса", EN = "Interface Font"},
        Opt_Gotham = {RU = "Стандартный", EN = "Standard"},
        Opt_Chat = {RU = "Как в чате", EN = "Chat-like"},
        Opt_Lazy = {RU = "Ленивый", EN = "Lazy"},
        Opt_Light = {RU = "Тонкий", EN = "Light"},
        Opt_Bold = {RU = "Жирный", EN = "Bold"},
        Opt_Soft = {RU = "Мягкий", EN = "Soft"},
        Opt_Code = {RU = "Моноширинный", EN = "Monospace"},
        HitMarkerOn = {RU = "Маркер попадания", EN = "Hit Marker"},
        BloomOn = {RU = "Свечение", EN = "Bloom Glow"},
        BloomIntensity = {RU = "Сила свечения", EN = "Glow Intensity"},
        BloomSize = {RU = "Размер свечения", EN = "Glow Size"},
        BloomThreshold = {RU = "Порог свечения", EN = "Glow Threshold"},
        SpectateOn = {RU = "Наблюдение за игроком", EN = "Spectate Player"},
        Spectate_None = {RU = "Нет игроков для наблюдения", EN = "No players to spectate"},
        Spectate_Title = {RU = "Наблюдение", EN = "Spectating"},
        Spectate_Now = {RU = "Наблюдаем за: %s", EN = "Spectating: %s"},
        TimeSyncReal = {RU = "Время как в реальности", EN = "Real-World Time"},
        Intro_Step1 = {RU = "Загрузка настроек", EN = "Loading settings"},
        Intro_Step2 = {RU = "Подготовка интерфейса", EN = "Preparing interface"},
        Intro_Step3 = {RU = "Применение эффектов", EN = "Applying effects"},
        Intro_Step4 = {RU = "Проверка окружения", EN = "Checking environment"},
        Intro_Step5 = {RU = "Готово", EN = "Ready"},
        Intro_Skip = {RU = "Нажмите любую клавишу, чтобы пропустить", EN = "Press any key to skip"},

        Sec_Hits = {RU = "Реакция на урон", EN = "Damage Feedback"},
        Sec_PlayerViewExtra = {RU = "Дополнительно", EN = "Extras"},
        ShakeOn = {RU = "Тряска камеры при уроне", EN = "Camera Shake on Damage"},
        ShakeStrength = {RU = "Сила тряски", EN = "Shake Strength"},
        HitFlashOn = {RU = "Красная вспышка при уроне", EN = "Red Flash on Damage"},
        LowHpOn = {RU = "Пульс при низком здоровье", EN = "Low Health Pulse"},
        DamageNumbers = {RU = "Числа урона над игроками", EN = "Damage Numbers"},
        PlayerViewDistance = {RU = "Показывать дистанцию до игроков", EN = "Show Distance"},
        PlayerViewHealthColor = {RU = "Цвет по здоровью", EN = "Color by Health"},

        PropWeather = {RU = "Включить осадки на карте", EN = "Enable Precipitation"},
        WeatherMode = {RU = "Тип осадков", EN = "Precipitation Type"},
        WeatherDense = {RU = "Количество осадков", EN = "Precipitation Amount"},
        WeatherSpeed = {RU = "Скорость падения", EN = "Fall Speed"},
        WeatherRadius = {RU = "Радиус осадков", EN = "Precipitation Radius"},
        SnowSize = {RU = "Размер снежинок", EN = "Snowflake Size"},
        WeatherCol = {RU = "Цвет осадков", EN = "Precipitation Color"},

        Lightning = {RU = "Вспышки молний", EN = "Lightning Flashes"},
        LightRate = {RU = "Частота молний", EN = "Lightning Rate"},
        LightSize = {RU = "Размер молний", EN = "Lightning Size"},
        LightDur = {RU = "Длительность вспышки", EN = "Flash Duration"},
        Meteors = {RU = "Падающие звезды", EN = "Falling Stars"},
        MetRate = {RU = "Частота звезд", EN = "Star Rate"},
        MetSize = {RU = "Размер звезд", EN = "Star Size"},
        MetTail = {RU = "Длина следа", EN = "Trail Length"},
        MetDur = {RU = "Время полета", EN = "Flight Time"},
        MetCol = {RU = "Цвет звезд", EN = "Star Color"},

        HideHats = {RU = "Скрыть шапки у игроков", EN = "Hide Hats"},
        HoloSelf = {RU = "Голограмма на своем персонаже", EN = "Self Hologram"},
        HoloAlpha = {RU = "Прозрачность персонажа", EN = "Transparency"},
        HoloCol = {RU = "Цвет голограммы", EN = "Hologram Color"},
        JumpRings = {RU = "Круги от прыжков на полу", EN = "Jump Rings"},
        JumpRingType = {RU = "Тип круга", EN = "Ring Type"},
        JumpRingFillCol = {RU = "Цвет заливки", EN = "Fill Color"},
        JumpRingOutCol = {RU = "Цвет контура", EN = "Outline Color"},
        JumpRingGlow = {RU = "Яркость свечения", EN = "Ring Brightness"},
        JumpRingSize = {RU = "Размер круга", EN = "Ring Size"},
        JumpRingSpeed = {RU = "Скорость исчезновения", EN = "Fade Speed"},
        Orbits = {RU = "Сферы вокруг тела", EN = "Body Orbits"},
        OrbitCount = {RU = "Количество сфер", EN = "Sphere Count"},
        OrbitRadius = {RU = "Радиус вращения", EN = "Rotation Radius"},
        OrbitSpeed = {RU = "Скорость вращения", EN = "Rotation Speed"},
        OrbitSize = {RU = "Размер сфер", EN = "Sphere Size"},
        OrbitTrailThick = {RU = "Толщина следа", EN = "Trail Thickness"},
        OrbitTrailLen = {RU = "Длина следа", EN = "Trail Length"},
        OrbitCol = {RU = "Цвет сфер", EN = "Sphere Color"},
        OrbitTrailCol = {RU = "Цвет следа", EN = "Trail Color"},
        WireHat = {RU = "Голографическая шляпа", EN = "Holo Hat"},
        HatSize = {RU = "Размер шляпы", EN = "Hat Size"},
        HatHeight = {RU = "Высота на голове", EN = "Head Height"},
        HatCol = {RU = "Цвет шляпы", EN = "Hat Color"},

        PitchMod = {RU = "Наклон персонажа (видят все)", EN = "Character Tilt (everyone sees)"},
        PitchAngle = {RU = "Угол наклона", EN = "Tilt Angle"},
        SpinCharacter = {RU = "Вращать персонажа (видят все)", EN = "Spin Character (everyone sees)"},
        YawSpeed = {RU = "Скорость вращения", EN = "Rotation Speed"},
        JerkySpin = {RU = "Вращение рывками", EN = "Jerky Rotation"},

        FpsBoost = {RU = "Упрощённая графика (больше FPS)", EN = "Simplified Graphics (more FPS)"},

        FpsUnlocker = {RU = "Снять ограничение FPS", EN = "Remove FPS Limit"},

        FpsUnlockFail = {RU = "Лимит FPS снять не удалось: Roblox запретил это скрипту. Включите «Неограниченно» в меню Roblox: Esc, Настройки, Графика", EN = "Could not remove the FPS limit: Roblox blocks it for scripts. Set it to Unlimited in the Roblox menu: Esc, Settings, Graphics"},

        LangBtn = {RU = "Язык интерфейса", EN = "Language / Язык меню"},
        AnimSpeed = {RU = "Плавность меню", EN = "Menu Smoothness"},
        PillScale = {RU = "Размер инфо-панели", EN = "Info Panel Size"},
        MainAlpha = {RU = "Прозрачность фона", EN = "Background Opacity"},
        MainCol = {RU = "Цвет фона меню", EN = "Main Background Color"},
        CardAlpha = {RU = "Прозрачность блоков", EN = "Block Opacity"},
        CardCol = {RU = "Цвет блоков", EN = "Block Color"},
        AccentCol = {RU = "Основной цвет темы", EN = "Main Theme Color"},
        BorderThick = {RU = "Толщина обводки", EN = "Border Thickness"},
        BorderCol = {RU = "Цвет обводки меню", EN = "Menu Border Color"},
        SideAlpha = {RU = "Прозрачность списка", EN = "Sidebar Opacity"},
        SideCol = {RU = "Цвет списка слева", EN = "Sidebar Color"},
        SideCardAlpha = {RU = "Прозрачность иконок", EN = "Icon Opacity"},
        SideCardCol = {RU = "Цвет фона иконок", EN = "Icon BG Color"},
        LogoCol = {RU = "Цвет логотипа", EN = "Logo Color"},
        PillUser = {RU = "Показывать имя", EN = "Show Name"},
        PillMem = {RU = "Показывать память", EN = "Show Memory"},
        PillMinsk = {RU = "Показывать системное время", EN = "Show System Time"},
        PillSession = {RU = "Время в игре", EN = "Time in Game"},
        PillBorderThick = {RU = "Обводка панели", EN = "Panel Border"},
        PillBorderCol = {RU = "Цвет обводки инфо", EN = "Info Border Color"},
        PillAlpha = {RU = "Прозрачность инфо", EN = "Info Opacity"},
        PillBg = {RU = "Цвет фона инфо", EN = "Info BG Color"},
        PillTextCol = {RU = "Цвет текста инфо", EN = "Info Text Color"}
    }
}

M.Tooltips = {
    AimAssist = "Мягкая доводка камеры до цели.",
    ShowFov = "Рисует круг захвата целей в центре экрана.",
    TriggerAssist = "Срабатывание клика при наведении на цель.",
    TriggerLoop = "Непрерывная серия кликов.",
    FlightSpeed = "Полёт на WASD / Space / Shift. Скорость меняется плавно, гравитация компенсируется, персонаж не дёргается и висит на месте без нажатий. Стены задерживают его как обычно.",
    SprintSpeed = "Ускорение бега: пока вы идёте, скорость ходьбы персонажа поднимается до выбранной (на вашем компьютере). Персонаж бежит обычной физикой, без скачков по координатам, поэтому реже откатывается сервером.",
    WalkThroughWalls = "Отключает столкновения частей персонажа. Скрипт сам вас не двигает. При выключении внутри стены столкновения возвращаются, только когда вы вышли, иначе физика вытолкнула бы вас назад. Если игра сама возвращает вас за стену, это её проверка: скрипт её не обходит.",
    InfiniteJumps = "Прыжки в воздухе.",
    AutoJump = "Персонаж прыгает без остановок: как только он приземлился, прыжок повторяется сразу, как будто пробел нажимают снова и снова. Держать пробел не нужно. Во время полёта и в транспорте не работает. Аварийное отключение (End) выключает и эту функцию.",
    FallProtection = "Анти-рагдол: персонаж не падает в рагдол и встаёт сам, а силы отбрасывания, появившиеся при ударе, выключаются. Позиция не меняется: вы остаётесь на месте. Если игра толкает вас каждый кадр, защита уступает, чтобы не дёргать.",
    IdleProtection = "Анти-АФК: Roblox отключает игрока примерно через 20 минут без нажатий. Пока функция включена, в такой момент скрипт сам нажимает кнопку мыши (обычный ввод игрока), и вас не отключают. Ничего отдельного на сервер не отправляется.",
    NotifyScale = "Размер всплывающих уведомлений в правом нижнем углу. Меняется сразу, в том числе у уже показанных.",
    FontStyle = "Шрифт всего интерфейса. Как в чате: гротеск без засечек (в духе Arial). Жирный: везде самое жирное начертание. Ленивый: наклонный (курсив). Тонкий, мягкий и моноширинный тоже есть. Меняется сразу.",
    AntiStun = "Если игра после удара на несколько секунд обнуляет вашу скорость бега или прыжок (оглушение), скрипт возвращает прежние значения.",
    SpinCharacter = "Вращает весь корпус. Положение корня персонажа игра сама передаёт всем игрокам, поэтому вращение видят ВСЕ.",
    YawSpeed = "Плавная регулировка скорости вращения персонажа.",
    JerkySpin = "Резкие случайные рывки при вращении.",
    HeadTiltOn = "Наклоняет весь корпус вперёд или назад. Положение корня персонажа игра сама передаёт всем игрокам, поэтому наклон видят ВСЕ. Отрицательный угол наклоняет вперёд, положительный назад.",
    AirControl = "Управление в падении: скорость плавно подтягивается к выбранному направлению. Скорость выше выбранной не снижается.",
    PlayerView = "Подсвечивает игроков контуром и заливкой.",
    PlayerViewLines = "Рисует линии от низа экрана до игроков.",
    ThirdPerson = "Фиксированный вид от третьего лица.",
    CloudsOn = "Включение объемных облаков в небе.",
    FpsBoost = "Реально снижает нагрузку: все поверхности становятся гладкими и однотонными (без текстур мешей, материалов, декалей и одежды персонажей), простой вид материалов террейна, минимальная детализация мешей, выключены тени, частицы, источники света, пост-эффекты игры, облака, трава и волны воды, качество графики Roblox на минимуме. Картинка станет «мыльной», зато кадров заметно больше. Всё меняется только у вас на экране и возвращается при выключении.",
    FpsUnlocker = "Просит у встроенной настройки Roblox убрать лимит кадров. Работает только на вашем компьютере. Если Roblox запрещает это скрипту, появится уведомление: тогда включите «Неограниченно» в меню Roblox.",
    HideHats = "Прячет шапки и аксессуары на головах у всех игроков (только на вашем экране).",
    HoloSelf = "Делает вашего персонажа полупрозрачной голограммой.",
    KnockbackProtection = "Анти-хит: отменяет резкий толчок, остаётся ваша прежняя скорость. Если стоите на месте, остаётесь на месте. Позицию персонажа не трогает.",
    AimWallCheck = "Не целиться в игроков, которые закрыты стеной.",
    TriggerWallCheck = "Если включено, выстрел не произойдёт, пока цель закрыта стеной.",
    AimTeamCheck = "Не целиться в игроков из вашей команды.",
    SkyOn = "Заменяет небо на ваши картинки. Время суток на скайбокс не влияет: небо остаётся тем же днём и ночью.",
    SkyIds = "Один ID (картинка на все грани или модель-небо из магазина), шесть ID через запятую в порядке Bk, Dn, Ft, Lf, Rt, Up (зад, низ, перед, лево, право, верх) или слово default (стандартное небо Roblox).",
    SkyHideBodies = "Солнце, луна и звёзды привязаны ко времени суток и рисуются поверх неба. Выключите их, чтобы свой скайбокс выглядел одинаково в любое время.",
    FovOn = "Пока включено, поле зрения держится на выбранном значении каждый кадр, даже если игра пытается его менять.",
    ZoomOn = "Зажмите Z, чтобы плавно приблизить картинку. Отпустите, и FOV вернётся к прежнему значению.",
    GradeOn = "Меняет цвет всей картинки: насыщенность, контраст, яркость и общий оттенок.",
    TimeCycle = "Время суток постоянно идёт вперёд с выбранной скоростью.",
    SunRaysOn = "Красивые лучи от солнца или луны со свечением. Видны, когда источник света находится в кадре.",
    LightningFlash = "Короткая вспышка по всему экрану в момент удара молнии.",
    MeteorImpact = "Ударная волна и вспышка света в месте падения метеорита.",
    AimPart = "Head: голова. Body: корпус, куда проще попасть, если у игры маленькая голова.",
    TriggerMethod = "Click: клик мыши через VirtualUser, подходит почти всем играм. Tool: прямой вызов оружия, нужен только если клик не срабатывает.",
    GlassOn = "Добавляет стеклянные блики, светящуюся кромку и размытие мира за меню. Чем прозрачнее меню, тем заметнее эффект.",
    NotifyOn = "Показывает уведомление в правом нижнем углу, когда вы включаете или выключаете функцию.",
    ShakeOn = "Камера вздрагивает, когда вы получаете урон. Чем больше урон, тем сильнее тряска.",
    HitFlashOn = "Экран на мгновение краснеет, когда вам наносят урон.",
    LowHpOn = "Когда здоровья мало, края экрана пульсируют красным. Чем меньше здоровья, тем чаще пульс.",
    DamageNumbers = "Над игроком всплывает число, когда он теряет здоровье.",
    PlayerViewDistance = "Добавляет к имени игрока расстояние до него в метрах.",
    PlayerViewHealthColor = "Подсветка игрока и полоска здоровья меняют цвет от зелёного к красному по мере потери здоровья.",
    SpeedWidgetOn = "Виджет показывает вашу скорость числом и бегущей волной: чем быстрее вы двигаетесь, тем выше и чаще волна. Его можно перетаскивать мышью.",
    SafeStart = "При автозагрузке конфига полёт, ускорение, прохождение сквозь стены, помощь в прицеливании, автоматический выстрел, вращение, защита от падений и подобное остаются выключенными, пока вы сами их не включите. Так игра начинается спокойно, без уже включённых функций. Загрузка конфига кнопкой применяет всё как сохранено.",
    Ios26On = "Включено: инфо-панель (FPS, игра, время), виджет скорости и панель наблюдения становятся стеклянными капсулами в стиле iOS 26 со светящейся кромкой. Выключено: простой плоский вид.",
    HitMarkerOn = "Короткий крестик в центре экрана, когда рядом с прицелом кто-то теряет здоровье. Красный - если игрок погиб.",
    BloomOn = "Свечение ярких мест, как у линзы камеры. Не связано с лучами света, работает отдельно.",
    SpectateOn = "Камера следует за выбранным игроком. Кнопки со стрелками переключают игрока. При выключении камера возвращается к вам.",
    TimeSyncReal = "Время суток в игре совпадает с системным временем вашего устройства.",
    RollbackGuard = "Если игра вернула персонажа назад (смещение за кадр намного больше возможного и против вашего движения), полёт, ускорение, проход сквозь стены и управление в воздухе выключаются сами и вы видите уведомление. Иначе игра откатывала бы вас снова и снова. Телепорт игры вперёд или вбок откатом не считается.",
}

M.TooltipsEN = {
    AimAssist = "Smoothly pulls the camera toward the target.",
    ShowFov = "Draws the target capture circle in the center of the screen.",
    TriggerAssist = "Fires a click automatically when your aim is on a target.",
    TriggerLoop = "A continuous series of clicks.",
    FlightSpeed = "Flight with WASD / Space / Shift. Speed changes smoothly, gravity is compensated, the character does not jitter and hovers in place with no input. Walls stop it as usual.",
    SprintSpeed = "Faster running: while you walk, your character walk speed is raised to the chosen value (on your computer). The character runs with ordinary physics, with no jumps in position, so the server corrects it less often.",
    WalkThroughWalls = "Turns off collisions for the parts of your character. The script never moves you itself. When turned off inside a wall, collisions return only once you are out, otherwise physics would push you back. If the game itself returns you behind the wall, that is its own check: the script does not bypass it.",
    InfiniteJumps = "Jumping in mid-air.",
    AutoJump = "Your character jumps non-stop: the moment it lands, it jumps again, as if the space bar were pressed over and over. You do not need to hold anything. Does nothing while flying or seated. The panic key (End) turns this off too.",
    FallProtection = "Anti-ragdoll: your character does not fall into a ragdoll and gets back up by itself, and knockback forces created by a hit are switched off. Your position is never changed: you stay where you are. If the game pushes you every frame, the protection backs off so you do not jitter.",
    AntiStun = "If the game zeroes your walk speed or jump for a few seconds after a hit (a stun), the script restores the previous values.",
    IdleProtection = "Anti-AFK: Roblox disconnects a player after about 20 minutes without input. While this is on, at that moment the script presses a mouse button itself (ordinary player input), so you are not kicked. Nothing separate is sent to the server.",
    SpinCharacter = "Spins your whole body. The game itself sends your root part position to all players, so EVERYONE sees the spin.",
    YawSpeed = "Smooth control of the spin speed.",
    JerkySpin = "Sharp random jerks while spinning.",
    HeadTiltOn = "Tilts your whole body forward or backward. The game sends your root part position to all players, so EVERYONE sees the tilt. A negative angle tilts forward, a positive one backward.",
    AirControl = "Mid-air steering: your speed is smoothly pulled toward the chosen direction. A speed above the chosen one is never reduced.",
    PlayerView = "Highlights players with an outline and a fill.",
    PlayerViewLines = "Draws lines from the bottom of the screen to players.",
    ThirdPerson = "A fixed third-person view.",
    CloudsOn = "Adds volumetric clouds to the sky.",
    FpsBoost = "Really reduces the load: every surface becomes smooth and flat-colored (no mesh, material, decal or clothing textures), terrain gets simple materials, mesh detail is minimal, and shadows, particles, lights, the game post effects, clouds, grass and water waves are turned off, with Roblox graphics quality set to the minimum. The picture gets blurry, but you get noticeably more FPS. Everything changes only on your screen and is restored when you turn it off.",
    FpsUnlocker = "Asks the built-in Roblox setting to remove the frame rate limit. Works only on your computer. If Roblox does not allow scripts to do this, a notification appears: then set Unlimited in the Roblox menu.",
    HideHats = "Hides hats and accessories on the heads of all players (only on your screen).",
    HoloSelf = "Turns your character into a semi-transparent hologram.",
    KnockbackProtection = "Anti-hit: cancels a sudden push and keeps your previous speed. If you stand still, you stay still. Never changes your position.",
    AimWallCheck = "Do not aim at players hidden behind a wall.",
    TriggerWallCheck = "When on, no shot is fired while the target is hidden behind a wall.",
    AimTeamCheck = "Do not aim at players from your team.",
    SkyOn = "Replaces the sky with your images. Time of day does not affect the skybox: the sky stays the same day and night.",
    SkyIds = "One ID (an image for all faces or a sky model from the store), six IDs separated by commas in the order Bk, Dn, Ft, Lf, Rt, Up (back, down, front, left, right, up), or the word default (the standard Roblox sky).",
    SkyHideBodies = "The sun, moon and stars follow the time of day and are drawn over the sky. Turn them off so your skybox looks the same at any time.",
    FovOn = "While on, the field of view is held at the chosen value every frame, even if the game tries to change it.",
    ZoomOn = "Hold Z to smoothly zoom in. Release it and the FOV goes back to the previous value.",
    GradeOn = "Changes the color of the whole picture: saturation, contrast, brightness and overall tint.",
    TimeCycle = "The time of day keeps moving forward at the chosen speed.",
    SunRaysOn = "Nice glowing rays from the sun or moon. Visible when the light source is in view.",
    LightningFlash = "A short flash across the whole screen when lightning strikes.",
    MeteorImpact = "A shock wave and a flash of light where a meteor lands.",
    AimPart = "Head: the head. Body: the torso, easier to hit if the game has a small head.",
    TriggerMethod = "Click: a mouse click through VirtualUser, fits almost every game. Tool: a direct call of the weapon, needed only if the click does not fire.",
    GlassOn = "Adds glass highlights, a glowing rim and a blur of the world behind the menu. The more transparent the menu, the stronger the effect.",
    NotifyOn = "Shows a notification in the bottom-right corner when you turn a feature on or off.",
    NotifyScale = "Size of the pop-up notifications in the bottom-right corner. Changes immediately, including ones already on screen.",
    FontStyle = "Font of the whole interface. Chat-like: a sans-serif grotesque (Arial-style). Bold: the heaviest weight everywhere. Lazy: slanted (italic). Light, soft and monospace are also available. Changes immediately.",
    ShakeOn = "The camera shakes when you take damage. The bigger the damage, the stronger the shake.",
    HitFlashOn = "The screen briefly turns red when you take damage.",
    LowHpOn = "When your health is low, the screen edges pulse red. The lower the health, the faster the pulse.",
    DamageNumbers = "A number pops up above a player when they lose health.",
    PlayerViewDistance = "Adds the distance to the player, in meters, to their name.",
    PlayerViewHealthColor = "The player highlight and health bar change color from green to red as health drops.",
    SpeedWidgetOn = "The widget shows your speed as a number and a running wave: the faster you move, the higher and busier the wave. You can drag it with the mouse.",
    SafeStart = "When a config autoloads, flight, speed boost, walking through walls, aim assist, auto fire, spin, fall protection and similar features stay off until you turn them on yourself. This way the game starts calmly, with nothing already running. Loading a config with the button applies everything as saved.",
    Ios26On = "On: the info panel (FPS, game, time), the speed widget and the spectate bar become glass capsules in the iOS 26 style with a glowing rim. Off: a simple flat look.",
    HitMarkerOn = "A short cross in the center of the screen when someone near your aim loses health. Red if the player died.",
    BloomOn = "A glow around bright areas, like a camera lens. Unrelated to light rays, works separately.",
    SpectateOn = "The camera follows the chosen player. Arrow buttons switch players. When turned off, the camera returns to you.",
    TimeSyncReal = "The in-game time of day matches the system time of your device.",
    RollbackGuard = "If the game moves your character back (a per-frame jump far larger than possible and against your movement), flight, speed boost, walking through walls and mid-air control turn off by themselves and you get a notification. Otherwise the game would roll you back again and again. A game teleport forward or sideways does not count as a rollback.",
}


M.State = {
    Language = "RU",
    FontStyle = "Gotham",
    MenuOpen = false,

    AimAssist = false, AimFov = 150, ShowFov = false, AimTime = 50, AimWallCheck = true, AimTeamCheck = true, AimPart = "Head",
    TriggerAssist = false, TriggerLoop = false, TriggerDelay = 0.05, TriggerWallCheck = true, TriggerTeamCheck = true, TriggerMethod = "Click",

    FlightMode = false, WalkThroughWalls = false, PlayerView = false, PlayerViewOnSelf = false, PlayerViewTeamCheck = false, Speed = false, InfiniteJumps = false, FallProtection = false,
    FlightSpeed = 55, SprintSpeed = 45,
    KnockbackProtection = false,
    AirControl = false, AirSpeed = 150, AirAccel = 8,
    AutoJump = false,

    CamFov = 70, FovOn = false, ThirdPerson = false, ThirdPersonDist = 12,
    ZoomOn = false, ZoomFov = 25, ZoomSpeed = 12,
    GradeOn = false, GradePreset = "Custom", GradeSat = 0.15, GradeContrast = 0.1, GradeBright = 0,
    GradeTint = Color3.fromRGB(255, 255, 255),
    AntiStun = false,
    IdleProtection = false,
    RollbackGuard = true,
    ShakeOn = false, ShakeStrength = 0.6, HitFlashOn = false, LowHpOn = false,
    DamageNumbers = false, PlayerViewDistance = false, PlayerViewHealthColor = false,
    Ios26On = true,
    SpeedWidgetOn = false, SpeedWidgetScale = 1, SpeedWidgetX = 0.9, SpeedWidgetY = 0.62,
    HitMarkerOn = false,
    BloomOn = false, BloomIntensity = 0.6, BloomSize = 24, BloomThreshold = 1.2,
    SpectateOn = false, TimeSyncReal = false, SpecX = 0.5, SpecY = 0.9,
    SafeStart = true,

    SpinCharacter = false, YawSpeed = 25, JerkySpin = false, HeadTiltOn = false, PitchAngle = -60,

    FpsBoost = false, FpsUnlocker = false,

    MainBg = Color3.fromRGB(15, 17, 23), MenuAlpha = 0.1,
    SideBg = Color3.fromRGB(10, 12, 16), SideAlpha = 0,
    CardBg = Color3.fromRGB(22, 25, 33), CardAlpha = 0.18,
    SideCardBg = Color3.fromRGB(16, 19, 26), SideCardAlpha = 0.2,
    Accent = Color3.fromRGB(166, 211, 223), -- #A6D3DF
    BorderCol = Color3.fromRGB(45, 52, 70), BorderThick = 1,
    LogoCol = Color3.fromRGB(255, 255, 255),
    AnimSpeed = 0.22,
    NotifyOn = true, NotifyAlpha = 0.16, NotifyScale = 1, NotifyColor = Color3.fromRGB(56, 60, 82), GlassOn = true, GlassBlur = 10, GlassSheen = 0.5,

    PillBg = Color3.fromRGB(15, 17, 23), PillAlpha = 0.15, PillTextCol = Color3.fromRGB(255, 255, 255),
    PillBorderCol = Color3.fromRGB(45, 52, 70), PillBorderThick = 1,
    PillScaleVal = 1.0,
    PillShowUser = true, PillShowMem = true, PillShowTime = true, PillShowMinsk = true,
    PillLocked = false,

    PlayerViewBox = true,
    PlayerViewBoxCol = Color3.fromRGB(255, 255, 255),
    PlayerViewBoxThick = 1.5,
    PlayerViewFill = Color3.fromRGB(48, 209, 88),
    PlayerViewLine = Color3.fromRGB(255, 255, 255),
    PlayerViewAlpha = 0.4,
    PlayerViewNameCol = Color3.fromRGB(255, 255, 255), PlayerViewNameOutCol = Color3.fromRGB(0, 0, 0),
    PlayerViewFontWeight = "Bold", PlayerViewTextSize = 13,

    PlayerViewHealthBar = true,
    PlayerViewHealthPos = "Left",
    PlayerViewHealthText = true,
    PlayerViewHealthCol = Color3.fromRGB(48, 209, 88),
    PlayerViewHealthBarThick = 4,

    PlayerViewLines = false,
    PlayerLineCol = Color3.fromRGB(48, 209, 88),

    DarkWorld = false, DarkIntensity = 0.5, OrigExp = 0,
    FogOn = false, FogDensity = 0.75, FogHaze = 0.0,
    FogColor = Color3.fromRGB(255, 255, 255),
    OrigFogStart = 0, OrigFogEnd = 100000, OrigFogColor = Color3.new(0.8, 0.8, 0.8),
    OrigOutdoorAmb = Color3.fromRGB(128, 128, 128),

    CloudsOn = false,
    CloudDensity = 0.7,
    CloudCover = 60,
    CloudColor = Color3.fromRGB(255, 255, 255),

    SkyOn = false,
    SkyIds = "",
    SkyHideBodies = true,

    WeatherOn = false, WeatherMode = "Rain", WeatherDensity = 35, WeatherSpeed = 60, WeatherRadius = 60,
    WeatherColor = Color3.fromRGB(180, 230, 255), SnowSize = 0.5,

    TimeOn = false, OrigTime = 14, CustomTime = 14.5, TimeCycle = false, TimeCycleSpeed = 24,
    SunRaysOn = false, SunRaysIntensity = 0.35, SunRaysSpread = 0.7, SunRaysBright = 0.5,
    MeteorOn = false, MeteorRate = 3, MeteorSize = 3.5, MeteorTrailLen = 1.8, MeteorDuration = 2.5, MeteorColor = Color3.fromRGB(255, 140, 40), MeteorImpact = true,
    LightningOn = false, LightningRate = 3, LightningSize = 0.8, LightningDuration = 0.7, LightningFlash = true, LightningFlashPower = 0.5,

    HideHats = false,
    HoloSelf = false,
    HoloColor = Color3.fromRGB(0, 230, 255),
    HoloAlpha = 0.25,

    JumpRings = false,
    JumpRingType = "Both",
    JumpRingFillCol = Color3.fromRGB(48, 209, 88),
    JumpRingOutCol = Color3.fromRGB(255, 255, 255),
    JumpRingGlow = 1.5,
    JumpRingSize = 14,
    JumpRingSpeed = 0.8,

    OrbitOn = false, OrbitCount = 4, OrbitRadius = 6, OrbitSpeed = 2, OrbitSize = 0.8, OrbitTrailThick = 0.35, OrbitTrailLen = 0.7,
    OrbitColor = Color3.fromRGB(60, 255, 180), OrbitTrailColor = Color3.fromRGB(0, 180, 255),
    HatOn = false, HatSize = 1.1, HatHeight = 0.75, HatColor = Color3.fromRGB(0, 210, 255),

    Uptime = 0, ActiveTab = "Combat", SelectedCfg = "default",
    Highlights = {}, PlayerViewGuis = {}, OrbitObjs = {}, HatModel = nil, PlayerConns = {},
    WeatherPool = {},
    Cards = {}, SideCards = {}, Sliders = {}, Binds = {}, Pages = {}, TabButtons = {},
    ListeningBind = nil, CurFPS = 60, TabSwitching = false, IsShutDown = false,
    IsDead = false
}

M.Data = {
    GlobalPalette = {nil, nil, nil, nil, nil},
    PaletteCallers = {},
    ValidLimbs = {
        ["Head"] = true, ["Torso"] = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
        ["UpperTorso"] = true, ["LowerTorso"] = true,
        ["LeftUpperArm"] = true, ["LeftLowerArm"] = true, ["LeftHand"] = true,
        ["RightUpperArm"] = true, ["RightLowerArm"] = true, ["RightHand"] = true,
        ["LeftUpperLeg"] = true, ["LeftLowerLeg"] = true, ["LeftFoot"] = true,
        ["RightUpperLeg"] = true, ["RightLowerLeg"] = true, ["RightFoot"] = true
    },
    RegUI = {},
    Conns = {},
    CharConns = {},
    FpsCount = 0,
    FpsTimer = os.clock(),
    OrbitClock = 0,
    LastMet = 0,
    LastLight = 0,
    SpinAngle = 0,
    GuardUntil = 0, FixRun = 0, SpeedHum = nil, SpeedBase = nil, SpeedWritten = nil, FlightVel = nil, KnownMovers = setmetatable({}, {__mode = "k"}), OrigFpsCap = nil, PageBuilders = {}, AfkConn = nil, FontOrig = setmetatable({}, {__mode = "k"}),
    TriggerCD = false,
    LastTriggerTarget = nil,
    DragHandler = nil,
    HoverCard = nil,
    HoverTask = nil,
    MemStorage = {},
    -- Кэши с "слабыми" ключами: когда деталь удалена из игры, запись исчезает сама (нет утечки памяти)
    TextureCache = setmetatable({}, {__mode = "k"}),
    OriginalMaterials = setmetatable({}, {__mode = "k"}),
    EmitterCache = setmetatable({}, {__mode = "k"}),
    EffectCache = setmetatable({}, {__mode = "k"}),
    TexCache = setmetatable({}, {__mode = "k"}),
    FpsBoostConns = {}, BoostLighting = nil, BoostTerrain = nil, BoostQuality = nil,
    WallPassOrig = setmetatable({}, {__mode = "k"}),
    WallReleasePending = false, WallReleaseStart = 0, WallReleaseCheck = 0, WallPassAdded = nil,
    GuardLastPos = nil, GuardLastVel = nil, GuardChar = nil, GuardCooldownUntil = 0, ErrorLog = {},
    VisualOrig = setmetatable({}, {__mode = "k"}),

    -- Что было в игре до наших изменений (чтобы красиво вернуть при выключении)
    AtmoBackup = {},
    CloudBackup = nil,
    OrigCameraMode = nil,
    Importing = false,
    MenuToken = 0,
    OrigAmbient = nil,
    OrigGlobalShadows = nil,
    OrigZoomMin = 0.5,
    OrigZoomMax = 128,

    -- Флаги "мы это сейчас применяем", чтобы восстанавливать ровно один раз
    FogApplied = false,
    DarkApplied = false,
    PoseApplied = false, PoseAutoRotate = false, PoseStatesLocked = false,
    FallProtectionApplied = false,
    TPApplied = false,
    HatsHidden = false,
    HoloApplied = false,

    LastVisual = 0,
    FpsBoostToken = 0,
    OwnFolderSet = {},
    Debounce = {},
    RmbCamera = false,
    Fades = {},

    -- Свой скайбокс
    SkyFaces = {"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp"},
    SkyBuiltin = {"rbxasset://textures/sky/sky512_bk.tex", "rbxasset://textures/sky/sky512_dn.tex", "rbxasset://textures/sky/sky512_ft.tex",
        "rbxasset://textures/sky/sky512_lf.tex", "rbxasset://textures/sky/sky512_rt.tex", "rbxasset://textures/sky/sky512_up.tex"},
    SkyBackup = nil,   -- что было у Sky игры до нас
    SkyCache = {},     -- уже загруженные скайбоксы из магазина: [ID] = 6 граней
    SkyFallbackReason = nil,
    SkyWanted = nil,   -- последние корректно разобранные 6 граней
    SkyOkKey = "Sky_Ok1",
    SkyToken = 0,
    SkyStatus = nil,
    SkyDetail = nil,

    ZoomHeld = false, ZoomBlend = 0, GameFov = 70, FovApplied = false,
    
    NotifList = {}, LastCycleUi = 0, AimLock = nil, FogScan = 0,
    TabInds = {}, TabStrokes = {}, TabIcons = {}, GlassToken = 0,
    LastHealth = nil, ShakeEnergy = 0, LastShake = nil, LastPos = nil, MoveSpeed = 0,
    HpCache = setmetatable({}, {__mode = "k"}), LastShot = -10, FlashUsed = -100, NotifyUsed = -100, LastFolderSweep = 0, StartupLoad = false, SkippedAtStart = {}, PlayerViewConns = {}, LastJump = -10,
    LastGetUp = 0, LastMotorFix = 0, PrevVelocity = nil, PrevGrounded = true, FlingUntil = 0, LastDamage = -10, NormalWalk = nil, NormalJump = nil, NormalJumpHeight = nil, StunSince = nil,
    Panels = {}, ToggleRefs = {}, AccentVersion = 0,
    Speed3D = 0, SpeedShown = 0, SpeedSamples = {}, SpeedHistory = {}, SpeedClock = 0, GraphScale = 80,
    SpectateTarget = nil, Spectating = false,
    LastRealSync = 0
}

M.UI = { PlayerView2DParts = {} }
M.CFG = {}
M.F = {}

-- ==============================================================================
-- [ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ]
-- ==============================================================================

-- Запоминаем соединение, чтобы ShutDown смог его отключить
function M.Track(conn)
    table.insert(M.Data.Conns, conn)
    return conn
end

-- Откладывает вызов fn. Если за delay секунд функцию вызвали снова с тем же key,
-- сработает только последний вызов. Нужно, чтобы слайдеры не пересоздавали объекты на каждый пиксель.
function M.F.Debounce(key, delay, fn)
    local token = (M.Data.Debounce[key] or 0) + 1
    M.Data.Debounce[key] = token
    task.delay(delay, function()
        if M.Data.Debounce[key] == token and not M.State.IsShutDown then
            fn()
        end
    end)
end

-- ==============================================================================
-- [ ВСПОМОГАТЕЛЬНАЯ МАТЕМАТИКА ]
-- ==============================================================================
M.Math = {}

-- Плавное приближение к цели, не зависящее от FPS: за одну секунду скорость speed даёт одинаковый результат
-- и на 30, и на 240 кадрах. Когда осталось совсем чуть-чуть, значение "прилипает" к цели.
function M.Math.Smooth(current, target, dt, speed)
    local alpha = 1 - math.exp(-math.max(speed, 0) * math.max(dt, 0))
    local nextValue = current + (target - current) * alpha
    if math.abs(target - nextValue) < 0.0005 then return target end
    return nextValue
end

-- Часы суток (0..24) идут вперёд со скоростью hoursPerMinute игровых часов в минуту
function M.Math.AdvanceClock(clock, dt, hoursPerMinute)
    return (clock + dt * hoursPerMinute / 60) % 24
end

-- Цвет по доле здоровья: зелёный, жёлтый, красный
function M.Math.HealthColor(fraction)
    local f = math.clamp(fraction, 0, 1)
    if f < 0.5 then
        return Color3.fromRGB(255, 60, 60):Lerp(Color3.fromRGB(255, 200, 40), f * 2)
    end
    return Color3.fromRGB(255, 200, 40):Lerp(Color3.fromRGB(60, 220, 90), (f - 0.5) * 2)
end

-- Высоты точек графика скорости в пикселях: самая свежая скорость стоит справа, слева идёт предыдущая.
function M.Math.SpeedGraphHeights(history, scaleMax, maxHeight)
    local heights = {}
    local safeScale = (type(scaleMax) == "number" and scaleMax > 0) and scaleMax or 1
    for i, value in ipairs(history or {}) do
        heights[i] = math.clamp((value or 0) / safeScale, 0, 1) * maxHeight
    end
    return heights
end

-- Лёгкое сглаживание ряда (скользящее среднее по трём точкам): линия получается плавной, без ступенек
function M.Math.SmoothSeries(values)
    if not values then return {} end
    local count = #values
    local result = {}
    for i = 1, count do
        local before = values[math.max(i - 1, 1)] or 0
        local current = values[i] or 0
        local after = values[math.min(i + 1, count)] or 0
        result[i] = (before + 2 * current + after) / 4
    end
    return result
end

-- Один отрезок линии между точками (x1, y1) и (x2, y2): центр, длина и угол поворота в градусах.
-- Из таких отрезков (тонких повёрнутых прямоугольников) и складывается линия графика.
function M.Math.LineSegment(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return (x1 + x2) / 2, (y1 + y2) / 2, math.sqrt(dx * dx + dy * dy), math.deg(math.atan2(dy, dx))
end

-- Аватарка убрана целиком: раньше это была локальная копия головы персонажа в ViewportFrame со своей Camera,
-- которая создавалась уже при запуске скрипта. Теперь на месте аватарки - обычный кружок в цвет темы, без
-- копирования персонажа, без ViewportFrame и без камеры.
function M.F.NewAvatarView(parent)
    local view = Instance.new("Frame")
    view.BackgroundColor3 = M.State.Accent
    view.BackgroundTransparency = 0.55
    view.BorderSizePixel = 0
    Instance.new("UICorner", view).CornerRadius = UDim.new(1, 0)
    view.Parent = parent
    return view
end

-- Записывает значение в состояние И обновляет элемент меню (тумблер, ползунок, список, палитру)
function M.F.SetStateVisual(key, value)
    M.State[key] = value
    for _, el in ipairs(M.Data.RegUI) do
        if el.Key == key and el.SetVisual then el.SetVisual(value) end
    end
end

-- Высота земли рядом с игроком. Если земля в этой точке слишком далеко от уровня игрока
-- (обрыв, крыша, пустота), берём уровень игрока, чтобы эффекты не уходили под карту.
function M.F.GroundHeightAt(x, z, referenceY)
    local origin = Vector3.new(x, referenceY + 120, z)
    local result = workspace:Raycast(origin, Vector3.new(0, -400, 0), M.RayParams)
    if result and math.abs(result.Position.Y - referenceY) <= 60 then
        return result.Position.Y
    end
    return referenceY
end

-- Одинаковы ли два значения. Roblox хранит числа и цвета как float32, поэтому после записи 0.7 обратно
-- читается 0.699999988... и обычное сравнение (~=) считает значения РАЗНЫМИ. Раньше из-за этого настройки
-- окружения перезаписывались заново каждые полсекунды: мерцание, подвисания и «выключение-включение» эффектов.
function M.F.SameValue(a, b)
    local kind = typeof(a)
    if kind ~= typeof(b) then return false end
    if kind == "number" then
        return math.abs(a - b) <= 0.0005 + 0.00001 * math.abs(a)
    elseif kind == "Color3" then
        return math.abs(a.R - b.R) <= 0.002 and math.abs(a.G - b.G) <= 0.002 and math.abs(a.B - b.B) <= 0.002
    elseif kind == "Vector3" then
        return (a - b).Magnitude <= 0.001
    elseif kind == "CFrame" then
        return (a.Position - b.Position).Magnitude <= 0.001 and (a.LookVector - b.LookVector).Magnitude <= 0.001
            and (a.UpVector - b.UpVector).Magnitude <= 0.001
    end
    return a == b
end

-- Записывает свойство, только если оно действительно отличается
function M.F.SetProp(inst, prop, value)
    if not M.F.SameValue(inst[prop], value) then inst[prop] = value end
end

-- Меняет основной цвет меню везде: полоски, ползунки, включённые переключатели, активную вкладку, мини-меню.
-- Пока меню закрыто, тяжёлую перекраску пропускаем (она выполнится при открытии).
function M.F.RecolorAccent(col)
    M.State.Accent = col
    M.Data.AccentVersion = M.Data.AccentVersion + 1
    if M.State.MenuOpen then
        for _, frame in ipairs(M.State.Sliders) do frame.BackgroundColor3 = col end
        for _, ref in ipairs(M.Data.ToggleRefs) do
            if ref.Track.Parent and ref.IsOn() then ref.Track.BackgroundColor3 = col end
        end
        local tab = M.State.TabButtons[M.State.ActiveTab]
        if tab then tab.TextColor3 = col end
        for _, stroke in pairs(M.Data.TabStrokes) do stroke.Color = col end
        M.F.SetTabIcon(M.State.ActiveTab, "active")
    end
end

-- ==============================================================================
-- [ ЛЕНИВАЯ ЗАГРУЗКА МОДУЛЕЙ ]
-- Модуль создаёт свои окна, объекты и подписки только пока он нужен. Включили функцию: модуль загрузился.
-- Выключили (или перестали пользоваться): всё уничтожено, подписки сняты, кэши и истории очищены.
-- Выключенная функция не создаёт ничего и не тратит кадры. Проверка идёт каждый кадр и состоит из пары сравнений.
-- ==============================================================================
M.Modules = {}
M.ModuleOrder = {}

function M.F.DefineModule(name, spec)
    M.Modules[name] = {Wanted = spec.Wanted, Load = spec.Load, Unload = spec.Unload, Loaded = false}
    table.insert(M.ModuleOrder, name)
end

function M.F.LoadModule(name)
    local module = M.Modules[name]
    if module and not module.Loaded then
        module.Loaded = true
        module.Load()
    end
end

function M.F.UnloadModule(name)
    local module = M.Modules[name]
    if module and module.Loaded then
        module.Loaded = false
        module.Unload()
    end
end

function M.F.SyncModules()
    for _, name in ipairs(M.ModuleOrder) do
        local module = M.Modules[name]
        local wanted = module.Wanted()
        if wanted and not module.Loaded then
            M.F.LoadModule(name)
        elseif not wanted and module.Loaded then
            M.F.UnloadModule(name)
        end
    end
end

function M.F.UnloadAllModules()
    for i = #M.ModuleOrder, 1, -1 do M.F.UnloadModule(M.ModuleOrder[i]) end
end

-- Снимает подписку и убирает её из общего списка (иначе список рос бы при каждой загрузке-выгрузке)
function M.F.Untrack(conn)
    for i = #M.Data.Conns, 1, -1 do
        if M.Data.Conns[i] == conn then table.remove(M.Data.Conns, i) end
    end
    conn:Disconnect()
end

-- Временные записи в реестре меню (подписи языка у виджетов): удаляются вместе с виджетом
function M.F.AddTempReg(owner, entry)
    owner.RegEntries = owner.RegEntries or {}
    table.insert(owner.RegEntries, entry)
    table.insert(M.Data.RegUI, entry)
end

function M.F.RemoveTempRegs(owner)
    for _, entry in ipairs(owner.RegEntries or {}) do
        for i = #M.Data.RegUI, 1, -1 do
            if M.Data.RegUI[i] == entry then table.remove(M.Data.RegUI, i) end
        end
    end
    owner.RegEntries = nil
end

-- Короткая запись: M.Conn(сигнал, функция) подключает событие и запоминает соединение
function M.Conn(signal, fn)
    return M.Track(signal:Connect(fn))
end

-- Поднимаемся от детали вверх, пока не найдём модель с Humanoid (это и есть персонаж)
function M.GetCharacterFromPart(part)
    local current = part
    while current and current ~= workspace do
        if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
            return current
        end
        current = current.Parent
    end
    return nil
end

-- Принадлежит ли объект нашим папкам (эффекты скрипта)
function M.IsOwned(obj)
    local current = obj
    while current and current ~= workspace do
        if M.Data.OwnFolderSet[current] then return true end
        current = current.Parent
    end
    return false
end

-- string:upper() не знает кириллицу, поэтому делаем свою версию
function M.Upper(str)
    local ok, result = pcall(function()
        local out = {}
        for _, cp in utf8.codes(str) do
            if cp >= 0x430 and cp <= 0x44F then
                cp = cp - 32
            elseif cp == 0x451 then
                cp = 0x401
            elseif cp >= 97 and cp <= 122 then
                cp = cp - 32
            end
            table.insert(out, utf8.char(cp))
        end
        return table.concat(out)
    end)
    return ok and result or str:upper()
end

M.State.OrigExp = M.Services.L.ExposureCompensation or 0
M.State.OrigFogStart = M.Services.L.FogStart or 0
M.State.OrigFogEnd = M.Services.L.FogEnd or 100000
M.State.OrigFogColor = M.Services.L.FogColor or Color3.new(0.8, 0.8, 0.8)
M.State.OrigOutdoorAmb = M.Services.L.OutdoorAmbient or Color3.fromRGB(128, 128, 128)
M.State.OrigTime = M.Services.L.ClockTime or 14
M.Data.OrigAmbient = M.Services.L.Ambient
M.Data.OrigGlobalShadows = M.Services.L.GlobalShadows

do
    -- Раньше скрипт сразу насильно ставил FOV 70. Теперь стартуем с FOV, который реально в игре
    local cam0 = workspace.CurrentCamera
    if cam0 then
        M.Data.GameFov = cam0.FieldOfView
        M.State.CamFov = math.clamp(math.round(cam0.FieldOfView), 30, 120)
    end
end

function M.Translate(key)
    local item = M.L10N.Dict[key]
    if item then return item[M.L10N.Current] or item["RU"] end
    return key
end

-- ==============================================================================
-- [ ШРИФТ ИНТЕРФЕЙСА ]
-- Список шрифтов в Настройках. У каждой надписи при первом изменении запоминается ИСХОДНЫЙ шрифт (Gotham, Medium,
-- Bold или Black), и выбранный стиль подбирает ему пару того же «веса»: заголовки остаются жирнее обычного текста.
--   Standard (Gotham)    - как было.
--   Chat (Arimo)         - гротеск, как шрифт этого чата: строгий нейтральный шрифт без засечек (в духе Arial и
--                          Helvetica). Раньше был Roboto, он на шрифт чата не похож.
--   Bold (Gotham Black)  - всё самым жирным начертанием Gotham, включая обычный текст.
--   Soft (Nunito)        - мягкий и округлый.
--   Code (Roboto Mono)   - моноширинный.
--   Lazy (Source Sans)   - «ленивый»: наклонное начертание (курсив).
--   Light (Roboto Light) - тонкий.
-- Шрифты берутся из встроенных семейств Roblox, ничего не загружается. Если семейство недоступно, ставится запасной.
-- Новые надписи (страницы меню строятся лениво, уведомления появляются позже) получают шрифт сразу при создании.
-- ==============================================================================
local FONT_CLASS = {Gotham = "R", GothamMedium = "M", GothamBold = "B", GothamBlack = "H"}
local FONT_SPECS = {
    Chat = {Family = "Arimo", R = Enum.FontWeight.Regular, M = Enum.FontWeight.Regular, B = Enum.FontWeight.Bold, H = Enum.FontWeight.Bold},
    Soft = {Family = "Nunito", R = Enum.FontWeight.Regular, M = Enum.FontWeight.SemiBold, B = Enum.FontWeight.Bold, H = Enum.FontWeight.ExtraBold},
    Code = {Family = "RobotoMono", R = Enum.FontWeight.Regular, M = Enum.FontWeight.Medium, B = Enum.FontWeight.Bold, H = Enum.FontWeight.Bold},
    Light = {Family = "Roboto", R = Enum.FontWeight.Light, M = Enum.FontWeight.Regular, B = Enum.FontWeight.Medium, H = Enum.FontWeight.Bold},
    Lazy = {Family = "SourceSansPro", Style = Enum.FontStyle.Italic, R = Enum.FontWeight.Regular, M = Enum.FontWeight.SemiBold, B = Enum.FontWeight.Bold, H = Enum.FontWeight.Bold},
    Bold = {Legacy = {R = Enum.Font.GothamBlack, M = Enum.Font.GothamBlack, B = Enum.Font.GothamBlack, H = Enum.Font.GothamBlack}}
}
local FONT_FALLBACK = {Chat = Enum.Font.Arial, Soft = Enum.Font.Nunito, Code = Enum.Font.RobotoMono, Light = Enum.Font.SourceSansLight, Lazy = Enum.Font.SourceSansItalic}

local function isTextObject(obj)
    return obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")
end

local function applyFontTo(obj)
    if not obj.Parent then return end
    local orig = M.Data.FontOrig[obj]
    local spec = FONT_SPECS[M.State.FontStyle]
    if not spec then
        -- Стандартный шрифт: возвращаем исходный тем надписям, которые мы меняли
        if orig then obj.Font = orig end
        return
    end
    if not orig then
        orig = obj.Font
        M.Data.FontOrig[obj] = orig
    end
    local class = FONT_CLASS[orig.Name] or "R"
    if spec.Legacy then
        obj.Font = spec.Legacy[class]
    else
        local ok = pcall(function() obj.FontFace = Font.fromName(spec.Family, spec[class], spec.Style or Enum.FontStyle.Normal) end)
        if not ok then obj.Font = FONT_FALLBACK[M.State.FontStyle] or orig end
    end
end

-- Применяет выбранный шрифт ко всем надписям интерфейса (или одного окна)
function M.F.ApplyFont(root)
    local roots = root and {root} or {M.UI.Gui, M.UI.NotifyGui, M.UI.WidgetGui}
    for _, gui in ipairs(roots) do
        for _, obj in ipairs(gui:GetDescendants()) do
            if isTextObject(obj) then applyFontTo(obj) end
        end
    end
end

-- Следит за окном: любая новая надпись получает выбранный шрифт. Пока шрифт стандартный, это одна проверка.
function M.F.WatchFonts(gui)
    if not gui then return end
    if FONT_SPECS[M.State.FontStyle] then M.F.ApplyFont(gui) end
    gui.DescendantAdded:Connect(function(obj)
        if FONT_SPECS[M.State.FontStyle] and isTextObject(obj) then
            -- Свойства надписи задаются сразу после создания: даём создателю закончить и только потом меняем шрифт
            task.defer(applyFontTo, obj)
        end
    end)
end

function M.IsTeammate(p)
    if not p then return false end
    if p == M.LP then return true end
    -- В играх без команд у всех игроков одинаковый TeamColor (белый), и старая проверка
    -- по цвету делала ВСЕХ "своими". Поэтому смотрим на команду, только если игроки в ней реально состоят.
    if M.LP.Neutral or p.Neutral then return false end
    local myTeam, hisTeam = M.LP.Team, p.Team
    return myTeam ~= nil and myTeam == hisTeam
end

-- Папки с нашими объектами лежат в workspace только тогда, когда в них что-то есть. Пока функции выключены,
-- в игре нет ни одной нашей папки: при запуске скрипт ничего в workspace не создаёт.
M.Data.FolderNames = {
    wFolder = M.Services.H:GenerateGUID(false),
    kFolder = M.Services.H:GenerateGUID(false),
    lFolder = M.Services.H:GenerateGUID(false),
    mFolder = M.Services.H:GenerateGUID(false),
    vFolder = M.Services.H:GenerateGUID(false),
    jFolder = M.Services.H:GenerateGUID(false)
}

function M.UpdateRaycast()
    local ignore = {}
    for key in pairs(M.Data.FolderNames) do
        local folder = M.UI[key]
        if folder and folder.Parent then table.insert(ignore, folder) end
    end
    local char = M.LP and M.LP.Character
    if char then
        table.insert(ignore, char)
    end
    M.RayParams.FilterDescendantsInstances = ignore
end

-- Возвращает нужную папку, создавая её при первом обращении
function M.F.Folder(key)
    local folder = M.UI[key]
    if folder and folder.Parent then return folder end
    folder = Instance.new("Folder")
    folder.Name = M.Data.FolderNames[key]
    folder.Parent = workspace
    M.UI[key] = folder
    M.Data.OwnFolderSet[folder] = true
    M.UpdateRaycast()
    return folder
end

-- Пустые папки уничтожаются
function M.F.ReleaseEmptyFolders()
    local changed = false
    for key in pairs(M.Data.FolderNames) do
        local folder = M.UI[key]
        if folder and folder.Parent and #folder:GetChildren() == 0 then
            M.Data.OwnFolderSet[folder] = nil
            folder:Destroy()
            M.UI[key] = nil
            changed = true
        end
    end
    if changed then M.UpdateRaycast() end
end

M.UpdateRaycast()

function M.SpawnJumpRing(originPos)
    if not M.State.JumpRings or not originPos then return end
    local ray = workspace:Raycast(originPos, Vector3.new(0, -12, 0), M.RayParams)
    local hitPos = ray and ray.Position or (originPos - Vector3.new(0, 3, 0))
    local hitNorm = ray and ray.Normal or Vector3.new(0, 1, 0)

    local ringModel = Instance.new("Model")
    ringModel.Name = "JumpRingEffect"
    ringModel.Parent = M.F.Folder("jFolder")

    local dur = math.clamp(M.State.JumpRingSpeed, 0.3, 3.0)
    local targetRad = M.State.JumpRingSize
    local glowMult = M.State.JumpRingGlow

    local function boostCol(c)
        return Color3.new(math.clamp(c.R * glowMult, 0, 1), math.clamp(c.G * glowMult, 0, 1), math.clamp(c.B * glowMult, 0, 1))
    end

    local upVec = (math.abs(hitNorm.Y) > 0.95) and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
    local rightVec = hitNorm:Cross(upVec).Unit
    local flatCFrame = CFrame.fromMatrix(hitPos + (hitNorm * 0.04), hitNorm, rightVec)

    if M.State.JumpRingType == "Filled" or M.State.JumpRingType == "Both" then
        local fillPart = Instance.new("Part")
        fillPart.Shape = Enum.PartType.Cylinder
        fillPart.Material = Enum.Material.Neon
        fillPart.Color = boostCol(M.State.JumpRingFillCol)
        fillPart.Transparency = 0.2
        fillPart.Size = Vector3.new(0.04, 0.8, 0.8)
        fillPart.CFrame = flatCFrame
        fillPart.CanCollide = false
        fillPart.CanTouch = false
        fillPart.CanQuery = false
        fillPart.CastShadow = false
        fillPart.Anchored = true
        fillPart.Parent = ringModel

        M.Services.T:Create(fillPart, TweenInfo.new(dur, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.04, targetRad * 2, targetRad * 2),
            Transparency = 1
        }):Play()
    end

    if M.State.JumpRingType == "Outline" or M.State.JumpRingType == "Both" then
        local anchor = Instance.new("Part")
        anchor.Size = Vector3.new(0.1, 0.1, 0.1)
        anchor.CFrame = CFrame.lookAt(hitPos + (hitNorm * 0.05), hitPos + (hitNorm * 2))
        anchor.Transparency = 1
        anchor.CanCollide = false
        anchor.CanTouch = false
        anchor.CanQuery = false
        anchor.CastShadow = false
        anchor.Anchored = true
        anchor.Parent = ringModel

        local cyl = Instance.new("CylinderHandleAdornment")
        cyl.Adornee = anchor
        cyl.Height = 0.04
        cyl.Radius = 0.6
        cyl.InnerRadius = 0.35
        cyl.Color3 = boostCol(M.State.JumpRingOutCol)
        cyl.Transparency = 0.05
        cyl.AlwaysOnTop = false
        cyl.ZIndex = 2
        cyl.Parent = anchor

        local startTime = os.clock()
        local twConn
        twConn = M.Services.R.RenderStepped:Connect(function()
            local p = (os.clock() - startTime) / dur
            if p >= 1 or not anchor.Parent then
                twConn:Disconnect()
                return
            end
            local curRadius = 0.6 + ((targetRad - 0.6) * M.Services.T:GetValue(p, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out))
            cyl.Radius = curRadius
            cyl.InnerRadius = math.max(curRadius - 0.45, 0.1)
            cyl.Transparency = 0.05 + (0.95 * p)
        end)
    end

    M.Services.D:AddItem(ringModel, dur + 0.15)
end

-- Игры отбрасывают персонажа «движителями»: BodyVelocity, LinearVelocity, VectorForce и им подобными.
-- AlignPosition и AlignOrientation сюда НЕ входят: на них держатся обычные механики игр (перенос, хваты и т.п.).
function M.F.IsMover(obj)
    return obj:IsA("BodyMover") or obj:IsA("LinearVelocity") or obj:IsA("VectorForce")
        or obj:IsA("AngularVelocity") or obj:IsA("Torque") or obj:IsA("LineForce")
end

function M.F.NeutralizeMover(obj)
    if obj:IsA("BodyMover") then
        obj:Destroy()
    else
        obj.Enabled = false
    end
end

-- Включена ли хоть одна из двух защит (анти-хит «Гасить сильные толчки» и анти-рагдол «Защита от падений»)
function M.F.AntiHitOn()
    return M.State.FallProtection or M.State.KnockbackProtection
end

-- Идёт ли «окно отбрасывания»: недавний урон по нам, обнаруженный улёт или падение персонажа. Только в этом окне мы
-- убираем чужие движители, чтобы не ломать собственные способности игры (рывки, ускорители, транспорт).
function M.F.InHitWindow(hum)
    local now = os.clock()
    if now < M.Data.FlingUntil or now - M.Data.LastDamage < 2.5 then return true end
    local state = hum and hum:GetState()
    return state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.PlatformStanding
end

-- ЗАЩИТА ОТ ОТБРАСЫВАНИЯ (анти-хит). Работает каждый кадр после физики (Heartbeat), до отправки положения на сервер.
--   * Чужой толчок (скорость за кадр резко выросла без вашей команды) отменяется: горизонтальная скорость
--     остаётся ТОЙ ЖЕ, какой была в прошлом кадре. Стояли на месте - остаётесь на месте.
--   * Позицию персонажа мы НЕ трогаем вообще (раньше откат позиции при телепорте игры уносил под землю и дёргал).
--   * Порог выше двойной скорости ходьбы: обычный разгон, разворот, прыжок и посадка фильтр не задевают.
--   * Если толчок приходит КАЖДЫЙ кадр (игра или сервер сами ведут персонажа), мы не воюем с ними: после
--     4 исправлений подряд фильтр делает паузу, иначе получилось бы дёрганье и замедление.
-- В транспорте и в полёте фильтр не работает.
function M.F.UpdateAntiFling(dt)
    local D = M.Data
    if not M.F.AntiHitOn() or M.State.IsDead or M.State.FlightMode then
        D.PrevVelocity, D.FixRun = nil, 0
        return
    end
    local char = M.LP and M.LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.SeatPart ~= nil or not (dt > 0) then
        D.PrevVelocity, D.FixRun = nil, 0
        return
    end

    local now = os.clock()
    if hum:GetState() == Enum.HumanoidStateType.Jumping then D.LastJump = now end
    local grounded = hum.FloorMaterial ~= Enum.Material.Air
    local prev, prevGrounded = D.PrevVelocity, D.PrevGrounded
    D.PrevGrounded = grounded
    local velocity = hrp.AssemblyLinearVelocity
    local inWindow = M.F.InHitWindow(hum)
    local fixed = false

    if prev and now >= D.GuardUntil then
        local walk = math.max(hum.WalkSpeed, 16)
        local flatNow = Vector3.new(velocity.X, 0, velocity.Z)
        local flatPrev = Vector3.new(prev.X, 0, prev.Z)

        local threshold = inWindow and math.max(34, walk * 2.1) or math.max(45, walk * 2.5)
        local side = (flatNow - flatPrev).Magnitude > threshold and flatNow.Magnitude > flatPrev.Magnitude + 5
        local up = (velocity.Y - prev.Y) > (inWindow and 40 or 70)
            and now - D.LastJump >= 0.25 and not (grounded and not prevGrounded)

        if side or up then
            local nx, ny, nz = velocity.X, velocity.Y, velocity.Z
            if side then nx, nz = prev.X, prev.Z end
            if up then
                -- Вертикаль продолжает прежнее движение под действием гравитации (с земли толчок просто гасится)
                ny = prevGrounded and math.min(prev.Y, 0) or (prev.Y - workspace.Gravity * dt)
            end
            hrp.AssemblyLinearVelocity = Vector3.new(nx, ny, nz)
            velocity = hrp.AssemblyLinearVelocity
            fixed = true
        end
    end

    -- Подряд идущие исправления = нас толкают каждый кадр. Уступаем, чтобы не дёргать и не тормозить персонажа.
    if fixed then
        D.FixRun = D.FixRun + 1
        if D.FixRun >= 4 then
            D.GuardUntil = now + 0.7
            D.FixRun = 0
        end
    else
        D.FixRun = 0
    end

    -- Запасные пределы на случай сверхсильного улёта (прыжок самой игры не срезается)
    local flat = Vector3.new(velocity.X, 0, velocity.Z)
    local limitFlat = math.max(140, M.State.SprintSpeed * 2.5)
    -- Скорость, которую вы сами выбрали для управления в воздухе, аварийным пределом не обрезается
    if M.State.AirControl then limitFlat = math.max(limitFlat, M.State.AirSpeed * 1.2) end
    local jumpVel = hum.UseJumpPower and hum.JumpPower or math.sqrt(2 * workspace.Gravity * hum.JumpHeight)
    local limitUp = math.max(80, jumpVel * 1.6)
    if now >= D.GuardUntil and (flat.Magnitude > limitFlat or velocity.Y > limitUp) then
        local cappedFlat = flat.Magnitude > limitFlat and flat.Unit * limitFlat or flat
        hrp.AssemblyLinearVelocity = Vector3.new(cappedFlat.X, math.min(velocity.Y, limitUp), cappedFlat.Z)
        D.FlingUntil = now + 1
    end
    if hrp.AssemblyAngularVelocity.Magnitude > 60 then
        hrp.AssemblyAngularVelocity = Vector3.zero
        D.FlingUntil = now + 1
    end
    D.PrevVelocity = hrp.AssemblyLinearVelocity
end

-- Встать после рагдола: снимаем PlatformStand и возвращаем нормальное состояние. GettingUp не используем:
-- из него персонаж мог провалиться в пол, если туловище лежало вплотную к земле.
function M.F.StandUp(h)
    if not h or h.Health <= 0 or h.SeatPart ~= nil or M.State.FlightMode then return end
    local now = os.clock()
    if now - M.Data.LastGetUp < 0.25 then return end
    M.Data.LastGetUp = now
    if h.PlatformStand then h.PlatformStand = false end
    local state = h:GetState()
    if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.PlatformStanding then
        h:ChangeState(h.FloorMaterial ~= Enum.Material.Air and Enum.HumanoidStateType.Running or Enum.HumanoidStateType.Freefall)
    end
end

function M.BindFallProtection(char)
    for _, conn in ipairs(M.Data.CharConns) do
        if conn then conn:Disconnect() end
    end
    M.Data.CharConns = {}
    if not char then return end

    local h = char:WaitForChild("Humanoid", 4)
    local r = char:WaitForChild("HumanoidRootPart", 4)
    if not h or not r then return end

    -- Движители, которые уже были у персонажа до удара, считаются «родными» механиками игры и не трогаются.
    -- Отключаем только те, что появились ВО ВРЕМЯ отбрасывания.
    M.Data.KnownMovers = setmetatable({}, {__mode = "k"})
    for _, d in ipairs(char:GetDescendants()) do
        if M.F.IsMover(d) then M.Data.KnownMovers[d] = true end
    end

    table.insert(M.Data.CharConns, h.StateChanged:Connect(function(_, newState)
        if h.Health <= 0 then return end
        if newState == Enum.HumanoidStateType.Jumping and M.State.JumpRings then
            M.SpawnJumpRing(r.Position)
        end
        -- Анти-рагдол: сразу выходим из состояний падения и бессилия
        if M.State.FallProtection and (newState == Enum.HumanoidStateType.Ragdoll or newState == Enum.HumanoidStateType.FallingDown
            or newState == Enum.HumanoidStateType.Physics or newState == Enum.HumanoidStateType.PlatformStanding) then
            task.defer(M.F.StandUp, h)
        end
    end))

    table.insert(M.Data.CharConns, char.DescendantAdded:Connect(function(desc)
        if h.Health <= 0 then return end
        if M.F.AntiHitOn() and M.F.IsMover(desc) then
            if M.F.InHitWindow(h) then
                task.defer(function() if desc.Parent then M.F.NeutralizeMover(desc) end end)
            else
                M.Data.KnownMovers[desc] = true
            end
        end
        if M.State.FallProtection then
            -- Суставы ragdoll-систем выключаем, а не удаляем: чужие детали игры не трогаем
            if desc:IsA("Constraint") and desc.Name:lower():find("ragdoll") then
                task.defer(function() if desc.Parent then desc.Enabled = false end end)
            end
            if desc:IsA("Motor6D") and not desc.Enabled then desc.Enabled = true end
        end
    end))
end

function M.F.ApplyHolo(char)
    if M.State.HoloSelf then
        M.Data.HoloApplied = true
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and M.Data.ValidLimbs[part.Name] and not part:FindFirstAncestorOfClass("Accessory") then
                if not M.Data.VisualOrig[part] then
                    M.Data.VisualOrig[part] = {Material = part.Material, Color = part.Color, Transparency = part.Transparency}
                end
                if part.Material ~= Enum.Material.ForceField then part.Material = Enum.Material.ForceField end
                M.F.SetProp(part, "Color", M.State.HoloColor)
                M.F.SetProp(part, "Transparency", M.State.HoloAlpha)
            end
        end
    elseif M.Data.HoloApplied then
        M.Data.HoloApplied = false
        for part, orig in pairs(M.Data.VisualOrig) do
            if part.Parent then
                part.Material = orig.Material
                part.Color = orig.Color
                part.Transparency = orig.Transparency
            end
        end
        table.clear(M.Data.VisualOrig)
    end
end

function M.F.ApplyHats()
    local function setAll(value)
        for _, plr in ipairs(M.Services.P:GetPlayers()) do
            local ch = plr.Character
            if ch then
                for _, item in ipairs(ch:GetChildren()) do
                    if item:IsA("Accessory") then
                        local handle = item:FindFirstChild("Handle")
                        if handle and handle:IsA("BasePart") then
                            handle.LocalTransparencyModifier = value
                        end
                    end
                end
            end
        end
    end

    if M.State.HideHats then
        M.Data.HatsHidden = true
        setAll(1)
    elseif M.Data.HatsHidden then
        M.Data.HatsHidden = false
        setAll(0)
    end
end

-- Раньше эта функция КАЖДЫЙ кадр насильно красила и делала видимым весь персонаж,
-- ломая игры с невидимостью. Теперь она трогает только то, что включил пользователь,
-- и один раз возвращает всё как было, когда функцию выключают.
function M.UpdatePlayerVisuals()
    local char = M.LP and M.LP.Character
    if char and char.Parent then
        M.F.ApplyHolo(char)
    end
    M.F.ApplyHats()
end

-- ФПС-буст. Что реально отнимает кадры, то и отключается (всё запоминается и возвращается при выключении):
--   * материалы и отражения деталей, тени деталей (CastShadow) и глобальные тени;
--   * частицы, шлейфы, дым, огонь, лучи (Beam), искры и ВСЕ источники света (PointLight, SpotLight, SurfaceLight);
--   * текстуры и наклейки;
--   * пост-эффекты игры (Bloom, Blur, DepthOfField, SunRays, ColorCorrection) и облака;
--   * трава на террейне, отражения и волны воды;
--   * качество графики Roblox снижается до минимального.
-- Новые объекты, появившиеся уже после включения, упрощаются тоже. Свои эффекты скрипта (Matsysense*) не трогаем.
function M.ApplyFpsBoost(enabled)
    M.State.FpsBoost = enabled
    M.Data.FpsBoostToken = M.Data.FpsBoostToken + 1
    local token = M.Data.FpsBoostToken

    for _, conn in ipairs(M.Data.FpsBoostConns) do conn:Disconnect() end
    M.Data.FpsBoostConns = {}

    local L = M.Services.L
    local terrain = workspace:FindFirstChildOfClass("Terrain")

    local function boost(obj)
        if obj:IsA("Terrain") then return end
        if obj:IsA("BasePart") then
            if M.Data.OriginalMaterials[obj] == nil then
                M.Data.OriginalMaterials[obj] = {Material = obj.Material, CastShadow = obj.CastShadow, Reflectance = obj.Reflectance}
            end
            obj.Material = Enum.Material.SmoothPlastic
            obj.CastShadow = false
            obj.Reflectance = 0
            if obj:IsA("MeshPart") then
                pcall(function()
                    if M.Data.TexCache[obj] == nil then
                        M.Data.TexCache[obj] = {Texture = obj.TextureID, Fidelity = obj.RenderFidelity}
                    end
                    obj.TextureID = ""
                    obj.RenderFidelity = Enum.RenderFidelity.Performance
                end)
            end
        elseif obj:IsA("SpecialMesh") then
            pcall(function()
                if M.Data.TexCache[obj] == nil then M.Data.TexCache[obj] = {Texture = obj.TextureId} end
                obj.TextureId = ""
            end)
        elseif obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
            pcall(function()
                if M.Data.TexCache[obj] == nil then
                    local original = obj:IsA("Shirt") and obj.ShirtTemplate or (obj:IsA("Pants") and obj.PantsTemplate or obj.Graphic)
                    M.Data.TexCache[obj] = {Cloth = original}
                end
                if obj:IsA("Shirt") then obj.ShirtTemplate = ""
                elseif obj:IsA("Pants") then obj.PantsTemplate = ""
                else obj.Graphic = "" end
            end)
        elseif obj:IsA("SurfaceAppearance") then
            pcall(function()
                if M.Data.TexCache[obj] == nil then
                    M.Data.TexCache[obj] = {Color = obj.ColorMap, Normal = obj.NormalMap, Metal = obj.MetalnessMap, Rough = obj.RoughnessMap}
                end
                obj.ColorMap, obj.NormalMap, obj.MetalnessMap, obj.RoughnessMap = "", "", "", ""
            end)
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            if M.Data.TextureCache[obj] == nil then
                M.Data.TextureCache[obj] = obj.Transparency
            end
            obj.Transparency = 1
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles")
            or obj:IsA("Beam") or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
            if M.Data.EmitterCache[obj] == nil then
                M.Data.EmitterCache[obj] = obj.Enabled
            end
            obj.Enabled = false
        end
    end

    local function boostLighting(obj)
        if obj == M.Data.FxGrade or obj == M.Data.FxBloom or obj == M.Data.FxRayBloom
            or obj == M.Data.FxSunRays or obj == M.Data.FxGlassBlur then return end
        if obj:IsA("PostEffect") then
            if M.Data.EffectCache[obj] == nil then M.Data.EffectCache[obj] = obj.Enabled end
            obj.Enabled = false
        end
    end

    if enabled then
        -- Освещение, террейн, облака и настройки графики (один раз запоминаем исходное)
        if not M.Data.BoostLighting then
            M.Data.BoostLighting = {GlobalShadows = L.GlobalShadows, EnvironmentSpecularScale = L.EnvironmentSpecularScale,
                ShadowSoftness = L.ShadowSoftness, EnvironmentDiffuseScale = L.EnvironmentDiffuseScale}
        end
        L.GlobalShadows = false
        pcall(function() L.EnvironmentSpecularScale = 0 end)
        pcall(function() L.ShadowSoftness = 0 end)
        pcall(function() L.EnvironmentDiffuseScale = 0 end)
        for _, child in ipairs(L:GetChildren()) do boostLighting(child) end

        if terrain then
            if not M.Data.BoostTerrain then
                M.Data.BoostTerrain = {
                    Decoration = terrain.Decoration, WaterReflectance = terrain.WaterReflectance,
                    WaterWaveSize = terrain.WaterWaveSize, WaterWaveSpeed = terrain.WaterWaveSpeed
                }
            end
            pcall(function()
                terrain.Decoration = false
                terrain.WaterReflectance = 0
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
            end)
            for _, child in ipairs(terrain:GetChildren()) do
                if child:IsA("Clouds") and child ~= M.Data.FxClouds then
                    if M.Data.EffectCache[child] == nil then M.Data.EffectCache[child] = child.Enabled end
                    child.Enabled = false
                end
            end
        end

        if M.Data.BoostQuality == nil then
            pcall(function()
                local rendering = settings().Rendering
                M.Data.BoostQuality = rendering.QualityLevel
                rendering.QualityLevel = Enum.QualityLevel.Level01
                pcall(function()
                    M.Data.BoostMeshDetail = rendering.MeshPartDetailLevel
                    rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
                end)
            end)
        end
        pcall(function()
            local materials = game:GetService("MaterialService")
            if M.Data.BoostMaterial2022 == nil then M.Data.BoostMaterial2022 = materials.Use2022Materials end
            materials.Use2022Materials = false
        end)

        table.insert(M.Data.FpsBoostConns, workspace.DescendantAdded:Connect(function(obj)
            if not M.IsOwned(obj) then boost(obj) end
        end))
        table.insert(M.Data.FpsBoostConns, L.ChildAdded:Connect(boostLighting))

        -- Карту проходим кусками, чтобы игра не зависала на больших картах
        local processed = 0
        for _, child in ipairs(workspace:GetChildren()) do
            if not M.Data.OwnFolderSet[child] then
                boost(child)
                for _, obj in ipairs(child:GetDescendants()) do
                    boost(obj)
                    processed = processed + 1
                    if processed % 1500 == 0 then
                        task.wait()
                        if token ~= M.Data.FpsBoostToken then return end
                    end
                end
            end
        end
    else
        for obj, saved in pairs(M.Data.OriginalMaterials) do
            if obj.Parent then
                obj.Material = saved.Material
                obj.CastShadow = saved.CastShadow
                obj.Reflectance = saved.Reflectance
            end
        end
        for obj, trans in pairs(M.Data.TextureCache) do
            if obj.Parent then obj.Transparency = trans end
        end
        for obj, saved in pairs(M.Data.TexCache) do
            if obj.Parent then
                pcall(function()
                    if obj:IsA("MeshPart") then
                        obj.TextureID = saved.Texture
                        obj.RenderFidelity = saved.Fidelity
                    elseif obj:IsA("SpecialMesh") then
                        obj.TextureId = saved.Texture
                    elseif saved.Cloth ~= nil then
                        if obj:IsA("Shirt") then obj.ShirtTemplate = saved.Cloth
                        elseif obj:IsA("Pants") then obj.PantsTemplate = saved.Cloth
                        else obj.Graphic = saved.Cloth end
                    elseif obj:IsA("SurfaceAppearance") then
                        obj.ColorMap, obj.NormalMap, obj.MetalnessMap, obj.RoughnessMap = saved.Color, saved.Normal, saved.Metal, saved.Rough
                    end
                end)
            end
        end
        table.clear(M.Data.TexCache)
        for obj, wasEnabled in pairs(M.Data.EmitterCache) do
            if obj.Parent then obj.Enabled = wasEnabled end
        end
        for obj, wasEnabled in pairs(M.Data.EffectCache) do
            if obj.Parent then obj.Enabled = wasEnabled end
        end
        table.clear(M.Data.OriginalMaterials)
        table.clear(M.Data.TextureCache)
        table.clear(M.Data.EmitterCache)
        table.clear(M.Data.EffectCache)

        local savedLighting = M.Data.BoostLighting
        if savedLighting then
            M.Data.BoostLighting = nil
            L.GlobalShadows = savedLighting.GlobalShadows
            pcall(function() L.EnvironmentSpecularScale = savedLighting.EnvironmentSpecularScale end)
            pcall(function() L.ShadowSoftness = savedLighting.ShadowSoftness end)
            pcall(function() L.EnvironmentDiffuseScale = savedLighting.EnvironmentDiffuseScale end)
        end
        local savedTerrain = M.Data.BoostTerrain
        if savedTerrain and terrain then
            M.Data.BoostTerrain = nil
            pcall(function()
                terrain.Decoration = savedTerrain.Decoration
                terrain.WaterReflectance = savedTerrain.WaterReflectance
                terrain.WaterWaveSize = savedTerrain.WaterWaveSize
                terrain.WaterWaveSpeed = savedTerrain.WaterWaveSpeed
            end)
        end
        if M.Data.BoostQuality ~= nil then
            local quality, meshDetail = M.Data.BoostQuality, M.Data.BoostMeshDetail
            M.Data.BoostQuality, M.Data.BoostMeshDetail = nil, nil
            pcall(function() settings().Rendering.QualityLevel = quality end)
            if meshDetail ~= nil then pcall(function() settings().Rendering.MeshPartDetailLevel = meshDetail end) end
        end
        if M.Data.BoostMaterial2022 ~= nil then
            local value = M.Data.BoostMaterial2022
            M.Data.BoostMaterial2022 = nil
            pcall(function() game:GetService("MaterialService").Use2022Materials = value end)
        end
    end
end

-- Снятие лимита кадров. Используется встроенная пользовательская настройка Roblox (FramerateCap): она меняется
-- только на вашем компьютере и ничего не отправляет серверу. Если Roblox не даёт скрипту её менять, покажем уведомление.
function M.ApplyFpsUnlocker(enabled)
    M.State.FpsUnlocker = enabled
    local ok = pcall(function()
        local settingsService = UserSettings():GetService("UserGameSettings")
        if enabled then
            if M.Data.OrigFpsCap == nil then M.Data.OrigFpsCap = settingsService.FramerateCap end
            settingsService.FramerateCap = 1000
        elseif M.Data.OrigFpsCap ~= nil then
            settingsService.FramerateCap = M.Data.OrigFpsCap
            M.Data.OrigFpsCap = nil
        end
    end)
    if enabled and not ok then
        M.State.FpsUnlocker = false
        for _, el in ipairs(M.Data.RegUI) do
            if el.Key == "FpsUnlocker" and el.SetVisual then el.SetVisual(false) end
        end
        M.F.Notify("FpsUnlocker", M.Translate("FpsUnlockFail"), false, true)
    end
end

function M.OnCharacterAdded(newChar)
    if not newChar then return end
    task.spawn(function()
        newChar:WaitForChild("HumanoidRootPart", 5)
        newChar:WaitForChild("Humanoid", 5)
        if M.State.IsShutDown or M.LP.Character ~= newChar then return end

        -- Новый персонаж = новые детали, поэтому "применено" сбрасываем
        table.clear(M.Data.WallPassOrig)
        table.clear(M.Data.VisualOrig)
        M.Data.PoseApplied = false
        M.Data.PoseAutoRotate = false
        M.Data.PoseStatesLocked = false
        M.Data.FallProtectionApplied = false
        M.Data.HoloApplied = false
        -- При самом первом запуске этот код (через task.spawn) может выполниться ДО того, как функции ниже по
        -- файлу определились (если персонаж уже существовал на момент инжекта и WaitForChild не стал ждать).
        -- Поэтому каждая функция вызывается только если она уже определена - иначе просто ждём следующего раза,
        -- вместо падения с ошибкой "attempt to call a nil value".
        M.BindFallProtection(newChar)
        M.UpdateRaycast()
        M.UpdatePlayerVisuals()
        if M.State.OrbitOn and type(M.F.RebuildOrbits) == "function" then M.F.RebuildOrbits() end
        if M.State.HatOn and type(M.F.RebuildWireHat) == "function" then M.F.RebuildWireHat() end
        if M.State.WalkThroughWalls and type(M.F.SetWallPass) == "function" then M.F.SetWallPass(true) end
        if M.State.FlightMode and type(M.F.StartFlying) == "function" then M.F.StartFlying() end
    end)
end

if M.LP and M.LP.Character then M.OnCharacterAdded(M.LP.Character) end
table.insert(M.Data.Conns, M.LP.CharacterAdded:Connect(M.OnCharacterAdded))
function M.TargetVisibility(targetPart, ownerChar)
    local cam = workspace.CurrentCamera
    if not cam or not targetPart then return false end
    local origin = cam.CFrame.Position
    local result = M.RaycastSolid(origin, targetPart.Position - origin)
    if not result then return true end
    return result.Instance:IsDescendantOf(ownerChar or targetPart.Parent)
end

-- Часть тела, в которую целимся: голова или корпус
function M.GetAimPart(char)
    if M.State.AimPart == "Body" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

function M.GetClosestTarget()
    if not M.State.AimAssist then return nil end
    local char = M.LP and M.LP.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end

    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local bestPart, bestDist = nil, math.huge
    local lock = M.Data.AimLock
    local lockDist = nil

    for _, p in ipairs(M.Services.P:GetPlayers()) do
        local pChar = p.Character
        if p ~= M.LP and pChar then
            local targetHum = pChar:FindFirstChildOfClass("Humanoid")
            local part = M.GetAimPart(pChar)
            if targetHum and targetHum.Health > 0 and part and not (M.State.AimTeamCheck and M.IsTeammate(p)) then
                local pos, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen and pos.Z > 0 then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    -- Для уже захваченной цели зона чуть шире, чтобы прицел не дёргался на границе
                    local limit = (part == lock) and (M.State.AimFov * 1.2) or M.State.AimFov
                    if dist <= limit and (not M.State.AimWallCheck or M.TargetVisibility(part, pChar)) then
                        if part == lock then lockDist = dist end
                        if dist < bestDist then
                            bestDist = dist
                            bestPart = part
                        end
                    end
                end
            end
        end
    end

    -- Залипание: пока прежняя цель подходит, не перескакиваем на другую из-за пары пикселей
    if lockDist and bestPart ~= lock and lockDist <= bestDist * 1.35 + 8 then
        bestPart = lock
    end
    M.Data.AimLock = bestPart
    return bestPart
end

local function IsAliveModel(model)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

-- Точка на экране, куда игрок реально целится. Если мышь заблокирована по центру (шифт-лок, первое лицо),
-- это центр экрана. Иначе игры берут позицию курсора, поэтому берём курсор.
function M.GetAimPoint(cam)
    if M.Services.U.MouseBehavior == Enum.MouseBehavior.LockCenter then
        return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    end
    return M.Services.U:GetMouseLocation()
end

-- Луч, который не упирается в невидимые некликабельные детали (триггеры, зоны, невидимые стены)
function M.RaycastSolid(origin, direction)
    local ignore = {}
    for i, inst in ipairs(M.RayParams.FilterDescendantsInstances) do ignore[i] = inst end
    for _ = 1, 4 do
        M.ScratchParams.FilterDescendantsInstances = ignore
        local result = workspace:Raycast(origin, direction, M.ScratchParams)
        if not result then return nil end
        local part = result.Instance
        local ghost = part.Transparency >= 0.95 and not part.CanCollide and not M.GetCharacterFromPart(part)
        if not ghost then return result end
        table.insert(ignore, part)
    end
    return nil
end

-- Ищет цель под прицелом. Возвращает: модель персонажа и точку на экране.
-- TriggerWallCheck включён: цель считается только если луч дошёл до неё без преград.
-- Выключен: стены игнорируются (луч проверяется отдельно для каждого игрока).
function M.GetTriggerTarget(cam)
    local point = M.GetAimPoint(cam)
    local ray = cam:ViewportPointToRay(point.X, point.Y)
    local direction = ray.Direction * 2000

    if M.State.TriggerWallCheck then
        local result = M.RaycastSolid(ray.Origin, direction)
        local model = result and M.GetCharacterFromPart(result.Instance)
        local owner = model and M.Services.P:GetPlayerFromCharacter(model)
        if owner and owner ~= M.LP and IsAliveModel(model) and not (M.State.TriggerTeamCheck and M.IsTeammate(owner)) then
            return model, point
        end
        return nil
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    for _, plr in ipairs(M.Services.P:GetPlayers()) do
        local ch = plr.Character
        if plr ~= M.LP and ch and IsAliveModel(ch) and not (M.State.TriggerTeamCheck and M.IsTeammate(plr)) then
            params.FilterDescendantsInstances = {ch}
            if workspace:Raycast(ray.Origin, direction, params) then
                return ch, point
            end
        end
    end
    return nil
end

-- Клик через VirtualUser: тот же ввод игрока, которым пользуется анти-АФК Roblox, поэтому он доступен в обычном
-- LocalScript без особых прав.
-- Порядок: CaptureController (без него игра ввод не получает) -> Button1Down -> короткая пауза -> Button1Up.
-- Если нажатие/отпускание дали ошибку, делается обычный ClickButton1. Кнопка отпускается ВСЕГДА, даже если нажатие
-- вызвало ошибку, чтобы она не оставалась зажатой. Возвращает true, если клик отправлен без ошибок.
function M.F.SendClick(cam)
    local vu = M.F.GetVirtualUser()
    if not vu then return false end
    local point = M.GetAimPoint(cam)
    local cframe = cam.CFrame

    local okCapture = pcall(function() vu:CaptureController() end)
    if not okCapture then return false end

    local okDown = pcall(function() vu:Button1Down(point, cframe) end)
    task.wait(0.05)
    local okUp = pcall(function() vu:Button1Up(point, cam.CFrame) end)
    if okDown and okUp then return true end

    -- Запасной вариант внутри VirtualUser: готовый одиночный клик
    if not okUp then pcall(function() vu:Button1Up(point, cam.CFrame) end) end
    return pcall(function() vu:ClickButton1(point, cam.CFrame) end)
end

-- Один выстрел. Возвращает true, если выстрел выполнен, и false, если он отменён.
-- Click: клик через VirtualUser (CaptureController + нажатие и отпускание кнопки мыши), сервер получает обычное
-- событие оружия, и урон засчитывается.
-- Tool: прямой вызов Tool:Activate() (срабатывает на вашем экране; нужен, если клик не работает в конкретной игре).
-- Перед самим выстрелом, уже после задержки, цель проверяется ещё раз: прицел за это время мог уйти с врага,
-- и тогда клик попал бы в пустоту. Позиция прицела берётся свежая, а не из момента, когда выстрел планировался.
-- Выстрел через мышь инжектора с учётом задержки, стен и команд
function M.F.FireTrigger()
    if M.State.TriggerDelay > 0 then task.wait(M.State.TriggerDelay) end

    if M.State.IsShutDown or M.State.MenuOpen or not M.State.TriggerAssist then return false end
    if M.Services.U:GetFocusedTextBox() then return false end -- блокировка при открытом чате

    local cam = workspace.CurrentCamera
    local char = M.LP and M.LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not cam or not hum or hum.Health <= 0 then return false end

    -- Повторная валидация цели перед кликом (проверка стен и тимы внутри GetTriggerTarget)
    local targetChar, point = M.GetTriggerTarget(cam)
    if not targetChar then return false end

    local fired = false
    M.Data.LastShot = os.clock()

    if M.State.TriggerMethod == "Click" then
        -- 1. Приоритет: чистый клик инжектора
        if typeof(mouse1click) == "function" then
            mouse1click()
            fired = true
        elseif typeof(mouse1press) == "function" and typeof(mouse1release) == "function" then
            mouse1press()
            task.wait(0.02)
            mouse1release()
            fired = true
        else
            -- Фоллбэк на VirtualUser, если чит-функции ввода недоступны
            fired = M.F.SendClick(cam)
        end
    end

    -- Альтернативный метод через активацию тула (если выбран метод Tool или не сработал клик)
    if not fired then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            local okTool = pcall(function() tool:Activate() end)
            fired = okTool
        end
    end

    task.wait(0.06)
    return fired
end
-- Защита от падений (анти-рагдол). Состояния падения (FallingDown, Ragdoll) отключаем ОДИН раз и возвращаем при
-- выключении. Всё остальное делается только сразу после урона или падения персонажа (окно отбрасывания), поэтому
-- обычное управление ничем не затрагивается. Позицию персонажа не трогаем: вы остаётесь там, где стояли.
function M.F.UpdateFallProtection()
    local D = M.Data
    if not M.State.FallProtection and not D.FallProtectionApplied then return end
    local char = M.LP and M.LP.Character
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local want = M.State.FallProtection and h ~= nil and h.Health > 0
    if want then
        if not D.FallProtectionApplied then
            D.FallProtectionApplied = true
            h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end
        local now = os.clock()
        local hit = M.F.InHitWindow(h)
        if hit then M.F.StandUp(h) end

        -- Ragdoll-системы выключают суставы (Motor6D) и включают свои ограничения: возвращаем суставы.
        -- В окне отбрасывания проверяем 5 раз в секунду, в обычное время раз в секунду.
        if now - D.LastMotorFix >= (hit and 0.2 or 1) then
            D.LastMotorFix = now
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("Motor6D") then
                    if not d.Enabled then d.Enabled = true end
                elseif hit and (d:IsA("BallSocketConstraint") or d:IsA("HingeConstraint")) and d.Enabled then
                    d.Enabled = false       -- суставы ragdoll-систем (у обычного персонажа таких нет)
                elseif d:IsA("Constraint") and d.Enabled and d.Name:lower():find("ragdoll") then
                    d.Enabled = false
                end
            end
        end
    elseif D.FallProtectionApplied then
        D.FallProtectionApplied = false
        if h then
            h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end
    end
end

-- Снятие оглушения: если игра на время обнуляет скорость бега или прыжок (оглушение после удара),
-- возвращаем последние нормальные значения. Игроки, управляющие своим персонажем, двигаются сами,
-- поэтому сервер принимает их позицию.
function M.F.UpdateAntiStun()
    if not M.State.AntiStun then
        M.Data.StunSince = nil
        return
    end
    local char = M.LP and M.LP.Character
    local h = char and char:FindFirstChildOfClass("Humanoid")
    if not M.State.AntiStun or not h or h.Health <= 0 then
        M.Data.StunSince = nil
        return
    end

    local gameWalk = M.F.GameWalkSpeed(h)
    if gameWalk > 1 then M.Data.NormalWalk = gameWalk end
    if h.UseJumpPower then
        if h.JumpPower > 1 then M.Data.NormalJump = h.JumpPower end
    elseif h.JumpHeight > 0.5 then
        M.Data.NormalJumpHeight = h.JumpHeight
    end

    local stunned = h.WalkSpeed <= 1 and M.Data.NormalWalk ~= nil
    if not stunned then
        M.Data.StunSince = nil
        return
    end
    M.Data.StunSince = M.Data.StunSince or os.clock()
    if os.clock() - M.Data.StunSince >= 0.2 then
        h.WalkSpeed = M.Data.NormalWalk
        if h.UseJumpPower and h.JumpPower <= 1 and M.Data.NormalJump then h.JumpPower = M.Data.NormalJump end
        if not h.UseJumpPower and h.JumpHeight <= 0.5 and M.Data.NormalJumpHeight then h.JumpHeight = M.Data.NormalJumpHeight end
    end
end

-- Позиция камеры на заданной дистанции позади точки фокуса, не заходя за стены.
-- Сквозь игроков, невидимые и некликабельные детали луч проходит: они камеру не двигают.
function M.F.OccludedCameraPosition(focus, backward, distance)
    local ignore = {}
    for i, inst in ipairs(M.RayParams.FilterDescendantsInstances) do ignore[i] = inst end
    for _ = 1, 4 do
        M.ScratchParams.FilterDescendantsInstances = ignore
        local hit = workspace:Raycast(focus, backward * distance, M.ScratchParams)
        if not hit then return focus + backward * distance end
        local part = hit.Instance
        local character = M.GetCharacterFromPart(part)
        if character or not part.CanCollide or part.Transparency >= 0.95 then
            table.insert(ignore, character or part)
        else
            return focus + backward * math.max(hit.Distance - 0.6, 1)
        end
    end
    return focus + backward * distance
end

-- Вид от третьего лица. Игры любят возвращать первое лицо (меняют CameraMode и зум каждый кадр),
-- поэтому нужные значения проверяются КАЖДЫЙ кадр, а исходные запоминаются один раз и возвращаются при выключении.
function M.F.UpdateThirdPerson(cam, hrp, h, active)
    if active and hrp and h then
        if not M.Data.TPApplied then
            M.Data.TPApplied = true
            M.Data.OrigCameraMode = M.LP.CameraMode
            M.Data.OrigZoomMin = M.LP.CameraMinZoomDistance
            M.Data.OrigZoomMax = M.LP.CameraMaxZoomDistance
        end
        if M.LP.CameraMode ~= Enum.CameraMode.Classic then
            M.LP.CameraMode = Enum.CameraMode.Classic
        end
        local dist = M.State.ThirdPersonDist
        if M.LP.CameraMinZoomDistance ~= dist or M.LP.CameraMaxZoomDistance ~= dist then
            M.LP.CameraMinZoomDistance = math.min(dist, M.LP.CameraMinZoomDistance)
            M.LP.CameraMaxZoomDistance = dist
            M.LP.CameraMinZoomDistance = dist
        end
        -- Камера должна смотреть на нашего персонажа (но сиденья и чужие цели не трогаем)
        local subject = cam.CameraSubject
        if not M.Data.Spectating and (subject == nil or (subject:IsA("Humanoid") and subject ~= h)) then
            cam.CameraSubject = h
        end
        -- ТОЧНАЯ ДИСТАНЦИЯ. Раньше она задавалась только пределами зума Player.CameraMin/MaxZoomDistance, а игра
-- может ограничивать их своими лимитами или стены прижимают камеру, поэтому дистанция бывала «не той».
-- Теперь камера ставится ровно на нужное расстояние позади точки фокуса (стены учитываются).
        local lookVector = cam.CFrame.LookVector
        local cameraPosition = M.F.OccludedCameraPosition(cam.Focus.Position, -lookVector, dist)
        cam.CFrame = CFrame.lookAt(cameraPosition, cameraPosition + lookVector)

        local poseOverride = M.State.SpinCharacter
        if not M.State.MenuOpen and not M.State.SpectateOn then
            M.Services.U.MouseBehavior = Enum.MouseBehavior.LockCenter
            if not poseOverride then
                if h.AutoRotate then h.AutoRotate = false end
                local _, ry, _ = cam.CFrame:ToOrientation()
                hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, ry, 0)
            end
        end
    elseif M.Data.TPApplied then
        M.Data.TPApplied = false
        M.LP.CameraMinZoomDistance = M.Data.OrigZoomMin
        M.LP.CameraMaxZoomDistance = M.Data.OrigZoomMax
        if M.Data.OrigCameraMode then M.LP.CameraMode = M.Data.OrigCameraMode end
        M.Services.U.MouseBehavior = Enum.MouseBehavior.Default
        local char = M.LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
    end
end

-- Автоматический выстрел (вызывается после доводки, чтобы прицел уже стоял на цели)
function M.F.UpdateTrigger(cam, isAlive)
    if not (M.State.TriggerAssist and not M.State.MenuOpen and isAlive) then
        M.Data.LastTriggerTarget = nil
        return
    end

    local curTarget = M.GetTriggerTarget(cam)
    if not curTarget then
        M.Data.LastTriggerTarget = nil
        return
    end

    if (M.State.TriggerLoop or curTarget ~= M.Data.LastTriggerTarget) and not M.Data.TriggerCD then
        M.Data.LastTriggerTarget = curTarget
        M.Data.TriggerCD = true
        task.spawn(function()
            -- pcall гарантирует, что кулдаун снимется, даже если выстрел вызвал ошибку.
            -- Если выстрел отменён или не удался, цель «забывается»: следующая попытка будет уже на следующем кадре,
            -- а не только после того, как вы наведётесь на другого игрока.
            local ok, fired = pcall(M.F.FireTrigger)
            if not (ok and fired) then M.Data.LastTriggerTarget = nil end
            M.Data.TriggerCD = false
        end)
    end
end

-- ==============================================================================
-- [ ВРАЩЕНИЕ И НАКЛОН ПЕРСОНАЖА: ИХ ВИДЯТ ВСЕ ]
-- Поворачивается КОРНЕВАЯ деталь персонажа (HumanoidRootPart). Её положение и поворот клиент-владелец сам отправляет
-- серверу, и их видят все игроки. Никаких отдельных запросов нет. Работает в Heartbeat: после физики и непосредственно
-- перед отправкой положения.
-- ==============================================================================
-- Следующий угол вращения (градусы)
function M.F.AdvanceSpin(dt)
    local speed = M.State.YawSpeed
    if M.State.JerkySpin then speed = speed + math.random(-25, 25) end
    M.Data.SpinAngle = (M.Data.SpinAngle + speed * dt * 25) % 360
end

-- Корень = поворот вокруг вертикали (рыскание) * наклон вперёд-назад. Рыскание берётся из текущего поворота
-- (ToOrientation возвращает порядок YXZ, поэтому наш же наклон на него не влияет).
function M.F.UpdatePoseReal(dt)
    local wantSpin, wantTilt = M.State.SpinCharacter, M.State.HeadTiltOn
    if not (wantSpin or wantTilt) and not M.Data.PoseApplied then return end

    local char = M.LP and M.LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local alive = hrp ~= nil and hum ~= nil and hum.Health > 0 and not M.State.IsShutDown
    if not hrp then
        M.Data.PoseApplied, M.Data.PoseAutoRotate = false, false
        return
    end

    if alive and (wantSpin or wantTilt) and not M.State.FlightMode then
        local _, yaw = hrp.CFrame:ToOrientation()
        if wantSpin then
            M.F.AdvanceSpin(dt)
            yaw = math.rad(M.Data.SpinAngle)
            -- Humanoid сам разворачивает персонажа по ходу движения и боролся бы с вращением
            if hum.AutoRotate then
                hum.AutoRotate = false
                M.Data.PoseAutoRotate = true
            end
        elseif M.Data.PoseAutoRotate then
            hum.AutoRotate = true
            M.Data.PoseAutoRotate = false
        end
        local pitch = wantTilt and math.rad(math.clamp(M.State.PitchAngle, -90, 90)) or 0
        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
        M.Data.PoseApplied = true
    elseif M.Data.PoseApplied then
        -- Выключили или умерли: ставим персонажа вертикально, поворот по вертикали остаётся
        M.Data.PoseApplied = false
        if alive then
            local _, yaw = hrp.CFrame:ToOrientation()
            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
        end
        if hum and M.Data.PoseAutoRotate then hum.AutoRotate = true end
        M.Data.PoseAutoRotate = false
    end
end

-- Приближение и свой FOV. Работает в самом конце кадра (Last), чтобы игра не успела перезаписать значение.
function M.F.UpdateFov(cam, dt)
    local zoomWanted = M.State.ZoomOn and M.Data.ZoomHeld and not M.State.MenuOpen
    M.Data.ZoomBlend = M.Math.Smooth(M.Data.ZoomBlend, zoomWanted and 1 or 0, dt, M.State.ZoomSpeed)

    local controlling = M.State.FovOn or M.Data.ZoomBlend > 0
    if not controlling then
        -- Ничего не трогаем: запоминаем FOV игры и, если раньше мы его держали, возвращаем один раз
        if M.Data.FovApplied then
            M.Data.FovApplied = false
            cam.FieldOfView = M.Data.GameFov
        else
            M.Data.GameFov = cam.FieldOfView
        end
        return
    end

    M.Data.FovApplied = true
    local base = M.State.FovOn and math.clamp(M.State.CamFov, 30, 120) or M.Data.GameFov
    local target = base + (math.clamp(M.State.ZoomFov, 10, 100) - base) * M.Data.ZoomBlend
    if math.abs(cam.FieldOfView - target) > 0.001 then
        cam.FieldOfView = target
    end
end

-- ==============================================================================
-- [ CAMERA AIM-ASSIST & FOV PIPELINE ]
-- ==============================================================================
-- Перед работой камеры Roblox снимаем прошлую тряску (подробности в M.F.ApplyShake)
pcall(function() M.Services.R:UnbindFromRenderStep("ShakeUndo") end)
M.Services.R:BindToRenderStep("ShakeUndo", Enum.RenderPriority.Camera.Value - 1, function()
    local cam = workspace.CurrentCamera
    if cam then M.F.UndoShake(cam) end
end)

pcall(function() M.Services.R:UnbindFromRenderStep("CamProcessor") end)
M.Services.R:BindToRenderStep("CamProcessor", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if M.State.IsShutDown then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    local char = M.LP and M.LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local isAlive = (hum ~= nil and hum.Health > 0)

    -- 1. Доводка прицела. Скорость не зависит от FPS: за AimTime мс камера проходит почти весь путь до цели.
    if M.State.AimAssist and not M.State.MenuOpen and isAlive then
        local target = M.GetClosestTarget()
        if target then
            local camCF = cam.CFrame
            if (target.Position - camCF.Position).Magnitude > 0.001 then
                local targetCF = CFrame.lookAt(camCF.Position, target.Position, Vector3.new(0, 1, 0))
                local tau = M.State.AimTime / 1000
                local factor = (tau <= 0) and 1 or (1 - math.exp(-3 * dt / tau))
                cam.CFrame = camCF:Lerp(targetCF, factor)
            end
        end
    else
        M.Data.AimLock = nil
    end

    -- 2. Третье лицо (после доводки, чтобы тело поворачивалось по итоговому взгляду)
    M.F.UpdateThirdPerson(cam, hrp, hum, M.State.ThirdPerson and isAlive)

    -- 3. Автоматический выстрел
    M.F.UpdateTrigger(cam, isAlive)

    -- 4. Скорость, урон по нам и тряска камеры (тряска идёт последней)
    -- Скорость и здоровье считаем, только если ими кто-то пользуется
    if M.State.SpeedWidgetOn then
        M.F.UpdateMoveSpeed(hrp, dt)
    elseif M.Data.LastPos then
        M.Data.LastPos, M.Data.MoveSpeed, M.Data.Speed3D = nil, 0, 0
        table.clear(M.Data.SpeedSamples)
    end
    if M.State.ShakeOn or M.State.HitFlashOn or M.State.FallProtection then
        M.F.UpdateSelfHealth(hum)
    else
        M.Data.LastHealth = nil
    end
    if M.State.ShakeOn or M.Data.ShakeEnergy > 0 then M.F.ApplyShake(cam, dt) end
end)

-- Страж окружения. Работает КАЖДЫЙ кадр в самом конце, но только СРАВНИВАЕТ значения (с допуском на float)
-- и записывает лишь то, что реально изменила игра. Если игра меняет свойство постоянно, наше значение всё равно
-- остаётся последним перед отрисовкой, поэтому мерцания «выкл-вкл» нет. Раньше проверка шла раз в полсекунды
-- и сравнивала числа без допуска, из-за чего эффекты перезаписывались заново и вызывали подвисания.
-- Пока открыто меню или идёт наблюдение, курсор всегда свободен: иначе игра, блокирующая мышь (шифт-лок,
-- первое лицо), не давала бы нажимать кнопки. Работает в конце кадра, поэтому блокировку игры перебивает.
function M.F.EnforceCursor()
    if M.F.CameraDragActive() then return end
    if M.State.MenuOpen or M.State.SpectateOn then
        local input = M.Services.U
        if input.MouseBehavior ~= Enum.MouseBehavior.Default then input.MouseBehavior = Enum.MouseBehavior.Default end
        if not input.MouseIconEnabled then input.MouseIconEnabled = true end
    end
end

function M.F.GuardEnvironment()
    local state = M.State
    if state.SkyOn then M.F.ApplySky(true) end
    if state.CloudsOn then M.F.ApplyClouds() end
    if state.FogOn then M.F.ApplyFog() end
    if state.SunRaysOn then M.F.ApplySunRays() end
    if state.GradeOn then M.F.ApplyGrade() end
    if state.BloomOn then M.F.ApplyBloom() end
    if state.DarkWorld then M.F.ApplyDark() end
    if state.TimeOn then M.F.SetProp(M.Services.L, "ClockTime", state.CustomTime) end
end

pcall(function() M.Services.R:UnbindFromRenderStep("FovProcessor") end)
M.Services.R:BindToRenderStep("FovProcessor", Enum.RenderPriority.Last.Value, function(dt)
    if M.State.IsShutDown then return end
    local cam = workspace.CurrentCamera
    if cam then M.F.UpdateFov(cam, dt) end
    M.F.GuardEnvironment()
    M.F.EnforceCursor()
end)

-- Удержание клавиши Z для приближения
M.Conn(M.Services.U.InputBegan, function(inp, processed)
    if inp.KeyCode == Enum.KeyCode.Z and not processed then M.Data.ZoomHeld = true end
end)
M.Conn(M.Services.U.InputEnded, function(inp)
    if inp.KeyCode == Enum.KeyCode.Z then M.Data.ZoomHeld = false end
end)

-- ==============================================================================
-- [ ИНТЕРФЕЙС ОТОБРАЖЕНИЯ ИГРОКОВ ]
-- ==============================================================================
-- Этот ScreenGui (рамки и подписи игроков, кружок прицела) создаётся только при первом реальном обращении:
-- при включении «Отображения игроков» или когда круг прицела впервые нужно показать. Пока обе функции выключены,
-- в PlayerGui ничего из этого нет.
function M.F.EnsurePlayerViewGui()
    if M.UI.PlayerViewGui then return end
    M.UI.PlayerViewGui = Instance.new("ScreenGui")
    M.UI.PlayerViewGui.Name = M.Services.H:GenerateGUID(false)
    M.UI.PlayerViewGui.ResetOnSpawn = false
    M.UI.PlayerViewGui.DisplayOrder = 100
    M.UI.PlayerViewGui.IgnoreGuiInset = true
    M.UI.PlayerViewGui.Parent = M.TargetGui

    M.UI.FovCircle = Instance.new("Frame")
    M.UI.FovCircle.Name = "AimFovCircle"
    M.UI.FovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    M.UI.FovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
    M.UI.FovCircle.BackgroundTransparency = 1
    M.UI.FovCircle.Visible = false
    M.UI.FovCircle.Parent = M.UI.PlayerViewGui
    Instance.new("UICorner", M.UI.FovCircle).CornerRadius = UDim.new(1, 0)

    M.UI.FovStroke = Instance.new("UIStroke", M.UI.FovCircle)
    M.UI.FovStroke.Color = Color3.fromRGB(255, 255, 255)
    M.UI.FovStroke.Thickness = 1
    M.UI.FovStroke.Transparency = 0.7
end

function M.F.SetupPlayerView(p)
    M.F.EnsurePlayerViewGui()
    local function initChar(char)
        if not char then return end
        local isSelf = (p == M.LP)

        -- Ждём Humanoid ДО создания рамок: при быстром респавне старые рамки раньше "терялись"
        local hum = char:WaitForChild("Humanoid", 10)
        -- Пока мы ждали, отображение игроков могли выключить или игрок мог респавниться
        if p.Character ~= char or not p.Parent or not M.Modules.PlayerView.Loaded then return end

        if M.State.Highlights[p] and M.State.Highlights[p].Parent then
            M.State.Highlights[p]:Destroy()
        end
        if M.State.PlayerViewGuis[p] and M.State.PlayerViewGuis[p].Container and M.State.PlayerViewGuis[p].Container.Parent then
            M.State.PlayerViewGuis[p].Container:Destroy()
        end
        if M.State.PlayerViewGuis[p] and M.State.PlayerViewGuis[p].PlayerLine and M.State.PlayerViewGuis[p].PlayerLine.Parent then
            M.State.PlayerViewGuis[p].PlayerLine:Destroy()
        end

        local hl = Instance.new("Highlight")
        hl.Name = M.Services.H:GenerateGUID(false)
        hl.Adornee = char
        hl.FillColor = M.State.PlayerViewFill
        hl.FillTransparency = M.State.PlayerViewAlpha
        hl.OutlineColor = M.State.PlayerViewLine
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = M.F.Folder("vFolder")
        M.State.Highlights[p] = hl

        local boxContainer = Instance.new("Frame")
        boxContainer.Name = M.Services.H:GenerateGUID(false)
        boxContainer.BackgroundTransparency = 1
        boxContainer.BorderSizePixel = 0
        boxContainer.Visible = false
        boxContainer.Parent = M.UI.PlayerViewGui

        local bStroke = Instance.new("UIStroke", boxContainer)
        bStroke.Color = M.State.PlayerViewBoxCol
        bStroke.Thickness = M.State.PlayerViewBoxThick

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Name = "NL"
        nameLbl.Size = UDim2.new(1, 40, 0, 16)
        nameLbl.AnchorPoint = Vector2.new(0.5, 1)
        nameLbl.Position = UDim2.new(0.5, 0, 0, -4)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = (isSelf and M.Translate("PV_You") or "") .. p.DisplayName
        nameLbl.TextColor3 = M.State.PlayerViewNameCol
        nameLbl.TextStrokeColor3 = M.State.PlayerViewNameOutCol
        nameLbl.TextStrokeTransparency = 0
        nameLbl.Font = (M.State.PlayerViewFontWeight == "Bold") and Enum.Font.GothamBold or Enum.Font.GothamMedium
        nameLbl.TextSize = M.State.PlayerViewTextSize
        nameLbl.Parent = boxContainer

        local barBg = Instance.new("Frame")
        barBg.Name = "HB_BG"
        barBg.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
        barBg.BorderSizePixel = 0
        barBg.Parent = boxContainer
        Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 2)

        local barFill = Instance.new("Frame")
        barFill.Name = "HB_FILL"
        barFill.BorderSizePixel = 0
        barFill.Parent = barBg
        Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 2)

        local hpLbl = Instance.new("TextLabel")
        hpLbl.Name = "HP_TXT"
        hpLbl.BackgroundTransparency = 1
        hpLbl.Font = Enum.Font.GothamBold
        hpLbl.TextSize = 11
        hpLbl.TextStrokeTransparency = 0
        hpLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        hpLbl.Parent = boxContainer

        local tracer = Instance.new("Frame")
        tracer.Name = M.Services.H:GenerateGUID(false)
        tracer.AnchorPoint = Vector2.new(0.5, 0.5)
        tracer.BackgroundColor3 = M.State.PlayerLineCol
        tracer.BorderSizePixel = 0
        tracer.Visible = false
        tracer.Parent = M.UI.PlayerViewGui

        M.State.PlayerViewGuis[p] = {
            Container = boxContainer,
            Stroke = bStroke,
            NameLabel = nameLbl,
            BarBg = barBg,
            BarFill = barFill,
            HpLabel = hpLbl,
            PlayerLine = tracer,
            Char = char,
            Hum = hum,
            IsSelf = isSelf,
            Player = p,
            BaseName = nameLbl.Text
        }
        M.F.UpdatePlayerView()
    end

    if p.Character then
        task.spawn(function() initChar(p.Character) end)
    end

    if M.State.PlayerConns[p] then
        M.State.PlayerConns[p]:Disconnect()
    end
    M.State.PlayerConns[p] = p.CharacterAdded:Connect(initChar)
end

function M.F.Update2DPreview()
    if not M.UI.PrevDummyContainer then return end
    if M.UI.PrevDummyTag then
        M.UI.PrevDummyTag.TextColor3 = M.State.PlayerViewNameCol
        M.UI.PrevDummyTag.TextStrokeColor3 = M.State.PlayerViewNameOutCol
        M.UI.PrevDummyTag.Font = (M.State.PlayerViewFontWeight == "Bold") and Enum.Font.GothamBold or Enum.Font.GothamMedium
        M.UI.PrevDummyTag.TextSize = M.State.PlayerViewTextSize
    end

    for _, f in ipairs(M.UI.PlayerView2DParts) do
        f.BackgroundColor3 = M.State.PlayerViewFill
        f.BackgroundTransparency = M.State.PlayerViewAlpha
        local strk = f:FindFirstChildOfClass("UIStroke")
        if strk then
            strk.Color = M.State.PlayerViewBoxCol
            strk.Thickness = M.State.PlayerViewBoxThick
        end
    end

    if M.UI.PrevHealthPack then
        local pack = M.UI.PrevHealthPack
        local isH = (M.State.PlayerViewHealthPos == "Bottom")
        local tSize = M.State.PlayerViewHealthBarThick

        pack.BarBg.Visible = M.State.PlayerViewHealthBar
        pack.HpLabel.Visible = M.State.PlayerViewHealthText

        if isH then
            pack.BarBg.Size = UDim2.new(1, 0, 0, tSize)
            pack.BarBg.Position = UDim2.new(0, 0, 1, 4)
            pack.BarFill.Size = UDim2.new(0.75, 0, 1, 0)
            pack.BarFill.Position = UDim2.new(0, 0, 0, 0)
            pack.HpLabel.Position = UDim2.new(0.5, 0, 1, tSize + 4)
            pack.HpLabel.AnchorPoint = Vector2.new(0.5, 0)
        elseif M.State.PlayerViewHealthPos == "Right" then
            pack.BarBg.Size = UDim2.new(0, tSize, 1, 0)
            pack.BarBg.Position = UDim2.new(1, 4, 0, 0)
            pack.BarFill.Size = UDim2.new(1, 0, 0.75, 0)
            pack.BarFill.Position = UDim2.new(0, 0, 0.25, 0)
            pack.HpLabel.Position = UDim2.new(1, tSize + 6, 0.25, 0)
            pack.HpLabel.AnchorPoint = Vector2.new(0, 0.5)
        else
            pack.BarBg.Size = UDim2.new(0, tSize, 1, 0)
            pack.BarBg.Position = UDim2.new(0, -(tSize + 4), 0, 0)
            pack.BarFill.Size = UDim2.new(1, 0, 0.75, 0)
            pack.BarFill.Position = UDim2.new(0, 0, 0.25, 0)
            pack.HpLabel.AnchorPoint = Vector2.new(1, 0.5)
            pack.HpLabel.Position = UDim2.new(0, -(tSize + 6), 0.25, 0)
            pack.HpLabel.TextXAlignment = Enum.TextXAlignment.Right
        end

        pack.BarFill.BackgroundColor3 = M.State.PlayerViewHealthCol
        pack.HpLabel.Text = "100 HP"
        pack.HpLabel.TextColor3 = M.State.PlayerViewHealthCol
    end
end

function M.F.UpdatePlayerView()
    for p, hl in pairs(M.State.Highlights) do
        if hl and hl.Parent then
            local isSelf = (p == M.LP)
            local allowed = M.State.PlayerView and (not isSelf or M.State.PlayerViewOnSelf)
            if M.State.PlayerViewTeamCheck and M.IsTeammate(p) and not isSelf then allowed = false end

            hl.Enabled = allowed
            hl.FillColor = M.State.PlayerViewFill
            hl.FillTransparency = M.State.PlayerViewAlpha
            hl.OutlineColor = M.State.PlayerViewLine
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        end
    end

    for _, pack in pairs(M.State.PlayerViewGuis) do
        if pack and pack.Container then
            local isSelf = pack.IsSelf
            local allowed = M.State.PlayerView and (not isSelf or M.State.PlayerViewOnSelf)
            if M.State.PlayerViewTeamCheck and not isSelf and M.IsTeammate(pack.Player) then allowed = false end

            pack.Container.Visible = allowed and M.State.PlayerViewBox
            pack.Stroke.Color = M.State.PlayerViewBoxCol
            pack.Stroke.Thickness = M.State.PlayerViewBoxThick

            pack.NameLabel.TextColor3 = M.State.PlayerViewNameCol
            pack.NameLabel.TextStrokeColor3 = M.State.PlayerViewNameOutCol
            pack.NameLabel.Font = (M.State.PlayerViewFontWeight == "Bold") and Enum.Font.GothamBold or Enum.Font.GothamMedium
            pack.NameLabel.TextSize = M.State.PlayerViewTextSize

            if pack.PlayerLine then
                pack.PlayerLine.BackgroundColor3 = M.State.PlayerLineCol
            end
        end
    end
    M.F.Update2DPreview()
end

-- Убирает всё оформление отображения одного игрока
function M.F.RemovePlayerView(p)
    if M.State.Highlights[p] and M.State.Highlights[p].Parent then M.State.Highlights[p]:Destroy() end
    M.State.Highlights[p] = nil
    if M.State.PlayerViewGuis[p] then
        if M.State.PlayerViewGuis[p].Container and M.State.PlayerViewGuis[p].Container.Parent then M.State.PlayerViewGuis[p].Container:Destroy() end
        if M.State.PlayerViewGuis[p].PlayerLine and M.State.PlayerViewGuis[p].PlayerLine.Parent then M.State.PlayerViewGuis[p].PlayerLine:Destroy() end
    end
    M.State.PlayerViewGuis[p] = nil
    if M.State.PlayerConns[p] then M.State.PlayerConns[p]:Disconnect(); M.State.PlayerConns[p] = nil end
end

-- Отображение игроков не создаёт ничего (ни рамок, ни подсветки, ни подписок на игроков), пока он выключен.
-- При включении оформление строится для всех игроков, при выключении уничтожается полностью.
M.F.DefineModule("PlayerView", {
    Wanted = function() return M.State.PlayerView end,
    Load = function()
        for _, p in ipairs(M.Services.P:GetPlayers()) do M.F.SetupPlayerView(p) end
        table.insert(M.Data.PlayerViewConns, M.Services.P.PlayerAdded:Connect(function(p)
            if M.Modules.PlayerView.Loaded then M.F.SetupPlayerView(p) end
        end))
        table.insert(M.Data.PlayerViewConns, M.Services.P.PlayerRemoving:Connect(M.F.RemovePlayerView))
    end,
    Unload = function()
        for _, conn in ipairs(M.Data.PlayerViewConns) do conn:Disconnect() end
        M.Data.PlayerViewConns = {}
        local players = {}
        for p in pairs(M.State.Highlights) do players[p] = true end
        for p in pairs(M.State.PlayerViewGuis) do players[p] = true end
        for p in pairs(M.State.PlayerConns) do players[p] = true end
        for p in pairs(players) do M.F.RemovePlayerView(p) end
    end
})

function M.F.ClearWeatherProps()
    for _, item in ipairs(M.State.WeatherPool) do if item.Part then item.Part:Destroy() end end
    M.State.WeatherPool = {}
end

function M.F.UpdateWeatherProps(dt)
    if not M.State.WeatherOn then
        if #M.State.WeatherPool > 0 then M.F.ClearWeatherProps() end
        return
    end

    local cam = workspace.CurrentCamera
    local char = M.LP and M.LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local origin = (root and root.Position) or (cam and cam.CFrame.Position)
    if not origin then return end

    local vel = (root and root.AssemblyLinearVelocity) or Vector3.zero
    local center = origin + (Vector3.new(vel.X, 0, vel.Z) * 0.4)
    local targetCount = M.State.WeatherDensity
    local radiusBound = math.clamp(M.State.WeatherRadius, 15, 250)

    if #M.State.WeatherPool < targetCount then
        for _ = 1, (targetCount - #M.State.WeatherPool) do
            local p = Instance.new("Part")
            p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
            p.Anchored = true; p.Material = Enum.Material.Neon; p.Parent = M.F.Folder("wFolder")

            local ang = math.rad(math.random(0, 360))
            local rad = math.random(4, radiusBound)
            local pos = center + Vector3.new(math.cos(ang) * rad, math.random(15, 55), math.sin(ang) * rad)
            p.Position = pos
            table.insert(M.State.WeatherPool, {Part = p, Pos = pos, Seed = math.random() * 10})
        end
    elseif #M.State.WeatherPool > targetCount then
        for _ = 1, (#M.State.WeatherPool - targetCount) do
            local item = table.remove(M.State.WeatherPool)
            if item and item.Part then item.Part:Destroy() end
        end
    end

    local isSnow = (M.State.WeatherMode == "Snow")
    local fallSpd = isSnow and (M.State.WeatherSpeed * 0.6 + 8) or (M.State.WeatherSpeed * 2.0 + 60)
    -- "Подпись" внешнего вида: пока она не изменилась, размер и цвет частиц заново не выставляем
    local visualSig = table.concat({tostring(isSnow), M.State.SnowSize, M.State.WeatherColor:ToHex(), math.floor(fallSpd)}, "|")
    for i = 1, #M.State.WeatherPool do
        local it = M.State.WeatherPool[i]
        local p = it.Part
        if p and p.Parent then
            it.Pos = it.Pos - Vector3.new(0, fallSpd * dt, 0)
            if isSnow then
                local t = os.clock() * 2 + it.Seed
                it.Pos = it.Pos + Vector3.new(math.sin(t) * 0.12, 0, math.cos(t) * 0.12)
            end
            if it.Sig ~= visualSig then
                it.Sig = visualSig
                p.Color = M.State.WeatherColor
                if isSnow then
                    p.Shape = Enum.PartType.Ball
                    p.Size = Vector3.new(M.State.SnowSize, M.State.SnowSize, M.State.SnowSize)
                    p.Transparency = 0.15
                else
                    p.Shape = Enum.PartType.Block
                    p.Size = Vector3.new(0.08, math.clamp(fallSpd * 0.03, 1.2, 3.2), 0.08)
                    p.Transparency = 0.25
                end
            end
            p.CFrame = CFrame.new(it.Pos)

            if it.Pos.Y < origin.Y + 1.5 or (Vector3.new(it.Pos.X, 0, it.Pos.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude > radiusBound then
                local ang = math.rad(math.random(0, 360))
                local rad = math.random(4, radiusBound)
                it.Pos = center + Vector3.new(math.cos(ang) * rad, math.random(25, 55), math.sin(ang) * rad)
            end
        end
    end
end

-- ==============================================================================
-- [ ЛУЧИ СВЕТА, ЯРКИЙ МИР, ВЗРЫВ МЕТЕОРИТА ]
-- ==============================================================================

-- Лучи солнца/луны как в RTX: SunRaysEffect (сами лучи) + BloomEffect (свечение вокруг ярких мест).
-- Интенсивность и длина лучей - у SunRaysEffect, яркость свечения - у Bloom.
function M.F.ApplySunRays()
    pcall(function()
        local L = M.Services.L
        local rays = M.Data.FxSunRays and M.Data.FxSunRays.Parent and M.Data.FxSunRays
        local bloom = M.Data.FxRayBloom and M.Data.FxRayBloom.Parent and M.Data.FxRayBloom

        if M.State.SunRaysOn then
            if not rays then
                rays = Instance.new("SunRaysEffect")
                rays.Parent = L
                M.Data.FxSunRays = rays
            end
            if not bloom then
                bloom = Instance.new("BloomEffect")
                bloom.Parent = L
                M.Data.FxRayBloom = bloom
            end
            local glow = math.clamp(M.State.SunRaysBright, 0, 1)
            M.F.SetProp(rays, "Intensity", math.clamp(M.State.SunRaysIntensity, 0, 1))
            M.F.SetProp(rays, "Spread", math.clamp(M.State.SunRaysSpread, 0, 1))
            M.F.SetProp(bloom, "Intensity", 0.15 + glow * 1.1)
            M.F.SetProp(bloom, "Size", 18 + glow * 40)
            M.F.SetProp(bloom, "Threshold", 1.9 - glow * 1.1)
        else
            if rays then rays:Destroy() end
            if bloom then bloom:Destroy() end
            M.Data.FxSunRays, M.Data.FxRayBloom = nil, nil
        end
    end)
end

-- Взрыв в месте падения метеорита: вспышка-шар, ударная волна и всплеск света
function M.F.SpawnImpact(pos)
    local size = M.State.MeteorSize
    local color = M.State.MeteorColor

    local function fx(part)
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Material = Enum.Material.Neon
        part.Color = color
        return part
    end

    local blast = fx(Instance.new("Part"))
    blast.Shape = Enum.PartType.Ball
    blast.Size = Vector3.new(size, size, size)
    blast.Transparency = 0.15
    blast.CFrame = CFrame.new(pos)
    blast.Parent = M.F.Folder("mFolder")

    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = 8
    light.Range = size * 12
    light.Parent = blast

    local ring = fx(Instance.new("Part"))
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.4, size * 2, size * 2)
    ring.Color = Color3.fromRGB(255, 235, 200)
    ring.Transparency = 0.35
    -- Цилиндр лежит вдоль оси X; поворот на 90 градусов делает его плоским диском на земле
    ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
    ring.Parent = M.F.Folder("mFolder")

    local big = size * 7
    local out = Enum.EasingDirection.Out
    M.Services.T:Create(blast, TweenInfo.new(0.7, Enum.EasingStyle.Quad, out), {Size = Vector3.new(big, big, big), Transparency = 1}):Play()
    M.Services.T:Create(light, TweenInfo.new(0.7, Enum.EasingStyle.Quad, out), {Brightness = 0}):Play()
    M.Services.T:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quad, out), {Size = Vector3.new(0.4, size * 16, size * 16), Transparency = 1}):Play()
    M.Services.D:AddItem(blast, 1.0)
    M.Services.D:AddItem(ring, 1.2)
end

function M.F.StrikeLightning()
    local cam = workspace.CurrentCamera
    local char = M.LP and M.LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local origin = (root and root.Position) or (cam and cam.CFrame.Position)
    if not origin then return end

    local dist = math.random(80, 400)
    local angle = math.rad(math.random(0, 360))
    -- Высота земли в точке удара берётся лучом вниз: раньше удар шёл на высоте игрока и мог оказаться под картой
    local groundX = origin.X + math.cos(angle) * dist
    local groundZ = origin.Z + math.sin(angle) * dist
    local strikeGround = Vector3.new(groundX, M.F.GroundHeightAt(groundX, groundZ, origin.Y), groundZ)
    local startSky = strikeGround + Vector3.new(math.random(-25, 25), math.random(180, 280), math.random(-25, 25))

    local bolt = Instance.new("Model")
    bolt.Name = "LightningBolt"

    local segments = 6
    local curPt = startSky
    local boltParts = {}

    for i = 1, segments do
        local target = startSky:Lerp(strikeGround, i / segments)
        if i < segments then
            target = target + Vector3.new(math.random(-12, 12), math.random(-4, 4), math.random(-12, 12))
        end

        local seg = Instance.new("Part")
        seg.Size = Vector3.new(M.State.LightningSize, M.State.LightningSize, (target - curPt).Magnitude)
        seg.Material = Enum.Material.Neon
        seg.Color = Color3.fromRGB(240, 248, 255)
        seg.CanCollide = false
        seg.CanTouch = false
        seg.CanQuery = false
        seg.CastShadow = false
        seg.Anchored = true
        seg.CFrame = CFrame.new((curPt + target) / 2, target)
        seg.Parent = bolt

        table.insert(boltParts, seg)
        curPt = target
    end

    local hl = Instance.new("Highlight")
    hl.Adornee = bolt
    hl.FillColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineColor = Color3.fromRGB(200, 235, 255)
    hl.FillTransparency = 0.05
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = bolt

    bolt.Parent = M.F.Folder("lFolder")

    if M.State.LightningFlash then M.F.ScreenFlash(M.State.LightningFlashPower) end

    local fadeDur = 0.45
    M.Services.D:AddItem(bolt, M.State.LightningDuration + fadeDur + 0.1)

    task.delay(M.State.LightningDuration, function()
        if not bolt.Parent then return end
        local fadeInfo = TweenInfo.new(fadeDur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        for _, part in ipairs(boltParts) do
            if part.Parent then
                M.Services.T:Create(part, fadeInfo, {
                    Transparency = 1,
                    Size = Vector3.new(0.01, 0.01, part.Size.Z)
                }):Play()
            end
        end
        M.Services.T:Create(hl, fadeInfo, {FillTransparency = 1, OutlineTransparency = 1}):Play()
    end)
end

function M.F.SpawnMeteor()
    local cam = workspace.CurrentCamera
    local char = M.LP and M.LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local originPos = (root and root.Position) or (cam and cam.CFrame.Position)
    if not originPos then return end

    -- Сначала выбираем точку падения рядом с игроком и находим там землю. Раньше метеорит летел по прямой
    -- с фиксированной длиной и часто заканчивал путь глубоко под картой.
    local impactAngle = math.rad(math.random(0, 360))
    local impactDist = math.random(40, 200)
    local impactX = originPos.X + math.cos(impactAngle) * impactDist
    local impactZ = originPos.Z + math.sin(impactAngle) * impactDist
    local impactPos = Vector3.new(impactX, M.F.GroundHeightAt(impactX, impactZ, originPos.Y), impactZ)

    -- Старт высоко в небе так, чтобы угол падения был 25-40 градусов
    local height = math.random(220, 420)
    local dropAngle = math.rad(math.random(25, 40))
    local approach = math.rad(math.random(0, 360))
    local horizontal = height / math.tan(dropAngle)
    local startPos = impactPos + Vector3.new(math.cos(approach) * horizontal, height, math.sin(approach) * horizontal)

    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(M.State.MeteorSize, M.State.MeteorSize, M.State.MeteorSize)
    p.Material = Enum.Material.Neon; p.Color = M.State.MeteorColor
    -- Anchored обязателен: иначе гравитация тянет метеорит вниз и спорит с анимацией полёта
    p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
    p.CFrame = CFrame.new(startPos); p.Parent = M.F.Folder("mFolder")

    local a0 = Instance.new("Attachment", p); a0.Position = Vector3.new(0, M.State.MeteorSize * 0.45, 0)
    local a1 = Instance.new("Attachment", p); a1.Position = Vector3.new(0, -M.State.MeteorSize * 0.45, 0)
    local trail = Instance.new("Trail")
    trail.Attachment0 = a0; trail.Attachment1 = a1; trail.Lifetime = M.State.MeteorTrailLen; trail.LightEmission = 1.0
    trail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, M.State.MeteorColor),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 205, 80)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 255, 255))
    })
    trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0.0, 1.2), NumberSequenceKeypoint.new(0.6, 0.4), NumberSequenceKeypoint.new(1.0, 0.0)})
    trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.0, 0.0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1.0, 1.0)})
    trail.Parent = p

    local tw = M.Services.T:Create(p, TweenInfo.new(M.State.MeteorDuration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(impactPos)})
    tw:Play()
    tw.Completed:Connect(function()
        if M.State.MeteorImpact and not M.State.IsShutDown then M.F.SpawnImpact(impactPos) end
        p:Destroy()
    end)
    M.Services.D:AddItem(p, M.State.MeteorDuration + 0.1)
end

function M.F.RebuildOrbits()
    for _, item in ipairs(M.State.OrbitObjs) do if item.Part then item.Part:Destroy() end end
    M.State.OrbitObjs = {}
    if not M.State.OrbitOn then return end

    local pCol = M.State.OrbitColor
    local tCol = M.State.OrbitTrailColor
    for i = 1, M.State.OrbitCount do
        local p = Instance.new("Part")
        p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(M.State.OrbitSize, M.State.OrbitSize, M.State.OrbitSize)
        p.Material = Enum.Material.Neon; p.Color = pCol; p.CanCollide = false; p.CastShadow = false; p.Anchored = true; p.Parent = M.F.Folder("vFolder")

        local a0 = Instance.new("Attachment", p); a0.Position = Vector3.new(0, M.State.OrbitSize * 0.45 * (M.State.OrbitTrailThick / 0.35), 0)
        local a1 = Instance.new("Attachment", p); a1.Position = Vector3.new(0, -M.State.OrbitSize * 0.45 * (M.State.OrbitTrailThick / 0.35), 0)
        local tr = Instance.new("Trail")
        tr.Attachment0 = a0; tr.Attachment1 = a1; tr.Lifetime = M.State.OrbitTrailLen; tr.LightEmission = 1
        tr.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, tCol), ColorSequenceKeypoint.new(1, tCol)})
        tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1)})
        tr.Parent = p

        table.insert(M.State.OrbitObjs, {
            Part = p, A0 = a0, A1 = a1,
            Phase = (i / M.State.OrbitCount) * (math.pi * 2),
            SpeedX = 1 + (i * 0.35), SpeedY = 1.3 - (i * 0.25), SpeedZ = 0.8 + (i * 0.4), Trail = tr
        })
    end
end

function M.F.UpdateOrbitsVisualLive()
    local pCol = M.State.OrbitColor
    local tCol = M.State.OrbitTrailColor
    for _, d in ipairs(M.State.OrbitObjs) do
        if d.Part and d.Part.Parent then
            d.Part.Color = pCol
            d.A0.Position = Vector3.new(0, M.State.OrbitSize * 0.45 * (M.State.OrbitTrailThick / 0.35), 0)
            d.A1.Position = Vector3.new(0, -M.State.OrbitSize * 0.45 * (M.State.OrbitTrailThick / 0.35), 0)
            if d.Trail then
                d.Trail.Lifetime = M.State.OrbitTrailLen
                d.Trail.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, tCol), ColorSequenceKeypoint.new(1, tCol)})
            end
        end
    end
end

function M.F.RebuildWireHat()
    if M.State.HatModel then M.State.HatModel:Destroy(); M.State.HatModel = nil end
    local char = M.LP and M.LP.Character
    if not M.State.HatOn or not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local model = Instance.new("Model"); model.Name = "WireHat"; model.Parent = M.F.Folder("vFolder")
    local baseCol = M.State.HatColor
    local rootCFrame = head.CFrame * CFrame.new(0, M.State.HatHeight, 0)
    local R, H, lineThick = 2.0 * M.State.HatSize, 0.85 * M.State.HatSize, 0.03 * M.State.HatSize
    local segs = 64

    local function makeLine(p1, p2)
        local rod = Instance.new("Part")
        rod.Size = Vector3.new(lineThick, lineThick, (p2 - p1).Magnitude)
        rod.Material = Enum.Material.Neon; rod.Color = baseCol
        rod.CanCollide = false; rod.CanTouch = false; rod.CanQuery = false; rod.CastShadow = false; rod.Massless = true
        rod.CFrame = rootCFrame * CFrame.new((p1 + p2) / 2, p2)
        rod.Parent = model
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = rod; weld.Part1 = head; weld.Parent = rod
    end

    local rimPoints, midPoints = {}, {}
    for i = 1, segs do
        local ang = (i / segs) * (math.pi * 2)
        rimPoints[i] = Vector3.new(math.cos(ang) * R, 0, math.sin(ang) * R)
        midPoints[i] = Vector3.new(math.cos(ang) * R * 0.52, H * 0.48, math.sin(ang) * R * 0.52)
    end
    for i = 1, segs do
        local nextIdx = (i % segs) + 1
        makeLine(rimPoints[i], rimPoints[nextIdx])
        makeLine(midPoints[i], midPoints[nextIdx])
        if i % 2 == 0 then makeLine(Vector3.new(0, H, 0), rimPoints[i]) end
    end
    M.State.HatModel = model
end

function M.F.ApplyDark()
    pcall(function()
        if M.State.DarkWorld then
            M.Data.DarkApplied = true
            M.F.SetProp(M.Services.L, "ExposureCompensation", -M.State.DarkIntensity * 3.5)
        elseif M.Data.DarkApplied then
            M.Data.DarkApplied = false
            M.Services.L.ExposureCompensation = M.State.OrigExp
        end
    end)
end

-- Туман: мы всегда создаём СВОЙ Atmosphere и не трогаем объекты игры.
-- Раньше скрипт менял Atmosphere самой игры и при выключении не возвращал.
-- Чужие Atmosphere на время тумана обнуляем и запоминаем, чтобы вернуть.
function M.F.ApplyFog()
    pcall(function()
        local L = M.Services.L
        local ours = M.Data.FxAtmosphere and M.Data.FxAtmosphere.Parent and M.Data.FxAtmosphere
        local set = M.F.SetProp

        if M.State.FogOn then
            M.Data.FogApplied = true
            local created = false
            if not ours then
                ours = Instance.new("Atmosphere")
                ours.Parent = L
                M.Data.FxAtmosphere = ours
                created = true
            end
            set(ours, "Density", math.clamp(M.State.FogDensity, 0.05, 0.99))
            set(ours, "Offset", 0)
            set(ours, "Haze", math.clamp(M.State.FogHaze, 0, 10))
            set(ours, "Color", M.State.FogColor)
            set(ours, "Decay", M.State.FogColor)
            set(ours, "Glare", 0)

            -- Чужие Atmosphere гасим. Список детей Lighting небольшой, но сканировать его каждый кадр незачем.
            if created or os.clock() - M.Data.FogScan >= 0.5 then
                M.Data.FogScan = os.clock()
                for _, child in ipairs(L:GetChildren()) do
                    if child:IsA("Atmosphere") and child ~= ours then
                        if M.Data.AtmoBackup[child] == nil then
                            M.Data.AtmoBackup[child] = child.Density
                        end
                        set(child, "Density", 0)
                    end
                end
            end

            set(L, "FogStart", 0)
            set(L, "FogEnd", math.clamp(320 - (M.State.FogDensity * 280), 10, 500))
            set(L, "FogColor", M.State.FogColor)
            local ambient = M.State.FogColor:Lerp(Color3.fromRGB(15, 15, 15), 0.35)
            set(L, "OutdoorAmbient", ambient)
            set(L, "Ambient", ambient)
        elseif M.Data.FogApplied then
            -- Возвращаем всё как было ровно один раз
            M.Data.FogApplied = false
            if ours then ours:Destroy() end
            M.Data.FxAtmosphere = nil
            for atmo, density in pairs(M.Data.AtmoBackup) do
                if atmo.Parent then atmo.Density = density end
            end
            table.clear(M.Data.AtmoBackup)
            L.FogStart = M.State.OrigFogStart
            L.FogEnd = M.State.OrigFogEnd
            L.FogColor = M.State.OrigFogColor
            L.OutdoorAmbient = M.State.OrigOutdoorAmb
            L.Ambient = M.Data.OrigAmbient
        end
    end)
end

-- ==============================================================================
-- [ CUSTOM SKYBOX ] (всё происходит только у вас на экране; серверу игры ничего не отправляется)
-- Вводится ОДИН ID из Creator Store (число из ссылки магазина). Скрипт пытается открыть модель прямо на
-- вашем клиенте и достать из неё объект Sky. Способы по очереди, первый сработавший побеждает:
--   1) AssetService:LoadAssetAsync - официальный способ. Для чужих бесплатных моделей в настройках
--      игры должна стоять галочка Game Settings > Security > Allow Loading Third Party Assets;
--   2) InsertService:LoadAsset - старый способ. Я убирал его «для безопасности», и скайбоксы перестали грузиться
--      там, где работал только он. Вернул: модель никуда не вставляется, из неё читаются только адреса шести
--      картинок, и она сразу удаляется, поэтому скрипты внутри модели запуститься не могут;
--   3) если ни один не сработал, ID считается ID картинки и ставится на все 6 граней.
-- Метод game:GetObjects по-прежнему убран: он работает с повышенными правами.
-- Также можно вписать 6 ID картинок через запятую: Bk, Dn, Ft, Lf, Rt, Up.
-- Небо не зависит от Lighting.ClockTime, поэтому не конфликтует с функциями времени суток.
-- ==============================================================================

function M.F.RenderSkyStatus()
    local label = M.UI.SkyStatusLabel
    local st = M.Data.SkyStatus
    if not label or not st then return end
    local text = M.Translate(st.Key)
    if st.Arg ~= nil then text = string.format(text, st.Arg) end
    -- Если небо не загрузилось, под сообщением показываем причину (что именно ответил каждый способ загрузки)
    if st.Kind == "error" and M.Data.SkyDetail and M.Data.SkyDetail ~= "" then
        text = text .. "  [" .. string.sub(M.Data.SkyDetail, 1, 110) .. "]"
    end
    label.Text = text
    if st.Kind == "ok" then
        label.TextColor3 = Color3.fromRGB(110, 220, 150)
    elseif st.Kind == "error" then
        label.TextColor3 = Color3.fromRGB(255, 105, 105)
    else
        label.TextColor3 = Color3.fromRGB(150, 160, 185)
    end
end

function M.F.SetSkyStatus(key, arg, kind)
    M.Data.SkyStatus = {Key = key, Arg = arg, Kind = kind}
    M.F.RenderSkyStatus()
end

-- Достаёт ID из строки: "123456", "rbxassetid://123456", ссылка магазина или ссылка с id=123456
function M.F.ExtractAssetDigits(text)
    local digits = string.match(text, "[?&]id=(%d+)") or string.match(text, "rbxassetid://(%d+)") or string.match(text, "%d+")
    if digits and #digits >= 5 and #digits <= 19 then return digits end
    return nil
end

-- Разбирает строку с ID. Возвращает: таблицу из 6 строк, ключ статуса, аргумент статуса, ID (для одного ID)
function M.F.ParseSkyIds(text)
    local word = string.lower(string.match(text or "", "^%s*(.-)%s*$") or "")
    if word == "default" or word == "стандарт" then
        return M.Data.SkyBuiltin, "Sky_OkBuiltin", nil
    end
    local ids = {}
    for token in string.gmatch(text or "", "[^,;%s]+") do
        local digits = M.F.ExtractAssetDigits(token)
        if not digits then
            return nil, "Sky_BadId", string.sub(token, 1, 24)
        end
        table.insert(ids, digits)
    end

    if #ids == 0 then return nil, "Sky_Idle", nil end
    if #ids == 1 then
        local one = "rbxassetid://" .. ids[1]
        return {one, one, one, one, one, one}, "Sky_Ok1", nil, ids[1]
    end
    if #ids == 6 then
        local faces = {}
        for i, id in ipairs(ids) do faces[i] = "rbxassetid://" .. id end
        return faces, "Sky_Ok6", nil
    end
    return nil, "Sky_BadCount", #ids
end

-- Приводит ОДИН адрес грани к безопасному виду или возвращает nil. Разрешены только:
--   * встроенные картинки неба самого Roblox (rbxasset://textures/sky/..., rbxasset://sky/...). Именно так задано
--     «классическое» небо Roblox: раньше такие адреса отбрасывались, и «Roblox 2016» не загружался;
--   * rbxassetid://число;
--   * старые ссылки Roblox вида http(s)://www.roblox.com/asset/?id=число (у старых скайбоксов, вроде заката 2010):
--     переводятся в rbxassetid://число;
--   * просто число.
-- Любой другой адрес (чужие сайты, пути к файлам) не принимается.
function M.F.NormalizeSkyFace(value)
    if type(value) ~= "string" or #value > 200 then return nil end
    -- Префикс проверяем через find без счёта символов: так нельзя ошибиться в длине
    if string.find(value, "rbxasset://textures/sky/", 1, true) == 1 or string.find(value, "rbxasset://sky/", 1, true) == 1 then
        if string.find(value, "..", 1, true) then return nil end
        return value
    end
    local digits = M.F.ExtractAssetDigits(value)
    if digits then return "rbxassetid://" .. digits end
    return nil
end

-- Превращает словарь {SkyboxBk = "...", ...} в массив из 6 корректных строк (или nil, если чего-то не хватает)
function M.F.SanitizeSkyFaces(raw)
    if type(raw) ~= "table" then return nil end
    local out = {}
    for i, face in ipairs(M.Data.SkyFaces) do
        local normalized = M.F.NormalizeSkyFace(raw[face])
        if not normalized then return nil end
        out[i] = normalized
    end
    return out
end

-- Достаёт 6 граней из первого объекта Sky внутри загруженного объекта (или самого Sky)
function M.F.ExtractFacesFromModel(root)
    local sky = root:IsA("Sky") and root or root:FindFirstChildWhichIsA("Sky", true)
    if not sky then return nil end
    local raw = {}
    for _, face in ipairs(M.Data.SkyFaces) do raw[face] = sky[face] end
    return M.F.SanitizeSkyFaces(raw)
end

-- Загружает модель из магазина ЛОКАЛЬНО и достаёт 6 граней Sky. Возвращает: грани или nil, причину.
-- Причины: "no_sky" (модель открылась, но Sky внутри нет), "no_loader" (ни один способ загрузки не разрешён).
function M.F.ResolveStoreSky(digits)
    local cached = M.Data.SkyCache[digits]
    if cached then return cached, "cache" end

    local numericId = tonumber(digits)
    if not numericId then return nil, "bad_id" end

    local loaders = {
        {Name = "AssetService", Load = function() return game:GetService("AssetService"):LoadAssetAsync(numericId) end},
        {Name = "InsertService", Load = function() return M.Services.I:LoadAsset(numericId) end}
    }

    local modelOpened = false
    local problems = {}
    for _, loader in ipairs(loaders) do
        -- Каждый способ в pcall: Roblox запрещает часть из них клиенту, и это не должно ронять скрипт
        local ok, result = pcall(loader.Load)
        if not ok then
            problems[#problems + 1] = loader.Name .. ": " .. string.sub(tostring(result), 1, 70)
        elseif not result then
            problems[#problems + 1] = loader.Name .. ": пусто"
        end
        if ok and result then
            local roots = (typeof(result) == "Instance") and {result} or result
            local faces = nil
            for _, root in ipairs(roots) do
                if typeof(root) == "Instance" then
                    faces = faces or M.F.ExtractFacesFromModel(root)
                    root:Destroy()
                end
            end
            modelOpened = true
            if faces then
                M.Data.SkyCache[digits] = faces
                return faces, "model"
            end
            problems[#problems + 1] = loader.Name .. ": в модели нет Sky"
        end
    end
    return nil, modelOpened and "no_sky" or "no_loader", table.concat(problems, " | ")
end

-- Находит Sky: сначала наш, потом игровой. Для игрового запоминаем исходные значения.
function M.F.AcquireSky()
    local L = M.Services.L
    if M.Data.FxSky and M.Data.FxSky.Parent then return M.Data.FxSky end

    local sky = L:FindFirstChildOfClass("Sky")
    if sky then
        -- Это небо самой игры: не создаём второе, а меняем это, запомнив исходные значения, чтобы вернуть при выключении
        local backup = M.Data.SkyBackup
        if not backup or backup.Object ~= sky then
            backup = {Object = sky, CelestialBodiesShown = sky.CelestialBodiesShown, Faces = {}}
            for _, face in ipairs(M.Data.SkyFaces) do
                backup.Faces[face] = sky[face]
            end
            M.Data.SkyBackup = backup
        end
        M.Data.SkyIsGame = true
    else
        sky = Instance.new("Sky")
        sky.Parent = L
        M.Data.SkyIsGame = false
    end
    M.Data.FxSky = sky
    return sky
end

function M.F.RestoreSky()
    M.Data.SkyWanted = nil
    M.Data.SkyToken = M.Data.SkyToken + 1

    if M.Data.FxSky and M.Data.FxSky.Parent and not M.Data.SkyIsGame then
        M.Data.FxSky:Destroy()
    end
    M.Data.FxSky, M.Data.SkyIsGame = nil, nil

    local backup = M.Data.SkyBackup
    if backup and backup.Object and backup.Object.Parent then
        for face, value in pairs(backup.Faces) do
            backup.Object[face] = value
        end
        backup.Object.CelestialBodiesShown = backup.CelestialBodiesShown
    end
    M.Data.SkyBackup = nil
end

-- Записывает M.Data.SkyWanted в Sky. silent = true: тихая проверка (статус не трогаем)
function M.F.CommitSky(silent)
    local faces = M.Data.SkyWanted
    if not faces or not M.State.SkyOn then return end

    local sky = M.F.AcquireSky()
    local changed = false

    for i, face in ipairs(M.Data.SkyFaces) do
        -- Сравниваем по цифрам ID: движок может записать ссылку в другом виде
        local current, wanted = tostring(sky[face]), faces[i]
        if string.find(wanted, "rbxassetid://", 1, true) then
            current, wanted = string.match(current, "%d+"), string.match(wanted, "%d+")
        end
        if current ~= wanted then
            sky[face] = faces[i]
            changed = true
        end
    end

    local showBodies = not M.State.SkyHideBodies
    if sky.CelestialBodiesShown ~= showBodies then
        sky.CelestialBodiesShown = showBodies
    end

    if silent or (not changed and M.Data.SkyStatus and M.Data.SkyStatus.Kind == "ok") then return end

    -- Проверяем, что картинки реально загрузились, и показываем результат
    M.Data.SkyToken = M.Data.SkyToken + 1
    local token = M.Data.SkyToken
    M.F.SetSkyStatus("Sky_Loading", nil, "idle")
    task.spawn(function()
        local failed = 0
        pcall(function()
            M.Services.C:PreloadAsync({sky}, function(_, status)
                if status == Enum.AssetFetchStatus.Failure or status == Enum.AssetFetchStatus.TimedOut then
                    failed = failed + 1
                end
            end)
        end)
        if token ~= M.Data.SkyToken or M.State.IsShutDown then return end
        if failed > 0 then
            if M.Data.SkyFallbackReason == "no_loader" then
                M.F.SetSkyStatus("Sky_NoLoader", nil, "error")
            else
                M.F.SetSkyStatus("Sky_Fail", failed, "error")
            end
        else
            M.F.SetSkyStatus(M.Data.SkyOkKey, nil, "ok")
        end
    end)
end

-- silent = true: тихая проверка раз в полсекунды (ничего не разбираем заново, статус не трогаем)
function M.F.ApplySky(silent)
    pcall(function()
        if not M.State.SkyOn then
            M.F.RestoreSky()
            table.clear(M.Data.SkyCache)      -- кэш загруженных скайбоксов больше не нужен
            if not silent then M.F.SetSkyStatus("Sky_Off", nil, "idle") end
            return
        end

        if silent then
            M.F.CommitSky(true)
            return
        end

        local faces, info, arg, digits = M.F.ParseSkyIds(M.State.SkyIds)
        if not faces then
            -- Неверный ввод: возвращаем обычное небо, чтобы не оставлять "старое" без ведома игрока
            M.F.RestoreSky()
            M.F.SetSkyStatus(info, arg, info == "Sky_Idle" and "idle" or "error")
            return
        end

        if info == "Sky_Ok1" then
            -- Один ID: сначала пробуем как модель из магазина. Загрузка может занять время, поэтому в отдельном потоке.
            M.Data.SkyToken = M.Data.SkyToken + 1
            local token = M.Data.SkyToken
            M.F.SetSkyStatus("Sky_Resolving", nil, "idle")
            task.spawn(function()
                local ok, err = pcall(function()
                    local resolved, reason, detail = M.F.ResolveStoreSky(digits)
                    if token ~= M.Data.SkyToken or M.State.IsShutDown or not M.State.SkyOn then return end
                    M.Data.SkyDetail = (not resolved) and detail or nil
                    if resolved then
                        M.Data.SkyWanted = resolved
                        M.Data.SkyOkKey = "Sky_OkModel"
                        M.Data.SkyFallbackReason = nil
                    else
                        M.Data.SkyWanted = faces
                        M.Data.SkyOkKey = "Sky_Ok1"
                        M.Data.SkyFallbackReason = reason
                    end
                    M.F.CommitSky(false)
                end)
                if not ok then warn("[Matsysense] Ошибка загрузки скайбокса: " .. tostring(err)) end
            end)
            return
        end

        M.Data.SkyWanted = faces
        M.Data.SkyOkKey = info
        M.Data.SkyFallbackReason = nil
        M.F.CommitSky(false)
    end)
end

-- Быстрый выбор: подставляет ID, включает скайбокс и применяет его
function M.F.PickSkyPreset(id)
    M.F.SetStateVisual("SkyIds", id)
    M.F.SetStateVisual("SkyOn", true)
    M.F.ApplySky()
end

-- Облака: если в игре уже есть Clouds, меняем их и запоминаем исходные значения (вернём при выключении).
-- Если нет - создаём свои и удаляем при выключении.
function M.F.ApplyClouds()
    pcall(function()
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if not terrain then return end

        local ownClouds = M.Data.FxClouds and M.Data.FxClouds.Parent and M.Data.FxClouds
        local clouds = ownClouds or terrain:FindFirstChildOfClass("Clouds")
        if M.State.CloudsOn then
            if not clouds then
                clouds = Instance.new("Clouds")
                clouds.Parent = terrain
                M.Data.FxClouds = clouds
                ownClouds = clouds
            end
            -- Если игра сама пересоздала Clouds, прежняя копия настроек уже недействительна
            if M.Data.CloudBackup and M.Data.CloudBackup.Object ~= clouds and not ownClouds then
                M.Data.CloudBackup = nil
            end
            if not ownClouds and not M.Data.CloudBackup then
                M.Data.CloudBackup = {
                    Object = clouds, Enabled = clouds.Enabled,
                    Density = clouds.Density, Cover = clouds.Cover, Color = clouds.Color
                }
            end
            M.F.SetProp(clouds, "Enabled", true)
            M.F.SetProp(clouds, "Density", math.clamp(M.State.CloudDensity, 0.01, 1.0))
            M.F.SetProp(clouds, "Cover", math.clamp(M.State.CloudCover / 100, 0.0, 1.0))
            M.F.SetProp(clouds, "Color", M.State.CloudColor)
        else
            local backup = M.Data.CloudBackup
            if clouds and ownClouds then
                clouds:Destroy()
                M.Data.FxClouds = nil
            elseif backup and backup.Object == clouds and clouds.Parent then
                clouds.Enabled = backup.Enabled
                clouds.Density = backup.Density
                clouds.Cover = backup.Cover
                clouds.Color = backup.Color
            end
            M.Data.CloudBackup = nil
        end
    end)
end

-- ==============================================================================
-- [ BODY ORIENTATION & MOTOR6D HOOKS (ROBUST TRANSFORM CORE) ]
-- ==============================================================================
local function GetDirectionInput()
    -- Если игрок печатает в поле меню, клавиши WASD не должны двигать персонажа
    if M.Services.U:GetFocusedTextBox() then return 0, 0, 0 end
    local x, z, y = 0, 0, 0
    if M.Services.U:IsKeyDown(Enum.KeyCode.D) then x = x + 1 end
    if M.Services.U:IsKeyDown(Enum.KeyCode.A) then x = x - 1 end
    if M.Services.U:IsKeyDown(Enum.KeyCode.W) then z = z + 1 end
    if M.Services.U:IsKeyDown(Enum.KeyCode.S) then z = z - 1 end
    if M.Services.U:IsKeyDown(Enum.KeyCode.Space) then y = y + 1 end
    if M.Services.U:IsKeyDown(Enum.KeyCode.LeftControl) or M.Services.U:IsKeyDown(Enum.KeyCode.LeftShift) then y = y - 1 end
    return x, z, y
end

-- ==============================================================================
-- [ ДВИЖЕНИЕ ЧЕРЕЗ ФИЗИКУ ]
-- Раньше ускорение бега, полёт и управление в воздухе двигали персонажа прибавлением к его CFrame: это «прыжки по
-- координатам» поверх физики, и сервер игры часто откатывал такого персонажа назад (рывки, резиновая лента).
-- Теперь персонажа двигает сама физика Roblox:
--   * ускорение бега: повышается скорость ходьбы Humanoid (на вашем компьютере), персонаж просто бежит быстрее;
--   * полёт: плавно меняется скорость персонажа (AssemblyLinearVelocity), гравитация компенсируется;
--   * управление в воздухе: скорость в падении плавно подтягивается к выбранному направлению.
-- Положение больше не пишется напрямую, поэтому нет мгновенных скачков. Это про плавность и меньше откатов.
-- Игра по-прежнему видит ваше положение и скорость, как и у любого игрока: скрыть их нельзя.
-- ==============================================================================

-- Пишет скорость персонажа и сообщает защите от толчков, что это ВАШЕ изменение (иначе защита приняла бы его за толчок)
function M.F.WriteVelocity(hrp, newVelocity)
    local old = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = newVelocity
    if M.Data.PrevVelocity then
        M.Data.PrevVelocity = M.Data.PrevVelocity + (newVelocity - old)
    end
end

-- Скорость ходьбы, которую задала ИГРА (без нашей надбавки). Нужна и защите от оглушения.
function M.F.GameWalkSpeed(h)
    local D = M.Data
    if D.SpeedWritten ~= nil and D.SpeedHum == h and h.WalkSpeed == D.SpeedWritten then
        return D.SpeedBase
    end
    return h.WalkSpeed
end

-- Возвращает скорость ходьбы, которая была до надбавки (если игра сама её не меняла)
function M.F.ReleaseSpeedBoost(h)
    local D = M.Data
    if D.SpeedWritten == nil then return end
    if h and D.SpeedHum == h and D.SpeedBase and h.WalkSpeed == D.SpeedWritten then
        h.WalkSpeed = D.SpeedBase
    end
    D.SpeedWritten = nil
end

-- Ускорение бега. Пока вы идёте, скорость ходьбы поднимается до выбранной, когда остановились, возвращается.
-- Если игра сама поменяла скорость (замедление, спринт), новая скорость считается обычной. Оглушение (скорость 0)
-- не перебивается.
function M.F.UpdateSpeedBoost(h)
    local D = M.Data
    if D.SpeedHum ~= h then
        D.SpeedHum, D.SpeedWritten, D.SpeedBase = h, nil, h.WalkSpeed
    end
    local current = h.WalkSpeed
    if D.SpeedWritten == nil or current ~= D.SpeedWritten then
        D.SpeedBase = current
        D.SpeedWritten = nil
    end
    local base = D.SpeedBase
    local want = base
    if h.MoveDirection.Magnitude > 0 and base >= 1 then
        want = math.max(base, M.State.SprintSpeed)
    end
    if want ~= current then
        h.WalkSpeed = want
        D.SpeedWritten = (want ~= base) and want or nil
    end
end

-- Полёт: желаемая скорость плавно догоняется (старт и остановка без рывка). Скорость хранится отдельно от физики,
-- а к записываемой добавляется половина потери от гравитации за кадр, поэтому без нажатий персонаж висит на месте.
function M.F.UpdateFlight(dt, hrp, cam)
    local D = M.Data
    local inX, inZ, inY = GetDirectionInput()
    local camCF = cam.CFrame
    local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
    local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
    if forward.Magnitude > 0 then forward = forward.Unit end
    if right.Magnitude > 0 then right = right.Unit end

    local moveDir = (right * inX) + (forward * inZ)
    if moveDir.Magnitude > 0 then moveDir = moveDir.Unit end
    local totalDir = Vector3.new(moveDir.X, inY, moveDir.Z)
    if totalDir.Magnitude > 1 then totalDir = totalDir.Unit end          -- по диагонали не быстрее, чем прямо

    D.FlightVel = D.FlightVel or hrp.AssemblyLinearVelocity
    D.FlightVel = D.FlightVel:Lerp(totalDir * M.State.FlightSpeed, 1 - math.exp(-12 * dt))
    hrp.AssemblyLinearVelocity = D.FlightVel + Vector3.new(0, workspace.Gravity * dt * 0.5, 0)
    hrp.AssemblyAngularVelocity = Vector3.zero
end

-- Управление в падении: горизонтальная скорость подтягивается к выбранному направлению, вертикаль не трогаем.
-- Скорость выше выбранной не снижается (например, после сильного толчка).
function M.F.UpdateAirControl(dt, hrp, cam)
    local inX, inZ = GetDirectionInput()
    local camCF = cam.CFrame
    local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
    local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
    if forward.Magnitude > 0 then forward = forward.Unit end
    if right.Magnitude > 0 then right = right.Unit end

    local dir = (right * inX) + (forward * inZ)
    if dir.Magnitude <= 0 then return end
    local velocity = hrp.AssemblyLinearVelocity
    local flat = Vector3.new(velocity.X, 0, velocity.Z)
    if flat.Magnitude >= M.State.AirSpeed then return end
    local alpha = 1 - math.exp(-(M.State.AirAccel * 0.75) * dt)
    local newFlat = flat:Lerp(dir.Unit * M.State.AirSpeed, alpha)
    M.F.WriteVelocity(hrp, Vector3.new(newFlat.X, velocity.Y, newFlat.Z))
end

-- Аварийное выключение: одним нажатием (клавиша End или кнопка в Настройках) отключает всё, что меняет движение,
-- физику персонажа или действует за вас. Нужно, если что-то пошло не так: застряли в полёте, игра начала откатывать,
-- хочется быстро вернуть обычное управление. Настройки при этом не стираются, функции можно включить снова.
local PANIC_KEYS = {"FlightMode", "Speed", "WalkThroughWalls", "InfiniteJumps", "AutoJump", "AirControl", "TriggerAssist", "TriggerLoop",
    "AimAssist", "KnockbackProtection", "FallProtection", "AntiStun", "SpinCharacter", "HeadTiltOn", "IdleProtection"}
local MOVE_KEYS = {"FlightMode", "Speed", "WalkThroughWalls", "AirControl"}

-- Выключает перечисленные функции так же, как это сделал бы игрок в меню (переключатель и его обработчик)
function M.F.DisableFeatures(keys)
    local count = 0
    for _, key in ipairs(keys) do
        if M.State[key] == true then
            count = count + 1
            M.F.SetStateVisual(key, false)
            -- Обработчик переключателя (если есть) выполняет остановку: снять подписки, вернуть свойства
            for _, el in ipairs(M.Data.RegUI) do
                if el.Key == key and el.Callback then pcall(el.Callback, false) end
            end
        end
    end
    return count
end

-- Страховка: то, что должно быть остановлено, останавливаем напрямую, даже если переключателя в меню нет
function M.F.StopMovement()
    local char = M.LP and M.LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    pcall(M.F.ReleaseSpeedBoost, hum)
    pcall(M.F.StopFlying)
    pcall(M.F.SetWallPass, false)
    M.Data.FlightVel = nil
end

function M.F.PanicReset()
    local count = M.F.DisableFeatures(PANIC_KEYS)
    M.F.StopMovement()
    pcall(M.F.SetIdleProtection, false)
    M.Data.PrevVelocity = nil
    M.F.Notify("PanicReset", M.Translate("Panic_Done"), false, true)
    return count
end

-- Выключает только движение (полёт, ускорение, проход сквозь стены, управление в воздухе) и говорит почему
function M.F.MovementStopped(reasonKey)
    M.F.DisableFeatures(MOVE_KEYS)
    M.F.StopMovement()
    M.Data.PrevVelocity = nil
    M.F.Notify("MovementStopped", M.Translate(reasonKey), false, true)
end

-- Защита от повторных откатов. Если сервер игры вернул персонажа назад (за один кадр смещение намного больше, чем
-- можно пройти на выбранной скорости, и направлено ПРОТИВ вашего движения), функции движения выключаются сами и
-- вы видите уведомление. Иначе игра откатывала бы вас снова и снова, а частые откаты часто заканчиваются
-- отключением от игры. Телепорт игры «вперёд» или вбок откатом не считается. Включается в Настройках.
function M.F.UpdateRollbackGuard(dt, hrp, h, char)
    local D = M.Data
    local position, velocity = hrp.Position, hrp.AssemblyLinearVelocity
    local lastPosition, lastVelocity, lastChar = D.GuardLastPos, D.GuardLastVel, D.GuardChar
    D.GuardLastPos, D.GuardLastVel, D.GuardChar = position, velocity, char
    if not M.State.RollbackGuard or not lastPosition or lastChar ~= char or h.SeatPart ~= nil then return end
    if not (M.State.FlightMode or M.State.Speed or M.State.WalkThroughWalls or M.State.AirControl) then return end
    local now = os.clock()
    if now < D.GuardCooldownUntil then return end

    local fastest = math.max(h.WalkSpeed, 16)
    if M.State.Speed then fastest = math.max(fastest, M.State.SprintSpeed) end
    if M.State.FlightMode then fastest = math.max(fastest, M.State.FlightSpeed) end
    if M.State.AirControl then fastest = math.max(fastest, M.State.AirSpeed) end

    local step = position - lastPosition
    if step.Magnitude <= math.max(12, fastest * dt * 3 + 4) then return end
    if lastVelocity.Magnitude < 4 or step:Dot(lastVelocity) >= 0 then return end

    D.GuardCooldownUntil = now + 3
    M.F.MovementStopped("Rollback_Done")
end

-- Предохранитель от ошибок. Ошибка в одной из функций, которые работают каждый кадр, раньше просто сыпалась в
-- вывод кадр за кадром и могла оставить персонажа в странном состоянии (застрявший полёт, ускорение). Теперь
-- ошибка перехватывается, а если одна и та же функция падает 8 раз за 5 секунд, движение выключается само.
function M.F.Guarded(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if ok then return true end
    local D = M.Data
    local now = os.clock()
    local record = D.ErrorLog[name]
    if not record or now - record.First > 5 then
        record = {First = now, Count = 0}
        D.ErrorLog[name] = record
        warn("[Matsysense] Ошибка в " .. name .. ": " .. tostring(err))
    end
    record.Count = record.Count + 1
    if record.Count >= 8 then
        D.ErrorLog[name] = nil
        warn("[Matsysense] " .. name .. " падает слишком часто, движение выключено")
        M.F.MovementStopped("Guard_Tripped")
    end
    return false
end

-- Авто-прыжок: персонаж прыгает без остановок. Как только он стоит на земле, запрашивается новый прыжок, поэтому
-- прыжки идут один за другим, как при бесконечном нажатии пробела. Прыжок запрашивается обычным способом игрока
-- (смена состояния Humanoid на своём компьютере), без отдельных запросов на сервер. В полёте, на сиденье, в воде
-- и на лестнице ничего не делает.
function M.F.UpdateAutoJump(h)
    if h.SeatPart ~= nil or h.Sit or h.PlatformStand then return end
    local state = h:GetState()
    if state == Enum.HumanoidStateType.Running
        or state == Enum.HumanoidStateType.RunningNoPhysics
        or state == Enum.HumanoidStateType.Landed then
        h:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end

-- Одна точка входа для всех трёх функций (вызывается каждый кадр после физики)
function M.F.UpdateMovement(dt, hrp, h, cam)
    if M.State.AutoJump and not M.State.FlightMode then
        M.F.UpdateAutoJump(h)
    end
    if M.State.Speed and not M.State.FlightMode then
        M.F.UpdateSpeedBoost(h)
    else
        M.F.ReleaseSpeedBoost(h)
    end
    if M.State.FlightMode then
        if cam then M.F.UpdateFlight(dt, hrp, cam) end
    else
        M.Data.FlightVel = nil
        if M.State.AirControl and cam and h:GetState() == Enum.HumanoidStateType.Freefall then
            M.F.UpdateAirControl(dt, hrp, cam)
        end
    end
end

M.F.StartFlying = function()
    M.State.FlightMode = true
    M.Data.FlightVel = nil
    local char = M.LP and M.LP.Character
    if char then
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = true end
    end
end

M.F.StopFlying = function()
    M.State.FlightMode = false
    M.Data.FlightVel = nil
    local char = M.LP and M.LP.Character
    if char then
        local h = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if h then h.PlatformStand = false end
        if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
    end
end

table.insert(M.Data.Conns, M.Services.U.JumpRequest:Connect(function()
    local char = M.LP and M.LP.Character
    if not char then return end
    local h = char:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return end
    if M.State.InfiniteJumps and not M.State.FlightMode then
        h:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

-- Анти-АФК. Roblox считает игрока бездействующим примерно через 20 минут без нажатий и отключает его. Пока функция
-- включена, в момент такого «засыпания» скрипт сам нажимает кнопку мыши (обычный ввод игрока через VirtualUser).
-- Подписка на событие Idled существует только пока функция включена. Ничего отдельного на сервер не отправляется.
M.F.SetIdleProtection = function(on)
    if M.Data.AfkConn then M.Data.AfkConn:Disconnect(); M.Data.AfkConn = nil end
    if not on then return end
    M.Data.AfkConn = M.LP.Idled:Connect(function()
        local vu = M.F.GetVirtualUser()
        if not vu then return end
        pcall(function()
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end)
end

-- ==============================================================================
-- [ ПРОХОД СКВОЗЬ СТЕНЫ ]
-- Столкновения частей персонажа выключаются каждый физический шаг (PreSimulation) и у новых деталей (инструмент,
-- аксессуар) сразу при появлении. Раньше при выключении столкновения возвращались мгновенно: если вы были внутри
-- стены, физика выталкивала персонажа наружу, и это выглядело как телепорт назад. Теперь, пока вы внутри
-- стены или другой детали, столкновения остаются выключенными и возвращаются, когда вы вышли (не дольше 20 секунд).
-- Скрипт НЕ двигает персонажа сам: ни записи позиции, ни CFrame.
-- ==============================================================================

-- Есть ли вокруг персонажа твёрдые детали (кроме него самого). Запрос локальный, серверу ничего не отправляется.
function M.F.CharacterOverlapsSolid(char)
    local ok, overlapping = pcall(function()
        local cframe, size = char:GetBoundingBox()
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}
        params.RespectCanCollide = true
        params.MaxParts = 1
        local parts = workspace:GetPartBoundsInBox(cframe, size - Vector3.new(0.3, 0.3, 0.3), params)
        return #parts > 0
    end)
    return ok and overlapping or false
end

local function wallDisableCollision(part)
    local D = M.Data
    -- Запоминаем исходное значение ОДИН раз, чтобы потом вернуть именно его (шапкам, например, не включаем столкновения)
    if D.WallPassOrig[part] == nil then D.WallPassOrig[part] = part.CanCollide end
    part.CanCollide = false
end

-- Окончательно возвращает столкновения и снимает подписки
function M.F.FinishWallRelease()
    local D = M.Data
    D.WallReleasePending = false
    if D.WallPassAdded then D.WallPassAdded:Disconnect(); D.WallPassAdded = nil end
    if M.UI.WallPassLoop and not M.State.WalkThroughWalls then
        M.UI.WallPassLoop:Disconnect()
        M.UI.WallPassLoop = nil
    end
    for part, original in pairs(D.WallPassOrig) do
        if part.Parent then part.CanCollide = original end
    end
    table.clear(D.WallPassOrig)
end

local function wallPassStep()
    local D = M.Data
    if M.State.IsShutDown then return end
    local char = M.LP and M.LP.Character
    if not (char and char.Parent) or M.State.IsDead then
        if D.WallReleasePending then M.F.FinishWallRelease() end
        return
    end
    if M.State.WalkThroughWalls or D.WallReleasePending then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then wallDisableCollision(part) end
        end
    end
    if D.WallReleasePending then
        local now = os.clock()
        if now - D.WallReleaseCheck >= 0.1 then
            D.WallReleaseCheck = now
            if now - D.WallReleaseStart > 20 or not M.F.CharacterOverlapsSolid(char) then
                M.F.FinishWallRelease()
            end
        end
    end
end

M.F.SetWallPass = function(on)
    local D = M.Data
    M.State.WalkThroughWalls = on
    if D.WallPassAdded then D.WallPassAdded:Disconnect(); D.WallPassAdded = nil end

    if on then
        D.WallReleasePending = false
        if not M.UI.WallPassLoop then
            M.UI.WallPassLoop = M.Services.R.PreSimulation:Connect(wallPassStep)
        end
        local char = M.LP and M.LP.Character
        if char then
            D.WallPassAdded = char.DescendantAdded:Connect(function(part)
                if M.State.WalkThroughWalls and part:IsA("BasePart") then wallDisableCollision(part) end
            end)
        end
        return
    end

    -- Выключение. Цикла нет (скрипт выключается): возвращаем сразу.
    if not M.UI.WallPassLoop then
        M.F.FinishWallRelease()
        return
    end
    local char = M.LP and M.LP.Character
    if char and char.Parent and M.F.CharacterOverlapsSolid(char) then
        D.WallReleasePending, D.WallReleaseStart, D.WallReleaseCheck = true, os.clock(), 0
        M.F.Notify("WallRelease", M.Translate("WallPass_Wait"), false, true)
    else
        M.F.FinishWallRelease()
    end
end

-- ==============================================================================
-- [ SIMULATION LOOPS (PHYSICS & RENDERING) ]
-- ==============================================================================
table.insert(M.Data.Conns, M.Services.R.Heartbeat:Connect(function(dt)
    if M.State.IsShutDown then return end
    local char = M.LP and M.LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local cam = workspace.CurrentCamera

    M.State.IsDead = not (h and h.Health > 0)

    -- Раньше тут стоял return при смерти, и метеориты с молниями замирали. Теперь блок просто пропускается.
    if char and char.Parent and not M.State.IsDead and hrp and h then
        M.F.Guarded("Movement", M.F.UpdateMovement, dt, hrp, h, cam)
        M.F.Guarded("RollbackGuard", M.F.UpdateRollbackGuard, dt, hrp, h, char)
    else
        M.Data.GuardLastPos = nil
    end

    M.F.Guarded("AntiFling", M.F.UpdateAntiFling, dt)
    M.F.Guarded("Pose", M.F.UpdatePoseReal, dt)

    local now = os.clock()
    if M.State.MeteorOn and now - M.Data.LastMet >= math.clamp(6 / M.State.MeteorRate, 0.4, 6) then
        M.Data.LastMet = now
        M.F.SpawnMeteor()
    end
    if M.State.LightningOn and now - M.Data.LastLight >= math.clamp(8 / M.State.LightningRate, 0.6, 8) then
        M.Data.LastLight = now
        M.F.StrikeLightning()
    end
end))

table.insert(M.Data.Conns, M.Services.R.RenderStepped:Connect(function(dt)
    if M.State.IsShutDown then return end

    M.F.SyncModules()
    if os.clock() - M.Data.LastFolderSweep >= 3 then
        M.Data.LastFolderSweep = os.clock()
        M.F.ReleaseEmptyFolders()
    end

    M.Data.FpsCount = M.Data.FpsCount + 1
    if os.clock() - M.Data.FpsTimer >= 0.5 then
        M.State.CurFPS = math.round(M.Data.FpsCount / (os.clock() - M.Data.FpsTimer))
        M.Data.FpsCount = 0; M.Data.FpsTimer = os.clock()
    end

    if M.State.MenuOpen and not M.F.CameraDragActive() then
        M.Services.U.MouseBehavior = Enum.MouseBehavior.Default
        M.Services.U.MouseIconEnabled = true
    end

    M.F.UpdateWeatherProps(dt)

    M.F.UpdateLowHp(M.LP.Character and M.LP.Character:FindFirstChildOfClass("Humanoid"))
    M.F.UpdateEnemyHealth()
    M.F.UpdateWidgets(dt)
    M.F.UpdateSpectate()

    -- Внешний вид проверяем 10 раз в секунду, а не каждый кадр
    if os.clock() - M.Data.LastVisual >= 0.1 then
        M.Data.LastVisual = os.clock()
        M.UpdatePlayerVisuals()
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local char = M.LP and M.LP.Character
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local isAlive = (h and h.Health > 0)
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if M.State.ShowFov and M.State.AimAssist then
        M.F.EnsurePlayerViewGui()
        M.UI.FovCircle.Visible = true
        M.UI.FovCircle.Size = UDim2.new(0, M.State.AimFov * 2, 0, M.State.AimFov * 2)
        local center = cam.ViewportSize / 2
        M.UI.FovCircle.Position = UDim2.new(0, center.X, 0, center.Y)
    elseif M.UI.FovCircle then
        M.UI.FovCircle.Visible = false
    end

    M.F.Guarded("FallProtection", M.F.UpdateFallProtection)
    M.F.Guarded("AntiStun", M.F.UpdateAntiStun)

    if M.State.PlayerView then
        local vSize = cam.ViewportSize
        for p, pack in pairs(M.State.PlayerViewGuis) do
            if not p.Parent then
                pack.Container:Destroy()
                if pack.PlayerLine then pack.PlayerLine:Destroy() end
                if M.State.Highlights[p] then M.State.Highlights[p]:Destroy() end
                M.State.Highlights[p] = nil
                M.State.PlayerViewGuis[p] = nil
                continue
            end

            local t_char = p.Character
            if not t_char or not t_char.Parent then
                pack.Container.Visible = false
                if pack.PlayerLine then pack.PlayerLine.Visible = false end
                if M.State.Highlights[p] then M.State.Highlights[p].Enabled = false end
                continue
            end

            local hum = pack.Hum
            if not hum or not hum.Parent then
                hum = t_char:FindFirstChildOfClass("Humanoid")
                pack.Hum = hum
            end

            local r = t_char:FindFirstChild("HumanoidRootPart")
            local head = t_char:FindFirstChild("Head")

            if not hum or hum.Health <= 0 or not r or not r.Parent or not head then
                pack.Container.Visible = false
                if pack.PlayerLine then pack.PlayerLine.Visible = false end
                if M.State.Highlights[p] then M.State.Highlights[p].Enabled = false end
                continue
            end

            local isSelf = pack.IsSelf
            local allowed = M.State.PlayerView and (not isSelf or M.State.PlayerViewOnSelf)
            if M.State.PlayerViewTeamCheck and M.IsTeammate(p) and not isSelf then allowed = false end

            if not allowed then
                pack.Container.Visible = false
                if pack.PlayerLine then pack.PlayerLine.Visible = false end
                if M.State.Highlights[p] then M.State.Highlights[p].Enabled = false end
                continue
            end

            local rootPos, onScreen = cam:WorldToViewportPoint(r.Position)
            if onScreen and rootPos.Z > 0.5 then
                local topWorld = head.Position + Vector3.new(0, 1.4, 0)
                local bottomWorld = r.Position - Vector3.new(0, 3.0, 0)
                local topScreen, topVis = cam:WorldToViewportPoint(topWorld)
                local bottomScreen, botVis = cam:WorldToViewportPoint(bottomWorld)

                if topVis and botVis and topScreen.Z > 0 and bottomScreen.Z > 0 then
                    local boxHeight = math.abs(bottomScreen.Y - topScreen.Y)
                    local boxWidth = boxHeight * 0.62

                    if boxHeight > 4 and boxHeight < 2000 then
                        pack.Container.Visible = M.State.PlayerViewBox
                        pack.Container.Position = UDim2.fromOffset(math.floor(rootPos.X - (boxWidth / 2)), math.floor(topScreen.Y))
                        pack.Container.Size = UDim2.fromOffset(math.floor(boxWidth), math.floor(boxHeight))
                        pack.Stroke.Enabled = M.State.PlayerViewBox

                        local curHp = math.clamp(hum.Health, 0, hum.MaxHealth)
                        local hpPercent = curHp / math.max(hum.MaxHealth, 1)
                        local tSize = M.State.PlayerViewHealthBarThick
                        local isH = (M.State.PlayerViewHealthPos == "Bottom")

                        pack.BarBg.Visible = M.State.PlayerViewHealthBar
                        pack.HpLabel.Visible = M.State.PlayerViewHealthText

                        if isH then
                            pack.BarBg.Size = UDim2.new(1, 0, 0, tSize)
                            pack.BarBg.Position = UDim2.new(0, 0, 1, 4)
                            pack.BarFill.Size = UDim2.new(hpPercent, 0, 1, 0)
                            pack.BarFill.Position = UDim2.new(0, 0, 0, 0)
                            pack.HpLabel.AnchorPoint = Vector2.new(0.5, 0)
                            pack.HpLabel.Position = UDim2.new(0.5, 0, 1, tSize + 4)
                            pack.HpLabel.TextXAlignment = Enum.TextXAlignment.Center
                        elseif M.State.PlayerViewHealthPos == "Right" then
                            pack.BarBg.Size = UDim2.new(0, tSize, 1, 0)
                            pack.BarBg.Position = UDim2.new(1, 4, 0, 0)
                            pack.BarFill.Size = UDim2.new(1, 0, hpPercent, 0)
                            pack.BarFill.Position = UDim2.new(0, 0, 1 - hpPercent, 0)
                            pack.HpLabel.AnchorPoint = Vector2.new(0, 0.5)
                            pack.HpLabel.Position = UDim2.new(1, tSize + 6, 1 - hpPercent, 0)
                            pack.HpLabel.TextXAlignment = Enum.TextXAlignment.Left
                        else
                            pack.BarBg.Size = UDim2.new(0, tSize, 1, 0)
                            pack.BarBg.Position = UDim2.new(0, -(tSize + 4), 0, 0)
                            pack.BarFill.Size = UDim2.new(1, 0, hpPercent, 0)
                            pack.BarFill.Position = UDim2.new(0, 0, 1 - hpPercent, 0)
                            pack.HpLabel.AnchorPoint = Vector2.new(1, 0.5)
                            pack.HpLabel.Position = UDim2.new(0, -(tSize + 6), 1 - hpPercent, 0)
                            pack.HpLabel.TextXAlignment = Enum.TextXAlignment.Right
                        end

                        pack.BarFill.BackgroundColor3 = M.State.PlayerViewHealthCol
                        pack.HpLabel.Text = string.format("%d HP", math.floor(curHp))
                        pack.HpLabel.TextColor3 = M.State.PlayerViewHealthCol
                        -- Цвет по здоровью: подсветка, полоска и подпись плавно идут от зелёного к красному
                        local fillColor = M.State.PlayerViewHealthColor and M.Math.HealthColor(hpPercent) or M.State.PlayerViewFill
                        local highlight = M.State.Highlights[p]
                        if highlight then
                            highlight.Enabled = true
                            M.F.SetProp(highlight, "FillColor", fillColor)
                        end
                        if M.State.PlayerViewHealthColor then
                            local hpColor = M.Math.HealthColor(hpPercent)
                            pack.BarFill.BackgroundColor3 = hpColor
                            pack.HpLabel.TextColor3 = hpColor
                        end

                        -- Дистанция в имени (строка пересобирается, только если включено)
                        local wantedName = pack.BaseName
                        if M.State.PlayerViewDistance then
                            wantedName = pack.BaseName .. string.format("  [%d%s]", math.floor((cam.CFrame.Position - r.Position).Magnitude), M.Translate("Unit_m"))
                        end
                        if pack.NameLabel.Text ~= wantedName then pack.NameLabel.Text = wantedName end

                        if M.State.PlayerViewLines and pack.PlayerLine and not isSelf then
                            local startX, startY = vSize.X / 2, vSize.Y
                            local targetX, targetY = rootPos.X, rootPos.Y
                            local distance = math.sqrt((targetX - startX)^2 + (targetY - startY)^2)
                            local angle = math.atan2(targetY - startY, targetX - startX)

                            pack.PlayerLine.Visible = true
                            pack.PlayerLine.Size = UDim2.new(0, distance, 0, 1.5)
                            pack.PlayerLine.Position = UDim2.fromOffset((startX + targetX) / 2, (startY + targetY) / 2)
                            pack.PlayerLine.Rotation = math.deg(angle)
                            pack.PlayerLine.BackgroundColor3 = M.State.PlayerLineCol
                        elseif pack.PlayerLine then
                            pack.PlayerLine.Visible = false
                        end
                    else
                        pack.Container.Visible = false
                        if pack.PlayerLine then pack.PlayerLine.Visible = false end
                        if M.State.Highlights[p] then M.State.Highlights[p].Enabled = false end
                    end
                else
                    pack.Container.Visible = false
                    if pack.PlayerLine then pack.PlayerLine.Visible = false end
                    if M.State.Highlights[p] then M.State.Highlights[p].Enabled = false end
                end
            else
                pack.Container.Visible = false
                if pack.PlayerLine then pack.PlayerLine.Visible = false end
                if M.State.Highlights[p] then M.State.Highlights[p].Enabled = false end
            end
        end
    else
        for _, pack in pairs(M.State.PlayerViewGuis) do
            if pack and pack.Container then pack.Container.Visible = false end
            if pack and pack.PlayerLine then pack.PlayerLine.Visible = false end
        end
        for _, hl in pairs(M.State.Highlights) do
            if hl and hl.Parent then hl.Enabled = false end
        end
    end

    if M.UI.PrevCard and M.UI.PrevCard.Visible and M.UI.PrevDummyContainer then
        local bob = math.sin(os.clock() * 2.8) * 3
        M.UI.PrevDummyContainer.Position = UDim2.new(0.5, -55, 0, 80 + bob)
    end

    if char and M.State.OrbitOn and #M.State.OrbitObjs > 0 and char:FindFirstChild("HumanoidRootPart") then
        M.Data.OrbitClock = M.Data.OrbitClock + (dt * M.State.OrbitSpeed * 1.5)
        local cen = char.HumanoidRootPart.Position
        for _, d in ipairs(M.State.OrbitObjs) do
            if d.Part and d.Part.Parent then
                local t = M.Data.OrbitClock + d.Phase
                d.Part.CFrame = CFrame.new(cen + Vector3.new(math.cos(t * d.SpeedX) * M.State.OrbitRadius, math.sin(t * d.SpeedY) * (M.State.OrbitRadius * 0.65), math.sin(t * d.SpeedZ) * M.State.OrbitRadius))
                d.Part.Size = Vector3.new(M.State.OrbitSize, M.State.OrbitSize, M.State.OrbitSize)
            end
        end
    end

    -- Смена дня и ночи: время само идёт вперёд.
    if M.State.TimeOn and M.State.TimeSyncReal and os.clock() - M.Data.LastRealSync >= 1 then
        M.Data.LastRealSync = os.clock()
        M.F.SyncRealTime()
    end
    if M.State.TimeOn and M.State.TimeCycle and not M.State.TimeSyncReal then
        M.State.CustomTime = M.Math.AdvanceClock(M.State.CustomTime, dt, M.State.TimeCycleSpeed)
        if os.clock() - M.Data.LastCycleUi >= 0.25 then
            M.Data.LastCycleUi = os.clock()
            for _, el in ipairs(M.Data.RegUI) do
                if el.Key == "CustomTime" and el.SetVisual then el.SetVisual(math.floor(M.State.CustomTime * 100) / 100) end
            end
        end
    end
end))

-- ==============================================================================
-- [ КАМЕРА ПРАВОЙ КНОПКОЙ ПРИ ОТКРЫТОМ МЕНЮ ]
-- Пока меню открыто, мы держим курсор свободным. Но если правую кнопку нажали ВНЕ окна меню, ничего не
-- перебиваем: стандартная камера Roblox сама вращается, пока кнопка зажата. Нажатие внутри меню камеру не трогает.
-- ==============================================================================
local function pointInside(obj, point)
    if not obj or not obj.Visible then return false end
    local pos, size = obj.AbsolutePosition, obj.AbsoluteSize
    return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

function M.F.PointerOverMenu()
    if not M.State.MenuOpen or not M.UI.Main then return false end
    local point = M.Services.U:GetMouseLocation()
    -- Координаты мыши считаются от угла экрана, а у окна без IgnoreGuiInset - от-под верхней панели Roblox
    if not M.UI.Gui.IgnoreGuiInset then
        point = point - game:GetService("GuiService"):GetGuiInset()
    end
    return pointInside(M.UI.Main, point) or pointInside(M.UI.PrevCard, point)
end

function M.F.CameraDragActive()
    return M.Data.RmbCamera == true and M.Services.U:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

table.insert(M.Data.Conns, M.Services.U.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton2 then
        M.Data.RmbCamera = M.State.MenuOpen and not M.F.PointerOverMenu()
    end
end))
table.insert(M.Data.Conns, M.Services.U.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton2 then M.Data.RmbCamera = false end
end))

-- ==============================================================================
-- [ UI DRAG, BIND & HOVER LOGIC ]
-- ==============================================================================
table.insert(M.Data.Conns, M.Services.U.InputChanged:Connect(function(inp)
    if M.Data.DragHandler and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        M.Data.DragHandler(inp.Position)
    end
    if inp.UserInputType == Enum.UserInputType.MouseMovement and M.UI.Tooltip.Visible then
        local mPos = M.Services.U:GetMouseLocation()
        local screenSz = M.UI.Gui.AbsoluteSize
        local x = mPos.X + 14
        local y = mPos.Y + 14
        if x + 220 > screenSz.X then x = mPos.X - 225 end
        if y + 60 > screenSz.Y then y = mPos.Y - 65 end
        M.UI.Tooltip.Position = UDim2.fromOffset(math.max(x, 5), math.max(y, 5))
    end
end))

table.insert(M.Data.Conns, M.Services.U.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        M.Data.DragHandler = nil
    end
end))

table.insert(M.Data.Conns, M.Services.U.InputBegan:Connect(function(inp, proc)
    if M.State.IsShutDown then return end
    -- Запоминаем момент вашего выстрела (клик не по меню): маркер попадания показывается только после него
    if not proc and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
        M.Data.LastShot = os.clock()
    end
    if not proc and inp.KeyCode == Enum.KeyCode.End then
        M.F.PanicReset()
        return
    end
    if not proc and inp.KeyCode == Enum.KeyCode.RightShift then
        if not M.UI.Main then return end
        if M.UI.Main.Visible then M.F.CloseMenu() else M.F.OpenMenu() end
        return
    end
    if M.State.ListeningBind then
        if inp.UserInputType == Enum.UserInputType.Keyboard then
            -- Классическая ловушка Lua: "условие and nil or значение" ВСЕГДА даёт значение, потому что nil считается ложью.
            -- Из-за этого Backspace/Delete/Escape не снимали бинд. Пишем честным if.
            local code = inp.KeyCode
            if code == Enum.KeyCode.Backspace or code == Enum.KeyCode.Delete or code == Enum.KeyCode.Escape then
                code = nil
            end
            M.State.ListeningBind.Set(code)
            M.State.ListeningBind = nil
        elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then
            M.State.ListeningBind.Cancel()
            M.State.ListeningBind = nil
        end
        return
    end
    if not proc and inp.UserInputType == Enum.UserInputType.Keyboard then
        for _, b in ipairs(M.State.Binds) do if b.Key == inp.KeyCode then b.Trigger() end end
    end
end))

M.UI.Gui = Instance.new("ScreenGui")
M.UI.Gui.Name = M.Services.H:GenerateGUID(false)
M.UI.Gui.ResetOnSpawn = false
M.UI.Gui.DisplayOrder = 200 -- меню выше рамок игроков
-- Global нужен, чтобы выпадающие списки (ZIndex 15) рисовались поверх следующих карточек
M.UI.Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
M.UI.Gui.Parent = M.TargetGui
M.F.WatchFonts(M.UI.Gui)

M.UI.Tooltip = Instance.new("Frame", M.UI.Gui)
M.UI.Tooltip.Size = UDim2.new(0, 210, 0, 48)
M.UI.Tooltip.BackgroundColor3 = Color3.fromRGB(18, 21, 30)
M.UI.Tooltip.BackgroundTransparency = 0.08
M.UI.Tooltip.Visible = false
M.UI.Tooltip.ZIndex = 99999
Instance.new("UICorner", M.UI.Tooltip).CornerRadius = UDim.new(0, 6)
M.UI.TooltipStroke = Instance.new("UIStroke", M.UI.Tooltip)
M.UI.TooltipStroke.Color = Color3.fromRGB(55, 65, 88)
M.UI.TooltipStroke.Thickness = 1

M.UI.TooltipTxt = Instance.new("TextLabel", M.UI.Tooltip)
M.UI.TooltipTxt.Size = UDim2.new(1, -16, 1, 0)
M.UI.TooltipTxt.Position = UDim2.new(0, 8, 0, 0)
M.UI.TooltipTxt.BackgroundTransparency = 1
M.UI.TooltipTxt.TextColor3 = Color3.fromRGB(215, 225, 245)
M.UI.TooltipTxt.Font = Enum.Font.Gotham
M.UI.TooltipTxt.TextSize = 11
M.UI.TooltipTxt.TextWrapped = true
M.UI.TooltipTxt.TextXAlignment = Enum.TextXAlignment.Left
M.UI.TooltipTxt.TextYAlignment = Enum.TextYAlignment.Center
M.UI.TooltipTxt.ZIndex = 100000

-- Текст подсказки на текущем языке. Английского нет - показываем русский.
-- VirtualUser нужен только для автовыстрела (клик) и анти-АФК. Получаем его лениво, при первом реальном
-- обращении, и в pcall: если по какой-то причине game:GetService("VirtualUser") откажет, падает только этот
-- один вызов (пользователь увидит, что клик/анти-АФК не сработали), а не вся загрузка скрипта.
function M.F.GetVirtualUser()
    if M.Data.VirtualUserMissing then return nil end
    if M.Data.VirtualUser then return M.Data.VirtualUser end
    local ok, result = pcall(function() return game:GetService("VirtualUser") end)
    if ok and result then
        M.Data.VirtualUser = result
        return result
    end
    M.Data.VirtualUserMissing = true
    return nil
end

function M.F.TooltipText(key)
    if M.L10N.Current == "EN" and M.TooltipsEN[key] then return M.TooltipsEN[key] end
    return M.Tooltips[key]
end

function M.F.AttachTooltip(card, key)
    if not M.Tooltips[key] then return end

    card.MouseEnter:Connect(function()
        M.Data.HoverCard = card
        if M.Data.HoverTask then pcall(task.cancel, M.Data.HoverTask) end
        M.Data.HoverTask = task.spawn(function()
            task.wait(1.0)
            if M.Data.HoverCard == card and not M.State.IsShutDown then
                local mPos = M.Services.U:GetMouseLocation()
                local screenSz = M.UI.Gui.AbsoluteSize
                local x = mPos.X + 14
                local y = mPos.Y + 14
                if x + 220 > screenSz.X then x = mPos.X - 225 end
                if y + 60 > screenSz.Y then y = mPos.Y - 65 end
                M.UI.Tooltip.Position = UDim2.fromOffset(math.max(x, 5), math.max(y, 5))
                M.UI.TooltipTxt.Text = M.F.TooltipText(key)
                M.UI.Tooltip.Visible = true
            end
        end)
    end)

    card.MouseLeave:Connect(function()
        if M.Data.HoverCard == card then
            M.Data.HoverCard = nil
            if M.Data.HoverTask then pcall(task.cancel, M.Data.HoverTask) end
            M.UI.Tooltip.Visible = false
        end
    end)
end

-- ==============================================================================
-- [ PILL & MAIN FRAME CONSTRUCTORS ]
-- ==============================================================================
M.UI.Pill = Instance.new("Frame", M.UI.Gui)
M.UI.Pill.Name = M.Services.H:GenerateGUID(false)
M.UI.Pill.Size = UDim2.new(0, 0, 0, 34)
M.UI.Pill.AutomaticSize = Enum.AutomaticSize.X
M.UI.Pill.Position = UDim2.new(0.04, 0, 0.05, 0)
M.UI.Pill.BackgroundColor3 = M.State.PillBg
M.UI.Pill.BackgroundTransparency = M.State.PillAlpha
M.UI.Pill.Visible = true
M.UI.Pill.Active = true
M.UI.PillCorner = Instance.new("UICorner", M.UI.Pill)
M.UI.PillCorner.CornerRadius = UDim.new(0, 10)
M.UI.PillStroke = Instance.new("UIStroke", M.UI.Pill)
M.UI.PillStroke.Color = M.State.PillBorderCol
M.UI.PillStroke.Thickness = M.State.PillBorderThick
M.UI.PillRim = Instance.new("UIGradient", M.UI.PillStroke)
M.UI.PillRim.Rotation = 90
M.UI.PillScale = Instance.new("UIScale", M.UI.Pill)
M.UI.PillScale.Scale = M.State.PillScaleVal

local pillLayout = Instance.new("UIListLayout", M.UI.Pill)
pillLayout.FillDirection = Enum.FillDirection.Horizontal
pillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
pillLayout.Padding = UDim.new(0, 8)

local pillPad = Instance.new("UIPadding", M.UI.Pill)
pillPad.PaddingLeft = UDim.new(0, 8); pillPad.PaddingRight = UDim.new(0, 12)

M.UI.PillAvatar = M.F.NewAvatarView(M.UI.Pill)
M.UI.PillAvatar.Size = UDim2.new(0, 22, 0, 22); M.UI.PillAvatar.LayoutOrder = 1

M.UI.PillTxt = Instance.new("TextLabel", M.UI.Pill)
M.UI.PillTxt.Size = UDim2.new(0, 0, 1, 0); M.UI.PillTxt.AutomaticSize = Enum.AutomaticSize.X; M.UI.PillTxt.LayoutOrder = 2
M.UI.PillTxt.BackgroundTransparency = 1; M.UI.PillTxt.TextColor3 = M.State.PillTextCol; M.UI.PillTxt.Font = Enum.Font.GothamBold; M.UI.PillTxt.TextSize = 12
M.UI.PillTxt.Text = "matsysense | " .. M.Translate("Pill_Loaded")

-- Стиль инфо-панели. iOS 26: полная капсула (скругление = половина высоты), стеклянная заливка, светящаяся кромка
-- с бликом сверху. Выключено: прежний простой вид, где работают ваши цвет, рамка и прозрачность.
-- Включается в Настройках («Стиль iOS 26»).
function M.F.StylePill(animate)
    local pill = M.UI.Pill
    if not pill then return end
    local ios = M.State.Ios26On
    local locked = M.State.PillLocked

    M.UI.PillCorner.CornerRadius = ios and UDim.new(0.5, 0) or UDim.new(0, 10)
    pill.BackgroundColor3 = M.State.PillBg
    pill.BackgroundTransparency = ios and math.max(M.State.PillAlpha, 0.12) or M.State.PillAlpha

    local strokeColor, thickness
    if ios then
        strokeColor = locked and M.State.Accent or Color3.fromRGB(255, 255, 255)
        thickness = math.max(1.2, M.State.PillBorderThick)
        M.UI.PillRim.Enabled = true
        M.UI.PillRim.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(0.5, 0.82),
            NumberSequenceKeypoint.new(1, 0.5)
        })
    else
        strokeColor = locked and M.State.Accent or M.State.PillBorderCol
        thickness = M.State.PillBorderThick
        M.UI.PillRim.Enabled = false
    end
    M.UI.PillStroke.Thickness = thickness
    if animate then
        M.Services.T:Create(M.UI.PillStroke, TweenInfo.new(M.State.AnimSpeed), {Color = strokeColor}):Play()
    else
        M.UI.PillStroke.Color = strokeColor
    end
end
M.F.StylePill()

do
    local pDragStart, pStartPos, isPillDragging = nil, nil, false
    local clickDownPos = nil
    M.UI.Pill.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton2 then
            M.State.PillLocked = not M.State.PillLocked
            M.F.StylePill(true)
            return
        end
        if (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
            clickDownPos = inp.Position
            if not M.State.PillLocked then
                isPillDragging = true; pDragStart = inp.Position; pStartPos = M.UI.Pill.Position
            end
        end
    end)
    M.Conn(M.Services.U.InputChanged, function(inp)
        if isPillDragging and not M.State.PillLocked and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - pDragStart
            M.UI.Pill.Position = UDim2.new(pStartPos.X.Scale, pStartPos.X.Offset + d.X, pStartPos.Y.Scale, pStartPos.Y.Offset + d.Y)
        end
    end)
    M.Conn(M.Services.U.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            if clickDownPos and (inp.Position - clickDownPos).Magnitude < 6 then
                if M.UI.Main and not M.UI.Main.Visible then M.F.OpenMenu() end
            end
            clickDownPos = nil
            isPillDragging = false
        end
    end)
end

task.spawn(function()
    while task.wait(0.5) do
        if M.State.IsShutDown then break end
        M.State.Uptime = M.State.Uptime + 0.5

        local totalMem = math.round(M.Services.S:GetTotalMemoryUsageMb())
        local serverTime = os.date("*t", os.time())

        local textParts = {"matsysense"}
        if M.State.PillLocked then table.insert(textParts, "[" .. M.Translate("Pill_Locked") .. "]") end
        if M.State.PillShowUser then table.insert(textParts, M.LP.Name) end
        table.insert(textParts, string.format("%d FPS", M.State.CurFPS))

        if M.State.PillShowMem then table.insert(textParts, string.format(M.Translate("Pill_Mem"), totalMem)) end
        if M.State.PillShowMinsk then table.insert(textParts, string.format(M.Translate("Pill_Time"), serverTime.hour, serverTime.min, serverTime.sec)) end
        if M.State.PillShowTime then table.insert(textParts, string.format(M.Translate("Pill_Session"), math.floor(M.State.Uptime/3600), math.floor((M.State.Uptime%3600)/60), math.floor(M.State.Uptime%60))) end

        M.UI.PillTxt.Text = table.concat(textParts, " | ")
        if M.UI.PUptime then M.UI.PUptime.Text = string.format("Up: %02d:%02d:%02d", math.floor(M.State.Uptime/3600), math.floor((M.State.Uptime%3600)/60), math.floor(M.State.Uptime%60)) end
    end
end)

-- ==============================================================================
-- [ УВЕДОМЛЕНИЯ В СТИЛЕ iOS 26 (Liquid Glass) ]
-- Правый нижний угол. Стеклянная капсула: градиентная заливка, блик сверху, светящаяся кромка,
-- мини-переключатель внутри. Новые уведомления выталкивают старые вверх.
-- ==============================================================================
local NOTIF_W, NOTIF_H, NOTIF_GAP, NOTIF_MARGIN, NOTIF_MAX = 330, 66, 10, 20, 4

M.F.DefineModule("Notify", {
    -- Окно уведомлений существует, только пока есть уведомления (и 8 секунд после последнего)
    Wanted = function() return #M.Data.NotifList > 0 or os.clock() - M.Data.NotifyUsed < 8 end,
    Load = function()
        M.UI.NotifyGui = Instance.new("ScreenGui")
        M.UI.NotifyGui.Name = M.Services.H:GenerateGUID(false)
        M.UI.NotifyGui.ResetOnSpawn = false
        M.UI.NotifyGui.DisplayOrder = 300
        M.UI.NotifyGui.IgnoreGuiInset = true
        M.UI.NotifyGui.Parent = M.TargetGui
        M.F.WatchFonts(M.UI.NotifyGui)
    end,
    Unload = function()
        if M.UI.NotifyGui then M.UI.NotifyGui:Destroy() end
        M.UI.NotifyGui = nil
    end
})

local function notifTween(inst, duration, style, direction, goal)
    local tween = M.Services.T:Create(inst, TweenInfo.new(duration, style, direction), goal)
    tween:Play()
    return tween
end

-- Расставляет уведомления стопкой: индекс 1 (самое новое) внизу, старые выше. Высота у каждого своя (n.H),
-- потому что размер уведомлений настраивается.
function M.F.NotifyLayout()
    local offset = NOTIF_MARGIN
    for _, n in ipairs(M.Data.NotifList) do
        notifTween(n.Holder, 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {Position = UDim2.new(1, -NOTIF_MARGIN, 1, -offset)})
        offset = offset + n.H + NOTIF_GAP
    end
end

-- Размер уведомлений меняется сразу, в том числе у уже показанных: рамка меняет размер, а содержимое внутри неё
-- (фиксированный холст 330 x 66) масштабируется через UIScale
function M.F.NotifyRescale()
    local scale = math.clamp(M.State.NotifyScale or 1, 0.5, 2)
    for _, n in ipairs(M.Data.NotifList) do
        if not n.Dead then
            n.W, n.H, n.Scale = NOTIF_W * scale, NOTIF_H * scale, scale
            n.Holder.Size = UDim2.new(0, n.W, 0, n.H)
            if n.InnerScale then n.InnerScale.Scale = scale end
        end
    end
    M.F.NotifyLayout()
end

function M.F.NotifyDismiss(n)
    if n.Dead then return end
    n.Dead = true
    for i, item in ipairs(M.Data.NotifList) do
        if item == n then table.remove(M.Data.NotifList, i) break end
    end
    notifTween(n.Holder, 0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.In,
        {Position = UDim2.new(1, n.W + 40, n.Holder.Position.Y.Scale, n.Holder.Position.Y.Offset)})
    for _, item in ipairs(n.FadeItems or {}) do
        notifTween(item[1], 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {[item[2]] = 1})
    end
    notifTween(n.Fill, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {BackgroundTransparency = 1})
    notifTween(n.Stroke, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {Transparency = 1})
    task.delay(0.45, function() n.Holder:Destroy() end)
    M.F.NotifyLayout()
end

-- Обновляет содержимое (иконка-переключатель, тексты) и перезапускает таймер
function M.F.NotifyApply(n, title, isOn)
    n.TitleLabel.Text = title
    -- Цвет и прозрачность берутся из настроек, поэтому ползунки действуют и на уже показанное уведомление
    n.Fill.BackgroundColor3 = M.State.NotifyColor
    if not n.Dead then
        notifTween(n.Fill, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {BackgroundTransparency = M.State.NotifyAlpha})
    end
    n.SubLabel.Text = M.Translate(isOn and "Notif_On" or "Notif_Off")
    n.SubLabel.TextColor3 = isOn and Color3.fromRGB(120, 235, 160) or Color3.fromRGB(175, 182, 200)
    notifTween(n.Track, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
        BackgroundColor3 = isOn and M.State.Accent or Color3.fromRGB(96, 100, 116)
    })
    notifTween(n.Knob, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
        Position = isOn and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    })
    n.Token = n.Token + 1
    local token = n.Token
    task.delay(2.8, function()
        if n.Token == token then M.F.NotifyDismiss(n) end
    end)
end

-- Капсула собрана из трёх слоёв ОДИНАКОВОЙ формы (радиус = половина высоты): заливка, содержимое и кромка.
-- Раньше радиусы слоёв были разными, а сверху лежал отдельный белый блик и две тени: края выглядели кривыми.
-- Теперь тени и блик убраны, форма идеально ровная.
function M.F.Notify(key, title, isOn, force)
    if (not M.State.NotifyOn and not force) or M.State.IsShutDown or M.Data.Importing then return end
    M.Data.NotifyUsed = os.clock()
    M.F.LoadModule("Notify")
    local list = M.Data.NotifList

    -- Это уведомление уже на экране (например, быстро включили и выключили): обновляем его
    for _, existing in ipairs(list) do
        if existing.Key == key and not existing.Dead then
            M.F.NotifyApply(existing, title, isOn)
            return
        end
    end

    local scale = math.clamp(M.State.NotifyScale or 1, 0.5, 2)
    local n = {Key = key, Token = 0, Dead = false, W = NOTIF_W * scale, H = NOTIF_H * scale, Scale = scale}

    local holder = Instance.new("Frame")
    holder.Name = "Notification"
    holder.AnchorPoint = Vector2.new(1, 1)
    holder.Size = UDim2.new(0, n.W, 0, n.H)
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.Position = UDim2.new(1, n.W + 40, 1, -NOTIF_MARGIN)
    holder.Parent = M.UI.NotifyGui
    n.Holder = holder

    local function capsuleCorner(parent)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = parent
    end

    -- Слой 1: стеклянная заливка с мягким затенением к низу
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = M.State.NotifyColor
    fill.BackgroundTransparency = 1
    fill.BorderSizePixel = 0
    capsuleCorner(fill)
    fill.Parent = holder
    n.Fill = fill

    -- Слой 2: содержимое. Это обычная рамка: проявляются сами элементы (переключатель и тексты), а не группа
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Parent = holder
    n.Content = content

    -- Холст фиксированного размера 330 x 66: всё содержимое рисуется на нём, а UIScale растягивает его до размера рамки
    local inner = Instance.new("Frame")
    inner.Name = "Inner"
    inner.Size = UDim2.new(0, NOTIF_W, 0, NOTIF_H)
    inner.BackgroundTransparency = 1
    inner.BorderSizePixel = 0
    local innerScale = Instance.new("UIScale")
    innerScale.Scale = scale
    innerScale.Parent = inner
    inner.Parent = content
    n.Inner, n.InnerScale = inner, innerScale

    -- Слой 3: тонкая светящаяся кромка. Отдельная прозрачная рамка той же формы, на ней только контур.
    local rim = Instance.new("Frame")
    rim.Name = "Rim"
    rim.Size = UDim2.new(1, 0, 1, 0)
    rim.BackgroundTransparency = 1
    rim.BorderSizePixel = 0
    capsuleCorner(rim)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.2
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = rim
    local strokeGrad = Instance.new("UIGradient")
    strokeGrad.Rotation = 90
    strokeGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(0.5, 0.82),
        NumberSequenceKeypoint.new(1, 0.55)
    })
    strokeGrad.Parent = stroke
    rim.Parent = holder
    n.Stroke = stroke

    -- Иконка: мини-переключатель, как в iOS
    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(0, 46, 0, 26)
    track.Position = UDim2.new(0, 20, 0.5, -13)
    track.BackgroundColor3 = Color3.fromRGB(96, 100, 116)
    track.BorderSizePixel = 0
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track
    track.Parent = inner
    n.Track = track

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = UDim2.new(0, 3, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    knob.Parent = track
    n.Knob = knob

    local function makeLabel(name, font, size, pos, sz, color, align, anchor)
        local lbl = Instance.new("TextLabel")
        lbl.Name = name
        lbl.BackgroundTransparency = 1
        lbl.Font = font
        lbl.TextSize = size
        lbl.Position = pos
        lbl.Size = sz
        lbl.TextColor3 = color
        lbl.TextXAlignment = align
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        if anchor then lbl.AnchorPoint = anchor end
        lbl.Parent = inner
        return lbl
    end
    n.TitleLabel = makeLabel("Title", Enum.Font.GothamBold, 14, UDim2.new(0, 82, 0, 12), UDim2.new(1, -82 - 76, 0, 20),
        Color3.fromRGB(255, 255, 255), Enum.TextXAlignment.Left)
    n.SubLabel = makeLabel("Sub", Enum.Font.GothamMedium, 12, UDim2.new(0, 82, 0, 33), UDim2.new(1, -82 - 20, 0, 18),
        Color3.fromRGB(175, 182, 200), Enum.TextXAlignment.Left)
    n.TimeLabel = makeLabel("Time", Enum.Font.Gotham, 11, UDim2.new(1, -24, 0, 14), UDim2.new(0, 60, 0, 14),
        Color3.fromRGB(150, 158, 178), Enum.TextXAlignment.Right, Vector2.new(1, 0))
    n.TimeLabel.Text = M.Translate("Notif_Now")

    -- Элементы, которые проявляются и растворяются: {объект, свойство, настоящее значение}. Сначала невидимы.
    n.FadeItems = {
        {track, "BackgroundTransparency", 0}, {knob, "BackgroundTransparency", 0},
        {n.TitleLabel, "TextTransparency", 0}, {n.SubLabel, "TextTransparency", 0}, {n.TimeLabel, "TextTransparency", 0}
    }
    for _, item in ipairs(n.FadeItems) do item[1][item[2]] = 1 end

    -- Вставляем в начало списка: новое уведомление всегда внизу стопки
    table.insert(list, 1, n)
    holder.Position = UDim2.new(1, n.W + 40, 1, -NOTIF_MARGIN)
    while #list > NOTIF_MAX do M.F.NotifyDismiss(list[#list]) end

    M.F.NotifyApply(n, title, isOn)
    -- Переключатель в иконке сначала стоит в противоположном положении и красиво "щёлкает" в нужное
    knob.Position = isOn and UDim2.new(0, 3, 0.5, 0) or UDim2.new(1, -23, 0.5, 0)
    track.BackgroundColor3 = isOn and Color3.fromRGB(96, 100, 116) or M.State.Accent
    notifTween(knob, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {Position = isOn and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)})
    notifTween(track, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {BackgroundColor3 = isOn and M.State.Accent or Color3.fromRGB(96, 100, 116)})

    notifTween(fill, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {BackgroundTransparency = M.State.NotifyAlpha})
    notifTween(stroke, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {Transparency = 0})
    for _, item in ipairs(n.FadeItems) do
        notifTween(item[1], 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {[item[2]] = item[3]})
    end
    M.F.NotifyLayout()
end

-- Показывает пробное уведомление, чтобы сразу было видно, как выглядят выбранные цвет и прозрачность
function M.F.NotifyPreview()
    if M.Data.Importing then return end
    M.F.Notify("NotifyPreview", M.Translate("NotifyPreviewText"), true, true)
end

function M.F.NotifyToggle(stateKey, locKey, value)
    M.F.Notify(stateKey, M.Translate(locKey), value and true or false)
end

-- ==============================================================================
-- [ ЭКРАННЫЕ ЭФФЕКТЫ: ВСПЫШКА, ВИНЬЕТКА, ПРИЦЕЛ, РЕЗКОСТЬ, РАЗМЫТИЕ, ЦВЕТ ]
-- ==============================================================================
function M.F.NewGui(name, order)
    local gui = Instance.new("ScreenGui")
    gui.Name = M.Services.H:GenerateGUID(false)
    gui.ResetOnSpawn = false
    gui.DisplayOrder = order
    gui.IgnoreGuiInset = true
    gui.Parent = M.TargetGui
    M.F.WatchFonts(gui)
    return gui
end

-- Вспышка экрана (молния). Двойная вспышка выглядит естественнее одиночной.
M.F.DefineModule("Flash", {
    -- Вспышка нужна редко: окно создаётся при первой вспышке и выгружается через 8 секунд без неё
    Wanted = function() return os.clock() - M.Data.FlashUsed < 8 end,
    Load = function()
        M.UI.FlashGui = M.F.NewGui("Flash", 45)
        M.UI.FlashFrame = Instance.new("Frame")
        M.UI.FlashFrame.Size = UDim2.new(1, 0, 1, 0)
        M.UI.FlashFrame.BackgroundColor3 = Color3.fromRGB(235, 240, 255)
        M.UI.FlashFrame.BackgroundTransparency = 1
        M.UI.FlashFrame.BorderSizePixel = 0
        M.UI.FlashFrame.Parent = M.UI.FlashGui
    end,
    Unload = function()
        if M.UI.FlashGui then M.UI.FlashGui:Destroy() end
        M.UI.FlashGui, M.UI.FlashFrame = nil, nil
    end
})

function M.F.ScreenFlash(power, color)
    power = math.clamp(power, 0, 1)
    if power <= 0 then return end
    M.Data.FlashUsed = os.clock()
    M.F.LoadModule("Flash")
    M.UI.FlashFrame.BackgroundColor3 = color or Color3.fromRGB(235, 240, 255)
    M.Data.FlashToken = (M.Data.FlashToken or 0) + 1
    local token = M.Data.FlashToken
    local frame = M.UI.FlashFrame
    task.spawn(function()
        local peak = 1 - 0.7 * power
        frame.BackgroundTransparency = peak
        M.Services.T:Create(frame, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
        task.wait(0.16)
        if token ~= M.Data.FlashToken or M.State.IsShutDown then return end
        frame.BackgroundTransparency = 1 - (1 - peak) * 0.65
        M.Services.T:Create(frame, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    end)
end

-- Цветокоррекция и готовые стили
M.GradePresets = {
    Cinematic = {Sat = -0.1, Contrast = 0.22, Bright = -0.02, Tint = Color3.fromRGB(255, 238, 222)},
    Warm = {Sat = 0.15, Contrast = 0.1, Bright = 0.02, Tint = Color3.fromRGB(255, 224, 188)},
    Cold = {Sat = 0.0, Contrast = 0.1, Bright = 0.0, Tint = Color3.fromRGB(196, 222, 255)},
    Vivid = {Sat = 0.55, Contrast = 0.2, Bright = 0.02, Tint = Color3.fromRGB(255, 255, 255)},
    Noir = {Sat = -1.0, Contrast = 0.38, Bright = -0.02, Tint = Color3.fromRGB(255, 255, 255)}
}

function M.F.ApplyGrade()
    pcall(function()
        local L = M.Services.L
        local cc = M.Data.FxGrade and M.Data.FxGrade.Parent and M.Data.FxGrade
        if M.State.GradeOn then
            if not cc then
                cc = Instance.new("ColorCorrectionEffect")
                cc.Parent = L
                M.Data.FxGrade = cc
            end
            M.F.SetProp(cc, "Saturation", math.clamp(M.State.GradeSat, -1, 2))
            M.F.SetProp(cc, "Contrast", math.clamp(M.State.GradeContrast, -1, 1))
            M.F.SetProp(cc, "Brightness", math.clamp(M.State.GradeBright, -0.5, 0.5))
            M.F.SetProp(cc, "TintColor", M.State.GradeTint)
        elseif cc then
            cc:Destroy()
            M.Data.FxGrade = nil
        end
    end)
end

function M.F.ApplyGradePreset(name)
    local preset = M.GradePresets[name]
    if not preset then return end   -- "Custom": значения остаются как есть
    M.F.SetStateVisual("GradeSat", preset.Sat)
    M.F.SetStateVisual("GradeContrast", preset.Contrast)
    M.F.SetStateVisual("GradeBright", preset.Bright)
    M.F.SetStateVisual("GradeTint", preset.Tint)
    if not M.State.GradeOn then M.F.SetStateVisual("GradeOn", true) end
    M.F.ApplyGrade()
end

-- ==============================================================================
-- [ ЕЩЁ 10 ФУНКЦИЙ ]
-- ==============================================================================

-- Красная подсветка краёв при низком здоровье (те же четыре полосы, что у виньетки, но красные и пульсирующие)
M.F.DefineModule("LowHp", {
    Wanted = function() return M.State.LowHpOn end,
    Load = function()
        M.UI.LowHpGui = M.F.NewGui("LowHp", 41)
        M.UI.LowHpGui.Enabled = false
        M.UI.LowHpEdges = {}
        local sides = {
            {Anchor = Vector2.new(0, 0), Pos = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0.3, 0, 1, 0), Rot = 0},
            {Anchor = Vector2.new(1, 0), Pos = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.3, 0, 1, 0), Rot = 180},
            {Anchor = Vector2.new(0, 0), Pos = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0.36, 0), Rot = 90},
            {Anchor = Vector2.new(0, 1), Pos = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0.36, 0), Rot = 270}
        }
        for _, side in ipairs(sides) do
            local edge = Instance.new("Frame")
            edge.AnchorPoint = side.Anchor
            edge.Position = side.Pos
            edge.Size = side.Size
            edge.BackgroundColor3 = Color3.fromRGB(220, 20, 30)
            edge.BackgroundTransparency = 1
            edge.BorderSizePixel = 0
            local grad = Instance.new("UIGradient")
            grad.Rotation = side.Rot
            grad.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.05),
                NumberSequenceKeypoint.new(0.5, 0.65),
                NumberSequenceKeypoint.new(1, 1)
            })
            grad.Parent = edge
            edge.Parent = M.UI.LowHpGui
            table.insert(M.UI.LowHpEdges, edge)
        end
    end,
    Unload = function()
        if M.UI.LowHpGui then M.UI.LowHpGui:Destroy() end
        M.UI.LowHpGui, M.UI.LowHpEdges = nil, nil
    end
})

function M.F.UpdateLowHp(hum)
    if not M.UI.LowHpGui then return end
    local fraction = hum and hum.Health > 0 and hum.Health / math.max(hum.MaxHealth, 1) or 1
    local show = M.State.LowHpOn and fraction < 0.4
    M.UI.LowHpGui.Enabled = show
    if not show then return end
    local severity = (0.4 - fraction) / 0.4                          -- 0 .. 1
    local beat = (math.sin(os.clock() * (3 + severity * 4)) + 1) / 2   -- чем хуже здоровье, тем чаще пульс
    local alpha = 0.25 + 0.6 * severity * (0.45 + 0.55 * beat)
    for _, edge in ipairs(M.UI.LowHpEdges) do
        edge.BackgroundTransparency = 1 - alpha
    end
end

-- Следим за СВОИМ здоровьем: урон запускает тряску камеры и красную вспышку
function M.F.UpdateSelfHealth(hum)
    if not hum then
        M.Data.LastHealth = nil
        return
    end
    local health = hum.Health
    local last = M.Data.LastHealth
    M.Data.LastHealth = health
    if last and health < last - 0.5 then
        M.Data.LastDamage = os.clock()
        local fraction = math.clamp((last - health) / math.max(hum.MaxHealth, 1), 0, 1)
        local power = math.clamp(fraction * 4, 0.25, 1)
        if M.State.ShakeOn then
            M.Data.ShakeEnergy = math.max(M.Data.ShakeEnergy, power * M.State.ShakeStrength)
        end
        if M.State.HitFlashOn then
            M.F.ScreenFlash(power * 0.9, Color3.fromRGB(255, 40, 40))
        end
    end
end

-- Тряска: небольшой случайный поворот камеры, который затухает. Camera-скрипт Roblox каждый кадр берёт
-- за основу ТЕКУЩИЙ CFrame камеры, поэтому прошлый поворот обязательно снимается перед его работой
-- (MatsysenseShakeUndo), иначе тряска накапливалась бы и камеру уводило в сторону.
function M.F.ApplyShake(cam, dt)
    local energy = M.Data.ShakeEnergy
    if energy <= 0.002 then
        M.Data.ShakeEnergy = 0
        return
    end
    local t = os.clock() * 38
    local nx = math.sin(t * 1.3) + math.sin(t * 2.7) * 0.5
    local ny = math.sin(t * 1.7 + 1.3) + math.sin(t * 3.1 + 0.4) * 0.5
    local nz = math.sin(t * 2.1 + 2.2)
    local offset = CFrame.Angles(nx * energy * 0.035, ny * energy * 0.035, nz * energy * 0.05)
    cam.CFrame = cam.CFrame * offset
    M.Data.LastShake = offset
    M.Data.ShakeEnergy = energy * math.exp(-6 * dt)
end

function M.F.UndoShake(cam)
    local last = M.Data.LastShake
    if last then
        cam.CFrame = cam.CFrame * last:Inverse()
        M.Data.LastShake = nil
    end
end

-- Скорость движения по смещению позиции (работает и когда персонажа двигают через CFrame).
-- Меряем смещение за короткое ОКНО (около 0.14 с) по меткам времени, а не кадр за кадром. Физика Roblox идёт со своим
-- шагом, а кадры отрисовки со своим: при замере «кадр за кадром» значения скакали (0, двойное, 0, двойное...), и
-- виджет дёргался. Окно усредняет эти скачки, а небольшая задержка скрывается плавным приближением.
function M.F.UpdateMoveSpeed(hrp, dt)
    local samples = M.Data.SpeedSamples
    if not hrp or dt <= 0 then
        M.Data.LastPos = nil
        M.Data.MoveSpeed = 0
        M.Data.Speed3D = 0
        table.clear(samples)
        return
    end
    local now = os.clock()
    local pos = hrp.Position
    local last = M.Data.LastPos
    M.Data.LastPos = pos

    -- Телепорт или респавн (скачок больше 100 studs за кадр): прежние замеры больше не годятся
    if last and (pos - last).Magnitude > 100 then
        table.clear(samples)
    end

    table.insert(samples, {T = now, P = pos})
    while #samples > 2 and now - samples[1].T > 0.14 do
        table.remove(samples, 1)
    end

    local first = samples[1]
    local span = now - first.T
    if span >= 0.03 then
        local delta = pos - first.P
        local flat = Vector3.new(delta.X, 0, delta.Z).Magnitude / span
        M.Data.MoveSpeed = M.Math.Smooth(M.Data.MoveSpeed, math.min(flat, 120), dt, 12)
        -- Полная скорость (с вертикалью) нужна виджету: при полёте вверх или падении она тоже растёт
        M.Data.Speed3D = M.Math.Smooth(M.Data.Speed3D, math.min(delta.Magnitude / span, 400), dt, 12)
    end
end

-- Числа урона над игроками
M.F.DefineModule("DamageNumbers", {
    Wanted = function() return M.State.DamageNumbers end,
    Load = function()
        M.UI.DamageFolder = Instance.new("Folder")
        M.UI.DamageFolder.Name = M.Services.H:GenerateGUID(false)
        M.UI.DamageFolder.Parent = M.TargetGui
    end,
    Unload = function()
        if M.UI.DamageFolder then M.UI.DamageFolder:Destroy() end
        M.UI.DamageFolder = nil
    end
})

function M.F.SpawnDamageNumber(head, amount)
    if not M.UI.DamageFolder then return end
    local gui = Instance.new("BillboardGui")
    gui.Adornee = head
    gui.AlwaysOnTop = true
    gui.Size = UDim2.fromOffset(120, 36)
    gui.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 2.2, 0)
    gui.Parent = M.UI.DamageFolder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 22
    label.TextColor3 = Color3.fromRGB(255, 110, 70)
    label.TextStrokeTransparency = 0.4
    label.Text = "-" .. tostring(math.floor(amount + 0.5))
    label.Parent = gui

    M.Services.T:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {StudsOffset = gui.StudsOffset + Vector3.new(0, 3, 0)}):Play()
    M.Services.T:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.3),
        {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    M.Services.D:AddItem(gui, 1.3)
end

-- Один опрос здоровья других игроков кормит и числа урона, и маркер попадания
function M.F.UpdateEnemyHealth()
    if not (M.State.DamageNumbers or M.State.HitMarkerOn) then
        -- Обе функции выключены: история здоровья игроков больше не нужна
        if next(M.Data.HpCache) ~= nil then table.clear(M.Data.HpCache) end
        return
    end
    local cam = workspace.CurrentCamera
    -- Зажатая кнопка мыши тоже считается стрельбой
    if M.State.HitMarkerOn and not M.State.MenuOpen and M.Services.U:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        M.Data.LastShot = os.clock()
    end
    for _, plr in ipairs(M.Services.P:GetPlayers()) do
        if plr ~= M.LP then
            local ch = plr.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local head = ch and ch:FindFirstChild("Head")
            if hum and head then
                local last = M.Data.HpCache[hum]
                M.Data.HpCache[hum] = hum.Health
                if last and hum.Health < last - 0.5 then
                    if M.State.DamageNumbers then M.F.SpawnDamageNumber(head, last - hum.Health) end
                    -- Маркер ложно срабатывал на урон от других игроков и окружения. Теперь нужны сразу три условия:
                    -- вы стреляли не позже 0.45 с назад, пострадавший рядом с прицелом (до 90 px) и виден без стен.
                    if M.State.HitMarkerOn and cam and (os.clock() - M.Data.LastShot) <= 0.45 then
                        local point = M.GetAimPoint(cam)
                        local screen, onScreen = cam:WorldToViewportPoint(head.Position)
                        if onScreen and (Vector2.new(screen.X, screen.Y) - point).Magnitude <= 90 and M.TargetVisibility(head, ch) then
                            M.F.ShowHitMarker(hum.Health <= 0, point)
                        end
                    end
                end
            end
        end
    end
end

-- ==============================================================================
-- [ СТЕКЛЯННЫЕ ПАНЕЛИ: ВИДЖЕТЫ И ПАНЕЛЬ НАБЛЮДЕНИЯ (стиль iOS 26) ]
-- Одна и та же панель умеет быть и стеклянной (iOS 26: большие скругления, полупрозрачная заливка, светящаяся
-- кромка), и простой плоской. Режим переключается в настройках и применяется ко всем панелям сразу.
-- ==============================================================================
-- Общее окно виджетов создаётся вместе с первым виджетом и уничтожается вместе с последним
function M.F.EnsureWidgetGui()
    if not M.UI.WidgetGui then M.UI.WidgetGui = M.F.NewGui("Widgets", 55) end
end

function M.F.ReleaseWidgetGui()
    if M.UI.WidgetGui and not M.UI.SpeedWidget and not M.UI.SpecBar then
        M.UI.WidgetGui:Destroy()
        M.UI.WidgetGui = nil
    end
end

-- Полностью убирает панель: снимает подписки перетаскивания, вычёркивает из списка, уничтожает окно
function M.F.DestroyPanel(panel)
    for _, conn in ipairs(panel.Conns or {}) do M.F.Untrack(conn) end
    panel.Conns = nil
    for i = #M.Data.Panels, 1, -1 do
        if M.Data.Panels[i] == panel then table.remove(M.Data.Panels, i) end
    end
    panel.Root:Destroy()
end

function M.F.StylePanel(panel)
    local ios = M.State.Ios26On
    local radius = ios and panel.Corner or math.min(panel.Corner, 10)
    for _, corner in ipairs(panel.Corners) do corner.CornerRadius = UDim.new(0, radius) end

    if ios then
        panel.FillAlpha = 0.2
        panel.Fill.BackgroundColor3 = Color3.fromRGB(44, 48, 68)
        panel.Stroke.Color = Color3.fromRGB(255, 255, 255)
        panel.Stroke.Thickness = 1.2
        panel.StrokeGrad.Enabled = true
        panel.StrokeGrad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.35),
            NumberSequenceKeypoint.new(0.5, 0.82),
            NumberSequenceKeypoint.new(1, 0.55)
        })
    else
        panel.FillAlpha = 0.04
        panel.Fill.BackgroundColor3 = Color3.fromRGB(20, 23, 31)
        panel.Stroke.Color = M.State.BorderCol
        panel.Stroke.Thickness = 1
        panel.StrokeGrad.Enabled = false
    end
    if not panel.Animating then
        panel.Fill.BackgroundTransparency = panel.FillAlpha
        panel.Stroke.Transparency = 0
    end

    if panel.OnStyle then panel.OnStyle(panel, ios) end
end

function M.F.RestyleAllPanels()
    for _, panel in ipairs(M.Data.Panels) do M.F.StylePanel(panel) end
    if M.F.StylePill then M.F.StylePill() end
end

-- Создаёт панель из трёх слоёв ОДИНАКОВОЙ формы: заливка, содержимое, кромка (как уведомления)
function M.F.MakePanel(gui, name, width, height, corner, posKey, useCanvas)
    local root = Instance.new("Frame")
    root.Name = name
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Size = UDim2.fromOffset(width, height)
    root.Position = UDim2.new(M.State[posKey .. "X"], 0, M.State[posKey .. "Y"], 0)
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.Active = true
    root.Visible = false
    root.Parent = gui

    local scale = Instance.new("UIScale")
    scale.Parent = root

    local panel = {Root = root, Scale = scale, Corner = corner, Corners = {}, PosKey = posKey, FillAlpha = 0.2, Animating = false, Conns = {}}

    local function addCorner(frame)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, corner)
        c.Parent = frame
        table.insert(panel.Corners, c)
    end

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BorderSizePixel = 0
    addCorner(fill)
    fill.Parent = root

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Parent = root

    local rim = Instance.new("Frame")
    rim.Name = "Rim"
    rim.Size = UDim2.new(1, 0, 1, 0)
    rim.BackgroundTransparency = 1
    rim.BorderSizePixel = 0
    addCorner(rim)
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = rim
    local strokeGrad = Instance.new("UIGradient")
    strokeGrad.Rotation = 90
    strokeGrad.Parent = stroke
    rim.Parent = root

    panel.Fill, panel.Content = fill, content
    panel.Stroke, panel.StrokeGrad = stroke, strokeGrad
    table.insert(M.Data.Panels, panel)
    M.F.StylePanel(panel)
    return panel
end

-- Перетаскивание панели мышью (за handle). Положение хранится в долях экрана и попадает в конфиг.
function M.F.MakePanelDraggable(panel, handle)
    local posKey = panel.PosKey
    local dragging, dragStart, startX, startY = false, nil, 0, 0
    handle.Active = true
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = inp.Position
            startX, startY = M.State[posKey .. "X"], M.State[posKey .. "Y"]
        end
    end)
    table.insert(panel.Conns, M.Conn(M.Services.U.InputChanged, function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local size = cam.ViewportSize
        local nx = math.clamp(startX + (inp.Position.X - dragStart.X) / size.X, 0.03, 0.97)
        local ny = math.clamp(startY + (inp.Position.Y - dragStart.Y) / size.Y, 0.03, 0.97)
        M.State[posKey .. "X"], M.State[posKey .. "Y"] = nx, ny
        panel.Root.Position = UDim2.new(nx, 0, ny, 0)
    end))
    table.insert(panel.Conns, M.Conn(M.Services.U.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

local function panelLabel(parent, name, font, size, pos, sz, color, align)
    local lbl = Instance.new("TextLabel")
    lbl.Name = name
    lbl.BackgroundTransparency = 1
    lbl.Font = font
    lbl.TextSize = size
    lbl.Position = pos
    lbl.Size = sz
    lbl.TextColor3 = color
    lbl.TextXAlignment = align or Enum.TextXAlignment.Center
    lbl.Parent = parent
    return lbl
end

-- ---------------- Виджет скорости: линия и шарик ----------------
-- Справа шарик: он стоит на высоте вашей ТЕКУЩЕЙ скорости. От шарика влево тянется линия: это предыдущая скорость,
-- график бежит влево, как на осциллографе. Пока вы стоите, линия ровная и лежит внизу.
-- Как это сделано плавно и дёшево:
--   * Отрезки линии лежат на полосе (Strip). Каждый кадр двигается только сама полоса на долю шага: один параметр.
--   * Геометрия отрезков пересчитывается лишь при новом замере (30 раз в секунду), а не на каждом кадре.
--   * Последний отрезок (от последнего замера до шарика) и сам шарик обновляются каждый кадр, поэтому шарик
--     всегда точно на конце линии.
-- Отрезки НЕПРОЗРАЧНЫЕ: полупрозрачные при наложении давали светлые полосы. К левому краю линия растворяется
-- плавным переходом цвета в цвет панели.
function M.F.BuildSpeedWidget()
    local panel = M.F.MakePanel(M.UI.WidgetGui, "SpeedWidget", 220, 132, 30, "SpeedWidget", false)
    local widget = {
        Panel = panel, Segments = {}, Cache = {}, Version = -1, WasFlat = true, Peak = 0, LastY = 77, BallY = -1,
        Left = 16, Right = 204, BaseY = 77, GraphHeight = 54, Step = 3, Interval = 1 / 30, ShownInt = 0
    }
    local samples = math.floor((widget.Right - widget.Left) / widget.Step)      -- 62 прошлых значения
    for i = 1, samples do M.Data.SpeedHistory[i] = 0 end

    local strip = Instance.new("Frame")
    strip.Name = "Strip"
    strip.Size = UDim2.new(1, 0, 1, 0)
    strip.BackgroundTransparency = 1
    strip.BorderSizePixel = 0
    strip.Parent = panel.Content
    widget.Strip = strip

    -- Отрезки 1..samples-1 едут на полосе, последний (живой) стоит отдельно и тянется к шарику
    for i = 1, samples do
        local segment = Instance.new("Frame")
        segment.AnchorPoint = Vector2.new(0.5, 0.5)
        segment.Size = UDim2.fromOffset(4, 3)
        segment.BackgroundColor3 = M.State.Accent
        segment.BorderSizePixel = 0
        segment.Visible = false
        segment.Parent = (i < samples) and strip or panel.Content
        widget.Segments[i] = segment
        widget.Cache[i] = {X = -1e9, Y = -1e9, Len = -1e9, Ang = -1e9, R = -1, G = -1, B = -1, Shown = false}
    end

    -- Шарик с мягким ореолом
    widget.Glow = Instance.new("Frame")
    widget.Glow.AnchorPoint = Vector2.new(0.5, 0.5)
    widget.Glow.Size = UDim2.fromOffset(20, 20)
    widget.Glow.BackgroundColor3 = M.State.Accent
    widget.Glow.BackgroundTransparency = 0.7
    widget.Glow.BorderSizePixel = 0
    Instance.new("UICorner", widget.Glow).CornerRadius = UDim.new(1, 0)
    widget.Glow.Parent = panel.Content
    widget.Ball = Instance.new("Frame")
    widget.Ball.AnchorPoint = Vector2.new(0.5, 0.5)
    widget.Ball.Size = UDim2.fromOffset(10, 10)
    widget.Ball.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    widget.Ball.BorderSizePixel = 0
    widget.Ball.ZIndex = 2
    Instance.new("UICorner", widget.Ball).CornerRadius = UDim.new(1, 0)
    widget.Ball.Parent = panel.Content

    widget.Number = panelLabel(panel.Content, "Number", Enum.Font.GothamBold, 30, UDim2.new(0, 0, 0, 86), UDim2.new(1, 0, 0, 34),
        Color3.fromRGB(255, 255, 255))
    widget.Number.Text = "0"
    widget.Unit = panelLabel(panel.Content, "Unit", Enum.Font.GothamMedium, 11, UDim2.new(0, 0, 0, 114), UDim2.new(1, 0, 0, 14),
        Color3.fromRGB(165, 172, 192))
    widget.Unit.Text = M.Translate("SpeedUnit")
    M.F.AddTempReg(widget, {SetLanguage = function() widget.Unit.Text = M.Translate("SpeedUnit") end})

    M.F.MakePanelDraggable(panel, panel.Root)
    return widget
end

-- Пересчёт геометрии линии (при новом замере). В отрезок пишем только то, что реально изменилось: при ровном беге
-- почти вся линия стоит на месте, и записей почти нет. Возвращает высоту последней точки.
local function layoutSpeedStrip(widget, history, graphScale)
    local count = #history
    local heights = M.Math.SmoothSeries(M.Math.SpeedGraphHeights(history, graphScale, widget.GraphHeight))
    local back = widget.Panel.Fill.BackgroundColor3
    local accent = M.State.Accent
    local cache = widget.Cache
    local xs, ys = {}, {}
    for k = 1, count do
        xs[k] = widget.Right - (count - k) * widget.Step
        ys[k] = widget.BaseY - heights[k]
    end
    for i = 1, count - 1 do
        local segment = widget.Segments[i]
        local c = cache[i]
        local cx, cy, length, angle = M.Math.LineSegment(xs[i], ys[i], xs[i + 1], ys[i + 1])
        local fade = math.clamp((xs[i] - widget.Left) / 90, 0, 1) ^ 0.8
        if fade <= 0 then
            if c.Shown then segment.Visible = false c.Shown = false end
        else
            if not c.Shown then segment.Visible = true c.Shown = true end
            if math.abs(cx - c.X) > 0.01 or math.abs(cy - c.Y) > 0.01 then
                segment.Position = UDim2.fromOffset(cx, cy)
                c.X, c.Y = cx, cy
            end
            if math.abs(length - c.Len) > 0.01 then
                segment.Size = UDim2.fromOffset(length + 1.5, 3)
                c.Len = length
            end
            if math.abs(angle - c.Ang) > 0.02 then
                segment.Rotation = angle
                c.Ang = angle
            end
            local color = back:Lerp(accent, fade)
            if math.abs(color.R - c.R) + math.abs(color.G - c.G) + math.abs(color.B - c.B) > 0.004 then
                segment.BackgroundColor3 = color
                c.R, c.G, c.B = color.R, color.G, color.B
            end
        end
    end
    return ys[count]
end

function M.F.UpdateSpeedWidget(dt)
    local widget = M.UI.SpeedWidget
    local visible = M.State.SpeedWidgetOn
    widget.Panel.Root.Visible = visible
    if not visible then return end
    M.F.SetProp(widget.Panel.Scale, "Scale", M.State.SpeedWidgetScale)

    -- Плавная скорость: из неё получается мягкая линия, а не ступеньки
    local shown = M.Math.Smooth(M.Data.SpeedShown, M.Data.Speed3D, dt, 10)
    M.Data.SpeedShown = shown

    -- Число меняем только при заметном изменении: иначе последняя цифра мелькает туда-сюда
    if math.abs(shown - widget.ShownInt) > 0.65 or shown < 0.5 then
        local rounded = (shown < 0.5) and 0 or math.floor(shown + 0.5)
        if rounded ~= widget.ShownInt or widget.Number.Text ~= tostring(rounded) then
            widget.ShownInt = rounded
            widget.Number.Text = tostring(rounded)
        end
    end
    M.F.SetProp(widget.Number, "TextColor3", Color3.fromRGB(255, 255, 255):Lerp(M.State.Accent, math.clamp(shown / 70, 0, 1) * 0.7))

    -- Новые замеры: 30 раз в секунду график сдвигается на один шаг влево
    local history = M.Data.SpeedHistory
    M.Data.SpeedClock = math.min(M.Data.SpeedClock + dt, 0.25)
    local pushed = false
    while M.Data.SpeedClock >= widget.Interval do
        M.Data.SpeedClock = M.Data.SpeedClock - widget.Interval
        table.insert(history, shown)
        table.remove(history, 1)
        pushed = true
    end
    if pushed then
        local peak = shown
        for _, value in ipairs(history) do peak = math.max(peak, value) end
        widget.Peak = peak
    end

    -- Пока всё ровно (стоите на месте и график пуст), линию перерисовывать не нужно
    local flat = widget.Peak < 0.5 and shown < 0.5
    if flat and widget.WasFlat and widget.Version == M.Data.AccentVersion then return end
    local wasFlat = widget.WasFlat
    widget.WasFlat = flat

    M.Data.GraphScale = M.Math.Smooth(M.Data.GraphScale, math.max(80, widget.Peak * 1.1), dt, 4)
    if pushed or wasFlat or widget.Version ~= M.Data.AccentVersion then
        widget.LastY = layoutSpeedStrip(widget, history, M.Data.GraphScale)
        widget.Version = M.Data.AccentVersion
    end

    -- Каждый кадр: полоса едет на долю шага, живой отрезок тянется к шарику
    local fraction = M.Data.SpeedClock / widget.Interval
    local shift = fraction * widget.Step
    widget.Strip.Position = UDim2.fromOffset(-shift, 0)

    local headY = widget.BaseY - math.clamp(shown / M.Data.GraphScale, 0, 1) * widget.GraphHeight
    local live = widget.Segments[#widget.Segments]
    local cx, cy, length, angle = M.Math.LineSegment(widget.Right - shift, widget.LastY, widget.Right, headY)
    live.Visible = true
    live.Position = UDim2.fromOffset(cx, cy)
    live.Size = UDim2.fromOffset(length + 1.5, 3)
    live.Rotation = angle
    M.F.SetProp(live, "BackgroundColor3", M.State.Accent)

    if math.abs(headY - widget.BallY) > 0.02 then
        widget.BallY = headY
        widget.Ball.Position = UDim2.fromOffset(widget.Right, headY)
        widget.Glow.Position = widget.Ball.Position
    end
    M.F.SetProp(widget.Glow, "BackgroundColor3", M.State.Accent)
    widget.Glow.BackgroundTransparency = 0.72 + 0.12 * math.sin(os.clock() * 4)
end

function M.F.UpdateWidgets(dt)
    if M.UI.SpeedWidget then M.F.UpdateSpeedWidget(dt) end
end

M.F.DefineModule("SpeedWidget", {
    Wanted = function() return M.State.SpeedWidgetOn end,
    Load = function()
        M.F.EnsureWidgetGui()
        M.UI.SpeedWidget = M.F.BuildSpeedWidget()
    end,
    Unload = function()
        local widget = M.UI.SpeedWidget
        M.UI.SpeedWidget = nil
        if widget then
            M.F.RemoveTempRegs(widget)
            M.F.DestroyPanel(widget.Panel)
        end
        -- История скорости больше не нужна
        table.clear(M.Data.SpeedHistory)
        M.Data.SpeedShown, M.Data.GraphScale, M.Data.SpeedClock = 0, 80, 0
        M.F.ReleaseWidgetGui()
    end
})

-- ---------------- Панель наблюдения: две кнопки на экране ----------------
function M.F.BuildSpecBar()
    local panel = M.F.MakePanel(M.UI.WidgetGui, "SpectateBar", 400, 64, 32, "Spec", false)
    local bar = {Panel = panel}

    local function circleButton(text, anchorX, offsetX)
        local button = Instance.new("TextButton")
        button.AnchorPoint = Vector2.new(anchorX, 0.5)
        button.Position = UDim2.new(anchorX, offsetX, 0.5, 0)
        button.Size = UDim2.fromOffset(46, 46)
        button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        button.BackgroundTransparency = 0.82
        button.BorderSizePixel = 0
        button.Text = text
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Font = Enum.Font.GothamBold
        button.TextSize = 22
        button.AutoButtonColor = false
        Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
        button.Parent = panel.Content
        button.MouseEnter:Connect(function()
            M.Services.T:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.65}):Play()
        end)
        button.MouseLeave:Connect(function()
            M.Services.T:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.82}):Play()
        end)
        return button
    end
    bar.Prev = circleButton("<", 0, 9)
    bar.Next = circleButton(">", 1, -9)
    bar.Prev.MouseButton1Click:Connect(function() M.F.SpectateStep(-1) end)
    bar.Next.MouseButton1Click:Connect(function() M.F.SpectateStep(1) end)

    -- Середина панели (за неё же панель перетаскивается)
    local info = Instance.new("Frame")
    info.Position = UDim2.new(0, 64, 0, 0)
    info.Size = UDim2.new(1, -128, 1, 0)
    info.BackgroundTransparency = 1
    info.Active = true
    info.Parent = panel.Content
    bar.TitleLabel = panelLabel(info, "Title", Enum.Font.GothamMedium, 10, UDim2.new(0, 0, 0, 12), UDim2.new(1, 0, 0, 14),
        Color3.fromRGB(165, 172, 192))
    bar.TitleLabel.Text = M.Translate("Spectate_Title")
    bar.NameLabel = panelLabel(info, "Name", Enum.Font.GothamBold, 17, UDim2.new(0, 0, 0, 27), UDim2.new(1, 0, 0, 24),
        Color3.fromRGB(255, 255, 255))
    bar.NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    bar.NameLabel.Text = "-"
    M.F.AddTempReg(bar, {SetLanguage = function() bar.TitleLabel.Text = M.Translate("Spectate_Title") end})

    M.F.MakePanelDraggable(panel, info)
    return bar
end
M.F.DefineModule("SpecBar", {
    Wanted = function() return M.State.SpectateOn end,
    Load = function()
        M.F.EnsureWidgetGui()
        M.UI.SpecBar = M.F.BuildSpecBar()
        M.F.RenderSpectateLabel()
    end,
    Unload = function()
        local bar = M.UI.SpecBar
        M.UI.SpecBar = nil
        if bar then
            M.F.RemoveTempRegs(bar)
            M.F.DestroyPanel(bar.Panel)
        end
        M.F.ReleaseWidgetGui()
    end
})

-- ==============================================================================
-- [ МАРКЕР ПОПАДАНИЯ, СВЕТЛЯЧКИ, СВЕЧЕНИЕ, КИНОПОЛОСЫ, НАБЛЮДЕНИЕ, ВРЕМЯ, СКРИНШОТ ]
-- ==============================================================================

-- Маркер попадания: четыре короткие чёрточки крестиком вокруг прицела
M.F.DefineModule("HitMarker", {
    Wanted = function() return M.State.HitMarkerOn end,
    Load = function()
        M.UI.HitGui = M.F.NewGui("Hit", 61)
        M.UI.HitSegments = {}
        for _, d in ipairs({{-1, -1, 45}, {1, -1, -45}, {-1, 1, -45}, {1, 1, 45}}) do
            local seg = Instance.new("Frame")
            seg.AnchorPoint = Vector2.new(0.5, 0.5)
            seg.Size = UDim2.fromOffset(9, 2)
            seg.Rotation = d[3]
            seg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            seg.BackgroundTransparency = 1
            seg.BorderSizePixel = 0
            seg.Parent = M.UI.HitGui
            table.insert(M.UI.HitSegments, {Frame = seg, DirX = d[1], DirY = d[2]})
        end
    end,
    Unload = function()
        if M.UI.HitGui then M.UI.HitGui:Destroy() end
        M.UI.HitGui, M.UI.HitSegments = nil, nil
    end
})

function M.F.ShowHitMarker(killed, point)
    if not M.UI.HitSegments then return end
    local color = killed and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(255, 255, 255)
    local duration = killed and 0.5 or 0.28
    local start = killed and 11 or 8
    for _, seg in ipairs(M.UI.HitSegments) do
        seg.Frame.BackgroundColor3 = color
        seg.Frame.BackgroundTransparency = 0
        seg.Frame.Position = UDim2.fromOffset(point.X + seg.DirX * start, point.Y + seg.DirY * start)
        M.Services.T:Create(seg.Frame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(point.X + seg.DirX * (start + 7), point.Y + seg.DirY * (start + 7))
        }):Play()
    end
end

-- Свечение (Bloom)
function M.F.ApplyBloom()
    pcall(function()
        local L = M.Services.L
        local bloom = M.Data.FxBloom and M.Data.FxBloom.Parent and M.Data.FxBloom
        if M.State.BloomOn then
            if not bloom then
                bloom = Instance.new("BloomEffect")
                bloom.Parent = L
                M.Data.FxBloom = bloom
            end
            M.F.SetProp(bloom, "Intensity", math.clamp(M.State.BloomIntensity, 0, 2))
            M.F.SetProp(bloom, "Size", math.clamp(M.State.BloomSize, 0, 56))
            M.F.SetProp(bloom, "Threshold", math.clamp(M.State.BloomThreshold, 0, 3))
        elseif bloom then
            bloom:Destroy()
            M.Data.FxBloom = nil
        end
    end)
end

-- Наблюдение за игроком
function M.F.SpectateCandidates()
    local list = {}
    for _, plr in ipairs(M.Services.P:GetPlayers()) do
        if plr ~= M.LP and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
            table.insert(list, plr)
        end
    end
    table.sort(list, function(a, b) return a.Name < b.Name end)
    return list
end

function M.F.RenderSpectateLabel()
    local label = M.UI.SpectateLabel
    if not label then return end
    local target = M.Data.SpectateTarget
    local valid = target and target.Parent
    label.Text = valid and string.format(M.Translate("Spectate_Now"), target.DisplayName) or M.Translate("Spectate_None")
    if M.UI.SpecBar then
        M.UI.SpecBar.NameLabel.Text = valid and target.DisplayName or "-"
    end
end

function M.F.SpectateStep(direction)
    local list = M.F.SpectateCandidates()
    if #list == 0 then
        M.Data.SpectateTarget = nil
        M.F.RenderSpectateLabel()
        return
    end
    local index = 0
    for i, plr in ipairs(list) do
        if plr == M.Data.SpectateTarget then index = i end
    end
    if index == 0 then
        index = direction > 0 and 1 or #list
    else
        index = ((index - 1 + direction) % #list) + 1
    end
    M.Data.SpectateTarget = list[index]
    M.F.RenderSpectateLabel()
end

function M.F.UpdateSpectate()
    -- Наблюдение выключено и не было включено: делать нечего
    if not M.State.SpectateOn and not M.Data.Spectating then return end
    -- Две кнопки «предыдущий / следующий» видны на экране, пока идёт наблюдение
    if M.UI.SpecBar then M.UI.SpecBar.Panel.Root.Visible = M.State.SpectateOn end
    local cam = workspace.CurrentCamera
    if not cam then return end
    if M.State.SpectateOn then
        local target = M.Data.SpectateTarget
        local hum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
        if not hum then
            M.F.SpectateStep(1)
            target = M.Data.SpectateTarget
            hum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
        end
        if hum then
            M.Data.Spectating = true
            if cam.CameraSubject ~= hum then cam.CameraSubject = hum end
        end
    elseif M.Data.Spectating then
        M.Data.Spectating = false
        local char = M.LP.Character
        local own = char and char:FindFirstChildOfClass("Humanoid")
        if own then cam.CameraSubject = own end
        M.Data.SpectateTarget = nil
        M.F.RenderSpectateLabel()
    end
end

-- Время как в реальности
function M.F.SyncRealTime()
    local now = os.date("*t", os.time())
    M.State.CustomTime = now.hour + now.min / 60 + now.sec / 3600
    local shown = math.floor(M.State.CustomTime * 100) / 100
    for _, el in ipairs(M.Data.RegUI) do
        if el.Key == "CustomTime" and el.SetVisual then el.SetVisual(shown) end
    end
end

-- Main Frame Component
M.UI.Main = Instance.new("Frame", M.UI.Gui)
M.UI.Main.Size = UDim2.new(0, 710, 0, 490); M.UI.Main.Position = UDim2.new(0.5, -355, 0.5, -245)
M.UI.Main.BackgroundColor3 = M.State.MainBg; M.UI.Main.BackgroundTransparency = 1; M.UI.Main.Active = true
Instance.new("UICorner", M.UI.Main).CornerRadius = UDim.new(0, 12); M.UI.MainScale = Instance.new("UIScale", M.UI.Main)
M.UI.MainStroke = Instance.new("UIStroke", M.UI.Main); M.UI.MainStroke.Color = M.State.BorderCol; M.UI.MainStroke.Thickness = M.State.BorderThick

M.UI.TopControls = Instance.new("Frame", M.UI.Main)
M.UI.TopControls.Size = UDim2.new(0, 60, 0, 26)
M.UI.TopControls.Position = UDim2.new(1, -70, 0, 10)
M.UI.TopControls.BackgroundTransparency = 1
M.UI.TopControls.ZIndex = 25

local tcLayout = Instance.new("UIListLayout", M.UI.TopControls)
tcLayout.FillDirection = Enum.FillDirection.Horizontal
tcLayout.Padding = UDim.new(0, 6)
tcLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
tcLayout.VerticalAlignment = Enum.VerticalAlignment.Center

M.UI.BtnCollapse = Instance.new("TextButton", M.UI.TopControls)
M.UI.BtnCollapse.Size = UDim2.new(0, 26, 0, 26)
M.UI.BtnCollapse.BackgroundColor3 = Color3.fromRGB(32, 36, 48)
M.UI.BtnCollapse.Text = "–"
M.UI.BtnCollapse.TextColor3 = Color3.fromRGB(210, 220, 240)
M.UI.BtnCollapse.Font = Enum.Font.GothamBold
M.UI.BtnCollapse.TextSize = 14
M.UI.BtnCollapse.ZIndex = 26
Instance.new("UICorner", M.UI.BtnCollapse).CornerRadius = UDim.new(0, 6)

M.UI.BtnCollapse.MouseEnter:Connect(function()
    M.Services.T:Create(M.UI.BtnCollapse, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(45, 52, 68)}):Play()
end)
M.UI.BtnCollapse.MouseLeave:Connect(function()
    M.Services.T:Create(M.UI.BtnCollapse, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(32, 36, 48)}):Play()
end)
M.UI.BtnCollapse.MouseButton1Click:Connect(function() M.F.CloseMenu() end)

M.UI.BtnShutDown = Instance.new("TextButton", M.UI.TopControls)
M.UI.BtnShutDown.Size = UDim2.new(0, 26, 0, 26)
M.UI.BtnShutDown.BackgroundColor3 = Color3.fromRGB(180, 40, 50)
M.UI.BtnShutDown.Text = "X"
M.UI.BtnShutDown.TextColor3 = Color3.fromRGB(255, 255, 255)
M.UI.BtnShutDown.Font = Enum.Font.GothamBold
M.UI.BtnShutDown.TextSize = 12
M.UI.BtnShutDown.ZIndex = 26
Instance.new("UICorner", M.UI.BtnShutDown).CornerRadius = UDim.new(0, 6)

M.UI.BtnShutDown.MouseEnter:Connect(function()
    M.Services.T:Create(M.UI.BtnShutDown, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(225, 45, 55)}):Play()
end)
M.UI.BtnShutDown.MouseLeave:Connect(function()
    M.Services.T:Create(M.UI.BtnShutDown, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(180, 40, 50)}):Play()
end)
M.UI.BtnShutDown.MouseButton1Click:Connect(function() M.F.ShutDown() end)

M.UI.PrevCard = Instance.new("Frame", M.UI.Gui)
M.UI.PrevCard.Size = UDim2.new(0, 205, 0, 490); M.UI.PrevCard.Position = UDim2.new(M.UI.Main.Position.X.Scale, M.UI.Main.Position.X.Offset + 722, M.UI.Main.Position.Y.Scale, M.UI.Main.Position.Y.Offset)
M.UI.PrevCard.BackgroundColor3 = M.State.MainBg; M.UI.PrevCard.BackgroundTransparency = M.State.MenuAlpha; M.UI.PrevCard.Visible = false
Instance.new("UICorner", M.UI.PrevCard).CornerRadius = UDim.new(0, 12); M.UI.PrevScale = Instance.new("UIScale", M.UI.PrevCard)
M.UI.PrevStroke = Instance.new("UIStroke", M.UI.PrevCard); M.UI.PrevStroke.Color = M.State.BorderCol; M.UI.PrevStroke.Thickness = M.State.BorderThick

function M.F.SyncPreviewPos()
    M.UI.PrevCard.Position = UDim2.new(M.UI.Main.Position.X.Scale, M.UI.Main.Position.X.Offset + M.UI.Main.Size.X.Offset + 12, M.UI.Main.Position.Y.Scale, M.UI.Main.Position.Y.Offset)
end

do
    local dragStart, startPos, isDragging = nil, nil, false
    M.UI.Main.InputBegan:Connect(function(inp)
        if (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) and inp.Position.Y < M.UI.Main.AbsolutePosition.Y + 45 then
            isDragging = true; dragStart = inp.Position; startPos = M.UI.Main.Position
        end
    end)
    M.Conn(M.Services.U.InputChanged, function(inp)
        if isDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            M.UI.Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            M.F.SyncPreviewPos()
        end
    end)
    M.Conn(M.Services.U.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then isDragging = false end
    end)

    local isResizing, resizeStart, startSize
    local resizeHandle = Instance.new("TextButton", M.UI.Main)
    resizeHandle.Size = UDim2.new(0, 16, 0, 16); resizeHandle.Position = UDim2.new(1, -16, 1, -16); resizeHandle.BackgroundTransparency = 1
    resizeHandle.Text = "◢"; resizeHandle.TextSize = 14; resizeHandle.Font = Enum.Font.GothamBold; resizeHandle.TextColor3 = Color3.fromRGB(150, 160, 185)

    resizeHandle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            isResizing = true; resizeStart = inp.Position; startSize = Vector2.new(M.UI.Main.Size.X.Offset, M.UI.Main.Size.Y.Offset)
        end
    end)
    M.Conn(M.Services.U.InputChanged, function(inp)
        if isResizing and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - resizeStart
            M.UI.Main.Size = UDim2.new(0, math.clamp(startSize.X + d.X, 600, 960), 0, math.clamp(startSize.Y + d.Y, 420, 760))
            M.UI.PrevCard.Size = UDim2.new(0, 205, 0, M.UI.Main.Size.Y.Offset)
            M.F.SyncPreviewPos()
        end
    end)
    M.Conn(M.Services.U.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then isResizing = false end
    end)
end

local pHeader = Instance.new("TextLabel", M.UI.PrevCard)
pHeader.Size = UDim2.new(1, 0, 0, 36); pHeader.Position = UDim2.new(0, 0, 0, 6); pHeader.BackgroundTransparency = 1
pHeader.Text = M.Translate("Prev_Header"); pHeader.TextColor3 = Color3.fromRGB(160, 170, 195); pHeader.Font = Enum.Font.GothamBold; pHeader.TextSize = 12

M.UI.PrevDummyTag = Instance.new("TextLabel", M.UI.PrevCard)
M.UI.PrevDummyTag.Size = UDim2.new(1, -10, 0, 20); M.UI.PrevDummyTag.Position = UDim2.new(0, 5, 0, 48); M.UI.PrevDummyTag.BackgroundTransparency = 1
M.UI.PrevDummyTag.Text = M.Translate("Prev_Dummy"); M.UI.PrevDummyTag.TextColor3 = M.State.PlayerViewNameCol; M.UI.PrevDummyTag.TextStrokeColor3 = M.State.PlayerViewNameOutCol; M.UI.PrevDummyTag.TextStrokeTransparency = 0
M.UI.PrevDummyTag.Font = Enum.Font.GothamBold; M.UI.PrevDummyTag.TextSize = 12

table.insert(M.Data.RegUI, {SetLanguage = function()
    pHeader.Text = M.Translate("Prev_Header")
    M.UI.PrevDummyTag.Text = M.Translate("Prev_Dummy")
end})

M.UI.PrevDummyContainer = Instance.new("Frame", M.UI.PrevCard)
M.UI.PrevDummyContainer.Size = UDim2.new(0, 110, 0, 220); M.UI.PrevDummyContainer.Position = UDim2.new(0.5, -55, 0, 80); M.UI.PrevDummyContainer.BackgroundTransparency = 1

do
    local function makeDP(size, pos, cr)
        local f = Instance.new("Frame", M.UI.PrevDummyContainer)
        f.Size = size; f.Position = pos; f.BackgroundColor3 = M.State.PlayerViewFill; f.BackgroundTransparency = M.State.PlayerViewAlpha; f.BorderSizePixel = 0
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, cr)
        local s = Instance.new("UIStroke", f); s.Color = M.State.PlayerViewBoxCol; s.Thickness = M.State.PlayerViewBoxThick
        table.insert(M.UI.PlayerView2DParts, f)
    end
    makeDP(UDim2.new(0, 36, 0, 36), UDim2.new(0.5, -18, 0, 10), 8)
    makeDP(UDim2.new(0, 52, 0, 70), UDim2.new(0.5, -26, 0, 50), 8)
    makeDP(UDim2.new(0, 20, 0, 68), UDim2.new(0.5, -50, 0, 50), 6)
    makeDP(UDim2.new(0, 20, 0, 68), UDim2.new(0.5, 30, 0, 50), 6)
    makeDP(UDim2.new(0, 23, 0, 74), UDim2.new(0.5, -25, 0, 124), 6)
    makeDP(UDim2.new(0, 23, 0, 74), UDim2.new(0.5, 2, 0, 124), 6)

    local pBarBg = Instance.new("Frame", M.UI.PrevDummyContainer); pBarBg.BackgroundColor3 = Color3.fromRGB(15, 17, 24); pBarBg.BorderSizePixel = 0
    Instance.new("UICorner", pBarBg).CornerRadius = UDim.new(0, 2)
    local pBarFill = Instance.new("Frame", pBarBg); pBarFill.BorderSizePixel = 0
    Instance.new("UICorner", pBarFill).CornerRadius = UDim.new(0, 2)
    local pHpLbl = Instance.new("TextLabel", M.UI.PrevDummyContainer); pHpLbl.Size = UDim2.new(0, 50, 0, 16); pHpLbl.BackgroundTransparency = 1; pHpLbl.Font = Enum.Font.GothamBold

    M.UI.PrevHealthPack = {BarBg = pBarBg, BarFill = pBarFill, HpLabel = pHpLbl}
end

M.UI.Sidebar = Instance.new("Frame", M.UI.Main)
M.UI.Sidebar.Size = UDim2.new(0.25, 0, 1, 0); M.UI.Sidebar.BackgroundColor3 = M.State.SideBg; M.UI.Sidebar.BackgroundTransparency = M.State.SideAlpha; M.UI.Sidebar.BorderSizePixel = 0
Instance.new("UICorner", M.UI.Sidebar).CornerRadius = UDim.new(0, 12)
M.UI.SideStroke = Instance.new("UIStroke", M.UI.Sidebar); M.UI.SideStroke.Color = M.State.BorderCol; M.UI.SideStroke.Thickness = M.State.BorderThick

M.UI.LogoCard = Instance.new("Frame", M.UI.Sidebar)
M.UI.LogoCard.Size = UDim2.new(1, -16, 0, 36); M.UI.LogoCard.Position = UDim2.new(0, 8, 0, 12)
M.UI.LogoCard.BackgroundColor3 = M.State.SideCardBg; M.UI.LogoCard.BackgroundTransparency = M.State.SideCardAlpha; M.UI.LogoCard.BorderSizePixel = 0
Instance.new("UICorner", M.UI.LogoCard).CornerRadius = UDim.new(0, 8); table.insert(M.State.SideCards, M.UI.LogoCard)

M.UI.Logo = Instance.new("TextLabel", M.UI.LogoCard)
M.UI.Logo.Size = UDim2.new(1, 0, 1, 0); M.UI.Logo.BackgroundTransparency = 1
M.UI.Logo.Text = "matsysense"; M.UI.Logo.TextColor3 = M.State.LogoCol; M.UI.Logo.Font = Enum.Font.GothamBlack; M.UI.Logo.TextSize = 15
M.UI.LogoGrad = Instance.new("UIGradient", M.UI.Logo)
M.UI.LogoGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 145, 160)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 145, 160))
})
M.UI.LogoGrad.Rotation = 45; M.UI.LogoGrad.Offset = Vector2.new(-1, 0)

task.spawn(function()
    while task.wait(3.0) do
        if M.State.IsShutDown then break end
        if M.State.MenuOpen and M.UI.LogoGrad and M.UI.LogoGrad.Parent then
            M.Services.T:Create(M.UI.LogoGrad, TweenInfo.new(2.2, Enum.EasingStyle.Linear), {Offset = Vector2.new(1, 0)}):Play()
            task.wait(2.3)
            if M.UI.LogoGrad and M.UI.LogoGrad.Parent then M.UI.LogoGrad.Offset = Vector2.new(-1, 0) end
        end
    end
end)

M.UI.ProfileCard = Instance.new("Frame", M.UI.Sidebar)
M.UI.ProfileCard.Size = UDim2.new(1, -16, 0, 52); M.UI.ProfileCard.Position = UDim2.new(0, 8, 1, -60)
M.UI.ProfileCard.BackgroundColor3 = M.State.SideCardBg; M.UI.ProfileCard.BackgroundTransparency = M.State.SideCardAlpha; M.UI.ProfileCard.BorderSizePixel = 0
Instance.new("UICorner", M.UI.ProfileCard).CornerRadius = UDim.new(0, 8); table.insert(M.State.SideCards, M.UI.ProfileCard)

M.UI.Avatar = M.F.NewAvatarView(M.UI.ProfileCard)
M.UI.Avatar.Size = UDim2.new(0, 36, 0, 36); M.UI.Avatar.Position = UDim2.new(0, 8, 0.5, -18)

M.UI.PName = Instance.new("TextLabel", M.UI.ProfileCard)
M.UI.PName.Size = UDim2.new(1, -54, 0, 16); M.UI.PName.Position = UDim2.new(0, 50, 0, 10); M.UI.PName.BackgroundTransparency = 1
M.UI.PName.Text = M.LP.Name; M.UI.PName.TextColor3 = Color3.fromRGB(240, 245, 255); M.UI.PName.Font = Enum.Font.GothamBold; M.UI.PName.TextSize = 12; M.UI.PName.TextXAlignment = Enum.TextXAlignment.Left

M.UI.PUptime = Instance.new("TextLabel", M.UI.ProfileCard)
M.UI.PUptime.Size = UDim2.new(1, -54, 0, 14); M.UI.PUptime.Position = UDim2.new(0, 50, 0, 26); M.UI.PUptime.BackgroundTransparency = 1
M.UI.PUptime.TextColor3 = Color3.fromRGB(150, 160, 185); M.UI.PUptime.Font = Enum.Font.Gotham; M.UI.PUptime.TextSize = 11; M.UI.PUptime.TextXAlignment = Enum.TextXAlignment.Left

-- Список вкладок: карточки такой же формы, как карточка с названием и карточка игрока. Если окно уменьшили и
-- карточки не помещаются, список прокручивается (полосы прокрутки не видно).
M.UI.TabContainer = Instance.new("ScrollingFrame", M.UI.Sidebar)
M.UI.TabContainer.Size = UDim2.new(1, 0, 1, -135); M.UI.TabContainer.Position = UDim2.new(0, 0, 0, 56); M.UI.TabContainer.BackgroundTransparency = 1
M.UI.TabContainer.BorderSizePixel = 0; M.UI.TabContainer.ScrollBarThickness = 0
M.UI.TabContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y; M.UI.TabContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
M.UI.TabContainer.ScrollingDirection = Enum.ScrollingDirection.Y
local tLayout = Instance.new("UIListLayout", M.UI.TabContainer); tLayout.Padding = UDim.new(0, 4); tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local tabPad = Instance.new("UIPadding", M.UI.TabContainer); tabPad.PaddingTop = UDim.new(0, 2); tabPad.PaddingBottom = UDim.new(0, 2)

M.UI.ContentArea = Instance.new("Frame", M.UI.Main)
M.UI.ContentArea.Size = UDim2.new(0.75, 0, 1, -44)
M.UI.ContentArea.Position = UDim2.new(0.25, 0, 0, 40)
M.UI.ContentArea.BackgroundTransparency = 1

function M.F.CreatePage(name)
    local sf = Instance.new("ScrollingFrame", M.UI.ContentArea)
    sf.Size = UDim2.new(1, -16, 1, -10)
    sf.Position = UDim2.new(0, 8, 0, 6)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 6
    sf.ScrollBarImageColor3 = Color3.fromRGB(130, 145, 175)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.None
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.Visible = false
    sf.CanvasPosition = Vector2.zero

    local container = Instance.new("Frame", sf)
    container.Size = UDim2.new(1, -12, 0, 0)
    container.BackgroundTransparency = 1

    local l = Instance.new("UIListLayout", container)
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder

    local p = Instance.new("UIPadding", container)
    p.PaddingBottom = UDim.new(0, 24)
    p.PaddingTop = UDim.new(0, 2)
    p.PaddingRight = UDim.new(0, 2)

    l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local h = l.AbsoluteContentSize.Y + 36
        local curPos = sf.CanvasPosition
        container.Size = UDim2.new(1, -12, 0, h)
        sf.CanvasSize = UDim2.new(0, 0, 0, h)
        sf.CanvasPosition = curPos
    end)

    M.State.Pages[name] = {Frame = sf, Container = container}
    return container
end

-- Содержимое страницы строится только при первом открытии вкладки (или при загрузке конфига)
function M.F.BuildPage(name)
    local builder = M.Data.PageBuilders[name]
    if not builder then return end
    M.Data.PageBuilders[name] = nil
    local ok, err = pcall(builder)
    if not ok then warn("[Matsysense] Ошибка при создании страницы " .. name .. ": " .. tostring(err)) end
end

-- spread = true: страницы собираются по одной за кадр, поэтому загрузка конфига и экран загрузки не подвисают
-- одним рывком. Вызывать так можно только из потока, которому разрешено ждать (кнопка, запуск).
function M.F.BuildAllPages(spread)
    local names = {}
    for name in pairs(M.Data.PageBuilders) do names[#names + 1] = name end
    for _, name in ipairs(names) do
        M.F.BuildPage(name)
        if spread then task.wait() end
    end
end

function M.F.SwitchTab(name)
    if M.State.ActiveTab == name and M.State.Pages[name] and M.State.Pages[name].Frame.Visible then return end
    M.F.BuildPage(name)
    M.State.ActiveTab = name

    for n, b in pairs(M.State.TabButtons) do
        local isAct = (n == name)
        b.TextColor3 = isAct and M.State.Accent or Color3.fromRGB(160, 170, 190)
        b.BackgroundColor3 = M.State.SideCardBg
        b.BackgroundTransparency = isAct and math.clamp(M.State.SideCardAlpha * 0.55, 0, 1) or M.State.SideCardAlpha
        local stroke = M.Data.TabStrokes[n]
        if stroke then
            stroke.Color = M.State.Accent
            stroke.Transparency = isAct and 0.45 or 1
        end
        M.F.SetTabIcon(n, isAct and "active" or "idle")
        local ind = M.Data.TabInds[n]
        if ind then
            M.Services.T:Create(ind, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, 3, 0, isAct and 16 or 0)}):Play()
        end
    end

    for n, pPack in pairs(M.State.Pages) do
        if n == name then
            -- Страница просто сменяется на месте, без выезда: страница уже собрана (при наведении на вкладку)
            pPack.Frame.Position = UDim2.new(0, 8, 0, 6)
            pPack.Frame.Visible = true
        else
            pPack.Frame.Visible = false
        end
    end

    M.UI.PrevCard.Visible = (name == "Display") and M.UI.Main.Visible
    if M.UI.PrevCard.Visible then
        M.F.SyncPreviewPos()
        M.F.Update2DPreview()
    end
end

-- Значки вкладок рисуются из простых фигур (линии, кольца, точки), а не эмодзи: они одноцветные, чёткие и
-- перекрашиваются вместе с темой (серые, белые при наведении, акцентные у активной вкладки). Картинки не нужны.
-- Холст значка 20 x 20, координаты центров в пикселях. Кольцо рисуется рамкой UIStroke: она лежит снаружи
-- фигуры, поэтому размер кольца = внешний диаметр минус две толщины.
local ICON_IDLE, ICON_HOVER = Color3.fromRGB(150, 160, 182), Color3.fromRGB(255, 255, 255)

local function iconFill(icon, x, y, w, h, round, rotation)
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.fromOffset(x, y)
    f.Size = UDim2.fromOffset(w, h)
    f.BackgroundColor3 = icon.Color
    f.BorderSizePixel = 0
    if rotation then f.Rotation = rotation end
    if round then Instance.new("UICorner", f).CornerRadius = round end
    f.Parent = icon.Root
    table.insert(icon.Fills, f)
end

local function iconRing(icon, x, y, outerW, outerH, thickness, round)
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.fromOffset(x, y)
    f.Size = UDim2.fromOffset(outerW - 2 * thickness, outerH - 2 * thickness)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    if round then Instance.new("UICorner", f).CornerRadius = round end
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness
    stroke.Color = icon.Color
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = f
    f.Parent = icon.Root
    table.insert(icon.Strokes, stroke)
end

local FULL, SOFT, TINY = UDim.new(1, 0), UDim.new(0, 2), UDim.new(0, 1)

-- Рисунки значков: каждая функция получает значок и добавляет в него фигуры
local ICON_SHAPES = {
    Combat = function(i)         -- мишень
        iconRing(i, 10, 10, 14, 14, 1.5, FULL)
        iconFill(i, 10, 10, 4, 4, FULL)
        iconFill(i, 10, 2.5, 1.6, 5, TINY); iconFill(i, 10, 17.5, 1.6, 5, TINY)
        iconFill(i, 2.5, 10, 5, 1.6, TINY); iconFill(i, 17.5, 10, 5, 1.6, TINY)
    end,
    Movement = function(i)       -- две стрелки вперёд
        for _, apex in ipairs({9, 16}) do
            iconFill(i, apex - 2.83, 7.17, 8, 2, TINY, 45)
            iconFill(i, apex - 2.83, 12.83, 8, 2, TINY, -45)
        end
    end,
    Camera = function(i)         -- фотоаппарат
        iconRing(i, 10, 11.5, 18, 13, 1.5, SOFT)
        iconFill(i, 10, 4.5, 6, 3, TINY)
        iconRing(i, 10, 11.5, 7, 7, 1.5, FULL)
    end,
    Display = function(i)        -- глаз
        iconRing(i, 10, 10, 19, 11, 1.6, FULL)
        iconFill(i, 10, 10, 5, 5, FULL)
    end,
    World = function(i)          -- глобус
        iconRing(i, 10, 10, 17, 17, 1.5, FULL)
        iconRing(i, 10, 10, 8, 17, 1.2, FULL)
        iconFill(i, 10, 10, 16, 1.3, TINY)
    end,
    Player = function(i)         -- человек: голова и плечи
        iconFill(i, 10, 6, 7, 7, FULL)
        iconFill(i, 10, 18, 15, 15, FULL)
    end,
    Misc = function(i)           -- четыре квадрата
        iconFill(i, 5.5, 5.5, 7, 7, SOFT); iconFill(i, 14.5, 5.5, 7, 7, SOFT)
        iconFill(i, 5.5, 14.5, 7, 7, SOFT); iconFill(i, 14.5, 14.5, 7, 7, SOFT)
    end,
    System = function(i)         -- монитор
        iconRing(i, 10, 8.5, 18, 12, 1.5, SOFT)
        iconFill(i, 10, 15, 2, 3)
        iconFill(i, 10, 17.5, 8, 1.6, TINY)
    end,
    Configs = function(i)        -- дискета
        iconRing(i, 10, 10, 16, 16, 1.5, SOFT)
        iconFill(i, 10, 5.4, 7, 3.4, TINY)
        iconFill(i, 10, 14.4, 8, 4.4, TINY)
    end,
    Settings = function(i)       -- шестерёнка: кольцо и восемь зубцов
        iconRing(i, 10, 10, 12, 12, 2, FULL)
        for k = 0, 7 do
            local angle = math.rad(k * 45)
            iconFill(i, 10 + 7.4 * math.cos(angle), 10 + 7.4 * math.sin(angle), 4.4, 3, TINY, k * 45)
        end
    end
}

function M.F.SetIconColor(icon, color)
    if icon.Applied ~= nil and M.F.SameValue(icon.Applied, color) then return end
    icon.Applied = color
    for _, f in ipairs(icon.Fills) do f.BackgroundColor3 = color end
    for _, s in ipairs(icon.Strokes) do s.Color = color end
end

-- mode: "idle" (серый), "hover" (белый), "active" (цвет темы)
function M.F.SetTabIcon(tabName, mode)
    local icon = M.Data.TabIcons[tabName]
    if not icon then return end
    M.F.SetIconColor(icon, mode == "active" and M.State.Accent or (mode == "hover" and ICON_HOVER or ICON_IDLE))
end

function M.F.BuildTabIcon(tabName, parent)
    local root = Instance.new("Frame")
    root.Name = "Icon"
    root.AnchorPoint = Vector2.new(0, 0.5)
    root.Position = UDim2.new(0, -29, 0.5, 0)      -- UIPadding карточки сдвигает дочерние элементы на 38, итого x = 9
    root.Size = UDim2.fromOffset(20, 20)
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.ClipsDescendants = true                   -- плечи человека обрезаются по нижнему краю
    root.Parent = parent
    local icon = {Root = root, Fills = {}, Strokes = {}, Color = ICON_IDLE}
    local draw = ICON_SHAPES[tabName]
    if draw then draw(icon) end
    M.Data.TabIcons[tabName] = icon
    return icon
end

-- Вкладка - карточка той же формы и цвета, что карточка с названием и карточка игрока (входит в SideCards, поэтому
-- прозрачность и цвет карточек из настроек действуют и на неё). Слева значок, справа название.
function M.F.MakeTabBtn(tabKey, order)
    local tabName = tabKey:gsub("Tab_", "")
    local b = Instance.new("TextButton", M.UI.TabContainer)
    b.Size = UDim2.new(1, -16, 0, 30); b.LayoutOrder = order; b.AutoButtonColor = false; b.BorderSizePixel = 0
    b.BackgroundColor3 = M.State.SideCardBg; b.BackgroundTransparency = M.State.SideCardAlpha
    b.Text = M.Translate(tabKey); b.TextColor3 = Color3.fromRGB(160, 170, 190); b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local pad = Instance.new("UIPadding", b); pad.PaddingLeft = UDim.new(0, 38)
    table.insert(M.State.SideCards, b)

    -- Рамка активной вкладки (у неактивных скрыта)
    local stroke = Instance.new("UIStroke", b)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = M.State.Accent; stroke.Thickness = 1; stroke.Transparency = 1
    M.Data.TabStrokes[tabName] = stroke

    M.F.BuildTabIcon(tabName, b)

    -- Акцентная полоска слева у активной вкладки (x = 3)
    local ind = Instance.new("Frame", b)
    ind.AnchorPoint = Vector2.new(0, 0.5)
    ind.Position = UDim2.new(0, -35, 0.5, 0)
    ind.Size = UDim2.new(0, 3, 0, 0)
    ind.BackgroundColor3 = M.State.Accent
    ind.BorderSizePixel = 0
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)
    M.Data.TabInds[tabName] = ind
    table.insert(M.State.Sliders, ind)

    b.MouseEnter:Connect(function()
        -- Страницу готовим заранее, пока курсор над вкладкой: при клике она уже собрана и не подвисает
        task.defer(M.F.BuildPage, tabName)
        if M.State.ActiveTab ~= tabName then
            M.F.SetTabIcon(tabName, "hover")
            M.Services.T:Create(b, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = math.clamp(M.State.SideCardAlpha * 0.6, 0.03, 0.5)
            }):Play()
            M.Services.T:Create(stroke, TweenInfo.new(M.State.AnimSpeed), {Transparency = 0.8}):Play()
        end
    end)

    b.MouseLeave:Connect(function()
        if M.State.ActiveTab ~= tabName then
            M.F.SetTabIcon(tabName, "idle")
            M.Services.T:Create(b, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextColor3 = Color3.fromRGB(160, 170, 190),
                BackgroundTransparency = M.State.SideCardAlpha
            }):Play()
            M.Services.T:Create(stroke, TweenInfo.new(M.State.AnimSpeed), {Transparency = 1}):Play()
        end
    end)

    b.MouseButton1Click:Connect(function() M.F.SwitchTab(tabName) end)
    M.State.TabButtons[tabName] = b
    table.insert(M.Data.RegUI, { SetLanguage = function() b.Text = M.Translate(tabKey) end })
end

function M.F.MakeSection(parent, locKey, order)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 28)
    f.LayoutOrder = order
    f.BackgroundTransparency = 1

    local bar = Instance.new("Frame", f)
    bar.Size = UDim2.new(0, 3, 0, 12)
    bar.AnchorPoint = Vector2.new(0, 0.5)
    bar.Position = UDim2.new(0, 4, 0.5, 1)
    bar.BackgroundColor3 = M.State.Accent
    bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    table.insert(M.State.Sliders, bar)

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = M.Upper(M.Translate(locKey))
    lbl.TextColor3 = Color3.fromRGB(140, 155, 185)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local line = Instance.new("Frame", f)
    line.Size = UDim2.new(1, -8, 0, 1)
    line.Position = UDim2.new(0, 4, 1, -2)
    line.BackgroundColor3 = Color3.fromRGB(35, 40, 54)
    line.BorderSizePixel = 0

    table.insert(M.Data.RegUI, { SetLanguage = function() lbl.Text = M.Upper(M.Translate(locKey)) end })
    return f
end

function M.F.MakeCard(parent, h)
    local c = Instance.new("Frame", parent)
    c.Size = UDim2.new(1, 0, 0, h or 42); c.BackgroundColor3 = M.State.CardBg; c.BackgroundTransparency = M.State.CardAlpha; c.BorderSizePixel = 0
    Instance.new("UICorner", c).CornerRadius = UDim.new(0, 10)
    table.insert(M.State.Cards, c)

    return c
end

-- Оформление переключателей
M.Theme = {
    ToggleOff = Color3.fromRGB(46, 50, 64),
    ThumbOff = UDim2.new(0, 3, 0.5, 0),
    ThumbOn = UDim2.new(1, -21, 0.5, 0)
}

-- Переключатель: цветная дорожка и белый круглый бегунок
function M.F.StyleToggle(trk, thm, on)
    trk.BackgroundColor3 = on and M.State.Accent or M.Theme.ToggleOff
    thm.Size = UDim2.new(0, 18, 0, 18)
    thm.AnchorPoint = Vector2.new(0, 0.5)
    thm.Position = on and M.Theme.ThumbOn or M.Theme.ThumbOff
    thm.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
end

function M.F.AnimateToggle(trk, thm, on)
    local d = math.max(M.State.AnimSpeed, 0.1)
    M.Services.T:Create(thm, TweenInfo.new(d * 1.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = on and M.Theme.ThumbOn or M.Theme.ThumbOff}):Play()
    M.Services.T:Create(trk, TweenInfo.new(d, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {BackgroundColor3 = on and M.State.Accent or M.Theme.ToggleOff}):Play()
end

function M.F.MakeToggle(parent, locKey, stateKey, order, onTog, allowBind)
    local c = M.F.MakeCard(parent, 40); c.LayoutOrder = order
    M.F.AttachTooltip(c, stateKey)

    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1, allowBind and -130 or -75, 1, 0); l.Position = UDim2.new(0, 12, 0, 0); l.BackgroundTransparency = 1
    l.Text = M.Translate(locKey); l.TextColor3 = Color3.fromRGB(240, 245, 255); l.Font = Enum.Font.GothamMedium; l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left

    local bBtn = nil
    if allowBind then
        bBtn = Instance.new("TextButton", c)
        bBtn.Size = UDim2.new(0, 48, 0, 24); bBtn.Position = UDim2.new(1, -118, 0.5, -12); bBtn.BackgroundColor3 = Color3.fromRGB(16, 18, 25); bBtn.Text = "NONE"; bBtn.TextColor3 = Color3.fromRGB(150, 160, 185); bBtn.Font = Enum.Font.GothamBold; bBtn.TextSize = 11
        Instance.new("UICorner", bBtn).CornerRadius = UDim.new(0, 6)
    end

    local trk = Instance.new("TextButton", c)
    trk.Size = UDim2.new(0, 48, 0, 24); trk.Position = UDim2.new(1, -60, 0.5, -12); trk.Text = ""; trk.AutoButtonColor = false
    Instance.new("UICorner", trk).CornerRadius = UDim.new(1, 0)

    local thm = Instance.new("Frame", trk)
    thm.BorderSizePixel = 0
    Instance.new("UICorner", thm).CornerRadius = UDim.new(1, 0)
    M.F.StyleToggle(trk, thm, M.State[stateKey])

    local function uv(val)
        M.F.AnimateToggle(trk, thm, val)
    end

    local function trigger()
        M.State[stateKey] = not M.State[stateKey]
        uv(M.State[stateKey])
        if onTog then onTog(M.State[stateKey]) end
        M.F.NotifyToggle(stateKey, locKey, M.State[stateKey])
    end
    trk.MouseButton1Click:Connect(trigger)
    -- Список дорожек нужен, чтобы смена основного цвета перекрашивала уже включённые переключатели
    table.insert(M.Data.ToggleRefs, {Track = trk, IsOn = function() return M.State[stateKey] == true end})

    table.insert(M.Data.RegUI, {
        Key = stateKey,
        SetVisual = function(val) uv(val) end,
        SetLanguage = function() l.Text = M.Translate(locKey) end,
        Callback = onTog
    })

    if allowBind and bBtn then
        local bDat = {Key = nil, Trigger = trigger}
        table.insert(M.State.Binds, bDat)

        bBtn.MouseButton1Click:Connect(function()
            if M.State.ListeningBind then
                M.State.ListeningBind = nil
                bBtn.Text = bDat.Key and bDat.Key.Name:upper() or "NONE"
                bBtn.TextColor3 = bDat.Key and M.State.Accent or Color3.fromRGB(150, 160, 185)
            else
                M.State.ListeningBind = {
                    Set = function(k) bDat.Key = k; bBtn.Text = k and k.Name:upper() or "NONE"; bBtn.TextColor3 = k and M.State.Accent or Color3.fromRGB(150, 160, 185) end,
                    Cancel = function() bBtn.Text = bDat.Key and bDat.Key.Name:upper() or "NONE"; bBtn.TextColor3 = bDat.Key and M.State.Accent or Color3.fromRGB(150, 160, 185) end
                }
                bBtn.Text = "..."
                bBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
            end
        end)
    end
    return c
end

function M.F.MakeSpeedCard(parent, locKey, stateValKey, isFly, order, tFn, onV)
    local c = M.F.MakeCard(parent, 40); c.LayoutOrder = order
    M.F.AttachTooltip(c, stateValKey)

    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1, -170, 1, 0); l.Position = UDim2.new(0, 12, 0, 0); l.BackgroundTransparency = 1
    l.Text = M.Translate(locKey); l.TextColor3 = Color3.fromRGB(240, 245, 255); l.Font = Enum.Font.GothamMedium; l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("TextBox", c)
    box.Size = UDim2.new(0, 46, 0, 24); box.Position = UDim2.new(1, -118, 0.5, -12); box.BackgroundColor3 = Color3.fromRGB(15, 17, 24); box.Text = tostring(M.State[stateValKey]); box.TextColor3 = Color3.fromRGB(255, 255, 255); box.Font = Enum.Font.GothamBold; box.TextSize = 12; box.BorderSizePixel = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n and n > 0 then onV(n); M.State[stateValKey] = n else box.Text = tostring(M.State[stateValKey]) end
    end)

    local trk = Instance.new("TextButton", c)
    trk.Size = UDim2.new(0, 48, 0, 24); trk.Position = UDim2.new(1, -60, 0.5, -12); trk.Text = ""; trk.AutoButtonColor = false
    Instance.new("UICorner", trk).CornerRadius = UDim.new(1, 0)

    local thm = Instance.new("Frame", trk)
    thm.BorderSizePixel = 0
    Instance.new("UICorner", thm).CornerRadius = UDim.new(1, 0)
    M.F.StyleToggle(trk, thm, false)

    local function uv()
        local a = isFly and M.State.FlightMode or M.State.Speed
        box.Text = tostring(M.State[stateValKey])
        M.F.AnimateToggle(trk, thm, a and true or false)
    end

    local function t()
        if isFly then
            if M.State.FlightMode then M.F.StopFlying() else M.F.StartFlying() end
        else
            M.State.Speed = not M.State.Speed
        end
        if tFn then tFn() end
        uv()
        if isFly then
            M.F.NotifyToggle("FlightMode", locKey, M.State.FlightMode)
        else
            M.F.NotifyToggle("Speed", locKey, M.State.Speed)
        end
    end
    trk.MouseButton1Click:Connect(t)
    local speedKey = isFly and "FlightMode" or "Speed"
    table.insert(M.Data.ToggleRefs, {Track = trk, IsOn = function() return M.State[speedKey] == true end})

    table.insert(M.Data.RegUI, {
        Key = stateValKey,
        SetVisual = function(val) box.Text = tostring(val); uv() end,
        SetLanguage = function() l.Text = M.Translate(locKey) end,
        Callback = onV
    })
    return c
end

-- Эти ползунки должны давать только целые числа (количество штук, толщина в пикселях)
local INTEGER_SLIDERS = {OrbitCount = true, PlayerViewHealthBarThick = true}

local UNIT_KEYS = {["мс"] = "Unit_ms", ["с"] = "Unit_s", ["м"] = "Unit_m", ["штук"] = "Unit_pcs"}
function M.F.UnitText(un)
    local key = UNIT_KEYS[un]
    return key and M.Translate(key) or un
end

function M.F.MakeSlider(parent, locKey, stateKey, mn, mx, un, order, cb)
    -- Целые числа для больших диапазонов. Секунды ("с") всегда дробные.
    -- Раньше проверка по букве "с" случайно делала дробными и "мс" (миллисекунды).
    local useInteger = (mx > 10 and un ~= "с") or INTEGER_SLIDERS[stateKey] == true
    local c = M.F.MakeCard(parent, 40); c.LayoutOrder = order
    local labelText = M.Translate(locKey) .. (un and ("  " .. M.F.UnitText(un)) or "")
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(0.42, 0, 1, 0); l.Position = UDim2.new(0, 12, 0, 0); l.BackgroundTransparency = 1
    l.Text = labelText; l.TextColor3 = Color3.fromRGB(190, 200, 220); l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left

    local trk = Instance.new("Frame", c)
    trk.Size = UDim2.new(0.36, 0, 0, 6); trk.Position = UDim2.new(0.44, 0, 0.5, -3); trk.BackgroundColor3 = Color3.fromRGB(28, 32, 44); trk.Active = true
    Instance.new("UICorner", trk).CornerRadius = UDim.new(1, 0)

    local f = Instance.new("Frame", trk)
    f.Size = UDim2.new(math.clamp((M.State[stateKey] - mn) / (mx - mn), 0.02, 1), 0, 1, 0); f.BackgroundColor3 = M.State.Accent; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
    table.insert(M.State.Sliders, f)

    -- Круглая ручка на конце заполнения: двигается вместе с ним
    local handle = Instance.new("Frame", f)
    handle.AnchorPoint = Vector2.new(1, 0.5)
    handle.Position = UDim2.new(1, 3, 0.5, 0)
    handle.Size = UDim2.new(0, 12, 0, 12)
    handle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    handle.BorderSizePixel = 0
    handle.ZIndex = 2
    Instance.new("UICorner", handle).CornerRadius = UDim.new(1, 0)
    local handleStroke = Instance.new("UIStroke", handle)
    handleStroke.Thickness = 1
    handleStroke.Color = Color3.fromRGB(0, 0, 0)
    handleStroke.Transparency = 0.75

    local box = Instance.new("TextBox", c)
    box.Size = UDim2.new(0, 52, 0, 24); box.Position = UDim2.new(1, -60, 0.5, -12)
    box.BackgroundColor3 = Color3.fromRGB(16, 19, 27); box.Text = tostring(M.State[stateKey]); box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.GothamBold; box.TextSize = 12; box.BorderSizePixel = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    -- instant = true во время перетаскивания: ставим размер сразу. Раньше на каждое движение мыши создавался
    -- новый твин, они копились и давали лаги и "резиновый" ползунок.
    local sizeTween = nil
    local function setVisual(val, instant)
        box.Text = tostring(val)
        local goal = UDim2.new(math.clamp((val - mn) / (mx - mn), 0.02, 1), 0, 1, 0)
        if sizeTween then
            sizeTween:Cancel()
            sizeTween = nil
        end
        if instant then
            f.Size = goal
        else
            sizeTween = M.Services.T:Create(f, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = goal})
            sizeTween:Play()
        end
    end

    local function upd(pos)
        local curAbsPos = trk.AbsolutePosition
        local curAbsSz = trk.AbsoluteSize
        if curAbsSz.X <= 0 then return end
        local r = math.clamp((pos.X - curAbsPos.X) / curAbsSz.X, 0, 1)
        local val = mn + (r * (mx - mn))
        val = useInteger and math.round(val) or (math.floor(val * 100) / 100)
        M.State[stateKey] = val
        setVisual(val, true)
        if cb then cb(val) end
    end

    trk.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            upd(inp.Position); M.Data.DragHandler = upd
        end
    end)

    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then
            n = math.clamp(n, mn, mx)
            if useInteger then n = math.round(n) else n = math.floor(n * 100) / 100 end
            M.State[stateKey] = n
            setVisual(n)
            if cb then cb(n) end
        else
            box.Text = tostring(M.State[stateKey])
        end
    end)

    table.insert(M.Data.RegUI, {
        Key = stateKey, Min = mn, Max = mx,
        SetVisual = function(val) setVisual(val, M.Data.Importing) end,
        SetLanguage = function() l.Text = M.Translate(locKey) .. (un and ("  " .. M.F.UnitText(un)) or "") end,
        Callback = cb
    })
    return c
end

-- ==============================================================================
-- [ МАТЕМАТИКА ПАЛИТРЫ ]
-- Чистые функции без объектов Roblox.
-- ==============================================================================
M.ColorMath = {}

-- У белого, серого и чёрного оттенок (hue) не определён: Color3:ToHSV() возвращает 0.
-- Раньше палитра брала этот 0 и "теряла" выбранный оттенок. Теперь при таких цветах оставляем прежний.
function M.ColorMath.ResolveHue(previousHue, newHue, saturation, value)
    if saturation > 0.001 and value > 0.001 then
        return newHue
    end
    return previousHue
end

-- Если цвет почти белый/серый (мало насыщенности) или почти чёрный (мало яркости),
-- движение ползунка оттенка не меняет итоговый цвет и выглядит как "не работает".
-- Поэтому перед сменой оттенка поднимаем насыщенность и яркость до видимых значений.
function M.ColorMath.PrepareForHueChange(saturation, value)
    if saturation < 0.05 then saturation = 0.55 end
    if value < 0.15 then value = 1 end
    return saturation, value
end

function M.F.MakePicker(parent, locKey, stateColorKey, order, cb)
    local c = M.F.MakeCard(parent, 118); c.LayoutOrder = order
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(0.32, 0, 0, 20); l.Position = UDim2.new(0, 12, 0, 8); l.BackgroundTransparency = 1
    l.Text = M.Translate(locKey); l.TextColor3 = Color3.fromRGB(240, 245, 255); l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left

    local prevBox = Instance.new("Frame", c)
    prevBox.Size = UDim2.new(0, 16, 0, 16); prevBox.Position = UDim2.new(0.34, 0, 0, 10); prevBox.BackgroundColor3 = M.State[stateColorKey]; prevBox.BorderSizePixel = 0
    Instance.new("UICorner", prevBox).CornerRadius = UDim.new(0, 4)
    local pbStroke = Instance.new("UIStroke", prevBox)
    pbStroke.Color = Color3.fromRGB(60, 70, 95); pbStroke.Thickness = 1

    local cH, cS, cV = M.State[stateColorKey]:ToHSV()
    local cv = Instance.new("Frame", c)
    cv.Size = UDim2.new(0.55, -20, 0, 52); cv.Position = UDim2.new(0.42, 0, 0, 8); cv.BackgroundColor3 = Color3.fromHSV(cH, 1, 1); cv.Active = true
    Instance.new("UICorner", cv).CornerRadius = UDim.new(0, 6)

    local sat = Instance.new("Frame", cv); sat.Size = UDim2.new(1, 0, 1, 0); sat.BackgroundColor3 = Color3.fromRGB(255, 255, 255); sat.BorderSizePixel = 0; Instance.new("UICorner", sat).CornerRadius = UDim.new(0, 6)
    local sg = Instance.new("UIGradient", sat); sg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})

    local val = Instance.new("Frame", cv); val.Size = UDim2.new(1, 0, 1, 0); val.BackgroundColor3 = Color3.fromRGB(0, 0, 0); val.BorderSizePixel = 0; Instance.new("UICorner", val).CornerRadius = UDim.new(0, 6)
    local vg = Instance.new("UIGradient", val); vg.Rotation = 90; vg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})

    local pin = Instance.new("Frame", cv); pin.Size = UDim2.new(0, 8, 0, 8); pin.AnchorPoint = Vector2.new(0.5, 0.5); pin.Position = UDim2.new(cS, 0, 1 - cV, 0); pin.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Instance.new("UICorner", pin).CornerRadius = UDim.new(1, 0)

    local hb = Instance.new("Frame", c)
    hb.Size = UDim2.new(0.55, -20, 0, 8); hb.Position = UDim2.new(0.42, 0, 0, 66); hb.BackgroundColor3 = Color3.fromRGB(255, 255, 255); hb.Active = true
    Instance.new("UICorner", hb).CornerRadius = UDim.new(1, 0)
    local hg = Instance.new("UIGradient", hb)
    hg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
    })

    -- Маркер на полосе оттенка: раньше положения ползунка не было видно вообще
    local hueKnob = Instance.new("Frame", hb)
    hueKnob.Size = UDim2.new(0, 6, 0, 14)
    hueKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    hueKnob.Position = UDim2.new(cH, 0, 0.5, 0)
    hueKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hueKnob.BorderSizePixel = 0
    Instance.new("UICorner", hueKnob).CornerRadius = UDim.new(1, 0)
    local hkStroke = Instance.new("UIStroke", hueKnob)
    hkStroke.Color = Color3.fromRGB(20, 22, 30); hkStroke.Thickness = 1

    local toolRow = Instance.new("Frame", c)
    toolRow.Size = UDim2.new(1, -24, 0, 28)
    toolRow.Position = UDim2.new(0, 12, 0, 82)
    toolRow.BackgroundTransparency = 1

    local hexBox = Instance.new("TextBox", toolRow)
    hexBox.Size = UDim2.new(0, 68, 0, 22); hexBox.Position = UDim2.new(0, 0, 0.5, -11)
    hexBox.BackgroundColor3 = Color3.fromRGB(15, 17, 24); hexBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    hexBox.Font = Enum.Font.GothamBold; hexBox.TextSize = 11; hexBox.Text = "#" .. M.State[stateColorKey]:ToHex():upper()
    hexBox.ClearTextOnFocus = false; hexBox.BorderSizePixel = 0
    Instance.new("UICorner", hexBox).CornerRadius = UDim.new(0, 5)

    local btnClear = Instance.new("TextButton", toolRow)
    btnClear.Size = UDim2.new(0, 22, 0, 22); btnClear.Position = UDim2.new(0, 72, 0.5, -11)
    btnClear.BackgroundColor3 = Color3.fromRGB(32, 36, 48); btnClear.Text = "×"
    btnClear.TextColor3 = Color3.fromRGB(220, 225, 240); btnClear.Font = Enum.Font.GothamBold; btnClear.TextSize = 13
    Instance.new("UICorner", btnClear).CornerRadius = UDim.new(0, 5)

    local btnPaste = Instance.new("TextButton", toolRow)
    btnPaste.Size = UDim2.new(0, 22, 0, 22); btnPaste.Position = UDim2.new(0, 98, 0.5, -11)
    btnPaste.BackgroundColor3 = Color3.fromRGB(32, 36, 48); btnPaste.Text = "📋"
    btnPaste.TextColor3 = Color3.fromRGB(220, 225, 240); btnPaste.Font = Enum.Font.Gotham; btnPaste.TextSize = 11
    Instance.new("UICorner", btnPaste).CornerRadius = UDim.new(0, 5)

    local quickSlots = {}
    local slotSize, slotGap = 22, 6

    for i = 1, 5 do
        local slot = Instance.new("TextButton", toolRow)
        slot.Size = UDim2.new(0, slotSize, 0, slotSize)
        slot.Position = UDim2.new(1, -((5 - i + 1) * (slotSize + slotGap)), 0.5, -11)
        slot.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
        slot.BorderSizePixel = 0
        slot.Text = ""
        Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 5)

        local sStroke = Instance.new("UIStroke", slot)
        sStroke.Color = Color3.fromRGB(50, 58, 78)
        sStroke.Thickness = 1

        local icon = Instance.new("TextLabel", slot)
        icon.Size = UDim2.new(1, 0, 1, 0); icon.BackgroundTransparency = 1
        icon.Text = "+"
        icon.TextColor3 = Color3.fromRGB(150, 160, 185)
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 12

        table.insert(quickSlots, {Btn = slot, Stroke = sStroke, Icon = icon})
    end

    local function refreshSlotVisuals()
        for idx, slotData in ipairs(quickSlots) do
            local col = M.Data.GlobalPalette[idx]
            if col then
                slotData.Btn.BackgroundColor3 = col
                slotData.Icon.Text = ""
                slotData.Stroke.Color = Color3.fromRGB(90, 100, 130)
            else
                slotData.Btn.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
                slotData.Icon.Text = "+"
                slotData.Stroke.Color = Color3.fromRGB(50, 58, 78)
            end
        end
    end

    table.insert(M.Data.PaletteCallers, refreshSlotVisuals)
    refreshSlotVisuals()

    -- keepHsv = true: цвет выбран самой палитрой, значит H/S/V уже известны, и пересчитывать их из цвета не нужно
    -- (пересчёт округлял значения и сбрасывал оттенок у серых цветов).
    local function setVisual(colorObj, keepHsv)
        if not keepHsv then
            local h, sat, val = colorObj:ToHSV()
            cH = M.ColorMath.ResolveHue(cH, h, sat, val)
            cS, cV = sat, val
        end
        cv.BackgroundColor3 = Color3.fromHSV(cH, 1, 1)
        prevBox.BackgroundColor3 = colorObj
        pin.Position = UDim2.new(math.clamp(cS, 0, 1), 0, math.clamp(1 - cV, 0, 1), 0)
        hueKnob.Position = UDim2.new(math.clamp(cH, 0, 1), 0, 0.5, 0)
        hexBox.Text = "#" .. colorObj:ToHex():upper()
    end

    local function applyColor(col, keepHsv)
        M.State[stateColorKey] = col
        setVisual(col, keepHsv)
        if cb then cb(col) end
    end

    for idx, slotData in ipairs(quickSlots) do
        slotData.Btn.MouseButton1Click:Connect(function()
            if M.Data.GlobalPalette[idx] then
                applyColor(M.Data.GlobalPalette[idx])
            else
                M.Data.GlobalPalette[idx] = M.State[stateColorKey]
                for _, syncFn in ipairs(M.Data.PaletteCallers) do
                    syncFn()
                end
            end
        end)
    end

    local function tryHexInput(str)
        local clean = str:gsub("#", ""):gsub("%s+", "")
        if #clean == 6 then
            local succ, parsed = pcall(function() return Color3.fromHex(clean) end)
            if succ and parsed then
                applyColor(parsed)
            end
        end
    end

    hexBox.FocusLost:Connect(function()
        tryHexInput(hexBox.Text)
        hexBox.Text = "#" .. M.State[stateColorKey]:ToHex():upper()
    end)

    btnClear.MouseButton1Click:Connect(function()
        hexBox.Text = ""
        hexBox:CaptureFocus()
    end)

    btnPaste.MouseButton1Click:Connect(function()
        hexBox:CaptureFocus()
    end)

    local function updSV(pos)
        local curPos = cv.AbsolutePosition; local curSz = cv.AbsoluteSize
        if curSz.X == 0 or curSz.Y == 0 then return end
        cS = math.clamp((pos.X - curPos.X) / curSz.X, 0, 1)
        cV = 1 - math.clamp((pos.Y - curPos.Y) / curSz.Y, 0, 1)
        pin.Position = UDim2.new(cS, 0, 1 - cV, 0)
        applyColor(Color3.fromHSV(cH, cS, cV), true)
    end

    local function updHue(pos)
        local curPos = hb.AbsolutePosition; local curSz = hb.AbsoluteSize
        if curSz.X == 0 then return end
        cH = math.clamp((pos.X - curPos.X) / curSz.X, 0, 1)
        -- У белого/серого/чёрного цвета (туман и облака по умолчанию белые) оттенок не виден,
        -- поэтому ползунок "не работал". Поднимаем насыщенность и яркость, чтобы цвет изменился.
        cS, cV = M.ColorMath.PrepareForHueChange(cS, cV)
        applyColor(Color3.fromHSV(cH, cS, cV), true)
    end

    cv.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            updSV(inp.Position); M.Data.DragHandler = updSV
        end
    end)
    hb.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            updHue(inp.Position); M.Data.DragHandler = updHue
        end
    end)

    table.insert(M.Data.RegUI, {
        Key = stateColorKey,
        SetVisual = setVisual,
        SetLanguage = function() l.Text = M.Translate(locKey) end,
        Callback = cb
    })
    return c
end

-- Названия вариантов: если для варианта есть ключ перевода Opt_<вариант>, показывается он, иначе сам вариант.
local function optionLabel(opt)
    local key = "Opt_" .. tostring(opt)
    if M.L10N.Dict[key] then return M.Translate(key) end
    return tostring(opt)
end

function M.F.MakeDropdown(parent, locKey, options, stateKey, order, cb)
    local c = M.F.MakeCard(parent, 40); c.LayoutOrder = order
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(0.45, 0, 1, 0); l.Position = UDim2.new(0, 12, 0, 0); l.BackgroundTransparency = 1
    l.Text = M.Translate(locKey); l.TextColor3 = Color3.fromRGB(240, 245, 255); l.Font = Enum.Font.GothamMedium; l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left

    local b = Instance.new("TextButton", c)
    b.Size = UDim2.new(0, 115, 0, 24); b.Position = UDim2.new(1, -125, 0.5, -12); b.BackgroundColor3 = Color3.fromRGB(38, 42, 54); b.Text = optionLabel(M.State[stateKey]); b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Font = Enum.Font.GothamBold; b.TextSize = 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

    local drop = Instance.new("Frame", c)
    drop.Size = UDim2.new(0, 115, 0, #options * 26); drop.Position = UDim2.new(1, -125, 1, 2); drop.BackgroundColor3 = Color3.fromRGB(20, 24, 32); drop.Visible = false; drop.ZIndex = 15
    Instance.new("UICorner", drop).CornerRadius = UDim.new(0, 6); Instance.new("UIListLayout", drop)

    local optionButtons = {}
    b.MouseButton1Click:Connect(function() drop.Visible = not drop.Visible end)
    for _, opt in ipairs(options) do
        local ob = Instance.new("TextButton", drop)
        ob.Size = UDim2.new(1, 0, 0, 26); ob.BackgroundTransparency = 1; ob.Text = optionLabel(opt); ob.TextColor3 = Color3.fromRGB(200, 210, 230); ob.Font = Enum.Font.Gotham; ob.TextSize = 12; ob.ZIndex = 16
        optionButtons[opt] = ob
        ob.MouseButton1Click:Connect(function()
            b.Text = optionLabel(opt)
            drop.Visible = false
            M.State[stateKey] = opt
            if cb then cb(opt) end
        end)
    end

    table.insert(M.Data.RegUI, {
        Key = stateKey,
        SetVisual = function(val) b.Text = optionLabel(val) end,
        SetLanguage = function()
            l.Text = M.Translate(locKey)
            b.Text = optionLabel(M.State[stateKey])
            for opt, ob in pairs(optionButtons) do ob.Text = optionLabel(opt) end
        end,
        Callback = cb
    })
    return c
end

-- Ряд из нескольких кнопок. items = { {Key = "локализация", Id = "..."}, ... }
function M.F.MakePresetRow(parent, order, items, onPick)
    local c = M.F.MakeCard(parent, 46)
    c.LayoutOrder = order
    local count = #items
    local buttons = {}
    for i, item in ipairs(items) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1 / count, -8, 0, 30)
        b.Position = UDim2.new((i - 1) / count, 6, 0.5, -15)
        b.BackgroundColor3 = Color3.fromRGB(38, 42, 54)
        b.AutoButtonColor = false
        b.Text = M.Translate(item.Key)
        b.TextColor3 = Color3.fromRGB(235, 240, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 9)
        bc.Parent = b
        b.Parent = c

        b.MouseEnter:Connect(function()
            M.Services.T:Create(b, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(58, 64, 82)}):Play()
        end)
        b.MouseLeave:Connect(function()
            M.Services.T:Create(b, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(38, 42, 54)}):Play()
        end)
        b.MouseButton1Click:Connect(function() onPick(item.Id) end)
        buttons[i] = b
    end
    table.insert(M.Data.RegUI, {
        SetLanguage = function()
            for i, item in ipairs(items) do buttons[i].Text = M.Translate(item.Key) end
        end
    })
    return c
end

function M.F.MakeTextInput(parent, locKey, stateKey, placeholderKey, order, cb)
    local c = M.F.MakeCard(parent, 84)
    c.LayoutOrder = order
    M.F.AttachTooltip(c, stateKey)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -24, 0, 18)
    label.Position = UDim2.new(0, 12, 0, 8)
    label.BackgroundTransparency = 1
    label.Text = M.Translate(locKey)
    label.TextColor3 = Color3.fromRGB(235, 238, 248)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = c

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -24, 0, 46)
    box.Position = UDim2.new(0, 12, 0, 30)
    box.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.TextWrapped = true
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = Enum.TextYAlignment.Center
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 12
    box.TextColor3 = Color3.fromRGB(235, 238, 248)
    box.PlaceholderText = M.Translate(placeholderKey)
    box.PlaceholderColor3 = Color3.fromRGB(105, 114, 135)
    box.Text = tostring(M.State[stateKey] or "")

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = box
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = box
    box.Parent = c

    box.FocusLost:Connect(function()
        local clean = string.match(box.Text, "^%s*(.-)%s*$") or ""
        box.Text = clean
        M.State[stateKey] = clean
        cb(clean)
    end)

    table.insert(M.Data.RegUI, {
        Key = stateKey,
        SetVisual = function(val) box.Text = tostring(val) end,
        SetLanguage = function()
            label.Text = M.Translate(locKey)
            box.PlaceholderText = M.Translate(placeholderKey)
        end,
        Callback = cb
    })
    return c, box
end

function M.F.UpdateLanguageUI()
    for _, item in ipairs(M.Data.RegUI) do if item.SetLanguage then item.SetLanguage() end end
end

-- ==============================================================================
-- [ CONFIG MANAGER - ХРАНИЛИЩЕ НА ДИСКЕ ]
-- ==============================================================================

-- Эти значения живут только во время игры. Раньше они попадали в конфиг и ломали загрузку
-- (например, MenuOpen/IsDead/FlightMode восстанавливались из файла, а Orig* подменяли настоящие настройки игры).
M.CFG.RuntimeKeys = {
    Uptime = true, CurFPS = true, IsDead = true, IsShutDown = true,
    MenuOpen = true, TabSwitching = true, FlightMode = true,
    SpectateOn = true      -- разовые действия сессии, при запуске сами не включаются
}

function M.CFG.IsRuntimeKey(k)
    return M.CFG.RuntimeKeys[k] == true or string.sub(k, 1, 4) == "Orig"
end

-- Прежние названия настроек из старых сохранённых конфигов. При загрузке они переносятся на новые названия,
-- поэтому ранее сохранённые конфиги продолжают работать.
M.CFG.LegacyKeys = {
    AirVault = "InfiniteJumps",
    AirVectoring = "AirControl",
    NetworkAlive = "IdleProtection",
    Esp = "PlayerView",
    EspAlpha = "PlayerViewAlpha",
    EspBox = "PlayerViewBox",
    EspBoxCol = "PlayerViewBoxCol",
    EspBoxThick = "PlayerViewBoxThick",
    EspDistance = "PlayerViewDistance",
    EspFill = "PlayerViewFill",
    EspFontWeight = "PlayerViewFontWeight",
    EspGuis = "PlayerViewGuis",
    EspHealthBar = "PlayerViewHealthBar",
    EspHealthBarThick = "PlayerViewHealthBarThick",
    EspHealthCol = "PlayerViewHealthCol",
    EspHealthColor = "PlayerViewHealthColor",
    EspHealthPos = "PlayerViewHealthPos",
    EspHealthText = "PlayerViewHealthText",
    EspLine = "PlayerViewLine",
    EspNameCol = "PlayerViewNameCol",
    EspNameOutCol = "PlayerViewNameOutCol",
    EspOnSelf = "PlayerViewOnSelf",
    EspTeamCheck = "PlayerViewTeamCheck",
    EspTextSize = "PlayerViewTextSize",
    EspTracers = "PlayerViewLines",
    ImpulseStutters = "KnockbackProtection",
    IsUninjected = "IsShutDown",
    JitterSpin = "JerkySpin",
    KinematicBoost = "FlightSpeed",
    Levitation = "FlightMode",
    PhaseCollision = "WalkThroughWalls",
    PitchModification = "HeadTiltOn",
    RotationYaw = "SpinCharacter",
    StateForce = "FallProtection",
    TracerCol = "PlayerLineCol",
}

M.CFG.GetExportData = function()
    local data = {}
    for k, v in pairs(M.State) do
        local t = typeof(v)
        if M.CFG.IsRuntimeKey(k) then
            -- пропускаем
        elseif t == "boolean" or t == "number" or t == "string" then
            data[k] = v
        elseif t == "Color3" then
            data[k] = {__type = "Color3", hex = v:ToHex()}
        end
    end
    if M.UI.Pill then
        data["__PillPos"] = {XS = M.UI.Pill.Position.X.Scale, XO = M.UI.Pill.Position.X.Offset, YS = M.UI.Pill.Position.Y.Scale, YO = M.UI.Pill.Position.Y.Offset}
    end
    if M.UI.Main then
        data["__MainPos"] = {XS = M.UI.Main.Position.X.Scale, XO = M.UI.Main.Position.X.Offset, YS = M.UI.Main.Position.Y.Scale, YO = M.UI.Main.Position.Y.Offset}
        data["__MainSize"] = {X = M.UI.Main.Size.X.Offset, Y = M.UI.Main.Size.Y.Offset}
    end
    return data
end

-- Функции, которые меняют движение, физику или выполняют действия за вас. При запуске из автозагрузки конфига они
-- НЕ включаются сами: так игра начинается спокойно, без уже включённого полёта, ускорения или вращения.
-- Включить их можно вручную или загрузкой конфига кнопкой. Отключается в Настройках («Спокойный старт»).
M.CFG.ManualStartKeys = {
    FlightMode = true, Speed = true, WalkThroughWalls = true, InfiniteJumps = true, AutoJump = true, AirControl = true,
    TriggerAssist = true, TriggerLoop = true, AimAssist = true, KnockbackProtection = true, FallProtection = true,
    AntiStun = true, SpinCharacter = true, HeadTiltOn = true, FpsBoost = true, FpsUnlocker = true
}

M.CFG.ApplyImportDataInner = function(data)
    if type(data) ~= "table" then return end
    M.F.BuildAllPages(true)      -- все элементы меню должны существовать, чтобы применить значения конфига (по странице за кадр)

    -- Переносим старые названия настроек на новые (копия, чтобы не менять сохранённый конфиг)
    local migrated = {}
    for k, v in pairs(data) do
        local newKey = M.CFG.LegacyKeys[k]
        if newKey ~= nil and data[newKey] == nil then
            migrated[newKey] = v
        else
            migrated[k] = v
        end
    end
    data = migrated

    -- Спокойный старт: функции движения и действий пропускаем (копия, чтобы не испортить сохранённый конфиг)
    if M.Data.StartupLoad and data.SafeStart ~= false then
        local copy = {}
        for k, v in pairs(data) do copy[k] = v end
        for key in pairs(M.CFG.ManualStartKeys) do
            if copy[key] == true then
                copy[key] = false
                table.insert(M.Data.SkippedAtStart, key)
            end
        end
        data = copy
    end

    -- Применяются только простые значения (строка, число, логическое) и цвет. Таблицы из файла в настройки не
    -- попадают: иначе файл мог бы подменить внутренние списки скрипта (окна, вкладки, подписки).
    for k, v in pairs(data) do
        if type(k) == "string" and M.State[k] ~= nil and not M.CFG.IsRuntimeKey(k) then
            local current = M.State[k]
            if type(v) == "table" then
                if v.__type == "Color3" and type(v.hex) == "string" and #v.hex <= 9 and typeof(current) == "Color3" then
                    -- fromHex бросает ошибку на неправильной строке, поэтому pcall
                    local ok, color = pcall(Color3.fromHex, v.hex)
                    if ok then M.State[k] = color end
                end
            elseif type(v) == type(current) and M.CFG.IsPlainData(v) then
                M.State[k] = v
            end
        end
    end
    if M.State.Language ~= "RU" and M.State.Language ~= "EN" then M.State.Language = "RU" end

    -- Значения из файла могли быть испорчены или изменены вручную: числа возвращаем в пределы ползунков
    for _, el in ipairs(M.Data.RegUI) do
        if el.Min and el.Max and el.Key and type(M.State[el.Key]) == "number" then
            local value = M.State[el.Key]
            if value ~= value then value = el.Min end                -- NaN
            M.State[el.Key] = math.clamp(value, el.Min, el.Max)
        end
    end

    -- Число из таблицы позиции: если там не число (файл испорчен), берём запасное значение
    local function safeNumber(tbl, key, low, high, fallback)
        local x = type(tbl) == "table" and tbl[key] or nil
        if type(x) == "number" and x == x then return math.clamp(x, low, high) end
        return fallback
    end
    if type(data["__PillPos"]) == "table" and M.UI.Pill then
        local p, old = data["__PillPos"], M.UI.Pill.Position
        M.UI.Pill.Position = UDim2.new(safeNumber(p, "XS", -2, 3, old.X.Scale), safeNumber(p, "XO", -5000, 5000, old.X.Offset),
            safeNumber(p, "YS", -2, 3, old.Y.Scale), safeNumber(p, "YO", -5000, 5000, old.Y.Offset))
    end
    if type(data["__MainPos"]) == "table" and M.UI.Main then
        local m, old = data["__MainPos"], M.UI.Main.Position
        M.UI.Main.Position = UDim2.new(safeNumber(m, "XS", -2, 3, old.X.Scale), safeNumber(m, "XO", -5000, 5000, old.X.Offset),
            safeNumber(m, "YS", -2, 3, old.Y.Scale), safeNumber(m, "YO", -5000, 5000, old.Y.Offset))
        M.F.SyncPreviewPos()
    end
    if type(data["__MainSize"]) == "table" and M.UI.Main then
        local ms, old = data["__MainSize"], M.UI.Main.Size
        M.UI.Main.Size = UDim2.new(0, safeNumber(ms, "X", 600, 960, old.X.Offset), 0, safeNumber(ms, "Y", 420, 760, old.Y.Offset))
        M.UI.PrevCard.Size = UDim2.new(0, 205, 0, M.UI.Main.Size.Y.Offset)
        M.F.SyncPreviewPos()
    end

    M.L10N.Current = M.State.Language or "RU"
    M.F.UpdateLanguageUI()

    for _, el in ipairs(M.Data.RegUI) do
        if el.Key and M.State[el.Key] ~= nil then
            if el.SetVisual then el.SetVisual(M.State[el.Key]) end
            if el.Callback then el.Callback(M.State[el.Key]) end
        end
    end

    M.F.StylePill()
    M.UI.PillScale.Scale = M.State.PillScaleVal
    M.UI.PillTxt.TextColor3 = M.State.PillTextCol

    if M.UI.MenuBg then
        M.UI.MenuBg.BackgroundColor3 = M.State.MainBg
        M.UI.MenuBg.BackgroundTransparency = M.State.MenuAlpha
    end
    M.UI.PrevCard.BackgroundColor3 = M.State.MainBg
    M.UI.PrevCard.BackgroundTransparency = M.State.MenuAlpha
    M.UI.Sidebar.BackgroundColor3 = M.State.SideBg
    M.UI.Sidebar.BackgroundTransparency = M.State.SideAlpha
    M.UI.MainStroke.Color = M.State.BorderCol
    M.UI.MainStroke.Thickness = M.State.BorderThick
    M.UI.PrevStroke.Color = M.State.BorderCol
    M.UI.PrevStroke.Thickness = M.State.BorderThick
    M.UI.SideStroke.Color = M.State.BorderCol
    M.UI.SideStroke.Thickness = M.State.BorderThick

    for _, c in ipairs(M.State.Cards) do
        c.BackgroundColor3 = M.State.CardBg
        c.BackgroundTransparency = M.State.CardAlpha
    end
    for _, sc in ipairs(M.State.SideCards) do
        sc.BackgroundColor3 = M.State.SideCardBg
        sc.BackgroundTransparency = M.State.SideCardAlpha
    end

    M.F.SetWallPass(M.State.WalkThroughWalls)
    M.F.ApplyDark()
    M.F.ApplyFog()
    M.F.ApplyClouds()
    M.ApplyFpsBoost(M.State.FpsBoost)
    M.ApplyFpsUnlocker(M.State.FpsUnlocker)
    M.F.UpdatePlayerView()
    M.UpdatePlayerVisuals()
    if M.State.OrbitOn then M.F.RebuildOrbits() end
    if M.State.HatOn then M.F.RebuildWireHat() end
    -- Если во вкладке из конфига нет такой страницы, открываем Combat, а не оставляем пустое меню
    if not M.State.Pages[M.State.ActiveTab] then M.State.ActiveTab = "Combat" end
    M.F.SwitchTab(M.State.ActiveTab)
end

-- Обёртка: флаг Importing нужен, чтобы колбэки (например, цвет тумана) не включали функции сами по себе
M.CFG.ApplyImportData = function(data)
    M.Data.Importing = true
    local ok, err = pcall(M.CFG.ApplyImportDataInner, data)
    M.Data.Importing = false
    if not ok then warn("[Matsysense] Ошибка загрузки конфига: " .. tostring(err)) end
end

-- Запись на диск. Обычный клиент Roblox и Studio НЕ дают скриптам доступ к файлам, поэтому используем функции
-- writefile / readfile / isfile, если окружение их предоставляет. Файл лежит в рабочей папке этого окружения и
-- переживает перезапуск игры и компьютера. Если функций нет, конфиги живут в памяти до закрытия игры.
M.CFG.FilePath = "Matsysense_Configs.json"
M.CFG.MaxFileBytes = 1000000     -- файл больше мегабайта считается испорченным: не читается и не пишется
M.CFG.MaxNameLength = 64

-- Данные из файла - это ЧУЖОЙ ввод (файл могли подменить или испортить), поэтому проверяем всё до применения.
-- Разрешены только строки, числа, логические значения и вложенные таблицы небольшой глубины и размера.
function M.CFG.IsPlainData(value, depth, budget)
    depth = depth or 0
    budget = budget or {Left = 5000}
    budget.Left = budget.Left - 1
    if budget.Left < 0 or depth > 4 then return false end
    local t = type(value)
    if t == "string" then return #value <= 500 end
    if t == "number" then return value == value and math.abs(value) < 1e9 end
    if t == "boolean" then return true end
    if t == "table" then
        for k, v in pairs(value) do
            if type(k) ~= "string" or #k > M.CFG.MaxNameLength then return false end
            if not M.CFG.IsPlainData(v, depth + 1, budget) then return false end
        end
        return true
    end
    return false
end

-- Оставляет из прочитанного файла только допустимые записи: имя-строка и либо конфиг-таблица, либо имя автозагрузки
function M.CFG.SanitizeStorage(parsed)
    local clean = {}
    if type(parsed) ~= "table" then return clean end
    for name, value in pairs(parsed) do
        if type(name) == "string" and #name > 0 and #name <= M.CFG.MaxNameLength then
            if name == "__AUTOLOAD" then
                if type(value) == "string" and #value <= M.CFG.MaxNameLength then clean[name] = value end
            elseif type(value) == "table" and M.CFG.IsPlainData(value) then
                clean[name] = value
            end
        end
    end
    return clean
end
M.CFG.BackupPath = "Matsysense_Configs_backup.json"

function M.CFG.DiskAvailable()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

-- Сохраняет все конфиги в файл. Перед записью предыдущая версия копируется в резервный файл:
-- если запись оборвётся, конфиги не потеряются. Возвращает true, если запись удалась.
function M.CFG.FlushToFile()
    if not M.CFG.DiskAvailable() then return false end
    local ok = pcall(function()
        local raw = M.Services.H:JSONEncode(M.Data.MemStorage)
        if #raw > M.CFG.MaxFileBytes then error("файл конфигов слишком большой") end
        if isfile(M.CFG.FilePath) then
            local old = readfile(M.CFG.FilePath)
            if type(old) == "string" and #old > 2 then writefile(M.CFG.BackupPath, old) end
        end
        writefile(M.CFG.FilePath, raw)
    end)
    return ok
end

-- Читает конфиги из файла (если основной повреждён, берёт резервный). Возвращает true, если что-то прочитано.
function M.CFG.LoadFromFile()
    if not M.CFG.DiskAvailable() then return false end
    for _, path in ipairs({M.CFG.FilePath, M.CFG.BackupPath}) do
        local ok, parsed = pcall(function()
            if not isfile(path) then return nil end
            local raw = readfile(path)
            if type(raw) ~= "string" or #raw > M.CFG.MaxFileBytes then return nil end
            return M.Services.H:JSONDecode(raw)
        end)
        if ok and type(parsed) == "table" then
            M.Data.MemStorage = M.CFG.SanitizeStorage(parsed)
            return true
        end
    end
    return false
end

-- Сохраняет конфиг. Возвращает: успех, записано ли на диск
M.CFG.Save = function(name)
    name = (name and name ~= "") and name or "default"
    M.Data.MemStorage[name] = M.CFG.GetExportData()
    return true, M.CFG.FlushToFile()
end

M.CFG.Load = function(name)
    name = (name and name ~= "") and name or "default"
    M.CFG.LoadFromFile()
    local data = M.Data.MemStorage[name]
    if data then
        M.CFG.ApplyImportData(data)
        return true
    end
    return false
end

M.CFG.Delete = function(name)
    name = (name and name ~= "") and name or "default"
    if M.Data.MemStorage[name] then
        M.Data.MemStorage[name] = nil
        M.CFG.FlushToFile()
        return true
    end
    return false
end

M.CFG.SetAutoload = function(name)
    M.Data.MemStorage["__AUTOLOAD"] = name or "default"
    return M.CFG.FlushToFile()
end

M.CFG.CheckAutoload = function()
    M.CFG.LoadFromFile()
    local auto = M.Data.MemStorage["__AUTOLOAD"]
    if auto and auto ~= "" then
        M.Data.StartupLoad = true
        M.Data.SkippedAtStart = {}
        M.CFG.Load(auto)
        M.Data.StartupLoad = false
        M.State.SelectedCfg = auto
        local skipped = #M.Data.SkippedAtStart
        if skipped > 0 then
            M.F.Notify("SafeStart", string.format(M.Translate("SafeStartSkipped"), skipped), false, true)
        end
    end
end

M.CFG.List = function()
    M.CFG.LoadFromFile()
    local cfgs = {}
    for k in pairs(M.Data.MemStorage) do
        if k ~= "__AUTOLOAD" then
            table.insert(cfgs, k)
        end
    end
    table.sort(cfgs)
    if #cfgs == 0 then table.insert(cfgs, "default") end
    return cfgs
end

-- ==============================================================================
-- [ INTERFACE PAGES CONSTRUCTOR ]
-- ==============================================================================
M.F.MakeTabBtn("Tab_Combat", 1)
M.F.MakeTabBtn("Tab_Movement", 2)
M.F.MakeTabBtn("Tab_Camera", 3)
M.F.MakeTabBtn("Tab_Display", 4)
M.F.MakeTabBtn("Tab_World", 5)
M.F.MakeTabBtn("Tab_Player", 6)
M.F.MakeTabBtn("Tab_Misc", 7)
M.F.MakeTabBtn("Tab_System", 8)
M.F.MakeTabBtn("Tab_Configs", 9)
M.F.MakeTabBtn("Tab_Settings", 10)

local pCombat = M.F.CreatePage("Combat")
local pExp = M.F.CreatePage("Movement")
local pCam = M.F.CreatePage("Camera")
local pDisplay = M.F.CreatePage("Display")
local pWrld = M.F.CreatePage("World")
local pPlyr = M.F.CreatePage("Player")
local pMisc = M.F.CreatePage("Misc")
local pSys = M.F.CreatePage("System")
local pCfg = M.F.CreatePage("Configs")
local pSet = M.F.CreatePage("Settings")

M.Data.PageBuilders.Combat = function()
-- Combat
M.F.MakeSection(pCombat, "Sec_AimAssist", 1)
M.F.MakeToggle(pCombat, "AimAssist", "AimAssist", 2, function() end, true)
M.F.MakeToggle(pCombat, "AimTeamCheck", "AimTeamCheck", 3, function() end, false)
M.F.MakeDropdown(pCombat, "AimPart", {"Head", "Body"}, "AimPart", 4, function() M.Data.AimLock = nil end)
M.F.MakeSlider(pCombat, "AimFov", "AimFov", 10, 800, "px", 5, function() end)
M.F.MakeToggle(pCombat, "ShowFov", "ShowFov", 6, function() end, false)
M.F.MakeSlider(pCombat, "AimTime", "AimTime", 0, 1000, "мс", 7, function() end)
M.F.MakeToggle(pCombat, "AimWallCheck", "AimWallCheck", 8, function() end, false)

M.F.MakeSection(pCombat, "Sec_TriggerAssist", 9)
M.F.MakeToggle(pCombat, "TriggerAssist", "TriggerAssist", 10, function() end, true)
M.F.MakeDropdown(pCombat, "TriggerMethod", {"Click", "Tool"}, "TriggerMethod", 11, function() end)
M.F.MakeToggle(pCombat, "TriggerTeamCheck", "TriggerTeamCheck", 12, function() end, false)
M.F.MakeToggle(pCombat, "TriggerLoop", "TriggerLoop", 13, function() end, false)
M.F.MakeSlider(pCombat, "TriggerDelay", "TriggerDelay", 0.0, 0.5, "с", 14, function() end)
M.F.MakeToggle(pCombat, "TriggerWallCheck", "TriggerWallCheck", 15, function() end, false)
end

M.Data.PageBuilders.Movement = function()
-- Movement
M.F.MakeSection(pExp, "Sec_Movement", 1)
M.F.MakeSpeedCard(pExp, "FlightMode", "FlightSpeed", true, 2, function() end, function(v) M.State.FlightSpeed = v end)
M.F.MakeToggle(pExp, "KnockbackProtection", "KnockbackProtection", 3, function() end, false)
M.F.MakeSpeedCard(pExp, "SprintBoost", "SprintSpeed", false, 4, function() end, function(v) M.State.SprintSpeed = v end)
M.F.MakeToggle(pExp, "AirControl", "AirControl", 5, function() end, true)
M.F.MakeSlider(pExp, "AirSpeed", "AirSpeed", 50, 400, "", 6, function() end)
M.F.MakeSlider(pExp, "AirAccel", "AirAccel", 1, 20, "", 7, function() end)
M.F.MakeToggle(pExp, "InfiniteJumps", "InfiniteJumps", 8, function() end, true)
M.F.MakeToggle(pExp, "AutoJump", "AutoJump", 9, function() end, true)

M.F.MakeSection(pExp, "Sec_Defense", 10)
M.F.MakeToggle(pExp, "WalkThroughWalls", "WalkThroughWalls", 11, M.F.SetWallPass, true)
M.F.MakeToggle(pExp, "FallProtection", "FallProtection", 12, function() end, true)
M.F.MakeToggle(pExp, "AntiStun", "AntiStun", 13, function() end, true)
M.F.MakeToggle(pExp, "IdleProtection", "IdleProtection", 14, function(on) M.F.SetIdleProtection(on) end, true)
end

M.Data.PageBuilders.Camera = function()
-- Camera
do
    local order = 0
    local function nextOrder() order = order + 1 return order end

    M.F.MakeSection(pCam, "Sec_CameraMain", nextOrder())
    M.F.MakeToggle(pCam, "FovOn", "FovOn", nextOrder(), function() end, true)
    M.F.MakeSlider(pCam, "CamFov", "CamFov", 30, 120, "°", nextOrder(), function(v)
        M.State.CamFov = v
        -- Двигаете ползунок: значит хотите свой FOV. Включаем его сами (кроме загрузки конфига)
        if not M.Data.Importing and not M.State.FovOn then
            M.F.SetStateVisual("FovOn", true)
        end
    end)
    M.F.MakeToggle(pCam, "ThirdPerson", "ThirdPerson", nextOrder(), function() end, true)
    M.F.MakeSlider(pCam, "ThirdPersonDist", "ThirdPersonDist", 5, 30, "м", nextOrder(), function() end)

    M.F.MakeSection(pCam, "Sec_Zoom", nextOrder())
    M.F.MakeToggle(pCam, "ZoomOn", "ZoomOn", nextOrder(), function() end, true)
    M.F.MakeSlider(pCam, "ZoomFov", "ZoomFov", 10, 70, "°", nextOrder(), function() end)
    M.F.MakeSlider(pCam, "ZoomSpeed", "ZoomSpeed", 2, 30, "", nextOrder(), function() end)


    M.F.MakeSection(pCam, "Sec_Cinema", nextOrder())
    M.F.MakeToggle(pCam, "BloomOn", "BloomOn", nextOrder(), function() M.F.ApplyBloom() end, true)
    M.F.MakeSlider(pCam, "BloomIntensity", "BloomIntensity", 0, 2, "", nextOrder(), function() M.F.ApplyBloom() end)
    M.F.MakeSlider(pCam, "BloomSize", "BloomSize", 0, 56, "", nextOrder(), function() M.F.ApplyBloom() end)
    M.F.MakeSlider(pCam, "BloomThreshold", "BloomThreshold", 0, 3, "", nextOrder(), function() M.F.ApplyBloom() end)

    M.F.MakeSection(pCam, "Sec_Grade", nextOrder())
    M.F.MakeToggle(pCam, "GradeOn", "GradeOn", nextOrder(), function() M.F.ApplyGrade() end, true)
    M.F.MakeDropdown(pCam, "GradePreset", {"Custom", "Cinematic", "Warm", "Cold", "Vivid", "Noir"}, "GradePreset", nextOrder(), function(name)
        -- При загрузке конфига готовый стиль не должен затирать сохранённые значения ползунков
        if not M.Data.Importing then M.F.ApplyGradePreset(name) end
    end)
    local function onGradeSlider()
        if not M.Data.Importing and M.State.GradePreset ~= "Custom" then M.F.SetStateVisual("GradePreset", "Custom") end
        M.F.ApplyGrade()
    end
    M.F.MakeSlider(pCam, "GradeSat", "GradeSat", -1, 2, "", nextOrder(), onGradeSlider)
    M.F.MakeSlider(pCam, "GradeContrast", "GradeContrast", -0.5, 0.8, "", nextOrder(), onGradeSlider)
    M.F.MakeSlider(pCam, "GradeBright", "GradeBright", -0.3, 0.3, "", nextOrder(), onGradeSlider)
    M.F.MakePicker(pCam, "GradeTint", "GradeTint", nextOrder(), onGradeSlider)

    M.F.MakeSection(pCam, "Sec_Hits", nextOrder())
    M.F.MakeToggle(pCam, "ShakeOn", "ShakeOn", nextOrder(), function() end, true)
    M.F.MakeSlider(pCam, "ShakeStrength", "ShakeStrength", 0.1, 1, "", nextOrder(), function() end)
    M.F.MakeToggle(pCam, "HitFlashOn", "HitFlashOn", nextOrder(), function() end, false)
    M.F.MakeToggle(pCam, "LowHpOn", "LowHpOn", nextOrder(), function() end, false)
    M.F.MakeToggle(pCam, "HitMarkerOn", "HitMarkerOn", nextOrder(), function() end, true)
end
end

M.Data.PageBuilders.Display = function()
-- Отображение игроков
M.F.MakeSection(pDisplay, "Sec_PlayerViewBase", 1)
M.F.MakeToggle(pDisplay, "EnablePlayerView", "PlayerView", 2, function() M.F.UpdatePlayerView() end, false)
M.F.MakeToggle(pDisplay, "PlayerViewOnSelf", "PlayerViewOnSelf", 3, function() M.F.UpdatePlayerView() end, false)
M.F.MakeToggle(pDisplay, "PlayerViewTeamCheck", "PlayerViewTeamCheck", 4, function() M.F.UpdatePlayerView() end, false)
M.F.MakePicker(pDisplay, "FillCol", "PlayerViewFill", 5, function() M.F.UpdatePlayerView() end)
M.F.MakePicker(pDisplay, "LineCol", "PlayerViewLine", 6, function() M.F.UpdatePlayerView() end)

M.F.MakeSection(pDisplay, "Sec_PlayerViewBoxes", 7)
M.F.MakeToggle(pDisplay, "PlayerViewBox", "PlayerViewBox", 8, function() M.F.UpdatePlayerView() end, false)
M.F.MakePicker(pDisplay, "BoxCol", "PlayerViewBoxCol", 9, function() M.F.UpdatePlayerView() end)
M.F.MakeSlider(pDisplay, "BoxThick", "PlayerViewBoxThick", 1.0, 5.0, "px", 10, function() M.F.UpdatePlayerView() end)
M.F.MakeDropdown(pDisplay, "FontWeight", {"Bold", "Medium"}, "PlayerViewFontWeight", 11, function() M.F.UpdatePlayerView() end)
M.F.MakeSlider(pDisplay, "TextSize", "PlayerViewTextSize", 9, 20, "px", 12, function() M.F.UpdatePlayerView() end)
M.F.MakePicker(pDisplay, "NameCol", "PlayerViewNameCol", 13, function() M.F.UpdatePlayerView() end)

M.F.MakeSection(pDisplay, "Sec_PlayerViewHealth", 14)
M.F.MakeToggle(pDisplay, "ShowHp", "PlayerViewHealthBar", 15, function() M.F.UpdatePlayerView() end, false)
M.F.MakeDropdown(pDisplay, "HpPos", {"Left", "Right", "Bottom"}, "PlayerViewHealthPos", 16, function() M.F.UpdatePlayerView() end)
M.F.MakeSlider(pDisplay, "HpThick", "PlayerViewHealthBarThick", 2, 10, "px", 17, function() M.F.UpdatePlayerView() end)
M.F.MakeToggle(pDisplay, "HpText", "PlayerViewHealthText", 18, function() M.F.UpdatePlayerView() end, false)
M.F.MakePicker(pDisplay, "HpCol", "PlayerViewHealthCol", 19, function() M.F.UpdatePlayerView() end)

M.F.MakeSection(pDisplay, "Sec_PlayerViewLines", 20)
M.F.MakeToggle(pDisplay, "PlayerViewLines", "PlayerViewLines", 21, function() M.F.UpdatePlayerView() end, false)
M.F.MakePicker(pDisplay, "PlayerLineCol", "PlayerLineCol", 22, function() M.F.UpdatePlayerView() end)

M.F.MakeSection(pDisplay, "Sec_PlayerViewExtra", 23)
M.F.MakeToggle(pDisplay, "DamageNumbers", "DamageNumbers", 24, function() end, true)
M.F.MakeToggle(pDisplay, "PlayerViewDistance", "PlayerViewDistance", 25, function() end, false)
M.F.MakeToggle(pDisplay, "PlayerViewHealthColor", "PlayerViewHealthColor", 26, function() M.F.UpdatePlayerView() end, false)
end

M.Data.PageBuilders.World = function()
-- World
do
    local order = 0
    local function nextOrder() order = order + 1 return order end

    -- Туман
    M.F.MakeSection(pWrld, "Sec_WorldFog", nextOrder())
    M.F.MakeToggle(pWrld, "WhiteFog", "FogOn", nextOrder(), function() M.F.ApplyFog() end, false)
    M.F.MakeSlider(pWrld, "FogDense", "FogDensity", 0.1, 1.0, "", nextOrder(), function() M.F.ApplyFog() end)
    M.F.MakeSlider(pWrld, "FogHaze", "FogHaze", 0.0, 6.0, "", nextOrder(), function() M.F.ApplyFog() end)
    M.F.MakePicker(pWrld, "FogCol", "FogColor", nextOrder(), function(c)
        M.State.FogColor = c
        if not M.Data.Importing and not M.State.FogOn then
            M.F.SetStateVisual("FogOn", true)
        end
        M.F.ApplyFog()
    end)

    -- Время суток
    M.F.MakeSection(pWrld, "Sec_WorldTime", nextOrder())
    M.F.MakeToggle(pWrld, "TimeOfDay", "TimeOn", nextOrder(), function(on)
        M.Services.L.ClockTime = on and M.State.CustomTime or M.State.OrigTime
    end, false)
    M.F.MakeSlider(pWrld, "ClockTime", "CustomTime", 0, 24, "", nextOrder(), function(v)
        if M.State.TimeOn then M.Services.L.ClockTime = v end
    end)
    M.F.MakeToggle(pWrld, "TimeCycle", "TimeCycle", nextOrder(), function(on)
        if on and not M.Data.Importing then
            -- Цикл продолжается с текущего времени игры, без скачка
            local now = math.floor(M.Services.L.ClockTime * 100) / 100
            M.F.SetStateVisual("CustomTime", now)
            if not M.State.TimeOn then M.F.SetStateVisual("TimeOn", true) end
        end
    end, true)
    M.F.MakeSlider(pWrld, "TimeCycleSpeed", "TimeCycleSpeed", 1, 240, "", nextOrder(), function() end)
    M.F.MakeToggle(pWrld, "TimeSyncReal", "TimeSyncReal", nextOrder(), function(on)
        if on and not M.Data.Importing then
            -- Реальное время и цикл исключают друг друга
            M.F.SetStateVisual("TimeCycle", false)
            if not M.State.TimeOn then M.F.SetStateVisual("TimeOn", true) end
            M.F.SyncRealTime()
        end
    end, true)

    -- Освещение
    M.F.MakeSection(pWrld, "Sec_WorldLight", nextOrder())
    M.F.MakeToggle(pWrld, "DarkWorld", "DarkWorld", nextOrder(), function() M.F.ApplyDark() end, false)
    M.F.MakeSlider(pWrld, "DarkIntense", "DarkIntensity", 0.05, 1, "", nextOrder(), function() M.F.ApplyDark() end)

    -- Свой скайбокс
    M.F.MakeSection(pWrld, "Sec_WorldSky", nextOrder())
    M.F.MakeToggle(pWrld, "SkyOn", "SkyOn", nextOrder(), function() M.F.ApplySky() end, false)
    M.F.MakeTextInput(pWrld, "SkyIds", "SkyIds", "SkyPlaceholder", nextOrder(), function() M.F.ApplySky() end)
    -- Готовые скайбоксы из магазина (названия проверены по страницам Creator Store). Любой другой ID можно вписать выше.
    M.F.MakePresetRow(pWrld, nextOrder(), {
        {Key = "SkyPreset1", Id = "132703927222924"},
        {Key = "SkyPreset2", Id = "15502592084"},
        {Key = "SkyPreset3", Id = "911025794"},
        {Key = "SkyPreset4", Id = "741300412"}
    }, function(id) M.F.PickSkyPreset(id) end)
    M.F.MakePresetRow(pWrld, nextOrder(), {
        {Key = "SkyPreset5", Id = "339406852"},
        {Key = "SkyPreset6", Id = "32584709"},
        {Key = "SkyPreset7", Id = "175933054"},
        {Key = "SkyPreset8", Id = "default"}
    }, function(id) M.F.PickSkyPreset(id) end)

    local skyStatusCard = M.F.MakeCard(pWrld, 40)
    skyStatusCard.LayoutOrder = nextOrder()
    M.UI.SkyStatusLabel = Instance.new("TextLabel")
    M.UI.SkyStatusLabel.Size = UDim2.new(1, -24, 1, 0)
    M.UI.SkyStatusLabel.Position = UDim2.new(0, 12, 0, 0)
    M.UI.SkyStatusLabel.BackgroundTransparency = 1
    M.UI.SkyStatusLabel.TextWrapped = true
    M.UI.SkyStatusLabel.Font = Enum.Font.GothamMedium
    M.UI.SkyStatusLabel.TextSize = 11
    M.UI.SkyStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    M.UI.SkyStatusLabel.Parent = skyStatusCard
    table.insert(M.Data.RegUI, {SetLanguage = M.F.RenderSkyStatus})
    if M.Data.SkyStatus then M.F.RenderSkyStatus() else M.F.SetSkyStatus("Sky_Idle", nil, "idle") end

    M.F.MakeToggle(pWrld, "SkyHideBodies", "SkyHideBodies", nextOrder(), function() M.F.ApplySky(true) end, false)

    -- Лучи света
    M.F.MakeSection(pWrld, "Sec_WorldRays", nextOrder())
    M.F.MakeToggle(pWrld, "SunRaysOn", "SunRaysOn", nextOrder(), function() M.F.ApplySunRays() end, true)
    M.F.MakeSlider(pWrld, "SunRaysIntensity", "SunRaysIntensity", 0, 1, "", nextOrder(), function() M.F.ApplySunRays() end)
    M.F.MakeSlider(pWrld, "SunRaysSpread", "SunRaysSpread", 0, 1, "", nextOrder(), function() M.F.ApplySunRays() end)
    M.F.MakeSlider(pWrld, "SunRaysBright", "SunRaysBright", 0, 1, "", nextOrder(), function() M.F.ApplySunRays() end)


    -- Облака
    M.F.MakeSection(pWrld, "Sec_WorldClouds", nextOrder())
    M.F.MakeToggle(pWrld, "CloudsOn", "CloudsOn", nextOrder(), function() M.F.ApplyClouds() end, false)
    M.F.MakeSlider(pWrld, "CloudDensity", "CloudDensity", 0.01, 1.0, "", nextOrder(), function() M.F.ApplyClouds() end)
    M.F.MakeSlider(pWrld, "CloudCover", "CloudCover", 0, 100, "%", nextOrder(), function() M.F.ApplyClouds() end)
    M.F.MakePicker(pWrld, "CloudColor", "CloudColor", nextOrder(), function(c)
        M.State.CloudColor = c
        -- Раньше цвет менялся, но облака были выключены, и результата не было видно
        if not M.Data.Importing and not M.State.CloudsOn then
            M.F.SetStateVisual("CloudsOn", true)
        end
        M.F.ApplyClouds()
    end)

    -- Погода
    M.F.MakeSection(pWrld, "Sec_WorldWeather", nextOrder())
    M.F.MakeToggle(pWrld, "PropWeather", "WeatherOn", nextOrder(), function(on) if not on then M.F.ClearWeatherProps() end end, false)
    M.F.MakeDropdown(pWrld, "WeatherMode", {"Rain", "Snow"}, "WeatherMode", nextOrder(), function() M.F.ClearWeatherProps() end)
    M.F.MakeSlider(pWrld, "WeatherDense", "WeatherDensity", 10, 100, "", nextOrder(), function() end)
    M.F.MakeSlider(pWrld, "WeatherSpeed", "WeatherSpeed", 10, 140, "", nextOrder(), function() end)
    M.F.MakeSlider(pWrld, "WeatherRadius", "WeatherRadius", 20, 220, "studs", nextOrder(), function() end)
    M.F.MakeSlider(pWrld, "SnowSize", "SnowSize", 0.2, 2.5, "studs", nextOrder(), function() end)
    M.F.MakePicker(pWrld, "WeatherCol", "WeatherColor", nextOrder(), function() end)


    -- Молнии и метеориты
    M.F.MakeSection(pWrld, "Sec_WorldEffects", nextOrder())
    M.F.MakeToggle(pWrld, "Lightning", "LightningOn", nextOrder(), function() end, false)
    M.F.MakeSlider(pWrld, "LightRate", "LightningRate", 1, 10, "x", nextOrder(), function() end)
    M.F.MakeSlider(pWrld, "LightSize", "LightningSize", 0.2, 2.5, "studs", nextOrder(), function() end)
    M.F.MakeSlider(pWrld, "LightDur", "LightningDuration", 0.1, 3.0, "с", nextOrder(), function() end)
    M.F.MakeToggle(pWrld, "LightningFlash", "LightningFlash", nextOrder(), function() end, false)
    M.F.MakeSlider(pWrld, "LightningFlashPower", "LightningFlashPower", 0.05, 1, "", nextOrder(), function() end)
    M.F.MakeToggle(pWrld, "Meteors", "MeteorOn", nextOrder(), function() end, false)
    M.F.MakeSlider(pWrld, "MetRate", "MeteorRate", 1, 10, "x", nextOrder(), function() end)
    M.F.MakeSlider(pWrld, "MetSize", "MeteorSize", 1, 8, "studs", nextOrder(), function() end)
    M.F.MakeSlider(pWrld, "MetTail", "MeteorTrailLen", 0.3, 3.5, "с", nextOrder(), function() end)
    M.F.MakeSlider(pWrld, "MetDur", "MeteorDuration", 0.5, 5.0, "с", nextOrder(), function() end)
    M.F.MakeToggle(pWrld, "MeteorImpact", "MeteorImpact", nextOrder(), function() end, false)
    M.F.MakePicker(pWrld, "MetCol", "MeteorColor", nextOrder(), function() end)
end
end

M.Data.PageBuilders.Player = function()
-- Player
M.F.MakeSection(pPlyr, "Sec_PlyrModel", 1)
M.F.MakeToggle(pPlyr, "HideHats", "HideHats", 2, function() M.UpdatePlayerVisuals() end, false)
M.F.MakeToggle(pPlyr, "HoloSelf", "HoloSelf", 3, function() M.UpdatePlayerVisuals() end, false)
M.F.MakeSlider(pPlyr, "HoloAlpha", "HoloAlpha", 0.0, 1.0, "", 4, function() M.UpdatePlayerVisuals() end)
M.F.MakePicker(pPlyr, "HoloCol", "HoloColor", 5, function() M.UpdatePlayerVisuals() end)

M.F.MakeSection(pPlyr, "Sec_PlyrJump", 6)
M.F.MakeToggle(pPlyr, "JumpRings", "JumpRings", 7, function() end, false)
M.F.MakeDropdown(pPlyr, "JumpRingType", {"Both", "Outline", "Filled"}, "JumpRingType", 8, function() end)
M.F.MakePicker(pPlyr, "JumpRingFillCol", "JumpRingFillCol", 9, function() end)
M.F.MakePicker(pPlyr, "JumpRingOutCol", "JumpRingOutCol", 10, function() end)
M.F.MakeSlider(pPlyr, "JumpRingGlow", "JumpRingGlow", 1.0, 5.0, "x", 11, function() end)
M.F.MakeSlider(pPlyr, "JumpRingSize", "JumpRingSize", 4, 30, "studs", 12, function() end)
M.F.MakeSlider(pPlyr, "JumpRingSpeed", "JumpRingSpeed", 0.3, 2.5, "с", 13, function() end)

M.F.MakeSection(pPlyr, "Sec_PlyrAccessories", 14)
M.F.MakeToggle(pPlyr, "Orbits", "OrbitOn", 15, function() M.F.RebuildOrbits() end, false)
M.F.MakeSlider(pPlyr, "OrbitCount", "OrbitCount", 1, 8, "", 16, function() M.F.Debounce("orbits", 0.15, M.F.RebuildOrbits) end)
M.F.MakeSlider(pPlyr, "OrbitRadius", "OrbitRadius", 3, 16, "studs", 17, function() end)
M.F.MakeSlider(pPlyr, "OrbitSpeed", "OrbitSpeed", 0.5, 8, "x", 18, function() end)
M.F.MakeSlider(pPlyr, "OrbitSize", "OrbitSize", 0.3, 3, "studs", 19, function(v) M.State.OrbitSize = v; M.F.UpdateOrbitsVisualLive() end)
M.F.MakeSlider(pPlyr, "OrbitTrailThick", "OrbitTrailThick", 0.1, 1.2, "", 20, function(v) M.State.OrbitTrailThick = v; M.F.UpdateOrbitsVisualLive() end)
M.F.MakeSlider(pPlyr, "OrbitTrailLen", "OrbitTrailLen", 0.2, 2.5, "с", 21, function(v) M.State.OrbitTrailLen = v; M.F.UpdateOrbitsVisualLive() end)
M.F.MakePicker(pPlyr, "OrbitCol", "OrbitColor", 22, function() M.F.UpdateOrbitsVisualLive() end)
M.F.MakePicker(pPlyr, "OrbitTrailCol", "OrbitTrailColor", 23, function() M.F.UpdateOrbitsVisualLive() end)
M.F.MakeToggle(pPlyr, "WireHat", "HatOn", 24, function() M.F.RebuildWireHat() end, false)
M.F.MakeSlider(pPlyr, "HatSize", "HatSize", 0.6, 2.4, "x", 25, function() M.F.Debounce("hat", 0.15, M.F.RebuildWireHat) end)
M.F.MakeSlider(pPlyr, "HatHeight", "HatHeight", 0.2, 2.0, "studs", 26, function() M.F.Debounce("hat", 0.15, M.F.RebuildWireHat) end)
M.F.MakePicker(pPlyr, "HatCol", "HatColor", 27, function() M.F.Debounce("hat", 0.15, M.F.RebuildWireHat) end)
end

M.Data.PageBuilders.Misc = function()
-- Misc
M.F.MakeSection(pMisc, "Sec_SilhouetteMod", 1)
M.F.MakeToggle(pMisc, "PitchMod", "HeadTiltOn", 2, function() end, false)
M.F.MakeSlider(pMisc, "PitchAngle", "PitchAngle", -90, 90, "°", 3, function() end)
M.F.MakeToggle(pMisc, "SpinCharacter", "SpinCharacter", 4, function() end, true)
M.F.MakeSlider(pMisc, "YawSpeed", "YawSpeed", 5, 100, "", 6, function() end)
M.F.MakeToggle(pMisc, "JerkySpin", "JerkySpin", 7, function() end, false)


M.F.MakeSection(pMisc, "Sec_Observe", 17)
M.F.MakeToggle(pMisc, "SpectateOn", "SpectateOn", 18, function(on)
    if on and not M.Data.SpectateTarget then M.F.SpectateStep(1) end
end, true)
M.F.MakePresetRow(pMisc, 19, {{Key = "<", Id = -1}, {Key = ">", Id = 1}}, function(direction)
    M.F.SpectateStep(direction)
end)
do
    local spectateCard = M.F.MakeCard(pMisc, 36)
    spectateCard.LayoutOrder = 20
    M.UI.SpectateLabel = Instance.new("TextLabel")
    M.UI.SpectateLabel.Size = UDim2.new(1, -24, 1, 0)
    M.UI.SpectateLabel.Position = UDim2.new(0, 12, 0, 0)
    M.UI.SpectateLabel.BackgroundTransparency = 1
    M.UI.SpectateLabel.Font = Enum.Font.GothamMedium
    M.UI.SpectateLabel.TextSize = 12
    M.UI.SpectateLabel.TextColor3 = Color3.fromRGB(190, 200, 220)
    M.UI.SpectateLabel.TextXAlignment = Enum.TextXAlignment.Left
    M.UI.SpectateLabel.Parent = spectateCard
    table.insert(M.Data.RegUI, {SetLanguage = M.F.RenderSpectateLabel})
    M.F.RenderSpectateLabel()
end
end

M.Data.PageBuilders.System = function()
-- System
M.F.MakeSection(pSys, "Sec_Performance", 1)
M.F.MakeToggle(pSys, "FpsBoost", "FpsBoost", 2, function(v) M.ApplyFpsBoost(v) end, true)

M.F.MakeSection(pSys, "Sec_Framerate", 3)
M.F.MakeToggle(pSys, "FpsUnlocker", "FpsUnlocker", 4, function(v) M.ApplyFpsUnlocker(v) end, true)
end

M.Data.PageBuilders.Configs = function()
-- Configs UI
local cfgInputCard = M.F.MakeCard(pCfg, 42); cfgInputCard.LayoutOrder = 1
local cfgInput = Instance.new("TextBox", cfgInputCard)
cfgInput.Size = UDim2.new(0.65, 0, 0, 26); cfgInput.Position = UDim2.new(0, 10, 0.5, -13)
cfgInput.BackgroundColor3 = Color3.fromRGB(15, 17, 24); cfgInput.Text = "default"; cfgInput.TextColor3 = Color3.fromRGB(240, 245, 255)
cfgInput.Font = Enum.Font.GothamBold; cfgInput.TextSize = 12; cfgInput.BorderSizePixel = 0
Instance.new("UICorner", cfgInput).CornerRadius = UDim.new(0, 6)

local cfgStatusCard = M.F.MakeCard(pCfg, 28); cfgStatusCard.LayoutOrder = 2
local cfgStatus = Instance.new("TextLabel", cfgStatusCard)
cfgStatus.Size = UDim2.new(1, 0, 1, 0); cfgStatus.BackgroundTransparency = 1
cfgStatus.TextColor3 = M.State.Accent; cfgStatus.Font = Enum.Font.GothamBold; cfgStatus.TextSize = 11

-- Строка состояния хранит ключ перевода и аргумент, поэтому при смене языка пересобирается на новом языке
local cfgStatusState = {}
local function setCfgStatus(key, arg)
    cfgStatusState.Key, cfgStatusState.Arg = key, arg
    local text = M.Translate(key)
    if arg ~= nil then text = string.format(text, arg) end
    cfgStatus.Text = text
end
if M.CFG.DiskAvailable() then setCfgStatus("Cfg_StorageDisk", M.CFG.FilePath) else setCfgStatus("Cfg_StorageMem") end

local btnRow = M.F.MakeCard(pCfg, 38); btnRow.LayoutOrder = 3
local function makeCfgBtn(textKey, posScale, widthScale, cb)
    local b = Instance.new("TextButton", btnRow)
    b.Size = UDim2.new(widthScale, 0, 0, 26); b.Position = UDim2.new(posScale, 0, 0.5, -13)
    b.BackgroundColor3 = Color3.fromRGB(28, 32, 44); b.Text = M.Translate(textKey); b.TextColor3 = Color3.fromRGB(240, 245, 255)
    b.Font = Enum.Font.GothamBold; b.TextSize = 11; Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(cb)
    table.insert(M.Data.RegUI, {SetLanguage = function() b.Text = M.Translate(textKey) end})
    return b
end

local cfgListContainer = M.F.MakeCard(pCfg, 150); cfgListContainer.LayoutOrder = 4
local cfgListScroll = Instance.new("ScrollingFrame", cfgListContainer)
cfgListScroll.Size = UDim2.new(1, -16, 1, -12); cfgListScroll.Position = UDim2.new(0, 8, 0, 6); cfgListScroll.BackgroundTransparency = 1
cfgListScroll.ScrollBarThickness = 6
cfgListScroll.ScrollBarImageColor3 = Color3.fromRGB(130, 145, 175)
cfgListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local clLayout = Instance.new("UIListLayout", cfgListScroll); clLayout.Padding = UDim.new(0, 4)

local function refreshCfgListUI()
    for _, ch in ipairs(cfgListScroll:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
    local list = M.CFG.List()
    local autoName = M.Data.MemStorage["__AUTOLOAD"]

    for _, name in ipairs(list) do
        local b = Instance.new("TextButton", cfgListScroll)
        b.Size = UDim2.new(1, -8, 0, 24); b.BackgroundColor3 = (name == M.State.SelectedCfg) and M.State.SideCardBg or Color3.fromRGB(18, 21, 28)
        local isAuto = (autoName == name)
        b.Text = "  " .. name .. (isAuto and M.Translate("Cfg_AutoTag") or "")
        b.TextColor3 = (name == M.State.SelectedCfg) and M.State.Accent or Color3.fromRGB(180, 195, 215)
        b.Font = Enum.Font.GothamMedium; b.TextSize = 11; b.TextXAlignment = Enum.TextXAlignment.Left
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function()
            M.State.SelectedCfg = name
            cfgInput.Text = name
            refreshCfgListUI()
        end)
    end
end

makeCfgBtn("Cfg_BtnSave", 0.01, 0.23, function()
    local name = cfgInput.Text:gsub("%s+", "")
    local saved, onDisk = M.CFG.Save(name)
    if saved then
        M.State.SelectedCfg = name
        setCfgStatus(onDisk and "Cfg_SavedDisk" or "Cfg_SavedMem", name)
        refreshCfgListUI()
    end
end)

makeCfgBtn("Cfg_BtnLoad", 0.26, 0.23, function()
    local name = cfgInput.Text:gsub("%s+", "")
    if M.CFG.Load(name) then
        setCfgStatus("Cfg_Loaded", name)
    else
        setCfgStatus("Cfg_NotFound")
    end
end)

makeCfgBtn("Cfg_BtnAuto", 0.51, 0.23, function()
    local name = cfgInput.Text:gsub("%s+", "")
    local onDisk = M.CFG.SetAutoload(name)
    setCfgStatus(onDisk and "Cfg_AutoDisk" or "Cfg_AutoMem", name)
    refreshCfgListUI()
end)

makeCfgBtn("Cfg_BtnDelete", 0.76, 0.23, function()
    local name = cfgInput.Text:gsub("%s+", "")
    if M.CFG.Delete(name) then
        M.State.SelectedCfg = "default"
        cfgInput.Text = "default"
        setCfgStatus("Cfg_Deleted", name)
        refreshCfgListUI()
    end
end)

refreshCfgListUI()
table.insert(M.Data.RegUI, {SetLanguage = function()
    setCfgStatus(cfgStatusState.Key, cfgStatusState.Arg)
    refreshCfgListUI()
end})
end

M.Data.PageBuilders.Settings = function()
-- Settings
M.F.MakeSection(pSet, "Sec_UiGlass", 1)
M.F.MakeToggle(pSet, "GlassOn", "GlassOn", 2, function() M.F.ApplyGlass() end, false)
M.F.MakeSlider(pSet, "GlassBlur", "GlassBlur", 0, 24, "", 3, function() M.F.UpdateGlassBlur(M.State.MenuOpen) end)
M.F.MakeSlider(pSet, "GlassSheen", "GlassSheen", 0, 1, "", 4, function() M.F.ApplyGlass() end)
M.F.MakeSection(pSet, "Sec_UiNotify", 5)
M.F.MakeToggle(pSet, "NotifyOn", "NotifyOn", 6, function() end, false)
M.F.MakeSlider(pSet, "NotifyAlpha", "NotifyAlpha", 0, 0.9, "", 7, function() M.F.NotifyPreview() end)
M.F.MakeSlider(pSet, "NotifyScale", "NotifyScale", 0.6, 1.8, "x", 8, function() M.F.NotifyRescale(); M.F.NotifyPreview() end)
M.F.MakePicker(pSet, "NotifyColor", "NotifyColor", 9, function(col)
    M.State.NotifyColor = col
    M.F.NotifyPreview()
end)

M.F.MakeSection(pSet, "Sec_UiIos", 10)
M.F.MakeToggle(pSet, "Ios26On", "Ios26On", 11, function() M.F.RestyleAllPanels() end, false)

M.F.MakeSection(pSet, "Sec_Safety", 12)
M.F.MakeToggle(pSet, "SafeStart", "SafeStart", 13, function() end, false)
M.F.MakeToggle(pSet, "RollbackGuard", "RollbackGuard", 15, function() end, false)
do
    local panicCard = M.F.MakeCard(pSet, 40); panicCard.LayoutOrder = 14
    local panicBtn = Instance.new("TextButton", panicCard)
    panicBtn.Size = UDim2.new(1, -20, 0, 28); panicBtn.Position = UDim2.new(0, 10, 0.5, -14)
    panicBtn.BackgroundColor3 = Color3.fromRGB(150, 42, 54); panicBtn.AutoButtonColor = true
    panicBtn.Text = M.Translate("Panic_Btn"); panicBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    panicBtn.Font = Enum.Font.GothamBold; panicBtn.TextSize = 12
    Instance.new("UICorner", panicBtn).CornerRadius = UDim.new(0, 7)
    panicBtn.MouseButton1Click:Connect(function() M.F.PanicReset() end)
    table.insert(M.Data.RegUI, {SetLanguage = function() panicBtn.Text = M.Translate("Panic_Btn") end})
end

M.F.MakeSection(pSet, "Sec_UiWidgets", 15)
M.F.MakeToggle(pSet, "SpeedWidgetOn", "SpeedWidgetOn", 16, function() end, true)
M.F.MakeSlider(pSet, "SpeedWidgetScale", "SpeedWidgetScale", 0.6, 2, "x", 17, function() end)

M.F.MakeSection(pSet, "Sec_UiFont", 18)
M.F.MakeDropdown(pSet, "FontStyle", {"Gotham", "Chat", "Bold", "Soft", "Code", "Lazy", "Light"}, "FontStyle", 19, function() M.F.ApplyFont() end)

M.F.MakeSection(pSet, "Sec_UiTheme", 23)
M.F.MakeDropdown(pSet, "LangBtn", {"EN", "RU"}, "Language", 24, function(v)
    M.L10N.Current = v
    M.F.UpdateLanguageUI()
end)
M.F.MakeSlider(pSet, "AnimSpeed", "AnimSpeed", 0.05, 0.5, "с", 25, function() end)
M.F.MakeSlider(pSet, "MainAlpha", "MenuAlpha", 0, 1, "", 26, function(v)
    if M.UI.MenuBg then M.UI.MenuBg.BackgroundTransparency = v end
    M.UI.PrevCard.BackgroundTransparency = v
    -- Чем прозрачнее меню, тем сильнее эффект стекла (блики, кромка и размытие мира за окном)
    M.F.ApplyGlass()
end)
M.F.MakePicker(pSet, "MainCol", "MainBg", 27, function(col)
    if M.UI.MenuBg then M.UI.MenuBg.BackgroundColor3 = col end
    M.UI.PrevCard.BackgroundColor3 = col
end)
M.F.MakeSlider(pSet, "CardAlpha", "CardAlpha", 0, 1, "", 28, function(v)
    for _, c in ipairs(M.State.Cards) do c.BackgroundTransparency = v end
    M.F.ApplyGlass()
end)
M.F.MakePicker(pSet, "CardCol", "CardBg", 29, function(col)
    for _, c in ipairs(M.State.Cards) do c.BackgroundColor3 = col end
end)
M.F.MakePicker(pSet, "AccentCol", "Accent", 30, function(col)
    M.F.RecolorAccent(col)
end)
M.F.MakeSlider(pSet, "BorderThick", "BorderThick", 0, 5, "px", 31, function(v)
    local t = math.round(v)
    M.UI.MainStroke.Thickness = t
    M.UI.PrevStroke.Thickness = t
    M.UI.SideStroke.Thickness = t
end)
M.F.MakePicker(pSet, "BorderCol", "BorderCol", 32, function(col)
    M.UI.MainStroke.Color = col
    M.UI.PrevStroke.Color = col
    M.UI.SideStroke.Color = col
end)

M.F.MakeSection(pSet, "Sec_UiSidebar", 33)
M.F.MakeSlider(pSet, "SideAlpha", "SideAlpha", 0, 1, "", 34, function(v) M.UI.Sidebar.BackgroundTransparency = v end)
M.F.MakePicker(pSet, "SideCol", "SideBg", 35, function(col) M.UI.Sidebar.BackgroundColor3 = col end)
M.F.MakeSlider(pSet, "SideCardAlpha", "SideCardAlpha", 0, 1, "", 36, function(v)
    for _, sc in ipairs(M.State.SideCards) do sc.BackgroundTransparency = v end
    M.F.SwitchTab(M.State.ActiveTab)
end)
M.F.MakePicker(pSet, "SideCardCol", "SideCardBg", 37, function(col)
    for _, sc in ipairs(M.State.SideCards) do sc.BackgroundColor3 = col end
    M.F.SwitchTab(M.State.ActiveTab)
end)
M.F.MakePicker(pSet, "LogoCol", "LogoCol", 38, function(col)
    M.UI.Logo.TextColor3 = col
    M.UI.LogoGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, col:Lerp(Color3.fromRGB(80, 80, 80), 0.4)),
        ColorSequenceKeypoint.new(0.5, col),
        ColorSequenceKeypoint.new(1, col:Lerp(Color3.fromRGB(80, 80, 80), 0.4))
    })
end)

M.F.MakeSection(pSet, "Sec_UiPill", 39)
M.F.MakeSlider(pSet, "PillScale", "PillScaleVal", 0.7, 1.6, "x", 40, function(v) M.UI.PillScale.Scale = v end)
M.F.MakeToggle(pSet, "PillUser", "PillShowUser", 41, function() end, false)
M.F.MakeToggle(pSet, "PillMem", "PillShowMem", 42, function() end, false)
M.F.MakeToggle(pSet, "PillMinsk", "PillShowMinsk", 43, function() end, false)
M.F.MakeToggle(pSet, "PillSession", "PillShowTime", 44, function() end, false)
M.F.MakeSlider(pSet, "PillBorderThick", "PillBorderThick", 0, 5, "px", 45, function() M.F.StylePill() end)
M.F.MakePicker(pSet, "PillBorderCol", "PillBorderCol", 46, function() M.F.StylePill() end)
M.F.MakeSlider(pSet, "PillAlpha", "PillAlpha", 0, 1, "", 47, function() M.F.StylePill() end)
M.F.MakePicker(pSet, "PillBg", "PillBg", 48, function() M.F.StylePill() end)
M.F.MakePicker(pSet, "PillTextCol", "PillTextCol", 49, function(col) M.UI.PillTxt.TextColor3 = col end)
end

-- ==============================================================================
-- [ ЖИДКОЕ СТЕКЛО ]
-- Стекло складывается из четырёх вещей: блик по диагонали, светящаяся кромка, лёгкая подсветка карточек
-- и размытие 3D-мира за меню. Чем прозрачнее меню (настройки прозрачности), тем сильнее эффект.
-- ==============================================================================
-- Размытие создаём ОДИН раз и держим со Size = 0. Раньше эффект создавался при каждом открытии меню и удалялся
-- при закрытии: пересборка графического конвейера давала подвисание ровно в начале анимации, и казалось,
-- что она не доигрывается и лагает. Теперь меняется только число Size.
function M.F.EnsureGlassBlur()
    if M.Data.FxGlassBlur and M.Data.FxGlassBlur.Parent then return M.Data.FxGlassBlur end
    local blur = Instance.new("BlurEffect")
    blur.Size = 0
    blur.Parent = M.Services.L
    M.Data.FxGlassBlur = blur
    return blur
end

function M.F.UpdateGlassBlur(open, duration)
    local L = M.Services.L
    local want = 0
    if open and M.State.GlassOn then
        want = M.State.GlassBlur * math.clamp(M.State.MenuAlpha * 2, 0.2, 1)
    end
    if want <= 0.05 then want = 0 end

    M.Data.GlassToken = M.Data.GlassToken + 1
    local token = M.Data.GlassToken
    local blur = (want > 0) and M.F.EnsureGlassBlur() or (M.Data.FxGlassBlur and M.Data.FxGlassBlur.Parent and M.Data.FxGlassBlur)
    if not blur then return end

    local fade = duration or ((want > 0) and 0.3 or 0.25)
    M.Services.T:Create(blur, TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = want}):Play()

    -- Стекло или размытие выключили совсем: после затухания эффект больше не нужен
    if want == 0 and (not M.State.GlassOn or M.State.GlassBlur <= 0.05) then
        task.delay(fade + 0.05, function()
            if token == M.Data.GlassToken and blur.Parent then
                blur:Destroy()
                if M.Data.FxGlassBlur == blur then M.Data.FxGlassBlur = nil end
            end
        end)
    end
end

function M.F.ApplyGlass()
    if not M.UI.Main then return end

    local on = M.State.GlassOn
    local sheen = math.clamp(M.State.GlassSheen, 0, 1)
    local seeThrough = math.clamp(M.State.MenuAlpha * 1.8, 0.15, 1)
    local opacity = 0.06 + 0.22 * sheen * seeThrough

    if M.UI.GlassSheen then
        M.UI.GlassSheen.Visible = on
        M.UI.GlassSheenGrad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1 - opacity),
            NumberSequenceKeypoint.new(0.45, 1 - opacity * 0.22),
            NumberSequenceKeypoint.new(1, 1)
        })
    end
    if M.UI.MainGrad then
        M.UI.MainGrad.Color = on
            and ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 222, 242))
            or ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255))
    end
    if M.UI.MainStrokeGrad then
        M.UI.MainStrokeGrad.Enabled = on
        local rim = 0.4 + 0.6 * sheen
        M.UI.MainStrokeGrad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1 - 0.9 * rim),
            NumberSequenceKeypoint.new(0.3, 0.7),
            NumberSequenceKeypoint.new(0.7, 0.82),
            NumberSequenceKeypoint.new(1, 1 - 0.85 * rim)
        })
    end
    if M.State.GlassOn and M.State.GlassBlur > 0.05 then M.F.EnsureGlassBlur() end
    M.F.UpdateGlassBlur(M.State.MenuOpen)
end

-- ==============================================================================
-- [ ПЛАВНОЕ ПОЯВЛЕНИЕ И РАСТВОРЕНИЕ БЕЗ CanvasGroup ]
-- Раньше всё меню растворялось через CanvasGroup.GroupTransparency. Но CanvasGroup у Roblox ненадёжен: при низком
-- качестве графики (а «Упрощённая графика» ставит именно его) анимацию такой группы урезают, картинку размывают, а
-- на нехватке памяти группа вообще рисуется пустой. Поэтому анимация «не работала». Теперь растворяются сами
-- элементы: у каждого видимого элемента прозрачность идёт от своего настоящего значения к полностью прозрачной.
-- Это работает при любом качестве графики и не зависит от CanvasGroup.
--   FadeCollect  - запоминает настоящие прозрачности всех ВИДИМЫХ элементов (скрытые страницы пропускаются);
--   FadeApply    - ставит нужную видимость (1 = как обычно, 0 = невидимо);
--   FadePrepare / FadeTo / FadeFinish - управление анимацией по ключу: можно прервать и развернуть на ходу.
-- ==============================================================================
function M.F.FadeCollect(roots)
    local entries = {}
    local stack = {}
    for _, root in ipairs(roots) do
        if root then stack[#stack + 1] = root end
    end
    while #stack > 0 do
        local obj = table.remove(stack)
        local descend = true
        if obj:IsA("GuiObject") then
            if not obj.Visible then
                descend = false                -- скрытое поддерево не трогаем
            else
                local entry, has = {Obj = obj}, false
                local bg = obj.BackgroundTransparency
                if bg < 1 then entry.BT, has = bg, true end
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                    local text = obj.TextTransparency
                    if text < 1 then entry.TT, has = text, true end
                    local stroke = obj.TextStrokeTransparency
                    if stroke < 1 then entry.ST, has = stroke, true end
                elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") or obj:IsA("ViewportFrame") then
                    local image = obj.ImageTransparency
                    if image < 1 then entry.IT, has = image, true end
                end
                if obj:IsA("ScrollingFrame") then
                    local bar = obj.ScrollBarImageTransparency
                    if bar < 1 then entry.SB, has = bar, true end
                end
                if has then entries[#entries + 1] = entry end
            end
        elseif obj:IsA("UIStroke") then
            local line = obj.Transparency
            if line < 1 then entries[#entries + 1] = {Obj = obj, UT = line} end
        end
        if descend then
            for _, child in ipairs(obj:GetChildren()) do stack[#stack + 1] = child end
        end
    end
    return entries
end

function M.F.FadeApply(entries, visibility)
    local hidden = 1 - visibility
    for _, entry in ipairs(entries) do
        local obj = entry.Obj
        if obj.Parent then
            if entry.BT then obj.BackgroundTransparency = entry.BT + (1 - entry.BT) * hidden end
            if entry.TT then obj.TextTransparency = entry.TT + (1 - entry.TT) * hidden end
            if entry.ST then obj.TextStrokeTransparency = entry.ST + (1 - entry.ST) * hidden end
            if entry.IT then obj.ImageTransparency = entry.IT + (1 - entry.IT) * hidden end
            if entry.SB then obj.ScrollBarImageTransparency = entry.SB + (1 - entry.SB) * hidden end
            if entry.UT then obj.Transparency = entry.UT + (1 - entry.UT) * hidden end
        end
    end
end

-- Готовит анимацию. Если по этому ключу уже что-то идёт (например, меню закрывают, а потом сразу открывают),
-- продолжаем с текущего места. startVisibility применяется только при первом сборе значений.
function M.F.FadePrepare(key, roots, startVisibility)
    local fades = M.Data.Fades
    local state = fades[key]
    if state and state.Conn then state.Conn:Disconnect(); state.Conn = nil end
    if not (state and state.Entries) then
        state = {Entries = M.F.FadeCollect(roots), Visibility = 1}
        fades[key] = state
        if startVisibility ~= nil then
            state.Visibility = startVisibility
            M.F.FadeApply(state.Entries, startVisibility)
        end
    end
    return state
end

-- Плавно ведёт видимость к target (кривая Sine InOut). onDone вызывается по окончании.
function M.F.FadeTo(key, target, duration, onDone)
    local state = M.Data.Fades[key]
    if not state or not state.Entries then
        if onDone then onDone() end
        return
    end
    if state.Conn then state.Conn:Disconnect(); state.Conn = nil end
    local from, started = state.Visibility, os.clock()
    duration = math.max(duration, 0.01)
    state.Conn = M.Services.R.RenderStepped:Connect(function()
        local progress = math.clamp((os.clock() - started) / duration, 0, 1)
        local eased = -(math.cos(math.pi * progress) - 1) / 2
        state.Visibility = from + (target - from) * eased
        M.F.FadeApply(state.Entries, state.Visibility)
        if progress >= 1 then
            if state.Conn then state.Conn:Disconnect(); state.Conn = nil end
            state.Visibility = target
            if onDone then onDone() end
        end
    end)
end

-- Останавливает анимацию и возвращает всем элементам их настоящие прозрачности
function M.F.FadeFinish(key)
    local state = M.Data.Fades[key]
    if not state then return end
    if state.Conn then state.Conn:Disconnect(); state.Conn = nil end
    if state.Entries then M.F.FadeApply(state.Entries, 1) end
    M.Data.Fades[key] = nil
end

function M.F.FadeFinishAll()
    local keys = {}
    for key in pairs(M.Data.Fades) do keys[#keys + 1] = key end
    for _, key in ipairs(keys) do M.F.FadeFinish(key) end
end

-- Всё меню (фон, карточки, текст, блик) лежит в ОДНОМ контейнере Content и растворяется одной общей анимацией
-- (см. FadePrepare/FadeTo выше), поэтому фон, карточки и текст появляются строго вместе.
function M.F.BuildMenuLayers()
    local main = M.UI.Main
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ClipsDescendants = true
    content.Parent = main

    -- Фон окна теперь внутри группы, под всеми остальными элементами
    local bg = Instance.new("Frame")
    bg.Name = "MenuBg"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = M.State.MainBg
    bg.BackgroundTransparency = M.State.MenuAlpha
    bg.BorderSizePixel = 0
    bg.Active = false
    bg.ZIndex = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 12)
    bg.Parent = content
    main.BackgroundTransparency = 1
    M.UI.MenuBg = bg

    for _, child in ipairs(main:GetChildren()) do
        if child:IsA("GuiObject") and child ~= content then
            child.Parent = content
        end
    end
    M.UI.Content = content

    -- Стеклянный блик поверх всего, тоже внутри группы. Не перехватывает мышь.
    local sheen = Instance.new("Frame")
    sheen.Name = "GlassSheen"
    sheen.Size = UDim2.new(1, 0, 1, 0)
    sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sheen.BorderSizePixel = 0
    sheen.Active = false
    sheen.ZIndex = 100
    Instance.new("UICorner", sheen).CornerRadius = UDim.new(0, 12)
    local sheenGrad = Instance.new("UIGradient", sheen)
    sheenGrad.Rotation = 35
    sheen.Parent = content
    M.UI.GlassSheen, M.UI.GlassSheenGrad = sheen, sheenGrad

    M.UI.MainGrad = Instance.new("UIGradient", bg)
    M.UI.MainGrad.Rotation = 35
    M.UI.MainStrokeGrad = Instance.new("UIGradient", M.UI.MainStroke)
    M.UI.MainStrokeGrad.Rotation = 45
    M.F.ApplyGlass()
end

-- ==============================================================================
-- [ MENU LIFECYCLE & CLEANUP ]
-- ==============================================================================
M.F.BuildMenuLayers()

-- Одна анимация для всех частей меню: меню РАСТВОРЯЕТСЯ на месте, ничего никуда не едет. Меняется прозрачность
-- самих элементов (не CanvasGroup), кривая Sine InOut, одно время у меню, рамки и карточки предпросмотра.
-- Чтобы анимация не рвалась:
--   * всё тяжёлое (размытие мира, предпросмотр, перерисовка аватарки) запускается ПОСЛЕ старта анимации, а не в
--     первом кадре, иначе подвисание съедало начало анимации;
--   * в конце всем элементам возвращаются настоящие значения (FadeFinish);
--   * если меню быстро открыли и закрыли, анимация разворачивается с текущего места, а устаревшие шаги
--     отменяются по номеру (MenuToken).
M.F.CloseMenu = function()
    M.State.MenuOpen = false
    M.Data.MenuToken = M.Data.MenuToken + 1
    local token = M.Data.MenuToken
    M.UI.Tooltip.Visible = false

    local duration = math.max(M.State.AnimSpeed * 1.1, 0.22)
    M.F.FadePrepare("Menu", {M.UI.Main}, 1)
    M.F.FadeTo("Menu", 0, duration, function()
        -- Если за это время меню снова открыли, прятать его уже нельзя
        if token ~= M.Data.MenuToken then return end
        M.UI.Main.Visible = false
        M.F.FadeFinish("Menu")
    end)
    if M.UI.PrevCard.Visible then
        M.F.FadePrepare("Prev", {M.UI.PrevCard}, 1)
        M.F.FadeTo("Prev", 0, duration, function()
            if token ~= M.Data.MenuToken then return end
            M.UI.PrevCard.Visible = false
            M.F.FadeFinish("Prev")
        end)
    end
    M.F.UpdateGlassBlur(false, duration)
end

M.F.OpenMenu = function()
    M.State.MenuOpen = true
    M.Data.MenuToken = M.Data.MenuToken + 1
    local token = M.Data.MenuToken

    -- Старт: окно показываем и сразу делаем полностью прозрачным (в том же кадре, поэтому вспышки нет).
    -- Если закрытие ещё шло, Prepare ничего не пересобирает и открытие продолжается с текущего места.
    M.UI.Main.Visible = true
    M.F.FadePrepare("Menu", {M.UI.Main}, 0)
    M.F.FadeFinish("Prev")

    local duration = math.max(M.State.AnimSpeed * 1.7, 0.35)
    M.F.FadeTo("Menu", 1, duration, function()
        if token ~= M.Data.MenuToken or not M.State.MenuOpen then return end
        M.F.FadeFinish("Menu")
    end)

    local showPreview = (M.State.ActiveTab == "Display")
    -- Тяжёлое: чуть позже, уже после того как анимация пошла
    task.delay(0.04, function()
        if token ~= M.Data.MenuToken or not M.State.MenuOpen then return end
        M.F.UpdateGlassBlur(true, math.max(duration - 0.04, 0.1))
        if showPreview then
            M.F.SyncPreviewPos()
            M.UI.PrevCard.Visible = true
            M.F.Update2DPreview()
            M.F.FadePrepare("Prev", {M.UI.PrevCard}, 0)
            M.F.FadeTo("Prev", 1, math.max(duration - 0.04, 0.1), function()
                if token ~= M.Data.MenuToken then return end
                M.F.FadeFinish("Prev")
            end)
        end
    end)
end

M.F.ShutDown = function()
    M.State.IsShutDown = true
    -- Сначала снимаем тряску, чтобы камера не осталась повёрнутой
    local shakeCam = workspace.CurrentCamera
    if shakeCam then M.F.UndoShake(shakeCam) end
    pcall(function() M.Services.R:UnbindFromRenderStep("ShakeUndo") end)
    pcall(function() M.Services.R:UnbindFromRenderStep("CamProcessor") end)
    pcall(function() M.Services.R:UnbindFromRenderStep("FovProcessor") end)

    for _, conn in ipairs(M.Data.Conns) do
        if conn then conn:Disconnect() end
    end
    M.Data.Conns = {}

    for _, conn in ipairs(M.Data.CharConns) do
        if conn then conn:Disconnect() end
    end
    M.Data.CharConns = {}

    for _, conn in pairs(M.State.PlayerConns) do
        if conn then conn:Disconnect() end
    end
    M.State.PlayerConns = {}

    if M.UI.WallPassLoop then M.UI.WallPassLoop:Disconnect(); M.UI.WallPassLoop = nil end
    M.Data.WallReleasePending = false

    do
        local char = M.LP and M.LP.Character
        M.F.ReleaseSpeedBoost(char and char:FindFirstChildOfClass("Humanoid"))
    end
    M.F.StopFlying()
    M.F.SetWallPass(false)
    M.ApplyFpsBoost(false)
    M.ApplyFpsUnlocker(false)
    M.State.PlayerView = false; M.F.UpdatePlayerView()
    M.State.FogOn = false; M.F.ApplyFog()
    M.State.CloudsOn = false; M.F.ApplyClouds()
    M.State.SunRaysOn = false; M.F.ApplySunRays()
    if M.Data.FxGlassBlur and M.Data.FxGlassBlur.Parent then M.Data.FxGlassBlur:Destroy() end
    M.Data.FxGlassBlur = nil
    M.State.GradeOn = false; M.F.ApplyGrade()
    M.State.DamageNumbers = false
    M.State.BloomOn = false; M.F.ApplyBloom()
    M.State.SpectateOn = false; M.F.UpdateSpectate()
    M.F.UnloadAllModules()
    M.F.FadeFinishAll()
    M.State.DarkWorld = false; M.F.ApplyDark()
    M.State.SkyOn = false; M.F.RestoreSky()
    M.State.TimeOn = false; M.Services.L.ClockTime = M.State.OrigTime
    M.State.WeatherOn = false; M.F.ClearWeatherProps()
    M.State.HatOn = false; if M.State.HatModel then M.State.HatModel:Destroy() end
    M.State.OrbitOn = false; for _, item in ipairs(M.State.OrbitObjs) do if item.Part then item.Part:Destroy() end end

    local cam = workspace.CurrentCamera
    -- Возвращаем FOV игры (раньше всегда ставилось 70)
    M.State.FovOn = false
    M.State.ZoomOn = false
    M.Data.ZoomHeld = false
    M.Data.ZoomBlend = 0
    if cam then M.F.UpdateFov(cam, 0.016) end

    -- Раньше тут принудительно ставили WalkSpeed = 16 и CanCollide = true для всех деталей.
    -- Это ломало игры с другой скоростью и превращало шапки в твёрдые объекты. Теперь возвращаем только своё.
    M.State.ThirdPerson = false
    M.F.UpdateThirdPerson(cam, nil, nil, false)
    M.State.FallProtection = false
    M.F.UpdateFallProtection()
    M.State.AutoJump = false
    M.State.AntiStun = false
    M.State.IdleProtection = false
    M.F.SetIdleProtection(false)
    M.State.HideHats = false
    M.State.HoloSelf = false
    M.UpdatePlayerVisuals()

    -- Возвращаем персонажа вертикально и отдаём управление поворотом обратно Humanoid
    M.State.SpinCharacter = false
    M.State.HeadTiltOn = false
    M.F.UpdatePoseReal(0)

    pcall(function()
        if M.UI.Gui then M.UI.Gui:Destroy() end
        if M.UI.PlayerViewGui then M.UI.PlayerViewGui:Destroy() end
        for key in pairs(M.Data.FolderNames) do
            if M.UI[key] then M.UI[key]:Destroy() end
            M.UI[key] = nil
        end
    end)
end

M.UI.Main.Visible = false

-- ==============================================================================
-- [ INTRO AND INITIAL LAUNCH ]
-- Заставка идёт около 9 секунд; её можно пропустить любой клавишей, кликом или касанием. Стеклянная карточка по центру: буквы логотипа выезжают
-- по очереди, потом по ним пробегает волна цвета темы. Ниже настоящие шаги запуска с прогресс-баром и процентами,
-- мир за карточкой размыт. Никаких шаров и кругов: только карточка, текст и полоса прогресса.
-- ==============================================================================
-- Экран загрузки. Всё построено на одном спокойном приёме: плавное появление и растворение (кривая Sine, вход и
-- выход одинаково мягкие). Раньше были пружинка у карточки, выезд букв снизу, резкий старт кривой Quint, увеличение
-- карточки при выходе и очень сильное размытие. Теперь ничего не отскакивает, не едет и не увеличивается.
function M.F.RunIntro()
    local introGui = Instance.new("ScreenGui")
    introGui.Name = "Matsysense"
    introGui.ResetOnSpawn = false
    -- 99999 заменено на небольшое число: экрану загрузки достаточно быть выше меню (200), не выше вообще всего
    introGui.DisplayOrder = 210
    introGui.IgnoreGuiInset = true
    introGui.Parent = M.TargetGui

    -- Пропуск заставки: любая клавиша, клик или касание. Шаги запуска (конфиг, стили, проверка окружения)
    -- при этом всё равно выполняются полностью, сокращаются только ожидания и анимации.
    local skipped = false
    local skipConn = M.Services.U.InputBegan:Connect(function(input)
        local kind = input.UserInputType
        if kind == Enum.UserInputType.Keyboard or kind == Enum.UserInputType.MouseButton1
            or kind == Enum.UserInputType.Touch then
            skipped = true
        end
    end)

    local function pause(seconds)
        local waited = 0
        while waited < seconds and not M.State.IsShutDown and not skipped do
            waited = waited + task.wait(0.03)
        end
    end
    -- Единая кривая для ВСЕГО на экране загрузки
    local function tween(inst, duration, goal)
        local t = M.Services.T:Create(inst, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), goal)
        t:Play()
        return t
    end
    local function ease(alpha) return -(math.cos(math.pi * alpha) - 1) / 2 end      -- та же кривая Sine InOut

    local backdrop = Instance.new("Frame")
    backdrop.Size = UDim2.new(1, 0, 1, 36)
    backdrop.Position = UDim2.new(0, 0, 0, -36)
    backdrop.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
    backdrop.BackgroundTransparency = 1
    backdrop.BorderSizePixel = 0
    backdrop.Parent = introGui

    -- Стеклянная карточка: три слоя одной формы (заливка, содержимое, кромка). Размер постоянный.
    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.Size = UDim2.fromOffset(460, 260)
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    card.Parent = backdrop

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(44, 48, 68)
    fill.BackgroundTransparency = 1
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 38)
    fill.Parent = card

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Parent = card

    local rim = Instance.new("Frame")
    rim.Size = UDim2.new(1, 0, 1, 0)
    rim.BackgroundTransparency = 1
    rim.BorderSizePixel = 0
    Instance.new("UICorner", rim).CornerRadius = UDim.new(0, 38)
    local rimStroke = Instance.new("UIStroke")
    rimStroke.Thickness = 1.4
    rimStroke.Color = Color3.fromRGB(255, 255, 255)
    rimStroke.Transparency = 1
    rimStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    rimStroke.Parent = rim
    local rimGrad = Instance.new("UIGradient", rimStroke)
    rimGrad.Rotation = 90
    rimGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.5, 0.82),
        NumberSequenceKeypoint.new(1, 0.5)
    })
    rim.Parent = card

    -- Логотип: буквы стоят на своих местах и просто проявляются по очереди
    local letters = {}
    local word = {{"M", 44}, {"A", 36}, {"T", 32}, {"S", 31}, {"Y", 34}, {"S", 31}, {"E", 30}, {"N", 37}, {"S", 31}, {"E", 30}}
    local totalWidth = 0
    for _, item in ipairs(word) do totalWidth = totalWidth + item[2] end
    local cursor = (460 - totalWidth) / 2
    for _, item in ipairs(word) do
        local label = Instance.new("TextLabel")
        label.Position = UDim2.new(0, cursor, 0, 56)
        label.Size = UDim2.fromOffset(item[2], 54)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBlack
        label.TextSize = 46
        label.Text = item[1]
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextTransparency = 1
        label.Parent = content
        table.insert(letters, label)
        cursor = cursor + item[2]
    end

    local subtitle = Instance.new("TextLabel")
    subtitle.Position = UDim2.new(0, 0, 0, 118)
    subtitle.Size = UDim2.new(1, 0, 0, 18)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.GothamMedium
    subtitle.TextSize = 12
    subtitle.Text = "S U P R E M E   E D I T I O N"
    subtitle.TextColor3 = Color3.fromRGB(165, 172, 195)
    subtitle.TextTransparency = 1
    subtitle.Parent = content

    -- Прогресс: капсула, подпись шага и проценты
    local track = Instance.new("Frame")
    track.AnchorPoint = Vector2.new(0.5, 0)
    track.Position = UDim2.new(0.5, 0, 0, 172)
    track.Size = UDim2.fromOffset(360, 8)
    track.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    track.BackgroundTransparency = 0.88
    track.BorderSizePixel = 0
    track.ClipsDescendants = true
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    track.Parent = content

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 0, 1, 0)
    bar.BackgroundColor3 = M.State.Accent
    bar.BorderSizePixel = 0
    bar.ClipsDescendants = true
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    bar.Parent = track

    -- Блик, бегущий по заполненной части полосы (медленный и мягкий)
    local shine = Instance.new("Frame")
    shine.Size = UDim2.new(0, 60, 1, 0)
    shine.Position = UDim2.new(0, -60, 0, 0)
    shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    shine.BorderSizePixel = 0
    local shineGrad = Instance.new("UIGradient", shine)
    shineGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.65),
        NumberSequenceKeypoint.new(1, 1)
    })
    shine.Parent = bar
    local shineTween = M.Services.T:Create(shine, TweenInfo.new(1.8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
        {Position = UDim2.new(1, 0, 0, 0)})
    shineTween:Play()

    local status = Instance.new("TextLabel")
    status.Position = UDim2.new(0, 50, 0, 192)
    status.Size = UDim2.new(1, -150, 0, 18)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.GothamMedium
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextColor3 = Color3.fromRGB(205, 212, 232)
    status.Text = ""
    status.Parent = content
    local percent = Instance.new("TextLabel")
    percent.AnchorPoint = Vector2.new(1, 0)
    percent.Position = UDim2.new(1, -50, 0, 192)
    percent.Size = UDim2.fromOffset(70, 18)
    percent.BackgroundTransparency = 1
    percent.Font = Enum.Font.GothamBold
    percent.TextSize = 12
    percent.TextXAlignment = Enum.TextXAlignment.Right
    percent.TextColor3 = Color3.fromRGB(255, 255, 255)
    percent.Text = "0%"
    percent.Parent = content

    local skipHint = Instance.new("TextLabel")
    skipHint.Position = UDim2.new(0, 0, 0, 228)
    skipHint.Size = UDim2.new(1, 0, 0, 16)
    skipHint.BackgroundTransparency = 1
    skipHint.Font = Enum.Font.Gotham
    skipHint.TextSize = 11
    skipHint.TextColor3 = Color3.fromRGB(165, 172, 195)
    skipHint.TextTransparency = 0.35
    skipHint.Text = M.Translate("Intro_Skip")
    skipHint.Parent = content

    local function finish()
        skipConn:Disconnect()
        pcall(function() shineTween:Cancel() end)
        M.F.FadeFinish("Intro")
        introGui:Destroy()
    end

    -- Появление: фон и размытие проявляются первыми, затем карточка, затем буквы одна за другой
    tween(backdrop, 1.1, {BackgroundTransparency = 0.25})
    pause(0.6)
    tween(fill, 1.0, {BackgroundTransparency = 0.16})
    tween(rimStroke, 1.0, {Transparency = 0})
    -- Содержимое карточки проявляется самими элементами (без CanvasGroup). Буквы и подпись пока прозрачны и в
    -- этот набор не попадают: они проявляются отдельно, по очереди.
    M.F.FadePrepare("Intro", {content}, 0)
    M.F.FadeTo("Intro", 1, 1.0, function() M.F.FadeFinish("Intro") end)
    pause(0.6)

    for _, label in ipairs(letters) do
        tween(label, 0.9, {TextTransparency = 0})
        pause(0.08)
    end
    tween(subtitle, 1.0, {TextTransparency = 0})

    -- Волна цвета темы по буквам (идёт параллельно с загрузкой, плавно в обе стороны)
    task.spawn(function()
        pause(0.5)
        for _, label in ipairs(letters) do
            if M.State.IsShutDown then break end
            tween(label, 0.4, {TextColor3 = M.State.Accent})
            task.delay(0.45, function()
                if label.Parent then tween(label, 0.7, {TextColor3 = Color3.fromRGB(255, 255, 255)}) end
            end)
            pause(0.09)
        end
    end)

    -- Настоящие шаги запуска. Полоса и проценты идут по одной и той же кривой.
    local shown = 0
    local function setProgress(target, stepKey)
        status.Text = M.Translate(stepKey)
        local duration = skipped and 0.15 or 0.8
        tween(bar, duration, {Size = UDim2.new(target / 100, 0, 1, 0)})
        local from = shown
        local started = os.clock()
        while os.clock() - started < duration and not M.State.IsShutDown and not skipped do
            local alpha = ease(math.clamp((os.clock() - started) / duration, 0, 1))
            percent.Text = string.format("%d%%", math.floor(from + (target - from) * alpha + 0.5))
            task.wait(0.03)
        end
        shown = target
        percent.Text = string.format("%d%%", target)
    end

    pause(0.3)
    setProgress(20, "Intro_Step1")
    M.CFG.CheckAutoload()
    pause(0.2)
    setProgress(45, "Intro_Step2")
    M.F.RestyleAllPanels()
    M.F.ApplyGlass()
    pause(0.2)
    setProgress(70, "Intro_Step3")
    pause(0.2)
    setProgress(90, "Intro_Step4")
    M.F.GuardEnvironment()
    pause(0.2)
    setProgress(100, "Intro_Step5")
    tween(bar, 0.5, {BackgroundColor3 = Color3.fromRGB(150, 235, 190)})

    -- Содержимое вкладки больше не строится здесь заранее: M.F.OpenMenu сам построит нужную страницу,
    -- когда меню действительно появляется на экране, а не во время заставки.
    pause(0.5)

    -- Финал: всё растворяется вместе, одним временем и одной кривой, ничего не увеличивается и не едет.
    -- Меню начинает проявляться, когда загрузочный экран растворён наполовину: плавный переход без провала.
    local fade = skipped and 0.4 or 1.1
    M.F.FadeFinish("Intro")
    M.F.FadePrepare("Intro", {content}, 1)          -- теперь собираются и буквы: у них уже настоящие значения
    M.F.FadeTo("Intro", 0, fade)
    tween(fill, fade, {BackgroundTransparency = 1})
    tween(rimStroke, fade, {Transparency = 1})
    local done = tween(backdrop, fade, {BackgroundTransparency = 1})
    pause(fade * 0.5)
    if not M.State.IsShutDown then M.F.OpenMenu() end
    done.Completed:Wait()

    finish()
    -- Интро больше не понадобится: освобождаем функцию, и вместе с ней все её данные
    M.F.RunIntro = nil
end

task.spawn(M.F.RunIntro)

-- ==============================================================================
-- СПИСОК ГЛАВНЫХ ИСПРАВЛЕНИЙ (revision 2)
--  1. Вращение (Spin) не работало на R15: мотор "Root" лежит в LowerTorso, а не в HumanoidRootPart.
--  2. IsTeammate считал ВСЕХ своими в играх без команд (одинаковый TeamColor) -> наводка/триггер молчали.
--  3. Бинд-клавиша: "условие and nil or x" всегда давала x -> Backspace/Delete/Escape не снимали бинд.
--  4. Метеориты: Y игрока прибавлялся дважды, деталь не была Anchored.
--  5. Туман/облака/темнота/Ambient/частицы: теперь запоминаются и ВОЗВРАЩАЮТСЯ, чужие Atmosphere не ломаются.
--  6. Noclip возвращал CanCollide=true ВСЕМ деталям (шапки становились твёрдыми) -> теперь исходные значения.
--  7. Внешний вид персонажа красился каждый кадр -> теперь только при включении и с возвратом.
--  8. Защита от АФК и "Гасить толчки" были пустыми переключателями -> реализованы.
--  9. Триггер стрелял дважды (Tool + VirtualUser), TriggerWallCheck не работал.
-- 10. Конфиг сохранял служебные значения (MenuOpen, Orig*), а загрузка сама включала туман.
-- 11. Выпадающие списки перекрывались карточками (ZIndexBehavior), быстрое открытие меню прятало его.
-- 12. Утечки: незакрытые соединения, кэши без weak-ключей, повторное создание шапки на каждый тик слайдера.
-- ==============================================================================

-- ==============================================================================
-- Matsysense Supreme Edition (Roblox Studio Native Port)
-- Enterprise Monolith Architecture - Bug-Fixed Core (revision 2)
-- ==============================================================================

-- Поставьте true, чтобы при запуске в Output выполнились встроенные модульные тесты (см. M.RunSelfTests внизу файла)
local RUN_SELF_TESTS = false

local M = {}

M.Services = {
    P = game:GetService("Players"),
    R = game:GetService("RunService"),
    U = game:GetService("UserInputService"),
    T = game:GetService("TweenService"),
    L = game:GetService("Lighting"),
    H = game:GetService("HttpService"),
    D = game:GetService("Debris"),
    S = game:GetService("Stats"),
    G = game:GetService("GuiService"),
    V = game:GetService("VirtualUser"),
    C = game:GetService("ContentProvider")
}

M.LP = M.Services.P.LocalPlayer
if not M.LP then
    M.Services.P:GetPropertyChangedSignal("LocalPlayer"):Wait()
    M.LP = M.Services.P.LocalPlayer
end
M.TargetGui = M.LP:WaitForChild("PlayerGui")

M.RayParams = RaycastParams.new()
M.RayParams.FilterType = Enum.RaycastFilterType.Exclude

pcall(function()
    local oldHub = M.TargetGui:FindFirstChild("MatsysenseHub")
    if oldHub then oldHub:Destroy() end
    local oldEsp = M.TargetGui:FindFirstChild("MatsysenseESP")
    if oldEsp then oldEsp:Destroy() end
    local oldIntro = M.TargetGui:FindFirstChild("MatsysenseIntro")
    if oldIntro then oldIntro:Destroy() end
    for _, name in ipairs({"MatsysenseWeatherProps", "MatsysenseMeteors", "MatsysenseVisuals", "MatsysenseLightnings", "MatsysenseKillFX", "MatsysenseClothCache", "MatsysenseGhostCache", "MatsysenseJumpRings"}) do
        local obj = workspace:FindFirstChild(name)
        if obj then obj:Destroy() end
    end
    local oldAtmo = M.Services.L:FindFirstChild("MatsysenseAtmosphere")
    if oldAtmo then oldAtmo:Destroy() end
end)

M.L10N = {
    Current = "RU",
    Dict = {
        Tab_Combat = {RU = "Бой", EN = "Combat"},
        Tab_Movement = {RU = "Движение", EN = "Movement"},
        Tab_Camera = {RU = "Камера", EN = "Camera"},
        Tab_ESP = {RU = "Отображение", EN = "Display"},
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
        Sec_CameraMods = {RU = "Модификации экрана", EN = "Screen Mods"},
        Sec_EspBase = {RU = "Видимость игроков", EN = "Player Visibility"},
        Sec_EspBoxes = {RU = "Настройки рамок", EN = "Box Settings"},
        Sec_EspHealth = {RU = "Шкала здоровья", EN = "Health Bar"},
        Sec_EspTracers = {RU = "Линии до игроков (Трейсеры)", EN = "Tracers"},
        Sec_WorldFog = {RU = "Настройка тумана", EN = "Fog Settings"},
        Sec_WorldClouds = {RU = "Настройка облаков", EN = "Cloud Settings"},
        Sec_WorldWeather = {RU = "Эффекты погоды", EN = "Weather Effects"},
        Sec_WorldEffects = {RU = "Дополнительные эффекты", EN = "Additional Effects"},
        Sec_WorldSky = {RU = "Свой скайбокс (небо)", EN = "Custom Skybox"},
        Sec_PlyrModel = {RU = "Внешний вид модели", EN = "Model Appearance"},
        Sec_PlyrJump = {RU = "Следы от прыжка", EN = "Jump Trails"},
        Sec_PlyrAccessories = {RU = "Сферы вокруг тела", EN = "Body Spheres"},
        Sec_SilhouetteMod = {RU = "Искажение позы", EN = "Posture Distortion"},
        Sec_NetworkMod = {RU = "Сетевые функции", EN = "Network Functions"},
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
        TriggerLoop = {RU = "Стрелять непрерывно (Зажим)", EN = "Continuous Fire Loop"},
        TriggerDelay = {RU = "Задержка перед выстрелом", EN = "Fire Delay"},
        TriggerWallCheck = {RU = "Не стрелять через стены", EN = "Check Obstacles"},

        Levitation = {RU = "Режим полета", EN = "Flight Mode"},
        ImpulseStutters = {RU = "Гасить сильные толчки", EN = "Anti-Knockback"},
        MovementVelocity = {RU = "Ускорение бега", EN = "Sprint Boost"},
        AirVectoring = {RU = "Управление в прыжке", EN = "Mid-air Control"},
        AirSpeed = {RU = "Скорость в воздухе", EN = "Mid-air Speed"},
        AirAccel = {RU = "Резкость маневров", EN = "Maneuver Sharpness"},

        PhaseCollision = {RU = "Проходить сквозь стены", EN = "Walk Through Walls"},
        AirVault = {RU = "Бесконечные прыжки", EN = "Infinite Jumps"},
        NetworkAlive = {RU = "Защита от АФК", EN = "Anti-AFK"},
        StateForce = {RU = "Защита от падений (Анти-Рэгдолл)", EN = "Block Falling"},

        CamFov = {RU = "Отдаленность камеры (FOV)", EN = "Field of View"},
        ThirdPerson = {RU = "Вид от 3-го лица (Шифт-лок)", EN = "Third Person View (Shift-Lock)"},
        ThirdPersonDist = {RU = "Дистанция камеры", EN = "Camera Distance"},

        EnableEsp = {RU = "Показывать игроков (ВХ)", EN = "Show Players"},
        EspOnSelf = {RU = "Показывать на себе", EN = "Show on Self"},
        EspTeamCheck = {RU = "Скрыть своих из видимости", EN = "Hide Teammates"},
        FillCol = {RU = "Цвет заливки тела", EN = "Fill Color"},
        LineCol = {RU = "Цвет контура (За стеной)", EN = "Outline Color"},

        EspBox = {RU = "Показывать рамки игроков", EN = "Render Boxes"},
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

        EspTracers = {RU = "Линии до игроков (Трейсеры)", EN = "Player Tracers"},
        TracerCol = {RU = "Цвет трейсеров", EN = "Tracer Color"},

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
        SkyOn = {RU = "Включить свой скайбокс", EN = "Enable Custom Skybox"},
        SkyIds = {RU = "ID скайбокса", EN = "Skybox ID"},
        SkyHideBodies = {RU = "Скрыть солнце, луну и звёзды", EN = "Hide Sun, Moon & Stars"},
        SkyPlaceholder = {
            RU = "Формат: 1234567890 или rbxassetid://1234567890\n6 граней через запятую: Bk, Dn, Ft, Lf, Rt, Up",
            EN = "Format: 1234567890 or rbxassetid://1234567890\n6 faces, comma-separated: Bk, Dn, Ft, Lf, Rt, Up"
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

        PitchMod = {RU = "Наклонить тело в пол", EN = "Tilt Body Down"},
        PitchAngle = {RU = "Угол наклона", EN = "Tilt Angle"},
        RotationYaw = {RU = "Вращать персонажа", EN = "Spin Character"},
        YawSpeed = {RU = "Скорость вращения", EN = "Rotation Speed"},
        JitterSpin = {RU = "Джиттер-вращение", EN = "Jitter Rotation"},
        PacketChoke = {RU = "Искусственная задержка", EN = "Fake Lag"},
        LagTicks = {RU = "Сила задержки", EN = "Delay Strength"},
        LagLimit = {RU = "Лимит задержки", EN = "Delay Limit (s)"},
        BacktrackShadows = {RU = "Тени прошлых позиций", EN = "Past Position Shadows"},
        GhostMat = {RU = "Материал теней", EN = "Shadow Material"},
        GhostCount = {RU = "Количество теней", EN = "Shadow Count"},
        GhostAlpha = {RU = "Прозрачность теней", EN = "Shadow Transparency"},
        GhostCol = {RU = "Цвет теней", EN = "Shadow Color"},

        FpsBoost = {RU = "Мыльные текстуры (FPS Boost)", EN = "Potato Textures (FPS Boost)"},
        FpsUnlocker = {RU = "Разблокировать FPS (Без лимита)", EN = "Unlock FPS (No Limit)"},

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
    Levitation = "Полет персонажа с управлением на WASD/Space/Shift.",
    MovementVelocity = "Ускорение бега.",
    PhaseCollision = "Отключение столкновений частей персонажа.",
    AirVault = "Прыжки в воздухе.",
    NetworkAlive = "Предотвращение отключения.",
    StateForce = "Защита персонажа от падений и физических опрокидываний.",
    RotationYaw = "Вращение туловища модели.",
    YawSpeed = "Плавная регулировка скорости вращения персонажа.",
    JitterSpin = "Резкие случайные рывки при вращении.",
    PitchMod = "Наклон модели по вертикали.",
    PacketChoke = "Только визуально: меняет частоту теней и показ пинга. На сервер ничего не отправляется.",
    BacktrackShadows = "Следы прошлых координат персонажа.",
    AirVectoring = "Управление траекторией в падении.",
    EnableEsp = "Подсветка сущностей.",
    EspTracers = "Отрисовка линий от низа экрана до игроков.",
    ThirdPerson = "Фиксированный вид от третьего лица.",
    CloudsOn = "Включение объемных облаков в небе.",
    FpsBoost = "Превращает карту в гладкий пластик без лишних текстур.",
    FpsUnlocker = "Снимает лимит кадров Roblox (работает только в среде с функцией setfpscap).",
    HideHats = "Прячет шапки и аксессуары на головах у всех игроков (только на вашем экране).",
    HoloSelf = "Делает вашего персонажа полупрозрачной голограммой.",
    ImpulseStutters = "Гасит очень сильные толчки, чтобы персонажа не швыряло от отбрасывания.",
    AimWallCheck = "Не целиться в игроков, которые закрыты стеной.",
    TriggerWallCheck = "Если включено, выстрел не произойдёт, пока цель закрыта стеной.",
    AimTeamCheck = "Не целиться в игроков из вашей команды.",
    SkyOn = "Заменяет небо на ваши картинки. Время суток на скайбокс не влияет: небо остаётся тем же днём и ночью.",
    SkyIds = "Один ID картинки на все грани или шесть ID через запятую в порядке Bk, Dn, Ft, Lf, Rt, Up (зад, низ, перед, лево, право, верх).",
    SkyHideBodies = "Солнце, луна и звёзды привязаны ко времени суток и рисуются поверх неба. Выключите их, чтобы свой скайбокс выглядел одинаково в любое время."
}

M.State = {
    Language = "RU",
    MenuOpen = false,

    AimAssist = false, AimFov = 150, ShowFov = false, AimTime = 50, AimWallCheck = true, AimTeamCheck = true,
    TriggerAssist = false, TriggerLoop = false, TriggerDelay = 0.05, TriggerWallCheck = true, TriggerTeamCheck = true,

    Levitation = false, PhaseCollision = false, Esp = false, EspOnSelf = false, EspTeamCheck = false, Speed = false, AirVault = false, NetworkAlive = false, StateForce = false,
    KinematicBoost = 55, SprintSpeed = 45,
    ImpulseStutters = false,
    AirVectoring = false, AirSpeed = 150, AirAccel = 8,

    CamFov = 70, ThirdPerson = false, ThirdPersonDist = 12,

    RotationYaw = false, YawSpeed = 25, JitterSpin = false, PitchModification = false, PitchAngle = -60,
    PacketChoke = false, LagTicks = 16, LagLimit = 0.2,
    BacktrackShadows = true, GhostMat = "Neon", GhostCount = 3, GhostAlpha = 0.45, GhostCol = Color3.fromRGB(160, 50, 255),

    FpsBoost = false, FpsUnlocker = false,

    MainBg = Color3.fromRGB(15, 17, 23), MenuAlpha = 0,
    SideBg = Color3.fromRGB(10, 12, 16), SideAlpha = 0,
    CardBg = Color3.fromRGB(22, 25, 33), CardAlpha = 0.15,
    SideCardBg = Color3.fromRGB(16, 19, 26), SideCardAlpha = 0.2,
    Accent = Color3.fromRGB(48, 209, 88),
    BorderCol = Color3.fromRGB(45, 52, 70), BorderThick = 1,
    LogoCol = Color3.fromRGB(255, 255, 255),
    AnimSpeed = 0.22,

    PillBg = Color3.fromRGB(15, 17, 23), PillAlpha = 0.15, PillTextCol = Color3.fromRGB(255, 255, 255),
    PillBorderCol = Color3.fromRGB(45, 52, 70), PillBorderThick = 1,
    PillScaleVal = 1.0,
    PillShowUser = true, PillShowMem = true, PillShowTime = true, PillShowMinsk = true,
    PillLocked = false,

    EspBox = true,
    EspBoxCol = Color3.fromRGB(255, 255, 255),
    EspBoxThick = 1.5,
    EspFill = Color3.fromRGB(48, 209, 88),
    EspLine = Color3.fromRGB(255, 255, 255),
    EspAlpha = 0.4,
    EspNameCol = Color3.fromRGB(255, 255, 255), EspNameOutCol = Color3.fromRGB(0, 0, 0),
    EspFontWeight = "Bold", EspTextSize = 13,

    EspHealthBar = true,
    EspHealthPos = "Left",
    EspHealthText = true,
    EspHealthCol = Color3.fromRGB(48, 209, 88),
    EspHealthBarThick = 4,

    EspTracers = false,
    TracerCol = Color3.fromRGB(48, 209, 88),

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

    TimeOn = false, OrigTime = 14, CustomTime = 14.5,
    MeteorOn = false, MeteorRate = 3, MeteorSize = 3.5, MeteorTrailLen = 1.8, MeteorDuration = 2.5, MeteorColor = Color3.fromRGB(255, 140, 40),
    LightningOn = false, LightningRate = 3, LightningSize = 0.8, LightningDuration = 0.7,

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
    HatOn = false, HatSize = 1.1, HatHeight = 0.75, HatGlow = 1.5, HatColor = Color3.fromRGB(0, 210, 255),

    Uptime = 0, ActiveTab = "Combat", SelectedCfg = "default",
    Highlights = {}, EspGuis = {}, OrbitObjs = {}, HatModel = nil, PlayerConns = {},
    WeatherPool = {}, GhostPool = {}, BacktrackHistory = {}, OrigC0Cache = {},
    Cards = {}, SideCards = {}, Sliders = {}, Binds = {}, Pages = {}, TabButtons = {},
    ListeningBind = nil, CurFPS = 60, TabSwitching = false, IsUninjected = false,
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
    MatMap = {
        ["ForceField"] = Enum.Material.ForceField,
        ["Neon"] = Enum.Material.Neon,
        ["SmoothPlastic"] = Enum.Material.SmoothPlastic,
        ["Glass"] = Enum.Material.Glass
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
    LagTicks = 0,
    LastPacketTime = os.clock(),
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
    NoclipOrig = setmetatable({}, {__mode = "k"}),
    VisualOrig = setmetatable({}, {__mode = "k"}),

    -- Что было в игре до наших изменений (чтобы красиво вернуть при выключении)
    AtmoBackup = {},
    CloudBackup = nil,
    OrigCameraMode = nil,
    FovForced = false,
    Importing = false,
    MenuToken = 0,
    OrigAmbient = nil,
    OrigGlobalShadows = nil,
    OrigFov = 70,
    OrigZoomMin = 0.5,
    OrigZoomMax = 128,

    -- Флаги "мы это сейчас применяем", чтобы восстанавливать ровно один раз
    FogApplied = false,
    DarkApplied = false,
    PitchDirty = false,
    SpinDirty = false,
    StateForceApplied = false,
    TPApplied = false,
    HatsHidden = false,
    HoloApplied = false,

    AfkConn = nil,
    LastVisual = 0,
    FpsBoostToken = 0,
    FpsBoostConn = nil,
    FpsWarned = false,
    OwnFolderSet = {},
    Debounce = {},

    -- Свой скайбокс
    SkyFaces = {"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp"},
    SkyBackup = nil,   -- что было у Sky игры до нас
    SkyWanted = nil,   -- последние корректно разобранные 6 граней
    SkyOkKey = "Sky_Ok1",
    SkyToken = 0,
    LastSkyCheck = 0,
    SkyStatus = nil
}

M.UI = { Esp2DParts = {} }
M.CFG = {}
M.F = {}

-- ==============================================================================
-- [ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ]
-- ==============================================================================

-- Запоминаем соединение, чтобы Uninject смог его отключить
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
        if M.Data.Debounce[key] == token and not M.State.IsUninjected then
            fn()
        end
    end)
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
        M.Data.OrigFov = cam0.FieldOfView
        M.State.CamFov = math.clamp(math.round(cam0.FieldOfView), 30, 120)
    end
end

function M.Translate(key)
    local item = M.L10N.Dict[key]
    if item then return item[M.L10N.Current] or item["RU"] end
    return key
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

function M.UpdateRaycast()
    local ignore = {
        M.UI.wFolder,
        M.UI.kFolder,
        M.UI.lFolder,
        M.UI.mFolder,
        M.UI.vFolder,
        M.UI.cCache,
        M.UI.gFolder,
        M.UI.jFolder
    }
    local char = M.LP and M.LP.Character
    if char then
        table.insert(ignore, char)
    end
    M.RayParams.FilterDescendantsInstances = ignore
end

M.UI.wFolder = Instance.new("Folder", workspace); M.UI.wFolder.Name = "MatsysenseWeatherProps"
M.UI.kFolder = Instance.new("Folder", workspace); M.UI.kFolder.Name = "MatsysenseKillFX"
M.UI.lFolder = Instance.new("Folder", workspace); M.UI.lFolder.Name = "MatsysenseLightnings"
M.UI.mFolder = Instance.new("Folder", workspace); M.UI.mFolder.Name = "MatsysenseMeteors"
M.UI.vFolder = Instance.new("Folder", workspace); M.UI.vFolder.Name = "MatsysenseVisuals"
M.UI.cCache = Instance.new("Folder", workspace); M.UI.cCache.Name = "MatsysenseClothCache"
M.UI.gFolder = Instance.new("Folder", workspace); M.UI.gFolder.Name = "MatsysenseGhostCache"
M.UI.jFolder = Instance.new("Folder", workspace); M.UI.jFolder.Name = "MatsysenseJumpRings"
for _, folder in ipairs({M.UI.wFolder, M.UI.kFolder, M.UI.lFolder, M.UI.mFolder, M.UI.vFolder, M.UI.cCache, M.UI.gFolder, M.UI.jFolder}) do
    M.Data.OwnFolderSet[folder] = true
end
M.UpdateRaycast()

function M.CacheJoints(char)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("Motor6D") and (v.Name == "RootJoint" or v.Name == "Root" or v.Name == "Waist" or v.Name == "Neck") then
            if not M.State.OrigC0Cache[v] then
                M.State.OrigC0Cache[v] = v.C0
            end
        end
    end
end

function M.ClearGhosts()
    for _, m in ipairs(M.State.GhostPool) do
        if m and m.Parent then m:Destroy() end
    end
    M.State.GhostPool = {}
    M.State.BacktrackHistory = {}
end

function M.TakeSnapshot(char)
    local snap = {}
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and M.Data.ValidLimbs[p.Name] and not p:FindFirstAncestorOfClass("Accessory") then
            snap[p.Name] = {CFrame = p.CFrame, Size = p.Size}
        end
    end
    return snap
end

function M.UpdateBacktrack()
    local char = M.LP and M.LP.Character
    if not M.State.BacktrackShadows or not char or not char:FindFirstChild("HumanoidRootPart") then
        if #M.State.GhostPool > 0 then M.ClearGhosts() end
        return
    end

    table.insert(M.State.BacktrackHistory, 1, M.TakeSnapshot(char))
    local maxLimit = math.clamp(math.floor(M.State.GhostCount), 1, 5)
    while #M.State.BacktrackHistory > maxLimit do
        table.remove(M.State.BacktrackHistory)
    end

    local mat = M.Data.MatMap[M.State.GhostMat] or Enum.Material.Neon
    for i = 1, maxLimit do
        local snap = M.State.BacktrackHistory[i]
        local model = M.State.GhostPool[i]

        if snap then
            if not model or not model.Parent then
                model = Instance.new("Model")
                model.Name = "BacktrackGhost_" .. i
                model.Parent = M.UI.gFolder
                M.State.GhostPool[i] = model
            end
            local a = math.clamp(M.State.GhostAlpha + ((1 - M.State.GhostAlpha) * ((i - 1) / math.max(maxLimit, 1)) * 0.45), 0.05, 0.98)
            for name, data in pairs(snap) do
                local p = model:FindFirstChild(name)
                if not p then
                    p = Instance.new("Part")
                    p.Name = name
                    p.CanCollide = false
                    p.CanTouch = false
                    p.CanQuery = false
                    p.CastShadow = false
                    p.Anchored = true
                    p.Parent = model
                end
                p.Size = data.Size
                p.CFrame = data.CFrame
                p.Material = mat
                p.Color = M.State.GhostCol
                p.Transparency = a
            end
        elseif model then
            model:Destroy()
            M.State.GhostPool[i] = nil
        end
    end
end

function M.SpawnJumpRing(originPos)
    if not M.State.JumpRings or not originPos then return end
    local ray = workspace:Raycast(originPos, Vector3.new(0, -12, 0), M.RayParams)
    local hitPos = ray and ray.Position or (originPos - Vector3.new(0, 3, 0))
    local hitNorm = ray and ray.Normal or Vector3.new(0, 1, 0)

    local ringModel = Instance.new("Model")
    ringModel.Name = "JumpRingEffect"
    ringModel.Parent = M.UI.jFolder

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

function M.BindAntiRagdoll(char)
    for _, conn in ipairs(M.Data.CharConns) do
        if conn then conn:Disconnect() end
    end
    M.Data.CharConns = {}
    if not char then return end

    local h = char:WaitForChild("Humanoid", 4)
    local r = char:WaitForChild("HumanoidRootPart", 4)
    if not h or not r then return end

    table.insert(M.Data.CharConns, h.StateChanged:Connect(function(_, newState)
        if h.Health <= 0 then return end
        if newState == Enum.HumanoidStateType.Jumping and M.State.JumpRings then
            M.SpawnJumpRing(r.Position)
        end
        if M.State.StateForce and not M.State.IsDead and not M.State.Levitation then
            if newState == Enum.HumanoidStateType.Ragdoll or newState == Enum.HumanoidStateType.FallingDown or newState == Enum.HumanoidStateType.Physics or newState == Enum.HumanoidStateType.PlatformStanding then
                h:ChangeState(Enum.HumanoidStateType.GettingUp)
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
                task.defer(function()
                    if h and not M.State.Levitation and h.Health > 0 then
                        h:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end)
            end
        end
    end))

    table.insert(M.Data.CharConns, char.DescendantAdded:Connect(function(desc)
        if M.State.StateForce and h.Health > 0 then
            if desc:IsA("BallSocketConstraint") or desc:IsA("HingeConstraint") or (desc:IsA("Constraint") and desc.Name:lower():find("ragdoll")) then
                task.defer(function() if desc and desc.Parent then desc:Destroy() end end)
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
                if part.Color ~= M.State.HoloColor then part.Color = M.State.HoloColor end
                if part.Transparency ~= M.State.HoloAlpha then part.Transparency = M.State.HoloAlpha end
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

function M.ApplyFpsBoost(enabled)
    M.State.FpsBoost = enabled
    M.Data.FpsBoostToken = M.Data.FpsBoostToken + 1
    local token = M.Data.FpsBoostToken

    if M.Data.FpsBoostConn then
        M.Data.FpsBoostConn:Disconnect()
        M.Data.FpsBoostConn = nil
    end

    local function boost(obj)
        if obj:IsA("Terrain") then return end
        if obj:IsA("BasePart") then
            if M.Data.OriginalMaterials[obj] == nil then
                M.Data.OriginalMaterials[obj] = obj.Material
            end
            obj.Material = Enum.Material.SmoothPlastic
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            if M.Data.TextureCache[obj] == nil then
                M.Data.TextureCache[obj] = obj.Transparency
            end
            obj.Transparency = 1
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
            if M.Data.EmitterCache[obj] == nil then
                M.Data.EmitterCache[obj] = obj.Enabled
            end
            obj.Enabled = false
        end
    end

    if enabled then
        M.Services.L.GlobalShadows = false
        -- Новые объекты, появившиеся уже после включения, тоже упрощаем
        M.Data.FpsBoostConn = workspace.DescendantAdded:Connect(function(obj)
            if not M.IsOwned(obj) then boost(obj) end
        end)

        -- Идём по карте кусками, чтобы игра не зависала на больших картах
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
        for obj, mat in pairs(M.Data.OriginalMaterials) do
            if obj.Parent then obj.Material = mat end
        end
        for obj, trans in pairs(M.Data.TextureCache) do
            if obj.Parent then obj.Transparency = trans end
        end
        for obj, wasEnabled in pairs(M.Data.EmitterCache) do
            if obj.Parent then obj.Enabled = wasEnabled end
        end
        table.clear(M.Data.OriginalMaterials)
        table.clear(M.Data.TextureCache)
        table.clear(M.Data.EmitterCache)
        M.Services.L.GlobalShadows = M.Data.OrigGlobalShadows
    end
end

function M.ApplyFpsUnlocker(enabled)
    M.State.FpsUnlocker = enabled
    local capFn = setfpscap or set_fps_cap
    if capFn then
        pcall(capFn, enabled and 9999 or 60)
    elseif enabled and not M.Data.FpsWarned then
        -- В обычном Roblox Studio нельзя поменять лимит кадров из скрипта.
        -- Раньше тут молча меняли качество графики, что вводило в заблуждение.
        M.Data.FpsWarned = true
        warn("[Matsysense] FPS Unlocker не работает: в этой среде нет функции setfpscap.")
    end
end

function M.OnCharacterAdded(newChar)
    if not newChar then return end
    task.spawn(function()
        newChar:WaitForChild("HumanoidRootPart", 5)
        newChar:WaitForChild("Humanoid", 5)
        if M.State.IsUninjected or M.LP.Character ~= newChar then return end

        -- Новый персонаж = новые детали, поэтому "применено" сбрасываем
        M.State.OrigC0Cache = {}
        table.clear(M.Data.NoclipOrig)
        table.clear(M.Data.VisualOrig)
        M.Data.PitchDirty = false
        M.Data.SpinDirty = false
        M.Data.StateForceApplied = false
        M.Data.HoloApplied = false

        M.CacheJoints(newChar)
        M.BindAntiRagdoll(newChar)
        M.UpdateRaycast()
        M.UpdatePlayerVisuals()
        if M.State.OrbitOn then M.F.RebuildOrbits() end
        if M.State.HatOn then M.F.RebuildWireHat() end
        if M.State.PhaseCollision then M.F.SetNoclip(true) end
        if M.State.Levitation then M.F.StartFlying() end
    end)
end

if M.LP and M.LP.Character then M.OnCharacterAdded(M.LP.Character) end
table.insert(M.Data.Conns, M.LP.CharacterAdded:Connect(M.OnCharacterAdded))

function M.TargetVisibility(targetPart)
    local cam = workspace.CurrentCamera
    if not cam or not targetPart then return false end
    local origin = cam.CFrame.Position
    local dir = targetPart.Position - origin
    local res = workspace:Raycast(origin, dir, M.RayParams)
    return not (res and res.Instance and not res.Instance:IsDescendantOf(targetPart.Parent))
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
    local bestTarget = nil
    local minDelta = math.huge

    for _, p in ipairs(M.Services.P:GetPlayers()) do
        if p ~= M.LP and p.Character then
            local targetHum = p.Character:FindFirstChildOfClass("Humanoid")
            local head = p.Character:FindFirstChild("Head")
            if targetHum and targetHum.Health > 0 and head then
                if not (M.State.AimTeamCheck and M.IsTeammate(p)) then
                    local pos, onScreen = cam:WorldToViewportPoint(head.Position)
                    if onScreen and pos.Z > 0 then
                        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if dist <= M.State.AimFov and dist < minDelta then
                            if not M.State.AimWallCheck or M.TargetVisibility(head) then
                                minDelta = dist
                                bestTarget = head
                            end
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

local function IsAliveModel(model)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

-- Ищет цель под центром экрана.
-- TriggerWallCheck включён: цель считается только если луч дошёл до неё без преград.
-- Выключен: стены игнорируются (луч проверяется отдельно для каждого игрока).
function M.GetTriggerTarget(cam)
    local center = cam.ViewportSize / 2
    local ray = cam:ViewportPointToRay(center.X, center.Y)
    local direction = ray.Direction * 2000

    if M.State.TriggerWallCheck then
        local result = workspace:Raycast(ray.Origin, direction, M.RayParams)
        local model = result and M.GetCharacterFromPart(result.Instance)
        local owner = model and M.Services.P:GetPlayerFromCharacter(model)
        if owner and owner ~= M.LP and IsAliveModel(model) and not (M.State.TriggerTeamCheck and M.IsTeammate(owner)) then
            return model
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
                return ch
            end
        end
    end
    return nil
end

-- Один "выстрел": если в руках Tool - активируем его, иначе имитируем клик.
-- Раньше делались ОБА действия сразу, и оружие стреляло дважды.
function M.F.FireTrigger()
    if M.State.TriggerDelay > 0 then task.wait(M.State.TriggerDelay) end
    local char = M.LP and M.LP.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        tool:Activate()
    else
        M.Services.V:Button1Down(Vector2.zero)
        task.wait(0.02)
        M.Services.V:Button1Up(Vector2.zero)
    end
    task.wait(0.06)
end

-- Защита от падений: состояния отключаем ОДИН раз и возвращаем, когда функцию выключили
function M.F.UpdateStateForce()
    local char = M.LP and M.LP.Character
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local want = M.State.StateForce and h ~= nil and h.Health > 0
    if want then
        if not M.State.Levitation and h.PlatformStand then h.PlatformStand = false end
        if not M.Data.StateForceApplied then
            M.Data.StateForceApplied = true
            h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end
    elseif M.Data.StateForceApplied then
        M.Data.StateForceApplied = false
        if h then
            h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end
    end
end

-- Вид от третьего лица: свои настройки камеры включаем один раз и возвращаем при выключении.
-- Раньше лимиты зума перезаписывались КАЖДЫЙ кадр, даже когда функция была выключена.
function M.F.UpdateThirdPerson(cam, hrp, h, active)
    if active and hrp and h then
        if not M.Data.TPApplied then
            M.Data.TPApplied = true
            M.Data.OrigCameraMode = M.LP.CameraMode
            M.Data.OrigZoomMin = M.LP.CameraMinZoomDistance
            M.Data.OrigZoomMax = M.LP.CameraMaxZoomDistance
            M.LP.CameraMode = Enum.CameraMode.Classic
        end
        local dist = M.State.ThirdPersonDist
        if M.LP.CameraMaxZoomDistance ~= dist or M.LP.CameraMinZoomDistance ~= dist then
            M.LP.CameraMinZoomDistance = math.min(dist, M.LP.CameraMinZoomDistance)
            M.LP.CameraMaxZoomDistance = dist
            M.LP.CameraMinZoomDistance = dist
        end
        if not M.State.MenuOpen then
            M.Services.U.MouseBehavior = Enum.MouseBehavior.LockCenter
            if h.AutoRotate then h.AutoRotate = false end
            local _, ry, _ = cam.CFrame:ToOrientation()
            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, ry, 0)
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

-- ==============================================================================
-- [ CAMERA AIM-ASSIST & FOV PIPELINE ]
-- ==============================================================================
pcall(function() M.Services.R:UnbindFromRenderStep("MatsysenseCameraProcessor") end)
M.Services.R:BindToRenderStep("MatsysenseCameraProcessor", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if M.State.IsUninjected then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    -- FOV насильно держим только если пользователь сам его менял (иначе не мешаем игре)
    if M.Data.FovForced then
        local targetFov = math.clamp(M.State.CamFov, 30, 120)
        if cam.FieldOfView ~= targetFov then
            cam.FieldOfView = targetFov
        end
    end

    local char = M.LP and M.LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local isAlive = (hum and hum.Health > 0)

    if M.State.AimAssist and not M.State.MenuOpen and isAlive then
        local target = M.GetClosestTarget()
        if target then
            local currentCamCF = cam.CFrame
            local dir = (target.Position - currentCamCF.Position).Unit
            local targetCamCF = CFrame.lookAt(currentCamCF.Position, currentCamCF.Position + dir, Vector3.new(0, 1, 0))
            local factor = (M.State.AimTime <= 0) and 1 or math.clamp(dt / (M.State.AimTime / 1000), 0.05, 1)
            cam.CFrame = currentCamCF:Lerp(targetCamCF, factor)
        end
    end
end)

-- ==============================================================================
-- [ ESP DISPLAY INTERFACE ]
-- ==============================================================================
M.UI.EspGui = Instance.new("ScreenGui")
M.UI.EspGui.Name = "MatsysenseESP"
M.UI.EspGui.ResetOnSpawn = false
M.UI.EspGui.DisplayOrder = 100
M.UI.EspGui.IgnoreGuiInset = true
M.UI.EspGui.Parent = M.TargetGui

M.UI.FovCircle = Instance.new("Frame")
M.UI.FovCircle.Name = "AimFovCircle"
M.UI.FovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
M.UI.FovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
M.UI.FovCircle.BackgroundTransparency = 1
M.UI.FovCircle.Visible = false
M.UI.FovCircle.Parent = M.UI.EspGui
Instance.new("UICorner", M.UI.FovCircle).CornerRadius = UDim.new(1, 0)

M.UI.FovStroke = Instance.new("UIStroke", M.UI.FovCircle)
M.UI.FovStroke.Color = Color3.fromRGB(255, 255, 255)
M.UI.FovStroke.Thickness = 1
M.UI.FovStroke.Transparency = 0.7

function M.F.SetupEsp(p)
    local function initChar(char)
        if not char then return end
        local isSelf = (p == M.LP)

        -- Ждём Humanoid ДО создания рамок: при быстром респавне старые рамки раньше "терялись"
        local hum = char:WaitForChild("Humanoid", 10)
        if p.Character ~= char or not p.Parent then return end

        if M.State.Highlights[p] and M.State.Highlights[p].Parent then 
            M.State.Highlights[p]:Destroy() 
        end
        if M.State.EspGuis[p] and M.State.EspGuis[p].Container and M.State.EspGuis[p].Container.Parent then 
            M.State.EspGuis[p].Container:Destroy() 
        end
        if M.State.EspGuis[p] and M.State.EspGuis[p].TracerLine and M.State.EspGuis[p].TracerLine.Parent then
            M.State.EspGuis[p].TracerLine:Destroy()
        end

        local hl = Instance.new("Highlight")
        hl.Name = "MatsysenseHL"
        hl.Adornee = char
        hl.FillColor = M.State.EspFill
        hl.FillTransparency = M.State.EspAlpha
        hl.OutlineColor = M.State.EspLine
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
        M.State.Highlights[p] = hl

        local boxContainer = Instance.new("Frame")
        boxContainer.Name = "BOX_" .. p.Name
        boxContainer.BackgroundTransparency = 1
        boxContainer.BorderSizePixel = 0
        boxContainer.Visible = false
        boxContainer.Parent = M.UI.EspGui

        local bStroke = Instance.new("UIStroke", boxContainer)
        bStroke.Color = M.State.EspBoxCol
        bStroke.Thickness = M.State.EspBoxThick

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Name = "NL"
        nameLbl.Size = UDim2.new(1, 40, 0, 16)
        nameLbl.AnchorPoint = Vector2.new(0.5, 1)
        nameLbl.Position = UDim2.new(0.5, 0, 0, -4)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = (isSelf and "[ВЫ] " or "") .. p.DisplayName
        nameLbl.TextColor3 = M.State.EspNameCol
        nameLbl.TextStrokeColor3 = M.State.EspNameOutCol
        nameLbl.TextStrokeTransparency = 0
        nameLbl.Font = (M.State.EspFontWeight == "Bold") and Enum.Font.GothamBold or Enum.Font.GothamMedium
        nameLbl.TextSize = M.State.EspTextSize
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
        tracer.Name = "TRACER_" .. p.Name
        tracer.AnchorPoint = Vector2.new(0.5, 0.5)
        tracer.BackgroundColor3 = M.State.TracerCol
        tracer.BorderSizePixel = 0
        tracer.Visible = false
        tracer.Parent = M.UI.EspGui

        M.State.EspGuis[p] = {
            Container = boxContainer,
            Stroke = bStroke,
            NameLabel = nameLbl,
            BarBg = barBg,
            BarFill = barFill,
            HpLabel = hpLbl,
            TracerLine = tracer,
            Char = char,
            Hum = hum,
            IsSelf = isSelf,
            Player = p
        }
        M.F.UpdateEsp()
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
        M.UI.PrevDummyTag.TextColor3 = M.State.EspNameCol
        M.UI.PrevDummyTag.TextStrokeColor3 = M.State.EspNameOutCol
        M.UI.PrevDummyTag.Font = (M.State.EspFontWeight == "Bold") and Enum.Font.GothamBold or Enum.Font.GothamMedium
        M.UI.PrevDummyTag.TextSize = M.State.EspTextSize
    end

    for _, f in ipairs(M.UI.Esp2DParts) do
        f.BackgroundColor3 = M.State.EspFill
        f.BackgroundTransparency = M.State.EspAlpha
        local strk = f:FindFirstChildOfClass("UIStroke")
        if strk then
            strk.Color = M.State.EspBoxCol
            strk.Thickness = M.State.EspBoxThick
        end
    end

    if M.UI.PrevHealthPack then
        local pack = M.UI.PrevHealthPack
        local isH = (M.State.EspHealthPos == "Bottom")
        local tSize = M.State.EspHealthBarThick

        pack.BarBg.Visible = M.State.EspHealthBar
        pack.HpLabel.Visible = M.State.EspHealthText

        if isH then
            pack.BarBg.Size = UDim2.new(1, 0, 0, tSize)
            pack.BarBg.Position = UDim2.new(0, 0, 1, 4)
            pack.BarFill.Size = UDim2.new(0.75, 0, 1, 0)
            pack.BarFill.Position = UDim2.new(0, 0, 0, 0)
            pack.HpLabel.Position = UDim2.new(0.5, 0, 1, tSize + 4)
            pack.HpLabel.AnchorPoint = Vector2.new(0.5, 0)
        elseif M.State.EspHealthPos == "Right" then
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

        pack.BarFill.BackgroundColor3 = M.State.EspHealthCol
        pack.HpLabel.Text = "100 HP"
        pack.HpLabel.TextColor3 = M.State.EspHealthCol
    end
end

function M.F.UpdateEsp()
    for p, hl in pairs(M.State.Highlights) do
        if hl and hl.Parent then
            local isSelf = (p == M.LP)
            local allowed = M.State.Esp and (not isSelf or M.State.EspOnSelf)
            if M.State.EspTeamCheck and M.IsTeammate(p) and not isSelf then allowed = false end
            
            hl.Enabled = allowed
            hl.FillColor = M.State.EspFill
            hl.FillTransparency = M.State.EspAlpha
            hl.OutlineColor = M.State.EspLine
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        end
    end

    for _, pack in pairs(M.State.EspGuis) do
        if pack and pack.Container then
            local isSelf = pack.IsSelf
            local allowed = M.State.Esp and (not isSelf or M.State.EspOnSelf)
            if M.State.EspTeamCheck and not isSelf and M.IsTeammate(pack.Player) then allowed = false end
            
            pack.Container.Visible = allowed and M.State.EspBox
            pack.Stroke.Color = M.State.EspBoxCol
            pack.Stroke.Thickness = M.State.EspBoxThick

            pack.NameLabel.TextColor3 = M.State.EspNameCol
            pack.NameLabel.TextStrokeColor3 = M.State.EspNameOutCol
            pack.NameLabel.Font = (M.State.EspFontWeight == "Bold") and Enum.Font.GothamBold or Enum.Font.GothamMedium
            pack.NameLabel.TextSize = M.State.EspTextSize

            if pack.TracerLine then
                pack.TracerLine.BackgroundColor3 = M.State.TracerCol
            end
        end
    end
    M.F.Update2DPreview()
end

for _, p in ipairs(M.Services.P:GetPlayers()) do M.F.SetupEsp(p) end
table.insert(M.Data.Conns, M.Services.P.PlayerAdded:Connect(M.F.SetupEsp))
table.insert(M.Data.Conns, M.Services.P.PlayerRemoving:Connect(function(p)
    if M.State.Highlights[p] and M.State.Highlights[p].Parent then M.State.Highlights[p]:Destroy() end
    M.State.Highlights[p] = nil
    if M.State.EspGuis[p] then
        if M.State.EspGuis[p].Container and M.State.EspGuis[p].Container.Parent then M.State.EspGuis[p].Container:Destroy() end
        if M.State.EspGuis[p].TracerLine and M.State.EspGuis[p].TracerLine.Parent then M.State.EspGuis[p].TracerLine:Destroy() end
    end
    M.State.EspGuis[p] = nil
    if M.State.PlayerConns[p] then M.State.PlayerConns[p]:Disconnect(); M.State.PlayerConns[p] = nil end
end))

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
            p.Anchored = true; p.Material = Enum.Material.Neon; p.Parent = M.UI.wFolder

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

function M.F.StrikeLightning()
    local cam = workspace.CurrentCamera
    local char = M.LP and M.LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local origin = (root and root.Position) or (cam and cam.CFrame.Position)
    if not origin then return end

    local dist = math.random(80, 400)
    local angle = math.rad(math.random(0, 360))
    local strikeGround = origin + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
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

    bolt.Parent = M.UI.lFolder

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
    local originPos = (char and char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position) or (cam and cam.CFrame.Position)
    if not originPos then return end

    local dist = math.random(300, 700)
    local angle = math.rad(math.random(0, 360))
    -- Высота прибавляется к позиции игрока один раз (раньше Y игрока учитывался дважды)
    local startPos = originPos + Vector3.new(math.cos(angle) * dist, math.random(220, 420), math.sin(angle) * dist)
    local dropAngle = math.rad(math.random(25, 40))
    local flyDir = (Vector3.new(math.sin(angle + math.pi), -math.tan(dropAngle), math.cos(angle + math.pi))).Unit
    local travelLen = math.clamp(dist * 1.7, 500, 1400)
    local endPos = startPos + (flyDir * travelLen)

    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(M.State.MeteorSize, M.State.MeteorSize, M.State.MeteorSize)
    p.Material = Enum.Material.Neon; p.Color = M.State.MeteorColor
    -- Anchored обязателен: иначе гравитация тянет метеорит вниз и спорит с анимацией полёта
    p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
    p.CFrame = CFrame.new(startPos); p.Parent = M.UI.mFolder

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

    local tw = M.Services.T:Create(p, TweenInfo.new(M.State.MeteorDuration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(endPos)})
    tw:Play(); tw.Completed:Connect(function() p:Destroy() end)
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
        p.Material = Enum.Material.Neon; p.Color = pCol; p.CanCollide = false; p.CastShadow = false; p.Anchored = true; p.Parent = M.UI.vFolder

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

    local model = Instance.new("Model"); model.Name = "WireHat"; model.Parent = M.UI.vFolder
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
            M.Services.L.ExposureCompensation = -M.State.DarkIntensity * 3.5
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
        local ours = L:FindFirstChild("MatsysenseAtmosphere")

        if M.State.FogOn then
            M.Data.FogApplied = true
            if not ours then
                ours = Instance.new("Atmosphere")
                ours.Name = "MatsysenseAtmosphere"
                ours.Parent = L
            end
            ours.Density = math.clamp(M.State.FogDensity, 0.05, 0.99)
            ours.Offset = 0.0
            ours.Haze = math.clamp(M.State.FogHaze, 0, 10)
            ours.Color = M.State.FogColor
            ours.Decay = M.State.FogColor
            ours.Glare = 0.0

            for _, child in ipairs(L:GetChildren()) do
                if child:IsA("Atmosphere") and child ~= ours then
                    if M.Data.AtmoBackup[child] == nil then
                        M.Data.AtmoBackup[child] = child.Density
                    end
                    child.Density = 0
                end
            end

            L.FogStart = 0
            L.FogEnd = math.clamp(320 - (M.State.FogDensity * 280), 10, 500)
            L.FogColor = M.State.FogColor
            local ambient = M.State.FogColor:Lerp(Color3.fromRGB(15, 15, 15), 0.35)
            L.OutdoorAmbient = ambient
            L.Ambient = ambient
        elseif M.Data.FogApplied then
            -- Возвращаем всё как было ровно один раз
            M.Data.FogApplied = false
            if ours then ours:Destroy() end
            for atmo, density in pairs(M.Data.AtmoBackup) do
                if atmo.Parent then atmo.Density = density end
            end
            table.clear(M.Data.AtmoBackup)
            L.FogStart = M.State.OrigFogStart
            L.FogEnd = M.State.OrigFogEnd
            L.FogColor = M.State.OrigFogColor
            L.OutdoorAmbient = M.State.OrigOutdoorAmb
            -- Раньше Ambient никогда не возвращался
            L.Ambient = M.Data.OrigAmbient
        end
    end)
end

-- Облака: если в игре уже есть Clouds, меняем их и запоминаем исходные значения (вернём при выключении).
-- Если нет - создаём свои и удаляем при выключении.
-- ==============================================================================
-- [ CUSTOM SKYBOX ]
-- Не зависит от Lighting.ClockTime, поэтому не конфликтует с функцией "Свое время суток".
-- Время меняет только освещение, а картинки неба остаются нашими.
-- Если игровой скрипт (например, смена дня и ночи) подменит текстуры, мы вернём свои.
-- ==============================================================================

function M.F.RenderSkyStatus()
    local label = M.UI.SkyStatusLabel
    local st = M.Data.SkyStatus
    if not label or not st then return end
    local text = M.Translate(st.Key)
    if st.Arg ~= nil then text = string.format(text, st.Arg) end
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

-- Разбирает строку с ID. Принимает "123456", "rbxassetid://123456" и ссылки со словом id=123456.
-- Возвращает: таблицу из 6 строк, ключ статуса, аргумент статуса.
function M.F.ParseSkyIds(text)
    local ids = {}
    for token in string.gmatch(text or "", "[^,;%s]+") do
        local digits = string.match(token, "%d+")
        if not digits or #digits < 5 or #digits > 19 then
            return nil, "Sky_BadId", string.sub(token, 1, 24)
        end
        table.insert(ids, "rbxassetid://" .. digits)
    end

    if #ids == 0 then return nil, "Sky_Idle", nil end
    if #ids == 1 then
        local one = ids[1]
        return {one, one, one, one, one, one}, "Sky_Ok1", nil
    end
    if #ids == 6 then return ids, "Sky_Ok6", nil end
    return nil, "Sky_BadCount", #ids
end

-- Находит Sky: сначала наш, потом игровой. Для игрового запоминаем исходные значения.
function M.F.AcquireSky()
    local L = M.Services.L
    local sky = L:FindFirstChild("MatsysenseSky") or L:FindFirstChildOfClass("Sky")
    if not sky then
        sky = Instance.new("Sky")
        sky.Name = "MatsysenseSky"
        sky.Parent = L
    end

    if sky.Name ~= "MatsysenseSky" then
        local backup = M.Data.SkyBackup
        if not backup or backup.Object ~= sky then
            backup = {Object = sky, CelestialBodiesShown = sky.CelestialBodiesShown, Faces = {}}
            for _, face in ipairs(M.Data.SkyFaces) do
                backup.Faces[face] = sky[face]
            end
            M.Data.SkyBackup = backup
        end
    end
    return sky
end

function M.F.RestoreSky()
    M.Data.SkyWanted = nil
    M.Data.SkyToken = M.Data.SkyToken + 1

    local ours = M.Services.L:FindFirstChild("MatsysenseSky")
    if ours then ours:Destroy() end

    local backup = M.Data.SkyBackup
    if backup and backup.Object and backup.Object.Parent then
        for face, value in pairs(backup.Faces) do
            backup.Object[face] = value
        end
        backup.Object.CelestialBodiesShown = backup.CelestialBodiesShown
    end
    M.Data.SkyBackup = nil
end

-- silent = true: тихая проверка раз в полсекунды (ничего не разбираем заново, статус не трогаем)
function M.F.ApplySky(silent)
    pcall(function()
        if not M.State.SkyOn then
            M.F.RestoreSky()
            if not silent then M.F.SetSkyStatus("Sky_Off", nil, "idle") end
            return
        end

        if not silent then
            local faces, info, arg = M.F.ParseSkyIds(M.State.SkyIds)
            if not faces then
                -- Неверный ввод: возвращаем обычное небо, чтобы не оставлять "старое" без ведома игрока
                M.F.RestoreSky()
                M.F.SetSkyStatus(info, arg, info == "Sky_Idle" and "idle" or "error")
                return
            end
            M.Data.SkyWanted = faces
            M.Data.SkyOkKey = info
        end

        local faces = M.Data.SkyWanted
        if not faces then return end

        local sky = M.F.AcquireSky()
        local changed = false

        for i, face in ipairs(M.Data.SkyFaces) do
            -- Сравниваем по цифрам ID: движок может записать ссылку в другом виде
            local current = string.match(tostring(sky[face]), "%d+")
            local wanted = string.match(faces[i], "%d+")
            if current ~= wanted then
                sky[face] = faces[i]
                changed = true
            end
        end

        local showBodies = not M.State.SkyHideBodies
        if sky.CelestialBodiesShown ~= showBodies then
            sky.CelestialBodiesShown = showBodies
        end

        if silent or not changed and M.Data.SkyStatus and M.Data.SkyStatus.Kind == "ok" then
            return
        end

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
            if token ~= M.Data.SkyToken or M.State.IsUninjected then return end
            if failed > 0 then
                M.F.SetSkyStatus("Sky_Fail", failed, "error")
            else
                M.F.SetSkyStatus(M.Data.SkyOkKey, nil, "ok")
            end
        end)
    end)
end

function M.F.ApplyClouds()
    pcall(function()
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if not terrain then return end

        local clouds = terrain:FindFirstChild("MatsysenseClouds") or terrain:FindFirstChildOfClass("Clouds")
        if M.State.CloudsOn then
            if not clouds then
                clouds = Instance.new("Clouds")
                clouds.Name = "MatsysenseClouds"
                clouds.Parent = terrain
            end
            if clouds.Name ~= "MatsysenseClouds" and not M.Data.CloudBackup then
                M.Data.CloudBackup = {
                    Object = clouds, Enabled = clouds.Enabled,
                    Density = clouds.Density, Cover = clouds.Cover, Color = clouds.Color
                }
            end
            clouds.Enabled = true
            clouds.Density = math.clamp(M.State.CloudDensity, 0.01, 1.0)
            clouds.Cover = math.clamp(M.State.CloudCover / 100, 0.0, 1.0)
            clouds.Color = M.State.CloudColor
        else
            local backup = M.Data.CloudBackup
            if clouds and clouds.Name == "MatsysenseClouds" then
                clouds:Destroy()
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
local function FindMotor(char, name)
    local obj = char:FindFirstChild(name, true)
    if obj and obj:IsA("Motor6D") then return obj end
    return nil
end

local function UpdateRigOrientation(dt)
    if M.State.IsUninjected then return end
    local char = M.LP and M.LP.Character
    if not char or not char.Parent then return end
    local h = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not h or h.Health <= 0 or not hrp then return end

    local wantPitch = M.State.PitchModification
    local wantSpin = M.State.RotationYaw and not M.State.Levitation
    -- Ничего не включено и нечего возвращать - не трогаем суставы вообще
    if not wantPitch and not wantSpin and not M.Data.PitchDirty and not M.Data.SpinDirty then return end

    local cache = M.State.OrigC0Cache
    local isR15 = (h.RigType == Enum.HumanoidRigType.R15)

    -- ГЛАВНЫЙ БАГ ВРАЩЕНИЯ: в R15 мотор "Root" лежит внутри LowerTorso, а не внутри HumanoidRootPart.
    -- Старый код искал его только в HumanoidRootPart, находил nil, и персонаж не крутился.
    local rootMotor = FindMotor(char, "RootJoint") or FindMotor(char, "Root")
    local waistMotor = FindMotor(char, "Waist")
    local neckMotor = FindMotor(char, "Neck")

    for _, motor in ipairs({rootMotor, waistMotor, neckMotor}) do
        if motor and not cache[motor] then cache[motor] = motor.C0 end
    end

    if wantPitch then
        M.Data.PitchDirty = true
        local pRad = math.rad(M.State.PitchAngle)
        if isR15 then
            if waistMotor then waistMotor.C0 = cache[waistMotor] * CFrame.Angles(pRad * 0.65, 0, 0) end
            if neckMotor then neckMotor.C0 = cache[neckMotor] * CFrame.Angles(pRad * 0.35, 0, 0) end
        elseif neckMotor then
            neckMotor.C0 = cache[neckMotor] * CFrame.Angles(pRad, 0, 0)
        end
    elseif M.Data.PitchDirty then
        M.Data.PitchDirty = false
        if waistMotor and cache[waistMotor] then waistMotor.C0 = cache[waistMotor] end
        if neckMotor and cache[neckMotor] then neckMotor.C0 = cache[neckMotor] end
    end

    if wantSpin and rootMotor then
        M.Data.SpinDirty = true
        local spd = M.State.YawSpeed
        if M.State.JitterSpin then
            spd = spd + math.random(-25, 25)
        end
        M.Data.SpinAngle = (M.Data.SpinAngle + (spd * dt * 25)) % 360
        local yRad = math.rad(M.Data.SpinAngle)

        if isR15 then
            rootMotor.C0 = cache[rootMotor] * CFrame.Angles(0, yRad, 0)
        else
            rootMotor.C0 = cache[rootMotor] * CFrame.Angles(0, 0, -yRad)
        end
    elseif M.Data.SpinDirty then
        M.Data.SpinDirty = false
        if rootMotor and cache[rootMotor] then rootMotor.C0 = cache[rootMotor] end
    end
end

table.insert(M.Data.Conns, M.Services.R.Stepped:Connect(function(_, dt)
    UpdateRigOrientation(dt)
end))

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

M.F.StartFlying = function()
    M.State.Levitation = true
    local char = M.LP and M.LP.Character
    if char then
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = true end
    end
end

M.F.StopFlying = function()
    M.State.Levitation = false
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
    if M.State.AirVault and not M.State.Levitation then
        h:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

-- Защита от АФК: когда Roblox считает игрока бездействующим, отправляем "виртуальный клик"
M.F.SetAntiAfk = function(on)
    if M.Data.AfkConn then M.Data.AfkConn:Disconnect(); M.Data.AfkConn = nil end
    if not on then return end
    M.Data.AfkConn = M.LP.Idled:Connect(function()
        pcall(function()
            M.Services.V:CaptureController()
            M.Services.V:ClickButton2(Vector2.new())
        end)
    end)
end

M.F.SetNoclip = function(on)
    M.State.PhaseCollision = on
    if M.UI.NoclipLoop then M.UI.NoclipLoop:Disconnect(); M.UI.NoclipLoop = nil end
    if on then
        M.UI.NoclipLoop = M.Services.R.PreSimulation:Connect(function()
            if M.State.IsUninjected or not M.State.PhaseCollision or M.State.IsDead then return end
            local char = M.LP and M.LP.Character
            if not (char and char.Parent) then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    -- Запоминаем исходное значение ОДИН раз, чтобы потом вернуть именно его
                    if M.Data.NoclipOrig[part] == nil then
                        M.Data.NoclipOrig[part] = part.CanCollide
                    end
                    part.CanCollide = false
                end
            end
        end)
    else
        -- Раньше всем деталям (даже шапкам) ставили CanCollide = true, и шапки начинали толкаться
        for part, original in pairs(M.Data.NoclipOrig) do
            if part.Parent then part.CanCollide = original end
        end
        table.clear(M.Data.NoclipOrig)
    end
end

-- ==============================================================================
-- [ SIMULATION LOOPS (PHYSICS & RENDERING) ]
-- ==============================================================================
table.insert(M.Data.Conns, M.Services.R.Heartbeat:Connect(function(dt)
    if M.State.IsUninjected then return end
    local char = M.LP and M.LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local cam = workspace.CurrentCamera

    M.State.IsDead = not (h and h.Health > 0)

    -- Раньше тут стоял return при смерти, и метеориты с молниями замирали. Теперь блок просто пропускается.
    if char and char.Parent and not M.State.IsDead and hrp and h then
        if M.State.Speed and not M.State.Levitation then
            local moveDir = h.MoveDirection
            if moveDir.Magnitude > 0 then
                local vel = hrp.AssemblyLinearVelocity
                local curSpd = Vector3.new(vel.X, 0, vel.Z).Magnitude
                if curSpd < M.State.SprintSpeed then
                    -- math.max: если задали скорость ниже обычной, персонажа не должно тянуть назад
                    local extra = math.max(M.State.SprintSpeed - h.WalkSpeed, 0)
                    hrp.CFrame = hrp.CFrame + (moveDir * (extra * dt))
                end
            end
        end

        if M.State.Levitation and cam then
            hrp.AssemblyLinearVelocity = Vector3.zero
            local inX, inZ, inY = GetDirectionInput()
            local camCF = cam.CFrame
            local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
            local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)

            if forward.Magnitude > 0 then forward = forward.Unit end
            if right.Magnitude > 0 then right = right.Unit end

            local moveDir = (right * inX) + (forward * inZ)
            if moveDir.Magnitude > 0 then moveDir = moveDir.Unit end

            local totalDir = Vector3.new(moveDir.X, inY, moveDir.Z)
            if totalDir.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + (totalDir * (M.State.KinematicBoost * dt))
            end
        elseif M.State.ImpulseStutters then
            -- Защита от толчков: срезаем слишком сильный разгон и бешеное вращение (раньше эта настройка ничего не делала)
            local vel = hrp.AssemblyLinearVelocity
            local flat = Vector3.new(vel.X, 0, vel.Z)
            local limit = math.max(120, M.State.SprintSpeed * 2.5)
            if flat.Magnitude > limit then
                local capped = flat.Unit * limit
                hrp.AssemblyLinearVelocity = Vector3.new(capped.X, vel.Y, capped.Z)
            end
            if hrp.AssemblyAngularVelocity.Magnitude > 40 then
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end

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
    if M.State.IsUninjected then return end

    M.Data.FpsCount = M.Data.FpsCount + 1
    if os.clock() - M.Data.FpsTimer >= 0.5 then
        M.State.CurFPS = math.round(M.Data.FpsCount / (os.clock() - M.Data.FpsTimer))
        M.Data.FpsCount = 0; M.Data.FpsTimer = os.clock()
    end

    if M.State.MenuOpen then
        M.Services.U.MouseBehavior = Enum.MouseBehavior.Default
        M.Services.U.MouseIconEnabled = true
    end

    M.F.UpdateWeatherProps(dt)

    -- Внешний вид проверяем 10 раз в секунду, а не каждый кадр
    if os.clock() - M.Data.LastVisual >= 0.1 then
        M.Data.LastVisual = os.clock()
        M.UpdatePlayerVisuals()
    end

    -- Страховка от игровых скриптов (смена дня и ночи и т.п.), которые подменяют небо
    if M.State.SkyOn and os.clock() - M.Data.LastSkyCheck >= 0.5 then
        M.Data.LastSkyCheck = os.clock()
        M.F.ApplySky(true)
    end

    if M.State.BacktrackShadows then
        if M.State.PacketChoke then
            M.Data.LagTicks = M.Data.LagTicks + 1
            local now = os.clock()
            if M.Data.LagTicks >= M.State.LagTicks or (now - M.Data.LastPacketTime) >= M.State.LagLimit then
                M.Data.LagTicks = 0
                M.Data.LastPacketTime = now
                M.UpdateBacktrack()
            end
        else
            if os.clock() - M.Data.LastPacketTime >= 0.08 then
                M.Data.LastPacketTime = os.clock()
                M.UpdateBacktrack()
            end
        end
    else
        if #M.State.GhostPool > 0 then M.ClearGhosts() end
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local char = M.LP and M.LP.Character
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local isAlive = (h and h.Health > 0)
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    M.F.UpdateThirdPerson(cam, hrp, h, M.State.ThirdPerson and isAlive)

    if M.State.ShowFov and M.State.AimAssist then
        M.UI.FovCircle.Visible = true
        M.UI.FovCircle.Size = UDim2.new(0, M.State.AimFov * 2, 0, M.State.AimFov * 2)
        local center = cam.ViewportSize / 2
        M.UI.FovCircle.Position = UDim2.new(0, center.X, 0, center.Y)
    else
        M.UI.FovCircle.Visible = false
    end

    if M.State.TriggerAssist and not M.State.MenuOpen and isAlive then
        local curTarget = M.GetTriggerTarget(cam)

        if curTarget then
            if (M.State.TriggerLoop or curTarget ~= M.Data.LastTriggerTarget) and not M.Data.TriggerCD then
                M.Data.LastTriggerTarget = curTarget
                M.Data.TriggerCD = true

                task.spawn(function()
                    -- pcall гарантирует, что кулдаун снимется, даже если выстрел вызвал ошибку
                    pcall(M.F.FireTrigger)
                    M.Data.TriggerCD = false
                end)
            end
        else
            M.Data.LastTriggerTarget = nil
        end
    end

    if char and char.Parent and not M.State.Levitation and isAlive then
        local myHum = char:FindFirstChildOfClass("Humanoid")
        local myRoot = char:FindFirstChild("HumanoidRootPart")
        if myHum and myRoot and M.State.AirVectoring and myHum:GetState() == Enum.HumanoidStateType.Freefall then
            local inX, inZ, _ = GetDirectionInput()
            local camCF = cam.CFrame
            local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
            local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)

            if forward.Magnitude > 0 then forward = forward.Unit end
            if right.Magnitude > 0 then right = right.Unit end

            local dir = (right * inX) + (forward * inZ)
            if dir.Magnitude > 0 then
                local curVel = myRoot.AssemblyLinearVelocity
                local curSpd = Vector3.new(curVel.X, 0, curVel.Z).Magnitude
                if curSpd < M.State.AirSpeed then
                    myRoot.CFrame = myRoot.CFrame + (dir.Unit * ((M.State.AirSpeed - curSpd) * dt * (M.State.AirAccel / 10)))
                end
            end
        end
    end

    M.F.UpdateStateForce()

    if M.State.Esp then
        local vSize = cam.ViewportSize
        for p, pack in pairs(M.State.EspGuis) do
            if not p.Parent then
                pack.Container:Destroy()
                if pack.TracerLine then pack.TracerLine:Destroy() end
                if M.State.Highlights[p] then M.State.Highlights[p]:Destroy() end
                M.State.Highlights[p] = nil
                M.State.EspGuis[p] = nil
                continue
            end

            local t_char = p.Character
            if not t_char or not t_char.Parent then
                pack.Container.Visible = false
                if pack.TracerLine then pack.TracerLine.Visible = false end
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
                if pack.TracerLine then pack.TracerLine.Visible = false end
                if M.State.Highlights[p] then M.State.Highlights[p].Enabled = false end
                continue
            end

            local isSelf = pack.IsSelf
            local allowed = M.State.Esp and (not isSelf or M.State.EspOnSelf)
            if M.State.EspTeamCheck and M.IsTeammate(p) and not isSelf then allowed = false end

            if not allowed then
                pack.Container.Visible = false
                if pack.TracerLine then pack.TracerLine.Visible = false end
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
                        pack.Container.Visible = M.State.EspBox
                        pack.Container.Position = UDim2.fromOffset(math.floor(rootPos.X - (boxWidth / 2)), math.floor(topScreen.Y))
                        pack.Container.Size = UDim2.fromOffset(math.floor(boxWidth), math.floor(boxHeight))
                        pack.Stroke.Enabled = M.State.EspBox

                        local curHp = math.clamp(hum.Health, 0, hum.MaxHealth)
                        local hpPercent = curHp / math.max(hum.MaxHealth, 1)
                        local tSize = M.State.EspHealthBarThick
                        local isH = (M.State.EspHealthPos == "Bottom")

                        pack.BarBg.Visible = M.State.EspHealthBar
                        pack.HpLabel.Visible = M.State.EspHealthText

                        if isH then
                            pack.BarBg.Size = UDim2.new(1, 0, 0, tSize)
                            pack.BarBg.Position = UDim2.new(0, 0, 1, 4)
                            pack.BarFill.Size = UDim2.new(hpPercent, 0, 1, 0)
                            pack.BarFill.Position = UDim2.new(0, 0, 0, 0)
                            pack.HpLabel.AnchorPoint = Vector2.new(0.5, 0)
                            pack.HpLabel.Position = UDim2.new(0.5, 0, 1, tSize + 4)
                            pack.HpLabel.TextXAlignment = Enum.TextXAlignment.Center
                        elseif M.State.EspHealthPos == "Right" then
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

                        pack.BarFill.BackgroundColor3 = M.State.EspHealthCol
                        pack.HpLabel.Text = string.format("%d HP", math.floor(curHp))
                        pack.HpLabel.TextColor3 = M.State.EspHealthCol
                        if M.State.Highlights[p] then M.State.Highlights[p].Enabled = true end

                        if M.State.EspTracers and pack.TracerLine and not isSelf then
                            local startX, startY = vSize.X / 2, vSize.Y
                            local targetX, targetY = rootPos.X, rootPos.Y
                            local distance = math.sqrt((targetX - startX)^2 + (targetY - startY)^2)
                            local angle = math.atan2(targetY - startY, targetX - startX)

                            pack.TracerLine.Visible = true
                            pack.TracerLine.Size = UDim2.new(0, distance, 0, 1.5)
                            pack.TracerLine.Position = UDim2.fromOffset((startX + targetX) / 2, (startY + targetY) / 2)
                            pack.TracerLine.Rotation = math.deg(angle)
                            pack.TracerLine.BackgroundColor3 = M.State.TracerCol
                        elseif pack.TracerLine then
                            pack.TracerLine.Visible = false
                        end
                    else
                        pack.Container.Visible = false
                        if pack.TracerLine then pack.TracerLine.Visible = false end
                        if M.State.Highlights[p] then M.State.Highlights[p].Enabled = false end
                    end
                else
                    pack.Container.Visible = false
                    if pack.TracerLine then pack.TracerLine.Visible = false end
                    if M.State.Highlights[p] then M.State.Highlights[p].Enabled = false end
                end
            else
                pack.Container.Visible = false
                if pack.TracerLine then pack.TracerLine.Visible = false end
                if M.State.Highlights[p] then M.State.Highlights[p].Enabled = false end
            end
        end
    else
        for _, pack in pairs(M.State.EspGuis) do
            if pack and pack.Container then pack.Container.Visible = false end
            if pack and pack.TracerLine then pack.TracerLine.Visible = false end
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

    if M.State.DarkWorld then
        local exp = -M.State.DarkIntensity * 3.5
        if M.Services.L.ExposureCompensation ~= exp then M.Services.L.ExposureCompensation = exp end
    end
    if M.State.TimeOn and M.Services.L.ClockTime ~= M.State.CustomTime then
        M.Services.L.ClockTime = M.State.CustomTime
        if M.State.FogOn then M.F.ApplyFog() end
        if M.State.CloudsOn then M.F.ApplyClouds() end
    end
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
    if M.State.IsUninjected then return end
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
M.UI.Gui.Name = "MatsysenseHub"
M.UI.Gui.ResetOnSpawn = false
M.UI.Gui.DisplayOrder = 200 -- меню выше ESP-рамок
-- Global нужен, чтобы выпадающие списки (ZIndex 15) рисовались поверх следующих карточек
M.UI.Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
M.UI.Gui.Parent = M.TargetGui

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

function M.F.AttachTooltip(card, key)
    local desc = M.Tooltips[key]
    if not desc then return end

    card.MouseEnter:Connect(function()
        M.Data.HoverCard = card
        if M.Data.HoverTask then pcall(task.cancel, M.Data.HoverTask) end
        M.Data.HoverTask = task.spawn(function()
            task.wait(1.0)
            if M.Data.HoverCard == card and not M.State.IsUninjected then
                local mPos = M.Services.U:GetMouseLocation()
                local screenSz = M.UI.Gui.AbsoluteSize
                local x = mPos.X + 14
                local y = mPos.Y + 14
                if x + 220 > screenSz.X then x = mPos.X - 225 end
                if y + 60 > screenSz.Y then y = mPos.Y - 65 end
                M.UI.Tooltip.Position = UDim2.fromOffset(math.max(x, 5), math.max(y, 5))
                M.UI.TooltipTxt.Text = desc
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
M.UI.Pill.Size = UDim2.new(0, 0, 0, 34)
M.UI.Pill.AutomaticSize = Enum.AutomaticSize.X
M.UI.Pill.Position = UDim2.new(0.04, 0, 0.05, 0)
M.UI.Pill.BackgroundColor3 = M.State.PillBg
M.UI.Pill.BackgroundTransparency = M.State.PillAlpha
M.UI.Pill.Visible = true
M.UI.Pill.Active = true
Instance.new("UICorner", M.UI.Pill).CornerRadius = UDim.new(0, 10)
M.UI.PillStroke = Instance.new("UIStroke", M.UI.Pill)
M.UI.PillStroke.Color = M.State.PillBorderCol
M.UI.PillStroke.Thickness = M.State.PillBorderThick
M.UI.PillScale = Instance.new("UIScale", M.UI.Pill)
M.UI.PillScale.Scale = M.State.PillScaleVal

local pillLayout = Instance.new("UIListLayout", M.UI.Pill)
pillLayout.FillDirection = Enum.FillDirection.Horizontal
pillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
pillLayout.Padding = UDim.new(0, 8)

local pillPad = Instance.new("UIPadding", M.UI.Pill)
pillPad.PaddingLeft = UDim.new(0, 8); pillPad.PaddingRight = UDim.new(0, 12)

M.UI.PillAvatar = Instance.new("ImageLabel", M.UI.Pill)
M.UI.PillAvatar.Size = UDim2.new(0, 22, 0, 22); M.UI.PillAvatar.LayoutOrder = 1; M.UI.PillAvatar.BackgroundTransparency = 1
Instance.new("UICorner", M.UI.PillAvatar).CornerRadius = UDim.new(1, 0)
task.spawn(pcall, function() M.UI.PillAvatar.Image = M.Services.P:GetUserThumbnailAsync(M.LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) end)

M.UI.PillTxt = Instance.new("TextLabel", M.UI.Pill)
M.UI.PillTxt.Size = UDim2.new(0, 0, 1, 0); M.UI.PillTxt.AutomaticSize = Enum.AutomaticSize.X; M.UI.PillTxt.LayoutOrder = 2
M.UI.PillTxt.BackgroundTransparency = 1; M.UI.PillTxt.TextColor3 = M.State.PillTextCol; M.UI.PillTxt.Font = Enum.Font.GothamBold; M.UI.PillTxt.TextSize = 12
M.UI.PillTxt.Text = "matsysense | Загружено"

do
    local pDragStart, pStartPos, isPillDragging = nil, nil, false
    local clickDownPos = nil
    M.UI.Pill.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton2 then
            M.State.PillLocked = not M.State.PillLocked
            M.Services.T:Create(M.UI.PillStroke, TweenInfo.new(M.State.AnimSpeed), {
                Color = M.State.PillLocked and M.State.Accent or M.State.PillBorderCol
            }):Play()
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
        if M.State.IsUninjected then break end
        M.State.Uptime = M.State.Uptime + 0.5
        local ping = 0; pcall(function() ping = math.round(M.LP:GetNetworkPing() * 1000) end)
        if M.State.PacketChoke then ping = ping + math.round(M.State.LagLimit * 1000) end
        
        local totalMem = math.round(M.Services.S:GetTotalMemoryUsageMb())
        local serverTime = os.date("*t", os.time())

        local textParts = {"matsysense"}
        if M.State.PillLocked then table.insert(textParts, "[ЗАМОК]") end
        if M.State.PillShowUser then table.insert(textParts, M.LP.Name) end
        table.insert(textParts, string.format("%d FPS", M.State.CurFPS))
        table.insert(textParts, string.format("%dms", ping))

        if M.State.PillShowMem then table.insert(textParts, string.format("Память: %dMB", totalMem)) end
        if M.State.PillShowMinsk then table.insert(textParts, string.format("Время: %02d:%02d:%02d", serverTime.hour, serverTime.min, serverTime.sec)) end
        if M.State.PillShowTime then table.insert(textParts, string.format("Сессия: %02d:%02d:%02d", math.floor(M.State.Uptime/3600), math.floor((M.State.Uptime%3600)/60), math.floor(M.State.Uptime%60))) end

        M.UI.PillTxt.Text = table.concat(textParts, " | ")
        if M.UI.PUptime then M.UI.PUptime.Text = string.format("Up: %02d:%02d:%02d", math.floor(M.State.Uptime/3600), math.floor((M.State.Uptime%3600)/60), math.floor(M.State.Uptime%60)) end
    end
end)

-- Main Frame Component
M.UI.Main = Instance.new("Frame", M.UI.Gui)
M.UI.Main.Size = UDim2.new(0, 710, 0, 490); M.UI.Main.Position = UDim2.new(0.5, -355, 0.5, -245)
M.UI.Main.BackgroundColor3 = M.State.MainBg; M.UI.Main.BackgroundTransparency = M.State.MenuAlpha; M.UI.Main.Active = true
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

M.UI.BtnUninject = Instance.new("TextButton", M.UI.TopControls)
M.UI.BtnUninject.Size = UDim2.new(0, 26, 0, 26)
M.UI.BtnUninject.BackgroundColor3 = Color3.fromRGB(180, 40, 50)
M.UI.BtnUninject.Text = "X"
M.UI.BtnUninject.TextColor3 = Color3.fromRGB(255, 255, 255)
M.UI.BtnUninject.Font = Enum.Font.GothamBold
M.UI.BtnUninject.TextSize = 12
M.UI.BtnUninject.ZIndex = 26
Instance.new("UICorner", M.UI.BtnUninject).CornerRadius = UDim.new(0, 6)

M.UI.BtnUninject.MouseEnter:Connect(function()
    M.Services.T:Create(M.UI.BtnUninject, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(225, 45, 55)}):Play()
end)
M.UI.BtnUninject.MouseLeave:Connect(function()
    M.Services.T:Create(M.UI.BtnUninject, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(180, 40, 50)}):Play()
end)
M.UI.BtnUninject.MouseButton1Click:Connect(function() M.F.Uninject() end)

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
    local resizeHandle = Instance.new("ImageButton", M.UI.Main)
    resizeHandle.Size = UDim2.new(0, 16, 0, 16); resizeHandle.Position = UDim2.new(1, -16, 1, -16); resizeHandle.BackgroundTransparency = 1
    resizeHandle.Image = "rbxassetid://6031094678"; resizeHandle.ImageColor3 = Color3.fromRGB(150, 160, 185)

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
pHeader.Text = "ОТОБРАЖЕНИЕ"; pHeader.TextColor3 = Color3.fromRGB(160, 170, 195); pHeader.Font = Enum.Font.GothamBold; pHeader.TextSize = 12

M.UI.PrevDummyTag = Instance.new("TextLabel", M.UI.PrevCard)
M.UI.PrevDummyTag.Size = UDim2.new(1, -10, 0, 20); M.UI.PrevDummyTag.Position = UDim2.new(0, 5, 0, 48); M.UI.PrevDummyTag.BackgroundTransparency = 1
M.UI.PrevDummyTag.Text = "Игрок (@User)"; M.UI.PrevDummyTag.TextColor3 = M.State.EspNameCol; M.UI.PrevDummyTag.TextStrokeColor3 = M.State.EspNameOutCol; M.UI.PrevDummyTag.TextStrokeTransparency = 0
M.UI.PrevDummyTag.Font = Enum.Font.GothamBold; M.UI.PrevDummyTag.TextSize = 12

M.UI.PrevDummyContainer = Instance.new("Frame", M.UI.PrevCard)
M.UI.PrevDummyContainer.Size = UDim2.new(0, 110, 0, 220); M.UI.PrevDummyContainer.Position = UDim2.new(0.5, -55, 0, 80); M.UI.PrevDummyContainer.BackgroundTransparency = 1

do
    local function makeDP(size, pos, cr)
        local f = Instance.new("Frame", M.UI.PrevDummyContainer)
        f.Size = size; f.Position = pos; f.BackgroundColor3 = M.State.EspFill; f.BackgroundTransparency = M.State.EspAlpha; f.BorderSizePixel = 0
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, cr)
        local s = Instance.new("UIStroke", f); s.Color = M.State.EspBoxCol; s.Thickness = M.State.EspBoxThick
        table.insert(M.UI.Esp2DParts, f)
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
        if M.State.IsUninjected then break end
        if M.UI.LogoGrad and M.UI.LogoGrad.Parent then
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

M.UI.Avatar = Instance.new("ImageLabel", M.UI.ProfileCard)
M.UI.Avatar.Size = UDim2.new(0, 36, 0, 36); M.UI.Avatar.Position = UDim2.new(0, 8, 0.5, -18); M.UI.Avatar.BackgroundTransparency = 1
Instance.new("UICorner", M.UI.Avatar).CornerRadius = UDim.new(1, 0)
task.spawn(pcall, function() M.UI.Avatar.Image = M.Services.P:GetUserThumbnailAsync(M.LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) end)

M.UI.PName = Instance.new("TextLabel", M.UI.ProfileCard)
M.UI.PName.Size = UDim2.new(1, -54, 0, 16); M.UI.PName.Position = UDim2.new(0, 50, 0, 10); M.UI.PName.BackgroundTransparency = 1
M.UI.PName.Text = M.LP.Name; M.UI.PName.TextColor3 = Color3.fromRGB(240, 245, 255); M.UI.PName.Font = Enum.Font.GothamBold; M.UI.PName.TextSize = 12; M.UI.PName.TextXAlignment = Enum.TextXAlignment.Left

M.UI.PUptime = Instance.new("TextLabel", M.UI.ProfileCard)
M.UI.PUptime.Size = UDim2.new(1, -54, 0, 14); M.UI.PUptime.Position = UDim2.new(0, 50, 0, 26); M.UI.PUptime.BackgroundTransparency = 1
M.UI.PUptime.TextColor3 = Color3.fromRGB(150, 160, 185); M.UI.PUptime.Font = Enum.Font.Gotham; M.UI.PUptime.TextSize = 11; M.UI.PUptime.TextXAlignment = Enum.TextXAlignment.Left

M.UI.TabContainer = Instance.new("Frame", M.UI.Sidebar)
M.UI.TabContainer.Size = UDim2.new(1, 0, 1, -135); M.UI.TabContainer.Position = UDim2.new(0, 0, 0, 56); M.UI.TabContainer.BackgroundTransparency = 1
local tLayout = Instance.new("UIListLayout", M.UI.TabContainer); tLayout.Padding = UDim.new(0, 5); tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

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

function M.F.SwitchTab(name)
    if M.State.ActiveTab == name and M.State.Pages[name] and M.State.Pages[name].Frame.Visible then return end
    M.State.ActiveTab = name

    for n, b in pairs(M.State.TabButtons) do
        local isAct = (n == name)
        b.TextColor3 = isAct and M.State.Accent or Color3.fromRGB(160, 170, 190)
        b.BackgroundColor3 = isAct and M.State.SideCardBg or Color3.fromRGB(0, 0, 0)
        b.BackgroundTransparency = isAct and M.State.SideCardAlpha or 1
    end

    for n, pPack in pairs(M.State.Pages) do
        if n == name then
            pPack.Frame.Position = UDim2.new(0, 8, 0, 6)
            pPack.Frame.Visible = true
        else
            pPack.Frame.Visible = false
        end
    end

    M.UI.PrevCard.Visible = (name == "ESP") and M.UI.Main.Visible
    if M.UI.PrevCard.Visible then
        M.F.SyncPreviewPos()
        M.F.Update2DPreview()
    end
end

function M.F.MakeTabBtn(tabKey, order)
    local b = Instance.new("TextButton", M.UI.TabContainer)
    b.Size = UDim2.new(1, -16, 0, 30); b.LayoutOrder = order; b.BackgroundTransparency = 1; b.BackgroundColor3 = M.State.SideCardBg
    b.Text = M.Translate(tabKey); b.TextColor3 = Color3.fromRGB(160, 170, 190); b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local pad = Instance.new("UIPadding", b); pad.PaddingLeft = UDim.new(0, 12)
    local tabName = tabKey:gsub("Tab_", "")

    b.MouseEnter:Connect(function()
        if M.State.ActiveTab ~= tabName then
            M.Services.T:Create(b, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundColor3 = M.State.SideCardBg,
                BackgroundTransparency = math.clamp(M.State.SideCardAlpha * 0.5, 0.05, 0.5)
            }):Play()
        end
    end)

    b.MouseLeave:Connect(function()
        if M.State.ActiveTab ~= tabName then
            M.Services.T:Create(b, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextColor3 = Color3.fromRGB(160, 170, 190),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = 1
            }):Play()
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

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Position = UDim2.new(0, 4, 0, 2)
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
    Instance.new("UICorner", c).CornerRadius = UDim.new(0, 8); table.insert(M.State.Cards, c)
    return c
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
    trk.Size = UDim2.new(0, 48, 0, 24); trk.Position = UDim2.new(1, -60, 0.5, -12); trk.BackgroundColor3 = M.State[stateKey] and M.State.Accent or Color3.fromRGB(38, 42, 54); trk.Text = ""
    Instance.new("UICorner", trk).CornerRadius = UDim.new(1, 0)

    local thm = Instance.new("Frame", trk)
    thm.Size = UDim2.new(0, 14, 0, 14); thm.AnchorPoint = Vector2.new(0, 0.5); thm.Position = M.State[stateKey] and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 4, 0.5, 0); thm.BackgroundColor3 = Color3.fromRGB(255, 255, 255); thm.BorderSizePixel = 0
    Instance.new("UICorner", thm).CornerRadius = UDim.new(1, 0)

    local function uv(val)
        M.Services.T:Create(thm, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = val and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 4, 0.5, 0)}):Play()
        M.Services.T:Create(trk, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = val and M.State.Accent or Color3.fromRGB(38, 42, 54)}):Play()
    end

    local function trigger()
        M.State[stateKey] = not M.State[stateKey]
        uv(M.State[stateKey])
        if onTog then onTog(M.State[stateKey]) end
    end
    trk.MouseButton1Click:Connect(trigger)

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
    trk.Size = UDim2.new(0, 48, 0, 24); trk.Position = UDim2.new(1, -60, 0.5, -12); trk.BackgroundColor3 = Color3.fromRGB(38, 42, 54); trk.Text = ""
    Instance.new("UICorner", trk).CornerRadius = UDim.new(1, 0)

    local thm = Instance.new("Frame", trk)
    thm.Size = UDim2.new(0, 14, 0, 14); thm.AnchorPoint = Vector2.new(0, 0.5); thm.Position = UDim2.new(0, 4, 0.5, 0); thm.BackgroundColor3 = Color3.fromRGB(255, 255, 255); thm.BorderSizePixel = 0
    Instance.new("UICorner", thm).CornerRadius = UDim.new(1, 0)

    local function uv()
        local a = isFly and M.State.Levitation or M.State.Speed
        box.Text = tostring(M.State[stateValKey])
        M.Services.T:Create(thm, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = a and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 4, 0.5, 0)}):Play()
        M.Services.T:Create(trk, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = a and M.State.Accent or Color3.fromRGB(38, 42, 54)}):Play()
    end

    local function t()
        if isFly then 
            if M.State.Levitation then M.F.StopFlying() else M.F.StartFlying() end
        else 
            M.State.Speed = not M.State.Speed 
        end
        if tFn then tFn() end
        uv()
    end
    trk.MouseButton1Click:Connect(t)

    table.insert(M.Data.RegUI, {
        Key = stateValKey,
        SetVisual = function(val) box.Text = tostring(val); uv() end,
        SetLanguage = function() l.Text = M.Translate(locKey) end,
        Callback = onV
    })
    return c
end

-- Эти ползунки должны давать только целые числа (количество штук, толщина в пикселях)
local INTEGER_SLIDERS = {GhostCount = true, OrbitCount = true, EspHealthBarThick = true}

function M.F.MakeSlider(parent, locKey, stateKey, mn, mx, un, order, cb)
    -- Целые числа для больших диапазонов. Секунды ("с") всегда дробные.
    -- Раньше проверка по букве "с" случайно делала дробными и "мс" (миллисекунды).
    local useInteger = (mx > 10 and un ~= "с") or INTEGER_SLIDERS[stateKey] == true
    local c = M.F.MakeCard(parent, 40); c.LayoutOrder = order
    local labelText = M.Translate(locKey) .. (un and ("  " .. un) or "")
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

    local box = Instance.new("TextBox", c)
    box.Size = UDim2.new(0, 52, 0, 24); box.Position = UDim2.new(1, -60, 0.5, -12)
    box.BackgroundColor3 = Color3.fromRGB(16, 19, 27); box.Text = tostring(M.State[stateKey]); box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.GothamBold; box.TextSize = 12; box.BorderSizePixel = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local function setVisual(val)
        box.Text = tostring(val)
        M.Services.T:Create(f, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(math.clamp((val - mn) / (mx - mn), 0.02, 1), 0, 1, 0)
        }):Play()
    end

    local function upd(pos)
        local curAbsPos = trk.AbsolutePosition
        local curAbsSz = trk.AbsoluteSize
        if curAbsSz.X <= 0 then return end
        local r = math.clamp((pos.X - curAbsPos.X) / curAbsSz.X, 0, 1)
        local val = mn + (r * (mx - mn))
        val = useInteger and math.round(val) or (math.floor(val * 100) / 100)
        M.State[stateKey] = val
        setVisual(val)
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
        Key = stateKey,
        SetVisual = setVisual,
        SetLanguage = function() l.Text = M.Translate(locKey) .. (un and ("  " .. un) or "") end,
        Callback = cb
    })
    return c
end

-- ==============================================================================
-- [ МАТЕМАТИКА ПАЛИТРЫ ]
-- Чистые функции без объектов Roblox: их можно проверять модульными тестами.
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

function M.F.MakeDropdown(parent, locKey, options, stateKey, order, cb)
    local c = M.F.MakeCard(parent, 40); c.LayoutOrder = order
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(0.45, 0, 1, 0); l.Position = UDim2.new(0, 12, 0, 0); l.BackgroundTransparency = 1
    l.Text = M.Translate(locKey); l.TextColor3 = Color3.fromRGB(240, 245, 255); l.Font = Enum.Font.GothamMedium; l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left

    local b = Instance.new("TextButton", c)
    b.Size = UDim2.new(0, 115, 0, 24); b.Position = UDim2.new(1, -125, 0.5, -12); b.BackgroundColor3 = Color3.fromRGB(38, 42, 54); b.Text = tostring(M.State[stateKey]); b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Font = Enum.Font.GothamBold; b.TextSize = 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

    local drop = Instance.new("Frame", c)
    drop.Size = UDim2.new(0, 115, 0, #options * 26); drop.Position = UDim2.new(1, -125, 1, 2); drop.BackgroundColor3 = Color3.fromRGB(20, 24, 32); drop.Visible = false; drop.ZIndex = 15
    Instance.new("UICorner", drop).CornerRadius = UDim.new(0, 6); Instance.new("UIListLayout", drop)

    b.MouseButton1Click:Connect(function() drop.Visible = not drop.Visible end)
    for _, opt in ipairs(options) do
        local ob = Instance.new("TextButton", drop)
        ob.Size = UDim2.new(1, 0, 0, 26); ob.BackgroundTransparency = 1; ob.Text = opt; ob.TextColor3 = Color3.fromRGB(200, 210, 230); ob.Font = Enum.Font.Gotham; ob.TextSize = 12; ob.ZIndex = 16
        ob.MouseButton1Click:Connect(function()
            b.Text = opt
            drop.Visible = false
            M.State[stateKey] = opt
            if cb then cb(opt) end
        end)
    end

    table.insert(M.Data.RegUI, {
        Key = stateKey,
        SetVisual = function(val) b.Text = tostring(val) end,
        SetLanguage = function() l.Text = M.Translate(locKey) end,
        Callback = cb
    })
    return c
end

-- Поле ввода текста. Серый текст-подсказка (PlaceholderText) виден, пока поле пустое,
-- и показывает, в каком формате нужно писать.
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
-- [ CONFIG MANAGER - ДИСКОВОЕ ХРАНИЛИЩЕ ]
-- ==============================================================================
local CFG_FILE_PATH = "Matsysense_Configs.json"

-- Эти значения живут только во время игры. Раньше они попадали в конфиг и ломали загрузку
-- (например, MenuOpen/IsDead/Levitation восстанавливались из файла, а Orig* подменяли настоящие настройки игры).
M.CFG.RuntimeKeys = {
    Uptime = true, CurFPS = true, IsDead = true, IsUninjected = true,
    MenuOpen = true, TabSwitching = true, Levitation = true
}

function M.CFG.IsRuntimeKey(k)
    return M.CFG.RuntimeKeys[k] == true or string.sub(k, 1, 4) == "Orig"
end

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

M.CFG.ApplyImportDataInner = function(data)
    if type(data) ~= "table" then return end
    for k, v in pairs(data) do
        if M.State[k] ~= nil and not M.CFG.IsRuntimeKey(k) then
            if type(v) == "table" and v.__type == "Color3" and v.hex then
                -- fromHex бросает ошибку на неправильной строке, поэтому pcall
                local ok, color = pcall(Color3.fromHex, v.hex)
                if ok then M.State[k] = color end
            elseif typeof(M.State[k]) == typeof(v) then
                M.State[k] = v
            end
        end
    end

    if data["__PillPos"] and M.UI.Pill then
        local p = data["__PillPos"]
        M.UI.Pill.Position = UDim2.new(p.XS, p.XO, p.YS, p.YO)
    end
    if data["__MainPos"] and M.UI.Main then
        local m = data["__MainPos"]
        M.UI.Main.Position = UDim2.new(m.XS, m.XO, m.YS, m.YO)
        M.F.SyncPreviewPos()
    end
    if data["__MainSize"] and M.UI.Main then
        local ms = data["__MainSize"]
        M.UI.Main.Size = UDim2.new(0, math.clamp(ms.X, 600, 960), 0, math.clamp(ms.Y, 420, 760))
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

    M.UI.Pill.BackgroundColor3 = M.State.PillBg
    M.UI.Pill.BackgroundTransparency = M.State.PillAlpha
    M.UI.PillStroke.Color = M.State.PillBorderCol
    M.UI.PillStroke.Thickness = M.State.PillBorderThick
    M.UI.PillScale.Scale = M.State.PillScaleVal
    M.UI.PillTxt.TextColor3 = M.State.PillTextCol

    M.UI.Main.BackgroundColor3 = M.State.MainBg
    M.UI.Main.BackgroundTransparency = M.State.MenuAlpha
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

    M.F.SetNoclip(M.State.PhaseCollision)
    M.F.ApplyDark()
    M.F.ApplyFog()
    M.F.ApplyClouds()
    M.ApplyFpsBoost(M.State.FpsBoost)
    M.ApplyFpsUnlocker(M.State.FpsUnlocker)
    M.F.UpdateEsp()
    M.UpdatePlayerVisuals()
    if M.State.OrbitOn then M.F.RebuildOrbits() end
    if M.State.HatOn then M.F.RebuildWireHat() end
    M.ClearGhosts()
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

function M.CFG.FlushToFile()
    pcall(function()
        local raw = M.Services.H:JSONEncode(M.Data.MemStorage)
        if writefile then
            writefile(CFG_FILE_PATH, raw)
        end
    end)
end

function M.CFG.LoadFromFile()
    pcall(function()
        if isfile and readfile and isfile(CFG_FILE_PATH) then
            local raw = readfile(CFG_FILE_PATH)
            local parsed = M.Services.H:JSONDecode(raw)
            if type(parsed) == "table" then
                M.Data.MemStorage = parsed
            end
        end
    end)
end

M.CFG.Save = function(name)
    name = (name and name ~= "") and name or "default"
    M.Data.MemStorage[name] = M.CFG.GetExportData()
    M.CFG.FlushToFile()
    return true
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
    M.CFG.FlushToFile()
end

M.CFG.CheckAutoload = function()
    M.CFG.LoadFromFile()
    local auto = M.Data.MemStorage["__AUTOLOAD"]
    if auto and auto ~= "" then
        M.CFG.Load(auto)
        M.State.SelectedCfg = auto
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
    if #cfgs == 0 then table.insert(cfgs, "default") end
    return cfgs
end

-- ==============================================================================
-- [ INTERFACE PAGES CONSTRUCTOR ]
-- ==============================================================================
M.F.MakeTabBtn("Tab_Combat", 1)
M.F.MakeTabBtn("Tab_Movement", 2)
M.F.MakeTabBtn("Tab_Camera", 3)
M.F.MakeTabBtn("Tab_ESP", 4)
M.F.MakeTabBtn("Tab_World", 5)
M.F.MakeTabBtn("Tab_Player", 6)
M.F.MakeTabBtn("Tab_Misc", 7)
M.F.MakeTabBtn("Tab_System", 8)
M.F.MakeTabBtn("Tab_Configs", 9)
M.F.MakeTabBtn("Tab_Settings", 10)

local pCombat = M.F.CreatePage("Combat")
local pExp = M.F.CreatePage("Movement")
local pCam = M.F.CreatePage("Camera")
local pEsp = M.F.CreatePage("ESP")
local pWrld = M.F.CreatePage("World")
local pPlyr = M.F.CreatePage("Player")
local pMisc = M.F.CreatePage("Misc")
local pSys = M.F.CreatePage("System")
local pCfg = M.F.CreatePage("Configs")
local pSet = M.F.CreatePage("Settings")

-- Combat
M.F.MakeSection(pCombat, "Sec_AimAssist", 1)
M.F.MakeToggle(pCombat, "AimAssist", "AimAssist", 2, function() end, true)
M.F.MakeToggle(pCombat, "AimTeamCheck", "AimTeamCheck", 3, function() end, false)
M.F.MakeSlider(pCombat, "AimFov", "AimFov", 10, 800, "px", 4, function() end)
M.F.MakeToggle(pCombat, "ShowFov", "ShowFov", 5, function() end, false)
M.F.MakeSlider(pCombat, "AimTime", "AimTime", 0, 1000, "мс", 6, function() end)
M.F.MakeToggle(pCombat, "AimWallCheck", "AimWallCheck", 7, function() end, false)

M.F.MakeSection(pCombat, "Sec_TriggerAssist", 8)
M.F.MakeToggle(pCombat, "TriggerAssist", "TriggerAssist", 9, function() end, true)
M.F.MakeToggle(pCombat, "TriggerTeamCheck", "TriggerTeamCheck", 10, function() end, false)
M.F.MakeToggle(pCombat, "TriggerLoop", "TriggerLoop", 11, function() end, false)
M.F.MakeSlider(pCombat, "TriggerDelay", "TriggerDelay", 0.0, 0.5, "с", 12, function() end)
M.F.MakeToggle(pCombat, "TriggerWallCheck", "TriggerWallCheck", 13, function() end, false)

-- Movement
M.F.MakeSection(pExp, "Sec_Movement", 1)
M.F.MakeSpeedCard(pExp, "Levitation", "KinematicBoost", true, 2, function() end, function(v) M.State.KinematicBoost = v end)
M.F.MakeToggle(pExp, "ImpulseStutters", "ImpulseStutters", 3, function() end, false)
M.F.MakeSpeedCard(pExp, "MovementVelocity", "SprintSpeed", false, 4, function() end, function(v) M.State.SprintSpeed = v end)
M.F.MakeToggle(pExp, "AirVectoring", "AirVectoring", 5, function() end, true)
M.F.MakeSlider(pExp, "AirSpeed", "AirSpeed", 50, 400, "", 6, function() end)
M.F.MakeSlider(pExp, "AirAccel", "AirAccel", 1, 20, "", 7, function() end)
M.F.MakeToggle(pExp, "AirVault", "AirVault", 8, function() end, true)

M.F.MakeSection(pExp, "Sec_Defense", 9)
M.F.MakeToggle(pExp, "PhaseCollision", "PhaseCollision", 10, M.F.SetNoclip, true)
M.F.MakeToggle(pExp, "StateForce", "StateForce", 11, function() end, true)
M.F.MakeToggle(pExp, "NetworkAlive", "NetworkAlive", 12, function(on) M.F.SetAntiAfk(on) end, true)

-- Camera
M.F.MakeSection(pCam, "Sec_CameraMain", 1)
M.F.MakeSlider(pCam, "CamFov", "CamFov", 30, 120, "°", 2, function(v)
    M.State.CamFov = v
    -- Принудительно держим FOV только если он отличается от FOV игры
    M.Data.FovForced = math.abs(v - M.Data.OrigFov) > 0.5
    local cam = workspace.CurrentCamera
    if cam then cam.FieldOfView = v end
end)

M.F.MakeSection(pCam, "Sec_CameraMods", 3)
M.F.MakeToggle(pCam, "ThirdPerson", "ThirdPerson", 4, function() end, true)
M.F.MakeSlider(pCam, "ThirdPersonDist", "ThirdPersonDist", 5, 30, "м", 5, function() end)

-- ESP
M.F.MakeSection(pEsp, "Sec_EspBase", 1)
M.F.MakeToggle(pEsp, "EnableEsp", "Esp", 2, function() M.F.UpdateEsp() end, false)
M.F.MakeToggle(pEsp, "EspOnSelf", "EspOnSelf", 3, function() M.F.UpdateEsp() end, false)
M.F.MakeToggle(pEsp, "EspTeamCheck", "EspTeamCheck", 4, function() M.F.UpdateEsp() end, false)
M.F.MakePicker(pEsp, "FillCol", "EspFill", 5, function() M.F.UpdateEsp() end)
M.F.MakePicker(pEsp, "LineCol", "EspLine", 6, function() M.F.UpdateEsp() end)

M.F.MakeSection(pEsp, "Sec_EspBoxes", 7)
M.F.MakeToggle(pEsp, "EspBox", "EspBox", 8, function() M.F.UpdateEsp() end, false)
M.F.MakePicker(pEsp, "BoxCol", "EspBoxCol", 9, function() M.F.UpdateEsp() end)
M.F.MakeSlider(pEsp, "BoxThick", "EspBoxThick", 1.0, 5.0, "px", 10, function() M.F.UpdateEsp() end)
M.F.MakeDropdown(pEsp, "FontWeight", {"Bold", "Medium"}, "EspFontWeight", 11, function() M.F.UpdateEsp() end)
M.F.MakeSlider(pEsp, "TextSize", "EspTextSize", 9, 20, "px", 12, function() M.F.UpdateEsp() end)
M.F.MakePicker(pEsp, "NameCol", "EspNameCol", 13, function() M.F.UpdateEsp() end)

M.F.MakeSection(pEsp, "Sec_EspHealth", 14)
M.F.MakeToggle(pEsp, "ShowHp", "EspHealthBar", 15, function() M.F.UpdateEsp() end, false)
M.F.MakeDropdown(pEsp, "HpPos", {"Left", "Right", "Bottom"}, "EspHealthPos", 16, function() M.F.UpdateEsp() end)
M.F.MakeSlider(pEsp, "HpThick", "EspHealthBarThick", 2, 10, "px", 17, function() M.F.UpdateEsp() end)
M.F.MakeToggle(pEsp, "HpText", "EspHealthText", 18, function() M.F.UpdateEsp() end, false)
M.F.MakePicker(pEsp, "HpCol", "EspHealthCol", 19, function() M.F.UpdateEsp() end)

M.F.MakeSection(pEsp, "Sec_EspTracers", 20)
M.F.MakeToggle(pEsp, "EspTracers", "EspTracers", 21, function() M.F.UpdateEsp() end, false)
M.F.MakePicker(pEsp, "TracerCol", "TracerCol", 22, function() M.F.UpdateEsp() end)

-- World
M.F.MakeSection(pWrld, "Sec_WorldFog", 1)
M.F.MakeToggle(pWrld, "WhiteFog", "FogOn", 2, function() M.F.ApplyFog() end, false)
M.F.MakeSlider(pWrld, "FogDense", "FogDensity", 0.1, 1.0, "", 3, function() M.F.ApplyFog() end)
M.F.MakeSlider(pWrld, "FogHaze", "FogHaze", 0.0, 6.0, "", 4, function() M.F.ApplyFog() end)
M.F.MakePicker(pWrld, "FogCol", "FogColor", 5, function(c)
    M.State.FogColor = c
    if not M.Data.Importing and not M.State.FogOn then
        M.State.FogOn = true
        for _, el in ipairs(M.Data.RegUI) do
            if el.Key == "FogOn" and el.SetVisual then el.SetVisual(true) end
        end
    end
    M.F.ApplyFog()
end)
M.F.MakeToggle(pWrld, "TimeOfDay", "TimeOn", 6, function(on)
    M.Services.L.ClockTime = on and M.State.CustomTime or M.State.OrigTime
    if M.State.FogOn then M.F.ApplyFog() end
    if M.State.CloudsOn then M.F.ApplyClouds() end
end, false)
M.F.MakeSlider(pWrld, "ClockTime", "CustomTime", 0, 24, "", 7, function(v)
    if M.State.TimeOn then
        M.Services.L.ClockTime = v
        if M.State.FogOn then M.F.ApplyFog() end
        if M.State.CloudsOn then M.F.ApplyClouds() end
    end
end)
M.F.MakeToggle(pWrld, "DarkWorld", "DarkWorld", 8, function() M.F.ApplyDark() end, false)
M.F.MakeSlider(pWrld, "DarkIntense", "DarkIntensity", 0.05, 1, "", 9, function() M.F.ApplyDark() end)

-- Clouds
-- Custom Skybox
M.F.MakeSection(pWrld, "Sec_WorldSky", 10)
M.F.MakeToggle(pWrld, "SkyOn", "SkyOn", 11, function() M.F.ApplySky() end, false)
M.F.MakeTextInput(pWrld, "SkyIds", "SkyIds", "SkyPlaceholder", 12, function() M.F.ApplySky() end)

local skyStatusCard = M.F.MakeCard(pWrld, 40)
skyStatusCard.LayoutOrder = 13
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
M.F.SetSkyStatus("Sky_Idle", nil, "idle")

M.F.MakeToggle(pWrld, "SkyHideBodies", "SkyHideBodies", 14, function() M.F.ApplySky(true) end, false)

M.F.MakeSection(pWrld, "Sec_WorldClouds", 15)
M.F.MakeToggle(pWrld, "CloudsOn", "CloudsOn", 16, function() M.F.ApplyClouds() end, false)
M.F.MakeSlider(pWrld, "CloudDensity", "CloudDensity", 0.01, 1.0, "", 17, function() M.F.ApplyClouds() end)
M.F.MakeSlider(pWrld, "CloudCover", "CloudCover", 0, 100, "%", 18, function() M.F.ApplyClouds() end)
M.F.MakePicker(pWrld, "CloudColor", "CloudColor", 19, function(c)
    M.State.CloudColor = c
    -- Раньше цвет менялся, но облака были выключены, и результата не было видно
    if not M.Data.Importing and not M.State.CloudsOn then
        M.State.CloudsOn = true
        for _, el in ipairs(M.Data.RegUI) do
            if el.Key == "CloudsOn" and el.SetVisual then el.SetVisual(true) end
        end
    end
    M.F.ApplyClouds()
end)

-- Weather
M.F.MakeSection(pWrld, "Sec_WorldWeather", 20)
M.F.MakeToggle(pWrld, "PropWeather", "WeatherOn", 21, function(on) if not on then M.F.ClearWeatherProps() end end, false)
M.F.MakeDropdown(pWrld, "WeatherMode", {"Rain", "Snow"}, "WeatherMode", 22, function() M.F.ClearWeatherProps() end)
M.F.MakeSlider(pWrld, "WeatherDense", "WeatherDensity", 10, 100, "", 23, function() end)
M.F.MakeSlider(pWrld, "WeatherSpeed", "WeatherSpeed", 10, 140, "", 24, function() end)
M.F.MakeSlider(pWrld, "WeatherRadius", "WeatherRadius", 20, 220, "studs", 25, function() end)
M.F.MakeSlider(pWrld, "SnowSize", "SnowSize", 0.2, 2.5, "studs", 26, function() end)
M.F.MakePicker(pWrld, "WeatherCol", "WeatherColor", 27, function() end)

-- World Effects
M.F.MakeSection(pWrld, "Sec_WorldEffects", 28)
M.F.MakeToggle(pWrld, "Lightning", "LightningOn", 29, function() end, false)
M.F.MakeSlider(pWrld, "LightRate", "LightningRate", 1, 10, "x", 30, function() end)
M.F.MakeSlider(pWrld, "LightSize", "LightningSize", 0.2, 2.5, "studs", 31, function() end)
M.F.MakeSlider(pWrld, "LightDur", "LightningDuration", 0.1, 3.0, "с", 32, function() end)
M.F.MakeToggle(pWrld, "Meteors", "MeteorOn", 33, function() end, false)
M.F.MakeSlider(pWrld, "MetRate", "MeteorRate", 1, 10, "x", 34, function() end)
M.F.MakeSlider(pWrld, "MetSize", "MeteorSize", 1, 8, "studs", 35, function() end)
M.F.MakeSlider(pWrld, "MetTail", "MeteorTrailLen", 0.3, 3.5, "с", 36, function() end)
M.F.MakeSlider(pWrld, "MetDur", "MeteorDuration", 0.5, 5.0, "с", 37, function() end)
M.F.MakePicker(pWrld, "MetCol", "MeteorColor", 38, function() end)

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

-- Misc
M.F.MakeSection(pMisc, "Sec_SilhouetteMod", 1)
M.F.MakeToggle(pMisc, "PitchMod", "PitchModification", 2, function() end, false)
M.F.MakeSlider(pMisc, "PitchAngle", "PitchAngle", -90, 90, "°", 3, function() end)
M.F.MakeToggle(pMisc, "RotationYaw", "RotationYaw", 4, function() end, true)
M.F.MakeSlider(pMisc, "YawSpeed", "YawSpeed", 5, 100, "", 5, function() end)
M.F.MakeToggle(pMisc, "JitterSpin", "JitterSpin", 6, function() end, false)

M.F.MakeSection(pMisc, "Sec_NetworkMod", 7)
M.F.MakeToggle(pMisc, "PacketChoke", "PacketChoke", 8, function() end, true)
M.F.MakeSlider(pMisc, "LagTicks", "LagTicks", 1, 999, "кадров", 9, function() end)
M.F.MakeSlider(pMisc, "LagLimit", "LagLimit", 0.01, 60.0, "с", 10, function() end)
M.F.MakeToggle(pMisc, "BacktrackShadows", "BacktrackShadows", 11, function(on) if not on then M.ClearGhosts() end end, false)
M.F.MakeDropdown(pMisc, "GhostMat", {"Neon", "ForceField", "SmoothPlastic"}, "GhostMat", 12, function() M.ClearGhosts() end)
M.F.MakeSlider(pMisc, "GhostCount", "GhostCount", 1, 5, "штук", 13, function() M.ClearGhosts() end)
M.F.MakeSlider(pMisc, "GhostAlpha", "GhostAlpha", 0.05, 0.9, "", 14, function() end)
M.F.MakePicker(pMisc, "GhostCol", "GhostCol", 15, function() end)

-- System
M.F.MakeSection(pSys, "Sec_Performance", 1)
M.F.MakeToggle(pSys, "FpsBoost", "FpsBoost", 2, function(v) M.ApplyFpsBoost(v) end, true)

M.F.MakeSection(pSys, "Sec_Framerate", 3)
M.F.MakeToggle(pSys, "FpsUnlocker", "FpsUnlocker", 4, function(v) M.ApplyFpsUnlocker(v) end, true)

-- Configs UI
local cfgInputCard = M.F.MakeCard(pCfg, 42); cfgInputCard.LayoutOrder = 1
local cfgInput = Instance.new("TextBox", cfgInputCard)
cfgInput.Size = UDim2.new(0.65, 0, 0, 26); cfgInput.Position = UDim2.new(0, 10, 0.5, -13)
cfgInput.BackgroundColor3 = Color3.fromRGB(15, 17, 24); cfgInput.Text = "default"; cfgInput.TextColor3 = Color3.fromRGB(240, 245, 255)
cfgInput.Font = Enum.Font.GothamBold; cfgInput.TextSize = 12; cfgInput.BorderSizePixel = 0
Instance.new("UICorner", cfgInput).CornerRadius = UDim.new(0, 6)

local cfgStatusCard = M.F.MakeCard(pCfg, 28); cfgStatusCard.LayoutOrder = 2
local cfgStatus = Instance.new("TextLabel", cfgStatusCard)
cfgStatus.Size = UDim2.new(1, 0, 1, 0); cfgStatus.BackgroundTransparency = 1; cfgStatus.Text = (writefile and readfile and isfile) and "Хранилище: файл на диске" or "Хранилище: только память (в Studio файлы недоступны)"
cfgStatus.TextColor3 = M.State.Accent; cfgStatus.Font = Enum.Font.GothamBold; cfgStatus.TextSize = 11

local btnRow = M.F.MakeCard(pCfg, 38); btnRow.LayoutOrder = 3
local function makeCfgBtn(text, posScale, widthScale, cb)
    local b = Instance.new("TextButton", btnRow)
    b.Size = UDim2.new(widthScale, 0, 0, 26); b.Position = UDim2.new(posScale, 0, 0.5, -13)
    b.BackgroundColor3 = Color3.fromRGB(28, 32, 44); b.Text = text; b.TextColor3 = Color3.fromRGB(240, 245, 255)
    b.Font = Enum.Font.GothamBold; b.TextSize = 11; Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(cb)
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
        b.Text = "  " .. name .. (isAuto and " [АВТО]" or "")
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

makeCfgBtn("Сохранить", 0.01, 0.23, function()
    local name = cfgInput.Text:gsub("%s+", "")
    if M.CFG.Save(name) then
        M.State.SelectedCfg = name
        cfgStatus.Text = "Сохранен: " .. name
        refreshCfgListUI()
    end
end)

makeCfgBtn("Загрузить", 0.26, 0.23, function()
    local name = cfgInput.Text:gsub("%s+", "")
    if M.CFG.Load(name) then
        cfgStatus.Text = "Загружен: " .. name
    else
        cfgStatus.Text = "Не найден"
    end
end)

makeCfgBtn("Авто", 0.51, 0.23, function()
    local name = cfgInput.Text:gsub("%s+", "")
    M.CFG.SetAutoload(name)
    cfgStatus.Text = "Автозагрузка: " .. name
    refreshCfgListUI()
end)

makeCfgBtn("Удалить", 0.76, 0.23, function()
    local name = cfgInput.Text:gsub("%s+", "")
    if M.CFG.Delete(name) then
        M.State.SelectedCfg = "default"
        cfgInput.Text = "default"
        cfgStatus.Text = "Удален: " .. name
        refreshCfgListUI()
    end
end)

refreshCfgListUI()

-- Settings
M.F.MakeSection(pSet, "Sec_UiTheme", 1)
M.F.MakeDropdown(pSet, "LangBtn", {"EN", "RU"}, "Language", 2, function(v)
    M.L10N.Current = v
    M.F.UpdateLanguageUI()
end)
M.F.MakeSlider(pSet, "AnimSpeed", "AnimSpeed", 0.05, 0.5, "с", 3, function() end)
M.F.MakeSlider(pSet, "MainAlpha", "MenuAlpha", 0, 1, "", 4, function(v)
    M.UI.Main.BackgroundTransparency = v
    M.UI.PrevCard.BackgroundTransparency = v
end)
M.F.MakePicker(pSet, "MainCol", "MainBg", 5, function(col)
    M.UI.Main.BackgroundColor3 = col
    M.UI.PrevCard.BackgroundColor3 = col
end)
M.F.MakeSlider(pSet, "CardAlpha", "CardAlpha", 0, 1, "", 6, function(v)
    for _, c in ipairs(M.State.Cards) do c.BackgroundTransparency = v end
end)
M.F.MakePicker(pSet, "CardCol", "CardBg", 7, function(col)
    for _, c in ipairs(M.State.Cards) do c.BackgroundColor3 = col end
end)
M.F.MakePicker(pSet, "AccentCol", "Accent", 8, function(col)
    for _, f in ipairs(M.State.Sliders) do f.BackgroundColor3 = col end
    M.F.SwitchTab(M.State.ActiveTab)
end)
M.F.MakeSlider(pSet, "BorderThick", "BorderThick", 0, 5, "px", 9, function(v)
    local t = math.round(v)
    M.UI.MainStroke.Thickness = t
    M.UI.PrevStroke.Thickness = t
    M.UI.SideStroke.Thickness = t
end)
M.F.MakePicker(pSet, "BorderCol", "BorderCol", 10, function(col)
    M.UI.MainStroke.Color = col
    M.UI.PrevStroke.Color = col
    M.UI.SideStroke.Color = col
end)

M.F.MakeSection(pSet, "Sec_UiSidebar", 11)
M.F.MakeSlider(pSet, "SideAlpha", "SideAlpha", 0, 1, "", 12, function(v) M.UI.Sidebar.BackgroundTransparency = v end)
M.F.MakePicker(pSet, "SideCol", "SideBg", 13, function(col) M.UI.Sidebar.BackgroundColor3 = col end)
M.F.MakeSlider(pSet, "SideCardAlpha", "SideCardAlpha", 0, 1, "", 14, function(v)
    for _, sc in ipairs(M.State.SideCards) do sc.BackgroundTransparency = v end
    M.F.SwitchTab(M.State.ActiveTab)
end)
M.F.MakePicker(pSet, "SideCardCol", "SideCardBg", 15, function(col)
    for _, sc in ipairs(M.State.SideCards) do sc.BackgroundColor3 = col end
    M.F.SwitchTab(M.State.ActiveTab)
end)
M.F.MakePicker(pSet, "LogoCol", "LogoCol", 16, function(col)
    M.UI.Logo.TextColor3 = col
    M.UI.LogoGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, col:Lerp(Color3.fromRGB(80, 80, 80), 0.4)),
        ColorSequenceKeypoint.new(0.5, col),
        ColorSequenceKeypoint.new(1, col:Lerp(Color3.fromRGB(80, 80, 80), 0.4))
    })
end)

M.F.MakeSection(pSet, "Sec_UiPill", 17)
M.F.MakeSlider(pSet, "PillScale", "PillScaleVal", 0.7, 1.6, "x", 18, function(v) M.UI.PillScale.Scale = v end)
M.F.MakeToggle(pSet, "PillUser", "PillShowUser", 19, function() end, false)
M.F.MakeToggle(pSet, "PillMem", "PillShowMem", 20, function() end, false)
M.F.MakeToggle(pSet, "PillMinsk", "PillShowMinsk", 21, function() end, false)
M.F.MakeToggle(pSet, "PillSession", "PillShowTime", 22, function() end, false)
M.F.MakeSlider(pSet, "PillBorderThick", "PillBorderThick", 0, 5, "px", 23, function(v) M.UI.PillStroke.Thickness = math.round(v) end)
M.F.MakePicker(pSet, "PillBorderCol", "PillBorderCol", 24, function(col) M.UI.PillStroke.Color = col end)
M.F.MakeSlider(pSet, "PillAlpha", "PillAlpha", 0, 1, "", 25, function(v) M.UI.Pill.BackgroundTransparency = v end)
M.F.MakePicker(pSet, "PillBg", "PillBg", 26, function(col) M.UI.Pill.BackgroundColor3 = col end)
M.F.MakePicker(pSet, "PillTextCol", "PillTextCol", 27, function(col) M.UI.PillTxt.TextColor3 = col end)

-- ==============================================================================
-- [ MENU LIFECYCLE & CLEANUP ]
-- ==============================================================================
M.F.CloseMenu = function()
    M.State.MenuOpen = false
    M.Data.MenuToken = M.Data.MenuToken + 1
    local token = M.Data.MenuToken
    if M.UI.PrevCard.Visible then M.UI.PrevCard.Visible = false end
    M.UI.Tooltip.Visible = false
    M.Services.T:Create(M.UI.MainScale, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.85}):Play()
    task.delay(M.State.AnimSpeed, function()
        -- Если за это время меню снова открыли, прятать его уже нельзя
        if token ~= M.Data.MenuToken then return end
        M.UI.Main.Visible = false
        M.UI.MainScale.Scale = 1
    end)
end

M.F.OpenMenu = function()
    M.State.MenuOpen = true
    M.Data.MenuToken = M.Data.MenuToken + 1
    M.UI.Main.Visible = true
    M.UI.MainScale.Scale = 0.85
    M.Services.T:Create(M.UI.MainScale, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
    if M.State.ActiveTab == "ESP" then
        M.F.SyncPreviewPos()
        M.UI.PrevCard.Visible = true
        M.F.Update2DPreview()
    end
end

M.F.Uninject = function()
    M.State.IsUninjected = true
    pcall(function() M.Services.R:UnbindFromRenderStep("MatsysenseCameraProcessor") end)
    
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

    if M.UI.NoclipLoop then M.UI.NoclipLoop:Disconnect(); M.UI.NoclipLoop = nil end

    M.F.StopFlying()
    M.F.SetNoclip(false)
    M.ApplyFpsBoost(false)
    M.ApplyFpsUnlocker(false)
    M.State.Esp = false; M.F.UpdateEsp()
    M.State.FogOn = false; M.F.ApplyFog()
    M.State.CloudsOn = false; M.F.ApplyClouds()
    M.State.SkyOn = false; M.F.RestoreSky()
    M.State.DarkWorld = false; M.F.ApplyDark()
    M.State.TimeOn = false; M.Services.L.ClockTime = M.State.OrigTime
    M.State.WeatherOn = false; M.F.ClearWeatherProps()
    M.State.BacktrackShadows = false; M.ClearGhosts()
    M.State.HatOn = false; if M.State.HatModel then M.State.HatModel:Destroy() end
    M.State.OrbitOn = false; for _, item in ipairs(M.State.OrbitObjs) do if item.Part then item.Part:Destroy() end end
    
    local cam = workspace.CurrentCamera
    -- Возвращаем FOV, который был в игре (раньше всегда ставилось 70)
    if cam and M.Data.FovForced then cam.FieldOfView = M.Data.OrigFov end

    -- Раньше тут принудительно ставили WalkSpeed = 16 и CanCollide = true для всех деталей.
    -- Это ломало игры с другой скоростью и превращало шапки в твёрдые объекты. Теперь возвращаем только своё.
    M.State.ThirdPerson = false
    M.F.UpdateThirdPerson(cam, nil, nil, false)
    M.State.StateForce = false
    M.F.UpdateStateForce()
    M.State.HideHats = false
    M.State.HoloSelf = false
    M.UpdatePlayerVisuals()
    M.State.NetworkAlive = false
    M.F.SetAntiAfk(false)

    local char = M.LP and M.LP.Character
    if char then
        for joint, origC0 in pairs(M.State.OrigC0Cache) do
            if joint and joint.Parent then joint.C0 = origC0 end
        end
    end

    pcall(function()
        M.UI.Gui:Destroy()
        M.UI.EspGui:Destroy()
        M.UI.wFolder:Destroy()
        M.UI.kFolder:Destroy()
        M.UI.lFolder:Destroy()
        M.UI.mFolder:Destroy()
        M.UI.vFolder:Destroy()
        M.UI.cCache:Destroy()
        M.UI.gFolder:Destroy()
        M.UI.jFolder:Destroy()
    end)
end

M.UI.Main.Visible = false

-- ==============================================================================
-- [ INTRO AND INITIAL LAUNCH ]
-- ==============================================================================
task.spawn(function()
    M.CFG.CheckAutoload()

    local introGui = Instance.new("ScreenGui")
    introGui.Name = "MatsysenseIntro"
    introGui.ResetOnSpawn = false
    introGui.DisplayOrder = 99999
    introGui.IgnoreGuiInset = true
    introGui.Parent = M.TargetGui

    local blackOverlay = Instance.new("Frame", introGui)
    blackOverlay.Size = UDim2.new(1, 0, 1, 36)
    blackOverlay.Position = UDim2.new(0, 0, 0, -36)
    blackOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    blackOverlay.BackgroundTransparency = 1
    blackOverlay.BorderSizePixel = 0

    local introText = Instance.new("TextLabel", blackOverlay)
    introText.Size = UDim2.new(1, 0, 0, 70)
    introText.Position = UDim2.new(0, 0, 0.5, -35)
    introText.BackgroundTransparency = 1
    introText.Text = "matsysense"
    introText.TextColor3 = Color3.fromRGB(255, 255, 255)
    introText.TextTransparency = 1
    introText.Font = Enum.Font.GothamBlack
    introText.TextSize = 38

    local sheenGrad = Instance.new("UIGradient", introText)
    sheenGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 115, 130)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 115, 130))
    })
    sheenGrad.Rotation = 45
    sheenGrad.Offset = Vector2.new(-1, 0)

    local twIn = M.Services.T:Create(blackOverlay, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
    twIn:Play()
    twIn.Completed:Wait()
    task.wait(0.2)

    local twTxt = M.Services.T:Create(introText, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {TextTransparency = 0})
    twTxt:Play()
    twTxt.Completed:Wait()
    task.wait(0.2)

    local twSheen = M.Services.T:Create(sheenGrad, TweenInfo.new(1.2, Enum.EasingStyle.Linear), {Offset = Vector2.new(1, 0)})
    twSheen:Play()
    twSheen.Completed:Wait()
    task.wait(0.3)

    M.Services.T:Create(introText, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1}):Play()
    local twOut = M.Services.T:Create(blackOverlay, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
    twOut:Play()
    twOut.Completed:Wait()

    introGui:Destroy()

    M.F.SwitchTab("Combat")
    M.F.OpenMenu()
end)

-- ==============================================================================
-- [ МОДУЛЬНЫЕ ТЕСТЫ ]
-- Включаются флагом RUN_SELF_TESTS в начале файла. Результат выводится в Output.
-- ==============================================================================
function M.RunSelfTests()
    local passed, failed = 0, 0

    local function test(name, fn)
        local ok, err = pcall(fn)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            warn("[Matsysense tests] ПРОВАЛ: " .. name .. " -> " .. tostring(err))
        end
    end

    local function expectEqual(actual, expected, label)
        if actual ~= expected then
            error((label or "значение") .. ": ожидалось " .. tostring(expected) .. ", получено " .. tostring(actual), 2)
        end
    end

    local function expectNear(actual, expected, label)
        if math.abs(actual - expected) > 1e-6 then
            error((label or "значение") .. ": ожидалось " .. tostring(expected) .. ", получено " .. tostring(actual), 2)
        end
    end

    -- ----- ColorMath.ResolveHue -----
    test("ResolveHue: белый цвет сохраняет прежний оттенок", function()
        expectNear(M.ColorMath.ResolveHue(0.6, 0, 0, 1), 0.6)
    end)
    test("ResolveHue: чёрный цвет сохраняет прежний оттенок", function()
        expectNear(M.ColorMath.ResolveHue(0.6, 0, 1, 0), 0.6)
    end)
    test("ResolveHue: насыщенный цвет берёт новый оттенок", function()
        expectNear(M.ColorMath.ResolveHue(0.6, 0.1, 0.8, 0.9), 0.1)
    end)
    test("ResolveHue: граница saturation = 0.001 считается серым", function()
        expectNear(M.ColorMath.ResolveHue(0.6, 0.1, 0.001, 0.9), 0.6)
    end)
    test("ResolveHue: чуть выше границы считается цветным", function()
        expectNear(M.ColorMath.ResolveHue(0.6, 0.1, 0.0011, 0.9), 0.1)
    end)

    -- ----- ColorMath.PrepareForHueChange -----
    test("PrepareForHueChange: белый становится насыщенным", function()
        local s2, v2 = M.ColorMath.PrepareForHueChange(0, 1)
        expectNear(s2, 0.55, "saturation")
        expectNear(v2, 1, "value")
    end)
    test("PrepareForHueChange: чёрный становится светлым", function()
        local s2, v2 = M.ColorMath.PrepareForHueChange(1, 0)
        expectNear(s2, 1, "saturation")
        expectNear(v2, 1, "value")
    end)
    test("PrepareForHueChange: нормальный цвет не меняется", function()
        local s2, v2 = M.ColorMath.PrepareForHueChange(0.8, 0.7)
        expectNear(s2, 0.8, "saturation")
        expectNear(v2, 0.7, "value")
    end)
    test("PrepareForHueChange: границы 0.05 и 0.15 не меняются", function()
        local s2, v2 = M.ColorMath.PrepareForHueChange(0.05, 0.15)
        expectNear(s2, 0.05, "saturation")
        expectNear(v2, 0.15, "value")
    end)
    test("PrepareForHueChange: чуть ниже границ меняется", function()
        local s2, v2 = M.ColorMath.PrepareForHueChange(0.049, 0.149)
        expectNear(s2, 0.55, "saturation")
        expectNear(v2, 1, "value")
    end)
    test("Сценарий: белый туман, сдвиг оттенка даёт видимый цвет", function()
        local s2, v2 = M.ColorMath.PrepareForHueChange(0, 1)
        expectEqual(s2 > 0.05 and v2 > 0.15, true, "цвет должен стать видимым")
    end)

    -- ----- ParseSkyIds -----
    local function faces(text) return M.F.ParseSkyIds(text) end

    test("ParseSkyIds: один ID идёт на все 6 граней", function()
        local f, key = faces("123456789")
        expectEqual(key, "Sky_Ok1", "ключ")
        expectEqual(#f, 6, "граней")
        for i = 1, 6 do expectEqual(f[i], "rbxassetid://123456789", "грань " .. i) end
    end)
    test("ParseSkyIds: принимает формат rbxassetid://", function()
        local f = faces("rbxassetid://987654321")
        expectEqual(f[1], "rbxassetid://987654321")
    end)
    test("ParseSkyIds: достаёт ID из ссылки магазина", function()
        local f = faces("https://create.roblox.com/store/asset/132703927222924/Sky-Sunset-new?pagePosition=3")
        expectEqual(f[1], "rbxassetid://132703927222924")
    end)
    test("ParseSkyIds: шесть ID сохраняют порядок", function()
        local f, key = faces("11111, 22222, 33333, 44444, 55555, 66666")
        expectEqual(key, "Sky_Ok6", "ключ")
        expectEqual(f[1], "rbxassetid://11111", "Bk")
        expectEqual(f[6], "rbxassetid://66666", "Up")
    end)
    test("ParseSkyIds: разделители пробел и точка с запятой", function()
        local f = faces("11111 22222;33333,44444  55555 66666")
        expectEqual(#f, 6, "граней")
    end)
    test("ParseSkyIds: не-ID даёт ошибку Sky_BadId", function()
        local f, key, arg = faces("abc")
        expectEqual(f, nil, "граней")
        expectEqual(key, "Sky_BadId", "ключ")
        expectEqual(arg, "abc", "аргумент")
    end)
    test("ParseSkyIds: слишком короткий ID", function()
        local _, key = faces("1234")
        expectEqual(key, "Sky_BadId")
    end)
    test("ParseSkyIds: слишком длинный ID (20 цифр)", function()
        local _, key = faces("12345678901234567890")
        expectEqual(key, "Sky_BadId")
    end)
    test("ParseSkyIds: три ID дают Sky_BadCount", function()
        local f, key, arg = faces("11111, 22222, 33333")
        expectEqual(f, nil, "граней")
        expectEqual(key, "Sky_BadCount", "ключ")
        expectEqual(arg, 3, "количество")
    end)
    test("ParseSkyIds: пустая строка и nil дают Sky_Idle", function()
        local _, key1 = faces("")
        local _, key2 = faces(nil)
        expectEqual(key1, "Sky_Idle", "пустая строка")
        expectEqual(key2, "Sky_Idle", "nil")
    end)

    print(string.format("[Matsysense tests] пройдено: %d, провалено: %d", passed, failed))
    return failed == 0
end

if RUN_SELF_TESTS then
    M.RunSelfTests()
end

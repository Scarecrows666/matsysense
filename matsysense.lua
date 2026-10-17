-- Script 14 v13
local Current
-- модульная сборка: 69 модулей по порядку, у всех общая таблица M, общие локальные - через __X
-- если модуль упал, его имя будет в getgenv().__MatsysenseLastError

local MODULES = {}

-- [1/69] Ядро: сервисы, журнал ошибок, словарь текстов, состояние
MODULES[#MODULES + 1] = {"1. Ядро: сервисы, журнал ошибок, словарь текстов, состояние", function(M, __X)

-- в консоль ничего не пишем, ошибки копятся здесь
M.Errors = {List = {}, Total = 0, Count = {}, Seen = {}}
function M.Quiet(msg)
    local list = M.Errors.List
    list[#list + 1] = {At = os.clock(), Msg = tostring(msg)}
    if #list > 30 then table.remove(list, 1) end
end

-- считаем каждую ошибку, а текст пишем не чаще раза в 5 с на имя
function M.Errors.Hit(name, err)
    local E = M.Errors
    E.Total = E.Total + 1
    E.Count[name] = (E.Count[name] or 0) + 1
    local now = os.clock()
    if E.Seen[name] and now - E.Seen[name] < 5 then return end
    E.Seen[name] = now
    M.Quiet("[Matsysense] Ошибка в " .. name .. ": " .. tostring(err))
end

-- единое место проверок возможностей исполнителя
M.Cap = {Names = {"mouse1click", "mouse1press", "mouse1release", "mousemoverel", "isrbxactive", "iswindowactive", "writefile",
    "readfile", "isfile", "setfpscap", "set_fps_cap", "setclipboard", "getclipboard", "gethui", "cloneref", "identifyexecutor"}}
M.Cap.Roots = {
    function() return getgenv() end,
    function() return getfenv(0) end,
    function() return getfenv() end,
    function() return _G end,
    function() return shared end,
}
function M.Cap.Walk(root, path)
    local node = root()
    for part in string.gmatch(path, "[^%.]+") do
        if node == nil then return nil end
        node = node[part]
    end
    return node
end
-- найденная функция запоминается; отсутствующую ищем заново не чаще раза в 5 с
M.Cap.Found, M.Cap.MissAt = {}, {}
function M.Cap.Fn(path)
    local found = M.Cap.Found[path]
    if found then return found end
    local now = os.clock()
    local miss = M.Cap.MissAt[path]
    if miss and now - miss < 5 then return nil end
    for _, root in ipairs(M.Cap.Roots) do
        local ok, fn = pcall(M.Cap.Walk, root, path)
        if ok and fn ~= nil and (type(fn) == "function" or typeof(fn) == "function") then
            M.Cap.Found[path] = fn
            M.Cap.MissAt[path] = nil
            return fn
        end
    end
    M.Cap.MissAt[path] = now
    return nil
end

-- забыть найденное (исполнитель подменил функции)
function M.Cap.Reset()
    table.clear(M.Cap.Found)
    table.clear(M.Cap.MissAt)
end
function M.Cap.Has(path) return M.Cap.Fn(path) ~= nil end
-- вызов функции исполнителя в pcall
function M.Cap.Call(path, ...)
    local fn = M.Cap.Fn(path)
    if not fn then return false, "нет функции " .. tostring(path) end
    return pcall(fn, ...)
end
-- все ли перечисленные функции есть
function M.Cap.All(...)
    for i = 1, select("#", ...) do
        if not M.Cap.Fn((select(i, ...))) then return false end
    end
    return true
end
-- строка для отчёта
function M.Cap.Report()
    local out = {}
    for _, name in ipairs(M.Cap.Names) do out[#out + 1] = name .. "=" .. (M.Cap.Has(name) and "да" or "нет") end
    return table.concat(out, " ")
end

-- повторный запуск
do
    local okEnv, env = pcall(function() return getgenv and getgenv() or nil end)
    if okEnv and type(env) == "table" and type(env.__MatsysenseShutdown) == "function" then
        pcall(env.__MatsysenseShutdown)
        env.__MatsysenseShutdown = nil
    end
end

-- дожидаемся загрузки игры
if not game:IsLoaded() then
    pcall(function() game.Loaded:Wait() end)
end

-- сервис берётся в pcall
local function getService(name)
    local ok, service = pcall(function() return game:GetService(name) end)
    if not ok or not service then return nil end
    if typeof(cloneref) == "function" then
        local okC, cloned = pcall(cloneref, service)
        if okC and cloned then return cloned end
    end
    return service
end

M.Services = {
    P = getService("Players"),
    R = getService("RunService"),
    U = getService("UserInputService"),
    T = getService("TweenService"),
    L = getService("Lighting"),
    D = getService("Debris"),
    S = getService("Stats"),
    I = getService("InsertService"),
    C = getService("ContentProvider"),
    H = getService("HttpService"),
    Text = getService("TextService")
}

M.LP = M.Services.P.LocalPlayer
if not M.LP then
    M.Services.P:GetPropertyChangedSignal("LocalPlayer"):Wait()
    M.LP = M.Services.P.LocalPlayer
end

-- контейнер подходит, только если в него реально можно положить объект
local function canHost(container)
    if not container then return false end
    local ok = pcall(function()
        local probe = Instance.new("Folder")
        probe.Parent = container
        probe:Destroy()
    end)
    return ok
end

-- интерфейс живёт только в gethui()
local function getIsolatedContainer()
    local candidates = {
        function() return gethui end,
        function() return getgenv().gethui end,
    }
    for _, get in ipairs(candidates) do
        local okFn, fn = pcall(get)
        if okFn and typeof(fn) == "function" then
            local okHui, hui = pcall(fn)
            if okHui and canHost(hui) then return hui end
        end
    end
    return nil
end
M.TargetGui = getIsolatedContainer()
-- без gethui интерфейсу негде жить
if not M.TargetGui then pcall(function() warn("[Matsysense] gethui недоступен в этом исполнителе: интерфейс не создан, скрипт остановлен") end) end
if not M.TargetGui then return false end

M.RayParams = RaycastParams.new()
M.RayParams.FilterType = Enum.RaycastFilterType.Exclude
M.RayParams.IgnoreWater = true

M.ScratchParams = RaycastParams.new()
M.ScratchParams.FilterType = Enum.RaycastFilterType.Exclude
M.ScratchParams.IgnoreWater = true


M.L10N = {
    Current = "RU",
    Dict = {
        Tab_Combat = {RU = "Бой", EN = "Combat"},
        Tab_Movement = {RU = "Движение", EN = "Movement"},
        Tab_Camera = {RU = "Камера", EN = "Camera"},
        Tab_Display = {RU = "Игроки", EN = "Players"},
        Tab_World = {RU = "Окружение", EN = "World"},
        Tab_Player = {RU = "Персонаж", EN = "Character"},
        Tab_Misc = {RU = "Разное", EN = "Misc"},
        Tab_System = {RU = "Система", EN = "System"},
        Tab_Configs = {RU = "Конфиги", EN = "Configs"},
        Tab_Settings = {RU = "Настройки", EN = "Settings"},

        Sec_AimAssist = {RU = "Помощь в прицеливании", EN = "Aim Assist"},
        Sec_TriggerAssist = {RU = "Автоматический выстрел", EN = "Auto Fire"},
        Sec_Defense = {RU = "Защита персонажа", EN = "Character Protection"},
        Sec_CameraMain = {RU = "Управление камерой", EN = "Camera Control"},
        Sec_PlayerViewBase = {RU = "Видимость игроков", EN = "Player Visibility"},
        PlayerViewMaxDist = {RU = "Дальность прорисовки", EN = "Draw Distance"},
        Sec_PlayerViewHl = {RU = "Подсветка силуэта", EN = "Silhouette Highlight"},
        Sec_Feedback = {RU = "Обратная связь при попаданиях", EN = "Hit Feedback"},
        Sec_Flight = {RU = "Полёт и проход сквозь стены", EN = "Flight & Noclip"},
        Sec_Sprint = {RU = "Ускорение бега", EN = "Sprint Boost"},
        Sec_AirJump = {RU = "Воздух и прыжки", EN = "Air & Jumping"},
        Sec_Teleport = {RU = "Телепорт", EN = "Teleport"},
        Sec_ThirdPerson = {RU = "Третье лицо", EN = "Third Person"},
        Sec_Lightning = {RU = "Молнии", EN = "Lightning"},
        Sec_Meteors = {RU = "Метеориты", EN = "Meteors"},
        Sec_Spin = {RU = "Вращение", EN = "Spin"},
        Sec_Desync = {RU = "Заморозка и лаги", EN = "Freeze & Lag Effect"},
        Sec_UiGeneral = {RU = "Общее", EN = "General"},
        Sec_PlayerViewBoxes = {RU = "Рамки и подписи", EN = "Boxes & Labels"},
        Sec_PlayerViewHealth = {RU = "Шкала здоровья", EN = "Health Bar"},
        Sec_PlayerViewLines = {RU = "Линии до игроков", EN = "Player Lines"},
        Sec_WorldFog = {RU = "Туман", EN = "Fog"},
        Sec_WorldClouds = {RU = "Облака", EN = "Clouds"},
        Sec_WorldWeather = {RU = "Погода", EN = "Weather"},
        Sec_PlyrModel = {RU = "Внешний вид модели", EN = "Model Appearance"},
        Sec_PlyrJump = {RU = "Следы от прыжка", EN = "Jump Trails"},
        Sec_Arrows = {RU = "Стрелки за краем экрана", EN = "Off-screen Arrows"},
        ArrowsOn = {RU = "Стрелки на врагов за экраном", EN = "Arrows to Off-screen Enemies"},
        ArrowCol = {RU = "Цвет стрелки (для одного цвета)", EN = "Arrow Color (single color)"},
        ArrowSize = {RU = "Размер стрелок", EN = "Arrow Size"},
        ArrowRadius = {RU = "Радиус от центра экрана", EN = "Radius from Screen Center"},
        ArrowDistance = {RU = "Дистанция на стрелках", EN = "Distance on Arrows"},
        Sec_Skeleton = {RU = "Скелет", EN = "Skeleton"},
        PlayerViewSkeleton = {RU = "Показывать скелет", EN = "Show Skeleton"},
        SkeletonCol = {RU = "Цвет скелета", EN = "Skeleton Color"},
        SkeletonThick = {RU = "Толщина линий", EN = "Line Thickness"},
        SkeletonHealthColor = {RU = "Цвет по здоровью", EN = "Color by Health"},
        Sec_KillFx = {RU = "Эффект убийства", EN = "Kill Effect"},
        KillFxOn = {RU = "Частицы и растворение при смерти (и у вас)", EN = "Particles & Dissolve on Death (including you)"},
        KillFxType = {RU = "Тип частиц", EN = "Particle Type"},
        Opt_Cloud = {RU = "Облако", EN = "Cloud"},
        Opt_Sparks = {RU = "Искры", EN = "Sparks"},
        KillFxColor = {RU = "Цвет частиц", EN = "Particle Color"},
        KillFxSpeed = {RU = "Скорость частиц", EN = "Particle Speed"},
        Sec_Tracers = {RU = "Следы от пуль", EN = "Bullet Trails"},
        TracerOn = {RU = "Следы от ваших выстрелов", EN = "Trails from Your Shots"},
        TracerCol = {RU = "Цвет следа пули", EN = "Bullet Trail Color"},
        TracerIntensity = {RU = "Интенсивность", EN = "Intensity"},
        TracerSize = {RU = "Размер (толщина) следа", EN = "Trail Size (thickness)"},
        TracerGlow = {RU = "Свечение материала", EN = "Material Glow"},
        TracerLength = {RU = "Длина (время жизни)", EN = "Length (lifetime)"},
        Sec_Trail = {RU = "Шлейф за персонажем", EN = "Character Trail"},
        TrailOn = {RU = "Включить шлейф", EN = "Enable Trail"},
        TrailCol = {RU = "Цвет шлейфа", EN = "Trail Color"},
        TrailIntensity = {RU = "Интенсивность", EN = "Intensity"},
        TrailGlow = {RU = "Свечение материала", EN = "Material Glow"},
        TrailLength = {RU = "Длина шлейфа", EN = "Trail Length"},
        Sec_PlyrAccessories = {RU = "Сферы вокруг тела", EN = "Body Spheres"},
        Sec_SilhouetteMod = {RU = "Поза персонажа", EN = "Character Pose"},
        Sec_Performance = {RU = "Оптимизация текстур", EN = "Texture Optimization"},
        Sec_Framerate = {RU = "Частота кадров", EN = "Framerate"},
        Sec_UiTheme = {RU = "Оформление меню", EN = "Main UI Appearance"},
        Sec_UiSidebar = {RU = "Боковая панель", EN = "Sidebar Styling"},
        Sec_UiPill = {RU = "Информационная панель", EN = "Info Panel"},

        AimAssist = {RU = "Включить наводку прицела", EN = "Enable Aim Assist"},
        AimTeamCheck = {RU = "Не наводить на своих", EN = "Ignore Teammates"},
        AimFov = {RU = "Радиус наведения на экране", EN = "Aim Radius on Screen"},
        ShowFov = {RU = "Показывать круг наведения", EN = "Show Aim Circle"},
        AimTime = {RU = "Время доводки (0 = сразу)", EN = "Aim Time (0 = instant)"},
        AimWallCheck = {RU = "Не наводить через стены", EN = "Don't Aim Through Walls"},

        TriggerAssist = {RU = "Стрелять при наведении", EN = "Fire on Target"},
        TriggerTeamCheck = {RU = "Не стрелять по своим", EN = "Ignore Teammates"},
        TriggerLoop = {RU = "Стрелять непрерывно", EN = "Continuous Fire"},
        TriggerDelay = {RU = "Задержка перед выстрелом", EN = "Fire Delay"},
        TriggerWallCheck = {RU = "Не стрелять через стены", EN = "Don't Fire Through Walls"},

        FlightMode = {RU = "Режим полета", EN = "Flight Mode"},
        SprintBoost = {RU = "Ускорение бега", EN = "Sprint Boost"},
        FlightSpeed = {RU = "Скорость полёта", EN = "Flight Speed"},
        SprintSpeed = {RU = "Скорость бега", EN = "Sprint Speed"},
        AirControl = {RU = "Управление в прыжке", EN = "Mid-air Control"},
        Sec_Peek = {RU = "Пик-ассист", EN = "Peek Assist"},
        PeekOn = {RU = "Пик-ассист (после выстрела назад на точку)", EN = "Peek Assist (back to the point after a shot)"},
        PeekKey = {RU = "Клавиша точки (удерживать)", EN = "Point Key (hold)"},
        PeekColor = {RU = "Цвет точек (пик-ассист и телепорт)", EN = "Point Color (peek and teleport)"},
        PeekSize = {RU = "Размер точек", EN = "Point Size"},
        AimDynamic = {RU = "Динамическая зона доводки (сжимается на месте, растёт при движении)", EN = "Dynamic Aim Zone (shrinks standing, grows moving)"},
        AimZone_Info = {RU = "Зона %d px (x%.2f): %s", EN = "Zone %d px (x%.2f): %s"},
        AimSt_Stand = {RU = "стою", EN = "standing"},
        AimSt_Walk = {RU = "иду", EN = "walking"},
        AimSt_Air = {RU = "в воздухе", EN = "airborne"},
        AimDynStand = {RU = "Зона, когда стоите (множитель)", EN = "Zone When Standing (multiplier)"},
        AimDynWalk = {RU = "Зона при ходьбе (множитель)", EN = "Zone When Walking (multiplier)"},
        AimDynJump = {RU = "Зона в прыжке и падении (множитель)", EN = "Zone In The Air (multiplier)"},
        AimDebug = {RU = "Показывать, почему враг захвачен или нет (отладка зоны)", EN = "Show why an enemy is captured or not (zone debug)"},
        AimLagComp = {RU = "Компенсировать отставание плавной наводки (меньше промахов по бегущим)", EN = "Compensate Smoothing Lag (fewer misses on moving targets)"},
        AimWhy_Chosen = {RU = "захват", EN = "locked"},
        AimWhy_Ok = {RU = "в зоне", EN = "in zone"},
        AimWhy_Wall = {RU = "за стеной", EN = "behind wall"},
        AimWhy_Zone = {RU = "вне зоны", EN = "outside zone"},
        AimWhy_Team = {RU = "союзник", EN = "teammate"},
        AimWhy_Far = {RU = "далеко/щит", EN = "too far/shield"},
        FovFillOn = {RU = "Заливка внутри зоны доводки", EN = "Fill Inside The Aim Zone"},
        FovFillAlpha = {RU = "Прозрачность заливки зоны", EN = "Zone Fill Transparency"},
        HitRingsOn = {RU = "Круги от ног цели при попадании (неоновые)", EN = "Rings From Target's Feet On Hit (neon)"},
        HitRingColor = {RU = "Цвет кругов попадания", EN = "Hit Rings Color"},
        HitRingSpeed = {RU = "Скорость кругов попадания", EN = "Hit Rings Speed"},
        HitRingGlow = {RU = "Яркость кругов попадания", EN = "Hit Rings Brightness"},
        Sec_Music = {RU = "Музыка (Spotify, SoundCloud и др.)", EN = "Music (Spotify, SoundCloud, etc.)"},
        MusicOn = {RU = "Синхронизация музыки (плеер в мини-меню или отдельным виджетом)", EN = "Music Sync (player in the mini menu or as a separate widget)"},
        MusicHelp = {RU = "Скрипт сам кладёт файлы помощника в папку workspace вашего исполнителя. Один раз откройте её и дважды щёлкните matsysense_media_autostart.bat: он запустит помощника и поставит его на запуск вместе с Windows, дальше ничего запускать не нужно. Если автозапуск не нужен, щёлкните matsysense_media_start.bat (запуск без окна, помощник закроется сам после выхода из Roblox). Помощник читает у Windows, что играет: Spotify, SoundCloud и YouTube Music в браузере, любой плеер. Аккаунты, токены и Premium не нужны. Листать треки можно колесом мыши над панелью.", EN = "The script puts the helper files into your executor's workspace folder by itself. Open it once and double-click matsysense_media_autostart.bat: it starts the helper and sets it to start with Windows, nothing else to run afterwards. If you do not want autostart, double-click matsysense_media_start.bat (no window, the helper closes by itself after you quit Roblox). The helper reads what is playing from Windows: Spotify, SoundCloud and YouTube Music in a browser, any player. No accounts, tokens or Premium needed. Scroll the mouse wheel over the panel to change tracks."},
        MusicFiles = {RU = "Создать файлы помощника заново", EN = "Recreate helper files"},
        MusicLayout = {RU = "Вид плеера", EN = "Player Layout"},
        Opt_Pill = {RU = "Один виджет (внутри мини-меню)", EN = "One widget (inside the mini menu)"},
        Opt_Widget = {RU = "Два виджета (плеер отдельно)", EN = "Two widgets (separate player)"},
        MusicWidgetScale = {RU = "Размер отдельного плеера", EN = "Separate Player Size"},
        Music_FilesNew = {RU = "Файлы помощника созданы в workspace: запустите matsysense_media_start.bat", EN = "Helper files created in workspace: run matsysense_media_start.bat"},
        Music_FilesDone = {RU = "Файлы помощника обновлены в workspace", EN = "Helper files refreshed in workspace"},
        Music_NoFiles = {RU = "Исполнитель не умеет писать файлы (writefile)", EN = "The executor cannot write files (writefile)"},
        Music_NoHelper = {RU = "Запустите помощника", EN = "Run the helper"},
        Music_Nothing = {RU = "Ничего не играет", EN = "Nothing is playing"},
        Music_Old = {RU = "Обновите файлы помощника", EN = "Update the helper files"},
        Music_NoHttp = {RU = "Нет http-запросов", EN = "No http requests"},
        Music_Loading = {RU = "Загрузка...", EN = "Loading..."},
        BindName_Peek = {RU = "Пик-ассист", EN = "Peek Assist"},
        AirSpeed = {RU = "Скорость в воздухе", EN = "Mid-air Speed"},
        AirAccel = {RU = "Резкость маневров", EN = "Maneuver Sharpness"},

        WalkThroughWalls = {RU = "Проходить сквозь стены", EN = "Walk Through Walls"},
        InfiniteJumps = {RU = "Бесконечные прыжки", EN = "Infinite Jumps"},
        AutoJump = {RU = "Авто-прыжок (без остановок)", EN = "Auto Jump (non-stop)"},
        FallProtection = {RU = "Защита от падений", EN = "Fall Protection"},
        AntiStun = {RU = "Снимать оглушение (скорость и прыжок)", EN = "Remove Stun (speed & jump)"},
        IdleProtection = {RU = "Не отключаться при бездействии", EN = "Stay Connected When Idle"},

        CamFov = {RU = "Угол обзора камеры", EN = "Field of View"},
        ThirdPerson = {RU = "Вид от 3-го лица (с фиксацией камеры)", EN = "Third Person View (Locked Camera)"},
        ThirdPersonDist = {RU = "Дистанция камеры (колесо мыши меняет её)", EN = "Camera Distance (mouse wheel changes it)"},
        ThirdPersonShoulder = {RU = "Смещение через плечо (- влево, + вправо)", EN = "Shoulder Offset (- left, + right)"},
        ThirdPersonHeight = {RU = "Высота камеры над головой", EN = "Camera Height Above Head"},

        EnablePlayerView = {RU = "Показывать игроков сквозь стены", EN = "Show Players Through Walls"},
        PlayerViewOnSelf = {RU = "Показывать на себе", EN = "Show on Self"},
        PlayerViewTeamCheck = {RU = "Скрыть своих из видимости", EN = "Hide Teammates"},
        FillCol = {RU = "Цвет заливки тела", EN = "Fill Color"},
        FillAlpha = {RU = "Прозрачность заливки (0 = модель не видна)", EN = "Fill Transparency (0 = model hidden)"},
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
        HpTextSize = {RU = "Размер цифр здоровья", EN = "Health Number Size"},
        HpCol = {RU = "Цвет здоровья", EN = "Health Color"},

        PlayerViewLines = {RU = "Линии до игроков", EN = "Player Lines"},
        PlayerLineCol = {RU = "Цвет линий", EN = "Line Color"},

        WhiteFog = {RU = "Свой цветной туман", EN = "Custom Color Fog"},
        FogDense = {RU = "Плотность тумана", EN = "Fog Density"},
        FogHaze = {RU = "Дымка тумана", EN = "Fog Haze"},
        WeatherSplash = {RU = "Брызги дождя на земле", EN = "Rain Splashes on the Ground"},
        Opt_Rain = {RU = "Дождь", EN = "Rain"},
        Opt_Snow = {RU = "Снег", EN = "Snow"},
        Opt_Leaves = {RU = "Листья", EN = "Leaves"},
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
        Sec_WorldSky = {RU = "Небо (скайбокс)", EN = "Sky (Skybox)"},
        SkyOn = {RU = "Включить свой скайбокс", EN = "Enable Custom Skybox"},
        Sky_Idle = {RU = "Введите ID картинки и нажмите Enter", EN = "Enter an image ID and press Enter"},
        Sky_Off = {RU = "Скайбокс выключен", EN = "Skybox is off"},
        Sky_Loading = {RU = "Загрузка текстур...", EN = "Loading textures..."},
        Sky_Ok1 = {RU = "Применено: один ID на все 6 граней", EN = "Applied: one ID on all 6 faces"},
        Sky_Ok6 = {RU = "Применено: 6 граней", EN = "Applied: 6 faces"},
        Sky_BadCount = {RU = "Ошибка: нужен 1 ID или 6 ID, а введено: %d", EN = "Error: need 1 or 6 IDs, got: %d"},
        Sky_BadId = {RU = "Ошибка: «%s» не похоже на ID (нужно от 5 до 19 цифр)", EN = "Error: \"%s\" is not an ID (5 to 19 digits needed)"},
        Sky_Fail = {
            RU = "Не загрузилось текстур: %d. Нужен ID именно картинки, и она должна быть доступна этому месту",
            EN = "Textures failed to load: %d. Use an image ID that this place is allowed to use"
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
        SkyPreset7 = {RU = "Пастель", EN = "Pastel"},
        SkyPreset8 = {RU = "Стандартное", EN = "Standard"},

        Sec_WorldRays = {RU = "Лучи солнца и луны", EN = "Sun & Moon Rays"},
        Sec_Zoom = {RU = "Приближение", EN = "Zoom"},
        Sec_Grade = {RU = "Цветокоррекция", EN = "Color Grading"},
        Sec_UiNotify = {RU = "Уведомления", EN = "Notifications"},
        Sec_UiGlass = {RU = "Жидкое стекло", EN = "Liquid Glass"},
        GlassOn = {RU = "Эффект жидкого стекла", EN = "Liquid Glass Effect"},
        GlassBlur = {RU = "Размытие мира за меню", EN = "World Blur Behind Menu"},
        GlassSheen = {RU = "Блики и кромка стекла", EN = "Glass Sheen & Rim"},

        FovOn = {RU = "Использовать свой угол обзора", EN = "Use Custom Field of View"},
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
        SunRaysOn = {RU = "Лучи света (красивые, как в новых играх)", EN = "Light Rays (realistic look)"},
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
        Notif_On = {RU = "Включено", EN = "Enabled"},
        Notif_Off = {RU = "Выключено", EN = "Disabled"},
        Notif_Now = {RU = "сейчас", EN = "now"},
        Sec_UiWidgets = {RU = "Виджеты", EN = "Widgets"},
        Sec_Safety = {RU = "Безопасность и запуск", EN = "Safety & Startup"},
        SafeStart = {RU = "Спокойный старт (не включать движение из конфига)", EN = "Calm Start (don't auto-enable movement from config)"},
        RestoreMouse = {RU = "Возвращать мышь игре после закрытия меню", EN = "Give the Mouse Back to the Game After Closing the Menu"},
        PlayerViewHlLimit = {RU = "Максимум подсвеченных игроков", EN = "Max Highlighted Players"},
        AimMode = {RU = "Когда работает доводка", EN = "Aim Assist Activation"},
        AimKey = {RU = "Клавиша доводки", EN = "Aim Assist Key"},
        AimPriority = {RU = "Приоритет цели", EN = "Target Priority"},
        AimMethod = {RU = "Метод наведения", EN = "Aim Method"},
        AimMouseGain = {RU = "Сила движения мышью", EN = "Mouse Move Strength"},
        Sec_AimLead = {RU = "Упреждение: целиться чуть вперёд движущейся цели", EN = "Lead: Aim Slightly Ahead of Moving Targets"},
        AimLeadOn = {RU = "Целиться с упреждением (выключено - ровно в цель)", EN = "Lead Moving Targets (off = aim exactly at the target)"},
        AimPredict = {RU = "На сколько вперёд целиться (секунды)", EN = "How Far Ahead to Aim (seconds)"},
        MouseFallback = {RU = "Управление мышью недоступно в этом исполнителе: используется метод «Камера»", EN = "Mouse control is unavailable here: using the Camera method"},
        Sec_AimMotion = {RU = "Движение прицела", EN = "Aim Movement"},
        Sec_AimVisual = {RU = "Круг и метка цели", EN = "Aim Circle & Target Marker"},
        Sec_CombatFilters = {RU = "Общие условия для доводки и выстрела", EN = "Shared Conditions"},
        Preset_AimSoft = {RU = "Мягкая", EN = "Soft"},
        Preset_AimBalanced = {RU = "Обычная", EN = "Balanced"},
        Preset_AimHard = {RU = "Резкая", EN = "Sharp"},
        Preset_AimSniper = {RU = "Снайпер", EN = "Sniper"},
        AimSticky = {RU = "Держать цель, пока она подходит", EN = "Keep Current Target"},
        AimHumanize = {RU = "Как у человека: прицел двигается неровно", EN = "Human-like: Uneven Aim Movement"},
        AimDeadzone = {RU = "Мёртвая зона (внутри прицел стоит)", EN = "Dead Zone (no movement inside)"},
        AimBulletSpeed = {RU = "Скорость пули для расчёта (0 = мгновенно)", EN = "Bullet Speed for the Lead (0 = instant)"},
        AimLeadMax = {RU = "Максимальный сдвиг вперёд, м (0 = без предела)", EN = "Max Shift Ahead, m (0 = no limit)"},
        AimBulletDrop = {RU = "Учитывать падение пули", EN = "Compensate Bullet Drop"},
        AimShowTarget = {RU = "Метка на захваченной цели", EN = "Mark the Locked Target"},
        FovCol = {RU = "Цвет круга", EN = "Circle Color"},
        FovLockCol = {RU = "Цвет при захвате цели", EN = "Color When Locked"},
        FovThick = {RU = "Толщина линии круга", EN = "Circle Line Thickness"},
        TriggerMode = {RU = "Когда стрелять", EN = "Fire Activation"},
        TriggerKey = {RU = "Клавиша автовыстрела", EN = "Auto Fire Key"},
        TriggerPart = {RU = "Куда стрелять", EN = "Fire At"},
        TriggerInterval = {RU = "Пауза между выстрелами", EN = "Interval Between Shots"},
        TriggerRadius = {RU = "Радиус срабатывания у прицела (0 = точно)", EN = "Trigger Radius (0 = exact)"},
        CombatMaxDist = {RU = "Максимальная дистанция до цели", EN = "Max Target Distance"},
        CombatSkipFF = {RU = "Пропускать игроков под защитным щитом", EN = "Skip Players Under a Protective Shield"},
        CombatNeedTool = {RU = "Только с предметом в руках", EN = "Only With an Item in Hand"},
        Opt_Closest = {RU = "Ближайшая к прицелу", EN = "Nearest to crosshair"},
        Opt_Any = {RU = "Любая часть", EN = "Any part"},
        ArrowStyle = {RU = "Форма стрелки", EN = "Arrow Shape"},
        ArrowColorMode = {RU = "Как красить стрелки", EN = "Arrow Coloring"},
        ArrowPlacement = {RU = "Где стоят стрелки", EN = "Arrow Placement"},
        ArrowMargin = {RU = "Отступ от края экрана", EN = "Distance from Screen Edge"},
        ArrowMaxCount = {RU = "Сколько стрелок показывать", EN = "Max Arrows Shown"},
        ArrowScaleDist = {RU = "Ближе - крупнее и ярче", EN = "Closer = Bigger & Brighter"},
        ArrowPulse = {RU = "Пульсация, если враг совсем рядом", EN = "Pulse When an Enemy Is Very Close"},
        ArrowGlow = {RU = "Свечение вокруг стрелки", EN = "Arrow Glow"},
        ArrowPlate = {RU = "Тёмная подложка и кольцо под стрелкой", EN = "Dark Backplate and Ring Under the Arrow"},
        ArrowName = {RU = "Имя рядом со стрелкой", EN = "Name Next to Arrow"},
        ArrowRing = {RU = "Кольцо, по которому идут стрелки", EN = "Guide Ring"},
        ArrowOpacity = {RU = "Непрозрачность стрелок", EN = "Arrow Opacity"},
        ArrowSmart = {RU = "Умная посадка: цель у края - стрелка снаружи, за спиной - ближе к центру", EN = "Smart Placement: Near the Edge = Outer, Behind You = Closer to Center"},
        ArrowThreat = {RU = "Подсвечивать тех, кто смотрит на вас", EN = "Highlight Enemies Facing You"},
        ArrowHealth = {RU = "Полоска здоровья у стрелки", EN = "Health Bar on Arrow"},
        ArrowGroup = {RU = "Объединять стрелки в одном направлении (x2, x3)", EN = "Merge Arrows in the Same Direction (x2, x3)"},
        ArrowGroupAngle = {RU = "Угол объединения стрелок", EN = "Merge Angle"},
        ArrowLos = {RU = "Приглушать врагов за стеной", EN = "Dim Enemies Behind Walls"},
        ArrowHeight = {RU = "Выше / ниже: метры со знаком (+12, -8)", EN = "Above / Below: Signed Meters (+12, -8)"},
        ArrowAngle = {RU = "Угол поворота до цели (73°)", EN = "Turn Angle to Target (73°)"},
        AimMouseAuto = {RU = "Подстраивать силу мыши под чувствительность игры", EN = "Auto-match Mouse Strength to Game Sensitivity"},
        TriggerHold = {RU = "Удерживать кнопку, пока цель под прицелом", EN = "Hold the Button While on Target"},
        AimOverride = {RU = "Перебивать камеру игры (если доводка не работает)", EN = "Override the Game Camera (if aim doesn't work)"},
        AimAutoMouse = {RU = "Игра ведёт камеру сама: доводка переключилась на движение мышью", EN = "The game drives the camera itself: aim assist switched to mouse movement"},
        AimOverrideAuto = {RU = "Игра перезаписывает камеру: доводка теперь удерживает её сама", EN = "The game overwrites the camera: aim assist now holds it itself"},
        AimNpcs = {RU = "Целиться и в ботов", EN = "Aim at Bots Too"},
        TriggerNpcs = {RU = "Стрелять и по ботам", EN = "Fire at Bots Too"},
        EspNpcs = {RU = "Показывать и ботов (рамки, подсветка, скелет)", EN = "Show Bots Too (boxes, highlight, skeleton)"},
        ArrowNpcs = {RU = "Стрелки и на ботов", EN = "Arrows to Bots Too"},
        PlayerViewHlFallback = {RU = "Рамка-запас, если подсветка не помещается в лимит", EN = "Backup Outline When Highlight Limit Is Exceeded"},
        PlayerViewHlMode = {RU = "Цвет подсветки", EN = "Highlight Color Mode"},
        PlayerViewHiddenFill = {RU = "Цвет подсветки за стеной", EN = "Highlight Color Behind Walls"},
        Opt_Wall = {RU = "За стеной", EN = "Behind walls"},
        Opt_Dart = {RU = "Стрела", EN = "Dart"},
        Opt_Chevron = {RU = "Галочка", EN = "Chevron"},
        AutoLite = {RU = "Авто-облегчение при нагрузке (упрощает оформление, если игра подвисает)", EN = "Auto-lighten Under Load (simplifies visuals when the game stutters)"},
        HitchReport = {RU = "Сообщать о подвисаниях (какая часть скрипта тормозит)", EN = "Report Stutters (which part of the script is slow)"},
        HitchMsg = {RU = "Фриз %d мс: скрипт %d мс (%s)", EN = "Stutter %d ms: script %d ms (%s)"},
        HitchNotScript = {RU = "виноват не скрипт", EN = "not the script"},
        HitchDump = {RU = "Сохранить отчёт о подвисаниях в файл", EN = "Save Stutter Report to File"},
        HitchSaved = {RU = "Отчёт: %s (подвисаний %d, по вине скрипта %d)", EN = "Report: %s (stutters %d, script-caused %d)"},
        HitchNone = {RU = "Подвисаний пока не было", EN = "No stutters yet"},
        Sec_Errors = {RU = "Ошибки скрипта", EN = "Script Errors"},
        ErrNone = {RU = "Ошибок нет", EN = "No errors"},
        ErrSummary = {RU = "Ошибок за сеанс: %d, чаще всего: %s", EN = "Errors this session: %d, most often: %s"},
        ErrLast = {RU = "Последняя (%d с назад): %s", EN = "Last (%d s ago): %s"},
        ErrCopy = {RU = "Скопировать отчёт", EN = "Copy Report"},
        ErrClear = {RU = "Очистить", EN = "Clear"},
        ErrCopied = {RU = "Отчёт об ошибках скопирован", EN = "Error report copied"},
        ErrSaved = {RU = "Буфера обмена нет, отчёт в файле %s", EN = "No clipboard, report saved to %s"},
        ErrFail = {RU = "Не получилось ни скопировать, ни сохранить", EN = "Could not copy or save the report"},
        GovMsg = {RU = "Нагрузка высокая: оформление упрощено (уровень %d)", EN = "High load: visuals simplified (level %d)"},
        Sec_FoeTrail = {RU = "Следы врагов", EN = "Enemy Trails"},
        FoeTrailOn = {RU = "След за врагами (где они были последние секунды)", EN = "Enemy Trails (where they were a moment ago)"},
        FoeTrailTime = {RU = "Длина следа (секунды)", EN = "Trail Length (seconds)"},
        FoeTrailMax = {RU = "Сколько ближайших врагов со следом", EN = "How Many Nearest Enemies Get a Trail"},
        FoeTrailThick = {RU = "Толщина следа", EN = "Trail Thickness"},
        FoeTrailCol = {RU = "Цвет следа", EN = "Trail Color"},
        SearchHint = {RU = "Поиск по настройкам...", EN = "Search settings..."},
        SearchNone = {RU = "Ничего не найдено", EN = "Nothing found"},
        SearchBusy = {RU = "Собираю список настроек...", EN = "Collecting settings..."},
        Opt_Fixed = {RU = "Один цвет", EN = "Single color"},
        Opt_Team = {RU = "По команде", EN = "By team"},
        Opt_ByHealth = {RU = "По здоровью", EN = "By health"},
        Opt_ByDistance = {RU = "По дальности", EN = "By distance"},
        Opt_Circle = {RU = "Окружность", EN = "Circle"},
        Opt_Edge = {RU = "Край экрана", EN = "Screen edge"},
        Opt_Always = {RU = "Всегда", EN = "Always"},
        Opt_HoldKey = {RU = "Клавиша", EN = "Hold key"},
        Opt_HoldRmb = {RU = "ПКМ", EN = "Right mouse"},
        Opt_Crosshair = {RU = "К центру", EN = "Crosshair"},
        Opt_Distance = {RU = "Ближайший", EN = "Closest"},
        Opt_Health = {RU = "Слабый", EN = "Lowest HP"},
        Opt_Camera = {RU = "Камера", EN = "Camera"},
        Opt_Mouse = {RU = "Мышь", EN = "Mouse"},
        Opt_Auto = {RU = "Авто", EN = "Auto"},
        SafeStartSkipped = {RU = "Спокойный старт: функций из конфига оставлено выключенными: %d", EN = "Calm Start: config features left off: %d"},
        Sec_Observe = {RU = "Наблюдение", EN = "Spectate"},
        Sec_Freecam = {RU = "Свободная камера", EN = "Free Camera"},
        FreecamOn = {RU = "Свободная камера (персонаж стоит на месте)", EN = "Free Camera (character stays put)"},
        FreecamSpeed = {RU = "Скорость камеры", EN = "Camera Speed"},
        FreecamSens = {RU = "Чувствительность поворота", EN = "Look Sensitivity"},
        FreecamSmooth = {RU = "Плавность камеры", EN = "Camera Smoothness"},
        FreecamHint = {RU = "Правая кнопка мыши - поворот. W A S D - движение, E или пробел - вверх, Q - вниз, Shift - быстрее, Ctrl - медленнее, колесо - скорость.",
            EN = "Hold right mouse button to look. W A S D move, E or Space up, Q down, Shift faster, Ctrl slower, mouse wheel changes speed."},
        SpeedWidgetOn = {RU = "Виджет скорости", EN = "Speed Widget"},
        Sec_UiKeys = {RU = "Виджет клавиш (W A S D, пробел)", EN = "Keys Widget (W A S D, Space)"},
        KeysOn = {RU = "Виджет клавиш", EN = "Keys Widget"},
        KeysStyle = {RU = "Стиль клавиш", EN = "Key Style"},
        KeysColor = {RU = "Цвет нажатой клавиши", EN = "Pressed Key Color"},
        KeysBase = {RU = "Цвет клавиши (в покое)", EN = "Key Color (idle)"},
        KeysScale = {RU = "Размер виджета клавиш", EN = "Keys Widget Size"},
        KeysAlpha = {RU = "Прозрачность клавиш", EN = "Key Transparency"},
        KeysRound = {RU = "Скругление клавиш", EN = "Key Roundness"},
        KeysFx = {RU = "Анимация (пружина, волна, свечение, наклон)", EN = "Animation (spring, ripple, glow, tilt)"},
        KeysMouse = {RU = "Показывать ЛКМ и ПКМ", EN = "Show LMB and RMB"},
        KeysLabels = {RU = "Подписи на клавишах", EN = "Key Labels"},
        Keys_Lmb = {RU = "ЛКМ", EN = "LMB"},
        Keys_Rmb = {RU = "ПКМ", EN = "RMB"},
        Opt_Glass = {RU = "Стекло", EN = "Glass"},
        Opt_Solid = {RU = "Сплошной", EN = "Solid"},
        Opt_Outline = {RU = "Контур", EN = "Outline"},
        Opt_Neon = {RU = "Неон", EN = "Neon"},
        SpeedWidgetScale = {RU = "Размер виджета скорости", EN = "Speed Widget Size"},
        Ios26On = {RU = "Стиль iOS 26 (стекло)", EN = "iOS 26 Style (glass)"},
        SpeedUnit = {RU = "студ./с", EN = "studs/s"},
        Unit_ms = {RU = "мс", EN = "ms"},
        Unit_s = {RU = "с", EN = "s"},
        Unit_m = {RU = "м", EN = "m"},
        Unit_pcs = {RU = "штук", EN = "pcs"},
        Unit_studs = {RU = "студ.", EN = "studs"},
        Profile_Uptime = {RU = "В игре: %02d:%02d:%02d", EN = "Playtime: %02d:%02d:%02d"},
        Opt_Head = {RU = "Голова", EN = "Head"},
        Opt_Body = {RU = "Тело", EN = "Body"},
        Opt_Click = {RU = "Клик", EN = "Click"},
        Opt_Tool = {RU = "Инструмент", EN = "Tool"},
        Opt_Left = {RU = "Слева", EN = "Left"},
        Opt_Right = {RU = "Справа", EN = "Right"},
        Opt_Bottom = {RU = "Снизу", EN = "Bottom"},
        Opt_Both = {RU = "Заливка и контур", EN = "Fill & Outline"},
        Opt_Filled = {RU = "Заливка", EN = "Filled"},
        Opt_Medium = {RU = "Средний", EN = "Medium"},
        Opt_Custom = {RU = "Свой", EN = "Custom"},
        Opt_Cinematic = {RU = "Кино", EN = "Cinematic"},
        Opt_Warm = {RU = "Тёплый", EN = "Warm"},
        Opt_Cold = {RU = "Холодный", EN = "Cold"},
        Opt_Vivid = {RU = "Яркий", EN = "Vivid"},
        Opt_Noir = {RU = "Нуар", EN = "Noir"},
        Confirm_ExitTitle = {RU = "Выгрузить скрипт?", EN = "Unload the script?"},
        Confirm_ExitText = {RU = "Все функции будут выключены, окна закрыты, а изменения в игре откатятся. Вернуть скрипт можно только повторным запуском.", EN = "All features will be turned off, windows closed and changes in the game reverted. You can bring the script back only by running it again."},
        Confirm_PanicTitle = {RU = "Выключить все функции?", EN = "Turn everything off?"},
        Confirm_PanicText = {RU = "Все включённые функции будут отключены. Скрипт и меню останутся загруженными.", EN = "Every enabled feature will be turned off. The script and the menu stay loaded."},
        Confirm_Yes = {RU = "Да", EN = "Yes"},
        Confirm_No = {RU = "Нет", EN = "No"},
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
        Panic_Btn = {RU = "Выключить все функции (клавиша End)", EN = "Turn Everything Off (End key)"},
        Panic_Done = {RU = "Все функции выключены", EN = "Everything turned off"},
        RollbackGuard = {RU = "Выключать движение, если игра вернула назад", EN = "Stop Movement If the Game Moves You Back"},
        Rollback_Done = {RU = "Игра вернула персонажа назад: движение выключено", EN = "The game moved you back: movement turned off"},
        Guard_Tripped = {RU = "Постоянно выдавало ошибку и выключено: %s", EN = "Kept failing and was turned off: %s"},
        WallPass_Wait = {RU = "Вы внутри стены: столкновения вернутся, когда выйдете", EN = "You are inside a wall: collisions return once you are out"},
        FontStyle = {RU = "Шрифт интерфейса", EN = "Interface Font"},
        Opt_Gotham = {RU = "Стандартный", EN = "Standard"},
        Opt_Lazy = {RU = "Ленивый", EN = "Lazy"},
        Opt_Bold = {RU = "Жирный", EN = "Bold"},
        HitMarkerOn = {RU = "Эффект попадания по врагу (только за ваши выстрелы): крестик, кольцо, осколки", EN = "Hit Effect (your own hits only): cross, ring, shards"},
        HitLoose = {RU = "Засчитывать попадание свободнее (урон врагу рядом с прицелом после выстрела)", EN = "Count Hits Loosely (damage to an enemy near the crosshair after a shot)"},
        HitFxSize = {RU = "Размер эффекта попадания", EN = "Hit Effect Size"},
        HitFxPower = {RU = "Сила эффекта попадания", EN = "Hit Effect Intensity"},
        HitFxColor = {RU = "Цвет попадания", EN = "Hit Color"},
        HitFxKillColor = {RU = "Цвет убийства", EN = "Kill Color"},
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

        Sec_Hits = {RU = "Реакция камеры на урон", EN = "Camera Damage Reaction"},
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
        SnowSize = {RU = "Размер снежинок и листьев", EN = "Snowflake / Leaf Size"},
        WeatherCol = {RU = "Цвет осадков", EN = "Precipitation Color"},

        Lightning = {RU = "Вспышки молний", EN = "Lightning Flashes"},
        LightRate = {RU = "Частота молний", EN = "Lightning Rate"},
        LightSize = {RU = "Размер молний", EN = "Lightning Size"},
        LightDur = {RU = "Длительность вспышки", EN = "Flash Duration"},
        Meteors = {RU = "Падающие звёзды (метеориты)", EN = "Meteor Shower"},
        MetRate = {RU = "Частота звёзд", EN = "Meteor Rate"},
        MetSize = {RU = "Размер звёзд", EN = "Meteor Size"},
        MetTail = {RU = "Длина следа", EN = "Trail Length"},
        MetDur = {RU = "Время полета", EN = "Flight Time"},
        MetCol = {RU = "Цвет звёзд", EN = "Meteor Color"},

        HideHats = {RU = "Скрыть шапки у игроков", EN = "Hide Hats"},
        HoloSelf = {RU = "Голограмма на своем персонаже", EN = "Self Hologram"},
        HoloAlpha = {RU = "Прозрачность персонажа", EN = "Transparency"},
        HoloCol = {RU = "Цвет голограммы", EN = "Hologram Color"},
        Bind_None = {RU = "НЕТ", EN = "NONE"},
        HoloGlow = {RU = "Яркость / свечение", EN = "Brightness / Glow"},
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

        PitchMod = {RU = "Наклон персонажа (видят все)", EN = "Character Tilt (everyone sees)"},
        PitchAngle = {RU = "Угол наклона", EN = "Tilt Angle"},
        TiltMode = {RU = "Как наклонять", EN = "Tilt Mode"},
        Opt_TiltAll = {RU = "Видят все (у вас гнётся туловище)", EN = "Everyone sees (torso bends for you)"},
        Opt_TiltTorso = {RU = "Только туловище (видно только вам)", EN = "Torso only (only you see it)"},
        Opt_TiltBody = {RU = "Всё тело целиком", EN = "Whole body"},
        TeleportOn = {RU = "Телепорт на точку", EN = "Teleport to Point"},
        Sec_Ghosts = {RU = "Как вас видят другие", EN = "How Others See You"},
        ServerGhosts = {RU = "Показывать, где вас видят другие игроки", EN = "Show Where Other Players See You"},
        GhostMaterial = {RU = "Материал призрака", EN = "Ghost Material"},
        GhostAlpha = {RU = "Прозрачность призрака", EN = "Ghost Transparency"},
        GhostColor = {RU = "Цвет призрака", EN = "Ghost Color"},
        GhostCount = {RU = "Количество призраков", EN = "Number of Ghosts"},
        Opt_ForceField = {RU = "Голограмма", EN = "Hologram"},
        Opt_Plastic = {RU = "Пластик", EN = "Plastic"},
        TeleportSpeed = {RU = "Скорость телепорта (0 = мгновенно)", EN = "Teleport Speed (0 = instant)"},
        TpSetBind = {RU = "Клавиша: поставить точку", EN = "Key: Set Point"},
        TpGoBind = {RU = "Клавиша: телепорт на точку", EN = "Key: Teleport to Point"},
        DisplayAllNote = {RU = "Всё отображение", EN = "All Display"},
        TpSaved = {RU = "Точка телепорта создана", EN = "Teleport point saved"},
        TpDone = {RU = "Телепорт выполнен", EN = "Teleported"},
        TpNoPoint = {RU = "Сначала создайте точку", EN = "Set a point first"},
        FreezeChar = {RU = "Замереть для других игроков (вы двигаетесь)", EN = "Appear Frozen to Others (you can still move)"},
        FakeLag = {RU = "Эффект лагов у персонажа (видят все)", EN = "Lag Effect on Character (everyone sees)"},
        FakeLagTicks = {RU = "Тиков движения до паузы", EN = "Move Ticks Before Pause"},
        FakeLagDelay = {RU = "Задержка между тиками", EN = "Delay Between Ticks"},
        SpinCharacter = {RU = "Вращать персонажа (видят все)", EN = "Spin Character (everyone sees)"},
        YawSpeed = {RU = "Скорость вращения", EN = "Rotation Speed"},
        JerkySpin = {RU = "Вращение рывками", EN = "Jerky Rotation"},
        Sec_BackWalk = {RU = "Ходьба спиной", EN = "Walk Backwards"},
        BackWalk = {RU = "Ходьба спиной (видят все: вы идёте вперёд, персонаж смотрит назад)", EN = "Walk Backwards (everyone sees: you move forward, the character faces back)"},
        BackWalkLegs = {RU = "Ноги шагают назад (обратная анимация ходьбы)", EN = "Legs Step Backwards (reversed walk animation)"},

        OptLight = {RU = "Лёгкая оптимизация (включена при запуске): тени, отражения, дорогие эффекты", EN = "Light Optimization (on at start): shadows, reflections, costly effects"},
        FpsBoost = {RU = "Упрощённая графика (больше кадров в секунду)", EN = "Simplified Graphics (smoother game)"},

        FpsUnlocker = {RU = "Снять ограничение кадров в секунду", EN = "Remove Frame Rate Limit"},
        CullOn = {RU = "Ограничить дальность прорисовки", EN = "Limit Draw Distance"},
        FpsCullDist = {RU = "Дальность прорисовки (студов)", EN = "Draw Distance (studs)"},

        FpsUnlockFail = {RU = "Снять ограничение кадров не удалось: Roblox запретил это скрипту. Включите «Неограниченно» в меню Roblox: Esc, Настройки, Графика", EN = "Could not remove the frame rate limit: Roblox blocks it for scripts. Set it to Unlimited in the Roblox menu: Esc, Settings, Graphics"},

        LangBtn = {RU = "Язык интерфейса", EN = "Language / Язык меню"},
        AnimSpeed = {RU = "Плавность меню", EN = "Menu Smoothness"},
        UiFx = {RU = "Живой интерфейс (анимации)", EN = "Living Interface (motion)"},
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
        PillClock = {RU = "Показывать системное время", EN = "Show System Time"},
        PillSession = {RU = "Время в игре", EN = "Time in Game"},
        PillPing = {RU = "Показывать пинг", EN = "Show Ping"},
        BindListOn = {RU = "Показывать виджет биндов", EN = "Show Keybinds Widget"},
        Sec_UiBinds = {RU = "Виджет биндов", EN = "Keybinds Widget"},
        BindListShow = {RU = "Что показывать", EN = "What to Show"},
        Opt_BindAll = {RU = "Все назначенные клавиши", EN = "All bound keys"},
        Opt_BindActive = {RU = "Только включённые", EN = "Only active"},
        BindListScale = {RU = "Размер виджета биндов", EN = "Keybinds Widget Size"},
        BindListOnCol = {RU = "Цвет «вкл»", EN = "Active Color"},
        BindListKeys = {RU = "Показывать клавишу", EN = "Show Key"},
        BindListStates = {RU = "Показывать вкл/выкл", EN = "Show On/Off"},
        BindListNoneOn = {RU = "сейчас ничего не включено", EN = "nothing active"},
        BindListTitle = {RU = "Клавиши", EN = "Keybinds"},
        BindListEmpty = {RU = "клавиши не назначены", EN = "no keys bound"},
        BindList_On = {RU = "вкл", EN = "on"},
        BindList_Off = {RU = "выкл", EN = "off"},
        BindList_Held = {RU = "удерж.", EN = "held"},
        BindList_Press = {RU = "нажатие", EN = "press"},
        BindList_Pressed = {RU = "нажато", EN = "pressed"},
        BindMode_Toggle = {RU = "Переключать", EN = "Toggle"},
        BindMode_Hold = {RU = "Удерживать", EN = "Hold"},
        BindMode_Clear = {RU = "Убрать клавишу", EN = "Clear Key"},
        Keys_Mmb = {RU = "СКМ", EN = "MMB"},
        BindName_AimAssist = {RU = "Наводка", EN = "Aim Assist"},
        BindName_TriggerAssist = {RU = "Автовыстрел", EN = "Auto Fire"},
        BindName_AimLeadOn = {RU = "Упреждение", EN = "Lead"},
        BindName_AimNpcs = {RU = "Наводка на ботов", EN = "Aim at Bots"},
        BindName_TriggerNpcs = {RU = "Выстрел по ботам", EN = "Fire at Bots"},
        BindName_FlightMode = {RU = "Полёт", EN = "Flight"},
        BindName_Speed = {RU = "Ускорение", EN = "Sprint"},
        BindName_WalkThroughWalls = {RU = "Сквозь стены", EN = "Noclip"},
        BindName_AirControl = {RU = "Управление в воздухе", EN = "Air Control"},
        BindName_InfiniteJumps = {RU = "Бесконечные прыжки", EN = "Infinite Jumps"},
        BindName_AutoJump = {RU = "Авто-прыжок", EN = "Auto Jump"},
        BindName_FallProtection = {RU = "Защита от падений", EN = "Fall Protection"},
        BindName_AntiStun = {RU = "Без оглушения", EN = "Anti-Stun"},
        BindName_IdleProtection = {RU = "Анти-АФК", EN = "Anti-AFK"},
        BindName_FovOn = {RU = "Свой угол обзора", EN = "Custom FOV"},
        BindName_ThirdPerson = {RU = "Третье лицо", EN = "Third Person"},
        BindName_ZoomOn = {RU = "Приближение", EN = "Zoom"},
        BindName_SpectateOn = {RU = "Наблюдение", EN = "Spectate"},
        BindName_FreecamOn = {RU = "Свободная камера", EN = "Free Camera"},
        BindName_PlayerView = {RU = "Отображение игроков", EN = "Player ESP"},
        BindName_TimeCycle = {RU = "Смена дня", EN = "Day Cycle"},
        BindName_TimeSyncReal = {RU = "Реальное время", EN = "Real Time"},
        BindName_GradeOn = {RU = "Цветокоррекция", EN = "Color Grading"},
        BindName_HeadTiltOn = {RU = "Наклон", EN = "Tilt"},
        BindName_SpinCharacter = {RU = "Вращение", EN = "Spin"},
        BindName_BackWalk = {RU = "Ходьба спиной", EN = "Walk Backwards"},
        BindName_FreezeChar = {RU = "Заморозка", EN = "Freeze"},
        BindName_FakeLag = {RU = "Лаги", EN = "Fake Lag"},
        BindName_ServerGhosts = {RU = "Призраки", EN = "Ghosts"},
        BindName_TpSetBind = {RU = "Точка телепорта", EN = "Set TP Point"},
        BindName_TpGoBind = {RU = "Телепорт", EN = "Teleport"},
        PillBorderThick = {RU = "Обводка панели", EN = "Panel Border"},
        PillBorderCol = {RU = "Цвет обводки инфо", EN = "Info Border Color"},
        PillAlpha = {RU = "Прозрачность инфо", EN = "Info Opacity"},
        PillBg = {RU = "Цвет фона инфо", EN = "Info BG Color"},
        PillTextCol = {RU = "Цвет текста инфо", EN = "Info Text Color"}
    }
}

__X.getService = getService
end}

-- [2/69] Ядро: таблицы состояния, данных и меню, сводка настроек
MODULES[#MODULES + 1] = {"2. Ядро: таблицы состояния, данных и меню, сводка настроек", function(M, __X)
-- жизнь скрипта в этом сеансе: не настройки и в конфиг не попадают
M.Run = {IsShutDown = false, MenuOpen = false, IsDead = false, CurFPS = 60, Uptime = 0, StartedAt = os.clock(), ListeningBind = nil}

-- только настройки: всё отсюда (кроме M.CFG.RuntimeKeys) сохраняется в конфиг
M.State = {
    Language = "RU",
    FontStyle = "Gotham",

    AimAssist = false, AimFov = 150, ShowFov = false, AimTime = 50, AimWallCheck = true, AimTeamCheck = true, AimPart = "Head",
    AimDynamic = false, AimDynStand = 0.6, AimDynWalk = 1, AimDynJump = 1.4, FovFillOn = true, FovFillAlpha = 0.9, AimDebug = false, AimLagComp = true,
    TriggerAssist = false, TriggerLoop = false, TriggerDelay = 0.05, TriggerWallCheck = true, TriggerTeamCheck = true, TriggerMethod = "Auto",

    FlightMode = false, WalkThroughWalls = false, PlayerView = false, PlayerViewOnSelf = false, PlayerViewTeamCheck = false, Speed = false, InfiniteJumps = false, FallProtection = false,
    FlightSpeed = 55, SprintSpeed = 45,
    AirControl = false, AirSpeed = 150, AirAccel = 8, PeekOn = false, PeekKey = "", PeekColor = Color3.fromRGB(0, 230, 255), PeekSize = 2.4,
    AutoJump = false,
    -- музыка: плеер в мини-меню или отдельным виджетом
    MusicOn = false, MusicMode = false, MusicLayout = "Pill", MusicWidgetScale = 1, MusicWidgetX = 0.17, MusicWidgetY = 0.14,

    CamFov = 70, FovOn = false, ThirdPerson = false, ThirdPersonDist = 12, ThirdPersonShoulder = 0, ThirdPersonHeight = 0.6,
    ZoomOn = false, ZoomFov = 25, ZoomSpeed = 12,
    FreecamOn = false, FreecamSpeed = 40, FreecamSens = 1, FreecamSmooth = 0.4,
    GradeOn = false, GradePreset = "Custom", GradeSat = 0.15, GradeContrast = 0.1, GradeBright = 0,
    GradeTint = Color3.fromRGB(255, 255, 255),
    AntiStun = false,
    IdleProtection = false,
    RollbackGuard = true,
    ShakeOn = false, ShakeStrength = 0.6, HitFlashOn = false, LowHpOn = false,
    DamageNumbers = false, PlayerViewDistance = false, PlayerViewHealthColor = false, PlayerViewMaxDist = 5000,
    Ios26On = true,
    SpeedWidgetOn = false, SpeedWidgetScale = 1, SpeedWidgetX = 0.9, SpeedWidgetY = 0.62,
    -- виджет клавиш (W A S D и пробел)
    KeysOn = false, KeysStyle = "Glass", KeysColor = Color3.fromRGB(0, 230, 255), KeysBase = Color3.fromRGB(22, 26, 36), KeysScale = 1,
    KeysAlpha = 0.3, KeysRound = 10, KeysFx = true, KeysMouse = false, KeysLabels = true, KeysWidgetX = 0.14, KeysWidgetY = 0.8,
    HitRingsOn = false, HitRingColor = Color3.fromRGB(0, 230, 255), HitRingSpeed = 14, HitRingGlow = 0.7,
    HitMarkerOn = false, HitLoose = true, HitFxSize = 1, HitFxPower = 1, HitFxColor = Color3.fromRGB(255, 255, 255), HitFxKillColor = Color3.fromRGB(255, 70, 70),
    SpectateOn = false, TimeSyncReal = false, SpecX = 0.5, SpecY = 0.9,
    SafeStart = true,
    RestoreMouse = true,
    PlayerViewHlLimit = 12,
    AimMode = "Always", AimKey = "", AimPriority = "Crosshair", AimMethod = "Auto", AimMouseGain = 1, AimLeadOn = false, AimPredict = 0,
    AimSticky = false, AimHumanize = false, AimDeadzone = 0, AimBulletSpeed = 0, AimLeadMax = 12, AimBulletDrop = false, AimShowTarget = false,
    FovCol = Color3.fromRGB(255, 255, 255), FovLockCol = Color3.fromRGB(255, 90, 90), FovThick = 1,
    TriggerMode = "Always", TriggerKey = "", TriggerPart = "Any", TriggerInterval = 0.06, TriggerRadius = 0,
    CombatMaxDist = 3000, CombatSkipFF = false, CombatNeedTool = false,
    AimNpcs = false, TriggerNpcs = false, EspNpcs = false, ArrowNpcs = false, PlayerViewHlFallback = true,
    AimOverride = false, AimMouseAuto = true, TriggerHold = false,
    PlayerViewHlMode = "Fixed", PlayerViewHiddenFill = Color3.fromRGB(255, 84, 98),

    ConfirmX = 0.5, ConfirmY = 0.5,
    TeleportOn = false, TeleportSpeed = 0, ServerGhosts = false, GhostMaterial = "ForceField", GhostAlpha = 0.45, GhostColor = Color3.fromRGB(120, 200, 255), GhostCount = 3, FreezeChar = false, FakeLag = false, FakeLagTicks = 3, FakeLagDelay = 0.25, SpinCharacter = false, YawSpeed = 25, JerkySpin = false, BackWalk = false, BackWalkLegs = true, HeadTiltOn = false, PitchAngle = -60, TiltMode = "TiltAll",

    OptLight = true, FpsBoost = false, FpsUnlocker = false, FpsCullDist = 800, CullOn = false,

    -- единая тёмная палитра по умолчанию
    MainBg = Color3.fromRGB(10, 11, 17), MenuAlpha = 0.03,
    SideBg = Color3.fromRGB(8, 9, 14), SideAlpha = 0,
    CardBg = Color3.fromRGB(18, 20, 30), CardAlpha = 0.08,
    SideCardBg = Color3.fromRGB(16, 18, 27), SideCardAlpha = 0.25,
    Accent = Color3.fromRGB(118, 150, 255),  -- #7696FF
    BorderCol = Color3.fromRGB(34, 38, 54), BorderThick = 1,
    LogoCol = Color3.fromRGB(255, 255, 255),
    AnimSpeed = 0.22,
    UiFx = true,
    NotifyOn = true, NotifyAlpha = 0.1, NotifyScale = 1, NotifyColor = Color3.fromRGB(13, 14, 21),
    GlassOn = false, GlassBlur = 10, GlassSheen = 0.5,

    PillBg = Color3.fromRGB(13, 14, 21), PillAlpha = 0.1, PillTextCol = Color3.fromRGB(255, 255, 255),
    PillBorderCol = Color3.fromRGB(34, 38, 54), PillBorderThick = 1,
    PillScaleVal = 1.0,
    PillShowUser = true, PillShowMem = true, PillShowTime = true, PillShowClock = true, PillShowPing = true,
    BindListOn = false, BindListX = 0.88, BindListY = 0.3, BindListShow = "BindAll", BindListScale = 1, BindListOnCol = Color3.fromRGB(90, 220, 140), BindListKeys = true, BindListStates = true,
    PillLocked = false,

    PlayerViewBox = true,
    PlayerViewBoxCol = Color3.fromRGB(255, 255, 255),
    PlayerViewBoxThick = 1.5,
    PlayerViewFill = Color3.fromRGB(48, 209, 88),
    PlayerViewLine = Color3.fromRGB(255, 255, 255),
    PlayerViewAlpha = 0,
    PlayerViewNameCol = Color3.fromRGB(255, 255, 255), PlayerViewNameOutCol = Color3.fromRGB(0, 0, 0),
    PlayerViewFontWeight = "Bold", PlayerViewTextSize = 13,

    PlayerViewHealthBar = true,
    PlayerViewHealthPos = "Left",
    PlayerViewHealthText = true,
    PlayerViewHealthCol = Color3.fromRGB(48, 209, 88),
    PlayerViewHealthBarThick = 4,
    PlayerViewHpTextSize = 11,

    PlayerViewLines = false,
    PlayerLineCol = Color3.fromRGB(48, 209, 88),

    DarkWorld = false, DarkIntensity = 0.5,
    FogOn = false, FogDensity = 0.75, FogHaze = 0.0,
    WeatherSplash = false,
    FogColor = Color3.fromRGB(255, 255, 255),

    CloudsOn = false,
    CloudDensity = 0.7,
    CloudCover = 60,
    CloudColor = Color3.fromRGB(255, 255, 255),

    SkyOn = false,
    SkyIds = "",

    WeatherOn = false, WeatherMode = "Rain", WeatherDensity = 35, WeatherSpeed = 60, WeatherRadius = 60,
    WeatherColor = Color3.fromRGB(180, 230, 255), SnowSize = 0.5,

    TimeOn = false, CustomTime = 14.5, TimeCycle = false, TimeCycleSpeed = 24,
    SunRaysOn = false, SunRaysIntensity = 0.35, SunRaysSpread = 0.7, SunRaysBright = 0.5,
    MeteorOn = false, MeteorRate = 3, MeteorSize = 3.5, MeteorTrailLen = 1.8, MeteorDuration = 2.5, MeteorColor = Color3.fromRGB(255, 140, 40), MeteorImpact = true,
    LightningOn = false, LightningRate = 3, LightningSize = 0.8, LightningDuration = 0.7, LightningFlash = true, LightningFlashPower = 0.5,

    ArrowsOn = false, ArrowCol = Color3.fromRGB(255, 84, 98), ArrowSize = 40, ArrowRadius = 240, ArrowDistance = false,
    ArrowStyle = "Dart", ArrowColorMode = "Fixed", ArrowPlacement = "Circle", ArrowMargin = 48, ArrowMaxCount = 8,
    ArrowScaleDist = true, ArrowPulse = true, ArrowGlow = true, ArrowName = false, ArrowRing = false, ArrowOpacity = 1,
    ArrowSmart = true, ArrowThreat = true, ArrowHealth = true, ArrowGroup = true, ArrowGroupAngle = 10, ArrowLos = true,
    ArrowHeight = true, ArrowAngle = false, ArrowPlate = true,
    -- следы врагов
    FoeTrailOn = false, FoeTrailTime = 2.5, FoeTrailMax = 5, FoeTrailThick = 2, FoeTrailCol = Color3.fromRGB(0, 255, 210),
    AutoLite = false, HitchReport = false,
    TracerOn = false, TracerCol = Color3.fromRGB(118, 150, 255), TracerIntensity = 0.9, TracerSize = 1, TracerGlow = 0.6, TracerLength = 0.45,
    TrailOn = false, TrailCol = Color3.fromRGB(118, 150, 255), TrailIntensity = 0.8, TrailGlow = 0.6, TrailLength = 0.8,
    PlayerViewSkeleton = false, SkeletonCol = Color3.fromRGB(255, 255, 255), SkeletonThick = 1.5, SkeletonHealthColor = false,
    KillFxOn = false, KillFxType = "Cloud", KillFxColor = Color3.fromRGB(118, 150, 255), KillFxSpeed = 4,

    HideHats = false,
    HoloSelf = false,
    HoloColor = Color3.fromRGB(0, 230, 255),
    HoloAlpha = 0.25,
    HoloGlow = 0,

    JumpRings = false,
    JumpRingType = "Both",
    JumpRingFillCol = Color3.fromRGB(48, 209, 88),
    JumpRingOutCol = Color3.fromRGB(255, 255, 255),
    JumpRingGlow = 1.5,
    JumpRingSize = 14,
    JumpRingSpeed = 0.8,

    OrbitOn = false, OrbitCount = 4, OrbitRadius = 6, OrbitSpeed = 2, OrbitSize = 0.8, OrbitTrailThick = 0.35, OrbitTrailLen = 0.7,
    OrbitColor = Color3.fromRGB(60, 255, 180), OrbitTrailColor = Color3.fromRGB(0, 180, 255),

    ActiveTab = "Combat", SelectedCfg = "default",
}

-- сводка настроек
M.Schema = {
    Slider = {
        AimFov = {10, 2000, "px", "x"},
        AimTime = {0, 1000, "мс", "x"},
        AimMouseGain = {0.1, 5, "x", ""},
        AimDeadzone = {0, 100, "px", "x"},
        AimPredict = {0, 0.5, "с", ""},
        AimBulletSpeed = {0, 3000, "", "x"},
        AimLeadMax = {0, 100, "м", ""},
        FovThick = {1, 10, "px", ""},
        TriggerRadius = {0, 300, "px", "x"},
        TriggerDelay = {0.0, 0.5, "с", "x"},
        TriggerInterval = {0.02, 1, "с", ""},
        CombatMaxDist = {50, 5000, "м", "x"},
        FlightSpeed = {5, 1000, "", "x"},
        SprintSpeed = {16, 1000, "", "x"},
        AirSpeed = {50, 1000, "", "x"},
        AirAccel = {1, 100, "", "x"},
        PeekSize = {1, 8, "м", "dx"},
        AimDynStand = {0.2, 1.5, "x", ""},
        AimDynWalk = {0.4, 2.5, "x", ""},
        AimDynJump = {0.4, 3, "x", ""},
        FovFillAlpha = {0.5, 0.99, "", ""},
        HitRingSpeed = {4, 40, "", "ix"},
        HitRingGlow = {0.1, 1, "", ""},
        TeleportSpeed = {0, 5000, "", "x"},
        PlayerViewMaxDist = {100, 20000, "м", "x"},
        PlayerViewBoxThick = {1.0, 15.0, "px", "dx"},
        PlayerViewTextSize = {9, 40, "px", "x"},
        SkeletonThick = {1, 15, "px", "dx"},
        PlayerViewHlLimit = {4, 31, "", ""},
        PlayerViewAlpha = {0, 1, "", ""},
        PlayerViewHealthBarThick = {2, 30, "px", "ix"},
        PlayerViewHpTextSize = {8, 32, "px", "ix"},
        ArrowSize = {12, 150, "px", "x"},
        ArrowOpacity = {0.1, 1, "", ""},
        ArrowRadius = {60, 1500, "px", "x"},
        ArrowMargin = {10, 400, "px", "x"},
        ArrowMaxCount = {1, 30, "", ""},
        FoeTrailTime = {0.5, 8, "с", ""},
        FoeTrailMax = {1, 15, "", ""},
        FoeTrailThick = {1, 8, "px", ""},
        TracerIntensity = {0.1, 1, "", ""},
        TracerSize = {0.2, 10, "x", "x"},
        TracerGlow = {0, 1, "", ""},
        TracerLength = {0.1, 10, "с", "x"},
        KillFxSpeed = {0.5, 100, "", "x"},
        CamFov = {30, 120, "°", ""},
        ThirdPersonDist = {3, 200, "м", "x"},
        ThirdPersonShoulder = {-20, 20, "м", "dx"},
        ThirdPersonHeight = {-5, 20, "м", "dx"},
        ZoomFov = {10, 70, "°", ""},
        ZoomSpeed = {2, 100, "", "x"},
        FreecamSpeed = {2, 500, "", ""},
        FreecamSens = {0.2, 3, "x", ""},
        FreecamSmooth = {0, 1, "", ""},
        ShakeStrength = {0.1, 1, "", ""},
        CustomTime = {0, 24, "", ""},
        TimeCycleSpeed = {1, 1000, "", "x"},
        CloudDensity = {0.01, 1.0, "", ""},
        CloudCover = {0, 100, "%", ""},
        FogDensity = {0.1, 1.0, "", ""},
        FogHaze = {0.0, 6.0, "", ""},
        DarkIntensity = {0.05, 1, "", ""},
        GradeSat = {-1, 2, "", ""},
        GradeContrast = {-0.5, 0.8, "", ""},
        GradeBright = {-0.3, 0.3, "", ""},
        SunRaysIntensity = {0, 1, "", ""},
        SunRaysSpread = {0, 1, "", ""},
        SunRaysBright = {0, 1, "", ""},
        WeatherDensity = {10, 500, "", "x"},
        WeatherSpeed = {10, 400, "", "x"},
        WeatherRadius = {20, 600, "studs", "x"},
        SnowSize = {0.2, 10, "studs", "x"},
        LightningRate = {1, 30, "x", "dx"},
        LightningSize = {0.2, 10, "studs", "x"},
        LightningDuration = {0.1, 10.0, "с", "x"},
        LightningFlashPower = {0.05, 1, "", ""},
        MeteorRate = {1, 30, "x", "dx"},
        MeteorSize = {1, 30, "studs", "dx"},
        MeteorTrailLen = {0.3, 10, "с", "x"},
        MeteorDuration = {0.5, 15.0, "с", "x"},
        HoloAlpha = {0.0, 1.0, "", ""},
        HoloGlow = {0, 10, "", "x"},
        TrailIntensity = {0.1, 1, "", ""},
        TrailGlow = {0, 1, "", ""},
        TrailLength = {0.2, 15, "с", "x"},
        JumpRingGlow = {1.0, 15.0, "x", "dx"},
        JumpRingSize = {4, 100, "studs", "x"},
        JumpRingSpeed = {0.3, 2.5, "с", ""},
        OrbitCount = {1, 24, "", "i"},
        OrbitRadius = {3, 60, "studs", "x"},
        OrbitSpeed = {0.5, 30, "x", "dx"},
        OrbitSize = {0.3, 10, "studs", "x"},
        OrbitTrailThick = {0.1, 1.2, "", ""},
        OrbitTrailLen = {0.2, 2.5, "с", ""},
        PitchAngle = {-90, 90, "°", ""},
        YawSpeed = {5, 500, "", "x"},
        FakeLagTicks = {1, 120, "", "x"},
        FakeLagDelay = {0.05, 5, "с", "x"},
        GhostAlpha = {0.0, 1.0, "", ""},
        GhostCount = {1, 30, "", "x"},
        FpsCullDist = {100, 10000, "studs", "x"},
        AnimSpeed = {0.05, 0.5, "с", ""},
        MenuAlpha = {0, 1, "", ""},
        CardAlpha = {0, 1, "", ""},
        BorderThick = {0, 15, "px", "dx"},
        SideAlpha = {0, 1, "", ""},
        SideCardAlpha = {0, 1, "", ""},
        GlassBlur = {0, 24, "", ""},
        GlassSheen = {0, 1, "", ""},
        NotifyAlpha = {0, 0.9, "", ""},
        NotifyScale = {0.6, 3, "x", "x"},
        PillScaleVal = {0.7, 1.6, "x", "x"},
        PillAlpha = {0, 1, "", ""},
        PillBorderThick = {0, 5, "px", ""},
        SpeedWidgetScale = {0.6, 4, "x", "x"},
        MusicWidgetScale = {0.5, 3, "x", "x"},
        KeysScale = {0.5, 3, "x", ""},
        BindListScale = {0.5, 3, "x", ""},
        KeysAlpha = {0, 1, "", ""},
        KeysRound = {0, 22, "px", ""},
        ArrowGroupAngle = {2, 40, "°", ""},
        HitFxSize = {0.3, 4, "x", ""},
        HitFxPower = {0.1, 3, "", ""},
    },
    Options = {
        AimMode = {"Always", "HoldKey", "HoldRmb"},
        AimPart = {"Head", "Body", "Closest"},
        AimPriority = {"Crosshair", "Distance", "Health"},
        AimMethod = {"Camera", "Mouse", "Auto"},
        TriggerMode = {"Always", "HoldKey", "HoldRmb"},
        TriggerMethod = {"Auto", "Click", "Tool"},
        TriggerPart = {"Any", "Head", "Body"},
        PlayerViewFontWeight = {"Bold", "Medium"},
        PlayerViewHlMode = {"Fixed", "Team", "Wall"},
        PlayerViewHealthPos = {"Left", "Right", "Bottom"},
        ArrowStyle = {"Dart", "Chevron"},
        ArrowColorMode = {"Fixed", "Team", "ByHealth", "ByDistance"},
        ArrowPlacement = {"Circle", "Edge"},
        GradePreset = {"Custom", "Cinematic", "Warm", "Cold", "Vivid", "Noir"},
        WeatherMode = {"Rain", "Snow", "Leaves"},
        JumpRingType = {"Both", "Outline", "Filled"},
        GhostMaterial = {"ForceField", "Neon", "Plastic"},
        Language = {"EN", "RU"},
        FontStyle = {"Gotham", "Bold", "Lazy"},
        KeysStyle = {"Glass", "Solid", "Outline", "Neon"},
        KillFxType = {"Cloud", "Sparks"},
        TiltMode = {"TiltAll", "TiltTorso", "TiltBody"},
        BindListShow = {"BindAll", "BindActive"},
        MusicLayout = {"Pill", "Widget"},
    },
}

M.Data = {
    GlobalPalette = {nil, nil, nil, nil, nil},
    PaletteCallers = {},
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
    NpcPseudo = setmetatable({}, {__mode = "k"}), NpcVersion = 0,
    DragHandler = nil,
    MemStorage = {},
    -- кэши с "слабыми" ключами
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

    -- что было в игре до наших изменений
    AtmoBackup = {},
    CloudBackup = nil,
    OrigCameraMode = nil,
    Importing = false,
    MenuToken = 0,
    OrigZoomMin = 0.5,
    OrigZoomMax = 128,

    FogApplied = false,
    DarkApplied = false,
    TimeApplied = false,
    PoseApplied = false, PoseAutoRotate = false, PoseStatesLocked = false, BackYaw = nil, BackLegsOn = false, BackLegsNames = setmetatable({}, {__mode = "k"}),
    FallProtectionApplied = false,
    TPApplied = false,
    HatsHidden = false,
    HoloApplied = false,

    LastVisual = 0,
    GroundCacheTime = 0,
    Quality = 1,
    FpsBoostToken = 0,
    OwnFolderSet = {},
    Debounce = {},
    RmbCamera = false,
    Fades = {},

    -- свой скайбокс
    SkyFaces = {"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp"},
    SkyBuiltin = {"rbxasset://textures/sky/sky512_bk.tex", "rbxasset://textures/sky/sky512_dn.tex", "rbxasset://textures/sky/sky512_ft.tex",
        "rbxasset://textures/sky/sky512_lf.tex", "rbxasset://textures/sky/sky512_rt.tex", "rbxasset://textures/sky/sky512_up.tex"},
    SkyBackup = nil,  -- что было у Sky игры до нас
    SkyCache = {},
    SkyFallbackReason = nil,
    SkyWanted = nil,  -- последние корректно разобранные 6 граней
    SkyOkKey = "Sky_Ok1",
    SkyToken = 0,
    SkyStatus = nil,
    SkyDetail = nil,

    ZoomHeld = false, ZoomBlend = 0, GameFov = 70, FovApplied = false,

    NotifList = {}, LastCycleUi = 0, AimLock = nil, FogScan = 0,
    TabStrokes = {}, GlassToken = 0,
    LastHealth = nil, ShakeEnergy = 0, LastShake = nil, LastPos = nil, MoveSpeed = 0,
    HpCache = setmetatable({}, {__mode = "k"}), AimSeen = setmetatable({}, {__mode = "k"}), LastShot = -10, FlashUsed = -100, NotifyUsed = -100, LastFolderSweep = 0, StartupLoad = false, SkippedAtStart = {}, PlayerViewConns = {}, LastJump = -10,
    LastGetUp = 0, LastMotorFix = 0, PrevVelocity = nil, PrevGrounded = true, FlingUntil = 0, LastDamage = -10, NormalWalk = nil, NormalJump = nil, NormalJumpHeight = nil, StunSince = nil,
    Panels = {}, ToggleRefs = {}, AccentVersion = 0,
    Speed3D = 0, SpeedShown = 0, SpeedSamples = {}, SpeedClock = 0,
    SpectateTarget = nil, Spectating = false,
    LastRealSync = 0,

    -- объекты по игрокам и эффектам
    Highlights = {}, PlayerViewGuis = {}, PlayerConns = {}, OrbitObjs = {}, WeatherPool = {}, Binds = {},
    -- что было в игре до включения функции (снимок берётся при включении)
    WorldSaved = {},
}

-- элементы меню
M.UI = {Cards = {}, SideCards = {}, Sliders = {}, Pages = {}, TabButtons = {}}
M.CFG = {}
M.F = {}

end}

-- [3/69] Оформление, стекло
MODULES[#MODULES + 1] = {"3. Оформление, стекло", function(M, __X)
-- ==============================================================================
-- [ СТИЛЬ ]
-- ==============================================================================
M.Style = {
    Bg = Color3.fromRGB(10, 11, 17),
    Surface = Color3.fromRGB(13, 14, 21),
    Card = Color3.fromRGB(18, 20, 30),
    Field = Color3.fromRGB(10, 11, 17),
    Raised = Color3.fromRGB(27, 30, 44),
    Stroke = Color3.fromRGB(34, 38, 54),
    Text = Color3.fromRGB(236, 239, 248),
    TextDim = Color3.fromRGB(150, 158, 182),
    TextMute = Color3.fromRGB(100, 108, 132),
    Off = Color3.fromRGB(38, 42, 58),
    Success = Color3.fromRGB(94, 214, 150),
    Warn = Color3.fromRGB(240, 190, 90),
    Danger = Color3.fromRGB(240, 92, 108),
    StrokeIdle = 0.5,
    StrokeActive = 0.35,
    SurfaceGlow = 0.12,
    ControlGlow = 0.45,
}
M.Data.AccentBound = {}
M.Data.GlassSurfaces = {}

-- короткая обёртка над TweenService
function M.Style.Scale()
    return math.clamp((M.State.AnimSpeed or 0.22) / 0.22, 0.2, 3)
end

-- TweenInfo с длительностью, умноженной на множитель скорости
function M.Style.Info(duration, style, direction)
    return TweenInfo.new(duration * M.Style.Scale(), style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
end

-- raw = true
function M.Style.Tween(inst, duration, goal, style, direction, raw)
    local seconds = raw and duration or duration * M.Style.Scale()
    local tween = M.Services.T:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), goal)
    tween:Play()
    return tween
end

-- цвет темы, при желании подмешанный к белому
function M.Style.AccentMix(mix)
    local col = M.State.Accent
    if mix and mix > 0 then return col:Lerp(Color3.new(1, 1, 1), mix) end
    return col
end

-- привязывает свойство объекта к цвету темы
function M.Style.Bind(inst, prop, mix)
    inst[prop] = M.Style.AccentMix(mix)
    local list = M.Data.AccentBound
    if #list > (M.Data.AccentPruneAt or 400) then
        for i = #list, 1, -1 do
            if not list[i].Obj.Parent then table.remove(list, i) end
        end
        M.Data.AccentPruneAt = math.max(400, #list * 2)
    end
    list[#list + 1] = {Obj = inst, Prop = prop, Mix = mix}
    return inst
end

function M.Style.AddStroke(inst, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = color or M.Style.Stroke
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0
    stroke.Parent = inst
    return stroke
end

-- мягкое свечение без картинок
function M.Style.Glow(parent, spread, strength, color, radius, zindex)
    local glow = {Layers = {}, Strength = strength or 0.2}
    local count = 3
    for i = 1, count do
        local grow = spread * (i / count)
        local layer = Instance.new("Frame")
        layer.Name = "Glow"
        layer.AnchorPoint = Vector2.new(0.5, 0.5)
        layer.Position = UDim2.new(0.5, 0, 0.5, 0)
        layer.Size = UDim2.new(1, grow * 2, 1, grow * 2)
        layer.BackgroundColor3 = color or M.State.Accent
        layer.BackgroundTransparency = 1
        layer.BorderSizePixel = 0
        layer.Active = false
        local z = zindex or 1
        pcall(function() layer.ZIndex = z end)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = radius or UDim.new(0.5, 0)
        corner.Parent = layer
        layer.Parent = parent
        glow.Layers[i] = layer
    end
    local function transparencyFor(index, power)
        local falloff = 1 - (index - 1) / count
        return 1 - math.clamp(power * (0.25 + 0.75 * falloff * falloff) / (count * 0.45), 0, 1)
    end
    function glow.Set(power, duration)
        glow.Strength = power
        glow.Token = (glow.Token or 0) + 1
        local token = glow.Token
        local lit = power > 0.001
        local tweened = duration and duration > 0
        for i, layer in ipairs(glow.Layers) do
            local goal = {BackgroundTransparency = transparencyFor(i, power)}
            if tweened then
                if lit and not layer.Visible then layer.Visible = true end
                M.Style.Tween(layer, duration, goal)
            else
                layer.BackgroundTransparency = goal.BackgroundTransparency
                layer.Visible = lit
            end
        end
        if tweened and not lit then
            task.delay(duration * M.Style.Scale() + 0.05, function()
                if glow.Token ~= token then return end
                for _, layer in ipairs(glow.Layers) do
                    if layer.Parent then layer.Visible = false end
                end
            end)
        end
    end
    function glow.SetColor(col, duration)
        for _, layer in ipairs(glow.Layers) do
            if duration and duration > 0 then
                M.Style.Tween(layer, duration, {BackgroundColor3 = col})
            else
                layer.BackgroundColor3 = col
            end
        end
    end
    glow.Set(glow.Strength, 0)
    return glow
end

-- свечение, которое следует за цветом темы
function M.Style.AccentGlow(parent, spread, strength, radius, zindex)
    local glow = M.Style.Glow(parent, spread, strength, M.State.Accent, radius, zindex)
    for _, layer in ipairs(glow.Layers) do M.Style.Bind(layer, "BackgroundColor3") end
    return glow
end

-- матовое тёмное стекло
function M.Style.BuildGlass(parent, radius, opts)
    opts = opts or {}
    local z = opts.ZIndex or 1
    local glass = {Parts = {}, Corners = {}, Strokes = {}, Parent = parent, Ios = opts.Ios == true, Level = 1, Radius = radius, Built = false}

    local function layer(name)
        local frame = Instance.new("Frame")
        frame.Name = name
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BorderSizePixel = 0
        frame.Active = false
        pcall(function() frame.ZIndex = z end)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = glass.Radius
        corner.Parent = frame
        glass.Corners[#glass.Corners + 1] = corner
        glass.Parts[#glass.Parts + 1] = frame
        return frame
    end

    -- прозрачность слоя целиком
    function glass.Alpha(level, duration)
        glass.Level = level
        if not glass.Built then return end
        for _, frame in ipairs(glass.Parts) do
            if frame.Name ~= "GlassInner" then
                if duration and duration > 0 then M.Style.Tween(frame, duration, {BackgroundTransparency = 1 - level})
                else frame.BackgroundTransparency = 1 - level end
            end
        end
        for _, st in ipairs(glass.Strokes) do
            if duration and duration > 0 then M.Style.Tween(st, duration, {Transparency = 1 - level})
            else st.Transparency = 1 - level end
        end
    end

    local function build()
        glass.Built = true
        if not opts.NoSheen then
            local sheen = layer("GlassSheen")
            sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            local g = Instance.new("UIGradient")
            g.Rotation = 90
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.86), NumberSequenceKeypoint.new(0.4, 0.96), NumberSequenceKeypoint.new(1, 1)
            })
            g.Parent = sheen
            sheen.Parent = parent
        end

        local shade = layer("GlassShade")
        shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        local sg = Instance.new("UIGradient")
        sg.Rotation = 90
        sg.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 0.86)
        })
        sg.Parent = shade
        shade.Parent = parent

        local inner = layer("GlassInner")
        inner.BackgroundTransparency = 1
        inner.Position = UDim2.new(0, 1, 0, 1)
        inner.Size = UDim2.new(1, -2, 1, -2)
        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Thickness = 1
        stroke.Transparency = 0
        stroke.Parent = inner
        local ig = Instance.new("UIGradient")
        ig.Rotation = 90
        ig.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.74), NumberSequenceKeypoint.new(0.5, 0.95), NumberSequenceKeypoint.new(1, 0.86)
        })
        ig.Parent = stroke
        inner.Parent = parent
        glass.Strokes[#glass.Strokes + 1] = stroke
        -- прозрачность, заданную до создания слоёв
        if glass.Level ~= 1 then glass.Alpha(glass.Level) end
    end

    function glass.SetVisible(on)
        on = on and true or false
        if on and not glass.Built then build() end
        for _, frame in ipairs(glass.Parts) do frame.Visible = on end
    end
    function glass.SetRadius(r)
        glass.Radius = r
        for _, corner in ipairs(glass.Corners) do corner.CornerRadius = r end
    end

    local list = M.Data.GlassSurfaces
    if #list > 60 then
        for i = #list, 1, -1 do
            if not list[i].Parent.Parent then table.remove(list, i) end
        end
    end
    list[#list + 1] = glass
    glass.SetVisible(M.State.GlassOn and (not glass.Ios or M.State.Ios26On))
    return glass
end
-- чистка реестров от разрушенных объектов
function M.F.PruneRegistries()
    local D = M.Data
    local list = D.AccentBound
    local j = 0
    for i = 1, #list do
        local item = list[i]
        if item.Obj.Parent then
            j = j + 1
            list[j] = item
        end
    end
    for i = #list, j + 1, -1 do list[i] = nil end
    D.AccentPruneAt = math.max(400, #list * 2)
    local glass = D.GlassSurfaces
    j = 0
    for i = 1, #glass do
        local g = glass[i]
        if g.Parent and g.Parent.Parent then
            j = j + 1
            glass[j] = g
        end
    end
    for i = #glass, j + 1, -1 do glass[i] = nil end
end

-- включает/выключает стекло у всех поверхностей разом
function M.Style.ApplyGlassSurfaces()
    for _, glass in ipairs(M.Data.GlassSurfaces) do
        if glass.Parent and glass.Parent.Parent then
            glass.SetVisible(M.State.GlassOn and (not glass.Ios or M.State.Ios26On))
        end
    end
end

end}

-- [4/69] Подписки, список игроков, отложенные вызовы
MODULES[#MODULES + 1] = {"4. Подписки, список игроков, отложенные вызовы", function(M, __X)
-- ==============================================================================
-- [ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ]
-- ==============================================================================

-- запоминаем соединение, чтобы ShutDown смог его отключить
function M.Track(conn)
    table.insert(M.Data.Conns, conn)
    return conn
end

-- обход всех потомков объекта по кусочкам
function M.F.SliceWalk(root, visit, alive, skip, budget)
    budget = budget or 0.002
    local stack, top = {root}, 1
    local mark, n = os.clock(), 0
    while top > 0 do
        local inst = stack[top]
        stack[top] = nil
        top = top - 1
        local ok, kids = pcall(inst.GetChildren, inst)
        if ok then
            for i = 1, #kids do
                local child = kids[i]
                if not (skip and skip(child)) then
                    pcall(visit, child)
                    top = top + 1
                    stack[top] = child
                end
            end
        end
        n = n + 1
        if n % 32 == 0 and os.clock() - mark > (M.F.FrameBudget and M.F.FrameBudget(budget) or budget) then
            task.wait()
            mark = os.clock()
            if alive and not alive() then return false end
        end
    end
    return true
end

-- список игроков без нового массива на каждый вызов
function M.F.Players()
    local D = M.Data
    local now = os.clock()
    local list = D.PlayerList
    if not list or D.PlayerListDirty or now - D.PlayerListAt > 3 then
        list = M.Services.P:GetPlayers()
        D.PlayerList, D.PlayerListDirty, D.PlayerListAt = list, false, now
        D.Merged = nil
    end
    local npcs = D.Npcs
    if npcs and next(npcs) ~= nil then
        local merged = D.Merged
        if not merged or D.MergedVersion ~= D.NpcVersion then
            merged = {}
            for i = 1, #list do merged[i] = list[i] end
            for _, npc in pairs(npcs) do merged[#merged + 1] = npc end
            D.Merged, D.MergedVersion = merged, D.NpcVersion
        end
        return merged
    end
    return list
end
M.Track(M.Services.P.PlayerAdded:Connect(function() M.Data.PlayerListDirty = true end))
M.Track(M.Services.P.PlayerRemoving:Connect(function() M.Data.PlayerListDirty = true end))

-- откладывает вызов fn
function M.F.Debounce(key, delay, fn)
    local token = (M.Data.Debounce[key] or 0) + 1
    M.Data.Debounce[key] = token
    task.delay(delay, function()
        if M.Data.Debounce[key] == token and not M.Run.IsShutDown then
            fn()
        end
    end)
end

end}

-- [5/69] Математика, реестр элементов меню, цвет темы
MODULES[#MODULES + 1] = {"5. Математика, реестр элементов меню, цвет темы", function(M, __X)
-- ==============================================================================
-- [ ВСПОМОГАТЕЛЬНАЯ МАТЕМАТИКА ]
-- ==============================================================================
M.Math = {}

-- плавное приближение к цели, не зависящее от FPS
function M.Math.Smooth(current, target, dt, speed)
    local alpha = 1 - math.exp(-math.max(speed, 0) * math.max(dt, 0))
    local nextValue = current + (target - current) * alpha
    if math.abs(target - nextValue) < 0.0005 then return target end
    return nextValue
end

-- часы суток
function M.Math.AdvanceClock(clock, dt, hoursPerMinute)
    return (clock + dt * hoursPerMinute / 60) % 24
end

-- число из настроек без NaN и бесконечности
function M.Math.Finite(value, fallback)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return fallback end
    return value
end

-- доля здоровья 0..1 без NaN
function M.Math.HpFraction(health, maxHealth)
    if health ~= health or health <= 0 then return 0 end
    if maxHealth ~= maxHealth or maxHealth == math.huge or health == math.huge then return 1 end
    if maxHealth < 1 then maxHealth = 1 end
    local f = health / maxHealth
    return f > 1 and 1 or f
end

-- конечное ли положение
function M.F.FiniteVec(v)
    local x, y, z = v.X, v.Y, v.Z
    return x == x and y == y and z == z and x > -1e8 and x < 1e8 and y > -1e8 and y < 1e8 and z > -1e8 and z < 1e8
end

-- цвет по доле здоровья: зелёный, жёлтый, красный
local healthColors = {}
function M.Math.HealthColor(fraction)
    -- доля округляется до 1/40, оттенки запоминаются: новый Color3 на каждого игрока в каждом кадре не нужен
    local step = math.floor(math.clamp(fraction ~= fraction and 0 or fraction, 0, 1) * 40 + 0.5)
    local cached = healthColors[step]
    if cached then return cached end
    local f = step / 40
    local col
    if f < 0.5 then
        col = Color3.fromRGB(255, 60, 60):Lerp(Color3.fromRGB(255, 200, 40), f * 2)
    else
        col = Color3.fromRGB(255, 200, 40):Lerp(Color3.fromRGB(60, 220, 90), (f - 0.5) * 2)
    end
    healthColors[step] = col
    return col
end

-- своя проекция на экран: та же математика, что у Camera:WorldToViewportPoint, но без обращения к движку
-- и без новых объектов. ProjBegin берёт камеру один раз, дальше Project только считает
local proj = {x = 0, y = 0, z = 0, r00 = 1, r01 = 0, r02 = 0, r10 = 0, r11 = 1, r12 = 0, r20 = 0, r21 = 0, r22 = 1, W = 1, H = 1, kx = 1, ky = 1}
function M.Math.ProjBegin(cam)
    local P = proj
    P.x, P.y, P.z, P.r00, P.r01, P.r02, P.r10, P.r11, P.r12, P.r20, P.r21, P.r22 = cam.CFrame:Inverse():GetComponents()
    local vs = cam.ViewportSize
    local w, h = math.max(vs.X, 1), math.max(vs.Y, 1)
    local th = math.tan(math.rad(math.clamp(cam.FieldOfView, 1, 179)) / 2)
    P.W, P.H, P.ky, P.kx = w, h, 1 / th, h / (th * w)
end

-- экранные x, y и глубина (глубина <= 0 - точка за камерой)
function M.Math.Project(p)
    local P = proj
    local px, py, pz = p.X, p.Y, p.Z
    local rx = P.r00 * px + P.r01 * py + P.r02 * pz + P.x
    local ry = P.r10 * px + P.r11 * py + P.r12 * pz + P.y
    local depth = -(P.r20 * px + P.r21 * py + P.r22 * pz + P.z)
    local d = depth
    if d > -1e-6 and d < 1e-6 then d = 1e-6 end
    return (rx / d * P.kx * 0.5 + 0.5) * P.W, (-ry / d * P.ky * 0.5 + 0.5) * P.H, depth
end

-- то же в готовую таблицу {X, Y, Z}, чтобы код с полями .X .Y .Z не менялся
function M.Math.ProjectInto(t, p)
    t.X, t.Y, t.Z = M.Math.Project(p)
    return t
end

-- на экране ли точка (как второе значение WorldToViewportPoint)
function M.Math.OnScreen(x, y, depth)
    return depth > 0 and x >= 0 and y >= 0 and x <= proj.W and y <= proj.H
end

-- один отрезок линии между точками
function M.Math.LineSegment(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return (x1 + x2) / 2, (y1 + y2) / 2, math.sqrt(dx * dx + dy * dy), math.deg(math.atan2(dy, dx))
end

-- в круге показывается настоящая аватарка игрока
function M.F.NewAvatarView(parent)
    local view = Instance.new("Frame")
    view.BackgroundTransparency = 0.55
    view.BorderSizePixel = 0
    Instance.new("UICorner", view).CornerRadius = UDim.new(1, 0)
    view.Parent = parent
    -- подложка аватарки следует за цветом темы
    M.Style.Bind(view, "BackgroundColor3")

    local okId, userId = pcall(function() return M.LP.UserId end)
    if okId and type(userId) == "number" and userId > 0 then
        local img = Instance.new("ImageLabel")
        img.Name = "Headshot"
        img.Size = UDim2.new(1, 0, 1, 0)
        img.BackgroundTransparency = 1
        img.BorderSizePixel = 0
        img.ScaleType = Enum.ScaleType.Crop
        img.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
        Instance.new("UICorner", img).CornerRadius = UDim.new(1, 0)
        img.Parent = view
        task.spawn(function()
            for attempt = 1, 5 do
                local started = os.clock()
                while img.Parent and not img.IsLoaded and os.clock() - started < 4 do task.wait(0.2) end
                if not img.Parent or img.IsLoaded then return end
                local ok, content, ready = pcall(function()
                    return M.Services.P:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
                end)
                if ok and content and ready then img.Image = content end
                task.wait(attempt)
            end
        end)
    end
    return view
end

-- записывает значение в состояние И обновляет элемент меню
local NO_ENTRIES = {}
function M.F.VisualEntries(key)
    local D = M.Data
    local reg = D.RegUI
    if D.VisualIndexSize ~= #reg then
        D.VisualIndexSize = #reg
        local index = {}
        for _, el in ipairs(reg) do
            if el.Key and el.SetVisual then
                local list = index[el.Key]
                if not list then list = {}; index[el.Key] = list end
                list[#list + 1] = el
            end
        end
        D.VisualIndex = index
    end
    return D.VisualIndex[key] or NO_ENTRIES
end

function M.F.SetStateVisual(key, value)
    M.State[key] = value
    for _, el in ipairs(M.F.VisualEntries(key)) do el.SetVisual(value) end
end

-- высота земли рядом с игроком
function M.F.GroundHeightAt(x, z, referenceY)
    local D = M.Data
    local now = os.clock()
    local cache = D.GroundCache
    if not cache or now - D.GroundCacheTime > 5 then
        cache = {}
        D.GroundCache, D.GroundCacheTime = cache, now
    end
    local key = math.floor(x / 4) * 262144 + math.floor(z / 4)
    local y = cache[key]
    if y == nil then
        local result = workspace:Raycast(Vector3.new(x, referenceY + 120, z), Vector3.new(0, -400, 0), M.RayParams)
        y = result and result.Position.Y or false
        cache[key] = y
    end
    if y and math.abs(y - referenceY) <= 60 then
        return y
    end
    return referenceY
end

-- одинаковы ли два значения
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

-- записывает свойство, только если оно действительно отличается
function M.F.SetProp(inst, prop, value)
    if not M.F.SameValue(inst[prop], value) then inst[prop] = value end
end

-- меняет основной цвет меню везде
function M.F.RecolorAccent(col)
    M.State.Accent = col
    M.Data.AccentVersion = M.Data.AccentVersion + 1
    for _, item in ipairs(M.Data.AccentBound) do
        if item.Obj.Parent then
            item.Obj[item.Prop] = (item.Mix and item.Mix > 0) and col:Lerp(Color3.new(1, 1, 1), item.Mix) or col
        end
    end
    for _, frame in ipairs(M.UI.Sliders) do frame.BackgroundColor3 = col end
    for _, ref in ipairs(M.Data.BindRefs or {}) do
        if ref.Btn.Parent and ref.Active() and M.Run.ListeningBind == nil then
            if ref.Show then ref.Show() else ref.Btn.TextColor3 = col end
        end
    end
    for _, ref in ipairs(M.Data.ToggleRefs) do
        if ref.Track.Parent and ref.IsOn() then ref.Track.BackgroundColor3 = col end
        if ref.Glow and ref.IsOn() then ref.Glow.SetColor(col) end
    end
    -- активная вкладка
    if M.F.StyleTabs then M.F.StyleTabs(0.2) else
        local tab = M.UI.TabButtons[M.State.ActiveTab]
        if tab then tab.TextColor3 = M.Style.AccentMix(0.35) end
    end
    for _, stroke in pairs(M.Data.TabStrokes) do stroke.Color = col end
    if M.UI.Pill and M.F.RestyleAllPanels then M.F.RestyleAllPanels() end
end

end}

-- [6/69] Загрузка модулей по требованию, поиск частей персонажа
MODULES[#MODULES + 1] = {"6. Загрузка модулей по требованию, поиск частей персонажа", function(M, __X)
-- ==============================================================================
-- [ ЛЕНИВАЯ ЗАГРУЗКА МОДУЛЕЙ ]
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

-- снимает подписку и убирает её из общего списка
function M.F.Untrack(conn)
    for i = #M.Data.Conns, 1, -1 do
        if M.Data.Conns[i] == conn then table.remove(M.Data.Conns, i) end
    end
    conn:Disconnect()
end

-- временные записи в реестре меню
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

-- короткая запись
function M.Conn(signal, fn)
    return M.Track(signal:Connect(fn))
end

-- поднимаемся от детали вверх, пока не найдём персонажа
function M.GetCharacterFromPart(part)
    local players = M.Services.P
    local current = part
    while current and current ~= workspace do
        if current:IsA("Model") and (players:GetPlayerFromCharacter(current) or current:FindFirstChildOfClass("Humanoid")) then
            return current
        end
        current = current.Parent
    end
    return nil
end

-- только детали
local function asPart(inst)
    if inst and inst:IsA("BasePart") then return inst end
    return nil
end

-- корневая деталь персонажа
local rootCache = setmetatable({}, {__mode = "k"})
function M.GetRoot(char)
    if not char then return nil end
    local e = rootCache[char]
    local now = os.clock()
    if e then
        local v = e.v
        if v then
            if now - (e.chk or 0) < 0.25 and (e.final or now - e.t < 0.25) then return v end
            if v.Parent == char and (e.final or now - e.t < 0.25) then
                e.chk = now
                return v
            end
        end
    end
    local found = asPart(char:FindFirstChild("HumanoidRootPart")) or char.PrimaryPart or asPart(char:FindFirstChild("UpperTorso"))
        or asPart(char:FindFirstChild("Torso")) or asPart(char:FindFirstChild("LowerTorso")) or char:FindFirstChildWhichIsA("BasePart")
    local final = found ~= nil and found.Name == "HumanoidRootPart"
    if e then
        e.v, e.t, e.final = found, os.clock(), final
    else
        rootCache[char] = {v = found, t = os.clock(), final = final}
    end
    return found
end

-- универсальные поисковики частей персонажа
local partCache = {Humanoid = setmetatable({}, {__mode = "k"}), Head = setmetatable({}, {__mode = "k"})}

local function cachedLookup(kind, char, finder)
    local bucket = partCache[kind]
    local entry = bucket[char]
    local now = os.clock()
    if entry then
        local v = entry.v
        if v then
            -- проверка «на месте ли» не чаще 4 раз в секунду: она стоит обращения к движку
            if now - (entry.chk or 0) < 0.25 then return v end
            local parent = v.Parent
            if parent == char or (parent and v:IsDescendantOf(char)) then
                entry.chk = now
                return v
            end
        elseif now - entry.t < 0.5 then
            return nil
        end
    end
    local found = finder(char)
    -- запись обновляется на месте
    if entry then
        entry.v, entry.t = found, now
    else
        bucket[char] = {v = found, t = now}
    end
    return found
end

function M.GetHumanoid(char)
    if not char then return nil end
    return cachedLookup("Humanoid", char, function(c)
        return c:FindFirstChildOfClass("Humanoid") or c:FindFirstChildWhichIsA("Humanoid", true)
    end)
end

function M.GetHead(char)
    if not char then return nil end
    local head = cachedLookup("Head", char, function(c)
        local h = c:FindFirstChild("Head") or c:FindFirstChild("Head", true)
        return h and h:IsA("BasePart") and h or nil
    end)
    return head or M.GetRoot(char)
end

-- всё о собственном персонаже за один вызов
function M.GetSelf()
    local char = M.LP and M.LP.Character
    local hum = char and M.GetHumanoid(char)
    return char, hum, M.GetRoot(char), (hum ~= nil and hum.Health > 0)
end

-- здоровье персонажа: своё здоровье игры (атрибут или значение Health/HP), иначе Humanoid
local HEALTH_NAMES = {"Health", "HP", "Hp", "health", "hp"}
local MAXHP_NAMES = {"MaxHealth", "MaxHP", "MaxHp", "maxHealth", "maxhp"}
local healthSrc = setmetatable({}, {__mode = "k"})

local function findNumber(char, names)
    for _, n in ipairs(names) do
        if type(char:GetAttribute(n)) == "number" then return n, nil end
        local o = char:FindFirstChild(n)
        if o and (o:IsA("NumberValue") or o:IsA("IntValue")) then return nil, o end
    end
    return nil, nil
end

-- откуда брать своё здоровье игры (ищется раз в 2 секунды на персонажа)
local function healthSource(char)
    local now = os.clock()
    local c = healthSrc[char]
    if not c or now - c.t > 2 then
        c = c or {}
        c.t = now
        local okH, attr, obj = pcall(findNumber, char, HEALTH_NAMES)
        c.attr, c.obj = okH and attr or nil, okH and obj or nil
        c.maxAttr, c.maxObj = nil, nil
        if c.attr or c.obj then
            local okM, mAttr, mObj = pcall(findNumber, char, MAXHP_NAMES)
            if okM then c.maxAttr, c.maxObj = mAttr, mObj end
        end
        healthSrc[char] = c
    end
    return c
end

-- здоровье, максимум и «жив ли» за один проход: каждое свойство читается не больше одного раза
function M.F.CharVitals(char, hum)
    local humHp = hum and hum.Health
    local c = char and healthSource(char)
    if c and (c.attr or c.obj) then
        local v
        if c.attr then v = char:GetAttribute(c.attr) elseif c.obj.Parent then v = c.obj.Value end
        if type(v) == "number" and v == v then
            local m
            if c.maxAttr then m = char:GetAttribute(c.maxAttr) elseif c.maxObj and c.maxObj.Parent then m = c.maxObj.Value end
            if type(m) ~= "number" or m ~= m or m <= 0 then
                local mh = hum and hum.MaxHealth or 100
                m = (mh > 0 and v <= mh) and mh or math.max(100, v)
            end
            return v, m, v > 0 and (humHp == nil or humHp > 0), true
        end
    end
    if hum then return humHp, hum.MaxHealth, humHp > 0, false end
    -- без Humanoid и без своего здоровья игры: персонаж цел, пока модель в мире и у неё есть корень
    local alive = char ~= nil and char.Parent ~= nil and M.GetRoot(char) ~= nil
    return 100, 100, alive, false
end

function M.F.CharHealth(char, hum)
    local h, m, _, custom = M.F.CharVitals(char, hum)
    return h, m, custom
end

-- жив ли персонаж: Humanoid жив и своё здоровье игры (если есть) больше нуля;
-- модель без Humanoid жива, пока она в мире и у неё есть корень
function M.F.IsAliveChar(char, hum)
    local _, _, alive = M.F.CharVitals(char, hum)
    return alive
end
-- персонаж игрока: Player.Character, а если игра его не ставит - модель с именем игрока в мире
M.Data.AltChars = setmetatable({}, {__mode = "k"})
M.Data.AltOwner = setmetatable({}, {__mode = "k"})
function M.F.CharOf(p)
    local c = p.Character
    if c then return c end
    local alt = M.Data.AltChars[p]
    if alt and alt.Parent then return alt end
    return nil
end

-- поиск моделей игроков без Player.Character: верхний уровень мира и папки до двух уровней.
-- Обычное возрождение (несколько секунд без персонажа) поиск не запускает; сначала смотрятся папки, где модели уже
-- находились, а полный обход идёт порциями по кадрам, чтобы большая карта не давала фриз
M.Data.AltMissSince = setmetatable({}, {__mode = "k"})
M.Data.AltHomes = setmetatable({}, {__mode = "k"})
function M.F.ScanAltChars()
    local D = M.Data
    local now = os.clock()
    local missing, any = {}, false
    for _, p in ipairs(M.Services.P:GetPlayers()) do
        if p ~= M.LP then
            if p.Character then
                D.AltMissSince[p] = nil
                local old = D.AltChars[p]
                if old then D.AltOwner[old] = nil; D.AltChars[p] = nil end
            else
                local cur = D.AltChars[p]
                if not (cur and cur.Parent) then
                    local since = D.AltMissSince[p]
                    if not since then since = now; D.AltMissSince[p] = now end
                    if now - since >= 4 then
                        missing[p.Name] = p
                        if p.DisplayName ~= p.Name and not missing[p.DisplayName] then missing[p.DisplayName] = p end
                        any = true
                    end
                end
            end
        end
    end
    if not any then return end
    local function consider(m)
        if not m:IsA("Model") then return end
        local p = missing[m.Name]
        if p and m:FindFirstChildWhichIsA("BasePart", true) then
            D.AltChars[p] = m
            D.AltOwner[m] = p
            if m.Parent then D.AltHomes[m.Parent] = true end
            missing[m.Name] = nil
            if p.DisplayName ~= p.Name then missing[p.DisplayName] = nil end
            if p.Name ~= m.Name then missing[p.Name] = nil end
        end
    end
    -- 1. папки, где модели игроков уже находились
    for home in pairs(D.AltHomes) do
        if home.Parent then
            for _, c in ipairs(home:GetChildren()) do consider(c) end
        else
            D.AltHomes[home] = nil
        end
    end
    if next(missing) == nil then return end
    -- 2. полный обход порциями; если он ничего не нашёл (игроки в лобби вообще без модели), следующий - позже
    if now < (D.AltFullAt or 0) then return end
    local foundBefore = 0
    for _ in pairs(missing) do foundBefore = foundBefore + 1 end
    local budget = M.F.FrameBudget and M.F.FrameBudget(0.0006) or 0.0006
    local mark, n = os.clock(), 0
    local function pause()
        n = n + 1
        if n % 48 == 0 and os.clock() - mark > budget then
            task.wait()
            mark = os.clock()
        end
        return M.Run.IsShutDown or next(missing) == nil
    end
    local function container(inst)
        return inst:IsA("Folder") or (inst:IsA("Model") and inst:FindFirstChildWhichIsA("BasePart") == nil)
    end
    for _, c in ipairs(workspace:GetChildren()) do
        if c.Parent then
            consider(c)
            if pause() then return end
            if container(c) then
                for _, cc in ipairs(c:GetChildren()) do
                    consider(cc)
                    if pause() then return end
                    if cc.Parent and container(cc) then
                        for _, ccc in ipairs(cc:GetChildren()) do
                            consider(ccc)
                            if pause() then return end
                        end
                    end
                end
            end
        end
    end
    local left = 0
    for _ in pairs(missing) do left = left + 1 end
    if left >= foundBefore then
        D.AltBackoff = math.min((D.AltBackoff or 0) + 10, 30)
        D.AltFullAt = os.clock() + D.AltBackoff
    else
        D.AltBackoff, D.AltFullAt = 0, 0
    end
end
task.spawn(function()
    while not M.Run.IsShutDown do
        task.wait(2)
        local S = M.State
        if S.PlayerView or S.AimAssist or S.TriggerAssist or S.ArrowsOn or S.FoeTrailOn then pcall(M.F.ScanAltChars) end
    end
end)

function M.GetTorso(char)
    if not char then return nil end
    return asPart(char:FindFirstChild("UpperTorso")) or asPart(char:FindFirstChild("Torso")) or M.GetRoot(char)
end

-- эффекты скрипта вне наших папок (свет голограммы на персонаже)
M.Data.OwnLoose = setmetatable({}, {__mode = "k"})
function M.F.MarkOwned(inst)
    M.Data.OwnLoose[inst] = true
    return inst
end

-- принадлежит ли объект скрипту
function M.IsOwned(obj)
    if M.Data.OwnLoose[obj] then return true end
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

-- нижний регистр с кириллицей
function M.Lower(str)
    local ok, result = pcall(function()
        local out = {}
        for _, cp in utf8.codes(str) do
            if cp >= 0x410 and cp <= 0x42F then
                cp = cp + 32
            elseif cp == 0x401 then
                cp = 0x451
            elseif cp >= 65 and cp <= 90 then
                cp = cp + 32
            end
            table.insert(out, utf8.char(cp))
        end
        return table.concat(out)
    end)
    return ok and result or str:lower()
end

-- снимок свойств игры при включении функции; повторный вызов снимок не перезаписывает
function M.F.WorldSave(id, inst, props)
    local saved = M.Data.WorldSaved
    if saved[id] then return end
    local snap = {Inst = inst, Values = {}}
    for _, prop in ipairs(props) do
        local ok, value = pcall(function() return inst[prop] end)
        if ok then snap.Values[prop] = value end
    end
    saved[id] = snap
end

-- возвращает снятые значения и забывает снимок
function M.F.WorldRestore(id)
    local saved = M.Data.WorldSaved
    local snap = saved[id]
    if not snap then return end
    saved[id] = nil
    for prop, value in pairs(snap.Values) do
        pcall(function() snap.Inst[prop] = value end)
    end
end

do
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

end}

-- [7/69] Шрифты, команды, папки и лучи, круги от прыжков
MODULES[#MODULES + 1] = {"7. Шрифты, команды, папки и лучи, круги от прыжков", function(M, __X)
-- ==============================================================================
-- [ ШРИФТ ИНТЕРФЕЙСА ]
-- ==============================================================================
do
local FONT_CLASS = {Gotham = "R", GothamMedium = "M", GothamBold = "B", GothamBlack = "H"}
local FONT_SPECS = {
    Lazy = {Family = "SourceSansPro", Style = Enum.FontStyle.Italic, R = Enum.FontWeight.Regular, M = Enum.FontWeight.SemiBold, B = Enum.FontWeight.Bold, H = Enum.FontWeight.Bold},
    Bold = {Legacy = {R = Enum.Font.GothamBlack, M = Enum.Font.GothamBlack, B = Enum.Font.GothamBlack, H = Enum.Font.GothamBlack}}
}
local FONT_FALLBACK = {Lazy = Enum.Font.SourceSansItalic}

local function isTextObject(obj)
    return obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")
end

local function applyFontTo(obj)
    if not obj.Parent then return end
    local orig = M.Data.FontOrig[obj]
    local spec = FONT_SPECS[M.State.FontStyle]
    if not spec then
        -- стандартный шрифт
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

-- применяет выбранный шрифт ко всем надписям интерфейса
function M.F.ApplyFont(root)
    local roots = {}
    if root then
        roots[1] = root
    else
        for _, gui in ipairs({M.UI.Gui, M.UI.PillGui, M.UI.NotifyGui, M.UI.WidgetGui, M.UI.ConfirmGui}) do
            if gui then roots[#roots + 1] = gui end
        end
    end
    for _, gui in ipairs(roots) do
        for _, obj in ipairs(gui:GetDescendants()) do
            if isTextObject(obj) then applyFontTo(obj) end
        end
    end
    -- у другого шрифта другая ширина
    if M.F.RefitAll then task.defer(M.F.RefitAll) end
end

-- следит за окном
function M.F.WatchFonts(gui)
    if not gui then return end
    if FONT_SPECS[M.State.FontStyle] then M.F.ApplyFont(gui) end
    gui.DescendantAdded:Connect(function(obj)
        if FONT_SPECS[M.State.FontStyle] and isTextObject(obj) then
            task.defer(applyFontTo, obj)
        end
    end)
end
end

do
local TEAM_KEYS = {"Team", "TeamName", "TeamId", "TeamID", "TeamColor", "Side", "Faction"}
local teamCache = setmetatable({}, {__mode = "k"})

-- значение командного ключа у игрока
local NO_TEAM_VALUES = {none = true, neutral = true, spectator = true, spectators = true, noteam = true,
    ["no team"] = true, unassigned = true, ["nil"] = true, ["false"] = true, null = true}

local function readTeamValue(plr, name)
    local char = M.F.CharOf(plr)
    local v = plr:GetAttribute(name)
    if v == nil and char then v = char:GetAttribute(name) end
    if v == nil then
        local leaderstats = plr:FindFirstChild("leaderstats")
        local obj = plr:FindFirstChild(name) or (char and char:FindFirstChild(name)) or (leaderstats and leaderstats:FindFirstChild(name))
        if obj and obj:IsA("ValueBase") then v = obj.Value end
    end
    if v == nil or v == false or v == "" then return nil end
    if type(v) == "string" and NO_TEAM_VALUES[v:lower()] then return nil end
    return v
end

-- собственная система команд игры
local function customTeamRelation(a, b)
    for _, name in ipairs(TEAM_KEYS) do
        local va, vb = readTeamValue(a, name), readTeamValue(b, name)
        if va ~= nil and vb ~= nil then return va == vb end
    end
    return nil
end

local function computeTeammate(p)
    -- 1. Стандартные команды Roblox
    local myTeam, hisTeam = M.LP.Team, p.Team
    if myTeam ~= nil or hisTeam ~= nil then
        if myTeam == nil or myTeam ~= hisTeam then return false end
        return customTeamRelation(M.LP, p) ~= false
    end
    -- 2. TeamColor без объекта Team
    if not M.LP.Neutral and not p.Neutral then
        return M.LP.TeamColor == p.TeamColor
    end
    -- 3. Собственная система команд игры
    return customTeamRelation(M.LP, p) == true
end

-- режим «каждый сам за себя»: команда в игре одна или их нет, а союзниками выходят все - значит союзников нет
local ffaState = {At = -10, V = false}
local function ffaMode()
    local now = os.clock()
    if now - ffaState.At < 1 then return ffaState.V end
    ffaState.At = now
    local teams = 0
    local okT, svc = pcall(function() return game:FindService("Teams") end)
    if okT and svc then
        for _, c in ipairs(svc:GetChildren()) do
            if c:IsA("Team") then teams = teams + 1 end
        end
    end
    local v = false
    if teams <= 1 then
        local others, mates = 0, 0
        for _, p in ipairs(M.Services.P:GetPlayers()) do
            if p ~= M.LP then
                others = others + 1
                if computeTeammate(p) then mates = mates + 1 end
            end
        end
        v = others >= 3 and mates == others
    end
    ffaState.V = v
    return v
end
M.F.FfaMode = ffaMode

-- смена команды у игрока сразу сбрасывает его запись; у вас - все записи
local teamWatched = setmetatable({}, {__mode = "k"})
local function watchTeam(p)
    if teamWatched[p] then return end
    local conns = {}
    teamWatched[p] = conns
    local function drop()
        if p == M.LP then
            table.clear(teamCache)
            ffaState.At = -10
        else
            teamCache[p] = nil
        end
    end
    for _, prop in ipairs({"Team", "TeamColor", "Neutral"}) do
        pcall(function() conns[#conns + 1] = p:GetPropertyChangedSignal(prop):Connect(drop) end)
    end
end
-- игрок вышел: его подписки отключаются, иначе они держали бы его в памяти
table.insert(M.Data.Conns, M.Services.P.PlayerRemoving:Connect(function(p)
    local conns = teamWatched[p]
    teamWatched[p] = nil
    teamCache[p] = nil
    if conns then
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    end
end))
-- выгрузка скрипта: все подписки на команды тоже отключаются
function M.F.UnwatchTeams()
    for p, conns in pairs(teamWatched) do
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        teamWatched[p] = nil
    end
    table.clear(teamCache)
end

-- результат держится секунду: стандартные команды сбрасывают его сразу по событию, свои команды игры обновятся через секунду
function M.IsTeammate(p)
    if not p then return false end
    if p == M.LP then return true end
    if M.Data.NpcPseudo[p] then return false end
    local now = os.clock()
    local c = teamCache[p]
    if c and now - c.t < 1 then return c.v end
    if M.LP then watchTeam(M.LP) end
    watchTeam(p)
    local v = (computeTeammate(p) and not ffaMode()) and true or false
    if c then
        c.t, c.v = now, v
    else
        teamCache[p] = {t = now, v = v}
    end
    return v
end
end

-- ЕДИНОЕ правило показа игроков
function M.F.EspAllows(p, forArrows)
    if p == M.LP then return M.State.PlayerViewOnSelf == true end
    -- бот
    if M.Data.NpcPseudo[p] and not M.State[forArrows and "ArrowNpcs" or "EspNpcs"] then return false end
    if M.State.PlayerViewTeamCheck and M.IsTeammate(p) then return false end
    return true
end

-- можно ли считать p целью функции с выключателем «и боты»
function M.F.NpcOk(p, key)
    return not M.Data.NpcPseudo[p] or M.State[key] == true
end

M.Data.FolderNames = {
    wFolder = M.Services.H:GenerateGUID(false),
    pkFolder = M.Services.H:GenerateGUID(false),
    hrFolder = M.Services.H:GenerateGUID(false),
    kFolder = M.Services.H:GenerateGUID(false),
    lFolder = M.Services.H:GenerateGUID(false),
    mFolder = M.Services.H:GenerateGUID(false),
    vFolder = M.Services.H:GenerateGUID(false),
    jFolder = M.Services.H:GenerateGUID(false),
    tFolder = M.Services.H:GenerateGUID(false),
    fFolder = M.Services.H:GenerateGUID(false)
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
    local cam = workspace.CurrentCamera
    if cam then
        table.insert(ignore, cam)
    end
    M.RayParams.FilterDescendantsInstances = ignore
    -- своя копия списка
    M.Data.RayIgnoreBase = ignore
    if M.F.ClearRayCache then M.F.ClearRayCache() end
end

function M.F.HuiFolder()
    local folder = M.UI.HuiFolder
    if folder and folder.Parent then return folder end
    folder = Instance.new("Folder")
    folder.Name = M.Services.H:GenerateGUID(false)
    folder.Parent = M.TargetGui
    M.UI.HuiFolder = folder
    return folder
end

-- возвращает нужную папку, создавая её при первом обращении
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

-- пустые папки уничтожаются, если пустуют дольше 20 секунд: иначе папка эффектов смертей или следов создавалась бы
-- и удалялась каждые несколько секунд, и каждый раз пересобирался бы список исключений для лучей
M.Data.FolderEmptySince = {}
function M.F.ReleaseEmptyFolders()
    local changed = false
    local now = os.clock()
    local since = M.Data.FolderEmptySince
    for key in pairs(M.Data.FolderNames) do
        local folder = M.UI[key]
        if folder and folder.Parent and #folder:GetChildren() == 0 then
            local t0 = since[key]
            if not t0 then
                since[key] = now
            elseif now - t0 >= 20 or M.Run.IsShutDown then
                since[key] = nil
                M.Data.OwnFolderSet[folder] = nil
                folder:Destroy()
                M.UI[key] = nil
                changed = true
            end
        else
            since[key] = nil
        end
    end
    if changed then M.UpdateRaycast() end
end

M.UpdateRaycast()
-- камера сменилась
table.insert(M.Data.Conns, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(M.UpdateRaycast))

function M.SpawnJumpRing(originPos)
    if not M.State.JumpRings or not originPos then return end
    local ray = workspace:Raycast(originPos, Vector3.new(0, -12, 0), M.RayParams)
    local hitPos = ray and ray.Position or (originPos - Vector3.new(0, 3, 0))
    local hitNorm = ray and ray.Normal or Vector3.new(0, 1, 0)

    local ringModel = Instance.new("Model")
    ringModel.Name = M.Services.H:GenerateGUID(false)
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

end}

-- [8/69] Защита от отбрасывания и падений
MODULES[#MODULES + 1] = {"8. Защита от отбрасывания и падений", function(M, __X)
-- игры отбрасывают персонажа «движителями»
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

-- включена ли защита от падений
function M.F.AntiHitOn()
    return M.State.FallProtection
end

-- идёт ли «окно отбрасывания»
function M.F.InHitWindow(hum)
    local now = os.clock()
    if now < M.Data.FlingUntil or now - M.Data.LastDamage < 2.5 then return true end
    local state = hum and hum:GetState()
    return state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.PlatformStanding
end

-- защита от отбрасывания
function M.F.UpdateAntiFling(dt)
    local D = M.Data
    if not M.F.AntiHitOn() or M.Run.IsDead or M.State.FlightMode then
        D.PrevVelocity, D.FixRun = nil, 0
        return
    end
    local char = M.LP and M.LP.Character
    local hrp = M.GetRoot(char)
    local hum = char and M.GetHumanoid(char)
    if not hrp or not hum or hum.SeatPart ~= nil or not (dt > 0) then
        D.PrevVelocity, D.FixRun = nil, 0
        return
    end

    local now = os.clock()
    -- прыжок: состояние Jumping длится доли кадра, поэтому смотрим и на запрос прыжка
    if hum.Jump or hum:GetState() == Enum.HumanoidStateType.Jumping then D.LastJump = now end
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
                ny = prevGrounded and math.min(prev.Y, 0) or (prev.Y - workspace.Gravity * dt)
            end
            hrp.AssemblyLinearVelocity = Vector3.new(nx, ny, nz)
            velocity = hrp.AssemblyLinearVelocity
            fixed = true
        end
    end

    if fixed then
        D.FixRun = D.FixRun + 1
        if D.FixRun >= 4 then
            D.GuardUntil = now + 0.7
            D.FixRun = 0
        end
    else
        D.FixRun = 0
    end

    local flat = Vector3.new(velocity.X, 0, velocity.Z)
    local limitFlat = math.max(140, M.State.SprintSpeed * 2.5)
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

-- встать после рагдола
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

    local h = char:WaitForChild("Humanoid", 4) or M.GetHumanoid(char)
    local r = char:WaitForChild("HumanoidRootPart", 4) or M.GetRoot(char)
    if not h or not r then return end

    M.Data.KnownMovers = setmetatable({}, {__mode = "k"})
    for _, d in ipairs(char:GetDescendants()) do
        if M.F.IsMover(d) then M.Data.KnownMovers[d] = true end
    end

    table.insert(M.Data.CharConns, h.StateChanged:Connect(function(_, newState)
        if h.Health <= 0 then return end
        if newState == Enum.HumanoidStateType.Jumping and M.State.JumpRings then
            M.SpawnJumpRing(r.Position)
        end
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
            if desc:IsA("Constraint") and desc.Name:lower():find("ragdoll") then
                task.defer(function() if desc.Parent then desc.Enabled = false end end)
            end
            if desc:IsA("Motor6D") and not desc.Enabled then desc.Enabled = true end
        end
    end))
end

-- слова названия
function M.F.NameWords(name)
    local spaced = name:gsub("(%l)(%u)", "%1 %2")
    spaced = spaced:gsub("(%u)(%u%l)", "%1 %2")
    local words = {}
    for w in string.lower(spaced):gmatch("%a+") do words[#words + 1] = w end
    return words
end

function M.F.WordSet(list)
    local set = {}
    for _, w in ipairs(list) do set[w] = true end
    return set
end

-- первое слово названия, которое есть в наборе (или nil)
function M.F.HasWord(name, set)
    for _, w in ipairs(M.F.NameWords(name)) do
        if set[w] then return w end
    end
    return nil
end

end}

-- [9/69] Голограмма и скрытие шапок
MODULES[#MODULES + 1] = {"9. Голограмма и скрытие шапок", function(M, __X)
-- ==============================================================================
-- [ ГОЛОГРАММА НА СВОЁМ ПЕРСОНАЖЕ ]
-- ==============================================================================
do
local HOLO = {
    Body = M.F.WordSet({"head", "torso", "arm", "arms", "hand", "hands", "forearm", "leg", "legs", "foot", "feet", "thigh",
        "shin", "calf", "chest", "pelvis", "hip", "hips", "shoulder", "neck", "body", "abdomen", "waist"}),
    Arm = M.F.WordSet({"arm", "arms", "hand", "hands", "forearm", "finger", "fingers", "thumb", "wrist", "palm", "glove",
        "gloves", "sleeve", "sleeves"}),
    -- детали оружия в модели рук
    Gear = M.F.WordSet({"guard", "grip", "gun", "barrel", "mag", "magazine", "stock", "sight", "trigger", "slide", "bolt",
        "rail", "scope", "muzzle", "laser", "flashlight", "weapon", "knife", "blade", "sword"}),
}

-- красит деталь голограммой
local function holoPaint(D, orig, part, color, alpha)
    local fresh = false
    if not orig[part] then
        fresh = true
        orig[part] = {Material = part.Material, Color = part.Color, Transparency = part.Transparency}
        local surface = part:FindFirstChildOfClass("SurfaceAppearance")
        if surface then
            D.HoloSurfaces[surface] = part
            pcall(function() surface.Parent = nil end)
        end
    end
    if part.Material ~= Enum.Material.ForceField then part.Material = Enum.Material.ForceField end
    M.F.SetProp(part, "Color", color)
    M.F.SetProp(part, "Transparency", alpha)
    return fresh
end

local function holoRestore(orig)
    for part, saved in pairs(orig) do
        if part.Parent then
            pcall(function()
                part.Material = saved.Material
                part.Color = saved.Color
                part.Transparency = saved.Transparency
            end)
        end
    end
    table.clear(orig)
end

local function holoVisible(orig, part)
    local saved = orig[part]
    return (saved and saved.Transparency or part.Transparency) < 0.95
end

-- прячет то, что ложится поверх голограммы: у ForceField текстура детали становится узором, а одежда и наклейки
-- закрывают его - тогда вместо голограммы видна просто перекрашенная кожа
local function holoHide(store, d)
    if store[d] ~= nil then return end
    local prop, value
    if d:IsA("Decal") then prop, value = "Transparency", 1
    elseif d:IsA("Shirt") then prop, value = "ShirtTemplate", ""
    elseif d:IsA("Pants") then prop, value = "PantsTemplate", ""
    elseif d:IsA("ShirtGraphic") then prop, value = "Graphic", ""
    elseif d:IsA("SpecialMesh") then prop, value = "TextureId", ""
    elseif d:IsA("MeshPart") then prop, value = "TextureID", ""
    else return end
    local ok, old = pcall(function() return d[prop] end)
    if not ok or old == value then return end
    store[d] = {prop, old}
    pcall(function() d[prop] = value end)
end

-- вся модель: тело, аксессуары (шапки, волосы) и любые свои детали игры; предмет в руках и невидимые детали не трогаем
local function holoCollectBody(D, char)
    local list = {}
    local root = M.GetRoot(char)
    D.HoloHidden = D.HoloHidden or {}
    for _, d in ipairs(char:GetDescendants()) do
        if not d:FindFirstAncestorOfClass("Tool") then
            if d:IsA("BasePart") then
                if d ~= root and holoVisible(D.VisualOrig, d) then
                    list[#list + 1] = d
                    holoHide(D.HoloHidden, d)
                end
            else
                holoHide(D.HoloHidden, d)
            end
        end
    end
    return list
end

-- вернуть спрятанное на время голограммы
local function holoUnhide(store)
    for inst, saved in pairs(store or {}) do
        if inst.Parent then pcall(function() inst[saved[1]] = saved[2] end) end
    end
    if store then table.clear(store) end
end

-- детали рук в моделях камеры
local function holoScanViewmodel(D, container, inArm, list)
    for _, obj in ipairs(container:GetChildren()) do
        if not (obj:IsA("Tool") or obj:IsA("Accessory")) then
            local arm, gear = false, false
            for _, w in ipairs(M.F.NameWords(obj.Name)) do
                if HOLO.Arm[w] then arm = true elseif HOLO.Gear[w] then gear = true end
            end
            if not gear then
                arm = arm or inArm
                if arm and obj:IsA("BasePart") and holoVisible(D.HoloCamOrig, obj) then
                    list[#list + 1] = obj
                    -- у рук от первого лица прячется то же, что у тела: текстура, наклейки и текстура меша внутри
                    holoHide(D.HoloCamHidden, obj)
                    for _, sub in ipairs(obj:GetChildren()) do holoHide(D.HoloCamHidden, sub) end
                end
                holoScanViewmodel(D, obj, arm, list)
            end
        end
    end
end

-- модели рук от первого лица: в камере или в мире под именами вроде ViewModel, Arms, FP
HOLO.View = M.F.WordSet({"view", "viewmodel", "viewmodels", "vm", "fp", "firstperson", "arms", "hands", "fps"})
local function holoCollectViewmodel(D, cam)
    local list = {}
    local seen = {}
    local function scan(child)
        if seen[child] then return end
        seen[child] = true
        if (child:IsA("Model") or child:IsA("Folder")) and child ~= (M.LP and M.LP.Character) then
            -- имя самой модели
            -- оружие в модели рук не красим: голограммой становятся только детали с именами рук и кистей
            local armish = M.F.HasWord(child.Name, HOLO.Arm) ~= nil
            local before = #list
            holoScanViewmodel(D, child, armish, list)
            -- одежда модели рук (рукава) ложится на руки поверх голограммы
            if #list > before then
                for _, c in ipairs(child:GetChildren()) do
                    if c:IsA("Clothing") or c:IsA("ShirtGraphic") then holoHide(D.HoloCamHidden, c) end
                end
            end
        end
    end
    for _, child in ipairs(cam:GetChildren()) do scan(child) end
    -- раз в 2 секунды смотрим и мир: многие игры кладут руки не в камеру
    local now = os.clock()
    if now - (D.HoloWorldAt or -10) >= 2 then
        D.HoloWorldAt = now
        local found = {}
        for _, child in ipairs(workspace:GetChildren()) do
            if (child:IsA("Model") or child:IsA("Folder")) and M.F.HasWord(child.Name, HOLO.View) then found[#found + 1] = child end
        end
        D.HoloWorldVm = found
    end
    for _, child in ipairs(D.HoloWorldVm or {}) do
        if child.Parent then scan(child) end
    end
    return list
end

function M.F.ApplyHolo(char)
    local D = M.Data
    if M.State.HoloSelf then
        D.HoloApplied, D.HoloActive = true, true
        D.HoloCamOrig = D.HoloCamOrig or setmetatable({}, {__mode = "k"})
        D.HoloCamHidden = D.HoloCamHidden or setmetatable({}, {__mode = "k"})
        D.HoloSurfaces = D.HoloSurfaces or {}
        local hum = M.GetHumanoid(char)
        if hum and hum.Health <= 0 then return end

        if D.HoloChar ~= char then
            if D.HoloConn then D.HoloConn:Disconnect() end
            D.HoloChar, D.HoloParts = char, nil
            for surface, part in pairs(D.HoloSurfaces) do
                if not part.Parent then D.HoloSurfaces[surface] = nil end
            end
            for inst in pairs(D.HoloHidden or {}) do
                if not inst:IsDescendantOf(char) then D.HoloHidden[inst] = nil end
            end
            D.HoloConn = char.DescendantAdded:Connect(function(d)
                if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("SpecialMesh") then
                    D.HoloParts = nil
                end
            end)
        end
        if not D.HoloParts then D.HoloParts = holoCollectBody(D, char) end

        local glow = math.clamp(tonumber(M.State.HoloGlow) or 0, 0, 5)
        -- яркость
        local color = M.State.HoloColor:Lerp(Color3.new(1, 1, 1), math.clamp(glow / 10, 0, 0.5))
        local alpha = M.State.HoloAlpha
        local parts = D.HoloParts
        local n = #parts
        local idx, units = D.HoloIdx or 1, 0
        for _ = 1, n do
            if units >= 40 then break end
            if idx > n then idx = 1 end
            local part = parts[idx]
            idx = idx + 1
            if part.Parent then
                units = units + (holoPaint(D, D.VisualOrig, part, color, alpha) and 8 or 1)
            end
        end
        D.HoloIdx = idx

        -- руки от первого лица в камере
        local cam = workspace.CurrentCamera
        if D.HoloCam ~= cam then
            for _, conn in ipairs(D.HoloCamConns or {}) do conn:Disconnect() end
            D.HoloCamConns, D.HoloCam, D.HoloCamDirty = {}, cam, true
            if cam then
                local function dirty() D.HoloCamDirty = true end
                D.HoloCamConns[1] = cam.ChildAdded:Connect(dirty)
                D.HoloCamConns[2] = cam.ChildRemoved:Connect(dirty)
                D.HoloCamConns[3] = cam.DescendantAdded:Connect(function(d)
                    if d:IsA("BasePart") then D.HoloCamDirty = true end
                end)
            end
        end
        local now = os.clock()
        if cam and (D.HoloCamDirty or now - (D.HoloCamAt or 0) >= 2) and now - (D.HoloCamAt or 0) >= 0.25 then
            D.HoloCamDirty, D.HoloCamAt = false, now
            D.HoloCamParts = holoCollectViewmodel(D, cam)
        end
        for _, part in ipairs(D.HoloCamParts or {}) do
            if part.Parent then holoPaint(D, D.HoloCamOrig, part, color, alpha) end
        end

        local root = M.GetRoot(char)
        local light = D.HoloLight
        if glow > 0 and root then
            if not light or not light.Parent or light.Parent ~= root then
                if light then light:Destroy() end
                light = M.F.MarkOwned(Instance.new("PointLight"))
                light.Name = M.Services.H:GenerateGUID(false)
                light.Shadows = false
                light.Parent = root
                D.HoloLight = light
            end
            M.F.SetProp(light, "Color", M.State.HoloColor)
            M.F.SetProp(light, "Brightness", glow * 1.5)
            M.F.SetProp(light, "Range", 8 + glow * 4)
        elseif light then
            light:Destroy()
            D.HoloLight = nil
        end
    elseif D.HoloApplied or D.HoloActive then
        D.HoloApplied, D.HoloActive = false, false
        if D.HoloLight then D.HoloLight:Destroy(); D.HoloLight = nil end
        if D.HoloConn then D.HoloConn:Disconnect(); D.HoloConn = nil end
        for _, conn in ipairs(D.HoloCamConns or {}) do conn:Disconnect() end
        D.HoloCamConns, D.HoloCam, D.HoloCamParts = nil, nil, nil
        D.HoloChar, D.HoloParts = nil, nil
        holoRestore(D.VisualOrig)
        holoUnhide(D.HoloHidden)
        holoUnhide(D.HoloCamHidden)
        if D.HoloCamOrig then holoRestore(D.HoloCamOrig) end
        for surface, part in pairs(D.HoloSurfaces or {}) do
            if part.Parent then pcall(function() surface.Parent = part end) end
        end
        if D.HoloSurfaces then table.clear(D.HoloSurfaces) end
    end
end
end

function M.F.ApplyHats()
    local function setAll(value)
        for _, plr in ipairs(M.F.Players()) do
            local ch = plr.Character
            if ch then
                for _, item in ipairs(ch:GetChildren()) do
                    if item:IsA("Accessory") then
                        local handle = item:FindFirstChild("Handle")
                        if handle and handle:IsA("BasePart") and handle.LocalTransparencyModifier ~= value then
                            handle.LocalTransparencyModifier = value
                        end
                    end
                end
            end
        end
    end

    if M.State.HideHats then
        -- обход всех игроков дорогой
        local now = os.clock()
        if M.Data.HatsHidden and now - (M.Data.HatsSweep or 0) < 0.5 then return end
        M.Data.HatsSweep = now
        M.Data.HatsHidden = true
        setAll(1)
    elseif M.Data.HatsHidden then
        M.Data.HatsHidden = false
        setAll(0)
    end
end

function M.UpdatePlayerVisuals()
    local char = M.LP and M.LP.Character
    if char and char.Parent then
        M.F.ApplyHolo(char)
    end
    M.F.ApplyHats()
end

end}

-- [10/69] Отсечение по виду и оптимизация графики (уровни, настройки движка)
MODULES[#MODULES + 1] = {"10. Отсечение по виду и оптимизация графики (уровни, настройки движка)", function(M, __X)
-- ==============================================================================
-- [ ОТСЕЧЕНИЕ ПО ВИДУ ]
-- ==============================================================================
do
local CULL_CELL = 64
local CULL_HALF_DIAG = CULL_CELL * 0.8661
local CULL_MAX_PART = 160

-- доля кадра на фоновую работу: при 400 кадрах в секунду кадр короче, значит и работы за кадр меньше
function M.F.FrameBudget(maxSec)
    local fps = math.max(tonumber(M.Run.CurFPS) or 60, 30)
    return math.min(maxSec, 0.12 / fps)
end

local function newCullState()
    return {
        Active = false, Cells = {}, List = {}, All = {},
        PartCell = setmetatable({}, {__mode = "k"}), Extras = setmetatable({}, {__mode = "k"}),
        Hidden = setmetatable({}, {__mode = "k"}), Rad = setmetatable({}, {__mode = "k"}),
        Queue = {Items = {}, Head = 1, Tail = 0}, Added = {}, AddedN = 0,
        Clock = 1, Cursor = 1, CamPos = nil, MaxDist = 800, Conns = {}, Token = 0
    }
end
local cull = newCullState()

local function cullCellFor(pos)
    local ix, iy, iz = math.floor(pos.X / CULL_CELL), math.floor(pos.Y / CULL_CELL), math.floor(pos.Z / CULL_CELL)
    local key = ((ix + 1024) * 2048 + (iy + 1024)) * 2048 + (iz + 1024)
    local cell = cull.Cells[key]
    if not cell then
        -- Mode: 0 - всё видно, 1 - всё скрыто, 2 - на границе дальности, решается по каждой детали
        cell = {List = {}, N = 0, Dead = 0, X = (ix + 0.5) * CULL_CELL, Y = (iy + 0.5) * CULL_CELL, Z = (iz + 0.5) * CULL_CELL,
            MaxR = 0, R = CULL_HALF_DIAG, Mode = 0, Prog = 1, Pending = false, EvalPos = nil}
        cull.Cells[key] = cell
        cull.List[#cull.List + 1] = cell
    end
    return cell
end

local function cullSetPart(part, hidden)
    if (cull.Hidden[part] or false) == hidden then return end
    cull.Hidden[part] = hidden or nil
    local v = hidden and 1 or 0
    part.LocalTransparencyModifier = v
    local extras = cull.Extras[part]
    if extras then
        for _, d in ipairs(extras) do
            if d.Parent then d.LocalTransparencyModifier = v end
        end
    end
end

-- нужна ли детали невидимость: край детали дальше заданной дальности (с запасом 3%, чтобы у границы не мигало)
local function cullPartWant(part)
    local cp = cull.CamPos
    if not cp then return false end
    local d = (part.Position - cp).Magnitude - (cull.Rad[part] or 0)
    local maxDist = cull.MaxDist
    if cull.Hidden[part] then return d > maxDist * 0.97 end
    return d > maxDist
end

local function cullApply(part, cell)
    local mode = cell.Mode
    if mode == 1 then
        cullSetPart(part, true)
    elseif mode == 2 then
        cullSetPart(part, cullPartWant(part))
    else
        cullSetPart(part, false)
    end
end

-- кладёт деталь в ячейку по её положению
local function cullPlace(part, pos, radius)
    if math.abs(pos.X) > 100000 or math.abs(pos.Y) > 100000 or math.abs(pos.Z) > 100000 then
        cull.PartCell[part] = false
        return
    end
    local cell = cullCellFor(pos)
    if radius > cell.MaxR then
        cell.MaxR = radius
        cell.R = CULL_HALF_DIAG + radius
    end
    cell.N = cell.N + 1
    cell.List[cell.N] = part
    cull.PartCell[part] = cell
    cull.Rad[part] = radius
    cullApply(part, cell)
end

function M.F.CullAdd(part)
    if not cull.Active or cull.PartCell[part] ~= nil then return end
    cull.PartCell[part] = false
    -- осадки, следы и прочие объекты скрипта не прячем
    if not part.Anchored or part.Transparency >= 1 or M.IsOwned(part) then return end
    -- части персонажей
    local ancestor, depth = part.Parent, 0
    while ancestor and ancestor ~= workspace and depth < 8 do
        if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then return end
        ancestor = ancestor.Parent
        depth = depth + 1
    end
    local radius = part.Size.Magnitude / 2
    if radius > CULL_MAX_PART then return end
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("Decal") then
            local extras = cull.Extras[part]
            if not extras then extras = {}; cull.Extras[part] = extras end
            extras[#extras + 1] = child
        end
    end
    cullPlace(part, part.Position, radius)
    if cull.PartCell[part] then cull.All[#cull.All + 1] = part end
end

local function cullCompact(cell)
    local list, count = {}, 0
    for _, part in ipairs(cell.List) do
        if part.Parent and cull.PartCell[part] == cell then
            count = count + 1
            list[count] = part
        end
    end
    cell.List, cell.N, cell.Dead = list, count, 0
end

local function cullEnqueue(cell, mode)
    cell.Mode = mode
    cell.Prog = 1
    cell.EvalPos = cull.CamPos
    if cell.Pending then return end
    cell.Pending = true
    local q = cull.Queue
    q.Tail = q.Tail + 1
    q.Items[q.Tail] = cell
end

-- только дальность: что вне экрана, Roblox и так не рисует, а переключать детали при каждом повороте камеры дорого
local function cullEvaluate(cam)
    local cp = cam.CFrame.Position
    local maxDist = math.max(M.State.FpsCullDist or 800, 50)
    local distChanged = maxDist ~= cull.MaxDist
    cull.CamPos, cull.MaxDist = cp, maxDist
    local cx, cy, cz = cp.X, cp.Y, cp.Z
    local cells = cull.List
    for i = 1, #cells do
        local cell = cells[i]
        if cell.N > 0 then
            local dx, dy, dz = cell.X - cx, cell.Y - cy, cell.Z - cz
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            local mode
            if d - cell.R > maxDist * 1.02 then
                mode = 1
            elseif d + cell.R < maxDist * 0.95 then
                mode = 0
            else
                mode = 2
            end
            if mode ~= cell.Mode then
                cullEnqueue(cell, mode)
            elseif mode == 2 and (distChanged or not cell.EvalPos or (cell.EvalPos - cp).Magnitude > 4) then
                -- ячейка на границе: при движении камеры детали в ней пересматриваются по одной
                cullEnqueue(cell, mode)
            end
        end
    end
end

-- применяет состояние ячеек к деталям порциями, не дольше бюджета кадра
local function cullDrain(deadline)
    local q = cull.Queue
    local checks = 0
    while q.Head <= q.Tail do
        local cell = q.Items[q.Head]
        local list, count, i = cell.List, cell.N, cell.Prog
        while i <= count do
            local part = list[i]
            if cull.PartCell[part] == cell and part.Parent then cullApply(part, cell) end
            i = i + 1
            checks = checks + 1
            if checks % 32 == 0 and os.clock() > deadline then
                cell.Prog = i
                return
            end
        end
        cell.Pending = false
        q.Items[q.Head] = nil
        q.Head = q.Head + 1
        if cell.Dead > 8 then cullCompact(cell) end
    end
    q.Head, q.Tail = 1, 0
end

-- сверка положения
local function cullDrift()
    local all = cull.All
    local count = #all
    for _ = 1, 150 do
        if count == 0 then return end
        if cull.Cursor > count then cull.Cursor = 1 end
        local part = all[cull.Cursor]
        local cell = cull.PartCell[part]
        local gone = not part.Parent
        local loose = not gone and not part.Anchored
        if gone or loose or not cell then
            if cell then cell.Dead = cell.Dead + 1 end
            if loose then pcall(cullSetPart, part, false) end
            cull.PartCell[part] = nil
            cull.Extras[part] = nil
            all[cull.Cursor] = all[count]
            all[count] = nil
            count = count - 1
        else
            local pos = part.Position
            local limit = CULL_CELL * 0.5 + 2
            if math.abs(pos.X - cell.X) > limit or math.abs(pos.Y - cell.Y) > limit or math.abs(pos.Z - cell.Z) > limit then
                cell.Dead = cell.Dead + 1
                cullPlace(part, pos, part.Size.Magnitude / 2)
                if not cull.PartCell[part] then
                    all[cull.Cursor] = all[count]
                    all[count] = nil
                    count = count - 1
                    cull.Cursor = cull.Cursor - 1
                end
            end
            cull.Cursor = cull.Cursor + 1
        end
    end
end

local function cullStep(dt)
    if M.Run.IsShutDown or not cull.Active then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local deadline = os.clock() + M.F.FrameBudget(0.0006)
    -- новые детали карты
    local added = cull.Added
    while cull.AddedN > 0 do
        local part = added[cull.AddedN]
        added[cull.AddedN] = nil
        cull.AddedN = cull.AddedN - 1
        if part.Parent then pcall(M.F.CullAdd, part) end
        if cull.AddedN % 16 == 0 and os.clock() > deadline then break end
    end
    -- дальность меняется только при перемещении: проверки 4 раза в секунду хватает
    cull.Clock = cull.Clock + dt
    if cull.Clock >= 0.25 then
        cull.Clock = 0
        cullEvaluate(cam)
    end
    cullDrain(deadline)
    cull.DriftAt = (cull.DriftAt or 0) + dt
    if cull.DriftAt >= 0.1 then
        cull.DriftAt = 0
        cullDrift()
    end
end

function M.F.CullStart()
    if cull.Active then return end
    cull = newCullState()
    cull.Active = true
    local state = cull
    pcall(function() M.Services.R:UnbindFromRenderStep("MatsysenseCull") end)
    M.Services.R:BindToRenderStep("MatsysenseCull", Enum.RenderPriority.Last.Value + 2, function(dt)
        pcall(cullStep, dt)
    end)
    -- новые детали собираются в очередь с потолком и разбираются в кадре по бюджету
    state.Conns[1] = workspace.DescendantAdded:Connect(function(obj)
        if state.AddedN < 30000 and obj:IsA("BasePart") then
            state.AddedN = state.AddedN + 1
            state.Added[state.AddedN] = obj
        end
    end)
    -- карта обходится по кусочкам
    task.spawn(function()
        M.F.SliceWalk(workspace, function(obj)
            if obj:IsA("BasePart") then M.F.CullAdd(obj) end
        end, function() return cull == state and state.Active end,
            function(obj) return M.Data.OwnFolderSet[obj] or obj:IsA("Terrain") or obj:IsA("Camera") end, 0.0006)
    end)
end

-- выключение: всё скрытое снова видно
function M.F.CullStop()
    if not cull.Active then return end
    local old = cull
    old.Active = false
    cull = newCullState()
    for _, conn in ipairs(old.Conns) do conn:Disconnect() end
    pcall(function() M.Services.R:UnbindFromRenderStep("MatsysenseCull") end)
    local list = {}
    for part in pairs(old.Hidden) do list[#list + 1] = part end
    task.spawn(function()
        for i, part in ipairs(list) do
            if part.Parent then
                pcall(function()
                    part.LocalTransparencyModifier = 0
                    local extras = old.Extras[part]
                    if extras then
                        for _, d in ipairs(extras) do
                            if d.Parent then d.LocalTransparencyModifier = 0 end
                        end
                    end
                end)
            end
            if i % 2500 == 0 then task.wait() end
        end
    end)
end

-- дальность прорисовки работает сама по себе или вместе с упрощённой графикой
function M.F.CullRefresh()
    local want = not M.Run.IsShutDown and (M.State.CullOn or M.F.OptLevel() >= 2)
    if want then M.F.CullStart() else M.F.CullStop() end
end

end

-- оптимизация графики: уровень 1 - лёгкая (включена при запуске), уровень 2 - полная («Упрощённая графика»)
function M.F.OptLevel()
    if M.Run.IsShutDown then return 0 end
    if M.State.FpsBoost then return 2 end
    return M.State.OptLight and 1 or 0
end

-- применяет уровень сразу; повторный вызов с тем же уровнем ничего не делает
function M.F.RefreshOptimization()
    M.F.ApplyOptimization(M.F.OptLevel())
end

-- совместимость с тумблером «Упрощённая графика»
function M.ApplyFpsBoost(enabled)
    M.State.FpsBoost = enabled and true or false
    M.F.RefreshOptimization()
end

-- запись свойства без обрыва: игра может запретить любое из них
function M.F.OptPut(obj, prop, value)
    return (pcall(function() obj[prop] = value end))
end

function M.F.OptRestore()
    local D, L = M.Data, M.Services.L
    local put = M.F.OptPut
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    pcall(M.F.CullStop)
    pcall(function()
        if D.BoostFlags ~= nil then
            D.BoostFlags = nil
            M.Cap.Call("setfflag", "DFFlagTextureQualityOverrideEnabled", "False")
        end
    end)
    for obj, saved in pairs(D.OriginalMaterials) do
        if obj.Parent then
            put(obj, "Material", saved.Material)
            put(obj, "CastShadow", saved.CastShadow)
            put(obj, "Reflectance", saved.Reflectance)
        end
    end
    for obj, trans in pairs(D.TextureCache) do
        if obj.Parent then put(obj, "Transparency", trans) end
    end
    for obj, saved in pairs(D.TexCache) do
        if obj.Parent then
            pcall(function()
                if saved.TileU ~= nil then
                    obj.StudsPerTileU, obj.StudsPerTileV = saved.TileU, saved.TileV
                elseif obj:IsA("MeshPart") then
                    obj.TextureID = saved.Texture
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
    for obj, wasEnabled in pairs(D.EmitterCache) do
        if obj.Parent then put(obj, "Enabled", wasEnabled) end
    end
    for obj, wasEnabled in pairs(D.EffectCache) do
        if obj.Parent then put(obj, "Enabled", wasEnabled) end
    end
    for obj, saved in pairs(D.BoostExtra or {}) do
        if obj.Parent then put(obj, saved.Prop, saved.Value) end
    end
    if D.BoostExtra then table.clear(D.BoostExtra) end
    if D.BoostTech ~= nil then
        local tech = D.BoostTech
        D.BoostTech = nil
        M.Cap.Call("sethiddenproperty", L, "Technology", tech)
    end
    table.clear(D.OriginalMaterials)
    table.clear(D.TextureCache)
    table.clear(D.TexCache)
    table.clear(D.EmitterCache)
    table.clear(D.EffectCache)

    local savedLighting = D.BoostLighting
    if savedLighting then
        D.BoostLighting = nil
        for prop, value in pairs(savedLighting) do put(L, prop, value) end
    end
    local savedTerrain = D.BoostTerrain
    if savedTerrain then
        D.BoostTerrain = nil
        if terrain then
            for prop, value in pairs(savedTerrain) do put(terrain, prop, value) end
        end
    end
    if D.BoostQuality ~= nil then
        local quality, meshDetail = D.BoostQuality, D.BoostMeshDetail
        D.BoostQuality, D.BoostMeshDetail = nil, nil
        pcall(function() settings().Rendering.QualityLevel = quality end)
        if meshDetail ~= nil then pcall(function() settings().Rendering.MeshPartDetailLevel = meshDetail end) end
    end
    if D.BoostSavedQuality ~= nil then
        local value = D.BoostSavedQuality
        D.BoostSavedQuality = nil
        pcall(function() UserSettings():GetService("UserGameSettings").SavedQualityLevel = value end)
    end
    if D.BoostMaterial2022 ~= nil then
        local value = D.BoostMaterial2022
        D.BoostMaterial2022 = nil
        pcall(function() game:GetService("MaterialService").Use2022Materials = value end)
    end
end

end}

-- [11/69] Оптимизация графики: объекты карты; снятие лимита кадров
MODULES[#MODULES + 1] = {"11. Оптимизация графики: объекты карты; снятие лимита кадров", function(M, __X)
M.F.OptLightClasses = {MeshPart = true, UnionOperation = true, IntersectOperation = true, NegateOperation = true,
    PointLight = true, SpotLight = true, SurfaceLight = true}

-- одного объекта карты касается только то, что нужно уровню
function M.F.OptObject(obj, level)
    local D = M.Data
    if D.OwnLoose[obj] then return end
    -- лёгкому уровню нужны единицы классов: остальное отсеиваем сразу, без лишней работы
    if level == 1 and not M.F.OptLightClasses[obj.ClassName] then return end
    local put = M.F.OptPut
    local extra = D.BoostExtra
    local function stash(prop, value)
        -- свойство, которое игра не даёт менять, больше не пробуем: ошибка в pcall дорогая
        if D.OptDenied and D.OptDenied[prop] then return end
        local ok = pcall(function()
            if extra[obj] == nil then extra[obj] = {Prop = prop, Value = obj[prop]} end
            obj[prop] = value
        end)
        if not ok then
            if extra[obj] and extra[obj].Prop == prop then extra[obj] = nil end
            D.OptDeniedN = D.OptDeniedN or {}
            D.OptDeniedN[prop] = (D.OptDeniedN[prop] or 0) + 1
            if D.OptDeniedN[prop] >= 3 then
                D.OptDenied = D.OptDenied or {}
                D.OptDenied[prop] = true
            end
        end
    end
    -- то же для остальных записей: при отказах игры перестаём пробовать
    local function try(key, fn)
        if D.OptDenied and D.OptDenied[key] then return end
        if pcall(fn) then return end
        D.OptDeniedN = D.OptDeniedN or {}
        D.OptDeniedN[key] = (D.OptDeniedN[key] or 0) + 1
        if D.OptDeniedN[key] >= 3 then
            D.OptDenied = D.OptDenied or {}
            D.OptDenied[key] = true
        end
    end
    local class = obj.ClassName
    if level == 1 then
        -- лёгкий уровень: детализация мешей и тени ламп; материалы и текстуры остаются
        if class == "MeshPart" or class == "UnionOperation" or class == "IntersectOperation" or class == "NegateOperation" then
            stash("RenderFidelity", Enum.RenderFidelity.Performance)
        elseif class == "PointLight" or class == "SpotLight" or class == "SurfaceLight" then
            stash("Shadows", false)
        end
        return
    end
    if class == "Terrain" then return end
    -- свой персонаж не трогаем: на нём голограмма, скрытие шапок и вид от первого лица
    local own = M.LP and M.LP.Character
    if own and obj:IsDescendantOf(own) then return end
    if obj:IsA("PartOperation") then
        stash("RenderFidelity", Enum.RenderFidelity.Performance)
    end
    if obj:IsA("BasePart") then
        if D.OriginalMaterials[obj] == nil then
            D.OriginalMaterials[obj] = {Material = obj.Material, CastShadow = obj.CastShadow, Reflectance = obj.Reflectance}
        end
        -- силовое поле - это прозрачный эффект: пластиком оно стало бы сплошной глыбой
        if obj.Material ~= Enum.Material.ForceField then put(obj, "Material", Enum.Material.SmoothPlastic) end
        if obj.CastShadow then put(obj, "CastShadow", false) end
        if obj.Reflectance ~= 0 then put(obj, "Reflectance", 0) end
        if class == "MeshPart" then
            try("TextureID", function()
                if D.TexCache[obj] == nil then D.TexCache[obj] = {Texture = obj.TextureID} end
                obj.TextureID = ""
            end)
            stash("RenderFidelity", Enum.RenderFidelity.Performance)
        end
        M.F.CullAdd(obj)
    elseif class == "SpecialMesh" then
        try("TextureId", function()
            if D.TexCache[obj] == nil then D.TexCache[obj] = {Texture = obj.TextureId} end
            obj.TextureId = ""
        end)
    elseif class == "Shirt" or class == "Pants" or class == "ShirtGraphic" then
        try("Cloth", function()
            if D.TexCache[obj] == nil then
                local original = class == "Shirt" and obj.ShirtTemplate or (class == "Pants" and obj.PantsTemplate or obj.Graphic)
                D.TexCache[obj] = {Cloth = original}
            end
            if class == "Shirt" then obj.ShirtTemplate = ""
            elseif class == "Pants" then obj.PantsTemplate = ""
            else obj.Graphic = "" end
        end)
    elseif class == "SurfaceAppearance" then
        try("SurfaceAppearance", function()
            if D.TexCache[obj] == nil then
                D.TexCache[obj] = {Color = obj.ColorMap, Normal = obj.NormalMap, Metal = obj.MetalnessMap, Rough = obj.RoughnessMap}
            end
            obj.ColorMap, obj.NormalMap, obj.MetalnessMap, obj.RoughnessMap = "", "", "", ""
        end)
    elseif class == "Decal" or class == "Texture" then
        if D.TextureCache[obj] == nil then D.TextureCache[obj] = obj.Transparency end
        put(obj, "Transparency", 1)
    elseif class == "Explosion" or class == "ForceField" then
        stash("Visible", false)
    elseif class == "Highlight" or class == "ParticleEmitter" or class == "Trail" or class == "Smoke" or class == "Fire"
        or class == "Sparkles" or class == "Beam" or class == "PointLight" or class == "SpotLight" or class == "SurfaceLight" then
        if D.EmitterCache[obj] == nil then D.EmitterCache[obj] = obj.Enabled end
        put(obj, "Enabled", false)
    end
end

-- пост-эффекты Lighting: на лёгком уровне только дорогие, на полном все
function M.F.OptLightingObject(obj, level)
    local D = M.Data
    if obj == D.FxGrade or obj == D.FxRayBloom or obj == D.FxSunRays or obj == D.FxGlassBlur
        or obj == D.FxConfirmBlur or obj == D.FxIntroBlur or M.IsOwned(obj) then return end
    if not obj:IsA("PostEffect") then return end
    if level == 1 then
        local class = obj.ClassName
        if class ~= "BloomEffect" and class ~= "DepthOfFieldEffect" and class ~= "SunRaysEffect" then return end
    end
    if D.EffectCache[obj] == nil then D.EffectCache[obj] = obj.Enabled end
    M.F.OptPut(obj, "Enabled", false)
end

-- настройки движка, общие для обоих уровней
function M.F.OptEngine(level)
    local D, L = M.Data, M.Services.L
    local put = M.F.OptPut
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if not D.BoostLighting then
        local saved = {}
        for _, prop in ipairs({"GlobalShadows", "EnvironmentSpecularScale", "ShadowSoftness", "EnvironmentDiffuseScale"}) do
            pcall(function() saved[prop] = L[prop] end)
        end
        D.BoostLighting = saved
    end
    put(L, "GlobalShadows", false)
    put(L, "EnvironmentSpecularScale", 0)
    put(L, "ShadowSoftness", 0)
    if level >= 2 then put(L, "EnvironmentDiffuseScale", 0) end
    for _, child in ipairs(L:GetChildren()) do pcall(M.F.OptLightingObject, child, level) end

    if terrain then
        if not D.BoostTerrain then
            local saved = {}
            for _, prop in ipairs({"Decoration", "WaterReflectance", "WaterWaveSize", "WaterWaveSpeed"}) do
                pcall(function() saved[prop] = terrain[prop] end)
            end
            D.BoostTerrain = saved
        end
        put(terrain, "Decoration", false)
        put(terrain, "WaterReflectance", 0)
        if level >= 2 then
            put(terrain, "WaterWaveSize", 0)
            put(terrain, "WaterWaveSpeed", 0)
            for _, child in ipairs(terrain:GetChildren()) do
                if child:IsA("Clouds") and child ~= D.FxClouds then
                    if D.EffectCache[child] == nil then D.EffectCache[child] = child.Enabled end
                    put(child, "Enabled", false)
                end
            end
        end
    end

    -- качество графики и материалы меняет только полный уровень: на лёгком они сокращали дальность прорисовки самой игры
    if level >= 2 then
        pcall(function()
            local rendering = settings().Rendering
            if D.BoostQuality == nil then D.BoostQuality = rendering.QualityLevel end
            rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        pcall(function()
            local rendering = settings().Rendering
            if D.BoostMeshDetail == nil then D.BoostMeshDetail = rendering.MeshPartDetailLevel end
            -- уровни идут от простого к подробному: Level01 - самая лёгкая детализация мешей
            rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        end)
        -- ползунок графики из меню Roblox: у исполнителей без доступа к settings() работает только он
        pcall(function()
            local gs = UserSettings():GetService("UserGameSettings")
            if D.BoostSavedQuality == nil then D.BoostSavedQuality = gs.SavedQualityLevel end
            gs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        end)
    end
    if level >= 2 then
        pcall(function()
            local materials = game:GetService("MaterialService")
            if D.BoostMaterial2022 == nil then D.BoostMaterial2022 = materials.Use2022Materials end
            materials.Use2022Materials = false
        end)
        pcall(function()
            local setFlag = M.Cap.Fn("setfflag")
            if D.BoostFlags == nil and setFlag then
                D.BoostFlags = true
                setFlag("DFFlagTextureQualityOverrideEnabled", "True")
                setFlag("DFIntTextureQualityOverride", "0")
            end
        end)
        -- самая простая система освещения
        pcall(function()
            local getHidden, setHidden = M.Cap.Fn("gethiddenproperty"), M.Cap.Fn("sethiddenproperty")
            if D.BoostTech == nil and getHidden and setHidden then
                D.BoostTech = getHidden(L, "Technology")
                setHidden(L, "Technology", Enum.Technology.Compatibility)
            end
        end)
    end
end

function M.F.ApplyOptimization(level)
    local ok, err = pcall(M.F.ApplyOptLevel, level)
    if not ok then M.Errors.Hit("Optimization", err) end
    pcall(M.F.CullRefresh)
end

function M.F.ApplyOptLevel(level)
    local D, L = M.Data, M.Services.L
    local current = D.OptLevel or 0
    if level == current then return end
    D.FpsBoostToken = D.FpsBoostToken + 1
    local token = D.FpsBoostToken
    for _, conn in ipairs(D.FpsBoostConns) do pcall(function() conn:Disconnect() end) end
    D.FpsBoostConns = {}

    if not D.BoostExtra then D.BoostExtra = setmetatable({}, {__mode = "k"}) end
    -- с полного уровня на лёгкий: сначала вернуть всё, потом применить лёгкий
    if level < current then
        local okR, errR = pcall(M.F.OptRestore)
        if not okR then M.Errors.Hit("OptRestore", errR) end
    end
    D.OptLevel = level
    if level == 0 then return end

    -- сбой одной части не должен оставлять уровень наполовину включённым
    local ok, err = pcall(M.F.OptEngine, level)
    if not ok then M.Errors.Hit("OptEngine", err) end

    -- новые объекты карты: очередь с потолком, чтобы подгрузка большой карты не съела память
    local queue, head, tail = {}, 1, 0
    table.insert(D.FpsBoostConns, workspace.DescendantAdded:Connect(function(obj)
        if tail - head > 40000 then return end
        if level == 1 and not M.F.OptLightClasses[obj.ClassName] then return end
        tail = tail + 1
        queue[tail] = obj
    end))
    table.insert(D.FpsBoostConns, M.Services.R.Heartbeat:Connect(function()
        if head > tail then return end
        local budget = 120
        local deadline = os.clock() + M.F.FrameBudget(0.0006)
        while head <= tail and budget > 0 do
            local obj = queue[head]
            queue[head] = nil
            head = head + 1
            budget = budget - 1
            if obj.Parent and not M.IsOwned(obj) then pcall(M.F.OptObject, obj, level) end
            if budget % 4 == 0 and os.clock() > deadline then break end
        end
        if head > tail then head, tail = 1, 0 end
    end))
    table.insert(D.FpsBoostConns, L.ChildAdded:Connect(function(obj) pcall(M.F.OptLightingObject, obj, level) end))

    -- обход карты по кусочкам: на старте он не должен быть заметен по кадрам
    task.spawn(function()
        M.F.SliceWalk(workspace, function(obj)
            if not M.IsOwned(obj) then M.F.OptObject(obj, level) end
        end, function() return token == D.FpsBoostToken end,
            function(obj) return D.OwnFolderSet[obj] end, 0.0006)
    end)
end

-- снятие лимита кадров
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
    if not ok then
        local capFn = M.Cap.Fn("setfpscap") or M.Cap.Fn("set_fps_cap")
        if capFn then
            ok = pcall(capFn, enabled and 1000 or (M.Data.OrigFpsCap or 60))
        end
    end
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
    M.UpdateRaycast()
    task.spawn(function()
        newChar:WaitForChild("HumanoidRootPart", 5)
        newChar:WaitForChild("Humanoid", 5)
        if not M.GetRoot(newChar) then return end
        if M.Run.IsShutDown or M.LP.Character ~= newChar then return end

        table.clear(M.Data.WallPassOrig)
        table.clear(M.Data.VisualOrig)
        M.Data.PoseApplied = false
        M.Data.PoseAutoRotate = false
        M.Data.PoseStatesLocked = false
        M.Data.BackLegsOn, M.Data.BackYaw = false, nil
        M.Data.Tilt = nil
        M.Data.FallProtectionApplied = false
        M.Data.HoloApplied = false
        M.BindFallProtection(newChar)
        M.UpdateRaycast()
        M.UpdatePlayerVisuals()
        if M.State.OrbitOn and type(M.F.RebuildOrbits) == "function" then M.F.RebuildOrbits() end
        if M.State.WalkThroughWalls and type(M.F.SetWallPass) == "function" then M.F.SetWallPass(true) end
        if M.State.FlightMode and type(M.F.StartFlying) == "function" then M.F.StartFlying() end
    end)
end

end}

-- [12/69] Доводка: видимость цели, выбор части тела и цели
MODULES[#MODULES + 1] = {"12. Доводка: видимость цели, выбор части тела и цели", function(M, __X)
if M.LP and M.LP.Character then M.OnCharacterAdded(M.LP.Character) end
table.insert(M.Data.Conns, M.LP.CharacterAdded:Connect(M.OnCharacterAdded))
local visCache = setmetatable({}, {__mode = "k"})

-- сброс состояния ассистов
function M.F.ResetAssistState()
    table.clear(visCache)
    M.F.ClearRayCache()
    M.Data.AimLock = nil
    M.Data.LastTriggerTarget = nil
    M.Data.TriggerCD = false
    M.Data.TriggerScan = nil
end

-- откуда летит выстрел, если камера далеко от головы (третье лицо); от первого лица nil
function M.F.ShotFrom(cam)
    local char = M.LP and M.LP.Character
    local head = char and M.GetHead(char)
    if not head then return nil end
    local headPos = head.Position
    if (cam.CFrame.Position - headPos).Magnitude <= 2.5 then return nil end
    return headPos
end

-- луч от камеры до точки
local function visClear(origin, point)
    local delta = point - origin
    local wall = M.RaycastMap(origin, delta)
    return wall == nil or wall.Distance >= delta.Magnitude - 0.4
end

function M.TargetVisibility(targetPart, ownerChar)
    local cam = workspace.CurrentCamera
    if not cam or not targetPart then return false end
    local now = os.clock()
    local c = visCache[targetPart]
    if c and now - c.t < 0.08 then return c.v end
    local camCF = cam.CFrame
    local center = targetPart.Position
    local size = targetPart.Size
    local r = math.min(size.X, size.Y, size.Z) * 0.4
    local right, up = camCF.RightVector * r, camCF.UpVector * r
    local function clearFrom(origin)
        return visClear(origin, center) or visClear(origin, center + right) or visClear(origin, center - right)
            or visClear(origin, center + up) or visClear(origin, center - up)
    end
    local raw = clearFrom(camCF.Position)
    -- от третьего лица пуля летит от персонажа, а не от камеры: цель должна быть видна и из головы
    if raw then
        local shotFrom = M.F.ShotFrom(cam)
        if shotFrom then raw = clearFrom(shotFrom) end
    end
    local lastVisible = c and c.lastVisible
    if raw then lastVisible = now end
    local visible = raw or (lastVisible ~= nil and now - lastVisible < 0.2)
    -- запись в кеше обновляется на месте
    if c then
        c.t, c.v, c.lastVisible = now, visible, lastVisible
    else
        visCache[targetPart] = {t = now, v = visible, lastVisible = lastVisible}
    end
    return visible
end

-- последний известный ответ «видна ли деталь» без новых лучей: видно ли и сколько секунд назад проверено
function M.F.VisPeek(part)
    local c = visCache[part]
    if not c then return nil, math.huge end
    return c.v, os.clock() - c.t
end

-- часть тела цели по режиму
function M.F.PickPart(pChar, mode, cam, cx, cy)
    if mode == "Body" then return M.GetTorso(pChar) end
    if mode ~= "Closest" then return M.GetHead(pChar) end
    local tmp = M.F.BodyParts(pChar)
    local best, bestD = nil, math.huge
    for i = 1, #tmp do
        local part = tmp[i]
        if part.Parent then
            local sp = cam:WorldToViewportPoint(part.Position)
            if sp.Z > 0 then
                local dx, dy = sp.X - cx, sp.Y - cy
                local d = dx * dx + dy * dy
                if d < bestD then best, bestD = part, d end
            end
        end
    end
    return best or tmp[1]
end

-- основные части тела цели без повторов
function M.F.BodyParts(pChar)
    local D = M.Data
    local tmp = D.PickTmp
    if not tmp then
        tmp = {}
        D.PickTmp = tmp
    end
    table.clear(tmp)
    local head, torso, root = M.GetHead(pChar), M.GetTorso(pChar), M.GetRoot(pChar)
    if head then tmp[1] = head end
    if torso and torso ~= head then tmp[#tmp + 1] = torso end
    if root and root ~= head and root ~= torso then tmp[#tmp + 1] = root end
    return tmp
end

-- часть тела, которую видно из камеры
-- запасные детали, если ближайшая к прицелу закрыта: голова, торс и корень, а не все детали тела (каждая - до 10 лучей)
local visSpare = {}
function M.F.VisiblePart(part, pChar, mode, cam, cx, cy)
    if M.TargetVisibility(part, pChar) then return part end
    if mode ~= "Closest" then return nil end
    local tmp = visSpare
    tmp[1], tmp[2], tmp[3] = M.GetHead(pChar) or false, M.GetTorso(pChar) or false, M.GetRoot(pChar) or false
    local best, bestD = nil, math.huge
    for i = 1, 3 do
        local cand = tmp[i]
        if cand and cand ~= part and cand.Parent then
            local sp = cam:WorldToViewportPoint(cand.Position)
            if sp.Z > 0 then
                local dx, dy = sp.X - cx, sp.Y - cy
                local d = dx * dx + dy * dy
                if d < bestD and M.TargetVisibility(cand, pChar) then best, bestD = cand, d end
            end
        end
    end
    return best
end

-- общие условия «Боя» для доводки и выстрела
function M.F.CombatFilter(pChar, pos, camPos)
    local S = M.State
    local maxDist = S.CombatMaxDist
    if maxDist and maxDist > 0 and (pos - camPos).Magnitude > maxDist then return false end
    if S.CombatSkipFF and pChar:FindFirstChildOfClass("ForceField") then return false end
    return true
end

-- есть ли у вашего персонажа предмет
function M.F.HasTool()
    local char = M.LP and M.LP.Character
    return char ~= nil and char:FindFirstChildOfClass("Tool") ~= nil
end

-- радиус зоны доводки. При включённой динамике зона плавно сжимается, пока вы стоите, растёт в ходьбе
-- и ещё сильнее в прыжке и падении; множители задаёт игрок
function M.F.AimRadius()
    local S, D = M.State, M.Data
    local base = S.AimFov
    if not S.AimDynamic then
        D.AimDynMul = nil
        return base
    end
    local now = os.clock()
    local mul = D.AimDynMul
    if mul and D.AimDynAt and now - D.AimDynAt < 1 / 120 then return base * mul end
    -- зону давно никто не спрашивал (доводка была выключена): старое значение устарело, берём сразу нужное
    if D.AimDynAt and now - D.AimDynAt > 0.3 then mul = nil end
    local dt = D.AimDynAt and math.min(now - D.AimDynAt, 0.1) or 0.05
    D.AimDynAt = now
    local target = S.AimDynStand
    local char = M.LP and M.LP.Character
    local hum = char and M.GetHumanoid(char)
    local root = char and M.GetRoot(char)
    D.AimDynState = "Stand"
    if hum and root and hum.Health > 0 and not hum.SeatPart then
        local state = hum:GetState()
        if hum.FloorMaterial == Enum.Material.Air or state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
            or state == Enum.HumanoidStateType.Flying then
            target = S.AimDynJump
            D.AimDynState = "Air"
        else
            -- скорость берётся из трёх источников: у многих игр своё движение, и физическая скорость корня остаётся нулевой
            local v = root.AssemblyLinearVelocity
            local speed = math.sqrt(v.X * v.X + v.Z * v.Z)
            -- шаг корня замеряется раз в 0.06 с, между замерами берётся прошлый результат
            local pos, prev, prevAt = root.Position, D.AimDynPos, D.AimDynPosAt
            if not prevAt or now - prevAt > 0.5 then
                D.AimDynPos, D.AimDynPosAt, D.AimDynStep = pos, now, 0
            elseif now - prevAt > 0.06 then
                local dx, dz = pos.X - prev.X, pos.Z - prev.Z
                D.AimDynStep = math.sqrt(dx * dx + dz * dz) / (now - prevAt)
                D.AimDynPos, D.AimDynPosAt = pos, now
            end
            speed = math.max(speed, D.AimDynStep or 0)
            local k = math.clamp(speed / math.max(hum.WalkSpeed * 0.6, 4), 0, 1)
            -- зажата клавиша движения: ходьба, даже если скорость ещё не набрана
            if hum.MoveDirection.Magnitude > 0.1 then k = 1 end
            target = S.AimDynStand + (S.AimDynWalk - S.AimDynStand) * k
            if k > 0.15 then D.AimDynState = "Walk" end
        end
    end
    mul = mul or target
    -- растёт быстрее, чем сжимается: при движении зона готова сразу, а при остановке сжимается без рывка
    mul = mul + (target - mul) * (1 - math.exp(-dt * (target > mul and 7 or 3.5)))
    D.AimDynMul = mul
    D.AimDynRadius = base * mul
    return base * mul
end

-- расстояние от центра зоны до точки на экране; бесконечность, если точка за спиной или вне экрана.
-- Точка берётся у самого движка (WorldToViewportPoint): это те же пиксели, что видит игрок, при любом режиме поля зрения
local aimCam
local function screenDist(pos, cx, cy)
    local v = aimCam:WorldToViewportPoint(pos)
    local sx, sy, sz = v.X, v.Y, v.Z
    local vs = aimCam.ViewportSize
    if sz > 0 and sx >= 0 and sy >= 0 and sx <= vs.X and sy <= vs.Y then
        local dx, dy = sx - cx, sy - cy
        return math.sqrt(dx * dx + dy * dy)
    end
    return math.huge
end

function M.GetClosestTarget()
    local S, D = M.State, M.Data
    if not S.AimAssist then return nil end
    local char = M.LP and M.LP.Character
    if not char then return nil end
    local hum = M.GetHumanoid(char)
    if not hum or hum.Health <= 0 then return nil end

    local cam = workspace.CurrentCamera
    if not cam then return nil end
    M.Math.ProjBegin(cam)
    aimCam = cam
    -- от чего считается область доводки
    local cx, cy = M.F.AimRef(cam)
    local camPos = cam.CFrame.Position
    local fov = M.F.AimRadius()
    -- захват держится за игрока, а не за деталь
    local lockChar = D.AimLock and D.AimLockChar or nil
    local teamCheck, wallCheck = S.AimTeamCheck, S.AimWallCheck
    local priority, partMode, sticky = S.AimPriority, S.AimPart, S.AimSticky

    -- 1. Дешёвый отбор
    local parts, chars, mets = D.AimParts, D.AimChars, D.AimMets
    if not parts then
        parts, chars, mets = {}, {}, {}
        D.AimParts, D.AimChars, D.AimMets = parts, chars, mets
    end
    table.clear(parts); table.clear(chars); table.clear(mets)
    local n = 0
    -- отладка зоны: по каждому врагу запоминается, почему он взят или нет
    local why = S.AimDebug and (D.AimWhy or {}) or nil
    if why then D.AimWhy, D.AimWhyAt = why, os.clock(); table.clear(why) end
    for _, p in ipairs(M.F.Players()) do
        local pChar = M.F.CharOf(p)
        if p ~= M.LP and pChar and pChar.Parent and M.F.NpcOk(p, "AimNpcs") then
            local targetHum = M.GetHumanoid(pChar)
            local targetHp, _, targetAlive = M.F.CharVitals(pChar, targetHum)
            if targetAlive then
                local part = M.F.PickPart(pChar, partMode, cam, cx, cy)
                if part and part.Parent then
                    local partPos = part.Position
                    local dist = screenDist(partPos, cx, cy)
                    local limit = (pChar == lockChar) and (fov * 1.2) or fov
                    if dist > limit then
                        -- выбранная точка (например голова) вне зоны, а тело внутри: цель тоже захвачена,
                        -- зона считается по всему телу, а не по одной точке; доводка потом идёт к выбранной точке
                        local head, torso, rootPart = M.GetHead(pChar), M.GetTorso(pChar), M.GetRoot(pChar)
                        if head and head ~= part then dist = math.min(dist, screenDist(head.Position, cx, cy)) end
                        if torso and torso ~= part and torso ~= head then dist = math.min(dist, screenDist(torso.Position, cx, cy)) end
                        if rootPart and rootPart ~= part and rootPart ~= torso and rootPart ~= head then
                            dist = math.min(dist, screenDist(rootPart.Position, cx, cy))
                        end
                    end
                    if why then
                        local key = "AimWhy_Ok"
                        if dist > limit then key = "AimWhy_Zone"
                        elseif teamCheck and M.IsTeammate(p) then key = "AimWhy_Team"
                        elseif not M.F.CombatFilter(pChar, partPos, camPos) then key = "AimWhy_Far" end
                        why[pChar] = {Key = key, Dist = dist, Limit = limit}
                    end
                    if dist <= limit and not (teamCheck and M.IsTeammate(p)) and M.F.CombatFilter(pChar, partPos, camPos) then
                        n = n + 1
                        parts[n], chars[n] = part, pChar
                        -- приоритет цели
                        if priority == "Distance" then
                            mets[n] = (partPos - camPos).Magnitude
                        elseif priority == "Health" then
                            mets[n] = targetHp + dist * 0.001
                        else
                            mets[n] = dist
                        end
                    end
                end
            end
        end
    end

    local lockPart, lockMet = nil, nil
    if lockChar then
        for i = 1, n do
            if chars[i] == lockChar then
                local seen = (not wallCheck) and parts[i] or M.F.VisiblePart(parts[i], lockChar, partMode, cam, cx, cy)
                if seen then lockPart, lockMet = seen, mets[i] end
                if why and why[lockChar] then why[lockChar].Key = seen and "AimWhy_Chosen" or "AimWhy_Wall" end
                parts[i], chars[i], mets[i] = parts[n], chars[n], mets[n]
                parts[n], chars[n], mets[n] = nil, nil, nil
                n = n - 1
                break
            end
        end
    end
    local bestPart, bestChar, bestMet = nil, nil, math.huge
    -- «Держать цель»
    if not (sticky and lockMet) then
        -- новых проверок видимости за кадр не больше четырёх: в бою за стенами стоят десятки врагов, и проверка всех
        -- сразу давала фриз. Остальные кандидаты берут ответ последних долей секунды или ждут следующего кадра
        local fresh = 4
        while n > 0 do
            local mi, mm = 1, mets[1]
            for i = 2, n do
                if mets[i] < mm then mi, mm = i, mets[i] end
            end
            local part, pChar = parts[mi], chars[mi]
            parts[mi], chars[mi], mets[mi] = parts[n], chars[n], mets[n]
            parts[n], chars[n], mets[n] = nil, nil, nil
            n = n - 1
            local seen
            if not wallCheck then
                seen = part
            else
                local known, age = M.F.VisPeek(part)
                if known and age < 0.08 then
                    seen = part
                elseif fresh > 0 then
                    -- «закрыта» из кэша тоже проверяется: при «Ближайшей части» может быть видна другая часть тела
                    fresh = fresh - 1
                    seen = M.F.VisiblePart(part, pChar, partMode, cam, cx, cy)
                elseif known and age < 0.4 then
                    -- бюджет кадра кончился: верим недавнему «видно», иначе ждём следующего кадра
                    seen = part
                end
            end
            if why and why[pChar] then why[pChar].Key = seen and "AimWhy_Chosen" or "AimWhy_Wall" end
            if seen then
                bestPart, bestChar, bestMet = seen, pChar, mm
                break
            end
        end
    end

    -- залипание
    if lockMet then
        local mul, add = 1.35, 8
        if priority == "Distance" then mul, add = 1.25, 6 elseif priority == "Health" then mul, add = 1.3, 12 end
        if sticky or lockMet <= bestMet * mul + add then bestPart, bestChar = lockPart, lockChar end
    end
    D.AimLock = bestPart
    D.AimLockChar = bestChar
    return bestPart
end

local function IsAliveModel(model)
    local hum = M.GetHumanoid(model)
    return M.F.IsAliveChar(model, hum)
end

-- точка на экране, куда игрок реально целится
function M.GetAimPoint(cam)
    if M.Services.U.MouseBehavior == Enum.MouseBehavior.LockCenter then
        return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    end
    return M.Services.U:GetMouseLocation()
end

-- метод наведения, который действует сейчас
function M.F.AimMethodNow()
    local method = M.State.AimMethod
    if method == "Auto" then
        if M.Services.U.MouseBehavior ~= Enum.MouseBehavior.LockCenter then return "Mouse" end
        -- игра ведёт камеру сама и перетирает поворот: двигаем мышь, как игрок, это принимает любая камера
        if M.Data.AimOverrideAuto and M.F.MouseMoveFn and M.F.MouseMoveFn() then return "Mouse" end
        return "Camera"
    end
    return method
end

-- точка, от которой считается область доводки и круг
function M.F.AimRef(cam)
    if M.F.AimMethodNow() == "Mouse" then
        local point = M.GetAimPoint(cam)
        return point.X, point.Y
    end
    local size = cam.ViewportSize
    return size.X / 2, size.Y / 2
end

-- луч, который не упирается в невидимые некликабельные детали
local rayIgnore = {}

-- как скрипт отличает карту от не-карты
local MAP_SKIP_NAMES = {
    debris = true, effects = true, effect = true, fx = true, vfx = true, particles = true, bullets = true, bullet = true,
    projectiles = true, projectile = true, tracers = true, tracer = true, casings = true, shells = true, ignore = true,
    ignored = true, trash = true, viewmodel = true, viewmodels = true, arms = true, cosmetics = true, visuals = true,
    gibs = true, ragdolls = true
}
local mapClassCache = setmetatable({}, {__mode = "k"})

-- возвращает "wall", если деталь
function M.ClassifyMapHit(part)
    local now = os.clock()
    local cached = mapClassCache[part]
    if cached and now - cached.t < 1 then return cached.kind, cached.target end

    local players = M.Services.P
    local kind, target = "wall", part
    local current = part
    while current and current ~= workspace do
        if current:IsA("Model") and (players:GetPlayerFromCharacter(current) or M.Data.AltOwner[current] or current:FindFirstChildOfClass("Humanoid")) then
            kind, target = "character", current
            break
        end
        if current:IsA("Accoutrement") or current:IsA("BackpackItem") or MAP_SKIP_NAMES[string.lower(current.Name)] then
            kind, target = "skip", current
            break
        end
        current = current.Parent
    end

    if kind == "wall" then
        local size = part.Size
        local longest = math.max(size.X, size.Y, size.Z)
        if not part.CanCollide or part.Transparency >= 0.6 or longest < 1 then
            kind = "skip"
        elseif not part.Anchored then
            local root = part.AssemblyRootPart
            local fixed = root ~= nil and root.Anchored
            if not fixed and longest < 8 then kind = "skip" end
        end
    end

    mapClassCache[part] = {kind = kind, target = target, t = now}
    return kind, target
end

__X.IsAliveModel = IsAliveModel
__X.rayIgnore = rayIgnore
end}

-- [13/69] Проверка видимости по карте и врагам, запоминание проверок, цель автовыстрела
MODULES[#MODULES + 1] = {"13. Проверка видимости по карте и врагам, запоминание проверок, цель автовыстрела", function(M, __X)
local IsAliveModel = __X.IsAliveModel
local rayIgnore = __X.rayIgnore
-- кэш лучей по карте
function M.F.ClearRayCache()
    local cache = M.Data.RayCache
    if cache then for i = 1, #cache do cache[i].t = -1 end end
end

function M.RaycastMap(origin, direction)
    local D = M.Data
    local cache = D.RayCache
    if not cache then
        -- все 16 ячеек сразу: кэш не растёт, ячейки только перезаписываются
        cache = {}
        for i = 1, 16 do cache[i] = {t = -1, ox = 0, oy = 0, oz = 0, dx = 0, dy = 0, dz = 0, res = false} end
        D.RayCache = cache; D.RayCacheNext = 1; D.RayCacheHits, D.RayCacheMisses = 0, 0
    end
    local now = os.clock()
    local ox, oy, oz, dx, dy, dz = origin.X, origin.Y, origin.Z, direction.X, direction.Y, direction.Z
    for i = 1, #cache do
        local e = cache[i]
        if now - e.t < 0.05 and math.abs(e.ox - ox) < 0.05 and math.abs(e.oy - oy) < 0.05 and math.abs(e.oz - oz) < 0.05
            and math.abs(e.dx - dx) < 0.05 and math.abs(e.dy - dy) < 0.05 and math.abs(e.dz - dz) < 0.05 then
            D.RayCacheHits = D.RayCacheHits + 1
            return e.res or nil
        end
    end
    D.RayCacheMisses = D.RayCacheMisses + 1
    local result = M.F.RaycastMapRaw(origin, direction)
    local slot = D.RayCacheNext
    local e = cache[slot]
    if not e then e = {}; cache[slot] = e end
    e.t, e.ox, e.oy, e.oz, e.dx, e.dy, e.dz, e.res = now, ox, oy, oz, dx, dy, dz, result or false
    D.RayCacheNext = slot % 16 + 1
    return result
end

local function newMapParams()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    pcall(function() params.RespectCanCollide = true end)
    return params
end

-- Передача списка исключений движку дорогая: основной список передаётся, только когда он сменился,
-- а второй набор с дополнительными исключениями нужен, лишь если луч упёрся в то, что надо пропустить
function M.F.RaycastMapRaw(origin, direction)
    local params = M.MapParams
    if not params then
        params = newMapParams()
        M.MapParams = params
    end
    local base = M.Data.RayIgnoreBase or M.RayParams.FilterDescendantsInstances
    if M.MapParamsBase ~= base then
        M.MapParamsBase = base
        params.FilterDescendantsInstances = base
    end
    local result = workspace:Raycast(origin, direction, params)
    if not result then return nil end
    local kind, target = M.ClassifyMapHit(result.Instance)
    if kind == "wall" then return result end
    local extra = M.MapParamsExtra
    if not extra then
        extra = newMapParams()
        M.MapParamsExtra = extra
    end
    local ignore = rayIgnore
    table.clear(ignore)
    for i = 1, #base do ignore[i] = base[i] end
    local last = result
    for _ = 1, 13 do
        ignore[#ignore + 1] = target
        extra.FilterDescendantsInstances = ignore
        result = workspace:Raycast(origin, direction, extra)
        if not result then return nil end
        last = result
        kind, target = M.ClassifyMapHit(result.Instance)
        if kind == "wall" then return result end
    end
    -- пропускаемых объектов подряд больше лимита
    return last
end


-- ближайший подходящий враг на луче
function M.EnemyOnRay(origin, direction, teamCheck)
    local params = M.TriggerParams
    if not params then
        params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        M.TriggerParams = params
        M.TriggerList, M.TriggerSet = {}, {}
    end
    -- список врагов передаётся движку заново, только когда сменился его состав
    local list, set = M.TriggerList, M.TriggerSet
    local n, same = 0, true
    for _, plr in ipairs(M.F.Players()) do
        local ch = M.F.CharOf(plr)
        if plr ~= M.LP and ch and IsAliveModel(ch) and M.F.NpcOk(plr, "TriggerNpcs") and not (teamCheck and M.IsTeammate(plr)) then
            n = n + 1
            if list[n] ~= ch then
                list[n] = ch
                same = false
            end
        end
    end
    for i = #list, n + 1, -1 do
        list[i] = nil
        same = false
    end
    if n == 0 then return nil end
    if not same or M.TriggerAssigned ~= n then
        M.TriggerAssigned = n
        table.clear(set)
        for i = 1, n do set[list[i]] = true end
        params.FilterDescendantsInstances = list
    end
    local hit = workspace:Raycast(origin, direction, params)
    local hitPart = hit and hit.Instance
    local found = hitPart
    while found and not set[found] do found = found.Parent end
    if found then return found, hit.Distance, hitPart end
    return nil
end

-- подходит ли попавшая под луч часть тела под «Куда стрелять»
function M.F.TriggerPartOk(model, hitPart)
    local mode = M.State.TriggerPart
    if mode ~= "Head" and mode ~= "Body" then return true end
    local head = M.GetHead(model)
    local isHead = hitPart == head
    if not isHead and head and hitPart and hitPart.Parent and hitPart.Parent:IsA("Accoutrement") then
        isHead = hitPart.Position.Y >= head.Position.Y - head.Size.Y * 0.6
    end
    if mode == "Head" then return isHead end
    return not isHead
end

-- «Радиус срабатывания»
function M.F.TriggerNearTarget(cam, point, radius)
    local S = M.State
    M.Math.ProjBegin(cam)
    local camPos = cam.CFrame.Position
    local mode = S.TriggerPart
    local pickMode = (mode == "Head") and "Head" or ((mode == "Body") and "Body" or "Closest")
    local best, bestD = nil, radius * radius
    for _, p in ipairs(M.F.Players()) do
        local ch = M.F.CharOf(p)
        if p ~= M.LP and ch and ch.Parent and IsAliveModel(ch) and M.F.NpcOk(p, "TriggerNpcs") and not (S.TriggerTeamCheck and M.IsTeammate(p)) then
            local part = M.F.PickPart(ch, pickMode, cam, point.X, point.Y)
            if part and part.Parent then
                local partPos = part.Position
                local spx, spy, spz = M.Math.Project(partPos)
                if spz > 0 and M.Math.OnScreen(spx, spy, spz) then
                    local dx, dy = spx - point.X, spy - point.Y
                    local d = dx * dx + dy * dy
                    if d <= bestD and M.F.CombatFilter(ch, partPos, camPos)
                        and (not S.TriggerWallCheck or M.F.VisiblePart(part, ch, pickMode, cam, point.X, point.Y)) then
                        best, bestD = ch, d
                    end
                end
            end
        end
    end
    return best
end

-- ищет цель под прицелом
function M.GetTriggerTarget(cam)
    local S = M.State
    local point = M.GetAimPoint(cam)
    local ray = cam:ViewportPointToRay(point.X, point.Y)
    local origin, dir = ray.Origin, ray.Direction
    local direction = dir * 2000

    local model, distance, hitPart = M.EnemyOnRay(origin, direction, S.TriggerTeamCheck)
    if model and M.F.TriggerPartOk(model, hitPart) and M.F.CombatFilter(model, origin + dir * distance, origin) then
        local blocked = false
        if S.TriggerWallCheck then
            local wall = M.RaycastMap(origin, direction)
            blocked = wall ~= nil and wall.Distance < distance - 0.2
            -- от третьего лица стену между персонажем и целью камера может не видеть
            if not blocked then blocked = not M.F.ShotPathClear(cam, origin + dir.Unit * distance) end
        end
        if not blocked then return model, point end
    end
    -- запасная проверка без лучей движка: в некоторых играх детали персонажей лучи не ловят
    if not model then
        local geo = M.F.TriggerGeoTarget(origin, dir.Unit, S.TriggerTeamCheck)
        if geo then return geo, point end
    end
    local radius = S.TriggerRadius
    if radius and radius > 0 then
        local near = M.F.TriggerNearTarget(cam, point, radius)
        if near then return near, point end
    end
    local ahead = M.F.TriggerLeadTarget(cam, point)
    if ahead then return ahead, point end
    return nil
end

-- ближайший враг на линии прицела по геометрии деталей (без Raycast движка)
function M.F.TriggerGeoTarget(origin, unitDir, teamCheck)
    local S = M.State
    local bestModel, bestT = nil, math.huge
    for _, plr in ipairs(M.F.Players()) do
        local ch = M.F.CharOf(plr)
        if plr ~= M.LP and ch and ch.Parent and IsAliveModel(ch) and M.F.NpcOk(plr, "TriggerNpcs") and not (teamCheck and M.IsTeammate(plr)) then
            local root = M.GetRoot(ch)
            if root then
                local rv = root.Position - origin
                local rt = rv:Dot(unitDir)
                -- грубый отсев: враг впереди и не дальше 8 студов от линии
                if rt > 0 and rt < 2000 and (rv - unitDir * rt).Magnitude < 8 then
                    for _, part in ipairs(ch:GetChildren()) do
                        if part:IsA("BasePart") and part.Transparency < 0.95 then
                            local hitT = M.F.RayHitsPart(origin, unitDir, part, 0.05)
                            if hitT and hitT < bestT and M.F.TriggerPartOk(ch, part) then bestModel, bestT = ch, hitT end
                        end
                    end
                end
            end
        end
    end
    if not bestModel then return nil end
    if not M.F.CombatFilter(bestModel, origin + unitDir * bestT, origin) then return nil end
    if S.TriggerWallCheck then
        local wall = M.RaycastMap(origin, unitDir * bestT)
        if wall ~= nil and wall.Distance < bestT - 0.2 then return nil end
        local cam = workspace.CurrentCamera
        if cam and not M.F.ShotPathClear(cam, origin + unitDir * bestT) then return nil end
    end
    return bestModel
end

-- свободен ли путь пули от персонажа до точки (от первого лица всегда да: проверки от камеры хватает)
function M.F.ShotPathClear(cam, point)
    local from = M.F.ShotFrom(cam)
    if not from then return true end
    local delta = point - from
    local wall = M.RaycastMap(from, delta)
    return wall == nil or wall.Distance >= delta.Magnitude - 0.6
end

-- враг, у которого точка упреждения доводки сейчас под прицелом
function M.F.TriggerLeadTarget(cam, point)
    local S, D = M.State, M.Data
    local lead = D.AimLead
    if not (S.AimAssist and lead and lead.Part and lead.Part.Parent and os.clock() - lead.At < 0.12) then return nil end
    if not S.AimLeadOn then return nil end
    if (S.AimPredict or 0) <= 0 and (S.AimBulletSpeed or 0) <= 0 then return nil end
    local part = lead.Part
    if (lead.Pos - part.Position).Magnitude < 0.3 then return nil end  -- упреждение ничтожно: хватает обычного луча
    local model = part:FindFirstAncestorWhichIsA("Model")
    if not model or not IsAliveModel(model) then return nil end
    local plr = (D.Npcs and D.Npcs[model]) or M.Services.P:GetPlayerFromCharacter(model) or D.AltOwner[model]
    if not plr or plr == M.LP or not M.F.NpcOk(plr, "TriggerNpcs") then return nil end
    if S.TriggerTeamCheck and M.IsTeammate(plr) then return nil end
    local mode = S.TriggerPart
    if mode == "Head" or mode == "Body" then
        local isHead = part == M.GetHead(model)
        if (mode == "Head") ~= isHead then return nil end
    end
    local camPos = cam.CFrame.Position
    local sp = cam:WorldToViewportPoint(lead.Pos)
    if sp.Z <= 0 then return nil end
    -- допуск
    local dist = (lead.Pos - camPos).Magnitude
    local tol = part.Size.Magnitude * 0.35 * cam.ViewportSize.Y / (2 * math.tan(math.rad(cam.FieldOfView) / 2) * math.max(dist, 1))
    tol = math.clamp(tol, 6, 40)
    local dx, dy = sp.X - point.X, sp.Y - point.Y
    if dx * dx + dy * dy > tol * tol then return nil end
    if not M.F.CombatFilter(model, lead.Pos, camPos) then return nil end
    if S.TriggerWallCheck then
        local dir = lead.Pos - camPos
        local wall = M.RaycastMap(camPos, dir)
        if wall ~= nil and wall.Distance < dir.Magnitude - 0.2 then return nil end
    end
    return model
end

-- окно игры в фокусе: опрос исполнителя плюс признак недавнего ввода (без фокуса события ввода не приходят)
function M.F.RefreshWindowActive()
    local D = M.Data
    local now = os.clock()
    if now - (D.WindowPollAt or 0) < 0.25 then return end
    D.WindowPollAt = now
    local fn = M.Cap.Fn("isrbxactive") or M.Cap.Fn("iswindowactive")
    if fn then
        local ok, v = pcall(fn)
        if ok and v ~= nil then D.WindowActive = v ~= false end
    end
    if D.LastInputAt and now - D.LastInputAt < 1 then D.WindowActive = true end
end

-- клик через VirtualInputManager
function M.F.SendVimClick(cam)
    local D = M.Data
    if D.VimMissing then return false end
    local vim = D.Vim
    if not vim then
        local ok, svc = pcall(function() return game:GetService("VirtualInputManager") end)
        if not ok or not svc then D.VimMissing = true return false end
        vim = svc
        D.Vim = svc
    end
    local point = M.GetAimPoint(cam)
    local okDown = pcall(vim.SendMouseButtonEvent, vim, point.X, point.Y, 0, true, game, 0)
    if not okDown then D.VimMissing = true return false end
    task.wait(0.03)
    pcall(vim.SendMouseButtonEvent, vim, point.X, point.Y, 0, false, game, 0)
    return true
end

-- клик через VirtualUser
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

    if not okUp then pcall(function() vu:Button1Up(point, cam.CFrame) end) end
    local okClick = pcall(function() vu:ClickButton1(point, cam.CFrame) end)
    return okClick
end

-- один выстрел; known - цель, найденная в этом же кадре (без задержки её не нужно искать лучами заново)
function M.F.FireTrigger(known)
    local delayed = M.State.TriggerDelay > 0
    if delayed then task.wait(M.State.TriggerDelay) end

    if M.Run.IsShutDown or M.Run.MenuOpen or not M.State.TriggerAssist then return false end
    if M.Services.U:GetFocusedTextBox() then return false end  -- блокировка при открытом чате
    -- клик исполнителя
    if not M.Data.WindowActive then return false end
    if M.State.CombatNeedTool and not M.F.HasTool() then return false end

    local cam = workspace.CurrentCamera
    local char = M.LP and M.LP.Character
    local hum = char and M.GetHumanoid(char)
    if not cam or not hum or hum.Health <= 0 then return false end

    -- после задержки цель могла уйти: проверяется заново
    local targetChar = (not delayed and known and known.Parent) and known or M.GetTriggerTarget(cam)
    if not targetChar then return false end

    local fired = false
    local method = M.State.TriggerMethod

    if method == "Click" or method == "Auto" then
        M.Data.LastShot = os.clock()
        -- 1. Приоритет
        local click, press, release = M.Cap.Fn("mouse1click"), M.Cap.Fn("mouse1press"), M.Cap.Fn("mouse1release")
        if click then
            fired = pcall(click)
        end
        if not fired and press and release then
            local okPress = pcall(press)
            local okWait = pcall(task.wait, 0.02)
            local okRelease = pcall(release)
            fired = okPress and okWait and okRelease
        end
        if not fired then
            fired = M.F.SendVimClick(cam)
        end
        if not fired then
            fired = M.F.SendClick(cam)
        end
    end

    if not fired and method ~= "Click" then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            M.Data.LastShot = os.clock()
            local okTool = pcall(function() tool:Activate() end)
            fired = okTool
        end
    end

    -- пауза после выстрела
    task.wait(math.max(M.State.TriggerInterval or 0.06, 0.02))
    return fired
end
-- защита от падений
function M.F.UpdateFallProtection()
    local D = M.Data
    if not M.State.FallProtection and not D.FallProtectionApplied then return end
    local char = M.LP and M.LP.Character
    local h = char and M.GetHumanoid(char)
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

        if now - D.LastMotorFix >= (hit and 0.2 or 1) then
            D.LastMotorFix = now
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("Motor6D") then
                    if not d.Enabled then d.Enabled = true end
                elseif hit and (d:IsA("BallSocketConstraint") or d:IsA("HingeConstraint")) and d.Enabled then
                    d.Enabled = false
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

end}

-- [14/69] Выстрел, защита от падений, третье лицо, автовыстрел
MODULES[#MODULES + 1] = {"14. Выстрел, защита от падений, третье лицо, автовыстрел", function(M, __X)
-- снятие оглушения
function M.F.UpdateAntiStun()
    if not M.State.AntiStun then
        M.Data.StunSince = nil
        return
    end
    local char = M.LP and M.LP.Character
    local h = char and M.GetHumanoid(char)
    if not h or h.Health <= 0 then
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

-- свободная дистанция камеры позади точки фокуса, не заходя за стены
function M.F.OccludedCameraDistance(focus, backward, distance)
    local D = M.Data
    if D.HasSpherecast == nil then D.HasSpherecast = (pcall(function() return workspace.Spherecast end)) end
    local hasSpherecast = D.HasSpherecast
    local ignore = {}
    for i, inst in ipairs(M.Data.RayIgnoreBase or M.RayParams.FilterDescendantsInstances) do ignore[i] = inst end
    for _ = 1, 4 do
        M.ScratchParams.FilterDescendantsInstances = ignore
        local hit
        if hasSpherecast then
            local ok, res = pcall(workspace.Spherecast, workspace, focus, 0.45, backward * distance, M.ScratchParams)
            if ok then hit = res else D.HasSpherecast = false; hasSpherecast = false; hit = workspace:Raycast(focus, backward * distance, M.ScratchParams) end
        else
            hit = workspace:Raycast(focus, backward * distance, M.ScratchParams)
        end
        if not hit then return distance end
        local part = hit.Instance
        local character = M.GetCharacterFromPart(part)
        if character or not part.CanCollide or part.Transparency >= 0.95 then
            table.insert(ignore, character or part)
        else
            return math.max(hit.Distance - (hasSpherecast and 0.1 or 0.6), 0.8)
        end
    end
    return distance
end

-- вид от третьего лица
function M.F.UpdateThirdPerson(cam, hrp, h, active, dt)
    dt = dt or (1 / 60)
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
        -- камера должна смотреть на нашего персонажа
        local subject = cam.CameraSubject
        if not M.Data.Spectating and (subject == nil or (subject:IsA("Humanoid") and subject ~= h)) then
            cam.CameraSubject = h
        end
        -- саму камеру ставит M.F.ThirdPersonFinal в конце кадра: так её не перебивает своя камера игры
        M.Data.TPActive = true

        local poseOverride = M.State.SpinCharacter or M.State.BackWalk
        if not M.Run.MenuOpen and not M.State.SpectateOn then
            M.Services.U.MouseBehavior = Enum.MouseBehavior.LockCenter
            -- сидя корень приварен к сиденью
            if not poseOverride and not h.SeatPart then
                if h.AutoRotate then h.AutoRotate = false end
                local _, ry, _ = cam.CFrame:ToOrientation()
                hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, ry, 0)
            end
        end
    else
        M.Data.TPActive = false
        if M.Data.TPApplied then
            M.Data.TPApplied = false
            M.Data.TPCurDist, M.Data.TPFocusDist = nil, nil
            M.LP.CameraMinZoomDistance = M.Data.OrigZoomMin
            M.LP.CameraMaxZoomDistance = M.Data.OrigZoomMax
            if M.Data.OrigCameraMode then M.LP.CameraMode = M.Data.OrigCameraMode end
            M.Data.TPReleaseUntil = os.clock() + 0.6
        end
        if M.Data.TPReleaseUntil then
            if os.clock() < M.Data.TPReleaseUntil then
                M.Services.U.MouseBehavior = Enum.MouseBehavior.Default
                pcall(function()
                    local gs = UserSettings():GetService("UserGameSettings")
                    if gs.RotationType == Enum.RotationType.CameraRelative then gs.RotationType = Enum.RotationType.MovementRelative end
                end)
                local char = M.LP.Character
                local hum = char and M.GetHumanoid(char)
                if hum and not hum.AutoRotate then hum.AutoRotate = true end
            else
                M.Data.TPReleaseUntil = nil
            end
        end
    end
end

-- детали своего персонажа (список обновляется раз в секунду)
function M.F.SelfParts(char)
    local D = M.Data
    local cache = D.SelfPartsCache
    local now = os.clock()
    if cache and cache.Char == char and now - cache.At < 1 then return cache.List end
    local list = {}
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then list[#list + 1] = d end
    end
    D.SelfPartsCache = {Char = char, At = now, List = list}
    return list
end

-- третье лицо в конце кадра: от того, куда смотрит камера игры, назад на заданную дистанцию.
-- Работает и в играх со своей камерой и с режимом «только первое лицо»
function M.F.ThirdPersonFinal(cam, dt)
    local D, S = M.Data, M.State
    if not D.TPActive or D.Fc or D.Spectating or S.SpectateOn then return end
    local char, _, hrp, alive = M.GetSelf()
    if not (alive and hrp) then return end
    dt = dt or (1 / 60)
    local gameCF = cam.CFrame
    local look = gameCF.LookVector
    local head = M.GetHead(char)
    local headPos = (head and head ~= hrp) and head.Position or (hrp.Position + Vector3.new(0, 1.5, 0))
    local flatRight = Vector3.new(gameCF.RightVector.X, 0, gameCF.RightVector.Z)
    if flatRight.Magnitude > 0.01 then flatRight = flatRight.Unit end
    local dist = S.ThirdPersonDist
    local shoulder, lift = S.ThirdPersonShoulder, S.ThirdPersonHeight
    local pivot = headPos + Vector3.new(0, lift, 0) + flatRight * shoulder
    if shoulder ~= 0 or lift ~= 0 then
        local off = pivot - headPos
        if off.Magnitude > 0.001 then
            local free = M.F.OccludedCameraDistance(headPos, off.Unit, off.Magnitude)
            pivot = headPos + off.Unit * math.min(free, off.Magnitude)
        end
    end
    local free = M.F.OccludedCameraDistance(pivot, -look, dist)
    local cur = D.TPCurDist
    if not cur then
        -- первый кадр после включения
        cur = math.clamp((gameCF.Position - pivot).Magnitude, 0.8, dist)
    end
    if free < cur then
        cur = free
    else
        cur = cur + (free - cur) * (1 - math.exp(-8 * dt))
    end
    D.TPCurDist = cur
    local pos = pivot - look * cur
    if not M.F.FiniteVec(pos) then return end
    -- камеру игры запоминаем: в начале следующего кадра она вернётся, чтобы своя логика игры не сбилась
    D.TPGameCF = gameCF
    -- камера смотрит в точку, куда смотрит камера игры: центр экрана совпадает с тем, куда целятся доводка и игра
    local hit = M.RaycastMap(gameCF.Position, look * 300)
    local want = hit and math.max(hit.Distance, 6) or 300
    -- дальность до точки сглажена: на краях препятствий камера не дёргается
    local fd = D.TPFocusDist or want
    fd = fd + (want - fd) * (1 - math.exp(-14 * dt))
    D.TPFocusDist = fd
    cam.CFrame = CFrame.lookAt(pos, gameCF.Position + look * fd)
    -- игра могла спрятать персонажа как при виде от первого лица
    local hideHats = S.HideHats
    for _, part in ipairs(M.F.SelfParts(char)) do
        if part.LocalTransparencyModifier > 0 and part.Parent and not (hideHats and part:FindFirstAncestorOfClass("Accessory")) then
            part.LocalTransparencyModifier = 0
        end
    end
end

-- автоматический выстрел
function M.F.TriggerRelease()
    local D = M.Data
    D.TriggerSince = nil
    if D.TriggerHeld then
        D.TriggerHeld = false
        M.Cap.Call("mouse1release")
    end
end

function M.F.UpdateTrigger(cam, isAlive)
    local S, D = M.State, M.Data
    if S.TriggerAssist then M.F.RefreshWindowActive() end
    -- «Когда стрелять»
    if not (S.TriggerAssist and not M.Run.MenuOpen and isAlive) or not M.F.TriggerActive()
        or (S.CombatNeedTool and not M.F.HasTool()) or (D.TriggerHeld and not D.WindowActive) then
        D.LastTriggerTarget = nil
        M.F.TriggerRelease()
        return
    end

    -- на высоком FPS кадры почти одинаковы: цель ищем не чаще 60 раз в секунду, если камера не сдвинулась
    local now, camCF = os.clock(), cam.CFrame
    local scan = D.TriggerScan
    if not scan then scan = {At = -1}; D.TriggerScan = scan end
    local curTarget
    if now - scan.At < 1 / 60 and scan.Cam == camCF then
        curTarget = scan.Target
    else
        curTarget = M.GetTriggerTarget(cam)
        scan.At, scan.Cam, scan.Target = now, camCF, curTarget
    end
    if curTarget and not curTarget.Parent then curTarget = nil end
    if not curTarget then
        D.LastTriggerTarget = nil
        M.F.TriggerRelease()
        return
    end

    if S.TriggerHold and M.Cap.All("mouse1press", "mouse1release") then
        D.TriggerSince = D.TriggerSince or now
        if not D.TriggerHeld and now - D.TriggerSince >= (S.TriggerDelay or 0)
            and D.WindowActive and not M.Services.U:GetFocusedTextBox() then
            if M.Cap.Call("mouse1press") then
                D.TriggerHeld = true
                D.LastShot = now
            end
        end
        return
    end
    M.F.TriggerRelease()

    if (S.TriggerLoop or curTarget ~= D.LastTriggerTarget) and not D.TriggerCD then
        D.LastTriggerTarget = curTarget
        D.TriggerCD = true
        task.spawn(function()
            local ok, fired = pcall(M.F.FireTrigger, curTarget)
            if not (ok and fired) then M.Data.LastTriggerTarget = nil end
            M.Data.TriggerCD = false
        end)
    end
end

end}

-- [15/69] Вращение, наклон и угол обзора
MODULES[#MODULES + 1] = {"15. Вращение, наклон и угол обзора", function(M, __X)
-- ==============================================================================
-- [ ВРАЩЕНИЕ И НАКЛОН ]
-- ==============================================================================
-- следующий угол вращения
function M.F.AdvanceSpin(dt)
    local speed = M.State.YawSpeed
    if M.State.JerkySpin then speed = speed + math.random(-25, 25) end
    M.Data.SpinAngle = (M.Data.SpinAngle + speed * math.min(dt, 0.1) * 25) % 360
    M.Data.SpinRate = speed * 25
end

-- ходьба спиной
function M.F.BackWalkYaw(hum, yaw, dt)
    local D = M.Data
    local move = hum.MoveDirection
    local fx, fz = M.Math.Finite(move.X, 0), M.Math.Finite(move.Z, 0)
    local moving = fx * fx + fz * fz > 0.01
    if not moving then
        local cam = workspace.CurrentCamera
        if cam then
            local look = cam.CFrame.LookVector
            fx, fz = M.Math.Finite(look.X, 0), M.Math.Finite(look.Z, 0)
        end
    end
    local target = D.BackYaw
    if fx * fx + fz * fz > 0.0025 then
        -- взгляд персонажа направлен против
        target = math.atan2(fx, fz)
        D.BackYaw = target
    elseif not target then
        target = yaw + math.pi
    end
    local diff = (target - yaw + math.pi) % (2 * math.pi) - math.pi
    if math.abs(diff) < 0.002 then return target, moving end
    return yaw + diff * (1 - math.exp(-16 * dt)), moving
end

-- ноги идут назад
function M.F.BackLegsTracks(hum)
    local src = hum:FindFirstChildOfClass("Animator") or hum
    local ok, tracks = pcall(src.GetPlayingAnimationTracks, src)
    if ok and type(tracks) == "table" then return tracks end
    return nil
end

function M.F.BackLegsIsStep(track)
    local names = M.Data.BackLegsNames
    local known = names[track]
    if known == nil then
        local name = string.lower(tostring(track.Name))
        known = (string.find(name, "walk", 1, true) or string.find(name, "run", 1, true)) ~= nil
        names[track] = known
    end
    return known
end

function M.F.BackLegs(hum)
    M.Data.BackLegsOn = true
    local tracks = M.F.BackLegsTracks(hum)
    if not tracks then return end
    for i = 1, #tracks do
        local track = tracks[i]
        if M.F.BackLegsIsStep(track) then
            local speed = track.Speed
            if type(speed) == "number" and speed > 0 then track:AdjustSpeed(-speed) end
        end
    end
end

-- возвращает прежнее направление анимаций шага
function M.F.BackLegsRestore(hum)
    M.Data.BackLegsOn = false
    local tracks = hum and M.F.BackLegsTracks(hum)
    if not tracks then return end
    for i = 1, #tracks do
        local track = tracks[i]
        if M.F.BackLegsIsStep(track) then
            local speed = track.Speed
            if type(speed) == "number" and speed < 0 then pcall(track.AdjustSpeed, track, -speed) end
        end
    end
end

-- наклон туловища: гнутся суставы, а не корень, и положения деталей уходят всем игрокам.
-- Подходит любому персонажу: путь от корня к голове ищется по суставам, а не по именам (R15, R6, свои модели).
local function tiltJointKids(char)
    local kids = {}
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("JointInstance") then
            local a, b = d.Part0, d.Part1
            if a and b and a:IsA("BasePart") and b:IsA("BasePart") and a ~= b then
                local list = kids[a]
                if not list then list = {}; kids[a] = list end
                list[#list + 1] = {Joint = d, Part = b}
            end
        end
    end
    return kids
end

-- путь от корня к голове: список {Joint, Part}
local function tiltPath(kids, from, target, seen, depth)
    if from == target then return {} end
    if depth > 12 then return nil end
    seen[from] = true
    for _, k in ipairs(kids[from] or {}) do
        if not seen[k.Part] then
            local rest = tiltPath(kids, k.Part, target, seen, depth + 1)
            if rest then
                table.insert(rest, 1, k)
                return rest
            end
        end
    end
    return nil
end

local function tiltCount(kids, part, seen)
    if seen[part] then return 0 end
    seen[part] = true
    local n = 1
    for _, k in ipairs(kids[part] or {}) do n = n + tiltCount(kids, k.Part, seen) end
    return n
end

function M.F.TiltRig(char, hrp)
    local D = M.Data
    local t = D.Tilt
    if t then
        local alive = t.Char == char and t.Hrp == hrp
        if alive then
            for _, it in ipairs(t.Items) do
                if not it.Joint.Parent then alive = false break end
            end
        end
        if alive then return t end
        M.F.ClearTilt()
    end
    local now = os.clock()
    if D.TiltMissAt and D.TiltMissChar == char and now - D.TiltMissAt < 1 then return nil end

    t = {Char = char, Hrp = hrp, Kind = "Root", Items = {}, At = -1}
    local head = M.GetHead(char)
    local kids = tiltJointKids(char)
    local path = head and head ~= hrp and tiltPath(kids, hrp, head, {}, 0) or nil
    if path and #path >= 2 then
        -- первый узел пути, от которого вниз отходят ноги: туловище
        local nodes = {hrp}
        for _, k in ipairs(path) do nodes[#nodes + 1] = k.Part end
        for i = 1, #nodes - 1 do
            local node, onPath = nodes[i], path[i]
            local legs = {}
            for _, k in ipairs(kids[node] or {}) do
                if k ~= onPath and node.Position.Y - k.Part.Position.Y > node.Size.Y * 0.6 then legs[#legs + 1] = k end
            end
            if #legs > 0 then
                if tiltCount(kids, onPath.Part, {}) >= 5 then
                    -- у туловища есть отдельная верхняя часть (R15): гнём сустав в неё
                    t.Kind = "Upper"
                    t.Items[1] = {Joint = onPath.Joint, C0 = onPath.Joint.C0}
                elseif i > 1 then
                    -- торс одним куском (R6): гнём сустав в него вокруг бёдер, ноги возвращаем обратным поворотом
                    local into = path[i - 1]
                    local parent = into.Joint.Part0
                    local pivot = parent.CFrame:PointToObjectSpace(node.Position) - Vector3.new(0, node.Size.Y * 0.5, 0)
                    t.Kind = "Hips"
                    t.Pivot = CFrame.new(pivot)
                    t.Rel = into.Joint.C0 * into.Joint.C1:Inverse()
                    t.Items[1] = {Joint = into.Joint, C0 = into.Joint.C0}
                    for _, leg in ipairs(legs) do t.Items[#t.Items + 1] = {Joint = leg.Joint, C0 = leg.Joint.C0, Leg = true} end
                end
                break
            end
        end
    end
    if t.Kind == "Root" then
        -- суставов не нашлось: наклоняется корень целиком
        D.TiltMissAt, D.TiltMissChar = now, char
    elseif path[1] and path[1].Joint.Part0 == hrp then
        -- сустав от корня к телу: им корень, наклонённый для всех, возвращается ровно на вашем экране
        for i, it in ipairs(t.Items) do
            if it.Joint == path[1].Joint then t.RootIdx = i end
        end
        if not t.RootIdx then
            t.Items[#t.Items + 1] = {Joint = path[1].Joint, C0 = path[1].Joint.C0}
            t.RootIdx = #t.Items
        end
    end
    D.Tilt = t
    return t
end

-- возвращает, на сколько наклонить корень.
-- Режимы: "TiltAll" - корень наклонён (это передаётся всем), а у вас на экране ноги ровно и гнётся туловище;
-- "TiltTorso" - только туловище в суставах (Roblox не передаёт суставы другим игрокам, видно только вам); "TiltBody" - всё тело
function M.F.ApplyTilt(char, hrp, pitch, mode)
    mode = mode or "TiltTorso"
    local t = M.F.TiltRig(char, hrp)
    if not t or t.Kind == "Root" then return pitch end
    if mode == "TiltBody" then
        if t.Want then
            for _, it in ipairs(t.Items) do
                if it.Joint.Parent and it.Joint.C0 ~= it.C0 then it.Joint.C0 = it.C0 end
            end
            t.Want = nil
        end
        return pitch
    end
    local rootPitch = (mode == "TiltAll" and t.RootIdx) and pitch or 0
    local now = os.clock()
    if t.Pitch ~= pitch or t.Mode ~= mode or now - t.At >= 0.25 or not t.Want then
        t.Pitch, t.Mode, t.At = pitch, mode, now
        local turn = CFrame.Angles(pitch, 0, 0)
        local want = {}
        if t.Kind == "Upper" then
            want[1] = t.Items[1].C0 * turn
        else
            local bend = t.Pivot * turn * t.Pivot:Inverse()
            local back = t.Rel:Inverse() * bend:Inverse() * t.Rel
            want[1] = bend * t.Items[1].C0
            for i = 2, #t.Items do
                if t.Items[i].Leg then want[i] = back * t.Items[i].C0 end
            end
        end
        if t.RootIdx then
            local ri = t.RootIdx
            want[ri] = CFrame.Angles(-rootPitch, 0, 0) * (want[ri] or t.Items[ri].C0)
        end
        for i, it in ipairs(t.Items) do want[i] = want[i] or it.C0 end
        t.Want = want
    end
    -- игра или анимация могли вернуть сустав: сверяется каждый кадр
    local want = t.Want
    for i, it in ipairs(t.Items) do
        if it.Joint.C0 ~= want[i] then it.Joint.C0 = want[i] end
    end
    return rootPitch
end

-- возвращает суставы, как были
function M.F.ClearTilt()
    local D = M.Data
    local t = D.Tilt
    D.Tilt = nil
    if not t then return end
    pcall(function()
        for _, it in ipairs(t.Items) do
            if it.Joint.Parent then it.Joint.C0 = it.C0 end
        end
    end)
end

function M.F.UpdatePoseReal(dt)
    local S, D = M.State, M.Data
    local wantSpin, wantTilt, wantBack = S.SpinCharacter, S.HeadTiltOn, S.BackWalk
    if not (wantSpin or wantTilt or wantBack) and not D.PoseApplied and not D.BackLegsOn then return end

    local char = M.LP and M.LP.Character
    local hrp = M.GetRoot(char)
    local hum = char and M.GetHumanoid(char)
    local alive = hrp ~= nil and hum ~= nil and hum.Health > 0 and not M.Run.IsShutDown
    if not hrp then
        D.PoseApplied, D.PoseAutoRotate, D.BackLegsOn, D.BackYaw = false, false, false, nil
        return
    end
    -- корень с NaN или бесконечностью в положении
    if not M.F.FiniteVec(hrp.Position) then return end

    local back = wantBack and not wantSpin and hum ~= nil and hum.SeatPart == nil and not hum.PlatformStand
        and hum:GetState() ~= Enum.HumanoidStateType.Climbing
    if alive and (wantSpin or wantTilt or back) and not S.FlightMode then
        local _, yaw = hrp.CFrame:ToOrientation()
        if wantSpin then
            M.F.AdvanceSpin(dt)
            yaw = math.rad(D.SpinAngle)
        elseif back then
            yaw = M.F.BackWalkYaw(hum, yaw, dt)
        end
        if wantSpin or back then
            if hum.AutoRotate then
                hum.AutoRotate = false
                D.PoseAutoRotate = true
            end
        elseif D.PoseAutoRotate then
            hum.AutoRotate = true
            D.PoseAutoRotate = false
        end
        -- корень поворачивается вокруг вертикали, наклон идёт в суставах: ноги стоят, туловище и всё выше гнутся
        local rootPitch = 0
        if wantTilt then
            rootPitch = M.F.ApplyTilt(char, hrp, math.rad(math.clamp(S.PitchAngle, -90, 90)), S.TiltMode)
        elseif D.Tilt then
            M.F.ClearTilt()
        end
        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(rootPitch, 0, 0)
        -- угловая скорость уходит другим игрокам вместе с положением: их клиенты крутят персонажа плавно между пакетами, а не рывками
        if wantSpin then
            local w = math.rad(D.SpinRate or 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, math.clamp(w, -45, 45), 0)
            D.SpinVelSet = true
        elseif D.SpinVelSet then
            D.SpinVelSet = false
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        D.PoseApplied = true
        -- обратные ноги
        if back and S.BackWalkLegs then
            pcall(M.F.BackLegs, hum)
        elseif D.BackLegsOn then
            pcall(M.F.BackLegsRestore, hum)
        end
        if not back then D.BackYaw = nil end
    elseif D.PoseApplied or D.BackLegsOn then
        -- выключили или умерли
        D.PoseApplied = false
        D.BackYaw = nil
        M.F.ClearTilt()
        if alive and hrp then
            local _, yaw = hrp.CFrame:ToOrientation()
            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
            if D.SpinVelSet then hrp.AssemblyAngularVelocity = Vector3.zero end
        end
        D.SpinVelSet = false
        if hum and D.PoseAutoRotate then hum.AutoRotate = true end
        D.PoseAutoRotate = false
        if D.BackLegsOn then pcall(M.F.BackLegsRestore, hum) end
    end
end

-- приближение и свой FOV
function M.F.UpdateFov(cam, dt)
    local zoomWanted = M.State.ZoomOn and M.Data.ZoomHeld and not M.Run.MenuOpen
    M.Data.ZoomBlend = M.Math.Smooth(M.Data.ZoomBlend, zoomWanted and 1 or 0, dt, M.State.ZoomSpeed)

    local controlling = M.State.FovOn or M.Data.ZoomBlend > 0
    if not controlling then
        -- ничего не трогаем
        if M.Data.FovApplied then
            M.Data.FovApplied = false
            M.Data.FovTarget = nil
            cam.FieldOfView = M.Data.GameFov
        else
            M.Data.GameFov = cam.FieldOfView
        end
        return
    end

    M.Data.FovApplied = true
    if M.Data.FovCam ~= cam then
        M.Data.FovCam = cam
        if M.Data.FovConn then M.Data.FovConn:Disconnect() end
        M.Data.FovConn = cam:GetPropertyChangedSignal("FieldOfView"):Connect(function()
            local want = M.Data.FovTarget
            if M.Run.IsShutDown or M.Data.FovBusy or not want then return end
            if math.abs(cam.FieldOfView - want) > 0.001 then
                M.Data.FovBusy = true
                cam.FieldOfView = want
                M.Data.FovBusy = false
            end
        end)
        table.insert(M.Data.Conns, M.Data.FovConn)
    end
    local base = M.State.FovOn and math.clamp(M.State.CamFov, 30, 120) or M.Data.GameFov
    local target = base + (math.clamp(M.State.ZoomFov, 10, 100) - base) * M.Data.ZoomBlend
    M.Data.FovTarget = target
    if math.abs(cam.FieldOfView - target) > 0.001 then
        cam.FieldOfView = target
    end
end

end}

-- [16/69] Камера: доводка, упреждение
MODULES[#MODULES + 1] = {"16. Камера: доводка, упреждение", function(M, __X)
-- ==============================================================================
-- [ КАМЕРА: ДОВОДКА И FOV ]
-- ==============================================================================
-- перед работой камеры Roblox снимаем прошлую тряску
pcall(function() M.Services.R:UnbindFromRenderStep("ShakeUndo") end)
M.Services.R:BindToRenderStep("ShakeUndo", Enum.RenderPriority.Camera.Value - 1, function()
    local cam = workspace.CurrentCamera
    if cam then M.F.UndoShake(cam) end
end)

-- в начале кадра камере возвращается то, что поставила игра: третье лицо сдвигало её только для картинки
pcall(function() M.Services.R:UnbindFromRenderStep("TPRestore") end)
M.Services.R:BindToRenderStep("TPRestore", Enum.RenderPriority.First.Value, function()
    local D = M.Data
    local saved = D.TPGameCF
    if not saved then return end
    D.TPGameCF = nil
    local cam = workspace.CurrentCamera
    if cam and not D.Fc then pcall(function() cam.CFrame = saved end) end
end)

-- доводка прицела
function M.F.ModeActive(mode, keyName, slot)
    if mode == "HoldKey" then
        if keyName == nil or keyName == "" then return false end
        -- пока вы печатаете
        if M.Services.U:GetFocusedTextBox() then return false end
        local D = M.Data
        local cache = D.KeyCache
        if not cache then
            cache = {}
            D.KeyCache = cache
        end
        local e = cache[slot]
        if not e then
            e = {}
            cache[slot] = e
        end
        if e.Name ~= keyName then
            e.Name = keyName
            e.Code, e.Mouse = nil, nil
            if M.F.BindMouse and M.F.BindMouse[keyName] then
                e.Mouse = Enum.UserInputType[keyName]
            else
                local ok, code = pcall(function() return Enum.KeyCode[keyName] end)
                e.Code = ok and code or nil
            end
        end
        if e.Mouse then return M.Services.U:IsMouseButtonPressed(e.Mouse) end
        return e.Code ~= nil and M.Services.U:IsKeyDown(e.Code)
    elseif mode == "HoldRmb" then
        return M.Services.U:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end
    return true
end

function M.F.AimActive() return M.F.ModeActive(M.State.AimMode, M.State.AimKey, "Aim") end
function M.F.TriggerActive() return M.F.ModeActive(M.State.TriggerMode, M.State.TriggerKey, "Trigger") end

-- скорость цели
function M.F.TargetVelocity(part)
    local D = M.Data
    local now = os.clock()
    local pos = part.Position
    if D.AimVelPart ~= part or now - D.AimVelAt > 0.5 then
        D.AimVelPart, D.AimVelPos, D.AimVelAt, D.AimVel = part, pos, now, Vector3.zero
    else
        local dt = now - D.AimVelAt
        if dt > 0.0001 then
            local raw = (pos - D.AimVelPos) / dt
            if raw.Magnitude > 300 then raw = raw.Unit * 300 end
            D.AimVel = D.AimVel + (raw - D.AimVel) * (1 - math.exp(-dt / 0.08))
            D.AimVelPos, D.AimVelAt = pos, now
        end
    end
    local physics = part.AssemblyLinearVelocity
    if physics.Magnitude > 1 and physics.Magnitude < 300 then return physics end
    return D.AimVel
end

-- умное упреждение по движению персонажа

-- высота центра корня над поверхностью под ним
function M.F.HeightAbove(root, char)
    local params = M.ScratchParams
    params.FilterDescendantsInstances = {char, M.LP.Character}
    local hit = workspace:Raycast(root.Position, Vector3.new(0, -500, 0), params)
    if hit then return root.Position.Y - hit.Position.Y end
    return nil
end

-- раз в кадр
function M.F.MotionUpdate(part)
    local D = M.Data
    local vel = M.F.TargetVelocity(part)
    local now = os.clock()
    local mo = D.AimMotion
    if not mo or mo.Part ~= part then
        local char = part:FindFirstAncestorWhichIsA("Model")
        mo = {Part = part, Char = char, Hum = char and M.GetHumanoid(char), Root = char and M.GetRoot(char),
            V = vel, Acc = Vector3.zero, At = now}
        D.AimMotion = mo
    end
    local dt = now - mo.At
    if dt > 0.0005 then
        if dt < 0.3 then
            local raw = (vel - mo.V) / dt
            mo.Acc = mo.Acc + (raw - mo.Acc) * (1 - math.exp(-dt / 0.12))
        else
            mo.Acc = Vector3.zero
        end
        mo.V, mo.At = vel, now
    end
    mo.Vel = vel
    mo.Frame = nil
    return mo
end

-- смещение цели за T секунд
M.Tune = M.Tune or {}
M.Tune.Lead = {
    MinSpeed = 1.5,  -- медленнее - стоит на месте
    AccNoise = 6,
    AccMax = 80,  -- больше - рывок или телепорт, обрезаем
    AccTime = 0.35,  -- дальше этого времени ускорение не тянем
    FallSpeed = 6,
    GroundVy = 4,
}

function M.F.MotionDisplacement(mo, T)
    if T <= 0 then return Vector3.zero end
    local LT = M.Tune.Lead
    local vel = mo.Vel
    local hum, root = mo.Hum, mo.Root
    local hv = Vector3.new(vel.X, 0, vel.Z)
    local airborne, free = false, false
    if hum and hum.Parent then
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming
            or state == Enum.HumanoidStateType.Seated or hum.Sit then
            free = true  -- линейно, без гравитации
        else
            airborne = hum.FloorMaterial == Enum.Material.Air or state == Enum.HumanoidStateType.Freefall
                or state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Flying
        end
    end
    -- горизонталь
    local hdisp = Vector3.zero
    local speed = hv.Magnitude
    if speed >= LT.MinSpeed then
        if airborne or free then
            hdisp = hv * T
        else
            local a = Vector3.new(mo.Acc.X, 0, mo.Acc.Z)
            if a.Magnitude < LT.AccNoise then a = Vector3.zero elseif a.Magnitude > LT.AccMax then a = a.Unit * LT.AccMax end
            local along = a:Dot(hv / speed)
            local Tm = T
            if along < -1 then Tm = math.min(T, speed / -along) end  -- тормозит: прогноз до остановки
            local Ta = math.min(Tm, LT.AccTime)
            hdisp = hv * Tm + a * (LT.AccTime * Ta * Ta)
        end
    end
    -- вертикаль
    local vy, vdisp = vel.Y, 0
    if airborne and not (math.abs(vy) > LT.FallSpeed or mo.Acc.Y < -0.35 * workspace.Gravity) then airborne = false end
    if airborne and not free then
        local g = workspace.Gravity
        local te = T
        if root then
            if mo.Height == nil or mo.HeightFrame ~= M.Data.AimFrame then
                mo.Height = M.F.HeightAbove(root, mo.Char) or false
                mo.HeightFrame = M.Data.AimFrame
            end
            if mo.Height then
                local standing = root.Size.Y * 0.5 + ((hum and hum.HipHeight > 0) and hum.HipHeight or 2)
                local h = mo.Height - standing
                if h <= 0 then
                    te = 0
                else
                    local tl = (vy + math.sqrt(vy * vy + 2 * g * h)) / g
                    if tl < te then te = tl end
                end
            end
        end
        vdisp = vy * te - 0.5 * g * te * te
    elseif free then
        vdisp = vy * T
    else
        vdisp = math.clamp(vy, -LT.GroundVy, LT.GroundVy) * T
    end
    return Vector3.new(hdisp.X, vdisp, hdisp.Z)
end

-- куда целиться, чтобы попасть по движущейся цели
function M.F.LeadPosition(target, camPos)
    local S = M.State
    local pos = target.Position
    -- упреждение выключено: ровно в деталь цели, без расчёта движения
    if not S.AimLeadOn then return pos end
    local lead, speed = S.AimPredict or 0, S.AimBulletSpeed or 0
    M.Data.AimFrame = (M.Data.AimFrame or 0) + 1
    local mo = M.F.MotionUpdate(target)
    local base = lead + math.clamp((S.AimTime or 0) / 3000, 0, 0.12)
    local flight = 0
    if speed > 0 then
        -- время полёта считается дважды
        flight = (pos - camPos).Magnitude / speed
        flight = (pos + M.F.MotionDisplacement(mo, math.min(base + flight, 3)) - camPos).Magnitude / speed
        flight = math.min(flight, 3)
    end
    local disp = M.F.MotionDisplacement(mo, math.min(base + flight, 3))
    local cap = S.AimLeadMax or 12
    if cap > 0 and disp.Magnitude > cap then disp = disp.Unit * cap end
    local result = pos + disp
    if speed > 0 and S.AimBulletDrop then
        result = result + Vector3.new(0, 0.5 * workspace.Gravity * flight * flight, 0)
    end
    return result
end
-- функция исполнителя для относительного движения мыши
function M.F.MouseMoveFn()
    return M.Cap.Fn("mousemoverel")
end

-- окно Roblox в фокусе? Мышью двигаем, только пока игра активна
M.Data.WindowActive = true
pcall(function()
    local fn = M.Cap.Fn("isrbxactive") or M.Cap.Fn("iswindowactive")
    if fn then M.Data.WindowActive = fn() ~= false end
end)
table.insert(M.Data.Conns, M.Services.U.WindowFocused:Connect(function() M.Data.WindowActive = true end))
table.insert(M.Data.Conns, M.Services.U.WindowFocusReleased:Connect(function() M.Data.WindowActive = false end))

-- метод «Мышь»
M.Data.MsHistX, M.Data.MsHistY = {0, 0, 0}, {0, 0, 0}

function M.F.Median(buf)
    local sorted = table.clone(buf)
    table.sort(sorted)
    return sorted[math.ceil(#sorted / 2)]
end

-- разрыв цепочки замеров
function M.F.MouseReset()
    local D = M.Data
    D.MsPrevEx = nil
    for j = 1, 3 do D.MsHistX[j], D.MsHistY[j] = 0, 0 end
end

-- забыть всё, что намеряли (включили/выключили автоподстройку)
function M.F.MouseForget()
    local D = M.Data
    M.F.MouseReset()
    D.MsSamples, D.MouseG, D.MsLag, D.MsLagErr, D.MsLagN = nil, nil, nil, nil, nil
end

function M.F.MousePush(ix, iy)
    local hx, hy = M.Data.MsHistX, M.Data.MsHistY
    hx[3], hx[2], hx[1] = hx[2], hx[1], ix
    hy[3], hy[2], hy[1] = hy[2], hy[1], iy
end

function M.F.MouseCalibrate(cam, ref, part)
    local D = M.Data
    local now = os.clock()
    local camPos = cam.CFrame.Position
    local raw = part.Position
    if D.MsPrevPart ~= part then
        D.MsPrevPart = part
        M.F.MouseReset()
    end
    local a = cam:WorldToViewportPoint(raw)
    if a.Z <= 0 then M.F.MouseReset() return end
    local ex, ey = a.X - ref.X, a.Y - ref.Y
    local pex, pey, pp, pc = D.MsPrevEx, D.MsPrevEy, D.MsPrevP, D.MsPrevC
    local fresh = pex and now - (D.MsPrevAt or 0) < 0.12
    D.MsPrevEx, D.MsPrevEy, D.MsPrevP, D.MsPrevC, D.MsPrevAt = ex, ey, raw, camPos, now
    if not fresh or pex * pex + pey * pey < 100 then return end

    local dx, dy = ex - pex, ey - pey
    local rel = (raw - pp) - (camPos - pc)
    local relMag = rel.Magnitude
    if relMag > 20 then return end  -- телепорт/респавн
    if relMag > 0.001 then
        local b = cam:WorldToViewportPoint(raw - rel)
        if b.Z <= 0 then return end
        dx, dy = dx - (a.X - b.X), dy - (a.Y - b.Y)
    end

    local bufs = D.MsSamples
    if not bufs then
        bufs = {{}, {}, {}}
        D.MsSamples = bufs
    end
    local errs, cnt = D.MsLagErr, D.MsLagN
    if not errs then
        errs, cnt = {0, 0, 0}, {0, 0, 0}
        D.MsLagErr, D.MsLagN = errs, cnt
    end
    local hx, hy = D.MsHistX, D.MsHistY
    for lag = 1, 3 do
        local sx, sy = hx[lag], hy[lag]
        local ss = sx * sx + sy * sy
        if ss >= 4 then
            local g = -(dx * sx + dy * sy) / ss
            local buf = bufs[lag]
            if g > 0.05 and g < 30 then
                buf[#buf + 1] = g
                if #buf > 15 then table.remove(buf, 1) end
            end
            if #buf > 0 then
                local gm = M.F.Median(buf)
                local rx, ry = dx + gm * sx, dy + gm * sy
                local r = math.min(math.sqrt(rx * rx + ry * ry) / (gm * math.sqrt(ss) + 2), 3)
                errs[lag] = cnt[lag] == 0 and r or errs[lag] + (r - errs[lag]) * 0.15
                cnt[lag] = cnt[lag] + 1
            end
        end
    end
    -- одному замеру не верим
    local best = D.MsLag
    if not best or #bufs[best] < 3 then
        best = nil
        for lag = 1, 3 do
            if #bufs[lag] >= 3 and (not best or errs[lag] < errs[best]) then best = lag end
        end
    elseif errs[best] > 0.25 then
        local cur = best
        for lag = 1, 3 do
            if lag ~= cur and cnt[lag] >= 6 and #bufs[lag] >= 3 and errs[lag] < errs[best] * 0.5 then best = lag end
        end
    end
    if best then
        D.MsLag = best
        D.MouseG = M.F.Median(bufs[best])
    end
end

end}

-- [17/69] Камера: метод «Мышь», неровное движение прицела, шаг доводки, курсор, проверка окружения
MODULES[#MODULES + 1] = {"17. Камера: метод «Мышь», неровное движение прицела, шаг доводки, курсор, проверка окружения", function(M, __X)
function M.F.AimWithMouse(cam, targetPos, factor, part)
    local D = M.Data
    local fn = M.F.MouseMoveFn()
    if not fn or not D.WindowActive then M.F.MouseReset() return end
    local sp = cam:WorldToViewportPoint(targetPos)
    if sp.Z <= 0 then M.F.MouseReset() return end
    local ref = M.GetAimPoint(cam)
    local ex, ey = sp.X - ref.X, sp.Y - ref.Y
    if ex ~= ex or ey ~= ey or ex * ex + ey * ey > 1e12 then M.F.MouseReset() return end
    if M.State.AimMouseAuto and part then M.F.MouseCalibrate(cam, ref, part) end
    if ex * ex + ey * ey < 1 then
        D.AimAccX, D.AimAccY = 0, 0
        M.F.MousePush(0, 0)
        return
    end
    local k = math.min(factor, 0.9) * (M.State.AimMouseGain or 1)
    if M.State.AimMouseAuto then
        local g = D.MouseG
        if g then
            k = k / g
            local hx, hy = D.MsHistX, D.MsHistY
            for j = 1, (D.MsLag or 1) - 1 do
                ex, ey = ex - g * hx[j], ey - g * hy[j]
            end
        else
            -- чувствительность ещё не знаем
            local hx, hy = D.MsHistX, D.MsHistY
            if hx[1] ~= 0 or hy[1] ~= 0 or hx[2] ~= 0 or hy[2] ~= 0 or hx[3] ~= 0 or hy[3] ~= 0 then
                M.F.MousePush(0, 0)
                return
            end
            k = math.min(k, 0.25)
        end
    end
    local ax = (D.AimAccX or 0) + ex * k
    local ay = (D.AimAccY or 0) + ey * k
    local ix = ax >= 0 and math.floor(ax) or math.ceil(ax)
    local iy = ay >= 0 and math.floor(ay) or math.ceil(ay)
    D.AimAccX, D.AimAccY = ax - ix, ay - iy
    M.F.MousePush(ix, iy)
    if ix ~= 0 or iy ~= 0 then pcall(fn, ix, iy) end
end

-- неровное движение прицела, как у человека: паузы, запоздалая реакция, небольшой разброс
function M.F.UnevenAim(cam, target, aimPos)
    local D = M.Data
    local now = os.clock()
    local model = target:FindFirstAncestorWhichIsA("Model") or target
    local h = D.AimHum
    if not h or h.Model ~= model or now - h.Seen > 0.5 then
        h = {Model = model, Start = now, Seed = math.random() * 100, React = 0.12 + math.random() * 0.13,
            NextPause = now + 0.6 + math.random() * 0.9, PauseUntil = 0}
        D.AimHum = h
    end
    h.Seen = now
    local camCF = cam.CFrame
    local toTarget = aimPos - camCF.Position
    if toTarget.Magnitude > 0.01 then
        local err = math.deg(math.acos(math.clamp(camCF.LookVector:Dot(toTarget.Unit), -1, 1)))
        if err < 0.4 then
            h.Calm = now
        elseif err > 1.5 and h.Calm and now - h.Calm < 0.6 then
            h.Calm, h.Start, h.React = nil, now, 0.1 + math.random() * 0.14
        end
    end
    local t = now + h.Seed
    local mul = 1 + 0.45 * math.sin(t * 2.1) * math.sin(t * 0.73 + 1.7) + 0.25 * math.sin(t * 4.3 + 2.3)
    mul = math.clamp(mul, 0.35, 1.6)
    local age = now - h.Start
    if age < h.React then
        local k = age / h.React
        mul = mul * (0.12 + 0.88 * k * k * (3 - 2 * k))
    end
    if now >= h.NextPause then
        h.PauseUntil = now + 0.05 + math.random() * 0.09
        h.NextPause = h.PauseUntil + 0.7 + math.random() * 1.1
    end
    if now < h.PauseUntil then mul = mul * 0.12 end
    local amp = 0.12 + (aimPos - camCF.Position).Magnitude * 0.0025
    amp = math.min(amp, 0.6)
    local sx = math.sin(t * 3.1) + 0.5 * math.sin(t * 7.7 + 3)
    local sy = math.sin(t * 2.3 + 2) + 0.5 * math.sin(t * 6.1 + 1)
    return mul, camCF.RightVector * (amp * sx) + camCF.UpVector * (amp * sy)
end

function M.F.UpdateAim(cam, dt, isAlive)
    local S = M.State
    if not (S.AimAssist and not M.Run.MenuOpen and isAlive) or S.SpectateOn or M.Data.Spectating or not M.F.AimActive()
        or (S.CombatNeedTool and not M.F.HasTool()) then
        M.Data.AimLock = nil
        M.F.MouseReset()
        return
    end
    local target = M.GetClosestTarget()
    if not target then
        M.F.MouseReset()
        return
    end
    local camCF = cam.CFrame
    local camPos = camCF.Position
    -- упреждение
    local targetPos = M.F.LeadPosition(target, camPos)
    -- плавная наводка всегда отстаёт от бегущей цели на скорость x (время сглаживания / 3): это и есть промах мимо головы.
    -- Эту долю добавляем к точке прицеливания (упреждение по пингу и пуле остаётся отдельной настройкой)
    if S.AimLagComp and not S.AimLeadOn and S.AimTime > 0 then
        local v = M.F.TargetVelocity(target)
        if v.Magnitude > 1.5 then
            local shift = v * math.min(S.AimTime / 3000, 0.12)
            if shift.Magnitude > 3 then shift = shift.Unit * 3 end
            targetPos = targetPos + shift
        end
    end
    -- цель в NaN или за пределами разумного
    if not M.F.FiniteVec(targetPos) then
        M.Data.AimLead = nil
        return
    end
    M.Data.AimLead = {Part = target, Pos = targetPos, At = os.clock()}
    -- неровное движение прицела
    local humanMul = 1
    if S.AimHumanize then
        local offset
        humanMul, offset = M.F.UnevenAim(cam, target, targetPos)
        targetPos = targetPos + offset
    end
    -- мёртвая зона
    local dead = S.AimDeadzone
    if dead and dead > 0 then
        local sp = cam:WorldToViewportPoint(targetPos)
        if sp.Z > 0 then
            local rx, ry = M.F.AimRef(cam)
            local ex, ey = sp.X - rx, sp.Y - ry
            if ex * ex + ey * ey <= dead * dead then
                M.Data.AimAccX, M.Data.AimAccY = 0, 0
                M.F.MouseReset()
                return
            end
        end
    end
    local tau = S.AimTime / 1000
    local factor = (tau <= 0) and 1 or (1 - math.exp(-3 * dt / tau))
    if humanMul ~= 1 then factor = math.min(factor * humanMul, 1) end
    if M.F.AimMethodNow() == "Mouse" and M.F.MouseMoveFn() then
        M.F.AimWithMouse(cam, targetPos, factor, target)
        return
    end
    if (targetPos - camPos).Magnitude > 0.001 then
        local targetCF = CFrame.lookAt(camPos, targetPos, Vector3.yAxis)
        cam.CFrame = camCF:Lerp(targetCF, factor)
        M.Data.AimStepWrote = true
    end
end

function M.F.ReassertAim(cam)
    local D = M.Data
    local written = D.AimWritten
    if not written then return end
    D.AimWritten = nil
    local now = cam.CFrame
    if (now.Position - written.Position).Magnitude > 0.01 or now.LookVector:Dot(written.LookVector) < 0.99999 then
        D.AimOverwritten = (D.AimOverwritten or 0) + 1
        if D.AimOverwritten >= 12 and not D.AimOverrideAuto then
            D.AimOverrideAuto = true
            local toMouse = M.State.AimMethod == "Auto" and M.F.MouseMoveFn() ~= nil
            M.F.Notify("AimOverrideAuto", M.Translate(toMouse and "AimAutoMouse" or "AimOverrideAuto"), false, true)
        end
        if M.State.AimOverride or D.AimOverrideAuto then cam.CFrame = written end
    else
        D.AimOverwritten = 0
    end
end

-- готовые настройки доводки
M.F.AimPresets = {
    -- мягкая: помогает только у прицела, плавно и неровно, как рука; цель - ближайшая к прицелу часть тела
    Soft = {AimTime = 180, AimFov = 110, AimDeadzone = 4, AimLeadOn = false, AimPredict = 0, AimSticky = false, AimHumanize = true,
        AimPart = "Closest", AimPriority = "Crosshair"},
    Balanced = {AimTime = 110, AimFov = 180, AimDeadzone = 3, AimLeadOn = false, AimPredict = 0, AimSticky = false, AimHumanize = false},
    -- резкая: быстро и точно в голову, держит цель; без упреждения - в большинстве шутеров Roblox попадание мгновенное
    Hard = {AimTime = 15, AimFov = 260, AimDeadzone = 0, AimLeadOn = false, AimPredict = 0, AimSticky = true, AimHumanize = false,
        AimPart = "Head", AimPriority = "Crosshair"},
    Sniper = {AimTime = 60, AimFov = 70, AimDeadzone = 1, AimLeadOn = true, AimPredict = 0.1, AimSticky = true, AimPart = "Head", AimHumanize = false},
}
function M.F.ApplyAimPreset(id)
    local preset = M.F.AimPresets[id]
    if not preset then return end
    for key, value in pairs(preset) do M.F.SetStateVisual(key, value) end
    M.Data.AimLock = nil
    if M.F.UpdateLeadRows then M.F.UpdateLeadRows() end
end

-- скорость, урон по нам и тряска камеры
function M.F.UpdateCameraExtras(cam, dt, hrp, hum)
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
    if (M.State.ShakeOn or M.Data.ShakeEnergy > 0) and not M.Data.Fc then M.F.ApplyShake(cam, dt) end
end

pcall(function() M.Services.R:UnbindFromRenderStep("CamProcessor") end)
M.Services.R:BindToRenderStep("CamProcessor", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if M.Run.IsShutDown then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local safe = M.F.Safe or function(_, fn, ...) return pcall(fn, ...) end

    local char = M.LP and M.LP.Character
    local hum = char and M.GetHumanoid(char)
    local hrp = char and M.GetRoot(char)
    local isAlive = (hum ~= nil and hum.Health > 0)

    -- свободная камера сама ведёт камеру
    if M.Data.Fc then
        safe("Freecam", M.F.UpdateFreecam, cam, dt)
        safe("CameraExtras", M.F.UpdateCameraExtras, cam, dt, hrp, hum)
        return
    end

    safe("Aim", M.F.UpdateAim, cam, dt, isAlive)
    -- 2. Третье лицо
    safe("ThirdPerson", M.F.UpdateThirdPerson, cam, hrp, hum, M.State.ThirdPerson and isAlive, dt)
    -- 3. Автоматический выстрел
    safe("Trigger", M.F.UpdateTrigger, cam, isAlive)
    -- 4. Скорость, урон по нам и тряска камеры
    safe("CameraExtras", M.F.UpdateCameraExtras, cam, dt, hrp, hum)
    -- итоговая камера после доводки запоминается
    if M.Data.AimStepWrote then
        M.Data.AimStepWrote = false
        M.Data.AimWritten = cam.CFrame
    end
end)

-- страж окружения
function M.F.CursorHeld()
    return M.Run.MenuOpen == true or M.State.SpectateOn == true
end

function M.F.CaptureCursor()
    local D = M.Data
    if D.CursorSaved then return end
    local input = M.Services.U
    local behavior = input.MouseBehavior
    if behavior == Enum.MouseBehavior.LockCurrentPosition then behavior = Enum.MouseBehavior.Default end
    D.CursorSaved = {Behavior = behavior, Icon = input.MouseIconEnabled}
end

function M.F.RestoreCursor()
    local D = M.Data
    local saved = D.CursorSaved
    D.CursorSaved = nil
    if not saved or M.State.RestoreMouse == false then return end
    local input = M.Services.U
    local behavior = saved.Behavior
    -- режим «только первое лицо»
    if behavior == Enum.MouseBehavior.Default then
        pcall(function()
            if M.LP.CameraMode == Enum.CameraMode.LockFirstPerson then behavior = Enum.MouseBehavior.LockCenter end
        end)
    end
    pcall(function() input.MouseBehavior = behavior end)
    pcall(function() input.MouseIconEnabled = saved.Icon end)
end

-- держит курсор свободным
function M.F.ForceFreeCursor()
    if M.F.CameraDragActive() then return end
    M.F.CaptureCursor()
    local input = M.Services.U
    local current = input.MouseBehavior
    if current ~= Enum.MouseBehavior.Default then
        if current ~= Enum.MouseBehavior.LockCurrentPosition and M.Data.CursorSaved then
            M.Data.CursorSaved.Behavior = current
        end
        input.MouseBehavior = Enum.MouseBehavior.Default
    end
    if not input.MouseIconEnabled then
        if M.Data.CursorSaved then M.Data.CursorSaved.Icon = false end
        input.MouseIconEnabled = true
    end
end

-- каждый кадр
function M.F.UpdateCursor()
    if M.F.CursorHeld() then
        M.F.ForceFreeCursor()
    elseif M.Data.CursorSaved then
        M.F.RestoreCursor()
    end
end

function M.F.EnforceCursor()
    if M.F.CursorHeld() then M.F.ForceFreeCursor() end
end

function M.F.GuardEnvironment()
    if M.Run.IsShutDown then return end
    local state = M.State
    local now = os.clock()
    if now - (M.Data.GuardSlow or 0) >= 0.25 then
        M.Data.GuardSlow = now
        if state.SkyOn then M.F.ApplySky(true) end
        if state.CloudsOn then M.F.ApplyClouds() end
    end
    local D = M.Data
    -- выключение тоже доходит сюда, даже если тумблер сменили не кликом
    if state.FogOn or D.FogApplied then M.F.ApplyFog() end
    if state.SunRaysOn then M.F.ApplySunRays() end
    if state.GradeOn then M.F.ApplyGrade() end
    if state.DarkWorld or D.DarkApplied then M.F.ApplyDark() end
    if state.TimeOn or D.TimeApplied then M.F.ApplyTime() end
end

pcall(function() M.Services.R:UnbindFromRenderStep("FovProcessor") end)
M.Services.R:BindToRenderStep("FovProcessor", Enum.RenderPriority.Last.Value, function(dt)
    if M.Run.IsShutDown then return end
    local cam = workspace.CurrentCamera
    local safe = M.F.Safe
    if not safe then return end
    -- каждая часть в своей защите; порядок: доводка сверяется с тем, что записала, потом третье лицо и угол обзора
    if cam then safe("AimReassert", M.F.ReassertAim, cam) end
    if cam then safe("ThirdPersonFinal", M.F.ThirdPersonFinal, cam, dt) end
    if cam then safe("Fov", M.F.UpdateFov, cam, dt) end
    safe("Environment", M.F.GuardEnvironment)
    safe("Cursor", M.F.EnforceCursor)
end)

pcall(function() M.Services.R:UnbindFromRenderStep("PlayerViewFrame") end)
M.Services.R:BindToRenderStep("PlayerViewFrame", Enum.RenderPriority.Last.Value + 1, function(dt)
    if M.Run.IsShutDown or not M.State.PlayerView then return end
    local cam = workspace.CurrentCamera
    -- не чаще 120 раз в секунду: на высоком FPS лишние обновления глазу не видны, а кадр стоят
    local D = M.Data
    local acc = (D.PvAcc or 0) + (dt or 0)
    if acc < 1 / 120 then
        D.PvAcc = acc
        return
    end
    D.PvAcc = math.min(acc - 1 / 120, 1 / 120)
    if cam and M.F.Safe then M.F.Safe("PlayerView", M.F.UpdatePlayerViewFrame, cam) end
end)

-- свой час против часа игры
do
    local L = M.Services.L
    local function holdTime()
        if M.Run.IsShutDown or not M.State.TimeOn then return end
        M.F.ApplyTime()
    end
    table.insert(M.Data.Conns, L:GetPropertyChangedSignal("ClockTime"):Connect(holdTime))
    table.insert(M.Data.Conns, L:GetPropertyChangedSignal("TimeOfDay"):Connect(holdTime))
end

-- удержание клавиши Z для приближения
M.Conn(M.Services.U.InputBegan, function(inp, processed)
    if inp.KeyCode == Enum.KeyCode.Z and not processed then M.Data.ZoomHeld = true end
end)
M.Conn(M.Services.U.InputEnded, function(inp)
    if inp.KeyCode == Enum.KeyCode.Z then M.Data.ZoomHeld = false end
end)

end}

-- [18/69] Боты как цели
MODULES[#MODULES + 1] = {"18. Боты как цели", function(M, __X)
-- ==============================================================================
-- [ БОТЫ КАК ЦЕЛИ ]
-- ==============================================================================
M.Data.NpcMeta = {
    __index = function(t, key)
        local model = rawget(t, "Model")
        if key == "Parent" then return (model.Parent ~= nil) and workspace or nil end
        if key == "Character" then return (model.Parent ~= nil) and model or nil end
        return nil
    end
}
M.Data.NpcSignal = {Connect = function() return {Disconnect = function() end} end}

-- жив ли псевдоигрок как цель
function M.F.NpcActive(p)
    local set = M.Data.Npcs
    return set ~= nil and set[p.Model] == p
end

function M.F.NpcAdd(inst)
    if inst.ClassName ~= "Humanoid" then return end
    local D = M.Data
    local set = D.Npcs
    local model = inst.Parent
    if not set or not model or set[model] or not model:IsA("Model") then return end
    if model == M.LP.Character or M.Services.P:GetPlayerFromCharacter(model) then return end
    local npc = setmetatable({Model = model, Name = model.Name, DisplayName = model.Name, UserId = 0, Neutral = true,
        CharacterAdded = D.NpcSignal}, D.NpcMeta)
    D.NpcPseudo[npc] = true
    set[model] = npc
    D.NpcVersion = D.NpcVersion + 1
end

function M.F.NpcRemove(inst)
    if inst.ClassName ~= "Humanoid" then return end
    local set = M.Data.Npcs
    local model = inst.Parent
    if set and model and set[model] then
        set[model] = nil
        M.Data.NpcVersion = M.Data.NpcVersion + 1
    end
end

-- раз в 2 секунды
function M.F.NpcPurge()
    local D = M.Data
    local set = D.Npcs
    if not set then return end
    local removed = false
    for model in pairs(set) do
        if model.Parent == nil or M.Services.P:GetPlayerFromCharacter(model) or model == M.LP.Character then
            set[model] = nil
            removed = true
        end
    end
    if removed then D.NpcVersion = D.NpcVersion + 1 end
end

M.F.DefineModule("NpcTargets", {
    Wanted = function()
        local S = M.State
        -- эффекты попадания и числа урона тоже видят ботов и манекены
        return S.AimNpcs or S.TriggerNpcs or S.EspNpcs or S.ArrowNpcs or S.HitMarkerOn or S.HitRingsOn or S.DamageNumbers
    end,
    Load = function()
        local D = M.Data
        D.Npcs = {}
        D.NpcVersion = D.NpcVersion + 1
        D.NpcConns = {
            workspace.DescendantAdded:Connect(M.F.NpcAdd),
            workspace.DescendantRemoving:Connect(M.F.NpcRemove),
        }
        -- первый обход карты идёт порциями по времени
        task.spawn(function()
            M.F.SliceWalk(workspace, M.F.NpcAdd, function() return M.Modules.NpcTargets.Loaded end)
        end)
        task.spawn(function()
            while M.Modules.NpcTargets.Loaded and not M.Run.IsShutDown do
                task.wait(2)
                M.F.NpcPurge()
            end
        end)
    end,
    Unload = function()
        local D = M.Data
        for _, conn in ipairs(D.NpcConns or {}) do pcall(function() conn:Disconnect() end) end
        D.NpcConns = nil
        -- оформление ботов
        for p in pairs(M.Data.PlayerViewGuis) do
            if D.NpcPseudo[p] then M.F.RemovePlayerView(p) end
        end
        for p in pairs(M.Data.Highlights) do
            if D.NpcPseudo[p] then M.F.RemovePlayerView(p) end
        end
        D.Npcs, D.Merged = nil, nil
        D.NpcVersion = D.NpcVersion + 1
    end
})

end}

-- [19/69] Рисование поверх экрана
MODULES[#MODULES + 1] = {"19. Рисование поверх экрана", function(M, __X)
local getService = __X.getService
-- ==============================================================================
-- [ РИСОВАНИЕ ПОВЕРХ ЭКРАНА ]
-- ==============================================================================
M.Draw = {Objects = {}, Failures = 0}

-- средство рисования поверх экрана от исполнителя (или nil, если его нет)
function M.Draw.Lib()
    local draw = M.Draw
    if draw.LibChecked then return draw.LibRef end
    draw.LibChecked = true
    local lib
    pcall(function() lib = Drawing end)
    if lib == nil then pcall(function() lib = getgenv().Drawing end) end
    local ok = false
    pcall(function() ok = lib ~= nil and typeof(lib.new) == "function" end)
    draw.LibRef = ok and lib or nil
    return draw.LibRef
end

-- проверка возможностей
function M.Draw.Probe()
    local draw = M.Draw
    if draw.Probed ~= nil then return draw.Probed end
    draw.Probed = false
    draw.Caps = {}
    local lib = draw.Lib()
    if not lib then return false end
    local function test(kind, essential, optional)
        local obj
        if not pcall(function() obj = lib.new(kind) end) or obj == nil then return false, {} end
        local ok, missing = true, {}
        for _, pair in ipairs(essential) do
            if not pcall(function() obj[pair[1]] = pair[2] end) then ok = false end
        end
        for _, pair in ipairs(optional) do
            if not pcall(function() obj[pair[1]] = pair[2] end) then missing[pair[1]] = true end
        end
        pcall(function() obj.Visible = false end)
        if not pcall(function() obj:Remove() end) then pcall(function() obj:Destroy() end) end
        return ok, missing
    end
    local v2, c3 = Vector2.new(0, 0), Color3.new(1, 1, 1)
    local okLine, missLine = test("Line", {{"Visible", false}, {"From", v2}, {"To", v2}, {"Color", c3}, {"Thickness", 1}},
        {{"Transparency", 1}, {"ZIndex", 1}})
    local okSquare, missSquare = test("Square", {{"Visible", false}, {"Position", v2}, {"Size", v2}, {"Color", c3}, {"Thickness", 1}, {"Filled", false}},
        {{"Transparency", 1}, {"ZIndex", 1}})
    local okText, missText = test("Text", {{"Visible", false}, {"Text", "x"}, {"Size", 13}, {"Color", c3}, {"Position", v2}},
        {{"Center", true}, {"Outline", true}, {"OutlineColor", c3}, {"Font", 2}, {"Transparency", 1}, {"ZIndex", 1}})
    local okCircle, missCircle = test("Circle", {{"Visible", false}, {"Position", v2}, {"Radius", 10}, {"Color", c3}, {"Thickness", 1}, {"Filled", false}},
        {{"NumSides", 32}, {"Transparency", 1}})
    if okLine and okSquare and okText and okCircle then
        local caps = draw.Caps
        caps.LineAlpha = not missLine.Transparency
        caps.SquareAlpha = not missSquare.Transparency
        caps.TextAlpha = not missText.Transparency
        caps.CircleAlpha = not missCircle.Transparency
        caps.ZIndex = not (missLine.ZIndex or missSquare.ZIndex or missText.ZIndex)
        caps.TextCenter = not missText.Center
        caps.TextOutline = not (missText.Outline or missText.OutlineColor)
        caps.TextFont = not missText.Font
        caps.CircleSides = not missCircle.NumSides
        draw.Probed = true
    end
    return draw.Probed
end

-- рисовать ли поверх экрана прямо сейчас
function M.Draw.Enabled()
    local draw = M.Draw
    -- после отказов раз в полминуты пробуем снова
    if draw.Probed == false and draw.Failures >= 5 and os.clock() - (draw.FailAt or 0) > 30 then
        draw.Probed, draw.Failures = nil, 0
    end
    return draw.Probe()
end

-- пул рисунков
M.Draw.Pool = {}
M.Draw.Kind = setmetatable({}, {__mode = "k"})
function M.Draw.Set(obj, prop, value) obj[prop] = value end
-- что возвращается к исходному виду у рисунка, взятого из пула
function M.Draw.ResetList(kind)
    local draw = M.Draw
    local cache = draw.ResetCache
    if not cache then cache = {}; draw.ResetCache = cache end
    local list = cache[kind]
    if list then return list end
    local caps = draw.Caps
    if not caps then return {} end
    local white = Color3.new(1, 1, 1)
    list = {}
    local function add(prop, value) list[#list + 1] = {prop, value} end
    if kind == "Line" then
        add("Thickness", 1); add("Color", white)
        if caps.LineAlpha then add("Transparency", 1) end
    elseif kind == "Square" then
        add("Thickness", 1); add("Filled", false); add("Color", white)
        if caps.SquareAlpha then add("Transparency", 1) end
    elseif kind == "Circle" then
        add("Thickness", 1); add("Filled", false); add("Color", white)
        if caps.CircleAlpha then add("Transparency", 1) end
    elseif kind == "Text" then
        add("Size", 13); add("Color", white); add("Text", "")
        if caps.TextCenter then add("Center", false) end
        if caps.TextOutline then add("Outline", false); add("OutlineColor", Color3.new(0, 0, 0)) end
        if caps.TextFont then add("Font", 0) end
        if caps.TextAlpha then add("Transparency", 1) end
    end
    if caps.ZIndex then add("ZIndex", 0) end
    cache[kind] = list
    return list
end
M.Draw.Kinds = {Line = true, Square = true, Circle = true, Text = true}
-- новый рисунок
function M.Draw.New(kind)
    local draw = M.Draw
    local lib = draw.Lib()
    if not lib then return nil end
    local obj
    local pool = draw.Pool[kind]
    if pool and #pool > 0 then
        obj = table.remove(pool)
        draw.PoolUsed = os.clock()
        draw.Reused = (draw.Reused or 0) + 1
        for _, pair in ipairs(draw.ResetList(kind)) do pcall(M.Draw.Set, obj, pair[1], pair[2]) end
    else
        local ok = pcall(function() obj = lib.new(kind) end)
        if not ok or obj == nil then
            -- несколько отказов подряд
            draw.Failures = draw.Failures + 1
            if draw.Failures >= 5 then draw.Probed, draw.FailAt = false, os.clock() end
            return nil
        end
        draw.Created = (draw.Created or 0) + 1
        draw.Failures = 0  -- считаются только отказы подряд
        draw.Kind[obj] = kind
    end
    draw.Objects[obj] = true
    draw.Made = (draw.Made or 0) + 1
    pcall(M.Draw.Set, obj, "Visible", false)
    return obj
end

function M.Draw.Kill(obj)
    if not pcall(function() obj:Remove() end) then pcall(function() obj:Destroy() end) end
end

-- убранный рисунок уходит в пул
function M.Draw.Remove(obj, forceKill)
    if obj == nil then return end
    local draw = M.Draw
    if not draw.Objects[obj] then return end
    draw.Objects[obj] = nil
    local kind = draw.Kind[obj]
    local pool = kind and draw.Pool[kind]
    if kind and not forceKill and draw.Kinds[kind] and not M.Run.IsShutDown then
        if not pool then pool = {}; draw.Pool[kind] = pool end
        if #pool < 300 then
            pcall(M.Draw.Set, obj, "Visible", false)
            pool[#pool + 1] = obj
            draw.PoolUsed = os.clock()
            return
        end
    end
    draw.Kill(obj)
end

-- настоящее удаление всего, что лежит в пуле
function M.Draw.DrainPool()
    local draw = M.Draw
    for kind, pool in pairs(draw.Pool) do
        for i = #pool, 1, -1 do draw.Kill(pool[i]); pool[i] = nil end
    end
end

-- пул, который долго не нужен, освобождается
function M.Draw.TrimPool()
    local draw = M.Draw
    if draw.PoolUsed and os.clock() - draw.PoolUsed > 60 then
        draw.PoolUsed = nil
        draw.DrainPool()
    end
end

function M.Draw.RemoveAll()
    local list = {}
    for obj in pairs(M.Draw.Objects) do list[#list + 1] = obj end
    for _, obj in ipairs(list) do M.Draw.Remove(obj, true) end
    M.Draw.DrainPool()
end
-- запись свойства рисунка только при изменении значения
local function dset(obj, K, key, prop, value)
    -- NaN в рисунок не пишется
    if value ~= value then return end
    if K[key] ~= value then
        K[key] = value
        obj[prop] = value
    end
end

-- то же для Vector2
local function dvec(obj, K, key, prop, x, y)
    if x > 1e6 then x = 1e6 elseif x < -1e6 then x = -1e6 elseif x ~= x then x = (prop == "Size") and 0 or -1e4 end
    if y > 1e6 then y = 1e6 elseif y < -1e6 then y = -1e6 elseif y ~= y then y = (prop == "Size") and 0 or -1e4 end
    local c = K[key]
    if not c then
        K[key] = {x, y}
        obj[prop] = Vector2.new(x, y)
    elseif c[1] ~= x or c[2] ~= y then
        c[1], c[2] = x, y
        obj[prop] = Vector2.new(x, y)
    end
end

-- рисунки не показываются во время заставки и пока открыто меню Roblox
function M.Draw.Blocked()
    if M.Data.IntroActive then return true end
    local gs = M.Data.GuiSvc
    if gs == nil then
        gs = getService("GuiService") or false
        M.Data.GuiSvc = gs
    end
    return gs and gs.MenuIsOpen == true or false
end

-- прямоугольник окна меню в координатах экрана
function M.F.MenuRect()
    local main = M.UI.Main
    if not main or not main.Visible then return nil end
    local rect = M.Data.MenuRectT
    if not rect then
        rect = {0, 0, 0, 0}
        M.Data.MenuRectT = rect
    end
    local pos, size = main.AbsolutePosition, main.AbsoluteSize
    local ox, oy = 0, 0
    local gui = M.UI.Gui
    if gui and not gui.IgnoreGuiInset then
        local gs = M.Data.GuiSvc
        if gs == nil then
            gs = getService("GuiService") or false
            M.Data.GuiSvc = gs
        end
        if gs then
            local inset = gs:GetGuiInset()
            ox, oy = inset.X, inset.Y
        end
    end
    rect[1], rect[2], rect[3], rect[4] = pos.X + ox, pos.Y + oy, pos.X + size.X + ox, pos.Y + size.Y + oy
    return rect
end

__X.dset = dset
__X.dvec = dvec
end}

-- [20/69] Отображение игроков: окно, рамки, скелет, подсветка, покадровый цикл
MODULES[#MODULES + 1] = {"20. Отображение игроков: окно, рамки, скелет, подсветка, покадровый цикл", function(M, __X)
local dset = __X.dset
local dvec = __X.dvec
-- ==============================================================================
-- [ ИНТЕРФЕЙС ОТОБРАЖЕНИЯ ИГРОКОВ ]
-- ==============================================================================
-- этот ScreenGui
function M.F.EnsurePlayerViewGui()
    if M.UI.PlayerViewGui and M.UI.PlayerViewGui.Parent then return end
    if M.UI.PlayerViewGui then pcall(function() M.UI.PlayerViewGui:Destroy() end) end
    M.UI.PlayerViewGui = Instance.new("ScreenGui")
    M.UI.PlayerViewGui.Name = M.Services.H:GenerateGUID(false)
    M.UI.PlayerViewGui.ResetOnSpawn = false
    M.UI.PlayerViewGui.DisplayOrder = 100
    M.UI.PlayerViewGui.IgnoreGuiInset = true
    M.F.GateGui(M.UI.PlayerViewGui)
    M.UI.PlayerViewGui.Parent = M.TargetGui

    M.UI.FovCircle = Instance.new("Frame")
    M.UI.FovCircle.Name = M.Services.H:GenerateGUID(false)
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

-- новая подсветка
function M.F.NewPlayerHighlight(char)
    local hl = Instance.new("Highlight")
    hl.Name = M.Services.H:GenerateGUID(false)
    hl.Enabled = false
    hl.FillColor = M.State.PlayerViewFill
    hl.FillTransparency = M.State.PlayerViewAlpha
    hl.OutlineColor = M.State.PlayerViewLine
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char
    hl.Parent = M.F.HuiFolder()
    return hl
end

-- покадровое отображение игроков
do
local PV_HEAD_UP = Vector3.new(0, 1.4, 0)
local PV_FEET_DOWN = Vector3.new(0, 3.0, 0)
local pvCandidates = {}

local function pvPut(inst, prop, value)
    if inst[prop] ~= value then inst[prop] = value end
end

local function pvByScore(a, b) return a.HlScore < b.HlScore end

-- скелет
local SKEL_R15_JOINTS = {"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
    "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
local SKEL_R15_BONES = {{1, 2}, {2, 3}, {2, 4}, {4, 5}, {5, 6}, {2, 7}, {7, 8}, {8, 9}, {3, 10}, {10, 11}, {11, 12},
    {3, 13}, {13, 14}, {14, 15}}
local SKEL_R6_NAMES = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
local SKEL_R6_BONES = {{1, 2}, {2, 3}, {4, 5}, {6, 7}, {4, 8}, {5, 9}, {6, 10}, {7, 11}}
-- сдвиги от центра Torso
local SKEL_R6_OFFSETS = {Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), Vector3.new(-1, 0.9, 0), Vector3.new(1, 0.9, 0),
    Vector3.new(-0.5, -1, 0), Vector3.new(0.5, -1, 0)}
local SKEL_LIMB_END = Vector3.new(0, -1, 0)
local jW, jX, jY, jZ = {}, {}, {}, {}

local function pvPart(inst)
    if inst and inst:IsA("BasePart") then return inst end
    return false
end

-- собирает мировые точки суставов в jW
local function skelJoints(pack, char)
    if pack.SkelChar ~= char then
        pack.SkelChar, pack.SkelRig, pack.SkelParts = char, nil, nil
    end
    local rig = pack.SkelRig
    if not rig then
        local parts = {}
        if char:FindFirstChild("UpperTorso") then
            rig = "R15"
            for i, name in ipairs(SKEL_R15_JOINTS) do parts[i] = pvPart(char:FindFirstChild(name)) end
        elseif char:FindFirstChild("Torso") then
            rig = "R6"
            for i, name in ipairs(SKEL_R6_NAMES) do parts[i] = pvPart(char:FindFirstChild(name)) end
        else
            return 0
        end
        pack.SkelRig, pack.SkelParts = rig, parts
    end
    local parts = pack.SkelParts
    if rig == "R15" then
        -- на месте ли детали, проверяется раз в полсекунды, а не у каждой детали в каждом кадре
        local now = os.clock()
        local check = now - (pack.SkelChk or 0) > 0.5
        if check then pack.SkelChk = now end
        for i = 1, 15 do
            local part = parts[i]
            if part and (not check or part.Parent) then jW[i] = part.Position
            else
                jW[i] = false
                if part and check then parts[i] = false end
            end
        end
        return 15, SKEL_R15_BONES
    end
    local head, torso = parts[1], parts[2]
    if torso and torso.Parent then
        local cf = torso.CFrame
        for i = 1, 6 do jW[i + 1] = cf * SKEL_R6_OFFSETS[i] end
    else
        for i = 2, 7 do jW[i] = false end
    end
    jW[1] = (head and head.Parent) and head.Position or false
    for i = 1, 4 do
        local part = parts[i + 2]
        jW[7 + i] = (part and part.Parent) and (part.CFrame * SKEL_LIMB_END) or false
    end
    return 11, SKEL_R6_BONES
end

-- убирает с экрана и уничтожает всё оформление игрока
local function pvDisposePack(pack)
    if not pack then return end
    M.F.DestroySkeleton(pack)
    if pack.Sel then pcall(function() pack.Sel:Destroy() end); pack.Sel = nil end
    if pack.Dr then
        for _, obj in ipairs(pack.All) do M.Draw.Remove(obj) end
        pack.All = {}
    else
        if pack.Container then pcall(function() pack.Container:Destroy() end) end
        if pack.PlayerLine then pcall(function() pack.PlayerLine:Destroy() end) end
    end
end

-- оформление игрока из обычных элементов меню
local function pvBuildGuiPack(p, char, isSelf)
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
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

    local barFill = Instance.new("Frame")
    barFill.Name = "HB_FILL"
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

    local hpLbl = Instance.new("TextLabel")
    hpLbl.Name = "HP_TXT"
    hpLbl.BackgroundTransparency = 1
    hpLbl.Font = Enum.Font.GothamBold
    hpLbl.TextSize = M.State.PlayerViewHpTextSize or 11
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

    return {
        Container = boxContainer,
        Stroke = bStroke,
        NameLabel = nameLbl,
        BarBg = barBg,
        BarFill = barFill,
        HpLabel = hpLbl,
        PlayerLine = tracer,
        Char = char,
        Hum = M.GetHumanoid(char),
        IsSelf = isSelf,
        Player = p,
        BaseName = nameLbl.Text
    }
end

-- оформление игрока из рисунков поверх экрана
local function pvBuildDrawPack(p, char, isSelf)
    local S = M.State
    local caps = M.Draw.Caps or {}
    local created = {}
    local function new(kind)
        local obj = M.Draw.New(kind)
        if obj then created[#created + 1] = obj end
        return obj
    end
    -- полоска здоровья скруглённая: толстая линия и круги на концах
    local box, nameT, hpBg, hpFill, hpT, line = new("Square"), new("Text"), new("Line"), new("Line"), new("Text"), new("Line")
    local hpBgC = {new("Circle"), new("Circle")}
    local hpFillC = {new("Circle"), new("Circle")}
    if not (box and nameT and hpBg and hpFill and hpT and line and hpBgC[1] and hpBgC[2] and hpFillC[1] and hpFillC[2]) then
        for _, obj in ipairs(created) do M.Draw.Remove(obj) end
        return nil
    end
    local nameText = (isSelf and M.Translate("PV_You") or "") .. p.DisplayName
    pcall(function()
        box.Filled = false
        box.Thickness = S.PlayerViewBoxThick
        box.Color = S.PlayerViewBoxCol
        for _, c in ipairs({hpBgC[1], hpBgC[2], hpFillC[1], hpFillC[2]}) do
            c.Filled = true
            if caps.CircleSides then c.NumSides = 20 end
        end
        line.Thickness = 1.5
        nameT.Size = S.PlayerViewTextSize
        nameT.Color = S.PlayerViewNameCol
        nameT.Text = nameText
        hpT.Size = S.PlayerViewHpTextSize or 11
        if caps.TextCenter then nameT.Center = true; hpT.Center = true end
        if caps.TextOutline then
            nameT.Outline = true
            nameT.OutlineColor = S.PlayerViewNameOutCol
            hpT.Outline = true
            hpT.OutlineColor = Color3.new(0, 0, 0)
        end
        if caps.TextFont then nameT.Font = 2; hpT.Font = 2 end
        if caps.ZIndex then
            box.ZIndex = 1; line.ZIndex = 1; hpBg.ZIndex = 1; hpBgC[1].ZIndex = 1; hpBgC[2].ZIndex = 1
            hpFill.ZIndex = 2; hpFillC[1].ZIndex = 2; hpFillC[2].ZIndex = 2; nameT.ZIndex = 3; hpT.ZIndex = 3
        end
    end)
    return {
        Dr = true, K = {}, All = created,
        Box = box, NameT = nameT, HpBg = hpBg, HpFill = hpFill, HpBgC = hpBgC, HpFillC = hpFillC, HpT = hpT, Line = line,
        Char = char, Hum = M.GetHumanoid(char), IsSelf = isSelf, Player = p, BaseName = nameText
    }
end

function M.F.SetupPlayerView(p)
    if not p or not p.Parent then return end
    local function initChar(char)
        if not char then return end
        if M.F.CharOf(p) ~= char or not p.Parent or not M.Modules.PlayerView.Loaded then return end
        local isSelf = (p == M.LP)

        local old = M.Data.PlayerViewGuis[p]
        if old then pvDisposePack(old) end
        local hl = M.Data.Highlights[p]
        if hl and hl.Parent then
            hl.Adornee = char
        else
            M.Data.Highlights[p] = M.F.NewPlayerHighlight(char)
        end

        local pack = nil
        if M.Draw.Enabled() then pack = pvBuildDrawPack(p, char, isSelf) end
        if not pack then
            M.F.EnsurePlayerViewGui()
            pack = pvBuildGuiPack(p, char, isSelf)
        end
        pack.HlSlot = old and old.HlSlot
        M.Data.PlayerViewGuis[p] = pack
    end

    local function enqueueInit(char)
        if not char then return end
        local pending = M.Data.PvPending
        if not pending then pending = setmetatable({}, {__mode = "k"}); M.Data.PvPending = pending end
        if pending[p] == char then return end  -- этот персонаж уже ждёт своей очереди
        pending[p] = char
        local queue = M.Data.PvInitQueue
        if not queue then queue = {}; M.Data.PvInitQueue = queue end
        queue[#queue + 1] = {initChar, char, p}
    end
    local current = M.F.CharOf(p)
    if current then enqueueInit(current) end

    if M.Data.PlayerConns[p] then
        M.Data.PlayerConns[p]:Disconnect()
    end
    M.Data.PlayerConns[p] = p.CharacterAdded:Connect(enqueueInit)
end

function M.F.UpdatePlayerView()
    for _, hl in pairs(M.Data.Highlights) do
        if hl and hl.Parent then
            if not M.State.PlayerView then hl.Enabled = false end
            hl.FillColor = M.State.PlayerViewFill
            hl.FillTransparency = M.State.PlayerViewAlpha
            hl.OutlineColor = M.State.PlayerViewLine
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        end
    end

    for _, pack in pairs(M.Data.PlayerViewGuis) do M.F.PvForgetHighlight(pack) end
    for _, pack in pairs(M.Data.PlayerViewGuis) do
        if pack and pack.Container then
            local allowed = M.State.PlayerView and M.F.EspAllows(pack.Player)

            pack.Container.Visible = allowed and (M.State.PlayerViewBox or M.State.PlayerViewHealthBar or M.State.PlayerViewHealthText)
            pack.Stroke.Enabled = M.State.PlayerViewBox
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
end

-- удаляет линии скелета игрока
function M.F.DestroySkeleton(pack)
    if pack and pack.SkelLines then
        for _, line in ipairs(pack.SkelLines) do
            if pack.Dr then
                M.Draw.Remove(line)
            elseif line.Parent then
                line:Destroy()
            end
        end
        pack.SkelLines, pack.SkelShown, pack.SkelK = nil, false, nil
    end
end

-- убирает всё оформление отображения одного игрока
function M.F.RemovePlayerView(p)
    if M.Data.Highlights[p] and M.Data.Highlights[p].Parent then M.Data.Highlights[p]:Destroy() end
    M.Data.Highlights[p] = nil
    local pack = M.Data.PlayerViewGuis[p]
    if pack then pvDisposePack(pack) end
    M.Data.PlayerViewGuis[p] = nil
    if M.Data.PlayerConns[p] then M.Data.PlayerConns[p]:Disconnect(); M.Data.PlayerConns[p] = nil end
end

-- прячет линии скелета
local function pvHideSkeleton(pack)
    local lines = pack.SkelLines
    if lines and pack.SkelShown then
        if pack.Dr then
            local SK = pack.SkelK
            for i = 1, #lines do
                local c = SK and SK[i]
                if c and c.v then
                    c.v = false
                    lines[i].Visible = false
                end
            end
        else
            for _, line in ipairs(lines) do
                if line.Visible then line.Visible = false end
            end
        end
        pack.SkelShown = false
    end
end

-- скелет из элементов меню: каждая кость - повёрнутая полоска
local function pvSkeletonGui(pack, bones, color, thick)
    local lines = pack.SkelLines
    if not lines then lines = {}; pack.SkelLines = lines end
    local nb = #bones
    for b = 1, nb do
        local line = lines[b]
        if not line then
            local made = M.Data.PvNewLines or 0
            if made >= 12 then break end
            M.Data.PvNewLines = made + 1
            line = Instance.new("Frame")
            line.Name = M.Services.H:GenerateGUID(false)
            line.AnchorPoint = Vector2.new(0.5, 0.5)
            line.BorderSizePixel = 0
            line.Visible = false
            line.Parent = M.UI.PlayerViewGui
            lines[b] = line
        end
        local a, c2 = bones[b][1], bones[b][2]
        local za, zb = jZ[a], jZ[c2]
        local show = false
        if za and zb and za > 0.05 and zb > 0.05 then
            local dx, dy = jX[c2] - jX[a], jY[c2] - jY[a]
            local len = math.sqrt(dx * dx + dy * dy)
            if len > 0.5 and len < 5000 then
                show = true
                pvPut(line, "Size", UDim2.fromOffset(len + thick * 0.5, thick))
                pvPut(line, "Position", UDim2.fromOffset((jX[a] + jX[c2]) / 2, (jY[a] + jY[c2]) / 2))
                pvPut(line, "Rotation", math.deg(math.atan2(dy, dx)))
                pvPut(line, "BackgroundColor3", color)
            end
        end
        pvPut(line, "Visible", show)
    end
    for i = nb + 1, #lines do pvPut(lines[i], "Visible", false) end
    pack.SkelShown = true
end

-- скелет из рисунков поверх экрана
local function pvSkeletonDraw(pack, bones, color, thick)
    local lines = pack.SkelLines
    if not lines then lines = {}; pack.SkelLines = lines; pack.SkelK = {} end
    local SK = pack.SkelK
    local caps = M.Draw.Caps
    local nb = #bones
    for b = 1, nb do
        local line = lines[b]
        if not line then
            local made = M.Data.PvNewLines or 0
            if made >= 12 then break end
            M.Data.PvNewLines = made + 1
            line = M.Draw.New("Line")
            if not line then
                pack.SkelBroken = true
                break
            end
            if caps and caps.ZIndex then pcall(function() line.ZIndex = 1 end) end
            lines[b] = line
            SK[b] = {v = false}
        end
        local c = SK[b]
        local a, c2 = bones[b][1], bones[b][2]
        local za, zb = jZ[a], jZ[c2]
        local show = false
        if za and zb and za > 0.05 and zb > 0.05 then
            -- целые пиксели: линия толщиной 1-2 px на полупиксель не меняется, а запись в рисунок дорогая
            local x1, y1 = math.floor(jX[a] + 0.5), math.floor(jY[a] + 0.5)
            local x2, y2 = math.floor(jX[c2] + 0.5), math.floor(jY[c2] + 0.5)
            local dx, dy = x2 - x1, y2 - y1
            if dx * dx + dy * dy > 0.25 then
                show = true
                if c.x1 ~= x1 or c.y1 ~= y1 then c.x1, c.y1 = x1, y1; line.From = Vector2.new(x1, y1) end
                if c.x2 ~= x2 or c.y2 ~= y2 then c.x2, c.y2 = x2, y2; line.To = Vector2.new(x2, y2) end
                if c.col ~= color then c.col = color; line.Color = color end
                if c.th ~= thick then c.th = thick; line.Thickness = thick end
            end
        end
        if c.v ~= show then
            c.v = show
            line.Visible = show
        end
    end
    for i = nb + 1, #lines do
        local c = SK[i]
        if c and c.v then c.v = false; lines[i].Visible = false end
    end
    pack.SkelShown = true
end

local function pvSkeleton(pack, char, cam, color)
    local nJ, bones = skelJoints(pack, char)
    if nJ == 0 then pvHideSkeleton(pack) return end
    for i = 1, nJ do
        local w = jW[i]
        if w then
            jX[i], jY[i], jZ[i] = M.Math.Project(w)
        else
            jZ[i] = false
        end
    end
    -- не все части могли успеть загрузиться
    local valid = 0
    for b = 1, #bones do
        if jZ[bones[b][1]] and jZ[bones[b][2]] then valid = valid + 1 end
    end
    if valid < #bones and os.clock() - (pack.SkelTry or 0) > 1 then
        pack.SkelTry = os.clock()
        pack.SkelRig = nil
    end
    local thick = M.State.SkeletonThick
    if pack.Dr then
        pvSkeletonDraw(pack, bones, color, thick)
    else
        pvSkeletonGui(pack, bones, color, thick)
    end
end

-- полоска со скруглёнными концами: толстая линия от центра одного конца до центра другого и два круга
local PILL_BG = {L = {"hbf", "hbt", "hbw", "hbc", "hbv"}, {"hb1p", "hb1r", "hb1c", "hb1v"}, {"hb2p", "hb2r", "hb2c", "hb2v"}, Last = "hbLast"}
local PILL_FILL = {L = {"hff", "hft", "hfw", "hfc", "hfv"}, {"hf1p", "hf1r", "hf1c", "hf1v"}, {"hf2p", "hf2r", "hf2c", "hf2v"}, Last = "hfLast"}
local PV_BAR_BG = Color3.fromRGB(15, 17, 24)
local function pvPill(K, keys, line, caps2, x, y, w, h, col)
    -- полоска та же, что в прошлом кадре: рисунки не трогаем
    local last = K[keys.Last]
    if last and last[1] == x and last[2] == y and last[3] == w and last[4] == h and last[5] == col then return end
    if not last then last = {}; K[keys.Last] = last end
    last[1], last[2], last[3], last[4], last[5] = x, y, w, h, col
    local r, ax, ay, bx, by
    if w >= h then
        r = h * 0.5
        ax, ay = x + r, y + r
        bx, by = math.max(x + w - r, ax), ay
    else
        -- вертикальная растёт снизу вверх
        r = w * 0.5
        ax, ay = x + r, y + h - r
        bx, by = ax, math.min(y + r, ay)
    end
    local L = keys.L
    dvec(line, K, L[1], "From", ax, ay)
    dvec(line, K, L[2], "To", bx, by)
    dset(line, K, L[3], "Thickness", r * 2)
    dset(line, K, L[4], "Color", col)
    dset(line, K, L[5], "Visible", true)
    for i = 1, 2 do
        local c, ck = caps2[i], keys[i]
        if i == 1 then dvec(c, K, ck[1], "Position", ax, ay) else dvec(c, K, ck[1], "Position", bx, by) end
        dset(c, K, ck[2], "Radius", r)
        dset(c, K, ck[3], "Color", col)
        dset(c, K, ck[4], "Visible", true)
    end
end
local function pvPillHide(K, keys, line, caps2)
    local last = K[keys.Last]
    if last then last[1] = nil end
    dset(line, K, keys.L[5], "Visible", false)
    dset(caps2[1], K, keys[1][4], "Visible", false)
    dset(caps2[2], K, keys[2][4], "Visible", false)
end

-- прячет рамку, имя, полоску здоровья и линию игрока
local function pvHideBox(pack)
    if pack.Dr then
        local K = pack.K
        if K.bv ~= false then K.bv = false; pack.Box.Visible = false end
        if K.nv ~= false then K.nv = false; pack.NameT.Visible = false end
        pvPillHide(K, PILL_BG, pack.HpBg, pack.HpBgC)
        pvPillHide(K, PILL_FILL, pack.HpFill, pack.HpFillC)
        if K.htv ~= false then K.htv = false; pack.HpT.Visible = false end
        if K.lv ~= false then K.lv = false; pack.Line.Visible = false end
    else
        pvPut(pack.Container, "Visible", false)
        if pack.PlayerLine then pvPut(pack.PlayerLine, "Visible", false) end
    end
end

-- прячет всё оформление игрока, кроме подсветки
local function pvHideAll(pack)
    pvHideBox(pack)
    pvHideSkeleton(pack)
    local sel = pack.Sel
    if sel and sel.Adornee ~= nil then sel.Adornee = nil end
end

-- рамка-запас
-- то, что записано в рамку, помнится у себя: каждый кадр чтения у движка не нужны
function M.F.HighlightFallback(pack, char, want, color)
    local sel = pack.Sel
    if not want then
        if sel and pack.SelAdornee ~= nil then
            sel.Adornee = nil
            pack.SelAdornee = nil
        end
        return
    end
    if not sel or not sel.Parent then
        sel = Instance.new("SelectionBox")
        sel.Name = M.Services.H:GenerateGUID(false)
        sel.LineThickness = 0.04
        sel.SurfaceTransparency = 1
        sel.Parent = M.F.HuiFolder()
        pack.Sel, pack.SelAdornee, pack.SelColor = sel, nil, nil
    end
    if pack.SelAdornee ~= char then
        sel.Adornee = char
        pack.SelAdornee = char
    end
    if pack.SelColor ~= color then
        sel.Color3 = color
        pack.SelColor = color
    end
end

function M.F.HidePlayerPack(pack)
    if pack then pvHideAll(pack) end
end

-- цвет заливки подсветки по режиму «Цвет подсветки»
function M.F.HighlightColor(p, pack, char, head, S)
    local mode = S.PlayerViewHlMode
    if mode == "Team" then
        local team = p.Team
        if team then return p.TeamColor.Color end
    elseif mode == "Wall" then
        local now = os.clock()
        if now - (pack.VisAt or 0) > 0.12 then
            pack.VisAt = now
            pack.VisOk = M.TargetVisibility(head, char)
        end
        if pack.VisOk == false then return S.PlayerViewHiddenFill end
    end
    return S.PlayerViewFill
end

-- подсветка не зависит от того, помещается ли 2D-рамка на экран
local function pvSetHighlight(p, char, on, fillColor, pack)
    local hl = M.Data.Highlights[p]
    -- быстрый путь: подсветка проверялась недавно, движок трогаем только при изменении
    local now = M.Data.PvNow or 0
    if pack and hl and pack.HlObj == hl and now - (pack.HlCheck or -1) < 0.5 then
        if not on then
            if pack.HlOn then pack.HlOn = false; hl.Enabled = false end
            return
        end
        if pack.HlOn and pack.HlChar == char then
            if pack.HlFill ~= fillColor then pack.HlFill = fillColor; hl.FillColor = fillColor end
            return
        end
    end
    if pack then pack.HlCheck = now end
    if not on then
        if hl and hl.Parent and hl.Enabled then hl.Enabled = false end
        if pack then pack.HlObj, pack.HlOn = hl, false end
        return
    end
    if not hl or not hl.Parent then
        hl = M.F.NewPlayerHighlight(char)
        M.Data.Highlights[p] = hl
    else
        -- папку подсветок отцепили
        local folder = M.F.HuiFolder()
        if hl.Parent ~= folder then hl.Parent = folder end
    end
    if hl.Adornee ~= char then hl.Adornee = char end
    if not hl.Enabled then hl.Enabled = true end
    M.F.SetProp(hl, "FillColor", fillColor)
    if pack then pack.HlObj, pack.HlOn, pack.HlChar, pack.HlFill = hl, true, char, fillColor end
end

-- после смены подсветки снаружи кэш пакета сбрасывается
function M.F.PvForgetHighlight(pack)
    if pack then pack.HlCheck = nil end
end

-- рамка, имя, здоровье и линия из элементов меню
local function pvApplyGui(pack, S, left, top, boxWidth, boxHeight, hpPercent, hpColor, curHp, camPos, rootWorld, rootPos, vSize, isSelf)
    pvPut(pack.Container, "Visible", S.PlayerViewBox or S.PlayerViewHealthBar or S.PlayerViewHealthText)
    pvPut(pack.Container, "Position", UDim2.fromOffset(math.floor(left), math.floor(top)))
    pvPut(pack.Container, "Size", UDim2.fromOffset(math.floor(boxWidth), math.floor(boxHeight)))
    pvPut(pack.Stroke, "Enabled", S.PlayerViewBox)

    local tSize = S.PlayerViewHealthBarThick
    pvPut(pack.BarBg, "Visible", S.PlayerViewHealthBar)
    pvPut(pack.HpLabel, "Visible", S.PlayerViewHealthText)

    if S.PlayerViewHealthPos == "Bottom" then
        pvPut(pack.BarBg, "Size", UDim2.new(1, 0, 0, tSize))
        pvPut(pack.BarBg, "Position", UDim2.new(0, 0, 1, 4))
        pvPut(pack.BarFill, "Size", UDim2.new(hpPercent, 0, 1, 0))
        pvPut(pack.BarFill, "Position", UDim2.new(0, 0, 0, 0))
        pvPut(pack.HpLabel, "AnchorPoint", Vector2.new(0.5, 0))
        pvPut(pack.HpLabel, "Position", UDim2.new(0.5, 0, 1, tSize + 4))
        pvPut(pack.HpLabel, "TextXAlignment", Enum.TextXAlignment.Center)
    elseif S.PlayerViewHealthPos == "Right" then
        pvPut(pack.BarBg, "Size", UDim2.new(0, tSize, 1, 0))
        pvPut(pack.BarBg, "Position", UDim2.new(1, 4, 0, 0))
        pvPut(pack.BarFill, "Size", UDim2.new(1, 0, hpPercent, 0))
        pvPut(pack.BarFill, "Position", UDim2.new(0, 0, 1 - hpPercent, 0))
        pvPut(pack.HpLabel, "AnchorPoint", Vector2.new(0, 0.5))
        pvPut(pack.HpLabel, "Position", UDim2.new(1, tSize + 6, 1 - hpPercent, 0))
        pvPut(pack.HpLabel, "TextXAlignment", Enum.TextXAlignment.Left)
    else
        pvPut(pack.BarBg, "Size", UDim2.new(0, tSize, 1, 0))
        pvPut(pack.BarBg, "Position", UDim2.new(0, -(tSize + 4), 0, 0))
        pvPut(pack.BarFill, "Size", UDim2.new(1, 0, hpPercent, 0))
        pvPut(pack.BarFill, "Position", UDim2.new(0, 0, 1 - hpPercent, 0))
        pvPut(pack.HpLabel, "AnchorPoint", Vector2.new(1, 0.5))
        pvPut(pack.HpLabel, "Position", UDim2.new(0, -(tSize + 6), 1 - hpPercent, 0))
        pvPut(pack.HpLabel, "TextXAlignment", Enum.TextXAlignment.Right)
    end

    pvPut(pack.BarFill, "BackgroundColor3", hpColor)
    local hpInt = math.floor(curHp)
    if pack.LastHp ~= hpInt then pack.LastHp = hpInt; pack.HpLabel.Text = hpInt .. " HP" end
    pvPut(pack.HpLabel, "TextColor3", hpColor)
    pvPut(pack.HpLabel, "TextSize", S.PlayerViewHpTextSize or 11)

    -- дистанция в имени
    local wantedName = pack.BaseName
    if S.PlayerViewDistance then
        local dist = math.floor((camPos - rootWorld).Magnitude)
        if pack.LastDist ~= dist then
            pack.LastDist = dist
            pack.DistText = pack.BaseName .. string.format("  [%d%s]", dist, M.Translate("Unit_m"))
        end
        wantedName = pack.DistText
    end
    if pack.NameLabel.Text ~= wantedName then pack.NameLabel.Text = wantedName end

    local line = pack.PlayerLine
    if line then
        if S.PlayerViewLines and not isSelf then
            local startX, startY = vSize.X / 2, vSize.Y
            local dx, dy = rootPos.X - startX, rootPos.Y - startY
            pvPut(line, "Visible", true)
            pvPut(line, "Size", UDim2.new(0, math.sqrt(dx * dx + dy * dy), 0, 1.5))
            pvPut(line, "Position", UDim2.fromOffset((startX + rootPos.X) / 2, (startY + rootPos.Y) / 2))
            pvPut(line, "Rotation", math.deg(math.atan2(dy, dx)))
            pvPut(line, "BackgroundColor3", S.PlayerLineCol)
        else
            pvPut(line, "Visible", false)
        end
    end
end

-- рамка, имя, здоровье и линия из рисунков поверх экрана
local function pvApplyDraw(pack, S, left, top, boxWidth, boxHeight, hpPercent, hpColor, curHp, camPos, rootWorld, rootPos, vSize, isSelf, menuRect)
    local K = pack.K
    local x, y = math.floor(left + 0.5), math.floor(top + 0.5)
    local w, h = math.floor(boxWidth + 0.5), math.floor(boxHeight + 0.5)
    local caps = M.Draw.Caps
    local showBox, showBar, showTxt = S.PlayerViewBox, S.PlayerViewHealthBar, S.PlayerViewHealthText
    local showAny = showBox or showBar or showTxt

    -- рамка
    local box = pack.Box
    if showBox then
        dvec(box, K, "bp", "Position", x, y)
        dvec(box, K, "bs", "Size", w, h)
        dset(box, K, "bc", "Color", S.PlayerViewBoxCol)
        dset(box, K, "bt", "Thickness", S.PlayerViewBoxThick)
    end
    dset(box, K, "bv", "Visible", showBox and true or false)

    local nameT = pack.NameT
    if showAny then
        local wanted = pack.BaseName
        if S.PlayerViewDistance then
            local dist = math.floor((camPos - rootWorld).Magnitude)
            if pack.LastDist ~= dist then
                pack.LastDist = dist
                pack.DistText = pack.BaseName .. string.format("  [%d%s]", dist, M.Translate("Unit_m"))
            end
            wanted = pack.DistText
        end
        local size = S.PlayerViewTextSize
        dset(nameT, K, "nt", "Text", wanted)
        dset(nameT, K, "ns", "Size", size)
        dset(nameT, K, "nc", "Color", S.PlayerViewNameCol)
        if caps.TextOutline then dset(nameT, K, "noc", "OutlineColor", S.PlayerViewNameOutCol) end
        local nx = x + math.floor(w / 2)
        if not caps.TextCenter then nx = nx - math.floor(#wanted * size * 0.27) end
        dvec(nameT, K, "np", "Position", nx, y - 4 - size - 2)
    end
    dset(nameT, K, "nv", "Visible", showAny and true or false)

    -- полоска здоровья и цифры
    local hpBg, hpFill, hpT = pack.HpBg, pack.HpFill, pack.HpT
    if showBar or showTxt then
        local tSize = S.PlayerViewHealthBarThick
        local mode = S.PlayerViewHealthPos
        local bgx, bgy, bgw, bgh, fx, fy, fw, fh
        if mode == "Bottom" then
            bgx, bgy, bgw, bgh = x, y + h + 4, w, tSize
            fx, fy, fw, fh = bgx, bgy, math.floor(w * hpPercent + 0.5), tSize
        elseif mode == "Right" then
            bgx, bgy, bgw, bgh = x + w + 4, y, tSize, h
            fh = math.floor(h * hpPercent + 0.5)
            fx, fy, fw = bgx, y + h - fh, tSize
        else
            bgx, bgy, bgw, bgh = x - tSize - 4, y, tSize, h
            fh = math.floor(h * hpPercent + 0.5)
            fx, fy, fw = bgx, y + h - fh, tSize
        end
        if showBar then
            -- подложка на пиксель шире: тёмная кайма вокруг заливки
            pvPill(K, PILL_BG, hpBg, pack.HpBgC, bgx - 1, bgy - 1, bgw + 2, bgh + 2, PV_BAR_BG)
            if fw > 0 and fh > 0 then
                pvPill(K, PILL_FILL, hpFill, pack.HpFillC, fx, fy, fw, fh, hpColor)
            else
                pvPillHide(K, PILL_FILL, hpFill, pack.HpFillC)
            end
        else
            pvPillHide(K, PILL_BG, hpBg, pack.HpBgC)
            pvPillHide(K, PILL_FILL, hpFill, pack.HpFillC)
        end
        if showTxt then
            local hpInt = math.floor(curHp)
            if pack.LastHp ~= hpInt then pack.LastHp = hpInt; pack.HpStr = (hpInt >= 1e7 and "INF" or hpInt) .. " HP" end
            local str = pack.HpStr
            local ts = S.PlayerViewHpTextSize or 11
            dset(hpT, K, "ht", "Text", str)
            dset(hpT, K, "hc", "Color", hpColor)
            dset(hpT, K, "hs", "Size", ts)
            local half = math.floor(#str * ts * 0.27)
            local tx, ty
            if mode == "Bottom" then
                tx, ty = x + math.floor(w / 2), bgy + tSize + 2
            elseif mode == "Right" then
                tx, ty = bgx + tSize + 4 + half, fy - math.floor(ts * 0.55)
            else
                tx, ty = bgx - 4 - half, fy - math.floor(ts * 0.55)
            end
            if not caps.TextCenter then tx = tx - half end
            dvec(hpT, K, "hp", "Position", tx, ty)
        end
    else
        pvPillHide(K, PILL_BG, hpBg, pack.HpBgC)
        pvPillHide(K, PILL_FILL, hpFill, pack.HpFillC)
    end
    dset(hpT, K, "htv", "Visible", showTxt and true or false)

    -- линия от низа экрана до игрока
    local line = pack.Line
    if S.PlayerViewLines and not isSelf and not menuRect then
        dvec(line, K, "lf", "From", math.floor(vSize.X / 2), math.floor(vSize.Y))
        dvec(line, K, "lt", "To", math.floor(rootPos.X + 0.5), math.floor(rootPos.Y + 0.5))
        dset(line, K, "lc", "Color", S.PlayerLineCol)
        dset(line, K, "lv", "Visible", true)
    else
        dset(line, K, "lv", "Visible", false)
    end
end

-- один игрок за кадр
local function pvStep(p, pack, cam, camPos, vSize, S, menuRect)
    pack.BoxH = nil
    if not pack.Gi then
        M.Data.PvGi = (M.Data.PvGi or 0) + 1
        pack.Gi = M.Data.PvGi
    end
    local t_char = M.F.CharOf(p)
    if not t_char or not t_char.Parent then
        pvHideAll(pack)
        pvSetHighlight(p, nil, false, nil, pack)
        return
    end

    local nowPv = M.Data.PvNow
    local hum, r, head = pack.Hum, pack.Root, pack.Head
    -- модель без Humanoid тоже годится: здоровье и «жив ли» берутся из модели
    if not r or not head or r.Parent == nil or nowPv - (pack.RefAt or 0) > 0.5 then
        pack.RefAt = nowPv
        if not hum or not hum.Parent or not hum:IsDescendantOf(t_char) then
            hum = M.GetHumanoid(t_char)
            pack.Hum = hum
        end
        r = M.GetRoot(t_char)
        head = M.GetHead(t_char) or r
        pack.Root, pack.Head = r, head
        pack.MaxHp = hum and hum.MaxHealth or 100
    end

    local isSelf = pack.IsSelf
    local allowed = pack.Allowed
    if allowed == nil or nowPv - (pack.AllowAt or 0) > 0.25 then
        pack.AllowAt = nowPv
        allowed = M.F.EspAllows(p)
        pack.Allowed = allowed
    end

    local health, healthMax, aliveNow = M.F.CharVitals(t_char, hum)
    if not allowed or not r or not head or not aliveNow then
        pvHideAll(pack)
        pvSetHighlight(p, nil, false, nil, pack)
        return
    end

    local maxHp = healthMax or pack.MaxHp or 100
    local hpPercent = M.Math.HpFraction(health, maxHp)
    -- число здоровья
    local curHp
    if health ~= health then curHp = 0
    elseif health == math.huge or maxHp == math.huge then curHp = 1e9
    else curHp = math.clamp(health, 0, math.max(maxHp, 1)) end
    local hpColor = S.PlayerViewHealthColor and M.Math.HealthColor(hpPercent) or S.PlayerViewHealthCol

    local rootWorld = r.Position
    -- положение NaN или бесконечность
    if not M.F.FiniteVec(rootWorld) then
        pvHideAll(pack)
        pvSetHighlight(p, nil, false, nil, pack)
        return
    end
    -- дальность прорисовки
    if not isSelf and (camPos - rootWorld).Magnitude > S.PlayerViewMaxDist then
        pvHideAll(pack)
        pvSetHighlight(p, nil, false, nil, pack)
        return
    end
    pack.SpRoot = pack.SpRoot or {}
    local rootPos = M.Math.ProjectInto(pack.SpRoot, rootWorld)
    local onScreen = rootPos.Z > 0 and rootPos.X >= 0 and rootPos.X <= vSize.X and rootPos.Y >= 0 and rootPos.Y <= vSize.Y
    pack.HlScore = (onScreen and 0 or 1e6) + (camPos - rootWorld).Magnitude
    pvCandidates[#pvCandidates + 1] = pack
    local slot = pack.HlSlot
    if slot == nil then slot = (M.Data.PvCandCount or 0) < M.F.HlLimit() end
    -- вне экрана подсветку не видно, а видеокарта её всё равно рисует: такие выключаем (с запасом у краёв)
    local inView = (camPos - rootWorld).Magnitude < 25 or (rootPos.Z > 0 and rootPos.X > -vSize.X * 0.25 and rootPos.X < vSize.X * 1.25
        and rootPos.Y > -vSize.Y * 0.35 and rootPos.Y < vSize.Y * 1.35)
    -- выключение подсветки с задержкой: на краю экрана она не мигает при каждом повороте камеры (включение дорогое)
    if inView then
        pack.HlSeenAt = nowPv
    elseif pack.HlSeenAt and nowPv - pack.HlSeenAt < 0.6 then
        inView = true
    end
    local fillColor
    if slot and inView then fillColor = S.PlayerViewHealthColor and hpColor or M.F.HighlightColor(p, pack, t_char, head, S) end
    local okHl = pcall(pvSetHighlight, p, t_char, slot and inView, fillColor, pack)
    local wantSel = S.PlayerViewHlFallback and inView and ((not slot) or not okHl)
    if wantSel or pack.Sel then
        pcall(M.F.HighlightFallback, pack, t_char, wantSel,
            S.PlayerViewHealthColor and hpColor or S.PlayerViewFill)
    end

    -- за спиной у камеры ни рамки, ни скелета нет
    if rootPos.Z <= 0.05 then
        pvHideBox(pack)
        pvHideSkeleton(pack)
        return
    end

    -- вблизи рамка по двум проекциям (точно при взгляде сверху), дальше 60 студов по одной: разницы не видно, а проекции дорогие
    local headPos = head.Position
    local far = rootPos.Z > 60
    local topScreen, bottomScreen
    if not far then
        pack.SpTop = pack.SpTop or {}
        pack.SpBot = pack.SpBot or {}
        topScreen = M.Math.ProjectInto(pack.SpTop, headPos + PV_HEAD_UP)
        bottomScreen = M.Math.ProjectInto(pack.SpBot, rootWorld - PV_FEET_DOWN)
    end
    local top, boxHeight
    if not far and topScreen.Z > 0.05 and bottomScreen.Z > 0.05 then
        top = math.min(topScreen.Y, bottomScreen.Y)
        boxHeight = math.abs(bottomScreen.Y - topScreen.Y)
    else
        local topWorldY = headPos.Y + PV_HEAD_UP.Y
        local worldHeight = math.max(topWorldY - (rootWorld.Y - PV_FEET_DOWN.Y), 1)
        local pixelsPerStud = vSize.Y / (2 * rootPos.Z * (M.Data.PvTanHalf or 0.7))
        boxHeight = worldHeight * pixelsPerStud
        top = rootPos.Y - boxHeight * math.clamp((topWorldY - rootWorld.Y) / worldHeight, 0, 1)
    end
    boxHeight = math.min(boxHeight, 6000)
    -- сглаживание высоты: покачивание головы в анимации не дёргает рамку, резкие изменения проходят сразу
    local sm = pack.SmH
    if sm and math.abs(boxHeight - sm) < sm * 0.12 then
        local center = top + boxHeight * 0.5
        sm = sm + (boxHeight - sm) * 0.35
        top, boxHeight = center - sm * 0.5, sm
    end
    pack.SmH = boxHeight
    pack.BoxH = boxHeight
    local boxWidth = boxHeight * 0.62
    local left = rootPos.X - boxWidth / 2

    if menuRect and left - 70 < menuRect[3] and left + boxWidth + 70 > menuRect[1]
        and top - 26 < menuRect[4] and top + boxHeight + 34 > menuRect[2] then
        pvHideBox(pack)
        pvHideSkeleton(pack)
        return
    end

    -- у совсем маленькой фигуры скелет не разглядеть, а линий на нём 14: рисуем от 40 пикселей роста
    -- маленькая фигура (ниже 100 px) обновляет скелет через кадр рамок: на таком размере разницы не видно
    local skelSkip = boxHeight < 100 and pack.SkelShown and (M.Data.PvFrame + (pack.Gi or 0)) % 2 == 1
    if S.PlayerViewSkeleton and boxHeight >= (M.Data.Gov.Level >= 2 and 90 or 40) and rootPos.X > -300 and rootPos.X < vSize.X + 300
        and rootPos.Y > -300 and rootPos.Y < vSize.Y + 300 then
        if not pack.SkelBroken and not skelSkip then
            local okSkel = pcall(pvSkeleton, pack, t_char, cam, S.SkeletonHealthColor and M.Math.HealthColor(hpPercent) or S.SkeletonCol)
            if not okSkel then
                pack.SkelBroken = true
                pcall(pvHideSkeleton, pack)
            end
        end
    else
        pvHideSkeleton(pack)
    end

    if boxHeight <= 4 or left > vSize.X or left + boxWidth < 0 or top > vSize.Y or top + boxHeight < 0 then
        pvHideBox(pack)
        return
    end

    if pack.Dr then
        pvApplyDraw(pack, S, left, top, boxWidth, boxHeight, hpPercent, hpColor, curHp, camPos, rootWorld, rootPos, vSize, isSelf, menuRect)
    else
        pvApplyGui(pack, S, left, top, boxWidth, boxHeight, hpPercent, hpColor, curHp, camPos, rootWorld, rootPos, vSize, isSelf)
    end
end

-- покадровое обновление отображения всех игроков
function M.F.UpdatePlayerViewFrame(cam)
    local S = M.State
    M.Math.ProjBegin(cam)
    local useDraw = M.Draw.Enabled()
    -- окно рамок нужно только запасному варианту
    if not useDraw then M.F.EnsurePlayerViewGui() end
    local gui = M.UI.PlayerViewGui
    local vSize = cam.ViewportSize
    local camPos = cam.CFrame.Position
    -- drawing
    local blocked, menuRect = false, nil
    if useDraw then
        blocked = M.Draw.Blocked()
        if not blocked then menuRect = M.F.MenuRect() end
    end
    table.clear(pvCandidates)
    M.Data.PvNewLines = 0
    local initQueue = M.Data.PvInitQueue
    if initQueue and #initQueue > 0 then
        local pending = M.Data.PvPending
        local n = 0
        while #initQueue > 0 and n < 3 and (n == 0 or M.Draw.MadeThisFrame() < 8) do
            local job = table.remove(initQueue, 1)
            if pending and pending[job[3]] == job[2] then pending[job[3]] = nil end
            pcall(job[1], job[2])
            n = n + 1
        end
    end
    local nowSweep = os.clock()
    if nowSweep - (M.Data.PvSweepAt or 0) >= 0.5 then
        M.Data.PvSweepAt = nowSweep
        local pending = M.Data.PvPending
        for _, plr in ipairs(M.F.Players()) do
            local char = M.F.CharOf(plr)
            if char and char.Parent and plr.Parent and (S.EspNpcs or not M.Data.NpcPseudo[plr]) then
                local existing = M.Data.PlayerViewGuis[plr]
                if (not existing or existing.Char ~= char) and not (pending and pending[plr] == char) then
                    M.F.SetupPlayerView(plr)
                end
            end
        end
    end
    M.Data.PvFrame = (M.Data.PvFrame or 0) + 1
    M.Data.PvNow = os.clock()
    -- общее для всех рамок кадра: угол обзора читается один раз
    M.Data.PvTanHalf = math.tan(math.rad(cam.FieldOfView) / 2)
    local govLevel, pvFrame = M.Data.Gov.Level, M.Data.PvFrame
    -- далёкие игроки обновляются реже только под нагрузкой, иначе рамки дёргаются при повороте камеры
    local govSmall, govEvery = 0, 1
    if govLevel >= 2 then govSmall, govEvery = 140, 2 end
    if govLevel >= 3 then govSmall, govEvery = 220, 3 end
    for p, pack in pairs(M.Data.PlayerViewGuis) do
        if pack.Dr and not blocked and (pack.BoxH or 0) < govSmall
            and (pvFrame + (pack.Gi or 0)) % govEvery ~= 0 and p.Parent then
            -- далёкий или мелкий игрок обновляется реже
        elseif not p.Parent or (M.Data.NpcPseudo[p] and (not M.F.NpcActive(p) or not S.EspNpcs)) then
            -- игрок вышел
            M.F.RemovePlayerView(p)
        elseif pack.Dr then
            if blocked then
                pcall(pvHideAll, pack)
            elseif not pcall(pvStep, p, pack, cam, camPos, vSize, S, menuRect) then
                pcall(pvHideAll, pack)
            end
        elseif pack.Container.Parent ~= gui then
            -- окно рамок удалили
            if not pack.Rebuilding then
                pack.Rebuilding = true
                M.F.SetupPlayerView(p)
            end
        elseif not pcall(pvStep, p, pack, cam, camPos, vSize, S, nil) then
            pcall(pvHideAll, pack)
        end
    end
    local now = os.clock()
    if now - (M.Data.PvPickAt or 0) >= 0.25 then
        M.Data.PvPickAt = now
        local limit = M.F.HlLimit()
        if #pvCandidates > limit then table.sort(pvCandidates, pvByScore) end
        for i, pack in ipairs(pvCandidates) do pack.HlSlot = (i <= limit) end
        M.Data.PvCandCount = #pvCandidates
    end
    table.clear(pvCandidates)
end
end

-- круг области доводки: линия цвета обводки и полупрозрачная заливка того же цвета внутри
function M.F.UpdateFovCircle(cam)
    local S, D = M.State, M.Data
    local want = S.ShowFov and S.AimAssist
    -- круг не нужен
    if not want and D.FovDraw ~= nil then
        if D.FovDraw then M.Draw.Remove(D.FovDraw) end
        if D.FovFillDraw then M.Draw.Remove(D.FovFillDraw) end
        D.FovDraw, D.FovFillDraw, D.FovK, D.FovFK = nil, nil, nil, nil
    end
    local drawing = want and M.Draw.Enabled()
    local circle = D.FovDraw
    if drawing and circle == nil then
        circle = M.Draw.New("Circle") or false
        if circle then
            local caps = M.Draw.Caps
            pcall(function()
                circle.Filled = false
                circle.Thickness = 1
                circle.Color = Color3.new(1, 1, 1)
                if caps.CircleSides then circle.NumSides = 64 end
                if caps.CircleAlpha then circle.Transparency = 0.3 end
                if caps.ZIndex then circle.ZIndex = 2 end
            end)
            D.FovK = {}
            -- заливка отдельным кругом под линией
            local fill = M.Draw.New("Circle")
            if fill then
                pcall(function()
                    fill.Filled = true
                    fill.Thickness = 1
                    fill.Color = Color3.new(1, 1, 1)
                    if caps.CircleSides then fill.NumSides = 64 end
                    if caps.ZIndex then fill.ZIndex = 1 end
                end)
                D.FovFillDraw, D.FovFK = fill, {}
            end
        end
        D.FovDraw = circle
    end
    if circle then
        -- круг из рисунков поверх экрана
        local show = drawing and not M.Draw.Blocked()
        local fill, fk = D.FovFillDraw, D.FovFK
        if show then
            local rx, ry = M.F.AimRef(cam)
            local rect = M.F.MenuRect()
            local radius = math.floor(M.F.AimRadius() * 2 + 0.5) / 2
            if rect and rx - radius < rect[3] and rx + radius > rect[1] and ry - radius < rect[4] and ry + radius > rect[2] then
                show = false
            else
                local K = D.FovK
                local px, py = math.floor(rx + 0.5), math.floor(ry + 0.5)
                dvec(circle, K, "p", "Position", px, py)
                dset(circle, K, "r", "Radius", radius)
                local locked = D.AimLock ~= nil
                local col = locked and S.FovLockCol or S.FovCol
                dset(circle, K, "c", "Color", col)
                dset(circle, K, "t", "Thickness", S.FovThick)
                if M.Draw.Caps.CircleAlpha then dset(circle, K, "a", "Transparency", locked and 0.75 or 0.45) end
                if fill then
                    local fillOn = S.FovFillOn and M.Draw.Caps.CircleAlpha
                    if fillOn then
                        dvec(fill, fk, "p", "Position", px, py)
                        dset(fill, fk, "r", "Radius", radius)
                        dset(fill, fk, "c", "Color", col)
                        -- прозрачность 0.9 - это 10% непрозрачности; шагами по 1/40
                        local opacity = (1 - math.clamp(M.Math.Finite(S.FovFillAlpha, 0.9), 0.5, 0.99)) * (locked and 1.6 or 1)
                        dset(fill, fk, "a", "Transparency", math.floor(math.min(opacity, 0.9) * 40 + 0.5) / 40)
                    end
                    dset(fill, fk, "v", "Visible", fillOn and true or false)
                end
            end
        end
        dset(circle, D.FovK, "v", "Visible", show and true or false)
        if fill and not show then dset(fill, fk, "v", "Visible", false) end
        if drawing then
            local gc = M.UI.FovCircle
            if gc and gc.Visible then gc.Visible = false end
            return
        end
    end
    if want and not (drawing and circle) then
        M.F.EnsurePlayerViewGui()
        -- свойства пишутся, только если изменились
        local gc = M.UI.FovCircle
        local rx, ry = M.F.AimRef(cam)
        local radius = M.F.AimRadius()
        local size = UDim2.fromOffset(radius * 2, radius * 2)
        local pos = UDim2.fromOffset(rx, ry)
        if not gc.Visible then gc.Visible = true end
        if gc.Size ~= size then gc.Size = size end
        if gc.Position ~= pos then gc.Position = pos end
        local locked = D.AimLock ~= nil
        local stroke = M.UI.FovStroke
        local col = locked and S.FovLockCol or S.FovCol
        M.F.SetProp(stroke, "Color", col)
        M.F.SetProp(stroke, "Thickness", S.FovThick)
        M.F.SetProp(stroke, "Transparency", locked and 0.25 or 0.55)
        M.F.SetProp(gc, "BackgroundColor3", col)
        M.F.SetProp(gc, "BackgroundTransparency", S.FovFillOn and math.clamp(M.Math.Finite(S.FovFillAlpha, 0.9), 0.5, 0.99) or 1)
    elseif M.UI.FovCircle and M.UI.FovCircle.Visible then
        M.UI.FovCircle.Visible = false
    end
end
end}

-- [21/69] Метка цели, модуль отображения игроков, осадки
MODULES[#MODULES + 1] = {"21. Метка цели, модуль отображения игроков, осадки", function(M, __X)
local dset = __X.dset
local dvec = __X.dvec
-- ==============================================================================
-- [ МЕТКА ЗАХВАЧЕННОЙ ЦЕЛИ ]
-- ==============================================================================
function M.F.BuildAimMarker(useDraw)
    if useDraw then
        local caps = M.Draw.Caps or {}
        local created = {}
        local function new(kind)
            local obj = M.Draw.New(kind)
            if obj then created[#created + 1] = obj end
            return obj
        end
        local line, ring, text = new("Line"), new("Circle"), new("Text")
        if ring and line and text then
            pcall(function()
                ring.Filled = false
                ring.Thickness = 2
                if caps.CircleSides then ring.NumSides = 48 end
                if caps.CircleAlpha then ring.Transparency = 0.9 end
                line.Thickness = 1.5
                if caps.LineAlpha then line.Transparency = 0.5 end
                text.Size = 13
                text.Color = Color3.new(1, 1, 1)
                if caps.TextCenter then text.Center = true end
                if caps.TextOutline then text.Outline = true; text.OutlineColor = Color3.new(0, 0, 0) end
                if caps.TextFont then text.Font = 2 end
                if caps.ZIndex then line.ZIndex = 1; ring.ZIndex = 2; text.ZIndex = 3 end
            end)
            return {Dr = true, K = {}, All = created, Ring = ring, Line = line, Text = text}
        end
        for _, obj in ipairs(created) do M.Draw.Remove(obj) end
    end
    M.F.EnsurePlayerViewGui()
    local parent = M.UI.PlayerViewGui
    local ring = Instance.new("Frame")
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.BackgroundTransparency = 1
    ring.BorderSizePixel = 0
    ring.Visible = false
    Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", ring)
    stroke.Thickness = 2
    stroke.Transparency = 0.1
    ring.Parent = parent
    local line = Instance.new("Frame")
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.BorderSizePixel = 0
    line.BackgroundTransparency = 0.5
    line.Visible = false
    line.Parent = parent
    local text = Instance.new("TextLabel")
    text.AnchorPoint = Vector2.new(0.5, 1)
    text.Size = UDim2.fromOffset(260, 16)
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBold
    text.TextSize = 13
    text.TextColor3 = Color3.new(1, 1, 1)
    text.TextStrokeTransparency = 0.3
    text.Visible = false
    text.Parent = parent
    return {Dr = false, Ring = ring, Stroke = stroke, Line = line, Text = text}
end

function M.F.DisposeAimMarker()
    local mk = M.Data.AimMarker
    local o = mk and mk.Obj
    if not o then return end
    mk.Obj = nil
    if o.Dr then
        for _, obj in ipairs(o.All) do M.Draw.Remove(obj) end
    else
        pcall(function() o.Ring:Destroy() end)
        pcall(function() o.Line:Destroy() end)
        pcall(function() o.Text:Destroy() end)
    end
end

function M.F.UpdateAimMarker(cam)
    local D, S = M.Data, M.State
    local mk = D.AimMarker
    if not mk then return end
    local useDraw = M.Draw.Enabled()
    local part, char = D.AimLock, D.AimLockChar
    local show = part ~= nil and part.Parent ~= nil and char ~= nil and S.AimAssist and not M.Run.MenuOpen
    local o = mk.Obj
    if o and o.Backend ~= useDraw then
        M.F.DisposeAimMarker()
        o = nil
    end
    if not o then
        if not show then return end
        o = M.F.BuildAimMarker(useDraw)
        o.Backend = useDraw
        mk.Obj = o
    end

    local x, y, r, rx, ry, label, sp
    if show then
        sp = cam:WorldToViewportPoint(part.Position)
        show = sp.Z > 0
    end
    if show then
        x, y = sp.X, sp.Y
        -- размер кольца: по размеру детали на экране
        local pixelsPerStud = cam.ViewportSize.Y / (2 * sp.Z * math.tan(math.rad(cam.FieldOfView) / 2))
        r = math.clamp(math.max(part.Size.X, part.Size.Y) * pixelsPerStud * 0.75 + 6, 12, 90)
        rx, ry = M.F.AimRef(cam)
        -- подпись
        if mk.Char ~= char then
            mk.Char = char
            local plr = M.Services.P:GetPlayerFromCharacter(char)
            mk.Name = plr and plr.DisplayName or char.Name
            mk.LastKey = nil
        end
        local hum = M.GetHumanoid(char)
        local dist = math.floor((part.Position - cam.CFrame.Position).Magnitude + 0.5)
        local hpNow, hpMax = M.F.CharHealth(char, hum)
        local hp = math.floor(M.Math.HpFraction(hpNow, hpMax) * 100 + 0.5)
        local key = dist * 1000 + hp
        if mk.LastKey ~= key then
            mk.LastKey = key
            mk.Label = string.format("%s  %d%s  %d%%", mk.Name, dist, M.Translate("Unit_m"), hp)
        end
        label = mk.Label
        -- рисунки поверх экрана лежат выше окон
        if o.Dr then
            if M.Draw.Blocked() then
                show = false
            else
                local rect = M.F.MenuRect()
                if rect and x + r + 20 > rect[1] and x - r - 20 < rect[3] and y + r + 20 > rect[2] and y - r - 40 < rect[4] then show = false end
            end
        end
    end

    local col = S.FovLockCol
    -- линия идёт от прицела до края кольца
    local lineOn, ex, ey, lineLen, ang = false, 0, 0, 0, 0
    if show then
        local dx, dy = x - rx, y - ry
        lineLen = math.sqrt(dx * dx + dy * dy)
        if lineLen > r + 4 then
            lineOn = true
            ex, ey = x - dx / lineLen * r, y - dy / lineLen * r
            ang = math.atan2(dy, dx)
        end
    end

    if o.Dr then
        local K = o.K
        if show then
            dvec(o.Ring, K, "rp", "Position", math.floor(x + 0.5), math.floor(y + 0.5))
            dset(o.Ring, K, "rr", "Radius", math.floor(r + 0.5))
            dset(o.Ring, K, "rc", "Color", col)
            if lineOn then
                dvec(o.Line, K, "lf", "From", math.floor(rx + 0.5), math.floor(ry + 0.5))
                dvec(o.Line, K, "lt", "To", math.floor(ex + 0.5), math.floor(ey + 0.5))
                dset(o.Line, K, "lc", "Color", col)
            end
            dset(o.Text, K, "tt", "Text", label)
            local tx = math.floor(x + 0.5)
            if not (M.Draw.Caps and M.Draw.Caps.TextCenter) then tx = tx - math.floor(#label * 3.4) end
            dvec(o.Text, K, "tp", "Position", tx, math.floor(y - r - 18 + 0.5))
        end
        dset(o.Ring, K, "rv", "Visible", show and true or false)
        dset(o.Line, K, "lv", "Visible", lineOn)
        dset(o.Text, K, "tv", "Visible", show and true or false)
    else
        local ring, line, text = o.Ring, o.Line, o.Text
        if show then
            local d = math.floor(r * 2 + 0.5)
            ring.Size = UDim2.fromOffset(d, d)
            ring.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
            M.F.SetProp(o.Stroke, "Color", col)
            if text.Text ~= label then text.Text = label end
            text.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y - r - 4 + 0.5))
            if lineOn then
                line.Size = UDim2.fromOffset(math.floor(lineLen - r + 0.5), 2)
                line.Position = UDim2.fromOffset(math.floor((rx + ex) / 2 + 0.5), math.floor((ry + ey) / 2 + 0.5))
                line.Rotation = math.deg(ang)
                M.F.SetProp(line, "BackgroundColor3", col)
            end
        end
        if ring.Visible ~= show then ring.Visible = show end
        if line.Visible ~= lineOn then line.Visible = lineOn end
        if text.Visible ~= show then text.Visible = show end
    end
end

M.F.DefineModule("AimMarker", {
    Wanted = function() return M.State.AimAssist and M.State.AimShowTarget end,
    Load = function()
        M.Data.AimMarker = {}
        pcall(function() M.Services.R:UnbindFromRenderStep("AimMarkerFrame") end)
        M.Services.R:BindToRenderStep("AimMarkerFrame", Enum.RenderPriority.Last.Value + 3, function()
            if M.Run.IsShutDown then return end
            local cam = workspace.CurrentCamera
            if cam then M.F.Safe("AimMarker", M.F.UpdateAimMarker, cam) end
        end)
    end,
    Unload = function()
        pcall(function() M.Services.R:UnbindFromRenderStep("AimMarkerFrame") end)
        M.F.DisposeAimMarker()
        M.Data.AimMarker = nil
    end
})

-- отображение игроков не создаёт ничего
M.F.DefineModule("PlayerView", {
    Wanted = function() return M.State.PlayerView end,
    Load = function()
        task.spawn(function()
            for i, p in ipairs(M.Services.P:GetPlayers()) do
                if not M.Modules.PlayerView.Loaded then return end
                M.F.SetupPlayerView(p)
                -- по две рамки за кадр: у каждой с круглой полоской 10 рисунков
                if i % 2 == 0 then task.wait() end
            end
        end)
        table.insert(M.Data.PlayerViewConns, M.Services.P.PlayerAdded:Connect(function(p)
            if M.Modules.PlayerView.Loaded then M.F.SetupPlayerView(p) end
        end))
        table.insert(M.Data.PlayerViewConns, M.Services.P.PlayerRemoving:Connect(M.F.RemovePlayerView))
    end,
    Unload = function()
        for _, conn in ipairs(M.Data.PlayerViewConns) do conn:Disconnect() end
        M.Data.PlayerViewConns = {}
        M.Data.PvInitQueue, M.Data.PvPending = nil, nil
        local players = {}
        for p in pairs(M.Data.Highlights) do players[p] = true end
        for p in pairs(M.Data.PlayerViewGuis) do players[p] = true end
        for p in pairs(M.Data.PlayerConns) do players[p] = true end
        for p in pairs(players) do M.F.RemovePlayerView(p) end
    end
})

-- область осадков
function M.F.WeatherView(cam)
    local D = M.Data
    local look = cam.CFrame.LookVector
    local fx, fz = look.X, look.Z
    local flat = math.sqrt(fx * fx + fz * fz)
    if flat < 0.05 then
        fx, fz = D.WViewFX or 0, D.WViewFZ or -1
    else
        fx, fz = fx / flat, fz / flat
        D.WViewFX, D.WViewFZ = fx, fz
    end
    local fovHalf = math.rad(math.clamp(cam.FieldOfView, 1, 120)) / 2
    local vp = cam.ViewportSize
    local aspect = vp.Y > 0 and vp.X / vp.Y or 1.78
    local pitch = math.asin(math.clamp(look.Y, -1, 1))
    if math.abs(pitch) + fovHalf >= math.pi / 2 - 0.05 then return fx, fz, math.pi end
    local half = math.atan(math.tan(fovHalf) * aspect / math.max(flat, 0.1))
    return fx, fz, half + 0.35
end

-- случайная точка клина
function M.F.WeatherSpawnXZ(cx, cz, fx, fz, half, radius)
    local a
    if half >= math.pi then a = math.random() * math.pi * 2
    else a = math.atan2(fz, fx) + (math.random() * 2 - 1) * half end
    local rad = 4 + math.sqrt(math.random()) * (radius - 4)
    return cx + math.cos(a) * rad, cz + math.sin(a) * rad
end

-- пол под частицей: луч идёт от уровня персонажа вниз, поэтому крыши и потолки над вами осадки пролетают насквозь,
-- а невидимые и проходимые детали не считаются
-- Записи стареют по одной, а не все разом: иначе все частицы в один кадр искали бы пол,
-- а новых лучей за кадр не больше бюджета: остальные частицы берут последний найденный пол
function M.F.WeatherGround(x, z, refY)
    local D = M.Data
    local now = os.clock()
    local cache = D.WGroundCache
    if not cache then
        cache = {}
        D.WGroundCache, D.WGroundN = cache, 0
    end
    local key = (math.floor(x / 4) * 65536 + math.floor(z / 4)) * 64 + (math.floor(refY / 16) % 64)
    local e = cache[key]
    if e and now - e[2] < 6 then return e[1] end
    -- бюджет выставляет кадр осадков; вне его (прямой вызов) ограничения нет
    if D.WGroundBudget ~= nil and D.WGroundBudget <= 0 then
        if e then return e[1] end
        return D.WGroundLast or (refY - 3.5)
    end
    if D.WGroundBudget then D.WGroundBudget = D.WGroundBudget - 1 end
    local ok, hit = pcall(M.F.RaycastMapRaw, Vector3.new(x, refY + 2, z), Vector3.new(0, -300, 0))
    local y = (ok and hit) and hit.Position.Y or (refY - 300)
    if ok and hit then D.WGroundLast = y end
    if not e then
        -- кэш не растёт без конца
        D.WGroundN = D.WGroundN + 1
        if D.WGroundN > 1500 then
            table.clear(cache)
            D.WGroundN = 1
        end
        e = {y, now}
        cache[key] = e
    else
        e[1], e[2] = y, now
    end
    return y
end

-- положение частицы осадков или листа (для проверок)
function M.F.WeatherPos(it)
    return Vector3.new(it.X, it.Y, it.Z)
end

function M.F.ClearWeatherProps()
    M.F.ClearSplashPool()
    M.Data.WGroundCache, M.Data.WGroundN = nil, 0
    for _, item in ipairs(M.Data.WeatherPool) do if item.Part then item.Part:Destroy() end end
    M.Data.WeatherPool = {}
    if M.Data.WMoveParts then table.clear(M.Data.WMoveParts); table.clear(M.Data.WMoveCFs) end
end

function M.F.UpdateWeatherProps(dt)
    if not M.State.WeatherOn or M.State.WeatherMode == "Leaves" then
        if #M.Data.WeatherPool > 0 then M.F.ClearWeatherProps() end
        return
    end

    local cam = workspace.CurrentCamera
    local char = M.LP and M.LP.Character
    local root = char and M.GetRoot(char)
    local origin = (cam and cam.CFrame.Position) or (root and root.Position)
    if not origin then return end
    -- уровень, от которого ищется пол: голова персонажа, а не камера (от третьего лица она высоко)
    local refY = root and (root.Position.Y + 3) or origin.Y
    M.Data.WGroundBudget = 12

    local center = origin
    local viewFX, viewFZ, viewHalf = 0, -1, math.pi
    if cam then viewFX, viewFZ, viewHalf = M.F.WeatherView(cam) end
    local quality = M.Data.Quality * M.F.VisualK()
    local targetCount = math.max(math.floor(M.State.WeatherDensity * quality), 1)
    local radiusBound = math.clamp(M.State.WeatherRadius, 15, 2000)

    if #M.Data.WeatherPool < targetCount then
        -- не больше 10 новых частиц за кадр: создание объектов дорогое
        for _ = 1, math.min(targetCount - #M.Data.WeatherPool, 10) do
            local p = Instance.new("Part")
            p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
            p.Anchored = true; p.Material = Enum.Material.Neon; p.Parent = M.F.Folder("wFolder")

            local sx, sz = M.F.WeatherSpawnXZ(center.X, center.Z, viewFX, viewFZ, viewHalf, radiusBound)
            local pos = Vector3.new(sx, center.Y + math.random(40, 85), sz)
            local ground = M.F.WeatherGround(pos.X, pos.Z, refY)
            pos = Vector3.new(pos.X, math.max(pos.Y, math.max(ground, refY - 6) + math.random(40, 70)), pos.Z)
            p.Position = pos
            table.insert(M.Data.WeatherPool, {Part = p, X = pos.X, Y = pos.Y, Z = pos.Z, Seed = math.random() * 10, Ground = ground,
                SizeK = 0.7 + math.random() * 0.6, Flake = math.random() < 0.35})
        end
    elseif #M.Data.WeatherPool > targetCount * 2 + 20 then
        -- при просадке частицы не удаляются сразу, а ждут спрятанными: когда нагрузка спадёт, их не придётся создавать заново
        for _ = 1, math.min(#M.Data.WeatherPool - (targetCount * 2 + 20), 5) do
            local item = table.remove(M.Data.WeatherPool)
            if item and item.Part then item.Part:Destroy() end
        end
    end

    local isSnow = (M.State.WeatherMode == "Snow")
    local fallSpd = isSnow and (5 * (0.5 + M.State.WeatherSpeed / 60)) or (M.State.WeatherSpeed * 2.0 + 60)
    -- "Подпись" внешнего вида
    local D = M.Data
    local fallKey = math.floor(fallSpd)
    if D.WSigSnow ~= isSnow or D.WSigSize ~= M.State.SnowSize or D.WSigColor ~= M.State.WeatherColor or D.WSigFall ~= fallKey then
        D.WSigSnow, D.WSigSize, D.WSigColor, D.WSigFall = isSnow, M.State.SnowSize, M.State.WeatherColor, fallKey
        D.WSigVer = (D.WSigVer or 0) + 1
    end
    local visualSig = D.WSigVer
    -- все частицы двигаются одним вызовом
    local moveParts = D.WMoveParts or {}
    local moveCFs = D.WMoveCFs or {}
    D.WMoveParts, D.WMoveCFs = moveParts, moveCFs
    local moveN = 0
    -- бюджет брызг растёт с радиусом
    local splashBudget = math.max(math.floor(math.clamp(math.floor(radiusBound / 50) + 2, 3, 6) * quality), 1)
    local camPos = cam and cam.CFrame.Position or origin
    local pool = M.Data.WeatherPool
    local centerX, centerZ = center.X, center.Z
    local radiusSq = radiusBound * radiusBound
    local fall = fallSpd * dt
    local now = os.clock()
    local splashOn = (not isSnow) and M.State.WeatherSplash
    local defaultGround = refY - 300
    local viewAll = viewHalf >= math.pi
    local cosT = viewAll and -1 or math.cos(viewHalf + 0.07)
    local cosSq = cosT * cosT
    local viewBudget = math.max(25, math.floor(#pool / 5))
    for i = 1, #pool do
        local it = pool[i]
        local p = it.Part
        if i > targetCount then
            -- лишняя частица спрятана и не двигается
            if not it.Parked and p and p.Parent then
                it.Parked = true
                p.Transparency = 1
            end
        elseif it.Parked then
            it.Parked = false
            it.Sig = nil  -- вид восстановится ниже в следующем кадре
        end
        if i <= targetCount and p and p.Parent then
            -- положение хранится тремя числами: новый Vector3 на каждую частицу в каждом кадре не нужен
            local ix, iy, iz = it.X, it.Y, it.Z
            local px, py, pz, drawX, drawZ, tumble
            if isSnow then
                if not it.Fall then
                    it.Fall = 0.7 + math.random() * 0.6  -- своя скорость падения
                    it.Amp = 0.5 + math.random() * 0.9  -- размах покачивания, студы
                    it.Freq = 0.7 + math.random() * 0.7  -- частота покачивания
                    it.DriftX = (math.random() - 0.5) * 0.8  -- снос ветром, студы в секунду
                    it.DriftZ = (math.random() - 0.5) * 0.8
                end
                px, py, pz = ix + it.DriftX * dt, iy - fall * it.Fall, iz + it.DriftZ * dt
                local t = now * it.Freq + it.Seed
                drawX = px + math.sin(t) * it.Amp
                drawZ = pz + math.cos(t * 0.8 + it.Seed) * it.Amp
                if it.Flake then tumble = t end
            else
                px, py, pz = ix, iy - fall, iz
                drawX, drawZ = px, pz
            end
            it.X, it.Y, it.Z = px, py, pz
            if it.Sig ~= visualSig then
                it.Sig = visualSig
                p.Color = M.State.WeatherColor
                p.Material = Enum.Material.Neon
                if isSnow then
                    local s = M.State.SnowSize * (it.SizeK or 1)
                    if it.Flake then
                        -- снежинка: тонкий неоновый диск, кувыркается в полёте
                        p.Shape = Enum.PartType.Cylinder
                        p.Size = Vector3.new(0.06, s * 1.7, s * 1.7)
                    else
                        p.Shape = Enum.PartType.Ball
                        p.Size = Vector3.new(s, s, s)
                    end
                    p.Transparency = 0.15
                else
                    p.Shape = Enum.PartType.Block
                    p.Size = Vector3.new(0.08, math.clamp(fallSpd * 0.03, 1.2, 3.2), 0.08)
                    p.Transparency = 0.25
                end
            end
            moveN = moveN + 1
            moveParts[moveN] = p
            if tumble then
                moveCFs[moveN] = CFrame.new(drawX, py, drawZ) * CFrame.Angles(tumble * 1.3, tumble * 0.9, 0)
            else
                moveCFs[moveN] = CFrame.new(drawX, py, drawZ)
            end

            local ground = it.Ground or defaultGround
            local landed = py <= ground
            if landed and splashOn and splashBudget > 0 and math.random() < 0.35 then
                splashBudget = splashBudget - 1
                M.F.SpawnSplash(Vector3.new(px, ground, pz), camPos)
            end
            local offX, offZ = px - centerX, pz - centerZ
            local d2 = offX * offX + offZ * offZ
            local outView = false
            if not viewAll and d2 > 36 then
                local dot = offX * viewFX + offZ * viewFZ
                if cosT >= 0 then outView = dot < 0 or dot * dot < cosSq * d2
                else outView = dot < 0 and dot * dot > cosSq * d2 end
            end
            local recycle = outView and not landed and d2 <= radiusSq
            if landed or d2 > radiusSq or (recycle and viewBudget > 0) then
                -- sqrt даёт равномерную плотность по площади
                local x, z = M.F.WeatherSpawnXZ(centerX, centerZ, viewFX, viewFZ, viewHalf, radiusBound)
                local newGround = M.F.WeatherGround(x, z, refY)
                it.Ground = newGround
                -- высота появления считается от пола, но не ниже уровня персонажа: под полом без опоры частицы не рождаются
                local base = math.max(newGround, refY - 6)
                if recycle then
                    -- перенос из-за поворота камеры
                    viewBudget = viewBudget - 1
                    it.X, it.Y, it.Z = x, base + 1 + math.random() * math.max(center.Y + 80 - base, 35), z
                else
                    it.X, it.Y, it.Z = x, math.max(center.Y + math.random(50, 85), base + math.random(40, 70)), z
                end
            end
        end
    end
    for i = #moveParts, moveN + 1, -1 do moveParts[i] = nil; moveCFs[i] = nil end
    if moveN > 0 then workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged) end
end

end}

-- [22/69] Отладка зоны доводки: подпись у каждого врага рядом с зоной
MODULES[#MODULES + 1] = {"22. Отладка зоны доводки", function(M, __X)
local dset, dvec = __X.dset, __X.dvec
do
local AD = {Step = M.Services.H:GenerateGUID(false), Texts = {}}
local COLORS = {
    AimWhy_Chosen = Color3.fromRGB(90, 235, 120), AimWhy_Ok = Color3.fromRGB(255, 255, 255), AimWhy_Wall = Color3.fromRGB(255, 210, 70),
    AimWhy_Zone = Color3.fromRGB(170, 170, 185), AimWhy_Team = Color3.fromRGB(80, 220, 255), AimWhy_Far = Color3.fromRGB(255, 150, 60),
}

local function newText()
    local obj = M.Draw.New("Text")
    if not obj then return nil end
    local caps = M.Draw.Caps or {}
    pcall(function()
        obj.Size = 13
        if caps.TextCenter then obj.Center = true end
        if caps.TextOutline then obj.Outline = true; obj.OutlineColor = Color3.new(0, 0, 0) end
        if caps.TextFont then obj.Font = 2 end
    end)
    return {Obj = obj, K = {}}
end

function AD.hideFrom(from)
    for i = from, #AD.Texts do
        local t = AD.Texts[i]
        dset(t.Obj, t.K, "v", "Visible", false)
    end
end

function AD.frame()
    local D = M.Data
    local why, cam = D.AimWhy, workspace.CurrentCamera
    if not why or not cam or not M.Draw.Enabled() or M.Draw.Blocked() or os.clock() - (D.AimWhyAt or 0) > 0.3 then
        AD.hideFrom(1)
        if AD.ZoneText then dset(AD.ZoneText.Obj, AD.ZoneText.K, "v", "Visible", false) end
        return
    end
    M.Math.ProjBegin(cam)
    -- первая строка: радиус зоны, который сейчас реально используется для захвата
    local zr = D.AimDynRadius or M.State.AimFov
    local zt = AD.ZoneText
    if not zt then
        zt = newText()
        AD.ZoneText = zt
    end
    if zt then
        local rx, ry = M.F.AimRef(cam)
        local state = M.State.AimDynamic and M.Translate("AimSt_" .. (D.AimDynState or "Stand")) or "-"
        dset(zt.Obj, zt.K, "t", "Text", string.format(M.Translate("AimZone_Info"), math.floor(zr + 0.5), M.State.AimDynamic and (D.AimDynMul or 1) or 1, state))
        dset(zt.Obj, zt.K, "c", "Color", Color3.fromRGB(255, 255, 255))
        dvec(zt.Obj, zt.K, "p", "Position", math.floor(rx + 0.5), math.floor(ry + zr + 8))
        dset(zt.Obj, zt.K, "v", "Visible", true)
    end
    local i = 0
    for char, info in pairs(why) do
        if char.Parent and info.Dist < info.Limit * 2.5 then
            local anchor = M.GetHead(char) or M.GetRoot(char)
            if anchor then
                local x, y, z = M.Math.Project(anchor.Position)
                if z > 0 and M.Math.OnScreen(x, y, z) then
                    i = i + 1
                    if i > 8 then break end
                    local t = AD.Texts[i]
                    if not t then
                        t = newText()
                        if not t then return end
                        AD.Texts[i] = t
                    end
                    local distText = info.Dist < 1e5 and math.floor(info.Dist + 0.5) or "-"
                    dset(t.Obj, t.K, "t", "Text", M.Translate(info.Key) .. "  " .. distText .. "/" .. math.floor(info.Limit + 0.5))
                    dset(t.Obj, t.K, "c", "Color", COLORS[info.Key] or COLORS.AimWhy_Ok)
                    dvec(t.Obj, t.K, "p", "Position", math.floor(x + 0.5), math.floor(y + 26))
                    dset(t.Obj, t.K, "v", "Visible", true)
                end
            end
        end
    end
    AD.hideFrom(i + 1)
end

M.F.DefineModule("AimDebug", {
    Wanted = function() return M.State.AimDebug and M.State.AimAssist end,
    Load = function()
        pcall(function() M.Services.R:UnbindFromRenderStep(AD.Step) end)
        M.Services.R:BindToRenderStep(AD.Step, Enum.RenderPriority.Last.Value + 7, function()
            if M.Run.IsShutDown then return end
            M.F.Safe("AimDebug", AD.frame)
        end)
    end,
    Unload = function()
        pcall(function() M.Services.R:UnbindFromRenderStep(AD.Step) end)
        for _, t in ipairs(AD.Texts) do M.Draw.Remove(t.Obj) end
        AD.Texts = {}
        if AD.ZoneText then M.Draw.Remove(AD.ZoneText.Obj); AD.ZoneText = nil end
        M.Data.AimWhy = nil
    end
})
end

end}

-- [23/69] Лучи света и взрыв метеорита
MODULES[#MODULES + 1] = {"23. Лучи света и взрыв метеорита", function(M, __X)
-- ==============================================================================
-- [ ЛУЧИ СВЕТА И МЕТЕОРИТЫ ]
-- ==============================================================================

-- лучи солнца/луны как в RTX
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
            local fxOn = M.F.VisualLevel() < 2
            M.F.SetProp(bloom, "Enabled", fxOn)
            M.F.SetProp(rays, "Enabled", fxOn)
        else
            if rays then rays:Destroy() end
            if bloom then bloom:Destroy() end
            M.Data.FxSunRays, M.Data.FxRayBloom = nil, nil
        end
    end)
end

-- взрыв в месте падения метеорита
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
    -- цилиндр лежит вдоль оси X
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

end}

-- [24/69] Брызги, листья, молнии, метеориты
MODULES[#MODULES + 1] = {"24. Брызги, листья, молнии, метеориты", function(M, __X)
-- ==============================================================================
-- [ БРЫЗГИ И ЛИСТЬЯ ]
-- ==============================================================================

-- брызги дождя
function M.F.SpawnSplash(position, viewerPos)
    -- не больше 160 колец одновременно
    local D = M.Data
    if (D.SplashLive or 0) >= 160 then return end
    D.SplashLive = (D.SplashLive or 0) + 1

    local dist = viewerPos and (position - viewerPos).Magnitude or 0
    local startSize = 0.4 + dist * 0.012
    local endSize = 2.4 + dist * 0.06
    local thick = 0.04 + dist * 0.002

    -- кольца переиспользуются
    local pool = D.SplashPool
    if not pool then pool = {}; D.SplashPool = pool end
    local ring
    while #pool > 0 do
        local candidate = table.remove(pool)
        if candidate.Parent then ring = candidate break end
    end
    if not ring then
        ring = Instance.new("Part")
        ring.Name = M.Services.H:GenerateGUID(false)
        ring.Shape = Enum.PartType.Cylinder
        ring.Material = Enum.Material.Neon
        ring.Anchored = true
        ring.CanCollide = false; ring.CanQuery = false; ring.CanTouch = false; ring.CastShadow = false
    end
    ring.Size = Vector3.new(thick, startSize, startSize)
    ring.Color = M.State.WeatherColor
    ring.Transparency = 0.35
    ring.CFrame = CFrame.new(position + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2)
    ring.Parent = M.F.Folder("wFolder")
    M.Services.T:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = Vector3.new(thick, endSize, endSize), Transparency = 1}):Play()

    task.delay(0.5, function()
        D.SplashLive = math.max((D.SplashLive or 1) - 1, 0)
        if not ring.Parent then return end
        -- кольцо уже невидимо
        local live = D.SplashPool
        if live and #live < 64 and M.State.WeatherOn and not M.Run.IsShutDown then
            live[#live + 1] = ring
        else
            ring:Destroy()
        end
    end)
end

function M.F.ClearSplashPool()
    local pool = M.Data.SplashPool
    M.Data.SplashPool = nil
    if pool then
        for _, ring in ipairs(pool) do pcall(function() ring:Destroy() end) end
    end
end

-- осенние листья
local LEAF_COLORS = {Color3.fromRGB(214, 120, 30), Color3.fromRGB(190, 60, 30), Color3.fromRGB(230, 170, 40),
    Color3.fromRGB(150, 90, 40), Color3.fromRGB(170, 130, 30)}

function M.F.ClearLeaves()
    local list = M.Data.Leaves
    M.Data.Leaves = nil
    M.Data.LeafParts, M.Data.LeafCFs = nil, nil
    if list then
        for _, leaf in ipairs(list) do if leaf.Part then leaf.Part:Destroy() end end
    end
end

function M.F.UpdateLeaves(dt)
    local D, S = M.Data, M.State
    if not (S.WeatherOn and S.WeatherMode == "Leaves") then
        if D.Leaves then M.F.ClearLeaves() end
        return
    end
    local cam = workspace.CurrentCamera
    local char = M.LP and M.LP.Character
    local root = char and M.GetRoot(char)
    local origin = (cam and cam.CFrame.Position) or (root and root.Position)
    if not origin then return end
    local viewFX, viewFZ, viewHalf = 0, -1, math.pi
    if cam then viewFX, viewFZ, viewHalf = M.F.WeatherView(cam) end
    D.Leaves = D.Leaves or {}
    local list = D.Leaves
    -- листья
    local radius = math.clamp(S.WeatherRadius, 15, 220)
    local count = math.clamp(math.floor(S.WeatherDensity * D.Quality), 1, 120)
    local size = math.clamp(S.SnowSize * 1.5, 0.3, 4)
    local fallScale = 0.5 + S.WeatherSpeed / 60

    -- не больше 10 новых листьев за кадр
    for _ = 1, math.min(count - #list, 10) do
        local part = Instance.new("Part")
        part.Name = M.Services.H:GenerateGUID(false)
        part.Material = Enum.Material.SmoothPlastic
        part.Color = LEAF_COLORS[math.random(#LEAF_COLORS)]
        part.Anchored = true
        part.CanCollide = false; part.CanQuery = false; part.CanTouch = false; part.CastShadow = false
        part.Parent = M.F.Folder("wFolder")
        local sx, sz = M.F.WeatherSpawnXZ(origin.X, origin.Z, viewFX, viewFZ, viewHalf, radius)
        list[#list + 1] = {Part = part, X = sx, Y = origin.Y + math.random(3, 40), Z = sz,
            Seed = math.random() * 10, Fall = 3 + math.random() * 4}
    end
    for _ = 1, math.min(#list - count, 20) do
        local leaf = table.remove(list)
        if leaf.Part then leaf.Part:Destroy() end
    end

    local now = os.clock()
    local parts, cfs = D.LeafParts, D.LeafCFs
    if not parts then parts, cfs = {}, {}; D.LeafParts, D.LeafCFs = parts, cfs end
    local n = 0
    local ox, oy, oz = origin.X, origin.Y, origin.Z
    local radiusSq = radius * radius
    local base = now * 1.4
    local move = 1.6 * dt
    -- вне клина обзора листья переносятся в него
    local viewAll = viewHalf >= math.pi
    local cosT = viewAll and -1 or math.cos(viewHalf + 0.07)
    local cosSq = cosT * cosT
    local viewBudget = math.max(10, math.floor(#list / 5))
    for _, leaf in ipairs(list) do
        local t = base + leaf.Seed
        local x = leaf.X + math.sin(t) * move
        local y = leaf.Y - leaf.Fall * fallScale * dt
        local z = leaf.Z + math.cos(t * 0.8) * move
        local fx, fz = x - ox, z - oz
        local d2 = fx * fx + fz * fz
        local outView = false
        if not viewAll and d2 > 36 then
            local dot = fx * viewFX + fz * viewFZ
            if cosT >= 0 then outView = dot < 0 or dot * dot < cosSq * d2
            else outView = dot < 0 and dot * dot > cosSq * d2 end
        end
        local fell = y < oy - 3
        local recycle = outView and not fell and d2 <= radiusSq
        if fell or d2 > radiusSq or (recycle and viewBudget > 0) then
            x, z = M.F.WeatherSpawnXZ(ox, oz, viewFX, viewFZ, viewHalf, radius)
            if recycle then
                viewBudget = viewBudget - 1
                y = oy + math.random(0, 40)
            else
                y = oy + math.random(25, 45)
            end
        end
        leaf.X, leaf.Y, leaf.Z = x, y, z
        local p = leaf.Part
        if leaf.Size ~= size then
            leaf.Size = size
            p.Size = Vector3.new(size, 0.04, size * 0.7)
        end
        n = n + 1
        parts[n] = p
        cfs[n] = CFrame.new(x, y, z) * CFrame.Angles(t * 1.7, t * 1.1, t * 1.3)
    end
    for i = #parts, n + 1, -1 do parts[i] = nil; cfs[i] = nil end
    if n > 0 then workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
end

-- сколько неба видно над камерой
function M.F.SkyExposure(origin)
    local ignore = {}
    for i, inst in ipairs(M.Data.RayIgnoreBase or M.RayParams.FilterDescendantsInstances) do ignore[i] = inst end
    for _ = 1, 4 do
        M.ScratchParams.FilterDescendantsInstances = ignore
        local hit = workspace:Raycast(origin, Vector3.new(0, 300, 0), M.ScratchParams)
        if not hit then return 1 end
        local part = hit.Instance
        local character = M.GetCharacterFromPart(part)
        if character or not part.CanCollide or part.Transparency >= 0.95 then
            table.insert(ignore, character or part)
        else
            return 0.12
        end
    end
    return 1
end

function M.F.StrikeLightning()
    local cam = workspace.CurrentCamera
    local char = M.LP and M.LP.Character
    local root = char and M.GetRoot(char)
    local origin = (root and root.Position) or (cam and cam.CFrame.Position)
    if not origin then return end

    local dist = math.random(80, 400)
    local angle = math.rad(math.random(0, 360))
    -- высота земли в точке удара берётся лучом вниз
    local groundX = origin.X + math.cos(angle) * dist
    local groundZ = origin.Z + math.sin(angle) * dist
    local strikeGround = Vector3.new(groundX, M.F.GroundHeightAt(groundX, groundZ, origin.Y), groundZ)
    local startSky = strikeGround + Vector3.new(math.random(-25, 25), math.random(180, 280), math.random(-25, 25))

    local bolt = Instance.new("Model")
    bolt.Name = M.Services.H:GenerateGUID(false)

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

    local fadeDur = 0.45
    -- Roblox показывает не больше 31 подсветки сразу: подсветке игроков молния место не занимает
    local hl
    if M.F.HighlightsFree() > 0 then
        hl = Instance.new("Highlight")
        hl.Adornee = bolt
        hl.FillColor = Color3.fromRGB(255, 255, 255)
        hl.OutlineColor = Color3.fromRGB(200, 235, 255)
        hl.FillTransparency = 0.05
        hl.DepthMode = Enum.HighlightDepthMode.Occluded
        hl.Parent = bolt
        M.Data.BoltHl = (M.Data.BoltHl or 0) + 1
        task.delay(M.State.LightningDuration + fadeDur + 0.1, function()
            M.Data.BoltHl = math.max((M.Data.BoltHl or 1) - 1, 0)
        end)
    end

    bolt.Parent = M.F.Folder("lFolder")

    if M.State.LightningFlash and cam then
        local power = M.State.LightningFlashPower * math.clamp(1.15 - dist / 500, 0.35, 1)
        power = power * M.F.SkyExposure(cam.CFrame.Position)
        if power > 0.02 then M.F.ScreenFlash(power) end
    end

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
        if hl then M.Services.T:Create(hl, fadeInfo, {FillTransparency = 1, OutlineTransparency = 1}):Play() end
    end)
end

function M.F.SpawnMeteor()
    local cam = workspace.CurrentCamera
    local char = M.LP and M.LP.Character
    local root = char and M.GetRoot(char)
    local originPos = (root and root.Position) or (cam and cam.CFrame.Position)
    if not originPos then return end

    local impactAngle = math.rad(math.random(0, 360))
    local impactDist = math.random(40, 200)
    local impactX = originPos.X + math.cos(impactAngle) * impactDist
    local impactZ = originPos.Z + math.sin(impactAngle) * impactDist
    local impactPos = Vector3.new(impactX, M.F.GroundHeightAt(impactX, impactZ, originPos.Y), impactZ)

    local height = math.random(220, 420)
    local dropAngle = math.rad(math.random(25, 40))
    local approach = math.rad(math.random(0, 360))
    local horizontal = height / math.tan(dropAngle)
    local startPos = impactPos + Vector3.new(math.cos(approach) * horizontal, height, math.sin(approach) * horizontal)

    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(M.State.MeteorSize, M.State.MeteorSize, M.State.MeteorSize)
    p.Material = Enum.Material.Neon; p.Color = M.State.MeteorColor
    -- anchored обязателен
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
        if M.State.MeteorImpact and not M.Run.IsShutDown then M.F.SpawnImpact(impactPos) end
        p:Destroy()
    end)
    M.Services.D:AddItem(p, M.State.MeteorDuration + 0.1)
end

end}

-- [25/69] Сферы вокруг тела, затемнение, туман
MODULES[#MODULES + 1] = {"25. Сферы вокруг тела, затемнение, туман", function(M, __X)
-- шары вокруг игрока со следом
local ORBIT_TRAIL_STEPS = 14

function M.F.StyleOrbitTrail(d)
    local tCol = M.State.OrbitTrailColor
    local width = M.State.OrbitSize * 0.9 * (M.State.OrbitTrailThick / 0.35)
    local steps = #d.Beams
    for j, b in ipairs(d.Beams) do
        local f0, f1 = (j - 1) / steps, j / steps
        b.Width0 = width * (1 - f0)
        b.Width1 = width * (1 - f1)
        b.Transparency = NumberSequence.new(0.05 + 0.95 * f0, 0.05 + 0.95 * f1)
        b.Color = ColorSequence.new(tCol)
    end
end

function M.F.RebuildOrbits()
    for _, item in ipairs(M.Data.OrbitObjs) do if item.Part then item.Part:Destroy() end end
    M.Data.OrbitObjs = {}
    if not M.State.OrbitOn then return end

    local pCol = M.State.OrbitColor
    for i = 1, M.State.OrbitCount do
        local p = Instance.new("Part")
        p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(M.State.OrbitSize, M.State.OrbitSize, M.State.OrbitSize)
        p.Material = Enum.Material.Neon; p.Color = pCol; p.CanCollide = false; p.CastShadow = false; p.Anchored = true
        -- лучи и касания игры шары не ловят
        p.CanQuery = false; p.CanTouch = false
        p.Parent = M.F.Folder("vFolder")

        -- якорь следа
        local anchor = Instance.new("Part")
        anchor.Name = M.Services.H:GenerateGUID(false)
        anchor.Size = Vector3.new(0.1, 0.1, 0.1)
        anchor.Transparency = 1
        anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false; anchor.CanTouch = false
        anchor.CastShadow = false; anchor.Massless = true
        anchor.Parent = p

        local atts = {Instance.new("Attachment", p)}
        for j = 1, ORBIT_TRAIL_STEPS do atts[j + 1] = Instance.new("Attachment", anchor) end
        local beams = {}
        for j = 1, ORBIT_TRAIL_STEPS do
            local b = Instance.new("Beam")
            b.Attachment0 = atts[j]; b.Attachment1 = atts[j + 1]
            b.Segments = 1; b.FaceCamera = true; b.LightEmission = 1; b.LightInfluence = 0
            b.Parent = p
            beams[j] = b
        end

        local item = {
            Part = p, Anchor = anchor, Atts = atts, Beams = beams, Hist = {}, Acc = 0,
            Phase = (i / M.State.OrbitCount) * (math.pi * 2),
            SpeedX = 1 + (i * 0.35), SpeedY = 1.3 - (i * 0.25), SpeedZ = 0.8 + (i * 0.4)
        }
        M.F.StyleOrbitTrail(item)
        table.insert(M.Data.OrbitObjs, item)
    end
end

function M.F.UpdateOrbitsVisualLive()
    local pCol = M.State.OrbitColor
    for _, d in ipairs(M.Data.OrbitObjs) do
        if d.Part and d.Part.Parent then
            d.Part.Color = pCol
            M.F.StyleOrbitTrail(d)
        end
    end
end

-- шаг следа одного шара
function M.F.StepOrbitTrail(d, offset, dt)
    local hist = d.Hist
    if #hist == 0 then
        for j = 1, ORBIT_TRAIL_STEPS do hist[j] = offset end
    end
    d.Acc = d.Acc + dt
    local interval = math.max(M.State.OrbitTrailLen, 0.05) / ORBIT_TRAIL_STEPS
    if d.Acc < interval then return end
    d.Acc = d.Acc % interval
    table.insert(hist, 1, offset)
    hist[ORBIT_TRAIL_STEPS + 1] = nil
    for j = 1, ORBIT_TRAIL_STEPS do d.Atts[j + 1].Position = hist[j] or offset end
end
function M.F.ApplyDark()
    pcall(function()
        if M.State.DarkWorld then
            if not M.Data.DarkApplied then M.F.WorldSave("Dark", M.Services.L, {"ExposureCompensation"}) end
            M.Data.DarkApplied = true
            M.F.SetProp(M.Services.L, "ExposureCompensation", -M.State.DarkIntensity * 3.5)
        elseif M.Data.DarkApplied then
            M.Data.DarkApplied = false
            M.F.WorldRestore("Dark")
        end
    end)
end

-- своё время суток
function M.F.ApplyTime()
    local L = M.Services.L
    if M.State.TimeOn and not M.Run.IsShutDown then
        if not M.Data.TimeApplied then M.F.WorldSave("Time", L, {"ClockTime"}) end
        M.Data.TimeApplied = true
        M.F.SetProp(L, "ClockTime", M.State.CustomTime)
    elseif M.Data.TimeApplied then
        M.Data.TimeApplied = false
        M.F.WorldRestore("Time")
    end
end

-- туман
function M.F.ApplyFog()
    pcall(function()
        local L = M.Services.L
        local ours = M.Data.FxAtmosphere and M.Data.FxAtmosphere.Parent and M.Data.FxAtmosphere
        local set = M.F.SetProp

        if M.State.FogOn then
            if not M.Data.FogApplied then
                M.F.WorldSave("Fog", L, {"FogStart", "FogEnd", "FogColor", "OutdoorAmbient", "Ambient"})
            end
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

            -- чужие Atmosphere гасим
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
            -- возвращаем всё как было ровно один раз
            M.Data.FogApplied = false
            if ours then ours:Destroy() end
            M.Data.FxAtmosphere = nil
            for atmo, density in pairs(M.Data.AtmoBackup) do
                if atmo.Parent then atmo.Density = density end
            end
            table.clear(M.Data.AtmoBackup)
            M.F.WorldRestore("Fog")
        end
    end)
end
end}

-- [26/69] Скайбокс и облака
MODULES[#MODULES + 1] = {"26. Скайбокс и облака", function(M, __X)
-- ==============================================================================
-- [ СКАЙБОКС ]
-- ==============================================================================

function M.F.RenderSkyStatus()
    local label = M.UI.SkyStatusLabel
    local st = M.Data.SkyStatus
    if not label or not st then return end
    local text = M.Translate(st.Key)
    if st.Arg ~= nil then text = string.format(text, st.Arg) end
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

-- достаёт ID из строки
function M.F.ExtractAssetDigits(text)
    local digits = string.match(text, "[?&]id=(%d+)") or string.match(text, "rbxassetid://(%d+)") or string.match(text, "%d+")
    if digits and #digits >= 5 and #digits <= 19 then return digits end
    return nil
end

-- разбирает строку с ID
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

-- приводит ОДИН адрес грани к безопасному виду или возвращает nil
function M.F.NormalizeSkyFace(value)
    if type(value) ~= "string" or #value > 200 then return nil end
    if string.find(value, "rbxasset://textures/sky/", 1, true) == 1 or string.find(value, "rbxasset://sky/", 1, true) == 1 then
        if string.find(value, "..", 1, true) then return nil end
        return value
    end
    local digits = M.F.ExtractAssetDigits(value)
    if digits then return "rbxassetid://" .. digits end
    return nil
end

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

-- достаёт 6 граней из первого объекта Sky внутри загруженного объекта
function M.F.ExtractFacesFromModel(root)
    local sky = root:IsA("Sky") and root or root:FindFirstChildWhichIsA("Sky", true)
    if not sky then return nil end
    local raw = {}
    for _, face in ipairs(M.Data.SkyFaces) do raw[face] = sky[face] end
    return M.F.SanitizeSkyFaces(raw)
end

-- загружает модель из магазина ЛОКАЛЬНО и достаёт 6 граней Sky
function M.F.ResolveImageFace(digits)
    M.Data.ImgCache = M.Data.ImgCache or {}
    local cached = M.Data.ImgCache[digits]
    if cached then return cached end
    local result = "rbxassetid://" .. digits
    pcall(function()
        local objects = game:GetObjects("rbxassetid://" .. digits)
        for _, obj in ipairs(objects) do
            if typeof(obj) == "Instance" and (obj:IsA("Decal") or obj:IsA("Texture")) then
                local image = M.F.NormalizeSkyFace(obj.Texture)
                if image then result = image end
            end
            if typeof(obj) == "Instance" then obj:Destroy() end
        end
    end)
    M.Data.ImgCache[digits] = result
    return result
end

function M.F.ResolveStoreSky(digits)
    local cached = M.Data.SkyCache[digits]
    if cached then return cached, "cache" end

    local numericId = tonumber(digits)
    if not numericId then return nil, "bad_id" end

    local loaders = {
        {Name = "GetObjects", Load = function() return game:GetObjects("rbxassetid://" .. digits) end},
        {Name = "AssetService", Load = function() return game:GetService("AssetService"):LoadAssetAsync(numericId) end},
        {Name = "InsertService", Load = function() return M.Services.I:LoadAsset(numericId) end}
    }

    local modelOpened = false
    local problems = {}
    for _, loader in ipairs(loaders) do
        -- каждый способ в pcall
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
                    if not faces and (root:IsA("Decal") or root:IsA("Texture")) then
                        local image = M.F.NormalizeSkyFace(root.Texture)
                        if image then faces = {image, image, image, image, image, image} end
                    end
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

-- находит Sky
function M.F.AcquireSky()
    local L = M.Services.L
    if M.Data.FxSky and M.Data.FxSky.Parent then return M.Data.FxSky end

    local sky = L:FindFirstChildOfClass("Sky")
    if sky then
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

-- записывает M.Data.SkyWanted в Sky
function M.F.CommitSky(silent)
    local faces = M.Data.SkyWanted
    if not faces or not M.State.SkyOn then return end

    local sky = M.F.AcquireSky()
    local changed = false

    for i, face in ipairs(M.Data.SkyFaces) do
        -- сравниваем по цифрам ID
        local current, wanted = tostring(sky[face]), faces[i]
        if string.find(wanted, "rbxassetid://", 1, true) then
            current, wanted = string.match(current, "%d+"), string.match(wanted, "%d+")
        end
        if current ~= wanted then
            sky[face] = faces[i]
            changed = true
        end
    end

    if silent or (not changed and M.Data.SkyStatus and M.Data.SkyStatus.Kind == "ok") then return end

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
        if token ~= M.Data.SkyToken or M.Run.IsShutDown then return end
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

-- silent = true
function M.F.ApplySky(silent)
    pcall(function()
        if not M.State.SkyOn then
            M.F.RestoreSky()
            table.clear(M.Data.SkyCache)  -- кэш загруженных скайбоксов больше не нужен
            if not silent then M.F.SetSkyStatus("Sky_Off", nil, "idle") end
            return
        end

        if silent then
            M.F.CommitSky(true)
            return
        end

        local faces, info, arg, digits = M.F.ParseSkyIds(M.State.SkyIds)
        if not faces then
            -- неверный ввод
            M.F.RestoreSky()
            M.F.SetSkyStatus(info, arg, info == "Sky_Idle" and "idle" or "error")
            return
        end

        if info == "Sky_Ok1" then
            -- один ID
            M.Data.SkyToken = M.Data.SkyToken + 1
            local token = M.Data.SkyToken
            M.F.SetSkyStatus("Sky_Resolving", nil, "idle")
            task.spawn(function()
                local ok, err = pcall(function()
                    local resolved, reason, detail = M.F.ResolveStoreSky(digits)
                    if token ~= M.Data.SkyToken or M.Run.IsShutDown or not M.State.SkyOn then return end
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
                if not ok then M.Errors.Hit("Skybox", err) end
            end)
            return
        end

        M.Data.SkyWanted = faces
        M.Data.SkyOkKey = info
        M.Data.SkyFallbackReason = nil
        M.F.CommitSky(false)

        -- шесть ID
        if info == "Sky_Ok6" then
            M.Data.SkyRefine = (M.Data.SkyRefine or 0) + 1
            local token = M.Data.SkyRefine
            task.spawn(function()
                local refined, changed = {}, false
                for i, face in ipairs(faces) do
                    local digits = string.match(face, "%d+")
                    refined[i] = digits and M.F.ResolveImageFace(digits) or face
                    if refined[i] ~= face then changed = true end
                end
                if changed and token == M.Data.SkyRefine and M.Data.SkyWanted == faces and M.State.SkyOn and not M.Run.IsShutDown then
                    M.Data.SkyWanted = refined
                    M.F.CommitSky(false)
                end
            end)
        end
    end)
end

-- быстрый выбор
function M.F.PickSkyPreset(id)
    M.F.SetStateVisual("SkyIds", id)
    M.F.SetStateVisual("SkyOn", true)
    M.F.ApplySky()
end

-- облака
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
            if M.Data.CloudBackup and M.Data.CloudBackup.Object ~= clouds and not ownClouds then
                M.Data.CloudBackup = nil
            end
            if not ownClouds and not M.Data.CloudBackup then
                M.Data.CloudBackup = {
                    Object = clouds, Enabled = clouds.Enabled,
                    Density = clouds.Density, Cover = clouds.Cover, Color = clouds.Color
                }
            end
            M.F.SetProp(clouds, "Enabled", M.F.VisualLevel() < 3)
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

end}

-- [27/69] Направление ввода
MODULES[#MODULES + 1] = {"27. Направление ввода", function(M, __X)
-- ==============================================================================
-- [ НАПРАВЛЕНИЕ ВВОДА ]
-- ==============================================================================
local function GetDirectionInput()
    if M.Data.Fc or M.Services.U:GetFocusedTextBox() then return 0, 0, 0 end
    local x, z, y = 0, 0, 0
    if M.Services.U:IsKeyDown(Enum.KeyCode.D) then x = x + 1 end
    if M.Services.U:IsKeyDown(Enum.KeyCode.A) then x = x - 1 end
    if M.Services.U:IsKeyDown(Enum.KeyCode.W) then z = z + 1 end
    if M.Services.U:IsKeyDown(Enum.KeyCode.S) then z = z - 1 end
    if M.Services.U:IsKeyDown(Enum.KeyCode.Space) then y = y + 1 end
    if M.Services.U:IsKeyDown(Enum.KeyCode.LeftControl) or M.Services.U:IsKeyDown(Enum.KeyCode.LeftShift) then y = y - 1 end
    return x, z, y
end

__X.GetDirectionInput = GetDirectionInput
end}

-- [28/69] Движение: скорость, транспорт, полёт, воздух, паника
MODULES[#MODULES + 1] = {"28. Движение: скорость, транспорт, полёт, воздух, паника", function(M, __X)
local GetDirectionInput = __X.GetDirectionInput
-- ==============================================================================
-- [ ДВИЖЕНИЕ ]
-- ==============================================================================

function M.F.WriteVelocity(hrp, newVelocity)
    local old = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = newVelocity
    if M.Data.PrevVelocity then
        M.Data.PrevVelocity = M.Data.PrevVelocity + (newVelocity - old)
    end
end

-- скорость ходьбы, которую задала ИГРА
function M.F.GameWalkSpeed(h)
    local D = M.Data
    if D.SpeedWritten ~= nil and D.SpeedHum == h and h.WalkSpeed == D.SpeedWritten then
        return D.SpeedBase
    end
    return h.WalkSpeed
end

-- возвращает скорость ходьбы, которая была до надбавки
function M.F.ReleaseSpeedBoost(h)
    local D = M.Data
    if D.SpeedWritten == nil then return end
    if h and D.SpeedHum == h and D.SpeedBase and h.WalkSpeed == D.SpeedWritten then
        h.WalkSpeed = D.SpeedBase
    end
    D.SpeedWritten = nil
end

-- ускорение бега
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

-- ускорение в транспорте
function M.F.ReleaseVehicleSpeed()
    local D = M.Data
    if D.VehSeat then
        local seat, orig = D.VehSeat, D.VehOrigMax
        D.VehSeat, D.VehOrigMax = nil, nil
        if seat.Parent and orig then pcall(function() seat.MaxSpeed = orig end) end
    end
end

function M.F.UpdateVehicleSpeed(dt, h)
    local D = M.Data
    local seat = h.SeatPart
    if not seat then M.F.ReleaseVehicleSpeed(); return end
    local speed = M.State.SprintSpeed
    local throttle
    if seat:IsA("VehicleSeat") then
        if D.VehSeat ~= seat then
            M.F.ReleaseVehicleSpeed()
            D.VehSeat, D.VehOrigMax = seat, seat.MaxSpeed
        end
        if seat.MaxSpeed ~= speed then seat.MaxSpeed = speed end
        throttle = seat.Throttle
    else
        M.F.ReleaseVehicleSpeed()
        local _, z = GetDirectionInput()
        throttle = z
    end
    if throttle == 0 then return end
    local root = seat.AssemblyRootPart or seat
    local velocity = root.AssemblyLinearVelocity
    local flat = Vector3.new(velocity.X, 0, velocity.Z)
    if flat.Magnitude >= speed then return end
    local look = seat.CFrame.LookVector
    local forward = Vector3.new(look.X, 0, look.Z)
    if forward.Magnitude <= 0 then return end
    local want = (flat.Magnitude > 3) and (flat.Unit * speed) or (forward.Unit * math.sign(throttle) * speed)
    local newFlat = flat:Lerp(want, 1 - math.exp(-10 * dt))
    M.F.PushVehicle(seat, newFlat, false)
end

-- полёт
function M.F.UpdateFlight(dt, hrp, cam, h)
    local D = M.Data
    -- тумблер «Полёт и в транспорте»
    if h and h.SeatPart then
        hrp = h.SeatPart.AssemblyRootPart or h.SeatPart
        -- сидя PlatformStand не нужен
        if h.PlatformStand then h.PlatformStand = false end
    elseif h and not h.PlatformStand then
        h.PlatformStand = true
    end
    local inX, inZ, inY = GetDirectionInput()
    local camCF = cam.CFrame
    local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
    local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
    if forward.Magnitude > 0 then forward = forward.Unit end
    if right.Magnitude > 0 then right = right.Unit end

    local moveDir = (right * inX) + (forward * inZ)
    if moveDir.Magnitude > 0 then moveDir = moveDir.Unit end
    local totalDir = Vector3.new(moveDir.X, inY, moveDir.Z)
    if totalDir.Magnitude > 1 then totalDir = totalDir.Unit end  -- по диагонали не быстрее, чем прямо

    D.FlightVel = D.FlightVel or hrp.AssemblyLinearVelocity
    D.FlightVel = D.FlightVel:Lerp(totalDir * M.State.FlightSpeed, 1 - math.exp(-12 * dt))
    local flightVelocity = D.FlightVel + Vector3.new(0, workspace.Gravity * dt * 0.5, 0)
    if h and h.SeatPart then
        -- в транспорте летит вся машина
        D.VehFly = {Seat = h.SeatPart, Vel = flightVelocity}
        M.F.PushVehicle(h.SeatPart, flightVelocity, true)
    else
        D.VehFly = nil
        hrp.AssemblyLinearVelocity = flightVelocity
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

-- управление в падении
function M.F.VehicleAssemblies(seat)
    local D = M.Data
    local cache = D.VehAsm
    local now = os.clock()
    if cache and cache.Seat == seat and now - cache.At < 1 then return cache.List end
    local list, seen = {}, {}
    local function add(part)
        local root = part and (part.AssemblyRootPart or part)
        if root and not seen[root] and not root.Anchored and #list < 40 then
            seen[root] = true
            list[#list + 1] = root
        end
    end
    add(seat)
    local base = seat.AssemblyRootPart or seat
    local ok, connected = pcall(function() return base:GetConnectedParts(true) end)
    if ok then
        for _, part in ipairs(connected) do add(part) end
    end
    D.VehAsm = {Seat = seat, At = now, List = list}
    return list
end

-- записывает скорость во весь транспорт
function M.F.PushVehicle(seat, velocity, full)
    for _, root in ipairs(M.F.VehicleAssemblies(seat)) do
        if root.Parent then
            if full then
                root.AssemblyLinearVelocity = velocity
                root.AssemblyAngularVelocity = Vector3.zero
            else
                local own = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(velocity.X, own.Y, velocity.Z)
            end
        end
    end
end

-- в воздухе меняется только горизонтальная скорость: прыжок и падение остаются за игрой
function M.F.UpdateAirControl(dt, hrp, cam)
    local D = M.Data
    -- первые мгновения после отрыва от земли не трогаем, чтобы толчок прыжка прошёл целиком
    if os.clock() - (D.AirGroundAt or -10) < 0.12 then return end
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
    local top = math.max(M.State.AirSpeed, 1)
    -- быстрее заданного не разгоняем, но набранную скорость можно поворачивать
    local target = dir.Unit * math.max(top, flat.Magnitude)
    local alpha = 1 - math.exp(-(M.State.AirAccel * 0.75) * dt)
    local delta = (target - flat) * alpha
    if delta.Magnitude < 1e-3 then return end
    local ok = pcall(function() hrp:ApplyImpulse(delta * hrp.AssemblyMass) end)
    if ok then
        if D.PrevVelocity then D.PrevVelocity = D.PrevVelocity + delta end
    else
        M.F.WriteVelocity(hrp, Vector3.new(flat.X + delta.X, hrp.AssemblyLinearVelocity.Y, flat.Z + delta.Z))
    end
end

-- аварийное выключение
local PANIC_KEYS = {"FreezeChar", "FakeLag", "FlightMode", "Speed", "WalkThroughWalls", "InfiniteJumps", "AutoJump", "AirControl", "PeekOn", "TriggerAssist", "TriggerLoop",
    "AimAssist", "FallProtection", "AntiStun", "SpinCharacter", "BackWalk", "HeadTiltOn", "IdleProtection", "FreecamOn"}
local MOVE_KEYS = {"FlightMode", "Speed", "WalkThroughWalls", "AirControl"}

-- выключает перечисленные функции так же, как это сделал бы игрок в меню
function M.F.DisableFeatures(keys)
    local count = 0
    for _, key in ipairs(keys) do
        if M.State[key] == true then
            count = count + 1
            M.F.SetStateVisual(key, false)
            -- обработчик переключателя
            for _, el in ipairs(M.Data.RegUI) do
                if el.Key == key and el.Callback then pcall(el.Callback, false) end
            end
        end
    end
    return count
end

-- страховка
function M.F.StopMovement()
    local char = M.LP and M.LP.Character
    local hum = char and M.GetHumanoid(char)
    pcall(M.F.ReleaseSpeedBoost, hum)
    pcall(M.F.ReleaseVehicleSpeed)
    M.Data.TpTravel = nil
    pcall(M.F.StopFlying)
    pcall(M.F.SetWallPass, false)
    M.Data.FlightVel = nil
end

function M.F.PanicReset()
    local count = M.F.DisableFeatures(PANIC_KEYS)
    M.F.StopMovement()
    -- страховка
    pcall(M.F.StopFreecam)
    pcall(M.F.SetIdleProtection, false)
    M.Data.PrevVelocity = nil
    M.F.Notify("PanicReset", M.Translate("Panic_Done"), false, true)
    return count
end

-- выключает только движение
function M.F.MovementStopped(reasonKey)
    M.F.DisableFeatures(MOVE_KEYS)
    M.F.StopMovement()
    M.Data.PrevVelocity = nil
    M.F.Notify("MovementStopped", M.Translate(reasonKey), false, true)
end

-- телепорт
function M.F.SetTeleportPoint()
    local _, h, hrp = M.GetSelf()
    if not hrp or not h or h.Health <= 0 then return end
    M.Data.TeleportPoint = hrp.CFrame
    M.F.Notify("TeleportSet", M.Translate("TpSaved"), true, true)
end

local function moveCharacterBy(h, hrp, delta)
    local target = hrp
    if h.SeatPart then target = h.SeatPart.AssemblyRootPart or h.SeatPart end
    target.CFrame = target.CFrame + delta
    target.AssemblyLinearVelocity = Vector3.zero
    M.Data.GuardCooldownUntil = os.clock() + 1.5
    M.Data.PrevVelocity = nil
end

function M.F.TeleportToPoint()
    local _, h, hrp = M.GetSelf()
    if not hrp or not h or h.Health <= 0 then return end
    local point = M.Data.TeleportPoint
    if not point then
        M.F.Notify("TeleportNoPoint", M.Translate("TpNoPoint"), false, true)
        return
    end
    if M.State.TeleportSpeed > 0 then
        M.Data.TpTravel = {Target = point.Position, Speed = M.State.TeleportSpeed}
        return
    end
    moveCharacterBy(h, hrp, point.Position - hrp.Position)
    M.F.Notify("TeleportDone", M.Translate("TpDone"), true, true)
end

-- плавный телепорт
function M.F.UpdateTpTravel(dt, hrp, h)
    local D = M.Data
    local travel = D.TpTravel
    if not travel then return end
    if not hrp or not h or h.Health <= 0 or not hrp.Parent then
        D.TpTravel = nil
        return
    end
    local delta = travel.Target - hrp.Position
    local dist = delta.Magnitude
    if dist <= 0.5 then
        D.TpTravel = nil
        M.F.Notify("TeleportDone", M.Translate("TpDone"), true, true)
        return
    end
    moveCharacterBy(h, hrp, delta.Unit * math.min(dist, travel.Speed * dt))
end

__X.MOVE_KEYS = MOVE_KEYS
-- ---------------- Пик-ассист: зажали клавишу - на месте загорается точка; выстрелили - персонаж сам бежит на неё своей скоростью
local PK = {Step = M.Services.H:GenerateGUID(false), TpStep = M.Services.H:GenerateGUID(false)}
local PEEK_KEYS = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down,
    Enum.KeyCode.Left, Enum.KeyCode.Right}

-- пол под точкой: на нём рисуется круг
function PK.groundBelow(pos, down)
    local ok, hit = pcall(M.F.RaycastMapRaw, pos, Vector3.new(0, -(down + 6), 0))
    if ok and hit then return hit.Position end
    return pos - Vector3.new(0, down, 0)
end

function PK.ground(root, hum)
    return PK.groundBelow(root.Position, (hum and hum.HipHeight or 2) + root.Size.Y * 0.5)
end

-- неоновый круг: светящийся край, тёмная середина и расходящаяся волна
function PK.makeMark(pos)
    local folder = M.F.Folder("pkFolder")
    local function disc(lift)
        local p = Instance.new("Part")
        p.Name = M.Services.H:GenerateGUID(false)
        p.Shape = Enum.PartType.Cylinder
        p.Anchored = true
        p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
        p.Material = Enum.Material.Neon
        p.CFrame = CFrame.new(pos + Vector3.new(0, lift, 0)) * CFrame.Angles(0, 0, math.pi / 2)
        p.Parent = folder
        return p
    end
    local mark = {Pos = pos, Rim = disc(0.03), Core = disc(0.06), Wave = disc(0.045)}
    local light = Instance.new("PointLight")
    light.Shadows = false
    light.Range = 7
    light.Brightness = 1.4
    light.Parent = mark.Rim
    mark.Light = light
    PK.style(mark)
    return mark
end

-- цвет и размер из настроек
function PK.style(mark)
    local S = M.State
    local col = S.PeekColor
    local d = math.clamp(tonumber(S.PeekSize) or 2.4, 0.8, 8)
    if mark.Col == col and mark.D == d then return end
    mark.Col, mark.D = col, d
    mark.Rim.Color, mark.Rim.Size, mark.Rim.Transparency = col, Vector3.new(0.05, d, d), 0.15
    mark.Core.Color, mark.Core.Size, mark.Core.Transparency = col:Lerp(Color3.new(0, 0, 0), 0.55), Vector3.new(0.05, d * 0.78, d * 0.78), 0.35
    mark.Wave.Color = col:Lerp(Color3.new(1, 1, 1), 0.25)
    mark.Light.Color = col
end

function PK.dropMark(P)
    local mark = P.Mark
    P.Mark = nil
    if not mark then return end
    for _, part in ipairs({mark.Rim, mark.Core, mark.Wave}) do pcall(function() part:Destroy() end) end
end

-- волна и свет точки
function PK.animate(mark, bright)
    PK.style(mark)
    local ph = (os.clock() * 0.8) % 1
    local d = mark.D * (1 + 0.7 * ph)
    mark.Wave.Size = Vector3.new(0.05, d, d)
    mark.Wave.Transparency = 0.35 + 0.65 * ph
    local b = bright and 2.4 or 1.4
    if mark.Light.Brightness ~= b then mark.Light.Brightness = b end
end

-- зажаты ли клавиши движения у игрока
function PK.moveKeysDown()
    local U = M.Services.U
    for _, k in ipairs(PEEK_KEYS) do
        if U:IsKeyDown(k) then return true end
    end
    return false
end

-- клавиши у игрока не забираются: управление Roblox всё время видит их, а возврат просто перекрывает направление.
-- Поэтому, когда возврат закончился, зажатая W работает в тот же кадр
function PK.stopReturn(P, hum)
    if not P.Returning then return end
    P.Returning = false
    -- ничего не зажато: останавливаем шаг, иначе направление возврата осталось бы у персонажа
    if hum and hum.Parent and not PK.moveKeysDown() then pcall(function() hum:Move(Vector3.zero, false) end) end
end

-- идёт ли стрельба: щелчок, зажатая кнопка или автовыстрел
function PK.firing(P, D)
    if D.LastShot > P.ArmedAt or D.TriggerHeld then return true end
    local U = M.Services.U
    return U:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not M.Run.MenuOpen and not U:GetFocusedTextBox()
end

function PK.clear(P, hum)
    PK.stopReturn(P, hum)
    PK.dropMark(P)
    P.Held = false
end

function PK.step(dt)
    local S, D = M.State, M.Data
    local P = D.Peek
    if not P then return end
    local char, hum, root, alive = M.GetSelf()
    -- полёт, свободная камера, наблюдение и плавный телепорт сами ведут персонажа: пик-ассист им не мешает
    local held = S.PeekOn and alive and root ~= nil and hum ~= nil and not M.Run.MenuOpen and not S.FlightMode and not D.Fc
        and not S.SpectateOn and not D.TpTravel and M.F.ModeActive("HoldKey", S.PeekKey, "Peek")
    if not held then
        if P.Held or P.Mark then PK.clear(P, hum) end
        return
    end
    -- нажали: точка там, где вы стоите
    if not P.Held or P.Char ~= char then
        PK.clear(P, hum)
        P.Held, P.Char = true, char
        P.Mark = PK.makeMark(PK.ground(root, hum))
        P.ArmedAt = os.clock()
    end
    local mark = P.Mark
    local now = os.clock()
    PK.animate(mark, P.Returning)

    local target = mark.Pos
    local pos = root.Position
    local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
    local dist = flat.Magnitude
    if not P.Returning then
        -- стреляете, отойдя от точки: бежим обратно
        if dist > 1 and now >= (P.StuckUntil or 0) and PK.firing(P, D) then
            P.Returning, P.Best, P.BestAt = true, dist, now
        else
            return
        end
    end
    -- на месте: управление снова ваше, следующий выстрел снова вернёт
    local speed = math.max(hum.WalkSpeed, 1)
    if dist <= math.max(0.6, speed * dt * 1.2) then
        PK.stopReturn(P, hum)
        P.ArmedAt = now
        return
    end
    -- упёрлись в препятствие и не приближаемся: возврат отменяется, чтобы не держать управление
    if dist < P.Best - 0.3 then
        P.Best, P.BestAt = dist, now
    elseif now - P.BestAt > 1.2 then
        PK.stopReturn(P, hum)
        -- пока зажата стрельба, сразу снова не тянем: полторы секунды управление полностью ваше
        P.ArmedAt, P.StuckUntil = now, now + 1.5
        return
    end
    hum:Move(flat.Unit, false)
end

-- такая же точка на месте телепорта
function PK.tpStep()
    local T = M.Data.TpMark
    local point = M.Data.TeleportPoint
    if not T or not point then return end
    if T.Src ~= point then
        T.Src = point
        PK.dropMark(T)
        T.Mark = PK.makeMark(PK.groundBelow(point.Position, 3))
    end
    PK.animate(T.Mark, M.Data.TpTravel ~= nil)
end

M.F.DefineModule("TpMarker", {
    Wanted = function() return M.State.TeleportOn and M.Data.TeleportPoint ~= nil end,
    Load = function()
        M.Data.TpMark = {}
        pcall(function() M.Services.R:UnbindFromRenderStep(PK.TpStep) end)
        M.Services.R:BindToRenderStep(PK.TpStep, Enum.RenderPriority.Last.Value, function()
            if M.Run.IsShutDown then return end
            M.F.Safe("TpMarker", PK.tpStep)
        end)
    end,
    Unload = function()
        pcall(function() M.Services.R:UnbindFromRenderStep(PK.TpStep) end)
        local T = M.Data.TpMark
        M.Data.TpMark = nil
        if T then PK.dropMark(T) end
    end
})

M.F.DefineModule("PeekAssist", {
    Wanted = function() return M.State.PeekOn end,
    Load = function()
        M.Data.Peek = {Held = false, Returning = false, ArmedAt = 0}
        pcall(function() M.Services.R:UnbindFromRenderStep(PK.Step) end)
        -- сразу после того, как управление Roblox записало движение: наше направление главнее
        M.Services.R:BindToRenderStep(PK.Step, Enum.RenderPriority.Input.Value + 1, function(dt)
            if M.Run.IsShutDown then return end
            M.F.Safe("PeekAssist", PK.step, dt)
        end)
    end,
    Unload = function()
        pcall(function() M.Services.R:UnbindFromRenderStep(PK.Step) end)
        local P = M.Data.Peek
        M.Data.Peek = nil
        if P then
            local _, hum = M.GetSelf()
            PK.clear(P, hum)
        end
    end
})
end}

-- [29/69] Телепорт, призраки, заморозка для других игроков, откат
MODULES[#MODULES + 1] = {"29. Телепорт, призраки, заморозка для других игроков, откат", function(M, __X)
local GetDirectionInput = __X.GetDirectionInput
local MOVE_KEYS = __X.MOVE_KEYS
-- призраки сервера
local GHOST_MATERIALS = {ForceField = Enum.Material.ForceField, Neon = Enum.Material.Neon, Plastic = Enum.Material.Plastic}
local GHOST_STRIP = {"Script", "LocalScript", "ModuleScript", "Humanoid", "Animator", "Sound", "Decal", "Texture",
    "SurfaceAppearance", "Shirt", "Pants", "ShirtGraphic", "BillboardGui", "SurfaceGui", "Highlight", "ParticleEmitter",
    "Trail", "Beam", "Light", "ForceField", "Motor6D", "Weld", "WeldConstraint", "JointInstance", "Constraint", "Fire",
    "Smoke", "Sparkles", "Tool"}

function M.F.StyleGhosts()
    local D, S = M.Data, M.State
    local list = D.Ghosts
    if not list then return end
    local material = GHOST_MATERIALS[S.GhostMaterial] or Enum.Material.ForceField
    local count = math.max(1, math.floor(S.GhostCount))
    for index, ghost in ipairs(list) do
        -- чем старше призрак, тем он прозрачнее
        local alpha = math.clamp(S.GhostAlpha + (1 - S.GhostAlpha) * 0.7 * ((index - 1) / count), 0, 1)
        for _, part in ipairs(ghost.Parts) do
            if part.Parent then
                if part.Material ~= material then part.Material = material end
                M.F.SetProp(part, "Color", S.GhostColor)
                M.F.SetProp(part, "Transparency", alpha)
                M.F.SetProp(part, "Reflectance", 0)
            end
        end
    end
end

function M.F.ClearGhosts()
    local list = M.Data.Ghosts
    if not list then return end
    M.Data.Ghosts = nil
    for _, ghost in ipairs(list) do
        if ghost.Model.Parent then ghost.Model:Destroy() end
    end
end

-- приводит число призраков к выбранному, перекрашивает остальные
function M.F.RestyleGhosts()
    if not M.State.ServerGhosts then
        M.F.ClearGhosts()
        return
    end
    local list = M.Data.Ghosts
    if not list then return end
    local count = math.max(1, math.floor(M.State.GhostCount))
    while #list > count do
        local old = table.remove(list)
        if old.Model.Parent then old.Model:Destroy() end
    end
    M.F.StyleGhosts()
end

function M.F.CaptureGhost()
    local D, S = M.Data, M.State
    if not S.ServerGhosts then return end
    local now = os.clock()
    if now - (D.GhostAt or 0) < 0.1 then return end
    local char = M.LP and M.LP.Character
    if not char then return end
    D.GhostAt = now

    local wasArchivable = char.Archivable
    pcall(function() char.Archivable = true end)
    local ok, clone = pcall(function() return char:Clone() end)
    pcall(function() char.Archivable = wasArchivable end)
    if not ok or not clone then return end

    local rootName = M.GetRoot(char) and M.GetRoot(char).Name
    local parts = {}
    for _, inst in ipairs(clone:GetDescendants()) do
        local strip = false
        for _, className in ipairs(GHOST_STRIP) do
            if inst:IsA(className) then strip = true; break end
        end
        if strip then
            inst:Destroy()
        elseif inst:IsA("BasePart") then
            local hiddenOriginally = inst.Transparency >= 0.9
            inst.Anchored = true
            inst.CanCollide = false
            inst.CanQuery = false
            inst.CanTouch = false
            inst.Massless = true
            inst.CastShadow = false
            pcall(function() inst.MaterialVariant = "" end)
            if inst:IsA("MeshPart") then pcall(function() inst.TextureID = "" end) end
            if inst.Name == rootName or hiddenOriginally then
                inst.Transparency = 1
            else
                parts[#parts + 1] = inst
            end
        end
    end
    clone.Name = M.Services.H:GenerateGUID(false)
    clone.Parent = M.F.Folder("vFolder")

    D.Ghosts = D.Ghosts or {}
    table.insert(D.Ghosts, 1, {Model = clone, Parts = parts})
    local count = math.max(1, math.floor(S.GhostCount))
    while #D.Ghosts > count do
        local old = table.remove(D.Ghosts)
        if old.Model.Parent then old.Model:Destroy() end
    end
    M.F.StyleGhosts()
end

-- рассинхрон с сервером
local function desyncAnchor(D, hrp, on)
    D.DesyncWant = (on and hrp) or nil
    if on then
        if D.DesyncRoot ~= hrp then
            if D.DesyncRoot and D.DesyncRoot.Parent then D.DesyncRoot.Anchored = D.DesyncOrig or false end
            D.DesyncRoot, D.DesyncOrig = hrp, hrp.Anchored
        end
        if not hrp.Anchored then
            M.F.CaptureGhost()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.Anchored = true
        end
    elseif D.DesyncRoot then
        local root = D.DesyncRoot
        D.DesyncRoot, D.DesyncOrig = nil, nil
        if root.Parent then
            root.Anchored = false
            root.AssemblyLinearVelocity = D.DesyncVel or Vector3.zero
        end
    end
end

-- шаг своего движения по клавишам, пока корень закреплён
local function desyncStep(D, dt, hrp, h, cam, vertical)
    if dt <= 0 or not cam then return end
    local inX, inZ, inY = GetDirectionInput()
    local camCF = cam.CFrame
    local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
    local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
    if forward.Magnitude > 0 then forward = forward.Unit end
    if right.Magnitude > 0 then right = right.Unit end
    local dir = (right * inX) + (forward * inZ)
    if dir.Magnitude > 0 then dir = dir.Unit end
    local speed = math.max(h.WalkSpeed, 0)
    local move = dir * speed
    if vertical then move = move + Vector3.new(0, inY * speed, 0) end
    D.DesyncVel = Vector3.new(move.X, 0, move.Z)
    if move.Magnitude <= 0 then return end
    local pos = hrp.Position + move * dt
    local rot = hrp.CFrame - hrp.CFrame.Position
    if dir.Magnitude > 0 then
        rot = rot:Lerp(CFrame.lookAt(Vector3.zero, dir), math.clamp(dt * 12, 0, 1))
    end
    hrp.CFrame = CFrame.new(pos) * rot
end

function M.F.UpdateDesync(dt, hrp, h, cam)
    local D, S = M.Data, M.State
    local frozen = S.FreezeChar
    local lagging = S.FakeLag and not frozen
    local active = (frozen or lagging) and hrp and hrp.Parent and h and h.Health > 0 and h.SeatPart == nil
    -- режим рассинхрона сменился
    local signature = (frozen and 1 or 0) + (lagging and 2 or 0) + (active and 4 or 0)
    if D.DesyncSig ~= signature then
        D.DesyncSig = signature
        M.F.ResetAssistState()
    end
    if not active then
        M.F.ClearGhosts()
        desyncAnchor(D, hrp, false)
        D.LagPhase, D.LagFrames, D.LagSendSince = nil, 0, nil
        return
    end
    if frozen then
        D.LagPhase = nil
        desyncAnchor(D, hrp, true)
        desyncStep(D, dt, hrp, h, cam, true)
        return
    end
    -- фейк лаги
    D.LagPhase = D.LagPhase or "send"
    if D.LagPhase == "send" then
        desyncAnchor(D, hrp, false)
        D.LagFrames = (D.LagFrames or 0) + 1
        D.LagSendSince = D.LagSendSince or os.clock()
        if D.LagFrames >= math.max(1, math.floor(S.FakeLagTicks)) and os.clock() - D.LagSendSince >= 0.07 then
            D.LagPhase, D.LagFrames, D.LagSendSince = "hold", 0, nil
            D.LagHoldUntil = os.clock() + math.max(0.03, S.FakeLagDelay)
            desyncAnchor(D, hrp, true)
        end
    else
        desyncAnchor(D, hrp, true)
        desyncStep(D, dt, hrp, h, cam, false)
        if os.clock() >= (D.LagHoldUntil or 0) then
            D.LagPhase = "send"
            desyncAnchor(D, hrp, false)
        end
    end
end
-- защита от повторных откатов
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

-- что выключать, если часть падает слишком часто: только её собственные функции
M.F.GuardKeys = {
    Movement = MOVE_KEYS,
    RollbackGuard = {"RollbackGuard"},
    AntiFling = {"FallProtection"},
    FallProtection = {"FallProtection"},
    AntiStun = {"AntiStun"},
    Pose = {"SpinCharacter", "BackWalk", "HeadTiltOn"},
    Desync = {"FreezeChar", "FakeLag"},
}

-- предохранитель от ошибок
function M.F.Guarded(name, fn, ...)
    local t0 = os.clock()
    local ok, err = pcall(fn, ...)
    M.F.GovRecord(name, os.clock() - t0)
    if ok then return true end
    M.Errors.Hit(name, err)
    local D = M.Data
    local now = os.clock()
    local record = D.ErrorLog[name]
    if not record or now - record.First > 5 then
        record = {First = now, Count = 0}
        D.ErrorLog[name] = record
    end
    record.Count = record.Count + 1
    if record.Count >= 8 then
        D.ErrorLog[name] = nil
        M.F.GuardTrip(name)
    end
    return false
end

-- подписи тумблеров, у которых имя настройки и строка перевода различаются
M.F.GuardLabels = {Speed = "SprintBoost", HeadTiltOn = "PitchMod"}

function M.F.GuardTrip(name)
    local keys = M.F.GuardKeys[name] or {}
    local labels = {}
    for _, key in ipairs(keys) do
        if M.State[key] == true then labels[#labels + 1] = M.Translate(M.F.GuardLabels[key] or key) end
    end
    M.F.DisableFeatures(keys)
    if name == "Movement" then pcall(M.F.StopMovement); M.Data.PrevVelocity = nil end
    if name == "TpTravel" then M.Data.TpTravel = nil end
    M.Quiet("[Matsysense] " .. name .. " падает слишком часто и выключена")
    if #labels > 0 then
        M.F.Notify("GuardTripped", string.format(M.Translate("Guard_Tripped"), table.concat(labels, ", ")), false, true)
    end
end

-- мягкая защита для визуальных обновлений
function M.F.Safe(name, fn, ...)
    local t0 = os.clock()
    local ok, err = pcall(fn, ...)
    M.F.GovRecord(name, os.clock() - t0)
    if ok then return true end
    M.Errors.Hit(name, err)
    return false
end

end}

-- [30/69] Защита от ошибок, управление нагрузкой, авто-прыжок
MODULES[#MODULES + 1] = {"30. Защита от ошибок, управление нагрузкой, авто-прыжок", function(M, __X)
local getService = __X.getService
-- управление нагрузкой
M.Data.Gov = {Level = 0, Cost = 0, Ema = 0, Down = 0, UpAt = 0, FpsRef = 0, HitchAt = 0, Hitches = {}}

function M.F.GovRecord(name, secs)
    local G = M.Data.Gov
    G.Cost = G.Cost + secs
    if secs > (G.FrameWorstSecs or 0) then G.FrameWorstSecs, G.FrameWorst = secs, name end
end

-- журнал подвисаний
function M.F.EngineStats()
    local D = M.Data
    local st = D.StatsSvc
    if st == nil then st = getService("Stats") or false; D.StatsSvc = st end
    local r = {}
    -- числом считается только настоящее число
    local function num(v) return type(v) == "number" and v or nil end
    if st then
        pcall(function() r.Inst = num(st.InstanceCount) end)
        pcall(function() r.Prim = num(st.PrimitivesCount) end)
        pcall(function() r.Moving = num(st.MovingPrimitivesCount) end)
        pcall(function() r.Phys = num(st.PhysicsStepTimeMs) end)
    end
    r.Mem = num(M.Data.PillMem)
    local n = 0
    for _ in pairs(M.Draw.Objects) do n = n + 1 end
    r.Draws = n
    local pooled = 0
    for _, pool in pairs(M.Draw.Pool) do pooled = pooled + #pool end
    r.Pool = pooled
    r.Created = M.Draw.Created or 0
    pcall(function() r.Heap = collectgarbage("count") / 1024 end)
    r.Own = #M.Data.WeatherPool + #(D.Leaves or {}) + (D.SplashLive or 0)
    return r
end

function M.F.GovHitch(dt, scriptMs, worstName, worstMs)
    local G = M.Data.Gov
    local mem = 0
    pcall(function() mem = collectgarbage("count") end)
    local entry = {At = math.floor(M.Run.Uptime or 0), Ms = math.floor(dt * 1000 + 0.5), Script = math.floor(scriptMs + 0.5),
        Worst = worstName or "-", WorstMs = math.floor(worstMs + 0.5), MemDelta = math.floor(mem - (G.LastMem or mem)),
        Made = (M.Draw.Made or 0) - (G.LastMade or 0), Level = G.Level, Fps = M.Run.CurFPS or 0}
    -- что было включено в этот момент
    local S, flags = M.State, ""
    for _, f in ipairs({{"PlayerView", "P"}, {"ArrowsOn", "A"}, {"FoeTrailOn", "T"}, {"WeatherOn", "W"}, {"SpeedWidgetOn", "S"},
        {"KeysOn", "K"}, {"HoloSelf", "H"}, {"OrbitOn", "O"}, {"TracerOn", "R"}, {"HideHats", "C"}, {"FpsBoost", "F"}}) do
        if S[f[1]] then flags = flags .. f[2] end
    end
    entry.Flags = flags ~= "" and flags or "-"
    entry.Players = #M.Services.P:GetPlayers()
    local okEng, eng = pcall(M.F.EngineStats)
    entry.Eng = okEng and eng or nil
    G.Hitches[#G.Hitches + 1] = entry
    if #G.Hitches > 40 then table.remove(G.Hitches, 1) end
    G.HitchCount = (G.HitchCount or 0) + 1
    if entry.Script * 3 >= entry.Ms then G.HitchScript = (G.HitchScript or 0) + 1 end
    if M.State.HitchReport and os.clock() - G.HitchAt > 4 then
        G.HitchAt = os.clock()
        local who = (entry.Script * 3 >= entry.Ms) and (entry.Worst .. " " .. entry.WorstMs .. " мс") or M.Translate("HitchNotScript")
        M.F.Notify("Hitch", string.format(M.Translate("HitchMsg"), entry.Ms, entry.Script, who), false, true)
    end
end

function M.F.HitchDump()
    local G = M.Data.Gov
    local total, byScript = G.HitchCount or 0, G.HitchScript or 0
    local lines = {string.format("Matsysense: подвисаний за сеанс %d, из них по вине скрипта %d (скрипт занял от трети кадра и больше)", total, byScript),
        "время(с) кадр(мс) скрипт(мс) тяжелее_всего(мс) память(КБ) рисунков_создано уровень FPS включено(P рамки,A стрелки,T следы,W погода,S скорость,K клавиши,H голограмма,O сферы,R трассеры,C шапки,F буст) игроков | рисунков_живых объектов_в_игре деталей двигающихся физика_мс память_игры_МБ куча_Lua_МБ наших_деталей в_пуле создано_всего"}
    local function eng(x)
        x = x or {}
        return string.format("%d %d %d %d %.1f %.0f %.1f %d %d %d", x.Draws or 0, x.Inst or 0, x.Prim or 0, x.Moving or 0, x.Phys or 0, x.Mem or 0, x.Heap or 0, x.Own or 0, x.Pool or 0, x.Created or 0)
    end
    for _, e in ipairs(G.Hitches) do
        lines[#lines + 1] = string.format("%d %d %d %s(%d) %+d %d %d %d %s %d | %s", e.At, e.Ms, e.Script, e.Worst, e.WorstMs, e.MemDelta, e.Made, e.Level, e.Fps,
            e.Flags or "-", e.Players or 0, eng(e.Eng))
    end
    -- динамика за сеанс
    lines[#lines + 1] = ""
    lines[#lines + 1] = "динамика раз в 30 с: время(с) FPS | рисунков_живых объектов_в_игре деталей двигающихся физика_мс память_игры_МБ куча_Lua_МБ наших_деталей в_пуле создано_всего"
    for _, s in ipairs(G.Samples or {}) do
        lines[#lines + 1] = string.format("%d %d | %s", s.At, s.Fps, eng(s.Eng))
    end
    local path = "Matsysense_hitches.txt"
    local saved = false
    lines[#lines + 1] = ""
    lines[#lines + 1] = "исполнитель: " .. M.Cap.Report()
    if M.Cap.Has("writefile") then saved = M.Cap.Call("writefile", path, table.concat(lines, "\n")) end
    if total == 0 then
        M.F.Notify("HitchDump", M.Translate("HitchNone"), false, true)
    else
        M.F.Notify("HitchDump", string.format(M.Translate("HitchSaved"), saved and path or "-", total, byScript), false, true)
    end
end

-- сколько рисунков создано в этом кадре
function M.Draw.MadeThisFrame()
    return (M.Draw.Made or 0) - (M.Draw.FrameStart or 0)
end

function M.F.GovTick(dt)
    M.Draw.FrameStart = M.Draw.Made or 0
    local G = M.Data.Gov
    local ms = G.Cost * 1000
    G.Cost = 0
    local worstName, worstMs = G.FrameWorst, (G.FrameWorstSecs or 0) * 1000
    G.FrameWorst, G.FrameWorstSecs = nil, 0
    -- подвисание
    if dt > 0.1 and (M.Run.Uptime or 0) > 20 and M.Data.WindowActive ~= false then
        pcall(M.F.GovHitch, dt, ms, worstName, worstMs)
    end
    G.LastMade = M.Draw.Made or 0
    -- память Lua нужна только журналу подвисаний: хватает замера 4 раза в секунду
    local clk = os.clock()
    if clk - (G.MemAt or 0) >= 0.25 then
        G.MemAt = clk
        local okMem, mem = pcall(collectgarbage, "count")
        if okMem then G.LastMem = mem end
    end
    -- раз в 30 секунд запись динамики
    if (M.Run.Uptime or 0) - (G.SampleAt or -30) >= 30 then
        G.SampleAt = M.Run.Uptime or 0
        G.Samples = G.Samples or {}
        local okEng, eng = pcall(M.F.EngineStats)
        G.Samples[#G.Samples + 1] = {At = math.floor(G.SampleAt), Fps = math.floor(M.Run.CurFPS or 0), Eng = okEng and eng or nil}
        if #G.Samples > 120 then table.remove(G.Samples, 1) end
    end
    G.Ema = G.Ema + (ms - G.Ema) * (1 - math.exp(-dt / 0.5))
    local now = os.clock()
    local fps = M.Run.CurFPS or 0
    if fps > G.FpsRef then G.FpsRef = fps else G.FpsRef = G.FpsRef - (G.FpsRef - fps) * math.min(dt * 0.02, 1) end
    local target = 0
    if M.State.AutoLite then
        if G.Ema > 11 then target = 3 elseif G.Ema > 7 then target = 2 elseif G.Ema > 4 then target = 1 end
        if G.FpsRef > 20 and fps > 0 then
            local r = fps / G.FpsRef
            if r < 0.25 then target = math.max(target, 3) elseif r < 0.4 then target = math.max(target, 2) elseif r < 0.6 then target = math.max(target, 1) end
        end
        -- игра и так тянет еле-еле: оформление скрипта не должно добавлять нагрузку
        if fps > 0 and (M.Run.Uptime or 0) > 15 and M.Data.WindowActive ~= false then
            if fps < 22 then target = math.max(target, 2) elseif fps < 35 then target = math.max(target, 1) end
        end
    end
    if target > G.Level then
        G.Down = 0
        if now - G.UpAt >= 0.5 then
            G.UpAt = now
            G.Level = G.Level + 1
            M.F.Notify("GovLevel", string.format(M.Translate("GovMsg"), G.Level), false, true)
        end
    elseif target < G.Level then
        G.Down = G.Down + dt
        if G.Down >= 3 then G.Level = G.Level - 1; G.Down = 0 end
    else
        G.Down = 0
    end
end

-- уровень облегчения визуалов задаёт только нагрузка
function M.F.VisualLevel()
    return M.Data.Gov.Level
end

-- доля частиц погоды, листьев и брызг по уровню облегчения
function M.F.VisualK()
    local l = M.Data.Gov.Level
    if l >= 3 then return 0.25 end
    if l == 2 then return 0.4 end
    if l == 1 then return 0.7 end
    return 1
end
-- подсветок Roblox одновременно
function M.F.HlLimit()
    local limit = M.State.PlayerViewHlLimit or 12
    local level = M.Data.Gov.Level
    if level >= 3 then return math.min(limit, 5) end
    if level >= 2 then return math.min(limit, 10) end
    return limit
end

-- сколько подсветок ещё можно показать (предел Roblox - 31)
function M.F.HighlightsFree()
    local used = M.Data.BoltHl or 0
    for _, hl in pairs(M.Data.Highlights) do
        if hl and hl.Parent and hl.Enabled then used = used + 1 end
    end
    return 31 - used
end
-- авто-прыжок
function M.F.UpdateAutoJump(h)
    if h.SeatPart ~= nil or h.Sit or h.PlatformStand then return end
    local state = h:GetState()
    if state == Enum.HumanoidStateType.Running
        or state == Enum.HumanoidStateType.RunningNoPhysics
        or state == Enum.HumanoidStateType.Landed then
        h:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end

-- одна точка входа для всех трёх функций
function M.F.UpdateMovement(dt, hrp, h, cam)
    if M.State.AutoJump and not M.State.FlightMode then
        M.F.UpdateAutoJump(h)
    end
    if M.State.Speed and not M.State.FlightMode then
        M.F.UpdateSpeedBoost(h)
    else
        M.F.ReleaseSpeedBoost(h)
    end
    if M.State.Speed and not M.State.FlightMode and h.SeatPart then
        M.F.UpdateVehicleSpeed(dt, h)
    else
        M.F.ReleaseVehicleSpeed()
    end
    if M.State.FlightMode then
        if cam then M.F.UpdateFlight(dt, hrp, cam, h) end
    else
        M.Data.FlightVel = nil
        if h.FloorMaterial ~= Enum.Material.Air then M.Data.AirGroundAt = os.clock() end
        if M.State.AirControl and cam and h:GetState() == Enum.HumanoidStateType.Freefall then
            M.F.UpdateAirControl(dt, hrp, cam)
        end
    end
end

function M.F.StartFlying()
    M.State.FlightMode = true
    M.Data.FlightVel = nil
    local char = M.LP and M.LP.Character
    if char then
        local h = M.GetHumanoid(char)
        if h then h.PlatformStand = true end
    end
end

function M.F.StopFlying()
    M.State.FlightMode = false
    M.Data.FlightVel = nil
    local char = M.LP and M.LP.Character
    if char then
        local h = M.GetHumanoid(char)
        local hrp = M.GetRoot(char)
        if h then h.PlatformStand = false end
        if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
    end
end

table.insert(M.Data.Conns, M.Services.U.JumpRequest:Connect(function()
    local char = M.LP and M.LP.Character
    if not char then return end
    local h = M.GetHumanoid(char)
    if not h or h.Health <= 0 then return end
    if M.State.InfiniteJumps and not M.State.FlightMode then
        h:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

-- анти-АФК
function M.F.SetIdleProtection(on)
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

end}

-- [31/69] Проход сквозь стены (шаг физики)
MODULES[#MODULES + 1] = {"31. Проход сквозь стены (шаг физики)", function(M, __X)
-- ==============================================================================
-- [ ПРОХОД СКВОЗЬ СТЕНЫ ]
-- ==============================================================================

-- есть ли вокруг персонажа твёрдые детали
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
    if D.WallPassOrig[part] == nil then D.WallPassOrig[part] = part.CanCollide end
    part.CanCollide = false
end

-- детали персонажа собираются один раз, новые добавляет DescendantAdded
local function wallParts(char)
    local D = M.Data
    if D.WallPartsChar ~= char or not D.WallParts then
        local list = {}
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then list[#list + 1] = part end
        end
        D.WallParts, D.WallPartsChar = list, char
    end
    return D.WallParts
end

-- окончательно возвращает столкновения и снимает подписки
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
    D.WallParts, D.WallPartsChar = nil, nil
end

local function wallPassStep()
    local D = M.Data
    if M.Run.IsShutDown then return end
    local char = M.LP and M.LP.Character
    if not (char and char.Parent) or M.Run.IsDead then
        if D.WallReleasePending then M.F.FinishWallRelease() end
        return
    end
    if M.State.WalkThroughWalls or D.WallReleasePending then
        -- Humanoid возвращает столкновения каждый шаг, поэтому запись нужна каждый шаг
        local list = wallParts(char)
        local n, alive = #list, 0
        for i = 1, n do
            local part = list[i]
            if part.Parent then
                alive = alive + 1
                list[alive] = part
                if part.CanCollide then wallDisableCollision(part) end
            end
        end
        for i = n, alive + 1, -1 do list[i] = nil end
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

-- заморозка и фейк лаги
table.insert(M.Data.Conns, M.Services.R.PreSimulation:Connect(function()
    local root = M.Data.DesyncWant
    if root and root.Parent and not root.Anchored then root.Anchored = true end
    -- полёт в транспорте
    local fly = M.Data.VehFly
    if fly then
        if M.State.FlightMode and fly.Seat.Parent and fly.Seat.Occupant then
            M.F.PushVehicle(fly.Seat, fly.Vel, true)
        else
            M.Data.VehFly = nil
        end
    end
end))

function M.F.SetWallPass(on)
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
                if not part:IsA("BasePart") then return end
                if D.WallParts and D.WallPartsChar == char then D.WallParts[#D.WallParts + 1] = part end
                if M.State.WalkThroughWalls then wallDisableCollision(part) end
            end)
        end
        return
    end

    -- выключение
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

end}

-- [32/69] Игровые циклы (после физики и перед рисованием кадра)
MODULES[#MODULES + 1] = {"32. Игровые циклы (после физики и перед рисованием кадра)", function(M, __X)
-- ==============================================================================
-- [ ГЛАВНЫЕ ЦИКЛЫ ]
-- ==============================================================================
-- запрос прыжка от игрока: защита от отбрасывания не примет толчок прыжка за удар
table.insert(M.Data.Conns, M.Services.U.JumpRequest:Connect(function() M.Data.LastJump = os.clock() end))
table.insert(M.Data.Conns, M.Services.R.Heartbeat:Connect(function(dt)
    if M.Run.IsShutDown then return end
    local char, h, hrp = M.GetSelf()
    local cam = workspace.CurrentCamera

    M.Run.IsDead = not (h and h.Health > 0)

    if char and char.Parent and not M.Run.IsDead and hrp and h then
        M.F.Guarded("Movement", M.F.UpdateMovement, dt, hrp, h, cam)
        M.F.Guarded("RollbackGuard", M.F.UpdateRollbackGuard, dt, hrp, h, char)
    else
        M.Data.GuardLastPos = nil
    end

    M.F.Guarded("AntiFling", M.F.UpdateAntiFling, dt)
    M.F.Guarded("Pose", M.F.UpdatePoseReal, dt)
    M.F.Guarded("Desync", M.F.UpdateDesync, dt, hrp, h, cam)
    M.F.Guarded("TpTravel", M.F.UpdateTpTravel, dt, hrp, h)

    local now = os.clock()
    if M.State.MeteorOn and now - M.Data.LastMet >= math.clamp(6 / M.State.MeteorRate, 0.4, 6) then
        M.Data.LastMet = now
        M.F.Safe("Meteor", M.F.SpawnMeteor)
    end
    if M.State.LightningOn and now - M.Data.LastLight >= math.clamp(8 / M.State.LightningRate, 0.6, 8) then
        M.Data.LastLight = now
        M.F.Safe("Lightning", M.F.StrikeLightning)
    end
end))

table.insert(M.Data.Conns, M.Services.R.RenderStepped:Connect(function(dt)
    if M.Run.IsShutDown then return end

    M.F.Safe("Cursor", M.F.UpdateCursor)
    pcall(M.F.GovTick, dt)

    M.Data.FpsCount = M.Data.FpsCount + 1
    if os.clock() - M.Data.FpsTimer >= 0.5 then
        M.Run.CurFPS = math.round(M.Data.FpsCount / (os.clock() - M.Data.FpsTimer))
        M.Data.FpsCount = 0; M.Data.FpsTimer = os.clock()
        local fps, q = M.Run.CurFPS, M.Data.Quality
        if fps > 0 and fps < 28 then q = math.max(q - 0.15, 0.35)
        elseif fps > 50 then q = math.min(q + 0.05, 1) end
        M.Data.Quality = q
    end

    -- остальное не чаще 144 раз в секунду: на 300-400 кадрах лишние обновления глазу не видны, а кадр стоят.
    -- Время копится, поэтому скорость эффектов не меняется
    do
        local acc = (M.Data.SlowAcc or 0) + dt
        if acc < 1 / 144 then
            M.Data.SlowAcc = acc
            return
        end
        M.Data.SlowAcc = 0
        dt = math.min(acc, 0.1)
    end

    M.F.SyncModules()
    if os.clock() - M.Data.LastFolderSweep >= 3 then
        M.Data.LastFolderSweep = os.clock()
        M.F.ReleaseEmptyFolders()
        if os.clock() - (M.Data.LastPrune or 0) >= 10 then
            M.Data.LastPrune = os.clock()
            M.F.Safe("PruneRegistries", M.F.PruneRegistries)
            M.Draw.TrimPool()
        end
    end
    if M.Run.MenuOpen and os.clock() - (M.Data.RefitAt or 0) >= 0.5 then
        M.Data.RefitAt = os.clock()
        M.F.Safe("FitText", M.F.RefitChanged)
    end

    local weatherDt = dt
    if (M.Run.CurFPS or 0) >= 100 then
        M.Data.WeatherAcc = (M.Data.WeatherAcc or 0) + dt
        if M.Data.WeatherAcc < 1 / 72 then weatherDt = nil else weatherDt, M.Data.WeatherAcc = M.Data.WeatherAcc, 0 end
    else
        M.Data.WeatherAcc = 0
    end
    if weatherDt and (M.State.WeatherOn or #M.Data.WeatherPool > 0) then M.F.Safe("WeatherProps", M.F.UpdateWeatherProps, weatherDt) end

    local D, S, UI = M.Data, M.State, M.UI
    if UI.LowHpGui then M.F.Safe("LowHp", M.F.UpdateLowHp, M.LP.Character and M.GetHumanoid(M.LP.Character)) end
    if S.DamageNumbers or S.HitMarkerOn or S.HitRingsOn or next(D.HpCache) ~= nil then M.F.Safe("EnemyHealth", M.F.UpdateEnemyHealth) end
    if UI.SpeedWidget then M.F.Safe("Widgets", M.F.UpdateWidgets, dt) end
    if S.SpectateOn or D.Spectating then M.F.Safe("Spectate", M.F.UpdateSpectate) end
    if D.Tracers and #D.Tracers > 0 then M.F.Safe("Tracers", M.F.UpdateTracers, dt) end
    if UI.Trail then M.F.Safe("CharTrail", M.F.UpdateCharTrail, dt) end

    if os.clock() - M.Data.LastVisual >= 0.1 then
        M.Data.LastVisual = os.clock()
        M.F.Safe("PlayerVisuals", M.UpdatePlayerVisuals)
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local char = M.LP and M.LP.Character
    if weatherDt and (D.Leaves or (S.WeatherOn and S.WeatherMode == "Leaves")) then M.F.Safe("Leaves", M.F.UpdateLeaves, weatherDt) end

    -- круг области доводки
    M.F.Safe("FovCircle", M.F.UpdateFovCircle, cam)

    M.F.Guarded("FallProtection", M.F.UpdateFallProtection)
    M.F.Guarded("AntiStun", M.F.UpdateAntiStun)

    if not M.State.PlayerView then
        for _, pack in pairs(M.Data.PlayerViewGuis) do M.F.HidePlayerPack(pack); M.F.PvForgetHighlight(pack) end
        for _, hl in pairs(M.Data.Highlights) do
            if hl and hl.Parent and hl.Enabled then hl.Enabled = false end
        end
    end

    if char and M.State.OrbitOn and #M.Data.OrbitObjs > 0 and M.GetRoot(char) then
        M.Data.OrbitClock = M.Data.OrbitClock + (dt * M.State.OrbitSpeed * 1.5)
        local cen = M.GetRoot(char).Position
        for _, d in ipairs(M.Data.OrbitObjs) do
            if d.Part and d.Part.Parent then
                local t = M.Data.OrbitClock + d.Phase
                local offset = Vector3.new(math.cos(t * d.SpeedX) * M.State.OrbitRadius, math.sin(t * d.SpeedY) * (M.State.OrbitRadius * 0.65), math.sin(t * d.SpeedZ) * M.State.OrbitRadius)
                d.Part.CFrame = CFrame.new(cen + offset)
                -- размер пишем, только если он изменился
                if math.abs(d.Part.Size.X - M.State.OrbitSize) > 0.001 then
                    d.Part.Size = Vector3.new(M.State.OrbitSize, M.State.OrbitSize, M.State.OrbitSize)
                end
                d.Anchor.CFrame = CFrame.new(cen)
                M.F.StepOrbitTrail(d, offset, dt)
            end
        end
    end

    -- смена дня и ночи: время само идёт вперёд
    if M.State.TimeOn and M.State.TimeSyncReal and os.clock() - M.Data.LastRealSync >= 1 then
        M.Data.LastRealSync = os.clock()
        M.F.SyncRealTime()
    end
    if M.State.TimeOn and M.State.TimeCycle and not M.State.TimeSyncReal then
        M.State.CustomTime = M.Math.AdvanceClock(M.State.CustomTime, dt, M.State.TimeCycleSpeed)
        if os.clock() - M.Data.LastCycleUi >= 0.25 then
            M.Data.LastCycleUi = os.clock()
            local shownTime = math.floor(M.State.CustomTime * 100) / 100
            for _, el in ipairs(M.F.VisualEntries("CustomTime")) do el.SetVisual(shownTime) end
        end
    end
end))

end}

-- [33/69] Камера правой кнопкой при открытом меню
MODULES[#MODULES + 1] = {"33. Камера правой кнопкой при открытом меню", function(M, __X)
local getService = __X.getService
-- ==============================================================================
-- [ ПКМ ПРИ ОТКРЫТОМ МЕНЮ ]
-- ==============================================================================
local function pointInside(obj, point)
    if not obj or not obj.Visible then return false end
    local pos, size = obj.AbsolutePosition, obj.AbsoluteSize
    return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

function M.F.PointerOverMenu()
    if not M.Run.MenuOpen or not M.UI.Main then return false end
    local point = M.Services.U:GetMouseLocation()
    if not M.UI.Gui.IgnoreGuiInset then
        local guiService = getService("GuiService")
        if guiService then point = point - guiService:GetGuiInset() end
    end
    return pointInside(M.UI.Main, point)
end

function M.F.CameraDragActive()
    local fc = M.Data.Fc
    local rmb = (fc and fc.Rmb) or M.Data.RmbCamera == true
    return rmb and M.Services.U:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

table.insert(M.Data.Conns, M.Services.U.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton2 then
        M.Data.RmbCamera = (M.Run.MenuOpen or M.State.SpectateOn) and not M.F.PointerOverMenu()
    end
end))
table.insert(M.Data.Conns, M.Services.U.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton2 then M.Data.RmbCamera = false end
end))

-- колесо мыши меняет дистанцию третьего лица
table.insert(M.Data.Conns, M.Services.U.InputChanged:Connect(function(inp, proc)
    if inp.UserInputType ~= Enum.UserInputType.MouseWheel then return end
    if M.Run.IsShutDown or not M.State.ThirdPerson or M.Run.MenuOpen or M.State.SpectateOn or M.Data.Fc then return end
    local step = inp.Position.Z * -1.2
    M.F.SetStateVisual("ThirdPersonDist", math.clamp(M.State.ThirdPersonDist + step, 3, 400))
end))

end}

-- [34/69] Перетаскивание и горячие клавиши
MODULES[#MODULES + 1] = {"34. Перетаскивание и горячие клавиши", function(M, __X)
-- ==============================================================================
-- [ ПЕРЕТАСКИВАНИЕ И БИНДЫ ]
-- ==============================================================================
table.insert(M.Data.Conns, M.Services.U.InputChanged:Connect(function(inp)
    M.Data.LastInputAt = os.clock()
    if M.Data.DragHandler and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        M.Data.DragHandler(inp.Position)
    end
end))

table.insert(M.Data.Conns, M.Services.U.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        M.Data.DragHandler = nil
        local finish = M.Data.DragEnd
        M.Data.DragEnd = nil
        if finish then pcall(finish) end
    end
end))

table.insert(M.Data.Conns, M.Services.U.InputBegan:Connect(function(inp, proc)
    if M.Run.IsShutDown then return end
    if (not proc and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch))
        or inp.KeyCode == Enum.KeyCode.ButtonR2 then
        M.Data.LastShot = os.clock()
    end
    local typing = M.Services.U:GetFocusedTextBox() ~= nil
    if not typing and inp.KeyCode == Enum.KeyCode.End then
        M.F.PanicReset()
        return
    end
    if not typing and (inp.KeyCode == Enum.KeyCode.RightShift or inp.KeyCode == Enum.KeyCode.Insert) then
        if not M.UI.Main or M.Data.ConfirmOpen then return end
        if M.UI.Main.Visible then M.F.CloseMenu() else M.F.OpenMenu() end
        return
    end
    if M.Run.ListeningBind then
        if inp.UserInputType == Enum.UserInputType.Keyboard then
            local code = inp.KeyCode
            if code == Enum.KeyCode.Backspace or code == Enum.KeyCode.Delete or code == Enum.KeyCode.Escape then
                code = nil
            end
            M.Run.ListeningBind.Set(code)
            M.Run.ListeningBind = nil
        elseif M.F.BindMouse and M.F.BindMouse[inp.UserInputType.Name] then
            -- средняя и правая кнопки мыши тоже могут быть клавишей бинда
            M.Run.ListeningBind.Set(inp.UserInputType)
            M.Run.ListeningBind = nil
        elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then
            M.Run.ListeningBind.Cancel()
            M.Run.ListeningBind = nil
        end
        return
    end
    if not typing and M.F.InputKey then
        local key = M.F.InputKey(inp)
        if key then
            for _, b in ipairs(M.Data.Binds) do
                if b.Key == key then M.F.BindPress(b) end
            end
        end
    end
end))

-- отпускание клавиши: бинды в режиме «Удерживать» выключаются
table.insert(M.Data.Conns, M.Services.U.InputEnded:Connect(function(inp)
    if M.Run.IsShutDown or not M.F.InputKey then return end
    local key = M.F.InputKey(inp)
    if not key then return end
    for _, b in ipairs(M.Data.Binds) do
        if b.Key == key and (b.Down or b.HeldOn) then M.F.BindRelease(b) end
    end
end))
table.insert(M.Data.Conns, M.Services.U.WindowFocusReleased:Connect(function()
    if M.F.ReleaseAllBinds then M.F.ReleaseAllBinds() end
end))

-- пока идёт заставка, ни один экран скрипта не показывается
M.Data.IntroActive = true
M.Data.GatedGuis = {}
function M.F.GateGui(gui)
    if M.Data.IntroActive then
        gui.Enabled = false
        table.insert(M.Data.GatedGuis, gui)
    end
    return gui
end

M.UI.Gui = Instance.new("ScreenGui")
M.UI.Gui.Name = M.Services.H:GenerateGUID(false)
M.UI.Gui.ResetOnSpawn = false
M.UI.Gui.DisplayOrder = 200  -- меню выше рамок игроков
-- global нужен, чтобы выпадающие списки
M.UI.Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
M.F.GateGui(M.UI.Gui)
M.UI.Gui.Parent = M.TargetGui
M.F.WatchFonts(M.UI.Gui)

-- VirtualUser нужен только для автовыстрела
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

end}

-- [35/69] Окно скрипта и мини-меню
MODULES[#MODULES + 1] = {"35. Окно скрипта и мини-меню", function(M, __X)
-- ==============================================================================
-- [ ОКНО И МИНИ-МЕНЮ ]
-- ==============================================================================
-- мини-меню
M.UI.PillGui = Instance.new("ScreenGui")
M.UI.PillGui.Name = M.Services.H:GenerateGUID(false)
M.UI.PillGui.ResetOnSpawn = false
M.UI.PillGui.DisplayOrder = 150
M.UI.PillGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
M.F.GateGui(M.UI.PillGui)
M.UI.PillGui.Parent = M.TargetGui
M.F.WatchFonts(M.UI.PillGui)

-- свечение инфо-панели лежит отдельным слоем рядом с ней
M.UI.PillGlowHost = Instance.new("Frame", M.UI.PillGui)
M.UI.PillGlowHost.Name = M.Services.H:GenerateGUID(false)
M.UI.PillGlowHost.BackgroundTransparency = 1
M.UI.PillGlowHost.BorderSizePixel = 0
M.UI.PillGlowHost.Active = false
M.UI.PillGlowHost.ZIndex = 0
M.UI.PillGlow = M.Style.AccentGlow(M.UI.PillGlowHost, 9, M.Style.SurfaceGlow, UDim.new(0.5, 0), 0)

M.UI.Pill = Instance.new("Frame", M.UI.PillGui)
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

-- бегущие символы: при смене текста меняются только изменившиеся буквы и цифры, старые уезжают вверх
function M.F.NewRoller(parent, order)
    local H = 18
    local R = {Cells = {}, Text = "", Color = M.State.PillTextCol}
    local host = Instance.new("Frame")
    host.Name = "Roller"
    host.BackgroundTransparency = 1
    host.BorderSizePixel = 0
    host.Size = UDim2.new(0, 0, 1, 0)
    host.AutomaticSize = Enum.AutomaticSize.X
    host.LayoutOrder = order
    local layout = Instance.new("UIListLayout", host)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    host.Parent = parent
    R.Host = host

    local function label(ch, y)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0, 0, 0, H)
        l.AutomaticSize = Enum.AutomaticSize.X
        l.Position = UDim2.fromOffset(0, y)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamMedium
        l.TextSize = 12
        l.TextColor3 = R.Color
        l.Text = ch
        return l
    end
    local function tween(inst, goal, dur)
        M.Services.T:Create(inst, TweenInfo.new(dur * M.Style.Scale(), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
    end
    local function newCell(ch, rollIn)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 0, 0, H)
        frame.AutomaticSize = Enum.AutomaticSize.X
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.ClipsDescendants = true
        local l = label(ch, rollIn and H or 0)
        l.Parent = frame
        frame.Parent = host
        if rollIn then tween(l, {Position = UDim2.fromOffset(0, 0)}, 0.28) end
        return {Frame = frame, Label = l, Char = ch}
    end
    -- крутятся только цифры: остальное меняется сразу
    local function isDigit(ch) return ch ~= nil and string.find(ch, "^%d$") ~= nil end
    local function roll(cell, ch)
        local old = cell.Label
        local was = cell.Char
        cell.Char = ch
        if not (isDigit(ch) or isDigit(was)) then old.Text = ch return end
        local new = label(ch, H)
        new.Parent = cell.Frame
        cell.Label = new
        tween(old, {Position = UDim2.fromOffset(0, -H), TextTransparency = 1}, 0.28)
        tween(new, {Position = UDim2.fromOffset(0, 0)}, 0.28)
        task.delay(0.28 * M.Style.Scale() + 0.05, function() old:Destroy() end)
    end
    local function drop(cell)
        if not isDigit(cell.Char) then cell.Frame:Destroy() return end
        tween(cell.Label, {Position = UDim2.fromOffset(0, -H), TextTransparency = 1}, 0.25)
        task.delay(0.25 * M.Style.Scale() + 0.05, function() cell.Frame:Destroy() end)
    end

    function R.Set(text)
        if text == R.Text then return end
        local animate = R.Text ~= ""
        R.Text = text
        local chars = {}
        for _, cp in utf8.codes(text) do chars[#chars + 1] = utf8.char(cp) end
        local old = R.Cells
        local no, nn = #old, #chars
        local p = 0
        while p < no and p < nn and old[p + 1].Char == chars[p + 1] do p = p + 1 end
        local s = 0
        while s < no - p and s < nn - p and old[no - s].Char == chars[nn - s] do s = s + 1 end
        local cells = {}
        for i = 1, p do cells[i] = old[i] end
        local oldMid, newMid = no - p - s, nn - p - s
        for j = 1, math.max(oldMid, newMid) do
            local o = old[p + j]
            if j <= oldMid and j <= newMid then
                roll(o, chars[p + j])
                cells[#cells + 1] = o
            elseif j <= newMid then
                cells[#cells + 1] = newCell(chars[p + j], animate and isDigit(chars[p + j]))
            else
                drop(o)
            end
        end
        for i = no - s + 1, no do cells[#cells + 1] = old[i] end
        -- порядок пишется только у сдвинувшихся символов: каждая запись заставляет движок заново раскладывать панель
        for i, c in ipairs(cells) do
            if c.Order ~= i then c.Order = i; c.Frame.LayoutOrder = i end
        end
        R.Cells = cells
    end

    function R.SetColor(col)
        R.Color = col
        for _, c in ipairs(R.Cells) do c.Label.TextColor3 = col end
    end
    return R
end

-- значки мини-меню: рисуются фреймами 14x14, цвет следует за темой
function M.F.PillIcon(kind)
    local box = Instance.new("Frame")
    box.Name = "Icon"
    box.Size = UDim2.fromOffset(14, 14)
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    local function fill(x, y, w, h, r)
        local f = Instance.new("Frame")
        f.Position = UDim2.fromOffset(x, y)
        f.Size = UDim2.fromOffset(w, h)
        f.BorderSizePixel = 0
        if r then Instance.new("UICorner", f).CornerRadius = r end
        M.Style.Bind(f, "BackgroundColor3", 0.1)
        f.Parent = box
        return f
    end
    local function outline(x, y, w, h, r)
        local f = Instance.new("Frame")
        f.Position = UDim2.fromOffset(x, y)
        f.Size = UDim2.fromOffset(w, h)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        if r then Instance.new("UICorner", f).CornerRadius = r end
        local st = Instance.new("UIStroke")
        st.Thickness = 1.5
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        st.Parent = f
        M.Style.Bind(st, "Color", 0.1)
        f.Parent = box
        return f
    end
    -- стрелка часов: отрезок от центра под углом
    local function hand(cx, cy, len, deg)
        local rad = math.rad(deg)
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.fromOffset(math.floor(cx + math.cos(rad) * len / 2 + 0.5), math.floor(cy + math.sin(rad) * len / 2 + 0.5))
        f.Size = UDim2.fromOffset(len + 1, 2)
        f.Rotation = deg
        f.BorderSizePixel = 0
        Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
        M.Style.Bind(f, "BackgroundColor3", 0.1)
        f.Parent = box
    end
    local round = UDim.new(1, 0)
    if kind == "fps" then
        -- монитор
        outline(1, 2, 12, 8, UDim.new(0, 2))
        fill(6, 10, 2, 2)
        fill(3, 12, 8, 2, round)
    elseif kind == "ping" then
        -- столбики сигнала
        for i = 1, 4 do
            local h = 3 + i * 2 + (i == 4 and 1 or 0)
            fill(1 + (i - 1) * 3, 14 - h, 2, h, UDim.new(0, 1))
        end
    elseif kind == "mem" then
        -- микросхема
        outline(4, 4, 6, 6, UDim.new(0, 1))
        for _, p in ipairs({5, 8}) do
            fill(1, p, 2, 1); fill(11, p, 2, 1); fill(p, 1, 1, 2); fill(p, 11, 1, 2)
        end
    elseif kind == "clock" then
        outline(1, 1, 12, 12, round)
        hand(7, 7, 4, -90)
        hand(7, 7, 3, 0)
    elseif kind == "session" then
        -- секундомер
        outline(2, 3, 10, 10, round)
        fill(5, 0, 4, 2, UDim.new(0, 1))
        hand(7, 8, 3, -60)
    elseif kind == "user" then
        fill(5, 1, 4, 4, round)
        fill(2, 7, 10, 6, UDim.new(0, 4))
    elseif kind == "lock" then
        outline(4, 1, 6, 7, UDim.new(0, 3))
        fill(2, 6, 10, 7, UDim.new(0, 2))
    end
    return box
end

-- название отдельной надписью, дальше части со значком и бегущими цифрами
M.UI.PillBrand = Instance.new("TextLabel", M.UI.Pill)
M.UI.PillBrand.Size = UDim2.new(0, 0, 1, 0); M.UI.PillBrand.AutomaticSize = Enum.AutomaticSize.X; M.UI.PillBrand.LayoutOrder = 3
M.UI.PillBrand.BackgroundTransparency = 1; M.UI.PillBrand.TextColor3 = M.State.PillTextCol; M.UI.PillBrand.Font = Enum.Font.GothamBold; M.UI.PillBrand.TextSize = 12
M.UI.PillBrand.Text = "matsysense"

M.UI.PillSegs = {}
do
    local function seg(id, order, icon, withValue)
        local f = Instance.new("Frame")
        f.Name = id
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.Size = UDim2.new(0, 0, 1, 0)
        f.AutomaticSize = Enum.AutomaticSize.X
        f.LayoutOrder = order
        local lay = Instance.new("UIListLayout", f)
        lay.FillDirection = Enum.FillDirection.Horizontal
        lay.VerticalAlignment = Enum.VerticalAlignment.Center
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Padding = UDim.new(0, 5)
        -- тонкий разделитель перед частью
        local sep = Instance.new("Frame")
        sep.Size = UDim2.fromOffset(1, 14)
        sep.BackgroundColor3 = M.Style.Stroke
        sep.BackgroundTransparency = 0.1
        sep.BorderSizePixel = 0
        sep.LayoutOrder = 0
        sep.Parent = f
        local ic = M.F.PillIcon(icon)
        ic.LayoutOrder = 1
        ic.Parent = f
        local roll = withValue and M.F.NewRoller(f, 2) or nil
        f.Parent = M.UI.Pill
        M.UI.PillSegs[id] = {Frame = f, Roll = roll}
    end
    seg("lock", 10, "lock", false)
    seg("user", 11, "user", true)
    seg("fps", 12, "fps", true)
    seg("ping", 13, "ping", true)
    seg("mem", 14, "mem", true)
    seg("clock", 15, "clock", true)
    seg("session", 16, "session", true)
end

-- значения мини-меню; цифры прокручиваются только у тех символов, что изменились
function M.F.PillUpdate()
    local S, segs = M.State, M.UI.PillSegs
    -- в режиме музыки вместо обычных частей показывается трек
    local spot = M.F.MusicShown and M.F.MusicShown() or false
    if M.UI.PillAvatar.Visible == spot then M.UI.PillAvatar.Visible = not spot end
    if M.UI.PillBrand.Visible == spot then M.UI.PillBrand.Visible = not spot end
    local function set(id, show, text)
        local s = segs[id]
        show = show and not spot
        if s.Frame.Visible ~= show then s.Frame.Visible = show end
        if show and s.Roll and text then s.Roll.Set(text) end
    end
    local function clock(sec)
        sec = math.max(math.floor(sec), 0)
        return string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60)
    end
    set("lock", S.PillLocked)
    set("user", S.PillShowUser, M.LP.Name)
    set("fps", true, tostring(M.Run.CurFPS or 0))
    local ping = M.F.PingSec and math.floor(M.F.PingSec() * 1000 + 0.5) or 0
    set("ping", S.PillShowPing ~= false, ping > 0 and tostring(ping) or "--")
    set("mem", S.PillShowMem, tostring(M.Data.PillMem or 0))
    local now = os.date("*t", os.time())
    set("clock", S.PillShowClock, string.format("%02d:%02d:%02d", now.hour, now.min, now.sec))
    set("session", S.PillShowTime, clock(M.Run.Uptime or 0))
end
M.F.PillUpdate()

-- цвет текста панели; значки остаются цвета темы
function M.F.PillSetColor(col)
    M.UI.PillBrand.TextColor3 = col
    if M.F.MusicRecolor then M.F.MusicRecolor(col) end
    for _, s in pairs(M.UI.PillSegs) do
        if s.Roll then s.Roll.SetColor(col) end
    end
end

-- свечение и положение: слой повторяет панель
do
    local pill, host = M.UI.Pill, M.UI.PillGlowHost
    -- стекло лежит поверх панели отдельным слоем
    local glassHost = Instance.new("Frame", M.UI.PillGui)
    glassHost.Name = M.Services.H:GenerateGUID(false)
    glassHost.BackgroundTransparency = 1
    glassHost.BorderSizePixel = 0
    glassHost.Active = false
    glassHost.ZIndex = 2
    M.UI.PillGlassHost = glassHost
    M.UI.PillGlass = M.Style.BuildGlass(glassHost, UDim.new(0.5, 0), {ZIndex = 2, Ios = true})
    local function syncGlow()
        host.AnchorPoint = pill.AnchorPoint
        host.Position = pill.Position
        host.Size = UDim2.fromOffset(pill.AbsoluteSize.X, pill.AbsoluteSize.Y)
        glassHost.AnchorPoint = pill.AnchorPoint
        glassHost.Position = pill.Position
        glassHost.Size = host.Size
    end
    pill:GetPropertyChangedSignal("Position"):Connect(syncGlow)
    pill:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncGlow)
    syncGlow()
end

-- стиль инфо-панели
function M.F.StylePill(animate)
    local pill = M.UI.Pill
    if not pill then return end
    local ios = M.State.Ios26On
    local locked = M.State.PillLocked

    M.UI.PillCorner.CornerRadius = ios and UDim.new(0.5, 0) or UDim.new(0, 10)
    if M.UI.PillGlass then
        M.UI.PillGlass.SetRadius(ios and UDim.new(0.5, 0) or UDim.new(0, 10))
        M.UI.PillGlass.SetVisible(M.State.GlassOn and ios)
    end
    pill.BackgroundColor3 = M.State.PillBg
    pill.BackgroundTransparency = ios and math.max(M.State.PillAlpha, 0.12) or M.State.PillAlpha

    local strokeColor, thickness
    if ios then
        -- кромка
        strokeColor = Color3.fromRGB(255, 255, 255)
        thickness = math.max(1.2, M.State.PillBorderThick)
        M.UI.PillRim.Enabled = true
        M.UI.PillRim.Color = ColorSequence.new(
            locked and M.State.Accent or M.Style.AccentMix(0.45),
            locked and M.State.Accent:Lerp(M.Style.Stroke, 0.4) or M.Style.Stroke)
        M.UI.PillRim.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, locked and 0.05 or 0.22),
            NumberSequenceKeypoint.new(0.5, 0.7),
            NumberSequenceKeypoint.new(1, 0.4)
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

    -- свечение
    if M.UI.PillGlow then
        M.UI.PillGlowHost.Visible = ios
        M.UI.PillGlow.Set(locked and M.Style.SurfaceGlow * 2 or M.Style.SurfaceGlow, animate and 0.3 or 0)
    end
end
M.F.StylePill()

do
    local pDragStart, pStartPos, isPillDragging = nil, nil, false
    local clickDownPos = nil
    -- плавное перемещение, как у окна и виджетов
    local pTargetX, pTargetY, pCurX, pCurY = 0, 0, 0, 0
    local pillSmooth
    local function startPillSmooth()
        if pillSmooth then return end
        pillSmooth = M.Track(M.Services.R.RenderStepped:Connect(function(dt)
            local blend = 1 - math.exp(-dt * 18 / M.Style.Scale())
            pCurX = pCurX + (pTargetX - pCurX) * blend
            pCurY = pCurY + (pTargetY - pCurY) * blend
            local settled = not isPillDragging and math.abs(pTargetX - pCurX) < 0.3 and math.abs(pTargetY - pCurY) < 0.3
            if settled then pCurX, pCurY = pTargetX, pTargetY end
            M.UI.Pill.Position = UDim2.new(pStartPos.X.Scale, pCurX, pStartPos.Y.Scale, pCurY)
            if settled then
                M.F.Untrack(pillSmooth)
                pillSmooth = nil
            end
        end))
    end
    M.UI.Pill.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton2 then
            M.State.PillLocked = not M.State.PillLocked
            M.F.StylePill(true)
            M.F.PillUpdate()
            return
        end
        if (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
            clickDownPos = inp.Position
            if not M.State.PillLocked then
                isPillDragging = true; pDragStart = inp.Position; pStartPos = M.UI.Pill.Position
                pCurX, pCurY = pStartPos.X.Offset, pStartPos.Y.Offset
                pTargetX, pTargetY = pCurX, pCurY
                startPillSmooth()
            end
        end
    end)
    M.Conn(M.Services.U.InputChanged, function(inp)
        if isPillDragging and not M.State.PillLocked and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - pDragStart
            pTargetX, pTargetY = pStartPos.X.Offset + d.X, pStartPos.Y.Offset + d.Y
        end
    end)
    M.Conn(M.Services.U.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            -- нажатие на кнопку плеера мини-меню не открывает
            if clickDownPos and (inp.Position - clickDownPos).Magnitude < 6 and os.clock() - (M.Data.PillBtnAt or -10) > 0.4 then
                if M.UI.Main and not M.UI.Main.Visible then M.F.OpenMenu() end
            end
            clickDownPos = nil
            isPillDragging = false
        end
    end)
end

-- наведение
M.UI.Pill.MouseEnter:Connect(function()
    if M.UI.PillGlow and M.State.Ios26On then M.UI.PillGlow.Set(M.Style.SurfaceGlow * 2, 0.25) end
end)
M.UI.Pill.MouseLeave:Connect(function() M.F.StylePill(true) end)

task.spawn(function()
    while task.wait(1) do
        if M.Run.IsShutDown then break end
        -- по часам: при лагах task.wait растягивается и сумма шагов отстаёт
        M.Run.Uptime = os.clock() - M.Run.StartedAt

        local totalMem = M.Data.PillMem or 0
        if M.State.PillShowMem and os.clock() - (M.Data.PillMemAt or -10) >= 5 then
            M.Data.PillMemAt = os.clock()
            local okMem, mem = pcall(function() return M.Services.S:GetTotalMemoryUsageMb() end)
            totalMem = okMem and math.round(mem) or totalMem
            M.Data.PillMem = totalMem
        end
        local up = M.Run.Uptime
        M.F.PillUpdate()
        if M.UI.PUptime then
            local uptimeText = string.format(M.Translate("Profile_Uptime"), math.floor(up / 3600), math.floor((up % 3600) / 60), math.floor(up % 60))
            if M.UI.PUptime.Text ~= uptimeText then M.UI.PUptime.Text = uptimeText end
        end
    end
end)

end}

-- [36/69] Музыка: мини-меню и отдельный виджет
MODULES[#MODULES + 1] = {"36. Музыка: мини-меню и отдельный виджет", function(M, __X)
-- ==============================================================================
-- [ МУЗЫКА: ОБЛОЖКА, ТРЕК, ПРОГРЕСС И КНОПКИ ]
-- Играющее читает у Windows маленький помощник (PowerShell): Spotify, SoundCloud и YouTube Music в браузере, любой плеер.
-- Скрипт сам создаёт файлы помощника в папке workspace исполнителя.
-- ==============================================================================
local MP = {Gen = 0, Delay = 2, CoverFiles = {}, CoverN = 0, Playing = false, Progress = 0, Duration = 0,
    BaseAt = 0, Title = "", Artist = "", StatusKey = "Music_Loading", FrameAt = 0}
M.Data.Music = MP
local PILL_H, PILL_MUSIC_H = 34, 46
local LOCAL = "http://127.0.0.1:8765"
local LOCAL_HEADERS = {["X-Msense"] = "1"}

-- ---------------------------------------------------------------- файлы помощника
local HELPER_PS1 = [=[
# matsysense media helper v2
# Reads what is playing in Windows (Spotify, SoundCloud or YouTube Music in a browser, any player)
# and gives it to the script at http://127.0.0.1:8765. No accounts, tokens or Premium are needed.
# Stops by itself when Roblox is closed. Use -KeepAlive to keep it running.
param([int]$Port = 8765, [switch]$KeepAlive)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime

# waiting for Windows async operations from PowerShell 5.1
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]
function Await($operation, [Type]$resultType) {
    $task = $asTask.MakeGenericMethod($resultType).Invoke($null, @($operation))
    [void]$task.Wait(-1)
    return $task.Result
}

[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
[void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType = WindowsRuntime]
[void][Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType = WindowsRuntime]

$managerType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
$propsType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]
$streamType = [Windows.Storage.Streams.IRandomAccessStreamWithContentType]
$manager = Await ($managerType::RequestAsync()) $managerType

# the session that is playing; if nothing plays, the one Windows considers current
function Get-ActiveSession {
    $current = $manager.GetCurrentSession()
    $paused = $null
    foreach ($s in $manager.GetSessions()) {
        $status = $s.GetPlaybackInfo().PlaybackStatus.ToString()
        if ($status -eq 'Playing') { return $s }
        if (-not $paused -and $status -eq 'Paused') { $paused = $s }
    }
    if ($current) { return $current }
    return $paused
}

$coverCache = @{ Key = ''; Bytes = $null; Type = 'image/jpeg'; Hash = ''; PrevHash = ''; Since = [DateTime]::MinValue }
$readStreamMethod = [System.IO.WindowsRuntimeStreamExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsStreamForRead' -and $_.GetParameters().Count -eq 1 } | Select-Object -First 1
$md5 = [System.Security.Cryptography.MD5]::Create()

# Windows often still gives the picture of the previous track for a moment after a change:
# for the first seconds the picture is read again and a copy of the old one is not accepted
function Get-Cover($props) {
    $key = "$($props.Title)|$($props.Artist)|$($props.AlbumTitle)"
    $now = Get-Date
    if ($coverCache.Key -ne $key) {
        $coverCache.PrevHash = $coverCache.Hash
        $coverCache.Key = $key
        $coverCache.Since = $now
        $coverCache.Bytes = $null
        $coverCache.Hash = ''
    }
    $age = ($now - $coverCache.Since).TotalSeconds
    if ($coverCache.Bytes -and $age -gt 8) { return }
    if (-not $props.Thumbnail) { $coverCache.Bytes = $null; $coverCache.Hash = ''; return }
    try {
        $stream = Await ($props.Thumbnail.OpenReadAsync()) $streamType
        # the Windows stream is opened through reflection: PowerShell does not see its members
        $reader = $readStreamMethod.Invoke($null, @($stream))
        $memory = New-Object System.IO.MemoryStream
        $reader.CopyTo($memory)
        $reader.Dispose()
        $bytes = $memory.ToArray()
        $hash = [System.BitConverter]::ToString($md5.ComputeHash($bytes)).Replace('-', '')
        if ($bytes.Length -lt 200 -or ($hash -eq $coverCache.PrevHash -and $age -lt 6)) {
            $coverCache.Bytes = $null; $coverCache.Hash = ''
            return
        }
        $coverCache.Bytes = $bytes
        $coverCache.Hash = $hash
        $coverCache.Type = if ($bytes[0] -eq 0x89 -and $bytes[1] -eq 0x50) { 'image/png' } else { 'image/jpeg' }
    } catch { $coverCache.Bytes = $null; $coverCache.Hash = '' }
}

function Get-Now {
    $session = Get-ActiveSession
    if (-not $session) { return @{ ok = $true; active = $false } }
    $props = Await ($session.TryGetMediaPropertiesAsync()) $propsType
    $info = $session.GetPlaybackInfo()
    $line = $session.GetTimelineProperties()
    $playing = $info.PlaybackStatus.ToString() -eq 'Playing'
    $duration = ($line.EndTime - $line.StartTime).TotalSeconds
    $position = ($line.Position - $line.StartTime).TotalSeconds
    # the position is recorded at the moment of the last update; while playing, add the time since then
    if ($playing) { $position += ([DateTimeOffset]::UtcNow - $line.LastUpdatedTime).TotalSeconds }
    if ($duration -gt 0) { $position = [Math]::Min($position, $duration) }
    $position = [Math]::Max($position, 0)
    Get-Cover $props
    return @{
        ok = $true; active = $true; app = [string]$session.SourceAppUserModelId
        title = [string]$props.Title; artist = [string]$props.Artist; album = [string]$props.AlbumTitle
        playing = $playing; position = [Math]::Round($position, 2); duration = [Math]::Round([Math]::Max($duration, 0), 2)
        cover = [bool]$coverCache.Bytes; coverKey = $coverCache.Key; coverHash = $coverCache.Hash
    }
}

function Invoke-Control($command) {
    $session = Get-ActiveSession
    if (-not $session) { return @{ ok = $false; error = 'no session' } }
    $done = $false
    switch ($command) {
        'playpause' { $done = Await ($session.TryTogglePlayPauseAsync()) ([bool]) }
        'next' { $done = Await ($session.TrySkipNextAsync()) ([bool]) }
        'prev' { $done = Await ($session.TrySkipPreviousAsync()) ([bool]) }
        default { return @{ ok = $false; error = 'bad command' } }
    }
    return @{ ok = [bool]$done }
}

function Send-Response($stream, [int]$code, [string]$contentType, [byte[]]$body) {
    $status = switch ($code) { 200 { 'OK' } 403 { 'Forbidden' } 404 { 'Not Found' } default { 'Error' } }
    $head = "HTTP/1.1 $code $status`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
    $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head)
    $stream.Write($headBytes, 0, $headBytes.Length)
    if ($body.Length -gt 0) { $stream.Write($body, 0, $body.Length) }
}
function Send-Json($stream, $object, [int]$code = 200) {
    $json = $object | ConvertTo-Json -Depth 4 -Compress
    Send-Response $stream $code 'application/json; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($json))
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
try { $listener.Start() } catch { exit 1 }

$started = Get-Date
$seenRoblox = $false
$lastSeen = Get-Date
$nextCheck = Get-Date

while ($true) {
    if (-not $listener.Pending()) {
        Start-Sleep -Milliseconds 60
        if (-not $KeepAlive -and (Get-Date) -ge $nextCheck) {
            $nextCheck = (Get-Date).AddSeconds(10)
            if (Get-Process -Name 'Roblox*','Windows10Universal' -ErrorAction SilentlyContinue) { $seenRoblox = $true; $lastSeen = Get-Date }
            elseif ($seenRoblox -and ((Get-Date) - $lastSeen).TotalSeconds -gt 90) { break }
            elseif (-not $seenRoblox -and ((Get-Date) - $started).TotalMinutes -gt 60) { break }
        }
        continue
    }
    $client = $listener.AcceptTcpClient()
    try {
        $client.ReceiveTimeout = 2000
        $stream = $client.GetStream()
        $buffer = New-Object byte[] 4096
        $read = $stream.Read($buffer, 0, $buffer.Length)
        $request = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $read)
        $first = ($request -split "`r`n")[0]
        $path = if ($first -match '^GET\s+(\S+)') { $Matches[1] } else { '' }
        # only the script sends this header: web pages in a browser get nothing
        if ($request -notmatch '(?im)^X-Msense:\s*1') {
            Send-Json $stream @{ ok = $false; error = 'forbidden' } 403
        } elseif ($path -like '/now*') {
            Send-Json $stream (Get-Now)
        } elseif ($path -like '/cover*') {
            if ($coverCache.Bytes) { Send-Response $stream 200 $coverCache.Type $coverCache.Bytes } else { Send-Json $stream @{ ok = $false } 404 }
        } elseif ($path -like '/ctl*') {
            $cmd = if ($path -match 'cmd=(\w+)') { $Matches[1] } else { '' }
            Send-Json $stream (Invoke-Control $cmd)
        } else {
            Send-Json $stream @{ ok = $false; error = 'not found' } 404
        }
    } catch {
        try { Send-Json $stream @{ ok = $false; error = $_.Exception.Message } 500 } catch {}
    } finally {
        $client.Close()
    }
}
$listener.Stop()
]=]

-- запуск без окна: файл закрывается сразу, помощник живёт в фоне и сам останавливается, когда закрыт Roblox (с параметром keep - не останавливается)
local START_BAT = [=[
@echo off
rem matsysense media helper: starts the helper in the background
set "KEEP="
if /i "%~1"=="keep" set "KEEP=-KeepAlive"
start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0matsysense_media_helper.ps1" %KEEP%
]=]

-- один раз: ставит запуск помощника вместе с Windows (ярлык в автозагрузке) и сразу запускает его; дальше ничего запускать не нужно.
-- убрать: Win+R, shell:startup, удалить ярлык
local AUTOSTART_BAT = [=[
@echo off
rem matsysense media helper: start with Windows (creates a shortcut in the Startup folder) and start it now
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Startup')+'\matsysense media helper.lnk'); $s.TargetPath='%~dp0matsysense_media_start.bat'; $s.Arguments='keep'; $s.WorkingDirectory='%~dp0'; $s.WindowStyle=7; $s.Save()"
call "%~dp0matsysense_media_start.bat" keep
echo Done. The helper is running and will start with Windows. To remove: press Win+R, type shell:startup and delete the shortcut.
timeout /t 6 >nul
]=]

local function crlf(s) return (string.gsub(s, "\r?\n", "\r\n")) end
local function helperFiles()
    return {
        -- BOM, чтобы PowerShell 5.1 читал файл как UTF-8
        ["matsysense_media_helper.ps1"] = "\239\187\191" .. crlf(HELPER_PS1),
        ["matsysense_media_start.bat"] = crlf(START_BAT),
        ["matsysense_media_autostart.bat"] = crlf(AUTOSTART_BAT),
    }
end

-- создаёт файлы в workspace; уже лежащие и совпадающие не переписываются. Возвращает: записано ли что-то, умеет ли исполнитель писать файлы
function MP.ensureHelper(force)
    local write = M.Cap.Fn("writefile")
    if not write then return false, false end
    local isfile, readfile = M.Cap.Fn("isfile"), M.Cap.Fn("readfile")
    local wrote = false
    for name, content in pairs(helperFiles()) do
        local same = false
        if not force and isfile and readfile then
            local ok, result = pcall(function() return isfile(name) and readfile(name) == content end)
            same = ok and result == true
        end
        if not same and pcall(write, name, content) then wrote = true end
    end
    return wrote, true
end

-- ---------------------------------------------------------------- сеть
-- универсальный запрос: у исполнителей он называется по-разному
local function httpFn()
    for _, path in ipairs({"syn.request", "http.request", "http_request", "request", "fluxus.request"}) do
        local fn = M.Cap.Fn(path)
        if fn then return fn end
    end
    return nil
end

local function request(opts)
    local fn = httpFn()
    if not fn then return nil, "nohttp" end
    local ok, res = pcall(fn, opts)
    if not ok or type(res) ~= "table" then return nil, "net" end
    local code = tonumber(res.StatusCode or res.status_code or res.Status) or 0
    return {Code = code, Body = res.Body or res.body or "", Headers = res.Headers or res.headers or {}}
end

local function setStatus(key)
    MP.StatusKey = key
    MP.Playing = false
    MP.Dirty = true
end

-- ---------------------------------------------------------------- обложка
function MP.fetchCover(url, token, headers)
    local write, asset = M.Cap.Fn("writefile"), M.Cap.Fn("getcustomasset") or M.Cap.Fn("getsynasset")
    if not (write and asset) then return end
    MP.CoverBusy = true
    task.spawn(function()
        local res = request({Url = url, Method = "GET", Headers = headers})
        MP.CoverBusy = false
        if not res or res.Code ~= 200 or #res.Body < 200 then
            -- не вышло: следующий опрос попробует ещё раз (не больше трёх раз на картинку)
            MP.CoverFailed = (MP.CoverFailed or 0) + 1
            if MP.CoverFailed < 3 then MP.CoverFetched = nil end
            return
        end
        MP.CoverN = MP.CoverN + 1
        -- у каждой картинки своё имя: движок кэширует по имени файла, и при повторе имени показывал бы старую
        local ext = string.sub(res.Body, 1, 4) == "\137PNG" and ".png" or ".jpg"
        local name = "msense_cover_" .. MP.CoverN .. ext
        if not pcall(write, name, res.Body) then return end
        MP.CoverFiles[name] = MP.CoverN
        local ok, id = pcall(asset, name)
        -- за время загрузки трек мог смениться
        if ok and id and MP.CoverWanted == token then
            MP.CoverAsset, MP.CoverDirty = id, true
        end
        -- старые файлы удаляются, последние три остаются
        local del = M.Cap.Fn("delfile")
        if del then
            for old, n in pairs(MP.CoverFiles) do
                if n <= MP.CoverN - 3 then
                    pcall(del, old)
                    MP.CoverFiles[old] = nil
                end
            end
        end
    end)
end
-- ---------------------------------------------------------------- опрос помощника
function MP.pollOnce()
    local res, err = request({Url = LOCAL .. "/now", Method = "GET", Headers = LOCAL_HEADERS})
    if not res then
        setStatus(err == "nohttp" and "Music_NoHttp" or "Music_NoHelper")
        -- помощник не отвечает: опрос реже и реже (у части исполнителей запрос блокирует игру, пока ждёт отказа)
        MP.Fails = (MP.Fails or 0) + 1
        MP.Delay = err == "nohttp" and 10 or math.min(3 * 2 ^ (MP.Fails - 1), 10)
        return
    end
    MP.Fails = 0
    if res.Code ~= 200 then
        setStatus(res.Code == 403 and "Music_Old" or "Music_NoHelper")
        MP.Delay = 4
        return
    end
    local ok, data = pcall(function() return M.Services.H:JSONDecode(res.Body) end)
    if not ok or type(data) ~= "table" or not data.active then
        setStatus("Music_Nothing")
        MP.Delay = 2
        return
    end
    MP.StatusKey = nil
    MP.Title, MP.Artist = tostring(data.title or ""), tostring(data.artist or "")
    MP.Duration = tonumber(data.duration) or 0
    MP.Progress = tonumber(data.position) or 0
    MP.BaseAt = os.clock()
    MP.Playing = data.playing == true
    MP.Dirty = true
    local id = tostring(data.coverKey or (MP.Title .. MP.Artist))
    if MP.TrackId ~= id then
        MP.TrackId = id
        -- обложка прошлого трека не остаётся на новом
        MP.CoverAsset, MP.CoverDirty, MP.CoverFetched, MP.CoverWanted, MP.CoverFailed = nil, true, nil, nil, 0
    end
    -- картинка появляется позже названия и бывает заменена после первой отдачи: качается при каждой смене её отпечатка
    local token = data.cover and (id .. "|" .. tostring(data.coverHash or "")) or nil
    if token and MP.CoverFetched ~= token and not MP.CoverBusy then
        MP.CoverFetched, MP.CoverWanted = token, token
        MP.fetchCover(LOCAL .. "/cover", token, LOCAL_HEADERS)
    elseif not token and MP.CoverAsset then
        MP.CoverAsset, MP.CoverDirty, MP.CoverFetched, MP.CoverWanted = nil, true, nil, nil
    end
    MP.Delay = 2
end

local function pollLoop(gen)
    while MP.Gen == gen and not M.Run.IsShutDown and M.State.MusicOn do
        MP.pollOnce()
        local untilAt = os.clock() + MP.Delay
        MP.Wake = nil
        while MP.Gen == gen and not M.Run.IsShutDown and os.clock() < untilAt do
            if MP.Wake and os.clock() >= MP.Wake then break end
            task.wait(0.25)
        end
    end
end

-- нажали кнопку или сменили трек: опрос раньше срока
function M.F.MusicKick() MP.Wake = os.clock() + 0.3; MP.Fails = 0 end

-- ---------------------------------------------------------------- управление
function MP.control(kind)
    task.spawn(function()
        if kind == "toggle" then
            -- сразу показываем новое состояние, не дожидаясь ответа
            MP.Progress = MP.Playing and math.min(MP.Progress + (os.clock() - MP.BaseAt), MP.Duration) or MP.Progress
            MP.BaseAt = os.clock()
            MP.Playing = not MP.Playing
            MP.Dirty = true
        else
            -- с какой стороны выезжает новый трек
            MP.FlipDir = kind == "next" and 1 or -1
        end
        local cmd = kind == "toggle" and "playpause" or (kind == "next" and "next" or "prev")
        local res = request({Url = LOCAL .. "/ctl?cmd=" .. cmd, Method = "GET", Headers = LOCAL_HEADERS})
        if not res or res.Code ~= 200 then
            MP.Notice, MP.NoticeAt, MP.Dirty = "Music_NoHelper", os.clock(), true
        end
        M.F.MusicKick()
    end)
end

-- ---------------------------------------------------------------- значки кнопок
-- значки рисуются прямо в скрипте: PNG с мягкими краями (16 проб на пиксель), без внешних файлов и ссылок
local ICON_N, ICON_SS = 36, 4

local crcTable
local function crc32(s)
    local bxor, band, rshift = bit32.bxor, bit32.band, bit32.rshift
    if not crcTable then
        crcTable = {}
        for i = 0, 255 do
            local c = i
            for _ = 1, 8 do
                if band(c, 1) == 1 then c = bxor(0xEDB88320, rshift(c, 1)) else c = rshift(c, 1) end
            end
            crcTable[i] = c
        end
    end
    local c = 0xFFFFFFFF
    for i = 1, #s do c = bxor(crcTable[band(bxor(c, string.byte(s, i)), 255)], rshift(c, 8)) end
    return bxor(c, 0xFFFFFFFF)
end

local function be32(n)
    local band, rshift = bit32.band, bit32.rshift
    return string.char(band(rshift(n, 24), 255), band(rshift(n, 16), 255), band(rshift(n, 8), 255), band(n, 255))
end

local function pngChunk(kind, data)
    return be32(#data) .. kind .. data .. be32(crc32(kind .. data))
end

-- белая картинка n x n, прозрачность каждой точки берётся из alpha[y][x] (0..255); данные не сжимаются
local function encodePng(n, alpha)
    local cache, rows = {}, {}
    for y = 1, n do
        local parts = {"\0"}
        local row = alpha[y]
        for x = 1, n do
            local a = row[x]
            local ch = cache[a]
            if not ch then ch = string.char(255, 255, 255, a); cache[a] = ch end
            parts[x + 1] = ch
        end
        rows[y] = table.concat(parts)
    end
    local raw = table.concat(rows)
    local s1, s2 = 1, 0
    for i = 1, #raw do
        s1 = (s1 + string.byte(raw, i)) % 65521
        s2 = (s2 + s1) % 65521
    end
    local blocks, pos = {"\120\1"}, 1
    while pos <= #raw do
        local len = math.min(65535, #raw - pos + 1)
        local nlen = 65535 - len
        blocks[#blocks + 1] = string.char((pos + len > #raw) and 1 or 0, len % 256, math.floor(len / 256), nlen % 256, math.floor(nlen / 256))
            .. string.sub(raw, pos, pos + len - 1)
        pos = pos + len
    end
    blocks[#blocks + 1] = be32(s2 * 65536 + s1)
    return "\137PNG\r\n\26\n" .. pngChunk("IHDR", be32(n) .. be32(n) .. "\8\6\0\0\0") .. pngChunk("IDAT", table.concat(blocks)) .. pngChunk("IEND", "")
end

-- скруглённый треугольник: внутренний (уменьшенный на r) плюс все точки не дальше r от него
local function roundedTri(ax, ay, bx, by, cx, cy, r)
    local la = math.sqrt((bx - cx) ^ 2 + (by - cy) ^ 2)
    local lb = math.sqrt((ax - cx) ^ 2 + (ay - cy) ^ 2)
    local lc = math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
    local per = la + lb + lc
    local ix, iy = (la * ax + lb * bx + lc * cx) / per, (la * ay + lb * by + lc * cy) / per
    local area = math.abs((bx - ax) * (cy - ay) - (cx - ax) * (by - ay)) / 2
    local ri = area / (per / 2)
    local k = math.max(ri - r, 0) / ri
    local x1, y1 = ix + (ax - ix) * k, iy + (ay - iy) * k
    local x2, y2 = ix + (bx - ix) * k, iy + (by - iy) * k
    local x3, y3 = ix + (cx - ix) * k, iy + (cy - iy) * k
    local function side(px, py, qx, qy, x, y) return (qx - px) * (y - py) - (qy - py) * (x - px) end
    local function seg(px, py, qx, qy, x, y)
        local dx, dy = qx - px, qy - py
        local u = math.clamp(((x - px) * dx + (y - py) * dy) / (dx * dx + dy * dy), 0, 1)
        local ex, ey = x - (px + dx * u), y - (py + dy * u)
        return ex * ex + ey * ey
    end
    local rr = r * r
    return function(x, y)
        local s1, s2, s3 = side(x1, y1, x2, y2, x, y), side(x2, y2, x3, y3, x, y), side(x3, y3, x1, y1, x, y)
        if (s1 >= 0 and s2 >= 0 and s3 >= 0) or (s1 <= 0 and s2 <= 0 and s3 <= 0) then return true end
        return seg(x1, y1, x2, y2, x, y) <= rr or seg(x2, y2, x3, y3, x, y) <= rr or seg(x3, y3, x1, y1, x, y) <= rr
    end
end

local function roundedRect(x0, y0, x1, y1, r)
    local ix0, iy0, ix1, iy1, rr = x0 + r, y0 + r, x1 - r, y1 - r, r * r
    return function(x, y)
        local dx = math.max(ix0 - x, 0, x - ix1)
        local dy = math.max(iy0 - y, 0, y - iy1)
        return dx * dx + dy * dy <= rr
    end
end

local ICON_SHAPES = {
    play = function() return {roundedTri(0.24, 0.12, 0.24, 0.88, 0.90, 0.5, 0.07)} end,
    pause = function() return {roundedRect(0.20, 0.12, 0.42, 0.88, 0.07), roundedRect(0.58, 0.12, 0.80, 0.88, 0.07)} end,
    next = function() return {roundedTri(0.10, 0.18, 0.10, 0.82, 0.66, 0.5, 0.05), roundedRect(0.72, 0.18, 0.90, 0.82, 0.05)} end,
    prev = function() return {roundedTri(0.90, 0.18, 0.90, 0.82, 0.34, 0.5, 0.05), roundedRect(0.10, 0.18, 0.28, 0.82, 0.05)} end,
}

local function renderIcon(shapes)
    local n, ss = ICON_N, ICON_SS
    local alpha = {}
    for y = 1, n do
        local row = {}
        for x = 1, n do
            local hits = 0
            for sy = 0, ss - 1 do
                local fy = (y - 1 + (sy + 0.5) / ss) / n
                for sx = 0, ss - 1 do
                    local fx = (x - 1 + (sx + 0.5) / ss) / n
                    for i = 1, #shapes do
                        if shapes[i](fx, fy) then hits = hits + 1 break end
                    end
                end
            end
            row[x] = math.floor(255 * hits / (ss * ss) + 0.5)
        end
        alpha[y] = row
    end
    return alpha
end

-- рисует четыре значка и кладёт их в workspace; не вышло (нет writefile, getcustomasset) - кнопки рисуются полосками
function MP.makeIcons()
    if MP.Icons then return end
    local write, asset = M.Cap.Fn("writefile"), M.Cap.Fn("getcustomasset") or M.Cap.Fn("getsynasset")
    if not (write and asset and bit32) then return end
    local made, files = {}, {}
    local ok = pcall(function()
        for name, make in pairs(ICON_SHAPES) do
            local file = "msense_icon_" .. name .. ".png"
            write(file, encodePng(ICON_N, renderIcon(make())))
            files[file] = true
            made[name] = asset(file)
        end
    end)
    MP.IconFiles = files
    if ok and made.play and made.pause and made.next and made.prev then MP.Icons = made end
end

-- ---------------------------------------------------------------- вид
-- состояние в мини-меню: показывать ли трек вместо обычных частей
function M.F.MusicShown()
    return M.State.MusicOn == true and M.State.MusicMode == true and MP.Ui ~= nil and not MP.Ui.Widget
end

-- виден ли плеер сейчас (в мини-меню или отдельным виджетом)
function MP.visible()
    local ui = MP.Ui
    return ui ~= nil and (ui.Widget == true or M.F.MusicShown())
end

local function icon(parent, w, h)
    local box = Instance.new("Frame")
    box.Size = UDim2.fromOffset(w, h)
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.fromScale(0.5, 0.5)
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Parent = parent
    return box
end
local function bar(parent, x, y, w, h, r)
    local f = Instance.new("Frame")
    f.Position = UDim2.fromOffset(x, y)
    f.Size = UDim2.fromOffset(w, h)
    f.BorderSizePixel = 0
    if r then Instance.new("UICorner", f).CornerRadius = r end
    M.Style.Bind(f, "BackgroundColor3", 0.1)
    f.Parent = parent
    return f
end
-- треугольник из строк по 1 px
local function triangle(parent, x, y, w, h, right)
    for row = 0, h - 1 do
        local rel = 1 - math.abs((row + 0.5) / h * 2 - 1)
        local rw = math.max(1, math.floor(rel * w + 0.5))
        bar(parent, right and x or x + (w - rw), y + row, rw, 1)
    end
end

-- значок кнопки: картинка с мягкими краями, а если картинок нет - полоски
local fallbacks = {
    prev = function(box) bar(box, 0, 0, 2, 10); triangle(box, 3, 0, 7, 10, false) end,
    play = function(box) triangle(box, 1, 0, 9, 10, true) end,
    pause = function(box) bar(box, 1, 0, 3, 10); bar(box, 6, 0, 3, 10) end,
    next = function(box) triangle(box, 0, 0, 7, 10, true); bar(box, 8, 0, 2, 10) end,
}
local function glyph(parent, name)
    local id = MP.Icons and MP.Icons[name]
    if id then
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.fromOffset(13, 13)
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Position = UDim2.fromScale(0.5, 0.5)
        img.BackgroundTransparency = 1
        img.BorderSizePixel = 0
        img.Image = id
        img.ScaleType = Enum.ScaleType.Fit
        M.Style.Bind(img, "ImageColor3", 0.1)
        img.Parent = parent
        return img
    end
    local box = icon(parent, 10, 10)
    fallbacks[name](box)
    return box
end

-- колесо над панелью: вниз - следующий трек, вверх - предыдущий (не чаще 3 раз в секунду)
local function flip(kind)
    local now = os.clock()
    if now - (MP.FlipAt or -10) < 0.35 then return end
    MP.FlipAt = now
    MP.control(kind)
end
local function wheel(obj)
    obj.MouseWheelBackward:Connect(function() flip("next") end)
    obj.MouseWheelForward:Connect(function() flip("prev") end)
end

local function button(parent, order, w, h, onClick)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w, h)
    b.LayoutOrder = order
    b.BackgroundColor3 = Color3.new(1, 1, 1)
    b.BackgroundTransparency = 1
    b.AutoButtonColor = false
    b.Text = ""
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    -- при нажатии кнопка чуть уменьшается
    local press = Instance.new("UIScale", b)
    b.MouseEnter:Connect(function() M.Style.Tween(b, 0.15, {BackgroundTransparency = 0.86}) end)
    b.MouseLeave:Connect(function()
        M.Style.Tween(b, 0.2, {BackgroundTransparency = 1})
        M.Style.Tween(press, 0.12, {Scale = 1})
    end)
    b.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            M.Data.PillBtnAt = os.clock()
            M.Style.Tween(press, 0.08, {Scale = 0.86})
        end
    end)
    b.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            M.Style.Tween(press, 0.14, {Scale = 1})
        end
    end)
    b.MouseButton1Click:Connect(function()
        M.Data.PillBtnAt = os.clock()
        onClick()
    end)
    wheel(b)
    b.Parent = parent
    return b
end

local function text(parent, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.TextXAlignment = Enum.TextXAlignment.Left
    for k, v in pairs(props) do l[k] = v end
    l.Parent = parent
    return l
end

function M.F.MusicApplyMode(animate)
    local ui, pill = MP.Ui, M.UI.Pill
    if not pill then return end
    local shown = M.F.MusicShown()
    if ui then ui.Player.Visible = shown or ui.Widget == true end
    local h = shown and PILL_MUSIC_H or PILL_H
    local goal = UDim2.new(0, 0, 0, h)
    if pill.Size ~= goal then
        if animate then
            M.Services.T:Create(pill, TweenInfo.new(0.25 * M.Style.Scale(), Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = goal}):Play()
        else
            pill.Size = goal
        end
    end
end

function MP.build()
    local pill = M.UI.Pill
    local widget = M.State.MusicLayout == "Widget"
    local ui = {Widget = widget}
    -- панель трека
    local body = Instance.new("Frame")
    body.Name = "MusicPlayer"
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.LayoutOrder = 5
    local lay = Instance.new("UIListLayout", body)
    lay.FillDirection = Enum.FillDirection.Horizontal
    lay.VerticalAlignment = Enum.VerticalAlignment.Center
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Padding = UDim.new(0, 9)
    if widget then
        -- отдельный виджет в том же стиле, что виджеты скорости и клавиш; двигается мышью при открытом меню
        M.F.EnsureWidgetGui()
        local panel = M.F.MakePanel(M.UI.WidgetGui, "MusicWidget", 300, 60, 22, "MusicWidget", false)
        panel.Content.ClipsDescendants = true
        body.Size = UDim2.new(1, 0, 1, 0)
        local pad = Instance.new("UIPadding", body)
        pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
        body.Parent = panel.Content
        M.F.MakePanelDraggable(panel, panel.Root)
        panel.Root.Active = false
        panel.Root.Visible = true
        ui.Panel = panel
        M.UI.MusicWidget = ui
    else
        body.Size = UDim2.new(0, 0, 1, 0)
        body.AutomaticSize = Enum.AutomaticSize.X
        body.Visible = false
        body.Parent = pill
    end
    ui.Player = body
    wheel(body)

    -- обложка: цветной квадрат с буквой, поверх него картинка, когда она загружена; края скруглены у обоих слоёв
    local cover = Instance.new("Frame")
    cover.Size = UDim2.fromOffset(36, 36)
    cover.LayoutOrder = 1
    cover.BorderSizePixel = 0
    cover.BackgroundColor3 = M.State.Accent:Lerp(Color3.new(0, 0, 0), 0.45)
    Instance.new("UICorner", cover).CornerRadius = UDim.new(0, 10)
    cover.Parent = body
    wheel(cover)
    ui.Cover = cover
    ui.Letter = text(cover, {Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = Enum.TextXAlignment.Center, Text = ""})
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.fromScale(1, 1)
    img.BackgroundTransparency = 1
    img.BorderSizePixel = 0
    img.ImageTransparency = 1
    img.ScaleType = Enum.ScaleType.Crop
    img.ZIndex = 2
    Instance.new("UICorner", img).CornerRadius = UDim.new(0, 10)
    img.Parent = cover
    ui.Image = img

    -- название, исполнитель, время и полоса прогресса
    local info = Instance.new("Frame")
    info.Size = UDim2.fromOffset(150, 38)
    info.LayoutOrder = 2
    info.BackgroundTransparency = 1
    info.BorderSizePixel = 0
    info.ClipsDescendants = true
    info.Parent = body
    wheel(info)
    ui.Title = text(info, {Size = UDim2.new(1, 0, 0, 15), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = M.State.PillTextCol,
        TextTruncate = Enum.TextTruncate.AtEnd, Text = ""})
    ui.Artist = text(info, {Position = UDim2.fromOffset(0, 15), Size = UDim2.new(1, -56, 0, 12), Font = Enum.Font.GothamMedium, TextSize = 10,
        TextColor3 = M.Style.TextDim, TextTruncate = Enum.TextTruncate.AtEnd, Text = ""})
    ui.Time = text(info, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 15), Size = UDim2.fromOffset(56, 12),
        Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = M.Style.TextDim, TextXAlignment = Enum.TextXAlignment.Right, Text = ""})
    local track = Instance.new("Frame")
    track.Position = UDim2.fromOffset(0, 32)
    track.Size = UDim2.new(1, 0, 0, 3)
    track.BackgroundColor3 = M.Style.Stroke
    track.BackgroundTransparency = 0.2
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    track.Parent = info
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BorderSizePixel = 0
    M.Style.Bind(fill, "BackgroundColor3")
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    fill.Parent = track
    ui.Fill = fill

    -- кнопки: назад, пауза/играть, вперёд
    local ctl = Instance.new("Frame")
    ctl.Size = UDim2.fromOffset(70, 24)
    ctl.LayoutOrder = 3
    ctl.BackgroundTransparency = 1
    ctl.BorderSizePixel = 0
    local cl = Instance.new("UIListLayout", ctl)
    cl.FillDirection = Enum.FillDirection.Horizontal
    cl.VerticalAlignment = Enum.VerticalAlignment.Center
    cl.SortOrder = Enum.SortOrder.LayoutOrder
    cl.Padding = UDim.new(0, 2)
    ctl.Parent = body
    local prev = button(ctl, 1, 22, 22, function() MP.control("prev") end)
    glyph(prev, "prev")
    local play = button(ctl, 2, 22, 22, function() MP.control("toggle") end)
    ui.PlayIcon = glyph(play, "play")
    ui.PauseIcon = glyph(play, "pause")
    local nxt = button(ctl, 3, 22, 22, function() MP.control("next") end)
    glyph(nxt, "next")

    -- кнопка-волна: у мини-меню, переключает режим (у отдельного виджета не нужна)
    ui.Bars = {}
    if not widget then
        local wave = button(pill, 30, 24, 24, function()
            M.State.MusicMode = not M.State.MusicMode
            M.F.MusicApplyMode(true)
            M.F.PillUpdate()
            MP.Dirty = true
        end)
        wave.Name = "MusicWave"
        local wb = icon(wave, 14, 14)
        for i = 1, 4 do
            local b = bar(wb, (i - 1) * 4, 7, 2, 4, UDim.new(0, 1))
            ui.Bars[i] = {Frame = b, H = 4}
        end
        ui.Wave = wave
    end
    MP.Ui = ui
end

function MP.destroy()
    local ui = MP.Ui
    MP.Ui = nil
    if not ui then return end
    if ui.Panel then
        M.UI.MusicWidget = nil
        M.F.DestroyPanel(ui.Panel)
        M.F.ReleaseWidgetGui()
    else
        pcall(function() ui.Player:Destroy() end)
    end
    if ui.Wave then pcall(function() ui.Wave:Destroy() end) end
end

-- смена вида плеера (в мини-меню / отдельный виджет): плеер строится заново
function M.F.MusicRelayout()
    if not MP.Ui then return end
    MP.destroy()
    MP.build()
    MP.Dirty, MP.CoverDirty = true, true
    M.F.MusicApplyMode(false)
    M.F.PillUpdate()
end
local function fmtTime(sec)
    sec = math.max(math.floor(sec), 0)
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- прогресс между опросами считается по часам, а не по сети
function MP.position()
    local p = MP.Progress
    if MP.Playing then p = p + (os.clock() - MP.BaseAt) end
    if MP.Duration > 0 then p = math.min(p, MP.Duration) end
    return math.max(p, 0)
end

-- смена трека: название и исполнитель выезжают сбоку, обложка чуть «подпрыгивает»
local function flipAnimation(ui)
    local dir = MP.FlipDir or 1
    MP.FlipDir = nil
    for _, label in ipairs({ui.Title, ui.Artist}) do
        label.Position = UDim2.fromOffset(dir * 14, label == ui.Artist and 15 or 0)
        label.TextTransparency = 1
        M.Style.Tween(label, 0.28, {Position = UDim2.fromOffset(0, label == ui.Artist and 15 or 0), TextTransparency = 0})
    end
    ui.Cover.Position = UDim2.fromOffset(0, 0)
end

-- раз в кадр (не чаще 30 раз в секунду): волны, прогресс, подписи
function MP.frame()
    local ui = MP.Ui
    if not ui then return end
    local now = os.clock()
    if now - MP.FrameAt < 1 / 30 then return end
    MP.FrameAt = now
    -- волны бегут, только пока играет музыка
    local live = MP.Playing and MP.StatusKey == nil
    for i, b in ipairs(ui.Bars) do
        local h = live and math.floor(4 + 9 * (0.5 + 0.5 * math.sin(now * 5.2 + i * 1.9)) + 0.5) or ({4, 7, 5, 6})[i]
        if b.H ~= h then
            b.H = h
            b.Frame.Size = UDim2.fromOffset(2, h)
            b.Frame.Position = UDim2.fromOffset((i - 1) * 4, 7 - math.floor(h / 2))
        end
    end
    local panel = ui.Panel
    if panel then
        local sc = math.clamp(M.State.MusicWidgetScale or 1, 0.5, 3)
        if ui.ScaleSet ~= sc then ui.ScaleSet = sc; panel.Scale.Scale = sc end
        local active = M.Run.MenuOpen == true
        if ui.ActiveSet ~= active then ui.ActiveSet = active; panel.Root.Active = active end
    end
    if not MP.visible() then return end
    if MP.Notice and now - (MP.NoticeAt or 0) > 3 then MP.Notice = nil; MP.Dirty = true end
    local statusKey = MP.StatusKey
    if MP.Dirty then
        MP.Dirty = false
        local title = statusKey and M.Translate(statusKey) or MP.Title
        local artist = statusKey and (statusKey == "Music_NoHelper" and "matsysense_media_start.bat" or "") or MP.Artist
        if MP.Notice then artist = M.Translate(MP.Notice) end
        -- у статуса подпись на всю ширину: времени справа нет
        local wide = statusKey ~= nil
        if ui.ArtistWide ~= wide then
            ui.ArtistWide = wide
            ui.Artist.Size = wide and UDim2.new(1, 0, 0, 12) or UDim2.new(1, -56, 0, 12)
        end
        if ui.Title.Text ~= title then
            ui.Title.Text = title
            -- новый трек (а не смена статуса) листается анимацией
            if not statusKey and ui.ShownTrack ~= MP.TrackId then flipAnimation(ui) end
        end
        ui.ShownTrack = statusKey and ui.ShownTrack or MP.TrackId
        if ui.Artist.Text ~= artist then ui.Artist.Text = artist end
        local letter = statusKey and "" or (title ~= "" and string.sub(title, 1, utf8.offset(title, 2) and utf8.offset(title, 2) - 1 or #title) or "")
        if ui.Letter.Text ~= letter then ui.Letter.Text = letter end
        ui.PlayIcon.Visible = not MP.Playing
        ui.PauseIcon.Visible = MP.Playing
    end
    if MP.CoverDirty then
        MP.CoverDirty = false
        if MP.CoverAsset then
            ui.Image.Image = MP.CoverAsset
            M.Style.Tween(ui.Image, 0.3, {ImageTransparency = 0})
        else
            ui.Image.ImageTransparency = 1
        end
    end
    local pos, dur = MP.position(), MP.Duration
    local ratio = (dur > 0 and not statusKey) and pos / dur or 0
    local px = math.floor(ratio * 150 + 0.5)
    if ui.PxShown ~= px then
        ui.PxShown = px
        ui.Fill.Size = UDim2.new(0, px, 1, 0)
    end
    local tm = statusKey and "" or (dur > 0 and (fmtTime(pos) .. "/" .. fmtTime(dur)) or fmtTime(pos))
    if ui.Time.Text ~= tm then ui.Time.Text = tm end
end

function MP.recolor(col)
    if MP.Ui then MP.Ui.Title.TextColor3 = col end
end
M.F.MusicRecolor = MP.recolor

-- кнопка в меню: пересоздать файлы помощника
function M.F.MusicFiles()
    local wrote, supported = MP.ensureHelper(true)
    local key = not supported and "Music_NoFiles" or "Music_FilesDone"
    M.F.Notify("MusicFiles", M.Translate(key), supported, true)
end

M.F.DefineModule("Music", {
    Wanted = function() return M.State.MusicOn end,
    Load = function()
        MP.Gen = MP.Gen + 1
        MP.StatusKey, MP.Dirty, MP.CoverDirty = "Music_Loading", true, true
        MP.TrackId, MP.CoverAsset, MP.CoverFetched, MP.CoverWanted, MP.Playing = nil, nil, nil, nil, false
        -- файлы помощника создаются сами; о них сообщается при первом создании
        local wrote, supported = MP.ensureHelper(false)
        if wrote then M.F.Notify("MusicFiles", M.Translate("Music_FilesNew"), true, true) end
        MP.makeIcons()
        MP.build()
        MP.Conn = M.Track(M.Services.R.RenderStepped:Connect(function()
            if M.Run.IsShutDown then return end
            M.F.Safe("Music", MP.frame)
        end))
        local gen = MP.Gen
        task.spawn(function() pollLoop(gen) end)
        M.F.MusicApplyMode(false)
        M.F.PillUpdate()
    end,
    Unload = function()
        MP.Gen = MP.Gen + 1
        if MP.Conn then M.F.Untrack(MP.Conn); MP.Conn = nil end
        MP.destroy()
        local del = M.Cap.Fn("delfile")
        if del then
            for name in pairs(MP.CoverFiles) do pcall(del, name) end
        end
        table.clear(MP.CoverFiles)
        if del then
            for name in pairs(MP.IconFiles or {}) do pcall(del, name) end
        end
        MP.Icons, MP.IconFiles = nil, nil
        if M.UI.Pill then
            M.UI.Pill.Size = UDim2.new(0, 0, 0, PILL_H)
            M.F.PillUpdate()
        end
    end
})

end}

-- [37/69] Уведомления
MODULES[#MODULES + 1] = {"37. Уведомления", function(M, __X)
-- ==============================================================================
-- [ УВЕДОМЛЕНИЯ ]
-- ==============================================================================
do
local NOTIF_W, NOTIF_H, NOTIF_GAP, NOTIF_MARGIN, NOTIF_MAX = 330, 66, 10, 20, 4

M.F.DefineModule("Notify", {
    Wanted = function() return #M.Data.NotifList > 0 or os.clock() - M.Data.NotifyUsed < 30 end,
    Load = function()
        M.UI.NotifyGui = Instance.new("ScreenGui")
        M.UI.NotifyGui.Name = M.Services.H:GenerateGUID(false)
        M.UI.NotifyGui.ResetOnSpawn = false
        M.UI.NotifyGui.DisplayOrder = 300
        M.UI.NotifyGui.IgnoreGuiInset = true
        M.F.GateGui(M.UI.NotifyGui)
        M.UI.NotifyGui.Parent = M.TargetGui
        M.F.WatchFonts(M.UI.NotifyGui)
    end,
    Unload = function()
        if M.UI.NotifyGui then M.UI.NotifyGui:Destroy() end
        M.UI.NotifyGui = nil
    end
})

local function notifTween(inst, duration, style, direction, goal)
    local tween = M.Services.T:Create(inst, TweenInfo.new(duration * M.Style.Scale(), style, direction), goal)
    tween:Play()
    return tween
end

-- расставляет уведомления стопкой
function M.F.NotifyLayout()
    local offset = NOTIF_MARGIN
    for _, n in ipairs(M.Data.NotifList) do
        -- back
        notifTween(n.Holder, 0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {Position = UDim2.new(1, -NOTIF_MARGIN, 1, -offset)})
        offset = offset + n.H + NOTIF_GAP
    end
end

-- размер уведомлений меняется сразу, в том числе у уже показанных
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
    if n.Glow then n.Glow.Set(0, 0.3) end
    if n.TrackGlow then n.TrackGlow.Set(0, 0.3) end
    if n.Glass then n.Glass.Alpha(0, 0.3) end
    task.delay(0.45, function() n.Holder:Destroy() end)
    M.F.NotifyLayout()
end

-- обновляет содержимое
function M.F.NotifyApply(n, title, isOn)
    n.TitleLabel.Text = title
    M.F.Refit(n.TitleLabel)
    n.Fill.BackgroundColor3 = M.State.NotifyColor
    if not n.Dead then
        notifTween(n.Fill, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {BackgroundTransparency = M.State.NotifyAlpha})
    end
    n.SubLabel.Text = M.Translate(isOn and "Notif_On" or "Notif_Off")
    n.SubLabel.TextColor3 = isOn and M.Style.Success or M.Style.TextDim
    notifTween(n.Track, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
        BackgroundColor3 = isOn and M.State.Accent or M.Style.Off
    })
    notifTween(n.Knob, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
        Position = isOn and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    })
    -- свечение за капсулой и под переключателем
    if n.Glow then
        n.Glow.SetColor(isOn and M.State.Accent or M.Style.TextMute, 0.3)
        n.Glow.Set(isOn and M.Style.SurfaceGlow or M.Style.SurfaceGlow * 0.4, 0.3)
    end
    if n.TrackGlow then
        n.TrackGlow.SetColor(M.State.Accent, 0.3)
        n.TrackGlow.Set(isOn and M.Style.ControlGlow or 0, 0.3)
    end
    -- полоска, которая убывает до закрытия уведомления
    if not n.Dead and n.Holder then
        local drain = n.Drain
        if not drain then
            if n.Content then n.Content.ZIndex = 2 end
            if n.Stroke and n.Stroke.Parent then n.Stroke.Parent.ZIndex = 3 end
            drain = Instance.new("Frame")
            drain.Name = "Drain"
            drain.Size = UDim2.new(1, 0, 1, 0)
            drain.BackgroundTransparency = 1
            drain.BorderSizePixel = 0
            drain.Active = false
            drain.ZIndex = 1
            Instance.new("UICorner", drain).CornerRadius = UDim.new(0.5, 0)
            drain.Parent = n.Holder
            n.Drain = drain
            table.insert(n.FadeItems, {drain, "BackgroundTransparency", 0.84})
        end
        drain.BackgroundColor3 = isOn and M.State.Accent or M.Style.TextMute
        drain.Size = UDim2.new(1, 0, 1, 0)
        M.Services.T:Create(drain, TweenInfo.new(2.8, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 1, 0)}):Play()
    end
    n.Token = n.Token + 1
    local token = n.Token
    task.delay(2.8, function()
        if n.Token == token then M.F.NotifyDismiss(n) end
    end)
end

-- капсула собрана из трёх слоёв ОДИНАКОВОЙ формы
function M.F.Notify(key, title, isOn, force)
    if (not M.State.NotifyOn and not force) or M.Run.IsShutDown or M.Data.Importing then return end
    M.Data.NotifyUsed = os.clock()
    M.F.LoadModule("Notify")
    local list = M.Data.NotifList

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

    -- слой 0
    n.Glow = M.Style.Glow(holder, 12, 0, M.State.Accent, UDim.new(0.5, 0), 0)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = M.State.NotifyColor
    fill.BackgroundTransparency = 1
    fill.BorderSizePixel = 0
    capsuleCorner(fill)
    fill.Parent = holder
    n.Fill = fill

    -- матовое стекло над заливкой
    n.Glass = M.Style.BuildGlass(holder, UDim.new(0.5, 0), {})
    n.Glass.SetVisible(M.State.GlassOn)
    n.Glass.Alpha(0)
    n.Glass.Alpha(1, 0.4)

    -- слой 2
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Parent = holder
    n.Content = content

    -- холст фиксированного размера 330 x 66
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

    -- слой 3
    local rim = Instance.new("Frame")
    rim.Name = "Rim"
    rim.Size = UDim2.new(1, 0, 1, 0)
    rim.BackgroundTransparency = 1
    rim.BorderSizePixel = 0
    capsuleCorner(rim)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.2
    stroke.Color = M.State.Accent
    stroke.Transparency = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = rim
    -- градиент на обводке убран
    rim.Parent = holder
    n.Stroke = stroke

    local trackHost = Instance.new("Frame")
    trackHost.Name = "TrackGlowHost"
    trackHost.Size = UDim2.new(0, 46, 0, 26)
    trackHost.Position = UDim2.new(0, 20, 0.5, -13)
    trackHost.BackgroundTransparency = 1
    trackHost.BorderSizePixel = 0
    trackHost.Parent = inner
    n.TrackGlow = M.Style.Glow(trackHost, 7, 0, M.State.Accent, UDim.new(1, 0), 0)

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(0, 46, 0, 26)
    track.Position = UDim2.new(0, 20, 0.5, -13)
    track.BackgroundColor3 = M.Style.Off
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
        M.Style.Text, Enum.TextXAlignment.Left)
    n.SubLabel = makeLabel("Sub", Enum.Font.GothamMedium, 12, UDim2.new(0, 82, 0, 33), UDim2.new(1, -82 - 20, 0, 18),
        M.Style.TextDim, Enum.TextXAlignment.Left)
    n.TimeLabel = makeLabel("Time", Enum.Font.Gotham, 11, UDim2.new(1, -24, 0, 14), UDim2.new(0, 60, 0, 14),
        M.Style.TextMute, Enum.TextXAlignment.Right, Vector2.new(1, 0))
    n.TimeLabel.Text = M.Translate("Notif_Now")
    M.F.FitText(n.TitleLabel, 9)
    M.F.FitText(n.SubLabel, 8)

    -- элементы, которые проявляются и растворяются
    n.FadeItems = {
        {track, "BackgroundTransparency", 0}, {knob, "BackgroundTransparency", 0},
        {n.TitleLabel, "TextTransparency", 0}, {n.SubLabel, "TextTransparency", 0}, {n.TimeLabel, "TextTransparency", 0}
    }
    for _, item in ipairs(n.FadeItems) do item[1][item[2]] = 1 end

    -- вставляем в начало списка
    table.insert(list, 1, n)
    holder.Position = UDim2.new(1, n.W + 40, 1, -NOTIF_MARGIN)
    while #list > NOTIF_MAX do M.F.NotifyDismiss(list[#list]) end

    M.F.NotifyApply(n, title, isOn)
    knob.Position = isOn and UDim2.new(0, 3, 0.5, 0) or UDim2.new(1, -23, 0.5, 0)
    track.BackgroundColor3 = isOn and M.Style.Off or M.State.Accent
    notifTween(knob, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {Position = isOn and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)})
    notifTween(track, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {BackgroundColor3 = isOn and M.State.Accent or M.Style.Off})

    notifTween(fill, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {BackgroundTransparency = M.State.NotifyAlpha})
    notifTween(stroke, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {Transparency = M.Style.StrokeActive})
    for _, item in ipairs(n.FadeItems) do
        notifTween(item[1], 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {[item[2]] = item[3]})
    end
    M.F.NotifyLayout()
end
end

function M.F.NotifyPreview()
    if M.Data.Importing then return end
    M.F.Notify("NotifyPreview", M.Translate("NotifyPreviewText"), true, true)
end

function M.F.NotifyToggle(stateKey, locKey, value)
    M.F.Notify(stateKey, M.Translate(locKey), value and true or false)
end

end}

-- [38/69] Экранные эффекты: вспышка, цветокоррекция
MODULES[#MODULES + 1] = {"38. Экранные эффекты: вспышка, цветокоррекция", function(M, __X)
-- ==============================================================================
-- [ ЭКРАННЫЕ ЭФФЕКТЫ ]
-- ==============================================================================
function M.F.NewGui(name, order)
    local gui = Instance.new("ScreenGui")
    gui.Name = M.Services.H:GenerateGUID(false)
    gui.ResetOnSpawn = false
    gui.DisplayOrder = order
    gui.IgnoreGuiInset = true
    M.F.GateGui(gui)
    gui.Parent = M.TargetGui
    M.F.WatchFonts(gui)
    return gui
end

-- вспышка экрана
M.F.DefineModule("Flash", {
    -- вспышка нужна редко
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

-- вспышка рисунком поверх экрана; false, если так нельзя
function M.F.FlashDraw(power, color, token)
    local caps = M.Draw.Caps or {}
    if not caps.SquareAlpha then return false end
    local cam = workspace.CurrentCamera
    local sq = cam and M.Draw.New("Square")
    if not sq then return false end
    local vs = cam.ViewportSize
    pcall(function()
        sq.Filled = true
        sq.Color = color
        sq.Position = Vector2.new(0, 0)
        sq.Size = Vector2.new(vs.X, vs.Y)
        if caps.ZIndex then sq.ZIndex = 1 end
    end)
    task.spawn(function()
        local started = os.clock()
        local peak = 0.7 * power
        while true do
            local age = os.clock() - started
            if age >= 0.7 or M.Run.IsShutDown or M.Data.FlashToken ~= token then break end
            local op
            if age < 0.1 then
                op = peak * (1 - 0.57 * age / 0.1)
            else
                local k = (age - 0.1) / 0.6
                op = peak * 0.43 * (1 - k) * (1 - k)
            end
            pcall(function()
                sq.Transparency = op
                sq.Visible = not M.Draw.Blocked()
            end)
            M.Services.R.RenderStepped:Wait()
        end
        M.Draw.Remove(sq)
    end)
    return true
end

function M.F.ScreenFlash(power, color)
    power = math.clamp(power, 0, 1)
    if power <= 0 then return end
    M.Data.FlashUsed = os.clock()
    M.Data.FlashToken = (M.Data.FlashToken or 0) + 1
    local token = M.Data.FlashToken
    if M.Draw.Enabled() and M.F.FlashDraw(power, color or Color3.fromRGB(235, 240, 255), token) then return end
    M.F.LoadModule("Flash")
    M.UI.FlashFrame.BackgroundColor3 = color or Color3.fromRGB(235, 240, 255)
    local frame = M.UI.FlashFrame
    task.spawn(function()
        local peak = 1 - 0.7 * power
        frame.BackgroundTransparency = peak
        M.Services.T:Create(frame, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
        task.wait(0.16)
        if token ~= M.Data.FlashToken or M.Run.IsShutDown then return end
        frame.BackgroundTransparency = 1 - (1 - peak) * 0.65
        M.Services.T:Create(frame, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    end)
end

-- цветокоррекция и готовые стили
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
    if not preset then return end  -- "Custom": значения остаются как есть
    M.F.SetStateVisual("GradeSat", preset.Sat)
    M.F.SetStateVisual("GradeContrast", preset.Contrast)
    M.F.SetStateVisual("GradeBright", preset.Bright)
    M.F.SetStateVisual("GradeTint", preset.Tint)
    if not M.State.GradeOn then M.F.SetStateVisual("GradeOn", true) end
    M.F.ApplyGrade()
end

end}

-- [39/69] Низкое здоровье, тряска, скорость, числа урона
MODULES[#MODULES + 1] = {"39. Низкое здоровье, тряска, скорость, числа урона", function(M, __X)
-- ==============================================================================
-- [ НИЗКОЕ ЗДОРОВЬЕ, ТРЯСКА, ЧИСЛА УРОНА ]
-- ==============================================================================

-- красная подсветка краёв при низком здоровье
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
    local fraction = hum and hum.Health > 0 and M.Math.HpFraction(hum.Health, hum.MaxHealth) or 1
    local show = M.State.LowHpOn and fraction < 0.4
    if M.UI.LowHpGui.Enabled ~= show then M.UI.LowHpGui.Enabled = show end
    if not show then return end
    local severity = (0.4 - fraction) / 0.4  -- 0 .. 1
    local beat = (math.sin(os.clock() * (3 + severity * 4)) + 1) / 2  -- чем хуже здоровье, тем чаще пульс
    local alpha = 0.25 + 0.6 * severity * (0.45 + 0.55 * beat)
    for _, edge in ipairs(M.UI.LowHpEdges) do
        edge.BackgroundTransparency = 1 - alpha
    end
end

-- следим за СВОИМ здоровьем
function M.F.UpdateSelfHealth(hum)
    if not hum then
        M.Data.LastHealth = nil
        return
    end
    if M.Data.LastHealthHum ~= hum then
        M.Data.LastHealthHum, M.Data.LastHealth = hum, nil
    end
    local health = hum.Health
    local last = M.Data.LastHealth
    M.Data.LastHealth = health
    if last and health < last - 0.5 and health == health and last < math.huge then
        M.Data.LastDamage = os.clock()
        local maxHealth = hum.MaxHealth
        if not (maxHealth >= 1 and maxHealth < math.huge) then maxHealth = 100 end
        local fraction = math.clamp((last - health) / maxHealth, 0, 1)
        local power = math.clamp(fraction * 4, 0.25, 1)
        if M.State.ShakeOn then
            M.Data.ShakeEnergy = math.max(M.Data.ShakeEnergy, power * M.State.ShakeStrength)
        end
        if M.State.HitFlashOn then
            M.F.ScreenFlash(power * 0.9, Color3.fromRGB(255, 40, 40))
        end
    end
end

-- тряска
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

-- скорость движения по смещению позиции
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
    local lastSample = samples[#samples]
    if lastSample and now - lastSample.T < 0.033 then return end
    local pos = hrp.Position
    -- телепорт или респавн
    if lastSample and (pos - lastSample.P).Magnitude > 100 then table.clear(samples) end
    M.Data.LastPos = pos
    samples[#samples + 1] = {T = now, P = pos}
    while #samples > 2 and now - samples[1].T > 0.32 do table.remove(samples, 1) end

    local first = samples[1]
    local span = now - first.T
    if span >= 0.06 then
        local delta = pos - first.P
        M.Data.MoveSpeed = math.min(Vector3.new(delta.X, 0, delta.Z).Magnitude / span, 120)
        -- полная скорость
        M.Data.Speed3D = math.min(delta.Magnitude / span, 100000)
    end
end
-- числа урона над игроками
M.F.DefineModule("DamageNumbers", {
    Wanted = function() return M.State.DamageNumbers end,
    Load = function()
        M.UI.DamageFolder = Instance.new("Folder")
        M.UI.DamageFolder.Name = M.Services.H:GenerateGUID(false)
        M.UI.DamageFolder.Parent = M.TargetGui
    end,
    Unload = function()
        M.F.DamageDrawStop()
        if M.UI.DamageFolder then M.UI.DamageFolder:Destroy() end
        M.UI.DamageFolder = nil
    end
})

-- число рисуется поверх экрана: цифры поднимаются, потом рассыпаются и падают
local DMG_LIFE = 1.35
local DMG_POP = 0.4
local DMG_SIZE = 34
local DMG_CRUMBS = 7

function M.F.DamageDrawStop()
    local H = M.Data.DmgDraw
    if not H then return end
    M.Data.DmgDraw = nil
    pcall(function() M.Services.R:UnbindFromRenderStep("DamageFxFrame") end)
    for _, e in ipairs(H.List) do
        for _, o in ipairs(e.Objs) do M.Draw.Remove(o) end
    end
end

local function dmgStep(dt)
    local H = M.Data.DmgDraw
    if not H then return end
    local cam = workspace.CurrentCamera
    local now = os.clock()
    local caps = M.Draw.Caps or {}
    for i = #H.List, 1, -1 do
        local e = H.List[i]
        local age = now - e.T0
        if age >= DMG_LIFE or not cam or M.Run.IsShutDown then
            for _, o in ipairs(e.Objs) do M.Draw.Remove(o) end
            table.remove(H.List, i)
        else
            if e.Head and e.Head.Parent then e.Pos = e.Head.Position + e.Off end
            local sp = cam:WorldToViewportPoint(e.Pos)
            local visible = sp.Z > 0 and not M.Draw.Blocked()
            local rise, scale
            if age < DMG_POP then
                local k = age / DMG_POP
                rise = -38 * (1 - (1 - k) * (1 - k))
                scale = 0.55 + 0.7 * math.sin(k * math.pi * 0.5) - 0.25 * k * k
            else
                rise = -38 - 10 * (age - DMG_POP)
                scale = 1
            end
            local crumble = math.max(age - DMG_POP * 1.1, 0)
            local fade = 1 - math.clamp(crumble / (DMG_LIFE - DMG_POP * 1.1), 0, 1)
            local opacity = math.floor(fade * fade * 20 + 0.5) / 20
            local size = math.floor(DMG_SIZE * scale + 0.5)
            local step = size * 0.62
            local n = #e.Digits
            for d, dig in ipairs(e.Digits) do
                local t = dig.Obj
                local x = sp.X + (d - (n + 1) / 2) * step
                local y = sp.Y + rise - size * 0.5
                if crumble > 0 then
                    x = x + dig.VX * crumble
                    y = y + dig.VY * crumble + 0.5 * 420 * crumble * crumble
                end
                t.Size = size
                t.Position = Vector2.new(math.floor(x + 0.5), math.floor(y + 0.5))
                if caps.TextAlpha then t.Transparency = opacity end
                t.Visible = visible and opacity > 0.02
            end
            for _, c in ipairs(e.Crumbs) do
                local o = c.Obj
                local show = visible and crumble > 0 and opacity > 0.02
                if show then
                    local cx = sp.X + (c.D - (n + 1) / 2) * step + c.VX * crumble
                    local cy = sp.Y + rise + c.VY * crumble + 0.5 * 520 * crumble * crumble
                    o.Position = Vector2.new(math.floor(cx + 0.5), math.floor(cy + 0.5))
                    if caps.SquareAlpha then o.Transparency = opacity end
                end
                o.Visible = show
            end
        end
    end
    if #H.List == 0 then M.F.DamageDrawStop() end
end

-- возвращает false, если рисунки создать не получилось
function M.F.DamageDrawShow(head, text)
    local caps = M.Draw.Caps or {}
    local objs = {}
    local failed = false
    local function new(kind)
        local o = M.Draw.New(kind)
        if o then objs[#objs + 1] = o else failed = true end
        return o
    end
    local base = Color3.fromRGB(255, 110, 70)
    local e = {T0 = os.clock(), Objs = objs, Head = head, Pos = head.Position, Digits = {}, Crumbs = {},
        Off = Vector3.new(math.random(-10, 10) / 10, 2.4, 0)}
    e.Pos = head.Position + e.Off
    local n = #text
    for i = 1, n do
        local t = new("Text")
        if t then
            pcall(function()
                t.Text = string.sub(text, i, i)
                t.Size = DMG_SIZE
                t.Color = base
                if caps.TextCenter then t.Center = true end
                if caps.TextOutline then t.Outline = true; t.OutlineColor = Color3.new(0, 0, 0) end
                if caps.TextFont then t.Font = 2 end
                if caps.ZIndex then t.ZIndex = 5 end
            end)
            e.Digits[#e.Digits + 1] = {Obj = t, VX = (math.random() - 0.5) * 150, VY = -(30 + math.random() * 110)}
        end
    end
    for _ = 1, DMG_CRUMBS do
        local q = new("Square")
        if q then
            local sz = 3 + math.random(0, 2)
            pcall(function()
                q.Filled = true
                q.Color = base:Lerp(Color3.new(1, 1, 1), math.random() * 0.5)
                q.Size = Vector2.new(sz, sz)
                if caps.ZIndex then q.ZIndex = 4 end
            end)
            e.Crumbs[#e.Crumbs + 1] = {Obj = q, D = math.random(1, n), VX = (math.random() - 0.5) * 190, VY = -(20 + math.random() * 120)}
        end
    end
    if failed then
        for _, o in ipairs(objs) do M.Draw.Remove(o) end
        return false
    end
    local H = M.Data.DmgDraw
    if not H then
        H = {List = {}}
        M.Data.DmgDraw = H
        pcall(function() M.Services.R:UnbindFromRenderStep("DamageFxFrame") end)
        M.Services.R:BindToRenderStep("DamageFxFrame", Enum.RenderPriority.Last.Value + 5, function(dt)
            if M.Run.IsShutDown then return end
            M.F.Safe("DamageFx", dmgStep, dt)
        end)
    end
    -- лишние числа убираются, чтобы не копились рисунки
    while #H.List >= 8 do
        local old = table.remove(H.List, 1)
        for _, o in ipairs(old.Objs) do M.Draw.Remove(o) end
    end
    H.List[#H.List + 1] = e
    for _, o in ipairs(objs) do pcall(function() o.Visible = false end) end
    return true
end

-- запасной вариант из элементов меню: те же цифры, рассыпаются по одной
function M.F.DamageGuiShow(head, text)
    if not M.UI.DamageFolder then return end
    local n = #text
    local gui = Instance.new("BillboardGui")
    gui.Adornee = head
    gui.AlwaysOnTop = true
    gui.Size = UDim2.fromOffset(240, 90)
    gui.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 2.4, 0)
    gui.Parent = M.UI.DamageFolder
    local step = 24
    local T = M.Services.T
    for i = 1, n do
        local label = Instance.new("TextLabel")
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Size = UDim2.fromOffset(step, 44)
        label.Position = UDim2.new(0.5, (i - (n + 1) / 2) * step, 0.5, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 34
        label.TextColor3 = Color3.fromRGB(255, 110, 70)
        label.TextStrokeTransparency = 0.4
        label.Text = string.sub(text, i, i)
        label.Parent = gui
        local goal = {
            Position = label.Position + UDim2.fromOffset((math.random() - 0.5) * 120, 40 + math.random() * 50),
            Rotation = (math.random() - 0.5) * 140,
            TextTransparency = 1, TextStrokeTransparency = 1
        }
        T:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45), goal):Play()
    end
    T:Create(gui, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {StudsOffset = gui.StudsOffset + Vector3.new(0, 2.5, 0)}):Play()
    M.Services.D:AddItem(gui, 1.6)
end

-- попадания по одному врагу за 0.08 с (дробь, очередь) складываются в одно число: так читается проще и рисунков меньше
function M.F.SpawnDamageNumber(head, amount)
    local viewCam = workspace.CurrentCamera
    if viewCam and (viewCam.CFrame.Position - head.Position).Magnitude > M.State.PlayerViewMaxDist then return end
    local D = M.Data
    D.DmgMerge = D.DmgMerge or setmetatable({}, {__mode = "k"})
    local m = D.DmgMerge[head]
    if m then
        m.Sum = m.Sum + amount
        return
    end
    m = {Sum = amount}
    D.DmgMerge[head] = m
    task.delay(0.08, function()
        if D.DmgMerge and D.DmgMerge[head] == m then D.DmgMerge[head] = nil end
        if M.Run.IsShutDown or not head.Parent or not M.State.DamageNumbers then return end
        local text = tostring(math.floor(m.Sum + 0.5))
        if M.Draw.Enabled() and M.F.DamageDrawShow(head, text) then return end
        M.F.DamageGuiShow(head, text)
    end)
end

-- чей это урон

-- пинг до сервера в секундах
function M.F.PingSec()
    local D = M.Data
    local now = os.clock()
    if now - (D.PingAt or -10) < 1 then return D.PingVal or 0 end
    D.PingAt = now
    local stats = M.Services.S
    if stats then
        local ok, ms = pcall(function() return stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if ok and type(ms) == "number" and ms == ms and ms >= 0 and ms < 5000 then D.PingVal = ms / 1000 end
    end
    return D.PingVal or 0
end

-- сколько секунд после выстрела
function M.F.ShotWindow()
    return math.clamp(0.4 + 1.5 * M.F.PingSec(), 0.5, 1.5)
end

-- откуда реально вылетает пуля
function M.F.ShotOrigins(cam)
    local camPos = cam.CFrame.Position
    local char = M.LP and M.LP.Character
    local head = char and M.GetHead(char)
    if not head then return camPos, nil end
    local headPos = head.Position
    if (camPos - headPos).Magnitude <= 2.5 then return camPos, nil end
    local muzzle
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local m = tool:FindFirstChild("Muzzle", true) or tool:FindFirstChild("FirePoint", true) or tool:FindFirstChild("Handle")
        if m then
            if m:IsA("Attachment") then muzzle = m.WorldPosition elseif m:IsA("BasePart") then muzzle = m.Position end
        end
    end
    if muzzle then return muzzle, headPos end
    return headPos, nil
end

function M.F.Slab(oi, di, hi, tmin, tmax)
    if math.abs(di) < 1e-9 then
        if oi < -hi or oi > hi then return nil end
        return tmin, tmax
    end
    local t1, t2 = (-hi - oi) / di, (hi - oi) / di
    if t1 > t2 then t1, t2 = t2, t1 end
    if t1 > tmin then tmin = t1 end
    if t2 < tmax then tmax = t2 end
    if tmin > tmax then return nil end
    return tmin, tmax
end

-- пересекает ли луч
function M.F.RayHitsPart(o, d, part, pad)
    local cf = part.CFrame
    local lo, ld = cf:PointToObjectSpace(o), cf:VectorToObjectSpace(d)
    local size = part.Size
    local tmin, tmax = M.F.Slab(lo.X, ld.X, size.X * 0.5 + pad, 0, 1e9)
    if not tmin then return nil end
    tmin, tmax = M.F.Slab(lo.Y, ld.Y, size.Y * 0.5 + pad, tmin, tmax)
    if not tmin then return nil end
    tmin = M.F.Slab(lo.Z, ld.Z, size.Z * 0.5 + pad, tmin, tmax)
    return tmin
end

-- какая деталь тела врага лежит на линии прицела
function M.F.AimedPart(ch, o, d)
    local root = M.GetRoot(ch)
    if not root then return nil end
    local rv = root.Position - o
    local rt = rv:Dot(d)
    if rt <= 0 then return nil end
    local pad = 0.6 + 0.003 * rt
    -- грубый отсев
    if (rv - d * rt).Magnitude > 6 + pad then return nil end
    local best, bestT = nil, math.huge
    for _, part in ipairs(ch:GetChildren()) do
        if part:IsA("BasePart") then
            local t = M.F.RayHitsPart(o, d, part, pad)
            if t and t < bestT then best, bestT = part, t end
        end
    end
    if not best then
        local list = M.F.BodyParts(ch)
        for i = 1, #list do
            local t = M.F.RayHitsPart(o, d, list[i], pad)
            if t and t < bestT then best, bestT = list[i], t end
        end
    end
    return best
end

-- свободна ли прямая от точки до точки
function M.F.LineClear(from, to)
    local delta = to - from
    local wall = M.RaycastMap(from, delta)
    return wall == nil or wall.Distance >= delta.Magnitude - 0.4
end

-- может ли пуля дойти до врага
function M.F.PathClear(oa, ob, part, ch)
    local p = part.Position
    if M.F.LineClear(oa, p) or (ob and M.F.LineClear(ob, p)) then return true end
    local head, torso = M.GetHead(ch), M.GetTorso(ch)
    if head and head ~= part then
        local q = head.Position
        if M.F.LineClear(oa, q) or (ob and M.F.LineClear(ob, q)) then return true end
    end
    if torso and torso ~= part and torso ~= head then
        local q = torso.Position
        if M.F.LineClear(oa, q) or (ob and M.F.LineClear(ob, q)) then return true end
    end
    return false
end

-- урон врагу ваш?
-- линия прицела рядом с врагом: до 4 стадов сбоку плюс небольшой конус
local function nearAimLine(ch, ro, rd)
    local root = M.GetRoot(ch) or M.GetHead(ch)
    if not root or not ro then return false end
    local rv = root.Position - ro
    local along = rv:Dot(rd)
    if along <= 0 then return false end
    return (rv - rd * along).Magnitude < 4 + along * 0.12
end

function M.F.HitIsMine(ch, hum, now, ro, rd)
    local D = M.Data
    local tag = hum and hum:FindFirstChild("creator")
    if tag and tag:IsA("ObjectValue") then
        local who = tag.Value
        if who == M.LP then return true end
        if who ~= nil then return false end
    end
    local window = M.F.ShotWindow()
    if now - D.LastShot > window then return false end
    local seen = D.AimSeen[ch]
    if seen ~= nil and now - seen <= window then return true end
    -- свободный режим: стреляли, а урон получил враг, которого доводка держит или который рядом с линией прицела
    -- (разброс, отдача, пули игры не идут ровно в центр, а стены могут быть из невидимых деталей)
    if M.State.HitLoose then
        if D.AimLockChar == ch and D.AimLock ~= nil then return true end
        return nearAimLine(ch, ro, rd)
    end
    return false
end

-- выстрел предметом в руках
function M.F.HitWatchTool(on)
    local D = M.Data
    local char = on and M.LP and M.LP.Character
    local tool = char and char:FindFirstChildOfClass("Tool") or nil
    if tool == D.HitTool then return end
    if D.HitToolConn then
        M.F.Untrack(D.HitToolConn)
        D.HitToolConn = nil
    end
    D.HitTool = tool
    if tool then
        D.HitToolConn = M.Track(tool.Activated:Connect(function() M.Data.LastShot = os.clock() end))
    end
end

function M.F.UpdateEnemyHealth()
    local S, D = M.State, M.Data
    if not (S.DamageNumbers or S.HitMarkerOn or S.HitRingsOn) then
        -- все функции выключены
        if next(D.HpCache) ~= nil then table.clear(D.HpCache) end
        if D.HitToolConn then M.F.HitWatchTool(false) end
        return
    end
    if (S.HitMarkerOn or S.HitRingsOn) and not M.Run.MenuOpen and (D.TriggerHeld or M.Services.U:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then
        D.LastShot = os.clock()
    end
    local pollNow = os.clock()
    if pollNow - (D.EnemyPoll or 0) < 0.05 then return end
    D.EnemyPoll = pollNow
    local cam = workspace.CurrentCamera
    local marker = (S.HitMarkerOn or S.HitRingsOn) and cam ~= nil
    M.F.HitWatchTool(marker)
    local shooting, ro, rd, oa, ob = false, nil, nil, nil, nil
    if marker and pollNow - D.LastShot <= M.F.ShotWindow() then
        local point = M.GetAimPoint(cam)
        local ray = cam:ViewportPointToRay(point.X, point.Y)
        ro, rd = ray.Origin, ray.Direction.Unit
        oa, ob = M.F.ShotOrigins(cam)
        shooting = true
    end
    for _, plr in ipairs(M.F.Players()) do
        if plr ~= M.LP then
            local ch = M.F.CharOf(plr)
            local hum = ch and M.GetHumanoid(ch)
            local head = ch and M.GetHead(ch)
            if ch and head then
                if shooting then
                    -- детали тела перебираются только у тех, кто рядом с линией прицела: иначе на каждого врага по 15 деталей 20 раз в секунду
                    local root = M.GetRoot(ch)
                    local rv = (root or head).Position - ro
                    local along = rv:Dot(rd)
                    -- у больших моделей (боссы) запас шире: по размеру корня
                    if along > -4 and (rv - rd * along).Magnitude < math.max(7, (root or head).Size.Magnitude * 2.5) then
                        local part = M.F.AimedPart(ch, ro, rd)
                        if part and M.F.PathClear(oa, ob, part, ch) then D.AimSeen[ch] = pollNow end
                    end
                end
                local nowHp, maxHp, custom = M.F.CharHealth(ch, hum)
                -- без Humanoid урон видно только по своему здоровью игры
                local key = hum or (custom and ch) or nil
                local last = key and D.HpCache[key]
                if key then D.HpCache[key] = nowHp end
                -- порог падения
                if last and nowHp < last - math.min(0.5, math.max(maxHp, 1) * 0.005) then
                    if S.DamageNumbers then M.F.SpawnDamageNumber(head, last - nowHp) end
                    if marker and M.F.HitIsMine(ch, hum, pollNow, ro, rd) then
                        local killed = nowHp <= 0 or (hum ~= nil and hum.Health <= 0)
                        if S.HitMarkerOn then M.F.ShowHitMarker(killed, M.GetAimPoint(cam)) end
                        if S.HitRingsOn and M.F.HitRings then M.F.HitRings(ch, killed) end
                    end
                end
            end
        end
    end
end

end}

-- [40/69] Виджеты и виджет скорости (построение)
MODULES[#MODULES + 1] = {"40. Виджеты и виджет скорости (построение)", function(M, __X)
-- ==============================================================================
-- [ ВИДЖЕТЫ И ПАНЕЛЬ НАБЛЮДЕНИЯ ]
-- ==============================================================================
function M.F.EnsureWidgetGui()
    if not M.UI.WidgetGui then M.UI.WidgetGui = M.F.NewGui("Widgets", 55) end
end

function M.F.ReleaseWidgetGui()
    if M.UI.WidgetGui and not M.UI.SpeedWidget and not M.UI.SpecBar and not M.UI.KeysWidget and not M.UI.BindList and not M.UI.MusicWidget then
        M.UI.WidgetGui:Destroy()
        M.UI.WidgetGui = nil
    end
end

-- полностью убирает панель
function M.F.DestroyPanel(panel)
    for _, conn in ipairs(panel.Conns or {}) do M.F.Untrack(conn) end
    panel.Conns = nil
    if panel.SmoothConn then M.F.Untrack(panel.SmoothConn); panel.SmoothConn = nil end
    for i = #M.Data.Panels, 1, -1 do
        if M.Data.Panels[i] == panel then table.remove(M.Data.Panels, i) end
    end
    panel.Root:Destroy()
    pcall(M.F.PruneRegistries)
end

function M.F.StylePanel(panel)
    local ios = M.State.Ios26On
    local radius = ios and panel.Corner or math.min(panel.Corner, 10)
    for _, corner in ipairs(panel.Corners) do corner.CornerRadius = UDim.new(0, radius) end

    if ios then
        -- те же цвета, что у инфо-панели и уведомлений
        panel.FillAlpha = M.State.PillAlpha
        panel.Fill.BackgroundColor3 = M.State.PillBg
        panel.Stroke.Color = Color3.fromRGB(255, 255, 255)
        panel.Stroke.Thickness = 1.2
        panel.StrokeGrad.Enabled = true
        panel.StrokeGrad.Color = ColorSequence.new(M.Style.AccentMix(0.45), M.Style.Stroke)
        panel.StrokeGrad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.22),
            NumberSequenceKeypoint.new(0.5, 0.7),
            NumberSequenceKeypoint.new(1, 0.4)
        })
    else
        panel.FillAlpha = 0.04
        panel.Fill.BackgroundColor3 = M.Style.Surface
        panel.Stroke.Color = M.State.BorderCol
        panel.Stroke.Thickness = 1
        panel.StrokeGrad.Enabled = false
    end
    if panel.Glow then panel.Glow.Set(ios and M.Style.SurfaceGlow or 0) end
    if panel.Glass then
        panel.Glass.SetRadius(UDim.new(0, radius))
        panel.Glass.SetVisible(M.State.GlassOn and ios)
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
    M.Style.ApplyGlassSurfaces()
end

-- создаёт панель из трёх слоёв ОДИНАКОВОЙ формы
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

    -- свечение под панелью
    panel.Glow = M.Style.AccentGlow(root, 14, M.Style.SurfaceGlow, UDim.new(0, corner + 8), 0)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BorderSizePixel = 0
    addCorner(fill)
    fill.Parent = root

    panel.Glass = M.Style.BuildGlass(root, UDim.new(0, corner), {Ios = true})

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

-- перетаскивание панели мышью
function M.F.MakePanelDraggable(panel, handle)
    local posKey = panel.PosKey
    local dragging, dragStart, startX, startY = false, nil, 0, 0
    local curX, curY = M.State[posKey .. "X"], M.State[posKey .. "Y"]
    local smoothConn
    local function restGlow()
        return M.State.Ios26On and M.Style.SurfaceGlow or 0
    end
    local function stopSmooth()
        if smoothConn then
            M.F.Untrack(smoothConn)
            smoothConn, panel.SmoothConn = nil, nil
        end
    end
    local function startSmooth()
        if smoothConn then return end
        smoothConn = M.Track(M.Services.R.RenderStepped:Connect(function(dt)
            local targetX, targetY = M.State[posKey .. "X"], M.State[posKey .. "Y"]
            local blend = 1 - math.exp(-dt * 16 / M.Style.Scale())
            curX = curX + (targetX - curX) * blend
            curY = curY + (targetY - curY) * blend
            if not dragging and math.abs(targetX - curX) < 0.0004 and math.abs(targetY - curY) < 0.0004 then
                curX, curY = targetX, targetY
                panel.Root.Position = UDim2.new(curX, 0, curY, 0)
                stopSmooth()
            else
                panel.Root.Position = UDim2.new(curX, 0, curY, 0)
            end
        end))
        panel.SmoothConn = smoothConn
    end
    handle.Active = true
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            panel.Dragging = true
            dragStart = inp.Position
            startX, startY = M.State[posKey .. "X"], M.State[posKey .. "Y"]
            curX, curY = panel.Root.Position.X.Scale, panel.Root.Position.Y.Scale
            if panel.Glow then panel.Glow.Set(restGlow() * 2.5 + 0.1, 0.2) end
            startSmooth()
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
    end))
    table.insert(panel.Conns, M.Conn(M.Services.U.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                panel.Dragging = false
                if panel.Glow then panel.Glow.Set(restGlow(), 0.35) end
            end
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

-- ---------------- Виджет скорости
function M.F.BuildSpeedWidget()
    local panel = M.F.MakePanel(M.UI.WidgetGui, "SpeedWidget", 220, 132, 30, "SpeedWidget", false)
    local widget = {
        Panel = panel, Slots = {}, Vals = {}, N = 0, LastV = 0, PeakV = 0, Scale = 80, ScaleK = 0, Rescale = false,
        BallY = -1, ShownInt = 0, NumberAt = 0, BreatheAt = 0, StripX = -1e9, LiveX = -1e9, LiveY = -1e9, LiveLen = -1e9, LiveAng = -1e9,
        Left = 16, Right = 204, BaseY = 77, GraphHeight = 54, Step = 3, Interval = 1 / 15
    }
    panel.Content.ClipsDescendants = true  -- ореол шарика не выходит за края панели
    local total = math.floor((widget.Right - widget.Left) / widget.Step)  -- 62 значения, между ними 61 отрезок
    widget.Count, widget.Total = total - 1, total
    for i = 1, total do widget.Vals[i] = 0 end
    M.Data.SpeedShown, M.Data.SpeedClock = 0, 0

    local strip = Instance.new("Frame")
    strip.Name = "Strip"
    strip.Size = UDim2.new(1, 0, 1, 0)
    strip.BackgroundTransparency = 1
    strip.BorderSizePixel = 0
    strip.Parent = panel.Content
    widget.Strip = strip

    local function newSegment(parent)
        local segment = Instance.new("Frame")
        segment.AnchorPoint = Vector2.new(0.5, 0.5)
        segment.Size = UDim2.fromOffset(4, 3)
        segment.BackgroundColor3 = M.State.Accent
        segment.BorderSizePixel = 0
        segment.Visible = false
        segment.Parent = parent
        return segment
    end
    for i = 1, widget.Count do
        widget.Slots[i] = {Seg = newSegment(strip), N = 0, V0 = 0, V1 = 0, X = -1e9, Y = -1e9, Len = -1e9, Ang = -1e9,
            Zone = -1, Ver = -1, Scale = 0, On = false}
    end
    -- живой отрезок
    widget.Live = newSegment(panel.Content)
    widget.Live.Visible = true

    -- тонкая базовая линия
    local baseline = Instance.new("Frame")
    baseline.Name = "Baseline"
    baseline.Position = UDim2.fromOffset(widget.Left, widget.BaseY + 4)
    baseline.Size = UDim2.fromOffset(widget.Right - widget.Left, 1)
    baseline.BackgroundColor3 = M.Style.Stroke
    baseline.BackgroundTransparency = 0.35
    baseline.BorderSizePixel = 0
    baseline.Parent = panel.Content
    local baselineFade = Instance.new("UIGradient", baseline)
    baselineFade.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.2), NumberSequenceKeypoint.new(1, 0.2)
    })

    -- шарик с мягким пульсирующим ореолом
    widget.Glow = Instance.new("Frame")
    widget.Glow.AnchorPoint = Vector2.new(0.5, 0.5)
    widget.Glow.Size = UDim2.fromOffset(22, 22)
    widget.Glow.BackgroundColor3 = M.State.Accent
    widget.Glow.BackgroundTransparency = 0.7
    widget.Glow.BorderSizePixel = 0
    Instance.new("UICorner", widget.Glow).CornerRadius = UDim.new(1, 0)
    widget.Glow.Parent = panel.Content
    widget.Halo = Instance.new("Frame")
    widget.Halo.AnchorPoint = Vector2.new(0.5, 0.5)
    widget.Halo.Size = UDim2.fromOffset(38, 38)
    widget.Halo.BackgroundColor3 = M.State.Accent
    widget.Halo.BackgroundTransparency = 0.9
    widget.Halo.BorderSizePixel = 0
    Instance.new("UICorner", widget.Halo).CornerRadius = UDim.new(1, 0)
    widget.Halo.Parent = panel.Content
    widget.Ball = Instance.new("Frame")
    widget.Ball.AnchorPoint = Vector2.new(0.5, 0.5)
    widget.Ball.Size = UDim2.fromOffset(10, 10)
    widget.Ball.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    widget.Ball.BorderSizePixel = 0
    widget.Ball.ZIndex = 2
    Instance.new("UICorner", widget.Ball).CornerRadius = UDim.new(1, 0)
    widget.Ball.Parent = panel.Content

    widget.Number = panelLabel(panel.Content, "Number", Enum.Font.GothamBold, 30, UDim2.new(0, 0, 0, 86), UDim2.new(1, 0, 0, 34),
        M.Style.Text)
    widget.Number.Text = "0"
    -- цифры чуть темнеют к низу
    local numberDepth = Instance.new("UIGradient", widget.Number)
    numberDepth.Rotation = 90
    numberDepth.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(176, 186, 218))
    widget.Unit = panelLabel(panel.Content, "Unit", Enum.Font.GothamMedium, 11, UDim2.new(0, 0, 0, 114), UDim2.new(1, 0, 0, 14),
        M.Style.TextDim)
    widget.Unit.Text = M.Translate("SpeedUnit")
    M.F.AddTempReg(widget, {SetLanguage = function() widget.Unit.Text = M.Translate("SpeedUnit") end})

    M.F.MakePanelDraggable(panel, panel.Root)
    return widget
end

__X.panelLabel = panelLabel
end}

-- [41/69] Виджет скорости и панель наблюдения
MODULES[#MODULES + 1] = {"41. Виджет скорости и панель наблюдения", function(M, __X)
-- геометрия отрезка слота по его значениям и текущему масштабу
local function speedSlotGeometry(widget, slot)
    local step, scale = widget.Step, widget.Scale
    local x0 = (slot.N - 1) * step
    local y0 = widget.BaseY - math.clamp(slot.V0 / scale, 0, 1) * widget.GraphHeight
    local y1 = widget.BaseY - math.clamp(slot.V1 / scale, 0, 1) * widget.GraphHeight
    local cx, cy, length, angle = M.Math.LineSegment(x0, y0, x0 + step, y1)
    local seg = slot.Seg
    if math.abs(cx - slot.X) > 0.01 or math.abs(cy - slot.Y) > 0.01 then
        seg.Position = UDim2.fromOffset(cx, cy)
        slot.X, slot.Y = cx, cy
    end
    if math.abs(length - slot.Len) > 0.01 then
        seg.Size = UDim2.fromOffset(length + 1.5, 3)
        slot.Len = length
    end
    if math.abs(angle - slot.Ang) > 0.02 then
        seg.Rotation = angle
        slot.Ang = angle
    end
    slot.Scale = scale
end

-- цвет и видимость отрезков по возрасту
local function speedColorPass(widget)
    local back = widget.Panel.Fill.BackgroundColor3
    local accent = M.State.Accent
    local ver = M.Data.AccentVersion
    for _, slot in ipairs(widget.Slots) do
        if slot.N > 0 then
            local x = widget.Right - (widget.N - slot.N) * widget.Step
            local zone = math.floor(math.clamp((x - widget.Left) / 90, 0, 1) ^ 0.8 * 8 + 0.5)
            if zone ~= slot.Zone or slot.Ver ~= ver then
                local seg = slot.Seg
                if zone == 0 then
                    if slot.On then seg.Visible = false slot.On = false end
                else
                    if not slot.On then seg.Visible = true slot.On = true end
                    seg.BackgroundColor3 = back:Lerp(accent, zone / 8)
                end
                slot.Zone, slot.Ver = zone, ver
            end
        end
    end
end

-- ступень масштаба
local function speedScaleStep(peak, k)
    local need = math.max(peak * 1.1, 1)
    local level = 80 * 1.5 ^ k
    if need > level then return math.ceil(math.log(need / 80) / math.log(1.5)) end
    if k > 0 and need < level * 0.55 then return math.max(0, math.ceil(math.log(need / 80) / math.log(1.5))) end
    return k
end

-- новый замер
local function speedPush(widget, value)
    local count, step = widget.Count, widget.Step
    widget.N = widget.N + 1
    local n = widget.N
    local slot = widget.Slots[(n - 1) % count + 1]
    slot.N, slot.V0, slot.V1, slot.Zone = n, widget.LastV, value, -1
    widget.LastV = value
    widget.Vals[n % widget.Total + 1] = value
    speedSlotGeometry(widget, slot)

    local cycle = count * widget.Total
    if n >= cycle * 2 then
        local delta = cycle * math.floor(n / (cycle * 2))
        widget.N = n - delta
        for _, s in ipairs(widget.Slots) do
            if s.N > 0 then
                s.N = s.N - delta
                s.X = s.X - delta * step
                s.Seg.Position = UDim2.fromOffset(s.X, s.Y)
            end
        end
    end

    local peak = value
    for _, v in ipairs(widget.Vals) do if v > peak then peak = v end end
    widget.PeakV = peak
    local k = speedScaleStep(peak, widget.ScaleK)
    if k ~= widget.ScaleK then
        widget.ScaleK = k
        widget.Scale = 80 * 1.5 ^ k
        widget.Rescale = true
    end
    speedColorPass(widget)
end

function M.F.UpdateSpeedWidget(dt)
    local widget = M.UI.SpeedWidget
    local D = M.Data
    local visible = M.State.SpeedWidgetOn
    if widget.Panel.Root.Visible ~= visible then widget.Panel.Root.Visible = visible end
    if not visible then return end
    M.F.SetProp(widget.Panel.Scale, "Scale", M.State.SpeedWidgetScale)

    -- плавная скорость для линии и шарика
    local shown = M.Math.Smooth(D.SpeedShown, D.Speed3D, dt, 7)
    D.SpeedShown = shown
    local now = os.clock()

    -- число
    if now - widget.NumberAt >= 0.2 then
        local want = (shown < 0.5) and 0 or math.floor(shown + 0.5)
        if want ~= widget.ShownInt and (want == 0 or math.abs(shown - widget.ShownInt) > 0.9) then
            widget.ShownInt = want
            widget.Number.Text = tostring(want)
            widget.NumberAt = now
        end
    end
    local colorStep = math.floor(math.clamp(shown / 70, 0, 1) * 24 + 0.5)
    if colorStep ~= widget.ColorStep or widget.ColorVer ~= D.AccentVersion then
        widget.ColorStep, widget.ColorVer = colorStep, D.AccentVersion
        widget.Number.TextColor3 = M.Style.Text:Lerp(M.Style.AccentMix(0.25), colorStep / 24 * 0.85)
    end

    -- замеры для линии
    local flat = shown < 0.5 and widget.PeakV < 0.5
    if flat then
        D.SpeedClock = 0
    else
        D.SpeedClock = math.min(D.SpeedClock + dt, 0.25)
        while D.SpeedClock >= widget.Interval do
            D.SpeedClock = D.SpeedClock - widget.Interval
            speedPush(widget, shown)
        end
    end

    if widget.AccentSeen ~= D.AccentVersion then
        widget.AccentSeen = D.AccentVersion
        speedColorPass(widget)
        widget.Live.BackgroundColor3 = M.State.Accent
        widget.Glow.BackgroundColor3 = M.State.Accent
        widget.Halo.BackgroundColor3 = M.State.Accent
    end
    -- смена ступени масштаба
    if widget.Rescale then
        local budget, pending = 20, false
        for _, slot in ipairs(widget.Slots) do
            if slot.N > 0 and slot.Scale ~= widget.Scale then
                if budget <= 0 then pending = true break end
                speedSlotGeometry(widget, slot)
                budget = budget - 1
            end
        end
        widget.Rescale = pending
    end

    -- каждый кадр
    local shift = D.SpeedClock / widget.Interval * widget.Step
    local stripX = widget.Right - shift - widget.N * widget.Step
    if math.abs(stripX - widget.StripX) > 0.05 then
        widget.StripX = stripX
        widget.Strip.Position = UDim2.fromOffset(stripX, 0)
    end
    local headY = widget.BaseY - math.clamp(shown / widget.Scale, 0, 1) * widget.GraphHeight
    local lastY = widget.BaseY - math.clamp(widget.LastV / widget.Scale, 0, 1) * widget.GraphHeight
    local cx, cy, length, angle = M.Math.LineSegment(widget.Right - shift, lastY, widget.Right, headY)
    local live = widget.Live
    if math.abs(cx - widget.LiveX) > 0.03 or math.abs(cy - widget.LiveY) > 0.03 then
        widget.LiveX, widget.LiveY = cx, cy
        live.Position = UDim2.fromOffset(cx, cy)
    end
    if math.abs(length - widget.LiveLen) > 0.03 then
        widget.LiveLen = length
        live.Size = UDim2.fromOffset(length + 1.5, 3)
    end
    if math.abs(angle - widget.LiveAng) > 0.1 then
        widget.LiveAng = angle
        live.Rotation = angle
    end

    if math.abs(headY - widget.BallY) > 0.03 then
        widget.BallY = headY
        widget.Ball.Position = UDim2.fromOffset(widget.Right, headY)
        widget.Glow.Position = widget.Ball.Position
        widget.Halo.Position = widget.Ball.Position
    end
    -- ореол «дышит»
    if now - widget.BreatheAt >= 0.033 then
        widget.BreatheAt = now
        local energy = math.clamp(shown / 80, 0, 1)
        local breathe = math.sin(now * 3.2)
        widget.Glow.BackgroundTransparency = 0.76 - 0.12 * energy + 0.08 * breathe
        widget.Halo.BackgroundTransparency = 0.93 - 0.06 * energy + 0.03 * breathe
        local haloSize = 38 + 14 * energy + 3 * breathe
        widget.Halo.Size = UDim2.fromOffset(haloSize, haloSize)
    end
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
        M.Data.SpeedShown, M.Data.SpeedClock = 0, 0
        M.F.ReleaseWidgetGui()
    end
})

end}

-- [42/69] Виджет клавиш (W A S D, пробел)
MODULES[#MODULES + 1] = {"42. Виджет клавиш (W A S D, пробел)", function(M, __X)
local panelLabel = __X.panelLabel
-- ==============================================================================
-- [ ВИДЖЕТ КЛАВИШ ]
-- ==============================================================================
local KW = {
    Pad = 14,  -- поле панели вокруг клавиш
    Defs = {
        {Id = "W", Code = Enum.KeyCode.W, Text = "W", X = 50, Y = 0, W = 44, H = 44, Tilt = 0},
        {Id = "A", Code = Enum.KeyCode.A, Text = "A", X = 0, Y = 50, W = 44, H = 44, Tilt = -5},
        {Id = "S", Code = Enum.KeyCode.S, Text = "S", X = 50, Y = 50, W = 44, H = 44, Tilt = 0},
        {Id = "D", Code = Enum.KeyCode.D, Text = "D", X = 100, Y = 50, W = 44, H = 44, Tilt = 5},
        {Id = "Space", Code = Enum.KeyCode.Space, Text = "SPACE", X = 0, Y = 100, W = 144, H = 30, Tilt = 0, Small = true},
        {Id = "M1", Mouse = Enum.UserInputType.MouseButton1, TextKey = "Keys_Lmb", X = 0, Y = 136, W = 69, H = 28, Tilt = 0, Small = true, IsMouse = true},
        {Id = "M2", Mouse = Enum.UserInputType.MouseButton2, TextKey = "Keys_Rmb", X = 75, Y = 136, W = 69, H = 28, Tilt = 0, Small = true, IsMouse = true},
    },
    Idle = Color3.fromRGB(232, 236, 250),
}

function KW.tween(inst, secs, goal, style, dir)
    M.Services.T:Create(inst, TweenInfo.new(secs, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal):Play()
end

-- цвет текста на залитой клавише
function KW.onColor(col)
    local lum = 0.299 * col.R + 0.587 * col.G + 0.114 * col.B
    return lum > 0.62 and Color3.fromRGB(14, 16, 24) or Color3.new(1, 1, 1)
end

function KW.panelSize()
    local pad = KW.Pad
    return 144 + 2 * pad, (M.State.KeysMouse and 164 or 130) + 2 * pad
end

function KW.makeKey(parent, def)
    local k = {Def = def, Down = false, At = 0}
    local holder = Instance.new("Frame")
    holder.Name = def.Id
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.Position = UDim2.fromOffset(KW.Pad + def.X, KW.Pad + def.Y)
    holder.Size = UDim2.fromOffset(def.W, def.H)
    holder.Parent = parent
    k.Holder = holder

    -- корпус клавиши
    local body = Instance.new("Frame")
    body.Name = "Body"
    body.AnchorPoint = Vector2.new(0.5, 0.5)
    body.Position = UDim2.fromScale(0.5, 0.5)
    body.Size = UDim2.fromScale(1, 1)
    body.BorderSizePixel = 0
    body.ClipsDescendants = true
    k.BodyCorner = Instance.new("UICorner", body)
    k.Stroke = Instance.new("UIStroke", body)
    k.Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    k.Shine = Instance.new("UIGradient", body)
    k.Shine.Rotation = 90
    k.Scale = Instance.new("UIScale", body)
    body.Parent = holder
    k.Body = body

    -- заливка цвета клавиши
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(1, 1)
    fill.BackgroundTransparency = 1
    fill.BorderSizePixel = 0
    k.FillCorner = Instance.new("UICorner", fill)
    k.FillGrad = Instance.new("UIGradient", fill)
    k.FillGrad.Rotation = 90
    fill.Parent = body
    k.Fill = fill

    -- волна от нажатия
    local ripple = Instance.new("Frame")
    ripple.Name = "Ripple"
    ripple.AnchorPoint = Vector2.new(0.5, 0.5)
    ripple.Position = UDim2.fromScale(0.5, 0.5)
    ripple.Size = UDim2.fromOffset(0, 0)
    ripple.BackgroundColor3 = Color3.new(1, 1, 1)
    ripple.BackgroundTransparency = 1
    ripple.BorderSizePixel = 0
    ripple.ZIndex = 2
    Instance.new("UICorner", ripple).CornerRadius = UDim.new(1, 0)
    ripple.Parent = body
    k.Ripple = ripple

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = def.Small and 12 or 17
    label.ZIndex = 3
    label.Parent = body
    k.Label = label
    return k
end

-- оформление всех клавиш по настройкам
function KW.restyle()
    local W = M.UI.KeysWidget
    if not W then return end
    local S = M.State
    local style = S.KeysStyle
    local active, base = S.KeysColor, S.KeysBase
    local radius = math.clamp(S.KeysRound or 10, 0, 22)
    local hot = active:Lerp(Color3.new(1, 1, 1), 0.38)
    for _, k in ipairs(W.Keys) do
        local def = k.Def
        local r = def.Small and math.min(radius, def.H / 2) or radius
        k.BodyCorner.CornerRadius = UDim.new(0, r)
        k.FillCorner.CornerRadius = UDim.new(0, r)
        k.Fill.BackgroundColor3 = Color3.new(1, 1, 1)
        k.FillGrad.Color = ColorSequence.new(hot, active)
        k.Body.BackgroundColor3 = base
        k.Shine.Enabled = false
        k.Stroke.Thickness = 1
        k.Stroke.Color = Color3.new(1, 1, 1)
        k.Stroke.Transparency = 0.8
        k.Body.BackgroundTransparency = S.KeysAlpha
        k.IdleText = KW.Idle
        k.IdleStroke = {Color3.new(1, 1, 1), 0.8}
        k.FillOn = 0.0
        if style == "Glass" then
            k.Shine.Enabled = true
            k.Shine.Color = ColorSequence.new(base:Lerp(Color3.new(1, 1, 1), 0.22), base)
            k.Stroke.Thickness = 1.3
            k.Stroke.Transparency = 0.55
            k.IdleStroke = {Color3.new(1, 1, 1), 0.55}
            k.FillOn = 0.1
        elseif style == "Solid" then
            k.Body.BackgroundTransparency = math.min(S.KeysAlpha, 0.2)
            k.Stroke.Thickness = 0
            k.IdleStroke = {Color3.new(1, 1, 1), 1}
        elseif style == "Outline" then
            k.Body.BackgroundTransparency = 1
            k.Stroke.Thickness = 2
            k.Stroke.Color = active
            k.Stroke.Transparency = 0.35
            k.IdleStroke = {active, 0.35}
            k.IdleText = active
            k.FillOn = 0.15
        else  -- neon
            k.Stroke.Thickness = 2
            k.Stroke.Color = active
            k.Stroke.Transparency = 0.05
            k.IdleStroke = {active, 0.05}
            k.IdleText = active
            k.FillOn = 0.2
        end
        k.Label.TextColor3 = k.IdleText
        k.Label.Visible = S.KeysLabels ~= false
        if def.TextKey then k.Label.Text = M.Translate(def.TextKey) else k.Label.Text = def.Text end
        if def.IsMouse then k.Holder.Visible = S.KeysMouse == true end
        k.Fill.BackgroundTransparency = k.Down and k.FillOn or 1
        k.Scale.Scale = k.Down and 0.88 or 1
        if k.Down then
            k.Label.TextColor3 = KW.onColor(active)
            k.Stroke.Color, k.Stroke.Transparency = active, 0
        end
    end
    local w, h = KW.panelSize()
    W.Panel.Root.Size = UDim2.fromOffset(w, h)
end

-- нажатие и отпускание одной клавиши
function KW.press(k, down)
    local S = M.State
    local fx = S.KeysFx
    local active = S.KeysColor
    if down then
        k.Label.TextColor3 = KW.onColor(active)
        if fx then
            KW.tween(k.Scale, 0.07, {Scale = 0.86})
            KW.tween(k.Fill, 0.08, {BackgroundTransparency = k.FillOn})
            KW.tween(k.Stroke, 0.08, {Color = active, Transparency = 0})
            KW.tween(k.Body, 0.12, {Rotation = k.Def.Tilt})
            -- волна
            local d = math.max(k.Def.W, k.Def.H) * 1.9
            k.Ripple.Size = UDim2.fromOffset(0, 0)
            k.Ripple.BackgroundTransparency = 0.45
            KW.tween(k.Ripple, 0.5, {Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1})
        else
            k.Scale.Scale = 0.9
            k.Fill.BackgroundTransparency = k.FillOn
            k.Stroke.Color, k.Stroke.Transparency = active, 0
        end
    else
        k.Label.TextColor3 = k.IdleText
        if fx then
            KW.tween(k.Scale, 0.32, {Scale = 1}, Enum.EasingStyle.Back)
            KW.tween(k.Fill, 0.3, {BackgroundTransparency = 1})
            KW.tween(k.Stroke, 0.3, {Color = k.IdleStroke[1], Transparency = k.IdleStroke[2]})
            KW.tween(k.Body, 0.32, {Rotation = 0}, Enum.EasingStyle.Back)
        else
            k.Scale.Scale = 1
            k.Fill.BackgroundTransparency = 1
            k.Stroke.Color, k.Stroke.Transparency = k.IdleStroke[1], k.IdleStroke[2]
            k.Body.Rotation = 0
        end
    end
end

-- каждый кадр
function KW.step()
    local W = M.UI.KeysWidget
    if not W then return end
    local now = os.clock()
    -- не чаще 120 раз в секунду: нажатие видно так же сразу, а опрос клавиш на 400 кадрах не нужен
    if now - (W.At or 0) < 1 / 120 then return end
    W.At = now
    if not W.Panel.Root.Parent then return end
    local S, U = M.State, M.Services.U
    local typing = U:GetFocusedTextBox() ~= nil
    for _, k in ipairs(W.Keys) do
        local def = k.Def
        local down = false
        if def.Code then
            down = (not typing) and U:IsKeyDown(def.Code)
        elseif S.KeysMouse and not M.Run.MenuOpen then
            down = U:IsMouseButtonPressed(def.Mouse)
        end
        if down ~= k.Down then
            k.Down, k.At = down, now
            KW.press(k, down)
        elseif down and S.KeysFx and now - k.At > 0.2 then
            k.Fill.BackgroundTransparency = k.FillOn + 0.08 + 0.08 * math.sin((now - k.At) * 7)
        end
    end
    local scale = math.clamp(S.KeysScale or 1, 0.4, 4)
    if W.ScaleSet ~= scale then W.ScaleSet = scale; W.Panel.Scale.Scale = scale end
    local active = M.Run.MenuOpen == true
    if W.ActiveSet ~= active then W.ActiveSet = active; W.Panel.Root.Active = active end
end

M.F.DefineModule("KeysWidget", {
    Wanted = function() return M.State.KeysOn end,
    Load = function()
        M.F.EnsureWidgetGui()
        local w, h = KW.panelSize()
        local panel = M.F.MakePanel(M.UI.WidgetGui, "KeysWidget", w, h, 26, "KeysWidget", false)
        panel.Content.ClipsDescendants = true
        local W = {Panel = panel, Keys = {}}
        for _, def in ipairs(KW.Defs) do
            W.Keys[#W.Keys + 1] = KW.makeKey(panel.Content, def)
        end
        M.F.MakePanelDraggable(panel, panel.Root)
        panel.Root.Active = false
        panel.Root.Visible = true
        W.Conn = M.Track(M.Services.R.RenderStepped:Connect(function()
            if M.Run.IsShutDown then return end
            M.F.Safe("KeysWidget", KW.step)
        end))
        M.UI.KeysWidget = W
        KW.restyle()
    end,
    Unload = function()
        local W = M.UI.KeysWidget
        M.UI.KeysWidget = nil
        if not W then return end
        if W.Conn then M.F.Untrack(W.Conn) end
        M.F.DestroyPanel(W.Panel)
        M.F.ReleaseWidgetGui()
    end
})

function M.F.KeysRestyle() KW.restyle() end

-- ---------------- Список клавиш: на что назначены и включено ли
local BL = {W = 230, HeadH = 32, RowH = 24, Pad = 8}

-- короткое имя функции для списка
function BL.name(id, locKey)
    local short = "BindName_" .. tostring(id)
    if M.L10N.Dict[short] then return M.Translate(short) end
    return M.Translate(locKey or id)
end

-- все назначенные клавиши и их состояние: включено, выключено, зажато или только что нажато
function BL.entries()
    local out = {}
    local S = M.State
    local now = os.clock()
    for _, b in ipairs(M.Data.Binds) do
        if b.Key then
            local state
            if b.IsOn then
                if b.IsOn() then
                    state = ((b.HeldOn or b.Mode == "Hold") and b.Down) and "BindList_Held" or "BindList_On"
                else
                    state = "BindList_Off"
                end
            else
                -- действие (например, телепорт): горит, пока клавиша зажата, и полсекунды после
                state = (b.Down or (b.PressedAt ~= nil and now - b.PressedAt < 0.6)) and "BindList_Pressed" or "BindList_Press"
            end
            out[#out + 1] = {Id = "b:" .. tostring(b.Id), Name = BL.name(b.Id, b.LocKey), Key = M.F.KeyLabel(b.Key), State = state}
        end
    end
    -- клавиши удержания доводки и выстрела
    local function holdKey(slot, enabled, mode, keyName, nameKey)
        if not enabled or (mode ~= "HoldKey" and mode ~= "HoldRmb") then return end
        local held = M.F.ModeActive(mode, keyName, slot)
        out[#out + 1] = {Id = "h:" .. slot, Name = M.Translate(nameKey),
            Key = mode == "HoldRmb" and M.Translate("Keys_Rmb") or M.F.KeyLabel(keyName),
            State = held and "BindList_Held" or "BindList_Off"}
    end
    holdKey("Aim", S.AimAssist, S.AimMode, S.AimKey, "BindName_AimAssist")
    holdKey("Trigger", S.TriggerAssist, S.TriggerMode, S.TriggerKey, "BindName_TriggerAssist")
    holdKey("Peek", S.PeekOn, "HoldKey", S.PeekKey, "BindName_Peek")
    return out
end

-- горит ли строка
BL.Lit = {BindList_On = true, BindList_Held = true, BindList_Pressed = true}

local function blTween(inst, secs, goal, style)
    M.Services.T:Create(inst, TweenInfo.new(secs * M.Style.Scale(), style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal):Play()
end

-- значок клавиатуры в шапке: по центру шапки, а не всей панели
function BL.icon(parent)
    local box = Instance.new("Frame")
    box.Size = UDim2.fromOffset(16, 12)
    box.Position = UDim2.fromOffset(12, math.floor(BL.HeadH / 2) - 6)
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    local body = Instance.new("Frame")
    body.Size = UDim2.fromOffset(16, 12)
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    Instance.new("UICorner", body).CornerRadius = UDim.new(0, 3)
    local st = Instance.new("UIStroke", body)
    st.Thickness = 1.5
    M.Style.Bind(st, "Color", 0.1)
    body.Parent = box
    for i = 0, 2 do
        local key = Instance.new("Frame")
        key.Size = UDim2.fromOffset(2, 2)
        key.Position = UDim2.fromOffset(3 + i * 4, 3)
        key.BorderSizePixel = 0
        M.Style.Bind(key, "BackgroundColor3", 0.1)
        key.Parent = box
    end
    local space = Instance.new("Frame")
    space.Size = UDim2.fromOffset(8, 2)
    space.Position = UDim2.fromOffset(4, 7)
    space.BorderSizePixel = 0
    M.Style.Bind(space, "BackgroundColor3", 0.1)
    space.Parent = box
    box.Parent = parent
    return box
end

function BL.build()
    M.F.EnsureWidgetGui()
    local panel = M.F.MakePanel(M.UI.WidgetGui, "BindList", BL.W, BL.HeadH + BL.RowH + BL.Pad, 16, "BindList", false)
    panel.Root.AnchorPoint = Vector2.new(0.5, 0)
    panel.Content.ClipsDescendants = true
    local W = {Panel = panel, Rows = {}, H = 0}

    BL.icon(panel.Content)
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(36, 0)
    title.Size = UDim2.new(1, -48, 0, BL.HeadH)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextColor3 = M.Style.Text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = M.Translate("BindListTitle")
    title.Parent = panel.Content
    W.Title = title
    -- линия цвета темы под шапкой, гаснет к краям
    local line = Instance.new("Frame")
    line.Position = UDim2.new(0, 10, 0, BL.HeadH - 1)
    line.Size = UDim2.new(1, -20, 0, 1)
    line.BorderSizePixel = 0
    M.Style.Bind(line, "BackgroundColor3")
    local fade = Instance.new("UIGradient", line)
    fade.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1)
    })
    line.Parent = panel.Content
    -- пусто
    local empty = Instance.new("TextLabel")
    empty.BackgroundTransparency = 1
    empty.Position = UDim2.fromOffset(14, BL.HeadH + 4)
    empty.Size = UDim2.new(1, -28, 0, BL.RowH)
    empty.Font = Enum.Font.GothamMedium
    empty.TextSize = 11
    empty.TextColor3 = M.Style.TextMute
    empty.TextXAlignment = Enum.TextXAlignment.Left
    empty.Parent = panel.Content
    W.Empty = empty

    M.F.MakePanelDraggable(panel, panel.Root)
    panel.Root.Visible = true
    M.F.AddTempReg(W, {SetLanguage = function()
        title.Text = M.Translate("BindListTitle")
        -- строки соберутся заново с новыми подписями
        BL.clearRows(W)
    end})
    return W
end

function BL.clearRows(W)
    for id, row in pairs(W.Rows) do row.Frame:Destroy(); W.Rows[id] = nil end
    W.Sig = nil
end

-- цвета строки по состоянию: горящая подсвечена цветом «вкл», выключенная приглушена
function BL.paint(row, state, instant)
    local lit = BL.Lit[state] == true
    local on = M.State.BindListOnCol or M.Style.Success
    local secs = instant and 0 or 0.25
    row.State.Text = M.Translate(state)
    blTween(row.Frame, secs, {BackgroundTransparency = lit and 0.9 or 1}, Enum.EasingStyle.Quad)
    blTween(row.Bar, secs, {BackgroundColor3 = lit and on or M.Style.TextMute, BackgroundTransparency = lit and 0 or 0.6}, Enum.EasingStyle.Quad)
    blTween(row.Name, secs, {TextTransparency = lit and 0 or 0.4}, Enum.EasingStyle.Quad)
    blTween(row.State, secs, {TextColor3 = lit and on or M.Style.TextMute, TextTransparency = lit and 0 or 0.2,
        BackgroundColor3 = lit and on or M.Style.TextMute, BackgroundTransparency = lit and 0.82 or 0.92}, Enum.EasingStyle.Quad)
    blTween(row.Key, secs, {TextTransparency = lit and 0 or 0.35, BackgroundTransparency = lit and 0.75 or 0.9}, Enum.EasingStyle.Quad)
    row.Lit = state
end

function BL.makeRow(W, e, y)
    local S = M.State
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.BackgroundColor3 = S.BindListOnCol or M.Style.Success
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, -16, 0, BL.RowH - 2)
    row.Position = UDim2.fromOffset(8, y + 8)
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    -- полоска состояния слева
    local bar = Instance.new("Frame")
    bar.AnchorPoint = Vector2.new(0, 0.5)
    bar.Position = UDim2.new(0, 5, 0.5, 0)
    bar.Size = UDim2.fromOffset(3, 12)
    bar.BorderSizePixel = 0
    bar.BackgroundTransparency = 1
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    bar.Parent = row
    -- справа: клавиша и состояние ровным столбцом
    local right = Instance.new("Frame")
    right.BackgroundTransparency = 1
    right.AnchorPoint = Vector2.new(1, 0.5)
    right.Position = UDim2.new(1, -5, 0.5, 0)
    right.Size = UDim2.new(0, 0, 0, 16)
    right.AutomaticSize = Enum.AutomaticSize.X
    local lay = Instance.new("UIListLayout", right)
    lay.FillDirection = Enum.FillDirection.Horizontal
    lay.HorizontalAlignment = Enum.HorizontalAlignment.Right
    lay.VerticalAlignment = Enum.VerticalAlignment.Center
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Padding = UDim.new(0, 5)
    local keyBox = Instance.new("TextLabel")
    keyBox.LayoutOrder = 1
    keyBox.Size = UDim2.fromOffset(0, 16)
    keyBox.AutomaticSize = Enum.AutomaticSize.X
    keyBox.Font = Enum.Font.GothamBold
    keyBox.TextSize = 10
    keyBox.Text = e.Key
    keyBox.BorderSizePixel = 0
    keyBox.BackgroundTransparency = 1
    keyBox.TextTransparency = 1
    keyBox.Visible = S.BindListKeys ~= false
    M.Style.Bind(keyBox, "BackgroundColor3")
    M.Style.Bind(keyBox, "TextColor3", 0.35)
    Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 5)
    local kp = Instance.new("UIPadding", keyBox)
    kp.PaddingLeft, kp.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
    keyBox.Parent = right
    local state = Instance.new("TextLabel")
    state.LayoutOrder = 2
    state.Size = UDim2.fromOffset(46, 16)
    state.Font = Enum.Font.GothamBold
    state.TextSize = 10
    state.BorderSizePixel = 0
    state.BackgroundTransparency = 1
    state.TextTransparency = 1
    state.Visible = S.BindListStates ~= false
    Instance.new("UICorner", state).CornerRadius = UDim.new(1, 0)
    state.Parent = right
    right.Parent = row
    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Position = UDim2.fromOffset(15, 0)
    -- имя занимает всё, что осталось слева от клавиши и состояния
    local rightW = (S.BindListStates ~= false and 51 or 0) + (S.BindListKeys ~= false and 44 or 0)
    name.Size = UDim2.new(1, -(20 + rightW), 1, 0)
    name.Font = Enum.Font.GothamMedium
    name.TextSize = 12
    name.TextColor3 = M.Style.Text
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.Text = e.Name
    name.TextTransparency = 1
    name.Parent = row
    row.Parent = W.Panel.Content
    local r = {Frame = row, Name = name, Key = keyBox, State = state, Bar = bar, Y = y, Entry = e}
    blTween(row, 0.35, {Position = UDim2.fromOffset(8, y)})
    BL.paint(r, e.State)
    return r
end

function BL.dropRow(row)
    blTween(row.Name, 0.2, {TextTransparency = 1}, Enum.EasingStyle.Quad)
    blTween(row.Key, 0.2, {TextTransparency = 1, BackgroundTransparency = 1}, Enum.EasingStyle.Quad)
    blTween(row.State, 0.2, {TextTransparency = 1, BackgroundTransparency = 1}, Enum.EasingStyle.Quad)
    blTween(row.Bar, 0.2, {BackgroundTransparency = 1}, Enum.EasingStyle.Quad)
    blTween(row.Frame, 0.25, {Position = UDim2.fromOffset(8, row.Y - 6), BackgroundTransparency = 1})
    task.delay(0.3 * M.Style.Scale(), function() row.Frame:Destroy() end)
end

function BL.step()
    local W = M.UI.BindList
    if not W or not W.Panel.Root.Parent then return end
    local S = M.State
    local root = W.Panel.Root
    local active = M.Run.MenuOpen == true
    if root.Active ~= active then root.Active = active end
    M.F.SetProp(W.Panel.Scale, "Scale", math.clamp(tonumber(S.BindListScale) or 1, 0.5, 3))
    local now = os.clock()
    if now - (W.At or 0) < 0.1 then return end
    W.At = now
    -- смена настроек виджета: строки собираются заново
    local onCol = S.BindListOnCol or M.Style.Success
    local cfg = tostring(S.BindListShow) .. tostring(S.BindListKeys) .. tostring(S.BindListStates) .. tostring(onCol)
    if cfg ~= W.Cfg then
        W.Cfg = cfg
        BL.clearRows(W)
    end
    local all = BL.entries()
    -- «только включённые»: выключенные строки не показываются
    local list = all
    if S.BindListShow == "BindActive" then
        list = {}
        for _, e in ipairs(all) do
            if BL.Lit[e.State] then list[#list + 1] = e end
        end
    end
    -- состояние меняется на месте; строки пересобираются, только когда меняется набор
    for _, e in ipairs(list) do
        local row = W.Rows[e.Id]
        if row and row.Lit ~= e.State then BL.paint(row, e.State) end
    end
    local parts = {}
    for i, e in ipairs(list) do parts[i] = e.Id .. "|" .. e.Key end
    local sig = table.concat(parts, ";")
    if sig == W.Sig then return end
    W.Sig = sig
    local seen = {}
    for i, e in ipairs(list) do
        seen[e.Id] = true
        local y = BL.HeadH + 4 + (i - 1) * BL.RowH
        local row = W.Rows[e.Id]
        if not row then
            W.Rows[e.Id] = BL.makeRow(W, e, y)
        else
            if row.Entry.Key ~= e.Key then row.Key.Text = e.Key end
            row.Entry = e
            if row.Y ~= y then
                row.Y = y
                blTween(row.Frame, 0.3, {Position = UDim2.fromOffset(8, y)})
            end
        end
    end
    for id, row in pairs(W.Rows) do
        if not seen[id] then
            W.Rows[id] = nil
            BL.dropRow(row)
        end
    end
    local n = #list
    W.Empty.Visible = n == 0
    W.Empty.Text = M.Translate((#all > 0) and "BindListNoneOn" or "BindListEmpty")
    local h = BL.HeadH + 4 + math.max(n, 1) * BL.RowH + BL.Pad
    if h ~= W.H then
        W.H = h
        blTween(root, 0.35, {Size = UDim2.fromOffset(BL.W, h)})
    end
end

M.F.DefineModule("BindList", {
    Wanted = function() return M.State.BindListOn end,
    Load = function()
        M.UI.BindList = BL.build()
        M.UI.BindList.Conn = M.Track(M.Services.R.RenderStepped:Connect(function()
            if M.Run.IsShutDown then return end
            M.F.Safe("BindList", BL.step)
        end))
    end,
    Unload = function()
        local W = M.UI.BindList
        M.UI.BindList = nil
        if not W then return end
        if W.Conn then M.F.Untrack(W.Conn) end
        M.F.RemoveTempRegs(W)
        M.F.DestroyPanel(W.Panel)
        M.F.ReleaseWidgetGui()
    end
})
-- ---------------- Панель наблюдения
function M.F.BuildSpecBar()
    local panel = M.F.MakePanel(M.UI.WidgetGui, "SpectateBar", 400, 64, 32, "Spec", false)
    local bar = {Panel = panel}

    local function circleButton(text, anchorX, offsetX)
        local button = Instance.new("TextButton")
        button.AnchorPoint = Vector2.new(anchorX, 0.5)
        button.Position = UDim2.new(anchorX, offsetX, 0.5, 0)
        button.Size = UDim2.fromOffset(46, 46)
        button.BackgroundColor3 = M.Style.Raised
        button.BackgroundTransparency = 0.2
        button.BorderSizePixel = 0
        button.Text = text
        button.TextColor3 = M.Style.Text
        button.Font = Enum.Font.GothamBold
        button.TextSize = 20
        button.AutoButtonColor = false
        Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
        local buttonStroke = M.Style.AddStroke(button, M.Style.Stroke, 1, M.Style.StrokeIdle)
        button.Parent = panel.Content
        -- наведение
        local buttonScale = Instance.new("UIScale", button)
        button.MouseEnter:Connect(function()
            M.Style.Tween(button, 0.18, {BackgroundColor3 = M.State.Accent:Lerp(M.Style.Raised, 0.7), TextColor3 = M.Style.AccentMix(0.6)})
            M.Style.Tween(buttonStroke, 0.18, {Color = M.State.Accent})
        end)
        button.MouseLeave:Connect(function()
            M.Style.Tween(button, 0.25, {BackgroundColor3 = M.Style.Raised, TextColor3 = M.Style.Text})
            M.Style.Tween(buttonStroke, 0.25, {Color = M.Style.Stroke})
            M.Style.Tween(buttonScale, 0.2, {Scale = 1})
        end)
        button.MouseButton1Down:Connect(function() M.Style.Tween(buttonScale, 0.1, {Scale = 0.92}) end)
        button.MouseButton1Up:Connect(function() M.Style.Tween(buttonScale, 0.3, {Scale = 1}, Enum.EasingStyle.Back) end)
        return button
    end
    bar.Prev = circleButton("<", 0, 9)
    bar.Next = circleButton(">", 1, -9)
    bar.Prev.MouseButton1Click:Connect(function() M.F.SpectateStep(-1) end)
    bar.Next.MouseButton1Click:Connect(function() M.F.SpectateStep(1) end)

    local info = Instance.new("Frame")
    info.Position = UDim2.new(0, 64, 0, 0)
    info.Size = UDim2.new(1, -128, 1, 0)
    info.BackgroundTransparency = 1
    info.Active = true
    info.Parent = panel.Content
    bar.TitleLabel = panelLabel(info, "Title", Enum.Font.GothamMedium, 10, UDim2.new(0, 0, 0, 12), UDim2.new(1, 0, 0, 14),
        M.Style.TextDim)
    bar.TitleLabel.Text = M.Translate("Spectate_Title")
    bar.NameLabel = panelLabel(info, "Name", Enum.Font.GothamBold, 17, UDim2.new(0, 0, 0, 27), UDim2.new(1, 0, 0, 24),
        M.Style.Text)
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

end}

-- [43/69] Эффект попадания, наблюдение, время
MODULES[#MODULES + 1] = {"43. Эффект попадания, наблюдение, время", function(M, __X)
-- ==============================================================================
-- [ МАРКЕР ПОПАДАНИЯ, НАБЛЮДЕНИЕ, ВРЕМЯ ]
-- ==============================================================================

-- эффект попадания
M.Data.HitShardMax = 24

-- запасной вариант из элементов меню строится только если рисовать поверх экрана нельзя
function M.F.HitGuiBuild()
    if M.UI.HitGui and M.UI.HitGui.Parent then return end
    M.UI.HitGui = M.F.NewGui("Hit", 250)
    M.UI.HitTweens = {}
    local function piece(w, h)
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Size = UDim2.fromOffset(w, h)
        f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.Parent = M.UI.HitGui
        return f
    end
    M.UI.HitSegments = {}
    for _, d in ipairs({{-1, -1, 45}, {1, -1, -45}, {-1, 1, -45}, {1, 1, 45}}) do
        local seg = piece(9, 2)
        seg.Rotation = d[3]
        table.insert(M.UI.HitSegments, {Frame = seg, DirX = d[1], DirY = d[2]})
    end
    M.UI.HitShards = {}
    for i = 1, M.Data.HitShardMax do M.UI.HitShards[i] = piece(6, 2) end
    -- кольцо
    local ring = piece(10, 10)
    Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5, 0)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Transparency = 1
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Parent = ring
    M.UI.HitRing = {Frame = ring, Stroke = stroke}
end

-- эффект из рисунков поверх экрана: каждый кадр пересчитывается по времени
function M.F.HitDrawStop()
    local H = M.Data.HitDraw
    if not H then return end
    M.Data.HitDraw = nil
    if H.Conn then H.Conn:Disconnect() end
    for _, e in ipairs(H.List) do
        for _, o in ipairs(e.Objs) do M.Draw.Remove(o) end
    end
end

local function hitDrawStep()
    local H = M.Data.HitDraw
    if not H then return end
    local now = os.clock()
    for i = #H.List, 1, -1 do
        local e = H.List[i]
        local p = (now - e.T0) / e.Dur
        if p >= 1 or M.Run.IsShutDown then
            for _, o in ipairs(e.Objs) do M.Draw.Remove(o) end
            table.remove(H.List, i)
        else
            local k = 1 - (1 - p) * (1 - p)
            local op = math.clamp(e.A0 * (1 - p), 0, 1)
            local px, py = e.X, e.Y
            for _, s in ipairs(e.Segs) do
                local c = e.Start + e.Travel * k
                local h = e.SegLen * 0.5 * 0.7071
                local cx, cy = px + s.DX * c, py + s.DY * c
                s.Obj.From = Vector2.new(cx - s.DX * h, cy - s.DY * h)
                s.Obj.To = Vector2.new(cx + s.DX * h, cy + s.DY * h)
                if e.LineAlpha then s.Obj.Transparency = op end
            end
            for _, s in ipairs(e.Shards) do
                local c = s.R0 + (s.R1 - s.R0) * k
                local cx, cy = px + s.DX * c, py + s.DY * c
                local h = s.Len * 0.5
                s.Obj.From = Vector2.new(cx - s.DX * h, cy - s.DY * h)
                s.Obj.To = Vector2.new(cx + s.DX * h, cy + s.DY * h)
                if e.LineAlpha then s.Obj.Transparency = op end
            end
            if e.Ring then
                e.Ring.Radius = (e.D0 + (e.D1 - e.D0) * k) * 0.5
                if e.CircleAlpha then e.Ring.Transparency = math.clamp(op - 0.1, 0, 1) end
            end
        end
    end
    if #H.List == 0 then M.F.HitDrawStop() end
end

-- возвращает false, если рисунки создать не получилось
function M.F.HitDrawShow(killed, point)
    local size, power, count, color = M.F.HitFxParams(killed)
    local caps = M.Draw.Caps or {}
    local objs = {}
    local failed = false
    local function new(kind)
        local o = M.Draw.New(kind)
        if o then objs[#objs + 1] = o else failed = true end
        return o
    end
    local e = {T0 = os.clock(), Dur = (killed and 0.55 or 0.32) * (0.8 + 0.2 * power), Objs = objs, X = point.X, Y = point.Y,
        A0 = math.clamp(0.5 + 0.35 * power, 0, 0.95), Start = (killed and 11 or 8) * size, SegLen = 9 * size,
        LineAlpha = caps.LineAlpha, CircleAlpha = caps.CircleAlpha, Segs = {}, Shards = {}}
    e.Travel = 7 * size * (0.7 + 0.3 * power)
    local segThick = math.max(1.5, 1.6 * size)
    for _, d in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
        local l = new("Line")
        if l then
            pcall(function() l.Color = color; l.Thickness = segThick end)
            e.Segs[#e.Segs + 1] = {Obj = l, DX = d[1], DY = d[2]}
        end
    end
    local turn = math.random() * math.pi * 2
    local shardThick = math.max(1, 1.6 * size)
    for i = 1, count do
        local l = new("Line")
        if l then
            local ang = turn + (i - 1) / count * math.pi * 2 + (math.random() - 0.5) * 0.25
            local r0 = 12 * size
            pcall(function() l.Color = color; l.Thickness = shardThick end)
            e.Shards[#e.Shards + 1] = {Obj = l, DX = math.cos(ang), DY = math.sin(ang), R0 = r0,
                R1 = r0 + (14 + 16 * power) * size * (0.6 + math.random() * 0.8), Len = (5 + 4 * power) * size}
        end
    end
    if power >= 0.15 then
        local ring = new("Circle")
        if ring then
            pcall(function()
                ring.Filled = false
                ring.Color = color
                ring.Thickness = math.max(1, 1.5 * size)
                if caps.CircleSides then ring.NumSides = 32 end
                ring.Position = Vector2.new(point.X, point.Y)
            end)
            e.Ring, e.D0, e.D1 = ring, 8 * size, (30 + 18 * power) * size * (killed and 1.25 or 1)
        end
    end
    if failed then
        for _, o in ipairs(objs) do M.Draw.Remove(o) end
        return false
    end
    local H = M.Data.HitDraw
    if not H then
        H = {List = {}}
        H.Conn = M.Services.R.RenderStepped:Connect(function()
            local ok, err = pcall(hitDrawStep)
            if not ok then M.Errors.Hit("HitFx", err) end
        end)
        M.Data.HitDraw = H
    end
    -- старый эффект гасится, чтобы не копились рисунки
    while #H.List >= 3 do
        local old = table.remove(H.List, 1)
        for _, o in ipairs(old.Objs) do M.Draw.Remove(o) end
    end
    H.List[#H.List + 1] = e
    for _, o in ipairs(objs) do pcall(function() o.Visible = true end) end
    pcall(hitDrawStep)
    return true
end

M.F.DefineModule("HitMarker", {
    Wanted = function() return M.State.HitMarkerOn end,
    Load = function() end,
    Unload = function()
        M.F.HitDrawStop()
        for _, tw in ipairs(M.UI.HitTweens or {}) do pcall(function() tw:Cancel() end) end
        if M.UI.HitGui then M.UI.HitGui:Destroy() end
        M.UI.HitGui, M.UI.HitSegments, M.UI.HitShards, M.UI.HitRing, M.UI.HitTweens = nil, nil, nil, nil, nil
    end
})

-- параметры эффекта из настроек
function M.F.HitFxParams(killed)
    local S = M.State
    local size = math.clamp(M.Math.Finite(S.HitFxSize, 1), 0.3, 4)
    local power = math.clamp(M.Math.Finite(S.HitFxPower, 1), 0.1, 3)
    local shards = math.clamp(math.floor((killed and 10 or 5) * power + 0.5), 0, M.Data.HitShardMax)
    return size, power, shards, killed and S.HitFxKillColor or S.HitFxColor
end

function M.F.ShowHitMarker(killed, point)
    if M.Draw.Enabled() then
        if M.Draw.Blocked() then return end
        if M.F.HitDrawShow(killed, point) then return end
    end
    M.F.HitGuiBuild()
    if not M.UI.HitSegments then return end
    local size, power, count, color = M.F.HitFxParams(killed)
    local T = M.Services.T
    local tweens = M.UI.HitTweens
    for i = #tweens, 1, -1 do pcall(function() tweens[i]:Cancel() end); tweens[i] = nil end
    local duration = (killed and 0.55 or 0.32) * (0.8 + 0.2 * power)
    local a0 = math.clamp(1 - (0.5 + 0.35 * power), 0, 0.9)
    local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local function play(inst, goal)
        local tw = T:Create(inst, info, goal)
        tweens[#tweens + 1] = tw
        tw:Play()
    end

    -- чёрточки крестиком
    local start = (killed and 11 or 8) * size
    local travel = 7 * size * (0.7 + 0.3 * power)
    for _, seg in ipairs(M.UI.HitSegments) do
        local f = seg.Frame
        f.Size = UDim2.fromOffset(9 * size, math.max(1.5, 1.6 * size))
        f.BackgroundColor3 = color
        f.BackgroundTransparency = a0
        f.Position = UDim2.fromOffset(point.X + seg.DirX * start, point.Y + seg.DirY * start)
        play(f, {BackgroundTransparency = 1, Position = UDim2.fromOffset(point.X + seg.DirX * (start + travel), point.Y + seg.DirY * (start + travel))})
    end

    -- осколки
    local turn = math.random() * math.pi * 2
    for i, f in ipairs(M.UI.HitShards) do
        if i <= count then
            local ang = turn + (i - 1) / count * math.pi * 2 + (math.random() - 0.5) * 0.25
            local dx, dy = math.cos(ang), math.sin(ang)
            local r0 = 12 * size
            local r1 = r0 + (14 + 16 * power) * size * (0.6 + math.random() * 0.8)
            f.Size = UDim2.fromOffset((5 + 4 * power) * size, math.max(1, 1.6 * size))
            f.Rotation = math.deg(ang)
            f.BackgroundColor3 = color
            f.BackgroundTransparency = a0
            f.Position = UDim2.fromOffset(point.X + dx * r0, point.Y + dy * r0)
            play(f, {BackgroundTransparency = 1, Position = UDim2.fromOffset(point.X + dx * r1, point.Y + dy * r1)})
        else
            f.BackgroundTransparency = 1
        end
    end

    -- кольцо-вспышка
    local ring = M.UI.HitRing
    if power >= 0.15 then
        local d0, d1 = 8 * size, (30 + 18 * power) * size * (killed and 1.25 or 1)
        ring.Frame.Position = UDim2.fromOffset(point.X, point.Y)
        ring.Frame.Size = UDim2.fromOffset(d0, d0)
        ring.Stroke.Color = color
        ring.Stroke.Thickness = math.max(1, 1.5 * size)
        ring.Stroke.Transparency = math.clamp(a0 + 0.1, 0, 0.95)
        play(ring.Frame, {Size = UDim2.fromOffset(d1, d1)})
        play(ring.Stroke, {Transparency = 1})
    else
        ring.Stroke.Transparency = 1
    end
end

-- наблюдение за игроком
function M.F.SpectateCandidates()
    local list = {}
    for _, plr in ipairs(M.Services.P:GetPlayers()) do
        local ch = plr ~= M.LP and M.F.CharOf(plr)
        if ch and (M.GetHumanoid(ch) or M.GetRoot(ch)) then
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
    if not M.State.SpectateOn and not M.Data.Spectating then return end
    if M.UI.SpecBar then M.UI.SpecBar.Panel.Root.Visible = M.State.SpectateOn end
    local cam = workspace.CurrentCamera
    if not cam then return end
    if M.State.SpectateOn then
        local function subjectOf(plr)
            local ch = plr and M.F.CharOf(plr)
            return ch and (M.GetHumanoid(ch) or M.GetRoot(ch)) or nil
        end
        local target = M.Data.SpectateTarget
        local hum = subjectOf(target)
        if not hum then
            M.F.SpectateStep(1)
            target = M.Data.SpectateTarget
            hum = subjectOf(target)
        end
        if hum then
            M.Data.Spectating = true
            if cam.CameraSubject ~= hum then cam.CameraSubject = hum end
        end
    elseif M.Data.Spectating then
        M.Data.Spectating = false
        local char = M.LP.Character
        local own = char and M.GetHumanoid(char)
        if own then cam.CameraSubject = own end
        M.Data.SpectateTarget = nil
        M.F.RenderSpectateLabel()
    end
end

end}

-- [44/69] Круги от ног цели при попадании
MODULES[#MODULES + 1] = {"44. Круги от ног при попадании", function(M, __X)
-- ==============================================================================
-- [ КРУГИ ОТ НОГ ПРИ ПОПАДАНИИ ]
-- ==============================================================================
do
local HR = {Step = M.Services.H:GenerateGUID(false)}
local LIFE = 0.8     -- сколько живёт каждый круг
local GAP = 0.13     -- задержка между кругами
local RINGS = 3
local MAX_FX = 4     -- одновременно живых эффектов

-- один круг: неоновый диск (мягкая заливка) и кольцо на невидимой плоской детали, которое светится яркостью SurfaceGui
local function newRing(folder)
    local function part()
        local p = Instance.new("Part")
        p.Name = M.Services.H:GenerateGUID(false)
        p.Anchored = true
        p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
        p.Transparency = 1
        return p
    end
    local disc = part()
    disc.Shape = Enum.PartType.Cylinder
    disc.Material = Enum.Material.Neon
    disc.Size = Vector3.new(0.05, 1, 1)
    disc.Parent = folder
    local carrier = part()
    carrier.Material = Enum.Material.Neon
    carrier.Size = Vector3.new(1, 0.05, 1)
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Top
    pcall(function() gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize end)
    gui.CanvasSize = Vector2.new(256, 256)
    gui.LightInfluence = 0
    gui.Parent = carrier
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Thickness = 12
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Transparency = 1
    carrier.Parent = folder
    return {Disc = disc, Carrier = carrier, Gui = gui, Stroke = stroke, Hidden = true}
end

local function hideRing(r)
    if r.Hidden then return end
    r.Hidden = true
    r.Disc.Transparency = 1
    r.Stroke.Transparency = 1
    r.D, r.DT, r.ST = nil, nil, nil
end

local function newFx(folder)
    local fx = {Rings = {}, Live = false}
    for i = 1, RINGS do fx.Rings[i] = newRing(folder) end
    return fx
end

local function releaseFx(fx)
    fx.Live = false
    for _, r in ipairs(fx.Rings) do hideRing(r) end
end

-- запуск эффекта: killed - убийство, круги крупнее
function M.F.HitRings(char, killed)
    local state = M.Data.HitRingState
    if not state or M.Run.IsShutDown or M.Data.Gov.Level >= 3 then return end
    local root = M.GetRoot(char)
    if not root then return end
    local now = os.clock()
    -- очередь выстрелов не множит эффекты: не чаще 16 раз в секунду
    if now - state.LastAt < 0.06 then return end
    state.LastAt = now
    local S = M.State
    local hum = M.GetHumanoid(char)
    local down = (hum and hum.HipHeight or 2) + root.Size.Y * 0.5
    local ok, hit = pcall(M.F.RaycastMapRaw, root.Position, Vector3.new(0, -(down + 4), 0))
    local pos = (ok and hit) and hit.Position or (root.Position - Vector3.new(0, down, 0))
    pos = pos + Vector3.new(0, 0.07, 0)

    local fx
    for _, cand in ipairs(state.Pool) do
        if not cand.Live then fx = cand break end
    end
    if not fx then
        if #state.Pool < MAX_FX then
            fx = newFx(M.F.Folder("hrFolder"))
            state.Pool[#state.Pool + 1] = fx
        else
            -- все заняты: забирается самый старый
            for _, cand in ipairs(state.Pool) do
                if not fx or cand.Born < fx.Born then fx = cand end
            end
            releaseFx(fx)
        end
    end
    local speed = math.clamp(M.Math.Finite(S.HitRingSpeed, 14), 4, 40)
    local glow = math.clamp(M.Math.Finite(S.HitRingGlow, 0.7), 0.1, 1)
    fx.Live, fx.Born = true, now
    fx.MaxR = speed * LIFE * 0.5 * (killed and 1.35 or 1)
    fx.Col, fx.Glow = S.HitRingColor, glow
    fx.Pos = pos
    local flat = CFrame.new(pos)
    local up = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
    for _, r in ipairs(fx.Rings) do
        r.Disc.CFrame, r.Carrier.CFrame = up, flat
        r.Disc.Color = fx.Col
        r.Stroke.Color = fx.Col
        pcall(function() r.Gui.Brightness = 1 + 4 * glow end)
    end
end

local function stepFx(fx, now)
    local age0 = now - fx.Born
    local alive = false
    local glow = fx.Glow
    for i, r in ipairs(fx.Rings) do
        local age = age0 - (i - 1) * GAP
        if age < 0 then
            alive = true
        elseif age >= LIFE then
            hideRing(r)
        else
            alive = true
            local p = age / LIFE
            local d = (0.5 + fx.MaxR * (1 - (1 - p) ^ 2)) * 2
            d = math.floor(d * 20 + 0.5) / 20
            if r.D ~= d then
                r.D = d
                r.Disc.Size = Vector3.new(0.05, d, d)
                r.Carrier.Size = Vector3.new(d, 0.05, d)
            end
            local fade = (1 - p) ^ 1.3
            local dt = math.floor((1 - 0.3 * glow * fade) * 40 + 0.5) / 40
            local st = math.floor((1 - glow * fade) * 40 + 0.5) / 40
            if r.DT ~= dt then r.DT = dt; r.Disc.Transparency = dt end
            if r.ST ~= st then r.ST = st; r.Stroke.Transparency = st end
            r.Hidden = false
        end
    end
    if not alive then fx.Live = false end
end

M.F.DefineModule("HitRings", {
    Wanted = function() return M.State.HitRingsOn end,
    Load = function()
        M.Data.HitRingState = {Pool = {}, LastAt = -10}
        pcall(function() M.Services.R:UnbindFromRenderStep(HR.Step) end)
        local acc = 0
        M.Services.R:BindToRenderStep(HR.Step, Enum.RenderPriority.Last.Value + 6, function(dt)
            if M.Run.IsShutDown then return end
            local state = M.Data.HitRingState
            if not state then return end
            -- не чаще 90 раз в секунду
            acc = acc + (dt or 0)
            if acc < 1 / 90 then return end
            acc = 0
            local now = os.clock()
            for _, fx in ipairs(state.Pool) do
                if fx.Live then M.F.Safe("HitRings", stepFx, fx, now) end
            end
        end)
    end,
    Unload = function()
        pcall(function() M.Services.R:UnbindFromRenderStep(HR.Step) end)
        local state = M.Data.HitRingState
        M.Data.HitRingState = nil
        if state then
            for _, fx in ipairs(state.Pool) do
                for _, r in ipairs(fx.Rings) do
                    pcall(function() r.Disc:Destroy() end)
                    pcall(function() r.Carrier:Destroy() end)
                end
            end
        end
    end
})
end

end}

-- [45/69] Свободная камера
MODULES[#MODULES + 1] = {"45. Свободная камера", function(M, __X)
local getService = __X.getService
-- ==============================================================================
-- [ СВОБОДНАЯ КАМЕРА ]
-- ==============================================================================
function M.F.SetFreecam(on)
    if on then M.F.StartFreecam() else M.F.StopFreecam() end
end

function M.F.StartFreecam()
    local D, S = M.Data, M.State
    if D.Fc or M.Run.IsShutDown then return end
    local cam = workspace.CurrentCamera
    if not cam then
        M.F.SetStateVisual("FreecamOn", false)
        return
    end
    -- наблюдение занимает ту же камеру
    if S.SpectateOn or D.Spectating then
        M.F.SetStateVisual("SpectateOn", false)
        pcall(M.F.UpdateSpectate)
    end
    local U = M.Services.U
    local cf = cam.CFrame
    local pitch, yaw = cf:ToOrientation()
    -- cams
    local fc = {
        Cam = cam, Pos = cf.Position, Pitch = pitch, Yaw = yaw, Vel = Vector3.zero, Rmb = false, Locking = false,
        Cams = {[cam] = {Type = cam.CameraType, Subject = cam.CameraSubject, CF = cf, Focus = cam.Focus}},
        Action = M.Services.H:GenerateGUID(false), Conns = {},
    }
    D.Fc = fc
    -- всё, что целилось этой камерой, отпускаем
    D.AimLock, D.AimLead, D.AimWritten, D.AimStepWrote = nil, nil, nil, false
    pcall(M.F.TriggerRelease)

    pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)

    fc.Step = M.Services.H:GenerateGUID(false)
    pcall(function()
        M.Services.R:BindToRenderStep(fc.Step, Enum.RenderPriority.Last.Value - 1, function()
            local cur, want = workspace.CurrentCamera, fc.Written
            if not want or cur ~= fc.Cam then return end
            if cur.CameraType ~= Enum.CameraType.Scriptable then cur.CameraType = Enum.CameraType.Scriptable end
            local now = cur.CFrame
            if (now.Position - want.Position).Magnitude > 0.01 or now.LookVector:Dot(want.LookVector) < 0.99999 then cur.CFrame = want end
        end)
    end)

    pcall(function()
        local KC = Enum.KeyCode
        getService("ContextActionService"):BindActionAtPriority(fc.Action, function() return Enum.ContextActionResult.Sink end,
            false, Enum.ContextActionPriority.High.Value, KC.W, KC.A, KC.S, KC.D, KC.Space, KC.Up, KC.Down, KC.Left, KC.Right)
    end)

    local function hold(conn) fc.Conns[#fc.Conns + 1] = M.Track(conn) end
    hold(U.InputBegan:Connect(function(inp, proc)
        if inp.UserInputType == Enum.UserInputType.MouseButton2 then
            fc.Rmb = (not proc) and not M.F.PointerOverMenu()
        end
    end))
    hold(U.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton2 then fc.Rmb = false end
    end))
    hold(U.InputChanged:Connect(function(inp, proc)
        if proc or inp.UserInputType ~= Enum.UserInputType.MouseWheel then return end
        local z = inp.Position.Z
        if z ~= z or z == 0 then return end
        M.F.SetStateVisual("FreecamSpeed", math.clamp(M.Math.Finite(S.FreecamSpeed, 40) * (1.18 ^ (z > 0 and 1 or -1)), 2, 500))
    end))

    -- свой персонаж виден со стороны
    pcall(function()
        local char = M.LP and M.LP.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.LocalTransparencyModifier > 0.5 then part.LocalTransparencyModifier = 0 end
        end
    end)
end

function M.F.StopFreecam()
    local D = M.Data
    local fc = D.Fc
    if not fc then return end
    D.Fc = nil
    if fc.Step then pcall(function() M.Services.R:UnbindFromRenderStep(fc.Step) end) end
    for _, conn in ipairs(fc.Conns) do pcall(M.F.Untrack, conn) end
    pcall(function() getService("ContextActionService"):UnbindAction(fc.Action) end)
    local U = M.Services.U
    if fc.Locking then
        local before = fc.Before
        if before == nil or before == Enum.MouseBehavior.LockCurrentPosition then before = Enum.MouseBehavior.Default end
        pcall(function() U.MouseBehavior = before end)
    end
    local _, hum = M.GetSelf()
    for cam, saved in pairs(fc.Cams) do
        pcall(function()
            local subject = (hum and hum.Parent) and hum or ((saved.Subject and saved.Subject.Parent) and saved.Subject or nil)
            if subject then cam.CameraSubject = subject end
            cam.CameraType = saved.Type
            cam.CFrame = saved.CF
            cam.Focus = saved.Focus
        end)
    end
    -- выключили не тумблером
    if M.State.FreecamOn then M.F.SetStateVisual("FreecamOn", false) end
end

-- один шаг свободной камеры
function M.F.UpdateFreecam(cam, dt)
    local D, S = M.Data, M.State
    local fc = D.Fc
    if not fc then return end
    local U = M.Services.U
    dt = math.clamp(dt, 0, 0.1)

    if fc.Cam ~= cam then
        fc.Cam = cam
        if not fc.Cams[cam] then
            fc.Cams[cam] = {Type = (cam.CameraType == Enum.CameraType.Scriptable) and Enum.CameraType.Custom or cam.CameraType,
                Subject = cam.CameraSubject, CF = cam.CFrame, Focus = cam.Focus}
        end
    end
    if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end

    local KC = Enum.KeyCode
    local typing = U:GetFocusedTextBox() ~= nil

    -- поворот
    local rmbLook = (not typing) and fc.Rmb and U:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    if rmbLook then
        if U.MouseBehavior ~= Enum.MouseBehavior.LockCurrentPosition then
            if not fc.Locking then fc.Locking, fc.Before = true, U.MouseBehavior end
            U.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        end
    elseif fc.Locking then
        fc.Locking = false
        local before = fc.Before
        fc.Before = nil
        if before == nil or before == Enum.MouseBehavior.LockCurrentPosition then before = Enum.MouseBehavior.Default end
        U.MouseBehavior = before
    end
    if (not typing) and (rmbLook or U.MouseBehavior == Enum.MouseBehavior.LockCenter) then
        local delta = U:GetMouseDelta()
        local k = 0.0035 * math.clamp(M.Math.Finite(S.FreecamSens, 1), 0.1, 5)
        if delta.X == delta.X and delta.Y == delta.Y then
            fc.Yaw = (fc.Yaw - delta.X * k) % (math.pi * 2)
            fc.Pitch = math.clamp(fc.Pitch - delta.Y * k, -1.5, 1.5)
        end
    end

    -- движение
    local rot = CFrame.fromOrientation(fc.Pitch, fc.Yaw, 0)
    local move = Vector3.zero
    if not typing then
        local x = (U:IsKeyDown(KC.D) and 1 or 0) - (U:IsKeyDown(KC.A) and 1 or 0)
        local z = (U:IsKeyDown(KC.W) and 1 or 0) - (U:IsKeyDown(KC.S) and 1 or 0)
        local y = ((U:IsKeyDown(KC.E) or U:IsKeyDown(KC.Space)) and 1 or 0) - (U:IsKeyDown(KC.Q) and 1 or 0)
        move = rot.LookVector * z + rot.RightVector * x + Vector3.new(0, y, 0)
        if move.Magnitude > 1 then move = move.Unit end
    end
    local speed = math.clamp(M.Math.Finite(S.FreecamSpeed, 40), 1, 1000)
    if not typing then
        if U:IsKeyDown(KC.LeftShift) or U:IsKeyDown(KC.RightShift) then speed = speed * 4 end
        if U:IsKeyDown(KC.LeftControl) or U:IsKeyDown(KC.RightControl) then speed = speed * 0.25 end
    end
    local smooth = math.clamp(M.Math.Finite(S.FreecamSmooth, 0.4), 0, 1)
    local rate = 3 + (1 - smooth) * (1 - smooth) * 40
    fc.Vel = fc.Vel + (move * speed - fc.Vel) * (1 - math.exp(-rate * dt))
    local pos = fc.Pos + fc.Vel * dt
    if not M.F.FiniteVec(pos) then pos, fc.Vel = fc.Pos, Vector3.zero end
    fc.Pos = pos

    local cf = CFrame.new(pos) * rot
    cam.CFrame = cf
    cam.Focus = cf * CFrame.new(0, 0, -16)
    fc.Written = cf
end

-- время как в реальности
function M.F.SyncRealTime()
    local now = os.date("*t", os.time())
    M.State.CustomTime = now.hour + now.min / 60 + now.sec / 3600
    local shown = math.floor(M.State.CustomTime * 100) / 100
    for _, el in ipairs(M.F.VisualEntries("CustomTime")) do el.SetVisual(shown) end
end

end}

-- [46/69] Стрелки за краем экрана: общее, цвета, подписи
MODULES[#MODULES + 1] = {"46. Стрелки за краем экрана: общее, цвета, подписи", function(M, __X)
-- ==============================================================================
-- [ СТРЕЛКИ ЗА КРАЕМ ЭКРАНА ]
-- ==============================================================================
local AR = {
    TwoPi = math.pi * 2,
    RimMin = 1.5,
    RimK = 0.08,
    GuiRim = 0.11,
    Span = 3.0,
    Cand = {},
    Shapes = {
        Dart = {Kind = "poly", Pts = {{0, -0.95}, {0.80, 0.90}, {0, 0.42}, {-0.80, 0.90}}, Rays = 5, RayT = 0.17},
        Chevron = {Kind = "arms", Tip = {0, -0.66}, End = {0.90, 0.66}, Thick = 0.24},
    },
    NearCol = Color3.fromRGB(255, 72, 72), MidCol = Color3.fromRGB(255, 196, 64), FarCol = Color3.fromRGB(84, 214, 148),
    Dark = Color3.fromRGB(8, 10, 16), White = Color3.new(1, 1, 1), Soft = Color3.fromRGB(196, 204, 218),
    PlateR = 1.32,
    Sx = {}, Sy = {},
}

function AR.lineKeys(name) return {name .. "f", name .. "t", name .. "c", name .. "w", name .. "a", name .. "v"} end
function AR.circKeys(name) return {name .. "p", name .. "r", name .. "c", name .. "a", name .. "v"} end
-- незалитый круг (кольцо) ещё помнит толщину линии
function AR.ringKeys(name) return {name .. "p", name .. "r", name .. "c", name .. "a", name .. "v", name .. "w"} end
AR.K = {
    RimA = AR.lineKeys("ra"), RimB = AR.lineKeys("rb"), FillA = AR.lineKeys("fa"), FillB = AR.lineKeys("fb"),
    RimC = {AR.circKeys("rc1"), AR.circKeys("rc2"), AR.circKeys("rc3")},
    FillC = {AR.circKeys("fc1"), AR.circKeys("fc2"), AR.circKeys("fc3")},
    GlowO = AR.circKeys("go"), GlowI = AR.circKeys("gi"),  -- мягкое свечение: внешний и внутренний круг
    Plate = AR.circKeys("pl"), Ring = AR.ringKeys("rg"),
    Pulse = AR.ringKeys("pu"), CntBg = AR.circKeys("cb"),
    Col = {}, Edge = {}, Joint = {},
}
AR.K.HpBg, AR.K.HpFill = AR.lineKeys("hb"), AR.lineKeys("hf")  -- полоска здоровья: фон и заливка
AR.K.HpCap = {AR.circKeys("h1"), AR.circKeys("h2")}  -- круглые концы подложки полоски
for i = 1, 16 do AR.K.Col[i] = AR.lineKeys("c" .. i) end
for i = 1, 4 do
    AR.K.Edge[i] = AR.lineKeys("e" .. i)
    AR.K.Joint[i] = AR.circKeys("j" .. i)
end

-- лучи веера заливки Dart
function AR.fan(sh)
    if sh.Fan then return sh.Fan end
    local p = sh.Pts
    local tip, wing, notch = p[1], p[2], p[3]
    local list = {}
    local n = sh.Rays
    for k = 0, n - 1 do
        local f = k / n
        local qx, qy = wing[1] + (notch[1] - wing[1]) * f, wing[2] + (notch[2] - wing[2]) * f
        local t = k / math.max(n - 1, 1)
        list[#list + 1] = {qx, qy, 1, k == 0, t, false, f}
        list[#list + 1] = {-qx, qy, -1, k == 0, t, false, f}
    end
    list[#list + 1] = {notch[1], notch[2], 1, false, 1, true, 1}
    local ex, ey = wing[1] - tip[1], wing[2] - tip[2]
    local len = math.sqrt(ex * ex + ey * ey)
    local bx, by = notch[1] - wing[1], notch[2] - wing[2]
    local blen = math.sqrt(bx * bx + by * by)
    local nx, ny = by / blen, -bx / blen
    local mx, my = (wing[1] + notch[1]) / 2, (wing[2] + notch[2]) / 2
    local cx, cy = (tip[1] + wing[1] + notch[1] + -wing[1]) / 4, (tip[2] + wing[2] + notch[2] + wing[2]) / 4
    if (mx - cx) * nx + (my - cy) * ny < 0 then nx, ny = -nx, -ny end
    sh.BackNX, sh.BackNY = nx, ny
    sh.TipTan = math.abs(ex) / math.abs(ey)
    sh.TipCos = math.abs(ey) / len
    sh.EdgeInX, sh.EdgeInY = -ey / len, ex / len
    if sh.EdgeInX > 0 then sh.EdgeInX, sh.EdgeInY = -sh.EdgeInX, -sh.EdgeInY end  -- внутрь = к оси (x меньше)
    sh.Fan = list
    return list
end
-- конец луча, укороченный так, чтобы срезанный угол линии
function AR.rayEnd(sh, side, sx0, sy0, qx, qy, t, rimHalf, wingPt)
    local dx, dy = qx - sx0, qy - sy0
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1e-6 then return qx, qy end
    dx, dy = dx / len, dy / len
    local nx, ny = sh.BackNX * side, sh.BackNY
    local dn = dx * nx + dy * ny
    if dn < 0.05 then return qx, qy end
    local corner = (t * 0.5) * math.abs(-dy * nx + dx * ny)
    local wing = wingPt or sh.Pts[2]
    local out0 = (qx - wing[1] * side) * nx + (qy - wing[2]) * ny
    local cut = (math.max(out0, 0) + corner - rimHalf) / dn
    if cut <= 0 then return qx, qy end
    cut = math.min(cut, len * 0.5)
    return qx - dx * cut, qy - dy * cut
end

-- вершины контура, сдвинутые внутрь на d (в долях unit)
function AR.insetPts(sh, d)
    local p = sh.Pts
    local n = #p
    local buf = sh.InsetBuf
    if not buf then
        buf = {}
        for i = 1, n do buf[i] = {0, 0} end
        sh.InsetBuf = buf
        -- нормаль каждой стороны внутрь фигуры
        local area = 0
        for i = 1, n do
            local a, b = p[i], p[i % n + 1]
            area = area + a[1] * b[2] - b[1] * a[2]
        end
        local s = area > 0 and 1 or -1
        sh.EdgeN = {}
        for i = 1, n do
            local a, b = p[i], p[i % n + 1]
            local ex, ey = b[1] - a[1], b[2] - a[2]
            local len = math.sqrt(ex * ex + ey * ey)
            sh.EdgeN[i] = {-ey / len * s, ex / len * s, ex, ey}
        end
    end
    if sh.InsetD == d then return buf end
    sh.InsetD = d
    local en = sh.EdgeN
    for i = 1, n do
        local j = (i - 2) % n + 1
        local e0, e1 = en[j], en[i]
        local ax, ay = p[j][1] + e0[1] * d, p[j][2] + e0[2] * d
        local bx, by = p[i][1] + e1[1] * d, p[i][2] + e1[2] * d
        local den = e0[3] * e1[4] - e0[4] * e1[3]
        local s = ((bx - ax) * e1[4] - (by - ay) * e1[3]) / den
        buf[i][1], buf[i][2] = ax + e0[3] * s, ay + e0[4] * s
    end
    return buf
end

-- лучи заливки Dart толщиной t внутри контура, сдвинутого на d: углы толстой линии не выходят наружу
function AR.fanRays(sh, t, d)
    local fan = AR.fan(sh)
    local out = sh.RayBuf
    if not out then out = {}; sh.RayBuf = out end
    if sh.RayT_ == t and sh.RayD_ == d then return out end
    sh.RayT_, sh.RayD_ = t, d
    local ins = AR.insetPts(sh, d)
    local tip, wing, notch = ins[1], ins[2], ins[3]
    local h = t * 0.5
    local startY = tip[2] + h / sh.TipTan
    for i = 1, #fan do
        local r = fan[i]
        local f, side = r[7], r[3]
        local qx = (wing[1] + (notch[1] - wing[1]) * f) * side
        local qy = wing[2] + (notch[2] - wing[2]) * f
        local sx0, sy0 = tip[1], startY
        if r[4] then
            local nx, ny = sh.EdgeInX * h * side, sh.EdgeInY * h
            qx, qy, sx0, sy0 = qx + nx, qy + ny, sx0 + nx, sy0 + ny
        end
        qx, qy = AR.rayEnd(sh, side, sx0, sy0, qx, qy, t, 0, wing)
        local e = out[i]
        if not e then e = {}; out[i] = e end
        -- у очень маленькой стрелки луч может не поместиться: тогда он не рисуется
        e[1], e[2], e[3], e[4], e[5] = sx0, sy0, qx, qy, qy - sy0 > h
    end
    return out
end

-- название формы
function AR.styleName(style)
    if AR.Shapes[style] then return style end
    return "Dart"
end

-- кратчайшая разность углов b - a в пределах [-pi, pi)

function AR.angDiff(a, b) return (b - a + math.pi) % AR.TwoPi - math.pi end
function AR.wrap(a) return (a + math.pi) % AR.TwoPi - math.pi end
-- порядок при равных значениях задаёт Uid
function AR.byScore(a, b)
    if a.Score ~= b.Score then return a.Score < b.Score end
    return a.Uid < b.Uid
end
function AR.byAngle(a, b)
    if a.Ang ~= b.Ang then return a.Ang < b.Ang end
    return a.Uid < b.Uid
end

function AR.newState(player)
    AR.Seq = (AR.Seq or 0) + 1
    return {Player = player, Uid = AR.Seq, Alpha = 0, Want = false, Dist = 0, Hp = 1, NameStr = "", DistStr = "", InfoStr = "",
        Off = 0, H = 0, Count = 1, Threat = 0, ThrS = 0, ThreatT = 0, LosK = 1}
end

-- цвет стрелки по выбранному способу
function AR.color(st, S)
    local mode = S.ArrowColorMode
    if mode == "Team" then
        local plr = st.Player
        if plr and plr.Team then return plr.TeamColor.Color end
    elseif mode == "ByHealth" then
        return M.Math.HealthColor(st.Hp or 1)
    elseif mode == "ByDistance" then
        -- 21 готовый оттенок вместо нового цвета в каждом кадре
        local step = math.floor(math.clamp((st.Dist or 0) / 400, 0, 1) * 20 + 0.5)
        local cached = AR.DistCols[step]
        if cached then return cached end
        local t = step / 20
        local col
        if t < 0.5 then col = AR.NearCol:Lerp(AR.MidCol, t * 2) else col = AR.MidCol:Lerp(AR.FarCol, (t - 0.5) * 2) end
        AR.DistCols[step] = col
        return col
    end
    return S.ArrowCol
end

AR.DistCols = {}

-- итоговый цвет стрелки: пересчитывается, только когда меняются цвет, ступень дальности или угроза
function AR.finalColor(st, S, dist, threat)
    local base = AR.color(st, S)
    local k = math.floor(math.clamp(dist / 450, 0, 1) * 5 + 0.5)
    local tq = threat > 0.05 and math.floor(threat * 10 + 0.5) or 0
    if st.FcCol and st.FcBase == base and st.FcK == k and st.FcT == tq then return st.FcCol end
    local col = AR.shade(AR.neon(base), dist)
    if tq > 0 then col = col:Lerp(AR.White, 0.04 * tq) end
    st.FcBase, st.FcK, st.FcT, st.FcCol = base, k, tq, col
    return col
end

-- далёкая цель темнее
function AR.shade(col, dist)
    local k = math.floor(math.clamp(dist / 450, 0, 1) * 5 + 0.5) / 10  -- 0 .. 0.5
    if k <= 0 then return col end
    return col:Lerp(AR.Dark, k * 0.6)
end

-- неоновый цвет заливки
function AR.neon(col)
    local h, s = col:ToHSV()
    return Color3.fromHSV(h, math.clamp(s ^ 0.7 + 0.12, 0, 1), 1)
end

-- оттенки по цвету стрелки
function AR.tones(st, col)
    if st.ToneBase ~= col then
        st.ToneBase = col
        st.RimCol = col:Lerp(AR.Dark, 0.78)
        st.LightCol = col:Lerp(Color3.new(1, 1, 1), 0.5)
        st.DarkCol = col
        st.RingCol = col:Lerp(AR.White, 0.2)
        st.PlateCol = col:Lerp(AR.Dark, 0.88)
    end
end

-- цвет каждого луча заливки Dart
function AR.rayColors(st, fan, col)
    if st.RayBase == col and st.RayN == #fan then return st.RayCols end
    st.RayBase, st.RayN = col, #fan
    local cols = st.RayCols
    if not cols then cols = {}; st.RayCols = cols end
    for i = 1, #fan do
        local r = fan[i]
        local t = r[5]
        if r[6] then
            cols[i] = col:Lerp(AR.White, 0.62)
        elseif r[3] > 0 then
            cols[i] = col:Lerp(AR.White, 0.05 + 0.27 * t)
        else
            cols[i] = col:Lerp(AR.Dark, 0.30 * (1 - t))
        end
    end
    return cols
end

-- прозрачность округляется до 1/40
function AR.q(x) return math.floor(x * 40 + 0.5) / 40 end

-- строка под стрелкой
function AR.info(st, S)
    local showDist, showAng = S.ArrowDistance and true or false, S.ArrowAngle and true or false
    local ang = showAng and math.floor(math.deg(st.Off or 0) + 0.5) or 0
    local h = st.H or 0
    if st.IDist == st.LastDist and st.IAng == ang and st.IH == h and st.IShowDist == showDist
        and st.IShowAng == showAng and st.InfoStr then return end
    st.IDist, st.IAng, st.IH, st.IShowDist, st.IShowAng = st.LastDist, ang, h, showDist, showAng
    local parts = {}
    if showDist and st.DistStr ~= "" then parts[#parts + 1] = st.DistStr end
    if h ~= 0 then parts[#parts + 1] = (h > 0 and "+" or "") .. h end
    if showAng then parts[#parts + 1] = ang .. "°" end
    st.InfoStr = table.concat(parts, "  ")
end

-- цвет заливки полоски здоровья
function AR.hpColor(st, hp)
    if st.HpColKey ~= hp then
        st.HpColKey = hp
        st.HpCol = M.Math.HealthColor(hp)
    end
    return st.HpCol
end

-- прячется ли стрелка под окном меню
function AR.underMenu(rect, px, py, unit)
    local pad = unit * 1.4 + 40
    return px + pad > rect[1] and px - pad < rect[3] and py + pad > rect[2] and py - pad < rect[4]
end

function AR.buildDraw(style)
    local caps = M.Draw.Caps or {}
    local created = {}
    local ok = true
    local function new(kind)
        local obj = M.Draw.New(kind)
        if obj then created[#created + 1] = obj else ok = false end
        return obj
    end
    local sh = AR.Shapes[style]
    local o = {Dr = true, K = {}, All = created, Style = style, Shape = sh}
    local KS = AR.K
    local solid, hollow, vis, visK = {}, {}, {}, {}
    local function reg(obj, key) vis[#vis + 1] = obj; visK[#visK + 1] = key end
    -- порядок создания = порядок наложения
    o.GlowO, o.GlowI, o.Plate, o.Ring = new("Circle"), new("Circle"), new("Circle"), new("Circle")
    solid[#solid + 1] = o.GlowO; solid[#solid + 1] = o.GlowI; solid[#solid + 1] = o.Plate; hollow[#hollow + 1] = o.Ring
    reg(o.GlowO, KS.GlowO[5]); reg(o.GlowI, KS.GlowI[5]); reg(o.Plate, KS.Plate[5]); reg(o.Ring, KS.Ring[5])
    if sh.Kind == "poly" then
        o.Cols, o.Edges, o.Joints = {}, {}, {}
        for i = 1, #AR.fan(sh) do o.Cols[i] = new("Line"); reg(o.Cols[i], KS.Col[i][6]) end
        for i = 1, 4 do o.Edges[i] = new("Line"); reg(o.Edges[i], KS.Edge[i][6]) end
        for i = 1, 4 do
            o.Joints[i] = new("Circle"); solid[#solid + 1] = o.Joints[i]; reg(o.Joints[i], KS.Joint[i][5])
        end
    else
        o.RimA, o.RimB = new("Line"), new("Line")
        o.RimC = {new("Circle"), new("Circle"), new("Circle")}
        o.FillA, o.FillB = new("Line"), new("Line")
        o.FillC = {new("Circle"), new("Circle"), new("Circle")}
        reg(o.RimA, KS.RimA[6]); reg(o.RimB, KS.RimB[6]); reg(o.FillA, KS.FillA[6]); reg(o.FillB, KS.FillB[6])
        for i = 1, 3 do
            solid[#solid + 1] = o.RimC[i]; solid[#solid + 1] = o.FillC[i]
            reg(o.RimC[i], KS.RimC[i][5]); reg(o.FillC[i], KS.FillC[i][5])
        end
    end
    -- полоска здоровья
    o.HpBg, o.HpFill = new("Line"), new("Line")
    reg(o.HpBg, KS.HpBg[6]); reg(o.HpFill, KS.HpFill[6])
    if not ok then
        for _, obj in ipairs(created) do M.Draw.Remove(obj) end
        return nil
    end
    pcall(function()
        for _, c in ipairs(solid) do
            c.Filled = true
            if caps.CircleSides then c.NumSides = 32 end
        end
        for _, c in ipairs(hollow) do
            c.Filled = false
            if caps.CircleSides then c.NumSides = 48 end
        end
        if caps.ZIndex then
            o.GlowO.ZIndex, o.GlowI.ZIndex, o.Plate.ZIndex, o.Ring.ZIndex = 1, 1, 2, 3
            o.HpBg.ZIndex, o.HpFill.ZIndex = 6, 7
            if sh.Kind == "poly" then
                for i = 1, #o.Cols do o.Cols[i].ZIndex = 4 end
                for i = 1, 4 do o.Edges[i].ZIndex = 5; o.Joints[i].ZIndex = 5 end
            else
                o.RimA.ZIndex = 4; o.RimB.ZIndex = 4
                for i = 1, 3 do o.RimC[i].ZIndex = 4; o.FillC[i].ZIndex = 5 end
                o.FillA.ZIndex = 5; o.FillB.ZIndex = 5
            end
        end
    end)
    o.Vis, o.VisK = vis, visK
    return o
end

-- подписи стрелки
function AR.ensureTexts(o)
    if o.NameT then return end
    local caps = M.Draw.Caps or {}
    local nameT, distT = M.Draw.New("Text"), M.Draw.New("Text")
    if not (nameT and distT) then
        M.Draw.Remove(nameT); M.Draw.Remove(distT)
        o.NoTexts = true
        return
    end
    o.NameT, o.DistT = nameT, distT
    o.All[#o.All + 1] = nameT
    o.All[#o.All + 1] = distT
    o.Vis[#o.Vis + 1] = nameT; o.VisK[#o.VisK + 1] = "vn"
    o.Vis[#o.Vis + 1] = distT; o.VisK[#o.VisK + 1] = "vd"
    pcall(function()
        nameT.Color = Color3.new(1, 1, 1)
        distT.Color = AR.Soft  -- строка с дистанцией спокойнее имени
        for _, t in ipairs({nameT, distT}) do
            if caps.TextCenter then t.Center = true end
            if caps.TextOutline then t.Outline = true; t.OutlineColor = Color3.new(0, 0, 0) end
            if caps.TextFont then t.Font = 2 end
            if caps.ZIndex then t.ZIndex = 9 end
        end
    end)
end

__X.AR = AR
end}

-- [47/69] Стрелки: рисование поверх экрана, полоска здоровья
MODULES[#MODULES + 1] = {"47. Стрелки: рисование поверх экрана, полоска здоровья", function(M, __X)
local AR = __X.AR
local dset = __X.dset
local dvec = __X.dvec
-- расходящееся кольцо угрозы
function AR.makePulse(o)
    local caps = M.Draw.Caps or {}
    local c = M.Draw.New("Circle")
    if not c then o.NoPulse = true; return end
    o.Pulse = c
    o.All[#o.All + 1] = c
    o.Vis[#o.Vis + 1] = c; o.VisK[#o.VisK + 1] = AR.K.Pulse[5]
    pcall(function()
        c.Filled = false
        if caps.CircleSides then c.NumSides = 48 end
        if caps.ZIndex then c.ZIndex = 3 end
    end)
end

-- круглые концы подложки полоски здоровья (у тонкой заливки внутри они не видны): создаются, только когда полоска включена
function AR.makeHpCaps(o)
    local caps = M.Draw.Caps or {}
    local list = {}
    for i = 1, 2 do
        local c = M.Draw.New("Circle")
        if not c then
            for _, made in ipairs(list) do M.Draw.Remove(made) end
            o.NoHpCaps = true
            return
        end
        list[i] = c
    end
    o.HpCaps = list
    for i, c in ipairs(list) do
        o.All[#o.All + 1] = c
        o.Vis[#o.Vis + 1] = c; o.VisK[#o.VisK + 1] = AR.K.HpCap[i][5]
        pcall(function()
            c.Filled = true
            if caps.CircleSides then c.NumSides = 16 end
            if caps.ZIndex then c.ZIndex = 6 end
        end)
    end
end

-- кружок со счётчиком группы
function AR.makeBadge(o)
    local caps = M.Draw.Caps or {}
    local circle, text = M.Draw.New("Circle"), M.Draw.New("Text")
    if not (circle and text) then
        M.Draw.Remove(circle); M.Draw.Remove(text)
        o.NoBadge = true
        return
    end
    o.CntBg, o.CntT = circle, text
    o.All[#o.All + 1] = circle; o.All[#o.All + 1] = text
    o.Vis[#o.Vis + 1] = circle; o.VisK[#o.VisK + 1] = AR.K.CntBg[5]
    o.Vis[#o.Vis + 1] = text; o.VisK[#o.VisK + 1] = "vc"
    pcall(function()
        circle.Filled = true
        if caps.CircleSides then circle.NumSides = 32 end
        if caps.ZIndex then circle.ZIndex = 8 end
        text.Color = Color3.new(1, 1, 1)
        if caps.TextCenter then text.Center = true end
        if caps.TextOutline then text.Outline = true; text.OutlineColor = Color3.new(0, 0, 0) end
        if caps.TextFont then text.Font = 2 end
        if caps.ZIndex then text.ZIndex = 9 end
    end)
end
function AR.hideDraw(o)
    local K, vis, visK = o.K, o.Vis, o.VisK
    for i = 1, #vis do dset(vis[i], K, visK[i], "Visible", false) end
end

-- линия с толщиной (значения пишутся только при изменении)
function AR.dline(obj, K, ks, ax, ay, bx, by, thick, col, alpha, lineAlpha)
    dvec(obj, K, ks[1], "From", ax, ay)
    dvec(obj, K, ks[2], "To", bx, by)
    dset(obj, K, ks[3], "Color", col)
    dset(obj, K, ks[4], "Thickness", thick)
    if lineAlpha then dset(obj, K, ks[5], "Transparency", alpha) end
    dset(obj, K, ks[6], "Visible", true)
end

-- залитый круг (круглый конец луча, подложка, свечение)
function AR.dcirc(obj, K, ks, x, y, r, col, alpha, circAlpha)
    dvec(obj, K, ks[1], "Position", x, y)
    dset(obj, K, ks[2], "Radius", r)
    dset(obj, K, ks[3], "Color", col)
    if circAlpha then dset(obj, K, ks[4], "Transparency", alpha) end
    dset(obj, K, ks[5], "Visible", true)
end

-- кольцо: незалитый круг с толщиной линии
function AR.dring(obj, K, ks, x, y, r, thick, col, alpha, circAlpha)
    dvec(obj, K, ks[1], "Position", x, y)
    dset(obj, K, ks[2], "Radius", r)
    dset(obj, K, ks[3], "Color", col)
    dset(obj, K, ks[6], "Thickness", thick)
    if circAlpha then dset(obj, K, ks[4], "Transparency", alpha) end
    dset(obj, K, ks[5], "Visible", true)
end

-- блок подписей рядом со стрелкой, со стороны центра экрана
function AR.labelPlan(st, S, unit, ca, sa, px, py)
    local showName, showInfo, showBar = S.ArrowName, st.InfoStr ~= "", S.ArrowHealth
    local ts = math.clamp(math.floor(S.ArrowSize * 0.4 + 0.5), 11, 19)
    local ti = math.max(10, ts - 2)
    local lhN, lhI, lhB = ts + 2, ti + 2, 9
    local wName = showName and (utf8.len(st.NameStr) or #st.NameStr) * ts * 0.52 or 0
    local wInfo = showInfo and (utf8.len(st.InfoStr) or #st.InfoStr) * ti * 0.52 or 0
    local hw = showBar and math.clamp(math.floor(math.max(wName, wInfo, unit * 1.9) + 0.5), 30, 96) or 0
    local bw = math.max(wName, wInfo, hw)
    local hN, hB = showName and lhN or 0, showBar and lhB or 0
    local bh = hN + hB + (showInfo and lhI or 0)
    local off = unit * AR.PlateR + 7 + math.abs(ca) * bw * 0.5 + math.abs(sa) * bh * 0.5
    local y0 = py - sa * off - bh * 0.5
    return ts, ti, px - ca * off, y0, y0 + hN, y0 + hN + hB, wName, wInfo, hw
end

function AR.applyDraw(st, o, px, py, ang, unit, col, opacity, S, caps, ca, sa)
    local K = o.K
    local KS = AR.K
    local sh = o.Shape
    local theta = ang + math.pi / 2
    local ct, sn = math.cos(theta), math.sin(theta)
    AR.tones(st, col)
    local rimCol = st.RimCol
    local la, ca_ = caps.LineAlpha, caps.CircleAlpha
    local thr = st.Threat or 0
    local hx, hy = math.floor(px + 0.5), math.floor(py + 0.5)
    local lite = M.Data.Gov.Level >= 2
    local plateR = unit * AR.PlateR

    -- 1. Мягкое свечение
    local glowK = (S.ArrowGlow and 0.6 or 0) + 0.9 * thr
    if glowK > 0.02 and ca_ and not lite then
        AR.dcirc(o.GlowO, K, KS.GlowO, hx, hy, math.floor(unit * (2.0 + 0.55 * thr) + 0.5), col, AR.q(opacity * 0.07 * glowK), true)
        AR.dcirc(o.GlowI, K, KS.GlowI, hx, hy, math.floor(unit * (1.62 + 0.4 * thr) + 0.5), col, AR.q(opacity * 0.12 * glowK), true)
    else
        dset(o.GlowO, K, KS.GlowO[5], "Visible", false)
        dset(o.GlowI, K, KS.GlowI[5], "Visible", false)
    end

    -- 2. Подложка и кольцо
    if S.ArrowPlate then
        local rr = math.floor(plateR + 0.5)
        if ca_ then
            AR.dcirc(o.Plate, K, KS.Plate, hx, hy, rr, st.PlateCol, AR.q(opacity * 0.55), true)
        else
            dset(o.Plate, K, KS.Plate[5], "Visible", false)
        end
        AR.dring(o.Ring, K, KS.Ring, hx, hy, rr, math.max(1.2, math.floor(unit * 0.15 + 0.5) * 0.5), st.RingCol,
            AR.q(opacity * (0.55 + 0.4 * thr)), ca_)
    else
        dset(o.Plate, K, KS.Plate[5], "Visible", false)
        dset(o.Ring, K, KS.Ring[5], "Visible", false)
    end

    if sh.Kind == "poly" then
        -- заливка
        local fan = AR.fan(sh)
        local rc = AR.rayColors(st, fan, col)
        local tcol = math.max(1.5, math.floor(sh.RayT * unit * 2 + 0.5) * 0.5)
        local rimT = math.max(AR.RimMin, unit * AR.RimK)
        rimT = math.floor(rimT * 2 + 0.5) * 0.5
        -- заливка внутри контура, сдвинутого на половину обводки и полпикселя запаса на округление:
        -- край заливки всегда под обводкой и наружу не выходит
        local rays = AR.fanRays(sh, tcol / unit, (rimT * 0.5 + 0.5) / unit)
        for i = 1, #fan do
            local e = rays[i]
            if e[5] then
                local sx0, sy0, qx, qy = e[1], e[2], e[3], e[4]
                -- концы с шагом 0.5 px
                local ax = math.floor((px + (sx0 * ct - sy0 * sn) * unit) * 2 + 0.5) * 0.5
                local ay = math.floor((py + (sx0 * sn + sy0 * ct) * unit) * 2 + 0.5) * 0.5
                local bx = math.floor((px + (qx * ct - qy * sn) * unit) * 2 + 0.5) * 0.5
                local by = math.floor((py + (qx * sn + qy * ct) * unit) * 2 + 0.5) * 0.5
                AR.dline(o.Cols[i], K, KS.Col[i], ax, ay, bx, by, tcol, rc[i], opacity, la)
            else
                dset(o.Cols[i], K, KS.Col[i][6], "Visible", false)
            end
        end
        -- контур поверх заливки
        local sx, sy = AR.Sx, AR.Sy
        for i = 1, 4 do
            local lx, ly = sh.Pts[i][1], sh.Pts[i][2]
            sx[i] = math.floor((px + (lx * ct - ly * sn) * unit) * 2 + 0.5) * 0.5
            sy[i] = math.floor((py + (lx * sn + ly * ct) * unit) * 2 + 0.5) * 0.5
        end
        for i = 1, 4 do
            local j = i % 4 + 1
            AR.dline(o.Edges[i], K, KS.Edge[i], sx[i], sy[i], sx[j], sy[j], rimT, rimCol, opacity, la)
            AR.dcirc(o.Joints[i], K, KS.Joint[i], sx[i], sy[i], rimT * 0.5, rimCol, opacity, ca_)
        end
    else
        -- вершины
        local tx, ty = sh.Tip[1], sh.Tip[2]
        local ex, ey = sh.End[1], sh.End[2]
        local x0 = math.floor((px + (tx * ct - ty * sn) * unit) * 2 + 0.5) * 0.5
        local y0 = math.floor((py + (tx * sn + ty * ct) * unit) * 2 + 0.5) * 0.5
        local x1 = math.floor((px + (ex * ct - ey * sn) * unit) * 2 + 0.5) * 0.5
        local y1 = math.floor((py + (ex * sn + ey * ct) * unit) * 2 + 0.5) * 0.5
        local x2 = math.floor((px + (-ex * ct - ey * sn) * unit) * 2 + 0.5) * 0.5
        local y2 = math.floor((py + (-ex * sn + ey * ct) * unit) * 2 + 0.5) * 0.5
        local thick = math.max(2, math.floor(sh.Thick * unit * 2 + 0.5) * 0.5)
        local rimW = math.max(AR.RimMin, unit * AR.RimK)
        local rimThick = thick + math.floor(rimW * 4 + 0.5) * 0.5
        local capR = thick * 0.5
        local rimR = rimThick * 0.5
        AR.dline(o.RimA, K, KS.RimA, x0, y0, x1, y1, rimThick, rimCol, opacity, la)
        AR.dline(o.RimB, K, KS.RimB, x0, y0, x2, y2, rimThick, rimCol, opacity, la)
        AR.dcirc(o.RimC[1], K, KS.RimC[1], x0, y0, rimR, rimCol, opacity, ca_)
        AR.dcirc(o.RimC[2], K, KS.RimC[2], x1, y1, rimR, rimCol, opacity, ca_)
        AR.dcirc(o.RimC[3], K, KS.RimC[3], x2, y2, rimR, rimCol, opacity, ca_)
        -- заливка поверх контура
        AR.dline(o.FillA, K, KS.FillA, x0, y0, x1, y1, thick, col, opacity, la)
        AR.dline(o.FillB, K, KS.FillB, x0, y0, x2, y2, thick, col, opacity, la)
        AR.dcirc(o.FillC[1], K, KS.FillC[1], x0, y0, capR, col, opacity, ca_)
        AR.dcirc(o.FillC[2], K, KS.FillC[2], x1, y1, capR, col, opacity, ca_)
        AR.dcirc(o.FillC[3], K, KS.FillC[3], x2, y2, capR, col, opacity, ca_)
    end

    -- 3. Угроза
    if thr > 0.25 and ca_ and not lite and not o.NoPulse and not o.Pulse then AR.makePulse(o) end
    if thr > 0.25 and ca_ and not lite and o.Pulse then
        local ph = ((AR.Now or 0) * 0.85) % 1
        local fade = 1 - ph
        AR.dring(o.Pulse, K, KS.Pulse, hx, hy, math.floor(plateR * (1.05 + 0.75 * ph) + 0.5), 1.5, col,
            AR.q(opacity * 0.6 * thr * fade * fade), true)
    elseif o.Pulse then
        dset(o.Pulse, K, KS.Pulse[5], "Visible", false)
    end

    -- 4. Блок подписей
    local showName, showInfo, showBar = S.ArrowName, st.InfoStr ~= "", S.ArrowHealth
    local cnt = st.Count or 1
    if (showName or showInfo) and not o.NameT and not o.NoTexts then AR.ensureTexts(o) end
    if cnt > 1 and not o.CntBg and not o.NoBadge then AR.makeBadge(o) end
    local nameT, distT = o.NameT, o.DistT
    local ts, ti, bx, yName, yBar, yInfo, wName, wInfo, hw
    if showName or showInfo or showBar then
        ts, ti, bx, yName, yBar, yInfo, wName, wInfo, hw = AR.labelPlan(st, S, unit, ca, sa, px, py)
    end
    if showBar then
        local hp = math.floor(math.clamp(st.Hp or 1, 0, 1) * 20 + 0.5) / 20
        local x0 = math.floor(bx - hw * 0.5 + 0.5)
        local yc = math.floor(yBar + 4.5)
        if not o.HpCaps and not o.NoHpCaps and ca_ then AR.makeHpCaps(o) end
        local hc = o.HpCaps
        -- линия идёт между центрами круглых концов, поэтому общая длина полоски не меняется
        local x1 = x0 + hw
        AR.dline(o.HpBg, K, KS.HpBg, x0 + 2, yc, x1 - 2, yc, 6, AR.Dark, AR.q(opacity * 0.72), la)
        if hc then
            AR.dcirc(hc[1], K, KS.HpCap[1], x0 + 2, yc, 3, AR.Dark, AR.q(opacity * 0.72), ca_)
            AR.dcirc(hc[2], K, KS.HpCap[2], x1 - 2, yc, 3, AR.Dark, AR.q(opacity * 0.72), ca_)
        end
        if hp > 0.01 then
            local hcol = AR.hpColor(st, hp)
            local fx1 = math.max(math.floor(x0 + 2 + (hw - 4) * hp + 0.5), x0 + 2)
            AR.dline(o.HpFill, K, KS.HpFill, x0 + 2, yc, fx1, yc, 3, hcol, opacity, la)
        else
            dset(o.HpFill, K, KS.HpFill[6], "Visible", false)
        end
    else
        dset(o.HpBg, K, KS.HpBg[6], "Visible", false)
        dset(o.HpFill, K, KS.HpFill[6], "Visible", false)
        if o.HpCaps then
            for i = 1, 2 do dset(o.HpCaps[i], K, KS.HpCap[i][5], "Visible", false) end
        end
    end

    if nameT then
        if showName then
            dset(nameT, K, "nt", "Text", st.NameStr)
            dset(nameT, K, "ns", "Size", ts)
            local tx_ = math.floor(bx + 0.5)
            if not caps.TextCenter then tx_ = tx_ - math.floor(wName * 0.5) end
            dvec(nameT, K, "np", "Position", tx_, math.floor(yName + 0.5))
            if caps.TextAlpha then dset(nameT, K, "na", "Transparency", opacity) end
        end
        dset(nameT, K, "vn", "Visible", showName and true or false)
        if showInfo then
            dset(distT, K, "dt", "Text", st.InfoStr)
            dset(distT, K, "ds", "Size", ti)
            local tx_ = math.floor(bx + 0.5)
            if not caps.TextCenter then tx_ = tx_ - math.floor(wInfo * 0.5) end
            dvec(distT, K, "dp", "Position", tx_, math.floor(yInfo + 0.5))
            if caps.TextAlpha then dset(distT, K, "da", "Transparency", AR.q(opacity * 0.9)) end
        end
        dset(distT, K, "vd", "Visible", showInfo and true or false)
    end
    -- кружок со счётчиком
    local badge, cntT = o.CntBg, o.CntT
    if badge then
        if cnt > 1 then
            local off = math.floor(unit * 0.95 + 0.5)
            local bxc, byc = hx + off, hy - off
            local br = math.max(8, math.floor(unit * 0.58 + 0.5))
            AR.dcirc(badge, K, KS.CntBg, bxc, byc, br, rimCol, ca_ and AR.q(opacity * 0.95) or 1, ca_)
            local fs = math.max(11, math.floor(br * 1.4 + 0.5))
            dset(cntT, K, "ct", "Text", tostring(cnt))
            dset(cntT, K, "cs", "Size", fs)
            dvec(cntT, K, "cp", "Position", bxc + (caps.TextCenter and 0 or -math.floor(fs * 0.25)), byc - math.floor(fs * 0.5 + 0.5))
            if caps.TextAlpha then dset(cntT, K, "cq", "Transparency", opacity) end
            dset(cntT, K, "vc", "Visible", true)
        else
            dset(badge, K, KS.CntBg[5], "Visible", false)
            dset(cntT, K, "vc", "Visible", false)
        end
    end
end

-- ---------------------------------------------------------------- GUI
function AR.ensureGui()
    local gui = M.UI.ArrowGui
    if gui and gui.Parent then return gui end
    if gui then pcall(function() gui:Destroy() end) end
    gui = M.F.NewGui("Arrows", 46)
    M.UI.ArrowGui = gui
    return gui
end

end}

-- [48/69] Стрелки: вариант из элементов меню, образец в меню
MODULES[#MODULES + 1] = {"48. Стрелки: вариант из элементов меню, образец в меню", function(M, __X)
local AR = __X.AR
-- луч из обычного Frame
function AR.pill(parent, x0, y0, x1, y1, thick)
    local span = AR.Span
    local dx, dy = x1 - x0, y1 - y0
    local len = math.sqrt(dx * dx + dy * dy)
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.fromScale((x0 + x1) / 2 / span + 0.5, (y0 + y1) / 2 / span + 0.5)
    f.Size = UDim2.fromScale((len + thick) / span, thick / span)
    f.Rotation = math.deg(math.atan2(dy, dx))
    f.BorderSizePixel = 0
    f.BackgroundTransparency = 1
    Instance.new("UICorner", f).CornerRadius = UDim.new(0.5, 0)
    f.Parent = parent
    return f
end

-- луч заливки
function AR.ray(parent, x0, y0, x1, y1, thick)
    local span = AR.Span
    local dx, dy = x1 - x0, y1 - y0
    local len = math.sqrt(dx * dx + dy * dy)
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.fromScale((x0 + x1) / 2 / span + 0.5, (y0 + y1) / 2 / span + 0.5)
    f.Size = UDim2.fromScale(math.max(len, 0.001) / span, thick / span)
    f.Rotation = math.deg(math.atan2(dy, dx))
    f.BorderSizePixel = 0
    f.BackgroundTransparency = 1
    f.Parent = parent
    return f
end
-- parent
function AR.buildGui(style, parent, preview)
    local sh = AR.Shapes[style]
    local gui = parent or AR.ensureGui()
    local span = AR.Span
    local holder = Instance.new("Frame")
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.Size = UDim2.fromOffset(40, 40)
    holder.Visible = false

    local function disc(radius)
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.fromScale(0.5, 0.5)
        f.Size = UDim2.fromScale(radius * 2 / span, radius * 2 / span)
        f.BorderSizePixel = 0
        f.BackgroundTransparency = 1
        Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
        f.Parent = holder
        return f
    end
    local glowO, glowI = disc(2.0), disc(1.62)
    local plate = disc(AR.PlateR)
    plate.BackgroundColor3 = AR.Dark
    -- кольцо цвета стрелки - контур подложки
    local ring = Instance.new("UIStroke")
    ring.Thickness = 1.5
    ring.Transparency = 1
    ring.Color = AR.White
    ring.Parent = plate

    local rotor = Instance.new("Frame")
    rotor.AnchorPoint = Vector2.new(0.5, 0.5)
    rotor.Position = UDim2.fromScale(0.5, 0.5)
    rotor.Size = UDim2.fromScale(1, 1)
    rotor.BackgroundTransparency = 1
    rotor.BorderSizePixel = 0
    rotor.Parent = holder

    local fills, rims = {}, {}
    local fan
    if sh.Kind == "poly" then
        fan = AR.fan(sh)
        -- те же лучи, что и у рисунков: заливка не выходит за обводку
        for _, e in ipairs(AR.fanRays(sh, sh.RayT, AR.GuiRim * 0.5)) do
            fills[#fills + 1] = AR.ray(rotor, e[1], e[2], e[3], e[4], sh.RayT)
        end
        for i = 1, 4 do
            local a, b = sh.Pts[i], sh.Pts[i % 4 + 1]
            rims[#rims + 1] = AR.pill(rotor, a[1], a[2], b[1], b[2], AR.GuiRim)
        end
    else
        local tx, ty, ex, ey = sh.Tip[1], sh.Tip[2], sh.End[1], sh.End[2]
        local rimT = sh.Thick + AR.GuiRim * 2
        rims = {AR.pill(rotor, tx, ty, ex, ey, rimT), AR.pill(rotor, tx, ty, -ex, ey, rimT)}
        fills = {AR.pill(rotor, tx, ty, ex, ey, sh.Thick), AR.pill(rotor, tx, ty, -ex, ey, sh.Thick)}
    end

    -- кружок со счётчиком группы
    local cntBg = Instance.new("Frame")
    cntBg.AnchorPoint = Vector2.new(0.5, 0.5)
    cntBg.BorderSizePixel = 0
    cntBg.BackgroundColor3 = AR.Dark
    cntBg.BackgroundTransparency = 1
    cntBg.Visible = false
    Instance.new("UICorner", cntBg).CornerRadius = UDim.new(1, 0)
    cntBg.Parent = holder
    local cntL = Instance.new("TextLabel")
    cntL.Size = UDim2.fromScale(1, 1)
    cntL.BackgroundTransparency = 1
    cntL.Font = Enum.Font.GothamBold
    cntL.TextSize = 12
    cntL.TextColor3 = AR.White
    cntL.Text = ""
    cntL.Parent = cntBg

    -- полоска здоровья
    local hpBox = Instance.new("Frame")
    hpBox.AnchorPoint = Vector2.new(0.5, 0.5)
    hpBox.BorderSizePixel = 0
    hpBox.BackgroundColor3 = AR.Dark
    hpBox.BackgroundTransparency = 1
    hpBox.Visible = false
    Instance.new("UICorner", hpBox).CornerRadius = UDim.new(0.5, 0)
    hpBox.Parent = preview and holder or gui
    local hpFill = Instance.new("Frame")
    hpFill.BorderSizePixel = 0
    hpFill.BackgroundTransparency = 1
    hpFill.Position = UDim2.fromOffset(1, 1.5)
    hpFill.Size = UDim2.fromOffset(0, 3)
    Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0.5, 0)
    hpFill.Parent = hpBox

    local nameL, distL
    if not preview then
        local function label(font, color)
            local l = Instance.new("TextLabel")
            l.AnchorPoint = Vector2.new(0.5, 0)
            l.Size = UDim2.fromOffset(160, 16)
            l.BackgroundTransparency = 1
            l.Font = font
            l.TextSize = 12
            l.TextColor3 = color
            l.TextStrokeColor3 = Color3.new(0, 0, 0)
            l.TextStrokeTransparency = 0.4
            l.Text = ""
            l.Visible = false
            l.Parent = gui
            return l
        end
        nameL, distL = label(Enum.Font.GothamBold, AR.White), label(Enum.Font.Gotham, AR.Soft)
    end
    holder.Parent = gui
    return {Dr = false, Style = style, Shape = sh, Shaded = sh.Kind == "poly", Fan = fan, Holder = holder, GlowO = glowO, GlowI = glowI,
        Plate = plate, Ring = ring, Rotor = rotor, Fills = fills, Rims = rims, NameL = nameL, DistL = distL, HpBox = hpBox,
        HpFill = hpFill, CntBg = cntBg, CntL = cntL, Preview = preview and true or false}
end

function AR.applyGui(st, o, px, py, ang, unit, col, opacity, S, ca, sa)
    local holder = o.Holder
    ca, sa = ca or 0, sa or 0
    local side = math.floor(AR.Span * unit * 2 + 0.5) / 2
    if o.Side ~= side then
        o.Side = side
        holder.Size = UDim2.fromOffset(side, side)
        local half, off = math.floor(side * 0.5), math.floor(unit * 0.95 + 0.5)
        local br = math.max(8, math.floor(unit * 0.58 + 0.5))
        o.CntBg.Size = UDim2.fromOffset(br * 2, br * 2)
        o.CntBg.Position = UDim2.fromOffset(half + off, half - off)
        o.CntL.TextSize = math.max(11, math.floor(br * 1.4 + 0.5))
        o.Ring.Thickness = math.max(1.2, math.floor(unit * 0.15 + 0.5) * 0.5)
    end
    holder.Position = UDim2.fromOffset(math.floor(px + 0.5), math.floor(py + 0.5))
    local rot = math.deg(ang) + 90
    if o.Rot ~= rot then
        o.Rot = rot
        o.Rotor.Rotation = rot
    end
    if not holder.Visible then holder.Visible = true end

    -- цвет и прозрачность
    local oq = AR.q(opacity)
    local thr = st.Threat or 0
    local glowK = math.floor(((S.ArrowGlow and 0.6 or 0) + 0.9 * thr) * 20 + 0.5) / 20
    local hk = math.floor(thr * 10 + 0.5)
    local plateOn = S.ArrowPlate and true or false
    if o.HaloK ~= hk then
        -- свечение врага-угрозы шире
        o.HaloK = hk
        local ro, ri = (2.0 + 0.55 * hk / 10) * 2 / AR.Span, (1.62 + 0.4 * hk / 10) * 2 / AR.Span
        o.GlowO.Size = UDim2.fromScale(ro, ro)
        o.GlowI.Size = UDim2.fromScale(ri, ri)
    end
    local ringA = AR.q(0.55 + 0.4 * thr)
    if o.Col ~= col or o.Op ~= oq or o.GlowK ~= glowK or o.PlateOn ~= plateOn or o.RingA ~= ringA then
        if o.Col ~= col then
            AR.tones(st, col)
            if o.Shaded then
                local rc = AR.rayColors(st, o.Fan, col)
                for i, f in ipairs(o.Fills) do f.BackgroundColor3 = rc[i] end
            else
                for _, f in ipairs(o.Fills) do f.BackgroundColor3 = col end
            end
            for _, f in ipairs(o.Rims) do f.BackgroundColor3 = st.RimCol end
            o.GlowO.BackgroundColor3 = col
            o.GlowI.BackgroundColor3 = col
            o.Plate.BackgroundColor3 = st.PlateCol
            o.Ring.Color = st.RingCol
            o.CntBg.BackgroundColor3 = st.RimCol
        end
        o.Col, o.Op, o.GlowK, o.PlateOn, o.RingA = col, oq, glowK, plateOn, ringA
        local tf = 1 - oq
        for _, f in ipairs(o.Fills) do f.BackgroundTransparency = tf end
        for _, f in ipairs(o.Rims) do f.BackgroundTransparency = tf end
        o.GlowO.BackgroundTransparency = glowK > 0 and (1 - AR.q(oq * 0.07 * glowK)) or 1
        o.GlowI.BackgroundTransparency = glowK > 0 and (1 - AR.q(oq * 0.12 * glowK)) or 1
        o.Plate.BackgroundTransparency = plateOn and (1 - AR.q(oq * 0.55)) or 1
        o.Ring.Transparency = plateOn and (1 - AR.q(oq * ringA)) or 1
        o.CntOp = nil
        o.HpOp = nil
    end

    -- кружок со счётчиком группы
    local cnt = st.Count or 1
    if cnt > 1 then
        if o.CntVal ~= cnt then o.CntVal = cnt; o.CntL.Text = tostring(cnt) end
        if o.CntOp ~= oq then
            o.CntOp = oq
            o.CntBg.BackgroundTransparency = 1 - AR.q(oq * 0.95)
            o.CntL.TextTransparency = 1 - oq
        end
        if not o.CntBg.Visible then o.CntBg.Visible = true end
    elseif o.CntBg.Visible then
        o.CntBg.Visible = false
    end

    -- блок подписей
    local nameL, distL = o.NameL, o.DistL
    local showName, showInfo, showBar = nameL ~= nil and S.ArrowName, st.InfoStr ~= "", S.ArrowHealth
    if nameL == nil then showInfo = false end
    local ts, ti, bx, yName, yBar, yInfo, wName, wInfo, hw
    if showName or showInfo or showBar then
        ts, ti, bx, yName, yBar, yInfo, wName, wInfo, hw = AR.labelPlan(st, S, unit, ca, sa, px, py)
    end
    local box, fill = o.HpBox, o.HpFill
    if showBar then
        local hp = math.floor(math.clamp(st.Hp or 1, 0, 1) * 20 + 0.5) / 20
        local bw = o.Preview and math.clamp(math.floor(unit * 1.9 + 0.5), 30, 96) or hw
        if o.HpW ~= bw then
            o.HpW = bw
            box.Size = UDim2.fromOffset(bw + 2, 6)
            o.HpVal = nil
        end
        if o.Preview then
            box.Position = UDim2.fromOffset(math.floor(side * 0.5 + 0.5), math.floor(side * 0.5 + unit * AR.PlateR + 8 + 0.5))
        else
            box.Position = UDim2.fromOffset(math.floor(bx + 0.5), math.floor(yBar + 4.5))
        end
        if o.HpVal ~= hp then
            o.HpVal = hp
            fill.Size = UDim2.fromOffset(math.floor(bw * hp + 0.5), 3)
        end
        local hc = AR.hpColor(st, hp)
        if o.HpCol ~= hc then o.HpCol = hc; fill.BackgroundColor3 = hc end
        if o.HpOp ~= oq then
            o.HpOp = oq
            box.BackgroundTransparency = 1 - AR.q(oq * 0.72)
            fill.BackgroundTransparency = 1 - oq
        end
        if not box.Visible then box.Visible = true end
    elseif box.Visible then
        box.Visible = false
    end

    if not nameL then return end
    local tt = 1 - oq
    if showName then
        if nameL.Text ~= st.NameStr then nameL.Text = st.NameStr end
        if nameL.TextSize ~= ts then nameL.TextSize = ts end
        nameL.Position = UDim2.fromOffset(math.floor(bx + 0.5), math.floor(yName + 0.5))
        nameL.TextTransparency = tt
        nameL.Visible = true
    else
        nameL.Visible = false
    end
    if showInfo then
        if distL.Text ~= st.InfoStr then distL.Text = st.InfoStr end
        if distL.TextSize ~= ti then distL.TextSize = ti end
        distL.Position = UDim2.fromOffset(math.floor(bx + 0.5), math.floor(yInfo + 0.5))
        distL.TextTransparency = 1 - AR.q(oq * 0.9)
        distL.Visible = true
    else
        distL.Visible = false
    end
end

end}

-- [49/69] Стрелки: тестовые стрелки, модуль, расчёт кадра (группы, угроза, посадка)
MODULES[#MODULES + 1] = {"49. Стрелки: тестовые стрелки, модуль, расчёт кадра (группы, угроза, посадка)", function(M, __X)
local AR = __X.AR
local dset = __X.dset
local dvec = __X.dvec
function AR.hideGui(o)
    if o.Holder.Visible then o.Holder.Visible = false end
    if o.NameL and o.NameL.Visible then o.NameL.Visible = false end
    if o.DistL and o.DistL.Visible then o.DistL.Visible = false end
    if o.HpBox.Visible then o.HpBox.Visible = false end
end

-- ---------------------------------------------------------------- Общее
function AR.build(style, useDraw)
    local o
    if useDraw then o = AR.buildDraw(style) end
    if not o then o = AR.buildGui(style) end
    o.Backend = useDraw
    return o
end

function AR.hide(o)
    if o.Dr then AR.hideDraw(o) else AR.hideGui(o) end
end

function AR.dispose(o)
    if not o then return end
    if o.Dr then
        for _, obj in ipairs(o.All) do M.Draw.Remove(obj) end
        o.All = {}
    else
        pcall(function() o.Holder:Destroy() end)
        if o.NameL then pcall(function() o.NameL:Destroy() end) end
        if o.DistL then pcall(function() o.DistL:Destroy() end) end
        if o.HpBox then pcall(function() o.HpBox:Destroy() end) end
    end
end

AR.PrevAngles = {-1.5708, -0.55, 0.8, 2.55}
AR.PrevDist = {14, 70, 170, 330}
AR.PrevHp = {1, 0.7, 0.4, 0.15}
AR.PrevThreat = {0, 1, 0, 0}
AR.PrevCount = {1, 1, 3, 1}

function M.F.ArrowPreviewRefresh()
    local P = M.Data.ArrowPrev
    if not P or not P.Stage.Parent then return end
    local S = M.State
    local size = math.clamp(tonumber(S.ArrowSize) or 30, 12, 150)
    local style = AR.styleName(S.ArrowStyle)
    for i = 1, 4 do
        local item = P.Items[i]
        local o = item.Obj
        if o and o.Style ~= style then
            pcall(function() o.Holder:Destroy() end)
            o = nil
        end
        if not o then
            o = AR.buildGui(style, P.Stage, true)
            item.Obj = o
        end
        local dist = AR.PrevDist[i]
        local st = item.St
        st.Dist, st.Hp = dist, AR.PrevHp[i]
        st.Threat = S.ArrowThreat and AR.PrevThreat[i] or 0
        st.Count = S.ArrowGroup and AR.PrevCount[i] or 1
        local sc = 1
        if S.ArrowScaleDist then sc = 1.28 - 0.52 * math.clamp(dist / 300, 0, 1) end
        if st.Threat > 0 then sc = sc * 1.15 end
        local unit = math.min(size * 0.5 * sc, 22)
        local col = AR.shade(AR.neon(AR.color(st, S)), dist)
        if st.Threat > 0.05 then col = col:Lerp(AR.White, 0.4 * st.Threat) end
        local a = AR.PrevAngles[i]
        AR.applyGui(st, o, 0, 0, a, unit, col, S.ArrowOpacity or 1, S, math.cos(a), math.sin(a))
        o.Holder.Position = UDim2.new((i - 0.5) / 4, 0, 0.5, 0)
    end
end

-- карточка с образцом в странице меню
function M.F.ArrowPreviewBuild(parent, order)
    local card = M.F.MakeCard(parent, 112)
    card.LayoutOrder = order
    local stage = Instance.new("Frame")
    stage.Name = "ArrowPreview"
    stage.Position = UDim2.new(0, 8, 0, 8)
    stage.Size = UDim2.new(1, -16, 1, -16)
    stage.BackgroundColor3 = Color3.fromRGB(20, 24, 33)
    stage.BorderSizePixel = 0
    stage.ClipsDescendants = true
    Instance.new("UICorner", stage).CornerRadius = UDim.new(0, 9)
    stage.Parent = card
    local items = {}
    for i = 1, 4 do
        local st = AR.newState(nil)
        st.Alpha = 1
        st.NameStr, st.DistStr = "", ""
        items[i] = {St = st}
    end
    M.Data.ArrowPrev = {Card = card, Stage = stage, Items = items}
    task.spawn(function()
        while not M.Run.IsShutDown and stage.Parent do
            local main = M.UI.Main
            if main and main.Visible and parent.Visible then M.F.Safe("ArrowPreview", M.F.ArrowPreviewRefresh) end
            task.wait(0.15)
        end
    end)
    M.F.ArrowPreviewRefresh()
    return card
end

-- кольцо, по которому идут стрелки
function AR.updateRing(D, S, useDraw, hidden, cx, cy, radius, alpha)
    local show = S.ArrowRing and S.ArrowPlacement ~= "Edge" and alpha > 0.03 and not hidden
    local ring = D.ArrowRing
    if ring and ring.Dr ~= useDraw then
        if ring.Dr then M.Draw.Remove(ring.Obj) else pcall(function() ring.Obj:Destroy() end) end
        ring = nil
        D.ArrowRing = nil
    end
    if not ring then
        if not show then return end
        if useDraw then
            local c = M.Draw.New("Circle")
            if c then
                pcall(function()
                    c.Filled = false
                    c.Thickness = 1
                    c.Color = Color3.new(1, 1, 1)
                    if M.Draw.Caps.CircleSides then c.NumSides = 96 end
                end)
                ring = {Dr = true, Obj = c, K = {}}
            end
        end
        if not ring then
            local frame = Instance.new("Frame")
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.BackgroundTransparency = 1
            frame.BorderSizePixel = 0
            frame.Visible = false
            Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
            local stroke = Instance.new("UIStroke", frame)
            stroke.Thickness = 1
            stroke.Color = Color3.new(1, 1, 1)
            frame.Parent = AR.ensureGui()
            ring = {Dr = false, Obj = frame, Stroke = stroke}
        end
        D.ArrowRing = ring
    end
    if ring.Dr then
        local K, c = ring.K, ring.Obj
        if show then
            dvec(c, K, "p", "Position", math.floor(cx + 0.5), math.floor(cy + 0.5))
            dset(c, K, "r", "Radius", math.floor(radius + 0.5))
            if M.Draw.Caps.CircleAlpha then dset(c, K, "a", "Transparency", 0.22 * alpha) end
        end
        dset(c, K, "v", "Visible", show and true or false)
    else
        local frame = ring.Obj
        if show then
            local d = math.floor(radius * 2 + 0.5)
            frame.Size = UDim2.fromOffset(d, d)
            frame.Position = UDim2.fromOffset(math.floor(cx + 0.5), math.floor(cy + 0.5))
            ring.Stroke.Transparency = 1 - 0.22 * alpha
        end
        if frame.Visible ~= show then frame.Visible = show end
    end
end

M.F.DefineModule("OffscreenArrows", {
    Wanted = function() return M.State.ArrowsOn end,
    Load = function()
        M.Data.Arrows = {}
        pcall(function() M.Services.R:UnbindFromRenderStep("ArrowsFrame") end)
        M.Services.R:BindToRenderStep("ArrowsFrame", Enum.RenderPriority.Last.Value + 2, function(dt)
            if M.Run.IsShutDown then return end
            M.F.Safe("Arrows", M.F.UpdateArrows, dt)
        end)
    end,
    Unload = function()
        pcall(function() M.Services.R:UnbindFromRenderStep("ArrowsFrame") end)
        local D = M.Data
        if D.Arrows then
            for _, st in pairs(D.Arrows) do AR.dispose(st.Obj) end
        end
        local ring = D.ArrowRing
        if ring then
            if ring.Dr then M.Draw.Remove(ring.Obj) else pcall(function() ring.Obj:Destroy() end) end
        end
        D.ArrowRing = nil
        if M.UI.ArrowGui then pcall(function() M.UI.ArrowGui:Destroy() end) end
        M.UI.ArrowGui = nil
        D.Arrows = nil
    end
})

function M.F.UpdateArrows(dt)
    local D, S = M.Data, M.State
    local arrows = D.Arrows
    if not arrows then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    M.Math.ProjBegin(cam)
    dt = math.clamp(dt or 0.016, 0.001, 0.1)
    -- частота стрелок не зависит от FPS: до 90 раз в секунду (под большой нагрузкой до 45)
    local interval = D.Gov.Level >= 3 and 1 / 45 or 1 / 90
    local acc = (D.ArrowDtAcc or 0) + dt
    if acc < interval then
        D.ArrowDtAcc = acc
        return
    end
    dt = math.min(acc, 0.1)
    D.ArrowDtAcc = 0
    local viewport = cam.ViewportSize
    local vw, vh = viewport.X, viewport.Y
    local cx, cy = vw / 2, vh / 2
    local camCF = cam.CFrame
    local camPos = camCF.Position
    local now = os.clock()
    AR.Now = now
    local useDraw = M.Draw.Enabled()
    local blocked = useDraw and M.Draw.Blocked()
    local menuRect = (useDraw and not blocked) and M.F.MenuRect() or nil
    local follow = 1 - math.exp(-dt * 14)
    local follow2 = 1 - math.exp(-dt * 16)
    local fade = 1 - math.exp(-dt * 10)

    local size = S.ArrowSize
    local half = math.min(vw, vh) / 2
    local edge = S.ArrowPlacement == "Edge"
    local rMax = math.max(30, half - size * 0.85 - 6)
    local radius = math.clamp(S.ArrowRadius, 30, rMax)
    local margin = math.clamp(S.ArrowMargin, size * 0.8 + 6, math.max(size * 0.8 + 6, half - 24))
    local ex, ey = cx - margin, cy - margin
    local maxDist = S.PlayerViewMaxDist
    local caps = M.Draw.Caps or {}

    local cand = AR.Cand
    table.clear(cand)
    local n = 0
    local players = M.F.Players()
    -- номер кадра
    local frameId = (D.ArrowFrame or 0) + 1
    D.ArrowFrame = frameId
    for i = 1, #players do
        local player = players[i]
        local st = arrows[player]
        if st then st.Seen = frameId end
        local want = false
        if player ~= M.LP then
            local char = M.F.CharOf(player)
            local root = char and M.GetRoot(char)
            local hum = char and M.GetHumanoid(char)
            local hpNow, hpMax, alive = 0, 1, false
            if root then hpNow, hpMax, alive = M.F.CharVitals(char, hum) end
            if root and alive and M.F.EspAllows(player, true) then
                local pos = root.Position
                local spx, spy, spz = M.Math.Project(pos)
                local pad = (st and st.Want) and 24 or 0
                local inside = spz > 0 and spx > pad and spx < vw - pad and spy > pad and spy < vh - pad
                if not inside then
                    local dist = (pos - camPos).Magnitude
                    if dist <= maxDist then
                        want = true
                        if not st then
                            st = AR.newState(player)
                            st.Seen = frameId
                            arrows[player] = st
                        end
                        local rel = camCF:PointToObjectSpace(pos)
                        local fx, fy = rel.X, -rel.Y
                        local m = math.sqrt(fx * fx + fy * fy)
                        if m > 0.001 then st.Dx, st.Dy = fx / m, fy / m else st.Dx, st.Dy = nil, nil end
                        st.Dist = dist
                        -- угол от оси взгляда
                        local rl = rel.Magnitude
                        st.Off = rl > 0.001 and math.acos(math.clamp(-rel.Z / rl, -1, 1)) or 0
                        local dy = pos.Y - camPos.Y
                        st.H = (S.ArrowHeight and math.abs(dy) >= 6) and math.floor(dy + 0.5) or 0
                        -- угроза
                        st.ThreatT = 0
                        if S.ArrowThreat and dist <= 250 and root.CFrame.LookVector:Dot(camPos - pos) > 0.97 * dist then st.ThreatT = 1 end
                        st.Char = char
                        st.Hp = M.Math.HpFraction(hpNow, hpMax)
                        -- имя меняется редко: читаем раз в 2 секунды
                        if not st.NameAt or now - st.NameAt > 2 then
                            st.NameAt = now
                            local nm = player.DisplayName
                            st.NameStr = (nm ~= nil and nm ~= "") and nm or player.Name
                        end
                        local d10 = math.floor(dist + 0.5)
                        if st.LastDist ~= d10 then
                            st.LastDist = d10
                            st.DistStr = d10 .. M.Translate("Unit_m")
                        end
                        n = n + 1
                        cand[n] = st
                    end
                end
            end
        end
        if st and not want then st.Want = false end
    end

    local threatFollow = 1 - math.exp(-dt * 8)
    for i = 1, n do
        local st = cand[i]
        st.Want = true
        st.Count = 1
        local target
        if st.Dx then target = math.atan2(st.Dy, st.Dx) else target = st.Ang or (math.pi / 2) end
        if st.Ang == nil then
            st.Ang = target
        else
            st.Ang = AR.wrap(st.Ang + AR.angDiff(st.Ang, target) * follow)
        end
        st.Tgt = st.Ang
        -- ThrS
        local tt, th = st.ThreatT or 0, st.ThrS or 0
        th = th + (tt - th) * threatFollow
        if tt == 0 and th < 0.01 then th = 0 elseif tt == 1 and th > 0.99 then th = 1 end
        st.ThrS = th
        st.Threat = th
        st.Score = st.Dist * ((st.Alpha > 0.5) and 0.8 or 1) * (1 - 0.6 * th) * (st.WasLeader and 0.85 or 1)
    end

    -- 3. Группы
    if S.ArrowGroup and n > 1 then
        local gap = math.rad(math.clamp(M.Math.Finite(S.ArrowGroupAngle, 10), 2, 40))
        table.sort(cand, AR.byAngle)
        local out, i = 0, 1
        while i <= n do
            local j = i
            while j < n and AR.angDiff(cand[i].Ang, cand[j + 1].Ang) < gap do j = j + 1 end
            local leader = cand[i]
            local worst = 0
            for k = i, j do
                if cand[k].ThrS > worst then worst = cand[k].ThrS end
                if k > i and AR.byScore(cand[k], leader) then leader = cand[k] end
            end
            leader.Threat = worst
            for k = i, j do
                local st = cand[k]
                if st == leader then
                    st.Count = st.Count + (j - i)
                    st.WasLeader = true
                    out = out + 1
                    cand[out] = st
                else
                    st.Want = false
                    st.WasLeader = false
                end
            end
            i = j + 1
        end
        for k = n, out + 1, -1 do cand[k] = nil end
        n = out
    else
        for i = 1, n do cand[i].WasLeader = false end
    end

    local maxCount = math.max(1, math.floor(S.ArrowMaxCount or 8))
    if n > maxCount then
        table.sort(cand, AR.byScore)
        for i = n, maxCount + 1, -1 do
            cand[i].Want = false
            cand[i] = nil
        end
        n = maxCount
    end

    if n > 1 then
        local refRadius = edge and (ex + ey) * 0.5 or radius
        -- подложка с кольцом шире самой стрелки
        local gap = 2 * math.asin(math.min(1, (size * (S.ArrowPlate and 1.4 or 1.15) + 4) / (2 * math.max(refRadius, 20))))
        gap = math.min(gap, AR.TwoPi / n)
        table.sort(cand, AR.byAngle)
        for _ = 1, 8 do
            for i = 1, n do
                local a = cand[i]
                local b, g
                if i < n then
                    b = cand[i + 1]
                    g = b.Tgt - a.Tgt
                else
                    b = cand[1]
                    g = b.Tgt + AR.TwoPi - a.Tgt
                end
                if g < gap then
                    local push = (gap - g) * 0.5
                    a.Tgt = a.Tgt - push
                    b.Tgt = b.Tgt + push
                end
            end
        end
    end

    local built, removed = 0, 0
    local maxAlpha = 0
    local scaleByDist, pulse = S.ArrowScaleDist, S.ArrowPulse
    local userOpacity = S.ArrowOpacity or 1
    local style = AR.styleName(S.ArrowStyle)
    if style ~= S.ArrowStyle then
        -- в конфиге осталась удалённая форма
        S.ArrowStyle = style
        for _, el in ipairs(M.F.VisualEntries("ArrowStyle")) do pcall(el.SetVisual, style) end
    end
    for player, st in pairs(arrows) do
        if not player.Parent then
            if st.Obj and not st.Hidden then AR.hide(st.Obj); st.Hidden = true end
            if removed < 2 or not st.Obj then
                removed = removed + 1
                AR.dispose(st.Obj)
                arrows[player] = nil
            end
        else
            if st.Seen ~= frameId then st.Want = false end
            local want = st.Want
            st.Alpha = st.Alpha + ((want and 1 or 0) - st.Alpha) * fade
            if want and st.Alpha > 0.995 then st.Alpha = 1 end
            if st.Alpha < 0.02 and not want then
                -- стрелка погасла
                st.Alpha = 0
                st.Ang, st.Disp = nil, nil
                if st.Obj and not st.Hidden then
                    AR.hide(st.Obj)
                    st.Hidden = true
                end
                st.Idle = (st.Idle or 0) + dt
                if st.Idle > 8 and st.Obj and removed < 2 then
                    removed = removed + 1
                    AR.dispose(st.Obj)
                    st.Obj = nil
                end
            elseif st.Ang ~= nil then
                st.Idle = 0
                if st.Alpha > maxAlpha then maxAlpha = st.Alpha end
                if want then
                    if st.Disp == nil then st.Disp = st.Tgt else st.Disp = st.Disp + AR.angDiff(st.Disp, st.Tgt) * follow2 end
                end
                local disp = st.Disp or st.Ang
                local ca, sa = math.cos(disp), math.sin(disp)
                -- умная посадка
                local smart = S.ArrowSmart
                local behind = smart and math.clamp((st.Off or 0) / math.pi, 0, 1) or 0
                local px, py
                if edge then
                    local tx = (ca ~= 0) and ex / math.abs(ca) or math.huge
                    local ty = (sa ~= 0) and ey / math.abs(sa) or math.huge
                    local t = math.min(tx, ty) * (1 - 0.22 * behind)
                    px, py = cx + ca * t, cy + sa * t
                else
                    local rt = smart and math.clamp(radius * (1.10 - 0.35 * behind), 30, rMax) or radius
                    -- радиус плавно догоняет цель
                    if smart and st.R then st.R = st.R + (rt - st.R) * follow2 else st.R = rt end
                    px, py = cx + ca * st.R, cy + sa * st.R
                end

                local dist = st.Dist
                local sc = 1
                if scaleByDist then sc = 1.28 - 0.52 * math.clamp(dist / 300, 0, 1) end
                if pulse and dist < 60 then
                    sc = sc * (1 + 0.12 * (1 - dist / 60) * (0.5 + 0.5 * math.sin(now * 10)))
                end
                -- тот, кто смотрит на вас, крупнее и пульсирует
                local threat = st.Threat or 0
                if threat > 0 then sc = sc * (1 + 0.15 * threat) * (1 + 0.12 * threat * (0.5 + 0.5 * math.sin(now * 9))) end
                -- появление и угасание
                local fadeK = 1 - st.Alpha
                sc = sc * (1 + 0.4 * fadeK * fadeK)
                local unit = size * 0.5 * sc
                -- враг за стеной приглушается
                local losK = 1
                if S.ArrowLos then
                    if st.Char and want and D.Gov.Level < 2 and now - (st.LosAt or 0) > 0.1 then
                        st.LosAt = now
                        local head = M.GetHead(st.Char)
                        if head then st.Los = M.TargetVisibility(head, st.Char) end
                    end
                    if st.Los == false then losK = 0.62 end
                end
                local lk = st.LosK or 1
                lk = lk + (losK - lk) * follow
                if math.abs(lk - losK) < 0.01 then lk = losK end
                st.LosK = lk
                local opacity = math.floor(st.Alpha * userOpacity * lk * 40 + 0.5) / 40  -- шагами по 1/40: лишние записи не нужны
                local col = AR.finalColor(st, S, dist, threat)
                AR.info(st, S)

                local o = st.Obj
                -- смена формы или способа рисования
                if o and (o.Style ~= style or o.Backend ~= useDraw) and built < 1 then
                    AR.dispose(o)
                    o = nil
                    st.Obj = nil
                end
                if not o and built < 1 and (M.Draw.MadeThisFrame() < 14 or frameId - (D.ArrowBuiltAt or 0) >= 3 or not useDraw) then
                    D.ArrowBuiltAt = frameId
                    built = built + 1
                    o = AR.build(style, useDraw)
                    st.Obj = o
                end
                if o then
                    st.Hidden = false
                    if o.Dr then
                        if blocked or (menuRect and AR.underMenu(menuRect, px, py, unit)) then
                            AR.hideDraw(o)
                        else
                            AR.applyDraw(st, o, px, py, st.Ang, unit, col, opacity, S, caps, ca, sa)
                        end
                    else
                        AR.applyGui(st, o, px, py, st.Ang, unit, col, opacity, S, ca, sa)
                    end
                end
            end
        end
    end

    AR.updateRing(D, S, useDraw, blocked or menuRect ~= nil, cx, cy, radius, maxAlpha)
end

end}

-- [50/69] Следы врагов
MODULES[#MODULES + 1] = {"50. Следы врагов", function(M, __X)
local dset = __X.dset
local dvec = __X.dvec
-- ==============================================================================
-- [ СЛЕДЫ ВРАГОВ ]
-- ==============================================================================
local FT = {
    Cand = {}, Sx = {}, Sy = {}, Sz = {}, Wx = {},
    Feet = Vector3.new(0, 2.6, 0),
    MaxSeg = 16,
}

-- один отрезок следа
function FT.newLine(useDraw)
    if useDraw then
        local obj = M.Draw.New("Line")
        if obj then return {Dr = true, Obj = obj, K = {}} end
    end
    local gui = M.UI.FoeTrailGui
    if not gui or not gui.Parent then
        if gui then pcall(function() gui:Destroy() end) end
        gui = M.F.NewGui("FoeTrails", 44)
        M.UI.FoeTrailGui = gui
    end
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BorderSizePixel = 0
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = gui
    return {Dr = false, Obj = f, K = {}}
end

function FT.hideLine(l)
    if l.Dr then dset(l.Obj, l.K, "v", "Visible", false)
    elseif l.Obj.Visible then l.Obj.Visible = false end
end

function FT.disposeLines(rec)
    for _, l in ipairs(rec.Lines) do
        if l.Dr then M.Draw.Remove(l.Obj) else pcall(function() l.Obj:Destroy() end) end
    end
    rec.Lines = {}
end

function FT.setLine(l, ax, ay, bx, by, thick, col, alpha, caps)
    if l.Dr then
        local o, K = l.Obj, l.K
        dvec(o, K, "f", "From", math.floor(ax * 2 + 0.5) * 0.5, math.floor(ay * 2 + 0.5) * 0.5)
        dvec(o, K, "t", "To", math.floor(bx * 2 + 0.5) * 0.5, math.floor(by * 2 + 0.5) * 0.5)
        dset(o, K, "c", "Color", col)
        dset(o, K, "w", "Thickness", math.floor(thick * 2 + 0.5) * 0.5)
        if caps.LineAlpha then dset(o, K, "a", "Transparency", math.floor(alpha * 20 + 0.5) / 20) end
        dset(o, K, "v", "Visible", true)
    else
        local f = l.Obj
        local dx, dy = bx - ax, by - ay
        local len = math.sqrt(dx * dx + dy * dy)
        f.Position = UDim2.fromOffset(math.floor((ax + bx) / 2 + 0.5), math.floor((ay + by) / 2 + 0.5))
        f.Size = UDim2.fromOffset(math.floor(len + 1.5), math.max(1, math.floor(thick + 0.5)))
        f.Rotation = math.deg(math.atan2(dy, dx))
        f.BackgroundColor3 = col
        f.BackgroundTransparency = 1 - math.floor(alpha * 20 + 0.5) / 20
        f.Visible = true
    end
end

M.F.DefineModule("FoeTrails", {
    Wanted = function() return M.State.FoeTrailOn end,
    Load = function()
        M.Data.Trails = {}
        pcall(function() M.Services.R:UnbindFromRenderStep("TrailsFrame") end)
        M.Services.R:BindToRenderStep("TrailsFrame", Enum.RenderPriority.Last.Value + 4, function(dt)
            if M.Run.IsShutDown then return end
            M.F.Safe("FoeTrails", M.F.UpdateFoeTrails, dt)
        end)
    end,
    Unload = function()
        pcall(function() M.Services.R:UnbindFromRenderStep("TrailsFrame") end)
        if M.Data.Trails then
            for _, rec in pairs(M.Data.Trails) do FT.disposeLines(rec) end
        end
        M.Data.Trails = nil
        if M.UI.FoeTrailGui then pcall(function() M.UI.FoeTrailGui:Destroy() end) end
        M.UI.FoeTrailGui = nil
    end
})

function M.F.UpdateFoeTrails(dt)
    local D, S = M.Data, M.State
    local trails = D.Trails
    if not trails then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    -- весь проход не чаще 90 раз в секунду (под нагрузкой 45): точки следа и так ставятся не чаще раза в 0.05 с
    local rate = D.Gov.Level >= 2 and 1 / 45 or 1 / 90
    local pass = (D.TrailPassAcc or 0) + (dt or 0)
    if pass < rate then
        D.TrailPassAcc = pass
        return
    end
    D.TrailPassAcc = 0
    dt = math.min(pass, 0.1)
    M.Math.ProjBegin(cam)
    local now = os.clock()
    local life = math.clamp(S.FoeTrailTime or 2.5, 0.5, 8)
    local interval = math.clamp(life / 12, 0.05, 0.6)
    local level = D.Gov.Level
    local useDraw = M.Draw.Enabled()
    local caps = M.Draw.Caps or {}
    local frameId = (D.TrailFrame or 0) + 1
    D.TrailFrame = frameId
    local camCF = cam.CFrame
    local camPos, look = camCF.Position, camCF.LookVector
    local vw, vh = cam.ViewportSize.X, cam.ViewportSize.Y

    local cand, nc = FT.Cand, 0
    table.clear(cand)
    local players = M.F.Players()
    local maxDist = S.PlayerViewMaxDist
    for i = 1, #players do
        local p = players[i]
        if p ~= M.LP then
            local char = M.F.CharOf(p)
            local root = char and M.GetRoot(char)
            local hum = char and M.GetHumanoid(char)
            if root and M.F.IsAliveChar(char, hum) and M.F.EspAllows(p) then
                local rec = trails[p]
                if not rec then
                    rec = {P = {}, T = {}, Last = -1, Lines = {}, Seen = 0, Idle = 0}
                    trails[p] = rec
                end
                rec.Seen = frameId
                local feet = root.Position - FT.Feet
                local np = #rec.P
                if np > 0 and (rec.P[np] - feet).Magnitude > 30 then
                    rec.P, rec.T = {}, {}
                    np = 0
                end
                if now - rec.Last >= interval then
                    rec.Last = now
                    rec.P[np + 1], rec.T[np + 1] = feet, now
                    while #rec.T > 0 and (now - rec.T[1] > life + interval or #rec.T > FT.MaxSeg + 2) do
                        table.remove(rec.P, 1)
                        table.remove(rec.T, 1)
                    end
                end
                rec.Cur = feet
                rec.Dist = (feet - camPos).Magnitude
                if rec.Dist <= maxDist then
                    nc = nc + 1
                    cand[nc] = rec
                end
            end
        end
    end

    -- не больше FoeTrailMax следов
    local maxCount = math.max(1, math.floor(S.FoeTrailMax or 5))
    if level >= 2 then maxCount = math.min(maxCount, 3) end
    if nc > maxCount then
        table.sort(cand, function(a, b) return a.Dist < b.Dist end)
        for i = nc, maxCount + 1, -1 do cand[i] = nil end
        nc = maxCount
    end
    for i = 1, nc do cand[i].Want = frameId end

    local hidden = level >= 3 or (useDraw and (M.Draw.Blocked() or M.F.MenuRect() ~= nil))
    -- рисуем не чаще 90 раз в секунду (под нагрузкой до 45); точки следа записываются с обычной частотой
    local interval = level >= 2 and 1 / 45 or 1 / 90
    local acc = (D.TrailDrawAcc or 0) + (dt or 0)
    local skipDraw = acc < interval
    D.TrailDrawAcc = skipDraw and acc or math.min(acc - interval, interval)

    -- 2. Рисуем и убираем лишнее
    local col = S.FoeTrailCol
    local thickBase = S.FoeTrailThick or 2
    local opacity = 0.9
    local removed = 0
    local newLines = 0
    for p, rec in pairs(trails) do
        local wanted = rec.Want == frameId and not hidden
        if not p.Parent or rec.Seen ~= frameId then
            -- враг ушёл, умер или перестал быть целью
            for _, l in ipairs(rec.Lines) do FT.hideLine(l) end
            rec.Idle = rec.Idle + dt
            if rec.Idle > 5 or not p.Parent then
                if removed < 2 then
                    removed = removed + 1
                    FT.disposeLines(rec)
                    trails[p] = nil
                end
            end
            rec.P, rec.T = {}, {}
        elseif wanted then
            rec.Idle = 0
            if skipDraw then
                -- оставляем нарисованное
            else
                if rec.Dr ~= nil and rec.Dr ~= useDraw then FT.disposeLines(rec) end
                rec.Dr = useDraw
                local pts, tms = rec.P, rec.T
                local n = #pts
                local total = n + 1
                local sx, sy, sz = FT.Sx, FT.Sy, FT.Sz
                            for k = 1, total do
                    local pos = (k <= n) and pts[k] or rec.Cur
                    sx[k], sy[k], sz[k] = M.Math.Project(pos)
                end
                local used = 0
                for j = 1, n do
                    local a, b = j, j + 1
                    local tb = (b <= n) and tms[b] or now
                    local frac = 1 - (now - tb) / life
                    local ax, ay, bx, by = sx[a], sy[a], sx[b], sy[b]
                    local okSeg = frac > 0.02
                    if okSeg and (sz[a] <= 0.05 or sz[b] <= 0.05) then
                        if sz[a] <= 0.05 and sz[b] <= 0.05 then
                            okSeg = false
                        else
                            -- один конец за камерой
                            local pa = (a <= n) and pts[a] or rec.Cur
                            local pb = (b <= n) and pts[b] or rec.Cur
                            local da, db = (pa - camPos):Dot(look), (pb - camPos):Dot(look)
                            local tcl = (0.1 - da) / (db - da)
                            local pc = pa + (pb - pa) * tcl
                            local vx, vy = M.Math.Project(pc)
                            if sz[a] <= 0.05 then ax, ay = vx, vy else bx, by = vx, vy end
                        end
                    end
                    if okSeg and ((math.abs(ax - bx) + math.abs(ay - by)) < 0.6 or (ax < 0 and bx < 0) or (ax > vw and bx > vw)
                        or (ay < 0 and by < 0) or (ay > vh and by > vh)) then
                        okSeg = false
                    end
                    if okSeg then
                        used = used + 1
                        local l = rec.Lines[used]
                        if not l and newLines < 6 then
                            newLines = newLines + 1
                            l = FT.newLine(useDraw)
                            rec.Lines[used] = l
                        end
                        if l then
                            local f = math.clamp(frac, 0, 1)
                            FT.setLine(l, ax, ay, bx, by, math.max(1, thickBase * (0.35 + 0.65 * f)), col, opacity * f ^ 1.3, caps)
                        end
                    end
                end
                for k = used + 1, #rec.Lines do FT.hideLine(rec.Lines[k]) end
            end
        else
            for _, l in ipairs(rec.Lines) do FT.hideLine(l) end
        end
    end
end
end}

-- [51/69] Следы от пуль
MODULES[#MODULES + 1] = {"51. Следы от пуль", function(M, __X)
-- ==============================================================================
-- [ ТРАССЕРЫ ]
-- ==============================================================================
do
local TRACER_MAX = 24
local TRACER_SPEED = 2200
local TRACER_MIN_GAP = 0.06
local TRACER_CLICK_SOUND = 0.25

local wordSet, hasWord = M.F.WordSet, M.F.HasWord

-- сравнение идёт по целым словам названия
local TRACER_MELEE = wordSet({"knife", "knives", "sword", "bat", "axe", "hammer", "melee", "pickaxe", "fist", "fists",
    "punch", "katana", "machete", "shovel", "wrench", "crowbar", "spear", "club", "saber", "sabre", "scythe", "dagger",
    "blade", "mace", "bow", "karambit", "cleaver", "baton", "hatchet", "kunai", "lance", "halberd", "rapier", "sickle",
    "trident", "claymore"})
local TRACER_GUN_NAMES = wordSet({"gun", "rifle", "pistol", "smg", "shotgun", "sniper", "revolver", "deagle", "glock",
    "uzi", "carbine", "lmg", "minigun", "blaster", "launcher", "rpg", "ak", "ar", "mp", "awp", "scar", "famas", "aug",
    "sks", "mosin", "barrett", "musket", "crossbow", "tommy", "magnum", "railgun", "handgun"})
local TRACER_SHOT_SOUNDS = wordSet({"fire", "fired", "shoot", "shot", "shots", "gunshot", "bang", "blast", "pew", "discharge"})
local TRACER_GUN_HINTS = {"ammo", "magazine", "reload", "recoil", "firerate", "fire_rate", "muzzle", "bullet", "shoot", "gunshot"}
-- дульный срез: Attachment или деталь с таким именем
local TRACER_MUZZLE = {"muzzle", "firepoint", "fire_point", "shootpoint", "shoot_point", "barrelend", "barrel_end",
    "bulletspawn", "gunpoint"}
-- звуки, которые не являются выстрелом
local TRACER_SOUND_SKIP = {"reload", "equip", "draw", "empty", "dry", "switch", "walk", "step", "foot", "jump", "land",
    "swing", "impact", "ricochet", "holster", "inspect", "cock", "pump", "hit", "hurt", "click", "echo", "tail", "distant",
    "mech", "bolt", "shell", "casing", "magin", "magout", "mag_in", "mag_out", "zoom", "scope", "spin"}
-- счётчик патронов в магазине: по его уменьшению выстрел виден точнее всего
local TRACER_AMMO = {"ammo", "mag", "clip", "bullet", "round"}
local TRACER_AMMO_SKIP = {"max", "reserve", "spare", "total", "stored", "capacity", "size", "speed", "spread", "damage",
    "range", "time", "drop", "velocity", "cost", "pellet", "recoil"}

local function hasPart(name, list)
    local low = string.lower(name)
    for _, w in ipairs(list) do
        if string.find(low, w, 1, true) then return true end
    end
    return false
end

-- сведения об оружии
local tracerWeapons = setmetatable({}, {__mode = "k"})

local function inspectWeapon(weapon)
    local now = os.clock()
    local info = tracerWeapons[weapon]
    if info and now - info.At < (info.Ranged and 5 or 1) and (not info.Muzzle or info.Muzzle:IsDescendantOf(weapon)) then
        return info
    end
    info = {At = now, Ranged = false, Muzzle = nil}
    tracerWeapons[weapon] = info
    if hasWord(weapon.Name, TRACER_MELEE) then return info end
    local ranged = hasWord(weapon.Name, TRACER_GUN_NAMES) ~= nil
    if not ranged then
        for key in pairs(weapon:GetAttributes()) do
            if hasPart(key, TRACER_GUN_HINTS) then ranged = true break end
        end
    end
    for _, d in ipairs(weapon:GetDescendants()) do
        local n = d.Name
        if not info.Muzzle and (d:IsA("Attachment") or d:IsA("BasePart")) and hasPart(n, TRACER_MUZZLE) then
            info.Muzzle = d
            ranged = true
        elseif not ranged then
            ranged = hasPart(n, TRACER_GUN_HINTS) or hasWord(n, TRACER_GUN_NAMES) ~= nil
                or ((d:IsA("Sound") or d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent")
                    or d:IsA("Animation")) and hasWord(n, TRACER_SHOT_SOUNDS) ~= nil)
        end
        if ranged and info.Muzzle then break end
    end
    info.Ranged = ranged
    return info
end

-- оружие, из которого вы сейчас стреляете
local function currentWeapon()
    local char = M.LP and M.LP.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        return inspectWeapon(tool).Ranged and tool or nil
    end
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    for _, child in ipairs(cam:GetChildren()) do
        if child:IsA("Model") and inspectWeapon(child).Ranged then return child end
    end
    return nil
end

-- начало линии
local function muzzlePosition(weapon, cam, root)
    local muzzle = inspectWeapon(weapon).Muzzle
    if muzzle and muzzle.Parent then
        return muzzle:IsA("Attachment") and muzzle.WorldPosition or muzzle.Position
    end
    if weapon:IsA("Tool") then
        local handle = weapon:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then return handle.Position end
    end
    if cam then return (cam.CFrame * CFrame.new(0.8, -0.7, -2.5)).Position end
    return root and root.Position or nil
end

-- конец линии
local function tracerTarget(cam)
    local aim = M.GetAimPoint(cam)
    local ray = cam:ViewportPointToRay(aim.X, aim.Y)
    local dir = ray.Direction * 1500
    local params, ignore = M.RayParams, nil
    for _ = 1, 4 do
        local hit = workspace:Raycast(ray.Origin, dir, params)
        if not hit then break end
        if hit.Instance.Transparency < 0.9 then return hit.Position end
        if not ignore then
            ignore = table.clone(M.Data.RayIgnoreBase or {})
            params = M.ScratchParams
        end
        ignore[#ignore + 1] = hit.Instance
        params.FilterDescendantsInstances = ignore
    end
    return ray.Origin + ray.Direction * 1000
end

-- клик пришёлся на кнопку или поле ввода интерфейса игры
local function clickOnGameButton(pos)
    local playerGui = M.LP:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return false end
    local ok, list = pcall(function() return playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) end)
    if not ok or not list then return false end
    for _, obj in ipairs(list) do
        if obj:IsA("GuiButton") or obj:IsA("TextBox") then return true end
    end
    return false
end

local function newTracer()
    local part = Instance.new("Part")
    part.Name = M.Services.H:GenerateGUID(false)
    part.Size = Vector3.new(0.05, 0.05, 0.05)
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow, part.Massless = false, false, false, false, true
    local tail = Instance.new("Attachment")
    tail.Parent = part
    local head = Instance.new("Attachment")
    head.Parent = part
    local function beam(zOffset)
        local b = Instance.new("Beam")
        b.Attachment0, b.Attachment1 = tail, head
        b.Segments = 1
        b.FaceCamera = true
        b.LightInfluence = 0
        b.ZOffset = zOffset
        b.Enabled = false
        b.Parent = part
        return b
    end
    local glow = beam(0)
    local core = beam(0.05)  -- сердцевина рисуется поверх свечения
    part.Parent = M.F.Folder("tFolder")
    return {Part = part, Tail = tail, Head = head, Core = core, Glow = glow}
end

-- погасшая линия возвращается в запас
local function releaseTracer(W, t)
    if t.Part.Parent and #W.Pool < TRACER_MAX then
        t.Core.Enabled, t.Glow.Enabled = false, false
        W.Pool[#W.Pool + 1] = t
    else
        t.Part:Destroy()
    end
end

local function takeTracer(W)
    local pool = W.Pool
    while #pool > 0 do
        local t = table.remove(pool)
        if t.Part.Parent then return t end
        t.Part:Destroy()  -- нашу папку удалили вместе с деталью
    end
    local active = M.Data.Tracers
    if #active >= TRACER_MAX then return table.remove(active, 1) end
    return newTracer()
end

-- возвращает true, если линия нарисована
function M.F.FireTracer(weapon)
    local W = M.Data.TracerState
    if not W or M.Run.IsShutDown or not M.State.TracerOn or M.Run.MenuOpen then return false end
    local now = os.clock()
    if now - W.Last < TRACER_MIN_GAP then return false end
    local _, _, root, alive = M.GetSelf()
    local cam = workspace.CurrentCamera
    if not alive or not cam then return false end
    weapon = weapon or currentWeapon()
    if not weapon or not weapon.Parent then return false end
    local origin = muzzlePosition(weapon, cam, root)
    if not origin then return false end
    local target = tracerTarget(cam)
    local dist = (target - origin).Magnitude
    if dist < 3 then return false end
    W.Last = now

    local t = takeTracer(W)
    t.Part.CFrame = CFrame.new(origin)
    t.Tail.WorldPosition = origin
    t.Head.WorldPosition = origin
    t.Origin, t.Target, t.Born, t.Travel = origin, target, now, math.max(dist / TRACER_SPEED, 0.03)
    t.Style = nil
    t.Core.Enabled, t.Glow.Enabled = true, true
    table.insert(M.Data.Tracers, t)
    return true
end

function M.F.UpdateTracers(dt)
    local list, W = M.Data.Tracers, M.Data.TracerState
    if not list or not W then return end
    local now = os.clock()
    local life = math.max(M.State.TracerLength, 0.05)
    local intensity = math.clamp(M.State.TracerIntensity, 0, 1)
    local glow = math.clamp(M.State.TracerGlow, 0, 1)
    local col = M.State.TracerCol
    if W.StyleCol ~= col or W.StyleGlow ~= glow then
        W.StyleCol, W.StyleGlow = col, glow
        W.StyleVer = (W.StyleVer or 0) + 1
        W.GlowSeq = ColorSequence.new(col)
        W.CoreSeq = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.2 * glow))
    end
    local size = math.clamp(tonumber(M.State.TracerSize) or 1, 0.05, 100)
    local thick = (0.6 + 0.4 * intensity) * size
    local haloWidth = (0.25 + 0.6 * glow) * size
    for i = #list, 1, -1 do
        local t = list[i]
        local age = now - t.Born
        if age >= t.Travel + life or not t.Part.Parent then
            table.remove(list, i)
            releaseTracer(W, t)
        else
            local core, aura = t.Core, t.Glow
            if t.Style ~= W.StyleVer then
                t.Style = W.StyleVer
                core.Color, aura.Color = W.CoreSeq, W.GlowSeq
                core.LightEmission = glow
                aura.LightEmission = 1
            end
            t.Head.WorldPosition = t.Origin:Lerp(t.Target, math.min(age / t.Travel, 1))
            local fade = 0.5 + 0.5 * math.cos(math.pi * math.clamp((age - t.Travel) / life, 0, 1))
            local a = intensity * fade
            -- у дула линия бледнее, у головы ярче
            core.Transparency = NumberSequence.new(1 - 0.5 * a, 1 - a)
            aura.Transparency = NumberSequence.new(1 - 0.15 * glow * a, 1 - 0.6 * glow * a)
            local w = 0.14 * thick
            core.Width0, core.Width1 = w * 0.6, w
            aura.Width0, aura.Width1 = haloWidth * 0.5, haloWidth
        end
    end
end

-- имя звука без цифр
local function shotKey(name)
    return (string.gsub(string.lower(name), "%d+", ""))
end

local function isAmmoName(name)
    return hasPart(name, TRACER_AMMO) and not hasPart(name, TRACER_AMMO_SKIP)
end

-- выстрел засчитан: одна линия
local function tracerShot(W, weapon)
    W.LastShotAt = os.clock()
    M.F.FireTracer(weapon)
end

-- кнопка зажата или только что отпущена
local function tracerTriggerHeld(W, now, grace)
    if W.Held and M.Services.U:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return true end
    return now - W.ReleasedAt <= grace or now - W.ClickAt <= grace
end

-- патрон ушёл из магазина
local function onAmmoSpent(W, weapon)
    if M.Data.TracerState ~= W or W.Weapon ~= weapon then return end
    if not tracerTriggerHeld(W, os.clock(), 0.3) then return end
    W.AmmoSeen[weapon] = true
    tracerShot(W, weapon)
end

-- линии по звукам выстрела, если у оружия нет счётчика патронов
local function onWeaponSound(W, sound)
    if M.Data.TracerState ~= W or not W.Weapon or not sound:IsDescendantOf(W.Weapon) then return end
    if W.AmmoSeen[W.Weapon] then return end
    if hasPart(sound.Name, TRACER_SOUND_SKIP) then return end
    local now = os.clock()
    -- один звук может прийти дважды: клон уже играет и сразу получает Play()
    if now - (W.SoundAt[sound] or -10) < 0.05 then return end
    W.SoundAt[sound] = now
    local key = shotKey(sound.Name)
    local isShotName = hasWord(sound.Name, TRACER_SHOT_SOUNDS) ~= nil
    local learned = W.SoundGuns[W.Weapon]
    if learned and key ~= learned.Key then
        -- другой звук того же оружия
        if isShotName and not learned.Shot then
            learned = {Key = key, Shot = true}
            W.SoundGuns[W.Weapon] = learned
        else
            return
        end
    end
    if not tracerTriggerHeld(W, now, 0.12) and now - W.ClickAt > TRACER_CLICK_SOUND then return end
    if not learned then W.SoundGuns[W.Weapon] = {Key = key, Shot = isShotName} end
    tracerShot(W, W.Weapon)
end

-- подписки только на звуки и патроны ТЕКУЩЕГО оружия
local function watchWeapon(W, weapon)
    if W.Weapon == weapon then return end
    for _, conn in ipairs(W.WeaponConns) do conn:Disconnect() end
    table.clear(W.WeaponConns)
    W.Weapon, W.AmmoCount = weapon, 0
    if not weapon then return end
    local conns = W.WeaponConns
    local function hook(d, isNew)
        if d:IsA("Sound") then
            conns[#conns + 1] = d.Played:Connect(function() pcall(onWeaponSound, W, d) end)
            if isNew and d.IsPlaying then pcall(onWeaponSound, W, d) end
        elseif (d:IsA("IntValue") or d:IsA("NumberValue")) and isAmmoName(d.Name) then
            W.AmmoCount = W.AmmoCount + 1
            local last = d.Value
            conns[#conns + 1] = d.Changed:Connect(function()
                local was, value = last, d.Value
                last = value
                if type(value) == "number" and type(was) == "number" and value < was then pcall(onAmmoSpent, W, weapon) end
            end)
        else
            return
        end
        -- игры часто клонируют звук на каждый выстрел
        if #conns > 48 then
            for i = #conns, 1, -1 do
                if not conns[i].Connected then table.remove(conns, i) end
            end
        end
    end
    for _, d in ipairs(weapon:GetDescendants()) do hook(d, false) end
    conns[#conns + 1] = weapon.DescendantAdded:Connect(function(d) hook(d, true) end)
    -- патроны в атрибутах оружия
    local attrs = {}
    for name, value in pairs(weapon:GetAttributes()) do
        if type(value) == "number" and isAmmoName(name) then
            attrs[name] = value
            W.AmmoCount = W.AmmoCount + 1
        end
    end
    conns[#conns + 1] = weapon.AttributeChanged:Connect(function(name)
        local value = weapon:GetAttribute(name)
        if type(value) ~= "number" or not isAmmoName(name) then return end
        local was = attrs[name]
        attrs[name] = value
        if was == nil then
            W.AmmoCount = W.AmmoCount + 1
        elseif value < was then
            pcall(onAmmoSpent, W, weapon)
        end
    end)
end
local function refreshWeapon(W)
    W.RefreshQueued = false
    if M.Data.TracerState ~= W then return end
    watchWeapon(W, currentWeapon())
end

-- предмет мог ещё собираться
local function refreshSoon(W)
    if W.RefreshQueued then return end
    W.RefreshQueued = true
    task.delay(0.2, function() pcall(refreshWeapon, W) end)
end

M.F.DefineModule("Tracers", {
    Wanted = function() return M.State.TracerOn end,
    Load = function()
        local W = {Pool = {}, Conns = {}, CharConns = {}, CamConns = {}, WeaponConns = {}, Weapon = nil, Last = -10,
            ClickAt = -10, Held = false, ReleasedAt = -10, RefreshQueued = false, LastShotAt = -10, AmmoCount = 0,
            SoundAt = setmetatable({}, {__mode = "k"})}
        -- какое оружие каким звуком стреляет и у какого замечен расход патронов
        M.Data.TracerSoundGuns = M.Data.TracerSoundGuns or setmetatable({}, {__mode = "k"})
        M.Data.TracerAmmoGuns = M.Data.TracerAmmoGuns or setmetatable({}, {__mode = "k"})
        W.SoundGuns, W.AmmoSeen = M.Data.TracerSoundGuns, M.Data.TracerAmmoGuns
        M.Data.TracerState = W
        M.Data.Tracers = {}
        local U = M.Services.U

        local function clearList(list)
            for _, conn in ipairs(list) do conn:Disconnect() end
            table.clear(list)
        end
        local function hookCharacter(char)
            clearList(W.CharConns)
            if char then
                W.CharConns[1] = char.ChildAdded:Connect(function(c) if c:IsA("Tool") then refreshSoon(W) end end)
                W.CharConns[2] = char.ChildRemoved:Connect(function(c) if c:IsA("Tool") then refreshSoon(W) end end)
            end
            refreshSoon(W)
        end
        local function hookCamera()
            clearList(W.CamConns)
            local cam = workspace.CurrentCamera
            if cam then
                W.CamConns[1] = cam.ChildAdded:Connect(function(c) if c:IsA("Model") then refreshSoon(W) end end)
                W.CamConns[2] = cam.ChildRemoved:Connect(function(c) if c:IsA("Model") then refreshSoon(W) end end)
            end
            refreshSoon(W)
        end
        hookCharacter(M.LP.Character)
        hookCamera()
        local conns = W.Conns
        conns[#conns + 1] = M.LP.CharacterAdded:Connect(hookCharacter)
        conns[#conns + 1] = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)

        conns[#conns + 1] = U.InputBegan:Connect(function(inp, processed)
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if M.Run.MenuOpen or U:GetFocusedTextBox() then return end
            if processed and clickOnGameButton(inp.Position) then return end
            W.Held = true
            pcall(refreshWeapon, W)
            if not W.Weapon then return end
            local at, weapon = os.clock(), W.Weapon
            W.ClickAt = at
            -- у тихого оружия без счётчика патронов след рисуется по щелчку, если звук выстрела так и не пришёл
            if not W.SoundGuns[weapon] and not W.AmmoSeen[weapon] and W.AmmoCount == 0 then
                task.delay(0.15, function()
                    if M.Data.TracerState ~= W or W.Weapon ~= weapon or W.LastShotAt >= at then return end
                    if W.SoundGuns[weapon] or W.AmmoSeen[weapon] then return end
                    tracerShot(W, weapon)
                end)
            end
        end)
        conns[#conns + 1] = U.InputEnded:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if W.Held then W.ReleasedAt = os.clock() end
            W.Held = false
        end)
        conns[#conns + 1] = U.WindowFocusReleased:Connect(function() W.Held = false end)
    end,
    Unload = function()
        local W = M.Data.TracerState
        M.Data.TracerState = nil
        if W then
            for _, list in ipairs({W.Conns, W.CharConns, W.CamConns, W.WeaponConns}) do
                for _, conn in ipairs(list) do conn:Disconnect() end
            end
            for _, t in ipairs(W.Pool) do t.Part:Destroy() end
        end
        for _, t in ipairs(M.Data.Tracers or {}) do t.Part:Destroy() end
        M.Data.Tracers = nil
    end
})
end

end}

-- [52/69] Шлейф за персонажем
MODULES[#MODULES + 1] = {"52. Шлейф за персонажем", function(M, __X)
-- ==============================================================================
-- [ ШЛЕЙФ ЗА ПЕРСОНАЖЕМ ]
-- ==============================================================================
local TRAIL_TOP, TRAIL_BOTTOM = 1.1, -1.5
local TRAIL_EDGE = 0.07  -- половина толщины кромки

local function trailSequence(points)
    local keys = {}
    for i, p in ipairs(points) do keys[i] = NumberSequenceKeypoint.new(p[1], math.clamp(p[2], 0, 1)) end
    return NumberSequence.new(keys)
end

M.F.DefineModule("CharTrail", {
    Wanted = function() return M.State.TrailOn end,
    Load = function()
        local part = Instance.new("Part")
        part.Name = M.Services.H:GenerateGUID(false)
        part.Size = Vector3.new(0.1, 0.1, 0.1)
        part.Transparency = 1
        part.Anchored = true
        part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow, part.Massless = false, false, false, false, true

        local function point(y)
            local a = Instance.new("Attachment")
            a.Position = Vector3.new(0, y, 0)
            a.Parent = part
            return a
        end
        local function trail(top, bottom, faceCamera)
            local tr = Instance.new("Trail")
            tr.Attachment0, tr.Attachment1 = point(top), point(bottom)
            tr.FaceCamera = faceCamera
            tr.LightInfluence = 0
            tr.MinLength = 0.1
            tr.MaxLength = 0
            tr.Enabled = false
            tr.Parent = part
            return tr
        end
        local ribbon = trail(TRAIL_TOP, TRAIL_BOTTOM, false)
        local upper = trail(TRAIL_TOP + TRAIL_EDGE, TRAIL_TOP - TRAIL_EDGE, true)
        local lower = trail(TRAIL_BOTTOM + TRAIL_EDGE, TRAIL_BOTTOM - TRAIL_EDGE, true)
        part.Parent = M.F.Folder("tFolder")
        M.UI.Trail = {Part = part, Ribbon = ribbon, Edges = {upper, lower}, All = {ribbon, upper, lower}, On = false, Reset = true}
        M.F.StyleTrail()
    end,
    Unload = function()
        if M.UI.Trail and M.UI.Trail.Part then M.UI.Trail.Part:Destroy() end
        M.UI.Trail = nil
    end
})

function M.F.StyleTrail()
    local o = M.UI.Trail
    if not o then return end
    local col = M.State.TrailCol
    local intensity = math.clamp(M.State.TrailIntensity, 0, 1)
    local glow = math.clamp(M.State.TrailGlow, 0, 1)
    local life = math.clamp(M.State.TrailLength, 0.1, 30)
    local white = Color3.new(1, 1, 1)

    local ribbon = o.Ribbon
    ribbon.Lifetime = life
    ribbon.LightEmission = glow
    ribbon.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, col:Lerp(white, 0.25 + 0.25 * glow)),
        ColorSequenceKeypoint.new(0.45, col),
        ColorSequenceKeypoint.new(1, col:Lerp(Color3.new(0, 0, 0), 0.2)),
    })
    ribbon.Transparency = trailSequence({{0, 1 - 0.5 * intensity}, {0.3, 1 - 0.38 * intensity}, {0.75, 1 - 0.12 * intensity}, {1, 1}})
    ribbon.WidthScale = trailSequence({{0, 1}, {0.5, 0.7}, {1, 0.2}})

    for _, edge in ipairs(o.Edges) do
        edge.Lifetime = life * 0.8
        edge.LightEmission = glow
        edge.Color = ColorSequence.new(col:Lerp(white, 0.3 + 0.4 * glow), col)
        edge.Transparency = trailSequence({{0, 1 - intensity}, {0.6, 1 - 0.55 * intensity}, {1, 1}})
        edge.WidthScale = trailSequence({{0, 1}, {1, 0.25}})
    end
end

function M.F.UpdateCharTrail(dt)
    local o = M.UI.Trail
    if not o or not o.Part.Parent then return end
    local S = M.State
    if o.SigCol ~= S.TrailCol or o.SigI ~= S.TrailIntensity or o.SigG ~= S.TrailGlow or o.SigL ~= S.TrailLength then
        o.SigCol, o.SigI, o.SigG, o.SigL = S.TrailCol, S.TrailIntensity, S.TrailGlow, S.TrailLength
        M.F.StyleTrail()
    end
    local function enable(on)
        if o.On == on then return end
        o.On = on
        for _, tr in ipairs(o.All) do tr.Enabled = on end
    end
    local char, _, root, alive = M.GetSelf()
    if not root or not alive then
        enable(false)
        o.Reset = true
        return
    end
    local pos = root.Position
    -- телепорт или возрождение
    if o.Last and (pos - o.Last).Magnitude > 40 then o.Reset = true end
    o.Last = pos
    o.Part.CFrame = CFrame.new(pos)
    -- от первого лица
    local cam = workspace.CurrentCamera
    local head = M.GetHead(char)
    if cam and head and (cam.CFrame.Position - head.Position).Magnitude < 1.2 then
        enable(false)
        o.Reset = true
        return
    end
    if o.Reset then
        -- кадр сброса
        enable(false)
        for _, tr in ipairs(o.All) do pcall(tr.Clear, tr) end
        o.Reset = false
    else
        enable(true)
    end
end

end}

-- [53/69] Эффект убийства
MODULES[#MODULES + 1] = {"53. Эффект убийства", function(M, __X)
-- ==============================================================================
-- [ ЭФФЕКТ УБИЙСТВА ]
-- ==============================================================================
local KILLFX_MAX = 5

M.F.DefineModule("KillFx", {
    Wanted = function() return M.State.KillFxOn end,
    Load = function()
        local conns = {}
        local hooked = setmetatable({}, {__mode = "k"})
        M.Data.KillFxConns = conns
        M.Data.KillFxDone = setmetatable({}, {__mode = "k"})
        M.Data.KillFxLive = 0
        -- на каждый Humanoid карты (игроки, боты, манекены, свой персонаж): так не зависит от того, как игра создаёт персонажей
        local function hook(inst)
            if inst.ClassName ~= "Humanoid" or hooked[inst] then return end
            local char = inst.Parent
            if not char or not char:IsA("Model") then return end
            hooked[inst] = true
            -- игра может убрать персонажа сразу после смерти, поэтому место запоминается заранее
            local lastPos
            local function remember()
                local root = M.GetRoot(char)
                if root and root.Parent then lastPos = root.Position end
            end
            remember()
            local own = {}
            local function release()
                for _, c in ipairs(own) do pcall(function() c:Disconnect() end) end
                table.clear(own)
            end
            local function died()
                if not M.Modules.KillFx.Loaded or M.Data.KillFxConns ~= conns then return end
                release()
                M.F.PlayKillFx(char, lastPos)
            end
            own[1] = inst.Died:Connect(died)
            own[2] = inst.HealthChanged:Connect(function(health)
                if health <= 0 then died() else remember() end
            end)
            own[3] = inst.AncestryChanged:Connect(function()
                if not inst:IsDescendantOf(workspace) then release() end
            end)
            for _, c in ipairs(own) do conns[#conns + 1] = c end
            if #conns > 200 then
                for i = #conns, 1, -1 do
                    if not conns[i].Connected then table.remove(conns, i) end
                end
            end
        end
        conns[#conns + 1] = workspace.DescendantAdded:Connect(hook)
        task.spawn(function()
            M.F.SliceWalk(workspace, hook, function() return M.Modules.KillFx.Loaded and M.Data.KillFxConns == conns end)
        end)
    end,
    Unload = function()
        for _, conn in ipairs(M.Data.KillFxConns or {}) do pcall(function() conn:Disconnect() end) end
        M.Data.KillFxConns, M.Data.KillFxDone = nil, nil
    end
})
-- облако частиц, поднимающееся вверх
local function killFxCloud(host, speed)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(M.State.KillFxColor)
    emitter.LightEmission = 1
    emitter.LightInfluence = 0
    emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.38), NumberSequenceKeypoint.new(1, 0)})
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.65, 0.3), NumberSequenceKeypoint.new(1, 1)
    })
    emitter.Lifetime = NumberRange.new(2.4, 3.6)
    emitter.Speed = NumberRange.new(speed * 0.6, speed)
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.SpreadAngle = Vector2.new(22, 22)
    emitter.Acceleration = Vector3.new(0, 1.2, 0)
    emitter.Drag = 0.6
    emitter.Rotation = NumberRange.new(0, 360)
    emitter.RotSpeed = NumberRange.new(-70, 70)
    -- при просадке FPS частиц меньше
    emitter.Rate = math.floor(110 * math.clamp((M.Data.Quality or 1) * M.F.VisualK(), 0.2, 1))
    pcall(function()
        emitter.Shape = Enum.ParticleEmitterShape.Box
        emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    end)
    emitter.Parent = host
    task.delay(1.7, function()
        if emitter.Parent then emitter.Enabled = false end
    end)
    M.Services.D:AddItem(host, 7)
end

-- искры: вспышка, выброс раскалённых длинных искр во все стороны и медленно оседающие угольки
local function killFxSparks(host, speed)
    local col = M.State.KillFxColor
    local white = Color3.new(1, 1, 1)
    local k = math.clamp((M.Data.Quality or 1) * M.F.VisualK(), 0.25, 1)
    local function emitter(props)
        local e = Instance.new("ParticleEmitter")
        e.Rate = 0
        e.LightInfluence = 0
        e.LightEmission = 1
        e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        e.EmissionDirection = Enum.NormalId.Top
        for prop, value in pairs(props) do pcall(function() e[prop] = value end) end
        e.Parent = host
        return e
    end

    -- искры: у вылета белые, остывая уходят в цвет темы и темнеют; вытянуты вдоль полёта
    local streaks = emitter({
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, white),
            ColorSequenceKeypoint.new(0.18, col:Lerp(white, 0.55)),
            ColorSequenceKeypoint.new(0.6, col),
            ColorSequenceKeypoint.new(1, col:Lerp(Color3.new(0, 0, 0), 0.5))
        }),
        Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.42), NumberSequenceKeypoint.new(0.5, 0.26), NumberSequenceKeypoint.new(1, 0.04)}),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.1), NumberSequenceKeypoint.new(1, 1)
        }),
        Lifetime = NumberRange.new(2, 3.4),
        Speed = NumberRange.new(speed * 1.2, speed * 3.4),
        SpreadAngle = Vector2.new(180, 180),
        Acceleration = Vector3.new(0, -6, 0),
        Drag = 0.1,
        Orientation = Enum.ParticleOrientation.VelocityParallel,
        Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, -3.2), NumberSequenceKeypoint.new(1, -1.6)}),
        Brightness = 3,
        Shape = Enum.ParticleEmitterShape.Sphere,
        ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
    })
    -- угольки: мельче, медленнее, живут дольше и мерцают
    local embers = emitter({
        Color = ColorSequence.new(col:Lerp(white, 0.35), col),
        Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0)}),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.15, 0.45), NumberSequenceKeypoint.new(0.3, 0.05),
            NumberSequenceKeypoint.new(0.45, 0.5), NumberSequenceKeypoint.new(0.6, 0.1), NumberSequenceKeypoint.new(0.8, 0.55),
            NumberSequenceKeypoint.new(1, 1)
        }),
        Lifetime = NumberRange.new(3.2, 5),
        Speed = NumberRange.new(speed * 0.4, speed * 1.4),
        SpreadAngle = Vector2.new(180, 180),
        Acceleration = Vector3.new(0, -1.5, 0),
        Drag = 0.7,
        Rotation = NumberRange.new(0, 360),
        RotSpeed = NumberRange.new(-120, 120),
        Brightness = 2,
        Shape = Enum.ParticleEmitterShape.Sphere,
        ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
    })
    -- вспышка в центре
    local flash = emitter({
        Color = ColorSequence.new(col:Lerp(white, 0.6)),
        Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(0.3, 4.2), NumberSequenceKeypoint.new(1, 0)}),
        Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)}),
        Lifetime = NumberRange.new(0.35, 0.35),
        Speed = NumberRange.new(0, 0),
        LockedToPart = true,
        Brightness = 4,
    })
    -- частиц немного: в бою смертей много, а каждая вспышка частиц нагружает видеокарту
    flash:Emit(1)
    streaks:Emit(math.floor(72 * k))
    embers:Emit(math.floor(24 * k))
    -- вторая волна угольков чуть позже: взрыв выглядит объёмнее
    task.delay(0.12, function()
        if embers.Parent then embers:Emit(math.floor(16 * k)) end
    end)
    -- короткий свет на окружение
    local light = Instance.new("PointLight")
    light.Color = col
    light.Range = 16
    light.Brightness = 6
    light.Shadows = false
    light.Parent = host
    M.Services.T:Create(light, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = 0, Range = 6}):Play()
    M.Services.D:AddItem(host, 6)
end
function M.F.PlayKillFx(char, lastPos)
    if M.Run.IsShutDown or not M.State.KillFxOn or not char then return end
    local done = M.Data.KillFxDone
    if not done or done[char] then return end
    local root = M.GetRoot(char)
    local pos = (root and root.Parent) and root.Position or lastPos
    if not pos then return end
    done[char] = true
    -- дальность прорисовки ESP действует и здесь
    local viewCam = workspace.CurrentCamera
    if viewCam and char ~= M.LP.Character and (viewCam.CFrame.Position - pos).Magnitude > M.State.PlayerViewMaxDist then return end
    if (M.Data.KillFxLive or 0) >= KILLFX_MAX then return end
    M.Data.KillFxLive = (M.Data.KillFxLive or 0) + 1
    task.delay(7, function() M.Data.KillFxLive = math.max((M.Data.KillFxLive or 1) - 1, 0) end)

    local host = Instance.new("Part")
    host.Name = M.Services.H:GenerateGUID(false)
    host.Size = Vector3.new(2.4, 4.6, 1.6)
    host.Transparency = 1
    host.Anchored = true
    host.CanCollide, host.CanQuery, host.CanTouch, host.CastShadow, host.Massless = false, false, false, false, true
    host.CFrame = CFrame.new(pos)
    host.Parent = M.F.Folder("fFolder")

    local speed = math.clamp(M.State.KillFxSpeed, 0.5, 200)
    if M.State.KillFxType == "Sparks" then killFxSparks(host, speed) else killFxCloud(host, speed) end

    -- растворение модели, если она ещё на месте
    if char.Parent then
        local info = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and d ~= root then
                if d.Transparency < 1 then M.Services.T:Create(d, info, {Transparency = 1}):Play() end
            elseif d:IsA("Decal") or d:IsA("Texture") then
                if d.Transparency < 1 then M.Services.T:Create(d, info, {Transparency = 1}):Play() end
            end
        end
    end
end

-- main Frame Component
M.UI.Main = Instance.new("Frame", M.UI.Gui)
M.UI.Main.Size = UDim2.new(0, 710, 0, 490); M.UI.Main.Position = UDim2.new(0.5, -355, 0.5, -245)
M.UI.Main.BackgroundColor3 = M.State.MainBg; M.UI.Main.BackgroundTransparency = 1; M.UI.Main.Active = true
Instance.new("UICorner", M.UI.Main).CornerRadius = UDim.new(0, 14); M.UI.MainScale = Instance.new("UIScale", M.UI.Main)
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

-- кнопки окна
local function windowButton(text, textSize, hoverColor, hoverText)
    local button = Instance.new("TextButton", M.UI.TopControls)
    button.Size = UDim2.new(0, 26, 0, 26)
    button.BackgroundColor3 = M.Style.Raised
    button.BackgroundTransparency = 0.15
    button.AutoButtonColor = false
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = M.Style.TextDim
    button.Font = Enum.Font.GothamBold
    button.TextSize = textSize
    button.ZIndex = 26
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
    local stroke = M.Style.AddStroke(button, M.Style.Stroke, 1, M.Style.StrokeIdle)
    local scale = Instance.new("UIScale", button)
    button.MouseEnter:Connect(function()
        M.Style.Tween(button, 0.18, {BackgroundColor3 = hoverColor(), TextColor3 = hoverText()})
        M.Style.Tween(stroke, 0.18, {Color = hoverText(), Transparency = M.Style.StrokeActive})
    end)
    button.MouseLeave:Connect(function()
        M.Style.Tween(button, 0.25, {BackgroundColor3 = M.Style.Raised, TextColor3 = M.Style.TextDim})
        M.Style.Tween(stroke, 0.25, {Color = M.Style.Stroke, Transparency = 0.3})
        M.Style.Tween(scale, 0.2, {Scale = 1})
    end)
    button.MouseButton1Down:Connect(function() M.Style.Tween(scale, 0.1, {Scale = 0.9}) end)
    button.MouseButton1Up:Connect(function() M.Style.Tween(scale, 0.3, {Scale = 1}, Enum.EasingStyle.Back) end)
    return button
end

M.UI.BtnCollapse = windowButton("–", 14,
    function() return M.State.Accent:Lerp(M.Style.Raised, 0.78) end,
    function() return M.Style.AccentMix(0.5) end)
M.UI.BtnCollapse.MouseButton1Click:Connect(function() M.F.CloseMenu() end)

M.UI.BtnShutDown = windowButton("X", 12,
    function() return M.Style.Danger:Lerp(M.Style.Raised, 0.72) end,
    function() return M.Style.Danger end)
M.UI.BtnShutDown.MouseButton1Click:Connect(function() M.F.Confirm("exit") end)

do
    local dragStart, startPos, isDragging = nil, nil, false
    local targetX, targetY, curX, curY = 0, 0, 0, 0
    local smoothConn
    local function stopSmooth()
        if smoothConn then M.F.Untrack(smoothConn); smoothConn = nil end
    end
    local function startSmooth()
        if smoothConn then return end
        smoothConn = M.Track(M.Services.R.RenderStepped:Connect(function(dt)
            local blend = 1 - math.exp(-dt * 18 / M.Style.Scale())
            curX = curX + (targetX - curX) * blend
            curY = curY + (targetY - curY) * blend
            if not isDragging and math.abs(targetX - curX) < 0.3 and math.abs(targetY - curY) < 0.3 then
                M.UI.Main.Position = UDim2.new(startPos.X.Scale, targetX, startPos.Y.Scale, targetY)
                stopSmooth()
            else
                M.UI.Main.Position = UDim2.new(startPos.X.Scale, curX, startPos.Y.Scale, curY)
            end
        end))
    end
    M.UI.Main.InputBegan:Connect(function(inp)
        if (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) and inp.Position.Y < M.UI.Main.AbsolutePosition.Y + 45 and not M.Data.SearchHover then
            isDragging = true; dragStart = inp.Position; startPos = M.UI.Main.Position
            curX, curY = startPos.X.Offset, startPos.Y.Offset
            targetX, targetY = curX, curY
            startSmooth()
        end
    end)
    M.Conn(M.Services.U.InputChanged, function(inp)
        if isDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            targetX, targetY = startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y
        end
    end)
    M.Conn(M.Services.U.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then isDragging = false end
    end)

    local isResizing, resizeStart, startSize = false, nil, nil
    local sizeTarget, sizeCurrent = Vector2.zero, Vector2.zero
    local resizeConn
    local resizeHandle = Instance.new("TextButton", M.UI.Main)
    resizeHandle.Size = UDim2.new(0, 16, 0, 16); resizeHandle.Position = UDim2.new(1, -13, 1, -13); resizeHandle.BackgroundTransparency = 1
    resizeHandle.Text = "◢"; resizeHandle.TextSize = 14; resizeHandle.Font = Enum.Font.GothamBold; resizeHandle.TextColor3 = M.Style.TextMute
    resizeHandle.MouseEnter:Connect(function() M.Style.Tween(resizeHandle, 0.2, {TextColor3 = M.Style.AccentMix(0.3)}) end)
    resizeHandle.MouseLeave:Connect(function()
        if not isResizing then M.Style.Tween(resizeHandle, 0.25, {TextColor3 = M.Style.TextMute}) end
    end)

    local function stopResize()
        if resizeConn then M.F.Untrack(resizeConn); resizeConn = nil end
    end
    local function startResize()
        if resizeConn then return end
        resizeConn = M.Track(M.Services.R.RenderStepped:Connect(function(dt)
            local blend = 1 - math.exp(-dt * 16 / M.Style.Scale())
            sizeCurrent = sizeCurrent:Lerp(sizeTarget, blend)
            if not isResizing and (sizeTarget - sizeCurrent).Magnitude < 0.4 then
                M.UI.Main.Size = UDim2.new(0, sizeTarget.X, 0, sizeTarget.Y)
                stopResize()
                task.defer(M.F.RefitAll)
                M.Style.Tween(resizeHandle, 0.25, {TextColor3 = M.Style.TextMute})
            else
                M.UI.Main.Size = UDim2.new(0, sizeCurrent.X, 0, sizeCurrent.Y)
            end
        end))
    end

    resizeHandle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            isResizing = true; resizeStart = inp.Position; startSize = Vector2.new(M.UI.Main.Size.X.Offset, M.UI.Main.Size.Y.Offset)
            sizeTarget, sizeCurrent = startSize, startSize
            M.Style.Tween(resizeHandle, 0.15, {TextColor3 = M.Style.AccentMix(0.6)})
            startResize()
        end
    end)
    M.Conn(M.Services.U.InputChanged, function(inp)
        if isResizing and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - resizeStart
            sizeTarget = Vector2.new(math.clamp(startSize.X + d.X, 600, 960), math.clamp(startSize.Y + d.Y, 420, 760))
        end
    end)
    M.Conn(M.Services.U.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then isResizing = false end
    end)
end

M.UI.Sidebar = Instance.new("Frame", M.UI.Main)
M.UI.Sidebar.Size = UDim2.new(0.25, 0, 1, 0); M.UI.Sidebar.BackgroundColor3 = M.State.SideBg; M.UI.Sidebar.BackgroundTransparency = M.State.SideAlpha; M.UI.Sidebar.BorderSizePixel = 0
Instance.new("UICorner", M.UI.Sidebar).CornerRadius = UDim.new(0, 14)
M.UI.SideStroke = Instance.new("UIStroke", M.UI.Sidebar); M.UI.SideStroke.Color = M.State.BorderCol; M.UI.SideStroke.Thickness = M.State.BorderThick

M.UI.LogoCard = Instance.new("Frame", M.UI.Sidebar)
M.UI.LogoCard.Size = UDim2.new(1, -16, 0, 42); M.UI.LogoCard.Position = UDim2.new(0, 8, 0, 12)
M.UI.LogoCard.BackgroundColor3 = M.State.SideCardBg; M.UI.LogoCard.BackgroundTransparency = M.State.SideCardAlpha; M.UI.LogoCard.BorderSizePixel = 0
Instance.new("UICorner", M.UI.LogoCard).CornerRadius = UDim.new(0, 10); table.insert(M.UI.SideCards, M.UI.LogoCard)
M.Style.AddStroke(M.UI.LogoCard, M.Style.Stroke, 1, M.Style.StrokeIdle)

M.UI.Logo = Instance.new("TextLabel", M.UI.LogoCard)
M.UI.Logo.Size = UDim2.new(1, 0, 1, 0); M.UI.Logo.BackgroundTransparency = 1
M.UI.Logo.Text = "matsysense"; M.UI.Logo.TextColor3 = M.State.LogoCol; M.UI.Logo.Font = Enum.Font.GothamBlack; M.UI.Logo.TextSize = 20
-- очень слабое свечение вокруг букв
M.UI.LogoGlow = Instance.new("UIStroke", M.UI.Logo)
M.UI.LogoGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
M.UI.LogoGlow.Thickness = 2.5
M.UI.LogoGlow.Transparency = 0.9
M.Style.Bind(M.UI.LogoGlow, "Color")
M.UI.LogoGrad = Instance.new("UIGradient", M.UI.Logo)
M.UI.LogoGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 156, 178)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 156, 178))
})
M.UI.LogoGrad.Rotation = 45; M.UI.LogoGrad.Offset = Vector2.new(-1, 0)

task.spawn(function()
    while task.wait(3.0) do
        if M.Run.IsShutDown then break end
        if M.Run.MenuOpen and M.UI.LogoGrad and M.UI.LogoGrad.Parent then
            M.Services.T:Create(M.UI.LogoGrad, TweenInfo.new(2.2, Enum.EasingStyle.Linear), {Offset = Vector2.new(1, 0)}):Play()
            task.wait(2.3)
            if M.UI.LogoGrad and M.UI.LogoGrad.Parent then M.UI.LogoGrad.Offset = Vector2.new(-1, 0) end
        end
    end
end)

end}

-- [54/69] Построение меню: страницы и вкладки
MODULES[#MODULES + 1] = {"54. Построение меню: страницы и вкладки", function(M, __X)
M.UI.ProfileCard = Instance.new("Frame", M.UI.Sidebar)
M.UI.ProfileCard.Size = UDim2.new(1, -16, 0, 52); M.UI.ProfileCard.Position = UDim2.new(0, 8, 1, -60)
M.UI.ProfileCard.BackgroundColor3 = M.State.SideCardBg; M.UI.ProfileCard.BackgroundTransparency = M.State.SideCardAlpha; M.UI.ProfileCard.BorderSizePixel = 0
Instance.new("UICorner", M.UI.ProfileCard).CornerRadius = UDim.new(0, 10); table.insert(M.UI.SideCards, M.UI.ProfileCard)
M.Style.AddStroke(M.UI.ProfileCard, M.Style.Stroke, 1, M.Style.StrokeIdle)

M.UI.Avatar = M.F.NewAvatarView(M.UI.ProfileCard)
M.UI.Avatar.Size = UDim2.new(0, 36, 0, 36); M.UI.Avatar.Position = UDim2.new(0, 8, 0.5, -18)

M.UI.PName = Instance.new("TextLabel", M.UI.ProfileCard)
M.UI.PName.Size = UDim2.new(1, -54, 0, 16); M.UI.PName.Position = UDim2.new(0, 50, 0, 10); M.UI.PName.BackgroundTransparency = 1
M.UI.PName.Text = M.LP.Name; M.UI.PName.TextColor3 = M.Style.Text; M.UI.PName.Font = Enum.Font.GothamBold; M.UI.PName.TextSize = 12; M.UI.PName.TextXAlignment = Enum.TextXAlignment.Left
M.UI.PName.TextTruncate = Enum.TextTruncate.AtEnd

M.UI.PUptime = Instance.new("TextLabel", M.UI.ProfileCard)
M.UI.PUptime.Size = UDim2.new(1, -54, 0, 14); M.UI.PUptime.Position = UDim2.new(0, 50, 0, 26); M.UI.PUptime.BackgroundTransparency = 1
M.UI.PUptime.TextColor3 = M.Style.TextMute; M.UI.PUptime.Font = Enum.Font.Gotham; M.UI.PUptime.TextSize = 11; M.UI.PUptime.TextXAlignment = Enum.TextXAlignment.Left

-- список вкладок
M.UI.TabContainer = Instance.new("ScrollingFrame", M.UI.Sidebar)
M.UI.TabContainer.Size = UDim2.new(1, 0, 1, -141); M.UI.TabContainer.Position = UDim2.new(0, 0, 0, 62); M.UI.TabContainer.BackgroundTransparency = 1
M.UI.TabContainer.BorderSizePixel = 0; M.UI.TabContainer.ScrollBarThickness = 0
M.UI.TabContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y; M.UI.TabContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
M.UI.TabContainer.ScrollingDirection = Enum.ScrollingDirection.Y
local tLayout = Instance.new("UIListLayout", M.UI.TabContainer); tLayout.Padding = UDim.new(0, 4); tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local tabPad = Instance.new("UIPadding", M.UI.TabContainer); tabPad.PaddingTop = UDim.new(0, 2); tabPad.PaddingBottom = UDim.new(0, 2)

M.UI.ContentArea = Instance.new("Frame", M.UI.Main)
M.UI.ContentArea.Size = UDim2.new(0.75, 0, 1, -44)
M.UI.ContentArea.Position = UDim2.new(0.25, 0, 0, 40)
M.UI.ContentArea.BackgroundTransparency = 1

-- прокрутка перетаскиванием
do
    local inertiaConn
    local function stopInertia()
        if inertiaConn then M.F.Untrack(inertiaConn); inertiaConn = nil end
    end
    local function maxCanvas(sf)
        return math.max(sf.AbsoluteCanvasSize.Y - sf.AbsoluteWindowSize.Y, 0)
    end

    function M.F.BeginPageDrag(sf, inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        if M.Data.DragHandler or M.Run.ListeningBind then return end
        if inp.Position.X >= sf.AbsolutePosition.X + sf.AbsoluteSize.X - (sf.ScrollBarThickness + 10) then return end
        stopInertia()
        M.Data.PageDrag = {Frame = sf, StartY = inp.Position.Y, StartCanvas = sf.CanvasPosition.Y,
            LastY = inp.Position.Y, LastT = os.clock(), Velocity = 0, Moving = false}
    end

    M.Conn(M.Services.U.InputChanged, function(inp)
        local drag = M.Data.PageDrag
        if not drag or (inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch) then return end
        if M.Data.DragHandler then M.Data.PageDrag = nil return end
        local sf = drag.Frame
        if not sf.Parent or not sf.Visible then M.Data.PageDrag = nil return end
        local dy = inp.Position.Y - drag.StartY
        if not drag.Moving and math.abs(dy) > 5 then drag.Moving = true end
        if not drag.Moving then return end
        local now = os.clock()
        local dt = now - drag.LastT
        if dt > 0 then
            drag.Velocity = drag.Velocity * 0.6 + ((inp.Position.Y - drag.LastY) / dt) * 0.4
        end
        drag.LastY, drag.LastT = inp.Position.Y, now
        sf.CanvasPosition = Vector2.new(0, math.clamp(drag.StartCanvas - dy, 0, maxCanvas(sf)))
    end)

    M.Conn(M.Services.U.InputEnded, function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local drag = M.Data.PageDrag
        M.Data.PageDrag = nil
        if not drag or not drag.Moving then return end
        local velocity = (os.clock() - drag.LastT > 0.08) and 0 or -drag.Velocity
        if math.abs(velocity) < 40 then return end
        local sf = drag.Frame
        inertiaConn = M.Services.R.Heartbeat:Connect(function(dt)
            if not sf.Parent or not sf.Visible then stopInertia() return end
            velocity = velocity * math.exp(-dt * 4.5)
            local y = math.clamp(sf.CanvasPosition.Y + velocity * dt, 0, maxCanvas(sf))
            sf.CanvasPosition = Vector2.new(0, y)
            if math.abs(velocity) < 8 or y <= 0 or y >= maxCanvas(sf) then stopInertia() end
        end)
        M.Track(inertiaConn)
    end)
end

-- подгоняет надпись под её рамку
-- сжимается только надпись, которая не помещается: TextScaled дорог при каждой перекладке
M.Data.FitSet = setmetatable({}, {__mode = "k"})
function M.F.FitText(obj, minSize)
    if not obj then return end
    local set = M.Data.FitSet
    local info = set[obj]
    if not info then
        if obj.TextScaled then return end
        info = {Size = math.max(obj.TextSize, 1), Min = minSize or 8, Wrapped = obj.TextWrapped}
        set[obj] = info
    end
    M.F.Refit(obj)
end

-- ширина текста при обычном размере или nil, если измерить нельзя
function M.F.TextWidth(obj, size)
    local svc = M.Services.Text
    if not svc then return nil end
    local ok, bounds = pcall(function() return svc:GetTextSize(obj.Text, size, obj.Font, Vector2.new(100000, 100000)) end)
    if ok and typeof(bounds) == "Vector2" then return bounds.X end
    return nil
end

function M.F.Refit(obj)
    local info = M.Data.FitSet[obj]
    if not info or not obj.Parent then return end
    info.Text = obj.Text
    local width = obj.AbsoluteSize.X
    local pad = obj:FindFirstChildOfClass("UIPadding")
    if pad then width = width - pad.PaddingLeft.Offset - pad.PaddingRight.Offset end
    local need = width > 4 and M.F.TextWidth(obj, info.Size) or nil
    info.Pending = need == nil
    if need and need <= width - 2 then
        if obj.TextScaled then
            obj.TextScaled = false
            obj.TextWrapped = info.Wrapped
            obj.TextSize = info.Size
        end
        return
    end
    -- не помещается или не измерить: сжимаем ограничением размера
    local constraint = obj:FindFirstChildOfClass("UITextSizeConstraint")
    if not constraint then
        constraint = Instance.new("UITextSizeConstraint")
        constraint.Parent = obj
    end
    constraint.MinTextSize = 1
    constraint.MaxTextSize = info.Size
    constraint.MinTextSize = math.min(info.Min, info.Size)
    obj.TextWrapped = true
    obj.TextScaled = true
end

-- после смены шрифта, размера окна или показа страницы
function M.F.RefitAll(onlyPending)
    for obj, info in pairs(M.Data.FitSet) do
        if not onlyPending or info.Pending then M.F.Refit(obj) end
    end
end

-- надписи, у которых сменился текст (подписок на каждую надпись нет)
function M.F.RefitChanged()
    for obj, info in pairs(M.Data.FitSet) do
        if obj.Parent and obj.Text ~= info.Text then M.F.Refit(obj) end
    end
end

function M.F.CreatePage(name)
    local sf = Instance.new("ScrollingFrame", M.UI.ContentArea)
    sf.InputBegan:Connect(function(inp) M.F.BeginPageDrag(sf, inp) end)
    sf.Size = UDim2.new(1, -16, 1, -10)
    sf.Position = UDim2.new(0, 8, 0, 6)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 5
    sf.ScrollBarImageColor3 = Color3.fromRGB(70, 78, 104)
    sf.ScrollBarImageTransparency = 0.2
    sf.AutomaticCanvasSize = Enum.AutomaticSize.None
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.Visible = false
    sf.CanvasPosition = Vector2.zero

    local container = Instance.new("Frame", sf)
    container.Size = UDim2.new(1, -12, 0, 0)
    container.BackgroundTransparency = 1
    container.DescendantAdded:Connect(function(d)
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            task.defer(function()
                if d.Parent then M.F.FitText(d, 8) end
            end)
        end
    end)

    local l = Instance.new("UIListLayout", container)
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder

    local p = Instance.new("UIPadding", container)
    p.PaddingBottom = UDim.new(0, 24)
    p.PaddingTop = UDim.new(0, 2)
    p.PaddingRight = UDim.new(0, 3)
    p.PaddingLeft = UDim.new(0, 3)

    l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local h = l.AbsoluteContentSize.Y + 36
        local curPos = sf.CanvasPosition
        container.Size = UDim2.new(1, -12, 0, h)
        sf.CanvasSize = UDim2.new(0, 0, 0, h)
        sf.CanvasPosition = curPos
    end)

    M.UI.Pages[name] = {Frame = sf, Container = container}
    return container
end

-- содержимое страницы строится только при первом открытии вкладки
M.Data.BuildThreads = setmetatable({}, {__mode = "k"})
M.Data.BuildMark = 0

function M.F.BuildYield()
    local D = M.Data
    local co = coroutine.running()
    if D.BuildThreads[co] and os.clock() - D.BuildMark > 0.003 then
        task.wait()
        D.BuildMark = os.clock()
    end
end

function M.F.BuildPage(name, mode)
    local builder = M.Data.PageBuilders[name]
    if not builder then return end
    M.Data.PageBuilders[name] = nil
    local function run()
        local D = M.Data
        local co = coroutine.running()
        if mode then
            D.BuildThreads[co] = true
            D.BuildMark = os.clock()
        end
        local ok, err = pcall(builder)
        D.BuildThreads[co] = nil
        if not ok then M.Errors.Hit("Page " .. name, err) end
    end
    if mode == "async" then task.spawn(run) else run() end
end

-- spread = true
function M.F.BuildAllPages(spread)
    local names = {}
    for name in pairs(M.Data.PageBuilders) do names[#names + 1] = name end
    for _, name in ipairs(names) do
        M.F.BuildPage(name, spread and "inline" or nil)
        if spread then task.wait() end
    end
end

-- оформление кнопок вкладок для текущей активной вкладки
function M.F.StyleTabs(duration)
    local name = M.State.ActiveTab
    -- длительность либо задана явно
    local dur = duration and duration * M.Style.Scale() or math.max(M.State.AnimSpeed, 0.12)
    for n, b in pairs(M.UI.TabButtons) do
        local isAct = (n == name)
        -- активная вкладка плавно окрашивается
        M.Style.Tween(b, dur, {
            TextColor3 = isAct and M.Style.AccentMix(0.35) or M.Style.TextDim,
            BackgroundColor3 = isAct and M.State.SideCardBg:Lerp(M.State.Accent, 0.16) or M.State.SideCardBg,
            BackgroundTransparency = isAct and math.clamp(M.State.SideCardAlpha * 0.55, 0, 1) or M.State.SideCardAlpha
        }, nil, nil, true)
        local stroke = M.Data.TabStrokes[n]
        if stroke then
            stroke.Color = M.State.Accent
            M.Style.Tween(stroke, dur * 1.4, {Transparency = isAct and M.Style.StrokeActive or 1}, nil, nil, true)
        end
        local tabPad = M.Data.TabPads and M.Data.TabPads[n]
        if tabPad then
            M.Services.T:Create(tabPad, M.Style.Info(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {PaddingLeft = UDim.new(0, isAct and 20 or 14)}):Play()
        end
    end
end

function M.F.SwitchTab(name)
    local search = M.Data.Search
    if search and search.Shown then
        search.Shown = false
        if search.Box then search.Box.Text = "" end
    end
    if M.State.ActiveTab == name and M.UI.Pages[name] and M.UI.Pages[name].Frame.Visible then return end
    local pack = M.UI.Pages[name]
    M.F.BuildPage(name, "async")
    M.State.ActiveTab = name
    M.F.StyleTabs()

    local menuFading = M.Data.Fades.Menu ~= nil
    M.F.FadeFinish("Page")
    for n, pPack in pairs(M.UI.Pages) do
        if n == name then
            pPack.Frame.Position = UDim2.new(0, 8, 0, 20)
            pPack.Frame.Visible = true
            M.Style.Tween(pPack.Frame, 0.45, {Position = UDim2.new(0, 8, 0, 6)})
            if M.Run.MenuOpen and not menuFading then
                M.F.FadePrepare("Page", {pPack.Frame}, 0)
                M.F.FadeTo("Page", 1, 0.3 * M.Style.Scale(), function() M.F.FadeFinish("Page") end)
            end
        else
            pPack.Frame.Visible = false
        end
    end
    -- карточки страницы проявляются по очереди
    if pack and M.State.UiFx and M.Run.MenuOpen and M.Data.Fades.Menu == nil and pack.Frame.Visible and M.F.PageCascade then
        M.F.PageCascade(pack)
    end
    -- надписи, которые на скрытой странице измерить не удалось
    task.defer(M.F.RefitAll, true)
end

end}

-- [55/69] Построение меню: разделы, переключатели, бинды
MODULES[#MODULES + 1] = {"55. Построение меню: разделы, переключатели, бинды", function(M, __X)
local getService = __X.getService
-- вкладка
function M.F.MakeTabBtn(tabKey, order)
    local tabName = tabKey:gsub("Tab_", "")
    local b = Instance.new("TextButton", M.UI.TabContainer)
    b.Size = UDim2.new(1, -16, 0, 30); b.LayoutOrder = order; b.AutoButtonColor = false; b.BorderSizePixel = 0
    b.BackgroundColor3 = M.State.SideCardBg; b.BackgroundTransparency = M.State.SideCardAlpha
    b.Text = M.Translate(tabKey); b.TextColor3 = M.Style.TextDim; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
    local pad = Instance.new("UIPadding", b); pad.PaddingLeft = UDim.new(0, 14)
    M.F.FitText(b, 9)
    M.Data.TabPads = M.Data.TabPads or {}
    M.Data.TabPads[tabName] = pad
    table.insert(M.UI.SideCards, b)

    -- рамка активной вкладки (у неактивных скрыта)
    local stroke = Instance.new("UIStroke", b)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = M.State.Accent; stroke.Thickness = 1; stroke.Transparency = 1
    M.Data.TabStrokes[tabName] = stroke

    b.MouseEnter:Connect(function()
        task.defer(M.F.BuildPage, tabName, "async")
        if M.State.ActiveTab ~= tabName then
            M.Services.T:Create(b, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                TextColor3 = M.Style.Text,
                BackgroundTransparency = math.clamp(M.State.SideCardAlpha * 0.6, 0.03, 0.5)
            }):Play()
            M.Services.T:Create(stroke, TweenInfo.new(M.State.AnimSpeed), {Transparency = 0.75}):Play()
        end
    end)

    b.MouseLeave:Connect(function()
        if M.State.ActiveTab ~= tabName then
            M.Services.T:Create(b, TweenInfo.new(M.State.AnimSpeed, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                TextColor3 = M.Style.TextDim,
                BackgroundTransparency = M.State.SideCardAlpha
            }):Play()
            M.Services.T:Create(stroke, TweenInfo.new(M.State.AnimSpeed), {Transparency = 1}):Play()
        end
    end)

    b.MouseButton1Click:Connect(function() M.F.SwitchTab(tabName) end)
    M.UI.TabButtons[tabName] = b
    table.insert(M.Data.RegUI, { SetLanguage = function() b.Text = M.Translate(tabKey) end })
end

function M.F.MakeSection(parent, locKey, order)
    M.F.BuildYield()
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
    table.insert(M.UI.Sliders, bar)

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = M.Upper(M.Translate(locKey))
    lbl.TextColor3 = M.Style.TextDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local line = Instance.new("Frame", f)
    line.Size = UDim2.new(1, -8, 0, 1)
    line.Position = UDim2.new(0, 4, 1, -2)
    line.BackgroundColor3 = M.Style.Stroke
    line.BorderSizePixel = 0
    local lineFade = Instance.new("UIGradient", line)
    lineFade.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})

    table.insert(M.Data.RegUI, { SetLanguage = function() lbl.Text = M.Upper(M.Translate(locKey)) end })
    return f
end

-- кнопки биндов
M.Data.BindRefs = {}

function M.F.MakeCard(parent, h)
    M.F.BuildYield()
    local c = Instance.new("Frame", parent)
    c.Size = UDim2.new(1, 0, 0, h or 42); c.BackgroundColor3 = M.State.CardBg; c.BackgroundTransparency = M.State.CardAlpha; c.BorderSizePixel = 0
    Instance.new("UICorner", c).CornerRadius = UDim.new(0, 11)
    table.insert(M.UI.Cards, c)

    -- тонкая рамка
    local stroke = M.Style.AddStroke(c, M.Style.Stroke, 1, M.Style.StrokeIdle)
    local hover = Instance.new("Frame", c)
    hover.Name = "Hover"
    hover.Size = UDim2.new(1, 0, 1, 0)
    hover.BackgroundColor3 = Color3.new(1, 1, 1)
    hover.BackgroundTransparency = 1
    hover.BorderSizePixel = 0
    hover.Active = false
    Instance.new("UICorner", hover).CornerRadius = UDim.new(0, 11)

    local hovered = false

    local function pointerInside()
        local point = M.Services.U:GetMouseLocation()
        if not M.UI.Gui.IgnoreGuiInset then
            local guiService = getService("GuiService")
            if guiService then point = point - guiService:GetGuiInset() end
        end
        local pos, size = c.AbsolutePosition, c.AbsoluteSize
        return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
    end
    c.MouseEnter:Connect(function()
        if hovered then return end
        hovered = true
        M.Style.Tween(stroke, 0.22, {Color = M.State.Accent, Transparency = M.Style.StrokeActive})
        M.Style.Tween(hover, 0.22, {BackgroundTransparency = 0.975})
        task.spawn(function()
            while hovered and c.Parent and not M.Run.IsShutDown do
                task.wait(0.06)
                if not M.Run.MenuOpen or not pointerInside() then break end
            end
            hovered = false
            if c.Parent then
                M.Style.Tween(stroke, 0.3, {Color = M.Style.Stroke, Transparency = M.Style.StrokeIdle})
                M.Style.Tween(hover, 0.3, {BackgroundTransparency = 1})
            end
        end)
    end)

    return c
end

-- оформление переключателей
M.Theme = {
    ToggleOff = M.Style.Off,
    ThumbOff = UDim2.new(0, 3, 0.5, 0),
    ThumbOn = UDim2.new(1, -21, 0.5, 0)
}

-- переключатель
function M.F.StyleToggle(trk, thm, on)
    trk.BackgroundColor3 = on and M.State.Accent or M.Theme.ToggleOff
    thm.Size = UDim2.new(0, 18, 0, 18)
    thm.AnchorPoint = Vector2.new(0, 0.5)
    thm.Position = on and M.Theme.ThumbOn or M.Theme.ThumbOff
    thm.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    -- лёгкий перелив на дорожке
    if not trk:FindFirstChild("Depth") then
        local depth = Instance.new("UIGradient")
        depth.Name = "Depth"
        depth.Rotation = 90
        depth.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 205, 222))
        depth.Parent = trk
    end
end

-- та же анимация, что у мини-переключателя в уведомлениях
function M.F.AnimateToggle(trk, thm, on, glow)
    M.Services.T:Create(thm, M.Style.Info(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = on and M.Theme.ThumbOn or M.Theme.ThumbOff}):Play()
    M.Services.T:Create(trk, M.Style.Info(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {BackgroundColor3 = on and M.State.Accent or M.Theme.ToggleOff}):Play()
    if glow then
        glow.SetColor(M.State.Accent, 0.3)
        glow.Set(on and M.Style.ControlGlow or 0, 0.3)
    end
end

-- свечение под дорожкой переключателя
function M.F.AttachToggleGlow(card, on)
    local host = Instance.new("Frame")
    host.Name = "ToggleGlowHost"
    host.Size = UDim2.new(0, 48, 0, 24); host.Position = UDim2.new(1, -60, 0.5, -12)
    host.BackgroundTransparency = 1; host.BorderSizePixel = 0; host.Active = false
    host.Parent = card
    return M.Style.Glow(host, 8, on and M.Style.ControlGlow or 0, M.State.Accent, UDim.new(1, 0))
end

-- небольшая кнопка
function M.F.DecorateButton(btn, ownScale)
    btn.AutoButtonColor = false
    local stroke = M.Style.AddStroke(btn, M.Style.Stroke, 1, M.Style.StrokeIdle)
    local scale = Instance.new("UIScale")
    scale.Name = "ButtonScale"
    scale.Parent = btn
    btn.MouseEnter:Connect(function()
        M.Style.Tween(stroke, 0.18, {Color = M.State.Accent, Transparency = M.Style.StrokeActive})
        if not ownScale and M.State.UiFx then M.Style.Tween(scale, 0.3, {Scale = 1.05}, Enum.EasingStyle.Back) end
    end)
    btn.MouseLeave:Connect(function()
        M.Style.Tween(stroke, 0.25, {Color = M.Style.Stroke, Transparency = M.Style.StrokeIdle})
        if not ownScale then M.Style.Tween(scale, 0.25, {Scale = 1}) end
    end)
    if not ownScale then
        btn.MouseButton1Down:Connect(function() M.Style.Tween(scale, 0.1, {Scale = 0.94}) end)
        btn.MouseButton1Up:Connect(function() M.Style.Tween(scale, 0.35, {Scale = 1.05}, Enum.EasingStyle.Back) end)
    end
    return stroke
end

function M.F.MakeToggle(parent, locKey, stateKey, order, onTog, allowBind, bindAction)
    local c = M.F.MakeCard(parent, 40); c.LayoutOrder = order

    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1, allowBind and -130 or -75, 1, 0); l.Position = UDim2.new(0, 12, 0, 0); l.BackgroundTransparency = 1
    l.Text = M.Translate(locKey); l.TextColor3 = M.Style.Text; l.Font = Enum.Font.GothamMedium; l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left

    local bBtn = nil
    if allowBind then
        bBtn = Instance.new("TextButton", c)
        bBtn.Size = UDim2.new(0, 48, 0, 24); bBtn.Position = UDim2.new(1, -118, 0.5, -12); bBtn.BackgroundColor3 = M.Style.Field; bBtn.Text = M.Translate("Bind_None"); bBtn.TextColor3 = M.Style.TextDim; bBtn.Font = Enum.Font.GothamBold; bBtn.TextSize = 11
        Instance.new("UICorner", bBtn).CornerRadius = UDim.new(0, 7); M.F.DecorateButton(bBtn)
    end

    local tglow = M.F.AttachToggleGlow(c, M.State[stateKey] == true)
    local trk = Instance.new("TextButton", c)
    trk.Size = UDim2.new(0, 48, 0, 24); trk.Position = UDim2.new(1, -60, 0.5, -12); trk.Text = ""; trk.AutoButtonColor = false
    Instance.new("UICorner", trk).CornerRadius = UDim.new(1, 0)

    local thm = Instance.new("Frame", trk)
    thm.BorderSizePixel = 0
    Instance.new("UICorner", thm).CornerRadius = UDim.new(1, 0)
    M.F.StyleToggle(trk, thm, M.State[stateKey])

    local function uv(val)
        M.F.AnimateToggle(trk, thm, val, tglow)
    end

    local function trigger()
        M.State[stateKey] = not M.State[stateKey]
        uv(M.State[stateKey])
        if onTog then onTog(M.State[stateKey]) end
        M.F.NotifyToggle(stateKey, locKey, M.State[stateKey])
    end
    trk.MouseButton1Click:Connect(trigger)
    table.insert(M.Data.ToggleRefs, {Track = trk, Glow = tglow, IsOn = function() return M.State[stateKey] == true end})

    local bindData
    table.insert(M.Data.RegUI, {
        Key = stateKey,
        SetVisual = function(val) uv(val) end,
        SetLanguage = function()
            l.Text = M.Translate(locKey)
            if bBtn and bindData and not bindData.Key then bBtn.Text = M.Translate("Bind_None") end
        end,
        Callback = onTog
    })

    if allowBind and bBtn then
        bindData = M.F.WireBindButton(bBtn, stateKey, bindAction or trigger, function() return M.State[stateKey] == true end, locKey)
    end
    return c
end

-- клавиша бинда: клавиша клавиатуры или средняя/правая кнопка мыши
M.F.BindMouse = {MouseButton2 = true, MouseButton3 = true}

function M.F.KeyFromName(name)
    if type(name) ~= "string" or name == "" then return nil end
    if M.F.BindMouse[name] then return Enum.UserInputType[name] end
    local ok, code = pcall(function() return Enum.KeyCode[name] end)
    if ok then return code end
    return nil
end

-- подпись клавиши для кнопок и списка
function M.F.KeyLabel(key)
    if key == nil or key == "" then return M.Translate("Bind_None") end
    local name = type(key) == "string" and key or key.Name
    if name == "MouseButton2" then return M.Translate("Keys_Rmb") end
    if name == "MouseButton3" then return M.Translate("Keys_Mmb") end
    return string.upper(name)
end

-- какая клавиша нажата: клавиатура или средняя/правая кнопка мыши
function M.F.InputKey(inp)
    local kind = inp.UserInputType
    if kind == Enum.UserInputType.Keyboard then return inp.KeyCode end
    if M.F.BindMouse[kind.Name] then return kind end
    return nil
end

-- режимы как в Neverlose: «Переключать» - нажатие меняет состояние, «Удерживать» - включено, пока клавиша зажата
function M.F.BindPress(b)
    b.Down = true
    b.PressedAt = os.clock()
    if b.Mode == "Hold" and b.IsOn then
        if not b.IsOn() then
            b.Trigger()
            b.HeldOn = true
        end
        return
    end
    b.Trigger()
end

function M.F.BindRelease(b)
    b.Down = false
    if b.HeldOn then
        b.HeldOn = false
        if b.IsOn and b.IsOn() then b.Trigger() end
    end
end

-- окно игры потеряло фокус: удерживаемые бинды отпускаются
function M.F.ReleaseAllBinds()
    for _, b in ipairs(M.Data.Binds) do
        if b.Down or b.HeldOn then pcall(M.F.BindRelease, b) end
    end
end

function M.F.CloseBindMenu()
    local bm = M.Data.BindMenu
    M.Data.BindMenu = nil
    if not bm then return end
    if bm.Conn then bm.Conn:Disconnect() end
    if bm.Frame then pcall(function() bm.Frame:Destroy() end) end
end

-- меню бинда по правой кнопке: режим и сброс клавиши
function M.F.BindModeMenu(btn, bDat, show)
    M.F.CloseBindMenu()
    local gui = M.UI.Gui
    if not gui or not btn.Parent then return end
    local items = {{"BindMode_Toggle", "Toggle"}, {"BindMode_Hold", "Hold"}, {"BindMode_Clear", "Clear"}}
    local W, H = 156, 26
    local menu = Instance.new("Frame")
    menu.Name = "BindMenu"
    menu.Size = UDim2.fromOffset(W, #items * H + 8)
    local abs, size, area = btn.AbsolutePosition, btn.AbsoluteSize, gui.AbsoluteSize
    local x = math.clamp(abs.X + size.X - W, 4, math.max(area.X - W - 4, 4))
    local y = abs.Y + size.Y + 4
    if y + #items * H + 8 > area.Y - 4 then y = abs.Y - #items * H - 12 end
    menu.Position = UDim2.fromOffset(x, y)
    menu.BackgroundColor3 = M.Style.Surface
    menu.BorderSizePixel = 0
    menu.ZIndex = 60
    Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 9)
    M.Style.Bind(M.Style.AddStroke(menu, M.State.Accent, 1, M.Style.StrokeActive), "Color")
    local pad = Instance.new("UIPadding", menu)
    pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 4)
    local list = Instance.new("UIListLayout", menu)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    for i, item in ipairs(items) do
        local current = item[2] == bDat.Mode and bDat.Key ~= nil
        local b = Instance.new("TextButton")
        b.LayoutOrder = i
        b.Size = UDim2.new(1, 0, 0, H)
        b.BackgroundColor3 = M.Style.Raised
        b.BackgroundTransparency = current and 0.4 or 1
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 12
        b.Text = M.Translate(item[1])
        b.TextColor3 = (item[2] == "Clear") and M.Style.Danger:Lerp(M.Style.Text, 0.3) or (current and M.State.Accent or M.Style.Text)
        b.ZIndex = 61
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseEnter:Connect(function() M.Style.Tween(b, 0.12, {BackgroundTransparency = 0.25}) end)
        b.MouseLeave:Connect(function() M.Style.Tween(b, 0.18, {BackgroundTransparency = current and 0.4 or 1}) end)
        b.MouseButton1Click:Connect(function()
            if item[2] == "Clear" then
                if bDat.HeldOn then M.F.BindRelease(bDat) end
                bDat.Key = nil
            else
                if bDat.HeldOn then M.F.BindRelease(bDat) end
                bDat.Mode = item[2]
            end
            show()
            M.F.CloseBindMenu()
        end)
        b.Parent = menu
    end
    local scale = Instance.new("UIScale", menu)
    scale.Scale = 0.92
    menu.Parent = gui
    M.Style.Tween(scale, 0.22, {Scale = 1}, Enum.EasingStyle.Back)
    local bm = {Frame = menu}
    M.Data.BindMenu = bm
    -- щелчок мимо меню закрывает его
    task.defer(function()
        if M.Data.BindMenu ~= bm then return end
        bm.Conn = M.Services.U.InputBegan:Connect(function(inp)
            local kind = inp.UserInputType
            if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.MouseButton2 and kind ~= Enum.UserInputType.Touch then return end
            local p = M.Services.U:GetMouseLocation()
            if not gui.IgnoreGuiInset then
                local gs = __X.getService and __X.getService("GuiService")
                if gs then p = p - gs:GetGuiInset() end
            end
            local a, s = menu.AbsolutePosition, menu.AbsoluteSize
            if p.X < a.X or p.X > a.X + s.X or p.Y < a.Y or p.Y > a.Y + s.Y then
                task.defer(function() if M.Data.BindMenu == bm then M.F.CloseBindMenu() end end)
            end
        end)
    end)
end

-- кнопка бинда: ЛКМ - ждать клавишу, ПКМ - меню режима; id, клавиша и режим сохраняются в конфиг
function M.F.WireBindButton(bBtn, id, trigger, isOn, locKey)
    local bDat = {Id = id, Key = nil, Mode = "Toggle", Trigger = trigger, IsOn = isOn, LocKey = locKey or id}
    local function show()
        bBtn.Text = bDat.Key and M.F.KeyLabel(bDat.Key) or M.Translate("Bind_None")
        if not bDat.Key then
            bBtn.TextColor3 = M.Style.TextDim
        elseif bDat.Mode == "Hold" then
            bBtn.TextColor3 = M.Style.AccentMix(0.55)
        else
            bBtn.TextColor3 = M.State.Accent
        end
    end
    bDat.Show = show
    table.insert(M.Data.BindRefs, {Btn = bBtn, Show = show, Active = function() return bDat.Key ~= nil end})
    table.insert(M.Data.Binds, bDat)
    bBtn.MouseButton1Click:Connect(function()
        M.F.CloseBindMenu()
        local listening = M.Run.ListeningBind
        if listening then
            M.Run.ListeningBind = nil
            if listening.Cancel then listening.Cancel() end
            show()
        else
            M.Run.ListeningBind = {Set = function(k)
                if bDat.HeldOn then M.F.BindRelease(bDat) end
                bDat.Key = k
                bDat.RmbSetAt = (k == Enum.UserInputType.MouseButton2) and os.clock() or nil
                show()
            end, Cancel = show}
            bBtn.Text = "..."
            bBtn.TextColor3 = M.Style.Warn
        end
    end)
    bBtn.MouseButton2Click:Connect(function()
        local listening = M.Run.ListeningBind
        if listening then
            M.Run.ListeningBind = nil
            if listening.Cancel then listening.Cancel() end
        end
        -- правая кнопка только что стала клавишей бинда: меню не открываем
        if bDat.RmbSetAt and os.clock() - bDat.RmbSetAt < 0.4 then bDat.RmbSetAt = nil return end
        M.F.BindModeMenu(bBtn, bDat, show)
    end)
    return bDat
end

end}

-- [56/69] Построение меню: выбор клавиши, ползунки
MODULES[#MODULES + 1] = {"56. Построение меню: выбор клавиши, ползунки", function(M, __X)
-- строка только с биндом
function M.F.MakeBindRow(parent, locKey, order, onPress)
    local c = M.F.MakeCard(parent, 40); c.LayoutOrder = order

    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1, -75, 1, 0); l.Position = UDim2.new(0, 12, 0, 0); l.BackgroundTransparency = 1
    l.Text = M.Translate(locKey); l.TextColor3 = M.Style.Text; l.Font = Enum.Font.GothamMedium; l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left

    local bBtn = Instance.new("TextButton", c)
    bBtn.Size = UDim2.new(0, 48, 0, 24); bBtn.Position = UDim2.new(1, -60, 0.5, -12); bBtn.BackgroundColor3 = M.Style.Field
    bBtn.Text = M.Translate("Bind_None"); bBtn.TextColor3 = M.Style.TextDim; bBtn.Font = Enum.Font.GothamBold; bBtn.TextSize = 11
    Instance.new("UICorner", bBtn).CornerRadius = UDim.new(0, 7); M.F.DecorateButton(bBtn)

    local bDat = M.F.WireBindButton(bBtn, locKey, onPress, nil, locKey)
    table.insert(M.Data.RegUI, {SetLanguage = function() l.Text = M.Translate(locKey); if not bDat.Key then bBtn.Text = M.Translate("Bind_None") end end})
    return c
end

-- строка выбора клавиши, которая сохраняется в настройках
function M.F.MakeKeyRow(parent, locKey, stateKey, order)
    local c = M.F.MakeCard(parent, 40); c.LayoutOrder = order

    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1, -125, 1, 0); l.Position = UDim2.new(0, 12, 0, 0); l.BackgroundTransparency = 1
    l.Text = M.Translate(locKey); l.TextColor3 = M.Style.Text; l.Font = Enum.Font.GothamMedium; l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left

    local bBtn = Instance.new("TextButton", c)
    bBtn.Size = UDim2.new(0, 100, 0, 24); bBtn.Position = UDim2.new(1, -112, 0.5, -12); bBtn.BackgroundColor3 = M.Style.Field
    bBtn.Text = M.Translate("Bind_None"); bBtn.TextColor3 = M.Style.TextDim; bBtn.Font = Enum.Font.GothamBold; bBtn.TextSize = 11
    Instance.new("UICorner", bBtn).CornerRadius = UDim.new(0, 7); M.F.DecorateButton(bBtn)

    local idle = M.Style.TextDim
    local function current() return M.State[stateKey] or "" end
    local function show()
        local name = current()
        bBtn.Text = name ~= "" and M.F.KeyLabel(name) or M.Translate("Bind_None")
        bBtn.TextColor3 = name ~= "" and M.State.Accent or idle
    end
    show()
    table.insert(M.Data.BindRefs, {Btn = bBtn, Active = function() return current() ~= "" end})

    bBtn.MouseButton1Click:Connect(function()
        local listening = M.Run.ListeningBind
        if listening then
            M.Run.ListeningBind = nil
            if listening.Cancel then listening.Cancel() end
            show()
        else
            M.Run.ListeningBind = {
                Set = function(k) M.State[stateKey] = k and k.Name or ""; show() end,
                Cancel = show
            }
            bBtn.Text = "..."
            bBtn.TextColor3 = M.Style.Warn
        end
    end)
    bBtn.MouseButton2Click:Connect(function()
        local listening = M.Run.ListeningBind
        M.Run.ListeningBind = nil
        if listening and listening.Cancel then listening.Cancel() end
        M.State[stateKey] = ""
        show()
    end)
    table.insert(M.Data.RegUI, {
        Key = stateKey,
        SetVisual = function() show() end,
        SetLanguage = function() l.Text = M.Translate(locKey); show() end
    })
    return c
end

-- карточка режима
function M.F.MakeSpeedCard(parent, locKey, isFly, order)
    local c = M.F.MakeCard(parent, 40); c.LayoutOrder = order

    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1, -130, 1, 0); l.Position = UDim2.new(0, 12, 0, 0); l.BackgroundTransparency = 1
    l.Text = M.Translate(locKey); l.TextColor3 = M.Style.Text; l.Font = Enum.Font.GothamMedium; l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left

    local tglow = M.F.AttachToggleGlow(c, false)
    local trk = Instance.new("TextButton", c)
    trk.Size = UDim2.new(0, 48, 0, 24); trk.Position = UDim2.new(1, -60, 0.5, -12); trk.Text = ""; trk.AutoButtonColor = false
    Instance.new("UICorner", trk).CornerRadius = UDim.new(1, 0)

    local thm = Instance.new("Frame", trk)
    thm.BorderSizePixel = 0
    Instance.new("UICorner", thm).CornerRadius = UDim.new(1, 0)
    M.F.StyleToggle(trk, thm, false)

    local speedKey = isFly and "FlightMode" or "Speed"
    local function uv()
        M.F.AnimateToggle(trk, thm, M.State[speedKey] and true or false, tglow)
    end

    local function t()
        if isFly then
            if M.State.FlightMode then M.F.StopFlying() else M.F.StartFlying() end
        else
            M.State.Speed = not M.State.Speed
        end
        uv()
        M.F.NotifyToggle(speedKey, locKey, M.State[speedKey])
    end
    trk.MouseButton1Click:Connect(t)
    table.insert(M.Data.ToggleRefs, {Track = trk, Glow = tglow, IsOn = function() return M.State[speedKey] == true end})

    -- кнопка бинда
    local bBtn = Instance.new("TextButton", c)
    bBtn.Size = UDim2.new(0, 48, 0, 24); bBtn.Position = UDim2.new(1, -118, 0.5, -12); bBtn.BackgroundColor3 = M.Style.Field
    bBtn.Text = M.Translate("Bind_None"); bBtn.TextColor3 = M.Style.TextDim; bBtn.Font = Enum.Font.GothamBold; bBtn.TextSize = 11
    Instance.new("UICorner", bBtn).CornerRadius = UDim.new(0, 7); M.F.DecorateButton(bBtn)
    local bDat = M.F.WireBindButton(bBtn, speedKey, t, function() return M.State[speedKey] == true end, locKey)

    table.insert(M.Data.RegUI, {
        Key = speedKey,
        SetVisual = function() uv() end,
        SetLanguage = function() l.Text = M.Translate(locKey); if not bDat.Key then bBtn.Text = M.Translate("Bind_None") end end
    })
    return c
end

-- флаги ползунков
M.IntegerSliders, M.DecimalSliders, M.ExtendableSliders = {}, {}, {}
for key, spec in pairs(M.Schema.Slider) do
    local flags = spec[4] or ""
    if flags:find("i", 1, true) then M.IntegerSliders[key] = true end
    if flags:find("d", 1, true) then M.DecimalSliders[key] = true end
    if flags:find("x", 1, true) then M.ExtendableSliders[key] = true end
end

local UNIT_KEYS = {["мс"] = "Unit_ms", ["с"] = "Unit_s", ["м"] = "Unit_m", ["штук"] = "Unit_pcs", ["studs"] = "Unit_studs"}
function M.F.UnitText(un)
    local key = UNIT_KEYS[un]
    return key and M.Translate(key) or un
end

function M.F.MakeSlider(parent, locKey, stateKey, order, cb)
    local spec = M.Schema.Slider[stateKey]
    if not spec then error("нет границ ползунка в M.Schema.Slider: " .. tostring(stateKey)) end
    local mn, mx, un = spec[1], spec[2], spec[3]
    local useInteger = (mx > 10 and un ~= "с" and not M.DecimalSliders[stateKey]) or M.IntegerSliders[stateKey] == true
    local c = M.F.MakeCard(parent, 40); c.LayoutOrder = order
    local labelText = M.Translate(locKey) .. (un and ("  " .. M.F.UnitText(un)) or "")
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(0.42, 0, 1, 0); l.Position = UDim2.new(0, 12, 0, 0); l.BackgroundTransparency = 1
    l.Text = labelText; l.TextColor3 = M.Style.TextDim; l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left

    local trk = Instance.new("Frame", c)
    trk.Size = UDim2.new(0.36, 0, 0, 6); trk.Position = UDim2.new(0.44, 0, 0.5, -3); trk.BackgroundColor3 = M.Style.Field; trk.Active = true
    Instance.new("UICorner", trk).CornerRadius = UDim.new(1, 0)
    M.Style.AddStroke(trk, M.Style.Stroke, 1, M.Style.StrokeIdle)

    local f = Instance.new("Frame", trk)
    f.Size = UDim2.new(math.clamp((M.State[stateKey] - mn) / (mx - mn), 0.02, 1), 0, 1, 0); f.BackgroundColor3 = M.State.Accent; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
    table.insert(M.UI.Sliders, f)
    local fillGrad = Instance.new("UIGradient", f)
    fillGrad.Color = ColorSequence.new(Color3.fromRGB(150, 150, 165), Color3.fromRGB(255, 255, 255))

    local handle = Instance.new("Frame", f)
    handle.AnchorPoint = Vector2.new(0.5, 0.5)
    handle.Position = UDim2.new(1, -3, 0.5, 0)
    handle.Size = UDim2.new(0, 12, 0, 12)
    handle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    handle.BorderSizePixel = 0
    handle.ZIndex = 2
    Instance.new("UICorner", handle).CornerRadius = UDim.new(1, 0)
    local handleGlow = M.Style.AccentGlow(handle, 9, M.Style.ControlGlow * 0.6, UDim.new(1, 0), 1)
    local handleScale = Instance.new("UIScale", handle)

    local dragging, hoveringHandle = false, false
    local function refreshHandle()
        -- при нажатии дорожка заметно утолщается
        local thick = dragging and 11 or (hoveringHandle and 8 or 6)
        M.Style.Tween(trk, 0.22, {Size = UDim2.new(0.36, 0, 0, thick), Position = UDim2.new(0.44, 0, 0.5, -thick / 2)}, Enum.EasingStyle.Back)
        handleGlow.Set(dragging and M.Style.ControlGlow * 1.5 or (hoveringHandle and M.Style.ControlGlow or M.Style.ControlGlow * 0.6), 0.2)
        M.Style.Tween(handleScale, 0.2, {Scale = dragging and 1.3 or (hoveringHandle and 1.15 or 1)}, Enum.EasingStyle.Back)
    end
    local hit = Instance.new("Frame", c)
    hit.Name = "SliderHit"
    hit.Size = UDim2.new(0.36, 16, 0, 28); hit.Position = UDim2.new(0.44, -8, 0.5, -14)
    hit.BackgroundTransparency = 1; hit.BorderSizePixel = 0; hit.Active = true; hit.ZIndex = 5
    hit.MouseEnter:Connect(function() hoveringHandle = true; refreshHandle() end)
    hit.MouseLeave:Connect(function() hoveringHandle = false; refreshHandle() end)

    local box = Instance.new("TextBox", c)
    box.Size = UDim2.new(0, 52, 0, 24); box.Position = UDim2.new(1, -60, 0.5, -12)
    box.BackgroundColor3 = M.Style.Field; box.Text = tostring(M.State[stateKey]); box.TextColor3 = M.Style.Text
    box.Font = Enum.Font.GothamBold; box.TextSize = 12; box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 7)
    local boxStroke = M.Style.AddStroke(box, M.Style.Stroke, 1, M.Style.StrokeIdle)
    box.Focused:Connect(function() M.Style.Tween(boxStroke, 0.2, {Color = M.State.Accent, Transparency = M.Style.StrokeActive}) end)

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

    hit.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            if M.Data.DragEnd then pcall(M.Data.DragEnd) end
            dragging = true
            refreshHandle()
            function M.Data.DragEnd()
                dragging = false
                refreshHandle()
            end
            upd(inp.Position); M.Data.DragHandler = upd
        end
    end)

    box.FocusLost:Connect(function()
        M.Style.Tween(boxStroke, 0.25, {Color = M.Style.Stroke, Transparency = M.Style.StrokeIdle})
        local n = tonumber(box.Text)
        if n and n == n then  -- NaN ("nan", "0/0") не принимается: n ~= n
            n = math.clamp(n, mn, M.ExtendableSliders[stateKey] and math.max(mx * 10, mx) or mx)
            if useInteger then n = math.round(n) else n = math.floor(n * 100) / 100 end
            M.State[stateKey] = n
            setVisual(n)
            if cb then cb(n) end
        else
            box.Text = tostring(M.State[stateKey])
        end
    end)

    table.insert(M.Data.RegUI, {
        Key = stateKey, Min = mn, Max = M.ExtendableSliders[stateKey] and math.max(mx * 10, mx) or mx,
        SetVisual = function(val) setVisual(val, M.Data.Importing) end,
        SetLanguage = function() l.Text = M.Translate(locKey) .. (un and ("  " .. M.F.UnitText(un)) or "") end,
        Callback = cb
    })
    return c
end

end}

-- [57/69] Построение меню: палитра, буфер обмена, журнал ошибок
MODULES[#MODULES + 1] = {"57. Построение меню: палитра, буфер обмена, журнал ошибок", function(M, __X)
-- ==============================================================================
-- [ МАТЕМАТИКА ПАЛИТРЫ ]
-- ==============================================================================
M.ColorMath = {}

-- у белого, серого и чёрного оттенок
function M.ColorMath.ResolveHue(previousHue, newHue, saturation, value)
    if saturation > 0.001 and value > 0.001 then
        return newHue
    end
    return previousHue
end

-- если цвет почти белый/серый
function M.ColorMath.PrepareForHueChange(saturation, value)
    if saturation < 0.05 then saturation = 0.55 end
    if value < 0.15 then value = 1 end
    return saturation, value
end

-- буфер обмена исполнителя
local CLIP_WRITE = {"setclipboard", "toclipboard", "set_clipboard", "setrbxclipboard", "writeclipboard", "write_clipboard",
    "syn.write_clipboard", "Clipboard.set", "clipboard.set", "clipboard.write"}
local CLIP_READ = {"getclipboard", "readclipboard", "get_clipboard", "fromclipboard", "syn.read_clipboard",
    "Clipboard.get", "clipboard.get", "clipboard.read"}

local function clipboardFns(names)
    local list, seen = {}, {}
    for _, name in ipairs(names) do
        local fn = M.Cap.Fn(name)
        if fn and not seen[fn] then seen[fn] = true; list[#list + 1] = fn end
    end
    return list
end

local function clipboardWriters() return clipboardFns(CLIP_WRITE) end
local function clipboardReaders() return clipboardFns(CLIP_READ) end

function M.F.CopyText(text)
    for _, fn in ipairs(clipboardWriters()) do
        if pcall(fn, text) then return true end
    end
    return false
end

-- журнал ошибок для меню
function M.F.ErrorsTop()
    local bestName, bestN = nil, 0
    for name, n in pairs(M.Errors.Count) do
        if n > bestN then bestName, bestN = name, n end
    end
    return bestName, bestN
end

function M.F.ErrorsText()
    local E = M.Errors
    if E.Total == 0 and #E.List == 0 then return M.Translate("ErrNone") end
    local name, n = M.F.ErrorsTop()
    local lines = {string.format(M.Translate("ErrSummary"), E.Total, name and (name .. " x" .. n) or "-")}
    local last = E.List[#E.List]
    if last then
        local msg = last.Msg:gsub("^%[Matsysense%] ", ""):gsub("%s+", " ")
        if #msg > 140 then msg = msg:sub(1, 140) .. "..." end
        lines[2] = string.format(M.Translate("ErrLast"), math.floor(os.clock() - last.At), msg)
    end
    return table.concat(lines, "\n")
end

function M.F.ErrorsReport()
    local E = M.Errors
    local out = {"Matsysense: ошибок за сеанс " .. E.Total, "исполнитель: " .. M.Cap.Report(), "", "по частям:"}
    local names = {}
    for name in pairs(E.Count) do names[#names + 1] = name end
    table.sort(names, function(a, b) return E.Count[a] > E.Count[b] end)
    for _, name in ipairs(names) do out[#out + 1] = "  " .. name .. " x" .. E.Count[name] end
    out[#out + 1] = ""
    out[#out + 1] = "последние:"
    local now = os.clock()
    for i = #E.List, 1, -1 do
        local e = E.List[i]
        out[#out + 1] = string.format("  -%ds  %s", math.floor(now - e.At), e.Msg)
    end
    return table.concat(out, "\n")
end

function M.F.ErrorsCopy()
    local text = M.F.ErrorsReport()
    if M.F.CopyText(text) then
        M.F.Notify("Errors", M.Translate("ErrCopied"), false, true)
        return
    end
    local path = "Matsysense_errors.txt"
    if M.Cap.Call("writefile", path, text) then
        M.F.Notify("Errors", string.format(M.Translate("ErrSaved"), path), false, true)
    else
        M.F.Notify("Errors", M.Translate("ErrFail"), false, true)
    end
end

function M.F.ErrorsClear()
    local E = M.Errors
    E.Total = 0
    table.clear(E.List); table.clear(E.Count); table.clear(E.Seen)
end

function M.F.MakeErrorsCard(parent, order)
    local c = M.F.MakeCard(parent, 54)
    c.LayoutOrder = order
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1, -24, 1, -12); l.Position = UDim2.new(0, 12, 0, 6); l.BackgroundTransparency = 1
    l.TextColor3 = M.Style.TextDim; l.Font = Enum.Font.GothamMedium; l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left; l.TextYAlignment = Enum.TextYAlignment.Center
    l.TextWrapped = true; l.TextTruncate = Enum.TextTruncate.AtEnd
    l.Text = M.F.ErrorsText()
    local at = 0
    M.Track(M.Services.R.Heartbeat:Connect(function()
        if not M.Run.MenuOpen or not c.Parent then return end
        local now = os.clock()
        if now - at < 1 then return end
        at = now
        local s = M.F.ErrorsText()
        if l.Text ~= s then
            l.Text = s
            l.TextColor3 = M.Errors.Total > 0 and M.Style.Danger:Lerp(M.Style.Text, 0.35) or M.Style.TextDim
        end
    end))
    table.insert(M.Data.RegUI, {SetLanguage = function() l.Text = M.F.ErrorsText() end})
    return c
end
function M.F.MakePicker(parent, locKey, stateColorKey, order, cb)
    local c = M.F.MakeCard(parent, 118); c.LayoutOrder = order
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(0.32, 0, 0, 20); l.Position = UDim2.new(0, 12, 0, 8); l.BackgroundTransparency = 1
    l.Text = M.Translate(locKey); l.TextColor3 = M.Style.Text; l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left

    local prevBox = Instance.new("Frame", c)
    prevBox.Size = UDim2.new(0, 16, 0, 16); prevBox.Position = UDim2.new(0.34, 0, 0, 10); prevBox.BackgroundColor3 = M.State[stateColorKey]; prevBox.BorderSizePixel = 0
    Instance.new("UICorner", prevBox).CornerRadius = UDim.new(0, 5)
    local pbStroke = Instance.new("UIStroke", prevBox)
    pbStroke.Color = M.Style.Stroke; pbStroke.Thickness = 1
    -- образец цвета светится самим выбранным цветом
    local prevGlow = M.Style.Glow(prevBox, 4, 0.1, M.State[stateColorKey], UDim.new(0, 8))

    local cH, cS, cV = M.State[stateColorKey]:ToHSV()
    local cv = Instance.new("Frame", c)
    cv.Size = UDim2.new(0.55, -20, 0, 52); cv.Position = UDim2.new(0.42, 0, 0, 8); cv.BackgroundColor3 = Color3.fromHSV(cH, 1, 1); cv.Active = true
    Instance.new("UICorner", cv).CornerRadius = UDim.new(0, 6)

    local sat = Instance.new("Frame", cv); sat.Size = UDim2.new(1, 0, 1, 0); sat.BackgroundColor3 = Color3.fromRGB(255, 255, 255); sat.BorderSizePixel = 0; Instance.new("UICorner", sat).CornerRadius = UDim.new(0, 6)
    local sg = Instance.new("UIGradient", sat); sg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})

    local val = Instance.new("Frame", cv); val.Size = UDim2.new(1, 0, 1, 0); val.BackgroundColor3 = Color3.fromRGB(0, 0, 0); val.BorderSizePixel = 0; Instance.new("UICorner", val).CornerRadius = UDim.new(0, 6)
    local vg = Instance.new("UIGradient", val); vg.Rotation = 90; vg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})

    local pin = Instance.new("Frame", cv); pin.Size = UDim2.new(0, 10, 0, 10); pin.AnchorPoint = Vector2.new(0.5, 0.5); pin.Position = UDim2.new(cS, 0, 1 - cV, 0); pin.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Instance.new("UICorner", pin).CornerRadius = UDim.new(1, 0)
    local pinStroke = Instance.new("UIStroke", pin); pinStroke.Color = Color3.fromRGB(0, 0, 0); pinStroke.Thickness = 1.5; pinStroke.Transparency = 0.5

    local hb = Instance.new("Frame", c)
    hb.Size = UDim2.new(0.55, -20, 0, 8); hb.Position = UDim2.new(0.42, 0, 0, 66); hb.BackgroundColor3 = Color3.fromRGB(255, 255, 255); hb.Active = true
    Instance.new("UICorner", hb).CornerRadius = UDim.new(1, 0)
    local hg = Instance.new("UIGradient", hb)
    local hueKeys = {}
    for i = 0, 6 do
        hueKeys[#hueKeys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1))
    end
    hueKeys[#hueKeys] = ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1))
    hg.Color = ColorSequence.new(hueKeys)

    -- маркер на полосе оттенка
    local hueKnob = Instance.new("Frame", hb)
    hueKnob.Size = UDim2.new(0, 6, 0, 14)
    hueKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    hueKnob.Position = UDim2.new(cH, 0, 0.5, 0)
    hueKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hueKnob.BorderSizePixel = 0
    Instance.new("UICorner", hueKnob).CornerRadius = UDim.new(1, 0)
    local hkStroke = Instance.new("UIStroke", hueKnob)
    hkStroke.Color = M.Style.Bg; hkStroke.Thickness = 1.5

    local toolRow = Instance.new("Frame", c)
    toolRow.Size = UDim2.new(1, -24, 0, 28)
    toolRow.Position = UDim2.new(0, 12, 0, 82)
    toolRow.BackgroundTransparency = 1

    local hexBox = Instance.new("TextBox", toolRow)
    hexBox.Size = UDim2.new(0, 68, 0, 22); hexBox.Position = UDim2.new(0, 0, 0.5, -11)
    hexBox.BackgroundColor3 = M.Style.Field; hexBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    hexBox.Font = Enum.Font.GothamBold; hexBox.TextSize = 11; hexBox.Text = "#" .. M.State[stateColorKey]:ToHex():upper()
    hexBox.ClearTextOnFocus = false; hexBox.BorderSizePixel = 0
    Instance.new("UICorner", hexBox).CornerRadius = UDim.new(0, 6)
    local hexStroke = M.Style.AddStroke(hexBox, M.Style.Stroke, 1, M.Style.StrokeIdle)
    hexBox.Focused:Connect(function() M.Style.Tween(hexStroke, 0.2, {Color = M.State.Accent, Transparency = M.Style.StrokeActive}) end)
    hexBox.FocusLost:Connect(function() M.Style.Tween(hexStroke, 0.25, {Color = M.Style.Stroke, Transparency = M.Style.StrokeIdle}) end)

    local btnClear = Instance.new("TextButton", toolRow)
    btnClear.Size = UDim2.new(0, 22, 0, 22); btnClear.Position = UDim2.new(0, 72, 0.5, -11)
    btnClear.BackgroundColor3 = M.Style.Raised; btnClear.Text = "×"
    btnClear.TextColor3 = Color3.fromRGB(220, 225, 240); btnClear.Font = Enum.Font.GothamBold; btnClear.TextSize = 13
    Instance.new("UICorner", btnClear).CornerRadius = UDim.new(0, 6); M.F.DecorateButton(btnClear)

    -- кнопки «копировать» и «вставить»
    local ICON_COL, BTN_COL = Color3.fromRGB(220, 225, 240), M.Style.Raised
    local function iconBox(parent, x, y, w, h, filled)
        local f = Instance.new("Frame", parent)
        f.Size = UDim2.new(0, w, 0, h); f.Position = UDim2.new(0, x, 0, y); f.BorderSizePixel = 0
        f.Active = false
        if filled then
            f.BackgroundColor3 = ICON_COL
        else
            f.BackgroundColor3 = BTN_COL
            local st = Instance.new("UIStroke", f); st.Color = ICON_COL; st.Thickness = 1
        end
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 2)
        return f
    end

    local btnCopy = Instance.new("TextButton", toolRow)
    btnCopy.Size = UDim2.new(0, 22, 0, 22); btnCopy.Position = UDim2.new(0, 98, 0.5, -11)
    btnCopy.BackgroundColor3 = BTN_COL; btnCopy.Text = ""; btnCopy.AutoButtonColor = true
    Instance.new("UICorner", btnCopy).CornerRadius = UDim.new(0, 6); M.F.DecorateButton(btnCopy)
    iconBox(btnCopy, 4, 3, 10, 11, false)  -- задний лист
    iconBox(btnCopy, 8, 8, 10, 11, false)  -- передний лист

    local btnPaste = Instance.new("TextButton", toolRow)
    btnPaste.Size = UDim2.new(0, 22, 0, 22); btnPaste.Position = UDim2.new(0, 124, 0.5, -11)
    btnPaste.BackgroundColor3 = BTN_COL; btnPaste.Text = ""; btnPaste.AutoButtonColor = true
    Instance.new("UICorner", btnPaste).CornerRadius = UDim.new(0, 6); M.F.DecorateButton(btnPaste)
    iconBox(btnPaste, 5, 5, 12, 14, false)  -- планшет
    iconBox(btnPaste, 8, 3, 6, 4, true)  -- зажим
    iconBox(btnPaste, 8, 10, 6, 1, true)  -- строки
    iconBox(btnPaste, 8, 13, 6, 1, true)

    local quickSlots = {}
    local slotSize, slotGap = 22, 6

    for i = 1, 5 do
        local slot = Instance.new("TextButton", toolRow)
        slot.Size = UDim2.new(0, slotSize, 0, slotSize)
        slot.Position = UDim2.new(1, -((5 - i + 1) * (slotSize + slotGap)), 0.5, -11)
        slot.BackgroundColor3 = M.Style.Card
        slot.BorderSizePixel = 0
        slot.Text = ""
        slot.AutoButtonColor = false
        Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 6)

        local sStroke = Instance.new("UIStroke", slot)
        sStroke.Color = M.Style.Stroke
        sStroke.Thickness = 1
        slot.MouseEnter:Connect(function() M.Style.Tween(sStroke, 0.15, {Color = M.State.Accent}) end)
        slot.MouseLeave:Connect(function() M.Style.Tween(sStroke, 0.2, {Color = M.Style.Stroke}) end)

        local icon = Instance.new("TextLabel", slot)
        icon.Size = UDim2.new(1, 0, 1, 0); icon.BackgroundTransparency = 1
        icon.Text = "+"
        icon.TextColor3 = M.Style.TextDim
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
                slotData.Stroke.Color = M.Style.TextMute
            else
                slotData.Btn.BackgroundColor3 = M.Style.Card
                slotData.Icon.Text = "+"
                slotData.Stroke.Color = M.Style.Stroke
            end
        end
    end

    table.insert(M.Data.PaletteCallers, refreshSlotVisuals)
    refreshSlotVisuals()

    local function setVisual(colorObj, keepHsv)
        if not keepHsv then
            local h, sat, val = colorObj:ToHSV()
            cH = M.ColorMath.ResolveHue(cH, h, sat, val)
            cS, cV = sat, val
        end
        cv.BackgroundColor3 = Color3.fromHSV(cH, 1, 1)
        prevBox.BackgroundColor3 = colorObj
        prevGlow.SetColor(colorObj)
        pin.Position = UDim2.new(math.clamp(cS, 0, 1), 0, math.clamp(1 - cV, 0, 1), 0)
        hueKnob.Position = UDim2.new(math.clamp(cH, 0, 1), 0, 0.5, 0)
        if not hexBox:IsFocused() then hexBox.Text = "#" .. colorObj:ToHex():upper() end
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
        if type(str) ~= "string" then return false end
        local hex = str:match("%x%x%x%x%x%x")
        if not hex then
            local short = str:match("#(%x%x%x)%f[^%x]") or str:match("^%s*(%x%x%x)%s*$")
            if short then hex = short:gsub(".", function(ch) return ch .. ch end) end
        end
        if hex then
            local succ, parsed = pcall(Color3.fromHex, hex)
            if succ and parsed then applyColor(parsed); return true end
        end
        local r, g, b = str:match("(%d+)%s*[,;%s]%s*(%d+)%s*[,;%s]%s*(%d+)")
        r, g, b = tonumber(r), tonumber(g), tonumber(b)
        if r and g and b and r <= 255 and g <= 255 and b <= 255 then
            applyColor(Color3.fromRGB(r, g, b))
            return true
        end
        return false
    end

    local function selectAllHex()
        task.defer(function()
            if not hexBox.Parent then return end
            hexBox:CaptureFocus()
            task.defer(function()
                pcall(function()
                    hexBox.CursorPosition = #hexBox.Text + 1
                    hexBox.SelectionStart = 1
                end)
            end)
        end)
    end

    local function flash(btn, state)
        local col = M.Style.Danger:Lerp(BTN_COL, 0.55)
        if state == true then col = M.Style.Success:Lerp(BTN_COL, 0.55)
        elseif state == "manual" then col = M.Style.Warn:Lerp(BTN_COL, 0.55) end
        btn.BackgroundColor3 = col
        M.Style.Tween(btn, 0.9, {BackgroundColor3 = BTN_COL}, Enum.EasingStyle.Quad)
    end

    hexBox.FocusLost:Connect(function()
        tryHexInput(hexBox.Text)
        hexBox.Text = "#" .. M.State[stateColorKey]:ToHex():upper()
    end)

    hexBox:GetPropertyChangedSignal("Text"):Connect(function()
        if not hexBox:IsFocused() then return end
        local clean = hexBox.Text:gsub("%s+", "")
        if clean:match("^#?%x%x%x%x%x%x$") then tryHexInput(clean) end
    end)

    btnClear.MouseButton1Click:Connect(function()
        hexBox.Text = ""
        hexBox:CaptureFocus()
    end)

    -- копирование
    btnCopy.MouseButton1Click:Connect(function()
        local text = "#" .. M.State[stateColorKey]:ToHex():upper()
        local copied = false
        for _, fn in ipairs(clipboardWriters()) do
            if pcall(fn, text) then copied = true; break end
        end
        if copied then
            flash(btnCopy, true)
        else
            hexBox.Text = text
            selectAllHex()
            flash(btnCopy, "manual")
        end
    end)

    btnPaste.MouseButton1Click:Connect(function()
        local text
        for _, fn in ipairs(clipboardReaders()) do
            local ok, result = pcall(fn)
            if ok and type(result) == "string" then text = result; break end
        end
        if text then
            flash(btnPaste, tryHexInput(text))
        else
            hexBox.Text = ""
            selectAllHex()
            flash(btnPaste, "manual")
        end
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
        SetLanguage = function()
            l.Text = M.Translate(locKey)
        end,
        Callback = cb
    })
    return c
end

end}

-- [58/69] Построение меню: списки, пресеты, язык
MODULES[#MODULES + 1] = {"58. Построение меню: списки, пресеты, язык", function(M, __X)
-- названия вариантов
local function optionLabel(opt)
    local key = "Opt_" .. tostring(opt)
    if M.L10N.Dict[key] then return M.Translate(key) end
    return tostring(opt)
end

function M.F.MakeDropdown(parent, locKey, options, stateKey, order, cb)
    local c = M.F.MakeCard(parent, 40); c.LayoutOrder = order
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(0.45, 0, 1, 0); l.Position = UDim2.new(0, 12, 0, 0); l.BackgroundTransparency = 1
    l.Text = M.Translate(locKey); l.TextColor3 = M.Style.Text; l.Font = Enum.Font.GothamMedium; l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left

    local b = Instance.new("TextButton", c)
    b.Size = UDim2.new(0, 115, 0, 24); b.Position = UDim2.new(1, -125, 0.5, -12); b.BackgroundColor3 = M.Style.Raised; b.Text = optionLabel(M.State[stateKey]); b.TextColor3 = M.Style.Text; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7); M.F.DecorateButton(b)

    -- список раскрывается плавно
    local fullHeight = #options * 26
    local drop = Instance.new("Frame", c)
    drop.Size = UDim2.new(0, 115, 0, 0); drop.Position = UDim2.new(1, -125, 1, 2); drop.BackgroundColor3 = M.Style.Surface; drop.Visible = false; drop.ZIndex = 15
    drop.ClipsDescendants = true
    Instance.new("UICorner", drop).CornerRadius = UDim.new(0, 8); Instance.new("UIListLayout", drop)
    M.Style.Bind(M.Style.AddStroke(drop, M.State.Accent, 1, M.Style.StrokeActive), "Color")  -- обводка списка следует за цветом темы
    -- стрелка справа в кнопке
    Instance.new("UIPadding", b).PaddingRight = UDim.new(0, 14)
    local chevron = Instance.new("TextLabel")
    chevron.Size = UDim2.new(0, 12, 1, 0)
    chevron.BackgroundTransparency = 1
    -- обычный символ ">"
    chevron.AnchorPoint = Vector2.new(1, 0.5)
    chevron.Position = UDim2.new(1, 12, 0.5, 0)
    chevron.Text = ">"
    chevron.Font = Enum.Font.GothamBold
    chevron.TextSize = 12
    chevron.TextScaled = true
    chevron.TextColor3 = M.Style.TextMute
    chevron.Rotation = 90
    Instance.new("UITextSizeConstraint", chevron).MaxTextSize = 12
    chevron.Parent = b
    local dropOpen, dropToken = false, 0
    local function setDrop(open)
        dropOpen = open
        dropToken = dropToken + 1
        local token = dropToken
        M.Style.Tween(chevron, 0.3, {Rotation = open and 270 or 90, TextColor3 = open and M.State.Accent or M.Style.TextMute}, Enum.EasingStyle.Back)
        if open then
            drop.Visible = true
            M.Style.Tween(drop, 0.34, {Size = UDim2.new(0, 115, 0, fullHeight)}, Enum.EasingStyle.Back)
        else
            local tween = M.Style.Tween(drop, 0.2, {Size = UDim2.new(0, 115, 0, 0)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            tween.Completed:Connect(function()
                if token == dropToken and not dropOpen then drop.Visible = false end
            end)
        end
    end

    local optionButtons = {}
    b.MouseButton1Click:Connect(function() setDrop(not dropOpen) end)
    for _, opt in ipairs(options) do
        local ob = Instance.new("TextButton", drop)
        ob.Size = UDim2.new(1, 0, 0, 26); ob.BackgroundColor3 = M.Style.Raised; ob.BackgroundTransparency = 1; ob.Text = optionLabel(opt); ob.TextColor3 = M.Style.TextDim; ob.Font = Enum.Font.Gotham; ob.TextSize = 12; ob.ZIndex = 16
        ob.AutoButtonColor = false
        optionButtons[opt] = ob
        ob.MouseEnter:Connect(function() M.Style.Tween(ob, 0.15, {BackgroundTransparency = 0.2, TextColor3 = M.Style.Text}) end)
        ob.MouseLeave:Connect(function() M.Style.Tween(ob, 0.2, {BackgroundTransparency = 1, TextColor3 = M.Style.TextDim}) end)
        ob.MouseButton1Click:Connect(function()
            b.Text = optionLabel(opt)
            setDrop(false)
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

-- ряд из нескольких кнопок
function M.F.MakePresetRow(parent, order, items, onPick)
    local c = M.F.MakeCard(parent, 46)
    c.LayoutOrder = order
    local count = #items
    local buttons = {}
    for i, item in ipairs(items) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1 / count, -8, 0, 30)
        b.Position = UDim2.new((i - 1) / count, 6, 0.5, -15)
        b.BackgroundColor3 = M.Style.Raised
        b.AutoButtonColor = false
        b.Text = M.Translate(item.Key)
        b.TextColor3 = M.Style.Text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 9)
        bc.Parent = b
        b.Parent = c
        M.F.DecorateButton(b, true)
        local presetScale = b:FindFirstChild("ButtonScale")

        b.MouseEnter:Connect(function()
            M.Style.Tween(b, 0.18, {BackgroundColor3 = M.State.Accent:Lerp(M.Style.Raised, 0.8), TextColor3 = M.Style.AccentMix(0.55)})
        end)
        b.MouseLeave:Connect(function()
            M.Style.Tween(b, 0.25, {BackgroundColor3 = M.Style.Raised, TextColor3 = M.Style.Text})
            M.Style.Tween(presetScale, 0.2, {Scale = 1})
        end)
        b.MouseButton1Down:Connect(function() M.Style.Tween(presetScale, 0.1, {Scale = 0.95}) end)
        b.MouseButton1Up:Connect(function() M.Style.Tween(presetScale, 0.3, {Scale = 1}, Enum.EasingStyle.Back) end)
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

function M.F.UpdateLanguageUI()
    for _, item in ipairs(M.Data.RegUI) do if item.SetLanguage then item.SetLanguage() end end
    M.F.RefitChanged()
end

end}

-- [59/69] Конфиги
MODULES[#MODULES + 1] = {"59. Конфиги", function(M, __X)
-- ==============================================================================
-- [ КОНФИГИ ]
-- ==============================================================================

-- тумблеры, которые после перезахода всегда выключены, и место окна подтверждения
M.CFG.RuntimeKeys = {
    FlightMode = true, SpectateOn = true, FreecamOn = true,
    ConfirmX = true, ConfirmY = true
}

function M.CFG.IsRuntimeKey(k)
    return M.CFG.RuntimeKeys[k] == true
end

-- значение из конфига, которого нет в списке вариантов, заменяется значением по умолчанию
M.CFG.Defaults = {}
for k, v in pairs(M.State) do M.CFG.Defaults[k] = v end

function M.CFG.ValidOption(key, value)
    local options = M.Schema.Options[key]
    return options == nil or table.find(options, value) ~= nil
end

-- прежние названия настроек из старых сохранённых конфигов
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
    JitterSpin = "JerkySpin",
    KinematicBoost = "FlightSpeed",
    Levitation = "FlightMode",
    PhaseCollision = "WalkThroughWalls",
    PitchModification = "HeadTiltOn",
    RotationYaw = "SpinCharacter",
    StateForce = "FallProtection",
    PillShowMinsk = "PillShowClock",
    SpotifyOn = "MusicOn",
    SpotifyMode = "MusicMode",
    SpotifyLayout = "MusicLayout",
}

-- версия формата конфига
M.CFG.FormatVersion = 1

function M.CFG.GetExportData()
    local data = {__Version = M.CFG.FormatVersion}
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
    -- клавиши биндов: id бинда -> имя клавиши
    local binds = {}
    local modes = {}
    for _, b in ipairs(M.Data.Binds) do
        if b.Id and b.Key then binds[b.Id] = b.Key.Name end
        if b.Id and b.Mode == "Hold" then modes[b.Id] = "Hold" end
    end
    data["__Binds"] = binds
    data["__BindModes"] = modes
    if M.UI.Pill then
        data["__PillPos"] = {XS = M.UI.Pill.Position.X.Scale, XO = M.UI.Pill.Position.X.Offset, YS = M.UI.Pill.Position.Y.Scale, YO = M.UI.Pill.Position.Y.Offset}
    end
    if M.UI.Main then
        data["__MainPos"] = {XS = M.UI.Main.Position.X.Scale, XO = M.UI.Main.Position.X.Offset, YS = M.UI.Main.Position.Y.Scale, YO = M.UI.Main.Position.Y.Offset}
        data["__MainSize"] = {X = M.UI.Main.Size.X.Offset, Y = M.UI.Main.Size.Y.Offset}
    end
    return data
end

-- функции, которые меняют движение, физику или выполняют действия за вас
M.CFG.ManualStartKeys = {
    FlightMode = true, Speed = true, WalkThroughWalls = true, InfiniteJumps = true, AutoJump = true, AirControl = true, PeekOn = true,
    TriggerAssist = true, TriggerLoop = true, AimAssist = true, FallProtection = true,
    AntiStun = true, SpinCharacter = true, BackWalk = true, FreezeChar = true, FakeLag = true, HeadTiltOn = true, FpsBoost = true, FpsUnlocker = true
}

function M.CFG.ApplyImportDataInner(data)
    if type(data) ~= "table" then return end
    M.F.BuildAllPages(true)
    -- пока страницы строились
    if M.Run.IsShutDown then return end

    local migrated = {}
    for k, v in pairs(data) do
        local newKey = M.CFG.LegacyKeys[k]
        if newKey ~= nil and data[newKey] == nil and M.State[k] == nil then
            migrated[newKey] = v
        else
            migrated[k] = v
        end
    end
    data = migrated

    -- спокойный старт
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

    for k, v in pairs(data) do
        if type(k) == "string" and M.State[k] ~= nil and not M.CFG.IsRuntimeKey(k) then
            local current = M.State[k]
            if type(v) == "table" then
                if v.__type == "Color3" and type(v.hex) == "string" and #v.hex <= 9 and typeof(current) == "Color3" then
                    local ok, color = pcall(Color3.fromHex, v.hex)
                    if ok then M.State[k] = color end
                end
            elseif type(v) == type(current) and M.CFG.IsPlainData(v) then
                if M.CFG.ValidOption(k, v) then M.State[k] = v else M.State[k] = M.CFG.Defaults[k] end
            end
        end
    end

    -- бинды: в старых конфигах их нет, тогда текущие остаются
    if type(data["__Binds"]) == "table" then
        local wanted = data["__Binds"]
        local modes = type(data["__BindModes"]) == "table" and data["__BindModes"] or {}
        for _, b in ipairs(M.Data.Binds) do
            local name = b.Id and wanted[b.Id]
            if b.HeldOn then pcall(M.F.BindRelease, b) end
            b.Key = M.F.KeyFromName(name)
            b.Mode = (b.Id and modes[b.Id] == "Hold") and "Hold" or "Toggle"
            if b.Show then b.Show() end
        end
    end

    for _, el in ipairs(M.Data.RegUI) do
        if el.Min and el.Max and el.Key and type(M.State[el.Key]) == "number" then
            local value = M.State[el.Key]
            if value ~= value then value = el.Min end  -- NaN
            M.State[el.Key] = math.clamp(value, el.Min, el.Max)
        end
    end

    -- число из таблицы позиции
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
    end
    if type(data["__MainSize"]) == "table" and M.UI.Main then
        local ms, old = data["__MainSize"], M.UI.Main.Size
        M.UI.Main.Size = UDim2.new(0, safeNumber(ms, "X", 600, 960, old.X.Offset), 0, safeNumber(ms, "Y", 420, 760, old.Y.Offset))
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
    M.F.PillSetColor(M.State.PillTextCol)

    if M.UI.MenuBg then
        M.UI.MenuBg.BackgroundColor3 = M.State.MainBg
        M.UI.MenuBg.BackgroundTransparency = M.State.MenuAlpha
    end
    M.UI.Sidebar.BackgroundColor3 = M.State.SideBg
    M.UI.Sidebar.BackgroundTransparency = M.State.SideAlpha
    M.UI.MainStroke.Color = M.State.BorderCol
    M.UI.MainStroke.Thickness = M.State.BorderThick
    M.UI.SideStroke.Color = M.State.BorderCol
    M.UI.SideStroke.Thickness = M.State.BorderThick

    for _, c in ipairs(M.UI.Cards) do
        c.BackgroundColor3 = M.State.CardBg
        c.BackgroundTransparency = M.State.CardAlpha
    end
    for _, sc in ipairs(M.UI.SideCards) do
        sc.BackgroundColor3 = M.State.SideCardBg
        sc.BackgroundTransparency = M.State.SideCardAlpha
    end

    M.F.SetWallPass(M.State.WalkThroughWalls)
    M.F.ApplyDark()
    M.F.ApplyFog()
    M.F.ApplyClouds()
    M.F.RefreshOptimization()
    M.ApplyFpsUnlocker(M.State.FpsUnlocker)
    M.F.UpdatePlayerView()
    M.UpdatePlayerVisuals()
    if M.State.OrbitOn then M.F.RebuildOrbits() end
    if not M.UI.Pages[M.State.ActiveTab] then M.State.ActiveTab = "Combat" end
    M.F.SwitchTab(M.State.ActiveTab)
end

-- обёртка
function M.CFG.ApplyImportData(data)
    M.Data.Importing = true
    local ok, err = pcall(M.CFG.ApplyImportDataInner, data)
    M.Data.Importing = false
    if not ok then M.Errors.Hit("ConfigLoad", err) end
end

-- запись на диск
M.CFG.FilePath = "Matsysense_Configs.json"
M.CFG.MaxFileBytes = 1000000
M.CFG.MaxNameLength = 64

-- данные из файла
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

-- оставляет из прочитанного файла только допустимые записи
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
    return M.Cap.All("writefile", "readfile", "isfile")
end

-- сохраняет все конфиги в файл
function M.CFG.FlushToFile()
    if not M.CFG.DiskAvailable() then return false end
    local isfile, readfile, writefile = M.Cap.Fn("isfile"), M.Cap.Fn("readfile"), M.Cap.Fn("writefile")
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

-- читает конфиги из файла
function M.CFG.LoadFromFile()
    if not M.CFG.DiskAvailable() then return false end
    local isfile, readfile = M.Cap.Fn("isfile"), M.Cap.Fn("readfile")
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

-- сохраняет конфиг. Возвращает: успех, записано ли на диск
function M.CFG.Save(name)
    name = (name and name ~= "") and name or "default"
    M.Data.MemStorage[name] = M.CFG.GetExportData()
    return true, M.CFG.FlushToFile()
end

function M.CFG.Load(name)
    name = (name and name ~= "") and name or "default"
    M.CFG.LoadFromFile()
    local data = M.Data.MemStorage[name]
    if data then
        M.CFG.ApplyImportData(data)
        return true
    end
    return false
end

function M.CFG.Delete(name)
    name = (name and name ~= "") and name or "default"
    if M.Data.MemStorage[name] then
        M.Data.MemStorage[name] = nil
        M.CFG.FlushToFile()
        return true
    end
    return false
end

function M.CFG.SetAutoload(name)
    M.Data.MemStorage["__AUTOLOAD"] = name or "default"
    return M.CFG.FlushToFile()
end

function M.CFG.CheckAutoload()
    if M.Run.IsShutDown then return end
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

function M.CFG.List()
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

end}

-- [60/69] Вкладки и страницы: создание
MODULES[#MODULES + 1] = {"60. Вкладки и страницы: создание", function(M, __X)
-- ==============================================================================
-- [ СТРАНИЦЫ МЕНЮ ]
-- ==============================================================================
M.F.MakeTabBtn("Tab_Combat", 1)
M.F.MakeTabBtn("Tab_Movement", 2)
M.F.MakeTabBtn("Tab_Display", 3)
M.F.MakeTabBtn("Tab_Camera", 4)
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

__X.pCam = pCam
__X.pCfg = pCfg
__X.pCombat = pCombat
__X.pDisplay = pDisplay
__X.pExp = pExp
__X.pMisc = pMisc
__X.pPlyr = pPlyr
__X.pSet = pSet
__X.pSys = pSys
__X.pWrld = pWrld
end}

-- [61/69] Поиск по меню, страница «Бой»
MODULES[#MODULES + 1] = {"61. Поиск по меню, страница «Бой»", function(M, __X)
local pCombat = __X.pCombat
-- ==============================================================================
-- [ ПОИСК ПО МЕНЮ ]
-- ==============================================================================
do
    local SEARCH_TABS = {"Combat", "Movement", "Display", "Camera", "World", "Player", "Misc", "System", "Configs", "Settings"}
    local tabRank = {}
    for i, n in ipairs(SEARCH_TABS) do tabRank[n] = i end
    local st = {Index = nil, Dirty = true, Building = false, Shown = false, Query = ""}
    M.Data.Search = st

    local pack = M.F.CreatePage("Search")
    local resultsPage = M.UI.Pages.Search

    local bar = Instance.new("Frame")
    bar.Name = "SearchBar"
    bar.Size = UDim2.new(0.75, -92, 0, 28)
    bar.Position = UDim2.new(0.25, 8, 0, 8)
    bar.BackgroundColor3 = M.Style.Field
    bar.BorderSizePixel = 0
    bar.ZIndex = 20
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 9)
    local barStroke = M.Style.AddStroke(bar, M.Style.Stroke, 1, M.Style.StrokeIdle)
    bar.Parent = M.UI.Main

    local box = Instance.new("TextBox")
    box.Name = "SearchBox"
    box.Size = UDim2.new(1, -40, 1, 0)
    box.Position = UDim2.new(0, 10, 0, 0)
    box.BackgroundTransparency = 1
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 12
    box.TextColor3 = M.Style.Text
    box.PlaceholderText = M.Translate("SearchHint")
    box.PlaceholderColor3 = Color3.fromRGB(105, 114, 135)
    box.Text = ""
    box.ZIndex = 21
    box.Parent = bar
    st.Box = box

    local clear = Instance.new("TextButton")
    clear.Size = UDim2.new(0, 22, 0, 22)
    clear.AnchorPoint = Vector2.new(1, 0.5)
    clear.Position = UDim2.new(1, -4, 0.5, 0)
    clear.BackgroundTransparency = 1
    clear.AutoButtonColor = false
    clear.Text = "x"
    clear.Font = Enum.Font.GothamBold
    clear.TextSize = 13
    clear.TextColor3 = M.Style.TextMute
    clear.Visible = false
    clear.ZIndex = 22
    clear.Parent = bar

    bar.MouseEnter:Connect(function() M.Data.SearchHover = true end)
    bar.MouseLeave:Connect(function() M.Data.SearchHover = false end)
    box.Focused:Connect(function()
        st.Dirty = true
        M.Style.Tween(barStroke, 0.2, {Color = M.State.Accent, Transparency = M.Style.StrokeActive})
    end)
    box.FocusLost:Connect(function()
        M.Style.Tween(barStroke, 0.25, {Color = M.Style.Stroke, Transparency = M.Style.StrokeIdle})
    end)
    clear.MouseEnter:Connect(function() M.Style.Tween(clear, 0.15, {TextColor3 = M.Style.Text}) end)
    clear.MouseLeave:Connect(function() M.Style.Tween(clear, 0.2, {TextColor3 = M.Style.TextMute}) end)
    clear.MouseButton1Click:Connect(function() box.Text = "" end)
    table.insert(M.Data.RegUI, {SetLanguage = function() box.PlaceholderText = M.Translate("SearchHint") end})

    -- список всех настроек
    function M.F.SearchBuildIndex()
        local list = {}
        for tab, p in pairs(M.UI.Pages) do
            if tab ~= "Search" then
                local kids = {}
                for _, ch in ipairs(p.Container:GetChildren()) do
                    if ch:IsA("Frame") then kids[#kids + 1] = ch end
                end
                table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
                local section = ""
                for _, card in ipairs(kids) do
                    if card:FindFirstChild("Hover") == nil then
                        -- заголовок раздела: единственная надпись
                        local lbl = card:FindFirstChildOfClass("TextLabel")
                        if lbl then section = lbl.Text end
                    elseif card.Visible then
                        local texts, display = {}, nil
                        for _, d in ipairs(card:GetDescendants()) do
                            if d:IsA("TextLabel") then
                                local tx = d.Text
                                if tx ~= "" and (utf8.len(tx) or 0) >= 2 and not tonumber(tx) then
                                    texts[#texts + 1] = tx
                                    display = display or tx
                                end
                            end
                        end
                        if not display then
                            for _, d in ipairs(card:GetDescendants()) do
                                if d:IsA("TextButton") and d.Text ~= "" and (utf8.len(d.Text) or 0) >= 2 then
                                    texts[#texts + 1] = d.Text
                                    display = display or d.Text
                                end
                            end
                        end
                        if display then
                            display = string.match(display, "^%s*(.-)%s*$")
                            list[#list + 1] = {Tab = tab, Card = card, Display = display, Section = section,
                                Low = M.Lower(table.concat(texts, " ")), LowDisplay = M.Lower(display),
                                Rank = tabRank[tab] or 99, Order = card.LayoutOrder}
                        end
                    end
                end
            end
        end
        st.Index = list
        st.Dirty = false
    end

    -- подходящие записи
    function M.F.SearchMatch(query)
        local tokens = {}
        for w in string.gmatch(M.Lower(query), "%S+") do tokens[#tokens + 1] = w end
        if #tokens == 0 then return {} end
        local found = {}
        for _, e in ipairs(st.Index or {}) do
            local ok, score = true, 2
            for i, w in ipairs(tokens) do
                if not string.find(e.Low, w, 1, true) then ok = false break end
                if i == 1 then
                    local pos = string.find(e.LowDisplay, w, 1, true)
                    if pos == 1 then score = 0 elseif pos then score = 1 end
                end
            end
            if ok then
                e.Score = score
                found[#found + 1] = e
            end
        end
        table.sort(found, function(a, b)
            if a.Score ~= b.Score then return a.Score < b.Score end
            if a.Rank ~= b.Rank then return a.Rank < b.Rank end
            return a.Order < b.Order
        end)
        return found
    end

    local function clearResults()
        for _, ch in ipairs(pack:GetChildren()) do
            if ch:IsA("GuiObject") then ch:Destroy() end
        end
    end

    local function noteRow(text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 30)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = M.Style.TextMute
        l.Font = Enum.Font.GothamMedium
        l.TextSize = 12
        l.Parent = pack
    end

    -- открыть найденную настройку
    function M.F.SearchGo(entry)
        box.Text = ""
        local card = entry.Card
        if not card or not card.Parent then return end
        M.F.SwitchTab(entry.Tab)
        task.delay(0.12, function()
            local p = M.UI.Pages[entry.Tab]
            if not p or not card.Parent then return end
            local sf = p.Frame
            local y = card.AbsolutePosition.Y - p.Container.AbsolutePosition.Y
            local maxY = math.max(sf.AbsoluteCanvasSize.Y - sf.AbsoluteWindowSize.Y, 0)
            sf.CanvasPosition = Vector2.new(0, math.clamp(y - 24, 0, maxY))
            local glow = card:FindFirstChild("Hover")
            if glow then
                glow.BackgroundColor3 = M.State.Accent
                glow.BackgroundTransparency = 0.55
                M.Style.Tween(glow, 1.3, {BackgroundTransparency = 1})
            end
        end)
    end

    local function showResults(on)
        if on then
            if not st.Shown then resultsPage.Frame.CanvasPosition = Vector2.zero end
            st.Shown = true
            for n, p in pairs(M.UI.Pages) do p.Frame.Visible = (n == "Search") end
        elseif st.Shown then
            st.Shown = false
            resultsPage.Frame.Visible = false
            M.F.SwitchTab(M.State.ActiveTab)
        end
    end

    function M.F.SearchRun(query)
        st.Query = query
        local text = string.match(query, "^%s*(.-)%s*$") or ""
        clear.Visible = query ~= ""
        if text == "" then
            clearResults()
            showResults(false)
            return
        end
        showResults(true)
        clearResults()
        if next(M.Data.PageBuilders) then
            noteRow(M.Translate("SearchBusy"))
            if not st.Building then
                st.Building = true
                task.spawn(function()
                    M.F.BuildAllPages(true)
                    st.Building = false
                    st.Dirty = true
                    if st.Shown and not M.Run.IsShutDown then M.F.SearchRun(box.Text) end
                end)
            end
            return
        end
        if st.Dirty or not st.Index then M.F.SearchBuildIndex() end
        local found = M.F.SearchMatch(text)
        if #found == 0 then
            noteRow(M.Translate("SearchNone"))
            return
        end
        for i = 1, math.min(#found, 40) do
            local e = found[i]
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 46)
            b.LayoutOrder = i
            b.AutoButtonColor = false
            b.Text = ""
            b.BackgroundColor3 = M.State.CardBg
            b.BackgroundTransparency = M.State.CardAlpha
            b.BorderSizePixel = 0
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 11)
            local stroke = M.Style.AddStroke(b, M.Style.Stroke, 1, M.Style.StrokeIdle)
            local l1 = Instance.new("TextLabel")
            l1.Size = UDim2.new(1, -24, 0, 20)
            l1.Position = UDim2.new(0, 12, 0, 5)
            l1.BackgroundTransparency = 1
            l1.Text = e.Display
            l1.TextColor3 = M.Style.Text
            l1.Font = Enum.Font.GothamMedium
            l1.TextSize = 13
            l1.TextXAlignment = Enum.TextXAlignment.Left
            l1.Parent = b
            local l2 = Instance.new("TextLabel")
            l2.Size = UDim2.new(1, -24, 0, 14)
            l2.Position = UDim2.new(0, 12, 0, 26)
            l2.BackgroundTransparency = 1
            l2.Text = M.Translate("Tab_" .. e.Tab) .. (e.Section ~= "" and ("  >  " .. e.Section) or "")
            l2.TextColor3 = M.Style.TextMute
            l2.Font = Enum.Font.Gotham
            l2.TextSize = 10
            l2.TextXAlignment = Enum.TextXAlignment.Left
            l2.Parent = b
            b.MouseEnter:Connect(function()
                M.Style.Tween(stroke, 0.18, {Color = M.State.Accent, Transparency = M.Style.StrokeActive})
            end)
            b.MouseLeave:Connect(function()
                M.Style.Tween(stroke, 0.22, {Color = M.Style.Stroke, Transparency = M.Style.StrokeIdle})
            end)
            b.MouseButton1Click:Connect(function() M.F.SearchGo(e) end)
            b.Parent = pack
        end
    end

    box:GetPropertyChangedSignal("Text"):Connect(function() M.F.SearchRun(box.Text) end)
    resultsPage.Frame.Visible = false
end
-- порядок во всех вкладках
M.Data.PageBuilders.Combat = function()
local order = 0
local function nx() order = order + 1 return order end
local function resetLock() M.Data.AimLock = nil end

-- доводка
M.F.MakeSection(pCombat, "Sec_AimAssist", nx())
M.F.MakeToggle(pCombat, "AimAssist", "AimAssist", nx(), function() end, true)
M.F.MakePresetRow(pCombat, nx(), {
    {Key = "Preset_AimSoft", Id = "Soft"}, {Key = "Preset_AimBalanced", Id = "Balanced"},
    {Key = "Preset_AimHard", Id = "Hard"}, {Key = "Preset_AimSniper", Id = "Sniper"},
}, function(id) M.F.ApplyAimPreset(id) end)
-- строки, которые сейчас не нужны
local aimKeyRow, mouseGainRow, mouseAutoRow
M.F.MakeDropdown(pCombat, "AimMode", M.Schema.Options.AimMode, "AimMode", nx(), function(opt)
    resetLock()
    if aimKeyRow then aimKeyRow.Visible = (opt == "HoldKey") end
end)
aimKeyRow = M.F.MakeKeyRow(pCombat, "AimKey", "AimKey", nx())
aimKeyRow.Visible = M.State.AimMode == "HoldKey"
M.F.MakeDropdown(pCombat, "AimPart", M.Schema.Options.AimPart, "AimPart", nx(), resetLock)
M.F.MakeDropdown(pCombat, "AimPriority", M.Schema.Options.AimPriority, "AimPriority", nx(), resetLock)
M.F.MakeToggle(pCombat, "AimSticky", "AimSticky", nx(), resetLock, false)
M.F.MakeSlider(pCombat, "AimFov", "AimFov", nx(), function() end)
M.F.MakeToggle(pCombat, "AimTeamCheck", "AimTeamCheck", nx(), function() end, false)
M.F.MakeToggle(pCombat, "AimWallCheck", "AimWallCheck", nx(), function() end, false)
M.F.MakeToggle(pCombat, "AimNpcs", "AimNpcs", nx(), resetLock, true)

-- движение прицела: метод, плавность, мёртвая зона, упреждение
M.F.MakeSection(pCombat, "Sec_AimMotion", nx())
M.F.MakeDropdown(pCombat, "AimMethod", M.Schema.Options.AimMethod, "AimMethod", nx(), function(opt)
    M.Data.AimLock = nil
    M.Data.AimAccX, M.Data.AimAccY = 0, 0
    if mouseGainRow then mouseGainRow.Visible = (opt ~= "Camera") end
    if mouseAutoRow then mouseAutoRow.Visible = (opt ~= "Camera") end
    -- исполнитель не умеет двигать мышь
    if opt ~= "Camera" and not M.Data.Importing and not M.F.MouseMoveFn() then
        M.F.Notify("MouseFallback", M.Translate("MouseFallback"), false, true)
    end
end)
M.F.MakeSlider(pCombat, "AimTime", "AimTime", nx(), function() end)
M.F.MakeToggle(pCombat, "AimHumanize", "AimHumanize", nx(), function() M.Data.AimHum = nil end, false)
M.F.MakeToggle(pCombat, "AimLagComp", "AimLagComp", nx(), function() end, false)
mouseAutoRow = M.F.MakeToggle(pCombat, "AimMouseAuto", "AimMouseAuto", nx(), function() M.F.MouseForget() end, false)
mouseAutoRow.Visible = M.State.AimMethod ~= "Camera"
mouseGainRow = M.F.MakeSlider(pCombat, "AimMouseGain", "AimMouseGain", nx(), function() end)
mouseGainRow.Visible = M.State.AimMethod ~= "Camera"
M.F.MakeSlider(pCombat, "AimDeadzone", "AimDeadzone", nx(), function() end)
M.F.MakeToggle(pCombat, "AimOverride", "AimOverride", nx(), function() end, false)

-- упреждение: тумблер и его настройки (настройки видны, только пока тумблер включён)
M.F.MakeSection(pCombat, "Sec_AimLead", nx())
local leadRows = {}
function M.F.UpdateLeadRows()
    for _, row in ipairs(leadRows) do row.Visible = M.State.AimLeadOn == true end
end
M.F.MakeToggle(pCombat, "AimLeadOn", "AimLeadOn", nx(), function() M.Data.AimLead = nil; M.F.UpdateLeadRows() end, true)
leadRows[#leadRows + 1] = M.F.MakeSlider(pCombat, "AimPredict", "AimPredict", nx(), function() end)
leadRows[#leadRows + 1] = M.F.MakeSlider(pCombat, "AimBulletSpeed", "AimBulletSpeed", nx(), function() end)
leadRows[#leadRows + 1] = M.F.MakeToggle(pCombat, "AimBulletDrop", "AimBulletDrop", nx(), function() end, false)
leadRows[#leadRows + 1] = M.F.MakeSlider(pCombat, "AimLeadMax", "AimLeadMax", nx(), function() end)
M.F.UpdateLeadRows()

-- круг области доводки и метка на захваченной цели
M.F.MakeSection(pCombat, "Sec_AimVisual", nx())
M.F.MakeToggle(pCombat, "ShowFov", "ShowFov", nx(), function() end, false)
M.F.MakePicker(pCombat, "FovCol", "FovCol", nx(), function() end)
M.F.MakeToggle(pCombat, "FovFillOn", "FovFillOn", nx(), function() end, false)
M.F.MakeSlider(pCombat, "FovFillAlpha", "FovFillAlpha", nx(), function() end)
M.F.MakeToggle(pCombat, "AimDynamic", "AimDynamic", nx(), function() M.Data.AimDynMul = nil end, false)
M.F.MakeSlider(pCombat, "AimDynStand", "AimDynStand", nx(), function() end)
M.F.MakeSlider(pCombat, "AimDynWalk", "AimDynWalk", nx(), function() end)
M.F.MakeSlider(pCombat, "AimDynJump", "AimDynJump", nx(), function() end)
M.F.MakeToggle(pCombat, "AimDebug", "AimDebug", nx(), function() end, false)
M.F.MakePicker(pCombat, "FovLockCol", "FovLockCol", nx(), function() end)
M.F.MakeSlider(pCombat, "FovThick", "FovThick", nx(), function() end)
M.F.MakeToggle(pCombat, "AimShowTarget", "AimShowTarget", nx(), function() end, false)

-- автовыстрел
M.F.MakeSection(pCombat, "Sec_TriggerAssist", nx())
M.F.MakeToggle(pCombat, "TriggerAssist", "TriggerAssist", nx(), function() end, true)
local triggerKeyRow
M.F.MakeDropdown(pCombat, "TriggerMode", M.Schema.Options.TriggerMode, "TriggerMode", nx(), function(opt)
    if triggerKeyRow then triggerKeyRow.Visible = (opt == "HoldKey") end
end)
triggerKeyRow = M.F.MakeKeyRow(pCombat, "TriggerKey", "TriggerKey", nx())
triggerKeyRow.Visible = M.State.TriggerMode == "HoldKey"
M.F.MakeDropdown(pCombat, "TriggerMethod", M.Schema.Options.TriggerMethod, "TriggerMethod", nx(), function() end)
M.F.MakeDropdown(pCombat, "TriggerPart", M.Schema.Options.TriggerPart, "TriggerPart", nx(), function() end)
M.F.MakeSlider(pCombat, "TriggerRadius", "TriggerRadius", nx(), function() end)
M.F.MakeSlider(pCombat, "TriggerDelay", "TriggerDelay", nx(), function() end)
M.F.MakeSlider(pCombat, "TriggerInterval", "TriggerInterval", nx(), function() end)
M.F.MakeToggle(pCombat, "TriggerLoop", "TriggerLoop", nx(), function() end, false)
M.F.MakeToggle(pCombat, "TriggerHold", "TriggerHold", nx(), function() M.F.TriggerRelease() end, false)
M.F.MakeToggle(pCombat, "TriggerTeamCheck", "TriggerTeamCheck", nx(), function() end, false)
M.F.MakeToggle(pCombat, "TriggerWallCheck", "TriggerWallCheck", nx(), function() end, false)
M.F.MakeToggle(pCombat, "TriggerNpcs", "TriggerNpcs", nx(), function() end, true)

-- общие условия: действуют и на доводку, и на автовыстрел
M.F.MakeSection(pCombat, "Sec_CombatFilters", nx())
M.F.MakeSlider(pCombat, "CombatMaxDist", "CombatMaxDist", nx(), function() end)
M.F.MakeToggle(pCombat, "CombatSkipFF", "CombatSkipFF", nx(), function() end, false)
M.F.MakeToggle(pCombat, "CombatNeedTool", "CombatNeedTool", nx(), function() end, false)
end

end}

-- [62/69] Страницы: движение, отображение игроков, камера (со свободной камерой), окружение
MODULES[#MODULES + 1] = {"62. Страницы: движение, отображение игроков, камера (со свободной камерой), окружение", function(M, __X)
local pCam = __X.pCam
local pDisplay = __X.pDisplay
local pExp = __X.pExp
local pWrld = __X.pWrld
M.Data.PageBuilders.Movement = function()
local order = 0
local function nx() order = order + 1 return order end

M.F.MakeSection(pExp, "Sec_Flight", nx())
M.F.MakeSpeedCard(pExp, "FlightMode", true, nx())
M.F.MakeSlider(pExp, "FlightSpeed", "FlightSpeed", nx(), function() end)
M.F.MakeToggle(pExp, "WalkThroughWalls", "WalkThroughWalls", nx(), M.F.SetWallPass, true)

M.F.MakeSection(pExp, "Sec_Sprint", nx())
M.F.MakeSpeedCard(pExp, "SprintBoost", false, nx())
M.F.MakeSlider(pExp, "SprintSpeed", "SprintSpeed", nx(), function() end)

M.F.MakeSection(pExp, "Sec_AirJump", nx())
M.F.MakeToggle(pExp, "AirControl", "AirControl", nx(), function() end, true)
M.F.MakeSlider(pExp, "AirSpeed", "AirSpeed", nx(), function() end)
M.F.MakeSlider(pExp, "AirAccel", "AirAccel", nx(), function() end)
M.F.MakeToggle(pExp, "InfiniteJumps", "InfiniteJumps", nx(), function() end, true)
M.F.MakeToggle(pExp, "AutoJump", "AutoJump", nx(), function() end, true)

M.F.MakeSection(pExp, "Sec_Peek", nx())
M.F.MakeToggle(pExp, "PeekOn", "PeekOn", nx(), function() end, false)
M.F.MakeKeyRow(pExp, "PeekKey", "PeekKey", nx())
M.F.MakePicker(pExp, "PeekColor", "PeekColor", nx(), function() end)
M.F.MakeSlider(pExp, "PeekSize", "PeekSize", nx(), function() end)

M.F.MakeSection(pExp, "Sec_Teleport", nx())
M.F.MakeToggle(pExp, "TeleportOn", "TeleportOn", nx(), function() end, false)
M.F.MakeBindRow(pExp, "TpSetBind", nx(), function() if M.State.TeleportOn then M.F.SetTeleportPoint() end end)
M.F.MakeBindRow(pExp, "TpGoBind", nx(), function() if M.State.TeleportOn then M.F.TeleportToPoint() end end)
M.F.MakeSlider(pExp, "TeleportSpeed", "TeleportSpeed", nx(), function() end)

M.F.MakeSection(pExp, "Sec_Defense", nx())
M.F.MakeToggle(pExp, "FallProtection", "FallProtection", nx(), function() end, true)
M.F.MakeToggle(pExp, "AntiStun", "AntiStun", nx(), function() end, true)
M.F.MakeToggle(pExp, "IdleProtection", "IdleProtection", nx(), function(on) M.F.SetIdleProtection(on) end, true)
end

function M.F.DisplayToggleAll()
    local S, D = M.State, M.Data
    local keys = {"PlayerView", "ArrowsOn", "FoeTrailOn"}
    local anyOn = false
    for _, k in ipairs(keys) do if S[k] then anyOn = true end end
    local target = {}
    if anyOn then
        D.DisplayWasOn = {}
        for _, k in ipairs(keys) do
            if S[k] then D.DisplayWasOn[k] = true end
            target[k] = false
        end
    else
        local was = D.DisplayWasOn
        if not was or next(was) == nil then was = {PlayerView = true} end
        for _, k in ipairs(keys) do target[k] = was[k] == true end
    end
    for _, k in ipairs(keys) do
        M.F.SetStateVisual(k, target[k])
        for _, el in ipairs(M.F.VisualEntries(k)) do
            if el.Callback then pcall(el.Callback, target[k]) end
        end
    end
    M.F.Notify("DisplayAll", M.Translate("DisplayAllNote"), anyOn == false)
end

M.Data.PageBuilders.Display = function()
local order = 0
local function nx() order = order + 1 return order end
local function refresh() M.F.UpdatePlayerView() end

M.F.MakeSection(pDisplay, "Sec_PlayerViewBase", nx())
M.F.MakeToggle(pDisplay, "EnablePlayerView", "PlayerView", nx(), refresh, true, function() M.F.DisplayToggleAll() end)
M.F.MakeSlider(pDisplay, "PlayerViewMaxDist", "PlayerViewMaxDist", nx(), function() end)
M.F.MakeToggle(pDisplay, "PlayerViewOnSelf", "PlayerViewOnSelf", nx(), refresh, false)
M.F.MakeToggle(pDisplay, "PlayerViewTeamCheck", "PlayerViewTeamCheck", nx(), refresh, false)
M.F.MakeToggle(pDisplay, "EspNpcs", "EspNpcs", nx(), refresh, false)

M.F.MakeSection(pDisplay, "Sec_PlayerViewBoxes", nx())
M.F.MakeToggle(pDisplay, "PlayerViewBox", "PlayerViewBox", nx(), refresh, false)
M.F.MakePicker(pDisplay, "BoxCol", "PlayerViewBoxCol", nx(), refresh)
M.F.MakeSlider(pDisplay, "BoxThick", "PlayerViewBoxThick", nx(), refresh)
M.F.MakePicker(pDisplay, "NameCol", "PlayerViewNameCol", nx(), refresh)
M.F.MakeDropdown(pDisplay, "FontWeight", M.Schema.Options.PlayerViewFontWeight, "PlayerViewFontWeight", nx(), refresh)
M.F.MakeSlider(pDisplay, "TextSize", "PlayerViewTextSize", nx(), refresh)
M.F.MakeToggle(pDisplay, "PlayerViewDistance", "PlayerViewDistance", nx(), function() end, false)

M.F.MakeSection(pDisplay, "Sec_Skeleton", nx())
M.F.MakeToggle(pDisplay, "PlayerViewSkeleton", "PlayerViewSkeleton", nx(), function() end, false)
M.F.MakePicker(pDisplay, "SkeletonCol", "SkeletonCol", nx(), function() end)
M.F.MakeToggle(pDisplay, "SkeletonHealthColor", "SkeletonHealthColor", nx(), function() end, false)
M.F.MakeSlider(pDisplay, "SkeletonThick", "SkeletonThick", nx(), function() end)

M.F.MakeSection(pDisplay, "Sec_PlayerViewHl", nx())
M.F.MakeSlider(pDisplay, "PlayerViewHlLimit", "PlayerViewHlLimit", nx(), function() end)
M.F.MakeToggle(pDisplay, "PlayerViewHlFallback", "PlayerViewHlFallback", nx(), function() end, false)
local hiddenFillRow
M.F.MakeDropdown(pDisplay, "PlayerViewHlMode", M.Schema.Options.PlayerViewHlMode, "PlayerViewHlMode", nx(), function(opt)
    if hiddenFillRow then hiddenFillRow.Visible = (opt == "Wall") end
end)
M.F.MakePicker(pDisplay, "FillCol", "PlayerViewFill", nx(), refresh)
hiddenFillRow = M.F.MakePicker(pDisplay, "PlayerViewHiddenFill", "PlayerViewHiddenFill", nx(), function() end)
hiddenFillRow.Visible = M.State.PlayerViewHlMode == "Wall"
M.F.MakeSlider(pDisplay, "FillAlpha", "PlayerViewAlpha", nx(), refresh)
M.F.MakePicker(pDisplay, "LineCol", "PlayerViewLine", nx(), refresh)

M.F.MakeSection(pDisplay, "Sec_PlayerViewHealth", nx())
M.F.MakeToggle(pDisplay, "ShowHp", "PlayerViewHealthBar", nx(), refresh, false)
M.F.MakeToggle(pDisplay, "PlayerViewHealthColor", "PlayerViewHealthColor", nx(), refresh, false)
M.F.MakePicker(pDisplay, "HpCol", "PlayerViewHealthCol", nx(), refresh)
M.F.MakeDropdown(pDisplay, "HpPos", M.Schema.Options.PlayerViewHealthPos, "PlayerViewHealthPos", nx(), refresh)
M.F.MakeSlider(pDisplay, "HpThick", "PlayerViewHealthBarThick", nx(), refresh)
M.F.MakeToggle(pDisplay, "HpText", "PlayerViewHealthText", nx(), refresh, false)
M.F.MakeSlider(pDisplay, "HpTextSize", "PlayerViewHpTextSize", nx(), refresh)

M.F.MakeSection(pDisplay, "Sec_PlayerViewLines", nx())
M.F.MakeToggle(pDisplay, "PlayerViewLines", "PlayerViewLines", nx(), refresh, false)
M.F.MakePicker(pDisplay, "PlayerLineCol", "PlayerLineCol", nx(), refresh)

-- стрелки
M.F.MakeSection(pDisplay, "Sec_Arrows", nx())
M.F.MakeToggle(pDisplay, "ArrowsOn", "ArrowsOn", nx(), function() end, false)
-- образец
M.F.ArrowPreviewBuild(pDisplay, nx())
local function arPrev() M.F.ArrowPreviewRefresh() end
M.F.MakeDropdown(pDisplay, "ArrowStyle", M.Schema.Options.ArrowStyle, "ArrowStyle", nx(), arPrev)
local arrowColorRow, arrowRadiusRow, arrowMarginRow
M.F.MakeDropdown(pDisplay, "ArrowColorMode", M.Schema.Options.ArrowColorMode, "ArrowColorMode", nx(), function(opt)
    if arrowColorRow then arrowColorRow.Visible = (opt == "Fixed") end
    arPrev()
end)
arrowColorRow = M.F.MakePicker(pDisplay, "ArrowCol", "ArrowCol", nx(), arPrev)
arrowColorRow.Visible = M.State.ArrowColorMode == "Fixed"
M.F.MakeSlider(pDisplay, "ArrowSize", "ArrowSize", nx(), arPrev)
M.F.MakeSlider(pDisplay, "ArrowOpacity", "ArrowOpacity", nx(), arPrev)
M.F.MakeDropdown(pDisplay, "ArrowPlacement", M.Schema.Options.ArrowPlacement, "ArrowPlacement", nx(), function(opt)
    if arrowRadiusRow then arrowRadiusRow.Visible = (opt ~= "Edge") end
    if arrowMarginRow then arrowMarginRow.Visible = (opt == "Edge") end
end)
arrowRadiusRow = M.F.MakeSlider(pDisplay, "ArrowRadius", "ArrowRadius", nx(), function() end)
arrowMarginRow = M.F.MakeSlider(pDisplay, "ArrowMargin", "ArrowMargin", nx(), function() end)
arrowRadiusRow.Visible = M.State.ArrowPlacement ~= "Edge"
arrowMarginRow.Visible = M.State.ArrowPlacement == "Edge"
M.F.MakeSlider(pDisplay, "ArrowMaxCount", "ArrowMaxCount", nx(), function() end)
M.F.MakeToggle(pDisplay, "ArrowDistance", "ArrowDistance", nx(), function() end, false)
M.F.MakeToggle(pDisplay, "ArrowNpcs", "ArrowNpcs", nx(), function() end, false)
M.F.MakeToggle(pDisplay, "ArrowName", "ArrowName", nx(), function() end, false)
M.F.MakeToggle(pDisplay, "ArrowScaleDist", "ArrowScaleDist", nx(), arPrev, false)
M.F.MakeToggle(pDisplay, "ArrowPulse", "ArrowPulse", nx(), function() end, false)
M.F.MakeToggle(pDisplay, "ArrowGlow", "ArrowGlow", nx(), arPrev, false)
M.F.MakeToggle(pDisplay, "ArrowPlate", "ArrowPlate", nx(), arPrev, false)
M.F.MakeToggle(pDisplay, "ArrowRing", "ArrowRing", nx(), function() end, false)
M.F.MakeToggle(pDisplay, "ArrowSmart", "ArrowSmart", nx(), function() end, false)
M.F.MakeToggle(pDisplay, "ArrowThreat", "ArrowThreat", nx(), arPrev, false)
M.F.MakeToggle(pDisplay, "ArrowHealth", "ArrowHealth", nx(), arPrev, false)
M.F.MakeToggle(pDisplay, "ArrowLos", "ArrowLos", nx(), function() end, false)
M.F.MakeToggle(pDisplay, "ArrowHeight", "ArrowHeight", nx(), function() end, false)
M.F.MakeToggle(pDisplay, "ArrowAngle", "ArrowAngle", nx(), function() end, false)
local arrowGroupRow
M.F.MakeToggle(pDisplay, "ArrowGroup", "ArrowGroup", nx(), function(on)
    if arrowGroupRow then arrowGroupRow.Visible = on end
end, false)
arrowGroupRow = M.F.MakeSlider(pDisplay, "ArrowGroupAngle", "ArrowGroupAngle", nx(), function() end)
arrowGroupRow.Visible = M.State.ArrowGroup == true

M.F.MakeSection(pDisplay, "Sec_FoeTrail", nx())
M.F.MakeToggle(pDisplay, "FoeTrailOn", "FoeTrailOn", nx(), function() end, false)
M.F.MakePicker(pDisplay, "FoeTrailCol", "FoeTrailCol", nx(), function() end)
M.F.MakeSlider(pDisplay, "FoeTrailTime", "FoeTrailTime", nx(), function() end)
M.F.MakeSlider(pDisplay, "FoeTrailMax", "FoeTrailMax", nx(), function() end)
M.F.MakeSlider(pDisplay, "FoeTrailThick", "FoeTrailThick", nx(), function() end)

M.F.MakeSection(pDisplay, "Sec_Tracers", nx())
M.F.MakeToggle(pDisplay, "TracerOn", "TracerOn", nx(), function() end, false)
M.F.MakePicker(pDisplay, "TracerCol", "TracerCol", nx(), function() end)
M.F.MakeSlider(pDisplay, "TracerIntensity", "TracerIntensity", nx(), function() end)
M.F.MakeSlider(pDisplay, "TracerSize", "TracerSize", nx(), function() end)
M.F.MakeSlider(pDisplay, "TracerGlow", "TracerGlow", nx(), function() end)
M.F.MakeSlider(pDisplay, "TracerLength", "TracerLength", nx(), function() end)

M.F.MakeSection(pDisplay, "Sec_Feedback", nx())
M.F.MakeToggle(pDisplay, "DamageNumbers", "DamageNumbers", nx(), function() end, false)
M.F.MakeToggle(pDisplay, "HitMarkerOn", "HitMarkerOn", nx(), function() end, false)
M.F.MakeToggle(pDisplay, "HitLoose", "HitLoose", nx(), function() end, false)
M.F.MakeSlider(pDisplay, "HitFxSize", "HitFxSize", nx(), function() end)
M.F.MakeSlider(pDisplay, "HitFxPower", "HitFxPower", nx(), function() end)
M.F.MakePicker(pDisplay, "HitFxColor", "HitFxColor", nx(), function() end)
M.F.MakePicker(pDisplay, "HitFxKillColor", "HitFxKillColor", nx(), function() end)
M.F.MakeToggle(pDisplay, "HitRingsOn", "HitRingsOn", nx(), function() end, false)
M.F.MakePicker(pDisplay, "HitRingColor", "HitRingColor", nx(), function() end)
M.F.MakeSlider(pDisplay, "HitRingSpeed", "HitRingSpeed", nx(), function() end)
M.F.MakeSlider(pDisplay, "HitRingGlow", "HitRingGlow", nx(), function() end)

M.F.MakeSection(pDisplay, "Sec_KillFx", nx())
M.F.MakeToggle(pDisplay, "KillFxOn", "KillFxOn", nx(), function() end, false)
M.F.MakeDropdown(pDisplay, "KillFxType", M.Schema.Options.KillFxType, "KillFxType", nx(), function() end)
M.F.MakePicker(pDisplay, "KillFxColor", "KillFxColor", nx(), function() end)
M.F.MakeSlider(pDisplay, "KillFxSpeed", "KillFxSpeed", nx(), function() end)
end

-- камера
M.Data.PageBuilders.Camera = function()
local order = 0
local function nx() order = order + 1 return order end

M.F.MakeSection(pCam, "Sec_CameraMain", nx())
M.F.MakeToggle(pCam, "FovOn", "FovOn", nx(), function() end, true)
M.F.MakeSlider(pCam, "CamFov", "CamFov", nx(), function(v)
    M.State.CamFov = v
    -- двигаете ползунок
    if not M.Data.Importing and not M.State.FovOn then
        M.F.SetStateVisual("FovOn", true)
    end
end)

M.F.MakeSection(pCam, "Sec_ThirdPerson", nx())
M.F.MakeToggle(pCam, "ThirdPerson", "ThirdPerson", nx(), function() end, true)
M.F.MakeSlider(pCam, "ThirdPersonDist", "ThirdPersonDist", nx(), function() end)
M.F.MakeSlider(pCam, "ThirdPersonShoulder", "ThirdPersonShoulder", nx(), function() end)
M.F.MakeSlider(pCam, "ThirdPersonHeight", "ThirdPersonHeight", nx(), function() end)

M.F.MakeSection(pCam, "Sec_Zoom", nx())
M.F.MakeToggle(pCam, "ZoomOn", "ZoomOn", nx(), function() end, true)
M.F.MakeSlider(pCam, "ZoomFov", "ZoomFov", nx(), function() end)
M.F.MakeSlider(pCam, "ZoomSpeed", "ZoomSpeed", nx(), function() end)

M.F.MakeSection(pCam, "Sec_Observe", nx())
M.F.MakeToggle(pCam, "SpectateOn", "SpectateOn", nx(), function(on)
    if on and M.Data.Fc then M.F.StopFreecam() end
    if on and not M.Data.SpectateTarget then M.F.SpectateStep(1) end
end, true)
M.F.MakePresetRow(pCam, nx(), {{Key = "<", Id = -1}, {Key = ">", Id = 1}}, function(direction)
    M.F.SpectateStep(direction)
end)
do
    local spectateCard = M.F.MakeCard(pCam, 36)
    spectateCard.LayoutOrder = nx()
    M.UI.SpectateLabel = Instance.new("TextLabel")
    M.UI.SpectateLabel.Size = UDim2.new(1, -24, 1, 0)
    M.UI.SpectateLabel.Position = UDim2.new(0, 12, 0, 0)
    M.UI.SpectateLabel.BackgroundTransparency = 1
    M.UI.SpectateLabel.Font = Enum.Font.GothamMedium
    M.UI.SpectateLabel.TextSize = 12
    M.UI.SpectateLabel.TextColor3 = M.Style.TextDim
    M.UI.SpectateLabel.TextXAlignment = Enum.TextXAlignment.Left
    M.UI.SpectateLabel.Parent = spectateCard
    table.insert(M.Data.RegUI, {SetLanguage = M.F.RenderSpectateLabel})
    M.F.RenderSpectateLabel()
end

M.F.MakeSection(pCam, "Sec_Freecam", nx())
M.F.MakeToggle(pCam, "FreecamOn", "FreecamOn", nx(), function(on) M.F.SetFreecam(on) end, true)
M.F.MakeSlider(pCam, "FreecamSpeed", "FreecamSpeed", nx(), function() end)
M.F.MakeSlider(pCam, "FreecamSens", "FreecamSens", nx(), function() end)
M.F.MakeSlider(pCam, "FreecamSmooth", "FreecamSmooth", nx(), function() end)
do
    -- подсказка по клавишам
    local hintCard = M.F.MakeCard(pCam, 62)
    hintCard.LayoutOrder = nx()
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -24, 1, -12)
    hint.Position = UDim2.new(0, 12, 0, 6)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.GothamMedium
    hint.TextSize = 12
    hint.TextWrapped = true
    hint.TextColor3 = M.Style.TextDim
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Center
    hint.Text = M.Translate("FreecamHint")
    hint.Parent = hintCard
    table.insert(M.Data.RegUI, {SetLanguage = function() hint.Text = M.Translate("FreecamHint") end})
end

M.F.MakeSection(pCam, "Sec_Hits", nx())
M.F.MakeToggle(pCam, "ShakeOn", "ShakeOn", nx(), function() end, false)
M.F.MakeSlider(pCam, "ShakeStrength", "ShakeStrength", nx(), function() end)
M.F.MakeToggle(pCam, "HitFlashOn", "HitFlashOn", nx(), function() end, false)
M.F.MakeToggle(pCam, "LowHpOn", "LowHpOn", nx(), function() end, false)
end

-- окружение: от неба и времени к погоде и редким эффектам
M.Data.PageBuilders.World = function()
local order = 0
local function nx() order = order + 1 return order end

M.F.MakeSection(pWrld, "Sec_WorldTime", nx())
M.F.MakeToggle(pWrld, "TimeOfDay", "TimeOn", nx(), function() M.F.ApplyTime() end, false)
M.F.MakeSlider(pWrld, "ClockTime", "CustomTime", nx(), function() M.F.ApplyTime() end)
M.F.MakeToggle(pWrld, "TimeCycle", "TimeCycle", nx(), function(on)
    if on and not M.Data.Importing then
        local now = math.floor(M.Services.L.ClockTime * 100) / 100
        M.F.SetStateVisual("CustomTime", now)
        if not M.State.TimeOn then M.F.SetStateVisual("TimeOn", true) end
    end
end, true)
M.F.MakeSlider(pWrld, "TimeCycleSpeed", "TimeCycleSpeed", nx(), function() end)
M.F.MakeToggle(pWrld, "TimeSyncReal", "TimeSyncReal", nx(), function(on)
    if on and not M.Data.Importing then
        -- реальное время и цикл исключают друг друга
        M.F.SetStateVisual("TimeCycle", false)
        if not M.State.TimeOn then M.F.SetStateVisual("TimeOn", true) end
        M.F.SyncRealTime()
    end
end, true)

M.F.MakeSection(pWrld, "Sec_WorldSky", nx())
M.F.MakeToggle(pWrld, "SkyOn", "SkyOn", nx(), function() M.F.ApplySky() end, false)
-- готовые скайбоксы из магазина
M.F.MakePresetRow(pWrld, nx(), {
    {Key = "SkyPreset1", Id = "132703927222924"},
    {Key = "SkyPreset2", Id = "15502592084"},
    {Key = "SkyPreset3", Id = "911025794"},
    {Key = "SkyPreset4", Id = "741300412"}
}, function(id) M.F.PickSkyPreset(id) end)
M.F.MakePresetRow(pWrld, nx(), {
    {Key = "SkyPreset5", Id = "339406852"},
    {Key = "SkyPreset7", Id = "175933054"},
    {Key = "SkyPreset8", Id = "default"}
}, function(id) M.F.PickSkyPreset(id) end)

M.F.MakeSection(pWrld, "Sec_WorldClouds", nx())
M.F.MakeToggle(pWrld, "CloudsOn", "CloudsOn", nx(), function() M.F.ApplyClouds() end, false)
M.F.MakeSlider(pWrld, "CloudDensity", "CloudDensity", nx(), function() M.F.ApplyClouds() end)
M.F.MakeSlider(pWrld, "CloudCover", "CloudCover", nx(), function() M.F.ApplyClouds() end)
M.F.MakePicker(pWrld, "CloudColor", "CloudColor", nx(), function(c)
    M.State.CloudColor = c
    if not M.Data.Importing and not M.State.CloudsOn then
        M.F.SetStateVisual("CloudsOn", true)
    end
    M.F.ApplyClouds()
end)

M.F.MakeSection(pWrld, "Sec_WorldFog", nx())
M.F.MakeToggle(pWrld, "WhiteFog", "FogOn", nx(), function() M.F.ApplyFog() end, false)
M.F.MakeSlider(pWrld, "FogDense", "FogDensity", nx(), function() M.F.ApplyFog() end)
M.F.MakeSlider(pWrld, "FogHaze", "FogHaze", nx(), function() M.F.ApplyFog() end)
M.F.MakePicker(pWrld, "FogCol", "FogColor", nx(), function(c)
    M.State.FogColor = c
    if not M.Data.Importing and not M.State.FogOn then
        M.F.SetStateVisual("FogOn", true)
    end
    M.F.ApplyFog()
end)

M.F.MakeSection(pWrld, "Sec_WorldLight", nx())
M.F.MakeToggle(pWrld, "DarkWorld", "DarkWorld", nx(), function() M.F.ApplyDark() end, false)
M.F.MakeSlider(pWrld, "DarkIntense", "DarkIntensity", nx(), function() M.F.ApplyDark() end)

M.F.MakeSection(pWrld, "Sec_Grade", nx())
M.F.MakeToggle(pWrld, "GradeOn", "GradeOn", nx(), function() M.F.ApplyGrade() end, true)
M.F.MakeDropdown(pWrld, "GradePreset", M.Schema.Options.GradePreset, "GradePreset", nx(), function(name)
    if not M.Data.Importing then M.F.ApplyGradePreset(name) end
end)
local function onGradeSlider()
    if not M.Data.Importing and M.State.GradePreset ~= "Custom" then M.F.SetStateVisual("GradePreset", "Custom") end
    M.F.ApplyGrade()
end
M.F.MakeSlider(pWrld, "GradeSat", "GradeSat", nx(), onGradeSlider)
M.F.MakeSlider(pWrld, "GradeContrast", "GradeContrast", nx(), onGradeSlider)
M.F.MakeSlider(pWrld, "GradeBright", "GradeBright", nx(), onGradeSlider)
M.F.MakePicker(pWrld, "GradeTint", "GradeTint", nx(), onGradeSlider)

M.F.MakeSection(pWrld, "Sec_WorldRays", nx())
M.F.MakeToggle(pWrld, "SunRaysOn", "SunRaysOn", nx(), function() M.F.ApplySunRays() end, false)
M.F.MakeSlider(pWrld, "SunRaysIntensity", "SunRaysIntensity", nx(), function() M.F.ApplySunRays() end)
M.F.MakeSlider(pWrld, "SunRaysSpread", "SunRaysSpread", nx(), function() M.F.ApplySunRays() end)
M.F.MakeSlider(pWrld, "SunRaysBright", "SunRaysBright", nx(), function() M.F.ApplySunRays() end)

M.F.MakeSection(pWrld, "Sec_WorldWeather", nx())
M.F.MakeToggle(pWrld, "PropWeather", "WeatherOn", nx(), function(on) if not on then M.F.ClearWeatherProps() end end, false)
M.F.MakeDropdown(pWrld, "WeatherMode", M.Schema.Options.WeatherMode, "WeatherMode", nx(), function() M.F.ClearWeatherProps(); M.F.ClearLeaves() end)
M.F.MakeSlider(pWrld, "WeatherDense", "WeatherDensity", nx(), function() end)
M.F.MakeSlider(pWrld, "WeatherSpeed", "WeatherSpeed", nx(), function() end)
M.F.MakeSlider(pWrld, "WeatherRadius", "WeatherRadius", nx(), function() end)
M.F.MakeSlider(pWrld, "SnowSize", "SnowSize", nx(), function() end)
M.F.MakePicker(pWrld, "WeatherCol", "WeatherColor", nx(), function() end)
M.F.MakeToggle(pWrld, "WeatherSplash", "WeatherSplash", nx(), function() end, false)

M.F.MakeSection(pWrld, "Sec_Lightning", nx())
M.F.MakeToggle(pWrld, "Lightning", "LightningOn", nx(), function() end, false)
M.F.MakeSlider(pWrld, "LightRate", "LightningRate", nx(), function() end)
M.F.MakeSlider(pWrld, "LightSize", "LightningSize", nx(), function() end)
M.F.MakeSlider(pWrld, "LightDur", "LightningDuration", nx(), function() end)
M.F.MakeToggle(pWrld, "LightningFlash", "LightningFlash", nx(), function() end, false)
M.F.MakeSlider(pWrld, "LightningFlashPower", "LightningFlashPower", nx(), function() end)

M.F.MakeSection(pWrld, "Sec_Meteors", nx())
M.F.MakeToggle(pWrld, "Meteors", "MeteorOn", nx(), function() end, false)
M.F.MakeSlider(pWrld, "MetRate", "MeteorRate", nx(), function() end)
M.F.MakeSlider(pWrld, "MetSize", "MeteorSize", nx(), function() end)
M.F.MakeSlider(pWrld, "MetTail", "MeteorTrailLen", nx(), function() end)
M.F.MakeSlider(pWrld, "MetDur", "MeteorDuration", nx(), function() end)
M.F.MakeToggle(pWrld, "MeteorImpact", "MeteorImpact", nx(), function() end, false)
M.F.MakePicker(pWrld, "MetCol", "MeteorColor", nx(), function() end)
end

end}

-- [63/69] Страницы: персонаж, разное, система, конфиги, настройки
MODULES[#MODULES + 1] = {"63. Страницы: персонаж, разное, система, конфиги, настройки", function(M, __X)
local pCfg = __X.pCfg
local pMisc = __X.pMisc
local pPlyr = __X.pPlyr
local pSet = __X.pSet
local pSys = __X.pSys
-- персонаж
M.Data.PageBuilders.Player = function()
local order = 0
local function nx() order = order + 1 return order end

M.F.MakeSection(pPlyr, "Sec_PlyrModel", nx())
M.F.MakeToggle(pPlyr, "HideHats", "HideHats", nx(), function() M.UpdatePlayerVisuals() end, false)
M.F.MakeToggle(pPlyr, "HoloSelf", "HoloSelf", nx(), function() M.UpdatePlayerVisuals() end, false)
M.F.MakePicker(pPlyr, "HoloCol", "HoloColor", nx(), function() M.UpdatePlayerVisuals() end)
M.F.MakeSlider(pPlyr, "HoloAlpha", "HoloAlpha", nx(), function() M.UpdatePlayerVisuals() end)
M.F.MakeSlider(pPlyr, "HoloGlow", "HoloGlow", nx(), function() M.UpdatePlayerVisuals() end)

M.F.MakeSection(pPlyr, "Sec_Trail", nx())
M.F.MakeToggle(pPlyr, "TrailOn", "TrailOn", nx(), function() end, false)
M.F.MakePicker(pPlyr, "TrailCol", "TrailCol", nx(), function() M.F.StyleTrail() end)
M.F.MakeSlider(pPlyr, "TrailIntensity", "TrailIntensity", nx(), function() M.F.StyleTrail() end)
M.F.MakeSlider(pPlyr, "TrailGlow", "TrailGlow", nx(), function() M.F.StyleTrail() end)
M.F.MakeSlider(pPlyr, "TrailLength", "TrailLength", nx(), function() M.F.StyleTrail() end)

M.F.MakeSection(pPlyr, "Sec_PlyrJump", nx())
M.F.MakeToggle(pPlyr, "JumpRings", "JumpRings", nx(), function() end, false)
M.F.MakeDropdown(pPlyr, "JumpRingType", M.Schema.Options.JumpRingType, "JumpRingType", nx(), function() end)
M.F.MakePicker(pPlyr, "JumpRingFillCol", "JumpRingFillCol", nx(), function() end)
M.F.MakePicker(pPlyr, "JumpRingOutCol", "JumpRingOutCol", nx(), function() end)
M.F.MakeSlider(pPlyr, "JumpRingGlow", "JumpRingGlow", nx(), function() end)
M.F.MakeSlider(pPlyr, "JumpRingSize", "JumpRingSize", nx(), function() end)
M.F.MakeSlider(pPlyr, "JumpRingSpeed", "JumpRingSpeed", nx(), function() end)

M.F.MakeSection(pPlyr, "Sec_PlyrAccessories", nx())
M.F.MakeToggle(pPlyr, "Orbits", "OrbitOn", nx(), function() M.F.RebuildOrbits() end, false)
M.F.MakePicker(pPlyr, "OrbitCol", "OrbitColor", nx(), function() M.F.UpdateOrbitsVisualLive() end)
M.F.MakeSlider(pPlyr, "OrbitCount", "OrbitCount", nx(), function() M.F.Debounce("orbits", 0.15, M.F.RebuildOrbits) end)
M.F.MakeSlider(pPlyr, "OrbitRadius", "OrbitRadius", nx(), function() end)
M.F.MakeSlider(pPlyr, "OrbitSpeed", "OrbitSpeed", nx(), function() end)
M.F.MakeSlider(pPlyr, "OrbitSize", "OrbitSize", nx(), function(v) M.State.OrbitSize = v; M.F.UpdateOrbitsVisualLive() end)
M.F.MakePicker(pPlyr, "OrbitTrailCol", "OrbitTrailColor", nx(), function() M.F.UpdateOrbitsVisualLive() end)
M.F.MakeSlider(pPlyr, "OrbitTrailThick", "OrbitTrailThick", nx(), function(v) M.State.OrbitTrailThick = v; M.F.UpdateOrbitsVisualLive() end)
M.F.MakeSlider(pPlyr, "OrbitTrailLen", "OrbitTrailLen", nx(), function(v) M.State.OrbitTrailLen = v; M.F.UpdateOrbitsVisualLive() end)
end

-- десинк: поза и вращение, заморозка и лаги, призраки сервера
M.Data.PageBuilders.Misc = function()
local order = 0
local function nx() order = order + 1 return order end
local function refreshDesync()
    local _, hum, root = M.GetSelf()
    M.F.UpdateDesync(0, root, hum, workspace.CurrentCamera)
end

M.F.MakeSection(pMisc, "Sec_SilhouetteMod", nx())
M.F.MakeToggle(pMisc, "PitchMod", "HeadTiltOn", nx(), function() end, true)
M.F.MakeSlider(pMisc, "PitchAngle", "PitchAngle", nx(), function() end)
M.F.MakeDropdown(pMisc, "TiltMode", M.Schema.Options.TiltMode, "TiltMode", nx(), function() end)

M.F.MakeSection(pMisc, "Sec_Spin", nx())
M.F.MakeToggle(pMisc, "SpinCharacter", "SpinCharacter", nx(), function() end, true)
M.F.MakeSlider(pMisc, "YawSpeed", "YawSpeed", nx(), function() end)
M.F.MakeToggle(pMisc, "JerkySpin", "JerkySpin", nx(), function() end, false)

M.F.MakeSection(pMisc, "Sec_BackWalk", nx())
M.F.MakeToggle(pMisc, "BackWalk", "BackWalk", nx(), function() end, true)
M.F.MakeToggle(pMisc, "BackWalkLegs", "BackWalkLegs", nx(), function() end, false)

M.F.MakeSection(pMisc, "Sec_Desync", nx())
M.F.MakeToggle(pMisc, "FreezeChar", "FreezeChar", nx(), refreshDesync, true)
M.F.MakeToggle(pMisc, "FakeLag", "FakeLag", nx(), refreshDesync, true)
M.F.MakeSlider(pMisc, "FakeLagTicks", "FakeLagTicks", nx(), function() end)
M.F.MakeSlider(pMisc, "FakeLagDelay", "FakeLagDelay", nx(), function() end)

M.F.MakeSection(pMisc, "Sec_Ghosts", nx())
M.F.MakeToggle(pMisc, "ServerGhosts", "ServerGhosts", nx(), function() M.F.RestyleGhosts() end, true)
M.F.MakeDropdown(pMisc, "GhostMaterial", M.Schema.Options.GhostMaterial, "GhostMaterial", nx(), function() M.F.RestyleGhosts() end)
M.F.MakePicker(pMisc, "GhostColor", "GhostColor", nx(), function() M.F.RestyleGhosts() end)
M.F.MakeSlider(pMisc, "GhostAlpha", "GhostAlpha", nx(), function() M.F.RestyleGhosts() end)
M.F.MakeSlider(pMisc, "GhostCount", "GhostCount", nx(), function() M.F.RestyleGhosts() end)
end

-- система: производительность и безопасность
M.Data.PageBuilders.System = function()
local order = 0
local function nx() order = order + 1 return order end

M.F.MakeSection(pSys, "Sec_Performance", nx())
M.F.MakeToggle(pSys, "OptLight", "OptLight", nx(), function() M.F.RefreshOptimization() end, false)
M.F.MakeToggle(pSys, "FpsBoost", "FpsBoost", nx(), function(v) M.ApplyFpsBoost(v) end, false)
M.F.MakeToggle(pSys, "CullOn", "CullOn", nx(), function() M.F.CullRefresh() end, false)
M.F.MakeSlider(pSys, "FpsCullDist", "FpsCullDist", nx(), function() end)
M.F.MakeToggle(pSys, "AutoLite", "AutoLite", nx(), function() end, false)
M.F.MakeToggle(pSys, "HitchReport", "HitchReport", nx(), function() end, false)
M.F.MakePresetRow(pSys, nx(), {{Key = "HitchDump", Id = "dump"}}, function() M.F.HitchDump() end)

M.F.MakeSection(pSys, "Sec_Errors", nx())
M.F.MakeErrorsCard(pSys, nx())
M.F.MakePresetRow(pSys, nx(), {{Key = "ErrCopy", Id = "copy"}, {Key = "ErrClear", Id = "clear"}}, function(id)
    if id == "copy" then M.F.ErrorsCopy() else M.F.ErrorsClear() end
end)

M.F.MakeSection(pSys, "Sec_Framerate", nx())
M.F.MakeToggle(pSys, "FpsUnlocker", "FpsUnlocker", nx(), function(v) M.ApplyFpsUnlocker(v) end, false)

M.F.MakeSection(pSys, "Sec_Safety", nx())
M.F.MakeToggle(pSys, "SafeStart", "SafeStart", nx(), function() end, false)
M.F.MakeToggle(pSys, "RollbackGuard", "RollbackGuard", nx(), function() end, false)
M.F.MakeToggle(pSys, "RestoreMouse", "RestoreMouse", nx(), function() end, false)
do
    local panicCard = M.F.MakeCard(pSys, 40); panicCard.LayoutOrder = nx()
    local panicBtn = Instance.new("TextButton", panicCard)
    panicBtn.Size = UDim2.new(1, -20, 0, 28); panicBtn.Position = UDim2.new(0, 10, 0.5, -14)
    panicBtn.BackgroundColor3 = M.Style.Danger:Lerp(M.Style.Card, 0.72); panicBtn.AutoButtonColor = false
    panicBtn.Text = M.Translate("Panic_Btn"); panicBtn.TextColor3 = M.Style.Danger:Lerp(Color3.new(1, 1, 1), 0.35)
    panicBtn.Font = Enum.Font.GothamBold; panicBtn.TextSize = 12
    Instance.new("UICorner", panicBtn).CornerRadius = UDim.new(0, 8)
    do
        -- красная кнопка
        local panicStroke = M.Style.AddStroke(panicBtn, M.Style.Danger, 1, 0.55)
        local panicGlow = M.Style.Glow(panicBtn, 8, 0, M.Style.Danger, UDim.new(0, 12))
        panicBtn.MouseEnter:Connect(function()
            M.Style.Tween(panicBtn, 0.18, {BackgroundColor3 = M.Style.Danger:Lerp(M.Style.Card, 0.55)})
            M.Style.Tween(panicStroke, 0.18, {Transparency = 0.15})
            panicGlow.Set(0.3, 0.2)
        end)
        panicBtn.MouseLeave:Connect(function()
            M.Style.Tween(panicBtn, 0.25, {BackgroundColor3 = M.Style.Danger:Lerp(M.Style.Card, 0.72)})
            M.Style.Tween(panicStroke, 0.25, {Transparency = 0.55})
            panicGlow.Set(0, 0.25)
        end)
    end
    panicBtn.MouseButton1Click:Connect(function() M.F.Confirm("panic") end)
    table.insert(M.Data.RegUI, {SetLanguage = function() panicBtn.Text = M.Translate("Panic_Btn") end})
end
end

M.Data.PageBuilders.Configs = function()
-- меню конфигов
local cfgInputCard = M.F.MakeCard(pCfg, 42); cfgInputCard.LayoutOrder = 1
local cfgInput = Instance.new("TextBox", cfgInputCard)
cfgInput.Size = UDim2.new(0.65, 0, 0, 26); cfgInput.Position = UDim2.new(0, 10, 0.5, -13)
cfgInput.BackgroundColor3 = M.Style.Field; cfgInput.Text = "default"; cfgInput.TextColor3 = M.Style.Text
cfgInput.Font = Enum.Font.GothamBold; cfgInput.TextSize = 12; cfgInput.BorderSizePixel = 0
Instance.new("UICorner", cfgInput).CornerRadius = UDim.new(0, 6)

local cfgStatusCard = M.F.MakeCard(pCfg, 28); cfgStatusCard.LayoutOrder = 2
local cfgStatus = Instance.new("TextLabel", cfgStatusCard)
cfgStatus.Size = UDim2.new(1, 0, 1, 0); cfgStatus.BackgroundTransparency = 1
M.Style.Bind(cfgStatus, "TextColor3"); cfgStatus.Font = Enum.Font.GothamBold; cfgStatus.TextSize = 11

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
    b.BackgroundColor3 = M.Style.Raised; b.Text = M.Translate(textKey); b.TextColor3 = M.Style.Text
    b.Font = Enum.Font.GothamBold; b.TextSize = 11; Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    M.F.DecorateButton(b, true)
    local cfgScale = b:FindFirstChild("ButtonScale")
    b.MouseEnter:Connect(function() M.Style.Tween(b, 0.18, {BackgroundColor3 = M.State.Accent:Lerp(M.Style.Raised, 0.8), TextColor3 = M.Style.AccentMix(0.55)}) end)
    b.MouseLeave:Connect(function()
        M.Style.Tween(b, 0.25, {BackgroundColor3 = M.Style.Raised, TextColor3 = M.Style.Text})
        M.Style.Tween(cfgScale, 0.2, {Scale = 1})
    end)
    b.MouseButton1Down:Connect(function() M.Style.Tween(cfgScale, 0.1, {Scale = 0.95}) end)
    b.MouseButton1Up:Connect(function() M.Style.Tween(cfgScale, 0.3, {Scale = 1}, Enum.EasingStyle.Back) end)
    b.MouseButton1Click:Connect(cb)
    table.insert(M.Data.RegUI, {SetLanguage = function() b.Text = M.Translate(textKey) end})
    return b
end

local cfgListContainer = M.F.MakeCard(pCfg, 150); cfgListContainer.LayoutOrder = 4
local cfgListScroll = Instance.new("ScrollingFrame", cfgListContainer)
cfgListScroll.Size = UDim2.new(1, -16, 1, -12); cfgListScroll.Position = UDim2.new(0, 8, 0, 6); cfgListScroll.BackgroundTransparency = 1
cfgListScroll.ScrollBarThickness = 3
cfgListScroll.ScrollBarImageColor3 = Color3.fromRGB(70, 78, 104)
cfgListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local clLayout = Instance.new("UIListLayout", cfgListScroll); clLayout.Padding = UDim.new(0, 4)
local clPad = Instance.new("UIPadding", cfgListScroll); clPad.PaddingLeft = UDim.new(0, 2); clPad.PaddingRight = UDim.new(0, 2); clPad.PaddingTop = UDim.new(0, 2)

local function refreshCfgListUI()
    for _, ch in ipairs(cfgListScroll:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
    local list = M.CFG.List()
    local autoName = M.Data.MemStorage["__AUTOLOAD"]

    for _, name in ipairs(list) do
        local b = Instance.new("TextButton", cfgListScroll)
        local selected = (name == M.State.SelectedCfg)
        b.Size = UDim2.new(1, -8, 0, 26); b.AutoButtonColor = false
        b.BackgroundColor3 = selected and M.State.Accent:Lerp(M.Style.Card, 0.84) or M.Style.Field
        local isAuto = (autoName == name)
        b.Text = "  " .. name .. (isAuto and M.Translate("Cfg_AutoTag") or "")
        b.TextColor3 = selected and M.Style.AccentMix(0.4) or M.Style.TextDim
        b.Font = Enum.Font.GothamMedium; b.TextSize = 11; b.TextXAlignment = Enum.TextXAlignment.Left
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
        local rowStroke = M.Style.AddStroke(b, selected and M.State.Accent or M.Style.Stroke, 1, selected and M.Style.StrokeActive or M.Style.StrokeIdle)
        b.MouseEnter:Connect(function()
            if not selected then M.Style.Tween(b, 0.15, {BackgroundColor3 = M.Style.Raised, TextColor3 = M.Style.Text}) end
            M.Style.Tween(rowStroke, 0.15, {Color = M.State.Accent, Transparency = M.Style.StrokeActive})
        end)
        b.MouseLeave:Connect(function()
            if not selected then M.Style.Tween(b, 0.2, {BackgroundColor3 = M.Style.Field, TextColor3 = M.Style.TextDim}) end
            M.Style.Tween(rowStroke, 0.2, {Color = selected and M.State.Accent or M.Style.Stroke, Transparency = selected and 0.55 or 0.7})
        end)
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

-- настройки
M.Data.PageBuilders.Settings = function()
local order = 0
local function nx() order = order + 1 return order end

M.F.MakeSection(pSet, "Sec_UiGeneral", nx())
M.F.MakeDropdown(pSet, "LangBtn", M.Schema.Options.Language, "Language", nx(), function(v)
    M.L10N.Current = v
    M.F.UpdateLanguageUI()
end)
M.F.MakeDropdown(pSet, "FontStyle", M.Schema.Options.FontStyle, "FontStyle", nx(), function() M.F.ApplyFont() end)
M.F.MakeSlider(pSet, "AnimSpeed", "AnimSpeed", nx(), function() end)
M.F.MakeToggle(pSet, "UiFx", "UiFx", nx(), function() end, false)

M.F.MakeSection(pSet, "Sec_UiTheme", nx())
M.F.MakePicker(pSet, "AccentCol", "Accent", nx(), function(col)
    M.F.RecolorAccent(col)
end)
M.F.MakePicker(pSet, "MainCol", "MainBg", nx(), function(col)
    if M.UI.MenuBg then M.UI.MenuBg.BackgroundColor3 = col end
end)
M.F.MakeSlider(pSet, "MainAlpha", "MenuAlpha", nx(), function(v)
    if M.UI.MenuBg then M.UI.MenuBg.BackgroundTransparency = v end
    M.F.ApplyGlass()
end)
M.F.MakePicker(pSet, "CardCol", "CardBg", nx(), function(col)
    for _, c in ipairs(M.UI.Cards) do c.BackgroundColor3 = col end
end)
M.F.MakeSlider(pSet, "CardAlpha", "CardAlpha", nx(), function(v)
    for _, c in ipairs(M.UI.Cards) do c.BackgroundTransparency = v end
    M.F.ApplyGlass()
end)
M.F.MakePicker(pSet, "BorderCol", "BorderCol", nx(), function(col)
    M.UI.MainStroke.Color = col
    M.UI.SideStroke.Color = col
end)
M.F.MakeSlider(pSet, "BorderThick", "BorderThick", nx(), function(v)
    local t = math.round(v)
    M.UI.MainStroke.Thickness = t
    M.UI.SideStroke.Thickness = t
end)

M.F.MakeSection(pSet, "Sec_UiSidebar", nx())
M.F.MakePicker(pSet, "SideCol", "SideBg", nx(), function(col) M.UI.Sidebar.BackgroundColor3 = col end)
M.F.MakeSlider(pSet, "SideAlpha", "SideAlpha", nx(), function(v) M.UI.Sidebar.BackgroundTransparency = v end)
M.F.MakePicker(pSet, "SideCardCol", "SideCardBg", nx(), function(col)
    for _, sc in ipairs(M.UI.SideCards) do sc.BackgroundColor3 = col end
    M.F.StyleTabs()
end)
M.F.MakeSlider(pSet, "SideCardAlpha", "SideCardAlpha", nx(), function(v)
    for _, sc in ipairs(M.UI.SideCards) do sc.BackgroundTransparency = v end
    M.F.StyleTabs()
end)
M.F.MakePicker(pSet, "LogoCol", "LogoCol", nx(), function(col)
    M.UI.Logo.TextColor3 = col
    M.UI.LogoGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, col:Lerp(Color3.fromRGB(80, 80, 80), 0.4)),
        ColorSequenceKeypoint.new(0.5, col),
        ColorSequenceKeypoint.new(1, col:Lerp(Color3.fromRGB(80, 80, 80), 0.4))
    })
end)

M.F.MakeSection(pSet, "Sec_UiGlass", nx())
M.F.MakeToggle(pSet, "GlassOn", "GlassOn", nx(), function() M.F.ApplyGlass() end, false)
M.F.MakeSlider(pSet, "GlassBlur", "GlassBlur", nx(), function() M.F.UpdateGlassBlur(M.Run.MenuOpen) end)
M.F.MakeSlider(pSet, "GlassSheen", "GlassSheen", nx(), function() M.F.ApplyGlass() end)

M.F.MakeSection(pSet, "Sec_UiNotify", nx())
M.F.MakeToggle(pSet, "NotifyOn", "NotifyOn", nx(), function() end, false)
M.F.MakePicker(pSet, "NotifyColor", "NotifyColor", nx(), function(col)
    M.State.NotifyColor = col
    M.F.NotifyPreview()
end)
M.F.MakeSlider(pSet, "NotifyAlpha", "NotifyAlpha", nx(), function() M.F.NotifyPreview() end)
M.F.MakeSlider(pSet, "NotifyScale", "NotifyScale", nx(), function() M.F.NotifyRescale(); M.F.NotifyPreview() end)

M.F.MakeSection(pSet, "Sec_UiPill", nx())
M.F.MakeToggle(pSet, "PillUser", "PillShowUser", nx(), function() M.F.PillUpdate() end, false)
M.F.MakeToggle(pSet, "PillMem", "PillShowMem", nx(), function() M.F.PillUpdate() end, false)
M.F.MakeToggle(pSet, "PillClock", "PillShowClock", nx(), function() M.F.PillUpdate() end, false)
M.F.MakeToggle(pSet, "PillSession", "PillShowTime", nx(), function() M.F.PillUpdate() end, false)
M.F.MakeToggle(pSet, "PillPing", "PillShowPing", nx(), function() M.F.PillUpdate() end, false)
M.F.MakeSlider(pSet, "PillScale", "PillScaleVal", nx(), function(v) M.UI.PillScale.Scale = v end)
M.F.MakePicker(pSet, "PillTextCol", "PillTextCol", nx(), function(col) M.F.PillSetColor(col) end)
M.F.MakePicker(pSet, "PillBg", "PillBg", nx(), function() M.F.StylePill() end)
M.F.MakeSlider(pSet, "PillAlpha", "PillAlpha", nx(), function() M.F.StylePill() end)
M.F.MakePicker(pSet, "PillBorderCol", "PillBorderCol", nx(), function() M.F.StylePill() end)
M.F.MakeSlider(pSet, "PillBorderThick", "PillBorderThick", nx(), function() M.F.StylePill() end)

M.F.MakeSection(pSet, "Sec_Music", nx())
M.F.MakeToggle(pSet, "MusicOn", "MusicOn", nx(), function() M.F.PillUpdate() end, false)
M.F.MakeDropdown(pSet, "MusicLayout", M.Schema.Options.MusicLayout, "MusicLayout", nx(), function() if M.F.MusicRelayout then M.F.MusicRelayout() end end)
M.F.MakeSlider(pSet, "MusicWidgetScale", "MusicWidgetScale", nx(), function() end)
do
    local help = M.F.MakeCard(pSet, 150); help.LayoutOrder = nx()
    local label = Instance.new("TextLabel", help)
    label.Size = UDim2.new(1, -24, 1, -10); label.Position = UDim2.new(0, 12, 0, 5); label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium; label.TextSize = 11; label.TextColor3 = M.Style.TextDim
    label.TextWrapped = true; label.TextXAlignment = Enum.TextXAlignment.Left; label.TextYAlignment = Enum.TextYAlignment.Top
    label.Text = M.Translate("MusicHelp")
    table.insert(M.Data.RegUI, {SetLanguage = function() label.Text = M.Translate("MusicHelp") end})
    M.F.MakePresetRow(pSet, nx(), {{Key = "MusicFiles", Id = "files"}}, function() M.F.MusicFiles() end)
end
M.F.MakeSection(pSet, "Sec_UiWidgets", nx())
M.F.MakeToggle(pSet, "SpeedWidgetOn", "SpeedWidgetOn", nx(), function() end, false)
M.F.MakeSlider(pSet, "SpeedWidgetScale", "SpeedWidgetScale", nx(), function() end)
M.F.MakeToggle(pSet, "Ios26On", "Ios26On", nx(), function() M.F.RestyleAllPanels() end, false)

M.F.MakeSection(pSet, "Sec_UiBinds", nx())
M.F.MakeToggle(pSet, "BindListOn", "BindListOn", nx(), function() end, false)
M.F.MakeDropdown(pSet, "BindListShow", M.Schema.Options.BindListShow, "BindListShow", nx(), function() end)
M.F.MakeSlider(pSet, "BindListScale", "BindListScale", nx(), function() end)
M.F.MakePicker(pSet, "BindListOnCol", "BindListOnCol", nx(), function() end)
M.F.MakeToggle(pSet, "BindListKeys", "BindListKeys", nx(), function() end, false)
M.F.MakeToggle(pSet, "BindListStates", "BindListStates", nx(), function() end, false)

M.F.MakeSection(pSet, "Sec_UiKeys", nx())
local function keysRe() M.F.KeysRestyle() end
M.F.MakeToggle(pSet, "KeysOn", "KeysOn", nx(), function() end, false)
M.F.MakeDropdown(pSet, "KeysStyle", M.Schema.Options.KeysStyle, "KeysStyle", nx(), keysRe)
M.F.MakePicker(pSet, "KeysColor", "KeysColor", nx(), keysRe)
M.F.MakePicker(pSet, "KeysBase", "KeysBase", nx(), keysRe)
M.F.MakeSlider(pSet, "KeysScale", "KeysScale", nx(), function() end)
M.F.MakeSlider(pSet, "KeysAlpha", "KeysAlpha", nx(), keysRe)
M.F.MakeSlider(pSet, "KeysRound", "KeysRound", nx(), keysRe)
M.F.MakeToggle(pSet, "KeysFx", "KeysFx", nx(), function() end, false)
M.F.MakeToggle(pSet, "KeysMouse", "KeysMouse", nx(), keysRe, false)
M.F.MakeToggle(pSet, "KeysLabels", "KeysLabels", nx(), keysRe, false)
end

end}

-- [64/69] Жидкое стекло
MODULES[#MODULES + 1] = {"64. Жидкое стекло", function(M, __X)
-- ==============================================================================
-- [ ЖИДКОЕ СТЕКЛО ]
-- ==============================================================================
function M.F.EnsureGlassBlur()
    if M.Data.FxGlassBlur and M.Data.FxGlassBlur.Parent then return M.Data.FxGlassBlur end
    local blur = Instance.new("BlurEffect")
    blur.Size = 0
    blur.Enabled = false
    blur.Parent = M.Services.L
    M.Data.FxGlassBlur = blur
    return blur
end

-- размытие мира за меню
function M.F.UpdateGlassBlur(open, duration)
    local want = 0
    if open and M.State.GlassOn then
        want = M.State.GlassBlur * math.clamp(M.State.MenuAlpha * 2, 0.2, 1)
        if M.F.VisualLevel and M.F.VisualLevel() >= 2 then want = 0 end
    end
    if want <= 0.05 then want = 0 end

    M.Data.GlassToken = M.Data.GlassToken + 1
    local token = M.Data.GlassToken
    local blur = (want > 0) and M.F.EnsureGlassBlur() or (M.Data.FxGlassBlur and M.Data.FxGlassBlur.Parent and M.Data.FxGlassBlur)
    if not blur then return end

    local fade = duration or ((want > 0) and 0.3 or 0.25)
    if want > 0 then blur.Enabled = true end
    M.Services.T:Create(blur, TweenInfo.new(duration and fade or fade * M.Style.Scale(), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = want}):Play()
    if want == 0 then
        task.delay(fade + 0.05, function()
            if token ~= M.Data.GlassToken or not blur.Parent then return end
            blur.Enabled = false
            if not M.State.GlassOn or M.State.GlassBlur <= 0.05 then
                blur:Destroy()
                if M.Data.FxGlassBlur == blur then M.Data.FxGlassBlur = nil end
            end
        end)
    end
end

-- «Жидкость»
function M.F.GlassDrift()
    local D = M.Data
    local grad = M.UI.GlassSheenGrad
    local want = grad ~= nil and M.State.GlassOn and M.State.UiFx and M.Run.MenuOpen and not M.Run.IsShutDown
    if want then
        if D.GlassDriftTween then return end
        grad.Offset = Vector2.new(-0.3, 0)
        local ok, tween = pcall(function()
            return M.Services.T:Create(grad, TweenInfo.new(9 * M.Style.Scale(), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                {Offset = Vector2.new(0.3, 0)})
        end)
        if ok and tween then
            D.GlassDriftTween = tween
            tween:Play()
        end
    elseif D.GlassDriftTween then
        pcall(function() D.GlassDriftTween:Cancel() end)
        D.GlassDriftTween = nil
        if grad and grad.Parent then grad.Offset = Vector2.zero end
    end
end

function M.F.ApplyGlass()
    if not M.UI.Main then return end

    local on = M.State.GlassOn
    M.Style.ApplyGlassSurfaces()
    local sheen = math.clamp(M.State.GlassSheen, 0, 1)
    local seeThrough = math.clamp(M.State.MenuAlpha * 1.8, 0.6, 1)
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
        -- лёгкий вертикальный перелив фона
        M.UI.MainGrad.Color = on
            and ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(196, 200, 220))
            or ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255))
    end
    if M.UI.MainStrokeGrad then
        M.UI.MainStrokeGrad.Enabled = on
        local rim = 0.4 + 0.6 * sheen
        -- рамка окна
        M.UI.MainStrokeGrad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1 - 0.85 * rim),
            NumberSequenceKeypoint.new(0.3, 0.6),
            NumberSequenceKeypoint.new(0.7, 0.75),
            NumberSequenceKeypoint.new(1, 1 - 0.7 * rim)
        })
    end
    if M.UI.MainGlow then M.UI.MainGlow.Set(on and M.Style.SurfaceGlow or 0, 0.3) end
    M.F.UpdateGlassBlur(M.Run.MenuOpen)
    M.F.GlassDrift()
end

end}

-- [65/69] Плавное появление и слои меню
MODULES[#MODULES + 1] = {"65. Плавное появление и слои меню", function(M, __X)
-- ==============================================================================
-- [ ПОЯВЛЕНИЕ МЕНЮ ]
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
                descend = false  -- скрытое поддерево не трогаем
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

-- готовит анимацию
function M.F.FadePrepare(key, roots, startVisibility)
    if M.F.CascadeFinish then M.F.CascadeFinish() end
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

-- плавно ведёт видимость к target
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
        local visibility = from + (target - from) * eased
        if math.abs(visibility - state.Visibility) > 0.002 or progress >= 1 then
            state.Visibility = visibility
            M.F.FadeApply(state.Entries, visibility)
        end
        if progress >= 1 then
            if state.Conn then state.Conn:Disconnect(); state.Conn = nil end
            state.Visibility = target
            if onDone then onDone() end
        end
    end)
end

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

-- всё меню
function M.F.BuildMenuLayers()
    local main = M.UI.Main

    M.UI.MainGlow = M.Style.AccentGlow(main, 22, M.Style.SurfaceGlow, UDim.new(0, 26), -1)

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ClipsDescendants = true
    content.Parent = main

    local bg = Instance.new("Frame")
    bg.Name = "MenuBg"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = M.State.MainBg
    bg.BackgroundTransparency = M.State.MenuAlpha
    bg.BorderSizePixel = 0
    bg.Active = false
    bg.ZIndex = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 14)
    bg.Parent = content
    main.BackgroundTransparency = 1
    M.UI.MenuBg = bg

    for _, child in ipairs(main:GetChildren()) do
        if child:IsA("GuiObject") and child ~= content and child.Name ~= "Glow" then
            child.Parent = content
        end
    end
    M.UI.Content = content

    local topLine = Instance.new("Frame")
    topLine.Name = "TopAccent"
    topLine.AnchorPoint = Vector2.new(0.5, 0)
    topLine.Position = UDim2.new(0.5, 0, 0, 0)
    topLine.Size = UDim2.new(0.62, 0, 0, 2)
    topLine.BorderSizePixel = 0
    topLine.Active = false
    topLine.ZIndex = 50
    M.Style.Bind(topLine, "BackgroundColor3", 0.15)
    local topFade = Instance.new("UIGradient", topLine)
    topFade.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1)
    })
    topLine.Parent = content

    local sheen = Instance.new("Frame")
    sheen.Name = "GlassSheen"
    sheen.Size = UDim2.new(1, 0, 1, 0)
    sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sheen.BorderSizePixel = 0
    sheen.Active = false
    sheen.ZIndex = 100
    Instance.new("UICorner", sheen).CornerRadius = UDim.new(0, 14)
    local sheenGrad = Instance.new("UIGradient", sheen)
    sheenGrad.Rotation = 35
    sheen.Parent = content
    M.UI.GlassSheen, M.UI.GlassSheenGrad = sheen, sheenGrad
    -- остальные слои матового стекла
    M.UI.MainGlass = M.Style.BuildGlass(content, UDim.new(0, 14), {ZIndex = 99, NoSheen = true})

    M.UI.MainGrad = Instance.new("UIGradient", bg)
    M.UI.MainGrad.Rotation = 35
    M.UI.MainStrokeGrad = Instance.new("UIGradient", M.UI.MainStroke)
    M.UI.MainStrokeGrad.Rotation = 45
    M.F.ApplyGlass()
end

end}

-- [66/69] Открытие и закрытие меню
MODULES[#MODULES + 1] = {"66. Открытие и закрытие меню", function(M, __X)
-- ==============================================================================
-- [ ОТКРЫТИЕ И ЗАКРЫТИЕ МЕНЮ ]
-- ==============================================================================
M.F.BuildMenuLayers()

-- одна анимация для всех частей меню
local MENU_RISE = 14
local function menuShifted(rest, dy)
    return UDim2.new(rest.X.Scale, rest.X.Offset, rest.Y.Scale, rest.Y.Offset + dy)
end
local function menuSlideTo(goal, duration, style, direction, rest, hideAfter, token)
    if M.Data.MenuTween then pcall(function() M.Data.MenuTween:Cancel() end) end
    M.Data.MenuSlide = true
    local tween = M.Style.Tween(M.UI.Main, duration, {Position = goal}, style, direction, true)  -- длительность уже из AnimSpeed
    M.Data.MenuTween = tween
    tween.Completed:Connect(function(state)
        if token ~= M.Data.MenuToken or state ~= Enum.PlaybackState.Completed then return end
        M.Data.MenuSlide = false
        if hideAfter then M.UI.Main.Position = rest end
    end)
end

function M.F.CloseMenu()
    if M.F.CloseBindMenu then M.F.CloseBindMenu() end
    if M.F.AuroraHide then M.F.AuroraHide() end
    M.Run.MenuOpen = false
    M.Data.MenuToken = M.Data.MenuToken + 1
    local token = M.Data.MenuToken

    local duration = math.max(M.State.AnimSpeed * 1.1, 0.22)
    local rest = M.Data.MenuSlide and M.Data.MenuRest or M.UI.Main.Position
    M.Data.MenuRest = rest
    menuSlideTo(menuShifted(rest, MENU_RISE * 0.7), duration, Enum.EasingStyle.Quint, Enum.EasingDirection.In, rest, true, token)
    M.F.FadePrepare("Menu", {M.UI.Main}, 1)
    M.F.FadeTo("Menu", 0, duration, function()
        if token ~= M.Data.MenuToken then return end
        M.UI.Main.Visible = false
        M.UI.Main.Position = rest
        M.Data.MenuSlide = false
        M.F.FadeFinish("Menu")
    end)
    M.F.UpdateGlassBlur(false, duration)
    M.F.GlassDrift()
end

function M.F.OpenMenu()
    if M.Data.ConfirmOpen then return end
    M.Run.MenuOpen = true
    M.Data.MenuToken = M.Data.MenuToken + 1
    local token = M.Data.MenuToken

    local rest = M.Data.MenuSlide and M.Data.MenuRest or M.UI.Main.Position
    M.Data.MenuRest = rest
    local duration = math.max(M.State.AnimSpeed * 1.7, 0.35)
    if not M.UI.Main.Visible then M.UI.Main.Position = menuShifted(rest, MENU_RISE) end
    menuSlideTo(rest, duration * 1.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, rest, false, token)

    M.UI.Main.Visible = true
    M.F.FadePrepare("Menu", {M.UI.Main}, 0)

    M.F.FadeTo("Menu", 1, duration, function()
        if token ~= M.Data.MenuToken or not M.Run.MenuOpen then return end
        M.F.FadeFinish("Menu")
    end)

    task.delay(0.04, function()
        if token ~= M.Data.MenuToken or not M.Run.MenuOpen then return end
        M.F.UpdateGlassBlur(true, math.max(duration - 0.04, 0.1))
        M.F.GlassDrift()
    end)
end

end}

-- [67/69] Живой интерфейс (сияние, индикатор вкладок, каскад)
MODULES[#MODULES + 1] = {"67. Живой интерфейс (сияние, индикатор вкладок, каскад)", function(M, __X)
-- ==============================================================================
-- [ ЖИВОЙ ИНТЕРФЕЙС ]
-- ==============================================================================

-- мягкое пятно света
function M.F.SoftBlob(parent, diameter, color, peak, zindex, steps)
    local host = Instance.new("Frame")
    host.Name = "Blob"
    host.AnchorPoint = Vector2.new(0.5, 0.5)
    host.Size = UDim2.fromOffset(diameter, diameter)
    host.BackgroundTransparency = 1
    host.BorderSizePixel = 0
    host.Active = false
    host.ZIndex = zindex
    host.Parent = parent
    steps = steps or 14
    local layers = {}
    for i = 1, steps do
        local ring = Instance.new("Frame")
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Position = UDim2.new(0.5, 0, 0.5, 0)
        ring.Size = UDim2.new(i / steps, 0, i / steps, 0)
        ring.BackgroundColor3 = color
        ring.BackgroundTransparency = 1 - peak / steps
        ring.BorderSizePixel = 0
        ring.Active = false
        ring.ZIndex = zindex
        Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5, 0)
        ring.Parent = host
        layers[i] = ring
    end
    return host, layers
end

do
local okFx, errFx = pcall(function()
    local main, content = M.UI.Main, M.UI.Content
    local RunS = M.Services.R
    -- оттенок темы, сдвинутый по кругу цветов
    local function tint(shift)
        local h, s, v = M.State.Accent:ToHSV()
        return Color3.fromHSV((h + shift) % 1, math.clamp(s, 0.35, 1), math.clamp(v, 0.6, 1))
    end

    local aurora = Instance.new("Frame")
    aurora.Name = "Aurora"
    aurora.Size = UDim2.new(1, 0, 1, 0)
    aurora.BackgroundTransparency = 1
    aurora.BorderSizePixel = 0
    aurora.Active = false
    aurora.ClipsDescendants = true
    aurora.ZIndex = 90
    aurora.Visible = false  -- включается, когда меню полностью открылось
    Instance.new("UICorner", aurora).CornerRadius = UDim.new(0, 14)
    aurora.Parent = content

    local blobs = {}
    local function addBlob(diameter, shift, peak, baseX, baseY, ampX, ampY, speedX, speedY, phase)
        local host, layers = M.F.SoftBlob(aurora, diameter, tint(shift), peak, 90, 7)
        blobs[#blobs + 1] = {Host = host, Layers = layers, Shift = shift, BX = baseX, BY = baseY, AX = ampX, AY = ampY,
            SX = speedX, SY = speedY, Phase = phase, Target = layers[1].BackgroundTransparency}
    end
    addBlob(420, 0, 0.11, 0.62, 0.18, 0.16, 0.12, 0.23, 0.31, 0)
    addBlob(360, 0.09, 0.09, 0.86, 0.82, 0.10, 0.14, 0.29, 0.21, 2.1)
    addBlob(320, -0.07, 0.08, 0.42, 0.96, 0.18, 0.08, 0.19, 0.27, 4.2)

    local function recolor()
        for _, blob in ipairs(blobs) do
            local col = tint(blob.Shift)
            for _, ring in ipairs(blob.Layers) do ring.BackgroundColor3 = col end
        end
    end

    local auroraOn = false
    local function auroraShow()
        auroraOn = true
        for _, blob in ipairs(blobs) do
            for _, ring in ipairs(blob.Layers) do
                ring.BackgroundTransparency = 1
                M.Services.T:Create(ring, M.Style.Info(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    {BackgroundTransparency = blob.Target}):Play()
            end
        end
        aurora.Visible = true
    end
    local function auroraHide()
        auroraOn = false
        aurora.Visible = false
    end

    local indicator = Instance.new("Frame")
    indicator.Name = "TabIndicator"
    indicator.AnchorPoint = Vector2.new(0, 0.5)
    indicator.Size = UDim2.fromOffset(3, 0)
    indicator.Position = UDim2.fromOffset(2, 0)
    indicator.BorderSizePixel = 0
    indicator.Active = false
    indicator.ZIndex = 6
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)
    -- сначала родитель, потом привязка к теме
    indicator.Parent = M.UI.Sidebar
    M.Style.Bind(indicator, "BackgroundColor3", 0.15)
    M.Style.AccentGlow(indicator, 7, 0.6, UDim.new(1, 0), 5)

    local startedAt = os.clock()
    local lastAccent = M.Data.AccentVersion
    local springY, springV, springReady = 0, 0, false
    local shownY, shownH = -1e9, -1e9
    local function step(dt)
        if M.Run.IsShutDown then return end
        local fx = M.State.UiFx
        local now = os.clock() - startedAt

        if main.Visible then
            -- сияние
            local settled = fx and M.Run.MenuOpen and M.Data.Fades.Menu == nil and M.F.VisualLevel() < 1
            if settled and not auroraOn then auroraShow()
            elseif not settled and auroraOn then auroraHide() end

            if lastAccent ~= M.Data.AccentVersion then
                lastAccent = M.Data.AccentVersion
                recolor()
            end
            -- индикатор вкладки
            local tab, list = M.UI.TabButtons[M.State.ActiveTab], M.UI.TabContainer
            if tab and tab.Parent and list.AbsoluteSize.Y > 0 then
                local centre = tab.AbsolutePosition.Y + tab.AbsoluteSize.Y / 2
                local inView = centre > list.AbsolutePosition.Y + 6 and centre < list.AbsolutePosition.Y + list.AbsoluteSize.Y - 6
                local target = centre - M.UI.Sidebar.AbsolutePosition.Y
                if not (target > -1e5 and target < 1e5) then target = (springY == springY and math.abs(springY) < 1e5) and springY or 0 end
                if not springReady or not fx then
                    springY, springV, springReady = target, 0, true
                else
                    local total = math.min(dt, 1 / 30) * math.max(1 / M.Style.Scale(), 0.5)
                    local steps = math.max(1, math.ceil(total * 90))
                    local h = total / steps
                    for _ = 1, steps do
                        springV = springV + ((target - springY) * 260 - springV * 22) * h
                        springY = springY + springV * h
                    end
                    if springY ~= springY or math.abs(springY) > 1e5 then springY, springV = target, 0 end
                end
                local height = inView and (18 + math.clamp(math.abs(springV) * 0.05, 0, 16)) or 0
                if math.abs(springY - shownY) > 0.02 then
                    shownY = springY
                    indicator.Position = UDim2.fromOffset(2, springY)
                end
                if math.abs(height - shownH) > 0.02 then
                    shownH = height
                    indicator.Size = UDim2.fromOffset(3, height)
                end
            end

            if auroraOn and now - (blobs.Last or -1) >= 0.05 then
                blobs.Last = now
                for _, blob in ipairs(blobs) do
                    blob.Host.Position = UDim2.fromScale(
                        blob.BX + blob.AX * math.sin(now * blob.SX + blob.Phase),
                        blob.BY + blob.AY * math.sin(now * blob.SY + blob.Phase * 0.7))
                end
            end
        elseif auroraOn then
            auroraHide()
        end

        if fx then
            local widget = M.UI.SpeedWidget
            if widget and widget.Panel.Glow and widget.Panel.Root.Visible and M.State.Ios26On and not widget.Panel.Dragging then
                local want = M.Style.SurfaceGlow + 0.28 * math.clamp(M.Data.SpeedShown / 90, 0, 1)
                if math.abs(want - (widget.GlowSeen or -1)) > 0.015 then
                    widget.GlowSeen = want
                    widget.Panel.Glow.Set(want, 0)
                end
            end
        end
    end
    M.Track(RunS.RenderStepped:Connect(function(dt) pcall(step, dt) end))

    -- перед закрытием меню сияние убираем
    function M.F.AuroraHide()
        if auroraOn then auroraHide() end
    end

    function M.F.CascadeFinish()
        local run = M.Data.Cascade
        if not run then return end
        M.Data.Cascade = nil
        if run.Conn then run.Conn:Disconnect() end
        for i, entries in ipairs(run.Entries) do
            M.F.FadeApply(entries, 1)
            local stroke = run.Strokes[i]
            if stroke and stroke.Parent then stroke.Color = M.Style.Stroke end
        end
    end

    function M.F.PageCascade(pack)
        M.F.CascadeFinish()
        M.F.FadeFinish("Page")
        local items = {}
        for _, child in ipairs(pack.Container:GetChildren()) do
            if child:IsA("GuiObject") and child.Visible then items[#items + 1] = child end
        end
        table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
        local count = math.min(#items, 14)
        if count == 0 then return end
        local speed = M.Style.Scale()
        local run = {Entries = {}, Strokes = {}, Start = os.clock(), Count = count}
        for i = 1, count do
            run.Entries[i] = M.F.FadeCollect({items[i]})
            run.Strokes[i] = items[i]:FindFirstChildOfClass("UIStroke")
            M.F.FadeApply(run.Entries[i], 0)
        end
        M.Data.Cascade = run
        run.Conn = RunS.RenderStepped:Connect(function()
            if M.Run.IsShutDown then M.F.CascadeFinish() return end
            local elapsed = os.clock() - run.Start
            local finished = true
            for i = 1, run.Count do
                local progress = math.clamp((elapsed - (i - 1) * 0.04 * speed) / (0.38 * speed), 0, 1)
                local eased = 1 - (1 - progress) ^ 3
                M.F.FadeApply(run.Entries[i], eased)
                local stroke = run.Strokes[i]
                if stroke and stroke.Parent then stroke.Color = M.State.Accent:Lerp(M.Style.Stroke, eased) end
                if progress < 1 then finished = false end
            end
            if finished then M.F.CascadeFinish() end
        end)
    end

end)
if not okFx then M.Errors.Hit("LiveUI", errFx) end
end

end}

-- [68/69] Диалог подтверждения и выгрузка скрипта
MODULES[#MODULES + 1] = {"68. Диалог подтверждения и выгрузка скрипта", function(M, __X)
-- ==============================================================================
-- [ ДИАЛОГ ПОДТВЕРЖДЕНИЯ ]
-- ==============================================================================
local function confirmButton(parent, text, anchorX, tint, onClick)
    local button = Instance.new("TextButton")
    button.AnchorPoint = Vector2.new(0.5, 1)
    button.Position = UDim2.new(anchorX, 0, 1, -24)
    button.Size = UDim2.fromOffset(160, 40)
    button.AutoButtonColor = false
    button.BorderSizePixel = 0
    local base = tint and tint:Lerp(M.Style.Raised, 0.78) or M.Style.Raised
    local hover = tint and tint:Lerp(M.Style.Raised, 0.5) or M.State.Accent:Lerp(M.Style.Raised, 0.8)
    button.BackgroundColor3 = base
    button.Text = text
    button.TextColor3 = tint and tint:Lerp(Color3.new(1, 1, 1), 0.45) or M.Style.Text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
    local stroke = M.Style.AddStroke(button, tint or M.Style.Stroke, 1, tint and 0.55 or M.Style.StrokeIdle)
    local scale = Instance.new("UIScale", button)
    button.MouseEnter:Connect(function()
        M.Style.Tween(button, 0.18, {BackgroundColor3 = hover})
        M.Style.Tween(stroke, 0.18, {Color = tint or M.State.Accent, Transparency = M.Style.StrokeActive})
    end)
    button.MouseLeave:Connect(function()
        M.Style.Tween(button, 0.25, {BackgroundColor3 = base})
        M.Style.Tween(stroke, 0.25, {Color = tint or M.Style.Stroke, Transparency = tint and 0.55 or M.Style.StrokeIdle})
        M.Style.Tween(scale, 0.2, {Scale = 1})
    end)
    button.MouseButton1Down:Connect(function() M.Style.Tween(scale, 0.1, {Scale = 0.95}) end)
    button.MouseButton1Up:Connect(function() M.Style.Tween(scale, 0.3, {Scale = 1}, Enum.EasingStyle.Back) end)
    button.MouseButton1Click:Connect(onClick)
    M.F.FitText(button, 10)
    button.Parent = parent
    return button
end

function M.F.Confirm(kind)
    if M.Data.ConfirmOpen or M.Run.IsShutDown or not M.UI.Main then return end
    M.Data.ConfirmOpen = true
    local isExit = (kind == "exit")

    -- меню закрывается, мир размывается
    if M.Run.MenuOpen then M.F.CloseMenu() end
    local blur = Instance.new("BlurEffect")
    blur.Size = 0
    blur.Parent = M.Services.L
    M.Data.FxConfirmBlur = blur
    M.Style.Tween(blur, 0.4, {Size = 22})

    local gui = Instance.new("ScreenGui")
    gui.Name = M.Services.H:GenerateGUID(false)
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 400
    gui.IgnoreGuiInset = true
    gui.Parent = M.TargetGui
    M.F.WatchFonts(gui)
    M.UI.ConfirmGui = gui

    -- затемнение
    local dim = Instance.new("Frame")
    dim.Size = UDim2.new(1, 0, 1, 0)
    dim.BackgroundColor3 = M.Style.Bg
    dim.BackgroundTransparency = 1
    dim.BorderSizePixel = 0
    dim.Active = true
    dim.Parent = gui
    M.Style.Tween(dim, 0.35, {BackgroundTransparency = 0.55})

    local panel = M.F.MakePanel(gui, "Confirm", 430, 214, 26, "Confirm", false)
    panel.Root.Visible = true
    local scale = panel.Scale
    scale.Scale = 0.9
    M.Style.Tween(scale, 0.45, {Scale = 1}, Enum.EasingStyle.Quint)

    local title = Instance.new("TextLabel", panel.Content)
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 0, 0, 26)
    title.Size = UDim2.new(1, 0, 0, 26)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 19
    title.TextColor3 = M.Style.Text
    title.Text = M.Translate(isExit and "Confirm_ExitTitle" or "Confirm_PanicTitle")
    M.F.FitText(title, 12)

    local message = Instance.new("TextLabel", panel.Content)
    message.BackgroundTransparency = 1
    message.Position = UDim2.new(0, 32, 0, 62)
    message.Size = UDim2.new(1, -64, 0, 62)
    message.Font = Enum.Font.GothamMedium
    message.TextSize = 13
    message.TextColor3 = M.Style.TextDim
    message.TextWrapped = true
    message.TextYAlignment = Enum.TextYAlignment.Top
    message.Text = M.Translate(isExit and "Confirm_ExitText" or "Confirm_PanicText")
    M.F.FitText(message, 10)

    local closing, keyConn = false, nil
    local function close(afterClose)
        if closing then return end
        closing = true
        if keyConn then keyConn:Disconnect() end
        M.Style.Tween(dim, 0.28, {BackgroundTransparency = 1})
        M.Style.Tween(scale, 0.28, {Scale = 0.94}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        M.F.FadePrepare("Confirm", {panel.Root}, 1)
        M.F.FadeTo("Confirm", 0, 0.28 * M.Style.Scale(), function()
            M.F.FadeFinish("Confirm")
            pcall(M.F.DestroyPanel, panel)
            if gui.Parent then gui:Destroy() end
            if M.UI.ConfirmGui == gui then M.UI.ConfirmGui = nil end
        end)
        if blur.Parent then
            M.Style.Tween(blur, 0.35, {Size = 0})
            task.delay(0.4, function()
                if blur.Parent then blur:Destroy() end
                if M.Data.FxConfirmBlur == blur then M.Data.FxConfirmBlur = nil end
            end)
        end
        if afterClose then afterClose() end
    end

    local function answerNo()
        close(function()
            M.Data.ConfirmOpen = false
            if not M.Run.IsShutDown then M.F.OpenMenu() end
        end)
    end
    local function answerYes()
        if isExit then
            close(function()
                task.delay(0.3, function()
                    M.Data.ConfirmOpen = false
                    M.F.ShutDown()
                end)
            end)
        else
            close(function()
                M.Data.ConfirmOpen = false
                M.F.PanicReset()
                M.F.OpenMenu()
            end)
        end
    end

    confirmButton(panel.Content, M.Translate("Confirm_No"), 0.28, nil, answerNo)
    confirmButton(panel.Content, M.Translate("Confirm_Yes"), 0.72, M.Style.Danger, answerYes)

    keyConn = M.Services.U.InputBegan:Connect(function(inp)
        if inp.KeyCode == Enum.KeyCode.Escape then answerNo() end
    end)

    M.F.FadePrepare("Confirm", {panel.Root}, 0)
    M.F.FadeTo("Confirm", 1, 0.35 * M.Style.Scale(), function() M.F.FadeFinish("Confirm") end)
end

function M.F.ShutDown()
    M.Run.IsShutDown = true
    pcall(M.F.StopFreecam)
    local function try(fn, ...) pcall(fn, ...) end
    local function disconnectAll(list)
        for _, conn in pairs(list) do
            if conn then pcall(function() conn:Disconnect() end) end
        end
    end

    try(function()
        local shakeCam = workspace.CurrentCamera
        if shakeCam then M.F.UndoShake(shakeCam) end
    end)
    pcall(function() M.Services.R:UnbindFromRenderStep("ShakeUndo") end)
    pcall(function() M.Services.R:UnbindFromRenderStep("TPRestore") end)
    pcall(function() M.Services.R:UnbindFromRenderStep("CamProcessor") end)
    pcall(function() M.Services.R:UnbindFromRenderStep("FovProcessor") end)
    pcall(function() M.Services.R:UnbindFromRenderStep("PlayerViewFrame") end)
    pcall(function() M.Services.R:UnbindFromRenderStep("ArrowsFrame") end)
    pcall(function() M.Services.R:UnbindFromRenderStep("AimMarkerFrame") end)
    try(M.F.TriggerRelease)

    disconnectAll(M.Data.Conns)
    M.Data.Conns = {}
    disconnectAll(M.Data.CharConns)
    M.Data.CharConns = {}
    disconnectAll(M.Data.PlayerConns)
    M.Data.PlayerConns = {}
    disconnectAll(M.Data.PlayerViewConns)
    M.Data.PlayerViewConns = {}

    try(function() if M.UI.WallPassLoop then M.UI.WallPassLoop:Disconnect(); M.UI.WallPassLoop = nil end end)
    M.Data.WallReleasePending = false

    try(function()
        local char = M.LP and M.LP.Character
        M.F.ReleaseSpeedBoost(char and M.GetHumanoid(char))
    end)
    try(M.F.StopFlying)
    try(M.F.SetWallPass, false)
    M.State.FpsBoost, M.State.OptLight = false, false
    try(M.F.RefreshOptimization)
    try(M.ApplyFpsUnlocker, false)
    M.State.PlayerView = false; try(M.F.UpdatePlayerView)
    M.State.FogOn = false; try(M.F.ApplyFog)
    M.State.CloudsOn = false; try(M.F.ApplyClouds)
    M.State.SunRaysOn = false; try(M.F.ApplySunRays)
    try(function()
        if M.Data.FxGlassBlur and M.Data.FxGlassBlur.Parent then M.Data.FxGlassBlur:Destroy() end
        M.Data.FxGlassBlur = nil
        if M.Data.GlassDriftTween then pcall(function() M.Data.GlassDriftTween:Cancel() end) end
        M.Data.GlassDriftTween = nil
        if M.Data.FxConfirmBlur and M.Data.FxConfirmBlur.Parent then M.Data.FxConfirmBlur:Destroy() end
        M.Data.FxConfirmBlur = nil
        if M.Data.FxIntroBlur and M.Data.FxIntroBlur.Parent then M.Data.FxIntroBlur:Destroy() end
        M.Data.FxIntroBlur = nil
        if M.UI.ConfirmGui then M.UI.ConfirmGui:Destroy() end
        M.UI.ConfirmGui = nil
    end)
    M.State.GradeOn = false; try(M.F.ApplyGrade)
    M.State.DamageNumbers = false
    M.State.SpectateOn = false; try(M.F.UpdateSpectate)
    M.Run.MenuOpen = false
    try(M.F.RestoreCursor)
    try(function() if M.F.UnwatchTeams then M.F.UnwatchTeams() end end)
    -- модули выгружаются по одному
    for i = #M.ModuleOrder, 1, -1 do try(M.F.UnloadModule, M.ModuleOrder[i]) end
    -- всё, что скрипт нарисовал поверх экрана
    try(function() if M.Draw then M.Draw.RemoveAll() end end)
    try(M.F.FadeFinishAll)
    M.State.DarkWorld = false; try(M.F.ApplyDark)
    M.State.SkyOn = false; try(M.F.RestoreSky)
    try(M.F.ClearLeaves)
    M.State.TimeOn = false; try(M.F.ApplyTime)
    M.State.WeatherOn = false; try(M.F.ClearWeatherProps)
    M.State.OrbitOn = false
    try(function() for _, item in ipairs(M.Data.OrbitObjs) do if item.Part then item.Part:Destroy() end end end)

    local cam = workspace.CurrentCamera
    -- возвращаем FOV игры
    M.State.FovOn = false
    M.State.ZoomOn = false
    M.Data.ZoomHeld = false
    M.Data.ZoomBlend = 0
    if cam then try(M.F.UpdateFov, cam, 0.016) end

    M.State.ThirdPerson = false
    try(M.F.UpdateThirdPerson, cam, nil, nil, false)
    try(function() if cam and M.Data.TPGameCF then cam.CFrame = M.Data.TPGameCF end; M.Data.TPGameCF = nil end)
    M.State.FallProtection = false
    try(M.F.UpdateFallProtection)
    M.State.AutoJump = false
    M.State.AntiStun = false
    M.State.IdleProtection = false
    try(M.F.SetIdleProtection, false)
    M.State.HideHats = false
    M.State.HoloSelf = false
    try(M.UpdatePlayerVisuals)

    M.State.FreezeChar = false
    M.State.FakeLag = false
    M.State.ServerGhosts = false
    try(M.F.ClearGhosts)
    try(function() local _, hum, root = M.GetSelf(); M.F.UpdateDesync(0, root, hum, workspace.CurrentCamera) end)
    M.State.SpinCharacter = false
    M.State.BackWalk = false
    M.State.HeadTiltOn = false
    try(M.F.UpdatePoseReal, 0)

    -- окна и папки скрипта удаляются по одной
    try(function() if M.UI.Gui then M.UI.Gui:Destroy() end end)
    try(function() if M.UI.PillGui then M.UI.PillGui:Destroy() end end)
    try(function() if M.UI.PlayerViewGui then M.UI.PlayerViewGui:Destroy() end end)
    try(function() if M.UI.HuiFolder then M.UI.HuiFolder:Destroy(); M.UI.HuiFolder = nil end end)
    try(function() if M.UI.NotifyGui then M.UI.NotifyGui:Destroy() end end)
    try(function() if M.UI.WidgetGui then M.UI.WidgetGui:Destroy() end end)
    for key in pairs(M.Data.FolderNames) do
        try(function() if M.UI[key] then M.UI[key]:Destroy() end end)
        M.UI[key] = nil
    end

    try(function()
        local env = getgenv and getgenv()
        if type(env) == "table" and env.__MatsysenseShutdown == M.Data.ShutdownHook then env.__MatsysenseShutdown = nil end
    end)
end

M.UI.Main.Visible = false

end}

-- [69/69] Заставка и запуск
MODULES[#MODULES + 1] = {"69. Заставка и запуск", function(M, __X)
-- ==============================================================================
-- [ ЗАСТАВКА И ЗАПУСК ]
-- ==============================================================================
function M.F.RunIntro()
    local introGui = Instance.new("ScreenGui")
    introGui.Name = M.Services.H:GenerateGUID(false)
    introGui.ResetOnSpawn = false
    -- 99999 заменено на небольшое число
    introGui.DisplayOrder = 210
    introGui.IgnoreGuiInset = true
    introGui.Parent = M.TargetGui
    M.Data.IntroGui = introGui

    local function pause(seconds)
        local waited = 0
        while waited < seconds and not M.Run.IsShutDown do
            waited = waited + task.wait(0.03)
        end
    end
    local function tween(inst, duration, goal, style, direction, raw)
        local seconds = raw and duration or duration * M.Style.Scale()
        local t = M.Services.T:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Sine, direction or Enum.EasingDirection.InOut), goal)
        t:Play()
        return t
    end
    -- бесконечный твин
    local function loop(inst, duration, goal, style, reverse)
        local t = M.Services.T:Create(inst, TweenInfo.new(duration * M.Style.Scale(), style or Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, reverse == true), goal)
        t:Play()
        return t
    end
    local function ease(alpha) return -(math.cos(math.pi * alpha) - 1) / 2 end  -- кривая Sine InOut
    local function round(inst, radius)
        Instance.new("UICorner", inst).CornerRadius = radius
        return inst
    end
    local function tintOf(shift)
        local h, s, v = M.State.Accent:ToHSV()
        return Color3.fromHSV((h + shift) % 1, math.clamp(s, 0.35, 1), math.clamp(v, 0.6, 1))
    end
    local WHITE = Color3.fromRGB(255, 255, 255)

    local introBlur = Instance.new("BlurEffect")
    introBlur.Size = 0
    introBlur.Parent = M.Services.L
    M.Data.FxIntroBlur = introBlur

    local backdrop = Instance.new("Frame")
    backdrop.Size = UDim2.new(1, 0, 1, 36)
    backdrop.Position = UDim2.new(0, 0, 0, -36)
    backdrop.BackgroundColor3 = Color3.fromRGB(2, 3, 6)
    backdrop.BackgroundTransparency = 1
    backdrop.BorderSizePixel = 0
    backdrop.Parent = introGui

    -- вся сцена в одном контейнере
    local scene = Instance.new("Frame")
    scene.Name = "Scene"
    scene.Size = UDim2.new(1, 0, 1, 0)
    scene.BackgroundTransparency = 1
    scene.BorderSizePixel = 0
    scene.Parent = backdrop

    -- фон тёмный: на нём только частицы и карточка
    local particles = {}
    for i = 1, 26 do
        local size = 2 + math.random() * 2.5
        local dot = Instance.new("Frame")
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Size = UDim2.fromOffset(size, size)
        dot.BackgroundTransparency = 0.35 + math.random() * 0.5
        dot.BorderSizePixel = 0
        round(dot, UDim.new(1, 0))
        dot.Parent = scene
        particles[i] = {Obj = dot, X = math.random(), Y = math.random(), Speed = 0.02 + math.random() * 0.05,
            Amp = 0.004 + math.random() * 0.012, Freq = 0.4 + math.random() * 1.2, Phase = math.random() * 6.28,
            Mix = 0.3 + math.random() * 0.6}
    end

    -- ---------------- Карточка ----------------
    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.Size = UDim2.fromOffset(500, 224)
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    card.Parent = scene
    local cardScale = Instance.new("UIScale", card)
    cardScale.Scale = 0.9

    local cardGlow = M.Style.Glow(card, 34, M.Style.SurfaceGlow * 1.6, M.State.Accent, UDim.new(0, 60), 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = M.State.PillBg
    fill.BackgroundTransparency = 0.1
    fill.BorderSizePixel = 0
    round(fill, UDim.new(0, 38))
    fill.Parent = card

    M.Style.BuildGlass(card, UDim.new(0, 38), {})

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Parent = card

    local rim = Instance.new("Frame")
    rim.Size = UDim2.new(1, 0, 1, 0)
    rim.BackgroundTransparency = 1
    rim.BorderSizePixel = 0
    round(rim, UDim.new(0, 38))
    local rimStroke = Instance.new("UIStroke")
    rimStroke.Thickness = 1.4
    rimStroke.Color = WHITE
    rimStroke.Transparency = 0
    rimStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    rimStroke.Parent = rim
    local rimGrad = Instance.new("UIGradient", rimStroke)
    rimGrad.Rotation = 90
    rimGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.75),
        NumberSequenceKeypoint.new(1, 0.35)
    })
    rim.Parent = card
    -- кромка карточки медленно вращается
    local rimSpin = loop(rimGrad, 9, {Rotation = 450})

    -- ---------------- Логотип ----------------
    local letters = {}
    local word = {{"M", 44}, {"A", 36}, {"T", 32}, {"S", 31}, {"Y", 34}, {"S", 31}, {"E", 30}, {"N", 37}, {"S", 31}, {"E", 30}}
    local totalWidth = 0
    for _, item in ipairs(word) do totalWidth = totalWidth + item[2] end
    local cursor = (500 - totalWidth) / 2
    local LETTER_Y = 54
    for _, item in ipairs(word) do
        local label = Instance.new("TextLabel")
        label.Position = UDim2.new(0, cursor, 0, LETTER_Y + 34)  -- ниже: буква падает на место (LETTER_Y)
        label.Size = UDim2.fromOffset(item[2], 54)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBlack
        label.TextSize = 46
        label.Text = item[1]
        label.TextColor3 = M.Style.Text
        label.TextTransparency = 1
        label.Parent = content
        table.insert(letters, label)
        cursor = cursor + item[2]
    end

    local divider = Instance.new("Frame")
    divider.AnchorPoint = Vector2.new(0.5, 0)
    divider.Position = UDim2.new(0.5, 0, 0, 116)
    divider.Size = UDim2.fromOffset(140, 2)
    divider.BorderSizePixel = 0
    local dividerFade = Instance.new("UIGradient", divider)
    dividerFade.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1)
    })
    divider.Parent = content
    M.Style.Bind(divider, "BackgroundColor3")

    -- ---------------- Прогресс ----------------
    local trackHost = Instance.new("Frame")
    trackHost.AnchorPoint = Vector2.new(0.5, 0)
    trackHost.Position = UDim2.new(0.5, 0, 0, 146)
    trackHost.Size = UDim2.fromOffset(400, 8)
    trackHost.BackgroundTransparency = 1
    trackHost.BorderSizePixel = 0
    trackHost.Parent = content
    local trackGlow = M.Style.Glow(trackHost, 12, M.Style.SurfaceGlow * 1.5, M.State.Accent, UDim.new(0, 8), 1)

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 1, 0)
    track.BackgroundColor3 = M.Style.Raised
    track.BackgroundTransparency = 0.15
    track.BorderSizePixel = 0
    track.ClipsDescendants = true
    round(track, UDim.new(1, 0))
    track.Parent = trackHost

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 0, 1, 0)
    bar.BorderSizePixel = 0
    bar.ClipsDescendants = true
    round(bar, UDim.new(1, 0))
    local barGrad = Instance.new("UIGradient", bar)
    barGrad.Color = ColorSequence.new(Color3.fromRGB(150, 150, 168), WHITE)
    bar.Parent = track
    M.Style.Bind(bar, "BackgroundColor3")

    -- блик, бегущий по заполненной части полосы
    local shine = Instance.new("Frame")
    shine.Size = UDim2.new(0, 70, 1, 0)
    shine.Position = UDim2.new(0, -70, 0, 0)
    shine.BackgroundColor3 = WHITE
    shine.BorderSizePixel = 0
    local shineGrad = Instance.new("UIGradient", shine)
    shineGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1)
    })
    shine.Parent = bar
    local shineTween = M.Services.T:Create(shine, TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
        {Position = UDim2.new(1, 0, 0, 0)})
    shineTween:Play()

    -- «Голова» полосы
    local head = Instance.new("Frame")
    head.AnchorPoint = Vector2.new(0.5, 0.5)
    head.Position = UDim2.new(0, 0, 0.5, 0)
    head.Size = UDim2.fromOffset(14, 14)
    head.BackgroundColor3 = WHITE
    head.BorderSizePixel = 0
    head.ZIndex = 3
    round(head, UDim.new(1, 0))
    head.Parent = trackHost
    M.Style.AccentGlow(head, 11, 0.8, UDim.new(1, 0), 2)
    local headScale = Instance.new("UIScale", head)
    loop(headScale, 0.8, {Scale = 1.25}, Enum.EasingStyle.Sine, true)

    local status = Instance.new("TextLabel")
    status.Position = UDim2.new(0, 50, 0, 168)
    status.Size = UDim2.new(1, -150, 0, 18)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.GothamMedium
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextColor3 = M.Style.TextDim
    status.Text = ""
    status.Parent = content
    local percent = Instance.new("TextLabel")
    percent.AnchorPoint = Vector2.new(1, 0)
    percent.Position = UDim2.new(1, -50, 0, 168)
    percent.Size = UDim2.fromOffset(70, 18)
    percent.BackgroundTransparency = 1
    percent.Font = Enum.Font.GothamBold
    percent.TextSize = 12
    percent.TextXAlignment = Enum.TextXAlignment.Right
    percent.TextColor3 = M.Style.Text
    percent.Text = "0%"
    percent.Parent = content

    -- цвета сцены из темы
    local function applyTheme()
        for _, p in ipairs(particles) do p.Obj.BackgroundColor3 = tintOf(0):Lerp(WHITE, p.Mix) end
        rimGrad.Color = ColorSequence.new(M.Style.AccentMix(0.45), M.Style.Stroke)
        cardGlow.SetColor(M.State.Accent)
        trackGlow.SetColor(M.State.Accent)
    end
    applyTheme()

    -- покадровое
    local startedAt = os.clock()
    local sceneConn
    sceneConn = M.Services.R.RenderStepped:Connect(function(dt)
        if not introGui.Parent or M.Run.IsShutDown then
            sceneConn:Disconnect()
            return
        end
        pcall(function()
            local now = os.clock() - startedAt
            for _, p in ipairs(particles) do
                p.Y = p.Y - p.Speed * dt
                if p.Y < -0.03 then
                    p.Y = 1.03
                    p.X = math.random()
                end
                p.Obj.Position = UDim2.fromScale(p.X + math.sin(now * p.Freq + p.Phase) * p.Amp, p.Y)
            end
        end)
    end)

    local function finish()
        if sceneConn then sceneConn:Disconnect() end
        pcall(function() shineTween:Cancel() end)
        pcall(function() rimSpin:Cancel() end)
        M.F.FadeFinish("Intro")
        pcall(function() introBlur:Destroy() end)
        M.Data.FxIntroBlur = nil
        introGui:Destroy()
    end

    M.F.FadePrepare("Intro", {scene}, 0)
    tween(backdrop, 1.2, {BackgroundTransparency = 0.04})
    tween(introBlur, 1.6, {Size = 8})
    pause(0.35)
    M.F.FadeTo("Intro", 1, 1.0 * M.Style.Scale(), function() M.F.FadeFinish("Intro") end)
    tween(cardScale, 1.1, {Scale = 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    pause(0.8)

    -- буквы падают на место с пружинным отскоком
    for _, label in ipairs(letters) do
        tween(label, 0.5, {TextTransparency = 0}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        tween(label, 0.75, {Position = UDim2.new(0, label.Position.X.Offset, 0, LETTER_Y)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        pause(0.07)
    end

    -- волна по буквам, пока идёт загрузка
    local loading = true
    task.spawn(function()
        pause(0.6)
        while loading and not M.Run.IsShutDown and introGui.Parent do
            for _, label in ipairs(letters) do
                if not loading or not label.Parent then break end
                tween(label, 0.22, {TextColor3 = M.Style.AccentMix(0.35), Position = UDim2.new(0, label.Position.X.Offset, 0, LETTER_Y - 9)},
                    Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                task.delay(0.24, function()
                    if label.Parent then
                        tween(label, 0.5, {TextColor3 = M.Style.Text, Position = UDim2.new(0, label.Position.X.Offset, 0, LETTER_Y)},
                            Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                    end
                end)
                pause(0.075)
            end
            pause(1.1)
        end
    end)

    -- настоящие шаги запуска
    local shown = 0
    local function setProgress(target, stepKey)
        status.Text = M.Translate(stepKey)
        local duration = 0.8 * M.Style.Scale()
        tween(bar, duration, {Size = UDim2.new(target / 100, 0, 1, 0)}, nil, nil, true)
        tween(head, duration, {Position = UDim2.new(target / 100, 0, 0.5, 0)}, nil, nil, true)
        local from = shown
        local started = os.clock()
        while os.clock() - started < duration and not M.Run.IsShutDown do
            local alpha = ease(math.clamp((os.clock() - started) / duration, 0, 1))
            percent.Text = string.format("%d%%", math.floor(from + (target - from) * alpha + 0.5))
            task.wait(0.03)
        end
        shown = target
        percent.Text = string.format("%d%%", target)
    end

    -- каждый шаг в своей защите: сбой одного не обрывает заставку
    local function step(name, fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then M.Errors.Hit("Intro " .. name, err) end
    end

    pause(0.3)
    if M.Run.IsShutDown then loading = false return end
    step("progress1", setProgress, 20, "Intro_Step1")
    step("autoload", M.CFG.CheckAutoload)
    -- лёгкая оптимизация включается сама, если конфиг её не выключил
    step("optimization", M.F.RefreshOptimization)
    step("theme", applyTheme)
    pause(0.2)
    if M.Run.IsShutDown then loading = false return end
    step("progress2", setProgress, 45, "Intro_Step2")
    step("panels", M.F.RestyleAllPanels)
    step("glass", M.F.ApplyGlass)
    pause(0.2)
    step("progress3", setProgress, 70, "Intro_Step3")
    pause(0.2)
    if M.Run.IsShutDown then loading = false return end
    step("progress4", setProgress, 90, "Intro_Step4")
    step("environment", M.F.GuardEnvironment)
    pause(0.2)
    step("progress5", setProgress, 100, "Intro_Step5")
    loading = false
    step("done", function()
        tween(bar, 0.5, {BackgroundColor3 = M.Style.Success})
        trackGlow.SetColor(M.Style.Success, 0.5)
    end)

    pause(0.35)

    for _, label in ipairs(letters) do
        tween(label, 0.25, {TextColor3 = WHITE, Position = UDim2.new(0, label.Position.X.Offset, 0, LETTER_Y)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end
    local wave = Instance.new("Frame")
    wave.AnchorPoint = Vector2.new(0.5, 0.5)
    wave.Position = UDim2.new(0.5, 0, 0.5, 0)
    wave.Size = UDim2.fromOffset(260, 260)
    wave.BackgroundTransparency = 1
    wave.BorderSizePixel = 0
    round(wave, UDim.new(0.5, 0))
    local waveStroke = Instance.new("UIStroke")
    waveStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    waveStroke.Thickness = 3
    waveStroke.Color = M.Style.AccentMix(0.4)
    waveStroke.Transparency = 0.15
    waveStroke.Parent = wave
    wave.Parent = backdrop
    tween(wave, 1.1, {Size = UDim2.fromOffset(1500, 1500)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    tween(waveStroke, 1.1, {Transparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pause(0.3)

    local fade = 1.1 * M.Style.Scale()
    M.F.FadeFinish("Intro")
    M.F.FadePrepare("Intro", {scene}, 1)
    M.F.FadeTo("Intro", 0, fade)
    tween(cardScale, fade, {Scale = 1.08}, nil, nil, true)  -- fade уже умножен на множитель скорости
    tween(introBlur, fade, {Size = 0}, nil, nil, true)
    local done = tween(backdrop, fade, {BackgroundTransparency = 1}, nil, nil, true)
    pause(fade * 0.5)
    M.F.RevealGuis()
    if not M.Run.IsShutDown then M.F.OpenMenu() end
    done.Completed:Wait()

    finish()
    -- интро больше не понадобится
    M.F.RunIntro = nil
end

-- завершение заставки
function M.F.RevealGuis()
    M.Data.IntroActive = false
    for _, gui in ipairs(M.Data.GatedGuis) do
        if gui.Parent and gui ~= M.UI.LowHpGui then gui.Enabled = true end
    end
    table.clear(M.Data.GatedGuis)
end

function M.F.FinishIntro(introOk)
    M.F.RevealGuis()
    if M.Data.FxIntroBlur then
        pcall(function() M.Data.FxIntroBlur:Destroy() end)
        M.Data.FxIntroBlur = nil
    end
    local intro = M.Data.IntroGui
    M.Data.IntroGui = nil
    if intro and intro.Parent then intro:Destroy() end
    M.F.FadeFinishAll()
    -- если заставка упала, меню открываем здесь
    if not introOk and not M.Run.IsShutDown and M.UI.Main and not M.UI.Main.Visible then M.F.OpenMenu() end
end

do
    local runIntro = M.F.RunIntro
    task.spawn(function()
        local ok, err = pcall(runIntro)
        if not ok then M.Errors.Hit("Splash", err) end
        M.F.FinishIntro(ok)
    end)
end
do
    local okEnv, env = pcall(function() return getgenv and getgenv() or nil end)
    if okEnv and type(env) == "table" then
        local hook = function() if M.F.ShutDown then M.F.ShutDown() end end
        M.Data.ShutdownHook = hook
        env.__MatsysenseShutdown = hook
    end
end

end}

local function Boot()
    local M = {}
    Current = M
    local shared = {}
    for _, mod in ipairs(MODULES) do
        local ok, result = pcall(mod[2], M, shared)
        if not ok then error("[модуль " .. mod[1] .. "] " .. tostring(result), 0) end
        -- false = остановились сами (например, нет gethui)
        if result == false then return end
    end
end -- Boot

-- убирает за неудавшейся попыткой запуска
local function Teardown(M)
    if not M then return end
    pcall(function() if M.State then M.Run.IsShutDown = true end end)
    if M.F and M.F.ShutDown then
        if pcall(M.F.ShutDown) then return end
    end
    pcall(function() if M.Draw then M.Draw.RemoveAll() end end)
    pcall(function()
        local runService = game:GetService("RunService")
        for _, name in ipairs({"ShakeUndo", "TPRestore", "CamProcessor", "FovProcessor", "PlayerViewFrame", "ArrowsFrame", "AimMarkerFrame", "MatsysenseCull"}) do
            pcall(function() runService:UnbindFromRenderStep(name) end)
        end
    end)
    pcall(function()
        if M.Data and M.Data.Conns then
            for _, conn in pairs(M.Data.Conns) do pcall(function() conn:Disconnect() end) end
        end
    end)
    pcall(function()
        if M.UI then
            for _, item in pairs(M.UI) do
                if typeof(item) == "Instance" and (item:IsA("ScreenGui") or item:IsA("Folder")) then
                    pcall(function() item:Destroy() end)
                end
            end
        end
    end)
end

do
    local lastError
    for attempt = 1, 3 do
        local ok, err = xpcall(Boot, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
        if ok then break end
        lastError = err
        Teardown(Current)
        Current = nil
        pcall(function() getgenv().__MatsysenseLastError = lastError end)
        if attempt < 3 then task.wait(1.5 * attempt) end
    end
end

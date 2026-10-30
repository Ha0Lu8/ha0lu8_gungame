Config = {}

--基本設定
--LBPhoneのリソース名
Config.PhoneResource = "lb-phone"

Config.Debug = false

--デバッグソロ開始モード
Config.DebugSolo = false

--アプリ情報（LB Phone に登録される内容）
Config.App = {
    identifier  = "gungame",--一意の識別子
    name        = "GUN GAME",-- 表示名
    description = "1v1〜3v3 / FFA の撃ち合いマッチング",-- 説明
    developer   = "ha0lu8",-- 開発者
    defaultApp  = true,-- DLなしで初期から追加するか
    price       = 0,-- DL価格（defaultApp=true の場合は無関係）
    --アプリアイコン、自リソース内ui/icon.pngを参照
    icon        = "https://cfx-nui-" .. GetCurrentResourceName() .. "/ui/icon.png",
    ui          = GetCurrentResourceName() .. "/ui/index.html",
}

--モード定義
Config.Modes = {
    ["1v1"]    = { label = "1v1", teamSize = 1, teams = 2, ffa = false },
    ["2v2"]    = { label = "2v2", teamSize = 2, teams = 2, ffa = false },
    ["3v3"]    = { label = "3v3", teamSize = 3, teams = 2, ffa = false },
    --カスタム：味方陣営/敵陣営の人数を作成時に自由設定
    ["custom"] = { label = "カスタム", teamSize = nil, teams = 2, ffa = false, custom = true },
    ["ffa"]    = { label = "FFA", teamSize = nil, teams = nil, ffa = true },
}

--モードの表示順（UI用）
Config.ModeOrder = { "1v1", "2v2", "3v3", "custom", "ffa" }

--カスタムモードの陣営人数の範囲（作成時に各陣営へ設定できる人数）
--Config.Arenas の各チームスポーン数を超える人数を許可すると
--スポーン地点が循環して重なる点に注意（スポーンを増やすと安心
Config.Custom = {
    minPerTeam = 1,
    maxPerTeam = 4,
}

--勝敗条件の上限・既定値
Config.WinConditions = {
    --ラウンド制：先取本数
    rounds = {
        min = 1,
        max = 9,   --設定できる最大の先取本数
        default = 3,
    },
    kills = {
        min = 1,
        max = 50,  --設定できる最大キル数
        default = 10,
    },
}

--FFAの最大参加人数
Config.FFA = {
    maxPlayers = 8,     -- FFAに参加できる最大人数
    minPlayers = 2,     -- FFA成立に必要な最低人数
}

-- 制限時間（秒）。0で無制限
Config.TimeLimit = {
    perRound = 180, --ラウンド制：1ラウンドあたりの制限時間
    killRace = 600, --規定キル数先取：全体の制限時間
    ffa      = 600, --FFA：全体の制限時間
}

-- リスポーン
Config.RespawnDelay = 3 --規定キル数先取/FFAで死亡後に復活するまでの秒数

-- ベット
Config.Betting = {
    enabled  = true, --ベット機能を使うか
    account  = "bank", --支払い元（QBCore"cash"or"bank"）
    min      = 0,--最低ベット額（0でベットなしの募集も可）
    max      = 1000000,--最高ベット額
    -- 手数料は使用しない
}

--XP/レベル
Config.XP = {
    perKill = 10,--1キルごとの獲得XP
    perWin  = 100,--勝利時の獲得XP
    perLoss = 25,--敗北時の獲得XP
    perDraw = 50,--引き分け時の獲得XP
}

Config.Level = {
    xpPerLevel = 1000, --1レベルアップに必要なXP（累計totalXp/xpPerLevel+1=レベル）
    maxLevel   = 999, --レベル上限
}

--ランキング（週次）
Config.Ranking = {
    topCount = 50,  -- 各ランキングで表示する上位件数
    --リセットタイミング（サーバーのローカル時刻基準）
    --weekday: 1=月 2=火 3=水 4=木 5=金 6=土 7=日
    reset = {
        weekday = 1,  --既定:月曜
        hour    = 0,  --0時
        minute  = 0,
    },
}

--アカウント登録
Config.Account = {
    nameMinLen = 2,
    nameMaxLen = 16,
    idMinLen   = 3,
    idMaxLen   = 16,
    -- アカウントID に使える文字（英数字とアンダースコア）
    idPattern  = "^[%w_]+$",
}

--フレンド/パーティー
Config.Social = {
    maxFriends      = 100,  -- フレンド上限
    partyMaxSize    = 3,    -- パーティー最大人数（最大チーム人数に合わせる）
    inviteTimeout   = 60,   -- パーティー招待の有効秒数
}

--アリーナ（試合会場）
--各マッチは Routing Bucket で隔離されるため、座標は共有してよい。
--spawns:チームごとのスポーン地点。ffaSpawns:FFA用スポーン地点。
--座標は仮の値。実際のマップに合わせて書き換えて
Config.Arenas = {
   {
        name = "ROOF",
        --試合エリアの中心と半径。半径外に出るとダメージ
        center = vec3(102.7784, -871.9827, 130.9539),
        radius = 30.0,
        --teams[1] = チームA のスポーン候補、teams[2] = チームB のスポーン候補
        teams = {
            [1] = {
                vec4(118.1300, -879.7460, 134.7701, 58.1218),
                vec4(119.2459, -876.4079, 134.7701, 90.9590),
                vec4(121.3754, -880.6761, 134.7701, 95.0075),
                vec4(122.8576, -877.2685, 134.7701, 17.6068),
            },
            [2] = {
                vec4(85.1970, -863.9915, 134.7700, 248.3550),
                vec4(84.0027, -867.9431, 134.7701, 215.6710),
                vec4(82.8438, -863.1938, 134.7702, 249.3238),
                vec4(81.7365, -867.1772, 134.7702, 241.9983),
            },
        },
        --FFA用スポーン（最大Config.FFA.maxPlayers個以上を推奨）
        ffaSpawns = {
            vec4(101.8399, -861.6406, 134.7702, 266.6455),
            vec4(124.1812, -869.6710, 134.7701, 222.5831),
            vec4(128.6460, -872.3497, 134.7701, 124.0836),
            vec4(118.2645, -878.4205, 134.7702, 225.5171),
            vec4(106.6020, -884.9815, 134.7702, 56.6355),
            vec4(89.8974, -877.6342, 134.7702, 57.6645),
            vec4(82.8312, -868.4634, 134.7701, 334.8658),
            vec4(82.8490, -853.4512, 134.7701, 249.4314),
        },
    },
    {
        name = "722農場",
        center = vec3(1442.9126, 1112.8044, 100.3306),
        radius = 110.0,
        teams = {
            [1] = {
                vec4(1461.6443, 1179.5099, 114.2090, 177.1094),
                vec4(1457.3391, 1178.8662, 114.2403, 178.6468),
                vec4(1452.9165, 1178.4673, 114.2552, 175.4547),
                vec4(1448.5338, 1179.3529, 114.2078, 178.0630),
            },
            [2] = {
                vec4(1465.0217, 1035.9126, 114.1275, 357.7531),
                vec4(1469.1327, 1035.8865, 114.1714, 1.3553),
                vec4(1473.2281, 1035.7526, 114.1968, 358.1882),
                vec4(1477.4033, 1035.5321, 114.2056, 357.2177),
            },
        },
        ffaSpawns = {
            vec4(1497.2510, 1130.2078, 114.3343, 96.2430),
            vec4(1490.5388, 1100.9985, 114.3344, 105.0950),
            vec4(1476.1160, 1037.2590, 114.1560, 61.0579),
            vec4(1470.2515, 1081.3324, 114.3343, 52.9089),
            vec4(1437.3508, 1135.4972, 114.4957, 280.3184),
            vec4(1454.5104, 1148.6840, 114.3343, 179.3938),
            vec4(1455.7771, 1187.0316, 114.2076, 178.1922),
            vec4(1466.8906, 1134.7660, 114.3227, 96.5257),
        },
    },
    {
        name = "RAMP",
        center = vec3(-922.0653, -757.2676, 14.8071),
        radius = 90.0,
        teams = {
            [1] = {
                vec4(-932.4537, -782.3680, 15.9211, 123.8159),
                vec4(-934.4558, -780.6283, 15.9212, 139.5933),
                vec4(-931.6337, -780.3464, 15.9212, 153.5048),
                vec4(-933.4718, -778.7545, 15.9212, 119.5774),
            },
            [2] = {
                vec4(-949.6982, -801.1915, 15.9211, 324.4662),
                vec4(-947.7396, -802.7313, 15.9211, 319.5208),
                vec4(-950.8102, -802.9337, 15.9211, 321.1804),
                vec4(-948.9200, -804.5334, 15.9212, 318.8057),
            },
        },
        ffaSpawns = {
            vec4(-957.2469, -712.8438, 19.9418, 223.4729),
            vec4(-882.7817, -781.4149, 16.1227, 37.5170),
            vec4(-947.1705, -800.5259, 15.9211, 50.7350),
            vec4(-961.9340, -779.7823, 16.0306, 273.5395),
            vec4(-883.3396, -687.0219, 25.6143, 153.0375),
            vec4(-934.5983, -746.4438, 19.8704, 226.3581),
            vec4(-933.7031, -782.4706, 15.9702, 220.7881),
            vec4(-921.2470, -687.9781, 26.3515, 205.1594),
        },
    },
    {
        name = "山小屋",
        center = vec3(-682.8464, 5794.6353, 15.3704),
        radius = 90.0,
        teams = {
            [1] = {
                vec4(-667.9852, 5838.4092, 17.3313, 133.5993),
                vec4(-669.2082, 5839.7466, 17.3313, 136.1570),
                vec4(-671.1271, 5841.7700, 17.3313, 129.3245),
                vec4(-673.6527, 5844.4941, 17.3313, 105.8231),
            },
            [2] = {
                vec4(-708.3336, 5755.5649, 17.8030, 329.1458),
                vec4(-703.5886, 5754.4683, 17.6568, 327.9625),
                vec4(-700.3764, 5752.8945, 17.7607, 338.0053),
                vec4(-696.0054, 5750.1938, 17.8145, 312.7903),
            },
        },
        ffaSpawns = {
            vec4(-698.2405, 5802.0161, 17.3309, 43.0477),
            vec4(-683.5469, 5798.2363, 17.3221, 243.1527),
            vec4(-679.0766, 5817.4009, 17.3248, 6.0541),
            vec4(-671.6995, 5841.1401, 17.3313, 294.4464),
            vec4(-698.5088, 5783.8306, 17.4682, 114.5526),
            vec4(-707.5822, 5755.4248, 17.7702, 115.2125),
            vec4(-674.8604, 5760.7593, 17.8624, 327.8756),
            vec4(-683.2581, 5843.9526, 17.2423, 239.7980),
        },
    },
    {
        name = "モーテル",
        center = vec3(336.5156, -2042.9692, 16.2458),
        radius = 90.0,
        teams = {
            [1] = {
                vec4(283.5937, -2083.9524, 16.8387, 326.8540),
                vec4(284.7513, -2086.5898, 16.8667, 277.5125),
                vec4(285.8889, -2090.2881, 16.8508, 276.5138),
                vec4(283.9164, -2093.8328, 16.6101, 276.0830),
            },
            [2] = {
                vec4(381.5725, -1981.2850, 24.3409, 153.6881),
                vec4(378.1694, -1979.8816, 24.1084, 161.3623),
                vec4(372.7760, -1977.6154, 24.1221, 158.9357),
                vec4(369.3792, -1975.5737, 24.2219, 158.4243),
            },
        },
        ffaSpawns = {
            vec4(383.8681, -1986.3602, 24.2639, 158.3232),
            vec4(284.9086, -2088.1665, 16.8383, 270.3546),
            vec4(277.2900, -2040.8475, 18.4163, 270.8255),
            vec4(400.3262, -2036.2820, 22.8457, 56.9997),
            vec4(366.4226, -2007.1913, 23.3702, 118.1015),
            vec4(346.2625, -2033.7557, 22.0828, 193.5243),
            vec4(327.9448, -2112.7224, 17.8699, 306.5674),
            vec4(331.1366, -1977.7009, 23.9560, 306.5726),
        },
    },
}

--Routing Bucketの割当開始番号（他リソースと衝突しない番号にする）
Config.BucketStart = 50000

--試合会場（バケット）のアンビエント湧きを無効化するか
--true: アリーナに通行人(NPC)・走行車が湧かなくなる（推奨）
--false: 通常どおり湧く
Config.DisableArenaPopulation = true

--試合エリアの境界（ゾーン）
--試合中、アリーナ中心(center)から半径(radius)の円を半透明で表示し
--円の外に出ると一定間隔で小ダメージを与える（戻るよう警告も表示）
--中心・半径は各アリーナの center / radius で指定（無指定なら defaultRadius）
Config.Zone = {
    enabled       = true,
    defaultRadius = 300.0, --アリーナにradius未指定時の既定半径(m)
    damage        = 5,      --範囲外でtickごとに与えるダメージ
    tickMs        = 1000,   --ダメージ間隔(ms)
    drawDistance  = 80.0,    --縦の壁を描画するプレイヤーからの距離(負荷軽減)
    color         = { r = 255, g = 60, b = 60, a = 90 }, --境界の色
    floorAlpha    = 75,      --エリア円の不透明度（薄め推奨。0で非表示）
    height        = 50.0,   --エリア円の高さ(m)。大きいほど柱/壁のように高くなる（平らにするなら2.0等）
}

-- 試合開始時の体力・アーマー
Config.Combat = {
    startHealth = 200,   --開始時の体力（FiveM: 100=死、200=満タン
    startArmor  = 100,   --開始時のアーマー
    countdown   = 10,    --試合開始前のカウントダウン秒数
    roundCountdown = 3,  --ラウンド制：次ラウンド開始前のカウントダウン秒数
    --キル時の回復（FFA / キル先取のみ）。0 で回復なし
    --health:1キルごとに回復するHP（開始時の最大体力まで）
    --armor:1キルごとに回復するアーマー（アーマー有りの試合のみ・最大まで）
    killHeal = {
        health = 20,
        armor  = 0,
    },
}

-- 武器カテゴリ（募集作成時の武器選択 UI に使用）
--   1試合につき 1 つの武器を選択する想定。
Config.Weapons = {
    {
        key = "pistols", label = "Pistol",
        items = {
            { weapon = "weapon_pistol",       label = "Colt" },
            { weapon = "weapon_combatpistol", label = "Combat Pistol" },
            { weapon = "weapon_pistol50",     label = ".50 Cal Pistol" },
            { weapon = "weapon_appistol",     label = "AP Pistol" },
            { weapon = "weapon_heavypistol",  label = "Heavy Pistol" },
        },
    },
    {
        key = "smgs", label = "SMG",
        items = {
            { weapon = "weapon_microsmg",   label = "MICRO SMG" },
            { weapon = "weapon_smg",        label = "MP5" },
            { weapon = "weapon_assaultsmg", label = "Assault SMG" },
            { weapon = "weapon_combatpdw",  label = "Combat PDW" },
            { weapon = "weapon_tecpistol",  label = "Tactical SMG" },
            { weapon = "weapon_gusenberg",  label = "Thompson" },
            { weapon = "weapon_kvr",        label = "Vector" },
            { weapon = "weapon_hkump",      label = "UMP45" },
        },
    },
    {
        key = "shotguns", label = "SG",
        items = {
            { weapon = "weapon_pumpshotgun",   label = "Pump Shotgun" },
            { weapon = "weapon_combatshotgun", label = "Combat Shotgun" },
            { weapon = "weapon_heavyshotgun",  label = "Heavy Shotgun" },
        },
    },
    {
        key = "rifles", label = "AR",
        items = {
            { weapon = "weapon_assaultrifle",      label = "AK-47" },
            { weapon = "weapon_carbinerifle",      label = "PD M4" },
            { weapon = "weapon_specialcarbine",    label = "Special Carbine" },
            { weapon = "WEAPON_BULLPUPRIFLE_MK2",  label = "QBZ" },
            { weapon = "WEAPON_CARBINERIFLE_MK2",  label = "CARBINE" },
            { weapon = "weapon_compactrifle",      label = "Draco" },
            { weapon = "weapon_mk47banshee",       label = "MK47 Banshee" },
            { weapon = "WEAPON_M4A",               label = "M4A1" },
            { weapon = "WEAPON_HK416B",            label = "HK416" },
        },
    },
    {
        key = "snipers", label = "SR",
        items = {
            { weapon = "weapon_sniperrifle",   label = "Sniper Rifle" },
            { weapon = "weapon_marksmanrifle", label = "Marksman Rifle" },
            { weapon = "weapon_heavysniper",   label = "Heavy Sniper" },
            { weapon = "WEAPON_MUSKET",        label = "Musket" },
        },
    },
}

--付与する弾薬数（予備弾。リロード用にインベントリへ入る弾薬アイテムの数）
Config.WeaponAmmo = 1000

--アリーナ武器の「最初から装填しておく」クリップ弾数
--ox_inventory は武器付与時のクリップ弾数（metadata.ammo）が既定で 0 のため
--そのままだと開始時にリロードが必要になる。この値だけ装填済みにする
--予備弾は別途 Config.WeaponAmmo がインベントリに入る
Config.WeaponLoadedAmmo = 250

-- インベントリ切り替え（ox_inventory 連携）
--   試合開始時にプレイヤーの所持品を一時退避（DB stash へ保存）
--   アリーナ用ロードアウト（選択武器＋弾薬）に切り替え
--   試合終了/放棄/再接続/リソース停止時に元の所持品へ復元
--   ※ ox_inventory は所持品に無い武器を剥奪するため、直接 GiveWeaponToPed
--      しただけでは武器が即消える。そのため武器・弾薬を「アイテム」として
--      付与し、クライアントで useSlot により装備
Config.InventorySwap = {
    enabled  = true,            -- インベントリ切り替えを使うか（ox_inventory 必須）
    resource = "ox_inventory",  -- 使用するインベントリリソース名
    --テレポート前後にインベントリを開けなくする秒数（アイテム複製防止）
    --この間は ox_inventory を強制的に閉じ、開く操作もブロック
    lockSeconds = 3,
    --アリーナ中も追加で所持させるアイテム（スマホ・ラジオなど）
    --※ lb-phone は電話アイテム("phone")が無いと電話を使えなくなるため
    --試合中もスマホを使えるよう必ず再付与
    extraItems = {
        { name = "phone", count = 1 },
        { name = "radio", count = 1 },
    },
    --スマホアイテムのアイテム名（lb-phone の電話アイテム）
    --試合会場へテレポートした際、このアイテムだけ少し遅れて戻すことで
    --lb-phone に「スマホが一時的に無くなった」と判定させ、自動でスマホを
    --閉じさせる（lb-phone は電話アイテムが約2秒無いと自動で閉じる挙動）
    phoneItem = "phone",
    --スマホアイテムを戻すまでの遅延（秒）。lb-phone の自動クローズ判定（約2秒）
    --より少し長くする。0 にすると遅延なし＝スマホを閉じない（即時付与）
    phoneCloseDelay = 3.0,
}

--武器ハッシュ名→ox_inventoryの弾薬アイテム名
--ox_inventory/data/weapons.luaのammonameに準拠。
Config.WeaponAmmoItem = {
    --ハンドガン
    weapon_pistol       = "ammo-9",
    weapon_combatpistol = "ammo-9",
    weapon_pistol50     = "ammo-9",
    weapon_appistol     = "ammo-9",
    weapon_heavypistol  = "ammo-9",
    --SMG
    weapon_microsmg     = "ammo-45",
    weapon_smg          = "ammo-45",
    weapon_assaultsmg   = "ammo-45",
    weapon_combatpdw    = "ammo-9",
    weapon_tecpistol    = "ammo-45",
    weapon_gusenberg    = "ammo-45",
    weapon_kvr          = "ammo-45",
    weapon_hkump        = "ammo-45",
    --ショットガン
    weapon_pumpshotgun   = "ammo-shotgun",
    weapon_combatshotgun = "ammo-shotgun",
    weapon_heavyshotgun  = "ammo-shotgun",
    --アサルトライフル
    weapon_assaultrifle      = "ammo-rifle",
    weapon_carbinerifle      = "ammo-rifle",
    weapon_specialcarbine    = "ammo-rifle",
    weapon_carbinerifle_mk2  = "ammo-rifle",
    weapon_bullpuprifle_mk2  = "ammo-rifle",
    weapon_compactrifle      = "ammo-rifle",
    weapon_mk47banshee       = "ammo-rifle",
    weapon_m4a               = "ammo-rifle",
    weapon_hk416b            = "ammo-rifle",
    --スナイパー
    weapon_sniperrifle   = "ammo-sniper",
    weapon_marksmanrifle = "ammo-sniper",
    weapon_heavysniper   = "ammo-heavysniper",
}

--マッチ成立→試合会場へのテレポート猶予（秒）
--マッチが成立した瞬間に飛ばされると驚くため、スマホ通知を出してから
--この秒数だけ待ってテレポートする。0 で即時。
Config.MatchStartDelay = 10

--試合放棄の猶予（秒）
--放棄ボタンを押した瞬間に退出せず、この秒数だけ待ってから放棄する。
--0 で即時。
Config.ForfeitDelay = 3

--試合結果（WIN / LOSE / DRAW）の表示時間（秒）
--勝敗が決まると試合会場でこの秒数だけ結果を画面表示し、効果音を鳴らし、
--その後に元いた場所へテレポートで戻す。
Config.ResultDisplay = {
    duration = 5,   -- 結果を表示してから元の場所へ戻るまでの秒数
}

--試合中の分身（スタンドイン）＆帰還時の事故防止
--試合会場へテレポートしている間、元の場所（通常世界=バケット0）に
--半透明の分身pedを立たせて待機エモートをさせる。場所が「占有」されるため
--他プレイヤーや車がよけやすくなり、帰還時の事故を減らせる。
--さらに帰還直後の数秒間はプレイヤーを無敵＋衝突/ラグドール保護する
Config.StandIn = {
    enabled  = true,
    --分身のモデル。nil でプレイヤー本人のモデルを使用（※服装までは複製されません）
    model    = nil,
    --待機エモート（GTAのシナリオ名）。anim が設定されている場合はそちらを優先
    scenario = "WORLD_HUMAN_STAND_MOBILE",
    --待機アニメーション（rpemotes の "sms5" 相当：スマホをいじる）
    --設定すると scenario より優先される。nil にすると scenario を使用
    anim = {
        dict        = "amb@code_human_wander_texting_fat@male@base",
        name        = "static",
        flag        = 1,            -- ループ
        prop        = "prop_phone_ing",  -- 手に持つスマホprop
        bone        = 28422,         -- 右手ボーン
        placement   = { x = -0.02, y = -0.01, z = 0.0, rx = 2.309, ry = 88.845, rz = 29.979 },
        propTexture = 0,          --スマホの色（0=青,1=緑,2=暗赤,3=橙,4=灰,5=紫,6=桃,7=黒）
    },
    alpha    = 150,   --半透明度
    --接地高さの微調整(m)。地面にスナップした後、この値だけ上下させる
    --埋まる→値を大きく(+0.1ずつ)、浮く→値を小さく(マイナス)して調整
    zOffset  = 1.0,
    --帰還後にプレイヤーを保護する秒数（無敵＋車に押されない）。0で無効
    returnProtect = 4,
    --分身の頭上ネームタグ（プレイヤー同様の表示）
    --1行目状態テキスト（例「ガンゲーム中」／2行目:ID＋名前
    nameTag = {
        enabled      = true,
        line1        = "ガンゲーム中",   --上段の固定テキスト
        drawDistance = 40.0,    --描画する最大距離(m)
        height       = 1.1,        --ped頭上からの高さ(m)
        textSize     = 0.40,      --文字サイズ
        lineGap      = 0.022,     --1段目と2段目の行間（画面比。小さいほど密着）
        line1Color   = { r = 255, g = 210, b = 60 },  --上段の色（黄）
        line2Color   = { r = 255, g = 255, b = 255 },  --下段の色（白）
    },
}

--死亡/救急システム連携
--wasabi_ambulance 等の死亡管理スクリプトがあると、プレイヤーの死亡を
--横取りして独自のダウン/死亡状態を維持するため、gungame 側の
--NetworkResurrectLocalPlayer だけでは蘇生できない。
--ラウンド開始/リスポーン/試合終了時に、このリソースの蘇生 export
--（RevivePlayer）を通じて確実に蘇生する。
Config.Ambulance = {
    -- 死亡管理リソース名。空文字 "" にすると連携無効（QB互換イベントのみ使用）
    resource = "wasabi_ambulance",
}

--ラジオ自動接続（pma-voice 連携）
--チーム戦のとき、味方を同じラジオ周波数に自動接続し、敵チームとは
--別の周波数に分ける。さらに試合ごとに固有の周波数を割り当てるため、
--他のマッチや街中の通常ラジオと混ざることはない。
--mm_radio は内部で pma-voice を使用しているため、pma-voiceの
--サーバーエクスポート setPlayerRadio で直接制御する。
Config.Radio = {
    enabled  = true,      --ラジオ自動接続を使うか（pma-voice必須）
    resource = "pma-voice",    --ボイスリソース名
    --試合用の周波数ベース。街中の通常チャンネル（mm_radio:1〜500）と
    --衝突しないよう十分高い値にする。
    --チームA = channelBase+matchId*2、チームB=channelBase+matchId*2 + 1
    channelBase = 900000,
    teamOnly = true,    --チーム戦のみ自動接続（FFAは接続しない）
}

-- 効果音
--試合カウントダウン音はゲームのネイティブ音（PlaySoundFrontend）で
--再生する。電話を閉じていても確実に鳴る。
--アプリUI（ボタン/通知）の効果音は ui/app.js が Web Audio API で
--生成するため音声ファイルは不要。uiEnabled で切り替える。
--サウンド名/サウンドセットは GTA のネイティブ音。鳴らない場合は
--別のセット（例: "HUD_MINI_GAME_SOUNDSET"）に変更してください
Config.Sounds = {
    enabled   = true,   --試合カウントダウンのネイティブ音を鳴らすか
    uiEnabled = true,   --アプリUI（ボタン/通知）の効果音を鳴らすか
    --各音は { name = サウンド名, set = サウンドセット }
    --HUD_MINI_GAME_SOUNDSET は常時ロード済み（音源バンク不要）で確実に鳴る。
    --別の音にしたい場合は名前/セットを変更してください
    countdownBeep = { name = "CHECKPOINT_NORMAL",  set = "HUD_MINI_GAME_SOUNDSET" }, --残り3,2,1
    countdownGo   = { name = "CHECKPOINT_PERFECT", set = "HUD_MINI_GAME_SOUNDSET" }, --開始(GO)
    matchEnd      = { name = "TIMER_STOP",         set = "HUD_MINI_GAME_SOUNDSET" }, --試合終了（未使用：下の勝敗音を使用）
    -- 勝敗の結果音。鳴らない場合は name/set を別の GTA ネイティブ音に変更して
    matchWin      = { name = "Mission_Pass_Notify", set = "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS" }, --勝利
    matchLose     = { name = "ScreenFlash",         set = "WastedSounds" },           --敗北
    matchDraw     = { name = "TIMER_STOP",          set = "HUD_MINI_GAME_SOUNDSET" },    --引き分け
}

-- 通知メッセージ（簡易）
Config.Notify = {
    matchFound   = "マッチが成立しました！",
    matchStart   = "試合開始！",
    youWon       = "勝利！",
    youLost      = "敗北...",
    draw         = "引き分け（ベットは返金されました）",
    notEnoughMoney = "ベット額を支払う残高が足りません。",
}

--武器ハッシュ→ラベルを引くための逆引きを構築
Config.WeaponLabels = {}
--武器名 → カテゴリキー（pistols / smgs / rifles など）。アタッチメント付与に使う
Config.WeaponCategory = {}
for _, cat in ipairs(Config.Weapons) do
    for _, it in ipairs(cat.items) do
        Config.WeaponLabels[it.weapon] = it.label
        Config.WeaponCategory[it.weapon] = cat.key
    end
end

--アリーナ武器のアタッチメント（ox_inventory のキットアイテム）
--選んだ武器のカテゴリに応じて、これらを「アイテムとして手持ちに付与」する
--武器には自動装着しない。プレイヤーが ox_inventory で任意に装着する
--カテゴリキーは Config.Weapons の key と一致させること
--キットの無いカテゴリ（shotguns / snipers 等）は未定義＝付与なし
Config.WeaponAttachments = {
    pistols = {
        "pistol_kit_muzzle", "pistol_kit_flashlight", "pistol_kit_clip",
    },
    smgs = {
        "smg_kit_sight", "smg_kit_muzzle", "smg_kit_grip", "smg_kit_barrel",
        "smg_kit_stock", "smg_kit_flashlight", "smg_kit_clip",
        "smg_kit_handguard", "smg_kit_drum",
    },
    rifles = {
        "rifle_kit_sight", "rifle_kit_muzzle", "rifle_kit_grip", "rifle_kit_barrel",
        "rifle_kit_flashlight", "rifle_kit_clip", "rifle_kit_stock",
    },
}

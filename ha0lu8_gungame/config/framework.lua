
-- QBCore フレームワーク抽象化
--   将来 ESX 等へ移植しやすいよう、フレームワーク依存処理をここに集約。

Framework = {}

local QBCore = nil

-- Qbox(qbx_core) / qb-core のどちらでも Core オブジェクトを取得する。
--   このサーバーは Qbox 稼働。Qbox の qb-core 互換エクスポート
--   (exports['qb-core']:GetCoreObject) はブリッジ未ロード時に存在せず不安定なため、
--   Qbox のネイティブエクスポート（GetPlayer / GetQBPlayers / GetPlayerData）から
--   このスクリプトが必要とする最小限の互換 core を組み立てる。
--   ネイティブの player オブジェクトは PlayerData と Functions.AddMoney/RemoveMoney を
--   そのまま持つため、以降の Framework.* は変更なしで動作する。
--   コールバックは qb-core 互換オブジェクト（qbCoreCompat）内の独自ネットイベントで
--   動くため、自前 core では流用できない。Qbox がネイティブで使う ox_lib(lib.callback)
--   に載せ替え、呼び出し側（sv_main/cl_main）の qb 形式シグネチャは維持する。
--   ※ サーバー側の各コールバックは cb(...) を同期的に呼ぶ（DB は MySQL.await で同一
--     コルーチン内完結）ため、戻り値へ写し取る下記シムで正しく動作する。
local function buildQbxCore()
    if IsDuplicityVersion() then
        return {
            Functions = {
                GetPlayer = function(src) return exports.qbx_core:GetPlayer(src) end,
                GetPlayerByCitizenId = function(cid) return exports.qbx_core:GetPlayerByCitizenId(cid) end,
                GetPlayers = function()
                    local sources = {}
                    local players = exports.qbx_core:GetQBPlayers()
                    for k in pairs(players) do sources[#sources + 1] = k end
                    return sources
                end,
                -- qb 形式: CreateCallback(name, function(source, cb, ...))
                CreateCallback = function(name, fn)
                    lib.callback.register(name, function(src, ...)
                        local ret
                        fn(src, function(result) ret = result end, ...)
                        return ret
                    end)
                end,
            },
        }
    end
    return {
        Functions = {
            GetPlayerData = function() return exports.qbx_core:GetPlayerData() end,
            -- qb 形式: TriggerCallback(name, cb, ...)
            TriggerCallback = function(name, cb, ...)
                lib.callback(name, false, cb, ...)
            end,
        },
    }
end

local function resolveCore()
    -- 本物の qb-core（GetCoreObject を持つ）が稼働していればそれを使う
    if GetResourceState("qb-core") == "started" then
        local ok, core = pcall(function() return exports["qb-core"]:GetCoreObject() end)
        if ok and type(core) == "table" then return core end
    end
    -- Qbox ネイティブから互換 core を構築
    if GetResourceState("qbx_core") == "started" then
        return buildQbxCore()
    end
    return nil
end

CreateThread(function()
    QBCore = resolveCore()
end)

--共通ヘルパ
function Framework.GetCore()
    if not QBCore then
        QBCore = resolveCore()
    end
    return QBCore
end

if IsDuplicityVersion() then
    -- サーバー側

    -- source から citizenid を取得
    function Framework.GetCitizenId(source)
        local core = Framework.GetCore()
        local player = core.Functions.GetPlayer(source)
        if not player then return nil end
        return player.PlayerData.citizenid
    end

    -- source からプレイヤーのキャラクターネーム（firstname + lastname）を取得
    function Framework.GetCharName(source)
        local core = Framework.GetCore()
        local player = core.Functions.GetPlayer(source)
        if not player then return nil end
        local ci = player.PlayerData and player.PlayerData.charinfo
        if not ci then return nil end
        local name = ((ci.firstname or "") .. " " .. (ci.lastname or "")):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then return nil end
        return name
    end

    -- 残高取得（account: "cash" or "bank"）
    function Framework.GetMoney(source, account)
        local core = Framework.GetCore()
        local player = core.Functions.GetPlayer(source)
        if not player then return 0 end
        return player.PlayerData.money[account] or 0
    end

    -- 出金（成功で true）
    function Framework.RemoveMoney(source, account, amount, reason)
        local core = Framework.GetCore()
        local player = core.Functions.GetPlayer(source)
        if not player then return false end
        return player.Functions.RemoveMoney(account, amount, reason or "gungame-bet")
    end

    -- 入金
    function Framework.AddMoney(source, account, amount, reason)
        local core = Framework.GetCore()
        local player = core.Functions.GetPlayer(source)
        if not player then return false end
        return player.Functions.AddMoney(account, amount, reason or "gungame-payout")
    end

    -- citizenid から現在オンラインの source を取得（オフラインなら nil）
    function Framework.GetSourceByCitizenId(citizenid)
        local core = Framework.GetCore()
        local player = core.Functions.GetPlayerByCitizenId(citizenid)
        if not player then return nil end
        return player.PlayerData.source
    end

    -- オンラインの全プレイヤー source 一覧
    function Framework.GetPlayers()
        local core = Framework.GetCore()
        return core.Functions.GetPlayers()
    end

    --フレームワークの死亡/救急システムでプレイヤーを蘇生（死亡状態を解除）。
    --試合中の蘇生がフレームワーク側（wasabi_ambulance 等）に打ち消されるのを防ぐ。
    function Framework.Revive(source)
        if not source then return end
        local res = Config.Ambulance and Config.Ambulance.resource
        if res and res ~= "" and GetResourceState(res) == "started" then
            --wasabi_ambulance: exports:RevivePlayer(target)
            if pcall(function() exports[res]:RevivePlayer(source) end) then return end
        end
        --フォールバック（QB互換の蘇生イベント。wasabi も provides で受ける）
        pcall(function() TriggerClientEvent("hospital:client:Revive", source) end)
    end

    --位置保存の抑止（qbx_core 連携）
    --試合中は現在地（アリーナ）がDBに保存されないようにし、保存値を試合前の
    --座標のまま固定する。これによりクラッシュ→再接続時に qbx_spawn の
    --「最後の地点」が試合前の場所になり、アリーナで湧かなくなる。
    --qbx_core/server/player.lua の Save() が state.gungameNoSave を見て
    --現在地ではなく playerData.position を保存するように改変済み。
    function Framework.FreezeSavePosition(source, x, y, z, h)
        if GetResourceState("qbx_core") ~= "started" then return end
        pcall(function()
            Player(source).state:set("gungameNoSave", true, false)
            -- 保存される座標（playerData.position）を試合前の位置に固定
            exports.qbx_core:SetPlayerData(source, "position", vec4(x + 0.0, y + 0.0, z + 0.0, (h or 0.0) + 0.0))
        end)
    end

    function Framework.UnfreezeSavePosition(source)
        if GetResourceState("qbx_core") ~= "started" then return end
        pcall(function()
            Player(source).state:set("gungameNoSave", nil, false)
        end)
    end

    -- インベントリ切り替え（ox_inventory 連携）
    -- 連携が有効かつリソースが起動しているか
    function Framework.InvSwapReady()
        if not (Config.InventorySwap and Config.InventorySwap.enabled) then return false end
        local res = Config.InventorySwap.resource
        return res and GetResourceState(res) == "started"
    end

    -- プレイヤーの所持品を退避（DB stash へ保存し、手持ちを空に）
    function Framework.ConfiscateInventory(source)
        if not Framework.InvSwapReady() then return false end
        local ok = pcall(function()
            exports[Config.InventorySwap.resource]:ConfiscateInventory(source)
        end)
        return ok
    end

    --退避した所持品を復元する。
    --先に現在の在庫（アリーナ武器・弾薬・ラジオ・携帯など付与品）を完全クリアし、
    --その後に退避していた元の所持品を復元する。
    --ReturnInventory のクライアント更新は「元在庫のスロットのみ」反映するため、
    --元在庫が空/少ないとアリーナアイテムが入っていたスロットがクライアントに
    --残ってしまう。ClearInventory は全スロットの削除をクライアントへ同期するので、
    --先にクリアすることで残留・操作不能（サーバーに無いアイテム）を防ぐ。
    --戻り値で状態を返す（呼び出し側が再試行/フラグ解除を判断）：
    --"done"     … スタッシュを消費して復元完了
    --"no_stash" … 復元すべきスタッシュが無い（＝やることが無い／既に復元済み）
    --"pending"  … まだ復元できない（ox 未準備 / 在庫未ロード等）→ 後で再試行すべき
    local function stashExists(owner)
        if not (owner and MySQL) then return nil end
        local ok, row = pcall(function()
            return MySQL.scalar.await("SELECT 1 FROM ox_inventory WHERE name = ?", { tostring(owner) })
        end)
        if not ok then return nil end   -- DB 未準備など → 判定不能
        return row ~= nil
    end

    function Framework.RestoreInventory(source, owner)
        if not Framework.InvSwapReady() then return "pending" end
        local res = Config.InventorySwap.resource

        -- スタッシュ（退避した元在庫）の有無を確認。
        local has = stashExists(owner)
        if has == nil then return "pending" end   -- 判定不能（DB未準備）→ 再試行
        if has == false then return "no_stash" end -- 復元対象なし

        --スタッシュがある時だけ「全クリア→復元」する。
        --※ プレイヤー在庫が未ロード（Inventory(source)==nil）の場合、ox の
        --ClearInventory/ReturnInventory は何もせずスタッシュも残る。その時は
        --下の再確認で has==true のままなので "pending" を返し、後で再試行する。
        pcall(function()
            exports[res]:ClearInventory(source)   --アリーナ付与アイテムを全消去（クライアント表示含む）
            exports[res]:ReturnInventory(source)  --退避した元の所持品を復元（成功時スタッシュ削除）
        end)

        --スタッシュが消費（削除）されていれば復元成功
        local still = stashExists(owner)
        if still == false then return "done" end
        return "pending"
    end

    -- アリーナ用武器＋弾薬を付与し、武器が入ったスロット番号を返す
    --weaponName:"weapon_pistol" 形式（小文字）
    -- ammoItem:oxの弾薬アイテム名（nil なら弾薬を付与しない）
    --ammoCount:弾薬数
    function Framework.GiveArenaWeapon(source, weaponName, ammoItem, ammoCount)
        if not Framework.InvSwapReady() then return nil end
        local res = Config.InventorySwap.resource
        local item = string.upper(weaponName)
        local loaded = Config.WeaponLoadedAmmo or 0
        local weaponSlot = nil
        pcall(function()
            -- metadata.ammo にクリップ装填弾数を渡して「最初から装填済み」で付与する
            exports[res]:AddItem(source, item, 1, (loaded > 0) and { ammo = loaded } or nil)
            if ammoItem and ammoCount and ammoCount > 0 then
                exports[res]:AddItem(source, ammoItem, ammoCount)
            end
            -- AddItem の戻り値はスロットを含まないため、付与後にスロットIDを取得する
            local slot = exports[res]:GetSlotIdWithItem(source, item, nil, true)
            if type(slot) == "table" then
                weaponSlot = slot.slot or slot.id
            else
                weaponSlot = slot
            end
        end)
        return weaponSlot
    end

    --アリーナ武器のアタッチメント（キット）をアイテムとして付与する。
    --武器のカテゴリ（Config.WeaponCategory）に対応する Config.WeaponAttachments を
    --そのままインベントリに入れる。武器には装着しない（プレイヤーが任意で装着）。
    function Framework.GiveArenaAttachments(source, weaponName)
        if not Framework.InvSwapReady() then return end
        if not weaponName then return end
        local catKey = Config.WeaponCategory and Config.WeaponCategory[weaponName]
        local list = catKey and Config.WeaponAttachments and Config.WeaponAttachments[catKey]
        if not list then return end
        local res = Config.InventorySwap.resource
        pcall(function()
            for _, itemName in ipairs(list) do
                exports[res]:AddItem(source, itemName, 1)
            end
        end)
    end

    --アリーナ用の追加アイテム（スマホ・ラジオなど）を付与
    --skipItemName を指定すると、そのアイテムだけ付与しない（後で遅延付与する用途）。
    function Framework.GiveArenaExtras(source, skipItemName)
        if not Framework.InvSwapReady() then return end
        local extras = Config.InventorySwap.extraItems
        if not extras then return end
        local res = Config.InventorySwap.resource
        pcall(function()
            for _, it in ipairs(extras) do
                if it.name ~= skipItemName then
                    exports[res]:AddItem(source, it.name, it.count or 1)
                end
            end
        end)
    end

    -- 単一アイテムを付与（遅延でのスマホ再付与などに使用）
    function Framework.GiveItem(source, name, count)
        if not Framework.InvSwapReady() then return end
        local res = Config.InventorySwap.resource
        pcall(function()
            exports[res]:AddItem(source, name, count or 1)
        end)
    end

    -- ラジオ（pma-voice 連携
    -- ラジオ連携が有効かつリソースが起動しているか
    function Framework.RadioReady()
        if not (Config.Radio and Config.Radio.enabled) then return false end
        local res = Config.Radio.resource
        return res and GetResourceState(res) == "started"
    end

    -- プレイヤーの現在のラジオ周波数を取得（接続していなければ 0）
    function Framework.GetPlayerRadio(source)
        if not Framework.RadioReady() then return 0 end
        local ch = 0
        pcall(function()
            ch = Player(source).state.radioChannel or 0
        end)
        return ch
    end

    -- プレイヤーを指定周波数へ接続（channel=0 で切断）
    --   サーバー側 setPlayerRadio は radioEnabled を有効化しないため、
    --   クライアント側で radioEnabled=true にしてから setRadioChannel する。
    function Framework.SetPlayerRadio(source, channel)
        if not Framework.RadioReady() then return end
        TriggerClientEvent("gungame:radio:apply", source, channel or 0)
    end
else
    -- クライアント側
    function Framework.GetCitizenId()
        local core = Framework.GetCore()
        local data = core.Functions.GetPlayerData()
        return data and data.citizenid or nil
    end
end

(function () {
    "use strict";

    const root = document.getElementById("root");

    function parentRes() {
        if (typeof window.GetParentResourceName === "function") {
            try { return window.GetParentResourceName(); } catch (e) {}
        }
        return globalThis.resourceName || "ha0lu8_gungame";
    }

    function api(name, data) {
        let p;
        if (typeof globalThis.fetchNui === "function") {
            p = Promise.resolve().then(() => globalThis.fetchNui(name, data || {}));
        } else {
            p = fetch(`https://${parentRes()}/${name}`, {
                method: "POST",
                headers: { "Content-Type": "application/json; charset=UTF-8" },
                body: JSON.stringify(data || {}),
            }).then((r) => r.json());
        }
        return p.then((r) => (r == null ? {} : r)).catch(() => ({}));
    }

    const ERR = {
        already_busy: "既に募集または試合中です", invalid_mode: "無効なモードです",
        not_leader: "パーティーリーダーのみ操作できます", party_no_ffa: "パーティー中はFFAを選べません",
        party_too_big: "パーティー人数がモードに対して多すぎます", invalid_winvalue: "勝利条件の値が範囲外です",
        invalid_wintype: "勝利条件が不正です", ffa_needs_kills: "FFAはキル先取のみです",
        invalid_bet: "ベット額が範囲外です", invalid_ffa_size: "FFAの人数が範囲外です",
        invalid_custom_size: "カスタムの陣営人数が範囲外です",
        listing_gone: "募集が見つかりません", full: "満員です", side_full: "そのチームは満員です",
        invalid_side: "チーム選択が不正です", user_not_found: "ユーザーが見つかりません",
        cannot_add_self: "自分自身は追加できません", already_friends: "既にフレンドです",
        friend_limit: "フレンド上限に達しています", cannot_invite_self: "自分は招待できません",
        target_offline: "相手がオフラインです", target_in_party: "相手は既にパーティー中です",
        party_full: "パーティーが満員です", no_request: "申請が見つかりません",
        invalid_name: "表示名の長さが不正です", invalid_id: "アカウントIDの長さが不正です",
        invalid_id_chars: "IDに使えない文字が含まれています", id_taken: "そのIDは既に使われています",
        already_registered: "既に登録済みです", no_player: "プレイヤー情報が取得できません",
        bet: "ベットの支払いに失敗しました", party_gone: "パーティーが解散されました",
        already_in_party: "既にパーティー中です", invite_expired: "招待の有効期限が切れています",
        wanted: "指名手配中は利用できません",
    };
    const errMsg = (k) => ERR[k] || k || "エラーが発生しました";

    function esc(s) {
        return String(s == null ? "" : s).replace(/[&<>"']/g, (c) =>
            ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
    }
    const num = (v) => Number(v) || 0;
    const initials = (name) => (name || "?").trim().slice(0, 2).toUpperCase();
    const fmt = (v) => num(v).toLocaleString("ja-JP");

    function avatar(icon, name, lg) {
        const cls = "avatar" + (lg ? " lg" : "");
        if (icon) return `<img class="${cls}" src="${esc(icon)}" alt="" />`;
        return `<div class="${cls}">${esc(initials(name))}</div>`;
    }

    const sfx = (function () {
        let ctx = null;
        function ac() {
            if (ctx === null) {
                const AC = window.AudioContext || window.webkitAudioContext;
                ctx = AC ? new AC() : false;
            }
            if (ctx && ctx.state === "suspended") { try { ctx.resume(); } catch (e) {} }
            return ctx || null;
        }
        function tone(freq, dur, type, gain, when) {
            const c = ac();
            if (!c) return;
            const t0 = c.currentTime + (when || 0);
            const osc = c.createOscillator();
            const g = c.createGain();
            osc.type = type || "sine";
            osc.frequency.setValueAtTime(freq, t0);
            g.gain.setValueAtTime(0.0001, t0);
            g.gain.exponentialRampToValueAtTime(gain || 0.06, t0 + 0.008);
            g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
            osc.connect(g); g.connect(c.destination);
            osc.start(t0); osc.stop(t0 + dur + 0.02);
        }
        function enabled() {
            return !state.cfg || state.cfg.uiSounds !== false;
        }
        return {
            click() { if (enabled()) tone(420, 0.05, "triangle", 0.05); },
            nav()   { if (enabled()) tone(560, 0.05, "triangle", 0.045); },
            ok()    { if (enabled()) { tone(660, 0.07, "sine", 0.06); tone(990, 0.1, "sine", 0.055, 0.06); } },
            error() { if (enabled()) tone(200, 0.2, "square", 0.045); },
            info()  { if (enabled()) tone(740, 0.08, "sine", 0.05); },
        };
    })();

    const state = {
        loading: true,
        registered: false,
        cfg: null,
        profile: null,
        view: "listings",
        listings: [],
        status: "idle",
        friends: [],
        requests: [],
        rankings: { xp: [], wins: [], kills: [] },
        party: null,
        partyInvite: null,
        match: null,
        rankTab: "xp",
        create: null,
        editProfile: false,
        weaponOpen: false,
    };

    function modeAllowed(key, partySize) {
        const m = state.cfg.modes[key];
        if (m.ffa) return partySize <= 1;
        if (m.custom) return true;
        return m.teamSize >= partySize;
    }

    function ensureCreate() {
        if (!state.cfg || state.create) return;
        const cfg = state.cfg;
        const partySize = state.party ? state.party.size : 1;
        const allowed = cfg.modeOrder.find((k) => modeAllowed(k, partySize)) || "1v1";
        const isFfa = cfg.modes[allowed].ffa;
        const cc = cfg.custom || { minPerTeam: 1, maxPerTeam: 4 };
        state.create = {
            mode: allowed,
            winType: isFfa ? "kills" : "rounds",
            winValue: (isFfa ? cfg.winConditions.kills : cfg.winConditions.rounds).default,
            weapon: cfg.weapons[0].items[0].weapon,
            bet: 0,
            ffaSize: cfg.ffa.minPlayers,
            armor: false,
            staminaDrain: true,
            team1Size: Math.max(partySize, cc.minPerTeam),
            team2Size: cc.minPerTeam,
            arenaIndex: "",
        };
    }

    function applyInit(init) {
        if (!init || !init.registered) {
            state.registered = false;
            state.loading = false;
            render();
            return;
        }
        state.registered = true;
        state.cfg = init.config || state.cfg;
        state.profile = init.profile;
        state.status = init.status || "idle";
        if (!state.match || state.match.phase !== "end") {
            state.match = init.match || null;
        }
        state.listings = init.listings || [];
        state.friends = init.friends || [];
        state.requests = init.requests || [];
        state.rankings = init.rankings || { xp: [], wins: [], kills: [] };
        state.loading = false;
        ensureCreate();
        render();
    }

    function refresh() {
        return api("gungame:getInit", {}).then(applyInit);
    }

    let toastTimer = null;
    function toast(msg, type) {
        let el = document.getElementById("gg-toast");
        if (!el) {
            el = document.createElement("div");
            el.id = "gg-toast";
            document.body.appendChild(el);
        }
        el.className = "toast" + (type === "ok" ? " ok" : type === "error" ? " err" : "");
        el.textContent = msg;
        el.style.display = "block";
        if (toastTimer) clearTimeout(toastTimer);
        toastTimer = setTimeout(() => { if (el) el.style.display = "none"; }, 2600);
        if (type === "ok") sfx.ok();
        else if (type === "error") sfx.error();
        else sfx.info();
    }

    function viewListings() {
        if (state.status === "in_listing") {
            return `<div class="content"><div class="empty">マッチング待機中です...<br/>相手が揃うと自動で試合が始まります。
                <div style="margin-top:16px"><button class="btn red" data-act="leaveListing">募集をキャンセル</button></div></div></div>`;
        }
        if (!state.listings || state.listings.length === 0) {
            return `<div class="content"><div class="empty">現在募集はありません。<br/>「作成」タブから募集を立てましょう。</div></div>`;
        }
        const cards = state.listings.map((l) => {
            const winLabel = l.winType === "rounds" ? `${l.winValue}本先取` : `${l.winValue}キル先取`;
            const betBadge = l.bet > 0 ? `<span class="badge bet">$${fmt(l.bet)}</span>` : "";
            const armorBadge = `<span class="badge armor">🛡️ ${l.armor ? "有り" : "無し"}</span>`;
            const staminaBadge = `<span class="badge stamina">⚡ ${l.staminaDrain === false ? "減少無" : "減少有"}</span>`;
            const mapBadge = `<span class="badge map">🗺️ ${esc(l.mapName || "ランダム")}</span>`;
            let body;
            if (l.ffa) {
                body = `<div class="row between">
                    <span class="muted">参加 ${num(l.count)}/${num(l.ffaSize)}</span>
                    <button class="btn green sm" data-act="join" data-id="${l.id}">参加</button>
                </div>`;
            } else {
                const t1 = (l.team1 || []).length, t2 = (l.team2 || []).length;
                const s1 = l.team1Size || l.teamSize, s2 = l.team2Size || l.teamSize;
                body = `<div class="row between">
                    <div class="col">
                        <span class="muted">青チーム: ${t1}/${s1}</span>
                        <span class="muted">赤チーム: ${t2}/${s2}</span>
                    </div>
                    <div class="btn-row">
                        <button class="btn blue sm" data-act="join" data-id="${l.id}" data-side="1" ${t1 >= s1 ? "disabled" : ""}>味方側</button>
                        <button class="btn red sm" data-act="join" data-id="${l.id}" data-side="2" ${t2 >= s2 ? "disabled" : ""}>相手側</button>
                    </div>
                </div>`;
            }
            return `<div class="card">
                <div class="row between">
                    <div class="listing-grid">
                        <span class="badge mode">${esc(l.modeLabel)}</span>
                        <span class="badge win">${esc(winLabel)}</span>
                        ${mapBadge}
                        ${armorBadge}
                        ${staminaBadge}
                        ${betBadge}
                    </div>
                    <span class="muted weapon-label">${esc(l.weaponLabel)}</span>
                </div>
                <div class="muted" style="margin:8px 0">主催: ${esc(l.host)} (${esc(l.hostId)})</div>
                ${body}
            </div>`;
        }).join("");
        return `<div class="content">${cards}</div>`;
    }

    function viewCreate() {
        const cfg = state.cfg, c = state.create;
        const partySize = state.party ? state.party.size : 1;
        const isFfa = cfg.modes[c.mode].ffa;
        const isCustom = cfg.modes[c.mode].custom;
        const wc = c.winType === "rounds" ? cfg.winConditions.rounds : cfg.winConditions.kills;

        const partyNote = state.party && state.party.size > 1
            ? `<div class="muted" style="margin-bottom:8px">パーティー ${state.party.size}人 — 選べるモードが制限されます</div>` : "";

        const modeChips = cfg.modeOrder.map((k) => {
            const allowed = modeAllowed(k, partySize);
            const cls = "chip" + (c.mode === k ? " active" : "") + (allowed ? "" : " disabled");
            return `<div class="${cls}" data-act="mode" data-mode="${esc(k)}">${esc(cfg.modes[k].label)}</div>`;
        }).join("");

        const ffaField = isFfa ? `<div class="field">
            <label>参加人数 (${cfg.ffa.minPlayers}〜${cfg.ffa.maxPlayers})</label>
            <input class="input" id="create-ffasize" data-cfield="ffaSize" type="number"
                min="${cfg.ffa.minPlayers}" max="${cfg.ffa.maxPlayers}" value="${esc(c.ffaSize)}" />
        </div>` : "";

        const cc = cfg.custom || { minPerTeam: 1, maxPerTeam: 4 };
        const customField = isCustom ? `<div class="field">
            <label>陣営人数 (各 ${cc.minPerTeam}〜${cc.maxPerTeam})</label>
            <div class="row" style="gap:10px">
                <div class="col" style="flex:1">
                    <span class="muted" style="color:#3b82f6">青チーム（味方）</span>
                    <input class="input" data-cfield="team1Size" type="number"
                        min="${cc.minPerTeam}" max="${cc.maxPerTeam}" value="${esc(c.team1Size)}" />
                </div>
                <div class="col" style="flex:1">
                    <span class="muted" style="color:#ef4444">赤チーム（相手）</span>
                    <input class="input" data-cfield="team2Size" type="number"
                        min="${cc.minPerTeam}" max="${cc.maxPerTeam}" value="${esc(c.team2Size)}" />
                </div>
            </div>
        </div>` : "";

        const arenas = cfg.arenas || [];
        const mapChips = `<div class="chip ${c.arenaIndex === "" ? "active" : ""}" data-act="map" data-map="">ランダム</div>` +
            arenas.map((a) =>
                `<div class="chip ${String(c.arenaIndex) === String(a.index) ? "active" : ""}" data-act="map" data-map="${a.index}">${esc(a.name)}</div>`
            ).join("");
        const mapField = `<div class="field">
            <label>マップ</label>
            <div class="seg scroll">${mapChips}</div>
        </div>`;

        let weaponLabel = c.weapon;
        cfg.weapons.forEach((cat) => cat.items.forEach((it) => {
            if (it.weapon === c.weapon) weaponLabel = it.label;
        }));
        const weaponList = cfg.weapons.map((cat) =>
            `<div class="dd-group">${esc(cat.label)}</div>` +
            cat.items.map((it) =>
                `<div class="dd-item ${c.weapon === it.weapon ? "active" : ""}" data-act="selectWeapon" data-weapon="${esc(it.weapon)}">${esc(it.label)}</div>`
            ).join("")).join("");

        const betField = cfg.betting.enabled ? `<div class="field">
            <label>ベット額 (勝者総取り / ${cfg.betting.min}〜${cfg.betting.max})</label>
            <input class="input" id="create-bet" data-cfield="bet" type="number"
                min="${cfg.betting.min}" max="${cfg.betting.max}" value="${esc(c.bet)}" />
        </div>` : "";

        return `<div class="content">
            ${partyNote}
            <div class="field">
                <label>モード</label>
                <div class="seg scroll">${modeChips}</div>
            </div>
            ${ffaField}
            ${customField}
            ${mapField}
            <div class="field">
                <label>勝利条件</label>
                <div class="seg">
                    <div class="chip ${c.winType === "rounds" ? "active" : ""} ${isFfa ? "disabled" : ""}" data-act="winType" data-wt="rounds">ラウンド制</div>
                    <div class="chip ${c.winType === "kills" ? "active" : ""}" data-act="winType" data-wt="kills">キル先取</div>
                </div>
            </div>
            <div class="field">
                <label>${c.winType === "rounds" ? "先取ラウンド数" : "目標キル数"} (${wc.min}〜${wc.max})</label>
                <input class="input" id="create-winvalue" data-cfield="winValue" type="number"
                    min="${wc.min}" max="${wc.max}" value="${esc(c.winValue)}" />
            </div>
            <div class="field">
                <label>武器</label>
                <div class="dropdown ${state.weaponOpen ? "open" : ""}">
                    <div class="dd-head" data-act="toggleWeapon">
                        <span>${esc(weaponLabel)}</span><span class="dd-caret">▾</span>
                    </div>
                    ${state.weaponOpen ? `<div class="dd-list">${weaponList}</div>` : ""}
                </div>
            </div>
            <div class="field">
                <label>スタミナ減少</label>
                <div class="seg">
                    <div class="chip ${c.staminaDrain ? "active" : ""}" data-act="stamina" data-stamina="1">有り</div>
                    <div class="chip ${!c.staminaDrain ? "active" : ""}" data-act="stamina" data-stamina="0">無し</div>
                </div>
            </div>
            <div class="field">
                <label>アーマー</label>
                <div class="seg">
                    <div class="chip ${!c.armor ? "active" : ""}" data-act="armor" data-armor="0">無し</div>
                    <div class="chip ${c.armor ? "active" : ""}" data-act="armor" data-armor="1">有り</div>
                </div>
            </div>
            ${betField}
            <button class="btn primary" data-act="create">募集を作成</button>
        </div>`;
    }

    function viewRankings() {
        const labels = { xp: "週間XP", wins: "週間勝利", kills: "週間キル" };
        const tabs = Object.keys(labels).map((k) =>
            `<button class="btn sm ${state.rankTab === k ? "primary" : "ghost"}" data-act="rankTab" data-rt="${k}">${labels[k]}</button>`
        ).join("");
        const list = (state.rankings && state.rankings[state.rankTab]) || [];
        let body;
        if (list.length === 0) {
            body = `<div class="empty">今週のデータはまだありません。</div>`;
        } else {
            body = list.map((r, i) => `<div class="rank-item">
                <div class="rank-num ${i === 0 ? "top1" : ""}">${i + 1}</div>
                ${avatar(r.icon, r.name)}
                <div class="col" style="flex:1">
                    <div style="font-weight:700">${esc(r.name)}</div>
                    <div class="muted">Lv.${num(r.level)} · ${esc(r.accountId)}</div>
                </div>
                <div class="rank-val">${fmt(r[state.rankTab])}</div>
            </div>`).join("");
        }
        return `<div class="content"><div class="rank-tabs">${tabs}</div>${body}</div>`;
    }

    function viewFriends() {
        const reqHtml = (state.requests && state.requests.length > 0) ? `<div class="card">
            <div class="muted" style="margin-bottom:8px">受信した申請</div>
            ${state.requests.map((r) => `<div class="row between" style="margin-bottom:8px">
                <div class="row">${avatar(r.icon, r.name)}<div class="col"><b>${esc(r.name)}</b><span class="muted">${esc(r.accountId)}</span></div></div>
                <div class="btn-row">
                    <button class="btn green sm" data-act="acceptFriend" data-cid="${esc(r.citizenid)}">承認</button>
                    <button class="btn ghost sm" data-act="declineFriend" data-cid="${esc(r.citizenid)}">拒否</button>
                </div>
            </div>`).join("")}
        </div>` : "";

        const friendsHtml = (!state.friends || state.friends.length === 0)
            ? `<div class="empty">フレンドがいません。</div>`
            : state.friends.map((f) => `<div class="card">
                <div class="row between">
                    <div class="row">
                        ${avatar(f.icon, f.name)}
                        <div class="col">
                            <b>${esc(f.name)} ${f.online ? `<span class="badge win">オンライン</span>` : `<span class="badge">オフライン</span>`}</b>
                            <span class="muted">Lv.${num(f.level)} · ${esc(f.accountId)}</span>
                        </div>
                    </div>
                    <div class="btn-row">
                        ${f.online && !f.inParty ? `<button class="btn blue sm" data-act="invite" data-aid="${esc(f.accountId)}">招待</button>` : ""}
                        <button class="btn ghost sm" data-act="removeFriend" data-cid="${esc(f.citizenid)}">削除</button>
                    </div>
                </div>
            </div>`).join("");

        return `<div class="content">
            <div class="card">
                <label class="muted">アカウントIDでフレンド追加</label>
                <div class="row" style="margin-top:6px">
                    <input class="input" id="friend-add" placeholder="アカウントID" />
                    <button class="btn blue sm" data-act="friendReq">申請</button>
                </div>
            </div>
            ${reqHtml}
            ${friendsHtml}
        </div>`;
    }

    function viewProfile() {
        const p = state.profile;
        const pct = p.levelNeed ? Math.floor((p.levelXp / p.levelNeed) * 100) : 0;

        return `<div class="content">
            <div class="row between" style="margin-bottom:4px">
                <b>マイページ</b>
                <button class="btn ghost sm" data-act="tab" data-tab="listings">← 戻る</button>
            </div>
            <div class="card">
                <div class="row">
                    ${avatar(p.icon, p.name, true)}
                    <div class="col" style="flex:1">
                        <h3>${esc(p.name)}</h3>
                        <span class="muted">${esc(p.accountId)}</span>
                    </div>
                    <div class="col" style="align-items:flex-end;gap:8px">
                        <div style="font-size:38px;font-weight:900">Lv.${num(p.level)}</div>
                        <button class="btn ghost sm" data-act="editProfile">編集</button>
                    </div>
                </div>
                <div class="levelbar"><div style="width:${pct}%"></div></div>
                <div class="muted" style="margin-top:4px">${num(p.levelXp)} / ${num(p.levelNeed)} XP (累計 ${fmt(p.totalXp)})</div>
            </div>
            <div class="card">
                <div class="row between">
                    <div class="col"><span class="muted">勝利</span><b style="font-size:28px">${num(p.totalWins)}</b></div>
                    <div class="col"><span class="muted">敗北</span><b style="font-size:28px">${num(p.totalLosses)}</b></div>
                    <div class="col"><span class="muted">総キル</span><b style="font-size:28px">${num(p.totalKills)}</b></div>
                </div>
            </div>
        </div>`;
    }

    function viewParty() {
        const party = state.party;

        let partyBody;
        if (party) {
            const members = party.members.map((mem) => `<div class="party-chip">
                <span class="pm-name">${mem.isLeader ? `<span class="crown">👑</span>` : ""}${esc(mem.name)}</span>
                ${party.isLeader && !mem.isLeader ? `<span class="pm-kick" data-act="kick" data-cid="${esc(mem.citizenid)}">✕</span>` : ""}
            </div>`).join("");
            const inviteRow = (party.isLeader && party.size < party.max) ? `<div class="row" style="margin-top:10px">
                <input class="input" id="party-invite" placeholder="招待するアカウントID" />
                <button class="btn blue sm" data-act="partyInvite">招待</button>
            </div>` : "";
            partyBody = `<div class="party-members">${members}</div>${inviteRow}`;
        } else {
            partyBody = `<div class="col" style="margin-top:8px">
                <span class="muted">パーティー未参加。アカウントIDで仲間を招待できます。</span>
                <div class="row" style="margin-top:8px">
                    <input class="input" id="party-invite" placeholder="招待するアカウントID" />
                    <button class="btn blue sm" data-act="partyInvite">招待</button>
                </div>
            </div>`;
        }

        return `<div class="content">
            <div class="card">
                <div class="row between"><b>パーティー</b>
                    ${party ? `<button class="btn red sm" data-act="leaveParty">退出/解散</button>` : ""}
                </div>
                ${party ? `<div class="muted" style="margin:6px 0">${num(party.size)}/${num(party.max)} 人</div>` : ""}
                ${partyBody}
            </div>
        </div>`;
    }

    function viewEditProfile() {
        const p = state.profile;
        const acc = (state.cfg && state.cfg.account) || { nameMinLen: 2, nameMaxLen: 16 };
        return `<div class="modal-bg">
            <div class="modal">
                <h3>プロフィール編集</h3>
                <div class="field">
                    <label>表示名 (${acc.nameMinLen}〜${acc.nameMaxLen}文字)</label>
                    <input class="input" id="edit-name" value="${esc(p.name)}" placeholder="表示名" />
                </div>
                <div class="field">
                    <label>アイコン画像URL (任意・空欄で削除)</label>
                    <input class="input" id="edit-icon" value="${esc(p.icon || "")}" placeholder="https://..." />
                </div>
                <p class="muted" style="margin-bottom:14px">アカウントID (${esc(p.accountId)}) は変更できません。</p>
                <div class="btn-row">
                    <button class="btn primary" data-act="saveProfile">保存</button>
                    <button class="btn ghost" data-act="cancelEdit">キャンセル</button>
                </div>
            </div>
        </div>`;
    }

    function viewMatch() {
        const m = state.match;
        if (m.phase === "end") {
            const r = m.result || {};
            const cls = r.outcome === "win" ? "win" : r.outcome === "loss" ? "loss" : "draw";
            const label = r.outcome === "win" ? "勝利" : r.outcome === "loss" ? "敗北" : "引き分け";
            const potHtml = r.pot > 0 ? `<div class="hud-sub" style="color:var(--gold)">賞金 +$${fmt(r.pot)}</div>` : "";
            return `<div class="match-overlay">
                <div class="result-big ${cls}">${label}</div>
                <div class="hud-sub">キル ${num(r.kills)} / デス ${num(r.deaths)}</div>
                <div class="hud-sub" style="margin-top:10px">獲得XP +${num(r.xpGained)}${r.leveledUp ? ` (Lv.${num(r.level)} に昇格!)` : ""}</div>
                ${potHtml}
                <div class="spacer"></div>
                <div class="hud-sub">数秒後にロビーへ戻ります...</div>
            </div>`;
        }
        if (m.phase === "countdown") {
            const info = m.info || {};
            const side = info.ffa ? "FFA" : info.team === 1 ? "チーム1" : "チーム2";
            return `<div class="match-overlay">
                <div class="hud-sub">${esc(side)} · ${esc(info.weapon)}</div>
                <div class="countdown">準備</div>
            </div>`;
        }
        const info = m.info || {}, st = m.state;
        let scoreHtml;
        if (info.ffa) {
            const scores = (st && st.scores) ? st.scores : [];
            scoreHtml = `<div style="margin-top:14px">${scores.map((s, i) =>
                `<div class="ffa-score-row"><span>${i + 1}. ${esc(s.name)} ${s.alive ? "" : "💀"}</span><b>${num(s.kills)}</b></div>`
            ).join("")}</div>`;
        } else {
            const a = st ? (info.winType === "rounds" ? st.teamRoundWins.t1 : st.teamKills.t1) : 0;
            const b = st ? (info.winType === "rounds" ? st.teamRoundWins.t2 : st.teamKills.t2) : 0;
            scoreHtml = `<div class="hud-score"><span class="t1">${num(a)}</span><span>:</span><span class="t2">${num(b)}</span></div>`;
        }
        const roundLabel = info.winType === "rounds" ? `ラウンド ${st ? st.round : 1}` : "キル先取";
        const spectate = m.spectating ? `<div class="hud-sub" style="color:var(--gold)">次ラウンドを待っています</div>` : "";
        return `<div class="match-overlay">
            <div class="hud-sub">${esc(roundLabel)} · 目標 ${num(info.winValue)}</div>
            ${scoreHtml}
            ${spectate}
            <div class="spacer"></div>
            <button class="btn red" data-act="forfeit">試合を放棄</button>
        </div>`;
    }

    function buildHTML() {
        if (state.loading) {
            return `<div class="app"><div class="empty" style="margin-top:120px">読み込み中...</div></div>`;
        }
        if (!state.registered) {
            const acc = (state.cfg && state.cfg.account) || { nameMinLen: 2, nameMaxLen: 16 };
            return `<div class="app">
                <div class="header"><h1>Gun <span class="accent">Game</span></h1></div>
                <div class="content">
                    <div class="card">
                        <h3 style="margin-bottom:10px">アカウント登録</h3>
                        <p class="muted" style="margin-bottom:14px">Gun Game を始めるにはアカウントを作成してください。</p>
                        <div class="field">
                            <label>表示名 (${acc.nameMinLen}〜${acc.nameMaxLen}文字)</label>
                            <input class="input" id="reg-name" placeholder="例: Shooter" />
                        </div>
                        <div class="field">
                            <label>アカウントID (英数字・他人と重複不可)</label>
                            <input class="input" id="reg-id" placeholder="例: shooter_01" />
                        </div>
                        <div class="field">
                            <label>アイコン画像URL (任意)</label>
                            <input class="input" id="reg-icon" placeholder="https://..." />
                        </div>
                        <button class="btn primary" data-act="register">登録する</button>
                    </div>
                </div>
            </div>`;
        }
        if (state.match) {
            return `<div class="app">${viewMatch()}</div>`;
        }

        const p = state.profile;
        const partyBar = state.party ? `<div style="padding:0 14px">
            <div class="partybar"><div class="row between">
                <span class="muted">パーティー ${state.party.size}/${state.party.max}</span>
                <span class="muted">${esc(state.party.members.map((m) => m.name).join(", "))}</span>
            </div></div></div>` : "";

        let viewHtml = "";
        if (state.view === "listings") viewHtml = viewListings();
        else if (state.view === "create") viewHtml = viewCreate();
        else if (state.view === "rankings") viewHtml = viewRankings();
        else if (state.view === "friends") viewHtml = viewFriends();
        else if (state.view === "party") viewHtml = viewParty();
        else if (state.view === "profile") viewHtml = viewProfile();

        const tabs = [
            { key: "listings", label: "募集", ico: "📋" },
            { key: "create", label: "作成", ico: "➕" },
            { key: "rankings", label: "ランク", ico: "🏆" },
            { key: "friends", label: "フレンド", ico: "👥" },
            { key: "party", label: "マイ", ico: "🤝" },
        ].map((t) => `<button class="${state.view === t.key ? "active" : ""}" data-act="tab" data-tab="${t.key}">
            <span class="ico">${t.ico}</span>${t.label}</button>`).join("");

        const modal = state.partyInvite ? `<div class="modal-bg">
            <div class="modal">
                <h3>パーティー招待</h3>
                <p class="muted" style="margin-bottom:14px">${esc(state.partyInvite.from)} (${esc(state.partyInvite.fromAccountId)}) からの招待</p>
                <div class="btn-row">
                    <button class="btn green" data-act="acceptParty">参加</button>
                    <button class="btn ghost" data-act="declineParty">拒否</button>
                </div>
            </div>
        </div>` : "";

        const editModal = state.editProfile ? viewEditProfile() : "";

        return `<div class="app">
            <div class="header">
                <h1>Gun <span class="accent">Game</span></h1>
                <div class="row"><span class="muted">Lv.${num(p.level)}</span><span data-act="openProfile" style="cursor:pointer">${avatar(p.icon, p.name)}</span></div>
            </div>
            ${partyBar}
            ${viewHtml}
            <div class="tabbar">${tabs}</div>
            ${modal}
            ${editModal}
        </div>`;
    }

    const TEXT_INPUT_IDS = ["reg-name", "reg-id", "reg-icon", "friend-add", "party-invite", "edit-name", "edit-icon"];
    if (!state.inputs) state.inputs = {};
    let pendingRender = false;
    let lastRenderKey = null;

    function isTyping() {
        const active = document.activeElement;
        if (!active || !active.id) return false;
        return TEXT_INPUT_IDS.includes(active.id);
    }

    function flushRender() {
        pendingRender = false;
        doRender();
    }

    function render() {
        if (isTyping()) {
            pendingRender = true;
            return;
        }
        doRender();
    }

    function doRender() {
        for (const id of TEXT_INPUT_IDS) {
            const el = document.getElementById(id);
            if (el) state.inputs[id] = el.value;
        }

        const renderKey = state.match ? "match" : (state.view || "");
        const prevContent = root.querySelector(".content");
        const prevScroll = prevContent ? prevContent.scrollTop : 0;

        root.innerHTML = buildHTML();

        for (const id of TEXT_INPUT_IDS) {
            if (state.inputs[id]) {
                const el = document.getElementById(id);
                if (el) el.value = state.inputs[id];
            }
        }

        const newContent = root.querySelector(".content");
        if (newContent && lastRenderKey === renderKey && prevScroll > 0) {
            newContent.scrollTop = prevScroll;
        }
        lastRenderKey = renderKey;
    }

    let lastMousedownTarget = null;
    document.addEventListener("mousedown", (e) => {
        lastMousedownTarget = e.target;
        if (e.target && (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA")) {
            e.stopPropagation();
        }
    }, true);
    document.addEventListener("touchstart", (e) => {
        lastMousedownTarget = e.target;
        if (e.target && (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA")) {
            e.stopPropagation();
        }
    }, { capture: true, passive: true });

    root.addEventListener("blur", (e) => {
        if (!e.target || !TEXT_INPUT_IDS.includes(e.target.id)) return;
        if (state.inputs[e.target.id] !== undefined) state.inputs[e.target.id] = e.target.value;

        const lostEl = e.target;

        requestAnimationFrame(() => {
            const ae = document.activeElement;
            const ae_is_neutral = ae === document.body || ae === null || ae === document.documentElement;

            if (ae_is_neutral) {
                if (lastMousedownTarget === lostEl) {
                    const still = document.getElementById(lostEl.id);
                    if (still) still.focus();
                } else if (pendingRender) {
                    flushRender();
                }
            } else if (pendingRender) {
                flushRender();
            }
        });
    }, true);

    function isTextTarget(t) {
        return t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA");
    }
    let typingActive = false;
    let idleTimer = null;
    let lastSent = 0;
    function engage() {
        if (state.match) return;
        typingActive = true;
        const now = Date.now();
        if (now - lastSent > 300) { lastSent = now; api("gungame:setTyping", { typing: true }); }
        if (idleTimer) clearTimeout(idleTimer);
        idleTimer = setTimeout(release, 2000);
    }
    function release() {
        if (idleTimer) { clearTimeout(idleTimer); idleTimer = null; }
        if (!typingActive) return;
        typingActive = false;
        lastSent = 0;
        api("gungame:setTyping", { typing: false });
    }
    root.addEventListener("keydown", () => { if (isTextTarget(document.activeElement)) engage(); }, true);
    root.addEventListener("focusout", () => {
        setTimeout(() => { if (!isTextTarget(document.activeElement)) release(); }, 80);
    }, true);
    document.addEventListener("visibilitychange", () => { if (document.hidden) release(); });
    window.addEventListener("blur", release);

    function join(id, side) {
        api("gungame:joinListing", { id: id, side: side }).then((res) => {
            if (res.ok) { state.status = "in_listing"; render(); }
            else toast(errMsg(res.err), "error");
        });
    }

    function doCreate() {
        const c = state.create;
        if (state.party && !state.party.isLeader) { toast("パーティーリーダーのみ募集できます", "error"); return; }
        api("gungame:createListing", {
            mode: c.mode, weapon: c.weapon, winType: c.winType,
            winValue: num(c.winValue), bet: num(c.bet), ffaSize: num(c.ffaSize),
            armor: !!c.armor,
            staminaDrain: !!c.staminaDrain,
            team1Size: num(c.team1Size), team2Size: num(c.team2Size),
            arenaIndex: c.arenaIndex,
        }).then((res) => {
            if (res.ok) { state.status = "in_listing"; state.view = "listings"; toast("募集を作成しました", "ok"); render(); }
            else toast(errMsg(res.err), "error");
        });
    }

    function doRegister() {
        const name = (document.getElementById("reg-name") || {}).value || state.inputs["reg-name"] || "";
        const accountId = (document.getElementById("reg-id") || {}).value || state.inputs["reg-id"] || "";
        const icon = (document.getElementById("reg-icon") || {}).value || state.inputs["reg-icon"] || "";
        if (!name || !accountId) { toast("表示名とアカウントIDを入力してください", "error"); return; }
        api("gungame:register", { name: name, accountId: accountId, icon: icon }).then((res) => {
            if (res.ok) {
                state.inputs["reg-name"] = state.inputs["reg-id"] = state.inputs["reg-icon"] = "";
                applyInit(res.init);
            } else {
                toast(errMsg(res.err), "error");
            }
        });
    }

    function doFriendReq() {
        const inp = document.getElementById("friend-add");
        const accountId = (inp ? inp.value : "") || (state.inputs["friend-add"] || "");
        if (!accountId) return;
        api("gungame:friendRequest", { accountId: accountId }).then((res) => {
            if (res.ok) { toast("フレンド申請を送りました", "ok"); state.inputs["friend-add"] = ""; if (inp) inp.value = ""; }
            else toast(errMsg(res.err), "error");
        });
    }

    function doSaveProfile() {
        const name = (document.getElementById("edit-name") || {}).value || state.inputs["edit-name"] || "";
        const icon = (document.getElementById("edit-icon") || {}).value || state.inputs["edit-icon"] || "";
        if (!name) { toast("表示名を入力してください", "error"); return; }
        api("gungame:updateProfile", { name: name, icon: icon }).then((res) => {
            if (res.ok) {
                if (res.profile) state.profile = res.profile;
                state.editProfile = false;
                state.inputs["edit-name"] = state.inputs["edit-icon"] = "";
                toast("プロフィールを更新しました", "ok");
                render();
            } else {
                toast(errMsg(res.err), "error");
            }
        });
    }

    function doPartyInvite() {
        const inp = document.getElementById("party-invite");
        const accountId = (inp ? inp.value : "") || (state.inputs["party-invite"] || "");
        if (!accountId) return;
        api("gungame:partyInvite", { accountId: accountId }).then((res) => {
            if (res.ok) { toast("招待しました", "ok"); state.inputs["party-invite"] = ""; if (inp) inp.value = ""; }
            else toast(errMsg(res.err), "error");
        });
    }

    root.addEventListener("click", (e) => {
        const el = e.target.closest("[data-act]");
        if (!el) return;
        const act = el.dataset.act;
        const d = el.dataset;

        if (!el.classList.contains("disabled")) {
            if (act === "tab") sfx.nav(); else sfx.click();
        }

        switch (act) {
            case "tab": state.view = d.tab; render(); break;
            case "leaveListing":
                api("gungame:leaveListing", {}); state.status = "idle"; render(); break;
            case "join":
                join(Number(d.id), d.side ? Number(d.side) : null); break;
            case "mode": {
                if (el.classList.contains("disabled")) break;
                state.create.mode = d.mode;
                const isFfa = state.cfg.modes[d.mode].ffa;
                if (isFfa && state.create.winType !== "kills") state.create.winType = "kills";
                const wc = state.create.winType === "rounds" ? state.cfg.winConditions.rounds : state.cfg.winConditions.kills;
                state.create.winValue = wc.default;
                render(); break;
            }
            case "winType": {
                if (el.classList.contains("disabled")) break;
                state.create.winType = d.wt;
                const wc = d.wt === "rounds" ? state.cfg.winConditions.rounds : state.cfg.winConditions.kills;
                state.create.winValue = wc.default;
                render(); break;
            }
            case "armor": state.create.armor = (d.armor === "1"); render(); break;
            case "stamina": state.create.staminaDrain = (d.stamina === "1"); render(); break;
            case "map": state.create.arenaIndex = d.map; render(); break;
            case "openProfile": state.view = "profile"; render(); break;
            case "toggleWeapon": state.weaponOpen = !state.weaponOpen; render(); break;
            case "selectWeapon": state.create.weapon = d.weapon; state.weaponOpen = false; render(); break;
            case "create": doCreate(); break;
            case "register": doRegister(); break;
            case "rankTab": state.rankTab = d.rt; render(); break;
            case "friendReq": doFriendReq(); break;
            case "acceptFriend": api("gungame:acceptFriend", { fromCid: d.cid }); break;
            case "declineFriend": api("gungame:declineFriend", { fromCid: d.cid }); break;
            case "removeFriend": api("gungame:removeFriend", { friendCid: d.cid }); break;
            case "invite":
                api("gungame:partyInvite", { accountId: d.aid }).then((res) => {
                    if (res.ok) toast("パーティーに招待しました", "ok"); else toast(errMsg(res.err), "error");
                }); break;
            case "partyInvite": doPartyInvite(); break;
            case "editProfile": state.editProfile = true; render(); break;
            case "saveProfile": doSaveProfile(); break;
            case "cancelEdit": state.editProfile = false; render(); break;
            case "leaveParty": api("gungame:leaveParty", {}); break;
            case "kick": api("gungame:kickParty", { targetCid: d.cid }); break;
            case "forfeit": api("gungame:forfeit", {}); break;
            case "acceptParty":
                if (state.partyInvite) api("gungame:acceptParty", { partyId: state.partyInvite.partyId });
                state.partyInvite = null; render(); break;
            case "declineParty":
                if (state.partyInvite) api("gungame:declineParty", { partyId: state.partyInvite.partyId });
                state.partyInvite = null; render(); break;
        }
    });

    function onField(e) {
        const f = e.target.dataset.cfield;
        if (f && state.create) state.create[f] = e.target.value;
    }
    root.addEventListener("input", onField);
    root.addEventListener("change", onField);

    window.addEventListener("keydown", (e) => {
        const t = e.target;
        const tag = t && t.tagName;
        const typing = tag === "INPUT" || tag === "TEXTAREA" || (t && t.isContentEditable);
        if (typing) return;
        if (e.key === " " || e.code === "Space" ||
            e.key === "PageUp" || e.key === "PageDown" ||
            e.key === "ArrowUp" || e.key === "ArrowDown") {
            e.preventDefault();
        }
    });

    function handleEvent(ev, data) {
        switch (ev) {
            case "match:listings": state.listings = data || []; if (state.view === "listings") render(); break;
            case "match:cancelled": state.status = "idle"; toast("募集がキャンセルされました", "error"); render(); break;
            case "match:aborted": state.status = "idle"; toast("試合を開始できませんでした", "error"); render(); break;
            case "notify": if (data && data.message) toast(data.message); break;
            case "match:found":
                toast((data && data.delay)
                    ? ("マッチ成立！" + data.delay + "秒後に試合会場へ移動します")
                    : "マッチが成立しました！", "ok");
                break;
            case "match:forfeitPending":
                toast((data && data.delay)
                    ? (data.delay + "秒後に試合を放棄します")
                    : "試合を放棄します");
                break;
            case "friends:list": state.friends = data || []; if (state.view === "friends") render(); break;
            case "friends:requests": state.requests = data || []; if (state.view === "friends") render(); break;
            case "party:update":
                state.party = data ? Object.assign({}, data, { max: data.max || 3 }) : null;
                render(); break;
            case "party:invite": state.partyInvite = data; render(); break;
            case "match:enter":
                state.status = "in_match";
                state.match = { phase: "countdown", info: data, state: null, spectating: false };
                release();
                render(); break;
            case "match:go":
                if (state.match) { state.match.phase = "running"; render(); } break;
            case "match:state":
                if (state.match) { state.match.state = data; render(); } break;
            case "match:spectate":
                if (state.match) { state.match.spectating = true; render(); } break;
            case "match:respawn":
                if (state.match) { state.match.spectating = false; render(); } break;
            case "match:roundReset":
                if (state.match) {
                    state.match.spectating = false;
                    if (state.match.state && data) state.match.state.round = data.round;
                    render();
                } break;
            case "match:end":
                state.match = { phase: "end", result: data, info: {}, state: null };
                state.status = "idle";
                render();
                setTimeout(() => { state.match = null; refresh(); }, 5000);
                break;
        }
    }

    window.addEventListener("message", (e) => {
        const m = e.data || {};
        const ev = m.event || m.action;
        if (!ev) return;
        const data = (m.data !== undefined) ? m.data : null;
        handleEvent(ev, data);
    });

    render();
    refresh();
})();

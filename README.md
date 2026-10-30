# Gun Game Phone

FiveM向けの撃ち合いマッチングリソースです。LB Phoneの「GUN GAME」アプリから募集・参加し、通常世界とは別のRouting Bucketで対戦できます。

1試合につき選択した1種類の武器を使用します。キルごとに武器が変わる方式ではありません。

## 主な機能

- 1v1・2v2・3v3、人数を個別指定できるカスタムチーム戦、FFA
- ラウンド先取・キル数先取、マップ選択またはランダム選択
- 募集時のアーマー・スタミナ減少の設定
- アカウント登録、プロフィール編集、フレンド申請、パーティー
- 累計戦績・XP・レベル、週次のXP・勝利数・キル数ランキング
- ベット、勝者への配当、引き分け時の返金
- 試合用装備への切り替え、終了時の所持品復元
- カウントダウン・スコア・観戦・結果のHUD
- エリア外ダメージ、元の場所に表示する分身、帰還後の保護

## 動作環境

| リソース | 用途 |
| --- | --- |
| `qbx_core` | 現在のマニフェストで必須のフレームワーク |
| `ox_lib` | 共通ライブラリ・Qbox用コールバック |
| `oxmysql` | アカウント・戦績などのDB処理 |
| `lb-phone` | アプリの登録・表示・通知 |
| `ox_inventory` | 標準設定での所持品退避・武器や弾薬の付与・復元 |

`config/framework.lua`には`qb-core`を取得する処理もありますが、現在の`fxmanifest.lua`は`qbx_core`を依存先として指定しています。QBCore環境へ移す場合はマニフェストと連携処理を環境に合わせて調整してください。

以下は機能に応じた連携先です。

| リソース | 用途 |
| --- | --- |
| `pma-voice` | チーム別のラジオ自動接続。使用する場合は`Config.Radio.enabled = true` |
| `wasabi_ambulance` | 蘇生処理。`Config.Ambulance.resource`で変更可能 |
| `illenium-appearance` | 分身の外見取得・適用。未起動時はネイティブ処理にフォールバック |
| `GKRHUD` | 分身に表示する名前・タグの同期 |
| `gkr-wanted` | 手配中プレイヤーの募集作成・参加制限 |

## 導入

1. サーバーの`resources`配下へ`ha0lu8_gungame`フォルダを配置します。
2. 使用するサーバーのデータベースで`sql/install.sql`を実行します。
3. `config/config.lua`をサーバー環境に合わせて編集します。
4. 依存リソースの起動後に、このリソースを起動します。

`server.cfg`の起動順の例です。各依存リソース自体の導入・設定も完了させてください。

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure ox_inventory
ensure lb-phone
ensure pma-voice
ensure wasabi_ambulance
ensure ha0lu8_gungame
```

ラジオや救急の連携先が異なる場合は、上記のリソース名と対応するコンフィグを変更します。LB Phoneへのアプリ登録はクライアント側で自動実行されます。

### 導入時に確認する項目

- `Config.Arenas`の座標・高さ・半径が使用するマップに合っているか確認してください。カスタム人数を増やす場合は、チームのスポーン地点も増やしてください。
- `Config.Weapons`にはカスタム武器が含まれます。武器本体とox_inventory側の定義を導入するか、使用しない武器を一覧から外してください。
- `Config.WeaponAmmoItem`の弾薬名、`Config.InventorySwap.extraItems`のスマホ・ラジオ名を、実際のアイテム定義に合わせてください。
- `Config.WeaponAttachments`のキットアイテムは別途定義が必要です。使用しないカテゴリは設定から外せます。キットはアイテムとして付与され、武器には自動装着されません。
- `Config.BucketStart`と`Config.Radio.channelBase`が他のリソースの使用範囲と衝突しないようにしてください。

### Qboxの位置保存との連携

本リソースは試合中に`gungameNoSave`を設定し、Qboxのプレイヤーデータへ試合前の座標を渡します。

`config/framework.lua`は、`qbx_core/server/player.lua`の保存処理がこのフラグを確認し、試合中は現在地ではなく保存済みの`playerData.position`をDBへ書き込む構成を前提としています。このQbox側の変更は本リソースに含まれません。未対応の環境では、クラッシュ後の再接続でアリーナ座標が保存される可能性があるため、導入先の保存処理を確認してください。

## 使い方

1. LB Phoneから「GUN GAME」を開き、表示名・アカウントIDを登録します。
2. 「作成」でモード、武器、勝利条件、マップ、ベット額などを指定するか、「募集」から既存の募集へ参加します。
3. パーティーで遊ぶ場合は、フレンドや「マイ」画面から招待し、リーダーが募集を作成・参加します。
4. 必要人数が揃うとマッチが成立し、通知後に会場へ移動します。カウントダウン終了後に戦闘が始まります。
5. 試合終了後は結果が表示され、元の場所へ戻ります。

- ラウンド制はチーム全滅でラウンドが決着し、死亡中は観戦になります。
- キル数先取・FFAは死亡後にリスポーンします。FFAはキル数先取のみ対応し、複数人のパーティーでは参加できません。
- 試合中はアプリの「試合を放棄」から降参できます。チーム戦は放棄した側の敗北となります。現在の実装は即時に放棄処理を行い、`Config.ForfeitDelay`は参照していません。
- ベットの賞金は勝者へ分配します。チーム戦では勝利チームの対象プレイヤー間で分配し、引き分け時は返金します。
- プロフィールは右上のアイコンから編集できます。

## 主要設定

設定は`config/config.lua`、フレームワーク・インベントリ・蘇生などの連携処理は`config/framework.lua`にあります。

| 設定 | 内容・標準値 |
| --- | --- |
| `Config.PhoneResource` / `Config.App` | 電話のリソース名、アプリ名、アイコンなど |
| `Config.Debug` / `Config.DebugSolo` | ログ出力・1人での動作確認。標準は両方`false` |
| `Config.Custom` | カスタム戦の各チーム人数。1〜4人 |
| `Config.FFA` | FFAの人数。2〜8人 |
| `Config.WinConditions` | ラウンド先取1〜9本、キル数先取1〜50キル |
| `Config.TimeLimit` | ラウンド180秒、キル数先取・FFA各600秒。0で無制限 |
| `Config.MatchStartDelay` | マッチ成立から移動まで10秒 |
| `Config.Combat` | 開始時の体力・アーマー、カウントダウン、キル時回復 |
| `Config.RespawnDelay` | リスポーンまで3秒 |
| `Config.Betting` | 有効・銀行口座・0〜1,000,000 |
| `Config.XP` / `Config.Level` | XP配分、1,000XPでレベルアップ、上限999 |
| `Config.Ranking` | 各ランキング上位50件。サーバーのローカル時刻で月曜0時に週次リセット |
| `Config.Social` | フレンド100人、パーティー3人、招待期限60秒 |
| `Config.Arenas` / `Config.Zone` | 会場・スポーン地点・境界表示・エリア外ダメージ |
| `Config.Weapons` / `Config.WeaponAmmoItem` | 武器一覧と弾薬アイテムの対応 |
| `Config.WeaponAmmo` / `Config.WeaponLoadedAmmo` | 予備弾薬1,000、初期装填250 |
| `Config.InventorySwap` | 所持品の退避・復元、追加アイテム、操作ロック |
| `Config.WeaponAttachments` | 武器カテゴリ別の支給キット |
| `Config.StandIn` | 分身の外見・アニメーション・タグ・帰還後の保護 |
| `Config.ResultDisplay` | 結果表示から帰還まで5秒 |
| `Config.Ambulance` / `Config.Radio` / `Config.Sounds` | 蘇生・ラジオ・効果音の連携 |

## データ保存

`sql/install.sql`は次の5テーブルを作成します。

- `gungame_accounts`：アカウント・プロフィール・累計戦績
- `gungame_weekly`：週次XP・勝利数・キル数
- `gungame_meta`：週次リセットの実行記録
- `gungame_friends`：フレンド関係
- `gungame_friend_requests`：承認待ちの申請

所持品の退避はox_inventoryのDBを使用します。退避中の記録や帰還位置はリソースKVPにも保存し、再接続・リソース起動時などに復旧を試みます。募集や進行中の試合自体はメモリ上で管理され、再起動で引き継がれません。

## 他リソースからの試合中判定

サーバー側ではプレイヤーのサーバーIDを渡します。

```lua
local inMatch = exports['ha0lu8_gungame']:IsPlayerInMatch(source)
```

クライアント側では自身の試合状態を取得できます。

```lua
local inMatch = exports['ha0lu8_gungame']:IsInMatch()
```

リソース名を変更した場合は、呼び出し先も変更してください。試合状態のステートバッグ`gungameMatch`も設定します。ストレス増加や手配の免除などに利用する場合は、外部リソース側で判定を追加してください。

## トラブルシューティング

| 症状 | 確認する内容 |
| --- | --- |
| 電話にアプリが出ない | `Config.PhoneResource`、LB Phoneの起動状態、クライアントのF8ログ |
| 登録や一覧取得に失敗する | SQLのインポート先、DB接続、`oxmysql`・`ox_lib`・フレームワークの起動状態 |
| 武器・弾薬・キットが付与されない | ox_inventoryの起動状態、アイテム定義、武器リソース、対応する設定名 |
| 復活しても死亡状態が残る | `Config.Ambulance.resource`と`Framework.Revive`の処理が救急システムに合っているか |
| チームのラジオが使えない | pma-voiceの起動状態、`Config.Radio`、支給するラジオアイテム |
| 会場で埋まる・エリア外になる | スポーン座標のZ値、マップの読み込み、`center`・`radius` |
| 再接続時にアリーナへ出る | Qboxの位置保存処理が`gungameNoSave`に対応しているか |

導入後は複数人で開始・死亡・ラウンド切り替え・放棄・帰還・所持品復元を確認してください。1人で確認する場合は一時的に`Config.DebugSolo = true`を使い、確認後に`false`へ戻してください。

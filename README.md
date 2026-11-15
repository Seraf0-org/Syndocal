# Syndocal

Syndocal は、DMX照明とVJ映像を同じタイムライン、キュー、BPMクロック、エフェクトソースで駆動するデスクトップ制御ソフトウェアです。

- 製品名: **Syndocal 1.2.0-rc.1**
- 開発: **Seraf() / KTN**
- プロジェクト: **`.sdc`** (可読JSON)
- Tier 1: Windows 10+ / macOS 12+
- Tier 2: Ubuntu 22.04+ / Arch Linux

## Code signing policy

Windows 1.2.0の公開形式はNSISです。SignPath Foundationへの申請・承認は未完了です。
未署名の配布ではSmartScreenが警告を表示したり、実行ポリシーが起動を止めたりする場合があります。
公開元と公開SHA-256を確認してください。更新ファイルの暗号署名検証は維持します。
詳細は[Code signing policy](qa/CODE_SIGNING_POLICY.md)と
[未署名版のダウンロード確認方法](qa/RELEASE_NOTES_SIGNING.md)を参照してください。

## 主な機能

### 照明

- GDTF読込、GDTF Share検索/取得、簡易カスタム`.fixture`プロファイル
- 8/16bit属性、複数ユニバース、重複/範囲外を防ぐDMXパッチ
- 階層グループ、複数所属、Highlight / Solo / Park、マスター/サブマスター
- Art-Net、sACN/E1.31、Enttec USB PRO、DMXKing ultraDMX、Enttec Open DMX
- LFOと3D位置ウェーブ、エフェクトスタック、共有ノードグラフ
- 灯体、投影面、ステージオブジェクトを扱う実用的な2D Stage Map

### 映像

- HAP / HAP Alpha / HAP Qの直接GPU圧縮テクスチャ経路
- H.264 / H.265 / ProResのインプロセスlibavデコード
- PNG/JPEG、可変速、リバース、A-Bループ、キューポイント、BPM同期
- Layer / Composition / Display Output、Normal / Add / Multiply / Screen合成
- 変形、クロップ、色補正、pixelate / blur / glow / edge / color key
- レイヤーごとに最大8段のordered ISF 2 stack。14種の内蔵FXまたは単一pass ISFを追加し、段別に選択、並べ替え、bypass、reset、削除、parameter操作して`.sdc`へ埋め込み保存
- wgpuネイティブ出力、複数Display、投影比率/keystone/lens/corner warp補正
- 通常Windowsパッケージ（MIT）でNDI®送受信を既定有効化（`Processing.NDI.Lib.x64.dll`および`licenses/Processing.NDI.Lib.Licenses.txt`を同梱し、Priority 1で実行ファイル隣接DLLを解決、Priority 2/3で`NDI_RUNTIME_DIR_V6`..`V2` / `NDI_SDK_DIR` / `C:\Program Files\NDI\NDI 6 Runtime\v6`へフォールバック）。GPL-ASIO（`show-asio`）パッケージからはNDI featureおよびDLLを厳格に除外

### 統合制御

- 照明と映像が混在する共有タイムライン
- 1キューで灯体値、映像Layer、Output、Node Graphを同時リコール
- 1つのLFO/位置ウェーブから灯体属性と映像パラメータを同時駆動
- マイクLive FFTの16 band／RMS／Peak／onset／BPM／kick／snareから照明・映像を同時駆動。WindowsではWASAPI sharedに加え、通常MIT版と分離したASIO bridge featureでdriver／sample rate／fixed buffer／channel mixを明示選択できる。ASIOは製品リリース要件であり、切断／250ms無入力時は共有0クリアを要求し、未受理を明示する。入力の未完了条件は `qa/ASIO_INPUT_ACCEPTANCE.md`、PROGRAM/CUE出力は `qa/ASIO_PROGRAM_CUE_OUTPUT_ACCEPTANCE.md` を参照する
- Tap / MIDI Clock / MTC / LTC / Ableton Link用共有クロック境界
- MIDI、OSC、WebSocket、iPad/Android向けPWAリモート
- 10秒間隔の自動Recovery、Recent Project、`.sdc` OS関連付け

## 画面構成

- **Setup**: Lighting / Video / Mapping / I/Oを分離し、パッチ、灯体プロファイル、出力、投影補正を設定
- **Control**: LIVEでは上段Timeline、左下の常設2D Stage / Groups、右下のSourcesを配置。Stage / Timelineは個別ウィンドウに分離でき、メイン側の残った領域は空白なく再配分。EDIT / MIXERでは同じ一画面枠内で編集・ミキサー面へ切り替え
- **Touch**: タブレットやタッチ操作向けのキュー、灯体、映像操作

アプリ本体は一画面内に固定されます。長い灯体ライブラリやリストだけが各パネル内部でスクロールします。

## インストール

現在の製品バージョンは `1.2.0-rc.1` です。受入状況と未完了条件は [RELEASE_STATUS.md](RELEASE_STATUS.md) を参照してください。

CI/Release成果物は次の形式です。

- Windows: `Syndocal_1.2.0-rc.1_x64-setup.exe` (NSIS)
- macOS: Apple Silicon向け `.pkg`
- Linux: `.deb`、AppImage

### 未署名ビルド

Windowsの現行リリース候補はAuthenticode署名なしです。SignPath Foundationの申請・承認は未完了です。

- Windows SmartScreen: ファイルのプロパティに「ブロックの解除」があれば有効にし、警告画面では発行元とハッシュを確認してから「詳細情報」→「実行」を選択します。
- macOS Gatekeeper: Finderでアプリを右クリックして「開く」、または「システム設定」→「プライバシーとセキュリティ」から対象アプリを許可します。

正式な公開配布ではWindows Authenticode証明書とApple Developer ID/Notarizationが必要です。秘密鍵や署名資格情報はリポジトリに保存しません。

## 最初の操作

1. Project menu (`...`) から **Sample** を開きます。
2. Setup / PatchでMini Spot 1、DMX U0 Address 1、2D Mappingを確認します。
3. Setup / I/O / DMXでArt-Net loopback `127.0.0.1:6454` または実機出力を設定します。
4. Controlで灯体を選択し、Dimmer/Color/Positionを操作します。
5. TimelineまたはGOで、照明と映像が同じキューから変化することを確認します。
6. Project menuから`.sdc`として保存します。

Project menuの`UI language`からEnglish／Japaneseを切り替えられます。選択は端末設定として保存され、`.sdc`には混在しません。

Timelineの論理スナップ間隔とズーム適応ルーラーは別の設定です。新規セッションは`Grid 500 ms`とScene端磁着を有効にして開始し、ルーラーだけが表示倍率に応じて細分化されます。ホイール、Undo/Redoを含む操作一覧は [HOTKEYS.md](HOTKEYS.md) を参照してください。

同梱サンプルの詳細は [samples/README.md](samples/README.md)、キー操作は [HOTKEYS.md](HOTKEYS.md) を参照してください。

## プロジェクトとプリセット

- `.sdc`: ショー全体。灯体、埋め込みカスタムプロファイル、キュー、タイムライン、映像、出力、Stage Mapを保存
- `.fixture`: 簡易灯体プロファイル
- `.preset`: 灯体属性スナップショット
- `.effect`: LFO/位置ウェーブ
- `.nodegraph`: エフェクトノードグラフ
- `.projmap`: プロジェクター補正
- `.midimap` / `.oscmap`: MIDI / OSCコントロールマッピング共有
- `.sdctemplate`: ショー構成、埋め込みプロファイル、MIDI / OSCマッピングをまとめたユーザーテンプレート。読込時は全出力を無効化

`.sdc` v1は未知フィールドを読み飛ばし、後から追加された省略可能項目を既定値で補完します。将来versionは暗黙変換せず、対応外として明示的に拒否します。

## 開発

必要環境:

- Rust stable (`rust-toolchain.toml`で安定版チャネルを指定)
- Node.js 22
- pnpm 10.9
- FFmpeg開発/共有ライブラリ (一般動画のlibav build)
- 各OSのTauri 2ビルド依存

```powershell
pnpm --dir app install --frozen-lockfile
cargo test --workspace --locked
pnpm --dir app build
pnpm --dir app tauri dev
```

軽量チェック:

```powershell
pnpm --dir app run check:release
pnpm --dir app run check:project-storage
pnpm --dir app run check:release-ui:browser
```

実ウィンドウを含むUIリリース受入（Windowsでは最大化→F11フルスクリーン→Esc復帰を自動検証）:

```powershell
pnpm --dir app run check:release-ui
```

リリース:

```powershell
pnpm --dir app tauri build --ci --bundles nsis
```

Windowsでは [ネイティブビルド手順](qa/WINDOWS_NATIVE_BUILD.md) に従い、固定されたFFmpeg SDKとMSVCを使用します。実行時ファイルは [inventory](qa/FFMPEG_WINDOWS_RUNTIME_INVENTORY.json) のサイズ・SHA-256・PE identityに一致する必要があります。通常Windows版はライセンス済みNDI runtimeを同梱し、別配布のGPL-ASIO構成からNDIを除外します。

ASIOはWindows製品のリリース要件です。通常MITパッケージにはASIO bridgeを含めず、独立したライセンス・配布境界を維持します。[SDK pin](qa/ASIO_SDK_PIN.json)、[入力受入](qa/ASIO_INPUT_ACCEPTANCE.md)、[PROGRAM/CUE出力受入](qa/ASIO_PROGRAM_CUE_OUTPUT_ACCEPTANCE.md)を参照してください。

## 既知の制限

- v1.0以降の外部映像I/OはDisplay、feature-gated NDI、Windows x86_64のSpoutに対応しています。macOSのSyphon送受信は実装されていますが、外部クライアントとの実機受入は未完了です。
- HAP Q Alpha、HAP R/BC7のGPU直接sampling + CPU fallback、安全境界付き最大8段のordered single-pass ISF stackは実装済みです。1 stackのsource合計は512 KiB、1段16 control、project内ISF source合計16 MiB、`.sdc`全体64 MiBに制限します。ISF multipass／persistent buffer／imported resource／audio input、100種級library、shared texture／任意node graph、headless readback後のnative別device再upload解消、4K multi-layer／実会場long soakは未対応または未受入です。
- Live FFT入力はCPALのdevice catalogとcapabilityを読み、Windowsの既定buildではWASAPI sharedのsystem defaultまたは列挙device、sample rate、requested buffer、全channel平均／単一channel／stereo pair downmixを選べます。選択rateごとにchannel数／sample format／buffer capabilityを`resolved_config`として先に確定し、Startでも同じ構成を再検証します。更新世代に結び付くopaque device IDを使い、古い／未知IDや非対応構成は別device・rate・bufferへ黙ってfallbackせずStartを拒否します。全11種のCPAL PCM sample formatを正規化し、通常data callbackは4本×2048-frameの事前確保slotへallocation-freeで格納します。workerは16対数band、RMS／Peak、spectral flux、適応onset、60–200 BPM／confidence／beat phase、centroid／density／kick／snareを生成し、同じframeから旧Node Graph用B/M/Hを派生します。Compiled Audio Reactive Rackは任意の対応照明属性／映像parameterへこれらを割り当て、Auto VJはCLOCKまたはLIVE INPUTのonsetを選び、seed／show revision／candidate順から決定的にTakeします。非既定のWindows ASIO featureは独立bridgeを動的loadし、明示driver／rate／channel／native format／fixed bufferをStart時に再検証、実buffer framesとbackend XRUNを表示します。ASIOの実機matrix、長時間運用、fault recovery、配布ライセンスの受入は未完了です。通常MIT installerへASIO bridgeは同梱しません。
- Device Refresh後はbackendとdevice名が新旧catalogueの双方で一意な場合だけ明示選択を新IDへ引き継ぎます。曖昧・消失時はsystem defaultへ黙って落とさず、再選択するまでcapabilityを破棄してStartをロックします。
- 3Dビジュアライザは本体UIへ戻さず、`visualizer`データ境界から外部実装へ接続します。標準UIは2D Stage Mapです。
- Enttec Open DMXはOS/USBドライバ依存のbreak timingがあるため、最終現場ではUSB PRO系を推奨します。
- Art-Net/sACN/Serialの実機遅延は接続機材ごとに再測定してください。リポジトリの自動検証はloopback中心です。
- NDI SDK、コード署名、macOS notarizationは配布ライセンス/資格情報が必要で、リポジトリには含みません。

## ライセンス

Syndocal本体は[MIT License](LICENSE)です。一般動画デコード用の配布物は、
GPLコンポーネントを無効化したFFmpeg 8.1共有ライブラリを動的リンクします。
詳細とLGPLv3本文は[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)を参照してください。

### NDI® 商標・ライセンス表記 (Ordinary Windows Package)

NDI® is a registered trademark of Vizrt NDI AB.

- NDI® 公式サイト: <https://ndi.video/>
- NDI® Tools (無償テスト・監視ツール): <https://ndi.video/tools/>
- NDI® SDK Licensing: <https://docs.ndi.video/all/developing-with-ndi/sdk/licensing>
- NDI® SDK Windows Installation & Redistribution: <https://docs.ndi.video/all/developing-with-ndi/sdk/installing-the-sdk/windows-installation>
- NDI® SDK License Agreement: `http://ndi.link/ndisdk_license`
- NDI® 6 Runtime Redistributable: `http://ndi.link/NDIRedistV6`

通常版のWindowsインストーラー（MITパッケージ）は、NDI® SDK License Agreementに基づき`Processing.NDI.Lib.x64.dll`（NDI 6.3.2.0）および`licenses/Processing.NDI.Lib.Licenses.txt`を同梱しています。GPLv3の`show-asio`パッケージには`ndi` featureおよび`Processing.NDI.Lib.x64.dll`を一切含めません。操作方法の詳細は[USER_GUIDE.md](USER_GUIDE.md)を参照してください。

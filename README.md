# esp32WifiConnect

Windows の標準機能だけで、ESP32 の SoftAP（APモード）へ簡単に接続するためのツール設計（バッチ・HTML/HTA ベース）。

## 概要
- 周辺の Wi‑Fi をスキャンして、指定したプレフィックスの SSID（例: ESP32-）を検出。
- 検出した AP に接続し、ESP32 の IP（デフォルト: 192.168.4.1）を表示。
- 追加ランタイム不要：Windows に標準である netsh / mshta / cmd / PowerShell を使用。

## 実行モード（2通り）
1. バッチモード（.bat）
   - 純粋なバッチスクリプトで netsh を呼び出してスキャン・接続・切断を行う。
   - 実行方法：`connect.bat` をダブルクリックで実行。
   - 長所：追加ソフト不要、軽量。短所：表示や操作が簡素。

2. HTML（HTA）モード
   - Windows の mshta.exe で動く HTA（HTML Application）で簡易 GUI を提供。
   - HTML + JavaScript（または VBScript）からコマンド実行して結果を表示できる（ブラウザでなく mshta で開く）。
   - 実行方法：`ui.hta` をダブルクリック（または `mshta.exe ui.hta`）。
   - 長所：見た目がわかりやすく操作が簡単。短所：IE 系の HTA 実行になる点に留意。

## 設計とファイル
推奨リポジトリ構成（最小）
- config.json            # 設定（git 管理外にすること推奨: config.local.json）
- connect.bat            # バッチ版ランチャー（スキャン→選択→接続）
- scan.bat               # AP スキャン（SSID一覧を出力）
- disconnect.bat         # 切断用
- ui.hta                 # HTA（HTML）版 GUI
- README.md

設定例（config.json）
{
  "ssid_prefix": "ESP32",
  "ap_password": "",
  "esp32_ip": "192.168.4.1",
  "scan_interval_sec": 5
}

- ssid_prefix: ESP32 の SSID を判定するプレフィックス
- ap_password: 空なら接続時に入力を促す
- esp32_ip: 接続後にアクセスする IP（通常 192.168.4.1）

## バッチモード：簡易使い方
1. config.json を編集（または config.local.json を作成して上書き）。
2. コマンドプロンプトで `connect.bat` を実行。
3. スキャン結果（SSID/RSSI）から番号で選択 → 必要ならパスワード入力 → 接続。
4. 接続後に ESP32 の IP を表示。

内部では `netsh wlan show networks mode=bssid` でスキャンし、`netsh wlan connect name="プロファイル名"` 等で接続します。

## HTA（HTML）モード：簡易使い方
1. config.json を編集。
2. `ui.hta` をダブルクリックして起動。
3. 「スキャン」ボタンで周辺 AP を一覧表示、選んで「接続」。
4. 接続完了後に ESP32 の IP を画面に表示。

HTA 内では JavaScript/VBScript で `WScript.Shell` を使い netsh コマンドを実行し、出力をパースして画面に反映します（mshta が標準で利用可）。

## 注意・制約
- 対象 OS: Windows 10 / 11（netsh, mshta が利用可能であること）。
- ESP32 は SoftAP モードで起動していること。
- 基本的に 1 台の ESP32 を想定（複数台同時接続は簡易実装では非対応）。
- ローカル AP 接続のみ（インターネット接続は行わない）。

## セキュリティ
- 設定ファイルにパスワードを平文で保存する場合はローカル限定にし、リポジトリへコミットしないでください。
- `config.local.json` を .gitignore に入れて運用してください。

## 将来拡張（参考）
- PowerShell GUI（WinForms/WinUI）での改良版
- ネイティブ exe（PyInstaller など）での配布
- macOS / Linux 向けスクリプトの追加

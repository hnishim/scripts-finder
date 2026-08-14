# GDrive File Locker

Finder で選択したファイル/フォルダを、rclone の認証を使い回して Drive API の `contentRestrictions`（readOnly）で編集ロックする shell スクリプト（Automator クイックアクション）。

## 前提

- rclone で全共有ドライブを `AllDrives:`（combine remote）として `~/mnt/gdrive` にマウント済み・自前の Google OAuth クライアント（scope=`drive`）で認証済み
- `jq` をインストール済み（`brew install jq`）。curl は macOS 標準
- Finder のクイックアクション（サービス）として登録し、`~/mnt/gdrive` 配下のファイル/フォルダを右クリックして使う
- Automator ワークフローの保存先: `~/Library/Services/<アクション名>.workflow`
- ロック対象の共有ドライブで**コンテンツ管理者以上**の権限

## 意図・背景

- 共有ドライブ上の完成版ファイル（例: 計画書 pptx）を誤編集・上書きから守るため、まとめて読み取り専用にしたい
- 認証は **rclone の refresh_token を流用して一本化**（Python / credentials.json / token.json / pyperclip は不要）。GDrive Link Copier などと同じ rclone 認証を使うので二重認証が起きない

## 使い方

1. `~/mnt/gdrive` 配下のファイル/フォルダを右クリック →「GDrive ロック」等のクイックアクションを実行
2. フォルダを選ぶと配下を**再帰的に**ロック
3. 結果は通知に「ロック成功 / スキップ / 失敗」の件数で表示

## 仕組み

1. `rclone config dump` から client_id / client_secret / refresh_token を取り出し、Google の token endpoint で access_token を都度発行（約1時間有効・保存しない）
2. 選択物がフォルダなら `rclone lsf -R --files-only --format i` で配下の全ファイルIDを再帰取得。ファイルなら親を `rclone lsf` して名前一致でID取得（同名が複数ある場合は誤ロック防止でスキップ）
3. 各IDへ `contentRestrictions:[{readOnly:true}]` を Drive API に PATCH（`429`・`5xx` は指数バックオフで最大3回リトライ）

## 注意

- 依存は **jq / curl / rclone**。起動時に存在チェックし、無ければ通知して終了（curl は macOS 標準搭載）
- 結果判定: `2xx`=成功 / `403`・`400`=スキップ（権限なし・ロック非対応=フォーム/サイト/Apps Script/ショートカット等）/ `429`・`5xx`=指数バックオフで最大3回リトライ後も失敗ならログ記録 / それ以外=失敗としてログに記録
- マウント直下ファイルの `dir="."` は空へ正規化。ファイル名照合の `awk` は `ENVIRON` 経由（`-v` のエスケープ解釈バグ回避）で、同名複数はスキップ
- `/bin/bash`（macOS標準は3.2）互換のため連想配列は不使用
- 既にロック済みでも 200 が返るため成功扱い（実害なし）
- OAuth アプリが「テスト中」のままだと rclone の refresh_token も約7日で失効。Internal もしくは公開済みにすれば無期限
- xattr の内部IDではなく rclone 経由の実ファイルIDを使う（xattr の item-id は共有URL用IDと別物）

## メモ

- 大量ファイルを含む巨大フォルダのロックでは access_token（約1時間有効）が処理中に失効し得る。途中から `401` で失敗するので、フォルダを分割して実行するか、トークン再発行ロジックの追加を検討
- ロック解除が必要なら `contentRestrictions:[{readOnly:false}]` を PATCH する版を別途用意すればよい
- 事前の capabilities チェックはせず PATCH の HTTP コードで判定している。詳細ログや事前チェックが欲しい場合は旧 Python 方式が参考になる
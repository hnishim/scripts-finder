# GDrive Link Copier

選択した Google Drive ファイル／フォルダの共有URL（ファイルは `https://drive.google.com/open?id=...`、フォルダは `https://drive.google.com/drive/folders/...`）をクリップボードにコピーする Automator クイックアクション。

## 前提

- rclone で全共有ドライブを `AllDrives:`（combine remote）として `~/mnt/gdrive` にマウント済み
- rclone は自前の Google OAuth クライアント（scope=drive）で認証済み
- Finder のクイックアクション（サービス）として登録し、`~/mnt/gdrive` 配下のファイルを右クリックして使う
- Automator ワークフローの保存先: `~/Library/Services/<アクション名>.workflow`

## 意図・背景

- Commander One / Finder から、共有ドライブ上ファイルの共有リンクを一発で取得したい
- Google Drive for desktop の拡張属性 `com.google.drivefs.item-id` は DriveFS の内部IDで、共有URL用の実ファイルIDとは**別物**なので使えない。→ rclone から実ファイルIDを取得している

## 仕組み

1. 選択パスをマウントルートからの相対パスに変換
2. 親ディレクトリを `rclone lsf` して、名前一致で実ID（ファイル／フォルダ）を取得（直近ディレクトリの列挙結果はキャッシュ。同名が複数ある場合は特定不可として通知・スキップ）
3. ファイルは `https://drive.google.com/open?id=<ID>`、フォルダは `https://drive.google.com/drive/folders/<ID>` を組み立て、複数選択時は改行区切りでまとめて最後に一度だけ `pbcopy`（従来は上書きで最後の1件のみ残っていた）

## 注意

- マウント配下のファイルのみ対象（それ以外は通知して無視）
- ファイル・フォルダ両対応（`-d` でフォルダ判定し、フォルダは `--dirs-only`＋末尾 `/` で照合して `drive/folders/<ID>` をコピー）
- 複数選択時は全URLを改行区切りでまとめてコピー（以前はループ内で上書きされ最後の1件のみ残っていた）
- 同一フォルダ内に同名が複数あるとID特定不可のため、通知して当該項目をスキップ（名前照合の原理的限界）
- `rclone` 実行ファイルが見つからない場合は通知して終了
- `/bin/bash`（macOS標準は3.2）で動くよう連想配列を避け、直近1ディレクトリのみキャッシュ
- **リンク生成のみで共有権限は変更しない**。相手が開けるかは別途の共有設定に依存
- 対になるスクリプト: ブラウザで開く版は **GDrive Opener**
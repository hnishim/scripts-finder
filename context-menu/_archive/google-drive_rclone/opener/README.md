# GDrive Opener

選択した Google Drive ファイル／フォルダの共有URL（ファイルは `https://drive.google.com/open?id=...`、フォルダは `https://drive.google.com/drive/folders/...`）を既定ブラウザで開く Automator クイックアクション。GDrive Link Copier の `open` 版。

## 前提

- rclone で全共有ドライブを `AllDrives:`（combine remote）として `~/mnt/gdrive` にマウント済み
- rclone は自前の Google OAuth クライアント（scope=drive）で認証済み
- Finder のクイックアクション（サービス）として登録し、`~/mnt/gdrive` 配下のファイルを右クリックして使う
- Automator ワークフローの保存先: `~/Library/Services/<アクション名>.workflow`

## 意図・背景

- ローカルにマウントした共有ドライブ上のファイルを、Web版 Google Drive/ドキュメントで素早く開きたい
- xattr の内部IDは共有URL用の実IDと別物なので使えない。→ rclone から実ファイルIDを取得している

## 仕組み

1. 選択パスをマウントルートからの相対パスに変換
2. 親ディレクトリを `rclone lsf` して、名前一致で実ID（ファイル／フォルダ）を取得（直近ディレクトリの列挙結果はキャッシュ。同名が複数ある場合は特定不可として通知・スキップ）
3. ファイルは `https://drive.google.com/open?id=<ID>`、フォルダは `https://drive.google.com/drive/folders/<ID>` を `open` でブラウザ起動

## 注意

- マウント配下のファイルのみ対象（それ以外は通知して無視）
- ファイル・フォルダ両対応（`-d` でフォルダ判定し、フォルダは `--dirs-only`＋末尾 `/` で照合して `drive/folders/<ID>` を開く）
- 同一フォルダ内に同名が複数あるとID特定不可のため、通知して当該項目をスキップ（名前照合の原理的限界）
- `rclone` 実行ファイルが見つからない場合は通知して終了
- 同一フォルダ内の複数選択では列挙結果をキャッシュし `rclone` 呼び出しを削減
- `/bin/bash`（macOS標準は3.2）で動くよう連想配列を避け、直近1ディレクトリのみキャッシュ
- URL をコピーしたい場合は **GDrive Link Copier** を使う
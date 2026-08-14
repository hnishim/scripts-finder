# GDrive Word Editor

rclone マウント上の Office ファイル（主に Word）を、ローカルへ取得 → Word で開く → 保存の度に自動で Drive へ書き戻し、閉じたら後始末する Automator クイックアクション。**衝突検知つき**。Google Drive for desktop 純正の「Open with → Microsoft Word.app」を rclone だけで模したもの。

## 前提

- rclone で全共有ドライブを `AllDrives:`（combine remote）として `~/mnt/gdrive` にマウント済み
- rclone は自前の Google OAuth クライアント（scope=drive）で認証済み
- 依存コマンド: **`jq`** と **`fswatch`**（未導入なら `brew install jq fswatch`）。curl は不要
- Microsoft Word がローカルにインストール済み
- Finder のクイックアクション（サービス）として登録し、`~/mnt/gdrive` 配下のファイルを右クリックして使う
- Automator ワークフローの保存先: `~/Library/Services/<アクション名>.workflow`

## 意図・背景

- rclone の NFS マウント上では **Word for Mac だけがファイルロックを取れず read-only で開く**（Excel / PowerPoint は編集できる）。原因は NFS のロック挙動
- Google Drive for desktop 純正の「Open with → Microsoft Word.app」（＝ローカルに開いて保存を同期）を、**rclone だけで模した**もの
- Drive for desktop の CloudStorage マウントや、Drive API 専用の認証（`credentials.json` / `token.json`）に依存せず、**rclone の認証を流用**（`lsjson` / `copyto`）して完結する。将来 Drive for desktop をアンインストールしても動く
- 旧 Python 版（Drive API + CloudStorage パス生成 + クリップボード）を置き換える位置づけ

## 仕組み

1. 選択パスをマウントルートからの相対パスに変換し、`rclone copyto` でローカル（`~/.gdrive-edit`）へダウンロード
2. Word で開く。**ダウンロード時点のリモート更新時刻（ModTime）を記録**
3. `fswatch` がローカルの保存を検知するたびに、`rclone copyto` で Drive へ書き戻し（毎回ファイル全体をアップロード）
4. Word のロックファイル（`~$name`）が消えたら「閉じた」と判定 → 最終同期して一時ファイルを削除

## 衝突検知

- 書き戻す**前に**リモートの ModTime を再取得し、記録値と違えば「他者がリモートを更新した」と判断
- その場合は**上書きせず**、同じフォルダに `名前 (conflict 日時).拡張子` として退避し通知 → **データ消失を防ぐ**
- 自分のアップロード後は、新しい ModTime を基準に更新（自分の書き込みを衝突と誤判定しない）
- あくまで**単独編集前提の簡易ロック**。Drive for desktop のような厳密な常時双方向同期ではない

## 注意

- 依存は `jq` と `fswatch` のみ。待機中の負荷は**ほぼ0**（動くのは保存の瞬間と10秒ごとの軽い存在チェックだけ。`lsof` の全プロセス走査は不使用）
- ロックファイル名は Word のバージョンで `~$` の後を数文字削ることがある。判定がシビアなら glob 照合（`~$*` 系）に変更する
- 保存の度にファイル全体をアップロードするため、巨大ファイルの高頻度保存では通信量が増える（通常の `.docx` なら誤差）
- Excel / PowerPoint でも使えるが、それらは元々 read-only にならないので**主対象は Word**

## 対になるスクリプト

- 共有リンクの取得: **GDrive Link Copier**
- ブラウザで開く: **GDrive Opener**
- ファイルのロック: **GDrive File Locker**
#!/bin/bash
# GDrive Word Editor: rclone上のOfficeファイルをローカルへ取得→Wordで開く→
# 保存の度に書き戻し、閉じたら後始末。衝突検知つき。

set -uo pipefail
MOUNT="$HOME/mnt/gdrive"
REMOTE="AllDrives:"
RCLONE="/opt/homebrew/bin/rclone"
WORK="$HOME/.gdrive-edit"; mkdir -p "$WORK"

notify(){ osascript -e "display notification \"$1\" with title \"GDrive Edit\""; }
remote_mtime(){ "$RCLONE" lsjson "$REMOTE$1" 2>/dev/null | jq -r '.[0].ModTime // empty'; }

for f in "$@"; do
  rel="${f#"$MOUNT"/}"
  [ "$rel" = "$f" ] && { notify "マウント外です"; continue; }
  base=$(basename "$rel"); dir=$(dirname "$rel")
  tmp="$WORK/$base"; lock="$WORK/~\$$base"; kf="$WORK/.known.$base"

  "$RCLONE" copyto "$REMOTE$rel" "$tmp" || { notify "DL失敗: $base"; continue; }
  remote_mtime "$rel" > "$kf"          # ダウンロード時点のリモート更新時刻を記録
  open -a "Microsoft Word" "$tmp"
  notify "編集中: $base（保存で自動反映）"

  (
    push(){
      local cur known
      cur=$(remote_mtime "$rel"); known=$(cat "$kf" 2>/dev/null)
      if [ -n "$cur" ] && [ "$cur" != "$known" ]; then
        # 誰かがリモートを更新 → 上書きせず衝突コピーを退避
        local stamp cfile
        stamp=$(date +%Y%m%d-%H%M%S)
        cfile="${base%.*} (conflict $stamp).${base##*.}"
        "$RCLONE" copyto "$tmp" "$REMOTE$dir/$cfile"
        notify "⚠️衝突: リモートが変更済。$cfile として退避しました"
        return 1
      fi
      "$RCLONE" copyto "$tmp" "$REMOTE$rel" || { notify "アップロード失敗"; return 1; }
      remote_mtime "$rel" > "$kf"       # 自分のアップ後の時刻を新しい基準に
      notify "反映: $base"
    }

    # 保存イベントで書き戻し（fswatch: イベント駆動・待機中CPUほぼ0）
    fswatch -o "$tmp" | while read -r _; do push; done &
    fswpid=$!

    # 閉じたら（ロックファイル消失）終了。軽いstatを10秒間隔で
    while :; do
      sleep 10
      [ -e "$lock" ] || { sleep 2; [ -e "$lock" ] || break; }
    done

    kill "$fswpid" 2>/dev/null
    push                                 # 最終同期
    rm -f "$tmp" "$kf"
  ) >/dev/null 2>&1 &
done
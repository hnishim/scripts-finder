#!/bin/bash
MOUNT="$HOME/mnt/gdrive"
REMOTE="AllDrives:"
RCLONE="/opt/homebrew/bin/rclone"

for f in "$@"; do
  rel="${f#"$MOUNT"/}"
  if [ "$rel" = "$f" ]; then
    osascript -e 'display notification "マウント外のファイルです" with title "GDrive Link"'
    continue
  fi
  dir=$(dirname "$rel"); base=$(basename "$rel")
  if [ -d "$f" ]; then
    # フォルダ：rclone lsf は末尾に "/" を付けるので base に "/" を足して照合
    id=$("$RCLONE" lsf --format "pi" --dirs-only --separator $'\t' "$REMOTE$dir" 2>/dev/null \
          | awk -F'\t' -v b="$base/" '$1==b{print $2; exit}')
    url="https://drive.google.com/drive/folders/$id"
  else
    id=$("$RCLONE" lsf --format "pi" --files-only --separator $'\t' "$REMOTE$dir" 2>/dev/null \
          | awk -F'\t' -v b="$base" '$1==b{print $2; exit}')
    url="https://drive.google.com/open?id=$id"
  fi
  if [ -n "$id" ]; then
    open "$url"
  else
    osascript -e 'display notification "IDが取得できません" with title "GDrive Link"'
  fi
done
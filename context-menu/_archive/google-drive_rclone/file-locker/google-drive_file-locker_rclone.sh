#!/bin/bash
MOUNT="$HOME/mnt/gdrive"
REMOTE="AllDrives:"
RCLONE="/opt/homebrew/bin/rclone"
CONF_REMOTE="gdrive"     # トークンを持つベースremote名
REASON="Locked by automated script"
LOG="$HOME/Library/Logs/gdrive-file-locker.log"

# --- 1. rclone の認証情報からアクセストークンを取得（認証はこれ1つ） ---
dump=$("$RCLONE" config dump 2>>"$LOG")
cid=$(jq -r ".\"$CONF_REMOTE\".client_id"     <<<"$dump")
csec=$(jq -r ".\"$CONF_REMOTE\".client_secret" <<<"$dump")
rtok=$(jq -r ".\"$CONF_REMOTE\".token | fromjson | .refresh_token" <<<"$dump")

access_token=$(curl -s https://oauth2.googleapis.com/token \
  -d client_id="$cid" -d client_secret="$csec" \
  -d refresh_token="$rtok" -d grant_type=refresh_token \
  | jq -r .access_token)

if [ -z "$access_token" ] || [ "$access_token" = "null" ]; then
  osascript -e 'display notification "認証トークン取得に失敗" with title "File Locker"'
  exit 1
fi

# --- 2. ロック関数（Drive API に PATCH） ---
ok=0; skip=0; fail=0
lock_one() {
  local id="$1"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH \
    "https://www.googleapis.com/drive/v3/files/$id?supportsAllDrives=true" \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    --data "{\"contentRestrictions\":[{\"readOnly\":true,\"reason\":\"$REASON\"}]}")
  case "$code" in
    2*) ok=$((ok+1)) ;;
    403|400) skip=$((skip+1)) ;;   # 権限なし/ロック非対応など
    *) fail=$((fail+1)); echo "PATCH $id -> $code" >>"$LOG" ;;
  esac
}

# --- 3. 選択物からIDを解決してロック（フォルダは配下を再帰） ---
for f in "$@"; do
  rel="${f#"$MOUNT"/}"
  [ "$rel" = "$f" ] && continue          # マウント外は無視
  if [ -d "$f" ]; then
    # フォルダ配下の全ファイルIDを rclone で再帰取得
    while IFS= read -r id; do
      [ -n "$id" ] && lock_one "$id"
    done < <("$RCLONE" lsf -R --files-only --format i "$REMOTE$rel" 2>>"$LOG")
  else
    dir=$(dirname "$rel"); base=$(basename "$rel")
    id=$("$RCLONE" lsf --format "ip" --separator $'\t' "$REMOTE$dir" 2>>"$LOG" \
         | awk -F'\t' -v b="$base" '$2==b || $2==b"/"{print $1; exit}')
    [ -n "$id" ] && lock_one "$id"
  fi
done

osascript -e "display notification \"ロック成功:$ok スキップ:$skip 失敗:$fail\" with title \"File Locker\""
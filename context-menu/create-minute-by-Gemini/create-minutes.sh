#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_DIR="${SCRIPT_DIR}/python"
PYTHON_RUNNER="${PYTHON_DIR}/run.sh"

# Finder/Automatorから起動した場合もログインシェルのAPIキー設定を引き継ぐ。
if [ -z "${GEMINI_API_KEY_FOR_MINUTES:-}" ]; then
    GEMINI_API_KEY_FOR_MINUTES="$(/bin/zsh -lc 'printf %s "$GEMINI_API_KEY_FOR_MINUTES"')"
fi
export GEMINI_API_KEY_FOR_MINUTES

if [ -z "${GEMINI_API_KEY_FOR_MINUTES}" ]; then
    osascript -e 'display notification "GEMINI_API_KEY_FOR_MINUTESが設定されていません。" with title "議事録作成エラー" sound name "Basso"'
    exit 1
fi

if [ ! -x "${PYTHON_RUNNER}" ]; then
    osascript -e 'display notification "議事録作成用の実行スクリプトがありません。" with title "議事録作成エラー" sound name "Basso"'
    exit 1
fi

if [ "$#" -eq 0 ]; then
    osascript -e 'display notification "ファイルが選択されていません。" with title "議事録作成エラー" sound name "Basso"'
    exit 1
fi

SELECTED_LANGUAGE=$(
    osascript -e '
        display dialog "議事録の言語を選択してください:" buttons {"日本語", "英語"} default button "日本語" with title "言語選択"
        set button_pressed to button returned of result
        if button_pressed is "日本語" then
            return "ja"
        else if button_pressed is "英語" then
            return "en"
        else
            return ""
        end if
    '
)

if [ -z "${SELECTED_LANGUAGE}" ]; then
    osascript -e 'display notification "言語選択がキャンセルされました。" with title "議事録作成キャンセル" sound name "Basso"'
    exit 1
fi

declare -a FILE_PATHS=()
for file in "$@"; do
    filename=$(basename -- "$file")
    if [[ ! "$filename" =~ ^202 ]]; then
        current_date=$(date "+%Y%m%d")
        new_file="$(dirname "$file")/${current_date}_${filename}"
        mv "$file" "$new_file" || exit 1
        FILE_PATHS+=("$new_file")
    else
        FILE_PATHS+=("$file")
    fi
done

osascript -e 'display notification "議事録の作成を開始します。" with title "議事録作成：開始"'

if "${PYTHON_RUNNER}" "${SELECTED_LANGUAGE}" "${FILE_PATHS[@]}"; then
    osascript -e 'display notification "議事録の作成が完了しました。" with title "議事録作成：完了" sound name "Glass"'
else
    osascript -e 'display notification "議事録の作成中にエラーが発生しました。" with title "議事録作成：エラー" sound name "Basso"'
    exit 1
fi

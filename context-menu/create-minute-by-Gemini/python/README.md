# Gemini APIでmp3から議事録を自動生成

## 概要
mp3音声ファイルをGoogle Gemini APIで直接処理し、議事録（要約）を自動生成するPythonスクリプトです。

## 必要要件
- Python 3.8以上
- Google Gemini APIのAPIキー（環境変数`GEMINI_API_KEY_FOR_MINUTES`に設定）
- `prompt.md`（スクリプトと同じディレクトリに配置）

## インストール

```bash
./setup.sh
```

## 使い方

```bash
./run.sh ja 入力ファイル.mp3
```

- 第1引数は出力言語（`ja`または`en`）、第2引数以降は入力mp3ファイルです。
- 入力ファイルと同じディレクトリに、拡張子を`.md`へ変えた議事録を出力します。

## 注意事項
- mp3ファイルは20MB未満を推奨します。
- API利用料・トークン制限に注意してください。
- `prompt.md`は、`Dev/prompts/gemini-gems/NotebookLM_create-minutes.md`へのシンボリックリンクです。
- 仮想環境は各Macの `~/Library/Application Support/com.hnishim.create-minute-by-gemini` に作成されます。

## 依存パッケージ
- google-genai

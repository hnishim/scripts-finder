import os
from google import genai

# === 設定 ===
API_KEY = os.getenv('GEMINI_API_KEY_FOR_MINUTES')  # 環境変数からAPIキー取得
MODEL_NAME = "gemini-3.5-flash"


# === 議事録生成（mp3を直接Geminiに渡す） ===
def generate_minutes_with_audio(lang, mp3_path):
    prompt_file = os.path.join(os.path.dirname(__file__), "prompt.md")
    if not os.path.exists(prompt_file):
        raise FileNotFoundError(f"プロンプトファイルが見つかりません: {prompt_file}")
    with open(prompt_file, "r", encoding="utf-8") as f:
        prompt = f.read().strip()
    prompt = prompt.replace(
        "日本語 英語",
        {"en": "英語", "ja": "日本語"}.get(lang, "不明"),
    )

    client = genai.Client(api_key=API_KEY)
    uploaded_file = client.files.upload(file=mp3_path)
    response = client.models.generate_content(
        model=MODEL_NAME,
        contents=[prompt, uploaded_file],
    )
    return response.text


# === メイン処理 ===
def main(lang, input_mp3):
    if not API_KEY:
        raise RuntimeError("GEMINI_API_KEY_FOR_MINUTESが設定されていません。")
    print("議事録を生成中...")
    minutes = generate_minutes_with_audio(lang, input_mp3)
    mp3_dir = os.path.dirname(input_mp3)
    mp3_base = os.path.splitext(os.path.basename(input_mp3))[0]
    txt_path = os.path.join(mp3_dir, mp3_base + ".md")
    with open(txt_path, "w", encoding="utf-8") as f:
        f.write(minutes)
    print(f"{txt_path} に議事録を出力しました。")


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("使い方: python createMinuteByGemini.py 言語(ja,en) 入力mp3ファイルパス")
        raise SystemExit(1)
    main(sys.argv[1], sys.argv[2])

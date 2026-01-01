#!/usr/bin/env python3
"""
cefr_tagger_v3_json.py - JSON forced output & Safety filters OFF
"""

import os
import sys
import csv
import time
import json
from pathlib import Path

try:
    from google import genai
    from google.genai import types
except ImportError:
    print("❌ pip install google-genai")
    sys.exit(1)

# 경로 설정 (본인 환경에 맞게)
BASE_DIR = Path("/Users/taewoo/Documents/ALP")
INPUT_FILE = BASE_DIR / "ArabicLearning/ArabicLearning/Resources/curriculum_data.csv"
OUTPUT_FILE = BASE_DIR / "curriculum_data_sorted.csv"

BATCH_SIZE = 50 # JSON 모드는 정확해서 50개도 거뜬함
MODEL_NAME = "gemini-2.5-flash" # 2.5가 아직 불안정하면 2.0 Flash 권장 (혹은 1.5 Flash)

def load_vocabulary():
    vocab = []
    if not INPUT_FILE.exists():
        print(f"❌ File not found: {INPUT_FILE}")
        sys.exit(1)
        
    with open(INPUT_FILE, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            word = row.get('arabic_word', '')
            meaning = row.get('meaning_korean', '')
            if word:
                vocab.append({
                    'arabic_word': word,
                    'meaning_korean': meaning,
                    'root': row.get('root', ''),
                    'verb_form': row.get('verb_form', '0'),
                    'pattern': row.get('pattern', ''),
                    'example_sentence': row.get('example_sentence', ''),
                    'cefr': 'B1' # 기본값
                })
    return vocab

def tag_batch_json(client, words: list) -> list:
    """Tag batch using JSON Schema enforcement"""
    
    # 입력 데이터 준비
    word_list_prompt = "\n".join([f"- {w['meaning_korean']} ({w['arabic_word']})" for w in words])
    
    prompt = f"""
    Act as an Arabic CEFR Expert.
    Classify the CEFR level (A1, A2, B1, B2, C1) for the following Arabic words based on their meaning and frequency.
    
    Guidelines:
    - A1: Very Basic (Family, Colors, Numbers, Basic Verbs)
    - A2: Elementary (Daily routine, Weather, Common objects)
    - B1: Intermediate (Abstract, Work, Feelings)
    - B2/C1: Advanced (Political, Academic, Rare)
    
    Words to classify:
    {word_list_prompt}
    """

    try:
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
            config=types.GenerateContentConfig(
                # 1. JSON 응답 강제
                response_mime_type="application/json",
                response_schema=list[str], # ["A1", "A2", ...] 형태 강제
                
                # 2. 안전 필터 해제 (사전 단어이므로 차단 방지)
                safety_settings=[
                    types.SafetySetting(
                        category="HARM_CATEGORY_HATE_SPEECH",
                        threshold="BLOCK_NONE",
                    ),
                    types.SafetySetting(
                        category="HARM_CATEGORY_DANGEROUS_CONTENT",
                        threshold="BLOCK_NONE",
                    ),
                    types.SafetySetting(
                        category="HARM_CATEGORY_SEXUALLY_EXPLICIT",
                        threshold="BLOCK_NONE",
                    ),
                    types.SafetySetting(
                        category="HARM_CATEGORY_HARASSMENT",
                        threshold="BLOCK_NONE",
                    ),
                ],
                temperature=0.1,
            )
        )
        
        # 파싱 (이미 리스트로 옴)
        levels = json.loads(response.text)
        
        # 개수 보정 (만약 개수가 안 맞으면 뒤쪽은 B1 처리)
        if len(levels) < len(words):
            levels.extend(['B1'] * (len(words) - len(levels)))
        return levels[:len(words)]
        
    except Exception as e:
        print(f"⚠️ API Error: {e}")
        return ['B1'] * len(words) # 에러 시 기본값 리턴

def main():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("❌ Set GEMINI_API_KEY")
        sys.exit(1)
    
    print(f"🏷️ CEFR Tagger v3 (JSON Mode)")
    
    vocab = load_vocabulary()
    print(f"📂 Loaded {len(vocab)} words")
    
    client = genai.Client(api_key=api_key)
    
    total_batches = (len(vocab) + BATCH_SIZE - 1) // BATCH_SIZE
    tagged_count = 0
    
    print(f"\n🤖 Tagging...")
    
    for batch_idx in range(0, len(vocab), BATCH_SIZE):
        batch_num = batch_idx // BATCH_SIZE + 1
        batch = vocab[batch_idx:batch_idx + BATCH_SIZE]
        
        print(f"   [{batch_num}/{total_batches}] Processing {len(batch)} words...", end=" ", flush=True)
        
        # API 호출
        levels = tag_batch_json(client, batch)
        
        # 결과 적용
        for i, level in enumerate(levels):
            # 유효성 검사 (A1~C2 아니면 B1)
            clean_level = level.upper().strip()
            if clean_level not in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']:
                clean_level = 'B1'
                
            vocab[batch_idx + i]['cefr'] = clean_level
            
        print(f"✓ Done ({levels.count('A1')} A1s found)")
        time.sleep(0.5)
    
    # --- [핵심] 정렬 로직 (등급 순 -> 길이 순) ---
    print("\n🔄 Sorting...")
    cefr_score = {'A1': 1, 'A2': 2, 'B1': 3, 'B2': 4, 'C1': 5, 'C2': 6}
    
    vocab.sort(key=lambda x: (
        cefr_score.get(x['cefr'], 3),  # 1순위: 난이도 (쉬운거 위로)
        len(x['arabic_word'])          # 2순위: 길이 (짧은거 위로)
    ))
    
    # 통계 출력
    counts = {}
    for w in vocab:
        lvl = w.get('cefr', 'B1')
        counts[lvl] = counts.get(lvl, 0) + 1
        
    print("\n📊 Final Distribution:")
    for k in sorted(counts.keys()):
        print(f"   {k}: {counts[k]}")
        
    # 저장
    headers = ['arabic_word', 'meaning_korean', 'root', 'verb_form', 'pattern', 
               'example_sentence', 'cefr']
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(vocab)
        
    print(f"\n✅ Saved sorted file to: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()

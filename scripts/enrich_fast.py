#!/usr/bin/env python3
"""
enrich_fast.py
병렬 처리로 10배 빠르게 verb_forms.csv를 enrichment하는 스크립트
"""

import os
import json
import pandas as pd
from pathlib import Path
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed

try:
    from google import genai
except ImportError:
    print("⚠️ 패키지 설치 필요: pip install google-genai pandas tqdm")
    exit(1)

# ==========================================
# ⚙️ 설정 (Configuration)
# ==========================================
SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent

INPUT_FILE = PROJECT_ROOT / "ArabicLearning" / "Resources" / "verb_forms.csv"
OUTPUT_FILE = PROJECT_ROOT / "ArabicLearning" / "Resources" / "verb_forms_enriched.csv"

API_KEY = os.getenv("GOOGLE_API_KEY")
MAX_WORKERS = 20  # 🚀 동시 요청 수 (유료면 10~20 추천)
MODEL_NAME = "gemini-2.0-flash"
# ==========================================

if not API_KEY:
    print("❌ GOOGLE_API_KEY 환경변수가 설정되지 않았습니다.")
    print("   export GOOGLE_API_KEY='your-key-here'")
    exit(1)

# Gemini 클라이언트 초기화
client = genai.Client(api_key=API_KEY)


def get_semantic_data(row_dict):
    """단일 행에 대해 AI에게 정보를 요청"""
    row_id = row_dict.get('_row_id', 0)
    word = row_dict.get('arabic_word', '')
    root = row_dict.get('root', '')
    form = row_dict.get('verb_form', '1')
    
    prompt = f"""
Analyze the Arabic verb '{word}' (Root: {root}, Form: {form}).
Return ONLY a raw JSON object (no markdown) with these keys:
{{
    "meaning_primary": "가장 일반적인 뜻 (한국어, 1-2단어)",
    "meaning_secondary": "2-3개의 다른 용법 (없으면 '없음')",
    "nuance_kr": "문법적/의미적 특징 설명 (한국어)",
    "example_sentence": "이 동사를 사용한 짧은 아랍어 문장 (모음부호 포함)",
    "sentence_meaning": "예문의 한국어 번역"
}}
"""
    
    try:
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=prompt
        )
        text = response.text.strip()
        
        # 마크다운 코드블럭 제거
        if text.startswith("```"):
            lines = text.split("\n")
            text = "\n".join(lines[1:-1])
        
        data = json.loads(text)
        return row_id, data
        
    except Exception as e:
        return row_id, None


def main():
    print("🚀 Speed Mode: Activated")
    print(f"   동시 처리: {MAX_WORKERS}개")
    print(f"   모델: {MODEL_NAME}")
    print("=" * 50)
    
    # 1. 데이터 로드
    print(f"📂 입력: {INPUT_FILE}")
    if not INPUT_FILE.exists():
        print(f"❌ 파일을 찾을 수 없습니다: {INPUT_FILE}")
        return
    
    df = pd.read_csv(INPUT_FILE)
    df['_row_id'] = df.index  # 임시 ID 생성
    print(f"📊 전체 행: {len(df)}개")
    
    # 2. 기존 작업 확인 (이어하기)
    processed_ids = set()
    if OUTPUT_FILE.exists():
        df_existing = pd.read_csv(OUTPUT_FILE)
        if 'meaning_primary' in df_existing.columns:
            # meaning_primary가 있는 행만 처리된 것으로 간주
            processed_mask = df_existing['meaning_primary'].notna()
            processed_ids = set(df_existing.loc[processed_mask].index)
        print(f"✅ 이미 처리됨: {len(processed_ids)}개")
    
    # 3. 처리할 데이터 필터링
    rows_to_process = []
    for idx, row in df.iterrows():
        if idx not in processed_ids:
            rows_to_process.append(row.to_dict())
    
    print(f"🔥 남은 작업: {len(rows_to_process)}개")
    
    if not rows_to_process:
        print("✅ 모든 작업이 이미 완료되었습니다!")
        return
    
    # 4. 병렬 처리
    results = []
    failed_count = 0
    
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        future_to_row = {
            executor.submit(get_semantic_data, row): row 
            for row in rows_to_process
        }
        
        for future in tqdm(as_completed(future_to_row), 
                          total=len(rows_to_process), 
                          unit="word",
                          desc="처리중"):
            row = future_to_row[future]
            row_id, data = future.result()
            
            if data:
                row.update(data)
                results.append(row)
            else:
                failed_count += 1
                row['meaning_primary'] = "[ERROR]"
                results.append(row)
            
            # 50개마다 중간 저장
            if len(results) >= 50:
                save_results(results)
                results = []
    
    # 남은 결과 저장
    if results:
        save_results(results)
    
    print()
    print("=" * 50)
    print(f"🎉 완료! 결과: {OUTPUT_FILE}")
    if failed_count > 0:
        print(f"⚠️ 실패: {failed_count}개 (나중에 재실행하면 다시 시도)")


def save_results(results):
    """결과를 CSV에 저장 (append 모드)"""
    temp_df = pd.DataFrame(results)
    
    # _row_id 컬럼 제거
    if '_row_id' in temp_df.columns:
        temp_df = temp_df.drop('_row_id', axis=1)
    
    if OUTPUT_FILE.exists():
        temp_df.to_csv(OUTPUT_FILE, mode='a', header=False, index=False)
    else:
        temp_df.to_csv(OUTPUT_FILE, index=False)


if __name__ == "__main__":
    main()

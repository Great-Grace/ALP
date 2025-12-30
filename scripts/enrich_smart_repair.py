#!/usr/bin/env python3
"""
enrich_smart_repair.py
🚑 외과적 데이터 복구 + 완성 스크립트

기능:
1. 엉망이 된 파일에서 유효 데이터 추출 (중복 제거)
2. 원본과 대조하여 미완성 행만 재처리
3. 재시도 로직 + JSON 파싱 강화
"""

import os
import time
import re
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

ORIGINAL_FILE = PROJECT_ROOT / "ArabicLearning" / "Resources" / "verb_forms.csv"
MESSY_FILE = PROJECT_ROOT / "ArabicLearning" / "Resources" / "verb_forms_enriched.csv"
FINAL_FILE = PROJECT_ROOT / "ArabicLearning" / "Resources" / "verb_forms_final.csv"

API_KEY = os.getenv("GOOGLE_API_KEY")
MAX_WORKERS = 8  # ⚠️ 안정성을 위해 8로 하향 (API 에러 방지)
MODEL_NAME = "gemini-2.5-flash"  # 안정적이고 빠른 모델
# ==========================================

if not API_KEY:
    print("❌ GOOGLE_API_KEY 환경변수가 없습니다.")
    print("   export GOOGLE_API_KEY='your-key-here'")
    exit(1)

# Gemini 클라이언트 초기화
client = genai.Client(api_key=API_KEY)


def clean_json_string(text):
    """AI가 마크다운 코드블럭으로 감싸서 줄 때 벗겨내는 함수"""
    text = text.strip()
    if "```" in text:
        text = re.sub(r'```json\s*', '', text)
        text = re.sub(r'```\s*', '', text)
    return text.strip()


def get_semantic_data_safe(row_dict, retry_count=3):
    """재시도 로직이 포함된 안전한 요청 함수"""
    row_id = row_dict.get('id', 'unknown')
    word = row_dict.get('arabic_word', '')
    root = row_dict.get('root', '')
    form = row_dict.get('verb_form', '1')
    
    prompt = f"""
Analyze the Arabic verb '{word}' (Root: {root}, Form: {form}).
Return ONLY a raw JSON object with these keys:
{{
    "meaning_primary": "가장 일반적인 뜻 (한국어, 1-2단어)",
    "meaning_secondary": "2-3개의 다른 용법 (없으면 '없음')",
    "nuance_kr": "문법적/의미적 특징 설명 (한국어)",
    "example_sentence": "이 동사를 사용한 짧은 아랍어 문장 (모음부호 포함)",
    "sentence_meaning": "예문의 한국어 번역"
}}
"""
    
    for attempt in range(retry_count):
        try:
            response = client.models.generate_content(
                model=MODEL_NAME,
                contents=prompt
            )
            text = clean_json_string(response.text)
            data = json.loads(text)
            
            # 필수 키가 있는지 검증
            if not data.get('meaning_primary'):
                raise ValueError("Empty meaning")
            
            return row_id, data
            
        except Exception as e:
            if attempt < retry_count - 1:
                time.sleep(2 * (attempt + 1))  # 지수 백오프
                continue
            else:
                return row_id, None


def main():
    print("🚑 Emergency Repair & Finish Mode Activated")
    print("=" * 50)
    
    # 1. 원본 뼈대 로드
    if not ORIGINAL_FILE.exists():
        print(f"❌ 원본 파일이 없습니다: {ORIGINAL_FILE}")
        return
    
    df_skeleton = pd.read_csv(ORIGINAL_FILE)
    print(f"💀 원본 데이터: {len(df_skeleton)}행")
    
    # ID가 없으면 임시 생성
    if 'id' not in df_skeleton.columns:
        df_skeleton['id'] = df_skeleton.index.astype(str)
    
    # 2. 엉망이 된 파일에서 유효 데이터 추출
    enriched_map = {}
    
    if MESSY_FILE.exists():
        print("🧹 기존 파일에서 유효 데이터 추출 중...")
        try:
            df_messy = pd.read_csv(MESSY_FILE)
            
            if 'meaning_primary' in df_messy.columns:
                # [ERROR]가 아니고 빈값이 아닌 행만 필터링
                df_valid = df_messy[
                    df_messy['meaning_primary'].notna() & 
                    ~df_messy['meaning_primary'].astype(str).str.contains(r'\[ERROR\]', na=False)
                ]
                print(f"   - 유효 데이터: {len(df_valid)}행 (중복 포함)")
                
                # 중복 제거 (첫번째 유효 데이터 유지)
                for _, row in df_valid.iterrows():
                    # 원본과 매칭할 키 생성 (arabic_word + verb_form)
                    key = f"{row.get('arabic_word', '')}_{row.get('verb_form', '')}"
                    
                    if key not in enriched_map:
                        enriched_map[key] = {
                            'meaning_primary': row.get('meaning_primary'),
                            'meaning_secondary': row.get('meaning_secondary'),
                            'nuance_kr': row.get('nuance_kr'),
                            'example_sentence': row.get('example_sentence'),
                            'sentence_meaning': row.get('sentence_meaning')
                        }
        except Exception as e:
            print(f"⚠️ 기존 파일 읽기 실패: {e}")
    
    print(f"💎 구조된 유효 데이터: {len(enriched_map)}개")
    
    # 3. 작업 분류: 완료 vs 처리 필요
    rows_to_process = []
    final_results = []
    
    for idx, row in df_skeleton.iterrows():
        row_dict = row.to_dict()
        row_dict['id'] = str(idx)
        key = f"{row.get('arabic_word', '')}_{row.get('verb_form', '')}"
        
        if key in enriched_map:
            # 이미 유효 데이터 있음 → 채워넣기
            row_dict.update(enriched_map[key])
            final_results.append(row_dict)
        else:
            # 데이터 없음 → 처리 필요
            rows_to_process.append(row_dict)
            final_results.append(row_dict)
    
    print(f"🔥 새로 처리해야 할 작업: {len(rows_to_process)}개")
    
    # 4. API 병렬 처리
    if rows_to_process:
        # 결과 조회용 딕셔너리
        result_lookup = {item['id']: item for item in final_results}
        completed_count = 0
        
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            future_to_row = {
                executor.submit(get_semantic_data_safe, row): row 
                for row in rows_to_process
            }
            
            for future in tqdm(as_completed(future_to_row), 
                              total=len(rows_to_process), 
                              unit="word",
                              desc="처리중"):
                row_id, result = future.result()
                
                if result:
                    if row_id in result_lookup:
                        result_lookup[row_id].update(result)
                    completed_count += 1
                
                # 50개마다 중간 저장
                if completed_count > 0 and completed_count % 50 == 0:
                    df_temp = pd.DataFrame(list(result_lookup.values()))
                    df_temp.to_csv(FINAL_FILE, index=False)
        
        final_results = list(result_lookup.values())
    
    # 5. 최종 저장
    df_final = pd.DataFrame(final_results)
    
    # id 컬럼 제거 (임시로 만든 것)
    if 'id' in df_final.columns:
        df_final = df_final.drop('id', axis=1)
    
    df_final.to_csv(FINAL_FILE, index=False)
    
    print()
    print("=" * 50)
    print(f"🎉 복구 및 처리 완료!")
    print(f"📂 최종 파일: {FINAL_FILE}")
    print(f"📊 총 행 수: {len(df_final)} (목표: {len(df_skeleton)})")
    
    # 검증
    missing = df_final['meaning_primary'].isna().sum() if 'meaning_primary' in df_final.columns else len(df_final)
    print(f"❓ 비어있는 행: {missing}개")
    
    if missing == 0:
        print("✅ 완벽합니다! 모든 데이터가 채워졌습니다.")
    elif missing < 100:
        print("✅ 거의 완료! 소수의 실패 건은 무시해도 됩니다.")
    else:
        print("⚠️ 실패 건이 많습니다. 다시 실행해주세요.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
data_quality_audit.py
verb_forms_enriched.csv 품질 검사 스크립트
"""

import pandas as pd
from pathlib import Path
from collections import Counter
import json

# 경로 설정
SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
ENRICHED_FILE = PROJECT_ROOT / "ArabicLearning" / "Resources" / "verb_forms_enriched.csv"
ORIGINAL_FILE = PROJECT_ROOT / "ArabicLearning" / "Resources" / "verb_forms.csv"

def main():
    print("=" * 60)
    print("📊 VERB_FORMS_ENRICHED.CSV 품질 감사 보고서")
    print("=" * 60)
    print()
    
    # 1. 파일 로드
    df = pd.read_csv(ENRICHED_FILE)
    df_original = pd.read_csv(ORIGINAL_FILE)
    
    print("## 1. 기본 통계")
    print("-" * 40)
    print(f"원본 파일 행 수: {len(df_original):,}")
    print(f"Enriched 파일 행 수: {len(df):,}")
    print(f"예상 대비 비율: {len(df) / len(df_original):.2f}x")
    print()
    
    # 2. 중복 검사
    print("## 2. 중복 검사")
    print("-" * 40)
    
    # 고유 키: arabic_word + verb_form
    df['_key'] = df['arabic_word'].astype(str) + '_' + df['verb_form'].astype(str)
    duplicates = df[df.duplicated(subset=['_key'], keep=False)]
    unique_keys = df['_key'].nunique()
    
    print(f"고유 단어+형태 조합: {unique_keys:,}")
    print(f"중복 행 수: {len(duplicates):,}")
    
    if len(duplicates) > 0:
        print(f"⚠️ 중복 비율: {len(duplicates) / len(df) * 100:.1f}%")
        # 중복 샘플
        print("\n중복 샘플 (최대 5개):")
        sample_keys = duplicates['_key'].drop_duplicates().head(5)
        for key in sample_keys:
            count = len(df[df['_key'] == key])
            print(f"  - '{key}': {count}회 중복")
    else:
        print("✅ 중복 없음")
    print()
    
    # 3. 필수 컬럼 완성도
    print("## 3. 신규 컬럼 완성도")
    print("-" * 40)
    
    new_columns = ['meaning_primary', 'meaning_secondary', 'nuance_kr', 
                   'example_sentence', 'sentence_meaning']
    
    for col in new_columns:
        if col in df.columns:
            filled = df[col].notna() & (df[col] != '') & (df[col] != '[ERROR]')
            fill_rate = filled.sum() / len(df) * 100
            error_count = (df[col] == '[ERROR]').sum()
            empty_count = (~filled).sum()
            
            status = "✅" if fill_rate > 95 else "⚠️" if fill_rate > 80 else "❌"
            print(f"{status} {col}: {fill_rate:.1f}% 완성 (빈값: {empty_count}, 에러: {error_count})")
        else:
            print(f"❌ {col}: 컬럼 없음!")
    print()
    
    # 4. 값 품질 샘플 검사
    print("## 4. 값 품질 샘플 (무작위 10개)")
    print("-" * 40)
    
    # 중복 제거 후 샘플링
    df_unique = df.drop_duplicates(subset=['_key'])
    sample = df_unique.sample(min(10, len(df_unique)))
    
    for idx, row in sample.iterrows():
        print(f"\n### [{row.get('arabic_word', 'N/A')}] ({row.get('verb_form_label', 'N/A')})")
        print(f"   Root: {row.get('root', 'N/A')}")
        print(f"   Primary: {row.get('meaning_primary', 'N/A')}")
        print(f"   Secondary: {row.get('meaning_secondary', 'N/A')[:50] if pd.notna(row.get('meaning_secondary')) else 'N/A'}...")
        print(f"   Nuance: {row.get('nuance_kr', 'N/A')[:60] if pd.notna(row.get('nuance_kr')) else 'N/A'}...")
        print(f"   Example: {row.get('example_sentence', 'N/A')}")
        print(f"   Translation: {row.get('sentence_meaning', 'N/A')}")
    print()
    
    # 5. 언어 품질 검사
    print("## 5. 언어 품질 검사")
    print("-" * 40)
    
    # 한국어 포함 여부 (meaning_primary)
    df_unique = df.drop_duplicates(subset=['_key'])
    korean_pattern = df_unique['meaning_primary'].str.contains(r'[가-힣]', na=False)
    korean_rate = korean_pattern.sum() / len(df_unique) * 100
    print(f"한국어 포함 (meaning_primary): {korean_rate:.1f}%")
    
    # 아랍어 포함 여부 (example_sentence)
    arabic_pattern = df_unique['example_sentence'].str.contains(r'[\u0600-\u06FF]', na=False)
    arabic_rate = arabic_pattern.sum() / len(df_unique) * 100
    print(f"아랍어 포함 (example_sentence): {arabic_rate:.1f}%")
    
    # 모음부호 포함 여부 (تشكيل)
    tashkeel_pattern = df_unique['example_sentence'].str.contains(r'[\u064B-\u065F]', na=False)
    tashkeel_rate = tashkeel_pattern.sum() / len(df_unique) * 100
    print(f"모음부호 포함 (تشكيل): {tashkeel_rate:.1f}%")
    print()
    
    # 6. 에러/이상값 분석
    print("## 6. 에러 및 이상값")
    print("-" * 40)
    
    # [ERROR] 태그
    for col in new_columns:
        if col in df.columns:
            errors = df[df[col] == '[ERROR]']
            if len(errors) > 0:
                print(f"❌ {col}에서 [ERROR] 발견: {len(errors)}건")
    
    # 너무 짧은 값
    if 'meaning_primary' in df.columns:
        short_primary = df_unique[df_unique['meaning_primary'].str.len() < 2]
        if len(short_primary) > 0:
            print(f"⚠️ meaning_primary 너무 짧음 (<2자): {len(short_primary)}건")
    
    # 영어만 있는 경우 (한국어여야 함)
    if 'meaning_primary' in df.columns:
        english_only = df_unique[
            df_unique['meaning_primary'].str.contains(r'^[a-zA-Z\s]+$', na=False)
        ]
        if len(english_only) > 0:
            print(f"⚠️ meaning_primary 영어만: {len(english_only)}건")
            print(f"   샘플: {english_only['meaning_primary'].head(3).tolist()}")
    print()
    
    # 7. 권장 조치
    print("## 7. 권장 조치")
    print("-" * 40)
    
    issues = []
    
    if len(df) > len(df_original) * 1.5:
        issues.append("🔧 중복 행 제거 필요 (DROP DUPLICATES)")
    
    for col in new_columns:
        if col in df.columns:
            filled = df[col].notna() & (df[col] != '') & (df[col] != '[ERROR]')
            fill_rate = filled.sum() / len(df) * 100
            if fill_rate < 95:
                issues.append(f"🔧 {col} 재처리 필요 (현재 {fill_rate:.1f}%)")
    
    if not issues:
        print("✅ 심각한 이슈 없음! 프로덕션 사용 가능")
    else:
        for issue in issues:
            print(issue)
    
    print()
    print("=" * 60)
    print("📊 감사 완료")
    print("=" * 60)
    
    return {
        'total_rows': len(df),
        'unique_rows': unique_keys,
        'duplicate_rows': len(duplicates),
        'issues': issues
    }

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
generate_block6.py - Form I Morphology Generator with Validation
Generates: 과거/현재/동명사/능동분사/수동분사 with Tashkeel validation

Usage:
    export GEMINI_API_KEY="your-key"
    python3 generate_block6.py
"""

import os
import sys
import csv
import json
import time
import re
from pathlib import Path
from datetime import datetime

try:
    from google import genai
    from google.genai import types
except ImportError:
    print("❌ pip install google-genai")
    sys.exit(1)

# Configuration
OUTPUT_DIR = Path("/Users/taewoo/Documents/ALP/ArabicLearning/scripts/generated_data")
OUTPUT_DIR.mkdir(exist_ok=True)

MODEL_NAME = "gemini-2.5-flash"

# Tashkeel validation regex (Fatha, Damma, Kasra, Sukun, Shadda, Tanween)
TASHKEEL_REGEX = re.compile(r'[\u064B-\u0652]')

# Form I base verbs for generation (50 common verbs)
SOURCE_VERBS = [
    {"root": "ك-ت-ب", "basic": "كَتَبَ", "meaning": "쓰다"},
    {"root": "د-ر-س", "basic": "دَرَسَ", "meaning": "공부하다"},
    {"root": "ع-ل-م", "basic": "عَلِمَ", "meaning": "알다"},
    {"root": "ف-ع-ل", "basic": "فَعَلَ", "meaning": "하다"},
    {"root": "ذ-ه-ب", "basic": "ذَهَبَ", "meaning": "가다"},
    {"root": "أ-ك-ل", "basic": "أَكَلَ", "meaning": "먹다"},
    {"root": "ش-ر-ب", "basic": "شَرِبَ", "meaning": "마시다"},
    {"root": "ج-ل-س", "basic": "جَلَسَ", "meaning": "앉다"},
    {"root": "ق-ر-أ", "basic": "قَرَأَ", "meaning": "읽다"},
    {"root": "س-م-ع", "basic": "سَمِعَ", "meaning": "듣다"},
    {"root": "ن-ظ-ر", "basic": "نَظَرَ", "meaning": "보다"},
    {"root": "ف-ه-م", "basic": "فَهِمَ", "meaning": "이해하다"},
    {"root": "خ-ر-ج", "basic": "خَرَجَ", "meaning": "나가다"},
    {"root": "د-خ-ل", "basic": "دَخَلَ", "meaning": "들어가다"},
    {"root": "ف-ت-ح", "basic": "فَتَحَ", "meaning": "열다"},
    {"root": "ق-ف-ل", "basic": "قَفَلَ", "meaning": "닫다"},
    {"root": "ض-ر-ب", "basic": "ضَرَبَ", "meaning": "치다"},
    {"root": "ل-ع-ب", "basic": "لَعِبَ", "meaning": "놀다"},
    {"root": "ن-ز-ل", "basic": "نَزَلَ", "meaning": "내리다"},
    {"root": "ص-ع-د", "basic": "صَعِدَ", "meaning": "오르다"},
    {"root": "ع-م-ل", "basic": "عَمِلَ", "meaning": "일하다"},
    {"root": "س-ك-ن", "basic": "سَكَنَ", "meaning": "살다"},
    {"root": "ط-ب-خ", "basic": "طَبَخَ", "meaning": "요리하다"},
    {"root": "غ-س-ل", "basic": "غَسَلَ", "meaning": "씻다"},
    {"root": "ل-ب-س", "basic": "لَبِسَ", "meaning": "입다"},
    {"root": "ن-ص-ر", "basic": "نَصَرَ", "meaning": "돕다"},
    {"root": "ف-ق-د", "basic": "فَقَدَ", "meaning": "잃다"},
    {"root": "و-ج-د", "basic": "وَجَدَ", "meaning": "찾다"},
    {"root": "أ-خ-ذ", "basic": "أَخَذَ", "meaning": "가지다"},
    {"root": "ت-ر-ك", "basic": "تَرَكَ", "meaning": "떠나다/놓다"},
    {"root": "ق-ت-ل", "basic": "قَتَلَ", "meaning": "죽이다"},
    {"root": "ح-م-ل", "basic": "حَمَلَ", "meaning": "나르다"},
    {"root": "ر-ك-ب", "basic": "رَكِبَ", "meaning": "타다"},
    {"root": "س-أ-ل", "basic": "سَأَلَ", "meaning": "묻다"},
    {"root": "ج-و-ب", "basic": "أَجَابَ", "meaning": "대답하다"},  # Note: Form IV
    {"root": "ز-ر-ع", "basic": "زَرَعَ", "meaning": "심다"},
    {"root": "ح-ص-د", "basic": "حَصَدَ", "meaning": "수확하다"},
    {"root": "ب-ن-ى", "basic": "بَنَى", "meaning": "짓다"},
    {"root": "ب-ي-ع", "basic": "بَاعَ", "meaning": "팔다"},
    {"root": "ش-ر-ى", "basic": "اِشْتَرَى", "meaning": "사다"},  # Note: Form VIII
    {"root": "ق-و-ل", "basic": "قَالَ", "meaning": "말하다"},
    {"root": "ن-و-م", "basic": "نَامَ", "meaning": "자다"},
    {"root": "ص-و-م", "basic": "صَامَ", "meaning": "단식하다"},
    {"root": "ز-و-ر", "basic": "زَارَ", "meaning": "방문하다"},
    {"root": "ع-و-د", "basic": "عَادَ", "meaning": "돌아오다"},
    {"root": "س-ي-ر", "basic": "سَارَ", "meaning": "걷다"},
    {"root": "ط-ي-ر", "basic": "طَارَ", "meaning": "날다"},
    {"root": "ص-ي-ر", "basic": "صَارَ", "meaning": "되다"},
    {"root": "ج-ي-ء", "basic": "جَاءَ", "meaning": "오다"},
    {"root": "ر-أ-ى", "basic": "رَأَى", "meaning": "보다"},
]

def validate_arabic(word: str) -> bool:
    """Validate Arabic word has Tashkeel"""
    if not word or word.strip() == "" or word == "N/A":
        return False
    # Must have at least one Tashkeel mark
    return bool(TASHKEEL_REGEX.search(word))

def generate_morphology(client, verb_info: dict) -> dict:
    """Generate 5 morphological forms for a Form I verb"""
    
    prompt = f"""You are an expert Arabic Morphologist.
For the Form I verb root '{verb_info['root']}' (Base: {verb_info['basic']} - {verb_info['meaning']}), generate the 5 core derivatives with FULL TASHKEEL.

Required Output (JSON):
{{
    "past": {{"arabic": "...", "korean": "..."}},
    "present": {{"arabic": "...", "korean": "..."}},
    "masdar": {{"arabic": "...", "korean": "..."}},
    "active": {{"arabic": "...", "korean": "..."}},
    "passive": {{"arabic": "...", "korean": "..."}}
}}

CRITICAL RULES:
1. All words MUST have full Tashkeel (Fatha, Damma, Kasra, Sukun)
2. past = 3rd person masculine singular past tense (فَعَلَ pattern)
3. present = 3rd person masculine singular present (يَفْعَلُ pattern)
4. masdar = verbal noun (المصدر)
5. active = active participle (اسم الفاعل - فَاعِل pattern)
6. passive = passive participle (اسم المفعول - مَفْعُول pattern)
7. If the verb is intransitive and has no passive participle, write "N/A"
8. Korean meanings should be natural Korean"""

    try:
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.2,
                safety_settings=[
                    types.SafetySetting(category="HARM_CATEGORY_HATE_SPEECH", threshold="BLOCK_NONE"),
                    types.SafetySetting(category="HARM_CATEGORY_DANGEROUS_CONTENT", threshold="BLOCK_NONE"),
                    types.SafetySetting(category="HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold="BLOCK_NONE"),
                    types.SafetySetting(category="HARM_CATEGORY_HARASSMENT", threshold="BLOCK_NONE"),
                ],
            )
        )
        
        return json.loads(response.text)
        
    except Exception as e:
        print(f"⚠️ API Error: {e}")
        return None

def main():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("❌ Set GEMINI_API_KEY")
        sys.exit(1)
    
    print("🚀 Block 6: Form I Morphology Generator")
    print("="*60)
    print(f"📂 Processing {len(SOURCE_VERBS)} root verbs")
    
    client = genai.Client(api_key=api_key)
    
    results = []
    success_count = 0
    fail_count = 0
    
    for idx, verb in enumerate(SOURCE_VERBS):
        print(f"   [{idx+1}/{len(SOURCE_VERBS)}] {verb['root']}...", end=" ", flush=True)
        
        data = generate_morphology(client, verb)
        
        if not data:
            print("❌ API Failed")
            fail_count += 1
            continue
        
        # Validation Phase
        is_valid = True
        
        # Check required fields
        for key in ['past', 'present', 'masdar', 'active']:
            if key not in data:
                is_valid = False
                break
            if not validate_arabic(data[key].get('arabic', '')):
                is_valid = False
                break
        
        if not is_valid:
            print("❌ Validation Failed (Missing Tashkeel)")
            fail_count += 1
            continue
        
        # Generate CSV rows
        root = verb['root']
        
        # 6-1: Past/Present
        results.append({
            "sub_level_id": "6-1", "type": "vocabulary",
            "arabic_text": data['past']['arabic'],
            "korean_meaning": f"{verb['meaning']} (과거)",
            "root": root, "form": 1
        })
        results.append({
            "sub_level_id": "6-1", "type": "vocabulary",
            "arabic_text": data['present']['arabic'],
            "korean_meaning": f"{verb['meaning']} (현재)",
            "root": root, "form": 1
        })
        
        # 6-2: Masdar
        results.append({
            "sub_level_id": "6-2", "type": "vocabulary",
            "arabic_text": data['masdar']['arabic'],
            "korean_meaning": data['masdar']['korean'],
            "root": root, "form": 1
        })
        
        # 6-3: Active Participle
        results.append({
            "sub_level_id": "6-3", "type": "vocabulary",
            "arabic_text": data['active']['arabic'],
            "korean_meaning": data['active']['korean'],
            "root": root, "form": 1
        })
        
        # 6-4: Passive Participle (if exists)
        if 'passive' in data and data['passive'].get('arabic') != 'N/A':
            if validate_arabic(data['passive'].get('arabic', '')):
                results.append({
                    "sub_level_id": "6-4", "type": "vocabulary",
                    "arabic_text": data['passive']['arabic'],
                    "korean_meaning": data['passive']['korean'],
                    "root": root, "form": 1
                })
        
        print("✅ Verified")
        success_count += 1
        time.sleep(0.5)
    
    print("\n" + "="*60)
    print(f"📊 Results: {success_count} success, {fail_count} failed")
    print(f"📊 Total items generated: {len(results)}")
    
    # Save
    if results:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filepath = OUTPUT_DIR / f"block6_morphology_{timestamp}.csv"
        
        headers = ["sub_level_id", "type", "arabic_text", "korean_meaning", "root", "form"]
        
        with open(filepath, 'w', encoding='utf-8-sig', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=headers)
            writer.writeheader()
            writer.writerows(results)
        
        print(f"\n💾 Saved: {filepath}")
        
        # Stats by sub-level
        sub_counts = {}
        for r in results:
            sl = r['sub_level_id']
            sub_counts[sl] = sub_counts.get(sl, 0) + 1
        
        print("\n📊 By Sub-level:")
        for sl in sorted(sub_counts.keys()):
            print(f"   {sl}: {sub_counts[sl]} items")
    else:
        print("\n❌ No data generated")

if __name__ == "__main__":
    main()

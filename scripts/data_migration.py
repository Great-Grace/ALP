#!/usr/bin/env python3
"""
data_migration.py - 8-Level Curriculum Data Re-Architecture
Merges all data sources into final_curriculum.csv

Usage:
    python3 data_migration.py
"""

import csv
import json
from pathlib import Path
from datetime import datetime

BASE_DIR = Path(__file__).parent.parent
RESOURCES_DIR = BASE_DIR / "ArabicLearning" / "Resources"
SCRIPTS_DIR = Path(__file__).parent
GENERATED_DIR = SCRIPTS_DIR / "generated_data"
OUTPUT_FILE = RESOURCES_DIR / "final_curriculum.csv"

def load_csv(filepath):
    """Load CSV file"""
    if not filepath.exists():
        print(f"⚠️ Not found: {filepath}")
        return []
    
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        return list(csv.DictReader(f))

def find_latest_file(directory, pattern):
    """Find most recent file matching pattern"""
    files = list(directory.glob(pattern))
    if not files:
        return None
    return max(files, key=lambda x: x.stat().st_mtime)

def main():
    print("🏗️ Data Migration: 8-Level Curriculum")
    print("="*60)
    
    master_data = []
    id_counter = 1
    
    # =========================================================
    # LEVEL 1: Merged Base Vocabulary (Old L1 + L2 + L3)
    # =========================================================
    print("\n📦 Processing Level 1 (Base Vocabulary)...")
    
    old_data = load_csv(RESOURCES_DIR / "curriculum_data.csv")
    
    level1_count = 0
    for row in old_data:
        old_level = int(row.get('level', 1))
        if old_level in [1, 2, 3]:  # Merge old L1, L2, L3
            master_data.append({
                'id': id_counter,
                'level': 1,
                'type': 'vocabulary',
                'arabic_text': row.get('arabic_word', ''),
                'korean_meaning': row.get('meaning_korean', ''),
                'root': row.get('root', ''),
                'form': row.get('verb_form', 0),
                'pattern': row.get('pattern', ''),
                'gender': '',
                'phrase_components': '',
                'singular_form': '',
                'plural_form': '',
                'sentence_analysis': ''
            })
            id_counter += 1
            level1_count += 1
    
    print(f"   ✅ Level 1: {level1_count} items (merged old L1+L2+L3)")
    
    # =========================================================
    # LEVEL 2: Phrases (New Gemini Data)
    # =========================================================
    print("\n📦 Processing Level 2 (Phrases)...")
    
    l2_file = find_latest_file(GENERATED_DIR, "level2_*.csv")
    if l2_file:
        l2_data = load_csv(l2_file)
        level2_count = 0
        for row in l2_data:
            master_data.append({
                'id': id_counter,
                'level': 2,
                'type': 'phrase',
                'arabic_text': row.get('arabic_text', ''),
                'korean_meaning': row.get('korean_meaning', ''),
                'root': row.get('root', ''),
                'form': 0,
                'pattern': '',
                'gender': row.get('gender', ''),
                'phrase_components': row.get('phrase_components', ''),
                'singular_form': '',
                'plural_form': '',
                'sentence_analysis': ''
            })
            id_counter += 1
            level2_count += 1
        print(f"   ✅ Level 2: {level2_count} phrases")
    else:
        print(f"   ⚠️ Level 2: No data file found")
    
    # =========================================================
    # LEVEL 3: Plural Pairs (New Gemini Data)
    # =========================================================
    print("\n📦 Processing Level 3 (Plural Pairs)...")
    
    l3_file = find_latest_file(GENERATED_DIR, "level3_*.csv")
    if l3_file:
        l3_data = load_csv(l3_file)
        level3_count = 0
        for row in l3_data:
            master_data.append({
                'id': id_counter,
                'level': 3,
                'type': 'plural_pair',
                'arabic_text': row.get('arabic_text', ''),
                'korean_meaning': row.get('korean_meaning', ''),
                'root': row.get('root', ''),
                'form': 0,
                'pattern': row.get('pattern', ''),
                'gender': row.get('gender', ''),
                'phrase_components': '',
                'singular_form': row.get('singular_form', ''),
                'plural_form': row.get('arabic_text', ''),  # Plural is in arabic_text
                'sentence_analysis': ''
            })
            id_counter += 1
            level3_count += 1
        print(f"   ✅ Level 3: {level3_count} plural pairs")
    else:
        print(f"   ⚠️ Level 3: No data file found")
    
    # =========================================================
    # LEVEL 4: Form 1-2 Verbs (From Old L4 + L5 + verb_forms)
    # =========================================================
    print("\n📦 Processing Level 4 (Form 1-2 Verbs)...")
    
    # From old curriculum_data L4, L5
    level4_count = 0
    for row in old_data:
        old_level = int(row.get('level', 1))
        form = int(row.get('verb_form', 0) or 0)
        if old_level in [4, 5] and form in [0, 1, 2]:
            master_data.append({
                'id': id_counter,
                'level': 4,
                'type': 'vocabulary',
                'arabic_text': row.get('arabic_word', ''),
                'korean_meaning': row.get('meaning_korean', ''),
                'root': row.get('root', ''),
                'form': form,
                'pattern': row.get('pattern', ''),
                'gender': '',
                'phrase_components': '',
                'singular_form': '',
                'plural_form': '',
                'sentence_analysis': ''
            })
            id_counter += 1
            level4_count += 1
    
    # From verb_forms.csv
    verb_forms = load_csv(Path("/Users/taewoo/Documents/ALP/verb_forms.csv"))
    for row in verb_forms:
        form = int(row.get('verb_form', 0) or 0)
        if form in [1, 2]:
            master_data.append({
                'id': id_counter,
                'level': 4,
                'type': 'vocabulary',
                'arabic_text': row.get('arabic_word', ''),
                'korean_meaning': row.get('nuance_korean', ''),
                'root': row.get('root', ''),
                'form': form,
                'pattern': row.get('pattern', ''),
                'gender': '',
                'phrase_components': '',
                'singular_form': '',
                'plural_form': '',
                'sentence_analysis': ''
            })
            id_counter += 1
            level4_count += 1
    
    print(f"   ✅ Level 4: {level4_count} verbs (Form 1-2)")
    
    # =========================================================
    # LEVELS 5-7: Generated Verb Data
    # =========================================================
    for level in [5, 6, 7]:
        print(f"\n📦 Processing Level {level} (Generated Verbs)...")
        
        l_file = find_latest_file(GENERATED_DIR, f"level{level}_*.csv")
        if l_file:
            l_data = load_csv(l_file)
            l_count = 0
            for row in l_data:
                master_data.append({
                    'id': id_counter,
                    'level': level,
                    'type': 'vocabulary',
                    'arabic_text': row.get('arabic_text', '') or row.get('arabic', ''),
                    'korean_meaning': row.get('korean_meaning', '') or row.get('korean', ''),
                    'root': row.get('root', ''),
                    'form': row.get('form', ''),
                    'pattern': row.get('pattern', ''),
                    'gender': '',
                    'phrase_components': '',
                    'singular_form': '',
                    'plural_form': '',
                    'sentence_analysis': ''
                })
                id_counter += 1
                l_count += 1
            print(f"   ✅ Level {level}: {l_count} verbs")
        else:
            print(f"   ⚠️ Level {level}: No data file found")
    
    # =========================================================
    # LEVEL 8: Sentences (New Gemini Data)
    # =========================================================
    print("\n📦 Processing Level 8 (Sentences)...")
    
    l8_file = find_latest_file(GENERATED_DIR, "level8_*.csv")
    if l8_file:
        l8_data = load_csv(l8_file)
        level8_count = 0
        for row in l8_data:
            master_data.append({
                'id': id_counter,
                'level': 8,
                'type': 'sentence',
                'arabic_text': row.get('arabic_text', ''),
                'korean_meaning': row.get('korean_meaning', ''),
                'root': '',
                'form': row.get('verb_form', ''),
                'pattern': '',
                'gender': '',
                'phrase_components': '',
                'singular_form': '',
                'plural_form': '',
                'sentence_analysis': row.get('sentence_analysis', '')
            })
            id_counter += 1
            level8_count += 1
        print(f"   ✅ Level 8: {level8_count} sentences")
    else:
        print(f"   ⚠️ Level 8: No data file found")
    
    # =========================================================
    # SAVE TO CSV
    # =========================================================
    print("\n" + "="*60)
    print("💾 Saving final_curriculum.csv...")
    
    headers = ['id', 'level', 'type', 'arabic_text', 'korean_meaning', 'root', 
               'form', 'pattern', 'gender', 'phrase_components', 'singular_form',
               'plural_form', 'sentence_analysis']
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(master_data)
    
    print(f"   ✅ Saved: {OUTPUT_FILE}")
    print(f"   📊 Total rows: {len(master_data)}")
    
    # Summary by level
    print("\n📊 FINAL SUMMARY")
    print("="*60)
    
    from collections import Counter
    level_counts = Counter(row['level'] for row in master_data)
    
    for level in sorted(level_counts.keys()):
        count = level_counts[level]
        status = "✅" if count >= 30 else "⚠️"
        print(f"{status} Level {level}: {count} items")
    
    print(f"\n🎉 Migration Complete! Total: {len(master_data)} items")
    
    return 0

if __name__ == "__main__":
    exit(main())

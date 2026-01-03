#!/usr/bin/env python3
"""
sublevel_mapper.py - Assign all vocabulary to 50 sub-levels
Based on: POS tags, verb_form, dataType, CEFR

Usage:
    python3 sublevel_mapper.py
"""

import csv
import json
from pathlib import Path
from collections import defaultdict

# Paths
BASE_DIR = Path("/Users/taewoo/Documents/ALP")
POS_TAGGED = BASE_DIR / "curriculum_data_pos_tagged.csv"
GENERATED_DIR = BASE_DIR / "ArabicLearning/scripts/generated_data"
OUTPUT_FILE = BASE_DIR / "ArabicLearning/ArabicLearning/Resources/final_curriculum.csv"

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

def assign_sublevel(row, pos, verb_form, data_type, cefr):
    """Determine sub-level ID based on data attributes"""
    
    # Block 6: Form I morphology (from block6 generator)
    if row.get('sub_level_id'):
        return row['sub_level_id']
    
    # Block 2-7, 2-8: Plurals
    if data_type == 'plural_pair':
        return '2-7'  # 규칙 복수 (or 2-8 for broken)
    
    # Block 2-1~2-6: Phrases
    if data_type == 'phrase':
        return '2-5'  # 연결형
    
    # Block 12: Sentences
    if data_type == 'sentence':
        return '12-1'
    
    # Block 1: Nouns based on CEFR
    if pos == 'noun':
        if cefr == 'A1':
            return '1-5'  # 기초 어휘 I
        elif cefr == 'A2':
            return '1-6'  # 기초 어휘 II
        else:
            return '1-6'
    
    # Block 2: Adjectives
    if pos == 'adj':
        return '2-1'  # 형용사 기초
    
    # Block 1: Expressions, Prepositions
    if pos in ['expression', 'prep']:
        return '1-3'  # 지시사/의문사
    
    # Block 3-10: Verbs based on Form
    if verb_form >= 1:
        form_to_sublevel = {
            1: '3-1',   # Form 1 과거 (기본)
            2: '7-1',   # Form 2
            3: '7-2',   # Form 3
            4: '7-3',   # Form 4
            5: '8-1',   # Form 5
            6: '8-2',   # Form 6
            7: '9-1',   # Form 7
            8: '9-2',   # Form 8
            9: '10-1',  # Form 9
            10: '10-2', # Form 10
        }
        return form_to_sublevel.get(verb_form, '3-1')
    
    # Default
    return '1-5'

def main():
    print("🗺️ Sub-level Mapper: 50 Sub-levels Assignment")
    print("="*60)
    
    master_data = []
    id_counter = 10001
    
    # 1. Load POS-tagged vocabulary
    print("\n📂 Loading POS-tagged vocabulary...")
    vocab = load_csv(POS_TAGGED)
    print(f"   {len(vocab)} items")
    
    for row in vocab:
        # CRITICAL: Skip items without Korean meaning
        korean_meaning = row.get('meaning_korean', '').strip()
        if not korean_meaning:
            continue
            
        pos = row.get('pos', 'noun')
        verb_form = int(row.get('verb_form', 0) or 0)
        data_type = row.get('type', 'vocabulary')
        cefr = row.get('cefr', 'A2')
        
        sub_level_id = assign_sublevel(row, pos, verb_form, data_type, cefr)
        
        master_data.append({
            'id': id_counter,
            'sub_level_id': sub_level_id,
            'type': 'vocabulary',
            'arabic_text': row.get('arabic_word', ''),
            'korean_meaning': korean_meaning,
            'root': row.get('root', ''),
            'form': verb_form,
            'pattern': row.get('pattern', ''),
            'pos': pos,
            'cefr': cefr
        })
        id_counter += 1
    
    print(f"   → {len(master_data)} items with Korean meaning")
    
    # 2. Load Block 6 morphology data
    print("\n📂 Loading Block 6 morphology...")
    b6_file = find_latest_file(GENERATED_DIR, "block6_*.csv")
    if b6_file:
        b6_data = load_csv(b6_file)
        print(f"   {len(b6_data)} items")
        
        for row in b6_data:
            master_data.append({
                'id': id_counter,
                'sub_level_id': row.get('sub_level_id', '6-1'),
                'type': row.get('type', 'vocabulary'),
                'arabic_text': row.get('arabic_text', ''),
                'korean_meaning': row.get('korean_meaning', ''),
                'root': row.get('root', ''),
                'form': int(row.get('form', 1) or 1),
                'pattern': '',
                'pos': 'verb',
                'cefr': 'B1'
            })
            id_counter += 1
    
    # 3. Load phrases (Level 2)
    print("\n📂 Loading phrases...")
    l2_file = find_latest_file(GENERATED_DIR, "level2_*.csv")
    if l2_file:
        l2_data = load_csv(l2_file)
        print(f"   {len(l2_data)} items")
        
        for row in l2_data:
            master_data.append({
                'id': id_counter,
                'sub_level_id': '2-5',  # 연결형 I
                'type': 'phrase',
                'arabic_text': row.get('arabic_text', ''),
                'korean_meaning': row.get('korean_meaning', ''),
                'root': row.get('root', ''),
                'form': 0,
                'pattern': '',
                'pos': 'phrase',
                'cefr': 'A2'
            })
            id_counter += 1
    
    # 4. Load plurals (Level 3)
    print("\n📂 Loading plurals...")
    l3_file = find_latest_file(GENERATED_DIR, "level3_*.csv")
    if l3_file:
        l3_data = load_csv(l3_file)
        print(f"   {len(l3_data)} items")
        
        for row in l3_data:
            master_data.append({
                'id': id_counter,
                'sub_level_id': '2-8',  # 불규칙 복수
                'type': 'plural_pair',
                'arabic_text': row.get('arabic_text', ''),
                'korean_meaning': row.get('korean_meaning', ''),
                'root': row.get('root', ''),
                'form': 0,
                'pattern': row.get('pattern', ''),
                'pos': 'noun',
                'cefr': 'A2'
            })
            id_counter += 1
    
    # 5. Load sentences (Level 8)
    print("\n📂 Loading sentences...")
    l8_file = find_latest_file(GENERATED_DIR, "level8_*.csv")
    if l8_file:
        l8_data = load_csv(l8_file)
        print(f"   {len(l8_data)} items")
        
        for row in l8_data:
            master_data.append({
                'id': id_counter,
                'sub_level_id': '12-1',  # 상태형
                'type': 'sentence',
                'arabic_text': row.get('arabic_text', ''),
                'korean_meaning': row.get('korean_meaning', ''),
                'root': '',
                'form': int(row.get('verb_form', 1) or 1),
                'pattern': '',
                'pos': 'sentence',
                'cefr': 'B2'
            })
            id_counter += 1
    
    print("\n" + "="*60)
    print(f"📊 Total: {len(master_data)} items")
    
    # Sort by sub-level
    def sort_key(item):
        sl = item['sub_level_id']
        parts = sl.split('-')
        return (int(parts[0]), int(parts[1]))
    
    master_data.sort(key=sort_key)
    
    # Re-number IDs
    for i, item in enumerate(master_data):
        item['id'] = 10001 + i
    
    # Statistics by sub-level
    sublevel_counts = defaultdict(int)
    for item in master_data:
        sublevel_counts[item['sub_level_id']] += 1
    
    print("\n📊 Distribution by Sub-level:")
    for sl in sorted(sublevel_counts.keys(), key=lambda x: (int(x.split('-')[0]), int(x.split('-')[1]))):
        print(f"   {sl}: {sublevel_counts[sl]}")
    
    # Save
    print(f"\n💾 Saving to {OUTPUT_FILE}...")
    
    headers = ['id', 'sub_level_id', 'type', 'arabic_text', 'korean_meaning', 
               'root', 'form', 'pattern', 'pos', 'cefr']
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(master_data)
    
    print(f"✅ Saved {len(master_data)} items")
    
    # Summary
    print("\n" + "="*60)
    print("📊 FINAL SUMMARY")
    print("="*60)
    
    block_counts = defaultdict(int)
    for item in master_data:
        block = item['sub_level_id'].split('-')[0]
        block_counts[block] += 1
    
    print("\nBy Block:")
    for block in sorted(block_counts.keys(), key=int):
        print(f"   Block {block}: {block_counts[block]} items")
    
    type_counts = defaultdict(int)
    for item in master_data:
        type_counts[item['type']] += 1
    
    print("\nBy Type:")
    for t, c in type_counts.items():
        print(f"   {t}: {c}")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
spiral_distribution.py - Distributed Spiral Curriculum Generator
Merges vocabulary, phrases, plurals, verbs, sentences into 8 balanced levels

Based on Bruner's Spiral Curriculum Theory
"""

import csv
from pathlib import Path

BASE_DIR = Path("/Users/taewoo/Documents/ALP")
SORTED_VOCAB = BASE_DIR / "curriculum_data_sorted.csv"
VERB_FORMS = BASE_DIR / "verb_forms.csv"
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

def main():
    print("🌀 Spiral Curriculum Distribution")
    print("="*60)
    
    # Load sorted vocabulary
    vocab = load_csv(SORTED_VOCAB)
    print(f"📂 Vocabulary: {len(vocab)} words (CEFR sorted)")
    
    # Load verbs
    verbs = load_csv(VERB_FORMS)
    print(f"📂 Verbs: {len(verbs)} verbs")
    
    # Load generated data
    l2_file = find_latest_file(GENERATED_DIR, "level2_*.csv")
    l3_file = find_latest_file(GENERATED_DIR, "level3_*.csv")
    l8_file = find_latest_file(GENERATED_DIR, "level8_*.csv")
    
    l2_data = load_csv(l2_file) if l2_file else []
    l3_data = load_csv(l3_file) if l3_file else []
    l8_data = load_csv(l8_file) if l8_file else []
    
    print(f"📂 Level 2 Phrases: {len(l2_data)}")
    print(f"📂 Level 3 Plurals: {len(l3_data)}")
    print(f"📂 Level 8 Sentences: {len(l8_data)}")
    
    # Spiral Distribution Cuts (based on 5366 words)
    # Level 1: 0-500 (500 words)
    # Level 2: 500-800 (300 words)
    # Level 3: 800-1100 (300 words)
    # Level 4: 1100-1500 (400 words)
    # Level 5: 1500-1900 (400 words)
    # Level 6: 1900-2300 (400 words)
    # Level 7: 2300-2600 (300 words)
    # Level 8: 2600-end (remaining)
    cuts = [0, 500, 800, 1100, 1500, 1900, 2300, 2600, len(vocab)]
    
    master_data = []
    id_counter = 10001
    
    print("\n🔄 Distributing...")
    
    for level in range(1, 9):
        level_items = []
        
        # 1. Add vocabulary slice (Side Dish)
        start_idx = cuts[level - 1]
        end_idx = cuts[level]
        vocab_slice = vocab[start_idx:end_idx]
        
        for row in vocab_slice:
            level_items.append({
                'id': id_counter,
                'level': level,
                'type': 'vocabulary',
                'arabic_text': row.get('arabic_word', ''),
                'korean_meaning': row.get('meaning_korean', ''),
                'root': row.get('root', ''),
                'form': row.get('verb_form', '0'),
                'pattern': row.get('pattern', ''),
                'gender': '',
                'phrase_components': '',
                'singular_form': '',
                'sentence_analysis': '',
                'cefr': row.get('cefr', 'B1')
            })
            id_counter += 1
        
        # 2. Add Structure Data (Main Dish)
        if level == 2:  # Phrases
            for row in l2_data:
                level_items.append({
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
                    'sentence_analysis': '',
                    'cefr': 'A2'
                })
                id_counter += 1
        
        elif level == 3:  # Plurals
            for row in l3_data:
                level_items.append({
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
                    'sentence_analysis': '',
                    'cefr': 'A2'
                })
                id_counter += 1
        
        elif level == 8:  # Sentences
            for row in l8_data:
                level_items.append({
                    'id': id_counter,
                    'level': 8,
                    'type': 'sentence',
                    'arabic_text': row.get('arabic_text', ''),
                    'korean_meaning': row.get('korean_meaning', ''),
                    'root': '',
                    'form': row.get('verb_form', 1),
                    'pattern': '',
                    'gender': '',
                    'phrase_components': '',
                    'singular_form': '',
                    'sentence_analysis': row.get('sentence_analysis', ''),
                    'cefr': 'B2'
                })
                id_counter += 1
        
        # 3. Add Verbs (Main Dish for L4-L7)
        form_map = {
            4: [1, 2],
            5: [3, 4],
            6: [5, 6, 7],
            7: [8, 9, 10]
        }
        
        if level in form_map:
            target_forms = form_map[level]
            for row in verbs:
                form = int(row.get('verb_form', 0) or 0)
                if form in target_forms:
                    level_items.append({
                        'id': id_counter,
                        'level': level,
                        'type': 'vocabulary',
                        'arabic_text': row.get('arabic_word', ''),
                        'korean_meaning': row.get('nuance_korean', '') or row.get('meaning_korean', ''),
                        'root': row.get('root', ''),
                        'form': form,
                        'pattern': row.get('pattern', ''),
                        'gender': '',
                        'phrase_components': '',
                        'singular_form': '',
                        'sentence_analysis': '',
                        'cefr': 'B1'
                    })
                    id_counter += 1
        
        master_data.extend(level_items)
        print(f"   Level {level}: {len(level_items)} items")
    
    # Save
    print("\n💾 Saving...")
    
    headers = ['id', 'level', 'type', 'arabic_text', 'korean_meaning', 'root',
               'form', 'pattern', 'gender', 'phrase_components', 'singular_form',
               'sentence_analysis', 'cefr']
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(master_data)
    
    print(f"✅ Saved: {OUTPUT_FILE}")
    print(f"📊 Total: {len(master_data)} items")
    
    # Summary
    print("\n📊 SPIRAL CURRICULUM SUMMARY")
    print("="*60)
    
    from collections import Counter
    level_counts = Counter(row['level'] for row in master_data)
    type_counts = Counter(row['type'] for row in master_data)
    
    print("\nBy Level:")
    for level in sorted(level_counts.keys()):
        print(f"   Level {level}: {level_counts[level]} items")
    
    print("\nBy Type:")
    for t, count in type_counts.items():
        print(f"   {t}: {count}")

if __name__ == "__main__":
    main()

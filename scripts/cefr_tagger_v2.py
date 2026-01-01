#!/usr/bin/env python3
"""
cefr_tagger_v2.py - Simpler CEFR tagging with small batches
"""

import os
import sys
import csv
import time
from pathlib import Path

try:
    from google import genai
    from google.genai import types
except ImportError:
    print("❌ pip install google-genai")
    sys.exit(1)

BASE_DIR = Path("/Users/taewoo/Documents/ALP")
INPUT_FILE = BASE_DIR / "ArabicLearning/ArabicLearning/Resources/curriculum_data.csv"
OUTPUT_FILE = BASE_DIR / "curriculum_data_sorted.csv"

BATCH_SIZE = 20
MODEL_NAME = "gemini-2.5-flash"

def load_vocabulary():
    """Load vocabulary from CSV"""
    vocab = []
    with open(INPUT_FILE, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            word = row.get('arabic_word', '')
            meaning = row.get('meaning_korean', '')
            if word:
                vocab.append({
                    'arabic_word': word,
                    'meaning_korean': meaning or '',
                    'root': row.get('root', ''),
                    'verb_form': row.get('verb_form', '0'),
                    'pattern': row.get('pattern', ''),
                    'example_sentence': row.get('example_sentence', ''),
                    'cefr': 'A2'  # Default middle level
                })
    return vocab

def tag_batch(client, words: list) -> dict:
    """Tag batch with simple line-by-line output"""
    word_list = "\n".join([f"{i+1}. {w['meaning_korean']}" for i, w in enumerate(words)])
    
    prompt = f"""Assign CEFR levels (A1, A2, B1, B2) to these Korean meanings of Arabic words.

A1 = basic (family, numbers, colors, body, food, animals)
A2 = elementary (daily activities, common verbs, weather)
B1 = intermediate (emotions, work, abstract concepts)
B2 = advanced (academic, technical, rare)

Words:
{word_list}

Reply with ONLY the level for each, one per line:
1. A1
2. A2
..."""

    try:
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.2,
                max_output_tokens=500,
            )
        )
        
        lines = response.text.strip().split('\n')
        results = {}
        
        for i, line in enumerate(lines):
            if i >= len(words):
                break
            # Parse "1. A1" or just "A1"
            level = line.strip().upper()
            for cefr in ['A1', 'A2', 'B1', 'B2']:
                if cefr in level:
                    results[i] = cefr
                    break
        
        return results
        
    except Exception as e:
        print(f"⚠️ {e}")
        return {}

def main():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("❌ Set GEMINI_API_KEY")
        sys.exit(1)
    
    print("🏷️ CEFR Tagger v2 (Small Batches)")
    print("="*50)
    
    print("\n📂 Loading vocabulary...")
    vocab = load_vocabulary()
    print(f"   {len(vocab)} words")
    
    client = genai.Client(api_key=api_key)
    
    total_batches = (len(vocab) + BATCH_SIZE - 1) // BATCH_SIZE
    tagged = 0
    
    print(f"\n🤖 Tagging ({BATCH_SIZE} words/batch, {total_batches} batches)...")
    
    for batch_idx in range(0, len(vocab), BATCH_SIZE):
        batch_num = batch_idx // BATCH_SIZE + 1
        batch = vocab[batch_idx:batch_idx + BATCH_SIZE]
        
        print(f"   [{batch_num}/{total_batches}]", end=" ", flush=True)
        
        results = tag_batch(client, batch)
        
        for idx, cefr in results.items():
            if batch_idx + idx < len(vocab):
                vocab[batch_idx + idx]['cefr'] = cefr
                tagged += 1
        
        print(f"✓ {len(results)}")
        time.sleep(0.5)
    
    print(f"\n✅ Tagged {tagged}/{len(vocab)}")
    
    # Sort
    cefr_order = {'A1': 0, 'A2': 1, 'B1': 2, 'B2': 3}
    vocab.sort(key=lambda x: cefr_order.get(x['cefr'], 1))
    
    # Stats
    counts = {'A1': 0, 'A2': 0, 'B1': 0, 'B2': 0}
    for w in vocab:
        counts[w.get('cefr', 'A2')] = counts.get(w.get('cefr', 'A2'), 0) + 1
    
    print("\n📊 Distribution:")
    for lvl in ['A1', 'A2', 'B1', 'B2']:
        print(f"   {lvl}: {counts.get(lvl, 0)}")
    
    # Save
    headers = ['arabic_word', 'meaning_korean', 'root', 'verb_form', 'pattern', 
               'example_sentence', 'cefr']
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(vocab)
    
    print(f"\n💾 Saved: {OUTPUT_FILE}")
    
if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
cefr_tagger.py - Tag Arabic vocabulary with CEFR levels using Gemini 2.5
Sorts vocabulary from A1 (easiest) to B2 (hardest) for Spiral Curriculum

Usage:
    export GEMINI_API_KEY="your-key"
    python3 cefr_tagger.py
"""

import os
import sys
import json
import csv
import time
from pathlib import Path
from datetime import datetime

try:
    from google import genai
    from google.genai import types
except ImportError:
    print("❌ pip install google-genai")
    sys.exit(1)

# Paths
BASE_DIR = Path("/Users/taewoo/Documents/ALP")
INPUT_FILE = BASE_DIR / "ArabicLearning/ArabicLearning/Resources/curriculum_data.csv"
OUTPUT_FILE = BASE_DIR / "curriculum_data_sorted.csv"

BATCH_SIZE = 100
MODEL_NAME = "gemini-2.5-flash"

def load_vocabulary():
    """Load vocabulary from curriculum_data.csv"""
    vocab = []
    with open(INPUT_FILE, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            word = row.get('arabic_word', '')
            meaning = row.get('meaning_korean', '')
            if word and meaning:
                vocab.append({
                    'arabic_word': word,
                    'meaning_korean': meaning,
                    'root': row.get('root', ''),
                    'verb_form': row.get('verb_form', '0'),
                    'pattern': row.get('pattern', ''),
                    'example_sentence': row.get('example_sentence', ''),
                    'cefr': 'A1'  # Default, will be updated
                })
    return vocab

def tag_batch(client, words: list) -> dict:
    """Tag a batch of words with CEFR levels"""
    word_list = [w['arabic_word'] + " (" + w['meaning_korean'] + ")" for w in words[:BATCH_SIZE]]
    
    prompt = f"""You are an Arabic language expert. Assign CEFR levels to these Arabic words.

CEFR Levels:
- A1: Basic vocabulary (family, numbers, colors, greetings, common objects)
- A2: Elementary vocabulary (daily activities, simple actions, common adjectives)
- B1: Intermediate vocabulary (abstract concepts, business terms, emotions)
- B2: Upper-intermediate vocabulary (academic, technical, rare words)

Words to classify:
{chr(10).join(word_list)}

Return a JSON array with the word and its CEFR level:
[{{"word": "أب", "cefr": "A1"}}, ...]

Only return the JSON array, no explanation:"""

    try:
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.3,
                max_output_tokens=4096,
            )
        )
        
        text = response.text.strip()
        if "```" in text:
            text = text.split("```")[1]
            if text.startswith("json"):
                text = text[4:]
        text = text.strip()
        
        results = json.loads(text)
        return {r['word'].split(' ')[0]: r['cefr'] for r in results}
        
    except Exception as e:
        print(f"   ⚠️ Error: {e}")
        return {}

def main():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("❌ Set GEMINI_API_KEY")
        sys.exit(1)
    
    print("🏷️ CEFR Vocabulary Tagger")
    print("="*50)
    
    # Load vocabulary
    print("\n📂 Loading vocabulary...")
    vocab = load_vocabulary()
    print(f"   Loaded {len(vocab)} words")
    
    # Initialize client
    client = genai.Client(api_key=api_key)
    
    # Tag in batches
    print(f"\n🤖 Tagging with Gemini ({BATCH_SIZE} words per batch)...")
    total_batches = (len(vocab) + BATCH_SIZE - 1) // BATCH_SIZE
    
    tagged_count = 0
    for batch_idx in range(0, len(vocab), BATCH_SIZE):
        batch_num = batch_idx // BATCH_SIZE + 1
        batch = vocab[batch_idx:batch_idx + BATCH_SIZE]
        
        print(f"   Batch {batch_num}/{total_batches}...", end=" ")
        
        cefr_map = tag_batch(client, batch)
        
        # Apply tags
        for word in batch:
            arabic = word['arabic_word']
            if arabic in cefr_map:
                word['cefr'] = cefr_map[arabic]
                tagged_count += 1
        
        print(f"Tagged {len(cefr_map)} words")
        time.sleep(1)  # Rate limiting
    
    print(f"\n✅ Tagged {tagged_count}/{len(vocab)} words")
    
    # Sort by CEFR
    cefr_order = {'A1': 0, 'A2': 1, 'B1': 2, 'B2': 3}
    vocab.sort(key=lambda x: cefr_order.get(x['cefr'], 4))
    
    # Count by level
    cefr_counts = {'A1': 0, 'A2': 0, 'B1': 0, 'B2': 0}
    for w in vocab:
        cefr = w.get('cefr', 'A1')
        if cefr in cefr_counts:
            cefr_counts[cefr] += 1
    
    print("\n📊 CEFR Distribution:")
    for level, count in cefr_counts.items():
        print(f"   {level}: {count} words")
    
    # Save sorted file
    print(f"\n💾 Saving to {OUTPUT_FILE}...")
    
    headers = ['arabic_word', 'meaning_korean', 'root', 'verb_form', 'pattern', 
               'example_sentence', 'cefr']
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(vocab)
    
    print(f"✅ Saved {len(vocab)} words sorted by CEFR (A1 → B2)")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())

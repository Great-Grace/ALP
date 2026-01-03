#!/usr/bin/env python3
"""
pos_tagger.py - AI Part-of-Speech Tagger for Arabic vocabulary
Tags nouns, adjectives, prepositions for Block 1-2 assignment

Usage:
    export GEMINI_API_KEY="your-key"
    python3 pos_tagger.py
"""

import os
import sys
import csv
import json
import time
import re
from pathlib import Path

try:
    from google import genai
    from google.genai import types
except ImportError:
    print("❌ pip install google-genai")
    sys.exit(1)

# Configuration
BASE_DIR = Path("/Users/taewoo/Documents/ALP")
INPUT_FILE = BASE_DIR / "curriculum_data_sorted.csv"
OUTPUT_FILE = BASE_DIR / "curriculum_data_pos_tagged.csv"

BATCH_SIZE = 50
MODEL_NAME = "gemini-2.5-flash"

def load_vocabulary():
    """Load vocabulary that needs POS tagging (verb_form = 0)"""
    all_vocab = []
    with open(INPUT_FILE, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            all_vocab.append(dict(row))
    return all_vocab

def tag_pos_batch(client, words: list) -> dict:
    """Tag Part-of-Speech for a batch of words"""
    
    items_str = "\n".join([
        f"{i}: {w.get('arabic_word', '')} ({w.get('meaning_korean', '')})" 
        for i, w in enumerate(words)
    ])
    
    prompt = f"""You are an Arabic Grammatician. Classify the Part of Speech (POS) for these items.

Categories:
- "noun" (Common nouns, Proper nouns)
- "adj" (Adjectives, Colors, Descriptors)  
- "prep" (Prepositions, Conjunctions, Particles)
- "expression" (Greetings, Phrases)

Items:
{items_str}

Return JSON only: {{"0": "noun", "1": "adj", ...}}"""

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
        return {}

def main():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("❌ Set GEMINI_API_KEY")
        sys.exit(1)
    
    print("🏷️ POS Tagger for Arabic Vocabulary")
    print("="*60)
    
    # Load vocabulary
    vocab = load_vocabulary()
    print(f"📂 Loaded {len(vocab)} words")
    
    # Filter: only words that need tagging (verb_form = 0 or empty)
    targets = []
    target_indices = []
    
    for idx, w in enumerate(vocab):
        form = str(w.get('verb_form', '0') or '0')
        if form == '0' or form == '':
            targets.append(w)
            target_indices.append(idx)
    
    print(f"🎯 Need to tag: {len(targets)} items (verb_form = 0)")
    
    # Initialize client
    client = genai.Client(api_key=api_key)
    
    # Process in batches
    total_batches = (len(targets) + BATCH_SIZE - 1) // BATCH_SIZE
    tagged_count = 0
    
    print(f"\n🤖 Tagging...")
    
    for batch_idx in range(0, len(targets), BATCH_SIZE):
        batch_num = batch_idx // BATCH_SIZE + 1
        batch = targets[batch_idx:batch_idx + BATCH_SIZE]
        batch_indices = target_indices[batch_idx:batch_idx + BATCH_SIZE]
        
        print(f"   [{batch_num}/{total_batches}]", end=" ", flush=True)
        
        tags = tag_pos_batch(client, batch)
        
        # Apply tags to original vocab
        for str_idx, pos in tags.items():
            try:
                local_idx = int(str_idx)
                if local_idx < len(batch_indices):
                    global_idx = batch_indices[local_idx]
                    valid_pos = pos.lower().strip()
                    if valid_pos in ['noun', 'adj', 'prep', 'expression']:
                        vocab[global_idx]['pos'] = valid_pos
                        tagged_count += 1
            except:
                pass
        
        noun_count = sum(1 for i in range(len(batch)) if tags.get(str(i)) == 'noun')
        adj_count = sum(1 for i in range(len(batch)) if tags.get(str(i)) == 'adj')
        print(f"✓ {noun_count} nouns, {adj_count} adj")
        
        time.sleep(0.5)
    
    print(f"\n✅ Tagged {tagged_count}/{len(targets)}")
    
    # Statistics
    pos_counts = {'noun': 0, 'adj': 0, 'prep': 0, 'expression': 0, 'verb': 0, 'untagged': 0}
    for w in vocab:
        form = str(w.get('verb_form', '0') or '0')
        if form != '0':
            pos_counts['verb'] += 1
        elif 'pos' in w and w['pos']:
            pos_counts[w['pos']] = pos_counts.get(w['pos'], 0) + 1
        else:
            pos_counts['untagged'] += 1
    
    print("\n📊 Final Distribution:")
    for pos, count in pos_counts.items():
        print(f"   {pos}: {count}")
    
    # Save
    fieldnames = list(vocab[0].keys())
    if 'pos' not in fieldnames:
        fieldnames.append('pos')
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(vocab)
    
    print(f"\n💾 Saved: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()

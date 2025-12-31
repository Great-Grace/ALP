#!/usr/bin/env python3
"""
generate_curriculum.py
Combines sample_words.csv and verb_forms.csv into a unified curriculum_data.csv
with proper level assignment.

Level Distribution:
- Level 1: sample_words.csv (nouns, phrases, basic expressions)
- Level 2: verb_forms.csv where verb_form = 1 (Form I verbs)
- Level 3: verb_forms.csv where verb_form = 2-3
- Level 4: verb_forms.csv where verb_form = 4-6
- Level 5: verb_forms.csv where verb_form = 7-10
"""

import pandas as pd
import os
from pathlib import Path

# Paths
BASE_DIR = Path(__file__).parent.parent
SAMPLE_WORDS_PATH = BASE_DIR.parent / "sample_words.csv"  # /Users/taewoo/Documents/ALP/sample_words.csv
VERB_FORMS_PATH = BASE_DIR / "ArabicLearning" / "Resources" / "verb_forms.csv"
OUTPUT_PATH = BASE_DIR / "ArabicLearning" / "Resources" / "curriculum_data.csv"

def load_sample_words():
    """Load sample_words.csv and assign Level 1"""
    print(f"📖 Loading sample_words.csv from {SAMPLE_WORDS_PATH}...")
    
    if not SAMPLE_WORDS_PATH.exists():
        print(f"⚠️ sample_words.csv not found at {SAMPLE_WORDS_PATH}")
        return pd.DataFrame()
    
    df = pd.read_csv(SAMPLE_WORDS_PATH, encoding='utf-8-sig')
    print(f"   Found {len(df)} rows")
    
    # Standardize columns
    result = pd.DataFrame({
        'arabic_word': df['arabic'],
        'meaning_korean': df['korean'],
        'meaning_primary': df['korean'],
        'example_sentence': df.get('example_sentence', ''),
        'sentence_meaning': df.get('sentence_korean', ''),
        'chapter': df.get('chapter', ''),
        'root': '',
        'verb_form': 0,  # Not a verb
        'pattern': '',
        'level': 1,  # All sample_words go to Level 1
        'source': 'sample_words'
    })
    
    return result

def load_verb_forms():
    """Load verb_forms.csv and assign levels based on verb_form"""
    print(f"📖 Loading verb_forms.csv from {VERB_FORMS_PATH}...")
    
    if not VERB_FORMS_PATH.exists():
        print(f"⚠️ verb_forms.csv not found at {VERB_FORMS_PATH}")
        return pd.DataFrame()
    
    df = pd.read_csv(VERB_FORMS_PATH, encoding='utf-8')
    print(f"   Found {len(df)} rows")
    
    # Assign levels based on verb_form
    def get_level(verb_form):
        try:
            vf = int(verb_form)
            if vf == 1:
                return 2  # Form I → Level 2
            elif vf in [2, 3]:
                return 3  # Form II-III → Level 3
            elif vf in [4, 5, 6]:
                return 4  # Form IV-VI → Level 4
            else:
                return 5  # Form VII-X → Level 5
        except:
            return 2  # Default to Level 2
    
    result = pd.DataFrame({
        'arabic_word': df['arabic_word'],
        'meaning_korean': df.get('meaning_korean', ''),
        'meaning_primary': df.get('meaning_primary', df.get('meaning_korean', '')),
        'example_sentence': df.get('example_sentence', ''),
        'sentence_meaning': df.get('sentence_meaning', ''),
        'chapter': '',
        'root': df.get('root', ''),
        'verb_form': df['verb_form'],
        'pattern': df.get('pattern', ''),
        'level': df['verb_form'].apply(get_level),
        'source': 'verb_forms'
    })
    
    return result

def generate_reading_passages(sample_df):
    """Extract unique example sentences as reading passages"""
    print("📚 Generating reading passages from example sentences...")
    
    if sample_df.empty:
        return []
    
    # Group by chapter and create passages
    passages = []
    for chapter, group in sample_df.groupby('chapter'):
        sentences = group['example_sentence'].dropna().unique()
        if len(sentences) > 0:
            passage_text = ' '.join(sentences[:10])  # Max 10 sentences per passage
            translations = group['sentence_meaning'].dropna().unique()
            passage_translation = ' '.join(translations[:10])
            
            passages.append({
                'title': f"{chapter} 읽기",
                'content': passage_text,
                'translation': passage_translation,
                'level': 1,
                'chapter': chapter
            })
    
    print(f"   Generated {len(passages)} reading passages")
    return passages

def main():
    print("=" * 50)
    print("🚀 Curriculum Data Generator")
    print("=" * 50)
    
    # Load data
    sample_df = load_sample_words()
    verb_df = load_verb_forms()
    
    # Combine
    combined = pd.concat([sample_df, verb_df], ignore_index=True)
    
    # Remove duplicates based on arabic_word
    combined = combined.drop_duplicates(subset=['arabic_word'], keep='first')
    
    # Sort by level, then by source
    combined = combined.sort_values(['level', 'source', 'arabic_word'])
    
    # Save
    print(f"\n💾 Saving curriculum_data.csv to {OUTPUT_PATH}...")
    combined.to_csv(OUTPUT_PATH, index=False, encoding='utf-8')
    
    # Stats
    print("\n📊 Level Distribution:")
    level_counts = combined['level'].value_counts().sort_index()
    for level, count in level_counts.items():
        print(f"   Level {level}: {count} words")
    
    print(f"\n✅ Total: {len(combined)} words saved to curriculum_data.csv")
    
    # Generate reading passages JSON
    passages = generate_reading_passages(sample_df)
    if passages:
        import json
        passages_path = OUTPUT_PATH.parent / "reading_passages.json"
        with open(passages_path, 'w', encoding='utf-8') as f:
            json.dump(passages, f, ensure_ascii=False, indent=2)
        print(f"📖 Saved {len(passages)} reading passages to reading_passages.json")
    
    print("\n🎉 Done!")

if __name__ == "__main__":
    main()

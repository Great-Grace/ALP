#!/usr/bin/env python3
"""
data_audit.py - 8-Level Curriculum Data Gap Analysis
Analyzes current CSVs and generates template for missing data
"""

import csv
import os
import json
from collections import defaultdict
from pathlib import Path

# Configuration
BASE_DIR = Path("/Users/taewoo/Documents/ALP")
CURRICULUM_CSV = BASE_DIR / "ArabicLearning/ArabicLearning/Resources/curriculum_data.csv"
VERB_FORMS_CSV = BASE_DIR / "verb_forms.csv"
SAMPLE_WORDS_CSV = BASE_DIR / "sample_words.csv"
OUTPUT_DIR = BASE_DIR / "ArabicLearning/scripts"

# 8-Level Curriculum Definition
LEVEL_DEFINITIONS = {
    1: {"name": "기초 동사 I", "type": "vocabulary", "focus": "1형 동사"},
    2: {"name": "명사-형용사 일치", "type": "phrase", "focus": "Noun-Adj Agreement"},
    3: {"name": "단수-복수 매핑", "type": "plural_pair", "focus": "Singular-Plural"},
    4: {"name": "파생 동사 I", "type": "vocabulary", "focus": "2-3형 동사"},
    5: {"name": "파생 동사 II", "type": "vocabulary", "focus": "4-5형 동사"},
    6: {"name": "파생 동사 III", "type": "vocabulary", "focus": "6-7형 동사"},
    7: {"name": "파생 동사 IV", "type": "vocabulary", "focus": "8-10형 동사"},
    8: {"name": "복합 문장", "type": "sentence", "focus": "Sentence Analysis"},
}

def load_csv(filepath):
    """Load CSV file and return list of dicts"""
    if not filepath.exists():
        print(f"⚠️  File not found: {filepath}")
        return []
    
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        return list(reader)

def analyze_curriculum_data(rows):
    """Analyze curriculum_data.csv for level distribution"""
    level_counts = defaultdict(int)
    has_root = 0
    has_sentence = 0
    
    for row in rows:
        level = row.get('level', '1')
        try:
            level_counts[int(level)] += 1
        except:
            level_counts[1] += 1
        
        if row.get('root'):
            has_root += 1
        if row.get('example_sentence'):
            has_sentence += 1
    
    return {
        'total': len(rows),
        'levels': dict(level_counts),
        'has_root': has_root,
        'has_sentence': has_sentence,
    }

def analyze_verb_forms(rows):
    """Analyze verb_forms.csv for form distribution"""
    form_counts = defaultdict(int)
    
    for row in rows:
        form = row.get('verb_form', '1')
        try:
            form_counts[int(form)] += 1
        except:
            form_counts[1] += 1
    
    return {
        'total': len(rows),
        'forms': dict(form_counts),
    }

def check_phrase_data(rows):
    """Check for Noun-Adjective phrase data (Level 2)"""
    # Looking for multi-word entries or phrase markers
    phrases = [r for r in rows if ' ' in r.get('arabic_word', '') or 
               r.get('type', '') == 'phrase']
    return len(phrases)

def check_plural_data(rows):
    """Check for Singular-Plural mapping data (Level 3)"""
    # Looking for singular_id or explicit plural markers
    plurals = [r for r in rows if r.get('singular_id') or 
               r.get('plural_form') or 
               'جمع' in r.get('pattern', '')]
    return len(plurals)

def check_sentence_data(rows):
    """Check for sentence analysis data (Level 8)"""
    # Looking for sentence_analysis field
    sentences = [r for r in rows if r.get('sentence_analysis')]
    return len(sentences)

def generate_warning_report(curriculum_stats, verb_stats, phrase_count, plural_count, sentence_count):
    """Generate warning report for missing data"""
    print("\n" + "="*60)
    print("🔍 DATA GAP ANALYSIS REPORT")
    print("="*60)
    
    print("\n📊 CURRENT DATA SUMMARY")
    print(f"  curriculum_data.csv: {curriculum_stats['total']} rows")
    print(f"  verb_forms.csv: {verb_stats['total']} rows")
    print(f"  Root coverage: {curriculum_stats['has_root']}/{curriculum_stats['total']} ({curriculum_stats['has_root']/max(1,curriculum_stats['total'])*100:.1f}%)")
    print(f"  Has example sentences: {curriculum_stats['has_sentence']}/{curriculum_stats['total']}")
    
    print("\n📈 LEVEL DISTRIBUTION (curriculum_data.csv)")
    for level in sorted(curriculum_stats.get('levels', {}).keys()):
        count = curriculum_stats['levels'][level]
        print(f"  Level {level}: {count} items")
    
    print("\n🔢 VERB FORM DISTRIBUTION (verb_forms.csv)")
    for form in sorted(verb_stats.get('forms', {}).keys()):
        count = verb_stats['forms'][form]
        print(f"  Form {form}: {count} items")
    
    print("\n" + "="*60)
    print("⚠️  GAP WARNINGS")
    print("="*60)
    
    warnings = []
    
    # Check Level 2 (Phrases)
    if phrase_count < 10:
        warnings.append(f"❌ Level 2 (Noun-Adj Phrases): {phrase_count} items - NEEDS 50+ PHRASES")
    else:
        print(f"✅ Level 2 (Phrases): {phrase_count} items")
    
    # Check Level 3 (Plurals)
    if plural_count < 10:
        warnings.append(f"❌ Level 3 (Singular-Plural): {plural_count} items - NEEDS 100+ PAIRS")
    else:
        print(f"✅ Level 3 (Plurals): {plural_count} items")
    
    # Check Level 8 (Sentences)
    if sentence_count < 10:
        warnings.append(f"❌ Level 8 (Sentence Analysis): {sentence_count} items - NEEDS 30+ SENTENCES")
    else:
        print(f"✅ Level 8 (Sentences): {sentence_count} items")
    
    for warning in warnings:
        print(warning)
    
    print("\n" + "="*60)
    print("📋 SUMMARY")
    print("="*60)
    if warnings:
        print(f"Total gaps found: {len(warnings)}")
        print("Action Required: Generate missing data for Levels 2, 3, 8")
    else:
        print("All levels have sufficient data! ✅")
    
    return warnings

def generate_template_csv(output_path):
    """Generate empty template CSV with new schema"""
    headers = [
        'id', 'level', 'type', 'arabic_text', 'korean_meaning',
        'root', 'form', 'part_of_speech', 'pattern', 'gender',
        'plural_form', 'singular_id', 'phrase_components',
        'example_sentence', 'sentence_analysis', 'audio_key', 'verified'
    ]
    
    # Sample rows for each type
    samples = [
        # Level 1 - Vocabulary
        {'id': 1, 'level': 1, 'type': 'vocabulary', 'arabic_text': 'كَتَبَ',
         'korean_meaning': '쓰다', 'root': 'ك-ت-ب', 'form': 1},
        
        # Level 2 - Phrase
        {'id': 101, 'level': 2, 'type': 'phrase', 'arabic_text': 'الْبَيْتُ الْكَبِيرُ',
         'korean_meaning': '큰 집', 'phrase_components': '{"noun":"بَيْت","adj":"كَبِير"}'},
        
        # Level 3 - Plural Pair
        {'id': 201, 'level': 3, 'type': 'plural_pair', 'arabic_text': 'طُلَّابٌ',
         'korean_meaning': '학생들', 'singular_id': 200, 'pattern': 'فُعَّالٌ'},
        
        # Level 8 - Sentence
        {'id': 801, 'level': 8, 'type': 'sentence', 'arabic_text': 'كَتَبَ الطَّالِبُ رِسَالَةً',
         'korean_meaning': '학생이 편지를 썼다',
         'sentence_analysis': '{"subject":"الطَّالِبُ","verb":"كَتَبَ","object":"رِسَالَةً"}'},
    ]
    
    with open(output_path, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        for sample in samples:
            row = {h: sample.get(h, '') for h in headers}
            writer.writerow(row)
    
    print(f"\n✅ Template generated: {output_path}")
    print(f"   Headers: {len(headers)} columns")
    print(f"   Sample rows: {len(samples)} (1 per level type)")

def main():
    print("🚀 Data Audit Script for 8-Level Curriculum")
    print("-" * 60)
    
    # Load data
    print("\n📂 Loading CSV files...")
    curriculum_rows = load_csv(CURRICULUM_CSV)
    verb_rows = load_csv(VERB_FORMS_CSV)
    sample_rows = load_csv(SAMPLE_WORDS_CSV)
    
    # Analyze
    print("🔍 Analyzing data...")
    curriculum_stats = analyze_curriculum_data(curriculum_rows)
    verb_stats = analyze_verb_forms(verb_rows)
    
    # Check specific requirements
    phrase_count = check_phrase_data(curriculum_rows)
    plural_count = check_plural_data(curriculum_rows)
    sentence_count = check_sentence_data(curriculum_rows)
    
    # Generate report
    warnings = generate_warning_report(
        curriculum_stats, verb_stats,
        phrase_count, plural_count, sentence_count
    )
    
    # Generate template
    template_path = OUTPUT_DIR / "target_data_template.csv"
    generate_template_csv(template_path)
    
    print("\n" + "="*60)
    print("🏁 Audit Complete")
    print("="*60)
    
    return len(warnings)

if __name__ == "__main__":
    exit(main())

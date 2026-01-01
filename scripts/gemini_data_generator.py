#!/usr/bin/env python3
"""
gemini_data_generator.py - Arabic Learning Data Generator (2026 Edition)
Uses Gemini 2.5 Flash with Hybrid Reasoning for grammar-accurate Arabic data

CTO Recommendation: Gemini 2.5 Flash
- Thinking Budget: Internal grammar validation before output
- Cost: ~$0.05 for full dataset (~70원)
- Accuracy: Best-in-class for Tashkeel and I'rab

Usage:
    export GEMINI_API_KEY="your-api-key"
    python3 gemini_data_generator.py --level 2 --count 50
    python3 gemini_data_generator.py --level 3 --count 100
    python3 gemini_data_generator.py --level 8 --count 30
    python3 gemini_data_generator.py --all  # Generate all levels
"""

import os
import sys
import json
import csv
import time
import argparse
from pathlib import Path
from datetime import datetime

try:
    import google.generativeai as genai
except ImportError:
    print("❌ google-generativeai not installed.")
    print("Run: pip install google-generativeai")
    sys.exit(1)

# Configuration
OUTPUT_DIR = Path(__file__).parent / "generated_data"
OUTPUT_DIR.mkdir(exist_ok=True)

# 2026 Model Selection: Gemini 2.5 Flash (Hybrid Reasoning)
MODEL_NAME = "gemini-2.5-flash"

# Rate limiting (conservative for stability)
REQUEST_DELAY = 2.0  # seconds between requests

# ============================================================
# PROMPTS: Designed to leverage Thinking/Reasoning capabilities
# ============================================================

LEVEL_PROMPTS = {
    2: """You are an expert Arabic linguist using Gemini 2.5's reasoning capabilities.
Generate exactly {count} distinct Arabic noun-adjective phrases for Level 2.

**CRITICAL INSTRUCTION:**
Before generating the JSON, **THINK** step-by-step about the grammatical rules:
1. Gender Agreement: Masculine noun → Masculine adjective (كَبِيرٌ), Feminine → Feminine (كَبِيرَةٌ)
2. Definiteness: If noun has ال, adjective must also have ال
3. Tashkeel: Every letter must have correct harakat (فَتْحَة/ضَمَّة/كَسْرَة/سُكُون)

**Required Fields:**
- id: Starting from 20001
- level: 2
- type: "phrase"
- arabic_text: Full phrase with complete Tashkeel
- korean_meaning: Korean translation
- root: Arabic root (ك-ت-ب format)
- gender: "M" or "F"
- phrase_components: JSON object with "noun" and "adj" keys

Generate {count} rows as a JSON array.""",

    3: """You are an expert Arabic morphologist using Gemini 2.5's reasoning capabilities.
Generate exactly {count} singular-plural pairs focusing on BROKEN PLURALS (جمع التكسير).

**CRITICAL INSTRUCTION:**
Before generating the JSON, **THINK** step-by-step:
1. Identify the singular pattern (وَزْن)
2. Apply the correct broken plural pattern
3. Verify Tashkeel accuracy on both singular and plural forms

**Required Fields:**
- id: Starting from 30001
- level: 3
- type: "plural_pair"
- arabic_text: The PLURAL form with complete Tashkeel
- korean_meaning: Korean meaning of plural
- singular_form: The singular form with complete Tashkeel
- root: Arabic root (ك-ت-ب format)
- gender: "M" or "F"
- pattern: The plural pattern (e.g., فُعُول, أَفْعَال)

Generate {count} rows as a JSON array. Focus on high-frequency vocabulary.""",

    8: """You are an expert Arabic syntactician using Gemini 2.5's reasoning capabilities.
Generate exactly {count} complete Arabic sentences with grammatical analysis.

**CRITICAL INSTRUCTION:**
Before generating the JSON, **THINK** step-by-step about:
1. Sentence structure: Use VSO (Verb-Subject-Object) primarily
2. Case endings (I'rab): رَفْع for subject, نَصْب for object, جَرّ after preposition
3. Verb agreement: Verb agrees with subject in gender/number
4. Complete Tashkeel on every word

**Required Fields:**
- id: Starting from 80001
- level: 8
- type: "sentence"
- arabic_text: Complete sentence with full Tashkeel and I'rab
- korean_meaning: Korean translation
- verb_form: Verb form number (1-10)
- sentence_analysis: JSON object with "verb", "subject", "object", "preposition" keys

Generate {count} rows as a JSON array. Use diverse verb forms (I-X)."""
}

# Headers for CSV output
LEVEL_HEADERS = {
    2: ["id", "level", "type", "arabic_text", "korean_meaning", "root", "gender", "phrase_components"],
    3: ["id", "level", "type", "arabic_text", "korean_meaning", "singular_form", "root", "gender", "pattern"],
    8: ["id", "level", "type", "arabic_text", "korean_meaning", "verb_form", "sentence_analysis"]
}

def setup_gemini():
    """Initialize Gemini API with 2.5 Flash"""
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("❌ GEMINI_API_KEY environment variable not set!")
        print("Run: export GEMINI_API_KEY='your-api-key'")
        print("Get your key at: https://aistudio.google.com/app/apikey")
        sys.exit(1)
    
    genai.configure(api_key=api_key)
    print(f"🤖 Using model: {MODEL_NAME}")
    print(f"   → Hybrid Reasoning enabled for grammar validation")
    return genai.GenerativeModel(MODEL_NAME)

def generate_batch(model, level: int, count: int) -> list:
    """Generate a batch of data using Gemini 2.5 Flash with JSON output"""
    prompt = LEVEL_PROMPTS[level].format(count=count)
    
    try:
        response = model.generate_content(
            prompt,
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                temperature=0.4,  # Lower for grammar accuracy
                max_output_tokens=8192,
            )
        )
        
        # Parse JSON response
        data = json.loads(response.text)
        
        if isinstance(data, list):
            return data
        elif isinstance(data, dict) and 'data' in data:
            return data['data']
        else:
            print(f"⚠️  Unexpected response format")
            return []
            
    except json.JSONDecodeError as e:
        print(f"⚠️  JSON Parse Error: {e}")
        print(f"   Response preview: {response.text[:200]}...")
        return []
    except Exception as e:
        print(f"❌ API Error: {e}")
        return []

def validate_arabic(text: str) -> tuple:
    """Validate Arabic text with Tashkeel, return (is_valid, issues)"""
    issues = []
    
    if not text:
        return False, ["Empty text"]
    
    # Check for Arabic characters
    arabic_chars = sum(1 for c in text if '\u0600' <= c <= '\u06FF')
    if arabic_chars < 2:
        issues.append("Insufficient Arabic characters")
    
    # Check for Tashkeel (harakat)
    tashkeel_chars = sum(1 for c in text if '\u064B' <= c <= '\u0652')
    if tashkeel_chars < 1:
        issues.append("Missing Tashkeel")
    
    return len(issues) == 0, issues

def validate_row(row: dict, level: int) -> tuple:
    """Validate a data row, return (is_valid, errors)"""
    errors = []
    
    # Check required fields
    if 'arabic_text' not in row:
        return False, ["Missing arabic_text field"]
    
    # Validate Arabic text
    is_valid, issues = validate_arabic(row.get('arabic_text', ''))
    if not is_valid:
        errors.extend(issues)
    
    # Check Korean meaning
    if not row.get('korean_meaning'):
        errors.append("Missing Korean meaning")
    
    return len(errors) == 0, errors

def generate_level_data(level: int, total_count: int):
    """Generate data for a specific level"""
    print(f"\n{'='*60}")
    print(f"🚀 Generating Level {level} Data")
    print(f"{'='*60}")
    
    level_names = {
        2: "명사-형용사 구문 (Noun-Adjective Phrases)",
        3: "단수-복수 매핑 (Singular-Plural Pairs)",
        8: "복합 문장 분석 (Complex Sentences)"
    }
    print(f"Type: {level_names.get(level, 'Unknown')}")
    print(f"Target: {total_count} items")
    
    model = setup_gemini()
    
    all_rows = []
    batch_size = min(25, total_count)
    attempts = 0
    max_attempts = 5
    
    while len(all_rows) < total_count and attempts < max_attempts:
        attempts += 1
        remaining = total_count - len(all_rows)
        current_batch = min(batch_size, remaining)
        
        print(f"\n📡 Attempt {attempts}: Requesting {current_batch} items...")
        
        rows = generate_batch(model, level, current_batch)
        
        if not rows:
            print("   ⚠️  Empty response, retrying...")
            time.sleep(REQUEST_DELAY * 2)
            continue
        
        print(f"   📝 Received {len(rows)} rows")
        
        # Validate each row
        valid_rows = []
        for row in rows:
            is_valid, errors = validate_row(row, level)
            if is_valid:
                valid_rows.append(row)
            else:
                print(f"   ⚠️  Validation failed: {errors}")
        
        print(f"   ✅ Valid: {len(valid_rows)} rows")
        all_rows.extend(valid_rows)
        
        print(f"   📊 Progress: {len(all_rows)}/{total_count}")
        
        time.sleep(REQUEST_DELAY)
    
    return all_rows

def save_to_csv(rows: list, level: int) -> Path:
    """Save rows to CSV file"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"level{level}_gemini25_{timestamp}.csv"
    filepath = OUTPUT_DIR / filename
    
    headers = LEVEL_HEADERS[level]
    
    with open(filepath, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers, extrasaction='ignore')
        writer.writeheader()
        
        for row in rows:
            # Handle nested JSON fields
            if 'phrase_components' in row and isinstance(row['phrase_components'], dict):
                row['phrase_components'] = json.dumps(row['phrase_components'], ensure_ascii=False)
            if 'sentence_analysis' in row and isinstance(row['sentence_analysis'], dict):
                row['sentence_analysis'] = json.dumps(row['sentence_analysis'], ensure_ascii=False)
            
            writer.writerow(row)
    
    return filepath

def main():
    parser = argparse.ArgumentParser(
        description='Generate Arabic learning data using Gemini 2.5 Flash',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 gemini_data_generator.py --level 2 --count 50
  python3 gemini_data_generator.py --level 3 --count 100
  python3 gemini_data_generator.py --level 8 --count 30
  python3 gemini_data_generator.py --all
        """
    )
    parser.add_argument('--level', type=int, choices=[2, 3, 8],
                        help='Level to generate (2=phrases, 3=plurals, 8=sentences)')
    parser.add_argument('--count', type=int, default=50,
                        help='Number of items to generate (default: 50)')
    parser.add_argument('--all', action='store_true',
                        help='Generate all levels (50 L2, 100 L3, 30 L8)')
    
    args = parser.parse_args()
    
    if not args.level and not args.all:
        parser.print_help()
        return 1
    
    print("="*60)
    print("🏭 Arabic Data Factory (Gemini 2.5 Flash Edition)")
    print("="*60)
    print(f"Model: {MODEL_NAME} (Hybrid Reasoning)")
    print(f"Estimated Cost: ~$0.05 (~70원)")
    print("="*60)
    
    levels_to_generate = {}
    
    if args.all:
        levels_to_generate = {
            2: 50,   # Noun-Adjective phrases
            3: 100,  # Singular-Plural pairs
            8: 30,   # Complex sentences
        }
    else:
        levels_to_generate = {args.level: args.count}
    
    results = {}
    
    for level, count in levels_to_generate.items():
        rows = generate_level_data(level, count)
        
        if rows:
            filepath = save_to_csv(rows, level)
            results[level] = (len(rows), filepath)
            print(f"\n✅ Level {level}: Saved {len(rows)} items to {filepath}")
        else:
            results[level] = (0, None)
            print(f"\n❌ Level {level}: Failed to generate data")
    
    # Summary
    print(f"\n{'='*60}")
    print("📊 GENERATION SUMMARY")
    print("="*60)
    
    total_items = 0
    for level, (count, path) in results.items():
        status = "✅" if count > 0 else "❌"
        print(f"{status} Level {level}: {count} items")
        if path:
            print(f"   → {path}")
        total_items += count
    
    print(f"\nTotal generated: {total_items} items")
    print("\nNext steps:")
    print("1. Review generated CSV files manually")
    print("2. Run: python3 data_audit.py to verify")
    print("3. Merge into curriculum_data.csv")
    
    return 0 if total_items > 0 else 1

if __name__ == "__main__":
    sys.exit(main())

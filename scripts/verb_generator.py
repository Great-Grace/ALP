#!/usr/bin/env python3
"""
verb_generator.py - Generate Form 2-10 Arabic Verbs for Levels 5-7
Uses Gemini 2.5 Flash

Usage:
    export GEMINI_API_KEY="your-key"
    python3 verb_generator.py
"""

import os
import sys
import json
import csv
from pathlib import Path
from datetime import datetime

try:
    from google import genai
    from google.genai import types
except ImportError:
    print("❌ pip install google-genai")
    sys.exit(1)

OUTPUT_DIR = Path(__file__).parent / "generated_data"
OUTPUT_DIR.mkdir(exist_ok=True)

MODEL_NAME = "gemini-2.5-flash"

# Level 5: Form 3-4
# Level 6: Form 5-6-7
# Level 7: Form 8-9-10

VERB_PROMPTS = {
    5: """Generate 50 Arabic Form III and Form IV verbs.

Form III (فَاعَلَ): Reciprocal/Intensive action (e.g., شَارَكَ "to participate with")
Form IV (أَفْعَلَ): Causative (e.g., أَكْرَمَ "to honor")

For each verb provide:
- id: Starting from 50001
- arabic: The verb with FULL TASHKEEL
- korean: Korean meaning
- root: Root letters (ك-ت-ب format)
- form: 3 or 4
- pattern: فَاعَلَ or أَفْعَلَ

Output JSON array:
[{{"id": 50001, "arabic": "شَارَكَ", "korean": "참여하다", "root": "ش-ر-ك", "form": 3, "pattern": "فَاعَلَ"}}]

Generate 50 verbs (25 Form III + 25 Form IV):""",

    6: """Generate 50 Arabic Form V, VI, and VII verbs.

Form V (تَفَعَّلَ): Reflexive of Form II (e.g., تَعَلَّمَ "to learn")
Form VI (تَفَاعَلَ): Mutual action (e.g., تَبَادَلَ "to exchange mutually")
Form VII (اِنْفَعَلَ): Passive/Reflexive (e.g., اِنْكَسَرَ "to break/be broken")

For each verb provide:
- id: Starting from 60001
- arabic: The verb with FULL TASHKEEL
- korean: Korean meaning
- root: Root letters
- form: 5, 6, or 7
- pattern: تَفَعَّلَ, تَفَاعَلَ, or اِنْفَعَلَ

Output JSON array. Generate 50 verbs (~17 each form):""",

    7: """Generate 50 Arabic Form VIII, IX, and X verbs.

Form VIII (اِفْتَعَلَ): Reflexive (e.g., اِجْتَمَعَ "to gather/meet")
Form IX (اِفْعَلَّ): Colors/Defects (e.g., اِحْمَرَّ "to become red")
Form X (اِسْتَفْعَلَ): Seeking/Request (e.g., اِسْتَغْفَرَ "to seek forgiveness")

For each verb provide:
- id: Starting from 70001
- arabic: The verb with FULL TASHKEEL
- korean: Korean meaning
- root: Root letters
- form: 8, 9, or 10
- pattern: اِفْتَعَلَ, اِفْعَلَّ, or اِسْتَفْعَلَ

Output JSON array. Generate 50 verbs (25 Form VIII, 5 Form IX, 20 Form X):"""
}

def generate_verbs(client, level: int) -> list:
    """Generate verbs for a specific level"""
    prompt = VERB_PROMPTS[level]
    
    try:
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.5,
                max_output_tokens=8192,
            )
        )
        
        text = response.text.strip()
        
        # Clean markdown
        if text.startswith("```json"):
            text = text[7:]
        if text.startswith("```"):
            text = text[3:]
        if text.endswith("```"):
            text = text[:-3]
        text = text.strip()
        
        return json.loads(text)
        
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return []

def save_verbs(data: list, level: int) -> Path:
    """Save verbs to CSV"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filepath = OUTPUT_DIR / f"level{level}_verbs_{timestamp}.csv"
    
    headers = ["id", "level", "type", "arabic_text", "korean_meaning", "root", "form", "pattern"]
    
    with open(filepath, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        
        for row in data:
            csv_row = {
                "id": row.get("id"),
                "level": level,
                "type": "vocabulary",
                "arabic_text": row.get("arabic", ""),
                "korean_meaning": row.get("korean", ""),
                "root": row.get("root", ""),
                "form": row.get("form", ""),
                "pattern": row.get("pattern", "")
            }
            writer.writerow(csv_row)
    
    return filepath

def main():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("❌ Set GEMINI_API_KEY")
        sys.exit(1)
    
    print("🚀 Arabic Verb Generator (Levels 5-7)")
    print("="*50)
    
    client = genai.Client(api_key=api_key)
    
    results = {}
    
    for level in [5, 6, 7]:
        print(f"\n📡 Generating Level {level} verbs...")
        
        data = generate_verbs(client, level)
        
        if data:
            filepath = save_verbs(data, level)
            results[level] = (len(data), filepath)
            print(f"   ✅ {len(data)} verbs → {filepath}")
        else:
            results[level] = (0, None)
            print(f"   ❌ Failed")
    
    print("\n" + "="*50)
    print("📊 Summary")
    print("="*50)
    
    total = 0
    for level, (count, path) in results.items():
        status = "✅" if count > 0 else "❌"
        print(f"{status} Level {level}: {count} verbs")
        total += count
    
    print(f"\nTotal: {total} verbs generated")
    return 0 if total > 0 else 1

if __name__ == "__main__":
    sys.exit(main())

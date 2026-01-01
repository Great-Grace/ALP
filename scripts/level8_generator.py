#!/usr/bin/env python3
"""
level8_generator.py - Level 8 Sentence Generator
Uses NEW google.genai package (2026)

Usage:
    pip install google-genai
    export GEMINI_API_KEY="your-key"
    python3 level8_generator.py
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
    print("❌ Install: pip install google-genai")
    sys.exit(1)

OUTPUT_DIR = Path(__file__).parent / "generated_data"
OUTPUT_DIR.mkdir(exist_ok=True)

# Smaller batches to avoid truncation
BATCH_SIZE = 10
TOTAL_COUNT = 30

def generate_sentences(client, count: int, start_id: int) -> list:
    """Generate sentences in small batches"""
    
    prompt = f"""Generate exactly {count} Arabic sentences for language learning.

Return ONLY a valid JSON array with this exact structure:
[
  {{"id": {start_id}, "arabic": "ذَهَبَ الطَّالِبُ إِلَى الْمَدْرَسَةِ", "korean": "학생이 학교에 갔다", "verb": "ذَهَبَ", "subject": "الطَّالِبُ"}},
  {{"id": {start_id + 1}, "arabic": "...", "korean": "...", "verb": "...", "subject": "..."}}
]

Requirements:
- Complete Tashkeel on Arabic text
- Diverse vocabulary
- Simple VSO structure

Generate {count} sentences starting ID {start_id}:"""

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.5,
                max_output_tokens=4096,
            )
        )
        
        text = response.text.strip()
        
        # Clean up response
        if text.startswith("```json"):
            text = text[7:]
        if text.startswith("```"):
            text = text[3:]
        if text.endswith("```"):
            text = text[:-3]
        text = text.strip()
        
        data = json.loads(text)
        return data if isinstance(data, list) else []
        
    except json.JSONDecodeError as e:
        print(f"   ⚠️ JSON error: {e}")
        return []
    except Exception as e:
        print(f"   ❌ API error: {e}")
        return []

def main():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("❌ Set GEMINI_API_KEY")
        sys.exit(1)
    
    print("🚀 Level 8 Generator (google.genai)")
    print(f"   Target: {TOTAL_COUNT} sentences")
    
    client = genai.Client(api_key=api_key)
    
    all_data = []
    start_id = 80001
    
    for batch in range(0, TOTAL_COUNT, BATCH_SIZE):
        count = min(BATCH_SIZE, TOTAL_COUNT - batch)
        print(f"\n📡 Batch {batch//BATCH_SIZE + 1}: Generating {count} sentences...")
        
        data = generate_sentences(client, count, start_id + batch)
        
        if data:
            all_data.extend(data)
            print(f"   ✅ Got {len(data)} sentences (Total: {len(all_data)})")
        else:
            print(f"   ⚠️ Batch failed, continuing...")
    
    if not all_data:
        print("\n❌ No data generated")
        return 1
    
    # Save to CSV
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filepath = OUTPUT_DIR / f"level8_sentences_{timestamp}.csv"
    
    headers = ["id", "level", "type", "arabic_text", "korean_meaning", "verb_form", "sentence_analysis"]
    
    with open(filepath, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        
        for row in all_data:
            analysis = {
                "verb": row.get("verb", ""),
                "subject": row.get("subject", ""),
                "object": row.get("object", "")
            }
            
            csv_row = {
                "id": row.get("id", 80001),
                "level": 8,
                "type": "sentence",
                "arabic_text": row.get("arabic", ""),
                "korean_meaning": row.get("korean", ""),
                "verb_form": 1,
                "sentence_analysis": json.dumps(analysis, ensure_ascii=False)
            }
            writer.writerow(csv_row)
    
    print(f"\n✅ Saved {len(all_data)} sentences to: {filepath}")
    return 0

if __name__ == "__main__":
    sys.exit(main())

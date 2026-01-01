#!/usr/bin/env python3
"""Level 5 only - smaller batches"""

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

def main():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("❌ Set GEMINI_API_KEY")
        sys.exit(1)
    
    client = genai.Client(api_key=api_key)
    
    all_data = []
    
    # Generate in 2 batches of 25
    for batch in [1, 2]:
        print(f"📡 Batch {batch}/2...")
        
        prompt = f"""Generate 25 Arabic Form III and Form IV verbs.

Form III (فَاعَلَ): Reciprocal action
Form IV (أَفْعَلَ): Causative

Return JSON array:
[{{"id": {50000 + (batch-1)*25 + 1}, "arabic": "شَارَكَ", "korean": "참여하다", "root": "ش-ر-ك", "form": 3}}]

Generate 25 verbs now:"""

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
            if "```" in text:
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            text = text.strip()
            
            data = json.loads(text)
            all_data.extend(data)
            print(f"   ✅ Got {len(data)} verbs")
            
        except Exception as e:
            print(f"   ❌ Error: {e}")
    
    if all_data:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filepath = OUTPUT_DIR / f"level5_verbs_{timestamp}.csv"
        
        with open(filepath, 'w', encoding='utf-8', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=["id", "level", "type", "arabic_text", "korean_meaning", "root", "form", "pattern"])
            writer.writeheader()
            
            for row in all_data:
                writer.writerow({
                    "id": row.get("id"),
                    "level": 5,
                    "type": "vocabulary",
                    "arabic_text": row.get("arabic", ""),
                    "korean_meaning": row.get("korean", ""),
                    "root": row.get("root", ""),
                    "form": row.get("form", ""),
                    "pattern": ""
                })
        
        print(f"\n✅ Saved {len(all_data)} verbs to: {filepath}")
    else:
        print("\n❌ No data generated")

if __name__ == "__main__":
    main()

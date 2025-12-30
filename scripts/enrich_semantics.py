#!/usr/bin/env python3
"""
enrich_semantics.py
Enriches verb_forms.csv with deep semantic data using Gemini LLM API.

Adds: meaning_primary, meaning_secondary, nuance_kr, example_sentence, sentence_meaning

Usage:
    export GOOGLE_API_KEY="your-api-key"
    python enrich_semantics.py

Requirements:
    pip install -r requirements.txt
"""

import csv
import json
import os
import sys
import time
from pathlib import Path

try:
    from google import genai
    from google.genai import types
    from tqdm import tqdm
except ImportError:
    print("⚠️ Missing dependencies. Run: pip install google-genai tqdm")
    sys.exit(1)

# ============================================================
# Configuration
# ============================================================

# Get the script's directory and project root
SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent

INPUT_FILE = PROJECT_ROOT / "ArabicLearning" / "Resources" / "verb_forms.csv"
OUTPUT_FILE = PROJECT_ROOT / "ArabicLearning" / "Resources" / "verb_forms_enriched.csv"
CHECKPOINT_FILE = SCRIPT_DIR / ".enrich_checkpoint.json"

# API Settings
MODEL_NAME = "gemini-2.0-flash"  # Latest fast model
BATCH_SIZE = 10  # Save every N rows
RATE_LIMIT_DELAY = 0.1  # Seconds between API calls (adjust for your quota)

# New columns to add
NEW_COLUMNS = [
    "meaning_primary",
    "meaning_secondary", 
    "nuance_kr",
    "example_sentence",
    "sentence_meaning"
]

# ============================================================
# LLM Prompt
# ============================================================

ENRICHMENT_PROMPT = """You are an expert Arabic linguist creating a dictionary entry.

Analyze this Arabic verb:
- Word: {arabic_word}
- Root: {root}
- Form: {form} ({form_label})
- Pattern: {pattern}

Return a JSON object with exactly these keys:
{{
  "primary": "The most common, concise definition in Korean (1-2 words)",
  "secondary": "2-3 other distinct meanings/usages in Korean, separated by semicolons",
  "nuance": "A short Korean explanation of usage nuance (e.g., 타동사적, 추상적 의미로 확장됨)",
  "example": "A short vocalized Arabic sentence using this exact verb form (5-8 words)",
  "example_kr": "Korean translation of the example sentence"
}}

IMPORTANT:
- For "primary", be concise: just the core meaning like "쓰다" or "가다"
- For "secondary", give 2-3 alternate meanings if they exist, otherwise write "없음"
- For "nuance", focus on grammatical or semantic aspects unique to this form
- For "example", use full tashkeel (vowel marks)
- Return ONLY valid JSON, no markdown or explanations

Respond with the JSON object only:"""


# ============================================================
# Gemini API Setup
# ============================================================

def setup_gemini():
    """Initialize Gemini API with environment key."""
    api_key = os.getenv("GOOGLE_API_KEY")
    
    if not api_key:
        print("❌ Error: GOOGLE_API_KEY environment variable not set")
        print("\nTo get an API key:")
        print("1. Go to https://aistudio.google.com/apikey")
        print("2. Create a new API key")
        print("3. Run: export GOOGLE_API_KEY='your-key-here'")
        sys.exit(1)
    
    client = genai.Client(api_key=api_key)
    return client


# ============================================================
# Enrichment Logic
# ============================================================

def enrich_row(client, row: dict) -> dict:
    """Call LLM to enrich a single row with semantic data."""
    prompt = ENRICHMENT_PROMPT.format(
        arabic_word=row.get("arabic_word", ""),
        root=row.get("root", ""),
        form=row.get("verb_form", "1"),
        form_label=row.get("verb_form_label", ""),
        pattern=row.get("pattern", "")
    )
    
    try:
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=prompt
        )
        text = response.text.strip()
        
        # Clean up response (remove markdown code blocks if present)
        if text.startswith("```"):
            text = text.split("```")[1]
            if text.startswith("json"):
                text = text[4:]
        text = text.strip()
        
        data = json.loads(text)
        
        return {
            "meaning_primary": data.get("primary", ""),
            "meaning_secondary": data.get("secondary", ""),
            "nuance_kr": data.get("nuance", ""),
            "example_sentence": data.get("example", ""),
            "sentence_meaning": data.get("example_kr", "")
        }
    
    except json.JSONDecodeError as e:
        print(f"\n⚠️ JSON parse error for {row.get('arabic_word')}: {e}")
        return {col: "" for col in NEW_COLUMNS}
    
    except Exception as e:
        print(f"\n⚠️ API error for {row.get('arabic_word')}: {e}")
        return {col: "" for col in NEW_COLUMNS}


def load_checkpoint() -> set:
    """Load set of already-processed row keys."""
    if Path(CHECKPOINT_FILE).exists():
        with open(CHECKPOINT_FILE, 'r') as f:
            return set(json.load(f))
    return set()


def save_checkpoint(processed: set):
    """Save checkpoint of processed rows."""
    Path(CHECKPOINT_FILE).parent.mkdir(exist_ok=True)
    with open(CHECKPOINT_FILE, 'w') as f:
        json.dump(list(processed), f)


def row_key(row: dict) -> str:
    """Generate unique key for a row."""
    return f"{row.get('arabic_word', '')}_{row.get('verb_form', '')}"


# ============================================================
# Main Processing
# ============================================================

def main():
    print("🚀 Arabic Verb Semantic Enrichment Tool")
    print("=" * 50)
    
    # Setup
    client = setup_gemini()
    processed = load_checkpoint()
    
    print(f"📂 Input: {INPUT_FILE}")
    print(f"📂 Output: {OUTPUT_FILE}")
    print(f"✅ Previously processed: {len(processed)} rows")
    print()
    
    # Read input CSV
    with open(INPUT_FILE, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        original_fieldnames = reader.fieldnames
        rows = list(reader)
    
    print(f"📊 Total rows: {len(rows)}")
    
    # Prepare output fieldnames
    output_fieldnames = list(original_fieldnames) + NEW_COLUMNS
    
    # Check if output exists and has data (for resume)
    output_rows = []
    if Path(OUTPUT_FILE).exists():
        with open(OUTPUT_FILE, 'r', encoding='utf-8') as f:
            existing_reader = csv.DictReader(f)
            output_rows = list(existing_reader)
        print(f"📂 Resuming from existing output ({len(output_rows)} rows)")
    
    # Build a map of existing enriched data
    enriched_map = {}
    for r in output_rows:
        key = row_key(r)
        if r.get("meaning_primary"):  # Has enriched data
            enriched_map[key] = r
    
    # Process rows
    new_output = []
    to_process = []
    
    for row in rows:
        key = row_key(row)
        if key in enriched_map:
            # Use existing enriched data
            new_output.append(enriched_map[key])
        elif key in processed:
            # Was processed but empty (API error), try again
            to_process.append(row)
            new_output.append(row)  # Placeholder
        else:
            to_process.append(row)
            new_output.append(row)  # Placeholder
    
    if not to_process:
        print("✅ All rows already enriched!")
        return
    
    print(f"🔄 Rows to process: {len(to_process)}")
    print()
    
    # Process with progress bar
    batch_buffer = []
    
    for i, row in enumerate(tqdm(to_process, desc="Enriching")):
        key = row_key(row)
        
        # Call LLM
        enriched_data = enrich_row(client, row)
        
        # Merge with original row
        enriched_row = {**row}
        for col in NEW_COLUMNS:
            enriched_row[col] = enriched_data.get(col, "")
        
        # Update in new_output
        for j, r in enumerate(new_output):
            if row_key(r) == key:
                new_output[j] = enriched_row
                break
        
        processed.add(key)
        batch_buffer.append(key)
        
        # Save checkpoint every BATCH_SIZE
        if len(batch_buffer) >= BATCH_SIZE:
            save_progress(new_output, output_fieldnames, processed)
            batch_buffer = []
        
        # Rate limiting
        time.sleep(RATE_LIMIT_DELAY)
    
    # Final save
    save_progress(new_output, output_fieldnames, processed)
    
    print()
    print("=" * 50)
    print(f"✅ Complete! Enriched {len(to_process)} rows")
    print(f"📂 Output saved to: {OUTPUT_FILE}")


def save_progress(rows: list, fieldnames: list, processed: set):
    """Save current progress to CSV and checkpoint."""
    with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)
    
    save_checkpoint(processed)


if __name__ == "__main__":
    main()

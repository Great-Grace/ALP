#!/usr/bin/env python3
"""
generate_article_json.py
Converts raw Arabic text files into ArticleToken JSON format for the iOS app.

Usage:
    python generate_article_json.py input.txt --title "My Article" --output output.json
    
Requirements:
    pip install uuid  (standard library, no external deps needed)
"""

import argparse
import csv
import json
import re
import uuid
from pathlib import Path

# ============================================================
# Arabic Diacritics Removal
# ============================================================

# Arabic diacritics (tashkeel) Unicode ranges
ARABIC_DIACRITICS = re.compile(r'[\u064B-\u065F\u0670]')

def strip_diacritics(text: str) -> str:
    """Remove Arabic diacritics (tashkeel) from text."""
    return ARABIC_DIACRITICS.sub('', text)


# ============================================================
# VerbForm Database Loader
# ============================================================

def load_verb_forms(csv_path: str) -> dict:
    """
    Load verb_forms.csv into a lookup dictionary.
    Returns: { arabic_word_clean: { id, root, form, pattern, nuance, meaning } }
    """
    verb_map = {}
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            arabic_word = row.get('arabic_word', '').strip()
            if not arabic_word:
                continue
            
            # Generate a deterministic UUID from the arabic word + form
            # This ensures same word always gets same ID
            unique_key = f"{arabic_word}_{row.get('verb_form', '1')}"
            generated_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, unique_key))
            
            clean_word = strip_diacritics(arabic_word)
            
            verb_map[clean_word] = {
                'id': generated_id,
                'root': row.get('root', ''),
                'form': int(row.get('verb_form', 1)),
                'pattern': row.get('pattern', ''),
                'nuance': row.get('nuance_korean', ''),
                'meaning': row.get('meaning_korean', '')
            }
    
    return verb_map


# ============================================================
# Tokenizer
# ============================================================

PUNCTUATION = set('.,;:!?،؟؛()[]{}«»"\'')

def tokenize(text: str) -> list:
    """
    Tokenize Arabic text into words and punctuation.
    Returns list of tuples: (token_text, is_word, punctuation)
    """
    tokens = []
    current_word = ""
    
    for char in text:
        if char.isspace():
            if current_word:
                tokens.append((current_word, True, None))
                current_word = ""
            # Skip whitespace tokens (we'll handle spacing in output)
        elif char in PUNCTUATION:
            if current_word:
                # Attach punctuation to previous word
                tokens.append((current_word, True, char))
                current_word = ""
            else:
                # Standalone punctuation
                tokens.append((char, False, None))
        else:
            current_word += char
    
    # Last token
    if current_word:
        tokens.append((current_word, True, None))
    
    return tokens


# ============================================================
# Main Processor
# ============================================================

def process_text(text: str, verb_map: dict, title: str) -> dict:
    """
    Process raw Arabic text and generate ArticleToken JSON structure.
    """
    tokens = tokenize(text)
    
    article_tokens = []
    matched_count = 0
    
    for text_segment, is_word, punctuation in tokens:
        clean_text = strip_diacritics(text_segment)
        
        # Try to match against VerbForm database
        root_id = None
        is_target_word = is_word  # All words are potential targets
        
        if is_word and clean_text in verb_map:
            root_id = verb_map[clean_text]['id']
            matched_count += 1
        
        token = {
            "id": str(uuid.uuid4()),
            "text": text_segment,
            "cleanText": clean_text,
            "rootId": root_id,
            "isTargetWord": is_target_word,
            "punctuation": punctuation
        }
        article_tokens.append(token)
    
    return {
        "title": title,
        "tokens": article_tokens,
        "difficulty": 1,
        "source": "Generated",
        "stats": {
            "total_tokens": len(article_tokens),
            "total_words": sum(1 for t in article_tokens if t["isTargetWord"]),
            "matched_roots": matched_count
        }
    }


def main():
    parser = argparse.ArgumentParser(
        description="Convert Arabic text to ArticleToken JSON for iOS app"
    )
    parser.add_argument("input", help="Input Arabic text file (.txt)")
    parser.add_argument("--title", "-t", default="Untitled Article", 
                        help="Article title")
    parser.add_argument("--output", "-o", default=None,
                        help="Output JSON file (default: input_name.json)")
    parser.add_argument("--verbforms", "-v", 
                        default="ArabicLearning/Resources/verb_forms.csv",
                        help="Path to verb_forms.csv")
    parser.add_argument("--difficulty", "-d", type=int, default=1,
                        help="Difficulty level (1-3)")
    
    args = parser.parse_args()
    
    # Load VerbForm database
    print(f"📚 Loading VerbForm database from: {args.verbforms}")
    verb_map = load_verb_forms(args.verbforms)
    print(f"   Loaded {len(verb_map)} verb forms")
    
    # Read input text
    print(f"📖 Reading input file: {args.input}")
    with open(args.input, 'r', encoding='utf-8') as f:
        text = f.read().strip()
    
    # Process
    print(f"⚙️  Processing text...")
    result = process_text(text, verb_map, args.title)
    result["difficulty"] = args.difficulty
    
    # Output
    output_path = args.output or Path(args.input).stem + ".json"
    
    # Write tokens only (for app import)
    output_data = {
        "title": result["title"],
        "difficulty": result["difficulty"],
        "source": result["source"],
        "tokens": result["tokens"]
    }
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)
    
    # Summary
    stats = result["stats"]
    print(f"\n✅ Complete!")
    print(f"   Output: {output_path}")
    print(f"   Total Tokens: {stats['total_tokens']}")
    print(f"   Total Words: {stats['total_words']}")
    print(f"   Matched Roots: {stats['matched_roots']} ({stats['matched_roots']*100//max(stats['total_words'],1)}%)")


if __name__ == "__main__":
    main()

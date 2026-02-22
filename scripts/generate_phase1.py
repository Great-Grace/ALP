import os
import json
import csv
import time
from pathlib import Path
from google import genai
from google.genai import types

# Setup paths
BASE_DIR = Path(__file__).parent.parent.parent
OUTPUT_DIR = BASE_DIR / "ArabicLearning/scripts/generated_data"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_JSON = OUTPUT_DIR / "phase1_foundation.json"

# Load API Key
api_key = os.environ.get("GEMINI_API_KEY")
if not api_key:
    # Try to read from .env file if running locally
    env_path = BASE_DIR / "ArabicLearning/scripts/.env"
    if env_path.exists():
         with open(env_path, 'r') as f:
             for line in f:
                 if line.startswith("GEMINI_API_KEY"):
                     api_key = line.split('=')[1].strip()

if not api_key:
    print("❌ Error: GEMINI_API_KEY environment variable not set.")
    exit(1)

client = genai.Client(api_key=api_key)

from pydantic import BaseModel, Field

# The Schema
class WordItem(BaseModel):
    sub_level_id: str = Field(description="e.g., '1-1', '1-2'")
    arabic: str = Field(description="100% fully voweled Arabic text")
    meaning: str = Field(description="Korean meaning")
    pos: str = Field(description="Part of speech (e.g., noun, prep, expression)")

# The Sub-levels for Phase 1
SUB_LEVELS = [
    {"id": "1-1", "topic": "Basic Greetings & Pronouns (인사말, 인칭대명사)", "count": 20},
    {"id": "1-2", "topic": "Basic Prepositions & Question Words (전치사, 의문사)", "count": 20},
    {"id": "1-3", "topic": "Family & People (가족, 사람 명사)", "count": 20},
    {"id": "1-4", "topic": "Places & Directions (장소, 방향 명사)", "count": 20},
    {"id": "2-1", "topic": "Everyday Objects & Food (사물, 음식 명사)", "count": 20},
    {"id": "2-2", "topic": "Time & Days (시간, 요일 명사)", "count": 20},
    {"id": "2-3", "topic": "Colors & Basic Adjectives (색상, 기초 형용사)", "count": 20}
]

def generate_sublevel_data(sub_level):
    print(f"🔄 Generating data for Sub-level {sub_level['id']} ({sub_level['topic']})...")
    
    prompt = f"""
    You are an expert Arabic linguist building an A1 level curriculum (Novice Level) for Korean speakers.
    Please generate {sub_level['count']} basic Arabic vocabulary items for Topic: {sub_level['topic']}.
    
    RULES:
    1. TARGET AUDIENCE: Total beginners to Arabic. Keep words very common and useful.
    2. TASHKEEL: You MUST provide 100% complete and accurate vowel markings (Tashkeel) for every letter to teach correct pronunciation.
    3. SUFFIX/PREFIX: Avoid complex attached pronouns if possible, present dictionary forms or most common forms. 
    4. For nouns, include the definite article (ال) ONLY IF it's crucial, otherwise provide indefinite with Tanween.
    5. TANWEEN: For indefinite nouns, you MUST include the final Tanween (e.g., كِتَابٌ instead of كِتَاب) to teach proper I'rab.
    6. OUTPUT FORMAT: JSON array of objects fitting the schema.
    
    Assign ALL items to `sub_level_id`: "{sub_level['id']}".
    """
    
    try:
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=list[WordItem],
                temperature=0.2, # Low temp for factual vocab
                safety_settings=[
                    types.SafetySetting(category=types.HarmCategory.HARM_CATEGORY_HARASSMENT, threshold=types.HarmBlockThreshold.BLOCK_NONE),
                    types.SafetySetting(category=types.HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold=types.HarmBlockThreshold.BLOCK_NONE),
                    types.SafetySetting(category=types.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold=types.HarmBlockThreshold.BLOCK_NONE),
                    types.SafetySetting(category=types.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold=types.HarmBlockThreshold.BLOCK_NONE),
                ]
            )
        )
        data = json.loads(response.text)
        print(f"   ✅ Generated {len(data)} items.")
        return data
    except Exception as e:
        print(f"   ❌ Failed to generate {sub_level['id']}: {e}")
        return []

def main():
    print("🚀 Starting Phase 1 (Foundation) Data Generation...")
    all_data = []
    
    for sl in SUB_LEVELS:
        items = generate_sublevel_data(sl)
        all_data.extend(items)
        time.sleep(2) # rate limit buffer
        
    print(f"\n📊 Generation complete. Total items: {len(all_data)}")
    
    if not all_data:
        return
        
    # Transform for Supabase 'Lessons' table with JSONB 'content_payload'
    import uuid
    supabase_payload = []
    for item in all_data:
        sub_level_id = item.pop("sub_level_id", "1-1")
        
        # Inject Python-controlled audio_url
        item_uuid = str(uuid.uuid4())[:8]
        lvl_folder = sub_level_id.split('-')[0]
        item['audio_url'] = f"s3://kalimat-audio/lvl-{lvl_folder}/{sub_level_id}_{item_uuid}.mp3"
        
        lesson_row = {
            "phase_type": "Phase1",
            "sub_level_id": sub_level_id,
            "content_payload": item
        }
        supabase_payload.append(lesson_row)
        
    with open(OUTPUT_JSON, 'w', encoding='utf-8') as f:
        json.dump(supabase_payload, f, ensure_ascii=False, indent=2)
            
    print(f"💾 Saved Phase 1 Supabase payload to: {OUTPUT_JSON}")

if __name__ == "__main__":
    main()

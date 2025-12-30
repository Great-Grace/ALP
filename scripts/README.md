# Content Pipeline Scripts

This folder contains Python scripts for preprocessing Arabic content for the iOS app.

## generate_article_json.py

Converts raw Arabic text files into the `ArticleToken` JSON format expected by the iOS app.

### Features
- **Diacritic Stripping**: Removes tashkeel (Arabic vowel marks) for clean matching
- **VerbForm Matching**: Links words to entries in `verb_forms.csv` database
- **Deterministic UUIDs**: Same word always gets the same root ID

### Usage

```bash
# Basic usage
python generate_article_json.py story.txt --title "My Story"

# With options
python generate_article_json.py story.txt \
    --title "قصة الأرنب" \
    --output my_article.json \
    --verbforms ../ArabicLearning/Resources/verb_forms.csv \
    --difficulty 2
```

### Arguments
| Arg | Description |
|-----|-------------|
| `input` | Input Arabic text file (.txt) |
| `--title, -t` | Article title |
| `--output, -o` | Output JSON filename |
| `--verbforms, -v` | Path to verb_forms.csv |
| `--difficulty, -d` | 1=Novice, 2=Intermediate, 3=Advanced |

### Output Format
```json
{
  "title": "My Article",
  "difficulty": 1,
  "source": "Generated",
  "tokens": [
    {
      "id": "uuid",
      "text": "كَتَبَ",
      "cleanText": "كتب",
      "rootId": "uuid-if-matched",
      "isTargetWord": true,
      "punctuation": null
    }
  ]
}
```

### Importing to iOS App
1. Run the script to generate JSON
2. Copy the JSON file to `ArabicLearning/Resources/`
3. Use `ArticleLoader.loadSampleArticles()` or import manually

---

## enrich_semantics.py

Enriches `verb_forms.csv` with deep semantic data using Gemini LLM API.

### New Columns Added
| Column | Description |
|--------|-------------|
| `meaning_primary` | Concise main definition (e.g., "쓰다") |
| `meaning_secondary` | 2-3 alternate meanings |
| `nuance_kr` | Korean usage nuance explanation |
| `example_sentence` | Vocalized Arabic example sentence |
| `sentence_meaning` | Korean translation of example |

### Setup

1. **Get API Key**
   - Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Create a new API key
   - Set environment variable:
   ```bash
   export GOOGLE_API_KEY="your-api-key-here"
   ```

2. **Install Dependencies**
   ```bash
   cd scripts
   pip install -r requirements.txt
   ```

3. **Run the Script**
   ```bash
   python enrich_semantics.py
   ```

### Features
- ✅ **Resume Capability**: Saves progress every 10 rows
- ✅ **Skip Existing**: Won't re-process already-enriched rows
- ✅ **Rate Limiting**: 0.5s delay between API calls
- ✅ **Progress Bar**: Visual progress with tqdm
- ✅ **Error Handling**: Continues on API errors

### Output
```
📂 Input: ArabicLearning/Resources/verb_forms.csv
📂 Output: ArabicLearning/Resources/verb_forms_enriched.csv
✅ Previously processed: 0 rows
📊 Total rows: 4123
🔄 Rows to process: 4123

Enriching: 100%|████████████| 4123/4123

✅ Complete! Enriched 4123 rows
```

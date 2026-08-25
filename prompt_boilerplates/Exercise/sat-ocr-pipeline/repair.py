#!/usr/bin/env python3
"""修复轮: 对指定页用 omni 重转录并覆盖 raw_{book}.json"""
import base64, json, os, re, sys, time, threading, urllib.request, urllib.error

OR_KEY = os.environ.get('OPENROUTER_API_KEY', '')
ZHIPU_KEY = os.environ.get('ZHIPU_API_KEY', '')

PROMPT = """You are transcribing a scanned page from an SAT practice book. Transcribe with 100% fidelity — do NOT summarize, skip, or rephrase anything.
Output EXACTLY this structure:
HEADER: <section title / header at top of page, verbatim>
PASSAGE: <all passage text verbatim. Preserve paragraph breaks. Mark underlined text as *[UL_START]*...*[UL_END]*. Mark blanks as [BLANK]. For notes-style questions ("While researching a topic..."), transcribe each note as its own line starting with "- ">
QUESTION: <full question text verbatim>
OPTIONS:
A) <verbatim>
B) <verbatim>
C) <verbatim>
D) <verbatim>
FOOTER: <footer verbatim>
COUNT: <integer number of questions on this page>
Rules:
- If the page has more than one question, output QUESTION1..N / OPTIONS1..N after the single shared PASSAGE.
- If there is no passage, output QUESTION directly after HEADER.
- Tables: pipe rows, e.g. | Month | Temp | then | October | 67 |.
- If the page has no question, output exactly: NO_QUESTION
- Do not add any text outside this structure."""

def call(url, key, payload, hard=400):
    result, error = {}, {}
    def work():
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + key})
            with urllib.request.urlopen(req, timeout=320) as r:
                d = json.load(r)
            result['v'] = d['choices'][0]['message']['content']
        except Exception as e:
            error['e'] = e
    t = threading.Thread(target=work, daemon=True)
    t.start(); t.join(hard)
    if t.is_alive():
        raise TimeoutError('hard timeout')
    if 'e' in error:
        raise error['e']
    return result['v']

def transcribe(img_b64):
    for name, url, key, model in [
        ('zhipu', 'https://open.bigmodel.cn/api/paas/v4/chat/completions', ZHIPU_KEY, 'glm-4.5v'),
        ('omni', 'https://openrouter.ai/api/v1/chat/completions', OR_KEY, 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free'),
        ('nano', 'https://openrouter.ai/api/v1/chat/completions', OR_KEY, 'nvidia/nemotron-nano-12b-v2-vl:free'),
    ]:
        payload = {'model': model, 'temperature': 0.1, 'max_tokens': 8000,
                   'messages': [{'role': 'user', 'content': [
                       {'type': 'text', 'text': PROMPT},
                       {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,' + img_b64}}]}]}
        for attempt, delay in enumerate([0, 20, 40]):
            try:
                return call(url, key, payload), name
            except urllib.error.HTTPError as e:
                if e.code == 429:
                    body = ''
                    try: body = e.read().decode()[:200]
                    except Exception: pass
                    if '1113' in body or '余额' in body:
                        print(f'  zhipu 余额耗尽, skip', flush=True); break
                print(f'  {name} HTTP {e.code}, retry {delay}s', flush=True)
            except Exception as e:
                print(f'  {name} {str(e)[:80]}, retry {delay}s', flush=True)
            time.sleep(delay)
    raise RuntimeError('all providers failed')

def main():
    jobs = json.load(open(sys.argv[1]))
    # jobs: [{"book": "reading", "pg": 43, "expect": 2}, ...]
    for job in jobs:
        book, pg, exp = job['book'], job['pg'], job.get('expect')
        w = 3 if book == 'reading' else 2
        png = f"{os.environ.get('SAT_OCR_BASE', '/tmp/sat_ocr')}/pages/{book}_-{pg:0{w}d}.png"
        img = base64.b64encode(open(png, 'rb').read()).decode()
        print(f'--- {book} p{pg} ---', flush=True)
        try:
            text, model = transcribe(img)
        except Exception as e:
            print(f'FAILED {book} p{pg}: {e}', flush=True)
            continue
        # 覆盖写入 raw_{book}.json
        f = f"{os.environ.get('SAT_OCR_BASE', '/tmp/sat_ocr')}/raw_{book}.json"
        d = json.load(open(f))
        key = f'{book}_{pg}'
        m = re.search(r'COUNT:\s*(\d+)', text)
        d[key] = {'book': book, 'pdf_page': pg, 'text': text, 'model': 'repair-' + model,
                  'count': int(m.group(1)) if m else None, 'expect': exp}
        json.dump(d, open(f, 'w'), ensure_ascii=False, indent=1)
        print(f'  saved ({model})', flush=True)
        time.sleep(3)
    print('REPAIR DONE', flush=True)

if __name__ == '__main__':
    main()

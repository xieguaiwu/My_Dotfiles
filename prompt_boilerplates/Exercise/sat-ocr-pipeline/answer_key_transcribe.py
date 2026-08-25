#!/usr/bin/env python3
"""答案键转录 v2 — openrouter omni/nano 链（zhipu 余额耗尽自动跳过）"""
import base64, json, os, re, time, urllib.request, urllib.error, threading

OR_KEY = os.environ.get('OPENROUTER_API_KEY', '')
ZHIPU_KEY = os.environ.get('ZHIPU_API_KEY', '')
OUT = os.path.join(os.environ.get('SAT_OCR_BASE', '/tmp/sat_ocr'), 'answers_key_omni.json')

PROMPT = """This is a scanned ANSWER KEY page from an SAT prep book. Transcribe EVERY answer exactly.
The page contains a table or list: question number -> answer letter (A/B/C/D).
Output strictly one entry per line: "Q<num>: <letter>"
Transcribe ALL entries visible on this page, every single row. Do not skip any. If a number has no letter, write "Q<num>: ?"."""

def call(url, key, payload, hard=360):
    result, error = {}, {}
    def work():
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + key})
            with urllib.request.urlopen(req, timeout=300) as r:
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
        payload = {'model': model, 'temperature': 0.1, 'max_tokens': 4000,
                   'messages': [{'role': 'user', 'content': [
                       {'type': 'text', 'text': PROMPT},
                       {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,' + img_b64}}]}]}
        for attempt, delay in enumerate([0, 15, 30]):
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
    out = {}
    if os.path.exists(OUT):
        out = json.load(open(OUT))
    jobs = [('reading', 1), ('reading', 2), ('reading', 3), ('grammar', 1), ('grammar', 2)]
    for book, pg in jobs:
        key = f'{book}_{pg}'
        if key in out:
            continue
        prefix = 'read' if book == 'reading' else 'gram'
        path = f"{os.environ.get('SAT_OCR_BASE', '/tmp/sat_ocr')}/pages/ans_{prefix}-{pg}.png"
        img = base64.b64encode(open(path, 'rb').read()).decode()
        print(f'--- {key} ---', flush=True)
        try:
            text, model = transcribe(img)
        except Exception as e:
            print(f'FAILED {key}: {e}', flush=True)
            continue
        print(f'[{model}] {text[:800]}', flush=True)
        out[key] = {'text': text, 'model': model}
        json.dump(out, open(OUT, 'w'), ensure_ascii=False, indent=1)
        time.sleep(2)
    # 汇总
    res = {'reading': {}, 'grammar': {}}
    for book in ['reading', 'grammar']:
        for pg in ([1, 2, 3] if book == 'reading' else [1, 2]):
            k = f'{book}_{pg}'
            if k in out:
                for line in out[k]['text'].splitlines():
                    m = re.match(r'Q\s*(\d+)\s*[:\-.\s]\s*([A-D?])', line.strip())
                    if m:
                        res[book][int(m.group(1))] = m.group(2)
    json.dump(res, open('/tmp/sat_ocr/answers_key_final.json', 'w'), ensure_ascii=False, indent=1)
    print('SUMMARY:', {k: len(v) for k, v in res.items()}, flush=True)

if __name__ == '__main__':
    main()

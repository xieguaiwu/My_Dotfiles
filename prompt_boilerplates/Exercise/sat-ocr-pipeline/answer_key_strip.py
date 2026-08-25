#!/usr/bin/env python3
"""答案页条带裁剪转录 — nano-vl 逐条读"""
import base64, json, os, re, time, threading, urllib.request, urllib.error
import os
from PIL import Image

OR_KEY = os.environ.get('OPENROUTER_API_KEY', '')
PROMPT = "Transcribe this table."

def call(url, key, payload, hard=180):
    result, error = {}, {}
    def work():
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + key})
            with urllib.request.urlopen(req, timeout=150) as r:
                raw = r.read()
            d = json.loads(raw)
            result['v'] = d['choices'][0]['message']['content']
        except Exception as e:
            error['e'] = e
    t = threading.Thread(target=work, daemon=True)
    t.start(); t.join(hard)
    if t.is_alive(): raise TimeoutError('hard timeout')
    if 'e' in error: raise error['e']
    return result['v']

def transcribe(img_b64, model='nvidia/nemotron-nano-12b-v2-vl:free'):
    payload = {'model': model, 'temperature': 0.0, 'max_tokens': 3000,
               'messages': [{'role': 'user', 'content': [
                   {'type': 'text', 'text': PROMPT},
                   {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,' + img_b64}}]}]}
    for attempt, delay in enumerate([0, 20, 40]):
        try:
            return call('https://openrouter.ai/api/v1/chat/completions', OR_KEY, payload)
        except urllib.error.HTTPError as e:
            print(f'  429 retry {delay}s', flush=True)
        except Exception as e:
            print(f'  {str(e)[:80]} retry {delay}s', flush=True)
        time.sleep(delay)
    raise RuntimeError('failed')

res = {}
for pg in [1, 2]:
    img = Image.open(os.path.join(os.environ.get('SAT_OCR_BASE', '/tmp/sat_ocr'), f'pages/ans_gram-{pg}.png')).convert('RGB')
    w, h = img.size
    print(f'=== grammar p{pg} {w}x{h} ===', flush=True)
    # 切 4 条 (15% 起 到 90%)
    y0, y1 = int(h*0.10), int(h*0.92)
    n = 4
    for i in range(n):
        top = y0 + (y1 - y0) * i // n
        bot = y0 + (y1 - y0) * (i + 1) // n
        strip = img.crop((0, top, w, bot))
        w2, h2 = strip.size
        scale = min(3.0, 1600.0 / max(w2, h2))
        if scale > 1.0:
            strip = strip.resize((int(w2*scale), int(h2*scale)), Image.LANCZOS)
        strip.save(f'/tmp/sat_ocr_local/strip_g{pg}_{i}.png')
        b64 = base64.b64encode(open(f'/tmp/sat_ocr_local/strip_g{pg}_{i}.png', 'rb').read()).decode()
        print(f'--- p{pg} strip {i} ---', flush=True)
        try:
            text = transcribe(b64)
        except Exception as e:
            print(f'  FAILED {e}', flush=True)
            text = 'EMPTY'
        print(text[:500], flush=True)
        res[f'g{pg}_s{i}'] = text
        time.sleep(2)
json.dump(res, open('strip_results.json', 'w'), ensure_ascii=False, indent=1)
print('DONE', flush=True)

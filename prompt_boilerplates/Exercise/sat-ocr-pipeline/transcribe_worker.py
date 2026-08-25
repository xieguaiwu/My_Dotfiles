#!/usr/bin/env python3
"""SAT 题目页转录多路 worker — 用法: python3 worker.py reading|grammar
Provider 链: zhipu glm-4.5v (余额耗尽自动跳过) → openrouter nemotron-3-nano-omni → nemotron-nano-12b-v2-vl → gemma-4-26b
增量保存 raw_{book}.json，断点续跑。"""
import base64, json, os, re, subprocess, sys, time, urllib.request, urllib.error

BOOK = sys.argv[1] if len(sys.argv) > 1 else 'reading'
RANGE = None
if len(sys.argv) >= 4:
    RANGE = (int(sys.argv[2]), int(sys.argv[3]))
PAGES_DIR = os.path.join(os.environ.get('SAT_OCR_BASE', '/tmp/sat_ocr'), 'pages')
LOG = f"{os.environ.get('SAT_OCR_BASE', '/tmp/sat_ocr')}/worker_{BOOK}.log"
OUT = f"{os.environ.get('SAT_OCR_BASE', '/tmp/sat_ocr')}/raw_{BOOK}.json"
ZHIPU_KEY = os.environ.get('ZHIPU_API_KEY', '')
OR_KEY = os.environ.get('OPENROUTER_API_KEY', '')

READING_ITEMS = {}
READING_ITEMS.update({i: p for i, p in [
    (1,6),(2,6),(3,7),(4,7),(5,8),(6,8),(7,9),(8,9),(9,10),(10,11),(11,12),
    (12,13),(13,13),(14,14),(15,14),(16,15),(17,15),(18,16),(19,16),(20,17),(21,18),
    (22,19),(23,20),(24,21),(25,22),(26,23),(27,24),(28,25),(29,26),(30,27),(31,28),
    (32,29),(33,30),(34,31),(35,32),(36,33),(37,34),(38,35),(39,36),(40,37),(41,38),
    (42,39),(43,40),(44,41),(45,42),(46,42),(47,43),(48,43),(49,44),(50,45),(51,46),
    (52,47),(53,48),(54,49),(55,50),(56,51),(57,52),(58,53),(59,54),(60,55),(61,56),
    (62,57),(63,58),(64,59),(65,60),(66,61),(67,62),(68,63),(69,64),(70,65),(71,66),
    (72,67),(73,68),(74,69),(75,70),(76,71),(77,72),(78,73),(79,74),(80,75),(81,76),
    (82,77),(83,78),(84,79),(85,80),(86,81),(87,82),(88,83),(89,84)]})
READING_ITEMS.update({i: 85 + (i - 90) for i in range(90, 116)})
READING_ITEMS.update({i: 111 + (i - 116) for i in range(116, 156)})
READING_ITEMS.update({i: 151 + (i - 156) for i in range(156, 161)})

GRAMMAR_ITEMS = {}
GRAMMAR_ITEMS.update({i: p for i, p in [
    (1,5),(2,6),(3,7),(4,7),(5,8),(6,8),(7,9),(8,9),(9,10),(10,10),(11,11),(12,11),
    (13,12),(14,12),(15,13),(16,13),(17,14),(18,14),(19,15),(20,16),(21,16),(22,17),
    (23,18),(24,19),(25,20),(26,21),(27,22),(28,22),(29,23),(30,24),(31,24),
    (32,25),(33,25),(34,26),(35,26),(36,27),(37,27),(38,28),(39,28),(40,29),(41,30),
    (42,30),(43,31),(44,31),(45,32),(46,32),(47,33),(48,33),(49,34),(50,34),(51,35),
    (52,35),(53,36),(54,36),(55,37),(56,37),(57,38),(58,38),(59,39),(60,39),(61,40),
    (62,40),(63,41)]})
GRAMMAR_ITEMS.update({i: 42 + (i - 64) for i in range(64, 99)})
GRAMMAR_ITEMS.update({99: 77, 100: 78})

BOOKS = {
    'reading': {'pdf': '23-26年阅读真题高频160题-题目文本.pdf', 'first': 7, 'last': 156,
                'items': READING_ITEMS, 'digits': 3},
    'grammar': {'pdf': '23-26语法真题高频100题-题目文本.pdf', 'first': 6, 'last': 79,
                'items': GRAMMAR_ITEMS, 'digits': 2},
}
book = BOOKS[BOOK]

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
- If the page has more than one question, output QUESTION1..QUESTIONN / OPTIONS1..OPTIONSN blocks after the single shared PASSAGE.
- If there is no passage, output QUESTION directly after HEADER.
- Tables: pipe rows, e.g. | Month | Temp | then | October | 67 |. Transcribe ALL table cells exactly.
- If the page has no question (cover/TOC/blank), output exactly: NO_QUESTION
- Do not add any text outside this structure."""

def log(msg):
    with open(LOG, 'a') as f:
        f.write(f'[{time.strftime("%H:%M:%S")}] {msg}\n')

import threading
def call(url, key, payload, timeout=300, hard=360):
    """线程硬超时: 流式响应卡住时也能放弃"""
    result, error = {}, {}
    def work():
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                         headers={'Content-Type': 'application/json',
                                                  'Authorization': 'Bearer ' + key})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.load(r)
            result['v'] = d['choices'][0]['message']['content']
        except Exception as e:
            error['e'] = e
    t = threading.Thread(target=work, daemon=True)
    t.start()
    t.join(hard)
    if t.is_alive():
        raise TimeoutError(f'hard timeout {hard}s: {url.split("/")[2]}')
    if 'e' in error:
        raise error['e']
    return result['v']

def providers(img_b64):
    """生成器: 依次 yield (name, callable)。zhipu 余额耗尽自动跳过。"""
    def zhipu():
        return call('https://open.bigmodel.cn/api/paas/v4/chat/completions', ZHIPU_KEY, {
            'model': 'glm-4.5v', 'temperature': 0.1, 'max_tokens': 8000,
            'messages': [{'role': 'user', 'content': [
                {'type': 'text', 'text': PROMPT},
                {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,' + img_b64}}]}]})
    def or_call(model):
        def f():
            return call('https://openrouter.ai/api/v1/chat/completions', OR_KEY, {
                'model': model, 'temperature': 0.1, 'max_tokens': 8000,
                'messages': [{'role': 'user', 'content': [
                    {'type': 'text', 'text': PROMPT},
                    {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,' + img_b64}}]}]})
        return f
    yield 'zhipu-glm-4.5v', zhipu
    if BOOK == 'grammar':
        yield 'or-nemotron-nano-vl', or_call('nvidia/nemotron-nano-12b-v2-vl:free')
        yield 'or-nemotron-omni', or_call('nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free')
    else:
        yield 'or-nemotron-omni', or_call('nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free')
        yield 'or-nemotron-nano-vl', or_call('nvidia/nemotron-nano-12b-v2-vl:free')
    yield 'or-gemma-26b', or_call('google/gemma-4-26b-a4b-it:free')

def transcribe_page(png_path):
    img_b64 = base64.b64encode(open(png_path, 'rb').read()).decode()
    zhipu_dead = False
    for name, fn in providers(img_b64):
        if name == 'zhipu-glm-4.5v' and zhipu_dead:
            continue
        for attempt, delay in enumerate([0, 10, 25, 50]):
            try:
                return fn(), name
            except urllib.error.HTTPError as e:
                if e.code == 429:
                    body = ''
                    try: body = e.read().decode()[:200]
                    except Exception: pass
                    if '1113' in body or '余额' in body:
                        log(f'  zhipu 余额耗尽, 永久跳过')
                        zhipu_dead = True
                        break
                    log(f'  {name} 429, retry in {delay}s')
                elif e.code in (402, 403, 404):
                    log(f'  {name} HTTP {e.code}, skip provider')
                    break
                else:
                    log(f'  {name} HTTP {e.code}, retry in {delay}s')
            except Exception as e:
                log(f'  {name} {str(e)[:100]}, retry in {delay}s')
            time.sleep(delay)
    raise RuntimeError('all providers failed')

def png_path(pdf_page):
    w = book['digits']
    return os.path.join(PAGES_DIR, f"{BOOK}_-{pdf_page:0{w}d}.png")

def expected_count(pdf_page):
    book_page = pdf_page - 1
    return sum(1 for p in book['items'].values() if p == book_page)

def main():
    data = {}
    if os.path.exists(OUT):
        data = json.load(open(OUT))
    pages = list(range(book['first'], book['last'] + 1))
    if RANGE:
        pages = [p for p in pages if RANGE[0] <= p <= RANGE[1]]
    while True:
        pending = [p for p in pages if f'{BOOK}_{p}' not in data or data[f'{BOOK}_{p}'].get('error')]
        if not pending:
            break
        for pdf_page in pending:
            key = f'{BOOK}_{pdf_page}'
            png = png_path(pdf_page)
            if not os.path.exists(png):
                subprocess.run(['pdftoppm', '-png', '-singlefile', '-r', '200',
                                '-f', str(pdf_page), '-l', str(pdf_page),
                                os.path.join(os.environ.get('SAT_OCR_BASE', '/tmp/sat_ocr'), book['pdf']), png[:-4]],
                               check=True, capture_output=True)
            exp = expected_count(pdf_page)
            log(f'{key}: start (expect {exp} q)')
            try:
                text, model = transcribe_page(png)
            except Exception as e:
                log(f'{key}: FAILED {e}')
                data[key] = {'book': BOOK, 'pdf_page': pdf_page, 'error': str(e)[:200]}
                json.dump(data, open(OUT, 'w'), ensure_ascii=False, indent=1)
                continue
            m = re.search(r'COUNT:\s*(\d+)', text)
            got = int(m.group(1)) if m else None
            if exp is not None and got is not None and got != exp:
                log(f'{key}: COUNT MISMATCH expect={exp} got={got} model={model}')
            data[key] = {'book': BOOK, 'pdf_page': pdf_page, 'text': text,
                         'model': model, 'count': got, 'expect': exp}
            json.dump(data, open(OUT, 'w'), ensure_ascii=False, indent=1)
            log(f'{key}: done ({got} q, {model})')
            time.sleep(2)
        log('round complete, checking failed...')
    ok = sum(1 for v in data.values() if v.get('text'))
    err = sum(1 for v in data.values() if v.get('error'))
    log(f'ALL DONE: {ok} ok, {err} errors')
    print(f'ALL DONE: {ok} ok, {err} errors')

if __name__ == '__main__':
    main()

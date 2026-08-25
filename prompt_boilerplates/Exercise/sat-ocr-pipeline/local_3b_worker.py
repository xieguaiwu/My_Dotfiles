#!/usr/bin/env python3
"""本地 Qwen2.5-VL-3B 转录 lane — 无限量免费。串行 GPU。
写 raw_local_{book}.json; 跳过 openrouter/zhipu 已完成的页。
"""
import json, os, re, sys, time, torch
from PIL import Image
from transformers import AutoModelForVision2Seq, AutoProcessor

BOOK = sys.argv[1] if len(sys.argv) > 1 else 'reading'
PAGES_DIR = '/tmp/sat_ocr/pages'
LOG = f'/tmp/sat_ocr/local_{BOOK}.log'
OUT = f'/tmp/sat_ocr/raw_local_{BOOK}.json'

# 页序 + 预期题数
READING_PAGES = [(p, 2 if p in (7, 8, 9, 13, 14, 15, 16, 43, 44) else 1) for p in range(7, 157)]
# 双题页(book page): 6,7,8,9,12,13,14,15,42,43 → pdf 页 = book+1 → 7,8,9,10,13,14,15,16,43,44
GRAMMAR_PAGES = [(p, 2 if p in (8, 10, 12, 14, 16, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 62) else 1) for p in range(6, 80)]
# 语法双题 pdf 页(book page→pdf): 7→8, 9→10, 11→12, 13→14, 15→16, 21→22, 23→24, 25→26, 27→28, 29→30, 31→32, 33→34, 35→36, 37→38, 39→40, 41→42, 43→44, 45→46, 47→48, 49→50, 51→52, 53→54, 55→56, 57→58, 59→60, 61→62

PROMPT = """You are transcribing a scanned page from an SAT practice book. Transcribe with 100% fidelity — do NOT summarize, skip, or rephrase anything.
Output EXACTLY this structure (nothing before HEADER):
HEADER: <section title at top, verbatim>
PASSAGE: <all passage text verbatim. Preserve paragraph breaks. Mark underlined text as *[UL_START]*...*[UL_END]*. Mark blanks as [BLANK]. For notes-style questions, transcribe each note as its own line starting with "- ">
QUESTION: <full question text verbatim>
OPTIONS:
A) <verbatim>
B) <verbatim>
C) <verbatim>
D) <verbatim>
FOOTER: <footer verbatim>
COUNT: <integer number of questions on this page>
If the page has more than one question, output QUESTION1..N / OPTIONS1..N after the shared PASSAGE.
If there is no question, output exactly: NO_QUESTION"""

def log(msg):
    with open(LOG, 'a') as f:
        f.write('[%s] %s\n' % (time.strftime('%H:%M:%S'), msg))

def main():
    global model, processor
    model = AutoModelForVision2Seq.from_pretrained("/root/liuji/qwen-vl-3b", torch_dtype=torch.bfloat16,
        device_map="cuda:0", trust_remote_code=True).eval()
    processor = AutoProcessor.from_pretrained("/root/liuji/qwen-vl-3b", trust_remote_code=True)
    log('model loaded')

    data = {}
    if os.path.exists(OUT):
        data = json.load(open(OUT))
    pages = READING_PAGES if BOOK == 'reading' else GRAMMAR_PAGES
    # 跳过 openrouter 已完成的
    done_by_other = set()
    for b in ['reading', 'grammar']:
        f = f'/tmp/sat_ocr/raw_{b}.json'
        if os.path.exists(f):
            d = json.load(open(f))
            done_by_other.update(int(v['pdf_page']) for v in d.values() if v.get('text') and v.get('book') == BOOK)

    for pg, exp in pages:
        key = f'{BOOK}_{pg}'
        if key in data and data[key].get('text'):
            continue
        if pg in done_by_other:
            continue
        w = 3 if BOOK == 'reading' else 2
        png = os.path.join(PAGES_DIR, f'{BOOK}_-{pg:0{w}d}.png')
        if not os.path.exists(png):
            log(f'{key}: page missing {png}')
            continue
        log(f'{key}: start (expect {exp})')
        try:
            image = Image.open(png).convert('RGB')
            w0, h0 = image.size
            scale = min(1.0, 896.0 / max(w0, h0))
            if scale < 1.0:
                image = image.resize((int(w0*scale), int(h0*scale)), Image.LANCZOS)
            messages = [{'role': 'user', 'content': [
                {'type': 'image', 'image': image},
                {'type': 'text', 'text': PROMPT}]}]
            text = processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
            inputs = processor(text=[text], images=[image], return_tensors='pt').to(model.device, torch.bfloat16)
            with torch.no_grad():
                out = model.generate(**inputs, max_new_tokens=5200, do_sample=False)
            gen = processor.batch_decode(out[:, inputs.input_ids.shape[1]:], skip_special_tokens=True)[0]
        except Exception as e:
            log(f'{key}: FAILED {str(e)[:150]}')
            data[key] = {'book': BOOK, 'pdf_page': pg, 'error': str(e)[:200]}
            json.dump(data, open(OUT, 'w'), ensure_ascii=False, indent=1)
            continue
        # 去回声: 删除首个 QUESTION 前的重复内容（若 PASSAGE 内出现完整问题副本）
        m = re.search(r'COUNT:\s*(\d+)', gen)
        got = int(m.group(1)) if m else len(re.findall(r'^QUESTION\d*\s*:', gen, re.M))
        data[key] = {'book': BOOK, 'pdf_page': pg, 'text': gen, 'model': 'local-qwen3b',
                     'count': got, 'expect': exp}
        json.dump(data, open(OUT, 'w'), ensure_ascii=False, indent=1)
        log(f'{key}: done ({got} q)')
        time.sleep(1)
    ok = sum(1 for v in data.values() if v.get('text'))
    log(f'LOCAL DONE: {ok} pages')
    print(f'LOCAL DONE: {ok}')

if __name__ == '__main__':
    main()

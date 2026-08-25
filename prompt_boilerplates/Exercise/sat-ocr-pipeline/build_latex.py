#!/usr/bin/env python3
"""SAT LaTeX 生成器: raw_{book}.json → {book}_questions.tex / {book}_answers.tex
阅读: 专题分节; 语法: 考点分节; 题号各节自 1 起; tectonic 编译。
"""
import json, os, re, subprocess, sys
from collections import OrderedDict

BASE = '/tmp/sat_ocr'
OUTDIR = '/home/xieguiawu/高一/英语/SAT/0815hw'

# ---------------- 解析 ----------------

def parse_page(text):
    """把一页转录解析为结构化 dict"""
    out = {'header': '', 'passage': '', 'questions': [], 'count': None, 'raw': text}
    if 'NO_QUESTION' in text:
        return out
    m = re.search(r'COUNT:\s*(\d+)', text)
    if m:
        out['count'] = int(m.group(1))
    m = re.search(r'^HEADER:\s*(.*)$', text, re.M)
    if m:
        out['header'] = m.group(1).strip()
    # 题目块: QUESTION / QUESTION 1..N (两种格式)
    q_blocks = re.split(r'^QUESTION\s*(?:\d+)?\s*:', text, flags=re.M)
    if len(q_blocks) < 2:
        return out
    out['passage'] = extract_passage(q_blocks[0])
    for blk in q_blocks[1:]:
        q, opts = extract_question(blk)
        if q:
            # 去回声: 3B 模型有时把问题(+选项)在 PASSAGE 区重复一遍
            if out['passage'] and q[:50] in out['passage']:
                cut = out['passage'].rfind(q[:50])
                passage = out['passage'][:cut].strip()
                lines = passage.splitlines()
                while lines and re.match(r'^[A-D]\)', lines[-1].strip()):
                    lines.pop()
                out['passage'] = '\n'.join(lines).strip()
            out['questions'].append({'q': q, 'options': opts})
    # 页内完全重复去重: 同题干+同选项 = 幻觉回声
    seen = set()
    dedup = []
    for q in out['questions']:
        sig = (q['q'], tuple(sorted(q['options'].items())))
        if sig not in seen:
            seen.add(sig)
            dedup.append(q)
    out['questions'] = dedup
    return out

def extract_passage(header_block):
    """HEADER 之后、QUESTION 之前的 PASSAGE 段"""
    m = re.search(r'PASSAGE:\s*(.*?)(?=\nQUESTION|\nFOOTER|\Z)', header_block, re.S)
    if not m:
        return ''
    return m.group(1).strip()

def extract_question(block):
    """题目块 → (question, {A-D: option})。兼容 OPTIONS: 前缀与裸 A) 行两种格式"""
    opts = {}
    q_lines = []
    for line in block.splitlines():
        if re.match(r'^\s*OPTIONS\s*(?:\d+)?\s*:?\s*$', line):
            continue
        m = re.match(r'\s*(?:OPTIONS\s*(?:\d+)?\s*:\s*)?([A-D])\)\s*(.*)$', line)
        if m:
            opts[m.group(1)] = m.group(2).strip()
        else:
            q_lines.append(line)
    q = ' '.join(l.strip() for l in q_lines if l.strip())
    q = re.sub(r'\s+', ' ', q)
    q = re.sub(r'\s*FOOTER:.*$', '', q, flags=re.S).strip()
    return q, opts

# ---------------- 清洗 ----------------

def fix_spacing(s):
    """修复模型合并空格: [a-z][A-Z] 边界插空格 (Mc/Mac 前缀除外)"""
    return re.sub(r'(?<!M)(?<!Ma)([a-z])([A-Z][a-z])', r'\1 \2', s)

def esc(s):
    """LaTeX 转义 + 符号规范化"""
    s = s.replace('\\', r'\textbackslash{}')
    s = s.replace('&', r'\&').replace('%', r'\%').replace('$', r'\$')
    s = s.replace('#', r'\#').replace('_', r'\_').replace('{', r'\{').replace('}', r'\}')
    s = s.replace('~', r'\textasciitilde{}').replace('^', r'\textasciicircum{}')
    s = s.replace('—', '---').replace('–', '--')
    s = s.replace('’', "'").replace('‘', "'").replace('“', "``").replace('”', "''")
    s = s.replace('…', r'\dots{}')
    return s

def ul_inner(s):
    """UL 内容: 转义 + BLANK + 引号 (无 UL 递归)"""
    s = esc(s)
    s = s.replace('[BLANK]', r'\rule{2.5cm}{0.4pt}')
    s = re.sub(r'"([^"]*)"', r"``\1''", s)
    return s

def inline(s):
    """段内文本: 空格修复 + 转义 + UL 标记 + BLANK + 引号"""
    s = fix_spacing(s)
    s = esc(s)
    s = re.sub(r'\*?\[UL[_\\]*START\]\*?(.*?)\*?\[UL[_\\]*END\]\*?',
               lambda m: r'\uline{' + ul_inner(m.group(1)) + '}', s, flags=re.S)
    s = s.replace('[BLANK]', r'\rule{2.5cm}{0.4pt}')
    # ASCII 引号成对转
    s = re.sub(r'"([^"]*)"', r"``\1''", s)
    return s

def passage_block(p):
    """PASSAGE → LaTeX: 段落 / bullets / 表格"""
    if not p.strip():
        return ''
    parts = []
    for chunk in re.split(r'\n\s*\n', p):
        chunk = chunk.strip()
        if not chunk:
            continue
        if chunk.startswith('- '):
            items = [inline(c[2:]) for c in chunk.splitlines() if c.startswith('- ')]
            parts.append('\\begin{itemize}[nosep]\n' + ''.join(f'\\item {it}\n' for it in items) + '\\end{itemize}')
            continue
        if '|' in chunk and re.search(r'\|.*\|.*\|', chunk):
            parts.append(table_block(chunk))
            continue
        parts.append(inline(chunk))
    body = '\n\n'.join(parts)
    return '\\begin{quote}\n' + body + '\n\\end{quote}\n'

def table_block(chunk):
    """pipe 表格 → tabular (自动列宽)"""
    rows = [r for r in chunk.splitlines() if r.strip().startswith('|')]
    if not rows:
        return inline(chunk)
    cells = [c.strip() for c in rows[0].strip().strip('|').split('|')]
    ncol = len(cells)
    colspec = []
    for c in cells:
        colspec.append('p{3.2cm}' if len(c) > 12 else 'l')
    tex = '\\begin{center}\\small\\begin{tabular}{' + ' '.join(colspec) + '}\n\\hline\n'
    for r in rows:
        cs = [inline(c.strip()) for c in r.strip().strip('|').split('|')]
        tex += ' & '.join(cs) + ' \\\\\n\\hline\n'
    tex += '\\end{tabular}\\end{center}\n'
    return tex

def options_block(opts):
    if not opts:
        return ''
    inner = []
    for letter in 'ABCD':
        if letter in opts:
            inner.append(f'\\item {inline(opts[letter])}')
    if not inner:
        return ''
    return '\\begin{enumerate}[label=(\\Alph*)]\n' + '\n'.join(inner) + '\n\\end{enumerate}\n'

# ---------------- 节结构 ----------------

def reading_sections(header_by_item):
    """阅读分节: TOC 边界 + header 校正 五/六 分界"""
    # 探测数量证据题/推断题边界: 找 header 含 Inference 的首个 item
    inf_start = None
    for it, h in header_by_item.items():
        if h and re.search(r'infer|推断', h, re.I):
            inf_start = it
            break
    if inf_start and inf_start > 116:
        q_start = inf_start
    elif not inf_start:
        q_start = 156  # 无推断 header 信息 → 五覆盖 116-155
    secs = [
        ('一、词汇题 (Vocabulary)', (1, 21)),
        ('二、双篇 (Dual Passages)', (22, 25)),
        ('三、结构目的与主旨细节题 (Structure, Purpose, Main Idea \& Details)', (26, 89)),
        ('四、文本证据题 (Textual Evidence)', (90, 115)),
        ('五、数量证据题 (Quantitative Evidence)', (116, q_start - 1)),
        ('六、推断题 (Inference)', (q_start, 155)),
        ('七、其他 (Others)', (156, 160)),
    ]
    return [(n, r) for n, r in secs if r[0] <= r[1]]

def grammar_sections(header_by_item):
    """语法分节: TOC 边界 + header 校正"""
    # 找 Transitions 起点
    tr_start = None
    for it, h in header_by_item.items():
        if h and re.search(r'transition|过渡', h, re.I):
            tr_start = it
            break
    if not tr_start:
        tr_start = 40
    return [
        ('1.1 Boundaries (Standard English Conventions)', (1, 31)),
        ('Expression of Ideas --- Other', (32, tr_start - 1)),
        ('2.1 Transitions', (tr_start, 100)),
    ]

# ---------------- 生成 ----------------

def load_book(book):
    pages = {}
    for f in [f'{BASE}/raw_{book}.json', f'{BASE}/raw_local_{book}.json']:
        if not os.path.exists(f):
            continue
        raw = json.load(open(f))
        for k, v in raw.items():
            if v.get('text') and not v.get('error'):
                pg = int(v['pdf_page'])
                # 非 local 文件优先 (raw_*.json 在 raw_local_*.json 之前)
                if pg not in pages:
                    pages[pg] = v['text']
    return pages

def build_items(book, pages, expect_map):
    """按 PDF 页序组装 item 列表; 返回 (items, warnings)"""
    items = []
    warnings = []
    order = sorted(pages.keys())
    for pg in order:
        parsed = parse_page(pages[pg])
        qs = parsed['questions']
        exp = expect_map.get(pg)
        if exp is not None and len(qs) != exp:
            warnings.append(f'page {pg}: expect {exp} got {len(qs)}')
        for qi, q in enumerate(qs):
            items.append({
                'book': book, 'pdf_page': pg, 'idx': len(items) + 1,
                'q': q['q'], 'options': q['options'],
                'passage': parsed['passage'], 'header': parsed['header'],
            })
    return items, warnings

def write_questions(items, sections, fname):
    with open(fname, 'w') as f:
        f.write(r'''\documentclass[10pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage{fontspec}
\setmainfont{Noto Sans SC}
\XeTeXlinebreaklocale "zh"
\XeTeXlinebreakskip = 0pt plus 1pt
\usepackage{amsmath,amssymb}
\usepackage{enumitem}
\usepackage{geometry}
\usepackage[normalem]{ulem}
\geometry{margin=0.6in}
\setlist[enumerate]{leftmargin=*,nosep}
\setlength{\parindent}{0pt}

\begin{document}

\begin{center}
{\Large\bfseries SAT Practice --- Questions}
\end{center}

''')
        for sec_name, (a, b) in sections:
            sec_items = [it for it in items if a <= it['idx'] <= b]
            if not sec_items:
                print(f'  (skip empty section {sec_name})')
                continue
            f.write(f'\\section{{{sec_name}}}\n')
            f.write('\\begin{enumerate}[label=\\textbf{\\arabic*.}]\n')
            for it in sec_items:
                f.write('\\item ')
                if it['passage']:
                    f.write('\n' + passage_block(it['passage']))
                f.write(inline(it['q']) + '\n')
                f.write(options_block(it['options']))
                f.write(f'% QID: {it["book"].upper()}{it["idx"]:03d}\n')
            f.write('\\end{enumerate}\n\n')
        f.write('\\end{document}\n')
    print(f'questions: {fname}')

def write_answers(items, sections, key, fname):
    with open(fname, 'w') as f:
        f.write(r'''\documentclass[10pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage{fontspec}
\setmainfont{Noto Sans SC}
\XeTeXlinebreaklocale "zh"
\XeTeXlinebreakskip = 0pt plus 1pt
\usepackage{amsmath,amssymb}
\usepackage{enumitem}
\usepackage{geometry}
\geometry{margin=0.6in}
\setlist[enumerate]{leftmargin=*,nosep}
\setlength{\parindent}{0pt}

\begin{document}

\begin{center}
{\Large\bfseries SAT Practice --- Answers}
\end{center}

''')
        for sec_name, (a, b) in sections:
            sec_items = [it for it in items if a <= it['idx'] <= b]
            if not sec_items:
                continue
            f.write(f'\\section{{{sec_name}}}\n')
            f.write('\\begin{enumerate}[label=\\textbf{\\arabic*.}]\n')
            for it in sec_items:
                letter = key.get(it['idx'], '?')
                f.write(f'\\item \\textbf{{{letter}}} \\quad (\\textsc{{{short_name(it)}}})\n')
                f.write(f'% QID: {it["book"].upper()}{it["idx"]:03d}\n')
            f.write('\\end{enumerate}\n\n')
        f.write('\\end{document}\n')
    print(f'answers: {fname}')

def short_name(it):
    """每题来源专题缩写"""
    idx = it['idx']
    if it['book'] == 'reading':
        if idx <= 21: return 'Vocabulary'
        if idx <= 25: return 'Dual Passages'
        if idx <= 89: return 'Structure \& Purpose'
        if idx <= 115: return 'Textual Evidence'
        if idx <= 155: return 'Quant./Inference'
        return 'Others'
    if idx <= 31: return 'Boundaries'
    if idx <= 39: return 'Expression of Ideas'
    return 'Transitions'

def compile_tex(fname):
    r = subprocess.run(['tectonic', fname], capture_output=True, text=True, timeout=600)
    if r.returncode == 0:
        print(f'compiled: {fname}')
        return True
    print(f'COMPILE FAIL {fname}:')
    print(r.stderr[-2000:])
    return False

# ---------------- 主流程 ----------------

def main():
    expect = {
        'reading': json.load(open(f'{BASE}/expect_reading.json')),
        'grammar': json.load(open(f'{BASE}/expect_grammar.json')),
    }
    key = {}
    if os.path.exists(f'{BASE}/answers_key.json'):
        key = json.load(open(f'{BASE}/answers_key.json'))
    for book in ['reading', 'grammar']:
        pages = load_book(book)
        items, warnings = build_items(book, pages, {int(k): v for k, v in expect[book].items()})
        print(f'== {book}: {len(items)} items, {len(warnings)} warnings')
        for w in warnings[:20]:
            print('  !', w)
        header_by_item = {it['idx']: it['header'] for it in items}
        sections = reading_sections(header_by_item) if book == 'reading' else grammar_sections(header_by_item)
        print('  sections:', [(s[0], s[1]) for s in sections])
        book_key = {int(k): v for k, v in key.get(book, {}).items()}
        missing = [i for i in range(1, len(items) + 1) if i not in book_key]
        print(f'  key coverage: {len(book_key) - len(missing)}/{len(items)} (missing {len(missing)})')
        write_questions(items, sections, f'{OUTDIR}/{book}_questions.tex')
        write_answers(items, sections, book_key, f'{OUTDIR}/{book}_answers.tex')
        compile_tex(f'{OUTDIR}/{book}_questions.tex')
        compile_tex(f'{OUTDIR}/{book}_answers.tex')
    print('DONE')

if __name__ == '__main__':
    main()

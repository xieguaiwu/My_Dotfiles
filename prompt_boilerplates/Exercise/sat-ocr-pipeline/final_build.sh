#!/bin/bash
# final_build.sh — S1 数据就绪后一键收尾: 同步 → 构建 → 编译 → 验证
# 用法: bash final_build.sh
set -e
SSHPASS_ENV=1
export SSHPASS='Romee9wa'
S1="root@223.109.239.36:10212"
LOCAL="/tmp/sat_ocr/final"
mkdir -p "$LOCAL"
cd "$LOCAL"

sync() {
  for i in 1 2 3 4 5 6 7 8; do
    sshpass -e scp -o ConnectTimeout=20 -o StrictHostKeyChecking=no -P "$S1_PORT" "$S1_HOST:$1" "$2" 2>/dev/null && return 0
    sleep $((i*5))
  done
  echo "✗ sync failed: $1"; return 1
}

S1_HOST="root@223.109.239.36"; S1_PORT=10212

echo "== 同步数据 =="
for f in raw_reading.json raw_grammar.json raw_local_reading.json raw_local_grammar.json answers_key_final.json expect_reading.json expect_grammar.json; do
  sync "/tmp/sat_ocr/$f" "$LOCAL/$f" || true
done

echo "== 构建 LaTeX =="
python3 <<'EOF'
import json, os, sys, warnings
warnings.filterwarnings('ignore')
sys.path.insert(0, '/tmp/sat_ocr')
import build_latex
build_latex.BASE = '/tmp/sat_ocr/final'
build_latex.OUTDIR = '/tmp/sat_ocr/final'
from build_latex import build_items, reading_sections, grammar_sections, load_book, write_questions, write_answers

key = {}
if os.path.exists('/tmp/sat_ocr/final/answers_key_final.json'):
    key = json.load(open('/tmp/sat_ocr/final/answers_key_final.json'))

for book in ['reading', 'grammar']:
    pages = load_book(book)
    expect = json.load(open(f'/tmp/sat_ocr/final/expect_{book}.json'))
    items, warns = build_items(book, pages, {int(k): v for k, v in expect.items()})
    print(f'== {book}: {len(items)} items, {len(warns)} warnings')
    for w in warns[:30]:
        print('  !', w)
    hdr = {it['idx']: it['header'] for it in items}
    secs = reading_sections(hdr) if book == 'reading' else grammar_sections(hdr)
    print('  sections:', [(s[0][:30], s[1]) for s in secs])
    bk = {int(k): v for k, v in key.get(book, {}).items()}
    missing = [i for i in range(1, len(items) + 1) if i not in bk]
    print(f'  answer coverage: {len(items) - len(missing)}/{len(items)} missing={missing[:10]}')
    write_questions(items, secs, f'/tmp/sat_ocr/final/{book}_questions.tex')
    write_answers(items, secs, bk, f'/tmp/sat_ocr/final/{book}_answers.tex')
print('BUILD OK')
EOF

echo "== 编译 =="
cd /tmp/sat_ocr/final
for f in reading_questions reading_answers grammar_questions grammar_answers; do
  tectonic "$f.tex" > /dev/null 2>&1 && echo "✓ $f.pdf" || echo "✗ $f FAILED"
done

echo "== 验证 =="
python3 <<'EOF'
import re, json, os
from pathlib import Path
for book in ['reading', 'grammar']:
    qtex = Path(f'/tmp/sat_ocr/final/{book}_questions.tex').read_text()
    atex = Path(f'/tmp/sat_ocr/final/{book}_answers.tex').read_text()
    nq = qtex.count('\\item ')
    # 答案字母 + qid zip 校验
    letters = re.findall(r'\\item \\textbf\{([A-D?])\}', atex)
    qids = re.findall(r'% QID: ([A-Z]+)(\d+)', atex)
    print(f'{book}: questions items={nq} answer letters={len(letters)} qids={len(qids)}')
    # 全部题数 = 答案数
    ok = nq == len(letters)
    print(f'  match: {"✓" if ok else "✗"}')
EOF
echo "== 复制到目标目录 =="
DEST="/home/xieguiawu/高一/英语/SAT/0815hw"
cp -f /tmp/sat_ocr/final/*.tex /tmp/sat_ocr/final/*.pdf "$DEST"/ 2>/dev/null
ls -la "$DEST"/*.tex "$DEST"/*.pdf 2>/dev/null
echo "ALL DONE"

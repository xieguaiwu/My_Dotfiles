#!/usr/bin/env python3
"""make_expect_map.py — 由 TOC 探针结果生成 expect_{book}.json（页面→预期题数映射）。
用法: 先用 vision 模型转录目录页得到 {item: book_page} 映射（手工粘贴到下方），再运行本脚本。
输出: expect_reading.json / expect_grammar.json
"""
import json, os
from collections import Counter

# ↓↓↓ 从 TOC 转录得到的 item → book page 映射（按书替换为你的数据）↓↓↓
READING_ITEMS = {
    1: 6, 2: 6, 3: 7, 4: 7, 5: 8, 6: 8, 7: 9, 8: 9, 9: 10, 10: 11,
    # ... 完整映射见 2026-08-19 实战 (阅读 160 题)
}
GRAMMAR_ITEMS = {
    1: 5, 2: 6, 3: 7, 4: 7, 5: 8, 6: 8, 7: 9, 8: 9, 9: 10, 10: 10,
    # ... 完整映射见 2026-08-19 实战 (语法 100 题)
}
# ↑↑↑ 替换为你的 TOC 数据 ↑↑↑

def make(book_items, pdf_first, out):
    """book page → pdf page = book page + pdf_first_offset。
    注意: pdf_page = book_page + offset, offset 由封面/目录页数决定 (本系列 = 1)。"""
    m = {}
    for item, book_page in book_items.items():
        pg = book_page + 1  # ← offset 按实际 PDF 调整
        m[pg] = m.get(pg, 0) + 1
    json.dump(m, open(out, 'w'), ensure_ascii=False, indent=1)
    total = sum(m.values())
    print(f'{out}: {len(m)} pages, {total} items, 分布 {dict(Counter(m.values()))}')

if __name__ == '__main__':
    make(READING_ITEMS, 7, 'expect_reading.json')
    make(GRAMMAR_ITEMS, 6, 'expect_grammar.json')

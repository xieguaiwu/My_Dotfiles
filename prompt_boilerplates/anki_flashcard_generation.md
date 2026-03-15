遵守以下步骤，写python脚本帮我生成anki闪卡

## 一、基本步骤

### 1. 环境准备

```bash
pip install genanki
```

**推荐使用 `genanki` 库**，而非手动构建 SQLite 数据库，可避免 JSON 格式兼容性问题。

### 2. 公式提取

- 识别 `$$...$$` 块级公式（单行和多行）
- 记录公式所属分类（通过 `##` 和 `###` 标题层级）
- 过滤非等式内容（纯描述性文本、条件说明等）

### 3. 公式解析

- 按 `=` 分割等式
- 左边部分作为**问题**
- 右边部分作为**答案**
- 多等号情况：将后续变形作为**其他形式**

### 4. 创建 Anki 模型

```python
FORMULA_MODEL = genanki.Model(
    model_id,
    'Formula Card',
    fields=[
        {'name': 'Category'},
        {'name': 'Question'},
        {'name': 'Answer'},
        {'name': 'AlternativeForms'},
    ],
    templates=[
        {
            'name': 'Card 1',
            'qfmt': '[$$]{{Question}} = \\, ?[/$$]',
            'afmt': '[$$]{{Question}} = {{Answer}}[/$$]',
        },
    ],
)
```

### 5. 生成 .apkg 文件

```python
deck = genanki.Deck(deck_id, '牌组名称')
# 添加笔记...
package = genanki.Package(deck)
package.write_to_file('output.apkg')
```

---

## 二、格式规范

### LaTeX 公式格式

使用 Anki 原生 LaTeX 标签：

```
[$$]LaTeX公式[/$$]
```

**不要使用**：
- `\[...\]` - Anki 不识别
- `\(...\)` - 行内公式不适用
- MathJax 的 `$$...$$` - 需转换

### 问题卡片格式

| 字段 | 内容 | 示例 |
|------|------|------|
| Question | 等式左边 | `\sin^2\theta + \cos^2\theta` |
| Answer | 等式右边（第一项） | `1` |
| AlternativeForms | 其他等价形式 | `\varphi = \frac{1+\sqrt{5}}{2}` |

---

## 三、常见问题

### 问题 1：导入时报 JSON 解码错误

**原因**：手动构建数据库时缺少必需字段

**解决**：使用 `genanki` 库，或确保模型包含以下字段：
- `css`（必需）
- `type`（deck 需要）
- 正确的 `flds` 和 `tmpls` 结构

### 问题 2：Note ID 冲突

**原因**：ID 生成方式导致重复

**解决**：使用计数器或时间戳确保唯一性

```python
_counter = 0
def get_note_id():
    global _counter
    _counter += 1
    return 1700000000000 + _counter
```

### 问题 3：公式渲染异常

**原因**：LaTeX 语法与 Anki 不兼容

**注意**：
- 转义反斜杠：Python 字符串中使用 `\\` 表示 `\`
- 某些宏包需要配置（如 `amsmath`, `amssymb`）

### 问题 4：多行公式解析错误

**处理方式**：
```python
# 将多行合并为单行
formula = ' '.join(formula_lines)
formula = re.sub(r'\s+', ' ', formula)  # 压缩空白
```

### 问题 5：特殊公式需跳过

以下类型不应生成为闪卡：
- `\begin{cases}...` 多分支条件
- 包含 `\Rightarrow` 的推导式
- 纯文字说明（`For...`, `If...`, `where...`）
- 表格形式的内容

---

## 四、代码模板

```python
#!/usr/bin/env python3
"""Markdown 公式转 Anki 闪卡"""

import re
import genanki

# 固定 ID
MODEL_ID = 1607392319
DECK_ID = 1607392320

# 定义模型
MODEL = genanki.Model(
    MODEL_ID,
    'Formula Card',
    fields=[
        {'name': 'Category'},
        {'name': 'Question'},
        {'name': 'Answer'},
        {'name': 'AlternativeForms'},
    ],
    templates=[{
        'name': 'Card 1',
        'qfmt': '[$$]{{Question}} = \\, ?[/$$]',
        'afmt': '[$$]{{Question}} = {{Answer}}[/$$]',
    }],
    css='.card { font-family: Arial; text-align: center; }'
)

def parse_formula(formula):
    """解析公式，返回 (问题, 答案, 其他形式)"""
    parts = [p.strip() for p in formula.split('=') if p.strip()]
    if len(parts) < 2:
        return None, None, None
    
    question, answer = parts[0], parts[1]
    alts = None
    if len(parts) > 2:
        alts = ' \\n '.join(f"{parts[i]} = {parts[i+1]}" 
                           for i in range(1, len(parts)-1))
    return question, answer, alts

def main():
    # 创建牌组
    deck = genanki.Deck(DECK_ID, '数学公式')
    
    # 提取并解析公式...
    # 添加笔记: deck.add_note(genanki.Note(model=MODEL, fields=[...]))
    
    # 导出
    genanki.Package(deck).write_to_file('output.apkg')

if __name__ == '__main__':
    main()
```

---

## 五、检查清单

在生成 .apkg 前确认：

- [ ] 使用 `genanki` 库（推荐）
- [ ] 模型包含 `css` 字段
- [ ] LaTeX 使用 `[$$]...[/$$]` 格式
- [ ] Note ID 唯一
- [ ] 过滤掉非公式内容
- [ ] 多等号公式正确处理
- [ ] 分类信息正确记录

---

## 六、测试验证

生成后用 Python 验证：

```python
import zipfile, sqlite3, json, tempfile

with zipfile.ZipFile('output.apkg') as z:
    with tempfile.TemporaryDirectory() as d:
        z.extract('collection.anki2', d)
        conn = sqlite3.connect(f'{d}/collection.anki2')
        cur = conn.cursor()
        cur.execute('SELECT COUNT(*) FROM notes')
        print(f'笔记数: {cur.fetchone()[0]}')
```

导入 Anki 后检查：
- 公式是否正确渲染
- 卡片正反面是否正确
- 分类标签是否显示

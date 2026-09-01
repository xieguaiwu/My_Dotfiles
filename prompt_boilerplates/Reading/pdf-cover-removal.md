---
name: pdf-cover-removal
version: 1.0.0
description: 批量移除PDF电子书封面页（前封面、后封面、衬页），预览与阅读均无封面
triggers:
  - "移除封面"
  - "去掉封面"
  - "删除电子书封面"
  - "PDF去封面"
  - "封面移除"
  - "cover removal"
inputs:
  - name: target_dir
    description: 待处理 PDF 所在目录（含子目录）
    required: true
  - name: remove_endpapers
    description: 是否同时移除封面衬页（纯色空白页）
    required: false
    default: true
  - name: vision_agent
    description: 视觉分类子代理名称
    required: false
    default: "multimodal-looker"
tools:
  - read
  - write
  - bash
  - grep
  - find
  - subagent
  - ask_user
---

# PDF 封面移除 Skill

> 扫描版 PDF 电子书常含前封面、后封面、封里、衬页。本 skill 用「墨量统计 + 视觉子代理 + 像素交叉验证」三明治流程定位并移除之，使文件预览与阅读均无封面。

## 任务目标

批量移除目录下所有 PDF 电子书的封面页（前封面、后封面、封里、封面衬页），保留标题页、扉页、版权页、正文。输出每本书的移除摘要。核心保障：视觉结论必须通过像素数据交叉验证，防 AI 幻觉误删或漏删。

## 执行流程

### 1. 清点目标 PDF

用 `find` 枚举 `{target_dir}` 下全部 PDF（含子目录）：

```bash
find "$TARGET_DIR" -iname '*.pdf'
```

逐本记录页数。**用 `qpdf --show-npages`，禁 pdfinfo**——Windows 生成的 PDF（stream 后仅 CR）pdfinfo 报 Syntax Error 且可能漏输出 Pages 行，中断 `&&` 链。

```bash
qpdf --show-npages "书.pdf"
```

### 2. 全量低分辨率渲染与墨量统计

每本渲染全部页面为 20 dpi 灰度 PNG（并行加速）。**文件名含空格、括号、撇号，禁 xargs -I + bash -c 字符串插值**（实测括号导致语法错误）；用内部循环 + `wait -n` 限并发：

```bash
out=/tmp/covstats
while IFS='|' read -r i f; do
  pdftoppm -r 20 -png -gray "$f" "$out/b${i}" 2>/dev/null &
  jobs=$((jobs+1)); [ $jobs -ge 8 ] && { wait -n; jobs=$((jobs-1)); }
done < /tmp/booklist.txt
wait
```

注意 pdftoppm 输出命名按总页数补零（154 页 → `b9-001.png`）。用 PIL 计算每页特征：

```python
ink = (im < 128).mean()      # 暗像素占比
std = im.std()               # 内容方差
blank: ink < 0.006；dark: ink > 0.55
```

输出每本书：前 6 页、末 6 页 ink 序列，加 blank/dark 异常页清单。

### 3. 候选页筛选与高分辨率渲染

候选页 = 前 6 页 + 末 6 页 + dark/blank 异常页。候选页以 100 dpi 彩色渲染（`pdftoppm -f N -l N -r 100 -png`），供视觉代理判读。

### 4. 蒙太奇构建

用 PIL 将候选页拼为网格图，每格左上角红字标签 `bookN page M`，另附该页 ink/std 数值，便于代理对照：

```python
cell_w, cell_h = 380, 520；缩放入格；grid.save('/tmp/montages/bookN.png')
```

### 5. 视觉子代理分类

派 `{vision_agent}` 逐格分类：`front_cover | back_cover | inside_cover | endpaper_blank | blank | title_page | half_title | copyright_page | content_page | photo_page | ad_page | other`。任务描述必须包含：

- 每页像素统计（ink、std），要求代理描述与数值自洽
- 显式警告：**页若空白或纯色，如实报"空白/纯色"，禁编造文字内容**（实测代理两次把空白页描述成"密集正文"）
- 重点问题：当前第 1 页是否封面样式？开头是否藏第二张封面？末页是否为后封面？

调用示例：

```python
subagent({
  agent: "multimodal-looker",
  task: "分类蒙太奇 /tmp/montages/bookN.png …",
  timeoutMs: 600000
})
```

### 6. 像素交叉验证（铁律）

视觉描述与像素数据矛盾即视为可疑，须复核：

- 代理说"米色浅色页"但 ink > 0.3 → 疑（实测把深色封面误判为浅色书名页）
- 代理说"密集文字"但 ink < 0.01 且 std < 35 → 疑（实测空白页被说成正文）
- 全书底色异常时（如某书全书 ink 中位数 0.44，整本深色扫描），用全书分位数区分"书自己的设计"与"封面"，勿凭单页深色判封面
- 必要时以外部参照比对：把疑似封面页与 OpenLibrary / 出版社官网封面图对照（实测以此坐实封面残留）
- 结论可疑时，重渲染该页 100 dpi 复核像素，或再派一轮代理交叉问询

### 7. qpdf 拆分移除

对确认的封面页用 qpdf 拆分（保留其余页）：

```bash
qpdf "书.pdf" --pages . 2-450 -- tmp.pdf
```

**qpdf 带警告成功时退出码非 0**（如 stream 仅 CR 的 Windows 文件），`&&` 链会中断且 tmp 残留。安全姿势：分步执行——先 `qpdf --show-npages tmp.pdf` 确认页数正确，再 `mv tmp.pdf "书.pdf"`。

封面范围判定：
- 前封面 = 第 1 页（或开头连续封面页）
- 后封面 = 末页（常有出版社徽标、ISBN、条形码、宣传文案）
- 封面衬页 = 封面内衬的纯色页（ink≈1 且 std < 10 的均匀深色，或均匀浅色）——`{remove_endpapers}` 为 true 时一并移除
- 末尾连续空白块（ink < 0.006，实测 13 页）——多为扫描衬纸，按用户意图移除

### 8. 终验

移除后，重渲染每本新第 1、2 页与倒数第 1、2 页（100 dpi），构建终验蒙太奇，再派一轮视觉复核，重点确认：

- 第 1 页不再是封面样式
- 末页不再是后封面
- 衬页已清除

终验通过后方可交付。清理解析用临时目录（/tmp 下）。

## 输出格式

交付时输出移除摘要表：

| 电子书 | 原页数 → 新页数 | 移除内容 |
|---|---|---|
| 书名.pdf | 452 → 449 | 前封面、后封面（条形码页） |

另列保留项（标题页、扉页、版权页、献词页、书内广告页等），并提醒用户文件名为 Vol.II 但封面标注 Vol.I 之类异常。

## 注意事项

- **封面不止第 1 页**：后封面、封里、衬页、重复封面图都可能藏在首尾数页内；只删第 1 页不满足"阅读时无封面"
- **保留非封面页**：标题页、扉页照片、版权页、目录页、献词页、广告页均非封面，禁删
- **20 dpi 会漏浅淡褪色扫描**（全书均值 ≈230 的浅淡书，20 dpi ink≈0 误判空白，100 dpi 有真实内容）——疑似空白页须 100 dpi 复核
- **视觉代理幻觉是最大风险**（实测两例：空白→正文、封面→书名页）——交叉验证不可省
- **模糊页先问用户**：无法定性的深色页/纯色页，用 `ask_user` 确认后再删
- **删前确认可恢复**：确认文件可重新下载，或先备份；qpdf 原位替换不可逆
- 文件名含特殊字符（括号、撇号、空格）时，脚本一律用变量传递，禁字符串拼命令

## 变更日志

### 1.0.0 (2026-08-25)
- 初始发布。沉淀 2026-08-25 实战流程：9 本 WWII 扫描书移除 27 页封面，抓出视觉代理两次幻觉（空白→正文、封面→书名页）
- 核心：墨量统计筛候选 → 视觉子代理分类 → 像素交叉验证 → qpdf 拆分 → 终验

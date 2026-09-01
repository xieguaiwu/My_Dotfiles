---
name: ffmpeg-narration-video
version: 1.0.0
description: 把文稿转成带旁白、字幕、花字的横竖屏视频（本地 TTS + PIL 卡片 + ffmpeg 逐段合成）
triggers:
  - "稿子转视频"
  - "旁白视频"
  - "ffmpeg合成"
  - "视频剪辑脚本"
  - "TTS配音视频"
  - "B站稿件出片"
inputs:
  - name: script_md
    description: 稿件 Markdown 路径（含分镜与旁白文本）
    required: true
  - name: orientation
    description: '横竖屏: wide（16:9 1920x1080）或 tall（9:16 1080x1920）'
    required: false
    default: "wide"
  - name: tts_rate
    description: 'TTS 语速倍率（如 "+25%"）'
    required: false
    default: "+50%"
  - name: server
    description: '渲染服务器 SSH 主机（可选，缺省本地）'
    required: false
    default: ""
tools:
  - read
  - write
  - bash
  - edit
  - grep
  - subagent
  - todo_create
---

# ffmpeg 旁白视频管线 Skill

> 以《我为什么讨厌加缪》双版本实战为源（2026-08-28，横屏 6:10→5:18、竖屏 2:34→2:23，全程 ffmpeg 命令行）。管线：稿件分镜 → 本地 edge-tts 逐段旁白 → 素材（Wikimedia 公共领域图 + PIL 程序化卡片）→ 服务器逐段合成（zoompan + drawtext 字幕/花字 + concat）→ 抽帧验证。

## 任务目标

把分镜稿件转成可发布的横/竖屏 MP4。产出：旁白 TTS、画面卡（真图 + 文字卡）、合成视频、验证证据。核心保障：字幕不遮挡画面、时长预算可控、素材可溯源。

## 执行流程

### 1. 读稿提取旁白与分镜

用 `read` 读稿件，按段落/分镜切出旁白文本（每段一个 TTS 单元）。同时记录镜头画面清单（哪段配哪张图/卡片）。文本与 TTS 同源：字幕文本存 JSON（`texts.json`），合成脚本读取，杜绝旁白与字幕不一致。

### 2. 本地生成 TTS 旁白

用 `edge-tts`（本地网络可达；服务器常不通微软端到端，2026-08-28 实测 NoAudioReceived）。音色 `zh-CN-YunxiNeural`（云希，男声沉稳，适合知识区）；语速横屏 +25%~+50%、竖屏 +50%~+65%。每段一个 mp3（`h01.mp3` 等），文件名稳定，便于重渲染。

```bash
edge-tts --voice zh-CN-YunxiNeural --rate=+50% --text "旁白文本" --write-media h01.mp3
```

- 踩坑：并发 4 限流报 `NoAudioReceived` 且生成 0 字节文件（2026-08-28 实测）。
- 修复：并发降至 2，每段重试 5 次（间隔 2+2n 秒），成功后校验文件 >1000 字节。
- 防复发：`asyncio.gather` 每批 2 个；模块顶层勿放 `asyncio.run(main())`（import 会误触发重复生成），脚本数据与执行分离。

### 3. 素材下载（Wikimedia）

公共领域图从 Wikimedia 获取：诺奖照、书封面、作家肖像、奖章等。

- 踩坑：服务器直连 `commons.wikimedia.org/w/api.php` 返回非 JSON（被挡）；直连 `upload.wikimedia.org` 也不稳（2026-08-28 实测）。
- 修复：本地（或可连的机器）下载后 `scp` 上传。
- 踩坑：API 连续请求触发 429 限流（`Expecting value` / HTTP 429）。
- 修复：先用 API 搜索拿**准确文件名**，再用 `https://commons.wikimedia.org/wiki/Special:FilePath/<文件名>?width=900` 直链下载；每次间隔 5-8 秒；UA 带浏览器标识；失败重试。
- 经验：文件名的猜测（如 `Das Schloss (Kafka, 1926).jpg`）大概率 404——先 `action=query&list=search&srnamespace=6` 拿真实文件名再直链。

### 4. PIL 生成画面卡

卡片统一 1920x1080（横）或 1080x1920（竖），黑底 + 白/黄/红字，Noto CJK 字体。

- 字体：`/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc` 是 ttc 多 face 文件；PIL 需循环 `index=0..5` 探测 `getname()` 含 `SC` 的 face（2026-08-28 实测），否则默认 face 是 JP。
- **字幕规范 hook（思想经验）**：用户要求"字幕（含卡片）不加句号逗号"时，在统一绘制入口做清洗——`T()`/`C()` 内部 `text.replace("，","").replace("。","")`，一处修改全卡生效，勿逐字手改。
- **底部留白**：drawtext 字幕贴底 + 半透明黑底条（`box=1:boxcolor=black@0.55:boxborderw=12`），故卡片文字一律不进底部 200px（横屏 0.80H 以上 / 竖屏 0.78H 以上禁放文字），保证"字幕不遮挡画面"。
- 踩坑：`Image.new("RGB",(W,H))` 默认全黑，直接 `paste` 到图上是**整图盖黑**；需用 `draw.rectangle` 画局部遮罩或 RGBA 透明底（2026-08-28 实测 c_mythe_quote 封面消失）。
- 踩坑：横竖双尺寸复用同一函数时，字号 `int(42*s)`（s=W/1080）在横屏变 74px，行距不足导致文字重叠（2026-08-28 实测 c_moyan2）。修复：横屏专用卡用固定字号，或统一行距 ≥ 1.2 倍字号。
- 竖屏专属卡：注册表区分 `WONLY`/`VONLY` 集合，避免横屏循环浪费生成或文件名错乱。

### 5. 服务器合成（ffmpeg）

**先检环境，再全量跑**：

```bash
ffmpeg -encoders | grep -E 'libx264|openh264'   # 确认编码器可用
```

- 踩坑：anaconda 自带 ffmpeg 4.3 无 libx264，`-preset` 直接报 `Unrecognized option 'preset'`（2026-08-28 实测）。
- 修复：`apt-get install -y ffmpeg` 装系统版 4.4.2，全脚本用绝对路径 `/usr/bin/ffmpeg`、`/usr/bin/ffprobe`。
- 踩坑：服务器无 `subtitles`（libass）滤镜——字幕只能用 `drawtext`（libfreetype）；textfile 方式避免转义地狱（冒号/逗号写进 text 参数会破坏 filter）。

逐段合成（每段 = 若干子画面 + 该段音频）：

```bash
# 子画面: 2x 预放大防 zoompan 抖动, zoom 1.0→1.06 全程均匀
ffmpeg -y -loop 1 -framerate 25 -t {dur} -i card.png \
  -vf "scale=3840:2160:force_original_aspect_ratio=increase,crop=3840:2160,\
zoompan=z='min(zoom+{0.06/frames},1.06)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1920x1080:fps=25,\
fade=t=in:st=0:d=0.22,fade=t=out:st={dur-0.22}:d=0.22" \
  -c:v libx264 -preset medium -crf 21 -pix_fmt yuv420p -an part.mp4
```

- zoompan 增量：`0.06/frames`（frames=dur*25），最后一帧恰好 1.06，避免 `min(zoom+0.0008,1.06)` 前快后停。
- 同段子画面用 concat demuxer（同编码 `-c copy`）拼 `seg_raw.mp4`；再 pass 一次叠加字幕/花字并 mux 音频（`-shortest`），最后整片 concat。

音频准备（每段统一采样率 + 首尾静音 + 淡入淡出防爆音）：

```bash
ffmpeg -y -i seg.mp3 -af "aresample=44100,pan=stereo|c0=c0|c1=c0,adelay=100|100,apad=pad_dur=0.15,\
afade=t=in:st=0:d=0.05,afade=t=out:st={total-0.06}:d=0.05" -ar 44100 -c:a pcm_s16le seg.wav
```

字幕/花字 drawtext（时间轴按句字数比例分配；长句 >52 字先拆两段）：

```bash
drawtext=fontfile=/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc:textfile=sub.txt:fontsize=42:fontcolor=white:borderw=3:bordercolor=black:box=1:boxcolor=black@0.55:boxborderw=12:x=(w-text_w)/2:y=922:enable='between(t,2.24,9.15)'
```

- 踩坑：验证抽帧时 `-ss 3 -i input`（输入侧）是快速 keyframe seek，显示 t≈0 帧而非 3s；精确验证用 `-i input -ss 3`（输出侧解码 seek）（2026-08-28 实测误判"字幕缺失"）。
- 花字字号：横屏 `int(H*0.07)`≈75px；竖屏超 100px 会溢出 1080 宽被裁，用 82px 单行（2026-08-28 实测"最安全的「深刻」符号"缺字）。

### 6. 验证

`ffprobe` 查时长/分辨率/音轨；按分段时间表抽帧对照稿件分镜（每段至少 1 帧）。抽帧网格拼接成一张总览图核对，勿凭文件名顺序猜测（字符串排序会混序，曾误判"整片乱序"）。

### 7. 回传与沉淀

`scp` 回本地；脚本与素材留存服务器（`build.py wide|tall` 可重跑）；写 memory 记录产出、参数、踩坑。

## 输出格式

- 视频：`*.mp4`（h264 + aac 160k，25fps；横 1920x1080 / 竖 1080x1920；crf 21）
- 时长预算：段时长 = TTS 音频 + 0.25s（0.10 前置 + 0.15 尾静音）；整片 = 各段之和，语速 +50% 约比 +25% 提速 17%
- 脚本留存：`gen_tts.py`（本地）、`gen_cards.py` + `build.py`（服务器 `/root/camus_video/`）
- 素材：Wikimedia 图（记录文件名）+ 卡片 PNG（`cards/*.png`，横竖双套）

## 注意事项

- 先测 ffmpeg 编码器（libx264）再开工，勿假设默认 ffmpeg 可用（anaconda 无 libx264 教训）
- 服务器渲染用 `nohup python3 build.py wide > build.log 2>&1 &` 后台跑，轮询日志与产物计数；日志路径用绝对路径，防止 cd 后相对路径错位
- TTS 文本保留句读（供语音停顿）；**字幕层**另做标点清洗——两者分离，勿在 TTS 文本上删标点
- 字幕黑底条会占底部 200px：卡片文字布局时（含竖屏）预留该区域，或用 `0.80H` 上限校验
- concat 要求各段编码参数一致（同 preset/crf/分辨率/时间基），否则 demuxer 拼接报错或时间戳错乱
- 段落变化时（如用户要求删段/加段）优先改 `plan()` 列表与 `texts.json`，勿重排 TTS 文件名

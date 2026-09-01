---
name: media-torrent-download
version: 1.0.0
description: 死链资源打捞与BT下载——直链/IPFS失效时经批量种子定位单文件，aria2c选择性下载书籍影视音乐等资源
triggers:
  - "bt下载"
  - "种子下载"
  - "磁力链接"
  - "死链捞书"
  - "aria2下载"
  - "libgen种子"
inputs:
  - name: target_list
    description: '目标资源列表。{ title, md5?, torrent_path?, final_name? } 数组'
    required: true
  - name: output_dir
    description: 下载落盘目录
    required: false
    default: ~/Downloads/books/
tools:
  - bash
  - read
  - write
  - web_search
  - grep
author: pi-agent
tags: [download, torrent, aria2c, libgen, bt, media]
---

# Media Torrent Download

> 直链、IPFS 尽皆失效之时，经批量种子定位单文件，以 aria2c 捞取之。适用于书籍（libgen 生态）、影视、音乐等一切存在公开 tracker 之资源。

## 任务目标

资源站点直下按钮缺失、IPFS 网关尽皆 403 之际，循资源站之批量种子体系（如 libgen 每 1000 册一种子），定位单个文件序号，以 `aria2c --select-file` 抽取之。产出：校验合格、依书单重命名之文件。

## 执行流程

### 1. 穷尽直连渠道（先易后难）

- HTTP 直下按钮、IPFS 各网关逐一试探。IPFS 网关清单：pinata / ipfs.io / dweb.link / w3s.link / 4everland / cloudflare-ipfs / gateway.ipfs.io / hardbin / ipfs.eth.aragon.network。
- 判据：`curl -r 0-100` 返回 403 或超时者，视为 unpinned。九网关皆殁，则 IPFS 路线止，入第 2 步。

```bash
timeout 25 curl -sL -r 0-100 -A "Mozilla/5.0" -o /dev/null -w "%{http_code}\n" "https://gateway.pinata.cloud/ipfs/<CID>"
```

### 2. 获取批量种子

- libgen 生态：条目页（`file.php?id=`）镜像区含 `/torrents/libgen/r_XXXXXXX.torrent`（每 1000 册一种子）；另有 `pilimi-zlib-*`（Anna's Archive zlib 备份）可作备选。
- 影视音乐：公开 tracker 站检索同名种子，或以 magnet + DHT 直接获取元数据。
- 种子文件仅百余 KB，curl 本地存之。

### 3. 解析种子定位目标

python 手写 bdecode 解码 `info.files`。libgen 种子两特征：

- 文件名 = **纯 MD5 hash**，无原名
- `info.name` = 批次号，即落盘子目录名

```python
def bdecode(data):
    def dec(i):
        c=data[i:i+1]
        if c==b'i': j=data.index(b'e',i); return int(data[i+1:j]),j+1
        if c==b'l':
            i+=1; l=[]
            while data[i:i+1]!=b'e': v,i=dec(i); l.append(v)
            return l,i+1
        if c==b'd':
            i+=1; d={}
            while data[i:i+1]!=b'e':
                k,i=dec(i); v,i=dec(i); d[k]=v
            return d,i+1
        j=data.index(b':',i); n=int(data[i:j])
        return data[j+1:j+1+n],j+1+n
    v,_=dec(0); return v
```

MD5 之来源：条目页正则 `MD5[:<>/strong\s]*([a-f0-9]{32})`，或 onion 链接路径中段。以 MD5 匹配种子文件名，得三元组 `(torrent, file_index, size)`。

非 libgen 资源（影视音乐）：以标题关键词模糊匹配 `path` 字段，人工确认后取 index。

### 4. aria2c 选择性下载

```bash
aria2c --seed-time=0 --enable-dht=true \
  --dht-listen-port=6882 --listen-port=6883-6890 \
  --select-file=<idx> --file-allocation=none --continue=true \
  --summary-interval=0 \
  --bt-tracker="udp://tracker.opentrackr.org:1337/announce,udp://open.tracker.cl:1337/announce,udp://tracker.openbittorrent.com:6969/announce" \
  -d dl tor.torrent
```

多本依次处理时，封装为映射表脚本（ASSOC ARRAY eid→最终文件名），循环体：find dl -name $md5 校验 size → 合格则 mv 重命名，否则 aria2c 续传。模板见 `~/Downloads/books/ss-wiking/dlfix.sh`。

### 5. 后台化与断点

```bash
cd <workdir> && setsid nohup ./dlfix.sh > progress.log 2>&1 & disown
```

脱离终端（防 SIGHUP）；`.aria2` 控制文件记录分片级进度，重启机器后重跑脚本即续传。已完成项自动跳过。

### 6. 完整性校验

- size 与种子声明精确相等
- magic bytes：PDF 验 `%PDF`，EPUB 验 zip 头 `PK`
- 不合格者保留 `.aria2` 断点，标记 FAIL 待续

## 输出格式

- 目标目录下：已重命名之最终文件（pdf/epub/mp4/mkv 等）
- 工作目录下：`found.json`（定位三元组）、`md5s.json`、`progress.log`（SKIP/DONE/FAIL 流水）、`dlfix.sh`（可复用脚本）

## 注意事项

- **参数坑**：`--file-allocation=false` 非法值会秒退，须用 `none`；`--listen-port=0` 非法，须 1024-65535
- **pkill 坑**：`pkill -f 'script名'` 会误杀含该字符串之当前命令自身——先 pgrep 排除 $$ 再 kill，或用 `pkill -x`
- **多实例坑**：数个后台实例抢 DHT 端口 6882、共写同一日志必互相干扰——启动前必须清场
- **路径坑**：断点控制文件在 `-d dir/<批次名>/` 层级，校验路径勿写死 `dl/libgen/`；用 `find dl -name $md5` 动态定位
- **速度预期**：老资源常仅 1 seeder，约 4 KB/s/本，全程可能逾十小时——挂机勿催
- **边界**：JS 挑战站（Anna's Archive antibot、DDoS-Guard）此法无解，须浏览器自动化或手动；无人做种之资源不可救
- **版权**：仅限公有领域、合理使用或用户自有授权之资源

### 附：Tor 通道预置（2026-08-26 实战验证）

本机已备独立 tor 实例（SocksPort 9051，obfs4 网桥经 clash 中转），供 IPFS/直链尽殁后探查与下载之用：

```bash
# 启动（幂等，已运行则跳过）
~/.local/share/tor-dl/start.sh
# 就绪标志：日志出现 Bootstrapped 100%，代理地址 socks5h://127.0.0.1:9051
```

- 配置：`~/.local/share/tor-dl/torrc`（网桥池 4 个）；备用池 `spare_bridges.txt`；启动器 `start.sh`
- libgen onion 镜像（libgenfrial…onion）：目录浏览 + HEAD 可探测任意文件存在性与大小（路径 `/LG/<repo前4位>/<MD5>`），**GET 被服务器故意禁用**——仅作校验工具，勿浪费时间尝试直下
- 网桥失效征兆：Bootstrapped 长期停滞 <50%。从 `spare_bridges.txt` 轮换替换 torrc 中 Bridge 行后重启实例
- 坑：torrc 必须显式声明 `ClientTransportPlugin obfs4 exec /usr/bin/obfs4proxy`（Tor Browser 运行时注入，独立实例不会自动有）；重启勿用 pkill -f 匹配含路径字符串的模式（会自杀），用 pgrep -x tor 后按 pid kill

## 变更日志

### 1.1.0 (2026-08-26)
- 新增：附「Tor 通道预置」节——本机 tor-dl 实例（9051）启动、网桥池轮换、libgen onion HEAD 探测用法
- 沉淀：ss-wiking 实战中 tor 网桥配置全流程（含 ClientTransportPlugin 缺失、pkill 自杀两坑）

### 1.0.0 (2026-08-26)
- 初始发布。源自 ss-wiking 书单实战（9/14 册经批量种子捞回）

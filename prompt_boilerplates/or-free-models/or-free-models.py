#!/usr/bin/env python3
"""or-free-models — 快速找出 OpenRouter 上的免费模型并按性能代理指标排序。

用法:
  or-free-models                # 列出全部免费模型，按综合评分降序
  or-free-models --top 10       # 只看前 10
  or-free-models --live         # 额外拉取每模型的实时吞吐/延迟/在线率(慢)
  or-free-models --json         # JSON 输出
  or-free-models --min-ctx 128000

评分构成（0-100 归一后加权）:
  参数量线索 35% + 档位关键词 25% + 上下文长度 15% + 能力广度 25%
"""
import argparse
import json
import math
import re
import sys
import urllib.request

API = "https://openrouter.ai/api/v1/models"

# 档位关键词 → 分值（按优先级匹配，命中即停）
TIER_KEYWORDS = [
    ("ultra", 95), ("pro-preview", 90), ("max", 90), ("large", 88),
    ("pro", 85), ("super", 80), ("reasoning", 78), ("omni", 75),
    ("standard", 65), ("code", 62), ("it", 60),
    ("mid", 55),
    ("mini", 40), ("small", 40), ("lite", 38),
    ("nano", 30), ("light", 28), ("tiny", 25), ("micro", 22),
]

def parse_params(model_id: str) -> float:
    """从模型名解析参数量(B)，返回 0 表示未知。支持 '550b-a55b' '31b' '2.6b'"""
    slug = model_id.split("/")[-1].lower()
    # 总参-激活参格式: xxx-550b-a55b → 用总参
    m = re.search(r"(\d+(?:\.\d+)?)b(?:-a\d+(?:\.\d+)?)?b?(?:$|-)", slug)
    if m:
        try:
            return float(m.group(1))
        except ValueError:
            return 0
    return 0

def tier_score(model_id: str) -> int:
    slug = model_id.split("/")[-1].lower()
    for kw, sc in TIER_KEYWORDS:
        if kw in slug:
            return sc
    return 50  # 中性默认

def capability_score(m: dict) -> float:
    arch = m.get("architecture", {}) or {}
    mods_in = set((arch.get("input_modalities") or ["text"]))
    sc = 0.0
    if "text" in mods_in: sc += 30
    if "image" in mods_in: sc += 20
    if "video" in mods_in or arch.get("modality") == "video+text->text": sc += 15
    sc += min(len(m.get("supported_parameters") or []), 20) * 1.5  # 工具调用/reasoning 等结构支持
    return sc

def ctx_score(ctx: int) -> float:
    if not ctx: return 0
    return min(math.log10(ctx) / math.log10(2_000_000), 1.0) * 100

def param_score(b: float) -> float:
    if b <= 0: return 35  # 未知给中性偏下分
    return min(math.log10(b * 1e9) / math.log10(600e9), 1.0) * 100

def composite(m: dict) -> dict:
    mid = m["id"]
    p = parse_params(mid)
    t = tier_score(mid)
    ps, ts = param_score(p), float(t)
    cs = ctx_score(m.get("context_length") or 0)
    cb = capability_score(m)
    total = ps * .35 + ts * .25 + cs * .15 + cb * .25
    return {
        "id": mid,
        "name": m.get("name", ""),
        "ctx": m.get("context_length"),
        "modal": ",".join((m.get("architecture", {}) or {}).get("input_modalities") or []),
        "params_B": p or None,
        "score": round(total, 1),
        "sub": {"param": round(ps,1), "tier": round(ts,1), "ctx": round(cs,1), "cap": round(cb,1)},
    }

def fetch(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "or-free-models/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)

def live_stats(model_id: str):
    """拉取 /endpoints 端点，只统计免费 provider 的吞吐与在线率。"""
    try:
        base = model_id.split(":")[0]  # 去掉 :free 后缀
        d = fetch(f"https://openrouter.ai/api/v1/models/{base}/endpoints")
        eps = [e for e in (d.get("data", {}).get("endpoints") or [])
               if e.get("pricing", {}).get("prompt") == "0"
               and e.get("pricing", {}).get("completion") == "0"]
        if not eps:
            return {"tps": None, "latency_s": None, "uptime": None, "providers": 0}
        tps_vals = [e.get("throughput_last_30m") for e in eps if e.get("throughput_last_30m")]
        lat_vals = [e.get("latency_last_30m") for e in eps if e.get("latency_last_30m")]
        up = sum(e.get("uptime_last_30m") or 0 for e in eps) / len(eps)
        return {"tps": round(max(tps_vals)) if tps_vals else None,
                "latency_s": round(min(lat_vals), 2) if lat_vals else None,
                "uptime": f"{up:.1f}%", "providers": len(eps)}
    except Exception as e:
        return {"error": str(e)[:60]}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", type=int, default=0)
    ap.add_argument("--min-ctx", type=int, default=0)
    ap.add_argument("--live", action="store_true")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    data = fetch(API)
    free = [m for m in data["data"]
            if m.get("pricing", {}).get("prompt") == "0"
            and m.get("pricing", {}).get("completion") == "0"]

    rows = [composite(m) for m in free]
    if args.min_ctx:
        rows = [r for r in rows if (r["ctx"] or 0) >= args.min_ctx]
    rows.sort(key=lambda r: -r["score"])

    if args.live:
        print(f"# 拉取 {len(rows)} 个模型的实时 provider 数据…", file=sys.stderr)
        for r in rows:
            r["live"] = live_stats(r["id"])
            lv = r.get("live") or {}
            # 吞吐并入总评：tps 对数缩放占 20%，重算排名
            if lv.get("tps"):
                bonus = min(math.log10(lv["tps"] + 1) / math.log10(150), 1.0) * 100
                r["score"] = round(r["score"] * 0.8 + bonus * 0.2, 1)
        rows.sort(key=lambda r: -r["score"])

    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
        return

    hdr = f"{'rank':<4} {'model id':<52} {'score':>5} {'ctx':>9} {'modal':<14} {'params':>7}"
    if args.live:
        hdr += f"  {'tps':>6} {'up%':>6}"
    print(hdr)
    print("-" * len(hdr))
    shown = rows[:args.top] if args.top else rows
    for i, r in enumerate(shown, 1):
        line = f"{i:<4} {r['id']:<52} {r['score']:>5} {(r['ctx'] or 0)//1000:>7}k {r['modal']:<14} {str(r['params_B'] or '?'):>7}"
        if args.live:
            lv = r.get("live") or {}
            line += f"  {str(lv.get('tps','?')):>6} {str(lv.get('uptime','?')):>6}"
        print(line)

if __name__ == "__main__":
    main()

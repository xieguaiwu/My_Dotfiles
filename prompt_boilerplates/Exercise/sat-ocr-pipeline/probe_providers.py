#!/usr/bin/env python3
"""探测哪个视觉 provider 可用; 可用则写 PROBE_OK"""
import base64, json, os, urllib.request, urllib.error, sys

def try_provider(name, url, key, model):
    b64 = base64.b64encode(open('/tmp/sat_ocr/pages/reading_-007.png', 'rb').read()).decode()
    payload = {'model': model, 'max_tokens': 20,
               'messages': [{'role': 'user', 'content': [
                   {'type': 'text', 'text': 'Say OK'},
                   {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,' + b64}}]}]}
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
        headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + key})
    try:
        with urllib.request.urlopen(req, timeout=45) as r:
            d = json.load(r)
        print(f'{name} OK')
        return True
    except urllib.error.HTTPError as e:
        print(f'{name} {e.code}')
        return False
    except Exception as e:
        print(f'{name} ERR {str(e)[:60]}')
        return False

ok = False
ok |= try_provider('openrouter', 'https://openrouter.ai/api/v1/chat/completions',
    os.environ.get('OPENROUTER_API_KEY', ''),
    'nvidia/nemotron-nano-12b-v2-vl:free')
ok |= try_provider('kimi', 'https://api.moonshot.cn/v1/chat/completions',
    os.environ.get('KIMI_API_KEY', ''), 'kimi-k3')
ok |= try_provider('nvidia', 'https://integrate.api.nvidia.com/v1/chat/completions',
    os.environ.get('NVIDIA_API_KEY', ''),
    'nvidia/nemotron-nano-12b-v2-vl')
if ok:
    open('/tmp/sat_ocr/PROBE_OK', 'w').close()
print('probe done')

#!/usr/bin/env python3
"""
Gemini Vision API 图像识别工具
可直接集成到 opencode-cli 等 CLI 工具中作为外部命令调用

使用方法:
  python gemini_vision_tool.py <图片路径> [提示词]
  python gemini_vision_tool.py /path/to/image.png "描述这张图片"
  python gemini_vision_tool.py --base64 <base64字符串> "分析这张图片"
  echo <base64> | python gemini_vision_tool.py --stdin "这是什么"

环境变量:
  GEMINI_API_KEY - Google Gemini API 密钥 (必需)

获取 API 密钥:
  https://makersuite.google.com/app/apikey
"""

import argparse
import base64
import json
import os
import sys
import mimetypes
from pathlib import Path
from typing import Optional
from urllib.request import Request, urlopen
from urllib.error import HTTPError


# Gemini API 端点 (可选模型: gemini-flash-latest, gemini-2.0-flash, gemini-2.5-flash)
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

# 支持的图片格式
SUPPORTED_FORMATS = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.gif': 'image/gif',
    '.heic': 'image/heic',
    '.heif': 'image/heif',
}


def get_api_key() -> str:
    """获取 API 密钥"""
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("错误: 未设置 GEMINI_API_KEY 环境变量", file=sys.stderr)
        print("获取密钥: https://makersuite.google.com/app/apikey", file=sys.stderr)
        sys.exit(1)
    return api_key


def detect_mime_type(file_path: str) -> str:
    """检测图片 MIME 类型"""
    ext = Path(file_path).suffix.lower()
    if ext in SUPPORTED_FORMATS:
        return SUPPORTED_FORMATS[ext]
    
    # 使用 mimetypes 模块检测
    mime_type, _ = mimetypes.guess_type(file_path)
    if mime_type and mime_type.startswith('image/'):
        return mime_type
    
    return 'image/jpeg'  # 默认


def load_image_from_file(file_path: str) -> tuple[str, str]:
    """从文件加载图片并转换为 base64"""
    path = Path(file_path)
    if not path.exists():
        print(f"错误: 文件不存在 - {file_path}", file=sys.stderr)
        sys.exit(1)
    
    mime_type = detect_mime_type(file_path)
    
    with open(path, 'rb') as f:
        image_data = f.read()
    
    b64_data = base64.b64encode(image_data).decode('utf-8')
    return b64_data, mime_type


def analyze_image(
    image_b64: str,
    mime_type: str,
    prompt: str,
    api_key: str,
    max_tokens: int = 1024
) -> str:
    """调用 Gemini Vision API 分析图片"""
    
    url = f"{GEMINI_API_URL}?key={api_key}"
    
    payload = {
        "contents": [{
            "parts": [
                {
                    "inline_data": {
                        "mime_type": mime_type,
                        "data": image_b64
                    }
                },
                {
                    "text": prompt
                }
            ]
        }],
        "generationConfig": {
            "maxOutputTokens": max_tokens,
            "temperature": 0.7
        }
    }
    
    headers = {
        "Content-Type": "application/json"
    }
    
    try:
        request = Request(
            url,
            data=json.dumps(payload).encode('utf-8'),
            headers=headers,
            method='POST'
        )
        
        with urlopen(request, timeout=60) as response:
            result = json.loads(response.read().decode('utf-8'))
        
        # 解析响应
        if 'candidates' in result and len(result['candidates']) > 0:
            candidate = result['candidates'][0]
            if 'content' in candidate and 'parts' in candidate['content']:
                for part in candidate['content']['parts']:
                    if 'text' in part:
                        return part['text']
        
        # 错误处理
        if 'error' in result:
            return f"API 错误: {result['error'].get('message', '未知错误')}"
        
        return f"无法解析响应: {json.dumps(result, ensure_ascii=False)}"
    
    except HTTPError as e:
        error_body = e.read().decode('utf-8')
        return f"HTTP 错误 ({e.code}): {error_body}"
    except Exception as e:
        return f"请求失败: {str(e)}"


def main():
    parser = argparse.ArgumentParser(
        description="Gemini Vision API 图像识别工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s image.png
  %(prog)s photo.jpg "这张图片里有什么?"
  %(prog)s --base64 "iVBORw0KGgo..." "描述图片"
  cat image.png | base64 | %(prog)s --stdin "分析图片"
        """
    )
    
    parser.add_argument(
        "image",
        nargs="?",
        help="图片文件路径"
    )
    parser.add_argument(
        "prompt",
        nargs="?",
        default="请详细描述这张图片的内容",
        help="对图片的提问/指令 (默认: 描述图片内容)"
    )
    parser.add_argument(
        "--base64",
        dest="b64_input",
        help="直接提供 base64 编码的图片数据"
    )
    parser.add_argument(
        "--stdin",
        action="store_true",
        help="从 stdin 读取 base64 编码的图片"
    )
    parser.add_argument(
        "--mime-type",
        default="image/jpeg",
        help="图片 MIME 类型 (使用 --base64 或 --stdin 时需要)"
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=1024,
        help="最大输出 token 数 (默认: 1024)"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="以 JSON 格式输出结果"
    )
    
    args = parser.parse_args()
    
    # 获取 API 密钥
    api_key = get_api_key()
    
    # 获取图片数据
    image_b64 = None
    mime_type = args.mime_type
    
    if args.stdin:
        # 从 stdin 读取
        b64_input = sys.stdin.read().strip()
        image_b64 = b64_input
    elif args.b64_input:
        # 从命令行参数获取
        image_b64 = args.b64_input.strip()
    elif args.image:
        # 从文件读取
        image_b64, mime_type = load_image_from_file(args.image)
    else:
        parser.print_help()
        print("\n错误: 请提供图片路径或使用 --base64/--stdin", file=sys.stderr)
        sys.exit(1)
    
    # 清理 base64 数据 (移除可能的前缀)
    if image_b64.startswith('data:'):
        # 格式: data:image/jpeg;base64,xxxxx
        parts = image_b64.split(',', 1)
        if len(parts) == 2:
            # 提取 MIME 类型
            header = parts[0]
            if 'image/' in header:
                mime_start = header.index('image/')
                mime_end = header.index(';', mime_start)
                mime_type = header[mime_start:mime_end]
            image_b64 = parts[1]
    
    # 调用 API
    result = analyze_image(
        image_b64=image_b64,
        mime_type=mime_type,
        prompt=args.prompt,
        api_key=api_key,
        max_tokens=args.max_tokens
    )
    
    # 输出结果
    if args.json:
        output = {
            "success": not result.startswith(("错误", "HTTP 错误", "请求失败", "API 错误")),
            "prompt": args.prompt,
            "response": result
        }
        print(json.dumps(output, ensure_ascii=False, indent=2))
    else:
        print(result)


if __name__ == "__main__":
    main()

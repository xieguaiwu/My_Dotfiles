#!/bin/bash

# 检查是否提供了所有必需的参数
if [ $# -ne 4 ]; then
    echo "用法: $0 <PDF文件> <起始页> <结束页> <输出文件名>"
    echo "示例: $0 document.pdf 1 10 output.pdf"
    exit 1
fi

WHICHFILE=$1
FROM=$2
ENDINGPAGE=$3
OUTPUTNAME=$4

# 检查输入文件是否存在
if [ ! -f "$WHICHFILE" ]; then
    echo "错误: 文件 '$WHICHFILE' 不存在"
    exit 1
fi

# 检查页码参数是否为数字
if ! [[ "$FROM" =~ ^[0-9]+$ ]] || ! [[ "$ENDINGPAGE" =~ ^[0-9]+$ ]]; then
    echo "错误: 页码必须是数字"
    exit 1
fi

# 检查输出文件名是否包含 .pdf 扩展名
if [[ "$OUTPUTNAME" != *.pdf ]]; then
    echo "警告: 输出文件名不包含 .pdf 扩展名，已自动添加"
    OUTPUTNAME="${OUTPUTNAME}.pdf"
fi

echo "正在从 '$WHICHFILE' 提取第 $FROM 到 $ENDINGPAGE 页到 '$OUTPUTNAME' ..."
qpdf "$WHICHFILE" --pages . $FROM-$ENDINGPAGE -- "$OUTPUTNAME"

if [ $? -eq 0 ]; then
    echo "成功: PDF 页面提取完成，输出文件: $OUTPUTNAME"
else
    echo "错误: qpdf 命令执行失败"
    exit 1
fi

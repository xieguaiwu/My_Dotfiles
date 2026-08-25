#!/bin/bash
# cron 看门狗 v7: 只保活本地 3B lane（openrouter 午夜由专项脚本接管）
cd /tmp/sat_ocr
PY=/root/anaconda3/bin/python3
if ! ps aux | grep -q "[l]ocal_worker"; then
  setsid nohup bash -c "cd /tmp/sat_ocr && PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True $PY local_worker.py reading; PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True $PY local_worker.py grammar" > /tmp/sat_ocr/lw.log 2>&1 < /dev/null &
  echo "$(date +%H:%M:%S) restarted local" >> /tmp/sat_ocr/supervise.log
fi

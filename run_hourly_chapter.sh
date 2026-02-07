#!/bin/bash
# ========================================
# 网文小说自动生成脚本
# 功能：每小时生成新章节，自动提交并推送到GitHub
# ========================================

# 配置变量
PROJECT_DIR="$HOME/yidaiwenhao"
GENERATOR="$PROJECT_DIR/chapter_generator.py"
LOG_FILE="$PROJECT_DIR/cron_log.txt"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 进入项目目录
cd "$PROJECT_DIR" || exit 1

# 记录开始
log "========== 开始生成新章节 =========="

# 1. 生成新章节
log "正在生成新章节..."
python3 "$GENERATOR" --auto >> "$LOG_FILE" 2>&1
GENERATION_RESULT=$?

if [ $GENERATION_RESULT -ne 0 ]; then
    log "❌ 章节生成失败，退出"
    exit 1
fi

# 2. 检查是否有新文件生成
NEW_FILES=$(git status --porcelain | grep "^?? .*\.md$" | grep -E "ch[0-9]{3}\.md$" || true)

if [ -n "$NEW_FILES" ]; then
    log "检测到新章节："
    echo "$NEW_FILES" | while read -r file; do
        log "  - $file"
    done
    
    # 3. 添加文件到Git
    log "正在添加文件到Git..."
    git add .
    
    # 4. 提交更改
    CHAPTER_NUM=$(git status --porcelain | grep -E "ch[0-9]{3}\.md$" | head -1 | sed 's/^...//' | sed 's/\.md$//')
    log "正在提交章节 $CHAPTER_NUM..."
    git commit -m "Auto-generate chapter $CHAPTER_NUM - $(date '+%Y-%m-%d %H:%M')" >> "$LOG_FILE" 2>&1
    
    # 5. 推送到远程
    log "正在推送到远程仓库..."
    git push origin main >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "✅ 章节 $CHAPTER_NUM 生成并推送成功！"
    else
        log "⚠️ 推送失败，请检查网络连接"
        exit 1
    fi
else
    log "⚠️ 没有检测到新章节，可能是今天已完成"
fi

# 6. 更新进度追踪
python3 -c "
import json
from datetime import datetime

progress_file = '$HOME/.openclaw/workspace/memory/novel-writing-automation-chapters.json'
with open(progress_file, 'r') as f:
    data = json.load(f)

data['last_generated'] = datetime.now().isoformat()

with open(progress_file, 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
"

log "========== 本次执行完成 =========="
log ""

# QWeather (和风天气) CLI 配置备份

备份日期：2026-08-01 · 工具：qw v0.5.0 (yinguobing/qweather-skill) · JWT 认证 (Ed25519)

## 文件清单

| 文件 | 说明 | 机密性 |
|---|---|---|
| `ed25519-public.pem` | JWT 公钥（已上传和风控制台） | 非机密 |
| `ed25519-private.pem.gpg` | **私钥加密备份**（gpg AES256） | 🔒 机密 |
| `qw.env` | qw 环境变量（kid/项目ID/API Host/私钥路径） | 标识符 |
| `tq` | 顺义天气一键查询脚本 | 非机密 |

## 恢复步骤（新机器）

```bash
# 1. 建目录并解出私钥（需要备份密码）
mkdir -p ~/.config/qweather && chmod 700 ~/.config/qweather
gpg -d -o ~/.config/qweather/ed25519-private.pem \
    ed25519-private.pem.gpg
chmod 600 ~/.config/qweather/ed25519-private.pem

# 2. 安装 qw（预编译二进制）
curl -sSL https://raw.githubusercontent.com/yinguobing/qweather-skill/main/install.sh | bash

# 3. 恢复配置
cp qw.env ~/.config/qweather/qw.env
cp tq ~/.local/bin/tq && chmod +x ~/.local/bin/tq
# 若用户名/路径变化，编辑 qw.env 中的 QWEATHER_PRIVATE_KEY 路径

# 4. fish 环境变量：追加到 ~/.config/fish/config.fish
#    内容见 My_Dotfiles/fish/config.fish 末尾「和风天气 qw CLI」段

# 5. 验证
tq          # 或: qw weather now --city 顺义
```

## 安全说明

- 备份密码：**不在本仓库内**。存储于密码管理器，或（临时）`~/.config/qweather/qweather-backup-passphrase.txt`（权限 600，用完即删）
- 私钥只解到本机 `~/.config/qweather/`，**永不入 git**；恢复后建议立即 `chmod 600`
- 若私钥泄露/丢失：控制台 → 项目管理 → 删除该 JWT 凭据 → 重新生成密钥对上传（kid 会变，同步更新 qw.env 与 fish 配置）

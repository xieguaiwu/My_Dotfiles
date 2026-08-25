---
name: fdroid-publishing
version: 1.0.0
description: 引导安卓应用上线 F-Droid——合规审查、fastlane 元数据、可复现构建、fdroiddata 提交与发版纪律
triggers:
  - "F-Droid 发布"
  - "安卓上架 F-Droid"
  - "fdroid 收录"
  - "fdroid 上线"
  - "fdroid metadata"
inputs:
  - name: android_repo
    description: 安卓应用仓库本地路径
    required: true
  - name: app_id
    description: 应用包名，auto 时从 build.gradle 自动检测
    required: false
    default: "auto"
  - name: signing_strategy
    description: 签名策略，fdroid 为官方签名，self 为自有签名可复现路线
    required: false
    default: "fdroid"
tools:
  - read
  - bash
  - write
  - edit
  - web_search
  - fetch_content
---

# F-Droid 上线发布

安卓应用（Kotlin/Compose、Flutter 等）上线 F-Droid 主仓库的完整流程。经验沉淀自 2026-08-24 pocket-llm-api-checker 实战：合规审查 → repo 准备 → 可复现构建 → fdroiddata 提交 → 发版纪律。

## 任务目标

引导任意安卓应用通过 F-Droid 收录审查并在主仓库发布。产出：合规预检结论、fastlane 元数据、可复现构建验证、fdroiddata metadata 文件、发版流程。流程之先判方向——F-Droid 硬性要求逐项可查，缺项集中在前置工程化（tag、元数据、提交），非代码改造。

## 执行流程

### 1. 合规预检（Inclusion Policy）

对照官方 Inclusion Policy 逐项核验，先取证再下结论：

1. **许可证**：仓库根有 LICENSE 文件，MIT/Apache-2.0/GPL 等 OSI 或 FSF 认可许可证。
2. **源码公开**：公共仓库、真实源码（非占位文件）、tag 与版本对应。
3. **依赖全 FOSS**：仅 `google()` + `mavenCentral()` 仓库；禁 Firebase、GMS（Google Play Services）、专有 SDK。GMS 依赖直接拒绝收录，须出无 GMS 变体。
4. **构建工具 FOSS**：标准 Gradle/Flutter 即可；wrapper 必须提交（`gradlew` + `gradle/wrapper/`）。
5. **无专有二进制**：扫仓库内 jar/so/预编译物（fdroidserver 构建时扫描，发现即失败）。
6. **权限与隐私面**：权限最小化、`usesCleartextTraffic=false`、`allowBackup=false`（含敏感凭据的应用）、无广告/统计/遥测 SDK。
7. **版本信息位置标准**：versionCode/versionName 在 `app/build.gradle.kts` android 块或 AndroidManifest（`UpdateCheckMode: Tags` 正则可提取）。

预检结论分三类：硬性缺失（须补）、反特性（须声明）、推荐项（可复现构建）。硬性缺失清单写入项目计划文档。

### 2. 反特性评估

判定应用是否触发 F-Droid 反特性标记，在 metadata 如实声明：

| 反特性 | 判定 | 是否阻止收录 |
|---|---|---|
| NonFreeNet | 应用依赖专有网络服务（如客户端指向专有 API/平台） | 否，仅显示警告徽章 |
| TetheredNet | 依赖不可替换的单一服务（2024-07 新增，细化了 NonFreeNet） | 否 |
| NonFreeDep | 依赖设备上安装的专有应用 | 阻止 |
| NonFreeAssets | 含非自由素材（NC/ND 类 CC 授权图音等） | 阻止 |
| Tracking | 默认收集或泄露用户数据 | 阻止 |

判定要点：客户端类应用（查余额、看用量、播视频）几乎必触 NonFreeNet，不阻止收录，但必须声明并在 full_description 说明。评估用 `read` 检查 Manifest 与依赖清单，用 `web_search` 核对反特性最新定义。

### 3. repo 侧准备（发布工程化）

#### 3.1 版本与 tag

- 首次发布前确认 versionCode/versionName 与 tag 对应：`v<versionName>`（如 v1.0.0）。
- 打 tag 前必须已提交全部发布准备变更（tag 指向的 commit 即 F-Droid 构建源）。
- 版本纪律：每次发布递增 versionCode（单调即可），versionName 同步。

#### 3.2 fastlane 元数据（官方要求 "should always be added before inclusion"）

目录结构（en-US 默认 + 目标语言本地化）：

```text
fastlane/metadata/android/
├── en-US/
│   ├── short_description.txt      # <80 字符，无结尾句点
│   ├── full_description.txt       # 每行 ≤80 字符，说明功能/隐私/反特性
│   ├── changelogs/
│   │   └── 1.txt                  # 文件名 = versionCode，≤500 字符
│   └── images/
│       ├── icon.png               # 512x512 起，从应用矢量图标精确渲染
│       └── phoneScreenshots/
│           ├── 1.png              # 真实界面截图，禁伪造数据
│           └── 2.png
└── zh-CN/                         # 同构本地化
```

要点：
- icon 从 `ic_launcher_*.xml` 矢量精确渲染（PIL/cairosvg），勿用 AI 生成与实物不符的图标。
- 截图必须真实（模拟器或真机侧载 capture）；无设备时先放同配色占位图并在计划文档标注「待替换」，上架前替换。
- full_description 声明数据源（官方 API/页面解析）与反特性，reviewer 会核对。

#### 3.3 可复现构建验证（强烈推荐，非强制）

- **可行性速判**：纯 Kotlin/Java + `isMinifyEnabled=false`（无 R8）+ 无 NDK + 无 PNG 资源 → 大概率开箱可复现。
- 验证脚本：干净树双构建，对比 release APK SHA-256（含 `SOURCE_DATE_EPOCH`，对齐 F-Droid buildserver）：

```bash
#!/usr/bin/env bash
set -euo pipefail
git diff --quiet --exit-code || { echo "工作区不干净"; exit 1; }
export SOURCE_DATE_EPOCH="$(git log -1 --format=%ct)"
for i in 1 2; do
  ./gradlew clean assembleRelease --no-daemon > /tmp/rb-build-$i.log 2>&1
  find app/build/outputs/apk -name '*.apk' | sort | xargs sha256sum > /tmp/rb-hash-$i.txt
done
diff -u /tmp/rb-hash-1.txt /tmp/rb-hash-2.txt && echo "OK 可复现"
```

- 常见不可复现源：R8 优化非确定、baseline.prof/profm、PNG crunch、AGP 8.3+ vcsInfo（须在 tag 处干净树构建，勿禁用除非确需）、build-tools 版本漂移。
- 实测通过后即可启用 **Verified 徽章路线**：自有签名 keystore → 签名 APK 发布到 GitHub Releases → metadata 加 `Binaries:` + `AllowedAPKSigningKeys:`（SHA-256 指纹），F-Droid 重建比对一致则用开发者签名发布。
- **签名决策窗口在首次发布前**：Android 不允许更新换签名，F-Droid 官方签名后不可再切自有签名（用户须重装）。

### 4. fdroiddata 提交

1. 起草 metadata：`metadata/<applicationId>.yml`（模板见「输出格式」）。
2. 校验：`Categories` 必须在官方 `config/categories.yml` 存在；`commit` 用 tag（全哈希更佳）。
3. fork `gitlab.com/fdroid/fdroiddata` → 新建分支 → 提交 MR。GitLab CI 自动跑 lint + 构建验证，失败看流水线日志修 metadata。
4. 本地可选：`fdroid lint <appid>` 预检（需安装 fdroidserver，非必需，CI 会跑）。
5. MR 合并后 24-48 小时出现在主仓库（签名步骤人工介入所致延迟）。

### 5. 发版纪律（收录后每次更新）

1. bump versionCode/versionName（build.gradle.kts android 块）。
2. 更新 `fastlane/metadata/android/*/changelogs/<versionCode>.txt`。
3. 提交 + `git tag v<versionName>` + push tag。
4. 若走 Verified 路线：CI/本地构建签名 → 上传 GitHub Releases（URL 须与 `Binaries` 模板匹配）。
5. F-Droid checkupdates 每日扫描 tag 自动发现，无需人工提交。

## 输出格式

产出三件：合规预检结论（写入项目计划文档）、repo 侧变更（fastlane + 脚本 + tag）、fdroiddata metadata 草稿。

fdroiddata metadata 模板（`metadata/<applicationId>.yml`）：

```yaml
Categories:
  - System                    # 必须存在于官方 categories.yml
License: MIT
AuthorName: 作者名
SourceCode: https://github.com/用户/仓库
IssueTracker: https://github.com/用户/仓库/issues
Changelog: https://github.com/用户/仓库/releases
AutoName: 应用名
RepoType: git
Repo: https://github.com/用户/仓库
Builds:
  - versionName: 1.0.0
    versionCode: 1
    commit: v1.0.0
AntiFeatures:
  - NonFreeNet                # 按第 2 步评估结果声明
AutoUpdateMode: Version
UpdateCheckMode: Tags
CurrentVersion: 1.0.0
CurrentVersionCode: 1
```

## 注意事项

1. **NonFreeNet 不阻止收录**，但隐瞒比声明更糟——reviewer 会逐行读代码，反特性漏标会被打回。
2. **签名不可中途更换**：首次发布前必须定签名策略；选 F-Droid 官方签名则简单省事，选自有签名则从第一版开始走。
3. **apksigner 版本坑**：build-tools ≥35.0.0-rc1 的 apksigner 产出与 apksigcopier 不兼容（fdroiddata#3299）——走 Verified 路线 CI 固定用 build-tools 34 的 apksigner。
4. **页面解析类数据源**（如解析 HTML 账单页）：在描述中声明「官方页面结构变化可能导致功能失效」，reviewer 与用户预期管理。
5. **review 周期不可控**：fdroiddata MR 排队 1-4 周常见，提交后保持 MR 评论响应。
6. **截图禁伪造**：AI 生成的假数据截图一旦被识破影响收录信任；真机侧载 capture 最稳。
7. **标签纪律**：`UpdateCheckMode: Tags` 依赖 tag 命名稳定（`v<versionName>`），乱打 tag（含 alpha/beta）需加正则过滤。
8. **ABI 拆分**：含 native 库的大包建议 ABI split，versionCode 用 `VercodeOperation` 低位编码（arm64 < x86 < x86_64 递增序）。
9. **官方文档**：Inclusion Policy、Submitting Quick Start、Build Metadata Reference、Reproducible Builds——均以 f-droid.org/docs/ 为准，反特性定义以 Anti-Features 页为准，动手前用 `fetch_content` 核对最新版。

## 变更日志

### 1.0.0 (2026-08-24)
- 初始发布。经验来源：pocket-llm-api-checker 实战（合规审查全过、可复现双构建一致、fastlane 双语元数据、fdroiddata 草稿），计划详见 `~/Desktop/go-projects/LLM-api-check/docs/plans/2026-08-24-fdroid-publishing-plan.md`

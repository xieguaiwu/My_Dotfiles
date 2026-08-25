---
name: android-development
version: 1.1.0
description: 安卓 Kotlin/Compose 应用开发全流程——脚手架、Activity 入口测试、Compose 触摸交互测试、安全存储、构建发布与血泪踩坑库
triggers:
  - "安卓开发"
  - "Android 项目"
  - "Kotlin Compose"
  - "新建安卓应用"
  - "APK 构建"
  - "Robolectric 测试"
inputs:
  - name: project_dir
    description: 安卓项目根目录
    required: true
  - name: verify_device
    description: 是否需要真机验证
    required: false
    default: false
tools:
  - read
  - bash
  - write
  - edit
  - grep
  - subagent
  - todo_create
---

# Android 应用开发（Kotlin/Compose）

经验沉淀自 2026-08 两项目实战：`pocket-llm-api-checker`（API Checkers）与 `currency-transfer`（FX Pixel）。本 skill = 标准流程 + 血泪踩坑库，任何安卓项目开工或回归时对照执行。

## 任务目标

按标准流程交付可用的安卓应用（APK + 测试 + 发布包），规避两大已实测致命坑：**Activity 入口占位代码上线**、**readOnly TextField 点击失效**。流程覆盖脚手架 → 入口接线 → 交互测试 → 数据层 → 安全 → 构建发布。

## 执行流程

### 1. 项目脚手架

模板优先——从已有项目复制配置，勿从零手写：

1. 复制 `gradle/wrapper/`、`gradlew`、`gradlew.bat`（已验证组合：Gradle 8.9 + AGP 8.5.2 + Kotlin 2.0.21 + Compose BOM 2024.10.00 + compileSdk 35 + minSdk 26 + targetSdk 35，JDK 17/21 均可）。
2. 写 `settings.gradle.kts`、根 `build.gradle.kts`、`gradle.properties`、`local.properties`。
3. `.gitignore` 必须含：`local.properties`、`.gradle/`、`build/`、`.kotlin/`、`keystore.properties`。
4. `app/build.gradle.kts`：namespace 独立；release 签名用可选 `keystore.properties`（存在才加载，不入库）；`testOptions.unitTests.isIncludeAndroidResources = true`（Robolectric 必需）。
5. Manifest：INTERNET 权限、`usesCleartextTraffic=false`、`allowBackup=false`（含敏感凭据时）、`network_security_config.xml`（HTTPS only）。
6. 验证：`./gradlew assembleDebug` 通过。

### 2. Activity 入口接线（🔴 头号教训）

**症状**：应用在手机打开只显示占位文本，无任何功能。所有单测与 Paparazzi 截图都测**组件**，无人测 **Activity 入口**——MainScreen 从未被调用，42+ 测试全绿依然上线即废。

**铁律**：
- 脚手架 `MainActivity.kt` 的占位 `setContent` 一旦替换为真实 UI，**立即**写 Robolectric Activity 启动测试：

```kotlin
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class MainActivitySmokeTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun app_startsAndShowsExchangeTab() {
        composeRule.onNodeWithText("FX PIXEL").assertIsDisplayed()
        composeRule.onNodeWithText("Currency Exchange").assertIsDisplayed()
    }
}
```

- 依赖：`org.robolectric:robolectric:4.14.1` + `androidx.test.ext:junit` + `androidx.compose.ui:ui-test-junit4` + `ui-test-manifest`。
- 收尾检查（上线前）：`grep -rn "Currency Transfer" app/src/main` 之类占位文本扫描，占位即删除。

### 3. Compose 触摸交互测试（物理注入）

**症状**：点击货币选择字段无反应，无法切换货币（2026-08-24 实测用户反馈）。语义层测试却通过——假阳性。

**根因**：`OutlinedTextField(readOnly = true)` 内部消费 pointer 事件（聚焦/光标放置），外层 `modifier.clickable { dialogOpen = true }` 永远收不到事件。

**修复**：Box 包裹 + 透明 overlay 捕获点击：

```kotlin
Box(modifier = modifier) {
    OutlinedTextField(
        value = Currencies.displayName(selected),
        onValueChange = {},
        readOnly = true,
        label = { Text("Currency") },
        trailingIcon = { Icon(Icons.Filled.ArrowDropDown, contentDescription = "Select currency") },
        modifier = Modifier.fillMaxWidth(),
    )
    // readOnly TextField 消费点击，overlay 重新捕获
    Box(
        Modifier
            .matchParentSize()
            .clickable { dialogOpen = true },
    )
}
```

**测试铁律**：交互测试必须用 `performTouchInput { click() }`（真实 PointerInput hit-test 管线），**勿用** `performClick()`（语义层 OnClick action，绕过事件分发 → 假阳性）。

```kotlin
composeRule.onNodeWithText("US Dollar").performTouchInput { click() }
composeRule.waitForIdle()
composeRule.onNodeWithText("Select currency").assertIsDisplayed()
```

### 4. 数据层

- **接口注入**：网络源定义接口（`ExchangeRateSource`、`CpiSource`），ViewModel 构造注入，测试传 fake——零网络单测。
- **纯函数计算**：核心计算（通胀/换算）独立 `object` 纯函数，单测覆盖边界（空列表、null 值、非法区间）。
- **汇率全量拉取**：固定 base（USD）拉全量 rates map，目标币换算用 `rateTo / rateFrom`——切换货币零额外请求。
- **World Bank CPI**：`per_page=200`、`date=1990:2026`、返回降序、`value` 可 null（当年未发布须过滤）；区域映射 EUR → `EMU`（Euro area）。
- **SSR HTML 解析**（无 API 时的 fallback）：锚点定位（如 `customerID:"cus_"`）+ 深度括号匹配取对象 + 正则逐字段；**单位陷阱**——Zen balance 为 microcents（÷1e8 得 USD），务必先实测再固化。
- **日期聚合**：服务器已按天聚合时用字符串比较即可，勿自行转时区；跨月聚合 30 天**不截断**（momus P0 实测：`days.size` 被截到 7）。

### 5. 安全与凭据

- **加密存储**：Android Keystore AES-GCM 加密后写 SharedPreferences；加密失败降级明文但置 `securityWarning` 提示 UI——防锁死。
- 提交前静态扫描：`grep -rniE 'sk-[a-zA-Z0-9]{16,}|Fe26\.2\*|Bearer [a-zA-Z0-9]{20,}'` 源码与暂存区，命中即处理。
- 敏感文件（keystore.properties、cookie）绝不入库；README 用占位符说明获取方式。

### 6. UI 状态管理

- **刷新不闪断**：刷新期间保留旧数据渲染，成功后才替换（P2 级但体验关键）。
- **下拉刷新**：松手判定放 `pointerInput` 的 up 事件；决策函数（是否自动刷新/复位）提纯函数可单测。
- **错误处理**：网络错误显示可读消息 + 重试按钮，禁止崩溃；401/403 显式提示「凭据无效或已过期」。
- **限流显示**：被限流 API 必须同时显示「已限流」徽章与重置倒计时（`X小时X分后重置`），禁止替代。

### 7. 测试与质量门

三层测试并存：
- JVM 单测：纯逻辑（计算/解析/决策），`kotlinx-coroutines-test`。
- Robolectric：Activity 启动 + Compose 交互（见 §2/§3），`@Config(sdk=[34])` + `@GraphicsMode(NATIVE)`。
- Paparazzi 1.3.5：截图回归（真实 UI 代码渲染，fake 数据源注入）。

质量门：`./gradlew testDebugUnitTest lintDebug` 全绿；momus 审查循环（P0/P1/P2 分级，修复后复验）——首次审查必出 P0/P1 级问题，勿跳过。

### 8. 构建与发布

- **版本纪律**：bump versionCode/versionName → `git tag v<ver>` → fastlane changelog → push tag → GitHub Release（附 SHA-256）。
- **可复现验证**：tag 处干净树重新构建，哈希一致才发版（`scripts/verify-reproducible.sh`）。
- **F-Droid 上架**：走独立 skill `fdroid-publishing.md`（分类白名单无 "Money"，用 `Market & Price`；Builds 必须 `subdir: app`）。
- **真机验证**：华为手机 USB 坑——`hisuite_mtp_mass_storage_hdb` 模式无 ADB 接口（`adb devices` 不可见），须用户开 USB 调试；系统缺 `gvfsd-mtp/libmtp` 时 MTP 挂载不可行；推送脚本 `adb push` 到 `/sdcard/Download/`。

### 9. 平台强制项（2025-2026 实测有效，新项目开工即对照）

以下为近年平台级强制变更，遗漏会导致 UI 遮挡、返回失灵或上架失败：

| 强制项 | 生效条件 | 必须动作 |
|---|---|---|
| Edge-to-edge | targetSdk ≥ 35 且运行于 Android 15+ | 调用 `enableEdgeToEdge()`，用 `safeDrawingPadding()`/`windowInsetsPadding()` 处理系统栏 insets；不处理则内容被遮挡 |
| Predictive back | targetSdk ≥ 36 且运行于 Android 16+ | `onBackPressed` 不再调用、`KEYCODE_BACK` 不再分发——改用 `BackHandler`/`OnBackPressedCallback`；未迁移则返回手势失灵 |
| 16KB page size | 2025-11-01 起 Play 提交 target 35+ | 纯 Kotlin/Java（无 NDK）天然兼容；含 native 库须 16KB 对齐重编译，`zipalign -P 16` |
| Play targetSdk 强制 | 2026-08-31 起 | 新应用/更新须 target 36+；存量应用须 35+；F-Droid 无此强制但低 target 在新系统受行为限制 |

侧载分发（GitHub/F-Droid）不受 Play 截止日期约束，但 edge-to-edge 与 predictive back 是**运行时行为变更**，无论渠道均生效——检测到 targetSdk 变化即回归 UI 遮挡与返回导航测试。

### 10. Compose 重组性能纪律（社区泛化经验）

重组性能坑是 Compose 生产环境最大一类问题，遵循以下纪律：

- **勿传不稳定参数**：composable 参数只传 immutable/stable 类型。ViewModel、`MutableStateFlow` 持有者均为不稳定类型——传入则 lambda 亦不稳定，子组合**无法跳过重组**。
- **lambda 稳定化**：引用 ViewModel 方法的 lambda 不稳定；用 `remember` 包装或改为顶层稳定函数。
- **状态提升**：UI 状态提升至最低公共祖先；业务状态放 Composition 之外（ViewModel）；对外暴露不可变状态 + 事件回调。
- **remember 缓存**：组合体可能每帧重组，昂贵计算（格式化、集合变换）用 `remember`/`derivedStateOf` 缓存。
- **三阶段理解**：重组 → 布局 → 绘制各可独立跳过；改颜色触发整树重排 = 布局阶段未跳过。
- **性能调试用工具不用猜**：Composition Tracing + 系统 trace 定位；重组计数是初步信号。
- **Baseline Profiles**：预编译热路径，启动与滚动收益明显，发布前生成。
- **渐进迁移纪律**（混合 View/Compose 项目）：以导航图节点为迁移单元，以发版周期为验证窗口；同页混用警惕滚动冲突、主题撕裂、生命周期不齐。

### 11. 工具链版本纪律（社区泛化经验）

- **Kotlin 2.0+ 必用 Compose Compiler Gradle Plugin**（`org.jetbrains.kotlin.plugin.compose`），与 Kotlin 同版本发布；勿再配独立 composeOptions 编译器版本。缺插件报错即检查插件声明。
- **新主版本有生态滞后**：Kotlin 2.3 等新版本可能触发第三方插件 `NoSuchMethodError`——升级前查插件兼容矩阵，勿在生产主力分支抢先升级。
- **AGP 9.0 巨变**（2026-01）：新 DSL 独占、旧 Variant API 删除、内置 Kotlin（不再需要 `kotlin-android` 插件）；升级用官方 Upgrade Assistant 与 `gradle-recipes`，**勿搜网上旧示例**（旧 DSL 代码全部失效）。
- **Robolectric 亦可能 flaky**：Compose 测试虚拟时钟 + 全主线程与真机行为有差异（如 `clearFocus` 触发 `onFocusChanged` 两次）；flaky 防护 = 自定义 Test Rule 固定线程与隔离状态，`waitForIdle` 不满足时排查 effect 向主线程 post 的工作。
- 升级顺序纪律：Kotlin → AGP → compose BOM → 第三方插件，一次只动一个维度，每步全量测试。

## 输出格式

- **APK**：`app/build/outputs/apk/debug/app-debug.apk`（或 release 签名包）。
- **测试报告**：`app/build/reports/tests/` + lint 报告；测试计数与通过率。
- **文档**：`README.md` + `README_zh.md` 双语互链、`CONTEXT_FOR_NEXT_AGENT.md`（状态/遗留/技术要点/图谱）。
- **发布物**：git tag + GitHub Release（APK + SHA-256）+ fastlane metadata（F-Droid 时）。

## 注意事项

- **占位代码是上线级事故**：脚手架文件要么完成时替换，要么删除；上线前 grep 占位文本。检查清单必须含「Activity 启动端到端」环节。
- **语义测试 ≠ 真实交互**：`performClick` 绕过 hit-test，`performTouchInput` 才是真验证；两类测试都写，语义层测可达性，物理层测交互。
- **测试只测组件 ≠ 应用可用**：必须有 Activity 入口级测试（createAndroidComposeRule 真实启动）。
- 解析第三方页面结构脆弱：加锚点注释 + 单测 fixture，网页改版即失效需更新。
- `tools` 只列 pi-agent 真实工具；subagent 调用必须带 `timeoutMs`（轻 300000 / 中 600000 / 重 900000）。
- 单位换算（microcents、percent、resetsAt ISO8601）先实测再固化，避免「看着对」的假实现。
- §9-§11 为 2025-2026 公开社区与官方文档泛化经验（Reddit r/androiddev、Stack Overflow、掘金、developer.android.com），非本机实测——引用前按项目实际版本复核生效条件。

## 变更日志

### 1.1.0 (2026-08-24)
- 新增：§9 平台强制项——edge-to-edge（targetSdk 35+）、predictive back（targetSdk 36+）、16KB page size（2025-11 起 Play 要求）、Play targetSdk 政策（2026-08-31）
- 新增：§10 Compose 重组性能纪律——不稳定参数/VM 直传、lambda 稳定化、状态提升、remember 缓存、Baseline Profiles、渐进迁移纪律（泛化自 Reddit/Stack Overflow/掘金/官方文档 2025-2026 讨论）
- 新增：§11 工具链版本纪律——Kotlin 2.0+ Compose Compiler 插件同版本、新版本生态滞后、AGP 9.0 DSL 巨变（勿用旧示例）、Robolectric flaky 防护

### 1.0.0 (2026-08-24)
- 初始发布。经验来源：currency-transfer（FX Pixel）与 pocket-llm-api-checker 两项目实战
- 🔴 头号坑：MainActivity 占位代码上线（测试测组件不测入口）——Robolectric createAndroidComposeRule 入口测试铁律
- 🔴 二号坑：readOnly TextField 消费点击，外层 clickable 失效——overlay Box 修复 + performTouchInput 物理注入测试
- 集成：脚手架模板、数据层接口注入、Keystore AES-GCM、SSR 解析单位陷阱、下拉刷新决策纯函数、momus 审查循环、版本纪律、华为 USB 调试坑

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vex 是一个 V2EX 社区的原生 iOS 客户端，使用 SwiftUI 构建，Swift 6.0，最低支持 iOS 18.0。Bundle ID: `com.ryuichi.vex`。

## Build & Development

项目使用 **XCGen** 管理构建配置（`project.yml` → `Vex.xcodeproj`）。修改构建配置应编辑 `project.yml`，然后运行：

```bash
xcodegen generate
```

构建项目（模拟器）：
```bash
xcodebuild build -scheme Vex -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

构建并安装到模拟器：
```bash
xcodebuild build -scheme Vex -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcrun simctl install booted $(find ~/Library/Developer/Xcode/DerivedData/Vex-*/Build/Products/Debug-iphonesimulator -name "Vex.app" -maxdepth 1)
xcrun simctl launch booted com.ryuichi.vex
```

构建并安装到真机（iPhone 17 Pro）：
```bash
xcodebuild build -scheme Vex -destination 'platform=iOS,name=Ryuichi的iPhone'
xcrun devicectl device install app --device 42712654-735D-528D-8EA7-FC536131B9DE $(find ~/Library/Developer/Xcode/DerivedData/Vex-*/Build/Products/Debug-iphoneos -name "Vex.app" -maxdepth 1)
```

运行测试（使用 Apple Testing 框架，非 XCTest）：
```bash
xcodebuild test -scheme VexTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

运行单个测试（通过 `-only-testing` 指定）：
```bash
xcodebuild test -scheme VexTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing VexTests/函数名
```

## Dependencies (SPM)

- **SwiftSoup** — HTML 解析
- **Kingfisher** — 图片加载与缓存
- **MarkdownUI** — Markdown 渲染
- **Lottie** — 加载/刷新动画（`Vex/Resources/*.lottie`）

## Architecture

### 目录结构
```
Vex/
├── Models/          # 数据模型（Topic, Member, Node, Feed, Response）
├── Services/        # 业务逻辑层（网络、解析、状态管理）
├── Navigation/      # Router + DeepLinkHandler
├── Views/           # SwiftUI 视图，按功能分目录（Home, Topic, Member, Node, Search, Settings, Auth, iPad, Browser, Components）
├── Utils/           # ClipboardWatcher, HapticManager
├── Resources/       # Lottie 动画文件（*.lottie）
└── Assets.xcassets/ # 图片资源和 App 图标
```

### 数据获取方式
V2EX 没有可用的 REST API，所有数据通过 **HTML 抓取 + SwiftSoup 解析**获取。`V2EXClient` 使用 URLSession 发请求，`HTMLParser` 负责从 DOM 中提取结构化数据。原版 React Native 实现位于 `/Users/ryuichi/Documents/GitHub/v2ex-react-native`，可作为参考。

### 状态管理
- `@Observable` + `@Environment`：大多数 Manager（`AuthManager`、`Router`、`AlertManager` 等），在 `VexApp.swift` 根级用 `.environment()` 注入
- `ObservableObject` + `@EnvironmentObject`：`ThemeManager`、`AppSettingsManager`（因依赖 `@AppStorage`，与 `@Observable` 不兼容），用 `.environmentObject()` 注入
- `V2EXClient` 是 `ObservableObject`，但未注入环境，各 View 直接调用其 `shared` 单例方法
- `actor CacheManager` 保证线程安全的缓存

### 导航
- iPhone: TabView（3 个 tab：主题、消息、搜索）+ NavigationStack（每个 tab 独立 NavigationPath）
- iPad: SidebarView（通过 `horizontalSizeClass` 切换）
- 深度链接：`vex://t/{id}`, `vex://go/{node}`, `vex://member/{username}`，也支持 `https://www.v2ex.com/...` 格式
- `Router` 通过 `homeBarsVisible` 控制主页滚动时导航栏/Tab Bar/FAB 的联动隐藏
- 所有 NavigationStack 共享 `.commonNavigationDestinations()` 扩展，统一注册 `TopicBasic`/`MemberBasic`/`NodeBasic` 的目标视图

### 核心 Services
| 文件 | 职责 |
|------|------|
| `V2EXClient.swift` | HTTP 请求、Cookie 管理、50+ API 端点、副作用提取（ONCE token/未读数/余额） |
| `HTMLParser.swift` | HTML→结构化数据、统一 `parsePagination` 解析、Cloudflare 邮箱解码（XOR）、`resolveURL` 处理协议相对 URL |
| `AuthManager.swift` | 用户会话、登录态、未读消息数、余额、审核员 Demo 模式 |
| `Router.swift` | 路由状态、tab 间导航、每 tab 独立 NavigationPath |
| `CacheManager.swift` | 内存+UserDefaults 混合缓存，带 TTL |
| `CloudflareManager.swift` | Cloudflare 验证弹窗处理，通过 `NotificationCenter` 通知验证完成后刷新数据 |
| `AlertManager.swift` | Toast 提示（成功/错误/信息） |
| `AppSettingsManager.swift` | 用户偏好、首页 Tab 配置持久化（排序/启用/禁用）、图床配置 |
| `FavoriteNodesManager.swift` | 收藏节点管理 |
| `ViewedTopicsManager.swift` | 浏览历史追踪 |
| `ImageUploader.swift` | Imgur 匿名 API 图片上传 |
| `ClipboardWatcher` (Utils) | 剪贴板 V2EX 链接检测 |
| `HapticManager` (Utils) | 触觉反馈 |

### V2EXClient 关键模式

**副作用提取**：`fetchHTML` 在解析 HTML 时自动提取 ONCE token、未读消息数、当前用户名、余额，更新 `@Published` 属性。

**ONCE token 去重**：`getOnce()` 复用正在进行的请求（`onceTask`），避免并发重复请求。每次修改操作后调用 `invalidateOnce()`。

**合并请求**：`getTopicDetailWithReplies(id)` 一次请求同时获取帖子详情和第一页回复，避免 `TopicDetailView` 重复请求同一页面。

**Cloudflare 403 处理**：收到 403 立即设置 `shouldPrepareFetch = true`，`CloudflareManager` 通过 Combine 监听弹出验证 WebView，验证完成后发送 `.cloudflareVerificationCompleted` 通知，各 View 监听此通知自动刷新。

### 首页 Tab 配置与分页

**Tab 标识**：`HomeTabOption.storageKey`（格式 `type:value`，如 `home:tech`、`node:swift`）是唯一标识，`value` 仅用于 API 请求。Tab 类型有 `home`（内置）、`node`（自定义节点）、`user`、`xna`。

**Tab 配置持久化**：`AppSettingsManager.configuredHomeTabs(from:)` 合并远程可用 Tab 和用户排序配置，`mergedHomeTabs()` 自动注入 "最近" Tab。设置界面在 `FavoriteNodesSettingsView.swift`（实际是 `HomeTabSettingsView`），支持拖拽排序、禁用/启用、添加自定义节点 Tab。

**首页分页**：双触发机制——最后一项 `.onAppear` + 底部哨兵 `onGeometryChange`。追加时按 `id` 去重。"最近" Tab 使用锚点时间戳（`recentPaginationAnchor`）避免翻页时内容漂移。"最热" Tab 仅第一页（走 REST API）。节点类型 Tab 调用 `getNodeFeeds` 并映射为 `HomeTopicFeed`。

### HTML 内容渲染
`HTMLContentView` 使用原生 SwiftUI 渲染 HTML 内容。整个渲染管线集中在 `HTMLContentView.swift` 中：

1. `HTMLContentPreprocessor.normalize()` — 预处理：修复转义的 img 标签、孤立图片属性、Markdown 图片语法等畸形 HTML
2. `HTMLBlockParser.parse()` — 解析为 `HTMLBlock` 枚举（text/image/inline/codeBlock/blockquote）
3. `HTMLContentView` — 渲染各 block 类型；单文本块有快速路径优化

**文本渲染使用 `Text` 拼接**（`HTMLBlockParser.buildText(from:)`），而非 `AttributedString`，以正确渲染 emoji 等 supplementary plane 字符。链接仍用 `AttributedString` 包装以保持可点击性，其余文本用 `Text(verbatim:)` + `.bold()/.italic()/.font(.monospaced)` 修饰符拼接。

**图片分流逻辑**：纯图片段（截图独占一行）→ block 级图片；图文混排（表情嵌在文字中）→ inline 片段，由 `HTMLInlineFragmentsView` 渲染（先查 Kingfisher 缓存，异步加载后嵌入 `Text(Image(uiImage:))`）。

**图片画廊**：点击图片打开 `ImageGalleryView` 全屏查看，支持多图左右滑动、捏合缩放、双击切换、保存到相册。`HTMLContentView` 收集所有 block 中的图片 URL 传递给画廊。

**尺寸计算**：`HTMLImageLayout.displaySize` 计算 block 图片显示尺寸（最大 320×360，小图有 `minHeight: 24` 兜底），`HTMLInlineImageLayout` 控制内联图片（表情）尺寸（目标高 24，最大宽 32）。

测试辅助：`HTMLContentParserTestSupport.blockKinds(for:)` 用于测试解析结果。

### 帖子详情页
- `TopicDetailView` 初始加载使用 `getTopicDetailWithReplies(id)` 合并请求
- 回复分页：手动 "加载更多回复" 按钮，调用 `getTopicReplies(id, page:)` 追加
- 回复输入框直接内联在底部（`TopicBottomBar`），不使用 sheet
- 回复行（`ReplyRow`）显示可见的操作按钮（回复/感谢/会话），不藏在 context menu
- 会话线程通过 `repliedTo` 和 `membersMentioned` 追踪
- 支持 `scrollToReplyNum` 参数定位到指定回复
- 支持 `auth.isDemoMode` 时本地模拟操作状态

## Code Conventions

- Swift 6.0 严格并发：Model 遵循 `Sendable`，Manager 标注 `@MainActor`，CacheManager 使用 `actor`
- 每个文件一个主要类型，相关枚举/结构体可嵌套
- UI 字符串和注释使用中文
- View body 保持精简，复杂逻辑抽到 computed property
- 错误类型使用 `V2EXError` 枚举，遵循 `LocalizedError`
- Model 使用 JSONDecoder `.convertFromSnakeCase`，不要同时定义 `CodingKeys`（会冲突）
- 协议相对 URL（`//cdn.v2ex.com/...`）需通过 `HTMLParser.resolveURL()` 处理
- API 返回值使用泛型包装：`PaginatedResponse<T>`（带分页）、`EntityResponse<T>`（单实体）、`CollectionResponse<T>`（列表）、`StatusResponse<T>`（操作结果）
- 测试使用 Apple Testing 框架（`import Testing`），用 `@Test func` 定义、`#expect()` 断言，不要用 XCTest 的 `XCTAssert`
- 分页解析统一使用 `HTMLParser.parsePagination(_:page:)`，不要在各解析方法中重复分页逻辑

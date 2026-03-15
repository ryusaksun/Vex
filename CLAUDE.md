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
- `V2EXClient` 是 `ObservableObject`，但未注入环境，各 View 直接调用其静态/实例方法
- `actor CacheManager` 保证线程安全的缓存

### 导航
- iPhone: TabView（3 个 tab：主题、消息、搜索）+ NavigationStack（每个 tab 独立 NavigationPath）
- iPad: SidebarView（通过 `horizontalSizeClass` 切换）
- 深度链接：`vex://t/{id}`, `vex://go/{node}`, `vex://member/{username}`
- `Router` 通过 `homeBarsVisible` 控制主页滚动时导航栏/Tab Bar/FAB 的联动隐藏
- 所有 NavigationStack 共享 `.commonNavigationDestinations()` 扩展，统一注册 `TopicBasic`/`MemberBasic`/`NodeBasic` 的目标视图

### 核心 Services
| 文件 | 职责 |
|------|------|
| `V2EXClient.swift` | HTTP 请求、Cookie 管理、50+ API 端点 |
| `HTMLParser.swift` | HTML→结构化数据、Cloudflare 邮箱解码（XOR）、`resolveURL` 处理协议相对 URL |
| `AuthManager.swift` | 用户会话、登录态、未读消息数、余额 |
| `Router.swift` | 路由状态、tab 间导航、滚动可见状态 |
| `CacheManager.swift` | 内存+UserDefaults 混合缓存，带 TTL |
| `CloudflareManager.swift` | Cloudflare 验证弹窗处理 |
| `AlertManager.swift` | Toast 提示（成功/错误/信息） |
| `FavoriteNodesManager.swift` | 收藏节点管理 |
| `ViewedTopicsManager.swift` | 浏览历史追踪 |
| `ImageUploader.swift` | Imgur 匿名 API 图片上传 |
| `ClipboardWatcher` (Utils) | 剪贴板 V2EX 链接检测 |
| `HapticManager` (Utils) | 触觉反馈 |

### HTML 内容渲染
`HTMLContentView` 使用原生 SwiftUI 渲染 HTML 内容（非 WKWebView），但含 `embedded_image` 的内容会回退到 `AutoSizingWebView`（WKWebView）。整个渲染管线集中在 `HTMLContentView.swift` 中：

1. `HTMLContentPreprocessor.normalize()` — 预处理：修复转义的 img 标签、孤立图片属性、Markdown 图片语法等畸形 HTML
2. `HTMLBlockParser.parse()` — 解析为 `HTMLBlock` 枚举（text/image/inline/codeBlock/blockquote）
3. `HTMLContentView` — 渲染各 block 类型；单文本块有快速路径优化

文本使用 `AttributedString` + `InlinePresentationIntent`，TextNode 需要折叠空白（HTML 规范）。`HTMLImageLayout` 和 `HTMLInlineImageLayout` 控制图片尺寸计算。

测试辅助：`HTMLContentParserTestSupport.blockKinds(for:)` 用于测试解析结果。

### 帖子详情页
- 回复输入框直接内联在底部（`TopicBottomBar`），不使用 sheet
- 回复行（`ReplyRow`）显示可见的操作按钮（回复/感谢/会话），不藏在 context menu
- 会话线程通过 `repliedTo` 和 `membersMentioned` 追踪

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

# FamilyRecipes (家庭食谱与点餐管家)

FamilyRecipes 是一款基于 SwiftUI 构建的家庭私房菜谱与点餐规划 iOS 应用。采用 **离线优先 (Offline-First) 与商业级多端协同架构**，本地数据通过 SwiftData 持久化，后台支持与自建 PostgREST / PostgreSQL 或 Supabase 服务进行增量数据同步、软删除墓碑清理、离线发件箱重发与冲突合并。

---

## 核心特性

- 👨‍👩‍👧‍👦 **家庭成员管理**：多身份成员切换与个性化配置。
- 🍲 **私房菜谱库**：支持菜品分类、标签管理、制作步骤与精美配图（集成 AI 菜品图生图）。
- 📝 **点餐与规划**：支持当日点餐、心愿单及就餐记录管理。
- 🎡 **大转盘抽奖**：智能随机摇菜谱，告别“今天吃什么”的纠结。
- 🔄 **高性能增量同步 (Delta Sync)**：基于时间戳游标进行增量拉取，节省 90%+ 网络传输流量，避免全表扫描。
- 🗑️ **可靠软删除机制 (Soft Delete & Tombstone)**：引入 `deleted_at` 字段同步删除标记，彻底解决不同设备间删除不同步的问题。
- 📦 **离线突变队列 (Sync Outbox)**：无网或弱网环境下新增、修改、删除操作自动落盘至本地发件箱，网络恢复后按时序 (FIFO) 自动重发。
- 🌐 **网络状态自适应 (Network Monitor)**：基于 Apple `NWPathMonitor` 实时感知网络连通性，断网静默省电，联网瞬间唤醒补发。
- ⚡️ **双协同协议自适应 (Realtime & Polling)**：自动识别后端形态，Supabase 走 WebSocket 毫秒级长连接，自建 PostgREST 走 15s 智能前台心跳轮询。

---

## 目录结构

```text
.
├── FamilyRecipes/            # 核心 iOS 源码 (App入口、Models、Views)
│   ├── Assets.xcassets/      # 图片与色彩资源
│   ├── FamilyRecipesApp.swift# 应用入口与 SwiftData ModelContainer
│   ├── Info.plist            # 应用配置与 ATS 设置
│   ├── Models/               # 数据模型、网络、同步引擎与离线发件箱
│   │   ├── Models.swift      # SwiftData @Model 实体定义
│   │   ├── DTOs.swift        # Codable 数据传输对象 (含 deletedAt)
│   │   ├── SyncEngine.swift  # 同步引擎核心 (增量合并、LWW 冲突解决、定时轮询)
│   │   ├── SupabaseManager.swift # PostgREST / Supabase RESTful 网络层
│   │   ├── SyncOutbox.swift  # 离线突变队列 (Outbox Pattern 持久化)
│   │   ├── NetworkMonitor.swift # 网络状态监听器 (NWPathMonitor)
│   │   ├── RealtimeManager.swift # WebSocket 实时协同管理器
│   │   ├── AppState.swift    # 全局状态管理 (成员选择、游标、网络状态)
│   │   ├── AIEngine.swift    # AI 菜品生图引擎
│   │   ├── ImageUtils.swift  # 图片压缩与 Base64 处理
│   │   └── SampleData.swift  # 初始预设菜谱与家庭成员数据
│   └── Views/                # SwiftUI 界面组件与功能模块
│       ├── ContentView.swift # 主视图路由与前后台生命周期
│       ├── Cook/             # 厨师主面板与点单管理
│       ├── Dishes/           # 菜品列表、分类与编辑
│       ├── Diary/            # 每日美食品尝记录
│       ├── Wheel/            # 转盘抽菜功能
│       └── Profile/          # 成员管理与云端同步设置
├── FamilyRecipesTests/       # 单元测试 (macOS Bundle，覆盖 32 个 CRUD 与同步用例)
├── FamilyRecipesUITests/     # UI 自动化测试 (iOS Simulator)
├── FamilyRecipes.xcodeproj/  # Xcode 工程文件 (由 XcodeGen 自动化维护)
├── docs/                     # 项目设计文档与测试报告
│   ├── PROJECT.md            # 架构演进与里程碑说明
│   └── bug_report.md         # 测试验收与 Bug 修复报告
├── project.yml               # XcodeGen 自动化工程规范配置
├── CLAUDE.md                 # 架构规范与开发调试指南
├── LICENSE                   # 开源许可
└── README.md                 # 项目说明文档
```

---

## 快速开始

### 1. 生成工程 (XcodeGen)
本项目推荐使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 维护 Xcode 工程文件：

```bash
xcodegen generate
```

### 2. 编译项目
在 iOS 模拟器上编译应用：

```bash
xcodebuild build -project FamilyRecipes.xcodeproj -scheme FamilyRecipes \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

### 3. 运行测试套件

- **单元测试 (macOS 目标，32 个用例全部通过，免模拟器毫秒级运行)**：
  ```bash
  xcodebuild test -project FamilyRecipes.xcodeproj -scheme FamilyRecipesTests \
    -destination "platform=macOS" CODE_SIGN_IDENTITY="-"
  ```

- **UI 自动化测试构建 (iOS 模拟器)**：
  ```bash
  xcodebuild build-for-testing -project FamilyRecipes.xcodeproj -scheme FamilyRecipes \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
  ```

---

## 技术架构

```text
[ SwiftUI Views ]
       │
       ▼
[ SwiftData (@Model) ]  <──(Last-Write-Wins / Delta)──>  [ SyncEngine ]
                                                               │
                     ┌───────────────────┬─────────────────────┼────────────────────┐
                     ▼                   ▼                     ▼                    ▼
             [ RealtimeManager ]  [ SyncOutbox ]       [ NetworkMonitor ]   [ SupabaseManager ]
             (WebSocket 广播)     (离线突变队列)        (NWPathMonitor)     (HTTP / PostgREST)
                     │                   │                                          │
                     └───────────────────┴──────────────────────────────────────────┘
                                                 │
                                                 ▼
                                     [ Remote PostgreSQL ]
```

- **语言 / 框架**: Swift 5.9+, SwiftUI, SwiftData
- **云端同步**: PostgREST HTTP RESTful API + Supabase Realtime WebSocket
- **本地存储与离线**: SwiftData + UserDefaults Outbox Queue
- **网络感知**: Apple Network Framework (`NWPathMonitor`)
- **工程管理**: XcodeGen

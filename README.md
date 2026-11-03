# 排班工坊 · Roster Studio

一个可以直接用 Xcode 打开、Archive 并提交 App Store 的 SwiftUI iOS 应用，内置
ShiftLattice 排班引擎：为小型团队（咖啡店、餐厅、门店、工作室）
在几秒钟内生成一份满足工时上限、休息间隔、连续上班天数与岗位要求的周排班表。

- 纯 Swift / SwiftUI，零第三方依赖
- 支持 iPhone 与 iPad，iOS 16.0+
- 内置示例数据，首次启动即可看到完整排班
- 一键导出 `.ics` 日历与 `.csv` 表格，通过系统分享面板发送
- 自带 1024×1024 图标、隐私清单（PrivacyInfo.xcprivacy）与 Codemagic 流水线

## 功能

| 页面 | 能力 |
| --- | --- |
| 排班 | 本周概览（人数、班次数、需求工时、已排工时、覆盖率）、一键重新排班、导出分享 |
| 明细 | 按星期分组展示每个班次的时间、岗位、在岗人员与空缺 |
| 团队 | 新增/编辑员工：岗位、每周上限、连续上班上限、班次间休息、每天可用时段 |
| 班次 | 新增/编辑班次模板：岗位、开始时间、时长、每天所需人数、优先级、生效星期 |

求解器在以下约束下寻找覆盖率优先、偏好次之、公平性再次的最优解：

- 岗位匹配与员工白名单
- 员工可用时段（班次必须完整落在某个可用窗口内）
- 每周工时上限、每日工时上限
- 两次班次之间最短休息时间
- 最多连续上班天数
- 同一天内不重叠

若无法覆盖全部班次，应用会说明还缺多少工时；若约束互相冲突，则给出无解原因。

## 运行

要求 macOS 13+ 与 Xcode 15+。

```bash
open RosterStudio.xcodeproj
```

1. 在 Xcode 中选择 `RosterStudio` target。
2. `Signing & Capabilities` 里选择你的开发团队；如需要，把 Bundle Identifier
   从 `com.shiftlattice.rosterstudio` 改成你自己的。
3. 选择任意 iPhone 模拟器，`⌘R` 运行。

## 提交 App Store

> Windows 用户：不用 Mac 也能提审，完整步骤见 [docs/STORE_RELEASE.md](docs/STORE_RELEASE.md)（GitHub + Codemagic + TestFlight + 网页提交）。

1. 在 [App Store Connect](https://appstoreconnect.apple.com) 新建 App，Bundle ID 与工程一致。
2. Xcode 菜单 `Product → Destination → Any iOS Device (arm64)`。
3. `Product → Archive`，归档完成后在 Organizer 中点 `Distribute App → App Store Connect → Upload`。
4. 等待 App Store Connect 处理完成，填写名称、副标题、描述、关键词、分类（商务）、
   年龄分级与截图，然后提交审核。

上架前检查：

- [ ] 图标已包含（`Assets.xcassets/AppIcon`，1024×1024，无透明通道）
- [ ] 启动屏使用系统生成（工程内已配置 `UILaunchScreen_Generation`）
- [ ] 隐私清单已包含（`PrivacyInfo.xcprivacy`，声明不追踪、不收集数据）
- [ ] App 隐私问卷选择「不收集数据」
- [ ] 截图：iPhone 6.7 英寸与 iPad 12.9 英寸各一组（可用模拟器 `⌘S` 截取）
- [ ] 支持邮箱与隐私政策链接（如不收集数据，可放一页静态说明）

## 使用 Codemagic 构建

仓库根目录已包含 `codemagic.yaml`：

1. 把工程推送到 GitHub。
2. 在 Codemagic 中添加该仓库，选择 `Roster Studio iOS` 工作流。
3. 在 Codemagic 的 Team settings 中配置 App Store Connect API Key，
   并在应用设置里添加名为 `app_store_credentials` 的集成（或按界面提示绑定）。
4. 推送 `main` 分支即可自动 `xcode-project build-ipa` 产出 `.ipa`。

签名使用 Codemagic 的自动签名（`ios_signing` + `xcode-project use-profiles`），
无需把证书提交进仓库。

## 目录结构

```
RosterStudio/
├── RosterStudio.xcodeproj/          # 单 target 工程 + 共享 scheme
├── RosterStudio/
│   ├── RosterStudioApp.swift        # @main
│   ├── AppModel.swift               # 草稿模型、示例数据、求解与导出
│   ├── ContentView.swift            # TabView 外壳
│   ├── HomeView.swift               # 概览 / 重新排班 / 分享导出
│   ├── RosterListView.swift         # 按星期分组的排班明细
│   ├── TeamView.swift               # 团队列表与员工编辑器
│   ├── TemplatesView.swift          # 班次模板列表与编辑器
│   ├── Engine/                      # vendored ShiftLattice 引擎（16 个文件）
│   ├── Assets.xcassets/             # AppIcon 与 AccentColor
│   └── PrivacyInfo.xcprivacy
├── codemagic.yaml
├── docs/STORE_RELEASE.md            # 无 Mac 提审全流程
├── PRIVACY.md                       # 隐私政策（可发布到 GitHub Pages）
└── README.md
```

引擎源码同时以独立 Swift Package 形式维护（ShiftLattice），
可作为 SPM 依赖用于其他 App；本工程将同一份源码直接编入 target，因此无需联网
解析依赖，离线也能构建。

## 自定义

- 想换示例数据：编辑 `AppModel.swift` 中的 `SampleData`。
- 想改主题色：修改 `Assets.xcassets/AccentColor.colorset`。
- 想换图标：替换 `AppIcon.appiconset/AppIcon-1024.png`。
- 想调整求解预算：修改 `AppModel.solve()` 里的 `maximumSteps`。

## 许可证

MIT，见 [LICENSE](LICENSE)。

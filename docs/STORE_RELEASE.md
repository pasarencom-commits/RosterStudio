# 用 GitHub + Codemagic 提交 App Store（无需 Mac）

本指南面向 Windows 用户：代码放在 GitHub，Codemagic 的 macOS 机器负责编译、签名、上传 TestFlight，最后在 App Store Connect 网页上提交审核。

## 0. 准备

- Apple Developer Program 会员（个人或公司，99 美元/年）已激活。
- App Store Connect 账号（同一个 Apple ID）。
- GitHub 账号，本机已安装 Git（或使用 GitHub Desktop）。
- Codemagic 账号：<https://codemagic.io>，用 GitHub 登录即可。

## 1. 把工程推到 GitHub

先在 GitHub 网页新建空仓库（不要勾选 README / .gitignore / license），例如 `roster-studio`。

```bat
cd C:\Users\zhang\Desktop\RosterStudio
git remote add origin https://github.com/<你的账号>/roster-studio.git
git branch -M main
git push -u origin main
```

之后每次改代码，`git add -A && git commit -m "..." && git push` 即可。

## 2. 在 Apple 后台创建 App ID 与 App 记录

1. 打开 <https://developer.apple.com/account> → Certificates, Identifiers & Profiles → Identifiers → `+`。
2. 选 **App IDs** → **App**，Description 填 `Roster Studio`，Bundle ID 选 **Explicit**，填 `com.shiftlattice.rosterstudio`，Capabilities 不用勾，保存。
3. 打开 <https://appstoreconnect.apple.com> → My Apps → `+` → **New App**：
   - Platform：iOS
   - Name：`Roster Studio`（若被占用就换一个，例如 `Roster Studio 排班`；这个名字就是商店里显示的名字）
   - Primary Language：简体中文
   - Bundle ID：选择上一步创建的 ID
   - SKU：例如 `rosterstudio001`
   - User Access：Full Access

## 3. 在 Codemagic 创建 App Store Connect API Key

1. App Store Connect → **Users and Access** → **Integrations**（旧版叫 App Store Connect API）→ **Team Keys** → `+` 生成密钥。
2. 权限选 **Admin**（自动签名与上传都需要；App Manager 上传可以，但签名可能失败）。
3. 记下 **Issuer ID** 和 **Key ID**，并下载 `.p8` 文件（只能下载一次）。

## 4. 在 Codemagic 绑定仓库与密钥

1. Codemagic → **Add application** → 选 GitHub → 选中 `roster-studio` → 选择 **Codemagic YAML**（仓库里已有 `codemagic.yaml`）→ Finish。
2. 左下角 **Team settings** → **Integrations** → **App Store Connect** → **Add key**：
   - Name 必须填 `app_store_credentials`（与 `codemagic.yaml` 里的 `api_key` 一致）
   - 上传 `.p8`，粘贴 Issuer ID、Key ID，保存。
3. 回到应用页面 → **Start new build** → Workflow 选 `Roster Studio iOS` → Branch 选 `main` → **Start new build**。

构建过程约 10–20 分钟：`xcode-project use-profiles` 会自动创建发布证书和 App Store 描述文件，`build-ipa` 产出 `.ipa`，最后自动上传到 TestFlight（`submit_to_testflight: true`）。

产物也可在构建页 **Artifacts** 里下载 `*.ipa`。

> 如果签名步骤报错，通常是 API Key 权限不是 Admin，或 Bundle ID 与 `codemagic.yaml` 里的 `bundle_identifier` 不一致。

## 5. 用 TestFlight 真机验收 + 截图

1. App Store Connect → 你的 App → **TestFlight**，等构建状态从 Processing 变为 Ready（5–30 分钟）。
2. 在 iPhone 上安装 **TestFlight** App，用同一个 Apple ID 登录，接受邀请（Internal Testing 里把自己加为测试员即可）。
3. 打开 App 走一遍：重新排班、改员工、导出分享，确认无崩溃。
4. 用 iPhone 截图（侧边键 + 音量上），至少准备：
   - 6.7 或 6.9 英寸 iPhone 截图 3–5 张（按 App Store Connect 页面提示的尺寸）
   - 若保留 iPad 支持，还需 13 英寸 iPad 截图 3–5 张
5. 没有 iPad 的话，可在 Xcode 工程里把 `TARGETED_DEVICE_FAMILY` 改成 `1`（仅 iPhone），重新推送构建，就只需要 iPhone 截图。

## 6. 填写 App Store 商品页

App Store Connect → 你的 App → 左侧逐项填写：

| 项目 | 填什么 |
| --- | --- |
| App 信息 | 名称、副标题（如「小型团队智能排班」）、分类选「商务」、内容版权选「不包含第三方内容」 |
| 定价与销售范围 | 免费，所有地区 |
| App 隐私 | 「不收集数据」（与 `PrivacyInfo.xcprivacy` 和 `PRIVACY.md` 一致） |
| 年龄分级 | 全部选「无」，得到 4+ |
| 版本信息 | 描述、关键词（如 `排班,值班表,排班表,团队,工时`）、支持 URL（可填 GitHub 仓库地址）、隐私政策 URL（把 `PRIVACY.md` 发布到 GitHub Pages 后填该地址） |
| 截图 | 第 5 步的截图 |
| 构建版本 | 选 TestFlight 里刚上传的构建 |

**隐私政策 URL 的最简做法**：GitHub 仓库 → Settings → Pages → Source 选 `main` 分支根目录 → 保存，几分钟后 `https://<账号>.github.io/roster-studio/PRIVACY.md` 可访问（或把 `PRIVACY.md` 重命名为 `privacy.md` 再发布）。

## 7. 提交审核

1. 确认所有必填项变绿，右上角 **Add for Review** → **Submit to App Review**。
2. 审核问题里：出口合规选「否/不使用加密」（工程已设置 `ITSAppUsesNonExemptEncryption = NO`）；无登录，不需要演示账号。
3. 通常 24–48 小时出结果；被拒会收到具体条款，改完重新提交即可。

## 常见被拒原因（提前规避）

- **2.1 崩溃**：务必用 TestFlight 真机跑一遍全部页面。
- **4.3 重复应用**：本 App 是原创排班工具，不要照搬模板 UI 或示例数据提交多个相似 App。
- **5.1.1 隐私**：App 隐私问卷、`PrivacyInfo.xcprivacy`、隐私政策三者必须一致（本项目均为「不收集」）。
- **2.3 截图与描述不符**：截图必须是 App 真实界面。
- **缺少隐私政策 URL**：必须可公开访问，不能是空页。

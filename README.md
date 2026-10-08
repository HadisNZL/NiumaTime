# 牛马日历

一款原生 macOS 菜单栏日历，也是一只有情绪的上下班倒计时牛。支持 Apple Silicon 与 Intel Mac。

## 主要功能

- 菜单栏日历：查看月历、公历、农历、节日、节气及周数
- 专属图标：日历与牛脸融合的原生 macOS 应用图标
- 中国工作日：内置 2024–2026 年法定节假日与调休，支持当天临时休息或上班
- 牛马倒计时：按开始和结束时间自动切换待命、工作、临近与完成状态，支持跨夜时段
- 悬浮牛：自由移动、锁定位置、隐藏牛耳朵，并可调整尺寸、透明度、文案与颜色
- 精确显示：菜单栏可显示剩余时间及秒数，最后一分钟在牛脸核心区进行动态倒计时
- 独立开关：不需要倒计时时，可完整关闭菜单栏倒计时和悬浮牛，仅保留日历
- 手动更新：按需检查 GitHub Releases，下载后校验 SHA-256，不后台联网或自动替换应用
- 轻量原生：SwiftUI + AppKit，无第三方依赖、日历权限、Widget 扩展或额外进程

快捷键：

- `⌥⇧J`：打开或收起日历
- `⌥⇧L`：显示或隐藏悬浮牛

系统要求：macOS 14 或更高版本。

## 构建

```bash
./scripts/build-app.sh
open dist/牛马日历.app
```

构建结果：

- `dist/牛马日历.app`
- `dist/NiumaCalendar-macOS-Universal.zip`

两份产物均同时支持 `arm64` 与 `x86_64`。默认使用临时签名，其他 Mac 首次运行时可能需要在 Finder 中右键应用并选择“打开”。

开发运行与测试：

```bash
swift run FloatProgress
swift test --disable-sandbox
```

## 更新中国工作日数据

App 只读取编译进程序的工作日数据，运行时不会联网。国务院公布下一年度安排，且 [NateScarlet/holiday-cn](https://github.com/NateScarlet/holiday-cn) 已收录后，运行：

```bash
./scripts/update-china-workdays.swift 2024...2027
swift test --disable-sandbox
./scripts/build-app.sh
```

参数必须包含需要保留的全部连续年份。离线数据也可以通过 `--input-directory` 指定：

```bash
./scripts/update-china-workdays.swift 2024...2027 --input-directory /path/to/holiday-cn
```

## 发布新版本

应用只读取 GitHub 上最新的正式 Release。推送 `v3.0.6` 这样的版本标签后，GitHub Actions 会自动测试、构建、校验并创建 Release，不需要在 GitHub 网页手工上传安装包。

下面以从 `3.0.5` 发布到 `3.0.6` 为例。

### 1. 确定版本号

版本号格式为 `主版本.次版本.修订号`：

- 小修复：`3.0.5` → `3.0.6`
- 新增一批功能：`3.0.6` → `3.1.0`
- 有较大且不兼容的变化：`3.1.0` → `4.0.0`

每个版本号只能使用一次。已经发布过的标签不要删除、移动或重复使用。

### 2. 进入项目并同步代码

打开“终端”，执行：

```bash
cd /Users/niuzilin/workProgress
git pull --ff-only origin main
git status --short
```

`git pull --ff-only origin main` 会把 GitHub 上 `main` 分支的最新提交同步到本机，不会覆盖本机尚未提交的修改。

`git status --short` 没有任何输出时，说明工作区干净；如果有输出，应确认这些文件都是本次准备发布的修改。

### 3. 测试并检查本地 App

先运行完整测试：

```bash
swift test --disable-sandbox
```

看到所有测试通过后，可以额外构建本地安装包：

```bash
./scripts/build-app.sh release
open dist/牛马日历.app
```

这一步只用于本机检查界面和功能。正式版本号与构建号会由 GitHub Actions 根据标签自动写入，不需要手工修改源码。

### 4. 提交并推送全部修改

先查看修改，再加入本次提交：

```bash
git status --short
git add -A
git status --short
```

确认文件列表正确后，使用中文说明提交内容并推送：

```bash
git commit -m "修正某某问题并优化某某功能"
git push origin main
```

如果终端提示 `nothing to commit`，表示没有新的代码修改，可以跳过提交和 `main` 推送，直接创建版本标签。

推送后可以确认本机与远程是否一致：

```bash
git status --short
git rev-list --left-right --count origin/main...main
```

第一条命令应没有输出；第二条命令应显示 `0 0`。

### 5. 创建并推送版本标签

先确认新标签没有被使用：

```bash
git tag --list v3.0.6
```

没有输出时，创建带说明的标签并推送：

```bash
git tag -a v3.0.6 -m "牛马日历 3.0.6"
git push origin v3.0.6
```

最后一条命令会启动自动发布。GitHub Actions 将依次完成：

1. 使用固定的 macOS 26 与 Xcode 26.6 环境。
2. 运行全部测试。
3. 构建同时支持 Apple 芯片与 Intel 的 Universal App。
4. 生成 `NiumaCalendar-macOS-Universal.zip`。
5. 生成并上传对应的 SHA-256 校验文件。
6. 创建正式的 GitHub Release。

### 6. 确认发布成功

打开 [GitHub Actions](https://github.com/HadisNZL/NiumaTime/actions)，等待“发布 macOS 安装包”显示绿色成功。通常需要几分钟。

然后打开 [GitHub Releases](https://github.com/HadisNZL/NiumaTime/releases)，确认最新版本包含：

- `NiumaCalendar-macOS-Universal.zip`
- `NiumaCalendar-macOS-Universal.zip.sha256`

只有 Actions 成功且正式 Release 已出现，其他用户的“检查更新”才会发现新版本。草稿版和预发布版不会被应用当作最新正式版。

### 7. 用户如何更新

旧版用户打开“设置 → 关于与更新”，点击“检查更新”后即可发现版本号更高的新版本。下载过程会自动校验 SHA-256。

发现新版本后，可在应用内下载并自动校验安装包。下载完成时选择“在 Finder 中显示”，退出正在运行的旧版本，解压后将“牛马日历”拖入“应用程序”并选择替换。

当前没有 Developer ID，因此发布包仍为临时签名。其他 Mac 首次打开时，可能需要在 Finder 中右键应用并选择“打开”。

### 常见问题

- **标签已经存在**：不要复用旧标签，改用更高的版本号，例如 `v3.0.7`。
- **代码已经提交，但推送失败**：网络恢复后重新执行 `git push origin main`。
- **标签推送失败**：网络恢复后重新执行对应的 `git push origin v3.0.6`。
- **Actions 构建失败**：不要手工创建缺少校验文件的 Release。修复问题、提交代码，再使用下一个版本号重新发布。
- **检查更新显示已是最新版本**：确认当前 App 的版本号低于新 Release，并确认 Actions 已成功、Release 不是草稿或预发布。
- **只想用相同代码测试更新**：可以跳过代码提交，直接在当前干净的 `main` 上创建一个更高的新标签。

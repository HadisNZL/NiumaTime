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
- `dist/牛马日历-macOS-Universal.zip`

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

提交并推送全部改动后，创建新的版本标签：

```bash
git tag v3.0.1
git push origin v3.0.1
```

GitHub Actions 会自动测试、构建 Universal App、生成 SHA-256 校验文件并创建 GitHub Release。应用内“检查更新”将读取最新正式 Release。

版本标签使用 `v主版本.次版本.修订号` 格式，例如 `v3.1.0`。当前没有 Developer ID，因此发布包仍为临时签名；以后加入签名与公证凭据即可升级正式分发流程。

# 双板协同应急信息终端

基于两块安路 HX4S20C（EG4S20BG256）的离线信息发布与应急疏散演示系统。

A 板负责 TF 卡媒体读取、四槽图像缓存、图像处理、字幕与图层合成，以及 HDMI 音视频输出；B 板负责现场操作、事件确认与权限控制、危险区域与封锁管理、路线求解，以及实际 PCM 的频谱分析。

本仓库保存 **2026 年 11 月 1 日正式提交版本**的完整材料。原始 695 个文件保持原目录和文件内容；仓库根目录另增项目导览与 Git 配置文件。

## 从哪里开始

- [工程说明与构建命令](02_完整源码/Emergency_Info_Terminal/README.md)
- [操作与接线指南](02_完整源码/Emergency_Info_Terminal/docs/OPERATING_GUIDE.md)
- [系统架构](02_完整源码/Emergency_Info_Terminal/docs/ARCHITECTURE.md)
- [第三方 IP 与素材来源](02_完整源码/Emergency_Info_Terminal/docs/THIRD_PARTY.md)
- [正式技术报告 PDF](01_技术文档/双板协同应急信息终端_技术文档.pdf)
- [完整提交说明](00_提交说明.md)

## 材料目录

| 目录 | 内容 |
| --- | --- |
| `01_技术文档` | 21 页技术报告的 Word 与 PDF |
| `02_完整源码/Emergency_Info_Terminal` | RTL、IP、TD 工程、约束、初始化数据、TF 媒体、配套位流、仿真及验证记录 |
| `03_作品照片` | 作品全貌及开发板接口照片 |
| `04_作品海报_选交` | 海报 PDF 与 PNG 预览 |
| `05_核验记录` | 检查结果、图片来源、修订记录及文件 SHA-256 清单 |

## 打开工程

先将源码目录复制到短的 ASCII 路径，例如 `D:/FPGA/Emergency_Info_Terminal`。工具链为 TD 6.2.1（6.2.168.116）；推荐使用 ModelSim 10.4 进行仿真。

- A 板工程：`02_完整源码/Emergency_Info_Terminal/td/Emergency_Info_Terminal.al`
- B 板工程：`02_完整源码/Emergency_Info_Terminal/console/td/Duty_Console_B.al`
- TF 卡媒体：`02_完整源码/Emergency_Info_Terminal/media/TF_A`
- 配套位流：`02_完整源码/Emergency_Info_Terminal/firmware`

构建、烧录、接线及上电操作以源码 README 和操作指南为准。两板分别供电、信号共地，不互连电源引脚。

## 验证记录与边界

本版本附有 47 项既有回归通过记录、参考实现的资源/时序报告，以及配套固件验证记录。仓库整理没有重新综合、烧录或重跑全量回归。

- 最终物理实现 LUT 占用：A 板 18,566 / 19,600（94.72%），B 板 10,042 / 19,600（51.23%）。
- Setup WNS：A 板 +0.141 ns，B 板 +4.913 ns；Hold WNS 均为 +0.020 ns，归属参考位流。
- 频谱来自数字 PCM；路线使用预设地图和人工危险区域输入。
- 当前没有有效的工具功耗估算值或仪器实测功耗数值。

视频与需要本人签字的材料由参赛者另行准备，不包含在本仓库中。第三方 IP 和媒体保留原有来源说明与条款，本仓库没有为其额外授予许可。

## 完整性核验

在源码目录运行：

```powershell
python tools/verify_package.py
```

正式材料全量清单位于 `05_核验记录/全部文件_SHA256.json`。Git 配置关闭换行转换，以保持校验清单对应的原始字节。

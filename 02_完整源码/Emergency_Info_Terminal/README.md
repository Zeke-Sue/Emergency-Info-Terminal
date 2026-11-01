# 双板协同应急信息终端

基于两块安路 HX4S20C（EG4S20BG256）的离线信息发布与应急疏散演示系统。
A板完成TF媒体读取、帧缓存、图像处理、字幕和HDMI音视频输出；B板完成事件操作、权限确认、路线求解和PCM音频分析。

## 目录

| 目录 | 内容 |
|---|---|
| board、rtl | A板顶层及媒体处理模块 |
| console | B板顶层、控制、路线及分析模块 |
| constraints | A板引脚与时序约束 |
| vendor | HDMI、SD、SDRAM配套IP及接口 |
| td、console/td | 可直接打开的TD工程 |
| sim | 自校验测试平台、参考模型与测试向量 |
| tools | 工程生成、综合实现及仿真脚本 |
| media/TF_A | A板TF卡根目录文件，共16张BMP与16个WAV |
| firmware | 与当前板卡固化记录对应的配套位流 |
| verification | 资源、时序、仿真及文件一致性证据 |
| docs | 系统结构、接口、操作和第三方来源说明 |

## 硬件连接

两板断电接线，均为3.3V逻辑；分别供电，不互连电源引脚。

| 信号 | A板 | B板 |
|---|---|---|
| A到B控制 | J1-1 / D14 | J2-2 / N4 |
| B到A控制 | J1-2 / G11 | J2-1 / P4 |
| A到B PCM和状态 | J1-3 / G12 | J2-3 / N3 |
| 公共地 | J1-12 | J2-12 |

A板连接TF卡和HDMI显示器；B板不需TF卡。将media/TF_A内文件复制到FAT32卡根目录，保持文件名。上电初始拨码A=0000、B=0100，字符串按SW1至SW4顺序，1表示输入高电平。

## 构建

工具链：TD 6.2.1（6.2.168.116）、Python 3、PowerShell。先将工程置于短的ASCII路径，例如D:/FPGA/Emergency_Info_Terminal。
GUI入口：td/Emergency_Info_Terminal.al及console/td/Duty_Console_B.al。
使用批处理可准确保留种子与存储器初始化设置：

```powershell
./tools/run_td.ps1 -TdHome 'D:/Anlogic/TD_6.2.1_Engineer_6.2.168.116' -Python python -BuildRoot 'D:/FPGA/build_A' -BitGen -PlaceSeed 8
./tools/run_td_console.ps1 -TdHome 'D:/Anlogic/TD_6.2.1_Engineer_6.2.168.116' -Python python -BuildRoot 'D:/FPGA/build_B' -BitGen
```

完成标志与退出码之外，必须检查最终route_flow.status的Setup/Hold及NUM_FEPS。不得删除或放宽约束以替代时序收敛。外部SD/DDC电气时序未提供独立实测定标，内部时序通过不代表所有板级接口完成签核。

## 仿真

推荐ModelSim 10.4。47项应用回归包含缓存、轮播、缩放、字幕、音频、路线和事件控制：

```powershell
./tools/run_modelsim.ps1 -Test usability -ModelSimBin 'C:/modeltech64_10.4/win64' -BuildRoot 'D:/FPGA/sim_runs'
```

__ICARUS__宏选用同步行为存储模型；这属于RTL功能仿真，不是厂商IP的门级时序仿真。sim中的reference模型用于对照，不加入硬件综合。

## 运行与验证边界

输出为640×480；媒体含640×480、800×600、1280×960三种输入尺寸。频谱使用实际送往HDMI封装器的数字PCM，不能检测扬声器声学输出。路线采用21节点、32边预设图与手动区域输入，非自动火灾探测或人员定位系统。

firmware下位流已完成Flash写入、回读与DONE检查。verification/reference保存对应实现数据。交付RTL与参考实现的有效词法单元一致，配套回归结果见verification/submission。重新综合可能因工具与随机性得到不同资源及时序，需独立复核。

## 仿真波形

verification/waveforms保存精选测试的完整WLF波形、45项波形记录日志（全部47项原回归日志见verification/submission）和重点信号布局；查看方法与记录范围见该目录README.md。为回归命令添加-RecordWaves即可重新生成全部测试波形，完整集会超过提交容量上限。

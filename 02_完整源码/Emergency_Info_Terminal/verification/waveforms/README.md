# 仿真波形查看与复现

这些波形选自提交源码对应的RTL自校验测试，采用ModelSim 10.4、1 ps仿真精度及行为级RAM/ROM。不是板端采样，也不是布局布线后时序仿真。记录从初始化开始到测试结束的层级信号（log -r /*，+acc）；未额外展开记录全部存储器单元。

## 打开波形

在ModelSim命令行执行（将文件路径替换为实际文件）：

    vsim -view tb_slideshow_lookahead.wlf

打开后在Structure/Objects窗口选择信号，加入Wave窗口，Zoom Full查看全过程。WLF是ModelSim原生波形数据库；无需将它加入FPGA综合工程。

## 建议先检查的测试

| 测试 | 检查重点 |
| --- | --- |
| tb_slideshow_lookahead | IMAGE09大图加载、三页前向预取、转场槽保护、2/5/10秒显示停留 |
| tb_filming_cadence | 轮播时序和完整显示后的计时 |
| tb_live_route | 256种区域封锁组合与独立最短路径参考比较 |
| tb_route_media_pipeline | 路线信息与显示通路协同（仅原回归日志，波形可按需复现） |
| tb_stft_512_fft | 512点频谱计算 |

轮播测试中图号为0基索引，索引8对应IMAGE09；player的CLK_HZ被缩小以加速验证。波形横轴是仿真时间，不能直接解释成真实板卡上的2/5/10秒；请结合seconds、cycle和displayed_at判断逻辑计时。测试输入与预期结果见sim目录同名测试文件。

## 从提交源码重新生成

安装ModelSim后，在源码根目录执行：

    powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_modelsim.ps1 -Test usability -RecordWaves -BuildRoot D:/TD/wave_reproduction

可通过-ModelSimBin指定仿真器目录。输出位于新建快照的evidence/waveforms，日志与源文件SHA-256在evidence中。建议使用较短的ASCII输出路径。

只生成某一测试：

    powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_modelsim.ps1 -Test tb_slideshow_lookahead -RecordWaves -BuildRoot D:/TD/wave_reproduction

inventory.json列出45项已完整录制测试的状态、波形体积及交付选择。logs目录保留这45项开启信号记录后的通过日志；全部47项原回归通过日志保留在verification/submission/logs。

打开轮播预取或计时波形后，可分别执行do view_slideshow.do、do view_cadence.do加载重点信号布局（先切换到本目录）。

路线波形可执行do view_route.do。request表示路线数据包有效；edges、dirs、path_cost是测试参考模型中的检查变量，不能当作持续有效的硬件输出，应以request有效时的payload为准。

## 交付范围

已录完45项波形，共2,318,082,048字节（2318.08 MB），因此47项全量波形至少为该体积，超过200 MB上传上限。停止tb_extension_manual_real的额外波形录制，未另录tb_route_media_pipeline；不把这两项声称为本次波形回归通过。两项原回归均已通过，日志位于verification/submission/logs。

交付保留单份不超过10 MB的34项完整波形，共25.11 MB；其他测试保留日志及复现入口。没有截短已收入的波形。recorded_source_sha256.json对应实际录制的冻结源，433项输入与当前交付一致，唯一差异是运行脚本新增可选波形开关，RTL未变。

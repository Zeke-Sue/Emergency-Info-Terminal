# 验证数据

reference：配套位流的资源与内部时序报告、固化摘要、参考回归结果。
submission：本源码目录执行的47项ModelSim回归，完成时间2026-10-31。
source_correspondence.json：参考实现输入与提交文件的SHA-256对应关系。RTL注释及空白不参与有效词法单元比较；厂商IP与初始化数据保持原字节。
package_sha256.json：整个代码目录的文件清单，不包含清单自身。

在工程根目录运行python tools/verify_package.py可检查交付文件完整性。
当前参考位流没有重新综合；其资源及时序数据只归属于所列SHA-256。新一轮综合、布局布线或烧录均应生成新的证据记录。

waveforms：RTL回归波形、记录范围、查看与复现说明。

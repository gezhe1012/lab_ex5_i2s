# 当前工程地图

此文件记录创建技能时的工程结构。每次执行任务都应重新检查实际源码，不能把本页状态当作永久事实。

## 工程入口

- 项目根目录：技能目录的上一级。
- Tang Dynasty 工程：`src/td_project/HDMI1.4b_Transmitter_v1.0.al`
- 顶层：`src/user_source/hdl_source/top_tf_hdmi_audio.v`，模块名 `top`
- 管脚：`src/user_source/constraints_source/pin.adc`
- 时序：`src/user_source/constraints_source/timing.sdc`
- 综合运行目录：`src/td_project/HDMI1.4b_Transmitter_v1.0_Runs/syn_1`
- 实现运行目录：`src/td_project/HDMI1.4b_Transmitter_v1.0_Runs/phy_1`

## 主要数据通路

```text
TF卡/SPI
  -> sd_card_bmp / bmp_read
  -> 异步写FIFO
  -> SDRAM双缓冲
  -> 异步读FIFO
  -> video_timing_data / video_delay
  -> 图像处理、转场、OSD
  -> video_rgb_to_axis_640x480
  -> HDMI 1.4b transmitter core
  -> HDMI PHY
```

```text
12.288 MHz音频时钟
  -> hdmi_audio_tone_i2s_64fs
  -> I2S_receiver
  -> 24-bit左右声道PCM
  -> audio_arc_calculate
  -> HDMI 1.4b transmitter core
```

## 时钟域

| 时钟 | 标称频率 | 主要用途 |
|---|---:|---|
| `clk` | 50 MHz | 板载输入、数码管 |
| `sd_card_clk` | 100 MHz | TF卡扫描、BMP解析、写FIFO |
| `ext_mem_clk` | 125 MHz | SDRAM控制器 |
| `video_clk` | 25 MHz | 640×480像素、HDMI视频输入 |
| `hdmi_5x_clk` | 125 MHz | TMDS串行化 |
| `audio_mclk` | 12.288 MHz | 48 kHz I2S测试音 |

## 关键源码

- `SD/sd_card_bmp.v`：扫描最多四张 BMP、KEY1/KEY2、防抖、双缓冲提交。
- `SD/bmp_read.v`：扇区扫描、BMP头识别、像素输出。
- `SD/frame_read_write.v`：读写FIFO和SDRAM访问仲裁。
- `SD/frame_fifo_write.v`：BMP上下方向修正和写地址生成。
- `SD/video_timing_data.v`、`SD/video_delay.v`：视频时序和读FIFO延迟对齐。
- `video_rgb_to_axis_640x480.v`：RGB/DE/VS到HDMI AXI-Stream。
- `hdmi_audio_tone_i2s_64fs.v`、`I2S_receiver.v`、`audio_arc_calculate.v`：音频链路。
- `video_fade_transition.v`：双缓冲淡出/淡入握手。
- `video_osd_overlay.v`：Alpha OSD、动态时间、滚动字幕。

## 创建技能时的已知状态

- 基础要求1、2、3已有实现。
- 扩展要求1、2已有实现并通过 TD 综合、布局布线和 bitstream 生成。
- 扩展要求3、4、5仍需按实际代码重新确认，不能直接假定缺失或完成。
- 已知旧工程与当前工程的最终报告都存在 SDRAM相移相关跨时钟负裕量；视频25 MHz域在最近一次构建中满足时序。处理时序时必须查看具体路径，不能简单忽略全局 WNS。

## 不可随意改变的接口

- `key1`：手动下一张。
- `key2`：自动轮播开关。
- TF SPI：`sd_ncs`、`sd_dclk`、`sd_mosi`、`sd_miso`。
- HDMI：`HDMI_CLK_P`、`HDMI_D[2:0]_P`、`HDMI_DDC_SCL`、`HDMI_DDC_SDA`。
- 新增板载按键、拨码或外设端口前，先核对 HX4S20C 原理图和 ADC 管脚约束。

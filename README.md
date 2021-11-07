# openStreamHDL

Here you will find some valuable VHDL code blocks for infrastructure. They are designed to be synthesized for FPGA. A short breakdown of files here:
| Filename                  | Description                                                            |
|---------------------------|------------------------------------------------------------------------|
| LFSR.vhd                  | Psudorandom Number Generation                                          |
| bezier.vhd                | Solves a Bezier Curve                                                  |
| bezier_mm.vhd             |                                                                        |
| bezier_tb.vhd             | Bezier testbench                                                       |
| chaser.vhd                | A single pole LPF or Ramp Generator (For Synth Envelopes)              |
| chaser_lpf.vhd            |                                                                        |
| chaser_mm.vhd             |                                                                        |
| deserializer.vhd          | A streaming deserializer                                               |
| fifo_stream.vhd           | A streaming FIFO                                                       |
| flow.vhd                  | Supplies run signals for a self-contained streaming block (IMPORTANT!) |
| flow_tb.vhd               | testbench                                                              |
| i2s_master.vhd            | A streaming I2S Master (Full duplex)                                   |
| i2s_master_clocked.vhd    |                                                                        |
| i2s_master_tb.vhd         |                                                                        |
| inverter.vhd              | A simple inverter                                                      |
| linear_interp.vhd         | A streaming linear interpolator                                        |
| mm_volume.vhd             |                                                                        |
| mm_volume_stream.vhd      | A Memory-Mapped streaming gain control                                 |
| note_svf.vhd              | A State Variable Filter for Synth                                      |
| note_svf_tb.vhd           | testbench                                                              |
| rationalize.vhd           | Arbitrarily rationalizes a fixed input                                 |
| rationalize_tb.vhd        |                                                                        |
| serializer.vhd            | A streaming serializer                                                 |
| simple_dual_one_clock.vhd | Inferred Ram (!)                                                       |
| sine_lookup.vhd           | A streaming sine lookup                                                |
| sine_lookup_tb.vhd        | testbench                                                              |
| spi_master.vhd            | A streaming SPI Master                                                 |
| spi_slave.vhd             |                                                                        |
| spi_slave_dualclock.vhd   | A dual-clock SPI Slave                                                 |
| stream_split.vhd          | Splits a stream                                                        |
| sum8.vhd                  | Sums 8 input channels                                                  |
| sumtime.vhd               | Sums across time (streaming)                                           |  
  
# Streaming Paradigm:  
(from https://inst.eecs.berkeley.edu/~cs150/Documents/Interfaces.pdf)  
  
![image](https://user-images.githubusercontent.com/8158655/140623267-7ed477c5-1778-45e8-ba8b-48a25d099fc0.png)
  
  
![image](https://user-images.githubusercontent.com/8158655/140623273-62945632-e23e-47b3-8f47-b73cd321168d.png)


# FLOW.VHD  
This is the most fundamental block in this repository. It implements the above paradigm, creating a step-by-step pipeline of arbitrary length

//Copyright (C)2014-2024 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.9 (64-bit) 
//Created Time: 2024-01-09 12:52:57
create_clock -name clk50m -period 20 -waveform {0 10} [get_ports {clk_50M}]
create_generated_clock -name clk133m -source [get_ports {clk_50M}] -master_clock clk50m -divide_by 3 -multiply_by 8 -duty_cycle 50 [get_nets {sdram_clk_p clk_133M aux_clk}]
set_false_path -from [get_regs {print_buffer_pointer_0_s2 print_buffer_pointer_1_s1 print_buffer_pointer_2_s1 print_buffer_pointer_3_s1 print_buffer_pointer_4_s1 print_buffer_pointer_5_s1 print_buffer_pointer_6_s1 print_state_0_s1 print_state_1_s0}] -to [get_regs {seq_tail_0_s0 seq_tail_1_s0 seq_tail_2_s0 seq_tail_3_s0 seq_tail_4_s0 seq_tail_5_s0 seq_tail_6_s0 seq_tail_7_s0 print_state_0_s1 print_state_1_s0}]  -setup
set_false_path -from [get_regs {print_buffer_pointer_5_s1 print_buffer_pointer_6_s1 print_buffer_pointer_0_s2 print_buffer_pointer_1_s1 print_buffer_pointer_2_s1 print_buffer_pointer_3_s1 print_buffer_pointer_4_s1}] -to [get_pins {print_state_0_s1/RESET print_seq_print_seq_0_0_s/CEA print_seq_print_seq_0_0_s/DI[6] print_seq_print_seq_0_0_s/DI[0] print_seq_print_seq_0_0_s/DI[1] print_seq_print_seq_0_0_s/DI[2] print_seq_print_seq_0_0_s/DI[3] print_seq_print_seq_0_0_s/DI[4]}] 

# LicheeTang25k_SDRAM

## Overview
The LicheeTang25k_SDRAM is a specialized SDRAM controller designed for the LicheeTang25k series. Total size is 64MB or 512Mb. Parameters are fixed, but modifying them should not be difficult.

This branch is for 133MHz. Another branch for 100MHz is available.

UART baudrate is 115200. Press S1 to trigger it.

PLL & IODelay are used to meet the timing requirements. If the frequency is changed, the PLL & IODelay settings should be modified accordingly.


## Functional Interface

### Clock and Reset
- **clk:** This is the clock input. The frequency is same to the interfaces and the SDRAM.
- **rst_n:** The reset input, active low.

### Command Inputs
- **cmd_en:** Enables the command input.
- **cmd_wr_rd:** Determines the operation type; '0' for write, '1' for read.
- **cmd_av:** Indicates whether the command input is valid.
- **cmd_len [9:0]:** Specifies the data length for a command in units of 2 Bytes (e.g., a value of 2 corresponds to 4 Bytes).
- **cmd_adr [24:0]:** Defines the starting address in 2 Byte units. The address structure includes: 1 bit for CS, 13 bits for row, 2 bits for bank, and 9 bits for column.

### Write Buffer Management
- **wr_remain_space [9:0]:** Shows the available space in the buffer for writing data (in 2 Byte units). 1023 is displayed when remaining space is greater than 1023.
- **wr_en:** Enables writing data into the buffer.
- **wr_data [15:0]:** The data to be written into the buffer.
- **wr_mask [1:0]:** The byte mask for data being written; '0' for write, '1' for masked.
> It's advised to preload the buffer with all intended data before issuing the write command. The writing procedure to the SDRAM might start instantly upon command issuance. Alternatively, ensure that the buffer is filled at a rate same or faster than the SDRAM's writing speed, maintaining at least one data in the buffer when the write command is executed.

### Read Buffer Management
- **rd_remain_space [9:0]:** Indicates the available space for reading data from the SDRAM to the buffer (in 2 Byte units).
- **rd_data [15:0]:** The data read from the buffer.
- **rd_av:** Validity of the data read from the buffer.
- **rd_en:** Enables reading the next data from the buffer.

### Other Interface
- **cs, ras, cas, we, adr [12:0], ba [1:0], dqm [1:0], dq [15:0]:** SDRAM interface.
- **init_fin:** Indicates the initialization status of the SDRAM; '0' for not initialized, '1' for initialized and ready.

## Performance
- **Operating Frequency:** The controller currently runs at 133MHz.
- **Random Read/Write Speed:** Approximately 65MB/s.
- **Continuous Read/Write Speed:** Approximately 260MB/s.
- **Average Random Access Latency:** Around 100ns.

## UART Output
```text
Write aaaa ffff 0000 to ram0. 
Write 5555 0000 ffff to ram1.
Read from ram0:
aaaaffff0000
Read from ram1:
55550000ffff
```
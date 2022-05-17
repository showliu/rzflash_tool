# rzflash_tool(WIP)
Renesas MPU flash tool for RZ
* This tool require Renesas Flash Writer

### How to get the help
ex.
> $ rzflash-tool.py -h

### single "command" mode: send single command to the board, use the mode to send other data as well. 
ex.
> $ rzflash-tool.py -s /dev/ttyUSB0 -b 115200 -m command -c h

### send "file" mode: send file to the board.
ex. 
> $ rzflash-tool.py -s /dev/ttyUSB0 -b 115200 -m file -w Flash_Writer_YOU_BUILT.mot
or <br>
> $ rzflash-tool.py -s /dev/ttyUSB0 -b 115200 -m file -f bl2_YOU_BUILT.srec

### "qspi" mode: write the firmware file to the qspi flash
ex. write bl2 to QSPI flash save address H'00000.
> $ rzflash-tool.py -s /dev/ttyUSB0 -b 115200 -m qspi -w Flash_Writer_YOU_BUILT.mot -R 11E00 -F 00000 -f bl2_YOU_BUILT.srec

### "emmc" mode: write the firmware file to the emmc
ex. write fip to emmc address 100th sector.
> $ rzflash-tool.py -s /dev/ttyUSB0 -b 115200 -m emmc -w Flash_Writer_YOU_BUILT.mot -p 1 -R 100 -F 1D200 -f bl2_YOU_BUILT.srec

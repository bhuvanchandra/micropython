MicroPython port to NXP VF6XX
=============================

This is an experimental port of MicroPython for NXP VF6XX M4 Core.

Supported features include:
- REPL (Python prompt) over UART2.
- Garbage collector.
- GPIO, UART support.

Build instructions
------------------

The tool chain required for the build is the Linaro provided ARM Embedded toolchain, e.g. 4.9 2015 Q3 update. Unpack the toolchain to an appropriate location.

e.g. your home directory:

```bash
$ tar xjf ${HOME}/gcc-arm-none-eabi-4_9-2015q3-20150921-linux.tar.bz2
...
$ export PATH=$PATH:$HOME/gcc-arm-none-eabi-4_9-2015q3/bin/
$ arm-none-eabi-gcc --version
arm-none-eabi-gcc (GNU Tools for ARM Embedded Processors) 4.9.3 20150529 (release) [ARM/embedded-4_9-branch revision 227977]
Copyright (C) 2014 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
```

Then, to build MicroPython for the VF6XX_M4, just run:
```bash
$ cd ${HOME}/micropython/vf6xx
$ make
$ ...
```
This will produce binary images in the `build/` subdirectory.

First start
-----------

## Running a Firmware on Cortex-M4 ##

There are two possible ways to boot the Cortex-M4 core on Vybrid:

1. From U-Boot using `m4boot`/`bootaux`
2. From Linux using remoteproc

**Note:**
In release image 2.7 Beta1, support for m4boot has been dropped from u-boot and remoteproc is the only method to boot and run firmware on Cortex-M4.
In release image 2.7 Beta2, support for bootaux has been added including elf boot support.

**Note:**
The FreeRTOS firmware uses Colibri UART_B as its debugging console. Make sure to connect UART_B to your debugging host and start a serial terminal emulator with a baud rate of 115200 on the serial port.

Linux disables unused clocks by default but it is not aware what clocks are used by the Cortex-M4 core. Use the 'clk_ignore_unused' kernel parameter to avoid clocks getting accidentally disabled. The power management suspend code and the Cortex-M4 firmware typically use the same SRAM location leading to a resource conflict. To prevent the suspend code from overwriting the M4 firmware and/or remoteproc from not being able to load, the SRAM driver should be disabled by passing 'initcall_blacklist=sram_init' kernel parameter:

```bash
Colibri VFxx # setenv defargs 'clk_ignore_unused initcall_blacklist=sram_init'
```

By default, our Linux device tree uses UART_B too, which leads to a external abort when the Linux kernel tries to access UART_B. It is recommended to alter the device tree and disable UART_B using the status property (see [[Device Tree Customization]](901439e4-9c90-11e4-8c91-9e9dd95319f8)). Temporary, the following fdt_fixup command can be use in U-Boot:

```bash
Colibri VFxx # setenv fdt_fixup 'fdt addr ${fdt_addr_r} && fdt rm /soc/aips-bus@40000000/serial@40029000'
Colibri VFxx # saveenv
```

### Booting from U-Boot ###

#### Using bootaux ####

With images 2.7b2 and newer you can boot the Cortex-M4 using `bootaux`. This command has been adopted from Colibri iMX7, and allows to boot `bin` and `elf` files directly.

```bash
Colibri VFxx # fatload mmc 0:1 ${loadaddr} firmware.elf
(Or)
Colibri VFxx # tftp ${loadaddr} firmware.elf
...
Colibri VFxx # bootaux ${loadaddr}
## Starting auxiliary core at 0x1F0002E1 ...
Colibri VFxx #
```

##### Store a Firmware on Flash and Run it on Boot #####

Use the following commands to create a UBI volume to store the Cortex-M4 firmware (to free up space for this volume this process will remove the rootfs volume!). The update scripts are required for this steps, make sure you have a SD-card with the image prepared and in your SD-card slot.

```
Colibri VFxx # run setupdate
...
Colibri VFxx # setenv create_m4firmware 'ubi part ubi && ubi remove rootfs && ubi create m4firmware 0xe0000 static && run prepare_ubi'
...
Colibri VFxx # run create_m4firmware
...
Colibri VFxx # fatload mmc 0:1 ${loadaddr} firmware.elf
...
Colibri VFxx # ubi write ${loadaddr} m4firmware ${filesize}
...
Colibri VFxx # run update_rootfs
...
```

Once the UBI volume is in place, a new firmware can be written by just using `ubi write`:

```
Colibri VFxx # ubi part ubi
...
Colibri VFxx # fatload mmc 0:1 ${loadaddr} firmware.elf
...
Colibri VFxx # ubi write ${loadaddr} m4firmware ${filesize}
...
```

You need to extend the default ubiboot command to load and execute the firmware before starting Linux:

```
Colibri VFxx # setenv ubiboot 'run setup; setenv bootargs ${defargs} ${ubiargs} ${setupargs} ${vidargs}; echo Booting from NAND...; ubi part ubi && ubi read ${loadaddr} m4firmware && bootaux ${loadaddr} && ubi read ${kernel_addr_r} kernel && ubi read ${fdt_addr_r} dtb && run fdt_fixup && bootz ${kernel_addr_r} - ${fdt_addr_r}'
Colibri VFxx # saveenv
```

### Booting from Linux ###

In our release image (since v2.6.1), by default remoteproc is disabled to allow Cortex-M4 to start from U-Boot. To start Cortex-M4 using remoteproc, deploy the .elf to '/lib/firmware' directory and load the remoteproc kernel modules. To auto load the remoteproc driver during boot, manually add vf610_cm4_rproc.conf file in '/etc/modules-load.d/'
with the remoteproc driver specified in the conf file. To have the conf deployed with the image, uncomment the line [here](http://git.toradex.com/cgit/meta-toradex-nxp.git/tree/recipes-kernel/linux/linux-toradex_4.4.bb?h=jethro-next&id=624df62851d3b80cac0a2c9ac7745c91ebe0fe81#n16 "") in the kernel recipe and re-build the image with [OpenEmbedded](http://developer.toradex.com/knowledge-base/board-support-package/openembedded-(core) "").
```
root@colibri-vf:~# cat /etc/modules-load.d/vf610_cm4_rproc.conf
vf610_cm4_rproc
```

NOTE: remoteproc by default looks for `freertos-rpmsg.elf` binary in /lib/firmware.
To load a custom .elf one can create a symlink so that `freertos-rpmsg.elf` points to the actual .elf.

```
root@colibri-vf:~# cd /lib/firmware/
root@colibri-vf:~# ln -s firmware.elf freertos-rpmsg.elf
```

```
root@colibri-vf:~# dmesg|grep remoteproc
[    4.897291]  remoteproc0: vf610_m4 is available
[    4.909798]  remoteproc0: Note: remoteproc is still under development and considered experimental.
[    4.934253]  remoteproc0: THE BINARY FORMAT IS NOT YET FINALIZED, and backward compatibility isn't yet guaranteed.
[    4.983452]  remoteproc0: powering up vf610_m4
[    5.069934]  remoteproc0: Booting fw image freertos-rpmsg.elf, size 160544
[    5.084654]  remoteproc0: No resource table found, continuing...
[    5.098450]  remoteproc0: remote processor vf610_m4 is now up
```

__Serial prompt__

You can access the REPL (Python prompt) over UART2 aka UART_B.
- Baudrate: 115200

e.g:
```
MicroPython v1.9.1-166-ge190711f on 2017-07-19; Colibri VF61 with VF6XX_M4
>>> print ("Hello World!")
Hello World!
>>>
```

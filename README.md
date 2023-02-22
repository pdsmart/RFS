## Rom Filing System

<div style="text-align: justify">
The Rom Filing System is a hardware and software upgrade for the Sharp MZ80A. The original hardware replaces the Monitor and User ROM's on the motherboard by a daughter card with lifter sockets where upto 4x512Kbyte Flash RAM's and 1x512Kbyte Static RAM are sited.
<br><br>

Recently the tranZPUter FusionX added hardware compatibility to its virtual capabilities, encapsulating the original hardware as a virtual emulated device and as a consequence is fully RFS compliant.
<br><br>

One of the Flash RAM's is paged into the Monitor ROM socket and the other Flash RAM/Static RAM into the User ROM socket. The first 32Kbytes (8 slots x 4K) of the Monitor Flash RAM and the first 24Kybtes (12 slots of 2K) of the User Flash RAM is
dedicated to paged ROMs with the remainder being used to store Sharp MZF format binary images compacted within 256byte sectors and additional 2K paged Static RAM.
<br><br>

(<i>NB. The sector size may change to 128 byte sectors as the original reason for choosing 256 byte sectors no longer exists</i>).
</div>

--------------------------------------------------------------------------------------------------------

### RFS Software

<div style="text-align: justify">
In order to use the RFS Hardware, a comprehensive set of Z80 assembler methods needed to be written to allow bank paging and with it came the ability to upgrade the machines monitor functionality. This Z80
software forms the Rom Filing System which can be found in the repository within the &lt;software&gt; directory.
</div>

The following table describes each major file which forms the Rom Filing System:

| Module                 | Target ROM | Size | Bank | Description                                                                                                                                                             |
|------------------------|------------|------|------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| rfs.asm                | User       | 2K   | 0    | Primary Rom Filing System and MZ700/MZ800 Monitor tools.                                                                                                                |
| rfs_bank1.asm          | User       | 2K   | 1    | Floppy disk controller functions.                                                                                                                                       |
| rfs_bank2.asm          | User       | 2K   | 2    | SD Card controller functions.                                                                                                                                           |
| rfs_bank3.asm          | User       | 2K   | 3    | Memory monitor utility functions and tape/SD copy utilities.                                                                                                            |
| rfs_bank4.asm          | User       | 2K   | 4    | CMT functions.                                                                                                                                                          |
| rfs_bank5.asm          | User       | 2K   | 5    | Unused.                                                                                                                                                                 |
| rfs_bank6.asm          | User       | 2K   | 6    | Message printing routines, static messages, ascii conversion and help screen.                                                                                           |
| rfs_bank7.asm          | User       | 2K   | 7    | Memory Test utility and 8253 Timer test.                                                                                                                                |
| cbios_bank1.asm        | User       | 2K   | 8    | CPM CBIOS Utilities and Audio functions.                                                                                                                                |
| cbios_bank2.asm        | User       | 2K   | 9    | CPM CBIOS Screen and ANSI Terminal functions.                                                                                                                           |
| cbios_bank3.asm        | User       | 2K   | 10   | CPM CBIOS SD Card Controller functions.                                                                                                                                 |
| cbios_bank4.asm        | User       | 2K   | 11   | CPM CBIOS Floppy Disk Controller functions.                                                                                                                             |
| monitor_SA1510.asm     | Monitor    | 4K   | 0    | Original SA1510 Monitor for 40 character display.                                                                                                                       |
| monitor_80c_SA1510.asm | Monitor    | 4K   | 1    | Original SA1510 Monitor patched for 80 character display.                                                                                                               |
| cbios.asm              | Monitor    | 4K   | 2    | CPM CBIOS (exec location 0xC000:0xCFFFF).                                                                                                                               |
| rfs_mrom.asm           | Monitor    | 4K   | 3    | Rom Filing System helper functions located in the Monitor ROM space in Bank 3. These functions are used to scan and process MZF files stored within the User ROM space. |
| unassigned             | Monitor    | 4K   | 4    | Unused slot.                                                                                                                                                            |
| unassigned             | Monitor    | 4K   | 5    | Unused slot.                                                                                                                                                            |
| unassigned             | Monitor    | 4K   | 6    | Unused slot.                                                                                                                                                            |
| unassigned             | Monitor    | 4K   | 7    | Unused slot.                                                                                                                                                            |


<div style="text-align: justify">
<br>
In the User ROM, the rfs.asm module and  all the rfs_bank&lt;x&gt;.asm modules form the Rom Filing System and are invoked by the original SA-1510 monitor on startup of the MZ80A (or reset). The functionality in these files provides
the Rom Filing System and additional MZ700/800 style monitor utilities. The way the code is structured, a call can be made from one bank to another without issue (stack and execution point manipulation is taken care of) thus
providing almost 16K program space in the User ROM slot.
<br><br>

Sharing the User ROM banks are the cbios_bank&lt;x&gt;.asm modules which form part of the CP/M Custom BIOS. They extend the functionality of the CBIOS without impacting RAM usage which is crucial within CP/M in order
to run as many applications as possible.
<br><br>
  
In the Monitor ROM, the rfs_mrom.asm module is located within the 4th bank (bank 3, bank 0 = original SA1510 ROM, bank 1 = 80 column modified SA1510 ROM) and provides utilities needed by the Rom Filing
System. These utilities are specifically needed for scanning and loading MZF files stored in the User ROM Flash RAM (because code executing in the User ROM cant page itself out to scan the
remainder of the ROM).
<br><br>

CPM v2.2 has been added with the CBIOS (Custom BIOS) being implemented within an MROM Bank (bank 2) along with User ROM Banks 8-11 mentioned above. This saves valuable RAM leaving only the CPM CCP and BDOS in RAM which can
be overwritten by programs, this gives a feasible 47K of useable program RAM. An intention is to include a paged RAM chip in the next release of the RFS Hardware which will allow upto 52K of program RAM.
<br><br>

There are several rapidly written shell scripts to aid in the building of the RFS software (which in all honesty need to be written into a single Python or Java tool). These can be seen in the following table along with their purpose:
<br><br>
</div>

| Script            |  Description                                                                                                             |
|------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| assemble_cpm.sh   | A shell script to build the CPM binary, the CPM MZF format application for loading via RFS and the CPM ROM Drives 0 & 1  |
| assemble_rfs.sh   | A bash script to build the Rom Filing System ROM images.                                                                 |
| assemble_roms.sh  | A bash script to build all the standard MZ80A ROMS, such as the SA-1510 monitor ROM.                                     |
| make_roms.sh      | A bash script to build the RFS ROMS suitable for programming in the 512KByte Flash RAMS. These images contain the banked RFS ROMS, the various system ROMS such as SA-1510 and all the MZF programs to be loaded by the RFS. |
| make_cpmdisks.sh  | A bash script to build a set of CPM disks, for use as Raw images in the SD Card or Rom drives and as CPC Extended Disk Formats for use in a Floppy disk emulator or copying to physical medium. |
| make_sdcard.sh    | A bash script to create an SD card image combining the RFS Images and several CPM disk drives. This image is then binary copied onto the SD card and installed into the RFS SD Card reader. |
| mzftool.pl        | A perl script to create/extract and manipulate MZF images.                                                               |
| processMZFfiles.sh| A bash script to convert a set of MZF programs into sectored images suitable for use in the Rom Filing System ROMS.      |
| sdtool            | A binary created from the src/tools repository which builds the RFS SD Card image, creating a directory and adding MZF/Binary applications into the drive image. |


--------------------------------------------------------------------------------------------------------

### Sharp BASIC SA-5510

<div style="text-align: justify">
The RFS development is primarily for the Sharp MZ-80A and as such it has a large base of BASIC programs. I originally converted Nascom's Microsoft BASIC to use under RFS as the source code was available making the task much easier + there is a large base
of BASIC programs for this interpreter.
<br><br>

After a bit of self-debate I decided to spend time disassembling the original Sharp SA-5510 BASIC to understand how it works and adapt a version suitable to work with the SD card under RFS. Byte location of the interpreter is critical as some programs
are written to expect functions at known locations so disassembly had to be accurate and modifications/enhancements made outside of the main program.
<br><br>

The solution I came up with was to extend the <b>LOAD</b> and <b>SAVE</b> commands and add an additional command <b>DIR</b> for listing of a card directory.
<br><br>

The LOAD/SAVE commands behave exactly as original except they are now intercepted and processed by RFS. On boot, the active SD drive (RFS has 10 drives, 0..9) is used and issuing a LOAD command will search for the requested program or choose the first program at location 00.
<br><br>

The table below lists the command extensions with a brief description.
</div>

| Command  | Parameter  | Description                                                                                                                                           |
| -------  | ---------  | -----------                                                                                                                                           |
| LOAD     | "TEST"     | Look for the program "TEST" on the active drive, generally 0 when SA-5510RFS is started.                                                                           |
| LOAD     |            | Load the first or subsequent file in the active drive. If a file at slot 5 was previously loaded, issuing this command would load file at slot 6.                  |
| LOAD     | "3:TEST"   | Look for the program "TEST" on RFS Drive 3, setting the active drive to 3 at the same time.                                                 |
| LOAD     | "C:TEST"   | Look for the program "TEST" on the internal cassette drive, setting the active drive to the internal cassette at the same time.                                                 |
| SAVE     | "TEST"     | Find a program called "TEST" in the active drive and overwrite it, if it doesnt exist, it will create a file called "TEST". On the cassette it will just write immediately wherever you have positioned the tape.                                         |
| SAVE     |            | Save the current program to a generated name "DEFAULT&lt;number&gt;" where &lt;number&gt; is the current sequence number used in the LOAD command.                             |
| SAVE     | "3:TEST"   | Find a program called "TEST" on RFS Drive 3 and overwrite it, if it doesnt exist, it will create a file called "TEST". It will also set the active drive to 3 for future operations. |
| SAVE     | "C:TEST"   | Save the current program to the internal cassette drive with the name "TEST". It will also set the active drive to C (CMT) for future operations. |
| DIR      |            | List out the SD card directory in RFS format, ie. A file number followed by the filename. |
| DIR      | "3:"       | List out the SD card directory on drive 3 in RFS format, ie. A file number followed by the filename. It will also set the active drive to 3 for future operations. |


<div style="text-align: justify">
To LOAD or SAVE a file to a different drive, qualify the filename with "&lt;drive no&gt;:...",<br>
&nbsp;&nbsp;&nbsp;&nbsp;ie. LOAD "3:TEST" - this will load program "TEST" from drive 3 and make drive 3 active.
<br><br>

To LOAD or SAVE to the builtin cassette drive, use the qualifier "C:"<br>
&nbsp;&nbsp;&nbsp;&nbsp;ie. LOAD "C:" or LOAD "C:TEST".
<br><br>

The new version of BASIC SA-5510 is named "BASIC SA-5510RFS" on the RFS ROM Drive and SD Drive.
</div>

See [SD Card Organisation](/sharpmz-upgrades-rfs/#sd-card-organisation) below for a description of the default drives and contents.

NB: I havent yet fully implemented the random file read/write BASIC operations as I dont fully understand the logic. Once I get a suitable program I can analyse I will adapt RFS so that it seeks, read/writes a single 64K tape block. If there exists 
programs with > 64K databases then RFS will need to be adapted to span successive blocks.

--------------------------------------------------------------------------------------------------------

### Microsoft BASIC

<div style="text-align: justify">
The Sharp machines have several versions of BASIC available to use, on cassette or floppy, although they have limited compatibility with each other (ie. MZ80A SA5510 differs to the MZ-700 S-BASIC). Each machine can have
several variants, ie. SA-6510 for disk drive use or third party versions such as OM-500. Most of these BASIC interpreters run well on RFS so long as they were intended for use on the MZ-80A albeit they are limited to CMT (cassette) or Floppy storage only.
<br><br>

One drawback of the existing BASIC interpreters is availability of source code to update them with RFS extensions. Unless you disassemble the binary or edit the binary directly adding RFS commands is not possible. I came across this same issue during the
development of TZFS on the tranZPUter and needing a version of BASIC to aid in hardware debugging I settled on using a version of Microsoft Basic where the source code was freely available, ie. the NASCOM v4.7b version of BASIC from Microsoft.
This version of Basic has quite a large following in the retro world and consequently a plethora of existing BASIC programs. It is also fairly simple to extend with additional commands.
</div>

There are two versions of the NASCOM 4.7b source code available on the internet, either the original or a version stripped of several hardware dependent commands such as LOAD /SAVE /SCREEN but tweaked to add binary/hex variables by [Grant Searle](http://searle.wales/) for his 
[multicomp project](http://searle.x10host.com/Multicomp/index.html). I took both versions to make a third, writing and expanding on available commands including the missing tape commands.

<div style="text-align: justify">
As the projects developed, Microsoft BASIC needed to support a variety of configurations, even under RFS there are potentially 5 possibilities. Not counting the tranZPUter running under RFS or the TZFS versions there are 3 RFS versions to consider, namely: 
</div>

  * MS-BASIC(MZ-80A) - Original hardware can be booted from cassette.
  * MS-BASIC(RFS40)  - RFS upgrade with 40 column display.
  * MS-BASIC(RFS80)  - RFS upgrade with 80 column display.

Each appears on the RFS drive and should be used according to hardware and need.  The original [NASCOM Basic Manual](../docs/Nascom_Basic_Manual.pdf) should be consulted for the standard set of commands and functions. The table below outlines additions which I have added to better
suite the MZ-80A / RFS hardware.

| Command  | Parameters                          | Version              | Description                                                                        |
|--------- |-------------------------------------|----------------------|------------------------------------------------------------------------------------|
| CLOAD    | "\<filename\>"                      | MZ-80A               | Load a cassette image from the tape drive, ie. tokenised BASIC program\.           |
| CSAVE    | "\<filename\>"                      | MZ-80A               | Save current BASIC program to the tape drive in tokenised cassette image format\.  |
| CLOAD    | "[\<drive\>:]\<filename\>"          | RFS40, RFS80         | Load a cassette image from the tape drive or SD card, ie. tokenised BASIC program\. <br> \<drive\> specifies the RFS drives to use, 0..9 and also makes the drive active for future commands\. <br>\<filename\> can be either an MZ 17 character name or a 2 digit RFS hex number. <br>i.e. CLOAD "8:13" or CLOAD "8:othello" will load the othello program from RFS drive 8. |
| CSAVE    | "[\<drive\>:]\<filename\>"          | RFS40, RFS80         | Save current BASIC program to the tape drive or SD card in tokenised cassette image format\.  |
| DIR      | "[\<drive\>:]"                      | RFS40, RFS80         | Display the active or specified RFS drive contents in RFS format. |
| ANSITERM | 0 = Off, 1 = On                     | MZ-80A, RFS40, RFS80 | Disable or enable (default) the inbuilt Ansi Terminal processor which recognises ANSI escape sequences and converts them into screen actions. This allows for use of portable BASIC programs which dont depend on specialised screen commands. FYI: The Star Trek V2 BASIC program uses ANSI escape sequences\. |

<div style="text-align: justify">
It is also quite easy to adapt this BASIC by changing the memory mode commands so that it will operate on a Sharp MZ-700/MZ-800 with full 64K RAM. The tranZPUter project contains such a version.
</div>


##### NASCOM Cassette Image Converter Tool

<div style="text-align: justify">
NASCOM BASIC programs can be found on the internet as Cassette image files. These files contain all the tape formatting data with embedded tokenised BASIC code. In order to be able to use these files I wrote a converter program which strips out the tape formatting data and reconstructs the BASIC code. In
addition, as this version of BASIC has been enhanced to support new commands, the token values have changed and so this program will automatically update the token value during conversion.
</div>

The converter is designed to run on the command line and it's synopsis is:
    
```bash
NASCONV v1.0

Required:-
  -i | --image <file>      Image file to be converted.
  -o | --output <file>     Target destination file for converted data.

Options:-
  -l | --loadaddr <addr>   MZ80A basic start address. NASCOM address is used to set correct MZ80A address.
  -n | --nasaddr <addr>    Original NASCOM basic start address.
  -h | --help              This help test.
  -v | --verbose           Output more messages.

Examples:
  nasconv --image 3dnc.cas --output 3dnc.bas --nasaddr 0x10fa --loadaddr 0x4341    Convert the file 3dnc.cas from NASCOM cassette format.
```

The files created by the converter are easily useable on the tranZPUter, for the RFS version I need to update the BASIC code to read files from the SD card, wip.

--------------------------------------------------------------------------------------------------------

### RFS Monitor
  
<div style="text-align: justify">
Upon boot, the typical SA-1510 monitor signon banner will appear and be appended with "+ RFS" if all works well. The usual '* ' prompt appears and you can then issue any of the original SA-1510 commands along with a set of enhanced
commands, some of which were seen on the MZ700/ MZ800 range and others are custom.
<br><br>

The full set of commands are listed in the table below:
</div>


| Command | Parameters                          | Description                                                                        |
|---------|-------------------------------------|------------------------------------------------------------------------------------|
| 1 .. 4  |                                     | Switch to RFS Drive, ie. 1. switches to RFS Drive 1.                               |
| 40      | n/a                                 | Switch to 40 Character mode if the 40/80 Column display upgrade has been added\.   |
| 80      | n/a                                 | Switch to 80 Character mode if the 40/80 Column display upgrade has been added\.   |
| 700     | n/a                                 | Switch to Sharp MZ-700 40 column BIOS and mode\.                                   |
| 7008    | n/a                                 | Switch to Sharp MZ-700 80 column BIOS and mode\.                                   |
| B       | n/a                                 | Enable/Disable key entry beep\.                                                    |
| BASIC   | n/a                                 | Locates BASIC SA-5510 on the SD card, loads and runs it.                           |
| C       | \[\<8 bit value\>\]                 | Initialise memory from 0x1200 \- Top of RAM with 0x00 or provided value\.          |
| CPM     | n/a                                 | Locates CP/M 2.23 on the SD card, loads and runs it.                               |
| D       | \<address>\[\<address2>\]           | Dump memory from \<address> to \<address2> (or 20 lines) in hex and ascii. When a screen is full, the output is paused until a key is pressed\. <br><br>Subsequent 'D' commands without an address value continue on from last displayed address\.<br><br> Recognised keys during paging are:<br> 'D' - page down, 'U' - page up, 'X' - exit, all other keys list another screen of data\.|
| EC      | \<name> or <br>\<file number>       | Erase file from SD Card\. The SD Card is searched for a file with \<name> or \<file number> and if found, erased\. |
| F       | \[\<drive number\>\]                | Boot from the given Floppy Disk, if no disk number is given, you will be prompted to enter one\. |
| f       | n/a                                 | Execute the original Floppy Disk AFI code @ 0xF000                                 |
| H       | n/a                                 | Help screen of all these commands\.                                                |
| IR      | n/a                                 | Paged directory listing of the files stored in ROM\. Each file title is preceded with a hex number which can be used to identify the file\. |
| IC      | n/a/                                | Paged directory listing of the files stored on the SD Card\. Each file title is preceded with a hex number which can be used to identify the file\. |
| J       | \<address>                          | Jump \(start execution\) at location \<address>\.                                  |
| L \| LT | n/a                                 | Load file into memory from Tape and execute\.                                      |
| LTNX    | n/a                                 | Load file into memory from Tape, dont execute\.                                    |
| LR      | \<name> or <br>\<file number>       | Load file into memory from ROM\. The ROM is searched for a file with \<name> or \<file number> and if found, loaded and executed\. |
| LRNX    | \<name> or <br>\<file number>       | Load file into memory from ROM\. The ROM is searched for a file with \<name> or \<file number> and if found, loaded and not executed\. |
| LC      | \<name> or <br>\<file number>       | Load file into memory from SD Card\. The SD Card is searched for a file with \<name> or \<file number> and if found, loaded and executed\. |
| LCNX    | \<name> or <br>\<file number>       | Load file into memory from SD Card\. The SD Card is searched for a file with \<name> or \<file number> and if found, loaded and not executed\. |
| M       | \<address>                          | Edit and change memory locations starting at \<address>\.                          |
| P       | n/a                                 | Run a test on connected printer\.                                                  |
| R       | n/a                                 | Run a memory test on main mmemory\.                                                |
| S       | \<start addr> \<end addr> \<exec addr> | Save a block of memory to tape\. You will be prompted to enter the filename\. <br><br>Ie\. S120020001203 - Save starting at 0x1200 up until 0x2000 and set execution address to 0x1203\.  |
| SC      | \<start addr> \<end addr> \<exec addr> | Save a block of memory to SD Card\. You will be prompted to enter the filename\. |
| SD2T    | \<name> or <br>\<file number>       | Copy a file from SD Card to Tape\. The SD Card is searched for a file with \<name> or \<file number> and if found, copied to a tape in the CMT\. |
| T       | n/a                                 | Test the 8253 timer\.                                                              |
| T2SD    | n/a                                 | Copy a file from Tape onto the SD Card. A program is loaded from Tape and written to a free position in the SD Card\. |
| V       | n/a                                 | Verify a file just written to tape with the original data stored in memory         |


If the 40/80 column card is installed, typing '4' switches to 40 Column display, typing '8' switches to 80 Column display. For the directory listing commands, 4 columns of output will be shown when in 80 column mode.

--------------------------------------------------------------------------------------------------------

### Sharp MZ-700 Mode

<div style="text-align: justify">
The tranZPUter SW Version 2.1 board has now been developed and RFS software updated to coexist with this board without a K64F processor (the processor can be present but no use of its services will be made under RFS). This board adds Sharp MZ-700 hardware level 
compatibility logic, both memory management and keyboard remapping are made within hardware.
<br><br>

In order to cater for this upgrade, RFS has been updated to include the MZ-700 1Z-013A monitor ROM and a command to enable it. When enabled, the machine is set to compatibility mode, the 1Z-013A ROM loaded as the primary monitor and reset. The keyboard
is remapped real time and so is the memory. Loading S-BASIC, read/write cassette etc works as expected on an MZ-700.
</div>


--------------------------------------------------------------------------------------------------------


## Building RFS

<div style="text-align: justify">
Building the Rom Filing System involves assembling the Z80 Assembly language source into a machine code binary and packaging it into an image suitable for writing onto a 512Kbyte Flash RAM. You may also want to include MZF applications
in the ROMS for rapid exection via the RFS system. If you intend to use CPM, see also the CPM documentation.
<br><br>

To accomplish it you need several tools and at the moment it is a script aided manual process.
</div>

## Paths

For ease of reading, the following shortnames refer to the corresponding path in this chapter.

|  Short Name      |                                                                            |
|------------------|----------------------------------------------------------------------------|
| \[\<ABS PATH>\]  | The path where this repository was extracted on your system.               |
| \<software\>     | \[\<ABS PATH>\]/MZ80A_RFS/software                                         |
| \<roms\>         | \[\<ABS PATH>\]/MZ80A_RFS/software/roms                                    |
| \<CPM\>          | \[\<ABS PATH>\]/MZ80A_RFS/software/CPM                                     |
| \<tools\>        | \[\<ABS PATH>\]/MZ80A_RFS/software/tools                                   |
| \<src\>          | \[\<ABS PATH>\]/MZ80A_RFS/software/src                                     |
| \<MZF\>          | \[\<ABS PATH>\]/MZ80A_RFS/software/MZF                                     |
| \<MZB\>          | \[\<ABS PATH>\]/MZ80A_RFS/software/MZB                                     |


## Tools

<div style="text-align: justify">
All development has been made under Linux, specifically Debian/Ubuntu. I use Windows for flashing the RAM's and using the GUI version of CP/M Tools but havent dedicated any time into building the RFS under Windows. I will in due course
create a Docker image with all necessary tools installed, but in the meantime, in order to assemble the Z80 code, the C programs and work with the CP/M software andCP/M disk images, you will need to obtain and install the following tools.
</div>

[Z80 Glass Assembler](http://www.grauw.nl/blog/entry/740/) - A Z80 Assembler for converting Assembly files into machine code.<br>
[samdisk](https://simonowen.com/samdisk/)   - A multi-os command line based low level disk manipulation tool.<br>
[cpmtools](https://www.cpm8680.com/cpmtools/) - A multi-os command line CP/M disk manipulation tool.<br>
[CPMToolsGUI](http://star.gmobb.jp/koji/cgi/wiki.cgi?page=CpmtoolsGUI) - A Windows based GUI CP/M disk manipulation tool.<br>
[z88dk](https://www.z88dk.org/forum/) - An excellent C development kit for the Z80 CPU.<br>
[sdcc](http://sdcc.sourceforge.net/) - Another excellent Small Device C compiler, the Z80 being one of its targets. z88dk provides an enhanced (for the Z80) version of this tool within its package.<br>



## Software

Building the software and final ROM images can be done by cloning the [repository](https://github.com/pdsmart/MZ80A_RFS.git) and running some of the shell scripts and binaries provided.

The basic procedure to build RFS as follows:

   1. Make the RFS binary using \<tools\>/assemble_rfs.sh, this creates \<roms\>/rfs.rom for the User Bank Flash RAM and \<roms\>/rfs_mrom.rom for the Monitor Bank Flash RAM.
   2. Make the original MZ80A monitor roms using \<tools\>/assemble_roms.sh, this creates \<roms\>/monitor_SA1510.rom and \<roms\>/monitor_80c_SA1510.rom for the Monitor Bank Flash RAM.
   3. Make the rom images using \<tools\>/make_roms.sh, this creates \<roms\>/USER_ROM_256.bin for the User Bank Flash RAM and \<roms\>/MROM_256.bin for the Monitor Bank Flash RAM.
      The rom images also contain a packed set of MZF applications found in the \<MZF\> directory. Edit the script \<tools\>/make_roms.sh to add or remove applications from the rom images.

The above procedure has been encoded in a set of shell scripts and C tools, which at the simplest level, is to run these commands:
````bash
cd <software>
tools/assemble_cpm.sh
tools/assemble_rfs.sh
tools/assemble_roms.sh
tools/make_cpmdisks.sh
tools/make_roms.sh
tools/make_sdcard.sh
````

The output of the above commands are ROM images \<roms\>/MROM_256.bin and \<roms\>/USER_ROM.256.bin which must be flashed into 512Kbyte Flash RAMS and inserted into the sockets on the
RFS adapter.

The applications which can be stored in the Flash RAMS are located in the \<MZF\> directory. In order to use them within the Flash RAM's, the applications need to be converted into sector rounded binary images and stored in the
\<MZB\> directory. The tool \<tool\>/processMZFiles.sh has been created for this purpose. Simply copy any MZF application into the \<MZF\> directory and run this tool:

```bash
cd <software>
tools/processMZFfiles.sh
```
The files will be converted and stored in the \<MZB\> directory and then used by the \<tools\>/make_roms.sh script when creating the ROM images.  The \<tools\>/make_roms.sh script lists all the applications to be added into the 
Flash RAM's and it will pack as many as space permits. To ensure your application appears in the Flash RAM, add it to the top of the list (just the filename not the .MZF extension), ie:

```bash
Edit the file <tools>/make_roms.sh
Locate the line: ROM_INCLUDE=
Below this line, add your application in the format: ROM_INCLUDE+="${MZBPATH}/<YOUR APPLICATION>.${SECTORSIZE}.bin"
ie. ROM_INCLUDE+="${MZB_PATH}/A-BASIC_SA-5510.${SECTORSIZE}.bin:"
Save the file and run the commands above to build the MonitorROM and USERROM's.
```


<div style="text-align: justify">
The SD Card image is created by the &#60;tools&#62;/make_sdcard.sh script and in its basic form creates an image which can be directly copied onto an SD Card. The start of the image is a Rom Filing System image which is populated with
MZF applications from the &#60;MZF&#62; directory. The RFS image is followed by several CPM Disk images and together is canned the SD Card Filing System. 
</div>

In order to add/remove MZF applications from the Rom Filing System image, edit the &#60;tools&#62;/make_sdcard.sh script and change which MZF applications are to be installed. CP/M images are also added to the SD Card and this is covered in the 
[CP/M](sharpmz-upgrades-cpm/) section.
<br>

To copy the SD Card Filing System image created by the &#60;tools&#62;/make_sdcard.sh script onto an SD card, use a suitable tool direct binary copy tool such as <b>dd</b> under Linux.<br>
ie. dd if=SHARP_MZ80A_RFS_CPM_IMAGE_1.img of=/dev/sdd bs=512
<br>

<div style="text-align: justify">
No disk partitioning is needed as the SDCFS image starts at sector 0 on the SD Card. Once the image has been copied, place into the SD Card Reader on the RFS Board.
</div>


## SD Card 

<div style="text-align: justify">
A recent addition to the Rom Filing System is an SD Card. The initial version was implemented in minimal hardware using the bitbang technique and provides performance comparable with a floppy disk without the seek overhead or interleave
times. In v2.0 onwards this was extended to a full hardware SPI circuit giving ROM level performance.
</div>

I worked on using the [Petit FatFS by El CHaN](http://elm-chan.org/fsw/ff/00index_p.html) for the SD Card filing system, which is excellent, having previously used the full Fat version with my ZPU project, but the Z80 isnt the best
architecture for code size when using C. In the repository in \<src\>/tools is my developments along this line with a C program called 'sdtest' and a modularized PetitFS along with manually coded Z80 assembler to handle the bitbang
algorithm and SD Card initialisation and communications.  The program compiles into an MZF application and when run performs flawlessly. The only issue as mentioned is size and when your limited to 2K and 4K banked roms with a 12K
filing system you have an immediate storage issue. It is feasible to build PetitFS into a set of ROM banks using the z88dk C Compiler which supports banked targets and \_\_far constructs but it would be a lot of effort for something
which really isnt required.

<div style="text-align: justify">
I thus took a step back and decided to create my own simple filing system which is described below. This filing system is used for Sharp MZ80A MZF applications and is for both read and write operations.
</div>

### SD Card Filing System

<div style="text-align: justify">
The SD Card Filing System resides at the beginning of the SD Card and is followed by several CPM disk drive images. The SDCFS image is constructed of a directory plus 256 file blocks. The directory in the image can contain upto 256 entries, 
each entry being 32 bytes long.
<br><br>

10 SDCFS images are supported per SD Card, numbered 0..9.
<br><br>

The SDCFS directory entry is based on the MZF Header format and is as follows:
</div>

| FLAG1  | FLAG2  | FILE NAME | START SECTOR | SIZE    | LOAD ADDR | EXEC ADDR | RESERVED |
|--------|--------|-----------|--------------|---------|-----------|-----------|----------|
| 1 Byte | 1 Byte | 17 Bytes  | 4 Bytes      | 2 Bytes | 2 Bytes   | 2 Bytes   | 3 Bytes  |


| Parameter&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;| Description                              |
| ---------                   | --------------------------------------------------------------------------------------------- |
|  FLAG1                      | BIT 7 = 1, Valid directory entry, 0 = inactive.                                               |
|  FLAG2                      | MZF Execution Code, 0x01 = Binary                                                             |
|  FILENAME                   | Standard MZF format filename.                                                                 |
|  START SECTOR               | Sector in the active SDCFS image where the program starts. It always starts at position 0 of the sector. |
|  SIZE                       | Size in bytes of the program. Each file block occupies 64Kbyte space (as per a tape) and this parameter provides the actual space occupied by the program at the current time. |
|  LOAD ADDR                  | Start address in memory where data should be loaded.                                          |
|  EXEC ADDR                  | If a binary then this parameter specifies the location to auto execute once loaded.           |
|  RESERVED                   | Not used at the moment.                                                                       |

Each file block, 1 per directory entry, is 64K long which is intentional as it keeps a fixed size which is in line
with the maximum tape (CMT) length and can be freely read/written to just as if it were a tape. This allows for easy
use within tape based applications such as Basic SA-5510 or for copying SD Card \<-\> CMT.

<div style="text-align: justify">
The remainder of the SD Card is filled with 16MByte CPM Disk drive images. Each image is organised as 32 (512byte) Sectors x 1024 tracks
and 1 head. Each image will be mounted in CPM under its own drive letter.
</div>

Visually, the SD Card is organised as follows:

```
ADDR     SECTOR  FUNCTION
00000000   0000  ---------------------------------------------------------------------------
                 | ROM FILING SYSTEM IMAGE 0                                               |
                 |                                                                         |
00000000   0000  | RFS DIRECTORY ENTRY 000 (32BYTE)                                        |
                 | ..                                                                      |
                 | ..                                                                      |
00001FE0   000F  | RFS DIRECTORY ENTRY 255 (32BYTE)                                        |
00002000   0010  ---------------------------------------------------------------------------
                 | RFS FILE BLOCK 0                                                        |
00011FFF   008F  ---------------------------------------------------------------------------
                 ...
00FF2000   7F90  ---------------------------------------------------------------------------
                 | RFS FILE BLOCK 255                                                      |
01001FFF   800F  ---------------------------------------------------------------------------

...

09012000  48090  ---------------------------------------------------------------------------
                 | ROM FILING SYSTEM IMAGE 9                                               |
                 |                                                                         |
09012000  48090  | RFS DIRECTORY ENTRY 000 (32BYTE)                                        |
                 | ..                                                                      |
                 | ..                                                                      |
09013FE0  4809F  | RFS DIRECTORY ENTRY 255 (32BYTE)                                        |
09014000  480A0  ---------------------------------------------------------------------------
                 | RFS FILE BLOCK 0                                                        |
09023FFF  4811F  ---------------------------------------------------------------------------
                 ...
0A004000  50020  ---------------------------------------------------------------------------
                 | RFS FILE BLOCK 255                                                      |
0A013FFF  5009F  ---------------------------------------------------------------------------

... padding ...

10000000  80000  ---------------------------------------------------------------------------
                 |                                                                         |
                 |  CP/M DISK IMAGE 0                                                      |
                 |                                                                         |
11000000  88000  ---------------------------------------------------------------------------
                 |                                                                         |
                 |  CP/M DISK IMAGE 1                                                      |
                 |                                                                         |
12000000  90000  ---------------------------------------------------------------------------
                 |                                                                         |
                 |  CP/M DISK IMAGE 2                                                      |
                 |                                                                         |
XX000000 XX0000  ---------------------------------------------------------------------------
                 |                                                                         |
                 |  CP/M DISK IMAGE <n>                                                    |
                 |                                                                         |
                 ---------------------------------------------------------------------------
```

## SD Card Organisation

The tools in the repository create an SD card with 10 RFS Drives and 6 CP/M Drives. These are organised as follows:

| RFS Drive  | Description                                                                 |
| ---------  | -----------                                                                 |
|  0         | Common and MZ-80A Machine Code programs.                                    |
|  1         | MZ-80K Machine Code programs.                                               |
|  2         | MZ-700 Machine Code programs.                                               |
|  3         | MZ-800/MZ-1500 Machine Code programs.                                       |
|  4         | MZ-80B/MZ-2000 Machine Code programs.                                       |
|  5         | BASIC programs, type 2 (MZ80A)                                              |
|  6         | BASIC programs, type 2 (MZ80K)                                              |
|  7         | BASIC programs, type 5 (MZ700/800)                                          |
|  8         | Other programs.                                                             |
|  9         | Other programs.                                                             |

| CPM Drive  | User No | Contents             | Comments                                                            |
| ---------  | ------- | --------             | --------                                                            |
|  0         |  0      | CPM00_SYSTEM         | System programs.                                                    |
|            |  1      | CPM01_TURBOP         | Turbo Pascal.                                                       |
|            |  2      | CPM02_HI_C           | Hi-Soft C                                                           |
|            |  3      | CPM03_FORTRAN80      | Fortran 80                                                          |
|            |  4      | CPM04_MBASIC         | Microsoft Basic 80/85                                               |
|            |  5      | CPM05_COBOL80_v13    | Cobol v1.3                                                          |
|            |  6      | CPM06_COBOL80_v20    | Cobol v2.0                                                          |
|            |  7      | CPM07_COBOL80        | Cobol 80                                                            |
|            |  8      | CPM08_Z80FORTH       | Z80 Forth                                                           |
|            |  9      | CPM09_CPMTEX         | CP/M Tex                                                            |
|            |  10     | CPM10_DISKUTILFUNC5  | Disk utilities.                                                     |
|            |  11     | CPM11_MAC80          | Macro Assembler 80                                                  |
|            |  12     | CPM29_ZSID_v14       | ZSID Debugger.                                                      |
|            |  13     | CPM32_ZCPR3          | ZCPR3 CCP enhancement.                                              |
|            |  14     | CPM33_ZCPR3_COMMON   | ZCPR3 CCP enhancement common utilities.                             |
|  1         |  0      | CPM12_PASCALMTP_v561 | Pascal v5.61                                                        |
|            |  1      | CPM26_TPASCAL_v300a  | Turbo Pascal v3.00a                                                 |
|            |  2      | CPM13_MTPUG_01       | Pascal User Group Disk 01                                           |
|            |  3      | CPM14_MTPUG_02       | Pascal User Group Disk 02                                           |
|            |  4      | CPM15_MTPUG_03       | Pascal User Group Disk 03                                           |
|            |  5      | CPM16_MTPUG_04       | Pascal User Group Disk 04                                           |
|            |  6      | CPM17_MTPUG_05       | Pascal User Group Disk 05                                           |
|            |  7      | CPM18_MTPUG_06       | Pascal User Group Disk 06                                           |
|            |  8      | CPM19_MTPUG_07       | Pascal User Group Disk 07                                           |
|            |  9      | CPM20_MTPUG_08       | Pascal User Group Disk 08                                           |
|            |  10     | CPM21_MTPUG_09       | Pascal User Group Disk 09                                           |
|            |  11     | CPM22_MTPUG_10       | Pascal User Group Disk 10                                           |
|  2         |  0      | CPM23_PLI            | PLI Compiler.                                                       |
|            |  1      | CPM24_PLI80_v13      | PLI 80 Compiler v1.3                                                |
|            |  2      | CPM25_PLI80_v14      | PLI 80 Compiler v1.4                                                |
|            |  3      | CPM28_PLM80          | PLM 80.                                                             |
|            |  4      | CPM27_WORDSTAR_v30   | WordStar v3.0                                                       |
|            |  5      | CPM31_WORDSTAR_v330  | WordStar v3.3                                                       |
|            |  6      | CPM30_WORDSTAR_v400  | WordStar v4.0                                                       |
|  3         |  0      | CPM_MC_C0            | Grant Searle's CPM collection Disk C0                               |
|            |  1      | CPM_MC_C1            |                                    C1                               |
|            |  2      | CPM_MC_C2            |                                    C2                               |
|            |  3      | CPM_MC_C3            |                                    C3                               |
|            |  4      | CPM_MC_C4            |                                    C4                               |
|            |  5      | CPM_MC_C5            |                                    C5                               |
|            |  6      | CPM_MC_C6            |                                    C6                               |
|            |  7      | CPM_MC_C7            |                                    C7                               |
|            |  8      | CPM_MC_C8            |                                    C8                               |
|            |  9      | CPM_MC_C9            |                                    C9                               |
|  4         |  0      | CPM_MC_D0            | Grant Searle's CPM collection Disk D0                               |
|            |  1      | CPM_MC_D1            |                                    D1                               |
|            |  2      | CPM_MC_D2            |                                    D2                               |
|            |  3      | CPM_MC_D3            |                                    D3                               |
|            |  4      | CPM_MC_D4            |                                    D4                               |
|            |  5      | CPM_MC_D5            |                                    D5                               |
|            |  6      | CPM_MC_D6            |                                    D6                               |
|            |  7      | CPM_MC_D7            |                                    D7                               |
|            |  8      | CPM_MC_D8            |                                    D8                               |
|            |  9      | CPM_MC_D9            |                                    D9                               | 
|  5         |  0      | CPM_MC_E0            | Grant Searle's CPM collection Disk E0                               |
|            |  1      | CPM_MC_E1            |                                    E1                               |
|            |  2      | CPM_MC_E2            |                                    E2                               |
|            |  3      | CPM_MC_E3            |                                    E3                               |
|            |  4      | CPM_MC_E4            |                                    E4                               |
|            |  5      | CPM_MC_E5            |                                    E5                               |
|            |  6      | CPM_MC_E6            |                                    E6                               |
|            |  7      | CPM_MC_E7            |                                    E7                               |
|            |  8      | CPM_MC_E8            |                                    E8                               |
|            |  9      | CPM_MC_E9            |                                    E9                               |
|  6         |  0      | CPM_MC_F0            | Grant Searle's CPM collection Disk F0                               |
|            |  1      | CPM_MC_F1            |                                    F1                               |
|            |  2      | CPM_MC_F2            |                                    F2                               |
|            |  3      | CPM_MC_F3            |                                    F3                               |
|            |  4      | CPM_MC_F4            |                                    F4                               |
|            |  5      | CPM_MC_F5            |                                    F5                               |
|            |  6      | CPM_MC_F6            |                                    F6                               |
|            |  7      | CPM_MC_F7            |                                    F7                               |
|            |  8      | CPM_MC_F8            |                                    F8                               |
|            |  9      | CPM_MC_F9            |                                    F9                               |



## Credits

<div style="text-align: justify">
Where I have used or based any component on a 3rd parties design I have included the original authors copyright notice within the headers or given due credit. All 3rd party software, to my knowledge and research, is open source and freely useable, if there is found to be any component with licensing restrictions, it will be removed from this repository and a suitable link/config provided.
</div>


## Licenses

<div style="text-align: justify">
This design, hardware and software, is licensed under the GNU Public Licence v3.
</div>

### The Gnu Public License v3

<div style="text-align: justify">
 The source and binary files in this project marked as GPL v3 are free software: you can redistribute it and-or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
<br><br>

 The source files are distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
<br><br>

 You should have received a copy of the GNU General Public License along with this program.  If not, see http://www.gnu.org/licenses/.
</div>

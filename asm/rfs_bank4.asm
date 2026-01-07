;--------------------------------------------------------------------------------------------------------
;-
;- Name:            rfs_bank4.asm
;- Created:         July 2019
;- Author(s):       Philip Smart
;- Description:     Sharp MZ series Rom Filing System.
;-                  This assembly language program is written to utilise the banked flashroms added with
;-                  the MZ-80A RFS hardware upgrade.
;-
;- Credits:         
;- Copyright:       (c) 2018-2023 Philip Smart <philip.smart@net2net.org>
;-
;- History:         July 2019 - Merged 2 utilities to create this compilation.
;-                  May 2020  - Bank switch changes with release of v2 pcb with coded latch. The coded
;-                              latch adds additional instruction overhead as the control latches share
;-                              the same address space as the Flash RAMS thus the extra hardware to
;-                              only enable the control registers if a fixed number of reads is made
;-                              into the upper 8 bytes which normally wouldnt occur. Caveat - ensure
;-                              that no loop instruction is ever placed into EFF8H - EFFFH.
;-                  Aug 2023  - Updates to make RFS run under the SFD700 Floppy Disk Interface board.
;-                              UROM remains the same, a 2K paged ROM, MROM is located at F000 when
;-                              RFS is built for the SFD700.
;-
;--------------------------------------------------------------------------------------------------------
;- This source file is free software: you can redistribute it and-or modify
;- it under the terms of the GNU General Public License as published
;- by the Free Software Foundation, either version 3 of the License, or
;- (at your option) any later version.
;-
;- This source file is distributed in the hope that it will be useful,
;- but WITHOUT ANY WARRANTY; without even the implied warranty of
;- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;- GNU General Public License for more details.
;-
;- You should have received a copy of the GNU General Public License
;- along with this program.  If not, see <http://www.gnu.org/licenses/>.
;--------------------------------------------------------------------------------------------------------

            IF BUILD_SFD700 = 1
             ORG    0E000H
             ALIGN  0E300H
             DB     "BANK4"
             ALIGN  UROMADDR
            ENDIF

            ;===========================================================
            ;
            ; USER ROM BANK 4 - CMT Controller utilities.
            ;
            ;===========================================================
            ORG     UROMADDR

            ;--------------------------------
            ; Common code spanning all banks.
            ;--------------------------------
            NOP
            HWSELROM2                                                         ; Select the first ROM page.
            ;
            ; No mans land... this should have switched to Bank 0 and at this point there is a jump to 00000H.
            JP      00000H                                                   ; This is for safety!!


            ;------------------------------------------------------------------------------------------
            ; Bank switching code, allows a call to code in another bank.
            ; This code is duplicated in each bank such that a bank switch doesnt affect logic flow.
            ;------------------------------------------------------------------------------------------            
            ALIGN_NOPS UROMBSTBL
            ;
BKSW4to0:   PUSH    AF
            LD      A, ROMBANK4                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK0                                              ; Required bank to call.
            JR      BKSW4_0
BKSW4to1:   PUSH    AF
            LD      A, ROMBANK4                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK1                                              ; Required bank to call.
            JR      BKSW4_0
BKSW4to2:   PUSH    AF
            LD      A, ROMBANK4                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK2                                              ; Required bank to call.
            JR      BKSW4_0
BKSW4to3:   PUSH    AF
            LD      A, ROMBANK4                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK3                                              ; Required bank to call.
            JR      BKSW4_0
BKSW4to4:   PUSH    AF
            LD      A, ROMBANK4                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK4                                              ; Required bank to call.
            JR      BKSW4_0
BKSW4to5:   PUSH    AF
            LD      A, ROMBANK4                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK5                                              ; Required bank to call.
            JR      BKSW4_0
BKSW4to6:   PUSH    AF
            LD      A, ROMBANK4                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK6                                              ; Required bank to call.
            JR      BKSW4_0
BKSW4to7:   PUSH    AF
            LD      A, ROMBANK4                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK7                                              ; Required bank to call.
            ;
BKSW4_0:    PUSH    HL                                                       ; Place function to call on stack
            LD      HL, BKSWRET4                                             ; Place bank switchers return address on stack.
            EX      (SP),HL
            LD      (TMPSTACKP),SP                                           ; Save the stack pointer as some old code corrupts it.
            BNKSWSEL
            JP      (HL)                                                     ; Jump to required function.
BKSWRET4:   POP     AF                                                       ; Get bank which called us.
            BNKSWSELRET
            POP     AF
            RET  

           ;-------------------------------------------------------------------------------
           ; START OF CMT CONTROLLER FUNCTIONALITY
           ;-------------------------------------------------------------------------------

            ; CMT Utility to Load a program from tape.
            ;
            ; Three entry points:
            ; LOADTAPE = Load the first program shifting to lo memory if required and execute.
            ; LOADTAPENX = Load the first program and return without executing.
            ; LOADTAPECP = Load the first program to address 0x1200 and return.
            ;
LOADTAPECP: LD      A,0FFH
            LD      (CMTAUTOEXEC),A
            JR      LOADTAPE2
LOADTAPENX: LD      A,0FFH
            JR      LOADTAPE1
LOADTAPE:   LD      A,000H
LOADTAPE1:  LD      (CMTAUTOEXEC),A
            XOR     A
LOADTAPE2:  LD      (CMTCOPY),A                                          ; Set cmt copy mode, 0xFF if we are copying.
            LD      A,0FFH                                               ; If called interbank, set a result code in memory to detect success.
            LD      (RESULT),A
            CALL    ?RDI
            JP      C,?ERX2
            LD      DE,MSGLOAD                                           ; 'LOADING '
            LD      BC,NAME
            LD      HL,PRINTMSG
            CALL    BKSW4to6
            XOR     A
            LD      (CMTLOLOAD),A

            LD      HL,(DTADR)                                           ; Common code, store load address in case we shift or manipulate loading.
            LD      (DTADRSTORE),HL

            LD      A,(CMTCOPY)                                          ; If were copying we always load at 0x1200.
            OR      A
            JR      Z,LOADTAPE3
            LD      HL,01200H
            LD      (DTADR),HL

LOADTAPE3:  LD      HL,(DTADR)                                           ; If were loading and the load address is below 0x1200, shift it to 0x1200 to load then move into correct location.
            LD      A,H
            OR      L
            JR      NZ,LOADTAPE4
            LD      A,0FFh
            LD      (CMTLOLOAD),A
            LD      HL,01200h
            LD      (DTADR),HL
LOADTAPE4:  CALL    ?RDD
            JP      C,?ERX2
            LD      HL,(DTADRSTORE)                                      ; Restore the original load address into the CMT header.
            LD      (DTADR),HL
            LD      A,(CMTCOPY)
            OR      A
            JR      NZ,LOADTAPE6
LOADTAPE5:  LD      A,(CMTAUTOEXEC)                                      ; Get back the auto execute flag.
            OR      A
            JR      NZ,LOADTAPE6                                         ; Dont execute..
            LD      A,(CMTLOLOAD)
            CP      0FFh
            JR      Z,LOADTAPELM                                         ; Execute at low memory?
            LD      BC,00100h
            LD      HL,(EXADR)
            JP      (HL)
LOADTAPELM: LD      A,(MEMSW)                                            ; Perform memory switch, mapping out ROM from $0000 to $C000
            LD      HL,01200h                                            ; Shift the program down to RAM at $0000
            LD      DE,00000h
            LD      BC,(SIZE)
            LDIR
            LD      BC,00100h
            LD      HL,(EXADR)                                           ; Fetch exec address and run.
            JP      (HL)
LOADTAPE6:  LD      DE,MSGCMTDATA
            PUSH    HL                                                   ; Load address as parameter 2.
            LD      HL,(EXADR)
            PUSH    HL                                                   ; Execution address as parameter 1.
            LD      BC,(SIZE)                                            ; Size as BC parameter.
            LD      HL,PRINTMSG
            CALL    BKSW4to6
            POP     BC
            POP     BC                                                   ; Waste parameters.
            XOR     A                                                    ; Success.
            LD      (RESULT),A
            RET


            ; SA1510 Routine to write a tape header. Copied into the RFS and modified to merge better
            ; with the RFS interface.
            ;
CMTWRI:    ;DI      
            PUSH    DE
            PUSH    BC
            PUSH    HL
            LD      D,0D7H
            LD      E,0CCH
            LD      HL,IBUFE
            LD      BC,00080H
            CALL    CKSUM
            IF      BUILD_ROMDISK = 1
              CALL  MOTOR80A 
            ENDIF
            IF      BUILD_SFD700 = 1
              IN    A,(SFD700_MODE)
              OR    A
              JR    Z,CMTWRI80A
              CALL  MOTOR700
              JR    CMTWRI0
CMTWRI80A:    CALL  MOTOR80A
            ENDIF
CMTWRI0:    JR      C,CMTWRI2                 
            LD      A,E
            CP      0CCH
            JR      NZ,CMTWRI1                
            PUSH    HL
            PUSH    DE
            PUSH    BC
            LD      DE,MSGCMTWRITE
            LD      BC,NAME
            LD      HL,PRINTMSG
            CALL    BKSW4to6
            POP     BC
            POP     DE
            POP     HL
CMTWRI1:    CALL    GAP
            IF      BUILD_ROMDISK = 1
              CALL  WTAPE80A
            ENDIF
            IF      BUILD_SFD700 = 1
              IN    A,(SFD700_MODE)
              OR    A
              JR    Z,CMTWRI80A2
              CALL  WTAPE700
              JR    CMTWRI2
CMTWRI80A2:   CALL  WTAPE80A
            ENDIF
CMTWRI2:    POP     HL
            POP     BC
            POP     DE
            CALL    MSTOP
            PUSH    AF
            LD      A,(TIMFG)
            CP      0F0H
            JR      NZ,CMTWRI3                
           ;EI      
CMTWRI3:    POP     AF
            RET     


            ; Method to save an application stored in memory to a cassette in the CMT. The start, size and execution address are either given in BUFER via the 
            ; command line and the a filename is prompted for and read, or alternatively all the data is passed into the function already set in the CMT header.
            ; The tape is then opened and the header + data are written out.
            ;
SAVECMT:    LD      A,0FFH                                               ; Set SDCOPY to indicate this is a copy command and not a command line save.
            JR      SAVEX1
            ;
            ; Normal entry point, the cmdline contains XXXXYYYYZZZZ where XXXX=start, YYYY=size, ZZZZ=exec addr. A filenname is prompted for and read.
            ; The data is stored in the CMT header prior to writing out the header and data..
            ;
SAVEX:      LD      HL,GETCMTPARM                                        ; Get the CMT parameters.
            CALL    BKSW4to3
            LD      A,C
            OR      A
            RET     NZ                                                   ; Exit if an error occurred.

            XOR     A
SAVEX1:     LD      (SDCOPY),A
            LD      A,0FFH
            LD      (RESULT),A                                           ; For interbank calls, pass result via a memory variable. Assume failure unless updated.
            LD      A,OBJCD                                              ; Set attribute: OBJ
            LD      (ATRB),A
            CALL    CMTWRI                                               ; Commence header write. Header doesnt need updating for header write.
?ERX1:      JP      C,?ERX2

            LD      A,(SDCOPY)
            OR      A
            JR      Z,SAVEX2
            LD      DE,(DTADR)
            LD      A,D                                                  ; If copying and address is below 1000H, then data is held at 1200H so update header for write.
            CP      001H
            JR      NC,SAVEX2
            LD      DE,01200H
            LD      (DTADR),DE
SAVEX2:     CALL    ?WRD                                                 ; data
            JR      C,?ERX1
            LD      DE,MSGSAVEOK                                         ; 'OK!'
            LD      HL,PRINTMSG
            CALL    BKSW4to6
            LD      A,0                                                  ; Success.
            LD      (RESULT),A
            RET
?ERX2:      CP      002h
            JR      NZ,?ERX3
            LD      (RESULT),A                                           ; Set break key pressed code.
            RET     Z
?ERX3:      LD      DE,MSGE1                                             ; 'CHECK SUM ER.'
            LD      HL,PRINTMSG
            CALL    BKSW4to6
            RET


            ; Method to verify that a tape write occurred free of error. After a write, the tape is read and compared with the memory that created it.
            ;
VRFYX:      CALL    ?VRFY
            JP      C,?ERX2
            LD      DE,MSGOK                                             ; 'OK!'
            LD      HL,PRINTMSG
            CALL    BKSW4to6
            RET

            ; Method to toggle the audible key press sound, ie a beep when a key is pressed.
            ;
SGX:        LD      A,(SWRK)
            RRA
            CCF
            RLA
            LD      (SWRK),A
            RET

            ;-------------------------------------------------------------------------------
            ; END OF CMT CONTROLLER FUNCTIONALITY
            ;-------------------------------------------------------------------------------

           ;-------------------------------------------------------------------------------
           ; START OF MEMORY TEST FUNCTIONALITY
           ;-------------------------------------------------------------------------------

MEMTEST:    LD      B,240       ; Number of loops
LOOP:       LD      HL,MEMSTART ; Start of checked memory,
            LD      D,0CFh      ; End memory check CF00
LOOP1:      LD      A,000h
            CP      L
            JR      NZ,LOOP1b
            CALL    PRTHL       ; Print HL as 4digit hex.
            LD      A,0C4h      ; Move cursor left.
            LD      E,004h      ; 4 times.
LOOP1a:     CALL    DPCT
            DEC     E
            JR      NZ,LOOP1a
LOOP1b:     INC     HL
            LD      A,H
            CP      D           ; Have we reached end of memory.
            JR      Z,LOOP3     ; Yes, exit.
            LD      A,(HL)      ; Read memory location under test, ie. 0.
            CPL                 ; Subtract, ie. FF - A, ie FF - 0 = FF.
            LD      (HL),A      ; Write it back, ie. FF.
            SUB     (HL)        ; Subtract written memory value from A, ie. should be 0.
            JR      NZ,LOOP2    ; Not zero, we have an error.
            LD      A,(HL)      ; Reread memory location, ie. FF
            CPL                 ; Subtract FF - FF
            LD      (HL),A      ; Write 0
            SUB     (HL)        ; Subtract 0
            JR      Z,LOOP1     ; Loop if the same, ie. 0
LOOP2:      LD      A,16h
            CALL    PRNT        ; Print A
            CALL    PRTHX       ; Print HL as 4 digit hex.
            CALL    PRNTS       ; Print space.
            XOR     A
            LD      (HL),A
            LD      A,(HL)      ; Get into A the failing bits.
            CALL    PRTHX       ; Print A as 2 digit hex.
            CALL    PRNTS       ; Print space.
            LD      A,0FFh      ; Repeat but first load FF into memory
            LD      (HL),A
            LD      A,(HL)
            CALL    PRTHX       ; Print A as 2 digit hex.
            NOP
            JR      LOOP4

LOOP3:      CALL    PRTHL
            LD      DE,OKCHECK
            CALL    MSG          ; Print check message in DE
            LD      A,B          ; Print loop count.
            CALL    PRTHX
            LD      DE,OKMSG
            CALL    MSG          ; Print ok message in DE
            CALL    NL
            DEC     B
            JR      NZ,LOOP
            LD      DE,DONEMSG
            CALL    MSG          ; Print check message in DE
            JP      ST1X

LOOP4:      LD      B,09h
            CALL    PRNTS        ; Print space.
            XOR     A            ; Zero A
            SCF                  ; Set Carry
LOOP5:      PUSH    AF           ; Store A and Flags
            LD      (HL),A       ; Store 0 to bad location.
            LD      A,(HL)       ; Read back
            CALL    PRTHX        ; Print A as 2 digit hex.
            CALL    PRNTS        ; Print space
            POP     AF           ; Get back A (ie. 0 + C)
            RLA                  ; Rotate left A. Bit LSB becomes Carry (ie. 1 first instance), Carry becomes MSB
            DJNZ    LOOP5        ; Loop if not zero, ie. print out all bit locations written and read to memory to locate bad bit.
            XOR     A            ; Zero A, clears flags.
            LD      A,80h
            LD      B,08h
LOOP6:      PUSH    AF           ; Repeat above but AND memory location with original A (ie. 80) 
            LD      C,A          ; Basically walk through all the bits to find which one is stuck.
            LD      (HL),A
            LD      A,(HL)
            AND     C
            NOP
            JR      Z,LOOP8      ; If zero then print out the bit number
            NOP
            NOP
            LD      A,C
            CPL
            LD      (HL),A
            LD      A,(HL)
            AND     C
            JR      NZ,LOOP8     ; As above, if the compliment doesnt yield zero, print out the bit number.
LOOP7:      POP     AF
            RRCA
            NOP
            DJNZ    LOOP6
            JP      ST1X

LOOP8:      CALL    LETNL        ; New line.
            LD      DE,BITMSG    ; BIT message
            CALL    MSG          ; Print message in DE
            LD      A,B
            DEC     A
            CALL    PRTHX        ; Print A as 2 digit hex, ie. BIT number.
            CALL    LETNL        ; New line
            LD      DE,BANKMSG   ; BANK message
            CALL    MSG          ; Print message in DE
            LD      A,H
            CP      50h          ; 'P'
            JR      NC,LOOP9     ; Work out bank number, 1, 2 or 3.
            LD      A,01h
            JR      LOOP11

LOOP9:      CP      90h
            JR      NC,LOOP10
            LD      A,02h
            JR      LOOP11

LOOP10:     LD      A,03h
LOOP11:     CALL    PRTHX        ; Print A as 2 digit hex, ie. BANK number.
            JR      LOOP7

DLY1S:      PUSH    AF
            PUSH    BC
            LD      C,10
L0324:      CALL    DLY12
            DEC     C
            JR      NZ,L0324
            POP     BC
            POP     AF
            RET
            
           ;-------------------------------------------------------------------------------
           ; END OF MEMORY TEST FUNCTIONALITY
           ;-------------------------------------------------------------------------------

           ;-------------------------------------------------------------------------------
           ; START OF TIMER TEST FUNCTIONALITY
           ;-------------------------------------------------------------------------------

            ; Test the 8253 Timer, configure it as per the monitor and display the read back values.
TIMERTST:   CALL    NL
            LD      DE,MSG_TIMERTST
            CALL    MSG
            CALL    NL
            LD      DE,MSG_TIMERVAL
            CALL    MSG
            LD      A,01h
            LD      DE,8000h
            CALL    TIMERTST1
NDE:        JP      NDE
            JP      ST1X
TIMERTST1: ;DI      
            PUSH    BC
            PUSH    DE
            PUSH    HL
            LD      (AMPM),A
            LD      A,0F0H
            LD      (TIMFG),A
ABCD:       LD      HL,0A8C0H
            XOR     A
            SBC     HL,DE
            PUSH    HL
            INC     HL
            EX      DE,HL

            LD      HL,CONTF    ; Control Register
            LD      (HL),0B0H   ; 10110000 Control Counter 2 10, Write 2 bytes 11, 000 Interrupt on Terminal Count, 0 16 bit binary
            LD      (HL),074H   ; 01110100 Control Counter 1 01, Write 2 bytes 11, 010 Rate Generator, 0 16 bit binary
            LD      (HL),030H   ; 00110100 Control Counter 1 01, Write 2 bytes 11, 010 interrupt on Terminal Count, 0 16 bit binary

            LD      HL,CONT2    ; Counter 2
            LD      (HL),E
            LD      (HL),D

            LD      HL,CONT1    ; Counter 1
            LD      (HL),00AH
            LD      (HL),000H

            LD      HL,CONT0    ; Counter 0
            LD      (HL),00CH
            LD      (HL),0C0H

;            LD      HL,CONT2    ; Counter 2
;            LD      C,(HL)
;            LD      A,(HL)
;            CP      D
;            JP      NZ,L0323H                
;            LD      A,C
;            CP      E
;            JP      Z,CDEF                
            ;

L0323H:     PUSH    AF
            PUSH    BC
            PUSH    DE
            PUSH    HL
            ;
            LD      HL,CONTF    ; Control Register
            LD      (HL),080H
            LD      HL,CONT2    ; Counter 2
            LD      C,(HL)
            LD      A,(HL)
            CALL    PRTHX
            LD      A,C
            CALL    PRTHX
            ;
            CALL    PRNTS
            ;CALL    DLY1S
            ;
            LD      HL,CONTF    ; Control Register
            LD      (HL),040H
            LD      HL,CONT1    ; Counter 1
            LD      C,(HL)
            LD      A,(HL)
            CALL    PRTHX
            LD      A,C
            CALL    PRTHX
            ;
            CALL    PRNTS
            ;CALL    DLY1S
            ;
            LD      HL,CONTF    ; Control Register
            LD      (HL),000H
            LD      HL,CONT0    ; Counter 0
            LD      C,(HL)
            LD      A,(HL)
            CALL    PRTHX
            LD      A,C
            CALL    PRTHX
            ;
            ;CALL    DLY1S
            ;
            LD      A,0C4h      ; Move cursor left.
            LD      E,0Eh      ; 4 times.
L0330:      CALL    DPCT
            DEC     E
            JR      NZ,L0330
            ;
;            LD      C,20
;L0324:      CALL    DLY12
;            DEC     C
;            JR      NZ,L0324
            ;
            POP     HL
            POP     DE
            POP     BC
            POP     AF
            ;
            LD      HL,CONT2    ; Counter 2
            LD      C,(HL)
            LD      A,(HL)
            CP      D
            JP      NZ,L0323H                
            LD      A,C
            CP      E
            JP      NZ,L0323H                
            ;
            ;
            PUSH    AF
            PUSH    BC
            PUSH    DE
            PUSH    HL
            CALL    NL
            CALL    NL
            CALL    NL
            LD      DE,MSG_TIMERVAL2
            CALL    MSG
            POP     HL
            POP     DE
            POP     BC
            POP     AF

            ;
CDEF:       POP     DE
            LD      HL,CONT1
            LD      (HL),00CH
            LD      (HL),07BH
            INC     HL

L0336H:     PUSH    AF
            PUSH    BC
            PUSH    DE
            PUSH    HL
            ;
            LD      HL,CONTF    ; Control Register
            LD      (HL),080H
            LD      HL,CONT2    ; Counter 2
            LD      C,(HL)
            LD      A,(HL)
            CALL    PRTHX
            LD      A,C
            CALL    PRTHX
            ;
            CALL    PRNTS
            CALL    DLY1S
            ;
            LD      HL,CONTF    ; Control Register
            LD      (HL),040H
            LD      HL,CONT1    ; Counter 1
            LD      C,(HL)
            LD      A,(HL)
            CALL    PRTHX
            LD      A,C
            CALL    PRTHX
            ;
            CALL    PRNTS
            CALL    DLY1S
            ;
            LD      HL,CONTF    ; Control Register
            LD      (HL),000H
            LD      HL,CONT0    ; Counter 0
            LD      C,(HL)
            LD      A,(HL)
            CALL    PRTHX
            LD      A,C
            CALL    PRTHX
            ;
            CALL    DLY1S
            ;
            LD      A,0C4h      ; Move cursor left.
            LD      E,0Eh      ; 4 times.
L0340:      CALL    DPCT
            DEC     E
            JR      NZ,L0340
            ;
            POP     HL
            POP     DE
            POP     BC
            POP     AF

            LD      HL,CONT2    ; Counter 2
            LD      C,(HL)
            LD      A,(HL)
            CP      D
            JR      NZ,L0336H                
            LD      A,C
            CP      E
            JR      NZ,L0336H                
            CALL    NL
            LD      DE,MSG_TIMERVAL3
            CALL    MSG
            POP     HL
            POP     DE
            POP     BC
           ;EI      
            RET   
            ;-------------------------------------------------------------------------------
            ; END OF TIMER TEST FUNCTIONALITY
            ;-------------------------------------------------------------------------------
  
            ;--------------------------------------
            ;
            ; Message table
            ;
            ;--------------------------------------             
OKCHECK:    DB      ", CHECK: ", 0Dh
OKMSG:      DB      " OK.", 0Dh
DONEMSG:    DB      11h
            DB      "RAM TEST COMPLETE.", 0Dh
           
BITMSG:     DB      " BIT:  ", 0Dh
BANKMSG:    DB      " BANK: ", 0Dh
MSG_TIMERTST:
            DB      "8253 TIMER TEST", 0Dh, 00h
MSG_TIMERVAL:
            DB      "READ VALUE 1: ", 0Dh, 00h
MSG_TIMERVAL2:
            DB      "READ VALUE 2: ", 0Dh, 00h
MSG_TIMERVAL3:
            DB      "READ DONE.", 0Dh, 00h

            ;--------------------------------------
            ;
            ; Message table - Refer to bank 6 for
            ;                 all messages.
            ;
            ;--------------------------------------

            ; RomDisk, top 8 bytes are used by the control registers when enabled so dont use the space.
            IF      BUILD_ROMDISK = 1
              ALIGN 0EFF8h
              ORG   0EFF8h
              DB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
            ENDIF

            IF      BUILD_SFD700 = 1
              ALIGN 0F000H
            ENDIF

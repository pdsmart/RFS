; the following is only to get the original length of 2048 bytes
ALIGN:     MACRO    ?boundary
               DS       ?boundary - 1 - ($ + ?boundary - 1) % ?boundary, 0FFh
           ENDM

; the following is only to get the original length of 2048 bytes
ALIGN_NOPS:MACRO    ?boundary
               DS       ?boundary - 1 - ($ + ?boundary - 1) % ?boundary, 000h
           ENDM

;
; Pads up to a certain address.
; Gives an error message if that address is already exceeded.
;
PAD:       MACRO ?address
	           IF $ > ?address
		           ERROR "Alignment exceeds %s"; % ?address
	           ENDIF
	           ds ?address - $
	       ENDM

;
; Pads up to the next multiple of the specified address.
;
;ALIGN: MACRO ?boundary
;	ds ?boundary - 1 - ($ + ?boundary - 1) % ?boundary
;	ENDM

;
; Pads to ensure a section of the given size does not cross a 100H boundary.
;
ALIGN_FIT8: MACRO ?size
	           ds (($ + ?size - 1) >> 8) != ($ >> 8) && (100H - ($ & 0FFH)) || 0
	        ENDM

HWSELROM:   MACRO 
                IF BUILD_ROMDISK = 1
                    LD      B,16                           ; If we read the bank control reset register 15 times then this will enable bank control and then the 16th read will reset all bank control registers to default.
HWSEL1:             LD      A,(BNKCTRLRST)
                    DJNZ    HWSEL1                         ; Apply the default number of coded latch reads to enable the bank control registers.
                    LD      A,BNKCTRLDEF                   ; Set coded latch, SDCS high, BBMOSI to high and BBCLK to high which enables SDCLK.
                    LD      (BNKCTRL),A
                    LD      (ROMCTL),A                     ; Save to memory the value in the bank control register - this register is used for SPI etc so need to remember its setting.
                    XOR     A                              ; We shouldnt arrive here after a reset, if we do, select UROM bank 0
                    LD      (BNKSELMROM),A
                    LD      (BNKSELUSER),A                 ; and start up - ie. SA1510 Monitor - this occurs as User Bank 0 is enabled and the jmp to 0 is coded in it.
                ENDIF                                      ; 22 bytes.

                                                           ; MODE_MZ1200 0
                                                           ; MODE_MZ80A  0
                                                           ; MODE_MZ700  1
                                                           ; MODE_MZ80B  2
                                                           ; MODE_MZ800  3
                                                           ; MODE_MZ1500 4
                                                           ; MODE_MZ2000 5
                                                           ; MODE_MZ2200 6
                IF BUILD_SFD700 = 1
                    IN      A,(SFD700_MODE)
                    OR      A
                    LD      A,BNKDEFMROM_MZ80A             ; Setup default MROM for an MZ80A, this is a 4K Window into the UROM at F000.
                    JR      Z, HWSEL11
                    LD      A,BNKDEFMROM_MZ700             ; Setup default MROM for an MZ700, this is a 4K Window into the UROM at F000.
HWSEL11:            OUT     (REG_FXXX),A
                    LD      (ROMBK1),A
                    LD      A,BNKDEFUROM                   ; Setup default UROM, this is a 2K Window into the UROM at E800 and contains the RFS.
                    OUT     (REG_EXXX),A                               
                    LD      (ROMBK2),A
                    NOP
                ENDIF
	        ENDM

HWSELROM2:  MACRO        
                IF BUILD_ROMDISK = 1
                    LD      B,16                           ; If we read the bank control reset register 15 times then this will enable bank control and then the 16th read will reset all bank control registers to default.
HWSEL2:             LD      A,(BNKCTRLRST)
                    DJNZ    HWSEL2                         ; Apply the default number of coded latch reads to enable the bank control registers.
                    LD      A,BNKCTRLDEF                   ; Set coded latch, SDCS high, BBMOSI to high and BBCLK to high which enables SDCLK.
                    LD      (BNKCTRL),A
                    NOP                                    ; Nops to allocate space for missing LD (ROMCTL),A present in first bank.
                    NOP
                    NOP
                    XOR     A                              ; We shouldnt arrive here after a reset, if we do, select UROM bank 0
                    LD      (BNKSELMROM),A
                    LD      (BNKSELUSER),A                 ; and start up - ie. SA1510 Monitor - this occurs as User Bank 0 is enabled and the jmp to 0 is coded in it.
                    NOP                                    ; Nops to allocate space for Bank 0 JP to startup code.
                    NOP
                    NOP
                ENDIF                                      ; 25 bytes.
                IF BUILD_SFD700 = 1
                    IN      A,(SFD700_MODE)
                    OR      A
                    LD      A,BNKDEFMROM_MZ80A             ; Setup default MROM for an MZ80A, this is a 4K Window into the UROM at F000.
                    JR      Z,HWSEL21
                    LD      A,BNKDEFMROM_MZ700             ; Setup default MROM for an MZ700, this is a 4K Window into the UROM at F000.
HWSEL21:            OUT     (REG_FXXX),A
                    LD      A,BNKDEFUROM                   ; Setup default UROM, this is a 2K Window into the UROM at E800 and contains the RFS.
                    OUT     (REG_EXXX),A                               
                    NOP                                    ; Nops to allocate space to match RomDisk block.
                    NOP
                    NOP
                    NOP
                    NOP
                    NOP
                    NOP
                    NOP
                    NOP
                    NOP
                ENDIF
	        ENDM

            ; Macro to select which part of the FlashROM appears in the Monitor ROM 0000:0FFF Window.
            ; On the SFD700 board, for ease of coding as the Monitor ROM doesnt exist but the Floppy ROM F000:FFFF window does,
            ; then on this board, MROM refers to the F000:FFFF window when working with code which is compatible across the RomDisk, SFD700 etc..
HWSELMROM:  MACRO
                IF BUILD_ROMDISK = 1
                    LD      (BNKSELMROM),A
                ENDIF
                IF BUILD_SFD700 = 1
                    OUT     (REG_FXXX),A
                ENDIF
	        ENDM

            ; Macro to perform the in-situ bank switch. RomDisk it is a simple register load, for the SFD700
            ; depending on the target bank, we need to bring in the complimentary FXXX bank as needed.
BNKSWSEL:    MACRO
                IF BUILD_ROMDISK = 1
                    LD      (BNKSELUSER),A
                ENDIF
                IF BUILD_SFD700 = 1
                    OUT     (REG_EXXX),A                   ; Execute active bank switch for E000:EFFF.
                    CP      ROMBANK6                       ; ROMBANK6/7 page in ROM from E300:FFFF
                    JR      C,BNKSWJMP
                    INC     A                              ; FXXX are 4K banks, EXXX are 2K banks.
                    JR      BNKSWJMP2
BNKSWJMP:           LD      A,(ROMBK1)                     ; All other banks place the current active ROM into F000:FXXX space.
BNKSWJMP2:          OUT     (REG_FXXX),A
                ENDIF
            ENDM

            ; Macro to return from a bank switch.
BNKSWSELRET:MACRO
                IF BUILD_ROMDISK = 1
                    LD      (BNKSELUSER),A
                ENDIF
                IF BUILD_SFD700 = 1
                    OUT     (REG_EXXX),A                   ; Execute active bank switch.
                    LD      A,(ROMBK1)                     ; Ensure the current active ROM is switched to the F000:FXXX space.
                    OUT     (REG_FXXX),A
                ENDIF
	        ENDM

            ; Macro to select which part of the FlashROM appears in the User ROM E800:EFFF window.
HWSELUROM:  MACRO
                IF BUILD_ROMDISK = 1
                    LD      (BNKSELUSER),A
                ENDIF
                IF BUILD_SFD700 = 1
                    OUT     (REG_EXXX),A
                ENDIF
	        ENDM

            ; Macro which is generally specific to the RomDisk, the code enables the Bank paging registers.
SETCODELTCH:MACRO
                IF BUILD_ROMDISK = 1
                    LD      A,BNKCTRLDEF                   ; Set coded latch, SDCS high, BBMOSI to high and BBCLK to high which enables SDCLK.
                    LD      (ROMCTL),A                     ; Save to memory the value in the bank control register - this register is used for SPI etc so need to remember its setting.
                ENDIF
                IF BUILD_SFD700 = 1
                    NOP
                    NOP
                    NOP
                    NOP
                    NOP
                ENDIF
	        ENDM

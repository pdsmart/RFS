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
;                   May 2020  - Bank switch changes with release of v2 pcb with coded latch. The coded
;                               latch adds additional instruction overhead as the control latches share
;                               the same address space as the Flash RAMS thus the extra hardware to
;                               only enable the control registers if a fixed number of reads is made
;                               into the upper 8 bytes which normally wouldnt occur. Caveat - ensure
;                               that no loop instruction is ever placed into EFF8H - EFFFH.
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

            ORG     0CF00H

COUNT_C:    DS      virtual 1        ; Counter C
ADDR:      
ADDR_LO:    DS      virtual 1 
ADDR_HI:    DS      virtual 1
ASM_ADDR:   DS      virtual 8        ; Assembler Destination address
ASM_BUF:    DS      virtual 16       ; 16 byte ASM Input Buffer
OUT_BUF:    DS      virtual 4        ; 4 byte test buffer(last part of ASM_BUF)  
INS_BUF:    DS      virtual 4        ; 4 Byte Instruction Buffer
PARM_BUF:   DS      virtual 7        ; 7 Byte Parm Buffer
VAL_BUF:                             ; 5 Byte Value Buffer
VAL_BUF_HI: DS      virtual 2        ; 2 Hi Bytes in Value Buffer
VAL_BUF_LO: DS      virtual 2        ; 2 Lo Bytes in Value Buffer
            DS      virtual 1
SRC_ADDR:   DS      virtual 2        ; 2 byte source pointer storage
DES_ADDR:   DS      virtual 2        ; 2 byte destination pointer storage
BLK_ADDR:   DS      virtual 2        ; 2 byte table block pointer storage
ROW_ADDR:   DS      virtual 2        ; 2 byte table row pointer storage
BLK_NUM:    DS      virtual 1        ; 1 byte Block Number
BLK_SIZE:   DS      virtual 1        ; 1 byte Block Size
ROW_NUM:    DS      virtual 1        ; 1 byte Row Number  
ML_BUF:     DS      virtual 2        ; 3 byte ML buffer
ML_BTCOUNT: DS      virtual 1        ; Last byte of ML buffer(byte count)
VAL_LO:     DS      virtual 1        ; Converted value LO
VAL_HI:     DS      virtual 1        ; Converted value Hi


            ORG     0E000H
            ALIGN   0E300H

            IF      BUILD_SFD700 = 1
             ;******************************************************************
             ; DASM_MAIN     Z80 Dis-Assembler
             ; Based on tables used by TASM for the Z80 target 
             ;******************************************************************
DASM_MAIN:   LD     B,(VAL_HI-COUNT_C)+1
             LD     HL,COUNT_C
             XOR    A
             CALL   MEMSET
             ;
             CALL   HLHEX            ; Get starting address.
             JP     C,DASM_ERR
             LD     (SRC_ADDR),HL    ; Save in SRC_ADDR & SRC_ADDR+1
             INC    DE
             INC    DE
             INC    DE
             INC    DE
             
             LD     BC,0h            ; Add 1 To Start Address  BC=0000
             SCF                     ; C=1
             ADC    HL,BC            ; Add HL+BC+C to HL(FFFF will overflow to 0000)  
             RET    Z                ; Exit if xFFFF was entered
             
             CALL   HLHEX            ; get end address 
             LD     (ADDR_LO),HL
             JP     NC,DASM_UENDAD   ; User entered a non-zero address(use it)

             XOR    A
             LD     (ASM_ADDR),A     ;NOT Using End Address - Just do 16 rows
             LD     (ASM_ADDR+1),A   ;Set ASM_ADDR=x0000
             
             LD     A,10h
             LD     (COUNT_C),A      ; Set Row Counter = 16
             JP     DASM_UROWCT
             
DASM_UENDAD: LD     A,0FFh           ; End Address Was entered - Use It
             LD     (COUNT_C),A      ; Set Row Counter = xFF           
             
             LD     HL,(ADDR_LO)
             LD     (ASM_ADDR),HL
DASM_UROWCT: LD     HL,(SRC_ADDR)
             LD     (ADDR_LO),HL
             
             ; ** Print CR, LF, ADDR_HI, ADDR_LO (in HEX), space
DASM_LOOP1:  CALL   NL               ; Print CR & LF
             LD     A,(ADDR_HI)      ; Print Address Buffer
             CALL   PRTHX
             LD     A,(ADDR_LO)
             CALL   PRTHX
             CALL   PRNTS            ; Print Space
             
             LD     HL,ASM_BUF       ; Clear ASM_BUF, INS_BUF, PARM_BUF & VAL_BUF
             LD     A,020H
             LD     B,26             ; (Set to all spaces)
DASM_FILL:   LD     (HL),A
             INC    HL
             DEC    B
             JP     NZ,DASM_FILL
             
             ; ** Get 2 bytes from memory pointed to by ADDR_LO & ADDR_HI
             LD     HL,(ADDR_LO)     ; Address ->HL
             LD     A,(HL)           ; First Byte ->A
             LD     (ML_BUF),A       ; Store in ML_BUF Byte 0

             INC    HL
             LD     A,(HL)           ; Second Byte ->A
             LD     (ML_BUF+1),A     ; Store in ML_BUF Byte 1
             
             CALL   DASMBITINST      ; Is This a BIT,SET or RES Inst.?
             JP     NZ,DASM_FIND     ; NO=Do regular search
             CALL   DSMFINDOPCD      ; Search For Matching BIT,SET,RES OP Code
             JP     Z,DASM_ERR       ; NOT FOUND - Error Message
             CALL   DASMGETINST      ; Copy 4 byte  Assembler Inst. to ASM_BUF
             JP     DASM_JUSTV       ; VAL_BUF has already been populated            
             
DASM_FIND:   CALL   DSMFINDOPCD      ; Search For Matching OP Code
             JP     Z,DASM_ERR       ; NOT FOUND - Error Message
             
             CALL   DASMGETINST      ; Copy 4 byte  Assembler Inst. to ASM_BUF
             
             ; ** Are Data Bytes expected? YES=COPY TO VAL_BUF
             LD     A,'0'
             LD     (VAL_BUF_HI),A   ; Set VAL_BUF_HI="00"
             LD     (VAL_BUF_HI+1),A
             LD     A,0
             LD     (VAL_BUF_LO),A   ; Set VAL_BUF_LO=NULL(NO DATA indicator)
             
             CALL   DASMGETVAL       ; Get 1 or 2 value bytes from memory
             
DASM_JUSTV:  CALL   DSMLFJVAL        ; Left justify VAL_BUF(Trim leading zeros)
             
             CALL   DASMGETPARM      ; Build parameter string with value data

             CALL   DSMRTRIMASM      ; Trim trailing spaces from ASM_BUF
             
             LD     A,0Fh            ; Output Memory Bytes and Advance Address Pointer
             LD     C,A
             LD     HL,(ADDR_LO)     ; Address ->HL
             LD     A,(ML_BTCOUNT)   ;Get Total Byte count from lookup table
             LD     B,A              ;Save in B
DASM_MEMOUT: LD     A,(HL)
             CALL   PRTHX
             CALL   PRNTS            ; Print Space
             INC    HL               ; Adjust memory pointer and byte count
             DEC    C
             DEC    C
             DEC    C
             DEC    B
             JP     NZ,DASM_MEMOUT   ; DONE?  NO=Continue
             LD     (ADDR_LO),HL     ; Save New Memory Address
             
DASM_SPCOUT: CALL   PRNTS            ; Pad with spaces to 15 bytes             
             DEC    C
             JP     NZ,DASM_SPCOUT   ; DONE?  NO=Continue
                                      
             LD     HL,ASM_BUF       ; Send Assembly string 
             EX     DE,HL
             LD     HL,PRTSTR
             CALL   BKSW7to6
             
             LD     A,(COUNT_C)      ; Get Row Count
             CP     0FFh             ; Using End Address?
             JP     Z,DASM_CKEADR             
             DEC    A                ; Decrement
             RET    Z                ; DONE? - YES = Exit
             LD     (COUNT_C),A      ; NO= Save Row Count 
             JP     DASM_LOOP1       ; Continue...
             
DASM_CKEADR: LD     HL,(ASM_ADDR)    ; Get End Address
             LD     BC,(ADDR_LO)     ; Get Memory Address pointer
             SBC    HL,BC            ; Subtract End from Current
             RET    M                ; If resulte negative - Exit
             JP     DASM_LOOP1       ; Otherwise Continue... 

DASM_ERR:    LD     DE,MSGNOTFND
             LD     HL,PRINTMSG
             CALL   BKSW7to6
             RET
             
             ;******************************************************************
             ; Dis-Assembler Routines
             ;******************************************************************

             ;******************************************************************
             ; ISVALBUF0
             ; Return Z=1 if VAL_BUF contains a single '0' followed by a NULL  
             ;******************************************************************
ISVALBUF0:   LD     A,(VAL_BUF)
             CP     '0'
             JP     NZ,IZVBFZ_RET
             LD     A,(VAL_BUF+1)
             CP     0
IZVBFZ_RET:  RET
                  
             ;******************************************************************
             ; ISIXIYPRM
             ; Is parameter (IX*) or (IY*)  
             ;******************************************************************
ISIXIYPRM:   PUSH   BC
             PUSH   HL
             LD     C,0              ; C = match counter
             LD     B,7              ; B = byte counter
             LD     HL,(ROW_ADDR)    ; HL = Row data pointer
ISIX_LOOP:   LD     A,(HL)           ; Get a byte from row
             CP     '('              ; If '(', 'I' or '*' Increment C
             JP     Z,ISIX_CKI 
             CP     '*'
             JP     Z,ISIX_COUNT 
             JP     ISIX_NEXT        ;None of the above then continue
             
ISIX_CKI:    INC    HL               ;Check for '(' followed by 'I'
             LD     A,(HL)           ;Get byte after the '(' just found
             CP     'I'              ;Is it = 'I'?
             JP     Z,ISIX_COUNT     ;Yes=Count the match
             JP     ISIX_NEXT2       ;No = Continue
             
ISIX_COUNT:  INC    C
ISIX_NEXT:   INC    HL               ; Advance row data pointer
ISIX_NEXT2:  DEC    B                ; Decrement byte count
             JP     NZ,ISIX_LOOP     ; DONE?  NO = Continue
             LD     A,C              ; Get match count
             CP     2                ; If = 2 Return Z=1 otherwise Z=0
             POP    HL
             POP    BC
             RET

             ;******************************************************************
             ; IS_DIGIT
             ;  
             ; RETURN Z=1 if A is 'A'-'F' otherwise Z=0 (A is unchanged )
             ; NOTE: A MUST be a non-zero ASCII Digit 
             ;******************************************************************
IS_DIGIT:    CALL   ISDECDIGIT       ; Is it '0'-'9' 
             JP     Z,IS_DIG_EXIT    ; YES=EXIT with Z=1

             CALL   ISHEXDIGIT       ; test for 'A'-'F' and return
IS_DIG_EXIT: RET

             ;******************************************************************
             ; ISHEXDIGIT
             ;  
             ; RETURN Z=1 if A is 'A'-'F' otherwise Z=0 (A is unchanged)
             ; NOTE: A MUST be a non-zero ASCII Digit  
             ;******************************************************************
ISHEXDIGIT:  CP      'A'             ; is A <'A'?
             JP      M,ISHEXD_EXIT   ; YES=just exit Z=0 
             CP      'G'             ; is A <='F'?
             JP      M,ISHEXD_ZRET   ; YES=return Z=1
             JP      ISHEXD_EXIT     ; otherwise return Z=0
             
ISHEXD_ZRET: CP      A               ; Set Z=1  and Return               
             RET
                              
ISHEXD_EXIT: CP      0               ; Set Z=0  and Return
             RET

             ;******************************************************************
             ; ISDECDIGIT
             ;  
             ; RETURN A=1 if A is '0'-'9' otherwise Z=0 (A is unchanged)
             ; NOTE: A MUST be a non-zero ASCII Digit 
             ;******************************************************************
ISDECDIGIT:  CP      '0'             ; is A <'0'?
             JP      M,ISDECD_EXIT   ; YES= exit with Z=0 
             CP      03Ah            ; is A <='9'?
             JP      M,ISDECD_ZRET   ; YES=return Z=1
             JP      ISDECD_EXIT     ; otherwise just exit with Z=0
            
ISDECD_ZRET: CP      A               ; Set Z=1  and Return
             RET

ISDECD_EXIT: CP      0               ; Set Z=0  and Return
             RET

             ;******************************************************************
             ; MEMSET
             ; HL=src  B=COUNT A=FILL BYTE 
             ; COPY A to (HL) for B bytes 
             ;******************************************************************
MEMSET:      LD      (HL),A
             INC     HL 
             DEC     B
             JP      NZ, MEMSET
             RET

             ;******************************************************************
             ; RTJUSTVAL
             ; Shift bytes in VAL_BUF right until left padded with '0's  
             ;******************************************************************
RTJUSTVAL:   PUSH    IX
             PUSH    BC
             LD      IX,VAL_BUF
             LD      B,05h           ; B=MAX search count 5
             
RTJVAL_LOOP: LD      A,(IX+3)        ; Get last byte from VAL_BUF
             CP      ' '             ; Is It SPACE?
             JP      NZ,RTJVAL_EXIT  ; Exit
             LD      A,(IX+2)        ; Shift 3 bytes left 1 positiom
             LD      (IX+3),A
             LD      A,(IX+1) 
             LD      (IX+2),A
             LD      A,(IX+0) 
             LD      (IX+1),A
             LD      A,'0'           ; Pad first position with '0' 
             LD      (IX+0),A
             DEC     B
             JP      NZ,RTJVAL_LOOP
             
RTJVAL_EXIT: POP     BC
             POP     IX
             RET
 
             ;******************************************************************
             ; DSMRTRIMASM
             ; Trim trailing spaces from ASM_BUF  
             ;******************************************************************
DSMRTRIMASM: PUSH    BC
             PUSH    HL 
             LD      B,0Fh           ; B=MAX loop count 15
             LD      HL,ASM_BUF+15   ; HL=tail of ASM_BUF
             
DSMRTA_LOOP: LD      A,(HL)          ; Get a byte from VAL_BUF
             CP      ' '             ; Is It ' '?
             JP      NZ,DSMRTA_EXIT  ; No = Exit
             LD      A,000h          ; A=FFh
             LD      (HL),A          ; Store in ASM_BUF 
             DEC     HL              ; Decrement ASM_BUF pointer
             DEC     B               ; Decrement byte count
             JP      NZ,DSMRTA_LOOP  ; Done? No=Continue
             
DSMRTA_EXIT: POP     HL              ; Restore BC, HL & Exit
             POP     BC
             RET

             ;******************************************************************
             ; DSMLFJVAL
             ; Shift bytes in VAL_BUF left until non-zero char is encountered  
             ;******************************************************************
DSMLFJVAL:   PUSH    BC
             LD      B,03h           ; B=MAX loop count 3
             
DSMLFJ_LOOP: LD      A,(VAL_BUF)     ; Get 1st byte from VAL_BUF
             CP      '0'             ; Is It '0'?
             JP      NZ,DSMLFJ_EXIT  ; No = Exit
             LD      A,(VAL_BUF+1)   ; Shift 3 bytes left 1 positiom
             LD      (VAL_BUF),A
             LD      A,(VAL_BUF+2) 
             LD      (VAL_BUF+1),A
             LD      A,(VAL_BUF+3) 
             LD      (VAL_BUF+2),A
             LD      A,0             ;Set last position to NULL 
             LD      (VAL_BUF+3),A
             DEC     B
             JP      NZ,DSMLFJ_LOOP
             
DSMLFJ_EXIT: POP     BC
             RET

             ;******************************************************************
             ; BYTE2ASCII
             ; Convert Hex Value of A to 2 Hex ASCII bytes in HL 
             ; NOTE: L=MSB, H=LSB since strings are usually Hi,Lo eg:"35"
             ; if we use LD (address),HL  then address = L and address+1 = H
             ;******************************************************************
BYTE2ASCII:  LD      H,A             ;Save A in H
             RRA                     ;Shift Hi 4 Bits to Low 4 Bits 
             RRA
             RRA
             RRA
             CALL    NIB_TOHEX
             LD      L,A             ; MSB->L
             LD      A,H             ;Restore A from H  
             CALL    NIB_TOHEX
             LD      H,A             ; LSB->H
             RET

             ;******************************************************************
             ; NIB_TOHEX
             ; Convert Lo 4 bits of A to ASCII of it's HEX value (0-9 or A-F)
             ;******************************************************************
NIB_TOHEX:   AND     0Fh             ;Mask Hi 4 Bits
             CP      0Ah             ; is it 9 or less?
             JP      M,ADD_30X  
             ADD     A,07h
ADD_30X:     ADD     A,030h     
             RET
 
             ;******************************************************************
             ; DASMBITINST
             ; ML_BUF contains 2 bytes from current memory location.
             ; If Byte1=0xCB and (Byte2 & 0xC0) > 0 This is a BIR, SET or RES inst.
             ; Pull the "Bit" value from Byte2 and populate VAL_LO 
             ; Mask the "Bit" indicator bits from byte 2 and do the lookup
             ;******************************************************************
DASMBITINST: LD      B,0CBh          ;B=0xCB 
             LD      A,(ML_BUF)      ;A=ML_BUF Byte1
             CP      B               ;Compare A with B
             JP      NZ,DASMBIT_RET  ;NoMatch Exit with Z=0 
             LD      A,(ML_BUF+1)    ;Get Byte2
             AND     0C0h            ;AND with 0xCO
             JP      NZ,DASMBIT_VAL  ;Not Zero then this is a BIT,SET or RES
             LD      A,0FFh          ;Otherwise...
             JP      DASMBITRETN     ;Return with Z=0  
       
DASMBIT_VAL: LD      A,(ML_BUF+1)    ;Get Byte2
             AND     038h            ;Mask All but 'BIT#' bits
             RRA                     ;Shift Right 3x
             RRA
             RRA
             AND     07h
             PUSH    HL              ;Save Address Pointer
             CALL    BYTE2ASCII      ;Convert A to 2 ASCII Bytes in HL
             LD      (VAL_BUF_LO),HL ;Store 2 bytes in VAL_BUF_LO
             LD      A,'0'
             LD      (VAL_BUF_HI),A 
             LD      (VAL_BUF_HI+1),A;Store '00' in VAL_BUF_HI
             POP     HL              ;Restore Address pointer              
             LD      A,(ML_BUF+1)    ;Get Byte2
             AND     0C7h            ;AND with 0xC7
             LD      (ML_BUF+1),A    ;Replace MLByte2  
DASMBITRETZ: LD      A,0             ;Return with Z=1
DASMBITRETN: CP      0               ;Return with Z=0
DASMBIT_RET: RET                     
 
             ;******************************************************************
             ; DASMGETPARM
             ; Build the Assembly instruction parameter string from bytes in 
             ; the found row in the lookup table. 
             ; Assumes justified value bytes are already in VAL_BUF if required.
             ; NOTE: ROW_ADDR is set by successful find by DSMFINDOPCD
             ;******************************************************************
DASMGETPARM: LD      B,7             ;Byte Counter = 7 
             LD      IY,ASM_BUF+5;   ;IY=Target Address (ASM_BUF+5)
             LD      IX,(ROW_ADDR)   ;IX=Source Address (Table Row Address)
DASM_GETPRM: LD      A,(IX)          ;Get Parm Byte 
             CP      '*'             ;Is it a '*'? 
             JP      NZ,DASM_SAVPAR  ;NO=Save Parm byte
             
             CALL    ISIXIYPRM       ;Is this an (IX*) ot (IY*) Parm?
             JP      NZ,DASM_MOVVAL  ;NO=Just move the value bytes
             CALL    ISVALBUF0       ;Is VAL_BUF="0"
             JP      Z,DASM_NXTPR2   ;YES=Skip move of value bytes
             LD      A,'+'
             LD      (IY),A          ;Store a '+'
             INC     IY              ;Advance Target Address & move value bytes
             
DASM_MOVVAL: LD      C,4             ;Byte count=4
             LD      HL,VAL_BUF      ;HL = VAL_BUF
DASM_MVLOOP: LD      A,(HL)          ;Get a value byte 
             CP      0               ;NULL?
             JP      Z,DASM_SAVH     ;YES=DONE goto Save 'h' & continue  
             LD      (IY),A          ;Store the value char
             INC     IY              ;Advance destination (ASM_BUF) pointer
             INC     HL
             DEC     C
             JP      NZ,DASM_MVLOOP
             
DASM_SAVH:   LD      A,'h'           ;Load the 'h'
DASM_SAVPAR: LD      (IY),A          ;Store parm char
DASM_NXTPAR: INC     IY              ;Advance Target Address
DASM_NXTPR2: INC     IX              ;Advance Source Address
             DEC     B               ;Count Source bytes
             JP      NZ,DASM_GETPRM  ;DONE? NO=Continue
             RET                     ;YES= Exit
             
             ;******************************************************************
             ; DASMGETVAL
             ; Copy 1 or 2 bytes of value data from memory to VAL_BUF 
             ; Data value are converted to ASCII HEX chars in VAL_BUF
             ; NOTE: ML_BTCOUNT is set by successful find by DSMFINDOPCD
             ;******************************************************************
DASMGETVAL:  LD      HL,(ADDR_LO)    ;Get memory Address->HL
             LD      A,(ML_BTCOUNT)  ;Get Total Byte count from lookup table
             LD      B,A             ;Save in B
             DEC     B               ;Skip 1 Byte count
             INC     HL              ;Skip 1 byte in memory             
             LD      A,(ML_BUF+1)    ;Is this a 2 byte instruction?
             CP      0
             JP      Z,DASM_CKBTCNT  ;NO= check final byte count
             DEC     B               ;Decrement byte count
             INC     HL              ;Adjust memory pointer
DASM_CKBTCNT:LD      A,0            
             CP      B               ;Is byte count=0?
             JP      Z,DASM_GVEXIT   ;YES=NO Data Bytes expected - Exit
             LD      A,(HL)          ;Get 1st Data Byte from memory
             PUSH    HL              ;Save Address Pointer
             CALL    BYTE2ASCII      ;Convert A to 2 ASCII Bytes in HL
             LD      (VAL_BUF_LO),HL ;Store 2 bytes in VAL_BUF_LO
             POP     HL              ;Restore Address pointer
             DEC     B
             LD      A,0            
             CP      B               ;Is byte count=0?
             JP      Z,DASM_GVEXIT   ;YES=NO More Data Bytes expected - Exit
             INC     HL              
             LD      A,(HL)          ;Get 2nd Data Byte from memory
             CALL    BYTE2ASCII      ;Convert A to 2 ASCII Bytes in HL
             LD      (VAL_BUF_HI),HL ;Store 2 bytes in VAL_BUF_LO
DASM_GVEXIT: RET
             
             ;******************************************************************
             ; DASMGETINST
             ; Copy 4 byte Assembler Instruction to ASM_BUFF
             ; NOTE: BLK_ADDR is set by successful find by DSMFINDOPCD
             ;******************************************************************
DASMGETINST: LD      HL,(BLK_ADDR)   ; Block Header Row Address ->HL
             LD      DE,ASM_BUF      ; ASM_BUF address->DE
             LD      B,04h           ; Byte Count=4
DASM_MOVINS: INC     HL              ; Inc Block Header data pointer
             LD      A,(HL)          ; Get 1 byte from Block Header
             LD      (DE),A          ; Save to ASM_BUF 
             INC     DE              ; Inc destination (ASM_BUF) pointer
             DEC     B               ; Dec byte count
             JP      NZ,DASM_MOVINS  ;DONE? No=Continue
             RET                     ; YES=Exit 
             
             ;******************************************************************
             ; DSMFINDOPCD
             ; ML_BUF contains 2 bytes from current memory location.
             ; Search opcode table for a matching opcode
             ; Return with BLK_ADDR=block header address, ROW_ADDR=found row address
             ; ML_BYCOUNT=a non-zero count if match was found  
             ;******************************************************************
DSMFINDOPCD: PUSH    BC
             LD      IX,OPCD_TABLE   ;Set IX=Table Start Address
DSMFN_LOOP1: LD      A,(IX+0)
             CP      '#'             ;Is Row Byte0='#'?
             JP      NZ,DSMFNCKBT1   ;YES=SAVE IX->BLK_ADDR
             LD      (BLK_ADDR),IX
             JP      DSMFN_NXTROW
             
DSMFNCKBT1:  LD      A,(ML_BUF)      ;IS ML_BUF0=(CB,DD,ED or FD)? 
             CP      0CBh
             JP      Z,DSMFN_CKBT2
             CP      0DDh
             JP      Z,DSMFN_CKBT2
             CP      0EDh
             JP      Z,DSMFN_CKBT2
             CP      0FDh
             JP      Z,DSMFN_CKBT2
             LD      C,(IX+7)        ; If ML_BUF0 is NOT one of the above
             CP      C               ; Compare with row byte7  
             JP      NZ,DSMFN_NXTROW ; NO=Next Row
             LD      A,0              
             LD      C,(IX+8)        ; Get Row Byte8
             CP      C               ; Is it Zero
             JP      Z,DSMFN_MATCH   ; YES=MATCH! 
             JP      DSMFN_NXTROW    ; NO=Next Row
             
DSMFN_CKBT2: LD      C,(IX+8)        ;If ML_BUF0=(CB,DD,ED or FD)?
             CP      C               ; Compare with row byte8
             JP      NZ,DSMFN_NXTROW ; NO=Next Row
             LD      A,(ML_BUF+1)    ; YES=Check Next Byte
             LD      C,(IX+7)        ; Combare with row byte7
             CP      C   
             JP      Z,DSMFN_MATCH   ;   YES=MATCH!                      
                                   
DSMFN_NXTROW:LD      BC,000Ah        ; Add 10 to IX and KEEP LOOKING
             ADD     IX,BC
             LD      A,(IX+5)        ; End Of Lookup Table?
             CP      0
             JP      NZ,DSMFN_LOOP1  ; NO=Keep Looking otherwise EXIT
 
DSMFN_MATCH: LD      (ROW_ADDR),IX   ; Save IX->ROW_ADDR
             LD      A,(IX+8)
             LD      (ML_BUF+1),A    ; Save row byte8 ->ML_BUF1
             LD      A,(IX+9)
             LD      (ML_BTCOUNT),A  ; Save byte count->ML_BYCOUNT
             CP      0               ; Set Z flag if NOT FOUND  
             POP     BC
             RET
             
             ;******************************************************************
             ; END  DIS_MAIN
             ;******************************************************************

             ;******************************************************************
             ; ASM_MAIN  Z80 Assembler
             ; Based on tables used by the TASM for the Z80 target
             ;******************************************************************
ASM_MAIN:    CALL    HLHEX           ; Print "Enter Address:" and get 4 hex bytes
             JP      C,DASM_ERR
             LD      (ADDR),HL
             
             ; ** Print CR, LF, ADDR_HI, ADDR_LO (in HEX), space
ASM_LOOP1:   CALL    NL              ; Print CR & LF
             LD      A,(ADDR_HI)     ; Print Address Buffer
             CALL    PRTHX
             LD      A,(ADDR_LO)
             CALL    PRTHX
             CALL    PRNTS           ; Print Space
             
             LD      HL,ASM_BUF      ; Clear ASM_BUF, INS_BUF, PARM_BUF & VAL_BUF
             LD      B,30h
             CALL    MEMSET
              
             LD      DE,BUFER        ; Use the SA1510 input buffer, it is larger and free format.
             CALL    GETL            
             CALL    HLHEX           ; Check if the address is present, if it is, update address as user may have changed it.
             JR      C,ASM_LOOP3
             LD      (ADDR),HL
ASM_LOOP3:   LD      BC,01005H
             LD      DE,BUFER+5      ; Skip memory address.
             LD      HL,ASM_BUF
             CALL    GETSTR
             LD      A,0C2H          ; Put cursor back to end of input line. Need to use display control for scrolling.
             CALL    DPCT            ; Cursor up.

             ; Clear the line, could have old data on it.
             LD      A,(SCRNMODE)
             LD      B,39
             OR      A
             JR      Z,ASM_LOOP4
             LD      B,79
ASM_LOOP4:   CALL    PRNTS
             DJNZ    ASM_LOOP4

             ; Reprint the line, removing leading white space.
             LD      HL,(DSPXY)
             LD      L, 0
             LD      (DSPXY),HL
             LD      A,(ADDR_HI)     ; Print Address Buffer
             CALL    PRTHX
             LD      A,(ADDR_LO)
             CALL    PRTHX
             CALL    PRNTS           ; Print Space
             LD      DE,ASM_BUF
ASM_LOOP5:   LD      A,(DE)
             CP      000H
             JR      Z,ASM_LOOP6
             CALL    PRNT
             INC     DE
             JR      ASM_LOOP5

ASM_LOOP6:   LD      HL,(DSPXY)
             LD      L, 22
             LD      (DSPXY),HL      ; To end of instruction.

             LD      A,(ASM_BUF)     ; Check 1st byte of ASM_BUF
             CP      0               ; Nothing was entered (QUIT) 
             JP      Z,ASM_EXIT      ; Just exit
             
;ASM_LOOP2:  CALL    PRNTS           ; print spaces (16-input length from B)
;            INC     C
;            LD      A,C
;            CP      0Fh
;            JP      M,ASM_LOOP2             
            
ASM_CPYINS:  LD      DE,INS_BUF   
             LD      HL,ASM_BUF
             CALL    CPY2SPC         ; Copy the instruction from ASM_BUF to INST_BUF 
             CALL    SKIPSPC         ; find the start of the parm. bytes
            
             LD      BC,PARM_BUF   
             CALL    PADWSPC         ; Pad the instruction buffer to 4 bytes
            
             ;**** Process the input parameter *****
             LD      A,10h
             LD      B,A             ; Load byte counter =16 
GET_NEXTASM: LD      A,(HL)          ; Get 1 byte from ASM_BUF
             CP      0               ; if we reached the end of input?
             JP      Z,ASMLOOPEXIT   ; just exit
             CALL    ISFLAGORNUM     ; Is it $,+,# or 0-9?
             JP      NZ,SAVE_ASMCHR
             CALL    ASMGETVAL       ; Extract the numbers to VAL_BUF
             LD      A,'*'           ; Load PARM_BUF with a '*'
             LD      (DE),A          
             INC     DE              ; Advance dest. pointer
             LD      A,(HL)          ; Get next non-number byte from ASM_BUF
 
SAVE_ASMCHR: CP      0               ; if we reached the end while in getval()?
             JP      Z,ASMLOOPEXIT   ; just exit
             LD      (DE),A          ; Otherwise store the byte
             INC     DE              ; Advance dest. pointer
             INC     HL              ; Advance src. pointer
             DEC     B
             JP      NZ,GET_NEXTASM
             
ASMLOOPEXIT: LD      BC,VAL_BUF   
             CALL    PADWSPC         ; Pad the parm buffer to 7 bytes
            
             LD      (SRC_ADDR),HL   ; Save HL & DE
             LD      (DES_ADDR),DE
            
             CALL    ASMFINDINST     ; Find Instruction in table
             LD      A,(BLK_SIZE)    ; Got a match? YES=search for a parameter match
             CP      0
             JP      NZ,ASM_FINDPRM   
ASM_ERR_INS: LD      DE,MSGNOINSTR
             LD      HL,PRINTMSG
             CALL    BKSW7to6
             JP      ASM_LOOP1       ; Get another line of ASM input... 
             
ASM_FINDPRM: CALL    ASMFINDPARM     ; Look for matching parameter pattern
             LD      A,(ML_BUF+2)    ; Found one? NO=ERROR 
             CP      0               
             JP      NZ,ASMOUTML
             LD      DE,MSGNOPARAM
             LD      HL,PRINTMSG
             CALL    BKSW7to6
             JP      ASM_LOOP1       ; Get another line of ASM input... 
            
            
ASMOUTML:    CALL    RTJUSTVAL       ; Right Justify VAL_BUF
            
             LD      DE,VAL_BUF_HI   ; Convert 4 ASCII Chars in VAL_BUF to 2 values
             CALL    HLHEX
             JR      C, ASM_ERR_INS  ; Couldnt convert the number.
             LD      A,H
             LD      (VAL_HI),A
             LD      A,L
             LD      (VAL_LO),A

             ;; Populate OUT_BUF with ML output             
             LD      IX,OUT_BUF
             LD      A,(ML_BUF+1)
             CP      0
             JP      Z,ASMNOBYTE2
             LD      (IX),A
             INC     IX
             CP      0CBh            ; Is this a BIT,SET or RES Inst?
             JP      NZ,ASMNOBYTE2   ; NO=Continue
             LD      A,(ML_BUF)      ; YES=Check 1st ML byte
             AND     0C0h            ; Are Bits 7 or 6 are set?
             JP      Z,ASMNOBYTE2    ; NO=Continue
             LD      A,(ML_BUF)      ; YES=Combine Val with ML_BUF byte1
             LD      B,A
             LD      A,(VAL_LO)
             SLA     A
             SLA     A
             SLA     A
             AND     38h
             OR      B
             LD      (ML_BUF),A
             
ASMNOBYTE2:  LD      A,(ML_BUF)
             LD      (IX),A
             INC     IX
            
             LD      A,(VAL_LO)
             LD      (IX),A
             INC     IX 
             LD      A,(VAL_HI)
             LD      (IX),A

             ;; *** Move ML code(s) to target address,  *** 
             ;; *** print them and adjust pointer       ***      
             ;CALL    PRNTS
             ;CALL    PRNTS
             ;CALL    PRNTS
             ;CALL    PRNTS

ASM_TOMEM:   LD      A,(ML_BTCOUNT)  ; Load Byte Count ->B
             LD      B,A
             LD      IX,OUT_BUF      ; Load IX with OUT_BUF address 
ASM_TOMEM1:  LD      HL,(ADDR_LO)    ; Load HL with Target Address
             LD      A,(IX)          ; Get Byte to Move
             LD      (HL),A          ; Store at target address
             CALL    PRTHX           ; Print it
             CALL    PRNTS           ; Print 1 space
             INC     HL              ; Advance Target Pointer
             LD      (ADDR_LO),HL    ; Save in ADDR_LO & HI
             INC     IX              ; Advance ML_BUF pointer
             DEC     B               ; Decrement byte counter
             JP      NZ,ASM_TOMEM1   ; Done? NO=Continue
             JP      ASM_LOOP1       ; Get another line of ASM input...       
             
ASM_EXIT:    RET        	     
             ;******************************************************************
             ;  END of ASM_MAIN
             ;******************************************************************             

             ; Ensure we fill the ROM frmo E300:E7FF
             ALIGN  UROMADDR
            ENDIF                    ; SFD700
             

            ;===========================================================
            ;
            ; USER ROM BANK 7 - Memory and timer test utilities.
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
BKSW7to0:   PUSH    AF
            LD      A, ROMBANK7                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK0                                              ; Required bank to call.
            JR      BKSW7_0
BKSW7to1:   PUSH    AF
            LD      A, ROMBANK7                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK1                                              ; Required bank to call.
            JR      BKSW7_0
BKSW7to2:   PUSH    AF
            LD      A, ROMBANK7                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK2                                              ; Required bank to call.
            JR      BKSW7_0
BKSW7to3:   PUSH    AF
            LD      A, ROMBANK7                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK3                                              ; Required bank to call.
            JR      BKSW7_0
BKSW7to4:   PUSH    AF
            LD      A, ROMBANK7                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK4                                              ; Required bank to call.
            JR      BKSW7_0
BKSW7to5:   PUSH    AF
            LD      A, ROMBANK7                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK5                                              ; Required bank to call.
            JR      BKSW7_0
BKSW7to6:   PUSH    AF
            LD      A, ROMBANK7                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK6                                              ; Required bank to call.
            JR      BKSW7_0
BKSW7to7:   PUSH    AF
            LD      A, ROMBANK7                                              ; Calling bank (ie. us).
            PUSH    AF
            LD      A, ROMBANK7                                              ; Required bank to call.
            ;
BKSW7_0:    PUSH    HL                                                       ; Place function to call on stack
            LD      HL, BKSWRET7                                             ; Place bank switchers return address on stack.
            EX      (SP),HL
            LD      (TMPSTACKP),SP                                           ; Save the stack pointer as some old code corrupts it.
            BNKSWSEL
            JP      (HL)                                                     ; Jump to required function.
BKSWRET7:   POP     AF                                                       ; Get bank which called us.
            BNKSWSELRET
            POP     AF
            RET  

            ;-------------------------------------------------------------------------------
            ; Z80 Assembler lookup table  
            ; FORMAT: 10 bytes per row
            ; Instruction Blocks: start with # followed by 4 char instruction
            ;   byte 5 = #of rows for this instruction
            ; Parameter Blocks: A 7 byte parameter pattern
            ;                Opcode byte 1, Opcode byte 2(if any otherwise zero)
            ;                Number of byte used for opcodes & data parameters.
            ;-------------------------------------------------------------------------------
OPCD_TABLE: IF      BUILD_SFD700 = 1
              DB    "#ADC ",    00FH, 000H, 000H, 000H, 000H
              DB    "A,(HL) ",  08EH, 000H, 001H
              DB    "A,(IX*)",  08EH, 0DDH, 003H
              DB    "A,(IY*)",  08EH, 0FDH, 003H
              DB    "A,A    ",  08FH, 000H, 001H
              DB    "A,B    ",  088H, 000H, 001H
              DB    "A,C    ",  089H, 000H, 001H
              DB    "A,D    ",  08AH, 000H, 001H
              DB    "A,E    ",  08BH, 000H, 001H
              DB    "A,H    ",  08CH, 000H, 001H
              DB    "A,L    ",  08DH, 000H, 001H
              DB    "A,*    ",  0CEH, 000H, 002H
              DB    "HL,BC  ",  04AH, 0EDH, 002H
              DB    "HL,DE  ",  05AH, 0EDH, 002H
              DB    "HL,HL  ",  06AH, 0EDH, 002H
              DB    "HL,SP  ",  07AH, 0EDH, 002H
              DB    "#ADD ",    017H, 000H, 000H, 000H, 000H
              DB    "A,(HL) ",  086H, 000H, 001H
              DB    "A,(IX*)",  086H, 0DDH, 003H
              DB    "A,(IY*)",  086H, 0FDH, 003H
              DB    "A,A    ",  087H, 000H, 001H
              DB    "A,B    ",  080H, 000H, 001H
              DB    "A,C    ",  081H, 000H, 001H
              DB    "A,D    ",  082H, 000H, 001H
              DB    "A,E    ",  083H, 000H, 001H
              DB    "A,H    ",  084H, 000H, 001H
              DB    "A,L    ",  085H, 000H, 001H
              DB    "A,*    ",  0C6H, 000H, 002H
              DB    "HL,BC  ",  009H, 000H, 001H
              DB    "HL,DE  ",  019H, 000H, 001H
              DB    "HL,HL  ",  029H, 000H, 001H
              DB    "HL,SP  ",  039H, 000H, 001H
              DB    "IX,BC  ",  009H, 0DDH, 002H
              DB    "IX,DE  ",  019H, 0DDH, 002H
              DB    "IX,IX  ",  029H, 0DDH, 002H
              DB    "IX,SP  ",  039H, 0DDH, 002H
              DB    "IY,BC  ",  009H, 0FDH, 002H
              DB    "IY,DE  ",  019H, 0FDH, 002H
              DB    "IY,IY  ",  029H, 0FDH, 002H
              DB    "IY,SP  ",  039H, 0FDH, 002H
              DB    "#AND ",    00BH, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  0A6H, 000H, 001H
              DB    "(IX*)  ",  0A6H, 0DDH, 003H
              DB    "(IY*)  ",  0A6H, 0FDH, 003H
              DB    "A      ",  0A7H, 000H, 001H
              DB    "B      ",  0A0H, 000H, 001H
              DB    "C      ",  0A1H, 000H, 001H
              DB    "D      ",  0A2H, 000H, 001H
              DB    "E      ",  0A3H, 000H, 001H
              DB    "H      ",  0A4H, 000H, 001H
              DB    "L      ",  0A5H, 000H, 001H
              DB    "*      ",  0E6H, 000H, 002H
              DB    "#BIT ",    008H, 000H, 000H, 000H, 000H
              DB    "*,(HL) ",  046H, 0CBH, 002H
              DB    "*,A    ",  047H, 0CBH, 002H
              DB    "*,B    ",  040H, 0CBH, 002H
              DB    "*,C    ",  041H, 0CBH, 002H
              DB    "*,D    ",  042H, 0CBH, 002H
              DB    "*,E    ",  043H, 0CBH, 002H
              DB    "*,H    ",  044H, 0CBH, 002H
              DB    "*,L    ",  045H, 0CBH, 002H
              DB    "#CALL",    009H, 000H, 000H, 000H, 000H
              DB    "C,*    ",  0DCH, 000H, 003H
              DB    "M,*    ",  0FCH, 000H, 003H
              DB    "NC,*   ",  0D4H, 000H, 003H
              DB    "NZ,*   ",  0C4H, 000H, 003H
              DB    "P,*    ",  0F4H, 000H, 003H
              DB    "PE,*   ",  0ECH, 000H, 003H
              DB    "PO,*   ",  0E4H, 000H, 003H
              DB    "Z,*    ",  0CCH, 000H, 003H
              DB    "*      ",  0CDH, 000H, 003H
              DB    "#CCF ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  03FH, 000H, 001H
              DB    "#CP  ",    00BH, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  0BEH, 000H, 001H
              DB    "(IX*)  ",  0BEH, 0DDH, 003H
              DB    "(IY*)  ",  0BEH, 0FDH, 003H
              DB    "A      ",  0BFH, 000H, 001H
              DB    "B      ",  0B8H, 000H, 001H
              DB    "C      ",  0B9H, 000H, 001H
              DB    "D      ",  0BAH, 000H, 001H
              DB    "E      ",  0BBH, 000H, 001H
              DB    "H      ",  0BCH, 000H, 001H
              DB    "L      ",  0BDH, 000H, 001H
              DB    "*      ",  0FEH, 000H, 002H
              DB    "#CPD ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0A9H, 0EDH, 002H
              DB    "#CPDR",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0B9H, 0EDH, 002H
              DB    "#CPIR",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0B1H, 0EDH, 002H
              DB    "#CPI ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0A1H, 0EDH, 002H
              DB    "#CPL ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  02FH, 000H, 001H
              DB    "#DAA ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  027H, 000H, 001H
              DB    "#DEC ",    010H, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  035H, 000H, 001H
              DB    "(IX*)  ",  035H, 0DDH, 003H
              DB    "(IY*)  ",  035H, 0FDH, 003H
              DB    "A      ",  03DH, 000H, 001H
              DB    "B      ",  005H, 000H, 001H
              DB    "BC     ",  00BH, 000H, 001H
              DB    "C      ",  00DH, 000H, 001H
              DB    "D      ",  015H, 000H, 001H
              DB    "DE     ",  01BH, 000H, 001H
              DB    "E      ",  01DH, 000H, 001H
              DB    "H      ",  025H, 000H, 001H
              DB    "HL     ",  02BH, 000H, 001H
              DB    "IX     ",  02BH, 0DDH, 002H
              DB    "IY     ",  02BH, 0FDH, 002H
              DB    "L      ",  02DH, 000H, 001H
              DB    "SP     ",  03BH, 000H, 001H
              DB    "#DI  ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0F3H, 000H, 001H
              DB    "#DJNZ",    001H, 000H, 000H, 000H, 000H
              DB    "*      ",  010H, 000H, 002H
              DB    "#EI  ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0FBH, 000H, 001H
              DB    "#EX  ",    005H, 000H, 000H, 000H, 000H
              DB    "(SP),HL",  0E3H, 000H, 001H
              DB    "(SP),IX",  0E3H, 0DDH, 002H
              DB    "(SP),IY",  0E3H, 0FDH, 002H
              DB    "AF,AF",    02CH, 020H, 008H, 000H, 001H
              DB    "DE,HL  ",  0EBH, 000H, 001H
              DB    "#EXX ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0D9H, 000H, 001H
              DB    "#HALT",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  076H, 000H, 001H
              DB    "#IM  ",    003H, 000H, 000H, 000H, 000H
              DB    "0      ",  046H, 0EDH, 002H
              DB    "1      ",  056H, 0EDH, 002H
              DB    "2      ",  05EH, 0EDH, 002H
              DB    "#IN  ",    008H, 000H, 000H, 000H, 000H
              DB    "A,(C)  ",  078H, 0EDH, 002H
              DB    "B,(C)  ",  040H, 0EDH, 002H
              DB    "C,(C)  ",  048H, 0EDH, 002H
              DB    "D,(C)  ",  050H, 0EDH, 002H
              DB    "E,(C)  ",  058H, 0EDH, 002H
              DB    "H,(C)  ",  060H, 0EDH, 002H
              DB    "L,(C)  ",  068H, 0EDH, 002H
              DB    "A,(*)  ",  0DBH, 000H, 002H
              DB    "#IN0 ",    007H, 000H, 000H, 000H, 000H
              DB    " A,(*) ",  038H, 0EDH, 003H
              DB    " B,(*) ",  000H, 0EDH, 003H
              DB    " C,(*) ",  008H, 0EDH, 003H
              DB    " D,(*) ",  010H, 0EDH, 003H
              DB    " E,(*) ",  018H, 0EDH, 003H
              DB    " H,(*) ",  020H, 0EDH, 003H
              DB    " L,(*) ",  028H, 0EDH, 003H
              DB    "#INC ",    010H, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  034H, 000H, 001H
              DB    "(IX*)  ",  034H, 0DDH, 003H
              DB    "(IY*)  ",  034H, 0FDH, 003H
              DB    "A      ",  03CH, 000H, 001H
              DB    "B      ",  004H, 000H, 001H
              DB    "BC     ",  003H, 000H, 001H
              DB    "C      ",  00CH, 000H, 001H
              DB    "D      ",  014H, 000H, 001H
              DB    "DE     ",  013H, 000H, 001H
              DB    "E      ",  01CH, 000H, 001H
              DB    "H      ",  024H, 000H, 001H
              DB    "HL     ",  023H, 000H, 001H
              DB    "IX     ",  023H, 0DDH, 002H
              DB    "IY     ",  023H, 0FDH, 002H
              DB    "L      ",  02CH, 000H, 001H
              DB    "SP     ",  033H, 000H, 001H
              DB    "#IND ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0AAH, 0EDH, 002H
              DB    "#INDR",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0BAH, 0EDH, 002H
              DB    "#INI ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0A2H, 0EDH, 002H
              DB    "#INIR",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0B2H, 0EDH, 002H
              DB    "#JP  ",    00CH, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  0E9H, 000H, 001H
              DB    "(IX)   ",  0E9H, 0DDH, 002H
              DB    "(IY)   ",  0E9H, 0FDH, 002H
              DB    "C,*    ",  0DAH, 000H, 003H
              DB    "M,*    ",  0FAH, 000H, 003H
              DB    "NC,*   ",  0D2H, 000H, 003H
              DB    "NZ,*   ",  0C2H, 000H, 003H
              DB    "P,*    ",  0F2H, 000H, 003H
              DB    "PE,*   ",  0EAH, 000H, 003H
              DB    "PO,*   ",  0E2H, 000H, 003H
              DB    "Z,*    ",  0CAH, 000H, 003H
              DB    "*      ",  0C3H, 000H, 003H
              DB    "#JR  ",    005H, 000H, 000H, 000H, 000H
              DB    "C,*    ",  038H, 000H, 002H
              DB    "NC,*   ",  030H, 000H, 002H
              DB    "NZ,*   ",  020H, 000H, 002H
              DB    "Z,*    ",  028H, 000H, 002H
              DB    "*      ",  018H, 000H, 002H
              DB    "#LD  ",    084H, 000H, 000H, 000H, 000H
              DB    "(BC),A ",  002H, 000H, 001H
              DB    "(DE),A ",  012H, 000H, 001H
              DB    "(HL),A ",  077H, 000H, 001H
              DB    "(HL),B ",  070H, 000H, 001H
              DB    "(HL),C ",  071H, 000H, 001H
              DB    "(HL),D ",  072H, 000H, 001H
              DB    "(HL),E ",  073H, 000H, 001H
              DB    "(HL),H ",  074H, 000H, 001H
              DB    "(HL),L ",  075H, 000H, 001H
              DB    "(HL),* ",  036H, 000H, 002H
              DB    "(IX*),A",  077H, 0DDH, 003H
              DB    "(IX*),B",  070H, 0DDH, 003H
              DB    "(IX*),C",  071H, 0DDH, 003H
              DB    "(IX*),D",  072H, 0DDH, 003H
              DB    "(IX*),E",  073H, 0DDH, 003H
              DB    "(IX*),H",  074H, 0DDH, 003H
              DB    "(IX*),L",  075H, 0DDH, 003H
              DB    "(IX*),*",  036H, 0DDH, 004H
              DB    "(IY*),A",  077H, 0FDH, 003H
              DB    "(IY*),B",  070H, 0FDH, 003H
              DB    "(IY*),C",  071H, 0FDH, 003H
              DB    "(IY*),D",  072H, 0FDH, 003H
              DB    "(IY*),E",  073H, 0FDH, 003H
              DB    "(IY*),H",  074H, 0FDH, 003H
              DB    "(IY*),L",  075H, 0FDH, 003H
              DB    "(IY*),*",  036H, 0FDH, 004H
              DB    "(*),A  ",  032H, 000H, 003H
              DB    "(*),BC ",  043H, 0EDH, 004H
              DB    "(*),DE ",  053H, 0EDH, 004H
              DB    "(*),HL ",  022H, 000H, 003H
              DB    "(*),IX ",  022H, 0DDH, 004H
              DB    "(*),IY ",  022H, 0FDH, 004H
              DB    "(*),SP ",  073H, 0EDH, 004H
              DB    "A,(BC) ",  00AH, 000H, 001H
              DB    "A,(DE) ",  01AH, 000H, 001H
              DB    "A,(HL) ",  07EH, 000H, 001H
              DB    "A,(IX*)",  07EH, 0DDH, 003H
              DB    "A,(IY*)",  07EH, 0FDH, 003H
              DB    "A,A    ",  07FH, 000H, 001H
              DB    "A,B    ",  078H, 000H, 001H
              DB    "A,C    ",  079H, 000H, 001H
              DB    "A,D    ",  07AH, 000H, 001H
              DB    "A,E    ",  07BH, 000H, 001H
              DB    "A,H    ",  07CH, 000H, 001H
              DB    "A,I    ",  057H, 0EDH, 002H
              DB    "A,L    ",  07DH, 000H, 001H
              DB    "A,R    ",  05FH, 0EDH, 002H
              DB    "A,(*)  ",  03AH, 000H, 003H
              DB    "A,*    ",  03EH, 000H, 002H
              DB    "B,(HL) ",  046H, 000H, 001H
              DB    "B,(IX*)",  046H, 0DDH, 003H
              DB    "B,(IY*)",  046H, 0FDH, 003H
              DB    "B,A    ",  047H, 000H, 001H
              DB    "B,B    ",  040H, 000H, 001H
              DB    "B,C    ",  041H, 000H, 001H
              DB    "B,D    ",  042H, 000H, 001H
              DB    "B,E    ",  043H, 000H, 001H
              DB    "B,H    ",  044H, 000H, 001H
              DB    "B,L    ",  045H, 000H, 001H
              DB    "B,*    ",  006H, 000H, 002H
              DB    "BC,(*) ",  04BH, 0EDH, 004H
              DB    "BC,*   ",  001H, 000H, 003H
              DB    "C,(HL) ",  04EH, 000H, 001H
              DB    "C,(IX*)",  04EH, 0DDH, 003H
              DB    "C,(IY*)",  04EH, 0FDH, 003H
              DB    "C,A    ",  04FH, 000H, 001H
              DB    "C,B    ",  048H, 000H, 001H
              DB    "C,C    ",  049H, 000H, 001H
              DB    "C,D    ",  04AH, 000H, 001H
              DB    "C,E    ",  04BH, 000H, 001H
              DB    "C,H    ",  04CH, 000H, 001H
              DB    "C,L    ",  04DH, 000H, 001H
              DB    "C,*    ",  00EH, 000H, 002H
              DB    "D,(HL) ",  056H, 000H, 001H
              DB    "D,(IX*)",  056H, 0DDH, 003H
              DB    "D,(IY*)",  056H, 0FDH, 003H
              DB    "D,A    ",  057H, 000H, 001H
              DB    "D,B    ",  050H, 000H, 001H
              DB    "D,C    ",  051H, 000H, 001H
              DB    "D,D    ",  052H, 000H, 001H
              DB    "D,E    ",  053H, 000H, 001H
              DB    "D,H    ",  054H, 000H, 001H
              DB    "D,L    ",  055H, 000H, 001H
              DB    "D,*    ",  016H, 000H, 002H
              DB    "DE,(*) ",  05BH, 0EDH, 004H
              DB    "DE,*   ",  011H, 000H, 003H
              DB    "E,(HL) ",  05EH, 000H, 001H
              DB    "E,(IX*)",  05EH, 0DDH, 003H
              DB    "E,(IY*)",  05EH, 0FDH, 003H
              DB    "E,A    ",  05FH, 000H, 001H
              DB    "E,B    ",  058H, 000H, 001H
              DB    "E,C    ",  059H, 000H, 001H
              DB    "E,D    ",  05AH, 000H, 001H
              DB    "E,E    ",  05BH, 000H, 001H
              DB    "E,H    ",  05CH, 000H, 001H
              DB    "E,L    ",  05DH, 000H, 001H
              DB    "E,*    ",  01EH, 000H, 002H
              DB    "H,(HL) ",  066H, 000H, 001H
              DB    "H,(IX*)",  066H, 0DDH, 003H
              DB    "H,(IY*)",  066H, 0FDH, 003H
              DB    "H,A    ",  067H, 000H, 001H
              DB    "H,B    ",  060H, 000H, 001H
              DB    "H,C    ",  061H, 000H, 001H
              DB    "H,D    ",  062H, 000H, 001H
              DB    "H,E    ",  063H, 000H, 001H
              DB    "H,H    ",  064H, 000H, 001H
              DB    "H,L    ",  065H, 000H, 001H
              DB    "H,*    ",  026H, 000H, 002H
              DB    "HL,(*) ",  02AH, 000H, 003H
              DB    "HL,*   ",  021H, 000H, 003H
              DB    "I,A    ",  047H, 0EDH, 002H
              DB    "IX,(*) ",  02AH, 0DDH, 004H
              DB    "IX,*   ",  021H, 0DDH, 004H
              DB    "IY,(*) ",  02AH, 0FDH, 004H
              DB    "IY,*   ",  021H, 0FDH, 004H
              DB    "L,(HL) ",  06EH, 000H, 001H
              DB    "L,(IX*)",  06EH, 0DDH, 003H
              DB    "L,(IY*)",  06EH, 0FDH, 003H
              DB    "L,A    ",  06FH, 000H, 001H
              DB    "L,B    ",  068H, 000H, 001H
              DB    "L,C    ",  069H, 000H, 001H
              DB    "L,D    ",  06AH, 000H, 001H
              DB    "L,E    ",  06BH, 000H, 001H
              DB    "L,H    ",  06CH, 000H, 001H
              DB    "L,L    ",  06DH, 000H, 001H
              DB    "L,*    ",  02EH, 000H, 002H
              DB    "R,A    ",  04FH, 0EDH, 002H
              DB    "SP,(*) ",  07BH, 0EDH, 004H
              DB    "SP,HL  ",  0F9H, 000H, 001H
              DB    "SP,IX  ",  0F9H, 0DDH, 002H
              DB    "SP,IY  ",  0F9H, 0FDH, 002H
              DB    "SP,*   ",  031H, 000H, 003H
              DB    "#LDD ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0A8H, 0EDH, 002H
              DB    "#LDDR",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0B8H, 0EDH, 002H
              DB    "#LDI ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0A0H, 0EDH, 002H
              DB    "#LDIR",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0B0H, 0EDH, 002H
              DB    "#NEG ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  044H, 0EDH, 002H
              DB    "#NOP ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  000H, 000H, 001H
              DB    "#OR  ",    00BH, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  0B6H, 000H, 001H
              DB    "(IX*)  ",  0B6H, 0DDH, 003H
              DB    "(IY*)  ",  0B6H, 0FDH, 003H
              DB    "A      ",  0B7H, 000H, 001H
              DB    "B      ",  0B0H, 000H, 001H
              DB    "C      ",  0B1H, 000H, 001H
              DB    "D      ",  0B2H, 000H, 001H
              DB    "E      ",  0B3H, 000H, 001H
              DB    "H      ",  0B4H, 000H, 001H
              DB    "L      ",  0B5H, 000H, 001H
              DB    "*      ",  0F6H, 000H, 002H
              DB    "#OTDR",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0BBH, 0EDH, 002H
              DB    "#OTIR",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0B3H, 0EDH, 002H
              DB    "#OUT ",    008H, 000H, 000H, 000H, 000H
              DB    "(C),A  ",  079H, 0EDH, 002H
              DB    "(C),B  ",  041H, 0EDH, 002H
              DB    "(C),C  ",  049H, 0EDH, 002H
              DB    "(C),D  ",  051H, 0EDH, 002H
              DB    "(C),E  ",  059H, 0EDH, 002H
              DB    "(C),H  ",  061H, 0EDH, 002H
              DB    "(C),L  ",  069H, 0EDH, 002H
              DB    "(*),A  ",  0D3H, 000H, 002H
              DB    "#OUT0",    007H, 000H, 000H, 000H, 000H
              DB    "(*),A  ",  039H, 0EDH, 003H
              DB    "(*),B  ",  001H, 0EDH, 003H
              DB    "(*),C  ",  009H, 0EDH, 003H
              DB    "(*),D  ",  011H, 0EDH, 003H
              DB    "(*),E  ",  019H, 0EDH, 003H
              DB    "(*),H  ",  021H, 0EDH, 003H
              DB    "(*),L  ",  029H, 0EDH, 003H
              DB    "#OUTD",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0ABH, 0EDH, 002H
              DB    "#OUTI",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  0A3H, 0EDH, 002H
              DB    "#POP ",    006H, 000H, 000H, 000H, 000H
              DB    "AF     ",  0F1H, 000H, 001H
              DB    "BC     ",  0C1H, 000H, 001H
              DB    "DE     ",  0D1H, 000H, 001H
              DB    "HL     ",  0E1H, 000H, 001H
              DB    "IX     ",  0E1H, 0DDH, 002H
              DB    "IY     ",  0E1H, 0FDH, 002H
              DB    "#PUSH",    006H, 000H, 000H, 000H, 000H
              DB    "AF     ",  0F5H, 000H, 001H
              DB    "BC     ",  0C5H, 000H, 001H
              DB    "DE     ",  0D5H, 000H, 001H
              DB    "HL     ",  0E5H, 000H, 001H
              DB    "IX     ",  0E5H, 0DDH, 002H
              DB    "IY     ",  0E5H, 0FDH, 002H
              DB    "#RES ",    008H, 000H, 000H, 000H, 000H
              DB    "*,(HL) ",  086H, 0CBH, 002H
              DB    "*,A    ",  087H, 0CBH, 002H
              DB    "*,B    ",  080H, 0CBH, 002H
              DB    "*,C    ",  081H, 0CBH, 002H
              DB    "*,D    ",  082H, 0CBH, 002H
              DB    "*,E    ",  083H, 0CBH, 002H
              DB    "*,H    ",  084H, 0CBH, 002H
              DB    "*,L    ",  085H, 0CBH, 002H
              DB    "#RET ",    009H, 000H, 000H, 000H, 000H
              DB    "       ",  0C9H, 000H, 001H
              DB    "C      ",  0D8H, 000H, 001H
              DB    "M      ",  0F8H, 000H, 001H
              DB    "NC     ",  0D0H, 000H, 001H
              DB    "NZ     ",  0C0H, 000H, 001H
              DB    "P      ",  0F0H, 000H, 001H
              DB    "PE     ",  0E8H, 000H, 001H
              DB    "PO     ",  0E0H, 000H, 001H
              DB    "Z      ",  0C8H, 000H, 001H
              DB    "#RETI",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  04DH, 0EDH, 002H
              DB    "#RETN",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  045H, 0EDH, 002H
              DB    "#RL  ",    008H, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  016H, 0CBH, 002H
              DB    "A      ",  017H, 0CBH, 002H
              DB    "B      ",  010H, 0CBH, 002H
              DB    "C      ",  011H, 0CBH, 002H
              DB    "D      ",  012H, 0CBH, 002H
              DB    "E      ",  013H, 0CBH, 002H
              DB    "H      ",  014H, 0CBH, 002H
              DB    "L      ",  015H, 0CBH, 002H
              DB    "#RLA ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  017H, 000H, 001H
              DB    "#RLC ",    008H, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  006H, 0CBH, 002H
              DB    "A      ",  007H, 0CBH, 002H
              DB    "B      ",  000H, 0CBH, 002H
              DB    "C      ",  001H, 0CBH, 002H
              DB    "D      ",  002H, 0CBH, 002H
              DB    "E      ",  003H, 0CBH, 002H
              DB    "H      ",  004H, 0CBH, 002H
              DB    "L      ",  005H, 0CBH, 002H
              DB    "#RLCA",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  007H, 000H, 001H
              DB    "#RLD ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  06FH, 0EDH, 002H
              DB    "#RR  ",    008H, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  01EH, 0CBH, 002H
              DB    "A      ",  01FH, 0CBH, 002H
              DB    "B      ",  018H, 0CBH, 002H
              DB    "C      ",  019H, 0CBH, 002H
              DB    "D      ",  01AH, 0CBH, 002H
              DB    "E      ",  01BH, 0CBH, 002H
              DB    "H      ",  01CH, 0CBH, 002H
              DB    "L      ",  01DH, 0CBH, 002H
              DB    "#RRA ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  01FH, 000H, 001H
              DB    "#RRC ",    008H, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  00EH, 0CBH, 002H
              DB    "A      ",  00FH, 0CBH, 002H
              DB    "B      ",  008H, 0CBH, 002H
              DB    "C      ",  009H, 0CBH, 002H
              DB    "D      ",  00AH, 0CBH, 002H
              DB    "E      ",  00BH, 0CBH, 002H
              DB    "H      ",  00CH, 0CBH, 002H
              DB    "L      ",  00DH, 0CBH, 002H
              DB    "#RRCA",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  00FH, 000H, 001H
              DB    "#RRD ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  067H, 0EDH, 002H
              DB    "#RST ",    008H, 000H, 000H, 000H, 000H
              DB    "00H    ",  0C7H, 000H, 001H
              DB    "08H    ",  0CFH, 000H, 001H
              DB    "10H    ",  0D7H, 000H, 001H
              DB    "18H    ",  0DFH, 000H, 001H
              DB    "20H    ",  0E7H, 000H, 001H
              DB    "28H    ",  0EFH, 000H, 001H
              DB    "30H    ",  0F7H, 000H, 001H
              DB    "38H    ",  0FFH, 000H, 001H
              DB    "#SBC ",    00FH, 000H, 000H, 000H, 000H
              DB    "A,(HL) ",  09EH, 000H, 001H
              DB    "A,(IX*)",  09EH, 0DDH, 003H
              DB    "A,(IY*)",  09EH, 0FDH, 003H
              DB    "A,A    ",  09FH, 000H, 001H
              DB    "A,B    ",  098H, 000H, 001H
              DB    "A,C    ",  099H, 000H, 001H
              DB    "A,D    ",  09AH, 000H, 001H
              DB    "A,E    ",  09BH, 000H, 001H
              DB    "A,H    ",  09CH, 000H, 001H
              DB    "A,L    ",  09DH, 000H, 001H
              DB    "HL,BC  ",  042H, 0EDH, 002H
              DB    "HL,DE  ",  052H, 0EDH, 002H
              DB    "HL,HL  ",  062H, 0EDH, 002H
              DB    "HL,SP  ",  072H, 0EDH, 002H
              DB    "A,*    ",  0DEH, 000H, 002H
              DB    "#SCF ",    001H, 000H, 000H, 000H, 000H
              DB    "       ",  037H, 000H, 001H
              DB    "#SET ",    008H, 000H, 000H, 000H, 000H
              DB    "*,(HL) ",  0C6H, 0CBH, 002H
              DB    "*,A    ",  0C7H, 0CBH, 002H
              DB    "*,B    ",  0C0H, 0CBH, 002H
              DB    "*,C    ",  0C1H, 0CBH, 002H
              DB    "*,D    ",  0C2H, 0CBH, 002H
              DB    "*,E    ",  0C3H, 0CBH, 002H
              DB    "*,H    ",  0C4H, 0CBH, 002H
              DB    "*,L    ",  0C5H, 0CBH, 002H
              DB    "#SLA ",    008H, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  026H, 0CBH, 002H
              DB    "A      ",  027H, 0CBH, 002H
              DB    "B      ",  020H, 0CBH, 002H
              DB    "C      ",  021H, 0CBH, 002H
              DB    "D      ",  022H, 0CBH, 002H
              DB    "E      ",  023H, 0CBH, 002H
              DB    "H      ",  024H, 0CBH, 002H
              DB    "L      ",  025H, 0CBH, 002H
              DB    "#SRA ",    008H, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  02EH, 0CBH, 002H
              DB    "A      ",  02FH, 0CBH, 002H
              DB    "B      ",  028H, 0CBH, 002H
              DB    "C      ",  029H, 0CBH, 002H
              DB    "D      ",  02AH, 0CBH, 002H
              DB    "E      ",  02BH, 0CBH, 002H
              DB    "H      ",  02CH, 0CBH, 002H
              DB    "L      ",  02DH, 0CBH, 002H
              DB    "#SRL ",    008H, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  03EH, 0CBH, 002H
              DB    "A      ",  03FH, 0CBH, 002H
              DB    "B      ",  038H, 0CBH, 002H
              DB    "C      ",  039H, 0CBH, 002H
              DB    "D      ",  03AH, 0CBH, 002H
              DB    "E      ",  03BH, 0CBH, 002H
              DB    "H      ",  03CH, 0CBH, 002H
              DB    "L      ",  03DH, 0CBH, 002H
              DB    "#SUB ",    00BH, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  096H, 000H, 001H
              DB    "(IX*)  ",  096H, 0DDH, 003H
              DB    "(IY*)  ",  096H, 0FDH, 003H
              DB    "A      ",  097H, 000H, 001H
              DB    "B      ",  090H, 000H, 001H
              DB    "C      ",  091H, 000H, 001H
              DB    "D      ",  092H, 000H, 001H
              DB    "E      ",  093H, 000H, 001H
              DB    "H      ",  094H, 000H, 001H
              DB    "L      ",  095H, 000H, 001H
              DB    "*      ",  0D6H, 000H, 002H
              DB    "#XOR ",    00BH, 000H, 000H, 000H, 000H
              DB    "(HL)   ",  0AEH, 000H, 001H
              DB    "(IX*)  ",  0AEH, 0DDH, 003H
              DB    "(IY*)  ",  0AEH, 0FDH, 003H
              DB    "A      ",  0AFH, 000H, 001H
              DB    "B      ",  0A8H, 000H, 001H
              DB    "C      ",  0A9H, 000H, 001H
              DB    "D      ",  0AAH, 000H, 001H
              DB    "E      ",  0ABH, 000H, 001H
              DB    "H      ",  0ACH, 000H, 001H
              DB    "L      ",  0ADH, 000H, 001H
              DB    "*      ",  0EEH, 000H, 002H
              DB    "#END ",    000H, 000H, 000H, 000H, 000H           
            ENDIF
            ;-------------------------------------------------------------------------------
            ; END of Z80 Assembler lookup table  
            ;-------------------------------------------------------------------------------

            ;******************************************************************
            ; Z80 Assembler Routines
            ;******************************************************************

            ; Method to get a string parameter and copy it into the provided buffer.
            ; (Duplicate method, also in Bank TZFS1).
            ; Inputs:
            ;     DE = Pointer to BUFER where user entered data has been placed.
            ;     HL = Pointer to Destination buffer.
            ;     B  = Max number of characters to read.
            ; Outputs:
            ;     DE and HL point to end of bufer and buffer resepectively.
            ;     B  = Characters copied (ie. B - input B = no characters).
            ;
GETSTR:     IF      BUILD_SFD700 = 1
              LD    A,(DE)           ; Skip white space and control characters before copy.
              CP    33
              JR    NC, GSTR1
              CP    00DH
              JR    Z, GSTR2         ; No directory means use the I/O set default.
              OR    A
              JR    Z, GSTR2
              INC   DE
              INC   C                ; Count the characters on the line.
              JR    GETSTR
GSTR1:        LD    (HL),A           ; Copy the name entered by user. Validation is done on the I/O processor, bad directory name will result in error next read/write.
              INC   DE
              INC   HL
              INC   C                ; Count the characters on the line.
              LD    A,(DE)           ; Get next char and check it isnt CR, end of input line character.
              CP    00DH
              JR    Z,GSTR2          ; Finished if we encounter CR.
              DJNZ  GSTR1            ; Loop until buffer is full, ignore characters beyond buffer limit.
GSTR2:        XOR   A                ; Place end of buffer terminator as I/O processor uses C strings.
              LD    (HL),A
              RET            
            ENDIF

            ;******************************************************************
            ; ASMFINDPARM
            ; HL=src  dest = PARM_BUF  
            ; Search block until match of PARM_BUF or end of block is found
            ; Return with HL pointing to match block B=block count
            ;******************************************************************
ASMFINDPARM:IF      BUILD_SFD700 = 1
              PUSH  DE
              PUSH  BC
              PUSH  HL
              LD    IX,(BLK_ADDR)    ; Load Saved Block Address->IX
              LD    A,(BLK_SIZE)     ; Get Block Size
              LD    L,A              ; L=ROW COUNTER
AFP_NEXTROW:  LD    DE,000Ah         ; 10 bytes per row
              ADD   IX,DE            ; Add 10 to Address (next block)
              LD    (ROW_ADDR),IX    ; Save ROW Address
              LD    IY,PARM_BUF      ; IY=PARM_BUF              
              LD    C,07h            ; Loop count =7
AFP_CMPLOOP:  LD    A,(IX+0)         ; Get Table byte->A
              LD    B,(IY+0)         ; Get PARM_BUF byte->B  
              CP    B                ; Compare A-B
              JP    NZ,AFP_NOMATCH   ; Mismatch = Exit loop
              INC   IX               ; Advance pointers
              INC   IY
              DEC   C                ; Decrement loop count
              JP    NZ,AFP_CMPLOOP   ; Not done yet - continue
              JP    AFP_MATCH        ; Match Found Get ML Bytes & Counts
                                     ; Match not found, advance to next block                 
AFP_NOMATCH:  DEC   L                ; Decrement row counter 
              JP    Z,AFP_NOFIND     ; Done = NOT FOUND EXIT
              LD    IX,(ROW_ADDR)    ; Get Saved ROW Address->IX
              JP    AFP_NEXTROW      ; Continue 
              
AFP_NOFIND:   LD    A,0              ; Not Found set ML_BUF[2]=0  
              LD    (ML_BUF+2),A
              JP    AFP_EXIT
              
AFP_MATCH:    LD    A,(IX+0)         ; Get Table ML Byte 1
              LD    (ML_BUF),A       ; Save it in M_BUF[0]
              LD    A,(IX+1)         ; Get Table ML Byte 2
              LD    (ML_BUF+1),A     ; Save it in M_BUF[1]
              LD    A,(IX+2)         ; Get Table  ML Byte count
              LD    (ML_BUF+2),A     ; Save it in M_BUF[2]
              
AFP_EXIT:     POP   HL
              POP   BC
              POP   DE
              RET
            ENDIF

            ;******************************************************************
            ; ASMFINDINST
            ; HL=src  dest = VAL_BUF  
            ; Search table until match of INS_BUF or end of table is found
            ; Return with IX pointing to match block B=block count
            ;******************************************************************
ASMFINDINST:IF      BUILD_SFD700 = 1
              PUSH  DE
              PUSH  BC
              LD    A,0
              LD    (ROW_NUM),A
              LD    IX,OPCD_TABLE
AFI_NEXTBLK:  LD    (BLK_ADDR),IX    ; Save Block Address
              LD    A,(IX+5)         ; Get Block Size & Save
              LD    (BLK_SIZE),A
              CP    0                ; If Block Size = 0 EXIT
              JP    Z,AFI_EXIT
              
              LD    IY,INS_BUF       ; IX=INS_BUF              
              LD    C,04h            ; Loop count =4
AFI_CMPLOOP:  LD    A,(IX+1)         ; Get Table byte->A
              LD    B,(IY+0)         ; Get INS_BUF byte->B  
              CP    B                ; Compare A-B
              JP    NZ,AFI_NOMATCH   ; Mismatch = Exit loop
              INC   IX               ; Advance pointers
              INC   IY
              DEC   C                ; Decremebnt loop count
              JP    NZ,AFI_CMPLOOP   ; Not done yet - continue
              JP    AFI_EXIT         ; Match Found EXIT
                                     ; Match not found, advance to next block                 
AFI_NOMATCH:  LD    A,(BLK_SIZE)     ; Get Block Size
              INC   A                ; Add 1 to Block count
              LD    IX,(BLK_ADDR)    ; Get Saved Block Start Address
              LD    DE,000Ah         ; 10 bytes per row
AFI_BLKLOOP:  ADD   IX,DE            ; Add 10 to Address 
              DEC   A                ; Decrement block counter 
              JP    NZ,AFI_BLKLOOP   ; Not Done = loop
              LD    A,(ROW_NUM)      ; Advance Row Number
              INC   A
              LD    (ROW_NUM),A 
              JP    AFI_NEXTBLK
              
AFI_EXIT:     POP   BC
              POP   DE
              RET
            ENDIF                    ; SFD700

            ;******************************************************************
            ; ASMRTJVAL
            ; Shift bytes in VAL_BUF right until left padded with '0's  
            ;******************************************************************
ASMRJTVAL:  IF      BUILD_SFD700 = 1
              PUSH  DE
              PUSH  BC
              LD    IX,VAL_BUF
              LD    B,05h            ; B=MAX search count 5
              
ASMRJT_LOOP:  LD    A,(IX+3)         ; Get last byte from VAL_BUF
              CP    ' '              ; Is It SPACE?
              JP    NZ,ASMRJT_EXIT   ; Exit
              LD    A,(IX+2)         ; Shift 3 bytes left 1 positiom
              LD    (IX+3),A
              LD    A,(IX+1) 
              LD    (IX+2),A
              LD    A,(IX+0) 
              LD    (IX+1),A
              LD    A,'0'            ; Pad first position with '0' 
              LD    (IX+0),A
              DEC   B
              JP    NZ,ASMRJT_LOOP
              
ASMRJT_EXIT:  POP   BC
              POP   DE
              RET
            ENDIF                    ; SFD700

            ;******************************************************************
            ; ASMGETVAL
            ; HL=src  dest = VAL_BUF  
            ; Copy bytes from src to dest until a non digit is encountered (4 bytes max.)
            ; skip over number flags ('$','+,'#')
            ;******************************************************************
ASMGETVAL:  IF      BUILD_SFD700 = 1
              PUSH  DE
              PUSH  BC
              LD    DE,VAL_BUF
              LD    B,05h            ; B=MAX search count 5
ASMGVL_LOOP:  LD    A,(HL)           ; Get a byte from ASM_BUF

              CP    0                ; End of input?
              JP    Z,ASMGVL_EXIT    ; Exit
               
              CALL  ISVALFLAG        ; Test A for '#' '$' or '+'
              JP    Z,ASMGVL_SKIP    ; If match then just skip it
              
              CALL  IS_DIGIT         ; Is A= '0'-'9' or 'A'-'F'?        
              JP    NZ,ASMGVL_EXIT
              LD    (DE),A           ; Save the byte to VAL_BUF
              INC   DE               ; Advance the destination pointer
ASMGVL_SKIP:  INC   HL               ; Advance the sourc pointer 
              DEC   B                ; Decrement byte count
              JP    NZ,ASMGVL_LOOP   ; Max reached? NO=Continue
ASMGVL_EXIT:  POP   BC
              POP   DE
              RET
            ENDIF                    ; SFD700

            ;******************************************************************
            ; ISFLAGORNUM
            ;  
            ; RETURN Z=1 if A = '$', '+' ,'#' or '0'-'9' 
            ;******************************************************************
ISFLAGORNUM:IF      BUILD_SFD700 = 1
              CALL  ISVALFLAG        ; is A ='$','#' or '+'?
              JP    Z,ISNUMF_ZRET    ; YES=return Z=1

              CALL  ISDECDIGIT       ; Test for '0-'9'  
ISNUMF_ZRET:  RET                    ;(Z is set accordingly)
            ENDIF                    ; SFD700
 
            ;******************************************************************
            ; ISVALFLAG
            ;  
            ; RETURN Z=1 if A = '$', '+' ,'#' or '0'-'9' (A is unchanged )
            ; NOTE: A MUST be a non-zero ASCII Digit
            ;******************************************************************
ISVALFLAG:  IF      BUILD_SFD700 = 1
              CP    '$'              ; is A ='$'?
              JP    Z,ISVALF_ZRET    ; YES=return Z=1 
              CP    '+'              ; is A ='+'?
              JP    Z,ISVALF_ZRET    ; YES=return Z=1
              CP    '#'              ; is A ='#'?
              JP    Z,ISVALF_ZRET    ; YES=return Z=1
               
              CP    0                ; Otherwise set Z=0                  
ISVALF_ZRET:  RET             
            ENDIF                    ; SFD700

              ;******************************************************************
              ; PADWSPC
              ; DE=dest  BC=END 
              ; starting at current DE fill with spaces until DE=BC
              ; NOTE: BC MUST BE > DE no bounds checking is done
              ;******************************************************************
PADWSPC:    IF      BUILD_SFD700 = 1
              LD    A,B
              CP    D
              JP    NZ,DOPADWSPC
              LD    A,C
              CP    E
              JP    M,PADWSP_EXIT               
              JP    NZ,DOPADWSPC
PADWSP_EXIT:  RET
DOPADWSPC:    LD    A,' '
              LD    (DE),A
              INC   DE
              JP    PADWSPC             
            ENDIF                    ; SFD700

            ;******************************************************************
            ; SKIPSPC
            ; HL=src  b=MAX 
            ; advance HL until it is pointing at a non-space byte (16 bytes max.)
            ;******************************************************************
SKIPSPC:    IF      BUILD_SFD700 = 1
              LD    B,10h            ; B= MAX byte count 16
SKIPSP_LOOP:  LD    A,(HL)
              INC   HL
              CP    ' '
              JP    Z,SKIPSP_EXIT
              CP    0
              JP    Z,SKIPSP_EXIT
              DEC   B
              JP    NZ,SKIPSP_LOOP 
SKIPSP_EXIT:  RET
            ENDIF                    ; SFD700

            ;******************************************************************
            ; CPY2SPC
            ; HL=src  DE=dest b=count 
            ; Copy bytes from src to dest until a space is encountered (12 bytes max.)
            ;******************************************************************
CPY2SPC:    IF      BUILD_SFD700 = 1
              LD    B,0Ch            ; B= MAX byte count 12
CPY2SP_LOOP:  LD    A,(HL)
              CP    ' '
              JP    Z,CPY2SP_EXIT    ; Found space so EXIT
              
              CP    0
              JP    NZ,CPY2SP_COPY   ; Found NULL before space
              LD    A,' '
              LD    (HL),A           ; Replace with space & exit
              INC   HL
              LD    A,0              ; Terminate
              LD    (HL),A
              DEC   HL
              JP    CPY2SP_EXIT
              
CPY2SP_COPY:  LD    (DE),A           ; Copy the byte
              INC   DE               ; Advance destination pointer 
              INC   HL               ; Advance source pointer
              DEC   B                ; Decremet byte count 
              JP    NZ,CPY2SP_LOOP   ; If MAX not reached continue...
CPY2SP_EXIT:  RET
            ENDIF                    ; SFD700

            ; RomDisk - Pad to EFFF boundary.
            IF      BUILD_ROMDISK = 1
              ALIGN 0EFF8h
              ORG   0EFF8h
              DB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh            
            ENDIF
            ; SFD700 - Pad to 10000H
            IF      BUILD_SFD700 = 1
              ALIGN 10000H
            ENDIF

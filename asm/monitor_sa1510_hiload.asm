; Configurable parameters.
COLW:   EQU     40                      ; Width of the display screen (ie. columns).
ROW:    EQU     25                      ; Number of rows on display screen.
SCRNSZ: EQU     COLW * ROW              ; Total size, in bytes, of the screen display area.
SCRLW:  EQU     COLW / 8                ; Number of 8 byte regions in a line for hardware scroll.
MODE80C:EQU     0                       ; Configure for 80 column mode monitor.
KUMABIN:EQU     0                       ; Generate original Kuma Monitor Binary (=1)
KUMA80: EQU     0                       ; Kuma upgrade installed, enable 80 column mode.

		INCLUDE "sa1510_hiload.asm"

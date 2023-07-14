; Configurable parameters.
COLW:   EQU     80                      ; Width of the display screen (ie. columns).
ROW:    EQU     25                      ; Number of rows on display screen.
SCRNSZ: EQU     COLW * ROW              ; Total size, in bytes, of the screen display area.
MODE80C:EQU     1                       ; Configure for 80 column mode monitor.
KUMABIN:EQU     0                       ; Generate original Kuma Monitor Binary (=1)
KUMA80: EQU     0                       ; Kuma upgrade installed, enable 80 column mode.

		INCLUDE "1z-013a.asm"

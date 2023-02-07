;***********************************************************
;*
;*	 Author: Emily Becher
;*	   Date: October 12, 2022
;*
;***********************************************************

.include "m32U4def.inc"			; Include definition file	

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16		; Multipurpose register is required for LCD Driver
.def	i = r17			; counter register
.def	temp = r18		; temp register

.equ	LL1 = $00		; low line 1 address
.equ	HL1 = $01		; high line 1 address
.equ	LL2 = $10		; low line 2 address
.equ	HL2 = $01		; high line 2 address
.equ	ON  = 0xFF		; ON is all ones
.equ	OFF = 0x00		; OFF is all zeroes

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp INIT				; Reset interrupt

.org	$0056					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:							; The initialization routine
		; Initialize Stack Pointer
		ldi mpr, high(RAMEND)		
		out SPH, mpr
		ldi mpr, low(RAMEND)
		out SPL, mpr
	

		; Initialize LCD Display
		rcall LCDInit		; Call intialization file from LCDDriver

		; Initialize Port D for input
		ldi		mpr, $00		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State

		; Start with scroll off
		ldi		temp, OFF		; set scroll off

		; Move string 1 from program memory to data memory
	WRITE:
		rcall LCDClr		; Clear to get rid of random characters
		LDI		ZL, LOW(STRING1_BEG<<1)	; beginning of string1 to lower byte of Z
		LDI		ZH, HIGH(STRING1_BEG<<1); next char to high byte of Z
		LDI		YL, LL1					; YL points to data memory location
		LDI		YH, HL1					; YH points to second location
		DO:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(STRING1_END<<1); compare z to byte after string
			BRNE DO						; continue in loop if not equal
		NEXT:

		; Move string 2 from program memory to data memory
		LDI		ZL, LOW(STRING2_BEG<<1) ; beginning of string2 to lower byte of Z
		LDI		ZH, HIGH(STRING2_BEG<<1); next char to high byte of Z
		LDI		YL, LL2					; YL points to 2nd line of LCD
		LDI		YH, HL2					; YH points to 2nd line of data memory
		DO2:
			LPM mpr, Z+					; load register and post increment
			ST  Y+,  mpr				; store to data memory with post increment
			CPI ZL,  LOW(STRING2_END<<1); compare z to byte after string2
			BRNE DO2					; continue in loop if not equal
		NEXT2:
		ldi		temp, OFF				; set scroll off			

		; NOTE that there is no RET or RJMP from INIT,
		; this is because the next instruction executed is the
		; first instruction of the main program

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:							; The Main program

		; Display the strings on the LCD Display
		rcall	LCDWrite		; Display data memory
		IN		mpr, PIND		; get input from buttons
		ANDI	mpr, 0xf0		; only get input from bits 7-4
		CPI		mpr, 0xe0		; check if button 1 is pressed
		BRNE	N1				; if not equal continue to next check
		rcall	LCDClr			; clears data memory
		ldi		temp, OFF		; set scroll off
		rjmp	MAIN			; start loop over
	N1:	
		CPI		mpr, 0xd0		; check if button 2 is pressed
		BRNE	N2  			; if not equal continue to next check
		rjmp	WRITE			; load strings into data memory
		ldi		temp, OFF		; set scroll off
		rjmp	MAIN			; start loop over
	N2:
		CPI		mpr, 0xb0		; check if button 3 is pressed
		BRNE	N3				; continue to next check
		rcall	Reverse			; load strings to data memory in reverse order
		ldi		temp, OFF		; set scroll off
		rjmp	MAIN			; start loop over
	N3:
		CPI		mpr, 0x70		; check if button 4 is pressed
		BRNE	N4				; restart loop
	Scroll:
		ldi		temp, ON		; turn temp ON
		rcall	Shift			; shift contents of data memory
		ldi		i, 0xFF			; set mpr as large as possible
	Delay:
		rcall	LCDDelay		; wait
		dec		i				; decrement i
		brne	Delay			; branch unless i is 0
		ldi		temp, ON		; set scroll on
		rjmp	Main			; start main loop over
	N4:
		cpi		temp, ON		; check if temp is in on state
		breq	Scroll			; go to scroll if on state
		rjmp	Main			; start main loop over

						; jump back to main and create an infinite
								; while loop.  Generally, every main program is an
								; infinite while loop, never let the main program
								; just run off



;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func: Reverse
; Desc: Stores string2 to line 1 of data memory and stores
;		string1 to line 2 of data memory
;-----------------------------------------------------------
Reverse:							; Begin a function with a label
		; Execute the function here
		rcall LCDClr
		; Move string 2 from program memory to data memory
		LDI		ZL, LOW(STRING2_BEG<<1)	; beginning of string2 to lower byte of Z
		LDI		ZH, HIGH(STRING2_BEG<<1); next char to high byte of Z
		LDI		YL, LL1					; YL points to data memory location
		LDI		YH, HL1					; YH points to second location
		DO_R:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(STRING2_END<<1); compare z to byte after string2
			BRNE DO_R						; continue in loop if not equal
		NEXT_R:

		; Move string 1 from program memory to data memory
		LDI		ZL, LOW(STRING1_BEG<<1) ; beginning of string1 to lower byte of Z
		LDI		ZH, HIGH(STRING1_BEG<<1); next char to high byte of Z
		LDI		YL, LL2					; YL points to 2nd line of LCD
		LDI		YH, HL2					; YH points to 2nd line of data memory
		DO2_R:
			LPM mpr, Z+					; load register and post increment
			ST  Y+,  mpr				; store to data memory with post increment
			CPI ZL,  LOW(STRING1_END<<1); compare z to byte after string1
			BRNE DO2_R					; continue in loop if not equal
		NEXT2_R:

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Shift
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
Shift:							; Begin a function with a label

		; Execute the function here
		LDI		ZL, LL1			; set to first character
		LDI		ZH, HL1			; set to first character
		LDI		YL, LL1			; set to first character
		LDI		YH, HL1			; set to first character
		LD		temp, Z+		; save front in temp register
		LDI		i, $1f			; set counter 
		LOOP:
			LD mpr, Z+			; load register and post increment
			ST Y+, mpr			; store to data memory and post increment
			DEC i				; decrement counter
			BRNE LOOP			; continue in loop if not equal
		ST  Y, temp				; store previous front in back

		ret						; End a function with RET

;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
STRING1_BEG:
.DB		"Emily Becher"		; Declaring data in ProgMem
STRING1_END:

STRING2_BEG:
.DB		"Hello World!"		; Declaring data in ProgMem
STRING2_END:

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver

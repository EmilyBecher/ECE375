;***********************************************************
;*	ECE375 Lab 5: External Interrupts
;*
;*	 Author: Emily Becher
;*	   Date: November 2, 2022
;*
;***********************************************************

.include "m32U4def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
.def	waitcnt = r17			; Wait loop counter
.def	ilcnt = r18				; Inner loop counter
.def	olcnt = r19				; Outer loop counter
.def	Rcnt = r23				; right hit counter
.def	Lcnt = r24				; left hit counter

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit

.equ	WTime = 100				; Time to wait in loop

; Movement Commands
.equ	MovFwd = 0b10010000		; define MovFwd
.equ	MovBck = 0b00000000		; define MovBck
.equ	TurnR = 0b10000000		; define TurnR
.equ	TurnL = 0b00010000		; define TurnL

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

		; Set up interrupt vectors for any interrupts being used
.org	$0002					; INT0
		rcall HitRight			; Call hit right routine
		reti

.org	$0004					; INT1
		rcall HitLeft			; Call hit left routine
		reti

.org	$0008					; INT3
		rcall ClearCount		; Call clear routine
		reti

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

		; Initialize Port B for output
		ldi		mpr, 0b11110000
		out		DDRB, mpr

		; Initialize Port D for input
		ldi		mpr, (0<<WskrL)|(0<<WskrR)|(0<<3)
		out		DDRD, mpr
		ldi		mpr, (1<<WskrL)|(1<<WskrR)|(1<<3)
		out		PORTD, mpr

		; Initialize LCD
		rcall LCDInit
		rcall LCDClr		; get rid of garbage characters

		; Set hit counters to zero
		ldi		Rcnt, 0
		ldi		Lcnt, 0

		; Initialize external interrupts
			; Set the Interrupt Sense Control to falling edge (10)
		ldi		mpr, 0b10001010
		sts		EICRA, mpr

		; Configure the External Interrupt Mask
		ldi		mpr, 0b00001011
		out		EIMSK, mpr

		; Turn on interrupts
			; NOTE: This must be the last thing to do in the INIT function
		sei

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:							; The Main program

		; TODO
		ldi		mpr, movFwd
		out		PORTB, mpr

		rjmp	MAIN			; Create an infinite while loop to signify the
								; end of the program.

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
;	You will probably want several functions, one to handle the
;	left whisker interrupt, one to handle the right whisker
;	interrupt, and maybe a wait function
;------------------------------------------------------------

;-----------------------------------------------------------
; Func: HitRight
; Desc: Functionality when right whisker is triggered.
;		Backs up for 1 second then turns left for 1 second.
;		Increments the hit right counter.
;-----------------------------------------------------------
HitRight:							; Begin a function with a label

		; Save variable by pushing them to the stack
		push	XL			; save X
		push	XH
		push	mpr			; save mpr
		push	waitcnt		; save wait
		in		mpr, SREG	; save program state
		push	mpr
		
		; Execute the function here
		; Increment hit right counter
		inc		Rcnt			; increment hit right counter
		mov		mpr, Rcnt		; move count to mpr
		ldi		XL, $00			; address of line 1 to X
		ldi		XH, $01
		rcall	Bin2ASCII		; convert count to ascii
		rcall	LCDWrite		; write updated count to LCD

		; Move Backwards for 1 sec
		ldi		mpr, Movbck		; load backwards movement
		out		PORTB, mpr		; load output
		ldi		waitcnt, WTime	; wait for 1 sec
		rcall	Wait			; call wait

		; Turn left for 1 sec
		ldi		mpr, TurnL		; load left turn
		out		PORTB, mpr		; load output
		ldi		waitcnt, WTime	; wait for 1 sec
		rcall	Wait			; call wait

		; Clear interrupt queue
		ldi		mpr, 0b00001011
		out		EIFR, mpr

		; Restore variable by popping them from the stack in reverse order
		pop		mpr			; restore program state
		out		SREG, mpr	
		pop		waitcnt		; restore wait
		pop		mpr			; restore mpr
		pop		XH
		pop		XL			; restore X

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: HitLeft
; Desc: Functionality when left whisker is triggered.
;		Backs up for 1 second then turns right for 1 second.
;		Increments hit left counter
;-----------------------------------------------------------
HitLeft:							; Begin a function with a label

		; Save variable by pushing them to the stack
		push	XL			; save X
		push	XH
		push	mpr			; save mpr
		push	waitcnt		; save wait
		in		mpr, SREG	; save program state
		push	mpr

		; Execute the function here
		; Increment hit left counter
		inc		Lcnt			; increment hit left counter
		mov		mpr, Lcnt		; move count to mpr
		ldi		XL, $10			; address of line 1 to X
		ldi		XH, $01
		rcall	Bin2ASCII		; convert count to ascii
		rcall	LCDWrite		; write updated count to LCD

		; Move Backwards for 1 sec
		ldi		mpr, Movbck		; load backwards movement
		out		PORTB, mpr		; load output
		ldi		waitcnt, WTime	; wait for 1 sec
		rcall	Wait			; call wait

		; Turn left for 1 sec
		ldi		mpr, TurnR		; load right turn
		out		PORTB, mpr		; load output
		ldi		waitcnt, WTime	; wait for 1 sec
		rcall	Wait			; call wait

		; Clear interrupt queue
		ldi		mpr, 0b00001011
		out		EIFR, mpr

		; Restore variable by popping them from the stack in reverse order
		pop		mpr			; restore program state
		out		SREG, mpr	
		pop		waitcnt		; restore wait
		pop		mpr			; restore mpr
		pop		XH
		pop		XL			; restore X

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Wait
; Desc: Function waits for 10 miliseconds.
;		
;-----------------------------------------------------------
Wait:							; Begin a function with a label

		; Save variable by pushing them to the stack
		push	waitcnt		; save wait
		push	ilcnt		; save ilcnt
		push	olcnt		; save olcnt

		; Execute the function here
		Loop:	ldi		olcnt, 224	; load olcnt
		OLoop:	ldi		ilcnt, 237	; load ilcnt
		ILoop:	dec		ilcnt		; decrement ilcnt
				brne	ILoop		; continue looping if ilcnt not 0
				dec		olcnt		; decrement olcnt
				brne	OLoop		; continue looping if olcnt not 0
				dec		waitcnt		; decrement waitcnt
				brne	Loop		; continue looping if waitcnt not 0

		; Restore variable by popping them from the stack in reverse order
		pop		olcnt		; restore olcnt
		pop		ilcnt		; restore ilcnt
		pop		waitcnt		; restore waitcnt

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: ClearCount
; Desc: Clears hit right and hit left counters.
;		
;-----------------------------------------------------------
ClearCount:							; Begin a function with a label

		; Save variable by pushing them to the stack
		push	XL			; save X
		push	XH
		push	mpr			; save mpr
		in		mpr, SREG	; save program state
		push	mpr

		; Execute the function here
		; Zero hit right counter
		ldi		Rcnt, 0			; clear hit right counter
		mov		mpr, Rcnt		; move count to mpr
		ldi		XL, $00			; address of line 1 to X
		ldi		XH, $01
		rcall	Bin2ASCII		; convert count to ascii
		rcall	LCDWrite		; write updated count to LCD

		; Zero hit left counter
		ldi		Lcnt, 0			; clear hit left counter
		mov		mpr, Lcnt		; move count to mpr
		ldi		XL, $10			; address of line 2 to X
		ldi		XH, $01			
		rcall	Bin2ASCII		; convert count to ascii
		rcall	LCDWrite		; write updated count to LCD

		; Clear interrupt queue
		ldi		mpr, 0b00001011
		out		EIFR, mpr

		; Restore variable by popping them from the stack in reverse order
		pop		mpr			; restore program state
		out		SREG, mpr	
		pop		mpr			; restore mpr
		pop		XH
		pop		XL			; restore X

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Template function header
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
FUNC:							; Begin a function with a label

		; Save variable by pushing them to the stack

		; Execute the function here

		; Restore variable by popping them from the stack in reverse order

		ret						; End a function with RET

;***********************************************************
;*	Stored Program Data
;***********************************************************

; Enter any stored data you might need here

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; include LCD driver

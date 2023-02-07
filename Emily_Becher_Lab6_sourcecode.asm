;***********************************************************
;*
;*	ECE375	Lab 6: Timer/Counters
;*
;*	 Author: Emily Becher
;*	   Date: November 9, 2022
;*
;***********************************************************

.include "m32U4def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
.def	speed_curr = r17		; speed register
.def	step = r18				; step register
.def	olcnt = r19				; outer loop counter register
.def	ilcnt = r20				; inner loop counter register
.def	waitcnt = r21			; wait count register

.equ	EngEnR = 5				; right Engine Enable Bit
.equ	EngEnL = 6				; left Engine Enable Bit
.equ	EngDirR = 4				; right Engine Direction Bit
.equ	EngDirL = 7				; left Engine Direction Bit

.equ	Down = 4				; button to slow down 1
.equ	Up = 5					; button to speed up 1
.equ	Full = 6				; button to go full speed

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000
		rjmp	INIT			; reset interrupt

		; place instructions in interrupt vectors here, if needed
.org	$0002					; INT0
		rcall Speed_Down		; Call routine to slow speed
		reti

.org	$0004					; INT1
		rcall Speed_Up			; Call routine to speed up
		reti

.org	$0008					; INT3
		rcall Speed_Max			; Call rountine to go to full speed
		reti

.org	$0056					; end of interrupt vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
		; Initialize the Stack Pointer
		ldi mpr, high(RAMEND)		
		out SPH, mpr
		ldi mpr, low(RAMEND)
		out SPL, mpr

		; Configure I/O ports
		; Initialize PORTB for output
		ldi		mpr, 0b11111111		; use all 8 LEDs for output
		out		DDRB, mpr

		; Initialize PORTD for input
		ldi		mpr, (0<<Down)|(0<<Up)|(0<<Full)
		out		DDRD, mpr
		ldi		mpr, (1<<Down)|(1<<Up)|(1<<Full)	; enable pull-up resistors
		out		PORTD, mpr

		; Configure External Interrupts, if needed
		ldi		mpr, 0b10001010		; set interrupts to falling edge
		sts		EICRA, mpr
		ldi		mpr, 0b00001011		; enable interrupts
		out		EIMSK, mpr

		; Configure 16-bit Timer/Counter 1A and 1B
		; Fast PWM, 8-bit mode, no prescaling
		ldi		mpr, 0b10100001	; 8 bit Fast PWM mode
		sts		TCCR1A, mpr
		ldi		mpr, 0b00001001	; no prescale
		sts		TCCR1B, mpr
		ldi		mpr, $00
		sts		OCR1AL, mpr		; load compare registers
		sts		OCR1BL, mpr

		; Set TekBot to Move Forward (1<<EngDirR|1<<EngDirL) on Port B
		ldi		mpr, (1<<EngDirR)|(1<<EngDirL)
		out		PORTB, mpr

		; Set initial speed, display on Port B pins 3:0
		ldi		speed_curr, 15		; start at full speed
		sbi		PORTB, 3
		sbi		PORTB, 2
		sbi		PORTB, 1
		sbi		PORTB, 0

		; Set step for speed increase/decrease
		ldi		step, 17
		
		; Set waitcnt (creates a wait of about 0.1 sec)
		ldi		waitcnt, 10

		; Enable global interrupts (if any are used)
		sei

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		rjmp	MAIN			; return to top of MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func:	Speed_Down
; Desc:	Decreases tekbot speed by one speed level.
;
;-----------------------------------------------------------
Speed_Down:	; Begin a function with a label

		; If needed, save variables by pushing to the stack
		push	mpr

		; Execute the function here
		; Check for speed 0
		ldi		mpr, $00
		cp		mpr, speed_curr
		breq	EXIT

		; Increase output compare so engine enable is on longer
		lds		mpr, OCR1AL		; get current compare value
		add		mpr, step		; increase compare value by one step
		sts		OCR1AL, mpr		; store new compare value in
		sts		OCR1BL, mpr		; compare registers

		; decrease speed level by one
		ldi		mpr, 0b1001_0000	; load eng dir movement
		dec		speed_curr			; decrement speed level
		or		mpr, speed_curr		; logical or eng dir and speed level
		out		PORTB, mpr			; write new speed level to LEDs

EXIT:

		; Wait and Clear interrupt queue
		rcall	Wait				; delay so one button push results in one action
		ldi		mpr, 0b00001011		; clear interrupts
		out		EIFR, mpr

		; Restore any saved variables by popping from stack
		pop		mpr

		ret						; End a function with RET

;-----------------------------------------------------------
; Func:	Speed_Up
; Desc:	Increase tekbot speed by one level.
;		
;-----------------------------------------------------------
Speed_Up:	; Begin a function with a label

		
		; If needed, save variables by pushing to the stack
		push	mpr

		; Execute the function here
		; Check for speed 0F
		ldi		mpr, $0F
		cp		mpr, speed_curr
		breq	EXIT2

		; Decrease output compare so engine enable is on less
		lds		mpr, OCR1AL			; get current compare value
		sub		mpr, step			; subtract one step from compare value
		sts		OCR1AL, mpr			; store new compare value
		sts		OCR1BL, mpr			; in compare registers

		; increase speed level by one
		ldi		mpr, 0b1001_0000	; load eng dir
		inc		speed_curr			; increase speed level
		or		mpr, speed_curr		; logical or new speed and eng dir
		out		PORTB, mpr			; output new speed to LEDs

EXIT2:

		; Wait and Clear interrupt queue
		rcall	Wait				; delay so one button push results in one action
		ldi		mpr, 0b00001011		; clear interrupts
		out		EIFR, mpr

		; Restore any saved variables by popping from stack
		pop		mpr

		ret						; End a function with RET

;-----------------------------------------------------------
; Func:	Speed_Max
; Desc:	Sets tekbot to max speed.
;		
;-----------------------------------------------------------
Speed_Max:	; Begin a function with a label

		; If needed, save variables by pushing to the stack
		push	 mpr

		; Execute the function here
		ldi		mpr, $00		; compare value 0 so eng en is always off
		sts		OCR1AL, mpr		; load compare value in compare registers
		sts		OCR1BL, mpr

		ldi		speed_curr, 15		; set speed level to max (15)
		ldi		mpr, 0b10011111		; output speed level and eng dir to LEDs
		out		PORTB, mpr

		; Wait and Clear interrupt queue
		rcall	Wait				; delay so that one button press results in one action
		ldi		mpr, 0b00001011		; clear interrupts
		out		EIFR, mpr

		; Restore any saved variables by popping from stack
		pop mpr

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Wait
; Desc: Function waits for 10 miliseconds times waitcnt.
;		Creates a 0.1 second delay in this program.
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
; Func:	Template function header
; Desc:	Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
FUNC:	; Begin a function with a label

		; If needed, save variables by pushing to the stack

		; Execute the function here

		; Restore any saved variables by popping from stack

		ret						; End a function with RET

;***********************************************************
;*	Stored Program Data
;***********************************************************
		; Enter any stored data you might need here

;***********************************************************
;*	Additional Program Includes
;***********************************************************
		; There are no additional file includes for this program

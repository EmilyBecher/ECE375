;***********************************************************
;*
;*	This is the file for Lab 7 of ECE 375
;*
;*  	Rock Paper Scissors
;* 	Requirement:
;* 	1. USART1 communication
;* 	2. Timer/counter1 Normal mode to create a 1.5-sec delay
;***********************************************************
;*
;*	 Authors: Rabecka Moffit & Emily Becher
;*	   Date: 11/18/2022
;*
;***********************************************************

.include "m32U4def.inc"         ; Include definition file

;***********************************************************
;*  Internal Register Definitions and Constants
;***********************************************************
.def    mpr = r16               ; Multi-Purpose Register
.def	choice = r17			; User's choice
.def	opp_choice = r18		; opponent's choice
.def	data = r19
.def	check_send = r23


; Use this signal code between two boards for their game ready
; Use this signal code between two boards for their game ready
.equ    SendReady = 0b11111111
.equ	rock = 1		; encoded value for rock
.equ	paper = 2		; encoded value for paper
.equ	scissors = 3	; encdod value for scissors
.equ	LL1 = $00		; low line 1 address (LCD)
.equ	HL1 = $01		; high line 1 address (LCD)
.equ	LL2 = $10		; low line 2 address (LCD)
.equ	HL2 = $01		; high line 2 address (LCD)
.equ	count1 = 4
.equ	count2 = 5
.equ	count3 = 6
.equ	count4 = 7

;***********************************************************
;*  Start of Code Segment
;***********************************************************
.cseg                           ; Beginning of code segment

;***********************************************************
;*  Interrupt Vectors
;***********************************************************
.org    $0000                   ; Beginning of IVs
	    rjmp    INIT            	; Reset interrupt
.org	$0002	;Interrupt 0
		rcall	Iterate_Choice	; call button 4 routine
		reti
.org	$0004	;Interrupt 1
		rcall	Send_Ready		; Sends ready signal to opp
		reti
.org	$0032					;receive complete
		rcall Receive
		reti
.org    $0056                   ; End of Interrupt Vectors

;***********************************************************
;*  Program Initialization
;***********************************************************
INIT:
    ; Initialize the Stack Pointer (VERY IMPORTANT!!!!)
		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND

    ; Initialize Port B for output
		ldi		mpr, $FF		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, (1<<count4 | 1<<count3 | 1<<count2 | 1<<count1)		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low

	; Initialize Port D for input
		ldi		mpr, $00		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State
	;USART1
		;Set baudrate at 2400bps
		;Enable receiver and transmitter
		;Set frame format: 8 data bits, 2 stop bits
		ldi		mpr, 0b00100010
		sts		UCSR1A, mpr
		ldi		mpr, 0b10011000
		sts		UCSR1B, mpr
		ldi		mpr, 0b00001110
		sts		UCSR1C, mpr
		ldi		mpr, high(416)
		sts		UBRR1H, mpr
		ldi		mpr, low(416)
		sts		UBRR1L, mpr
	;TIMER/COUNTER1
		;Set Normal mode
		ldi		mpr, 0b00000100
		sts		TCCR1B, mpr
		ldi		mpr, 0b00000000
		sts		TCCR1C, mpr

	;TIMER/COUNTER3
		;Set Normal mode
		ldi		mpr, 0b00000100
		sts		TCCR3B, mpr
		ldi		mpr, 0b00000000
		sts		TCCR3C, mpr
	;Other
	; Initialize external interrupts (to trigger on falling edge)
		ldi		mpr, (1<<ISC01)|(0<<ISC00)|(1<<ISC11)|(0<<ISC10)
		sts		EICRA, mpr ; Use sts, EICRA is in extended I/O space

		; Set the External Interrupt Mask
		ldi		mpr, (1<<INT0)|(1<<INT1)
		out		EIMSK, mpr
		
		;Initialize the LCD Screen
		rcall	LCDInit
		rcall	LCDBacklightOn
		rcall	LCDCLr

		; Initialize choice register
		ldi		choice, scissors


		; Turn on interrupts
		sei	; NOTE: This must be the last thing to do in the INIT function

;***********************************************************
;*  Main Program
;***********************************************************
MAIN:
		
		; Reset variables used
		ldi		check_send, 0
		ldi		choice, scissors
		ldi		opp_choice, 0

		rcall	Write_Welcome
		; Enable button 7 interrupt
		ldi		mpr, 0b00000010
		out		EIMSK, mpr
busy_loop:
		; Check that you have received ready signal
		cpi		opp_choice, SendReady
		brne	busy_loop

busy_loop2:
		; Check that you have sent ready signal
		mov		mpr, check_send
		cpi		mpr, 1
		brne	busy_loop2
		; Enable button 4 interrupts
		ldi		mpr, 0b00000001
		out		EIMSK, mpr
		rcall	Write_Start
		rcall	Countdown
		;Disable all external interrupts
		ldi		mpr, 0b00000000
		out		EIMSK, mpr
		rcall	Transmit_Data
		rcall	Wait_Big
		rcall	Write_Opponent
		rcall	Countdown
		rcall	Result
		rcall	Countdown
		rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
;----------------------------------------------------------------
; Sub:	USART_Transmit
; Desc:	Checks that the UDR1 register is empty and then loads
;		the data to be sent into UDR1
;----------------------------------------------------------------
USART_Transmit:
	; Wait for empty transmit buffer
	lds		mpr, UCSR1A
	sbrs	mpr, 5
	rjmp	USART_Transmit
	; Put data in mpr into buffer, sends the data
	sts		UDR1, data
	ret
;----------------------------------------------------------------
; Sub:	USART1_Receive
; Desc:	Checks that a transmission has been received and then
;		takes the data from UDR1
;----------------------------------------------------------------
USART_Receive:
	; Wait for data to be received
	lds		mpr, UCSR1A
	sbrs	mpr, 7
	rjmp	USART_Receive
	; Get and return received data from buffer
	lds		mpr, UDR1
	ret
;----------------------------------------------------------------
; Sub:	Wait_Big
; Desc:	Waits for 1.5 second using timer/counter1 without busy
;		loops
;----------------------------------------------------------------
Wait_Big:
	LDI		mpr, high(18661)	; Load the value for delay
	sts		TCNT1H, mpr			; Load high byte first
	LDI		mpr, low(18661) 
	sts		TCNT1L, mpr 
LOOP_Big:
	SBIS	TIFR1, TOV1			; Skip if OCF1A flag in TIFR1 is set, OCF1A = 1
	RJMP	LOOP_Big			; Loop if OCF1A not set
	LDI		mpr, 0b00000001		; Reset OCF1A
	out		TIFR1, mpr			; Note - write 1 to reset
	ret

;----------------------------------------------------------------
; Sub:	Wait_Small
; Desc:	Waits for 20 ms second using timer/counter1 without busy
;		loops
;----------------------------------------------------------------
Wait_Small:
	LDI		mpr, high(64911)	; Load the value for delay
	sts		TCNT3H, mpr			; Load high byte first
	LDI		mpr, low(64911)
	sts		TCNT3L, mpr
LOOP_Small:
	SBIS	TIFR3, TOV3		; Skip if OCF1A flag in TIFR1 is set, OCF1A = 1
	RJMP	LOOP_Small		; Loop if OCF1A not set
	LDI		mpr, 0b00000001 ; Reset OCF1A
	out		TIFR3, mpr		; Note - write 1 to reset
	ret

;----------------------------------------------------------------
; Sub:	Send_Ready
; Desc:	Sends ready signal to opponents board
;		
;----------------------------------------------------------------
Send_Ready:
	ldi		data, SendReady			; load ready signal into mpr
	rcall	USART_Transmit			; send that value to opponent
	rcall	Write_Ready	
	inc		check_send
	rcall	Wait_Small
	ldi		mpr, 0b00000011			; reset EIFR to cancel any queuing 
	out		EIFR, mpr
	ldi		mpr, 0b00000000			; disable button 7
	out		EIMSK, mpr
	ret
;----------------------------------------------------------------
; Sub:	Receive
; Desc: Takes data from transmission
;		
;----------------------------------------------------------------
Receive:
	rcall USART_Receive		; Get data from transmission
	mov opp_choice, mpr
	ret
	
;----------------------------------------------------------------
; Sub:	Transmit_Data
; Desc:	Sends data to opponents board
;		
;----------------------------------------------------------------
Transmit_Data:
	mov		data, choice			; put data to send in data
	rcall	USART_Transmit			; send the data

;----------------------------------------------------------------
; Sub:	Countdown
; Desc:	6 second countdown with output on the top 4 LEDs
;		
;----------------------------------------------------------------
Countdown:
	; Turns on all LEDS then decrements by 1 down the line
	; The countdown is not in binary
	ldi		mpr, (1<<count4 | 1<<count3 | 1<<count2 | 1<<count1)
	out		PORTB, mpr
	rcall	Wait_Big
	ldi		mpr, (0<<count4 | 1<<count3 | 1<<count2 | 1<<count1)
	out		PORTB, mpr
	rcall	Wait_Big
	ldi		mpr, (0<<count4 | 0<<count3 | 1<<count2 | 1<<count1)
	out		PORTB, mpr
	rcall	Wait_Big
	ldi		mpr, (0<<count4 | 0<<count3 | 0<<count2 | 1<<count1)
	out		PORTB, mpr
	rcall	Wait_Big
	ldi		mpr, (0<<count4 | 0<<count3 | 0<<count2 | 0<<count1)
	out		PORTB, mpr
	ret

;----------------------------------------------------------------
; Sub:	Write_Opponent
; Desc:	Calculates and Displays final result
;		
;----------------------------------------------------------------
Write_Opponent:
	; Execute Function
	; Check Opponent's Choice
	ldi		mpr, rock
	cp		opp_choice, mpr		; Check for rock
	breq	Display_Rock
	ldi		mpr, paper
	cp		opp_choice, mpr		; Check for paper
	breq	Display_Paper
	ldi		mpr, scissors	
	cp		opp_choice, mpr		; Check for scissors
	breq	Display_Scissors

	; Display Opponent's Choice
	Display_Rock:
		rcall	Write_Rock1
		rjmp	Exit_Display
	Display_Paper:
		rcall	Write_Paper1
		rjmp	Exit_Display
	Display_Scissors:
		rcall	Write_Scissors1
	Exit_Display:
	ret
;----------------------------------------------------------------
; Sub:	Result
; Desc:	Calculates and Displays final result
;		
;----------------------------------------------------------------
Result:
	; save choice
	push	choice
	; Execute function
	
	; Determine Result
	; choice - opp_choice
	sub		choice, opp_choice

	; If 0 -> draw
	cpi		choice, 0
	breq	Draw

	; If -1 -> loss
	cpi		choice, -1
	breq	Loss
	; If 2 -> loss
	cpi		choice, 2
	breq	Loss

	; If -2 -> win
	cpi		choice, -2
	breq	Win
	; If 1 -> win
	cpi		choice, 1
	breq	Win

	; Display Result
	Draw:
		rcall	Write_Draw
		rjmp	Exit_Result
	Loss:
		rcall	Write_Loss
		rjmp	Exit_Result
	Win:
		rcall	Write_Win

	Exit_Result:
	; restore choice
	pop choice

	ret
;----------------------------------------------------------------
; Sub:	Iterate_Choice
; Desc:	Allows user to select their game choice
;		
;----------------------------------------------------------------
Iterate_Choice:

	; Execute the function here
	ldi		mpr, rock		
	cp		choice, mpr			; check if choice is rock
	breq	Paper_Choice
	ldi		mpr, paper
	cp		choice, mpr			; check if choice is paper
	breq	Scissors_Choice
	ldi		mpr, scissors
	cp		choice, mpr			; check if choice is scissors
	breq	Rock_Choice
	rjmp	Exit_Choice

	Rock_Choice:
		ldi		choice, rock	; iterate choice
		rcall	Write_Rock2		; write rock to LCD
		rjmp	Exit_Choice
	Paper_Choice:
		ldi		choice, paper ; iterate choice
		rcall	Write_Paper2	 ; write paper to LCD
		rjmp	Exit_Choice
	Scissors_Choice:
		ldi		choice, scissors	; iterate choice
		rcall	Write_Scissors2	; write scissors to LCD
	Exit_Choice: 
		; Clear Interrupt Queue
		rcall	Wait_Small		; short delay to ensure function triggers once
		ldi		mpr, 0b00000011		; clear interrupts
		out		EIFR, mpr

		ret

;-----------------------------------------------------------
; Func: Write_Welcome
; Desc: Writes Welcome Message to LCD
;		
;-----------------------------------------------------------
Write_Welcome:							; Begin a function with a label
		; Execute the function here
		rcall LCDClr
		; Move Welcome string from program memory to data memory
		LDI		ZL, LOW(String1_start<<1)	; first char to low byte
		LDI		ZH, HIGH(String1_start<<1)
		LDI		YL, LL1					; YL points to data memory location
		LDI		YH, HL1						; of line 1
		DO_Welcome:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(String1_end<<1); compare z to string end
			BRNE DO_Welcome						; continue in loop if not equal
		NEXT_Welcome:

		; Move string 2 from program memory to data memory
		LDI		ZL, LOW(String2_start<<1) ; first char to low byte
		LDI		ZH, HIGH(String2_start<<1)
		LDI		YL, LL2					; YL points to 2nd line of LCD
		LDI		YH, HL2					; YH points to 2nd line of data memory
		DO2_Welcome:
			LPM mpr, Z+					; load register and post increment
			ST  Y+,  mpr				; store to data memory with post increment
			CPI ZL,  LOW(String2_end<<1); compare z to end
			BRNE DO2_Welcome					; continue in loop if not equal
		NEXT2_Welcome:

		rcall	LCDWrite		; Write to LCD
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Write_Ready
; Desc: Writes ready message to LCD
;		
;-----------------------------------------------------------
Write_Ready:							; Begin a function with a label
		; Execute the function here
		rcall LCDClr
		; Move Ready string from program memory to data memory
		LDI		ZL, LOW(String3_start<<1)	; first char to low byte
		LDI		ZH, HIGH(String3_start<<1)
		LDI		YL, LL1					; YL points to data memory location
		LDI		YH, HL1						; in line 1
		DO_Ready:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(String3_end<<1); compare z to end
			BRNE DO_Ready						; continue in loop if not equal
		NEXT_Ready:

		; Move string 4 from program memory to data memory
		LDI		ZL, LOW(String4_start<<1) ; first char to low byte
		LDI		ZH, HIGH(String4_start<<1)
		LDI		YL, LL2					; YL points to 2nd line of LCD
		LDI		YH, HL2					; YH points to 2nd line of data memory
		DO2_Ready:
			LPM mpr, Z+					; load register and post increment
			ST  Y+,  mpr				; store to data memory with post increment
			CPI ZL,  LOW(String4_end<<1); compare z to byte after string1
			BRNE DO2_Ready					; continue in loop if not equal
		NEXT2_Ready:

		rcall	LCDWrite		; Write to LCD
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Write_Start
; Desc: Writes start message to LCD. 
;			clear line 2
;-----------------------------------------------------------
Write_Start:							; Begin a function with a label
		; Execute the function here
		rcall LCDClr
		; Move start string from program memory to data memory
		LDI		ZL, LOW(String5_start<<1)	; first char to low byte
		LDI		ZH, HIGH(String5_start<<1)
		LDI		YL, LL1					; YL points to data memory location
		LDI		YH, HL1						; in line 1
		DO_Start:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(String5_end<<1); compare z to end
			BRNE DO_Start						; continue in loop if not equal
		NEXT_Start:

		rcall	LCDWrLn1		; Write to line 1 of LCD
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Write_Win
; Desc: Write win message to LCD.
;			only updates line 1
;-----------------------------------------------------------
Write_Win:							; Begin a function with a label
		; Execute the function here
		rcall LCDClrLn1
		; Move win string from program memory to data memory
		LDI		ZL, LOW(String6_start<<1)	; first char to low byte
		LDI		ZH, HIGH(String6_start<<1)
		LDI		YL, LL1					; YL points to data memory location
		LDI		YH, HL1						; in line 1
		DO_Win:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(String6_end<<1); compare z to end
			BRNE DO_Win						; continue in loop if not equal
		NEXT_Win:

		rcall	LCDWrLn1		; Write to line 1 of LCD
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Write_Loss
; Desc: Writes loss message to LCD.
;			only updates line 1 of LCD
;-----------------------------------------------------------
Write_Loss:							; Begin a function with a label
		; Execute the function here
		rcall LCDClrLn1
		; Move lose string from program memory to data memory
		LDI		ZL, LOW(String7_start<<1)	; first char to low byte
		LDI		ZH, HIGH(String7_start<<1)
		LDI		YL, LL1					; YL points to data memory location
		LDI		YH, HL1						; in line 1
		DO_Loss:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(String7_end<<1); compare z to end
			BRNE DO_Loss						; continue in loop if not equal
		NEXT_Loss:

		rcall	LCDwrLn1		; Write to line 1 of LCD
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Write_Draw
; Desc: Writes draw message to LCD.
;			only updates line 1
;-----------------------------------------------------------
Write_Draw:							; Begin a function with a label
		; Execute the function here
		rcall LCDClrLn1
		; Move draw string from program memory to data memory
		LDI		ZL, LOW(String8_start<<1)	; first char to low byte
		LDI		ZH, HIGH(String8_start<<1)
		LDI		YL, LL1					; YL points to data memory location
		LDI		YH, HL1						; in line 1
		DO_Draw:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(String8_end<<1); compare z to end
			BRNE DO_Draw						; continue in loop if not equal
		NEXT_Draw:

		rcall		LCDWrLn1	; Write to line 1 of LCD
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Write_Rock1
; Desc: Write rock to line 1 of LCD
;		
;-----------------------------------------------------------
Write_Rock1:							; Begin a function with a label
		; Execute the function here
		rcall LCDClrLn1
		; Move rock string from program memory to data memory
		LDI		ZL, LOW(StringR_start<<1)	; first char to low byte
		LDI		ZH, HIGH(StringR_start<<1)
		LDI		YL, LL1					; YL points to data memory location
		LDI		YH, HL1						; in line 1
		DO_Rock1:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(StringR_end<<1); compare z to end
			BRNE DO_Rock1						; continue in loop if not equal
		NEXT_Rock1:

		rcall		LCDWrLn1	; Write to line 1 of LCD
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Write_Rock2
; Desc: Write rock to line 2 of LCD.
;		
;-----------------------------------------------------------
Write_Rock2:							; Begin a function with a label
		; Execute the function here
		rcall LCDClrLn2
		; Move rock string from program memory to data memory
		LDI		ZL, LOW(StringR_start<<1)	; first char to low byte
		LDI		ZH, HIGH(StringR_start<<1)
		LDI		YL, LL2					; YL points to data memory location
		LDI		YH, HL2						; in line 2
		DO_Rock2:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(StringR_end<<1); compare z to end
			BRNE DO_Rock2						; continue in loop if not equal
		NEXT_Rock2:

		rcall		LCDWrLn2	; Write to line 2 of LCD
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Write_Scissors1
; Desc: Write scissors to line 1 of LCD
;		
;-----------------------------------------------------------
Write_Scissors1:							; Begin a function with a label
		; Execute the function here
		rcall LCDClrLn1
		; Move scissors string from program memory to data memory
		LDI		ZL, LOW(StringS_start<<1)	; first char to low byte
		LDI		ZH, HIGH(StringS_start<<1)
		LDI		YL, LL1					; YL points to data memory location
		LDI		YH, HL1						; in line 1
		DO_Scissors1:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(StringS_end<<1); compare z to end
			BRNE DO_Scissors1					; continue in loop if not equal
		NEXT_Scissors1:

		rcall		LCDWrLn1	; Write to line 1 of LCD
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Write_Scissors2
; Desc: Writes scissors to line 2 of LCD
;		
;-----------------------------------------------------------
Write_Scissors2:							; Begin a function with a label
		; Execute the function here
		rcall LCDClrLn2
		; Move scissors string from program memory to data memory
		LDI		ZL, LOW(StringS_start<<1)	; first char to low byte
		LDI		ZH, HIGH(StringS_start<<1)
		LDI		YL, LL2					; YL points to data memory location
		LDI		YH, HL2						; in line 2
		DO_Scissors2:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(StringS_end<<1); compare z to end
			BRNE DO_Scissors2					; continue in loop if not equal
		NEXT_Scissors2:

		rcall		LCDWrLn2	; Write to line 2 of LCD
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Write_Paper1
; Desc: Writes paper to line 1 of LCD
;		
;-----------------------------------------------------------
Write_Paper1:							; Begin a function with a label
		; Execute the function here
		rcall LCDClrLn1
		; Move paper string from program memory to data memory
		LDI		ZL, LOW(StringP_start<<1)	; first char to low byte
		LDI		ZH, HIGH(StringP_start<<1)
		LDI		YL, LL1					; YL points to data memory location
		LDI		YH, HL1						; in line 1
		DO_Paper1:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(StringP_end<<1); compare z to end
			BRNE DO_Paper1						; continue in loop if not equal
		NEXT_Paper1:

		rcall		LCDWrLn1	; Write to line 1 of LCD
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Write_Paper2
; Desc: Writes paper to line 2 of LCd
;		
;-----------------------------------------------------------
Write_Paper2:							; Begin a function with a label
		; Execute the function here
		rcall LCDClrLn2
		; Move Welcome string from program memory to data memory
		LDI		ZL, LOW(StringP_start<<1)	; first char to low byte
		LDI		ZH, HIGH(StringP_start<<1)
		LDI		YL, LL2					; YL points to data memory location
		LDI		YH, HL2						; in line 2
		DO_Paper2:
			LPM mpr, Z+					; load register then increment Z
			ST  Y+,  mpr				; store data to data memory then increment Y
			CPI ZL,  LOW(StringP_end<<1); compare z to end
			BRNE DO_Paper2						; continue in loop if not equal
		NEXT_Paper2:

		rcall		LCDWrLn2	; Writes to line 2 of LCD
		ret						; End a function with RET

;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
String1_start:
    .DB		"Welcome!"		; Declaring data in ProgMem
String1_end:

String2_start:
	.DB		"Please press PD7"
String2_end:

String3_start:
	.DB		"Ready. Wating "
String3_end:

String4_start:
	.DB		"for the opponent"
String4_end:

String5_start:
	.DB		"Game Start"
String5_end:

String6_start:
	.DB		"You Won!"
String6_end:

String7_start:
	.DB		"You Lost"
String7_end:

String8_start:
	.DB		"Draw"
String8_end:

StringR_start:
	.DB		"Rock"
StringR_end:

StringP_start:
	.DB		"Paper "
StringP_end:

StringS_start:
	.DB		"Scissors"
StringS_end:


;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver


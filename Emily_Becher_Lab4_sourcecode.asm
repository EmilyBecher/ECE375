;***********************************************************
;*	ECE375 Lab 4: Large Number Arithmetic
;*
;*	 Author: Emily Becher
;*	   Date: October 26
;*
;***********************************************************

;***********************************************************
;
;	This file includes subroutines for 16 bit addition,
;	16 bit subtraction, 24 bit multiplication, and a 
;	routine that does an operation using all three.
;
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
.def	rlo = r0				; Low byte of MUL result
.def	rhi = r1				; High byte of MUL result
.def	zero = r2				; Zero register, set to zero in INIT, useful for calculations
.def	A = r3					; A variable
.def	B = r4					; Another variable

.def	oloop = r17				; Outer Loop Counter
.def	iloop = r18				; Inner Loop Counter


;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;-----------------------------------------------------------
; Interrupt Vectors
;-----------------------------------------------------------
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

.org	$0056					; End of Interrupt Vectors

;-----------------------------------------------------------
; Program Initialization
;-----------------------------------------------------------
INIT:							; The initialization routine

		; Initialize Stack Pointer
		ldi mpr, high(RAMEND)		
		out SPH, mpr
		ldi mpr, low(RAMEND)
		out SPL, mpr

		; TODO

		clr		zero			; Set the zero register to zero, maintain
										; these semantics, meaning, don't
										; load anything else into it.

;-----------------------------------------------------------
; Main Program
;-----------------------------------------------------------
MAIN:							; The Main program

		; Call function to load ADD16 operands
		RCALL	LOAD_ADD
		nop ; Check load ADD16 operands (Set Break point here #1)

		; Call ADD16 function to display its results (calculate FCBA + FFFF)
		RCALL	ADD16
		nop ; Check ADD16 result (Set Break point here #2)


		; Call function to load SUB16 operands
		RCALL	LOAD_SUB
		nop ; Check load SUB16 operands (Set Break point here #3)

		; Call SUB16 function to display its results (calculate FCB9 - E420)
		RCALL	SUB16
		nop ; Check SUB16 result (Set Break point here #4)


		; Call function to load MUL24 operands
		RCALL	LOAD_MUL
		nop ; Check load MUL24 operands (Set Break point here #5)

		; Call MUL24 function to display its results (calculate FFFFFF * FFFFFF)
		RCALL	MUL24
		nop ; Check MUL24 result (Set Break point here #6)

		; Setup the COMPOUND function direct test
		RCALL	LOAD_COMPOUND
		nop ; Check load COMPOUND operands (Set Break point here #7)

		; Call the COMPOUND function
		RCALL COMPOUND
		nop ; Check COMPOUND result (Set Break point here #8)

DONE:	rjmp	DONE			; Create an infinite while loop to signify the
								; end of the program.

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func: LOAD_ADD
; Desc: Loads the addition operands from program memory to  
;       data memory
;-----------------------------------------------------------
LOAD_ADD:							; Begin a function with a label
		; Save variable by pushing them to the stack

		; Execute the function here
		; Load operand 1
		LDI		ZL, LOW(OperandA<<1)	; get low byte of operand 1
		LDI		ZH, HIGH(OperandA<<1)	; get high byte of operand 1
		LPM		mpr, Z+					; load then increment
		STS		ADD16_OP1, mpr			; store to data memory
		LPM		mpr, Z					; load high byte to register
		STS		ADD16_OP1+1, mpr		; store to data memory

		; Load operand 2
		LDI		ZL, LOW(OperandB<<1)	; get low byte of operand 2
		LDI		ZH, HIGH(OperandB<<1)	; get high byte of operand 2
		LPM		mpr, Z+					; load then increment
		STS		ADD16_OP2, mpr			; store to data memory
		LPM		mpr, Z					; load high byte to register
		STS		ADD16_OP2+1, mpr		; store to data memory

		; Restore variable by popping them from the stack in reverse order

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: ADD16
; Desc: Adds two 16-bit numbers and generates a 24-bit number
;       where the high byte of the result contains the carry
;       out bit.
;-----------------------------------------------------------
ADD16:
		; Load beginning address of first operand into X
		ldi		XL, low(ADD16_OP1)	; Load low byte of address
		ldi		XH, high(ADD16_OP1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(ADD16_OP2)	; Load low byte of address
		ldi		YH, high(ADD16_OP2)	; Load high byte of address

		; Load beginning address of result into Z
		ldi		ZL, low(ADD16_Result)	; Load low byte of address
		ldi		ZH, high(ADD16_Result)	; Load high byte of address

		; Clear result
		STS		ADD16_Result, zero
		STS		ADD16_Result+1, zero
		STS		ADD16_Result+2, zero

		; Execute the function
		LD		R19, X+		; Load first byte of operand 1
		LD		R20, Y+		; Load first byte of operand 2
		ADD		R20, R19	; Add lower bytes of operands
		ST		Z+, R20		; Store result
		LD		R19, X		; Load second byte of operand 1
		LD		R20, Y		; Load second byte of operand 2
		ADC		R20, R19	; Add higher bytes with carry
		ST		Z+, R20		; Store result
		BRCC	EXIT		; Check if carry cleared
		ST		Z, XH		; Store $01 in third byte of Z
		EXIT:

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: LOAD_SUB
; Desc: Loads subtraction operands from program memory to 
;       data memory.
;-----------------------------------------------------------
LOAD_SUB:							; Begin a function with a label
		; Save variable by pushing them to the stack

		; Execute the function here
		LDI		ZL, LOW(OperandC<<1)	; get low byte of operand 1
		LDI		ZH, HIGH(OperandC<<1)	; get high byte of operand 1
		LPM		mpr, Z+					; load then increment
		STS		SUB16_OP1, mpr			; store to data memory
		LPM		mpr, Z					; load high byte to register
		STS		SUB16_OP1+1, mpr		; store to data memory

		LDI		ZL, LOW(OperandD<<1)	; get low byte of operand 2
		LDI		ZH, HIGH(OperandD<<1)	; get high byte of operand 2
		LPM		mpr, Z+					; load then increment
		STS		SUB16_OP2, mpr			; store to data memory
		LPM		mpr, Z					; load high byte to register
		STS		SUB16_OP2+1, mpr		; store to data memory

		; Restore variable by popping them from the stack in reverse order

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: SUB16
; Desc: Subtracts two 16-bit numbers and generates a 16-bit
;       result. Always subtracts from the bigger values. 
;		First operand is assumed to be larger.
;-----------------------------------------------------------
SUB16:
		; Load beginning address of first operand into X
		ldi		XL, low(SUB16_OP1)	; Load low byte of address
		ldi		XH, high(SUB16_OP1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(SUB16_OP2)	; Load low byte of address
		ldi		YH, high(SUB16_OP2)	; Load high byte of address

		; Load beginning address of result into Z
		ldi		ZL, low(SUB16_Result)	; Load low byte of address
		ldi		ZH, high(SUB16_Result)	; Load high byte of address

		; Clear Results
		STS		SUB16_Result, zero
		STS		SUB16_Result+1, zero

		; Execute function
		LD		R19, X+		; Load first byte of operand 1
		LD		R20, Y+		; Load first byte of operand 2
		SUB		R19, R20	; Add lower bytes of operands
		ST		Z+, R19		; Store result
		LD		R19, X		; Load second byte of operand 1
		LD		R20, Y		; Load second byte of operand 2
		SBC		R19, R20	; Add higher bytes with carry
		ST		Z, R19		; Store result

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: LOAD_MUL
; Desc: Load multiplication operands from program memory to
;       data memory.
;-----------------------------------------------------------
LOAD_MUL:							; Begin a function with a label
		; Save variable by pushing them to the stack

		; Execute the function here
		LDI		ZL, LOW(OperandE1<<1)	; get low byte of operand 1
		LDI		ZH, HIGH(OperandE1<<1)	; get mid byte of operand 1
		LPM		mpr, Z+					; load then increment
		STS		MUL24_OP1, mpr			; store to data memory
		LPM		mpr, Z+					; load mid byte to register
		STS		MUL24_OP1+1, mpr		; store to data memory
		LPM		mpr, Z					; load high byte to register
		STS		MUL24_OP1+2, mpr		; store to data memory

		LDI		ZL, LOW(OperandF1<<1)	; get low byte of operand 2
		LDI		ZH, HIGH(OperandF1<<1)	; get mid byte of operand 2
		LPM		mpr, Z+					; load then increment
		STS		MUL24_OP2, mpr			; store to data memory
		LPM		mpr, Z+					; load mid byte to register
		STS		MUL24_OP2+1, mpr		; store to data memory
		LPM		mpr, Z					; load high byte to register
		STS		MUL24_OP2+2, mpr		; store to data memory

		; Restore variable by popping them from the stack in reverse order

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: MUL24
; Desc: Multiplies two 24-bit numbers and generates a 48-bit
;       result.
;-----------------------------------------------------------
MUL24:
;* - Simply adopting MUL16 ideas to MUL24 will not give you steady results. You should come up with different ideas.
		
		; Load beginning address of first operand into X
		;ldi		XL, low(MUL24_OP1)	; Load low byte of address
		;ldi		XH, high(MUL24_OP1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(MUL24_OP2)	; Load low byte of address
		ldi		YH, high(MUL24_OP2)	; Load high byte of address

		; Load beginning address of result into Z
		ldi		ZL, low(MUL24_Result)	; Load low byte of address
		ldi		ZH, high(MUL24_Result)	; Load high byte of address

		; Clear result
		STS		MUL24_Result, zero
		STS		MUL24_Result+1, zero
		STS		MUL24_Result+2, zero
		STS		MUL24_Result+3, zero
		STS		MUL24_Result+4, zero
		STS		MUL24_Result+5, zero


		; Execute the function here
		; Begin outer for loop
		ldi		oloop, 3		; Load counter
		MUL24_OLOOP:
		; Set X to beginning address of A
		ldi		XL, low(MUL24_OP1)	; Load low byte
		ldi		XH, high(MUL24_OP2)	; Load high byte

		; Begin inner for loop
		ldi		iloop, 3		; Load counter
		MUL24_ILOOP:
		ld		A, X+			; Get byte of A operand
		ld		B, Y			; Get byte of B operand
		mul		A,B				; Multiply A and B
		ld		A, Z+			; Get a result byte from memory
		ld		B, Z+			; Get the next result byte from memory
		add		rlo, A			; rlo <= rlo + A
		adc		rhi, B			; rhi <= rhi + B + carry
		ld		B, Z+			; Get fourth byte of result
		adc		B, zero			; Add carry to B
		ld		A, Z			; Get a fourth byte from the result
		adc		A, zero			; Add carry to A
		st		Z, A			; Store fourth byte to memory
		st		-Z, B			; Store third byte to memory
		st		-Z, rhi			; Store second byte to memory
		st		-Z, rlo			; Store first byte to memory
		adiw	ZH:ZL, 1		; Z <= Z + 1
		dec		iloop			; Decrement counter
		brne	MUL24_ILOOP		; Loop if iLoop != 0
		; End inner for loop

		sbiw	ZH:ZL, 2		; Z <= Z - 2
		adiw	YH:YL, 1		; Y <= Y + 1
		dec		oloop			; Decrement counter
		brne	MUL24_OLOOP		; Loop if oLoop != 0
		; End outer for loop


		ret						; End a function with RET

;-----------------------------------------------------------
; Func: LOAD_COMPOUND
; Desc: Loads the subtraction operands and second addition
;       operand from program memory to data memory.
;-----------------------------------------------------------
LOAD_COMPOUND:							; Begin a function with a label
		; Save variable by pushing them to the stack

		; Execute the function here
		; Load operand G
		LDI		ZL, LOW(OperandG<<1)	; get low byte of operand 1
		LDI		ZH, HIGH(OperandG<<1)	; get high byte of operand 1
		LPM		mpr, Z+					; load then increment
		STS		SUB16_OP1, mpr			; store to data memory
		LPM		mpr, Z					; load high byte to register
		STS		SUB16_OP1+1, mpr		; store to data memory

		; Load Operand H
		LDI		ZL, LOW(OperandH<<1)	; get low byte of operand 2
		LDI		ZH, HIGH(OperandH<<1)	; get high byte of operand 2
		LPM		mpr, Z+					; load then increment
		STS		SUB16_OP2, mpr			; store to data memory
		LPM		mpr, Z					; load high byte to register
		STS		SUB16_OP2+1, mpr		; store to data memory

		; Load Operand I
		LDI		ZL, LOW(OperandI<<1)	; get low byte of operand 2
		LDI		ZH, HIGH(OperandI<<1)	; get high byte of operand 2
		LPM		mpr, Z+					; load then increment
		STS		ADD16_OP2, mpr			; store to data memory
		LPM		mpr, Z					; load high byte to register
		STS		ADD16_OP2+1, mpr		; store to data memory

		; Restore variable by popping them from the stack in reverse order

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: COMPOUND
; Desc: Computes the compound expression ((G - H) + I)^2
;       by making use of SUB16, ADD16, and MUL24.
;
;       G, H, and I are declared in program memory, and must
;       be moved into data memory for use as input operands.
;
;       All result bytes should be cleared before beginning.
;		Result bytes are cleared in arithmetic functions.
;-----------------------------------------------------------
COMPOUND:

		; Setup SUB16 with operands G and H
		; Perform subtraction to calculate G - H
		RCALL SUB16

		; Setup the ADD16 function with SUB16 result and operand I
		LDS		mpr, SUB16_Result		; get low byte SUB16 result
		STS		ADD16_OP1, mpr			; store SUB16 result to ADD16 operand 1 (low byte)
		LDS		mpr, SUB16_Result+1		; get high byte
		STS		ADD16_OP1+1, mpr		; store high byte
		; Perform addition next to calculate (G - H) + I
		RCALL ADD16

		; Setup the MUL24 function with ADD16 result as both operands
		LDS		mpr, ADD16_Result		; get low byte of ADD16 result
		STS		MUL24_OP1, mpr			; store low byte to operand 1
		STS		MUL24_OP2, mpr			; store low byte to operand 2
		LDS		mpr, ADD16_Result+1		; get mid byte of ADD16 result
		STS		MUL24_OP1+1, mpr			; store mid byte to operand 1
		STS		MUL24_OP2+1, mpr			; store mid byte to operand 2
		LDS		mpr, ADD16_Result+2		; get high byte of ADD16 result
		STS		MUL24_OP1+2, mpr			; store high byte to operand 1
		STS		MUL24_OP2+2, mpr			; store high byte to operand 2
		; Perform multiplication to calculate ((G - H) + I)^2
		RCALL MUL24

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: MUL16
; Desc: An example function that multiplies two 16-bit numbers
;       A - Operand A is gathered from address $0101:$0100
;       B - Operand B is gathered from address $0103:$0102
;       Res - Result is stored in address
;             $0107:$0106:$0105:$0104
;       You will need to make sure that Res is cleared before
;       calling this function.
;-----------------------------------------------------------
MUL16:
		push 	A				; Save A register
		push	B				; Save B register
		push	rhi				; Save rhi register
		push	rlo				; Save rlo register
		push	zero			; Save zero register
		push	XH				; Save X-ptr
		push	XL
		push	YH				; Save Y-ptr
		push	YL
		push	ZH				; Save Z-ptr
		push	ZL
		push	oloop			; Save counters
		push	iloop

		clr		zero			; Maintain zero semantics

		; Set Y to beginning address of B
		ldi		YL, low(addrB)	; Load low byte
		ldi		YH, high(addrB)	; Load high byte

		; Set Z to begginning address of resulting Product
		ldi		ZL, low(LAddrP)	; Load low byte
		ldi		ZH, high(LAddrP); Load high byte

		; Begin outer for loop
		ldi		oloop, 2		; Load counter
MUL16_OLOOP:
		; Set X to beginning address of A
		ldi		XL, low(addrA)	; Load low byte
		ldi		XH, high(addrA)	; Load high byte

		; Begin inner for loop
		ldi		iloop, 2		; Load counter
MUL16_ILOOP:
		ld		A, X+			; Get byte of A operand
		ld		B, Y			; Get byte of B operand
		mul		A,B				; Multiply A and B
		ld		A, Z+			; Get a result byte from memory
		ld		B, Z+			; Get the next result byte from memory
		add		rlo, A			; rlo <= rlo + A
		adc		rhi, B			; rhi <= rhi + B + carry
		ld		A, Z			; Get a third byte from the result
		adc		A, zero			; Add carry to A
		st		Z, A			; Store third byte to memory
		st		-Z, rhi			; Store second byte to memory
		st		-Z, rlo			; Store first byte to memory
		adiw	ZH:ZL, 1		; Z <= Z + 1
		dec		iloop			; Decrement counter
		brne	MUL16_ILOOP		; Loop if iLoop != 0
		; End inner for loop

		sbiw	ZH:ZL, 1		; Z <= Z - 1
		adiw	YH:YL, 1		; Y <= Y + 1
		dec		oloop			; Decrement counter
		brne	MUL16_OLOOP		; Loop if oLoop != 0
		; End outer for loop

		pop		iloop			; Restore all registers in reverves order
		pop		oloop
		pop		ZL
		pop		ZH
		pop		YL
		pop		YH
		pop		XL
		pop		XH
		pop		zero
		pop		rlo
		pop		rhi
		pop		B
		pop		A
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Template function header
; Desc: Cut and paste this and fill in the info at the
;       beginning of your functions
;-----------------------------------------------------------
FUNC:							; Begin a function with a label
		; Save variable by pushing them to the stack

		; Execute the function here

		; Restore variable by popping them from the stack in reverse order
		ret						; End a function with RET


;***********************************************************
;*	Stored Program Data
;*	Do not  section.
;***********************************************************
; ADD16 operands
OperandA:
	.DW 0xFCBA
OperandB:
	.DW 0xFFFF
	;Result is 0x01FCB9

; SUB16 operands
OperandC:
	.DW 0XFCB9
OperandD:
	.DW 0XE420
	;Result C-D = 0x001899

; MUL24 operands
OperandE1:
	.DW	0XFFFF
OperandE2:
	.DW	0X00FF
OperandF1:
	.DW	0XFFFF
OperandF2:
	.DW	0X00FF
	;Result 0xFFFF FE00 0001

; Compoud operands
OperandG:
	.DW	0xFCBA				; test value for operand G
OperandH:
	.DW	0x2022				; test value for operand H
OperandI:
	.DW	0x21BB				; test value for operand I
	;Result 0xFCA8 CEE9

;***********************************************************
;*	Data Memory Allocation
;***********************************************************
.dseg
.org	$0100				; data memory allocation for MUL16 example
addrA:	.byte 2
addrB:	.byte 2
LAddrP:	.byte 4

; Below is an example of data memory allocation for ADD16.
; Consider using something similar for SUB16 and MUL24.
.org	$0110				; data memory allocation for operands
ADD16_OP1:
		.byte 2				; allocate two bytes for first operand of ADD16
ADD16_OP2:
		.byte 2				; allocate two bytes for second operand of ADD16

.org	$0120				; data memory allocation for results
ADD16_Result:
		.byte 3				; allocate three bytes for ADD16 result

; Data memory allocation for SUB16
.org	$012C				; data memory allocation for operands
SUB16_OP1:
		.byte 2				; allocate two bytes for first operand
SUB16_OP2:
		.byte 2				; allocate two bytes for second operand
.org	$0142				; data memory allocation for result
SUB16_Result:
		.byte 2				; allocate two bytes for SUB16 result

; Data memory allocation for MUL24
.org	$0158				; data memory allocation for operands
MUL24_OP1:
		.byte 3				; allocate three bytes for first operand
MUL24_OP2:
		.byte 3				; allocate three bytes for second operand
.org	$016E				; data memory allocation for result
MUL24_Result:
		.byte 6				; allocate six bytes for result

;***********************************************************
;*	Additional Program Includes
;***********************************************************
; There are no additional file includes for this program

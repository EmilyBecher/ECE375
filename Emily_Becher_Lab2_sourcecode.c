/*
 *
 * Created: 10/5/2022 
 * Author : Emily Becher
 *
 */ 

/*
PORT MAP
Port B, Pin 5 -> Output -> Right Motor Enable
Port B, Pin 4 -> Output -> Right Motor Direction
Port B, Pin 6 -> Output -> Left Motor Enable
Port B, Pin 7 -> Output -> Left Motor Direction
Port D, Pin 5 -> Input -> Left Whisker
Port D, Pin 4 -> Input -> Right Whisker
*/
#define F_CPU 16000000
#include <avr/io.h>
#include <util/delay.h>
#include <stdio.h>

/* Functions */
void HitRight();
void HitLeft();

/*
This code will cause a TekBot connected to the AVR board to
move forward and when it touches an obstacle, it will reverse
and turn away from the obstacle and resume forward motion.

When both whiskers are triggered the Tekbot will back up and 
turn left.
*/

int main(void)
{
	DDRB = 0b11110000;      // configure Port B pins for output
	PORTB = 0b11110000;     // set initial value for Port B outputs
	// (initially, disable both motors)
	
	DDRD = 0b00000000;		// configure Port D pins for input
	PORTD = 0b11111111;		// enable pull-up resistors

	while (1) // loop forever
	{
		PORTB = 0b10010000;		// make TekBot move forward
		uint8_t mpr = PIND & 0b00110000; //Extract only bits 4 and 5
		if ((mpr == 0b00100000) | (mpr == 0b00000000)) { //check if right or both whiskers triggered
			HitRight(); //perform HitRight routine
		}
		else if (mpr == 0b00010000) { //check if left whisker is triggered
			HitLeft(); // perform HitLeft routine
		}
	}
}

void HitRight () {
	PORTB = 0b00000000; //make Tekbot move backward
	_delay_ms(2000); //wait for 2 seconds
	PORTB = 0b00010000; //make Tekbot turn left
	_delay_ms(1000); //wait for 1 second
	return;
}

void HitLeft () {
	PORTB = 0b00000000; //make Tekbot move backward
	_delay_ms(2000); //wait for 2 seconds
	PORTB = 0b10000000; // make Tekbot turn right
	_delay_ms(1000); // wait for 1 second
	return;
}

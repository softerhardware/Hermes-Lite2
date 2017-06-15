//
//  Power Supply Controller for Hermes Lite V2 and SBC(Raspberry Pi) System
//
//  Device: PIC12F1822
//  Compiler: Microchip XC8
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
// (C) Takashi Komatsumoto JI1UDD 2017

#include <xc.h>
#include <math.h>

__CONFIG(CLKOUTEN_OFF & FOSC_INTOSC & FCMEN_OFF & IESO_OFF & BOREN_ON &
         PWRTE_ON & WDTE_OFF & MCLRE_OFF & CP_OFF & CPD_OFF) ;
__CONFIG(PLLEN_OFF & STVREN_ON & WRT_OFF & BORV_LO & LVP_OFF);

#define SBC_SDREQ    PORTAbits.RA0
#define SBC_STATUS   PORTAbits.RA1
#define KEYOUT       PORTAbits.RA2
#define PUSHSW       PORTAbits.RA3
#define HL2_PEN      PORTAbits.RA4
#define SBC_PEN      PORTAbits.RA5

#define KEYON         0
#define KEYOFF        1
#define	KEYCNT_LONG2  700		// 7sec
#define	KEYCNT_LONG	  300		// 3sec
#define	KEYCNT_SHORT  3
#define KEYDET_NONE   0
#define KEYDET_SHORT  1
#define KEYDET_LONG   2
#define KEYDET_LONG2  3

#define Key_pulse_width   10	//  100ms; assertion period
#define Power_off_delay  600	//  6sec; period after SBC active status stop
#define Sleep_delay     1000	// 10sec

static unsigned char keycode, precode, valcode, state ;
static int key_cnt, delay_cnt ;

void goto_sleep(void);
void check_key(void);
void state_controll(void);
void port_output(void);

/* Main Routine */
void main() {

   OSCCON = 0b00111010;     // Disable 4xPLL, Select internal 500kHz OSC
   OPTION_REG = 0b11111111; // Disable PullUp
   WPUA   = 0b00000000;     // Disable PullUp
   ANSELA = 0b00000000;     // Set RA4(AN3),RA2(AN2),RA0(AN0) as digital I/O
   PORTA  = 0b00000000;     // Clear RA5-0
   TRISA  = 0b00001010;     // Set RA3(PUSHSW),RA1(SBC_STATUS) as input port
   IOCAP  = 0b00000010;     // Set RA1 as pos/neg edge IOC
   IOCAN  = 0b00000010;
   INTCON = 0b00001000;     // GIE=0, IOCIE=1

   T2CON  = 0b01001000;     // PreScaler=1:1, PostScaler=1:10, 
   PR2 = 124 ;              // (fosc/4)/1/125/10 -> 10mS
   TMR2IF = 0; 
   TMR2ON = 1;              // Start Timer2

   precode = KEYOFF ;
   valcode = KEYDET_NONE ;
   state = 0 ;
   delay_cnt = Sleep_delay ;

   while (1) {
      if ( TMR2IF == 1 ) {   // Loop 10mS
         TMR2IF = 0 ;
         goto_sleep();
         check_key();
         state_controll();
         port_output();
      }
   }
}


/* save standby current*/
void goto_sleep(void) {
   if (state == 0) {
      if (delay_cnt == 0) {
         IOCAP  = 0b00000000;     // Set RA3 as neg edge IOC
         IOCAN  = 0b00001000;
         IOCAF  = 0;
         SLEEP();
         NOP();
         NOP();
         IOCAP  = 0b00000010;     // Set RA1 as pos/neg edge IOC
         IOCAN  = 0b00000010;
         IOCAF  = 0;
         delay_cnt = Sleep_delay ;
      } else {
         delay_cnt --;
      }
   } 
}

/* check Push-SW */
void check_key(void) {
   keycode = KEYDET_NONE ;

   if (PUSHSW == KEYOFF) {
      precode = KEYOFF ;
      keycode = valcode ;
      valcode = KEYDET_NONE ;
   } else if ( precode == KEYOFF ) { 
      precode = KEYON ;
      key_cnt = 0 ; 
   } else if ( key_cnt < KEYCNT_LONG2 ) {
      key_cnt ++ ;
      if ( key_cnt  == KEYCNT_SHORT )  {
         valcode = KEYDET_SHORT ; 
      } else if ( key_cnt == KEYCNT_LONG )  {
         if (state != 0) {
           keycode = KEYDET_LONG ;
           valcode = KEYDET_NONE ;
         } else {
           valcode = KEYDET_LONG ;
         }
      } else if ( key_cnt == KEYCNT_LONG2 ) {
         keycode = KEYDET_LONG2 ;
         valcode = KEYDET_NONE ;
      }
   }
}

/* state controll */
void state_controll(void) {
   switch(state) {
      case 0: // Power OFF
              if (keycode == KEYDET_SHORT) {
                 state = 1 ;
              } else if (keycode == KEYDET_LONG) {
                 state = 5 ;
              } else if (keycode == KEYDET_LONG2) {
                 state = 3;
              }
              break ;

      case 1: // Power ON
              if (keycode == KEYDET_SHORT) {
                 state = 2 ;
                 delay_cnt = Key_pulse_width ;
              } else if (keycode >= KEYDET_LONG) {
                 state = 4 ;
                 IOCAF = 0 ;  // clear IOC flag
                 delay_cnt = Power_off_delay ;
              }
              break ;

      case 2: // detect short key during SBC Power ON
              if ( delay_cnt == 0 ) {          // timeover?
                 if ( HL2_PEN ==1) {           // Yes
                    state = 1;                 //   HL2 ON  then all PowerON state
                 } else {
                    state = 3;                 //   HL2 OFF then Only SBC PowerON state
                 }
              } else {
                 delay_cnt -- ;                // No
              }
              break ;

      case 3: // Only SBC Power ON
              if (keycode == KEYDET_SHORT) {
                 state = 2 ;
                 delay_cnt = Key_pulse_width ;
              } else if (keycode >= KEYDET_LONG) {
                 state = 4 ;
                 IOCAF = 0 ;  // clear IOC flag
                 delay_cnt = Power_off_delay ;
              }
              break ;

      case 4: // Shut down request to SBC, HL2 Power OFF
              if (IOCAF != 0) {                // if detect H->L edge on RA1
                 IOCAF = 0 ;                   // clear IOC flag
                 delay_cnt = Power_off_delay ; // initialize delay counter
              } else if (delay_cnt == 0) {     // timeover?
                 state = 0 ;                   // Yes, then PowerOFF state
                 delay_cnt = Sleep_delay ;
              } else {
                 delay_cnt -- ;                // No
              }
              break ;

      case 5: // Only HL2 Power ON
              if (keycode == KEYDET_SHORT) {
                 state = 1 ;
              } else if(keycode >= KEYDET_LONG) {
                 state = 0 ;
                 delay_cnt = Sleep_delay ;
              }
              break ;

     default: state = 0 ;
              break ;
   }
}

/* Port Output */
void port_output(void) {
   switch(state) {
      case 0: HL2_PEN   = 0 ;	// Power OFF
              SBC_PEN   = 0 ;
              KEYOUT    = 0 ;
              SBC_SDREQ = 0 ;
              break ;

      case 1: HL2_PEN   = 1 ;	// Power ON
              SBC_PEN   = 1 ;
              KEYOUT    = 0 ;
              SBC_SDREQ = 0 ;
              break ;

      case 2: KEYOUT    = 1 ;	// decect short key during SBC Power ON 
              break ;

      case 3: HL2_PEN   = 0 ;	// Only SBC Power ON 
              SBC_PEN   = 1 ;
              KEYOUT    = 0 ;
              SBC_SDREQ = 0 ;
              break ;

      case 4: HL2_PEN   = 0 ;	// Shut down request to SBC, HL2 Power OFF
              SBC_PEN   = 1 ;
              KEYOUT    = 0 ;
              SBC_SDREQ = 1 ;
              break ;

      case 5: HL2_PEN   = 1 ;	// Only HL2 Power ON
              SBC_PEN   = 0 ;
              KEYOUT    = 0 ;
              SBC_SDREQ = 0 ;
              break ;

     default: HL2_PEN   = 0 ;
              SBC_PEN   = 0 ;
              KEYOUT    = 0 ;
              SBC_SDREQ = 0 ;
              break ;
   }
}

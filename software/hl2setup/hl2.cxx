#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#include <inaddr.h>
#pragma comment(lib, "Ws2_32.lib")
#else
#include <stdlib.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#endif

#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <math.h>

#include <string>
#include <iostream>

#ifdef _WIN32
#define QUISK_SHUT_RD	SD_RECEIVE
#define QUISK_SHUT_BOTH	SD_BOTH
#define close__socket	closesocket
static int cleanupWSA = 0;			// Must we call WSACleanup() ?
#else
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#define INVALID_SOCKET	-1
#define QUISK_SHUT_RD	SHUT_RD
#define QUISK_SHUT_BOTH	SHUT_RDWR
#define close__socket	close
#endif

#include <hl2.h>

static int rx_discover_socket = INVALID_SOCKET;		// Socket used to discover the hardware
static int rx_udp_socket = INVALID_SOCKET;		// Socket for receiving ADC samples from UDP
static int quisk_rx_udp_started;
double hermes_temperature;		// average temperature
double hermes_pa_current;		// average power amp current
double hermes_fwd_power;		// average forward power from filter board
double hermes_rev_power;		// average reverse power from filter board
double hermes_sample_rms;		// sample average voltage dB below clipping
float pwr1p8;		// measured PA power at 1.8 MHz
float pwr30;		// measured PA power at 30 MHz
static char status120[120];		// status message to display
static char output120[120];		// output window message to display
static int tests_total;
static int tests_failed;

// Special hardware commands.  The request bit is always set.
static unsigned char hw_command[5];	// Special command sent to hardware, C0 through C4.
static int hw_command_state;		// State of command. Set to 1 to start then count up. Finally 0 for success, -1 for error.
static double hw_command_start;		// The time the command was first sent.

// Send these to the hardware:
int hermes_key_down=0;			// The MOX bit 0 or 1
int hermes_rx_freq=7200000;		// 32-bit integer
int hermes_tx_freq=7201000;		// 32-bit integer
int hermes_enable_power_amp;		// 0 or 1
double hermes_spot_level=0;		// Spot level 0.0 to 1.0
int hermes_tx_drive_level=255;		// transmitter drive level, 8-bit unsigned integer 0 to 255
int hermes_Q5_switch_ext_ptt_lp;	// Q5 switch external PTT in low power mode, 0 or 1
int hermes_lna_gain;			// LNA gain -12 to +48 dB
int hermes_filter_rx = 0x0;		// open collector outputs on Hermes; Rx and Tx filters; default no HPF
int hermes_filter_tx;
int alex_hpf_rx;			// 8-bit integer for hpf/lpf for rx/tx
int alex_lpf_rx;
int alex_hpf_tx;
int alex_lpf_tx;

int code_version;
int board_id;
char mac_address[ADR_SIZE];
char ip_address[ADR_SIZE];
int hermes_run_state = STATE_IDLE;
int hermes_power_button;

static void quisk_hermes_tx_send(void);
static void Bias0code(int);
static void Bias1code(int);
static int read_rx_udp10(int);
static int CheckResult(const char *, double, double, double, const char *);
static void InitParams(void);

#define SHORT_TIME	(63 * 2 * 6 * 2)	// Enough samples for all changed C0 to be sent, plus a delay
#define LONG_TIME	(63 * 2 * 20)		// A longer number of samples to allow for a better average of received data
// Set a delay, and then change to the current state + 1
#define DELAY_NEXT	{next_state = hermes_run_state + 1; hermes_run_state = STATE_SAMPLE_DELAY;}
#define LONG_DELAY_NEXT	{next_state = hermes_run_state + 1; hermes_run_state = STATE_TIME_DELAY; delay_time = QuiskTimeSec() + 0.30;}
void HL2Run(void)
{
	int i;
	unsigned char buf64[64];
	static int next_state, bias0, bias1;
	static int want_samples = SHORT_TIME;
	static int read_count = 0;
	static int do_all_tests;
	static double delay_time = 0;
	static double rms_ref;

	read_rx_udp10(63 * 2 * 50); //want_samples);
	want_samples = SHORT_TIME;
	if (hw_command_state > 0 && hw_command_start - QuiskTimeSec() > COMMAND_TOTAL_SEC)		// timeout
		hw_command_state = -1;	// failure

	switch (hermes_run_state) {
	case STATE_IDLE:	// Wait for the user to press the Set Bias key or start a test
		break;
	case STATE_TIME_DELAY:	// delay for a time in seconds
		if (QuiskTimeSec() >= delay_time)
			hermes_run_state = next_state;
		break;
	case STATE_SAMPLE_DELAY:	// delay for a short or long number of samples
		// The last read_rx_udp10() sent all C0 plus a delay
		want_samples = LONG_TIME;	// Next read for a longer time and a better average
		hermes_run_state = next_state;
		break;
	case STATE_START_TESTS:
		do_all_tests = 1;
		tests_total = tests_failed = 0;
		hermes_run_state = BACKGROUND_NOISE;
		WriteOutput("Start of tests...");
		break;
	case BACKGROUND_NOISE:
		InitParams();
		hermes_lna_gain = 19;
		hermes_rx_freq = 1900000;
		WriteOutput("Test the background noise level");
		DELAY_NEXT
		break;
	case BACKGROUND_NOISE + 1:
		snprintf(output120, 120, "Noise level on 160m is %.0f", hermes_sample_rms);
		CheckResult(output120, hermes_sample_rms, -103.0, 0.10, NULL);
		hermes_rx_freq = 14000000;
		DELAY_NEXT
		break;
	case BACKGROUND_NOISE + 2:
		snprintf(output120, 120, "Noise level on 20m is %.0f", hermes_sample_rms);
		CheckResult(output120, hermes_sample_rms, -104.0, 0.10, NULL);
		hermes_rx_freq = 29000000;
		DELAY_NEXT
		break;
	case BACKGROUND_NOISE + 3:
		snprintf(output120, 120, "Noise level on 10m is %.0f", hermes_sample_rms);
		CheckResult(output120, hermes_sample_rms, -104.0, 0.10, NULL);
		hermes_rx_freq = 14000000;
		hermes_lna_gain = -12;
		DELAY_NEXT
		break;
	case BACKGROUND_NOISE + 4:
		snprintf(output120, 120, "Noise level on 20m at -12 dB LNA is %.0f", hermes_sample_rms);
		CheckResult(output120, hermes_sample_rms, -109.0, 0.10, NULL);
		hermes_lna_gain = +48;
		DELAY_NEXT
		break;
	case BACKGROUND_NOISE + 5:
		snprintf(output120, 120, "Noise level on 20m at +48 dB LNA is %.0f", hermes_sample_rms);
		CheckResult(output120, hermes_sample_rms, -85.0, 0.20, NULL);
		hermes_run_state = SIGNAL_LEVEL;
		break;
	case SIGNAL_LEVEL:
		InitParams();
		WriteOutput("Test the feedback signal level");
		hermes_enable_power_amp = 0;
		hermes_Q5_switch_ext_ptt_lp = 1;
		hermes_filter_tx = 0;
		hermes_filter_rx = 0;
		hermes_spot_level = 1.0;
		hermes_key_down = 1;
		hermes_lna_gain = 0;
		hermes_tx_drive_level = 255;
		hermes_rx_freq = 1900000;
		hermes_tx_freq = 1901000;
		DELAY_NEXT
		break;
	case SIGNAL_LEVEL + 1:
		snprintf(output120, 120, "Signal level on 160m is %.0f", hermes_sample_rms);
		CheckResult(output120, hermes_sample_rms, -29.0, 0.10, NULL);
		hermes_rx_freq = 3500000;
		hermes_tx_freq = 3501000;
		DELAY_NEXT
		break;
	case SIGNAL_LEVEL + 2:
		snprintf(output120, 120, "Signal level on 80m is %.0f", hermes_sample_rms);
		CheckResult(output120, hermes_sample_rms, -29.0, 0.10, NULL);
		hermes_rx_freq = 14000000;
		hermes_tx_freq = 14001000;
		DELAY_NEXT
		break;
	case SIGNAL_LEVEL + 3:
		rms_ref = hermes_sample_rms;	// save 20m sample RMS for test of LNA and Tx drive
		snprintf(output120, 120, "Signal level on 20m is %.0f", hermes_sample_rms);
		CheckResult(output120, hermes_sample_rms, -28.0, 0.10, NULL);
		hermes_rx_freq = 29000000;
		hermes_tx_freq = 29001000;
		DELAY_NEXT
		break;
	case SIGNAL_LEVEL + 4:
		snprintf(output120, 120, "Signal level on 10m is %.0f", hermes_sample_rms);
		CheckResult(output120, hermes_sample_rms, -30.0, 0.10, NULL);
		hermes_tx_drive_level = 125;
		hermes_rx_freq = 14000000;
		hermes_tx_freq = 14001000;
		DELAY_NEXT
		break;
	case SIGNAL_LEVEL + 5:
		snprintf(output120, 120, "Signal level 20m at -3.5 dB tx drive is %.0f", hermes_sample_rms);
		CheckResult(output120, hermes_sample_rms, rms_ref - 3.5, 0.10, "HL2 U7");
		hermes_tx_drive_level = 0;
		DELAY_NEXT
		break;
	case SIGNAL_LEVEL + 6:
		snprintf(output120, 120, "Signal level 20m at -7.5 dB tx drive is %.0f", hermes_sample_rms);
		CheckResult(output120, hermes_sample_rms, rms_ref - 7.5, 0.10, "HL2 U7");
		rms_ref = hermes_sample_rms; // Save at -7.5 dB TX
		hermes_lna_gain = 10;
		DELAY_NEXT
		break;
	case SIGNAL_LEVEL + 7:
		snprintf(output120, 120, "Signal level 20m at +10 dB LNA is %.0f", hermes_sample_rms);
		CheckResult(output120, hermes_sample_rms, rms_ref + 10.0, 0.10, "HL2 U7");
		hermes_lna_gain = 19;
		DELAY_NEXT
		break;
	case SIGNAL_LEVEL + 8:
		snprintf(output120, 120, "Signal level 20m at +19 dB LNA is %.0f", hermes_sample_rms);
		CheckResult(output120, hermes_sample_rms, rms_ref + 19.0, 0.10, "HL2 U7");
		hermes_run_state = FILTER_BOARD;
		break;
	case FILTER_BOARD:
		InitParams();
		WriteOutput("Test the filters");
		hermes_enable_power_amp = 0;
		hermes_Q5_switch_ext_ptt_lp = 1;
		hermes_filter_tx = 0;
		hermes_filter_rx = 0;
		hermes_spot_level = 1.0;
		hermes_key_down = 1;
		hermes_lna_gain = 10;
		hermes_tx_drive_level = 0;
		hermes_tx_freq = hermes_rx_freq = 1900000;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 1:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -27.0, 0.15, NULL);
		hermes_filter_tx = FILTER_160;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 2:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -27.0, 0.10, "N2ADR L5 L6 C21 C22 C23 K1");
		hermes_tx_freq = hermes_rx_freq = 3800000;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 3:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -50.0, 0.10, "N2ADR L5 L6 C21 C22 C23 K1");
		hermes_filter_tx = FILTER_80;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 4:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -27.0, 0.10, "N2ADR L1 L2 C8 C9 C10 K2");
		hermes_tx_freq = hermes_rx_freq = 7100000;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 5:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -48.0, 0.10, "N2ADR L1 L2 C8 C9 C10 K2");
		hermes_filter_tx = FILTER_60_40;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 6:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -28.0, 0.10, "N2ADR L9 L12 C32 C35 C37 C40 C42 K3");
		hermes_tx_freq = hermes_rx_freq = 14200000;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 7:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -61.0, 0.10, "N2ADR L9 L12 C32 C35 C37 C40 C42 K3");
		hermes_filter_tx = FILTER_30_20;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 8:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -27.0, 0.10, "N2ADR L10 L13 C33 C36 C38 C41 C43 K4");
		hermes_tx_freq = hermes_rx_freq = 28400000;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 9:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -55.0, 0.10, "N2ADR L10 L13 C33 C36 C38 C41 C43 K4");
		hermes_filter_tx = FILTER_17_15;
		hermes_tx_freq = hermes_rx_freq = 21100000;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 10:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -28.0, 0.10, "N2ADR L11 L14 C34 C39 C44 K5");
		hermes_tx_freq = hermes_rx_freq = 30000000;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 11:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -37.0, 0.10, "N2ADR L11 L14 C34 C39 C44 K5");
		hermes_filter_tx = FILTER_12_10;
		hermes_tx_freq = hermes_rx_freq = 29000000;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 12:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -29.0, 0.10, "N2ADR L7 L8 C24 C25 C26 K6");
		hermes_tx_freq = hermes_rx_freq = 34000000;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 13:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -40.0, 0.10, "N2ADR L7 L8 C24 C25 C26 K6");
		hermes_filter_tx = 0;
		hermes_tx_freq = hermes_rx_freq = 36000000; // Checks HL2 filters
		DELAY_NEXT
		break;
	case FILTER_BOARD + 14:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -49.0, 0.10, "HL2 L10 L11 C53-C57");
		hermes_filter_tx = FILTER_HPF;
		hermes_tx_freq = hermes_rx_freq = 1900000;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 15:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -41.0, 0.10, "N2ADR L4 L15 C47 C48 C49 K7");
		hermes_tx_freq = hermes_rx_freq = 3500000;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 16:
		snprintf(output120, 120, "Signal level when tx=%d is %.0f with filter 0x%02x", 
			hermes_tx_freq,hermes_sample_rms,hermes_filter_tx);
		CheckResult(output120, hermes_sample_rms, -27.0, 0.10, "N2ADR L4 L15 C47 C48 C49 K7");
		hermes_filter_tx = 0;
		hermes_key_down = 0;
		DELAY_NEXT
		break;
	case FILTER_BOARD + 17:
		snprintf(output120, 120, "PA current is %.1f", hermes_pa_current * 1000);
		CheckResult(output120, hermes_pa_current * 1000, 1.0, 1.0, NULL);

		if (tests_failed > 0) {
			// Skip bias and high power tests if any failures
			snprintf(output120, 120, "Skipped bias and PA tests due to early failures");
			CheckResult(output120, 1.0, 10.0, 0.10, NULL);			
			hermes_run_state = END_OF_TESTS;
		} else {
			hermes_run_state = SET_BIAS;
		}
		break;

	case STATE_START_SET_BIAS:
		do_all_tests = 0;
		InitParams();
		hermes_run_state = SET_BIAS;
		break;

	case SET_BIAS:		// User pressed the Set Bias key.  Set bias 0 to zero.
		if (do_all_tests)
			WriteOutput("Set the bias on the power output transistors...");
		hermes_enable_power_amp = 1;
		hermes_spot_level = 0.0;
		next_state = SET_BIAS + 2;
		bias0 = bias1 = 70;
		Bias0code(0);
		hermes_run_state = WAIT_STATE;
		break;
	case SET_BIAS + 2:		// Set bias 1 to zero.
		next_state = SET_BIAS + 3;
		Bias1code(0);	// Set bias 1 to zero;
		hermes_run_state = WAIT_STATE;
		break;
	case SET_BIAS + 3:		// Increase bias 0 until power amp current is 0.1 amps
		next_state = SET_BIAS + 3;
		hermes_key_down = 1;
		if (hermes_pa_current > 0.10) {
			hermes_run_state = SET_BIAS + 4;
			hermes_key_down = 0;
		}
		else if (bias0 >= 100 && hermes_pa_current < 0.010) {
			hermes_key_down = 0;
			hermes_run_state = ERROR_STATE;
			snprintf(status120, 120, "Error: Bias0 code 100 but low bias current < 10 ma");
			WriteStatus(status120);
		}
		else {
			Bias0code(++bias0);
			hermes_run_state = WAIT_STATE;
			snprintf(status120, 120, "Sending bias code %d for first transistor", bias0);
			WriteStatus(status120);
		}
		break;
	case SET_BIAS + 4:		// Set bias 0 to zero.
		next_state = SET_BIAS + 5;
		Bias0code(0);
		hermes_run_state = WAIT_STATE;
		break;
	case SET_BIAS + 5:		// Increase bias 1 until power amp current is 0.1 amps
		next_state = SET_BIAS + 5;
		hermes_key_down = 1;
		if (hermes_pa_current > 0.10) {
			hermes_run_state = SET_BIAS + 6;
			hermes_key_down = 0;
		}
		else if (bias1 >= 100 && hermes_pa_current < 0.010) {
			hermes_key_down = 0;
			hermes_run_state = ERROR_STATE;
			snprintf(status120, 120, "Error: Bias1 code 100 but low bias current < 10 ma");
			WriteStatus(status120);
		}
		else {
			Bias1code(++bias1);
			hermes_run_state = WAIT_STATE;
			snprintf(status120, 120, "Sending bias code %d for second transistor", bias1);
			WriteStatus(status120);
		}
		break;
	case SET_BIAS + 6:		// Set bias 0 to the measured value.
		next_state = SET_BIAS + 7;
		Bias0code(bias0);
		hermes_run_state = WAIT_STATE;
		break;
	case SET_BIAS + 7:		// Write bias 0 to permanent storage
		next_state = SET_BIAS + 8;
		hw_command[0] = 0x3D;
		hw_command[1] = 0x06;
		hw_command[2] = 0xAC;
		hw_command[3] = 0x20;
		hw_command[4] = (unsigned char)bias0;
		hw_command_state = 1;
		hw_command_start = QuiskTimeSec();
		hermes_run_state = WAIT_STATE;
		break;
	case SET_BIAS + 8:		// Write bias 1 to permanent storage
		next_state = SET_BIAS + 9;
		hw_command[0] = 0x3D;
		hw_command[1] = 0x06;
		hw_command[2] = 0xAC;
		hw_command[3] = 0x30;
		hw_command[4] = (unsigned char)bias1;
		hw_command_state = 1;
		hw_command_start = QuiskTimeSec();
		hermes_run_state = WAIT_STATE;
		break;
	case SET_BIAS + 9:		// We are finished
		hermes_enable_power_amp = 0;
		snprintf(status120, 120, "Success.  Writing bias codes %d and %d to hardware", bias0, bias1);
		WriteStatus(status120);
		if (do_all_tests)
			hermes_run_state = PA;
		else
			hermes_run_state = STATE_IDLE;
		break;
	case WAIT_STATE:	// Wait for the command to finish.
		if (hermes_temperature < 5.0 || hermes_temperature > 50.0) {
			hermes_key_down = 0;
			hermes_run_state = ERROR_STATE;
			snprintf(status120, 120, "Error: Lost communication with hardware, or bad temperature");
			WriteStatus(status120);
		}
		else if (hermes_pa_current > 0.3) {
			hermes_key_down = 0;
			hermes_run_state = ERROR_STATE;
			snprintf(status120, 120, "Error: Excessive PA current");
			WriteStatus(status120);
		}
		else if (hw_command_state == 0) {	// Command completed
			hermes_run_state = next_state;
		}
		else if (hw_command_state < 0) {	// Command failed
			hermes_key_down = 0;
			hermes_run_state = ERROR_STATE;
			snprintf(status120, 120, "Error: Command sent to hardware failed");
			WriteStatus(status120);
		}
		break;
	case ERROR_STATE:	// There was an error; set bias to zero
		if (do_all_tests)
			WriteOutput("Set bias on the power output transistors FAILED");
			CheckResult(output120, 1.0, 10.0, 0.1, NULL);
			hermes_run_state = END_OF_TESTS;
		if (hw_command_state <= 0) {
			Bias0code(0);
			hermes_run_state = ERROR_STATE + 1;
		}
		break;
	case ERROR_STATE + 1:
		if (hw_command_state <= 0) {
			Bias1code(0);
			hermes_run_state = ERROR_STATE + 2;
		}
		break;
	case ERROR_STATE + 2:
		if (hw_command_state <= 0) {
			hermes_enable_power_amp = 0;
			hermes_run_state = STATE_IDLE;
		}
		break;

	case PA:
		InitParams();
		WriteOutput("Test high power output");
		hermes_Q5_switch_ext_ptt_lp = 0;
		hermes_filter_tx = 0;
		hermes_filter_rx = 0;
		hermes_spot_level = 0.0;
		hermes_key_down = 1;
		hermes_lna_gain = 0;
		hermes_tx_drive_level = 0;

		snprintf(output120, 120, "Temperature is %.2f", hermes_temperature);
		CheckResult(output120, hermes_temperature, 25, 0.30, NULL);

		rms_ref = hermes_temperature;
		hermes_enable_power_amp = 1;
		hermes_tx_freq = hermes_rx_freq = 14200000;
		LONG_DELAY_NEXT
		break;

	case PA + 1:
		snprintf(output120, 120, "PA current is %.2f", hermes_pa_current);
		CheckResult(output120, hermes_pa_current, 0.20, 0.15, NULL);
		hermes_spot_level = 0.520;
		LONG_DELAY_NEXT
		break;


	case PA + 2:
		snprintf(output120, 120, "Forward power 30/20m filter, code is %.3f", hermes_fwd_power);
		CheckResult(output120, hermes_fwd_power, 662, 0.20, NULL);
		snprintf(output120, 120, "Reverse power 30/20m filter,code is %.3f", hermes_rev_power);
		CheckResult(output120, hermes_rev_power, 20, 1.00, NULL);
		LONG_DELAY_NEXT
		break;

	case PA + 3:
		next_state = hermes_run_state + 1;
		hermes_run_state = STATE_TIME_DELAY;
		delay_time = QuiskTimeSec() + 1.0;
		break;

	case PA + 4:
		rms_ref = hermes_temperature - rms_ref;
		if (rms_ref <= 0.0) {
			rms_ref = 100;
		}
		snprintf(output120, 120, "PA current is %.2f", hermes_pa_current);
		CheckResult(output120, hermes_pa_current, 0.33, 0.15, NULL);
		hermes_key_down = 0;
		snprintf(output120, 120, "Temperature change is %.2f", rms_ref);
		CheckResult(output120, rms_ref, 1.25, 1.0, NULL);

		hermes_run_state = TEST_TX_FLATNESS;
		break;

	case STATE_START_TEST_TX_FLATNESS:
		do_all_tests = 0;
		InitParams();
		hermes_run_state = TEST_TX_FLATNESS;
		break;

	case TEST_TX_FLATNESS:
		// measure PA output at 1.8 MHz and 30 MHz. Check absolute values and ratio
		// N2ADR filters bypassed
		WriteOutput("Test TX power flatness");
		hermes_spot_level = 1;
		hermes_tx_drive_level = 255;
		hermes_enable_power_amp = 1;
		hermes_tx_freq = hermes_rx_freq = 1800000;
		hermes_key_down = 1;
		LONG_DELAY_NEXT
		break;

	// case TEST_TX_FLATNESS + 1:
	// 	// measure PA output power over frequency - must use heatsink!
	// 	snprintf(output120, 120, "%i\t%.3f\t%.3f\n", hermes_tx_freq, hermes_fwd_power, hermes_rev_power)
	// 	WriteOutput(output120);
	// 	//printf(output120)
	// 	hermes_tx_freq += 1000000;
	// 	hermes_rx_freq = hermes_tx_freq;
	// 	if (hermes_tx_freq > 30000000)
	// 		hermes_run_state = END_OF_TESTS;

	// 	hermes_run_state -= 1; // need to go back to this state
	// 	LONG_DELAY_NEXT
	// 	break;

	case TEST_TX_FLATNESS + 1:
		// get power detector reading for full PA output at 1.8 MHz
		pwr1p8 = hermes_fwd_power;
		snprintf(output120, 120, "PA power code at 1.8 MHz is %.1f", pwr1p8);
		CheckResult(output120, pwr1p8, 4000.0, 0.10, NULL);
		// prepare for next measurement at 30 MHz
		hermes_tx_freq = hermes_rx_freq = 30000000;
		LONG_DELAY_NEXT
		break;

	case TEST_TX_FLATNESS + 2:
		// get power detector reading for full PA output at 30 MHz
		pwr30 = hermes_fwd_power;
		hermes_key_down = 0;
		snprintf(output120, 120, "PA power code at 30 MHz is %.1f", pwr30);
		CheckResult(output120, pwr30, 3500.0, 0.10, NULL);
		snprintf(output120, 120, "PA power code ratio 1.8 MHz vs 30 MHz is %.2f", pwr1p8 / pwr30);
		hermes_run_state = END_OF_TESTS;
		break;

	case END_OF_TESTS:
		InitParams();
		if (tests_failed == 0) {
			WriteOutput("END OF TESTS - ALL TESTS PASSED");
		}
		else {
			snprintf(output120, 120, "END OF TESTS - %d out of %d tests FAILED", tests_failed, tests_total);
			WriteOutput(output120);
		}
		hermes_run_state = STATE_IDLE;
		break;
	}
}

static void InitParams(void)
{
	hermes_enable_power_amp = 0;
	hermes_spot_level = 0.0;
	hermes_key_down = 0;
	hermes_rx_freq = 14200000;
	hermes_tx_freq = 14210000;
	hermes_tx_drive_level = 255;
	hermes_Q5_switch_ext_ptt_lp = 1;
	hermes_lna_gain = 0;
	hermes_filter_rx = 0;
	hermes_filter_tx = 0;
	alex_hpf_rx = 0;
	alex_lpf_rx = 0;
	alex_hpf_tx = 0;
	alex_lpf_tx = 0;
}

static int CheckResult(const char * msg, double result, double target, double tolerance, const char * components)
{
	char msg2[120];
	std::string output;

	tests_total++;
	if (fabs(result - target) <= fabs(target * tolerance)) {
		if (verbose_output) {
			snprintf(msg2, 120, "; should be %.2lf %.1lf%% - PASS", target, tolerance * 100);
			output = msg;
			output += msg2;
			std::cout << output + "\n";
		}
		return 0;
	}
	snprintf(msg2, 120, "; should be %.2lf %.1lf%% - FAIL", target, tolerance * 100);
	output = msg;
	output += msg2;
	WriteOutput(output.c_str());
	if (verbose_output) std::cout << output + "\n";
	if (components != NULL) {
		snprintf(msg2, 120, "Check components %s",components);
		output = msg2;
		WriteOutput(output.c_str());
		if (verbose_output) std::cout << output + "\n";
	}
	tests_failed++;
	
}

void QuiskSleepMicrosec(int usec)
{
#ifdef _WIN32
	int msec = (usec + 500) / 1000;		// convert to milliseconds
	if (msec < 1)
		msec = 1;
	Sleep(msec);
#else
	struct timespec tspec;
	tspec.tv_sec = usec / 1000000;
	tspec.tv_nsec = (usec - tspec.tv_sec * 1000000) * 1000;
	nanosleep(&tspec, NULL);
#endif
}

double QuiskTimeSec(void)
{  // return time in seconds as a double
#ifdef _WIN32
	FILETIME ft;
	ULARGE_INTEGER ll;

	GetSystemTimeAsFileTime(&ft);
	ll.LowPart  = ft.dwLowDateTime;
	ll.HighPart = ft.dwHighDateTime;
	return (double)ll.QuadPart * 1.e-7;
#else
	struct timeval tv;

	gettimeofday(&tv, NULL);
	return (double)tv.tv_sec + tv.tv_usec * 1e-6;
#endif
}

int HL2GetBoardId(void)
{
	const char * ip = "255.255.255.255";
	int i, port=1024;
	unsigned char data[1500];
	struct sockaddr_in recv_Addr;
#ifdef _WIN32
	int addrlen;
	unsigned long mode;
#else
	int fl;
	socklen_t addrlen;
#endif


	QuiskSleepMicrosec(100000);
#ifdef _WIN32
	WORD wVersionRequested;
	WSADATA wsaData;
	if (cleanupWSA == 0) {
		wVersionRequested = MAKEWORD(2, 2);
		if (WSAStartup(wVersionRequested, &wsaData) != 0) {
			snprintf(status120, 120, "Failed to initialize Winsock (WSAStartup)");
			WriteStatus(status120);
			return 0;
		}
		else {
			cleanupWSA = 1;
		}
	}
#endif
	if (rx_discover_socket == INVALID_SOCKET) {
		rx_discover_socket = socket(PF_INET, SOCK_DGRAM, 0);
		if (rx_discover_socket != INVALID_SOCKET) {
			i = ~ 0;
			setsockopt(rx_discover_socket, SOL_SOCKET, SO_BROADCAST, (char *)&i, sizeof(i));
#ifdef _WIN32
			mode = 1;
			ioctlsocket(rx_discover_socket, FIONBIO, &mode);
#else
			fl = fcntl(rx_discover_socket, F_GETFL);
			fcntl(rx_discover_socket, F_SETFL, fl | O_NONBLOCK);
#endif
			addrlen = sizeof(recv_Addr);
			while(recvfrom(rx_discover_socket, (char *)data, 1500, 0, (sockaddr *)&recv_Addr, &addrlen) > 0)
				;	// get rid of old packets
			data[0] = data[1] = 0;
		}
		else {
			snprintf(status120, 120, "Failed to open Discover socket");
			WriteStatus(status120);
		}
	}
	if (board_id == 0) {
#ifdef _WIN32
		strncpy_s(status120, 120, "Searching for Hermes-Lite2", _TRUNCATE);
#else
		strncpy(status120, "Searching for Hermes-Lite2", 120);
#endif
		WriteStatus(status120);
		send_discover(rx_discover_socket);
		QuiskSleepMicrosec(50000);
		addrlen = sizeof(recv_Addr);
		i = recvfrom(rx_discover_socket, (char *)data, 1500, 0, (sockaddr *)&recv_Addr, &addrlen);
		//printf("Got %i from recvfrom\n", i);
		if (i > 32 && data[0] == 0xEF && data[1] == 0xFE) {
			snprintf(mac_address, ADR_SIZE, "%2.2x:%2.2x:%2.2x:%2.2x:%2.2x:%2.2x",
				data[3], data[4], data[5], data[6], data[7], data[8]);
			code_version = data[9];
			board_id = data[10];
			//printf("Got board_id %i\n", board_id);
#ifdef _WIN32
			InetNtopA(AF_INET, &recv_Addr.sin_addr, ip_address, ADR_SIZE);
#else
			strncpy(ip_address, inet_ntoa(recv_Addr.sin_addr), ADR_SIZE);
#endif
			quisk_hermes_tx_send();		// initialize
			// Open the receive/transmit socket
			rx_udp_socket = socket(PF_INET, SOCK_DGRAM, 0);
			if (rx_udp_socket != INVALID_SOCKET) {
#ifdef _WIN32
				mode = 1;
				ioctlsocket(rx_udp_socket, FIONBIO, &mode);
#else
				fl = fcntl(rx_udp_socket, F_GETFL);
				fcntl(rx_udp_socket, F_SETFL, fl | O_NONBLOCK);
#endif
				if (connect(rx_udp_socket, (const struct sockaddr *)&recv_Addr, sizeof(recv_Addr)) != 0) {
					shutdown(rx_udp_socket, QUISK_SHUT_BOTH);
					close__socket(rx_udp_socket);
					rx_udp_socket = INVALID_SOCKET;
					snprintf(status120, 120, "Failed to connect rx socket");
					WriteStatus(status120);
				}
				else {
					snprintf(status120, 120, "Connected");
					WriteStatus(status120);
				}
			}
			else {
				snprintf(status120, 120, "Failed to open Rx socket");
				WriteStatus(status120);
			}

		}
	}
	return board_id;
}

int close_udp10(void)		// Metis-Hermes protocol
{  // Call this repeatedly until it returns zero.
	int i;
	unsigned char buf[64];
	static double time0 = 0;
	static int state = 0;

	if (rx_discover_socket != INVALID_SOCKET) {
		close__socket(rx_discover_socket);
		rx_discover_socket = INVALID_SOCKET;
		time0 = 0;
		state = 0;
	}
	if (rx_udp_socket == INVALID_SOCKET) {
		time0 = 0;
		state = 0;
		return 0;
	}
	if (QuiskTimeSec() < time0)
		return 1;
	switch(state) {
	case 0:
		state = 1;
		shutdown(rx_udp_socket, QUISK_SHUT_RD);
		buf[0] = 0xEF;
		buf[1] = 0xFE;
		buf[2] = 0x04;
		buf[3] = 0x00;
		for (i = 4; i < 64; i++)
			buf[i] = 0;
		send(rx_udp_socket, (char *)buf, 64, 0);
		time0 = QuiskTimeSec() + 0.050;
		return 1;
	case 1:
		state = 2;
		buf[0] = 0xEF;
		buf[1] = 0xFE;
		buf[2] = 0x04;
		buf[3] = 0x00;
		for (i = 4; i < 64; i++)
			buf[i] = 0;
		send(rx_udp_socket, (char *)buf, 64, 0);
		time0 = QuiskTimeSec() + 2.000;
		return 1;
	case 2:
		state = 0;
		close__socket(rx_udp_socket);
		rx_udp_socket = INVALID_SOCKET;
#ifdef _WIN32
		if (cleanupWSA) {
			cleanupWSA = 0;
			WSACleanup();
		}
#endif
		return 0;;
	default:
		time0 = 0;
		state = 0;
		return 0;
	}
	return 0;
}

static int quisk_hermes_is_ready(void)
{	// Start Hermes; return 1 when we are ready to receive data
	unsigned char buf[1500];
	int i;
	struct timeval tm_wait;
	static int state = 0;
	fd_set fds;

	if (rx_udp_socket == INVALID_SOCKET) {
		state = 0;
		return 0;
	}
	switch (state) {
	case 0:			// Start or restart
		buf[0] = 0xEF;
		buf[1] = 0xFE;
		buf[2] = 0x04;
		buf[3] = 0x00;
		for (i = 4; i < 64; i++)
			buf[i] = 0;
		send(rx_udp_socket, (char *)buf, 64, 0);		// send Stop
		state++;
		QuiskSleepMicrosec(2000);
		return 0;
	case 1:
		buf[0] = 0xEF;
		buf[1] = 0xFE;
		buf[2] = 0x04;
		buf[3] = 0x00;
		for (i = 4; i < 64; i++)
			buf[i] = 0;
		send(rx_udp_socket, (char *)buf, 64, 0);		// send Stop
		state++;
		QuiskSleepMicrosec(9000);
		return 0;
	case 2:
		while (1) {
			tm_wait.tv_sec = 0;			// throw away all pending records
			tm_wait.tv_usec = 0;
			FD_ZERO (&fds);
			FD_SET (rx_udp_socket, &fds);
			if (select (rx_udp_socket + 1, &fds, NULL, NULL, &tm_wait) != 1)
				break;
			recv(rx_udp_socket, (char *)buf, 1500,  0);
		}
		state++;
		return 0;
	case 3:
	case 4:
	case 5:
	case 6:
	case 7:
		quisk_hermes_tx_send();	// send packets with number of receivers
		state++;
		QuiskSleepMicrosec(2000);
		return 0;
	case 8:
		if (quisk_rx_udp_started) {
			state++;
		}
		else {
			// send our return address until we receive UDP blocks
			buf[0] = 0xEF;
			buf[1] = 0xFE;
			buf[2] = 0x04;
			buf[3] = 0x01;
			for (i = 4; i < 64; i++)
				buf[i] = 0;
			send(rx_udp_socket, (char *)buf, 64, 0);
			QuiskSleepMicrosec(2000);
		}
		return 1;
	default:
		return 1;
	}
}

static void quisk_hermes_tx_send()
{	// Send mic samples using the Metis-Hermes protocol.  Timing is from blocks received, rate is 48k.
	int i, sent, send_command;
	unsigned char ch1, ch2;
	unsigned char * pt_buf1;
	unsigned char * pt_buf2;
	static unsigned char sendbuf[1032];
	static unsigned int seq;
	static unsigned char C0_index;
	static double time_command;

	if (rx_udp_socket == INVALID_SOCKET) {	// initialize here
		seq = 0;
		C0_index = 0;
		for (i = 0; i < 1032; i++)
			sendbuf[i] = 0;
		sendbuf[0] = 0xEF;
		sendbuf[1] = 0xFE;
		sendbuf[2] = 0x01;
		sendbuf[3] = 0x02;
		sendbuf[8] = 0x7F;
		sendbuf[9] = 0x7F;
		sendbuf[10] = 0x7F;
		sendbuf[520] = 0x7F;
		sendbuf[521] = 0x7F;
		sendbuf[522] = 0x7F;
		quisk_hermes_is_ready();
		return;
	}
	sendbuf[4] = seq >> 24 & 0xFF;
	sendbuf[5] = seq >> 16 & 0xFF;
	sendbuf[6] = seq >> 8 & 0xFF;
	sendbuf[7] = seq & 0xFF;
	seq++;
	sendbuf[11] = C0_index << 1 | hermes_key_down;	// C0
	for (i = 12; i <= 15; i++)
		sendbuf[i] = 0;
	sendbuf[523] = (C0_index + 1) << 1 | hermes_key_down;	// C0
	for (i = 524; i <= 527; i++)
		sendbuf[i] = 0;
	switch (C0_index) {
	case 0:		// C0_index is 0, 1
		sendbuf[12] = 0;		// C1
		if (hermes_key_down)		// send filter selection on J16
			sendbuf[13] = hermes_filter_tx << 1;	// C2
		else
			sendbuf[13] = hermes_filter_rx << 1;
		sendbuf[14] = 0;		// C3
		sendbuf[15] = 0x04;		// C4	duplex on
		sendbuf[524] = (hermes_tx_freq >> 24) & 0xFF;		// C1	transmitter frequency
		sendbuf[525] = (hermes_tx_freq >> 16) & 0xFF;		// C2
		sendbuf[526] = (hermes_tx_freq >>  8) & 0xFF;		// C3
		sendbuf[527] = (hermes_tx_freq      ) & 0xFF;		// C4
		break;
	case 2:		// C0_index is 2, 3
		sendbuf[12] = (hermes_rx_freq >> 24) & 0xFF;		// C1	receiver 1 frequency
		sendbuf[13] = (hermes_rx_freq >> 16) & 0xFF;		// C2
		sendbuf[14] = (hermes_rx_freq >>  8) & 0xFF;		// C3
		sendbuf[15] = (hermes_rx_freq      ) & 0xFF;		// C4
		break;
	case 4:		// C0_index is 4, 5
		break;
	case 6:		// C0_index is 6, 7
		// use C0_index 7 to send special hardware commands if there are any
		send_command = 0;
		if (hw_command_state == 1) {	// first transmit of special command
			send_command = 1;
			time_command = QuiskTimeSec();
			hw_command_state++;
		}
		else if (hw_command_state > 1 && time_command - QuiskTimeSec() > COMMAND_INTERVAL_SEC) {
			send_command = 1;		// no ACK received, transmit command again
			time_command = QuiskTimeSec();
			hw_command_state++;
		}
		if (send_command) {	// send special command
			//printf ("Send command 0x%X\n", hw_command[0]);
			sendbuf[523] = (hw_command[0] << 1 | hermes_key_down) | 0x80;	// always set request bit
			sendbuf[524] = hw_command[1];
			sendbuf[525] = hw_command[2];
			sendbuf[526] = hw_command[3];
			sendbuf[527] = hw_command[4];
		}
		else {		// send the usual data
		}
		break;
	case 8:		// C0_index is 8, 9
		sendbuf[524] = hermes_tx_drive_level;		// C1
		sendbuf[525] = (hermes_enable_power_amp << 3) | (hermes_Q5_switch_ext_ptt_lp << 2);		// C2
		//printf("!%d",int(sendbuf[525]));
		if (hermes_key_down) {		// send Alex filter selection
			sendbuf[526] = alex_hpf_tx;	// C3
			sendbuf[527] = alex_lpf_tx;	// C4
                }
		else {
			sendbuf[526] = alex_hpf_rx;
			sendbuf[527] = alex_lpf_rx;
                }
		break;
	case 10:	// C0_index is 10, 11
		sendbuf[15] = ((hermes_lna_gain + 12) & 0x3F) | 0x40;		// C4
		break;
	}
	C0_index += 2;
	if (C0_index > 10)
		C0_index = 0;
	pt_buf1 = sendbuf + 16;
	pt_buf2 = sendbuf + 528;
	i = (int)(hermes_spot_level * 23000);	// 2^15 * 0.707
	ch1 = (i >> 8) & 0xFF;
	ch2 = i & 0xFF;
	for (i = 0; i < 63; i++) {		// add 63 samples
		pt_buf1 += 4;
		*pt_buf1++ = ch1;		// Two bytes of I
		*pt_buf1++ = ch2;
		*pt_buf1++ = ch1;		// Two bytes of Q
		*pt_buf1++ = ch2;
		pt_buf2 += 4;
		*pt_buf2++ = ch1;		// Two bytes of I
		*pt_buf2++ = ch2;
		*pt_buf2++ = ch1;		// Two bytes of Q
		*pt_buf2++ = ch2;
	}
	//printf ("Send 0x%X, 0x%X\n", sendbuf[11], sendbuf[523]);
	sent = send(rx_udp_socket, (char *)sendbuf, 1032, 0);
	if (sent != 1032) {
		snprintf(status120, 120, "Tx UDP socket error in Hermes");
		WriteStatus(status120);
	}
}

static int read_rx_udp10(int want_samples)	// Read samples from UDP using the Hermes protocol.
{
	int bytes;
	unsigned char buf[1500];
	unsigned int seq;
	static unsigned int seq0;
	int i, start, dindex, nSamples, ximag, xreal, index;
	struct timeval tm_wait;
	fd_set fds;
	int hermes_count_temperature, hermes_count_current;
	double d, samp_rms;

	hermes_temperature = hermes_pa_current = 0;
	hermes_fwd_power = hermes_rev_power = 0;
	if ( ! quisk_hermes_is_ready()) {
		seq0 = 0;
		quisk_rx_udp_started = 0;
		return 0;
	}
	nSamples = 0;
	samp_rms = 0;
	hermes_count_temperature = hermes_count_current = 0;
	// All C0 from 0,1 to 10,11 are sent every 63*2*6 samples
	while (nSamples < want_samples) {		// read several UDP blocks
		tm_wait.tv_sec = 0;
		tm_wait.tv_usec = 100000; // Linux seems to have problems with very small time intervals
		FD_ZERO (&fds);
		FD_SET (rx_udp_socket, &fds);
		i = select (rx_udp_socket + 1, &fds, NULL, NULL, &tm_wait);
		if (i == 1)
			;
		else if (i == 0) {
			snprintf(status120, 120, "Udp socket timeout");
			WriteStatus(status120);
			return 0;
		}
		else {
			snprintf(status120, 120, "Udp select error");
			WriteStatus(status120);
			return 0;
		}
		bytes = recv(rx_udp_socket, (char *)buf, 1500,  0);
		//printf ("Received %d bytes 0x%x 0x%x 0x%x 0x%x\n", (int)bytes, buf[0], buf[1], buf[2], buf[3]);
		if (bytes != 1032 || buf[0] != 0xEF || buf[1] != 0xFE || buf[2] != 0x01) {		// Known size of sample block
			snprintf(status120, 120, "read_rx_udp10: Bad block size or header");
			WriteStatus(status120);
			return 0;
		}
		////   ADC Rx samples
		if (buf[3] != 0x06)		// End point 6: I/Q and mic samples
			return 0;
		seq = buf[4] << 24 | buf[5] << 16 | buf[6] << 8 | buf[7];	// sequence number
		quisk_rx_udp_started = 1;
		quisk_hermes_tx_send();
		if (seq != seq0) {
			snprintf(status120, 120, "read_rx_udp10: Bad sequence number");
			WriteStatus(status120);
		}
		//printf("seq %d\n", seq0);
		seq0 = seq + 1;		// Next expected sequence number
		for (start = 11; start < 1000; start += 512) {
			// check the sync bytes
			if (buf[start - 3] != 0x7F || buf[start - 2] != 0x7F || buf[start - 1] != 0x7F) {
				snprintf(status120, 120, "read_rx_udp10: Bad sync byte");
				WriteStatus(status120);
			}
			// read five bytes of control information.  start is the index of C0.
			dindex = buf[start] >> 3;
			if (buf[start] & 0x80) {	// reply to request bit
				if ((buf[start] & 0x7F) >> 1 == hw_command[0]) {	// ACK for correct command
					hw_command_state = 0;
					//printf("Got ACK\n");
				}
			}
			//printf("Start %d dindex %d\n", start, dindex);
			else if (dindex == 0) {		// C0 is 0b00000xxx
				;
			}
			else if(dindex == 1) {	// temperature and forward power
				hermes_temperature += (buf[start + 1] << 8 | buf[start + 2]);
				hermes_fwd_power   += (buf[start + 3] << 8 | buf[start + 4]);
				hermes_count_temperature++;
			}
			else if (dindex == 2) {	// reverse power and current
				hermes_rev_power  += (buf[start + 1] << 8 | buf[start + 2]);
				hermes_pa_current += (buf[start + 3] << 8 | buf[start + 4]);
				hermes_count_current++;
			}
			// convert 24-bit samples to 32-bit samples; int must be 32 bits.
			index = start + 5;
			for (i = 0; i < 63; i++) {		// read each sample (xreal, ximag)
				ximag = buf[index    ] << 24 | buf[index + 1] << 16 | buf[index + 2] << 8;
				xreal = buf[index + 3] << 24 | buf[index + 4] << 16 | buf[index + 5] << 8;
				d = ximag;
				samp_rms += d * d;
				d = xreal;
				samp_rms += d * d;
				nSamples++;
				index += 8;
			}
		}
	}
	// compute the average
	if (hermes_count_temperature > 0) {	// There are 3 counts for every 63*2*6 samples
		hermes_temperature /= hermes_count_temperature;
		hermes_fwd_power /= hermes_count_temperature;
	}
	if (hermes_count_current > 0) {
		hermes_rev_power /= hermes_count_current;
		hermes_pa_current /= hermes_count_current;
	}
	if (hermes_fwd_power < hermes_rev_power) {	// forward and reverse power could be backwards
		d = hermes_fwd_power;
		hermes_fwd_power = hermes_rev_power;
		hermes_rev_power = d;
	}
	if (nSamples > 0) {
		samp_rms = sqrt(samp_rms / nSamples) / 2147483647.;
		samp_rms = 20.0 * log10(samp_rms);
		hermes_sample_rms = samp_rms;
	}
	// convert ADC codes to degrees C and amps
	hermes_temperature = (3.26 * (hermes_temperature/4096.0) - 0.5)/0.01;
	hermes_pa_current = (3.26 * (hermes_pa_current/4096.0))/50.0/0.04;
	hermes_pa_current = hermes_pa_current / (1000.0/1270.0);
	return nSamples;
}

static void Bias0code(int code)
{
	hw_command[0] = 0x3D; // ADDR
	hw_command[1] = 0x06; // I2C2 cookie, must be 0x06 to write
	hw_command[2] = 0xAC; // I2C2 stop at end + target chip address
	hw_command[3] = 0x00; // I2C2 control: MCP4662 Command Byte: Address 0, write data
	hw_command[4] = (unsigned char)code; // I2C2 data: MCP4662 Data Byte
	hw_command_state = 1;
	hw_command_start = QuiskTimeSec();
}

static void Bias1code(int code)
{
	hw_command[0] = 0x3D; // ADDR
	hw_command[1] = 0x06; // I2C2 cookie, must be 0x06 to write
	hw_command[2] = 0xAC; // I2C2 stop at end + target chip address
	hw_command[3] = 0x10; // I2C2 control: MCP4662 Command Byte: Address 1, write data
	hw_command[4] = (unsigned char)code; // I2C2 data: MCP4662 Data Byte
	hw_command_state = 1;
	hw_command_start = QuiskTimeSec();
}

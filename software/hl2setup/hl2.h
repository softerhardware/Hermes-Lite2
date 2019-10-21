void HL2Run(void);
int HL2GetBoardId(void);
int close_udp10(void);
double QuiskTimeSec(void);
void QuiskSleepMicrosec(int);
void send_discover(int);
void WriteStatus(const char *);
void WriteOutput(const char *);

#define ADR_SIZE 32
#define COMMAND_INTERVAL_SEC	0.05	// time interval between retries
#define COMMAND_TOTAL_SEC	0.25	// total time allowed for command

extern int code_version;
extern int board_id;
extern int hermes_key_down;
extern char mac_address[ADR_SIZE];
extern char ip_address[ADR_SIZE];
extern double hermes_temperature;
extern double hermes_pa_current;
extern int hermes_run_state;
extern int hermes_power_button;
extern int hermes_enable_power_amp;
extern int verbose_output;

#define FILTER_HPF		0x40
#define FILTER_160		0x01
#define FILTER_80		0x02
#define FILTER_60_40		0x04
#define FILTER_30_20		0x08
#define FILTER_17_15		0x10
#define FILTER_12_10		0x20

#define STATE_IDLE		0
#define STATE_TIME_DELAY	2
#define STATE_SAMPLE_DELAY	4
#define STATE_START_TESTS	6
#define END_OF_TESTS		10
#define STATE_START_SET_BIAS	16
#define SET_BIAS		40
#define WAIT_STATE		60
#define ERROR_STATE		61
#define BACKGROUND_NOISE	100
#define SIGNAL_LEVEL		110
#define FILTER_BOARD		160
#define PA  190
#define STATE_START_TEST_TX_FLATNESS 200
#define TEST_TX_FLATNESS 205

#include <FL/Fl.H>
#include <FL/fl_draw.H>
#include <FL/Fl_Window.H>
#include <FL/Fl_Box.H>
#include <FL/Fl_Button.H>
#include <FL/Fl_Light_Button.H>
#include <FL/Fl_Text_Display.H>

#include <string>

#include <hl2.h>

#ifndef _WIN32
#include <sys/time.h>
#endif

void idle(void *);
void exit_callback(Fl_Widget*, void*);
void btn_setup_callback(Fl_Widget *, void *);
void btn_test_bias_callback(Fl_Widget *, void *);
void btn_set_bias_callback(Fl_Widget *, void *);
void btn_power_callback(Fl_Widget *, void *);

int verbose_output;

class MainWindow : public Fl_Window
{
private:
	Fl_Button * setup_button;
	//Fl_Button * set_bias_button;
	//Fl_Button * test_bias_button;
	const char * help_text;
public:
	Fl_Light_Button * power_button;
	Fl_Box * value_mac;
	Fl_Box * value_id;
	Fl_Box * value_ip;
	Fl_Box * value_code;
	Fl_Box * value_current;
	Fl_Box * value_temp;
	Fl_Box * status_text;
	Fl_Text_Display * output_window;
	Fl_Text_Buffer * output_buffer;
	std::string output_string = "";

	MainWindow(int win_width, int win_height, const char * title) : Fl_Window(win_width, win_height, title) {
		int dx, dy, w, h, pix, bheight, x0;
		int ww, hh;
		int y, y0, tab1, tab2, tab3, tab4, width1, width2, width3, width4, height, info_width;
		Fl_Box * text;
		this->callback(exit_callback);
		pix = labelsize();	// The label size in pixels
		tab1 = pix;
		y0 = pix;
	
		text = new Fl_Box(20, 20, 100, 20, "Ethernet address");
		text->box(FL_NO_BOX);
		text->align(FL_ALIGN_LEFT|FL_ALIGN_INSIDE);
		ww = hh = 0;
		text->measure_label(ww, hh);
		bheight = hh * 20 / 10;		// button height
		height = hh;			// box text height
		width1 = ww * 15 / 10;
		width2 = ww * 12 / 10;
		width3 = ww * 12 / 10;
		width4 = ww * 8 / 10;
		tab2 = tab1 + width1;
		tab3 = tab2 + width2 + height * 3;
		tab4 = tab3 + width3;
		info_width = tab4 + width4 - tab1;
	
		ww = width1 * 50 / 100;
		power_button = new Fl_Light_Button(tab1, y0, ww, bheight, "Connect");
		power_button->callback(btn_power_callback);
		power_button->when(FL_WHEN_CHANGED);
	
		status_text = new Fl_Box(tab1 + ww + tab1, y0, info_width - ww - tab1, bheight, "Disconnected");
		status_text->box(FL_ENGRAVED_BOX);
		status_text->align(FL_ALIGN_LEFT|FL_ALIGN_INSIDE);
	
		y = y0 + bheight * 15 / 10;
		text->resize(tab1, y, width1, height);
	
		value_mac = new Fl_Box(tab2, y, width2, height, "Unknown");
		value_mac->box(FL_NO_BOX);
		value_mac->align(FL_ALIGN_RIGHT|FL_ALIGN_INSIDE);
	
		text = new Fl_Box(tab3, y, width3, height, "Board ID");
		text->box(FL_NO_BOX);
		text->align(FL_ALIGN_LEFT|FL_ALIGN_INSIDE);
		
		value_id = new Fl_Box(tab4, y, width4, height, "Unknown");
		value_id->box(FL_NO_BOX);
		value_id->align(FL_ALIGN_RIGHT|FL_ALIGN_INSIDE);
		y += height;
	
		text = new Fl_Box(tab1, y, width1, height, "Internet address");
		text->box(FL_NO_BOX);
		text->align(FL_ALIGN_LEFT|FL_ALIGN_INSIDE);
	
		value_ip = new Fl_Box(tab2, y, width2, height, "Unknown");
		value_ip->box(FL_NO_BOX);
		value_ip->align(FL_ALIGN_RIGHT|FL_ALIGN_INSIDE);
	
		text = new Fl_Box(tab3, y, width3, height, "Code version");
		text->box(FL_NO_BOX);
		text->align(FL_ALIGN_LEFT|FL_ALIGN_INSIDE);
		
		value_code = new Fl_Box(tab4, y, width4, height, "Unknown");
		value_code->box(FL_NO_BOX);
		value_code->align(FL_ALIGN_RIGHT|FL_ALIGN_INSIDE);
		y += height;
	
		text = new Fl_Box(tab1, y, width1, height, "Power amp current");
		text->box(FL_NO_BOX);
		text->align(FL_ALIGN_LEFT|FL_ALIGN_INSIDE);
	
		value_current = new Fl_Box(tab2, y, width2, height, "Unknown");
		value_current->box(FL_NO_BOX);
		value_current->align(FL_ALIGN_RIGHT|FL_ALIGN_INSIDE);
	
		text = new Fl_Box(tab3, y, width3, height, "Temperature");
		text->box(FL_NO_BOX);
		text->align(FL_ALIGN_LEFT|FL_ALIGN_INSIDE);
		
		value_temp = new Fl_Box(tab4, y, width4, height, "Unknown");
		value_temp->box(FL_NO_BOX);
		value_temp->align(FL_ALIGN_RIGHT|FL_ALIGN_INSIDE);
		y += height;
	
		y += height;
		ww = width1 * 70 / 100;
		hh = height * 2;
		x0 = tab1 * 2;
		dx = (info_width - tab1 * 2 - ww * 3) / 2;
		dx = ww + dx;
		setup_button = new Fl_Button(x0, y, ww, hh, "Test");
		setup_button->callback(btn_setup_callback);
		setup_button->deactivate();
		//test_bias_button = new Fl_Button(x0 + dx, y, ww, hh, "Test PA Bias");
		//test_bias_button->callback(btn_test_bias_callback);
		//test_bias_button->when(FL_WHEN_CHANGED);
		//test_bias_button->deactivate();
		//set_bias_button = new Fl_Button(x0 + dx * 2, y, ww, hh, "Set PA Bias");
		//set_bias_button->callback(btn_set_bias_callback);
		//set_bias_button->deactivate();
		y += hh + height;
	
		hh = height * 24;
		help_text = "Wait until the Hermes-Lite 2.0 has two solid LEDs and two blinking LEDs, "
" or three solid LEDs and 1 blinking LED. Then Press connect. Look at the Internet address. "
"There should be a valid IP address. If the IP address starts with 169.254, then DHCP failed."
"\n\n"
"Connect a loop back 50 Ohm coax cable with inline 30dB attenuator from one SMA connector to the other."
"\n\n"
"Press the Test button to start the automated tests and bias adjustments.";
		output_buffer = new Fl_Text_Buffer();
		output_window = new Fl_Text_Display(tab1, y, info_width, hh);
		output_window->buffer(output_buffer);
		output_window->wrap_mode(output_window->WRAP_AT_BOUNDS, 0);
		output_buffer->text(help_text);
		y += hh;
		this->end();
		this->size(tab1 + tab4 + width4, y + height);
		Fl::add_idle(idle);
	}

	void EnableSetButton(void)
	{
		//if (hermes_run_state == STATE_IDLE && code_version >= 60 && hermes_temperature >= 5.0 && hermes_temperature < 70.0)
		//	set_bias_button->activate();
		//else
		//	set_bias_button->deactivate();
		if (hermes_run_state == STATE_IDLE && code_version >= 60) {
			setup_button->activate();
			//test_bias_button->activate();
		}
		else {
			setup_button->deactivate();
			//test_bias_button->deactivate();
		}
	}

	void Disconnect(void) {
		this->output_buffer->text(this->help_text);
		hermes_key_down = 0;
		hermes_run_state = STATE_IDLE;
		this->setup_button->deactivate();
		//this->set_bias_button->deactivate();
		//this->test_bias_button->deactivate();
		this->value_mac->copy_label("Unknown");
		this->value_id->copy_label("Unknown");
		this->value_ip->copy_label("Unknown");
		this->value_code->copy_label("Unknown");
		this->value_current->copy_label("Unknown");
		this->value_temp->copy_label("Unknown");
	}
} ;

MainWindow * main_window = new MainWindow(600,400, "Hermes-Lite 2 Test and Setup Utility, Version 2.0, April 2019");

void WriteStatus(const char * msg)
{
	main_window->status_text->copy_label(msg);
}

void WriteOutput(const char * msg)
{
	main_window->output_string += msg;
	main_window->output_string += "\n";
	main_window->output_buffer->text(main_window->output_string.c_str());
}

void idle(void * w)
{
	char buf80[80];
	static double time0 = 0;
	static int power = 0;


	if ( ! hermes_power_button) {
		if (board_id) {	// Disconnect from hardware
			if (close_udp10() == 0) {
				board_id = 0;
				main_window->status_text->copy_label("Disconnected");
				main_window->power_button->activate();
			}
		}
		else {
			QuiskSleepMicrosec(10000);
		}
			
	}
	else if (board_id == 0) {
		if (HL2GetBoardId()) {		// Connect to the hardware
			snprintf(buf80, 80, "%d", board_id);
			main_window->value_id->copy_label(buf80);
			snprintf(buf80, 80, "%d", code_version);
			main_window->value_code->copy_label(buf80);
			main_window->value_mac->copy_label(mac_address);
			main_window->value_ip->copy_label(ip_address);
		}
	}
	else {
		HL2Run();	// Read and write samples; Perform tests
		if (code_version >= 60) {
			snprintf(buf80, 80, "%.0f C", hermes_temperature);
			main_window->value_temp->copy_label(buf80);
			snprintf(buf80, 80, "%.0f ma", hermes_pa_current * 1000);
			main_window->value_current->copy_label(buf80);
			main_window->EnableSetButton();
		}
	}
}

void exit_callback(Fl_Widget*, void*) {
	if (Fl::event()==FL_SHORTCUT && Fl::event_key()==FL_Escape) 
		return; // ignore Escape
	hermes_key_down = 0;
	hermes_run_state = STATE_IDLE;
	while (close_udp10())
		;
	exit(0);
}

void btn_setup_callback(Fl_Widget * w, void * d) {
	main_window->output_string = "";
	main_window->output_buffer->text(main_window->output_string.c_str());
	hermes_run_state = STATE_START_TESTS;
}

void btn_test_bias_callback(Fl_Widget * w, void * d) {
	hermes_key_down = hermes_enable_power_amp = ((Fl_Button * )w)->value(); 
}

void btn_set_bias_callback(Fl_Widget * w, void * d) {
	hermes_run_state = STATE_START_SET_BIAS;
}

void btn_power_callback(Fl_Widget * w, void * d) {
	hermes_power_button = ((Fl_Light_Button * )w)->value();
	if ( ! hermes_power_button) {
		main_window->Disconnect();
		main_window->status_text->copy_label("Shutdown...");
		main_window->power_button->deactivate();
	}
}

int main(int argc, char **argv) {
	int i;

	for (i = 1; i < argc; i++)
		if ( ! strcmp(argv[i], "-v"))
			verbose_output = 1;	// print the result of each test
	main_window->show();
	return Fl::run();
}

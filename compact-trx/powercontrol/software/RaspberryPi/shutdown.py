#!/usr/bin/python
# coding:utf-8 
import time
import RPi.GPIO as GPIO
import os
 
GPIO.setmode(GPIO.BCM)
GPIO.setup(14,GPIO.IN,pull_up_down=GPIO.PUD_DOWN)
 
while True:
    GPIO.wait_for_edge(14, GPIO.RISING)
    sw_counter = 0
 
    while True:
        sw_status = GPIO.input(14)
        if sw_status == 1:
            sw_counter = sw_counter + 1
            if sw_counter >= 5:
                os.system("sudo shutdown -h now")
                break
        else:
            break
 
        time.sleep(0.01)

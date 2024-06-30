#! /bin/bash

cat page4-fc00-c1-diskboot.dat  \
    page5-fd00-c1-keypoller.dat \
    page6-fe00-c1-monitor.dat   \
    page7-ff00-c1-dcwm.dat > syn-600-c1-dcwm.rom

cat page1-fd00-c2c4-keypoller.dat \
    page2-fe00-c2c4-monitor.dat   \
    page3-ff00-c2c4-cwm.dat > syn-500-502-c2c4-540-cwm.rom

cat page1-fd00-c2c4-keypoller.dat \
    page2-fe00-c2c4-monitor.dat   \
    page0-ff00-c2c4-hdm.dat > syn-505-c2c4-540-hdm.rom


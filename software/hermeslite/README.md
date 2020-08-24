Hermes-Lite Python Module
=========================

This is a Python module to allow alternate command and control of a Hermes-Lite 2.0. It can be run before or at the same time as standard SDR software is in use. It is recommended to make any changes before standard SDR software is started. It uses port 1025. The purpose is to allow configuration of new, experimental or non-openhpsdr features. For example, setting the TX buffer latency, configuring the external clocks, and synchronizing multiple radios. It is not intended to replace standard SDR software. The intent is that useful features will eventually be adopted by standard SDR software once matured and proven here.

# Installation

## Standard Python3

 1. Install python3 with "sudo apt install python3" on Linux, see [here](https://www.python.org/) for other platforms.
 2. Download the hermeslite.py from this github repository
 3. Start interactive python3 with "python3 -i hermeslite.py"

This will discover any Hermes-Lite 2.0 on your network and create a hl object for the first unit found.

## Jupyter Notebook

A Jupyter notebook is essentially an interactive web page displayed in your browser. It mixes formatted text, snippets of Python3 code, widgets and graphs. You select "cells" and run them. You only need to select the cells which perform the functions you need. You don't need to memorize or lookup the library method names and Python3 syntax. It is an easier approach for beginners. Jupyter notebook pages are very popular and widely used in data sciences. It is a mature tool. See [here](https://jupyter.org/install) for official installation. Quick install is:

 1. sudo apt install python3 python3-pip
 2. pip3 install --user jupyter
 3. pip3 install --user ipywidgets
 4. jupyter notebook
 5. Navigate to the hermeslite.ipynb file and open it

You must download at least the hermeslite.ipynb and hermeslite.py into the same working directory. These two files are found on this page. You may also want to checkout the entire hermes-lite github repository with *git clone https://github.com/softerhardware/Hermes-Lite2.git*.






#!/usr/bin/env python3
import argparse
import pathlib
import queue
import serial
import sys
import time

# RZ Flash Writer keywords
K_SCIF_DOWNLOAD_MODE = b"SCIF Download mode\r\n (C) Renesas Electronics Corp.\r\n-- Load Program to System RAM ---------------\r\nplease send !"
K_PROMPT = b">"
K_PLEASE_SEND = b"please send ! ('.' & CR stop load)"
# QSPI command operation keyword
K_INPUT_PROFRAM_TOP_ADDRESS = b"===== Please Input Program Top Address ============\r\n  Please Input : H\'"
K_INPUT_QSPI_SAVE_ADDRESS = b"===== Please Input Qspi Save Address ===\r\n  Please Input : H'"
K_YES_OR_NO = b"Clear OK?(y/n)"
# EMMC command operation 
K_INPUT_EXT_CSD_INDEX = b"Please Input EXT_CSD Index"
K_EXT_CSD_INPUT_VALUE = b"Please Input Value"
K_SELECT_AREA = b"Select area"
K_INPUT_START_ADDRESS = b"Please Input Start Address in sector"
K_INPUT_PROGRAM_START_ADDRESS = b"Please Input Program Start Address"
K_COMPLETE = b"Complete!"
# speed up/down keyword
K_SPEED_UP = b"Please change to 921.6Kbps baud rate setting of the terminal."
K_SPEED_DOWN = b"Please change to 115.2Kbps baud rate setting of the terminal."

"""
is_file_exist: check if the file is exist or not
"""
def is_file_exist(_file):
	file = pathlib.Path(_file)
	if file.exists():
		return True
	else:
		return False

"""
is_command_set: check if the command is set or not
"""
def is_command_set(command):
	if command != None:
		return True
	else:
		return False

"""
open_serial_port: open serial port
"""
def open_serial_port(serial_port, baudrate):
	serial_port = serial.Serial(serial_port, baudrate, timeout=0.5)
	if serial_port == None:
		print("Failed to connect to {}!".format(args.serial))
		exit()
	else:
		print("{} connected with {} bps.".format(args.serial, baudrate))
	return serial_port

"""
close_serial_port: close serial port
"""
def close_serial_port(sp):
	sp.close()

"""
send_command: send command
"""
def send_command(sp, command):
	sp.write(bytes(command, 'utf-8')+b'\r\n')

def send_file(sp, file_name):
	f = open(file_name, "rb")
	tlen = 0
	while True:
		fdata = f.read(4096)
		fdatalen = len(fdata)
		if fdatalen == 0:
			break;
		sp.write(fdata)
		tlen += fdatalen
		print('\r%d bytes completed.' % tlen, end='')
	f.close()
	sp.write(b'.\r\n')

"""
get_response: get response from Flash Writer
"""
def get_response(sp, keyword):
	while True:
		rdata = sp.read(8192)
		if len(rdata) != 0:
			print(rdata.decode())
		if keyword in rdata:
			break

"""
clean_receive_buffer: clear read buffer
"""
def clean_receive_buffer(sp):
	while True:
		rdata = sp.read(8192)
		if len(rdata) != 0:
			print(rdata.decode())
		if sp.in_waiting == 0:
			break

# rz flash tool arguments list 
def get_argparser():
	parser = argparse.ArgumentParser()
	
	parser.add_argument("-b", "--baudrate", type=int,
						help="Setup the baudrate for the serial port", required=True)
	parser.add_argument("-c", "--command",
						help="The command to drive the flash writer")
#	parser.add_argument("-d", "--storage_device", choices=['qspi', 'emmc'],
#						help="The command to drive the flash writer")

	parser.add_argument("-F", "--flash_addr",
						help="The save address(or sector) of Flash ROM")
	parser.add_argument("-f", "--firmware_file",
						help="The firmware file name")
	parser.add_argument("-m", "--mode", choices=['command','file', 'qspi', 'emmc'], required=True,
						help=" Please select operation mode first")
	parser.add_argument("-p", "--partition",
						help="partition number(EMMC only)")

	parser.add_argument("-R", "--ram_addr",
						help="The temporarily RAM address where store the firmware")
	parser.add_argument("-S", "--sport_mode", action="store_true",
						help="Switch serial port to SPORT Mode(921600 bps)")		
	parser.add_argument("-s", "--serial",
						help="Set the serial port, ex. /dev/ttyUSB0", required=True)

	parser.add_argument("-w", "--flash_writer",
						help="The flash writer file name")
	return parser

def run(sp, exec_queue):
	while exec_queue.empty() != True:
		# pop out a task from FIFO
		task = exec_queue.get()
		#print(task)
		if task[0] == 'command':
			send_command(sp=sp, command=task[1])
			get_response(sp=sp, keyword=task[2])
		elif task[0] == 'file':
			send_file(sp=sp, file_name=task[1])
			get_response(sp=sp, keyword=task[2])
		else:
			print("something wrong!!!")
			break

if __name__ == "__main__":
	parser = get_argparser()
	args = parser.parse_args()

	serial_port = open_serial_port( serial_port=args.serial, 
					baudrate=args.baudrate)

	# check if in expert mode
	if args.mode == 'command':
		print("[{}] mode".format(args.mode))
		if is_command_set(args.command) == True:
			send_command(sp=serial_port, command=args.command)
			clean_receive_buffer(serial_port)
		else:
			print("{} command not found!".format(args.command))
			exit()

	elif args.mode == 'file':
		print("[{}] mode".format(args.mode))
		if (args.firmware_file != None) and (is_file_exist(args.firmware_file) == True):
			send_file(sp=serial_port, file_name=args.firmware_file)
			clean_receive_buffer(serial_port)
		elif (args.flash_writer != None) and (is_file_exist(args.flash_writer) == True):
			send_file(sp=serial_port, file_name=args.flash_writer)
			clean_receive_buffer(serial_port)
		else:
			print("{} file not found!".format(args.firmware_file))
			exit()

	elif args.mode == 'qspi':
		print("[{}] mode".format(args.mode))
		
		# init the execute queue
		executeQ = queue.Queue()

		# check argument for qspi mode, and put all items in the excution queue
		# first, check and push flash writer into the queue
		if is_file_exist(args.flash_writer) == True:
			print("Flash Writer: {}".format(args.flash_writer))
			executeQ.put(('file', args.flash_writer, K_PROMPT))
		else:
			print("Flash Writer: X")
			exit()

		# second, it's qspi mode put qspi flash command directly
		executeQ.put(('command', 'XLS2', K_INPUT_PROFRAM_TOP_ADDRESS))

		# third, check the temporary RAM address
		if is_command_set(args.ram_addr) == True:
			print("RAM Address: {}".format(args.ram_addr))
			executeQ.put(('command', args.ram_addr, K_INPUT_QSPI_SAVE_ADDRESS))
		else:
			print("RAM Address: X")
			exit()

		# fourth, check the QSPI save address
		if is_command_set(args.flash_addr) == True:
			print("QSPI save Address: {}".format(args.flash_addr))
			executeQ.put(('command', args.flash_addr, K_PLEASE_SEND))
		else:
			print("QSPI save Address: X")
			exit()

		# fifth, check firmware file is exist or not
		if is_file_exist(args.firmware_file) == True:
			print("Firmware file: {}".format(args.firmware_file))
			executeQ.put(('file', args.firmware_file, K_YES_OR_NO))
		else:
			print("Firmware file: X")
			exit()

		# sixth, final check yes or no
		yes_or_no = input("Flash [{}] into QSPI flash address H'{}, y/n? ".format(args.firmware_file, args.flash_addr))
		if yes_or_no == 'y':
			executeQ.put(('command', yes_or_no,K_PROMPT))
			run(sp=serial_port, exec_queue=executeQ)
		else:
			print("[{}] operation mode is not executed!!!".format(args.mode))

	elif args.mode == 'emmc':
		print("[{}] mode".format(args.mode))

		# init the execute queue and add task in order
		executeQ = queue.Queue()

		# check argument for qspi mode, and put all items in the excution queue
		# first, check and push flash writer into the queue
		if is_file_exist(args.flash_writer) == True:
			print("Flash Writer: {}".format(args.flash_writer))
			executeQ.put(('file', args.flash_writer, K_PROMPT))
		else:
			print("Flash Writer: X")
			exit()

		# second, it's EMMC mode, send emmc write command and wait "select area" keyword 
		executeQ.put(('command', 'EM_W', K_SELECT_AREA))

		# third, check the EMMC partition number
		if is_command_set(args.partition) == True:
			print("partition: {}".format(args.partition))
			executeQ.put(('command', args.partition, K_INPUT_START_ADDRESS))
		else:
			print("partition: X")
			exit()

		# fourth, check the QSPI save address
		if is_command_set(args.flash_addr) == True:
			print("EMMC save Address in sector: {}".format(args.flash_addr))
			executeQ.put(('command', args.flash_addr, K_INPUT_PROGRAM_START_ADDRESS))
		else:
			print("EMMC save Address in sector: X")
			exit()

		# fifth, check the temporary RAM address
		if is_command_set(args.ram_addr) == True:
			print("RAM Address: {}".format(args.ram_addr))
			executeQ.put(('command', args.ram_addr, K_PLEASE_SEND))
		else:
			print("RAM: X")
			exit()

		# sixth, check firmware file is exist or not
		if is_file_exist(args.firmware_file) == True:
			print("Firmware file: {}".format(args.firmware_file))
			executeQ.put(('file', args.firmware_file, K_COMPLETE))
		else:
			print("Firmware file: X")
			exit()

		# seventh, final check yes or no
		yes_or_no = input("Flash [{}] into EMMC H'{} sector, y/n? ".format(args.firmware_file, args.flash_addr))
		if yes_or_no == 'y':
			run(sp=serial_port, exec_queue=executeQ)
		else:
			print("[{}] operation mode is not executed!!!".format(args.mode))

	else:
		print("[{}] operation mode is not support yet!!!".format(args.mode))

	close_serial_port(sp=serial_port)

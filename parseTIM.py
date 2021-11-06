import sys
import numpy as np
import json
count = 0
output = dict()
with open(sys.argv[1], 'r') as file1:
	while True:
		count += 1
		# Get next line from file
		line = file1.readline()
		
			
		if line.startswith("Digital_Bus") or line.startswith("Digital_Signal") :
			for i in range(3):
				file1.readline()
			nameline = list(filter(None, file1.readline().split(" ")))
			print("NAMELINE " + str(nameline))
			name = nameline[1]
			print(name)
			file1.readline()
			if line.startswith("Digital_Bus"):
				file1.readline()
			lenghtline = file1.readline()
			print(lenghtline)
			lenghtline = list(filter(None, lenghtline.split(" ")))
			length = int(lenghtline[1])
			edges = [0]*length 
			time  = [0.0]*length
			file1.readline()
			file1.readline()
			for i in range(length):
				edge = list(filter(None, file1.readline().split(" ")))
				thistime = float(edge[1])
				try:
					value= int(edge[2].replace("X", "").replace("\n", "").replace("x", "0"), 16)
				except:
					value= 0
				edges[i] = value
				time[i] = thistime
				
			thisDict = dict()
			thisDict["time"] = list(time)
			thisDict["edges"] = list(edges)
			output[name] = thisDict
		
			
				#print(value)
			
		
		# if line is empty
		# end of file is reached
		if not line:
			break
		#print("Line{}: {}".format(count, line.strip()))
 
with open("output.julian", 'w+') as f:
	f.write(json.dumps(output, indent=4))
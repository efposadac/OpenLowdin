#!/usr/bin/env python
from __future__ import print_function
import os
import sys
from colorstring import *

testName = sys.argv[0][:-3]
inputName = testName + ".lowdin"
outputName = testName + ".out"

# Reference values

refValues = {
    "HF energy" : [-75.93125555356,1E-8],
    "MP2 energy" : [-76.095442398277,1E-5],
    "e-AlphaBetaRepulsion" : [23.2395577028,1E-3]
}

testValues = dict(refValues) #copy 
for value in testValues: #reset
    testValues[value] = 0 #reset
    
# Run calculation

status = os.system("lowdin2 -i " + inputName)

if status:
    print(testName + str_red(" ... NOT OK"))
    sys.exit(1)

output = open(outputName, "r")
outputRead = output.readlines()

# Values
for i in range(0,len(outputRead)):
    line = outputRead[i]
    if "TOTAL ENERGY =" in line:
        testValues["HF energy"] = float(line.split()[3])
    if "E(MP2) =" in line:
        testValues["MP2 energy"] = float(line.split()[2])
    if "E-ALPHA/E-BETA Hartree energy" in line:
        testValues["e-AlphaBetaRepulsion"] = float(line.split()[4])

        
passTest = True

for value in refValues:
    diffValue = abs(refValues[value][0] - testValues[value]) 
    if ( diffValue <= refValues[value][1] ):
        passTest = passTest * True
    else :
        passTest = passTest * False
        print(value + " " + str(refValues[value]) +" " +  str(testValues[value]) + " "+ str(diffValue))

if passTest :
    print(testName + str_green(" ... OK"))
else:
    print(testName + str_red(" ... NOT OK"))
    sys.exit(1)

output.close()

import sys

# this script shifts all time indicators of form ZXX 
# ex Z02 -> Z00 when amount is -2

#usage: python shiftTime.py filename amount

filename = sys.argv[1]
amount   = int(sys.argv[2])

f1 = open(filename, 'r')
f2 = open(filename.replace(".vhd", "") + "_out.vhd", 'w+')

f3 = f1.readlines()
out = ""
for x in f3:
#    print(x)
    y = x

    #start high if increase, low if decrease
    if amount > 0:
        rnge = reversed(range(-20, 20))
    else:
        rnge = range(-20, 20)
    for z in rnge
        
        old = "Z{0:02d}".format(z)
        new = "Z{0:02d}".format(z+amount)
        # replace minus sign
        new.replace("-", "N")
        y   =  y.replace(old,new)
        #print(old + " " + new)
    f2.write(y)
    #print(y)


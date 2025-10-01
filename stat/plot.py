#!/usr/bin/env python3

# from pylab import *
import matplotlib.pyplot as plt

with open('../GA/output/driver-0.csv', 'r') as f:
  x = []
  y = []
  for line in f:
    tokens = line.split(',')
    x.append(int(tokens[0]))
    y.append(int(tokens[1]))

# x = x[57:]
# y = y[57:]
plt.plot(x,y,'r')
plt.axis([0, x[-1], 0, 200])
plt.show()

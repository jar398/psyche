# First pages at BHL of selected articles

# Input = '../bhl/first-pages.sch'

import sys, re

with open(sys.argv[1], 'r') as infile:
  print 'volume,start page,end page,bhl start page'
  for line in infile:
    line = line.strip()
    if line.startswith('("'):
      tokens = re.findall(r'[0-9]+', line)
      if len(tokens) != 4:
        print >>sys.stderr, '?', line
      else:
        print '%s,%s,%s,%s' % tuple(tokens)

# These are all the PDF files that we truly have (holdings)

# input = ../articles.sch

import sys, re

with open(sys.argv[1], 'r') as infile:
    print 'volume,start page,cec pdf'
    for line in infile:
        if line.startswith('(declare-prepared-articles-list'):
            tokens = re.findall(r'[a-z0-9-_+]+', line)
            volume = tokens[1]
            for token in tokens[2:]:
                if token.isdigit():
                    start = int(token)
                else:
                    start = token
                print '%s,%s,%s-%s' % (volume, start, volume, token)
                    

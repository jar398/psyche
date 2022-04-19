# -*- coding: utf-8 -*-

# Input: CEC table of contents in 'block' form (one field per line)
# Output: CSV file with same information

# toc.txt must end with a blank line

import sys, os, csv, re
import batch

# Write CSV file

def write_toc(toc, path):
  batch.write_batch(toc,
                    path,
                    ['volume', 'issue', 'start page', 'end page',
                     'year', 'doi', 'title', 'authors',
                     'inferred end page', 'comment', 'cec pdf', 'bhl start page'])

# 

inpath = sys.argv[1]            # Block-style
outpath = sys.argv[2]           # CSV

toc = batch.read_toc(inpath)
write_toc(toc, outpath)

def silly(record):
  return ('title' in record and
          ('Exchange Column' in record['title'] or
           'Index' in record['title']))
for record in toc:
  if not record.get('doi') and not record.get('cec pdf') and not silly(record):
    print("%s" % record)



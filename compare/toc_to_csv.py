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
                       'inferred end page', 'comment', 'cec pdf'])

# 

inpath = sys.argv[1]            # Block-style
outpath = sys.argv[2]           # CSV

toc = batch.read_toc(inpath)
write_toc(toc, outpath)

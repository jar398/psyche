
import csv

with open('article-pages.csv', 'r') as infile:
    with open('first-pages.sch', 'w') as outfile:
        outfile.write("(define first-pages\n '(\n")
        for (volume, start, end, title, pageids, guessed, missing) \
            in csv.reader(infile):
            ids = pageids.split(';')
            outfile.write('   ("%s-%s-%s" "%s")\n' % (volume, start, end, ids[0]))
        outfile.write('   ))\n')

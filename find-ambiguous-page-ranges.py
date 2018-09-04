import csv

# Volume Number,Issue Number,First Page,Last Page,DOI

table = {}
table2 = {}

with open('dois.csv', 'r') as infile:
    reader = csv.reader(infile)
    reader.next()
    for row in reader:
        key = (row[0], row[2], row[3])
        key2 = (row[0], row[2])
        if key in table:
            print "(volume, page, page) is ambiguous"
            print ' ', row
            print ' ', table[key]
        elif key2 in table2:
            print "(volume, page) is ambiguous"
            print ' ', row
            print ' ', table2[key2]
        table[key] = row
        table2[key2] = row

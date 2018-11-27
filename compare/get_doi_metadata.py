# curl -LH "Accept: application/json" http://dx.doi.org/10.1155/1927/94318 | python ~/a/ot/repo/reference-taxonomy/util/jsonpp.py 

import sys, requests, time, csv, json

writer = csv.writer(sys.stdout)

path = sys.argv[1]

def author_name(auth):
    g = auth.get("given")
    f = auth.get("family")
    if f and ',' in f:
        print >>sys.stderr, "Family name contains comma: %s" % f
    if g and ',' in g:
        print >>sys.stderr, "Given name contains comma: %s" % g
    if g != None and f != None:
        # N.b. Hindawi has parsed first/last but CEC hasn't.
        return "%s, %s" % (f, g)
    if g != None:
        return g
    if f != None:
        return f
    print >>sys.stderr, "ill-formed author: %s" % (auth,)
    return ''

with open(path, 'r') as infile:
    i = 1
    writer.writerow(["volume",
                     "issue",
                     "start page",
                     "end page",
                     "year",
                     "doi",
                     "title",
                     "authors"])
    reader = csv.reader(infile)
    header = reader.next()
    n = 0
    if 'doi' in header: n = header.index('doi')
    for row in reader:
        doi = row[n].strip()
        if not doi.startswith('10.'):
            print >>sys.stderr, "ill-formed doi: %s" % (doi,)
            continue
        url = 'http://dx.doi.org/' + doi
        r = requests.get(url, headers={"Accept": "application/json"}, allow_redirects=True)
        if r.status_code != 200:
            print >>sys.stderr, "Troublesome HTTP status %s for %s" % (r.status_code, url)
            continue
        j = r.json()
        year = j["issued"]["date-parts"][0][0]
        if int(year) < 2005:    # Hindawi-only
            if False and i % 2000 == 2:
                json.dump(j, sys.stderr, indent=2)
                print >>sys.stderr, ""
            pages = j["page"].split('-')
            authorstring = ';'.join([author_name(auth) for auth in j.get("author", [])])
            writer.writerow([int(j["volume"]),
                             j.get("issue"),
                             pages[0],
                             pages[1] if len(pages) > 1 else pages[0],
                             year,
                             doi,
                             j["title"].encode('utf-8'),
                             authorstring.encode('utf-8')])
        if i % 10 == 0:
            print >>sys.stderr, i, doi
        time.sleep(1)
        i += 1

# curl -LH "Accept: application/json" http://dx.doi.org/10.1155/1927/94318 | python ~/a/ot/repo/reference-taxonomy/util/jsonpp.py 

import sys, requests, time, csv

writer = csv.writer(sys.stdout)

path = sys.argv[1]

def author_name(auth):
    g = auth.get("given")
    f = auth.get("family")
    if g != None and f != None:
        return "%s %s" % (g, f)
    if g != None:
        return g
    if f != None:
        return f
    print "ill-formed author: %s" % (auth,)
    return ''

with open(path, 'r') as infile:
    for line in infile:
        doi = line.strip()
        url = 'http://dx.doi.org/' + doi
        r = requests.get(url, headers={"Accept": "application/json"}, allow_redirects=True)
        r.raise_for_status()
        j = r.json()
        pages = j["page"].split('-')
        authorstring = ';'.join([author_name(auth) for auth in j.get("author", [])])
        writer.writerow([doi,
                         int(j["volume"]),
                         j["issue"],
                         pages[0],
                         pages[1] if len(pages) > 1 else pages[0],
                         j["title"].encode('utf-8'),
                         authorstring.encode('utf-8')])
        time.sleep(1)

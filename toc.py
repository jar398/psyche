# Psyche table of contents tool

# Read, merge, write ?

# toc.txt must end with a blank line

import sys, os, csv

def read_toc(path):
    all_objects = []
    with open(path, 'r') as infile:
        current = None
        for line in infile:
            line = line.strip()
            if len(line) == 0:
                current = None
            else:
                if current == None:
                    # Start of new object
                    current = []
                    all_objects.append(current)
                    saw_volume = saw_issue = False
                if line[0] == '#':
                    parts = ('#', line[1:])
                else:
                    parts = line.split('\t', 1)
                    if len(parts) != 2:
                        print '** wrong number of parts: %s' % (parts,)
                        print current
                        continue
                current.append(parts)
    return all_objects

def infer_volume_and_issue(toc):
    previous = current_volume = current_issue = None
    for obj in toc:
        saw_volume = saw_issue = False
        for (verb, value) in obj:
            if verb == 'V':
                if current_volume != value:
                    current_issue = None
                current_volume = value
                saw_volume = True
            elif verb == 'I':
                current_issue = value
                saw_issue = True
        if not saw_volume and current_volume != None:
            obj.append(('V', current_volume))
        if not saw_issue and current_issue != None:
            obj.append(('I', current_issue))
        previous = obj

def infer_end_page(toc):
    count = 0
    previous = None
    previous_saw_end = False
    previous_start_page = None
    for obj in toc:
        this_start_page = None
        saw_end = False
        if previous != None:
            # Set inferred end page of previous to one less than
            # start page of this article
            for (verb, value) in obj:
                if verb == 'P':
                    this_start_page = value
                elif verb == 'Q':
                    saw_end = True
        if not previous_saw_end and this_start_page != None and previous_start_page != None:
            p = int(previous_start_page)
            here = int(this_start_page)
            if p < here:
                previous.append(('R', str(here - 1)))
                count += 1
            elif p == here:
                True
            else:
                print 'cannot infer end page because start pages out of order (%s > %s): %s' % (p, here, previous)
        previous = obj
        previous_saw_end = saw_end
        previous_start_page = this_start_page
    print 'inferred %s end pages' % count

def dictify(toc):
    # N.b. loses order, and does not include all authors & comments
    return [dictify_object(obj) for obj in toc]

def dictify_object(obj):
    d = {verb: value for (verb, value) in obj}
    d['object'] = obj
    return d

def proclaim(d, verb, value):
    d[verb] = value
    d['object'].append((verb, value))

def forget(d, verb, value):
    del d[verb]
    obj = d['object']
    gotit = None
    for entry in obj:
        (verb2, value2) = entry
        if verb2 == verb and value2 == value:
            gotit = entry
    if gotit != None:
        obj.remove(gotit)
    else:
        print '%s not in obj' % ((verb, value),)

def index_toc(dictified, fun):
    index = {}
    ambiguous = {}
    for d in dictified:
        key = fun(d)
        if not key in ambiguous:
            if key in index:
                del index[key]
                ambiguous[key] = True
            else:
                index[key] = d
    print 'Ambiguous: %s' % len(ambiguous)
    return (index, ambiguous)

def page_range_key(d):
    return (d.get('V'), d.get('I'), d.get('P'), get_last_page(d))

def get_last_page(d):
    q = d.get('Q')
    if q != None: return q
    return d.get('R')

def page_start_key(d):
    return (d.get('V'), d.get('I'), d.get('P'))

def vp_key(d):
    return (d.get('V'), d.get('P'))

def load_dois(dictified, path):
    count = 0
    ambiguous = []
    (index_by_vipq, vipq_ambiguous) = \
      index_toc(dictified, page_range_key)
    (index_by_vip, vip_ambiguous) = \
      index_toc(dictified, page_start_key)
    (index_by_doi, doi_ambiguous) = \
      index_toc(dictified, lambda d: d.get('D'))
    more = []
    with open(path, 'r') as infile:
        reader = csv.reader(infile)
        for (volume, issue, first_page, last_page, doi) in reader:
            first_page = first_page.lstrip('0')
            last_page = last_page.lstrip('0')
            if doi in index_by_doi:
                continue
            if (volume, first_page) in losers:
                continue
            probe = index_by_vipq.get((volume, issue, first_page, last_page))

            if probe == None and vipq_ambiguous.get(probe) == None:
                probe = index_by_vip.get((volume, issue, first_page))
                if probe != None:
                    if probe.get('Q') != None:
                        print 'last page mismatch: %s %s %s' \
                            % (page_range_key(probe), last_page, doi)
                        proclaim(probe, '#', ' Hindawi has last page = %s' % last_page)
                    else:
                        # Don't have last page.  Get it from Hindawi's CSV.
                        proclaim(probe, 'Q', last_page)
                        proclaim(probe, '#', ' Got last page %s from Hindawi' % last_page)
            if probe != None:
                if probe.get('D') == None:
                    proclaim(probe, 'D', doi)
                    count += 1
                elif probe['D'] != doi:
                    print 'wrong DOI: %s %s' % (probe['D'], doi)
            elif vip_ambiguous.get((volume, issue, first_page)) != None:
                ambiguous.append(doi)
            elif (doi.startswith('10') and 
                   index_by_vip.get((volume, issue, first_page)) == None):
                # Article not in CEC scanned set
                h = []
                h.append(('#', ' From Hindawi DOI file'))
                h.append(('V', volume))
                h.append(('I', issue))
                h.append(('P', first_page))
                h.append(('Q', last_page))
                h.append(('D', doi))
                more.append(dictify_object(h))
    for new_d in more:
        dictified.append(new_d)
    print 'added %s dois, added %s articles' % (count, len(more))
    return ambiguous
                
losers = [('8', '1'), ('8', '8'), ('8', '13'), ('64', '75')]

# Get titles and authors

def load_more_dois(dictified, path):
    (index_by_doi, doi_ambiguous) = \
      index_toc(dictified, lambda d: d.get('D'))
    for doi in doi_ambiguous:
        print 'ambiguous: %s' % doi
    rcount = 0
    tcount = 0
    acount = 0
    with open(path, 'r') as infile:
        reader = csv.reader(infile)
        for (doi, volume, issue, first_page, last_page, title, authors) in reader:
            rcount += 1
            d = index_by_doi.get(doi)
            if d != None:
                if d.get('T') == None:
                    if title == '':
                        proclaim(d, 'T', 'None')
                    else:
                        proclaim(d, 'T', title)
                        tcount += 1
                if d.get('A') == None:
                    if authors == '' or authors == 'None':
                        proclaim(d, 'A', 'None')
                    else:
                        for a in authors.split(';'):
                            proclaim(d, 'A', a)
                        acount += 1
                if d['V'] != volume:
                    print '** volume mismatch %s:%s %s:%s %s' % \
                      (d['V'], d['P'], volume, first_page, doi)
                if d['I'].lower() != issue.lower():
                    print '** issue mismatch %s(%s):%s %s(%s):%s %s' % \
                      (d['V'], d['I'], d['P'], volume, issue, first_page, doi)
                if d.get('P') != first_page:
                    print '** page mismatch %s:%s %s:%s %s' % \
                      (d['V'], d.get('P'), volume, first_page, doi)
            else:
                print 'no object with this DOI: %s' % doi
    print 'added titles to %s articles' % tcount
    print 'added authors to %s articles' % acount
    print '%s author/title records' % rcount

def add_cec_holdings(dictified, path):
    (index_by_vp, vp_ambiguous) = \
      index_toc(dictified, vp_key)
    count = 0
    losers = []
    ambiguous_s = []
    all_s = {}
    with open(path, 'r') as infile:
        reader = csv.reader(infile)
        for record in reader:
            (volume, first_pages) = record
            for first_page in first_pages.split(' '):
                p = first_page.lstrip('0')
                s = '%s-%s' % (volume, first_page)
                all_s[s] = True
                d = index_by_vp.get((volume, p))
                if d != None:
                    if 'S' in d:
                        if d['S'] != s:
                            print 'unexpected S %s (expected %s)' % (d['S'], s)
                    else:
                        proclaim(d, 'S', s)
                        count += 1
                elif vp_ambiguous.get((volume, p)):
                    ambiguous_s.append((volume, p))
                else:
                    if first_page.isdigit():
                        losers.append(s)
    print 'added %s CEC holdings' % count
    print '%s listed in %s but missing from TOC' % (len(losers), path)
    print losers[0:10]
    print 'ambiguous CEC (volume, page): %s' % len(ambiguous_s)
    print ambiguous_s[0:10]
    count = 0
    for d in dictified:
        s = d.get('S')
        if s != None:
            if not s in all_s:
                forget(d, 'S', s)
                proclaim(d, '#', ' Removed S = %s' % s)
                count += 1
    print 'Removed %s S fields' % count

# Assumes dictified is sorted

def infer_years(dictified):
    last_issue = {}    # maps volume to (issue, last_article)
    for d in dictified:
        if 'P' in d:
            i = issue_number(d)
            if i != None:
                l = last_issue.get(d['V'])
                if l == None:
                    last_issue[d['V']] = (i, d)
                else: 
                    (z, last_d) = l
                    if issue_number(last_d) <= i:
                        last_issue[d['V']] = (i, d)
    if False:
        # for debugging
        for v in sorted(last_issue.keys()):
            (z, last_d) = last_issue[v]
            if z > 6:
                print 'v. %s: last issue was %s, last page %s' % (v, z, get_last_page(last_d))
    year = None
    volume = None
    for d in dictified:
        # If starting a new volume, advance the year
        if d['V'] != volume:
            volume = d['V']
            y = get_year(d)
            year = str(y)
            # Advice already carried out
            if False:
                # Number of issues in this volume
                (z, last_d) = last_issue[d['V']]
                if z > 6:
                    q = int(get_last_page(last_d))
                    print ('v. %s: check for %s near %s and %s near %s' % 
                           (d['V'], y+1, (q / 3), y+2, (2 * q / 3)))
        if 'Y' in d:
            year = d['Y']
        if 'P' in d:
            # usually, just repeat year of previous article
            proclaim(d, 'Y', year)

def issue_number(d):
    i = d.get('I')
    if i != None:
        if '-' in i:
            i = i.split('-',1)[1]
        if i.isdigit():
            return int(i)
    return None

# One year per volume starting with volume 10 in 1903

def get_year(d):
    v = int(d['V'])
    if v < 11:
        year = 1871 + (v * 3)
        # Two year gap from volume 3 to volume 4
        if v > 4:
            year += 2
        return year
    elif v == 103:
        return 2000
    else:
        return v + (1903 - 10)

# Reporting

def object_sort_key(d):
    v = d.get('V')
    i = d.get('I')
    if i == None: i = ''
    if '-' in i:
        i = i.split('-')[0]
    p = d.get('P')
    lp = len(p) if p != None else 0
    return (len(v), v, len(i), i, lp, p, get_last_page(d), d.get('T'))

def field_sort_key(field):
    (verb, value) = field
    if verb == 'T': return 0
    if verb == 'A': return 10
    if verb == 'V': return 20
    if verb == 'I': return 30
    if verb == 'P': return 40
    if verb == 'Q': return 50
    if verb == 'R': return 60
    if verb == 'Y': return 65
    if verb == 'D': return 70
    if verb == 'S': return 90
    else: return 100

def check_continuity(dictified):
    previous_volume = None
    previous_issue = None
    previous_page = None
    previous_d = None
    for d in dictified:
        if d['V'] != previous_volume:
            previous_page = 0
            previous_issue = None
        if 'P' in d:
            page = int(d['P'])
            qage = get_last_page(d)
            if qage == None:
                if real_article(d):
                    print '* missing last page %s' % brief(d)
                continue
            qage = int(qage)
            if qage < page:
                print '* backwards page range %s' % brief(d)
                continue
            if page == previous_page:
                True
            elif page == previous_page + 1:
                True
            elif page == previous_page + 2 and ((page % 2) == 1):
                # Common pattern in e.g. volume 97
                True
            elif page < previous_page:
                print '* going backwards: %s -> %s' % (brief(previous_d), brief(d))
            elif (d.get('I') != previous_issue and
                  page < previous_page + 10):
                # Allow 10 pages between issues
                True
            else:
                print '* gap [%s]: %s -> %s' % \
                  (page-previous_page-1, brief(previous_d), brief(d))
            previous_page = qage
            previous_d = d
            previous_volume = d['V']
            previous_issue = d.get('I')
        
def brief(d):
    return '%s(%s):%s-%s' % (d.get('V'), d.get('I'), d.get('P'), get_last_page(d))

def real_article(d):
    if d.get('A') == 'None':
        return False
    t = d.get('T')
    if t == None: return False
    if t.startswith('Exchange'):
        return False
    if t.startswith('Proceedings'):
        return False
    if t.startswith('Bibliographical'):
        return False
    if 'Index' in t:
        return False
    return True

def count_things(dictified):
    volumes = {}
    issues = {}
    articles = 0
    dois = 0
    for d in dictified:
        if real_article(d):
            articles += 1
            if 'D' in d: dois += 1
        v = d.get('V')
        if not v in volumes: volumes[v] = True
        i = d.get('I')
        if not (v, i) in issues: issues[(v, i)] = True
    print 'Volumes:  %s' % len(volumes)
    print 'Issues:   %s' % len(issues)
    print 'Articles: %s' % articles
    print 'DOIs:     %s' % dois
    print 'No DOI:   %s' % (articles - dois)
        

# path to toc/ directory

def write_toc(dictified, ambiguous_dois, path):
    if not os.path.isdir(path):
        os.makedirs(path)
    with open(os.path.join(path, 'processed-toc.txt'), 'w') as outfile:
        for d in dictified:
            obj = d['object']
            for (verb, value) in sorted(obj, key=field_sort_key):
                if verb == '#':
                    outfile.write('#%s\n' % (value))
                else:
                    outfile.write('%s\t%s\n' % (verb, value))
            outfile.write('\n')
    with open(os.path.join(path, 'need-doi-lookup.txt'), 'w') as outfile:
        need = []
        for d in dictified:
            if 'D' in d and (not 'T' in d or not 'A' in d):
                need.append(d['D'])
        print 'dois lacking title or lacking author: %s' % len(need)
        for doi in sorted(need):
            outfile.write('%s\n' % doi)
    with open(os.path.join(path, 'ambiguous-dois.txt'), 'w') as outfile:
        for doi in sorted(ambiguous_dois):
            outfile.write('%s\n' % doi)


toc = read_toc(sys.argv[1])
infer_volume_and_issue(toc)
infer_end_page(toc)
dictified = dictify(toc)
ambiguous_dois = load_dois(dictified, 'dois.csv')
load_more_dois(dictified, 'doi-metadata.csv')
add_cec_holdings(dictified, 'articles.csv')

dictified = sorted(dictified, key=object_sort_key)
infer_years(dictified)
check_continuity(dictified)
count_things(dictified)
write_toc(dictified, ambiguous_dois, sys.argv[2])

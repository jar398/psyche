# -*- coding: utf-8 -*-

# Psyche table of contents tool

#   python toc.py toc.txt dois.csv doi-metadata.csv articles.csv master-toc
# or
#   python toc.py toc.txt /dev/null /dev/null articles.csv cec-toc

# An 'object' is an entry from toc.txt, with fields in order
#  represented as a vector of (key, value).
# These are processed to become 'records' which are little dictionaries.

# Read, merge, write ?

# toc.txt must end with a blank line

import sys, os, csv, re

def check_record(record):
    for (key, value) in record.items():
        if key == 'object':
            for (key, value) in value:
                if not isinstance(value, str):
                    print "bad value in object", key, value
        else:
            if isinstance(value, str) and value.isdigit():
                print "failed to convert to integer", key, value


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
    return [object_to_record(obj) for obj in toc]

# Turn a single TOC 'object' into a dictionary.
def object_to_record(obj):
    d = {verb: maybe_int(value) for (verb, value) in obj}
    d['object'] = obj
    return d

def proclaim(d, verb, value):
    d[verb] = maybe_int(value)
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

def index_toc(dictified, fun, tag):
    index = {}
    ambiguous = {}
    sample = []
    for d in dictified:
        key = fun(d)
        if key and not key in ambiguous:
            if key in index:
                del index[key]
                ambiguous[key] = True
                sample.append(key)
            else:
                index[key] = d
    print 'Ambiguous by %s: %s %s' % (tag, len(ambiguous), sample[0:2])
    return (index, ambiguous)

# VP
# Fails with the supplements
def vp_key(record):
    return (record.get('V'), record.get('P'))

# VIP
def page_start_key(record):
    return (record.get('V'), get_issue_key(record), record.get('P'))

# VIPQ
def page_range_key(record):
    return (record.get('V'), get_issue_key(record), record.get('P'), get_last_page(record))

# VIPQT
def record_sort_key(record):
    return (record.get('V'), get_issue_key(record), record.get('P'), get_last_page(record), record.get('T'))

# returns an integer or None
def get_last_page(record):
    q = record.get('Q')
    if q != None: return q
    return record.get('R')

def get_issue_key(record):
    i = record.get('I')
    if i == None:
        return i
    return issue_key(i)

def issue_key(i):
    if isinstance(i, int):
        return i
    else:
        parts = i.split('-')
        i = parts[0]
        if i.isdigit():
            return int(i)
        else:
            return i

def load_dois(dictified, path):
    count = 0
    ambiguous = []
    # vpiq = volume, index, start page, end page
    (index_by_vip, vip_ambiguous) = \
      index_toc(dictified, page_start_key, 'vip')
    (index_by_vipq, vipq_ambiguous) = \
      index_toc(dictified, page_range_key, 'vipq')
    (index_by_doi, doi_ambiguous) = \
      index_toc(dictified, lambda d: d.get('D'), 'DOI')
    more = []
    with open(path, 'r') as infile:
        reader = csv.reader(infile)
        header = reader.next()   # 'volume,issue,start page,end page,doi'
        for (volume, issue, first_page, last_page, doi) in reader:
            if doi in index_by_doi:
                continue
            first_page = first_page.lstrip('0')
            last_page = last_page.lstrip('0')
            if (volume, first_page) in losers:
                continue
            vip = (maybe_int(volume),
                   issue_key(issue),
                   maybe_int(first_page))
            vipq = vip + (maybe_int(last_page),)
            have = index_by_vipq.get(vipq)

            if have == None and vipq_ambiguous.get(vipq) == None:
                have = index_by_vip.get(vip)
                if have != None:
                    if have.get('Q') != None:
                        print '%s last page mismatch: CEC %s, Hindawi %s' \
                            % (doi, page_range_key(have), last_page)
                        proclaim(have, '#', ' Hindawi has last page = %s' % last_page)
                    else:
                        # Don't have last page.  Get it from Hindawi's CSV.
                        proclaim(have, 'Q', last_page)
                        proclaim(have, '#', ' Got last page %s from Hindawi' % last_page)
            if have != None:
                if have.get('D') == None:
                    proclaim(have, 'D', doi)
                    count += 1
                elif have['D'] != doi:
                    print 'wrong DOI: %s %s' % (have['D'], doi)
            elif vip_ambiguous.get(vip) != None:
                ambiguous.append(doi)
            elif (doi.startswith('10') and 
                   index_by_vip.get(vip) == None):
                # Article not in CEC scanned set
                have = {'object': []}
                proclaim(have, '#', ' From Hindawi DOI file')
                proclaim(have, 'V', volume)
                proclaim(have, 'I', issue)
                proclaim(have, 'P', first_page)
                proclaim(have, 'Q', last_page)
                proclaim(have, 'D', doi)
                more.append(have)
    for new_record in more:
        dictified.append(new_record)
    print 'added %s dois, added %s articles' % (count, len(more))
    return ambiguous
                
losers = [('8', '1'), ('8', '8'), ('8', '13'), ('64', '75')]

# Get titles and authors

def load_more_dois(dictified, path):
    (index_by_vip, vip_ambiguous) = \
      index_toc(dictified, page_start_key, 'vip')
    (index_by_vipq, vipq_ambiguous) = \
      index_toc(dictified, page_range_key, 'vipq')
    (index_by_doi, doi_ambiguous) = \
      index_toc(dictified, lambda d: d.get('D'), 'DOI')
    for doi in doi_ambiguous:
        print 'Ambiguous DOI: %s' % doi
    rcount = 0
    tcount = 0
    acount = 0
    more = []
    with open(path, 'r') as infile:
        reader = csv.reader(infile)  # doi,volume,issue,start page,end page,title,authors
        header = reader.next()
        legend = {key: i for (key, i) in zip(header, range(len(header)))}
        print legend
        for record in reader:
            def getcha(key):
                probe = legend.get(key)
                if probe != None:
                    return record[probe]
                else:
                    return ''
            # (doi, volume, issue, first_page, last_page, title, authors) = record
            doi = getcha('doi')
            volume = getcha('volume')
            issue = getcha('issue')
            first_page = getcha('start page')
            last_page = getcha('end page')
            title = getcha('title')
            authors = getcha('authors')

            vip = (maybe_int(volume),
                   issue_key(issue),
                   maybe_int(first_page))
            vipq = vip + (maybe_int(last_page),)

            have = index_by_doi.get(doi)
            if doi in doi_ambiguous: have = None
            if not have:
                have = index_by_vip.get(vipq)
                if vip in vip_ambiguous: have = None
            if not have:
                have = index_by_vipq.get(vipq)
                if vipq in vipq_ambiguous: have = None
            if not have:
                have = {'object': []}
                more.append(have)
            rcount += 1
            if have.get('T') == None:
                if title != '':
                    proclaim(have, 'T', title)
                    tcount += 1
            if have.get('A') == None:
                if authors != '':
                    for a in authors.split(';'):
                        proclaim(have, 'A', a)
                    acount += 1
            if have.get('V') == None:
                proclaim(have, 'V', volume)
            elif have['V'] != maybe_int(volume):
                print '** volume mismatch %s:%s %s:%s %s' % \
                  (have['V'], have['P'], volume, first_page, doi)
            if have.get('I') == None:
                proclaim(have, 'I', issue)
            elif have['I'] != maybe_int(issue):  #.lower()
                print '** issue mismatch %s(%s):%s %s(%s):%s %s' % \
                  (have['V'], have['I'], have['P'], volume, issue, first_page, doi)
            if have.get('P') == None:
                proclaim(have, 'P', first_page)
            elif have.get('P') != maybe_int(first_page):
                print '** start page mismatch %s:%s %s:%s %s' % \
                  (have['V'], have.get('P'), volume, first_page, doi)
            if have.get('Q') == None:
                proclaim(have, 'P', first_page)
    for new_record in more:
        dictified.append(new_record)
    print 'added titles to %s articles' % tcount
    print 'added authors to %s articles' % acount
    print '%s author/title records' % rcount

def add_cec_holdings(dictified, path):
    (index_by_vp, vp_ambiguous) = \
      index_toc(dictified, vp_key, 'vp')
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
    print 'ambiguous by CEC volume + page: %s' % len(ambiguous_s)
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
    return dictified

# Assumes dictified is sorted

def infer_years(dictified):
    last_issue = {}    # maps volume to (issue, last_article)
    for d in dictified:
        if 'P' in d:
            i = get_issue_key(d)
            if i != None:
                l = last_issue.get(d['V'])
                if l == None:
                    last_issue[d['V']] = (i, d)
                else: 
                    (z, last_d) = l
                    if get_issue_key(last_d) <= i:
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
            year = get_year(d)
            # Advice already carried out
            if False:
                # Number of issues in this volume
                (z, last_d) = last_issue[d['V']]
                if z > 6:
                    q = get_last_page(last_d)
                    print ('v. %s: check for %s near %s and %s near %s' % 
                           (d['V'], y+1, (q / 3), y+2, (2 * q / 3)))
        if 'Y' in d:
            year = d['Y']
        if 'P' in d:
            # usually, just repeat year of previous article
            proclaim(d, 'Y', str(year))

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

def maybe_int(x):
    if isinstance(x, str) and x.isdigit():
        return int(x)
    else:
        return x

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
        check_record(d)
        if d['V'] != previous_volume:
            previous_page = 0
            previous_issue = 0
        if 'P' in d:
            page = d['P']
            qage = get_last_page(d)
            issue = get_issue_key(d)
            if qage == None:
                if real_article(d):
                    print '* missing last page %s' % brief(d)
                continue
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
                print '* going backwards: %s -> %s (%s)' % (previous_page, page, brief(d))
            elif (issue != previous_issue and
                  page < previous_page + 10):
                # Allow 10 pages between issues
                True
            else:
                print '* gap: %s -> %s [%s pages]' % \
                  (brief(previous_d), brief(d), page-previous_page-1)
            previous_page = qage
            previous_d = d
            previous_volume = d['V']
            previous_issue = issue
        
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
    if t.startswith('Recent Publications'):
        return False
    if t.startswith('Recent Literature'):
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
    with open(os.path.join(path, 'no-doi.csv'), 'w') as outfile:
        writer = csv.writer(outfile)
        writer.writerow(['volume', 'issue', 'start page', 'end page', 'title', 'authors'])
        for d in dictified:
            t = d.get('T','')
            if ('P' in d and not 'D' in d and
                'A' in d and
                not 'Exchange Column' in t and
                not 'index to ' in t.lower()):
                writer.writerow([d['V'], d['I'], d['P'], get_last_page(d), t, ';'.join(authors(d))])
    write_master_csv(dictified, path)

# dictified comes in sorted properly

def write_master_csv(dictified, path):
    records = []
    for d in dictified:
        title = d.get('T','')
        if d.get('P') == None and title == '': continue
        # if title == '' and d.get('P') == '':
        records.append([d.get('V'),
                        d.get('I'),
                        d.get('P'),
                        get_last_page(d),
                        d.get('Y'), d.get('D'),
                        demarkupify(title),
                        ';'.join(map(demarkupify, authors(d)))])
    with open(os.path.join(path, 'master-toc.csv'), 'w') as outfile:
        writer = csv.writer(outfile)
        writer.writerow(['volume', 'issue', 'start page', 'end page',
                         'year', 'doi', 'title', 'authors'])
        for record in records:
            writer.writerow(record)

tag_pattern = re.compile('<[a-zA-Z/]+>')

def demarkupify(s):
    s = re.sub(tag_pattern, '', s, 99)

    # Diacritics and ligatures
    s = s.replace('&eaigu;', 'é')
    s = s.replace('&eacute;', 'é')
    s = s.replace('&euml;', 'ë')
    s = s.replace('&egrave;', 'è')
    s = s.replace('&ouml;', 'ö')
    s = s.replace('&uuml;', 'ü')
    s = s.replace('&oelig;', 'oe')
    s = s.replace('&OElig;', 'OE')
    s = s.replace('&aelig;', 'ae')
    s = s.replace('&AElig;', 'AE')
    s = s.replace('&acir;', 'å')
    s = s.replace('&oacute;', 'ó')
    s = s.replace('&iacute;', 'í')
    s = s.replace('&aacute;', 'á')
    s = s.replace('&aaigu;', 'á')
    s = s.replace('&atilde;', 'ã')
    s = s.replace('&uacute;', 'ú')
    s = s.replace('&auml;', 'ä')
    s = s.replace('&ocirc;', 'ô')

    # Punctuation
    s = s.replace('&mdash;', ' - ')
    s = s.replace('&ndash;', ' - ')
    s = s.replace('&ldquo;', '"')
    s = s.replace('&rdquo;', '"')
    s = s.replace('&amp;', '&')
    s = s.replace('&apos;', "'")
    s = s.replace('&lsquo;', "'")
    s = s.replace('&rsquo;', "'")
    return s

def authors(d):
    a = []
    for (verb, value) in d['object']:
        if verb == 'A' and value != 'None':
            a.append(value)
    return a

toc_path = sys.argv[1]
dois_path = sys.argv[2]       # 'dois.csv'
more_dois_path = sys.argv[3]  # 'doi-metadata.csv'
articles_path = sys.argv[4]   # 'articles.csv'
output_dir = sys.argv[5]

toc = read_toc(toc_path)
infer_volume_and_issue(toc)
infer_end_page(toc)
records = dictify(toc)
ambiguous_dois = load_dois(records, dois_path)
load_more_dois(records, more_dois_path)
add_cec_holdings(records, articles_path)

records = sorted(records, key=record_sort_key)
infer_years(records)
check_continuity(records)
count_things(records)
write_toc(records, ambiguous_dois, output_dir)

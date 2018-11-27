# Compare to Psyche CSV files

# python compare.py clean-doi-metadata.csv all-doi-metadata.csv

import sys, csv, re
import batch

def multi(record, keys):
  tup = ()
  for key in keys:
    v = record.get(key)
    if v:
      tup = tup + (v,)
    else:
      return None
  return tup

def vp(record):
  return multi(record, ['volume', 'start page'])

def find_match(record, vp_index, doi_index):
  doi_matches = doi_index.get(record.get('doi'), [])
  if len(doi_matches) == 1:
    return doi_matches[0]
  vp_matches = vp_index.get(vp(record), [])
  match = (check_property(record, 'title', vp_matches) or
           check_property(record, 'authors', vp_matches))
  if match == None and len(vp_matches) == 1:
    match = vp_matches[0]
  if (match and 'issue' in record and 'issue' in match and record['issue'] != match['issue'] and
      ('upp' in record['issue']) != ('upp' in match['issue'])):
    return None
  if (match and 'doi' in record and 'doi' in match and record['doi'] != match['doi']):
    return None
  return match

def check_property(record, key, matches):
  if key in record:
    prefix = record[key][0:10]
    results = []
    for match in matches:
      m = match.get(key)
      if m and m[0:10] == prefix:
        results.append(match)
    if len(results) == 1:
      return results[0]
  return None

def compare(toc1, toc2):
  matched = []
  unmatched = []
  indx1 = batch.invert(vp, toc2)
  indx2 = batch.invert(lambda r:r.get('doi'), toc2)
  for record in toc1:
    match = find_match(record, indx1, indx2)
    if match:
      # Compare record to match, report on differences
      matched.append((record, match))
    else:
      # Skip silly records
      unmatched.append(record)
  print 'matches:', len(matched)
  print 'unmatched:', len(unmatched)
  return (matched, unmatched)

def brief(r):
  return '%s(%s):%s-%s' % (r.get('volume'), r.get('issue'), r.get('start page'), r.get('end page'))

def silly(record):
  return ('title' in record and
          ('Exchange Column' in record['title'] or
           'Index' in record['title']))

def abbreviates(cec, hin):
  cec_authors = cec.split(';')
  hin_authors = hin.split(';')
  if len(cec_authors) != len(hin_authors):
    return False
  for (c, h) in zip(cec_authors, hin_authors):
    c_parts = c.split(' ')
    h_parts = h.split(' ')
    if len(c_parts) != len(h_parts):
      return False
    for (c_part, h_part) in zip(c_parts, h_parts):
      if c_part == h_part: continue
      if c_part == 'Wm.' and h_part == 'William': continue
      if not c_part.endswith('.') or not h_part.startswith(c_part[0:-1]):
        return False
  return True

# Fill in information that's missing from record2 with information
# provided by record1.  Side effecty.

def improve(target, source):
  for (key, value) in source.items():
    if not key in target:
      target[key] = value
  if 'end page' in target and 'inferred end page' in target:
    del target['inferred end page']
  return target

def add_holdings_info(target, holdings):
  vp_index = batch.invert(vp, target)
  count = 0
  for record in holdings:
    for hit in vp_index.get(vp(record), []):
      if hit.get('cec pdf') == None:
        improve(hit, record)
        count += 1
  print >>sys.stderr, 'added CEC PDF info for %s records' % count

def add_bhl_pages(target, bhl):
  vp_index = batch.invert(vp, target)
  count = 0
  for record in bhl:
    for hit in vp_index.get(vp(record), []):
      if hit.get('bhl start page') == None:
        improve(hit, record)
        count += 1
  print >>sys.stderr, 'added BHL pages info for %s records' % count

# print 'test1', abbreviates('H. F. Wickham', 'Henry Frederick Wickham')

pattern = re.compile('\W+')

def how_different(val1, val2, key):
  val1 = val1.lower()
  val2 = val2.lower()
  if val1 == val2:
    return 'case'
  val1 = val1.replace(' ','')
  val2 = val2.replace(' ','')
  if val1 == val2:
    return 'spacing'
  val1 = re.sub(pattern, '', val1)
  val2 = re.sub(pattern, '', val2)
  if val1 == val2:
    return 'punctuation'
  if val1.startswith(val2) or val1.endswith(val2):
    return 'extends'
  if val2.startswith(val1) or val2.endswith(val1):
    return 'shortens'
  return 'different'

def note(record, remark):
  if 'comment' in record:
    record['comment'] = record['comment'] + ';' + remark
  record['comment'] = remark

def show_diff(m):
  (record, tag, val1, val2) = m
  brf = brief(record)
  if 'title' in tag:
    print '%-20s %s:' % (brf, tag)
    print "%9s '%s'" % (name1, val1)
    print "%9s '%s'" % (name2, val2)
  else:
    print "%-20s %s: %s '%s' vs. '%s' %s" % (brf, tag, name1, val1, val2, name2)

# Workflow

toc1 = batch.read_batch(sys.argv[1]) # Typically Hindawi
toc2 = batch.read_batch(sys.argv[2]) # Typically CEC

name1 = 'Hindawi'
name2 = 'CEC'

(matched1, unmatched1) = compare(toc1, toc2)
(matched2, unmatched2) = compare(toc2, toc1)

# diff all the matched1
# print all the unmatched2

filtered = [r for r in unmatched2 if not silly(r)]
print 'silly unmatched records in toc2:', len(unmatched2) - len(filtered)
print 'good unmatched records in toc2:', len(unmatched2)
extras_path = 'in-toc2-but-not-toc1.csv'
print >>sys.stderr, 'writing', extras_path
batch.write_batch(filtered,
                  extras_path,
                  ['volume', 'issue', 'start page', 'end page',
                   'year', 'doi', 'title', 'authors',
                   'inferred end page', 'comment'])

print
outpath = 'compare.csv'
with open(outpath, 'w') as outfile:
  print >>sys.stderr, 'writing', outpath
  writer = csv.writer(outfile)
  writer.writerow(['doi', 'volume', 'issue', 'start page', 'end page', 'key', 'how',
                   name1.lower(), name2.lower()])
  for key in ['volume', 'year', 'start page', 'end page',
              'doi', 'issue', 'title', 'authors']:
    m1 = []
    m2 = []
    for (record1, record2) in matched1:
      val1 = record1.get(key)
      val2 = record2.get(key)
      if val1 and val2 and val1 != val2:
        if not abbreviates(val2, val1):
          how = how_different(val1, val2, key)
          writer.writerow([record1.get('doi'),
                           record1.get('volume'),
                           record1.get('issue'),
                           record1.get('start page'),
                           record1.get('end page'),
                           key, how, val1, val2])
          if how == 'different':
            m2.append((record1, '%s mismatch' % key, val1, val2))
            note(record2, '%s mismatch: %s' % (key, val1))
          else:
            m1.append((record1, '%s %s' % (key, how), val1, val2))
    if len(m2) > 0:
      for m in m2:
        show_diff(m)
      print
    if len(m1) > 0:
      for m in m1:
        show_diff(m)
      print

merged = []
for record in unmatched1:
  note(record, 'Not at ' + name2)
  merged.append(record)
for record in unmatched2:
  note(record, 'Not at ' + name1)
  merged.append(record)

for (record1, record2) in matched1:
  merged.append(improve(record2, record1))

add_holdings_info(merged, batch.read_batch('cec-pdf-list.csv'))
add_bhl_pages(merged, batch.read_batch('bhl-start-pages.csv'))

batch.write_toc(merged, 'merged-toc.txt')

# -*- coding: utf-8 -*-

import sys, csv, re
import batch

# For a given function, a mapping from each value taken on by the
# function, to the set of records that have that value

def invert(fun, batch):
  m = {}                        # dict
  for record in batch:
    val = fun(record)
    if val:
      if val in m:
        m[val].append(record)
      else:
        m[val] = [record]
  return m

def read_batch(path):
  if path.endswith('.txt'):
    return read_toc(path)
  else:
    if not path.endswith('.csv'):
      print >>sys.stderr, '** assuming csv input:', path
    return read_csv(path)

def read_csv(path):
  with open(path, 'r') as infile:
    reader = csv.reader(infile)
    header = reader.next()
    batch = []
    for tuple in reader:
      record = {}
      for (key, val) in zip(header, tuple):
        if val != '':
          record[key] = val
      batch.append(record)
    print 'got:', len(batch)
    return batch

def write_batch(batch, path, order):
    rows = []
    for record in sorted(batch, key=record_sort_key):
        rows.append(map(lambda key:record.get(key), order))
    with open(path, 'w') as outfile:
        writer = csv.writer(outfile)
        writer.writerow(order)
        for row in rows:
            writer.writerow(row)

def record_sort_key(record):
    issue = record.get('issue')
    if issue: issue = maybe_int(issue.split('-')[0])
    return (maybe_int(record.get('volume')), # volume
            issue,
            maybe_int(record.get('start page')),
            maybe_int(get_last_page(record)),
            record.get('title'))          # title as tie-breaker

def maybe_int(field):
    if field == None:
        return field
    elif field.isdigit():
        return int(field)
    else:
        return field

def get_last_page(record):
    q = record.get('inferred end page')
    if q != None: return q
    return record.get('end page')

# Read ad hoc 'block style' format in which primary CEC curation is kept.
# Volume, year, and issue are carried forward from one block to the next.

translations = {'V': 'volume',
                'I': 'issue',
                'Y': 'year',
                'P': 'start page',
                'Q': 'end page',
                'R': 'inferred end page',
                'T': 'title',
                'A': 'authors',
                'D': 'doi',
                '#': 'comment',
                'S': 'cec pdf',
                'B': 'bhl start page'}
inverse_translations = {value: key for (key, value) in translations.items()}

def read_toc(path):             # Block style
  toc = []
  with open(path, 'r') as infile:
      record = None
      current_volume = current_issue = current_year = None
      previous_volume = None
      for line in infile:
          line = line.strip()
          if len(line) == 0:
              if record != None:

                  if 'volume' in record:
                      current_volume = record['volume']
                      if current_volume != previous_volume:
                          current_year = None
                          previous_volume = current_volume
                  elif current_volume:
                      record['volume'] = current_volume

                  if 'year' in record:
                      current_year = record['year']
                  elif current_year:
                      record['year'] = current_year
                  elif current_volume:
                      record['year'] = current_year = str(get_year(current_volume))

                  if 'issue' in record:
                      current_issue = record['issue']
                  elif current_issue:
                      record['issue'] = current_issue

                  if (record.get('start page', '') != '' or
                      record.get('end page', '') != '' or
                      record.get('title','') != '' or
                      record.get('authors','') != '' or
                      record.get('doi','') != ''):
                      toc.append(record)
                  record = None
          else:
              if record == None:
                  # Start of new record
                  record = {}
                  saw_volume = saw_issue = False
              if line[0] == '#':
                  key = 'comment'
                  value = line[1:].strip()
              else:
                  parts = line.split('\t', 1)
                  if len(parts) != 2:
                      print '** wrong number of parts: %s' % (parts,)
                      print record
                      continue
                  key = translations.get(parts[0])
                  if key == None:
                      print '** unrecognized tag:', parts
                      continue
                  value = parts[1].strip()
                  if key == 'authors' or key == 'title':
                    value = batch.replace_entities(value)
                  if key == 'title':
                    cleaned = demarkupify(value)
                    if cleaned != value:
                      record['original title'] = value
                      value = cleaned
                  # minimal validation
                  if key in ['start page', 'end page', 'volume', 'year']:
                    if not value.isdigit():
                      print '** bad field value', key, value, record
              if value == 'None':
                pass
              elif key in record:
                record[key] = record[key] + ';' + value
              else:
                record[key] = value
  return batch.infer_end_pages(toc)

# One year per volume starting with volume 10 in 1903
# Some volumes take multiple years but this is handled in the metadata

def get_year(v):
    v = int(v)
    if v == 7:
        return 1894             # foo
    elif v < 11:
        year = 1871 + (v * 3)
        # Two year gap from volume 3 to volume 4
        if v > 4:
            year += 2
        return year
    elif v == 103:
        return 2000
    else:
        return v + (1903 - 10)

# Write batch as block-style TOC file

def write_toc(batch, path):
  with open(path, 'w') as outfile:
    for record in sorted(batch, key=record_sort_key):
      # Write one block
      for key in sorted(record.keys(), key=field_sort_key):
        value = record[key]
        if key == 'comment':
          for value in value.split(';'):
            outfile.write('# %s\n' % value)
        elif key == 'original title':
          pass
        else:
          if key == 'title' and 'original title' in record:
            orig = record['original title']
            if value == demarkupify(orig):
              value = orig
          for value in value.split(';'):
            outfile.write('%s\t%s\n' % (inverse_translations[key], value))
      outfile.write('\n')

def field_sort_key(key):
  return field_sort_order[key]

# Order in which to write fields in 'block style'

field_sort_order = {'volume': 20,
                    'issue': 30,
                    'start page': 40,
                    'end page': 50,
                    'inferred end page': 55,
                    'year': 60,
                    'authors': 62,
                    'title': 64,
                    'original title': 66,    # Suppress
                    'doi': 70,
                    'cec pdf': 80,
                    'bhl start page': 85,
                    'comment': 90}

# Whole-TOC inference of end pages

def infer_end_pages(toc):
  count = 0
  previous = None
  for record in toc:
        if ('start page' in record and
            previous and
            'start page' in previous and
            previous.get('issue') == record.get('issue') and
            not 'end page' in previous):
            p1 = int(previous['start page'])
            p2 = int(record['start page'])
            if p2 > p1:
                previous['inferred end page'] = str(p2 - 1)
                count += 1
            elif not 'Index' in previous.get('title'):
                print 'cannot infer end page because start pages out of order (%s >= %s): %s' % (p1, p2, previous)
        previous = record
  print 'inferred %s end pages' % count
  return toc

# For cleaning

def replace_entities(s):
  # Diacritics
  s = s.replace('&eaigu;', 'é')
  s = s.replace('&eacute;', 'é')
  s = s.replace('&euml;', 'ë')
  s = s.replace('&egrave;', 'è')
  s = s.replace('&ouml;', 'ö')
  s = s.replace('&uuml;', 'ü')
  s = s.replace('&acir;', 'å')
  s = s.replace('&oacute;', 'ó')
  s = s.replace('&iacute;', 'í')
  s = s.replace('&aacute;', 'á')
  s = s.replace('&aaigu;', 'á')
  s = s.replace('&atilde;', 'ã')
  s = s.replace('&uacute;', 'ú')
  s = s.replace('&auml;', 'ä')
  s = s.replace('&ocirc;', 'ô')
  # Ligatures
  s = s.replace('&oelig;', 'oe')
  s = s.replace('&OElig;', 'Oe')
  s = s.replace('&aelig;', 'ae')
  s = s.replace('&AElig;', 'Ae')
  # Punctuation
  s = s.replace('&mdash;', ' - ')
  s = s.replace('&ndash;', '-')
  s = s.replace('&ldquo;', '"')
  s = s.replace('&rdquo;', '"')
  s = s.replace('&amp;', '&')
  s = s.replace('&apos;', "'")
  s = s.replace('&lsquo;', "'")
  s = s.replace('&rsquo;', "'")
  return s

# Remove HTML markup from string

tag_pattern = re.compile('<[a-zA-Z/]+>')

def demarkupify(s):
  if s:
    return re.sub(tag_pattern, '', s, 99)
  else:
    return s

# Clean individual records of markup

def clean_records(toc):
  for record in toc:
    clean_record(record)
  return toc

def clean_record(record):
  if 'title' in record:
    value = record['title']
    cleaned = demarkupify(value)
    if cleaned != value:
      record['title'] = cleaned
      record['original title'] = value
  return record

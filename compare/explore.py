
import sys, csv, re

def read_batches(paths):
  return map(read_batch, sys.argv[1:])

def all_keyses(batches):
  keyses = map(all_keys, batches)
  return keyses[0].union(*keyses[1:])

def all_keys(batch):
  keys = set()
  for record in batch:
    for key in record.keys():
      keys.add(key)
  return keys

def read_batch(path):
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
    return batch

# Build up new functions from existing ones

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

def vip(record):
  return multi(record, ['volume', 'issue', 'start page'])
  
def vpt(record):
  t = record.get('title')
  if t:
    z = vp(record)
    if z:
      return z + (longest_word(t),)
  return None
  
def longest_word(s):
  if s:
    s1 = re.split('[ <>)(,/.]', s)
    return sorted(s1, key=lambda w: (len(w), w))[0]
  return None

def first_author(a):
  if a:
    aa = a.split(';')
    if len(aa) > 0:
      a1 = aa[0].replace(', Jr', ' Jr')
      a1 = a1.split(',')
      a2 = a1[-1]
      return a2.split(' ')[0]
  return a

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

# Functions is a dict from strings to one-argument functions

def analyze(batches, functions):

  # Compute inverses
  boku = {}    # funname -> [batch-specific inverses]
  for fun_name in functions.keys():
    fun = functions[fun_name]
    inverses = map(lambda batch: invert(fun, batch), batches)
    boku[fun_name] = inverses

  reports = []
  batch_numbers = range(0, len(batches))
  for fun_name in functions.keys():
    fun = functions[fun_name]
    # The inverse of fun, for each batch
    inverses = boku[fun_name]
    count = 0
    for b1 in batch_numbers:
      for b2 in batch_numbers:
        i2 = inverses[b2]
        for record1 in batches[b1]:
          val1 = fun(record1)
          if val1:
            records2 = i2.get(val1)
            if records2 and len(records2) == 1:
              count += 1
    reports.append((count, fun_name))
    boku[fun_name] = inverses
  reports = sorted(reports)
  reports.reverse()
  for (count, fun_name) in reports:
    print "%s:\t%s" % (fun_name, count)
  return (boku, reports)

def best_mutual_matches(batches, functions, boku, reports):
  for fun_name in boku.keys():
    fun = functions[fun_name]
    value = fun(record)
    inverses = boku[fun_name]
    choices = []
    for b in range(0, len(batches)):
      records = inverses[b].get(value)
      if records:
        if len(records) < len(choices):
          choices = records
      if len(choices) == 0:
        report_unmatched(record)
      elsif len(choices) > 1:
        report_ambiguous(record, choices)
      elsif record != choices[0]:
        report_diff(record, choices[0])

def report_diff(r1, r2):
  diffs = []
  for key in r1.keys():
    v1 = r1.get(key)
    v2 = r2.get(key)
    if v1 and v2:
      if v1 != v2:
        diffs.append((key, v1, v2))
  if len(diffs) > 0:
    print 'diffs', brief(r1), brief(r2), diffs

def report_ambiguous(record, records):
  print 'ambiguous', brief(record), map(brief, records)

def report_unmatched(record, records):
  print 'unmatched', brief(record)

def brief(r):
    return '%s(%s):%s-%s' % (r.get('volume'), r.get('issue'), r.get('start page'), r.get('end page'))

def fixed_authors(record):
  return record.get('authors')



batches = read_batches(sys.argv[1:])
keys = all_keyses(batches)

def getter(key):
  return lambda record: record.get(key)

functions = {key: getter(key) for key in keys}
for (name, fun) in [('vp', vp),
                    ('vip', vip),
                    ('vpt', vpt),
                    ('fixed', fixed_authors)]:
  functions[name] = fun

(boku, reports) = analyze(batches, functions)

for batch in batches:
  for record in batch:
    best_mutual_matches(record, batches, functions, boku, reports)

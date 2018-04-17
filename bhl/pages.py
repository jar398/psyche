import csv, json, os, codecs

"""
Manual changes to no-doi.txt:

Deleted:
8,249,1,2,Antennal structure of certain Diplosids (Plate I.),E. Porter Felt
32,6,323,328,Index,
63,4,147,148,Index to Authors,
64,4,149,150,Index to authors,

Changed page 79 to 81 in volume 13
Changed last page of 83,3-4,336,376 from 378 to to 376
"""

# Volumes that have missing articles (no DOI):

item_volumes = {44238: (8,),
                42922: (9,),
                43369: (12, 13, 14,),    # volumes 12-14
                45282: (15,),    # volume 15 (incomplete?)
                43796: (16,),
                43955: (18, 19,),    # v. 18-19
                48923: (22,),
                55101: (23,),
                207080: (32, 33,),   # v. 32-33
                229069: (38, 39, 40, 41,),   # v. 38-41
                207000: (47, 48, 49, 50,),
                207061: (56, 57,),
                206933: (63, 64,),
                207235: (72,),
                206917: (74,),
                207022: (75,),
                207079: (78,),
                207171: (83,)}

# Problems needing solutions:
#  Multiple pages 56:1 50909833, 50909861 (59)
#  Missing: 8:3-5 3 pages (246)

# ("volume", num) -> pageid
curated_pages = {("8", 1): 12122938, # plate 1
                 ("8", 3): 12122937,
                 ("9", 4): 11642156, # other one is volume index
                 ("9", 5): 11642157,
                 ("9", 6): 11642158,
                 ("9", 7): 11642159,
                 ("12", 4): 11809377,
                 ("12", 5): 11809376,
                 ("13", 29): 11809543,
                 # 13:79-80 is junk, first page is actually 81, not 79
                 # All v. 14 page numbers (thru 11809703-11809842) are off by 2
                 ("14", 1): 11809703,
                 ("14", 111): 11809829,
                 ("14", 113): 11809831,
                 ("15", 89): 12551516,
                 ("15", 96): 12551523,
                 ("15", 97): 12551524,
                 ("18", 1): 12032920,
                 ("18", 45): 12032984,
                 ("32", 1): 50914700,
                 ("32", 195): 50914912,
                 ("47", 45): 50901481,
                 ("47", 105): 50901545,
                 ("49", 3): 50901805,    # other one is index
                 ("49", 4): 50901806,    # other one is index
                 ("49", 5): 50901807,    # other one is index
                 ("49", 6): 50901808,    # other one is index
                 # BHL is pretty messed up for volume 56.  I verified the following...
                 ("56", 1): 50909833,
                 # Pages 50909859 (TOC) through 50909886 (26) are duplicates
                 ("56", 27): 50909887,   # Hull
                 # Pages 50909915 (27) through 50909942 (back matter) are duplicates
                 ("57", 109): 50909861,  # Back to normal
                 ("78", 1): 50914312,
                 ("83", 223): 50926646,
                 ("83", 224): 50926647,  # guessing
                 }

curated_pageids = {pageid: key for (key, pageid) in curated_pages.items()}

# Plates, volume 8
#   Plate 3 - Scudder - page 123  - there is no plate 3 in that issue.

plates = [(12122938, "I", "Felt", 3),
          (12122928, 2, "Morse", 35),
          (12123103, 4, "Folsom", 183),
          (12123130, 5, "Scudder", 207),
          (12123145, 6, "Wickham", 219),
          (12123183, 7, "Morse", 255),
          (12123247, 8, "Morse", 315)]

plate_index = {(str(8), num): pageid for (pageid, plate, auth, num) in plates}

def path_for_item(itemid):
    return 'bhl-pages-%s.json' % item_volumes[itemid][0]

volume_to_item = {}             # string to int

for (itemid, volumes) in sorted(item_volumes.items()):
    path = path_for_item(itemid)     # just uses first volume
    if os.path.exists(path):
        for volume in volumes:
            volume_to_item[str(volume)] = itemid
    else:
        if itemid != 0:
            print ('wget -O - "https://www.biodiversitylibrary.org/api2/httpquery.ashx?op=GetItemMetadata&itemid=%s&pages=t&apikey=a0ab085a-3a47-4aa4-bd92-66fa34d3e8fc&format=json" | ~/a/ot/repo/reference-taxonomy/util/jsonpp.py >%s' %
               (itemid, path))

def load_metadata(path):
    metadata = []
    with open(path, 'r') as infile:
        reader = csv.reader(infile)
        reader.next()  # header
        for row in reader:
            metadata.append(row)
    return metadata

metadata = load_metadata('/Users/jar/repo/psyche/no-doi.txt')
print 'Articles without DOIs:', len(metadata)

page_table = {}    # maps ("volume", pagenum) to pageid (int)
have_pages = {}    # maps pageid (int) to itemid (int)

# Get mapping from (volume, pagenum) to pageid
# N.b. strings in the json are unicode

def load_item(itemid, page_table):
    path = path_for_item(itemid)
    volumes = map(str, item_volumes[itemid])    # tuple of ints
    print 'Loading BHL info for volumes %s from %s' % (volumes, path)
    page_info = []
    with open(path, 'r') as infile:
        j = json.load(infile)
        for page in j["Result"]["Pages"]:
            pageid = int(page["PageID"])
            if pageid in curated_pageids:
                page_info.append((pageid, curated_pageids[pageid][1]))
                continue

            # Four special cases: 12/13/14, 18/19, 32/33, 38/39/40/41
            # Could say: if this page number < last page number, advance volume
            elif "PageNumbers" in page:
                have_pages[pageid] = True
                # Volume 56 duplicates
                if pageid >= 50909859 and pageid <= 50909886:
                    continue
                if pageid >= 50909915 and pageid <= 50909942:
                    continue
                # Volume 14 bad page number
                if pageid >= 11809703 and pageid <= 11809842:
                    continue
                for p in page["PageNumbers"]:
                    prefix = p.get("Prefix", None)
                    number = p.get("Number", None)
                    if number and number.startswith("[") and number.endswith("]"):
                        number = number[1:-1]
                    # Pay no attention to the supplements - they already have DOIs
                    if prefix and prefix.startswith("Supp"):
                        break
                    if prefix and prefix != "Page" and not prefix.startswith("No."):
                        print "  Page %s is %s %s" % (pageid, p["Prefix"], p["Number"])
                    elif number.isdigit():
                        # Capture volume when provided?  page["Volume"]
                        page_info.append((pageid, int(number)))
        volume = volumes[0]     # string
        remaining_volumes = volumes[1:]
        previous_num = -1000
        for (pageid, num) in sorted(page_info):    # sort by int pageid then by int page
            if pageid in curated_pageids:
                (volume, num) = curated_pageids[pageid]
                # print "  Found pageid %s = %s:%s" % (pageid, volume, num)
            else:
                if (num < previous_num - 40 and len(remaining_volumes) > 0):
                    new_volume = remaining_volumes[0]
                    if False:
                        print '  Going from volume %s page %s to volume %s page %s' % \
                            (volume, previous_num, new_volume, num)
                    volume = new_volume
                    remaining_volumes = remaining_volumes[1:]
                key = (volume, num)
                if key in page_table and page_table[key] != pageid and not key in curated_pages:
                    print ("  Page %s:%s has multiple BHL pages %s, %s" %
                           (volume, num, page_table[key], pageid))
                else:
                    page_table[key] = pageid
            previous_num = num
    return len(page_info)

for (key, pageid) in curated_pages.items():
    page_table[key] = pageid

for itemid in sorted(item_volumes.keys()):
    load_item(itemid, page_table)

# Metadata is in order by volume and page

def dump(page_table, metadata):
    path = 'article-pages.csv'
    print 'Writing', path
    wins = 0
    assigned_id = None       # pageid for most recent page that has (volume, pagenum)
    assigned_volume = None
    assigned_page = None
    with open(path, 'w') as outfile:
        writer = csv.writer(outfile)
        for met in metadata:
            volume = met[0]
            start = int(met[2])
            end = int(met[3])
            tag = "%s:%s-%s" % (volume, start, end)
            pageids = []
            guess_count = 0
            missing_count = 0
            for num in range(start, end+1):
                key = (volume, num)
                if key in page_table:
                    pageid = page_table[key]
                    pageids.append(pageid)
                    assigned_id = int(pageid)
                    assigned_volume = volume
                    assigned_page = num
                elif volume in volume_to_item:    # string to int
                    if assigned_volume == volume:
                        # Estimate pageid based on recently processed page
                        pageid = assigned_id + (num - assigned_page)
                        if pageid in have_pages:
                            pageids.append(pageid)
                            guess_count += 1
                        else:
                            # Never happens
                            print 'Absent:', tag, num
                    else:
                        missing_count += 1
            plate_key = (volume, start)
            if plate_key in plate_index:
                print "  Placed plate in %s:%s" % plate_key
                pageids.append(plate_index[plate_key])
            if missing_count > 0:
                print '%s missing %s pages out of %s' % \
                    (tag, missing_count, end-start+1)
            if len(pageids) > 0:
                if guess_count > 0:
                    print '%s guessing %s pages out of %s' % \
                        (tag, guess_count, end-start+1)
            title = met[4]
            ids_string = ';'.join(map(str, pageids))
            writer.writerow([met[0], met[2], met[3], title[0:10],
                             ids_string, str(guess_count), str(missing_count)])
            wins += 1
    print 'Found pages for %s articles' % wins

dump(page_table, metadata)


# Page 11642148 is a page 'iv' in the index to volume 9, not page '4'
# as it says

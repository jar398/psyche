
Master Psyche table of contents

Here is what I would like to see:

- One entry per article published in Psyche before 2001.  There are
  about 5500 of them.
- For each article, basic article metadata (volume, first page, last page, title,
  authors).
- For each article, electronics 'holdings' information consisting of
  . Hindawi DOI (when there is one)
  . BHL link of some kind (when article is in BHL); to volume at the
     very least, ideally to specific page
  . (Optional: links to Ent Club's archive; not really needed since
     the Club has exactly the same set of articles as Hindawi)

Hindawi covers 95% of these articles.  I don't know what BHL's
coverage is but it's possible that it's 100%.  I don't don't whether
there are articles that neither Hindawi nor BHL has; I expect there
are.  These need to be listed in the ToC, if they exist.

Sources of TOC information:

- I have a list of all of the Crossref DOIs with volume, issue, and first
  and list pages (CSV format)
- Additional Hindawi metadata can be retrieved one article at a time
  from Crossref (e.g. `curl -L -H "Accept: application/json" http://dx.doi.org/10.1155/1921/52645`)
- We might be able to get information directly from Hindawi but I'd
  rather not harrass them
- What metadata does BHL have? I don't know.
- Some article metadata will have to be curated for the 5% missing
  from Hindawi (approximately 250 articles).  Harvard has paper copies
  of everything.  I have paper copies of many, but not all, of the 
  articles that Hindawi doesn't have.


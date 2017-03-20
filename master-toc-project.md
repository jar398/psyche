
# Master Psyche table of contents

Here is what I would like to see:

- One entry per article published in Psyche before 2001.  There are
  about 5500 of them.
- For each article, basic article metadata (volume, first page, last page, title,
  authors).
- For each article, electronics 'holdings' information consisting of
  * Hindawi DOI (when there is one)
  * BHL link of some kind (when article is in BHL); to volume at the
     very least, ideally to specific page
  * (Optional: links to Ent Club's archive; not really needed since
     the Club has exactly the same set of articles as Hindawi)

Hindawi covers 95% of these articles.  I don't know what BHL's
coverage is but it's possible that it's 100%.  I don't know whether
there are articles that neither Hindawi nor BHL has; I expect there
are.  These need to be listed in the ToC, if they exist.

Sources of TOC information:

- I have a list of all of the Crossref DOIs with volume, issue, and first
  and list pages (CSV format).  Not every DOI is for a legitimate
  article, but I don't think that matters very much.
- Additional Hindawi metadata (title, authors) can be retrieved one article at a time
  from Crossref (e.g. `curl -L -H "Accept: application/json" http://dx.doi.org/10.1155/1921/52645`).
  Unfortunately not every record lists authors.
- We might be able to get Hindawi's metadata directly from Hindawi
  (rather than through Crossref) I'd prefer not to harrass them.
- I also have the metadata I use to generate the tables of contents
  for the Ent Club's Psyche archive web site.  It's a single text file in 
  an ad hoc but machine readable form.  The Club paid to curate most
  of this.  It is mostly redundant with Hindawi's metadata.  It has no
  information for volumes 1-17.  But it is likely to have some author
  information that's missing from Hindawi's metadata.
- What metadata does BHL have? I don't know.
- Some article metadata will have to be curated for the 5% missing
  from Hindawi (approximately 250 articles).  
  * BHL will have most if
    not all individual issue tables of contents as page images; they can be
    OCR'd and cleaned up, or transcribed manually.
  * Harvard has paper copies of everything.
  * The Ent Club has paper copies of
    most, but not all, of the issues that Hindawi doesn't have.

The corpus is small enough that the master TOC will fit easily into a
single quite manageable file.  It should be in some machine readable
form (e.g. CSV or JSON), from which it can be rendered in any other
form (e.g. as HTML, entered into a database, etc.).

Possible applications:
* getting all articles into Biostor
* one-stop shopping for anyone looking for Psyche articles (could put
  on Ent Club web site)
* useful for any kind of corpus analysis anyone might want to do
  (species or genus index, species descriptions, localities, etc.)

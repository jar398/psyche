; TBD: File download sizes

; To generate HTML from this file, start Scheme 48 (from s48.org) and
; issue the commands ",config ... (doit ...)" below, replacing
; <target-directory> with a directory of your choice that is not a 
; subdirectory of this one.
;
; Or use the Makefile.

(define articles-root "http://psyche.entclub.org/pdf/")
;(define text-files-root "/Users/jar/Scratch/Psyche/text/")
(define text-files-root "../text/")


"
,bench
,config ,load web/web-config.scm
,open define-record-types sorting c-system-function tables
,open extended-ports signals posix-files
,open html xml web-utils
,load build-web-site.sch articles.sch journal-meta.sch dois.sch
,load pdf-file-sizes.sch
(doit <target-directory>)
"

(define (testit) (doit "toc.txt" "~/Scratch/Psyche/build"))

; There is a module system conflict: both POSIX and HTML export
; bindings of LINK.
; 
; We would need the POSIX structure only for mkdir -p (formerly we
; also used it for the file existence check).
; Use C-SYSTEM-FUNCTION instead of POSIX for now.

(define (doit toc-file build-dir)
  (do-quick-part toc-file build-dir)
  (do-slow-part-1 build-dir))

(define (do-quick-part toc-file build-dir)
  (read-prepared-toc-file toc-file)
  (write-page build-dir
	      "index.html"
	      (make-main-page "index.html"))
  (write-page build-dir
	      "master-toc.html"
	      (make-master-toc-page "master-toc.html"))
  (write-page build-dir
	      "about.html"
	      (make-about-page "about.html"))
  (write-page build-dir
	      "contact.html"
	      (make-contact-page "contact.html")))

(define (do-slow-part toc-file build-dir)
  (read-prepared-toc-file toc-file)
  (do-slow-part-1 build-dir))

(define (do-slow-part-1 build-dir)
  (system (string-append "mkdir -p "
			 (path->filename build-dir "metadata")))
  ;; (write-articles-metadata build-dir)  -- too big, now split among vols
  (for-each (lambda (volnum)
	      (process-one-volume volnum build-dir))
	    (cdr (iota 104))
	    )
  (newline))

(define-record-type article :article
  (make-article stem title authors volume year pages issue id comments)
  (stem article-stem)          ;E.g. "30-013"
  (title article-title)
  (authors article-authors)    ;list of authors
  (volume article-volume)
  (year article-year)
  (pages article-pages set-article-pages!)
  (id article-id)		;sequential within volume
  (issue article-issue)
  (comments article-comments))

; Write TOC page, and one 'stub' page per article.

(define (process-one-volume volnum build-dir)
  (let ((articles (create-article-list volnum)))
    (if articles
	(begin
	  (display volnum) (display #\space)
	  ;; Directory will need to be created if only to hold the toc file.
	  (system (string-append "mkdir -p "
				 (path->filename build-dir (number->string volnum))))
	  (let ((volpath (path-to-toc volnum)))
	    (write-page build-dir
			volpath
			(make-volume-toc-page volnum articles build-dir volpath)))
	  (for-each (lambda (article)
		      (if (and article (prepared? article))
			  ;; Write the article's own page.
			  (write-article-page article build-dir)))
		    articles)
	  (write-volume-metadata volnum
				 (path->filename build-dir (path-to-metadata volnum)))))))

(define (create-article-list volnum)
  (let ((toc (get-volume-toc volnum))
	(prepared (get-volume-scans volnum))) ;List of article id's
    (if toc
	;; Augment TOC with any additional files listed in
	;; the prepared articles list.
	(if prepared
	    (list-sort article<
		       (append toc
			       (map (lambda (id)
				      (dummy-article-info volnum id))
				    (filter (lambda (id)
					      (and (string? id)
						   (not (maybe-article-info volnum id))))
					    prepared))))
	    toc)
	;; No TOC yet; just use the prepared article list (e.g. volume 1).
	(if prepared
	    (map (lambda (id)
		   (dummy-article-info volnum id))
		 prepared)
	    #f))))

(define (article< a1 a2)
  (if (= (article-year a1) (article-year a2))
      (string<? (article-stem a1)
		(article-stem a2))
      (< (article-year a1) (article-year a2))))

(define (make-volume-toc-page volnum articles build-dir here)
  (let* ((prepared (get-volume-scans volnum)) ;List of stems "30-013"
	 (aux (if prepared
		  (filter (lambda (x) (not (integer? x)))
			  prepared)
		  '())))
    (make-articles-page (span "Volume " volnum
			      " (" (volume->years volnum) ")"
			      (if prepared
				  '()
				  " [not yet available on web site]"))
			articles
			(compose-aux-links aux volnum here)
			(string-append "Psyche "
				       (number->string volnum))
			here)))

(define (compose-aux-links aux volnum here)
  (let ((issue-numbers ; (reverse ...)		;foo
		       (filter (lambda (x) x)
			       (map cover-info aux))))
    ;; TBD: also deal with Index and stray-plates.
    (span (map (lambda (issue-number)
		 (p (span (class= "contentlink")
			  (a (href= ;; (symbol->string aux-thing)
			      (string-append articles-root
					     (number->string volnum)
					     "/"
					     (number->string volnum)
					     "-covers-n" issue-number ".pdf"))
			     ;; Text is 
			     "Front and back matter for issue "
			     issue-number))))
	       issue-numbers)
	  (if (memq 'index aux)
	      (p (span (class= "contentlink")
		       (a (href=
			   (string-append articles-root
					  (number->string volnum)
					  "/"
					  (number->string volnum)
					  "-index" ".pdf"))
			  "Index to volume "
			  volnum)))
	      (span))
	  (p (a (hlink (path-to-metadata volnum) here)
		"Table of contents metadata (XML)")))))

; Not sure where to put the .xml file: in the volume directory
; (e.g. 10/metadata.xml), or in a metadata directory (metadata/10.xml)?

(define (path-to-metadata volnum)
  (if #t
      (cons "metadata" (string-append (number->string volnum) ".xml"))
      (cons (number->string volnum) "metadata.xml")))

; If article name starts with "covers-n" then return the issue number
; as a string.

(define (cover-info sc)
  (if (symbol? sc)
      (let ((z (symbol->string sc)))
	(if (and (> (string-length z) 8)
		 (equal? (substring z 0 8) "covers-n"))
	    (substring z 8 (string-length z))    ;e.g. "1+2"
	    #f))
      #f))

(define (path-to-toc volnum)
  (path-in-volume volnum "toc.html"))

(define (path-to-article article)
  (path-in-volume (article-volume article)
		  (string-append (article-stem article)
				 ".html")))

(define (path-in-volume volnum path)
  (cons (number->string volnum) path))

(define (create-stem volnum id)
  (let ((id (stringify id)))
    (string-append (number->string volnum)
		   "-"
		   (case (string-length id)
		     ((1) "00")
		     ((2) "0")
		     (else ""))
		   id)))

(define (write-article-page article build-dir)
  (let ((path (path-to-article article)))
    (write-page build-dir
		path
		(make-article-page path article))))

; Quoth Google Scholar on May 10, 2007:
;
; We recommend embedding the following tags* within your articles' abstract
; pages:
;
; <meta name="citation_journal_title" content="Journal Name">
; <meta name="citation_authors" 
;    content="Last Name1, First Name1; Last Name2, First Name2">
; <meta name="citation_title" content="Article Title">
; <meta name="citation_date" content="01/01/2007">
; <meta name="citation_volume" content="10">
; <meta name="citation_issue" content="1">
; <meta name="citation_firstpage" content="1">
; <meta name="citation_lastpage" content="15">
; <meta name="citation_doi" content="10.1074/jbc.M309524200">
; <meta name="citation_pdf_url"
;    content="http://www.publishername.org/10/1/1.pdf">
; <meta name="citation_abstract_html_url"
;    content="http://www.publishername.org/cgi/content/abstract/10/1/1">
; <meta name="citation_fulltext_html_url"
;    content="http://www.publishername.org/cgi/content/full/10/1/1">  
; <meta name="dc.Contributor" content="Last Name1, First Name1">
; <meta name="dc.Contributor" content="Last Name2, First Name2">
; <meta name="dc.Title" content="Article Title">
; <meta name="dc.Date" content="01/01/2007">
; <meta name="citation_publisher" content="Publisher Name">

; Table of contents for one volume or for a set of articles (query result?)

(define (make-article-page here article)
  (let ((pdf-link (article-pdf-link article here))
	(title-string (article-title-string article))
	(inverted-authors (map (lambda (name)
				 (invert-name (remove-markup name)))
			       (article-authors article))))
    (apply-meta-boilerplate
     here
     (string-append "Psyche "
		    (number->string (article-volume article))
		    ":"
		    (article-page-range article))
     (list (meta (name= "citation_journal_title")
		 (content= "Psyche"))
	   ;; authors
	   (if (not (null? inverted-authors))
	       (meta (name= "citation_authors")
		     (content=
		      (apply string-append
			     (car inverted-authors)
			     (apply append (map (lambda (inv)
						  (list "; " inv))
						(cdr inverted-authors))))))
	       '())
	   (meta (name= "citation_title")
		 (content= title-string))
	   (meta (name= "citation_date")
		 (content= (article-year article)))
	   (meta (name= "citation_volume")
		 (content= (article-volume article)))
	   (let ((issue (article-issue article)))
	     (if issue
		 (meta (name= "citation_issue")
		       (content= issue))
		 (begin
		   (if (not (null? (article-authors article)))
		       (begin (write `(missing issue: ,(article-volume article) ,@(article-pages article)))
			      (newline)))
		   '())))		;?
	   (let ((pages (article-pages article)))
	     (if pages
		 (list (meta (name= "citation_firstpage")
			     (content= (car pages)))
		       (if (integer? (cadr pages))
			   (meta (name= "citation_lastpage")
				 (content= (cadr pages)))
			   '()))
		 '()))
	   
	   (meta (name= "citation_pdf_url")
		 (content= (article-pdf-url article here)))
	   (meta (name= "citation_publisher")
		 (content= "Cambridge Entomological Club"))
	   ;; citation_abstract_html_url
	   ;; citation_fulltext_html_url
	   (meta (name= "dc.Title")
		 (content= title-string))
	   (meta (name= "dc.Date")
		 (content= (article-year article)))
	   (map (lambda (author)
		  (meta (name= "dc.Contributor")
			(content= (remove-markup author))))
		inverted-authors))
     (div
      (p (if (not (null? (article-authors article)))
	     (list (span (class= "authors")
			 (maybe-with-period
			  (andify (article-authors article))))
		   (br))
	     '())
	 (span (class= "title")
	       (maybe-with-period
		(article-title article)))
	 (br)
	 (maybe-with-period
	  (article-citation article)))

      (p (span (class= "contentlink")
	       pdf-link)
	  
	 (br)
	 (let ((permalink (string-append "http://psyche.entclub.org/"
					 (path->string here))))
	   (span (class= "stableurl")
		 (a (href= permalink)
		    "Durable link: "
		    permalink)))

	 (br)
	 (if (article-pages article)
	     (let* ((key (vpq->key (article-volume article)
				   (car (article-pages article))
				   (cadr (article-pages article))))
		    (doi-list (table-ref dois key)))
	       (if (pair? doi-list)
		   (if (null? (cdr doi-list))
		       (let ((doi (car doi-list)))
			 (span (class= "stableurl")
			       (a (href= (string-append "http://dx.doi.org/" doi))
				  "At Hindawi: doi:"
				  doi)
			       (br)))
		       '())	  ;Ambiguous... normal
		   ;; TBD: filter out "Exchange Column"
		   (if (and (not (equal? (article-title article) "Exchange Column"))
			    (>= (article-volume article) 17))
		       (begin (write `(no-doi ,key))
			      (newline)
			      '())
		       '())))
	     '())

	 (make-article-abstract article)

	 (hr)
	 (let ((volnum (article-volume article)))
	   (span (a (hlink (path-to-toc volnum) here)
		    "Volume " volnum " table of contents")))
	 )))))

(define (make-article-abstract article)
  (let ((fname (string-append text-files-root
			      (number->string (article-volume article))
			      "/"
			      (article-stem article)
			      ".txt")))
    (if (accessible? fname (access-mode read))
	(call-with-input-file fname
	  (lambda (iport)
	    ;; Skip over header.  Usually about 6 lines.
	    (let loop ()
	      (let ((line (read-line-foo iport)))
		(if (eof-object? line)
		    (warn "ill-formed .txt file")
		    (if (= (string-length line) 0)
			'ok
			(loop)))))
	    (list
	     (hr)
	     (p (i "The following unprocessed text is extracted from the PDF file, and "
		   "is likely to be both incomplete and full of errors. "
		   "Please consult the PDF file for the complete article."))
	     (p (reverse
		 (let loop ((items '()) (count 0))
		   (let ((line (read-line-foo iport)))
		     (if (eof-object? line)
			 items
			 (let ((items (cons line items)))
			   (if (> count 5000) ;increased, was 500
			       items
			       (loop (if (> (string-length line) 40)
					 items
					 (cons (br) items))
				     (+ count 1))))))))))))
	(begin (write `(no text file ,fname)) (newline)
	       '()))))

(define (write-page build-dir path item)
  (call-with-output-file (path->filename build-dir path)
    (lambda (port)
      (write-item item port))))

(define (make-master-toc-page here)
  (apply-boilerplate here "Psyche master table of contents"
   (div
    (h3 "Tables of Contents")

    (p "For some volumes, articles and/or table of contents are not yet available on this web site.")

    (let* ((vs (map (lambda (volnum)
		      (let ((foo
			     (td (volume-stuff volnum here))))
			foo))
		    (cdr (iota 104))))
	   (k 3)			;Number of columns
	   (n (length vs)) ;103
	   ;; Add dummy entries to end of volumes list
	   (vs (append vs (map (lambda (i) '()) (cdr (iota k)))))
	   (n/k (/ (+ n (- k 1)) k))) ;35
      (table (width= "100%")
	     (apply map
		    (lambda vv (apply tr vv))
		    (map (lambda (i)
			   (sublist vs (* i n/k) (* (+ i 1) n/k)))
			 (iota k))))))))
		
(define (round-up-to-nearest-multiple n k)
  (- (+ n (- k 1)) (remainder (+ n (- k 1)) k)))

(define (volume-stuff volnum here)
  (let* ((stuff (span "Volume "
		      volnum
		      " ("
		      (volume->years volnum)
		      ")"))
	 (stuff (if (get-volume-toc volnum)
		    stuff
		    (span "[" stuff "]"))))
    (if (or (get-volume-scans volnum)
	    (get-volume-toc volnum))
	(a (hlink (path-to-toc volnum)
		  here)
	   stuff)
	stuff)))

(define (make-about-page here)
  (apply-boilerplate here "About Psyche"
   (div
    (h3 "About " (i "Psyche"))

    (p (i "Psyche") " is a journal for the publication of "
       "'biological contributions upon Arthropoda from any competent person.' "
       "It was founded in 1874 by the "
       (a (href= "http://entclub.org/") "Cambridge Entomological Club")
       ". "
       "The title derives from the Greek word for butterfly. ")

    (p "The Club transferred management of the journal to "
       (a (href= "http://www.hindawi.com/journals/psyche/")
	  "Hindawi Publishing Corporation")
       " in July 2007. "
       "Hindawi "
       (a (href= "http://www.hindawi.com/journals/psyche/guidelines.html")
	  "accepts manuscripts")
       " for review "
       "and publishes new articles online as the are ready.  "
       "Access to new articles is open; there are no "
       "subscription or access charges.")

    (p "The Cambridge Entomological Club will honor written requests for refunds "
       "of advance payment to CEC for issues not received (through volume 103). "
       "Indicate the amount paid and "
       "which issues were expected but not received, "
       "and include an email address for correspondence. "
       "Address requests to "
       "Cambridge Entomological Club,"
       " 26 Oxford St., Cambridge, MA 02138.")

    (p "The Club has scanned "
       "a 95% complete set of back issues "
       "and has prepared all 5000+ articles "
       "for download from this web site. "
       "Articles were scanned at 400 dpi, processed by custom software for "
       "contrast enhancement, "
       "then processed by Adobe Acrobat for character recognition. ")

    (p "The Club's back issues scanning project was made possible "
       "by a generous grant from benefactor "
       (a (href= "http://people.csail.mit.edu/tk/")
	  "Tom Knight")
       ".")

    (p "Hindawi has prepared its own archive of back issues, "
       "which may be accessed "
       (a (href= "http://www.hindawi.com/journals/psyche/contents.html")
	  "here") ".")

    (p "All articles published in "
       (i "Psyche")
       " prior to 1989 are in the public domain.")

    (hr)

    (p (a (hlink (path-to-article (get-article-info 81 3)) here)
          "History of the Cambridge Entomological Club [and "
	  (i "Psyche")
	  "]"))

    (p (a (href= "http://www.google.com/search?q=psyche+entomology+-consciousness&ie=UTF-8&oe=UTF-8")
          "References to " (i "Psyche")
	  " on the Internet")
       " (Google search)")

    (p (a (href= "http://psyche1.entclub.org/options/")
          "Memo on the future of " (i "Psyche")))

    (p (a (href= "https://github.com/jar398/psyche")
          "Source code")
       " for this web site")

    )))

(define (make-contact-page here)
  (apply-boilerplate here "Contact Psyche"
   (div
    (h3 "Contact " (i "Psyche"))
    (p (dl
	(dt (i "Psyche's") " new publisher as of July 2007:")
	(dd (a (href= "http://www.hindawi.com/")
	       "Hindawi Publishing Corporation"))))
    (p (dl (dt "Jonathan Rees, manager, " (i "Psyche") " Online web site "
	       "(sponsored by Cambridge Entomological Club)")))
    (p (dl
	(dt "Email address:")
	(dd (a (href= "mailto:psyche@entclub.org") "psyche@entclub.org"))))
    (p (dl
	(dt "Address for written correspondence:")
	(dd (i "Psyche: A Journal of Entomology") (br)
	    "Cambridge Entomological Club" (br)
	    "26 Oxford St." (br)
	    "Cambridge, MA 02138")))
    (p (dl
	(dt "Telephone with voice mail:")
	(dd "+1 617 209-4263"))))))


; Article has:
;  title, authors, citation (volume, issue(?), page number start/end, year),
;   abstract-is-on-line flag,
;   article-is-on-line flag

(define (make-main-page here)
  (make-articles-page "Featured articles"
		      (featured-articles)
		      (span)
		      "Psyche: A Journal of Entomology"
		      here))

(define (make-articles-page heading articles more title here)
  (apply-boilerplate here title
			  
   (span (h3 heading)
         (map (lambda (art)
		(if art
		    (p (div (class= "title")
			    (article-title-element art here))
		       (if (not (null? (article-authors art)))
			   (div (class= "authors")
				(maybe-with-period
				 (andify
				  (article-authors art))))
			   (div))

		       ;; One line with several things
		       (if (prepared? art)
			   (div (class= "accesslinks") ;make smaller
				(article-citation art)
				" | "
				(article-pdf-link art here)
				" | "
				(article-stable-link art here))
			   (div (class= "accesslinks") ;make smaller
				(article-citation art))))
		    (div)))
              articles)
	 more)))

(define (prepared? article)
  (let ((prepared (get-volume-scans (article-volume article))))
    (if prepared
	(member (article-id article) prepared)
	#f)))

(define (article-title-element art here)
  ;; title
  (if (prepared? art)
      (a (class= "title")
	 (hlink (path-to-article art) here)
	 (maybe-with-period (article-title art)))
      (maybe-with-period (article-title art))))

(define (article-title-string art)
  (remove-markup (article-title art)))

(define (remove-markup item)
  (cond ((string? item)
	 item)
	((list? item)
	 (apply string-append (map remove-markup item)))
	((element? item)
	 (remove-markup (element-content item)))
	((entity? item)
	 (string-append "&"
			(entity-name item)
			";"))
	(else (error "confusing markup" item))))

(define (maybe-with-period x)           ; => item
  (if (pair? x)
      (if (null? (cdr x))
          (cons (maybe-with-period (car x)) '())
          (cons (car x) (maybe-with-period (cdr x))))
      (if (and (string? x)
               (memq (string-ref x (- (string-length x) 1))
                     '(#\. #\? #\!)))
          x
          (list x "."))))

(define (article-pdf-link art here)
  (a (href= (article-pdf-url art here))
     ;; TBD: pdf file size
     "Full text (searchable PDF"
     (let ((size (table-ref pdf-file-sizes (article-stem art))))
       (if size
	   (list ", " size "K")
	   '()))
     ")"))

(define (article-pdf-url art here)
  (let* ((volnum (number->string (article-volume art)))
	 (path (cons volnum
		     (string-append (article-stem art)
				    ".pdf"))))
    (string-append articles-root
		   (path->string path))))

(define (article-stable-link art here)
  ;;(a (hlink (path-to-article art) here) "Permalink")
  (let* ((volnum (number->string (article-volume art)))
	 (path (cons volnum
		     (string-append (article-stem art)
				    ".html"))))
    (span (class= "contentlink")
	  (a (href= (string-append "http://psyche.entclub.org/"
				   (path->string path)))
	     "Permalink"))))

; The thing that comes after the ':' in a citation
(define (article-page-range art)
  (let ((pages (article-pages art)))
    (if pages
	(let ((p (car pages))
	      (q (cadr pages)))
	  (if (equal? p q)
	      (number->string p)
	      (string-append (number->string p)
			     "-"
			     (stringify q))))
	"supplemental")))

; We get this from utils.scm
;(define (stringify x)
;  (cond ((number? x) (number->string x))
;        ((symbol? x) (symbol->string x))
;        (else x)))

(define (article-citation art)
  (span (class= "citation")
	(i "Psyche ") (strong (article-volume art)) ":"
	(article-page-range art)
	", " (article-year art)))

(define-record-discloser :article
  (lambda (art)
    `(article ,(article-stem art))))

; Path ("a" "b" . "c") == "a/b/c"
; Path ("a" "b") == "a/b/"

(define (hlink where here)
  (let ((ref (reference where here)))
    (if ref
        (href= ref)
        (class= "selflink"))))

; Creates a relative reference to page 'where' that can be used on
; page 'here'

(define (reference where here)    ;Returns a string
  (if (and (pair? where)
           (pair? here)
           (equal? (car where) (car here)))
      (reference (cdr where) (cdr here))
      (if (equal? where here)
          #f
          (if (pair? here)
              (reference (cons ".." where) (cdr here))
              (path->string where)))))

(define (path->string x)
  (if (string? x)
      x
      (if (null? x)
          ""
          (string-append (car x) "/" (path->string (cdr x))))))

(define mood-color "#DCE6FF")

(define (apply-boilerplate here the-title main-stuff)
  (apply-meta-boilerplate here the-title '() main-stuff))

(define (apply-meta-boilerplate here the-title meta-elements main-stuff)
  (html
   (apply head
	  (title the-title)
	  (link (type= "text/css")
		(rel= "stylesheet")
		(hlink "style.css" here))
	  meta-elements)
   (body
    (table
     (width= "100%")
     (tr 
      (td (align= "left") (valign= "top") (width= 170) (height= 170)
          (img (src= (reference "seal150.png" here))
               (width= 150)
               (height= 150)
               (alt= "Cambridge Entomological Club, 1874")))
      (td (align= "center")
          (div (class= "journaltitle")
               "PSYCHE")
          (br)
          (div (class= "journalsubtitle")
               "A Journal of Entomology")
          (br)
          (div (class= "old")
               "founded in 1874 by the "
               (a (href= "http://entclub.org/")
                  "Cambridge Entomological Club")))
      (if #f
	  (td (align= "right") (valign= "top") (width= 170)
	      (div (class= "issn")
		   "Print ISSN 0033-2615"))
	  '()))
     (tr (td (valign= "top")            ;Left gutter
             (width= 170)
             (bgcolor= mood-color)	;pale blue; ->css

             (div (class= "controlbar")

                  (div (class= "control")
                       (form (action= "http://google.com/search")
                             (method= "GET")
                             "Quick search"
                             (input (type= "hidden")
                                    (name= "as_sitesearch")
                                    (value= "entclub.org"))
                             (input (type= "text")
                                    (name= "as_q")
                                    (size= 13))
                             (input (type= "submit")
                                    (name= "btnG")
                                    (value= "Go!"))))

                  (div (class= "control")
                       (a (hlink "master-toc.html" here)
                          "Contents"))
                       
                  (div (class= "control")
                       (a (hlink "index.html" here)
                          "Home"))
                       
                  (div (class= "control")
                       (a (hlink "about.html" here)
                          "About"))

		  (div (class= "control")
                       (a (href= "http://www.hindawi.com/journals/psyche/guidelines.html")
                          "Author information"))
                       
                  (div (class= "control")
                       (a (hlink "contact.html" here)
                          "Contact"))

;                  (div (class= "control")
;                       "Editors"
;                       (div (class="editors")
;                            (editor "Naomi E. Pierce"
;                                    "http://www.oeb.harvard.edu/faculty/pierce/people/Naomi/Naomi.html")
;                            (editor "Edward O. Wilson"
;                                    "http://www-museum.unl.edu/research/entomology/workers/EWilson.htm")))
;
;                  (div (class= "control")
;                       "Associate Editors"
;                       (div (class="editors")
;                            (editor "Stefan P. Cover"
;                                    "http://www.mcz.harvard.edu/Departments/Entomology/personnel.cfm")
;                            (editor "J. W. Stubblefield" #f)
;                            (editor "James F. Traniello"
;                                    "http://www.bu.edu/biology/Faculty_Staff/jft.html")
;                            ))
;
;                  (div (class= "control")
;                       (div (i "Psyche") " Online")
;                       (div (class="editors")
;                            (editor "Jonathan A. Rees" "http://mumble.net/~jar")))

		  (br)
		  (div (class= "issn")
		       "Print ISSN 0033-2615")

                  ))
         (td (valign= "top")
	     (table (frame= "border")
	      (tr
	       (td
		(strong
		 "This is the CEC archive of "
		 (i "Psyche") " through 2000. "
		 (i "Psyche") " is now published by "
		 (a (href= "http://www.hindawi.com/journals/psyche/contents.html")
		    "Hindawi Publishing")
		 "."))))
             main-stuff)
	 (if #f
	     (td (right-gutter here))
	     '())
	 ))
    (lambda (port)
      (display (statcounter) port))
    )))

; Obsolete
(define (right-gutter here)
  (div (valign= "top")			;Right gutter
       (width= 180)
       (bgcolor= mood-color)		;pale blue; ; ->css
       (div (class= "archivebar")
	    (map (lambda (vol+year)
		   (list (volume-stuff (car vol+year) here)
			 (br)))
		 (reverse (volume-year-alist))))
       (br)
       ))

(define (statcounter)
"<!-- Start of StatCounter Code -->
<script type='text/javascript' language='javascript'>
var sc_project=1929596; 
var sc_invisible=1; 
var sc_partition=17; 
var sc_security=\"42a09c97\"; 
</script>

<script type='text/javascript' language='javascript' src='http://www.statcounter.com/counter/counter.js'></script><noscript><a href='http://www.statcounter.com/' target='_blank'><img  src='http://c18.statcounter.com/counter.php?sc_project=1929596&amp;java=0&amp;security=42a09c97&amp;invisible=1' alt='web tracker' border='0'></a> </noscript>
<!-- End of StatCounter Code -->")


(define (editor name link)
  (p (class= "editor")
     (if link
	 (a (class="editor")
	    (href= link)
	    name)
	 name)))

(define (volume-year-alist)
  (map (lambda (volnum)
	 (list volnum
	       (let ((toc (get-volume-toc volnum)))
		 (if toc
		     (article-year (car toc))
		     (volume->year volnum)))))
       (all-volumes-with-scans)))

; 52-001  VN
; 77-385  H&W recruuitment trails
; 99-015  H&W termite mimic
; 99-003  Eisner
; 102-173  BH & SC
; 78-229  Levi
; 86-091  rhythmic

(define (featured-articles)
  (map (lambda (x) (apply get-article-info x))
       '((52 001)			;VN
	 (68 075)			;WB insect control
	 (77 385)			;H&W recruitment trails
	 (78 229)			;Levi
	 (81 3)				;history, again
	 (86 091)			;rhythmic
	 (99 003)			;Eisner
	 (99 015)			;H&W termite mimic
	 (102 173)			;BH & SC
	 )))

; Previous set
(define (featured-articles-1)
  (list (get-article-info 101 119)    ;Prodryas
	(get-article-info 101 203)    ;Barry Bolton
	(get-article-info 100 025)    ;H E Evans
	(get-article-info 100 163)    ;Say
	(get-article-info 100 185)    ;Richness
	(get-article-info 81 3)       ;History
	))

; Synthesizes article info if not found in TOC

(define (get-article-info volnum id)
  (or (maybe-article-info volnum id)
      (dummy-article-info volnum id)))

; Find a article record in TOC

(define (maybe-article-info volnum id)
  (let ((arts (get-volume-toc volnum)))
    (if arts
	(let loop ((arts arts))
	  (if (null? arts)
	      #f
	      (let ((article (car arts)))
		(if (equal? (article-id article) id)
		    article
		    (loop (cdr arts))))))
	#f)))

; Generate a dummy article record for an article that has been
; prepared but for which there is no curated table of contents entry.
; id comes from ... where?

(define (dummy-article-info volnum id)
  (let ((prepared (or (get-volume-scans volnum) '())))
    (let ((foo (member id prepared)))	;foo = (31 35 49 55 ...) numbers/symbols
      (if foo
	  (cond ((integer? id)
		 ;; (make-article stem title authors volume year pages issue id comments)
		 (make-article (create-stem volnum id)
			       (string-append
				"Article beginning on page "
				(number->string id))
			       '()	;no authors
			       volnum
			       (volume->year volnum)
			       (cons id (if (or (null? (cdr foo))
						(not (integer? (cadr foo))))
					    (list '?)
					    (list (- (cadr foo) 1) '?)))
			       #f	;issue is unknown
			       id
			       '()))
		(else #f))
	  #f))))

; First year covered by the given volume

(define (volume->year volnum)
  (cond ((= volnum 103) 2000)
	((< volnum 10)
	 (let ((year (+ (* volnum 3) 1871)))
	   (if (> volnum 4)
	       (+ year 2)
	       year)))
	(else (+ volnum (- 1910 17)))))

; E.g. "1897-1899"

(define (volume->years volnum)
  (let ((year (volume->year volnum)))
    (if (< volnum 10)
	(string-append (number->string year)
		       "-"
		       (number->string (+ year 2)))
	(number->string year))))

;-----------------------------------------------------------------------------
; Tables of contents processing

(define table-of-contents (make-vector 200 #f))

; Get list of TOC entries for a given volume

(define (get-volume-toc volnum)
  (vector-ref table-of-contents volnum))

; Declare a bunch of TOC entries

(define (define-volume-toc volnum article-list)
  (vector-set! table-of-contents volnum article-list))

; Volume numbers of all volumes for which there is some
; table-of-contents information.

(define (all-volumes-with-tocs)
  (do ((v (- (vector-length table-of-contents) 1)
	  (- v 1))
       (vols '()
	     (let ((art-list (vector-ref table-of-contents v)))
	       (if art-list
		   (cons v vols)
		   vols))))
      ((< v 0) vols)))

; Returns HTML (as list, element, string, or SQUID)

(define (andify authors)
  (case (length authors)
    ((0) #f)
    ((1) (car authors))
    ((2) (list (car authors) " and " (cadr authors)))
    (else
     (append (map (lambda (author next-author)
		    (list author ", "))
		  authors
		  (cdr authors))
	     (list "and "
		   (last authors))))))

; Calls (define-volume-toc volnum article-list) for each volume.

(define (read-prepared-toc-file infile)
  (call-with-input-file infile
    (lambda (in)
      (display "Reading ") (display infile) (newline)
      (let vloop ((volume #f))

	(define (finish-volume articles)
	  (if (not (null? articles))
	      (define-volume-toc
		volume
		(let ((taps (list-sort article< articles)))
		  (map (lambda (t-a-p next)
			 (apply (lambda (stem title authors page qage issue comments)
				  (make-article stem
						title
						(reverse authors)
						volume
						(volume->year volume)
						(if (integer? page)
						    (cons page
							  (if qage
							      (list qage)
							      (if next
								  (let ((qage (cadddr next)))
								    (if (number? qage)
									(list (- qage 1) '?)
									'(?)))
								  '(?))))
						    #f)
						issue
						(id-from-stem stem)
						comments))
				t-a-p))
		       taps
		       (append (cdr taps) (list #f)))))))
   
	;; Compare the stems e.g.  "17-053", "17-214"
	(define (article< tap1 tap2)
	  (string<? (car tap1) (car tap2)))

	;; Loop for accumulating articles...
	(let aloop ((issue #f) (articles '()))

	(let loop ((stem #f)
		   (title #f)
		   (authors '())
		   (page #f)
		   (qage #f)    ;ending page, if known
		   (comments '()))

	  (define (finish-article) ;returns list of articles
	    (if (or stem title page)
		(cons (list stem title authors page qage issue comments)
		      articles)
		articles))

	  (let ((line (read-line-foo in)))
	    (cond ((eof-object? line)
		   (finish-volume (finish-article)))
		  ((< (string-length line) 2)
		   ;; Blank lines separate articles
		   (aloop issue (finish-article)))
		  (else
		   ;; New article
		   (let ((c (string-ref line 0))
			 (arg (substring line 2 (string-length line))))
		     (case c
		       ((#\V)
			(let ((new-volume (or (string->number arg) arg)))
			  (if (equal? volume new-volume)
			      (loop stem title authors page qage comments)
			      (begin (finish-volume (finish-article))
				     (vloop new-volume)))))
		       ((#\I)
			;; Should barf if we have any info saved up
			(aloop arg (finish-article)))
		       ;; 'Stem' e.g. 46-072
		       ((#\S) (loop arg #f '() #f #f comments))
		       ((#\T) (loop stem (allow-markup arg)
				    authors page qage comments))
		       ((#\A) (loop stem title
				    (cons (allow-markup arg) authors)
				    page qage comments))
		       ((#\P) (loop stem title authors
				    (or (string->number arg) arg)
				    qage comments))
		       ((#\Q) (loop stem title authors
				    page
				    (or (string->number arg) arg)
				    comments))
		       ((#\#) (loop stem title authors page qage
				    (cons line comments)))
		       (else (display volume)
			     (display ":")
			     (display page)
			     (display ": ")
			     (display "Unrecognized directive in TOC file: ")
			     (display line)
			     (newline)
			     (loop stem title authors page qage comments)))))))))))))

(define (id-from-stem stem)
  (let ((foo (member #\- (string->list stem))))
    (if foo
	(let ((z (list->string (cdr foo))))
	  (or (string->number z)
	      (string->symbol z)))
	(error "stem has no -" stem))))

(define (write-prepared-toc-file outfile)
  (call-with-output-file outfile
    (lambda (out)
      (define tab (integer->char (- (char->integer #\space) 23)))
      (define (directive char thing)
	(display char out)
	(display tab out)
	;; If thing is XML, write it that way
	(write-item thing out)
	(newline out))
      (define (write-article a)
	;; Write comments
	;; Write [# # ...] T [A A ...] P [Q]
	(for-each (lambda (comment) (display comment out) (newline out))
		  (article-comments a))
	(directive #\T (article-title a))     ;OOPS - need to write-xml.
	(for-each (lambda (author) (directive #\A author))
		  (article-authors a))
	(let ((pq (article-pages a)))
	  (directive #\P (car pq))
	  (if (and (number? (cadr pq))
		   (null? (cddr pq)))
	      (directive #\Q (cadr pq))))
	(newline out))
      (for-each (lambda (v)
		  (if (vector-ref table-of-contents v)
		      (begin
			(directive #\V v)
			(let loop ((i #f)
				   (as (vector-ref table-of-contents v)))
			  (if (null? as)
			      'done
			      (let ((a (car as)))
				(if (not (eq? (article-issue a) i))
				    (begin (directive #\I (article-issue a))
					   (newline out)))
				(write-article a)
				(loop (article-issue a) (cdr as))))))))
		(iota (vector-length table-of-contents))))))

(define (allow-markup arg)
  (if (string? arg)
      (let ((exploded (string->list arg)))
	(if (or (memq #\< exploded)
		(memq #\& exploded))
	    (read-item-from-string arg)
	    arg))
      arg))

(define (blank-line? line)
  (= (string-length line) 0))

; Adapted from scheme48/scheme/env/command.scm
; read-line is defined in utils.scm - we could probably use that instead
(define (read-line-foo port)
  (let loop ((l '()))
    (let ((c (read-char port)))
      (cond ((eof-object? c)
	     c)
	    ((char=? c #\newline)
	     (list->string (reverse l)))
	    (else
	     (loop (cons c l)))))))

; (process-prepared-toc-file "prepared-toc.txt" "prepared-toc.tmp")


(define (read-item-from-string string)
  (let ((port (make-string-input-port string)))
    (let loop ((items '()))
      (let ((item (read-item port)))
	(if (eof-object? item)
	    (if (and (pair? items)
		     (null? (cdr items)))
		(car items)
		(reverse items))
	    (loop (cons item items)))))))

; i = starting index, j = index of first thing not to be taken
; We allow the list to be too short

(define (sublist l i j)
  (if (null? l) l
      (if (> i 0)
	  (sublist (cdr l) (- i 1) (- j 1))
	  (if (> j 0)
	      (cons (car l)
		    (sublist (cdr l) 0 (- j 1)))
	      '()))))

(define (iota n) (iota1 0 n))		;Geometry/matrix.scm
(define (iota1 from upto)
  (if (>= from upto)
      '()
      (cons from (iota1 (+ from 1) upto))))


(define (last l)
  (if (null? (cdr l)) (car l) (last (cdr l))))

(define (filter pred l)
  (cond ((null? l) l)
	((pred (car l)) (cons (car l) (filter pred (cdr l))))
	(else (filter pred (cdr l)))))

(define (any pred l)
  (if (null? l)
      #f
      (if (pred (car l))
	  #t
	  (any pred (cdr l)))))

;-----------------------------------------------------------------------------
; Get list of prepared articles for a given volume -
;  i.e. the .pdf files that exist

(define (get-volume-scans volnum)
  (vector-ref table-of-scans volnum))

; Declares a bunch of prepared articles

(define (declare-prepared-articles-list n id-list)
  (vector-set!
   table-of-scans
   n
   (if (null? id-list)
       #f
       (list-sort (lambda (i j)
		    (if (number? i)
			(if (number? j)
			    (< i j)
			    #t)
			(string<? (stringify i)
				  (stringify j))))
		  id-list))))

; Returns a list of volume numbers, those that have at least one
; prepared article

(define (all-volumes-with-scans)
  (do ((i (- (vector-length table-of-scans) 1)
	  (- i 1))
       (vols '()
	     (let ((art-list (vector-ref table-of-scans i)))
	       (if art-list
		   (cons i vols)
		   vols))))
      ((< i 0) vols)))

(define (path->filename build-dir path)
  (string-append build-dir
		 "/"
		 (path->string path)))


; Hmm

(define (invert-name name)
  (call-with-values (lambda () (split-first-and-last name))
    (lambda (first last)
      (string-append last ", " first))))

; alternate strategy:
;  scan from end skipping short parts that end with . or those following ,
;  scan back over all non-short-. parts
;   but not the first
; Foo Bar Baz Jr.
; Foo Bar Baz, III

(define (split-first-and-last name)

  (define (jr? part)
    ;; what about III ?
    (and (< (length part) 4)
	 (eq? (car (reverse part)) #\.)))

  (define (get-van jrparts parts)
    (if (and (not (null? parts))
	     (not (null? (cdr parts)))
	     (not (null? (cddr parts)))
	     (let ((candidate (cadr parts)))
	       (and (< (length candidate) 4)
		    (char-lower-case? (car candidate)))))
	(finally (cddr parts)
		 (cons (cadr parts)
		       (cons (car parts) jrparts)))
	(finally (cdr parts)
		 (cons (car parts) jrparts))))

  (define (finally revfirstparts lastparts)
    (values (list->string (unsplit (reverse revfirstparts) #\space))
	    (list->string (unsplit lastparts #\space))))

  (let* ((revparts (reverse (split (string->list name) #\space)))
	 (revparts (if (null? (car revparts))
		       (cdr revparts)
		       revparts)))
    (if (jr? (car revparts))
	(get-van (list (car revparts))
		 (cons (let ((revlast (reverse (cadr revparts))))
			 (if (eq? (car revlast) #\,)
			     (reverse (cdr revlast))
			     revlast))
		       (cddr revparts)))
	(get-van '() revparts))))


(define (split l c)
  (call-with-values
      (lambda ()
	(let loop ((l l))
	  (cond ((null? l)
		 (values '() '()))
		((eq? (car l) c)
		 (call-with-values (lambda () (loop (cdr l)))
		   (lambda (cs parts)
		     (values '() (cons cs parts)))))
		(else
		 (call-with-values (lambda () (loop (cdr l)))
		   (lambda (cs parts)
		     (values (cons (car l) cs) parts)))))))
    cons))

(define (unsplit l c)
  (cdr (apply append (map (lambda (clist)
			    (cons #\space clist))
			  l))))

;-----
; Search

(define (for-each-article proc)
  (do ((i 0 (+ i 1)))
      ((> i 103) 'done)
    (let ((arts (get-volume-toc i)))
      (if arts
	  (for-each proc arts)))))

(define (show-author-and-title art)
  (if (pair? (article-authors art))
      (begin (display (remove-markup (car (article-authors art))))
	     (display ". ")))
  (display (remove-markup (article-title art)))
  (display ".")
  (newline))

(define (find-by-author lastname)
  (for-each-article
   (lambda (art)
     (for-each (lambda (name)
		 (call-with-values (lambda ()
				     (split-first-and-last (remove-markup name)))
		   (lambda (first last)
		     (if (equal? last lastname)
			 (show-author-and-title art)))))
	       (article-authors art)))))

; ls -s -k ?? ??? | grep pdf >/tmp/ls-s-k.out

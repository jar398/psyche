; TBD: File download sizes

; To generate HTML from this file, start Scheme 48 (from s48.org) and
; issue the commands ",config ... (doit ...)" below, replacing
; <target-directory> with a directory of your choice that is not a 
; subdirectory of this one.
;
; Or use the Makefile.

(define articles-root "http://psyche.entclub.org/pdf/")
;(define text-files-root "/Users/jar/Scratch/Psyche/text/")
(define text-files-root "text/")    ;; or ../text/


"
,bench
,config ,load web/web-config.scm
,open define-record-types sorting c-system-function tables
,open extended-ports signals posix-files
,open html xml web-utils
,load pdf-file-sizes.sch bhl/first-pages.sch build-web-site.sch
,load articles.sch journal-meta.sch dois.sch 
(doit <toc> <outdir>)  ;toc/processed-toc.txt build
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
  (message "index.html")
  (write-page build-dir
	      "index.html"
	      (make-main-page "index.html"))
  (message "master-toc.html")
  (write-page build-dir
	      "master-toc.html"
	      (make-master-toc-page "master-toc.html"))
  (message "about.html")
  (write-page build-dir
	      "about.html"
	      (make-about-page "about.html"))
  (message "contact.html")
  (write-page build-dir
	      "contact.html"
	      (make-contact-page "contact.html")))

(define (message x) (display x) (newline))

(define (do-slow-part toc-file build-dir)
  (read-prepared-toc-file toc-file)
  (do-slow-part-1 build-dir))

(define (do-slow-part-1 build-dir)
  (system (string-append "mkdir -p "
			 (path->filename build-dir "metadata")))
  ;; (write-articles-metadata (all-volumes-with-tocs) build-dir)  -- too big, now split among vols
  (for-each (lambda (volnum)
	      (process-one-volume volnum build-dir))
	    (cdr (iota 104))
	    )
  (newline))

(define-record-type article :article
  (make-article stem title authors volume year pages issue id doi comments)
  (stem article-stem)          ;E.g. "30-013" for PDF file, if any
  (title article-title)
  (authors article-authors)    ;list of authors
  (volume article-volume)
  (year article-year)
  (pages article-pages set-article-pages!)
  (id article-id)		;sequential within volume
  (issue article-issue)
  (doi article-doi)
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
		      (if (and article (article-stem article) (prepared? article))
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
  (if (= (article-volume a1) (article-volume a2))
      (if (and (string? (article-stem a1))
               (string? (article-stem a2)))
          (string<? (article-stem a1)
                    (article-stem a2))
          (< (car (article-pages a1))
             (car (article-pages a2))))
      (< (article-volume a1) (article-volume a2))))

(define (make-volume-toc-page volnum articles build-dir here)
  (let* ((prepared (get-volume-scans volnum)) ;List of stems "30-013"
	 (aux (if prepared
		  (filter (lambda (x) (not (integer? x)))
			  prepared)
		  '())))
    (make-articles-page (span "Volume " volnum
			      " (" (volume->years volnum) ")")
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
	  (p (a (rlink (path-to-metadata volnum) here)
		"Table of contents metadata (XML)")))))

; Not sure where to put the .xml file: in the volume directory
; (e.g. 10/metadata.xml), or in a metadata directory (metadata/10.xml)?

(define (path-to-metadata volnum)
  (cons "metadata" (string-append (number->string volnum) ".xml")))

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

; Returns a URI reference

(define (path-to-landing-page article)
  (if (article-stem article)
      (path-in-volume (article-volume article)
                      (string-append (article-stem article)
                                     ".html"))
      #f))

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
  (let ((path (path-to-landing-page article)))
    (if path
        (write-page build-dir
                    path
                    (make-article-landing-page path article)))))

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

(define (make-article-landing-page here article)
  (apply-meta-boilerplate
     here
     (string-append "Psyche "
		    (number->string (article-volume article))
		    ":"
		    (article-page-range article))
     (make-google-scholar-stuff here article)
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
	  (article-reference article)))

      (p (let ((doi-url (article-doi-url article)))
	   (if doi-url
	       (list (span (class= "stableurl")
                           "This article at Hindawi Publishing: "
                           (a (href= doi-url) doi-url))
                     (br))
	       '()))
         (let ((bhl-url (article-bhl-url article)))
	   (if bhl-url
	       (list (span (class= "stableurl")
                           "This article at Biodiversity Heritage Library: "
                           (a (href= bhl-url) bhl-url))
                     (br))
	       '()))
         (span (class= "contentlink")
	       (let ((url (article-cec-pdf-url article here)))
                 (if url
                     (list "CEC's scan of this article: "
                           (a (href= url) url)
                           (let ((size (table-ref pdf-file-sizes (article-stem article))))
                             (if size
                                 (list ", " size "K")
                                 '()))
                           (br))
                     '())))
	 (let ((cec-url (string-append "http://psyche.entclub.org/"
					 (path->string here))))
	   (list (span (class= "stableurl")
                       "This landing page: "
                       (a (href= cec-url) cec-url))
                 (br)))

	 (make-article-abstract article)

	 (hr)
	 (let ((volnum (article-volume article)))
	   (span (a (rlink (path-to-toc volnum) here)
		    "Volume " volnum " table of contents")))
	 ))))

(define (make-google-scholar-stuff here article)
  (let ((title-string (article-title-string article))
	(inverted-authors (map (lambda (name)
				 (invert-name (remove-markup name)))
			       (article-authors article))))
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
                  '())))                ;?
          (let ((pages (article-pages article)))
            (if pages
                (list (meta (name= "citation_firstpage")
                            (content= (car pages)))
                      (if (integer? (cadr pages))
                          (meta (name= "citation_lastpage")
                                (content= (cadr pages)))
                          '()))
                '()))
	   
          (let ((cec-url (article-cec-pdf-url article here)))
            (if cec-url
                (meta (name= "citation_pdf_url")
                      (content= cec-url))))
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
               inverted-authors))))

(define doi-prefix "https://doi.org/")

(define (article-doi-url article)
  (if (article-doi article)
      (string-append doi-prefix (article-doi article))
      (if (article-pages article)
          (let* ((key (vpq->key (article-volume article)
                                (car (article-pages article))
                                (cadr (article-pages article))))
                 (doi-list (table-ref dois key)))
            (if (pair? doi-list)
                (if (null? (cdr doi-list))
                    (string-append doi-prefix (car doi-list))
                    #f)		  ;Ambiguous... normal
                ;; TBD: filter out "Exchange Column"
                #f))
          #f)))

(define first-pages-table (make-string-table))
(for-each (lambda (first-page)
            (table-set! first-pages-table (car first-page) (cadr first-page)))
          first-pages)

(define (article-bhl-url article)
  (let ((pageid (table-ref first-pages-table (bhl-key article))))
    (if pageid
        (string-append "https://www.biodiversitylibrary.org/page/"
                       pageid)
        #f)))

(define (bhl-key article)
  (let ((pages (article-pages article)))
    (if pages
        (string-append (number->string (article-volume article))
                       "-"
                       (number->string (car pages))
                       "-"
                       (if (integer? (cadr pages))
                           (number->string (cadr pages))
                           (number->string (car pages))))
        "no pages")))

(define (make-article-abstract article)
  (if (article-stem article)
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
                 (p (i "The following unprocessed text is extracted automatically "
                       "from the PDF file, and "
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
                   '())))))

;; path may be #f

(define (write-page build-dir path item)
  (if path
      (call-with-output-file (path->filename build-dir path)
        (lambda (port)
          (write-item item port)))))

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
	(a (rlink (path-to-toc volnum)
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

                      (p (a (rlink (path-to-landing-page (get-article-info 81 3)) here)
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
                          (dt "As of 2007, " (i "Psyche") " is published by "
                              (a (href= "http://www.hindawi.com/")
                                 "Hindawi Publishing Corporation")
                              ". All correspondence regarding current publication should be addressed to Hindawi.")))
                      (p (dl (dt "This archive of " (i "Psyche") " pre 2007 is provided by "
                                 " the Cambridge Entomological Club"
                                 " and is managed by Jonathan A. Rees. "
                                 "Email: "
                                 (a (href= "mailto:psyche@entclub.org") "psyche@entclub.org"))))
                      (p (dl
                          (dt "Address for written correspondence:")
                          (dd "Cambridge Entomological Club" (br)
                              "26 Oxford St." (br)
                              "Cambridge, MA 02138"))))))

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

                                        ; Make page for a list of articles (usually a table of contents, but
                                        ; not always)

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

                                         (let ((doi-url (article-doi-url art))
                                               (bhl-url (article-bhl-url art))
                                               (cec-land (path-to-landing-page art))
                                               (cec-pdf (article-cec-pdf-url art here)))
                                           ;; One line with several things
                                           (if (not (or doi-url bhl-url cec-land cec-pdf))
                                               (begin
                                                 (write `(missing article ,(article-title art)))
                                                 (newline)))
                                           (div (class= "accesslinks") ;make smaller
                                                (article-reference art) ;Psyche n:n-n,yyyy
                                                (if doi-url
                                                    (list " | "
                                                          (a (href= doi-url) "At Hindawi"))
                                                    '())
                                                (if bhl-url
                                                    (list " | "
                                                          (a (href= bhl-url) "At BHL"))
                                                    '())
                                                (let ()
                                                  (if (or cec-land cec-pdf)
                                                      (list " | "
                                                            (if cec-land
                                                                (a (rlink cec-land here) "At CEC")
                                                                '())
                                                            (if (and cec-land cec-pdf)
                                                                " "
                                                                '())
                                                            (if cec-pdf
                                                                (a (href= cec-pdf) " (PDF)")
                                                                '()))
                                                      '())))))
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
  (strong (maybe-with-period (article-title art))))

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
  (cond ((pair? x)
         (if (null? (cdr x))
             (cons (maybe-with-period (car x)) '())
             (cons (car x) (maybe-with-period (cdr x)))))
        ((and (string? x)
              (memq (string-ref x (- (string-length x) 1))
                    '(#\. #\? #\!)))
         x)
        ((not x) "")
        (else (list x "."))))

; Relative URL for CEC PDF.  #f if none.

(define (article-cec-pdf-url art here)
  (if (article-stem art)
      (let* ((volnum (number->string (article-volume art)))
             (path (cons volnum
                         (string-append (article-stem art)
                                        ".pdf"))))
        (string-append articles-root
                       (path->string path)))
      #f))

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

(define (article-reference art)
  (span (class= "citation")
	(i "Psyche ") (strong (article-volume art))
        (if (and (article-issue art)
                 (> (string-length (article-issue art)) 0))
            (list "(" (article-issue art) ")"))
        ":"
	(article-page-range art)
	", " (article-year art)))

(define-record-discloser :article
  (lambda (art)
    `(article ,(article-stem art))))

; URI reference to target page relative to here.
; Path ("a" "b" . "c") == "a/b/c"
; Path ("a" "b") == "a/b/"

(define (rlink where here)
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
	  (hlink (type= "text/css")
                 (rel= "stylesheet")
                 (rlink "style.css" here))
          (meta (charset= "utf-8"))
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
                       (a (rlink "master-toc.html" here)
                          "Contents"))
                       
                  (div (class= "control")
                       (a (rlink "index.html" here)
                          "Home"))
                       
                  (div (class= "control")
                       (a (rlink "about.html" here)
                          "About"))

		  (div (class= "control")
                       (a (href= "http://www.hindawi.com/journals/psyche/guidelines.html")
                          "Author information"))
                       
                  (div (class= "control")
                       (a (rlink "contact.html" here)
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
                               #f    ;DOI
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
      (let vloop ((volume #f))          ;Volume loop
   
	;; Compare the stems e.g.  "17-053", "17-214"
	(define (article< tap1 tap2)
	  (string<? (car tap1) (car tap2)))

	;; Loop for accumulating articles...
	(let aloop ((issue #f) (articles '())) ;Article loop

          ;; Loop for properties of a single article...
          (let loop ((stem #f)
                     (title #f)
                     (authors '())
                     (year #f)
                     (page #f)
                     (qage #f)          ;ending page, if known
                     (issue #f)
                     (doi #f)
                     (comments '()))

            (define (finish-article)   ;returns reversed list of articles
              (if (or stem title page)
                  (cons (list stem title authors year page qage issue doi comments)
                        articles)
                  articles))

            (let ((line (read-line-foo in)))
              (cond ((eof-object? line)
                     (finish-volume volume (finish-article)))
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
                                (loop stem title authors year page qage issue doi comments)
                                (begin (finish-volume volume (finish-article))
                                       (vloop new-volume)))))
                         ;; 'Stem' e.g. 46-072
                         ((#\S) (loop arg
                                      title authors year page qage issue doi comments))
                         ((#\T) (loop stem
                                      (if arg (allow-markup arg) "No title")
                                      authors year page qage issue doi comments))
                         ((#\A) (loop stem title
                                      (if (and (> (string-length arg) 0)
                                               (not (string=? arg "None")))
                                          (cons (allow-markup arg) authors)
                                          authors)
                                      year page qage issue doi comments))
                         ((#\Y) (loop stem title authors
                                      (or (string->number arg) arg)
                                      page qage issue doi comments))
                         ((#\P) (loop stem title authors year
                                      (or (string->number arg) arg)
                                      qage issue doi comments))
                         ((#\Q #\R) (loop stem title authors year page
                                          (or (string->number arg) arg)
                                          issue doi comments))
                         ((#\I) (loop stem title authors year page qage
                                      arg
                                      doi comments))
                         ((#\D) (loop stem title authors year page qage issue
                                      arg
                                      comments))
                         ((#\#) (loop stem title authors year page qage issue doi
                                      (cons line comments)))
                         (else (display volume)
                               (display ":")
                               (display page)
                               (display ": ")
                               (display "Unrecognized directive in TOC file: ")
                               (display line)
                               (newline)
                               (loop stem title authors year page qage issue doi comments)))))))))))))

;; articles is a list of (stem title authors year page qage issue doi comments)

(define (finish-volume volume articles)
  (if (not (null? articles))
      (let* ((articles (reverse articles)))
        (define-volume-toc
          volume
          (let ((taps articles)) ;was (list-sort article< articles), before processed-toc
            (map (lambda (t-a-p next)
                   (apply (lambda (stem title authors year page qage issue doi comments)
                            (make-article stem
                                          title
                                          (reverse authors)
                                          volume
                                          (or year (volume->year volume))
                                          (if (integer? page)
                                              (cons page
                                                    (if qage
                                                        (list qage)
                                                        (if next
                                                            (let ((qage (list-ref next 4)))
                                                              (if (number? qage)
                                                                  (list (- qage 1) '?)
                                                                  '(?)))
                                                            '(?))))
                                              #f)
                                          issue
                                          (id-from-stem stem page)
                                          doi
                                          comments))
                          t-a-p))
                 taps
                 (append (cdr taps) (list #f))))))))

; Unique id for article within volume ... 
;  hmm, there are ambiguities when muliple articles on a page

(define (id-from-stem stem page)
  (if stem
      (let ((foo (member #\- (string->list stem))))
        (if foo
            (let ((z (list->string (cdr foo))))
              (or (string->number z)
                  (string->symbol z)))
            (error "stem has no -" stem)))
      page))


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
  (let ((stuff (apply append (map (lambda (clist)
                                    (cons #\space clist))
                                  l))))
    (if (null? stuff)
        stuff
        (cdr stuff))))

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

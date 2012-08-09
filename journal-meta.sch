; ,open utils  - for string-position
; ,open extended-ports  - for make-string-input-port
; ,open signals

; Generate metadata (originally for Google Scholar, now for Rod Page)

(define $articles (element-constructor 'articles))

(define $article (element-constructor 'article))
(define $front (element-constructor 'front))
(define $journal-meta (element-constructor 'journal-meta))
(define $journal-title (element-constructor 'journal-title))
(define $abbrev-journal-title (element-constructor 'abbrev-journal-title))
(define $issn (element-constructor 'issn))
(define $publisher (element-constructor 'publisher))
(define $publisher-name (element-constructor 'publisher-name))
(define $article-meta (element-constructor 'article-meta))
(define $title-group (element-constructor 'title-group))
(define $article-title (element-constructor 'article-title))
(define $trans-title (element-constructor 'trans-title))
(define $contrib-group (element-constructor 'contrib-group))
(define $contrib (element-constructor 'contrib))
(define $name (element-constructor 'name))
(define $surname (element-constructor 'surname))
(define $given-names (element-constructor 'given-names))
(define $suffix (element-constructor 'suffix))
(define $pub-date (element-constructor 'pub-date))
(define $year (element-constructor 'year))
(define $volume (element-constructor 'volume))
(define $issue (element-constructor 'issue))
(define $fpage (element-constructor 'fpage))
(define $lpage (element-constructor 'lpage))
(define $self-uri (element-constructor 'self-uri))

; article-id  -- no DOI's yet.
; day month

; Attributes
(define $contrib-type= (attribute-constructor 'contrib-type))
(define $pub-type=     (attribute-constructor 'pub-type))
(define $xlink:href=  (attribute-constructor 'xlink:href))

(define (write-articles-metadata build-dir)
  (call-with-output-file
      (path->filename build-dir "journal_meta.xml")
    (lambda (port)
      (let ((journal-metadata (journal-metadata)))
	(display "<?xml version='1.0' encoding='UTF-8'?>" port)
	(xml-end-of-line port)
	(display "<articles>" port)
	(xml-end-of-line port)
	(for-each (lambda (volnum)
		    (for-each (lambda (article)
				(if (pair? (article-authors article))
				    (begin (write-item 
					    (article-metadata article journal-metadata)
					    port)
					   (xml-end-of-line port)
					   (xml-end-of-line port))))
			      (or (get-volume-toc volnum) '()))
		    (xml-end-of-line port))
		  (all-volumes-with-tocs))
	(display "</articles>" port)
	(newline port)))))

(define (write-volume-metadata volnum outfile)
  (call-with-output-file outfile
    (lambda (port)
      (let ((journal-metadata (journal-metadata)))
	(display "<?xml version='1.0' encoding='UTF-8'?>" port)
	(xml-end-of-line port)
	(display "<articles>" port)
	(xml-end-of-line port)
	(for-each (lambda (article)
		    (if (pair? (article-authors article))
			(begin (write-item 
				(article-metadata article journal-metadata)
				port)
			       (xml-end-of-line port)
			       (xml-end-of-line port))))
		  (or (get-volume-toc volnum) '()))
	(display "</articles>" port)
	(newline port)))))

(define (journal-metadata)
  ($journal-meta
   ($journal-title "Psyche: A Journal of Entomology")
   ($abbrev-journal-title "Psyche")
   ($issn "0033-2615")
   ($publisher
    ($publisher-name "Cambridge Entomological Club"))))

(define (article-metadata article journal-metadata)
  ($article
   ($front
    journal-metadata
    ($article-meta
     ($title-group
      ($article-title (convert-markup (article-title article))))
     ($contrib-group
      (map (lambda (auth)
	     (call-with-values
		 (lambda () (parse-author-name auth))
		 (lambda (surname given-names suffix)
		   (if (not given-names)
		       (warn "No given names for this author"
			     auth
			     article))
		   ($contrib ($contrib-type= "author")
			     ($name
			      ($surname surname)
			      (if given-names
				  ($given-names given-names)
				  '())
			      (if suffix
				  ($suffix suffix)
				  '())
			      )))))
	   (article-authors article)))
     ($pub-date ($pub-type= "pub")
		($year (article-year article)))
     ($volume (article-volume article))
     ($issue (article-issue article))
     (if (article-pages article)
	 (list ($fpage (car (article-pages article)))
	       (let ((last (cadr (article-pages article))))
		 (if (integer? last)
		     ($lpage last)
		     '())))
	 '())
     ($self-uri ($xlink:href= (string-append "http://psyche.entclub.org/"
					     (path->string (path-to-article article)))))))))

(define (parse-author-name auth)
  (let ((auth (explode-item auth)))
    (call-with-values (lambda () (split-from-end auth #\,))
      (lambda (first+last suffix)
	(call-with-values (lambda () (split-from-end first+last #\space))
	  (lambda (first last)
	    (values first
		    last
		    (if (and (pair? suffix)
			     (eq? (car suffix) #\space))
			(cdr suffix)
			suffix))))))))

; Author name is either a string or a list of XML items - strings,
; entities, and elements.
; To do parsing we need to explode the strings into their constituent
; characters.

(define (explode-item item)
  (cond ((string? item)
	 (string->list item))
	((list? item)
	 (apply append
		(map (lambda (item)
		       (cond ((string? item)
			      (string->list item))
			     ((list? item) item)
			     (else (list item))))
		     item)))
	(else (list item))))

(define (split-from-end z separator)
  (let loop ((y '())
	     (z (reverse z)))
    (if (null? z)
	(values y #f)
	(if (eq? (car z) separator)
	    (values y
		    (reverse (cdr z)))
	    (loop (cons (car z) y)
		  (cdr z))))))

; Strip tags but not entities

(define (convert-markup item)
  (cond ((list? item)
	 (map convert-markup item))
	((and (element? item)
	      (eq? (element-type item) 'i))
	 (make-element 'italic
		       (element-attributes item)
		       (element-content item)))
	((procedure? item)
	 (let ((port (make-string-output-port)))
	   (item port)
	   (let ((s (string-output-port-output port)))
	     (list->string
	      (let gobble1 ((z (string->list s)))
		(if (null? z)
		    z
		    (if (char=? (car z) #\<)
			(let gobble2 ((z (cdr z)))
			  (if (null? z)
			      z
			      (if (char=? (car z) #\>)
				  (gobble1 (cdr z))
				  (gobble2 (cdr z)))))
			(cons (car z)
			      (gobble1 (cdr z))))))))))
	;; TBD: introduce entities where needed: < > &
	(else item)))

(define (allow-entities arg)
  (if (string? arg)
      (let ((exploded (string->list arg)))
	(if (memq #\& exploded)
	    (lambda (port) (display arg port))
	    arg))
      arg))

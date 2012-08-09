; Compare information about the prepared article files
; with the curated tables of contents.

; Unfixable:  (missing-scans 27 144)

; Splits, fixed: (missing-scans 53 21)
;		 (missing-scans 56 184)
;		 (missing-scans 68 145)


; ,load page-counts.sch

(define page-counts-by-volume (make-vector 200 '()))

(for-each (lambda (vac)
	    (vector-set! page-counts-by-volume
			 (car vac)
			 (cons vac
			       (vector-ref page-counts-by-volume (car vac)))))
	  page-counts)

(define (reconcile)
  (read-prepared-toc-file "toc.txt")
  (compare-prepared-to-toc)
  (compare-toc-to-prepared))

; For each volume in the prepared TOC
;  For each article
;   See whether there's a prepared article starting on that page
;    If not, make a note of it
;   If there is, compare article Q to Q value in page-range
;   Complain if different
;   If no Q value in TOC, acceptable Q's are nextP-1
;   and nextP-2, if there is a nextP  (guessing is testified by 
;   (P Q ?) in article record)

(define (compare-toc-to-prepared)
  (for-each (lambda (articles)
	      (if articles
		  (for-each (lambda (article)
			      ;; Ignore indexes, etc.
			      (if (article-authors article)
				  (let* ((volnum (article-volume article))
					 (artnum (car (article-pages article)))
					 (count
					  (get-page-count volnum artnum)))
				    (cond (count
					   ;; (check-page-count article count)
					   )
					  (else
					   (write
					    `(missing-scans ,volnum ,artnum))
					   (newline))))))
			    articles)))
	    (vector->list table-of-contents)))

(define (compare-prepared-to-toc)
  ; For each volume of prepared files
  ;  For each entry in page-counts list
  ;   See whether there's a TOC entry for that article
  ;     If not, and volume >= 3, make a note of it
  (for-each (lambda (counts)
	      (for-each (lambda (vac)
			  (apply (lambda (volnum artnum count)
				   (let ((art (maybe-article-info volnum artnum)))
				     (cond (art
					    (check-page-count art count))
					   ((not (vector-ref table-of-contents volnum))
					    'skip)
					   (else
					    (write `(missing-toc-entry ,volnum ,artnum))
					    (newline)))))
				 vac))
			(reverse counts)))
	    (vector->list page-counts-by-volume)))

(define (check-page-count article count)
  (let ((range (article-pages article))
	(v (article-volume article))
	(a (article-id article)))
    (if (list? range)
	(let* ((p (car range))
	       (q (cadr range))
	       (q+ (- (+ p count) 1))
	       (report (lambda (kind)
			 (write `(,kind ,v ,range ,q+))
			 (newline))))
	  (if (number? q)
	      (let ((toc-count (+ (- q p) 1)))
		(cond ((= q q+)
		       'ok)
		      ((and (even? q) (= q (+ q+ 1)))
		       ; Image processing detected blank page
		       (report 'blank-page-trimmed))
		      ((and (odd? q) (= q (- q+ 1)))
		       ; Q in TOC was set manually
		       (report 'blank-page-untrimmed))
		      ((< q+ q)
		       (report 'shortfall))
		      (else
		       (report 'surplus))))
	      (report 'toc-missing-q))))))

(define (get-page-count volume artnum)
  (let ((ac (assoc artnum
		   (vector-ref page-counts-by-volume volume))))
    (if ac (caddr ac) #f)))


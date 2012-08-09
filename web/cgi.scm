; Copyright (c) 2001-2007 Jonathan Rees http://mumble.net/~jar/LICENSE.txt

; Reading and writing CGI

;----------------------------------------
; CGI parsing -- for receiving form data via a POST or GET.
; We don't use GET, however, so we won't bother dealing with it.
; Cf. read-html-content

(define-content-type-reader 'application/x-www-form-urlencoded
  (lambda (port len)
    (let* ((remaining (or len -1))

	   (readc (lambda ()
		    (if (= remaining 0)
			#f
			(let ((c (read-char port)))
			  (if (eof-object? c)
			      #f	;shouldn't happen
			      (begin (set! remaining (- remaining 1))
				     c))))))

	   (cgi (parse-cgi readc)))

      (lambda (verb)
	(case verb
	  ((type) 'application/x-www-form-urlencoded)
	  ((length) len)
	  ((writer)
	   (lambda (port)
	     (write-content (cgi->content cgi) port)))
	  ((extract) cgi)
	  (else (error "MNU 3" verb)))))))

; READC should be a procedure of no arguments that returns either a
; character or, at end of input, #f.

(define (parse-cgi readc)

  (define (read-part)
    (let loop ((cs '()))
      (let ((c (readc)))
	(case c
	  ((#f #\= #\&)
	   (values (if (null? cs)
		       #f
		       (list->string (reverse cs)))
		   c))
	  ((#\%)
	   (let* ((c1 (readc)) (c2 (readc)))
	     (loop (cons (ascii->char (string->number (string c1 c2) 16))
			 cs))))
	  ((#\+) (loop (cons #\space cs)))
	  (else (loop (cons c cs)))))))

  (let loop ((pairs '()))
    (call-with-values (lambda () (read-part))
      (lambda (s1 c1)
	(case c1
	  ((#\=)
	   (call-with-values (lambda () (read-part))
	     (lambda (s2 c2)
	       (case c2
		 ((#\&)
		  (loop (cons (cons s1 s2) pairs)))
		 ((#f)
		  (reverse (cons (cons s1 s2) pairs)))
		 ((#\=)
		  (warn "invalid CGI syntax" s1 c1 s2 c2)
		  (loop (cons (cons s1 s2) pairs)))
		 (else (error "shouldn't happen"))))))
	  ((#f)
	   (reverse (if s1
			(cons (cons s1 s1) pairs)
			pairs)))
	  ((#\&)
	   (loop (cons s1 s1) pairs))
	  (else (error "shouldn't happen")))))))

;----------------------------------------
; CGI generation -- for when we want to pretend to be a client filling
; out a form.
; The emitter must be able to buffer the output, since we can't write
; any of it until we've computed the whole thing's content-length.
; Could use the extended-port feature of Scheme 48...?

(define (cgi->content alist)
  (let ((len 0)
	(chars '()))

    (define (emit c) (set! chars (cons c chars)) (set! len (+ len 1)))

    (define (emit-cgi s)
      (for-each (lambda (c)
		  (cond ((or (char=? c #\space)
			     (char=? c #\&)
			     (char=? c #\=)
			     (char=? c #\+)
			     (char=? c #\%))
			 (emit #\%)
			 (let ((foo (number->string (+ (char->ascii c) 256)
						    16)))
			   (emit (string-ref foo 1))
			   (emit (string-ref foo 2))))
			(else (emit c))))
		(string->list (stringify s))))

    (define (emit-field field)
      (emit-cgi (car field))
      (emit #\=)
      (emit-cgi (cdr field)))

    (if (not (null? alist))
	(begin (emit-field (car alist))
	       (for-each (lambda (field)
			   (emit #\&)
			   (emit-field field))
			 (cdr alist))))

    (lambda (verb)
      (case verb
	((type) 'application/x-www-form-urlencoded)
	((length) len)
	((writer) (lambda (port)
		    (for-each (lambda (char)
				(write-char char port))
			      (reverse chars))))
	((extract) alist)
	(else (error "MNU 4" verb))))))


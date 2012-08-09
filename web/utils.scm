; Copyright (c) 2001-2007 Jonathan Rees http://mumble.net/~jar/LICENSE.txt

(define (string-position c s)		;xnum.scm
  (let loop ((i 0))
    (if (>= i (string-length s))
	#f
	(if (char=? c (string-ref s i))
	    i
	    (loop (+ i 1))))))

(define (end-of-line port)
  (write-char carriage-return port)
  (write-char #\newline port))

(define (xml-end-of-line port)
  (newline port))  ;liberal

(define carriage-return (ascii->char 13))

(define (read-until pred port)
  (let loop ((l '()))
    (let ((c (peek-char port)))
      (if (eof-object? c)
          (if (null? l)
	      c
	      (list->string (reverse l)))
          (if (pred c)
              (list->string (reverse l))
              (loop (cons (read-char port) l)))))))

(define (skip-whitespace port)
  (skip-while char-whitespace? port))

(define (skip-hspace port)
  (skip-while (lambda (c) (char=? c #\space)) port))

(define (skip-while pred port)
  (let ((c (peek-char port)))
    (if (eof-object? c)
	c
	(if (pred c)
	    (begin (read-char port) (skip-while pred port))
	    c))))

; Names for XML tags and attributes.  Also used for other things, I think.
; BUG: XML is case sensitive, this code isn't.
; Figure out how to parameterize.

(define (read-name port)
  (create-name (read-token port)))

(define (read-token port)
  (let loop ((chars '()))
    (let ((c (peek-char port)))
      (if (eof-object? c)
	  (if (null? chars)
	      c
	      (list->string (reverse chars)))
	  (if (continues-a-name? c)
	      (loop (cons (preferred-case (read-char port)) chars))
	      (list->string (reverse chars)))))))

(define (create-name s)
  (if (= (string-length s) 0)
      s  ;shouldn't happen
      (string->symbol s)))

(define preferred-case char-downcase) ;assumes Scheme 48

(define (string-preferred-case s)
  (list->string (map preferred-case (string->list s))))

(define (begins-a-name? c)
  (or (char-alphabetic? c)
      (char-numeric? c)			;?
      (char=? c #\_)
      (char=? c #\:)))

(define (continues-a-name? c)
  (begins-a-name? c))

(define (write-name name port) (display name port))


(define (read-line port)
  (let ((line (read-until end-of-line? port)))
    (gobble-end-of-line port)
    line))

(define (gobble-end-of-line port)
  (if (eq? (peek-char port) carriage-return) ;!!eof
      (read-char port))
  (if (eq? (peek-char port) #\newline)
      (read-char port)))

(define (end-of-line? c)
  (or (char=? c #\newline) (char=? c carriage-return)))

(define (stringify s)
  (cond ((string? s) s)
	((number? s) (number->string s))
	((symbol? s) (symbol->string s))
	(else (error "Don't know how to stringify this" s))))

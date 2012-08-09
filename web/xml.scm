; Copyright (c) 2001-2007 Jonathan Rees http://mumble.net/~jar/LICENSE.txt
; Baby-XML library for Scheme 48
; Really just the minimum needed in order to read and write simple XHTML.

; TBD:
;   Case sensitivity
;   Namespaces
;   <-- --> comments
;   <?  ?>
;   <!   >
;   &foo;

; A "content item" is one of the following:
;   pcdata ("parsed character data")
;   element
;   list of content items.
; pcdata is read as a string, but can be a string, symbol, number, or 
; character on output.

; Consider using (make-tracking-input-port port) from extended-ports, so
; that at a suitable place (necessarily inside of a tag!),
; if (> (current-column port) 70), then emit a newline.

;----------------------------------------
; Attributes

(define-record-type attribute :attribute
  (%make-attribute keyword value? value)
  attribute?
  (keyword attribute-keyword)
  (value? attribute-value?)
  (value attribute-value))

(define (make-attribute keyword value? value)
  (%make-attribute keyword
		   value?
		   (cond ((string? value) value)
			 ((symbol? value) (symbol->string value))
			 ((number? value) (number->string value))
			 ((not value?) #f)
			 (else (error "expected something coercible to a string, but got this"
				      value
				      `(keyword = ,keyword))))))

; Convenience.  E.g. (define action= (attribute-constructor 'action))

(define (attribute-constructor keyword)
  (lambda (value)
    (make-attribute keyword #t value)))

(define-record-discloser :attribute
  (lambda (a)
    (if (attribute-value? a)
	`(= ,(attribute-keyword a) ,(attribute-value a))
	`(= ,(attribute-keyword a)))))

;----------------------------------------
; XML elements
;   element ::= <foo {keyword=value}* />
;             | <foo {keyword=value}*> {item}* </foo>
;   item ::= element | pcdata

(define-record-type element :element
  (%make-element type attributes content)
  element?
  (type element-type)
  (attributes element-attributes)
  (content element-content))

(define (make-element type attributes content)
  (%make-element type
		 ;; These must be attributes
		 (check-attributenesses attributes)
		 ;; These must be content items
		 (check-contentedness content)))

(define-record-discloser :element
  (lambda (el)
    `(element ,(element-type el)
	      ,@(element-attributes el)
	      ,@(or (element-content el)
		    '()))))


; (element-constructor type)
; E.g. (define form (element-constructor 'form))

; There could be a define-element-type macro, but we'll settle with
; the following for now.

(define (element-constructor type)
  (lambda rest
    ;; Peel off initial attributes.  The rest will be content.
    (let loop ((r rest)
	       (as '()))
      (if (or (null? r)
	      (not (attribute? (car r))))
	  (make-element type (reverse as) r)
	  (loop (cdr r) (cons (car r) as))))))

;----------------------------------------
; Write some XML to a port.

(define (write-item item port)
  (cond ((element? item)
	 (write-element item port))
	((list? item)
	 (write-items item port))
	((end-tag? item)
	 (display "</" port)
	 (write-name (end-tag-type item) port)
	 (write-char #\> port))
	((entity? item) (write-entity item port))
	((procedure? item) (item port))
	(else
	 (write-pcdata item port))))

(define (write-items items port)
  (for-each (lambda (item)
	      (write-item item port))
	    items))

(define (write-pcdata pcdata port)
  (if (char? pcdata)
      (write-parsed-char pcdata port)
      (let* ((s (stringify pcdata))
	     (len (string-length s)))
	(if (let loop ((i 0))
	      (if (>= i len)
		  #t
		  (if (or (char=? #\< (string-ref s i))
			  (char=? #\& (string-ref s i)))
		      #f
		      (loop (+ i 1)))))
	    ;; Premature optimization
	    (display s port)
	    ;; General case
	    (let loop ((i 0))
	      (if (< i len)
		  (begin (write-parsed-char (string-ref s i) port)
			 (loop (+ i 1)))))))))

(define (write-parsed-char c port)
  (case c
    ((#\<) (display "&lt;" port))
    ((#\>) (display "&gt;" port))
    ((#\&) (display "&amp;" port))
    ;; tbd: ISO 8859 / Unicode
    (else (write-char c port))))

(define (write-element el port)
  (let ((items (element-content el)))
    (if (or (null? items) (eq? items #f))
	(write-empty-element el port)
	(begin (write-start-tag el port)
	       (for-each (lambda (item)
			   (write-item item port))
			 items)
	       (write-end-tag el port)))))

; <name aname=value .../>

(define (write-empty-element el port)
  (write-char #\< port)
  (write-name (element-type el) port)
  (write-attributes (element-attributes el) port)
  (display " />" port))

; <name aname=value ...>

(define (write-start-tag el port)
  (write-char #\< port)
  (write-name (element-type el) port)
  (write-attributes (element-attributes el) port)
  (xml-end-of-line port)		;Break line after attributes and before >
  (write-char #\> port))

; </name>

(define (write-end-tag el port)
  (display "</" port)
  (write-name (element-type el) port)
  (write-char #\> port))

(define (write-attributes as port)
  (for-each (lambda (a)
	      (write-char #\space port)
	      (write-attribute-keyword (attribute-keyword a) port)
	      (if (attribute-value? a)
		  (begin (write-char #\= port)
			 (write-attribute-value (attribute-value a) port))))
	    as))

; Write the thing to the left of =

(define (write-attribute-keyword kw port)
  (write-name kw port))

; Write the thing to the right of =

(define (write-attribute-value val port)
  (write-string-value val port))

(define (write-string-value s port)
  ;; Not right when both ' and " occur in string !!
  (let ((delimiter
	 (if (string-position #\" s)
	     #\'
	     #\")))
    (write-char delimiter port)
    (display s port)
    (write-char delimiter port)))

;----------------------------------------
; Read XML.  Not so important for simple web servers.
;  There is a temptation to have read-item create an application's native
;  data structures directly, instead of an XML parse tree.
;  I'm uncomfortable with this; in particular, how do we ensure that
;  write-item on those native structures will do the right thing?

(define (read-item port)		;  => pcdata or element
  (let ((token (read-token port)))
    (if (start-tag? token)
	(call-with-values (lambda () (read-element token port))
	  (lambda (element extra)
	    ;; ugh. (if extra (warn "extra thing after element" extra))
	    element))
	token)))

(define (read-token port)
  (let ((c (peek-char port)))
    (cond ((eof-object? c) c)
	  ((char=? c #\<)
	   (read-tag port))
	  ((char=? c #\&)
	   (read-entity port))
	  (else
	   (read-pcdata port)))))
  
(define (read-tag port)
  (read-char port)			;gobble the <
  (let ((c (skip-whitespace port)))	;should return a letter
    (cond ((eof-object? c)
	   (warn "eof in tag" c)
	   '())
	  ((begins-a-name? c)
	   (read-start-tag port))
	  ((char=? c #\/)
	   (read-end-tag port))
	  ((char=? c #\?)
	   (read-char port)
	   (ignore-misc-directive port))
	  ((char=? c #\!)
	   ;; DTD declaration, or a <!-- ... --> comment,
	   ;; or <![CDATA[  ...  ]]>
	   (read-char port)
	   (ignore-misc-directive port))
	  (else
	   (warn "bogus tag" (string #\< c))
	   '()))))

(define (read-start-tag port)
  ;; It's either a start tag or an empty element.
  (let ((type (read-name port)))
    ;; Read attributes until > or />
    (let* ((attribs (read-attributes port))
	   (c (peek-char port)))
      (cond ((char=? c #\>)
	     ;; End of start tag
	     ;; Read content items
	     (read-char port)
	     (make-start-tag type
			     attribs))
	    ((char=? c #\/)
	     ;; Empty element <foo x='y'/>
	     (read-char port)
	     (let ((c (read-char port))) ;!eof
	       (if (not (char=? c #\>))
		   (warn "start tag syntax error" (string #\/ c)))
	       (make-element type attribs '())))
	    (else
	     (warn "syntax error in start tag" type c)
	     (make-start-tag type attribs))))))

(define (read-end-tag port)
  ;; This is an end tag
  (read-char port)
  (let ((c (skip-whitespace port)))	;should return a letter
    (cond ((begins-a-name? c)
	   (let ((type (read-name port)))
	     (let ((c (skip-whitespace port))) ;!eof
	       (if (not (char=? c #\>))
		   (warn "bogus end tag" type c))
	       (read-char port)
	       (make-end-tag type))))
	  ((char=? c #\>)
	   ;; SGML shortcut
	   (make-end-tag #f))
	  (else
	   (warn "bogus end tag" (string #\< #\/ c))
	   (make-end-tag #f)))))

; Read the stuff between >...<
; Should end up being elements with optional pcdata in between

(define (read-element tag port)
  (let* ((type (start-tag-type tag))
	 (terminators (case type
			((li) '(li))
			((p) '(p))
			((tr) '(tr))
			((table) '(table br p))
			(else '()))))
    (let loop ((items '()) (extra #f))
      (let ((token (or extra (read-token port))))
	(cond ((and (end-tag? token)
		    (eq? (end-tag-type token) type))
	       (finish-element tag items #f))
	      ((memq type '(meta img link input br hr))
	       ;; Elements that MUST be empty
	       (finish-element tag items token))
	      ((start-tag? token)
	       (if (memq (start-tag-type token) terminators)
		   (finish-element tag items token)
		   ;; Check to see whether start tag should act as
		   ;; terminator for current element, e.g. <li> ... <li>
		   (call-with-values (lambda () (read-element token port))
		     (lambda (element extra)
		       (loop (cons element items) extra)))))
	      ((end-tag? token)
	       (if (eq? (end-tag-type token) 'div)
		   ;; inspired by http://www.atcc.org/, which had an
		   ;; unmatched </div>
		   (begin (warn "discarding end tag"
				tag
				token
				`(items ,(reverse items)))
			  (loop items #f))
		   (begin (if (not (memq (end-tag-type token) '(ol ul td)))
			      (warn "end tag mismatch"
				    tag
				    token
				    `(items ,(reverse items))))
			  (finish-element tag items token))))
	      ((eof-object? token)
	       (warn "eof in element" type items)
	       (finish-element tag items #f))
	      (else
	       (loop (cons token items) #f)))))))

(define (finish-element tag rev-items extra)
  (values (make-element (start-tag-type tag)
			(start-tag-attributes tag)
			(reverse rev-items))
	  extra))

(define (read-attributes port)
  (let loop ((attribs '()))
    (let ((attrib (read-attribute port)))
      (if attrib
	  (loop (cons attrib attribs))
	  (reverse attribs)))))

; Read name=value

(define (read-attribute port)
  (let ((kw (read-attribute-keyword port)))
    (if kw
	(let ((c (peek-char port)))	;skip-whitespace ?
	  (if (char=? c #\=)		;!eof
	      (begin (read-char port)
		     (make-attribute kw #t (read-attribute-value port)))
	      (make-attribute kw #f #f)))
	#f)))

; Read k in k=value

(define (read-attribute-keyword port)
  (let ((c (skip-whitespace port)))	;!eof
    (if (begins-a-name? c)
	;; All done -- we must have encountered > or /
	(read-name port)
	#f)))

; Read value, e.g. foo, "foo", 'foo'

(define (read-attribute-value port)
  (let ((c (peek-char port)))
    (case c
      ((#\' #\")
       (read-matchfix-string port))
      (else (read-name port)))))

(define (read-matchfix-string port)
  (let ((c1 (read-char port)))
    (let ((s (read-until (lambda (c2) (char=? c2 c1)) port)))
      (read-char port)
      s)))

; Read "parsed character data" -- the text-like stuff in between > and <

(define (read-pcdata port)
  (let loop ((chars '()))
    (let ((c (peek-char port)))
      (cond ((or (eof-object? c)
		 (char=? c #\<)
		 (char=? c #\&))
	     (list->string (reverse chars)))
	    (else
	     ;; ??!?? fold control-M to control-J ???!?
	     (loop (cons (read-char port) chars)))))))

(define-record-type start-tag :start-tag
  (make-start-tag type attributes)
  start-tag?
  (type start-tag-type)
  (attributes start-tag-attributes))

(define-record-discloser :start-tag
  (lambda (tag) `(start-tag ,(start-tag-type tag))))

(define-record-type end-tag :end-tag
  (make-end-tag type)
  end-tag?
  (type end-tag-type))

(define-record-discloser :end-tag
  (lambda (tag) `(end-tag ,(end-tag-type tag))))


; Ignore characters up until the next >

(define (ignore-misc-directive port)
  (let loop ()
    (let ((c (read-char port)))
      (if (eof-object? c)
	  c
	  (if (eq? c #\>)
	      '()
	      (loop))))))
	      

(define-record-type entity :entity
  (entity name)
  entity?
  (name entity-name))

(define-record-discloser :entity
  (lambda (ent) `(entity ,(entity-name ent))))

(define (write-entity ent port)
  (display #\& port)
  (display (entity-name ent) port)
  (display #\; port))

(define (read-entity port)
  (read-char port)			; &
  (let loop ((chars '()))
    (let ((c (peek-char port)))
      (cond ((or (eof-object? c)
		 (char=? c #\<)
		 (char=? c #\")
		 (char=? c #\'))
	     ;; No trailing ; so don't treat as entity
	     (list->string (cons #\& (reverse chars))))
	    ((char=? c #\;)
	     (read-char port)
	     (entity (list->string (reverse chars))))
	    (else
	     (read-char port)
	     (loop (cons c chars)))))))


;----------------------------------------
; Using it

(define (element-attribute el aname)  ;or maybe get-attribute ?  get-attribute-value ?
  (let loop ((as (element-attributes el)))
    (if (null? as)
	#f
	(if (eq? aname (attribute-keyword (car as)))
	    (if (attribute-value? (car as))
		(attribute-value (car as))
		(symbol->string aname))
	    (loop (cdr as))))))
	    
(define (get-subelement elem type)
  (if (not (element? elem))
      (error "expected an element, but got this" elem type))
  (let loop ((content (element-content elem)))
    (if (pair? content)
	(if (and (element? (car content))
		 (eq? (element-type (car content)) type))
	    (car content)
	    (loop (cdr content)))
	#f)))

(define (get-subelements elem type)
  (if (not (element? elem))
      (error "expected an element, but got this" elem type))
  (let recur ((content (element-content elem)))
    (if (pair? content)
	(if (and (element? (car content))
		 (eq? (element-type (car content)) type))
	    (cons (car content)
		  (recur (cdr content)))
	    (recur (cdr content)))
	'())))

;----------------------------------------
; Boring utilities

(define (check-attributenesses as)
  (let loop ((l as))
    (if (null? l)
	as
	(if (attribute? (car l))
	    (loop (cdr l))
	    (error "invalid attribute" (car l))))))

(define (check-contentedness items)
  (let loop ((l items))
    (if (null? l)
	items
	(if (possible-item? (car l))
	    (loop (cdr l))
	    (error "invalid item" (car l))))))

(define (possible-item? x)
  (or (string? x)
      (char? x)
      (list? x)
      (element? x)
      (entity? x)
      (number? x)
      (procedure? x)))

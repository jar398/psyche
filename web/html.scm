; Copyright (c) 2001-2007 Jonathan Rees http://mumble.net/~jar/LICENSE.txt

; HTML support

(define (simple-html-response the-title . items)
  (make-response '(200 "OK")
		 (list (cons 'content-type 'text/html))
		 (item->content
		  (html (head (title the-title))
			(body (bgcolor= "#FFFFFF") ;white
			      items)))))

;----------------------------------------
; Read content type text/html.  (For client side code.)
; Where does this belong in the file?

(define-content-type-reader 'text/html
  (lambda (port len)
    ;; TBD: ought to deal with the content-length, but there appears to 
    ;; be no compelling reason to.
    (item->content (let loop ((items '()))
		     (let ((item (read-item port)))
		       (if (eof-object? item)
			   (reverse items)
			   (loop (cons item items))))))))

; Write content type text/html.  (For server side.)

(define (item->content item)
  (lambda (verb)
    (case verb
      ((type) 'text/html)
      ((length) (warn "NYI 2" verb) #f)
      ((writer) (lambda (port) (write-item item port) (end-of-line port)))
      ((extract) item)
      (else (error "MNU 2" verb)))))

;----------------------------------------
; Some HTML (for generation / server side)

(define html (element-constructor 'html))
(define head (element-constructor 'head))
(define meta (element-constructor 'meta))
(define title (element-constructor 'title))
(define hlink (element-constructor 'link))   ;link conflicts with posix-files
(define base (element-constructor 'base))    ;<base href="foo">
(define body (element-constructor 'body))
(define bgcolor= (attribute-constructor 'bgcolor))
(define align= (attribute-constructor 'align))
(define rel= (attribute-constructor 'rel))    ;for <link ...>

(define class= (attribute-constructor 'class))

; Ordinary text
(define div (element-constructor 'div))
(define span (element-constructor 'span))
(define p (element-constructor 'p))
(define a (element-constructor 'a))
(define href= (attribute-constructor 'href))
(define h1 (element-constructor 'h1))
(define h2 (element-constructor 'h2))
(define h3 (element-constructor 'h3))
(define h4 (element-constructor 'h4))
(define kbd (element-constructor 'kbd))
(define br (element-constructor 'br))
(define hr (element-constructor 'hr))
(define i (element-constructor 'i))    ;italic
(define strong (element-constructor 'strong))
(define pre (element-constructor 'pre))
(define blockquote (element-constructor 'blockquote))
(define size= (attribute-constructor 'size))

(define font (element-constructor 'font))
(define color= (attribute-constructor 'color))

; Lists
(define ul (element-constructor 'ul))
(define ol (element-constructor 'ol))
(define li (element-constructor 'li))
(define dl (element-constructor 'dl))
(define dt (element-constructor 'dt))
(define dd (element-constructor 'dd))

; Forms
(define form (element-constructor 'form))
(define action= (attribute-constructor 'action)) ;URL
(define method= (attribute-constructor 'method)) ;get or post
(define input (element-constructor 'input))
(define name= (attribute-constructor 'name))
(define type= (attribute-constructor 'type))
(define textarea (element-constructor 'textarea))
(define cols= (attribute-constructor 'cols))
(define rows= (attribute-constructor 'rows))
(define value= (attribute-constructor 'value))

; Tables
(define table (element-constructor 'table))
(define tr (element-constructor 'tr))
(define td (element-constructor 'td))  ;"table data cell"
(define width= (attribute-constructor 'width))    ;Applies to entire column
(define height= (attribute-constructor 'height))
(define border= (attribute-constructor 'border))  ;default 1
(define cellspacing= (attribute-constructor 'cellspacing)) ;default 2
(define valign= (attribute-constructor 'valign))
(define frame= (attribute-constructor 'frame))

; Images
(define img (element-constructor 'img))
(define src= (attribute-constructor 'src))
(define alt= (attribute-constructor 'alt))

; Meta
(define content= (attribute-constructor 'content))

;-----------------------------------------------------------------------------
; Foo

(define (auto-index! dir)
  (directory-set! dir
		  "/"
		  (lambda (request)
		    (simple-html-response "Root" (directory->hypertext dir))))
  dir)

(define (directory->hypertext dir)
  (ul (map (lambda (key+val)
	     (li (a (href= (car key+val))
		    (car key+val))))
	   (list-directory dir))))

;----------------------------------------
; Boring utilities

; tbd: text/plain

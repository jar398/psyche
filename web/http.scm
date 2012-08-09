; Copyright (c) 2001-2007 Jonathan Rees http://mumble.net/~jar/LICENSE.txt

; HTTP protocol (RFC 2616)

;  Mostly server side stuff, although there are a number of utilities
;  that are also of use on the client side.

; This is a very quick hack -- sorry for the lack of documentation.

; From RFC 2616:
;        generic-message = start-line
;                          *(message-header CRLF)
;                          CRLF
;                          [ message-body ]
;        start-line      = Request-Line | Status-Line


(define our-http-version "HTTP/1.0") ;?

; -----------------------------------------------------------------------------
; Generic HTTP server framework

(define *request* #f)

(define (service-http-requests port responder)
  (let ((sock #f))
    (dynamic-wind
	(lambda () (set! sock (open-socket port)))
	(lambda ()
	  (let loop ()
	    (if (let ((in #f) (out #f))
		  (dynamic-wind
		   (lambda ()
		     (call-with-values (lambda () (socket-accept sock))
		       (lambda (i o)
			 (set! in i) (set! out o))))
		   (lambda ()
		     (let ((request (read-http-request in)))
		       (set! *request* request)
		       ;; Log
		       (begin (write `(,(request-verb request)
				       ,(request-uri request)
				       ,(request-version request)))
			      (newline))
		       (let ((response (responder request)))
			 (if (response? response)
			     (begin (write-http-response response out)
				    #t) ;Loop
			     (begin (write `(quit: ,response)) (newline)
				    #f))))) ;Don't loop
		   (lambda ()
		     (if out (close-output-port out))
		     (if in (close-input-port in)))))
		(loop)
		'done)))
	(lambda ()
	  (if sock
	      (begin (note "Closing socket" sock)
		     (close-socket sock)))))))

; see bottom of this file
(define (error-response status)
  (make-response status
		 (list (cons 'content-type 'text/plain))
		 ;; Create a simple content object containing comment?
		 (plain-text-content "The server says: "
				     (number->string (car status))
				     " "
				     (cadr status))))

(define (plain-text-content . strings)
  (lambda (verb)
    (case verb
      ((type) 'text/plain)
      ((length) (apply + (map string-length strings)))
      ((writer) (lambda (port)
		  (for-each (lambda (string)
			      (display string port))
			    strings)
		  (end-of-line port)))
      ((extract) (apply string-append strings))
      (else (error "MNU 2" verb)))))

; -----------------------------------------------------------------------------
; Request =  <method-token> <uri> <httpversion>
;            <header>
;            ...
;            <blank line>
;            <content>                -- typically CGI, iff this is a POST
; The URI plays the role of an injection tag, with / being no-op.

(define-record-type request :request
  (make-request+ verb path h q v)
  request?
  (verb request-verb)   ;a symbol
  (path request-uri)       ;a string usually beginning with /
  (h request-headers)	  ;an association list
  (q request-content)
  (v request-version)   ;e.g. "HTTP/1.0"
  )

(define (make-request verb uri h q)
  (make-request+ verb uri h q our-http-version))

(define (set-request-uri request new-path)
  (make-request+ (request-verb request)
		 new-path
		 (request-headers request)
		 (request-content request)
		 (request-version request)))


(define (request-uri-sans-query request)
  (let ((uri (request-uri request)))
    (let ((? (string-position #\? uri)))
      (if ?
	  (substring uri 0 ?)
	  uri))))

(define (read-http-request port)
  ;; GET /foo HTTP/1.0
  (skip-hspace port)
  (let ((verb (read-name port)))
    (skip-hspace port)
    (let ((uri (read-until (lambda (c)
			     (or (char=? c #\space) (char=? c #\newline)))
			   port)))
      (skip-hspace port)
      (let ((version (read-until char-whitespace? port)))
	(skip-hspace port)
	(gobble-end-of-line port)
	(let ((headers (read-headers port)))
	  (make-request+ verb uri headers 
			 ;; "Content-type: application/x-www-form-urlencoded"
			 ;; for a PUT means CGI
			 (read-http-content port headers)
			 version))))))

; For clients
;  cf. write-http-response
; The method token IS case sensitive.

(define (write-http-request request port)
  (display (list->string (map char-upcase (string->list (symbol->string (request-verb request)))))
	   port)
  (display #\space port)
  (display (request-uri request) port)
  (display #\space port)
  (display (request-version request) port)
  (end-of-line port)
  (write-headers (request-headers request) port)
  (end-of-line port)			;Blank line
  (write-content (request-content request) port))

; For receiving POST data, and for web client use.

(define (read-http-content port headers)
  (let ((type (let ((type (get-header 'content-type headers)))
		(if type
		    ;; e.g. "text/html; charset=iso-8859-1"
		    (string->symbol
		     (string-preferred-case
		      (let ((foo (string-position #\; type)))
			(if foo
			    (substring type 0 foo)
			    type))))
		    #f))))     ;Careful here.
    (if type
	(let ((len (let ((len (get-header 'content-length headers)))
		     (if len (string->number len) #f)))
	      (probe (table-ref content-type-readers type)))
	  (if probe
	      (probe port len)
	      (error "unrecognized content type" type)))
	#f)))

; The interpretation of the content depends completely on the
; content-type.  Here is a table that allows new content-type
; processors to be added by various modules.

(define content-type-readers (make-table))
(define (define-content-type-reader type proc)
  (table-set! content-type-readers type proc))


; -----------------------------------------------------------------------------
; Response = <httpversion> <status-code> <comment>    -- e.g. HTTP/1.1 200 OK
;            <header>
;            ...
;            <blank line>
;            <content>                -- typically some HTML

(define-record-type response :response
  (make-response+ s h q v)
  response?
  (s response-status)
  (h response-headers)
  (q response-content)
  (v response-version))

(define (make-response s h q)
  (make-response+ s h q our-http-version))

(define (response-content-type r)
  (get-header 'content-type (response-headers r)))

(define (write-http-response response port)
  (display (response-version response) port)
  (write-char #\space port)
  (let ((status (response-status response)))
    (display (car status) port)
    (write-char #\space port)
    (display (cadr status) port)
    (end-of-line port))
  (write-headers (response-headers response) port)
  (end-of-line port)			;Blank line
  ;; The following should depend on the response's content-type.
  (write-content (response-content response) port))

(define (read-http-response port)
  ;; HTTP/1.1 200 OK
  (if (eof-object? (skip-hspace port))
      (error "got EOF instead of HTTP/1.1"))
  (let ((version (read-until char-whitespace? port)))
    (if (eof-object? (skip-hspace port))
	(error "got EOF instead of status code" version))
    (let ((status-code (string->number
			(read-until char-whitespace? port))))
      (if (eof-object? (skip-hspace port))
	  (error "got EOF instead of response comment" version))
      (let ((status-comment (read-line port))) ;maybe empty
	(let ((headers (read-headers port)))
	  (make-response+ (list status-code status-comment)
			  headers
			  (read-http-content port headers)
			  version))))))

;----------------------------------------
; Read and write headers  (lines of the form "Foo: value")

(define (read-headers port)
  (let loop ((hs '()))
    (let ((h (read-header port)))
      (if h
	  (loop (cons h hs))
	  (reverse hs)))))

; Read a single header, Foo: value <crlf>

(define (read-header port)
  (skip-hspace port)
  (let ((type-perhaps (read-until (lambda (c)
				    (or (char=? c #\:)
					(char-whitespace? c)))
				  port)))
    (if (= (string-length type-perhaps) 0)
	(begin (gobble-end-of-line port)
	       #f)				;Blank line, probably
	(let ((type (string->symbol
		     (string-preferred-case type-perhaps))))
	  (if (char=? (peek-char port) #\:)
	      (begin (read-char port)
		     (skip-hspace port)
		     (cons type (read-line port)))
	      (begin (warn "Invalid header syntax"
			   type-perhaps
			   (read-line port))
		     #f))))))

(define (write-headers headers port)
  (for-each (lambda (hdr)
	      (write-header hdr port))
	    headers))

(define (write-header hdr port)
  ;; Should capitalize to be nice, but it's not necessary.
  (write-name (car hdr) port)
  (display ": " port)
  (display (cdr hdr) port)
  (end-of-line port))

; Pick a header out of an a-list of headers.

(define (get-header tag headers)
  (let ((probe (assq tag headers)))
    (if probe
	(cdr probe)
	#f)))

;----------------------------------------
; Payload abstraction:
; . get MIME type as symbol (+ properties)
; . get content length length, in bytes
; . write content to a port
; . read content in a type-specific way
; E.g. Content-type: multipart/mixed; boundary="frontier"

(define (content-type content)   (content 'type))
(define (content-length content) (content 'length))
(define (write-content content port)
  (if content
      ((content 'writer) port)))
(define (extract-content content)
  (if content
      (content 'extract)		;as string
      #f))

;----------------------------------------
; URI / URL parsing.  To do this right, see RFC 2396.
;  (parse-url string) returns 4 values: protocol, host, port, URI
; This is a utility to be used by responders.
; TBD: Handle % codes?
; TBD: Peel off the query (after ?) and parse it?

(define (parse-url s)

  (define (parse-protocol s)
    (let ((probe (string-position #\: s)))
      (if probe
	  (parse-host (substring s 0 probe)
		      (substring s (+ 1 probe) (string-length s)))
	  (parse-host #f s))))

  (define (parse-host protocol s)
    (if (and (>= (string-length s) 2)
	     (char=? (string-ref s 0) #\/)
	     (char=? (string-ref s 1) #\/))
	(let* ((s (substring s 2 (string-length s)))
	       (probe (string-position #\/ s)))
	  (if probe
	      (parse-port protocol
			  (substring s 0 probe)
			  ;; URI includes the leading /
			  (substring s probe (string-length s)))
	      (parse-port protocol s #f)))
	(values protocol #f #f s)))

  (define (parse-port protocol host+port uri)
    (let ((probe2 (string-position #\: host+port)))
      (if probe2
	  (values protocol
		  (substring host+port 0 probe2)
		  (string->number (substring host+port
					     (+ probe2 1)
					     (string-length host+port)))
		  uri)
	  (values protocol
		  host+port
		  #f
		  uri))))

  (parse-protocol s))

; -----------------------------------------------------------------------------

; Do something webdavvy ?

; (make-http-directory)
; (directory-set! dir "/foo.html" responder)
; (directory-set! dir "/bar/" responder)
; (directory-ref dir "/bar/")  => responder

(define (directory-ref dir string)
  (table-ref (directory-table dir) string))

(define (directory-set! dir string rd)
  (table-set! (directory-table dir) string rd))

(define (list-directory dir)
  (let ((foo '()))
    (table-walk (lambda (key val)
		  (set! foo
			(cons (cons key val) foo)))
		(directory-table dir))
    (sort-list foo
	       (lambda (kv1 kv2)
		 (string<? (car kv1)
			   (car kv2))))))

(define (directory-table dir)
  (dir (make-request 'recover-table "." '() #f)))

(define (make-http-directory)
  (let ((table (make-string-table)))
    (lambda (request)
      (case (request-verb request)
	((recover-table) table)
	((get)
	 (let ((/uri (request-uri request)))
	   (let ((probe (table-ref table /uri)))
	     (if probe
		 (probe (set-request-uri request "."))
		 (if (not (char=? (string-ref /uri 0) #\/))
		     (error-response '(404 "Not found"))
		     ;; Find the second / in "/foo/bar.txt"
		     (let* ((uri (substring /uri 1 (string-length /uri)))
			    (/ (string-position #\/ uri)))
		       (if /
			   ;; lookup key = "/foo/"
			   (let ((probe (table-ref table (substring /uri 0 (+ / 1)))))
			     (if probe
				 (probe
				  (set-request-uri request
						   (substring uri / (string-length uri))))
				 (error-response '(404 "Not found"))))
			   (error-response '(404 "Not found")))))))))
        ((put)
	 ;; Doesn't work, for some reason.
	 ;; In particular, I need to fix the XML parser so that it understands
	 ;; <!doctype html ... >, which is generated by Netscape.
	 (let ((/uri (let ((uri (request-uri request)))
		       (if (char=? (string-ref uri 0) #\/)
			   uri
			   (string-append "/" uri)))))
	   ;; Find the second / in "/foo/bar.txt"
	   (let* ((uri (substring /uri 1 (string-length /uri)))
		  (/ (string-position #\/ uri)))
	     (if /
		 (let ((probe (table-ref table (substring /uri 0 (+ / 1)))))
		   (if probe
		       (probe
			(set-request-uri request
					 (substring uri / (string-length uri))))
		       (error-response '(403 "Directory not found"))))
		 (begin
		   (table-set! table
			       /uri
			       (request->responder request))
		   (make-response '(202 "Published") ;accepted
				  (list (cons 'content-type 'text/plain))
				  ;; Create a simple content object containing comment?
				  (plain-text-content "Your stuff got stored as "
						      /uri)))))))
	;; ((delete) ...)
	(else
	 (error-response '(400 "Bad request")))))))

; Apparently, Netscape Composer doesn't provide a proper content-type
; when it does a PUT.

(define (request->responder request)
  (let ((response
	 ;; Args are: version status-code comment headers content
	 (make-response '(200 "OK")
			(list (cons 'content-type
				    (get-header 'content-type
						(request-headers request))))
			(request-content request))))
    (lambda (request)
      (if (and (eq? (request-verb request) 'get)
	       (string=? (request-uri request) "."))
	  response
	  (error-response '(400 "Bad request"))))))

;----------------------------------------
; HTTP Status Codes

(define *continue                  '(100 "Continue"))
(define *switching-protocols	   '(101 "Switching Protocols"))
(define *ok			   '(200 "OK"))
(define *created		   '(201 "Created"))
(define *accepted		   '(202 "Accepted"))
(define *non-authoritative-information '(203 "Non-Authoritative Information"))
(define *no-content		   '(204 "No Content"))
(define *reset-content		   '(205 "Reset Content"))
(define *partial-content	   '(206 "Partial Content"))
(define *multiple-choices	   '(300 "Multiple Choices"))
(define *moved-permanently	   '(301 "Moved Permanently"))
(define *moved-temporarily	   '(302 "Moved Temporarily"))
(define *see-other		   '(303 "See Other"))
(define *not-modified		   '(304 "Not Modified"))
(define *use-proxy		   '(305 "Use Proxy"))
(define *bad-request		   '(400 "Bad Request"))
(define *unauthorized		   '(401 "Unauthorized"))
(define *payment-required	   '(402 "Payment Required "))
(define *forbidden		   '(403 "Forbidden"))
(define *not-found		   '(404 "Not Found"))
(define *method-not-allowed	   '(405 "Method Not Allowed"))
(define *not-acceptable		   '(406 "Not Acceptable"))
(define *proxy-authentication-required '(407 "Proxy Authentication Required"))
(define *request-time-out          '(408 "Request Time-Out"))
(define *conflict		   '(409 "Conflict"))
(define *gone			   '(410 "Gone"))
(define *length-required	   '(411 "Length Required"))
(define *precondition-failed	   '(412 "Precondition Failed"))
(define *request-entity-too-large  '(413 "Request Entity Too Large"))
(define *request-url-too-large	   '(414 "Request-URL Too Large"))
(define *unsupported-media-type	   '(415 "Unsupported Media Type"))
(define *server-error		   '(500 "Server Error"))
(define *not-implemented	   '(501 "Not Implemented"))
(define *bad-gateway		   '(502 "Bad Gateway"))
(define *out-of-resources	   '(503 "Out of Resources"))
(define *gateway-time-out	   '(504 "Gateway Time-Out"))
(define *http-version-not-supported '(505 "HTTP Version not supported"))

; Copyright (c) 2001-2007 Jonathan Rees http://mumble.net/~jar/LICENSE.txt

; util extended-ports

;----------------------------------------
; Degenerate HTTP client...
; E.g.
;  (write-content (response-content (get "http://mumble.net/")) (current-output-port))

(define (get url)
  (call-with-values (lambda () (parse-url url))
    (lambda (proto host port path)
      (issue-request host
		     port
		     'get
		     path
		     '()
		     #f))))

; alist (("propname" . "propval") ...)

(define (post url alist)
  (call-with-values (lambda () (parse-url url))
    (lambda (proto host port path)
      (let* ((separator "xyzzy")
	     (payload (compose-post-payload alist separator))
	     (ctype (string-append
		     "multipart/form-data; boundary="
		     separator)))
	(issue-request host
		       port
		       'post
		       path
		       (list (cons 'content-type
				   ctype)
			     (cons 'content-length
				   (string-length payload)))
		       (lambda (verb)
			 (case verb
			   ((type) ctype)
			   ((length) (string-length payload))
			   ((writer)
			    (lambda (port) (display payload port)))
			   ((extract) payload))))))))

(define (compose-post-payload alist separator)
  (let ((oport (make-string-output-port)))
    (for-each (lambda (name+value)
		(display "--" oport)
		(display separator oport)
		(end-of-line oport)
		(display "Content-Disposition: form-data; name=\"" oport)
		(display (car name+value) oport)
		(display "\"" oport)
		(end-of-line oport)
		(end-of-line oport)
		(display (cdr name+value) oport)
		(end-of-line oport))
	      alist)
    (display "--" oport)
    (display separator oport)
    (display "--" oport)
    (end-of-line oport)
    (string-output-port-output oport)))

(define (issue-request host port verb path headers payload)
  (let ((in #f) (out #f)
	(port (or port 80))
	(host (or host "localhost")))
    (dynamic-wind
	(lambda ()
	  (call-with-values
	      (lambda () (socket-client host port))
	    (lambda (i o)
	      (set! in i)
	      (set! out o))))
	(lambda ()
	  (write-http-request (make-request verb
					    path
					    (cons
					     (cons 'user-agent
						   "Penumbron 3.1")
					     (cons
					      (cons 'host host)
					      headers))
					    payload)
			      out)
	  (read-http-response in))
	(lambda ()
	  (if in (close-input-port in))
	  (if out (close-output-port out))))))

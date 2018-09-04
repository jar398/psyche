; Copyright (c) 2001-2007 Jonathan Rees http://mumble.net/~jar/LICENSE.txt

; Configuration file for http, html, cgi utilities
; Load with ,config ,load Config.scm

; Renamed utils to web-utils to avoid neurocommons package name conflict

(define-structure web-utils (export string-position
				end-of-line
				xml-end-of-line
				skip-whitespace
				skip-hspace
				read-until
				string-preferred-case
				read-line
				gobble-end-of-line
				end-of-line?
				read-token
				read-name
				write-name
				begins-a-name?
				stringify)
  (open scheme signals ascii)
  (files utils))

(define-structure xml (export attribute-constructor
			      element-constructor
			      write-item
			      read-item
			      element?
			      element-type
			      element-attributes
			      element-attribute
			      element-content
			      get-subelements
			      get-subelement
			      entity
			      entity?
			      entity-name
			      xml-end-of-line
			      make-element)
  (open scheme
	define-record-types signals
	web-utils)
  (files xml))

(define-structure http (export service-http-requests
			       parse-url
			       write-http-request
			       read-http-response
			       ;; Request
			       make-request
			       request-verb     ;or "method token"
			       request-uri
			       request-content
			       ;; Response
			       make-response
			       response-content
			       response-status
			       error-response
			       ;; Content
			       content-type
			       content-length
			       extract-content
			       write-content
			       define-content-type-reader
			       ;; Directories
			       make-http-directory
			       directory-ref
			       directory-set!
			       list-directory)
  (open scheme
	define-record-types signals sockets tables sort
	web-utils)
  (files http))

(define-structure html (export h2
			       simple-html-response
			       item->content
			       a
			       body
			       br
			       dd dl dt
			       div
			       font
			       form
			       h1 h2 h3 h4
			       head
			       html
			       hr
			       i
			       img
			       input
			       kbd
			       li
			       hlink
			       meta
			       ol
			       p
			       pre
			       span
			       strong
			       table
			       td
			       textarea
			       title
			       tr
			       ul
			       action=
			       align=
			       alt=
			       bgcolor=
			       border=
			       cellspacing=
                               charset=
			       class=
			       color=
			       cols=
			       content=
			       frame=
			       height=
			       href=
			       method=
			       name=
			       rel=
			       rows=
			       size=
			       src=
			       type=
			       value=
			       valign=
			       width=
			       )
  (open scheme signals
	web-utils xml http)
  (files html))

(define-structure cgi (export parse-cgi cgi->content)
  (open scheme signals ascii
	web-utils http)
  (files cgi))

(define-structure http-client (export get)
  (open scheme signals ascii sockets extended-ports
	web-utils http)
  (files client))

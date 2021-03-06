;; vi
;; TODO: combine two maps colon and single char cmds
;; TODO: parse cmds with numbers

(texmacs-module (vi)
  ;;  (:use (generic generic-kbd)
  )

(load "normal.scm")

(define-public vi-mode? #f)
(define-public cmd-buffer '())
(define (zzzz) vi-mode?)
(texmacs-modes
  (in-vi% (zzzz)))

(tm-define (vi-switch)
  (set! vi-mode? (not vi-mode?)))

(tm-define (exit-vi-mode)
  (set! vi-mode? #f)
  (set! cmd-buffer '()))

(tm-define (enter-vi-mode)
  (set! vi-mode? #t))

(tm-define (keyboard-press key time)
  (:require (not vi-mode?))
  (cond 
    ((== key "escape") (enter-vi-mode))
    (else (former key time))))

(tm-define (message-from-key key)
  (string-append "Sorry! " key " is not supported."))

(tm-define (keyboard-press key time)
  (:require vi-mode?)
  (vi-dispatch key))

;; :w
(tm-define (write-to-tm file-name)
  (let* ((this (current-buffer))
	 (to-file-name
	  (if (== "" file-name)
	      this
	      (url-relative this file-name))))
    (if (or (url-scratch? this)
	    (== "" file-name)
	    (== file-name this))
	(save-buffer this)
	(save-buffer-as to-file-name (list)))))

;; wq
(tm-define (write-and-quit file-name)
  (write-to-tm file-name)
  (quit-TeXmacs))

;; open maxima plugin
(tm-define (maxima s)
  (make-session "maxima" "default"))

;; open graph plugin
(tm-define (graph s) (noop))

(tm-define (set-cmd-buffer lst)
  (set! cmd-buffer lst))

(tm-define (clear-cmd-buffer)
  (set-cmd-buffer '()))

(tm-define (join l)
  (if (null? l) ""
      (let ((c (car l)))
	(string-append (if (== c "space") " " c) (join (cdr l))))))

(tm-define (test-join l) ;; for testing chinese
  (if (null? l) ""
      (let ((c (car l)))
	(string-append (if (== c "space") " " c) " " (test-join (cdr l))))))

(tm-define (skip-colon-space l)
  (if (null? l) '("")
      (let ((c (car l)))
	(if (or (== c ":") (== c "space"))
	    (skip-colon-space (cdr l))
	    l))))

;; a recursive version of parsing
(tm-define (-parse l cmd)
  (let ((c (car l)))
    (if (== c "space")
	(if (null? (cdr l)) (list cmd "")
	    (list cmd (join (skip-colon-space (cdr l)))))
	(if (null? (cdr l)) (list (string-append cmd c) "")
	    (-parse (cdr l) (string-append cmd c))))))

(tm-define (vi-parse-colon l)
  (-parse (skip-colon-space l) ""))


(tm-define (vi-dispatch key)
  (set-cmd-buffer (append cmd-buffer (list key)))
  
  (let* ((fc (car cmd-buffer))
	 (lc (cAr cmd-buffer)))
    (if (== key "escape")
	(begin (clear-cmd-buffer) (set-message "clearing" ""))
	(cond

	  ((and (== fc ":")
		(== lc "return"))
	   (let* ((cmd-opt (vi-parse-colon (cDr cmd-buffer)))
		  (cmd (car cmd-opt))
		  (opt (cadr cmd-opt))
		  (cmd-fn (ahash-ref vi-colon-map cmd)))
	     (if cmd-fn
		 (begin (cmd-fn opt) (clear-cmd-buffer))
		 (begin (clear-cmd-buffer) (set-message "invalide cmd as well" "")))))

	  ((and (== fc ":")
		(not (== lc "return"))
		(not (== lc "backspace")))
	   (set-message (test-join cmd-buffer) ""))

	  ;; only :, backspace bug happens
	  ((and (== fc ":")
		(== lc "backspace"))
	   (set-cmd-buffer (cDr (cDr cmd-buffer)))
	   (set-message (join cmd-buffer) ""))

	  (else ; normal cmd
	    (if (invalid? (parse-all cmd-buffer))
		(begin
		  (clear-cmd-buffer)
		  (set-message "invalid" ""))

		(let* ((parse-res (parse-all cmd-buffer))
		       (cmd-type (cadr parse-res))
		       (cmd-char (caddr parse-res)))

		  (cond

		    ((valid-mark? parse-res)

		     (let ((m (fourth parse-res))
			   (c cmd-char))
		       (jump-or-mark c m)
		       )
		     (clear-cmd-buffer))

		    ((valid-search? parse-res)
		     (set-message (string-append "Success: " (join cmd-buffer)) "")
		     (clear-cmd-buffer))

		    ((valid-hjkl? parse-res)
		     (when (in? cmd-char '("h" "j" "k" "l" "left" "right" "up"
					   "down" "return" "backspace" "i" "L"
					   "G" "A" "I" "#" "[" "]" "o" "O" "x"
					   "$" "0" "b" "w" "u" "D" "p" "R"))
		       (let ((n (-repeat-times parse-res))
			     (fn (vi-get-cmd cmd-char)))
			 (repeat n (when fn (fn)))))
		     (clear-cmd-buffer))

		    ((valid-cmpd? parse-res)
		     (set-message (string-append "Success: " (join cmd-buffer)) "")
		     (clear-cmd-buffer))
		    (else
		      (set-message
		       (string-append "not complete: " (join cmd-buffer)) ""))))))))))

(define-public single-char-cmds (make-ahash-table))

(tm-define (vi-map-set! key fn)
  (ahash-set! single-char-cmds key fn))

(tm-define (vi-get-cmd key)
  (ahash-ref single-char-cmds key))

(tm-define (vi-map-one l)
  (if (and (pair? l) (string? (car l)) (pair? (cdr l)))
      (with (key action) l
	`(vi-map-set! ,key ,action))
      (set-message "error" "error")))

(tm-define (vi-map-body l)
  (map (lambda (x) (vi-map-one x)) l))

(tm-define-macro (vi-kbd-map . l)
  `(begin ,@(vi-map-body l)))

(vi-kbd-map
 ("$" kbd-end-line)
 ("0" kbd-start-line)
 ("^" kbd-start-line)
 ("return" (lambda () (begin (kbd-down) (kbd-start-line))))

 ("h" kbd-left)
 ("left" kbd-left)
 ("backspace" kbd-left)

 ("l" kbd-right)
 ("right" kbd-right)

 ("j" kbd-down)
 ("down" kbd-down)

 ("k" kbd-up)
 ("up" kbd-up)

 ;; researve < and > for promoting sections

 ("[" traverse-next)
 ("]" traverse-previous)

 ("o" (lambda ()
	(kbd-end-line)
	(exit-vi-mode)
	(kbd-return)))

 ("O" (lambda ()
	(kbd-start-line)
	(exit-vi-mode)
	(kbd-return)
	(kbd-left)))

 ("/" interactive-search)

 ("p" (lambda ()
	(clipboard-paste "primary")))

 ("D" (lambda ()
	(kbd-select go-end-line)
	(clipboard-cut "primary"))) ;; it should be cut

 ("x" (lambda ()
	(kbd-select kbd-right)
	(clipboard-cut "primary")))

 ("G" go-end)
 ("g" go-start)

 ("R" (lambda ()(update-document "all")))

 ("b" go-to-previous-word)
 ("w" go-to-next-word)
 ("L" (lambda () (load "c:/greensoft/texmacs/progs/my.scm")))

 ("A"
  (lambda ()
    (kbd-end-line)
    (exit-vi-mode)))

 ("I"
  (lambda ()
    (kbd-start-line)
    (exit-vi-mode)))

 ("i" exit-vi-mode)
 ("#" (lambda () (numbered-toggle (focus-tree))))
 ;;("escape" (lambda () (+ 1 -1)))
 ;; ("s" exit-vi-mode)

 ("u" (lambda ()
	(undo 0)))
 ("C-r" (lambda ()
	  (redo 0))))


;; open a scheme session
;; :scm
(tm-define (scheme s)
  (make-session "scheme" "default"))

;;(export-buffer-main (current-buffer) s fm opts)
;; current-buffer-url
;; file-format
;; url-head path
;; url->string
;; url-tail 文件名
;; url-glue
;; url-exists?

; :E
(tm-define (export-to-latex file-name)
  (let* ((this (current-buffer))
	 (to-file-name
	  (if (== "" file-name) 
	      (url-append (url-head this)
			  (string-append (url-basename this) ".tex"))
	      (url-relative this file-name))))
    (if (url-scratch? this)
	(choose-file (buffer-exporter "latex") "Export as LaTex" "latex")
	(export-buffer-main
	 this
	 to-file-name
	 "latex" (list)))))

;;(tm-define (test-msg cmd)
;;  (set-message cmd "Succcccccccccccccccccccccccccc"))

;; :e
;;  load-document without GUI

(tm-define vi-colon-map (make-ahash-table))
;;(ahash-set! vi-colon-map "t" test-msg)
(ahash-set! vi-colon-map "w" write-to-tm)
(ahash-set! vi-colon-map "wq" write-and-quit)
(ahash-set! vi-colon-map "e" load-document)
(ahash-set! vi-colon-map "scm" scheme)
(ahash-set! vi-colon-map "max" maxima)
(ahash-set! vi-colon-map "q" (lambda (x) (safely-quit-TeXmacs)))
(ahash-set! vi-colon-map "E" export-to-latex)
(ahash-set! vi-colon-map "q!" (lambda (x) (kill-current-window-and-buffer)))

(tm-define (get-colon-cmd key)
  (ahash-ref vi-colon-map key))

(tm-define (set!-colon-cmd k v)
  (ahash-set! vi-colon-map k v))


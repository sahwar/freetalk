;;; smart-prompt: Show in the prompt the jid of the last destination user
;;; Copyright (c) 2005-2014 Freetalk Core Team
;;; This file is part of GNU Freetalk.
;;;
;;; Freetalk is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; Freetalk is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see
;;; <http://www.gnu.org/licenses/>.

(use-modules (ice-9 q))

(define msgs-htable (make-hash-table))
(define waiting-users-count '0  )
(define mute-flag "no")


(define (update-prompt)
  "update and redisplay the prompt according to the selected chat mode"
  (if (> (ft-get-conn-status) 0)
    (let ((prompt-jid (if (< 0 (string-length (ft-get-current-buddy)))
			(ft-get-current-buddy)
			(ft-get-jid))))
      (if (equal? mute-flag "yes")
	(begin
	  (set! waiting-users-count (hash-count (const #t) msgs-htable))
	  (ft-set-prompt!
	    (string-append "(new:" ; "\x01\x1b[33;1m\x02"
			   (number->string waiting-users-count)
			   ; "\x01\x1b[0m\x02"
			   ") "
			   prompt-jid "> "))
	  (ft-rl-redisplay))
	(ft-set-prompt! (string-append prompt-jid "> "))))))

(define (store-msg from msg)
  "store the msg in the hash table"
  (let ((buddy-msgs (hash-ref msgs-htable from)))
    (if (equal? buddy-msgs #f)
      (begin
        (set! buddy-msgs (make-q))
        (hash-set! msgs-htable from buddy-msgs)))
    (enq! buddy-msgs msg)))


(define (process-msg timestamp from nickname msg)
  "save in the hastable or print directly on the screen"
  (if (equal? mute-flag "no")
    (print-chat-msg timestamp from nickname msg)
    (begin
      (store-msg from (list (current-time) timestamp from nickname msg))
      (update-prompt)))
  (ft-hook-return))

(define (/next args)
  "print the next unread msgs belonging to a one sender at a time"
  (let ((next-buddy "") (msgs '()))
    (hash-fold (lambda (from msgs-q prior)
                 (let ((current-msg-time (car (q-front msgs-q))))
                   (if (> prior current-msg-time)
                     (set! next-buddy (string-copy from)))
                   current-msg-time))
               +inf.0 msgs-htable)
    (if (< 0 (string-length next-buddy))
      (begin
        (set! msgs (hash-ref msgs-htable next-buddy))
        (if (not (equal? msgs #f))
          (begin
            (while (not (q-empty? msgs))
                   (let ((msg '()))
                     (set! msg (deq! msgs ))
                     (print-chat-msg (cadr msg) (caddr msg) (cadddr msg) (car (cddddr msg)))))
            (hash-remove! msgs-htable next-buddy)
            (ft-set-current-buddy! (regexp-substitute/global #f "/.*$" next-buddy 'pre "" 'post))
            ))))
    (update-prompt)))

(add-command! /next "/next" "/next" "display next message")

;

(define (/quiet-mode args)
  " quiet chat mode "
  (set! mute-flag "yes")
  (ft-display (_ " Quiet chat mode selected "))
  (update-prompt))

(add-command! /quiet-mode "/quiet-mode" "quiet-mode" "Select quiet chat mode")

(define (/normal-mode args)
  " normal chat mode "
  (set! mute-flag "no")
  (ft-display (_ " Normal chat mode selected "))
  (update-prompt))

(add-command! /normal-mode "/normal-mode" "normal-mode" "Select normal chat mode")

;

(add-hook! ft-message-send-hook
           (lambda (to message)
             (ft-set-prompt! (string-append to "> "))
             (update-prompt)))

(add-hook! ft-message-receive-hook process-msg)

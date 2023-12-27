;; ~/.emacs.d/lorien.el
;;
;; Emacs configuration - this file will be loaded only when run on lorien.
;;
;; br, 2010-2019

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; pre-load often-visited files

;; avoids calling this twice
(when (not (boundp 'my/lorien-loaded))
  (setq my/lorien-loaded t)

  ;; use ESC as C-g
  ;; (global-set-key [escape] 'keyboard-escape-quit)
  ;; (global-unset-key [escape])
  (define-key key-translation-map (kbd "ESC") (kbd "C-g"))

  ;; mail
  (require 'message)
  (setq message-send-mail-function 'smtpmail-send-it
        smtpmail-default-smtp-server "localhost"
        smtpmail-smtp-server "localhost"
        smtpmail-debug-info t
        mail-signature "\n\n-- \n2 + 2 = 5, for very large values of 2.\n"
        mail-default-headers "CC: \n"
        send-mail-function 'smtpmail-send-it
        )

  ;; shortcuts for tramp
  ;; (my/add-to-list
  ;;   'directory-abbrev-alist
  ;;   '(("^/root" . "/su:/")
  ;;      ("^/rebel" . "/ssh:arwen:www/cf.bodi/rebels21/")
  ;;      ("^/strat" . "/ssh:arwen:www/cf.bodi/strat-dom/")))

  (defconst my/loaded-files-at-startup
    (list
     "~/dev/tools/c/brlib/Makefile"
     "~/dev/brchess/Makefile"
     ;;"~/org/boot-disk.org"
     ;;"~/org/beaglebone-buster-setup.org"
     ;;"~/dev/www/cf.bodi/sql/coc.sql"
     ;;"~/dev/www/cf.bodi/sql/coc-sql.org"
      user-init-file
      "~/org/emacs-cheatsheet.org")
      ;;"~/dev/g910/g910-gkey-macro-support/lib/data_mappers/char_uinput_mapper.py"
      ;;"~/dev/advent-of-code/2022/Makefile"
      ;;"~/dev/www/com.raoult/devs/php/chess/list-pgn-games.php")
      ;; "~/dev/eudyptula/ID")
    "personal files always loaded at startup (no visible window).")

  (let ((num 1))
    (dolist
      (filename my/loaded-files-at-startup)
      (if (file-exists-p filename)
        (progn
          ;; set variable "my/buffer-1" to buffer returned by find-file
          (set
            (intern (concat "my/buffer-" (number-to-string num)))
            (find-file-noselect filename nil nil nil))
          (message "file: [%s] loaded." filename))
        (message "cannot load file: [%s]." filename))
        (cl-incf num)))

  ;; set windows for current work buffers
  (when (boundp 'my/graphic-loaded)
    (set-window-buffer my/main-window my/buffer-1)
    (set-window-buffer my/upper-window "*Messages*")
    (set-window-buffer my/below-window my/buffer-2))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Coc sync
  ;; mysql CoC connection (dev)
  ;;(defun my/connect-coc ()
    ;;(interactive)
    ;;(my/sql-connect-preset 'coc))

  (defun my/connect-coc ()
    (interactive)
    (sql-connect "coc"))

  ;; sync from/to idril
  (defun my/coc-get-db ()
    "get last coc db from arwen"
    (interactive)
    ;; force run on local machine when in tramp buffer
    (with-current-buffer (get-buffer "*scratch*")
      (async-shell-command "sync-coc-db-from-idril.sh")))
  (defun my/sync-www ()
    "sync www to arwen - dry run"
    (interactive)
    (with-current-buffer (get-buffer "*scratch*")
      (async-shell-command "sync-www-to-idril.sh")))
  (defun my/sync-www-doit ()
    "sync www to arwen"
    (interactive)
    (with-current-buffer (get-buffer "*scratch*")
      (async-shell-command "sync-www-to-idril.sh -d")))

  (setq org-publish-project-alist
        '(("org"
           :base-directory "~/org"
           :base-extension "org"
           :publishing-directory "~/dev/www/cf.bodi/org"
           :recursive t
           :publishing-function org-html-publish-to-html
           ;;:headline-levels 4
           ;;:section-numbers nil
           ;;:html-head nil
           :html-head-include-default-style nil
           :html-head-include-scripts nil
           ;; :html-preamble my-blog-header
           ;;:html-postamble my-blog-footer
           )
          ("static"
           :base-directory "~/org/"
           :base-extension "css\\|js\\|png\\|jpg\\|gif\\|pdf\\|mp3\\|ogg\\|swf"
           :publishing-directory "~/dev/www/cf.bodi/org/"
           :recursive t
           :publishing-function org-publish-attachment)

        ;; Define any other projects here...
        ))

  (global-set-key (kbd "s-c c c") 'my/connect-coc)
  (global-set-key (kbd "s-c c g") 'my/coc-get-db)
  (global-set-key (kbd "s-c c s") 'my/sync-www)
  (global-set-key (kbd "s-c c w") 'my/sync-www-doit))

;; (Define-key my/keys-mode-map
;;   (kbd "s-c c g") 'my/coc-gewt-db)
;; (define-key my/keys-mode-map
;;   (kbd "s-c c s") 'my/coc-sync-www)



;; (set-window-buffer current-buffer (get-buffer "*messages*"))))
;; (set-window-buffer "*messages*")

;; Local Variables:
;; flycheck-disabled-checkers: (emacs-lisp-checkdoc)
;; End:

;; ~/.emacs.d/lorien.el
;;
;; emacs configuration - this file will be loaded only when emacs runs on lorien.
;;
;; br, 2010-2019

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; pre-load often-visited files

;; avoids calling this twice
(when (not (boundp 'my/eowyn-loaded))
  ;; I put mainfile (current project) in variable.
  (setq
    my/mainfile "~/dev/advent-of-code/2019/RESULTS.txt"
    my/eowyn-loaded t)

  ;; mysql CoC connection
  (defun my/connect-coc ()
    (interactive)
    (my/sql-connect-preset 'coc))

  ;; shortcuts for tramp
  ;; (my/add-to-list
  ;;   'directory-abbrev-alist
  ;;   '(("^/root" . "/su:/")
  ;;      ("^/rebel" . "/ssh:arwen:www/cf.bodi/rebels21/")
  ;;      ("^/strat" . "/ssh:arwen:www/cf.bodi/strat-dom/")))

  (defconst my/loaded-files-at-startup
    (list
      my/mainfile
      user-init-file
      (concat user-emacs-directory "emacs-cheatsheet.org"))
      ;; (concat (getenv "HOME") "/dev/g910-gkey-macro-support/lib/data_mappers/char_uinput_mapper.py")
      ;; (concat (getenv "HOME") "/Documents/org/boot-disk.org"))
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
    ;;(set-window-buffer my/upper-window (get-buffer "*Messages*"))
    (set-window-buffer my/upper-window "*Messages*")
    (set-window-buffer my/below-window my/buffer-3)))

;; (set-window-buffer current-buffer (get-buffer "*messages*"))))
;; (set-window-buffer "*messages*")

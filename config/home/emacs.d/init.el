;;;; ~/.Emacs.d/init.el
;;;;
;;;; emacs configuration
;;;; br, 2010-2024
;;;;
;;;; all personal variables/defun are prefixed with "my/".
;;
;;
;; TODO
;; paredit: see https://takeokunn.github.io/.emacs.d/
;;
;;; Code:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; packages/directories setup
(require 'package)
;; (require 'use-package)
(package-initialize)
(setq use-package-always-ensure t)

(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))
;;(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/"))
;;(add-to-list 'package-archives '("ox-odt" . "https://kjambunathan.github.io/elpa/"))

;; set package directory & recompile lisp files in user-emacs-directory
(add-to-list 'load-path (concat user-emacs-directory "lisp/"))
(add-to-list 'load-path "~/data/private/")

;; (byte-recompile-directory user-emacs-directory 0 t)

;; need to check
;;(require 'prog-mode)

;; store backup and auto-saved buffers (file~ and .#file#) in ~/tmp/emacs
(defconst my/emacs-tmpdir "~/tmp/emacs"
  "Directory where to store all temp and backup files.")
(setq backup-directory (concat my/emacs-tmpdir "/backups/")
      save-directory (concat my/emacs-tmpdir "/autosave/")
      auto-save-list-file-prefix (concat my/emacs-tmpdir "/autosave-list/"))

;; create dirs if necessary
(dolist (dir (list backup-directory save-directory auto-save-list-file-prefix))
  (if (not (file-exists-p dir))
      (make-directory dir t)))

;; backup settings
(setq backup-directory-alist `(("." . ,backup-directory))
      make-backup-file t                          ; make backup when first saving
      delete-old-versions t                       ; removes old versions silently
      kept-old-versions 10                        ; how many to keep (oldest)
      kept-new-versions 10                        ; how many to keep (newest)
      backup-by-copying 1                         ; to avoid link issues, backups are copied
      version-control t                           ; numbered backups
      )
;; auto-save settings
(setq auto-save-file-name-transforms `((".*" ,save-directory t))
      auto-save-timeout 60                        ; seconds idle before auto-save
      auto-save-interval 200                      ; keystrokes between auto-saves
      )
;; backup tramp files locally
(add-to-list 'backup-directory-alist
             (cons tramp-file-name-regexp backup-directory))

;; disable lockfiles
(setq create-lockfiles nil)

;; external editing in firefox
(require 'atomic-chrome)
(atomic-chrome-start-server)

;; *scratch* & *Messages* are immortal
(add-hook 'kill-buffer-query-functions
          (lambda () (not (member (buffer-name)
                                  '("*scratch*" "*Messages*")))))

;; allow remembering risky variables
(defun risky-local-variable-p (sym &optional _ignored) "Zoba SYM." nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; swap modifier keysyms (japanese keyboard)
;; windows key (super) becomes hyper
;;(setq x-super-keysym 'hyper)
;; alt key (meta) becomes super
;;(setq x-meta-keysym 'super)
;; muhenkan key (hyper) becomes meta
;;(setq x-hyper-keysym 'meta)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; crontabs handling
;; The idea: copy crontab entries to temp buffer, and
;; send back current buffer to "crontab"

(defun my/edit-root-crontab ()
  "Edit root crontab."
  (interactive)
  (with-editor-async-shell-command "crontab -e"))

(defvar my/crontabs-dir
  (concat my/emacs-tmpdir "/crontabs/" (number-to-string (user-uid)))
  "The directory in which to place the crontabs.")
;;(format "%s/emacs-cron" (or (getenv "TMPDIR") "/tmp") (user-uid)))

(defun my/edit-crontab ()
  "Edit current user crontab."
  (interactive)
  (setq cronBuf (get-buffer "br-crontab"))
  (when (not
         (and cronBuf
              (buffer-live-p cronBuf)))
    ;;(not cronBuf)
    ;;()
    (message "creating br-crontab")
    (setq cronBuf (get-buffer-create "br-crontab"))
    (set-buffer cronBuf)
    (crontab-mode)
    (insert (shell-command-to-string "crontab -l"))
    (set-buffer-modified-p nil)
    (goto-char (point-min)))
  (pop-to-buffer-same-window cronBuf))


(defun my/crontab-e ()
  "Run `crontab -e' in an Emacs buffer. Use 'kill-buffer' on crontab window to validate."
  (interactive)
  (with-editor-async-shell-command "crontab -e"))

(defun my/root-crontab-e ()
  "Run `crontab -e -u root' in an Emacs buffer. Use 'kill-buffer' on crontab window to validate."
  (interactive)
  (with-editor-async-shell-command "sudo -E crontab -e -u root"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; lisp tools
(defun my/append-to-list (list-var elements)
  "Append ELEMENTS to the end of LIST-VAR. Return new LIST-VAR value."
  (unless (consp elements)
    (error "ELEMENTS must be a list"))
  (let ((list (symbol-value list-var)))
    (if list
        (setcdr (last list) elements)
      (set list-var elements)))
  (symbol-value list-var))


(defun my/add-to-list (list-var elements &optional uniq)
  "Add ELEMENTS to the beginning LIST-VAR, remove duplicates if UNIQ is true.
Return new LIST-VAR value."
  (unless (consp elements)
    (error "ELEMENTS must be a list"))
  (set list-var (append elements (symbol-value list-var)))
  (and uniq
       (delete-dups (symbol-value list-var)))
  (symbol-value list-var))

;; don't remember what it was about. Saturday night wine idea ?
(defun my/str-replace-all (str alist)
  "Given an ALIST of the form '((a1 . a2)(b1 . b2)), will return a1 or b1 if STR equals a2 or b2."
  (if (null alist)
      str
    (let* ((elem (car alist))
           (lhs (car elem))
           (rhs (cdr elem)))
      ;;(message str)
      ;;(message lhs)
      ;;(message rhs)
      ;;(message "+++++++")
      (replace-regexp-in-string rhs lhs (my/str-replace-all str (cdr alist))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; buffer names
;; shorten tramp sudo
;;(my/add-to-list
;;  'directory-abbrev-alist
;;  '(("^root:/" . "/ssh:arwen:/home/br/www/cf.bodi/seven/")
;;     ("arwen:rebels:/" . "/ssh:arwen:/home/br/www/cf.bodi/rebels21/")
;;     ("arwen:strats:/" . "/ssh:arwen:/home/br/www/cf.bodi/strat-dom/")))

;; Buffer name in status bar
(require 'uniquify)
(setq uniquify-buffer-name-style 'forward         ; display finename as dir1/dir2/file
      uniquify-min-dir-content 0                  ; minimum # of dirs in name
      uniquify-strip-common-suffix t              ; strip dirs suffixes if conflict
      )

;; set main frame title
(set-frame-name "GNU Emacs")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ibuffer -- NOT USED: Using Helm
(defun my/ibuffer-hook ()
  "br ibuffer-hook."
  (interactive)
  (ibuffer-tramp-set-filter-groups-by-tramp-connection)
  (ibuffer-do-sort-by-alphabetic))

(define-ibuffer-column dirname
  (:name "Directory"
         :inline nil)
  (message (buffer-file-name buffer))
  (if (buffer-file-name buffer)
      (my/str-replace-all
       (file-name-directory
        (buffer-file-name buffer))
       directory-abbrev-alist)
    (or dired-directory
        "")))
;; (global-set-key (kbd "C-x C-b") 'ibuffer)
;; (global-set-key (kbd "C-x b") 'ibuffer)

;; original value
;; (setq ibuffer-formats
;;   '((mark modified read-only " "
;;       (name 18 18 :left :elide)
;;       " "
;;       (size 9 -1 :right)
;;       " "
;;       (mode 16 16 :left :elide)
;;       " " filename-and-process)
;;      (mark " "
;;        (name 16 -1)
;;        " " filename)))

(setq ibuffer-formats
      '((mark modified " "
              (name 18 18 :right :elide)
              " "
              (size 9 -1 :right)
              " "
              (mode 16 16 :left :elide)
              " " filename-and-process)
        (mark " "
              (name 16 -1)
              " " filename
              )
        (mark modified read-only " "
              (name 30 30 :left :elide)
              " "
              (size 9 -1 :right)
              " " dirname)
        ))

(add-hook 'ibuffer-hook 'my/ibuffer-hook)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; package auto update
(use-package auto-package-update
  :if (not (daemonp))
  :custom
  (auto-package-update-interval 7)                ; in days
  (auto-package-update-prompt-before-update t)
  (auto-package-update-delete-old-versions t)
  (auto-package-update-hide-results t)
  :config
  (auto-package-update-maybe))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; command-log-mode
;;(use-package command-log-mode
;;  :straight t
;;  :defer t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ggtags
(use-package ggtags
  :ensure t
  :diminish ggtags-mode
  :disabled t
  :defer t
  :init
  (setq ggtags-global-window-height 28
        ggtags-enable-navigation-keys nil)

  (after cc-mode (add-hook 'c-mode-common-hook #'ggtags-mode))

  :config
  (bind-keys :map ggtags-mode-map
             ("C-c g s" . ggtags-find-other-symbol)
             ("C-c g h" . ggtags-view-tag-history)
             ("C-c g r" . ggtags-find-reference)
             ("C-c g f" . ggtags-find-file)
             ("C-c g c" . ggtags-create-tags)
             ("C-c g u" . ggtags-update-tags)
             ("M-," 'pop-tag-mark)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; projectile
;; default config from developer
(use-package projectile
  ;;:diminish projectile-mode
  :diminish " prj"
  :ensure t
  :config
  ;;(define-key projectile-mode-map (kbd "s-p") 'projectile-command-map)
  ;;(define-key projectile-mode-map (kbd "s-p") 'projectile-command-map)
  (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map)
  (setq projectile-enable-caching t
        ;;projectile-indexing-method 'alien  ;; does not use ".projectile"
        projectile-indexing-method 'hybrid
        ;;projectile-indexing-method 'native
        projectile-completion-system 'default)
  (add-to-list 'projectile-globally-ignored-files "*.png")
  (projectile-mode +1))

;;   (add-to-list 'projectile-globally-ignored-files "node-modules")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; git
;; (use-package forge
;;   :after magit)
(use-package magit
  :ensure t
  :config
  (setq magit-delete-by-moving-to-trash nil
        magit-clone-default-directory "~/dev/")
  (magit-auto-revert-mode -1))


(use-package git-gutter
  :diminish
  :config
  (global-git-gutter-mode +1))

;; (use-package magithub
;;   :after magit
;;   ;;:ensure t
;;   :config
;;   (progn
;;     (magithub-feature-autoinject t)
;;     ;; (magithub-feature-autoinject '(commit-browse completion))
;;     (setq
;;      magithub-clone-default-directory "~/dev")))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; delight
(use-package autorevert
  :delight auto-revert-mode)
(use-package whole-line-or-region
  :delight whole-line-or-region-local-mode)
;;(use-package abbrev
;;  :delight abbrev-mode)
(use-package emacs
  :delight
  ;; (auto-fill-function " AF")
  (auto-fill-function)
  (abbrev-mode)
  (visual-line-mode))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; tramp
(setq tramp-default-method "ssh"                  ; faster than default scp
      enable-remote-dir-locals t
      tramp-verbose 1)
;; (customize-set-variable 'tramp-syntax 'simplified)

;; Emacs 29.1 ?
;;(autoload #'tramp-register-crypt-file-name-handler "tramp-crypt")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; conf mode
;; strangely ".cnf" is not here...
(use-package conf-mode
  :hook
  (conf-mode . my/conf-mode-hook)
  :mode
  (("\\.cnf\\'" . conf-mode)
   ("/auto\\." . conf-mode))
  :config
  (defun my/conf-mode-hook ()
    (message "calling my/conf-mode-hook")
    (setq-local comment-column 50)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ssh config
(use-package ssh-config-mode
  :ensure t
  :init
  (autoload 'ssh-config-mode "ssh-config-mode" t)
  :mode
  (("/\\.ssh/config\\'"     . ssh-config-mode)
   ("/sshd?_config\\'"      . ssh-config-mode)
   ("/known_hosts\\'"       . ssh-known-hosts-mode)
   ("/authorized_keys2?\\'" . ssh-authorized-keys-mode))
  :hook
  (ssh-config-mode . turn-on-font-lock))

;; (autoload 'ssh-config-mode "ssh-config-mode" t)
;; (add-to-list 'auto-mode-alist
;;              '("/\\.ssh/config\\'" . ssh-config-mode))
;; (add-to-list 'auto-mode-alist
;;              '("/sshd?_config\\'" . ssh-config-mode))
;; (add-to-list 'auto-mode-alist
;;              '("/knownhosts\\'" . ssh-known-hosts-mode))
;; (add-to-list 'auto-mode-alist
;;              '("/authorized_keys2?\\'" . ssh-authorized-keys-mode))
;; (add-hook 'ssh-config-mode-hook 'turn-on-font-lock)

;; following does not work
;;(set-default 'tramp-default-proxies-alist
;;  '("arwen" "root" "/ssh:arwen:"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; which-key
(use-package which-key
  :diminish which-key-mode
  :init
  (which-key-mode)
  :config
  (which-key-setup-side-window-right-bottom)
  (setq which-key-sort-order 'which-key-key-order-alpha
        which-key-side-window-max-width 0.33
        which-key-idle-delay 1))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; flycheck
(use-package flycheck
  :ensure t
  :init
  (require 'projectile)
  (global-flycheck-mode)
  :config
  (setq-default flycheck-sh-bash-args '("-O" "extglob")
                flycheck-disabled-checkers '(c/c++-clang c/c++-cppcheck c/c++-gcc))
  ;;(flycheck-add-mode 'sh-shellcheck 'bats-mode)

  :bind
  (("H-n" . flycheck-next-error)
   ("H-p" . flycheck-previous-error)
   ("H-l" . flycheck-list-errors)
   ("M-n" . flycheck-next-error)
   ("M-p" . flycheck-previous-error)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; subversion
;;(require 'psvn)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Japanese/iBus: works out of the box now
;; ibus-mode
;;(require 'ibus)
;; Turn on ibus-mode automatically after loading .emacs
;;(add-hook 'after-init-hook 'ibus-mode-on)
;; Use C-SPC for Set Mark command
;;(ibus-define-common-key ?\C-\s nil)
;; Use C-/ for Undo command
;;(ibus-define-common-key ?\C-/ nil)
;; Change cursor color depending on IBus status
;;(setq ibus-cursor-color '("red" "blue" "limegreen"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Some useful setups
;; mouse
;; does not change point when getting focus - DOES NOT WORK
;;x-mouse-click-focus-ignore-position t
;;focus-follows-mouse nil                ; must reflect WM settings
;;mouse-autoselect-window nil            ; pointer does not select window

(global-set-key (kbd "C-h c") 'describe-char)
(global-set-key (kbd "C-x 4 C-b") 'switch-to-buffer-other-window)

;; next example maps C-x C-x to the same as C-c
;; (global-set-key (kbd "C-x C-x") (lookup-key global-map (kbd "C-c")))

(setq inhibit-splash-screen t                     ; no spash screen
      column-number-mode t                        ; displays line/column positions
      kill-whole-line t                           ; C-k kills whole line

      ;; tab indents first, if indented, tries to autocomplete
      ;; TOO DANGEROUS (it completes without asking!)...
      ;; tab-always-indent t                    ; TAB always indent
      tab-always-indent 'complete
      completions-format 'vertical                ; sort completions vertically

      ;; Removed: Use smartparens instead.
      ;; show matching brace/paren
      ;;show-paren-mode t
      ;; style: parenthesis, expression, mixed
      ;;show-paren-style 'parenthesis

      sentence-end-double-space nil               ; who decided sentences should
                                                  ; end with two spaces ??
      ;; global-hl-line-sticky-flag t             ; highlight line
      tab-width 2                                 ; default tab width
      )

(setq-default indent-tabs-mode nil)               ; no tabs

(icomplete-mode 0)                                ; minibuffer completion
                                                  ; soooo sloooow

;; (global-hl-line-mode)                             ; line highlight

(delete-selection-mode 1)                         ; replace region when inserting text

;; fix mess with bidirectional (arabic/hebrew)
(setq-default bidi-display-reordering nil
              bidi-paragraph-direction 'left-to-right)

(setq display-time-24hr-format t)                 ; time format
(display-time-mode 0)                             ; disable time in the mode-line

(defalias 'yes-or-no-p 'y-or-n-p)                 ; just 'y' or 'n' instead of yes/no

(mouse-avoidance-mode 'exile)                     ; Avoid collision of mouse with point

;;(menu-bar-mode 0)                               ; Disable the menu bar
;;(put 'downcase-region 'disabled nil)            ; Enable downcase-region
;;(put 'upcase-region 'disabled nil)              ; Enable upcase-region
;;(global-subword-mode 1)                         ; Iterate through CamelCase words
;;(fringe-mode 0)                                 ; Disable fringes
(set-default-coding-systems 'utf-8)               ; default encoding - obviously utf-8

;; enable recursive minibuffer
(minibuffer-depth-indicate-mode)
(setq enable-recursive-minibuffers t)

;; copy from point to end of line (including '\n')
(defun my/mark-from-point-to-end-of-line ()
  "Copy text from point to end of line."
  (interactive)
  (set-mark (+ (line-end-position) 1))
  (kill-ring-save nil nil t))

(global-set-key (kbd "M-k") 'my/mark-from-point-to-end-of-line)
;; (global-set-key (kbd "C-k") 'kill-line)


;; minions: minor modes menu instead of (long) list on modeline
;;(use-package minions
;;  :config (minions-mode 1))

;;(defun caadr (a)
;;  (car(car(cdr a))))
;;(defun mouse-set-point-2 (event)
;;  (interactive "e")
;;  (mouse-minibuffer-check event)
;;  (let ((event-target-window (caadr event)))
;;    (if (eql event-target-window (frame-selected-window))
;;      (posn-set-point (event-end event))
;;      (set-frame-selected-window nil event-target-window))))
;;
;;(global-set-key [mouse-1] 'mouse-set-point-2)
;;
;;(global-unset-key [down-mouse-1])

;;(defadvice mouse-set-point (around cv/mouse-set-point (event) activate)
;; (let ((event-name (car event))
;; (event-target-window (posn-window (event-start event))))
;;    (if (and (eql 'down-mouse-1 event-name)
;;             (eql event-target-window (selected-window)))
;;        ad-do-it
;;      (select-window event-target-window))))

;; (defadvice mouse-drag-region (around cv/mouse-drag-region (event) activate)
;;   (let ((event-target-window (posn-window (event-start event))))
;; ;    (if (eql event-target-window (selected-window))
;; ;        ad-do-it
;; ;      (select-window event-target-window))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; local functions
(defun my/indent-whole-buffer ()
  "Indent whole buffer. TODO: indent comments."
  (interactive)
  ;; (delete-trailing-whitespace)
  ;; (untabify (point-min) (point-max))
  (indent-region (point-min) (point-max) nil))

(global-set-key (kbd "H-;") 'my/indent-whole-buffer)
(global-set-key (kbd "H-\\") 'my/indent-whole-buffer)

(defvar my/temp-buffer-count 0)

(defun my/make-temp-buffer (&optional mode)
  "Create new temporary buffer named '*temp-digit*' with MODE mode (default: text)."
  (interactive)
  (let ((tmp (format "*temp-%d*" my/temp-buffer-count))
        (dir (concat my/emacs-tmpdir "/tmpbufs/")))
    (switch-to-buffer tmp)
    (cd dir)
    (if mode
        (mode)
      (text-mode))
    (message "New temp buffer (%s) created." tmp))
  (setq my/temp-buffer-count (1+ my/temp-buffer-count)))

(global-set-key (kbd "C-c t") 'my/make-temp-buffer)

(defun my/write-visit-file ()
  "Write current buffer/region to file, and visit it."
  (interactive)
  (let ((thefile (read-file-name
                  "Copy/visit file: " nil nil nil)))
    (if (use-region-p)
        (write-region (region-beginning) (region-end) thefile nil nil nil t)
      (save-restriction
        (widen)
        (write-region (point-min) (point-max) thefile nil nil nil t)))
    (find-file-noselect thefile)))

(global-set-key (kbd "C-c w") 'my/write-visit-file)

(defun my/before-save ()
  "Remove trailing spaces, remove 'org-mode' results blocks."
  (delete-trailing-whitespace)
  (when (derived-mode-p 'org-mode)
    (org-babel-map-src-blocks nil (org-babel-remove-result))))

(add-hook 'before-save-hook 'my/before-save)
;;(global-set-key (kbd "C-c w") 'my/write-visit-file)

;;; from https://github.com/zilongshanren/prelude/blob/master/core/prelude-core.el
(defun my/delete-buffer-and-file ()
  "Kill the current buffer and deletes the file it is visiting."
  (interactive)
  (let ((filename (buffer-file-name)))
    (when filename
      (if (vc-backend filename)
          (vc-delete-file filename)
        (when (y-or-n-p (format "Are you sure you want to delete %s? " filename))
          (delete-file filename)
          (message "Deleted file %s" filename)
          (kill-buffer))))))

(global-set-key (kbd "s-d") 'my/delete-buffer-and-file)

;; from https://pages.sachachua.com/.emacs.d/Sacha.html
(defun my/smarter-move-beginning-of-line (arg)
  "Move point back to indentation of beginning of line.

Move point to the first non-whitespace character on this line.
If point is already there, move to the beginning of the line.
Effectively toggle between the first non-whitespace character and
the beginning of the line.

If ARG is not nil or 1, move forward ARG - 1 lines first.  If
point reaches the beginning or end of the buffer, stop there."
  (interactive "^p")
  (setq arg (or arg 1))

  ;; Move lines first
  (when (/= arg 1)
    (let ((line-move-visual nil))
      (forward-line (1- arg))))

  (let ((orig-point (point)))
    (back-to-indentation)
    (when (= orig-point (point))
      (move-beginning-of-line 1))))

;; remap C-a to `smarter-move-beginning-of-line'
(global-set-key [remap move-beginning-of-line]
                'my/smarter-move-beginning-of-line)

;;(defun my/upcase-word()
;; "Upcase current word."
;; (interactive)
;; (save-excursion
;;   (let* ((bounds (bounds-of-thing-at-point 'word))
;;         (beg (car bounds))
;;         (end (cdr bounds)))
;;     (upcase-region beg end))))

;; redefine upcase/downcase-word to really do it.
(defun my/upcase-word()
  "Upcase current word."
  (interactive)
  (save-excursion
    (beginning-of-thing 'word)
    (upcase-word 1)))

(defun my/downcase-word()
  "Downcase current word."
  (interactive)
  (save-excursion
    (beginning-of-thing 'word)
    (downcase-word 1)))

(global-set-key (kbd "M-u") 'my/upcase-word)
(global-set-key (kbd "M-l") 'my/downcase-word)

;; rewrite comment-kill to avoid filling kill-ring
;; From: https://emacs.stackexchange.com/a/5445/23591
;; https://emacs.stackexchange.com/questions/5441/function-to-delete-all-comments-from-a-buffer-without-moving-them-to-kill-ring
(defun my/comment-delete (arg)
  "Delete the first comment on this line, if any. Don't touch the kill ring.
With prefix ARG, delete comments on that many lines starting with this one."
  (interactive "P")
  (comment-normalize-vars)
  (dotimes (_i (prefix-numeric-value arg))
    (save-excursion
      (beginning-of-line)
      (let ((cs (comment-search-forward (line-end-position) t)))
        (when cs
          (goto-char cs)
          (skip-syntax-backward " ")
          (setq cs (point))
          (comment-forward)
          ;; (kill-region cs (if (bolp) (1- (point)) (point))) ; original
          (delete-region cs (if (bolp) (1- (point)) (point)))  ; change to delete-region
          (indent-according-to-mode))))
    (if arg (forward-line 1))))

(defun my/comment-delete-dwim (beg end arg)
  "Delete comments without touching the kill ring.
With active region, delete comments in region.  With prefix, delete comments
in whole buffer.  With neither, delete comments on current line."
  (interactive "r\nP")
  (let ((lines (cond (arg
                      (count-lines (point-min) (point-max)))
                     ((region-active-p)
                      (count-lines beg end)))))

    (save-excursion
      (when lines
        (goto-char (if arg (point-min) beg)))
      (my/comment-delete (or lines 1)))))

;; kill remove all consecutive blank lines (keep one only).
(defun my/single-blank-lines ()
  "Keep only one blank lines in buffer, keep one when multiple ones."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "\\(^[[:space:]\n]+\\)\n" nil t)
      (replace-match "\n"))))

(defun my/collapse-blank-lines (beg end)
  "Delete all consecutive `blank' lines in region or buffer, keeping one only."
  (interactive "r")
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "\\(^[[:space:]\n]+\\)\n" nil t)
      (replace-match "\n"))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; shell, eshell modes
;; will tell e-shell to run in visual mode
'(eshell-visual-commands
  (quote
   ("vi" "screen" "top" "less" "more")))

;; ignore duplicate input in shell-mode
(use-package shell
  :config
  (progn
    (setq comint-input-ignoredups t)))

;; https://www.emacswiki.org/emacs/SwitchingBuffers
(defun my/switch-buffers ()
  "Switch the buffers between the two last frames."
  (interactive)
  (let ((this-frame-buffer nil)
	      (other-frame-buffer nil))
    (setq this-frame-buffer (car (frame-parameter nil 'buffer-list)))
    (other-frame 1)
    (setq other-frame-buffer (car (frame-parameter nil 'buffer-list)))
    (switch-to-buffer this-frame-buffer)
    (other-frame 1)
    (switch-to-buffer other-frame-buffer)))

(defun my/switch-upper-window ()
  "Switch main window and upper one."
  (interactive)
  (window-swap-states my/main-window my/upper-window))
(defun my/switch-lower-window ()
  "Switch main window and lower one."
  (interactive)
  (window-swap-states my/main-window my/below-window))

(global-set-key (kbd "C-c u") 'my/switch-upper-window)
(global-set-key (kbd "C-c l") 'my/switch-lower-window)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; recent files
(require 'recentf)
(setq recentf-max-saved-items 20
      recentf-max-menu-items 10)
(recentf-mode)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; vc-mode modeline
;; inspired from:
;; https://emacs.stackexchange.com/questions/10955
(advice-add #'vc-git-mode-line-string :filter-return #'my/replace-git-status)
(defun my/replace-git-status (tstr)
  "Replace git `variable:vc-mode' string with a UTF8 symbol followed by TSTR."
  (let* ((tstr (replace-regexp-in-string "Git" "" tstr))
         (first-char (substring tstr 0 1))
         (rest-chars (substring tstr 1)))
    (cond
     ((string= ":" first-char)                    ; Modified
      (replace-regexp-in-string "^:" "⚡" tstr))
     ((string= "-" first-char)                    ; No change
      (replace-regexp-in-string "^-" "✔" tstr))
     ((string= "@" first-char)                    ; Added
      (replace-regexp-in-string "^@" "✚" tstr))
     (t tstr))))

(setf mode-line-modes
      (mapcar (lambda (item)
                (if (and (listp item)
                         (eq :propertize (car item))
                         (listp (cdr item))
                         (string= "" (car (cadr item)))
                         (eq 'mode-name (cadr (cadr item))))
                    (cl-list* (car item)
                           '(:eval (if (eq 'sh-mode major-mode)
                                       '("" sh-shell)
                                       '("" mode-name)))
                           (cddr item))
                    item))
              mode-line-modes))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; hippie
;; (setq hippie-expand-try-functions-list
;;       '(yas-hippie-try-expand
;;         try-expand-all-abbrevs
;;         try-complete-file-name-partially
;;         try-complete-file-name
;;         try-expand-dabbrev
;;         try-expand-dabbrev-from-kill
;;         try-expand-dabbrev-all-buffers
;;         try-expand-list
;;         try-expand-line
;;         try-complete-lisp-symbol-partially
;;         try-complete-lisp-symbol))

;; (use-package yasnippet
;;   :diminish yas-minor-mode
;;   :init (yas-global-mode)
;;   :config
;;   (progn
;;     (yas-global-mode)
;;     (add-hook 'hippie-expand-try-functions-list 'yas-hippie-try-expand)
;;     (setq yas-key-syntaxes '("w_" "w_." "^ "))
;;     ;;(setq yas-installed-snippets-dir (concat user-emacs-directory "yassnippet"))
;;     (setq yas-expand-only-for-last-commands nil)
;;     (yas-global-mode 1)
;;     (bind-key "\t" 'hippie-expand yas-minor-mode-map)
;;     (add-to-list 'yas-prompt-functions 'shk-yas/helm-prompt)))

;; (use-package yasnippet-snippets
;;   :after (yasnippet)
;;   :defer t
;;   :config
;;   (yas-global-mode 1))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; key Bindings
(global-set-key (kbd "<C-M-tab>") 'my/indent-whole-buffer)
;;(global-set-key (kbd "C-a") 'back-to-indentation)

;; https://github.com/technomancy/better-defaults/blob/master/better-defaults.el#L78
(global-set-key (kbd "M-/") 'hippie-expand)
(global-set-key (kbd "M-z") 'zap-up-to-char)
(global-set-key (kbd "C-s") 'isearch-forward-regexp)
(global-set-key (kbd "C-r") 'isearch-backward-regexp)
;; (global-set-key (kbd "C-M-s") 'isearch-forward) ; conflict with org
;; (global-set-key (kbd "C-M-r") 'isearch-backward)

;; goto-line/goto-char
;; (global-set-key (kbd "C-c g") 'goto-line)
;; (global-set-key (kbd "C-c c") 'goto-char)
(global-set-key (kbd "s-g g") 'goto-line)
(global-set-key (kbd "s-g c") 'goto-char)
(global-set-key (kbd "s-g s-g") 'goto-line)
(global-set-key (kbd "s-g s-c") 'goto-char)

(global-set-key (kbd "C-x w") 'compare-windows)

;; multiple cursors
(global-set-key (kbd "C->") 'mc/mark-next-like-this)
(global-set-key (kbd "C-<") 'mc/mark-previous-like-this)
(global-set-key (kbd "C-c C-<") 'mc/mark-all-like-this)
(global-set-key (kbd "C-S-<mouse-1>") 'mc/add-cursor-on-click)
(global-set-key (kbd "C-M-m") 'mc/mark-all-dwim)

(global-set-key (kbd "C-x g") 'magit-status)

;; (global-set-key (kbd "s-SPC") 'delete-blank-lines)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; define my own keymap (s-c)
;; first, define a keymap, with Super-c as prefix.
(defvar my/keys-mode-map (make-sparse-keymap)
  "Keymap for my/keys-mode.")

(defvar my/keys-mode-prefix-map (lookup-key global-map (kbd "s-c"))
  "Keymap for custom key bindings starting with s-c prefix.")

;; (define-key my/keys-mode-map (kbd "s-c") my/keys-mode-prefix-map)

(define-minor-mode my/keys-mode
  "A minor mode for custom key bindings."
  :lighter "s-c"
  :keymap 'my/keys-mode-map
  :global t)

(defun my/prioritize-keys
    (file &optional noerror nomessage nosuffix must-suffix)
  "Try to ensure that custom key bindings always have priority."
  (unless (eq (caar minor-mode-map-alist) 'my/keys-mode)
    (let ((my/keys-mode-map (assq 'my/keys-mode minor-mode-map-alist)))
      (assq-delete-all 'my/keys-mode minor-mode-map-alist)
      (add-to-list 'minor-mode-map-alist my/keys-mode-map))))

(advice-add 'load :after #'my/prioritize-keys)

;;(global-set-key (kbd "C-c t") #'make-temp-buffer)
;;(define-key my/keys-mode-prefix-map (kbd "r b") #'revert-buffer)
;;(define-key my/keys-mode-prefix-map (kbd "r b") 'revert-buffer)

;;(define-key ctl-x-map ";" 'indent-region)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; helm
;; Partially from http://pages.sachachua.com/.emacs.d/Sacha.html#org480d137
;; and http://tuhdo.github.io/helm-intro.html
(use-package helm
  :diminish helm-mode
  :init
  ;;(progn
  ;;  (require 'helm-config)
  ;;  (require 'helm-autoloads)
  (require 'pcomplete)
  (require 'helm-projectile)
  ;; (require 'tramp)
  (setq
   helm-candidate-number-limit 100
   ;; From https://gist.github.com/antifuchs/9238468
   helm-split-window-inside-p t                   ; open helm buffer in current window

   helm-idle-delay 0.0                            ; update fast sources immediately (doesn't).
   helm-input-idle-delay 0.01                     ; this actually updates things
                                                  ; reeeelatively quickly.
   helm-yas-display-key-on-candidate t
   helm-quick-update t
   helm-M-x-requires-pattern nil
   helm-ff-skip-boring-files t
   helm-ff-guess-fap-urls nil                     ; do not use ffap for URL at point

   helm-projectile-fuzzy-match nil

   helm-buffers-truncate-lines nil                ; truncate lines in buffers list
   helm-buffer-max-length nil                     ; buffer name length is longest one
   helm-prevent-escaping-from-minibuffer nil      ; allow escaping from minibuffer (C-o)
   helm-scroll-amount 8                           ; scroll 8 lines other window M-<NEXT>

   helm-ff-file-name-history-use-recentf t
   helm-echo-input-in-header-line t)              ; ??
  ;;)
  (helm-mode)
  (helm-projectile-on)
  ;;)
  :bind
  (("C-c h" . helm-mini)
   ("C-h a" . helm-apropos)
   ("C-x C-b" . helm-buffers-list)
   ("C-x C-f" . helm-find-files)
   ("C-x b" . helm-buffers-list)
   ("M-y" . helm-show-kill-ring)
   ("M-x" . helm-M-x)
   ("C-x c o" . helm-occur)
   ("C-x c s" . helm-swoop)
   ("C-x c y" . helm-yas-complete)
   ("C-x c Y" . helm-yas-create-snippet-on-region)
   ;;("C-x c b" . my/helm-do-grep-book-notes)
   ("C-x c SPC" . helm-all-mark-rings)
   :map helm-map
   ;; rebind tab/C-i to run persistent action
   ("<tab>" . helm-execute-persistent-action)
   ("C-i" . helm-execute-persistent-action)       ; make TAB works in terminal
   ("C-z" . helm-select-action)                   ; list actions using C-z

   ;; bookmarks

   ))

(use-package helm-swoop
  :bind
  (("M-i" . helm-swoop)
   ("M-I" . helm-swoop-back-to-last-point)
   ("C-c M-i" . helm-multi-swoop)
   ("C-x M-i" . helm-multi-swoop-all)
   )
  :config
  (progn
    (define-key isearch-mode-map (kbd "M-i") 'helm-swoop-from-isearch)
    (define-key helm-swoop-map (kbd "M-i") 'helm-multi-swoop-all-from-helm-swoop)))

(use-package helm-flycheck
  :requires (helm))

;; Turn off ido mode in case I enabled it accidentally
;; (ido-mode -1)

;; helm will be used to describe bindings
(use-package helm-descbinds
  :defer t
  :bind (("C-h b" . helm-descbinds)
         ("C-h w" . helm-descbinds)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; wc-mode
;;(require 'wc-mode)
;;(global-set-key (kbd "C-c C-w") 'wc-mode)
;;(setq wc-modeline-format "WC[%C/%tc]")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; kill/copy line if no region
(use-package whole-line-or-region
  :delight  whole-line-or-region-local-mode
  ;;:diminish whole-line-or-region-local-mode
  :commands
  (whole-line-or-region-global-mode)
  :init
  (whole-line-or-region-global-mode 1)
  ;; remove comment remaps
  (define-key whole-line-or-region-local-mode-map [remap comment-dwim] nil)
  (define-key whole-line-or-region-local-mode-map [remap comment-region] nil)
  (define-key whole-line-or-region-local-mode-map [remap uncomment-region] nil)
  :config
  ;;(whole-line-or-region-global-mode 1)
  ;; remove comment remaps
  ;;(define-key whole-line-or-region-local-mode-map [remap comment-dwim] nil)
  ;;(define-key whole-line-or-region-local-mode-map [remap comment-region] nil)
  ;;(define-key whole-line-or-region-local-mode-map [remap uncomment-region] nil)
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; undo tree
(use-package undo-tree
  :diminish undo-tree-mode
  :defer t
  :init
  (progn
    (defalias 'redo 'undo-tree-redo)
    (defalias 'undo 'undo-tree-undo)
    (global-undo-tree-mode 1))
  :config
  (progn
    (setq undo-tree-visualizer-timestamps t
          undo-tree-visualizer-diff t
          undo-tree-enable-undo-in-region t
          ;;undo-tree-auto-save-history t
          )
    (let ((undo-dir (concat my/emacs-tmpdir "/undo-tree/")))
      (setq undo-tree-history-directory-alist
            `(("." . ,undo-dir)))
      (unless (file-exists-p undo-dir)
        (make-directory undo-dir t)))))

;; useful to come back to working window after a buffer has popped up
;; C-c <left> to come back
(use-package winner
  :init (winner-mode 1))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; windows navigation
(use-package windmove
  :bind (("H-<right>" . windmove-right)
         ("H-<left>" . windmove-left)
         ("H-<up>"   . windmove-up)
         ("H-<down>" . windmove-down)
         ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; auto completion
(use-package company
  :diminish "Co"
  :defer t
  :bind
  (:map company-active-map
        ("RET" . nil)
        ;; ([return] . nil)
        ("TAB" . company-complete-selection)
        ;; ([tab] . company-complete-selection)
        ("<right>" . company-complete-common))
  :config
  ;; Too slow !
  ;; (global-company-mode 1)
  (setq-default
   company-idle-delay .2
   company-minimum-prefix-length 3
   company-require-match nil
   company-tooltip-align-annotations t)
  :hook
  (('prog-mode . 'company-mode)))

;;(add-to-list 'company-backends 'company-shell)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; dot-mode (vi-like redo)
;; repo: https://github.com/wyrickre/dot-mode
(use-package dot-mode
  :diminish
  :bind (("<insert>" . dot-mode-execute)
         ("C-M-<insert>" . dot-mode-override)     ; store next keystroke
         ("C-c <insert>" . dot-mode-copy-to-last-kbd-macro)

         ("C-." . dot-mode-execute)               ; default bindings below
         ("C-M-." . dot-mode-override)
         ("C-c ." . dot-mode-copy-to-last-kbd-macro))

  :init
  (global-dot-mode 1)                             ; enabled in all buffers
  (setq dot-mode-verbose nil
        dot-mode-ignore-undo t                    ; don't consider undos
        dot-mode-global-mode t))                  ; can redo in different buffer

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; change copy/kill region
;; from sacha
(defadvice kill-region (before slick-cut activate compile)
  "When called interactively with no active region, kill a single line instead."
  (interactive
   (if mark-active (list (region-beginning) (region-end))
     (list (line-beginning-position)
           (line-beginning-position 2)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; browse-url / webpaste (pastebin)
(use-package browse-url
  :ensure t
  :defer t
  :bind (( "C-c b" . browse-url )))

(use-package webpaste
  :ensure t

  :bind (("C-c P b" . webpaste-paste-buffer)
         ("C-c P r" . webpaste-paste-region))

  :hook (webpaste-return-url . my/webpaste-return-url-hook)

  :config
  (progn
    (setq webpaste-provider-priority  '("dpaste.org" "gist.github.com" "paste.mozilla.org"
                                        "dpaste.org" "ix.io")
          webpaste-paste-confirmation t           ; prompts before sending
          ;; nothing below: We do in webpaste-return-url hook
          webpaste-open-in-browser    nil         ; do not open in browser
          webpaste-add-to-killring    nil         ; do not add url to killring
          webpaste-paste-raw-text     nil         ; try to detect language
          ))
  (defun my/webpaste-return-url-hook (url)
    (message "Webpaste: %S" url)
    (browse-url-xdg-open url)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; markdown mode
;; https://github.com/jrblevin/markdown-mode/issues/578
(setq native-comp-deferred-compilation-deny-list '("markdown-mode\\.el$"))
;; inspired from: https://github.com/zaeph/.emacs.d/blob/master/init.el
;; doc: https://leanpub.com/markdown-mode/read
(use-package markdown-mode
  :ensure t
  :init
  ;;(setq markdown-command "pandoc"
  ;;      markdown-command-needs-filename t)
  ;; for pandoc:
  (setq markdown-command
        (concat "pandoc"
                " --quiet"
                " --from=markdown --to=html"
                " --standalone --mathjax --highlight-style=pygments"))
        ;; https://github.com/jrblevin/markdown-mode/issues/578
        ;; (setq markdown-nested-imenu-heading-index nil)
  :mode
  (("\\.md\\'" . gfm-mode)
   ("\\.markdown\\'" . gfm-mode))
  :hook
  ((markdown-mode . visual-line-mode)
   (markdown-mode . flyspell-mode)))

;; markdown-toc mode
;; (require 'dash)
;; drop all H1 titles
(custom-set-variables
 '(markdown-toc-user-toc-structure-manipulation-fn
   (lambda (toc-structure)
     (--map (-let (((level . label) it))
              (cons (- level 1) label))
            (cdr toc-structure)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; text mode
;; for some reason, I was not able to "use-package".
;;(use-package text-mode
;;  :preface (provide 'text-mode)
;;  :ensure nil
;;  :mode
;;  (("\\.txt\\'" . text-mode)
;;   ("\\.text\\'" . text-mode))
;;  :config
;;  (progn
;;    (message "I am in text-mode- use-package")
;;    (setq visual-line-fringe-indicators '(nil right-curly-arrow))
;;    (turn-on-visual-line-mode)                    ; enable visual-line
;;    (auto-fill-mode -1))                          ; disable auto-fill
;;  )

(defun my/text-mode-hook ()
  "X br text mode hook."
  (setq visual-line-fringe-indicators '(nil right-curly-arrow))
  (turn-on-visual-line-mode)                    ; enable visual-line
  (auto-fill-mode -1))                          ; disable auto-fill

(add-hook 'text-mode-hook 'my/text-mode-hook)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; makefile mode
(defun my/makefile-mode-hook ()
  "X br makefile mode hook."
  ;; (message "entering Makefile-mode")
  (setq indent-tabs-mode t
        tab-width 8
        comment-column 60))

(add-hook 'makefile-mode-hook 'my/makefile-mode-hook)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; org mode
;; mediawiki export
(require 'ox-mediawiki)
(require 'org-tempo)
;;(require 'ox-extra)

(defun my/org-mode-hook ()
  "X br org-mode-hook."
  (interactive)
  (setq fill-column 78
        ;; show structure at startup
        org-startup-folded 'content
        truncate-lines nil
        org-src-fontify-natively t                ; nil: disable coloring in code blocks
        org-src-preserve-indentation  t
        org-src-tab-acts-natively t
        org-src-window-setup 'current-window
        org-src-block-faces nil
        ;; org-descriptive-links nil
        org-link-descriptive nil
        ;; no TOC by default in export
        ;; org-export-with-toc nil
        ;;org-html-head-include-default-style nil
        ;;org-src-block-faces '(("emacs-lisp" (:background "#EEE2FF"))
        ;;                      ("python" (:background "#E5FFB8")))
        org-todo-keywords '((sequence "TODO" "STARTED" "WAITING"
                                      ;; "REVIEW(r)" "SUBMIT(m)"
                                      "|" "DONE" "CANCELED"))
        ;;org-todo-keyword-faces '(("TODO"     :foreground "red"       :weight bold)
        ;;                         ("STARTED"  :foreground "cyan"      :weight bold)
        ;;                         ("WAITING"  :foreground "gold"      :weight bold)
        ;;                         ("DONE"     :foreground "sea green" :weight bold)
        ;;                         ("LATER"    :foreground "dark red"  :weight bold)
        ;;                         ("CANCELED" :foreground "dark red"  :weight bold))

        org-support-shift-select t
        org-indent-mode-turns-on-hiding-stars nil
        org-export-allow-bind-keywords t
        visual-line-fringe-indicators '(nil right-curly-arrow)
        )
  ;; change "=" (verbatim) to be different from "~" (code)
  (push '(verbatim . "<code class='verbatim'>%s</code>") org-html-text-markup-alist)
  ;; to allow hiding a headline with :ignore: tag
  ;;(ox-extras-activate '(ignore-headlines))
  ;; visual-line mode
  (org-indent-mode)
  (visual-line-mode)
  ;;(setq visual-line-fringe-indicators '(nil right-curly-arrow))
  (auto-fill-mode 1)
  (define-key org-mode-map
    (kbd "C-c l") 'my/org-toggle-link-display)
  (define-key org-mode-map
    (kbd "C-c x") 'org-mw-export-as-mediawiki))

(defun my/org-toggle-link-display ()
  "Toggle the literal or descriptive display of links."
  (interactive)
  (if org-link-descriptive
      (progn (remove-from-invisibility-spec '(org-link))
             (org-restart-font-lock)
             (setq org-link-descriptive nil))
    (progn (add-to-invisibility-spec '(org-link))
           (org-restart-font-lock)
           (setq org-link-descriptive t))))

(add-hook 'org-mode-hook 'my/org-mode-hook)

;; inspired from https://orgmode.org/guide/Introduction.html
(global-set-key (kbd "H-c l") 'org-store-link)
(global-set-key (kbd "H-c a") 'org-agenda)
(global-set-key (kbd "H-c c") 'org-capture)

;; babel languages
(org-babel-do-load-languages
 'org-babel-load-languages
 '((calc . t)
   (emacs-lisp . t)
   (sql . t)
   (perl . t)
   (shell . t)))

;;   (plantuml . t)
;;   (python . t)
;;   (ruby . t)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; vimrc mode
(add-hook
 'vimrc-mode-hook
 (lambda ()
   (setq indent-tabs-mode nil           ; do not use tabs
         comment-column 50)))

(require 'vimrc-mode)
(add-to-list 'auto-mode-alist '("\\.vim\\(rc\\)?\\'" . vimrc-mode))
;;(add-to-list 'auto-mode-alikst '(".vim\\(rc\\)?$" . vimrc-mode))
;;(add-to-list 'auto-mode-alist '(".vim\\(rc\\)?" . vimrc-mode))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; perl (cperl) mode
(defalias 'perl-mode 'cperl-mode)
(add-hook
 'perl-lisp-mode-hook
 (lambda ()
   (setq indent-tabs-mode nil                    ; do not use tabs
         tab-width 2)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Cobol mode
(setq auto-mode-alist
      (append
       '(("\\.cob\\'" . cobol-mode)
         ("\\.cbl\\'" . cobol-mode)
         ("\\.cpy\\'" . cobol-mode))
       auto-mode-alist))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; C mode
(defun my/indent-maybe-cpp-directive ()
  "Indent c pre-processor line according to my own standard."
  (interactive)
  (save-excursion
    (back-to-indentation)
    (when (looking-at "#")
      (delete-char 1)
      (indent-according-to-mode)
      (beginning-of-line)
      (when (looking-at " ")
        (delete-char 1))
      (insert "#")
      (beginning-of-line))))

(defun my/c-style ()
  "Some general C setup."
  (interactive)
  (c-set-style "k&r")
  (c-set-offset 'knr-argdecl-intro '+)
  (c-set-offset 'case-label '+)
  (bind-keys :map c-mode-map
             ("s-;" . my/indent-maybe-cpp-directive)
             ("<f5>" . projectile-compile-project)
             ("F" . self-insert-command))

  (auto-complete-mode 0)
  ;;(yas-minor-mode 1)
  (flycheck-mode 1)
  ;;(ggtags-mode 1)
  (show-smartparens-mode 1)
  (company-mode 1)
  (auto-fill-mode 1)
  (setq company-backends '((company-dabbrev-code company-gtags))
        c-basic-offset 4
        comment-column 50
        fill-column 100
        c-ignore-auto-fill '(string cpp)
        comment-auto-fill-only-comments nil
        comment-style 'extra-line))

(add-hook 'c-mode-hook 'my/c-style)

;;;;;;;;;;;;; linux kernel style
(defun c-lineup-arglist-tabs-only (ignored)
  "Line up argument lists by tabs, not spaces. fuck flycheck IGNORED."
  (let* ((anchor (c-langelem-pos c-syntactic-element))
         (column (c-langelem-2nd-pos c-syntactic-element))
         (offset (- (1+ column) anchor))
         (steps (floor offset c-basic-offset)))
    (* (max steps 1)
       c-basic-offset)))

;; Eudyptula challenge
(defvar my/eudyptula-dir
  (expand-file-name "~/dev/eudyptula")
  "Eudyptula challenge directory.")
(defvar my/kernel-dir
  (concat my/eudyptula-dir "/linux")
  "Kernel tree within Eudyptula challenge.")
(defvar my/kernel-scripts-dir
  (concat my/kernel-dir "/scripts")
  "Scripts dir within Eudyptula challenge's kernel directory.")
(defvar my/kernel-include-dirs
  (list (concat my/kernel-dir "/include")
        (concat my/kernel-dir "/arch/x86/include")
        (concat my/kernel-dir "/arch/x86/include/generated"))
  "Kernel include directory.")
(defvar my/running-kernel-include-dirs
  (let ((kernel (concat "/lib/modules/"
                        (string-trim (shell-command-to-string "uname -r"))
                        "/build")))
    (list (concat kernel "/include")
          (concat kernel "/arch/x86/include")))
  "Running kernel include directory.")

;; https://stackoverflow.com/questions/29709967/using-flycheck-flymake-on-kernel-source-tree
(flycheck-define-checker my/flycheck-kernel-checker
  "Linux source checker"
  :command
  (
   "make" "C=1" "-C" (eval my/kernel-dir)
   (eval (concat "M="
                 (file-name-directory buffer-file-name)))
   (eval (concat (file-name-sans-extension (file-name-nondirectory buffer-file-name))
                 ".o"))
   )
  :error-patterns
  ((error line-start
          (message "In file included from") " " (file-name) ":" line ":"
          column ":"
          line-end)
   (info line-start (file-name) ":" line ":" column
         ": note: " (message) line-end)
   (warning line-start (file-name) ":" line ":" column
            ": warning: " (message) line-end)
   (error line-start (file-name) ":" line ":" column
          ": " (or "fatal error" "error") ": " (message) line-end))
  :modes (c-mode c++-mode))
;; :error-filter
;; (lambda (errors)
;;   (let ((errors (flycheck-sanitize-errors errors)))
;;     (dolist (err errors)
;;       (let* ((fn (flycheck-error-filename err))
;;              ;; flycheck-fix-error-filename converted to absolute, revert
;;              (rn0 (file-relative-name fn default-directory))
;;              ;; make absolute relative to "make -C dir"
;;              (rn1 (expand-file-name rn0 my/kernel-dir))
;;              ;; relative to source
;;              (ef (file-relative-name rn1 default-directory))
;;              )
;;         (setf (flycheck-error-filename err) ef)
;;         )))
;;   errors)

;; (defun my/flycheck-mode-hook ()
;;   "Flycheck mode hook."
;;   (setq flycheck-linux-makefile my/kernel-dir)
;;   (flycheck-select-checker 'my/flycheck-kernel-checker)
;;   )

(dir-locals-set-class-variables
 'linux-kernel
 '((c-mode
    . ((c-basic-offset . 8)
       (c-label-minimum-indentation . 0)
       (c-offsets-alist
        . ((arglist-close         . c-lineup-arglist)
           (arglist-cont-nonempty . (c-lineup-gcc-asm-reg c-lineup-arglist))
           (arglist-intro         . +)
           (brace-list-intro      . +)
           (c                     . c-lineup-C-comments)
           (case-label            . 0)
           (comment-intro         . c-lineup-comment)
           (cpp-define-intro      . +)
           (cpp-macro             . -1000)
           (cpp-macro-cont        . +)
           (defun-block-intro     . +)
           (else-clause           . 0)
           (func-decl-cont        . +)
           (inclass               . +)
           (inher-cont            . c-lineup-multi-inher)
           (knr-argdecl-intro     . 0)
           (label                 . -1000)
           (statement             . 0)
           (statement-block-intro . +)
           (statement-case-intro  . +)
           (statement-cont        . +)
           (substatement          . +)))
       (indent-tabs-mode . t)
       (show-trailing-whitespace . t)
       (eval . (flycheck-select-checker 'my/flycheck-kernel-checker)
             ;; (setq flycheck-gcc-include-path my/kernel-include-dirs)
             )
       ))))

;; (setq flycheck-checkers (delete 'c/c++-clang flycheck-checkers))

;; linux kernel style
(defun my/maybe-linux-style ()
  "Apply linux kernel style when buffer path contain 'eudyptula'."
  (interactive)
  (when (and buffer-file-name
             (string-match "eudyptula" buffer-file-name))
    (setq flycheck-checkers (delete '(c/c++-clang c/c++-cppcheck) flycheck-checkers)
          flycheck-gcc-include-path my/kernel-include-dirs
          flycheck-clang-include-path my/kernel-include-dirs)))

;; (add-hook 'c-mode-hook 'my/maybe-linux-style)

(dir-locals-set-directory-class my/eudyptula-dir 'linux-kernel)

;; (add-hook 'flycheck-mode-hook 'my/flycheck-mode-hook)

(defun my/checkpatch (file &optional nointree noterse nofilemode)
  "Run checkpatch on FILE, or current buffer if FILE is nil.

If NOTERSE is t, a full report will be done. If NOFILEMODE is t, FILE
is supposed to be a patchfile (otherwise a regular source file).
If NOINTREE is t, check will be done on file outside `my/kernel-dir'"
  ;;(interactive)
  (interactive "FFile name (default: current buffer): ")
  (let* ((ckp   (concat my/kernel-scripts-dir "checkpatch.pl "))
         (fn    (or file (buffer-file-name)))
         (terse (if noterse "" "--terse "))
         (tree  (if nointree "--notree " ""))
         (fm    (if nofilemode "" "--file "))
         (opt   (concat "--emacs --color=never " terse tree fm)))
    (setq my/compile (concat ckp opt fn))
    (compile (concat ckp opt fn))))

(defun my/checkstaging ()
  "Zobi."
  (interactive)
  (my/checkpatch "drivers/staging/*/*.[ch]"))

;; add kernel includes
;;(string-trim (shell-command-to-string "uname -r"))

;; to avoid "free variable" warnings at compile
;; (eval-when-compile
;;  (require 'cc-defs))

;; (add-hook 'c-mode-common-hook
;;           (lambda ()
;;             ;; Add kernel style
;;             (c-add-style
;;              "linux-tabs-only"
;;              '("linux" (c-offsets-alist
;;                         (arglist-cont-nonempty
;;                          c-lineup-gcc-asm-reg
;;                          c-lineup-arglist-tabs-only))))))

;; linux kernel style
;; (defun maybe-linux-style ()
;;   "Apply linux kernel style when buffer path contains 'linux'."
;;   (interactive)
;;   (when (and buffer-file-name
;;              (string-match "linux" buffer-file-name))
;;     (c-set-style "linux")))

;; (add-hook 'c-mode-hook 'maybe-linux-style)

;; ;; (defun br-linux-style ()
;; ;;   "Line up argument lists by tabs, not spaces"
;; ;;   (interactive)
;; ;;   (setq indent-tabs-mode t)
;; ;;   (setq show-trailing-whitespace t)
;; ;;   (c-set-style "linux-tabs-only"))

;; (add-hook 'c-mode-hook
;;           (lambda ()
;;             (let ((filename (buffer-file-name)))
;;               ;; Enable kernel mode for the appropriate files
;;               (when (and filename
;;                          (or (string-match "dev/eudyptula" filename)
;;                              (string-match "dev/kernel" filename)))
;;                          ;;(string-match (expand-file-name "~/dev/Eudyptula")
;;                          ;; (string-match "Eudyptula" buffer-file-name))
;;                          ;;(cl-search "eudyptula" buffer-file-name))
;;                 ;;(setq indent-tabs-mode t)
;;                 (setq show-trailing-whitespace t)
;;                 (c-set-style "linux-tabs-only")))))

;; exercism C style
(defvar my/exercism-dir
  (expand-file-name "~/dev/exercism-tracks/")
  "Exercism challenge directory.")

(dir-locals-set-class-variables
 'exercism-style
 '((c-mode
    . ((c-basic-offset . 3)
       (c-label-minimum-indentation . 0)
       (c-offsets-alist
        . ((arglist-close         . c-lineup-arglist)
           (arglist-cont-nonempty . (c-lineup-gcc-asm-reg c-lineup-arglist))
           (arglist-intro         . +)
           (brace-list-intro      . +)
           (c                     . c-lineup-C-comments)
           (case-label            . 0)
           (comment-intro         . c-lineup-comment)
           (cpp-define-intro      . +)
           (cpp-macro             . -1000)
           (cpp-macro-cont        . +)
           (defun-block-intro     . +)
           (else-clause           . 0)
           (func-decl-cont        . +)
           (inclass               . +)
           (inher-cont            . c-lineup-multi-inher)
           (knr-argdecl-intro     . 0)
           (label                 . -1000)
           (statement             . 0)
           (statement-block-intro . +)
           (statement-case-intro  . +)
           (statement-cont        . +)
           (substatement          . +)))
       (indent-tabs-mode . nil)
       (fill-column . 80)
       (show-trailing-whitespace . t)
       (comment-column . 33)
       ;;(eval . (flycheck-select-checker 'my/flycheck-kernel-checker)
       ;; (setq flycheck-gcc-include-path my/kernel-include-dirs)
       ;;)
       ))))

(dir-locals-set-directory-class my/exercism-dir 'exercism-style)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; emacs lisp mode
(defun my/emacs-lisp-mode-hook ()
  "My Emacs Lisp mode hook."
  (interactive)
  (setq
   indent-tabs-mode            nil
   tab-width                   2
   lisp-body-indent            2
   ;; lisp-indent-offset          2

   comment-column              50
   fill-column                 128
   comment-auto-fill-only-comments t
   auto-fill-mode              t)

  (define-key emacs-lisp-mode-map
    (kbd "<enter>") 'reindent-then-newline-and-indent))

(add-hook
 'lisp-interaction-mode-hook
 (lambda ()
   (define-key lisp-interaction-mode-map
     (kbd "<C-enter>") 'eval-last-sexp)))

(add-hook
 'lisp-mode-hook
 (lambda ()
   (outline-minor-mode)
   (make-local-variable 'outline-regexp)
   (setq outline-regexp "^(.*")
   (ignore-errors (semantic-default-elisp-setup))
   (set (make-local-variable lisp-indent-function)
        'common-lisp-indent-function)))

(add-hook 'emacs-lisp-mode-hook 'my/emacs-lisp-mode-hook)


;; eldoc - provides minibuffer hints when working in elisp
(use-package "eldoc"
  :diminish eldoc-mode
  :commands turn-on-eldoc-mode
  :defer t
  :init
  (progn
    (add-hook 'emacs-lisp-mode-hook 'turn-on-eldoc-mode)
    (add-hook 'lisp-interaction-mode-hook 'turn-on-eldoc-mode)
    (add-hook 'ielm-mode-hook 'turn-on-eldoc-mode)))

;; aggressive indent
;; (add-hook 'emacs-lisp-mode-hook #'aggressive-indent-mode)
;; (add-hook 'css-mode-hook #'aggressive-indent-mode)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  lisp interaction mode


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; php mode
;;TODO (use-package php
;;
;;  )
(defun my/php-send-buffer ()
  "Send current buffer to PHP for execution.
The output will appear in the buffer *PHP*."
  (interactive)
  (php-send-region (if (string-match "\\(^#!.*$\\)" (buffer-string) nil)
                       (+ 1 (point-min) (match-end 1))
                     (point-min))
                   (point-max)))

(defun my/php-mode-hook ()
  "Hook for php-mode."
  (interactive)
  (setq indent-tabs-mode nil
        c-basic-offset   4
        comment-column   50
        fill-column      128
        comment-auto-fill-only-comments t
        auto-fill-mode t
        php-mode-template-compatibility nil)
  ;;php-executable "php -f")
  (paren-toggle-open-paren-context 1)
  (php-enable-default-coding-style)
  (c-set-offset 'case-label '+)
  (define-key php-mode-map
    (kbd "C-c f") 'php-search-documentation)
  (define-key php-mode-map
    (kbd "C-c r") 'my/php-send-buffer)
  ;;(auto-complete-mode t)
  ;;(require 'ac-php)
  ;;(setq ac-sources '(ac-source-php))
  (require 'company-php)
  (set (make-local-variable 'company-backends)
       '((company-ac-php-backend company-dabbrev-code)
         company-capf company-files))
  )

(use-package phpactor :ensure t)
(use-package company-phpactor :ensure t)
;;(setq lsp-clients-php-server-command '("phpactor" "language-server"))

;; Add lsp or lsp-deferred function call to functions for your php-mode customization
;; https://phpactor.readthedocs.io/en/master/lsp/emacs.html
(defun init-php-mode ()
  "Zobi."
  (lsp-deferred))

(with-eval-after-load 'php-mode
  ;; If phpactor command is not installed as global, write the full path
  ;; (custom-set-variables '(lsp-phpactor-path "/path/to/phpactor"))
  (add-hook 'php-mode-hook #'init-php-mode))

;;(company-mode t)
;;(require 'company-php)
;;(set (make-local-variable 'company-backends)
;;     '((company-ac-php-backend company-dabbrev-code)
;;       company-capf company-files)))

;; (add-to-list 'company-backends 'company-ac-php-backend ))

(add-hook 'php-mode-hook 'my/php-mode-hook)

;; autoload php-html-helper-mode
;;(autoload 'php-html-helper-mode "html-helper-mode" "html-helper-mode" t)
;;(add-to-list 'auto-mode-alist '("\\.inc\\'" . php-html-helper-mode))
;;(add-to-list 'auto-mode-alist '("\\.html\\'" . html-mode))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; go mode
(add-hook
 'go-mode-hook
 (lambda ()
   ;; (setq-default)
   (setq
    indent-tabs-mode nil
    tab-width 2
    standard-indent 2)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; js mode
(add-hook
 'js-mode-hook
 (lambda ()
   (setq
    indent-tabs-mode nil
    js-indent-level 3
    ;; tab-width 3
    c-basic-offset 3
    comment-column 50
    fill-column 128
    comment-auto-fill-only-comments t
    auto-fill-mode t)
   (define-key js-mode-map
     (kbd "<kp-enter>") 'reindent-then-newline-and-indent)))

(use-package json-mode
  :defer t
  :mode "\\.json\\'"
  :config
  (setq indent-tabs-mode nil
        js-indent-level 2)
  ;; https://github.com/joshwnj/json-mode/issues/72
  (setq-default json-mode-syntax-table
                (let ((st (make-syntax-table)))
                  ;; Objects
                  (modify-syntax-entry ?\{ "(}" st)
                  (modify-syntax-entry ?\} "){" st)
                  ;; Arrays
                  (modify-syntax-entry ?\[ "(]" st)
                  (modify-syntax-entry ?\] ")[" st)
                  ;; Strings
                  (modify-syntax-entry ?\" "\"" st)
                  ;; Comments
                  (modify-syntax-entry ?\n ">" st)
                  st))
  )
;;(add-hook
;; 'json-mode-hook
;; (lambda ()
;;   (setq
;;    indent-tabs-mode nil
;;    js-indent-level 2)
;;   ))

;;(add-to-list 'auto-mode-alist '("\\.js\\'" . my/js-mode-hook))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; hideshow mode
(use-package hideshow
  :ensure nil
  ;;:diminish hideshow
  :hook
  ((json-mode .  hs-minor-mode)
   (web-mode . hs-minor-mode)
   (php-mode . hs-minor-mode)
   (prog-mode . hs-minor-mode)
   (lisp-mode . hs-minor-mode))
  :bind
  (:map hs-minor-mode-map
        ("H-<tab>" . hs-toggle-hiding)
        ("H-h" . hs-hide-block)
        ("H-s" . hs-show-block)
        ("H-l" . hs-hide-level)
        ("H-a" . hs-show-all)
        ("H-t" . hs-hide-all))
  ;; :commands hs-toggle-hiding
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; handle large buffers
(defun my/dabbrev-friend-buffer (other-buffer)
  "Exclude very large buffers from dabbrev."
  (< (buffer-size other-buffer) (* 1 1024 1024)))

(setq dabbrev-friend-buffer-function 'my/dabbrev-friend-buffer)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; multiple cursors
(use-package multiple-cursors
  :ensure t
  :bind (("C-S-C C-S-C" . mc/edit-lines)
         ("H-SPC" . set-rectangular-region-anchor)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; sql mode
;;(use-package sql-indent :defer t)
;;(use-package sqlup-mode :defer t)

(use-package sql
  :ensure t
  :init
  ;;(setq sql-product 'mysql
  ;; sqlup-mode t
  ;;(toggle-truncate-lines 1)

  ;; connect to a predefined connection (sql-connection-alist)
  (defun my/sql-connect-preset (name)
    "Connect to a predefined SQL connection listed in `sql-connection-alist'"
    (eval `(let ,(cdr (assoc name sql-connection-alist))
             (flet ((sql-get-login (&rest what)))
               (sql-product-interactive sql-product)))))

  (defun my/sql-mode-hook ()
    "Hook for SQL mode."
    (toggle-truncate-lines 1)
    (message "br sql hook"))

  (add-hook 'sql-interactive-mode-hook
            (lambda ()
              (toggle-truncate-lines t)
              ;;(my/sql-connect-preset)
              (setq comint-move-point-for-output "all")))
  ;; (add-hook 'sql-interactive-mode-hook #'my/sql-mode-hook)
  (font-lock-add-keywords 'sql-mode '(("greatest" . font-lock-builtin-face)
                                      ("least" . font-lock-builtin-face)))
  :config
  (toggle-truncate-lines 1)
  (sql-set-product-feature 'mysql :prompt-regexp
                           "^\\(MariaDB\\|MySQL\\) \\[[_a-zA-Z]*\\]> ")

  :hook
  ((sql-mode . sqlind-minor-mode)
   (sql-mode . sqlup-mode))
  ;;(sql . my/sql-mode-hook)
  ;;(sql-interactive-mode . #'my/sql-mode-hook))
  ;;(sql-interactive-mode . (toggle-truncate-lines 1)))
  )

;;(use-package sqlup-mode
;;:ensure
;;:after sql
;;:init
;;(local-set-key (kbd "C-c u") 'sqlup-capitalize-keywords-in-region)
;;:hook
;;(add-hook 'sql-mode-hook #'sqlup-mode)
;;:config
;;(add-to-list 'sqlup-blacklist "name")           ; I use "name" a lot.
;; )

;;(use-package sql-indent
;;:after (sql-mode)
;;:after sql
;;:init
;;:hook
;;((sql . sqlind-minor-mode)))

;; (use-package sql-interactive-mode
;;   :ensure
;;   :after sql
;;   :config
;;   (toggle-truncate-lines 0))

;;(add-hook 'sql-mode-hook #'my/sql-mode-hook)
;; When connected to a server within Emacs
;;(add-hook 'sql-interactive-mode-hook #'my/sql-mode-hook)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; html/xml mode
(add-hook
 'html-mode-hook
 (lambda ()
   (setq
    indent-tabs-mode nil
    ;; tab-width 2
    sgml-basic-offset 2)))

(defun xml-reformat ()
  "Reformats xml to make it readable (respects current selection)."
  (interactive)
  (save-excursion
    (let ((beg (point-min))
          (end (point-max)))
      (if (and mark-active transient-mark-mode)
          (progn
            (setq beg (min (point) (mark)))
            (setq end (max (point) (mark))))
        (widen))
      (setq end (copy-marker end t))
      (goto-char beg)
      (while (re-search-forward ">\\s-*<" end t)
        (replace-match ">\n<" t t))
      (goto-char beg)
      (indent-region beg end nil))))

(add-hook
 'nxml-mode-hook
 (lambda ()
   (setq
    indent-tabs-mode nil
    ;; tab-width 2
    sgml-basic-offset 2)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; web mode
(use-package web-mode
  ;;:demand t
  :init
  (require 'php-mode)
  ;; (setq web-mode-enable-current-column-highlight t)
  (make-local-variable 'web-mode-code-indent-offset)
  (make-local-variable 'web-mode-markup-indent-offset)
  (make-local-variable 'web-mode-css-indent-offset)
  :mode
  ("\\.phtml\\'" "\\.html?\\'")
  ;;(add-to-list 'auto-mode-alist '("\\.phtml\\'" . web-mode))
  ;;(add-to-list 'auto-mode-alist '("\\.html?\\'" . web-mode))

  :bind
  (:map web-mode-map
        ("C-c f" . php-search-documentation))

  ;;:hook
  ;;  (('web-mode . php-mode))

  :config
  (require 'company-php)
  (set (make-local-variable 'company-backends)
       '((company-ac-php-backend company-dabbrev-code)
         company-capf company-files))
  (setq web-mode-markup-indent-offset 2
        web-mode-enable-auto-pairing nil     ; overrides smartparens
        web-mode-css-indent-offset 2
        web-mode-code-indent-offset 4
        web-mode-style-padding 1
        web-mode-script-padding 1
        web-mode-block-padding 2
        web-mode-enable-current-element-highlight t
        web-mode-enable-current-column-highlight t
        web-mode-sql-indent-offset 2
        web-mode-engines-alist '(("php"    . "\\.phtml\\'")))
  (setq web-mode-ac-sources-alist
        '(("css" . (ac-source-css-property))
          ("html" . (ac-source-words-in-buffer ac-source-abbrev)))
        )
  ;;)
  ;;(add-hook 'web-mode-hook 'my/web-mode-hook)
  ;;(eval-after-load "web-mode"
  ;;'
  ;;(set-face-background 'web-mode-current-element-highlight-face "red")
  (set-face-foreground 'web-mode-current-element-highlight-face "chartreuse")

  )

;; (defun my/web-mode-hook ()
;;   "br web-mode-hook."
;;   (interactive)
;;   (setq indent-tabs-mode nil
;;         tab-width 2
;;         ;; web-mode-attr-indent-offset 2
;;         web-mode-enable-auto-pairing nil
;;         web-mode-code-indent-offset 2                 ; for php, js, etc...
;;         web-mode-css-indent-offset 2
;;         web-mode-markup-indent-offset 2               ; for html
;;         web-mode-sql-indent-offset 2
;;         web-mode-enable-current-column-highlight t
;;         )
;;   (define-key web-mode-map
;;     (kbd "C-c f") 'php-search-documentation)
;;   (paren-toggle-open-paren-context 1)
;;   (c-set-offset 'case-label '+)
;;   (setq web-mode-engines-alist
;;         '(("php"    . "\\.phtml\\'")))
;;   (sp-local-pair 'web-mode "<" nil :when '(my/sp-web-mode-is-code-context))
;;   )

;; (add-to-list 'auto-mode-alist '("\\.phtml\\'" . web-mode))
;; (add-to-list 'auto-mode-alist '("\\.html?\\'" . web-mode))
;; ;; (add-to-list 'auto-mode-alist '("\\.css\\'" . web-mode))
;; ;; (add-to-list 'auto-mode-alist '("\\.php\\'" . web-mode))
;; (add-hook 'web-mode-hook 'my/web-mode-hook)

;; ;; from FAQ at http://web-mode.org/ for smartparens
;; (defun my/sp-web-mode-is-code-context (id action context)
;;   (when (and (eq action 'insert)
;;              (not (or (get-text-property (point) 'part-side)
;;                       (get-text-property (point) 'block-side))))
;;     t))

;; (use-package web-mode
;;   ;;:mode "\\.html?\\'"
;;   :init

;;   :hook
;;   ((auto-mode-alist .'("\\.php\\'" . web-mode)
;;      )
;;   :config
;;   (progn
;;     (setq web-mode-markup-indent-offset 2)
;;     (setq web-mode-code-indent-offset 2)
;;     (setq web-mode-css-indent-offset 2)
;;     (setq web-mode-enable-current-element-highlight t)
;;     (setq web-mode-ac-sources-alist
;;       '(("css" . (ac-source-css-property))
;;          ("html" . (ac-source-words-in-buffer ac-source-abbrev)))
;;       )))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; smartparens mode
;; inspired from http://pages.sachachua.com/.emacs.d/Sacha.html#org480d137
(use-package smartparens
  :diminish
  :ensure t
  :config
  (progn
    (require 'smartparens-config)
    (smartparens-global-mode 1)
    (show-smartparens-global-mode 1)
    ;;(add-hook 'emacs-lisp-mode-hook 'smartparens-mode)

    (add-hook 'emacs-lisp-mode-hook 'show-smartparens-mode)

    (setq sp-navigate-close-if-unbalanced t)

    ;; keybinding management
    ;;(define-key smartparens-mode-map (kbd "C-M-k") 'sp-kill-sexp)
    ;;(define-key smartparens-mode-map (kbd "C-M-w") 'sp-copy-sexp)
    (define-key smartparens-mode-map (kbd "s-k") 'sp-kill-hybridsexp)
    (define-key smartparens-mode-map (kbd "s-w") 'sp-copy-sexp)

    (define-key smartparens-mode-map (kbd "C-c s r n") 'sp-narrow-to-sexp)

    ;; (define-key smartparens-mode-map (kbd "C-M-f") 'sp-forward-sexp)
    ;; (define-key smartparens-mode-map (kbd "C-M-b") 'sp-backward-sexp)
    (define-key smartparens-mode-map (kbd "s-f") 'sp-forward-sexp)
    (define-key smartparens-mode-map (kbd "s-b") 'sp-backward-sexp)

    ;; (define-key smartparens-mode-map (kbd "C-S-a") 'sp-beginning-of-sexp)
    ;; (define-key smartparens-mode-map (kbd "C-S-d") 'sp-end-of-sexp)
    ;; (define-key smartparens-mode-map (kbd "C-S-e") 'sp-end-of-sexp)
    (define-key smartparens-mode-map (kbd "s-a") 'sp-beginning-of-sexp)
    (define-key smartparens-mode-map (kbd "s-e") 'sp-end-of-sexp)

    ;; (define-key smartparens-mode-map (kbd "C-M-n") 'sp-next-sexp)
    ;; (define-key smartparens-mode-map (kbd "C-M-p") 'sp-previous-sexp)
    (define-key smartparens-mode-map (kbd "s-n") 'sp-next-sexp)
    (define-key smartparens-mode-map (kbd "s-p") 'sp-previous-sexp)

    ;; (define-key smartparens-mode-map (kbd "C-M-t") 'sp-transpose-sexp)
    (define-key smartparens-mode-map (kbd "s-<up>") 'sp-transpose-hybrid-sexp)
    (define-key smartparens-mode-map (kbd "s-<down>") 'sp-push-hybrid-sexp)

    ;; (define-key smartparens-mode-map (kbd "M-D") 'sp-splice-sexp)
    (define-key smartparens-mode-map (kbd "s-d") 'sp-splice-sexp)

    ;; (define-key smartparens-mode-map (kbd "C-<right>") 'sp-forward-slurp-sexp)
    ;; (define-key smartparens-mode-map (kbd "C-<left>") 'sp-forward-barf-sexp)
    ;; (define-key smartparens-mode-map (kbd "C-M-<left>") 'sp-backward-slurp-sexp)
    ;; (define-key smartparens-mode-map (kbd "C-M-<right>") 'sp-backward-barf-sexp)
    (define-key smartparens-mode-map (kbd "s-<right>") 'sp-slurp-hybrid-sexp)
    (define-key smartparens-mode-map (kbd "s-<left>") 'sp-forward-barf-sexp)
    (define-key smartparens-mode-map (kbd "s-S-<left>") 'sp-backward-slurp-sexp)
    (define-key smartparens-mode-map (kbd "s-S-<right>") 'sp-backward-barf-sexp)

    ;; nearly useless in C
    ;; (define-key smartparens-mode-map (kbd "<kp-enter>") 'sp-up-sexp)
    ;; (define-key emacs-lisp-mode-map (kbd ")") 'sp-up-sexp)
    ;; (define-key smartparens-mode-map (kbd "C-M-d") 'sp-down-sexp)
    ;; (define-key smartparens-mode-map (kbd "C-M-e") 'sp-up-sexp)

    (define-key smartparens-mode-map (kbd "C-M-a") 'sp-backward-down-sexp)
    (define-key smartparens-mode-map (kbd "C-M-u") 'sp-backward-up-sexp)

    (define-key smartparens-mode-map (kbd "M-<delete>")
      'sp-unwrap-sexp)
    (define-key smartparens-mode-map (kbd "M-<backspace>")
      'sp-backward-unwrap-sexp)

    (define-key smartparens-mode-map (kbd "C-M-<delete>")
      'sp-splice-sexp-killing-forward)
    (define-key smartparens-mode-map (kbd "C-M-<backspace>")
      'sp-splice-sexp-killing-backward)
    (define-key smartparens-mode-map (kbd "C-S-<backspace>")
      'sp-splice-sexp-killing-around)

    ;;(define-key smartparens-mode-map (kbd "C-]") 'sp-select-next-thing-exchange)
    ;;(define-key smartparens-mode-map (kbd "C-<left_bracket>") 'sp-select-previous-thing)
    ;;(define-key smartparens-mode-map (kbd "C-M-]") 'sp-select-next-thing)
    (define-key smartparens-mode-map (kbd "s-]")
      'sp-select-next-thing-exchange)
    (define-key smartparens-mode-map (kbd "s-<left_bracket>")
      'sp-select-previous-thing-exchange)

    ;;(define-key smartparens-mode-map (kbd "M-F") 'sp-forward-symbol)
    ;;(define-key smartparens-mode-map (kbd "M-B") 'sp-backward-symbol)

    (define-key smartparens-mode-map (kbd "C-c s t") 'sp-prefix-tag-object)
    (define-key smartparens-mode-map (kbd "C-c s p") 'sp-prefix-pair-object)
    (define-key smartparens-mode-map (kbd "C-c s c") 'sp-convolute-sexp)
    (define-key smartparens-mode-map (kbd "C-c s a") 'sp-absorb-sexp)
    (define-key smartparens-mode-map (kbd "C-c s e") 'sp-emit-sexp)
    (define-key smartparens-mode-map (kbd "C-c s p") 'sp-add-to-previous-sexp)
    (define-key smartparens-mode-map (kbd "C-c s n") 'sp-add-to-next-sexp)
    (define-key smartparens-mode-map (kbd "C-c s j") 'sp-join-sexp)
    (define-key smartparens-mode-map (kbd "C-c s s") 'sp-split-sexp)

;;;;;;;;;;;;;;;;;;
    ;; pair management

    (sp-local-pair 'minibuffer-inactive-mode "'" nil :actions nil)

;;; c-mode
    (sp-with-modes '(c-mode c++-mode)
      (sp-local-pair "{" nil :post-handlers '(("||\n[i]" "RET")))
      (sp-local-pair "/*" "*/" :post-handlers '((" | " "SPC")
                                                      ("* ||\n[i]" "RET"))))
;;; markdown-mode
    (sp-with-modes '(markdown-mode gfm-mode rst-mode)
      (sp-local-pair "*" "*" :bind "C-*")
      (sp-local-tag "2" "**" "**")
      (sp-local-tag "s" "```scheme" "```")
      (sp-local-tag "<"  "<_>" "</_>" :transform 'sp-match-sgml-tags))

;;; tex-mode latex-mode
    (sp-with-modes '(tex-mode plain-tex-mode latex-mode)
      (sp-local-tag "i" "1d5f8e69396c521f645375107197ea4dfbc7b792quot;<" "1d5f8e69396c521f645375107197ea4dfbc7b792quot;>"))

;;; html-mode
    (sp-with-modes '(html-mode sgml-mode web-mode)
      (sp-local-pair "<" ">"))

;;; web-mode
    (defun my/sp-web-mode-is-code-context (id action context)
      (when (and (eq action 'insert)
                 (not (or (get-text-property (point) 'part-side)
                          (get-text-property (point) 'block-side))))
        t))
    (sp-local-pair 'web-mode "<" nil :when '(my/sp-web-mode-is-code-context))

;;; lisp modes
    (sp-with-modes sp-lisp-modes
      (sp-local-pair "(" nil :bind "C-("))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; shell-script mode
(add-hook
 'sh-mode-hook
 (lambda ()
   (setq indent-tabs-mode nil
      	 tab-width 4
         sh-basic-offset 4
         comment-column 50
         comment-auto-fill-only-comments t
         fill-column 128
         auto-fill-mode t
         shfmt-command "~/go/bin/shfmt"
         shfmt-arguments '("-i" "4" "-ci"))
   (sh-electric-here-document-mode)
   (define-key sh-mode-map (kbd "C-c f") 'shfmt-buffer)))

;;(define-key sh-mode-map
;;     (kbd "<kp-return>") 'reindent-then-newline-and-indent)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; lsp-mode
(use-package lsp-mode
  :ensure t
  :diminish "LSP"
  :commands (lsp lsp-deferred)
  :config
  (setq lsp-prefer-flymake                 nil
        lsp-semantic-tokens-enable         t
        ;;lsp-enable-on-type-formatting      nil
        lsp-enable-snippet                 nil
        lsp-enable-symbol-highlighting     t
        lsp-lens-enable                    t
        lsp-headerline-breadcrumb-enable   t
        lsp-enable-indentation             nil
        lsp-enable-on-type-formatting      nil
        lsp-eldoc-enable-hover             t
        lsp-modeline-diagnostics-enable    t
        lsp-modeline-code-actions-enable   t
        lsp-modeline-code-actions-segments '(count icon name)
        lsp-signature-render-documentation t)
  :hook
  ((sh-mode  . lsp-deferred)
   ;;(c-mode-common . lsp-deferred)
   (lsp-mode . lsp-enable-which-key-integration)))

(use-package lsp-ui
  :ensure t
  ;;:diminish
  :config
  (setq ; lsp-ui-doc-show-with-cursor        t
        ; lsp-ui-doc-show-with-mouse         t
        lsp-ui-sideline-enable             t
        lsp-ui-sideline-show-code-actions  t
        lsp-ui-sideline-enable             t
        lsp-ui-sideline-show-hover         t
        lsp-ui-sideline-enable             t
        lsp-ui-doc-enable                  nil)

  :commands
  (lsp-ui-mode)
  :bind-keymap
  ("s-l" . lsp-command-map))

;;(use-package lsp-lens
;;  :diminish)

(use-package helm-lsp
  :commands
  helm-lsp-workspace-symbol)

;;(use-package eglot
;;  :ensure t
;;  :diminish "EG")

(use-package ccls
  :ensure t
  :diminish " ccls"
  :init
  (setq ccls-initialization-options
	      '(:index (:comments 2) :completion (:detailedLabel t)))
  (setq-default flycheck-disabled-checkers '(c/c++-clang c/c++-cppcheck c/c++-gcc))
  (setq ccls-sem-highlight-method 'font-lock)
  ;; alternatively,
  ;;(setq ccls-sem-highlight-method 'overlay)
  ;; For rainbow semantic highlighting
  ;;(ccls-use-default-rainbow-sem-highlight)
  :config
  ;;(setq projectile-project-root (ccls--suggest-project-root))
  :hook
  ((c-mode) . (lambda () (require 'ccls) (lsp)))
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; CSS mode
(add-hook
 'css-mode-hook
 (lambda()
   (setq cssm-indent-level 3
         cssm-newline-before-closing-bracket t
         cssm-indent-function #'cssm-c-style-indenter
         cssm-mirror-mode t
         css-indent-offset 2
         indent-tabs-mode nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; additional files to load
;; load different files if they exist in user-emacs-directory directory:
;; emacs custom file, graphical system, system type, and hostname
;; in this order.

;; special case for custom file. Need to do something (maybe use an alist below)
(setq custom-file
      (concat user-emacs-directory "custom.el"))
(when (file-exists-p custom-file)
  (load custom-file))

;; secret file: all sensitive data
(setq my/secret-file "~/data/private/secret.el")
(when (file-exists-p my/secret-file)
  (load my/secret-file)
  (message "+++%s" my/secret-file))

;; load graphic/terminal specific file
(let ((filename (concat user-emacs-directory
                        (if (display-graphic-p)
                            "graphic"
                          "term")
                        ".el")))
  (when (file-exists-p filename)
    (load filename)
    (message "+++%s" filename)))

;; host specific file
(let ((filename (concat user-emacs-directory
                        (system-name)
                        ".el")))
  (when (file-exists-p filename)
    (load filename)
    (message "+++%s" filename)))

;; start server if not running
(require 'server)
(unless (server-running-p)
  (server-start)
  (message "++++++ emacs server started"))

;; (dolist
;;   (filename
;;     (list
;;       ;; emacs self-generated - TO IMPROVE
;;       ;; "custom"
;;       ;; graphical system
;;       (if (display-graphic-p)
;;         "graphic"
;;         "term")
;;       ;; system type - we need to replace "/" with "!" here, for "gnu/linux"
;;       (replace-regexp-in-string "/" "%" (symbol-name system-type))
;;       ;; hostname
;;       (system-name)))
;;   (let ((full-filename (concat user-emacs-directory filename ".el")))
;;     ;; load file
;;     (message "+++%s" full-filename)
;;     (if (file-exists-p full-filename)
;;       (load full-filename)
;;       )))

(message "++++++ init.el end")
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; nothing works in Emacs 25
(defun my/trim-spaces (beg end)
  "Trim all blank characters in region to one space, and remove whitespaces
at beginning and end of lines."
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      ;; replace multiple spaces in one
      (goto-char (point-min))
      (while (re-search-forward "[ \t]+" nil t)
        (replace-match " "))
      ;; remove spaces at lines beginning
      (goto-char (point-min))
      (while (re-search-forward "^[ \t]+" nil t)
        (replace-match ""))
      ;; remove spaces at line start/end
      (delete-trailing-whitespace))))

(defun my/align (beg end)
  "Align columns with spaces."
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (my/trim-spaces (point-min) (point-max))
      (align-regexp (point-min) (point-max) "\\(\\s-*\\)\\s-" 1 0 t)
      (delete-trailing-whitespace))))

(defun align-cols (start end max-cols)
  "Align text between point and mark as columns.
Columns are separated by whitespace characters.
Prefix arg means align that many columns. (default is all)
Attribution: ?"
  (interactive "r\nP")
  (save-excursion
    (let ((p start)
          pos
          end-of-line
          word
          count
          (max-cols (if (numberp max-cols) (max 0 (1- max-cols)) nil))
          (pos-list nil)
          (ref-list nil))
      ;; find the positions
      (goto-char start)
      (while (< p end)
        (beginning-of-line)
        (setq count 0)
        (setq end-of-line (save-excursion (end-of-line) (point)))
        (re-search-forward "^\\s-*" end-of-line t)
        (setq pos (current-column))     ;start of first word
        (if (null (car ref-list))
            (setq pos-list (list pos))
          (setq pos-list (list (max pos (car ref-list))))
          (setq ref-list (cdr ref-list)))
        (while (and (if max-cols (< count max-cols) t)
                    (re-search-forward "\\s-+" end-of-line t))
          (setq count (1+ count))
          (setq word (- (current-column) pos))
          ;; length of next word including following whitespaces
          (setq pos (current-column))
          (if (null (car ref-list))
              (setq pos-list (cons word pos-list))
            (setq pos-list (cons (max word (car ref-list)) pos-list))
            (setq ref-list (cdr ref-list))))
        (while ref-list
          (setq pos-list (cons (car ref-list) pos-list))
          (setq ref-list (cdr ref-list)))
        (setq ref-list (nreverse pos-list))
        (forward-line)
        (setq p (point)))
      ;; align the cols starting with last row
      (setq pos-list (copy-sequence ref-list))
      (setq start
            (save-excursion (goto-char start) (beginning-of-line) (point)))
      (goto-char end)
      (beginning-of-line)
      (while (>= p start)
        (beginning-of-line)
        (setq count 0)
        (setq end-of-line (save-excursion (end-of-line) (point)))
        (re-search-forward "^\\s-*" end-of-line t)
        (goto-char (match-end 0))
        (setq pos (nth count pos-list))
        (while (< (current-column) pos)
          (insert-char ?\040 1))
        (setq end-of-line (save-excursion (end-of-line) (point)))
        (while (and (if max-cols (< count max-cols) t)
                    (re-search-forward "\\s-+" end-of-line t))
          (setq count (1+ count))
          (setq pos   (+  pos (nth count pos-list)))
          (goto-char (match-end 0))
          (while (< (current-column) pos)
            (insert-char ?\040 1))
          (setq end-of-line (save-excursion (end-of-line) (point))))
        (forward-line -1)
        (if (= p (point-min)) (setq p (1- p))
          (setq p (point)))))))
;;(setq
;;current-language-environment "UTF-8"
;;(prefer-coding-system 'UTF-8)
;;(set-default-coding-systems 'UTF-8)
;;(set-terminal-coding-system 'UTF-8)
;;(setq-default buffer-file-coding-system 'UTF-8)

;; affichage direct des caractères sur 8 bits
;; (standard-display-european 1)
;; les caractères iso-latin1 qui sont des lettres, des majuscules...
;; (require 'iso-syntax )

;; (rplacd fancy-startup-text
;;         `("\nZou are running a customized Emacs configuration. See "  :link
;;           ("here"
;;            #[257 "\300\301!\207"
;;                  [browse-url-default-browser "http://github.com/izahn/dotemacs/"]
;;                  3 "\n\n(fn BUTTON)"]
;;            "Open the README file")
;;           "\nfor information about these customizations.\n"
;;           .
;;           (cdr fancy-startup-text)))
;; (rplacd add-to-list 'fancy-startup-text
;;              '("\nYou are running a customized Emacs configuration. See "  :link
;;                ("here"
;;                 #[257 "\300\301!\207"
;;                       [browse-url-default-browser "http://github.com/izahn/dotemacs/"]
;;                       3 "\n\n(fn BUTTON)"]
;;                 "Open the README file")
;;                "\nfor information about these customizations.\n"))

;; Local Variables:
;; byte-compile-warnings: (not free-vars)
;; End:
(provide 'init)
;;; init.el ends here
(put 'narrow-to-region 'disabled nil)

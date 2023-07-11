;; ~/.emacs.d/graphic.el
;;
;; emacs configuration - this file will be loaded only when emacs runs on graphic
;; system.
;;
;; br, 2010-2019

;; avoids calling this twice
(when (not (boundp 'my/graphic-loaded))
  ;; disable toolbar
  (tool-bar-mode -1)

  ;; initial frame size
  (set-frame-size (selected-frame) 180 50)

  (setq
    ;; split windows and assign them references
    my/upper-window (selected-window)
    my/main-window  (split-window-right)
    my/below-window (split-window-below)

    my/graphic-loaded t))

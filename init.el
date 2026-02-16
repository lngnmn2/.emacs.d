;;; init.el --- Emacs Configuration  -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; A modern, minimal, and correct Emacs 30+ configuration.
;;
;; Design Philosophy:
;; 1. "Shift Left": Rely on static configuration and built-in mechanisms.
;; 2. Correctness: No warnings, no race conditions, clean load-path.
;; 3. Performance: Lazy loading (defer), optimized GC.
;; 4. Modern Stack: Vertico, Orderless, Corfu, Eglot.
;; 5. Idiomatic: Follows "use-package" best practices and Emacs conventions.
;;
;; References:
;; - https://github.com/jwiegley/use-package
;; - https://github.com/purcell/emacs.d
;; - https://github.com/minad/vertico
;; - Google Internal Emacs Best Practices (Performance, Stability)

;;; Code:

;;; 1. Startup & Performance

(setq-default load-prefer-newer t)
(setq-default byte-compile-warnings 'all)

(eval-and-compile
  (defconst emacs-start-time (current-time))

  (defun report-time-since-load (&optional suffix)
    (message "Loading init...done (%.3fs)%s"
             (float-time (time-subtract (current-time) emacs-start-time))
             suffix)))

(add-hook 'after-init-hook
          (lambda () (report-time-since-load " [after-init]"))
          t)

;; Maximize GC threshold during startup to prevent pauses.
;; We reset it to a sane value via `emacs-startup-hook'.
(setq gc-cons-threshold most-positive-fixnum)

;; Optimize file handler lookups during startup (Doom Emacs trick).
(defvar default-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 50 1024 1024)) ; 50MB
            (setq file-name-handler-alist default-file-name-handler-alist)))

(add-hook 'after-init-hook #'garbage-collect t)
(add-hook 'frame-focus-out #'garbage-collect t)

;; Native Compilation (Emacs 28+)
(when (boundp 'comp-deferred-compilation)
  (setq comp-deferred-compilation t)
  (setq comp-async-jobs-number 8)
  (setq native-comp-async-report-warnings-errors 'silent))

;;; 2. Package Management

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; Define and load custom file early to keep init.el clean
(setq custom-file (locate-user-emacs-file "custom.el"))
(when (file-exists-p custom-file)
  (load custom-file))

;; Bootstrap `use-package`
(require 'use-package)
(setq use-package-always-ensure t)
(setq use-package-always-defer t)
(setq use-package-compute-statistics t)
(setq use-package-expand-minimally t) ; errors

(let ((verbose (or nil init-file-debug)))
  (setq use-package-verbose verbose
        use-package-expand-minimally (not verbose)
        use-package-compute-statistics verbose
        debug-on-error verbose
        debug-on-message "buffer-local while locally let-bound"
        debug-on-quit verbose))

;; Add local lisp directories
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(let ((default-directory (expand-file-name "user-lisp" user-emacs-directory)))
  (when (file-exists-p default-directory)
    (add-to-list 'load-path default-directory)
    (normal-top-level-add-subdirs-to-load-path)))

;;; 3. General Settings & Defaults

(setq inhibit-startup-message t
      use-short-answers t             ; y-or-n-p
      visible-bell t                  ; No beep
      make-backup-files t             ; Yes ~ files
      create-lockfiles nil            ; No # files
      ring-bell-function 'ignore)     ; Silent

;; UTF-8 everywhere
(set-charset-priority 'unicode) ;; utf8 everywhere
(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8-unix)

(setq locale-coding-system 'utf-8
      coding-system-for-read 'utf-8
      coding-system-for-write 'utf-8)

(setq default-process-coding-system '(utf-8-unix . utf-8-unix))

(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(set-selection-coding-system 'utf-8)

(use-package aio :ensure t :defer t)
(use-package async :ensure t :defer t)
(use-package gnutls :ensure t :defer t)

(use-package dired-async
  :ensure nil
  :hook (dired-mode-load . dired-async-mode))

;; Indentation
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq-default fill-column 80)

;; Linux X11 Clipboard Fix
(setq x-select-request-type '(UTF8_STRING COMPOUND_TEXT TEXT STRING))

(eval-and-compile
  (defun add-all-to-list (var &rest elems)
    (dolist (elem (reverse elems))
      (add-to-list var elem))))

;; Persist history over Emacs restarts. Vertico sorts by history position.
(use-package savehist
  :ensure nil
  :demand t
  :config
  (setq history-length t)
  (setq history-delete-duplicates t)
  (setq savehist-save-minibuffer-history 1)
  (setq savehist-additional-variables
        '(kill-ring
          search-ring
          regexp-search-ring))
  :init
  (savehist-mode))

;; Recent files
(use-package recentf
  :ensure nil
  :demand t
  :init
  (recentf-mode)
  :custom
  (recentf-max-saved-items 60))


(use-package autorevert
  :ensure nil
  :custom
  (auto-revert-check-vc-info t)
  (auto-revert-verbose t)
  :config (global-auto-revert-mode t))
;;; 4. UI Configuration

(use-package emacs
  :init
  (tool-bar-mode -1)
  (menu-bar-mode -1)
  (scroll-bar-mode -1)
  (pixel-scroll-precision-mode 1)
  (set-fringe-mode 10)
  (global-visual-line-mode t)
  (global-hl-line-mode t)
  (global-subword-mode t)
  (setq show-trailing-whitespace t)
  ;; Transparency
  (set-frame-parameter nil 'alpha-background 96)
  (add-to-list 'default-frame-alist '(alpha-background . 96))
  (defun save-all ()
    (interactive)
    (save-some-buffers t))
  :custom
  (auto-save-default t)
  (make-backup-files t)
  (backup-by-copying t)
  (version-control t)
  (vc-make-backup-files t)
  (delete-old-versions -1)
  (create-lockfiles t)
  (auto-save-visited-mode t)
  :config
  (auto-save-visited-mode t)
  (add-hook 'focus-out-hook #'save-all))

(use-package super-save
  :diminish
  :init (super-save-mode t))

(use-package hide-mode-line :demand t)

(use-package auto-compile
  :demand t
  :hook (emacs-lisp . auto-compile-mode)
  :config
  (auto-compile-on-load-mode t)
  (auto-compile-on-save-mode t))

(use-package nyan-mode
  :demand t
  :init
  (nyan-mode t)
  :config
  (setq nyan-animate-nyancat t)
  (setq nyan-wavy-trail t))

(use-package guru-mode
  :demand t
  :diminish
  :config
  (guru-global-mode t))

(use-package hardtime
  :config
  (hardtime-mode t))

(use-package whole-line-or-region
  :ensure nil
  :demand t
  :diminish whole-line-or-region-local-mode
  :config (whole-line-or-region-global-mode))

(use-package hi-lock
  :ensure nil
  :bind (("M-o l" . highlight-lines-matching-regexp)
         ("M-o r" . highlight-regexp)
         ("M-o w" . highlight-phrase)))

(use-package expand-region
  :init
  (global-set-key (kbd "C-=") 'er/expand-region))

;; should use smartparens instead
;; (use-package electric
;;   :ensure nil
;;   :demand t
;;   :init
;;   (electric-pair-mode t)
;;   (electric-indent-mode t)
;;   :config
;;   (setq electric-pair-preserve-balance nil)) ;; more annoying than useful

(use-package browse-kill-ring
  :commands browse-kill-ring)

(use-package flyspell
  :ensure nil
  :custom
  (ispell-dictionary "en_GB")
  :hook (text-mode . flyspell-mode))

(use-package flyspell-lazy
  :demand t
  :hook (flyspell-mode . flyspell-lazy-mode))

(use-package flyspell-correct
  :after flyspell
  :bind (:map flyspell-mode-map ("C-;" . flyspell-correct-wrapper)))

(use-package avy
  :bind ("M-g g" . avy-goto-char))

(use-package flyspell-correct-avy-menu
  :after flyspell-correct)

(use-package undo-tree
  :demand t
  :diminish
  :custom
  (undo-tree-history-directory-alist `(("." . ,(concat user-emacs-directory "undo-tree-hist/"))))
  (undo-tree-visualizer-diff t)
  :config
  (setq undo-tree-visualizer-timestamps t)
  (setq undo-tree-visualizer-diff t
        undo-tree-auto-save-history t
        undo-tree-enable-undo-in-region t)
  :init
  (global-undo-tree-mode t))

(use-package which-key
  :demand t
  :diminish
  :init
  (which-key-mode t)
  :config
  (which-key-setup-minibuffer))

(use-package helpful
  :demand t
  :hook (help-mode . helpful-mode)
  :bind
  ([remap describe-function] . helpful-function)
  ([remap describe-variable] . helpful-variable)
  ([remap describe-key] . helpful-key)
  ([remap describe-symbol] . helpful-symbol)
  :config
  (defalias 'describe-function 'helpful-callable)
  (defalias 'describe-variable 'helpful-variable)
  (defalias 'describe-key 'helpful-key))

(use-package swiper
  :demand t
  :bind (([remap isearch-forward] . swiper-isearch)
         ([remap isearch-backward] . swiper-isearch-backward)))

(use-package aggressive-indent
  :demand t
  :diminish
  :config
  (global-aggressive-indent-mode t))

(use-package volatile-highlights
  :demand
  :diminish
  :config
  (volatile-highlights-mode t))

(use-package command-log-mode
  :bind (("C-c M" . command-log-mode)
         ("C-c L" . clm/open-command-log-buffer)))

(use-package wgrep)
(use-package rg)
(use-package fzf)
(use-package ag)

(use-package vterm
  :commands (vterm vterm-other-window)
  :config
  (define-key vterm-mode-map (kbd "M-n") 'vterm-send-down)
  (define-key vterm-mode-map (kbd "M-p") 'vterm-send-up)
  (define-key vterm-mode-map (kbd "M-y") 'vterm-yank-pop)
  (define-key vterm-mode-map (kbd "M-/") 'vterm-send-tab))

(use-package focus
  :commands (focus-mode focus-read-only-mode))

(use-package writeroom-mode
  :commands writeroom-mode)

(use-package doom-themes
  :demand t
  :custom
  (doom-themes-enable-bold t)   ; if nil, bold is universally disabled
  (doom-themes-enable-italic t) ; if nil, italics is universally disabled:config
  (doom-theme 'doom-tokyo-night)
  :init
  (setq doom-font (font-spec :family "SF Mono" :size 16 :weight 'light)
        doom-variable-pitch-font (font-spec :family "SF Pro Text" :size 16 :weight 'light))
  :config
  (setcdr (assoc 'gnus-group-news-low-empty doom-themes-base-faces)
          '(:inherit 'gnus-group-mail-1-empty :weight 'normal)))

(use-package indian
  :ensure nil
  :after unicode-fonts
  :config
  (set-language-environment 'Devanagari)
  (set-input-method 'devanagari-itrans))

(use-package solaire-mode
  :demand t
  :config
  (solaire-global-mode +1))

(use-package mixed-pitch
  :demand t
  :diminish
  :config
  (append mixed-pitch-fixed-pitch-faces
          '(font-lock-comment-face
            font-lock-string-face
            font-lock-doc-face
            font-lock-keyword-face
            font-lock-function-name-face
            font-lock-variable-name-face
            font-lock-type-face
            font-lock-constant-face
            font-lock-builtin-face
            font-lock-preprocessor-face
            org-block
            org-code
            org-verbatim
            org-link
            markdown-code-face
            markdown-inline-code-face
            markdown-pre-face
            markdown-link-face
            markdown-url-face))
  ;; Hook into text modes systematically
  (dolist (hook
           '(text-mode-hook
             help-mode-hook
             org-mode-hook
             org-roam-mode-hook
             markdown-mode-hook
             gfm-mode
             Info-mode-hook
             Man-mode-hook
             LaTex-mode-hook
             eww-mode-hook
             nov-mode-hook))
    (add-hook hook (lambda ()
                     ;;(variable-pitch-mode t)
                     (mixed-pitch-mode t)))))

(defvar mixed-pitch-modes '(text-mode help-mode org-mode org-roam-mode eww-mode LaTeX-mode markdown-mode gfm-mode Info-mode eww-mode Man-mode nov-mode)
  "Modes that `mixed-pitch-mode' should be enabled in, but only after UI initialisation.")

(defun init-mixed-pitch-h ()
  "Hook `mixed-pitch-mode' into each mode in `mixed-pitch-modes'.
Also immediately enables `mixed-pitch-modes' if currently in one of the modes."
  (when (memq major-mode mixed-pitch-modes)
    (mixed-pitch-mode t))
  (dolist (hook mixed-pitch-modes)
    (add-hook (intern (concat (symbol-name hook) "-hook")) #'mixed-pitch-mode)))

(add-hook 'after-init-hook #'init-mixed-pitch-h)

;; Font Setup (Idiomatic: Use `font-spec`)
(defun my/setup-fonts ()
  "Set fixed and variable pitch fonts systematically."
  (let ((mono-font "SF Mono")
        (prop-font "SF Pro Text")
        (size 160)) ;; 16pt
    (set-face-attribute 'default nil :family mono-font :height size :weight 'light)
    (set-face-attribute 'fixed-pitch nil :family mono-font :height size :weight 'light)
    (set-face-attribute 'variable-pitch nil :family prop-font :height size :weight 'light))

  (require 'org)
  (require 'doom-themes)
  (load-theme 'doom-tokyo-night t)
  (doom-themes-org-config)
  (doom-themes-enable-org-fontification)
  )

(add-hook 'after-init-hook #'my/setup-fonts)

(use-package smartparens
  :demand t
  :diminish
  :config
  (show-smartparens-global-mode t)
  (smartparens-global-mode t))

(use-package pretty-symbols
  :diminish
  :hook (prog-mode . pretty-symbols-mode))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package highlight-symbol
  :hook (prog-mode . highlight-symbol-mode)
  :diminish
  :init
  (setq highlight-symbol-on-navigation-p t))

(use-package highlight-numbers
  :hook (prog-mode . highlight-numbers-mode))
(use-package highlight-quoted
  :hook (prog-mode . highlight-quoted-mode))

;;; 5. Minibuffer Completion (Vertico Stack)

(use-package orderless
  :demand t
  :custom
  (completion-category-overrides
   '((file (styles basic partial-completion))))
  :config
  (add-to-list 'completion-styles 'orderless)
  (setq completion-category-overrides '((file (styles orderless partial-completion)))
        orderless-component-separator #'orderless-escapable-split-on-space))

(use-package vertico
  :after orderless
  :init
  (vertico-mode)
  :custom
  (vertico-cycle t)
  (vertico-count 15)
  (vertico-resize nil))

(use-package marginalia
  :demand t
  :init
  (marginalia-mode))

(use-package prescient
  :after (vertico orderless)
  :demand t
  :custom
  (prescient-persist-mode t)
  ;;(prescient-save-file (user-data "prescient-save.el"))
  :config
  (add-to-list 'completion-styles 'prescient)
  (add-to-list 'savehist-additional-variables 'prescient--history))

(use-package vertico-prescient
  :after (prescient)
  :demand t
  :config
  (vertico-prescient-mode 1))

(use-package consult
  :demand t
  :bind (;; C-c bindings (mode-specific-map)
         ("C-c M-x" . consult-mode-command)
         ("C-c h" . consult-history)
         ("C-c k" . consult-kmacro)
         ("C-c m" . consult-man)
         ("C-c i" . consult-info)
         ;; C-x bindings (ctl-x-map)
         ([remap yank-pop] . consult-yank-pop)
         ([remap imenu] . consult-imenu)
         ([remap Info-search] . consult-info)
         ([remap goto-line] . consult-goto-line)
         ([remap repeat-complex-command] . consult-complex-command)
         ([remap switch-to-buffer] . consult-buffer)
         ([remap switch-to-buffer-other-window] . consult-buffer-other-window)
         ([remap switch-to-buffer-other-frame] . consult-buffer-other-frame)
         ([remap bookmark-jump] . consult-bookmark)
         ([remap project-switch-to-buffer] . consult-project-buffer)
         ;; Custom M-# bindings for fast register access
         ("M-#" . consult-register-load-delete)
         ("M-'" . consult-register-store)
         ("C-M-#" . consult-register)
         ;; M-g bindings (goto-map)
         ("M-g e" . consult-compile-error)
         ("M-g f" . consult-flymake)
         ("M-g g" . consult-goto-line)
         ("M-g M-g" . consult-goto-line)
         ("M-g o" . consult-outline)
         ("M-g m" . consult-mark)
         ("M-g k" . consult-global-mark)
         ("M-g i" . consult-imenu)
         ("M-g I" . consult-imenu-multi)
         ;; M-s bindings (search-map)
         ("M-s d" . consult-find)
         ("M-s D" . consult-locate)
         ("M-s g" . consult-grep)
         ("M-s G" . consult-git-grep)
         ("M-s r" . consult-ripgrep)
         ("M-s l" . consult-line)
         ("M-s L" . consult-line-multi)
         ("M-s k" . consult-keep-lines)
         ("M-s u" . consult-focus-lines)
         ;; Isearch integration
         ("M-s e" . consult-isearch-history)
         :map isearch-mode-map
         ("M-e" . consult-isearch-history)
         ("M-s e" . consult-isearch-history)
         ("M-s l" . consult-line)
         ("M-s L" . consult-line-multi))
  :config
  (consult-customize
   consult-theme :preview-key '(:debounce 0.2 any)
   consult-ripgrep consult-git-grep consult-grep
   consult-bookmark consult-recent-file consult-xref
   :preview-key '(:debounce 0.4 any)))

(use-package consult-xref
  :ensure nil
  :demand t
  :init
  ;; Integrate with Xref
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)
  )

(use-package consult-dir
  :bind (("C-x C-d" . consult-dir)
         :map minibuffer-local-completion-map
         ("C-x C-d" . consult-dir)
         ("C-x C-j" . consult-dir-jump-file)))

(use-package flycheck
  :commands (flycheck-mode
             flycheck-next-error
             flycheck-previous-error)
  )

(use-package flycheck-eglot
  :after eglot)

(use-package consult-flycheck
  :bind ("M-g f" . consult-flycheck))

(use-package projectile)

(use-package consult-projectile
  :after projectile)

;;; 6. In-Buffer Completion (Corfu + Cape)

(use-package corfu
  :demand t
  :after orderless
  :bind (("C-M-i" . completion-at-point)
         :map corfu-map
         ;;         ("C-n"      . corfu-next)
         ;;         ("C-p"      . corfu-previous)
         ("M-d"      . corfu-info-documentation)
         ("M-l"      . corfu-info-location)
         ("<escape>" . corfu-quit)
         ("<return>" . corfu-insert))
  :hook ((eshell-mode comint-mode) . (lambda () (setq-local corfu-auto nil)))
  :custom
  (corfu-auto t)
  (corfu-cycle t)
  (corfu-quit-no-match 'separator)
  (corfu-preview-current 'insert)  ; Preview first candidate. Insert on input if only one
  (corfu-preselect 'prompt)
  (corfu-preselect-first t)        ; Preselect first company-box-candidate
  (corfu-quit-at-boundary nil)

  ;; Works with `indent-for-tab-command'. Make sure tab doesn't indent when you
  ;; want to perform completion
  (tab-always-indent 'complete)
  (completion-cycle-threshold nil)      ; Always show candidates in menu

  (corfu-preselect 'prompt)
  :init
  (global-corfu-mode)
  :bind (:map corfu-map
              ("M-n"      . corfu-next)
              ("M-p"      . corfu-previous)
              ("<escape>" . corfu-quit)
              ("<return>" . corfu-insert)
              ("M-d"      . corfu-info-documentation)
              ("M-l"      . corfu-info-location)
              ("SPC" . corfu-insert-separator)))


(use-package corfu-popupinfo
  :ensure nil
  :after corfu
  :hook (corfu-mode . corfu-popupinfo-mode)
  :bind (:map corfu-map
              ("M-n" . corfu-popupinfo-scroll-up)
              ("M-p" . corfu-popupinfo-scroll-down)
              ([remap corfu-show-documentation] . corfu-popupinfo-toggle))
  :custom
  (corfu-popupinfo-delay 0.5)
  (corfu-echo-documentation t))

(use-package corfu-prescient
  :after (prescient)
  :demand t
  :config
  (corfu-prescient-mode 1))

(use-package cape
  :demand t
  :after (orderless corfu)
  :hook (eshell-mode . (lambda ()
                         (setq-local completion-at-point-functions
                                     (cons #'pcomplete-completions-at-point
                                           completion-at-point-functions))))
  :hook (eglot-mode . (lambda ()
                        (add-to-list 'completion-at-point-functions
                                     (cape-capf-super #'eglot-completion-at-pointe-keyword))))
  :bind (:prefix-map
         my-cape-map
         :prefix "C-c ."
         ("p" . completion-at-point)
         ("t" . complete-tag)
         ("d" . cape-dabbrev)
         ("h" . cape-history)
         ("f" . cape-file)
         ("k" . cape-keyword)
         ("s" . cape-elisp-symbol)
         ("a" . cape-abbrev)
         ("l" . cape-line)
         ("w" . cape-dict)
         ("\\" . cape-tex)
         ("_" . cape-tex)
         ("^" . cape-tex)
         ("&" . cape-sgml)
         ("r" . cape-rfc1345))
  :init
  ;; Add `completion-at-point-functions`, used by `corfu`
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'cape-keyword)
  (add-hook 'completion-at-point-functions #'cape-elisp-symbol)
  (add-hook 'completion-at-point-functions #'cape-elisp-block)
  (add-hook 'completion-at-point-functions #'cape-tex) ; Math/LaTeX symbols
  )

(use-package corfu-history
  :ensure nil
  :after savehist
  :hook (corfu-mode . corfu-history-mode)
  :config
  (add-to-list 'savehist-additional-variables 'corfu-history))

(use-package yasnippet
  :demand t
  :hook (prog-mode . yas-minor-mode-on)
  :diminish yas-minor-mode
  :custom
  (yas-prompt-functions '(yas-completing-prompt yas-no-prompt))
  (yas-snippet-dirs (list (concat user-emacs-directory "snippets")))
  (yas-triggers-in-field t)
  (yas-wrap-around-region t)
  :config
  (yas-load-directory (concat user-emacs-directory "snippets")))

(use-package consult-yasnippet
  :after (consult yasnippet))

(use-package yasnippet-capf
  :hook (yas-minor-mode . (lambda ()
                        (add-hook 'completion-at-point-functions #'yasnippet-capf 30 t) )))

;; Company (Fallback / Legacy Support)
(use-package company
  :commands (company-mode company-complete)
  :custom
  (company-idle-delay nil)
  (company-tooltip-align-annotations t))

(use-package company-org-block
  :after company
  :custom
  (company-org-block-edit-style 'auto) ;; 'auto, 'prompt, or 'inline
  :hook (org-mode . (lambda ()
                      (add-to-list 'company-backends 'company-org-block)
                      (company-mode t))))

(use-package company-quickhelp
  :after company
  :custom
  (company-quickhelp-delay 3)
  :hook (company-mode . company-quickhelp-mode))

(use-package company-yasnippet
  :ensure nil
  :after (company yasnippet))

(use-package consult-company
  :demand t
  :after company
  :bind (:map company-mode-map
              ([remap completion-at-point] . consult-company)))

(use-package company-math
  :ensure t
  :defer t)

(use-package info :autoload Info-goto-node)
(use-package info-look :autoload info-lookup-add-help)

;;; 7. Development Tools

(use-package diff-hl
  :demand t
  :hook (magit-post-refresh . diff-hl-magit-post-refresh)
  :config
  (global-diff-hl-mode t))

(use-package diffview
  :commands (diffview-current diffview-region diffview-message))

(use-package magit
  :commands magit-status
  :custom
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

(use-package eldoc
  :ensure nil
  :diminish
  :custom
  (eldoc-echo-area-use-multiline-p t) ;; Ensure full docs are shown
  (eldoc-idle-delay 0.5))

(use-package flymake
  :ensure nil
  :bind (:map flymake-mode-map
              ("M-n" . flymake-goto-next-error)
              ("M-p" . flymake-goto-prev-error)))

(use-package lsp-mode
  :config
   (add-to-list 'completion-category-overrides `(lsp-capf (styles ,@completion-styles)))
  )

(use-package eglot
  :ensure nil
  :defer t
  :hook ((rust-mode . eglot-ensure)
         (rust-ts-mode . eglot-ensure)
         (python-mode . eglot-ensure)
         (python-ts-mode . eglot-ensure)
         (c-mode-common . eglot-ensure)
         (c++-mode . eglot-ensure))
  :bind (:map eglot-mode-map
              ("C-c r" . eglot-rename)
              ("C-c a" . eglot-code-actions)
              ("C-c d" . eldoc))
  :config
  (setq-default eglot-extend-to-xref t)
  (setq eglot-code-action-indications '(eldoc-hint mode-line))
  (setq eglot-autoshutdown t)
  ;; Add clangd to eglot
  (add-to-list 'eglot-server-programs
               '((c++-mode c-mode c++-ts-mode c-ts-mode)
                 . ("clangd"
                    "--background-index"
                    "--clang-tidy"
                    "--completion-style=detailed"
                    "--header-insertion=iwyu"
                    "--header-insertion-decorators=0"
                    "-j=8")))
  ;; Rust Analyzer is configured in rust-ts-mode block, or we can add default here
  (add-to-list 'eglot-server-programs
               '((rust-ts-mode rust-mode) . ("rust-analyzer" :initializationOptions (:check (:command "clippy"))))))

(use-package eglot-orderless
  :ensure nil
  :no-require t
  :after (eglot orderless)
  :config
  (add-to-list 'completion-category-overrides
               '(eglot (styles orderless flex basic))))

(use-package consult-eglot
  :demand t
  :after eglot
  :bind (:map eglot-mode-map
              ("C-c s" . consult-eglot-symbols)))

(use-package consult-lsp
  :demand t
  :after eglot
  :bind (:map eglot-mode-map
              ([remap xref-find-apropos] . consult-lsp-symbols)))


;;; 8. Languages & Shells

(use-package cmake-mode
  :mode ("CMakeLists\\.txt\\'" "\\.cmake\\'"))


(use-package google-c-style
  :hook ((c-mode-common . google-c-style)
         (c-mode-common . google-make-newline-indent)))

;; C++ / C Configuration
(use-package cc-mode
  :ensure nil
  :mode ("\\.h\\'" . c++-mode) ;; Default .h to C++
  :config
  ;; Modern C++17/20 settings
  (setq c-default-style "google"
        c-basic-offset 2))

(use-package clang-format
  :after cc-mode
  :bind (:map c-mode-base-map
              ("C-M-q" . clang-format-region))
  :hook (c-mode-common . (lambda ()
                           (add-hook 'before-save-hook #'clang-format-buffer nil t))))

;; (use-package realgud
;;   :commands (realgud:gdb))

;; (use-package rmsbolt :defer t)

(use-package x86-lookup :defer t)

(setq gentoo-erlang (car (file-expand-wildcards "/usr/lib64/erlang/lib/tools-*/emacs")))
(add-to-list 'load-path gentoo-erlang)

(use-package erlang
  :ensure nil
  :defer t
  :init
  (setq erlang-root-dir "/usr/lib64/erlang"))

(use-package sml-mode
  :mode "\\.sml\\'"
  )

(use-package ob-sml
  :after org)

(use-package company-mlton
  :ensure nil
  :load-path "/usr/local/share/emacs/site-lisp"
  :after company
  :hook (sml-mode . company-mlton-init)
  :config
  (add-to-list 'company-backends 'company-mlton-grouped-backend))

(use-package lua-mode
  :mode "\\.lua?\\'"
  :config
  (setq lua-default-application "luajit"))

(autoload 'octave-mode "octave-mod" nil t)

;; Rust Configuration (Google Style)
(use-package rust-ts-mode
  :ensure nil ;; Built-in in Emacs 29+
  :mode "\\.rs\\'"
  :hook ((rust-ts-mode . eglot-ensure)
         (rust-ts-mode . (lambda ()
                           (add-hook 'before-save-hook #'eglot-format-buffer nil t))))
  :config
  ;; Enforce 4-space indentation (Google/Rust Standard)
  (setq rust-ts-mode-indent-offset 4))

(use-package rust-mode
  :bind (:map rust-mode-map
              ("C-c C-c v" . (lambda ()
                               (interactive)
                               (shell-command "rustdocs std"))))
  :hook (rust-mode . yas-minor-mode-on)
  :config
  (setq rust-format-on-save t)
  (setq rust-mode-treesitter-derive t))

(use-package rustowl
  :ensure nil
  :after eglot)

(use-package ob-rust
  :after org)

(use-package python
  :mode ("\\.py\\'" . python-ts-mode)
  :interpreter "python3")

(use-package elisp-mode
  :ensure nil
  :after (cape)
  :hook (emacs-lisp-mode . my/setup-elisp)
  :preface
  (defun my/setup-elisp ()
    (setq-local completion-at-point-functions
                `(,(cape-capf-super
                    #'elisp-completion-at-point
                    #'cape-dabbrev)
                  cape-file)
                cape-dabbrev-min-length 5)))

;; use show-smartparens-mode
(use-package paren
  :ensure nil
  :custom
  (show-paren-context-when-offscreen t)
  :config
  (setq show-paren-delay 0.3)
  (show-paren-mode t))

(use-package hl-line
  :commands hl-line-mode
  :bind ("M-o h" . hl-line-mode))

;; use M-;
(keymap-global-set "C-x ;" #'comment-line)
(keymap-global-set "C-x C-;" #'comment-region)

(use-package elisp-mode
  :ensure nil
  :hook (emacs-lisp-mode . (lambda ()
                             (setq-local completion-at-point-functions
                                         (cons #'cape-elisp-symbol completion-at-point-functions)))))

(use-package lisp-mode
  :ensure nil
  :hook ((emacs-lisp-mode lisp-mode)
         . (lambda () (add-hook 'after-save-hook #'check-parens nil t)))
  :custom
  (parens-require-spaces t))

(use-package highlight-defined
  :commands highlight-defined-mode
  :custom
  (highlight-defined-face-use-itself t)
  :hook
  ((help-mode Info-mode) . highlight-defined-mode)
  (emacs-lisp-mode . highlight-defined-mode))

(use-package elisp-def
  :diminish
  :hook (emacs-lisp-mode . elisp-def-mode))

(use-package elisp-refs
  :commands elisp-refs-mode)

(use-package eval-sexp-fu
  :hook (emacs-lisp-mode . eval-sexp-fu-flash-mode))

(use-package elisp-depend
  :commands elisp-depend-print-dependencies)

(use-package elisp-docstring-mode
  :commands elisp-docstring-mode)

(use-package elisp-slime-nav
  :diminish
  :commands (elisp-slime-nav-mode
             elisp-slime-nav-find-elisp-thing-at-point))

(use-package elmacro
  :defer t
  :bind (("C-c e" . elmacro-mode)
         ("C-x C-)" . elmacro-show-last-macro)))

(use-package edebug
  :ensure nil
  :config
  (setq edebug-trace t
        edebug-save-windows t))

(use-package ert
  :ensure nil
  :bind (:map emacs-lisp-mode-map
              ("C-c C-t t" . ert-run-tests-interactively)
              ("C-c C-t a" . ert-run-tests-batch-and-exit)))

(use-package buttercup
  :bind (:map emacs-lisp-mode-map
              ("C-c C-t b" . buttercup-run-at-point)))

(use-package tdd
  :ensure nil
  :commands (tdd-mode)
  ;; :hook (emacs-lisp-mode . tdd-mode)
  )

;; (use-package ivy :defer t)

;; too invasive
(use-package lispy
  :after ivy
  :commands (lispy-mode)
  ;; :hook ((lisp-mode emacs-lisp-mode) . lispy-mode)
  )

(use-package elisp-lint
  :after emacs-lisp-mode)

(use-package package-lint
  :after emacs-lisp-mode)

(use-package undercover
  :after emacs-lisp-mode
  :config
  (setq undercover-force-coverage t))

(use-package slime)

;; pollutes C-x r
(use-package redshank
  :after slime
  :diminish
  :commands (redshank-mode)
  ;; :hook ((lisp-mode emacs-lisp-mode) . redshank-mode)
  )

(use-package compile
  :bind (("C-c c" . compile)
	     ("M-O"   . show-compilation))
  :bind (:map compilation-mode-map
	          ("q" . delete-window))
  :hook (compilation-filter . compilation-ansi-color-process-output)
  :custom
  (compilation-always-kill t)
  (compilation-ask-about-save nil)
  (compilation-context-lines 10)
  (compilation-scroll-output 'first-error)
  (compilation-skip-threshold 2)
  (compilation-window-height 100)
  :preface
  (defun show-compilation ()
    (interactive)
    (let ((it
	       (catch 'found
	         (dolist (buf (buffer-list))
	           (when (string-match "\\*compilation\\*" (buffer-name buf))
		         (throw 'found buf))))))
      (if it
	      (display-buffer it)
	    (call-interactively #'compile))))

  (defun compilation-ansi-color-process-output ()
    (ansi-color-process-output nil)
    (set (make-local-variable 'comint-last-output-start)
	     (point-marker))))

(use-package compile-angel
  :demand t
  :diminish
  :custom
  (compile-angel-verbose nil)
  :config
  (compile-angel-on-load-mode)
  (add-hook 'emacs-lisp-mode-hook
	        #'compile-angel-on-save-local-mode))

(use-package paredit :defer t)

(use-package ielm
  :ensure nil
  :hook (ielm-mode . (lambda ()
                       (corfu-mode)
                       (setq-local completion-at-point-functions
                                   (cons #'cape-elisp-symbol completion-at-point-functions))))
  :bind (:map ielm-map ("<return>" . my-ielm-return))
  :config
  (defun my-ielm-return ()
    (interactive)
    (let ((end-of-sexp (save-excursion
                         (goto-char (point-max))
                         (skip-chars-backward " \t\n\r")
                         (point))))
      (if (>= (point) end-of-sexp)
          (progn
            (goto-char (point-max))
            (skip-chars-backward " \t\n\r")
            (delete-region (point) (point-max))
            (call-interactively #'ielm-return))
        (call-interactively #'paredit-newline)))))

(use-package nxml-mode
  :ensure nil
  :commands nxml-mode
  :bind (:map nxml-mode-map
              ("<return>" . newline-and-indent)
              ("C-c M-h"  . tidy-xml-buffer))
  :custom
  (nxml-child-indent 2)
  (nxml-attribute-indent 2)
  (nxml-auto-insert-xml-declaration-flag nil)
  (nxml-bind-meta-tab-to-complete-flag t)
  (nxml-sexp-element-flag t)
  (nxml-slash-auto-complete-flag t)
  :preface
  (defun tidy-xml-buffer ()
    (interactive)
    (save-excursion
      (call-process-region (point-min) (point-max) "tidy" t t nil
                           "-xml" "-i" "-wrap" "0" "-omit" "-q" "-utf8")))
  :init
  (defalias 'xml-mode 'nxml-mode)
  :config
  (autoload 'sgml-skip-tag-forward "sgml-mode")
  (add-to-list 'hs-special-modes-alist
               '(nxml-mode
                 "<!--\\|<[^/>]*[^/]>"
                 "-->\\|</[^/>]*[^/]>"
                 "<!--"
                 sgml-skip-tag-forward
                 nil)))

(use-package json-mode :ensure t
  :mode "\\.json\\'")

(use-package jq-mode
  :after org)

(use-package json-reformat :ensure t
  :after json-mode)

(use-package restclient
  :commands (rest-client))

(use-package ob-restclient
  :after org)

(use-package ob-duckdb
  :after org
  :config
  (setq ob-duckdb-executable "duckdb")
  (setq ob-duckdb-connection-string "file:duckdb.db?mode=memory&cache=shared"))

(use-package markdown-mode
  :mode ("README\\.md\\'" . gfm-mode)
  :init
  (setq markdown-enable-math t
        markdown-enable-wiki-links t
        markdown-italic-underscore t
        markdown-asymmetric-header t
        markdown-gfm-additional-languages '("sh" "rust" "python")
        markdown-make-gfm-checkboxes-buttons t
        markdown-fontify-whole-heading-line t)
  :hook (markdown-mode . (lambda ()
                           (set-face-attribute 'markdown-pre-face nil :inherit 'fixed-pitch)
                           (set-face-attribute 'markdown-inline-code-face nil :inherit 'fixed-pitch)
                           (variable-pitch-mode t)))
  :hook (markdown-mode . markdown-toggle-markup-hiding)
  :config
  (setq markdown-command "pandoc")
  (setq markdown-fontify-code-blocks-natively t))

(use-package pandoc-mode
  :after markdown-mode
  :hook (markdown-mode . pandoc-mode)
  :config
  (setq pandoc-use-async t)
  (setq pandoc-process-connection-type nil)) ;; Use pipes

(use-package tex-mode
  :ensure nil
  :config
  (setq TeX-parse-self t ; parse on load
        TeX-auto-save t  ; parse on save
        ;; Use hidden directories for AUCTeX files.
        TeX-auto-local ".auctex-auto"
        TeX-style-local ".auctex-style"
        TeX-source-correlate-mode t
        TeX-source-correlate-method 'synctex
        ;; Don't start the Emacs server when correlating sources.
        TeX-source-correlate-start-server nil
        ;; Automatically insert braces after sub/superscript in `LaTeX-math-mode'.
        TeX-electric-sub-and-superscript t
        ;; Just save, don't ask before each compilation.
        TeX-save-query nil))

(use-package auctex
  :defer t)
(use-package company-auctex
  :after company)
(use-package cdlatex
  :defer t)

;;; 9. Org Mode & Notes

(use-package djvu
  :mode "\\.djvu\\'"
  :magic ("%DJVU" . djvu-read-mode)
  )
(use-package djvu3
  :ensure nil
  :after djvu)

(use-package pdf-tools
  :mode "\\.pdf\\'"
  :custom
  (pdf-use-scalling nil))

(define-minor-mode prose-mode
  "Set up a buffer for prose editing.
This enables or modifies a number of settings so that the
experience of editing prose is a little more like that of a
typical word processor."
  :init-value nil :lighter " Prose" :keymap nil
  (if prose-mode
      (progn
        (when (fboundp 'writeroom-mode)
          (writeroom-mode 1))
        (setq truncate-lines nil)
        (setq word-wrap t)
        (setq cursor-type 'bar)
        (when (eq major-mode 'org)
          (kill-local-variable 'buffer-face-mode-face))
        (buffer-face-mode 1)
        ;;(delete-selection-mode 1)
        (setq-local blink-cursor-interval 0.6)
        (setq-local show-trailing-whitespace nil)
        (setq-local line-spacing 0.2)
        (setq-local electric-pair-mode nil)
        (ignore-errors (flyspell-mode 1))
        (visual-line-mode 1))
    (kill-local-variable 'truncate-lines)
    (kill-local-variable 'word-wrap)
    (kill-local-variable 'cursor-type)
    (kill-local-variable 'blink-cursor-interval)
    (kill-local-variable 'show-trailing-whitespace)
    (kill-local-variable 'line-spacing)
    (kill-local-variable 'electric-pair-mode)
    (buffer-face-mode -1)
    ;; (delete-selection-mode -1)
    (flyspell-mode -1)
    (visual-line-mode -1)
    (when (fboundp 'writeroom-mode)
      (writeroom-mode 0))))

(use-package org
  :ensure nil
  :demand t
  :diminish
  :hook (org-mode . org-indent-mode)
  :init
  (setq org-ascii-charset 'utf-8)
  (setq org-export-coding-system 'utf-8)
  (setq org-html-coding-system 'utf-8)
  :config
  (setq org-auto-align-tags nil
        org-tags-column 0
        org-catch-invisible-edits 'show-and-error
        org-special-ctrl-a/e t ;; special navigation behaviour in headlines
        org-insert-heading-respect-content t)

  (setq org-hide-emphasis-markers t
        org-src-fontify-natively t ;; fontify source blocks natively
        org-highlight-latex-and-related '(native) ;; fontify latex blocks natively
        org-pretty-entities t)

  (setq org-ellipsis " …"
        org-startup-folded 'content)

  (setq org-adapt-indentation t)

  ;; Export Backends
  (require 'ox-md)

  ;; PDF Export (using latexmk)
  (setq org-latex-pdf-process
        '("latexmk -f -pdf -%latex -interaction=nonstopmode -output-directory=%o %f")))

(use-package sgml-mode
  :ensure nil
  :hook
  ((html-mode . sgml-electric-tag-pair-mode)
   (html-mode . sgml-name-8bit-mode))
  :custom
  (sgml-basic-offset 2)
  :config
  (setq sgml-xml-mode t)
  (setq sgml-transformation-function 'upcase))

(use-package tidy
  :ensure nil
  :config
  (setq sgml-validate-command "tidy"))

(use-package htmlize :defer t)

(use-package ox-gfm
  :after ox)

(use-package ox-html
  :ensure nil
  :after ox
  :config
  (setq org-html-coding-system 'utf-8-unix))

(use-package ox-latex
  :ensure nil
  :after ox)

(use-package ox-hugo
  :after ox)

(use-package ox-pandoc
  :after org
  :config
  ;; Set default options for pandoc export if needed
  (setq org-pandoc-options '((standalone . t))))

(use-package org-appear
  :demand t
  :after org
  :hook (org-mode . org-appear-mode)
  :config
  (setq org-appear-autoemphasis t
        org-appear-autosubmarkers t
        org-appear-autokeywords t
        org-appear-autolinks t)
  ;; for proper first-time setup, `org-appear--set-elements'
  ;; needs to be run after other hooks have acted.
  (run-at-time nil nil #'org-appear--set-elements))

(use-package org-modern
  :demand t
  :after org
  :hook (org-mode . org-modern-mode))

(use-package org-tidy
  :hook (org-mode . org-tidy-mode))

(use-package org-roam
  :after org
  :custom
  (org-roam-directory (file-truename "~/org-roam"))
  (org-roam-database-connector 'sqlite-builtin)
  :init
  (defun node-insert-immediate (arg &rest args)
    "a wrapper for org-roam-node-insert"
    (interactive "P")
    (let ((args (push arg args))
          (org-roam-capture-templates (list (append (car org-roam-capture-templates)
                                                    '(:immediate-finish t))) ))
      (apply #'org-roam-node-insert args)))

  (defun capture-inbox-item ()
    "a shortcut for capturing a common Inbox entry into org-roam (to refile later)"
    (interactive)
    (org-roam-capture- :node (org-roam-node-create)
                       :templates '(("i" "inbox" plain "* %?"
                                     :if-new (file+head "inbox.org" "#+TITLE: Inbox\n")
                                     :prepend t))))
  (defun capture-todo-item ()
    "a shotcut for quickly capturing a new TODO item in the todo.org file"
    (interactive)
    (org-roam-capture- :node (org-roam-node-create)
                       :templates '(("t" "a new todo" entry "* [ ] %?\n%i\n%a"
                                     :if-new (file+head +org-capture-todo-file "* Inbox\n")
                                     :prepend t))))
  (defun capture-new-note ()
    "a shortcut for quickly captureing a new Note in the notes.org file"
    (interactive)
    (org-roam-capture- :node (org-roam-node-create)
                       :templates '(("n" "a new note" entry "* %u %?\n%i\n%a"
                                     :if-new (file+head +org-capture-notes-file "* Inbox\n")
                                     :prepend t))))
  (defun filter-by-tag (tag)
    "captures a tag"
    (lambda (node)
      (member tag (org-roam-node-tags node))))

  (defun list-notes-by-tag (tag)
    "selects nodes which have the given tag"
    (mapcar #'org-roam-node-file
            (seq-filter
             (filter-by-tag tag)
             (org-roam-node-list))))

  :bind (("C-c n f" . org-roam-node-find)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n c" . org-roam-capture)
         ("C-c n b" . #'capture-inbox-item)
         ("C-c n t" . #'capture-todo-item) ; shortcuts
         ("C-c n n" . #'capture-new-note)
         (:map org-mode-map
               (("C-c n i" . org-roam-node-insert)
                ("C-c n I" . #'node-insert-immediate)
                ("C-c n r" . org-roam-refile)
                ("C-c n v" . org-id-get-visit)
                ("C-c n o" . org-id-get-create)
                ("C-c n t" . org-roam-tag-add)
                ("C-c n a" . org-roam-alias-add)
                ("C-c n l" . org-roam-buffer-toggle)
                ("C-M-i" . completion-at-point))))
  
  :config
  (org-roam-setup)
  (org-roam-db-autosync-mode))

(use-package org-ql :defer t)

;;; 10. AI & Tools

(use-package llama-cpp :demand t)

(use-package gptel
  :init
  ;; 1. Define a function to fetch the OAuth2 token dynamically
  (defun my/get-google-oauth-token ()
    "Get a valid OAuth2 token using the gcloud CLI."
    (string-trim (shell-command-to-string "gcloud auth print-access-token")))

  ;; 2. Configure the Gemini Backend
  ;; We use the specialized gptel-make-gemini helper
  (defvar gptel--gemini-backend
    (gptel-make-gemini "Gemini"
      :key #'my/get-google-oauth-token  ; <--- Uses the function, not a string
      :stream t                         ; Enable streaming responses
      :models '(;; Add the specific model names you want to use here
                "gemini-3-pro-preview"
                "gemini-3-flash-preview"  ; Example Preview model
                "gemini-exp-1206")))     ; Often used for the latest experimental builds

  ;; --- 1. Define the Local Llama Backend ---
  (defvar gptel--llama-backend
    (gptel-make-openai "Local Llama"   ; The name that appears in the menu
      :host "localhost:8080"           ; Default llama.cpp server port
      :protocol "http"
      :stream t                        ; Enable streaming
      :key nil                         ; No API key needed for local
      :models '("qwen3"  ; The model name (server often ignores this, but gptel needs one)
                "deepseek"
                "mistral")))

  ;; --- 2. Custom Switching Command ---
  (defun my/gptel-switch-backend ()
    "Quickly switch between Gemini and Local Llama backends."
    (interactive)
    (let* ((backends `(("Gemini (Cloud)" . ,gptel--gemini-backend)
                       ("Llama (Local)"  . ,gptel--llama-backend)))
           (choice (completing-read "Select AI Backend: " (mapcar #'car backends)))
           (selected-backend (alist-get choice backends nil nil #'string=)))
      
      (setq gptel-backend selected-backend)
      (message "Switched gptel backend to: %s" choice)))

  ;; --- 3. Keybinding ---
  ;; Bind this to a key for fast access, e.g., C-c s
  (global-set-key (kbd "C-c g s") 'my/gptel-switch-backend)
  ;; 3. Set it as the default (optional)
  :bind (("C-c RET" . gptel-send)
         ("C-c g n" . gptel)
         ("C-c g r" . gptel-rewrite)
         ("C-c g m" . gptel-menu))
  :custom
  (gptel-default-mode 'org-mode)
  :config
  (setq gptel-backend gptel--gemini-backend)
  (setq gptel-model 'gemini-3-pro-preview))

(use-package gptel-org
  :ensure nil
  :after gptel
  :config
  (add-to-list 'gptel-org-ignore-elements 'comment-block))

(use-package gptel-rewrite
  :ensure nil
  :after (gptel)
  :demand t
  :bind (("M-r" . gptel-rewrite)
         :map gptel-rewrite-actions-map
         ("<return>" . gptel--rewrite-dispatch))
  :custom
  (gptel-rewrite-default-action 'accept))

(use-package gptel-context
  :ensure nil
  :after gptel
  :bind (:map gptel-mode-map
              ("M-a" . gptel-context-add)))

(use-package gptel-agent :demand t :after gptel)

(use-package gptel-quick
  :ensure nil
  :after gptel
  :bind (:map gptel-mode-map
              ("M-q" . gptel-quick)))

(use-package gptel-emacs-tools :ensure nil :after gptel)

(use-package copilot-chat :defer t)

(use-package copilot
  :defer t
  :after copilot-chat
  :init
  (setq copilot-indent-offset-warning-disable t)
  ;; :hook ((prog-mode org-mode) . copilot-mode)
  :bind (:map copilot-completion-map
              ("C-n" . 'copilot-next-completion)
              ("C-p" . 'copilot-previous-completion)
              ("<tab>" . 'copilot-accept-completion)
              ("TAB" . 'copilot-accept-completion)
              ("C-TAB" . 'copilot-accept-completion-by-word)
              ("C-<tab>" . 'copilot-accept-completion-by-word))
  :config
  (add-to-list 'copilot-indentation-alist '(org-mode 2)))

(use-package macher
  :after (gptel)
  :config
  (macher-install))

(use-package agent-shell)

(use-package ai-code
  :bind ("C-c a" . #'ai-code-menu)
  :config
  ;; use codex as backend, other options are 'claude-code, 'gemini, 'github-copilot-cli, 'opencode, 'grok, 'cursor, 'kiro, 'codebuddy, 'aider, 'claude-code-ide, 'claude-code-el
  (ai-code-set-backend 'gemini)
  (setq ai-code-gemini-cli-program-switches '("--model" "gemini-3-pro-preview"))
  (ai-code-prompt-filepath-completion-mode 1))

;;; Scheme
(use-package xscheme
  :config
  (setq inferior-scheme-program "mit-scheme")
  (setq scheme-program-name "mit-scheme"))


;;; 11. Browsing

(use-package image-file
  :demand t
  :hook (image-mode . image-transform-reset-to-initial)
  :config
  (auto-image-file-mode 1))

(use-package language-id)

(use-package language-detection)

(use-package shrface
  :hook (shr-mode . shrface-mode))

(use-package shr-tag-pre-highlight
  :ensure t
  :after shr
  :hook (shr-mode . shr-tag-pre-highlight-mode)
  :config
  (add-to-list 'shr-external-rendering-functions
               '(pre . #''shr-tag-pre-highlight)))

(use-package nov
  :after shr
  :mode ("\\.epub\\'" . nov-mode)
  :commands (nov-mode nov-open-directory nov-mode-menu)
  :custom
  (nov-variable-pitch t)
  :hook (nov-mode . (lambda ()
                      (visual-line-mode t)
                      (visual-fill-column-mode t)
                      (mixed-pitch-mode t)
                      (variable-pitch-mode t)
                      (focus-read-only-mode t)
                      (hide-mode-line-mode t)))
  )

(use-package eww
  :ensure nil
  :hook (eww-mode . (lambda ()
                      (visual-line-mode t)
                      (mixed-pitch-mode t)
                      (variable-pitch-mode t)
                                        ;(focus-read-only-mode t)
                      (hide-mode-line-mode t)))

  :custom
  (eww-retrieve-command '("chromium" "--headless" "--dump-dom"))
  :config
  (add-hook 'eww-mode-hook #'mixed-pitch-mode))

(with-eval-after-load 'org
  (setq org-ascii-charset 'utf-8)
  (setq org-export-coding-system 'utf-8)
  (setq org-html-coding-system 'utf-8)

  (setq python-interpreter "python3")
  (setq python-shell-interpreter "python3")

  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (latex . t)
     (python . t)
     (shell . t)
     (sml . t)
     (ocaml . nil)
     (octave . t)
     (rust . t)))
  
  (cl-defmacro lsp-org-babel-enable (lang)
    "Support LANG in org source code block."
    (cl-check-type lang string)
    (let* ((edit-pre (intern (format "org-babel-edit-prep:%s" lang)))
           (intern-pre (intern (format "lsp--%s" (symbol-name edit-pre)))))
      `(progn
	     (defun ,intern-pre (info)
           (let ((file-name (->> info caddr (alist-get :file))))
             (unless file-name
               (setq file-name (make-temp-file "babel-lsp-")))
             (setq buffer-file-name file-name)
             (lsp-deferred)))
	     (put ',intern-pre 'function-documentation
              (format "Enable lsp-mode in the buffer of org source block (%s)."
                      (upcase ,lang)))
	     (if (fboundp ',edit-pre)
             (advice-add ',edit-pre :after ',intern-pre)
           (progn
             (defun ,edit-pre (info)
               (,intern-pre info))
             (put ',edit-pre 'function-documentation
                  (format "Prepare local buffer environment for org source block (%s)."
                          (upcase ,lang))))))))

  (defvar org-babel-lang-list
    '("emacs-lisp" "elisp" "rust" "python" "ipython" "bash" "sh"))
  (dolist (lang org-babel-lang-list)
    (eval `(lsp-org-babel-enable ,lang)))
  )

;; (use-package erc :ensure nil :commands erc)

;; (use-package gnus :ensure nil :commands gnus)

;;; 12. TDD & Workflow Tools

(defun my/project-test ()
  "Run the project's test command (TDD) based on context.
Auto-detects CMake (C++) or Cargo (Rust) projects."
  (interactive)
  (let* ((root (project-root (project-current t)))
         (default-directory root)
         (compile-command
          (cond
           ((file-exists-p (expand-file-name "Cargo.toml" root))
            "cargo test -- --color always")
           ((file-exists-p (expand-file-name "CMakeLists.txt" root))
            "ctest --output-on-failure")
           ((file-exists-p (expand-file-name "Makefile" root))
            "make test")
           (t "make check"))))
    (compile compile-command)))


(global-set-key (kbd "C-c t") #'my/project-test)

(use-package gt
  :config
  (setq gt-langs '(en np))
  (setq gt-default-translator (gt-translator :engines (gt-google-engine))))

(use-package ivy-lobsters
  :commands ivy-lobsters)

(use-package gnus
  :ensure nil
  :commands gnus
  :config 
  (setq gnus-posting-styles
        '((".*" ;; Apply this style to all groups/addresses matching ".*"
           (signature-file "~/.signature")) ; Use the content of ~/.signature as the signature
          ("lngnmn2@yahoo.com" ;; Apply this style specifically to your-email@example.com
           (signature "Ln Gnmn\nhttps://lngnmn2.github.io/")) ; Direct signature text
          ))
  ;;(setq gnus-select-method nil) ; start with no select method
  
  (setq gnus-secondary-select-methods
        '((nnimap "gmail"
                  (nnimap-address "imap.gmail.com")
                  (nnimap-server-port "imaps")
                  (nnimap-stream ssl))
          (nnimap "yahoo"
                  (nnimap-address "imap.mail.yahoo.com")
                  (nnimap-server-port "imaps")
                  (nnimap-stream ssl))
          (nntp "feedbase.org"
                (nntp-open-connection-function nntp-open-tls-stream) ; feedbase does not do STARTTLS (yet?)
                (nntp-port-number 563)                               ; nntps
                (nntp-address "feedbase.org"))
          (nntp "news.eternal-september.org"
                (nntp-open-connection-function nntp-open-tls-stream)
                (nntp-port-number 563)  ; nntps
                (nntp-address "news.eternal-september.org"))
          (nntp "news.gmane.io"
                ;;(nntp-open-connection-function nntp-open-tls-stream) ; gmane does not do STARTTLS (yet?)
                ;;(nntp-port-number 563) ; nntps
                (nntp-address "news.gmane.io"))))
  )

(use-package langtool
  :commands (langtool-check langtool-check-buffer)
  :config
  (setq langtool-mother-tongue "en")
  (setq langtool-default-language "en-GB")
  (setq langtool-java-user-arguments '("-Dfile.encoding=UTF-8"))
  (setq langtool-java-classpath "/opt/LanguageTool-6.6/*")
  (setq langtool-language-tool-jar "/opt/LanguageTool-6.6/languagetool-commandline.jar")
  (setq langtool-language-tool-server-jar "/opt/LanguageTool-6.6/languagetool-server.jar")
  (setq langtool-server-user-arguments '("-p" "8082")))

(use-package eshell
  :ensure nil
  :after (corfu cape)

  ;; :hook (eshell-mode . (lambda ()
  ;;                        (corfu-mode)
  ;;                        (setq-local corfu-auto nil)
  ;;                        (setq-local completion-at-point-functions
  ;;                                    (list (cape-capf-super #'cape-file #'cape-dabbrev #'eshell-complete-parse-arguments)))))
  ;; :hook (eshell-pre-command . #'buffer-disable-undo)
  ;; :hook (eshell-post-command . (lambda ()
  ;;                                (buffer-enable-undo (current-buffer))
  ;;                                (setq buffer-undo-list nil)))
  ;; :hook (eshell-pre-command . (lambda ()
  ;;                               (when (and eshell-last-input-start
  ;;                                          eshell-last-input-end)
  ;;                                 (add-text-properties eshell-last-input-start
  ;;                                                      (1- eshell-last-input-end)
  ;;                                                      '(read-only t)))))
  ;; :hook (eshell-post-command . (lambda ()
  ;;                                (when (and eshell-last-input-end
  ;;                                           eshell-last-output-start)
  ;;                                  (add-text-properties eshell-last-input-end
  ;;                                                       eshell-last-output-start
  ;;                                                       '(read-only t)))))
  ;; Enable autopairing in eshell
  :hook (eshell-mode . (lambda ()
                         (electric-pair-local-mode t)
                         (hide-mode-line-mode t)))
  :config
  (setq
   ;; eshell-banner-message
   ;; '(format "%s %s\n"
   ;;          (propertize (format " %s " (string-trim (buffer-name)))
   ;;                      'face 'mode-line-highlight)
   ;;          (propertize (current-time-string)
   ;;                      'face 'font-lock-keyword-face))
   eshell-scroll-to-bottom-on-input 'all
   eshell-scroll-to-bottom-on-output 'all
   eshell-kill-processes-on-exit t
   eshell-hist-ignoredups t
   ;; eshell-input-filter-initial-space t
   ;; em-prompt
   eshell-prompt-regexp "^[^#$\n]* [#$λ] "
   ;; em-glob
   eshell-glob-case-insensitive t
   eshell-error-if-no-glob t)
  )

;; (use-package eshell-up :ensure nil
;;   :after eshell)
;; (use-package eshell-z :ensure nil
;;   :after eshell)
;; (use-package shrink-path)
;; (use-package esh-help :ensure nil
;;   :after eshell)

;; (use-package eshell-did-you-mean
;;   :after esh-mode ; Specifically esh-mode, not eshell
;;   :config (eshell-did-you-mean-setup))

;; (use-package eshell-syntax-highlighting
;;   :hook (eshell-mode . eshell-syntax-highlighting-mode))

;; (use-package bash-completion)
;; (use-package fish-completion)

(use-package vterm
  :commands (vterm vterm-mode)
  :hook (vterm-mode . hide-mode-line-mode) ; modeline serves no purpose in vterm
  :config
  (setq vterm-max-scrollback 5000))

;; (use-package nxhtml
;;   :ensure nil
;;   :commands (nxhtml-mode)
;;   :init
;;   (load "nxhtml/autostart.el"))

(use-package monkeytype)
(use-package speed-type)

(use-package smtpmail :demand t)

(require 'smtpmail)

(with-eval-after-load 'smtpmail
  (setq smtpmail-auth-supported '(xoauth2)  ; Force XOAUTH2
        smtpmail-debug-info t              ; Useful for initial setup
        smtpmail-debug-verb t))

(use-package notmuch
  :ensure nil
  :load-path "/usr/share/emacs/site-lisp"
  :commands (notmuch))
  :after smtpmail

(use-package mu4e
  :ensure nil
  :load-path "/usr/local/share/emacs/site-lisp"
  :after smtpmail
  :commands (mu4e)
  :config
  ;; set mail user agent
  (setq mail-user-agent 'mu4e-user-agent
        message-mail-user-agent 'mu4e-user-agent)
  (setq         ;; configuration for sending mail
   message-send-mail-function #'smtpmail-send-it
   smtpmail-stream-type 'starttls
   ))

(use-package org-msg
  :defer t
  :init
  :hook (mu4e . (progn require 'org-msg))
  :config
  (setq org-msg-options "html-postamble:nil H:5 num:nil ^:{} toc:nil author:nil email:nil tex:dvipng"
        org-msg-startup "hidestars indent inlineimages"
        org-msg-greeting-name-limit 3
        org-msg-default-alternatives '((new . (utf-8 html))
                                       (reply-to-text . (utf-8))
                                       (reply-to-html . (utf-8 html)))
        org-msg-convert-citation t
        ))

;; Define a function to fetch the token from gcloud
(defun my-fetch-gcloud-token ()
  "Fetch a fresh OAuth2 access token using gcloud CLI."
  (string-trim (shell-command-to-string "gcloud auth print-access-token")))

;; We need to override the XOAUTH2 method in smtpmail to use our token
;; rather than looking for a hardcoded password in auth-sources.
(cl-defmethod smtpmail-try-auth-method
  (process (mech (eql xoauth2)) user password)
  (let ((token (my-fetch-gcloud-token)))
    (smtpmail-command-or-throw
     process
     (format "AUTH XOAUTH2 %s"
             (base64-encode-string
              (format "user=%s\1auth=Bearer %s\1\1" user token) t))
     235)))

(setq message-send-mail-function 'smtpmail-send-it
      smtpmail-stream-type 'starttls
      smtpmail-default-smtp-server "smtp.gmail.com"
      smtpmail-smtp-server "smtp.gmail.com"
      smtpmail-smtp-service 587
      ;; Force smtpmail to use XOAUTH2 mechanism
      smtpmail-auth-credentials nil ;; specific to older versions, safe to nil
      smtpmail-servers-requiring-authorization ".*"
      smtpmail-stream-type 'starttls)

;; explicitly whack the other methodsa
(setq smtpmail-auth-supported '(xoauth2))

(defun my/gmail-check-connection ()
  "Verify Gmail API connectivity using gcloud OAuth2 token."
  (interactive)
  (let* ((token (string-trim (shell-command-to-string "gcloud auth print-access-token")))
         (url "https://gmail.googleapis.com/gmail/v1/users/me/profile")
         (url-request-extra-headers `(("Authorization" . ,(concat "Bearer " token))))
         (url-request-method "GET"))
    (url-retrieve url
                  (lambda (status)
                    (if (plist-get status :error)
                        (message "Gmail Connection: FAILED. Check gcloud login.")
                      (goto-char (point-min))
                      (re-search-forward "{")
                      (message "Gmail Connection: SUCCESS! Your token is valid.")
                      ;; Optional: Show the JSON response in a buffer
                      ;; (display-buffer (current-buffer))
                      )))))

(defun my/gcloud-auth-login()
  (interactive)
  (eshell-command "gcloud auth application-default login" t))

(defun my/gcloud-auth-login1()
  (let* ((output (eshell-command-result "gcloud auth application-default login"))
         (stdout (split-string output "\n")))
    (message stdout)))

(defun my/gmail-check-connection1 ()
  "Verify Gmail API connectivity and log the results."
  (interactive)
  (let ((token (string-trim (shell-command-to-string "gcloud auth print-access-token"))))
    (if (or (string-empty-p token) (string-match-p "ERROR" token))
        (error "Gcloud failed to provide a token. Run 'gcloud auth application-default login' in terminal.")
      (let* ((url "https://gmail.googleapis.com/gmail/v1/users/me/profile")
             (url-request-extra-headers `(("Authorization" . ,(concat "Bearer " token))))
             (url-request-method "GET"))
        (message "Testing Gmail connection with token: %s..." (substring token 0 10))
        (url-retrieve url
                      (lambda (status)
                        (cond
                         ((plist-get status :error)
                          (message "Gmail Connection: FAILED. Error: %S" (plist-get status :error)))
                         (t
                          (goto-char (point-min))
                          (if (re-search-forward "emailAddress" nil t)
                              (message "Gmail Connection: SUCCESS! Emacs can see your inbox.")
                            (message "Gmail Connection: PARTIAL SUCCESS. Received response, but no email found."))))))))))

(provide 'init)
;;; init.el ends here

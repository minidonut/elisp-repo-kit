;;; run-shim.el --- -*-no-byte-compile: t; lexical-binding: t -*-

;; Copyright (C) 2022 Positron Solutions

;; Author:  <author>

;; Permission is hereby granted, free of charge, to any person obtaining a copy of
;; this software and associated documentation files (the "Software"), to deal in
;; the Software without restriction, including without limitation the rights to
;; use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
;; the Software, and to permit persons to whom the Software is furnished to do so,
;; subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
;; FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
;; COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
;; IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
;; CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

;;; Commentary:

;; This package sets up load paths and then loads the test files and runs
;; commands depending on the command line arguments.
;;
;; Usage:
;;
;; Always get a fresh Emacs for your test runs.  It will reload features and
;; byte compile where necessary.  The Emacs provided by the nix develop shell
;; contains the dependencies declared in the flake.nix.
;;
;;   nix develop
;;   "emacs" --quick --script test/run-shim.el -- test
;;   "emacs" --quick --script test/run-shim.el -- lint
;;   "emacs" --quick --script test/run-shim.el -- lint-tests
;;
;; Note that this elisp script assumes that some packages are located in
;; specific locations.

;;; Code:

(defun erk--lint-package ()
  "Lint the files in the package directory."

  (require 'elisp-lint)
  ;; 100-character column limit for lints.  If it's good enough for Linux, it's
  ;; good enough for us.  https://lkml.org/lkml/2020/5/29/1038
  (setq-default fill-column 100)
  ;; Spaces
  (setq-default indent-tabs-mode nil)

  ;; `command-line-args-left has the same effect as passing command line arguments.
  (let ((command-line-args-left
         (append
          '(;; "--no-<check>
            ;; "--no-byte-compile"
            "--no-checkdoc"
            "--no-package-lint"
            ;; "--no-indent"
            ;; "--no-indent-character"
            ;; "--no-fill-column"
            ;; "--no-trailing-whitespace"
            ;; "--no-check-declare"
            )
          (seq-filter
           (lambda (s) (not (string-match-p ".*autoloads.*.el$" s)))
           (file-expand-wildcards "../lisp/*.el")))))

    (message "ARGS: %s" command-line-args-left)

    ;; (setq elisp-lint-ignored-validators nil
    ;;       elisp-lint-file-validators nil
    ;;       elisp-lint-buffer-validators nil
    ;;       elisp-lint-batch-files nil)

    (elisp-lint-files-batch)))

(defun erk--lint-tests ()
  "Lint the files in the test directory."

  (require 'elisp-lint)

  ;; Use this file's directory as default directory so that lisp file locations
  ;; are fixed with respect to this file.

  ;; 100-character column limit for lints.  If it's good enough for Linux, it's
  ;; good enough for us.  https://lkml.org/lkml/2020/5/29/1038
  (setq-default fill-column 100)
  ;; Spaces
  (setq-default indent-tabs-mode nil)

  ;; `command-line-args-left has the same effect as passing command line arguments.
  (let ((command-line-args-left
         (append
          '(;; "--no-<check>
            ;; "--no-byte-compile"
            "--no-checkdoc"
            "--no-package-lint"
            ;; "--no-indent"
            ;; "--no-indent-character"
            ;; "--no-fill-column"
            ;; "--no-trailing-whitespace"
            ;; "--no-check-declare"
            )
          (seq-filter
           (lambda (s) (not (string-match-p ".*autoloads.*.el$" s)))
           (file-expand-wildcards "../test/*.el")))))

    ;; (setq elisp-lint-ignored-validators nil
    ;;       elisp-lint-file-validators nil
    ;;       elisp-lint-buffer-validators nil
    ;;       elisp-lint-batch-files nil)

    (elisp-lint-files-batch)))

(defun erk--run-shim ()
  "Execute a CI process based on CLI arguments."
  ;; This expression normalizes the behavior of --quick --load <file> and --script
  ;; <file> behavior.  If you don't do this, --script will see every argument
  ;; passed and the arguments from the Nix wrapper to set load paths.  You can use
  ;; this to pass extra options to your scripts in the github actions.
  (when (member (car argv) '("-l" "--"))
    (print "Normalizing arguments")
    (while (not (member (car argv) '("--" nil)))
      (print (format "Normalizing arguments, stripped: %s" (pop argv))))
    (pop argv))

  (message "original default directory: %s" default-directory)
  ;; Configure load paths
  (setq default-directory (if load-file-name (file-name-directory load-file-name)
                            default-directory))
  (let* ((test-dir (expand-file-name (concat default-directory "../test")))
         (lisp-dir (expand-file-name (concat default-directory "../lisp"))))
    (print (format "test load path: %s" test-dir))
    (print (format "package load path: %s" lisp-dir))
    (push test-dir load-path)
    (push lisp-dir load-path))

  ;; running manually may encounter stale .elc
  (setq load-prefer-newer t)

  ;; Consume the command argument and run one of the routines
  (setq command (pop argv)) ; nil-safe
  (cond ((string= command "test")
         (require 'elisp-repo-kit-test)
         (ert-run-tests-batch-and-exit))
        ((string= command "lint") (erk--lint-package))
        ((string= command "lint-tests") (erk--lint-tests))
        t (print "Command not recognized.  Use test, lint, lint-tests etc.")))

;; Only attempt to run when Emacs is loading with or --batch --no-x-resources,
;; which is implied by -Q.
(when (or noninteractive inhibit-x-resources)
  (erk--run-shim))

(provide 'run-shim)
;;; run-shim.el ends here

;;; adaptive-wrap.el --- Smart line-wrapping with wrap-prefix

;; Copyright (C) 2011  Stefan Monnier

;; Author: Stephen Berman <stephen.berman@gmx.net>
;;         Stefan Monnier <monnier@iro.umontreal.ca>
;; Version: 0.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides the `adaptive-wrap-prefix-mode' minor mode which sets
;; the wrap-prefix property on the fly so that single-long-line paragraphs get
;; word-wrapped in a way similar to what you'd get with M-q using
;; adaptive-fill-mode, but without actually changing the buffer's text.

;;; Code:

(defcustom adaptive-wrap-extra-indent 0
  "Number of extra spaces to indent in `adaptive-wrap-prefix-mode'.

`adaptive-wrap-prefix-mode' indents the visual lines to
the level of the actual line plus `adaptive-wrap-extra-indent'.
A negative value will do a relative de-indent.

Examples:

actual indent = 2
extra indent = -1

  Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do
 eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut
 enim ad minim veniam, quis nostrud exercitation ullamco laboris
 nisi ut aliquip ex ea commodo consequat.

actual indent = 2
extra indent = 2

  Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do
    eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut
    enim ad minim veniam, quis nostrud exercitation ullamco laboris
    nisi ut aliquip ex ea commodo consequat."
  :type 'integer
  :group 'visual-line)
(make-local-variable 'adaptive-wrap-extra-indent)

(defun adaptive-wrap-fill-context-prefix (beg en)
  "Like `fill-context-prefix', but with length adjusted by `adaptive-wrap-extra-indent'."
  (let* ((fcp (fill-context-prefix beg en))
         (fcp-len (string-width fcp))
         (fill-char (if (< 0 fcp-len)
                        (string-to-char (substring fcp -1))
                      ?\ )))
    (cond
     ((= 0 adaptive-wrap-extra-indent)
      fcp)
     ((< 0 adaptive-wrap-extra-indent)
      (concat fcp
              (make-string adaptive-wrap-extra-indent fill-char)))
     ((< 0 (+ adaptive-wrap-extra-indent fcp-len))
      (substring fcp
                 0
                 (+ adaptive-wrap-extra-indent fcp-len)))
     (t
      ""))))

(defun adaptive-wrap--vp-string-pixel-width (string)
  "Return the width of STRING in pixels.

  Just like `string-pixel-width', but adjusts to
  `variable-pitch-mode' if it is active."
  (if (zerop (length string))
      0
    (let ((variable-pitch-active (and (bound-and-true-p buffer-face-mode)
                                      (bound-and-true-p buffer-face-mode-face)
                                      (eq buffer-face-mode-face
                                          'variable-pitch))))
      ;; Keeping a work buffer around is more efficient than creating
      ;; a new temporary buffer.
      (with-current-buffer (get-buffer-create " *markdown/string-pixel-width*")
        ;; If `display-line-numbers' is enabled in internal buffers
        ;; (e.g. globally), it breaks width calculation (bug#59311)
        (setq-local display-line-numbers nil)
        (delete-region (point-min) (point-max))
        (if variable-pitch-active
            (variable-pitch-mode 1)
          (variable-pitch-mode -1))
        ;; Disable line-prefix and wrap-prefix, for the same reason.
        (setq line-prefix nil
  	    wrap-prefix nil)
        (insert (propertize string 'line-prefix nil 'wrap-prefix nil))
        (car (buffer-text-pixel-size nil nil t))))))

(defun adaptive-wrap--prefix-width-property (beg end)
  "Return the pixel-width of the prefix of the line between BEG and END.

  The returned value is a specified space.  Visit info
  node `(elisp)Specified Space' for more information."
  (let* ((whitespace-prefix (adaptive-wrap-fill-context-prefix beg end))
         (prefix-len (string-width whitespace-prefix))
         (prefix (buffer-substring beg (+ beg prefix-len)))
         (prefix-width (adaptive-wrap--vp-string-pixel-width prefix)))
    `(space . (:width (,prefix-width)))))


(defun adaptive-wrap-prefix-function (beg end)
  "Indent the region between BEG and END with adaptive filling."
  (goto-char beg)
  (while (< (point) end)
    (let ((lbp (line-beginning-position)))
      (put-text-property (point)
                         (progn (search-forward "\n" end 'move) (point))
                         'wrap-prefix
                         (adaptive-wrap--prefix-width-property lbp (point))))))

;;;###autoload
(define-minor-mode adaptive-wrap-prefix-mode
  "Wrap the buffer text with adaptive filling."
  :lighter ""
  :group 'visual-line
  (if adaptive-wrap-prefix-mode
      (jit-lock-register #'adaptive-wrap-prefix-function)
    (jit-lock-unregister #'adaptive-wrap-prefix-function)
    (with-silent-modifications
      (save-restriction
        (widen)
        (remove-text-properties (point-min) (point-max) '(wrap-prefix nil))))))

(provide 'adaptive-wrap)
;;; adaptive-wrap.el ends here

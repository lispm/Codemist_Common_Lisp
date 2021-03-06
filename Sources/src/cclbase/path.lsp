;;
;; File system interface for CCL
;;

;;;
;;; This code may be used and modified, and redistributed in binary
;;; or source form, subject to the "CCL Public License", which should
;;; accompany it. This license is a variant on the BSD license, and thus
;;; permits use of code derived from this in either open and commercial
;;; projects: but it does require that updates to this code be made
;;; available back to the originators of the package. Note that as with
;;; any BSD-style licenses the terms here are not compatible with the GNU
;;; public license, and so GPL code should not be combined with the material
;;; here in any way.
;;;
;;; Parts of the Lisp code here are or have been derived from the Spice
;;; Common Lisp code-base, that was placed in the Public Domain. Thus
;;; public domain versions of some of these files may also be available.
;;; The versions here will have been selected, customised and arranged
;;; for use with CCL. "Thank you very much, Spice People".
;;;


(in-package "LISP")

(defstruct pathname host device directory name type version)

(defun pathname (xx)  ;; arg is pathname or string. return pathname
   xx)

(defun truename (xx) xx)

(defun parse-namestring (xx) xx)

(defun merge-pathnames (xx) xx)

(defun namestring (xx) xx)

(defun file-namestring (xx) xx)

(defun directory-namestring (xx) xx)

(defun host-namestring (xx) xx)

(defun enough-namestring (xx) xx)

;; end of path.lsp

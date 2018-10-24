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


;;; generic sequence functions

(eval-when
   (compile load eval)
   ;;; Seq-Dispatch does an efficient type-dispatch on the given Sequence.
   (defmacro seq-dispatch (sequence list-form array-form)
      `(if (listp ,sequence) ,list-form ,array-form))
   (defmacro elt-slice (sequences n)
   "Returns a list of the Nth element of each of the sequences.  Used by MAP
         and friends."
      `(mapcar #'(lambda (seq) (elt seq ,n)) ,sequences))
   (defmacro make-sequence-like (sequence length)
      "Returns a sequence of the same type as SEQUENCE and the given LENGTH."
      `(make-sequence-of-type (type-of ,sequence) ,length)))


;;; This is called in SORT, so we don't just eval-when compile it.
(defmacro type-specifier (type)
   "Returns the broad class of which TYPE is a specific subclass."
   `(if (atom ,type) ,type (car ,type)))


(defun make-sequence-of-type (type length)
   "Returns a sequence of the given TYPE and LENGTH."
   (declare (fixnum length))
   (case
      (type-specifier type)
      (list (make-list length))
      ((bit-vector simple-bit-vector)
         (make-array length :element-type '(mod 2)))
      ((string simple-string) (make-string length))
      (simple-vector (make-array length))
      ((array simple-array vector)
         (if
            (listp type)
            (make-array length :element-type (cadr type))
            (make-array length)))
      (t (error (format nil "~S is a bad type specifier for sequence functions." type)))))


;(defun identity (thing)
;   "Returns what was passed to it.  Default for :key options."
;   thing)

;; (defun elt (sequence index)
;;    "Returns the element of SEQUENCE specified by INDEX."
;;    (if
;;       (listp sequence)
;;       (if
;;          (< index 0)
;;          (error "~S: index too small." index)
;;          (do
;;             ((count index (\1- count)))
;;             ((= count 0) (car sequence))
;;             (if
;;                (atom sequence)
;;                (error "~S: index too large." index)
;;                (setq sequence (cdr sequence)))) )
;;       (aref sequence index)))


;; (defun setelt (sequence index newval)
;;    "Store NEWVAL as the component of SEQUENCE specified by INDEX."
;;    (if
;;       (listp sequence)
;;       (if
;;          (< index 0)
;;          (error "~S: index too small." index)
;;          (do
;;             ((count index (\1- count)) (seq sequence))
;;             ((= count 0) (rplaca seq newval) sequence)
;;             (if
;;                (atom (cdr seq))
;;                (error "~S: index too large." index)
;;                (setq seq (cdr seq)))) )
;;       (setf (aref sequence index) newval)))


;; (defun length (sequence)
;;   "Returns an integer that is the length of SEQUENCE."
;;   (%primitive length sequence))

;; (defun list-length* (sequence)
;;   (do
;;      ((count 0 (\1+ count)))
;;      ((atom sequence) count)
;;      (setq sequence (cdr sequence))))


(defun make-sequence (type length &key initial-element)
   "Returns a sequence of the given Type and Length, with elements
    initialized to :Initial-Element."
   (declare (fixnum length))
   (case
      (type-specifier type)
      (list (make-list length :initial-element initial-element))
      ((simple-string string)
         (if
            initial-element
            (do
               ((index 0 (\1+ index)) (string (make-string length)))
               ((= index length) string)
               (setf
                  (char (the simple-string string) index)
                  initial-element))
            (make-string length)))
      ((array vector simple-vector)
         (if
            (listp type)
            (make-array length :element-type (cadr type) :initial-element
               initial-element)
            (make-array length :initial-element initial-element)))
      ((bit-vector simple-bit-vector)
         (make-array length :element-type '(mod 2) :initial-element
            initial-element))
      (t (error (format nil "~S is a bad type specifier for sequences." type)))))


;;; Subseq:
;;MCD (defun vector-subseq* (sequence start &optional end)
;;MCD    (declare (vector sequence))
;;MCD    (when (null end) (setq end (length sequence)))
;;MCD    (do
;;MCD       ((old-index start (\1+ old-index))
;;MCD          (new-index 0 (\1+ new-index))
;;MCD          (copy (make-sequence-like sequence (- end start))))
;;MCD       ((= old-index end) copy)
;;MCD       (setf (aref copy new-index) (aref sequence old-index))))
;;MCD 
;;MCD 
;;MCD (defun list-subseq* (sequence start &optional end)
;;MCD    (declare (list sequence))
;;MCD    (if
;;MCD       (and end (>= start end))
;;MCD       ()
;;MCD       (let*
;;MCD          ((groveled (nthcdr start sequence)) (result (list (car groveled))))
;;MCD          (if
;;MCD             groveled
;;MCD             (do
;;MCD                ((list (cdr groveled) (cdr list))
;;MCD                   (splice result (cdr (rplacd splice (list (car list)))) )
;;MCD                   (index (\1+ start) (\1+ index)))
;;MCD                ((or (atom list) (and end (= index end))) result))
;;MCD             ()))) )
;;MCD 
;;MCD
;;MCD (defun subseq (sequence start &optional end)
;;MCD    "Returns a copy of a subsequence of SEQUENCE starting with element number
;;MCD       START and continuing to the end of SEQUENCE or the optional END."
;;MCD    (if (null end) 
;;MCD      (seq-dispatch sequence
;;MCD         (list-subseq* sequence start)
;;MCD         (vector-subseq* sequence start))
;;MCD      (seq-dispatch sequence
;;MCD         (list-subseq* sequence start end)
;;MCD         (vector-subseq* sequence start end))))


;;; Copy-seq:

(eval-when
   (compile eval)
   (defmacro vector-copy-seq (sequence type)
      `(let
         ((length (length (the vector ,sequence))))
         (do
            ((index 0 (\1+ index))
               (copy (make-sequence-of-type ,type length)))
            ((= index length) copy)
            (setf (aref copy index) (aref ,sequence index)))) )
   (defmacro list-copy-seq (list)
      `(if
         (atom ,list)
         '()
         (let
            ((result (cons (car ,list) '())))
            (do
               ((x (cdr ,list) (cdr x))
                  (splice result (cdr (rplacd splice (cons (car x) '()))) ))
               ((atom x) (unless (null x) (rplacd splice x)) result)))) ))


(defun copy-seq (sequence)
   "Returns a copy of SEQUENCE which is EQUAL to SEQUENCE but not EQ."
   (seq-dispatch
      sequence
      (list-copy-seq* sequence)
      (vector-copy-seq* sequence)))


;;; Internal Frobs:
(defun list-copy-seq* (sequence) (list-copy-seq sequence))


(defun vector-copy-seq* (sequence)
   (vector-copy-seq sequence (type-of sequence)))


;;; Fill:

(eval-when
   (compile eval)
   (defmacro vector-fill (sequence item start end)
      `(do
         ((index ,start (\1+ index)))
         ((= index ,end) ,sequence)
         (setf (aref ,sequence index) ,item)))
   (defmacro list-fill (sequence item start end)
      `(do
         ((current (nthcdr ,start ,sequence) (cdr current))
            (index ,start (\1+ index)))
         ((or (atom current) (= index ,end)) sequence)
         (rplaca current ,item))))


(defun list-fill* (sequence item start end)
   (declare (list sequence))
   (if (not end) (setq end (length sequence)))
   (list-fill sequence item start end))


(defun vector-fill* (sequence item start end)
   (declare (vector sequence))
   (when (null end) (setq end (length sequence)))
   (vector-fill sequence item start end))


(defun fill (sequence item &key (start 0) end)
   "Replace the specified elements of SEQUENCE with ITEM."
   (seq-dispatch
      sequence
      (list-fill* sequence item start end)
      (vector-fill* sequence item start end)))


;;; Replace:

(eval-when
   (compile eval)
   ;;; If we are copying around in the same vector, be careful not to
   ;;; copy the same elements over repeatedly.  We do this by copying
   ;;; backwards.
   (defmacro mumble-replace-from-mumble ()
      `(if
         (and
            (eq target-sequence source-sequence)
            (> target-start source-start))
         (let
            ((nelts
                (min
                   (- target-end target-start)
                   (- source-end source-start))))
            (do
               ((target-index (+ target-start nelts -1) (\1- target-index))
                  (source-index
                     (+ source-start nelts -1)
                     (\1- source-index)))
               ((= target-index (\1- target-start)) target-sequence)
               (setf
                  (aref target-sequence target-index)
                  (aref source-sequence source-index))))
         (do
            ((target-index target-start (\1+ target-index))
               (source-index source-start (\1+ source-index)))
            ((or (= target-index target-end) (= source-index source-end))
               target-sequence)
            (setf
               (aref target-sequence target-index)
               (aref source-sequence source-index)))) )
   (defmacro list-replace-from-list ()
      `(if
         (and
            (eq target-sequence source-sequence)
            (> target-start source-start))
         (let
            ((new-elts
                (subseq
                   source-sequence
                   source-start
                   (+
                      source-start
                      (min
                         (- target-end target-start)
                         (- source-end source-start)))) ))
            (do
               ((n new-elts (cdr n))
                  (o (nthcdr target-start target-sequence) (cdr o)))
               ((null n) target-sequence)
               (rplaca o (car n))))
         (do
            ((target-index target-start (\1+ target-index))
               (source-index source-start (\1+ source-index))
               (target-sequence-ref
                  (nthcdr target-start target-sequence)
                  (cdr target-sequence-ref))
               (source-sequence-ref
                  (nthcdr source-start source-sequence)
                  (cdr source-sequence-ref)))
            ((or
                (= target-index target-end)
                (= source-index source-end)
                (null target-sequence-ref)
                (null source-sequence-ref))
               target-sequence)
            (rplaca target-sequence-ref (car source-sequence-ref)))) )
   (defmacro list-replace-from-mumble ()
      `(do
         ((target-index target-start (\1+ target-index))
            (source-index source-start (\1+ source-index))
            (target-sequence-ref
               (nthcdr target-start target-sequence)
               (cdr target-sequence-ref)))
         ((or
             (= target-index target-end)
             (= source-index source-end)
             (null target-sequence-ref))
            target-sequence)
         (rplaca target-sequence-ref (aref source-sequence source-index))))
   (defmacro mumble-replace-from-list ()
      `(do
         ((target-index target-start (\1+ target-index))
            (source-index source-start (\1+ source-index))
            (source-sequence
               (nthcdr source-start source-sequence)
               (cdr source-sequence)))
         ((or
             (= target-index target-end)
             (= source-index source-end)
             (null source-sequence))
            target-sequence)
         (setf (aref target-sequence target-index) (car source-sequence)))) )


(defun list-replace-from-list* (target-sequence
      source-sequence
      target-start
      target-end
      source-start
      source-end)
   (when (null target-end) (setq target-end (length target-sequence)))
   (when (null source-end) (setq source-end (length source-sequence)))
   (list-replace-from-list))


(defun list-replace-from-vector* (target-sequence
      source-sequence
      target-start
      target-end
      source-start
      source-end)
   (when (null target-end) (setq target-end (length target-sequence)))
   (when (null source-end) (setq source-end (length source-sequence)))
   (list-replace-from-mumble))


(defun vector-replace-from-list* (target-sequence
      source-sequence
      target-start
      target-end
      source-start
      source-end)
   (when (null target-end) (setq target-end (length target-sequence)))
   (when (null source-end) (setq source-end (length source-sequence)))
   (mumble-replace-from-list))


(defun vector-replace-from-vector* (target-sequence
      source-sequence
      target-start
      target-end
      source-start
      source-end)
   (when (null target-end) (setq target-end (length target-sequence)))
   (when (null source-end) (setq source-end (length source-sequence)))
   (mumble-replace-from-mumble))


(defun replace (target-sequence
      source-sequence
      &key
      ((:start1 target-start) 0)
      ((:end1 target-end))
      ((:start2 source-start) 0)
      ((:end2 source-end)))
   "The target sequence is destructively modified by copying successive
      elements into it from the source sequence."
   (unless target-end (setq target-end (length target-sequence)))
   (unless source-end (setq source-end (length source-sequence)))
   (seq-dispatch
      target-sequence
      (seq-dispatch
         source-sequence
         (list-replace-from-list)
         (list-replace-from-mumble))
      (seq-dispatch
         source-sequence
         (mumble-replace-from-list)
         (mumble-replace-from-mumble))))


;;; Reverse:

(eval-when
   (compile eval)
   (defmacro vector-reverse (sequence type)
      `(let
         ((length (length ,sequence)))
         (do
            ((forward-index 0 (\1+ forward-index))
               (backward-index (\1- length) (\1- backward-index))
               (new-sequence (make-sequence-of-type ,type length)))
            ((= forward-index length) new-sequence)
            (setf
               (aref new-sequence forward-index)
               (aref ,sequence backward-index)))) )
   (defmacro list-reverse-macro (sequence)
      `(do
         ((new-list ()))
         ((atom ,sequence) new-list)
         (push (pop ,sequence) new-list))))


;;; Internal Frobs:
(defun list-reverse* (sequence) (list-reverse-macro sequence))


(defun vector-reverse* (sequence)
   (vector-reverse sequence (type-of sequence)))


(defun reverse (sequence)
   "Returns a new sequence containing the same elements but in
    reverse order."
   (seq-dispatch
      sequence
      (list-reverse* sequence)
      (vector-reverse* sequence)))


;;; Nreverse:

; (eval-when
;    (compile eval)
;    (defmacro vector-nreverse (sequence)
;       `(let
;          ((length (length (the vector ,sequence))))
;          (do
;             ((left-index 0 (\1+ left-index))
;                (right-index (\1- length) (\1- right-index))
;                (half-length (truncate length 2)))
;             ((= left-index half-length) ,sequence)
;             (rotatef
;                (aref ,sequence left-index)
;                (aref ,sequence right-index)))) )
;  (defmacro list-nreverse-macro (list)
;     `(do
;        ((\1st (cdr ,list) (if (atom \1st) \1st (cdr \1st)))
;           (\2nd ,list \1st)
;           (\3rd '() \2nd))
;        ((atom \2nd) \3rd)
;        (rplacd \2nd \3rd)))
; )


;; (defun list-nreverse* (sequence) (list-nreverse-macro sequence))


;; (defun vector-nreverse* (sequence) (vector-nreverse sequence))


; (defun nreverse (sequence)
;    "Returns a sequence of the same elements in reverse order; the argument
;       is destroyed."
;    (seq-dispatch
;       sequence
;       (reversip sequence)
;       (vector-nreverse* sequence)))


;;; Concatenate:

(eval-when
   (compile eval)
   (defmacro concatenate-to-list (sequences)
      `(let
         ((result (list nil)))
         (do
            ((sequences ,sequences (cdr sequences)) (splice result))
            ((null sequences) (cdr result))
            (let
               ((sequence (car sequences)))
               (seq-dispatch
                  sequence
                  (do
                     ((sequence sequence (cdr sequence)))
                     ((atom sequence))
                     (setq splice
                        (cdr (rplacd splice (list (car sequence)))) ))
                  (do
                     ((index 0 (\1+ index)) (length (length sequence)))
                     ((= index length))
                     (setq splice
                        (cdr
                           (rplacd
                              splice
                              (list (aref sequence index)))) ))) ))) )
   (defmacro concatenate-to-mumble (output-type-spec sequences)
      `(do
         ((seqs ,sequences (cdr seqs)) (total-length 0) (lengths ()))
         ((null seqs)
            (do
               ((sequences ,sequences (cdr sequences))
                  (lengths lengths (cdr lengths))
                  (index 0)
                  (result
                     (make-sequence-of-type ,output-type-spec total-length)))
               ((= index total-length) result)
               (let
                  ((sequence (car sequences)))
                  (seq-dispatch
                     sequence
                     (do
                        ((sequence sequence (cdr sequence)))
                        ((atom sequence))
                        (setf (aref result index) (car sequence))
                        (setq index (\1+ index)))
                     (do
                        ((jndex 0 (\1+ jndex)))
                        ((= jndex (car lengths)))
                        (setf (aref result index) (aref sequence jndex))
                        (setq index (\1+ index)))) )))
         (let
            ((length (length (car seqs))))
            (setq lengths (nconc lengths (list length)))
            (setq total-length (+ total-length length)))) ))


;;; Internal Frobs:
(defun concat-to-list* (&rest sequences) (concatenate-to-list sequences))


(defun concat-to-simple* (type &rest sequences)
   (concatenate-to-mumble type sequences))


(defun concatenate (output-type-spec &rest sequences)
   "Returns a new sequence of all the argument sequences concatenated
      together which shares no structure with the original argument
      sequences of the specified OUTPUT-TYPE-SPEC."
   (case
      (type-specifier output-type-spec)
      (list (apply #'concat-to-list* sequences))
      ((simple-vector simple-string vector string array)
         (apply #'concat-to-simple* output-type-spec sequences))
      (t (error (format nil "~S: invalid output type specification." output-type-spec)))))


;;; Map:

(eval-when
   (compile eval)
   (defmacro map-to-list (function sequences)
      `(do
         ((seqs more-sequences (cdr seqs))
            (min-length (length first-sequence)))
         ((null seqs)
            (let
               ((result (list nil)))
               (do
                  ((index 0 (\1+ index)) (splice result))
                  ((= index min-length) (cdr result))
                  (setq splice
                     (cdr
                        (rplacd
                           splice
                           (list
                              (apply
                                 ,function
                                 (elt-slice ,sequences index)))) ))) ))
         (let
            ((length (length (car seqs))))
            (if (< length min-length) (setq min-length length)))) )
   (defmacro map-to-simple (output-type-spec function sequences)
      `(do
         ((seqs more-sequences (cdr seqs))
            (min-length (length first-sequence)))
         ((null seqs)
            (do
               ((index 0 (\1+ index))
                  (result
                     (make-sequence-of-type ,output-type-spec min-length)))
               ((= index min-length) result)
               (setf
                  (aref result index)
                  (apply ,function (elt-slice ,sequences index)))) )
         (let
            ((length (length (car seqs))))
            (if (< length min-length) (setq min-length length)))) )
   (defmacro map-for-effect (function sequences)
      `(do
         ((seqs more-sequences (cdr seqs))
            (min-length (length first-sequence)))
         ((null seqs)
            (do
               ((index 0 (\1+ index)))
               ((= index min-length) nil)
               (apply ,function (elt-slice ,sequences index))))
         (let
            ((length (length (car seqs))))
            (if (< length min-length) (setq min-length length)))) ))


(defun map (output-type-spec function first-sequence &rest more-sequences)
   "FUNCTION must take as many arguments as there are sequences provided.
    The result is a sequence such that element i is the result of applying
    FUNCTION to element i of each of the argument sequences."
   (let
      ((sequences (cons first-sequence more-sequences)))
      (case
         (type-specifier output-type-spec)
         (nil (map-for-effect function sequences))
         (list (map-to-list function sequences))
         ((simple-vector simple-string vector array string)
            (map-to-simple output-type-spec function sequences))
         (t (error (format nil
                           "~S: invalid output type specifier."
                           output-type-spec))))) )


;;; Quantifiers:
(defun some (predicate first-sequence &rest more-sequences)
   "PREDICATE is applied to the elements with index 0 of the sequences, then
      possibly to those with index 1, and so on.  SOME returns the first
      non-() value encountered, or () if the end of a sequence is reached."
   (do
      ((seqs more-sequences (cdr seqs))
         (length (length first-sequence))
         (sequences (cons first-sequence more-sequences)))
      ((null seqs)
         (do
            ((index 0 (\1+ index)))
            ((= index length) ())
            (let
               ((result (apply predicate (elt-slice sequences index))))
               (if result (return result)))) )
      (let
         ((this (length (car seqs))))
         (if (< this length) (setq length this)))) )


(defun every (predicate first-sequence &rest more-sequences)
   "PREDICATE is applied to the elements with index 0 of the sequences, then
      possibly to those with index 1, and so on.  EVERY returns () as soon
      as any invocation of PREDICATE returns (), or T if every invocation
      is non-()."
   (do
      ((seqs more-sequences (cdr seqs))
         (length (length first-sequence))
         (sequences (cons first-sequence more-sequences)))
      ((null seqs)
         (do
            ((index 0 (\1+ index)))
            ((= index length) t)
            (let
               ((result (apply predicate (elt-slice sequences index))))
               (if (not result) (return ()))) ))
      (let
         ((this (length (car seqs))))
         (if (< this length) (setq length this)))) )


(defun notany (predicate first-sequence &rest more-sequences)
   "PREDICATE is applied to the elements with index 0 of the sequences, then
      possibly to those with index 1, and so on.  NOTANY returns () as soon
      as any invocation of PREDICATE returns a non-() value, or T if the end
      of a sequence is reached."
   (do
      ((seqs more-sequences (cdr seqs))
         (length (length first-sequence))
         (sequences (cons first-sequence more-sequences)))
      ((null seqs)
         (do
            ((index 0 (\1+ index)))
            ((= index length) t)
            (let
               ((result (apply predicate (elt-slice sequences index))))
               (if result (return ()))) ))
      (let
         ((this (length (car seqs))))
         (if (< this length) (setq length this)))) )


(defun notevery (predicate first-sequence &rest more-sequences)
   "PREDICATE is applied to the elements with index 0 of the sequences, then
      possibly to those with index 1, and so on.  NOTEVERY returns T as soon
      as any invocation of PREDICATE returns (), or () if every invocation
      is non-()."
   (do
      ((seqs more-sequences (cdr seqs))
         (length (length first-sequence))
         (sequences (cons first-sequence more-sequences)))
      ((null seqs)
         (do
            ((index 0 (\1+ index)))
            ((= index length) ())
            (let
               ((result (apply predicate (elt-slice sequences index))))
               (if (not result) (return t)))) )
      (let
         ((this (length (car seqs))))
         (if (< this length) (setq length this)))) )


;;; Reduce:

(eval-when
   (compile eval)
   (defmacro mumble-reduce (function sequence start end initial-value ref)
      `(do
         ((index ,start (\1+ index)) (value ,initial-value))
         ((= index ,end) value)
         (setq value (funcall ,function value (,ref ,sequence index)))) )
   (defmacro mumble-reduce-from-end (function
         sequence
         start
         end
         initial-value
         ref)
      `(do
         ((index (\1- ,end) (\1- index))
            (value ,initial-value)
            (terminus (\1- ,start)))
         ((= index terminus) value)
         (setq value (funcall ,function (,ref ,sequence index) value))))
   (defmacro list-reduce (function sequence start end
                          initial-value initial-value-p)
      `(let
         ((sequence (nthcdr ,start ,sequence)))
         (do
            ((count (if ,initial-value-p ,start (\1+ ,start)) (\1+ count))
               (sequence
                  (if ,initial-value-p sequence (cdr sequence))
                  (cdr sequence))
               (value
                  (if ,initial-value-p ,initial-value (car sequence))
                  (funcall ,function value (car sequence))))
            ((= count ,end) value))))
   (defmacro list-reduce-from-end (function sequence start end
                                   initial-value initial-value-p)
      `(let
         ((sequence
             (nthcdr (- (length ,sequence) ,end) (reverse ,sequence))))
         (do
            ((count (if ,initial-value-p ,start (\1+ ,start)) (\1+ count))
               (sequence
                  (if ,initial-value-p sequence (cdr sequence))
                  (cdr sequence))
               (value
                  (if ,initial-value-p ,initial-value (car sequence))
                  (funcall ,function (car sequence) value)))
            ((= count ,end) value)))) )


(defun reduce (function sequence &key from-end (start 0)
      (end (length sequence)) (initial-value nil initial-value-p))
   "The specified Sequence is ``reduced'' using the given Function.
     See manual for details."
   (cond
      ((= end start) (if initial-value-p initial-value (funcall function)))
      ((listp sequence)
         (if
            from-end
            (list-reduce-from-end function sequence start end
                                  initial-value initial-value-p)
            (list-reduce function sequence start end
                                  initial-value initial-value-p)))
      (t (if
            from-end
            (cond
               ((not (slisp-array-p sequence))
                  (when
                     (not initial-value-p)
                     (setq end (\1- end))
                     (setq initial-value (aref sequence end)))
                  (mumble-reduce-from-end function sequence start end
                     initial-value aref))
               (t (when
                     (not initial-value-p)
                     (setq end (\1- end))
                     (setq initial-value (aref sequence end)))
                  (mumble-reduce-from-end function sequence start end
                     initial-value aref)))
            (cond
               ((not (slisp-array-p sequence))
                  (when
                     (not initial-value-p)
                     (setq initial-value (aref sequence start))
                     (setq start (\1+ start)))
                  (mumble-reduce function sequence start end initial-value
                     aref))
               (t (when
                     (not initial-value-p)
                     (setq initial-value (aref sequence start))
                     (setq start (\1+ start)))
                  (mumble-reduce function sequence start end initial-value
                     aref)))) )))


;;; Coerce:

;;; Internal Frobs:
(defun list-to-string* (object)
   (do*
      ((index 0 (\1+ index))
         (length (length object))
         (result (make-string length)))
      ((= index length) result)
      (setf (schar result index) (pop object))))


(defun list-to-bit-vector* (object)
   (do*
      ((index 0 (\1+ index))
         (length (length object))
         (result (make-array length :element-type '(mod 2))))
      ((= index length) result)
      (declare (fixnum length))
      (setf (sbit result index) (pop object))))


(defun list-to-vector* (object type)
   (do*
      ((index 0 (\1+ index))
         (length (length object))
         (result (make-sequence-of-type type length)))
      ((= index length) result)
      (setf (aref result index) (pop object))))


(defun vector-to-list* (object)
   (let
      ((result (list nil)) (length (length object)))
      (do
         ((index 0 (\1+ index)) (splice result (cdr splice)))
         ((= index length) (cdr result))
         (rplacd splice (list (aref object index)))) ))


(defun vector-to-vector* (object type)
   (do*
      ((index 0 (\1+ index))
         (length (length object))
         (result (make-sequence-of-type type length)))
      ((= index length) result)
      (setf (aref result index) (aref object index))))


(defun vector-to-string* (object)
   (do*
      ((index 0 (\1+ index))
         (length (length object))
         (result (make-string length)))
      ((= index length) result)
      (setf (schar result index) (aref object index))))


(defun vector-to-bit-vector* (object)
   (do*
      ((index 0 (\1+ index))
         (length (length object))
         (result (make-array length :element-type '(mod 2))))
      ((= index length) result)
      (declare (fixnum length))
      (setf (sbit result index) (aref object index))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; This needs work
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun string-to-simple-string* (object)
   (if (stringp object)
       object
       (error "String required")))

;;  (defun string-to-simple-string* (object)
;;     (if
;;        (simple-string-p object)
;;        object
;;        (let
;;           ((displacement
;;               (%primitive header-ref object %array-displacement-slot)))
;;           (subseq
;;              (the
;;                 simple-string
;;                 (%primitive header-ref object %array-data-slot))
;;              displacement
;;              (+
;;                 displacement
;;                 (%primitive header-ref object %array-fill-pointer-slot)))) ))

(defun bit-vector-to-simple-bit-vector* (object)
   (error "Bit vectors not supported at present"))

;;  (defun bit-vector-to-simple-bit-vector* (object)
;;     (if
;;        (simple-bit-vector-p object)
;;        object
;;        (let
;;           ((displacement
;;               (%primitive header-ref object %array-displacement-slot)))
;;           (subseq
;;              (the
;;                 simple-bit-vector
;;                 (%primitive header-ref object %array-data-slot))
;;              displacement
;;              (+
;;                 displacement
;;                 (%primitive header-ref object %array-fill-pointer-slot)))) ))


;; main entrypoint

(defun coerce (object output-type-spec)
  "Coerces the Object to an object of type Output-Type-Spec."
  (cond
   ((typep object output-type-spec) object)
   ((eq output-type-spec 'character) (character object))
   ((numberp object)
    (case
      output-type-spec
      (short-float  (float object 1.0s0))
      (single-float (float object 1.0e0)) ;; short float
      ((double-float long-float) (float object 1.0d0))  ;; long float
      (complex (complex object 0.0d0))
      (t (error (format nil
			"~S can't be converted to type ~S."
			object
			output-type-spec)))))
   (t (typecase
        object
	(list
	 (case (type-specifier output-type-spec)
	   ((simple-string string) (list-to-string* object))
	   ((simple-bit-vector bit-vector)
	    (list-to-bit-vector* object))
	   ((simple-vector vector array)
	    (list-to-vector* object output-type-spec))
	   (t (error (format nil
			     "Can't coerce ~S to type ~S."
			     object
			     output-type-spec)))))
	(simple-string
	 (case
	     (type-specifier output-type-spec)
	   (list (vector-to-list* object))
	   ;; Can't coerce a string to a bit-vector!
	   ((simple-vector vector array)
	    (vector-to-vector* object output-type-spec))
	   (t (error (format nil
			     "Can't coerce ~S to type ~S."
			     object
			     output-type-spec)))))
	(simple-bit-vector
	 (case
	     (type-specifier output-type-spec)
	   (list (vector-to-list* object))
	   ;; Can't coerce a bit-vector to a string!
	   ((simple-vector vector array)
	    (vector-to-vector* object output-type-spec))
	   (t (error (format nil
			     "Can't coerce ~S to type ~S."
			     object
			     output-type-spec)))))
	(simple-vector
	 (case
	     (type-specifier output-type-spec)
	   (list (vector-to-list* object))
	   ((simple-string string) (vector-to-string* object))
	   ((simple-bit-vector bit-vector)
	    (vector-to-bit-vector* object))
	   ((vector array)
	    (vector-to-vector* object output-type-spec))
	   (t (error (format nil
			     "Can't coerce ~S to type ~S."
			     object
			     output-type-spec)))))
	(string
	 (case
	     (type-specifier output-type-spec)
	   (list (vector-to-list* object))
	   (simple-string (string-to-simple-string* object))
	   ;; Can't coerce a string to a bit-vector!
	   ((simple-vector vector array)
	    (vector-to-vector* object output-type-spec))
	   (t (error (format nil
			     "Can't coerce ~S to type ~S."
			     object
			     output-type-spec)))))
	(bit-vector
	 (case
	     (type-specifier output-type-spec)
	   (list (vector-to-list* object))
	   ;; Can't coerce a bit-vector to a string!
	   (simple-bit-vector
	    (bit-vector-to-simple-bit-vector* object))
	   ((simple-vector vector array)
	    (vector-to-vector* object output-type-spec))
	   (t (error (format nil
			     "Can't coerce ~S to type ~S."
			     object
			     output-type-spec)))))
	(vector
	 (case
	     (type-specifier output-type-spec)
	   (list (vector-to-list* object))
	   ((simple-string string) (vector-to-string* object))
	   ((simple-bit-vector bit-vector)
	    (vector-to-bit-vector* object))
	   ((simple-vector vector array)
	    (vector-to-vector* object output-type-spec))
	   (t (error (format nil
			     "Can't coerce ~S to type ~S."
			     object
			     output-type-spec)))))
	(t (error (format nil
			  "~S is an inappropriate type of object for coerce."
			  object))))) ))


;
;;; Delete:

(eval-when
   (compile eval)
   (defmacro mumble-delete (pred)
      `(do
         ((index start (\1+ index)) (jndex start) (number-zapped 0))
         ((or (= index end) (= number-zapped count))
            (do
               ((index index (\1+ index))
                  ; copy the rest of the vector
                  (jndex jndex (\1+ jndex)))
               ((= index length) (shrink-vector sequence jndex))
               (setf (aref sequence jndex) (aref sequence index))))
         (setf (aref sequence jndex) (aref sequence index))
         (if
            ,pred
            (setq number-zapped (\1+ number-zapped))
            (setq jndex (\1+ jndex)))) )
   (defmacro mumble-delete-from-end (pred)
      `(do
         ((index (\1- end) (\1- index))
            ; find the losers
            (number-zapped 0)
            (losers ())
            this-element
            (terminus (\1- start)))
         ((or (= index terminus) (= number-zapped count))
            (do
               ((losers losers)
                  ; delete the losers
                  (index start (\1+ index))
                  (jndex start))
               ((or (null losers) (= index end))
                  (do
                     ((index index (\1+ index))
                        ; copy the rest of the vector
                        (jndex jndex (\1+ jndex)))
                     ((= index length) (shrink-vector sequence jndex))
                     (setf (aref sequence jndex) (aref sequence index))))
               (setf (aref sequence jndex) (aref sequence index))
               (if
                  (= index (car losers))
                  (pop losers)
                  (setq jndex (\1+ jndex)))) )
         (setq this-element (aref sequence index))
         (when
            ,pred
            (setq number-zapped (\1+ number-zapped))
            (push index losers))))
   (defmacro normal-mumble-delete ()
      `(mumble-delete
         (if
            test-not
            (not (funcall test-not item (funcall key (aref sequence index))))
            (funcall test item (funcall key (aref sequence index)))) ))
   (defmacro normal-mumble-delete-from-end ()
      `(mumble-delete-from-end
         (if
            test-not
            (not (funcall test-not item (funcall key (aref sequence index))))
            (funcall test item (funcall key (aref sequence index)))) ))
   (defmacro list-delete (pred)
      `(let
         ((handle (cons nil sequence)))
         (do
            ((current (nthcdr start sequence) (cdr current))
               (previous (nthcdr start handle))
               (index start (\1+ index))
               (number-zapped 0))
            ((or (= index end) (= number-zapped count)) (cdr handle))
            (cond
               (,pred
                  (rplacd previous (cdr current))
                  (setq number-zapped (\1+ number-zapped)))
               (t (setq previous (cdr previous)))) )))
   (defmacro list-delete-from-end (pred)
      `(let*
         ((reverse (nreverse (the list sequence)))
            (handle (cons nil reverse)))
         (do
            ((current (nthcdr (- length end) reverse) (cdr current))
               (previous (nthcdr (- length end) handle))
               (index start (\1+ index))
               (number-zapped 0))
            ((or (= index end) (= number-zapped count))
               (nreverse (cdr handle)))
            (cond
               (,pred
                  (rplacd previous (cdr current))
                  (setq number-zapped (\1+ number-zapped)))
               (t (setq previous (cdr previous)))) )))
   (defmacro normal-list-delete ()
      '(list-delete
         (if
            test-not
            (not (funcall test-not item (funcall key (car current))))
            (funcall test item (funcall key (car current)))) ))
   (defmacro normal-list-delete-from-end ()
      '(list-delete-from-end
         (if
            test-not
            (not (funcall test-not item (funcall key (car current))))
            (funcall test item (funcall key (car current)))) )))


(defun delete (item sequence &key from-end (test #'eql) test-not (start 0)
      (end (length sequence)) (count most-positive-fixnum) (key #'identity))
   "Returns a sequence formed by destructively removing the specified
     Item from the given Sequence."
   (let
      ((length (length sequence)))
      (seq-dispatch
         sequence
         (if from-end (normal-list-delete-from-end) (normal-list-delete))
         (if
            from-end
            (normal-mumble-delete-from-end)
            (normal-mumble-delete)))) )


(eval-when
   (compile eval)
   (defmacro if-mumble-delete ()
      `(mumble-delete
         (funcall predicate (funcall key (aref sequence index)))) )
   (defmacro if-mumble-delete-from-end ()
      `(mumble-delete-from-end
         (funcall predicate (funcall key (aref sequence index)))) )
   (defmacro if-list-delete ()
      '(list-delete (funcall predicate (funcall key (car current)))) )
   (defmacro if-list-delete-from-end ()
      '(list-delete-from-end
         (funcall predicate (funcall key (car current)))) ))


(defun delete-if (predicate sequence &key from-end (start 0) (key #'identity)
      (end (length sequence)) (count most-positive-fixnum))
   "Returns a sequence formed by destructively removing the elements
    satisfying the specified Predicate from the given Sequence."
   (let
      ((length (length sequence)))
      (seq-dispatch
         sequence
         (if from-end (if-list-delete-from-end) (if-list-delete))
         (if from-end (if-mumble-delete-from-end) (if-mumble-delete)))) )


(eval-when
   (compile eval)
   (defmacro if-not-mumble-delete ()
      `(mumble-delete
         (not (funcall predicate (funcall key (aref sequence index)))) ))
   (defmacro if-not-mumble-delete-from-end ()
      `(mumble-delete-from-end
         (not (funcall predicate (funcall key (aref sequence index)))) ))
   (defmacro if-not-list-delete ()
      '(list-delete (funcall predicate (funcall key (car current)))) )
   (defmacro if-not-list-delete-from-end ()
      '(list-delete-from-end
         (funcall predicate (funcall key (car current)))) ))


(defun delete-if-not (predicate sequence &key from-end (start 0)
      (end (length sequence)) (key #'identity) (count most-positive-fixnum))
   "Returns a sequence formed by destructively removing the elements not
     satisfying the specified Predicate from the given Sequence."
   (let
      ((length (length sequence)))
      (seq-dispatch
         sequence
         (if from-end (if-not-list-delete-from-end) (if-not-list-delete))
         (if
            from-end
            (if-not-mumble-delete-from-end)
            (if-not-mumble-delete)))) )


;;; Remove:

(eval-when
   (compile eval)
   (defmacro mumble-remove-macro (bump left begin finish right pred)
      `(do
         ((index ,begin (,bump index))
            (result
               (do
                  ((index ,left (,bump index))
                     (result (make-sequence-like sequence length)))
                  ((= index ,begin) result)
                  (setf (aref result index) (aref sequence index))))
            (new-index ,begin)
            (number-zapped 0)
            (this-element))
         ((or (= index ,finish) (= number-zapped count))
            (do
               ((index index (,bump index))
                  (new-index new-index (,bump new-index)))
               ((= index ,right) (shrink-vector result new-index))
               (setf (aref result new-index) (aref sequence index))))
         (setq this-element (aref sequence index))
         (cond
            (,pred
               (setf (aref result new-index) this-element)
               (setq new-index (,bump new-index)))
            (t (setq number-zapped (\1+ number-zapped)))) ))
   (defmacro mumble-remove (pred)
      `(mumble-remove-macro \1+ 0 start end length ,pred))
   ;;; Just copy it over and call the delete function, but reverse the
   ;;; predicate, because delete functions work that way.
   (defmacro mumble-remove-from-end (pred)
      `(let
         ((sequence (copy-seq sequence)))
         (mumble-delete-from-end (not ,pred))))
   (defmacro normal-mumble-remove ()
      `(mumble-remove
         (if
            test-not
            (funcall test-not item (funcall key this-element))
            (not (funcall test item (funcall key this-element)))) ))
   (defmacro normal-mumble-remove-from-end ()
      `(mumble-remove-from-end
         (if
            test-not
            (funcall test-not item (funcall key this-element))
            (not (funcall test item (funcall key this-element)))) ))
   (defmacro if-mumble-remove ()
      `(mumble-remove (not (funcall predicate (funcall key this-element)))) )
   (defmacro if-mumble-remove-from-end ()
      `(mumble-remove-from-end
         (not (funcall predicate (funcall key this-element)))) )
   (defmacro if-not-mumble-remove ()
      `(mumble-remove (funcall predicate (funcall key this-element))))
   (defmacro if-not-mumble-remove-from-end ()
      `(mumble-remove-from-end
         (funcall predicate (funcall key this-element))))
   (defmacro list-remove-macro (pred reverse?)
      `(let*
         (,@(if reverse? '((sequence (reverse (the list sequence)))) )
            (splice (list nil))
            (results
               (do
                  ((index 0 (\1+ index)) (before-start splice))
                  ((= index start) before-start)
                  (setq splice
                     (cdr (rplacd splice (list (pop sequence)))) ))) )
         (do
            ((index start (\1+ index)) (this-element) (number-zapped 0))
            ((or (= index end) (= number-zapped count))
               (do
                  ((index index (\1+ index)))
                  ((null sequence)
                     ,(if
                        reverse?
                        '(nreverse (the list (cdr results)))
                        '(cdr results)))
                  (setq splice
                     (cdr (rplacd splice (list (pop sequence)))) )))
            (setq this-element (pop sequence))
            (if
               ,pred
               (setq splice (cdr (rplacd splice (list this-element))))
               (setq number-zapped (\1+ number-zapped)))) ))
   (defmacro list-remove (pred) `(list-remove-macro ,pred nil))
   (defmacro list-remove-from-end (pred) `(list-remove-macro ,pred t))
   (defmacro normal-list-remove ()
      `(list-remove
         (if
            test-not
            (funcall test-not item (funcall key this-element))
            (not (funcall test item (funcall key this-element)))) ))
   (defmacro normal-list-remove-from-end ()
      `(list-remove-from-end
         (if
            test-not
            (funcall test-not item (funcall key this-element))
            (not (funcall test item (funcall key this-element)))) ))
   (defmacro if-list-remove ()
      `(list-remove (not (funcall predicate (funcall key this-element)))) )
   (defmacro if-list-remove-from-end ()
      `(list-remove-from-end
         (not (funcall predicate (funcall key this-element)))) )
   (defmacro if-not-list-remove ()
      `(list-remove (funcall predicate (funcall key this-element))))
   (defmacro if-not-list-remove-from-end ()
      `(list-remove-from-end
         (funcall predicate (funcall key this-element)))) )


(defun remove (item sequence &key from-end (test #'eql) test-not (start 0)
      (end (length sequence)) (count most-positive-fixnum) (key #'identity))
   "Returns a copy of SEQUENCE with elements satisfying the test (default is
      EQL) with ITEM removed."
   (let
      ((length (length sequence)))
      (seq-dispatch
         sequence
         (if from-end (normal-list-remove-from-end) (normal-list-remove))
         (if
            from-end
            (normal-mumble-remove-from-end)
            (normal-mumble-remove)))) )


(defun remove-if (predicate sequence &key from-end (start 0)
      (end (length sequence)) (count most-positive-fixnum) (key #'identity))
   "Returns a copy of sequence with elements such that predicate(element)
      is non-null are removed"
   (let
      ((length (length sequence)))
      (seq-dispatch
         sequence
         (if from-end (if-list-remove-from-end) (if-list-remove))
         (if from-end (if-mumble-remove-from-end) (if-mumble-remove)))) )


(defun remove-if-not (predicate sequence &key from-end (start 0)
      (end (length sequence)) (count most-positive-fixnum) (key #'identity))
   "Returns a copy of sequence with elements such that predicate(element)
      is null are removed"
   (let
      ((length (length sequence)))
      (seq-dispatch
         sequence
         (if from-end (if-not-list-remove-from-end) (if-not-list-remove))
         (if
            from-end
            (if-not-mumble-remove-from-end)
            (if-not-mumble-remove)))) )


;;; Remove-Duplicates:
;;; Remove duplicates from a list. If from-end, remove the later duplicates,
;;; not the earlier ones. Thus if we check from-end we don't copy an item
;;; if we look into the already copied structure (from after :start) and see
;;; the item. If we check from beginning we check into the rest of the
;;; original list up to the :end marker (this we have to do by running a
;;; do loop down the list that far and using our test.
(defun list-remove-duplicates* (list test test-not start end key from-end)
   (let*
      ((result (list ()))
         ; Put a marker on the beginning to splice with.
         (splice result)
         (current list))
      (do
         ((index 0 (\1+ index)))
         ((= index start))
         (setq splice (cdr (rplacd splice (list (car current)))) )
         (setq current (cdr current)))
      (do
         ((index 0 (\1+ index)))
         ((or (and end (= index end)) (atom current)))
         (if
            (or
               (and
                  from-end
                  (not
                     (member
                        (funcall key (car current))
                        (nthcdr start result) :test test :test-not test-not
                        :key key)))
               (and
                  (not from-end)
                  (not
                     (do
                        ((it (funcall key (car current)))
                           (l (cdr current) (cdr l))
                           (i (\1+ index) (\1+ i)))
                        ((or (atom l) (= i end)) ())
                        (if
                           (if
                              test-not
                              (not
                                 (funcall test-not (funcall key (car l)) it))
                              (funcall test (funcall key (car l)) it))
                           (return t)))) ))
            (setq splice (cdr (rplacd splice (list (car current)))) ))
         (setq current (cdr current)))
      (do
         ()
         ((atom current))
         (setq splice (cdr (rplacd splice (list (car current)))) )
         (setq current (cdr current)))
      (cdr result)))


(defun vector-remove-duplicates* (vector test test-not start end key from-end
      &optional (length (length vector)))
   (declare (vector vector))
   (let
      ((result (make-sequence-like vector length)) (index 0) (jndex start))
      (do
         ()
         ((= index start))
         (setf (aref result index) (aref vector index))
         (setq index (\1+ index)))
      (do
         ((elt))
         ((= index end))
         (setq elt (aref vector index))
         (unless
            (or
               (and
                  from-end
                  (position (funcall key elt) result :start start :end jndex
                     :test test :test-not test-not :key key))
               (and
                  (not from-end)
                  (position (funcall key elt) vector :start (\1+ index) :end
                     end :test test :test-not test-not :key key)))
            (setf (aref result jndex) elt)
            (setq jndex (\1+ jndex)))
         (setq index (\1+ index)))
      (do
         ()
         ((= index length))
         (setf (aref result jndex) (aref vector index))
         (setq index (\1+ index))
         (setq jndex (\1+ jndex)))
      (shrink-vector result jndex)))


(defun remove-duplicates (sequence &key (test #'eql) test-not (start 0)
      from-end (end (length sequence)) (key #'identity))
   "The elements of Sequence are examined, and if any two match, one is
      discarded.  The resulting sequence is returned."
   (seq-dispatch
      sequence
      (if
         sequence
         (list-remove-duplicates* sequence test test-not start end key
            from-end))
      (vector-remove-duplicates* sequence test test-not start end key
         from-end)))


(defun list-remove-duplicates*-1 (list)
   (let*
      ((result (list ()))
         ; Put a marker on the beginning to splice with.
         (splice result)
         (current list))
      (do
         ()
         ((atom current))
         (if
                  (not
                     (do
                        ((it (car current))
                           (l (cdr current) (cdr l)))
                        ((atom l) ())
                        (if
                              (equalp (car l) it)
                           (return t))))
            (setq splice (cdr (rplacd splice (list (car current)))) ))
         (setq current (cdr current)))
      (do
         ()
         ((atom current))
         (setq splice (cdr (rplacd splice (list (car current)))) )
         (setq current (cdr current)))
      (cdr result)))


(defun vector-remove-duplicates*-1 (vector end)
   (declare (vector vector))
   (let
      ((result (make-sequence-like vector end)) (index 0) (jndex 0))
      (do
         ()
         ((= index 0))
         (setf (aref result index) (aref vector index))
         (setq index (\1+ index)))
      (do
         ((elt))
         ((= index end))
         (setq elt (aref vector index))
         (unless (position elt vector :start (\1+ index)
                                      :end end :test #'equalp)
            (setf (aref result jndex) elt)
            (setq jndex (\1+ jndex)))
         (setq index (\1+ index)))
      (do
         ()
         ((= index end))
         (setf (aref result jndex) (aref vector index))
         (setq index (\1+ index))
         (setq jndex (\1+ jndex)))
      (shrink-vector result jndex)))


(defun remove-duplicates-1 (sequence)
   "The elements of Sequence are examined, and if any two match, one is
      discarded.  The resulting sequence is returned."
   (seq-dispatch
      sequence
      (if sequence (list-remove-duplicates*-1 sequence))
      (vector-remove-duplicates*-1 sequence (length sequence))))


;;; Delete-Duplicates:
(defun list-delete-duplicates* (list test test-not key from-end start end)
   (let
      ((handle (cons nil list)))
      (do
         ((current (nthcdr start list) (cdr current))
            (previous (nthcdr start handle))
            (index start (\1+ index)))
         ((or (= index end) (null current)) (cdr handle))
         (if
            (do
               ((x
                   (if from-end (nthcdr (\1+ start) handle) (cdr current))
                   (cdr x))
                  (i (\1+ index) (\1+ i)))
               ((or (null x) (and (not from-end) (= i end)) (eq x current))
                  nil)
               (if
                  (if
                     test-not
                     (not
                        (funcall
                           test-not
                           (funcall key (car current))
                           (funcall key (car x))))
                     (funcall
                        test
                        (funcall key (car current))
                        (funcall key (car x))))
                  (return t)))
            (rplacd previous (cdr current))
            (setq previous (cdr previous)))) ))


(defun vector-delete-duplicates* (vector test test-not key from-end start end
      &optional (length (length vector)))
   (declare (vector vector))
   (do
      ((index start (\1+ index)) (jndex start))
      ((= index end)
         (do
            ((index index (\1+ index))
               ; copy the rest of the vector
               (jndex jndex (\1+ jndex)))
            ((= index length) (shrink-vector vector jndex) vector)
            (setf (aref vector jndex) (aref vector index))))
      (setf (aref vector jndex) (aref vector index))
      (unless
         (position (funcall key (aref vector index)) vector :key key :start
            (if from-end start (\1+ index))
            :test test :end (if from-end jndex end) :test-not
            test-not)
         (setq jndex (\1+ jndex)))) )


(defun delete-duplicates (sequence &key (test #'eql) test-not (start 0)
      from-end (end (length sequence)) (key #'identity))
   "The elements of Sequence are examined, and if any two match, one is
      discarded.  The resulting sequence, which may be formed by
      destroying the given sequence, is returned."
   (seq-dispatch
      sequence
      (if
         sequence
         (list-delete-duplicates* sequence test test-not key from-end start
            end))
      (vector-delete-duplicates* sequence test test-not key from-end start
         end)))


(defun list-delete-duplicates*-1 (list)
   (let
      ((handle (cons nil list)))
      (do
         ((current list (cdr current))
            (previous handle)
            (index 0 (\1+ index)))
         ((null current) (cdr handle))
         (if
            (do ((x handle (cdr x))
                 (i (\1+ index) (\1+ i)))
               ((or (null x) (eq x current)) nil)
               (if (eql (car current) (car x)) (return t)))
            (rplacd previous (cdr current))
            (setq previous (cdr previous)))) ))


(defun vector-delete-duplicates*-1 (vector end)
   (declare (vector vector))
   (do
      ((index 0 (\1+ index)) (jndex 0))
      ((= index end)
         (do
            ((index index (\1+ index))
               ; copy the rest of the vector
               (jndex jndex (\1+ jndex)))
            ((= index end) (shrink-vector vector jndex) vector)
            (setf (aref vector jndex) (aref vector index))))
      (setf (aref vector jndex) (aref vector index))
      (unless
         (position (aref vector index) vector :start (\1+ index) :end end)
         (setq jndex (\1+ jndex)))) )


(defun delete-duplicates-1 (sequence)
   "The elements of Sequence are examined, and if any two match, one is
      discarded.  The resulting sequence, which may be formed by
      destroying the given sequence, is returned."
   (seq-dispatch
      sequence
      (if sequence (list-delete-duplicates*-1 sequence))
      (vector-delete-duplicates*-1 sequence (length sequence))))


(defun list-substitute* (pred new list start end count key test test-not old)
   (let*
      ((result (list nil)) elt (splice result) (list list))
      ; Get a local list for a stepper.
      (do
         ((index 0 (\1+ index)))
         ((= index start))
         (setq splice (cdr (rplacd splice (list (car list)))) )
         (setq list (cdr list)))
      (do
         ((index start (\1+ index)))
         ((or (and end (= index end)) (null list) (= count 0)))
         (setq elt (car list))
         (setq splice
            (cdr
               (rplacd
                  splice
                  (list
                     (cond
                        ((case
                            pred
                            (normal
                               (if
                                  test-not
                                  (not
                                     (funcall
                                        test-not
                                        (funcall key elt)
                                        old))
                                  (funcall test (funcall key elt) old)))
                            (if (funcall test (funcall key elt)))
                            (if-not (not (funcall test (funcall key elt)))) )
                           (setq count (\1- count))
                           new)
                        (t elt)))) ))
         (setq list (cdr list)))
      (do
         ()
         ((null list))
         (setq splice (cdr (rplacd splice (list (car list)))) )
         (setq list (cdr list)))
      (cdr result)))


;;; Replace old with new in sequence moving from left to right by incrementer
;;; on each pass through the loop. Called by all three substitute functions.
(defun vector-substitute* (pred new sequence incrementer left right length
      start end count key test test-not old)
   (let
      ((result (make-sequence-like sequence length)) (index left))
      (do
         ()
         ((= index start))
         (setf (aref result index) (aref sequence index))
         (setq index (+ index incrementer)))
      (do
         ((elt))
         ((or (= index end) (= count 0)))
         (setq elt (aref sequence index))
         (setf
            (aref result index)
            (cond
               ((case
                   pred
                   (normal
                      (if
                         test-not
                         (not (funcall test-not (funcall key elt) old))
                         (funcall test (funcall key elt) old)))
                   (if (funcall test (funcall key elt)))
                   (if-not (not (funcall test (funcall key elt)))) )
                  (setq count (\1- count))
                  new)
               (t elt)))
         (setq index (+ index incrementer)))
      (do
         ()
         ((= index right))
         (setf (aref result index) (aref sequence index))
         (setq index (+ index incrementer)))
      result))


(eval-when
   (compile eval)
   (defmacro subst-dispatch (pred)
      `(if
         (listp sequence)
         (if
            from-end
            (nreverse
               (list-substitute* ,pred new (reverse sequence) (- length end)
                  (- length start) count key test test-not old))
            (list-substitute* ,pred new sequence start end count key test
               test-not old))
         (if
            from-end
            (vector-substitute* ,pred new sequence -1 (\1- length) -1 length
               (\1- end) (\1- start) count key test test-not old)
            (vector-substitute* ,pred new sequence 1 0 length length start
               end count key test test-not old)))) )


;;; Substitute:
(defun substitute (new old sequence &key from-end (test #'eql) test-not
      (start 0)
      (count most-positive-fixnum)
      (end (length sequence))
      (key #'identity))
   "Returns a sequence of the same kind as Sequence with the same elements
     except that all elements equal to Old are replaced with New.  See manual
     for details."
   (let
      ((length (length sequence)) (old (funcall key old)))
      (subst-dispatch 'normal)))


;;; Substitute-If:
(defun substitute-if (new test sequence &key from-end (start 0)
      (end (length sequence)) (count most-positive-fixnum) (key #'identity))
   "Returns a sequence of the same kind as Sequence with the same elements
     except that all elements satisfying the Test are replaced with New.  See
     manual for details."
   (let ((length (length sequence)) test-not old) (subst-dispatch 'if)))


;;; Substitute-If-Not:
(defun substitute-if-not (new test sequence &key from-end (start 0)
      (end (length sequence)) (count most-positive-fixnum) (key #'identity))
   "Returns a sequence of the same kind as Sequence with the same elements
     except that all elements not satisfying the Test are replaced with New.
     See manual for details."
   (let ((length (length sequence)) test-not old) (subst-dispatch 'if-not)))


;;; NSubstitute:
(defun nsubstitute (new old sequence &key from-end (test #'eql) test-not
      (end (if (vectorp sequence) (length (the vector sequence))))
      (count most-positive-fixnum)
      (key #'identity)
      (start 0))
   "Returns a sequence of the same kind as Sequence with the same elements
     except that all elements equal to Old are replaced with New.
     The Sequence may be destroyed.  See manual for details."
   (let
      ((incrementer 1) (old* (funcall key old)))
      (if from-end (psetq start (\1- end) end (\1- start) incrementer -1))
      (if
         (listp sequence)
         (if
            from-end
            (nreverse
               (nlist-substitute*
                  new old* (nreverse (the list sequence)) test test-not start
                  end count key))
            (nlist-substitute* new old* sequence test test-not start end
               count key))
         (nvector-substitute* new old* sequence incrementer test test-not
            start end count key))))


(defun nlist-substitute* (new old* sequence test test-not start end count
      key)
   (do
      ((list (nthcdr start sequence) (cdr list)) (index start (\1+ index)))
      ((or (and end (= index end)) (null list) (= count 0)) sequence)
      (when
         (if
            test-not
            (not (funcall test-not (funcall key (car list)) old*))
            (funcall test (funcall key (car list)) old*))
         (rplaca list new)
         (setq count (\1- count)))) )


(defun nvector-substitute* (new old* sequence incrementer test test-not start
      end count key)
   (do
      ((index start (+ index incrementer)))
      ((or (= index end) (= count 0)) sequence)
      (when
         (if
            test-not
            (not (funcall test-not (funcall key (aref sequence index) old*)))
            (funcall test (funcall key (aref sequence index)) old*))
         (setf (aref sequence index) new)
         (setq count (\1- count)))) )


;;; NSubstitute-If:
(defun nsubstitute-if (new test sequence &key from-end (start 0)
      (end (if (vectorp sequence) (length (the vector sequence))))
      (count most-positive-fixnum)
      (key #'identity))
   "Returns a sequence of the same kind as Sequence with the same elements
     except that all elements satisfying the Test are replaced with New.  The
     Sequence may be destroyed.  See manual for details."
   (let
      ((incrementer 1))
      (if from-end (psetq start (\1- end) end (\1- start) incrementer -1))
      (if
         (listp sequence)
         (if
            from-end
            (nreverse
               (nlist-substitute-if*
                  new test (nreverse (the list sequence)) start end count
                  key))
            (nlist-substitute-if* new test sequence start end count key))
         (nvector-substitute-if* new test sequence incrementer start end
            count key))))


(defun nlist-substitute-if* (new test sequence start end count key)
   (do
      ((list (nthcdr start sequence) (cdr list)) (index start (\1+ index)))
      ((or (and end (= index end)) (null list) (= count 0)) sequence)
      (when
         (funcall test (funcall key (car list)))
         (rplaca list new)
         (setq count (\1- count)))) )


(defun nvector-substitute-if* (new test sequence incrementer start end count
      key)
   (do
      ((index start (+ index incrementer)))
      ((or (= index end) (= count 0)) sequence)
      (when
         (funcall test (funcall key (aref sequence index)))
         (setf (aref sequence index) new)
         (setq count (\1- count)))) )


;;; NSubstitute-If-Not:
(defun nsubstitute-if-not (new test sequence &key from-end (start 0)
      (end (if (vectorp sequence) (length (the vector sequence))))
      (count most-positive-fixnum)
      (key #'identity))
   "Returns a sequence of the same kind as Sequence with the same elements
     except that all elements not satisfying the Test are replaced with New.
     The Sequence may be destroyed.  See manual for details."
   (let
      ((incrementer 1))
      (if from-end (psetq start (\1- end) end (\1- start) incrementer -1))
      (if
         (listp sequence)
         (if
            from-end
            (nreverse
               (nlist-substitute-if-not*
                  new test (nreverse (the list sequence)) start end count
                  key))
            (nlist-substitute-if-not* new test sequence start end count key))
         (nvector-substitute-if-not* new test sequence incrementer start end
            count key))))


(defun nlist-substitute-if-not* (new test sequence start end count key)
   (do
      ((list (nthcdr start sequence) (cdr list)) (index start (\1+ index)))
      ((or (and end (= index end)) (null list) (= count 0)) sequence)
      (when
         (not (funcall test (funcall key (car list))))
         (rplaca list new)
         (setq count (\1- count)))) )


(defun nvector-substitute-if-not* (new test sequence incrementer start end
      count key)
   (do
      ((index start (+ index incrementer)))
      ((or (= index end) (= count 0)) sequence)
      (when
         (not (funcall test (funcall key (aref sequence index))))
         (setf (aref sequence index) new)
         (setq count (\1- count)))) )


;;; Position:

(eval-when
   (compile eval)
   (defmacro vector-position (item sequence)
      `(let
         ((incrementer (if from-end -1 1))
            (start (if from-end (\1- end) start))
            (end (if from-end (\1- start) end)))
         (do
            ((index start (+ index incrementer)))
            ((= index end) ())
            (if
               test-not
               (if
;; negate the condition for test-not
                  (not (funcall
                     test-not
                     ,item
                     (funcall key (aref ,sequence index))))
                  (return index))
               (if
                  (funcall test ,item (funcall key (aref ,sequence index)))
                  (return index)))) ))
   (defmacro list-position (item sequence)
      `(if
         from-end
         (do
            ((sequence
                (nthcdr
                   (- (length sequence) end)
                   (reverse (the list ,sequence))))
               (index (\1- end) (\1- index)))
            ((or (= index (\1- start)) (null sequence)) ())
            (if
               test-not
               (if
;; negate the condition for test-not
                  (not (funcall test-not ,item (funcall key (pop sequence))))
                  (return index))
               (if
                  (funcall test ,item (funcall key (pop sequence)))
                  (return index))))
         (do
            ((sequence (nthcdr start ,sequence)) (index start (\1+ index)))
            ((or (= index end) (null sequence)) ())
            (if
               test-not
               (if
;; negate the condition for test-not
                  (not (funcall test-not ,item (funcall key (pop sequence))))
                  (return index))
               (if
                  (funcall test ,item (funcall key (pop sequence)))
                  (return index)))) )))


(defun position (item sequence &key from-end (test #'eql) test-not (start 0)
      (end (length sequence)) (key #'identity))
   "Returns the zero-origin index of the first element in SEQUENCE
      satisfying the test (default is EQL) with the given ITEM"
   (seq-dispatch
      sequence
      (list-position* item sequence from-end test test-not start end key)
      (vector-position* item sequence from-end test test-not start end key)))


(defun list-position* (item sequence from-end test test-not start end key)
   (list-position item sequence))


(defun vector-position* (item sequence from-end test test-not start end key)
   (vector-position item sequence))


;;; Position-if:

(eval-when
   (compile eval)
   (defmacro vector-position-if (test sequence)
      `(let
         ((incrementer (if from-end -1 1))
            (start (if from-end (\1- end) start))
            (end (if from-end (\1- start) end)))
         (do
            ((index start (+ index incrementer)))
            ((= index end) ())
            (if
               (funcall ,test (funcall key (aref ,sequence index)))
               (return index)))) )
   (defmacro list-position-if (test sequence)
      `(if
         from-end
         (do
            ((sequence
                (nthcdr (- length end) (reverse (the list ,sequence))))
               (index (\1- end) (\1- index)))
            ((or (= index (\1- start)) (null sequence)) ())
            (if (funcall ,test (funcall key (pop sequence))) (return index)))
         (do
            ((sequence (nthcdr start ,sequence)) (index start (\1+ index)))
            ((or (= index end) (null sequence)) ())
            (if
               (funcall ,test (funcall key (pop sequence)))
               (return index)))) ))


(defun position-if (test sequence &key from-end (start 0) (key #'identity)
      (end (length sequence)))
   "Returns the zero-origin index of the first element satisfying test(el)"
   (let
      ((length (length sequence)))
      (seq-dispatch
         sequence
         (list-position-if test sequence)
         (vector-position-if test sequence))))


;;; Position-if-not:

(eval-when
   (compile eval)
   (defmacro vector-position-if-not (test sequence)
      `(let
         ((incrementer (if from-end -1 1))
            (start (if from-end (\1- end) start))
            (end (if from-end (\1- start) end)))
         (do
            ((index start (+ index incrementer)))
            ((= index end) ())
            (if
               (not (funcall ,test (funcall key (aref ,sequence index))))
               (return index)))) )
   (defmacro list-position-if-not (test sequence)
      `(if
         from-end
         (do
            ((sequence
                (nthcdr (- length end) (reverse (the list ,sequence))))
               (index (\1- end) (\1- index)))
            ((or (= index (\1- start)) (null sequence)) ())
            (if
               (not (funcall ,test (funcall key (pop sequence))))
               (return index)))
         (do
            ((sequence (nthcdr start ,sequence)) (index start (\1+ index)))
            ((or (= index end) (null sequence)) ())
            (if
               (not (funcall ,test (funcall key (pop sequence))))
               (return index)))) ))


(defun position-if-not (test sequence &key from-end (start 0)
      (key #'identity) (end (length sequence)))
   "Returns the zero-origin index of the first element not
    satisfying test(el)"
   (let
      ((length (length sequence)))
      (seq-dispatch
         sequence
         (list-position-if-not test sequence)
         (vector-position-if-not test sequence))))


;;; Count:

(eval-when
   (compile eval)
   (defmacro vector-count (item sequence)
      `(do
         ((index start (\1+ index)) (count 0))
         ((= index end) count)
         (if
            test-not
            (if
;; negate the condition for test-not
               (not (funcall test-not ,item (funcall key (aref ,sequence index))))
               (setq count (\1+ count)))
            (if
               (funcall test ,item (funcall key (aref ,sequence index)))
               (setq count (\1+ count)))) ))
   (defmacro list-count (item sequence)
      `(do
         ((sequence (nthcdr start ,sequence))
            (index start (\1+ index))
            (count 0))
         ((or (= index end) (null sequence)) count)
         (if
            test-not
            (if
;; negate the condition for test-not
               (not (funcall test-not ,item (funcall key (pop sequence))))
               (setq count (\1+ count)))
            (if
               (funcall test ,item (funcall key (pop sequence)))
               (setq count (\1+ count)))) )))


(defun count (item sequence &key from-end (test #'eql) test-not (start 0)
      (end (length sequence)) (key #'identity))
   "Returns the number of elements in SEQUENCE satisfying a test with ITEM,
      which defaults to EQL."
   (declare (ignore from-end))
   (seq-dispatch
      sequence
      (list-count item sequence)
      (vector-count item sequence)))


;;; Count-if:

(eval-when
   (compile eval)
   (defmacro vector-count-if (predicate sequence)
      `(do
         ((index start (\1+ index)) (count 0))
         ((= index end) count)
         (if
            (funcall ,predicate (funcall key (aref ,sequence index)))
            (setq count (\1+ count)))) )
   (defmacro list-count-if (predicate sequence)
      `(do
         ((sequence (nthcdr start ,sequence))
            (index start (\1+ index))
            (count 0))
         ((or (= index end) (null sequence)) count)
         (if
            (funcall ,predicate (funcall key (pop sequence)))
            (setq count (\1+ count)))) ))


(defun count-if (test sequence &key from-end (start 0)
      (end (length sequence)) (key #'identity))
   "Returns the number of elements in SEQUENCE satisfying TEST(el)."
   (declare (ignore from-end))
   (seq-dispatch
      sequence
      (list-count-if test sequence)
      (vector-count-if test sequence)))


;;; Count-if-not:

(eval-when
   (compile eval)
   (defmacro vector-count-if-not (predicate sequence)
      `(do
         ((index start (\1+ index)) (count 0))
         ((= index end) count)
         (if
            (not (funcall ,predicate (funcall key (aref ,sequence index))))
            (setq count (\1+ count)))) )
   (defmacro list-count-if-not (predicate sequence)
      `(do
         ((sequence (nthcdr start ,sequence))
            (index start (\1+ index))
            (count 0))
         ((or (= index end) (null sequence)) count)
         (if
            (not (funcall ,predicate (funcall key (pop sequence))))
            (setq count (\1+ count)))) ))


(defun count-if-not (test sequence &key from-end (start 0)
      (end (length sequence)) (key #'identity))
   "Returns the number of elements in SEQUENCE not satisfying TEST(el)."
   (declare (ignore from-end))
   (seq-dispatch
      sequence
      (list-count-if-not test sequence)
      (vector-count-if-not test sequence)))


;;; Find:

(eval-when
   (compile eval)
   (defmacro vector-find (item sequence)
      `(let
         ((incrementer (if from-end -1 1))
            (start (if from-end (\1- end) start))
            (end (if from-end (\1- start) end)))
         (do
            ((index start (+ index incrementer)) (current))
            ((= index end) ())
            (setq current (aref ,sequence index))
            (if
               test-not
               (if
                  (not (funcall test-not ,item (funcall key current)))
                  (return current))
               (if
                  (funcall test ,item (funcall key current))
                  (return current)))) ))
   (defmacro list-find (item sequence)
      `(if
         from-end
         (do
            ((sequence
                (nthcdr
                   (- (length ,sequence) end)
                   (reverse (the list ,sequence))))
               (index (\1- end) (\1- index))
               (current))
            ((or (= index (\1- start)) (null sequence)) ())
            (setq current (pop sequence))
            (if
               test-not
               (if
                  (not (funcall test-not ,item (funcall key current)))
                  (return current))
               (if
                  (funcall test ,item (funcall key current))
                  (return current))))
         (do
            ((sequence (nthcdr start ,sequence))
               (index start (\1+ index))
               (current))
            ((or (= index end) (null sequence)) ())
            (setq current (pop sequence))
            (if
               test-not
               (if
                  (not (funcall test-not ,item (funcall key current)))
                  (return current))
               (if
                  (funcall test ,item (funcall key current))
                  (return current)))) )))


(defun find (item sequence &key from-end (test #'eql) test-not (start 0)
      (end (length sequence)) (key #'identity))
   "Returns the first element in SEQUENCE satisfying the test (default
      is EQL) with the given ITEM"
   (seq-dispatch
      sequence
      (list-find* item sequence from-end test test-not start end key)
      (vector-find* item sequence from-end test test-not start end key)))


(defun list-find* (item sequence from-end test test-not start end key)
   (list-find item sequence))


(defun vector-find* (item sequence from-end test test-not start end key)
   (vector-find item sequence))


;; The case of (find a b :test #'char=) happens to be of especial importance
;; for an application I have, so I provide a special case for that!

(defun find-char= (item sequence)
   (if (listp sequence)
       (do ((current))
          ((null sequence) ())
          (setq current (pop sequence))
          (if (char= item current) (return current)))
       (let ((end (length sequence)))
          (do
             ((index 0 (1+ index))
              (current))
             ((= index end) ())
             (setq current (aref sequence index))
             (if (char= item current) (return current)) ))))


;;; Find-if:

(eval-when
   (compile eval)
   (defmacro vector-find-if (test sequence)
      `(let
         ((incrementer (if from-end -1 1))
            (start (if from-end (\1- end) start))
            (end (if from-end (\1- start) end)))
         (do
            ((index start (+ index incrementer)) (current))
            ((= index end) ())
            (setq current (aref ,sequence index))
            (if (funcall ,test (funcall key current)) (return current)))) )
   (defmacro list-find-if (test sequence)
      `(if
         from-end
         (do
            ((sequence
                (nthcdr (- length end) (reverse (the list ,sequence))))
               (index (\1- end) (\1- index))
               (current))
            ((or (= index (\1- start)) (null sequence)) ())
            (setq current (pop sequence))
            (if (funcall ,test (funcall key current)) (return current)))
         (do
            ((sequence (nthcdr start ,sequence))
               (index start (\1+ index))
               (current))
            ((or (= index end) (null sequence)) ())
            (setq current (pop sequence))
            (if (funcall ,test (funcall key current)) (return current)))) ))


(defun find-if (test sequence &key from-end (start 0) (end (length sequence))
      (key #'identity))
   "Returns the zero-origin index of the first element satisfying the test."
   (let
      ((length (length sequence)))
      (seq-dispatch
         sequence
         (list-find-if test sequence)
         (vector-find-if test sequence))))


;;; Find-if-not:

(eval-when
   (compile eval)
   (defmacro vector-find-if-not (test sequence)
      `(let
         ((incrementer (if from-end -1 1))
            (start (if from-end (\1- end) start))
            (end (if from-end (\1- start) end)))
         (do
            ((index start (+ index incrementer)) (current))
            ((= index end) ())
            (setq current (aref ,sequence index))
            (if
               (not (funcall ,test (funcall key current)))
               (return current)))) )
   (defmacro list-find-if-not (test sequence)
      `(if
         from-end
         (do
            ((sequence
                (nthcdr (- length end) (reverse (the list ,sequence))))
               (index (\1- end) (\1- index))
               (current))
            ((or (= index (\1- start)) (null sequence)) ())
            (setq current (pop sequence))
            (if
               (not (funcall ,test (funcall key current)))
               (return current)))
         (do
            ((sequence (nthcdr start ,sequence))
               (index start (\1+ index))
               (current))
            ((or (= index end) (null sequence)) ())
            (setq current (pop sequence))
            (if
               (not (funcall ,test (funcall key current)))
               (return current)))) ))


(defun find-if-not (test sequence &key from-end (start 0)
      (end (length sequence)) (key #'identity))
   "Returns the zero-origin index of the first element not satisfying
    the test."
   (let
      ((length (length sequence)))
      (seq-dispatch
         sequence
         (list-find-if-not test sequence)
         (vector-find-if-not test sequence))))


;;; Mismatch utilities:

(eval-when
   (compile eval)
   (defmacro match-vars (&rest body)
      `(let
         ((inc (if from-end -1 1))
            (start1 (if from-end (\1- end1) start1))
            (start2 (if from-end (\1- end2) start2))
            (end1 (if from-end (\1- start1) end1))
            (end2 (if from-end (\1- start2) end2)))
         ,@body))
   (defmacro matchify-list (sequence start length end)
      `(setq ,sequence
         (if
            from-end
            (nthcdr (- ,length ,start 1) (reverse (the list ,sequence)))
            (nthcdr ,start ,sequence)))) )


;;; Mismatch:

(eval-when
   (compile eval)
   (defmacro if-mismatch (elt1 elt2)
      `(cond
         ((= index1 end1)
            (return
               (if (= index2 end2) nil (if from-end (\1+ index1) index1))))
         ((= index2 end2) (return (if from-end (\1+ index1) index1)))
         (test-not
            (if
               (funcall test-not (funcall key ,elt1) (funcall key ,elt2))
               (return (if from-end (\1+ index1) index1))))
         (t (if
               (not (funcall test (funcall key ,elt1) (funcall key ,elt2)))
               (return (if from-end (\1+ index1) index1)))) ))
   (defmacro mumble-mumble-mismatch ()
      `(do
         ((index1 start1 (+ index1 inc)) (index2 start2 (+ index2 inc)))
         (())
         (if-mismatch (aref sequence1 index1) (aref sequence2 index2))))
   (defmacro mumble-list-mismatch ()
      `(do
         ((index1 start1 (+ index1 inc)) (index2 start2 (+ index2 inc)))
         (())
         (if-mismatch (aref sequence1 index1) (pop sequence2))))
   (defmacro list-mumble-mismatch ()
      `(do
         ((index1 start1 (+ index1 inc)) (index2 start2 (+ index2 inc)))
         (())
         (if-mismatch (pop sequence1) (aref sequence2 index2))))
   (defmacro list-list-mismatch ()
      `(do
         ((index1 start1 (+ index1 inc)) (index2 start2 (+ index2 inc)))
         (())
         (if-mismatch (pop sequence1) (pop sequence2)))) )


(defun mismatch (sequence1 sequence2 &key from-end (test #'eql) test-not
      (start1 0)
      (end1 (length sequence1))
      (start2 0)
      (end2 (length sequence2))
      (key #'identity))
   "The specified subsequences of Sequence1 and Sequence2 are compared
   element-wise.  If they are of equal length and match in every element, the
   result is Nil.  Otherwise, the result is a non-negative integer, the index
   within Sequence1 of the leftmost position at which they fail to match; or,
   if one is shorter than and a matching prefix of the other, the index
   within Sequence1 beyond the last position tested is returned.  If a
   non-Nil :From-End keyword argument is given, then one plus the index
   of the rightmost position in which the sequences differ is returned."
   (let
      ((length1 (length sequence1)) (length2 (length sequence2)))
      (match-vars
         (seq-dispatch
            sequence1
            (progn
               (matchify-list sequence1 start1 length1 end1)
               (seq-dispatch
                  sequence2
                  (progn
                     (matchify-list sequence2 start2 length2 end2)
                     (list-list-mismatch))
                  (list-mumble-mismatch)))
            (seq-dispatch
               sequence2
               (progn
                  (matchify-list sequence2 start2 length2 end2)
                  (mumble-list-mismatch))
               (mumble-mumble-mismatch)))) ))


;;; Search comparison functions:

(eval-when
   (compile eval)
   ;;; Compare two elements and return if they don't match:
   (defmacro compare-elements (elt1 elt2)
      `(if
         test-not
         (if
            (funcall test-not (funcall key ,elt1) (funcall key ,elt2))
            (return nil)
            t)
         (if
            (not (funcall test (funcall key ,elt1) (funcall key ,elt2)))
            (return nil)
            t)))
   (defmacro search-compare-list-list (main sub)
      `(do
         ((main ,main (cdr main))
            (jndex start1 (\1+ jndex))
            (sub (nthcdr start1 ,sub) (cdr sub)))
         ((or (null main) (null sub) (= end1 jndex)) t)
         (compare-elements (car main) (car sub))))
   (defmacro search-compare-list-vector (main sub)
      `(do
         ((main ,main (cdr main)) (index start1 (\1+ index)))
         ((or (null main) (= index end1)) t)
         (compare-elements (car main) (aref ,sub index))))
   (defmacro search-compare-vector-list (main sub index)
      `(do
         ((sub (nthcdr start1 ,sub) (cdr sub))
            (jndex start1 (\1+ jndex))
            (index ,index (\1+ index)))
         ((or (= end1 jndex) (null sub)) t)
         (compare-elements (aref ,main index) (car sub))))
   (defmacro search-compare-vector-vector (main sub index)
      `(do
         ((index ,index (\1+ index)) (sub-index start1 (\1+ sub-index)))
         ((= sub-index end1) t)
         (compare-elements (aref ,main index) (aref ,sub sub-index))))
   (defmacro search-compare (main-type main sub index)
      (if
         (eq main-type 'list)
         `(seq-dispatch
            ,sub
            (search-compare-list-list ,main ,sub)
            (search-compare-list-vector ,main ,sub))
         `(seq-dispatch
            ,sub
            (search-compare-vector-list ,main ,sub ,index)
            (search-compare-vector-vector ,main ,sub ,index)))) )


(eval-when
   (compile eval)
   (defmacro list-search (main sub)
      `(do
         ((main (nthcdr start2 ,main) (cdr main))
            (index2 start2 (\1+ index2))
            (terminus (- end2 (- end1 start1)))
            (last-match ()))
         ((> index2 terminus) last-match)
         (if
            (search-compare list main ,sub index2)
            (if from-end (setq last-match index2) (return index2)))) )
   (defmacro vector-search (main sub)
      `(do
         ((index2 start2 (\1+ index2))
            (terminus (- end2 (- end1 start1)))
            (last-match ()))
         ((> index2 terminus) last-match)
         (if
            (search-compare vector ,main ,sub index2)
            (if from-end (setq last-match index2) (return index2)))) ))


(defun search (sequence1 sequence2 &key from-end (test #'eql) test-not
      (start1 0)
      (end1 (length sequence1))
      (start2 0)
      (end2 (length sequence2))
      (key #'identity))
   "A search is conducted using EQL for the first subsequence of sequence2
      which element-wise matches sequence1.  If there is such a
      subsequence in sequence2, the index of the its leftmost element
      is returned; otherwise () is returned."
   (seq-dispatch
      sequence2
      (list-search sequence2 sequence1)
      (vector-search sequence2 sequence1)))


;; Now search without any keyword args... the simpler case, but still messy!

(eval-when
   (compile eval)
   ;;; Compare two elements and return if they don't match:
   (defmacro compare-elements-2 (elt1 elt2)
      `(when (not (eql ,elt1 ,elt2)) (return nil)))
   (defmacro search-2-compare-list-list (main sub)
      `(do
         ((main ,main (cdr main))
            (jndex 0 (\1+ jndex))
            (sub ,sub (cdr sub)))
         ((or (null main) (null sub) (= end1 jndex)) t)
         (compare-elements-2 (car main) (car sub))))
   (defmacro search-2-compare-list-vector (main sub)
      `(do
         ((main ,main (cdr main)) (index 0 (\1+ index)))
         ((or (null main) (= index end1)) t)
         (compare-elements-2 (car main) (aref ,sub index))))
   (defmacro search-2-compare-vector-list (main sub index)
      `(do
         ((sub ,sub (cdr sub))
            (jndex 0 (\1+ jndex))
            (index ,index (\1+ index)))
         ((or (= end1 jndex) (null sub)) t)
         (compare-elements-2 (aref ,main index) (car sub))))
   (defmacro search-2-compare-vector-vector (main sub index)
      `(do
         ((index ,index (\1+ index)) (sub-index 0 (\1+ sub-index)))
         ((= sub-index end1) t)
         (compare-elements-2 (aref ,main index) (aref ,sub sub-index))))
   (defmacro search-2-compare (main-type main sub index)
      (if
         (eq main-type 'list)
         `(seq-dispatch
            ,sub
            (search-2-compare-list-list ,main ,sub)
            (search-2-compare-list-vector ,main ,sub))
         `(seq-dispatch
            ,sub
            (search-2-compare-vector-list ,main ,sub ,index)
            (search-2-compare-vector-vector ,main ,sub ,index)))) )


(eval-when
   (compile eval)
   (defmacro list-search-2 (main sub)
      `(do
         ((main ,main (cdr main))
            (index2 0 (\1+ index2))
            (terminus (- end2 end1)))
         ((> index2 terminus) nil)
         (if
            (search-2-compare list main ,sub index2)
            (return index2))) )
   (defmacro vector-search-2 (main sub)
      `(do
         ((index2 0 (\1+ index2))
            (terminus (- end2 end1)))
         ((> index2 terminus) nil)
         (if
            (search-2-compare vector ,main ,sub index2)
            (return index2))) ))


(defun search-2 (sequence1 sequence2 &aux
      (end1 (length sequence1))
      (end2 (length sequence2))
      )
   "A search is conducted using EQL for the first subsequence of sequence2
      which element-wise matches sequence1.  If there is such a
      subsequence in sequence2, the index of the its leftmost element
      is returned; otherwise () is returned."
   (seq-dispatch
      sequence2
      (list-search-2 sequence2 sequence1)
      (vector-search-2 sequence2 sequence1)))




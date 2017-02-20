;;;; This file was automatically generated by Quickutil.
;;;; See http://quickutil.org for details.

;;;; To regenerate:
;;;; (qtlc:save-utils-as "quickutils.lisp" :utilities '(:CURRY :DEFINE-CONSTANT :ENSURE-BOOLEAN :READ-FILE-INTO-STRING :N-GRAMS :RANGE :RCURRY :SWITCH :WITH-GENSYMS) :ensure-package T :package "EULER.QUICKUTILS")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package "EULER.QUICKUTILS")
    (defpackage "EULER.QUICKUTILS"
      (:documentation "Package that contains Quickutil utility functions.")
      (:use #:cl))))

(in-package "EULER.QUICKUTILS")

(when (boundp '*utilities*)
  (setf *utilities* (union *utilities* '(:MAKE-GENSYM-LIST :ENSURE-FUNCTION
                                         :CURRY :DEFINE-CONSTANT
                                         :ENSURE-BOOLEAN :ONCE-ONLY
                                         :WITH-OPEN-FILE* :WITH-INPUT-FROM-FILE
                                         :READ-FILE-INTO-STRING :TAKE :N-GRAMS
                                         :RANGE :RCURRY :STRING-DESIGNATOR
                                         :WITH-GENSYMS :EXTRACT-FUNCTION-NAME
                                         :SWITCH))))
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun make-gensym-list (length &optional (x "G"))
    "Returns a list of `length` gensyms, each generated as if with a call to `make-gensym`,
using the second (optional, defaulting to `\"G\"`) argument."
    (let ((g (if (typep x '(integer 0)) x (string x))))
      (loop repeat length
            collect (gensym g))))
  )                                        ; eval-when
(eval-when (:compile-toplevel :load-toplevel :execute)
  ;;; To propagate return type and allow the compiler to eliminate the IF when
  ;;; it is known if the argument is function or not.
  (declaim (inline ensure-function))

  (declaim (ftype (function (t) (values function &optional))
                  ensure-function))
  (defun ensure-function (function-designator)
    "Returns the function designated by `function-designator`:
if `function-designator` is a function, it is returned, otherwise
it must be a function name and its `fdefinition` is returned."
    (if (functionp function-designator)
        function-designator
        (fdefinition function-designator)))
  )                                        ; eval-when

  (defun curry (function &rest arguments)
    "Returns a function that applies `arguments` and the arguments
it is called with to `function`."
    (declare (optimize (speed 3) (safety 1) (debug 1)))
    (let ((fn (ensure-function function)))
      (lambda (&rest more)
        (declare (dynamic-extent more))
        ;; Using M-V-C we don't need to append the arguments.
        (multiple-value-call fn (values-list arguments) (values-list more)))))

  (define-compiler-macro curry (function &rest arguments)
    (let ((curries (make-gensym-list (length arguments) "CURRY"))
          (fun (gensym "FUN")))
      `(let ((,fun (ensure-function ,function))
             ,@(mapcar #'list curries arguments))
         (declare (optimize (speed 3) (safety 1) (debug 1)))
         (lambda (&rest more)
           (apply ,fun ,@curries more)))))
  

  (defun %reevaluate-constant (name value test)
    (if (not (boundp name))
        value
        (let ((old (symbol-value name))
              (new value))
          (if (not (constantp name))
              (prog1 new
                (cerror "Try to redefine the variable as a constant."
                        "~@<~S is an already bound non-constant variable ~
                       whose value is ~S.~:@>" name old))
              (if (funcall test old new)
                  old
                  (restart-case
                      (error "~@<~S is an already defined constant whose value ~
                              ~S is not equal to the provided initial value ~S ~
                              under ~S.~:@>" name old new test)
                    (ignore ()
                      :report "Retain the current value."
                      old)
                    (continue ()
                      :report "Try to redefine the constant."
                      new)))))))

  (defmacro define-constant (name initial-value &key (test ''eql) documentation)
    "Ensures that the global variable named by `name` is a constant with a value
that is equal under `test` to the result of evaluating `initial-value`. `test` is a
function designator that defaults to `eql`. If `documentation` is given, it
becomes the documentation string of the constant.

Signals an error if `name` is already a bound non-constant variable.

Signals an error if `name` is already a constant variable whose value is not
equal under `test` to result of evaluating `initial-value`."
    `(defconstant ,name (%reevaluate-constant ',name ,initial-value ,test)
       ,@(when documentation `(,documentation))))
  

  (defun ensure-boolean (x)
    "Convert `x` into a Boolean value."
    (and x t))
  

  (defmacro once-only (specs &body forms)
    "Evaluates `forms` with symbols specified in `specs` rebound to temporary
variables, ensuring that each initform is evaluated only once.

Each of `specs` must either be a symbol naming the variable to be rebound, or of
the form:

    (symbol initform)

Bare symbols in `specs` are equivalent to

    (symbol symbol)

Example:

    (defmacro cons1 (x) (once-only (x) `(cons ,x ,x)))
      (let ((y 0)) (cons1 (incf y))) => (1 . 1)"
    (let ((gensyms (make-gensym-list (length specs) "ONCE-ONLY"))
          (names-and-forms (mapcar (lambda (spec)
                                     (etypecase spec
                                       (list
                                        (destructuring-bind (name form) spec
                                          (cons name form)))
                                       (symbol
                                        (cons spec spec))))
                                   specs)))
      ;; bind in user-macro
      `(let ,(mapcar (lambda (g n) (list g `(gensym ,(string (car n)))))
              gensyms names-and-forms)
         ;; bind in final expansion
         `(let (,,@(mapcar (lambda (g n)
                             ``(,,g ,,(cdr n)))
                           gensyms names-and-forms))
            ;; bind in user-macro
            ,(let ,(mapcar (lambda (n g) (list (car n) g))
                    names-and-forms gensyms)
               ,@forms)))))
  

  (defmacro with-open-file* ((stream filespec &key direction element-type
                                                   if-exists if-does-not-exist external-format)
                             &body body)
    "Just like `with-open-file`, but `nil` values in the keyword arguments mean to use
the default value specified for `open`."
    (once-only (direction element-type if-exists if-does-not-exist external-format)
      `(with-open-stream
           (,stream (apply #'open ,filespec
                           (append
                            (when ,direction
                              (list :direction ,direction))
                            (when ,element-type
                              (list :element-type ,element-type))
                            (when ,if-exists
                              (list :if-exists ,if-exists))
                            (when ,if-does-not-exist
                              (list :if-does-not-exist ,if-does-not-exist))
                            (when ,external-format
                              (list :external-format ,external-format)))))
         ,@body)))
  

  (defmacro with-input-from-file ((stream-name file-name &rest args
                                                         &key (direction nil direction-p)
                                                         &allow-other-keys)
                                  &body body)
    "Evaluate `body` with `stream-name` to an input stream on the file
`file-name`. `args` is sent as is to the call to `open` except `external-format`,
which is only sent to `with-open-file` when it's not `nil`."
    (declare (ignore direction))
    (when direction-p
      (error "Can't specifiy :DIRECTION for WITH-INPUT-FROM-FILE."))
    `(with-open-file* (,stream-name ,file-name :direction :input ,@args)
       ,@body))
  

  (defun read-file-into-string (pathname &key (buffer-size 4096) external-format)
    "Return the contents of the file denoted by `pathname` as a fresh string.

The `external-format` parameter will be passed directly to `with-open-file`
unless it's `nil`, which means the system default."
    (with-input-from-file
        (file-stream pathname :external-format external-format)
      (let ((*print-pretty* nil))
        (with-output-to-string (datum)
          (let ((buffer (make-array buffer-size :element-type 'character)))
            (loop
              :for bytes-read = (read-sequence buffer file-stream)
              :do (write-sequence buffer datum :start 0 :end bytes-read)
              :while (= bytes-read buffer-size)))))))
  

  (defun take (n sequence)
    "Take the first `n` elements from `sequence`."
    (subseq sequence 0 n))
  

  (defun n-grams (n sequence)
    "Find all `n`-grams of the sequence `sequence`."
    (assert (and (plusp n)
                 (<= n (length sequence))))
    
    (etypecase sequence
      ;; Lists
      (list (loop :repeat (1+ (- (length sequence) n))
                  :for seq :on sequence
                  :collect (take n seq)))
      
      ;; General sequences
      (sequence (loop :for i :to (- (length sequence) n)
                      :collect (subseq sequence i (+ i n))))))
  

  (defun range (start end &key (step 1) (key 'identity))
    "Return the list of numbers `n` such that `start <= n < end` and
`n = start + k*step` for suitable integers `k`. If a function `key` is
provided, then apply it to each number."
    (assert (<= start end))
    (loop :for i :from start :below end :by step :collecting (funcall key i)))
  

  (defun rcurry (function &rest arguments)
    "Returns a function that applies the arguments it is called
with and `arguments` to `function`."
    (declare (optimize (speed 3) (safety 1) (debug 1)))
    (let ((fn (ensure-function function)))
      (lambda (&rest more)
        (declare (dynamic-extent more))
        (multiple-value-call fn (values-list more) (values-list arguments)))))
  

  (deftype string-designator ()
    "A string designator type. A string designator is either a string, a symbol,
or a character."
    `(or symbol string character))
  
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmacro with-gensyms (names &body forms)
    "Binds each variable named by a symbol in `names` to a unique symbol around
`forms`. Each of `names` must either be either a symbol, or of the form:

    (symbol string-designator)

Bare symbols appearing in `names` are equivalent to:

    (symbol symbol)

The string-designator is used as the argument to `gensym` when constructing the
unique symbol the named variable will be bound to."
    `(let ,(mapcar (lambda (name)
                     (multiple-value-bind (symbol string)
                         (etypecase name
                           (symbol
                            (values name (symbol-name name)))
                           ((cons symbol (cons string-designator null))
                            (values (first name) (string (second name)))))
                       `(,symbol (gensym ,string))))
            names)
       ,@forms))

  (defmacro with-unique-names (names &body forms)
    "Binds each variable named by a symbol in `names` to a unique symbol around
`forms`. Each of `names` must either be either a symbol, or of the form:

    (symbol string-designator)

Bare symbols appearing in `names` are equivalent to:

    (symbol symbol)

The string-designator is used as the argument to `gensym` when constructing the
unique symbol the named variable will be bound to."
    `(with-gensyms ,names ,@forms))
  )                                        ; eval-when
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun extract-function-name (spec)
    "Useful for macros that want to mimic the functional interface for functions
like `#'eq` and `'eq`."
    (if (and (consp spec)
             (member (first spec) '(quote function)))
        (second spec)
        spec))
  )                                        ; eval-when

  (eval-when (:compile-toplevel :load-toplevel :execute)
    (defun generate-switch-body (whole object clauses test key &optional default)
      (with-gensyms (value)
        (setf test (extract-function-name test))
        (setf key (extract-function-name key))
        (when (and (consp default)
                   (member (first default) '(error cerror)))
          (setf default `(,@default "No keys match in SWITCH. Testing against ~S with ~S."
                                    ,value ',test)))
        `(let ((,value (,key ,object)))
           (cond ,@(mapcar (lambda (clause)
                             (if (member (first clause) '(t otherwise))
                                 (progn
                                   (when default
                                     (error "Multiple default clauses or illegal use of a default clause in ~S."
                                            whole))
                                   (setf default `(progn ,@(rest clause)))
                                   '(()))
                                 (destructuring-bind (key-form &body forms) clause
                                   `((,test ,value ,key-form)
                                     ,@forms))))
                           clauses)
                 (t ,default))))))

  (defmacro switch (&whole whole (object &key (test 'eql) (key 'identity))
                    &body clauses)
    "Evaluates first matching clause, returning its values, or evaluates and
returns the values of `default` if no keys match."
    (generate-switch-body whole object clauses test key))

  (defmacro eswitch (&whole whole (object &key (test 'eql) (key 'identity))
                     &body clauses)
    "Like `switch`, but signals an error if no key matches."
    (generate-switch-body whole object clauses test key '(error)))

  (defmacro cswitch (&whole whole (object &key (test 'eql) (key 'identity))
                     &body clauses)
    "Like `switch`, but signals a continuable error if no key matches."
    (generate-switch-body whole object clauses test key '(cerror "Return NIL from CSWITCH.")))
  
(eval-when (:compile-toplevel :load-toplevel :execute)
  (export '(curry define-constant ensure-boolean read-file-into-string n-grams
            range rcurry switch eswitch cswitch with-gensyms with-unique-names)))

;;;; END OF quickutils.lisp ;;;;

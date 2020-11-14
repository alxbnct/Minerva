(in-package :minerva)

;; Set this variable to your desired intermediates directory before running tests
(defvar *intermediates-pathname* (assert *intermediates-pathname*))

(defparameter *test-output* *standard-output*)

(defun compile-scheme (input)
  (with-output-to-file (make-pathname :name "test" :type "s" :defaults *intermediates-pathname*) (compile-program input)))

(defun clean-test ()
  (let ((test-s-pathname (make-pathname :name "test" :type "s" :defaults *intermediates-pathname*)))
    (when (probe-file test-s-pathname) (delete-file test-s-pathname)))
  (let ((main-exe-pathname (make-pathname :name "main" :type "exe" :defaults *intermediates-pathname*)))
    (when (probe-file main-exe-pathname) (delete-file main-exe-pathname))))

(defun compile-c ()
  (uiop:run-program (list "gcc" "test.s" "runtime.c" "-m32" "-o" "main") :directory *intermediates-pathname*))

(defun run-c ()
  #+win32
  (uiop:run-program (list (make-pathname :name "main" :type "exe" :defaults *intermediates-pathname*)) :output *test-output*)
  #+linux
  (uiop:run-program (list (make-pathname :name "main" :defaults *intermediates-pathname*)) :output *test-output*))

(defun test-case (input expected-output)
      (let* ((raw-output
	      (with-output-to-string (*test-output*)
		(progn
		  (clean-test)
		  (compile-scheme input)
		  (compile-c)
		  (run-c))))
	     (output (subseq raw-output 0 (- (length raw-output) 2)))
	     (result (string= expected-output output)))
	(format t "~:[FAILED~;passed~] case: ~s | expected output: ~a ~:[| actual output: ~a~;~]~%" result input expected-output result output)
	result))

(defun test-section (string)
  (format t "~a~%" string)
  t)

(defun run-all-tests ()
  (and
   (test-section "Immediate Constants:")
   (test-case 1337 "1337")
   (test-case #\F "F")
   (test-case #t "#t")
   (test-case #f "#f")
   (test-case nil "()")
   (test-section "Unary Primitives:")
   (test-case '(add1 80084) "80085")
   (test-case '(integer->char 90) "Z")
   (test-case '(char->integer #\Z) "90")
   (test-case '(zero? 0) "#t")
   (test-case '(zero? 1) "#f")
   (test-case '(null? nil) "#t")
   (test-case '(null? #\n) "#f")
   (test-case '(not #f) "#t")
   (test-case '(not 1) "#f")
   (test-case '(integer? 1337) "#t")
   (test-case '(integer? #t) "#f")
   (test-case '(boolean? #f) "#t")
   (test-case '(boolean? 1337) "#f")
   (test-case '(add1 (char->integer #\Z)) "91")
   (test-case '(add1 (char->integer (integer->char 90))) "91")
   (test-section "Binary Primitives:")
   (test-case '(+ 5 23) "28")
   (test-case '(- 1340 3) "1337")
   (test-case '(+ (- 4 3) (- 2 1)) "2")
   (test-case '(* 25 4) "100")
   (test-case '(* (+ 4 3) (- 2 1)) "7")
   (test-case '(= 13 37) "#f")
   (test-case '(= 3 (+ 2 1)) "#t")
   (test-case '(> 23 5) "#t")
   (test-case '(> 13 37) "#f")
   (test-case '(> 11 11) "#f")
   (test-section "Local Variables:")
   (test-case '(let ((a 1337)) a) "1337")
   (test-case '(let ((b #\V)) b) "V")
   (test-case '(let ((c nil)) c) "()")
   (test-case '(let ((d #f)) d) "#f")
   (test-case '(let ((foo 3)) (* foo foo)) "9")
   (test-case '(let ((one 4) (two 3) (three 2) (four 1)) (* (+ two four) (- one three))) "8")
   (test-case '(let ((a 1330)) (let ((b 7)) (+ a b))) "1337")
   (test-section "Conditional Expressions:")
   (test-case '(if (zero? 0) (+ 1330 7) (* 21 2)) "1337")
   (test-case '(if (zero? 1) (+ 1330 7) (* 21 2)) "42")
   (test-case '(let ((a (integer? 1))) (if a #\F 0)) "F")
   (test-section "Heap Allocation:")
   (test-case '(cons 1 2) "(1 . 2)")
   (test-case '(car (cons 10 20)) "10")
   (test-case '(cdr (cons 10 20)) "20")
   (test-case '(car (cons #t #f)) "#t")
   (test-case '(cdr (cons #\P #\Q)) "Q")
   (test-case '(cdr (cons 1 ())) "()")
   (test-case '(car (cdr (cons 10 (cons 20 ())))) "20")
   (test-case '(let ((a (cons #t #f))) (if (car a) 1 2)) "1")
   (test-case '(make-vector 3) "#(0 0 0)")
   (test-case '(let ((a (make-vector 3))) (let ((b (vector-set! a 1 1337))) a)) "#(0 1337 0)")
   (test-case '(let ((a (make-vector 128))) (let ((b (vector-set! a 127 #f))) (vector-ref a 127))) "#f")
   (test-case '(let ((s (make-string 3))) (let ((a (string-set! s 0 #\b)) (b (string-set! s 1 #\a)) (c (string-set! s 2 #\z))) s)) "\"baz\"")
   (test-case '(let ((s (make-string 3))) (let ((a (string-set! s 0 #\h)) (b (string-set! s 1 #\i))) (string-ref s 1))) "i")
   (test-case '(let ((v (make-vector 1))) (vector-set! v 0 1337) (vector-ref v 0)) "1337")
   (test-section "Closures:")
   (test-case '(lambda (x) x) "#<procedure>")
   (test-case '(funcall (lambda (x) x) 1337) "1337")
   (test-case '(funcall (lambda () 1337)) "1337")
   (test-case '(let ((x 5)) (lambda () (+ x 1))) "#<procedure>")
   (test-case '(let ((x 5)) (let ((foo (lambda () (+ x 1)))) (funcall foo))) "6")
   (test-case '(funcall (lambda (x) (* x x)) 4) "16")
   (test-case '(let ((x 5)) (lambda (y) (lambda () (+ x y)))) "#<procedure>")
   (test-case '(let ((sqr (lambda (x) (* x x)))) (funcall sqr 4)) "16")
   (test-case '(let ((v (make-vector 1))) (funcall (lambda () (vector-set! v 0 1337) (vector-ref v 0)))) "1337")
   (test-section "Complex Constants:")
   (test-case '(quote (1 . 2)) "(1 . 2)")
   (test-case '(car (quote (1 . 2))) "1")
   (test-case '(let ((f (lambda () (quote (1 . "H"))))) (eq? (funcall f) (funcall f))) "#t")
   (test-section "Assignment:")
   (test-case '(let ((a 1333)) (set! a (+ a 2)) (funcall (lambda (a b) (set! a (+ a 1)) (+ a b)) 1 a)) "1337")
   (test-case '(let ((z 1)) (let ((z (let ((z z)) (set! z (+ z 1)) z))) (+ z 1))) "3")))

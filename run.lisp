(require 'asdf)
(asdf:load-asd (merge-pathnames (uiop/os:getcwd) #P"minerva.asd"))
(asdf:load-system :minerva)
(in-package :minerva)
(run-all-tests)

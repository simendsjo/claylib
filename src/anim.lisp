(in-package #:claylib)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defclass rl-bone-info ()
    ((%c-struct
      :type claylib/ll:bone-info
      :initform (autowrap:calloc 'claylib/ll:bone-info)
      :accessor c-struct))))

(defcreader name rl-bone-info name bone-info)  ; TODO: Array/string
(defcreader parent rl-bone-info parent bone-info)

(defcwriter name rl-bone-info name bone-info string)  ; TODO: Array/string
(defcwriter parent rl-bone-info parent bone-info integer)

(definitializer rl-bone-info
  :pt-accessors ((name string)
                 (parent integer)))

(default-free rl-bone-info)
(default-free-c claylib/ll:bone-info)



(eval-when (:compile-toplevel :load-toplevel :execute)
  (defclass rl-model-animation ()
    ((%bones :initarg :bones
             :type rl-bones
             :reader bones)
     (%frame-poses :initarg :frame-poses
                   :type rl-transform  ; TODO: Array/pointer-pointer
                   :reader frame-poses)
     (%c-struct
      :type claylib/ll:model-animation
      :initform (autowrap:calloc 'claylib/ll:model-animation)
      :accessor c-struct))))

(defcreader bone-count rl-model-animation bone-count model-animation)
(defcreader frame-count rl-model-animation frame-count model-animation)

(defcwriter bone-count rl-model-animation bone-count model-animation integer)
(defcwriter frame-count rl-model-animation frame-count model-animation integer)
(defcwriter-struct bones rl-model-animation bones model-animation bone-info name parent)  ; TODO: Array/pointer
(defcwriter-struct frame-poses
  rl-model-animation frame-poses model-animation transform translation rotation scale)

(defmethod sync-children ((obj rl-model-animation))
  (flet ((i0 (array type)
           (autowrap:c-aref array 0 type)))
    (unless (eq (c-struct (bones obj))
                (i0 (model-animation.bones (c-struct obj)) 'claylib/ll:bone-info))
      (free-later (c-struct (bones obj)))
      (setf (c-struct (bones obj))
            (i0 (model-animation.bones (c-struct obj)) 'claylib/ll:bone-info)))
    (unless (eq (c-struct (frame-poses obj))
                (i0 (model-animation.frame-poses (c-struct obj)) 'claylib/ll:transform))
      (free-later (c-struct (frame-poses obj)))
      (setf (c-struct (frame-poses obj))
            (i0 (model-animation.frame-poses (c-struct obj)) 'claylib/ll:transform)))
    (sync-children (frame-poses obj))))

(definitializer rl-model-animation
  :struct-slots ((%bones) (%frame-poses))
  :pt-accessors ((bone-count integer)
                 (frame-count integer)))

(default-free rl-model-animation %bones %frame-poses)

(defmethod free ((anim claylib/ll:model-animation))
  ;; TODO: Access the num somehow and use UNLOAD-MODEL-ANIMATIONS to unload all of them
  (when (autowrap:valid-p anim)
    (unload-model-animation anim)
    (autowrap:free anim)))



(cffi:defcstruct bone-info
  (name :char :count 32)
  (parent :int))
(defconstant +foreign-bone-info-size+ (cffi:foreign-type-size '(:struct bone-info)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defclass rl-bones (sequences:sequence)
    ((%cl-array :type (array rl-bone-info 1)
                :initarg :cl-array
                :reader cl-array
                :documentation "An RL-BONE-INFO array tracking the C BoneInfo array underneath."))))

(defun make-bones-array (c-struct bone-count)
  "Make an array of rl-bone-info objects using BONE-COUNT elements of the BoneInfo wrapper C-STRUCT.

Warning: this can refer to bogus C data if BONE-COUNT does not match the real C array length."
  (let ((contents (loop for i below bone-count
                        for bone = (make-instance 'rl-bone-info)
                        do (setf (slot-value bone '%c-struct)
                                 (autowrap:c-aref c-struct i 'claylib/wrap:bone-info))
                        collect bone)))
    (make-array bone-count
                :element-type 'rl-bone-info
                :initial-contents contents)))

(defmethod sequences:length ((sequence rl-bones))
  (length (cl-array sequence)))

(defmethod sequences:elt ((sequence rl-bones) index)
  (elt (cl-array sequence) index))

(defmethod (setf sequences:elt) (value (sequence rl-bones) index)
  (check-type value rl-bone-info)
  (cffi:foreign-funcall "memcpy"
                        :pointer (autowrap:ptr (c-struct (elt sequence index)))
                        :pointer (autowrap:ptr (c-struct value))
                        :int +foreign-bone-info-size+
                        :void))

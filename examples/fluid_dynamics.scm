;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; A Simple Fluid Dynamics Example:
;;
;; A nice and simple 3d fluid simulation
;; based on code from Jos Stam and Mike Ash.
;;
;; This little example is nice and simple
;; The computation is all on the CPU and
;; the density of each cell is drawn using
;; very simple immediate OpenGL calls.
;;
;; The simulation is a little smoke sim
;; with constant air streams from bottom->top
;; and from left->right.  Smoke is injected
;; into the system semi-regularly.
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; First the fluid dynamics code
;;
;; code here largely pilfered from from
;; Jos Stam and Mike Ash
;;

(bind-type fluidcube <i64,double,double,double,double*,double*,double*,double*,double*,double*,double*,double*>)

(definec fluid-ix
  (lambda (x:i64 y:i64 z:i64 N:i64)
    (+ x (* y N) (* z N N))))

(definec fluid-cube-create
  (lambda (size diffusion viscosity dt:double)
    (let ((cube (heap-alloc fluidcube))
	  (size3:i64 (* size size size))
	  (s (heap-alloc size3 double))
	  (density (heap-alloc size3 double))
	  (Vx (heap-alloc size3 double))
	  (Vy (heap-alloc size3 double))
	  (Vz (heap-alloc size3 double))
	  (Vx0 (heap-alloc size3 double))
	  (Vy0 (heap-alloc size3 double))
	  (Vz0 (heap-alloc size3 double)))
      (tfill! cube size dt diffusion viscosity s density Vx Vy Vz Vx0 Vy0 Vz0)
      cube)))


(definec fluid-cube-add-density
  (lambda (cube:fluidcube* x y z amount:double)
    (let ((N (tref cube 0))
	  (idx (fluid-ix x y z N))
	  (density-ptr:double* (tref cube 5))
	  (density (aref density-ptr idx)))
      (aset! density-ptr idx (+ density amount))
      (+ density amount))))
	  

(definec fluid-cube-add-velocity
  (lambda (cube:fluidcube* x y z amount-x:double amount-y:double amount-z:double)
    (let ((N (tref cube 0))
	  (idx (fluid-ix x y z N))
	  (_Vx (tref cube 6))
	  (_Vy (tref cube 7))
	  (_Vz (tref cube 8)))
      (aset! _Vx idx (+ amount-x (aref _Vx idx)))
      (aset! _Vy idx (+ amount-y (aref _Vy idx)))
      (aset! _Vz idx (+ amount-z (aref _Vz idx)))
      cube)))


(definec fluid-set-boundary
  (lambda (b:i64 x:double* N:i64)
    (dotimes (j (- N 2))
      (dotimes (i (- N 2))
	(if (= b 3)
	    (aset! x (fluid-ix (+ i 1) (+ j 1) 0 N)
		   (- 0.0 (aref x (fluid-ix (+ i 1) (+ j 1) 1 N)))
		   (aref x (fluid-ix (+ i 1) (+ j 1) 1 N))))
	(if (= b 3)
	    (aset! x (fluid-ix (+ i 1) (+ j 1) (- N 1) N)
		   (- 0.0 (aref x (fluid-ix (+ i 1) (+ j 1) (- N 2) N)))
		   (aref x (fluid-ix (+ i 1) (+ j 1) (- N 2) N))))))
    (dotimes (kk (- N 2))
      (dotimes (ii (- N 2))
	(if (= b 2)
	    (aset! x (fluid-ix (+ ii 1) 0 (+ kk 1) N)
		   (- 0.0 (aref x (fluid-ix (+ ii 1) 1 (+ kk 1) N)))
		   (aref x (fluid-ix (+ ii 1) 1 (+ kk 1) N))))
	(if (= b 2)
	    (aset! x (fluid-ix (+ ii 1) (- N 1) (+ kk 1) N)
		   (- 0.0 (aref x (fluid-ix (+ ii 1) (- N 2) (+ kk 1) N)))
		   (aref x (fluid-ix (+ ii 1) (- N 2) (+ kk 1) N))))))
    (dotimes (kkk (- N 2))
      (dotimes (jjj (- N 2))
	(if (= b 1)
	    (aset! x (fluid-ix 0 (+ jjj 1) (+ kkk 1) N)
		   (- 0.0 (aref x (fluid-ix 1 (+ jjj 1) (+ kkk 1) N)))
		   (aref x (fluid-ix 1 (+ jjj 1) (+ kkk 1) N))))
	(if (= b 1)
	    (aset! x (fluid-ix (- N 1) (+ jjj 1) (+ kkk 1) N)
		   (- 0.0 (aref x (fluid-ix (- N 2) (+ jjj 1) (+ kkk 1) N)))
		   (aref x (fluid-ix (- N 2) (+ jjj 1) (+ kkk 1) N))))))

    (aset! x (fluid-ix 0 0 0 N)
	   (* 0.33333 (+ (aref x (fluid-ix 1 0 0 N))
			 (aref x (fluid-ix 0 1 0 N))
			 (aref x (fluid-ix 0 0 1 N)))))

    (aset! x (fluid-ix 0 (- N 1) 0 N)
	   (* 0.33333 (+ (aref x (fluid-ix 1 (- N 1) 0 N))
			 (aref x (fluid-ix 0 (- N 2) 0 N))
			 (aref x (fluid-ix 0 (- N 1) 1 N)))))

    (aset! x (fluid-ix 0 0 (- N 1) N)
	   (* 0.33333 (+ (aref x (fluid-ix 1 0 (- N 1) N))
			 (aref x (fluid-ix 0 1 (- N 1) N))
			 (aref x (fluid-ix 0 0 N N)))))

    (aset! x (fluid-ix 0 (- N 1) (- N 1) N)
	   (* 0.33333 (+ (aref x (fluid-ix 1 (- N 1) (- N 1) N))
			 (aref x (fluid-ix 0 (- N 2) (- N 1) N))
			 (aref x (fluid-ix 0 (- N 1) (- N 2) N)))))
    
    (aset! x (fluid-ix (- N 1) 0 0 N)
	   (* 0.33333 (+ (aref x (fluid-ix (- N 2) 0 0 N))
			 (aref x (fluid-ix (- N 1) 1 0 N))
			 (aref x (fluid-ix (- N 1) 0 1 N)))))

    (aset! x (fluid-ix (- N 1) (- N 1) 0 N)
	   (* 0.33333 (+ (aref x (fluid-ix (- N 2) (- N 1) 0 N))
			 (aref x (fluid-ix (- N 1) (- N 2) 0 N))
			 (aref x (fluid-ix (- N 1) (- N 1) 1 N)))))

    (aset! x (fluid-ix (- N 1) 0 (- N 1) N)
	   (* 0.33333 (+ (aref x (fluid-ix (- N 2) 0 (- N 1) N))
			 (aref x (fluid-ix (- N 1) 1 (- N 1) N))
			 (aref x (fluid-ix (- N 1) 0 (- N 2) N)))))

    (aset! x (fluid-ix (- N 1) (- N 1) (- N 1) N)
	   (* 0.33333 (+ (aref x (fluid-ix (- N 2) (- N 1) (- N 1) N))
			 (aref x (fluid-ix (- N 1) (- N 2) (- N 1) N))
			 (aref x (fluid-ix (- N 1) (- N 1) (- N 2) N)))))
    1))

            	    

(definec fluid-lin-solve
  (lambda (b:i64 x:double* x0:double* a c iter:i64 N:i64)
    (let ((cRecip (/ 1.0 c)))
      (dotimes (k iter)
	(dotimes (m (- N 2))
	  (dotimes (j (- N 2))
	    (dotimes (i (- N 2))
	      (aset! x (fluid-ix (+ i 1) (+ j 1) (+ m 1) N)
		     (* cRecip
			(+ (aref x0 (fluid-ix (+ i 1) (+ j 1) (+ m 1) N))
			   (* a (+ (aref x (fluid-ix (+ i 2) (+ j 1) (+ m 1) N))
				   (aref x (fluid-ix i (+ j 1) (+ m 1) N))
				   (aref x (fluid-ix (+ i 1) (+ j 2) (+ m 1) N))
				   (aref x (fluid-ix (+ i 1) j (+ m 1) N))
				   (aref x (fluid-ix (+ i 1) (+ j 1) (+ m 2) N))
				   (aref x (fluid-ix (+ i 1) (+ j 1) m N))))))))))
	(fluid-set-boundary b x N)))
    1))


(definec fluid-diffuse
  (lambda (b:i64 x:double* x0:double* diff:double dt:double iter N)
    (let ((a:double (* dt diff (i64tod (* (- N 2) (- N 2))))))
      (fluid-lin-solve b x x0 a (+ 1.0 (* 6.0 a)) iter N))))


(definec fluid-project
  (lambda (velocx:double* velocy:double* velocz:double* p:double* div:double* iter N)
    (dotimes (k (- N 2))
      (dotimes (j (- N 2))
	(dotimes (i (- N 2))
	  (aset! div (fluid-ix (+ i 1) (+ j 1) (+ k 1) N)
		 (* -0.5 (/ (+ (- (aref velocx (fluid-ix (+ i 2) (+ j 1) (+ k 1) N))
				  (aref velocx (fluid-ix i (+ j 1) (+ k 1) N)))
			       (- (aref velocy (fluid-ix (+ i 1) (+ j 2) (+ k 1) N))
				  (aref velocy (fluid-ix (+ i 1) j (+ k 1) N)))
			       (- (aref velocz (fluid-ix (+ i 1) (+ j 1) (+ k 2) N))
				  (aref velocz (fluid-ix (+ i 1) (+ j 1) k N))))
			    (i64tod N))))
	  (aset! p (fluid-ix (+ i 1) (+ j 1) (+ k 1) N) 0.0)
	  1)))
    
    (fluid-set-boundary 0 div N)
    (fluid-set-boundary 0 p N)
    (fluid-lin-solve 0 p div 1.0 6.0 iter N)

    (dotimes (kk (- N 2))
      (dotimes (jj (- N 2))
	(dotimes (ii (- N 2))
	  (aset! velocx (fluid-ix (+ ii 1) (+ jj 1) (+ kk 1) N)
		 (- (aref velocx (fluid-ix (+ ii 1) (+ jj 1) (+ kk 1) N))
		    (* 0.5
		       (- (aref p (fluid-ix (+ ii 2) (+ jj 1) (+ kk 1) N))
			  (aref p (fluid-ix (+ ii 0) (+ jj 1) (+ kk 1) N)))
		       (i64tod N))))
	  (aset! velocy (fluid-ix (+ ii 1) (+ jj 1) (+ kk 1) N)
		 (- (aref velocy (fluid-ix (+ ii 1) (+ jj 1) (+ kk 1) N))
		    (* 0.5
		       (- (aref p (fluid-ix (+ ii 1) (+ jj 2) (+ kk 1) N))
			  (aref p (fluid-ix (+ ii 1) (+ jj 0) (+ kk 1) N)))
		       (i64tod N))))
	  (aset! velocz (fluid-ix (+ ii 1) (+ jj 1) (+ kk 1) N)
		 (- (aref velocz (fluid-ix (+ ii 1) (+ jj 1) (+ kk 1) N))
		    (* 0.5
		       (- (aref p (fluid-ix (+ ii 1) (+ jj 1) (+ kk 2) N))
			  (aref p (fluid-ix (+ ii 1) (+ jj 1) (+ kk 0) N)))
		       (i64tod N))))
	  1)))

    (fluid-set-boundary 1 velocx N)
    (fluid-set-boundary 2 velocy N)
    (fluid-set-boundary 3 velocz N)
    
    1))


(definec fluid-advect
  (lambda (b:i64 d:double* d0:double* velocx:double* velocy:double* velocz:double* dt:double N:i64)
    (let ((n-2 (i64tod (- N 2)))
	  (dtx (* dt n-2))
	  (dty dtx)
	  (dtz dty)
	  (kfloat 0.0)
	  (jfloat 0.0)
	  (ifloat 0.0)
	  (s0 0.0)
	  (s1 0.0)
	  (t0 0.0)
	  (t1 0.0)
	  (u0 0.0)
	  (u1 0.0)
	  (i0 0.0)
	  (i0i 0)	 
	  (i1 0.0)
	  (i1i 0)
	  (j0 0.0)
	  (j0i 0)	 
	  (j1 0.0)
	  (j1i 0)
	  (k0 0.0)
	  (k0i 0)
	  (k1 0.0)
	  (k1i 0)
	  (Nfloat (i64tod N)))
      (dotimes (k (- N 2))
	(set! kfloat (+ kfloat 1.0))
	(set! jfloat 0.0)
	(dotimes (j (- N 2))
	  (set! jfloat (+ jfloat 1.0))
	  (set! ifloat 0.0)
	  (dotimes (i (- N 2))
	    (set! ifloat (+ ifloat 1.0))
	    (let ((tmp1 (* dtx (aref velocx (fluid-ix (+ i 1) (+ j 1) (+ k 1) N))))
		  (tmp2 (* dty (aref velocy (fluid-ix (+ i 1) (+ j 1) (+ k 1) N))))
		  (tmp3 (* dtz (aref velocz (fluid-ix (+ i 1) (+ j 1) (+ k 1) N))))
		  (x (- ifloat tmp1))
		  (y (- jfloat tmp2))
		  (z (- kfloat tmp3)))
	      
	      (if (< x 0.5) (set! x 0.5))
	      (if (> x (+ Nfloat 0.5)) (set! x (+ Nfloat 0.5)))
	      (set! i0 (floor x))
	      (set! i1 (+ i0 1.0))
	      (if (< y 0.5) (set! y 0.5))
	      (if (> y (+ Nfloat 0.5)) (set! y (+ Nfloat 0.5)))
	      (set! j0 (floor y))
	      (set! j1 (+ j0 1.0))
	      (if (< z 0.5) (set! z 0.5))
	      (if (> z (+ Nfloat 0.5)) (set! z (+ Nfloat 0.5)))
	      (set! k0 (floor z))
	      (set! k1 (+ k0 1.0))

	      (set! s1 (- x i0))
	      (set! s0 (- 1.0 s1))
	      (set! t1 (- y j0))
	      (set! t0 (- 1.0 t1))
	      (set! u1 (- z k0))
	      (set! u0 (- 1.0 u1))

	      (set! i0i (dtoi64 i0))
	      (set! i1i (dtoi64 i1))	      
	      (set! j0i (dtoi64 j0))
	      (set! j1i (dtoi64 j1))	      
	      (set! k0i (dtoi64 k0))
	      (set! k1i (dtoi64 k1))

	      (aset! d (fluid-ix (+ i 1) (+ j 1) (+ k 1) N)
	      	     (+ (* s0 (+ (* t0 (+ (* u0 (aref d0 (fluid-ix i0i j0i k0i N)))
	      				  (* u1 (aref d0 (fluid-ix i0i j0i k1i N)))))
	      			 (* t1 (+ (* u0 (aref d0 (fluid-ix i0i j1i k0i N)))
	      				  (* u1 (aref d0 (fluid-ix i0i j1i k1i N)))))))
	      		(* s1 (+ (* t0 (+ (* u0 (aref d0 (fluid-ix i1i j0i k0i N)))
	      				  (* u1 (aref d0 (fluid-ix i1i j0i k1i N)))))
	      			 (* t1 (+ (* u0 (aref d0 (fluid-ix i1i j1i k0i N)))
	      				  (* u1 (aref d0 (fluid-ix i1i j1i k1i N)))))))))))))
      
      (fluid-set-boundary b d N))))
				 
				 
      
(definec fluid-step-cube
  (lambda (cube:fluidcube*)
    (let ((N (tref cube 0))
	  (dt (tref cube 1))	  
	  (diff (tref cube 2))
	  (visc (tref cube 3))	  
	  (s (tref cube 4))
	  (density (tref cube 5))
	  (Vx (tref cube 6))
	  (Vy (tref cube 7))
	  (Vz (tref cube 8))
	  (Vx0 (tref cube 9))
	  (Vy0 (tref cube 10))
	  (Vz0 (tref cube 11)))
     
      (fluid-diffuse 1 Vx0 Vx visc dt 4 N)
      (fluid-diffuse 2 Vy0 Vy visc dt 4 N)
      (fluid-diffuse 3 Vz0 Vz visc dt 4 N)

      (dotimes (k (* N N N))
      	(aset! Vx k 0.0)
      	(aset! Vy k 0.0))
      	(aset! Vz k 0.0))
      
      (fluid-project Vx0 Vy0 Vz0 Vx Vy 4 N)

      (fluid-advect 1 Vx Vx0 Vx0 Vy0 Vz0 dt N)
      (fluid-advect 2 Vy Vy0 Vx0 Vy0 Vz0 dt N)
      (fluid-advect 3 Vz Vz0 Vx0 Vy0 Vz0 dt N)

      (dotimes (kk (* N N N))
      	(aset! Vx0 kk 0.0)
      	(aset! Vy0 kk 0.0)
      	(aset! Vz0 kk 0.0))                               
      
      (fluid-project Vx Vy Vz Vx0 Vy0 4 N)
      
      (fluid-diffuse 0 s density diff dt 4 N)

      (fluid-advect 0 density s Vx Vy Vz dt N)
      
      cube)))


(definec get-fluid-cube
  (let ((cube (fluid-cube-create 22 0.001 0.1 0.002)))
    (lambda ()
      cube)))



;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Next Some OpenGL Stuff    

(define libglu (if (string=? "Linux" (sys:platform))
		   (sys:open-dylib "libGLU.so")
		   (if (string=? "Windows" (sys:platform))
		       (sys:open-dylib "Glu32.dll")
		       #f)))

(bind-lib libglu gluLookAt [void,double,double,double,double,double,double,double,double,double]*)
(bind-lib libglu gluPerspective [void,double,double,double,double]*)
(bind-lib libglu gluErrorString [i8*,i32]*)

(definec setup
  (lambda ()
    (glEnable GL_LIGHTING)
    (glEnable GL_LIGHT0)
    (let ((diffuse (heap-alloc 4 float))
	  (specular (heap-alloc 4 float))
	  (position (heap-alloc 4 float)))      
      (aset! diffuse 0 1.0)
      (aset! diffuse 1 0.3)
      (aset! diffuse 2 0.0)
      (aset! diffuse 3 1.0)
      (aset! specular 0 1.0)
      (aset! specular 2 1.0)
      (aset! specular 3 1.0)
      (aset! specular 4 1.0)
      (aset! position 0 100.0)
      (aset! position 1 100.0)
      (aset! position 2 100.0)
      (aset! position 3 0.0)

      (glLightfv GL_LIGHT0 GL_DIFFUSE diffuse)
      (glLightfv GL_LIGHT0 GL_SPECULAR specular)
      (glLightfv GL_LIGHT0 GL_POSITION position))
    
    (glEnable GL_DEPTH_TEST)
    (glShadeModel GL_FLAT)
    (glEnable GL_BLEND)
    (glBlendFunc GL_ONE GL_SRC_ALPHA)))


(definec set-view
  (lambda ()
    (glViewport 0 0 1024 768)
    (glMatrixMode 5889)
    (glLoadIdentity)
    (gluPerspective 27.0 (/ 1024.0 768.0) 1.0 1000.0)
    (glMatrixMode 5888)
    (glEnable 2929)
    (setup)
    1))
 
(definec add-density
  (lambda (x:i64 y:i64 z:i64 amount:double)
    (let ((cube (get-fluid-cube)))
      (fluid-cube-add-density cube x y z amount))))

(definec add-velocity
  (lambda (x y z amount-x amount-y amount-z)
    (fluid-cube-add-velocity (get-fluid-cube) x y z amount-x amount-y amount-z)))

(definec get-velocity
  (lambda (x y z)
    (let ((xs (tref (get-fluid-cube) 6))
	  (size (tref (get-fluid-cube) 0)))
      (aref xs (fluid-ix x y z size)))))


(definec look-at
  (lambda (eyex eyey eyez centre-x centre-y centre-z up-x up-y up-z)
    (glLoadIdentity)
    (gluLookAt eyex eyey eyez centre-x centre-y centre-z up-x up-y up-z)))


(definec glCube
  (let ((dlist -1))
    (lambda ()
      (if (> dlist -1)
	  (begin (glCallList dlist) 1)
	  (begin (set! dlist (glGenLists 1))
		 (glNewList dlist (+ GL_COMPILE 1))
		 (glBegin GL_QUADS)
		 ;; Front face
		 (glNormal3d 0.0 0.0 1.0)
		 (glVertex3d 0.0 0.0  1.0)
		 (glVertex3d 1.0 0.0  1.0)
		 (glVertex3d 1.0  1.0  1.0)
		 (glVertex3d 0.0  1.0  1.0)
		 ;; Back face
		 (glNormal3d 0.0 0.0 -1.0)
		 (glVertex3d 0.0 0.0 0.0)
		 (glVertex3d 0.0  1.0 0.0)
		 (glVertex3d 1.0  1.0 0.0)
		 (glVertex3d 1.0 0.0 0.0)
		 ;; Top face
		 (glNormal3d 0.0 1.0 0.0)
		 (glVertex3d 0.0  1.0 0.0)
		 (glVertex3d 0.0  1.0  1.0)
		 (glVertex3d 1.0  1.0  1.0)
		 (glVertex3d 1.0  1.0 0.0)
		 ;; Bottom face
		 (glNormal3d 0.0 -1.0 0.0)
		 (glVertex3d 0.0 0.0 0.0)
		 (glVertex3d 1.0 0.0 0.0)
		 (glVertex3d 1.0 0.0  1.0)
		 (glVertex3d 0.0 0.0  1.0)
		 ;; Right face
		 (glNormal3d 1.0 0.0 0.0)
		 (glVertex3d 1.0 0.0 0.0)
		 (glVertex3d 1.0  1.0 0.0)
		 (glVertex3d 1.0  1.0  1.0)
		 (glVertex3d 1.0 0.0  1.0)
		 ;; Left face
		 (glNormal3d -1.0 0.0 0.0)
		 (glVertex3d 0.0 0.0 0.0)
		 (glVertex3d 0.0 0.0  1.0)
		 (glVertex3d 0.0  1.0  1.0)
		 (glVertex3d 0.0  1.0 0.0)
		 (glEnd)
		 (glEndList)
		 1)))))


  ;; a trivial opengl draw loop
;; need to call glfwSwapBuffers to flush
(definec my-gl-loop
  (let ((degree 0.0))
    (lambda ()    
      (look-at -30.5 30.0 50.0 20.5 3.5 -1.0 0.0 1.0 0.0)
      (glClearColor 1.0 0.5 .0 1.0)
      (glClear (+ GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT))
      (glColorMaterial GL_FRONT_AND_BACK GL_AMBIENT_AND_DIFFUSE)
      (glDisable GL_DEPTH_TEST)
      (glEnable GL_COLOR_MATERIAL)      
      (glBlendFunc GL_SRC_ALPHA (+ GL_SRC_ALPHA 1))
      (glColor4d 0.0 0.0 0.0 1.0)
      (glLineWidth 1.0)
      (fluid-step-cube (get-fluid-cube))
      (let ((densities (tref (get-fluid-cube) 5))
      	    (Vx (tref (get-fluid-cube) 6))
      	    (Vy (tref (get-fluid-cube) 7))
      	    (Vz (tref (get-fluid-cube) 8))	    
      	    (size (tref (get-fluid-cube) 0))
      	    (sized (i64tod size))
      	    (cvar 0.0))

	(glTranslated 10.0 11.0 11.0)
	(glRotated (* 500.0 degree) 0.0 1.0 0.0)	
        (glTranslated -10.0 -11.0 -11.0)
	
      	(dotimes (i:double sized)
      	  (dotimes (j:double sized)
      	    (dotimes (k:double sized)
	      (let ((idx (fluid-ix (dtoi64 i) (dtoi64 j) (dtoi64 k) size))
		    (norm (sqrt (+ (* (aref Vx idx) (aref Vx idx))
				   (* (aref Vy idx) (aref Vy idx))
				   (* (aref Vz idx) (aref Vz idx))))))
		(glPushMatrix)
		(glTranslated i j k)
		(set! cvar (aref densities idx))
		(glColor4d 0.0 0.0 0.0 cvar)
		(glCube)
		;; turn 0.2 to 0.0 to stop drawing vertex arrows
		(glColor4d 1.0 0.0 0.0 0.2)
		;; if you're having performance problems you
		;; could start by commenting out the next 4 lines
		;; i.e. stop drawing the red velocity arrows
		(glBegin GL_LINES)
		(glVertex3d 0.5 0.5 0.5)
		(glVertex3d (+ 0.5 (* 0.5 (/ (aref Vx idx) norm)))
			    (+ 0.5 (* 0.5 (/ (aref Vy idx) norm)))
			    (+ 0.5 (* 0.5 (/ (aref Vz idx) norm))))
		(glEnd)
		(glPopMatrix))))))

      (set! degree (+ degree .001))
      1)))


;;
;; opengl-test includes two sources
;; of constant wind speed
;;
;; bottom->top: straight up the middle
;; left->right: oscillates from back to front
;;
;; You might need to slow the rate of this
;; temporal recursion down if your machine
;; doesn't cope.  (i.e. 3000 to 5000 or more
;;
;; standard impromptu callback
(define opengl-test
  (lambda (time degree)
    (my-gl-loop)
    ;; 1000.0 is wind speed from bottom to top
    (add-velocity 11 1 11 0.0 1000.0 0.0)
    ;; 600.0 is wind speed from left to right
    (add-velocity 2 5 11 600.0 0.0 (* 300.0 (cos (* 120.0 degree))))
    (gl:swap-buffers pr2)
    (callback time 'opengl-test (+ time 3000) (+ degree 0.001))))

;;
;; Smoke signal injects smoke into the system
;; at semi-regular intervals (* 40000 (random 4 9))
;;
(define smoke-signal
  (lambda (time)
    ;; increase 300.0 to kick more smoke into the system 
    (add-density 2 5 11 (* (random) 300.0))
    ;; decrease (random 4 9) to inject smoke more often
    (callback (+ time 4410) 'smoke-signal (+ time (* 40000 (random 4 9))))))


(define pr2 (gl:make-ctx ":0.0" #f 0.0 0.0 1024.0 768.0))
(set-view)
(opengl-test (now) 0.0)
(smoke-signal (now))
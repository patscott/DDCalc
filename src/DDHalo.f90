MODULE DDHalo

!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
! DDHalo
!    Routines for initializing and modifying the dark matter halo
!    distribution, as well as performing the mean inverse speed (eta)
!    calculation needed for recoil rates.
!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

USE DDConstants
USE DDTypes
USE DDUtils
USE DDNumerical
USE DDCommandLine
USE DDInput

IMPLICIT NONE
PRIVATE

! Convert E to vmin given the scalar or vector arguments.
! Access all versions under function name 'EToVmin'.
INTERFACE EToVmin
  MODULE PROCEDURE EToVmin0,EToVmin1,EToVmin2
END INTERFACE

! Calculate mean inverse speed from vmin given the scalar or vector
! arguments. Access all versions under function name 'MeanInverseSpeed'.
INTERFACE MeanInverseSpeed
  MODULE PROCEDURE MeanInverseSpeed0,MeanInverseSpeed1,MeanInverseSpeed2
END INTERFACE

PUBLIC :: DDCalc_GetHalo,DDCalc_SetHalo, &
          DDCalc_InitHalo,DDCalc_InitHaloCommandLine, &
          EToVmin, MeanInverseSpeed, C_DDCalc_InitHalo
INTERFACE DDCalc_GetHalo
  MODULE PROCEDURE GetHalo
END INTERFACE
INTERFACE DDCalc_SetHalo
  MODULE PROCEDURE SetHalo
END INTERFACE
INTERFACE DDCalc_InitHalo
  MODULE PROCEDURE InitHalo
END INTERFACE
INTERFACE DDCalc_InitHaloCommandLine
  MODULE PROCEDURE InitHaloCommandLine
END INTERFACE

! Parameters describing the dark matter halo.  Only the Standard Halo
! Model (SHM) can be used for the velocity distribution (i.e. Maxwell-
! Boltzmann distribution with a finite cutoff).

! Local dark matter halo density [GeV/cm^3]:
!   0.3 [standard (old)]
! * Catena & Ullio, JCAP 1008, 004 (2010) [arXiv:0907.0018]
!   For spherical halos, not including structure
!     Einasto profile: 0.385 +/- 0.027
!     NFW profile:     0.389 +/- 0.025
! * Weber & de Boer, arXiv:0910.4272
!     0.2 - 0.4 (depending on model)
! * Salucci et al., arXiv:1003.3101
!   Model independent technique?
!     0.430 +/- 0.113 (alpha) +/- 0.096 (r)
! * Pato et al., PRD 82, 023531 (2010) [arXiv:1006.1322]
!   Density at disk may be 1.01 - 1.41 times larger than shell
!   averaged quantity, so above measurements might be underestimates
!   of local density.
! DEFAULT: 0.4 GeV/cm^3

! Sun's peculiar velocity [km/s]:
! motion relative to local standard of rest (LSR)
! * Mignard, Astron. Astrophys. 354, 522 (2000)
! * Schoenrich, Binney & Dehnen, arXiv:0912.3693
! DEFAULT: (11,12,7) km/s

! Disk rotation velocity [km/s]:
! * Kerr & Lynden-Bell, MNRAS 221, 1023 (1986)
!     220 [standard]
!     222 +/- 20 (average over multiple measurements, could be biased
!                 by systematics)
! * Reid et al., Astrophys. J. 700, 137 (2009) [arXiv:0902.3913]
!   Estimate based on masers.
!     254 +/- 16
! * McMillan & Binney, MNRAS 402, 934 (2010) [arXiv:0907.4685]
!   Reanalysis of Reid et al. masers.  Range of estimates based on
!   various models; suggest Sun's velocity with respect to LSR should
!   be modified.
!     200 +/- 20 to 279 +/- 33
! * Bovy, Hogg & Rix, ApJ 704, 1704 (2009) [arXiv:0907.5423]
!     244 +/- 13 (masers only)
!     236 +/- 11 (combined estimate)
! DEFAULT: 235 km/s

! The Local Standard of Rest (LSR) [km/s], which we take to be
! (0,vrot,0).
! DEFAULT: (0,235,0) km/s

! Sun's velocity vector relative to the galactic rest frame [km/s],
! sum of LSR and peculiar velocity, where LSR = (0,vrot,0):
! DEFAULT: (0,235,0) + (11,12,7) km/s

! Sun's speed relative to the galactic rest frame [km/s].
! Equal to magnitude of Sun's velocity.
! DEFAULT: sqrt{11^2 + (235+12)^2 + 7^2} km/s

! Most probable speed (characterizing velocity dispersion) [km/s]:
! Typically similar to rotation velocity.
!     vrms = sqrt(3/2) v0    [rms velocity]
!     vmp  = v0              [most probably velocity]
!     vave = sqrt(4/pi) v0   [mean velocity]
! DEFAULT: 235 km/s

! Local escape velocity [km/s]:
!   650 [standard (old)]
! * Smith et al., MNRAS 379, 755 (2007) [astro-ph/0611671]
!   Note from Fig 7 that the distribution is asymmetric.  The following
!   results assume vrot = 220.
!     544 (mean), 498 - 608 (90% CL)
!     462 - 640 (90% CL when also fitting parameter k)
! DEFAULT: 550 km/s


CONTAINS


! ----------------------------------------------------------------------
! Get various halo quantities.
! 
! Optional output arguments regarding galactic motions:
!   vrot        Local galactic disk rotation speed [km/s].
!   vlsr        Local standard of rest velocity vector (array of size 3)
!               [km/s], defined relative to galactic rest frame.
!   vpec        Sun's peculiar velocity vector (array of size 3) [km/s],
!               defined relative to local standard of rest.
!   vsun        Sun's velocity vector (array of size 3) [km/s], defined
!               relative to galactic rest frame.
! Optional output arguments regarding dark matter density:
!   rho         Local dark matter density [GeV/cm^3].
! Optional output arguments regarding SHM distribution, a truncated
! Maxwell-Boltzmann ("MB"):
!   vbulk       Bulk velocity of dark matter (array of size 3) [km/s],
!               defined relative to galactic rest frame.
!   vobs        Observer/detector's speed (i.e. Sun's speed) [km/s],
!               defined relative to MB rest frame.
!   v0          Most probable speed [km/s] in the MB rest frame.
!   vesc        Galactic/population escape speed [km/s] in the MB rest
!               frame (_galactic_ escape speed only if MB has no bulk
!               motion relative to galactic rest frame).
! Optional output arguments regarding tabulated eta(vmin):
!   tabulated   Indicates if a tabulated eta(vmin) is being used
!   eta_file    The file tabulated eta were taken from
!   Nvmin       Number of tabulation points
!   vmin        Allocatable array of vmin [km/s]
!   eta         Allocatable array of mean inverse speeds at vmin [s/km]
! 
SUBROUTINE GetHalo(Halo,vrot,vlsr,vpec,vsun,rho,vbulk,vobs,v0,vesc,    &
                   tabulated,eta_file,Nvmin,vmin,eta)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  CHARACTER(LEN=*), INTENT(OUT), OPTIONAL :: eta_file
  LOGICAL, INTENT(OUT), OPTIONAL :: tabulated
  INTEGER, INTENT(OUT), OPTIONAL :: Nvmin
  REAL*8, INTENT(OUT), OPTIONAL :: vrot,vlsr(3),vpec(3),vsun(3),       &
                                   rho,vbulk(3),vobs,v0,vesc
  REAL*8, ALLOCATABLE, INTENT(OUT), OPTIONAL :: vmin(:),eta(:)
  
  IF (PRESENT(vrot))  vrot  = Halo%vrot
  IF (PRESENT(vlsr))  vlsr  = Halo%vlsr
  IF (PRESENT(vpec))  vpec  = Halo%vpec
  IF (PRESENT(vsun))  vsun  = Halo%vsun
  
  IF (PRESENT(rho))   rho   = Halo%rho
  
  IF (PRESENT(vbulk)) vbulk = Halo%vbulk
  IF (PRESENT(vobs))  vobs  = Halo%vobs
  IF (PRESENT(v0))    v0    = Halo%v0
  IF (PRESENT(vesc))  vesc  = Halo%vesc
  
  IF (PRESENT(tabulated)) tabulated = Halo%tabulated
  IF (PRESENT(eta_file)) eta_file = Halo%eta_file
  IF (PRESENT(Nvmin)) Nvmin = Halo%Nvmin
  IF (PRESENT(vmin)) THEN
    ALLOCATE(vmin(Halo%Nvmin))
    vmin = Halo%vmin
  END IF
  IF (PRESENT(eta)) THEN
    ALLOCATE(eta(Halo%Nvmin))
    eta = Halo%eta
  END IF
END SUBROUTINE


! ----------------------------------------------------------------------
! Set various halo quantities.
! 
! Optional input arguments regarding galactic motions:
!   vrot        Local galactic disk rotation speed [km/s].
!   vlsr        Local standard of rest velocity vector (array of size 3)
!               [km/s], defined relative to galactic rest frame.
!   vpec        Sun's peculiar velocity vector (array of size 3) [km/s],
!               defined relative to local standard of rest.
!   vsun        Sun's velocity vector (array of size 3) [km/s], defined
!               relative to galactic rest frame.
! Optional input arguments regarding dark matter density:
!   rho         Local dark matter density [GeV/cm^3].
! Optional input arguments regarding SHM distribution, a truncated
! Maxwell-Boltzmann ("MB"):
!   vbulk       Bulk velocity of dark matter (array of size 3) [km/s],
!               defined relative to galactic rest frame.
!   vobs        Observer/detector's speed (i.e. Sun's speed) [km/s],
!               defined relative to MB rest frame.
!   v0          Most probable speed [km/s] in the MB rest frame.
!   vesc        Galactic/population escape speed [km/s] in the MB rest
!               frame (_galactic_ escape speed only if MB has no bulk
!               motion relative to galactic rest frame).
! Optional tabulated eta(vmin) arguments.  Can be loaded from a given
! file or explicitly provided.  If provided, Nvmin, vmin, and eta must
! all be given to take effect.  When a tabulation is not provided, the
! mean inverse speed will be calculated explicitly (not tabulated!)
! using the SHM as described by the above parameters.
!   tabulated   Indicates if a tabulated eta(vmin) is to be used.  Implied
!               by the use of other tabulation arguments, but can be set
!               false to return to the SHM calculation after a tabulation
!               has been loaded.
!   eta_file    File from which tabulated eta(vmin) should be read;
!               default is to perform explicit calculations for the SHM
!               describe The file tabulated eta were taken from
!   eta_filename Sets the stored file name _without_ loading any data
!               from the file.
!   eta_file_K  The column number in the file to take eta from (default
!               is second)
!   Nvmin       Number of tabulation points
!   vmin        Array of size [1:Nvmin] containing tabulation vmin [km/s]
!   eta         Array of size [1:Nvmin] containing tabulated mean inverse
!               speeds at vmin [s/km]
! 
SUBROUTINE SetHalo(Halo,vrot,vlsr,vpec,vsun,vobs,rho,vbulk,v0,vesc, &
            tabulated,eta_file,eta_filename,eta_file_K,Nvmin,vmin,eta)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(INOUT) :: Halo
  CHARACTER(LEN=*), INTENT(IN), OPTIONAL :: eta_file,eta_filename
  LOGICAL, INTENT(IN), OPTIONAL :: tabulated
  INTEGER, INTENT(IN), OPTIONAL :: eta_file_K,Nvmin
  REAL*8, INTENT(IN), OPTIONAL :: vrot,vlsr(3),vpec(3),vsun(3),         &
                                  rho,vbulk(3),vobs,v0,vesc
  REAL*8, INTENT(IN), OPTIONAL :: vmin(:),eta(:)
  INTEGER :: K
  
  IF (PRESENT(vrot))  CALL SetDiskRotationSpeed(vrot,Halo)
  IF (PRESENT(vlsr))  CALL SetLocalStandardOfRest(vlsr,Halo)
  IF (PRESENT(vpec))  CALL SetSunPeculiarVelocity(vpec,Halo)
  IF (PRESENT(vsun))  CALL SetSunVelocity(vsun,Halo)
  
  IF (PRESENT(rho))   CALL SetLocalDensity(rho,Halo)
  
  IF (PRESENT(vbulk)) CALL SetBulkVelocity(vbulk,Halo)
  IF (PRESENT(vobs))  CALL SetObserverSpeed(vobs,Halo)
  IF (PRESENT(v0))    CALL SetMostProbableSpeed(v0,Halo)
  IF (PRESENT(vesc))  CALL SetEscapeSpeed(vesc,Halo)
  
  IF (PRESENT(tabulated)) THEN
    IF (Halo%Nvmin .GT. 0) Halo%tabulated = tabulated
  END IF
  IF (PRESENT(Nvmin) .AND. PRESENT(vmin) .AND. PRESENT(eta)) THEN
    IF (Nvmin .GT. 0) THEN
      IF (ALLOCATED(Halo%vmin)) DEALLOCATE(Halo%vmin)
      IF (ALLOCATED(Halo%eta))  DEALLOCATE(Halo%eta)
      Halo%Nvmin = Nvmin
      Halo%vmin  = vmin
      Halo%eta   = eta
      Halo%tabulated = .TRUE.
      Halo%eta_file  = ''
    END IF
  END IF
  IF (PRESENT(eta_file)) THEN
    IF (PRESENT(eta_file_K)) THEN
      K = eta_file_K
    ELSE
      K = 2
    END IF
    CALL LoadArrays(file=eta_file,N=Halo%Nvmin,N1=1,C1=Halo%vmin,       &
                    N2=K,C2=Halo%eta)
    Halo%tabulated = .TRUE.
    Halo%eta_file  = eta_file
  END IF
  
  IF (PRESENT(eta_filename)) Halo%eta_file = eta_filename
  
END SUBROUTINE


!-----------------------------------------------------------------------
! Initializes halo.
! Simply sets halo parameters to default values.
! 
FUNCTION InitHalo() RESULT(Halo)

  IMPLICIT NONE
  TYPE(HaloStruct) :: Halo
  
  Halo%vrot  = 235d0
  Halo%vlsr  = (/ 0d0, 235d0, 0d0 /)
  Halo%vpec  = (/ 11d0, 12d0, 7d0 /)
  Halo%vsun  = (/ 0d0, 235d0, 0d0 /) + (/ 11d0, 12d0, 7d0 /)
  
  Halo%rho   = 0.4d0
  
  Halo%vbulk = (/ 0d0, 0d0, 0d0 /)
  Halo%vobs  = SQRT(11d0**2 + (235d0+12d0)**2 + 7d0**2)
  Halo%v0    = 235d0
  Halo%vesc  = 550d0
  
  Halo%tabulated = .FALSE.
  Halo%eta_file  = ''
  Halo%Nvmin = 0
  IF (ALLOCATED(Halo%vmin)) DEALLOCATE(Halo%vmin)
  IF (ALLOCATED(Halo%eta))  DEALLOCATE(Halo%eta)
  
END FUNCTION

!-----------------------------------------------------------------------
! C/C++ wrapper for InitHalo.
!
INTEGER(KIND=C_INT) FUNCTION C_DDCalc_InitHalo() &
 BIND(C,NAME='C_DDHalo_ddcalc_inithalo') 
  USE ISO_C_BINDING, only: C_INT
  IMPLICIT NONE
  N_Halos = N_Halos + 1
  IF (N_Halos .GT. Max_Halos) stop 'DDCalc: Max_Halos exceeded.&
   Please run FreeHalos or modify Max_Halos in DDTypes.f90.'
  ALLOCATE(Halos(N_Halos)%p)
  Halos(N_Halos)%p = InitHalo()
  C_DDCalc_InitHalo = N_Halos
END FUNCTION


!-----------------------------------------------------------------------
! Initializes halo from command-line parameters.
! 
! Possible options regarding galactic motions:
!   --vrot=<value>       ! Local galactic disk rotation speed [km/s].
!   --vlsr=<x>,<y>,<z>   ! Local standard of rest velocity vector (array of size 3)
!                        ! [km/s], defined relative to galactic rest frame.
!   --vpec=<x>,<y>,<z>   ! Sun's peculiar velocity vector (array of size 3) [km/s],
!                        ! defined relative to local standard of rest.
!   --vsun=<x>,<y>,<z>   ! Sun's velocity vector (array of size 3) [km/s], defined
!                        ! relative to galactic rest frame.
! Possible options regarding dark matter density:
!   --rho=<value>        ! Local dark matter density [GeV/cm^3]
! Possible options regarding SHM distribution:
!   --vbulk=<x>,<y>,<z>  ! Bulk velocity of dark matter (array of size 3) [km/s],
!                        ! defined relative to galactic rest frame.
!   --vobs=<value>       ! Observer/detector's speed (i.e. Sun's speed) [km/s],
!                        ! defined relative to MB rest frame.
!   --v0=<value>         ! Most probable speed [km/s] in the galactic rest frame.
!   --vesc=<value>       ! Escape speed of the dark matter population [km/s] in
!                        ! its rest frame.
! Possible options for provided a tabulated eta(vmin) instead of using the above
! SHM distribution.
!   --eta-file=<file>    ! File from which tabulated mean inverse speed eta(vmin)
!                        ! should be read.  First column is vmin [km/s] and second
!                        ! column is eta [s/km].  Default behavior is to do explicit
!                        ! calculations for SHM.
!   --eta-file=<file>,<K>! Same as above, but take the Kth column for eta.
! 
FUNCTION InitHaloCommandLine() RESULT(Halo)

  IMPLICIT NONE
  TYPE(HaloStruct) :: Halo
  CHARACTER(LEN=1024) :: eta_file
  INTEGER :: I,K,Nval,ios
  REAL*8 :: vrot,vobs,rho,v0,vesc
  REAL*8, ALLOCATABLE :: vlsr(:),vpec(:),vsun(:),vbulk(:)
  ! Older compiler compatibility
  INTEGER, PARAMETER :: NCHAR = 1024
  CHARACTER(LEN=NCHAR), DIMENSION(:), ALLOCATABLE :: aval
  ! ...but this would be better better (needs gfortran 4.6+)
  !CHARACTER(LEN=:), DIMENSION(:), ALLOCATABLE :: aval
  
  Halo = InitHalo()
  
  IF (GetLongArgReal('vrot',vrot)) CALL SetDiskRotationSpeed(vrot,Halo)
  IF (GetLongArgReals('vlsr',vlsr,I)) THEN
    IF (I .EQ. 3) THEN
      CALL SetLocalStandardOfRest(vlsr,Halo)
    ELSE
      WRITE(0,*) 'ERROR: Invalid --vlsr=<vx>,<vy>,<vz> parameter.'
      STOP
    END IF
  END IF
  IF (GetLongArgReals('vpec',vpec,I)) THEN
    IF (I .EQ. 3) THEN
      CALL SetSunPeculiarVelocity(vpec,Halo)
    ELSE
      WRITE(0,*) 'ERROR: Invalid --vpec=<vx>,<vy>,<vz> parameter.'
      STOP
    END IF
  END IF
  IF (GetLongArgReals('vsun',vsun,I)) THEN
    IF (I .EQ. 3) THEN
      CALL SetSunVelocity(vsun,Halo)
    ELSE
      WRITE(0,*) 'ERROR: Invalid --vsun=<vx>,<vy>,<vz> parameter.'
      STOP
    END IF
  END IF
  
  IF (GetLongArgReal('rho',rho))   CALL SetLocalDensity(rho,Halo)
  
  IF (GetLongArgReals('vbulk',vbulk,I)) THEN
    IF (I .EQ. 3) THEN
      CALL SetBulkVelocity(vbulk,Halo)
    ELSE
      WRITE(0,*) 'ERROR: Invalid --vbulk=<vx>,<vy>,<vz> parameter.'
      STOP
    END IF
  END IF
  IF (GetLongArgReal('vobs',vobs)) CALL SetObserverSpeed(vobs,Halo)
  IF (GetLongArgReal('v0',v0))     CALL SetMostProbableSpeed(v0,Halo)
  IF (GetLongArgReal('vesc',vesc)) CALL SetEscapeSpeed(vesc,Halo)
  
  !IF (GetLongArgString('eta-file',eta_file)) CALL SetHalo(Halo,eta_file=eta_file)
  IF (GetLongArgStrings('eta-file',NCHAR,aval,Nval)) THEN
    IF (Nval .GE. 2) THEN
      READ(aval(2),*,IOSTAT=ios) K
      IF (ios .NE. 0) K = 2
    ELSE
      K = 2
    END IF
    CALL SetHalo(Halo,eta_file=aval(1),eta_file_K=K)
  END IF
  
END FUNCTION


! ----------------------------------------------------------------------
! Get/set local galactic disk rotation speed [km/s].
! Modifies the Local Standard of Rest (LSR) and Sun's velocity relative
! to halo rest frame as well as the most probable speed of the velocity
! distribution (v0 = vrot).  The observer speed is updated.
! 
PURE FUNCTION GetDiskRotationSpeed(Halo) RESULT(vrot)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  REAL*8 :: vrot
  vrot = Halo%vrot
END FUNCTION

SUBROUTINE SetDiskRotationSpeed(vrot,Halo)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(INOUT) :: Halo
  REAL*8, INTENT(IN) :: vrot
  Halo%vrot = vrot
  Halo%vlsr = (/ 0d0, Halo%vrot, 0d0 /)
  Halo%vsun = Halo%vlsr + Halo%vpec
  Halo%vobs = SQRT(SUM((Halo%vsun - Halo%vbulk)**2))
  Halo%v0   = Halo%vrot
END SUBROUTINE


! ----------------------------------------------------------------------
! Get/set Local Standard Of Rest velocity vector [km/s], defined
! relative to galactic rest frame.  Usually assumed to be (0,vrot,0),
! where vrot is disk rotation speed.  Modifies Sun's velocity relative
! to halo rest frame.  The disk rotation speed and the most probable
! speed of the velocity distribution are set to the y component of this
! velocity vector.  The observer speed is updated.
! 
PURE FUNCTION GetLocalStandardOfRest(Halo) RESULT(vlsr)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  REAL*8 :: vlsr(3)
  vlsr = Halo%vlsr
END FUNCTION

SUBROUTINE SetLocalStandardOfRest(vlsr,Halo)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(INOUT) :: Halo
  REAL*8, INTENT(IN) :: vlsr(3)
  Halo%vlsr = vlsr
  Halo%vsun = Halo%vlsr + Halo%vpec
  Halo%vrot = vlsr(2)
  Halo%vobs = SQRT(SUM((Halo%vsun - Halo%vbulk)**2))
  Halo%v0   = ABS(Halo%vrot)
END SUBROUTINE


! ----------------------------------------------------------------------
! Get/set Sun's peculiar velocity vector [km/s], defined relative to
! local standard of rest.  Modifies Sun's velocity relative to halo
! rest frame.  The observer speed is updated.
! 
PURE FUNCTION GetSunPeculiarVelocity(Halo) RESULT(vpec)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  REAL*8 :: vpec(3)
  vpec = Halo%vpec
END FUNCTION

SUBROUTINE SetSunPeculiarVelocity(vpec,Halo)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(INOUT) :: Halo
  REAL*8, INTENT(IN) :: vpec(3)
  Halo%vpec = vpec
  Halo%vsun = Halo%vlsr + Halo%vpec
  Halo%vobs = SQRT(SUM((Halo%vsun - Halo%vbulk)**2))
END SUBROUTINE


! ----------------------------------------------------------------------
! Get/set Sun's velocity vector [km/s], defined relative to galactic
! rest frame.  Normally taken to be vlsr + vpec, i.e. the sum of the
! local standard of rest and the Sun's peculiar velocity.  The preferred
! way to set speeds is modifying the disk rotation speed or Sun's
! peculiar velocity, not by setting this velocity directly, as the
! contributing velocities become ill-defined.  If the Sun's velocity is
! set here, the routine will attempt to assign a rotation speed vrot
! and local standard of rest vlsr = (0,vrot,0) that matches the given
! velocity vector, using the current value of the peculiar velocity; if
! not possible, the peculiar motion is set to zero first.  The most
! probable speed of the velocity distribution is updated to the
! resulting vrot and the observer speed is updated.
! 
PURE FUNCTION GetSunVelocity(Halo) RESULT(vsun)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  REAL*8 :: vsun(3)
  vsun = Halo%vsun
END FUNCTION

SUBROUTINE SetSunVelocity(vsun,Halo)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(INOUT) :: Halo
  REAL*8, INTENT(IN) :: vsun(3)
  REAL*8 :: vrot2
  Halo%vsun = vsun
  vrot2 = SUM((Halo%vsun - Halo%vpec)**2)
  IF (vrot2 .GE. 0d0) THEN
    Halo%vrot = SQRT(vrot2)
    Halo%vlsr = (/ 0d0, Halo%vrot, 0d0 /)
  ELSE
    Halo%vpec = 0d0
    Halo%vrot = SQRT(SUM(Halo%vsun**2))
    Halo%vlsr = (/ 0d0, Halo%vrot, 0d0 /)
  END IF
  Halo%v0 = ABS(Halo%vrot)
  Halo%vobs = SQRT(SUM((Halo%vsun - Halo%vbulk)**2))
END SUBROUTINE


! ----------------------------------------------------------------------
! Get/set local halo density [GeV/cm^3].
! 
PURE FUNCTION GetLocalDensity(Halo) RESULT(rho)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  REAL*8 :: rho
  rho = Halo%rho
END FUNCTION

SUBROUTINE SetLocalDensity(rho,Halo)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(INOUT) :: Halo
  REAL*8, INTENT(IN) :: rho
  Halo%rho = MAX(rho,0d0)
END SUBROUTINE


! ----------------------------------------------------------------------
! Get/set the dark matter population's bulk velocity vector [km/s],
! defined relative to the galactic rest frame.  Modifies the observer
! speed.
! 
PURE FUNCTION GetBulkVelocity(Halo) RESULT(vbulk)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  REAL*8 :: vbulk(3)
  vbulk = Halo%vbulk
END FUNCTION

SUBROUTINE SetBulkVelocity(vbulk,Halo)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(INOUT) :: Halo
  REAL*8, INTENT(IN) :: vbulk(3)
  Halo%vbulk = vbulk
  Halo%vobs = SQRT(SUM((Halo%vsun - Halo%vbulk)**2))
END SUBROUTINE


! ----------------------------------------------------------------------
! Get/set observer/detector's speed (i.e. Sun's speed) [km/s], defined
! relative to Maxwell-Boltzmann population rest frame.  Normally taken
! to be |vlsr + vpec - vMB|, i.e. the sum of the local standard of rest
! and the Sun's peculiar velocity less the bulk velocity of the dark
! matter population.  The preferred way to set speeds is modifying the
! disk rotation speed, Sun's peculiar velocity, or the bulk dark matter
! motion, not by setting this speed directly, as the various
! velocities become ill-defined.  If the observer's speed is set here,
! the routine will set the bulk motion of the DM to zero (relative to
! the galactic rest frame) and attempt to assign a rotation speed vrot
! and local standard of rest vlsr = (0,vrot,0) that matches the given
! speed, using the current value of the peculiar velocity; if not
! possible, the peculiar motion is set to zero first.  The most
! probable speed of the velocity distribution is updated to the
! resulting vrot.
! 
PURE FUNCTION GetObserverSpeed(Halo) RESULT(vobs)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  REAL*8 :: vobs
  vobs = Halo%vobs
END FUNCTION

SUBROUTINE SetObserverSpeed(vobs,Halo)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(INOUT) :: Halo
  REAL*8, INTENT(IN) :: vobs
  REAL*8 :: vy2
  Halo%vobs  = MAX(vobs,0d0)
  Halo%vbulk = (/ 0d0, 0d0, 0d0 /)
  vy2 = Halo%vobs**2 - Halo%vpec(1)**2 - Halo%vpec(3)**2
  IF (vy2 .GE. 0d0) THEN
    Halo%vrot = SQRT(vy2) - Halo%vpec(2)
    Halo%vlsr = (/ 0d0, Halo%vrot, 0d0 /)
    Halo%vsun = Halo%vlsr + Halo%vpec
  ELSE
    Halo%vpec = 0d0
    Halo%vrot = Halo%vobs
    Halo%vlsr = (/ 0d0, Halo%vrot, 0d0 /)
    Halo%vsun = Halo%vlsr + Halo%vpec
  END IF
  Halo%v0 = ABS(Halo%vrot)
END SUBROUTINE


! ----------------------------------------------------------------------
! Get/set most probable speed v0 [km/s] in the dark matter population's
! rest frame. Related to other speeds characterizing velocity
! distribution by:
!     vrms = sqrt(3/2) v0    [rms velocity]
!     vmp  = v0              [most probably velocity]
!     vave = sqrt(4/pi) v0   [mean velocity]
! 
PURE FUNCTION GetMostProbableSpeed(Halo) RESULT(v0)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  REAL*8 :: v0
  v0 = Halo%v0
END FUNCTION

SUBROUTINE SetMostProbableSpeed(v0,Halo)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(INOUT) :: Halo
  REAL*8, INTENT(IN) :: v0
  Halo%v0 = v0
END SUBROUTINE


! ----------------------------------------------------------------------
! Get/set dark matter population escape speed [km/s].  In the case of
! the SHM with no bulk motion relative to the galactic rest frame, this
! is the galactic escape speed.
! 
PURE FUNCTION GetEscapeSpeed(Halo) RESULT(vesc)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  REAL*8 :: vesc
  vesc = Halo%vesc
END FUNCTION

SUBROUTINE SetEscapeSpeed(vesc,Halo)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(INOUT) :: Halo
  REAL*8, INTENT(IN) :: vesc
  Halo%vesc = MAX(vesc,0d0)
END SUBROUTINE


! ----------------------------------------------------------------------
! INTERFACE NAME: EToVmin
! Calculate the minimum velocity for producing a recoil of energy E,
! given by vmin = sqrt{M E/(2\mu^2)} [km/s].
! 
! This is the scalar version (single mass and energy).
! 
! Input arguments:
!   E           Recoil energy [keV]
!   m           WIMP mass [GeV]
!   Miso        Isotope mass [GeV]
! 
ELEMENTAL FUNCTION EToVmin0(E,m,Miso) RESULT(vmin)
  IMPLICIT NONE
  REAL*8 :: vmin
  REAL*8, INTENT(IN) :: E,m,Miso
  REAL*8 :: mu
  REAL*8, PARAMETER :: c = 1d-3*SPEED_OF_LIGHT  ! Speed of light in km/s
  mu = Miso*m / (Miso + m)
  vmin = c * SQRT(1d-6*Miso*E/(2*mu**2))
END FUNCTION


! ----------------------------------------------------------------------
! INTERFACE NAME: EToVmin
! Calculate the minimum velocity for producing a recoil of energy E,
! given by vmin = sqrt{M E/(2\mu^2)} [km/s].  Returns as array of
! size [1:N].
! 
! This is the 1D array version (single mass and array of energies).
! 
! Input arguments:
!   N           Number of recoil energies
!   E           Array of recoil energies [keV]
!   m           WIMP mass [GeV]
!   Miso        Isotope mass [GeV]
! 
PURE FUNCTION EToVmin1(N,E,m,Miso) RESULT(vmin)
  IMPLICIT NONE
  REAL*8 :: vmin(N)
  INTEGER, INTENT(IN) :: N
  REAL*8, INTENT(IN) :: E(N),m,Miso
  REAL*8 :: mu
  REAL*8, PARAMETER :: c = 1d-3*SPEED_OF_LIGHT  ! Speed of light in km/s
  mu = Miso*m / (Miso + m)
  vmin = c * SQRT(1d-6*Miso*E/(2*mu**2))
END FUNCTION


! ----------------------------------------------------------------------
! INTERFACE NAME: EToVmin
! Calculate the minimum velocity for producing a recoil of energy E,
! given by vmin = sqrt{M E/(2\mu^2)} [km/s].  Returns as array of
! size [1:N,1:Niso].
! 
! This is the 2D array version (multiple masses and array of energies).
! 
! Input arguments:
!   N           Number of recoil energies
!   E           Array of recoil energies [keV]
!   m           WIMP mass [GeV]
!   Niso        Number of isotopes
!   Miso        Array of isotope masses [GeV]
! 
PURE FUNCTION EToVmin2(N,E,m,Niso,Miso) RESULT(vmin)
  IMPLICIT NONE
  REAL*8 :: vmin(N,Niso)
  INTEGER, INTENT(IN) :: N,Niso
  REAL*8, INTENT(IN) :: E(N),m,Miso(Niso)
  INTEGER :: I
  REAL*8 :: mu(Niso)
  REAL*8, PARAMETER :: c = 1d-3*SPEED_OF_LIGHT  ! Speed of light in km/s
  mu = Miso*m / (Miso + m)
  DO I = 1,Niso
    vmin(:,I) = c * SQRT(1d-6*Miso(I)*E/(2*mu(I)**2))
  END DO
END FUNCTION


!-----------------------------------------------------------------------
! INTERFACE NAME: MeanInverseSpeed
! Calculates the mean inverse speed (eta) [s/km] for the given vmin,
! with eta define as:
!     eta(vmin) = \int_{|v|>vmin} d^3v 1/|v| f(v)
! 
! This is the scalar version (single vmin).
! 
! Input arguments:
!   vmin        The minimum speed in the eta integral [km/s]
! 
ELEMENTAL FUNCTION MeanInverseSpeed0(vmin,Halo) RESULT(eta)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  REAL*8 :: eta
  REAL*8, INTENT(IN) :: vmin
  REAL*8 :: v0,vobs,vesc,x,y,z,Nesc
  
  ! If have tabulation, use it
  IF (Halo%tabulated) THEN
    eta = MeanInverseSpeedT(vmin,Halo)
    RETURN
  END IF
  
  ! Easier to use variable names
  v0   = Halo%v0
  vobs = Halo%vobs
  vesc = Halo%vesc
  
  ! Special case: no dispersion
  ! Distribution is delta function
  IF (v0 .EQ. 0) THEN
    IF (vobs .EQ. 0d0) THEN
      eta = 0d0
    ELSE
      IF (vmin .LE. vobs) THEN
        eta = 1d0 / vobs
      ELSE
        eta = 0d0
      END IF
    END IF
    RETURN
  END IF
  
  x    = vmin / v0
  y    = vobs / v0
  z    = vesc / v0
  Nesc = ERF(z) - 2*INVSQRTPI*z*EXP(-z**2)
  
  ! Special case: no relative motion by observer
  !   eta = 2/(sqrt(pi) Nesc v0) [e^{-x^2} - e^{-z^2}]
  ! Note: EXP2(a,b) = e^b - e^a
  IF (y .EQ. 0d0) THEN
    IF (x .LE. z) THEN
      eta = 2*INVSQRTPI/(Nesc*v0) * EXP2(-z**2,-x**2)
    ELSE
      eta = 0d0
    END IF
    RETURN
  END IF
  
  ! Special case: no finite cutoff (vesc is effectively infinite)
  IF (z .GT. 25d0) THEN
    eta = ERF2(x-y,x+y) / (2*vobs)
    RETURN
  END IF
  
  ! General case.
  ! See e.g. Savage, Freese & Gondolo, PRD 74, 043531 (2006)
  ! [astrop-ph/0607121]; use arxiv version as PRD version has type-
  ! setting issues in the formula.
  ! Note: ERF2(a,b) = ERF(b) - ERF(a)
  IF (x .LE. ABS(y-z)) THEN
    IF (y .LT. z) THEN
      eta = 1d0 / (2*Nesc*vobs) * (ERF2(x-y,x+y) - 4*INVSQRTPI*y*EXP(-z**2))
    ELSE
      eta = 1d0 / vobs
    END IF
  ELSE IF (x .LE. y+z) THEN
    eta = 1d0 / (2*Nesc*vobs) * (ERF2(x-y,z) - 2*INVSQRTPI*(z+y-x)*EXP(-z**2))
  ELSE
    eta = 0d0
  END IF
  
END FUNCTION


!-----------------------------------------------------------------------
! INTERFACE NAME: MeanInverseSpeed
! Calculates the mean inverse speed (eta) [s/km] for the given 1D
! array of vmin, with eta define as:
!     eta(vmin) = \int_{|v|>vmin} d^3v 1/|v| f(v)
! Returns as array of size [1:N].
! 
! This is the 1D array version (1D array of vmin).
! 
! Input arguments:
!   N           Number of vmin
!   vmin        The minimum speed in the eta integral [km/s].
!               Array of size [1:N].
! 
PURE FUNCTION MeanInverseSpeed1(N,vmin,Halo) RESULT(eta)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  REAL*8 :: eta(N)
  INTEGER, INTENT(IN) :: N
  REAL*8, INTENT(IN) :: vmin(N)
  REAL*8 :: v0,vobs,vesc,x(N),y,z,Nesc
  
  ! If have tabulation, use it
  IF (Halo%tabulated) THEN
    eta = MeanInverseSpeedT(vmin,Halo)
    RETURN
  END IF
  
  ! Easier to use variable names
  v0   = Halo%v0
  vobs = Halo%vobs
  vesc = Halo%vesc
  
  ! Special case: no dispersion
  ! Distribution is delta function
  IF (v0 .EQ. 0) THEN
    IF (vobs .EQ. 0d0) THEN
      eta = 0d0
    ELSE
      WHERE (vmin .LE. vobs)
        eta = 1d0 / vobs
      ELSE WHERE
        eta = 0d0
      END WHERE
    END IF
    RETURN
  END IF
  
  x    = vmin / v0
  y    = vobs / v0
  z    = vesc / v0
  Nesc = ERF(z) - 2*INVSQRTPI*z*EXP(-z**2)
  
  ! Special case: no relative motion by observer
  !   eta = 2/(sqrt(pi) Nesc v0) [e^{-x^2} - e^{-z^2}]
  ! Note: EXP2(a,b) = e^b - e^a
  IF (y .EQ. 0d0) THEN
    WHERE (x .LE. z)
      eta = 2*INVSQRTPI/(Nesc*v0) * EXP2(-z**2,-x**2)
    ELSE WHERE
      eta = 0d0
    END WHERE
    RETURN
  END IF
  
  ! Special case: no finite cutoff (vesc is effectively infinite)
  IF (z .GT. 25d0) THEN
    eta = ERF2(x-y,x+y) / (2*vobs)
    RETURN
  END IF
  
  ! General case.
  ! See e.g. Savage, Freese & Gondolo, PRD 74, 043531 (2006)
  ! [astrop-ph/0607121]; use arxiv version as PRD version has type-
  ! setting issues in the formula.
  ! Note: ERF2(a,b) = ERF(b) - ERF(a)
  ! Separate y < z & y > z cases to make easier use of WHERE statements.
  IF (y .LT. z) THEN
    WHERE (x .LT. z-y)
      eta = 1d0 / (2*Nesc*vobs) * (ERF2(x-y,x+y) - 4*INVSQRTPI*y*EXP(-z**2))
    ELSE WHERE (x .LT. z+y)
      eta = 1d0 / (2*Nesc*vobs) * (ERF2(x-y,z) - 2*INVSQRTPI*(z+y-x)*EXP(-z**2))
    ELSE WHERE
      eta = 0d0
    END WHERE
  ELSE
    WHERE (x .LT. y-z)
      eta = 1d0 / vobs
    ELSE WHERE (x .LT. y+z)
      eta = 1d0 / (2*Nesc*vobs) * (ERF2(x-y,z) - 2*INVSQRTPI*(z+y-x)*EXP(-z**2))
    ELSE WHERE
      eta = 0d0
    END WHERE
  END IF
  
END FUNCTION


!-----------------------------------------------------------------------
! INTERFACE NAME: MeanInverseSpeed
! Calculates the mean inverse speed (eta) [s/km] for the given 2D
! array of vmin, with eta define as:
!     eta(vmin) = \int_{|v|>vmin} d^3v 1/|v| f(v)
! Returns as array of size [1:N1,1:N2].
! 
! This is the 2D array version (2D array of vmin).
! 
! Input arguments:
!   N1,N2       Size of vmin and eta arrays, i.e. [1:N1,1:N2]
!   vmin        The minimum speed in the eta integral [km/s].
!               Array of size [1:N].
! 
PURE FUNCTION MeanInverseSpeed2(N1,N2,vmin,Halo) RESULT(eta)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  REAL*8 :: eta(N1,N2)
  INTEGER, INTENT(IN) :: N1,N2
  REAL*8, INTENT(IN) :: vmin(N1,N2)
  REAL*8 :: v0,vobs,vesc,x(N1,N2),y,z,Nesc
  
  ! If have tabulation, use it
  IF (Halo%tabulated) THEN
    eta = MeanInverseSpeedT(vmin,Halo)
    RETURN
  END IF
  
  ! Easier to use variable names
  v0   = Halo%v0
  vobs = Halo%vobs
  vesc = Halo%vesc
  
  ! Special case: no dispersion
  ! Distribution is delta function
  IF (v0 .EQ. 0) THEN
    IF (vobs .EQ. 0d0) THEN
      eta = 0d0
    ELSE
      WHERE (vmin .LE. vobs)
        eta = 1d0 / vobs
      ELSE WHERE
        eta = 0d0
      END WHERE
    END IF
    RETURN
  END IF
  
  x    = vmin / v0
  y    = vobs / v0
  z    = vesc / v0
  Nesc = ERF(z) - 2*INVSQRTPI*z*EXP(-z**2)
  
  ! Special case: no relative motion by observer
  !   eta = 2/(sqrt(pi) Nesc v0) [e^{-x^2} - e^{-z^2}]
  ! Note: EXP2(a,b) = e^b - e^a
  IF (y .EQ. 0d0) THEN
    WHERE (x .LE. z)
      eta = 2*INVSQRTPI/(Nesc*v0) * EXP2(-z**2,-x**2)
    ELSE WHERE
      eta = 0d0
    END WHERE
    RETURN
  END IF
  
  ! Special case: no finite cutoff (vesc is effectively infinite)
  IF (z .GT. 25d0) THEN
    eta = ERF2(x-y,x+y) / (2*vobs)
    RETURN
  END IF
  
  ! General case.
  ! See e.g. Savage, Freese & Gondolo, PRD 74, 043531 (2006)
  ! [astrop-ph/0607121]; use arxiv version as PRD version has type-
  ! setting issues in the formula.
  ! Note: ERF2(a,b) = ERF(b) - ERF(a)
  ! Separate y < z & y > z cases to make easier use of WHERE statements.
  IF (y .LT. z) THEN
    WHERE (x .LT. z-y)
      eta = 1d0 / (2*Nesc*vobs) * (ERF2(x-y,x+y) - 4*INVSQRTPI*y*EXP(-z**2))
    ELSE WHERE (x .LT. z+y)
      eta = 1d0 / (2*Nesc*vobs) * (ERF2(x-y,z) - 2*INVSQRTPI*(z+y-x)*EXP(-z**2))
    ELSE WHERE
      eta = 0d0
    END WHERE
  ELSE
    WHERE (x .LT. y-z)
      eta = 1d0 / vobs
    ELSE WHERE (x .LT. y+z)
      eta = 1d0 / (2*Nesc*vobs) * (ERF2(x-y,z) - 2*INVSQRTPI*(z+y-x)*EXP(-z**2))
    ELSE WHERE
      eta = 0d0
    END WHERE
  END IF
  
END FUNCTION


!-----------------------------------------------------------------------
! Calculates the mean inverse speed (eta) [s/km] for the given vmin,
! with eta define as:
!     eta(vmin) = \int_{|v|>vmin} d^3v 1/|v| f(v)
! using the stored tabulation rather than the explicit calculation.
! 
! Input arguments:
!   vmin        The minimum speed in the eta integral [km/s]
! 
ELEMENTAL FUNCTION MeanInverseSpeedT(vmin,Halo) RESULT(eta)
  IMPLICIT NONE
  TYPE(HaloStruct), INTENT(IN) :: Halo
  REAL*8 :: eta
  REAL*8, INTENT(IN) :: vmin
  INTEGER :: K
  REAL*8 :: f
  
  IF (.NOT. Halo%tabulated .OR. (Halo%Nvmin .LE. 0)) THEN
    eta = 0d0
    RETURN
  END IF
  
  K = BSearch(Halo%Nvmin,Halo%vmin,vmin)
  
  IF (K .LE. 0) THEN
    eta = Halo%eta(1)
  ELSE IF (K .GE. Halo%Nvmin) THEN
    IF (vmin .EQ. Halo%vmin(Halo%Nvmin)) THEN
      eta = Halo%eta(Halo%Nvmin)
    ELSE
      eta = 0d0
    END IF
  ELSE IF (Halo%vmin(K) .EQ. Halo%vmin(K+1)) THEN
    eta = Halo%eta(K)
  ELSE
    f = (vmin-Halo%vmin(K)) / (Halo%vmin(K+1)-Halo%vmin(K))
    eta = (1-f)*Halo%eta(K) + f*Halo%eta(K+1)
  END IF
  
END FUNCTION


END MODULE
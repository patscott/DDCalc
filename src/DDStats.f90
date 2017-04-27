MODULE DDStats

!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
! DDStats
!    Routines to calculate the log-likelihood (Poisson with background)
!    or p-value (Poisson or Maximum Gap method, without background
!    subtraction) of the current result.  Must have called CalcRates()
!    for these routines to return appropriate values for the current
!    WIMP mass and couplings.
!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

USE DDNumerical
USE DDTypes

IMPLICIT NONE
PRIVATE

PUBLIC :: DDCalc_LogLikelihood,DDCalc_LogPValue,DDCalc_ScaleToPValue
PUBLIC :: C_DDCalc_LogLikelihood,C_DDCalc_LogPValue,C_DDCalc_ScaleToPValue
PUBLIC :: FeldmanCousinsPoissonCI

INTERFACE DDCalc_LogLikelihood
  MODULE PROCEDURE LogLikelihood
END INTERFACE
INTERFACE DDCalc_LogPValue
  MODULE PROCEDURE LogPValue
END INTERFACE
INTERFACE DDCalc_ScaleToPValue
  MODULE PROCEDURE ScaleToPValue
END INTERFACE

CONTAINS


! ----------------------------------------------------------------------
! Calculates the log-likelihood for the current WIMP mass and couplings.
! Uses a Poisson distribution in the number of observed events N:
!    P(N|s+b)
! where s is the average expected signal and b is the average expected
! background.
! 
! Optional input argument:
!   D           The DetectorStruct structure containing detector
!               and rate date to calculate the likelihood for.  If
!               not given, a default structure (internally stored)
!               will be used.
! 
FUNCTION LogLikelihood(D) RESULT(lnlike)
  IMPLICIT NONE
  REAL*8 :: lnlike
  TYPE(DetectorStruct), INTENT(IN) :: D
  INTEGER :: N
  REAL*8 :: b,s,mu
    
  ! Get observed events and expected events
  N = D%Nevents
  b = D%MuBackground
  s = D%MuSignal(0)

  IF (b .EQ. 0d0) THEN
    b = N - s
    IF (b .LT. 0) THEN
      b = 0
    END IF
  END IF

  mu = s + b
  
  ! Poisson likelihood (routine handles special cases)
  lnlike = PoissonLogPDF(N,mu)
  
END FUNCTION

!-----------------------------------------------------------------------
! C/C++ wrapper for DDCalc_LogLikelihood
!
REAL(KIND=C_DOUBLE) FUNCTION C_DDCalc_LogLikelihood(DetectorIndex) &
 BIND(C,NAME='C_DDStats_ddcalc_loglikelihood')
  USE ISO_C_BINDING, only: C_DOUBLE, C_INT
  IMPLICIT NONE
  INTEGER(KIND=C_INT), INTENT(IN) :: DetectorIndex
  IF (.NOT. ASSOCIATED(Detectors(DetectorIndex)%p)) stop 'Invalid detector index given to C_DDCalc_LogLikelihood'
  C_DDCalc_LogLikelihood = REAL(LogLikelihood(Detectors(DetectorIndex)%p),KIND=C_DOUBLE)
END FUNCTION


! ----------------------------------------------------------------------
! Calculates the log of the p-value for the current WIMP mass and
! couplings (NO BACKGROUND SUBTRACTION).  Uses the maximum gap method
! if efficiencies were provided in the efficiencies file for the
! intervals, otherwise uses a Poisson distribution in the number of
! observed events N:
!    P(N|s)
! where s is the average expected signal (background contributions are
! ignored).
! 
! Optional input argument:
!   D           The DetectorStruct structure containing detector
!               and rate date to calculate the p-value for.  If not
!               given, a default structure (internally stored) will
!               be used.
! 
FUNCTION LogPValue(D) RESULT(lnp)
  IMPLICIT NONE
  REAL*8 :: lnp
  TYPE(DetectorStruct), INTENT(IN) :: D
  INTEGER :: N,I
  REAL*8 :: s,mu
    
  ! Get observed events and expected events
  N  = D%Nevents
  mu = D%MuSignal(0)
  
  ! Check if rates are available for each interval
  IF (D%intervals .AND. (D%Neff .EQ. D%Nevents+1)) THEN
    lnp = LogMaximumGapP(mu,MAXVAL(D%MuSignal(1:N+1)))
  ELSE
    lnp = LogPoissonP(N,mu)
  END IF
  
END FUNCTION

!-----------------------------------------------------------------------
! C/C++ wrapper for DDCalc_LogPValue
!
REAL(KIND=C_DOUBLE) FUNCTION C_DDCalc_LogPValue(DetectorIndex) &
 BIND(C,NAME='C_DDStats_ddcalc_logpvalue')
  USE ISO_C_BINDING, only: C_DOUBLE, C_INT
  IMPLICIT NONE
  INTEGER(KIND=C_INT), INTENT(IN) :: DetectorIndex
  IF (.NOT. ASSOCIATED(Detectors(DetectorIndex)%p)) stop 'Invalid detector index given to C_DDCalc_LogPValue'
  C_DDCalc_LogPValue = REAL(LogPValue(Detectors(DetectorIndex)%p),KIND=C_DOUBLE)
END FUNCTION


! ----------------------------------------------------------------------
! Calculates the factor x by which the cross-sections must be scaled
! (sigma -> x*sigma) to achieve the desired p-value (given as log(p)).
! See LogPValue() above for a description of the statistics.
! 
! Optional input arguments:
!   D           The DetectorStruct structure containing detector
!               and rate date to calculate the scaling for.  If not
!               given, a default structure (internally stored) will
!               be used.
!   lnp         The logarithm of the desired p-value.  Default is
!               p=0.1 (90% CL).
! 
FUNCTION ScaleToPValue(D,lnp) RESULT(x)
  IMPLICIT NONE
  REAL*8 :: x
  TYPE(DetectorStruct), INTENT(IN) :: D
  REAL*8, INTENT(IN), OPTIONAL :: lnp
  INTEGER :: N
  REAL*8 :: lnp0,mu,f
  
  ! logarithm of p-value to use
  IF (PRESENT(lnp)) THEN
    lnp0 = lnp
  ELSE
    lnp0 = LOG(0.1d0)
  END IF
  
  ! Get observed events and expected events
  N  = D%Nevents
  mu = D%MuSignal(0)
  
  IF (mu .LE. 0d0) THEN
    x = HUGE(1d0)
    RETURN
  END IF
  
  IF (lnp0 .GE. 0d0) THEN
    x = 0d0
    RETURN
  END IF
  
  ! Use maximum gap if intervals available, otherwise Poisson
  IF (D%intervals .AND. (D%Neff .EQ. D%Nevents+1)) THEN
    f = MAXVAL(D%MuSignal(1:N+1)) / mu
    x = MaximumGapScaleToPValue(lnp0,mu,f)
  ELSE
    x = PoissonScaleToPValue(lnp0,N,mu)
  END IF
  
END FUNCTION

!-----------------------------------------------------------------------
! C/C++ wrapper for DDCalc_ScaleToPValue
!
REAL(KIND=C_DOUBLE) FUNCTION C_DDCalc_ScaleToPValue(DetectorIndex) &
 BIND(C,NAME='C_DDStats_ddcalc_scaletopvalue')
  USE ISO_C_BINDING, only: C_DOUBLE, C_INT
  IMPLICIT NONE
  INTEGER(KIND=C_INT), INTENT(IN) :: DetectorIndex
  IF (.NOT. ASSOCIATED(Detectors(DetectorIndex)%p)) stop 'Invalid detector index given to C_DDCalc_ScaleToPValue'
  C_DDCalc_ScaleToPValue = REAL(ScaleToPValue(Detectors(DetectorIndex)%p),KIND=C_DOUBLE)
END FUNCTION


! ----------------------------------------------------------------------
! Calculates the factor x by which the signal must be scaled (s -> x*s)
! to achieve the desired p-value (given as log(p)) using the maximum
! gap method.
! 
! NOTE: Uses quickly implemented numerical methods.  Could be much
!       better optimized if the need arises.
! 
! Input arguments:
!   lnp         The logarithm of the desired p-value.
!   mu          The total expected number of events.
!   f           The largest fraction of events expected in any interval
!               (i.e. the "maximum" gap).
! 
PURE FUNCTION MaximumGapScaleToPValue(lnp,mu,f) RESULT(x)
  IMPLICIT NONE
  REAL*8 :: x
  REAL*8, INTENT(IN) :: lnp,mu,f
  REAL*8 :: x1,lnp1,x2,lnp2,xm,lnpm
  
  IF (mu .LE. 0d0) THEN
    x = HUGE(1d0)
    RETURN
  END IF
  
  ! Should not happen...
  IF (lnp .GE. 0d0) THEN
    x = 0d0
    RETURN
  END IF
  
  ! Should not happen...
  IF (f .LE. 0d0) THEN
    x = HUGE(1d0)
    RETURN
  END IF
  
  ! Special case
  IF (f .GE. 1d0) THEN
    x = -lnp / mu
    RETURN
  END IF
  
  ! Starting point
  x1   = 1d0 / mu
  lnp1 = LogMaximumGapP(x1*mu,x1*f*mu)
  ! Bracket
  IF (lnp1 .GT. lnp) THEN
    x2   = 2d0*x1
    lnp2 = LogMaximumGapP(x2*mu,x2*f*mu)
    DO WHILE (lnp2 .GE. lnp)
      x1   = x2
      lnp1 = lnp2
      x2   = 2d0*x2
      lnp2 = LogMaximumGapP(x2*mu,x2*f*mu)
    END DO
  ELSE
    DO WHILE (lnp1 .LE. lnp)
      x2   = x1
      lnp2 = lnp1
      x1   = 0.5d0*x1
      lnp1 = LogMaximumGapP(x1*mu,x1*f*mu)
    END DO
  END IF
  
  ! Bisection (geometric)
  DO WHILE ((ABS(lnp2-lnp1) .GT. 1d-5) .AND. (ABS(LOG(x2/x1)) .GT. 1d-5))
    xm   = SQRT(x1*x2)
    lnpm = LogMaximumGapP(xm*mu,xm*f*mu)
    IF (lnpm .GE. lnp) THEN
      x1   = xm
      lnp1 = lnpm
    ELSE
      x2   = xm
      lnp2 = lnpm
    END IF
  END DO
  x = 0.5d0*(x1+x2)
  
END FUNCTION


! ----------------------------------------------------------------------
! Calculates the factor x by which the signal must be scaled (s -> x*s)
! to achieve the desired p-value (given as log(p)) using a Poisson
! distribution.
! 
! NOTE: Uses quickly implemented numerical methods.  Could be much
!       better optimized if the need arises.
! 
! Input arguments:
!   lnp         The logarithm of the desired p-value.
!   N           Number of observed events.
!   mu          The total expected number of events.
! 
PURE FUNCTION PoissonScaleToPValue(lnp,N,mu) RESULT(x)
  IMPLICIT NONE
  REAL*8 :: x
  INTEGER, INTENT(IN) :: N
  REAL*8, INTENT(IN) :: lnp,mu
  REAL*8 :: x1,lnp1,x2,lnp2,xm,lnpm
  
  IF (mu .LE. 0d0) THEN
    x = HUGE(1d0)
    RETURN
  END IF
  
  ! Should not happen...
  IF (lnp .GE. 0d0) THEN
    x = 0d0
    RETURN
  END IF
  
  ! Analytic formula for N=0
  IF (N .EQ. 0) THEN
    x = -lnp / mu
    RETURN
  END IF
  
  ! Starting point
  x1   = N / mu
  lnp1 = LogPoissonP(N,x1*mu)
  
  ! Bracket
  IF (lnp1 .GT. lnp) THEN
    x2   = 2d0*x1
    lnp2 = LogPoissonP(N,x2*mu)
    DO WHILE (lnp2 .GE. lnp)
      x1   = x2
      lnp1 = lnp2
      x2   = 2d0*x2
      lnp2 = LogPoissonP(N,x2*mu)
    END DO
  ELSE
    DO WHILE (lnp1 .LE. lnp)
      x2   = x1
      lnp2 = lnp1
      x1   = 0.5d0*x1
      lnp1 = LogPoissonP(N,x1*mu)
    END DO
  END IF
  
  ! Bisection (geometric)
  DO WHILE ((ABS(lnp2-lnp1) .GT. 1d-5) .AND. (ABS(x2-x1) .GT. 1d-5))
    xm   = SQRT(x1*x2)
    lnpm = LogPoissonP(N,xm*mu)
    IF (lnpm .GE. lnp) THEN
      x1   = xm
      lnp1 = lnpm
    ELSE
      x2   = xm
      lnp2 = lnpm
    END IF
  END DO
  x = 0.5d0*(x1+x2)
  
END FUNCTION


! ----------------------------------------------------------------------
! Calculates the confidence interval [s1,s2] for the signal
! contribution s in a Poisson distribution with background expectation
! b and observed events N.  Calculated at the CL corresponding to the
! given p-value (p = 1-CL).  Uses the Feldman-Cousins method as
! described in:
!    G. Feldman & R. Cousins, Phys. Rev. D 57, 3873 (1998) [physics/9711021]
! 
! Input arguments:
!   lnp         The logarithm of the p-value (CL = 1-p)
!   N           Number of observed events
!   b           Mean number of expected background events
! Output arguments:
!   s1,s2       The signal contribution confidence interval [s1,s2]
! 
PURE SUBROUTINE FeldmanCousinsPoissonCI(lnp,N,b,s1,s2)
  IMPLICIT NONE
  INTEGER, INTENT(IN) :: N
  REAL*8, INTENT(IN) :: lnp,b
  REAL*8, INTENT(OUT) :: s1,s2
  REAL*8 :: step,sa,sb,x,lnsum1,lnsum2
  ! Specifies the desired precision for boundary searches.
  ! This should not be smaller than EPSILON(1d0)!
  REAL*8, PARAMETER :: RELATIVE_PRECISION = 100*EPSILON(1d0)
  
  ! It is possible to get a measure zero confidence interval,
  ! though that is only possible if the CL is low (61% or lower,
  ! safely below the 1-sigma CL = 68.3%).  The measure zero
  ! interval will occur if the following is true:
  !   \Sum_{k=N+1}^{floor(b)} P(k|b) > 1-p = CL
  ! in which case the interval is [0,0].  The l.h.s. is bounded from
  ! above by Q(floor(b),b) - P(0|b), the sum for N=0 (Q is the
  ! regularized incomplete gamma function) which has a global
  ! maximum of 0.611 at b=4.0.  Other maxima occur at integer values
  ! of b, with maxima only slowly changing (goes to 0.5 as b becomes
  ! large).  Catch this case here:
  IF (lnp .GT. LOG(0.38d0)) THEN
    CALL LogPoissonSums(N,b,lnsum1,x)
    CALL LogPoissonSums(INT(b+EPSILON(1d0)),b,lnsum2,x)
    IF (EXP(lnsum2)-EXP(lnsum1) .GE. (1-EXP(lnp))) THEN
      s1 = 0d0
      s2 = 0d0
      RETURN
    END IF
  END IF
  
  ! Get lower boundary
  IF (accept(N,b,0d0,lnp)) THEN
    ! This should include b > N
    s1 = 0d0
  ELSE
    ! This _should_ be an accepted point
    s1 = N - b
    ! Take s1 -> s1/2 until s1 no longer accepted
    DO WHILE (accept(N,b,s1,lnp))
      s1 = 0.5d0*s1
    END DO
    step = s1
    ! Boundary is now between [s1,s1+step]
    DO WHILE (step .GE. RELATIVE_PRECISION*s1)
      step = 0.5d0*step
      IF (.NOT. accept(N,b,s1+step,lnp)) s1 = s1 + step
    END DO
  END IF
  
  ! Get upper boundary
  ! Need at least one good starting point
  IF (N .GT. b) THEN
    ! This _should_ be an accepted point
    s2 = N - b
  ELSE
    s2 = 1d0
    DO WHILE (.NOT. accept(N,b,s2,lnp))
      s2 = 0.5d0*s2
    END DO
  END IF
  ! Take s2 -> 2*s2 until s2 no longer accepted
  DO WHILE (accept(N,b,s2,lnp))
    s2 = 2*s2
  END DO
  step = s2
  ! Boundary is now between [s2-step,s2]
  DO WHILE (step .GE. RELATIVE_PRECISION*s2)
    step = 0.5d0*step
    IF (.NOT. accept(N,b,s2-step,lnp)) s2 = s2 - step
  END DO
  
  
  CONTAINS
  
  ! ------------------------------------------
  ! Determines if the given N is within the acceptance
  ! region for a Poisson of mean b+s with given CL=1-p.
  PURE FUNCTION accept(N,b,s,lnp)
    IMPLICIT NONE
    LOGICAL :: accept
    INTEGER, INTENT(IN) :: N
    REAL*8, INTENT(IN) :: b,s,lnp
    INTEGER :: Ktail,K1,K2
    REAL*8 :: x,lnP1,lnP2,lnR1,lnR2,lnPsum
    
    accept = .TRUE.
    
    ! Below, we are going to determine the probability outside
    ! some interval [K1,K2] (Psum) by starting with an interval
    ! of the form [0,K2] and working our way inward until the
    ! probability exceeds the p-value or N falls outside the
    ! interval.  Note this means we are adding terms in order of
    !  _increasing_ R (the Feldman-Cousins ordering parameter).
    
    ! To avoid ambiguity, terms of equal R are either accepted
    ! or rejected from the interval as one.  To avoid under-
    ! coverage, we accept such a group if necessary to ensure the
    ! interval covers at least 1-p, leading to (conservative)
    ! overcoverage.  There is a case (s=0) where the R has a
    ! plateau over a range of K that must be handled carefully.
    ! The only other possibility of equal R is by coincidence for
    ! two terms on opposite sides of the Poisson peak; this case
    ! is handled appropriately.
    
    ! Special case: s = 0 with N <= b
    ! For the s = 0 case, R=1 for all K <= b with R < 1 for
    ! K > b.  By our construction, that means that [0,floor(b)]
    ! is _always_ part of the accepted interval.  We catch this
    ! case here because the later algorithms will not handle
    ! it correctly (the N > b case is handled correctly below).
    IF ((s .EQ. 0d0) .AND. (N .LE. b)) THEN
      accept = .TRUE.
      RETURN
    END IF
    
    ! Special case: N = b+s
    ! R is maximized at K=b+s, so this is the first accepted term.
    ! Though the code below handles this correctly, we avoid that
    ! possibly long calculation for what is a common case.
    IF (ABS(b+s-N) .LT. 0.4d0) THEN
      accept = .TRUE.
      RETURN
    END IF
    
    ! For K >= Ktail, ordering parameter R is smaller than
    ! for any K < Ktail and is asymptotically decreasing.
    Ktail = FClnRsearch0(b,s) + 1
    
    ! Special case: N is in the tail region.
    ! Just have to check if probability for K >= N exceeds p-value.
    IF (N .GE. Ktail) THEN
      CALL LogPoissonSums(N,b+s,x,lnPsum)
      accept = (lnPsum .GT. lnp)
      RETURN
    END IF
    
    ! Get area of tail region
    CALL LogPoissonSums(Ktail,b+s,x,lnPsum)
    
    ! Special case: acceptance region contains at least [0,Ntail-1].
    ! By our above check, N is in [0,Ntail-1]
    IF (lnPsum .GT. lnp) THEN
      accept = .TRUE.
      RETURN
    END IF
    
    ! Now we narrow the interval from both sides using the
    ! ordering parameter.  We narrow until N falls outside
    ! the interval or the interval no longer covers enough
    ! probability (i.e. area outside the interval exceeds
    ! p-value).  We treats terms of equal R as one in terms
    ! of acceptance: this is handled appropriately below
    ! except for the case where R(K) is flat, which only
    ! occurs for the s=0 case already handled above.
    !
    K1   = 0
    lnR1 = FClnR(K1,b,s)
    K2   = Ktail-1
    lnR2 = FClnR(K2,b,s)
    ! Psum is probability outside of [K1,K2]
    DO WHILE ((lnPsum .LT. lnp))
      ! See if N is no longer in the valid region
      IF ((N .LT. K1) .OR. (N .GT. K2)) THEN
        accept = .FALSE.
        RETURN
      END IF
      ! Find term with _smaller_ R value: add its probability
      ! to Psum and drop from interval.  Note special case where
      ! both terms have same R value (drop both).
      IF (lnR1 .LT. lnR2) THEN
        lnPsum = LOG_SUM(lnPsum,LogPoisson(K1,b+s))
        K1     = K1+1
        lnR1   = FClnR(K1,b,s)
      ELSE IF (lnR1 .GT. lnR2) THEN
        lnPsum = LOG_SUM(lnPsum,LogPoisson(K2,b+s))
        K2     = K2-1
        lnR2   = FClnR(K2,b,s)
      ELSE
        lnPsum = LOG_SUM(lnPsum,LogPoisson(K1,b+s))
        K1     = K1+1
        lnR1   = FClnR(K1,b,s)
        lnPsum = LOG_SUM(lnPsum,LogPoisson(K2,b+s))
        K2     = K2-1
        lnR2   = FClnR(K2,b,s)
      END IF
    END DO
    
    ! If we made it here, we narrowed the interval too far before
    ! losing the K=N term.  N must be within the proper interval.
    accept = .TRUE.
    
  END FUNCTION
  
  ! ------------------------------------------
  ! Calculates the logarithm of the Poisson probability
  !   P(k|mu) = e^{-mu} mu^k / k!
  PURE FUNCTION LogPoisson(K,mu) RESULT(lnP)
    IMPLICIT NONE
    REAL*8 :: lnP
    INTEGER, INTENT(IN) :: K
    REAL*8, INTENT(IN) :: mu
    IF (K .EQ. 0) THEN
      lnP = -mu
    ELSE IF (mu .EQ. 0d0) THEN
      lnP = -HUGE(1d0)
    ELSE
      lnP = -mu + K*LOG(mu) - LOG_GAMMA(K+1d0)
    END IF
  END FUNCTION
  
  ! ------------------------------------------
  ! Calculates ln(r), where the ratio
  !   R = P(K|b+s)/P(K|b+s0(K))
  ! is the ordering term used by Feldman-Cousins, with
  !   s0(K) = max(0,K-b)
  ! the best-fit signal.
  PURE FUNCTION FClnR(K,b,s) RESULT(lnR)
    IMPLICIT NONE
    REAL*8 :: lnR
    INTEGER, INTENT(IN) :: K
    REAL*8, INTENT(IN) :: b,s
    IF (K .EQ. 0) THEN
      lnR = -s
    ELSE IF (b+s .LE. 0d0) THEN
      lnR = -HUGE(1d0)
    ELSE IF ( K .LE. b) THEN
      lnR = K*LOGp1(s/b) - s
    ELSE
      lnR = K*LOG((b+s)/K) + K - (b+s)
    END IF
  END FUNCTION
  
  ! ------------------------------------------
  ! Finds the index K such that the Feldman-Cousins
  ! ratio R is maximized for the given b & s.
  PURE FUNCTION FCpeakRloc(b,s) RESULT(K)
    IMPLICIT NONE
    INTEGER :: K
    REAL*8, INTENT(IN) :: b,s
    ! When analytically continuing R(k) for continuous k,
    ! there is a single maximum located at k=b+s.  For the
    ! discrete case, it must be at either the floor or
    ! ceiling of b+s.
    K = MAX(INT(b+s),0)
    IF (FClnR(K+1,b,s) .GT. FClnR(K,b,s)) K = K+1
  END FUNCTION
  
  ! ------------------------------------------
  ! Finds the largest index K such that the Feldman-Cousins
  ! ratio R is as large as R(K=0) for the given b & s.
  PURE FUNCTION FClnRsearch0(b,s) RESULT(K)
    IMPLICIT NONE
    INTEGER :: K
    REAL*8, INTENT(IN) :: b,s
    INTEGER :: K1,K2,Km,Kstep
    REAL*8 :: lnR0,lnR1,lnR2,lnRm
    Kstep = 1
    K1 = FCpeakRloc(b,s)
    K2 = K1+Kstep
    lnR0 = FClnR(0,b,s)
    lnR1 = FClnR(K1,b,s)
    lnR2 = FClnR(K2,b,s)
    ! Bracket
    DO WHILE (lnR2 .GE. lnR0)
      Kstep = 2*Kstep
      K1    = K2
      lnR1  = lnR2
      K2    = K2+Kstep
      lnR2 = FClnR(K2,b,s)
    END DO
    ! Bisection
    DO WHILE (K2-K1 .GT. 1)
      Km   = K1 + (K2-K1)/2
      lnRm = FClnR(Km,b,s)
      IF (lnRm .GE. lnR0) THEN
        K1   = Km
        lnR1 = lnRm
      ELSE
        K2   = Km
        lnR2 = lnRm
      END IF
    END DO
    K = K1
  END FUNCTION
  
END SUBROUTINE


! ----------------------------------------------------------------------
! For the Poisson distribution P(k|mu), calculates the log of the
! p-value, where p is defined as:
!   p = \Sum_{k\le N} P(k|mu)
! 
PURE FUNCTION LogPoissonP(N,mu) RESULT(lnp)
  IMPLICIT NONE
  REAL*8 :: lnp
  INTEGER, INTENT(IN) :: N
  REAL*8, INTENT(IN) :: mu
  REAL*8 :: lnlesum,lngesum
  
  ! Utility routine calculates P(k|mu) for k\le N and k\ge N.
  CALL LogPoissonSums(N,mu,lnlesum,lngesum)
  lnp = lnlesum
  
END FUNCTION


! ----------------------------------------------------------------------
! For the Poisson distribution P(k|mu), calculates the log of the sums:
!   lesum = \Sum_{k\le N} P(k|mu)
!   gesum = \Sum_{k\ge N} P(k|mu)
! This routine calculates the smaller of the two and uses the relation
!   lesum + gesum = 1 + P(N|mu)
! to find the other (note the k=N term appears in both sums).
! 
! Input arguments:
!   N           Maximum/minimum k in sum
!   mu          Mean of the Poisson
! Output arguments:
!   lnlesum     The logarithm of the sum of Poisson terms k = 0,1,...,N.
!   lngesum     The logarithm of the sum of Poisson terms k = N,N+1,....
! 
PURE SUBROUTINE LogPoissonSums(N,mu,lnlesum,lngesum)
  IMPLICIT NONE
  REAL*8 :: lnp
  INTEGER, INTENT(IN) :: N
  REAL*8, INTENT(IN) :: mu
  REAL*8, INTENT(OUT) :: lnlesum,lngesum
  INTEGER :: K,Kmax
  REAL*8 :: lnpmf0,lnpmf
  REAL*8, PARAMETER :: LN_PRECISION = -35d0  ! Precision of ~ 1d-15
  
  ! Special cases
  IF (mu .LE. 0d0) THEN
    lnlesum = 0d0
    IF (N .EQ. 0) THEN
      lngesum = 0d0
    ELSE
      lngesum = -HUGE(1d0)
    END IF
    RETURN
  ELSE IF (N .EQ. 0d0) THEN
    lnlesum = -mu
    lngesum = 0d0
    RETURN
  END IF
  
  ! General case
  lnpmf = N*LOG(mu) - mu - LOG_GAMMA(N+1d0)
  lnpmf0 = lnpmf
  
  ! NOTE: This algorithm calculates the log of the sum of both
  !       all K <= N (lnlesum) and all K >= N (lngesum).
  ! The distribution peaks around n = mu; to avoid a loss of
  ! precision, we will do the lower sum for n < mu and the
  ! upper sum for n > mu.
  IF (N .LE. mu) THEN
    K = N
    lnlesum = lnpmf
    DO WHILE (k .GT. 0)
      K = K-1
      lnpmf = lnpmf + LOG((K+1)/mu)
      lnlesum = LOG_SUM(lnlesum,lnpmf)
      IF (lnpmf - lnlesum .LE. LN_PRECISION) EXIT
    END DO
    lngesum = LOG(1d0 - (EXP(lnlesum) - EXP(lnpmf0)))
  ELSE
    K = N
    lngesum = lnpmf
    ! Determine a conservative upper limit on sum terms.
    ! Will hopefully hit precision condition first, but include
    ! this upper limit in case we didn't think of some pathological
    ! cases.
    IF ((N-mu)**2 .GT. mu) THEN
      Kmax = N + NINT(-LN_PRECISION * (N/(N-mu))) + 10
    ELSE
      Kmax = N + NINT(-LN_PRECISION * (1d0+SQRT(mu))) + 10
    END IF
    DO WHILE (K .LT. Kmax)
      K = K+1
      lnpmf = lnpmf + LOG(mu/K)
      lngesum = LOG_SUM(lngesum,lnpmf)
      IF (lnp - lngesum .LE. LN_PRECISION) EXIT
    END DO
    lnlesum = LOG(1d0 - (EXP(lngesum) - EXP(lnpmf0)))
  END IF
  
END SUBROUTINE


! ----------------------------------------------------------------------
! Calculates the log of the maximum gap statistic.  See:
!   S. Yellin, Phys. Rev. D 66, 032005 (2002) [arXiv:physics/0203002]
! This statistic is an upper bound on the p-value in the event the
! background spectrum is unknown.  The p-value is equal to 1-C_0 and
! is given by:
!   p = \sum_{k=1}^{floor(mu/x)} (k*x-mu)^(k-1) e^(-k*x) (mu-k(x-1)) / k!
! 
! NOTE: IMPLEMENTATION NEEDS TESTING.
! 
! Input arguments:
!   mu          Average expected number of signal events
!   x           Largest expected number of signal events in any
!               interval/gap.
! 
PURE FUNCTION LogMaximumGapP(mu,x) RESULT(lnp)
  IMPLICIT NONE
  REAL*8 :: lnp
  REAL*8, INTENT(IN) :: mu,x
  INTEGER :: K,Kmax
  REAL*8 :: p,psum,z
  
  ! Bad cases
  IF ((mu .LT. 0d0) .OR. (x .LT. 0d0)) THEN
    lnp = HUGE(1d0)
    RETURN
  END IF
  
  ! Special cases
  IF (mu .EQ. 0d0) THEN
    lnp = 0d0
    RETURN
  ELSE IF (x .GE. mu) THEN
    lnp = -mu
    RETURN
  ELSE IF (x .EQ. 0d0) THEN
    lnp = 0d0
    RETURN
  END IF
  
  ! Not optimized for log case or any extreme case
  ! WARNING: CONDITIONS AND ALGORITHMS NOT FULLY TESTED.
  
  IF (mu*EXP(-x) .GT. 12.5d0) THEN
    lnp = 0d0
    RETURN
  END IF
  
  ! Calculation involves sum from 1 to Kmax = floor(mu/x).  By
  ! definition, Kmax should never exceed the number of intervals.
  ! We handle the lowest Kmax cases explicitly and do the sum for
  ! larger Kmax.
  
  ! Small epsilon added to avoid bad truncation results
  ! when mu/x is an integer.
  Kmax = INT(mu/x+SQRT(EPSILON(1d0)))
  SELECT CASE (Kmax)
  CASE (:0)
    lnp = HUGE(1d0)
  CASE (1)
    ! p = (mu-x+1) e^-x
    ! Note LOGp1(z) = ln(1+z)
    lnp = -x + LOGp1(mu-x)
  CASE (2)
    ! p = (mu-x+1) e^-x [1 - 1/2 (mu-2x) e^(-x) (1 - (x-1)/(mu-(x-1)))]
    ! maximum z in range of validity is 0.1925 (safe here)
    z = 0.5d0 * (mu-2*x) * EXP(-x) * (mu-2*(x-1)) / (mu-x+1)
    lnp = -x + LOGp1(mu-x) + LOGp1(-z)
  CASE (3:)
    ! Do explicit sum.
    ! Note finite alternating series makes accuracy/precision
    ! and convergence determinations difficult.
    psum = 0d0
    DO K = 1,Kmax
      p = (K*x-mu)**(K-1) * EXP(-K*x) * (mu - K*(x-1)) / GAMMAI(K+1)
      psum = psum + p
    END DO
    lnp = LOG(psum)
  END SELECT
  
END FUNCTION

END MODULE
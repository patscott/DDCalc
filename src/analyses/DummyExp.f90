MODULE DummyExp

!=======================================================================
! Dummy experiment ANALYSIS ROUTINES
!=======================================================================

USE DDTypes
USE DDDetectors

IMPLICIT NONE

CONTAINS


!-----------------------------------------------------------------------
! Initializes a DetectorStruct of a dummy experiment
!
FUNCTION DummyExp_Init() RESULT(D)

  IMPLICIT NONE
  TYPE(DetectorStruct) :: D
  INTEGER, PARAMETER :: NE = 151
  INTEGER, PARAMETER :: NBINS = 2 ! 2
  ! Efficiency curves energy tabulation points
  REAL*8, PARAMETER :: E(NE)                                            &
      =       (/ 0.10000d0, 0.10471d0, 0.10965d0, 0.11482d0, 0.12023d0, &
      0.12589d0, 0.13183d0, 0.13804d0, 0.14454d0, 0.15136d0, 0.15849d0, &
      0.16596d0, 0.17378d0, 0.18197d0, 0.19055d0, 0.19953d0, 0.20893d0, &
      0.21878d0, 0.22909d0, 0.23988d0, 0.25119d0, 0.26303d0, 0.27542d0, &
      0.28840d0, 0.30200d0, 0.31623d0, 0.33113d0, 0.34674d0, 0.36308d0, &
      0.38019d0, 0.39811d0, 0.41687d0, 0.43652d0, 0.45709d0, 0.47863d0, &
      0.50119d0, 0.52481d0, 0.54954d0, 0.57544d0, 0.60256d0, 0.63096d0, &
      0.66069d0, 0.69183d0, 0.72444d0, 0.75858d0, 0.79433d0, 0.83176d0, &
      0.87096d0, 0.91201d0, 0.95499d0, 1.0000d0,  1.0471d0,  1.0965d0,  &
      1.1482d0,  1.2023d0,  1.2589d0,  1.3183d0,  1.3804d0,  1.4454d0,  &
      1.5136d0,  1.5849d0,  1.6596d0,  1.7378d0,  1.8197d0,  1.9055d0,  &
      1.9953d0,  2.0893d0,  2.1878d0,  2.2909d0,  2.3988d0,  2.5119d0,  &
      2.6303d0,  2.7542d0,  2.8840d0,  3.0200d0,  3.1623d0,  3.3113d0,  &
      3.4674d0,  3.6308d0,  3.8019d0,  3.9811d0,  4.1687d0,  4.3652d0,  &
      4.5709d0,  4.7863d0,  5.0119d0,  5.2481d0,  5.4954d0,  5.7544d0,  &
      6.0256d0,  6.3096d0,  6.6069d0,  6.9183d0,  7.2444d0,  7.5858d0,  &
      7.9433d0,  8.3176d0,  8.7096d0,  9.1201d0,  9.5499d0, 10.000d0,   &
     10.471d0,  10.965d0,  11.482d0,  12.023d0,  12.589d0,  13.183d0,   &
     13.804d0,  14.454d0,  15.136d0,  15.849d0,  16.596d0,  17.378d0,   &
     18.197d0,  19.055d0,  19.953d0,  20.893d0,  21.878d0,  22.909d0,   &
     23.988d0,  25.119d0,  26.303d0,  27.542d0,  28.840d0,  30.200d0,   &
     31.623d0,  33.113d0,  34.674d0,  36.308d0,  38.019d0,  39.811d0,   &
     41.687d0,  43.652d0,  45.709d0,  47.863d0,  50.119d0,  52.481d0,   &
     54.954d0,  57.544d0,  60.256d0,  63.096d0,  66.069d0,  69.183d0,   &
     72.444d0,  75.858d0,  79.433d0,  83.176d0,  87.096d0,  91.201d0,   &
     95.499d0, 100.00d0 /)
  ! LOWER 50% NR BAND >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  ! Efficiency (total)
  REAL*8, PARAMETER :: EFF0(NE)                                         &
      =       (/ 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      2.00000d-7,2.00000d-7,2.00000d-7,3.00000d-7,6.00000d-7,1.20000d-6,&
      1.40000d-6,1.90000d-6,4.20000d-6,4.80000d-6,6.50000d-6,1.08000d-5,&
      1.74000d-5,2.38000d-5,3.42000d-5,4.58000d-5,6.88000d-5,9.74000d-5,&
      1.37700d-4,1.96200d-4,2.84900d-4,3.97300d-4,5.54700d-4,7.81600d-4,&
      1.08660d-3,1.54220d-3,2.12830d-3,2.95810d-3,4.36510d-3,6.05560d-3,&
      8.07280d-3,1.08272d-2,1.40706d-2,1.84873d-2,2.39837d-2,3.08424d-2,&
      3.95926d-2,4.99352d-2,6.27487d-2,7.66224d-2,9.42524d-2,1.15720d-1,&
      1.40320d-1,1.67930d-1,1.98780d-1,2.32650d-1,2.68550d-1,3.06370d-1,&
      3.45110d-1,3.83720d-1,4.20080d-1,4.55080d-1,4.86810d-1,5.14040d-1,&
      5.37080d-1,5.54520d-1,5.66770d-1,5.73020d-1,5.74600d-1,5.71510d-1,&
      5.64900d-1,5.54790d-1,5.43390d-1,5.31050d-1,5.17910d-1,5.05330d-1,&
      4.94050d-1,4.83350d-1,4.74620d-1,4.67740d-1,4.61250d-1,4.56760d-1,&
      4.52870d-1,4.49950d-1,4.47830d-1,4.46160d-1,4.44270d-1,4.42740d-1,&
      4.41050d-1,4.39550d-1,4.38810d-1,4.37010d-1,4.33900d-1,4.28450d-1,&
      4.18620d-1,4.02840d-1,3.78120d-1,3.42460d-1,2.94850d-1,2.37970d-1,&
      1.77820d-1,1.21260d-1,7.52971d-2,4.19808d-2,2.08447d-2,9.20250d-3,&
      3.55500d-3,1.23880d-3,3.67200d-4,9.76000d-5,2.22000d-5,5.50000d-6,&
      9.00000d-7,0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0 /)
  ! Efficiency (first interval)
  REAL*8, PARAMETER :: EFF1(NE)                                         &
      =       (/ 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      1.00000d-7,2.00000d-7,2.00000d-7,3.00000d-7,6.00000d-7,1.10000d-6,&
      1.10000d-6,1.70000d-6,3.60000d-6,4.50000d-6,5.70000d-6,9.30000d-6,&
      1.54000d-5,2.07000d-5,2.90000d-5,3.92000d-5,5.91000d-5,8.30000d-5,&
      1.17700d-4,1.62500d-4,2.37000d-4,3.26000d-4,4.56700d-4,6.23200d-4,&
      8.61500d-4,1.21160d-3,1.64560d-3,2.25640d-3,3.25450d-3,4.43340d-3,&
      5.82990d-3,7.69370d-3,9.85520d-3,1.27067d-2,1.61984d-2,2.03405d-2,&
      2.56110d-2,3.15482d-2,3.86713d-2,4.64675d-2,5.56741d-2,6.63380d-2,&
      7.77153d-2,8.96590d-2,1.02090d-1,1.14360d-1,1.25880d-1,1.36440d-1,&
      1.45460d-1,1.51910d-1,1.55090d-1,1.55910d-1,1.53090d-1,1.46780d-1,&
      1.37830d-1,1.26400d-1,1.12860d-1,9.78608d-2,8.25226d-2,6.74473d-2,&
      5.35181d-2,4.07813d-2,3.01037d-2,2.13387d-2,1.44853d-2,9.50610d-3,&
      5.88720d-3,3.47590d-3,1.97510d-3,1.07430d-3,5.52700d-4,2.55800d-4,&
      1.12100d-4,5.05000d-5,2.12000d-5,6.90000d-6,2.10000d-6,8.00000d-7,&
      0.00000d0, 2.00000d-7,0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0 /)
  ! Efficiency (second interval)
  REAL*8, PARAMETER :: EFF2(NE)                                         &
      =       (/ 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      1.00000d-7,0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 1.00000d-7,&
      3.00000d-7,2.00000d-7,6.00000d-7,3.00000d-7,8.00000d-7,1.50000d-6,&
      2.00000d-6,3.10000d-6,5.20000d-6,6.60000d-6,9.70000d-6,1.44000d-5,&
      2.00000d-5,3.37000d-5,4.79000d-5,7.13000d-5,9.80000d-5,1.58400d-4,&
      2.25100d-4,3.30600d-4,4.82700d-4,7.01700d-4,1.11060d-3,1.62220d-3,&
      2.24290d-3,3.13350d-3,4.21540d-3,5.78060d-3,7.78530d-3,1.05019d-2,&
      1.39816d-2,1.83870d-2,2.40774d-2,3.01549d-2,3.85783d-2,4.93773d-2,&
      6.26065d-2,7.82662d-2,9.66959d-2,1.18290d-1,1.42670d-1,1.69920d-1,&
      1.99650d-1,2.31820d-1,2.64980d-1,2.99170d-1,3.33710d-1,3.67250d-1,&
      3.99250d-1,4.28120d-1,4.53910d-1,4.75160d-1,4.92080d-1,5.04070d-1,&
      5.11390d-1,5.14010d-1,5.13290d-1,5.09720d-1,5.03430d-1,4.95830d-1,&
      4.88170d-1,4.79880d-1,4.72650d-1,4.66660d-1,4.60700d-1,4.56500d-1,&
      4.52750d-1,4.49900d-1,4.47800d-1,4.46160d-1,4.44260d-1,4.42740d-1,&
      4.41050d-1,4.39550d-1,4.38810d-1,4.37010d-1,4.33900d-1,4.28450d-1,&
      4.18620d-1,4.02840d-1,3.78120d-1,3.42460d-1,2.94850d-1,2.37970d-1,&
      1.77820d-1,1.21260d-1,7.52971d-2,4.19808d-2,2.08447d-2,9.20250d-3,&
      3.55500d-3,1.23880d-3,3.67200d-4,9.76000d-5,2.22000d-5,5.50000d-6,&
      9.00000d-7,0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, 0.00000d0, &
      0.00000d0, 0.00000d0 /)

  REAL*8, PARAMETER :: EFF(NE,0:NBINS)                                   &
      = RESHAPE( (/ (/ EFF0(:), EFF1(:), EFF2(:) /) /) ,SHAPE(EFF))

  CALL SetDetector(D,mass=118d0,time=85.3d0,Nevents_tot=11,               &
                   Backgr_tot = 1.3d0, &
                   Nelem=1,Zelem=(/54/),               &
                   NE=NE,E=E,Nbins=NBINS,eff_all=EFF)
  D%eff_file = '[DummyExp]'
  
END FUNCTION


! C++ interface wrapper
INTEGER(KIND=C_INT) FUNCTION C_DummyExp_Init() &
 BIND(C,NAME='C_DDCalc_dummyexp_60_init') 
  USE ISO_C_BINDING, only: C_BOOL, C_INT
  IMPLICIT NONE
  N_Detectors = N_Detectors + 1
  ALLOCATE(Detectors(N_Detectors)%p)
  Detectors(N_Detectors)%p = DummyExp_Init()
  C_DummyExp_Init = N_Detectors
END FUNCTION


END MODULE

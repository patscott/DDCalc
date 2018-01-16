MODULE DDExperiments

!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
!  DDExperiments
!    Lists of experimental analyses included in DDCalc.  To add any new
!    experimental analysis:
!    1.  Put it in its own individual module source file, put that file
!        in src/analyses, and then USE that module from here.
!    2.  If you want your new analysis to also be available in the
!        commandline version of DDCalc, make sure to add it to the list
!        in AvailableAnalyses below.
!    3.  If you want your new analysis to also be available when calling
!        DDCalc from C/C++, make sure to add it to
!        include/DDExperiments.hpp too.
!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

USE XENON100_2012
USE LUX_2013
USE SIMPLE_2014
USE SuperCDMS_2014
USE Darwin_Ar
USE Darwin_Xe
USE LUX_2016
USE PandaX_2016
USE PandaX_2017
USE Xenon1T_2017
USE LUX_2015
USE PICO_2L
USE PICO_60_F
USE PICO_60_I
USE PICO_60
USE PICO_60_2017
USE CRESST_II
USE DummyExp

IMPLICIT NONE

! Change these if you want to pick a different analysis as the default.
INTERFACE DDCalc_InitDefaultDetector
  MODULE PROCEDURE Xenon1T_2017_Init
END INTERFACE

END MODULE

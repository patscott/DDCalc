/**********************************************************************
 * DDCALC EXAMPLE PROGRAM (C++)
 * This program shows how to use the DDCalc module from C++, making
 * use of the interface defined in the DDCalc.hpp header file.
 * 
 * Run:
 *   ./DDCalc_exampleC [--mG|--mfa]
 * where the optional flag specifies the form in which the WIMP-nucleon
 * couplings will be provided (default: --mfa).
 * 
 * 
 *       A. Scaffidi     U of Adelaide    2015    
 *       C. Savage       Nordita          2015
 *       P. Scott        Imperial Collge  2016
 *       F. Kahlhoefer   DESY		  2017
 *       S. Wild     	 DESY		  2017
 *       ddcalc@projects.hepforge.org
 * 
 **********************************************************************/

// All the DDCalc routines used below are declared in (or included from)
// the DDCalc.hpp header file.

#include <cstdlib>
#include <cstdio>
#include <cmath>
#include <iostream>
#include <string>
#include <sstream>

#include "DDCalc.hpp"


// CONSTANTS -----------------------------------------------------------

// These constants will be used to specify the type of input parameters.
const int TYPE_MG     = 1;  // Four-fermion effective couplings G
const int TYPE_MFA    = 2;  // Effective couplings f (SI), a (SD)


// UTILITY FUNCTIONS DECLARATIONS --------------------------------------

/* Provide prototypes for utility functions used by this example
   program.  The function definitions are given later in this file,
   after the main() routine. */

// Print description of input
void WriteDescription(const int type);

// Get WIMP mass and couplings
bool GetWIMPParams(const int type, double& M, double& xpSI, double& xnSI,
                   double& xpSD, double& xnSD);


// MAIN PROGRAM --------------------------------------------------------

int main(int argc, char* argv[])
{  
  
  int type;
  double M,xpSI,xnSI,xpSD,xnSD,GpSI,GnSI,GpSD,GnSD,fp,fn,ap,an;
  
  // These three sets of indices refer to instance of the three types that
  // are the bedrock of DDCalc.  (Almost) every calculation needs to be
  // provided with an instance of each of these to do its job.  Passing the
  // index of one of them to DDCalc tells it which one in its internal cache
  // to use for the calculation requested. You can make have as many
  // different instances as you want, corresponding to e.g. different
  // detectors/analyses, WIMP models and DM halo models; the factory
  // funcions create the instances in DDCalc and return you the index of
  // the resulting object.
  int WIMP;
  int Halo;
  int XENON, LUX, SCDMS, SIMPLE;  

  // Parse command line options
  // Notably, determining how WIMP parameters will be specified.
  // Default command line option (no argument) will give type = TYPE_MFA.
  type = TYPE_MFA;
  for (int i=1; i<argc; i++)
  {
    if (std::string(argv[i]) == "--mG")
      type = TYPE_MG;
    else if (std::string(argv[i]) == "--mfa")
      type = TYPE_MFA;
    else if (std::string(argv[i]) == "--help")
    {
      std::cout << "Usage:" << std::endl;
      std::cout << "  ./DDCalc_exampleC [--mG|--mfa]" << std::endl;
      std::cout << "where the optional flag specifies the form in which the WIMP-" << std::endl;
      std::cout << "nucleon couplings will be provided (default: --mfa)." << std::endl;
      exit(0);
    } else
    {
      std::cout << "WARNING:  Ignoring unknown argument '" << argv[i] << "'." << std::endl;
    }
  }
  
  /* Note that we never have to initialise DDCalc as a whole, we just
     have to create Detectors, WIMPs and Halos, then manipulate their
     parameters and hand them back to DDCalc to do calculations on. */

  /* Initialise a DM Halo object to default values.  See below for how to
     modify these values. */
  Halo = DDCalc::InitHalo();
    
  /* Initialise a WIMP object to default values.  Actually, this isn't
     necessary here, as we set the WIMP properties from the commandline
     later -- but here's how you would make a default version if needed: */
  WIMP = DDCalc::InitWIMP();

  /* Explicitly create detector objects for all the experiments to be
     used (set up isotopes, efficiencies, array sizing, etc.)  The   
     argument indicates if extra sub-interval calculations should
     be performed.  Those calculations are required for maximum gap
     analyses, but are unnecessary for calculating total rates and
     likelihoods.  If .FALSE. is given, a no-background-subtraction
     p-value can still be calculated, but a Poisson is used instead
     of the maximum gap.  We show some maximum gap results below, so
     we must use true here (the flag is ignored for experiments
     that do not have the event energies necessary for a maximum gap
     analysis). */
  XENON    = DDCalc::XENON100_2012_Init();
  LUX      = DDCalc::LUX_2013_Init();
  SCDMS    = DDCalc::SuperCDMS_2014_Init();
  SIMPLE   = DDCalc::SIMPLE_2014_Init();

  /* Can optionally specify a minimum recoil energy to be included in
     the rate calculations [keV].  Note the efficiency curves already
     account for detector and analysis thresholds regardless of this
     setting, so setting this to 0 keV (the default behavior when
     initialization is performed) does not imply that very low energy
     recoils actually contribute to the signal.
     EXAMPLE: Uncomment to set a minimum recoil energy of 3 keV for LUX: */
  //DDCalc::SetEmin(LUX,3.0)

  /* Optionally set the Standard Halo Model parameters:
       rho     Local dark matter density [GeV/cm^3]
       vrot    Local disk rotation speed [km/s]
       v0      Maxwell-Boltzmann most probable speed [km/s]
       vesc    Galactic escape speed [km/s]
     This example uses the default values (and is thus optional). */
  //DDCalc::SetSHM(0.4, 235.0, 235.0, 550.0)
  
  // INPUT LOOP >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  // Loop over input to this example program.
  // GetWIMPParams is defined below.
  while(GetWIMPParams(type,M,xpSI,xnSI,xpSD,xnSD))
  {

    std::cout << std::endl;
    
    /* Set the WIMP parameters.
       There are three ways to specify the WIMP-nucleon couplings, with
       the WIMP mass [GeV] always the first argument:
         * DDCalc::SetWIMP_mfa(m,fp,fn,ap,an)
           The standard couplings fp,fn [GeV^-2] & ap,an [unitless]
         * DDCalc::SetWIMP_mG(m,GpSI,GnSI,GpSD,GnSD)
           The effective 4 fermion vertex couplings GpSI,GnSI,GpSD,GnSD
           [GeV^-2], related by:
               GpSI = 2 fp        GpSD = 2\sqrt{2} G_F ap
               GnSI = 2 fn        GnSD = 2\sqrt{2} G_F an
       In the above, 'p' is for proton, 'n' is for neutron, 'SI' is for
       spin-independent, and 'SD' is for spin-dependent. */
    switch (type)
    {
      case TYPE_MG:
        DDCalc::SetWIMP_mG(WIMP,M,xpSI,xnSI,xpSD,xnSD);
        break;
      case TYPE_MFA:
        DDCalc::SetWIMP_mfa(WIMP,M,xpSI,xnSI,xpSD,xnSD);
        break;
    }
    
    /* Get the WIMP parameters with the same signatures and units as
       above.  The only difference is that WIMP-nucleon cross-sections
       are always positive. */
    DDCalc::GetWIMP_mfa(WIMP,M,fp,fn,ap,an);
    DDCalc::GetWIMP_mG(WIMP,M,GpSI,GnSI,GpSD,GnSD);
    
    /* Print out the above WIMP mass, couplings, and cross sections. */
    printf("%s %- #12.5g\n","WIMP mass [GeV]     ",M);
    std::cout << std::endl;
    printf("%-28s %11s %11s %11s %11s\n","WIMP-nucleon couplings",
           " proton-SI "," neutron-SI"," proton-SD "," neutron-SD");
    printf("%-28s %- #11.5g %- #11.5g %- #11.5g %- #11.5g\n",
           "  G [GeV^-2]",GpSI,GnSI,GpSD,GnSD);
    printf("%-28s %- #11.5g %- #11.5g %- #11.5g %- #11.5g\n",
           "  f & a [GeV^-2,unitless]",fp,fn,ap,an);
    std::cout << std::endl;
    
    /* Do rate calculations using the specified WIMP and halo parameters.
       Does the calculations necessary for predicted signals, likelihoods
       and/or maximum gap statistics. */
    DDCalc::CalcRates(XENON,WIMP,Halo);
    DDCalc::CalcRates(LUX,WIMP,Halo);
    DDCalc::CalcRates(SCDMS,WIMP,Halo);
    DDCalc::CalcRates(SIMPLE,WIMP,Halo);
    
    /* Header */
    printf("%-20s  %11s  %11s  %11s  %11s\n","",
           " XENON 2012"," LUX 2013  ","SuCDMS 2014","SIMPLE 2014");
    //printf("%-20s  %11s  %11s  %11s  %11s  %11s\n","",
    //       "-----------","-----------","-----------","-----------",
    //       "-----------","-----------");
    
    /* Event quantities. */
    printf("%-20s  % 6i       % 6i       % 6i       % 6i       \n",
           "Observed events     ",
        DDCalc::Events(XENON),
        DDCalc::Events(LUX),
        DDCalc::Events(SCDMS),
        DDCalc::Events(SIMPLE));
    printf("%-20s  %- #11.5g  %- #11.5g  %- #11.5g  %- #11.5g  \n",
           "Expected background ",
        DDCalc::Background(XENON),
        DDCalc::Background(LUX),
        DDCalc::Background(SCDMS),
        DDCalc::Background(SIMPLE));
    printf("%-20s  %- #11.5g  %- #11.5g  %- #11.5g  %- #11.5g  \n",
           "Expected signal     ",
        DDCalc::Signal(XENON),
        DDCalc::Signal(LUX),
        DDCalc::Signal(SCDMS),
        DDCalc::Signal(SIMPLE));
    
    /* The log-likelihoods for the current WIMP; note these are _not_
       multiplied by -2. */
    printf("%-20s  %- #11.5g  %- #11.5g  %- #11.5g  %- #11.5g  \n",
           "Log-likelihood      ",
        DDCalc::LogLikelihood(XENON),
        DDCalc::LogLikelihood(LUX),
        DDCalc::LogLikelihood(SCDMS),
        DDCalc::LogLikelihood(SIMPLE));
        
    /* Returns a factor x by which the current WIMP cross-sections must
       be multiplied (sigma -> x*sigma, applied to all four WIMP-nucleon
       cross-sections) to achieve the given p-value (specified by its
       logarithm). For example, if setWIMP_msigma(100.0,10.0,
       10.0,0.0,0.0) is called, then x*(10. pb) would be the SI
       cross-section at a WIMP mass of 100 GeV at which the experiment
       is excluded at the 90% CL (p=1-CL). */
    double lnp = log(0.1);  // default value for optional argument
    printf("%-20s  %- #11.5g  %- #11.5g  %- #11.5g  %- #11.5g  \n",
           "Rescaling for 90% CL",
        DDCalc::ScaleToPValue(XENON),
        DDCalc::ScaleToPValue(LUX),
        DDCalc::ScaleToPValue(SCDMS),
        DDCalc::ScaleToPValue(SIMPLE));
    std::cout << " * This is the factor by which the cross section must be rescaled to give the desired p-value" << std::endl;

  }  // END INPUT LOOP <<<<<<<<<<<<<<<<<<<<<<<<<

  // Clean up all the objects
  DDCalc::FreeAll();

} 


// UTILITY FUNCTION DEFINITIONS ----------------------------------------

/* Write a description of how input parameters should be specified. */
void WriteDescription(const int type)
{
  std::cout << std::endl;
  std::cout << "Enter WIMP parameters below.  Only the first two are necessary." << std::endl;
  std::cout << "A blank line terminates input.  The parameters are:" << std::endl;
  //std::cout << "Enter WIMP parameters below.  The parameters are:" << std::endl;
  std::cout << std::endl;
  switch (type)
  {
    case TYPE_MG:
      std::cout << "  M     WIMP mass [GeV]" << std::endl;
      std::cout << "  GpSI  Spin-independent WIMP-proton effective coupling [GeV^-2]" << std::endl;
      std::cout << "  GnSI  Spin-independent WIMP-neutron effective coupling [GeV^-2]" << std::endl;
      std::cout << "  GpSD  Spin-dependent WIMP-proton effective coupling [GeV^-2]" << std::endl;
      std::cout << "  GnSD  Spin-dependent WIMP-neutron effective coupling [GeV^-2]" << std::endl;
      break;
    case TYPE_MFA:
      std::cout << "  M     WIMP mass [GeV]" << std::endl;
      std::cout << "  fp    Spin-independent WIMP-proton effective coupling [GeV^-2]" << std::endl;
      std::cout << "  fn    Spin-independent WIMP-neutron effective coupling [GeV^-2]" << std::endl;
      std::cout << "  ap    Spin-dependent WIMP-proton effective coupling [unitless]" << std::endl;
      std::cout << "  an    Spin-dependent WIMP-neutron effective coupling [unitless]" << std::endl;
      break;
  }
}


/* Read WIMP parameters (mass & couplings) from standard input. */
bool GetWIMPParams(const int type, double& M, double& xpSI, double& xnSI,
                   double& xpSD, double& xnSD)
{
  std::cout << std::endl;
  std::cout << "------------------------------------------------------------" << std::endl;
  switch (type)
  {
    case TYPE_MG:
      std::cout << "Enter values <M GpSI GnSI GpSD GnSD>:" << std::endl;
      break;
    case TYPE_MFA:
      std::cout << "Enter values <M fp fn ap an>:" << std::endl;
      break;
    }
  
  // Get input line for parsing
  std::string line;
  getline(std::cin, line);
  std::istringstream iss(line);

  // Parse input line
  if (!(iss >> M)) return false;
  if (!(iss >> xpSI)) return false;
  if (!(iss >> xnSI))
  {
    xnSI = xpSI; xpSD = 0.0; xnSD = 0.0;
    return true;
  }
  if (!(iss >> xpSD))
  {
    xpSD = 0.0; xnSD = 0.0;
    return true;
  }
  if (!(iss >> xnSD))
  {
    xnSD = xpSD;
    return true;
  }
  return true;
}


// END FILE ------------------------------------------------------------

 

#include <stdlib.h>
#include "..\..\lingd11.h"

/*

  This code calls the LINGO DLL to solve the simple linear program:

  MAX     100 STANDARD + 150 TURBO
  SUBJECT TO
  2]  STANDARD <=   100
  3]  TURBO <=   120
  4]  STANDARD + 2 TURBO <=   160
  END

*/
/////////////////////////////////////////////////////////////////////////////

int __stdcall MyCallback( void* pModel, int nReserved, void* pUserData)
{

   // this callback function will be called periodically by the Lingo solver 

   int* pnCallbacks = (int*) pUserData;
   ++*pnCallbacks;
   if ( !(*pnCallbacks % 10)) printf( "In Callback: %d\n", *pnCallbacks);
   return( 0);

}

/////////////////////////////////////////////////////////////////////////////

int __stdcall MyErrorCallback( void* pModel, void* pUserData, int nErrorCode,
 char* pcErrorText)
{
   // this callback function will be called whenever Lingo hits an error

   printf( "In Error Callback: Error %d:\n%s \n", nErrorCode, pcErrorText);
   return( 0);

}

/////////////////////////////////////////////////////////////////////////////

void main()
{

   char cScript[256];

   char cComputers[64] = "STANDARD\nTURBO\n";
   int nError=-1, nPointersNow;
   int nCallbacks = 0;
   double dObjective, dStatus=-1.;
   double dProfit[] = {100., 150.};
   double dLimit[] = {100., 120.};
   double dLabor[] = {1., 2.};
   double dProduce[ sizeof( dProfit) / sizeof( double)];

   // create the LINGO environment object
   pLSenvLINGO pLINGO;
   pLINGO = LScreateEnvLng();
   if ( !pLINGO) 
   {
      printf( "Can''t create LINGO environment!\n");
      goto FinalExit;
   }

   // Pass LINGO a pointer to our callback function
   nCallbacks = 0;
   nError = LSsetCallbackSolverLng( pLINGO, &MyCallback, &nCallbacks);
   if ( nError) goto ErrorExit;

   // Pass LINGO a pointer to our callback function
   nCallbacks = 0;
   nError = LSsetCallbackErrorLng( pLINGO, &MyErrorCallback, NULL);
   if ( nError) goto ErrorExit;

     // Open LINGO's log file  
   nError = LSopenLogFileLng( pLINGO, "LINGO.log");
   if ( nError) goto ErrorExit;

   // Pass memory transfer pointers to LINGO

   // @POINTER(1)
   nError = LSsetPointerLng( pLINGO, dProfit, &nPointersNow); 
   if ( nError) goto ErrorExit;

   // @POINTER(2)
   nError = LSsetPointerLng( pLINGO, dLimit, &nPointersNow); 
   if ( nError) goto ErrorExit;

   // @POINTER(3)
   nError = LSsetPointerLng( pLINGO, dLabor, &nPointersNow); 
   if ( nError) goto ErrorExit;

   // @POINTER(4)
   nError = LSsetPointerLng( pLINGO, &dObjective, &nPointersNow); 
   if ( nError) goto ErrorExit;

   // @POINTER(5)
   nError = LSsetPointerLng( pLINGO, &dStatus, &nPointersNow); 
   if ( nError) goto ErrorExit;

   // @POINTER(6)
   nError = LSsetPointerLng( pLINGO, dProduce, &nPointersNow); 
   if ( nError) goto ErrorExit;

   // @POINTER(7)
   nError = LSsetPointerLng( pLINGO, cComputers, &nPointersNow); 
   if ( nError) goto ErrorExit;


   // Here is the script we want LINGO to run
   strcpy( cScript, "SET ECHOIN 1 \n TAKE SIMPLE.LNG \n GO \n QUIT \n");

   // Run the script
   nError = LSexecuteScriptLng( pLINGO, cScript);
   if ( nError) goto ErrorExit;

   // Close the log file
   LScloseLogFileLng( pLINGO);

   // Any problems?
   if ( nError || dStatus != LS_STATUS_GLOBAL_LNG)
   {

      // Had a problem   
      printf( "Unable to solve!");

   } else {

      // Everything went OK ... print results
      printf( "\nStandards: %g \nTurbos: %g \nProfit: %g \n", 
       dProduce[0], dProduce[1], dObjective);
   }

   goto NormalExit;

ErrorExit:
   printf("LINGO Error Code: %d\n", nError);

NormalExit:
   LSdeleteEnvLng( pLINGO);

FinalExit: ;

}



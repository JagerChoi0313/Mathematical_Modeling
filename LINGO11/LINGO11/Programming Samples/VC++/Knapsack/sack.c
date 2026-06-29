#include <stdlib.h>
#include <string.h>

#include "..\..\lingd11.h"

/*
   Solves a simple knapsack problem, passing
   all data to Lingo and retrieving the optimal
   set of knapsack items for display
*/

void main()
{
   // input data for model:

   // potential items in knapsack
   char pcItems[256] = "ANT_REPEL \n BEER \n BLANKET \n" 
    "BRATWURST \n BROWNIES \n FRISBEE \n SALAD \n" 
    "WATERMELON";

   // and their weights
   double pdItemWeight[8] = { 1, 3, 4, 3, 3, 1, 5,10};

   // and their rankings
   double pdItemRank[8]   = { 2, 9, 3, 8,10, 6, 4,10};

   // knapsack size
   double dSackSize = 15;

   // other declarations
   int i, nPointersNow, nError;
   double dStatus=-1.0;
   char pcScript[256];
   char pcItemsSolution[256];

   // create the LINGO environment object
   pLSenvLINGO pLINGO;
   pLINGO = LScreateEnvLng();
   if ( !pLINGO) 
   {
      printf( "Can''t create LINGO environment!\n");
      goto FinalExit;
   }

   // Open LINGO's log file  
   nError = LSopenLogFileLng( pLINGO, "LINGO.log");
   if ( nError) goto ErrorExit;

   // Pass memory transfer pointers to LINGO

   // @POINTER(1) - Items set
   nError = LSsetPointerLng( pLINGO, (void*) pcItems, 
    &nPointersNow); 
   if ( nError) goto ErrorExit;

   // @POINTER(2) - Item weights
   nError = LSsetPointerLng( pLINGO, (void*) pdItemWeight, 
    &nPointersNow); 
   if ( nError) goto ErrorExit;

   // @POINTER(3) - Item ranks
   nError = LSsetPointerLng( pLINGO, (void*) pdItemRank, 
    &nPointersNow); 
   if ( nError) goto ErrorExit;

   // @POINTER(4) - Sack size
   nError = LSsetPointerLng( pLINGO, (void*) &dSackSize, 
    &nPointersNow); 
   if ( nError) goto ErrorExit;

   // @POINTER(5) - Output region for optimal items set
   nError = LSsetPointerLng( pLINGO, (void*) pcItemsSolution, 
    &nPointersNow); 
   if ( nError) goto ErrorExit;

   // @POINTER(6) - Variable to receive solution status
   nError = LSsetPointerLng( pLINGO, &dStatus, &nPointersNow); 
   if ( nError) goto ErrorExit;

   // Here is the script we want LINGO to run:
   //  Load the model, solve the model, exit.
   strcpy( pcScript, "TAKE SACK.LNG \n GO \n QUIT \n");

   // Run the script
   nError = LSexecuteScriptLng( pLINGO, pcScript);
   if ( nError) goto ErrorExit;
 
   // display solution status
   printf("\nSolution status (should be 0): %d\n", (int) dStatus);

   // display items in optimal sack
   printf("\nItems in optimal sack:\n%s\n", pcItemsSolution);

   // Close the log file
   LScloseLogFileLng( pLINGO);

   // All done
   goto NormalExit;

ErrorExit:
   printf("LINGO Error Code: %d\n", nError);

NormalExit:
   LSdeleteEnvLng( pLINGO);

FinalExit: ;

}



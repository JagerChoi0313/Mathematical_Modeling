
/**************************************************************
 This program calls the Lingo DLL to run a Lingo script file.  
 See Chapter 6, "Command-Line Commands" for more information 
 on Lingo's script language.  You may also enter:
 
    runlingo tran.ltf
 
 to run a small script that solves a transportation model.
***************************************************************/

#include <stdio.h>

#include "lingd11.h"

int main(int argc, char* argv[])
{
   int nError;
   char cScript[512];
	pLSenvLINGO pLINGO;

   // did we get a script file name?
   if ( !argv[ 1]) 
   {
      printf( "\nEnter \"runlingo script_file_path\" to execute the");
      printf( "\nLINGO command script in file script_file_path.\n");
      return( 0);
   }

   // Embed the script file in a TAKE command. Add a QUIT command
   //  in case they forgot!
   sprintf( cScript, "TAKE %s \n QUIT\n", argv[1]);

   // create the LINGO environment object
   pLINGO = LScreateEnvLng();
   if ( !pLINGO) 
   {
      printf( "Can''t create LINGO environment!\n");
      goto FinalExit;
   }

   //nError = LSopenLogFileLng( pLINGO, "lingo.log");
   //if ( nError) goto ErrorExit;

   // Run the script
   nError = LSexecuteScriptLng( pLINGO, cScript);
   if ( nError) goto ErrorExit;
 
   //nError = LScloseLogFileLng( pLINGO);
   //if ( nError) goto ErrorExit;

   goto NormalExit;

ErrorExit:
   printf("LINGO Error Code: %d\n", nError);

NormalExit:
   LSdeleteEnvLng( pLINGO);

FinalExit: ;
	return 0;
}

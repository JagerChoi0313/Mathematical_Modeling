using System;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.Remoting;

namespace Simple
{
    [StructLayout(LayoutKind.Sequential)]
    public class CallbackData
    {
        public int nIterations;

        // Constructor:    
        public CallbackData()
        {
            nIterations = 0;
        }
    }

    class Program
    {
		/// Illustrates calling the Lingo DLL from C#.NET to
		/// solve the simple product mix model:
		///    Max 100 Standard + 150 Turbo;
		///    S.T.
		///       Standard <= 100
		///       Turbo <= 120
		///       Standard + 2 * Turbo < 160;
		///      
		///  Note: The model template file, \lingo9\samples\simple.lng,
		///  must be present in order to run this example.
		///       

		[STAThread]
		static void Main(string[] args)
		{
            IntPtr pLingoEnv;
            int nError=-1, nPointersNow=-1;

            // define the transfer areas we'll use to pass data to and from Lingo
            double[] dProfit = new double[2];
            double[] dLimit = new double[2];
            double[] dLabor = new double[2];
            double[] dProduce = new double[2];
            double[] dObjective = new double[1];
            double[] dStatus = new double[1];

            // the model's data
            dProfit[0] = 100; dProfit[1] = 150;
            dLimit[0] = 100; dLimit[1] = 200;
            dLabor[0] = 1; dLabor[1] = 2;

            // Get a pointer to a Lingo environment
            pLingoEnv = lingo.LScreateEnvLng();
            if ( pLingoEnv == IntPtr.Zero)
            {
               Console.WriteLine( "Unable to create Lingo environment.\n");
               goto FinalExit;
            }

            // Open LINGO's log file  
            nError = lingo.LSopenLogFileLng( pLingoEnv, "lingo.log");
            if ( nError != lingo.LSERR_NO_ERROR_LNG) goto ErrorExit;

            // Let Lingo know we have a callback function
            CallbackData cbd = new CallbackData(); 
            lingo.typCallback cb = new lingo.typCallback( LngCallback.MyCallback);
            nError = lingo.LSsetCallbackSolverLng( pLingoEnv, cb, cbd);
            if ( nError != lingo.LSERR_NO_ERROR_LNG) goto ErrorExit;
            
            // Pass Lingo the pointer to the objective coefficients (refer
            // to the template model, simple.lng)
            nError = lingo.LSsetPointerLng(pLingoEnv, dProfit, ref nPointersNow);
            if (nError != lingo.LSERR_NO_ERROR_LNG) goto ErrorExit;

            // Pass a pointer to the production limits
            nError = lingo.LSsetPointerLng( pLingoEnv, dLimit, ref nPointersNow); 
            if ( nError != lingo.LSERR_NO_ERROR_LNG) goto ErrorExit;

            // Pointer to the labor utilization coefficients
            nError = lingo.LSsetPointerLng( pLingoEnv, dLabor, ref nPointersNow); 
            if ( nError != lingo.LSERR_NO_ERROR_LNG) goto ErrorExit;

            // Point to dObjective, where Lingo will return the objective value
            nError = lingo.LSsetPointerLng( pLingoEnv, dObjective, ref nPointersNow); 
            if ( nError != lingo.LSERR_NO_ERROR_LNG) goto ErrorExit;

            // Pointer to the solution status code
            nError = lingo.LSsetPointerLng( pLingoEnv, dStatus, ref nPointersNow); 
            if ( nError != lingo.LSERR_NO_ERROR_LNG) goto ErrorExit;

            // Point to the variable value array
            nError = lingo.LSsetPointerLng( pLingoEnv, dProduce, ref nPointersNow); 
            if ( nError != lingo.LSERR_NO_ERROR_LNG) goto ErrorExit;
               
            // Here is the script we want LINGO to run. 
            string cScript = 
             "set echoin 1 \n take \\lingo64_10\\samples\\simple.lng \n gen \n go \n quit \n";

            // Run the script
            nError = lingo.LSexecuteScriptLng( pLingoEnv, cScript);
            if ( nError != lingo.LSERR_NO_ERROR_LNG) goto ErrorExit;

            // Close the log file
            lingo.LScloseLogFileLng( pLingoEnv);

            // Any problems?
            if ( nError != 0 || 
             dStatus[0] != lingo.LS_STATUS_GLOBAL_LNG)
            {
                // Had a problem   
                Console.WriteLine( "Unable to solve!");
            } 
            else 
            {
                // Everything went OK ... print results
                Console.WriteLine( 
                 "\nStandards: {0} \nTurbos: {1} \n\nProfit: {2} \n", 
                 dProduce[0], dProduce[1], dObjective[0]);
            }

            goto NormalExit;

            ErrorExit:
               Console.WriteLine( "LINGO Error Code: {0}\n", nError);

            NormalExit:
               // Free Lingo's envvironment to avoid a memory leak
               lingo.LSdeleteEnvLng( pLingoEnv);

            FinalExit:
               Console.WriteLine("press enter...");
               String sTemp = Console.ReadLine();
        }

 	}

    public class LngCallback
    {
        public LngCallback()
        {
        }

        public static int MyCallback( IntPtr pLingoEnv, int nReserved, IntPtr pMyData)  
        {

           // Lingo callback function to display the current iteration count

           CallbackData cb = new CallbackData();
           Marshal.PtrToStructure( pMyData, cb);

           int nIterations=-1, nErr;
           nErr = lingo.LSgetCallbackInfoLng( pLingoEnv, 
            lingo.LS_IINFO_ITERATIONS_LNG, ref nIterations);
           if ( nErr == lingo.LSERR_NO_ERROR_LNG && nIterations != cb.nIterations)
           {
              cb.nIterations = nIterations;
              Console.WriteLine("Iteration count={0}", nIterations);
           }

           Marshal.StructureToPtr( cb, pMyData, true); 

           return 0;
        }
    }
}

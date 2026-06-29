import com.lindo.Lingd11;
import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import java.lang.Runtime;

class RunAThread extends Thread
{
   public int m_nThread;

   Object m_pnLngEnv;

   int m_nLastIterationCount;

   Lingd11 lng;

   public RunAThread(int nThread)
   {
      m_nThread = nThread;
   }

   // Load the Lingo JNI interface
   static
   {
      try { System.loadLibrary("Lingj11");
      } catch (Exception e) {
         System.out.println("Load Exception: " + e.toString());
         e.printStackTrace();
      }
   } 

   private static int MySolverCallback( Object pnLng, int iLoc, Object jobjMyObj)
   {
      RunAThread rt = (RunAThread) jobjMyObj;
      int nIterations[] = new int [1];

      rt.lng.LSgetCallbackInfoIntLng( pnLng, Lingd11.LS_IINFO_ITERATIONS_LNG, nIterations);
      if ( nIterations[0] >= rt.m_nLastIterationCount + 100)
      {
         rt.m_nLastIterationCount = nIterations[0];
	 System.out.println("In Solver Callback for thread: " + 
         rt.m_nThread + "   Iterations = " + rt.m_nLastIterationCount);
      }
      return( 0);
   }

   private static int MyErrorCallback( Object pnLng, int nErrorCode, String jsErrMessage, Object jobjMyObj)
   {
      RunAThread rt = (RunAThread) jobjMyObj;
 
      System.out.println("\nIn Error Callback for thread: " + rt.m_nThread);
      System.out.println("Lingo error code: " + nErrorCode);
      System.out.println("Lingo error message:\n\n " + jsErrMessage);
      return( 0);
   }

   public void run() {

      System.out.println("Thread: " + m_nThread + " ***BEGIN***");

      // Create a new Lingo object, which we will use to interface with Lingo
      this.lng = new Lingd11();

      // create the Lingo environment
      m_pnLngEnv = lng.LScreateEnvLng();
      if ( m_pnLngEnv == null)
      {
         System.out.println("Thread: " + m_nThread + " ***Unable to create Lingo environment***");
         return;
      }

      // open a Lingo log file
      int nErr = lng.LSopenLogFileLng( m_pnLngEnv, "lingo" + m_nThread + ".log");
      if ( nErr != lng.LSERR_NO_ERROR_LNG)
      {
         System.out.println("Thread: " + m_nThread + " ***LSopenLogFileLng() error***: " + nErr);
         return;
      }

      // pass Lingo the name of the solver callback function...
      nErr = lng.LSsetCallbackSolverLng( m_pnLngEnv, "MySolverCallback", this);
      if ( nErr != lng.LSERR_NO_ERROR_LNG)
      {
         System.out.println( "Thread: " + m_nThread + " ***LSsetCallbackSolverLng error***: " + nErr);
         return;
      }

      // ...and the error callback function
      nErr = lng.LSsetCallbackErrorLng( m_pnLngEnv, "MyErrorCallback", this);
      if ( nErr != lng.LSERR_NO_ERROR_LNG)
      {
         System.out.println( "Thread: " + m_nThread + " ***LSsetCallbackErrorLng error***: " + nErr);
         return;
      }

      // echo input to log file
      String sScript = "SET ECHOIN 1" + "\n";

      // load the model from disk
      sScript = sScript + "TAKE VROUTE.LNG" + "\n";

      // solve
      sScript = sScript + "GO" + "\n";

      // exit script processor
      sScript = sScript + "QUIT" + "\n";

      // run the script
      nErr = lng.LSexecuteScriptLng( m_pnLngEnv, sScript);
      if ( nErr != lng.LSERR_NO_ERROR_LNG )
      {
         System.out.println( "Thread: " + m_nThread + " ***LSexecuteScriptLng error***: " + nErr);
         return;
      }

      // close Lingo's log file
      nErr = lng.LScloseLogFileLng( m_pnLngEnv);
      if ( nErr != lng.LSERR_NO_ERROR_LNG )
      {
         System.out.println( "Thread: " + m_nThread + " ***LScloseLogFileLng() error***: " + nErr);
         return;
      }

      // delete the Lingo environment
      lng.LSdeleteEnvLng( m_pnLngEnv);

      System.out.println("Thread: " + m_nThread + " ***DONE***");
   }
}

class ThreadTest
{
   public static void main( String args[])
   {
      for (int i = 0; i < 10; i++)
      {
         new RunAThread( i).start();
      }
   }
}

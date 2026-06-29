import com.lindo.Lingd11;
import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import java.lang.Runtime;

public class Staff1 implements ActionListener
{
   // Load the Lingo JNI interface
   static {
      System.loadLibrary( "Lingj11");
   }

   // Create a new Lingo object, which we will use to interface with Lingo
   Lingd11 lng = new Lingd11();

   // Stores the Lingo JNI environment pointer
   Object pnLngEnv;

   JFrame f;
   JPanel p;
   JTextField jtfNeeds[] = new JTextField[ 7];
   JTextField jtfStart[] = new JTextField[ 7];
   JTextField jtfOnDuty[] = new JTextField[ 7];
   JTextField jtfTotal;
   JButton jbtnSolve = new JButton("Solve");
   JButton jbtnExit = new JButton("Exit");

   int nLastIterationCount;

   public Staff1()
   {

      // Create the frame and panel
      f = new JFrame("Lingo staffing example using Java");
      p = new JPanel();                          //  t   l   b   r
      p.setBorder( BorderFactory.createEmptyBorder( 30, 10, 30, 50));
      p.setLayout( new GridLayout(10, 4, 40, 20));

      // Add the widgets.
      addWidgets();

      // Add the panel to the frame.
      f.getContentPane().add( p, BorderLayout.CENTER);

      // Exit when the window is closed.
      f.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

      // Show the frame
      f.pack();
      f.setVisible(true);

      // no solver iterations performed yet;
      nLastIterationCount = -1;
 
   }

   private void addWidgets()
   {
      String sDays[] = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"};
      JLabel jl[] = new JLabel[ 7];

      // Row 1...the headers
      JLabel jlHdrDay = new JLabel( "Day:", JLabel.RIGHT);
      p.add( jlHdrDay);
      JLabel jlHdrNeeds = new JLabel( "Needs:", JLabel.RIGHT);
      p.add( jlHdrNeeds);
      JLabel jlHdrStart = new JLabel( "Start:", JLabel.RIGHT);
      p.add( jlHdrStart);
      JLabel jlHdrOnDuty = new JLabel( "On Duty:", JLabel.RIGHT);
      p.add( jlHdrOnDuty);

      // Rows 2-8...days of the week
      for ( int i = 0; i < 7; i++)
      {

         jl[ i] = new JLabel( sDays[ i], JLabel.RIGHT);
         p.add( jl[ i]);
         jtfNeeds[ i] = new JTextField( "0", 5);
         jtfNeeds[ i].setHorizontalAlignment( JTextField.RIGHT);
         p.add( jtfNeeds[ i]);
         jtfStart[ i] = new JTextField( "0", JLabel.RIGHT);
         jtfStart[ i].setEditable( false);
         jtfStart[ i].setHorizontalAlignment( JTextField.RIGHT);
         p.add( jtfStart[ i]);
         jtfOnDuty[ i] = new JTextField( "0", JLabel.RIGHT);
         jtfOnDuty[ i].setEditable( false);
         jtfOnDuty[ i].setHorizontalAlignment( JTextField.RIGHT);
         p.add( jtfOnDuty[ i]);

      }

      // Row 9...displays total of Start column
      JLabel jlNull1 = new JLabel( " ", JLabel.RIGHT);
      p.add( jlNull1);
      JLabel jlTotal = new JLabel( "Total...", JLabel.RIGHT);
      p.add( jlTotal);
      jtfTotal = new JTextField( "0", JLabel.RIGHT);
      jtfTotal.setEditable( false);
      jtfTotal.setHorizontalAlignment( JTextField.RIGHT);
      p.add( jtfTotal);
      JLabel jlNull3 = new JLabel( " ", JLabel.RIGHT);
      p.add( jlNull3);

      // Row 10...Solve and Exit buttons
      JLabel jlNull4 = new JLabel( " ", JLabel.RIGHT);
      p.add( jlNull4);
      JLabel jlNull5 = new JLabel( " ", JLabel.RIGHT);
      p.add( jlNull5);
      jbtnSolve.addActionListener( this);
      p.add( jbtnSolve);
      jbtnExit.addActionListener( this);
      p.add( jbtnExit);

   }

   // Implementation of ActionListener interface.
   public void actionPerformed( ActionEvent event)
   {
      Object source = event.getSource();

      if ( source == jbtnSolve)
      {
         Solve();
      } else {
         System.exit( 0);
      }
   }

   private static int MySolverCallback( Object pnLng, int iLoc, Object jobj)
   {
      Staff1 s = (Staff1) jobj;
      int nIterations[] = new int [1];
      s.lng.LSgetCallbackInfoIntLng( pnLng, Lingd11.LS_IINFO_ITERATIONS_LNG, nIterations);
      if ( nIterations[0] != s.nLastIterationCount)
      {
         s.nLastIterationCount = nIterations[0];
         System.out.println("In Java callback function...iterations = " + s.nLastIterationCount);
      }
      return( 0);
   }

   private static int MyErrorCallback( Object pnLng, int nErrorCode, String jsErrMessage, Object jobj)
   {
      System.out.println("Lingo error code: " + nErrorCode);
      System.out.println("Lingo error message:\n\n " + jsErrMessage);
      return( 0);
   }

   private void Solve()
   {

      int nErr;
      Double d1=0.;
      double dNeeds[] = new double[7];
      double dStart[] = new double [7];
      double dOnDuty[] = new double [7];
      double dObj[] = new double [1];
      double dStatus[] = new double [1];

      System.out.println("\nSolving...");
      
      // get the staffing requirements
      for ( int i=0; i<7; i++)
      {
         String s = jtfNeeds[i].getText();
         try {
            dNeeds[ i] = d1.valueOf( s);
         }
         catch ( Exception e)
         {
            dNeeds[ i] = 0.;
         }
      }
      
      // clear output fields
      for ( int i=0; i<7; i++)
      {
         jtfStart[i].setText( " ");
         jtfOnDuty[i].setText( " ");
      }
      jtfTotal.setText( " ");
      
      // create the Lingo environment
      pnLngEnv = lng.LScreateEnvLng();
      if ( pnLngEnv == null)
      {
         System.out.println( "***Unable to create Lingo environment***");
         return;
      }
      
      // open a log file
      nErr = lng.LSopenLogFileLng( pnLngEnv, "lingo.log");
      if ( nErr != lng.LSERR_NO_ERROR_LNG )
      {
         System.out.println( "***LSopenLogFileLng() error***: " + nErr);
         return;
      }
      
      // pass lingo a pointer to the staffing needs
      int[] nPointersNow = new int[1];
	  nErr = lng.LSsetPointerLng( pnLngEnv, dNeeds, nPointersNow);
      if ( nErr != lng.LSERR_NO_ERROR_LNG )
      {
         System.out.println( "***LSsetPointerLng() error***: " + nErr);
         return;
      }
      
      // pass pointers to output areas
	  nErr = lng.LSsetPointerLng( pnLngEnv, dStart, nPointersNow);
      if ( nErr != lng.LSERR_NO_ERROR_LNG )
      {
         System.out.println( "***LSsetPointerLng() error***: " + nErr);
         return;
      }
	  nErr = lng.LSsetPointerLng( pnLngEnv, dOnDuty, nPointersNow);
      if ( nErr != lng.LSERR_NO_ERROR_LNG )
      {
         System.out.println( "***LSsetPointerLng() error***: " + nErr);
         return;
      }
	  nErr = lng.LSsetPointerLng( pnLngEnv, dObj, nPointersNow);
      if ( nErr != lng.LSERR_NO_ERROR_LNG )
      {
         System.out.println( "***LSsetPointerLng() error***: " + nErr);
         return;
      }
	  nErr = lng.LSsetPointerLng( pnLngEnv, dStatus, nPointersNow);
      if ( nErr != lng.LSERR_NO_ERROR_LNG )
      {
         System.out.println( "***LSsetPointerLng() error***: " + nErr);
         return;
      }
      
      // pass Lingo the name of the solver callback function...
      nErr = lng.LSsetCallbackSolverLng( pnLngEnv, "MySolverCallback", this);
      
      // ...and the error callback function
      nErr = lng.LSsetCallbackErrorLng( pnLngEnv, "MyErrorCallback", this);
      
      // construct the script
      
      // echo input to log file
      String sScript = "SET ECHOIN 1" + "\n";
      
      // load the model from disk
      sScript = sScript + "TAKE STAFFPTR.LNG" + "\n";
      
      // view the formulation
      sScript = sScript + "LOOK ALL" + "\n";
      
      // solve
      sScript = sScript + "GO" + "\n";
      
      // exit script processor
      sScript = sScript + "QUIT" + "\n";
      
      // run the script
      dStatus[0] = -1;
      nLastIterationCount = -1;
	  nErr = lng.LSexecuteScriptLng( pnLngEnv, sScript);
      if ( nErr != lng.LSERR_NO_ERROR_LNG )
      {
         System.out.println( "***LSexecuteScriptLng error***: " + nErr);
         return;
      }
      
      // clear the pointers to force update of local arrays
      // ***NOTE*** solution won't get passed to local arrays until
      // LSclearPointersLng is called!!!
	  nErr = lng.LSclearPointersLng( pnLngEnv);
      if ( nErr != lng.LSERR_NO_ERROR_LNG )
      {
         System.out.println( "***LSclearPointerLng() error***: " + nErr);
         return;
      }
      
      // check the solution status
      if ( dStatus[0] != lng.LS_STATUS_GLOBAL_LNG) 
       System.out.println( "***Unable to Solve*** dStatus:" + dStatus[0]);
      
      // close Lingo's log file
	  nErr = lng.LScloseLogFileLng( pnLngEnv);
      if ( nErr != lng.LSERR_NO_ERROR_LNG )
      {
         System.out.println( "***LScloseLogFileLng() error***: " + nErr);
         return;
      }
	  
      // delete the Lingo environment
      lng.LSdeleteEnvLng( pnLngEnv);
      
      // post the solution
      Integer nTotal = 0;
      for ( int i=0; i<7; i++)
      {
         Double d = dStart[i];
         Integer n = d.intValue(); 
         jtfStart[i].setText( n.toString());
         nTotal = nTotal + n;
      
         d = dOnDuty[i];
         n = d.intValue();
         jtfOnDuty[i].setText( n.toString());
      }
      jtfTotal.setText( nTotal.toString());
    
      //System.out.println( "free Java memory: " +  Runtime.getRuntime().freeMemory());
   }

   // main method
   public static void main(String[] args) {
      Staff1 s = new Staff1();
   }

}


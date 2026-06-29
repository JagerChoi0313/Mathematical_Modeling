
      program CallLINGO
!
! Sample FORTRAN program that calls the LINGO DLL to solve:
!
!    MAX=20*X+30*Y;
!    X<30;
!    Y<50;
!    X+2*Y<120;
!
      implicit none

      include 'lingd11.fi'

      integer pLINGO, nError, nPointers, nothin
      real*8 dObj, dX, dY, dStatus
      character*256 cScript

      external MyCallback
      
	nError = -1
      dStatus = -1

! Create a LINGO environment object
      pLINGO = LScreateEnvLng()
      if ( pLINGO .eq. 0) go to 9001

! Open up LINGO's log file
      nError = LSopenLogFileLng( pLINGO, "lingo.log");
      if ( nError .ne. 0) go to 9001

! Establish pointers for transferring data to/from LINGO
      nError = LSsetPointerLng( pLINGO, dObj, nPointers)
      if ( nError .ne. 0) go to 9001

      nError = LSsetPointerLng( pLINGO, dX, nPointers)
      if ( nError .ne. 0) go to 9001

      nError = LSsetPointerLng( pLINGO, dY, nPointers)
      if ( nError .ne. 0) go to 9001

      nError = LSsetPointerLng( pLINGO, dStatus, nPointers)
      if ( nError .ne. 0) go to 9001

! Pass Lingo a pointer to our callback function
      nError = LSsetCallbackSolverLng( pLINGO, 
     + loc( MyCallback), nothin)

! Build the command script
      cScript = 'SET ECHOIN 1' // char(10) //
     + 'MODEL:' // char(10) //
     + '[OBJECTIVE] MAX=20*X+30*Y;' // char(10) //
     + 'X<30;' // char(10) //
     + 'Y<50;' // char(10) //
     + 'X+2*Y<120;' // char(10) //
     + 'DATA:' // char(10) //
     + '@POINTER( 1) = OBJECTIVE;' // char(10) //
     + '@POINTER( 2) = X;' // char(10) //
     + '@POINTER( 3) = Y;' // char(10) //
     + '@POINTER( 4) = @STATUS();' // char(10) //
     + 'ENDDATA' // char(10) //
     + 'END' // char(10) //
     + 'GO' // char(10) //
     + 'QUIT' // char(10)

! Pass the command script to LINGO for execution
      nError = LSexecuteScriptLng( pLINGO, cScript)

! Test for any errors
      if ( nError .ne. 0 .or. 
     + dStatus .ne. LS_STATUS_GLOBAL_LNG) then

         type *, "Unable to solve!"

      else

! Display the solution
         write(6,*) 'Objective =', dObj
         write(6,*) 'X =', dX
         write(6,*) 'Y =', dY

      endif

! Close the log file
      nError = LScloseLogFileLng( pLINGO);
      if ( nError .ne. 0) go to 9001

      go to 9100

 9001 continue
      write( 6, *) 'LINGO Error Code: ', nError
      go to 9999

 9100 continue

! Delete the LINGO environment
      call LSdeleteEnvLng( pLINGO);

      pause 'Press Enter ...'

 9999 continue
      end

      integer function MyCallback( pLINGO, nReserved, pMyData)

      implicit none

      integer pLINGO, nReserved, pMyData

      !type *, "in callback"

      MyCallback = 0

      return
      end


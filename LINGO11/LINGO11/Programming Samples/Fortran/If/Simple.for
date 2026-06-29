cdec$ if defined (OS_WIN)
cdec$ attributes stdcall, alias:'lingcallback'::lingcallback
cdec$ endif

      program CallLINGO

      implicit none
!
! Sample Intel FORTRAN program that calls the LINGO DLL to solve:
!
!  MAX     100 STANDARD + 150 TURBO
!  SUBJECT TO
!  2]  STANDARD <=   100
!  3]  TURBO <=   120
!  4]  STANDARD + 2 TURBO <=   160
!  END
!
cdec$ if defined (BIT_64)
      include 'lingd64_11.fi'
cdec$ else
      include 'lingd11.fi'
cdec$ endif

      integer nError, nPointers, nCallbacks
      real*8 dProfit(2), dBounds(2), dLabor(2), dProduce(2)
      real*8 dStatus, dObj
      character*16 cComputers(3)
      character*256 cScript

      data dProfit /100., 150./
      data dBounds /100., 120./
      data dLabor  /1., 2./

      real*8 dComputerNamesPtr
      equivalence( dComputerNamesPtr, cComputers)

      external lingcallback

cdec$ if defined (BIT_64)
      integer*8 nFncPtr, pLINGO
cdec$ else
      integer nFncPtr, pLINGO
cdec$ endif

! Load computer names
      cComputers( 1) = 'STANDARD' // char( 13)
      cComputers( 2) = 'TURBO' // char( 13)
      cComputers( 3) = char( 0)

      nError = -1
      dStatus = -1

! Create a LINGO environment object
      pLINGO = LScreateEnvLng()
      if ( pLINGO .eq. 0) go to 9001

! Open up LINGO's log file
      nError = LSopenLogFileLng( pLINGO, "lingo.log");
      if ( nError .ne. 0) go to 9001

! Establish pointers for transferring data to/from LINGO
      nError = LSsetPointerLng( pLINGO, dProfit( 1), nPointers)
      if ( nError .ne. 0) go to 9001

      nError = LSsetPointerLng( pLINGO, dBounds( 1), nPointers)
      if ( nError .ne. 0) go to 9001

      nError = LSsetPointerLng( pLINGO, dLabor( 1), nPointers)
      if ( nError .ne. 0) go to 9001

      nError = LSsetPointerLng( pLINGO, dObj, nPointers)
      if ( nError .ne. 0) go to 9001

      nError = LSsetPointerLng( pLINGO, dStatus, nPointers)
      if ( nError .ne. 0) go to 9001

      nError = LSsetPointerLng( pLINGO, dProduce( 1), nPointers)
      if ( nError .ne. 0) go to 9001

      nError = LSsetPointerLng( pLINGO, dComputerNamesPtr, nPointers)
      if ( nError .ne. 0) go to 9001

! Establish pointer to the callback routine
      nFncPtr = loc( lingcallback)
      nCallbacks = 0
      nError = LSsetCallbackSolverLng( pLINGO, nFncPtr, nCallbacks)
      if ( nError .ne. 0) go to 9001

! Build the command script
      cScript = 'SET ECHOIN 1' // char(10) //
     + 'TAKE simple.lng' // char(10) //
     + 'GO' // char(10) //
     + 'QUIT' // char(10)

! Log header
      type *, '   Callbacks       Iters      Objective'

! Pass the command script to LINGO for execution
      nError = LSexecuteScriptLng( pLINGO, cScript)

! Test for any errors
      if ( nError .ne. 0 .or. 
     + dStatus .ne. LS_STATUS_GLOBAL_LNG) then

         type *, "Unable to solve!"

      else

! Display the solution
         type *, ' '
         type *, 'Objective =', dObj
         type *, 'Standards =', dProduce( 1)
         type *, 'Turbos    =', dProduce( 2)
         type *, ' '
         type *, 'See lingo.log for more details.'
         type *, ' '

      endif

! Close the log file
      nError = LScloseLogFileLng( pLINGO);
      if ( nError .ne. 0) go to 9001

      go to 9100

 9001 continue
      type *, 'LINGO Error Code: ', nError
      go to 9999

 9100 continue

! Delete the LINGO environment
      
      nError = LSdeleteEnvLng( pLINGO);

      pause ' Press Enter ...'

 9999 continue
      end

cdec$ if defined (OS_WIN)
cdec$ attributes stdcall, alias:'lingcallback'::lingcallback
cdec$ endif

      integer function lingcallback( nLingoPtr, nReserved, nCallbacks)

      implicit none

cdec$ if defined (BIT_64)
      include 'lingd64_11.fi'
      integer*8 nLingoPtr [value]
cdec$ else
      include 'lingd11.fi'
      integer nLingoPtr [value]
cdec$ endif

      integer nCallbacks [reference], nReserved [reference]

      integer nIters, nErr

      real*8 dObj

      nCallbacks = nCallbacks + 1

      nErr = LSgetCallbackInfoIntLng( nLingoPtr, 
     + LS_IINFO_ITERATIONS_LNG, nIters)

      nErr = LSgetCallbackInfoDoubleLng( nLingoPtr, 
     + LS_DINFO_OBJECTIVE_LNG, dObj)

      if ( MOD( nCallbacks, 10) .eq. 0) 
     + type *, nCallbacks, nIters, max( 0.d0, dObj)
 
      lingcallback = 0

      return
      end
      
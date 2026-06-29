Subroutine MyUser( nParms, dArgList, dResult)

!MS$ATTRIBUTES DLLEXPORT :: MyUser

!MS$ATTRIBUTES ALIAS: "MYUSER" :: MyUser

!MS$ATTRIBUTES C :: MyUser

!MS$ATTRIBUTES Reference :: nParms, dResult

implicit none

Integer nParms

Double Precision dArgList( nParms), dResult

!Eliminates a compiler warning:
nParms = nParms

dResult = sqrt( dArgList( 1))

Return

End  


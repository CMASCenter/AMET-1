C***********************************************************************
C   Portions of Models-3/CMAQ software were developed or based on      *
C   information from various groups: Federal Government employees,     *
C   contractors working on a United States Government contract, and    *
C   non-Federal sources (including research institutions).  These      *
C   research institutions have given the Government permission to      *
C   use, prepare derivative works, and distribute copies of their      *
C   work in Models-3/CMAQ to the public and to permit others to do     *
C   so.  EPA therefore grants similar permissions for use of the       *
C   Models-3/CMAQ software, but users are requested to provide copies  *
C   of derivative works to the Government without restrictions as to   *
C   use by others.  Users are responsible for acquiring their own      *
C   copies of commercial software associated with Models-3/CMAQ and    *
C   for complying with vendor requirements.  Software copyrights by    *
C   the MCNC Environmental Modeling Center are used with their         *
C   permissions subject to the above restrictions.                     *
C***********************************************************************

C*************************************************************************
C
C  FUNCTION: Gets avg concentration for each grid cell
C             
C                   
C*************************************************************************
      SUBROUTINE GET_GRIDVAL( GRIDVAL,VNAME, N )

      USE M3FILES
      USE ENV_VARS
      USE GRID_DATA
      USE TIME_STEP

      USE M3UTILIO 

      IMPLICIT NONE     

C..ARGUMENTS:
      INTEGER N
      CHARACTER*16 VNAME

      REAL GRIDVAL( M3GRID % NCOLS, M3GRID % NROWS )


C..PARAMETERS: None
      

C..EXTERNAL FUNCTIONS:

C..SAVED LOCAL VARIABLES: None

C..SCRATCH LOCAL VARIABLES:
      CHARACTER*16    PNAME        ! Program Name
      CHARACTER*80    MSG          ! Error message

      INTEGER    ESTEP        ! Last time step for averaging
      INTEGER    JDATE        ! Time step date, coded YYYYDDD
      INTEGER    JTIME        ! Time step time, coded HHMMSS
      INTEGER    JFILE        ! No. of file containing jdate & jtime 
      INTEGER    AVG_TIME
      INTEGER    NAVG         ! Loop index   

C..SAVED LOCAL VARIABLES:
      LOGICAL   LFIRST
      SAVE      LFIRST

      REAL, SAVE, ALLOCATABLE :: CHOUR( : , :, : )

   
C**********************************************************************
      DATA PNAME / 'GET_GRIDVAL' /
      DATA LFIRST / .TRUE. /
      DATA AVG_TIME / 1 /


      IF( AVG_TIME .EQ. 1 ) THEN

         JDATE = STEP_DATE( N )
         JTIME = STEP_TIME( N )
         JFILE = STEP_FILE( N )


         IF( .NOT. READ3( M3_FLNAME( JFILE ) , VNAME, 1, JDATE, 
     &                    JTIME, GRIDVAL( 1, 1 ) ) ) THEN
            MSG = 'Could not read input Models-3 file ' //
     &             M3_FLNAME( JFILE )         
            CALL M3ERR( PNAME, JDATE, JTIME, MSG, .TRUE. )
         ENDIF

         RETURN

      ELSE

         IF( LFIRST ) THEN

c..allocate array and read first n values
            ALLOCATE( CHOUR( M3GRID % NCOLS, M3GRID % NROWS, AVG_TIME ) )

            DO NAVG = 1, AVG_TIME

               JDATE = STEP_DATE( NAVG )
               JTIME = STEP_TIME( NAVG )
               JFILE = STEP_FILE( NAVG )

               IF( .NOT. READ3( M3_FLNAME( JFILE ) , VNAME, 1, JDATE, 
     &                          JTIME, CHOUR( 1, 1, NAVG ) ) ) THEN
                  MSG = 'Could not read input Models-3 file ' //
     &                   M3_FLNAME( JFILE )         
                  CALL M3ERR( PNAME, JDATE, JTIME, MSG, .TRUE. )
               ENDIF


            ENDDO

            LFIRST = .FALSE.

         ELSE


c..drop the first hour and add an hour at the end
            DO NAVG = 2, AVG_TIME
               CHOUR( : , : , NAVG - 1 ) = CHOUR( : , : , NAVG ) 
            ENDDO

            ESTEP = N + AVG_TIME - 1

            JDATE = STEP_DATE( ESTEP )
            JTIME = STEP_TIME( ESTEP )
            JFILE = STEP_FILE( ESTEP )

            IF( .NOT. READ3( M3_FLNAME( JFILE ) , VNAME, 1, JDATE, 
     &                       JTIME, CHOUR( 1, 1, AVG_TIME ) ) ) THEN
               MSG = 'Could not read input Models-3 file ' //
     &               M3_FLNAME( JFILE )         
               CALL M3ERR( PNAME, JDATE, JTIME, MSG, .TRUE. )
            ENDIF

         ENDIF


c..comput the n-hour average
         GRIDVAL = ( SUM ( CHOUR( : , : , 1 : AVG_TIME ) , DIM = 3 ) ) /
     &               FLOAT( AVG_TIME )


      ENDIF

      RETURN
 
      END

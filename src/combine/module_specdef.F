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

C RCS file, release, date & time of last delta, author, state, [and locker]
C $Header: /project/work/rep/TOOLS/src/combine/module_specdef.F,v 1.1.1.1 2005/07/27 12:55:20 sjr Exp $

C***********************************************************************
C  module to read, process and store the species definitions
C***********************************************************************

      Module spec_def

      Integer, Parameter, Private :: EXP_LEN = 1024
      Integer, Parameter, Private :: REC_LEN = EXP_LEN * 2
        
      Integer numSpec
      Integer maxSpec

      Integer Klayer
      Integer startDate, startTime
      Integer endDate, endTime
      
      CHARACTER*(16), Allocatable ::  specName(:)
      CHARACTER*(16), Allocatable :: specUnits(:)
      CHARACTER*(EXP_LEN), Allocatable :: specExpression(:)
      CHARACTER*(EXP_LEN), Allocatable :: specDesc(:)

      Contains

cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c  subroutine to read and load SPECFILE
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      Subroutine readSpec( specFile, status )

      USE M3UTILIO

      IMPLICIT NONE

      ! arguments
      CHARACTER*(*) specFile
      Integer status

      ! define external functions
      Integer getFldCount

      ! local variables
      Integer lfn
      Integer iostatus
      Character*(REC_LEN) record
      Character*(REC_LEN) NextRecord
      Character*(REC_LEN) field
      Character*(1) del
      Integer nflds
      Integer lenRec

      lfn = 20
      startDate = 0
      startTime = 0
      endDate = 0
      Klayer = -1
      numSpec = 0
      maxSpec = MXVARS3

      ! allocate species arrays
      if( .not. Allocated(specName) ) then
        Allocate( specName(maxSpec) )
        Allocate( specUnits(maxSpec) )
        Allocate( specExpression(maxSpec) )
        Allocate( specDesc(maxSpec) )
        endif
      
      ! open species definition file and fill arrays
      OPEN( UNIT=lfn, FILE=specFile, STATUS='OLD', IOSTAT=status)
      if( status.ne.0 ) return

      ! start read loop
      Do

        READ( lfn, '(a)', IOSTAT=iostatus ) RECORD
        IF( iostatus.ne.0 ) EXIT

        ! check for cr character at end of line, and remove it if found
        lenRec = LEN_TRIM(record) 
        if( record(lenRec:lenRec) .eq. char(13) ) record(lenRec:lenRec) = ' '

        ! check for blank line
        IF ( RECORD .eq. ' ' ) CYCLE

        ! check for comment line
        IF ( index( '!/', RECORD(1:1) ) .gt. 0 ) CYCLE

        ! Check for parameter values
        IF ( RECORD( 1:1 ) .EQ. '#' ) THEN
          field = RECORD(2:8)
          CALL UCASE(field)
          IF ( field( 1:5 ) .EQ. 'START' )
     &      READ( RECORD(7:), *, IOSTAT=status ) startDate, startTime
          IF ( field( 1:3 ) .EQ. 'END' )
     &      READ( RECORD(5:), *, IOSTAT=status ) endDate, endTime
          IF ( field( 1:5 ) .EQ. 'LAYER' )
     &      READ( RECORD(7:), *, IOSTAT=status ) Klayer

          if( status.ne.0 ) then
            Write(*,'(''Invalid parameter record:'',a)') trim(record)
            return 
            endif

          CYCLE
          ENDIF

C...check for old specdef format
        if( index(record, ',').eq.0 .and. index(record, '=').eq.30) then
          Write(*,'(/''**Warning** Invalid Record,'',
     &               '' Trying old Format''/)')
          Call readOld(lfn, status)
          return
          endif

C...append any continuation records 
        DO
          ! check for '\' character at end of line
          lenRec = LEN_TRIM(record) 
          if( record(lenRec:lenRec) .eq. char(92) ) then
            READ( lfn, '(a)', IOSTAT=iostatus ) NEXTRECORD
            if( iostatus.ne.0 ) then
              Write(*,'(''**ERROR** EOF reading continuation record'')')
              EXIT
              endif
            Call LeftTrim( NEXTRECORD )
          
            ! check for record length exceeded
            if( (lenRec + LEN_TRIM(NEXTRECORD)) .ge. REC_LEN ) then
              Write(*,'(//,''**ERROR** The maximum record length exceeded'')')
              Write(*,'(/,''  Species name ='',a)') record(1:16)
              Write(*,'(''  Maximum length ='',i8)') REC_LEN
              Write(*,'(''  Record length = '',i8)') lenRec + LEN_TRIM(NEXTRECORD)
              Stop
              endif

            ! append NEXTRECORD to record
            record = record(1:lenRec-1) // ' ' // TRIM(NEXTRECORD)

            ! check for cr character at end of line, and remove it if found
            lenRec = LEN_TRIM(record)  
            if( record(lenRec:lenRec) .eq. char(13) ) record(lenRec:lenRec) = ' ' 

           else
            EXIT
            endif
          Enddo 
        if( iostatus.ne.0 ) EXIT          


C...check for species line
        nflds = getFldCount(record, ',')
        if( nflds.lt.3 ) then
          Write(*,'(''Invalid record found:'',a)') trim(record)
          Stop
          endif

        ! check for maximum species count
        if(numSpec.eq.maxSpec) then
          Write(*,'(''**ERROR** the number of species exceeds maximum'')')
          Stop 
          endif
 
        ! save species line in arrays
        numSpec = numSpec+1         

        call getFld( record, ',', 1, del, specName(numSpec) ) 
        call getFld( record, ',', 2, del, specUnits(numSpec) ) 
        call getFld( record, ',', 3, del, field ) 
        specExpression(numSpec) = field
        call getFld( record, ',', 4, del, specDesc(numSpec) ) 
        if( specDesc(numSpec).eq.' ' ) specDesc(numSpec) = specExpression(numSpec)
      
        ! check if expression field is too long
        if( LEN_TRIM( field) .gt. EXP_LEN ) then 
          Write(*,'(//,''**ERROR** The maximum expression length exceeded'')')
          Write(*,'(/,''  Species name ='',a)') TRIM( specName(numSpec) )
          Write(*,'(''  Maximum length ='',i8)') EXP_LEN
          Write(*,'(''  Expression length = '',i8)') LEN_TRIM(field)
          Stop
          endif 
         
        enddo     

      ! close file and return
      close(unit=lfn)
      return
      End Subroutine readSpec 


cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c  subroutine to read using old SPECFILE format
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      Subroutine readOld( lfn, status )
      
      IMPLICIT NONE

      ! arguments
      Integer lfn
      Integer status

      ! local variables 
      character*(256) record
      Integer iostatus, reclen
      character*(16) field1    ! new variable name
      character*(16) field2    ! variable units
      character*(1)  field3    ! operator symbol
      character*(8)  field4    ! muliply factor
      character*(1)  field5    ! input file number
      character*(16) field6    ! input variable
      character*(70) field7    ! description
      Logical isnew
      character*(EXP_LEN) express


      backspace lfn

      ! start read loop
      Do

        READ( lfn, '(a)', IOSTAT=iostatus ) RECORD
        IF( iostatus.ne.0 ) EXIT

        ! check for comment line
        IF ( index( '!/#', RECORD(1:1) ) .gt. 0 ) CYCLE

        ! check for blank line
        reclen = LEN_TRIM( RECORD)
        if( reclen .le. 2 ) CYCLE

        if( RECORD(reclen:reclen).lt.' ') then
          RECORD(reclen:reclen) = ' '
          if( LEN_TRIM( RECORD) .eq. 0 ) CYCLE
          endif

        Call readRec(record, field1, field2, field3, field4,
     &               field5, field6, field7, status)
        if(status .ne. 0) then
          write(*,'(''<<---- Invalid species record ---->>'')')
          write(*,'(''>>'',a,''<<'',//)') trim(record)
          return
          endif

        Call LeftTrim( field4 )  ! left trim number field

        !determine if record has new variable 
        ISNEW = (LEN_TRIM(field1) .gt. 0)

        if( ISNEW ) then
          IF ( numSpec .EQ. maxSpec ) return
          numSpec = numSpec + 1

          specName(numSpec) = field1
          specUnits(numSpec) = field2
          specExpression(numSpec) = '(' // TRIM(field4) // '*'
     &                // TRIM(field6) // '[' // field5 // '])'
          specDesc(numSpec) = field7
          cycle
          endif

        ! if no specName defined cycle
        if( numSpec .EQ. 0 ) cycle

        ! add to previous species expression
        express = field3 // '(' // TRIM(field4) // '*'
     &                // TRIM(field6) // '[' // field5 // ']))'
        specExpression(numSpec) = '(' // TRIM(specExpression(numSpec))
     &                            // TRIM(express)

        enddo   

       ! generate new specfile using new format
       Call genNewFile()

      return
      end Subroutine readOld


C***********************************************************************
C  routine to read variable record, (formated or unformatted)
C***********************************************************************
      Subroutine readRec(record, field1, field2, field3, field4,
     &    field5, field6, field7, status)

      ! arguments
      character*(*) record
      character*(*) field1    ! new variable name
      character*(*) field2    ! variable units
      character*(*) field3    ! operator symbol
      character*(*) field4    ! muliply factor
      character*(*) field5    ! input file number
      character*(*) field6    ! input variable
      character*(*) field7    ! description
      integer status

      ! local variables
      logical ISFMT
      Real factor
      Integer stat, kfile
      character*(1) del


      status = 0

      !determine if record is formatted or unformatted
      ISFMT = .TRUE.     
      if( index('=+-*/',record(30:30)).eq.0 ) ISFMT = .FALSE.
      if( index(record(1:58),',').gt. 0 ) ISFMT = .FALSE.

      ! get input files from record
      if( ISFMT ) then 
        field1 = record(2:17)
        field2 = record(19:28)
        field3 = record(30:30)
        field4 = record(32:39)
        field5 = record(41:41)
        field6 = record(43:58)
        field7 = record(60:129)
       else
        Call getFld( record, ',', 1, del, field1 )
        Call getFld( record, ',', 2, del, field2 )
        Call getFld( record, ',', 3, del, field3 )
        Call getFld( record, ',', 4, del, field4 )
        Call getFld( record, ',', 5, del, field5 )
        Call getFld( record, ',', 6, del, field6 )
        Call getFld( record, ',', 7, del, field7 )
        endif

      ! verify fields
      if( index('=+*/',field3) .eq. 0 ) status = 3
      read(field4,'(f8.0)',iostat=stat) factor
      if( stat.ne.0 ) status = 4
      read(field5,'(I1)',iostat=stat) kfile
      if( stat.ne.0 ) status = 5
      if( LEN_TRIM(field6) .eq. 0 ) status = 6

      return
      end Subroutine readRec
 


cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c  subroutine to generate new SPECFILE from ioapi file
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      Subroutine genSpec( SpecFile )
   
      USE M3UTILIO
   
      IMPLICIT NONE

C...  arguments
      Character*(*) SpecFile

C...  local variables
      INTEGER STATUS
      INTEGER lfn
      INTEGER I
      LOGICAL KSWIT
      CHARACTER*1 REPLACE 
      CHARACTER*16 FNAME

C...open variable definition file
      lfn = 20
      
      OPEN( UNIT=lfn, FILE=SpecFile, STATUS='NEW', IOSTAT=status )
      If(status.ne.0) then

        Write(*,'(/''SPECDEF file: ['',a,
     &        ''] cannot be opened as "NEW"'')') TRIM(SpecFile)
        Write(*,'(''Do you want to replace existing? (Y/N) '',$)')
        Read(*,'(a)') replace
        if( replace.ne.'Y' .and. replace.ne.'y' ) return

        OPEN( UNIT=lfn, FILE=SpecFile, IOSTAT=status )
        if( status.ne.0 ) then
          Write(*,'(/''**ERROR** cannot open SPECDEF file: ['',a,
     &          '']'')') TRIM(SpecFile)
          return
          endif
        endif
 
C...open input file 1
      FNAME='INFILE1'
      IF ( .NOT. OPEN3( FNAME, 1, 'GENSPEC' ) ) THEN
        WRITE( *, '('' Error opening Input Data file:'',A)' ) FNAME
        GO TO 999
      END IF

C...fill Description Common Block
      IF ( .NOT.  DESC3( FNAME ) ) THEN
        WRITE( *, '(''**Error** While running DESC3 on '',A)' ) FNAME
        GO TO 999
      END IF

      write(lfn,'(''/#start   YYYYDDD  HHMMSS'')')
      write(lfn,'(''/#end     YYYYDDD  HHMMSS'')')
      write(lfn,'(''/#layer      KLAY     (default is all layers)'')')
      write(lfn,'(''/'')')
      write(lfn,'(''/new species,    units,     expression,   description'')')

      DO I = 1, NVARS3D
        Write(lfn,'(/a16,'','',a16,'','',a,''[1]'','', '',a)')
     &     VNAME3D(I), UNITS3D(I), TRIM(VNAME3D(I)),TRIM(VDESC3D(I))
      END DO


      Write(*,'(/''SpecDef file: ['',a,''] Generated''/)')TRIM(SpecFile)

C... shut down netcdf and return
999   CONTINUE
      CLOSE( unit=lfn )
      KSWIT = SHUT3()
      Return
      END Subroutine genSpec


cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c  subroutine to generate new SPECFILE from array data
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      Subroutine genNewFile()
   
      USE M3UTILIO
   
      IMPLICIT NONE

C...  local variables
      Character*(256) specFile
      INTEGER STATUS
      INTEGER lfn
      INTEGER n
      CHARACTER*1 REPLACE 

C...open variable definition file
      lfn = 21
      specFile = 'specdef.new'
      
      OPEN( UNIT=lfn, FILE=SpecFile, STATUS='NEW', IOSTAT=status )
      If(status.ne.0) then

        Write(*,'(/''New SPECDEF file: ['',a,
     &        ''] cannot be opened as "NEW"'')') TRIM(SpecFile)
        Write(*,'(''Do you want to replace existing? (Y/N) '',$)')
        Read(*,'(a)') replace
        if( replace.ne.'Y' .and. replace.ne.'y' ) return

        OPEN( UNIT=lfn, FILE=SpecFile, IOSTAT=status )
        if( status.ne.0 ) then
          Write(*,'(/''**ERROR** cannot open new SPECDEF file: ['',
     &            a,'']'')') TRIM(SpecFile)
          return
          endif
        endif

      ! write header record
      if( startDate.gt.0 ) then
        write(lfn,'(''#start'',2i10)') startDate, startTime
       else
        write(lfn,'(''/#start   YYYYDDD  HHMMSS'')')
        endif

      if( endDate.gt.0 ) then
        write(lfn,'(''#end  '',2i10)') endDate, endTime
       else
        write(lfn,'(''/#end     YYYYDDD  HHMMSS'')')
        endif
 
      if( klayer.gt.0 ) then
        write(lfn,'(''#layer'',i10)') klayer
       else
        write(lfn,'(''/#layer      KLAY     (default is all layers)'')')
        endif

      write(lfn,'(''/'')')
      write(lfn,'(''/new species    ,units     ,expression'')')

      do n = 1, numSpec
        Write(lfn,'(/a16,'', '',a16,'', '',a,'', '',a)')
     &     specName(n), specUnits(n), TRIM(specExpression(n)), TRIM(specDesc(n))
       enddo

      close(unit=lfn)

      write(*,'(/''-->New specdef file:['',a,
     &       ''] generated from old format''/)') trim(specFile)

      return 
      END Subroutine genNewFile

      End Module spec_def

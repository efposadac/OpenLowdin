      PROGRAM SYM4TR
!----------------------------------------------------------------------
!  DESCRIPTION : This routine 
!                is main program of symmetry adapted four-index 
!                integral transformation.
!  AUTHORS :     Shigeyoshi YAMAMOTO and Umpei NAGASHIMA (2003)
!  RELEASE :     v.01  gen = S.Yamamoto (sya) 2003-03-29 at chukyo-u
!----------------------------------------------------------------------
!  Files
!     FT71 : inf.dat / old / sequential / unformatted 
!     FT72 : mocoef.dat / old / sequential / unformatted / 
!     FT73 : soint.dat / old / sequential / unformatted /
!     FT74 : moint.dat / new / sequential / unformatted /
!
!     FT91 : work / direct / unformatted / ordering bin-1
!     FT92 : work / direct / unformatted / ordering bin-2
!     FT93 : work / sequential / unformatted / ordering control data
!     FT94 : work / sequential / unformatted / da2s
!     FT95 : work / direct / unformatted / half-transformed integrals
!----------------------------------------------------------------------
!  Data flow
!     ordering step (WTO*)
!       FT73: SO integrals generated by prepar.exe
!         -> 1st stage of ordering
!       FT91: work direct file (bin-1)
!         -> 2nd stage of ordering
!       FT92: work direct file (bin-2)
!
!     merge step  (WTS*)
!       FT94: work sequential file 
!
!     transformation step (WTH*)
!       FT95: half-transformed integrals, direct-access file
!       FT74: final transformed integrals, sequential file 
!
!----------------------------------------------------------------------
      IMPLICIT NONE
      INCLUDE 'declar.h'
      INCLUDE 'sym4tr.h'
!
!     ...memory size
!
      INTEGER,PARAMETER :: LDMB = 800 ! MB
      INTEGER,PARAMETER :: LDBYTE = LDMB * 10**6 ! Byte
      INTEGER,PARAMETER :: LD8BYT = LDBYTE/LDREAL ! 8-Byte
!
!     ...allocate big array by COMMON
!
      REAL(KIND=LDREAL),DIMENSION(LD8BYT) :: BIGARY
      COMMON/BIGARY/BIGARY
!
!----------------------------------------------------------------------
      CALL WMINIT
!
!
      CALL WMINPT(25, 1D-10, 1D-10, 1D-10)
!
!     ...check consistency of input data and save them
!
      CALL WMINFO

!     ...set integral file and mo coefficient file
!
      CALL WMFILE(LD8BYT,BIGARY)
!
!     ...check block-diagonality of MO matrix
!
      CALL WMCHKD(LD8BYT,BIGARY)

!     ...set control data
!
      CALL WTINIT
!
!     ...ordering SO integrals
!
      CALL WTODRV(LD8BYT,BIGARY)
!
!     ...copy ordered SO integrals from direct access file into 
!        sequential file
!
      CALL WTSDRV(LD8BYT,BIGARY)
!
!     ...integral transformation
!
      CALL WTHDRV(LD8BYT,BIGARY)
!
!      CALL PRCPUT('SYM4TR ended',0)
!
      END PROGRAM

!!******************************************************************************
!!	This code is part of LOWDIN Quantum chemistry package                 
!!	
!!	this program has been developed under direction of:
!!
!!	  UNIVERSIDAD NACIONAL DE COLOMBIA"
!!	  PROF. ANDRES REYES GROUP"
!!	  http://www.qcc.unal.edu.co"
!!	
!!	  UNIVERSIDAD DE GUADALAJARA"
!!	  PROF. ROBERTO FLORES GROUP"
!!	  http://www.cucei.udg.mx/~robertof"
!!	
!!	AUTHORS
!!		E.F. POSADA. UNIVERSIDAD NACIONAL DE COLOMBIA
!!   		S.A. GONZALEZ. UNIVERSIDAD NACIONAL DE COLOMBIA
!!   		F.S. MONCADA. UNIVERSIDAD NACIONAL DE COLOMBIA
!!   		J. ROMERO. UNIVERSIDAD NACIONAL DE COLOMBIA
!!
!!	CONTRIBUTORS
!!		N.F.AGUIRRE. UNIVERSIDAD NACIONAL DE COLOMBIA
!!   		GABRIEL MERINO. UNIVERSIDAD DE GUANAJUATO
!!   		J.A. CHARRY UNIVERSIDAD NACIONAL DE COLOMBIA
!!
!!
!!		Todos los derechos reservados, 2011
!!
!!******************************************************************************
                
module ConfigurationInteraction_
  use Exception_
  use Matrix_
  use Vector_
!  use MolecularSystem_
  use Configuration_
  use ReadTransformedIntegrals_
  use MolecularSystem_
  use String_
  use IndexMap_
  use InputCI_
  use omp_lib
  use ArpackInterface_
  implicit none
      
  !>
  !! @brief Configuration Interaction Module, works in spin orbitals
  !!
  !! @author felix
  !!
  !! <b> Creation data : </b> 07-24-12
  !!
  !! <b> History change: </b>
  !!
  !!   - <tt> 07-24-12 </tt>: Felix Moncada ( fsmoncadaa@unal.edu.co )
  !!        -# description.
  !!   - <tt> 07-09-16 </tt>: Jorge Charry ( jacharrym@unal.edu.co )
  !!        -# Add CIS, and Fix CISD.
  !!   - <tt> MM-DD-YYYY </tt>:  authorOfChange ( email@server )
  !!        -# description
  !!
  !<
  type, public :: ConfigurationInteraction
     logical :: isInstanced
     type(matrix) :: hamiltonianMatrix
     type(matrix) :: hamiltonianMatrix2
     type(ivector8) :: auxIndexCIMatrix
     type(matrix) :: eigenVectors
     type(matrix) :: initialEigenVectors
     type(vector8) :: initialEigenValues
     integer(8) :: numberOfConfigurations
     type(ivector) :: numberOfOccupiedOrbitals
     type(ivector) :: numberOfOrbitals
     type(vector) ::  numberOfSpatialOrbitals2 
     type(vector8) :: eigenvalues
     type(vector) :: lambda !!Number of particles per orbital, module only works for 1 or 2 particles per orbital
     type(matrix), allocatable :: fourCenterIntegrals(:,:)
     type(matrix), allocatable :: twoCenterIntegrals(:)
     type(matrix), allocatable :: FockMatrix(:)
     type(imatrix), allocatable :: twoIndexArray(:)
     type(imatrix), allocatable :: fourIndexArray(:)
     type(vector), allocatable :: energyofmolecularorbitals(:)
     type(imatrix), allocatable :: strings(:) !! species, conf, occupations
     type(ivector1), allocatable :: auxstring(:) !! species, occupations
     type(ivector8), allocatable :: numberOfStrings(:) !! species, excitation level, number of strings
     type(imatrix1), allocatable :: couplingMatrix(:)
     type(ivector1), allocatable :: couplingVector(:)
     type(ivector), allocatable :: couplingZero(:)
     type(imatrix), allocatable :: couplingOneTwo(:)
     type(imatrix) :: auxConfigurations !! species, configurations for initial hamiltonian
     integer, allocatable :: excitationLevel(:) !! species
     type(configuration), allocatable :: configurations(:)
     integer(2), allocatable :: auxconfs(:,:,:) ! nconf, species, occupation
     type (Vector8) :: diagonalHamiltonianMatrix
     type (Vector8) :: diagonalHamiltonianMatrix2
     real(8) :: totalEnergy
     integer, allocatable :: totalNumberOfContractions(:)
     integer, allocatable :: occupationNumber(:)
     type (Matrix) :: initialHamiltonianMatrix
     type (Matrix) :: initialHamiltonianMatrix2
     character(20) :: level
     integer :: maxCILevel

  end type ConfigurationInteraction

  type, public :: HartreeFock
        real(8) :: totalEnergy
        real(8) :: puntualInteractionEnergy
        type(matrix) :: coefficientsofcombination 
        type(matrix) :: HcoreMatrix 
  end type HartreeFock
  
  integer, allocatable :: Conf_occupationNumber(:)
  type(ConfigurationInteraction) :: ConfigurationInteraction_instance
  type(HartreeFock) :: HartreeFock_instance

  public :: &
       ConfigurationInteraction_constructor, &
       ConfigurationInteraction_destructor, &
       ConfigurationInteraction_getTotalEnergy, &
       ConfigurationInteraction_run, &
       ConfigurationInteraction_diagonalize, &
       ConfigurationInteraction_naturalOrbitals, &
       ConfigurationInteraction_show

  private

contains


  !>
  !! @brief Constructor por omision
  !!
  !! @param this
  !<
  subroutine ConfigurationInteraction_constructor(level)
    implicit none
    character(*) :: level

    integer :: numberOfSpecies
    integer :: i,j,k,l,m,n,p,q,cc,r,s,el
    integer(8) :: c
    integer :: ma,mb,mc,md,me,pa,pb,pc,pd,pe
    integer :: isLambdaEqual1,lambda,otherlambda
    type(vector) :: occupiedCode
    type(vector) :: unoccupiedCode
    real(8) :: totalEnergy

    character(50) :: wfnFile
    integer :: wfnUnit
    character(50) :: nameOfSpecie
    integer :: numberOfContractions
    character(50) :: arguments(2)

    wfnFile = "lowdin.wfn"
    wfnUnit = 20

    !! Open file for wavefunction
    open(unit=wfnUnit, file=trim(wfnFile), status="old", form="unformatted")

    !! Load results...
    call Vector_getFromFile(unit=wfnUnit, binary=.true., value=HartreeFock_instance%totalEnergy, &
         arguments=["TOTALENERGY"])
    call Vector_getFromFile(unit=wfnUnit, binary=.true., value=HartreeFock_instance%puntualInteractionEnergy, &
         arguments=["PUNTUALINTERACTIONENERGY"])

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()


    do i=1, numberOfSpecies
        nameOfSpecie= trim(  MolecularSystem_getNameOfSpecie( i ) )
        numberOfContractions = MolecularSystem_getTotalNumberOfContractions( i )

        arguments(2) = nameOfSpecie
        arguments(1) = "HCORE"
        HartreeFock_instance%HcoreMatrix  = &
                  Matrix_getFromFile(unit=wfnUnit, rows= int(numberOfContractions,4), &
                  columns= int(numberOfContractions,4), binary=.true., arguments=arguments(1:2))

        arguments(1) = "COEFFICIENTS"
        HartreeFock_instance%coefficientsofcombination = &
                  Matrix_getFromFile(unit=wfnUnit, rows= int(numberOfContractions,4), &
                  columns= int(numberOfContractions,4), binary=.true., arguments=arguments(1:2))
    end do

    ConfigurationInteraction_instance%isInstanced=.true.
    ConfigurationInteraction_instance%level=level
    ConfigurationInteraction_instance%numberOfConfigurations=0

    call Vector_constructorInteger (ConfigurationInteraction_instance%numberOfOccupiedOrbitals, numberOfSpecies)
    call Vector_constructorInteger (ConfigurationInteraction_instance%numberOfOrbitals, numberOfSpecies)
    call Vector_constructor (ConfigurationInteraction_instance%lambda, numberOfSpecies)
    call Vector_constructor (ConfigurationInteraction_instance%numberOfSpatialOrbitals2, numberOfSpecies)


    if  ( allocated (ConfigurationInteraction_instance%strings ) ) &
    deallocate ( ConfigurationInteraction_instance%strings )
    allocate ( ConfigurationInteraction_instance%strings ( numberOfSpecies ) )

    if  ( allocated (ConfigurationInteraction_instance%auxstring ) ) &
    deallocate ( ConfigurationInteraction_instance%auxstring )
    allocate ( ConfigurationInteraction_instance%auxstring ( numberOfSpecies ) )

    if  ( allocated (ConfigurationInteraction_instance%couplingMatrix ) ) &
    deallocate ( ConfigurationInteraction_instance%couplingMatrix )
    allocate ( ConfigurationInteraction_instance%couplingMatrix ( numberOfSpecies ) )

    if  ( allocated (ConfigurationInteraction_instance%couplingVector ) ) &
    deallocate ( ConfigurationInteraction_instance%couplingVector )
    allocate ( ConfigurationInteraction_instance%couplingVector ( numberOfSpecies ) )

    if  ( allocated (ConfigurationInteraction_instance%couplingZero ) ) &
    deallocate ( ConfigurationInteraction_instance%couplingZero )
    allocate ( ConfigurationInteraction_instance%couplingZero ( numberOfSpecies ) )

    if  ( allocated (ConfigurationInteraction_instance%couplingOneTwo ) ) &
    deallocate ( ConfigurationInteraction_instance%couplingOneTwo )
    allocate ( ConfigurationInteraction_instance%couplingOneTwo ( numberOfSpecies ) )

    if  ( allocated (ConfigurationInteraction_instance%numberOfStrings ) ) &
    deallocate ( ConfigurationInteraction_instance%numberOfStrings )
    allocate ( ConfigurationInteraction_instance%numberOfStrings ( numberOfSpecies ) )

    if  ( allocated (ConfigurationInteraction_instance%excitationLevel ) ) &
    deallocate ( ConfigurationInteraction_instance%excitationLevel )
    allocate ( ConfigurationInteraction_instance%excitationLevel ( numberOfSpecies ) )
    ConfigurationInteraction_instance%excitationLevel = 0

    if ( allocated ( ConfigurationInteraction_instance%totalNumberOfContractions ) ) &
    deallocate ( ConfigurationInteraction_instance%totalNumberOfContractions ) 
    allocate ( ConfigurationInteraction_instance%totalNumberOfContractions (numberOfSpecies ) )

    if ( allocated ( ConfigurationInteraction_instance%occupationNumber ) ) &
    deallocate ( ConfigurationInteraction_instance%occupationNumber ) 
    allocate ( ConfigurationInteraction_instance%occupationNumber (numberOfSpecies ) )

    if ( allocated ( Conf_occupationNumber ) ) &
    deallocate ( Conf_occupationNumber ) 
    allocate ( Conf_occupationNumber (numberOfSpecies ) )


    do i=1, numberOfSpecies
       !! We are working in spin orbitals not in spatial orbitals!
       ConfigurationInteraction_instance%lambda%values(i) = MolecularSystem_getLambda( i )
       ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i)= int (MolecularSystem_getOcupationNumber( i )* ConfigurationInteraction_instance%lambda%values(i))
       ConfigurationInteraction_instance%numberOfOrbitals%values(i)=MolecularSystem_getTotalNumberOfContractions( i )* ConfigurationInteraction_instance%lambda%values(i)
       ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(i) = MolecularSystem_getTotalNumberOfContractions( i )
       ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(i) = &
         ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(i) *  ( &
         ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(i) + 1 ) / 2

      
       ConfigurationInteraction_instance%totalNumberOfContractions( i ) = MolecularSystem_getTotalNumberOfContractions( i )
       ConfigurationInteraction_instance%occupationNumber( i ) = int( MolecularSystem_instance%species(i)%ocupationNumber )
       Conf_occupationNumber( i ) =  MolecularSystem_instance%species(i)%ocupationNumber
      !! Take the active space from input
      if ( InputCI_Instance(i)%activeOrbitals /= 0 ) then
        ConfigurationInteraction_instance%numberOfOrbitals%values(i) = InputCI_Instance(i)%activeOrbitals * &
                                    ConfigurationInteraction_instance%lambda%values(i)

      end if

       !!Uneven occupation number = alpha
       !!Even occupation number = beta     
    end do

    call Configuration_globalConstructor()

    select case ( trim(level) )

    case ( "CIS" )

      !!Ground State
      ConfigurationInteraction_instance%maxCILevel = 1
      c=1

      do i=1, numberOfSpecies

        call Vector_constructorInteger8 (ConfigurationInteraction_instance%numberOfStrings(i), 1_8 + 1_8, 0_8)
        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        cc = 0 
        !!Singles
        if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then

          el = 1 + 1 !! ground + singles
          ConfigurationInteraction_instance%excitationLevel(i) = el
          call Vector_constructorInteger8 (ConfigurationInteraction_instance%numberOfStrings(i), int(el,8), 0_8)

          do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
            do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
              !!if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                c=c+1
                cc = cc + 1
              !!end if
            end do
          end do
        end if
        ConfigurationInteraction_instance%numberOfStrings(i)%values(el) = ConfigurationInteraction_instance%numberOfStrings(i)%values(el) + cc
      end do

      ConfigurationInteraction_instance%numberOfConfigurations = c
      allocate (ConfigurationInteraction_instance%configurations(ConfigurationInteraction_instance%numberOfConfigurations) )

      call Matrix_Constructor(ConfigurationInteraction_instance%hamiltonianMatrix, int(ConfigurationInteraction_instance%numberOfConfigurations,8),int(ConfigurationInteraction_instance%numberOfConfigurations,8),0.0_8)


    case ( "CISD" )

       ConfigurationInteraction_instance%maxCILevel = 2
       !!Ground State
       c=1

       do i=1, numberOfSpecies
          call Vector_constructorInteger8 (ConfigurationInteraction_instance%numberOfStrings(i), (2_8 + 1_8), 0_8) !! ground + singles + doubles
          ConfigurationInteraction_instance%numberOfStrings(i)%values(0+1) = ConfigurationInteraction_instance%numberOfStrings(i)%values(0+1) + 1
       end do

       do i=1, numberOfSpecies

          cc = 0
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
          !!Singles
          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then
             do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )

                   !!if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                     c = c + 1
                     cc = cc + 1
                   !!end if
                end do
             end do
          end if

        ConfigurationInteraction_instance%numberOfStrings(i)%values(1+1) = ConfigurationInteraction_instance%numberOfStrings(i)%values(1+1) + cc

       end do

       do i=1, numberOfSpecies
   !!Doubles of the same specie
          cc = 0
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
          if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
             do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                do n=m+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   do p= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                      !if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                        do q=p+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                   !do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                      !!if ( mod(m,lambda) == mod(p,lambda) .and.  mod(n,lambda) == mod(q,lambda)  ) then !! alpha -> alpha, beta -> beta

                             c = c + 1
                             cc = cc + 1
                      !!end if
                        end do

                   end do
                end do
             end do
          end if
          ConfigurationInteraction_instance%numberOfStrings(i)%values(2+1) = ConfigurationInteraction_instance%numberOfStrings(i)%values(2+1) + cc

       end do !! species

       do i=1, numberOfSpecies
          !!Doubles of different species
          do j=i+1, numberOfSpecies
             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
                do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                   do n=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                      do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                         do q= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                            c=c+1
                         end do
                      end do
                   end do
                end do
             end if
          end do


       end do !! species

       ConfigurationInteraction_instance%numberOfConfigurations = c
       allocate (ConfigurationInteraction_instance%configurations(ConfigurationInteraction_instance%numberOfConfigurations) )

       if ( trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) /= "ARPACK" .and. &
        trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) /= "JADAMILU"  ) then

         call Matrix_Constructor(ConfigurationInteraction_instance%hamiltonianMatrix, &
                int(ConfigurationInteraction_instance%numberOfConfigurations,8), & 
                int(ConfigurationInteraction_instance%numberOfConfigurations,8),0.0_8)

       end if

    case ( "CIDD" )

       !!Count
       
       !!Ground State
       c=1

       do i=1, numberOfSpecies
          call Vector_constructorInteger8 (ConfigurationInteraction_instance%numberOfStrings(i), 2_8, 0_8)
       end do

       do i=1, numberOfSpecies
   !!Doubles of the same specie
          cc = 0
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
          if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
             do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                do n=m+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   do p= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                      !if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                        do q=p+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                   !do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                      !!if ( mod(m,lambda) == mod(p,lambda) .and.  mod(n,lambda) == mod(q,lambda)  ) then !! alpha -> alpha, beta -> beta

                             c=c+1
                             cc = cc + 1
                      !!end if
                        end do

                   end do
                end do
             end do
          end if

          ConfigurationInteraction_instance%numberOfStrings(i)%values(2) = ConfigurationInteraction_instance%numberOfStrings(i)%values(2) + cc
       end do !! species

       do i=1, numberOfSpecies
          !!Doubles of different species
          do j=i+1, numberOfSpecies
             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
                do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                   do n=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                      do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                         do q= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                            c=c+1
                         end do
                      end do
                   end do
                end do
             end if
          end do


       end do !! species

       ConfigurationInteraction_instance%numberOfConfigurations = c
       allocate (ConfigurationInteraction_instance%configurations(ConfigurationInteraction_instance%numberOfConfigurations) )

       if ( trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) /= "ARPACK" .and. &
        trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) /= "JADAMILU"  ) then


         call Matrix_Constructor(ConfigurationInteraction_instance%hamiltonianMatrix, &
                int(ConfigurationInteraction_instance%numberOfConfigurations,8), & 
                int(ConfigurationInteraction_instance%numberOfConfigurations,8),0.0_8)

       end if

    case ( "FCI" )

  !!Count
       
       !!Ground State
       c=1

       do i=1, numberOfSpecies
          call Vector_constructorInteger8 (ConfigurationInteraction_instance%numberOfStrings(i), (2_8 + 1_8), 0_8) !! ground + singles + doubles
          ConfigurationInteraction_instance%numberOfStrings(i)%values(0+1) = ConfigurationInteraction_instance%numberOfStrings(i)%values(0+1) + 1
       end do

       do i=1, numberOfSpecies
          cc = 0
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
          !!Singles
          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then
             do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )

                   !!if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                     c=c+1
                     cc = cc + 1
                   !!end if
                end do
             end do
          end if

          ConfigurationInteraction_instance%numberOfStrings(i)%values(1+1) = ConfigurationInteraction_instance%numberOfStrings(i)%values(1+1) + cc
       end do


       do i=1, numberOfSpecies
   !!Doubles of the same specie
          cc = 0
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
          if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
             do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                do n=m+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   do p= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                        do q=p+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                     !! if ( mod(m,lambda) == mod(p,lambda) .and.  mod(n,lambda) == mod(q,lambda) .and. (p /= q) ) then !! alpha -> alpha, beta -> beta

                             c=c+1
                             cc = cc + 1
                     !! end if
                        end do

                   end do
                end do
             end do
          end if

          ConfigurationInteraction_instance%numberOfStrings(i)%values(2+1) = ConfigurationInteraction_instance%numberOfStrings(i)%values(2+1) + cc
          !!Doubles of different species
          do j=i+1, numberOfSpecies
             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
                do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                   do n=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                      do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                         do q= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                            c=c+1
                         end do
                      end do
                   end do
                end do
             end if
          end do

   !!triples of diff specie
          do j=i+1, numberOfSpecies
             do k=j+1, numberOfSpecies

             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. & 
                ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 .and. &
                ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
                do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                   do n=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                      do r=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )
                      do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                         do q= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                         do s= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(k))
                            c=c+1
                         end do
                      end do
                         end do
                      end do
                   end do
                end do
             end if
                         end do
          end do


       end do !! species

       ConfigurationInteraction_instance%numberOfConfigurations = c
       allocate (ConfigurationInteraction_instance%configurations(ConfigurationInteraction_instance%numberOfConfigurations) )


       if ( trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) /= "ARPACK" .and. &
        trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) /= "JADAMILU"  ) then

       call Matrix_Constructor(ConfigurationInteraction_instance%hamiltonianMatrix, int(ConfigurationInteraction_instance%numberOfConfigurations,8),int(ConfigurationInteraction_instance%numberOfConfigurations,8),0.0_8)
        end if

    case ( "CISDT" )

      !!Ground State
      c=1

      do i=1, numberOfSpecies
          call Vector_constructorInteger8 (ConfigurationInteraction_instance%numberOfStrings(i), 3_8, 0_8)
       end do

      do i=1, numberOfSpecies
        cc = 0
        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        !!Singles (1)
        if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then
          do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
            do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
              int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
              !!if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                c=c+1
                cc = cc + 1
              !!end if
            end do
          end do
        end if
        
          ConfigurationInteraction_instance%numberOfStrings(i)%values(1) = ConfigurationInteraction_instance%numberOfStrings(i)%values(1) + cc
       end do

      !!Doubles of the same specie (2)
       do i=1, numberOfSpecies
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         cc = 0
         if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
           do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
             do n=m+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
               do p= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                 do q=p+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                   !!if ( mod(m,lambda) == mod(p,lambda) .and.  mod(n,lambda) == mod(q,lambda) .and. (p /= q) ) then !! alpha -> alpha, beta -> beta
                     c=c+1
                     cc = cc + 1
                   !!end if
                 end do
               end do
             end do
           end do
         end if
          ConfigurationInteraction_instance%numberOfStrings(i)%values(2) = ConfigurationInteraction_instance%numberOfStrings(i)%values(2) + cc
       end do !! species

       !!Doubles of different species (11)
       do i=1, numberOfSpecies
         do j=i+1, numberOfSpecies
            if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
               do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do n=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                     do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                        do q= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                           c=c+1
                        end do
                     end do
                  end do
               end do
            end if
         end do
       end do !! species


       !!Triples of the same specie (3)
       do i=1, numberOfSpecies
         cc = 0
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 3 ) then
           do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
             do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
               do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                 do pa= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                         int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                   do pb=pa+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                     do pc=pb+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                     !!  if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                     !!      mod(mb,lambda) == mod(pb,lambda) .and. &
                     !!      mod(mc,lambda) == mod(pc,lambda) ) then !! alpha -> alpha, beta -> beta
                            c=c+1
                            cc = cc + 1
                     !!  end if
                     end do
                   end do
                 end do
               end do
             end do
           end do
         end if
          ConfigurationInteraction_instance%numberOfStrings(i)%values(3) = ConfigurationInteraction_instance%numberOfStrings(i)%values(3) + cc
       end do !! species


       !!Triples (21) 
       do i=1, numberOfSpecies
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         do j=1, numberOfSpecies
           if ( j /= i ) then
             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
                .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
               do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                 do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                   do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                     do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                            int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                       do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                         do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, &
                           int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                         !!  if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                         !!       mod(mb,lambda) == mod(pb,lambda) .and. &
                         !!       mod(mc,lambda) == mod(pc,lambda) )  then !! alpha -> alpha, beta -> beta
                             c=c+1
                         !!  end if
                         end do
                       end do
                     end do  
                   end do
                 end do
               end do
             end if
           end if
         end do

       end do !! species


      !!Triples (111)
       do i=1, numberOfSpecies
         do j=i+1, numberOfSpecies
           do k=j+1, numberOfSpecies
             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. & 
               ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 .and. &
               ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
               do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                 do n=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                   do r=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )
                     do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                       do q= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                         do s= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(k))
                           c=c+1
                         end do
                       end do
                     end do
                   end do
                 end do
               end do
             end if
           end do
         end do

       end do !! species

       ConfigurationInteraction_instance%numberOfConfigurations = c
       allocate (ConfigurationInteraction_instance%configurations(ConfigurationInteraction_instance%numberOfConfigurations) )

       if ( trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) /= "ARPACK" .and. &
        trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) /= "JADAMILU"  ) then

       call Matrix_Constructor(ConfigurationInteraction_instance%hamiltonianMatrix, int(ConfigurationInteraction_instance%numberOfConfigurations,8),int(ConfigurationInteraction_instance%numberOfConfigurations,8),0.0_8)
        end if

    case ( "CISDTQ" )

      !!Ground State
      c=1

      do i=1, numberOfSpecies
          call Vector_constructorInteger8 (ConfigurationInteraction_instance%numberOfStrings(i), 4_8, 0_8)
      end do

      do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        cc = 0
        !!Singles (1)
        if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then
          do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
            do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
              int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
             !! if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                c=c+1
                cc = cc + 1
             !! end if
            end do
          end do
          ConfigurationInteraction_instance%numberOfStrings(i)%values(1) = ConfigurationInteraction_instance%numberOfStrings(i)%values(1) + cc
        end if
        
       end do

      !!Doubles of the same specie (2)
       do i=1, numberOfSpecies
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         cc = 0
         if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
           do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
             do n=m+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
               do p= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                 do q=p+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
               !!    if ( mod(m,lambda) == mod(p,lambda) .and.  mod(n,lambda) == mod(q,lambda) .and. (p /= q) ) then !! alpha -> alpha, beta -> beta
                     c=c+1
                     cc = cc + 1
               !!    end if
                 end do
               end do
             end do
           end do
         end if
          ConfigurationInteraction_instance%numberOfStrings(i)%values(2) = ConfigurationInteraction_instance%numberOfStrings(i)%values(2) + cc
       end do !! species

       !!Doubles of different species (11)
       do i=1, numberOfSpecies
         do j=i+1, numberOfSpecies
            if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
               do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do n=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                     do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                        do q= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                           c=c+1
                        end do
                     end do
                  end do
               end do
            end if
         end do
       end do !! species


       !!Triples of the same specie (3)
       do i=1, numberOfSpecies

         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         cc = 0
         if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 3 ) then
           do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
             do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
               do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                 do pa= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                         int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                   do pb=pa+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                     do pc=pb+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                    !!   if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                    !!       mod(mb,lambda) == mod(pb,lambda) .and. &
                    !!       mod(mc,lambda) == mod(pc,lambda) ) then !! alpha -> alpha, beta -> beta
                            c=c+1
                            cc = cc + 1
                    !!   end if
                     end do
                   end do
                 end do
               end do
             end do
           end do
         end if
          ConfigurationInteraction_instance%numberOfStrings(i)%values(3) = ConfigurationInteraction_instance%numberOfStrings(i)%values(3) + cc
       end do !! species


       !!Triples (21) 
       do i=1, numberOfSpecies
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         do j=1, numberOfSpecies
           if ( j /= i ) then
             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
                .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
               do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                 do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                   do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                     do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                            int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                       do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                         do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, &
                           int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                       !!    if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                       !!         mod(mb,lambda) == mod(pb,lambda) .and. &
                       !!         mod(mc,lambda) == mod(pc,lambda) )  then !! alpha -> alpha, beta -> beta
                             c=c+1
                       !!    end if
                         end do
                       end do
                     end do  
                   end do
                 end do
               end do
             end if
           end if
         end do

       end do !! species


      !!Triples (111)
       do i=1, numberOfSpecies
         do j=i+1, numberOfSpecies
           do k=j+1, numberOfSpecies
             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. & 
               ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 .and. &
               ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
               do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                 do n=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                   do r=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )
                     do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                       do q= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                         do s= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(k))
                           c=c+1
                         end do
                       end do
                     end do
                   end do
                 end do
               end do
             end if
           end do
         end do

       end do !! species

       !!Quadruples of the same species (4)
       do i=1, numberOfSpecies
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         cc = 0
         if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 4 ) then
           do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
             do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
               do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                 do md=mc+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   do pa= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                           int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                     do pb=pa+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                       do pc=pb+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                         do pd=pc+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                         !!  if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                         !!      mod(mb,lambda) == mod(pb,lambda) .and. &
                         !!      mod(mc,lambda) == mod(pc,lambda) .and. &
                         !!      mod(md,lambda) == mod(pd,lambda) ) then !! alpha -> alpha, beta -> beta
                                c=c+1
                                cc = cc + 1
                         !!  end if
                         end do
                       end do
                     end do
                   end do
                 end do
               end do
             end do
           end do
          ConfigurationInteraction_instance%numberOfStrings(i)%values(4) = ConfigurationInteraction_instance%numberOfStrings(i)%values(4) + cc
         end if

       end do !! species

       !!Quadruples (31)
       do i=1, numberOfSpecies

         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         do j=1, numberOfSpecies
           if ( j /= i ) then
             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 3 &
                .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
                do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                    do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                      do md=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                        do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                               int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                          do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                            do pc=pb+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                              do pd= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, &
                                int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                           !!     if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                           !!          mod(mb,lambda) == mod(pb,lambda) .and. &
                           !!          mod(mc,lambda) == mod(pc,lambda) .and. &
                           !!          mod(md,lambda) == mod(pd,lambda) )  then !! alpha -> alpha, beta -> beta
                                  c=c+1
                           !!     end if
                              end do
                            end do
                          end do
                        end do  
                      end do  
                    end do
                  end do
                end do
             end if
           end if
         end do

       end do !! species

       !!Quadruples (22)
       do i=1, numberOfSpecies
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         do j=i+1, numberOfSpecies
           otherlambda=ConfigurationInteraction_instance%lambda%values(j) !Particles per orbital
           if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
              .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 2 ) then
              do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                    do md=mc+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                      do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                             int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                        do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                          do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1,&
                             int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                            do pd=pc+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                             !! if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                             !!      mod(mb,lambda) == mod(pb,lambda) .and. &
                             !!      mod(mc,otherlambda) == mod(pc,otherlambda) .and. &
                             !!      mod(md,otherlambda) == mod(pd,otherlambda) )  then !! alpha -> alpha, beta -> beta
                                c=c+1
                             !! end if
                            end do
                          end do
                        end do
                      end do  
                    end do  
                  end do
                end do
              end do
           end if
         end do

       end do !! species

       !!quadruples of diff specie (1111)
       do i=1, numberOfSpecies
         if ( numberOfSpecies > 3 ) then
          do j=i+1, numberOfSpecies
            do k=j+1, numberOfSpecies
              do l=k+1, numberOfSpecies

                if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. & 
                   ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 .and. &
                   ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 .and. &
                   ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(l) .ge. 1 ) then
                  do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                    do mb=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                      do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )
                        do md=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(l) )
                          do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                            do pb= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                              do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(k))
                                do pd= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(l))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(l))
                                  c=c+1
                                end do
                              end do
                            end do
                          end do
                        end do
                      end do
                    end do
                  end do

                end if

              end do
            end do
          end do
        end if

       end do !! species

       !!Quadruples (211)
       do i=1, numberOfSpecies
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         do j=1, numberOfSpecies
           if ( j /= i ) then
             do k=j+1, numberOfSpecies
               if ( k /= j .and. k /=i ) then
                 if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
                    .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 &
                    .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
                   do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                     do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                       do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                         do md=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )
                           do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                                  int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                             do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                               do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1,&
                                  int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                                 do pd= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1,&
                                    int(ConfigurationInteraction_instance%numberOfOrbitals%values(k) )
                               !!    if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                               !!         mod(mb,lambda) == mod(pb,lambda) .and. &
                               !!         mod(mc,lambda) == mod(pc,lambda) .and. &
                               !!         mod(md,lambda) == mod(pd,lambda) )  then !! alpha -> alpha, beta -> beta
                                     c=c+1
                               !!    end if
                                 end do
                               end do
                             end do
                           end do  
                         end do  
                       end do
                     end do
                   end do
                 end if
               end if
             end do
           end if
         end do

      end do !! species

       ConfigurationInteraction_instance%numberOfConfigurations = c
       allocate (ConfigurationInteraction_instance%configurations(ConfigurationInteraction_instance%numberOfConfigurations) )

       if ( trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) /= "ARPACK" .and. &
        trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) /= "JADAMILU"  ) then

       call Matrix_Constructor(ConfigurationInteraction_instance%hamiltonianMatrix, int(ConfigurationInteraction_instance%numberOfConfigurations,8),int(ConfigurationInteraction_instance%numberOfConfigurations,8),0.0_8)
        end if


    case ( "CISDTQQ" )

      !!Ground State
      c=1

      do i=1, numberOfSpecies
          call Vector_constructorInteger8 (ConfigurationInteraction_instance%numberOfStrings(i), 5_8, 0_8)
      end do

      do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        cc = 0
        !!Singles (1)
        if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then
          do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
            do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
              int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
              !!if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                c=c+1
                cc = cc + 1
              !!end if
            end do
          end do
        end if
        
        ConfigurationInteraction_instance%numberOfStrings(i)%values(1) = ConfigurationInteraction_instance%numberOfStrings(i)%values(1) + cc
       end do

      !!Doubles of the same specie (2)
       do i=1, numberOfSpecies
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         cc = 0
         if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
           do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
             do n=m+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
               do p= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                 do q=p+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                   !!if ( mod(m,lambda) == mod(p,lambda) .and.  mod(n,lambda) == mod(q,lambda) .and. (p /= q) ) then !! alpha -> alpha, beta -> beta
                     c=c+1
                     cc = cc + 1
                   !!end if
                 end do
               end do
             end do
           end do
         end if
        ConfigurationInteraction_instance%numberOfStrings(i)%values(2) = ConfigurationInteraction_instance%numberOfStrings(i)%values(2) + cc
       end do !! species

       !!Doubles of different species (11)
       do i=1, numberOfSpecies
         do j=i+1, numberOfSpecies
            if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
               do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do n=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                     do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                        do q= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                           c=c+1
                        end do
                     end do
                  end do
               end do
            end if
         end do
       end do !! species


       !!Triples of the same specie (3)
       do i=1, numberOfSpecies

         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         cc = 0
         if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 3 ) then
           do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
             do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
               do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                 do pa= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                         int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                   do pb=pa+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                     do pc=pb+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                     !!  if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                     !!      mod(mb,lambda) == mod(pb,lambda) .and. &
                     !!      mod(mc,lambda) == mod(pc,lambda) ) then !! alpha -> alpha, beta -> beta
                            c=c+1
                            cc = cc + 1
                     !!  end if
                     end do
                   end do
                 end do
               end do
             end do
           end do
         end if
        ConfigurationInteraction_instance%numberOfStrings(i)%values(3) = ConfigurationInteraction_instance%numberOfStrings(i)%values(3) + cc
       end do !! species


       !!Triples (21) 
       do i=1, numberOfSpecies
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         do j=1, numberOfSpecies
           if ( j /= i ) then
             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
                .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
               do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                 do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                   do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                     do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                            int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                       do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                         do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, &
                           int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                       !!    if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                       !!         mod(mb,lambda) == mod(pb,lambda) .and. &
                       !!         mod(mc,lambda) == mod(pc,lambda) )  then !! alpha -> alpha, beta -> beta
                             c=c+1
                       !!    end if
                         end do
                       end do
                     end do  
                   end do
                 end do
               end do
             end if
           end if
         end do

       end do !! species


      !!Triples (111)
       do i=1, numberOfSpecies
         do j=i+1, numberOfSpecies
           do k=j+1, numberOfSpecies
             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. & 
               ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 .and. &
               ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
               do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                 do n=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                   do r=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )
                     do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                       do q= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                         do s= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(k))
                           c=c+1
                         end do
                       end do
                     end do
                   end do
                 end do
               end do
             end if
           end do
         end do

       end do !! species

       !!Quadruples of the same species (4)
       do i=1, numberOfSpecies
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         cc = 0
         if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 4 ) then
           do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
             do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
               do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                 do md=mc+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   do pa= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                           int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                     do pb=pa+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                       do pc=pb+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                         do pd=pc+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                         !!  if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                         !!      mod(mb,lambda) == mod(pb,lambda) .and. &
                         !!      mod(mc,lambda) == mod(pc,lambda) .and. &
                         !!      mod(md,lambda) == mod(pd,lambda) ) then !! alpha -> alpha, beta -> beta
                                c=c+1
                                cc = cc + 1
                         !!  end if
                         end do
                       end do
                     end do
                   end do
                 end do
               end do
             end do
           end do
         end if

         ConfigurationInteraction_instance%numberOfStrings(i)%values(4) = ConfigurationInteraction_instance%numberOfStrings(i)%values(4) + cc
       end do !! species

       !!Quadruples (31)
       do i=1, numberOfSpecies

         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         do j=1, numberOfSpecies
           if ( j /= i ) then
             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 3 &
                .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
                do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                    do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                      do md=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                        do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                               int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                          do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                            do pc=pb+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                              do pd= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, &
                                int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                           !!     if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                           !!          mod(mb,lambda) == mod(pb,lambda) .and. &
                           !!          mod(mc,lambda) == mod(pc,lambda) .and. &
                           !!          mod(md,lambda) == mod(pd,lambda) )  then !! alpha -> alpha, beta -> beta
                                  c=c+1
                           !!     end if
                              end do
                            end do
                          end do
                        end do  
                      end do  
                    end do
                  end do
                end do
             end if
           end if
         end do

       end do !! species

       !!Quadruples (22)
       do i=1, numberOfSpecies
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         do j=i+1, numberOfSpecies
           otherlambda=ConfigurationInteraction_instance%lambda%values(j) !Particles per orbital
           if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
              .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 2 ) then
              do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                    do md=mc+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                      do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                             int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                        do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                          do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1,&
                             int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                            do pd=pc+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                              !!if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                              !!     mod(mb,lambda) == mod(pb,lambda) .and. &
                              !!     mod(mc,otherlambda) == mod(pc,otherlambda) .and. &
                              !!     mod(md,otherlambda) == mod(pd,otherlambda) )  then !! alpha -> alpha, beta -> beta
                                c=c+1
                              !!end if
                            end do
                          end do
                        end do
                      end do  
                    end do  
                  end do
                end do
              end do
           end if
         end do

       end do !! species

       !!quadruples of diff specie (1111)
       do i=1, numberOfSpecies
         if ( numberOfSpecies > 3 ) then
          do j=i+1, numberOfSpecies
            do k=j+1, numberOfSpecies
              do l=k+1, numberOfSpecies

                if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. & 
                   ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 .and. &
                   ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 .and. &
                   ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(l) .ge. 1 ) then
                  do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                    do mb=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                      do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )
                        do md=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(l) )
                          do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                            do pb= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                              do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(k))
                                do pd= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(l))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(l))
                                  c=c+1
                                end do
                              end do
                            end do
                          end do
                        end do
                      end do
                    end do
                  end do

                end if

              end do
            end do
          end do
        end if

       end do !! species

       !!Quadruples (211)
       do i=1, numberOfSpecies
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         do j=1, numberOfSpecies
           if ( j /= i ) then
             do k=j+1, numberOfSpecies
               if ( k /= j .and. k /=i ) then
                 if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
                    .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 &
                    .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
                   do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                     do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                       do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                         do md=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )
                           do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                                  int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                             do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                               do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1,&
                                  int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                                 do pd= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1,&
                                    int(ConfigurationInteraction_instance%numberOfOrbitals%values(k) )
                                !!   if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                                !!        mod(mb,lambda) == mod(pb,lambda) .and. &
                                !!        mod(mc,lambda) == mod(pc,lambda) .and. &
                                !!        mod(md,lambda) == mod(pd,lambda) )  then !! alpha -> alpha, beta -> beta
                                     c=c+1
                                !!   end if
                                 end do
                               end do
                             end do
                           end do  
                         end do  
                       end do
                     end do
                   end do
                 end if
               end if
             end do
           end if
         end do

      end do !! species

       !!Quintuples (221)
       do i=1, numberOfSpecies
         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         do j=i+1, numberOfSpecies
           otherlambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
           do k=j+1, numberOfSpecies
             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
               .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 2 &
               .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
               do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                 do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                   do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                     do md=mc+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                       do me=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )
                         do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                                int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                           do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                             do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1,&
                                int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                               do pd=pc+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                                 do pe= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1,&
                                    int(ConfigurationInteraction_instance%numberOfOrbitals%values(k) )
                                  !! if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                                  !!      mod(mb,lambda) == mod(pb,lambda) .and. &
                                  !!      mod(mc,otherlambda) == mod(pc,otherlambda) .and. &
                                  !!      mod(md,otherlambda) == mod(pd,otherlambda) .and. &
                                  !!      mod(me,lambda) == mod(pe,lambda) )  then !! alpha -> alpha, beta -> beta
                                     c=c+1
                                  !! end if
                                 end do
                               end do
                             end do
                           end do
                         end do  
                       end do  
                     end do  
                   end do
                 end do
               end do
             end if
           end do
         end do

       end do !! species

       ConfigurationInteraction_instance%numberOfConfigurations = c
       allocate (ConfigurationInteraction_instance%configurations(ConfigurationInteraction_instance%numberOfConfigurations) )

       if ( trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) /= "ARPACK" .and. &
        trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) /= "JADAMILU"  ) then

       call Matrix_Constructor(ConfigurationInteraction_instance%hamiltonianMatrix, int(ConfigurationInteraction_instance%numberOfConfigurations,8),int(ConfigurationInteraction_instance%numberOfConfigurations,8),0.0_8)
        end if
    case ( "FCI-oneSpecie" )

    case default

       call ConfigurationInteraction_exception( ERROR, "Configuration interactor constructor", "Correction level not implemented")

    end select

    close(wfnUnit)

  end subroutine ConfigurationInteraction_constructor


  !>
  !! @brief Destructor por omision
  !!
  !! @param this
  !<
  subroutine ConfigurationInteraction_destructor()
    implicit none
    integer i,j,m,n,p,q,c
    integer numberOfSpecies
    integer :: isLambdaEqual1

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()

    !!Destroy configurations
    !!Ground State
    if (allocated(ConfigurationInteraction_instance%configurations)) then
      c=1
      call Configuration_destructor(ConfigurationInteraction_instance%configurations(c) )
  
      do c=2, ConfigurationInteraction_instance%numberOfConfigurations
         call Configuration_destructor(ConfigurationInteraction_instance%configurations(c) )                
      end do
  
      if (allocated(ConfigurationInteraction_instance%configurations)) deallocate(ConfigurationInteraction_instance%configurations)
    end if

    call Matrix_destructor(ConfigurationInteraction_instance%hamiltonianMatrix)
    call Vector_destructorInteger (ConfigurationInteraction_instance%numberOfOccupiedOrbitals)
    call Vector_destructorInteger (ConfigurationInteraction_instance%numberOfOrbitals)
    call Vector_destructor (ConfigurationInteraction_instance%lambda)

    ConfigurationInteraction_instance%isInstanced=.false.

  end subroutine ConfigurationInteraction_destructor

  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine ConfigurationInteraction_show()
    implicit none
    type(ConfigurationInteraction) :: this
    integer :: i
    integer :: m
    real(8) :: davidsonCorrection, HFcoefficient, CIcorrection
 
    if ( ConfigurationInteraction_instance%isInstanced ) then

       print *,""
       print *," POST HARTREE-FOCK CALCULATION"
       print *," CONFIGURATION INTERACTION THEORY:"
       print *,"=============================="
       print *,""
       write (6,"(T8,A30, A5)") "LEVEL = ", ConfigurationInteraction_instance%level
       write (6,"(T8,A30, I8)") "NUMBER OF CONFIGURATIONS = ", ConfigurationInteraction_instance%numberOfConfigurations
       do i = 1, CONTROL_instance%NUMBER_OF_CI_STATES
        write (6,"(T8,A17,I3,A10, F18.12)") "STATE: ", i, " ENERGY = ", ConfigurationInteraction_instance%eigenvalues%values(i)
       end do
       print *, ""
       CIcorrection = ConfigurationInteraction_instance%eigenvalues%values(1) - &
                HartreeFock_instance%totalEnergy

       write (6,"(T4,A34, F20.12)") "GROUND STATE CORRELATION ENERGY = ", CIcorrection

       if (  ConfigurationInteraction_instance%level == "CISD" ) then
         print *, ""
         write (6,"(T2,A34)") "RENORMALIZED DAVIDSON CORRECTION:"
         print *, ""
         write (6,"(T8,A54)") "E(CISDTQ) \approx E(CISD) + \delta E(Q)               "
         write (6,"(T8,A54)") "\delta E(Q) = (1 - c_0^2) * \delta E(CISD) / c_0^2    "
         print *, ""
         HFcoefficient = ConfigurationInteraction_instance%eigenVectors%values(1,1) 
         davidsonCorrection = ( 1 - HFcoefficient*HFcoefficient) * CIcorrection / (HFcoefficient*HFcoefficient)
  
  
         write (6,"(T8,A19, F20.12)") "HF COEFFICIENT = ", HFcoefficient
         write (6,"(T8,A19, F20.12)") "\delta E(Q) = ", davidsonCorrection
         write (6,"(T8,A19, F20.12)") "E(CISDTQ) ESTIMATE ",  HartreeFock_instance%totalEnergy +&
            CIcorrection + davidsonCorrection
       else 

         print *, ""
         HFcoefficient = ConfigurationInteraction_instance%eigenVectors%values(1,1) 
         write (6,"(T8,A19, F20.12)") "HF COEFFICIENT = ", HFcoefficient

       end if

        !do i=1, ConfigurationInteraction_instance%numberOfConfigurations
        !   call Configuration_show (ConfigurationInteraction_instance%configurations(i))
        !end do

    else 

    end if

  end subroutine ConfigurationInteraction_show

  !FELIX IS HERE
  subroutine ConfigurationInteraction_naturalOrbitals()
    implicit none
    type(ConfigurationInteraction) :: this
    integer :: i, j, k, mu, nu
    integer :: unit, wfnunit
    integer :: numberOfOrbitals, numberOfOccupiedOrbitals
    integer :: state, specie, orbital, orbitalA, orbitalB
    character(50) :: file, wfnfile, speciesName, auxstring
    character(50) :: arguments(2)
    real(8) :: sumaPrueba
    type(matrix) :: coefficients, densityMatrix
    type(matrix) :: ciOccupationNumbers
    integer numberOfSpecies

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()

    if ( ConfigurationInteraction_instance%isInstanced .and. CONTROL_instance%CI_STATES_TO_PRINT .gt. 0 ) then

       print *,""
       print *," FRACTIONAL ORBITAL OCCUPATIONS"
       print *,"=============================="
       print *,"column: state, row: orbital"
       print *,""

       !! Open file - to print natural orbitals
       unit = 29

       file = trim(CONTROL_instance%INPUT_FILE)//"CIOccupations.occ"
       open(unit = unit, file=trim(file), status="new", form="formatted")
       
       ! call Matrix_show (ConfigurationInteraction_instance%eigenVectors)
       
       do specie=1, numberOfSpecies
          
          speciesName = MolecularSystem_getNameOfSpecie(specie)
          numberOfOrbitals = ConfigurationInteraction_instance%numberOfOrbitals%values(specie)
          numberOfOccupiedOrbitals = ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(specie)
          !Inicializando la matriz

          call Matrix_constructor ( ciOccupationNumbers , int(numberOfOrbitals,8) , &
               int(CONTROL_instance%CI_STATES_TO_PRINT,8),  0.0_8 )
          print *, "numb orb", numberOfOccupiedOrbitals
          do state=1, CONTROL_instance%CI_STATES_TO_PRINT
             sumaPrueba=0
             do j=1, numberOfOccupiedOrbitals
                ciOccupationNumbers%values(j,state) = 1.0
             end do
          
          ! !Get occupation numbers from each configuration contribution
             
             do i=1, ConfigurationInteraction_instance%numberOfConfigurations
                do j=1, numberOfOccupiedOrbitals

                   !! Occupied orbitals
                   ciOccupationNumbers%values( j, state)= ciOccupationNumbers%values( j, state) -  &
                        ConfigurationInteraction_instance%eigenVectors%values(i,state)**2
                   !! Unoccupied orbitals
                   orbital = ConfigurationInteraction_instance%configurations(i)%occupations(j,specie) 

                   ciOccupationNumbers%values( orbital, state)= ciOccupationNumbers%values( orbital, state) + &
                        ConfigurationInteraction_instance%eigenVectors%values(i,state)**2

                   ! print *, j, orbital, ConfigurationInteraction_instance%eigenVectors%values(i,state)**2
                   ! sumaPrueba=sumaPrueba+ConfigurationInteraction_instance%eigenVectors%values(i,state)**2
                end do
                ! end if

             end do

             ! print *, "suma", sumaPrueba
             !Build a new density matrix (P) in atomic orbitals

             call Matrix_constructor ( densityMatrix , &
                  int(numberOfOrbitals,8), &
                  int(numberOfOrbitals,8),  0.0_8 )
             
             wfnFile = "lowdin.wfn"
             wfnUnit = 20

             open(unit=wfnUnit, file=trim(wfnFile), status="old", form="unformatted")

             arguments(2) = speciesName
             arguments(1) = "COEFFICIENTS"

             coefficients = Matrix_getFromFile(unit=wfnUnit, rows= int(numberOfOrbitals,4), &
                  columns= int(numberOfOrbitals,4), binary=.true., arguments=arguments(1:2))
             
             close(wfnUnit)
             
             do mu = 1 , numberOfOrbitals
                do nu = 1 , numberOfOrbitals
                   do k = 1 , numberOfOrbitals

                      densityMatrix%values(mu,nu) =  &
                           densityMatrix%values(mu,nu) + &
                           ciOccupationNumbers%values(k, state)* &
                           coefficients%values(mu,k)*coefficients%values(nu,k)
                    end do
                 end do
              end do

              write(auxstring,*) state
              arguments(2) = speciesName
              arguments(1) = "DENSITYMATRIX"//trim(adjustl(auxstring)) 
              
              call Matrix_writeToFile ( densityMatrix, unit , arguments=arguments(1:2) )

              ! print *, arguments(1:3)
              ! call Matrix_show ( densityMatrix )

              call Matrix_destructor(coefficients)          
              call Matrix_destructor(densityMatrix)          


           end do

          !Write occupation numbers to file
          write (6,"(T8,A10,A20)") trim(MolecularSystem_getNameOfSpecie(specie)),"OCCUPATIONS:"

          call Matrix_show ( ciOccupationNumbers )

          arguments(2) = speciesName
          arguments(1) = "OCCUPATIONS"

          call Matrix_writeToFile ( ciOccupationNumbers, unit , arguments=arguments(1:2) )

          call Matrix_destructor(ciOccupationNumbers)          

       end do
          
       close(unit)

    end if



  end subroutine ConfigurationInteraction_naturalOrbitals




  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine ConfigurationInteraction_run()
    implicit none 
    integer :: m
    real(8), allocatable :: eigenValues(:) 

!    select case ( trim(ConfigurationInteraction_instance%level) )

       print *, ""
       print *, "==============================================="
       print *, "|         BEGIN ", trim(ConfigurationInteraction_instance%level)," CALCULATION"
       print *, "-----------------------------------------------"
       print *, ""

       print *, "Getting transformed integrals..."
       call ConfigurationInteraction_getTransformedIntegrals()

       print *, ConfigurationInteraction_instance%fourCenterIntegrals(1,1)%values(171, 1)
       print *, "Building configurations..."

       call ConfigurationInteraction_buildConfigurations()
       print *, "Total number of configurations", ConfigurationInteraction_instance%numberOfConfigurations
       print *, ""
       call Vector_constructor8 ( ConfigurationInteraction_instance%eigenvalues, &
                                 ConfigurationInteraction_instance%numberOfConfigurations, 0.0_8)

       select case (trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)))

       case ("ARPACK")

         print *, "Building initial hamiltonian..."
         call ConfigurationInteraction_buildInitialCIMatrix()

         print *, "Building and saving hamiltonian..."
         call ConfigurationInteraction_buildAndSaveCIMatrix()

         !! deallocate transformed integrals
         deallocate (ConfigurationInteraction_instance%configurations)
         deallocate(ConfigurationInteraction_instance%twoCenterIntegrals)
         deallocate(ConfigurationInteraction_instance%fourCenterIntegrals)

         call Matrix_constructor (ConfigurationInteraction_instance%eigenVectors, &
              int(ConfigurationInteraction_instance%numberOfConfigurations,8), &
              int(CONTROL_instance%NUMBER_OF_CI_STATES,8), 0.0_8)

         print *, ""
         print *, "Diagonalizing hamiltonian..."
         print *, "  Using : ", trim(String_getUppercase((CONTROL_instance%CI_DIAGONALIZATION_METHOD)))


         call ConfigurationInteraction_diagonalize(ConfigurationInteraction_instance%numberOfConfigurations, &
              ConfigurationInteraction_instance%numberOfConfigurations, &
              CONTROL_instance%NUMBER_OF_CI_STATES, &
              CONTROL_instance%CI_MAX_NCV, &
              ConfigurationInteraction_instance%eigenvalues, &
              ConfigurationInteraction_instance%eigenVectors )

         case ("JADAMILU")

         print *, "Building initial hamiltonian..."

         !call ConfigurationInteraction_buildDiagonal()
         call ConfigurationInteraction_buildInitialCIMatrix2()
         call ConfigurationInteraction_buildHamiltonianMatrix2()
 
         !call ConfigurationInteraction_buildInitialCIMatrix()

         call Matrix_constructor (ConfigurationInteraction_instance%eigenVectors, &
              int(ConfigurationInteraction_instance%numberOfConfigurations,8), &
              int(CONTROL_instance%NUMBER_OF_CI_STATES,8), 0.0_8)

         if ( CONTROL_instance%CI_LOAD_EIGENVECTOR ) then 
           call ConfigurationInteraction_loadEigenVector (ConfigurationInteraction_instance%eigenvalues, &
                  ConfigurationInteraction_instance%eigenVectors) 
         end if 

         if ( CONTROL_instance%CI_BUILD_FULL_MATRIX ) then
           print *, "Building and saving hamiltonian..."
           call ConfigurationInteraction_buildAndSaveCIMatrix()
         end if

         print *, ""
         print *, "Diagonalizing hamiltonian..."
         print *, "  Using : ", trim(String_getUppercase((CONTROL_instance%CI_DIAGONALIZATION_METHOD)))
         print *, "============================================================="
         print *, "M. BOLLHÖFER AND Y. NOTAY, JADAMILU:"
         print *, " a software code for computing selected eigenvalues of "
         print *, " large sparse symmetric matrices, "
         print *, "Computer Physics Communications, vol. 177, pp. 951-964, 2007." 
         print *, "============================================================="


         call ConfigurationInteraction_jadamiluInterface(ConfigurationInteraction_instance%numberOfConfigurations, &
              int(CONTROL_instance%NUMBER_OF_CI_STATES,8), &
              ConfigurationInteraction_instance%eigenvalues, &
              ConfigurationInteraction_instance%eigenVectors )

         if ( CONTROL_instance%CI_SAVE_EIGENVECTOR ) then 
           call ConfigurationInteraction_saveEigenVector () 
         end if
       case ("DSYEVX")

         !call ConfigurationInteraction_buildCouplingMatrix()
         !call ConfigurationInteraction_buildDiagonal()
         !call ConfigurationInteraction_buildHamiltonianMatrix2()
         call ConfigurationInteraction_buildHamiltonianMatrix()
         print *, "Reference Energy", ConfigurationInteraction_instance%hamiltonianMatrix%values(1,1)

         call Matrix_constructor (ConfigurationInteraction_instance%eigenVectors, &
              int(ConfigurationInteraction_instance%numberOfConfigurations,8), &
              int(CONTROL_instance%NUMBER_OF_CI_STATES,8), 0.0_8)

         !! deallocate transformed integrals
         deallocate(ConfigurationInteraction_instance%twoCenterIntegrals)
         deallocate(ConfigurationInteraction_instance%fourCenterIntegrals)


         print *, ""
         print *, "Diagonalizing hamiltonian..."
         print *, "  Using : ", trim(String_getUppercase((CONTROL_instance%CI_DIAGONALIZATION_METHOD)))


         call Matrix_eigen_select (ConfigurationInteraction_instance%hamiltonianMatrix, ConfigurationInteraction_instance%eigenvalues, &
              int(1), int(CONTROL_instance%NUMBER_OF_CI_STATES), &  
              eigenVectors = ConfigurationInteraction_instance%eigenVectors, &
              flags = int(SYMMETRIC,4))

!         call Matrix_eigen_select (ConfigurationInteraction_instance%hamiltonianMatrix, ConfigurationInteraction_instance%eigenvalues, &
!              1, CONTROL_instance%NUMBER_OF_CI_STATES, &  
!              flags = SYMMETRIC, dm = ConfigurationInteraction_instance%numberOfConfigurations )


       case ("DSYEVR")

         call ConfigurationInteraction_buildHamiltonianMatrix()
         print *, "Reference Energy", ConfigurationInteraction_instance%hamiltonianMatrix%values(1,1)

         call Matrix_constructor (ConfigurationInteraction_instance%eigenVectors, &
              int(ConfigurationInteraction_instance%numberOfConfigurations,8), &
              int(CONTROL_instance%NUMBER_OF_CI_STATES,8), 0.0_8)

         !! deallocate transformed integrals
         deallocate(ConfigurationInteraction_instance%twoCenterIntegrals)
         deallocate(ConfigurationInteraction_instance%fourCenterIntegrals)

         print *, ""
         print *, "Diagonalizing hamiltonian..."
         print *, "  Using : ", trim(String_getUppercase((CONTROL_instance%CI_DIAGONALIZATION_METHOD)))


         call Matrix_eigen_dsyevr (ConfigurationInteraction_instance%hamiltonianMatrix, ConfigurationInteraction_instance%eigenvalues, &
              1, CONTROL_instance%NUMBER_OF_CI_STATES, &  
              eigenVectors = ConfigurationInteraction_instance%eigenVectors, &
              flags = SYMMETRIC)

!        call Matrix_eigen_dsyevr (ConfigurationInteraction_instance%hamiltonianMatrix, ConfigurationInteraction_instance%eigenvalues, &
!              1, CONTROL_instance%NUMBER_OF_CI_STATES, &  
!              flags = SYMMETRIC, dm = ConfigurationInteraction_instance%numberOfConfigurations )

       case default

         call ConfigurationInteraction_exception( ERROR, "Configuration interactor constructor", "Diagonalization method not implemented")


       end select

       print *,""
       print *, "-----------------------------------------------"
       print *, "|              END CISD CALCULATION           |"
       print *, "==============================================="
       print *, ""

         
!    case ( "FCI-oneSpecie" )
!
!       print *, ""
!       print *, ""
!       print *, "==============================================="
!       print *, "|  Full CI for one specie calculation          |"
!       print *, "|  Use fci program to perform the calculation  |"
!       print *, "-----------------------------------------------"
!       print *, ""
!       ! call ConfigurationInteraction_getTransformedIntegrals()
!       !call ConfigurationInteraction_printTransformedIntegralsToFile()
!

  end subroutine ConfigurationInteraction_run


  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine ConfigurationInteraction_buildConfigurations()
    implicit none

    integer :: numberOfSpecies
    integer :: i,ii,j,k,l,m,n,p,q,a,b,d,r,s
    integer(8) :: c, cc
    integer :: ma,mb,mc,md,me,pa,pb,pc,pd,pe
    integer :: isLambdaEqual1
    type(ivector) :: order
    type(vector), allocatable :: occupiedCode(:)
    type(vector), allocatable :: unoccupiedCode(:)
    logical :: sameConfiguration
    integer :: nEquivalentConfigurations, newNumberOfConfigurations
    integer, allocatable :: equivalentConfigurations (:,:), auxArray(:,:), auxvector(:),auxvectorA(:)
    integer :: lambda, otherlambda

    nEquivalentConfigurations = 0
    if (allocated ( equivalentConfigurations )) deallocate ( equivalentConfigurations)
    allocate( equivalentConfigurations(nEquivalentConfigurations,2) )
    equivalentConfigurations = 0

    newNumberOfConfigurations = ConfigurationInteraction_instance%numberOfConfigurations 

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()

    if ( allocated( occupiedCode ) ) deallocate( occupiedCode )
    allocate (occupiedCode ( numberOfSpecies ) )
    if ( allocated( unoccupiedCode ) ) deallocate( unoccupiedCode )
    allocate (unoccupiedCode ( numberOfSpecies ) )

    do i = 1, numberOfSpecies
      print *, "i , nstrings 1 ",i, ConfigurationInteraction_instance%numberOfOrbitals%values(i), &
      sum(ConfigurationInteraction_instance%numberOfStrings(i)%values)

      if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) > 0 ) then
      call Matrix_constructorInteger( ConfigurationInteraction_instance%strings(i), &
        int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i),8), &
        !!int(ConfigurationInteraction_instance%numberOfOrbitals%values(i),8), &
        sum(ConfigurationInteraction_instance%numberOfStrings(i)%values), int(0,4))
      else
       call Matrix_constructorInteger( ConfigurationInteraction_instance%strings(i), &
        1_8, 1_8, int(0,4))
      end if
    end do  

    do i = 1, numberOfSpecies
      call Vector_constructorInteger1( ConfigurationInteraction_instance%auxstring(i), &
        int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i),8), int(0,1))
    end do  

    select case ( trim(ConfigurationInteraction_instance%level) )

    case ( "CIS" )

   !!Build configurations
       !!Ground State
       c=1
       call Vector_constructorInteger (order, numberOfSpecies, 0 )

       do i=1, numberOfSpecies
         call Vector_constructor (occupiedCode(i), 1, 0.0_8)
         call Vector_constructor (unoccupiedCode(i), 1, 0.0_8)
       end do

       call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations,c) 

       do i=1, numberOfSpecies
          cc = 0
          call Vector_constructorInteger (order, numberOfSpecies, 0 )
          order%values(i)=1
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital

          !!Singles
          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then
             do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                !call Vector_constructor (occupiedCode(i), numberOfSpecies, 0.0_8)
                call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                occupiedCode(i)%values(1)=m
                do p=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i))
                   if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                     call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8)
                     unoccupiedCode(i)%values(1)=p
                     c=c+1
                     cc = cc + 1
                     call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                          ConfigurationInteraction_instance%numberOfConfigurations,c) 

                   end if

                end do !! p
             end do !! m
          end if
          write (6, "(T4,A20,A21,A3,I4)") "Singles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc
        end do !! species

        !do c = 1,  ConfigurationInteraction_instance%numberOfConfigurations 
        !   call Configuration_show(  ConfigurationInteraction_instance%configurations(c) )
        !end do 

!!! Working!! but checktwoConfigurations was commentted
!!       !! Search for equivalent configurations
!!       do a=1, ConfigurationInteraction_instance%numberOfConfigurations
!!          do b=a+1, ConfigurationInteraction_instance%numberOfConfigurations
!!
!!             !call Configuration_checkTwoConfigurations(ConfigurationInteraction_instance%configurations(a), &
!!             !       ConfigurationInteraction_instance%configurations(b), sameConfiguration, numberOfSpecies)
!!
!!             if ( sameConfiguration .eqv. .True. ) then
!!               !! append one value....
!!               nEquivalentConfigurations = nEquivalentConfigurations + 1
!!               allocate(auxArray(nEquivalentConfigurations,2))
!!               auxArray = 0
!!               auxArray(:nEquivalentConfigurations-1,:) = equivalentConfigurations(:nEquivalentConfigurations-1,:)
!!               deallocate(equivalentConfigurations)
!!               allocate(equivalentConfigurations(nEquivalentConfigurations,2))
!!               equivalentConfigurations(:,:) = auxArray(:,:) 
!!               deallocate(auxArray)
!!
!!               equivalentConfigurations(nEquivalentConfigurations,1) = a
!!               equivalentConfigurations(nEquivalentConfigurations,2) = b
!!
!!               newNumberOfConfigurations = newNumberOfConfigurations -1
!!
!!             end if
!!             sameConfiguration = .false.
!!          end do
!!       end do
!!
!!
!!       !! Remove equivalent configurations
!!        do c = nEquivalentConfigurations, 1, -1
!!
!!                call Configuration_destructor(ConfigurationInteraction_instance%configurations( &
!!                     equivalentConfigurations(c,2) ) )                
!!        end do
!!
!!        !! Compact the configuration vector... 
!!        do c = 1,  ConfigurationInteraction_instance%numberOfConfigurations 
!!
!!          if ( c <= newNumberOfConfigurations ) then
!!
!!            if ( ConfigurationInteraction_instance%configurations(c)%isInstanced .eqv. .false. ) then
!!              do d = c +1 , ConfigurationInteraction_instance%numberOfConfigurations 
!!
!!                if ( ConfigurationInteraction_instance%configurations(d)%isInstanced .eqv. .true. ) then
!!                  call Configuration_copyConstructor(  ConfigurationInteraction_instance%configurations(d), &
!!                    ConfigurationInteraction_instance%configurations(c) )
!!
!!                  call Configuration_destructor(ConfigurationInteraction_instance%configurations(d))                
!!
!!                  exit
!!                end if
!!
!!              end do 
!!            end if
!!
!!         end if
!!
!!        end do 
!!
!!        ConfigurationInteraction_instance%numberOfConfigurations = newNumberOfConfigurations 
        ConfigurationInteraction_instance%numberOfConfigurations = c

        !do c = 1,  ConfigurationInteraction_instance%numberOfConfigurations 
        !   call Configuration_show(  ConfigurationInteraction_instance%configurations(c) )
        !end do 
         
       call Matrix_destructor(ConfigurationInteraction_instance%hamiltonianMatrix)

       !! Rebuild the hamiltonian matrix without the equivalent configurations
       call Matrix_Constructor(ConfigurationInteraction_instance%hamiltonianMatrix, &
            int(ConfigurationInteraction_instance%numberOfConfigurations,8), &
            int(ConfigurationInteraction_instance%numberOfConfigurations,8),0.0_8 )

    case ( "CISD" )

   !!Build configurations
       !!Ground State
       c=1
       call Vector_constructorInteger (order, numberOfSpecies, 0 )

       do i=1, numberOfSpecies
         call Vector_constructor (occupiedCode(i), 1, 0.0_8)
         call Vector_constructor (unoccupiedCode(i), 1, 0.0_8)
       end do

       call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations, c) 

       do i=1, numberOfSpecies

          call Vector_constructorInteger (order, numberOfSpecies, 0 )
          order%values(i)=1
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
          cc = 0
          !!Singles
          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then
             do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                call Vector_constructor (occupiedCode(i), int( order%values(i),4), 0.0_8)
                occupiedCode(i)%values(1)=m
                do p=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1,int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                   if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                     call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                     unoccupiedCode(i)%values(1)=p
                     c=c+1
                     cc=cc+1
                     call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                          ConfigurationInteraction_instance%numberOfConfigurations,c) 

                   end if

                end do !! p
             end do !! m
          end if

          write (6, "(T4,A20,A21,A3,I8)") "Singles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

        end do !! species

       do i=1, numberOfSpecies
          !!Doubles of the same specie
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
          call Vector_constructorInteger (order, numberOfSpecies, 0 )
          order%values(i)=2
          cc = 0
          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
             do m=1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                do n=m+1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8 )
                   !occupiedCode%values(i,1)=m*1024+n
                   occupiedCode(i)%values(1)=m
                   occupiedCode(i)%values(2)=n
                   do p = int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                     do q=p+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                   !do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )

                      if ( mod(m,lambda) == mod(p,lambda) .and.  mod(n,lambda) == mod(q,lambda) ) then !! alpha -> alpha, beta -> beta
                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            !unoccupiedCode%values(i)=p*1024+q
                            unoccupiedCode(i)%values(1)=p
                            unoccupiedCode(i)%values(2)=q
                            c=c+1
                            cc=cc+1
                            call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), &
                                  occupiedCode, unoccupiedCode, order, &
                                   ConfigurationInteraction_instance%numberOfConfigurations, c) 
                     end if
                       end do
                   end do
                end do
             end do
          end if
          write (6, "(T4,A20,A21,A3,I8)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

          !!Doubles of different species
          do j=i+1, numberOfSpecies

             call Vector_constructorInteger (order, numberOfSpecies, 0 )
             order%values(i)=1
             order%values(j)=1
             cc = 0

             do ii=1, numberOfSpecies
               call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
               call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
             end do


             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
                do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   do n=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))

                      call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                      call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                      occupiedCode(i)%values(1)=m
                      occupiedCode(j)%values(1)=n
                      do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i))
                         do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                            unoccupiedCode(i)%values(1)=p
                            unoccupiedCode(j)%values(1)=q
                            c=c+1
                            cc=cc+1
                            call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations, c) 
                         end do
                      end do
                   end do
                end do
             end if

            write (6, "(T4,A20,A21,A3,I8)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i))//&
                                                   "/"//trim(MolecularSystem_getNameOfSpecie(j)), " : ", cc
          end do

       end do


!!!!!!!!!!!!!!!!!! string
       print *, "building strings"

       call Vector_constructorInteger (order, numberOfSpecies, 0 )

       do i=1, numberOfSpecies

          c = 0
          cc = 0
          c = c + 1

          call Vector_constructor (occupiedCode(i), 1, 0.0_8)
          call Vector_constructor (unoccupiedCode(i), 1, 0.0_8)

          call Configuration_constructorB(ConfigurationInteraction_instance%strings(i), occupiedCode, unoccupiedCode, i, c, order)

          !!Singles
          call Vector_constructorInteger (order, numberOfSpecies, 0 )
          order%values(i)=1
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital

          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then
             do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                call Vector_constructor (occupiedCode(i), int( order%values(i),4), 0.0_8)
                occupiedCode(i)%values(1)=m
                do p=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1,int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                     call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                     unoccupiedCode(i)%values(1)=p
                     c=c+1
                     cc=cc+1
                     call Configuration_constructorB(ConfigurationInteraction_instance%strings(i), occupiedCode, unoccupiedCode, i, c, order)

                end do !! p
             end do !! m
          end if

          write (6, "(T4,A20,A21,A3,I8)") "Singles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

          !!Doubles of the same specie
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
          call Vector_constructorInteger (order, numberOfSpecies, 0 )
          order%values(i)=2
          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
             do m=1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                do n=m+1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8 )
                   occupiedCode(i)%values(1)=m
                   occupiedCode(i)%values(2)=n
                   do p = int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                     do q=p+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )

                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            unoccupiedCode(i)%values(1)=p
                            unoccupiedCode(i)%values(2)=q
                            c=c+1
                            cc=cc+1
                            call Configuration_constructorB(ConfigurationInteraction_instance%strings(i), occupiedCode, unoccupiedCode, i, c, order)
                       end do
                   end do
                end do
             end do
          end if
          write (6, "(T4,A20,A21,A3,I8)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

       end do



!!!!

       !! Search for equivalent configurations
!!       do a=1, ConfigurationInteraction_instance%numberOfConfigurations
!!          do b=a+1, ConfigurationInteraction_instance%numberOfConfigurations
!!             call Configuration_checkTwoConfigurations(ConfigurationInteraction_instance%configurations(a), &
!!                    ConfigurationInteraction_instance%configurations(b), sameConfiguration, numberOfSpecies)
!!
!!             if ( sameConfiguration .eqv. .True. ) then
!!
!!               !! append one value....
!!               nEquivalentConfigurations = nEquivalentConfigurations + 1
!!               allocate(auxArray(nEquivalentConfigurations,2))
!!               auxArray = 0
!!               auxArray(:nEquivalentConfigurations-1,:) = equivalentConfigurations(:nEquivalentConfigurations-1,:)
!!               deallocate(equivalentConfigurations)
!!               allocate(equivalentConfigurations(nEquivalentConfigurations,2))
!!               equivalentConfigurations(:,:) = auxArray(:,:) 
!!               deallocate(auxArray)
!!
!!               equivalentConfigurations(nEquivalentConfigurations,1) = a
!!               equivalentConfigurations(nEquivalentConfigurations,2) = b
!!
!!               newNumberOfConfigurations = newNumberOfConfigurations -1
!!
!!             end if
!!             sameConfiguration = .false.
!!          end do
!!       end do
!!
!!
!!       print *, "nEquivalentConfigurations",  nEquivalentConfigurations
!!       allocate(auxvector( ConfigurationInteraction_instance%numberOfConfigurations ))
!!       allocate(auxvectorA( ConfigurationInteraction_instance%numberOfConfigurations ))
!!       auxvector = 0
!!       auxvectorA = 0
!!       !! Remove equivalent configurations
!!        do c = nEquivalentConfigurations, 1, -1
!!                print *, c,  equivalentConfigurations(c,1),  equivalentConfigurations(c,2)
!!                auxvector(equivalentConfigurations(c,2)) = auxvector(equivalentConfigurations(c,2)) + 1
!!!                auxvector(equivalentConfigurations(c,1)) = auxvector(equivalentConfigurations(c,1)) + 1
!!
!!                print *,auxvector(equivalentConfigurations(c,2))
!!                if ( auxvector(equivalentConfigurations(c,2)) < 2 ) then
!!                  call Configuration_destructor(ConfigurationInteraction_instance%configurations( &
!!                     equivalentConfigurations(c,2) ) )                
!!                end if
!!        end do
!!       print *, " newNumberOfConfiguration" ,newNumberOfConfigurations
!!        !! Compact the configuration vector... 
!!        do c = 1,  ConfigurationInteraction_instance%numberOfConfigurations 
!!
!!!          if ( c <= newNumberOfConfigurations ) then
!!
!!            if ( ConfigurationInteraction_instance%configurations(c)%isInstanced .eqv. .false. ) then
!!              do d = c +1 , ConfigurationInteraction_instance%numberOfConfigurations 
!!
!!                if ( ConfigurationInteraction_instance%configurations(d)%isInstanced .eqv. .true. ) then
!!                  call Configuration_copyConstructor(  ConfigurationInteraction_instance%configurations(d), &
!!                    ConfigurationInteraction_instance%configurations(c) )
!!
!!                  call Configuration_destructor(ConfigurationInteraction_instance%configurations(d))                
!!
!!                  exit
!!                end if
!!
!!              end do 
!!            end if
!!
!!!          end if
!!
!!        end do 
!!
!!        newNumberOfConfigurations  = 0
!!
!!        do c = 1,  ConfigurationInteraction_instance%numberOfConfigurations 
!!                if ( ConfigurationInteraction_instance%configurations(c)%isInstanced .eqv. .true. ) then
!!                  newNumberOfConfigurations = newNumberOfConfigurations + 1
!!                end if
!!        end do 
!!
!!        ConfigurationInteraction_instance%numberOfConfigurations = newNumberOfConfigurations 
!!
!!        do c = 1,  ConfigurationInteraction_instance%numberOfConfigurations 
!!           call Configuration_show(  ConfigurationInteraction_instance%configurations(c) )
!!        end do 
!!
!!         
!!       call Matrix_destructor(ConfigurationInteraction_instance%hamiltonianMatrix)
!!
!!       !! Rebuild the hamiltonian matrix without the equivalent configurations
!!       call Matrix_Constructor(ConfigurationInteraction_instance%hamiltonianMatrix, &
!!            int(ConfigurationInteraction_instance%numberOfConfigurations,8), &
!!            int(ConfigurationInteraction_instance%numberOfConfigurations,8),0.0_8 )

!       ConfigurationInteraction_instance%configurations(2)%occupations(1)%values = (/1,0,0,1/)


    case ( "CIDD" ) 

   !!Build configurations
       !!Ground State
       c=1
       call Vector_constructorInteger (order, numberOfSpecies, 0 )

       do i=1, numberOfSpecies
         call Vector_constructor (occupiedCode(i), 1, 0.0_8)
         call Vector_constructor (unoccupiedCode(i), 1, 0.0_8)
       end do

       call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations, c) 

       do i=1, numberOfSpecies
          !!Doubles of the same specie
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
          call Vector_constructorInteger (order, numberOfSpecies, 0 )
          order%values(i)=2
          cc = 0
          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
             do m=1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                do n=m+1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8 )
                   !occupiedCode%values(i,1)=m*1024+n
                   occupiedCode(i)%values(1)=m
                   occupiedCode(i)%values(2)=n
                   do p = int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                     do q=p+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                   !do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )

                      if ( mod(m,lambda) == mod(p,lambda) .and.  mod(n,lambda) == mod(q,lambda) ) then !! alpha -> alpha, beta -> beta
                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            !unoccupiedCode%values(i)=p*1024+q
                            unoccupiedCode(i)%values(1)=p
                            unoccupiedCode(i)%values(2)=q
                            c=c+1
                            cc=cc+1
                            call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), &
                                  occupiedCode, unoccupiedCode, order, &
                                   ConfigurationInteraction_instance%numberOfConfigurations, c) 
                     end if
                       end do
                   end do
                end do
             end do
          end if
          write (6, "(T4,A20,A21,A3,I8)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

          !!Doubles of different species
          do j=i+1, numberOfSpecies

             call Vector_constructorInteger (order, numberOfSpecies, 0 )
             order%values(i)=1
             order%values(j)=1
             cc = 0

             do ii=1, numberOfSpecies
               call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
               call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
             end do


             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
                do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   do n=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))

                      call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                      call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                      occupiedCode(i)%values(1)=m
                      occupiedCode(j)%values(1)=n
                      do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i))
                         do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                            unoccupiedCode(i)%values(1)=p
                            unoccupiedCode(j)%values(1)=q
                            c=c+1
                            cc=cc+1
                            call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations, c) 
                         end do
                      end do
                   end do
                end do
             end if

            write (6, "(T4,A20,A21,A3,I8)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i))//&
                                                   "/"//trim(MolecularSystem_getNameOfSpecie(j)), " : ", cc
          end do
       end do

    case ( "FCI" )

   !!Build configurations
       !!Ground State
       c=1
       call Vector_constructorInteger (order, numberOfSpecies, 0 )

       do i=1, numberOfSpecies
         call Vector_constructor (occupiedCode(i), 1, 0.0_8)
         call Vector_constructor (unoccupiedCode(i), 1, 0.0_8)
       end do

       call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations, c) 

       do i=1, numberOfSpecies

          call Vector_constructorInteger (order, numberOfSpecies, 0 )
          order%values(i)=1
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
          cc = 0
          !!Singles
          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then
             do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                call Vector_constructor (occupiedCode(i), int( order%values(i),4), 0.0_8)
                occupiedCode(i)%values(1)=m
                do p=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1,int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                   if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                     call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                     unoccupiedCode(i)%values(1)=p
                     c=c+1
                     cc=cc+1
                     call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                          ConfigurationInteraction_instance%numberOfConfigurations,c) 

                   end if

                end do !! p
             end do !! m
          end if

          write (6, "(T4,A20,A21,A3,I4)") "Singles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

        end do !! species

       do i=1, numberOfSpecies
          !!Doubles of the same specie
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
          call Vector_constructorInteger (order, numberOfSpecies, 0 )
          order%values(i)=2
          cc = 0
          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
             do m=1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                do n=m+1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8 )
                   !occupiedCode%values(i,1)=m*1024+n
                   occupiedCode(i)%values(1)=m
                   occupiedCode(i)%values(2)=n
                   do p = int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                     do q=p+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                   !do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )

                      if ( mod(m,lambda) == mod(p,lambda) .and.  mod(n,lambda) == mod(q,lambda) ) then !! alpha -> alpha, beta -> beta
                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            !unoccupiedCode%values(i)=p*1024+q
                            unoccupiedCode(i)%values(1)=p
                            unoccupiedCode(i)%values(2)=q
                            c=c+1
                            cc=cc+1
                            call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), &
                                  occupiedCode, unoccupiedCode, order, &
                                   ConfigurationInteraction_instance%numberOfConfigurations, c) 
                     end if
                       end do
                   end do
                end do
             end do
          end if
          write (6, "(T4,A20,A21,A3,I4)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

          !!Doubles of different species
          do j=i+1, numberOfSpecies

             call Vector_constructorInteger (order, numberOfSpecies, 0 )
             order%values(i)=1
             order%values(j)=1
             cc = 0

             do ii=1, numberOfSpecies
               call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
               call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
             end do


             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
                do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   do n=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))

                      call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                      call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                      occupiedCode(i)%values(1)=m
                      occupiedCode(j)%values(1)=n
                      do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i))
                         do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                            unoccupiedCode(i)%values(1)=p
                            unoccupiedCode(j)%values(1)=q
                            c=c+1
                            cc=cc+1
                            call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations, c) 
                         end do
                      end do
                   end do
                end do
             end if

            write (6, "(T4,A20,A21,A3,I4)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i))//&
                                                   "/"//trim(MolecularSystem_getNameOfSpecie(j)), " : ", cc
          end do

          !!triples of different species
          do j=i+1, numberOfSpecies

            do k=j+1, numberOfSpecies

             call Vector_constructorInteger (order, numberOfSpecies, 0)
             order%values(i)=1
             order%values(j)=1
             order%values(k)=1
             cc = 0

             do ii=1, numberOfSpecies
               call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
               call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
             end do


             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. &
                 ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 .and. &
                 ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
                do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   do n=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))
                     do r=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))

                      call Vector_constructor (occupiedCode(i), order%values(i), 0.0_8)
                      call Vector_constructor (occupiedCode(j), order%values(j), 0.0_8)
                      call Vector_constructor (occupiedCode(k), order%values(k), 0.0_8)
                      occupiedCode(i)%values(1)=m
                      occupiedCode(j)%values(1)=n
                      occupiedCode(k)%values(1)=r

                      do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i))
                         do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )

                         do s=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(k) )
                            call Vector_constructor (unoccupiedCode(i), order%values(i), 0.0_8)
                            call Vector_constructor (unoccupiedCode(j), order%values(j), 0.0_8)
                            call Vector_constructor (unoccupiedCode(k), order%values(k), 0.0_8)
                            unoccupiedCode(i)%values(1)=p
                            unoccupiedCode(j)%values(1)=q
                            unoccupiedCode(k)%values(1)=s
                            c=c+1
                            cc=cc+1
                            call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations, c) 

                         end do
                         end do
                      end do
                      end do
                   end do
                end do

             end if

            write (6, "(T4,A20,A21,A3,I6)") "Triples for species ", trim(MolecularSystem_getNameOfSpecie(i))//&
                                                   "/"//trim(MolecularSystem_getNameOfSpecie(j))//& 
                                                   "/"//trim(MolecularSystem_getNameOfSpecie(k)), " : ", cc
            end do
          end do


       end do

!!!!!!!!!!!!!!!!!! string
       print *, "building strings"

       call Vector_constructorInteger (order, numberOfSpecies, 0 )

       do i=1, numberOfSpecies

          c = 0
          cc = 0
          c = c + 1

          call Vector_constructor (occupiedCode(i), 1, 0.0_8)
          call Vector_constructor (unoccupiedCode(i), 1, 0.0_8)

          call Configuration_constructorB(ConfigurationInteraction_instance%strings(i), occupiedCode, unoccupiedCode, i, c, order)

          !!Singles
          call Vector_constructorInteger (order, numberOfSpecies, 0 )
          order%values(i)=1
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital

          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then
             do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                call Vector_constructor (occupiedCode(i), int( order%values(i),4), 0.0_8)
                occupiedCode(i)%values(1)=m
                do p=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1,int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                     call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                     unoccupiedCode(i)%values(1)=p
                     c=c+1
                     cc=cc+1
                     call Configuration_constructorB(ConfigurationInteraction_instance%strings(i), occupiedCode, unoccupiedCode, i, c, order)

                end do !! p
             end do !! m
          end if

          write (6, "(T4,A20,A21,A3,I8)") "Singles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc
          cc = 0

          !!Doubles of the same specie
          lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
          call Vector_constructorInteger (order, numberOfSpecies, 0 )
          order%values(i)=2
          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
             do m=1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                do n=m+1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                   call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8 )
                   occupiedCode(i)%values(1)=m
                   occupiedCode(i)%values(2)=n
                   do p = int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                     do q=p+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )

                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            unoccupiedCode(i)%values(1)=p
                            unoccupiedCode(i)%values(2)=q
                            c=c+1
                            cc=cc+1
                            call Configuration_constructorB(ConfigurationInteraction_instance%strings(i), occupiedCode, unoccupiedCode, i, c, order)
                       end do
                   end do
                end do
             end do
          end if
          write (6, "(T4,A20,A21,A3,I8)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

       end do



    case ("CISDT")
    !!Build configurations
    !!Ground State
      c=1
      call Vector_constructorInteger (order, numberOfSpecies, 0 )

      do i=1, numberOfSpecies
        call Vector_constructor (occupiedCode(i), 1, 0.0_8)
        call Vector_constructor (unoccupiedCode(i), 1, 0.0_8)
      end do

      call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations, c) 

      do i=1, numberOfSpecies

        call Vector_constructorInteger (order, numberOfSpecies, 0 )
        order%values(i)=1
        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        cc = 0
        !!Singles
        if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then
          do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
            call Vector_constructor (occupiedCode(i), int( order%values(i),4), 0.0_8)
            occupiedCode(i)%values(1)=m
            do p=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1,int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
              if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                unoccupiedCode(i)%values(1)=p
                c=c+1
                cc=cc+1
                call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                     ConfigurationInteraction_instance%numberOfConfigurations,c) 

              end if
            end do !! p
          end do !! m
        end if

        write (6, "(T4,A20,A21,A3,I4)") "Singles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

      end do !! species

      !!Doubles of the same specie
      do i=1, numberOfSpecies
        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        call Vector_constructorInteger (order, numberOfSpecies, 0 )
        order%values(i)=2
        cc = 0
        if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
           do m=1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
              do n=m+1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                 call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8 )
                 !occupiedCode%values(i,1)=m*1024+n
                 occupiedCode(i)%values(1)=m
                 occupiedCode(i)%values(2)=n
                 do p = int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                   do q=p+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                 !do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )

                    if ( mod(m,lambda) == mod(p,lambda) .and.  mod(n,lambda) == mod(q,lambda) ) then !! alpha -> alpha, beta -> beta
                          call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                          !unoccupiedCode%values(i)=p*1024+q
                          unoccupiedCode(i)%values(1)=p
                          unoccupiedCode(i)%values(2)=q
                          c=c+1
                          cc=cc+1
                          call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), &
                                occupiedCode, unoccupiedCode, order, &
                                 ConfigurationInteraction_instance%numberOfConfigurations, c) 
                   end if
                     end do
                 end do
              end do
           end do
        end if
        write (6, "(T4,A20,A21,A3,I4)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

      end do !! species

      !!Doubles of different species
      do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital

        do j=i+1, numberOfSpecies

          call Vector_constructorInteger (order, numberOfSpecies, 0 )

          order%values(i)=1
          order%values(j)=1
          cc = 0

             do ii=1, numberOfSpecies
               call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
               call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
             end do


          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
            do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
              do n=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))

                call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                occupiedCode(i)%values(1)=m
                occupiedCode(j)%values(1)=n
                do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i))
                  do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                    call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                    call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                    unoccupiedCode(i)%values(1)=p
                    unoccupiedCode(j)%values(1)=q
                    c=c+1
                    cc=cc+1
                    call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations, c) 
                  end do
                end do
              end do
            end do
          end if

          write (6, "(T4,A20,A21,A3,I4)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i))//&
                                                   "/"//trim(MolecularSystem_getNameOfSpecie(j)), " : ", cc

        end do 
      end do !! species

      !!Triples of the same specie (3)
      do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        call Vector_constructorInteger (order, numberOfSpecies, 0 )
        order%values(i)=3

        if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 3 ) then
          do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
            do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
              do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))

                call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                occupiedCode(i)%values(1)=ma
                occupiedCode(i)%values(2)=mb
                occupiedCode(i)%values(3)=mc

                do pa= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                        int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                  do pb=pa+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                    do pc=pb+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                      if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                          mod(mb,lambda) == mod(pb,lambda) .and. &
                          mod(mc,lambda) == mod(pc,lambda) ) then !! alpha -> alpha, beta -> beta

                          call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                          unoccupiedCode(i)%values(1)=pa
                          unoccupiedCode(i)%values(2)=pb
                          unoccupiedCode(i)%values(3)=pc
                          c=c+1
                          cc=cc+1
                          call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), &
                                occupiedCode, unoccupiedCode, order, &
                                 ConfigurationInteraction_instance%numberOfConfigurations, c) 

                      end if
                    end do
                  end do
                end do
              end do
            end do
          end do
        end if

        write (6, "(T4,A20,A21,A3,I6)") "Triples for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc
      end do !! species

       !!Triples (21)  problem here!!
      do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        call Vector_constructorInteger (order, numberOfSpecies, 0 )

        do j=1, numberOfSpecies
          if ( j /= i ) then

            order%values = 0
            order%values(i)=2
            order%values(j)=1

            do ii=1, numberOfSpecies
              call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
              call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
            end do


            if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
               .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
              do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )

                    call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                    occupiedCode(i)%values(1)=ma
                    occupiedCode(i)%values(2)=mb
                    call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                    occupiedCode(j)%values(1)=mc

                    do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                           int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                      do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                        do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, &
                          int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                          if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                               mod(mb,lambda) == mod(pb,lambda) .and. &
                               mod(mc,lambda) == mod(pc,lambda) )  then !! alpha -> alpha, beta -> beta

                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            unoccupiedCode(i)%values(1)=pa
                            unoccupiedCode(i)%values(2)=pb
                            call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                            unoccupiedCode(j)%values(1)=pc
                            c=c+1
                            cc=cc+1
                            call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                              ConfigurationInteraction_instance%numberOfConfigurations,c) 

                          end if
                        end do
                      end do
                    end do  
                  end do
                end do
              end do
            end if
          end if
        end do

      end do !! species

      !!Triples (111)
       do i=1, numberOfSpecies

         call Vector_constructorInteger (order, numberOfSpecies, 0 )

         do j=i+1, numberOfSpecies
           order%values(j)=1
           do k=j+1, numberOfSpecies

             order%values=0
             order%values(i)=1
             order%values(j)=1
             order%values(k)=1
             do ii=1, numberOfSpecies
               call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
               call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
             end do

             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. & 
               ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 .and. &
               ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
               do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                 do n=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                   do r=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )

                     call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                     occupiedCode(i)%values(1)=m
                     call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                     occupiedCode(j)%values(1)=n
                     call Vector_constructor (occupiedCode(k), int(order%values(k),4), 0.0_8)
                     occupiedCode(k)%values(1)=r

                     do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                       do q= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                         do s= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(k))
                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            unoccupiedCode(i)%values(1)=p
                            call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                            unoccupiedCode(j)%values(1)=q
                            call Vector_constructor (unoccupiedCode(k), int(order%values(k),4), 0.0_8 )
                            unoccupiedCode(k)%values(1)=s
                            c=c+1
                            cc=cc+1
                            call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                              ConfigurationInteraction_instance%numberOfConfigurations,c) 


                         end do
                       end do
                     end do
                   end do
                 end do
               end do
             end if
           end do
         end do

       end do !! species

    case ("CISDTQ")
    !!Build configurations
    !!Ground State
      c=1
      call Vector_constructorInteger (order, numberOfSpecies, 0 )

      do i=1, numberOfSpecies
        call Vector_constructor (occupiedCode(i), 1, 0.0_8)
        call Vector_constructor (unoccupiedCode(i), 1, 0.0_8)
      end do

      call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations, c) 

      do i=1, numberOfSpecies

        call Vector_constructorInteger (order, numberOfSpecies, 0 )
        order%values(i)=1
        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        cc = 0
        !!Singles
        if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then
          do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
            call Vector_constructor (occupiedCode(i), int( order%values(i),4), 0.0_8)
            occupiedCode(i)%values(1)=m
            do p=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1,int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
              if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                unoccupiedCode(i)%values(1)=p
                c=c+1
                cc=cc+1
                call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                     ConfigurationInteraction_instance%numberOfConfigurations,c) 

              end if
            end do !! p
          end do !! m
        end if

        write (6, "(T4,A20,A21,A3,I4)") "Singles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

      end do !! species

      !!Doubles of the same specie
      do i=1, numberOfSpecies
        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        call Vector_constructorInteger (order, numberOfSpecies, 0 )
        order%values(i)=2
        cc = 0
        if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
           do m=1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
              do n=m+1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                 call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8 )
                 !occupiedCode%values(i,1)=m*1024+n
                 occupiedCode(i)%values(1)=m
                 occupiedCode(i)%values(2)=n
                 do p = int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                   do q=p+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                 !do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )

                    if ( mod(m,lambda) == mod(p,lambda) .and.  mod(n,lambda) == mod(q,lambda) ) then !! alpha -> alpha, beta -> beta
                          call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                          !unoccupiedCode%values(i)=p*1024+q
                          unoccupiedCode(i)%values(1)=p
                          unoccupiedCode(i)%values(2)=q
                          c=c+1
                          cc=cc+1
                          call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), &
                                occupiedCode, unoccupiedCode, order, &
                                 ConfigurationInteraction_instance%numberOfConfigurations, c) 
                   end if
                     end do
                 end do
              end do
           end do
        end if
        write (6, "(T4,A20,A21,A3,I4)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

      end do !! species

      !!Doubles of different species
      do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital

        do j=i+1, numberOfSpecies

          call Vector_constructorInteger (order, numberOfSpecies, 0 )

          order%values(i)=1
          order%values(j)=1
          cc = 0

             do ii=1, numberOfSpecies
               call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
               call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
             end do


          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
            do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
              do n=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))

                call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                occupiedCode(i)%values(1)=m
                occupiedCode(j)%values(1)=n
                do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i))
                  do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                    call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                    call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                    unoccupiedCode(i)%values(1)=p
                    unoccupiedCode(j)%values(1)=q
                    c=c+1
                    cc=cc+1
                    call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations, c) 
                  end do
                end do
              end do
            end do
          end if

          write (6, "(T4,A20,A21,A3,I4)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i))//&
                                                   "/"//trim(MolecularSystem_getNameOfSpecie(j)), " : ", cc

        end do 
      end do !! species

      !!Triples of the same specie (3)
      do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        call Vector_constructorInteger (order, numberOfSpecies, 0 )
        order%values(i)=3

        if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 3 ) then
          do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
            do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
              do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))

                call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                occupiedCode(i)%values(1)=ma
                occupiedCode(i)%values(2)=mb
                occupiedCode(i)%values(3)=mc

                do pa= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                        int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                  do pb=pa+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                    do pc=pb+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                      if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                          mod(mb,lambda) == mod(pb,lambda) .and. &
                          mod(mc,lambda) == mod(pc,lambda) ) then !! alpha -> alpha, beta -> beta

                          call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                          unoccupiedCode(i)%values(1)=pa
                          unoccupiedCode(i)%values(2)=pb
                          unoccupiedCode(i)%values(3)=pc
                          c=c+1
                          cc=cc+1
                          call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), &
                                occupiedCode, unoccupiedCode, order, &
                                 ConfigurationInteraction_instance%numberOfConfigurations, c) 

                      end if
                    end do
                  end do
                end do
              end do
            end do
          end do
        end if
      end do !! species

       !!Triples (21)  problem here!!
      do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        call Vector_constructorInteger (order, numberOfSpecies, 0 )

        do j=1, numberOfSpecies
          if ( j /= i ) then

            order%values = 0
            order%values(i)=2
            order%values(j)=1

            do ii=1, numberOfSpecies
              call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
              call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
            end do


            if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
               .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
              do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )

                    call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                    occupiedCode(i)%values(1)=ma
                    occupiedCode(i)%values(2)=mb
                    call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                    occupiedCode(j)%values(1)=mc

                    do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                           int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                      do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                        do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, &
                          int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                          if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                               mod(mb,lambda) == mod(pb,lambda) .and. &
                               mod(mc,lambda) == mod(pc,lambda) )  then !! alpha -> alpha, beta -> beta

                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            unoccupiedCode(i)%values(1)=pa
                            unoccupiedCode(i)%values(2)=pb
                            call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                            unoccupiedCode(j)%values(1)=pc
                            c=c+1
                            cc=cc+1
                            call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                              ConfigurationInteraction_instance%numberOfConfigurations,c) 

                          end if
                        end do
                      end do
                    end do  
                  end do
                end do
              end do
            end if
          end if
        end do

      end do !! species

      !!Triples (111)
       do i=1, numberOfSpecies

         call Vector_constructorInteger (order, numberOfSpecies, 0 )

         do j=i+1, numberOfSpecies
           order%values(j)=1
           do k=j+1, numberOfSpecies

             order%values=0
             order%values(i)=1
             order%values(j)=1
             order%values(k)=1
             do ii=1, numberOfSpecies
               call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
               call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
             end do

             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. & 
               ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 .and. &
               ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
               do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                 do n=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                   do r=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )

                     call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                     occupiedCode(i)%values(1)=m
                     call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                     occupiedCode(j)%values(1)=n
                     call Vector_constructor (occupiedCode(k), int(order%values(k),4), 0.0_8)
                     occupiedCode(k)%values(1)=r

                     do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                       do q= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                         do s= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(k))
                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            unoccupiedCode(i)%values(1)=p
                            call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                            unoccupiedCode(j)%values(1)=q
                            call Vector_constructor (unoccupiedCode(k), int(order%values(k),4), 0.0_8 )
                            unoccupiedCode(k)%values(1)=s
                            c=c+1
                            cc=cc+1
                            call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                              ConfigurationInteraction_instance%numberOfConfigurations,c) 


                         end do
                       end do
                     end do
                   end do
                 end do
               end do
             end if
           end do
         end do

       end do !! species

       !!Quadruples of the same species (4)
       do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        call Vector_constructorInteger (order, numberOfSpecies, 0 )
        order%values(i)=4

         if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 4 ) then
           do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
             do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
               do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                 do md=mc+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))

                     call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                     occupiedCode(i)%values(1)=ma
                     occupiedCode(i)%values(2)=mb
                     occupiedCode(i)%values(3)=mc
                     occupiedCode(i)%values(4)=md


                   do pa= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                           int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                     do pb=pa+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                       do pc=pb+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                         do pd=pc+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                           if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                               mod(mb,lambda) == mod(pb,lambda) .and. &
                               mod(mc,lambda) == mod(pc,lambda) .and. &
                               mod(md,lambda) == mod(pd,lambda) ) then !! alpha -> alpha, beta -> beta
                             call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                             unoccupiedCode(i)%values(1)=pa
                             unoccupiedCode(i)%values(2)=pb
                             unoccupiedCode(i)%values(3)=pc
                             unoccupiedCode(i)%values(4)=pd
                             cc=cc+1
                             c=c+1
                             call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                              ConfigurationInteraction_instance%numberOfConfigurations,c) 

                           end if
                         end do
                       end do
                     end do
                   end do
                 end do
               end do
             end do
           end do
         end if

       end do !! species

       !!Quadruples (31)
       do i=1, numberOfSpecies

         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         call Vector_constructorInteger (order, numberOfSpecies, 0 )

         do j=1, numberOfSpecies
           if ( j /= i ) then

             order%values=0
             order%values(i)=3
             order%values(j)=1
             do ii=1, numberOfSpecies
               call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
               call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
             end do


             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 3 &
                .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
                do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                    do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                      do md=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )

                        call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                        occupiedCode(i)%values(1)=ma
                        occupiedCode(i)%values(2)=mb
                        occupiedCode(i)%values(3)=mc
                        call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                        occupiedCode(j)%values(1)=md

                        do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                               int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                          do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                            do pc=pb+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                              do pd= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, &
                                int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                                if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                                     mod(mb,lambda) == mod(pb,lambda) .and. &
                                     mod(mc,lambda) == mod(pc,lambda) .and. &
                                     mod(md,lambda) == mod(pd,lambda) )  then !! alpha -> alpha, beta -> beta
                                  call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                                  unoccupiedCode(i)%values(1)=pa
                                  unoccupiedCode(i)%values(2)=pb
                                  unoccupiedCode(i)%values(3)=pc
                                  call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                                  unoccupiedCode(j)%values(1)=pd
                                  cc=cc+1
                                  c=c+1
                                  call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                                    ConfigurationInteraction_instance%numberOfConfigurations,c) 
                                end if
                              end do
                            end do
                          end do
                        end do  
                      end do  
                    end do
                  end do
                end do
             end if
           end if
         end do

       end do !! species

       !!Quadruples (22)
       do i=1, numberOfSpecies

         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         call Vector_constructorInteger (order, numberOfSpecies, 0 )

         do j=i+1, numberOfSpecies

           otherlambda=ConfigurationInteraction_instance%lambda%values(j) !Particles per orbital
           !call Vector_constructorInteger (order, numberOfSpecies, 0 )
           order%values=0
           order%values(i)=2
           order%values(j)=2
           do ii=1, numberOfSpecies
             call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
             call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
           end do


           if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
              .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 2 ) then
              do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                    do md=mc+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )

                      call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                      occupiedCode(i)%values(1)=ma
                      occupiedCode(i)%values(2)=mb
                      call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                      occupiedCode(j)%values(1)=mc
                      occupiedCode(j)%values(2)=md

                      do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                             int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                        do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                          do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1,&
                             int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                            do pd=pc+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                              if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                                   mod(mb,lambda) == mod(pb,lambda) .and. &
                                   mod(mc,otherlambda) == mod(pc,otherlambda) .and. &
                                   mod(md,otherlambda) == mod(pd,otherlambda) )  then !! alpha -> alpha, beta -> beta

                                  call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                                  unoccupiedCode(i)%values(1)=pa
                                  unoccupiedCode(i)%values(2)=pb
                                  call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                                  unoccupiedCode(j)%values(1)=pc
                                  unoccupiedCode(j)%values(2)=pd
                                  cc=cc+1
                                  c=c+1
                                  call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                                   ConfigurationInteraction_instance%numberOfConfigurations,c) 

                              end if
                            end do
                          end do
                        end do
                      end do  
                    end do  
                  end do
                end do
              end do
           end if
         end do

       end do !! species

       !!quadruples of diff specie (1111)
       do i=1, numberOfSpecies

         call Vector_constructorInteger (order, numberOfSpecies, 0 )

         if ( numberOfSpecies > 3 ) then
          do j=i+1, numberOfSpecies
            do k=j+1, numberOfSpecies
              do l=k+1, numberOfSpecies

                order%values=0
                order%values(i)=1
                order%values(j)=1
                order%values(k)=1
                order%values(l)=1
                do ii=1, numberOfSpecies
                  call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
                  call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
                end do



                if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. & 
                   ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 .and. &
                   ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 .and. &
                   ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(l) .ge. 1 ) then
                  do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                    do mb=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                      do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )
                        do md=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(l) )

                          call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                          occupiedCode(i)%values(1)=ma
                          call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                          occupiedCode(j)%values(1)=mb
                          call Vector_constructor (occupiedCode(k), int(order%values(k),4), 0.0_8)
                          occupiedCode(k)%values(1)=mc
                          call Vector_constructor (occupiedCode(l), int(order%values(l),4), 0.0_8)
                          occupiedCode(l)%values(1)=md


                          do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                            do pb= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                              do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(k))
                                do pd= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(l))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(l))
                                  call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                                  unoccupiedCode(i)%values(1)=pa
                                  call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                                  unoccupiedCode(j)%values(1)=pb
                                  call Vector_constructor (unoccupiedCode(k), int(order%values(k),4), 0.0_8 )
                                  unoccupiedCode(k)%values(1)=pc
                                  call Vector_constructor (unoccupiedCode(l), int(order%values(l),4), 0.0_8 )
                                  unoccupiedCode(l)%values(1)=pd
                                  cc=cc+1
                                  c=c+1
                                  call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                                    ConfigurationInteraction_instance%numberOfConfigurations,c) 

                                end do
                              end do
                            end do
                          end do
                        end do
                      end do
                    end do
                  end do

                end if

              end do
            end do
          end do
        end if

       end do !! species

       !!Quadruples (211)
       do i=1, numberOfSpecies

         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         call Vector_constructorInteger (order, numberOfSpecies, 0 )

         do j=1, numberOfSpecies
           if ( j /= i ) then
             do k=j+1, numberOfSpecies
               if ( k /= j .and. k /=i ) then
                 order%values=0
                 order%values(i)=2
                 order%values(j)=1
                 order%values(k)=1
                 do ii=1, numberOfSpecies
                   call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
                   call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
                 end do

                 if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
                    .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 &
                    .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
                   do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                     do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                       do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                         do md=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )

                            call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                            occupiedCode(i)%values(1)=ma
                            occupiedCode(i)%values(2)=mb
                            call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                            occupiedCode(j)%values(1)=mc
                            call Vector_constructor (occupiedCode(k), int(order%values(k),4), 0.0_8)
                            occupiedCode(k)%values(1)=md

                           do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                                  int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                             do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                               do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1,&
                                  int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                                 do pd= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1,&
                                    int(ConfigurationInteraction_instance%numberOfOrbitals%values(k) )
                                   if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                                        mod(mb,lambda) == mod(pb,lambda) .and. &
                                        mod(mc,lambda) == mod(pc,lambda) .and. &
                                        mod(md,lambda) == mod(pd,lambda) )  then !! alpha -> alpha, beta -> beta
                                     call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                                     unoccupiedCode(i)%values(1)=pa
                                     unoccupiedCode(i)%values(2)=pb
                                     call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                                     unoccupiedCode(j)%values(1)=pc
                                     call Vector_constructor (unoccupiedCode(k), int(order%values(k),4), 0.0_8 )
                                     unoccupiedCode(k)%values(1)=pd
                                     cc=cc+1
                                     c=c+1
                                     call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                                       ConfigurationInteraction_instance%numberOfConfigurations,c) 
                                   end if
                                 end do
                               end do
                             end do
                           end do  
                         end do  
                       end do
                     end do
                   end do
                 end if
               end if
             end do
           end if
         end do

      end do !! species

    case ("CISDTQQ")
    !!Build configurations
    !!Ground State
      c=1
      call Vector_constructorInteger (order, numberOfSpecies, 0 )

      do i=1, numberOfSpecies
        call Vector_constructor (occupiedCode(i), 1, 0.0_8)
        call Vector_constructor (unoccupiedCode(i), 1, 0.0_8)
      end do

      call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations, c) 

      do i=1, numberOfSpecies

        call Vector_constructorInteger (order, numberOfSpecies, 0 )
        order%values(i)=1
        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        cc = 0
        !!Singles
        if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 ) then
          do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
            call Vector_constructor (occupiedCode(i), int( order%values(i),4), 0.0_8)
            occupiedCode(i)%values(1)=m
            do p=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1,int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
              if ( mod(m,lambda) == mod(p,lambda) ) then !! alpha -> alpha, beta -> beta
                call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                unoccupiedCode(i)%values(1)=p
                c=c+1
                cc=cc+1
                call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                     ConfigurationInteraction_instance%numberOfConfigurations,c) 

              end if
            end do !! p
          end do !! m
        end if

        write (6, "(T4,A20,A21,A3,I4)") "Singles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

      end do !! species

      !!Doubles of the same specie
      do i=1, numberOfSpecies
        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        call Vector_constructorInteger (order, numberOfSpecies, 0 )
        order%values(i)=2
        cc = 0
        if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 ) then
           do m=1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
              do n=m+1,int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                 call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8 )
                 !occupiedCode%values(i,1)=m*1024+n
                 occupiedCode(i)%values(1)=m
                 occupiedCode(i)%values(2)=n
                 do p = int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                   do q=p+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                 !do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )

                    if ( mod(m,lambda) == mod(p,lambda) .and.  mod(n,lambda) == mod(q,lambda) ) then !! alpha -> alpha, beta -> beta
                          call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                          !unoccupiedCode%values(i)=p*1024+q
                          unoccupiedCode(i)%values(1)=p
                          unoccupiedCode(i)%values(2)=q
                          c=c+1
                          cc=cc+1
                          call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), &
                                occupiedCode, unoccupiedCode, order, &
                                 ConfigurationInteraction_instance%numberOfConfigurations, c) 
                   end if
                     end do
                 end do
              end do
           end do
        end if
        write (6, "(T4,A20,A21,A3,I4)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i)), " : ", cc

      end do !! species

      !!Doubles of different species
      do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital

        do j=i+1, numberOfSpecies

          call Vector_constructorInteger (order, numberOfSpecies, 0 )

          order%values(i)=1
          order%values(j)=1
          cc = 0

             do ii=1, numberOfSpecies
               call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
               call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
             end do


          if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
            do m=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
              do n=1, int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))

                call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                occupiedCode(i)%values(1)=m
                occupiedCode(j)%values(1)=n
                do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i))
                  do q=int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                    call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                    call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                    unoccupiedCode(i)%values(1)=p
                    unoccupiedCode(j)%values(1)=q
                    c=c+1
                    cc=cc+1
                    call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, ConfigurationInteraction_instance%numberOfConfigurations, c) 
                  end do
                end do
              end do
            end do
          end if

          write (6, "(T4,A20,A21,A3,I4)") "Doubles for species ", trim(MolecularSystem_getNameOfSpecie(i))//&
                                                   "/"//trim(MolecularSystem_getNameOfSpecie(j)), " : ", cc

        end do 
      end do !! species

      !!Triples of the same specie (3)
      do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        call Vector_constructorInteger (order, numberOfSpecies, 0 )
        order%values(i)=3

        if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 3 ) then
          do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
            do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
              do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))

                call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                occupiedCode(i)%values(1)=ma
                occupiedCode(i)%values(2)=mb
                occupiedCode(i)%values(3)=mc

                do pa= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                        int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                  do pb=pa+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                    do pc=pb+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                      if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                          mod(mb,lambda) == mod(pb,lambda) .and. &
                          mod(mc,lambda) == mod(pc,lambda) ) then !! alpha -> alpha, beta -> beta

                          call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                          unoccupiedCode(i)%values(1)=pa
                          unoccupiedCode(i)%values(2)=pb
                          unoccupiedCode(i)%values(3)=pc
                          c=c+1
                          cc=cc+1
                          call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), &
                                occupiedCode, unoccupiedCode, order, &
                                 ConfigurationInteraction_instance%numberOfConfigurations, c) 

                      end if
                    end do
                  end do
                end do
              end do
            end do
          end do
        end if
      end do !! species

       !!Triples (21)  problem here!!
      do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        call Vector_constructorInteger (order, numberOfSpecies, 0 )

        do j=1, numberOfSpecies
          if ( j /= i ) then

            order%values = 0
            order%values(i)=2
            order%values(j)=1

            do ii=1, numberOfSpecies
              call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
              call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
            end do


            if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
               .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
              do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )

                    call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                    occupiedCode(i)%values(1)=ma
                    occupiedCode(i)%values(2)=mb
                    call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                    occupiedCode(j)%values(1)=mc

                    do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                           int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                      do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                        do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, &
                          int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                          if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                               mod(mb,lambda) == mod(pb,lambda) .and. &
                               mod(mc,lambda) == mod(pc,lambda) )  then !! alpha -> alpha, beta -> beta

                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            unoccupiedCode(i)%values(1)=pa
                            unoccupiedCode(i)%values(2)=pb
                            call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                            unoccupiedCode(j)%values(1)=pc
                            c=c+1
                            cc=cc+1
                            call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                              ConfigurationInteraction_instance%numberOfConfigurations,c) 

                          end if
                        end do
                      end do
                    end do  
                  end do
                end do
              end do
            end if
          end if
        end do

      end do !! species

      !!Triples (111)
       do i=1, numberOfSpecies

         call Vector_constructorInteger (order, numberOfSpecies, 0 )

         do j=i+1, numberOfSpecies
           order%values(j)=1
           do k=j+1, numberOfSpecies

             order%values=0
             order%values(i)=1
             order%values(j)=1
             order%values(k)=1
             do ii=1, numberOfSpecies
               call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
               call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
             end do

             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. & 
               ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 .and. &
               ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
               do m=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                 do n=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                   do r=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )

                     call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                     occupiedCode(i)%values(1)=m
                     call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                     occupiedCode(j)%values(1)=n
                     call Vector_constructor (occupiedCode(k), int(order%values(k),4), 0.0_8)
                     occupiedCode(k)%values(1)=r

                     do p= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                       do q= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                         do s= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(k))
                            call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                            unoccupiedCode(i)%values(1)=p
                            call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                            unoccupiedCode(j)%values(1)=q
                            call Vector_constructor (unoccupiedCode(k), int(order%values(k),4), 0.0_8 )
                            unoccupiedCode(k)%values(1)=s
                            c=c+1
                            cc=cc+1
                            call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                              ConfigurationInteraction_instance%numberOfConfigurations,c) 


                         end do
                       end do
                     end do
                   end do
                 end do
               end do
             end if
           end do
         end do

       end do !! species

       !!Quadruples of the same species (4)
       do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        call Vector_constructorInteger (order, numberOfSpecies, 0 )
        order%values(i)=4

         if ( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 4 ) then
           do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
             do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
               do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))
                 do md=mc+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))

                     call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                     occupiedCode(i)%values(1)=ma
                     occupiedCode(i)%values(2)=mb
                     occupiedCode(i)%values(3)=mc
                     occupiedCode(i)%values(4)=md


                   do pa= int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                           int( ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                     do pb=pa+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                       do pc=pb+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                         do pd=pc+1,int( ConfigurationInteraction_instance%numberOfOrbitals%values(i)) 
                           if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                               mod(mb,lambda) == mod(pb,lambda) .and. &
                               mod(mc,lambda) == mod(pc,lambda) .and. &
                               mod(md,lambda) == mod(pd,lambda) ) then !! alpha -> alpha, beta -> beta
                             call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                             unoccupiedCode(i)%values(1)=pa
                             unoccupiedCode(i)%values(2)=pb
                             unoccupiedCode(i)%values(3)=pc
                             unoccupiedCode(i)%values(4)=pd
                             cc=cc+1
                             c=c+1
                             call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                              ConfigurationInteraction_instance%numberOfConfigurations,c) 

                           end if
                         end do
                       end do
                     end do
                   end do
                 end do
               end do
             end do
           end do
         end if

       end do !! species

       !!Quadruples (31)
       do i=1, numberOfSpecies

         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         call Vector_constructorInteger (order, numberOfSpecies, 0 )

         do j=1, numberOfSpecies
           if ( j /= i ) then

             order%values=0
             order%values(i)=3
             order%values(j)=1
             do ii=1, numberOfSpecies
               call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
               call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
             end do


             if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 3 &
                .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 ) then
                do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                    do mc=mb+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                      do md=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )

                        call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                        occupiedCode(i)%values(1)=ma
                        occupiedCode(i)%values(2)=mb
                        occupiedCode(i)%values(3)=mc
                        call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                        occupiedCode(j)%values(1)=md

                        do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                               int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                          do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                            do pc=pb+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                              do pd= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, &
                                int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                                if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                                     mod(mb,lambda) == mod(pb,lambda) .and. &
                                     mod(mc,lambda) == mod(pc,lambda) .and. &
                                     mod(md,lambda) == mod(pd,lambda) )  then !! alpha -> alpha, beta -> beta
                                  call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                                  unoccupiedCode(i)%values(1)=pa
                                  unoccupiedCode(i)%values(2)=pb
                                  unoccupiedCode(i)%values(3)=pc
                                  call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                                  unoccupiedCode(j)%values(1)=pd
                                  cc=cc+1
                                  c=c+1
                                  call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                                    ConfigurationInteraction_instance%numberOfConfigurations,c) 
                                end if
                              end do
                            end do
                          end do
                        end do  
                      end do  
                    end do
                  end do
                end do
             end if
           end if
         end do

       end do !! species

       !!Quadruples (22)
       do i=1, numberOfSpecies

         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         call Vector_constructorInteger (order, numberOfSpecies, 0 )

         do j=i+1, numberOfSpecies

           otherlambda=ConfigurationInteraction_instance%lambda%values(j) !Particles per orbital
           !call Vector_constructorInteger (order, numberOfSpecies, 0 )
           order%values=0
           order%values(i)=2
           order%values(j)=2
           do ii=1, numberOfSpecies
             call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
             call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
           end do


           if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
              .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 2 ) then
              do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                    do md=mc+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )

                      call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                      occupiedCode(i)%values(1)=ma
                      occupiedCode(i)%values(2)=mb
                      call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                      occupiedCode(j)%values(1)=mc
                      occupiedCode(j)%values(2)=md

                      do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                             int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                        do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                          do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1,&
                             int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                            do pd=pc+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                              if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                                   mod(mb,lambda) == mod(pb,lambda) .and. &
                                   mod(mc,otherlambda) == mod(pc,otherlambda) .and. &
                                   mod(md,otherlambda) == mod(pd,otherlambda) )  then !! alpha -> alpha, beta -> beta

                                  call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                                  unoccupiedCode(i)%values(1)=pa
                                  unoccupiedCode(i)%values(2)=pb
                                  call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                                  unoccupiedCode(j)%values(1)=pc
                                  unoccupiedCode(j)%values(2)=pd
                                  cc=cc+1
                                  c=c+1
                                  call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                                   ConfigurationInteraction_instance%numberOfConfigurations,c) 

                              end if
                            end do
                          end do
                        end do
                      end do  
                    end do  
                  end do
                end do
              end do
           end if
         end do

       end do !! species

       !!quadruples of diff specie (1111)
       do i=1, numberOfSpecies

         call Vector_constructorInteger (order, numberOfSpecies, 0 )

         if ( numberOfSpecies > 3 ) then
          do j=i+1, numberOfSpecies
            do k=j+1, numberOfSpecies
              do l=k+1, numberOfSpecies

                order%values=0
                order%values(i)=1
                order%values(j)=1
                order%values(k)=1
                order%values(l)=1
                do ii=1, numberOfSpecies
                  call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
                  call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
                end do



                if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 1 .and. & 
                   ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 .and. &
                   ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 .and. &
                   ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(l) .ge. 1 ) then
                  do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                    do mb=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                      do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )
                        do md=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(l) )

                          call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                          occupiedCode(i)%values(1)=ma
                          call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                          occupiedCode(j)%values(1)=mb
                          call Vector_constructor (occupiedCode(k), int(order%values(k),4), 0.0_8)
                          occupiedCode(k)%values(1)=mc
                          call Vector_constructor (occupiedCode(l), int(order%values(l),4), 0.0_8)
                          occupiedCode(l)%values(1)=md


                          do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                            do pb= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j))
                              do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(k))
                                do pd= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(l))+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(l))
                                  call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                                  unoccupiedCode(i)%values(1)=pa
                                  call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                                  unoccupiedCode(j)%values(1)=pb
                                  call Vector_constructor (unoccupiedCode(k), int(order%values(k),4), 0.0_8 )
                                  unoccupiedCode(k)%values(1)=pc
                                  call Vector_constructor (unoccupiedCode(l), int(order%values(l),4), 0.0_8 )
                                  unoccupiedCode(l)%values(1)=pd
                                  cc=cc+1
                                  c=c+1
                                  call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                                    ConfigurationInteraction_instance%numberOfConfigurations,c) 

                                end do
                              end do
                            end do
                          end do
                        end do
                      end do
                    end do
                  end do

                end if

              end do
            end do
          end do
        end if

       end do !! species

       !!Quadruples (211)
       do i=1, numberOfSpecies

         lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
         call Vector_constructorInteger (order, numberOfSpecies, 0 )

         do j=1, numberOfSpecies
           if ( j /= i ) then
             do k=j+1, numberOfSpecies
               if ( k /= j .and. k /=i ) then
                 order%values=0
                 order%values(i)=2
                 order%values(j)=1
                 order%values(k)=1
                 do ii=1, numberOfSpecies
                   call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
                   call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
                 end do

                 if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
                    .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 1 &
                    .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
                   do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                     do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                       do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                         do md=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )

                            call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                            occupiedCode(i)%values(1)=ma
                            occupiedCode(i)%values(2)=mb
                            call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                            occupiedCode(j)%values(1)=mc
                            call Vector_constructor (occupiedCode(k), int(order%values(k),4), 0.0_8)
                            occupiedCode(k)%values(1)=md

                           do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                                  int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                             do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                               do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1,&
                                  int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                                 do pd= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1,&
                                    int(ConfigurationInteraction_instance%numberOfOrbitals%values(k) )
                                   if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                                        mod(mb,lambda) == mod(pb,lambda) .and. &
                                        mod(mc,lambda) == mod(pc,lambda) .and. &
                                        mod(md,lambda) == mod(pd,lambda) )  then !! alpha -> alpha, beta -> beta
                                     call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                                     unoccupiedCode(i)%values(1)=pa
                                     unoccupiedCode(i)%values(2)=pb
                                     call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                                     unoccupiedCode(j)%values(1)=pc
                                     call Vector_constructor (unoccupiedCode(k), int(order%values(k),4), 0.0_8 )
                                     unoccupiedCode(k)%values(1)=pd
                                     cc=cc+1
                                     c=c+1
                                     call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                                       ConfigurationInteraction_instance%numberOfConfigurations,c) 
                                   end if
                                 end do
                               end do
                             end do
                           end do  
                         end do  
                       end do
                     end do
                   end do
                 end if
               end if
             end do
           end if
         end do

      end do !! species

      !!Quintuples (221)
      do i=1, numberOfSpecies

        lambda=ConfigurationInteraction_instance%lambda%values(i) !Particles per orbital
        call Vector_constructorInteger (order, numberOfSpecies, 0 )

        do j=i+1, numberOfSpecies

          otherlambda=ConfigurationInteraction_instance%lambda%values(j) !Particles per orbital

          do k=j+1, numberOfSpecies

            order%values=0
            order%values(i)=2
            order%values(j)=2
            order%values(k)=1
            do ii=1, numberOfSpecies
              call Vector_constructor (occupiedCode(ii), 1, 0.0_8)
              call Vector_constructor (unoccupiedCode(ii), 1, 0.0_8)
            end do

            if (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) .ge. 2 &
              .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) .ge. 2 &
              .and. ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) .ge. 1 ) then
              do ma=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                do mb=ma+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) )
                  do mc=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                    do md=mc+1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j) )
                      do me=1, int( ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k) )

                         call Vector_constructor (occupiedCode(i), int(order%values(i),4), 0.0_8)
                         occupiedCode(i)%values(1)=ma
                         occupiedCode(i)%values(2)=mb
                         call Vector_constructor (occupiedCode(j), int(order%values(j),4), 0.0_8)
                         occupiedCode(j)%values(1)=mc
                         occupiedCode(j)%values(2)=md
                         call Vector_constructor (occupiedCode(k), int(order%values(k),4), 0.0_8)
                         occupiedCode(k)%values(1)=me


                        do pa= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i))+1, &
                               int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                          do pb=pa+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(i) )
                            do pc= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j))+1,&
                               int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                              do pd=pc+1, int(ConfigurationInteraction_instance%numberOfOrbitals%values(j) )
                                do pe= int(ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(k))+1,&
                                   int(ConfigurationInteraction_instance%numberOfOrbitals%values(k) )
                                  if ( mod(ma,lambda) == mod(pa,lambda) .and. & 
                                       mod(mb,lambda) == mod(pb,lambda) .and. &
                                       mod(mc,otherlambda) == mod(pc,otherlambda) .and. &
                                       mod(md,otherlambda) == mod(pd,otherlambda) .and. &
                                       mod(me,lambda) == mod(pe,lambda) )  then !! alpha -> alpha, beta -> beta
                                     call Vector_constructor (unoccupiedCode(i), int(order%values(i),4), 0.0_8 )
                                     unoccupiedCode(i)%values(1)=pa
                                     unoccupiedCode(i)%values(2)=pb
                                     call Vector_constructor (unoccupiedCode(j), int(order%values(j),4), 0.0_8 )
                                     unoccupiedCode(j)%values(1)=pc
                                     unoccupiedCode(j)%values(2)=pd
                                     call Vector_constructor (unoccupiedCode(k), int(order%values(k),4), 0.0_8 )
                                     unoccupiedCode(k)%values(1)=pe
                                     cc=cc+1
                                     c=c+1
                                     call Configuration_constructor(ConfigurationInteraction_instance%configurations(c), occupiedCode, unoccupiedCode, order, &
                                      ConfigurationInteraction_instance%numberOfConfigurations,c) 
                                  end if
                                end do
                              end do
                            end do
                          end do
                        end do  
                      end do  
                    end do  
                  end do
                end do
              end do
            end if
          end do
        end do

      end do !! species

!      do c = 1,  ConfigurationInteraction_instance%numberOfConfigurations 
!         call Configuration_show(  ConfigurationInteraction_instance%configurations(c) )
!      end do 

    case default

       call ConfigurationInteraction_exception( ERROR, "Configuration interactor constructor", "Correction level not implemented")

    end select


  end subroutine ConfigurationInteraction_buildConfigurations

  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine ConfigurationInteraction_buildCouplingMatrix()
    implicit none

    integer(8) :: a,b,c1,c2
    integer :: u,v
    integer :: i
    integer :: numberOfSpecies
    real(8) :: timeA, timeB
    integer(1) :: coupling
    integer(1), allocatable :: orbitalsA(:), orbitalsB(:)

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()
    coupling = 0

    do i = 1, numberOfSpecies
      call Matrix_constructorInteger1( ConfigurationInteraction_instance%couplingMatrix(i), &
        sum(ConfigurationInteraction_instance%numberOfStrings(i)%values), &
        sum(ConfigurationInteraction_instance%numberOfStrings(i)%values), int(0,1))
    end do  

!$    timeA = omp_get_wtime()
    do i = 1, numberOfSpecies 

      allocate (orbitalsA (ConfigurationInteraction_instance%numberOfOrbitals%values(i) ))
      allocate (orbitalsB (ConfigurationInteraction_instance%numberOfOrbitals%values(i) ))
      orbitalsA = 0
      orbitalsB = 0

      do a = 1, sum(ConfigurationInteraction_instance%numberOfStrings(i)%values)

        orbitalsA = 0
        do u = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i)
          orbitalsA( ConfigurationInteraction_instance%strings(i)%values(u,a) ) = 1
        end do

        do b = a, sum(ConfigurationInteraction_instance%numberOfStrings(i)%values)

          orbitalsB = 0
          do v = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i)
            orbitalsB( ConfigurationInteraction_instance%strings(i)%values(v,b) ) = 1
          end do
          
          ConfigurationInteraction_instance%couplingMatrix(i)%values(a,b) = & 
                      ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) - sum ( orbitalsA * orbitalsB ) 

        end do
      end do

      deallocate (orbitalsA )
      deallocate (orbitalsB )

    end do

!$  timeB = omp_get_wtime()
    !! symmetrize
    do i = 1, numberOfSpecies 
      do a = 1, sum(ConfigurationInteraction_instance%numberOfStrings(i)%values)
       do b = a, sum(ConfigurationInteraction_instance%numberOfStrings(i)%values)
         ConfigurationInteraction_instance%couplingMatrix(i)%values(b,a) = ConfigurationInteraction_instance%couplingMatrix(i)%values(a,b) 
        end do
      end do
    end do

!$  write(*,"(A,E10.3,A4)") "** TOTAL Elapsed Time for Building Coupling matrix : ", timeB - timeA ," (s)"

  end subroutine ConfigurationInteraction_buildCouplingMatrix

  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine ConfigurationInteraction_buildDiagonal()
    implicit none

    !type(Configuration) :: auxConfigurationA, auxConfigurationB
    !integer(2), allocatable :: auxConfiguration(:,:), auxConfigurationA(:,:)
    integer(8) :: a,b,c
    integer :: u,v
    integer :: i, j, ii, jj 
    integer :: s, numberOfSpecies, auxnumberOfSpecies
    integer :: size1, size2
    real(8) :: timeA, timeB
    integer(1) :: coupling
    integer(8) :: numberOfConfigurations
    real(8) :: CIenergy
    integer(8), allocatable :: indexConf(:)
    integer(8), allocatable :: excitationLevel(:)
!    real(8) :: coupingCoefficient 
!    integer(2), allocatable :: auxMatrix( :,:)
!    real(8), allocatable :: couplingMatrix(:,: )

!$  timeA = omp_get_wtime()
    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()
    coupling = 0
    CIenergy = 0

    !!!! interspecies
    !!do i = 1, numberOfSpecies
    !!  do j = i+1, numberOfSpecies
    !!    do ii = 2, size(ConfigurationInteraction_instance%numberOfStrings(i)%values, dim = 1)
    !!      do jj = 2, size(ConfigurationInteraction_instance%numberOfStrings(j)%values, dim = 1)
    !!        if ( ( ii - 1) + ( jj -1 ) <= ConfigurationInteraction_instance%maxCILevel ) &
    !!          numberOfConfigurations = numberOfConfigurations + &
    !!                                   (ConfigurationInteraction_instance%numberOfStrings(i)%values(ii)) * &
    !!                                   (ConfigurationInteraction_instance%numberOfStrings(i)%values(jj)) 
    !!      end do
    !!    end do
    !!  end do
    !!end do

    s = 0
    c = 0
    numberOfConfigurations = 0

    allocate ( excitationLevel ( numberOfSpecies ) )
    excitationLevel = 0
    !! call recursion 
    auxnumberOfSpecies = ConfigurationInteraction_numberOfConfigurationsRecursion(s, numberOfSpecies,  numberOfConfigurations) 

    call Vector_constructor8 ( ConfigurationInteraction_instance%diagonalHamiltonianMatrix2, &
                              numberOfConfigurations, 0.0_8 ) 

    ConfigurationInteraction_instance%numberOfConfigurations = numberOfConfigurations 
    allocate ( indexConf ( numberOfSpecies ) )
    indexConf = 0
    !! call recursion
    s = 0
    c = 0
    auxnumberOfSpecies = ConfigurationInteraction_buildDiagonalRecursion( s, numberOfSpecies, indexConf,  c )

    deallocate ( indexConf )
    deallocate ( excitationLevel )

!$  timeB = omp_get_wtime()
!$  write(*,"(A,E10.3,A4)") "** TOTAL Elapsed Time for Building diagonal matrix : ", timeB - timeA ," (s)"
    print *, "nconf", numberOfConfigurations
    print *, "H_0",  ConfigurationInteraction_instance%diagonalHamiltonianMatrix2%values(1)

  end subroutine ConfigurationInteraction_buildDiagonal

recursive  function ConfigurationInteraction_numberOfConfigurationsRecursion(s, numberOfSpecies, c) result (os)
    implicit none

    integer(8) :: a,b,c
    integer :: u,v
    integer :: i, j, ii, jj 
    integer :: s, numberOfSpecies
    integer :: os,is

    is = s + 1
    if ( is < numberOfSpecies ) then
      do i = 1, size(ConfigurationInteraction_instance%numberOfStrings(is)%values, dim = 1)
        do a = 1, ConfigurationInteraction_instance%numberOfStrings(is)%values(i)
          os = ConfigurationInteraction_numberOfConfigurationsRecursion( is, numberOfSpecies, c )
        end do
      end do

    else 
      os = is
      do i = 1, size(ConfigurationInteraction_instance%numberOfStrings(is)%values, dim = 1)
        do a = 1, ConfigurationInteraction_instance%numberOfStrings(is)%values(i)
          c = c + 1
        end do
      end do
    end if

  end function ConfigurationInteraction_numberOfConfigurationsRecursion


recursive  function ConfigurationInteraction_buildDiagonalRecursion(s, numberOfSpecies, indexConf, c) result (os)
    implicit none

    integer(8) :: a,b,c
    integer :: u,v
    integer :: i, j, ii, jj 
    integer :: s, numberOfSpecies
    integer :: os,is
    integer :: size1, size2
    integer(8) :: indexConf(:)
    real(8) :: timeA, timeB
    integer(1) :: coupling
    integer(8) :: numberOfConfigurations
    real(8) :: CIenergy
    integer :: ssize

    is = s + 1
    if ( is < numberOfSpecies ) then
      ssize = 0
      do i = 1, size(ConfigurationInteraction_instance%numberOfStrings(is)%values, dim = 1)
        do a = 1, ConfigurationInteraction_instance%numberOfStrings(is)%values(i)
          !indexConf(is,1) = sum(ConfigurationInteraction_instance%numberOfStrings(is)%values(1:i-1))
          indexConf(is) = ssize + a
          os = ConfigurationInteraction_buildDiagonalRecursion( is, numberOfSpecies, indexConf, c )
        end do
        ssize = ssize + ConfigurationInteraction_instance%numberOfStrings(is)%values(i)
      end do

    else 
      os = is
      ssize = 0
      do i = 1, size(ConfigurationInteraction_instance%numberOfStrings(is)%values, dim = 1)
        do a = 1, ConfigurationInteraction_instance%numberOfStrings(is)%values(i)
          c = c + 1
          indexConf(is) = ssize + a
          ConfigurationInteraction_instance%diagonalHamiltonianMatrix2%values(c) = &
                              ConfigurationInteraction_calculateEnergyZero ( indexConf )

        end do
        ssize = ssize + ConfigurationInteraction_instance%numberOfStrings(is)%values(i)
      end do
    end if

  end function ConfigurationInteraction_buildDiagonalRecursion

  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine ConfigurationInteraction_getInitialIndexes()
    implicit none

    !type(Configuration) :: auxConfigurationA, auxConfigurationB
    !integer(2), allocatable :: auxConfiguration(:,:), auxConfigurationA(:,:)
    integer(8) :: a,b,c
    integer :: u,v
    integer :: i, j, ii, jj 
    integer :: s, numberOfSpecies, auxnumberOfSpecies
    integer :: size1, size2
    real(8) :: timeA, timeB
    integer(1) :: coupling
    integer(8) :: numberOfConfigurations
    real(8) :: CIenergy
    integer(8), allocatable :: indexConf(:)

!$  timeA = omp_get_wtime()

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()

    s = 0
    c = 0

    call Matrix_constructorInteger ( ConfigurationInteraction_instance%auxConfigurations, int( numberOfSpecies,8), &
          int(CONTROL_instance%CI_SIZE_OF_GUESS_MATRIX,8), 0 )

    !! call recursion

    allocate ( indexConf ( numberOfSpecies ) )

    s = 0
    c = 0
    indexConf = 0
    auxnumberOfSpecies = ConfigurationInteraction_getIndexesRecursion( s, numberOfSpecies, indexConf, c )

    deallocate ( indexConf )

    do a = 1, numberOfConfigurations
    !print *, a, ConfigurationInteraction_instance%diagonalHamiltonianMatrix2%values(a)
    end do 

!$  timeB = omp_get_wtime()

!$  write(*,"(A,E10.3,A4)") "** TOTAL Elapsed Time for getting initial indexes : ", timeB - timeA ," (s)"

  end subroutine ConfigurationInteraction_getInitialIndexes

recursive  function ConfigurationInteraction_getIndexesRecursion(s, numberOfSpecies, indexConf, c) result (os)
    implicit none

    integer(8) :: a,b,c
    integer :: u,v
    integer :: i, j, ii, jj
    integer :: s, ss, numberOfSpecies
    integer :: os,is
    integer :: size1, size2
    integer(8) :: indexConf(:)
    integer(1) :: coupling
    integer :: ssize

    is = s + 1
    if ( is < numberOfSpecies ) then
      ssize = 0
      do i = 1, size(ConfigurationInteraction_instance%numberOfStrings(is)%values, dim = 1)
        do a = 1, ConfigurationInteraction_instance%numberOfStrings(is)%values(i)
          indexConf(is) = ssize + a
          os = ConfigurationInteraction_getIndexesRecursion( is, numberOfSpecies, indexConf, c )
        end do
        ssize = ssize + ConfigurationInteraction_instance%numberOfStrings(is)%values(i)
      end do

    else 
      os = is
      ssize = 0
      do i = 1, size(ConfigurationInteraction_instance%numberOfStrings(is)%values, dim = 1)
        do a = 1, ConfigurationInteraction_instance%numberOfStrings(is)%values(i)
          c = c + 1
          indexConf(is) = ssize + a
          do u = 1, CONTROL_instance%CI_SIZE_OF_GUESS_MATRIX 
            if ( c ==  ConfigurationInteraction_instance%auxIndexCIMatrix%values(u) ) then
              do ss = 1, numberOfSpecies
                ConfigurationInteraction_instance%auxConfigurations%values(ss,u) = indexConf(ss) 
              end do
            end if
           end do
        end do
        ssize = ssize + ConfigurationInteraction_instance%numberOfStrings(is)%values(i)
      end do
    end if

  end function ConfigurationInteraction_getIndexesRecursion

  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine ConfigurationInteraction_calculateInitialCIMatrix()
    implicit none

    integer(8) :: a,b,aa,bb
    integer :: u,v
    integer :: i
    integer :: numberOfSpecies
    real(8) :: timeA1, timeB1
    integer(1) :: coupling
    integer(1), allocatable :: orbitalsA(:), orbitalsB(:)
    integer :: initialCIMatrixSize 
    integer :: nproc
    integer(8), allocatable :: indexConfA(:)
    integer(8), allocatable :: indexConfB(:)

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()

    initialCIMatrixSize = CONTROL_instance%CI_SIZE_OF_GUESS_MATRIX 

    allocate ( indexConfA ( numberOfSpecies ) )
    allocate ( indexConfB ( numberOfSpecies ) )

!$    timeA1 = omp_get_wtime()

    do a = 1, initialCIMatrixSize 
      aa = ConfigurationInteraction_instance%auxIndexCIMatrix%values(a)
      do b = a, initialCIMatrixSize 
        bb = ConfigurationInteraction_instance%auxIndexCIMatrix%values(b)
        coupling = 0

        indexConfA = 0
        indexConfB = 0

        do i = 1, numberOfSpecies

          allocate (orbitalsA ( ConfigurationInteraction_instance%numberOfOrbitals%values(i) ))
          allocate (orbitalsB ( ConfigurationInteraction_instance%numberOfOrbitals%values(i) ))
          orbitalsA = 0
          orbitalsB = 0

          indexConfA(i) =  ConfigurationInteraction_instance%auxConfigurations%values(i,a)
          indexConfB(i) =  ConfigurationInteraction_instance%auxConfigurations%values(i,b)

          do u = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i)
            orbitalsA( ConfigurationInteraction_instance%strings(i)%values(u,indexConfA(i) ) ) = 1
            !orbitalsA( ConfigurationInteraction_instance%strings(i)%values(u,aa) ) = 1
          end do
          do v = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i)
            orbitalsB( ConfigurationInteraction_instance%strings(i)%values(v,indexConfB(i) ) ) = 1
          end do
          coupling = coupling + &
            ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i) - sum ( orbitalsA * orbitalsB ) 

          deallocate (orbitalsA )
          deallocate (orbitalsB )

        end do
        if ( coupling  == 0 ) then
          ConfigurationInteraction_instance%initialHamiltonianMatrix%values(a,b) = &
            ConfigurationInteraction_instance%diagonalHamiltonianMatrix2%values(a) 
            !ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values(aa) or this

        else if (  coupling == 1 ) then

          ConfigurationInteraction_instance%initialHamiltonianMatrix%values(a,b) = &
            ConfigurationInteraction_calculateEnergyOne ( indexConfA, indexConfB )

        else if ( coupling  == 2 ) then

          ConfigurationInteraction_instance%initialHamiltonianMatrix%values(a,b) = &
            ConfigurationInteraction_calculateEnergyTwo ( indexConfA, indexConfB )

        end if
 

      end do


    end do

    deallocate ( indexConfB )
    deallocate ( indexConfA )

!$  timeB1 = omp_get_wtime()
    !! symmetrize
    do a = 1, initialCIMatrixSize 
      do b = a, initialCIMatrixSize 

         ConfigurationInteraction_instance%initialHamiltonianMatrix%values(b,a) = &
            ConfigurationInteraction_instance%initialHamiltonianMatrix%values(a,b) 
      end do
    end do

!$  write(*,"(A,E10.3,A4)") "** TOTAL Elapsed Time for Calculating initial CI matrix : ", timeB1 - timeA1 ," (s)"

  end subroutine ConfigurationInteraction_calculateInitialCIMatrix 


  subroutine ConfigurationInteraction_buildInitialCIMatrix2()
    implicit none

    type(Configuration) :: auxConfigurationA, auxConfigurationB
    type (Vector8) :: diagonalHamiltonianMatrix
!    type (Vector) :: initialEigenValues
!    type (Matrix) :: initialHamiltonianMatrix
    integer :: a,b,c,aa,bb
    real(8) :: timeA, timeB
    real(8) :: CIenergy
    integer :: initialCIMatrixSize 
    integer :: nproc

!$    timeA = omp_get_wtime()
    call ConfigurationInteraction_buildDiagonal()
    initialCIMatrixSize = CONTROL_instance%CI_SIZE_OF_GUESS_MATRIX 

    call Vector_constructorInteger8 ( ConfigurationInteraction_instance%auxIndexCIMatrix, &
                              ConfigurationInteraction_instance%numberOfConfigurations, 0_8 ) !hmm
    do a = 1, ConfigurationInteraction_instance%numberOfConfigurations
      ConfigurationInteraction_instance%auxIndexCIMatrix%values(a)= a
    end do


   !! save the unsorted diagonal Matrix

    ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values = ConfigurationInteraction_instance%diagonalHamiltonianMatrix2%values
!   if ( trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) == "JADAMILU" .or. &
!      trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) == "ARPACK"  ) then
!
!     call Vector_copyConstructor8 (  ConfigurationInteraction_instance%diagonalHamiltonianMatrix, diagonalHamiltonianMatrix)
!
!   end if


   !! To get only the lowest 300 values.
   call Vector_reverseSortElements8( ConfigurationInteraction_instance%diagonalHamiltonianMatrix2, &
          ConfigurationInteraction_instance%auxIndexCIMatrix, int(initialCIMatrixSize,8))

   call Matrix_constructor ( ConfigurationInteraction_instance%initialHamiltonianMatrix, int(initialCIMatrixSize,8) , &
                               int(initialCIMatrixSize,8) , 0.0_8 ) 



    !! get the configurations for the initial hamiltonian matrix
    call ConfigurationInteraction_getInitialIndexes()

    call ConfigurationInteraction_calculateInitialCIMatrix()

    !! diagonalize the initial matrix
    call Vector_constructor8 ( ConfigurationInteraction_instance%initialEigenValues, int(CONTROL_instance%NUMBER_OF_CI_STATES,8),  0.0_8)

    call Matrix_constructor (ConfigurationInteraction_instance%initialEigenVectors, &
          int(initialCIMatrixSize,8), &
          int(CONTROL_instance%NUMBER_OF_CI_STATES,8), 0.0_8)

!!   call Matrix_copyConstructor ( ConfigurationInteraction_instance%initialHamiltonianMatrix2, ConfigurationInteraction_instance%initialHamiltonianMatrix ) !! hmm


    call Matrix_eigen_select ( ConfigurationInteraction_instance%initialHamiltonianMatrix, &
           ConfigurationInteraction_instance%initialEigenValues, &
           1, int(CONTROL_instance%NUMBER_OF_CI_STATES,4), &  
           eigenVectors = ConfigurationInteraction_instance%initialEigenVectors, &
           flags = int(SYMMETRIC,4))
    
    print *, "EigenValue 1", ConfigurationInteraction_instance%initialEigenValues%values(1)

!$    timeB = omp_get_wtime()
!$    write(*,"(A,F10.3,A4)") "** TOTAL Elapsed Time for Building Initial CI matrix2 : ", timeB - timeA ," (s)"

  end subroutine ConfigurationInteraction_buildInitialCIMatrix2


  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine ConfigurationInteraction_buildHamiltonianMatrix2()
    implicit none

    integer(8) :: a,b,c
    integer :: u,v
    integer :: i, j, ii, jj 
    integer :: s, numberOfSpecies, auxnumberOfSpecies
    integer :: size1, size2
    real(8) :: timeA, timeB
    integer(1) :: coupling
    integer(8) :: numberOfConfigurations
    real(8) :: CIenergy
    integer(8), allocatable :: indexConf(:)
    integer(8), allocatable :: excitationLevel(:)

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()

    s = 0
    c = 0
    numberOfConfigurations = 0

    allocate ( excitationLevel ( numberOfSpecies ) )
    excitationLevel = 0

    !! get numberOfConfigurations
    auxnumberOfSpecies = ConfigurationInteraction_numberOfConfigurationsRecursion(s, numberOfSpecies,  numberOfConfigurations) 
    print *, "nconf", numberOfConfigurations

    !! coupling vector
    do i = 1, numberOfSpecies
      call Vector_constructorInteger1( ConfigurationInteraction_instance%couplingVector(i), &
        sum(ConfigurationInteraction_instance%numberOfStrings(i)%values), int(0,1))
      !! here should be saved the excitation level, 
      call Matrix_constructorInteger (ConfigurationInteraction_instance%couplingOneTwo(i), &
        3_8, int(sum(ConfigurationInteraction_instance%numberOfStrings(i)%values),8), 0_4)

    end do  

!!    call Matrix_Constructor(ConfigurationInteraction_instance%hamiltonianMatrix2, numberOfConfigurations, numberOfConfigurations,0.0_8)


    allocate ( indexConf ( numberOfSpecies ) )
    indexConf = 0
    !! call recursion
    s = 0
    c = 0
!!!$  timeA = omp_get_wtime()
!!!    auxnumberOfSpecies = ConfigurationInteraction_buildMatrixRecursion( s, numberOfSpecies, indexConf,  c )
!!!$  timeB = omp_get_wtime()

    do a = 1,numberOfConfigurations
!      print *, a, ConfigurationInteraction_instance%hamiltonianMatrix2%values(a,a)
    end do

    deallocate ( indexConf )
    deallocate ( excitationLevel )

!$  write(*,"(A,E10.3,A4)") "** TOTAL Elapsed Time for HamiltonianMatrix 2 : ", timeB - timeA ," (s)"

  end subroutine ConfigurationInteraction_buildHamiltonianMatrix2

recursive  function ConfigurationInteraction_buildMatrixRecursion(s, numberOfSpecies, indexConf, c, v, w, nx) result (os)
    implicit none

    integer(8) :: a,b,c
    integer :: i, j, ii, jj 
    integer :: s, numberOfSpecies
    integer :: os,is
    integer :: size1, size2
    integer(8) :: indexConf(:)
    real(8) :: timeA, timeB
    integer(1) :: coupling
    integer(8) :: numberOfConfigurations
    real(8) :: CIenergy
    integer(8) :: nx 
    real(8) :: v(nx)
    real(8) :: w(nx)

    is = s + 1
    if ( is < numberOfSpecies ) then
      do i = 1, size(ConfigurationInteraction_instance%numberOfStrings(is)%values, dim = 1)
        do a = 1, ConfigurationInteraction_instance%numberOfStrings(is)%values(i)
          !indexConf(is,1) = sum(ConfigurationInteraction_instance%numberOfStrings(is)%values(1:i-1))
          indexConf(is) = sum(ConfigurationInteraction_instance%numberOfStrings(is)%values(1:i-1)) + a
          os = ConfigurationInteraction_buildMatrixRecursion( is, numberOfSpecies, indexConf, c, v, w, nx )
        end do
      end do

    else 
      os = is
      do i = 1, size(ConfigurationInteraction_instance%numberOfStrings(is)%values, dim = 1)
        do a = 1, ConfigurationInteraction_instance%numberOfStrings(is)%values(i)
          c = c + 1
          indexConf(is) = sum(ConfigurationInteraction_instance%numberOfStrings(is)%values(1:i-1)) + a
          if ( abs(v(c)) > 1E-8 )  call ConfigurationInteraction_buildRow( indexConf, c, w, v(c), nx)
        end do
      end do
    end if

  end function ConfigurationInteraction_buildMatrixRecursion

  subroutine ConfigurationInteraction_buildRow( indexConfA, c, w, vc, nx)
    implicit none

    integer(8) :: a,b,c,c1,c2,aa,d
    integer :: uu,vv
    integer :: i
    integer :: numberOfSpecies, auxnumberOfSpecies,s
    real(8) :: timeA, timeB
    integer(1) :: coupling
    integer(1), allocatable :: orbitalsA(:), orbitalsB(:)
    integer(1), allocatable :: couplingOrder(:)
    integer(8) :: indexConfA(:)
    integer(8), allocatable :: indexConfB(:)
    integer(4), allocatable :: nCouplingOneTwo (:,:)
    real(8) :: vc
    integer(8) :: nx 
    real(8) :: w(nx)

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()
    coupling = 0

    do i = 1, numberOfSpecies 
      ConfigurationInteraction_instance%couplingOneTwo(i)%values = 0
    end do

    allocate ( couplingOrder ( numberOfSpecies )) !! 0, 1, 2
    couplingOrder = 0

    allocate ( nCouplingOneTwo (3, numberOfSpecies )) !! 0, 1, 2
    nCouplingOneTwo = 0


    do i = 1, numberOfSpecies 

      allocate (orbitalsA (ConfigurationInteraction_instance%numberOfOrbitals%values(i) ))
      allocate (orbitalsB (ConfigurationInteraction_instance%numberOfOrbitals%values(i) ))
      orbitalsA = 0
      orbitalsB = 0

      aa = indexconfA(i)

      nCouplingOneTwo(1,i) = 1
      ConfigurationInteraction_instance%couplingOneTwo(i)%values(1,nCouplingOneTwo(1,i)) = aa 

      do uu = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i)
        orbitalsA( ConfigurationInteraction_instance%strings(i)%values(uu,aa) ) = 1
      end do

      Configurationinteraction_instance%couplingVector(i)%values = 0

      do b = 1, sum(ConfigurationInteraction_instance%numberOfStrings(i)%values)

        orbitalsB = 0
        do vv = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i)
          orbitalsB( ConfigurationInteraction_instance%strings(i)%values(vv,b) ) = 1
        end do
          
        Configurationinteraction_instance%couplingVector(i)%values(b) = &
            configurationinteraction_instance%numberOfOccupiedOrbitals%values(i) - sum ( orbitalsA * orbitalsB ) 

        if ( Configurationinteraction_instance%couplingVector(i)%values(b) == 1 ) then
          nCouplingOneTwo(2,i) = nCouplingOneTwo(2,i) + 1
          ConfigurationInteraction_instance%couplingOneTwo(i)%values(2,nCouplingOneTwo(2,i)) = b 
          !! save it in the same vector...
        end if

        if ( Configurationinteraction_instance%couplingVector(i)%values(b) == 2 ) then
          nCouplingOneTwo(3,i) = nCouplingOneTwo(3,i) + 1
          ConfigurationInteraction_instance%couplingOneTwo(i)%values(3,nCouplingOneTwo(3,i)) = b 
        end if

      end do

      deallocate (orbitalsA )
      deallocate (orbitalsB )

    end do

    allocate ( indexConfB ( numberOfSpecies ) )
    indexConfB = 0
    !! call recursion
    s = 0
    d = 0
    auxnumberOfSpecies = ConfigurationInteraction_buildRowRecursionFirst( s, numberOfSpecies, couplingOrder, &
                            indexConfA, indexConfB, nCouplingOneTwo, c, w, vc, nx )
    

    deallocate ( indexConfB )
    deallocate ( nCouplingOneTwo )
    deallocate ( couplingOrder ) 

  end subroutine ConfigurationInteraction_buildRow
 
recursive  function ConfigurationInteraction_buildRowRecursionFirst(s, numberOfSpecies, couplingOrder, &
                                          indexConfA, indexConfB, nCouplingOneTwo, c, w, vc, nx) result (os)
    implicit none

    integer(8) :: a,b,c,d
    integer :: u,v
    integer :: i, j, ii, jj 
    integer :: s, numberOfSpecies
    integer :: os,is,auxis, auxos
    integer :: size1, size2
    integer(1) :: couplingOrder(:)
    integer(8) :: indexConfA(:)
    integer(8) :: indexConfB(:)
    real(8) :: timeA, timeB
    integer(1) :: coupling
    integer(8) :: numberOfConfigurations
    integer(4) :: nCouplingOneTwo (:,:)
    real(8) :: vc
    integer(8) :: nx 
    real(8) :: w(nx)

    is = s + 1
    if ( is < numberOfSpecies ) then
      if ( sum ( couplingOrder) <= 2 ) then
        do i = 1, 3 - sum ( couplingOrder ) !! 0,1,2
          couplingOrder(is) = i-1
          couplingOrder(is+1:) = 0
          os = ConfigurationInteraction_buildRowRecursionFirst( is, numberOfSpecies, couplingOrder, &
                            indexConfA, indexConfB, nCouplingOneTwo, c, w, vc, nx )
        end do
      end if
    else 
      if ( sum ( couplingOrder) <= 2 ) then
        do i = 1, 3 - sum ( couplingOrder ) !! 0,1,2
          couplingOrder(is) = i-1
          couplingOrder(is+1:) = 0
          os = is
          if ( sum ( couplingOrder ) == 0 ) then
            !ConfigurationInteraction_instance%hamiltonianMatrix2%values(c,c) = &
            !  ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values(c) 
            w(c) = w(c) + vc*ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values(c) 


          else if ( sum ( couplingOrder ) == 1 ) then

            auxis = 0
            auxos = ConfigurationInteraction_buildRowRecursionSecondOne( auxis, numberOfSpecies, couplingOrder, &
                            indexConfA, indexConfB, nCouplingOneTwo, c, w, vc, nx  )

          else if ( sum ( couplingOrder ) == 2 ) then

            auxis = 0
            auxos = ConfigurationInteraction_buildRowRecursionSecondTwo( auxis, numberOfSpecies, couplingOrder, &
                            indexConfA, indexConfB, nCouplingOneTwo, c, w, vc, nx )

          end if
        end do
      end if
    end if

  end function ConfigurationInteraction_buildRowRecursionFirst

recursive  function ConfigurationInteraction_buildRowRecursionSecondOne(s, numberOfSpecies, couplingOrder, &
                                          indexConfA, indexConfB, nCouplingOneTwo, c, w, vc, nx) result (os)
    implicit none

    integer(8) :: a,b,c,d
    integer :: u,v
    integer :: i, j, ii, jj 
    integer :: s, numberOfSpecies
    integer :: os,is
    integer :: size1, size2
    integer(1) :: couplingOrder(:)
    integer(8) :: indexConfA(:)
    integer(8) :: indexConfB(:)
    real(8) :: timeA, timeB
    integer(1) :: coupling
    integer(8) :: numberOfConfigurations
    real(8) :: CIenergy
    integer(4) :: nCouplingOneTwo (:,:)
    real(8) :: vc
    integer(8) :: nx 
    real(8) :: w(nx)


    is = s + 1
    i = couplingOrder(is)+1

    !if ( c == 1 ) print *, 1, couplingOrder
    if ( is < numberOfSpecies ) then
      do a = 1, nCouplingOneTwo(i,is) 
        indexConfB(is) = ConfigurationInteraction_instance%couplingOneTwo(is)%values(i,a) 
        os = ConfigurationInteraction_buildRowRecursionSecondOne( is, numberOfSpecies, couplingOrder, &
                        indexConfA, indexConfB, nCouplingOneTwo, c, w, vc, nx )
      end do
    else 
      os = is
      !d = d + 1
      !do a = 1, nCouplingOneTwo(i,is) 
      do a = 1, nCouplingOneTwo(i,is) 
        indexConfB(is) = ConfigurationInteraction_instance%couplingOneTwo(is)%values(i,a) 
        d = ConfigurationInteraction_getIndex ( indexConfB ) 
        w(d) = w(d) + &
            vc*ConfigurationInteraction_calculateEnergyOne ( indexConfA, indexConfB )
        !! call
        !ConfigurationInteraction_instance%hamiltonianMatrix2%values(c,d) = &
        !    ConfigurationInteraction_instance%hamiltonianMatrix2%values(c,d) + &
        !    ConfigurationInteraction_calculateEnergyOne ( indexConfA, indexConfB )

       !if ( c == 1 ) print *, 1, ConfigurationInteraction_calculateEnergyOne ( indexConfA, indexConfB )
      end do
    end if

  end function ConfigurationInteraction_buildRowRecursionSecondOne

recursive  function ConfigurationInteraction_buildRowRecursionSecondTwo(s, numberOfSpecies, couplingOrder, &
                                          indexConfA, indexConfB, nCouplingOneTwo, c, w, vc, nx) result (os)
    implicit none

    integer(8) :: a,b,c,d
    integer :: u,v
    integer :: i, j, ii, jj 
    integer :: s, numberOfSpecies
    integer :: os,is
    integer :: size1, size2
    integer(1) :: couplingOrder(:)
    integer(8) :: indexConfA(:)
    integer(8) :: indexConfB(:)
    real(8) :: timeA, timeB
    integer(1) :: coupling
    integer(8) :: numberOfConfigurations
    real(8) :: CIenergy
    integer(4) :: nCouplingOneTwo (:,:)
    real(8) :: vc
    integer(8) :: nx 
    real(8) :: w(nx)

    is = s + 1
    i = couplingOrder(is)+1

    !if ( c == 1 ) print *, 2, couplingOrder
    if ( is < numberOfSpecies ) then
      do a = 1, nCouplingOneTwo(i,is) 
        indexConfB(is) = ConfigurationInteraction_instance%couplingOneTwo(is)%values(i,a) 
        os = ConfigurationInteraction_buildRowRecursionSecondTwo( is, numberOfSpecies, couplingOrder, &
                        indexConfA, indexConfB, nCouplingOneTwo, c, w, vc, nx )
      end do
    else 
      os = is
      !do a = 1, nCouplingOneTwo(i,is) 
      do a = 1, nCouplingOneTwo(i,is) 
        indexConfB(is) = ConfigurationInteraction_instance%couplingOneTwo(is)%values(i,a) 
        d = ConfigurationInteraction_getIndex ( indexConfB ) 
        !! call
        w(d) = w(d) + &
            vc*ConfigurationInteraction_calculateEnergyTwo ( indexConfA, indexConfB )

        !ConfigurationInteraction_instance%hamiltonianMatrix2%values(c,d) = &
        !    ConfigurationInteraction_instance%hamiltonianMatrix2%values(c,d) + &
        !    ConfigurationInteraction_calculateEnergyTwo ( indexConfA, indexConfB )

      end do
    end if

  end function ConfigurationInteraction_buildRowRecursionSecondTwo



  function ConfigurationInteraction_getIndex ( indexConf ) result ( output )
    implicit none
    integer(8) :: indexConf(:)
    integer(8) :: output, ssize
    integer :: i,j, numberOfSpecies

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()
    output = 0 
    do i = 1, numberOfSpecies
      ssize = 1 
      do j = i + 1, numberOfSpecies
        ssize = ssize * sum(ConfigurationInteraction_instance%numberOfStrings(j)%values)
      end do
      output = output + ( indexConf(i) - 1 ) * ssize
    end do
    output = output + 1

    !sum ( ConfigurationInteraction_instance%numberOfStrings(i)%values )


  end function ConfigurationInteraction_getIndex

  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine ConfigurationInteraction_buildHamiltonianMatrix()
    implicit none

    !type(Configuration) :: auxConfigurationA, auxConfigurationB
    !integer(2), allocatable :: auxConfiguration(:,:), auxConfigurationA(:,:)
    integer(8) :: a,b
    integer :: size1, size2
    real(8) :: timeA, timeB
    real(8) :: CIenergyb!, CIenergy
!    real(8) :: coupingCoefficient 
!    integer(2), allocatable :: auxMatrix( :,:)
!    real(8), allocatable :: couplingMatrix(:,: )

    size1 = size(ConfigurationInteraction_instance%configurations(1)%occupations, dim=1)
    size2 = size(ConfigurationInteraction_instance%configurations(1)%occupations, dim=2) 

    allocate (ConfigurationInteraction_instance%auxconfs (size1,size2, ConfigurationInteraction_instance%numberOfConfigurations ))
!    allocate(couplingMatrix( ConfigurationInteraction_instance%numberOfConfigurations , &
!       ConfigurationInteraction_instance%numberOfConfigurations))

    do a=1, ConfigurationInteraction_instance%numberOfConfigurations
        ConfigurationInteraction_instance%auxconfs(:,:,a) = ConfigurationInteraction_instance%configurations(a)%occupations
    end do

    CIenergyb = 0

!$    timeA = omp_get_wtime()
    do a=1, ConfigurationInteraction_instance%numberOfConfigurations
!$omp parallel &
!$omp& private(b,CIenergyb),&
!$omp& shared(a,ConfigurationInteraction_instance, HartreeFock_instance,size1,size2) 
!$omp do 
      do b=a, ConfigurationInteraction_instance%numberOfConfigurations

          CIenergyb = ConfigurationInteraction_calculateCoupling( a, b, size1, size2 )
          ConfigurationInteraction_instance%hamiltonianMatrix%values(b,a) = CIenergyB
      end do
!$omp end parallel
    end do

    !! symmetrize

!$  timeB = omp_get_wtime()
    
    do a=1, ConfigurationInteraction_instance%numberOfConfigurations
      do b=a, ConfigurationInteraction_instance%numberOfConfigurations
         ConfigurationInteraction_instance%hamiltonianMatrix%values(a,b)=ConfigurationInteraction_instance%hamiltonianMatrix%values(b,a)
      end do
    end do

!$  write(*,"(A,E10.3,A4)") "** TOTAL Elapsed Time for Building CI matrix : ", timeB - timeA ," (s)"

  end subroutine ConfigurationInteraction_buildHamiltonianMatrix

  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine ConfigurationInteraction_buildInitialCIMatrix()
    implicit none

    type(Configuration) :: auxConfigurationA, auxConfigurationB
    type (Vector8) :: diagonalHamiltonianMatrix
!    type (Vector) :: initialEigenValues
!    type (Matrix) :: initialHamiltonianMatrix
    integer :: a,b,c,aa,bb
    real(8) :: timeA, timeB
    real(8) :: CIenergy
    integer :: initialCIMatrixSize 
    integer :: nproc

    initialCIMatrixSize = CONTROL_instance%CI_SIZE_OF_GUESS_MATRIX 

    timeA = omp_get_wtime()
    !a,b configuration iterators
    call Configuration_copyConstructor ( ConfigurationInteraction_instance%configurations(1), auxConfigurationA )
    call Configuration_copyConstructor ( ConfigurationInteraction_instance%configurations(1), auxConfigurationB )

    call Vector_constructorInteger8 ( ConfigurationInteraction_instance%auxIndexCIMatrix, &
                              ConfigurationInteraction_instance%numberOfConfigurations, 0_8 ) 

    call Vector_constructor8 ( diagonalHamiltonianMatrix, &
                              ConfigurationInteraction_instance%numberOfConfigurations, 0.0_8 ) 

    print *, "  OMP Number of threads: " , omp_get_max_threads()
    nproc = omp_get_max_threads()

    call omp_set_num_threads(omp_get_max_threads())
    call omp_set_num_threads(nproc)

!$omp parallel & 
!$omp& private(a,b,CIenergy,auxConfigurationA,auxConfigurationB),&
!$omp& shared(ConfigurationInteraction_instance, HartreeFock_instance,diagonalHamiltonianMatrix)
!$omp do 
    do a=1, ConfigurationInteraction_instance%numberOfConfigurations
      auxConfigurationA%occupations = ConfigurationInteraction_instance%configurations(a)%occupations
      auxConfigurationB%occupations = ConfigurationInteraction_instance%configurations(a)%occupations
      CIenergy = ConfigurationInteraction_calculateCIenergyC(&
                      auxConfigurationA, auxConfigurationB )

      diagonalHamiltonianMatrix%values(a) = CIenergy
    end do
!$omp end do nowait
!$omp end parallel
    timeB = omp_get_wtime()
    write(*,"(A,F10.3,A4)") "** TOTAL Elapsed Time for Building Initial CI matrix : ", timeB - timeA ," (s)"


   !! save the unsorted diagonal Matrix )
   if ( trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) == "JADAMILU" .or. &
      trim(String_getUppercase(CONTROL_instance%CI_DIAGONALIZATION_METHOD)) == "ARPACK"  ) then

     call Vector_copyConstructor8 (  ConfigurationInteraction_instance%diagonalHamiltonianMatrix, diagonalHamiltonianMatrix)

   end if

   !! To get only the lowest 300 values.
   call Vector_reverseSortElements8(diagonalHamiltonianMatrix, ConfigurationInteraction_instance%auxIndexCIMatrix, int(initialCIMatrixSize,8))

   call Matrix_constructor ( ConfigurationInteraction_instance%initialHamiltonianMatrix, int(initialCIMatrixSize,8) , &
                               int(initialCIMatrixSize,8) , 0.0_8 ) 


    do a=1, initialCIMatrixSize 
      ConfigurationInteraction_instance%initialHamiltonianMatrix%values(a,a) = diagonalHamiltonianMatrix%values(a)
      aa = ConfigurationInteraction_instance%auxIndexCIMatrix%values(a)
      do b=a+1, initialCIMatrixSize 
        bb = ConfigurationInteraction_instance%auxIndexCIMatrix%values(b)
        auxConfigurationA%occupations = ConfigurationInteraction_instance%configurations(aa)%occupations
        auxConfigurationB%occupations = ConfigurationInteraction_instance%configurations(bb)%occupations
        ConfigurationInteraction_instance%initialHamiltonianMatrix%values(a,b) = ConfigurationInteraction_calculateCIenergyC( &
                      auxConfigurationA, auxConfigurationB )
      end do
    end do

    !! diagonalize the initial matrix
    call Vector_constructor8 ( ConfigurationInteraction_instance%initialEigenValues, int(CONTROL_instance%NUMBER_OF_CI_STATES,8),  0.0_8)

    call Matrix_constructor (ConfigurationInteraction_instance%initialEigenVectors, &
           int(initialCIMatrixSize,8), &
           int(CONTROL_instance%NUMBER_OF_CI_STATES,8), 0.0_8)

   call Matrix_copyConstructor ( ConfigurationInteraction_instance%initialHamiltonianMatrix2, ConfigurationInteraction_instance%initialHamiltonianMatrix ) 


    call Matrix_eigen_select ( ConfigurationInteraction_instance%initialHamiltonianMatrix, ConfigurationInteraction_instance%initialEigenValues, &
           1, int(CONTROL_instance%NUMBER_OF_CI_STATES,4), &  
           eigenVectors = ConfigurationInteraction_instance%initialEigenVectors, &
           flags = int(SYMMETRIC,4))

    !! cleaning
    call Vector_destructor8 ( diagonalHamiltonianMatrix )
!    call Vector_destructor ( initialEigenValues )
!    call Matrix_destructor ( initialHamiltonianMatrix )
    print *, "EigenValues 1", ConfigurationInteraction_instance%initialEigenValues%values(1)


    timeB = omp_get_wtime()
    write(*,"(A,F10.3,A4)") "** TOTAL Elapsed Time for Building Initial CI matrix : ", timeB - timeA ," (s)"

  end subroutine ConfigurationInteraction_buildInitialCIMatrix

  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine ConfigurationInteraction_buildAndSaveCIMatrix()
    implicit none
    type(Configuration) :: auxConfigurationA, auxConfigurationB
    integer(8) :: a,b,c,d,n, nproc,cc
    real(8) :: timeA, timeB
    character(50) :: CIFile
    integer :: CIUnit
    real(8) :: CIenergy
    integer, allocatable :: indexArray(:),auxIndexArray(:)
    real(8), allocatable :: energyArray(:),auxEnergyArray(:)
    integer :: starting, ending, step, maxConfigurations
    character(50) :: fileNumberA, fileNumberB
    integer :: cmax
    integer :: maxStackSize, i, ia, ib, ssize, ci,cj, size1, size2
    integer :: nblocks

    size1 = size(ConfigurationInteraction_instance%configurations(1)%occupations, dim=1)
    size2 = size(ConfigurationInteraction_instance%configurations(1)%occupations, dim=2) 

    maxStackSize = CONTROL_instance%CI_STACK_SIZE 

    allocate (ConfigurationInteraction_instance%auxconfs (size1,size2, ConfigurationInteraction_instance%numberOfConfigurations ))

    do a=1, ConfigurationInteraction_instance%numberOfConfigurations
        ConfigurationInteraction_instance%auxconfs(:,:,a) = ConfigurationInteraction_instance%configurations(a)%occupations
    end do


    timeA = omp_get_wtime()

    CIFile = "lowdin.ci"
    CIUnit = 4

#ifdef intel
    open(unit=CIUnit, file=trim(CIFile), action = "write", form="unformatted", BUFFERED="YES")
#else
    open(unit=CIUnit, file=trim(CIFile), action = "write", form="unformatted")
#endif
    
    print *, "  OMP Number of threads: " , omp_get_max_threads()
    nproc = omp_get_max_threads()

    !call omp_set_num_threads(omp_get_max_threads())
    !call omp_set_num_threads(nproc)

    !if (allocated(cmax)) deallocate(cmax)
    !allocate(cmax(nproc))
    cmax = 0

    maxConfigurations = ConfigurationInteraction_instance%numberOfConfigurations
    if (allocated(indexArray )) deallocate(indexArray)
    allocate (indexArray(maxConfigurations))
    indexArray = 0
    if (allocated(energyArray )) deallocate(energyArray)
    allocate (energyArray(maxConfigurations))
    energyArray = 0

    do a=1, ConfigurationInteraction_instance%numberOfConfigurations

      !indexArray = 0
      energyArray = 0
      c = 0

!$omp parallel & 
!$omp& private(b,CIenergy),&
!$omp& shared(indexArray,energyArray, HartreeFock_instance),&
!$omp& shared(ConfigurationInteraction_instance) reduction (+:c)
!$omp do schedule(guided)
        do b= a, ConfigurationInteraction_instance%numberOfConfigurations
          CIenergy = ConfigurationInteraction_calculateCoupling( a, b, size1, size2 )

          if ( abs(CIenergy) > 1E-9 ) then
            c = c +1   
            !indexArray(b) = b
            energyArray(b) = CIenergy
          end if
      end do
!$omp end do nowait
!$omp end parallel

       
      cmax = cmax + c

      write(CIUnit) c
      write(CIUnit) a

      allocate (auxEnergyArray(c))
      allocate (auxIndexArray(c))

      cj = 0
      do ci = a, ConfigurationInteraction_instance%numberOfConfigurations
        !if ( indexArray(ci) > 0 ) then
        if ( abs(energyArray(ci)) > 1E-9 ) then
          cj = cj + 1
          auxIndexArray(cj) =(ci)
          auxEnergyArray(cj) = energyArray(ci)
        end if
      end do
      nblocks = ceiling(real(c) / real(maxStackSize) )

      do i = 1, nblocks - 1
        ib = maxStackSize * i  
        ia = ib - maxStackSize + 1
        write(CIUnit) auxIndexArray(ia:ib)
      end do

      ia = maxStackSize * (nblocks - 1) + 1
      write(CIUnit) auxIndexArray(ia:c)

      deallocate(auxIndexArray)

      do i = 1, nblocks - 1
        ib = maxStackSize * i  
        ia = ib - maxStackSize + 1
        write(CIUnit) auxEnergyArray(ia:ib)
      end do

      ia = maxStackSize * (nblocks - 1) + 1
      write(CIUnit) auxEnergyArray(ia:c)

      deallocate (auxEnergyArray)

    end do

    write(CIUnit) -1

    close(CIUnit)

    deallocate(indexArray)
    deallocate(energyArray)
    
    timeB = omp_get_wtime()
    write(*,"(A,F10.3,A4)") "** TOTAL Elapsed Time for Building CI matrix : ", timeB - timeA ," (s)"
    print *, "Nonzero elements", cmax

  end subroutine ConfigurationInteraction_buildAndSaveCIMatrix

  function ConfigurationInteraction_calculateEnergyZero( this ) result (auxCIenergy)
    implicit none

    integer(8) :: this(:)
    integer(8) :: a, b
    !integer :: numberOfSpecies
    integer :: i,j,s
    integer :: l,k,z,kk,ll
    !integer :: numberOfOccupiedOrbitals
    !real(8) :: kappa !positive or negative exchange
    integer :: factor
    integer(2) :: numberOfDiffOrbitals
    integer :: auxnumberOfOtherSpecieSpatialOrbitals
    integer :: auxIndex1, auxIndex2, auxIndex
    real(8) :: auxCIenergy

    auxCIenergy = 0.0_8

    do i=1, MolecularSystem_instance%numberOfQuantumSpecies
         a = this(i)
         do kk=1, ConfigurationInteraction_instance%occupationNumber( i )  !! 1 is from a and 2 from b

            !k = ConfigurationInteraction_instance%auxconfs(kk,i,a)
            k = ConfigurationInteraction_instance%strings(i)%values(kk,a)

               !One particle terms
               auxCIenergy= auxCIenergy + &
                    ConfigurationInteraction_instance%twoCenterIntegrals(i)%values( k, k )

               !Two particles, same specie
               auxIndex1= ConfigurationInteraction_instance%twoIndexArray(i)%values(k,k)

               do ll=kk+1, ConfigurationInteraction_instance%occupationNumber( i )  !! 1 is from a and 2 from b
                     !l = ConfigurationInteraction_instance%auxconfs(ll,i,a)
                     l = ConfigurationInteraction_instance%strings(i)%values(ll,a)
                     auxIndex2= ConfigurationInteraction_instance%twoIndexArray(i)%values(l,l)
                     auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values(auxIndex1,auxIndex2) 

                     !Coulomb
                     auxCIenergy = auxCIenergy + &
                         ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                     !Exchange, depends on spin
                     !if ( spin(1) .eq. spin(2) ) then

                     auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                                   ConfigurationInteraction_instance%twoIndexArray(i)%values(k,l), &
                                   ConfigurationInteraction_instance%twoIndexArray(i)%values(l,k) )

                     auxCIenergy = auxCIenergy + &
                             MolecularSystem_instance%species(i)%kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)
               end do

               ! !Two particles, different species
               !if (MolecularSystem_instance%numberOfQuantumSpecies > 1 ) then
                  do j=i+1, MolecularSystem_instance%numberOfQuantumSpecies
                     b = this(j)
                     auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 

                     do ll=1, ConfigurationInteraction_instance%occupationNumber( j ) !! 1 is from a and 2 from b
                           !l = ConfigurationInteraction_instance%auxconfs(ll,j,a)
                           l = ConfigurationInteraction_instance%strings(j)%values(ll,b)

                           auxIndex2= ConfigurationInteraction_instance%twoIndexArray(j)%values(l,l)
                           auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                           auxCIenergy = auxCIenergy + &!couplingEnergy
                           ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1)

                     end do

                  end do

               !end if

         end do
      end do

      !Interaction with point charges
      auxCIenergy= auxCIenergy + HartreeFock_instance%puntualInteractionEnergy

  end function ConfigurationInteraction_calculateEnergyZero

  function ConfigurationInteraction_calculateEnergyOne( thisA, thisB ) result (auxCIenergy)
    implicit none
    integer(8) :: thisA(:), thisB(:)
    integer(8) :: a, b
    !integer :: numberOfSpecies
    integer :: i,j,s
    integer :: l,k,z,kk,ll
    !integer :: numberOfOccupiedOrbitals
    !real(8) :: kappa !positive or negative exchange
    integer :: factor
    integer(2) :: numberOfDiffOrbitals
    integer :: auxnumberOfOtherSpecieSpatialOrbitals
    integer :: auxIndex1, auxIndex2, auxIndex
    integer :: diffOrb(4), otherdiffOrb(4) !! to avoid confusions
    real(8) :: auxCIenergy
    integer :: auxOcc
    integer(2) :: score
    !integer(2) :: auxthisA(m,n)

    !MolecularSystem_instance%numberOfQuantumSpecies = MolecularSystem_instance%numberOfQuantumSpecies
    auxCIenergy = 0.0_8

    !auxCIenergy = numberOfDiffOrbitals
    factor = 1

    !! copy a
    do i = 1, MolecularSystem_instance%numberOfQuantumSpecies
      a = thisA(i)
      ConfigurationInteraction_instance%auxstring(i)%values(:) = ConfigurationInteraction_instance%strings(i)%values(:,a)
    end do

    !! set at maximum coincidence

    do s = 1, MolecularSystem_instance%numberOfQuantumSpecies
        !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) = ConfigurationInteraction_instance%ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values%values(s) 
        a = thisA(s)
        b = thisB(s)

        do i = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) !b
            do j = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) !a
              !if ( auxthisA(j,s) == &
              !   ConfigurationInteraction_instance%auxconfs(i,s,b) ) then
              if ( ConfigurationInteraction_instance%auxstring(s)%values(j) == &
                 ConfigurationInteraction_instance%strings(s)%values(i,b) ) then

                    auxOcc = ConfigurationInteraction_instance%auxstring(s)%values(i) 
                    ConfigurationInteraction_instance%auxstring(s)%values(i) = ConfigurationInteraction_instance%strings(s)%values(i,b)
                    ConfigurationInteraction_instance%auxstring(s)%values(j) = auxOcc
                    !auxOcc = auxthisA(i,s)
                    !auxthisA(i,s) = ConfigurationInteraction_instance%auxconfs(i,s,b) 
                    !auxthisA(j,s) = auxOcc
                if ( i /= j ) factor = -1*factor
              end if
             
            end do
        end do
    end do

    !! calculate
    do i=1, MolecularSystem_instance%numberOfQuantumSpecies

       a = thisA(i)
       b = thisB(i)
       diffOrb = 0
       !kappa = MolecularSystem_instance%species(i)%kappa

       do kk=1, ConfigurationInteraction_instance%occupationNumber( i) !! 1 is from a and 2 from b

         if ( ConfigurationInteraction_instance%auxstring(i)%values(kk) .ne. &
                 ConfigurationInteraction_instance%strings(i)%values(kk,b) ) then
           diffOrb(1) = ConfigurationInteraction_instance%auxstring(i)%values(kk)
           diffOrb(2) = ConfigurationInteraction_instance%strings(i)%values(kk,b)
           exit                   
         end if

         !if ( auxthisA(kk,i) .ne. ConfigurationInteraction_instance%auxconfs(kk,i,b) ) then

         !  diffOrb(1)= auxthisA(kk,i) 
         !  diffOrb(2) = ConfigurationInteraction_instance%auxconfs(kk,i,b)
         !  exit                   
         !end if
       end do
       if (  diffOrb(2) > 0 ) then 

         !One particle terms
         auxCIenergy= auxCIenergy +  ConfigurationInteraction_instance%twoCenterIntegrals(i)%values( &
                           diffOrb(1), diffOrb(2) )

          !if (spin(1) .eq. spin(2) ) then

             auxIndex1= ConfigurationInteraction_instance%twoIndexArray(i)%values( & 
                         diffOrb(1), diffOrb(2))

             do ll=1, ConfigurationInteraction_instance%occupationNumber( i ) !! 1 is from a and 2 from b

               if ( ConfigurationInteraction_instance%auxstring(i)%values(ll) .eq. &
                 ConfigurationInteraction_instance%strings(i)%values(ll,b) ) then

                   l = ConfigurationInteraction_instance%auxstring(i)%values(ll) !! or b
               !if (  auxthisA(ll,i) .eq. ConfigurationInteraction_instance%auxconfs(ll,i,b) ) then
               !    l = auxthisA(ll,i) !! or b

                   auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(i)%values( l,l) 

                   auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( auxIndex1, auxIndex2 )

                   auxCIenergy = auxCIenergy + &
                        ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                   auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                                ConfigurationInteraction_instance%twoIndexArray(i)%values(diffOrb(1),l), &
                                ConfigurationInteraction_instance%twoIndexArray(i)%values(l,diffOrb(2)) ) 

                   auxCIenergy = auxCIenergy + &
                                   MolecularSystem_instance%species(i)%kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                end if
             end do

          ! !Two particles, different species
          if (MolecularSystem_instance%numberOfQuantumSpecies .gt. 1 ) then !.and. spin(1) .eq. spin(2) ) then
             do j=1, MolecularSystem_instance%numberOfQuantumSpecies

                if (i .ne. j) then

                   auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 

                   do ll=1,  ConfigurationInteraction_instance%occupationNumber( j ) !! 1 is from a and 2 from b
                         l = ConfigurationInteraction_instance%auxstring(j)%values(ll) !! or b?
                         !l = auxthisA(ll,j)

                         auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(j)%values( l,l) 
                         auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                      auxCIenergy = auxCIenergy + &
                      ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1) 
                   end do

                end if
             end do
          end if
       end if
       
    end do

    auxCIenergy= auxCIenergy * factor

  end function ConfigurationInteraction_calculateEnergyOne


  function ConfigurationInteraction_calculateEnergyTwo( thisA, thisB ) result (auxCIenergy)
    implicit none
    integer(8) :: thisA(:), thisB(:)
    integer(8) :: a, b
    !integer :: numberOfSpecies
    integer :: i,j,s
    integer :: l,k,z,kk,ll
    !integer :: numberOfOccupiedOrbitals
    !real(8) :: kappa !positive or negative exchange
    integer :: factor
    integer(2) :: numberOfDiffOrbitals
    integer :: auxnumberOfOtherSpecieSpatialOrbitals
    integer :: auxIndex1, auxIndex2, auxIndex
    integer :: diffOrb(4), otherdiffOrb(4) !! to avoid confusions
    real(8) :: auxCIenergy
    integer :: auxOcc
    integer(2) :: score
    !integer(2) :: auxthisA(m,n)


    auxCIenergy = 0.0_8

    numberOfDiffOrbitals = 0
    factor = 1

    !! copy a
    do i = 1, MolecularSystem_instance%numberOfQuantumSpecies
      a = thisA(i)
      ConfigurationInteraction_instance%auxstring(i)%values(:) = ConfigurationInteraction_instance%strings(i)%values(:,a)
    end do

    !! set at maximum coincidence

    do s = 1, MolecularSystem_instance%numberOfQuantumSpecies
        !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) = ConfigurationInteraction_instance%ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values%values(s) 
        a = thisA(s)
        b = thisB(s)

        do i = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) !b
            do j = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) !a
              !if ( auxthisA(j,s) == &
              !   ConfigurationInteraction_instance%auxconfs(i,s,b) ) then
              if ( ConfigurationInteraction_instance%auxstring(s)%values(j) == &
                 ConfigurationInteraction_instance%strings(s)%values(i,b) ) then

                    auxOcc = ConfigurationInteraction_instance%auxstring(s)%values(i) 
                    ConfigurationInteraction_instance%auxstring(s)%values(i) = ConfigurationInteraction_instance%strings(s)%values(i,b)
                    ConfigurationInteraction_instance%auxstring(s)%values(j) = auxOcc
                    !auxOcc = auxthisA(i,s)
                    !auxthisA(i,s) = ConfigurationInteraction_instance%auxconfs(i,s,b) 
                    !auxthisA(j,s) = auxOcc
                if ( i /= j ) factor = -1*factor
              end if
             
            end do
        end do
    end do

    !!calculate
    do i=1, MolecularSystem_instance%numberOfQuantumSpecies

       a = thisA(i)
       b = thisB(i)
       diffOrb = 0
       z = 1 
       do k = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i)

         if ( ConfigurationInteraction_instance%auxstring(i)%values(k) .ne. &
                 ConfigurationInteraction_instance%strings(i)%values(k,b) ) then
           diffOrb(z) = ConfigurationInteraction_instance%auxstring(i)%values(k) 
           diffOrb(z+2) = ConfigurationInteraction_instance%strings(i)%values(k,b)  
           z = z + 1
           cycle
         end if 
!         if ( auxthisA(k,i) .ne. ConfigurationInteraction_instance%auxconfs(k,i,b)  ) then
!           diffOrb(z) = auxthisA(k,i)
!           diffOrb(z+2) = ConfigurationInteraction_instance%auxconfs(k,i,b)
!           z = z + 1
!           cycle 
!         end if 
       end do 
     ! print *, "diffOrb", diffOrb 
       if (  diffOrb(2) > 0 ) then

          !Coulomb
           !! 12|34
          !if ( spin(1) .eq. spin(3) .and. spin(2) .eq. spin(4) ) then
            !  print *, "ini", auxCIenergy  

              auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                          ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                             diffOrb(1),diffOrb(3)),&
                          ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                             diffOrb(2),diffOrb(4)) )
             !!auxIndex=1
             ! print *, "auxindex", auxIndex

             auxCIenergy = auxCIenergy + &
                  ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)
             ! print *, "i", i
            !  print *, "2p j", auxCIenergy  
             !!auxCIenergy = auxCIenergy + 1
          !Exchange
          !if ( spin(1) .eq. spin(4) .and. spin(2) .eq. spin(3) ) then

             auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                          ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                             diffOrb(1),diffOrb(4)),&
                          ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                             diffOrb(2),diffOrb(3)) )
             !!auxCIenergy = auxCIenergy + 1
             auxCIenergy = auxCIenergy + &
                             MolecularSystem_instance%species(i)%kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

           !   print *, "2p k", auxCIenergy  
          !end if

       !else
       end if
       !! different species

         do j=i+1, MolecularSystem_instance%numberOfQuantumSpecies
           auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 
           otherdiffOrb = 0
           a = thisA(j)
           b = thisB(j)

           do k = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j)
             if ( ConfigurationInteraction_instance%auxstring(j)%values(k) .ne. &
                  ConfigurationInteraction_instance%strings(j)%values(k,b) ) then
               otherdiffOrb(1) = ConfigurationInteraction_instance%auxstring(j)%values(k)
               otherdiffOrb(3) = ConfigurationInteraction_instance%strings(j)%values(k,b)
               exit 
             end if 

             !if ( auxthisA(k,j) .ne. ConfigurationInteraction_instance%auxconfs(k,j,b) ) then
             !  otherdiffOrb(1) = auxthisA(k,j)
             !  otherdiffOrb(3) = ConfigurationInteraction_instance%auxconfs(k,j,b)
             !  exit 
             !end if 
           end do 
          !print *, "otherdiff", otherdiffOrb
             if ( diffOrb(3) .gt. 0 .and. otherdiffOrb(3) .gt. 0 ) then

                !if ( spin(1) .eq. spin(3) .and. spin(2) .eq. spin(4) ) then
           auxIndex1 = ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                   diffOrb(1),diffOrb(3) )
           auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(j)%values(&
                                   otherdiffOrb(1),otherdiffOrb(3) )
           auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                   !auxCIenergy = auxCIenergy + 1
           auxCIenergy = auxCIenergy + &
                        ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1)

          !print *, "aux cou", auxCIenergy
                end if

         end do
    end do

    auxCIenergy= auxCIenergy * factor

  end function ConfigurationInteraction_calculateEnergyTwo










  function ConfigurationInteraction_calculateCoupling(a,b, m, n) result (auxCIenergy)
    implicit none
    integer(8) :: a, b
    integer, intent(in) :: m,n
    !integer :: numberOfSpecies
    integer :: i,j,s
    integer :: l,k,z,kk,ll
    !integer :: numberOfOccupiedOrbitals
    !real(8) :: kappa !positive or negative exchange
    integer :: factor
    integer(2) :: numberOfDiffOrbitals
    integer :: auxnumberOfOtherSpecieSpatialOrbitals
    integer :: auxIndex1, auxIndex2, auxIndex
    integer :: diffOrb(4), otherdiffOrb(4) !! to avoid confusions
    real(8) :: auxCIenergy
    integer :: auxOcc
    integer(2) :: score
    integer(2) :: auxthisA(m,n)


    !MolecularSystem_instance%numberOfQuantumSpecies = MolecularSystem_instance%numberOfQuantumSpecies
    auxCIenergy = 0.0_8

    !! same 
    if ( a == b ) then 
      do i=1, MolecularSystem_instance%numberOfQuantumSpecies

         do kk=1, ConfigurationInteraction_instance%occupationNumber( i )  !! 1 is from a and 2 from b

            !k = auxthisA(kk,i)
            k = ConfigurationInteraction_instance%auxconfs(kk,i,a)


               !One particle terms
               auxCIenergy= auxCIenergy + &
                    ConfigurationInteraction_instance%twoCenterIntegrals(i)%values( k, k )

               !Two particles, same specie
               auxIndex1= ConfigurationInteraction_instance%twoIndexArray(i)%values(k,k)

               do ll=kk+1, ConfigurationInteraction_instance%occupationNumber( i )  !! 1 is from a and 2 from b
                     !l = auxthisA(ll,i)
                     l = ConfigurationInteraction_instance%auxconfs(ll,i,a)
                     auxIndex2= ConfigurationInteraction_instance%twoIndexArray(i)%values(l,l)
                     auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values(auxIndex1,auxIndex2) 

                     !Coulomb
                     auxCIenergy = auxCIenergy + &
                         ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                     !Exchange, depends on spin
                     !if ( spin(1) .eq. spin(2) ) then

                     auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                                   ConfigurationInteraction_instance%twoIndexArray(i)%values(k,l), &
                                   ConfigurationInteraction_instance%twoIndexArray(i)%values(l,k) )

                     auxCIenergy = auxCIenergy + &
                             MolecularSystem_instance%species(i)%kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)
               end do

               ! !Two particles, different species
               !if (MolecularSystem_instance%numberOfQuantumSpecies > 1 ) then
                  do j=i+1, MolecularSystem_instance%numberOfQuantumSpecies

                     auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 

                     do ll=1, ConfigurationInteraction_instance%occupationNumber( j ) !! 1 is from a and 2 from b
                           !l = auxthisA(ll,j)
                           l = ConfigurationInteraction_instance%auxconfs(ll,j,a)

                           auxIndex2= ConfigurationInteraction_instance%twoIndexArray(j)%values(l,l)
                           auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                           auxCIenergy = auxCIenergy + &!couplingEnergy
                           ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1)

                     end do

                  end do

               !end if

         end do
      end do

      !Interaction with point charges
      auxCIenergy= auxCIenergy + HartreeFock_instance%puntualInteractionEnergy
      return 
    else

    numberOfDiffOrbitals = 0
    !! find different determinants 
    do s = 1, MolecularSystem_instance%numberOfQuantumSpecies
  
      !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = ConfigurationInteraction_instance%ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values%values(s) 
      score = 0
  
      do i = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s)
          do j = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s)
             if ( ConfigurationInteraction_instance%auxconfs(i,s,a) == &
                    ConfigurationInteraction_instance%auxconfs(j,s,b) ) then
                !thisA(i,s) == auxthisB(j,s) ) then
               score = score + 1
             end if 
          end do 
        end do 
         numberOfDiffOrbitals = numberOfDiffOrbitals + (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) - score )

    end do 

    !auxCIenergy = numberOfDiffOrbitals
    factor = 1

    !if  (  numberOfDiffOrbitals <= 2  ) then
    !  auxthisA = ConfigurationInteraction_instance%auxconfs(:,:,a)
    !else
    !  return
    !end if

    !if  (  numberOfDiffOrbitals == 1 .or. numberOfDiffOrbitals == 2  ) then
    if  (  numberOfDiffOrbitals > 2  ) then
      return
    else
      !! set at maximum coincidence
      auxthisA = ConfigurationInteraction_instance%auxconfs(:,:,a)

      do s = 1, MolecularSystem_instance%numberOfQuantumSpecies
          !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) = ConfigurationInteraction_instance%ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values%values(s) 

          do i = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) !b
              do j = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) !a
                if ( auxthisA(j,s) == &
                   ConfigurationInteraction_instance%auxconfs(i,s,b) ) then
                       auxOcc = auxthisA(i,s)
                      auxthisA(i,s) = ConfigurationInteraction_instance%auxconfs(i,s,b) 
                      auxthisA(j,s) = auxOcc
                  if ( i /= j ) factor = -1*factor
                end if
               
              end do
          end do
      end do
    end if

        select case (  numberOfDiffOrbitals )

        case (1)

           do i=1, MolecularSystem_instance%numberOfQuantumSpecies

              diffOrb = 0

              !kappa = MolecularSystem_instance%species(i)%kappa

              do kk=1, ConfigurationInteraction_instance%occupationNumber( i) !! 1 is from a and 2 from b
                !if ( abs (auxthisA(kk,i) - auxthisB(kk,i) ) > 0 ) then
                !if ( abs( auxthisA(kk,i) - ConfigurationInteraction_instance%auxconfs(kk,i,b) ) > 0 ) then
                if ( auxthisA(kk,i) .ne. ConfigurationInteraction_instance%auxconfs(kk,i,b) ) then

                  diffOrb(1)= auxthisA(kk,i) 
                  !diffOrb2= auxthisB(kk,i) 
                  diffOrb(2) = ConfigurationInteraction_instance%auxconfs(kk,i,b)
                  exit                   
                end if
              end do
              if (  diffOrb(2) > 0 ) then 

                !One particle terms
                auxCIenergy= auxCIenergy +  ConfigurationInteraction_instance%twoCenterIntegrals(i)%values( &
                                  diffOrb(1), diffOrb(2) )

                 !if (spin(1) .eq. spin(2) ) then

                    auxIndex1= ConfigurationInteraction_instance%twoIndexArray(i)%values( & 
                                diffOrb(1), diffOrb(2))

                    do ll=1, ConfigurationInteraction_instance%occupationNumber( i ) !! 1 is from a and 2 from b
                      !if ( abs (auxthisA(ll,i) - auxthisB(ll,i) ) == 0 ) then
                      if (  auxthisA(ll,i) .eq. ConfigurationInteraction_instance%auxconfs(ll,i,b) ) then
                      !if ( abs( auxthisA(ll,i) - ConfigurationInteraction_instance%auxconfs(ll,i,b) ) == 0 ) then
                          l = auxthisA(ll,i) !! or b

                          auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(i)%values( l,l) 

                          auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( auxIndex1, auxIndex2 )

                          auxCIenergy = auxCIenergy + &
                               ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                          auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                                       ConfigurationInteraction_instance%twoIndexArray(i)%values(diffOrb(1),l), &
                                       ConfigurationInteraction_instance%twoIndexArray(i)%values(l,diffOrb(2)) ) 

                          auxCIenergy = auxCIenergy + &
                                          MolecularSystem_instance%species(i)%kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                       end if
                    end do

                 !end if

                 !!Exchange
                 !do ll=1, ConfigurationInteraction_instance%occupationNumber( i ) !! 1 is from a and 2 from b
                 !   !if ( abs (auxthisA(ll,i) - auxthisB(ll,i) ) == 0 ) then
                 !   if ( abs( auxthisA(ll,i) - ConfigurationInteraction_instance%auxconfs(ll,i,b) ) == 0 ) then
                 !         l = auxthisA(ll,i) !! or b

                 !         auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                 !                      ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                 !                        diffOrb(1),l), &
                 !                      ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                 !                        l,diffOrb(2)) ) 

                 !         auxCIenergy = auxCIenergy + &
                 !                         MolecularSystem_instance%species(i)%kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)
                 !   end if
                 !end do

                 ! !Two particles, different species
                 if (MolecularSystem_instance%numberOfQuantumSpecies .gt. 1 ) then !.and. spin(1) .eq. spin(2) ) then
                    do j=1, MolecularSystem_instance%numberOfQuantumSpecies

                       if (i .ne. j) then

                          auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 

                          do ll=1,  ConfigurationInteraction_instance%occupationNumber( j ) !! 1 is from a and 2 from b
                                l = auxthisA(ll,j)

                                auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(j)%values( l,l) 
                                auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                             auxCIenergy = auxCIenergy + &
                             ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1) 
                          end do

                       end if
                    end do
                 end if
              end if
              
           end do

        case (2)

           do i=1, MolecularSystem_instance%numberOfQuantumSpecies

              !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = ConfigurationInteraction_instance%occupationNumber( i ) 
              !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = Conf_occupationNumber( i ) 
              !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = MolecularSystem_instance%species(i)%ocupationNumber!*lambda

              diffOrb = 0
              z = 1 
              !  if ( a == 2) print *, i, a, ConfigurationInteraction_instance%auxconfs(:,i,a) 
              !  if ( a == 2) print *, i, b, ConfigurationInteraction_instance%auxconfs(:,i,b) 

              do k = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i)
                !if ( abs(auxthisA(k,i) - auxthisB(k,i)) > 0 ) then
                !if ( abs( auxthisA(k,i) - ConfigurationInteraction_instance%auxconfs(k,i,b) ) > 0 ) then
                if ( auxthisA(k,i) .ne. ConfigurationInteraction_instance%auxconfs(k,i,b)  ) then
                  diffOrb(z) = auxthisA(k,i)
                  diffOrb(z+2) = ConfigurationInteraction_instance%auxconfs(k,i,b)
                  z = z + 1
                  cycle 
                end if 
              end do 
 

              !z = 1
              !do k = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i)
              !  if ( z > 2 ) exit
              !!  if ( abs(auxthisA(k,i) - auxthisB(k,i)) > 0 ) then
              !  if ( abs( auxthisA(k,i) - ConfigurationInteraction_instance%auxconfs(k,i,b) ) > 0 ) then
              !    if ( z == 1 ) then
              !      diffOrb(1) = auxthisA(k,i)
              !!      diffOrb3 = auxthisB(k,i)
              !      diffOrb(3) = ConfigurationInteraction_instance%auxconfs(k,i,b)
              !    else if ( z == 2 ) then
              !      diffOrb(2) = auxthisA(k,i)
              !!      diffOrb4 = auxthisB(k,i)
              !      diffOrb(4) = ConfigurationInteraction_instance%auxconfs(k,i,b)
              !    end if 
              !    z = z + 1
              !  end if 
              !end do 

              !z = 0
              !do k = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values
              !  !if ( abs(auxthisA(k,i) - auxthisB(k,i)) > 0 ) then
              !  if ( abs( auxthisA(k,i) - ConfigurationInteraction_instance%auxconfs(k,i,b) ) > 0 ) then
              !      diffOrb1 =  auxthisA(k,i)
              !      !diffOrb3 = auxthisB(k,i)
              !      diffOrb3 = ConfigurationInteraction_instance%auxconfs(k,i,b)
              !      z = k
              !      exit
              !  end if 
              !end do 
              !if ( z > 0 ) then
              !do k = z+1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values
              !  !if ( abs(auxthisA(k,i) - auxthisB(k,i)) > 0 ) then
              !  if ( abs( auxthisA(k,i) - ConfigurationInteraction_instance%auxconfs(k,i,b) ) > 0 ) then
              !      diffOrb2 = auxthisA(k,i)
              !      !diffOrb4 = auxthisB(k,i)
              !      diffOrb4 = ConfigurationInteraction_instance%auxconfs(k,i,b)
              !     exit
              !  end if 
              !end do 
              !  end if 


              !auxCIenergy = auxCIenergy + diffOrb1 + diffOrb2
              !auxCIenergy = auxCIenergy + Conf_occupationNumber( i ) 
              !uxCIenergy = auxCIenergy + 1
           ! !wo cases: 4 different orbitals of the same species, and 2 and 2 of different species

              !kappa = MolecularSystem_instance%species(i)%kappa
              !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = 1

             ! print *, "diffOrb", diffOrb 
              if (  diffOrb(2) > 0 ) then

                 !Coulomb
                  !! 12|34
                 !if ( spin(1) .eq. spin(3) .and. spin(2) .eq. spin(4) ) then
             ! print *, "ini", auxCIenergy  

                     auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb(1),diffOrb(3)),&
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb(2),diffOrb(4)) )
                    !!auxIndex=1
           !   print *, "auxindex", auxIndex

                    auxCIenergy = auxCIenergy + &
                         ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)
            !  print *, "i", i
             ! print *, "2p j", auxCIenergy  

                    !!auxCIenergy = auxCIenergy + 1
                 !Exchange
                 !if ( spin(1) .eq. spin(4) .and. spin(2) .eq. spin(3) ) then

                    auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb(1),diffOrb(4)),&
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb(2),diffOrb(3)) )
                    !!auxCIenergy = auxCIenergy + 1
                    ! print *, i, auxIndex, diffOrb(:)
                    auxCIenergy = auxCIenergy + &
                                    MolecularSystem_instance%species(i)%kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

             ! print *, "2p k", auxCIenergy  
                 !end if

              !else
              end if
              !! different species

                do j=i+1, MolecularSystem_instance%numberOfQuantumSpecies
                    auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 
                    !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = MolecularSystem_instance%species(j)%ocupationNumber!* &
                    !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = ConfigurationInteraction_instance%occupationNumber( j ) 
                                                !ConfigurationInteraction_instance%lambda%values(j)
                  otherdiffOrb = 0

                   ! z = 1
                  do k = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j)
                   !   if ( z > 1 ) exit
                      !if ( abs(auxthisA(k,j) - auxthisB(k,j)) > 0 ) then
                      !if ( abs( auxthisA(k,j) - ConfigurationInteraction_instance%auxconfs(k,j,b) ) > 0 ) then
                    if ( auxthisA(k,j) .ne. ConfigurationInteraction_instance%auxconfs(k,j,b) ) then
                      otherdiffOrb(1) = auxthisA(k,j)
                        !otherdiffOrb3 = auxthisB(k,j)
                      otherdiffOrb(3) = ConfigurationInteraction_instance%auxconfs(k,j,b)
                      exit 
                    !    z = z +1
                    end if 
                  end do 

          !print *, "otherdiff", otherdiffOrb
                    if ( diffOrb(3) .gt. 0 .and. otherdiffOrb(3) .gt. 0 ) then

                       !if ( spin(1) .eq. spin(3) .and. spin(2) .eq. spin(4) ) then
                  auxIndex1 = ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                          diffOrb(1),diffOrb(3) )
                  auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(j)%values(&
                                          otherdiffOrb(1),otherdiffOrb(3) )
                  auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                          !auxCIenergy = auxCIenergy + 1
                  auxCIenergy = auxCIenergy + &
                               ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1)
         ! print *, "aux cou", auxCIenergy
                       end if

                end do
           end do

    end select
    auxCIenergy= auxCIenergy * factor

    end if



  end function ConfigurationInteraction_calculateCoupling

  function ConfigurationInteraction_calculateCouplingB(a,b, m, n) result (auxCIenergy)
    implicit none
    integer(8) :: a, b
    integer, intent(in) :: m,n
    !integer :: numberOfSpecies
    integer :: i,j,s
    integer :: l,k,z,kk,ll
    !integer :: numberOfOccupiedOrbitals
    !real(8) :: kappa !positive or negative exchange
    integer :: factor
    integer(2) :: numberOfDiffOrbitals
    integer :: auxnumberOfOtherSpecieSpatialOrbitals
    integer :: auxIndex1, auxIndex2, auxIndex
    integer :: diffOrb(4), otherdiffOrb(4) !! to avoid confusions
    real(8) :: auxCIenergy
    integer :: auxOcc
    integer(2) :: score
    integer(2) :: auxthisA(m,n)


    !MolecularSystem_instance%numberOfQuantumSpecies = MolecularSystem_instance%numberOfQuantumSpecies
    auxCIenergy = 0.0_8

    numberOfDiffOrbitals = 0
    !! find different determinants 
    do s = 1, MolecularSystem_instance%numberOfQuantumSpecies
  
      !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = ConfigurationInteraction_instance%ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values%values(s) 
      score = 0
  
      do i = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s)
          do j = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s)
             if ( ConfigurationInteraction_instance%auxconfs(i,s,a) == &
                    ConfigurationInteraction_instance%auxconfs(j,s,b) ) then
                !thisA(i,s) == auxthisB(j,s) ) then
               score = score + 1
             end if 
          end do 
        end do 
         numberOfDiffOrbitals = numberOfDiffOrbitals + (ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) - score )

    end do 

    !auxCIenergy = numberOfDiffOrbitals
    factor = 1

    !if  (  numberOfDiffOrbitals <= 2  ) then
    !  auxthisA = ConfigurationInteraction_instance%auxconfs(:,:,a)
    !else
    !  return
    !end if

    !if  (  numberOfDiffOrbitals == 1 .or. numberOfDiffOrbitals == 2  ) then
    if  (  numberOfDiffOrbitals > 2  ) then
      return
    else
      !! set at maximum coincidence
      auxthisA = ConfigurationInteraction_instance%auxconfs(:,:,a)

      do s = 1, MolecularSystem_instance%numberOfQuantumSpecies
          !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) = ConfigurationInteraction_instance%ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values%values(s) 

          do i = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) !b
              do j = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) !a
                if ( auxthisA(j,s) == &
                   ConfigurationInteraction_instance%auxconfs(i,s,b) ) then
                       auxOcc = auxthisA(i,s)
                      auxthisA(i,s) = ConfigurationInteraction_instance%auxconfs(i,s,b) 
                      auxthisA(j,s) = auxOcc
                  if ( i /= j ) factor = -1*factor
                end if
               
              end do
          end do
      end do
    end if

        select case (  numberOfDiffOrbitals )

        case (1)

           do i=1, MolecularSystem_instance%numberOfQuantumSpecies

              diffOrb = 0

              !kappa = MolecularSystem_instance%species(i)%kappa

              do kk=1, ConfigurationInteraction_instance%occupationNumber( i) !! 1 is from a and 2 from b
                !if ( abs (auxthisA(kk,i) - auxthisB(kk,i) ) > 0 ) then
                !if ( abs( auxthisA(kk,i) - ConfigurationInteraction_instance%auxconfs(kk,i,b) ) > 0 ) then
                if ( auxthisA(kk,i) .ne. ConfigurationInteraction_instance%auxconfs(kk,i,b) ) then

                  diffOrb(1)= auxthisA(kk,i) 
                  !diffOrb2= auxthisB(kk,i) 
                  diffOrb(2) = ConfigurationInteraction_instance%auxconfs(kk,i,b)
                  exit                   
                end if
              end do
              if (  diffOrb(2) > 0 ) then 

                !One particle terms
                auxCIenergy= auxCIenergy +  ConfigurationInteraction_instance%twoCenterIntegrals(i)%values( &
                                  diffOrb(1), diffOrb(2) )

                 !if (spin(1) .eq. spin(2) ) then

                    auxIndex1= ConfigurationInteraction_instance%twoIndexArray(i)%values( & 
                                diffOrb(1), diffOrb(2))

                    do ll=1, ConfigurationInteraction_instance%occupationNumber( i ) !! 1 is from a and 2 from b
                      !if ( abs (auxthisA(ll,i) - auxthisB(ll,i) ) == 0 ) then
                      if (  auxthisA(ll,i) .eq. ConfigurationInteraction_instance%auxconfs(ll,i,b) ) then
                      !if ( abs( auxthisA(ll,i) - ConfigurationInteraction_instance%auxconfs(ll,i,b) ) == 0 ) then
                          l = auxthisA(ll,i) !! or b

                          auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(i)%values( l,l) 

                          auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( auxIndex1, auxIndex2 )

                          auxCIenergy = auxCIenergy + &
                               ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                          auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                                       ConfigurationInteraction_instance%twoIndexArray(i)%values(diffOrb(1),l), &
                                       ConfigurationInteraction_instance%twoIndexArray(i)%values(l,diffOrb(2)) ) 

                          auxCIenergy = auxCIenergy + &
                                          MolecularSystem_instance%species(i)%kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                       end if
                    end do

                 !end if

                 !!Exchange
                 !do ll=1, ConfigurationInteraction_instance%occupationNumber( i ) !! 1 is from a and 2 from b
                 !   !if ( abs (auxthisA(ll,i) - auxthisB(ll,i) ) == 0 ) then
                 !   if ( abs( auxthisA(ll,i) - ConfigurationInteraction_instance%auxconfs(ll,i,b) ) == 0 ) then
                 !         l = auxthisA(ll,i) !! or b

                 !         auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                 !                      ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                 !                        diffOrb(1),l), &
                 !                      ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                 !                        l,diffOrb(2)) ) 

                 !         auxCIenergy = auxCIenergy + &
                 !                         MolecularSystem_instance%species(i)%kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)
                 !   end if
                 !end do

                 ! !Two particles, different species
                 if (MolecularSystem_instance%numberOfQuantumSpecies .gt. 1 ) then !.and. spin(1) .eq. spin(2) ) then
                    do j=1, MolecularSystem_instance%numberOfQuantumSpecies

                       if (i .ne. j) then

                          auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 

                          do ll=1,  ConfigurationInteraction_instance%occupationNumber( j ) !! 1 is from a and 2 from b
                                l = auxthisA(ll,j)

                                auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(j)%values( l,l) 
                                auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                             auxCIenergy = auxCIenergy + &
                             ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1) 
                          end do

                       end if
                    end do
                 end if
              end if
              
           end do

        case (2)

           do i=1, MolecularSystem_instance%numberOfQuantumSpecies

              !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = ConfigurationInteraction_instance%occupationNumber( i ) 
              !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = Conf_occupationNumber( i ) 
              !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = MolecularSystem_instance%species(i)%ocupationNumber!*lambda

              diffOrb = 0
              z = 1 
              do k = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i)
                !if ( abs(auxthisA(k,i) - auxthisB(k,i)) > 0 ) then
                !if ( abs( auxthisA(k,i) - ConfigurationInteraction_instance%auxconfs(k,i,b) ) > 0 ) then
                if ( auxthisA(k,i) .ne. ConfigurationInteraction_instance%auxconfs(k,i,b)  ) then
                  diffOrb(z) = auxthisA(k,i)
                  diffOrb(z+2) = ConfigurationInteraction_instance%auxconfs(k,i,b)
                  z = z + 1
                  cycle 
                end if 
              end do 
 

              !z = 1
              !do k = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(i)
              !  if ( z > 2 ) exit
              !!  if ( abs(auxthisA(k,i) - auxthisB(k,i)) > 0 ) then
              !  if ( abs( auxthisA(k,i) - ConfigurationInteraction_instance%auxconfs(k,i,b) ) > 0 ) then
              !    if ( z == 1 ) then
              !      diffOrb(1) = auxthisA(k,i)
              !!      diffOrb3 = auxthisB(k,i)
              !      diffOrb(3) = ConfigurationInteraction_instance%auxconfs(k,i,b)
              !    else if ( z == 2 ) then
              !      diffOrb(2) = auxthisA(k,i)
              !!      diffOrb4 = auxthisB(k,i)
              !      diffOrb(4) = ConfigurationInteraction_instance%auxconfs(k,i,b)
              !    end if 
              !    z = z + 1
              !  end if 
              !end do 

              !z = 0
              !do k = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values
              !  !if ( abs(auxthisA(k,i) - auxthisB(k,i)) > 0 ) then
              !  if ( abs( auxthisA(k,i) - ConfigurationInteraction_instance%auxconfs(k,i,b) ) > 0 ) then
              !      diffOrb1 =  auxthisA(k,i)
              !      !diffOrb3 = auxthisB(k,i)
              !      diffOrb3 = ConfigurationInteraction_instance%auxconfs(k,i,b)
              !      z = k
              !      exit
              !  end if 
              !end do 
              !if ( z > 0 ) then
              !do k = z+1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values
              !  !if ( abs(auxthisA(k,i) - auxthisB(k,i)) > 0 ) then
              !  if ( abs( auxthisA(k,i) - ConfigurationInteraction_instance%auxconfs(k,i,b) ) > 0 ) then
              !      diffOrb2 = auxthisA(k,i)
              !      !diffOrb4 = auxthisB(k,i)
              !      diffOrb4 = ConfigurationInteraction_instance%auxconfs(k,i,b)
              !     exit
              !  end if 
              !end do 
              !  end if 


              !auxCIenergy = auxCIenergy + diffOrb1 + diffOrb2
              !auxCIenergy = auxCIenergy + Conf_occupationNumber( i ) 
              !uxCIenergy = auxCIenergy + 1
           ! !wo cases: 4 different orbitals of the same species, and 2 and 2 of different species

              !kappa = MolecularSystem_instance%species(i)%kappa
              !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = 1

              if (  diffOrb(2) > 0 ) then

                 !Coulomb
                  !! 12|34
                 !if ( spin(1) .eq. spin(3) .and. spin(2) .eq. spin(4) ) then

                     auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb(1),diffOrb(3)),&
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb(2),diffOrb(4)) )
                    !!auxIndex=1

                    auxCIenergy = auxCIenergy + &
                         ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                    !!auxCIenergy = auxCIenergy + 1
                 !Exchange
                 !if ( spin(1) .eq. spin(4) .and. spin(2) .eq. spin(3) ) then

                    auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb(1),diffOrb(4)),&
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb(2),diffOrb(3)) )
                    !!auxCIenergy = auxCIenergy + 1
                    auxCIenergy = auxCIenergy + &
                                    MolecularSystem_instance%species(i)%kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)
                 !end if

              !else
              end if
              !! different species

                do j=i+1, MolecularSystem_instance%numberOfQuantumSpecies
                    auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 
                    !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = MolecularSystem_instance%species(j)%ocupationNumber!* &
                    !ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values = ConfigurationInteraction_instance%occupationNumber( j ) 
                                                !ConfigurationInteraction_instance%lambda%values(j)
                  otherdiffOrb = 0

                   ! z = 1
                  do k = 1, ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(j)
                   !   if ( z > 1 ) exit
                      !if ( abs(auxthisA(k,j) - auxthisB(k,j)) > 0 ) then
                      !if ( abs( auxthisA(k,j) - ConfigurationInteraction_instance%auxconfs(k,j,b) ) > 0 ) then
                    if ( auxthisA(k,j) .ne. ConfigurationInteraction_instance%auxconfs(k,j,b) ) then
                      otherdiffOrb(1) = auxthisA(k,j)
                        !otherdiffOrb3 = auxthisB(k,j)
                      otherdiffOrb(3) = ConfigurationInteraction_instance%auxconfs(k,j,b)
                      exit 
                    !    z = z +1
                    end if 
                  end do 

                    if ( diffOrb(3) .gt. 0 .and. otherdiffOrb(3) .gt. 0 ) then

                       !if ( spin(1) .eq. spin(3) .and. spin(2) .eq. spin(4) ) then
                  auxIndex1 = ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                          diffOrb(1),diffOrb(3) )
                  auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(j)%values(&
                                          otherdiffOrb(1),otherdiffOrb(3) )
                  auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                          !auxCIenergy = auxCIenergy + 1
                  auxCIenergy = auxCIenergy + &
                               ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1)
                       end if

                end do
           end do

    end select
    auxCIenergy= auxCIenergy * factor

  end function ConfigurationInteraction_calculateCouplingB



  function ConfigurationInteraction_calculateCIenergyB( thisA, auxthisB, m, n) result (auxCIenergy)
    implicit none
    !type(Configuration), intent(in) :: thisA
    !type(Configuration), intent(in) :: auxthisB
    integer(2), intent(in) :: thisA(:,:), auxthisB(:,:)
    integer, intent(in) :: m,n
    integer :: i,j,s
    integer :: l,k,z,kk,ll
    integer :: numberOfSpecies
    integer :: numberOfOccupiedOrbitals
    real(8) :: kappa !positive or negative exchange
    real(8) :: twoParticlesEnergy
    real(8) :: couplingEnergy
    integer :: factor
    integer :: numberOfDiffOrbitals
    integer :: auxnumberOfOtherSpecieSpatialOrbitals
    integer :: auxIndex1, auxIndex2, auxIndex
    integer :: diffOrb1, diffOrb2, diffOrb3, diffOrb4, otherdiffOrb1,otherdiffOrb3
    real(8) :: auxCIenergy
    integer :: auxOcc
    integer(2) :: score, auxscore
    integer(2) :: diagonal
    logical(1) :: swap
    integer(2) :: auxthisA(m,n)

    numberOfSpecies = MolecularSystem_instance%numberOfQuantumSpecies

    !allocate(differentOrbitals (numberOfSpecies))

    !do ia = 1, thisA%nDeterminants 
    !  do ib = 1, thisB%nDeterminants 

        auxCIenergy = 0.0_8
   
        numberOfDiffOrbitals = Configuration_checkCoincidenceB( thisA, auxthisB, numberOfSpecies )

        factor = 1
        if  (  numberOfDiffOrbitals <= 2  ) then
          auxthisA = thisA
        else
          return
        end if

        if  (  numberOfDiffOrbitals == 1 .or. numberOfDiffOrbitals == 2  ) then
          !call Configuration_setAtMaximumCoincidenceC( auxthisA,auxthisB%occupations, m, n, numberOfSpecies, factor )
          !factor = Configuration_setAtMaximumCoincidenceB( numberOfSpecies)
          do s = 1, numberOfSpecies
              numberOfOccupiedOrbitals = ConfigurationInteraction_instance%numberOfOccupiedOrbitals%values(s) 
        
              score = 0
              auxscore = 0
              diagonal = 0
      
              do i = 1, numberOfOccupiedOrbitals 
                  do j = 1, numberOfOccupiedOrbitals
                     if ( auxthisA(i,s) == auxthisB(j,s) ) then
                       auxscore = 1
                     else 
                       auxscore = 0
                     end if 
                     if ( i == j ) diagonal = diagonal + auxscore
                     score = score + auxscore
                  end do 
               end do 
        
              !do while ( (score) > diagonal )
              do k = 1, numberOfOccupiedOrbitals 

                  if ((score) > diagonal ) then
                  swap = .false. 
                  do i = 1, numberOfOccupiedOrbitals 
                    do j = 1, numberOfOccupiedOrbitals
                      if ( i /= j ) then
                        if ( auxthisA(i,s) == auxthisB(j,s) ) then
      
                          auxOcc = auxthisA(i,s)
                          auxthisA(i,s) = auxthisA(j,s)
                          auxthisA(j,s) = auxOcc
                          swap = .true.  
                        end if
                      end if
      
                      if ( swap .eqv. .true. ) exit
                    end do 
                    if ( swap .eqv. .true. ) exit
                  end do 
      
                diagonal = 0
                score = 0
                do i = 1, numberOfOccupiedOrbitals 
                  do j = 1, numberOfOccupiedOrbitals
      
                     if ( auxthisA(i,s) == auxthisB(j,s) ) then
                        auxscore = 1
                     else  
                       auxscore = 0
                     end if 
                     if ( i == j ) diagonal = diagonal + auxscore
                     score = score + auxscore
                  end do 
                end do 
                  factor = -1 * factor 
                else
                  exit
                end if
              end do! while
      
           end do
        end if

        !numberOfDiffOrbitals = 3
        select case (  numberOfDiffOrbitals )

        case (0)
          
              do i=1, numberOfSpecies

                 kappa = MolecularSystem_instance%species(i)%kappa

                 do kk=1, int( MolecularSystem_instance%species(i)%ocupationNumber) !! 1 is from a and 2 from b

                    k = auxthisA(kk,i)

                       !One particle terms
                       auxCIenergy= auxCIenergy + &
                            ConfigurationInteraction_instance%twoCenterIntegrals(i)%values( k, k )

                       !Two particles, same specie
                       twoParticlesEnergy=0

                       !auxIndex1 = IndexMap_tensorR2ToVectorC( k, k, numberOfSpatialOrbitals )
                       auxIndex1= ConfigurationInteraction_instance%twoIndexArray(i)%values(k,k)
                       do ll=kk+1, int( MolecularSystem_instance%species(i)%ocupationNumber )!! 1 is from a and 2 from b
                             l = auxthisA(ll,i)
                             !auxIndex2 = IndexMap_tensorR2ToVectorC( l, l, numberOfSpatialOrbitals )
                             auxIndex2= ConfigurationInteraction_instance%twoIndexArray(i)%values(l,l)
                             auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values(auxIndex1,auxIndex2) 
                             !auxIndex = IndexMap_tensorR2ToVectorC( auxIndex1, auxIndex2, &
                             !          auxnumberOfSpatialOrbitals  )

                             !Coulomb
                             twoParticlesEnergy=twoParticlesEnergy + &
                                 ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                             !Exchange, depends on spin
                             !if ( spin(1) .eq. spin(2) ) then

                             auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                                           ConfigurationInteraction_instance%twoIndexArray(i)%values(k,l), &
                                           ConfigurationInteraction_instance%twoIndexArray(i)%values(l,k) )
                                            !k, l, l, k, numberOfSpatialOrbitals )

                                TwoParticlesEnergy=TwoParticlesEnergy + &
                                     kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                             !end if
                          !end if
                       end do

                       auxCIenergy = auxCIenergy + twoParticlesEnergy

                       ! !Two particles, different species
                       if (numberOfSpecies > 1 ) then
                          do j=i+1, numberOfSpecies

                             !numberOfOtherSpecieSpatialOrbitals= ConfigurationInteraction_instance%totalNumberOfContractions ( j )
                             auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 

                             couplingEnergy=0

                             do ll=1, int( MolecularSystem_instance%species(j)%ocupationNumber )!! 1 is from a and 2 from b
                                   l = auxthisA(ll,j)
                                   auxIndex2= ConfigurationInteraction_instance%twoIndexArray(j)%values(l,l)
                                   !auxIndex2 = IndexMap_tensorR2ToVectorC( l, & 
                                   !             l, numberOfOtherSpecieSpatialOrbitals )
                                   auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                                   couplingEnergy=couplingEnergy+ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1)

                             end do

                             auxCIenergy = auxCIenergy + couplingEnergy

                          end do

                       end if

                    !end if
                 end do
              end do

             !Interaction with point charges
              auxCIenergy= auxCIenergy + HartreeFock_instance%puntualInteractionEnergy

        case (1)

           !if ( allocated (differentOrbitals) ) deallocate (differentOrbitals)
           !allocate (differentOrbitals (numberOfSpecies,2 ) )
           !differentOrbitals= 0

           do i=1, numberOfSpecies

              diffOrb1 = 0
              diffOrb2 = 0

              kappa = MolecularSystem_instance%species(i)%kappa
              !numberOfSpatialOrbitals = ConfigurationInteraction_instance%totalNumberOfContractions ( i )
              !auxnumberOfSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(i) 

              !Determine different orbitals
              !call Vector_constructorInteger (differentOrbitals(i), 2)

              !differentOrbitals(i)%values = 0

              do kk=1, int( MolecularSystem_instance%species(i)%ocupationNumber )!! 1 is from a and 2 from b
                if ( abs (auxthisA(kk,i) - auxthisB(kk,i) ) > 0 ) then
                  diffOrb1= auxthisA(kk,i) 
                  diffOrb2= auxthisB(kk,i) 

                end if
              end do

              if (  diffOrb2 > 0 ) then 

                !One particle terms
                auxCIenergy= auxCIenergy +  ConfigurationInteraction_instance%twoCenterIntegrals(i)%values( &
                                  !differentOrbitals(i)%values(1), differentOrbitals(i)%values(2) )
                                  !differentOrbitals(i,1), differentOrbitals(i,2) )
                                  diffOrb1, diffOrb2 )

                 twoParticlesEnergy=0.0_8
                 !if (spin(1) .eq. spin(2) ) then

                    !auxIndex1 = IndexMap_tensorR2ToVectorC(differentOrbitals(i)%values(1), differentOrbitals(i)%values(2), &
                    !                              numberOfSpatialOrbitals )
                    auxIndex1= ConfigurationInteraction_instance%twoIndexArray(i)%values( & 
                                !differentOrbitals(i)%values(1), differentOrbitals(i)%values(2))
                                diffOrb1, diffOrb2)

                    do ll=1, int( MolecularSystem_instance%species(i)%ocupationNumber) !! 1 is from a and 2 from b
                      if ( abs (auxthisA(ll,i) - auxthisB(ll,i) ) == 0 ) then
                          l = auxthisA(ll,i) !! or b

                          !auxIndex2 = IndexMap_tensorR2ToVectorC( l, l, numberOfSpatialOrbitals )
                          auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(i)%values( l,l) 

                          auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( auxIndex1, auxIndex2 )
                          !auxIndex = IndexMap_tensorR2ToVectorC( auxIndex1, auxIndex2, &
                          !             auxnumberOfSpatialOrbitals )

                          TwoParticlesEnergy=TwoParticlesEnergy + &
                               ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                       end if
                    end do
                 !end if

                 !Exchange
                 do ll=1, int( MolecularSystem_instance%species(i)%ocupationNumber) !! 1 is from a and 2 from b
                    if ( abs (auxthisA(ll,i) - auxthisB(ll,i) ) == 0 ) then
                          l = auxthisA(ll,i) !! or b

                          auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                                       ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                         diffOrb1,l), &
                                       ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                         l,diffOrb2) ) 

                          TwoParticlesEnergy=TwoParticlesEnergy + &
                               kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)
                       !end if
                    end if
                 end do

                 auxCIenergy = auxCIenergy + twoParticlesEnergy

                 ! !Two particles, different species

                 if (numberOfSpecies .gt. 1 ) then !.and. spin(1) .eq. spin(2) ) then
                    do j=1, numberOfSpecies

                       couplingEnergy=0
                       if (i .ne. j) then

                          !numberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%totalNumberOfContractions ( j )
                          auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 

                          do ll=1, int( MolecularSystem_instance%species(j)%ocupationNumber )!! 1 is from a and 2 from b
                                l = auxthisA(ll,j)

                               ! auxIndex2 = IndexMap_tensorR2ToVectorC( l, l, numberOfOtherSpecieSpatialOrbitals )
                                auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(j)%values( l,l) 
                                auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                                couplingEnergy=couplingEnergy+ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1) 
                          end do
                          auxCIenergy = auxCIenergy + couplingEnergy

                       end if
                    end do
                 end if
              end if
              
           end do

        case (2)

           do i=1, numberOfSpecies

              numberOfOccupiedOrbitals = MolecularSystem_instance%species(i)%ocupationNumber!*lambda

              diffOrb1 = 0
              diffOrb2 = 0
              diffOrb3 = 0
              diffOrb4 = 0

              z = 1
              do k = 1, numberOfOccupiedOrbitals
                if ( z > 2 ) exit
                if ( abs(auxthisA(k,i) - auxthisB(k,i)) > 0 ) then
                  if ( z == 1 ) then
                    diffOrb1 = auxthisA(k,i)
                    diffOrb3 = auxthisB(k,i)
                  else if ( z == 2 ) then
                    diffOrb2 = auxthisA(k,i)
                    diffOrb4 = auxthisB(k,i)
                  end if 
                  z = z + 1
                end if 
              end do 

           ! !Two cases: 4 different orbitals of the same species, and 2 and 2 of different species
           !do i=1, numberOfSpecies

              kappa = MolecularSystem_instance%species(i)%kappa
              !numberOfSpatialOrbitals = ConfigurationInteraction_instance%totalNumberOfContractions ( i )
              !auxnumberOfSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(i) 

              if (  diffOrb2 > 0 ) then

                 !Coulomb
                  !! 12|34
                 !if ( spin(1) .eq. spin(3) .and. spin(2) .eq. spin(4) ) then

                    !auxIndex = IndexMap_tensorR4ToVectorC( differentOrbitals(i)%values(1), differentOrbitals(i)%values(3), &
                    !            differentOrbitals(i)%values(2), differentOrbitals(i)%values(4), numberOfSpatialOrbitals )

                     auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb1,diffOrb3),&
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb2,diffOrb4) )
 

                    auxCIenergy = auxCIenergy + &
                         ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)
                 !end if

                 !Exchange
                 !if ( spin(1) .eq. spin(4) .and. spin(2) .eq. spin(3) ) then
                    !auxIndex = IndexMap_tensorR4ToVectorC(  differentOrbitals(i)%values(1),  differentOrbitals(i)%values(4), &
                    !             differentOrbitals(i)%values(2),  differentOrbitals(i)%values(3), numberOfSpatialOrbitals )

                    auxIndex = ConfigurationInteraction_instance%fourIndexArray(i)%values( &
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb1,diffOrb4),&
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb2,diffOrb3) )
                    auxCIenergy = auxCIenergy + &
                         kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)
                 !end if

              end if

              !! different species

              do j=i+1, numberOfSpecies
                    !numberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%totalNumberOfContractions ( j )
                    auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 
                    numberOfOccupiedOrbitals = MolecularSystem_instance%species(j)%ocupationNumber!* &
                                                !ConfigurationInteraction_instance%lambda%values(j)
                    otherdiffOrb1 = 0
                    otherdiffOrb3 = 0

                    z = 1
                    do k = 1, numberOfOccupiedOrbitals
                      if ( z > 1 ) exit
                      if ( abs(auxthisA(k,j) - auxthisB(k,j)) > 0 ) then
                        otherdiffOrb1 = auxthisA(k,j)
                        otherdiffOrb3 = auxthisB(k,j)
                        z = z + 1
                      end if 
                    end do 


                    !if ( differentOrbitals(i)%values(3) .gt. 0 .and.  differentOrbitals(j)%values(3) .gt. 0 ) then
                    !if ( differentOrbitals(i,3) .gt. 0 .and.  differentOrbitals(j,3) .gt. 0 ) then
                    if ( diffOrb3 .gt. 0 .and. otherdiffOrb3 .gt. 0 ) then

                       !if ( spin(1) .eq. spin(3) .and. spin(2) .eq. spin(4) ) then
                          !auxIndex = IndexMap_tensorR4ToVectorC( differentOrbitals(i)%values(1), differentOrbitals(i)%values(3), &
                          !             differentOrbitals(j)%values(1), differentOrbitals(j)%values(3), &
                          !             numberOfSpatialOrbitals, numberOfOtherSpecieSpatialOrbitals )
                          auxIndex1 = ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                          diffOrb1,diffOrb3 )
                          auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(j)%values(&
                                          otherdiffOrb1,otherdiffOrb3 )
                          auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                          auxCIenergy = auxCIenergy + &
                               ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1)
                       !end if

                    end if
              end do
           end do

    case default

      auxCIenergy= 0.0_8

    end select
    auxCIenergy= auxCIenergy * factor

  end function ConfigurationInteraction_calculateCIenergyB



  function ConfigurationInteraction_calculateCIenergyC(auxthisA, auxthisB) result (CIenergy)
    implicit none
    type(Configuration) :: auxthisA, auxthisB
    integer :: i,j,a,b,ia,ib
    integer :: l,k,z,kk,ll
    integer :: numberOfSpecies
    integer :: numberOfSpatialOrbitals
    integer :: auxnumberOfSpatialOrbitals
    integer :: numberOfOtherSpecieSpatialOrbitals
    integer :: auxnumberOfOtherSpecieSpatialOrbitals
    integer :: lambda !occupation per orbital
    integer :: numberOfOccupiedOrbitals
    real(8) :: kappa !positive or negative exchange
    real(8) :: twoParticlesEnergy
    real(8) :: couplingEnergy
    integer :: factor
    integer :: numberOfDiffOrbitals
    integer :: auxIndex1, auxIndex2, auxIndex
    !type(Ivector), allocatable :: differentOrbitals(:)
!    integer, allocatable :: differentOrbitals(:,:)
    integer :: diffOrb1, diffOrb2, diffOrb3, diffOrb4, otherdiffOrb1,otherdiffOrb3
    !type(Ivector), allocatable :: occupiedOrbitals(:,:) !! nspecies
    !integer, allocatable :: occupiedOrbitalsA(:,:) !! nspecies
   ! integer, allocatable :: occupiedOrbitalsB(:,:) !! nspecies
    real(8) :: CIenergy
    real(8) :: auxCIenergy

    CIenergy = 0.0_8

    numberOfSpecies = MolecularSystem_instance%numberOfQuantumSpecies

    !allocate(differentOrbitals (numberOfSpecies))

    !do ia = 1, thisA%nDeterminants 
    !  do ib = 1, thisB%nDeterminants 

        auxCIenergy = 0.0_8
   
        numberOfDiffOrbitals = Configuration_checkCoincidenceB( auxthisA%occupations, auxthisB%occupations, numberOfSpecies )

        factor = 1
        if  (  numberOfDiffOrbitals == 1 .or. numberOfDiffOrbitals == 2  ) then
          call Configuration_setAtMaximumCoincidenceB( auxthisA%occupations,auxthisB%occupations, numberOfSpecies, factor )
          !call Configuration_setAtMaximumCoincidenceB( numberOfSpecies, factor )
          !factor = Configuration_setAtMaximumCoincidenceB( numberOfSpecies)
        !print *, "c", factor
        else if ( numberOfDiffOrbitals > 2 ) then
          return
        end if

        !numberOfDiffOrbitals = 3
        select case (  numberOfDiffOrbitals )

        case (0)
          
              do i=1, numberOfSpecies

                 kappa = MolecularSystem_instance%species(i)%kappa
                 numberOfSpatialOrbitals = ConfigurationInteraction_instance%totalNumberOfContractions ( i )
                 auxnumberOfSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(i) 

                 do kk=1, int( MolecularSystem_instance%species(i)%ocupationNumber) !! 1 is from a and 2 from b

                    k = auxthisA%occupations(kk,i)

                       !One particle terms
                       auxCIenergy= auxCIenergy + &
                            ConfigurationInteraction_instance%twoCenterIntegrals(i)%values( k, k )

                       !Two particles, same specie
                       twoParticlesEnergy=0

                       !auxIndex1 = IndexMap_tensorR2ToVectorC( k, k, numberOfSpatialOrbitals )
                       auxIndex1= ConfigurationInteraction_instance%twoIndexArray(i)%values(k,k)
                       do ll=kk+1, int( MolecularSystem_instance%species(i)%ocupationNumber )!! 1 is from a and 2 from b
                             l = auxthisA%occupations(ll,i)
                             !auxIndex2 = IndexMap_tensorR2ToVectorC( l, l, numberOfSpatialOrbitals )
                             auxIndex2= ConfigurationInteraction_instance%twoIndexArray(i)%values(l,l)
                             auxIndex = IndexMap_tensorR2ToVectorC( auxIndex1, auxIndex2, &
                                       auxnumberOfSpatialOrbitals  )

                             !Coulomb
                             twoParticlesEnergy=twoParticlesEnergy + &
                                 ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                             !Exchange, depends on spin
                             !if ( spin(1) .eq. spin(2) ) then

                                auxIndex = IndexMap_tensorR2ToVectorC(&
                                           ConfigurationInteraction_instance%twoIndexArray(i)%values(k,l), &
                                           ConfigurationInteraction_instance%twoIndexArray(i)%values(l,k), &
                                           auxnumberOfSpatialOrbitals )
                                            !k, l, l, k, numberOfSpatialOrbitals )

                                TwoParticlesEnergy=TwoParticlesEnergy + &
                                     kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                             !end if
                          !end if
                       end do

                       auxCIenergy = auxCIenergy + twoParticlesEnergy

                       ! !Two particles, different species
                       if (numberOfSpecies > 1 ) then
                          do j=i+1, numberOfSpecies

                             numberOfOtherSpecieSpatialOrbitals= ConfigurationInteraction_instance%totalNumberOfContractions ( j )
                             auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 

                             couplingEnergy=0

                             do ll=1, int( MolecularSystem_instance%species(j)%ocupationNumber )!! 1 is from a and 2 from b
                                   l = auxthisA%occupations(ll,j)
                                   auxIndex2= ConfigurationInteraction_instance%twoIndexArray(j)%values(l,l)
                                   !auxIndex2 = IndexMap_tensorR2ToVectorC( l, & 
                                   !             l, numberOfOtherSpecieSpatialOrbitals )
                                   auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                                   couplingEnergy=couplingEnergy+ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1)

                             end do

                             auxCIenergy = auxCIenergy + couplingEnergy

                          end do

                       end if

                    !end if
                 end do
              end do

             !Interaction with point charges
              auxCIenergy= auxCIenergy + HartreeFock_instance%puntualInteractionEnergy

        case (1)

           !if ( allocated (differentOrbitals) ) deallocate (differentOrbitals)
           !allocate (differentOrbitals (numberOfSpecies,2 ) )
           !differentOrbitals= 0

           do i=1, numberOfSpecies

              diffOrb1 = 0
              diffOrb2 = 0

              kappa = MolecularSystem_instance%species(i)%kappa
              numberOfSpatialOrbitals = ConfigurationInteraction_instance%totalNumberOfContractions ( i )
              auxnumberOfSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(i) 

              !Determine different orbitals
              !call Vector_constructorInteger (differentOrbitals(i), 2)

              !differentOrbitals(i)%values = 0

              do kk=1, int( MolecularSystem_instance%species(i)%ocupationNumber )!! 1 is from a and 2 from b
                if ( abs (auxthisA%occupations(kk,i) - &
                     auxthisB%occupations(kk,i) ) > 0 ) then
                  !differentOrbitals(i)%values(1)= occupiedOrbitals(i,1)%values(kk) 
                  !differentOrbitals(i)%values(2)= occupiedOrbitals(i,2)%values(kk) 
                  !differentOrbitals(i,1)= auxthisA%occupations(kk,i) 
                  !differentOrbitals(i,2)= auxthisB%occupations(kk,i) 
                  diffOrb1= auxthisA%occupations(kk,i) 
                  diffOrb2= auxthisB%occupations(kk,i) 

                end if
              end do

              !call vector_show(differentOrbitals(i))
              !if (  differentOrbitals(i)%values(2) > 0 ) then !?
              !if (  differentOrbitals(i,2) > 0 ) then !?
              if (  diffOrb2 > 0 ) then !?

                !One particle terms
                auxCIenergy= auxCIenergy +  ConfigurationInteraction_instance%twoCenterIntegrals(i)%values( &
                                  !differentOrbitals(i)%values(1), differentOrbitals(i)%values(2) )
                                  !differentOrbitals(i,1), differentOrbitals(i,2) )
                                  diffOrb1, diffOrb2 )

                 twoParticlesEnergy=0.0_8
                 !if (spin(1) .eq. spin(2) ) then

                    !auxIndex1 = IndexMap_tensorR2ToVectorC(differentOrbitals(i)%values(1), differentOrbitals(i)%values(2), &
                    !                              numberOfSpatialOrbitals )
                    auxIndex1= ConfigurationInteraction_instance%twoIndexArray(i)%values( & 
                                !differentOrbitals(i)%values(1), differentOrbitals(i)%values(2))
                                diffOrb1, diffOrb2)

                    do ll=1, int( MolecularSystem_instance%species(i)%ocupationNumber) !! 1 is from a and 2 from b
                      if ( abs (auxthisA%occupations(ll,i) - &
                            auxthisB%occupations(ll,i) ) == 0 ) then
                          l = auxthisA%occupations(ll,i) !! or b

                          !auxIndex2 = IndexMap_tensorR2ToVectorC( l, l, numberOfSpatialOrbitals )
                          auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(i)%values( l,l) 

                          auxIndex = IndexMap_tensorR2ToVectorC( auxIndex1, auxIndex2, &
                                       auxnumberOfSpatialOrbitals )

                          TwoParticlesEnergy=TwoParticlesEnergy + &
                               ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)

                       end if
                    end do
                 !end if

                 !Exchange
                 do ll=1, int( MolecularSystem_instance%species(i)%ocupationNumber) !! 1 is from a and 2 from b
                    if ( abs (auxthisA%occupations(ll,i) -&
                         auxthisB%occupations(ll,i) ) == 0 ) then
                       l = auxthisA%occupations(ll,i) !! or b
                       !if (spin(1) .eq. spin(3) .and. spin(2) .eq. spin(3) ) then
                          !auxIndex = IndexMap_tensorR4ToVectorC( differentOrbitals(i)%values(1), l,  &
                          !             l, differentOrbitals(i)%values(2), & 
                          !             numberOfSpatialOrbitals )
                          auxIndex = IndexMap_tensorR2ToVectorC(&
                                       ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                         !differentOrbitals(i)%values(1),l), &
                                         !differentOrbitals(i,1),l), &
                                         diffOrb1,l), &
                                       ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                         !l,differentOrbitals(i)%values(2)), &
                                         !l,differentOrbitals(i,2)), &
                                         l,diffOrb2), &
                                       auxnumberOfSpatialOrbitals  )

                          TwoParticlesEnergy=TwoParticlesEnergy + &
                               kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)
                       !end if
                    end if
                 end do

                 auxCIenergy = auxCIenergy + twoParticlesEnergy

                 ! !Two particles, different species

                 if (numberOfSpecies .gt. 1 ) then !.and. spin(1) .eq. spin(2) ) then
                    do j=1, numberOfSpecies

                       couplingEnergy=0
                       if (i .ne. j) then

                          numberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%totalNumberOfContractions ( j )
                          auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 

                          do ll=1, int( MolecularSystem_instance%species(j)%ocupationNumber )!! 1 is from a and 2 from b
                                l = auxthisA%occupations(ll,j)

                               ! auxIndex2 = IndexMap_tensorR2ToVectorC( l, l, numberOfOtherSpecieSpatialOrbitals )
                                auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(j)%values( l,l) 
                                auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                                couplingEnergy=couplingEnergy+ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1) 
                          end do
                          auxCIenergy = auxCIenergy + couplingEnergy

                       end if
                    end do
                 end if
              end if
              
           end do

        case (2)

           !if ( allocated (differentOrbitals) ) deallocate (differentOrbitals)
           !allocate (differentOrbitals (numberOfSpecies,4 ) )
           !differentOrbitals = 0


           do i=1, numberOfSpecies
              !call Vector_constructorInteger (differentOrbitals(i),4)
              !lambda=ConfigurationInteraction_instance%lambda%values(i)
              !differentOrbitals(i)%values = 0
              numberOfOccupiedOrbitals = MolecularSystem_instance%species(i)%ocupationNumber!*lambda

              diffOrb1 = 0
              diffOrb2 = 0
              diffOrb3 = 0
              diffOrb4 = 0

              z = 1
              do k = 1, numberOfOccupiedOrbitals
                if ( z > 2 ) exit
                if ( abs(auxthisA%occupations(k,i) - auxthisB%occupations(k,i)) > 0 ) then
                  if ( z == 1 ) then
                    diffOrb1 = auxthisA%occupations(k,i)
                    diffOrb3 = auxthisB%occupations(k,i)
                  else if ( z == 2 ) then
                    diffOrb2 = auxthisA%occupations(k,i)
                    diffOrb4 = auxthisB%occupations(k,i)
                  end if 
                  z = z + 1
                end if 
              end do 

              !print *, "c", diffOrb1, diffOrb2, diffOrb3, diffOrb4
           !end do
           ! !Two cases: 4 different orbitals of the same species, and 2 and 2 of different species

           !do i=1, numberOfSpecies

              kappa = MolecularSystem_instance%species(i)%kappa
              numberOfSpatialOrbitals = ConfigurationInteraction_instance%totalNumberOfContractions ( i )
              auxnumberOfSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(i) 

              if (  diffOrb2 > 0 ) then
              !if (  differentOrbitals(i,2) > 0 ) then
              !if (  differentOrbitals(i)%values(2) > 0 ) then

                 !Coulomb
                  !! 12|34
                 !if ( spin(1) .eq. spin(3) .and. spin(2) .eq. spin(4) ) then

                    !auxIndex = IndexMap_tensorR4ToVectorC( differentOrbitals(i)%values(1), differentOrbitals(i)%values(3), &
                    !            differentOrbitals(i)%values(2), differentOrbitals(i)%values(4), numberOfSpatialOrbitals )

                    auxIndex = IndexMap_tensorR2ToVectorC(&
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    !differentOrbitals(i)%values(1),differentOrbitals(i)%values(3)),&
                                    !differentOrbitals(i,1),differentOrbitals(i,3)),&
                                    diffOrb1,diffOrb3),&
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    !differentOrbitals(i)%values(2),differentOrbitals(i)%values(4)),&
                                    !differentOrbitals(i,2),differentOrbitals(i,4)),&
                                    diffOrb2,diffOrb4),&
                                 auxnumberOfSpatialOrbitals )


                    auxCIenergy = auxCIenergy + &
                         ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)
                 !end if

                 !Exchange
                 !if ( spin(1) .eq. spin(4) .and. spin(2) .eq. spin(3) ) then
                    !auxIndex = IndexMap_tensorR4ToVectorC(  differentOrbitals(i)%values(1),  differentOrbitals(i)%values(4), &
                    !             differentOrbitals(i)%values(2),  differentOrbitals(i)%values(3), numberOfSpatialOrbitals )
                    auxIndex = IndexMap_tensorR2ToVectorC(&
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb1,diffOrb4),&
                                    !differentOrbitals(i,1),differentOrbitals(i,4)),&
                                    !differentOrbitals(i)%values(1),differentOrbitals(i)%values(4)),&
                                 ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                    diffOrb2,diffOrb3),&
                                    !differentOrbitals(i,2),differentOrbitals(i,3)),&
                                    !differentOrbitals(i)%values(2),differentOrbitals(i)%values(3)),&
                                 auxnumberOfSpatialOrbitals  )

                    auxCIenergy = auxCIenergy + &
                         kappa*ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1)
                 !end if

              end if

              !! different species

              do j=i+1, numberOfSpecies
                    numberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%totalNumberOfContractions ( j )
                    auxnumberOfOtherSpecieSpatialOrbitals = ConfigurationInteraction_instance%numberOfSpatialOrbitals2%values(j) 
                    numberOfOccupiedOrbitals = MolecularSystem_instance%species(j)%ocupationNumber!* &
                                                !ConfigurationInteraction_instance%lambda%values(j)
                    otherdiffOrb1 = 0
                    otherdiffOrb3 = 0

                    z = 1
                    do k = 1, numberOfOccupiedOrbitals
                      if ( z > 1 ) exit
                      if ( abs(auxthisA%occupations(k,j) - auxthisB%occupations(k,j)) > 0 ) then
                        otherdiffOrb1 = auxthisA%occupations(k,j)
                        otherdiffOrb3 = auxthisB%occupations(k,j)
                        z = z + 1
                      end if 
                    end do 


                    !if ( differentOrbitals(i)%values(3) .gt. 0 .and.  differentOrbitals(j)%values(3) .gt. 0 ) then
                    !if ( differentOrbitals(i,3) .gt. 0 .and.  differentOrbitals(j,3) .gt. 0 ) then
                    if ( diffOrb3 .gt. 0 .and. otherdiffOrb3 .gt. 0 ) then

                       !if ( spin(1) .eq. spin(3) .and. spin(2) .eq. spin(4) ) then
                          !auxIndex = IndexMap_tensorR4ToVectorC( differentOrbitals(i)%values(1), differentOrbitals(i)%values(3), &
                          !             differentOrbitals(j)%values(1), differentOrbitals(j)%values(3), &
                          !             numberOfSpatialOrbitals, numberOfOtherSpecieSpatialOrbitals )
                          auxIndex1 = ConfigurationInteraction_instance%twoIndexArray(i)%values(&
                                          diffOrb1,diffOrb3 )
                                          !differentOrbitals(i,1),differentOrbitals(i,3) )
                                          !differentOrbitals(i)%values(1),differentOrbitals(i)%values(3) )
                          auxIndex2 = ConfigurationInteraction_instance%twoIndexArray(j)%values(&
                                          otherdiffOrb1,otherdiffOrb3 )
                                          !differentOrbitals(j,1),differentOrbitals(j,3) )
                                          !differentOrbitals(j)%values(1),differentOrbitals(j)%values(3) )
                          auxIndex = auxnumberOfOtherSpecieSpatialOrbitals * (auxIndex1 - 1 ) + auxIndex2

                          auxCIenergy = auxCIenergy + &
                               ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values(auxIndex, 1)
                       !end if

                    end if
              end do
           end do

        case default

           auxCIenergy= 0.0_8

        end select
        CIenergy= auxCIenergy * factor + CIenergy
        !print *, "factor", factor
    !  end do  ! ib
    !end do ! ia 
!    thisA%occupations2 = thisA%occupations
!    thisB%occupations2 = thisB%occupations
    !deallocate (differentOrbitals)

  end function ConfigurationInteraction_calculateCIenergyC



  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine ConfigurationInteraction_getTransformedIntegrals()
    implicit none

!    type(TransformIntegrals) :: repulsionTransformer
    integer :: numberOfSpecies
    integer :: i,j,m,n,mu,nu,a,b,c
    integer :: specieID
    integer :: otherSpecieID
    character(10) :: nameOfSpecie
    character(10) :: nameOfOtherSpecie
    integer :: ocupationNumber
    integer :: ocupationNumberOfOtherSpecie
    integer :: numberOfContractions
    integer :: numberOfContractionsOfOtherSpecie
!    type(Matrix) :: auxMatrix
!    type(Matrix) :: molecularCouplingMatrix
!    type(Matrix) :: molecularExtPotentialMatrix
!    type(Matrix) :: couplingMatrix
    type(Matrix) :: hcoreMatrix
    type(Matrix) :: coefficients
    real(8) :: charge
    real(8) :: otherSpecieCharge

    integer :: ssize1, ssize2

    character(50) :: wfnFile
    character(50) :: arguments(20)
    integer :: wfnUnit

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()
    allocate(ConfigurationInteraction_instance%twoCenterIntegrals(numberOfSpecies))
    !allocate(ConfigurationInteraction_instance%FockMatrix(numberOfSpecies))
    allocate(ConfigurationInteraction_instance%fourCenterIntegrals(numberOfSpecies,numberOfSpecies))
    !allocate(ConfigurationInteraction_instance%energyofmolecularorbitals(numberOfSpecies))

    allocate(ConfigurationInteraction_instance%twoIndexArray(numberOfSpecies))
    allocate(ConfigurationInteraction_instance%fourIndexArray(numberOfSpecies))

!    print *,""
!    print *,"BEGIN INTEGRALS TRANFORMATION:"
!    print *,"========================================"
!    print *,""
!    print *,"--------------------------------------------------"
!    print *,"    Algorithm Four-index integral tranformation"
!    print *,"      Yamamoto, Shigeyoshi; Nagashima, Umpei. "
!    print *,"  Computer Physics Communications, 2005, 166, 58-65"
!    print *,"--------------------------------------------------"
!    print *,""
!
!    call TransformIntegrals_constructor( repulsionTransformer )

    do i=1, numberOfSpecies
        nameOfSpecie= trim(  MolecularSystem_getNameOfSpecie( i ) )
        specieID = MolecularSystem_getSpecieID( nameOfSpecie=nameOfSpecie )
        ocupationNumber = MolecularSystem_getOcupationNumber( i )
        numberOfContractions = MolecularSystem_getTotalNumberOfContractions( i )
        charge=MolecularSystem_getCharge(i)

!        write (6,"(T10,A)")"ONE PARTICLE INTEGRALS TRANSFORMATION FOR: "//trim(nameOfSpecie)
        call Matrix_constructor (ConfigurationInteraction_instance%twoCenterIntegrals(i), int(numberOfContractions,8), int(numberOfContractions,8), 0.0_8 )

        !call Matrix_constructor (ConfigurationInteraction_instance%FockMatrix(i), int(numberOfContractions,8), int(numberOfContractions,8), 0.0_8 )
        call Matrix_constructor (hcoreMatrix,int(numberOfContractions,8), int(numberOfContractions,8), 0.0_8)

        !! Open file for wavefunction

        wfnFile = "lowdin.wfn"
        wfnUnit = 20

        open(unit=wfnUnit, file=trim(wfnFile), status="old", form="unformatted")

        arguments(2) = MolecularSystem_getNameOfSpecie(i)
        arguments(1) = "COEFFICIENTS"

        coefficients = &
          Matrix_getFromFile(unit=wfnUnit, rows= int(numberOfContractions,4), &
          columns= int(numberOfContractions,4), binary=.true., arguments=arguments(1:2))

        arguments(1) = "HCORE"

        hcoreMatrix = &
          Matrix_getFromFile(unit=wfnUnit, rows= int(numberOfContractions,4), &
          columns= int(numberOfContractions,4), binary=.true., arguments=arguments(1:2))

        do m=1,numberOfContractions
          do n=m, numberOfContractions
             do mu=1, numberOfContractions
                do nu=1, numberOfContractions
                    ConfigurationInteraction_instance%twoCenterIntegrals(i)%values(m,n) = &
                        ConfigurationInteraction_instance%twoCenterIntegrals(i)%values(m,n) + &
                        coefficients%values(mu,m)* &
                        coefficients%values(nu,n)* &
                        hcoreMatrix%values(mu,nu)
                end do
             end do
          end do
       end do

!! Not implemented yet
!!       if( WaveFunction_HF_instance( specieID )%isThereExternalPotential ) then
!!          do m=1,numberOfContractions
!!             do n=m, numberOfContractions
!!                do mu=1, numberOfContractions
!!                   do nu=1, numberOfContractions
!!                      ConfigurationInteraction_instance%twoCenterIntegrals(i)%values(m,n) = &
!!                           ConfigurationInteraction_instance%twoCenterIntegrals(i)%values(m,n) + &
!!                           WaveFunction_HF_instance( specieID )%waveFunctionCoefficients%values(mu,m)* &
!!                           WaveFunction_HF_instance( specieID )%waveFunctionCoefficients%values(nu,n) * &
!!                           WaveFunction_HF_instance( specieID )%ExternalPotentialMatrix%values(mu,nu)
!!                   end do
!!                end do
!!             end do
!!          end do
!!       end if

       do m=1,numberOfContractions
          do n=m, numberOfContractions
             ConfigurationInteraction_instance%twoCenterIntegrals(i)%values(n,m)=&
                  ConfigurationInteraction_instance%twoCenterIntegrals(i)%values(m,n)
          end do
       end do

        call Matrix_constructorInteger(ConfigurationInteraction_instance%twoIndexArray(i), &
                          int( numberOfContractions,8), int( numberOfContractions,8) , 0 )

       c = 0
       do a=1,numberOfContractions
         do b=a, numberOfContractions
           c = c + 1
           ConfigurationInteraction_instance%twoIndexArray(i)%values(a,b) = c !IndexMap_tensorR2ToVectorC( a, b, numberOfContractions )
           ConfigurationInteraction_instance%twoIndexArray(i)%values(b,a) = ConfigurationInteraction_instance%twoIndexArray(i)%values(a,b)
         end do 
       end do


          ssize1 = MolecularSystem_getTotalNumberOfContractions( i )
          ssize1 = ( ssize1 * ( ssize1 + 1 ) ) / 2

          call Matrix_constructorInteger(ConfigurationInteraction_instance%fourIndexArray(i), &
                          int( ssize1,8), int( ssize1,8) , 0 )
          c = 0
          do a=1, ssize1
            do b=a, ssize1
              c = c + 1
              !print *, a,b, c
              ConfigurationInteraction_instance%fourIndexArray(i)%values(a,b) = c! IndexMap_tensorR2ToVectorC( a, b, numberOfContractions )
              ConfigurationInteraction_instance%fourIndexArray(i)%values(b,a) = &
                ConfigurationInteraction_instance%fourIndexArray(i)%values(a,b)
             end do 
           end do


        call ReadTransformedIntegrals_readOneSpecies( specieID, ConfigurationInteraction_instance%fourCenterIntegrals(i,i)   )
        ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values = &
           ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values * charge * charge

       if ( numberOfSpecies > 1 ) then
          do j = 1 , numberOfSpecies
             if ( i .ne. j) then
                nameOfOtherSpecie= trim(  MolecularSystem_getNameOfSpecie( j ) )
                otherSpecieID =MolecularSystem_getSpecieID( nameOfSpecie=nameOfOtherSpecie )
                ocupationNumberOfOtherSpecie = MolecularSystem_getOcupationNumber( j )
                numberOfContractionsOfOtherSpecie = MolecularSystem_getTotalNumberOfContractions( j )
                otherSpecieCharge=MolecularSystem_getCharge(j)

                 call ReadTransformedIntegrals_readTwoSpecies( specieID, otherSpecieID, &
                         ConfigurationInteraction_instance%fourCenterIntegrals(i,j) )
                 ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values = &
                   ConfigurationInteraction_instance%fourCenterIntegrals(i,j)%values * charge * otherSpeciecharge


             end if
          end do
       end if
    end do
    close (wfnUnit)
    call Matrix_destructor (hcoreMatrix)
!   call Matrix_destructor (couplingMatrix)

  end subroutine ConfigurationInteraction_getTransformedIntegrals


  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
!  subroutine ConfigurationInteraction_printTransformedIntegralsToFile()
!    implicit none
!
!!    type(TransformIntegrals) :: repulsionTransformer
!    integer :: numberOfSpecies
!    integer :: i,j,m,n,mu,nu
!    integer :: a,b,r,s,u, auxIndex
!    integer :: z
!    integer :: stats, recNum
!    character(10) :: nameOfSpecie, auxNameOfSpecie
!    character(10) :: nameOfOtherSpecie
!    integer :: ocupationNumber
!    integer :: ocupationNumberOfOtherSpecie
!    integer :: numberOfContractions
!    integer :: numberOfContractionsOfOtherSpecie
!    type(Matrix) :: auxMatrix
!    type(Matrix) :: molecularCouplingMatrix
!    type(Matrix) :: molecularExtPotentialMatrix
!
!    integer :: spin
!
!    real(8) :: totalCoupEnergy
!    real(8) :: fixedPotEnergy
!    real(8) :: fixedIntEnergy
!    real(8) :: KineticEnergy
!    real(8) :: RepulsionEnergy
!    real(8) :: couplingEnergy


!    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()
!
!    print *,""
!    print *,"BEGIN INTEGRALS TRANFORMATION:"
!    print *,"========================================"
!    print *,""
!    print *,"--------------------------------------------------"
!    print *,"    Algorithm Four-index integral tranformation"
!    print *,"      Yamamoto, Shigeyoshi; Nagashima, Umpei. "
!    print *,"  Computer Physics Communications, 2005, 166, 58-65"
!    print *,"--------------------------------------------------"
!    print *,""
!
!    totalCoupEnergy = 0.0_8
!    fixedPotEnergy = 0.0_8
!    fixedIntEnergy = 0.0_8
!    KineticEnergy = 0.0_8
!    RepulsionEnergy = 0.0_8
!    couplingEnergy = 0.0_8
!    spin = 0
!
!    do i=1, numberOfSpecies
!        nameOfSpecie= trim(  MolecularSystem_getNameOfSpecie( i ) )
!        numberOfContractions = MolecularSystem_getTotalNumberOfContractions( i )
!        spin = MolecularSystem_getMultiplicity(i) - 1
!
!        if(trim(nameOfSpecie) /= "E-BETA" ) then
!
!           if(trim(nameOfSpecie) /= "U-" ) then 
!
!              open(unit=35, file="FCIDUMP-"//trim(nameOfSpecie)//".com", form="formatted", status="replace")
!
!              write(35,"(A)")"gprint basis"
!              write(35,"(A)")"memory 1000 M"
!              write(35,"(A)")"cartesian"
!              write(35,"(A)")"gthresh twoint=1e-12 prefac=1e-14 energy=1e-10 edens=1e-10 zero=1e-12"
!              write(35,"(A)")"basis={"
!              call ConfigurationInteraction_printBasisSetToFile(35)
!              write(35,"(A)")"}"
!
!              write(35,"(A)")"symmetry nosym"
!              write(35,"(A)")"angstrom"
!              write(35,"(A)")"geometry={"
!              call ConfigurationInteraction_printGeometryToFile(35)
!              write(35,"(A)")"}"
!
!              write(35,"(A)")"import 21500.2 "//trim(trim(CONTROL_instance%INPUT_FILE)//trim(nameOfSpecie)//"."//"jcoup")
!              write(35,"(A)")"import 21510.2 "//trim(trim(CONTROL_instance%INPUT_FILE)//trim(nameOfSpecie)//"."//"icoup")
!              write(35,"(A)")"import 21520.2 "//trim(trim(CONTROL_instance%INPUT_FILE)//trim(nameOfSpecie)//"."//"kin")
!              write(35,"(A)")"import 21530.2 "//trim(trim(CONTROL_instance%INPUT_FILE)//trim(nameOfSpecie)//"."//"coeff")
!
!              if(trim(nameOfSpecie) == "E-ALPHA") then
!
!                 write(35,"(A)")"import 21550.2 "//trim(trim(CONTROL_instance%INPUT_FILE)//"E-BETA"//"."//"coeff")
!
!              end if
!
!              write(35,"(A)")"import 21540.2 "//trim(trim(CONTROL_instance%INPUT_FILE)//trim(nameOfSpecie)//"."//"dens")
!              !write(35,"(A)")"import 21560.2 "//trim(trim(CONTROL_instance%INPUT_FILE)//trim(nameOfSpecie)//"."//"pot")
!
!              write(35,"(A)")"{matrop"
!              write(35,"(A)")"load Jcoup, SQUARE 21500.2"
!              write(35,"(A)")"load Icoup, SQUARE 21510.2"
!              write(35,"(A)")"load K, SQUARE 21520.2"
!              !write(35,"(A)")"load Pot, SQUARE 21560.2"
!              write(35,"(A)")"add H01, K Icoup Jcoup"! Pot"
!              write(35,"(A)")"save H01, 21511.2 H0"
!              write(35,"(A)")"}"
!
!              if(trim(nameOfSpecie) == "E-ALPHA") then
!                 write(35,"(A)")"{matrop"
!                 write(35,"(A)")"load Ca, SQUARE 21530.2"
!                 write(35,"(A)")"load Cb, SQUARE 21550.2"               
!                 write(35,"(A)")"save Ca, 2100.1 ORBITALS alpha"
!                 write(35,"(A)")"save Cb, 2100.1 ORBITALS beta"
!                 write(35,"(A)")"}"
!              else
!                 write(35,"(A)")"{matrop"
!                 write(35,"(A)")"load C, SQUARE 21530.2"
!                 write(35,"(A)")"save C, 2100.1 ORBITALS"
!                 write(35,"(A)")"}"
!              end if
!
!              write(35,"(A)")"{matrop"
!              write(35,"(A)")"load D, SQUARE 21540.2"
!              write(35,"(A)")"save D, 21400.1 DENSITY"
!              write(35,"(A)")"}"
!
!
!              !            write(35,"(A,I3,A,I3,A,I3,A1)")"$FCI NORB=",numberOfContractions, ",NELEC=", MolecularSystem_getNumberOfParticles(i)-spin, ", MS2=", spin,","
!              !
!              !            write(35,"(A)",advance="no") "ORBSYM="
!              !            do z=1, numberOfContractions
!              !                write(35,"(I1,A1)",advance="no") 1,","
!              !            end do
!              !            write(35,"(A)") ""
!              !
!              !            write(35, "(A,I3,A,I9)") "ISYM=",1, ",MEMORY=", 200000000
!              !
!              !            write(35, "(A)") "$"
!              !
!              !            print *, "FOUR CENTER INTEGRALS FOR SPECIE: ", trim(nameOfSpecie)
!              !
!              !            recNum = 0
!              !            do a = 1, numberOfContractions
!              !                n = a
!              !                do b=a, numberOfContractions
!              !                    u = b
!              !                    do r = n, numberOfContractions
!              !                        do s = u, numberOfContractions
!              !
!              !                            auxIndex = IndexMap_tensorR4ToVector( a, b, r, s, numberOfContractions )
!              !                            write(35,"(F20.10,4I3)") ConfigurationInteraction_instance%fourCenterIntegrals(i,i)%values(auxIndex, 1), a, b, r, s
!              !
!              !                        end do
!              !                        u=r+1
!              !                    end do
!              !                end do
!              !            end do
!              !
!              !
!              !            print *, "TWO CENTER TRANSFORMED INTEGRALS FOR SPECIE: ", trim(nameOfSpecie)
!              !
!              !            do m=1,numberOfContractions
!              !                do n=1, m
!              !                    write(35,"(F20.10,4I3)") ConfigurationInteraction_instance%twoCenterIntegrals(i)%values(m,n), m, n, 0, 0
!              !                end do
!              !            end do
!
!              !!Calculating the core energy....
!
!
!
!              totalCoupEnergy = MolecularSystem_instance%totalCouplingEnergy
!              fixedPotEnergy = MolecularSystem_instance%puntualInteractionEnergy
!
!              do j = 1, numberOfSpecies
!
!                 auxNameOfSpecie= trim(  MolecularSystem_getNameOfSpecie( j ) )
!
!                 if(trim(auxNameOfSpecie) == "E-ALPHA" .or.  trim(auxNameOfSpecie) == "E-BETA" .or.  trim(auxNameOfSpecie) == "e-") cycle
!
!                 fixedIntEnergy = fixedIntEnergy + MolecularSystem_instance%quantumPuntualInteractionEnergy(j)
!                 KineticEnergy = KineticEnergy + MolecularSystem_instance%kineticEnergy(j)
!                 RepulsionEnergy = RepulsionEnergy + MolecularSystem_instance%repulsionEnergy(j)
!                 couplingEnergy = couplingEnergy + MolecularSystem_instance%couplingEnergy(j)
!
!              end do
!
!              !!COMO SEA QUE SE META LA ENERGIA DE CORE
!              !write(35,"(F20.10,4I3)") (couplingEnergy-totalCoupEnergy+fixedPotEnergy+fixedIntEnergy+KineticEnergy+RepulsionEnergy), 0, 0, 0, 0
!              
!              print*, "COREENERGY ", (couplingEnergy-totalCoupEnergy+fixedPotEnergy+fixedIntEnergy+KineticEnergy+RepulsionEnergy)
!
!              write(35,"(A)")"{hf"
!              write(35,"(A)")"maxit 250"
!              write(35,"(A10,I2,A1,A6,I2,A1,A6,I3)")"wf spin=", spin, ",", "charge=",0, ",", "elec=", MolecularSystem_getNumberOfParticles(i)-spin
!              write(35,"(A)")"start 2100.1"
!              write(35,"(A)")"}"
!
!
!              write(35,"(A)")"{fci"
!              write(35,"(A)")"maxit 250"
!              write(35,"(A)")"dm 21400.1, IGNORE_ERROR"
!              write(35,"(A)")"orbit 2100.1, IGNORE_ERROR"
!              write(35,"(A10,I2,A1,A6,I2,A1,A6,I3)")"wf spin=", spin, ",", "charge=",0, ",", "elec=", MolecularSystem_getNumberOfParticles(i)-spin
!              !            write(35,"(A)")"print, orbital=2 integral = 2"
!              !            write(35,"(A)")"CORE"
!              write(35,"(A)")"}"
!
!              write(35,"(A)")"{matrop"
!              write(35,"(A)")"load D, DEN, 21400.1"
!              !	    write(35,"(A)")"print D"
!              write(35,"(A)")"natorb Norb, D"
!              write(35,"(A)")"save Norb, 21570.2"
!              !	    write(35,"(A)")"print Norb"
!              write(35,"(A)")"}"
!
!              write(35,"(A)")"put molden "//trim(trim(CONTROL_instance%INPUT_FILE)//trim(nameOfSpecie)//"."//"molden")//"; orb, 21570.2"
!
!              close(35)
!
!              print*, ""
!
!              stats = system("molpro "//"FCIDUMP-"//trim(nameOfSpecie)//".com ")
!              stats = system("cat "//"FCIDUMP-"//trim(nameOfSpecie)//".out ")
!
!              print*, ""
!
!              print *,"END"
!              
!           end if
!
!         end if
!
!    end do
    
!  end subroutine ConfigurationInteraction_printTransformedIntegralsToFile

!  subroutine ConfigurationInteraction_printGeometryToFile(unit)
!    implicit none
!    integer :: unit
!
!    integer :: i
!    integer :: from, to
!    real(8) :: origin(3)
!    character(50) :: auxString
!
!    
!    do i = 1, MolecularSystem_getTotalNumberOfParticles()
!       
!       origin = MolecularSystem_getOrigin( iterator = i ) * AMSTRONG
!       auxString = trim( MolecularSystem_getNickName( iterator = i ) )
!       
!       if( String_findSubstring( trim( auxString ), "e-") == 1 ) then
!          if( String_findSubstring( trim( auxString ), "BETA") > 1 ) then
!             cycle
!          end if
!            
!          from =String_findSubstring( trim(auxString), "[")
!          to = String_findSubstring( trim(auxString), "]")
!          auxString = auxString(from+1:to-1)
!          
!       else if( String_findSubstring( trim( auxString ), "_") /= 0 ) then
!          cycle
!       end if
!         
!         
!       write (unit,"(A10,3F20.10)") trim( auxString ), origin(1), origin(2), origin(3)
!       
!    end do

!  end subroutine ConfigurationInteraction_printGeometryToFile


!  subroutine ConfigurationInteraction_printBasisSetToFile(unit)
!    implicit none
!
!    integer :: unit
!
!    integer :: i, j
!    character(16) :: auxString
!
!
!    do i =1, MolecularSystem_instance%numberOfQuantumSpecies
!       
!       auxString=trim( Map_getKey( MolecularSystem_instance%speciesID, iterator=i ) )
!       
!       if( String_findSubstring( trim(auxString), "e-") == 1 ) then
!          
!          if( String_findSubstring( trim(auxString), "BETA") > 1 ) then
!             
!             cycle
!             
!          end if
!          
!          
!       end if
!       
!       if(trim(auxString)=="U-") cycle
!
!       do j =1, size(MolecularSystem_instance%particlesPtr)
!
!          if (    trim(MolecularSystem_instance%particlesPtr(j)%symbol) == trim( Map_getKey( MolecularSystem_instance%speciesID, iterator=i ) ) &
!               .and. MolecularSystem_instance%particlesPtr(j)%isQuantum ) then
!             
!             call BasisSet_showInMolproForm( MolecularSystem_instance%particlesPtr(j)%basis, trim(MolecularSystem_instance%particlesPtr(j)%nickname), unit=unit )
!             
!          end if
!          
!       end do
!       
!    end do
    
!  end subroutine ConfigurationInteraction_printBasisSetToFile


  !**
  ! @ Retorna la energia final com correccion Moller-Plesset de orrden dado
  !**
  function ConfigurationInteraction_getTotalEnergy() result(output)
    implicit none
    real(8) :: output

    output = ConfigurationInteraction_instance%totalEnergy

  end function ConfigurationInteraction_getTotalEnergy


  !>
  !! @brief  Maneja excepciones de la clase
  !<
  subroutine ConfigurationInteraction_exception( typeMessage, description, debugDescription)
    implicit none
    integer :: typeMessage
    character(*) :: description
    character(*) :: debugDescription

    type(Exception) :: ex

    call Exception_constructor( ex , typeMessage )
    call Exception_setDebugDescription( ex, debugDescription )
    call Exception_setDescription( ex, description )
    call Exception_show( ex )
    call Exception_destructor( ex )

  end subroutine ConfigurationInteraction_exception

  subroutine ConfigurationInteraction_saveEigenVector () 
    implicit none
    character(50) :: nameFile
    integer :: unitFile
    integer(8) :: i, ia
    integer :: ib, nonzero
    integer, allocatable :: auxIndexArray(:)
    real(8), allocatable :: auxArray(:)
    integer :: maxStackSize

    maxStackSize = CONTROL_instance%CI_STACK_SIZE 
    nameFile = "lowdin.civec"
    unitFile = 20

    nonzero = 0
    do i = 1, ConfigurationInteraction_instance%numberOfConfigurations
      if ( abs(ConfigurationInteraction_instance%eigenVectors%values(i,1) ) >= 1E-12 ) nonzero = nonzero + 1
    end do 

    print *, "nonzero", nonzero

    allocate(auxArray(nonzero))
    allocate(auxIndexArray(nonzero))

    ia = 0
    do i = 1, ConfigurationInteraction_instance%numberOfConfigurations
      if ( abs(ConfigurationInteraction_instance%eigenVectors%values(i,1) ) >= 1E-12 ) then 
        ia = ia + 1
        auxIndexArray(ia) = i 
        auxArray(ia) = ConfigurationInteraction_instance%eigenVectors%values(i,1) 
      end if
    end do 

    open(unit=unitFile, file=trim(nameFile), status="replace", form="unformatted")

    write(unitFile) ConfigurationInteraction_instance%eigenValues%values(1)
    write(unitFile) nonzero

    do i = 1, ceiling(real(nonzero) / real(maxStackSize) )
      ib = maxStackSize * i  
      ia = ib - maxStackSize + 1
      if ( ib > nonzero ) ib = nonzero
      write(unitFile) auxIndexArray(ia:ib)
    end do
    deallocate(auxIndexArray)

    do i = 1, ceiling(real(nonzero) / real(maxStackSize) )
      ib = maxStackSize * i  
      ia = ib - maxStackSize + 1
      if ( ib > nonzero ) ib = nonzero
      write(unitFile) auxArray(ia:ib)
    end do
    deallocate(auxArray)

    close(unitFile)

  end subroutine ConfigurationInteraction_saveEigenVector

  subroutine ConfigurationInteraction_loadEigenVector (eigenValues,eigenVectors) 
    implicit none
    type(Vector8) :: eigenValues
    type(Matrix) :: eigenVectors
    character(50) :: nameFile
    integer :: unitFile
    integer :: i, ia, ib, nonzero
    real(8) :: eigenValue
    integer, allocatable :: auxIndexArray(:)
    real(8), allocatable :: auxArray(:)
    integer :: maxStackSize

    maxStackSize = CONTROL_instance%CI_STACK_SIZE 
 

    nameFile = "lowdin.civec"
    unitFile = 20


    open(unit=unitFile, file=trim(nameFile), status="old", action="read", form="unformatted")

    readvectors : do
      read (unitFile) eigenValue
      read (unitFile) nonzero
      print *, "eigenValue", eigenValue
      print *, "nonzero", nonzero

      allocate (auxIndexArray(nonzero))
      auxIndexArray = 0

      do i = 1, ceiling(real(nonZero) / real(maxStackSize) )
        ib = maxStackSize * i  
        ia = ib - maxStackSize + 1
        if ( ib >  nonZero ) ib = nonZero
       read (unitFile) auxIndexArray(ia:ib)
      end do

      allocate (auxArray(nonzero))
      auxArray = 0

      do i = 1, ceiling(real(nonZero) / real(maxStackSize) )
        ib = maxStackSize * i  
        ia = ib - maxStackSize + 1
        if ( ib >  nonZero ) ib = nonZero
       read (unitFile) auxArray(ia:ib)
      end do
      exit readvectors
    end do readvectors

    eigenValues%values(1) = eigenValue
    do i = 1, nonzero
      eigenVectors%values(auxIndexArray(i),1) = auxArray(i)
    end do

    deallocate (auxIndexArray )
    deallocate (auxArray )


    close(unitFile)

  end subroutine ConfigurationInteraction_loadEigenVector


  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine ConfigurationInteraction_diagonalize(maxn,ldv, maxnev, maxncv, eigenValues, eigenVectors)
    implicit none

  !*******************************************************************************
  !
  !! SSSIMP is a simple program to call ARPACK for a symmetric eigenproblem.
  !
  !    This code shows how to use ARPACK to find a few eigenvalues
  !    LAMBDA and corresponding eigenvectors X for the standard
  !    eigenvalue problem:
  !
  !      A * X = LAMBDA * X
  !
  !    where A is an N by N real symmetric matrix.
  !
  !    The only things that must be supplied in order to use this
  !    routine on your problem is:
  !
  !    * to change the array dimensions appropriately, 
  !    * to specify WHICH eigenvalues you want to compute
  !    * to supply a matrix-vector product
  !      w <- A * v
  !      in place of the call to AV( ) below.
  !
  !  Example by:
  !
  !    Richard Lehoucq, Danny Sorensen, Chao Yang,
  !    Department of Computational and Applied Mathematics,
  !    Rice University,
  !    Houston, Texas.
  !
  !  Storage:
  ! 
  !    The maximum dimensions for all arrays are set here to accommodate 
  !    a problem size of N <= MAXN
  !
  !    NEV is the number of eigenvalues requested.
  !    See specifications for ARPACK usage below.
  !
  !    NCV is the largest number of basis vectors that will be used in 
  !    the Implicitly Restarted Arnoldi Process.  Work per major iteration is
  !    proportional to N*NCV*NCV.
  !
  !    You must set: 
  ! 
  !    MAXN:   Maximum dimension of the A allowed. 
  !    MAXNEV: Maximum NEV allowed. 
  !    MAXNCV: Maximum NCV allowed. 

    integer(8) :: maxn 
    integer :: maxnev 
    integer :: maxncv 
    integer(8) :: ldv 
    integer :: iter
  
!    intrinsic abs
    character(1) bmat  
    character ( len = 2 ) which
    integer ido,ierr,info,iparam(11),ipntr(11),ishfts,j,lworkl,maxitr,mode1,n,nconv,ncv,nev,nx
    logical rvec
    external saxpy
    real(8) sigma
    real(8) tol
    real(8), parameter :: zero = 1E-08

!    real(8) :: v(ldv,maxncv) 
!    real(8) :: ax(maxn)
!    real(8), external :: snrm2

    !! arrays
!    real(8) d(maxnev)
!    real(8) :: resid(maxn)
!    logical select(maxncv)
!    real(8) :: z(ldv,maxnev) 
!    real(8) workl(maxncv*(maxncv+8))
!    real(8) :: workd(3*maxn)
    real(8), allocatable :: v(:,:) 
    real(8), allocatable :: d(:)
    real(8), allocatable :: resid(:),residi(:)
    real(8), allocatable :: z(:,:) 
    real(8), allocatable :: workl(:)
    real(8), allocatable :: workd(:)
    logical, allocatable :: select(:)

    type(Vector8), intent(inout) :: eigenValues
    type(Matrix), intent(inout) :: eigenVectors
    integer :: ii, jj, ia

    if (allocated(v) ) deallocate(v)
    allocate (v(ldv,maxncv))
    if (allocated(d) ) deallocate(d)
    allocate (d(maxnev))
    if (allocated(resid) ) deallocate(resid)
    allocate (resid(maxn))
    if (allocated(residi) ) deallocate(residi)
    allocate (residi(maxn))

    if (allocated(z) ) deallocate(z)
    allocate (z(ldv,maxnev))
    if (allocated(workl) ) deallocate(workl)
    allocate (workl(maxncv*(maxncv+8)))
    if (allocated(workd) ) deallocate(workd)
    allocate (workd(3*maxn))
    if (allocated(select) ) deallocate(select)
    allocate (select(maxncv))

    v = 0.0_8
    d = 0.0_8
    resid = 0.0_8
    residi = 0.0_8
    z = 0.0_8
    workl = 0.0_8
    workd = 0.0_8

  !
  !  The following include statement and assignments control trace output 
  !  from the internal actions of ARPACK.  See debug.doc in the
  !  DOCUMENTS directory for usage.  
  !
  !  Initially, the most useful information will be a breakdown of
  !  time spent in the various stages of computation given by setting 
  !  msaupd = 1.
  !
  
  !  ndigit = -3
  !  logfil = 6
  !  msgets = 0
  !  msaitr = 0
  !  msapps = 0
  !  msaupd = 1
  !  msaup2 = 0
  !  mseigt = 0
  !  mseupd = 0
  !
  !  Set dimensions for this problem.
  !
    nx = ConfigurationInteraction_instance%numberOfConfigurations
    !n = nx * nx  
    !print *, "nnn", n

  !
  !  Specifications for ARPACK usage are set below:
  !
  !  1) NEV = 4 asks for 4 eigenvalues to be computed.                            !
  !  2) NCV = 20 sets the length of the Arnoldi factorization.
  !
  !  3) This is a standard problem(indicated by bmat  = 'I')
  !
  !  4) Ask for the NEV eigenvalues of largest magnitude
  !     (indicated by which = 'LM')
  !
  !  See documentation in SSAUPD for the other options SM, LA, SA, LI, SI.
  !
  !  NEV and NCV must satisfy the following conditions:
  !
  !    NEV <= MAXNEV
  !    NEV + 1 <= NCV <= MAXNCV
  !
    nev = CONTROL_instance%NUMBER_OF_CI_STATES 
    ncv = maxncv !! 
    bmat = 'I'
    which = 'SA'

!
!  WHICH   Character*2.  (INPUT)
!          Specify which of the Ritz values of OP to compute.
!
!          'LA' - compute the NEV largest (algebraic) eigenvalues.
!          'SA' - compute the NEV smallest (algebraic) eigenvalues.
!          'LM' - compute the NEV largest (in magnitude) eigenvalues.
!          'SM' - compute the NEV smallest (in magnitude) eigenvalues. 
!          'BE' - compute NEV eigenvalues, half from each end of the
!                 spectrum.  When NEV is odd, compute one more from the
!                 high end than from the low end.
!           (see remark 1 below)

  
!    if ( maxn < n ) then
!      write ( *, '(a)' ) ' '
!      write ( *, '(a)' ) 'SSSIMP - Fatal error!'
!      write ( *, '(a)' ) '  N is greater than MAXN '
!      !stop
!    else if ( maxnev < nev ) then
!      write ( *, '(a)' ) ' '
!      write ( *, '(a)' ) 'SSSIMP - Fatal error!'
!      write ( *, '(a)' ) '  NEV is greater than MAXNEV '
!      stop
!    else if ( maxncv < ncv ) then
!      write ( *, '(a)' ) ' '
!      write ( *, '(a)' ) 'SSSIMP - Fatal error!'
!      write ( *, '(a)' ) '  NCV is greater than MAXNCV '
!      stop
!    end if
  !
  !  TOL determines the stopping criterion.  Expect
  !    abs(lambdaC - lambdaT) < TOL*abs(lambdaC)
  !  computed   true
  !  If TOL <= 0, then TOL <- macheps (machine precision) is used.
  !
  !  IDO is the REVERSE COMMUNICATION parameter
  !  used to specify actions to be taken on return
  !  from SSAUPD. (See usage below.)
  !  It MUST initially be set to 0 before the first
  !  call to SSAUPD.
  !
  !  INFO on entry specifies starting vector information
  !  and on return indicates error codes
  !  Initially, setting INFO=0 indicates that a
  !  random starting vector is requested to 
  !  start the ARNOLDI iteration.  Setting INFO to
  !  a nonzero value on the initial call is used 
  !  if you want to specify your own starting 
  !  vector. (This vector must be placed in RESID.)
  !
  !  The work array WORKL is used in SSAUPD as workspace.  Its dimension
  !  LWORKL is set as illustrated below. 
  !
    lworkl = ncv * ( ncv + 8 )
    !tol = zero
    TOL = CONTROL_instance%CI_CONVERGENCE !1.0d-4 !    tolerance for the eigenvector residual
    ido = 0
  !
  !  Specification of Algorithm Mode:
  !
  !  This program uses the exact shift strategy
  !  (indicated by setting PARAM(1) = 1).
  !
  !  IPARAM(3) specifies the maximum number of Arnoldi iterations allowed.  
  !
  !  Mode 1 of SSAUPD is used (IPARAM(7) = 1). 
  !
  !  All these options can be changed by the user.  For details see the
  !  documentation in SSAUPD.
  !
    ishfts = 1
    maxitr = 300
    mode1 = 1
  
    iparam(1) = ishfts
    iparam(3) = maxitr
    iparam(7) = mode1
  !
  !  MAIN LOOP (Reverse communication loop)
  !
  !  Repeatedly call SSAUPD and take actions indicated by parameter 
  !  IDO until convergence is indicated or MAXITR is exceeded.
  !

    !call omp_set_num_threads(omp_get_max_threads())

    !! starting vector
    resid = 0
    info = 1

    do ii = 1, CONTROL_instance%CI_SIZE_OF_GUESS_MATRIX 
      resid(ConfigurationInteraction_instance%auxIndexCIMatrix%values(ii)) = ConfigurationInteraction_instance%initialEigenVectors%values(ii,1)
      residi(ConfigurationInteraction_instance%auxIndexCIMatrix%values(ii)) = ConfigurationInteraction_instance%initialEigenVectors%values(ii,1)
    end do

    print *, ConfigurationInteraction_instance%initialEigenValues%values(1)
    iter = 0
    do
  
      call dsaupd ( ido, bmat, nx, which, nev, tol, resid, &
        maxncv, v, int(ldv,4), iparam, ipntr, workd, workl, &
        lworkl, info )
      iter = iter + 1
      if ( ido /= -1 .and. ido /= 1 ) then
        exit
      end if
  !
  !  Perform matrix vector multiplication
  !
  !    y <--- OP*x
  !
  !  The user supplies a matrix-vector multiplication routine that takes
  !  workd(ipntr(1)) as the input, and return the result to workd(ipntr(2)).
  !
      call av ( int(nx,8), workd(ipntr(1)), workd(ipntr(2)) )
      !call matvec ( nx, residi,workd(ipntr(1)), workd(ipntr(2)), iter )
  
     end do
  !
  !  Either we have convergence or there is an error.
  !
    if ( info < 0 ) then
  !
  !  Error message. Check the documentation in SSAUPD.
  !
      write ( *, '(a)' ) ' '
      write ( *, '(a)' ) 'SSSIMP - Fatal error!'
      write ( *, '(a,i6)' ) '  Error with DSAUPD, INFO = ', info
      write ( *, '(a)' ) '  Check documentation in SSAUPD.'
  
    else
  !
  !  No fatal errors occurred.
  !  Post-Process using SSEUPD.
  !
  !  Computed eigenvalues may be extracted.
  !
  !  Eigenvectors may be also computed now if
  !  desired.  (indicated by rvec = .true.)
  !
  !  The routine SSEUPD now called to do this
  !  post processing (Other modes may require
  !  more complicated post processing than mode1.)
  !
      rvec = .true.
  
      call dseupd ( rvec, 'A', select, d, z,int( ldv,4), sigma, &
        bmat, nx, which, nev, tol, resid, ncv, v, int(ldv,4), &
        iparam, ipntr, workd, workl, lworkl, ierr )
  !
  !  Eigenvalues are returned in the first column of the two dimensional 
  !  array D and the corresponding eigenvectors are returned in the first 
  !  NCONV (=IPARAM(5)) columns of the two dimensional array V if requested.
  !
  !  Otherwise, an orthogonal basis for the invariant subspace corresponding 
  !  to the eigenvalues in D is returned in V.
  !
   !! Saving the eigenvalues !! Saving the eigenvectors

      do ii = 1, maxnev
        eigenValues%values(ii) = d(ii)
      end do

      ia = 0
      do ii = 1, nx
        do jj = 1, CONTROL_instance%NUMBER_OF_CI_STATES
          eigenVectors%values(ii,jj) = z(ii,jj)
          if ( abs(z(ii,jj)) > 1E-6) ia = ia + 1 
        end do
      end do 

      if ( ierr /= 0 ) then
  
        write ( *, '(a)' ) ' '
        write ( *, '(a)' ) 'SSSIMP - Fatal error!'
        write ( *, '(a,i6)' ) '  Error with SSEUPD, IERR = ', ierr
        write ( *, '(a)' ) '  Check the documentation of SSEUPD.'
  !
  !  Compute the residual norm
  !
  !    ||  A*x - lambda*x ||
  ! 
  !  for the NCONV accurately computed eigenvalues and 
  !  eigenvectors.  (iparam(5) indicates how many are 
  !  accurate to the requested tolerance)
  !
      else
  
        nconv =  iparam(5)
!  
!        do j = 1, nconv
!          call av ( nx, v(1,j), ax )
!          call saxpy ( nx, -d(j,1), v(1,j), 1, ax, 1 )
!          d(j,2) = snrm2 ( nx, ax, 1)
!          d(j,2) = d(j,2) / abs ( d(j,1) )
!        end do
!  !
!  !  Display computed residuals.
!  !
!        call smout ( 6, nconv, 2, d, maxncv, -6, &
!          'Ritz values and relative residuals' )
  
      end if
  !
  !  Print additional convergence information.
  !
      if ( info == 1) then
        write ( *, '(a)' ) ' '
        write ( *, '(a)' ) '  Maximum number of iterations reached.'
      else if ( info == 3) then
        write ( *, '(a)' ) ' '
        write ( *, '(a)' ) '  No shifts could be applied during implicit' &
          // ' Arnoldi update, try increasing NCV.'
      end if
  
      write ( *, '(a)' ) ' '
      write ( *, '(a)' ) '====== '
      write ( *, '(a)' ) ' '
      write ( *, '(a,i6)' ) '  Size of the matrix is ', nx
      write ( *, '(a,i6)' ) '  The number of Ritz values requested is ', nev
      write ( *, '(a,i6)' ) &
        '  The number of Arnoldi vectors generated (NCV) is ', ncv
      write ( *, '(a)' ) '  What portion of the spectrum: ' // which
      write ( *, '(a,i6)' ) &
        '  The number of converged Ritz values is ', nconv
      write ( *, '(a,i8)' ) &
        '  The number of Implicit Arnoldi update iterations taken is ', iparam(3)
      write ( *, '(a,i6)' ) '  The number of OP*x is ', iparam(9)
     write ( *, '(a,g14.6)' ) '  The convergence criterion is ', tol
 
    end if
  
    write ( *, '(a)' ) ' '
    write ( *, '(a)' ) '  Normal end of execution.'
  
    write ( *, '(a)' ) ' '
    !call timestamp ( )
  
  end subroutine ConfigurationInteraction_diagonalize

  subroutine av ( nx, v, w)
  
  !*******************************************************************************
  !! AV computes w <- A * V where A is a discretized Laplacian.
  !  Parameters:
  !    Input, integer NX, the length of the vectors.
  !    Input, real V(NX), the vector to be operated on by A.
  !    Output, real W(NX), the result of A*V.
  !
    implicit none
  
    integer(8) nx
    real(8) v(nx)
    real(8) w(nx)
    character(50) :: CIFile
    integer :: CIUnit
    integer, allocatable :: jj(:)
    real(8), allocatable :: CIEnergy(:)
    integer :: nonzero,ii, kk
    integer :: maxStackSize, i, ia, ib

    CIFile = "lowdin.ci"
    CIUnit = 20
    nonzero = 0
    maxStackSize = CONTROL_instance%CI_STACK_SIZE 

    w = 0
#ifdef intel
    open(unit=CIUnit, file=trim(CIFile), action = "read", form="unformatted", BUFFERED="YES")
#else
    open(unit=CIUnit, file=trim(CIFile), action = "read", form="unformatted")
#endif

    readmatrix : do
      read (CIUnit) nonzero
      if (nonzero > 0 ) then

        read (CIUnit) ii

        if ( allocated(jj)) deallocate (jj)
        allocate (jj(nonzero))
        jj = 0

        if ( allocated(CIEnergy)) deallocate (CIEnergy)
        allocate (CIEnergy(nonzero))
        CIEnergy = 0

        do i = 1, ceiling(real(nonZero) / real(maxStackSize) )

          ib = maxStackSize * i  
          ia = ib - maxStackSize + 1
          if ( ib >  nonZero ) ib = nonZero
          read (CIUnit) jj(ia:ib)
    
        end do

        do i = 1, ceiling(real(nonZero) / real(maxStackSize) )

          ib = maxStackSize * i  
          ia = ib - maxStackSize + 1
          if ( ib >  nonZero ) ib = nonZero
          read (CIUnit) CIEnergy(ia:ib)
    
        end do

        w(ii) = w(ii) + CIEnergy(1)*v(jj(1)) !! disk
        do kk = 2, nonzero
          !w(ii) = w(ii) + ConfigurationInteraction_calculateCIenergy(ii,jj(kk))*v(jj(kk))  !! direct
          w(ii) = w(ii) + CIEnergy(kk)*v(jj(kk)) !! disk
          w(jj(kk)) = w(jj(kk)) + CIEnergy(kk)*v(ii) !! disk
        end do

      else if ( nonzero == -1 ) then
        exit readmatrix
      end if
    end do readmatrix

!! memory
!    do i = 1, nx
!        w(:) = w(:) + ConfigurationInteraction_instance%hamiltonianMatrix%values(:,i)*v(i)
!    end do 

     close(CIUnit)

    return
  end subroutine av


  subroutine ConfigurationInteraction_jadamiluInterface(n,  maxeig, eigenValues, eigenVectors)
    implicit none
    integer(8) :: maxnev
    real(8) :: CIenergy
    integer(8) :: nproc
    type(Vector8), intent(inout) :: eigenValues
    type(Matrix), intent(inout) :: eigenVectors
    !type (Vector8) :: diagonalHamiltonianMatrix

!   N: size of the problem
!   MAXEIG: max. number of wanteg eig (NEIG<=MAXEIG)
!   MAXSP: max. value of MADSPACE
    integer(8) :: n, maxeig, MAXSP
    integer(8) :: LX
    real(8), allocatable :: EIGS(:), RES(:), X(:)!, D(:)
!   arguments to pass to the routines
    integer(8) :: NEIG, MADSPACE, ISEARCH, NINIT
    integer(8) :: ICNTL(5)
    integer(8) :: ITER, IPRINT, INFO
    real(8) :: SIGMA, TOL, GAP, MEM, DROPTOL, SHIFT
    integer(8) :: NDX1, NDX2, NDX3
    integer(8) :: IJOB!   some local variables
    integer(8) :: auxSize
    integer(4) :: size1,size2
    integer(8) :: I,J,K,ii,jj,jjj
    integer(4) :: iiter
    !real(8), allocatable :: A(:)
    !integer(8), allocatable :: IA(:)
    !integer(8), allocatable :: JA(:)
    !logical :: offElement
    !type(ivector8) :: auxIndexCIMatrix2
    !integer(8) :: nonzero
    integer(8) :: macroIterations, im, finalmacroIterations
    real(8), allocatable :: macroIterationsEnergies(:)
    real(8), allocatable :: macroIterationsEnergiesDiff(:)
    integer, allocatable :: macroIterationsNumberOfIter(:)
    logical :: fullMatrix
    
    maxsp = 15
    if ( CONTROL_instance%CI_JACOBI ) then
      macroIterations = 10
    else 
      macroIterations = 1
    end if

    !size1 = size(ConfigurationInteraction_instance%configurations(1)%occupations, dim=1)
    !size2 = size(ConfigurationInteraction_instance%configurations(1)%occupations, dim=2) 

    !if (allocated (ConfigurationInteraction_instance%auxconfs ) ) deallocate (ConfigurationInteraction_instance%auxconfs ) 
    !allocate (ConfigurationInteraction_instance%auxconfs (size1,size2, ConfigurationInteraction_instance%numberOfConfigurations ))

    !do i=1, ConfigurationInteraction_instance%numberOfConfigurations
    !    ConfigurationInteraction_instance%auxconfs(:,:,i) = ConfigurationInteraction_instance%configurations(i)%occupations
    !end do
    !deallocate (ConfigurationInteraction_instance%configurations)


    allocate (macroIterationsEnergies(macroIterations))
    allocate (macroIterationsEnergiesDiff(macroIterations))
    allocate (macroIterationsNumberOfIter(macroIterations))
    macroIterationsEnergies = 0
    macroIterationsEnergiesDiff = 0
    macroIterationsNumberOfIter = 0

    LX = N*(3*MAXSP+MAXEIG+1)+4*MAXSP*MAXSP

    if ( allocated ( eigs ) ) deallocate ( eigs )
    allocate ( eigs ( maxeig ) )
    eigs = 0.0_8
    if ( allocated ( res ) ) deallocate ( res )
    allocate ( res ( maxeig ) )
    res = 0.0_8
    if ( allocated ( x ) ) deallocate ( x )
    allocate ( x ( lx ) )
    x = 0.0_8


!    set input variables
!    the matrix is already in the required format

     IPRINT = -6 !     standard report on standard output
     ISEARCH = 1 !    we want the smallest eigenvalues
     NEIG = maxeig !    number of wanted eigenvalues
     !NINIT = 0 !    no initial approximate eigenvectors
     NINIT = 1 !    initial approximate eigenvectors
     MADSPACE = maxsp !    desired size of the search space
     ITER = 100 !    maximum number of iteration steps
     TOL = CONTROL_instance%CI_CONVERGENCE !1.0d-4 !    tolerance for the eigenvector residual

     NDX1 = 0
     NDX2 = 0
     MEM = 0

!    additional parameters set to default
     ICNTL(1)=0
     ICNTL(2)=0
     ICNTL(3)=0
     ICNTL(4)=0
     ICNTL(5)=1


    MEM = 50


    IJOB=0

     ! set initial eigenpairs
     if ( CONTROL_instance%CI_LOAD_EIGENVECTOR ) then 
       print *, "Loading the eigenvector to the initial guess"
       do i = 1, n 
         X(i) = eigenVectors%values(i,1)
       end do

       do i = 1, CONTROL_instance%NUMBER_OF_CI_STATES
         EIGS(i) = eigenValues%values(i)
       end do
     else
       do i = 1, CONTROL_instance%CI_SIZE_OF_GUESS_MATRIX 
         X(ConfigurationInteraction_instance%auxIndexCIMatrix%values(i)) = ConfigurationInteraction_instance%initialEigenVectors%values(i,1)
       end do

       do i = 1, CONTROL_instance%NUMBER_OF_CI_STATES
         EIGS(i) = ConfigurationInteraction_instance%initialEigenValues%values(i)
       end do
     end if

    !DROPTOL = 1 - X(1)**2
    !DROPTOL = 5E-2
    DROPTOL = 0
    print *, "Droptopl : ", Droptol
    !! preconditioner. 
    !! auxSize = CONTROL_instance%CI_SIZE_OF_GUESS_MATRIX 
    !!nonzero = 0
    !!do i = 1 , auxSize
    !!  do j = i + 1 , auxSize
    !!    if ( abs(ConfigurationInteraction_instance%initialHamiltonianMatrix2%values(i,j)) > 1E-10) nonzero = nonzero + 1
    !!  end do
    !!end do
    !!print *, "Nonzero initial Hamiltonian matrix elements", nonzero

    !!allocate (A ( nonzero + n ) ) 
    !!A = 0
    !!allocate (JA ( nonzero + n ) ) 
    !!JA = 0
    !!allocate (IA ( n + 1 ) ) 
    !!IA = 0

    !!do i = auxSize+1, n
    !!  ConfigurationInteraction_instance%auxIndexCIMatrix%values(i) = n + 1
    !!end do

    !!call Vector_constructorInteger8 ( auxIndexCIMatrix2, ConfigurationInteraction_instance%numberOfConfigurations, 0_8 ) 
    !!call Vector_reverseSortElements8Int(ConfigurationInteraction_instance%auxIndexCIMatrix, auxIndexCIMatrix2, int(auxSize,8))

    !!k = 1 
    !!do i = 1, n
    !!   if ( i <= n ) then
    !!     offElement = .false. 
    !!     do j = 1, auxSize
    !!        jj = ConfigurationInteraction_instance%auxIndexCIMatrix%values(j)
    !!        if ( jj == i ) then
    !!          offElement = .true.
    !!          ii = j
    !!        end if
    !!     end do
    !!     if ( .not. offElement  ) then
    !!        ja(k) = i 
    !!        a(k) = ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values(i)
    !!        ia(i) = k !! diagonal
    !!        k = k + 1
    !!     else 
    !!        ia(i) = k! + auxSize
    !!        do j = 1, auxSize
    !!          jj = ConfigurationInteraction_instance%auxIndexCIMatrix%values(j)
    !!          if ( jj >= i ) then
    !!            ja(k) = jj
    !!            if ( abs(ConfigurationInteraction_instance%initialHamiltonianMatrix2%values(ii,j)) > 1E-10) then
    !!              a(k) = ConfigurationInteraction_instance%initialHamiltonianMatrix2%values(ii,j)
    !!              k = k + 1
    !!            end if
    !!          end if
    !!        end do
    !!     end if

    !!   end if
    !!end do

    !! ia(n+1) = k!! last 

     SIGMA = EIGS(1)
     gap = 0 
     SHIFT = EIGS(1)

     !! macroiterations
     do im = 1, macroIterations 
        print *, "Eigenvalue(1)", eigs(1), "Eigenvector(1)", x(1)
        iiter = 0
  
!10     CALL DPJDREVCOM( N, A, JA, IA,EIGS, RES, X, LX, NEIG, &
!                        SIGMA, ISEARCH, NINIT, MADSPACE, ITER, TOL, &
!                        SHIFT, DROPTOL, MEM, ICNTL, &
!                        IJOB, NDX1, NDX2, IPRINT, INFO, GAP)
  10   CALL DPJDREVCOM( N, ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values ,-1_8,-1_8,EIGS, RES, X, LX, NEIG, &
                        SIGMA, ISEARCH, NINIT, MADSPACE, ITER, TOL, &
                        SHIFT, DROPTOL, MEM, ICNTL, &
                        IJOB, NDX1, NDX2, IPRINT, INFO, GAP)
        if (CONTROL_instance%CI_JACOBI ) then
          fullMatrix = .false.
        else 
          fullMatrix = .true.
        end if
  !!    your private matrix-vector multiplication
  
        iiter = iiter +1
        IF (IJOB.EQ.1) THEN
  !!       X(NDX1) input,  X(NDX2) output
          if ( CONTROL_instance%CI_BUILD_FULL_MATRIX ) then
            call av ( n, x(ndx1), x(ndx2))
          else 
            !call matvec(N,X(1),X(NDX1),X(NDX2),iiter, im, fullMatrix, size1,size2)
            call matvec2 ( N, X(NDX1), X(NDX2), iiter, im)
          end if

          GOTO 10
        END IF
  
        macroIterationsNumberOfIter(im) = iter
        !! saving the eigenvalues

         do i = 1, CONTROL_instance%NUMBER_OF_CI_STATES
           eigenValues%values(i) = EIGS(i)
         end do

        macroIterationsEnergies(im) = EIGS(1)
        macroIterationsEnergiesDiff(im) = macroIterationsEnergies(im)- macroIterationsEnergies(im-1)

        !! saving the eigenvectors
        k = 0
        do j = 1, maxeig
          do i = 1, N
            k = k + 1
            eigenVectors%values(i,j) = X(k)
          end do
        end do
        
        !! cleaning X and eigs
        x = 0
        eigs = 0
  
        !! reloading the final results
         do i = 1, n
           X(i) = eigenVectors%values(i,1)
         end do
  
         do i = 1, CONTROL_instance%NUMBER_OF_CI_STATES
           EIGS(i) = eigenValues%values(i)
         end do

         SIGMA = EIGS(1)
         gap = 0 
         !gap=  ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values(1)- ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values(2)
         SHIFT = EIGS(1)

         !! reseting variables
         RES = 0
         NDX1 = 0
         NDX2 = 0
         MEM = 0
         ITER = 100

         IPRINT = -6 !     standard report on standard output
         ISEARCH = 1 !    we want the smallest eigenvalues
         NEIG = maxeig !    number of wanted eigenvalues
         NINIT = 1 !    initial approximate eigenvectors
         MADSPACE = maxsp !    desired size of the search space
         ITER = 100 !    maximum number of iteration steps
         TOL = CONTROL_instance%CI_CONVERGENCE !1.0d-4 !    tolerance for the eigenvector residual

         ICNTL(1)=0
         ICNTL(2)=0
         ICNTL(3)=0
         ICNTL(4)=0
         ICNTL(5)=1
         IJOB = 0
    
         finalmacroIterations = im
         if ( abs(macroIterationsEnergiesDiff(im)) <= 1E-8 ) exit

      end do
!    release internal memory and discard preconditioner
      CALL PJDCLEANUP
      print *, " Macro iterations"
      print *, " i, Energy(i), Energy Diff (E(i) - E(i-1) "
      do im = 1,  finalmacroIterations
        print *, im,  macroIterationsNumberOfIter(im), macroIterationsEnergies(im), macroIterationsEnergiesDiff(im)
      end do
      !! saving the eigenvalues
      eigenValues%values = EIGS

      !! saving the eigenvectors
      k = 0
      do j = 1, maxeig
        do i = 1, N
          k = k + 1
          eigenVectors%values(i,j) = X(k)
        end do
      end do

  end subroutine ConfigurationInteraction_jadamiluInterface

  subroutine matvec ( nx, y, v, w, iter, im, fullMatrix,size1,size2)
  
  !*******************************************************************************
  !! AV computes w <- A * V where A is a discretized Laplacian.
  !  Parameters:
  !    Input, integer NX, the length of the vectors.
  !    Input, real V(NX), the vector to be operated on by A.
  !    Output, real W(NX), the result of A*V.
  !
    implicit none
  
    integer(8) nx
    real(8) y(nx)
    real(8) v(nx)
    real(8) w(nx)
    real(8) :: CIEnergy
    integer(8) :: nonzero
    integer(8) :: i, j, ia, ib, ii, jj, im, iii, jjj
    integer(4) :: nproc
    real(8) :: wi
    real(8) :: timeA, timeB
    real(8) :: tol
    integer(4) :: iter, size1, size2
    integer(8), allocatable :: indexArray(:)
    logical :: fullMatrix
    integer :: auxSize

    auxSize = CONTROL_instance%CI_SIZE_OF_GUESS_MATRIX 

    nproc = omp_get_max_threads()

    call omp_set_num_threads(omp_get_max_threads())
    call omp_set_num_threads(nproc)

    CIenergy = 0.0_8
    nonzero = 0
    w = 0 

    tol = 1E-8

    if (  fullMatrix ) then

      do i = 1 , nx
        if ( abs(v(i) ) >= tol) nonzero = nonzero + 1
      end do
  
      allocate(indexArray(nonzero))
      indexArray = 0
    
      ia = 0
      do i = 1 , nx
        if ( abs(v(i) ) >= tol) then
          ia = ia + 1
          indexArray(ia) = i
        end if
      end do

    else
      do i = 1 , nx
        if ( abs(v(i)+y( i) ) >= tol) nonzero = nonzero + 1
      end do
  
      allocate(indexArray(nonzero))
      indexArray = 0
    
      ia = 0
      do i = 1 , nx
        if ( abs(v(i)+y(i) ) >= tol) then
          ia = ia + 1
          indexArray(ia) = i
        end if
      end do
    end if

    !size1 = size(ConfigurationInteraction_instance%configurations(1)%occupations, dim=1)
    !size2 = size(ConfigurationInteraction_instance%configurations(1)%occupations, dim=2) 


    timeA = omp_get_wtime()
    if (  fullMatrix  ) then
     ! print *, "full"
     !do i = 1, nx
     !   w(i) = w(i) + ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values(i)*v(i)  !! direc
     ! end do
      !do i = 1, nonzero
      !  ii = indexArrayyy(i)

      !  !$omp parallel &
      !  !$omp& private(j,jj,CIEnergy),&
      !  !$omp& shared(i,ConfigurationInteraction_instance, HartreeFock_instance,v,nx,w,size1,size2) 
      !  !$omp do 
      !  do j = 1 , nx
      !    !jj = indexArray(j)
      !    jj = j

      !    CIenergy = ConfigurationInteraction_calculateCoupling( ii, jj, size1, size2  )
      !    w(jj) = w(jj) + CIEnergy*v(ii)  !! direct
      !    ib = ib + 1    
      !  end do 
      !  !$omp end do nowait
      !  !$omp end parallel
      !end do 

      do i = 1, nx
      !do ii = 1, nonzero
        !i = indexArray(ii)
        !do i = 1, nx
        w(i) = w(i) + ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values(i)*v(i)  !! direct
        wi = 0
        !$omp parallel &
        !$omp& private(j,CIEnergy),&
        !$omp& shared(i,ConfigurationInteraction_instance, HartreeFock_instance,v,nx,w,size1,size2) reduction (+:wi)
        !$omp do schedule (guided)
        do j = i+1 , nx
            CIenergy = ConfigurationInteraction_calculateCouplingB( i, j, size1, size2  )

            w(j) = w(j) + CIEnergy*v(i)  !! direct
            wi = wi + CIEnergy*v(j)  !! direct
        end do 
        !$omp end do nowait
        !$omp end parallel
        w(i) = w(i) + wi
      end do 

    else
      if (  iter == 1  ) then

      do ii = 1, nonzero
        i = indexArray(ii)
        !do i = 1, nx
        w(i) = w(i) + ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values(i)*v(i)  !! direct
        wi = 0
        !$omp parallel &
        !$omp& private(j,CIEnergy),&
        !$omp& shared(i,ConfigurationInteraction_instance, HartreeFock_instance,v,nx,w,size1,size2) reduction (+:wi)
        !$omp do schedule (guided)
        do j = i+1 , nx
            CIenergy = ConfigurationInteraction_calculateCouplingB( i, j, size1, size2  )

            w(j) = w(j) + CIEnergy*v(i)  !! direct
            wi = wi + CIEnergy*v(j)  !! direct
        end do 
        !$omp end do nowait
        !$omp end parallel
        w(i) = w(i) + wi
      end do 

      else 

      do ii = 1, nonzero
        i = indexArray(ii)
        w(i) = w(i) + ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values(i)*v(i)  !! direct
        wi = 0
        !$omp parallel &
        !$omp& private(j,jj,CIEnergy),&
        !$omp& shared(i,v,nonzero,w,size1,size2) reduction (+:wi) 
        !$omp do schedule (guided)
        do jj = ii+1 , nonzero
            j = indexArray(jj)
            CIenergy = ConfigurationInteraction_calculateCouplingB( i, j, size1, size2  )

            w(j) = w(j) + CIEnergy*v(i)  !! direct
            wi = wi + CIEnergy*v(j)  !! direct
        end do 
        !$omp end do nowait
        !$omp end parallel
        w(i) = w(i) + wi
      end do 

      !!do ii = 1, nonzero
      !!  i = indexArray(ii)
      !!  !do i = 1, nx
      !!  w(i) = w(i) + ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values(i)*v(i)  !! direct
      !!  wi = 0

      !!  iii = ConfigurationInteraction_instance%auxIndexCIMatrix%values(i)
      !!  if ( iii <=  auxSize ) then
      !!  !$omp parallel &
      !!  !$omp& private(j,jj,jjj,CIEnergy),&
      !!  !$omp& shared(i,iii,v,nonzero,w,size1,size2) reduction (+:wi) 
      !!  !$omp do schedule (guided)
      !!  do jj = ii+1 , nonzero
      !!      j = indexArray(jj)
      !!      jjj = ConfigurationInteraction_instance%auxIndexCIMatrix%values(j)

      !!       if ( jjj <=  auxSize ) then
      !!      CIenergy = ConfigurationInteraction_instance%initialHamiltonianMatrix2%values(iii,jjj)
      !!      !CIenergy = ConfigurationInteraction_calculateCouplingB( i, j, size1, size2  )

      !!      w(j) = w(j) + CIEnergy*v(i)  !! direct
      !!      wi = wi + CIEnergy*v(j)  !! direct
      !!      end if
      !!  end do 
      !!  !$omp end do nowait
      !!  !$omp end parallel
      !!  end if
      !!  w(i) = w(i) + wi
      !!end do 

      end if
    end if
    deallocate(indexArray)

    timeB = omp_get_wtime()
    !!write(*,"(A,I2,A,E10.3,A2,I12,A2,I12)") "  ", iter, "  ", timeB - timeA ,"  ", ia, "  ", ib
    write(*,"(A,I2,A,E10.3,A2,I12)") "  ", iter, "  ", timeB - timeA ,"  ", ia

    return

  end subroutine matvec

  subroutine matvec2 ( nx, v, w, iter, im)
  
  !*******************************************************************************
  !! AV computes w <- A * V where A is a discretized Laplacian.
  !  Parameters:
  !    Input, integer NX, the length of the vectors.
  !    Input, real V(NX), the vector to be operated on by A.
  !    Output, real W(NX), the result of A*V.
  !
    implicit none
  
    integer(8) nx
    real(8) y(nx)
    real(8) v(nx)
    real(8) w(nx)
    real(8) :: CIEnergy
    integer(8) :: nonzero
    integer(8) :: i, j, ia, ib, ii, jj, im, iii, jjj
    integer(4) :: nproc
    real(8) :: wi
    real(8) :: timeA, timeB
    real(8) :: tol
    integer(4) :: iter, size1, size2
    integer(8), allocatable :: indexArray(:)
    logical :: fullMatrix
    integer :: auxSize
    integer(8) :: a,b,c
    integer :: s, numberOfSpecies, auxnumberOfSpecies
    integer(1) :: coupling
    integer(8) :: numberOfConfigurations
    integer(8), allocatable :: indexConf(:)
    integer(8), allocatable :: excitationLevel(:)



    auxSize = CONTROL_instance%CI_SIZE_OF_GUESS_MATRIX 

    nproc = omp_get_max_threads()

    call omp_set_num_threads(omp_get_max_threads())
    call omp_set_num_threads(nproc)

    CIenergy = 0.0_8
    nonzero = 0
    w = 0 

    tol = 1E-8


      do i = 1 , nx
        if ( abs(v(i) ) >= tol) nonzero = nonzero + 1
      end do
  
      allocate(indexArray(nonzero))
      indexArray = 0
    
      ia = 0
      do i = 1 , nx
        if ( abs(v(i) ) >= tol) then
          ia = ia + 1
          indexArray(ia) = i
        end if
      end do

    timeA = omp_get_wtime()
      !!do i = 1, nx
      !!!do ii = 1, nonzero
      !!  !i = indexArray(ii)
      !!  !do i = 1, nx
      !!  w(i) = w(i) + ConfigurationInteraction_instance%diagonalHamiltonianMatrix%values(i)*v(i)  !! direct
      !!  wi = 0
      !!  do j = i+1 , nx
      !!      CIenergy = ConfigurationInteraction_calculateCouplingB( i, j, size1, size2  )

      !!      w(j) = w(j) + CIEnergy*v(i)  !! direct
      !!      wi = wi + CIEnergy*v(j)  !! direct
      !!  end do 
      !!  w(i) = w(i) + wi
      !!end do 

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()

    s = 0
    c = 0

    allocate ( excitationLevel ( numberOfSpecies ) )
    excitationLevel = 0

    allocate ( indexConf ( numberOfSpecies ) )
    indexConf = 0
    !! call recursion
    s = 0
    c = 0
!$  timeA = omp_get_wtime()
    auxnumberOfSpecies = ConfigurationInteraction_buildMatrixRecursion( s, numberOfSpecies, indexConf,  c, v, w, nx )
!$  timeB = omp_get_wtime()

    do a = 1,numberOfConfigurations
!      print *, a, ConfigurationInteraction_instance%hamiltonianMatrix2%values(a,a)
    end do

    !     call Matrix_eigen_select (ConfigurationInteraction_instance%hamiltonianMatrix2, ConfigurationInteraction_instance%eigenvalues, &
    !          int(1), int(CONTROL_instance%NUMBER_OF_CI_STATES), &  
    !          eigenVectors = ConfigurationInteraction_instance%eigenVectors, &
    !          flags = int(SYMMETRIC,4))
    !print *, "Eigen test",  ConfigurationInteraction_instance%eigenvalues%values(1)




    deallocate ( indexConf )
    deallocate ( excitationLevel )

    deallocate(indexArray)

    timeB = omp_get_wtime()
    write(*,"(A,I2,A,E10.3,A2,I12)") "  ", iter, "  ", timeB - timeA ,"  ", ia

    return

  end subroutine matvec2

end module ConfigurationInteraction_

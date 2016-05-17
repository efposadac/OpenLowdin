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

module Configuration_
  use Vector_
  use Exception_
  use MolecularSystem_
  implicit none

  !>
  !! @brief Description
  !!
  !! @author felix
  !!
  !! <b> Creation data : </b> 07-24-12
  !!
  !! <b> History change: </b>
  !!
  !!   - <tt> 07-24-12 </tt>:  felix ( email@server )
  !!        -# description.
  !!   - <tt> MM-DD-YYYY </tt>:  authorOfChange ( email@server )
  !!        -# description
  !!
  !<
  type, public :: Configuration
     character(20) :: name
     logical :: isInstanced
     type(Vector) :: coefficients
     type(Vector), allocatable :: occupations(:)
     type(Vector) :: order !! 1=single, 2=double, 3=triple, etc
  end type Configuration

  public :: &
       Configuration_constructor, &
       Configuration_destructor, &
       Configuration_show

  private		
contains


  !>
  !! @brief Constructor por omision
  !!
  !! @param this
  !<
  subroutine Configuration_constructor(this,occupiedCode,unoccupiedCode,order,numberOfConfigurations)
    implicit none
    type(Configuration) :: this
    type(Vector) :: order
    type(Vector) :: occupiedCode
    type(Vector) :: unoccupiedCode
    integer :: numberOfConfigurations

    integer :: numberOfOccupiedOrbitals 
    integer :: numberOfOrbitals 
    integer :: i,j
    integer :: numberOfSpecies
    integer :: div1
    integer :: div2
    integer :: lambda !Ocupation per orbital

    call Vector_constructor( this%coefficients, numberOfConfigurations, 0.0_8 )
    call Vector_copyConstructor( this%order, order )

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()
    allocate ( this%occupations(numberOfSpecies) )

    do i=1, numberOfSpecies
       !spin orbitals not spatial orbitals
       lambda=MolecularSystem_getLambda(i)
       numberOfOccupiedOrbitals=MolecularSystem_getOcupationNumber(i)*lambda
       numberOfOrbitals=MolecularSystem_getTotalNumberOfContractions(i)*lambda

       call Vector_constructor ( this%occupations(i), numberOfOrbitals , 0.0_8 )
      !  print *, "occ"
       !call Vector_show(occupiedCode)
       ! print *, "ucc"
       !call Vector_show(unoccupiedCode)

       do j=1, numberOfOccupiedOrbitals
          this%occupations(i)%values(j)=1
       end do

       div1= int(occupiedCode%values(i))
       div2= int(unoccupiedCode%values(i))

       do j=this%order%values(i), 1, -1 
          this%occupations(i)%values( MOD ( div1, 1024 ) ) = this%occupations(i)%values( MOD ( div1, 1024 ) ) - 1
          div1= div1/1024
          this%occupations(i)%values( MOD ( div2, 1024 ) ) = this%occupations(i)%values( MOD ( div2, 1024 ) ) + 1
          div2= div2/1024
       end do
       print *, "conf"
        call vector_show (this%occupations(i))

       
    end do

    this%isInstanced = .true.

  end subroutine Configuration_constructor


  !>
  !! @brief Destructor por omision
  !!
  !! @param this
  !<
  subroutine Configuration_destructor(this)
    implicit none
    type(Configuration) :: this
    integer :: i, numberOfSpecies

    call Vector_destructor( this%coefficients )
    call Vector_destructor( this%order )

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()

    do i=1, numberOfSpecies
       call Vector_destructor ( this%occupations(i) )
      
    end do

    deallocate ( this%occupations )

    this%isInstanced = .false.

  end subroutine Configuration_destructor

  !>
  !! @brief Muestra informacion del objeto
  !!
  !! @param this 
  !<
  subroutine Configuration_show(this)
    implicit none
    type(Configuration) :: this

    integer :: i, numberOfSpecies

    numberOfSpecies = MolecularSystem_getNumberOfQuantumSpecies()

    print *, "Configuration"
    print *, "-------------"

    do i=1, numberOfSpecies
       print *, "For specie ", MolecularSystem_getNameOfSpecie ( i )
       print *, "Excitations: ", this%order%values(i)
       print *, "Occupations"
       call Vector_show ( this%occupations(i) )
    end do

  end subroutine Configuration_show

  !!>
  !! @brief Indica si el objeto ha sido instanciado o no
  !!
  !<
  function Configuration_isInstanced( this ) result( output )
    implicit  none
    type(Configuration), intent(in) :: this
    logical :: output

    output = this%isInstanced

  end function Configuration_isInstanced

  !>
  !! @brief  Maneja excepciones de la clase
  !<
  subroutine Configuration_exception( typeMessage, description, debugDescription)
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

  end subroutine Configuration_exception

end module Configuration_

!!******************************************************************************
!!	This code is part of LOWDIN Quantum chemistry package                 
!!	
!!	this program has been developed under direction of:
!!
!!	Prof. A REYES' Lab. Universidad Nacional de Colombia
!!		http://www.qcc.unal.edu.co
!!	Prof. R. FLORES' Lab. Universidad de Guadalajara
!!		http://www.cucei.udg.mx/~robertof
!!
!!		Todos los derechos reservados, 2013
!!
!!******************************************************************************

!>
!! @brief Moller-Plesset and APMO-Moller-Plesset program.
!!        This module allows to make calculations in the APMO-Moller-Plesset framework
!! @author  J.M. Rodas, E. F. Posada and S. A. Gonzalez.
!!
!! <b> Creation date : </b> 2013-10-03
!!
!! <b> History: </b>
!!
!!   - <tt> 2008-05-25 </tt>: Sergio A. Gonzalez M. ( sagonzalezm@unal.edu.co )
!!        -# Creacion de modulo y procedimientos basicos para correccion de segundo orden
!!   - <tt> 2011-02-15 </tt>: Fernando Posada ( efposadac@unal.edu.co )
!!        -# Adapta el módulo para su inclusion en Lowdin 1
!!   - <tt> 2013-10-03 </tt>: Jose Mauricio Rodas (jmrodasr@unal.edu.co)
!!        -# Rewrite the module as a program and adapts to Lowdin 2
!!
!! @warning This programs only works linked to lowdincore library, and using lowdin-ints.x and lowdin-SCF.x programs, 
!!          all those tools are provided by LOWDIN quantum chemistry package
!!
module MMFunctions_
  use CONTROL_
  use BondsUFF_
  use AtomTypeUFF_
  use EnergyUFF_
  use Exception_
  implicit none


	type :: MolecularMechanics
    
       	character(50) :: ffmethod
        logical :: isInstanced

	end type MolecularMechanics

       type(MolecularMechanics), target :: MolecularMechanics_instance

       public :: &
            MolecularMechanics_constructor, &
            MolecularMechanics_destructor, &
            MolecularMechanics_run

contains
	!**
	! Define el constructor para la clase
	!
	!**
  subroutine MolecularMechanics_constructor()
    implicit none
  
    MolecularMechanics_instance%isInstanced =.true.

  end subroutine MolecularMechanics_constructor

	!**
	! Define el destructor para clase
	!
	!**
  subroutine MolecularMechanics_destructor()
    implicit none

    MolecularMechanics_instance%isInstanced =.false.

  end subroutine MolecularMechanics_destructor

  subroutine MolecularMechanics_run( ffmethod )
    implicit none
    character(50), intent(in) :: ffmethod
    type(Exception) :: ex
    character(10), allocatable :: ffAtomType(:)
    
    MolecularMechanics_instance%ffmethod = ffmethod

    if ( MolecularMechanics_instance%isInstanced ) then
    
       if ( MolecularMechanics_instance%ffmethod == "UFF" ) then
          call BondsUFF_getBondOrders()
          call AtomTypeUFF_run(ffAtomType)
          call EnergyUFF_run(ffAtomType)
       else
          call Exception_constructor( ex , ERROR )
          call Exception_setDebugDescription( ex, "Class object MolecularMechanics in run() function" )
          call Exception_setDescription( ex, "This Force Field hasn't been implemented" )
          call Exception_show( ex )
       end if
    else
       call Exception_constructor( ex , ERROR )
       call Exception_setDebugDescription( ex, "Class object MolecularMechanics in run() function" )
       call Exception_setDescription( ex, "You should to instance MolecularMechanics module before use this function" )
       call Exception_show( ex )
    end if

  end subroutine MolecularMechanics_run

subroutine MolecularMechanics_exception( typeMessage, description, debugDescription)
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

end subroutine MolecularMechanics_exception

  
end module MMFunctions_

!!******************************************************************************
!!	This code is part of LOWDIN Quantum chemistry package                 
!!	
!!	this program has been developed under direction of:
!!
!!	Prof. A REYES' Lab. Universidad Nacional de Colombia
!!		http://sites.google.com/a/bt.unal.edu.co/andresreyes/home
!!	Prof. R. FLORES' Lab. Universidad de Guadalajara
!!		http://www.cucei.udg.mx/~robertof
!!	Prof. G. MERINO's Lab. Universidad de Guanajuato
!!		http://quimera.ugto.mx/qtc/gmerino.html
!!
!!	Authors:
!!		E. F. Posada (efposadac@unal.edu.co)
!!		R. Flores (roberto.floresmoreno.qt@gmail.com)
!!
!!	Contributors:
!!
!!		Todos los derechos reservados, 2011
!!
!!******************************************************************************

module InputOutput_
  use Exception_
  use OutputManager_
  use Vector_
	implicit none

	!>
	!! @brief Description
	!!
	!! @author felix
	!!
	!! <b> Creation data : </b> 08-04-11
	!!
	!! <b> History change: </b>
	!!
	!!   - <tt> 08-04-11 </tt>:  felix ( email@server )
	!!        -# description.
	!!   - <tt> 10-31-2014 </tt>:  Jorge Charry ( jacharry@unal.edu.co )
	!!        -# Adapts this module to Lowdin2
	!!   - <tt> MM-DD-YYYY </tt>:  authorOfChange ( email@server )
	!!        -# description
	!!
	!<
	type, public :: InputOutput
		character(50) :: type
		character(50) :: specie
		integer :: orbital
		integer :: dimensions
        real(8) :: cubeSize
        type(Vector) :: point1
        type(Vector) :: point2
        type(Vector) :: point3
		logical :: isInstanced
	end type

		character(50) :: Output_type
		character(50) :: Output_specie
		integer :: Output_orbital
		integer :: Output_dimensions
        real(8) :: Output_cubeSize
        real(8) :: Output_point1(3)
        real(8) :: Output_point2(3)
        real(8) :: Output_point3(3)

	NAMELIST /Output/ &
            Output_type, &
            Output_specie, &
            Output_orbital, &
            Output_dimensions, &
            Output_cubeSize, &
            Output_point1, &
            Output_point2, &
            Output_point3

	public :: &
		InputOutput_constructor, &
		InputOutput_destructor, &
		InputOutput_show, &
                InputOutput_load
		
private	

	!<Singleton
	type(InputOutput), allocatable, public :: InputOutput_Instance(:)

contains


	!>
	!! @brief Constructor por omision
	!!
	!! @param this
	!<
	subroutine InputOutput_constructor(ssize)
		implicit none
		integer :: ssize
                integer :: i

                if(.not.allocated(InputOutput_Instance)) then
                   allocate(InputOutput_Instance(ssize))
                   InputOutput_Instance%type=""
                   InputOutput_Instance%specie=""
                   InputOutput_Instance%orbital=0
                   InputOutput_Instance%dimensions=0
                   InputOutput_Instance%cubeSize=0.0_8
                   do i=1, size(InputOutput_Instance)
                      call Vector_constructor( InputOutput_Instance(i)%point1, 3, 0.0_8)
                      call Vector_constructor( InputOutput_Instance(i)%point2, 3, 0.0_8)
                      call Vector_constructor( InputOutput_Instance(i)%point3, 3, 0.0_8)
                   end do
                end if
                open (unit=4, file=trim(CONTROL_instance%INPUT_FILE)//"aux")

	end subroutine InputOutput_constructor


	!>
	!! @brief Destructor por omision
	!!
	!! @param this
	!<
	subroutine InputOutput_destructor()
		implicit none
                integer :: i 

                  do i=1, size(InputOutput_Instance)
                     call Vector_destructor( InputOutput_Instance(i)%point1)
                     call Vector_destructor( InputOutput_Instance(i)%point2)
                     call Vector_destructor( InputOutput_Instance(i)%point3)
                  end do

		if(allocated(InputOutput_Instance)) then
			deallocate(InputOutput_Instance)
		end if

	end subroutine InputOutput_destructor

	!>
	!! @brief Muestra informacion del objeto
	!!
	!! @param this 
	!<
	subroutine InputOutput_show(this)
		implicit none
		type(InputOutput) :: this
	end subroutine InputOutput_show

	!>
	!! @brief Carga la informacion de potenciales externos desde el input
	!!
	!! @param this
	!<
	subroutine  InputOutput_load( )
		implicit none
		integer :: i
		integer :: stat

		if ( allocated(InputOutput_Instance) ) then
		rewind(4)
                   do i=1, size(InputOutput_Instance)
                      Output_type=""
                      Output_specie=""
                      Output_orbital=0
                      Output_dimensions=0
                      Output_cubeSize=0.0_8
                      Output_point1=0.0_8
                      Output_point2=0.0_8
                      Output_point3=0.0_8
                      read(4,NML=Output, iostat=stat)

                      if(stat > 0 ) then

                         call InputOutput_exception( ERROR, "Class object InputOutput in the load function", &
                              "check the EXTERPOTENTIAL block in your input file")
                      end if

                      InputOutput_Instance(i)%type = trim(Output_type)
                      InputOutput_Instance(i)%specie = trim(Output_specie)
                      InputOutput_Instance(i)%orbital = Output_orbital
                      InputOutput_Instance(i)%dimensions = Output_dimensions
                      InputOutput_Instance(i)%cubeSize = Output_cubeSize
                      InputOutput_Instance(i)%point1%values = Output_point1
                      InputOutput_Instance(i)%point2%values = Output_point2
                      InputOutput_Instance(i)%point3%values = Output_point3

                   end do

			call OutputManager_constructor( OutputManager_instance, &
                                                         InputOutput_Instance%type, &
                                                         InputOutput_Instance%specie, & 
                                                         InputOutput_Instance%orbital, &
                                                         InputOutput_Instance%dimensions, &
                                                         InputOutput_Instance%cubeSize, &
                                                         InputOutput_Instance%point1, & 
                                                         InputOutput_Instance%point2, &
                                                         InputOutput_Instance%point3  )
                        
		else

			call InputOutput_exception( ERROR, "Class object InputOutput in the load function", &
													"The Input_Parsing module wasn't instanced")
		end if

	end subroutine InputOutput_load


	!!>
	!! @brief Indica si el objeto ha sido instanciado o no
	!!
	!<
	function InputOutput_isInstanced( this ) result( output )
		implicit  none
		type(InputOutput), intent(in) :: this
		logical :: output
		
		output = this%isInstanced
	
	end function InputOutput_isInstanced

	!>
	!! @brief  Maneja excepciones de la clase
	!<
	subroutine InputOutput_exception( typeMessage, description, debugDescription)
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
	
	end subroutine InputOutput_exception

end module InputOutput_

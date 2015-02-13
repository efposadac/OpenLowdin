
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
!!
!!	Contributors:
!!
!!		Todos los derechos reservados, 2011
!!
!!******************************************************************************

!>
!!
!! This program organizes the modules necessary to calcutate Wavefuncion plots and
!! to write the HF wavefunction to the molden format, implemented in Lowdin1
!!
!! @author Jorge Charry ( jacharrym@unaledu.co ), Mauricio Rodas (jmrodasr@unal.edu.co)
!!
!! <b> Fecha de creacion : </b> 2014-01-31
!!
!! <b> Historial de modificaciones: </b>
!!
!<

program Output_
  use MolecularSystem_
  use Matrix_
  use InputOutput_
  use OutputManager_
  implicit none

  character(50) :: job
  integer :: numberOfOutputs

  job = ""
  call get_command_argument(1,value=job)  
  job = trim(String_getUppercase(job))
  read(job,"(I10)"), numberOfOutputs

  !!Load CONTROL Parameters
  call MolecularSystem_loadFromFile( "LOWDIN.DAT" )

  !!Load the system in lowdin.sys format
  call MolecularSystem_loadFromFile( "LOWDIN.SYS" )

  call InputOutput_constructor( numberOfOutputs )
  call InputOutput_load( )

  call OutputManager_buildOutputs(OutputManager_instance)
  call OutputManager_show(OutputManager_instance)

end program Output_






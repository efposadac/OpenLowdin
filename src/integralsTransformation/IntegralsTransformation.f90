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
!! @brief Integrals transformation program.
!!        This module allows to make calculations in the APMO framework
!! @author  J. A. Charry, J.M. Rodas, E. F. Posada and S. A. Gonzalez.
!!
!! <b> Creation date : </b> 2014-08-26
!!
!! <b> History: </b>
!!
!!   - <tt> 2008-05-25 </tt>: Sergio A. Gonzalez M. ( sagonzalezm@unal.edu.co )
!!        -# Creacion de modulo y procedimientos basicos para correccion de segundo orden
!!   - <tt> 2011-02-15 </tt>: Fernando Posada ( efposadac@unal.edu.co )
!!        -# Adapta el módulo para su inclusion en Lowdin 1
! this is a change
!!   - <tt> 2013-10-03 </tt>: Jose Mauricio Rodas (jmrodasr@unal.edu.co)
!!        -# Rewrite the module as a program and adapts to Lowdin 2
!!   - <tt> 2014-08-26 </tt>: Jorge Charry (jacharrym@unal.edu.co)
!!        -# Write this program to calculate the transformed integrals in Lowdin2
!!           independently from MP2 program.
!! @warning This programs only works linked to lowdincore library,
!!          provided by LOWDIN quantum chemistry package
!!
program IntegralsTransformation
  use CONTROL_
  use MolecularSystem_
!  use IntegralManager_
  use IndexMap_
  use Matrix_
  use Exception_
  use Vector_
  use TransformIntegrals_
  use String_
!  use MPFunctions_
  implicit none

  character(50) :: job
  integer :: numberOfSpecies
  integer :: i, j
  integer :: specieID, otherSpecieID
  integer :: numberOfContractions
  integer :: numberOfContractionsOfOtherSpecie
  character(10) :: nameOfSpecies
  character(10) :: nameOfOtherSpecie
  type(Vector) :: eigenValues
  type(Vector) :: eigenValuesOfOtherSpecie
  type(Matrix) :: auxMatrix
  type(TransformIntegrals) :: repulsionTransformer
  type(Matrix) :: eigenVec
  type(Matrix) :: eigenVecOtherSpecie 
  character(50) :: wfnFile
  character(50) :: arguments(2)
  integer :: wfnUnit
  integer :: numberOfQuantumSpecies

  wfnFile = "lowdin.wfn"
  wfnUnit = 20

  job = ""  
  call get_command_argument(1,value=job)  
  job = trim(String_getUppercase(job))

  !!Start time
  call Stopwatch_constructor(lowdin_stopwatch)
  call Stopwatch_start(lowdin_stopwatch)

  !!Load CONTROL Parameters
  call MolecularSystem_loadFromFile( "LOWDIN.DAT" )

  !!Load the system in lowdin.sys format
  call MolecularSystem_loadFromFile( "LOWDIN.SYS" )

  call TransformIntegrals_constructor( repulsionTransformer )

  !!*******************************************************************************************
  !! Calculo de correcciones de segundo orden para particulas de la misma especie
  !!
  if ( .not.CONTROL_instance%OPTIMIZE ) then
     print *,""
     print *,"BEGIN FOUR-INDEX INTEGRALS TRANFORMATION:"
     print *,"========================================"
     print *,""
     print *,"--------------------------------------------------"
     print *,"    Algorithm Four-index integral tranformation"
     print *,"      Yamamoto, Shigeyoshi; Nagashima, Umpei. "
     print *,"  Computer Physics Communications, 2005, 166, 58-65"
     print *,"--------------------------------------------------"
     print *,""
  end if

   open(unit=wfnUnit, file=trim(wfnFile), status="old", form="unformatted") 
   rewind(wfnUnit)

  numberOfQuantumSpecies = MolecularSystem_getNumberOfQuantumSpecies()

  do i=1, numberOfQuantumSpecies

        nameOfSpecies = trim( MolecularSystem_getNameOfSpecie( i ) )

        if ( .not.CONTROL_instance%OPTIMIZE ) then
            write (6,"(T2,A)")"Integrals transformation for: "//trim(nameOfSpecies)
         end if

        numberOfContractions = MolecularSystem_getTotalNumberOfContractions(i)
         arguments(2) = MolecularSystem_getNameOfSpecie(i)

         arguments(1) = "COEFFICIENTS"

         eigenVec= Matrix_getFromFile(unit=wfnUnit, rows= int(numberOfContractions,4), &
              columns= int(numberOfContractions,4), binary=.true., arguments=arguments(1:2))
        
        arguments(1) = "ORBITALS"
         call Vector_getFromFile( elementsNum = numberOfContractions, &
              unit = wfnUnit, binary = .true., arguments = arguments(1:2), &
              output = eigenValues )     
         
         specieID = MolecularSystem_getSpecieID( nameOfSpecie=nameOfSpecies )
         numberOfContractions = MolecularSystem_getTotalNumberOfContractions( i )

        call TransformIntegrals_atomicToMolecularOfOneSpecie( repulsionTransformer, &
             eigenVec, auxMatrix, specieID, trim(nameOfSpecies) )

        !!*******************************************************************************************
        !! Calculo de correcion se segundo orden para interaccion entre particulas de especie diferente
        !!
        if ( numberOfQuantumSpecies > 1 ) then
                do j = i + 1 , numberOfQuantumSpecies

                        nameOfOtherSpecie= trim(  MolecularSystem_getNameOfSpecie( j ) )
                
                        if ( .not.CONTROL_instance%OPTIMIZE ) then
                           write (6,"(T2,A)") "Inter-species integrals transformation for: "//trim(nameOfSpecies)//"/"//trim(nameOfOtherSpecie)
                        end if

                        numberOfContractionsOfOtherSpecie = MolecularSystem_getTotalNumberOfContractions( j )

                        arguments(2) = trim(MolecularSystem_getNameOfSpecie(j))

                        arguments(1) = "COEFFICIENTS"
                        eigenVecOtherSpecie = &
                                Matrix_getFromFile(unit=wfnUnit, rows= int(numberOfContractionsOfOtherSpecie,4), &
                                columns= int(numberOfContractionsOfOtherSpecie,4), binary=.true., arguments=arguments(1:2))

                        arguments(1) = "ORBITALS"
                        call Vector_getFromFile( elementsNum = numberOfContractionsofOtherSpecie, &
                             unit = wfnUnit, binary = .true., arguments = arguments(1:2), &
                             output = eigenValuesOfOtherSpecie )     

                        call TransformIntegrals_atomicToMolecularOfTwoSpecies( repulsionTransformer, &
                             eigenVec, eigenVecOtherSpecie, &
                             auxMatrix, specieID, nameOfSpecies, otherSpecieID, nameOfOtherSpecie )

                end do
           end if

   end do

  !!stop time
  call Stopwatch_stop(lowdin_stopwatch)
  
  write(*, *) ""
  write(*,"(A,F10.3,A4)") "** TOTAL Enlapsed Time for integrals transformation : ", lowdin_stopwatch%enlapsetTime ," (s)"
  write(*, *) ""
  close(30)

close(wfnUnit)

end program IntegralsTransformation

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
module Rings_
  use MolecularSystem_
  use ParticleManager_
  use MMCommons_
  use RingFinder_
  use MatrixInteger_
  use Vector_
  use MMCommons_
  use Exception_
  implicit none

  type , public :: Rings

     integer :: numberOfRings
     integer, allocatable :: ringSize(:)
     integer, allocatable :: aromaticity(:) !! 1 == Aromatic ring, 0 == Non aromatic ring
     type(MatrixInteger), allocatable :: connectionMatrix(:)
     logical :: hasRings

  end type Rings

  public :: &
       Rings_constructor, &
       Rings_getAromaticity, &
       Rings_isAromaticCandidate, &
       Rings_getNumberOfPiBonds, &
       Rings_isNeighborAromaticRing

contains

  subroutine Rings_constructor(this)
    implicit none
    type(Rings), intent(in out) :: this
    integer :: numberOfEdges
    integer :: cyclomaticNumber
    type(MatrixInteger), allocatable :: edges(:)
    type(MatrixInteger) :: connectivityMatrix
    type(Vector) :: bonds
    type(MatrixInteger), allocatable :: ringsArray(:)
    integer :: numberOfCenterofOptimization
    integer :: i, j

    call MMCommons_constructor( MolecularSystem_instance )
    numberOfCenterofOptimization = ParticleManager_getNumberOfCentersOfOptimization()

    !!******************************************************************************
    !! Se calcula el cyclomatic number el cual es aquivalente al numero de anillos
    !! L. Matyska, J. Comp. Chem. 9(5), 455 (1988)
    !! si cyclomaticNumber = 1 no hay anillos 
    !!******************************************************************************
    numberOfEdges=size(MolecularSystem_instance%intCoordinates%distanceBondValue%values)
    cyclomaticNumber = numberOfEdges - numberOfCenterofOptimization + 2

    this%hasRings = .false.
    this%numberOfRings = 0

    if(cyclomaticNumber>=2) then
       this%hasRings = .true.
    end if

    if (this%hasRings) then
       call MMCommons_pruningGraph( MolecularSystem_instance, numberOfCenterofOptimization, edges, connectivityMatrix, bonds )
       call RingFinder_getRings( edges, connectivityMatrix, cyclomaticNumber, ringsArray )
       this%numberOfRings = size(ringsArray)
       
       allocate( this%connectionMatrix( this%numberOfRings ))
       allocate( this%ringSize( this%numberOfRings ) )

       do i=1,this%numberOfRings
          this%ringSize(i) = size(ringsArray(i)%values) - 1
          call MatrixInteger_constructor( this%connectionMatrix(i), 1, this%ringSize(i) )
          do j=1,this%ringSize(i)
             this%connectionMatrix(i)%values(1,j) = ringsArray(i)%values(1,j)
          end do
       end do
    
       call Rings_getAromaticity(this)

       !! Debug
       ! write(*,"(T20,A)") ""
       ! write(*,"(T20,A)") " RINGS INFORMATION: "
       ! write(*,"(T20,A)") "-----------------------------------------------------------------"
       ! write(*,"(T20,A,I)") "Number of Rings: ", this%numberOfRings
       ! do i=1, this%numberOfRings
       !    write(*,"(T20,A,<this%ringSize(i)>I)") "Ring Members: ", this%connectionMatrix(i)%values(1,:)
       ! end do
       ! write(*,"(T20,A,<this%numberOfRings>I)") "Ring Aromaticity: ", this%aromaticity(:)
       ! write(*,"(T20,A)") "-----------------------------------------------------------------"
       ! write(*,"(T20,A)") ""
    end if

  end subroutine Rings_constructor

  subroutine Rings_getAromaticity(this)
    implicit none
    type(Rings), intent(in out) :: this
    integer :: connectivity
    character(10), allocatable :: labelOfCenters(:)
    integer :: numberOfCenterofOptimization
    integer :: i, j, atom
    logical :: isAromaticCandidate
    real(8) :: SP2SP3AngleCutoff
    real(8) :: angleAverage
    real(8) :: numberOfPiElectrons, huckelNumber
    integer :: numberOfBonds
    integer :: numberOfPiBonds
    type(MatrixInteger) :: bondConnectionMatrix
    real(8), allocatable :: bondDistance(:)
    logical :: isExocyclic, isNOx
    

    numberOfBonds = size(MolecularSystem_instance%intCoordinates%distanceBondValue%values)
    call MatrixInteger_constructor( bondConnectionMatrix, numberOfBonds, 2 )
    allocate( bondDistance( numberOfBonds ) )

    do i=1,numberOfBonds
       do j=1,2
          bondConnectionMatrix%values(i,j) = MolecularSystem_instance%intCoordinates%connectionMatrixForBonds%values(i,j)
       end do
       bondDistance(i) = MolecularSystem_instance%intCoordinates%distanceBondValue%values(i) * AMSTRONG
    end do


    SP2SP3AngleCutoff = 115.00000000

    numberOfCenterofOptimization = ParticleManager_getNumberOfCentersOfOptimization()

    allocate( labelOfCenters( numberOfCenterofOptimization ) )
    labelOfCenters = ParticleManager_getLabelsOfCentersOfOptimization()

    allocate( this%aromaticity( this%numberOfRings ) )

    isAromaticCandidate = .true.
    isExocyclic = .false.
    isNOx = .false.

    do i=1,this%numberOfRings
       numberOfPiElectrons = 0.0
       isAromaticCandidate = Rings_isAromaticCandidate(this, i, labelOfCenters)
       if(isAromaticCandidate) then
          do j=1,this%ringSize(i)
             atom = this%connectionMatrix(i)%values(1,j)
             connectivity = MMCommons_getConnectivity( MolecularSystem_instance, atom )
             if(trim( labelOfCenters(atom) ) == "C" .and. connectivity == 3 ) then
                angleAverage = MMCommons_getAngleAverage( MolecularSystem_instance, atom )
                 if(angleAverage > SP2SP3AngleCutoff) then
                   numberOfPiElectrons = numberOfPiElectrons + 1
                end if
             else if(trim( labelOfCenters(atom) ) == "N" .and. connectivity == 3 ) then
                call Rings_getNumberOfPiBonds(this, atom, i, connectivity, numberOfBonds, &
                     bondConnectionMatrix, bondDistance, labelOfCenters, numberOfPiBonds, isExocyclic, isNOx)
                if(numberOfPiBonds < 1) then
                   numberOfPiElectrons = numberOfPiElectrons + 2
                else if(numberOfPiBonds == 1) then
                   if(isExocyclic) then
                      numberOfPiElectrons = numberOfPiElectrons + 0
                   else
                      numberOfPiElectrons = numberOfPiElectrons + 1
                   end if
                else if(numberOfPiBonds == 2) then
                   if(isNOx) then
                      numberOfPiElectrons = numberOfPiElectrons + 1
                   else
                      numberOfPiElectrons = numberOfPiElectrons + 0
                   end if
                end if
             else if(trim( labelOfCenters(atom) ) == "N" .and. connectivity == 2 ) then
                numberOfPiElectrons = numberOfPiElectrons + 1
             else if(trim( labelOfCenters(atom) ) == "O" .and. connectivity == 2 ) then
                numberOfPiElectrons = numberOfPiElectrons + 2
             else if(trim( labelOfCenters(atom) ) == "S" .and. connectivity == 2 ) then
                numberOfPiElectrons = numberOfPiElectrons + 2
             end if
          end do
       end if
       huckelNumber = (numberOfPiElectrons - 2.0)/4.0
       if(huckelNumber == 0.0 .or. huckelNumber == 1.0 .or. huckelNumber == 2.0 .or. huckelNumber == 3.0 .or. &
            huckelNumber == 4.0 .or. huckelNumber == 5.0 .or. huckelNumber == 6.0) then
          this%aromaticity(i) = 1
       else
          this%aromaticity(i) = 0
       end if
    end do

  end subroutine Rings_getAromaticity
  
  function Rings_isAromaticCandidate(this, ringNumber, labelOfCenters) result(output)
    implicit none
    type(Rings), intent(in out) :: this
    integer, intent(in) :: ringNumber
    character(10), allocatable, intent(in) :: labelOfCenters(:)
    integer :: i, atom, connectivity
    logical :: output

    output = .true.
    
    do i=1,this%ringSize(ringNumber)
       atom = this%connectionMatrix(ringNumber)%values(1,i)
       connectivity = MMCommons_getConnectivity( MolecularSystem_instance, atom )
       if(trim( labelOfCenters(atom) ) == "C" .and. connectivity >=4 ) then
          output = .false.
       end if
    end do

  end function Rings_isAromaticCandidate

  subroutine Rings_getNumberOfPiBonds(this, atom, ringNumber, connectivity, numberOfBonds, &
       bondConnectionMatrix, bondDistance, labelOfCenters, numberOfPiBonds, isExocyclic, isNOx)
    implicit none
    type(Rings), intent(in out) :: this
    integer, intent(in) :: atom
    integer, intent(in) :: ringNumber
    integer, intent(in) :: connectivity
    integer, intent(in) :: numberOfBonds
    type(MatrixInteger), intent(in) :: bondConnectionMatrix
    real(8), allocatable, intent(in) :: bondDistance(:)
    character(10), allocatable, intent(in) :: labelOfCenters(:)
    integer, intent(out) :: numberOfPiBonds
    logical, intent(out) :: isExocyclic
    logical, intent(out) :: isNOx
    integer :: i, j
    integer, allocatable :: neighbor(:), ringNeighbor(:)
    integer, allocatable :: bondRow(:)
    real(8) :: singleNBondCutoff, singleONBondCutoff, singleNNBondCutoff, singleSNBondCutoff
    integer :: numberOfSigma

    singleNBondCutoff = 1.380000
    singleONBondCutoff = 1.250000
    singleNNBondCutoff = 1.320000
    singleSNBondCutoff = 1.580000

    allocate( neighbor( connectivity ) )
    allocate( ringNeighbor( 2 ) )
    allocate( bondRow( connectivity ) )

    numberOfPiBonds = connectivity
    numberOfSigma = 0
    isExocyclic = .false.
    isNOx = .false.

    do i=1, this%ringSize(ringNumber)
       if( this%connectionMatrix(ringNumber)%values(1,i) == atom ) then
          if( i == 1 ) then
             ringNeighbor(1) = this%connectionMatrix(ringNumber)%values(1, this%ringSize(ringNumber))                
             ringNeighbor(2) = this%connectionMatrix(ringNumber)%values(1,2)
          else if( i == this%ringSize(ringNumber) ) then
             ringNeighbor(1) = this%connectionMatrix(ringNumber)%values(1, this%ringSize(ringNumber) - 1)
             ringNeighbor(2) = this%connectionMatrix(ringNumber)%values(1,1)
          else
             ringNeighbor(1) = this%connectionMatrix(ringNumber)%values(1,i-1)
             ringNeighbor(2) = this%connectionMatrix(ringNumber)%values(1,i+1)
          end if
       end if
    end do

    j = 1
    do i=1, numberOfBonds
       if(bondConnectionMatrix%values(i,1) == atom) then
          neighbor(j) = bondConnectionMatrix%values(i,2)
          bondRow(j) = i
          j = j + 1
       else if(bondConnectionMatrix%values(i,2) == atom) then
          neighbor(j) = bondConnectionMatrix%values(i,1)
          bondRow(j) = i
          j = j + 1
       end if
    end do

    
    do i=1, connectivity
       if(trim( labelOfCenters(neighbor(i)) ) == "H") then
          numberOfPiBonds = numberOfPiBonds - 1
       else if(trim( labelOfCenters(neighbor(i)) ) == "C") then
          j = bondRow(i)
          if(bondDistance( j ) > singleNBondCutoff) then
             numberOfPiBonds = numberOfPiBonds - 1
             if(ringNeighbor(1) == neighbor(i) .or. ringNeighbor(2) == neighbor(i)) then
                numberOfSigma = numberOfSigma + 1
             end if
          end if
       else if(trim( labelOfCenters(neighbor(i)) ) == "O") then
          j = bondRow(i)
          if(bondDistance( j ) > singleONBondCutoff ) then
             numberOfPiBonds = numberOfPiBonds - 1
             if(ringNeighbor(1) == neighbor(i) .or. ringNeighbor(2) == neighbor(i)) then
                numberOfSigma = numberOfSigma + 1
             end if
          end if
       else if(trim( labelOfCenters(neighbor(i)) ) == "N") then
          j = bondRow(i)
          if(bondDistance( j ) > singleNNBondCutoff ) then
             numberOfPiBonds = numberOfPiBonds - 1
             if(ringNeighbor(1) == neighbor(i) .or. ringNeighbor(2) == neighbor(i)) then
                numberOfSigma = numberOfSigma + 1
             end if
          end if
       else if(trim( labelOfCenters(neighbor(i)) ) == "S") then
          j = bondRow(i)
          if(bondDistance( j ) > singleSNBondCutoff ) then
             numberOfPiBonds = numberOfPiBonds - 1
             if(ringNeighbor(1) == neighbor(i) .or. ringNeighbor(2) == neighbor(i)) then
                numberOfSigma = numberOfSigma + 1
             end if             
          end if
       end if
    end do

    if(numberOfPiBonds == 1 .and. numberOfSigma == 2) then
       isExocyclic = .true.
    end if

    if(numberofPiBonds == 2) then
       do i=1, connectivity
          if(trim( labelOfCenters(neighbor(i)) ) == "O") then
             if( ringNeighbor(1) /= neighbor(i) .and. ringNeighbor(1) /= neighbor(i) ) then
                isNOx = .true.
             end if
          end if
       end do
    end if

  end subroutine Rings_getNumberOfPiBonds

  function Rings_isNeighborAromaticRing(this, atomA, atomB) result(output)
    implicit none
    type(Rings), intent(in) :: this
    integer, intent(in) :: atomA, atomB
    logical :: output
    integer :: i, j

    output = .false.

    do i=1,this%numberOfRings
       do j=1,this%ringSize(i)
          if(this%connectionMatrix(i)%values(1,j) == atomA) then
             if(this%aromaticity(i) == 1) then
                if(j == 1) then
                   if(atomB == this%connectionMatrix(i)%values(1, this%ringSize(i))) then
                      output = .true.
                   else if(atomB == this%connectionMatrix(i)%values(1,2)) then
                      output = .true.
                   end if
                else if(j == this%ringSize(i)) then
                   if(atomB == this%connectionMatrix(i)%values(1, this%ringSize(i) - 1)) then
                      output = .true.
                   else if(atomB == this%connectionMatrix(i)%values(1,1)) then
                      output = .true.
                   end if
                else
                   if(atomB == this%connectionMatrix(i)%values(1, j - 1)) then
                      output = .true.
                   else if(atomB == this%connectionMatrix(i)%values(1, j + 1)) then
                      output = .true.
                   end if
                end if
             end if
          end if
       end do
    end do

  end function Rings_isNeighborAromaticRing

end module Rings_

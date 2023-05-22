# LOWDIN 2 Quantum chemistry package #

This program has been developed under direction of:

* [Prof. A REYES' Lab](http://www.qcc.unal.edu.co). Universidad Nacional de Colombia.

* [Prof. R. FLORES' Lab](http://www.cucei.udg.mx/~robertof). Universidad de Guadalajara.


© All rights reserved, 2014.

Build status

![status](https://codeship.com/projects/20d722b0-8229-0133-0920-3ae4df758b2e/status?branch=master "Build status")

Welcome to LOWDIN Quantum Chemistry Package 2.0.

Installation notes.
=============

###Prerequisites: ###

* A standard FORTRAN compiler. gfortran and intel FORTRAN compiler have been tested.
* Lapack or MKL libraries.
* Arpack library.
* [LIBINT library version 1.1.5](http://sourceforge.net/projects/libint/files/v1-releases/). NOTE: After download LIBINT please compile with default options. If you want to compile with angular momentum higher than `f`	you should compile LIBINT properly and edit the file `src/ints/LibintInterface.f90` accordingly.

NOTE: If you have the libraries in your own path please be sure to export the LIBRARY_PATH environment variable. ie:

`export LIBRARY_PATH=$LIBRARY_PATH:[your library path]`

### Compile: ###

* run `./configure` in LOWDIN root directory. Be sure that you have permissions to write in the installation directory and have properly exported the `$PATH` environment.

* run `make`

### Install: ###

* run `make install`

### Uninstall ###

* run `make uninstall`

### Documentation ###

* run `make doc`

The `make doc` command produces both latex and html documentation using doxygen program. Be sure you have installed doxygen, for instance in a debian-based distribution run:

`# apt-get install doxygen graphviz`

To use latex documentation in doc/latex folder, run command:

`pdflatex refman.tex`

To visualize the html documentation use:

`<web browser> doc/html/index.html`

### Clean the project ###

* run `make clean` and then `make distclean`

### Further info: ###
efposadac@unal.edu.co

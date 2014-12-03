#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <cuda.h>

const int numberOfThreads = 256;
const double pi = 3.14159265358979323846;

__device__ float kroneckerDelta(int i, int j)
{
  double delta;

  delta = 1.0;
  if(i != j)
    delta = 0.0;

  return delta;
}

__device__ float errorFunction(int order, double tFunc)
{

  double tFuncsqrt;
  double errorF; 

  tFuncsqrt = sqrt(tFunc);

  if(round(tFunc) == 0.0)
    errorF = 1.0/(2*order + 1);
  else
    {
      switch(order)
	{
	case 0:
	  errorF = 0.5*erf(tFuncsqrt)*sqrt(pi/tFunc);
	  break;
	case 1:
	  errorF = 0.25*(-2*tFuncsqrt*exp(-tFunc) + sqrt(pi)*erf(tFuncsqrt))/(tFuncsqrt*tFunc);
	  break;
	case 2:
	  errorF = -0.125*(exp(-tFunc)*(6*tFuncsqrt + 4*tFuncsqrt*tFunc) - 3*sqrt(pi)*erf(tFuncsqrt))/(tFuncsqrt*tFunc*tFunc);
	  break;
	case 3:
	  errorF = -0.0625*(exp(-tFunc)*(30*tFuncsqrt + 20*tFunc*tFuncsqrt + 8*tFunc*tFunc*tFuncsqrt) - 15*sqrt(pi)*erf(tFuncsqrt))/(tFuncsqrt*tFunc*tFunc*tFunc);
	  break;
	case 4:
	  errorF = -0.03125*(exp(-tFunc)*(16*tFuncsqrt*tFunc*tFunc*tFunc + 56*tFunc*tFunc*tFuncsqrt + 140*tFunc*tFuncsqrt + 210*tFuncsqrt) - (105*sqrt(pi)*erf(tFuncsqrt)))/(tFuncsqrt*tFunc*tFunc*tFunc*tFunc);
	  break;
	}
    }

  return errorF;
}

__global__ void analyticInts(int N, 
			int *primIndices_d,
			int *contIndices_d,
			double *exponents_d,
			double *primNormalization_d,
			double *coefficients_d,
			int *contCounter_d,
			int *contLength_d,
			double *origin_d,
			int *angularMoments_d,
			double *integralValues_d,
			int control,
			int kernelIter)
{
  int threadIndex = threadIdx.x + threadIdx.y*blockDim.x;
  int blockIndex = blockIdx.x;
  int global1 = threadIndex + blockIndex*blockDim.x*blockDim.y;
  int global = global1 + kernelIter; 
  
  int aa, bb, rr, ss, ii, jj, kk, ll;
  int contractionID;
  double exponentII, exponentJJ, exponentKK, exponentLL;
  double coefficientsII, coefficientsJJ, coefficientsKK, coefficientsLL;
  double primNormII, primNormJJ, primNormKK, primNormLL;
  int exponentIterII, exponentIterJJ, exponentIterKK, exponentIterLL;
  double IIx, IIy, IIz, JJx, JJy, JJz, KKx, KKy, KKz, LLx, LLy, LLz;
  double preIntegral, normIntegral; 
  double etha;
  int lAA, lBB, lRR, lSS; // Angular moments of contractions
  int integralCase;

  double A, B, C, D, KIJ, KKL, rPx, rPy, rPz, rQx, rQy, rQz, rPQ, rIJ, rKL, tFunc, prefact;
  double FA, FB, FC, FD, FE;
  double rPQx, rPQy, rPQz;
  int alpha, beta, kappa, lambda, selectCart;
  double dij;

  if(global1< control)
    {
      // ID of unic integrals
      contractionID = primIndices_d[global*9];

      // Contraction Indices
      aa = contIndices_d[contractionID*4];
      bb = contIndices_d[contractionID*4+1];
      rr = contIndices_d[contractionID*4+2];
      ss = contIndices_d[contractionID*4+3];
      
      // Primitive indices
      ii = primIndices_d[global*9+1];
      jj = primIndices_d[global*9+2];
      kk = primIndices_d[global*9+3];
      ll = primIndices_d[global*9+4];
      
      // Label of cartesian
      alpha = primIndices_d[global*9+5];
      beta = primIndices_d[global*9+6];
      kappa = primIndices_d[global*9+7];
      lambda = primIndices_d[global*9+8];

      lAA = angularMoments_d[aa-1];
      lBB = angularMoments_d[bb-1];
      lRR = angularMoments_d[rr-1];
      lSS = angularMoments_d[ss-1];
      
      exponentIterII = contCounter_d[aa-1] + ii - 1;
      exponentIterJJ = contCounter_d[bb-1] + jj - 1;
      exponentIterKK = contCounter_d[rr-1] + kk - 1;
      exponentIterLL = contCounter_d[ss-1] + ll - 1;

      exponentII = exponents_d[exponentIterII];
      exponentJJ = exponents_d[exponentIterJJ];
      exponentKK = exponents_d[exponentIterKK];
      exponentLL = exponents_d[exponentIterLL];

      coefficientsII = coefficients_d[exponentIterII];
      coefficientsJJ = coefficients_d[exponentIterJJ];
      coefficientsKK = coefficients_d[exponentIterKK];
      coefficientsLL = coefficients_d[exponentIterLL];

      primNormII = primNormalization_d[exponentIterII];
      primNormJJ = primNormalization_d[exponentIterJJ];
      primNormKK = primNormalization_d[exponentIterKK];
      primNormLL = primNormalization_d[exponentIterLL];

      IIx = origin_d[(aa*3)-3];
      IIy = origin_d[(aa*3)-2];
      IIz = origin_d[(aa*3)-1];
      JJx = origin_d[(bb*3)-3];
      JJy = origin_d[(bb*3)-2];
      JJz = origin_d[(bb*3)-1];
      KKx = origin_d[(rr*3)-3];
      KKy = origin_d[(rr*3)-2];
      KKz = origin_d[(rr*3)-1];
      LLx = origin_d[(ss*3)-3];
      LLy = origin_d[(ss*3)-2];
      LLz = origin_d[(ss*3)-1];
    
      A = exponentII + exponentJJ;
      B = exponentKK + exponentLL;
      C = exponentII*exponentJJ;
      D = exponentKK*exponentLL;

      etha = (A*B)/(A+B);

      rIJ = (IIx-JJx)*(IIx-JJx) + (IIy-JJy)*(IIy-JJy) + (IIz-JJz)*(IIz-JJz);
      rKL = (KKx-LLx)*(KKx-LLx) + (KKy-LLy)*(KKy-LLy) + (KKz-LLz)*(KKz-LLz);

      KIJ = exp(-(C/A)*rIJ);
      KKL = exp(-(D/B)*rKL);

      prefact = sqrt(etha/pi)*sqrt(pi/A)*(pi/A)*sqrt(pi/B)*(pi/B)*KIJ*KKL;
      // if(aa==1 && bb==1 && rr==1 && ss==2)
      // 	printf("etha: %f KIJ: %f KKL: %f prefact: %f %f %f %f\n", etha, KIJ, KKL, prefact, D, B, rKL);
      
      rPx =(exponentII*IIx+exponentJJ*JJx)/A;
      rPy =(exponentII*IIy+exponentJJ*JJy)/A;
      rPz =(exponentII*IIz+exponentJJ*JJz)/A;
      rQx = (exponentKK*KKx+exponentLL*LLx)/B;
      rQy = (exponentKK*KKy+exponentLL*LLy)/B;
      rQz = (exponentKK*KKz+exponentLL*LLz)/B;
      
      rPQx = (rPx*A + rQx*B)/(A+B);
      rPQy = (rPy*A + rQy*B)/(A+B);
      rPQz = (rPz*A + rQz*B)/(A+B);

      rPQ = (rPx-rQx)*(rPx-rQx) + (rPy-rQy)*(rPy-rQy) + (rPz-rQz)*(rPz-rQz);

      tFunc = 0.0;
      tFunc = etha*rPQ;

      FA = 0.0;
      FB = 0.0;
      FC = 0.0;
      FD = 0.0;
      FE = 0.0;
      
      integralCase = 64*lAA + 16*lBB + 4*lRR + lSS;

      switch(integralCase)
	{
	case 0: // Integral (s,s|s,s)
	  FA = errorFunction(0, tFunc);
	  preIntegral = 2*FA*prefact;
	  break;
	case 64:
	  FA = errorFunction(0, tFunc);
	  FB = errorFunction(1, tFunc);
	  switch(alpha)
	    {
	    case 1: // Integral (px,s|s,s)
	      preIntegral = 2*(FB*(rPQx-rPx)+FA*(rPx-IIx))*prefact;
	      break;
	    case 2: // Integral (py,s|s,s)
	      preIntegral = 2*(FB*(rPQy-rPy)+FA*(rPy-IIy))*prefact;
	      break;
	    case 3: // Integral (pz,s|s,s)
	      preIntegral = 2*(FB*(rPQz-rPz)+FA*(rPz-IIz))*prefact;
	      break;
	    }
	  break;
	case 68:
	  FA = errorFunction(0, tFunc);
	  FB = errorFunction(1, tFunc);
	  FC = errorFunction(2, tFunc);
	  selectCart = 64*alpha + 4*kappa;
	  dij = kroneckerDelta(alpha, kappa);
	  switch(selectCart)
	    {
	    case 68: // Integral (px,s|px,s)
	      preIntegral = prefact*((FB*dij)/(B+A) + 2*(rQx-KKx)*(FB*(rPQx-rPx) + FA*(rPx-IIx)) + 2*(rPQx-rQx)*(FC*(rPQx-rPx) + FB*(rPx-IIx)));
	      break;
	    case 72: // Integral (px,s|py,s)
	      preIntegral = prefact*((FB*dij)/(B+A) + 2*(rQy-KKy)*(FB*(rPQx-rPx) + FA*(rPx-IIx)) + 2*(rPQy-rQy)*(FC*(rPQx-rPx) + FB*(rPx-IIx)));
	      break;
	    case 76: // Integral (px,s|pz,s)
	      preIntegral = prefact*((FB*dij)/(B+A) + 2*(rQz-KKz)*(FB*(rPQx-rPx) + FA*(rPx-IIx)) + 2*(rPQz-rQz)*(FC*(rPQx-rPx) + FB*(rPx-IIx)));
	      break;
	    case 136: // Integral (py,s|py,s)
	      preIntegral = prefact*((FB*dij)/(B+A) + 2*(rQy-KKy)*(FB*(rPQy-rPy) + FA*(rPy-IIy)) + 2*(rPQy-rQy)*(FC*(rPQy-rPy) + FB*(rPy-IIy)));
	      break;
	    case 140: // Integral (py,s|pz,s)
	      preIntegral = prefact*((FB*dij)/(B+A) + 2*(rQz-KKz)*(FB*(rPQy-rPy) + FA*(rPy-IIy)) + 2*(rPQz-rQz)*(FC*(rPQy-rPy) + FB*(rPy-IIy)));
	      break;
	    case 204: // Integral (pz,s|pz,s)
	      preIntegral = prefact*((FB*dij)/(B+A) + 2*(rQz-KKz)*(FB*(rPQz-rPz) + FA*(rPz-IIz)) + 2*(rPQz-rQz)*(FC*(rPQz-rPz) + FB*(rPz-IIz)));
	      break;
	    }
	  break;
	case 80:
	  FA = errorFunction(0, tFunc);
	  FB = errorFunction(1, tFunc);
	  FC = errorFunction(2, tFunc);
	  selectCart = 64*alpha + 16*beta;
	  dij = kroneckerDelta(alpha, beta);
	  switch(selectCart)
	    {
	    case 80: // Integral (px,px|s,s)
	      preIntegral = prefact*(((A*FA-etha*FB)*dij)/(A*A) + 2*(FC*(rPQx-rPx) + FB*(rPx-IIx))*(rPQx-rPx) + 2*(FB*(rPQx-rPx) + FA*(rPx-IIx))*(rPx-JJx));
	      break;
	    case 96: // Integral (px,py|s,s)
	      preIntegral = prefact*(((A*FA-etha*FB)*dij)/(A*A) + 2*(FC*(rPQx-rPx) + FB*(rPx-IIx))*(rPQy-rPy) + 2*(FB*(rPQx-rPx) + FA*(rPx-IIx))*(rPy-JJy));
	      break;
	    case 112: // Integral (px,pz|s,s)
	      preIntegral = prefact*(((A*FA-etha*FB)*dij)/(A*A) + 2*(FC*(rPQx-rPx) + FB*(rPx-IIx))*(rPQz-rPz) + 2*(FB*(rPQx-rPx) + FA*(rPx-IIx))*(rPz-JJz));
	      break;
	    case 160: // Integral (py,py|s,s)
	      preIntegral = prefact*(((A*FA-etha*FB)*dij)/(A*A) + 2*(FC*(rPQy-rPy) + FB*(rPy-IIy))*(rPQy-rPy) + 2*(FB*(rPQy-rPy) + FA*(rPy-IIy))*(rPy-JJy));
	      break;
	    case 176: // Integral (py,pz|s,s)
	      preIntegral = prefact*(((A*FA-etha*FB)*dij)/(A*A) + 2*(FC*(rPQy-rPy) + FB*(rPy-IIy))*(rPQz-rPz) + 2*(FB*(rPQy-rPy) + FA*(rPy-IIy))*(rPz-JJz));
	      break;
	    case 240: // Integral (pz,pz|s,s)
	      preIntegral = prefact*(((A*FA-etha*FB)*dij)/(A*A) + 2*(FC*(rPQz-rPz) + FB*(rPz-IIz))*(rPQz-rPz) + 2*(FB*(rPQz-rPz) + FA*(rPz-IIz))*(rPz-JJz));
	      break;
	    }
	  break;
	}
      // if(aa == 1 && bb == 1 && rr == 1 && ss == 2)
      // 	{
      // 	  printf("Sin Norm:  %f %f | %f %f\n",
      // 		 preIntegral, prefact, FA, rKL);
      // 	}
      normIntegral = primNormII*primNormJJ*primNormKK*primNormLL*preIntegral;
      integralValues_d[global1] = coefficientsII*coefficientsJJ*coefficientsKK*coefficientsLL*normIntegral;
    }
}

extern "C" void cuda_int_intraspecies_(int *numberOfContractions,
				       int *totalContIntegrals,
				       int *totalPrimitives,
                                       int *maxNumCartesianOrbital,
				       int *primNormalizationSize,
                                       int *contractionId,
                                       int *contractionLength,
                                       int *contractionAngularMoment,
                                       int *contractionNumCartesianOrbital,
                                       int *contractionOwner,
                                       double *contractionOrigin,
                                       double *contractionOrbitalExponents,
                                       double *contractionCoefficients,
                                       double *contractionContNormalization,
                                       double *contractionPrimNormalization,
				       double *contractionIntegrals,
				       int *contractionIndices, 
				       int *primitiveIndices,
				       int *numberOfPPUC,
				       int *labelsOfContractions)
{
  int N;
  double *integralValues, *integralValues_d;
  int a, b, r, s;
  int i,j;
  int m;
  int *contLength;
  int totalPrim;
  int contractionsMem, unicintegrals, unicintegralsMem, exponentSize;
  int *contIndices, *primIndices, *contCounter;
  double *exponents, *primNormalization, *coefficients, *origin, *contNormalization, *contractedIntegrals, *integralValuesTotal;
  int *angularMoments;
  int *numCartesianOrbitals, *labelsForContractions;
  int *auxNumberOfPPUC, contractionsMemDoub, unicintegralsMemDoub;
  int auxCounter, originSize;

  //Cuda Arrays
  int *contIndices_d, *primIndices_d, *contLength_d, *contCounter_d, *angularMoments_d;
  double *exponents_d, *primNormalization_d, *coefficients_d, *origin_d;

  // unicintegrals = ((*numberOfContractions*(*numberOfContractions+1)/2)+1)*(*numberOfContractions*(*numberOfContractions+1)/2)/2;
  unicintegrals = *totalContIntegrals;
  totalPrim = *totalPrimitives;

  //////////////////////////////////////////////////////////////////////
  /// Memory size
  contractionsMem = *numberOfContractions*sizeof(int);
  contractionsMemDoub = *numberOfContractions*sizeof(double);
  unicintegralsMem = unicintegrals*sizeof(int);
  unicintegralsMemDoub = unicintegrals*sizeof(double);
  exponentSize = *primNormalizationSize*sizeof(double);
  originSize = *numberOfContractions*3*sizeof(double);
  //////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////
  /// Malloc
  //contLength = Contraction size
  contLength = (int *)malloc(contractionsMem);
  // Counter for contractions
  contCounter = (int *)malloc(contractionsMem);
  //numberOfPPC = Number of Primitives per Unic Integral Contraction
  auxNumberOfPPUC = (int *)malloc(3*unicintegralsMem);
  //Unic Integral Contraction Indices
  contIndices = (int *)malloc(4*unicintegralsMem); 
  //Exponents of contractions
  exponents = (double *)malloc(exponentSize);
  //Primitive normalization constants
  primNormalization = (double *)malloc(exponentSize);
  //Coefficients of contractions
  coefficients = (double *)malloc(exponentSize);
  // Origins of contractions
  origin = (double *)malloc(originSize);
  // Contracted Integrals
  contractedIntegrals = (double *)malloc(unicintegralsMemDoub);
  // Normalization constants of contractions
  contNormalization = (double *)malloc(contractionsMemDoub);
  // Angular moments of contractions
  angularMoments = (int *)malloc(contractionsMem);
  // Number of cartesian orbitals
  numCartesianOrbitals = (int *)malloc(contractionsMem);
  // Labels of cartesian orbitals
  labelsForContractions = (int *)malloc(contractionsMem);
  //////////////////////////////////////////////////////////////////////

  auxCounter = 0;
  for(i=0; i<*numberOfContractions;i++)
    {
      contNormalization[i] = *(contractionContNormalization+i);
      angularMoments[i] = *(contractionAngularMoment+i);
      numCartesianOrbitals[i] = *(contractionNumCartesianOrbital+i);
      labelsForContractions[i] = *(labelsOfContractions+i);
      // printf("Angular moments: %d\n", angularMoments[i]);
      for(j=0; j<3; j++)
	{
	  origin[j+i*3] = *(contractionOrigin+(j+i*3));
             printf("Origin from inter %f \n",*(contractionOrigin+(j+i*3)), origin[j+i*3]);
	}
      contLength[i] = *(contractionLength+i);
      contCounter[i] = auxCounter; 
      // printf("Contraction length: %d %d\n", contLength[i], contCounter[i]);
      printf("Origins: (%f, %f, %f)\n", origin[i*3], origin[i*3+1], origin[i*3+2]);
      auxCounter += contLength[i];
    }

  // printf("Exponents, coefficients and Primitive Normalization constants:\n");
  for(i=0; i<*primNormalizationSize;i++)
      {
	exponents[i] = *(contractionOrbitalExponents+i);
	primNormalization[i] = *(contractionPrimNormalization+i);
	coefficients[i] = *(contractionCoefficients+i);
	// printf(" (%d) %f %f %f\n", i, exponents[i], coefficients[i], primNormalization[i]);
      }

  m=0;
  for( i=0; i<unicintegrals; i++ )
    {
      contIndices[i*4] = *(contractionIndices+(i*4));
      contIndices[i*4+1] = *(contractionIndices+(i*4+1));
      contIndices[i*4+2] = *(contractionIndices+(i*4+2));
      contIndices[i*4+3] = *(contractionIndices+(i*4+3));
      auxNumberOfPPUC[i*3] = *(numberOfPPUC+(i*3));
      auxNumberOfPPUC[i*3+1] = *(numberOfPPUC+(i*3+1));
      auxNumberOfPPUC[i*3+2] = *(numberOfPPUC+(i*3+2));
      /* printf("Contraction num: %d (%d,%d|%d,%d)\n", i, contIndices[i*4], contIndices[i*4+1], contIndices[i*4+2], contIndices[i*4+3]); */
    }

  primIndices = (int *)malloc(totalPrim*9*sizeof(int));
  for( i=0; i<totalPrim; i++)
    {
      primIndices[i*9] = *(primitiveIndices+(i*9));
      primIndices[i*9+1] = *(primitiveIndices+(i*9+1));
      primIndices[i*9+2] = *(primitiveIndices+(i*9+2));
      primIndices[i*9+3] = *(primitiveIndices+(i*9+3));
      primIndices[i*9+4] = *(primitiveIndices+(i*9+4));
      primIndices[i*9+5] = *(primitiveIndices+(i*9+5));
      primIndices[i*9+6] = *(primitiveIndices+(i*9+6));
      primIndices[i*9+7] = *(primitiveIndices+(i*9+7));
      primIndices[i*9+8] = *(primitiveIndices+(i*9+8));
    }

  N=totalPrim;	  
  integralValuesTotal = (double *)malloc(N*sizeof(double));
  ////////////////////////////////////////////////////////////////////
  /// Total threads in GPUs
  // printf("     *** GPU Especifications ***\n");
  int gpu, count;
  cudaDeviceProp prop;
  cudaGetDeviceCount(&count);
  int totalThreads=0;
  for (gpu = 0; gpu < count; gpu++) {
    cudaGetDeviceProperties(&prop,gpu);
    totalThreads+=prop.multiProcessorCount*prop.maxThreadsPerMultiProcessor;
  }
  ////////////////////////////////////////////////////////////////////   
  int numberOfBlocks = totalThreads/numberOfThreads;
  dim3 blockSize(16,16,1);
  dim3 gridSize(numberOfBlocks,1,1);

  ////////////////////////////////////////////////////////////////////////////
  /// CUDA Malloc
  cudaMalloc((void **)&primIndices_d, totalPrim*9*sizeof(int));
  cudaMalloc((void **)&contIndices_d, 4*unicintegralsMem);
  cudaMalloc((void **)&exponents_d, exponentSize);
  cudaMalloc((void **)&primNormalization_d, exponentSize);
  cudaMalloc((void **)&coefficients_d, exponentSize);
  cudaMalloc((void **)&contCounter_d, contractionsMem);
  cudaMalloc((void **)&angularMoments_d, contractionsMem);
  cudaMalloc((void **)&contLength_d, contractionsMem);
  cudaMalloc((void **)&origin_d, originSize);
  ///////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////
  ///CUDA copy
  cudaMemcpy(primIndices_d, primIndices, totalPrim*9*sizeof(int), cudaMemcpyHostToDevice);
  cudaMemcpy(contIndices_d, contIndices, 4*unicintegralsMem, cudaMemcpyHostToDevice);
  cudaMemcpy(exponents_d, exponents, exponentSize, cudaMemcpyHostToDevice);
  cudaMemcpy(primNormalization_d, primNormalization, exponentSize, cudaMemcpyHostToDevice);
  cudaMemcpy(coefficients_d, coefficients, exponentSize, cudaMemcpyHostToDevice);
  cudaMemcpy(contCounter_d, contCounter, contractionsMem, cudaMemcpyHostToDevice);
  cudaMemcpy(angularMoments_d, angularMoments, contractionsMem, cudaMemcpyHostToDevice);
  cudaMemcpy(contLength_d, contLength, contractionsMem, cudaMemcpyHostToDevice);
  cudaMemcpy(origin_d, origin, originSize, cudaMemcpyHostToDevice);
  //////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////
  ///Number of Calls to kernel

  int numberCallkernel = 0;
  
  i=0;
  int kernelIter = 0;
  int control2=0;
  while(control2<=totalPrim-1)
    {
      int control = 0;
      kernelIter = control2;
      while(control+auxNumberOfPPUC[i*3]<=totalThreads && i < unicintegrals)
	{
	  control += auxNumberOfPPUC[i*3];
          control2 += auxNumberOfPPUC[i*3];
	  i++;
	  // printf("Control: %d %d\n",i, control);
	}
      numberCallkernel++;
      integralValues = (double *)malloc(control*sizeof(double));
      cudaMalloc((void **)&integralValues_d, control*sizeof(double));

      // printf("Control2: %d %d\n", numberCallkernel, control2);

           // printf("Kernel Call Number: %d\n", numberCallkernel );
      analyticInts<<<gridSize,blockSize>>>(N, primIndices_d, contIndices_d, exponents_d, primNormalization_d, coefficients_d, contCounter_d, contLength_d, origin_d, angularMoments_d, integralValues_d, control, kernelIter);

      cudaMemcpy(integralValues, integralValues_d, control*sizeof(double),cudaMemcpyDeviceToHost);

       for(j=kernelIter;j<control2;j++)
	{
	  integralValuesTotal[j] = integralValues[j-kernelIter];    
	  // if(numberCallkernel==3)
	     // printf("Integral post Kernel: %d, %d -> %f\n", j, j-kernelIter, integralValuesTotal[j]);
	}

      cudaFree(integralValues_d);
      free(integralValues);
    }

  m=0;
  // printf("Unic Integrals Cuda:%d\n", unicintegrals);
  for(i=0; i<unicintegrals;i++)
    {
      contractedIntegrals[i] = 0.0;
      a = contIndices[i*4];
      b = contIndices[i*4+1];
      r = contIndices[i*4+2];
      s = contIndices[i*4+3];
      for(j=0; j<auxNumberOfPPUC[i*3];j++)
	{
	  contractedIntegrals[i] += contNormalization[a-1]*contNormalization[b-1]*contNormalization[r-1]*contNormalization[s-1]*integralValuesTotal[m];
	  *(contractionIntegrals+i) = contractedIntegrals[i];
	  m++;
	}
      // printf("%d %f %f %f %f\n", i, contNormalization[a],contNormalization[b],contNormalization[r],contNormalization[s]);
      printf("Contraida numero: %3d (%d,%d|%d,%d) | %15.12f \n", i,a,b,r,s,contractedIntegrals[i]);
    }

  cudaFree(primIndices_d);
  cudaFree(contIndices_d);
  cudaFree(exponents_d);
  cudaFree(primNormalization_d);
  cudaFree(coefficients_d);
  cudaFree(contCounter_d);
  cudaFree(contLength_d);
  cudaFree(origin_d);
  free(integralValuesTotal);
  free(contLength);
  free(contCounter);
  free(auxNumberOfPPUC);
  free(contIndices);
  free(exponents);
  free(primNormalization);
  free(coefficients);
  free(origin);
  free(contractedIntegrals);
  free(contNormalization);

  return;
}

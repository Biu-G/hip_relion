#ifndef ACC_SETTINGS_H_
#define ACC_SETTINGS_H_

#include "src/macros.h"

#define cudaStreamPerThread 0

#ifdef ACC_DOUBLE_PRECISION
	#define XFLOAT double
	#ifndef CUDA
		typedef struct{ XFLOAT x; XFLOAT y;} double2;
	#endif
	#define ACCCOMPLEX double2
#else
	#define XFLOAT float
	#ifndef CUDA
		typedef struct{ XFLOAT x; XFLOAT y;} float2;
	#endif
	#define ACCCOMPLEX float2
#endif
#ifdef ALTCPU
	#ifndef CUDA
		typedef float hipStream_t;
		typedef double CudaCustomAllocator;
		#define cudaStreamPerThread 0
	#endif
#endif

#endif /* ACC_SETTINGS_H_ */

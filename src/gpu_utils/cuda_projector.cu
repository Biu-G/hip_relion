#include "src/gpu_utils/cuda_projector.h"
#include <signal.h>


bool CudaProjector::setMdlDim(
		int xdim, int ydim, int zdim,
		int inity, int initz,
		int maxr, int paddingFactor)
{
	if(zdim == 1) zdim = 0;

	if (xdim == mdlX &&
		ydim == mdlY &&
		zdim == mdlZ &&
		inity == mdlInitY &&
		initz == mdlInitZ &&
		maxr == mdlMaxR &&
		paddingFactor == padding_factor)
		return false;

	clear();

	mdlX = xdim;
	mdlY = ydim;
	mdlZ = zdim;
	if(zdim == 0)
		mdlXYZ = xdim*ydim;
	else
		mdlXYZ = xdim*ydim*zdim;
	mdlInitY = inity;
	mdlInitZ = initz;
	mdlMaxR = maxr;
	padding_factor = paddingFactor;

#ifndef CUDA_NO_TEXTURES
#if(COMPLEXTEXTURE)
	mdlComplex = new hipTextureObject_t();

	// create channel to describe data type (bits,bits,bits,bits,type)
	hipChannelFormatDesc desc;

	desc = hipCreateChannelDesc(32, 32, 0, 0, hipChannelFormatKindFloat);

	struct hipResourceDesc resDesc_complex;
	struct hipTextureDesc  texDesc;
	// -- Zero all data in objects handlers
	memset(&resDesc_complex, 0, sizeof(hipResourceDesc));
	memset(&texDesc, 0, sizeof(hipTextureDesc));

	if(mdlZ!=0)  // 3D model
	{
		texArrayComplex = new hipArray_t();

		// -- make extents for automatic pitch:ing (aligment) of allocated 3D arrays
		hipExtent volumeSize = make_hipExtent(mdlX, mdlY, mdlZ);

		// -- Allocate and copy data using very celver CUDA memcpy-functions
		HANDLE_ERROR(hipMalloc3DArray(texArrayComplex, &desc, volumeSize));

		// -- Descriptors of the channel(s) in the texture(s)
		resDesc_complex.res.array.array = *texArrayComplex;
		resDesc_complex.resType = hipResourceTypeArray;
	}
	else // 2D model
	{
		HANDLE_ERROR(hipMallocPitch(&texArrayComplex2D, &pitch2D, sizeof(CUDACOMPLEX)*mdlX,mdlY));

		// -- Descriptors of the channel(s) in the texture(s)
		resDesc_complex.resType = hipResourceTypePitch2D;
		resDesc_complex.res.pitch2D.devPtr = texArrayComplex2D;
		resDesc_complex.res.pitch2D.pitchInBytes =  pitch2D;
		resDesc_complex.res.pitch2D.width = mdlX;
		resDesc_complex.res.pitch2D.height = mdlY;
		resDesc_complex.res.pitch2D.desc = desc;
	}

	// -- Decriptors of the texture(s) and methods used for reading it(them) --
	texDesc.filterMode       = hipFilterModeLinear;
	texDesc.readMode         = hipReadModeElementType;
	texDesc.normalizedCoords = false;

	for(int n=0; n<3; n++)
		texDesc.addressMode[n]=hipAddressModeClamp;

	// -- Create texture object(s)
	HANDLE_ERROR(hipCreateTextureObject(mdlComplex, &resDesc_complex, &texDesc, NULL));

#else

	mdlReal = new hipTextureObject_t();
	mdlImag = new hipTextureObject_t();

	// create channel to describe data type (bits,bits,bits,bits,type)
	hipChannelFormatDesc desc;

	desc = hipCreateChannelDesc(32, 0, 0, 0, hipChannelFormatKindFloat);

	struct hipResourceDesc resDesc_real, resDesc_imag;
	struct hipTextureDesc  texDesc;
	// -- Zero all data in objects handlers
	memset(&resDesc_real, 0, sizeof(hipResourceDesc));
	memset(&resDesc_imag, 0, sizeof(hipResourceDesc));
	memset(&texDesc, 0, sizeof(hipTextureDesc));

	if(mdlZ!=0)  // 3D model
	{
		texArrayReal = new hipArray_t();
		texArrayImag = new hipArray_t();

		// -- make extents for automatic pitch:ing (aligment) of allocated 3D arrays
		hipExtent volumeSize = make_hipExtent(mdlX, mdlY, mdlZ);


		// -- Allocate and copy data using very clever CUDA memcpy-functions
		HANDLE_ERROR(hipMalloc3DArray(texArrayReal, &desc, volumeSize));
		HANDLE_ERROR(hipMalloc3DArray(texArrayImag, &desc, volumeSize));

		// -- Descriptors of the channel(s) in the texture(s)
		resDesc_real.res.array.array = *texArrayReal;
		resDesc_imag.res.array.array = *texArrayImag;
		resDesc_real.resType = hipResourceTypeArray;
		resDesc_imag.resType = hipResourceTypeArray;
	}
	else // 2D model
	{
		HANDLE_ERROR(hipMallocPitch(&texArrayReal2D, &pitch2D, sizeof(XFLOAT)*mdlX,mdlY));
		HANDLE_ERROR(hipMallocPitch(&texArrayImag2D, &pitch2D, sizeof(XFLOAT)*mdlX,mdlY));

		// -- Descriptors of the channel(s) in the texture(s)
		resDesc_real.resType = hipResourceTypePitch2D;
		resDesc_real.res.pitch2D.devPtr = texArrayReal2D;
		resDesc_real.res.pitch2D.pitchInBytes =  pitch2D;
		resDesc_real.res.pitch2D.width = mdlX;
		resDesc_real.res.pitch2D.height = mdlY;
		resDesc_real.res.pitch2D.desc = desc;
		// -------------------------------------------------
		resDesc_imag.resType = hipResourceTypePitch2D;
		resDesc_imag.res.pitch2D.devPtr = texArrayImag2D;
		resDesc_imag.res.pitch2D.pitchInBytes =  pitch2D;
		resDesc_imag.res.pitch2D.width = mdlX;
		resDesc_imag.res.pitch2D.height = mdlY;
		resDesc_imag.res.pitch2D.desc = desc;
	}

	// -- Decriptors of the texture(s) and methods used for reading it(them) --
	texDesc.filterMode       = hipFilterModeLinear;
	texDesc.readMode         = hipReadModeElementType;
	texDesc.normalizedCoords = false;

	for(int n=0; n<3; n++)
		texDesc.addressMode[n]=hipAddressModeClamp;

	// -- Create texture object(s)
	HANDLE_ERROR(hipCreateTextureObject(mdlReal, &resDesc_real, &texDesc, NULL));
	HANDLE_ERROR(hipCreateTextureObject(mdlImag, &resDesc_imag, &texDesc, NULL));
#endif
#else
	DEBUG_HANDLE_ERROR(hipMalloc( (void**) &mdlReal, mdlXYZ * sizeof(XFLOAT)));
	DEBUG_HANDLE_ERROR(hipMalloc( (void**) &mdlImag, mdlXYZ * sizeof(XFLOAT)));
#endif
	return true;
}

#if(!COMPLEXTEXTURE)
void CudaProjector::initMdl(XFLOAT *real, XFLOAT *imag)
{
#ifdef CUDA_DEBUG
	if (mdlXYZ == 0)
	{
        printf("DEBUG_ERROR: Model dimensions must be set with setMdlDim before call to setMdlData.");
		CRITICAL(ERR_MDLDIM);
	}
	if (mdlReal != 0)
	{
        printf("DEBUG_ERROR: Duplicated call to setMdlData.");
		CRITICAL(ERR_MDLSET);
	}
#endif

#ifndef CUDA_NO_TEXTURES
	if(mdlZ!=0)  // 3D model
	{
		// -- make extents for automatic pitching (aligment) of allocated 3D arrays
		hipMemcpy3DParms copyParams = {0};
		copyParams.extent = make_hipExtent(mdlX, mdlY, mdlZ);
		copyParams.kind   = hipMemcpyHostToDevice;

		// -- Copy data
		copyParams.dstArray = *texArrayReal;
		copyParams.srcPtr   = make_hipPitchedPtr(real, mdlX * sizeof(XFLOAT), mdlY, mdlZ);
		DEBUG_HANDLE_ERROR(hipMemcpy3D(&copyParams));
		copyParams.dstArray = *texArrayImag;
		copyParams.srcPtr   = make_hipPitchedPtr(imag, mdlX * sizeof(XFLOAT), mdlY, mdlZ);
		DEBUG_HANDLE_ERROR(hipMemcpy3D(&copyParams));
	}
	else // 2D model
	{
		DEBUG_HANDLE_ERROR(hipMemcpy2D(texArrayReal2D, pitch2D, real, sizeof(XFLOAT) * mdlX, sizeof(XFLOAT) * mdlX, mdlY, hipMemcpyHostToDevice));
		DEBUG_HANDLE_ERROR(hipMemcpy2D(texArrayImag2D, pitch2D, imag, sizeof(XFLOAT) * mdlX, sizeof(XFLOAT) * mdlX, mdlY, hipMemcpyHostToDevice));
	}
#else
	DEBUG_HANDLE_ERROR(hipMemcpy( mdlReal, real, mdlXYZ * sizeof(XFLOAT), hipMemcpyHostToDevice));
	DEBUG_HANDLE_ERROR(hipMemcpy( mdlImag, imag, mdlXYZ * sizeof(XFLOAT), hipMemcpyHostToDevice));
#endif

}
#endif


void CudaProjector::initMdl(Complex *data)
{
#if(COMPLEXTEXTURE)
	if(mdlZ!=0)  // 3D model
	{
		// -- make extents for automatic pitching (aligment) of allocated 3D arrays
		hipMemcpy3DParms copyParams = {0};
		copyParams.extent = make_hipExtent(mdlX, mdlY, mdlZ);
		copyParams.kind   = hipMemcpyHostToDevice;

		// -- Copy data
		copyParams.dstArray = *texArrayComplex;
		copyParams.srcPtr   = make_hipPitchedPtr(data, mdlX * sizeof(CUDACOMPLEX), mdlY, mdlZ);
		DEBUG_HANDLE_ERROR(hipMemcpy3D(&copyParams));
	}
	else // 2D model
	{
		DEBUG_HANDLE_ERROR(hipMemcpy2D(texArrayComplex2D, pitch2D, data, sizeof(CUDACOMPLEX) * mdlX, sizeof(CUDACOMPLEX) * mdlX, mdlY, hipMemcpyHostToDevice));
	}
#else
	XFLOAT *tmpReal = new XFLOAT[mdlXYZ];
	XFLOAT *tmpImag = new XFLOAT[mdlXYZ];

	for (unsigned long i = 0; i < mdlXYZ; i ++)
	{
		tmpReal[i] = (XFLOAT) data[i].real;
		tmpImag[i] = (XFLOAT) data[i].imag;
	}

	initMdl(tmpReal, tmpImag);

	delete [] tmpReal;
	delete [] tmpImag;
#endif
}

#if(COMPLEXTEXTURE)
void CudaProjector::clear()
{
	if (mdlComplex != 0)
	{
		hipDestroyTextureObject(*mdlComplex);
		delete mdlComplex;

		if(mdlZ!=0) //3D case
		{
			hipFreeArray(*texArrayComplex);
			delete texArrayComplex;
		}
		else //2D case
			hipFree(texArrayComplex2D);

		texArrayComplex= 0;
		mdlComplex = 0;
	}
}

#else

void CudaProjector::clear()
{
	mdlX = 0;
	mdlY = 0;
	mdlZ = 0;
	mdlXYZ = 0;
	mdlInitY = 0;
	mdlInitZ = 0;
	mdlMaxR = 0;
	padding_factor = 0;
	allocaton_size = 0;

	if (mdlReal != 0)
	{
#ifndef CUDA_NO_TEXTURES
		hipDestroyTextureObject(*mdlReal);
		hipDestroyTextureObject(*mdlImag);
		delete mdlReal;
		delete mdlImag;

		if(mdlZ!=0) //3D case
		{
			hipFreeArray(*texArrayReal);
			hipFreeArray(*texArrayImag);
			delete texArrayReal;
			delete texArrayImag;
		}
		else //2D case
		{
			HANDLE_ERROR(hipFree(texArrayReal2D));
			HANDLE_ERROR(hipFree(texArrayImag2D));
		}

		texArrayReal = 0;
		texArrayImag = 0;
#else
		hipFree(mdlReal);
		hipFree(mdlImag);
#endif
		mdlReal = 0;
		mdlImag = 0;
	}
}
	#endif

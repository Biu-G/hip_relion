#include "src/acc/acc_projector.h"
#include <signal.h>


bool AccProjector::setMdlDim(
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
		mdlXYZ = (size_t)xdim*(size_t)ydim;
	else
		mdlXYZ = (size_t)xdim*(size_t)ydim*(size_t)zdim;
	mdlInitY = inity;
	mdlInitZ = initz;
	mdlMaxR = maxr;
	padding_factor = paddingFactor;

#ifndef PROJECTOR_NO_TEXTURES

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

#else
#ifdef CUDA
	DEBUG_HANDLE_ERROR(hipMalloc( (void**) &mdlReal, mdlXYZ * sizeof(XFLOAT)));
	DEBUG_HANDLE_ERROR(hipMalloc( (void**) &mdlImag, mdlXYZ * sizeof(XFLOAT)));
#else
	mdlComplex = NULL;
#endif
#endif
	return true;
}

void AccProjector::initMdl(XFLOAT *real, XFLOAT *imag)
{
#ifdef DEBUG_CUDA
	if (mdlXYZ == 0)
	{
        printf("DEBUG_ERROR: Model dimensions must be set with setMdlDim before call to setMdlData.");
		CRITICAL(ERR_MDLDIM);
	}
#ifdef CUDA
	if (mdlReal == NULL)
	{
        printf("DEBUG_ERROR: initMdl called before call to setMdlData.");
		CRITICAL(ERR_MDLSET);
	}
#else
	if (mdlComplex == NULL)
	{
        printf("DEBUG_ERROR: initMdl called before call to setMdlData.");
		CRITICAL(ERR_MDLSET);
	}
#endif
#endif

#ifndef PROJECTOR_NO_TEXTURES
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
#ifdef CUDA
	DEBUG_HANDLE_ERROR(hipMemcpy( mdlReal, real, mdlXYZ * sizeof(XFLOAT), hipMemcpyHostToDevice));
	DEBUG_HANDLE_ERROR(hipMemcpy( mdlImag, imag, mdlXYZ * sizeof(XFLOAT), hipMemcpyHostToDevice));
#else
	std::complex<XFLOAT> *pData = mdlComplex;
    for(size_t i=0; i<mdlXYZ; i++) {
		std::complex<XFLOAT> arrayval(*real ++, *imag ++);
		pData[i] = arrayval;		        
    }
#endif
#endif

}

#ifndef CUDA
void AccProjector::initMdl(std::complex<XFLOAT> *data)
{
	mdlComplex = data;  // No copy needed - everyone shares the complex reference arrays
	externalFree = 1;   // This is shared memory freed outside the projector
}
#endif

void AccProjector::initMdl(Complex *data)
{
	XFLOAT *tmpReal;
	XFLOAT *tmpImag;
	if (posix_memalign((void **)&tmpReal, MEM_ALIGN, mdlXYZ * sizeof(XFLOAT))) CRITICAL(RAMERR);
	if (posix_memalign((void **)&tmpImag, MEM_ALIGN, mdlXYZ * sizeof(XFLOAT))) CRITICAL(RAMERR);


	for (size_t i = 0; i < mdlXYZ; i ++)
	{
		tmpReal[i] = (XFLOAT) data[i].real;
		tmpImag[i] = (XFLOAT) data[i].imag;
	}

	initMdl(tmpReal, tmpImag);

	free(tmpReal);
	free(tmpImag);
}

void AccProjector::clear()
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

#ifdef CUDA
	if (mdlReal != 0)
	{
#ifndef PROJECTOR_NO_TEXTURES
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
#else // ifdef CUDA
	if ((mdlComplex != NULL) && (externalFree == 0))
	{
		delete [] mdlComplex;
		mdlComplex = NULL;
	}
#endif  // ifdef CUDA
}

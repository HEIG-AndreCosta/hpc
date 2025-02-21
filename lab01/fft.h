

#ifndef FFT_H
#define FFT_H
#include <math.h>
#include <complex.h>
#include <stddef.h>

typedef float complex cplx_t;

int fft(cplx_t *buf, size_t n);

void float_to_cplx_t(float *in, cplx_t *out, size_t n);
void extract_frequencies(const cplx_t *buf, size_t n, double sample_rate);

#endif

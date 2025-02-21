
#include "utils.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "fft.h"
static void _fft(cplx_t *buf, cplx_t *out, size_t n, size_t step);

/*
 * Source: https://rosettacode.org/wiki/Fast_Fourier_transform#C
 */
int fft(cplx_t *buf, size_t n)
{
	if (!is_power_of_2(n)) {
		printf("Can't perform fft if n is not a power of 2\n");
		return 1;
	}

	cplx_t *tmp = (cplx_t *)calloc(n, sizeof(cplx_t));
	if (!tmp) {
		return 1;
	}

	memcpy(tmp, buf, n * sizeof(*buf));
	_fft(buf, tmp, n, 1);
	return 0;
}

void float_to_cplx_t(float *in, cplx_t *out, size_t n)
{
	for (size_t i = 0; i < n; ++i) {
		out[i] = in[i] + 0. * I;
	}
}
void extract_frequencies(const cplx_t *buf, size_t n, double sample_rate)
{
	for (size_t i = 0; i < n; ++i) {
		double magnitude = cabs(buf[i]);
		if (magnitude > 1) {
			double frequency =
				(i * sample_rate) / n; // Compute frequency
			printf("Freq: %g Hz, Magnitude: %g\n", frequency,
			       magnitude);
		}
	}
}

/*
 * Source: https://rosettacode.org/wiki/Fast_Fourier_transform#C
 */
static void _fft(cplx_t *buf, cplx_t *tmp, size_t n, size_t step)
{
	if (step >= n) {
		return;
	}
	for (size_t i = 0; i < n; i += 2 * step) {
		const cplx_t t = cexp(-I * M_PI * i / n) * tmp[i + step];
		buf[i / 2] = tmp[i] + t;
		buf[(i + n) / 2] = tmp[i] - t;
	}
}

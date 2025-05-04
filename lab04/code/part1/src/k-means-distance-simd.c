
#include <immintrin.h>
#include <stdint.h>
// This function will calculate the euclidean distance between two pixels.
// Instead of using coordinates, we use the RGB value for evaluating distance.
//
void distance_simd(const uint8_t *p1, const uint8_t *p2, uint32_t *result)
{
	__m128i v1 = _mm_loadu_si128((__m128i const *)p1);
	__m128i v2 = _mm_loadu_si128((__m128i const *)p2);

#if 0 /* Assume that the alpha channel is always set to zero so no need to mask */
	const __m128i mask = _mm_set_epi8(0x00, 0xFF, 0xFF, 0xFF, 0x00, 0xFF,
					  0xFF, 0xFF, 0x00, 0xFF, 0xFF, 0xFF,
					  0x00, 0xFF, 0xFF, 0xFF);

	v1 = _mm_and_si128(v1, mask);
	v2 = _mm_and_si128(v2, mask);
#endif

	__m128i zero = _mm_setzero_si128();

	__m128i v1lo = _mm_unpacklo_epi8(v1, zero);
	__m128i v1hi = _mm_unpackhi_epi8(v1, zero);
	__m128i v2lo = _mm_unpacklo_epi8(v2, zero);
	__m128i v2hi = _mm_unpackhi_epi8(v2, zero);

	__m128i diff_lo = _mm_sub_epi16(v1lo, v2lo);
	__m128i diff_hi = _mm_sub_epi16(v1hi, v2hi);

	__m128i sq_lo = _mm_mullo_epi16(diff_lo, diff_lo);
	__m128i sq_hi = _mm_mullo_epi16(diff_hi, diff_hi);

	uint16_t tmp[16];
	_mm_storeu_si128((__m128i *)tmp, sq_lo);
	_mm_storeu_si128((__m128i *)(tmp + 8), sq_hi);

	for (size_t i = 0; i < 4; ++i) {
		size_t j = i * 4;
		result[i] = tmp[j] + tmp[j + 1] + tmp[j + 2];
	}
}

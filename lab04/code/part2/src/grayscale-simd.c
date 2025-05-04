#include <immintrin.h>
#include <stdint.h>

void grayscale_simd(uint8_t *buffer, int width, int height)
{
	const size_t image_size = width * height;
	const size_t n = image_size - (image_size % 8);
	const size_t stride = 4;
	const __m256 red_weight = _mm256_set1_ps(0.299f);
	const __m256 green_weight = _mm256_set1_ps(0.587f);
	const __m256 blue_weight = _mm256_set1_ps(0.114f);

	size_t i;
	uint32_t grays[8];
	for (i = 0; i < n; i += 8) {
		__m256i pixel_data =
			_mm256_loadu_si256((__m256i *)(buffer + i * stride));

		// Extract R, G, B components for 8 pixels
		__m256i r_values =
			_mm256_and_si256(_mm256_srli_epi32(pixel_data, 0),
					 _mm256_set1_epi32(0xFF));
		__m256i g_values =
			_mm256_and_si256(_mm256_srli_epi32(pixel_data, 8),
					 _mm256_set1_epi32(0xFF));
		__m256i b_values =
			_mm256_and_si256(_mm256_srli_epi32(pixel_data, 16),
					 _mm256_set1_epi32(0xFF));
		__m256 r_float = _mm256_cvtepi32_ps(r_values);
		__m256 g_float = _mm256_cvtepi32_ps(g_values);
		__m256 b_float = _mm256_cvtepi32_ps(b_values);

		// Apply weights
		__m256 r_weighted = _mm256_mul_ps(r_float, red_weight);
		__m256 g_weighted = _mm256_mul_ps(g_float, green_weight);
		__m256 b_weighted = _mm256_mul_ps(b_float, blue_weight);

		// Sum the weighted values
		__m256 gray_float = _mm256_add_ps(
			_mm256_add_ps(r_weighted, g_weighted), b_weighted);

		// Convert back to integers
		__m256i gray_int = _mm256_cvtps_epi32(gray_float);

		// Store the grayscale values
		_mm256_store_si256((__m256i *)grays, gray_int);

		// Update original buffer with grayscale values
		for (int j = 0; j < 8; j++) {
			uint8_t gray = (uint8_t)grays[j];
			uint32_t offset = (j + i) * stride;
			buffer[offset] = gray;
			buffer[offset + 1] = gray;
			buffer[offset + 2] = gray;
		}
	}

	for (; i < image_size; i++) {
		const uint32_t offset = i * stride;
		const uint8_t r = buffer[offset];
		const uint8_t g = buffer[offset + 1];
		const uint8_t b = buffer[offset + 2];

		const uint8_t gray =
			(uint8_t)(0.299f * r + 0.587f * g + 0.114f * b);

		buffer[offset] = gray;
		buffer[offset + 1] = gray;
		buffer[offset + 2] = gray;
	}
}

#include <stddef.h>
#include <stdint.h>

uint32_t distance_single_pixel(const uint8_t *p1, const uint8_t *p2)
{
	uint32_t r_diff = p1[0] - p2[0];
	uint32_t g_diff = p1[1] - p2[1];
	uint32_t b_diff = p1[2] - p2[2];
	return r_diff * r_diff + g_diff * g_diff + b_diff * b_diff;
}

void distance_four_pixels(const uint8_t *p1, const uint8_t *p2,
			  uint32_t *results)
{
	for (size_t i = 0; i < 4; ++i) {
		results[i] = distance_single_pixel(&p1[i * 4], &p2[i * 4]);
	}
}

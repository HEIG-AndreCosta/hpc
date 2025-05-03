#include <stdint.h>

uint32_t distance_single_pixel(uint8_t *p1, uint8_t *p2)
{
	uint32_t r_diff = p1[0] - p2[0];
	uint32_t g_diff = p1[1] - p2[1];
	uint32_t b_diff = p1[2] - p2[2];
	return r_diff * r_diff + g_diff * g_diff + b_diff * b_diff;
}

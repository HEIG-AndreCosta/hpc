#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>

#include <k-means.h>

int main(void)
{
	uint8_t a[16] = { 178, 130, 144, 173, 125, 139, 170, 122,
			  138, 170, 122, 138, 171, 123, 139, 167 };
	uint8_t b[16] = { 115, 107, 146, 0, 115, 107, 146, 0,
			  115, 107, 146, 0, 115, 107, 146, 0 };

#if 0
	srand(time(NULL));
	for (size_t i = 0; i < 16; ++i) {
		a[i] = 0;
		b[i] = rand() % (UINT8_MAX + 1);
	}
#endif

	uint32_t expected_distances[4] = { 0 };
	uint32_t actual_distances[4] = { 0 };

	for (size_t i = 0; i < 4; i++) {
		printf("A %#x %#x %#x\n", a[i * 4], a[i * 4 + 1], a[i * 4 + 2]);
		printf("B %#x %#x %#x\n", a[i * 4], b[i * 4 + 1], b[i * 4 + 2]);

		expected_distances[i] =
			distance_single_pixel(a + i * 4, b + i * 4);
	}
	for (size_t i = 0; i < 16; i += 4) {
		distance_simd(a + i, b + i, actual_distances + i);
	}

	bool ok = true;

	for (size_t i = 0; i < 4; ++i) {
		const uint32_t expected = expected_distances[i];
		const uint32_t actual = actual_distances[i];
		const bool equal = expected == actual;
		printf("[%zu]: %u %u - %s\n", i, expected, actual,
		       equal ? "OK" : "KO");

		ok = ok && equal;
	}

	return !ok;
}

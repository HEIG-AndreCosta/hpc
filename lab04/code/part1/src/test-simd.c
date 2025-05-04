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
	uint8_t a[16];
	uint8_t b[16];
	srand(time(NULL));

	for (size_t i = 0; i < 16; ++i) {
		a[i] = rand() % (UINT8_MAX + 1);
		b[i] = rand() % (UINT8_MAX + 1);
	}

	uint32_t expected_distances[4] = { 0 };
	uint32_t actual_distances[4] = { 0 };

	for (size_t i = 0; i < 4; i++) {
		printf("A %#x %#x %#x\n", a[i * 4], a[i * 4 + 1], a[i * 4 + 2]);
		printf("B %#x %#x %#x\n", a[i * 4], b[i * 4 + 1], a[i * 4 + 2]);

		expected_distances[i] =
			distance_single_pixel(a + i * 4, b + i * 4);

		distance_simd(a + i * 4, b + i * 4, actual_distances + i);
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

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

		uint32_t red = a[i * 4] - b[i * 4];
		uint32_t green = a[i * 4 + 1] - b[i * 4 + 1];
		uint32_t blue = a[i * 4 + 2] - b[i * 4 + 2];
		printf("Diff %#x %#x %#x\n", red, green, blue);
		red = red * red;
		green = green * green;
		blue = blue * blue;
		printf("Squared %#x %#x %#x\n", red, green, blue);

		expected_distances[i] = red + green + blue;
		printf("Distance %#x\n", expected_distances[i]);

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

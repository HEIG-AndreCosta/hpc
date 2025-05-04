#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

#include <grayscale.h>

uint8_t *generate_test_image(int width, int height)
{
	uint8_t *buffer = (uint8_t *)malloc(width * height * 4);
	if (!buffer) {
		return NULL;
	}

	for (int i = 0; i < width * height; i++) {
		buffer[i * 4] = rand() % 256; // R
		buffer[i * 4 + 1] = rand() % 256; // G
		buffer[i * 4 + 2] = rand() % 256; // B
		buffer[i * 4 + 3] = 255; // A (fully opaque)
	}

	return buffer;
}

int compare_images(uint8_t *img1, uint8_t *img2, int width, int height)
{
	int diff_count = 0;
	int total_pixels = width * height;

	for (int i = 0; i < total_pixels; i++) {
		int offset = i * 4;
		for (int c = 0; c < 3; c++) {
			const int diff =
				abs(img1[offset + c] - img2[offset + c]);
			if (diff > 1) {
				diff_count++;
				break;
			}
		}
	}

	return diff_count;
}

// Measure execution time in milliseconds
double measure_time_ms(struct timespec start, struct timespec end)
{
	return (end.tv_sec - start.tv_sec) * 1000.0 +
	       (end.tv_nsec - start.tv_nsec) / 1000000.0;
}

int main(int argc, char *argv[])
{
	const size_t width = 1920;
	const size_t height = 1080;
	const size_t num_runs = 10;

	printf("Testing grayscale conversion on %zux%zu image (%zu runs)\n",
	       width, height, num_runs);

	srand(time(NULL));

	uint8_t *original = generate_test_image(width, height);
	uint8_t *sequential_result = (uint8_t *)malloc(width * height * 4);
	uint8_t *avx_result = (uint8_t *)malloc(width * height * 4);

	assert(original);
	assert(sequential_result);
	assert(avx_result);

	struct timespec start, end;
	double sequential_time = 0.0;
	double avx_time = 0.0;

	for (size_t run = 0; run < num_runs; run++) {
		memcpy(sequential_result, original, width * height * 4);
		memcpy(avx_result, original, width * height * 4);

		clock_gettime(CLOCK_MONOTONIC, &start);
		grayscale(sequential_result, width, height);
		clock_gettime(CLOCK_MONOTONIC, &end);
		sequential_time += measure_time_ms(start, end);

		clock_gettime(CLOCK_MONOTONIC, &start);
		grayscale_simd(avx_result, width, height);
		clock_gettime(CLOCK_MONOTONIC, &end);
		avx_time += measure_time_ms(start, end);
	}

	sequential_time /= num_runs;
	avx_time /= num_runs;

	int diff_count =
		compare_images(sequential_result, avx_result, width, height);
	double diff_percentage = 100.0 * diff_count / (width * height);

	printf("\nResults:\n");
	printf("Sequential implementation: %.3f ms\n", sequential_time);
	printf("AVX implementation: %.3f ms\n", avx_time);
	printf("Speed improvement: %.2fx\n", sequential_time / avx_time);
	printf("Pixel differences: %d (%.6f%%)\n", diff_count, diff_percentage);

	if (diff_percentage < 0.1) {
		printf("Test PASSED: Implementations produce equivalent results\n");
	} else {
		printf("Test FAILED: Implementations produce different results\n");
	}

	free(original);
	free(sequential_result);
	free(avx_result);

	return 0;
}

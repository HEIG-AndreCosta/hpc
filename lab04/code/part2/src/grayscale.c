
#include <stddef.h>
#include <stdint.h>
void grayscale(uint8_t *buffer, int width, int height)
{
	const size_t image_size = width * height;
	const size_t stride = 4;

	for (size_t i = 0; i < image_size; i++) {
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


#include "image.h"
#include "grayscale.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

int main(int argc, char **argv)
{
	struct img_t *image;
	if (argc < 3) {
		fprintf(stderr, "Usage : %s <img_src.png>  <img_dest.png>\n",
			argv[0]);
		return EXIT_FAILURE;
	}

	image = load_image(argv[1]);

	printf("Image loaded!\n");

	struct img_t padded_image;
	padded_image.width = image->width;
	padded_image.height = image->height;
	padded_image.components = 4;
	padded_image.data = image->data;
	bool padded = false;

	if (image->components < 4) {
		printf("Image is not RGBA. Padding image...\n");

		const size_t image_size = image->width * image->height;

		padded_image.data = calloc(image_size * padded_image.components,
					   sizeof(uint8_t));

		padded = true;

		for (size_t i = 0; i < image_size; i++) {
			memcpy(padded_image.data + i * padded_image.components,
			       image->data + i * image->components,
			       image->components * sizeof(uint8_t));
		}

	} else if (image->components > 4) {
		printf("Can't process image with more than 4 components\n");
		return 1;
	}

#ifdef SIMD
	printf("Using SIMD\n");

	grayscale_simd(padded_image.data, padded_image.width,
		       padded_image.height);
#else
	printf("Using sequential version \n");
	grayscale(padded_image.data, padded_image.width, padded_image.height);
#endif

	if (padded) {
		const size_t image_size = image->width * image->height;
		for (size_t i = 0; i < image_size; i++) {
			memcpy(image->data + i * image->components,
			       padded_image.data + i * padded_image.components,
			       image->components * sizeof(uint8_t));
		}
		free(padded_image.data);
	}

	save_image(argv[2], image);
	free_image(image);

	printf("Programm ended successfully\n\n");

	return 0;
}

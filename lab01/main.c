#include "buffer.h"
#include "dtmf.h"
#include "file.h"
#include "wave.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

void print_usage(const char *prog)
{
	printf("Usage :\n  %s encode input.txt output.wav\n  %s decode input.wav\n",
	       prog, prog);
}

int main(int argc, char *argv[])
{
	if (argc < 3) {
		print_usage(argv[0]);
		return 1;
	}

	if (strcmp(argv[1], "encode") == 0) {
		if (argc != 4) {
			print_usage(argv[0]);
			return 1;
		}
		dtmf_t encoder;
		const char *content = file_read(argv[2]);
		if (!content) {
			return EXIT_FAILURE;
		}
		int err = (int)dtmf_encode(&encoder, content) != DTMF_OK;
		free((void *)content);

		if (err != DTMF_OK) {
			puts(dtmf_err_to_string(err));
			return EXIT_FAILURE;
		}
		err = wave_generate(argv[3], encoder.buffer.data,
				    encoder.buffer.len, encoder.channels,
				    encoder.sample_rate);
		dtmf_terminate(&encoder);
		return err != 0;

	} else if (strcmp(argv[1], "decode") == 0) {
		dtmf_t decoder;
		double sample_rate;
		size_t len;
		float *data = wave_read(argv[2], &len, &sample_rate);
		if (!data) {
			return EXIT_FAILURE;
		}

		buffer_construct(&decoder.buffer, data, len, len);
		decoder.sample_rate = sample_rate;
		decoder.channels = 1;

		char *value = dtmf_decode(&decoder);
		if (!value) {
			printf("Failed to decode\n");
			return EXIT_FAILURE;
		}

		printf("Decoded: %s\n", value);
		free(value);
		dtmf_terminate(&decoder);
		return EXIT_SUCCESS;

	} else {
		print_usage(argv[0]);
		return 1;
	}

	return 0;
}

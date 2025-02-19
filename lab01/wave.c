
#include "wave.h"
#include <sndfile-64.h>

int wave_generate(const char *path, float *buffer, size_t len,
		  uint32_t channels, uint32_t sample_rate)
{
	SF_INFO sfinfo;
	sfinfo.format = SF_FORMAT_WAV | SF_ENDIAN_FILE | SF_FORMAT_FLOAT;
	sfinfo.frames = len;
	sfinfo.channels = channels;
	sfinfo.samplerate = sample_rate;

	SNDFILE *outfile = sf_open(path, SFM_WRITE, &sfinfo);
	if (!outfile) {
		printf("Error creating wave file: %s\n", sf_strerror(NULL));
		return -1;
	}

	sf_writef_float(outfile, buffer, len);
	sf_close(outfile);
	return 0;
}

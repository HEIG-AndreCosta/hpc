#include "dtmf.h"

#include "buffer.h"
#include <assert.h>
#include <math.h>
#include <ctype.h>
#include <sndfile-64.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#define COL0_CHARS		 "147#ghipqrs.!?,"
#define COL1_CHARS		 "2580abcjkltuv "
#define COL2_CHARS		 "369defmnowxyz"

#define ROW0_CHARS		 "123abcdef"
#define ROW1_CHARS		 "456ghijklmno"
#define ROW2_CHARS		 "789pqrstuvwxyz"
#define ROW3_CHARS		 "#0.!?, "

#define SPECIAL_CHARS		 ".!?,# "

#define CHAR_SOUND_DURATION	 0.2
#define CHAR_PAUSE_DURATION	 0.2
#define SAME_CHAR_PAUSE_DURATION 0.05

#define CHAR_SOUND_SAMPLES	 (CHAR_SOUND_DURATION * SAMPLE_RATE)
#define CHAR_PAUSE_SAMPLES	 (CHAR_PAUSE_DURATION * SAMPLE_RATE)
#define SAME_CHAR_PAUSE_SAMPLES	 (SAME_CHAR_PAUSE_DURATION * SAMPLE_RATE)

#define AMPLITUDE		 .3
#define SILENCE_F1		 0
#define SILENCE_F2		 0

static float s(float a, uint32_t f1, uint32_t f2, uint32_t t);
static int push_samples(buffer_t *buffer, uint32_t f1, uint32_t f2,
			size_t nb_samples);

static uint8_t char_row(char c);
static uint8_t char_col(char c);

static uint32_t row_freq(uint8_t row);
static uint32_t col_freq(uint8_t col);
static bool is_char_valid(char c);
static int encode_internal(buffer_t *buffer, const char *value);
static dtmf_err_t generate_wave(buffer_t *buffer, const char *path);

bool dtmf_is_valid(const char *value)
{
	assert(value);
	for (size_t i = 0; i < strlen(value); ++i) {
		if (!is_char_valid(value[i])) {
			return false;
		}
	}
	return true;
}

dtmf_err_t dtmf_encode(const char *value, const char *out_path)
{
	if (!dtmf_is_valid(value)) {
		return DTMF_INVALID_ENCODING_STRING;
	}
	buffer_t buffer;

	printf("Allocating Memory\n");
	int err = buffer_init(&buffer, strlen(value) * CHAR_SOUND_SAMPLES *
					       sizeof(float));
	if (err < 0) {
		return DTMF_NO_MEMORY;
	}
	printf("Encoding\n");
	err = (int)encode_internal(&buffer, value);

	if (err != DTMF_OK) {
		return err;
	}
	printf("Generating Wave\n");
	return generate_wave(&buffer, out_path);
}

static int encode_internal(buffer_t *buffer, const char *value)
{
	uint32_t last_btn;
	for (size_t i = 0; i < strlen(value); ++i) {
		const uint8_t row = char_row(value[i]);
		const uint8_t col = char_col(value[i]);
		const uint32_t f1 = row_freq(row);
		const uint32_t f2 = col_freq(col);
		const uint32_t btn = row * 3 + col;

		int err;
		if (i > 0) {
			if (btn == last_btn) {
				err = push_samples(buffer, SILENCE_F1,
						   SILENCE_F2,
						   SAME_CHAR_PAUSE_SAMPLES);
			} else {
				err = push_samples(buffer, SILENCE_F1,
						   SILENCE_F2,
						   CHAR_PAUSE_SAMPLES);
			}
			if (err < 0) {
				return DTMF_NO_MEMORY;
			}
		}
		err = push_samples(buffer, f1, f2, CHAR_SOUND_SAMPLES);
		if (err < 0) {
			return DTMF_NO_MEMORY;
		}
		last_btn = btn;
	}
	return DTMF_OK;
}
static dtmf_err_t generate_wave(buffer_t *buffer, const char *path)
{
	SF_INFO sfinfo;
	sfinfo.format = SF_FORMAT_WAV | SF_ENDIAN_FILE | SF_FORMAT_FLOAT;
	sfinfo.frames = buffer->len;
	sfinfo.channels = 1;
	sfinfo.samplerate = SAMPLE_RATE;

	SNDFILE *outfile = sf_open(path, SFM_WRITE, &sfinfo);
	if (!outfile) {
		fprintf(stderr,
			"Erreur: Impossible de créer le fichier '%s': %s\n",
			path, sf_strerror(NULL));

		return -1;
	}

	sf_writef_float(outfile, buffer->data, buffer->len);
	sf_close(outfile);
	buffer_terminate(buffer);
	return DTMF_OK;
}

static int push_samples(buffer_t *buffer, uint32_t f1, uint32_t f2,
			size_t nb_samples)
{
	for (size_t i = 0; i < nb_samples; ++i) {
		int err = buffer_push(buffer, s(AMPLITUDE, f1, f2, i));
		if (err < 0) {
			return err;
		}
	}
	return 0;
}

static float s(float a, uint32_t f1, uint32_t f2, uint32_t t)
{
	return a * (sin(2. * M_PI * f1 * t / SAMPLE_RATE) +
		    sin(2. * M_PI * f2 * t / SAMPLE_RATE));
}

static bool is_char_valid(char c)
{
	return islower(c) || isdigit(c) || strchr(SPECIAL_CHARS, c) != NULL;
}

static uint8_t char_row(char c)
{
	if (strchr(ROW0_CHARS, c) != NULL) {
		return 0;
	}
	if (strchr(ROW1_CHARS, c) != NULL) {
		return 1;
	}
	if (strchr(ROW2_CHARS, c) != NULL) {
		return 2;
	}
	if (strchr(ROW3_CHARS, c) != NULL) {
		return 3;
	}
	assert(0 && "Invalid Character Found");
}
static uint8_t char_col(char c)
{
	if (strchr(COL0_CHARS, c) != NULL) {
		return 0;
	}
	if (strchr(COL1_CHARS, c) != NULL) {
		return 1;
	}
	if (strchr(COL2_CHARS, c) != NULL) {
		return 2;
	}
	assert(0 && "Invalid Character Found");
}

static uint32_t row_freq(uint8_t row)
{
	assert(row < (sizeof(ROW_FREQ) / sizeof(ROW_FREQ[0])));
	return ROW_FREQ[row];
}
static uint32_t col_freq(uint8_t col)
{
	assert(col < (sizeof(COL_FREQ) / sizeof(COL_FREQ[0])));
	return COL_FREQ[col];
}

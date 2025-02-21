#include "dtmf.h"

#include "buffer.h"
#include "fft.h"
#include "utils.h"
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

#define MIN_FREQ		 697
#define MAX_FREQ		 1500

const char *button_characters[11] = { "1",     "2abc",	"3def",	 "4ghi",
				      "5jkl",  "6mno",	"7pqrs", "8tuv",
				      "9wxyz", "#.!?,", "0 " };

static float s(float a, uint32_t f1, uint32_t f2, uint32_t t);
static int push_samples(buffer_t *buffer, uint32_t f1, uint32_t f2,
			size_t nb_samples);

static uint8_t char_row(char c);
static uint8_t char_col(char c);

static uint32_t row_freq(uint8_t row);
static uint32_t col_freq(uint8_t col);
static bool is_char_valid(char c);
static int encode_internal(buffer_t *buffer, const char *value);
static size_t get_times_to_push(size_t btn_nr, char value);

static uint8_t closest_row(uint32_t freq);
static uint8_t closest_col(uint32_t freq);
static uint8_t closest(const uint16_t *values, size_t len, uint32_t freq);
static bool is_valid_frequency(uint32_t freq);

const char *dtmf_err_to_string(dtmf_err_t err)
{
	switch (err) {
	case DTMF_OK:
		return "dtmf ok";
	case DTMF_INVALID_ENCODING_STRING:
		return "dtmf invalid encoding string";
	case DTMF_NO_MEMORY:
		return "dtmf no memory";
	}
	return "dtmf unknown error";
}

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

dtmf_err_t dtmf_encode(dtmf_t *dtmf, const char *value)
{
	if (!dtmf_is_valid(value)) {
		return DTMF_INVALID_ENCODING_STRING;
	}

	int err =
		buffer_init(&dtmf->buffer,
			    strlen(value) * CHAR_SOUND_SAMPLES * sizeof(float));
	if (err < 0) {
		return DTMF_NO_MEMORY;
	}
	dtmf->channels = 1;
	dtmf->sample_rate = SAMPLE_RATE;
	return encode_internal(&dtmf->buffer, value);
}

char *dtmf_decode(dtmf_t *dtmf)
{
	size_t len = SAME_CHAR_PAUSE_SAMPLES;
	if (!is_power_of_2(len)) {
		len = align_to_power_of_2(len);
	}

	cplx_t *buffer = calloc(len, sizeof(*buffer));
	if (!buffer) {
		printf("Failed to allocate memory for decode\n");
		return NULL;
	}

	printf("Converting to cplx_t\n");
	float_to_cplx_t(dtmf->buffer.data, buffer, len);
	printf("Running fft\n");
	int err = fft(buffer, len);
	if (err != 0) {
		printf("Error running fft\n");
		return NULL;
	}
	printf("Extracting frequencies\n");
	uint32_t f1 = 0, f2 = 0;
	for (size_t i = 0; i + len < dtmf->buffer.len;
	     i += CHAR_SOUND_SAMPLES) {
		extract_frequencies(buffer + i, len, dtmf->sample_rate, &f1,
				    &f2);
		if (!(is_valid_frequency(f1) && is_valid_frequency(f2))) {
			continue;
		}
		uint8_t row, col;
		if (f1 < 1000) {
			row = closest_row(f1);
			col = closest_col(f2);
		} else {
			row = closest_row(f2);
			col = closest_col(f1);
		}
		const size_t btn = row * 3 + col;
		printf("btn %zu\n", btn);
	}
	printf("Extracted %d %d from %zu/%zu samples\n", f1, f2, len,
	       dtmf->buffer.len);
	return NULL;
}

void dtmf_terminate(dtmf_t *dtmf)
{
	buffer_terminate(&dtmf->buffer);
}

static uint8_t closest(const uint16_t *values, size_t len, uint32_t freq)
{
	int diff = 0xFFFF;
	uint8_t closest = 0;
	for (size_t i = 0; i < len; ++i) {
		const int curr_diff = abs(values[i] - (int)freq);
		if (curr_diff < diff) {
			closest = i;
			diff = curr_diff;
		}
	}
	return closest;
}
static uint8_t closest_row(uint32_t freq)
{
	return closest(ROW_FREQ, sizeof(ROW_FREQ) / sizeof(ROW_FREQ[0]), freq);
}
static uint8_t closest_col(uint32_t freq)
{
	return closest(COL_FREQ, sizeof(COL_FREQ) / sizeof(COL_FREQ[0]), freq);
}
static bool is_valid_frequency(uint32_t freq)
{
	return freq > 650 || freq < 1500;
}
static int encode_internal(buffer_t *buffer, const char *value)
{
	for (size_t i = 0; i < strlen(value); ++i) {
		const uint8_t row = char_row(value[i]);
		const uint8_t col = char_col(value[i]);
		const uint32_t f1 = row_freq(row);
		const uint32_t f2 = col_freq(col);
		const size_t btn = row * 3 + col;
		const size_t times_to_push = get_times_to_push(btn, value[i]);

		int err;
		if (i > 0) {
			err = push_samples(buffer, SILENCE_F1, SILENCE_F2,
					   CHAR_PAUSE_SAMPLES);
			if (err < 0) {
				return DTMF_NO_MEMORY;
			}
		}
		for (size_t j = 0; j < times_to_push; ++j) {
			if (j > 0) {
				err = push_samples(buffer, SILENCE_F1,
						   SILENCE_F2,
						   SAME_CHAR_PAUSE_SAMPLES);
				if (err < 0) {
					return DTMF_NO_MEMORY;
				}
			}

			err = push_samples(buffer, f1, f2, CHAR_SOUND_SAMPLES);
			if (err < 0) {
				return DTMF_NO_MEMORY;
			}
		}
	}
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
static size_t get_times_to_push(size_t btn_nr, char value)
{
	assert(btn_nr <
	       sizeof(button_characters) / sizeof(button_characters[0]));

	const char *char_btn_position =
		strchr(button_characters[btn_nr], value);

	assert(char_btn_position);

	return char_btn_position - button_characters[btn_nr] + 1;
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

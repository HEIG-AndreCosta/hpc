
#include "dtmf_private.h"

#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <math.h>

#define COL0_CHARS    "147#ghipqrs.!?,"
#define COL1_CHARS    "2580abcjkltuv "
#define COL2_CHARS    "369defmnowxyz"

#define ROW0_CHARS    "123abcdef"
#define ROW1_CHARS    "456ghijklmno"
#define ROW2_CHARS    "789pqrstuvwxyz"
#define ROW3_CHARS    "#0.!?, "
#define SPECIAL_CHARS ".!?,# "

#define AMPLITUDE     .3
#define SILENCE_F1    0
#define SILENCE_F2    0
#define EXTRA_PRESSES 0

static bool is_char_valid(char c);
static int encode_internal(buffer_t *buffer, const char *value,
			   uint32_t sample_rate);

static uint8_t char_row(char c);
static uint8_t char_col(char c);
static uint32_t col_freq(uint8_t col);
static uint32_t row_freq(uint8_t row);
static int push_samples(buffer_t *buffer, uint32_t f1, uint32_t f2,
			size_t nb_samples, uint32_t sample_rate);
static float s(float a, uint32_t f1, uint32_t f2, uint32_t t,
	       uint32_t sample_rate);

bool dtmf_is_valid(const char *value)
{
	assert(value);
	for (size_t i = 0; i < strlen(value); ++i) {
		if (!is_char_valid(value[i])) {
			printf("Found invalid character at position %zu (%c)\n",
			       i + 1, value[i]);
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
	dtmf->channels = 1;
	dtmf->sample_rate = ENCODE_SAMPLE_RATE;

	const size_t initial_capacity =
		strlen(value) * CHAR_SOUND_SAMPLES(dtmf->sample_rate);

	int err = buffer_init(&dtmf->buffer, initial_capacity, sizeof(float));

	if (err < 0) {
		return DTMF_NO_MEMORY;
	}
	return encode_internal(&dtmf->buffer, value, dtmf->sample_rate);
}

static int encode_internal(buffer_t *buffer, const char *value,
			   uint32_t sample_rate)
{
	const size_t nb_samples_on_char_pause = CHAR_PAUSE_SAMPLES(sample_rate);
	const size_t nb_samples_on_same_char_pause =
		SAME_CHAR_PAUSE_SAMPLES(sample_rate);
	const size_t nb_samples_on_char = CHAR_SOUND_SAMPLES(sample_rate);
	for (size_t i = 0; i < strlen(value); ++i) {
		const uint8_t row = char_row(value[i]);
		const uint8_t col = char_col(value[i]);
		const uint32_t f1 = row_freq(row);
		const uint32_t f2 = col_freq(col);
		const size_t btn = row * 3 + col;
		const size_t times_to_push =
			dtmf_get_times_to_push(btn, value[i], EXTRA_PRESSES);

		int err;
		if (i > 0) {
			err = push_samples(buffer, SILENCE_F1, SILENCE_F2,
					   nb_samples_on_char_pause,
					   sample_rate);
			if (err < 0) {
				return DTMF_NO_MEMORY;
			}
		}
		for (size_t j = 0; j < times_to_push; ++j) {
			if (j > 0) {
				err = push_samples(
					buffer, SILENCE_F1, SILENCE_F2,
					nb_samples_on_same_char_pause,
					sample_rate);
				if (err < 0) {
					return DTMF_NO_MEMORY;
				}
			}

			err = push_samples(buffer, f1, f2, nb_samples_on_char,
					   sample_rate);
			if (err < 0) {
				return DTMF_NO_MEMORY;
			}
		}
	}
	return DTMF_OK;
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
	return 0xFF;
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
	return 0xFF;
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

static int push_samples(buffer_t *buffer, uint32_t f1, uint32_t f2,
			size_t nb_samples, uint32_t sample_rate)
{
	for (size_t i = 0; i < nb_samples; ++i) {
		const float value = s(AMPLITUDE, f1, f2, i, sample_rate);
		int err = buffer_push(buffer, &value);
		if (err < 0) {
			return err;
		}
	}
	return 0;
}

static float s(float a, uint32_t f1, uint32_t f2, uint32_t t,
	       uint32_t sample_rate)
{
	return a * (sin(2. * M_PI * f1 * t / sample_rate) +
		    sin(2. * M_PI * f2 * t / sample_rate));
}

static bool is_char_valid(char c)
{
	return islower(c) || isdigit(c) || strchr(SPECIAL_CHARS, c) != NULL;
}

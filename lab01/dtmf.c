#include "dtmf.h"

#include "buffer.h"
#include "fft.h"
#include "utils.h"
#include <assert.h>
#include <math.h>
#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
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

#define AMPLITUDE		 .3
#define SILENCE_F1		 0
#define SILENCE_F2		 0
#define EXTRA_PRESSES		 0

#define MIN_FREQ		 697
#define MAX_FREQ		 1500
#define SPECIAL_BUTTON_CHAR	 '*'

#if 0
const char *button_characters[NB_BUTTONS] = { "1",     "2abc",	"3def",	 "4ghi",
					      "5jkl",  "6mno",	"7pqrs", "8tuv",
					      "9wxyz", "#.!?,", "0 " };

#else
const char *button_characters[NB_BUTTONS] = { "1",     "abc2",	"def3",	 "ghi4",
					      "jkl5",  "mno6",	"pqrs7", "tuv8",
					      "wxyz9", "#.!?,", " 0" };
#endif
static const size_t NB_BUTTONS =
	sizeof(button_characters) / sizeof(button_characters[0]);

static float s(float a, uint32_t f1, uint32_t f2, uint32_t t,
	       uint32_t sample_rate);
static int push_samples(buffer_t *buffer, uint32_t f1, uint32_t f2,
			size_t nb_samples, uint32_t sample_rate);

static uint8_t char_row(char c);
static uint8_t char_col(char c);
static char decode(size_t button, size_t presses);

static uint32_t row_freq(uint8_t row);
static uint32_t col_freq(uint8_t col);
static bool is_char_valid(char c);
static int encode_internal(buffer_t *buffer, const char *value,
			   uint32_t sample_rate);
static size_t get_times_to_push(size_t btn_nr, char value);

static float get_amplitude(const float *buffer, size_t len);
static uint8_t closest_row(uint32_t freq);
static uint8_t closest_col(uint32_t freq);
static uint8_t closest(const uint16_t *values, size_t len, uint32_t freq);
static bool is_valid_frequency(uint32_t freq);

static inline size_t char_sound_samples(uint32_t sample_rate)
{
	return CHAR_SOUND_DURATION * sample_rate;
}

static inline size_t char_pause_samples(uint32_t sample_rate)
{
	return CHAR_PAUSE_DURATION * sample_rate;
}

static inline size_t same_char_pause_samples(uint32_t sample_rate)
{
	return SAME_CHAR_PAUSE_DURATION * sample_rate;
}
static inline size_t decode_samples_to_skip_on_silence(uint32_t sample_rate)
{
	return char_pause_samples(sample_rate) -
	       same_char_pause_samples(sample_rate);
}

static inline size_t decode_samples_to_skip_on_press(uint32_t sample_rate)
{
	return char_sound_samples(sample_rate) +
	       same_char_pause_samples(sample_rate);
}

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
		strlen(value) * char_sound_samples(dtmf->sample_rate);

	int err = buffer_init(&dtmf->buffer, initial_capacity, sizeof(float));

	if (err < 0) {
		return DTMF_NO_MEMORY;
	}
	return encode_internal(&dtmf->buffer, value, dtmf->sample_rate);
}

char *dtmf_decode(dtmf_t *dtmf)
{
	size_t len = same_char_pause_samples(dtmf->sample_rate);
	if (!is_power_of_2(len)) {
		len = align_to_power_of_2(len);
	}

	cplx_t *buffer = calloc(len, sizeof(*buffer));
	if (!buffer) {
		printf("Failed to allocate memory for decode\n");
		return NULL;
	}
	buffer_t result;
	int ret = buffer_init(&result, 128, sizeof(char));
	if (ret < 0) {
		printf("Failed to allocate memory for decode result\n");
		free(buffer);
		return NULL;
	}

	const size_t samples_to_skip_on_silence =
		decode_samples_to_skip_on_silence(dtmf->sample_rate);
	const size_t samples_to_skip_on_press =
		decode_samples_to_skip_on_press(dtmf->sample_rate);
	uint32_t f1 = 0, f2 = 0;
	float btn_amplitude = 0;
	size_t i = 0;
	size_t btn = 0xFF;
	size_t consecutive_presses = 0;
	while ((i + len) < dtmf->buffer.len) {
		float amplitude =
			get_amplitude((float *)dtmf->buffer.data + i, len);
		if (i == 0) {
			btn_amplitude = amplitude - (amplitude / 10);
			printf("Using %g as silence amplitude threshold\n",
			       btn_amplitude);
		} else if (amplitude < btn_amplitude) {
			const char decoded = decode(btn, consecutive_presses);
			buffer_push(&result, &decoded);
			consecutive_presses = 0;
			i += samples_to_skip_on_silence;
			continue;
		}

		float_to_cplx_t((float *)dtmf->buffer.data + i, buffer, len);

		int err = fft(buffer, len);
		if (err != 0) {
			printf("Error running fft\n");
			return NULL;
		}
		extract_frequencies(buffer, len, dtmf->sample_rate, &f1, &f2);

		if (!(is_valid_frequency(f1) && is_valid_frequency(f2))) {
			const char decoded = decode(btn, consecutive_presses);
			buffer_push(&result, &decoded);
			consecutive_presses = 0;
			i += samples_to_skip_on_silence;
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
		consecutive_presses++;
		btn = row * 3 + col;
		i += samples_to_skip_on_press;
	}

	/* If the file ended without a silence, add the last button */
	if (consecutive_presses != 0) {
		const char decoded = decode(btn, consecutive_presses);
		buffer_push(&result, &decoded);
	}
	const char terminator = '\0';
	buffer_push(&result, &terminator);
	free(buffer);
	return (char *)result.data;
}

void dtmf_terminate(dtmf_t *dtmf)
{
	buffer_terminate(&dtmf->buffer);
}

static char decode(size_t button, size_t presses)
{
	assert(button <= NB_BUTTONS);

	if (button == NB_BUTTONS) {
		printf("Detected button %zu which should never happen and means the encoding is not very good :(\n",
		       button + 1);
		printf("\tUsing %c to represent this button\n",
		       SPECIAL_BUTTON_CHAR);
		return SPECIAL_BUTTON_CHAR;
	}
	return button_characters[button][(presses - 1) %
					 strlen(button_characters[button])];
}
static float get_amplitude(const float *buffer, size_t len)
{
	float amplitude = 0;

	for (size_t i = 0; i < len; ++i) {
		if (buffer[i] > amplitude) {
			amplitude = buffer[i];
		}
	}
	return amplitude;
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
	return freq > 650 && freq < 1500;
}
static int encode_internal(buffer_t *buffer, const char *value,
			   uint32_t sample_rate)
{
	const size_t nb_samples_on_char_pause = char_pause_samples(sample_rate);
	const size_t nb_samples_on_same_char_pause =
		same_char_pause_samples(sample_rate);
	const size_t nb_samples_on_char = char_sound_samples(sample_rate);
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
static size_t get_times_to_push(size_t btn_nr, char value)
{
	assert(btn_nr <
	       sizeof(button_characters) / sizeof(button_characters[0]));

	const char *char_btn_position =
		strchr(button_characters[btn_nr], value);

	assert(char_btn_position);

	const size_t index = char_btn_position - button_characters[btn_nr] + 1;
	return index + (strlen(button_characters[btn_nr]) * EXTRA_PRESSES);
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

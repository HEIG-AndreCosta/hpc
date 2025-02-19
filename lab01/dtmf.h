
#ifndef DTMF_H
#define DTMF_H

#include "buffer.h"
#include <stdint.h>
#include <stdbool.h>

#define SAMPLE_RATE 44100

static const uint16_t ROW_FREQ[] = { 697, 770, 852, 941 };
static const uint16_t COL_FREQ[] = { 1209, 1336, 1477 };

typedef enum {
	DTMF_OK,
	DTMF_INVALID_ENCODING_STRING,
	DTMF_NO_MEMORY,
} dtmf_err_t;

typedef struct {
	buffer_t buffer;
	uint32_t sample_rate;
	uint32_t channels;
} dtmf_encode_t;

bool dtmf_is_valid(const char *value);
dtmf_err_t dtmf_encode(dtmf_encode_t *dtmf, const char *value);
const char *dtmf_err_to_string(dtmf_err_t err);
void dtmf_terminate(dtmf_encode_t *dtmf);

#endif

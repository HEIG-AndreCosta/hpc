#ifndef WINDOW_H
#define WINDOW_H

#include "dtmf_private.h"
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

typedef struct {
	dtmf_button_t *btn;
	size_t data_offset;
	bool silence_detected_after;
} window_t;

#endif

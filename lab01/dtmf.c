#include "dtmf_private.h"

#include "utils.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

#define SPECIAL_BUTTON_CHAR '*'

#if 0
const char *button_characters[] = { "1",     "2abc",  "3def",  "4ghi",
				    "5jkl",  "6mno",  "7pqrs", "8tuv",
				    "9wxyz", "#.!?,", "0 " };

#else
const char *button_characters[] = { "1",     "abc2",  "def3",  "ghi4",
				    "jkl5",  "mno6",  "pqrs7", "tuv8",
				    "wxyz9", "#.!?,", " 0" };
#endif

size_t dtmf_get_times_to_push(size_t btn_nr, char value, size_t extra_presses)
{
	assert(btn_nr < ARRAY_LEN(button_characters));

	const char *char_btn_position =
		strchr(button_characters[btn_nr], value);

	assert(char_btn_position);

	const size_t index = char_btn_position - button_characters[btn_nr] + 1;
	return index + (strlen(button_characters[btn_nr]) * extra_presses);
}

char dtmf_decode_character(size_t button, size_t presses)
{
	assert(button <= ARRAY_LEN(button_characters));

	if (button == ARRAY_LEN(button_characters)) {
		printf("Detected button %zu which should never happen and means the encoding is not very good :(\n",
		       button + 1);
		printf("\tUsing %c to represent this button\n",
		       SPECIAL_BUTTON_CHAR);
		return SPECIAL_BUTTON_CHAR;
	}
	return button_characters[button][(presses - 1) %
					 strlen(button_characters[button])];
}

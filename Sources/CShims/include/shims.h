#pragma once

#ifdef __linux__
#include <bits/stdint-intn.h>
#include <termios.h>
#endif

int32_t list_zip_archive (void *reader);

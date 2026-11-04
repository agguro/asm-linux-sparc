
/*
 * agguro NAS Monitor
 * File: src/hardware.c
 *
 * Build:
 *   make
 *
 * Hardware information from Linux procfs.
 */

#include "nasmon.h"

int hardware_read_file(const char *path, char *buffer,
                       unsigned int capacity)
{
    (void)path;

    if (capacity == 0)
        return -1;

    buffer[0] = '\0';

    /* File syscalls will be added in the next stage. */
    return -1;
}

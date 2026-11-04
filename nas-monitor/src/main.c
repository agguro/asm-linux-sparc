
/*
 * agguro NAS Monitor
 * File: src/main.c
 *
 * Build:
 *   make
 *
 * Target: Linux/SPARC V8, 32-bit
 * No libc or dynamic linker.
 */

#include "nasmon.h"

int nas_write(int fd, const void *buffer, unsigned int length)
{
    register int g1 __asm__("g1") = 4;
    register int o0 __asm__("o0") = fd;
    register const void *o1 __asm__("o1") = buffer;
    register unsigned int o2 __asm__("o2") = length;

    __asm__ volatile(
        "ta 0x10\n\t"
        "bcc 1f\n\t"
        "nop\n\t"
        "neg %%o0, %%o0\n"
        "1:"
        : "+r"(o0)
        : "r"(g1), "r"(o1), "r"(o2)
        : "cc", "memory"
    );

    return o0;
}

void nas_exit(int status)
{
    register int g1 __asm__("g1") = 1;
    register int o0 __asm__("o0") = status;

    __asm__ volatile(
        "ta 0x10"
        :
        : "r"(g1), "r"(o0)
        : "cc", "memory"
    );

    for (;;) {}
}

unsigned int nas_strlen(const char *text)
{
    unsigned int length = 0;

    while (text[length])
        length++;

    return length;
}

void nas_print(const char *text)
{
    nas_write(1, text, nas_strlen(text));
}

void nas_print_number(int number)
{
    char buffer[12];
    unsigned int value;
    int pos = 11;

    buffer[pos] = '\0';

    if (number < 0)
        value = (unsigned int)(-(number + 1)) + 1;
    else
        value = (unsigned int)number;

    do {
        buffer[--pos] = '0' + (value % 10);
        value /= 10;
    } while (value);

    if (number < 0)
        buffer[--pos] = '-';

    nas_print(&buffer[pos]);
}

void _start(void)
{
    int server_fd;
    int client_fd;
    int result;

    struct sockaddr_in address = {
        .family = AF_INET,
        .port = 0x15B3,
        .address = 0,
        .zero = {0}
    };

    nas_print("agguro NAS Monitor\n");

    server_fd = sys_socket(AF_INET, SOCK_STREAM, 0);

    if (server_fd < 0) {
        nas_print("socket() failed\n");
        nas_exit(1);
    }

    result = sys_bind(server_fd, &address, sizeof(address));

    if (result < 0) {
        nas_print("bind() failed: ");
        nas_print_number(result);
        nas_print("\n");
        sys_close(server_fd);
        nas_exit(1);
    }

    result = sys_listen(server_fd, 5);

    if (result < 0) {
        nas_print("listen() failed\n");
        sys_close(server_fd);
        nas_exit(1);
    }

    nas_print("Listening on 0.0.0.0:5555\n");

    for (;;) {
        client_fd = sys_accept(server_fd, (void *)0, (void *)0);

        if (client_fd < 0) {
            nas_print("accept() failed: ");
            nas_print_number(client_fd);
            nas_print("\n");
            break;
        }

        http_handle(client_fd);
        sys_close(client_fd);
    }

    sys_close(server_fd);
    nas_exit(1);
}

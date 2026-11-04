
/*
 * agguro NAS Monitor
 * File: src/http.c
 *
 * Build:
 *   make
 *
 * HTTP/1.0 single-request handler.
 */

#include "nasmon.h"

static int write_all(int fd, const char *data, unsigned int length)
{
    unsigned int sent = 0;

    while (sent < length) {
        int n = nas_write(fd, data + sent, length - sent);

        if (n <= 0)
            return -1;

        sent += (unsigned int)n;
    }

    return 0;
}

static int read_request(int fd)
{
    char buffer[HTTP_BUFFER_SIZE];
    unsigned int used = 0;
    unsigned int matched = 0;
    static const char end[] = "\r\n\r\n";

    while (used < sizeof(buffer)) {
        int n = sys_read(fd, buffer + used, 1);
        char c;

        if (n <= 0)
            return -1;

        c = buffer[used++];

        if (c == end[matched]) {
            matched++;

            if (matched == 4)
                return 0;
        } else {
            matched = (c == '\r') ? 1 : 0;
        }
    }

    return -1;
}

static unsigned int append_text(char *destination,
                                unsigned int used,
                                unsigned int capacity,
                                const char *source)
{
    unsigned int i = 0;

    while (source[i] && used + 1 < capacity)
        destination[used++] = source[i++];

    destination[used] = '\0';
    return used;
}

static unsigned int append_number(char *destination,
                                  unsigned int used,
                                  unsigned int capacity,
                                  unsigned int number)
{
    char digits[12];
    unsigned int count = 0;

    do {
        digits[count++] = '0' + (number % 10);
        number /= 10;
    } while (number);

    while (count && used + 1 < capacity)
        destination[used++] = digits[--count];

    destination[used] = '\0';
    return used;
}

void http_handle(int client_fd)
{
    static const char body[] =
        "<!DOCTYPE html>\n"
        "<html lang=\"en\">\n"
        "<head><meta charset=\"UTF-8\">"
        "<title>agguro NAS Monitor</title></head>\n"
        "<body style=\"background:#101820;color:#e5e7eb;"
        "font-family:monospace;padding:40px\">\n"
        "<h1>agguro NAS Monitor</h1>\n"
        "<p>Netgear ReadyNAS Duo</p>\n"
        "<p>Infrant Neon / SPARC V8</p>\n"
        "<p>Native HTTP server without libc.</p>\n"
        "</body></html>\n";

    char header[256];
    unsigned int used = 0;

    if (read_request(client_fd) < 0)
        return;

    used = append_text(header, used, sizeof(header),
                       "HTTP/1.0 200 OK\r\n"
                       "Content-Type: text/html; charset=UTF-8\r\n"
                       "Content-Length: ");

    used = append_number(header, used, sizeof(header),
                         sizeof(body) - 1);

    used = append_text(header, used, sizeof(header),
                       "\r\nConnection: close\r\n\r\n");

    if (write_all(client_fd, header, used) < 0)
        return;

    write_all(client_fd, body, sizeof(body) - 1);
}

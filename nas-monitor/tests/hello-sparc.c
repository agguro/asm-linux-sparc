/*
 * agguro NAS Monitor
 * File: nasmon-test.c
 * Architecture: SPARC V8, 32-bit, big-endian
 * Platform: Linux / Netgear ReadyNAS Duo
 *
 * Cross-compilation (Debian x86-64):
 *
 * sparc64-linux-gnu-gcc \
 *     -m32 -mcpu=v8 \
 *     -O2 -Wall -Wextra \
 *     -ffreestanding \
 *     -fno-stack-protector \
 *     -fno-pie \
 *     -nostdlib \
 *     -no-pie \
 *     -Wl,-e,_start \
 *     -o nasmon-test nasmon-test.c
 *
 * Verify:
 * file nasmon-test
 * sparc64-linux-gnu-readelf -h nasmon-test
 * sparc64-linux-gnu-readelf -l nasmon-test
 *
 * Dependencies: None (direct Linux syscalls)
 */

static inline long sys_write(int fd, const void *buf,
                             unsigned long count)
{
    register long g1 __asm__("g1") = 4;
    register long o0 __asm__("o0") = fd;
    register long o1 __asm__("o1") = (long)buf;
    register long o2 __asm__("o2") = count;

    __asm__ volatile(
        "ta 0x10"
        : "+r"(o0)
        : "r"(g1), "r"(o1), "r"(o2)
        : "cc", "memory"
    );

    return o0;
}

__attribute__((noreturn))
static void sys_exit(int status)
{
    register long g1 __asm__("g1") = 1;
    register long o0 __asm__("o0") = status;

    __asm__ volatile(
        "ta 0x10"
        :
        : "r"(g1), "r"(o0)
        : "cc", "memory"
    );

    __builtin_unreachable();
}

void _start(void)
{
    static const char msg[] =
        "Hello from SPARC Linux!\n";

    sys_write(1, msg, sizeof(msg) - 1);
    sys_exit(0);
}

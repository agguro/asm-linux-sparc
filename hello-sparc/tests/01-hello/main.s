
! SPARC V8 Linux assembly
! Test 001: Write a message to standard output
! Target: NETGEAR ReadyNAS Duo v1 (32-bit SPARC)

.section ".text"
.global _start

_start:
    ! write(1, message, message_length)
    mov 4, %g1
    mov 1, %o0
    set message, %o1
    mov message_length, %o2
    ta 0x10

    ! exit(0)
    mov 1, %g1
    clr %o0
    ta 0x10

.section ".rodata"
message:
    .ascii "Hello from SPARC!\n"
message_length = . - message

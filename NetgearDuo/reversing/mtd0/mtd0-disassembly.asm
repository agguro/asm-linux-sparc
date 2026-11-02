! Netgear ReadyNAS Duo SPARC firmware - uniformly formatted annotated disassembly
! Format: address | four original opcode bytes | SPARC instruction | English comment
! Original opcode bytes and mnemonics are preserved; annotations are updated as evidence improves.
! Long runs of erased 0xFF words are represented as ranges.
!
! Hardware references (GPL: include/asm-sparc/padre0.h,
! arch/sparc/kernel/padre_nand_flash.c):
!   0x20000094 = PADRE_SYS_CTRL
!   0x200000C0 = PADRE_GPIO_DATA
!   0x200000C4 = PADRE_GPIO_DIR
!   0x2000010C = PADRE_PCI_FEATURE (bit 10 used for NAND select)
!   0x08000000 = NAND data aperture (early boot mapping)
!   0x08010000 = NAND command aperture (inferred from writes)
!   0x08020000 = NAND address aperture (inferred from writes)
! NAND page size = 512 bytes; eraseblock size = 16 KiB (32 pages).
! Important: disassembly addresses are FILE OFFSETS; runtime mapping
! and branch interpretation must be verified separately.
! Two similar code regions exist at 0x00200 and 0x0C000; whether
! they form a dual-image boot fallback remains UNPROVEN.

! ------------------------------------------------------------
! 0x000 - 0x1FB: Unused or erased flash region
! ------------------------------------------------------------
!
! 508 bytes containing 0xFF.
! Likely an erased or reserved flash area.
! This region is data, not executable SPARC instructions.
!
! 000: ff ff ff ff
! ...
! 1f8: ff ff ff ff

! ------------------------------------------------------------
! 0x1FC: NAND bad-block table pointer (GPL-source correlation)
! ------------------------------------------------------------
!
! 32-bit big-endian value: 0xDEAD0008.
! GPL NAND code associates this location with a bad-block table pointer.
! Interpreted table block index: 8 (0x20000 with 16 KiB eraseblocks).
! This is data, not a SPARC instruction; do not treat as a generic
! firmware-validity marker without further evidence.

0x001FC    de ad 00 08    

! ------------------------------------------------------------
! 0x200 - 0x24F: Initial trap-table region
! ------------------------------------------------------------
!
! SPARC V8 trap entries occupy 16 bytes each.
! Assuming the table begins at 0x200, this region
! contains trap slots 0 through 4.
!
! The first instruction branches to initialization
! code at 0x2A4. Its delay slot contains a NOP.

0x00200    10 80 00 29    b     0x2a4
0x00204    01 00 00 00    nop

0x00208    01 00 00 00    nop
0x0020C    01 00 00 00    nop

0x00210    01 00 00 00    nop
0x00214    01 00 00 00    nop
0x00218    01 00 00 00    nop
0x0021C    01 00 00 00    nop

0x00220    01 00 00 00    nop
0x00224    01 00 00 00    nop
0x00228    01 00 00 00    nop
0x0022C    01 00 00 00    nop

0x00230    01 00 00 00    nop
0x00234    01 00 00 00    nop
0x00238    01 00 00 00    nop
0x0023C    01 00 00 00    nop

0x00240    01 00 00 00    nop
0x00244    01 00 00 00    nop
0x00248    01 00 00 00    nop
0x0024C    01 00 00 00    nop

! ------------------------------------------------------------
! 0x250 - 0x25F: Register window overflow trap
! ------------------------------------------------------------
!
! Trap type 0x05 (assuming TBR base at 0x200).
! Read the Window Invalid Mask into %l0.
! The RD instruction executes in the branch delay slot.
! Handler entry point: 0x58C.

0x00250    10 80 00 cf    b     0x58c
0x00254    a1 50 00 00    rd    %wim, %l0
0x00258    01 00 00 00    nop
0x0025C    01 00 00 00    nop

! ------------------------------------------------------------
! 0x260 - 0x26F: Register window underflow trap
! ------------------------------------------------------------
!
! Trap type 0x06 (assuming TBR base at 0x200).
! Read WIM into %l0 before entering the handler.
! Handler entry point: 0x5D4.

0x00260    10 80 00 dd    b     0x5d4
0x00264    a1 50 00 00    rd    %wim, %l0
0x00268    01 00 00 00    nop
0x0026C    01 00 00 00    nop

! ------------------------------------------------------------
! 0x270 - 0x2A0: Low-level hardware output routine
! ------------------------------------------------------------
!
! Likely a polling-based serial output routine.
!
! MMIO status register: 0x20000064
! MMIO data register:   0x20000060
!
! Wait until status bit 2 is set.
! Write the value in %l6 to the output register.
! Execute a short delay loop and return.
!
! Note:
! This routine overlaps positions normally reserved
! for additional trap entries. Its exact entry path
! and runtime memory mapping remain unverified.

0x00270    2f 08 00 00    sethi %hi(0x20000000), %l7

0x00274    c2 05 e0 64    ld    [%l7 + 0x64], %g1
0x00278    80 88 60 04    btst  4, %g1
0x0027C    02 bf ff fe    be    0x274
0x00280    01 00 00 00    nop

0x00284    2f 08 00 00    sethi %hi(0x20000000), %l7
0x00288    ec 25 e0 60    st    %l6, [%l7 + 0x60]

! Delay loop: 256 iterations.

0x0028C    ae 10 21 00    mov   0x100, %l7
0x00290    ae a5 e0 01    deccc %l7
0x00294    12 bf ff ff    bne   0x290
0x00298    01 00 00 00    nop

! Return to caller.

0x0029C    81 c3 e0 08    retl
0x002A0    01 00 00 00    nop

! ============================================================
! 0x2A4: Boot initialization
! Existing annotated disassembly continues here.
! ============================================================


! Annotated SPARC firmware disassembly: 0x2A4–0x7B8
! Steps:
! 1. Initialize boot mode, memory-mapped hardware, and CPU state.
! 2. Inspect register-window trap handlers and arithmetic helpers.
! 3. Identify character classification and string conversion helpers.
! Notes: Addresses and machine-code bytes are preserved from the input.
! Labels marked probable/likely are hypotheses, not verified symbols.

! 0x2A4–0x2B0: Reset trap base register
0x002A4    81 98 00 00    wr  %g0, %tbr                          ! TBR = 0 (XOR of two zero registers)
0x002A8    01 00 00 00    nop                                    ! pipeline delay
0x002AC    01 00 00 00    nop                                    ! pipeline delay
0x002B0    01 00 00 00    nop                                    ! pipeline delay

! 0x2B4–0x2D0: Read boot mode from alternate address space
0x002B4    86 10 20 08    mov   8, %g3                           ! g3 = 8
0x002B8    82 10 20 04    mov   4, %g1                           ! g1 = 4
0x002BC    c4 80 42 00    lda   [%g1] #ASI_AIUP, %g2             ! Read 32-bit word
0x002C0    85 30 a0 14    srl   %g2, 0x14, %g2                   ! Shift right 20 bits
0x002C4    84 08 a0 0f    and   %g2, 0xf, %g2                    ! Keep original bits 23-20
0x002C8    80 a0 a0 00    cmp   %g2, 0                           ! Compare with zero
0x002CC    02 80 00 10    be    0x30c                            ! Branch if equal
0x002D0    88 80 28 00    addcc %g0, 0x800, %g4                  ! Delay slot: g4 = 2048

! 0x2D4–0x2D8: Short delay loop
0x002D4    12 80 00 00    bne   0x2d4                            ! Loop while the condition codes indicate nonzero
0x002D8    88 a1 20 01    deccc %g4                              ! Delay slot: decrement counter and update condition codes

! 0x2DC–0x2EC: Dispatch based on boot mode
0x002DC    80 a0 a0 01    cmp  %g2, 1                            ! Compare g2 with 1
0x002E0    02 80 00 04    be   0x2f0                             ! If equal, branch to 0x2F0
0x002E4    80 a0 a0 02    cmp  %g2, 2                            ! Delay slot: compare with 2
0x002E8    02 80 00 04    be   0x2f8                             ! If equal, branch to 0x2F8
0x002EC    01 00 00 00    nop                                    ! Delay slot

! 0x2F0–0x2F4: Halt loop for unsupported mode
0x002F0    10 80 00 00    b    0x2f0                             ! Branch to itself forever
0x002F4    01 00 00 00    nop                                    ! Delay slot

! 0x2F8–0x308: Jump to stored resume address and clear it
0x002F8    03 0c 00 1f    sethi %hi(0x30007c00), %g1             ! Build upper part of saved jump-address location
0x002FC    82 10 63 fc    or    %g1, 0x3fc, %g1                  ! g1 = 0x30007FFC
0x00300    c4 00 40 00    ld    [%g1], %g2                       ! g2 = memory32[g1]
0x00304    81 c0 80 00    jmp   %g2                              ! Jump to address in g2
0x00308    c0 20 40 00    clr   [%g1]                            ! Delay slot: memory32[g1] = 0

! 0x30C–0x318: Initialize controller register 0x20000094
0x0030C    05 08 00 00    sethi %hi(0x20000000), %g2             ! g2 = 0x20000000
0x00310    84 10 a0 94    or    %g2, 0x94, %g2                   ! g2 = 0x20000094
0x00314    03 00 00 18    sethi %hi(0x6000), %g1                 ! g1 = 0x00006000
0x00318    c2 20 80 00    st    %g1, [%g2]                       ! memory32[0x20000094] = 0x6000

! 0x31C–0x328: Initialize controller register 0x200000D4
0x0031C    82 10 20 0c    mov   0xc, %g1                         ! g1 = 12
0x00320    05 08 00 00    sethi %hi(0x20000000), %g2             ! g2 = 0x20000000
0x00324    84 10 a0 d0    or    %g2, 0xd0, %g2                   ! g2 = 0x200000D0
0x00328    c2 20 a0 04    st    %g1, [%g2 + 4]                   ! memory32[0x200000D4] = 12

! 0x32C–0x358: Controller command sequence: first data word
0x0032C    c2 00 a0 10    ld    [%g2 + 0x10], %g1                ! g1 = memory32[0x200000E0]
0x00330    80 88 60 01    btst  1, %g1                           ! Test bit 0 of g1
0x00334    12 bf ff fe    bne   0x32c                            ! Repeat if bit 0 = 1
0x00338    03 02 80 60    sethi %hi(0x0A018000), %g1             ! Delay slot: prepare next data word
0x0033C    c2 20 a0 08    st    %g1, [%g2 + 8]                   ! [0x200000D8] = 0x0A018000
0x00340    03 00 00 0a    sethi %hi(0x2800), %g1                 ! g1 = 0x00002800
0x00344    82 10 62 d2    or    %g1, 0x2d2, %g1                  ! g1 = 0x00002AD2
0x00348    c2 20 a0 00    st    %g1, [%g2]                       ! [0x200000D0] = 0x00002AD2
0x0034C    c2 00 a0 10    ld    [%g2 + 0x10], %g1                ! g1 = [0x200000E0]
0x00350    80 88 60 01    btst  1, %g1                           ! Test bit 0
0x00354    12 bf ff fe    bne   0x34c                            ! Repeat while bit 0 = 1
0x00358    03 00 40 61    sethi %hi(0x1018400), %g1              ! Delay slot: g1 = 0x01018400

! 0x35C–0x37C: Controller command sequence: second data word
0x0035C    82 10 62 00    or    %g1, 0x200, %g1                  ! g1 = 0x01018600
0x00360    c2 20 a0 08    st    %g1, [%g2 + 8]                   ! [0x200000D8] = 0x01018600
0x00364    03 00 00 0a    sethi %hi(0x2800), %g1                 ! g1 = 0x00002800
0x00368    82 10 62 d2    or    %g1, 0x2d2, %g1                  ! g1 = 0x00002AD2
0x0036C    c2 20 a0 00    st    %g1, [%g2]                       ! [0x200000D0] = 0x2AD2
0x00370    c2 00 a0 10    ld    [%g2 + 0x10], %g1                ! Read status at 0x200000E0
0x00374    80 88 60 01    btst  1, %g1                           ! Test status bit 0
0x00378    12 bf ff fe    bne   0x370                            ! Wait while bit 0 is set
0x0037C    03 04 40 47    sethi %hi(0x11011c00), %g1             ! Delay slot: prepare next value

! 0x380–0x39C: Controller command sequence: third data word
0x00380    c2 20 a0 08    st    %g1, [%g2 + 8]                   ! [0x200000D8] = 0x11011C00
0x00384    03 00 00 0a    sethi %hi(0x2800), %g1                 ! g1 = 0x00002800
0x00388    82 10 62 d2    or    %g1, 0x2d2, %g1                  ! g1 = 0x00002AD2
0x0038C    c2 20 a0 00    st    %g1, [%g2]                       ! [0x200000D0] = 0x2AD2
0x00390    c2 00 a0 10    ld    [%g2 + 0x10], %g1                ! Read controller status
0x00394    80 88 60 01    btst  1, %g1                           ! Test bit 0
0x00398    12 bf ff fe    bne   0x390                            ! Wait while bit 0 is set
0x0039C    03 02 c0 62    sethi %hi(0x0B018800), %g1             ! Delay slot: g1 = 0x0B018800

! 0x3A0–0x3C0: Controller command sequence: fourth data word
0x003A0    82 10 63 00    or    %g1, 0x300, %g1                  ! g1 = 0x0B018B00
0x003A4    c2 20 a0 08    st    %g1, [%g2 + 8]                   ! [0x200000D8] = 0x0B018B00
0x003A8    03 00 00 0a    sethi %hi(0x2800), %g1                 ! g1 = 0x00002800
0x003AC    82 10 62 d2    or    %g1, 0x2d2, %g1                  ! g1 = 0x00002AD2
0x003B0    c2 20 a0 00    st    %g1, [%g2]                       ! [0x200000D0] = 0x2AD2
0x003B4    c2 00 a0 10    ld    [%g2 + 0x10], %g1                ! Read controller status
0x003B8    80 88 60 01    btst  1, %g1                           ! Test bit 0
0x003BC    12 bf ff fe    bne   0x3b4                            ! Wait while bit 0 is set
0x003C0    03 03 00 5f    sethi %hi(0x0C017C00), %g1             ! Delay slot: g1 = 0x0C017C00

! 0x3C4–0x3E4: Controller command sequence: fifth data word
0x003C4    82 10 63 00    or    %g1, 0x300, %g1                  ! g1 = 0x0C017F00
0x003C8    c2 20 a0 08    st    %g1, [%g2 + 8]                   ! [0x200000D8] = 0x0C017F00
0x003CC    03 00 00 0a    sethi %hi(0x2800), %g1                 ! g1 = 0x00002800
0x003D0    82 10 62 d2    or    %g1, 0x2d2, %g1                  ! g1 = 0x00002AD2
0x003D4    c2 20 a0 00    st    %g1, [%g2]                       ! [0x200000D0] = 0x2AD2
0x003D8    c2 00 a0 10    ld    [%g2 + 0x10], %g1                ! Read controller status
0x003DC    80 88 60 01    btst  1, %g1                           ! Test bit 0
0x003E0    12 bf ff fe    bne   0x3d8                            ! Wait while bit 0 is set
0x003E4    03 02 c0 62    sethi %hi(0x0B018800), %g1             ! Delay slot: g1 = 0x0B018800

! 0x3E8–0x3F4: Controller command sequence: sixth data word
0x003E8    c2 20 a0 08    st    %g1, [%g2 + 8]                   ! [0x200000D8] = 0x0B018800
0x003EC    03 00 00 0a    sethi %hi(0x2800), %g1                 ! g1 = 0x00002800
0x003F0    82 10 62 d2    or    %g1, 0x2d2, %g1                  ! g1 = 0x00002AD2
0x003F4    c2 20 a0 00    st    %g1, [%g2]                       ! [0x200000D0] = 0x2AD2

! 0x3F8–0x408: Initialize processor status register (PSR)
0x003F8    84 10 21 c0    mov   0x1c0, %g2                       ! g2 = 0x000001C0
0x003FC    81 88 a0 00    wr    %g2, %psr                        ! PSR = g2 XOR 0 = 0x1C0
0x00400    01 00 00 00    nop                                    ! PSR write delay
0x00404    01 00 00 00    nop                                    ! PSR write delay
0x00408    01 00 00 00    nop                                    ! PSR write delay

! 0x40C–0x41C: Initialize window invalid mask (WIM)
0x0040C    82 10 20 02    mov   2, %g1                           ! g1 = 0x00000002
0x00410    81 90 60 00    wr    %g1, %wim                        ! WIM = 0x00000002
0x00414    01 00 00 00    nop                                    ! Delay after WIM write
0x00418    01 00 00 00    nop
0x0041C    01 00 00 00    nop

! 0x420–0x42C: Load diagnostic register patterns
0x00420    31 04 8d 15    sethi %hi(0x12345400), %i0             ! Prepare recognizable 32-bit pattern
0x00424    b0 16 22 78    or    %i0, 0x278, %i0                  ! i0 = 0x12345678
0x00428    11 21 d9 50    sethi %hi(0x87654000), %o0             ! Prepare second recognizable 32-bit pattern
0x0042C    90 12 23 21    or    %o0, 0x321, %o0                  ! o0 = 0x87654321

! 0x430–0x434: Write through alternate address space
0x00430    07 00 00 c0    sethi %hi(0x30000), %g3                ! g3 = 0x00030000
0x00434    c0 a0 c2 80    sta   %g0, [%g3] #ASI_PHYS_USE_EC      ! Store zero using alternate address space

! 0x438–0x444: Initialize MMIO registers 0x88 and 0x8C
0x00438    0f 08 00 00    sethi %hi(0x20000000), %g7             ! g7 = 0x20000000
0x0043C    82 10 2f ff    mov   0xfff, %g1                       ! g1 = 0x00000FFF
0x00440    c2 21 e0 88    st    %g1, [%g7 + 0x88]                ! [0x20000088] = 0xFFF
0x00444    c0 21 e0 8c    clr   [%g7 + 0x8c]                     ! [0x2000008C] = 0

! 0x448–0x460: Configure and poll MMIO register 0x80
0x00448    03 01 b6 c1    sethi %hi(0x06DB0400), %g1             ! g1 = 0x06DB0400
0x0044C    82 10 60 01    or    %g1, 1, %g1                      ! g1 = 0x06DB0401
0x00450    c2 21 e0 80    st    %g1, [%g7 + 0x80]                ! [0x20000080] = 0x06DB0401
0x00454    c2 01 e0 80    ld    [%g7 + 0x80], %g1                ! Read [0x20000080]
0x00458    80 88 62 00    btst  0x200, %g1                       ! Test bit 9
0x0045C    02 bf ff fe    be    0x454                            ! Repeat while bit 9 = 0
0x00460    01 00 00 00    nop                                    ! Branch delay slot

! 0x464–0x47C: Clear control register and write alternate-space values
0x00464    c0 21 e0 80    clr   [%g7 + 0x80]                     ! [0x20000080] = 0
0x00468    07 00 00 c0    sethi %hi(0x30000), %g3                ! g3 = 0x00030000
0x0046C    84 10 20 01    mov   1, %g2                           ! g2 = 1
0x00470    c4 a0 c2 80    sta   %g2, [%g3] #ASI_PHYS_USE_EC      ! Alternate-space store: 1 at 0x30000
0x00474    86 10 20 1c    mov   0x1c, %g3                        ! g3 = 0x1C
0x00478    05 1e 00 00    sethi %hi(0x78000000), %g2             ! g2 = 0x78000000
0x0047C    c4 a0 c2 00    sta   %g2, [%g3] #ASI_AIUP             ! Alternate-space store at 0x1C

! 0x480–0x4B4: Initialize additional MMIO registers
0x00480    03 08 00 00    sethi %hi(0x20000000), %g1             ! g1 = 0x20000000
0x00484    82 10 60 1c    or    %g1, 0x1c, %g1                   ! g1 = 0x2000001C
0x00488    88 10 3f ff    mov   -1, %g4                          ! g4 = 0xFFFFFFFF
0x0048C    c8 20 40 00    st    %g4, [%g1]                       ! [0x2000001C] = 0xFFFFFFFF
0x00490    03 08 00 00    sethi %hi(0x20000000), %g1             ! g1 = 0x20000000
0x00494    82 10 60 18    or    %g1, 0x18, %g1                   ! g1 = 0x20000018
0x00498    c8 20 40 00    st    %g4, [%g1]                       ! [0x20000018] = 0xFFFFFFFF
0x0049C    03 08 00 00    sethi %hi(0x20000000), %g1             ! g1 = 0x20000000
0x004A0    82 10 60 04    or    %g1, 4, %g1                      ! g1 = 0x20000004
0x004A4    09 20 00 00    sethi %hi(0x80000000), %g4             ! g4 = 0x80000000
0x004A8    c0 20 40 00    clr   [%g1]                            ! [0x20000004] = 0
0x004AC    03 08 00 00    sethi %hi(0x20000000), %g1             ! g1 = 0x20000000
0x004B0    88 10 24 00    mov   0x400, %g4                       ! g4 = 0x400
0x004B4    c0 20 40 00    clr   [%g1]                            ! [0x20000000] = 0

! 0x4B8–0x4C8: Program MMIO register 0xC4
! Hardware mapping: PADRE_GPIO_DIR at 0x200000C4;
! PADRE_GPIO_DATA at 0x200000C0. Data toggles bit 15 between
! 0x000C0000 and 0x000C8000; attached signal is unidentified.
0x004B8    21 08 00 00    sethi %hi(0x20000000), %l0             ! l0 = 0x20000000
0x004BC    a0 14 20 c4    or    %l0, 0xc4, %l0                   ! l0 = 0x200000C4
0x004C0    23 00 00 2f    sethi %hi(0xbc00), %l1                 ! l1 = 0x0000BC00
0x004C4    a2 14 63 00    or    %l1, 0x300, %l1                  ! l1 = 0x0000BF00
0x004C8    e2 24 00 00    st    %l1, [%l0]                       ! [0x200000C4] = 0xBF00

! 0x4CC–0x4E8: Program MMIO register 0xC0 and delay
0x004CC    21 08 00 00    sethi %hi(0x20000000), %l0             ! l0 = 0x20000000
0x004D0    a0 14 20 c0    or    %l0, 0xc0, %l0                   ! l0 = 0x200000C0
0x004D4    23 00 03 00    sethi %hi(0xc0000), %l1                ! l1 = 0x000C0000
0x004D8    e2 24 00 00    st    %l1, [%l0]                       ! [0x200000C0] = 0xC0000
0x004DC    23 00 00 40    sethi %hi(0x10000), %l1                ! l1 = 0x00010000
0x004E0    a2 a4 60 01    deccc %l1                              ! Decrement l1, update condition codes
0x004E4    12 80 00 00    bne   0x4e4                            ! Delay loop
0x004E8    a2 a4 60 01    deccc %l1                              ! Delay slot: decrement again

! 0x4EC–0x500: Update MMIO register 0xC0 and delay
0x004EC    23 00 03 20    sethi %hi(0xc8000), %l1                ! l1 = 0x000C8000
0x004F0    e2 24 00 00    st    %l1, [%l0]                       ! [0x200000C0] = 0xC8000
0x004F4    23 00 00 40    sethi %hi(0x10000), %l1                ! l1 = 0x00010000
0x004F8    a2 a4 60 01    deccc %l1                              ! Decrement l1, update condition codes
0x004FC    12 80 00 00    bne   0x4fc                            ! Delay loop
0x00500    a2 a4 60 01    deccc %l1                              ! Delay slot: decrement again

! 0x504–0x530: Program MMIO registers 0x6C, 0x68, and 0x64
0x00504    a2 10 20 40    mov   0x40, %l1                        ! l1 = 0x40
0x00508    21 08 00 00    sethi %hi(0x20000000), %l0             ! l0 = 0x20000000
0x0050C    a0 14 20 6c    or    %l0, 0x6c, %l0                   ! l0 = 0x2000006C
0x00510    e2 24 00 00    st    %l1, [%l0]                       ! [0x2000006C] = 0x40
0x00514    21 08 00 00    sethi %hi(0x20000000), %l0             ! l0 = 0x20000000
0x00518    a0 14 20 68    or    %l0, 0x68, %l0                   ! l0 = 0x20000068
0x0051C    a2 10 23 03    mov   0x303, %l1                       ! l1 = 0x303
0x00520    e2 24 00 00    st    %l1, [%l0]                       ! [0x20000068] = 0x303
0x00524    21 08 00 00    sethi %hi(0x20000000), %l0             ! l0 = 0x20000000
0x00528    a0 14 20 64    or    %l0, 0x64, %l0                   ! l0 = 0x20000064
0x0052C    a2 10 20 0f    mov   0xf, %l1                         ! l1 = 0xF
0x00530    e2 24 00 00    st    %l1, [%l0]                       ! [0x20000064] = 0xF

! 0x534–0x544: Initialize stack pointer and frame pointer
0x00534    03 0c 00 00    sethi %hi(0x30000000), %g1             ! g1 = 0x30000000
0x00538    05 00 00 1f    sethi %hi(0x7c00), %g2                 ! g2 = 0x00007C00
0x0053C    84 10 a3 80    or    %g2, 0x380, %g2                  ! g2 = 0x00007F80
0x00540    9c 00 40 02    add   %g1, %g2, %sp                    ! sp = 0x30007F80
0x00544    bc 10 00 0e    mov   %sp, %fp                         ! fp = sp

! 0x548–0x55C: Set trap base register to 0x30000000
0x00548    07 0c 00 00    sethi %hi(0x30000000), %g3             ! g3 = 0x30000000
0x0054C    86 10 e0 00    mov   %g3, %g3                         ! Copy g3 to itself (no state change)
0x00550    81 98 e0 00    wr    %g3, %tbr                        ! Trap base = 0x30000000
0x00554    01 00 00 00    nop                                    ! Delay after TBR write
0x00558    01 00 00 00    nop
0x0055C    01 00 00 00    nop

! 0x560–0x580: Update processor status and trap enable bit
0x00560    87 48 00 00    rd    %psr, %g3                        ! Read PSR
0x00564    81 88 e0 00    wr    %g3, %psr                        ! Rewrite PSR unchanged
0x00568    01 00 00 00    nop
0x0056C    01 00 00 00    nop
0x00570    01 00 00 00    nop
0x00574    81 88 e0 20    wr    %g3, 0x20, %psr                  ! PSR = old PSR XOR 0x20
0x00578    01 00 00 00    nop
0x0057C    01 00 00 00    nop
0x00580    01 00 00 00    nop

! 0x584–0x588: Call initialization routine at 0x37FC
0x00584    40 00 0c 9e    call  0x37fc                           ! Call initialization routine
0x00588    01 00 00 00    nop                                    ! Call delay slot

! 0x58C–0x5D0: Probable register-window overflow trap handler
0x0058C    a6 10 00 01    mov     %g1, %l3                       ! Preserve g1 in l3
0x00590    83 34 20 01    srl     %l0, 1, %g1                    ! g1 = l0 >> 1
0x00594    a1 2c 20 07    sll     %l0, 7, %l0                    ! l0 = l0 << 7
0x00598    82 14 00 01    or      %l0, %g1, %g1                  ! Combine shifted values
0x0059C    81 e0 00 00    save                                   ! Switch to next register window
0x005A0    81 90 40 00    wr      %g1, %wim                      ! Set WIM using computed mask
0x005A4    e0 3b a0 00    std     %l0, [%sp]                     ! Store l0 and l1
0x005A8    e4 3b a0 08    std     %l2, [%sp + 8]                 ! Store l2 and l3
0x005AC    e8 3b a0 10    std     %l4, [%sp + 0x10]              ! Store l4 and l5
0x005B0    ec 3b a0 18    std     %l6, [%sp + 0x18]              ! Store l6 and l7
0x005B4    f0 3b a0 20    std     %i0, [%sp + 0x20]              ! Store i0 and i1
0x005B8    f4 3b a0 28    std     %i2, [%sp + 0x28]              ! Store i2 and i3
0x005BC    f8 3b a0 30    std     %i4, [%sp + 0x30]              ! Store i4 and i5
0x005C0    fc 3b a0 38    std     %fp, [%sp + 0x38]              ! Store i6 and i7
0x005C4    81 e8 00 00    restore                                ! Return to previous window
0x005C8    82 10 00 13    mov     %l3, %g1                       ! Restore original g1
0x005CC    81 c4 40 00    jmp     %l1                            ! Jump to address in l1
0x005D0    81 cc 80 00    rett    %l2                            ! Trap return in jump delay slot

! 0x5D4–0x5F0: Rotate WIM and move to saved register window
0x005D4    a7 2c 20 01    sll     %l0, 1, %l3                    ! l3 = l0 << 1
0x005D8    a1 34 20 07    srl     %l0, 7, %l0                    ! l0 = l0 >> 7
0x005DC    81 94 00 13    wr      %l0, %l3, %wim                 ! WIM = l0 XOR l3
0x005E0    01 00 00 00    nop                                    ! WIM write delay
0x005E4    01 00 00 00    nop
0x005E8    01 00 00 00    nop
0x005EC    81 e8 00 00    restore                                ! Move to previous window
0x005F0    81 e8 00 00    restore                                ! Move to previous window again

! 0x5F4–0x610: Reload register window from stack
0x005F4    e0 1b a0 00    ldd     [%sp], %l0                     ! Restore l0 and l1
0x005F8    e4 1b a0 08    ldd     [%sp + 8], %l2                 ! Restore l2 and l3
0x005FC    e8 1b a0 10    ldd     [%sp + 0x10], %l4              ! Restore l4 and l5
0x00600    ec 1b a0 18    ldd     [%sp + 0x18], %l6              ! Restore l6 and l7
0x00604    f0 1b a0 20    ldd     [%sp + 0x20], %i0              ! Restore i0 and i1
0x00608    f4 1b a0 28    ldd     [%sp + 0x28], %i2              ! Restore i2 and i3
0x0060C    f8 1b a0 30    ldd     [%sp + 0x30], %i4              ! Restore i4 and i5
0x00610    fc 1b a0 38    ldd     [%sp + 0x38], %fp              ! Restore i6 and i7

! 0x614–0x620: Restore register window and return from trap
0x00614    81 e0 00 00    save                                   ! Move to next register window
0x00618    81 e0 00 00    save                                   ! Move to next register window again
0x0061C    81 c4 40 00    jmp     %l1                            ! Restore saved PC
0x00620    81 cc 80 00    rett    %l2                            ! Trap return in jump delay slot

! 0x624–0x648: Signed division helper
0x00624    95 3a 20 1f    sra     %o0, 0x1f, %o2                 ! o2 = 0xFFFFFFFF if o0 < 0, otherwise 0
0x00628    81 82 a0 00    wr      %o2, %y                        ! Y = sign extension of dividend
0x0062C    01 00 00 00    nop                                    ! Y write latency
0x00630    01 00 00 00    nop
0x00634    01 00 00 00    nop
0x00638    90 fa 00 09    sdivcc  %o0, %o1, %o0                  ! Signed quotient; update condition codes
0x0063C    2e 80 00 02    bvs,a   0x644                          ! Branch if overflow; annul delay slot if not taken
0x00640    90 3a 00 00    xnor    %o0, %g0, %o0                  ! Executed only if overflow: o0 = ~o0
0x00644    81 c3 e0 08    retl                                   ! Return to caller
0x00648    01 00 00 00    nop                                    ! Return delay slot

! 0x64C–0x65C: Unsigned division helper
0x0064C    81 80 20 00    wr    %g0, %y                          ! Y = 0
0x00650    01 00 00 00    nop                                    ! Y write latency
0x00654    01 00 00 00    nop
0x00658    81 c3 e0 08    retl                                   ! Return to caller
0x0065C    90 72 00 09    udiv  %o0, %o1, %o0                    ! Delay slot: unsigned quotient

! 0x660–0x674: Signed multiplication helper (entry likely 0x66C)
0x00660    01 00 00 00    nop                                    ! Padding or scheduling NOP (purpose unconfirmed)
0x00664    01 00 00 00    nop                                    ! Padding or scheduling NOP (purpose unconfirmed)
0x00668    01 00 00 00    nop                                    ! Padding or scheduling NOP (purpose unconfirmed)
0x0066C    90 5a 00 09    smul  %o0, %o1, %o0                    ! Signed multiplication, low 32 bits in o0
0x00670    81 c3 e0 08    retl                                   ! Return
0x00674    93 40 00 00    rd    %y, %o1                          ! Delay slot: read upper 32 bits

! 0x678–0x68C: Unsigned multiplication helper (entry likely 0x684)
0x00678    01 00 00 00    nop                                    ! Padding or scheduling NOP (purpose unconfirmed)
0x0067C    01 00 00 00    nop                                    ! Padding or scheduling NOP (purpose unconfirmed)
0x00680    01 00 00 00    nop                                    ! Padding or scheduling NOP (purpose unconfirmed)
0x00684    90 52 00 09    umul  %o0, %o1, %o0                    ! Unsigned multiplication
0x00688    81 c3 e0 08    retl                                   ! Return
0x0068C    93 40 00 00    rd    %y, %o1                          ! Delay slot: read upper 32 bits

! 0x690–0x6BC: Signed remainder helper (entry likely 0x694)
0x00690    01 00 00 00    nop                                    ! Padding or scheduling NOP (purpose unconfirmed)
0x00694    99 3a 20 1f    sra     %o0, 0x1f, %o4                 ! Sign extension
0x00698    81 83 20 00    wr      %o4, %y                        ! Y = sign extension
0x0069C    01 00 00 00    nop
0x006A0    01 00 00 00    nop
0x006A4    01 00 00 00    nop
0x006A8    94 fa 00 09    sdivcc  %o0, %o1, %o2                  ! o2 = signed quotient
0x006AC    2e 80 00 02    bvs,a   0x6b4                          ! Branch if overflow
0x006B0    94 3a 80 00    xnor    %o2, %g0, %o2                  ! Overflow correction
0x006B4    94 5a 80 09    smul    %o2, %o1, %o2                  ! o2 = quotient * divisor
0x006B8    81 c3 e0 08    retl                                   ! Return
0x006BC    90 22 00 0a    sub     %o0, %o2, %o0                  ! Delay slot: remainder

! 0x6C0–0x6E0: Unsigned remainder helper (entry likely 0x6C4)
0x006C0    01 00 00 00    nop                                    ! Padding or scheduling NOP (purpose unconfirmed)
0x006C4    81 80 20 00    wr    %g0, %y                          ! Y = 0
0x006C8    01 00 00 00    nop
0x006CC    01 00 00 00    nop
0x006D0    01 00 00 00    nop
0x006D4    94 72 00 09    udiv  %o0, %o1, %o2                    ! Unsigned quotient
0x006D8    94 52 80 09    umul  %o2, %o1, %o2                    ! quotient * divisor
0x006DC    81 c3 e0 08    retl                                   ! Return
0x006E0    90 22 00 0a    sub  %o0, %o2, %o0                     ! Return delay slot: remainder = dividend - quotient * divisor

! 0x6E4–0x6FC: Compare bytes from two strings
0x006E4    c6 0a 40 00    ldub  [%o1], %g3                       ! g3 = unsigned byte from string 2
0x006E8    d4 0a 00 00    ldub  [%o0], %o2                       ! o2 = unsigned byte from string 1
0x006EC    86 22 80 03    sub   %o2, %g3, %g3                    ! g3 = byte1 - byte2
0x006F0    85 28 e0 18    sll   %g3, 0x18, %g2                   ! g2 = difference << 24
0x006F4    80 a0 a0 00    cmp   %g2, 0                           ! Are the bytes different?
0x006F8    12 80 00 06    bne   0x710                            ! Exit if different
0x006FC    92 02 60 01    inc   %o1                              ! Delay slot: advance string 2

! 0x700–0x70C: Check for string terminator and advance
0x00700    80 a2 a0 00    cmp   %o2, 0                           ! Is byte1 the null terminator?
0x00704    12 bf ff f8    bne   0x6e4                            ! Continue if not zero
0x00708    90 02 20 01    inc   %o0                              ! Delay slot: advance string 1
0x0070C    85 28 e0 18    sll   %g3, 0x18, %g2                   ! Recreate shifted difference

! 0x710–0x718: Return string comparison result
0x00710    80 a0 00 02    cmp   %g0, %g2                         ! Compare 0 with shifted difference
0x00714    81 c3 e0 08    retl                                   ! Return
0x00718    90 60 3f ff    subx  %g0, -1, %o0                     ! Return delay slot: encode comparison sign in o0

! 0x71C–0x72C: Check ASCII decimal digits for hexadecimal classification
0x0071C    84 02 3f d0    add   %o0, -48, %g2                    ! g2 = character - '0'
0x00720    84 08 a0 ff    and   %g2, 0xff, %g2                   ! Keep lowest 8 bits
0x00724    80 a0 a0 09    cmp   %g2, 9                           ! Check range 0..9
0x00728    08 80 00 0b    bleu  0x754                            ! Valid decimal digit
0x0072C    86 10 20 00    clr   %g3                              ! Delay slot: result = 0

! 0x730–0x740: Check lowercase hexadecimal letters
0x00730    84 02 3f 9f    add   %o0, -97, %g2                    ! g2 = character - 'a'
0x00734    84 08 a0 ff    and   %g2, 0xff, %g2                   ! Keep lowest 8 bits
0x00738    80 a0 a0 05    cmp   %g2, 5                           ! Check range 0..5
0x0073C    08 80 00 06    bleu  0x754                            ! Valid lowercase hex letter
0x00740    84 02 3f bf    add   %o0, -65, %g2                    ! Delay slot: g2 = character - 'A'

! 0x744–0x750: Check uppercase hexadecimal letters
0x00744    84 08 a0 ff    and   %g2, 0xff, %g2                   ! Keep lowest 8 bits
0x00748    80 a0 a0 05    cmp   %g2, 5                           ! Check range 0..5
0x0074C    18 80 00 03    bgu   0x758                            ! Invalid if greater than 5
0x00750    01 00 00 00    nop                                    ! Delay slot

! 0x754–0x75C: Return hexadecimal classification result
0x00754    86 10 20 01    mov   1, %g3                           ! Result = 1
0x00758    81 c3 e0 08    retl                                   ! Return to caller
0x0075C    90 10 00 03    mov   %g3, %o0                         ! Delay slot: o0 = result

! 0x760–0x764: Normalize ASCII digit candidate
0x00760    90 02 3f d0    add   %o0, -48, %o0                    ! o0 = character - '0'
0x00764    90 0a 20 ff    and   %o0, 0xff, %o0                   ! Keep lowest 8 bits

! 0x768–0x770: Return decimal digit classification
0x00768    80 a2 20 0a    cmp   %o0, 0xa                         ! Unsigned comparison with 10
0x0076C    81 c3 e0 08    retl                                   ! Return to caller
0x00770    90 40 20 00    addx  %g0, 0, %o0                      ! Return delay slot: convert carry flag to 0 or 1

! 0x774–0x780: Start string-to-integer conversion; check base argument
0x00774    9d e3 bf 98    save  %sp, -104, %sp                   ! Allocate stack frame
0x00778    80 a6 a0 00    cmp   %i2, 0                           ! Check third argument
0x0077C    12 80 00 24    bne   0x80c                            ! Skip prefix detection if nonzero
0x00780    a0 10 20 00    clr   %l0                              ! Delay slot: l0 = 0

! 0x784–0x790: Check leading ASCII zero
0x00784    d0 4e 00 00    ldsb  [%i0], %o0                       ! Read first character (signed byte)
0x00788    80 a2 20 30    cmp   %o0, 0x30                        ! Compare with ASCII '0'
0x0078C    12 80 00 20    bne   0x80c                            ! Skip if not '0'
0x00790    b4 10 20 0a    mov   0xa, %i2                         ! Delay slot: set default decimal base

! 0x794–0x7A4: Check optional hexadecimal prefix
0x00794    b0 06 20 01    inc   %i0                              ! Advance input pointer
0x00798    d0 4e 00 00    ldsb  [%i0], %o0                       ! Read next character
0x0079C    80 a2 20 78    cmp   %o0, 0x78                        ! Compare with ASCII 'x'
0x007A0    12 80 00 1b    bne   0x80c                            ! Skip if not 'x'
0x007A4    b4 10 20 08    mov   8, %i2                           ! Delay slot: select octal base for leading zero

! 0x7A8–0x7B8: Validate digit following hexadecimal prefix
0x007A8    7f ff ff dd    call  0x71c                            ! Call isxdigit-like routine
0x007AC    d0 0e 20 01    ldub  [%i0 + 1], %o0                   ! Delay slot: load character after 'x'
0x007B0    80 a2 20 00    cmp   %o0, 0                           ! Check validator result
0x007B4    02 80 00 16    be    0x80c                            ! Skip if not hexadecimal
0x007B8    01 00 00 00    nop                                    ! Delay slot

! 0x7BC–0x80B: Select numeric base and accumulate digits
! Steps:
! 1. Complete hexadecimal prefix detection.
! 2. Select multiplication by 8, 10, or 16.
! 3. Add the converted digit to the accumulated value.
! 4. Advance the input pointer.

! 0x7BC–0x7C4: Accept hexadecimal prefix
0x007BC    b0 06 20 01    inc  %i0                               ! Advance past 'x'
0x007C0    10 80 00 13    b    0x80c                             ! Continue parsing
0x007C4    b4 10 20 10    mov  0x10, %i2                         ! Delay slot: base = 16

! 0x7C8–0x7FC: Select multiplication by base
0x007C8    02 80 00 0d    be   0x7fc                             ! Base 10: calculate value * 10
0x007CC    93 2c 20 01    sll  %l0, 1, %o1                       ! o1 = value * 2
0x007D0    18 80 00 06    bgu  0x7e8                             ! Base > 10: check for base 16
0x007D4    80 a6 a0 08    cmp  %i2, 8                            ! Delay slot: compare base with 8
0x007D8    02 80 00 0b    be   0x804                             ! Base 8: use value * 8
0x007DC    91 2c 20 03    sll  %l0, 3, %o0                       ! Delay slot: value * 8
0x007E0    10 80 00 0b    b    0x80c                             ! Continue parsing
0x007E4    b0 06 20 01    inc  %i0                               ! Delay slot: advance pointer

! 0x7E8–0x7FC: Handle base 16 or unsupported base
0x007E8    80 a6 a0 10    cmp  %i2, 0x10                         ! Check for base 16
0x007EC    02 80 00 06    be   0x804                             ! Base 16: use value * 16
0x007F0    91 2c 20 04    sll  %l0, 4, %o0                       ! Delay slot: value * 16
0x007F4    10 80 00 06    b    0x80c                             ! Continue parsing
0x007F8    b0 06 20 01    inc  %i0                               ! Delay slot: advance pointer

! 0x7FC–0x80B: Accumulate digit
0x007FC    91 2c 20 03    sll  %l0, 3, %o0                       ! o0 = value * 8
0x00800    90 02 00 09    add  %o0, %o1, %o0                     ! o0 = value * 10
0x00804    a0 02 00 0a    add  %o0, %o2, %l0                     ! Accumulator = product + digit
0x00808    b0 06 20 01    inc  %i0                               ! Advance input pointer

! 0x80C–0x85B: Read and convert the next ASCII digit
! Steps:
! 1. Check whether the character is hexadecimal.
! 2. Distinguish decimal digits from alphabetic digits.
! 3. Convert ASCII to a numeric value.
! 4. Compare the digit with the selected base.
! 5. Repeat while the digit is valid.

! 0x80C–0x81C: Validate input character
0x0080C    7f ff ff c4    call  0x71c                            ! Check hexadecimal character
0x00810    d0 0e 00 00    ldub  [%i0], %o0                       ! Delay slot: load character
0x00814    80 a2 20 00    cmp   %o0, 0                           ! Check validator result
0x00818    02 80 00 12    be    0x860                            ! Stop if invalid
0x0081C    80 a6 60 00    cmp   %i1, 0                           ! Delay slot: test end-pointer argument

! 0x820–0x83C: Check decimal digit
0x00820    7f ff ff d0    call  0x760                            ! Check decimal digit
0x00824    d0 0e 00 00    ldub  [%i0], %o0                       ! Delay slot: load character
0x00828    80 a2 20 00    cmp   %o0, 0                           ! Check isdigit result
0x0082C    22 80 00 05    be,a  0x840                            ! Branch to letter conversion
0x00830    d0 0e 00 00    ldub  [%i0], %o0                       ! Annulled delay slot if not taken
0x00834    d0 4e 00 00    ldsb  [%i0], %o0                       ! Load signed ASCII byte
0x00838    10 80 00 06    b     0x850                            ! Skip alphabetic conversion
0x0083C    94 02 3f d0    add   %o0, -48, %o2                    ! Delay slot: digit = ASCII - '0'

! 0x840–0x84C: Convert hexadecimal letter
0x00840    90 0a 3f df    and  %o0, -33, %o0                     ! Clear ASCII lowercase bit
0x00844    91 2a 20 18    sll  %o0, 0x18, %o0                    ! Shift left 24 bits
0x00848    91 3a 20 18    sra  %o0, 0x18, %o0                    ! Sign-extend low byte
0x0084C    94 02 3f c9    add  %o0, -55, %o2                     ! 'A' -> 10, ..., 'F' -> 15

! 0x850–0x85B: Check digit against base
0x00850    80 a2 80 1a    cmp  %o2, %i2                          ! Compare digit with base
0x00854    0a bf ff dd    bcs  0x7c8                             ! Continue if digit < base
0x00858    80 a6 a0 0a    cmp  %i2, 0xa                          ! Delay slot: compare base with 10
0x0085C    80 a6 60 00    cmp  %i1, 0                            ! Check end-pointer argument
! 0x85C–0x86C: Store end pointer and return parsed value
! Steps:
! 1. Check whether an end-pointer address was supplied.
! 2. Store the current input position when requested.
! 3. Restore the caller's register window.
! 4. Return the accumulated integer.

0x0085C    80 a6 60 00    cmp      %i1, 0                        ! Is endptr NULL?
0x00860    32 80 00 02    bne,a    0x868                         ! Skip store if NULL
0x00864    f0 26 40 00    st       %i0, [%i1]                    ! Delay slot: *endptr = current pointer
0x00868    81 c7 e0 08    ret                                    ! Return
0x0086C    91 e8 00 10    restore  %g0, %l0, %o0                 ! Delay slot: return accumulator

! 0x870–0x8A8: Signed string-to-integer conversion
! Steps:
! 1. Create a stack frame.
! 2. Read the first character and check for '-'.
! 3. Forward the end-pointer and base arguments.
! 4. Call the unsigned conversion routine at 0x774.
! 5. Negate the result if the input starts with '-'.
! 6. Return the converted integer.

! 0x870–0x884: Initialize arguments and check sign
0x00870    9d e3 bf 98    save  %sp, -104, %sp                   ! Create a 104-byte stack frame
0x00874    d0 4e 00 00    ldsb  [%i0], %o0                       ! Read first input character
0x00878    92 10 00 19    mov   %i1, %o1                         ! Forward end-pointer argument
0x0087C    80 a2 20 2d    cmp   %o0, 0x2d                        ! Compare with ASCII '-'
0x00880    02 80 00 06    be    0x898                            ! Branch if negative
0x00884    94 10 00 1a    mov   %i2, %o2                         ! Delay slot: forward base argument

! 0x888–0x894: Convert nonnegative input
0x00888    7f ff ff bb    call  0x774                            ! Call unsigned conversion routine
0x0088C    90 10 00 18    mov   %i0, %o0                         ! Delay slot: pass original string
0x00890    10 80 00 05    b     0x8a4                            ! Skip negative conversion
0x00894    b0 10 00 08    mov   %o0, %i0                         ! Delay slot: save converted value

! 0x898–0x8A0: Convert negative input
0x00898    7f ff ff b7    call  0x774                            ! Convert digits after '-'
0x0089C    90 06 20 01    add   %i0, 1, %o0                      ! Delay slot: skip minus sign
0x008A0    b0 20 00 08    neg   %o0, %i0                         ! Negate converted value

! 0x8A4–0x8A8: Return result
0x008A4    81 c7 e0 08    ret                                    ! Return to caller
0x008A8    81 e8 00 00    restore                                ! Delay slot: restore register window

! 0x8AC–0x8D4: Output a null-terminated string
! Steps:
! 1. Create a stack frame.
! 2. Load the first character.
! 3. Stop when the null terminator is reached.
! 4. Call the character-output routine at 0x998.
! 5. Advance the pointer and repeat.
! 6. Restore the register window and return.

! 0x8AC–0x8B4: Initialize string traversal
0x008AC    9d e3 bf 98    save  %sp, -104, %sp                   ! Create stack frame
0x008B0    10 80 00 05    b     0x8c4                            ! Jump to initial character test
0x008B4    d0 0e 00 00    ldub  [%i0], %o0                       ! Delay slot: load first character

! 0x8B8–0x8C0: Process one character
0x008B8    40 00 00 38    call  0x998                            ! Call character handler
0x008BC    b0 06 20 01    inc   %i0                              ! Delay slot: advance string pointer
0x008C0    d0 0e 00 00    ldub  [%i0], %o0                       ! Load next character

! 0x8C4–0x8CC: Check for string termination
0x008C4    80 a2 20 00    cmp   %o0, 0                           ! Is current character NUL?
0x008C8    12 bf ff fc    bne   0x8b8                            ! Repeat while character is nonzero
0x008CC    01 00 00 00    nop                                    ! Branch delay slot

! 0x8D0–0x8D4: Return
0x008D0    81 c7 e0 08    ret                                    ! Return to caller
0x008D4    81 e8 00 00    restore                                ! Delay slot: restore register window

! 0x8D8–0x900: Output a string and append a newline
! Steps:
! 1. Create a stack frame.
! 2. Read the first byte of the input string.
! 3. If the first byte is ASCII 8, print the remaining string.
! 4. Output ASCII 10 (line feed).
! 5. Restore the register window and return.

! 0x8D8–0x8E8: Check the first character
0x008D8    9d e3 bf 98    save  %sp, -104, %sp                   ! Create stack frame
0x008DC    d0 0e 00 00    ldub  [%i0], %o0                       ! Read first byte
0x008E0    80 a2 20 08    cmp   %o0, 8                           ! Compare with ASCII BS (0x08)
0x008E4    12 80 00 04    bne   0x8f4                            ! Skip string output if not BS
0x008E8    01 00 00 00    nop                                    ! Branch delay slot

! 0x8EC–0x8F0: Output remaining string
0x008EC    7f ff ff f0    call  0x8ac                            ! Output string starting at input + 1
0x008F0    90 06 20 01    add   %i0, 1, %o0                      ! Delay slot: skip first byte

! 0x8F4–0x900: Output newline and return
0x008F4    40 00 00 29    call  0x998                            ! Call character-output routine
0x008F8    90 10 20 0a    mov   0xa, %o0                         ! Delay slot: ASCII LF (newline)
0x008FC    81 c7 e0 08    ret                                    ! Return to caller
0x00900    81 e8 00 00    restore                                ! Delay slot: restore register window

! 0x904–0x930: Output one hexadecimal digit
! Steps:
! 1. Extract the lowest four bits (one nibble).
! 2. Convert values 0–9 to ASCII '0'–'9'.
! 3. Convert values 10–15 to ASCII 'a'–'f'.
! 4. Send the resulting character to 0x998.
! 5. Return to the caller.

0x00904    9d e3 bf 98    save  %sp, -104, %sp                   ! Create stack frame
0x00908    90 0e 20 0f    and   %i0, 0xf, %o0                    ! Extract low nibble
0x0090C    80 a2 20 09    cmp   %o0, 9                           ! Compare nibble with 9
0x00910    18 80 00 05    bgu   0x924                            ! Branch if value > 9
0x00914    01 00 00 00    nop                                    ! Delay slot

0x00918    40 00 00 20    call  0x998                            ! Output decimal hex digit
0x0091C    90 12 20 30    or    %o0, 0x30, %o0                   ! Delay slot: convert to '0'–'9'
0x00920    30 80 00 03    b,a   0x92c                            ! Unconditional branch, annul slot

0x00924    40 00 00 1d    call  0x998                            ! Output alphabetic hex digit
0x00928    90 02 20 57    add   %o0, 0x57, %o0                   ! Delay slot: convert to 'a'–'f'

0x0092C    81 c7 e0 08    ret                                    ! Return
0x00930    81 e8 00 00    restore                                ! Delay slot

! 0x934–0x94C: Output an 8-bit value as two hexadecimal digits
! Steps:
! 1. Shift the input right by four bits.
! 2. Output the high nibble.
! 3. Output the low nibble.
! 4. Return.

0x00934    9d e3 bf 98    save  %sp, -104, %sp
0x00938    7f ff ff f3    call  0x904                            ! Output high nibble
0x0093C    91 36 20 04    srl   %i0, 4, %o0                      ! Delay slot: input >> 4
0x00940    7f ff ff f1    call  0x904                            ! Output low nibble
0x00944    90 10 00 18    mov   %i0, %o0                         ! Delay slot: original input
0x00948    81 c7 e0 08    ret
0x0094C    81 e8 00 00    restore

! 0x950–0x970: Output a 16-bit value as four hexadecimal digits
! Steps:
! 1. Start at bit position 12.
! 2. Extract and output one nibble.
! 3. Decrease shift by four bits.
! 4. Repeat through bit position zero.
! 5. Return.

0x00950    9d e3 bf 98    save  %sp, -104, %sp
0x00954    a0 10 20 0c    mov   0xc, %l0                         ! Shift = 12

0x00958    7f ff ff eb    call  0x904                            ! Output nibble
0x0095C    91 36 00 10    srl   %i0, %l0, %o0                    ! Delay slot: extract nibble
0x00960    a0 84 3f fc    addcc %l0, -4, %l0                     ! Shift -= 4
0x00964    1c bf ff fd    bpos  0x958                            ! Repeat while shift >= 0
0x00968    01 00 00 00    nop

0x0096C    81 c7 e0 08    ret
0x00970    81 e8 00 00    restore

! 0x974–0x994: Output a 32-bit value as eight hexadecimal digits
! Steps:
! 1. Start at bit position 28.
! 2. Extract and output each nibble from most to least significant.
! 3. Decrease shift by four bits.
! 4. Stop after all eight digits.
! 5. Return.

0x00974    9d e3 bf 98    save  %sp, -104, %sp
0x00978    a0 10 20 1c    mov   0x1c, %l0                        ! Shift = 28

0x0097C    7f ff ff e2    call  0x904                            ! Output nibble
0x00980    91 36 00 10    srl   %i0, %l0, %o0                    ! Delay slot: extract nibble
0x00984    a0 84 3f fc    addcc %l0, -4, %l0                     ! Shift -= 4
0x00988    1c bf ff fd    bpos  0x97c                            ! Repeat while shift >= 0
0x0098C    01 00 00 00    nop

0x00990    81 c7 e0 08    ret
0x00994    81 e8 00 00    restore

! 0x998–0x9F0: Polled character output with LF-to-CRLF conversion
! Steps:
! 1. Extract the lowest eight bits of the character.
! 2. Check whether the character is LF (0x0A).
! 3. If LF, wait for transmitter readiness and output CR (0x0D).
! 4. Wait for transmitter readiness again.
! 5. Write the original character to the data register.
! 6. Return.

! 0x998–0x9A4: Check for line feed
0x00998    84 0a 20 ff    and   %o0, 0xff, %g2
0x0099C    80 a0 a0 0a    cmp   %g2, 0xa
0x009A0    12 80 00 0b    bne   0x9cc
0x009A4    05 08 00 00    sethi %hi(0x20000000), %g2

! 0x9A8–0x9C8: Output carriage return before line feed
0x009A8    86 10 a0 64    or    %g2, 0x64, %g3                   ! Status register address
0x009AC    c4 00 c0 00    ld    [%g3], %g2                       ! Read status
0x009B0    80 88 a0 04    btst  4, %g2                           ! Test status bit 2
0x009B4    02 bf ff fe    be    0x9ac                            ! Wait until bit 2 is set
0x009B8    05 08 00 00    sethi %hi(0x20000000), %g2             ! Delay slot
0x009BC    84 10 a0 60    or    %g2, 0x60, %g2                   ! Data register address
0x009C0    86 10 20 0d    mov   0xd, %g3                         ! ASCII CR
0x009C4    c6 20 80 00    st    %g3, [%g2]                       ! Write CR
0x009C8    05 08 00 00    sethi %hi(0x20000000), %g2

! 0x9CC–0x9E8: Output original character
0x009CC    86 10 a0 64    or    %g2, 0x64, %g3                   ! Status register address
0x009D0    90 0a 20 ff    and   %o0, 0xff, %o0                   ! Keep lowest byte
0x009D4    c4 00 c0 00    ld    [%g3], %g2                       ! Read status
0x009D8    80 88 a0 04    btst  4, %g2                           ! Test status bit 2
0x009DC    02 bf ff fe    be    0x9d4                            ! Wait until ready
0x009E0    05 08 00 00    sethi %hi(0x20000000), %g2             ! Delay slot
0x009E4    84 10 a0 60    or    %g2, 0x60, %g2                   ! Data register address
0x009E8    d0 20 80 00    st    %o0, [%g2]                       ! Write character

! 0x9EC–0x9F0: Return
0x009EC    81 c3 e0 08    retl
0x009F0    01 00 00 00    nop

! 0x9F4–0xA14: Erase one character on a terminal
! Steps:
! 1. Send backspace (0x08).
! 2. Send a space (0x20).
! 3. Send backspace again.
! 4. Return.

0x009F4    9d e3 bf 98    save  %sp, -104, %sp
0x009F8    7f ff ff e8    call  0x998
0x009FC    90 10 20 08    mov   8, %o0
0x00A00    7f ff ff e6    call  0x998
0x00A04    90 10 20 20    mov   0x20, %o0
0x00A08    7f ff ff e4    call  0x998
0x00A0C    90 10 20 08    mov   8, %o0
0x00A10    81 c7 e0 08    ret
0x00A14    81 e8 00 00    restore

! 0xA18–0xA78: Poll serial-interface status bits
! Steps:
! 1. Initialize MMIO base and a counter limit.
! 2. Wait until status bit 2 is set.
! 3. Wait until status bit 7 is set.
! 4. Wait until status bit 1 is set.
! 5. Repeat until the counter exceeds 0x1387.
! 6. Return.

! 0xA18–0xA30: Initialize addresses and counter
0x00A18    07 08 00 00    sethi %hi(0x20000000), %g3
0x00A1C    05 00 00 04    sethi %hi(0x1000), %g2
0x00A20    94 10 00 03    mov   %g3, %o2
0x00A24    96 10 a3 87    or    %g2, 0x387, %o3                  ! Limit = 0x1387
0x00A28    86 10 e0 64    or    %g3, 0x64, %g3                   ! Status address
0x00A2C    84 10 20 00    clr   %g2
0x00A30    92 00 a0 01    add   %g2, 1, %o1                      ! Counter = 1

! 0xA34–0xA40: Wait for bit 2
0x00A34    c4 00 c0 00    ld    [%g3], %g2
0x00A38    80 88 a0 04    btst  4, %g2
0x00A3C    02 bf ff fe    be    0xa34
0x00A40    90 12 a0 64    or    %o2, 0x64, %o0

! 0xA44–0xA50: Wait for bit 7
0x00A44    c4 02 00 00    ld    [%o0], %g2
0x00A48    80 88 a0 80    btst  0x80, %g2
0x00A4C    02 bf ff fe    be    0xa44
0x00A50    01 00 00 00    nop

! 0xA54–0xA64: Wait for bit 1
0x00A54    90 12 a0 64    or    %o2, 0x64, %o0
0x00A58    c4 02 00 00    ld    [%o0], %g2
0x00A5C    80 88 a0 02    btst  2, %g2
0x00A60    02 bf ff fe    be    0xa58
0x00A64    84 10 00 09    mov   %o1, %g2

! 0xA68–0xA78: Check repetition count
0x00A68    80 a0 80 0b    cmp   %g2, %o3
0x00A6C    04 bf ff f2    ble   0xa34
0x00A70    92 00 a0 01    add   %g2, 1, %o1
0x00A74    81 c3 e0 08    retl
0x00A78    01 00 00 00    nop

! 0xA7C–0xA94: Initialize argument parsing
! Steps:
! 1. Clear the argument counter.
! 2. Check whether the maximum argument index is exceeded.
! 3. Load the current input character.
! 4. Remember the current input position.

0x00A7C    86 10 20 00    clr   %g3                              ! Argument count = 0
0x00A80    80 a0 c0 0a    cmp   %g3, %o2                         ! Compare count with limit
0x00A84    34 80 00 27    bg,a  0xb20                            ! Return -1 if count > limit
0x00A88    90 10 3f ff    mov   -1, %o0                          ! Annulled delay slot if not taken
0x00A8C    c4 4a 00 00    ldsb  [%o0], %g2                       ! Read current character
0x00A90    10 80 00 03    b     0xa9c                            ! Enter whitespace check
0x00A94    96 10 00 08    mov   %o0, %o3                         ! Save current pointer

! 0xA98–0xAB8: Skip spaces and horizontal tabs
! Steps:
! 1. Read the current character.
! 2. Stop on NUL.
! 3. Advance past ASCII space or tab.
! 4. Stop at the first non-whitespace character.

0x00A98    c4 4a 00 00    ldsb  [%o0], %g2
0x00A9C    80 a0 a0 00    cmp   %g2, 0
0x00AA0    02 80 00 07    be    0xabc
0x00AA4    80 a0 a0 20    cmp   %g2, 0x20
0x00AA8    22 bf ff fc    be,a  0xa98
0x00AAC    90 02 20 01    inc   %o0
0x00AB0    80 a0 a0 09    cmp   %g2, 9
0x00AB4    22 bf ff f9    be,a  0xa98
0x00AB8    90 02 20 01    inc   %o0

! 0xABC–0xAD8: Terminate previous token and check for end of input
! Steps:
! 1. Check whether a previous token exists.
! 2. Replace its separator with NUL.
! 3. Check whether the current character is NUL.
! 4. Return the count when no more tokens remain.

0x00ABC    80 a0 e0 00    cmp   %g3, 0
0x00AC0    02 80 00 03    be    0xacc
0x00AC4    c4 0a 00 00    ldub  [%o0], %g2
0x00AC8    c0 2a c0 00    clrb  [%o3]
0x00ACC    85 28 a0 18    sll   %g2, 0x18, %g2
0x00AD0    80 a0 a0 00    cmp   %g2, 0
0x00AD4    02 80 00 12    be    0xb1c
0x00AD8    85 28 e0 02    sll   %g3, 2, %g2

! 0xADC–0xAE8: Store the next argument pointer
! Steps:
! 1. Calculate argument index multiplied by four.
! 2. Store the current string pointer.
! 3. Increment argument count.

0x00ADC    d0 22 40 02    st    %o0, [%o1 + %g2]                 ! argv[argc] = p
0x00AE0    c4 4a 00 00    ldsb  [%o0], %g2                       ! Read first token character
0x00AE4    10 80 00 03    b     0xaf0
0x00AE8    86 00 e0 01    inc   %g3                              ! argc++

! 0xAEC–0xB08: Scan to the end of the current token
! Steps:
! 1. Read the next character.
! 2. Stop on NUL, space, or tab.
! 3. Otherwise advance and repeat.

0x00AEC    c4 4a 00 00    ldsb  [%o0], %g2
0x00AF0    80 a0 a0 00    cmp   %g2, 0
0x00AF4    02 80 00 06    be    0xb0c
0x00AF8    80 a0 a0 20    cmp   %g2, 0x20
0x00AFC    02 80 00 04    be    0xb0c
0x00B00    80 a0 a0 09    cmp   %g2, 9
0x00B04    32 bf ff fa    bne,a  0xaec
0x00B08    90 02 20 01    inc   %o0


! 0xB0C–0xB24: Continue parsing or return argument count
! Steps:
! 1. Check whether the token ended at NUL.
! 2. If not, repeat the outer loop.
! 3. Otherwise return the number of arguments.

0x00B0C    c4 4a 00 00    ldsb  [%o0], %g2
0x00B10    80 a0 a0 00    cmp   %g2, 0
0x00B14    12 bf ff dc    bne   0xa84
0x00B18    80 a0 c0 0a    cmp   %g3, %o2                         ! Delay slot: compare count with limit
0x00B1C    90 10 00 03    mov   %g3, %o0                         ! Return argument count
0x00B20    81 c3 e0 08    retl
0x00B24    01 00 00 00    nop

! 0xB28–0xBC0: Read an interactive command line
! Steps:
! 1. Initialize the input length to zero.
! 2. Read characters from the serial input routine at 0xBC4.
! 3. Echo ordinary characters and append them to the buffer.
! 4. Handle backspace (0x08), including BEL at an empty line.
! 5. Stop on carriage return (0x0D) or when the buffer is full.
! 6. NUL-terminate the input buffer.
!
! Arguments:
! %i0 = destination buffer
! %i1 = buffer capacity
! %l0 = current input length

0x00B28    9d e3 bf 98    save  %sp, -104, %sp
0x00B2C    10 80 00 09    b     0xb50
0x00B30    a0 10 20 00    clr   %l0
0x00B34    90 0a 60 ff    and   %o1, 0xff, %o0
0x00B38    7f ff ff 98    call  0x998
0x00B3C    a0 04 20 01    inc   %l0
0x00B40    90 06 7f ff    add   %i1, -1, %o0
0x00B44    80 a4 00 08    cmp   %l0, %o0
0x00B48    36 80 00 1d    bge,a 0xbbc
0x00B4C    c0 2e 00 10    clrb  [%i0 + %l0]
0x00B50    40 00 00 1d    call  0xbc4
0x00B54    01 00 00 00    nop
0x00B58    92 10 00 08    mov   %o0, %o1
0x00B5C    91 2a 60 18    sll   %o1, 0x18, %o0
0x00B60    91 3a 20 18    sra   %o0, 0x18, %o0
0x00B64    80 a2 20 08    cmp   %o0, 8
0x00B68    12 80 00 0e    bne   0xba0
0x00B6C    80 a2 20 0d    cmp   %o0, 0xd
0x00B70    80 a4 20 00    cmp   %l0, 0
0x00B74    12 80 00 06    bne   0xb8c
0x00B78    90 10 20 20    mov   0x20, %o0
0x00B7C    7f ff ff 87    call  0x998
0x00B80    90 10 20 07    mov   7, %o0
0x00B84    10 bf ff f0    b     0xb44
0x00B88    90 06 7f ff    add   %i1, -1, %o0
0x00B8C    d0 2e 00 10    stb   %o0, [%i0 + %l0]
0x00B90    7f ff ff 99    call  0x9f4
0x00B94    a0 04 3f ff    add   %l0, -1, %l0
0x00B98    10 bf ff eb    b     0xb44
0x00B9C    90 06 7f ff    add   %i1, -1, %o0
0x00BA0    32 bf ff e5    bne,a 0xb34
0x00BA4    d2 2e 00 10    stb   %o1, [%i0 + %l0]
0x00BA8    7f ff ff 7c    call  0x998
0x00BAC    90 0a 60 ff    and   %o1, 0xff, %o0
0x00BB0    7f ff ff 7a    call  0x998
0x00BB4    90 10 20 0a    mov   0xa, %o0
0x00BB8    c0 2e 00 10    clrb  [%i0 + %l0]
0x00BBC    81 c7 e0 08    ret
0x00BC0    81 e8 00 00    restore

! 0xBC4–0xBF8: Read one character from the serial interface
! Steps:
! 1. Execute a short delay loop.
! 2. Set the status register address to 0x20000064.
! 3. Poll status bit 0 until received data is available.
! 4. Read the data register at 0x20000060.
! 5. Return the received byte in %o0.
!
! Hardware:
! 0x20000064 = probable UART status register
! 0x20000060 = probable UART data register

0x00BC4    84 10 20 63    mov   0x63, %g2
0x00BC8    84 80 bf ff    addcc %g2, -1, %g2
0x00BCC    1c 80 00 00    bpos  0xbcc
0x00BD0    84 80 bf ff    addcc %g2, -1, %g2
0x00BD4    05 08 00 00    sethi %hi(0x20000000), %g2
0x00BD8    86 10 a0 64    or    %g2, 0x64, %g3
0x00BDC    c4 00 c0 00    ld    [%g3], %g2
0x00BE0    80 88 a0 01    btst  1, %g2
0x00BE4    02 bf ff fe    be    0xbdc
0x00BE8    05 08 00 00    sethi %hi(0x20000000), %g2
0x00BEC    84 10 a0 60    or    %g2, 0x60, %g2
0x00BF0    d0 00 80 00    ld    [%g2], %o0
0x00BF4    81 c3 e0 08    retl
0x00BF8    90 0a 20 ff    and   %o0, 0xff, %o0

! 0xBFC–0xC94: Poll serial input for 'i' or 'I'
! Steps:
! 1. Execute a short initial delay.
! 2. Initialize the UART status and data register addresses.
! 3. Poll the receive-ready bit with a timeout counter.
! 4. Read a character and compare it with 'i' (0x69) or 'I' (0x49).
! 5. Return 0 when either character is received.
! 6. Return 0xFF after a timeout or too many other characters.
!
! Hardware:
! 0x20000064 = probable UART status register
! 0x20000060 = probable UART data register
!
! Note:
! The timeout counter and character counter are independent.
! The character counter is checked through its low byte.

0x00BFC    86 10 20 63    mov   0x63, %g3
0x00C00    86 80 ff ff    addcc %g3, -1, %g3
0x00C04    1c 80 00 00    bpos  0xc04
0x00C08    86 80 ff ff    addcc %g3, -1, %g3
0x00C0C    05 08 00 00    sethi %hi(0x20000000), %g2
0x00C10    9a 10 00 02    mov   %g2, %o5
0x00C14    98 10 a0 64    or    %g2, 0x64, %o4
0x00C18    96 10 a0 60    or    %g2, 0x60, %o3
0x00C1C    86 10 20 00    clr   %g3
0x00C20    94 10 20 00    clr   %o2
0x00C24    c4 03 00 00    ld    [%o4], %g2
0x00C28    80 88 a0 01    btst  1, %g2
0x00C2C    12 80 00 0c    bne   0xc5c
0x00C30    01 00 00 00    nop
0x00C34    13 00 01 40    sethi %hi(0x50000), %o1
0x00C38    90 13 60 64    or    %o5, 0x64, %o0
0x00C3C    86 00 e0 01    inc   %g3
0x00C40    80 a0 c0 09    cmp   %g3, %o1
0x00C44    34 80 00 13    bg,a  0xc90
0x00C48    90 10 20 ff    mov   0xff, %o0
0x00C4C    c4 02 00 00    ld    [%o0], %g2
0x00C50    80 88 a0 01    btst  1, %g2
0x00C54    22 bf ff fb    be,a  0xc40
0x00C58    86 00 e0 01    inc   %g3
0x00C5C    c4 02 c0 00    ld    [%o3], %g2
0x00C60    84 08 a0 ff    and   %g2, 0xff, %g2
0x00C64    80 a0 a0 69    cmp   %g2, 0x69
0x00C68    02 80 00 04    be    0xc78
0x00C6C    80 a0 a0 49    cmp   %g2, 0x49
0x00C70    12 80 00 04    bne   0xc80
0x00C74    94 02 a0 01    inc   %o2
0x00C78    10 80 00 06    b     0xc90
0x00C7C    90 10 20 00    clr   %o0
0x00C80    84 0a a0 ff    and   %o2, 0xff, %g2
0x00C84    80 a0 a0 02    cmp   %g2, 2
0x00C88    08 bf ff e7    bleu  0xc24
0x00C8C    90 10 20 ff    mov   0xff, %o0
0x00C90    81 c3 e0 08    retl
0x00C94    01 00 00 00    nop

! 0xC98–0xD38: Initialize and configure a hardware controller
! Steps:
! 1. Combine the two input arguments into a configuration word.
! 2. Write the configuration to register 0x2001041C.
! 3. Issue command 0x00280001 through register 0x20010418.
! 4. Wait for status bit 2 to become set.
! 5. Write 1 to the configuration register.
! 6. Issue command 0x00240001 and wait for completion.
! 7. Call the delay routine at 0x272C with argument 5.
! 8. Clear the configuration register.
! 9. Issue command 0x00240001 again and wait for completion.
!
! Arguments:
! %i0 = first configuration value
! %i1 = second configuration value
!
! Hardware:
! 0x20010418 = probable command/status register
! 0x2001041C = probable configuration/data register
!
! Note:
! Controller type and command meanings are not yet identified.

0x00C98    9d e3 bf 98    save  %sp, -104, %sp
0x00C9C    13 08 00 41    sethi %hi(0x20010400), %o1
0x00CA0    b1 2e 20 08    sll   %i0, 8, %i0
0x00CA4    94 12 60 1c    or    %o1, 0x1c, %o2
0x00CA8    b0 16 00 19    or    %i0, %i1, %i0
0x00CAC    11 00 0a 00    sethi %hi(0x280000), %o0
0x00CB0    f0 22 80 00    st    %i0, [%o2]
0x00CB4    92 12 60 18    or    %o1, 0x18, %o1
0x00CB8    90 12 20 01    or    %o0, 1, %o0
0x00CBC    94 10 00 09    mov   %o1, %o2
0x00CC0    d0 22 40 00    st    %o0, [%o1]
0x00CC4    d0 02 80 00    ld    [%o2], %o0
0x00CC8    80 8a 20 04    btst  4, %o0
0x00CCC    02 bf ff fe    be    0xcc4
0x00CD0    13 08 00 41    sethi %hi(0x20010400), %o1
0x00CD4    96 12 60 1c    or    %o1, 0x1c, %o3
0x00CD8    94 10 20 01    mov   1, %o2
0x00CDC    11 00 09 00    sethi %hi(0x240000), %o0
0x00CE0    d4 22 c0 00    st    %o2, [%o3]
0x00CE4    92 12 60 18    or    %o1, 0x18, %o1
0x00CE8    90 12 20 01    or    %o0, 1, %o0
0x00CEC    94 10 00 09    mov   %o1, %o2
0x00CF0    d0 22 40 00    st    %o0, [%o1]
0x00CF4    d0 02 80 00    ld    [%o2], %o0
0x00CF8    80 8a 20 04    btst  4, %o0
0x00CFC    02 bf ff fe    be    0xcf4
0x00D00    01 00 00 00    nop
0x00D04    40 00 06 8a    call  0x272c
0x00D08    90 10 20 05    mov   5, %o0
0x00D0C    11 08 00 41    sethi %hi(0x20010400), %o0
0x00D10    94 12 20 1c    or    %o0, 0x1c, %o2
0x00D14    13 00 09 00    sethi %hi(0x240000), %o1
0x00D18    90 12 20 18    or    %o0, 0x18, %o0
0x00D1C    c0 22 80 00    clr   [%o2]
0x00D20    92 12 60 01    or    %o1, 1, %o1
0x00D24    94 10 00 08    mov   %o0, %o2
0x00D28    d2 22 00 00    st    %o1, [%o0]
0x00D2C    d0 02 80 00    ld    [%o2], %o0
0x00D30    80 8a 20 04    btst  4, %o0
0x00D34    02 bf ff fe    be    0xd2c
0x00D38    11 00 0d 00    sethi %hi(0x340000), %o0


! 0xD3C–0xDC4: Poll the hardware controller with retries
! Steps:
! 1. Prepare command words 0x00340003 and 0x00300003.
! 2. Set a retry counter to 1000.
! 3. Call the delay routine at 0x272C with argument 5.
! 4. Issue the first command and wait for status bit 2.
! 5. Read the data register and test bit 0.
! 6. If bit 0 is set, decrement the retry counter and repeat.
! 7. Otherwise issue the second command and read the response.
! 8. Mask the response with 0xFFFF and return it.
! 9. Return -1 if the retry counter expires.
!
! Hardware:
! 0x20010418 = probable command/status register
! 0x2001041C = probable data register

0x00D3C    a6 12 20 03    or    %o0, 3, %l3
0x00D40    15 08 00 41    sethi %hi(0x20010400), %o2
0x00D44    13 00 0c 00    sethi %hi(0x300000), %o1
0x00D48    11 00 00 3f    sethi %hi(0xfc00), %o0
0x00D4C    aa 10 00 0a    mov   %o2, %l5
0x00D50    a4 12 60 03    or    %o1, 3, %l2
0x00D54    a8 12 23 ff    or    %o0, 0x3ff, %l4
0x00D58    b2 12 a0 18    or    %o2, 0x18, %i1
0x00D5C    a2 12 a0 1c    or    %o2, 0x1c, %l1
0x00D60    a0 10 23 e8    mov   0x3e8, %l0
0x00D64    40 00 06 72    call  0x272c
0x00D68    90 10 20 05    mov   5, %o0
0x00D6C    e6 26 40 00    st    %l3, [%i1]
0x00D70    d0 06 40 00    ld    [%i1], %o0
0x00D74    80 8a 20 04    btst  4, %o0
0x00D78    02 bf ff fe    be    0xd70
0x00D7C    01 00 00 00    nop
0x00D80    f0 04 40 00    ld    [%l1], %i0
0x00D84    80 8e 20 01    btst  1, %i0
0x00D88    32 80 00 0b    bne,a 0xdb4
0x00D8C    a0 04 3f ff    add   %l0, -1, %l0
0x00D90    e4 26 40 00    st    %l2, [%i1]
0x00D94    94 15 60 18    or    %l5, 0x18, %o2
0x00D98    d0 02 80 00    ld    [%o2], %o0
0x00D9C    80 8a 20 04    btst  4, %o0
0x00DA0    02 bf ff fe    be    0xd98
0x00DA4    01 00 00 00    nop
0x00DA8    f0 04 40 00    ld    [%l1], %i0
0x00DAC    10 80 00 05    b     0xdc0
0x00DB0    b0 0e 00 14    and   %i0, %l4, %i0
0x00DB4    80 a4 20 00    cmp   %l0, 0
0x00DB8    14 bf ff eb    bg    0xd64
0x00DBC    b0 10 3f ff    mov   -1, %i0
0x00DC0    81 c7 e0 08    ret
0x00DC4    81 e8 00 00    restore

! 0xDC8–0xE84: Write a value through the hardware controller
! Steps:
! 1. Combine the first two arguments into a configuration word.
! 2. Write the configuration to register 0x2001041C.
! 3. Issue command 0x00280001 and wait for completion.
! 4. Initialize a retry counter to 1000.
! 5. Issue command 0x00340003 and read the response.
! 6. Retry while response bit 0 is set.
! 7. Otherwise write the third argument to the data register.
! 8. Issue command 0x002C0001 and wait for completion.
! 9. Return 0 on success or -1 after exhausting retries.
!
! Arguments:
! %i0 = first configuration value
! %i1 = second configuration value
! %i2 = value to write
!
! Hardware:
! 0x20010418 = probable command/status register
! 0x2001041C = probable data register

0x00DC8    9d e3 bf 98    save  %sp, -104, %sp
0x00DCC    11 08 00 41    sethi %hi(0x20010400), %o0
0x00DD0    b1 2e 20 08    sll   %i0, 8, %i0
0x00DD4    94 12 20 1c    or    %o0, 0x1c, %o2
0x00DD8    b0 16 00 19    or    %i0, %i1, %i0
0x00DDC    13 00 0a 00    sethi %hi(0x280000), %o1
0x00DE0    f0 22 80 00    st    %i0, [%o2]
0x00DE4    90 12 20 18    or    %o0, 0x18, %o0
0x00DE8    92 12 60 01    or    %o1, 1, %o1
0x00DEC    94 10 00 08    mov   %o0, %o2
0x00DF0    d2 22 00 00    st    %o1, [%o0]
0x00DF4    b0 10 3f ff    mov   -1, %i0
0x00DF8    d0 02 80 00    ld    [%o2], %o0
0x00DFC    80 8a 20 04    btst  4, %o0
0x00E00    02 bf ff fe    be    0xdf8
0x00E04    11 08 00 41    sethi %hi(0x20010400), %o0
0x00E08    13 00 0d 00    sethi %hi(0x340000), %o1
0x00E0C    15 00 0b 00    sethi %hi(0x2c0000), %o2
0x00E10    a2 10 00 08    mov   %o0, %l1
0x00E14    a4 12 60 03    or    %o1, 3, %l2
0x00E18    a6 12 a0 01    or    %o2, 1, %l3
0x00E1C    b2 12 20 18    or    %o0, 0x18, %i1
0x00E20    a0 10 23 e8    mov   0x3e8, %l0
0x00E24    40 00 06 42    call  0x272c
0x00E28    90 10 20 05    mov   5, %o0
0x00E2C    e4 26 40 00    st    %l2, [%i1]
0x00E30    d0 06 40 00    ld    [%i1], %o0
0x00E34    80 8a 20 04    btst  4, %o0
0x00E38    02 bf ff fe    be    0xe30
0x00E3C    92 14 60 1c    or    %l1, 0x1c, %o1
0x00E40    d0 02 40 00    ld    [%o1], %o0
0x00E44    80 8a 20 01    btst  1, %o0
0x00E48    32 80 00 0b    bne,a 0xe74
0x00E4C    a0 04 3f ff    add   %l0, -1, %l0
0x00E50    f4 22 40 00    st    %i2, [%o1]
0x00E54    e6 26 40 00    st    %l3, [%i1]
0x00E58    92 14 60 18    or    %l1, 0x18, %o1
0x00E5C    d0 02 40 00    ld    [%o1], %o0
0x00E60    80 8a 20 04    btst  4, %o0
0x00E64    02 bf ff fe    be    0xe5c
0x00E68    01 00 00 00    nop
0x00E6C    10 80 00 05    b     0xe80
0x00E70    b0 10 20 00    clr   %i0
0x00E74    80 a4 20 00    cmp   %l0, 0
0x00E78    14 bf ff eb    bg    0xe24
0x00E7C    01 00 00 00    nop
0x00E80    81 c7 e0 08    ret
0x00E84    81 e8 00 00    restore


! 0xE88–0xFFC: Initialize hardware registers and controller
! Steps:
! 1. Clear register 0x20005040.
! 2. Write 0x377 to register 0x20010428.
! 3. Configure registers at 0x20002800–0x20002814.
! 4. Set and clear control bits at 0x20010400.
! 5. Call the delay routine at 0x272C.
! 6. Write commands to 0x20010418 and poll status bit 2.
! 7. Modify data register 0x2001041C using bit masks.
! 8. Continue hardware initialization beyond 0xFFC.
!
! Hardware:
! 0x20005040 = unidentified control register
! 0x20010400 = controller configuration register
! 0x20010418 = command/status register
! 0x2001041C = data register
! 0x20010428 = unidentified configuration register
! 0x20002800–0x20002814 = additional hardware registers
!
! Note:
! This routine continues beyond the supplied disassembly.

0x00E88    9d e3 bf 98    save  %sp, -104, %sp
0x00E8C    11 08 00 14    sethi %hi(0x20005000), %o0
0x00E90    90 12 20 40    or    %o0, 0x40, %o0
0x00E94    21 08 00 41    sethi %hi(0x20010400), %l0
0x00E98    c0 22 00 00    clr   [%o0]
0x00E9C    17 08 00 0a    sethi %hi(0x20002800), %o3
0x00EA0    92 14 20 28    or    %l0, 0x28, %o1
0x00EA4    90 10 23 77    mov   0x377, %o0
0x00EA8    d0 22 40 00    st    %o0, [%o1]
0x00EAC    94 12 e0 04    or    %o3, 4, %o2
0x00EB0    98 10 24 00    mov   0x400, %o4
0x00EB4    d8 22 80 00    st    %o4, [%o2]
0x00EB8    92 12 e0 14    or    %o3, 0x14, %o1
0x00EBC    11 00 00 20    sethi %hi(0x8000), %o0
0x00EC0    d8 22 40 00    st    %o4, [%o1]
0x00EC4    90 12 20 0b    or    %o0, 0xb, %o0
0x00EC8    d0 22 c0 00    st    %o0, [%o3]
0x00ECC    94 12 e0 10    or    %o3, 0x10, %o2
0x00ED0    d0 22 80 00    st    %o0, [%o2]
0x00ED4    d2 04 00 00    ld    [%l0], %o1
0x00ED8    90 10 20 0a    mov   0xa, %o0
0x00EDC    92 12 64 00    or    %o1, 0x400, %o1
0x00EE0    d2 24 00 00    st    %o1, [%l0]
0x00EE4    40 00 06 12    call  0x272c
0x00EE8    01 00 00 00    nop
0x00EEC    d0 04 00 00    ld    [%l0], %o0
0x00EF0    19 20 00 00    sethi %hi(0x80000000), %o4
0x00EF4    90 0a 3b ff    and   %o0, -1025, %o0
0x00EF8    d0 24 00 00    st    %o0, [%l0]
0x00EFC    d2 04 00 00    ld    [%l0], %o1
0x00F00    94 10 00 0c    mov   %o4, %o2
0x00F04    92 12 40 0c    or    %o1, %o4, %o1
0x00F08    d2 24 00 00    st    %o1, [%l0]
0x00F0C    d0 04 00 00    ld    [%l0], %o0
0x00F10    17 00 00 10    sethi %hi(0x4000), %o3
0x00F14    94 2a 00 0a    andn  %o0, %o2, %o2
0x00F18    d4 24 00 00    st    %o2, [%l0]
0x00F1C    d0 04 00 00    ld    [%l0], %o0
0x00F20    92 14 20 1c    or    %l0, 0x1c, %o1
0x00F24    90 12 00 0b    or    %o0, %o3, %o0
0x00F28    d0 24 00 00    st    %o0, [%l0]
0x00F2C    d8 22 40 00    st    %o4, [%o1]
0x00F30    a0 14 20 18    or    %l0, 0x18, %l0
0x00F34    90 10 20 01    mov   1, %o0
0x00F38    92 10 00 10    mov   %l0, %o1
0x00F3C    d0 24 00 00    st    %o0, [%l0]
0x00F40    d0 02 40 00    ld    [%o1], %o0
0x00F44    80 8a 20 04    btst  4, %o0
0x00F48    02 bf ff fe    be    0xf40
0x00F4C    01 00 00 00    nop
0x00F50    40 00 05 f7    call  0x272c
0x00F54    90 10 20 01    mov   1, %o0
0x00F58    11 08 00 41    sethi %hi(0x20010400), %o0
0x00F5C    90 12 20 18    or    %o0, 0x18, %o0
0x00F60    92 10 20 03    mov   3, %o1
0x00F64    94 10 00 08    mov   %o0, %o2
0x00F68    d2 22 00 00    st    %o1, [%o0]
0x00F6C    d0 02 80 00    ld    [%o2], %o0
0x00F70    80 8a 20 04    btst  4, %o0
0x00F74    02 bf ff fe    be    0xf6c
0x00F78    13 08 00 41    sethi %hi(0x20010400), %o1
0x00F7C    96 12 60 1c    or    %o1, 0x1c, %o3
0x00F80    d4 02 c0 00    ld    [%o3], %o2
0x00F84    11 20 00 00    sethi %hi(0x80000000), %o0
0x00F88    90 2a 80 08    andn  %o2, %o0, %o0
0x00F8C    d0 22 c0 00    st    %o0, [%o3]
0x00F90    92 12 60 18    or    %o1, 0x18, %o1
0x00F94    90 10 20 01    mov   1, %o0
0x00F98    94 10 00 09    mov   %o1, %o2
0x00F9C    d0 22 40 00    st    %o0, [%o1]
0x00FA0    d0 02 80 00    ld    [%o2], %o0
0x00FA4    80 8a 20 04    btst  4, %o0
0x00FA8    02 bf ff fe    be    0xfa0
0x00FAC    01 00 00 00    nop
0x00FB0    40 00 05 df    call  0x272c
0x00FB4    90 10 20 01    mov   1, %o0
0x00FB8    11 08 00 41    sethi %hi(0x20010400), %o0
0x00FBC    90 12 20 18    or    %o0, 0x18, %o0
0x00FC0    92 10 20 03    mov   3, %o1
0x00FC4    94 10 00 08    mov   %o0, %o2
0x00FC8    d2 22 00 00    st    %o1, [%o0]
0x00FCC    d0 02 80 00    ld    [%o2], %o0
0x00FD0    80 8a 20 04    btst  4, %o0
0x00FD4    02 bf ff fe    be    0xfcc
0x00FD8    13 08 00 41    sethi %hi(0x20010400), %o1
0x00FDC    94 12 60 1c    or    %o1, 0x1c, %o2
0x00FE0    d0 02 80 00    ld    [%o2], %o0
0x00FE4    92 12 60 18    or    %o1, 0x18, %o1
0x00FE8    90 12 20 01    or    %o0, 1, %o0
0x00FEC    d0 22 80 00    st    %o0, [%o2]
0x00FF0    90 10 20 01    mov   1, %o0
0x00FF4    94 10 00 09    mov   %o1, %o2
0x00FF8    d0 22 40 00    st    %o0, [%o1]
0x00FFC    d0 02 80 00    ld    [%o2], %o0
0x01000    80 8a 20 04    btst  4, %o0                           ! Test controller completion bit
0x01004    02 bf ff fe    be    0xffc                            ! Wait until operation completes
0x01008    11 08 00 41    sethi %hi(0x20010400), %o0
0x0100C    90 12 20 18    or    %o0, 0x18, %o0                   ! Command/status register: 0x20010418
0x01010    92 10 20 03    mov   3, %o1                           ! Controller command 3
0x01014    94 10 00 08    mov   %o0, %o2
0x01018    d2 22 00 00    st    %o1, [%o0]                       ! Issue command
0x0101C    d0 02 80 00    ld    [%o2], %o0                       ! Read controller status
0x01020    80 8a 20 04    btst  4, %o0                           ! Check completion bit
0x01024    02 bf ff fe    be    0x101c                           ! Continue polling

0x01028    13 08 00 41    sethi %hi(0x20010400), %o1
0x0102C    94 12 60 1c    or    %o1, 0x1c, %o2                   ! Data register: 0x2001041C
0x01030    d0 02 80 00    ld    [%o2], %o0                       ! Read controller data
0x01034    92 12 60 18    or    %o1, 0x18, %o1                   ! Command/status register
0x01038    90 12 20 04    or    %o0, 4, %o0                      ! Set bit 2
0x0103C    d0 22 80 00    st    %o0, [%o2]                       ! Write modified data
0x01040    90 10 20 01    mov   1, %o0
0x01044    94 10 00 09    mov   %o1, %o2
0x01048    d0 22 40 00    st    %o0, [%o1]                       ! Issue command 1
0x0104C    d0 02 80 00    ld    [%o2], %o0                       ! Read status
0x01050    80 8a 20 04    btst  4, %o0                           ! Test completion bit
0x01054    02 bf ff fe    be    0x104c                           ! Wait for completion
0x01058    01 00 00 00    nop
0x0105C    40 00 05 b4    call  0x272c                           ! Delay routine
0x01060    90 10 20 01    mov   1, %o0                           ! Delay argument (delay slot)
0x01064    13 08 00 41    sethi %hi(0x20010400), %o1
0x01068    96 12 60 1c    or    %o1, 0x1c, %o3                   ! Data register
0x0106C    94 10 20 07    mov   7, %o2
0x01070    11 00 08 00    sethi %hi(0x200000), %o0
0x01074    d4 22 c0 00    st    %o2, [%o3]                       ! Write value 7
0x01078    92 12 60 18    or    %o1, 0x18, %o1
0x0107C    90 12 20 01    or    %o0, 1, %o0                      ! Command 0x00200001
0x01080    94 10 00 09    mov   %o1, %o2
0x01084    d0 22 40 00    st    %o0, [%o1]                       ! Issue controller command
0x01088    d0 02 80 00    ld    [%o2], %o0
0x0108C    80 8a 20 04    btst  4, %o0                           ! Test completion bit
0x01090    02 bf ff fe    be    0x1088                           ! Poll until complete
0x01094    01 00 00 00    nop
0x01098    40 00 05 a5    call  0x272c                           ! Delay routine
0x0109C    90 10 20 01    mov   1, %o0                           ! Delay argument (delay slot)
0x010A0    15 08 00 41    sethi %hi(0x20010400), %o2
0x010A4    11 04 84 44    sethi %hi(0x12111000), %o0
0x010A8    96 12 a0 1c    or    %o2, 0x1c, %o3                   ! Data register
0x010AC    90 12 21 11    or    %o0, 0x111, %o0                  ! Value 0x12111111
0x010B0    13 00 10 00    sethi %hi(0x400000), %o1
0x010B4    d0 22 c0 00    st    %o0, [%o3]                       ! Write configuration pattern
0x010B8    94 12 a0 18    or    %o2, 0x18, %o2
0x010BC    92 12 60 01    or    %o1, 1, %o1                      ! Command 0x00400001
0x010C0    96 10 00 0a    mov   %o2, %o3
0x010C4    d2 22 80 00    st    %o1, [%o2]                       ! Issue controller command
0x010C8    d0 02 c0 00    ld    [%o3], %o0
0x010CC    80 8a 20 04    btst  4, %o0                           ! Test completion bit
0x010D0    02 bf ff fe    be    0x10c8                           ! Poll until complete
0x010D4    13 08 00 41    sethi %hi(0x20010400), %o1
0x010D8    96 12 60 1c    or    %o1, 0x1c, %o3                   ! Data register
0x010DC    15 04 44 40    sethi %hi(0x11110000), %o2
0x010E0    11 00 11 00    sethi %hi(0x440000), %o0
0x010E4    d4 22 c0 00    st    %o2, [%o3]                       ! Write 0x11110000
0x010E8    92 12 60 18    or    %o1, 0x18, %o1
0x010EC    90 12 20 01    or    %o0, 1, %o0                      ! Command 0x00440001
0x010F0    94 10 00 09    mov   %o1, %o2
0x010F4    d0 22 40 00    st    %o0, [%o1]                       ! Issue controller command
0x010F8    d0 02 80 00    ld    [%o2], %o0
0x010FC    80 8a 20 04    btst  4, %o0                           ! Test completion bit
0x01100    02 bf ff fe    be    0x10f8                           ! Poll until complete
0x01104    11 0f 68 00    sethi %hi(0x3da00000), %o0
0x01108    90 12 23 02    or    %o0, 0x302, %o0                  ! Value 0x3DA00302
0x0110C    15 08 00 41    sethi %hi(0x20010400), %o2
0x01110    13 00 00 3f    sethi %hi(0xfc00), %o1
0x01114    a0 12 63 ff    or    %o1, 0x3ff, %l0                  ! Mask 0x0000FFFF
0x01118    d0 22 80 00    st    %o0, [%o2]                       ! Write controller configuration
0x0111C    a2 10 20 00    clr   %l1                              ! Start device index at 0
0x01120    80 a4 60 1f    cmp   %l1, 0x1f                        ! Maximum index: 31
0x01124    18 80 00 0b    bgu   0x1150                           ! Exit scan when index > 31
0x01128    90 10 00 11    mov   %l1, %o0                         ! First argument (delay slot)
0x0112C    7f ff fe db    call  0xc98                            ! Read controller value
0x01130    92 10 20 02    mov   2, %o1                           ! Second argument (delay slot)
0x01134    a6 0a 00 10    and   %o0, %l0, %l3                    ! Keep lower 16 bits
0x01138    80 a4 e1 41    cmp   %l3, 0x141                       ! Compare identification value
0x0113C    02 80 00 04    be    0x114c                           ! Match: 0x0141
0x01140    80 a4 e0 0f    cmp   %l3, 0xf                         ! Compare with 0x000F (delay slot)
0x01144    32 bf ff f7    bne,a 0x1120                           ! Continue scan if neither matches
0x01148    a2 04 60 01    inc   %l1                              ! Advance index only when branching
0x0114C    80 a4 60 1f    cmp   %l1, 0x1f
0x01150    18 80 00 1c    bgu   0x11c0                           ! No matching device found
0x01154    92 10 20 00    clr   %o1                              ! Second argument (delay slot)
0x01158    7f ff fe d0    call  0xc98                            ! Read selected device register
0x0115C    90 10 00 11    mov   %l1, %o0                         ! Selected device index
0x01160    15 00 00 20    sethi %hi(0x8000), %o2
0x01164    a0 10 00 08    mov   %o0, %l0                         ! Preserve register value
0x01168    a4 10 00 0a    mov   %o2, %l2                         ! Bit mask 0x8000
0x0116C    90 10 00 11    mov   %l1, %o0
0x01170    92 10 20 00    clr   %o1
0x01174    7f ff ff 15    call  0xdc8                            ! Write controller value
0x01178    94 14 00 0a    or    %l0, %o2, %o2                    ! Set bit 15 (delay slot)
0x0117C    b0 10 20 64    mov   0x64, %i0                        ! Initialize retry counter: 100
0x01180    80 a6 20 00    cmp   %i0, 0
0x01184    22 80 00 0c    be,a 0x11b4                            ! Exit retry loop when zero
0x01188    25 00 00 20    sethi %hi(0x8000), %l2
0x0118C    40 00 05 68    call  0x272c                           ! Delay routine
0x01190    90 10 20 32    mov   0x32, %o0                        ! Delay argument: 50
0x01194    90 10 00 11    mov   %l1, %o0
0x01198    7f ff fe c0    call  0xc98                            ! Read device register again
0x0119C    92 10 20 00    clr   %o1
0x011A0    a0 10 00 08    mov   %o0, %l0
0x011A4    80 8c 00 12    btst  %l0, %l2                         ! Test bit 15
0x011A8    12 bf ff f6    bne   0x1180                           ! Retry while bit remains set
0x011AC    b0 06 3f ff    add   %i0, -1, %i0                     ! Decrement counter (delay slot)
0x011B0    25 00 00 20    sethi %hi(0x8000), %l2
0x011B4    80 8c 00 12    btst  %l0, %l2                         ! Final busy-bit check
0x011B8    02 80 00 04    be    0x11c8                           ! Continue if bit is clear
0x011BC    94 0c 3b ff    and   %l0, -1025, %o2                  ! Clear bit 10 (delay slot)
0x011C0    10 80 00 57    b     0x131c                           ! Error exit
0x011C4    b0 10 20 01    mov   1, %i0                           ! Return status 1
0x011C8    92 10 20 00    clr   %o1
0x011CC    7f ff fe ff    call  0xdc8                            ! Write modified register value
0x011D0    90 10 00 11    mov   %l1, %o0
0x011D4    92 10 20 00    clr   %o1
0x011D8    7f ff fe b0    call  0xc98                            ! Read register back
0x011DC    90 10 00 11    mov   %l1, %o0
0x011E0    13 00 00 04    sethi %hi(0x1000), %o1
0x011E4    92 12 63 00    or    %o1, 0x300, %o1                  ! Mask 0x1300
0x011E8    a0 12 00 09    or    %o0, %o1, %l0                    ! Set configuration bits
0x011EC    94 10 00 10    mov   %l0, %o2
0x011F0    92 10 20 00    clr   %o1
0x011F4    7f ff fe f5    call  0xdc8                            ! Write updated configuration
0x011F8    90 10 00 11    mov   %l1, %o0
0x011FC    15 08 00 00    sethi %hi(0x20000000), %o2
0x01200    96 12 a0 40    or    %o2, 0x40, %o3                   ! Register 0x20000040
0x01204    e4 22 c0 00    st    %l2, [%o3]                       ! Write 0x8000
0x01208    92 12 a0 44    or    %o2, 0x44, %o1                   ! Register 0x20000044
0x0120C    90 10 22 62    mov   0x262, %o0
0x01210    d0 22 40 00    st    %o0, [%o1]                       ! Write 0x262
0x01214    b0 12 a0 4c    or    %o2, 0x4c, %i0                   ! Register 0x2000004C
0x01218    94 12 a0 50    or    %o2, 0x50, %o2                   ! Register 0x20000050
0x0121C    11 00 00 10    sethi %hi(0x4000), %o0
0x01220    d0 22 80 00    st    %o0, [%o2]                       ! Write 0x4000
0x01224    92 10 21 00    mov   0x100, %o1
0x01228    d2 22 c0 00    st    %o1, [%o3]                       ! Update register 0x20000040
0x0122C    21 00 3f fe    sethi %hi(0xfff800), %l0               ! Prepare status mask
0x01230    40 00 05 3f    call  0x272c                           ! Delay routine

! 0x1234–0x1320: Complete controller initialization
! Steps:
! 1. Wait and poll the selected device for status bit 2.
! 2. Check an additional MMIO status register if necessary.
! 3. Select a device-specific status test.
! 4. Issue one of two final controller commands.
! 5. Return 0 on success or 1 on earlier failure.

0x01234    90 10 23 e8    mov   0x3e8, %o0                       ! Delay argument: 1000 (call delay slot)
0x01238    90 10 00 11    mov   %l1, %o0                         ! Selected device index
0x0123C    7f ff fe 97    call  0xc98                            ! Read device register
0x01240    92 10 20 01    mov   1, %o1                           ! Register selector 1 (delay slot)
0x01244    80 8a 20 04    btst  4, %o0                           ! Test returned bit 2
0x01248    12 80 00 06    bne   0x1260                           ! Continue if bit is set
0x0124C    80 a4 e1 41    cmp   %l3, 0x141                       ! Prepare device-type comparison
0x01250    d0 06 00 00    ld    [%i0], %o0                       ! Read MMIO register 0x2000004C
0x01254    80 8a 00 10    btst  %o0, %l0                         ! Test hardware status mask
0x01258    12 bf ff f6    bne   0x1230                           ! Retry while masked bits are set
0x0125C    80 a4 e1 41    cmp   %l3, 0x141                       ! Prepare device-type comparison
0x01260    12 80 00 0e    bne   0x1298                           ! Different device type
0x01264    92 10 20 1c    mov   0x1c, %o1                        ! Register selector (delay slot)
0x01268    92 10 20 11    mov   0x11, %o1                        ! Override selector with 0x11
0x0126C    7f ff fe 8b    call  0xc98                            ! Read device register 0x11
0x01270    90 10 00 11    mov   %l1, %o0                         ! Selected device index (delay slot)
0x01274    92 10 00 08    mov   %o0, %o1                         ! Preserve returned value
0x01278    80 8a 64 00    btst  0x400, %o1                       ! Test bit 10
0x0127C    02 80 00 04    be    0x128c                           ! Bit 10 clear
0x01280    11 00 00 20    sethi %hi(0x8000), %o0                 ! Prepare bit 15 mask
0x01284    10 80 00 03    b     0x1290
0x01288    90 0a 40 08    and   %o1, %o0, %o0                    ! Isolate bit 15 (delay slot)
0x0128C    90 10 20 00    clr   %o0                              ! No qualifying status bit
0x01290    10 80 00 05    b     0x12a4
0x01294    92 10 00 08    mov   %o0, %o1                         ! Set condition value (delay slot)
0x01298    7f ff fe 80    call  0xc98                            ! Read device register 0x1C
0x0129C    90 10 00 11    mov   %l1, %o0                         ! Selected device index (delay slot)
0x012A0    92 0a 20 10    and   %o0, 0x10, %o1                   ! Isolate bit 4
0x012A4    80 a2 60 00    cmp   %o1, 0
0x012A8    02 80 00 10    be    0x12e8                           ! Choose alternative configuration
0x012AC    15 08 00 41    sethi %hi(0x20010400), %o2
0x012B0    11 00 00 3c    sethi %hi(0xf000), %o0
0x012B4    96 12 a0 1c    or    %o2, 0x1c, %o3                   ! Data register: 0x2001041C
0x012B8    90 12 22 05    or    %o0, 0x205, %o0                  ! Configuration value 0xF205
0x012BC    13 00 01 00    sethi %hi(0x40000), %o1
0x012C0    d0 22 c0 00    st    %o0, [%o3]                       ! Write configuration value
0x012C4    94 12 a0 18    or    %o2, 0x18, %o2                   ! Command/status register
0x012C8    92 12 60 01    or    %o1, 1, %o1                      ! Command 0x00040001
0x012CC    96 10 00 0a    mov   %o2, %o3
0x012D0    d2 22 80 00    st    %o1, [%o2]                       ! Issue command
0x012D4    d0 02 c0 00    ld    [%o3], %o0                       ! Read controller status
0x012D8    80 8a 20 04    btst  4, %o0                           ! Test completion bit
0x012DC    02 bf ff fe    be    0x12d4                           ! Poll until complete
0x012E0    b0 10 20 00    clr   %i0                              ! Set success return value
0x012E4    30 80 00 0e    b,a   0x131c                           ! Skip alternative path and delay slot
0x012E8    11 00 00 3c    sethi %hi(0xf000), %o0
0x012EC    96 12 a0 1c    or    %o2, 0x1c, %o3                   ! Data register
0x012F0    90 12 21 05    or    %o0, 0x105, %o0                  ! Configuration value 0xF105
0x012F4    13 00 01 00    sethi %hi(0x40000), %o1
0x012F8    d0 22 c0 00    st    %o0, [%o3]                       ! Write alternative configuration
0x012FC    94 12 a0 18    or    %o2, 0x18, %o2                   ! Command/status register
0x01300    92 12 60 01    or    %o1, 1, %o1                      ! Command 0x00040001
0x01304    96 10 00 0a    mov   %o2, %o3
0x01308    d2 22 80 00    st    %o1, [%o2]                       ! Issue command
0x0130C    d0 02 c0 00    ld    [%o3], %o0                       ! Read controller status
0x01310    80 8a 20 04    btst  4, %o0                           ! Test completion bit
0x01314    02 bf ff fe    be    0x130c                           ! Poll until complete
0x01318    b0 10 20 00    clr   %i0                              ! Set success return value
0x0131C    81 c7 e0 08    ret
0x01320    81 e8 00 00    restore                                ! Restore register window

! 0x1324–0x1498: Controller data transfer and status handling
! Steps:
! 1. Drain pending data while controller status bit 12 is set.
! 2. Enable or reset the controller if status bit 29 is clear.
! 3. Configure transfer registers using the first two arguments.
! 4. Poll for incoming data with a bounded retry counter.
! 5. Read two 32-bit words from the controller data port.
! 6. Check bit 23 of the second word.
! 7. Save diagnostic values to RAM when the check succeeds.
! 8. Return 0, -1 on timeout, or -3 on invalid data.
!
! Arguments:
! %i0 = transfer address or offset (exact meaning unknown)
! %i1 = transfer configuration value (exact meaning unknown)
! %i2 = destination buffer for two 32-bit words
!
! Hardware:
! 0x20010400 = controller status/control register
! 0x20010420 = controller data port
! 0x20002810 = auxiliary controller register
! 0x20002818 = transfer address register (probable)
! 0x2000281C = transfer configuration register (probable)

0x01324    9d e3 bf 98    save  %sp, -104, %sp
0x01328    11 08 00 41    sethi %hi(0x20010400), %o0
0x0132C    e0 02 00 00    ld    [%o0], %l0                       ! Read controller status
0x01330    19 00 00 04    sethi %hi(0x1000), %o4                 ! Status bit 12
0x01334    80 8c 00 0c    btst  %l0, %o4                         ! Check pending data
0x01338    02 80 00 0b    be    0x1364                           ! Skip draining if clear
0x0133C    96 10 00 08    mov   %o0, %o3                         ! Preserve status address
0x01340    94 12 e0 20    or    %o3, 0x20, %o2                   ! Data port: 0x20010420
0x01344    d0 02 80 00    ld    [%o2], %o0                       ! Read first data word
0x01348    d0 26 80 00    st    %o0, [%i2]                       ! Store at destination
0x0134C    d2 02 80 00    ld    [%o2], %o1                       ! Read second data word
0x01350    d2 26 a0 04    st    %o1, [%i2 + 4]                   ! Store at destination + 4
0x01354    e0 02 c0 00    ld    [%o3], %l0                       ! Refresh controller status
0x01358    80 8c 00 0c    btst  %l0, %o4                         ! Check pending data again
0x0135C    12 bf ff fa    bne   0x1344                           ! Drain while bit 12 is set
0x01360    01 00 00 00    nop

0x01364    19 08 00 41    sethi %hi(0x20010400), %o4
0x01368    d0 03 00 00    ld    [%o4], %o0                       ! Read controller status
0x0136C    17 08 00 00    sethi %hi(0x20000000), %o3             ! Status bit 29
0x01370    80 8a 00 0b    btst  %o0, %o3                         ! Test controller state
0x01374    12 80 00 0c    bne   0x13a4                           ! Skip setup if already set
0x01378    15 08 00 0a    sethi %hi(0x20002800), %o2
0x0137C    94 12 a0 10    or    %o2, 0x10, %o2                   ! Auxiliary register: 0x20002810
0x01380    90 10 20 0b    mov   0xb, %o0
0x01384    13 00 00 20    sethi %hi(0x8000), %o1
0x01388    d0 22 80 00    st    %o0, [%o2]                       ! Write 0x0000000B
0x0138C    92 12 60 0b    or    %o1, 0xb, %o1                    ! Value 0x0000800B
0x01390    d2 22 80 00    st    %o1, [%o2]                       ! Write auxiliary configuration
0x01394    d0 03 00 00    ld    [%o4], %o0                       ! Read controller status/control
0x01398    90 12 00 0b    or    %o0, %o3, %o0                    ! Set bit 29
0x0139C    d0 23 00 00    st    %o0, [%o4]                       ! Update controller register
0x013A0    15 08 00 0a    sethi %hi(0x20002800), %o2

0x013A4    11 30 00 00    sethi %hi(0xc0000000), %o0
0x013A8    90 06 00 08    add   %i0, %o0, %o0                    ! Add 0xC0000000 to argument 0
0x013AC    96 12 a0 18    or    %o2, 0x18, %o3                   ! Register: 0x20002818
0x013B0    d0 22 c0 00    st    %o0, [%o3]                       ! Set transfer address/offset
0x013B4    13 00 80 00    sethi %hi(0x2000000), %o1
0x013B8    92 16 40 09    or    %i1, %o1, %o1                    ! Set bit 25 in argument 1
0x013BC    94 12 a0 1c    or    %o2, 0x1c, %o2                   ! Register: 0x2000281C
0x013C0    11 00 00 1d    sethi %hi(0x7400), %o0
0x013C4    a4 12 21 30    or    %o0, 0x130, %l2                  ! Retry limit: 0x7530 (30000)
0x013C8    d2 22 80 00    st    %o1, [%o2]                       ! Set transfer configuration
0x013CC    b2 10 00 0c    mov   %o4, %i1                         ! Preserve status register address
0x013D0    b0 10 20 00    clr   %i0                              ! Initialize poll counter
0x013D4    23 00 00 04    sethi %hi(0x1000), %l1                 ! Data-ready bit 12
0x013D8    b0 06 20 01    inc   %i0                              ! Increment poll counter
0x013DC    e0 06 40 00    ld    [%i1], %l0                       ! Read controller status
0x013E0    80 a6 00 12    cmp   %i0, %l2                         ! Compare with retry limit
0x013E4    14 80 00 18    bg    0x1444                           ! Timeout handling
0x013E8    01 00 00 00    nop
0x013EC    40 00 04 d0    call  0x272c                           ! Delay routine
0x013F0    90 10 20 01    mov   1, %o0                           ! Delay argument (delay slot)
0x013F4    80 8c 00 11    btst  %l0, %l1                         ! Test data-ready bit
0x013F8    02 bf ff f9    be    0x13dc                           ! Continue polling if clear
0x013FC    b0 06 20 01    inc   %i0                              ! Increment counter (delay slot)

0x01400    11 08 00 41    sethi %hi(0x20010400), %o0
0x01404    90 12 20 20    or    %o0, 0x20, %o0                   ! Data port: 0x20010420
0x01408    d8 02 00 00    ld    [%o0], %o4                       ! Read first result word
0x0140C    13 00 20 00    sethi %hi(0x800000), %o1               ! Bit 23 mask
0x01410    d8 26 80 00    st    %o4, [%i2]                       ! Store first result word
0x01414    d6 02 00 00    ld    [%o0], %o3                       ! Read second result word
0x01418    80 8a c0 09    btst  %o3, %o1                         ! Test bit 23
0x0141C    02 80 00 1d    be    0x1490                           ! Return -3 if bit is clear
0x01420    d6 26 a0 04    st    %o3, [%i2 + 4]                   ! Store second word (delay slot)
0x01424    11 0c 00 0f    sethi %hi(0x30003c00), %o0
0x01428    13 0c 00 0f    sethi %hi(0x30003c00), %o1
0x0142C    15 0c 00 0f    sethi %hi(0x30003c00), %o2
0x01430    d6 22 20 34    st    %o3, [%o0 + 0x34]                ! Save second word at 0x30003C34
0x01434    d8 22 60 30    st    %o4, [%o1 + 0x30]                ! Save first word at 0x30003C30
0x01438    e0 22 a0 38    st    %l0, [%o2 + 0x38]                ! Save status at 0x30003C38
0x0143C    10 80 00 16    b     0x1494                           ! Successful completion
0x01440    b0 10 20 00    clr   %i0                              ! Return 0 (delay slot)

0x01444    d0 06 40 00    ld    [%i1], %o0                       ! Read controller control register
0x01448    17 08 00 00    sethi %hi(0x20000000), %o3
0x0144C    90 12 00 0b    or    %o0, %o3, %o0                    ! Set bit 29
0x01450    15 08 00 0a    sethi %hi(0x20002800), %o2
0x01454    d0 26 40 00    st    %o0, [%i1]                       ! Update controller control
0x01458    94 12 a0 10    or    %o2, 0x10, %o2                   ! Auxiliary register: 0x20002810
0x0145C    92 10 20 0b    mov   0xb, %o1
0x01460    d2 22 80 00    st    %o1, [%o2]                       ! Write 0x0000000B
0x01464    d0 06 40 00    ld    [%i1], %o0
0x01468    13 00 00 20    sethi %hi(0x8000), %o1
0x0146C    90 12 20 80    or    %o0, 0x80, %o0                   ! Set bit 7
0x01470    d0 26 40 00    st    %o0, [%i1]
0x01474    92 12 60 0b    or    %o1, 0xb, %o1                    ! Value 0x0000800B
0x01478    d2 22 80 00    st    %o1, [%o2]                       ! Restore auxiliary configuration
0x0147C    d0 06 40 00    ld    [%i1], %o0
0x01480    b0 10 3f ff    mov   -1, %i0                          ! Timeout return value
0x01484    90 12 00 0b    or    %o0, %o3, %o0                    ! Set bit 29
0x01488    d0 26 40 00    st    %o0, [%i1]
0x0148C    30 80 00 02    b,a   0x1494                           ! Return; annul delay slot

0x01490    b0 10 3f fd    mov   -3, %i0                          ! Invalid-result return value
0x01494    81 c7 e0 08    ret
0x01498    81 e8 00 00    restore

! 0x149C–0x18F8: Controller transfer, response validation and buffer preparation
! Steps:
! 1. Configure the controller and wait for transfer completion.
! 2. Read two result words and validate their status bits.
! 3. Wait for the auxiliary controller to become idle.
! 4. Validate selected fields against reference data in RAM.
! 5. Copy or construct a response buffer, optionally calling 0x1324.
! 6. Return a status code (0, 1, 2, 3, or negative error codes).
!
! Note: The meaning of the controller protocol and data fields is not yet verified.

0x0149C    9d e3 bf 90    save  %sp, -112, %sp                   ! New stack frame (112 bytes)
0x014A0    19 08 00 41    sethi  %hi(0x20010400), %o4
0x014A4    d0 03 00 00    ld  [ %o4 ], %o0                       ! Read controller control/status
0x014A8    17 04 00 00    sethi  %hi(0x10000000), %o3            ! Bit 28 mask
0x014AC    80 8a 00 0b    btst  %o0, %o3                         ! Check controller bit 28
0x014B0    12 80 00 11    bne  0x14f4                            ! Skip reset sequence if set
0x014B4    15 08 00 0a    sethi  %hi(0x20002800), %o2            ! Auxiliary controller base (delay slot)
0x014B8    92 10 20 0b    mov  0xb, %o1
0x014BC    d2 22 80 00    st  %o1, [ %o2 ]                       ! Write 0x0B to 0x20002800
0x014C0    d0 03 00 00    ld  [ %o4 ], %o0
0x014C4    13 00 00 20    sethi  %hi(0x8000), %o1
0x014C8    90 12 20 40    or  %o0, 0x40, %o0                     ! Set bit 6
0x014CC    d0 23 00 00    st  %o0, [ %o4 ]                       ! Write controller control register
0x014D0    92 12 60 0b    or  %o1, 0xb, %o1
0x014D4    d2 22 80 00    st  %o1, [ %o2 ]                       ! Write 0x800B to 0x20002800
0x014D8    d0 03 00 00    ld  [ %o4 ], %o0
0x014DC    90 0a 3f bf    and  %o0, -65, %o0                     ! Clear bit 6
0x014E0    d0 23 00 00    st  %o0, [ %o4 ]                       ! Write controller control register
0x014E4    d2 03 00 00    ld  [ %o4 ], %o1
0x014E8    92 12 40 0b    or  %o1, %o3, %o1                      ! Set bit 28
0x014EC    d2 23 00 00    st  %o1, [ %o4 ]                       ! Write controller control register
0x014F0    15 08 00 0a    sethi  %hi(0x20002800), %o2
0x014F4    11 30 00 00    sethi  %hi(0xc0000000), %o0
0x014F8    90 06 00 08    add  %i0, %o0, %o0                     ! Add 0xC0000000 to argument 0
0x014FC    96 12 a0 08    or  %o2, 8, %o3                        ! Register 0x20002808
0x01500    d0 22 c0 00    st  %o0, [ %o3 ]                       ! Write transfer address/value
0x01504    13 00 c0 00    sethi  %hi(0x3000000), %o1
0x01508    92 16 40 09    or  %i1, %o1, %o1                      ! Set bits 24 and 25 in argument 1
0x0150C    94 12 a0 0c    or  %o2, 0xc, %o2                      ! Register 0x2000280C
0x01510    11 00 00 1d    sethi  %hi(0x7400), %o0
0x01514    a4 12 21 30    or  %o0, 0x130, %l2                    ! Polling limit: 30000
0x01518    d2 22 80 00    st  %o1, [ %o2 ]                       ! Write transfer configuration
0x0151C    a2 10 00 0c    mov  %o4, %l1                          ! Preserve status register address
0x01520    a0 10 20 00    clr  %l0                               ! Clear poll counter
0x01524    a0 04 20 01    inc  %l0                               ! Increment poll counter
0x01528    f2 04 40 00    ld  [ %l1 ], %i1                       ! Read controller status
0x0152C    80 a4 00 12    cmp  %l0, %l2
0x01530    34 80 00 f1    bg,a   0x18f4                          ! Compare with polling limit
0x01534    b0 10 3f ff    mov  -1, %i0                           ! Return -1 on timeout (annulled delay slot)
0x01538    40 00 04 7d    call  0x272c                           ! Delay routine
0x0153C    90 10 20 01    mov  1, %o0                            ! Delay argument 1
0x01540    80 8e 68 00    btst  0x800, %i1                       ! Test status bit 11
0x01544    22 bf ff f9    be,a   0x1528                          ! Continue polling while bit 11 is clear
0x01548    a0 04 20 01    inc  %l0                               ! Increment counter only on taken branch
0x0154C    11 08 00 41    sethi  %hi(0x20010400), %o0
0x01550    90 12 20 24    or  %o0, 0x24, %o0                     ! Result port 0x20010424
0x01554    d2 02 00 00    ld  [ %o0 ], %o1                       ! Read first result word
0x01558    15 00 20 00    sethi  %hi(0x800000), %o2              ! Bit 23 mask
0x0155C    d2 26 80 00    st  %o1, [ %i2 ]                       ! Store first result word
0x01560    d0 02 00 00    ld  [ %o0 ], %o0                       ! Read second result word
0x01564    80 8a 40 0a    btst  %o1, %o2                         ! Test bit 23 of first word
0x01568    02 80 00 04    be  0x1578                             ! Branch if first word bit 23 is clear
0x0156C    d0 26 a0 04    st  %o0, [ %i2 + 4 ]                   ! Store second word (delay slot)
0x01570    10 80 00 e1    b  0x18f4                              ! Return -2 if first word bit 23 is set
0x01574    b0 10 3f fe    mov  -2, %i0                           ! Return -2 (delay slot)
0x01578    80 8a 00 0a    btst  %o0, %o2                         ! Test bit 23 of second word
0x0157C    12 80 00 04    bne  0x158c                            ! Continue if second word bit 23 is set
0x01580    a0 10 20 00    clr  %l0
0x01584    10 80 00 dc    b  0x18f4                              ! Return -3 if second word bit 23 is clear
0x01588    b0 10 3f fd    mov  -3, %i0                           ! Return -3 (delay slot)
0x0158C    15 08 00 0a    sethi  %hi(0x20002800), %o2
0x01590    13 00 05 dc    sethi  %hi(0x177000), %o1              ! Auxiliary status register 0x20002800
0x01594    11 00 00 10    sethi  %hi(0x4000), %o0                ! Bit 14 mask
0x01598    a0 04 20 01    inc  %l0                               ! Increment poll counter
0x0159C    f2 02 80 00    ld  [ %o2 ], %i1                       ! Read auxiliary status
0x015A0    80 a4 00 09    cmp  %l0, %o1                          ! Compare against 0x177000
0x015A4    14 80 00 ab    bg  0x1850                             ! Timeout branch
0x015A8    80 8e 40 08    btst  %i1, %o0                         ! Test bit 14 (delay slot)
0x015AC    32 bf ff fc    bne,a   0x159c                         ! Poll while bit 14 remains set
0x015B0    a0 04 20 01    inc  %l0                               ! Increment counter on taken branch
0x015B4    d0 0e 00 00    ldub  [ %i0 ], %o0                     ! Read first byte of input buffer
0x015B8    80 a2 20 ff    cmp  %o0, 0xff                         ! Check for 0xFF marker
0x015BC    02 80 00 2a    be  0x1664                             ! Branch to alternate validation path
0x015C0    d8 0e 20 0c    ldub  [ %i0 + 0xc ], %o4               ! Read input byte at +0x0C (delay slot)
0x015C4    80 a3 20 08    cmp  %o4, 8                            ! Compare field with 8
0x015C8    12 80 00 28    bne  0x1668
0x015CC    90 0b 20 ff    and  %o4, 0xff, %o0
0x015D0    d0 0e 20 0d    ldub  [ %i0 + 0xd ], %o0               ! Read input byte at +0x0D
0x015D4    80 a2 20 06    cmp  %o0, 6                            ! Compare field with 6
0x015D8    12 80 00 24    bne  0x1668
0x015DC    90 0b 20 ff    and  %o4, 0xff, %o0
0x015E0    11 0c 00 0f    sethi  %hi(0x30003c00), %o0
0x015E4    d4 0a 20 40    ldub  [ %o0 + 0x40 ], %o2              ! Read reference byte at 0x30003C40
0x015E8    d2 0e 20 26    ldub  [ %i0 + 0x26 ], %o1              ! Read input byte at +0x26
0x015EC    80 a2 40 0a    cmp  %o1, %o2                          ! Compare reference and input bytes
0x015F0    12 80 00 1d    bne  0x1664
0x015F4    96 12 20 40    or  %o0, 0x40, %o3
0x015F8    d2 0e 20 27    ldub  [ %i0 + 0x27 ], %o1              ! Read input byte at +0x27
0x015FC    d0 0a e0 01    ldub  [ %o3 + 1 ], %o0                 ! Read reference byte at +1
0x01600    80 a2 40 08    cmp  %o1, %o0
0x01604    12 80 00 19    bne  0x1668
0x01608    90 0b 20 ff    and  %o4, 0xff, %o0
0x0160C    d2 0e 20 28    ldub  [ %i0 + 0x28 ], %o1              ! Read input byte at +0x28
0x01610    d0 0a e0 02    ldub  [ %o3 + 2 ], %o0                 ! Read reference byte at +2
0x01614    80 a2 40 08    cmp  %o1, %o0
0x01618    12 80 00 14    bne  0x1668
0x0161C    90 0b 20 ff    and  %o4, 0xff, %o0
0x01620    d2 0a e0 03    ldub  [ %o3 + 3 ], %o1                 ! Read reference byte at +3
0x01624    d0 0e 20 29    ldub  [ %i0 + 0x29 ], %o0              ! Read input byte at +0x29
0x01628    80 a2 00 09    cmp  %o0, %o1
0x0162C    12 80 00 0f    bne  0x1668
0x01630    90 0b 20 ff    and  %o4, 0xff, %o0
0x01634    11 0c 00 0f    sethi  %hi(0x30003c00), %o0
0x01638    94 12 20 50    or  %o0, 0x50, %o2                     ! Destination 0x30003C50
0x0163C    96 10 20 00    clr  %o3                               ! Initialize six-byte copy index
0x01640    90 02 c0 18    add  %o3, %i0, %o0
0x01644    d2 0a 20 16    ldub  [ %o0 + 0x16 ], %o1              ! Read input byte at +0x16 + index
0x01648    d2 2a 80 0b    stb  %o1, [ %o2 + %o3 ]                ! Copy byte to 0x30003C50 + index
0x0164C    96 02 e0 01    inc  %o3
0x01650    80 a2 e0 05    cmp  %o3, 5                            ! Advance copy index
0x01654    04 bf ff fc    ble  0x1644                            ! Repeat through index 5
0x01658    90 02 c0 18    add  %o3, %i0, %o0
0x0165C    10 80 00 a6    b  0x18f4                              ! Return after copying six bytes
0x01660    b0 10 20 01    mov  1, %i0                            ! Return 1 (delay slot)
0x01664    90 0b 20 ff    and  %o4, 0xff, %o0
0x01668    80 a2 20 08    cmp  %o0, 8                            ! Check field at +0x0C against 8
0x0166C    12 80 00 7c    bne  0x185c
0x01670    90 0b 20 ff    and  %o4, 0xff, %o0
0x01674    d0 0e 20 0d    ldub  [ %i0 + 0xd ], %o0               ! Read field at +0x0D
0x01678    80 a2 20 06    cmp  %o0, 6                            ! Check field against 6
0x0167C    12 80 00 78    bne  0x185c
0x01680    90 0b 20 ff    and  %o4, 0xff, %o0
0x01684    d0 0e 20 14    ldub  [ %i0 + 0x14 ], %o0              ! Read field at +0x14
0x01688    80 a2 20 00    cmp  %o0, 0                            ! Require value 0
0x0168C    12 80 00 74    bne  0x185c
0x01690    90 0b 20 ff    and  %o4, 0xff, %o0
0x01694    d0 0e 20 15    ldub  [ %i0 + 0x15 ], %o0              ! Read field at +0x15
0x01698    80 a2 20 01    cmp  %o0, 1                            ! Require value 1
0x0169C    12 80 00 70    bne  0x185c
0x016A0    90 0b 20 ff    and  %o4, 0xff, %o0
0x016A4    11 0c 00 0f    sethi  %hi(0x30003c00), %o0
0x016A8    d4 0a 20 40    ldub  [ %o0 + 0x40 ], %o2              ! Reference byte 0x30003C40
0x016AC    d2 0e 20 26    ldub  [ %i0 + 0x26 ], %o1              ! Input byte at +0x26
0x016B0    80 a2 40 0a    cmp  %o1, %o2                          ! Compare first reference byte
0x016B4    12 80 00 69    bne  0x1858
0x016B8    96 12 20 40    or  %o0, 0x40, %o3
0x016BC    d2 0e 20 27    ldub  [ %i0 + 0x27 ], %o1              ! Input byte at +0x27
0x016C0    d0 0a e0 01    ldub  [ %o3 + 1 ], %o0                 ! Second reference byte
0x016C4    80 a2 40 08    cmp  %o1, %o0
0x016C8    12 80 00 65    bne  0x185c
0x016CC    90 0b 20 ff    and  %o4, 0xff, %o0
0x016D0    d2 0e 20 28    ldub  [ %i0 + 0x28 ], %o1              ! Input byte at +0x28
0x016D4    d0 0a e0 02    ldub  [ %o3 + 2 ], %o0                 ! Third reference byte
0x016D8    80 a2 40 08    cmp  %o1, %o0
0x016DC    12 80 00 60    bne  0x185c
0x016E0    90 0b 20 ff    and  %o4, 0xff, %o0
0x016E4    d2 0a e0 03    ldub  [ %o3 + 3 ], %o1                 ! Fourth reference byte
0x016E8    d0 0e 20 29    ldub  [ %i0 + 0x29 ], %o0              ! Input byte at +0x29
0x016EC    80 a2 00 09    cmp  %o0, %o1
0x016F0    12 80 00 5b    bne  0x185c
0x016F4    90 0b 20 ff    and  %o4, 0xff, %o0
0x016F8    1b 0c 00 0f    sethi  %hi(0x30003c00), %o5            ! RAM base 0x30003C00
0x016FC    94 10 00 0d    mov  %o5, %o2
0x01700    96 10 20 00    clr  %o3
0x01704    84 07 bf f0    add  %fp, -16, %g2                     ! Local stack buffer at %fp - 16
0x01708    d2 0e 00 0b    ldub  [ %i0 + %o3 ], %o1               ! Read byte from input buffer
0x0170C    d0 02 a0 58    ld  [ %o2 + 0x58 ], %o0                ! Load destination pointer from 0x30003C58
0x01710    d2 2a 00 0b    stb  %o1, [ %o0 + %o3 ]                ! Copy byte to destination + index
0x01714    96 02 e0 01    inc  %o3
0x01718    80 a2 e0 2a    cmp  %o3, 0x2a                         ! Compare index with 42
0x0171C    26 bf ff fc    bl,a   0x170c                          ! Repeat while index < 42 (annulled)
0x01720    d2 0e 00 0b    ldub  [ %i0 + %o3 ], %o1               ! Prefetch next byte only when branching
0x01724    96 10 20 00    clr  %o3
0x01728    19 0c 00 0f    sethi  %hi(0x30003c00), %o4            ! RAM base for destination pointer
0x0172C    90 02 c0 18    add  %o3, %i0, %o0
0x01730    d4 0a 20 16    ldub  [ %o0 + 0x16 ], %o2              ! Read input byte at +0x16 + index
0x01734    d2 03 20 58    ld  [ %o4 + 0x58 ], %o1                ! Load destination pointer
0x01738    d4 2a 40 0b    stb  %o2, [ %o1 + %o3 ]                ! Copy byte to destination + index
0x0173C    96 02 e0 01    inc  %o3
0x01740    80 a2 e0 05    cmp  %o3, 5
0x01744    04 bf ff fb    ble  0x1730                            ! Repeat for six bytes
0x01748    90 02 c0 18    add  %o3, %i0, %o0
0x0174C    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x01750    98 12 23 40    or  %o0, 0x340, %o4                    ! Source table at 0x30003B40
0x01754    96 10 20 00    clr  %o3
0x01758    15 0c 00 0f    sethi  %hi(0x30003c00), %o2
0x0175C    d0 02 a0 58    ld  [ %o2 + 0x58 ], %o0                ! Load destination pointer from 0x30003C58
0x01760    d2 0b 00 0b    ldub  [ %o4 + %o3 ], %o1               ! Read source table byte
0x01764    90 02 c0 08    add  %o3, %o0, %o0
0x01768    96 02 e0 01    inc  %o3
0x0176C    80 a2 e0 05    cmp  %o3, 5
0x01770    04 bf ff fb    ble  0x175c
0x01774    d2 2a 20 06    stb  %o1, [ %o0 + 6 ]                  ! Store byte at destination + index + 6 (delay slot)
0x01778    11 0c 00 0e    sethi  %hi(0x30003800), %o0            ! Source table at 0x30003B40
0x0177C    98 12 23 40    or  %o0, 0x340, %o4
0x01780    96 10 20 00    clr  %o3
0x01784    15 0c 00 0f    sethi  %hi(0x30003c00), %o2
0x01788    d0 02 a0 58    ld  [ %o2 + 0x58 ], %o0
0x0178C    d2 0b 00 0b    ldub  [ %o4 + %o3 ], %o1
0x01790    90 02 c0 08    add  %o3, %o0, %o0
0x01794    96 02 e0 01    inc  %o3
0x01798    80 a2 e0 05    cmp  %o3, 5
0x0179C    04 bf ff fb    ble  0x1788
0x017A0    d2 2a 20 16    stb  %o1, [ %o0 + 0x16 ]               ! Store byte at destination + index + 0x16
0x017A4    11 0c 00 0f    sethi  %hi(0x30003c00), %o0
0x017A8    98 12 20 40    or  %o0, 0x40, %o4                     ! Reference bytes at 0x30003C40
0x017AC    96 10 20 00    clr  %o3
0x017B0    15 0c 00 0f    sethi  %hi(0x30003c00), %o2
0x017B4    d0 02 a0 58    ld  [ %o2 + 0x58 ], %o0
0x017B8    d2 0b 00 0b    ldub  [ %o4 + %o3 ], %o1
0x017BC    90 02 c0 08    add  %o3, %o0, %o0
0x017C0    96 02 e0 01    inc  %o3
0x017C4    80 a2 e0 03    cmp  %o3, 3
0x017C8    04 bf ff fb    ble  0x17b4
0x017CC    d2 2a 20 1c    stb  %o1, [ %o0 + 0x1c ]               ! Store byte at destination + index + 0x1C
0x017D0    96 10 20 00    clr  %o3
0x017D4    19 0c 00 0f    sethi  %hi(0x30003c00), %o4
0x017D8    d0 03 20 58    ld  [ %o4 + 0x58 ], %o0
0x017DC    92 02 c0 18    add  %o3, %i0, %o1
0x017E0    90 02 c0 08    add  %o3, %o0, %o0
0x017E4    d4 0a 60 16    ldub  [ %o1 + 0x16 ], %o2              ! Read input byte at +0x16 + index
0x017E8    96 02 e0 01    inc  %o3
0x017EC    80 a2 e0 05    cmp  %o3, 5
0x017F0    04 bf ff fa    ble  0x17d8
0x017F4    d4 2a 20 20    stb  %o2, [ %o0 + 0x20 ]               ! Store byte at destination + index + 0x20
0x017F8    96 10 20 00    clr  %o3
0x017FC    19 0c 00 0f    sethi  %hi(0x30003c00), %o4
0x01800    d0 03 20 58    ld  [ %o4 + 0x58 ], %o0
0x01804    92 02 c0 18    add  %o3, %i0, %o1
0x01808    90 02 c0 08    add  %o3, %o0, %o0
0x0180C    d4 0a 60 1c    ldub  [ %o1 + 0x1c ], %o2              ! Read input byte at +0x1C + index
0x01810    96 02 e0 01    inc  %o3
0x01814    80 a2 e0 03    cmp  %o3, 3
0x01818    04 bf ff fa    ble  0x1800
0x0181C    d4 2a 20 26    stb  %o2, [ %o0 + 0x26 ]               ! Store byte at destination + index + 0x26
0x01820    d2 03 60 58    ld  [ %o5 + 0x58 ], %o1                ! Load destination pointer
0x01824    90 10 20 02    mov  2, %o0                            ! Set byte value 2
0x01828    d0 2a 60 15    stb  %o0, [ %o1 + 0x15 ]               ! Write value 2 at destination + 0x15
0x0182C    d0 03 60 58    ld  [ %o5 + 0x58 ], %o0                ! Load destination pointer as first argument
0x01830    94 10 00 02    mov  %g2, %o2                          ! Pass local buffer at %fp - 16 as third argument
0x01834    7f ff fe bc    call  0x1324                           ! Call previous controller transfer routine
0x01838    92 10 20 2a    mov  0x2a, %o1                         ! Second argument: 42 (delay slot)
0x0183C    80 a2 20 00    cmp  %o0, 0                            ! Check transfer result
0x01840    12 80 00 2d    bne  0x18f4                            ! Branch on nonzero result
0x01844    b0 10 3f fb    mov  -5, %i0                           ! Set return -5 (delay slot)
0x01848    10 80 00 2b    b  0x18f4                              ! Return 2 on success
0x0184C    b0 10 20 02    mov  2, %i0                            ! Set return 2 (delay slot)
0x01850    10 80 00 29    b  0x18f4                              ! Auxiliary status timeout exit
0x01854    b0 10 3f fc    mov  -4, %i0                           ! Return -4 (delay slot)
0x01858    90 0b 20 ff    and  %o4, 0xff, %o0
0x0185C    80 a2 20 08    cmp  %o0, 8                            ! Check field at +0x0C against 8
0x01860    32 80 00 25    bne,a   0x18f4                         ! Return 0 for other field values
0x01864    b0 10 20 00    clr  %i0
0x01868    11 0c 00 0f    sethi  %hi(0x30003c00), %o0            ! Reference bytes at 0x30003C40
0x0186C    d4 0a 20 40    ldub  [ %o0 + 0x40 ], %o2
0x01870    d2 0e 20 1e    ldub  [ %i0 + 0x1e ], %o1              ! Read input byte at +0x1E
0x01874    80 a2 40 0a    cmp  %o1, %o2                          ! Compare reference byte 0
0x01878    12 80 00 1e    bne  0x18f0
0x0187C    96 12 20 40    or  %o0, 0x40, %o3
0x01880    d2 0e 20 1f    ldub  [ %i0 + 0x1f ], %o1              ! Read input byte at +0x1F
0x01884    d0 0a e0 01    ldub  [ %o3 + 1 ], %o0
0x01888    80 a2 40 08    cmp  %o1, %o0
0x0188C    32 80 00 1a    bne,a   0x18f4
0x01890    b0 10 20 00    clr  %i0
0x01894    d2 0e 20 20    ldub  [ %i0 + 0x20 ], %o1              ! Read input byte at +0x20
0x01898    d0 0a e0 02    ldub  [ %o3 + 2 ], %o0
0x0189C    80 a2 40 08    cmp  %o1, %o0
0x018A0    32 80 00 15    bne,a   0x18f4
0x018A4    b0 10 20 00    clr  %i0
0x018A8    d2 0a e0 03    ldub  [ %o3 + 3 ], %o1                 ! Read reference byte 3
0x018AC    d0 0e 20 21    ldub  [ %i0 + 0x21 ], %o0              ! Read input byte at +0x21
0x018B0    80 a2 00 09    cmp  %o0, %o1
0x018B4    32 80 00 10    bne,a   0x18f4
0x018B8    b0 10 20 00    clr  %i0
0x018BC    11 0c 00 0e    sethi  %hi(0x30003800), %o0            ! RAM base 0x30003800
0x018C0    d4 02 23 48    ld  [ %o0 + 0x348 ], %o2               ! Read reference word at 0x30003B48
0x018C4    d2 0e 20 24    ldub  [ %i0 + 0x24 ], %o1              ! Read input byte at +0x24
0x018C8    91 32 a0 08    srl  %o2, 8, %o0                       ! Extract bits 8–15
0x018CC    90 0a 20 ff    and  %o0, 0xff, %o0                    ! Mask to one byte
0x018D0    80 a2 40 08    cmp  %o1, %o0                          ! Compare byte at +0x24
0x018D4    32 80 00 08    bne,a   0x18f4
0x018D8    b0 10 20 00    clr  %i0
0x018DC    d2 0e 20 25    ldub  [ %i0 + 0x25 ], %o1              ! Read input byte at +0x25
0x018E0    90 0a a0 ff    and  %o2, 0xff, %o0                    ! Extract low byte
0x018E4    80 a2 40 08    cmp  %o1, %o0                          ! Compare byte at +0x25
0x018E8    02 80 00 03    be  0x18f4                             ! Return 3 when both bytes match
0x018EC    b0 10 20 03    mov  3, %i0                            ! Set return 3 (delay slot)
0x018F0    b0 10 20 00    clr  %i0                               ! Return 0
0x018F4    81 c7 e0 08    ret                                    ! Return to caller
0x018F8    81 e8 00 00    restore                                ! Restore register window

! 0x18FC–0x1964: Parse dot-separated decimal values
! Steps:
! 1. Read decimal digits from the input string.
! 2. Accumulate each value using multiplication by 10.
! 3. Store the accumulated byte on '.' or NUL.
! 4. Continue until the input string ends.
!
! Arguments:
! %o0 = destination byte array
! %o1 = NUL-terminated input string

0x018FC    98 10 20 00    clr   %o4                              ! Destination index
0x01900    96 10 20 00    clr   %o3                              ! Decimal accumulator
0x01904    c6 4a 40 00    ldsb  [%o1], %g3                       ! Read current character
0x01908    80 a0 e0 2e    cmp   %g3, 0x2e                        ! ASCII '.'
0x0190C    02 80 00 06    be    0x1924                           ! Store accumulated byte
0x01910    c4 0a 40 00    ldub  [%o1], %g2                       ! Delay slot: unsigned character
0x01914    84 00 bf d0    add   %g2, -48, %g2                    ! Character minus ASCII '0'
0x01918    80 a0 e0 00    cmp   %g3, 0                           ! End of string?
0x0191C    12 80 00 06    bne   0x1934                           ! Process non-NUL character
0x01920    94 08 a0 ff    and   %g2, 0xff, %o2                   ! Candidate digit (delay slot)
0x01924    d6 2a 00 0c    stb   %o3, [%o0 + %o4]                 ! Store accumulated value
0x01928    98 03 20 01    inc   %o4                              ! Next destination byte
0x0192C    10 80 00 09    b     0x1950
0x01930    96 10 20 00    clr   %o3                              ! Reset accumulator
0x01934    85 2a e0 03    sll   %o3, 3, %g2                      ! Accumulator * 8
0x01938    84 00 80 0b    add   %g2, %o3, %g2                    ! Accumulator * 9
0x0193C    84 00 80 0b    add   %g2, %o3, %g2                    ! Accumulator * 10
0x01940    80 a2 a0 09    cmp   %o2, 9                           ! Check digit range
0x01944    18 80 00 03    bgu   0x1950                           ! Ignore invalid character
0x01948    84 00 bf d0    add   %g2, -48, %g2                    ! Prepare decimal adjustment
0x0194C    96 00 80 03    add   %g2, %g3, %o3                    ! Accumulator = old * 10 + digit
0x01950    c4 4a 40 00    ldsb  [%o1], %g2
0x01954    80 a0 a0 00    cmp   %g2, 0
0x01958    12 bf ff eb    bne   0x1904                           ! Continue until NUL
0x0195C    92 02 60 01    inc   %o1                              ! Advance input pointer
0x01960    81 c3 e0 08    retl
0x01964    01 00 00 00    nop


! 0x1968–0x1A08: Parse colon-separated hexadecimal values
! Steps:
! 1. Read hexadecimal digits (0–9, a–f, A–F).
! 2. Shift the accumulator left by four bits per digit.
! 3. Store a byte on ':' or NUL.
! 4. Continue until the input string ends.
!
! Arguments:
! %o0 = destination byte array
! %o1 = NUL-terminated input string

0x01968    88 10 20 00    clr   %g4                              ! Destination index
0x0196C    82 10 20 00    clr   %g1                              ! Hex accumulator
0x01970    d6 4a 40 00    ldsb  [%o1], %o3
0x01974    80 a2 e0 3a    cmp   %o3, 0x3a                        ! ASCII ':'
0x01978    02 80 00 06    be    0x1990                           ! Store accumulated byte
0x0197C    d4 0a 40 00    ldub  [%o1], %o2
0x01980    84 02 bf d0    add   %o2, -48, %g2                    ! Candidate decimal digit
0x01984    80 a2 e0 00    cmp   %o3, 0
0x01988    12 80 00 06    bne   0x19a0
0x0198C    98 08 a0 ff    and   %g2, 0xff, %o4
0x01990    c2 2a 00 04    stb   %g1, [%o0 + %g4]                 ! Store accumulated byte
0x01994    88 01 20 01    inc   %g4                              ! Next output position
0x01998    10 80 00 17    b     0x19f4
0x0199C    82 10 20 00    clr   %g1                              ! Reset accumulator
0x019A0    85 28 60 04    sll   %g1, 4, %g2                      ! Accumulator * 16
0x019A4    86 02 bf 9f    add   %o2, -97, %g3                    ! Candidate lowercase a–f
0x019A8    84 00 bf d0    add   %g2, -48, %g2
0x019AC    80 a3 20 09    cmp   %o4, 9
0x019B0    18 80 00 04    bgu   0x19c0                           ! Not a decimal digit
0x019B4    9a 08 e0 ff    and   %g3, 0xff, %o5
0x019B8    10 80 00 0f    b     0x19f4
0x019BC    82 00 80 0b    add   %g2, %o3, %g1                    ! Append decimal hex digit
0x019C0    85 28 60 04    sll   %g1, 4, %g2
0x019C4    86 02 bf bf    add   %o2, -65, %g3                    ! Candidate uppercase A–F
0x019C8    84 00 80 0b    add   %g2, %o3, %g2
0x019CC    80 a3 60 05    cmp   %o5, 5
0x019D0    18 80 00 04    bgu   0x19e0                           ! Not lowercase a–f
0x019D4    86 08 e0 ff    and   %g3, 0xff, %g3
0x019D8    10 80 00 07    b     0x19f4
0x019DC    82 00 bf a9    add   %g2, -87, %g1                    ! Append lowercase hex digit
0x019E0    85 28 60 04    sll   %g1, 4, %g2
0x019E4    80 a0 e0 05    cmp   %g3, 5
0x019E8    18 80 00 03    bgu   0x19f4                           ! Ignore invalid character
0x019EC    84 00 80 0b    add   %g2, %o3, %g2
0x019F0    82 00 bf c9    add   %g2, -55, %g1                    ! Append uppercase hex digit
0x019F4    c4 4a 40 00    ldsb  [%o1], %g2
0x019F8    80 a0 a0 00    cmp   %g2, 0
0x019FC    12 bf ff dd    bne   0x1970
0x01A00    92 02 60 01    inc   %o1                              ! Advance input pointer
0x01A04    81 c3 e0 08    retl
0x01A08    01 00 00 00    nop


! 0x1A0C–0x1BAC: Prepare and execute a controller transfer sequence
! Steps:
! 1. Copy a 42-byte template into the active transfer buffer.
! 2. Populate selected fields from stored configuration values.
! 3. Clear a second 42-byte buffer.
! 4. Execute two initial transfers using routine 0x1324.
! 5. Poll for a matching response using routine 0x149C.
! 6. Retry up to the caller-supplied attempt limit.
!
! Arguments:
! %i0 = maximum number of outer attempts
!
! RAM:
! 0x30003B40 = source configuration bytes
! 0x30003B60 = 42-byte transfer template
! 0x30003C40 = four-byte stored identifier
! 0x30003C48 = four-byte stored configuration value
! 0x30003C58 = pointer to active transfer buffer
! 0x30003C5C = pointer to secondary buffer

0x01A0C    9d e3 bf 88    save  %sp, -120, %sp
0x01A10    a8 10 20 00    clr   %l4                              ! Outer attempt counter
0x01A14    80 a5 00 18    cmp   %l4, %i0
0x01A18    36 80 00 64    bge,a 0x1ba8                           ! Attempt limit reached
0x01A1C    b0 10 20 02    mov   2, %i0                           ! Return 2 (annulled delay slot)
0x01A20    11 0c 00 0e    sethi %hi(0x30003800), %o0
0x01A24    ac 12 23 60    or    %o0, 0x360, %l6                  ! Template at 0x30003B60
0x01A28    27 0c 00 0f    sethi %hi(0x30003c00), %l3
0x01A2C    aa 07 bf f0    add   %fp, -16, %l5                    ! Local result buffer

0x01A30    94 10 20 00    clr   %o2                              ! Copy index
0x01A34    d2 0d 80 0a    ldub  [%l6 + %o2], %o1                 ! Read template byte
0x01A38    d0 04 e0 58    ld    [%l3 + 0x58], %o0                ! Active buffer pointer
0x01A3C    d2 2a 00 0a    stb   %o1, [%o0 + %o2]                 ! Copy template byte
0x01A40    94 02 a0 01    inc   %o2
0x01A44    80 a2 a0 2a    cmp   %o2, 0x2a                        ! 42 bytes
0x01A48    26 bf ff fc    bl,a 0x1a38
0x01A4C    d2 0d 80 0a    ldub  [%l6 + %o2], %o1

0x01A50    11 0c 00 0e    sethi %hi(0x30003800), %o0
0x01A54    98 12 23 40    or    %o0, 0x340, %o4                  ! Source at 0x30003B40
0x01A58    94 10 20 00    clr   %o2
0x01A5C    17 0c 00 0f    sethi %hi(0x30003c00), %o3
0x01A60    d0 02 e0 58    ld    [%o3 + 0x58], %o0
0x01A64    d2 0b 00 0a    ldub  [%o4 + %o2], %o1
0x01A68    90 02 80 08    add   %o2, %o0, %o0
0x01A6C    94 02 a0 01    inc   %o2
0x01A70    80 a2 a0 05    cmp   %o2, 5
0x01A74    04 bf ff fb    ble   0x1a60
0x01A78    d2 2a 20 06    stb   %o1, [%o0 + 6]                   ! Copy six bytes to offset 6

0x01A7C    11 0c 00 0e    sethi %hi(0x30003800), %o0
0x01A80    98 12 23 40    or    %o0, 0x340, %o4
0x01A84    94 10 20 00    clr   %o2
0x01A88    17 0c 00 0f    sethi %hi(0x30003c00), %o3
0x01A8C    d0 02 e0 58    ld    [%o3 + 0x58], %o0
0x01A90    d2 0b 00 0a    ldub  [%o4 + %o2], %o1
0x01A94    90 02 80 08    add   %o2, %o0, %o0
0x01A98    94 02 a0 01    inc   %o2
0x01A9C    80 a2 a0 05    cmp   %o2, 5
0x01AA0    04 bf ff fb    ble   0x1a8c
0x01AA4    d2 2a 20 16    stb   %o1, [%o0 + 0x16]                ! Copy six bytes to offset 0x16

0x01AA8    11 0c 00 0f    sethi %hi(0x30003c00), %o0
0x01AAC    98 12 20 40    or    %o0, 0x40, %o4                   ! Identifier at 0x30003C40
0x01AB0    94 10 20 00    clr   %o2
0x01AB4    17 0c 00 0f    sethi %hi(0x30003c00), %o3
0x01AB8    d0 02 e0 58    ld    [%o3 + 0x58], %o0
0x01ABC    d2 0b 00 0a    ldub  [%o4 + %o2], %o1
0x01AC0    90 02 80 08    add   %o2, %o0, %o0
0x01AC4    94 02 a0 01    inc   %o2
0x01AC8    80 a2 a0 03    cmp   %o2, 3
0x01ACC    04 bf ff fb    ble   0x1ab8
0x01AD0    d2 2a 20 1c    stb   %o1, [%o0 + 0x1c]                ! Copy four identifier bytes

0x01AD4    11 0c 00 0f    sethi %hi(0x30003c00), %o0
0x01AD8    98 12 20 48    or    %o0, 0x48, %o4                   ! Configuration at 0x30003C48
0x01ADC    94 10 20 00    clr   %o2
0x01AE0    17 0c 00 0f    sethi %hi(0x30003c00), %o3
0x01AE4    d0 02 e0 58    ld    [%o3 + 0x58], %o0
0x01AE8    d2 0b 00 0a    ldub  [%o4 + %o2], %o1
0x01AEC    90 02 80 08    add   %o2, %o0, %o0
0x01AF0    94 02 a0 01    inc   %o2
0x01AF4    80 a2 a0 03    cmp   %o2, 3
0x01AF8    04 bf ff fb    ble   0x1ae4
0x01AFC    d2 2a 20 26    stb   %o1, [%o0 + 0x26]                ! Copy four configuration bytes

0x01B00    94 10 20 00    clr   %o2
0x01B04    13 0c 00 0f    sethi %hi(0x30003c00), %o1
0x01B08    d0 02 60 5c    ld    [%o1 + 0x5c], %o0                ! Secondary buffer pointer
0x01B0C    c0 2a 00 0a    clrb  [%o0 + %o2]                      ! Clear buffer byte
0x01B10    94 02 a0 01    inc   %o2
0x01B14    80 a2 a0 2a    cmp   %o2, 0x2a
0x01B18    06 bf ff fd    bl    0x1b0c
0x01B1C    d0 02 60 5c    ld    [%o1 + 0x5c], %o0

0x01B20    d0 04 e0 58    ld    [%l3 + 0x58], %o0
0x01B24    92 10 20 2a    mov   0x2a, %o1                        ! Transfer length: 42
0x01B28    7f ff fd ff    call  0x1324                           ! First controller transfer
0x01B2C    94 10 00 15    mov   %l5, %o2                         ! Local result buffer
0x01B30    80 a2 20 00    cmp   %o0, 0
0x01B34    32 80 00 19    bne,a 0x1b98                           ! Retry outer attempt on failure
0x01B38    a8 05 20 01    inc   %l4

0x01B3C    d0 04 e0 58    ld    [%l3 + 0x58], %o0
0x01B40    92 10 20 2a    mov   0x2a, %o1
0x01B44    7f ff fd f8    call  0x1324                           ! Second controller transfer
0x01B48    94 10 00 15    mov   %l5, %o2
0x01B4C    80 a2 20 00    cmp   %o0, 0
0x01B50    32 80 00 12    bne,a 0x1b98                           ! Retry on failure
0x01B54    a8 05 20 01    inc   %l4

0x01B58    a0 10 20 01    mov   1, %l0                           ! Inner attempt counter
0x01B5C    25 0c 00 0f    sethi %hi(0x30003c00), %l2
0x01B60    a2 07 bf e8    add   %fp, -24, %l1                    ! Local response buffer
0x01B64    d0 04 a0 5c    ld    [%l2 + 0x5c], %o0                ! Secondary buffer
0x01B68    92 10 28 00    mov   0x800, %o1                       ! Transfer configuration
0x01B6C    7f ff fe 4c    call  0x149c                           ! Receive and validate response
0x01B70    94 10 00 11    mov   %l1, %o2                         ! Local result buffer
0x01B74    80 a2 20 01    cmp   %o0, 1                           ! Expected return value
0x01B78    12 80 00 04    bne   0x1b88                           ! Continue if not matched
0x01B7C    90 10 00 10    mov   %l0, %o0                         ! Prepare inner counter
0x01B80    10 80 00 0a    b     0x1ba8                           ! Success
0x01B84    b0 10 20 00    clr   %i0                              ! Return 0
0x01B88    80 a2 20 20    cmp   %o0, 0x20                        ! Compare result with 32
0x01B8C    04 bf ff f6    ble   0x1b64                           ! Retry while condition holds
0x01B90    a0 04 20 01    inc   %l0                              ! Increment counter (delay slot)
0x01B94    a8 05 20 01    inc   %l4                              ! Next outer attempt
0x01B98    80 a5 00 18    cmp   %l4, %i0
0x01B9C    06 bf ff a6    bl    0x1a34                           ! Retry from template copy
0x01BA0    94 10 20 00    clr   %o2
0x01BA4    b0 10 20 02    mov   2, %i0                           ! Attempts exhausted
0x01BA8    81 c7 e0 08    ret
0x01BAC    81 e8 00 00    restore

! 0x1BB0–0x1DAC: Build and transmit a network frame
! Steps:
! 1. Copy a 42-byte frame template into the transmit buffer.
! 2. Append the caller's payload at offset 0x2A.
! 3. Populate length, protocol and address fields.
! 4. Transmit the frame through routine 0x1324.
! 5. Optionally wait for a response through routine 0x149C.
!
! Arguments:
! %i0 = pointer to payload data
! %i1 = 16-bit field written at offsets 0x22–0x23
! %i2 = 16-bit field written at offsets 0x24–0x25
! %i3 = payload length
! %i4 = transmission/response flags
!
! RAM:
! 0x30003BA0 = 42-byte frame template
! 0x30003B40 = six-byte address
! 0x30003C40 = four-byte address
! 0x30003C48 = four-byte address
! 0x30003C50 = six-byte address
! 0x30003C58 = pointer to transmit buffer
! 0x30003C5C = pointer to receive buffer

0x01BB0    9d e3 bf 88    save  %sp, -120, %sp
0x01BB4    19 0c 00 0f    sethi %hi(0x30003c00), %o4
0x01BB8    11 0c 00 0e    sethi %hi(0x30003800), %o0
0x01BBC    9a 12 23 a0    or    %o0, 0x3a0, %o5                  ! Frame template: 0x30003BA0
0x01BC0    94 10 00 0c    mov   %o4, %o2
0x01BC4    96 10 20 00    clr   %o3                              ! Template copy index
0x01BC8    d2 0b 40 0b    ldub  [%o5 + %o3], %o1                 ! Read template byte
0x01BCC    d0 02 a0 58    ld    [%o2 + 0x58], %o0                ! Load transmit buffer pointer
0x01BD0    d2 2a 00 0b    stb   %o1, [%o0 + %o3]                 ! Copy byte to transmit buffer
0x01BD4    96 02 e0 01    inc   %o3
0x01BD8    80 a2 e0 29    cmp   %o3, 0x29                        ! Last template offset: 41
0x01BDC    24 bf ff fc    ble,a 0x1bcc                           ! Continue copying 42 bytes
0x01BE0    d2 0b 40 0b    ldub  [%o5 + %o3], %o1                 ! Prefetch next byte (annulled slot)

! 0x1BE4–0x1C20: Append caller-supplied payload

0x01BE4    96 10 20 00    clr   %o3                              ! Payload index
0x01BE8    80 a2 c0 1b    cmp   %o3, %i3                         ! Check payload length
0x01BEC    9a 06 e0 08    add   %i3, 8, %o5                      ! Length + 8
0x01BF0    85 3e a0 08    sra   %i2, 8, %g2                      ! High byte of argument 2
0x01BF4    9f 3e 60 08    sra   %i1, 8, %o7                      ! High byte of argument 1
0x01BF8    82 06 e0 1c    add   %i3, 0x1c, %g1                   ! Length + 28
0x01BFC    16 80 00 0a    bge   0x1c24                           ! Skip if payload length <= 0
0x01C00    88 0f 20 01    and   %i4, 1, %g4                      ! Extract flag bit 0
0x01C04    15 0c 00 0f    sethi %hi(0x30003c00), %o2
0x01C08    d0 02 a0 58    ld    [%o2 + 0x58], %o0                ! Transmit buffer pointer
0x01C0C    d2 0e 00 0b    ldub  [%i0 + %o3], %o1                 ! Read payload byte
0x01C10    90 02 c0 08    add   %o3, %o0, %o0
0x01C14    96 02 e0 01    inc   %o3
0x01C18    80 a2 c0 1b    cmp   %o3, %i3
0x01C1C    06 bf ff fb    bl    0x1c08                           ! Copy remaining payload bytes
0x01C20    d2 2a 20 2a    stb   %o1, [%o0 + 0x2a]                ! Write payload at offset 42

! 0x1C24–0x1C80: Populate protocol length and address fields

0x01C24    d2 03 20 58    ld    [%o4 + 0x58], %o1
0x01C28    91 3b 60 08    sra   %o5, 8, %o0
0x01C2C    d0 2a 60 26    stb   %o0, [%o1 + 0x26]                ! UDP length high byte
0x01C30    d4 03 20 58    ld    [%o4 + 0x58], %o2
0x01C34    13 0c 00 0f    sethi %hi(0x30003c00), %o1
0x01C38    da 2a a0 27    stb   %o5, [%o2 + 0x27]                ! UDP length low byte
0x01C3C    d0 03 20 58    ld    [%o4 + 0x58], %o0
0x01C40    86 12 60 48    or    %o1, 0x48, %g3                   ! Stored IPv4 address
0x01C44    c4 2a 20 24    stb   %g2, [%o0 + 0x24]                ! UDP field high byte
0x01C48    d2 03 20 58    ld    [%o4 + 0x58], %o1
0x01C4C    96 10 20 00    clr   %o3
0x01C50    f4 2a 60 25    stb   %i2, [%o1 + 0x25]                ! UDP field low byte
0x01C54    d4 03 20 58    ld    [%o4 + 0x58], %o2
0x01C58    9a 10 00 0c    mov   %o4, %o5
0x01C5C    de 2a a0 22    stb   %o7, [%o2 + 0x22]                ! UDP field high byte
0x01C60    d0 03 20 58    ld    [%o4 + 0x58], %o0
0x01C64    f2 2a 20 23    stb   %i1, [%o0 + 0x23]                ! UDP field low byte
0x01C68    d0 03 60 58    ld    [%o5 + 0x58], %o0
0x01C6C    d2 08 c0 0b    ldub  [%g3 + %o3], %o1                 ! Read IPv4 address byte
0x01C70    90 02 c0 08    add   %o3, %o0, %o0
0x01C74    96 02 e0 01    inc   %o3
0x01C78    80 a2 e0 03    cmp   %o3, 3
0x01C7C    04 bf ff fb    ble   0x1c68
0x01C80    d2 2a 20 1e    stb   %o1, [%o0 + 0x1e]                ! Copy four IPv4 address bytes

! 0x1C84–0x1D18: Populate remaining frame header fields

0x01C84    11 0c 00 0f    sethi %hi(0x30003c00), %o0
0x01C88    9a 12 20 40    or    %o0, 0x40, %o5                   ! Stored IPv4 address
0x01C8C    96 10 20 00    clr   %o3
0x01C90    15 0c 00 0f    sethi %hi(0x30003c00), %o2
0x01C94    d0 02 a0 58    ld    [%o2 + 0x58], %o0
0x01C98    d2 0b 40 0b    ldub  [%o5 + %o3], %o1
0x01C9C    90 02 c0 08    add   %o3, %o0, %o0
0x01CA0    96 02 e0 01    inc   %o3
0x01CA4    80 a2 e0 03    cmp   %o3, 3
0x01CA8    04 bf ff fb    ble   0x1c94
0x01CAC    d2 2a 20 1a    stb   %o1, [%o0 + 0x1a]                ! Copy four address bytes
0x01CB0    d2 03 20 58    ld    [%o4 + 0x58], %o1
0x01CB4    91 38 60 08    sra   %g1, 8, %o0
0x01CB8    d0 2a 60 10    stb   %o0, [%o1 + 0x10]                ! IP total length high byte
0x01CBC    d4 03 20 58    ld    [%o4 + 0x58], %o2
0x01CC0    11 0c 00 0f    sethi %hi(0x30003c00), %o0
0x01CC4    c2 2a a0 11    stb   %g1, [%o2 + 0x11]                ! IP total length low byte

! 0x1CC8–0x1D18: Copy MAC addresses

0x01CC8    9a 12 20 50    or    %o0, 0x50, %o5                   ! MAC address at 0x30003C50
0x01CCC    96 10 20 00    clr   %o3
0x01CD0    94 10 00 0c    mov   %o4, %o2
0x01CD4    d2 0b 40 0b    ldub  [%o5 + %o3], %o1
0x01CD8    d0 02 a0 58    ld    [%o2 + 0x58], %o0
0x01CDC    d2 2a 00 0b    stb   %o1, [%o0 + %o3]                 ! Destination MAC byte
0x01CE0    96 02 e0 01    inc   %o3
0x01CE4    80 a2 e0 05    cmp   %o3, 5
0x01CE8    24 bf ff fc    ble,a 0x1cd8
0x01CEC    d2 0b 40 0b    ldub  [%o5 + %o3], %o1

0x01CF0    11 0c 00 0e    sethi %hi(0x30003800), %o0
0x01CF4    9a 12 23 40    or    %o0, 0x340, %o5                  ! MAC address at 0x30003B40
0x01CF8    96 10 20 00    clr   %o3
0x01CFC    15 0c 00 0f    sethi %hi(0x30003c00), %o2
0x01D00    d0 02 a0 58    ld    [%o2 + 0x58], %o0
0x01D04    d2 0b 40 0b    ldub  [%o5 + %o3], %o1
0x01D08    90 02 c0 08    add   %o3, %o0, %o0
0x01D0C    96 02 e0 01    inc   %o3
0x01D10    80 a2 e0 05    cmp   %o3, 5
0x01D14    04 bf ff fb    ble   0x1d00
0x01D18    d2 2a 20 06    stb   %o1, [%o0 + 6]                   ! Source MAC byte

! 0x1D1C–0x1DAC: Transmit frame and optionally await a response

0x01D1C    80 a1 20 00    cmp   %g4, 0                           ! Test flag bit 0
0x01D20    12 80 00 09    bne   0x1d44                           ! Use response-handling path
0x01D24    80 8f 20 02    btst  2, %i4                           ! Test flag bit 1 (delay slot)
0x01D28    d0 03 20 58    ld    [%o4 + 0x58], %o0                ! Transmit buffer
0x01D2C    92 06 e0 2a    add   %i3, 0x2a, %o1                   ! Total frame length
0x01D30    7f ff fd 7d    call  0x1324                           ! Transmit frame
0x01D34    94 07 bf f0    add   %fp, -16, %o2                    ! Local result buffer
0x01D38    80 a0 00 08    cmp   %g0, %o0                         ! Compare return value with zero
0x01D3C    10 80 00 1b    b     0x1da8
0x01D40    b0 40 20 00    addx  %g0, 0, %i0                      ! Return 1 if transfer returned < 0

0x01D44    02 80 00 0b    be    0x1d70                           ! Skip transmit when flag bit 1 clear
0x01D48    d0 03 20 58    ld    [%o4 + 0x58], %o0
0x01D4C    92 06 e0 2a    add   %i3, 0x2a, %o1
0x01D50    7f ff fd 75    call  0x1324                           ! Transmit frame
0x01D54    94 07 bf f0    add   %fp, -16, %o2
0x01D58    80 a2 20 00    cmp   %o0, 0
0x01D5C    02 80 00 05    be    0x1d70                           ! Transfer successful
0x01D60    b0 10 20 01    mov   1, %i0                           ! Prepare failure return
0x01D64    30 80 00 11    b,a   0x1da8                           ! Return on transfer failure
0x01D68    10 80 00 10    b     0x1da8
0x01D6C    b0 10 20 00    clr   %i0                              ! Return 0
0x01D70    b0 10 20 01    mov   1, %i0                           ! Response attempt counter
0x01D74    35 0c 00 0f    sethi %hi(0x30003c00), %i2
0x01D78    b2 07 bf e8    add   %fp, -24, %i1                    ! Local response buffer
0x01D7C    d0 06 a0 5c    ld    [%i2 + 0x5c], %o0                ! Receive buffer pointer
0x01D80    92 10 28 00    mov   0x800, %o1
0x01D84    7f ff fd c6    call  0x149c                           ! Receive and inspect response
0x01D88    94 10 00 19    mov   %i1, %o2
0x01D8C    80 a2 20 03    cmp   %o0, 3                           ! Expected response status
0x01D90    02 bf ff f6    be    0x1d68                           ! Return success if matched
0x01D94    90 10 00 18    mov   %i0, %o0                         ! Delay slot: attempt counter
0x01D98    80 a2 20 20    cmp   %o0, 0x20
0x01D9C    04 bf ff f8    ble   0x1d7c                           ! Retry up to 32 attempts
0x01DA0    b0 06 20 01    inc   %i0                              ! Increment attempt counter
0x01DA4    b0 10 20 01    mov   1, %i0                           ! Return failure
0x01DA8    81 c7 e0 08    ret
0x01DAC    81 e8 00 00    restore

! 0x1DB0: Initialize network controller and transfer buffers
! 1. Reset controller state and configure MMIO.
! 2. Assign transmit and receive buffers.
! 3. Validate arguments and parse network addresses.

0x01DB0    9d e3 be 98    save  %sp, -360, %sp                   ! Allocate 360-byte stack frame
0x01DB4    15 08 00 0a    sethi  %hi(0x20002800), %o2
0x01DB8    90 10 20 0b    mov  0xb, %o0
0x01DBC    d0 22 80 00    st  %o0, [ %o2 ]                       ! Write 0x0B to MMIO 0x20002800
0x01DC0    1b 08 00 41    sethi  %hi(0x20010400), %o5
0x01DC4    d0 03 40 00    ld  [ %o5 ], %o0                       ! Read controller control register
0x01DC8    13 00 00 20    sethi  %hi(0x8000), %o1
0x01DCC    90 12 20 40    or  %o0, 0x40, %o0                     ! Set bit 6
0x01DD0    d0 23 40 00    st  %o0, [ %o5 ]
0x01DD4    92 12 60 0b    or  %o1, 0xb, %o1
0x01DD8    d2 22 80 00    st  %o1, [ %o2 ]                       ! Write 0x800B to MMIO
0x01DDC    d2 03 40 00    ld  [ %o5 ], %o1
0x01DE0    19 0c 00 0e    sethi  %hi(0x30003800), %o4
0x01DE4    d6 03 23 48    ld  [ %o4 + 0x348 ], %o3
0x01DE8    15 0c 00 0f    sethi  %hi(0x30003c00), %o2
0x01DEC    11 21 e0 02    sethi  %hi(0x87800800), %o0
0x01DF0    92 0a 7f bf    and  %o1, -65, %o1                     ! Clear bit 6
0x01DF4    d0 22 a0 58    st  %o0, [ %o2 + 0x58 ]                ! Set transmit buffer pointer to 0x87800800
0x01DF8    07 0c 00 0f    sethi  %hi(0x30003c00), %g3
0x01DFC    d2 23 40 00    st  %o1, [ %o5 ]
0x01E00    96 02 e0 01    inc  %o3
0x01E04    05 21 e0 00    sethi  %hi(0x87800000), %g2
0x01E08    aa 10 00 0c    mov  %o4, %l5
0x01E0C    ac 10 00 03    mov  %g3, %l6
0x01E10    d6 23 23 48    st  %o3, [ %o4 + 0x348 ]               ! Update persistent counter
0x01E14    80 a6 20 06    cmp  %i0, 6                            ! Require six arguments
0x01E18    12 80 00 3c    bne  0x1f08
0x01E1C    c4 20 e0 5c    st  %g2, [ %g3 + 0x5c ]                ! Set receive buffer pointer to 0x87800000 (delay slot)

! 0x1E20: Parse MAC address, IPv4 addresses, and numeric argument
! 1. Parse colon-separated MAC address.
! 2. Parse two dot-separated IPv4 addresses.
! 3. Convert numeric argument and inspect stored network configuration.

0x01E20    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x01E24    d2 06 60 04    ld  [ %i1 + 4 ], %o1                   ! Load MAC address string
0x01E28    a6 12 23 40    or  %o0, 0x340, %l3
0x01E2C    7f ff fe cf    call  0x1968                           ! Parse colon-separated hexadecimal bytes
0x01E30    90 10 00 13    mov  %l3, %o0
0x01E34    23 0c 00 0f    sethi  %hi(0x30003c00), %l1
0x01E38    d2 06 60 08    ld  [ %i1 + 8 ], %o1                   ! Load first IPv4 address string
0x01E3C    a0 14 60 40    or  %l1, 0x40, %l0
0x01E40    7f ff fe af    call  0x18fc                           ! Parse dotted-decimal bytes
0x01E44    90 10 00 10    mov  %l0, %o0
0x01E48    d2 06 60 0c    ld  [ %i1 + 0xc ], %o1                 ! Load second IPv4 address string
0x01E4C    11 0c 00 0f    sethi  %hi(0x30003c00), %o0
0x01E50    7f ff fe ab    call  0x18fc                           ! Parse dotted-decimal bytes
0x01E54    90 12 20 48    or  %o0, 0x48, %o0
0x01E58    ee 06 60 10    ld  [ %i1 + 0x10 ], %l7                ! Save pointer to request string
0x01E5C    92 10 20 00    clr  %o1
0x01E60    d0 06 60 14    ld  [ %i1 + 0x14 ], %o0                ! Load numeric argument string
0x01E64    7f ff fa 83    call  0x870                            ! Convert string to integer
0x01E68    94 10 20 00    clr  %o2
0x01E6C    d2 0c 20 02    ldub  [ %l0 + 2 ], %o1
0x01E70    b0 10 00 08    mov  %o0, %i0
0x01E74    80 a2 60 7d    cmp  %o1, 0x7d                         ! Check address byte against 0x7D
0x01E78    12 80 00 26    bne  0x1f10
0x01E7C    a4 10 00 18    mov  %i0, %l2

! 0x1E80: Inspect stored network configuration
! 1. Compare bytes and update selected network address fields.

0x01E80    11 0c 00 0f    sethi  %hi(0x30003c00), %o0
0x01E84    d2 0a 20 80    ldub  [ %o0 + 0x80 ], %o1              ! Read stored configuration byte
0x01E88    98 10 00 08    mov  %o0, %o4
0x01E8C    80 a2 60 00    cmp  %o1, 0
0x01E90    12 80 00 20    bne  0x1f10
0x01E94    94 12 20 80    or  %o0, 0x80, %o2
0x01E98    d0 0a a0 01    ldub  [ %o2 + 1 ], %o0
0x01E9C    80 a2 20 0d    cmp  %o0, 0xd                          ! Check byte against 0x0D
0x01EA0    12 80 00 1c    bne  0x1f10
0x01EA4    01 00 00 00    nop
0x01EA8    d0 0a a0 02    ldub  [ %o2 + 2 ], %o0
0x01EAC    80 a2 20 a2    cmp  %o0, 0xa2                         ! Check byte against 0xA2
0x01EB0    12 80 00 18    bne  0x1f10
0x01EB4    92 10 00 0a    mov  %o2, %o1
0x01EB8    96 10 00 13    mov  %l3, %o3
0x01EBC    94 10 20 00    clr  %o2
0x01EC0    d0 0a 40 0a    ldub  [ %o1 + %o2 ], %o0               ! Copy byte from stored configuration
0x01EC4    d0 2a c0 0a    stb  %o0, [ %o3 + %o2 ]
0x01EC8    94 02 a0 01    inc  %o2
0x01ECC    80 a2 a0 05    cmp  %o2, 5
0x01ED0    24 bf ff fd    ble,a   0x1ec4                         ! Repeat for six bytes
0x01ED4    d0 0a 40 0a    ldub  [ %o1 + %o2 ], %o0
0x01ED8    90 13 20 80    or  %o4, 0x80, %o0
0x01EDC    d0 0a 20 05    ldub  [ %o0 + 5 ], %o0
0x01EE0    92 0a 20 ff    and  %o0, 0xff, %o1
0x01EE4    80 a2 60 09    cmp  %o1, 9                            ! Compare byte with 9
0x01EE8    08 80 00 05    bleu  0x1efc
0x01EEC    a2 14 60 40    or  %l1, 0x40, %l1
0x01EF0    80 a2 60 fd    cmp  %o1, 0xfd                         ! Compare byte with 0xFD
0x01EF4    28 80 00 07    bleu,a   0x1f10
0x01EF8    d0 2c 60 03    stb  %o0, [ %l1 + 3 ]
0x01EFC    90 02 3f 80    add  %o0, -128, %o0
0x01F00    10 80 00 04    b  0x1f10
0x01F04    d0 2c 60 03    stb  %o0, [ %l1 + 3 ]
0x01F08    10 80 00 a7    b  0x21a4                              ! Return status 1 for invalid argument count
0x01F0C    b0 10 20 01    mov  1, %i0

! 0x1F10: Perform network setup and prepare a request
! 1. Run setup routine 0x1A0C.
! 2. Build a request payload containing a caller-supplied string and mode suffix.
! 3. Transmit the request through 0x1BB0.

0x01F10    7f ff fe bf    call  0x1a0c                           ! Initialize network via 0x1A0C
0x01F14    90 10 20 0a    mov  0xa, %o0
0x01F18    80 a2 20 00    cmp  %o0, 0                            ! Test initialization result
0x01F1C    02 80 00 04    be  0x1f2c
0x01F20    90 07 be f8    add  %fp, -264, %o0
0x01F24    10 80 00 a0    b  0x21a4                              ! Return status 2 if initialization failed
0x01F28    b0 10 20 02    mov  2, %i0
0x01F2C    94 10 20 01    mov  1, %o2                            ! Initialize local request buffer
0x01F30    c0 2a 00 00    clrb  [ %o0 ]
0x01F34    b2 10 00 08    mov  %o0, %i1
0x01F38    d4 2a 00 0a    stb  %o2, [ %o0 + %o2 ]
0x01F3C    98 10 00 19    mov  %i1, %o4
0x01F40    96 10 00 17    mov  %l7, %o3
0x01F44    94 10 20 02    mov  2, %o2
0x01F48    d0 0a c0 00    ldub  [ %o3 ], %o0                     ! Read request string byte
0x01F4C    93 2a 20 18    sll  %o0, 0x18, %o1
0x01F50    d0 2b 00 0a    stb  %o0, [ %o4 + %o2 ]
0x01F54    80 a2 60 00    cmp  %o1, 0
0x01F58    96 02 e0 01    inc  %o3
0x01F5C    12 bf ff fb    bne  0x1f48                            ! Continue until NUL
0x01F60    94 02 a0 01    inc  %o2
0x01F64    90 10 20 6f    mov  0x6f, %o0                         ! Append 'o'
0x01F68    d0 2e 40 0a    stb  %o0, [ %i1 + %o2 ]
0x01F6C    94 02 a0 01    inc  %o2
0x01F70    90 10 20 63    mov  0x63, %o0                         ! Append 'c'
0x01F74    d0 2e 40 0a    stb  %o0, [ %i1 + %o2 ]
0x01F78    94 02 a0 01    inc  %o2
0x01F7C    92 10 20 74    mov  0x74, %o1                         ! Append 't'
0x01F80    d2 2e 40 0a    stb  %o1, [ %i1 + %o2 ]
0x01F84    94 02 a0 01    inc  %o2
0x01F88    90 10 20 65    mov  0x65, %o0                         ! Append 'e'
0x01F8C    d0 2e 40 0a    stb  %o0, [ %i1 + %o2 ]
0x01F90    94 02 a0 01    inc  %o2
0x01F94    d2 2e 40 0a    stb  %o1, [ %i1 + %o2 ]                ! Append 't'
0x01F98    d2 05 63 48    ld  [ %l5 + 0x348 ], %o1
0x01F9C    94 02 a0 01    inc  %o2
0x01FA0    96 02 a0 01    add  %o2, 1, %o3
0x01FA4    c0 2e 40 0a    clrb  [ %i1 + %o2 ]                    ! Append NUL terminator
0x01FA8    90 10 00 19    mov  %i1, %o0
0x01FAC    94 10 20 45    mov  0x45, %o2
0x01FB0    7f ff ff 00    call  0x1bb0                           ! Send request using 0x1BB0
0x01FB4    98 10 20 03    mov  3, %o4                            ! Flags = 3 (delay slot)
0x01FB8    80 a2 20 00    cmp  %o0, 0
0x01FBC    02 80 00 06    be  0x1fd4
0x01FC0    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x01FC4    7f ff fa 3a    call  0x8ac                            ! Print error message
0x01FC8    90 12 21 70    or  %o0, 0x170, %o0
0x01FCC    10 80 00 76    b  0x21a4                              ! Return status 3
0x01FD0    b0 10 20 03    mov  3, %i0

! 0x1FD4: Receive and validate numbered data blocks
! 1. Check response opcode and block number.
! 2. Request retransmission when a block is missing.
! 3. Copy received data to destination.

0x01FD4    a2 10 20 00    clr  %l1
0x01FD8    a6 10 20 01    mov  1, %l3
0x01FDC    d6 05 a0 5c    ld  [ %l6 + 0x5c ], %o3                ! Load receive buffer pointer
0x01FE0    d0 0a e0 2a    ldub  [ %o3 + 0x2a ], %o0              ! Read response payload opcode high byte
0x01FE4    80 a2 20 00    cmp  %o0, 0
0x01FE8    12 80 00 06    bne  0x2000
0x01FEC    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x01FF0    d0 0a e0 2b    ldub  [ %o3 + 0x2b ], %o0              ! Read response payload opcode low byte
0x01FF4    80 a2 20 03    cmp  %o0, 3
0x01FF8    02 80 00 06    be  0x2010                             ! Check opcode 3 (DATA)
0x01FFC    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x02000    7f ff fa 2b    call  0x8ac                            ! Print unexpected response message
0x02004    90 12 21 78    or  %o0, 0x178, %o0
0x02008    10 80 00 67    b  0x21a4                              ! Return status 4
0x0200C    b0 10 20 04    mov  4, %i0
0x02010    d0 0a e0 2c    ldub  [ %o3 + 0x2c ], %o0              ! Read block number high byte
0x02014    d2 0a e0 2d    ldub  [ %o3 + 0x2d ], %o1              ! Read block number low byte
0x02018    91 2a 20 08    sll  %o0, 8, %o0
0x0201C    94 12 00 09    or  %o0, %o1, %o2
0x02020    80 a2 80 13    cmp  %o2, %l3                          ! Compare received block number with expected
0x02024    16 80 00 09    bge  0x2048
0x02028    d2 05 63 48    ld  [ %l5 + 0x348 ], %o1
0x0202C    90 10 00 19    mov  %i1, %o0                          ! Prepare retransmission request
0x02030    94 10 00 14    mov  %l4, %o2
0x02034    96 10 20 04    mov  4, %o3
0x02038    7f ff fe de    call  0x1bb0                           ! Send response using 0x1BB0
0x0203C    98 10 20 01    mov  1, %o4
0x02040    10 bf ff e8    b  0x1fe0                              ! Check received response again
0x02044    d6 05 a0 5c    ld  [ %l6 + 0x5c ], %o3
0x02048    24 80 00 04    ble,a   0x2058
0x0204C    d0 0a e0 26    ldub  [ %o3 + 0x26 ], %o0
0x02050    10 80 00 55    b  0x21a4                              ! Return status 5 for unexpected block number
0x02054    b0 10 20 05    mov  5, %i0
0x02058    15 3f fc 00    sethi  %hi(0xfff00000), %o2            ! Read UDP length high byte
0x0205C    d2 0a e0 27    ldub  [ %o3 + 0x27 ], %o1
0x02060    91 2a 20 08    sll  %o0, 8, %o0
0x02064    a0 12 00 09    or  %o0, %o1, %l0                      ! Combine UDP length bytes
0x02068    a0 04 3f f4    add  %l0, -12, %l0                     ! Subtract UDP header (8) and TFTP header (4)
0x0206C    a2 04 40 10    add  %l1, %l0, %l1                     ! Add data length to accumulated total
0x02070    80 ac 40 0a    andncc  %l1, %o2, %g0                  ! Test accumulated byte count against 0xFFF00000 mask
0x02074    12 80 00 07    bne  0x2090
0x02078    a6 04 e0 01    inc  %l3
0x0207C    7f ff fa 2e    call  0x934                            ! Print upper byte of total
0x02080    91 34 60 14    srl  %l1, 0x14, %o0
0x02084    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x02088    7f ff fa 09    call  0x8ac                            ! Print progress message
0x0208C    90 12 21 80    or  %o0, 0x180, %o0

! 0x2090: Copy payload data and acknowledge received block
! 1. Copy payload in 16-bit units.
! 2. Build acknowledgment payload and send through 0x1BB0.

0x02090    94 10 20 00    clr  %o2
0x02094    80 a2 80 10    cmp  %o2, %l0                          ! Check whether data remains to copy
0x02098    36 80 00 0c    bge,a   0x20c8
0x0209C    d4 05 a0 5c    ld  [ %l6 + 0x5c ], %o2
0x020A0    96 10 00 16    mov  %l6, %o3
0x020A4    d0 02 e0 5c    ld  [ %o3 + 0x5c ], %o0
0x020A8    90 02 80 08    add  %o2, %o0, %o0
0x020AC    d2 12 20 2e    lduh  [ %o0 + 0x2e ], %o1              ! Read 16-bit data from receive buffer + 0x2E
0x020B0    94 02 a0 02    add  %o2, 2, %o2
0x020B4    d2 34 80 00    sth  %o1, [ %l2 ]                      ! Write 16-bit word to destination
0x020B8    80 a2 80 10    cmp  %o2, %l0
0x020BC    06 bf ff fa    bl  0x20a4
0x020C0    a4 04 a0 02    add  %l2, 2, %l2                       ! Advance destination pointer by two bytes (delay slot)
0x020C4    d4 05 a0 5c    ld  [ %l6 + 0x5c ], %o2
0x020C8    90 10 20 04    mov  4, %o0                            ! Set ACK opcode low byte to 4
0x020CC    d0 2f be f9    stb  %o0, [ %fp + -263 ]
0x020D0    c0 2f be f8    clrb  [ %fp + -264 ]
0x020D4    d2 0a a0 2c    ldub  [ %o2 + 0x2c ], %o1              ! Read block number high byte
0x020D8    80 a4 21 ff    cmp  %l0, 0x1ff
0x020DC    d2 2f be fa    stb  %o1, [ %fp + -262 ]
0x020E0    d0 0a a0 2d    ldub  [ %o2 + 0x2d ], %o0              ! Read block number low byte
0x020E4    d0 2f be fb    stb  %o0, [ %fp + -261 ]
0x020E8    d2 0a a0 22    ldub  [ %o2 + 0x22 ], %o1              ! Read received source UDP port high byte
0x020EC    d0 0a a0 23    ldub  [ %o2 + 0x23 ], %o0              ! Read received source UDP port low byte
0x020F0    93 2a 60 08    sll  %o1, 8, %o1
0x020F4    14 80 00 22    bg  0x217c                             ! Branch if data length > 511
0x020F8    a8 12 40 08    or  %o1, %o0, %l4
0x020FC    d2 05 63 48    ld  [ %l5 + 0x348 ], %o1               ! Load current transaction counter
0x02100    90 10 00 19    mov  %i1, %o0
0x02104    94 10 00 14    mov  %l4, %o2
0x02108    96 10 20 04    mov  4, %o3
0x0210C    7f ff fe a9    call  0x1bb0                           ! Send ACK using 0x1BB0
0x02110    98 10 20 02    mov  2, %o4
0x02114    80 a2 20 00    cmp  %o0, 0                            ! Check send result
0x02118    22 80 00 07    be,a   0x2134
0x0211C    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x02120    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x02124    7f ff f9 e2    call  0x8ac                            ! Print send failure message
0x02128    90 12 21 88    or  %o0, 0x188, %o0
0x0212C    10 80 00 05    b  0x2140
0x02130    80 a4 60 00    cmp  %l1, 0
0x02134    7f ff f9 de    call  0x8ac                            ! Print send success message
0x02138    90 12 21 90    or  %o0, 0x190, %o0
0x0213C    80 a4 60 00    cmp  %l1, 0

! 0x2140: Finalize received data or continue transfer
! 1. Copy accumulated data in chunks.
! 2. Handle final or next-block conditions.

0x02140    22 80 00 19    be,a   0x21a4                          ! Return 0 if no data accumulated
0x02144    b0 10 20 00    clr  %i0
0x02148    80 a4 62 00    cmp  %l1, 0x200                        ! Choose copy chunk size up to 512 bytes
0x0214C    08 80 00 03    bleu  0x2158
0x02150    a0 10 00 11    mov  %l1, %l0
0x02154    a0 10 22 00    mov  0x200, %l0
0x02158    90 10 00 18    mov  %i0, %o0
0x0215C    92 10 00 18    mov  %i0, %o1
0x02160    40 00 04 0c    call  0x3190                           ! Call data-copy routine 0x3190
0x02164    94 10 00 10    mov  %l0, %o2
0x02168    a2 a4 40 10    subcc  %l1, %l0, %l1                   ! Decrease remaining byte count
0x0216C    12 bf ff f7    bne  0x2148
0x02170    b0 06 00 10    add  %i0, %l0, %i0                     ! Advance destination pointer (delay slot)
0x02174    10 80 00 0c    b  0x21a4                              ! Return success after copy
0x02178    b0 10 20 00    clr  %i0
0x0217C    d2 05 63 48    ld  [ %l5 + 0x348 ], %o1               ! Load current transaction counter
0x02180    90 10 00 19    mov  %i1, %o0
0x02184    94 10 00 14    mov  %l4, %o2
0x02188    96 10 20 04    mov  4, %o3
0x0218C    7f ff fe 89    call  0x1bb0                           ! Send alternate ACK using 0x1BB0
0x02190    98 10 20 03    mov  3, %o4
0x02194    80 a2 20 00    cmp  %o0, 0                            ! Retry receiving if send succeeded
0x02198    02 bf ff 92    be  0x1fe0
0x0219C    d6 05 a0 5c    ld  [ %l6 + 0x5c ], %o3
0x021A0    b0 10 20 04    mov  4, %i0                            ! Return status 4
0x021A4    81 c7 e0 08    ret                                    ! Function return
0x021A8    81 e8 00 00    restore                                ! Restore register window

! 0x21AC: NAND logical-to-physical page translation (probable bad-block remapping)
! Input/output: %o0 = NAND page index (inferred from call site 0x2218).
! 0x30003BE4 controls whether the translation table is consulted.
! 0x30003BE0 contains the table pointer; entries appear 4 bytes wide,
! with two 16-bit fields. The low five bits of the input are retained.
! The mapping resembles 32-page groups (32 * 512 = 16 KiB eraseblock).
! Verify the exact lookup/termination behavior before treating it as final.
0x021AC    05 0c 00 0e    sethi  %hi(0x30003800), %g2
0x021B0    c6 00 a3 e4    ld  [ %g2 + 0x3e4 ], %g3               ! 0x30003be4  [Translation-table active flag]
0x021B4    80 a0 e0 00    cmp  %g3, 0
0x021B8    02 80 00 16    be  0x2210
0x021BC    99 3a 20 05    sra  %o0, 5, %o4                       ! Preserve address / 32 as search key (delay slot)
0x021C0    92 10 20 00    clr  %o1
0x021C4    17 0c 00 0e    sethi  %hi(0x30003800), %o3
0x021C8    80 a2 63 ff    cmp  %o1, 0x3ff
0x021CC    14 80 00 0b    bg  0x21f8
0x021D0    95 2a 60 02    sll  %o1, 2, %o2
0x021D4    c6 02 e3 e0    ld  [ %o3 + 0x3e0 ], %g3
0x021D8    05 00 00 3f    sethi  %hi(0xfc00), %g2
0x021DC    c6 10 c0 0a    lduh  [ %g3 + %o2 ], %g3               ! Read table entry identifier
0x021E0    84 10 a3 ff    or  %g2, 0x3ff, %g2
0x021E4    80 a0 c0 02    cmp  %g3, %g2
0x021E8    02 80 00 0a    be  0x2210                             ! 0xffff indicates an unused/end entry
0x021EC    80 a0 c0 0c    cmp  %g3, %o4
0x021F0    32 bf ff f6    bne,a   0x21c8                         ! Annulled loop branch; increment only on taken branch
0x021F4    92 02 60 01    inc  %o1
0x021F8    c4 02 e3 e0    ld  [ %o3 + 0x3e0 ], %g2
0x021FC    86 0a 20 1f    and  %o0, 0x1f, %g3
0x02200    84 00 80 0a    add  %g2, %o2, %g2
0x02204    d0 10 a0 02    lduh  [ %g2 + 2 ], %o0                 ! Load mapped page index
0x02208    91 2a 20 05    sll  %o0, 5, %o0
0x0220C    90 12 00 03    or  %o0, %g3, %o0                      ! Combine mapped page with original low five bits
0x02210    81 c3 e0 08    retl
0x02214    01 00 00 00    nop

! 0x2218: Issue NAND command and address cycles
! Inputs: %i0 = command byte; %i1 = logical NAND page/address index.
! Calls 0x21AC to translate the address, then writes NAND command
! to 0x08010000 and address cycles to 0x08020000.
! 0x08000000 is the NAND data aperture in the early physical mapping.
! The 0x272C call with argument 12 is not yet characterized.
0x02218    9d e3 bf 98    save  %sp, -104, %sp
0x0221C    7f ff ff e4    call  0x21ac
0x02220    90 10 00 19    mov  %i1, %o0
0x02224    13 02 00 40    sethi  %hi(0x8010000), %o1
0x02228    f0 2a 40 00    stb  %i0, [ %o1 ]                      ! Write NAND command byte to command aperture
0x0222C    15 02 00 80    sethi  %hi(0x8020000), %o2
0x02230    c0 2a 80 00    clrb  [ %o2 ]
0x02234    d0 2a 80 00    stb  %o0, [ %o2 ]                      ! Write low address byte
0x02238    93 3a 20 10    sra  %o0, 0x10, %o1
0x0223C    91 3a 20 08    sra  %o0, 8, %o0
0x02240    d0 2a 80 00    stb  %o0, [ %o2 ]                      ! Write next address byte
0x02244    92 0a 60 0f    and  %o1, 0xf, %o1
0x02248    d2 2a 80 00    stb  %o1, [ %o2 ]                      ! Write upper address nibble
0x0224C    40 00 01 38    call  0x272c
0x02250    90 10 20 0c    mov  0xc, %o0                          ! Delay-slot argument = 12
0x02254    81 c7 e0 08    ret
0x02258    81 e8 00 00    restore

! 0x225C: Read one 512-byte NAND page to RAM
! Inputs: %i0 = NAND page index; %i1 = destination RAM address.
! Saves PADRE_PCI_FEATURE (0x2000010C), sets bit 10 (0x400),
! issues command 0x00 via 0x2218, then copies 128 32-bit words
! from NAND data aperture 0x08000000 to the destination buffer.
! Restores the original PADRE_PCI_FEATURE value afterward.
! Unlike the GPL Linux NAND driver, this routine does not explicitly
! clear PCION (bit 2); its prior state is not established here.
0x0225C    9d e3 bf 98    save  %sp, -104, %sp
0x02260    11 08 00 00    sethi  %hi(0x20000000), %o0
0x02264    90 12 21 0c    or  %o0, 0x10c, %o0                    ! 0x2000010c
0x02268    e0 02 00 00    ld  [ %o0 ], %l0                       ! Save PADRE_PCI_FEATURE register value
0x0226C    92 14 24 00    or  %l0, 0x400, %o1
0x02270    d2 22 00 00    st  %o1, [ %o0 ]                       ! Set bit 10 (0x400); PCION bit 2 not explicitly cleared
0x02274    92 10 00 18    mov  %i0, %o1
0x02278    7f ff ff e8    call  0x2218
0x0227C    90 10 20 00    clr  %o0
0x02280    15 02 00 00    sethi  %hi(0x8000000), %o2
0x02284    92 10 20 00    clr  %o1
0x02288    d0 02 80 00    ld  [ %o2 ], %o0                       ! Read 32-bit word from flash data port
0x0228C    d0 26 40 09    st  %o0, [ %i1 + %o1 ]                 ! Store word in destination buffer
0x02290    92 02 60 04    add  %o1, 4, %o1
0x02294    80 a2 61 ff    cmp  %o1, 0x1ff
0x02298    04 bf ff fc    ble  0x2288                            ! Repeat for 512 bytes; delay slot sets MMIO base
0x0229C    11 08 00 00    sethi  %hi(0x20000000), %o0
0x022A0    90 12 21 0c    or  %o0, 0x10c, %o0                    ! 0x2000010c
0x022A4    e0 22 00 00    st  %l0, [ %o0 ]                       ! Restore original PADRE_PCI_FEATURE value
0x022A8    81 c7 e0 08    ret
0x022AC    81 e8 00 00    restore

! 0x22B0: Decimal string conversion
! Accumulate signed ASCII bytes as decimal digits; no digit validation.
0x022B0    92 10 00 08    mov  %o0, %o1
0x022B4    c4 4a 40 00    ldsb  [ %o1 ], %g2
0x022B8    86 10 20 00    clr  %g3
0x022BC    80 a0 a0 00    cmp  %g2, 0
0x022C0    02 80 00 0e    be  0x22f8
0x022C4    d4 0a 40 00    ldub  [ %o1 ], %o2
0x022C8    85 28 e0 02    sll  %g3, 2, %g2
0x022CC    84 00 80 03    add  %g2, %g3, %g2
0x022D0    92 02 60 01    inc  %o1
0x022D4    87 2a a0 18    sll  %o2, 0x18, %g3
0x022D8    85 28 a0 01    sll  %g2, 1, %g2
0x022DC    d0 4a 40 00    ldsb  [ %o1 ], %o0
0x022E0    84 00 bf d0    add  %g2, -48, %g2                     ! Multiply accumulator by ten and subtract ASCII zero
0x022E4    87 38 e0 18    sra  %g3, 0x18, %g3
0x022E8    d4 0a 40 00    ldub  [ %o1 ], %o2
0x022EC    80 a2 20 00    cmp  %o0, 0
0x022F0    12 bf ff f6    bne  0x22c8
0x022F4    86 00 80 03    add  %g2, %g3, %g3                     ! Accumulate final digit in branch delay slot
0x022F8    81 c3 e0 08    retl
0x022FC    90 10 00 03    mov  %g3, %o0

! 0x2300: Colon-delimited record parser
! Extract fields, compare a key, and parse two decimal values.
0x02300    9d e3 bf 58    save  %sp, -168, %sp
0x02304    a0 10 00 18    mov  %i0, %l0
0x02308    b0 10 20 00    clr  %i0
0x0230C    d6 0c 00 18    ldub  [ %l0 + %i0 ], %o3
0x02310    92 10 00 19    mov  %i1, %o1
0x02314    94 10 20 00    clr  %o2
0x02318    80 a2 e0 3a    cmp  %o3, 0x3a
0x0231C    02 80 00 0a    be  0x2344
0x02320    a2 07 bf b8    add  %fp, -72, %l1
0x02324    98 10 00 11    mov  %l1, %o4
0x02328    d6 2b 00 0a    stb  %o3, [ %o4 + %o2 ]
0x0232C    b0 06 20 01    inc  %i0
0x02330    d0 4c 00 18    ldsb  [ %l0 + %i0 ], %o0
0x02334    94 02 a0 01    inc  %o2
0x02338    80 a2 20 3a    cmp  %o0, 0x3a
0x0233C    12 bf ff fb    bne  0x2328
0x02340    d6 0c 00 18    ldub  [ %l0 + %i0 ], %o3
0x02344    c0 2c 40 0a    clrb  [ %l1 + %o2 ]
0x02348    7f ff f8 e7    call  0x6e4                            ! Compare extracted key against expected key
0x0234C    90 10 00 11    mov  %l1, %o0
0x02350    80 a2 20 00    cmp  %o0, 0
0x02354    12 80 00 04    bne  0x2364
0x02358    b0 06 20 02    add  %i0, 2, %i0
0x0235C    10 80 00 2b    b  0x2408
0x02360    c0 26 c0 00    clr  [ %i3 ]
0x02364    d0 4c 00 18    ldsb  [ %l0 + %i0 ], %o0
0x02368    94 10 20 00    clr  %o2
0x0236C    80 a2 20 3a    cmp  %o0, 0x3a
0x02370    02 80 00 0a    be  0x2398
0x02374    d2 0c 00 18    ldub  [ %l0 + %i0 ], %o1
0x02378    96 10 00 11    mov  %l1, %o3
0x0237C    d2 2a c0 0a    stb  %o1, [ %o3 + %o2 ]
0x02380    b0 06 20 01    inc  %i0
0x02384    d0 4c 00 18    ldsb  [ %l0 + %i0 ], %o0
0x02388    94 02 a0 01    inc  %o2
0x0238C    80 a2 20 3a    cmp  %o0, 0x3a
0x02390    12 bf ff fb    bne  0x237c
0x02394    d2 0c 00 18    ldub  [ %l0 + %i0 ], %o1
0x02398    c0 2c 40 0a    clrb  [ %l1 + %o2 ]
0x0239C    7f ff ff c5    call  0x22b0                           ! Convert first decimal field
0x023A0    90 10 00 11    mov  %l1, %o0
0x023A4    d0 26 80 00    st  %o0, [ %i2 ]
0x023A8    b0 06 20 02    add  %i0, 2, %i0
0x023AC    d0 4c 00 18    ldsb  [ %l0 + %i0 ], %o0
0x023B0    94 10 20 00    clr  %o2
0x023B4    80 a2 20 0a    cmp  %o0, 0xa
0x023B8    02 80 00 0f    be  0x23f4
0x023BC    d2 0c 00 18    ldub  [ %l0 + %i0 ], %o1
0x023C0    80 a2 20 00    cmp  %o0, 0
0x023C4    02 80 00 0c    be  0x23f4
0x023C8    96 10 00 11    mov  %l1, %o3
0x023CC    b0 06 20 01    inc  %i0
0x023D0    d0 4c 00 18    ldsb  [ %l0 + %i0 ], %o0
0x023D4    d2 2a c0 0a    stb  %o1, [ %o3 + %o2 ]
0x023D8    d2 0c 00 18    ldub  [ %l0 + %i0 ], %o1
0x023DC    80 a2 20 0a    cmp  %o0, 0xa
0x023E0    02 80 00 05    be  0x23f4
0x023E4    94 02 a0 01    inc  %o2
0x023E8    80 a2 20 00    cmp  %o0, 0
0x023EC    32 bf ff f9    bne,a   0x23d0
0x023F0    b0 06 20 01    inc  %i0
0x023F4    c0 2c 40 0a    clrb  [ %l1 + %o2 ]
0x023F8    7f ff ff ae    call  0x22b0                           ! Convert second decimal field
0x023FC    90 10 00 11    mov  %l1, %o0
0x02400    b0 06 20 01    inc  %i0
0x02404    d0 26 c0 00    st  %o0, [ %i3 ]
0x02408    81 c7 e0 08    ret
0x0240C    81 e8 00 00    restore

! 0x2410: Read flash identification marker
! Read flash page zero and return word at offset 0x1fc.
0x02410    9d e3 bf 98    save  %sp, -104, %sp
0x02414    21 21 e0 00    sethi  %hi(0x87800000), %l0
0x02418    90 10 20 00    clr  %o0
0x0241C    7f ff ff 90    call  0x225c
0x02420    92 10 00 10    mov  %l0, %o1
0x02424    f0 04 21 fc    ld  [ %l0 + 0x1fc ], %i0               ! Read flash page zero
0x02428    81 c7 e0 08    ret                                    ! Read marker at offset 0x1fc
0x0242C    81 e8 00 00    restore

! 0x2430: Initialize flash translation table
! Check upper marker bits against 0xDEAD; read eight pages and set translation-table active flag.
0x02430    9d e3 bf 98    save  %sp, -104, %sp
0x02434    7f ff ff f7    call  0x2410
0x02438    01 00 00 00    nop
0x0243C    a0 10 00 08    mov  %o0, %l0
0x02440    11 3f ff c0    sethi  %hi(0xffff0000), %o0
0x02444    90 0c 00 08    and  %l0, %o0, %o0
0x02448    13 37 ab 40    sethi  %hi(0xdead0000), %o1
0x0244C    80 a2 00 09    cmp  %o0, %o1                          ! Compare upper 16 bits with 0xDEAD
0x02450    12 80 00 17    bne  0x24ac
0x02454    b0 10 20 01    mov  1, %i0
0x02458    11 00 00 3f    sethi  %hi(0xfc00), %o0
0x0245C    90 12 23 ff    or  %o0, 0x3ff, %o0                    ! 0xffff
0x02460    13 0c 00 0e    sethi  %hi(0x30003800), %o1
0x02464    a0 0c 00 08    and  %l0, %o0, %l0
0x02468    e2 02 63 e0    ld  [ %o1 + 0x3e0 ], %l1
0x0246C    a1 2c 20 05    sll  %l0, 5, %l0                       ! Extract low marker bits as page number
0x02470    b0 10 20 00    clr  %i0
0x02474    90 0e 20 ff    and  %i0, 0xff, %o0
0x02478    93 2a 20 09    sll  %o0, 9, %o1
0x0247C    90 04 00 08    add  %l0, %o0, %o0
0x02480    7f ff ff 77    call  0x225c                           ! Read one of eight pages into translation table
0x02484    92 04 40 09    add  %l1, %o1, %o1
0x02488    b0 06 20 01    inc  %i0
0x0248C    90 0e 20 ff    and  %i0, 0xff, %o0
0x02490    80 a2 20 07    cmp  %o0, 7
0x02494    08 bf ff fa    bleu  0x247c
0x02498    93 2a 20 09    sll  %o0, 9, %o1
0x0249C    92 10 20 01    mov  1, %o1
0x024A0    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x024A4    d2 22 23 e4    st  %o1, [ %o0 + 0x3e4 ]               ! 0x30003be4  [Mark translation table as initialized]
0x024A8    b0 10 20 00    clr  %i0
0x024AC    81 c7 e0 08    ret
0x024B0    81 e8 00 00    restore

! 0x24B4: Read and verify flash region
! Read 64 pages starting at page 0x60 and compare 32-KiB word sum with 0xDADABEEF.
0x024B4    9d e3 bf 98    save  %sp, -104, %sp
0x024B8    23 21 e0 c0    sethi  %hi(0x87830000), %l1
0x024BC    b0 10 20 00    clr  %i0
0x024C0    a0 10 00 11    mov  %l1, %l0
0x024C4    90 06 20 60    add  %i0, 0x60, %o0
0x024C8    7f ff ff 65    call  0x225c                           ! Read one 512-byte page
0x024CC    92 10 00 10    mov  %l0, %o1
0x024D0    b0 06 20 01    inc  %i0
0x024D4    80 a6 20 3f    cmp  %i0, 0x3f
0x024D8    08 bf ff fb    bleu  0x24c4
0x024DC    a0 04 22 00    add  %l0, 0x200, %l0                   ! Advance destination by 512 bytes (delay slot)
0x024E0    11 00 00 1f    sethi  %hi(0x7c00), %o0
0x024E4    94 12 23 ff    or  %o0, 0x3ff, %o2                    ! 0x7fff
0x024E8    92 10 20 00    clr  %o1
0x024EC    b0 10 20 00    clr  %i0
0x024F0    d0 04 40 18    ld  [ %l1 + %i0 ], %o0
0x024F4    b0 06 20 04    add  %i0, 4, %i0
0x024F8    80 a6 00 0a    cmp  %i0, %o2
0x024FC    08 bf ff fd    bleu  0x24f0
0x02500    92 02 40 08    add  %o1, %o0, %o1
0x02504    11 36 b6 af    sethi  %hi(0xdadabc00), %o0
0x02508    90 12 22 ef    or  %o0, 0x2ef, %o0                    ! 0xdadabeef  [Expected checksum 0xDADABEEF]
0x0250C    90 1a 40 08    xor  %o1, %o0, %o0
0x02510    80 a0 00 08    cmp  %g0, %o0
0x02514    b0 60 3f ff    subx  %g0, -1, %i0                     ! Derive boolean checksum result using carry
0x02518    81 c7 e0 08    ret
0x0251C    81 e8 00 00    restore

! 0x2520: Load and validate flash metadata
! Read page 0x800; check initial bytes 0x76 0x6d (vm); parse fields and load two regions.
0x02520    9d e3 bf 88    save  %sp, -120, %sp
0x02524    21 21 e0 40    sethi  %hi(0x87810000), %l0
0x02528    90 10 28 00    mov  0x800, %o0
0x0252C    7f ff ff 4c    call  0x225c                           ! Read flash page 0x800
0x02530    92 10 00 10    mov  %l0, %o1
0x02534    d0 0c 00 00    ldub  [ %l0 ], %o0
0x02538    80 a2 20 76    cmp  %o0, 0x76                         ! Check first magic byte: v
0x0253C    12 80 00 06    bne  0x2554
0x02540    a6 10 20 00    clr  %l3
0x02544    d0 0c 20 01    ldub  [ %l0 + 1 ], %o0
0x02548    80 a2 20 6d    cmp  %o0, 0x6d                         ! Check second magic byte: m
0x0254C    02 80 00 18    be  0x25ac
0x02550    13 0c 00 0e    sethi  %hi(0x30003800), %o1
0x02554    90 10 00 10    mov  %l0, %o0
0x02558    92 10 00 10    mov  %l0, %o1
0x0255C    40 00 03 0d    call  0x3190
0x02560    94 10 22 00    mov  0x200, %o2
0x02564    80 a2 20 00    cmp  %o0, 0
0x02568    02 80 00 05    be  0x257c
0x0256C    a6 10 20 01    mov  1, %l3
0x02570    90 10 20 01    mov  1, %o0
0x02574    40 00 04 46    call  0x368c
0x02578    92 10 20 07    mov  7, %o1
0x0257C    d0 0c 00 00    ldub  [ %l0 ], %o0
0x02580    80 a2 20 76    cmp  %o0, 0x76
0x02584    12 80 00 07    bne  0x25a0
0x02588    90 10 20 01    mov  1, %o0
0x0258C    d0 0c 20 01    ldub  [ %l0 + 1 ], %o0
0x02590    80 a2 20 6d    cmp  %o0, 0x6d
0x02594    02 80 00 06    be  0x25ac
0x02598    13 0c 00 0e    sethi  %hi(0x30003800), %o1
0x0259C    90 10 20 01    mov  1, %o0
0x025A0    40 00 04 3b    call  0x368c
0x025A4    92 10 20 05    mov  5, %o1
0x025A8    13 0c 00 0e    sethi  %hi(0x30003800), %o1
0x025AC    94 07 bf f4    add  %fp, -12, %o2
0x025B0    96 07 bf f0    add  %fp, -16, %o3
0x025B4    92 12 61 98    or  %o1, 0x198, %o1
0x025B8    7f ff ff 52    call  0x2300                           ! Parse first metadata record
0x025BC    11 21 e0 40    sethi  %hi(0x87810000), %o0
0x025C0    13 0c 00 0e    sethi  %hi(0x30003800), %o1
0x025C4    92 12 61 a8    or  %o1, 0x1a8, %o1                    ! 0x300039a8
0x025C8    94 07 bf ec    add  %fp, -20, %o2
0x025CC    96 07 bf e8    add  %fp, -24, %o3
0x025D0    7f ff ff 4c    call  0x2300                           ! Parse second metadata record
0x025D4    90 04 00 08    add  %l0, %o0, %o0
0x025D8    d4 07 bf f0    ld  [ %fp + -16 ], %o2
0x025DC    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x025E0    d2 07 bf e8    ld  [ %fp + -24 ], %o1
0x025E4    94 02 a1 ff    add  %o2, 0x1ff, %o2
0x025E8    92 02 61 ff    add  %o1, 0x1ff, %o1
0x025EC    95 32 a0 09    srl  %o2, 9, %o2                       ! Round byte count up to 512-byte pages
0x025F0    93 32 60 09    srl  %o1, 9, %o1
0x025F4    90 12 21 b8    or  %o0, 0x1b8, %o0
0x025F8    d4 27 bf f0    st  %o2, [ %fp + -16 ]
0x025FC    7f ff f8 ac    call  0x8ac
0x02600    d2 27 bf e8    st  %o1, [ %fp + -24 ]
0x02604    d0 07 bf f0    ld  [ %fp + -16 ], %o0
0x02608    a4 10 20 00    clr  %l2
0x0260C    80 a4 80 08    cmp  %l2, %o0
0x02610    3a 80 00 19    bcc,a   0x2674
0x02614    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x02618    21 20 00 10    sethi  %hi(0x80004000), %l0
0x0261C    d0 07 bf f4    ld  [ %fp + -12 ], %o0
0x02620    92 10 00 10    mov  %l0, %o1
0x02624    90 04 80 08    add  %l2, %o0, %o0
0x02628    7f ff ff 0d    call  0x225c                           ! Read flash page to RAM
0x0262C    90 02 28 00    add  %o0, 0x800, %o0
0x02630    80 8c e0 ff    btst  0xff, %l3
0x02634    02 80 00 0a    be  0x265c
0x02638    90 10 00 10    mov  %l0, %o0
0x0263C    92 10 00 10    mov  %l0, %o1
0x02640    40 00 02 d4    call  0x3190                           ! Optional 512-byte verification helper
0x02644    94 10 22 00    mov  0x200, %o2
0x02648    80 a2 20 00    cmp  %o0, 0
0x0264C    02 80 00 04    be  0x265c
0x02650    90 10 20 01    mov  1, %o0
0x02654    40 00 04 0e    call  0x368c
0x02658    92 10 20 07    mov  7, %o1
0x0265C    d0 07 bf f0    ld  [ %fp + -16 ], %o0
0x02660    a4 04 a0 01    inc  %l2
0x02664    80 a4 80 08    cmp  %l2, %o0
0x02668    0a bf ff ed    bcs  0x261c
0x0266C    a0 04 22 00    add  %l0, 0x200, %l0
0x02670    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x02674    7f ff f8 8e    call  0x8ac
0x02678    90 12 21 c0    or  %o0, 0x1c0, %o0                    ! 0x300039c0
0x0267C    d0 07 bf e8    ld  [ %fp + -24 ], %o0
0x02680    a4 10 20 00    clr  %l2
0x02684    80 a4 80 08    cmp  %l2, %o0
0x02688    1a 80 00 25    bcc  0x271c
0x0268C    11 10 5d 51    sethi  %hi(0x41754400), %o0
0x02690    a8 12 22 c0    or  %o0, 0x2c0, %l4                    ! 0x417546c0
0x02694    21 20 40 00    sethi  %hi(0x81000000), %l0
0x02698    d0 07 bf ec    ld  [ %fp + -20 ], %o0
0x0269C    92 10 00 10    mov  %l0, %o1
0x026A0    90 04 80 08    add  %l2, %o0, %o0
0x026A4    7f ff fe ee    call  0x225c                           ! Read second flash region
0x026A8    90 02 28 00    add  %o0, 0x800, %o0
0x026AC    80 a4 a0 00    cmp  %l2, 0
0x026B0    12 80 00 0b    bne  0x26dc
0x026B4    a2 0c e0 ff    and  %l3, 0xff, %l1
0x026B8    80 8c e0 ff    btst  0xff, %l3
0x026BC    02 80 00 09    be  0x26e0
0x026C0    80 a4 60 00    cmp  %l1, 0
0x026C4    d0 04 20 08    ld  [ %l0 + 8 ], %o0
0x026C8    80 a2 00 14    cmp  %o0, %l4                          ! Check first-page signature 0x417546c0
0x026CC    02 80 00 05    be  0x26e0
0x026D0    80 a4 60 00    cmp  %l1, 0
0x026D4    40 00 02 86    call  0x30ec
0x026D8    90 10 20 01    mov  1, %o0
0x026DC    80 a4 60 00    cmp  %l1, 0
0x026E0    02 80 00 0a    be  0x2708
0x026E4    90 10 00 10    mov  %l0, %o0
0x026E8    92 10 00 10    mov  %l0, %o1
0x026EC    40 00 02 a9    call  0x3190
0x026F0    94 10 22 00    mov  0x200, %o2
0x026F4    80 a2 20 00    cmp  %o0, 0
0x026F8    02 80 00 04    be  0x2708
0x026FC    90 10 20 01    mov  1, %o0
0x02700    40 00 03 e3    call  0x368c
0x02704    92 10 20 07    mov  7, %o1
0x02708    d0 07 bf e8    ld  [ %fp + -24 ], %o0
0x0270C    a4 04 a0 01    inc  %l2
0x02710    80 a4 80 08    cmp  %l2, %o0
0x02714    0a bf ff e1    bcs  0x2698
0x02718    a0 04 22 00    add  %l0, 0x200, %l0
0x0271C    40 00 02 74    call  0x30ec
0x02720    90 10 20 00    clr  %o0                               ! Pass zero to final helper in call delay slot
0x02724    81 c7 e0 08    ret
0x02728    81 e8 00 00    restore

! 0x272C: Busy-wait delay
! Spin for 96 times the supplied count.
0x0272C    87 2a 20 05    sll  %o0, 5, %g3
0x02730    85 2a 20 06    sll  %o0, 6, %g2
0x02734    90 00 80 03    add  %g2, %g3, %o0                     ! count * (64 + 32) = count * 96
0x02738    90 a2 20 01    deccc  %o0                             ! Decrement and test counter
0x0273C    12 bf ff ff    bne  0x2738
0x02740    01 00 00 00    nop
0x02744    81 c3 e0 08    retl
0x02748    01 00 00 00    nop

! 0x274C: Read and interpret hardware configuration
! Read 128 bytes via helper calls; check checksum and configuration fields; construct settings.
0x0274C    9d e3 bf 10    save  %sp, -240, %sp
0x02750    11 0c 00 0f    sethi  %hi(0x30003c00), %o0
0x02754    a4 12 20 60    or  %o0, 0x60, %l2                     ! 0x30003c60
0x02758    40 00 02 55    call  0x30ac                           ! Acquire hardware/configuration resource
0x0275C    90 10 20 50    mov  0x50, %o0
0x02760    80 a2 20 00    cmp  %o0, 0
0x02764    02 80 01 85    be  0x2d78
0x02768    a0 10 20 00    clr  %l0
0x0276C    a6 07 bf 74    add  %fp, -140, %l3
0x02770    a2 07 bf 70    add  %fp, -144, %l1
0x02774    a8 07 bf 78    add  %fp, -136, %l4
0x02778    b0 07 bf f8    add  %fp, -8, %i0
0x0277C    93 2c 20 18    sll  %l0, 0x18, %o1
0x02780    94 10 20 00    clr  %o2
0x02784    96 10 20 01    mov  1, %o3
0x02788    40 00 02 20    call  0x3008                           ! Write/read a block through controller helper
0x0278C    90 10 20 50    mov  0x50, %o0
0x02790    92 10 00 13    mov  %l3, %o1
0x02794    90 10 20 50    mov  0x50, %o0
0x02798    94 10 00 11    mov  %l1, %o2
0x0279C    40 00 02 2e    call  0x3054                           ! Fetch eight bytes into local storage
0x027A0    96 10 20 08    mov  8, %o3
0x027A4    d2 07 bf 74    ld  [ %fp + -140 ], %o1
0x027A8    a0 04 20 08    add  %l0, 8, %l0
0x027AC    d2 26 3f 80    st  %o1, [ %i0 + -128 ]
0x027B0    d0 07 bf 70    ld  [ %fp + -144 ], %o0
0x027B4    80 a4 20 7f    cmp  %l0, 0x7f
0x027B8    d0 26 3f 84    st  %o0, [ %i0 + -124 ]
0x027BC    08 bf ff f0    bleu  0x277c
0x027C0    b0 06 20 08    add  %i0, 8, %i0
0x027C4    d6 0f bf b7    ldub  [ %fp + -73 ], %o3
0x027C8    94 10 00 14    mov  %l4, %o2
0x027CC    92 10 20 00    clr  %o1
0x027D0    a0 10 20 00    clr  %l0
0x027D4    d0 0a 80 10    ldub  [ %o2 + %l0 ], %o0
0x027D8    a0 04 20 01    inc  %l0
0x027DC    80 a4 20 3e    cmp  %l0, 0x3e
0x027E0    08 bf ff fd    bleu  0x27d4
0x027E4    92 02 40 08    add  %o1, %o0, %o1
0x027E8    90 0a 60 ff    and  %o1, 0xff, %o0
0x027EC    80 a2 00 0b    cmp  %o0, %o3
0x027F0    32 80 01 6e    bne,a   0x2da8                         ! Compare computed checksum with stored byte
0x027F4    b0 10 3f ff    mov  -1, %i0
0x027F8    d0 0f bf 7a    ldub  [ %fp + -134 ], %o0
0x027FC    80 a2 20 07    cmp  %o0, 7
0x02800    32 80 01 6a    bne,a   0x2da8                         ! Validate configuration field
0x02804    b0 10 3f ff    mov  -1, %i0
0x02808    d0 0f bf 7e    ldub  [ %fp + -130 ], %o0
0x0280C    80 a2 20 40    cmp  %o0, 0x40
0x02810    02 80 00 04    be  0x2820
0x02814    80 a2 20 48    cmp  %o0, 0x48
0x02818    32 80 01 64    bne,a   0x2da8
0x0281C    b0 10 3f ff    mov  -1, %i0
0x02820    d0 0f bf 80    ldub  [ %fp + -128 ], %o0
0x02824    80 a2 20 04    cmp  %o0, 4
0x02828    32 80 01 60    bne,a   0x2da8
0x0282C    b0 10 3f ff    mov  -1, %i0
0x02830    d0 0f bf 89    ldub  [ %fp + -119 ], %o0
0x02834    80 a2 20 04    cmp  %o0, 4
0x02838    32 80 01 5c    bne,a   0x2da8
0x0283C    b0 10 3f ff    mov  -1, %i0
0x02840    d2 0f bf 8a    ldub  [ %fp + -118 ], %o1
0x02844    90 0a 60 0c    and  %o1, 0xc, %o0                     ! Check required flag bits
0x02848    80 a2 20 00    cmp  %o0, 0
0x0284C    02 80 01 4b    be  0x2d78
0x02850    80 8a 60 20    btst  0x20, %o1
0x02854    12 80 00 09    bne  0x2878
0x02858    84 10 20 23    mov  0x23, %g2
0x0285C    80 8a 60 10    btst  0x10, %o1
0x02860    12 80 00 06    bne  0x2878
0x02864    84 10 20 1e    mov  0x1e, %g2
0x02868    80 8a 60 08    btst  8, %o1
0x0286C    02 80 00 03    be  0x2878
0x02870    84 10 20 14    mov  0x14, %g2
0x02874    84 10 20 19    mov  0x19, %g2
0x02878    d0 0f bf 8b    ldub  [ %fp + -117 ], %o0
0x0287C    80 a2 20 01    cmp  %o0, 1
0x02880    12 80 01 4a    bne  0x2da8
0x02884    b0 10 3f ff    mov  -1, %i0
0x02888    d0 0f bf 8c    ldub  [ %fp + -116 ], %o0
0x0288C    80 a2 20 02    cmp  %o0, 2
0x02890    12 80 01 46    bne  0x2da8
0x02894    d4 0f bf a3    ldub  [ %fp + -93 ], %o2
0x02898    80 a2 a0 00    cmp  %o2, 0
0x0289C    02 80 00 0b    be  0x28c8
0x028A0    91 2a a0 05    sll  %o2, 5, %o0
0x028A4    90 22 00 0a    sub  %o0, %o2, %o0
0x028A8    91 2a 20 02    sll  %o0, 2, %o0
0x028AC    90 02 00 0a    add  %o0, %o2, %o0
0x028B0    13 0c 00 0e    sethi  %hi(0x30003800), %o1
0x028B4    d4 02 63 e8    ld  [ %o1 + 0x3e8 ], %o2               ! 0x30003be8
0x028B8    91 2a 20 01    sll  %o0, 1, %o0
0x028BC    80 a2 00 0a    cmp  %o0, %o2                          ! Compare calculated size against available memory
0x028C0    0a 80 01 3a    bcs  0x2da8
0x028C4    01 00 00 00    nop
0x028C8    d0 0f bf 8d    ldub  [ %fp + -115 ], %o0
0x028CC    80 a2 20 20    cmp  %o0, 0x20
0x028D0    02 80 00 05    be  0x28e4
0x028D4    c0 24 80 00    clr  [ %l2 ]                           ! Initialize output configuration to zero (delay slot)
0x028D8    80 a2 20 24    cmp  %o0, 0x24
0x028DC    12 80 00 05    bne  0x28f0
0x028E0    80 a2 20 26    cmp  %o0, 0x26
0x028E4    90 10 20 04    mov  4, %o0
0x028E8    10 80 00 04    b  0x28f8
0x028EC    d0 24 80 00    st  %o0, [ %l2 ]
0x028F0    12 80 01 2e    bne  0x2da8
0x028F4    b0 10 3f ff    mov  -1, %i0
0x028F8    d2 0f bf 7b    ldub  [ %fp + -133 ], %o1
0x028FC    80 8a 60 f0    btst  0xf0, %o1
0x02900    12 80 01 2a    bne  0x2da8
0x02904    b0 10 3f ff    mov  -1, %i0
0x02908    da 0f bf 7c    ldub  [ %fp + -132 ], %o5
0x0290C    80 8b 60 f0    btst  0xf0, %o5
0x02910    12 80 01 26    bne  0x2da8
0x02914    d8 0f bf 7d    ldub  [ %fp + -131 ], %o4
0x02918    90 03 3f ff    add  %o4, -1, %o0
0x0291C    80 a2 20 01    cmp  %o0, 1
0x02920    18 80 01 22    bgu  0x2da8
0x02924    92 02 40 0d    add  %o1, %o5, %o1
0x02928    96 02 60 05    add  %o1, 5, %o3
0x0292C    92 02 7f f5    add  %o1, -11, %o1
0x02930    90 10 20 01    mov  1, %o0
0x02934    91 2a 00 09    sll  %o0, %o1, %o0
0x02938    15 00 00 10    sethi  %hi(0x4000), %o2
0x0293C    92 02 00 0a    add  %o0, %o2, %o1
0x02940    94 12 c0 0a    or  %o3, %o2, %o2
0x02944    91 2b 00 0b    sll  %o4, %o3, %o0
0x02948    d0 24 a0 18    st  %o0, [ %l2 + 0x18 ]
0x0294C    d4 24 a0 08    st  %o2, [ %l2 + 8 ]
0x02950    80 a3 20 02    cmp  %o4, 2
0x02954    12 80 00 04    bne  0x2964
0x02958    d2 24 a0 0c    st  %o1, [ %l2 + 0xc ]
0x0295C    90 12 40 0b    or  %o1, %o3, %o0
0x02960    d0 24 a0 0c    st  %o0, [ %l2 + 0xc ]
0x02964    90 03 7f f8    add  %o5, -8, %o0
0x02968    80 a2 20 04    cmp  %o0, 4
0x0296C    18 80 01 03    bgu  0x2d78
0x02970    90 03 7f fa    add  %o5, -6, %o0
0x02974    93 2a 20 04    sll  %o0, 4, %o1
0x02978    80 a3 20 02    cmp  %o4, 2
0x0297C    12 80 00 05    bne  0x2990
0x02980    d2 24 a0 10    st  %o1, [ %l2 + 0x10 ]
0x02984    91 2a 20 07    sll  %o0, 7, %o0
0x02988    90 12 40 08    or  %o1, %o0, %o0
0x0298C    d0 24 a0 10    st  %o0, [ %l2 + 0x10 ]
0x02990    d2 0f bf 8f    ldub  [ %fp + -113 ], %o1
0x02994    29 0c 00 0e    sethi  %hi(0x30003800), %l4
0x02998    d8 0f bf 91    ldub  [ %fp + -111 ], %o4
0x0299C    91 32 60 04    srl  %o1, 4, %o0
0x029A0    9b 33 20 04    srl  %o4, 4, %o5
0x029A4    95 2a 20 02    sll  %o0, 2, %o2
0x029A8    94 02 80 08    add  %o2, %o0, %o2
0x029AC    97 2b 60 02    sll  %o5, 2, %o3
0x029B0    92 0a 60 0f    and  %o1, 0xf, %o1
0x029B4    96 02 c0 0d    add  %o3, %o5, %o3
0x029B8    95 2a a0 01    sll  %o2, 1, %o2
0x029BC    94 02 80 09    add  %o2, %o1, %o2
0x029C0    98 0b 20 0f    and  %o4, 0xf, %o4
0x029C4    97 2a e0 01    sll  %o3, 1, %o3
0x029C8    96 02 c0 0c    add  %o3, %o4, %o3
0x029CC    93 2a a0 01    sll  %o2, 1, %o1
0x029D0    91 2a e0 01    sll  %o3, 1, %o0
0x029D4    92 02 40 0a    add  %o1, %o2, %o1
0x029D8    90 02 00 0b    add  %o0, %o3, %o0
0x029DC    93 2a 60 03    sll  %o1, 3, %o1
0x029E0    92 02 40 0a    add  %o1, %o2, %o1
0x029E4    91 2a 20 03    sll  %o0, 3, %o0
0x029E8    90 02 00 0b    add  %o0, %o3, %o0
0x029EC    99 2a 60 02    sll  %o1, 2, %o4
0x029F0    80 a3 20 00    cmp  %o4, 0
0x029F4    12 80 00 06    bne  0x2a0c
0x029F8    97 2a 20 02    sll  %o0, 2, %o3
0x029FC    d2 05 23 e8    ld  [ %l4 + 0x3e8 ], %o1
0x02A00    11 00 00 37    sethi  %hi(0xdc00), %o0
0x02A04    90 12 22 ad    or  %o0, 0x2ad, %o0                    ! 0xdead
0x02A08    98 02 40 08    add  %o1, %o0, %o4
0x02A0C    80 a2 e0 00    cmp  %o3, 0
0x02A10    12 80 00 06    bne  0x2a28
0x02A14    d4 0f bf 81    ldub  [ %fp + -127 ], %o2
0x02A18    d2 05 23 e8    ld  [ %l4 + 0x3e8 ], %o1
0x02A1C    11 00 00 37    sethi  %hi(0xdc00), %o0
0x02A20    90 12 22 ad    or  %o0, 0x2ad, %o0                    ! 0xdead
0x02A24    96 02 40 08    add  %o1, %o0, %o3
0x02A28    91 32 a0 04    srl  %o2, 4, %o0
0x02A2C    93 2a 20 02    sll  %o0, 2, %o1
0x02A30    92 02 40 08    add  %o1, %o0, %o1
0x02A34    93 2a 60 01    sll  %o1, 1, %o1
0x02A38    94 0a a0 0f    and  %o2, 0xf, %o2
0x02A3C    92 02 40 0a    add  %o1, %o2, %o1
0x02A40    91 2a 60 01    sll  %o1, 1, %o0
0x02A44    90 02 00 09    add  %o0, %o1, %o0
0x02A48    91 2a 20 03    sll  %o0, 3, %o0
0x02A4C    90 02 00 09    add  %o0, %o1, %o0
0x02A50    d2 05 23 e8    ld  [ %l4 + 0x3e8 ], %o1
0x02A54    91 2a 20 02    sll  %o0, 2, %o0
0x02A58    80 a2 00 09    cmp  %o0, %o1
0x02A5C    18 80 00 c7    bgu  0x2d78
0x02A60    90 08 a0 ff    and  %g2, 0xff, %o0
0x02A64    80 a2 20 23    cmp  %o0, 0x23
0x02A68    12 80 00 07    bne  0x2a84
0x02A6C    84 10 20 14    mov  0x14, %g2
0x02A70    80 a2 c0 09    cmp  %o3, %o1
0x02A74    18 80 00 c1    bgu  0x2d78
0x02A78    84 10 20 19    mov  0x19, %g2
0x02A7C    10 80 00 0f    b  0x2ab8
0x02A80    80 a0 a0 19    cmp  %g2, 0x19
0x02A84    80 a2 20 1e    cmp  %o0, 0x1e
0x02A88    12 80 00 06    bne  0x2aa0
0x02A8C    80 a2 20 19    cmp  %o0, 0x19
0x02A90    80 a3 00 09    cmp  %o4, %o1
0x02A94    18 80 00 b9    bgu  0x2d78
0x02A98    80 a2 c0 09    cmp  %o3, %o1
0x02A9C    30 80 00 04    b,a   0x2aac
0x02AA0    12 80 00 06    bne  0x2ab8
0x02AA4    80 a0 a0 19    cmp  %g2, 0x19
0x02AA8    80 a3 00 09    cmp  %o4, %o1
0x02AAC    38 80 00 02    bgu,a   0x2ab4
0x02AB0    84 10 20 19    mov  0x19, %g2
0x02AB4    80 a0 a0 19    cmp  %g2, 0x19
0x02AB8    12 80 00 08    bne  0x2ad8
0x02ABC    90 10 20 21    mov  0x21, %o0
0x02AC0    d0 04 80 00    ld  [ %l2 ], %o0
0x02AC4    92 10 20 61    mov  0x61, %o1
0x02AC8    90 12 20 08    or  %o0, 8, %o0
0x02ACC    d0 24 80 00    st  %o0, [ %l2 ]
0x02AD0    10 80 00 03    b  0x2adc
0x02AD4    d2 24 a0 14    st  %o1, [ %l2 + 0x14 ]
0x02AD8    d0 24 a0 14    st  %o0, [ %l2 + 0x14 ]
0x02ADC    d2 05 23 e8    ld  [ %l4 + 0x3e8 ], %o1
0x02AE0    11 00 00 07    sethi  %hi(0x1c00), %o0
0x02AE4    90 12 21 4b    or  %o0, 0x14b, %o0                    ! 0x1d4b
0x02AE8    80 a2 40 08    cmp  %o1, %o0
0x02AEC    18 80 00 04    bgu  0x2afc
0x02AF0    d0 04 80 00    ld  [ %l2 ], %o0
0x02AF4    10 80 00 03    b  0x2b00
0x02AF8    90 12 20 03    or  %o0, 3, %o0
0x02AFC    90 12 20 02    or  %o0, 2, %o0
0x02B00    d0 24 80 00    st  %o0, [ %l2 ]
0x02B04    d2 0f bf 95    ldub  [ %fp + -107 ], %o1
0x02B08    a6 10 20 01    mov  1, %l3
0x02B0C    91 2a 60 05    sll  %o1, 5, %o0
0x02B10    90 22 00 09    sub  %o0, %o1, %o0
0x02B14    91 2a 20 02    sll  %o0, 2, %o0
0x02B18    d4 05 23 e8    ld  [ %l4 + 0x3e8 ], %o2
0x02B1C    90 02 00 09    add  %o0, %o1, %o0
0x02B20    92 10 00 0a    mov  %o2, %o1
0x02B24    10 80 00 03    b  0x2b30
0x02B28    91 2a 20 01    sll  %o0, 1, %o0
0x02B2C    a6 04 e0 01    inc  %l3
0x02B30    80 a4 e0 04    cmp  %l3, 4
0x02B34    14 80 00 04    bg  0x2b44
0x02B38    80 a2 00 0a    cmp  %o0, %o2
0x02B3C    3a bf ff fc    bcc,a   0x2b2c
0x02B40    94 02 80 09    add  %o2, %o1, %o2
0x02B44    80 a4 e0 04    cmp  %l3, 4
0x02B48    14 80 00 98    bg  0x2da8
0x02B4C    b0 10 3f ff    mov  -1, %i0
0x02B50    d6 0f bf 93    ldub  [ %fp + -109 ], %o3
0x02B54    92 04 ff ff    add  %l3, -1, %o1
0x02B58    91 2a e0 05    sll  %o3, 5, %o0
0x02B5C    d4 04 80 00    ld  [ %l2 ], %o2
0x02B60    93 2a 60 04    sll  %o1, 4, %o1
0x02B64    90 22 00 0b    sub  %o0, %o3, %o0
0x02B68    92 0a 60 30    and  %o1, 0x30, %o1
0x02B6C    91 2a 20 02    sll  %o0, 2, %o0
0x02B70    94 12 80 09    or  %o2, %o1, %o2
0x02B74    90 02 00 0b    add  %o0, %o3, %o0
0x02B78    d8 05 23 e8    ld  [ %l4 + 0x3e8 ], %o4
0x02B7C    93 2a 20 01    sll  %o0, 1, %o1
0x02B80    9a 10 00 0c    mov  %o4, %o5
0x02B84    d4 24 80 00    st  %o2, [ %l2 ]
0x02B88    10 80 00 03    b  0x2b94
0x02B8C    90 10 20 01    mov  1, %o0
0x02B90    90 02 20 01    inc  %o0
0x02B94    80 a2 20 04    cmp  %o0, 4
0x02B98    14 80 00 04    bg  0x2ba8
0x02B9C    80 a2 40 0c    cmp  %o1, %o4
0x02BA0    3a bf ff fc    bcc,a   0x2b90
0x02BA4    98 03 00 0d    add  %o4, %o5, %o4
0x02BA8    80 a2 20 04    cmp  %o0, 4
0x02BAC    14 80 00 7f    bg  0x2da8
0x02BB0    b0 10 3f ff    mov  -1, %i0
0x02BB4    90 02 3f ff    add  %o0, -1, %o0
0x02BB8    d4 04 80 00    ld  [ %l2 ], %o2
0x02BBC    91 2a 20 06    sll  %o0, 6, %o0
0x02BC0    90 0a 20 c0    and  %o0, 0xc0, %o0
0x02BC4    90 12 80 08    or  %o2, %o0, %o0
0x02BC8    92 12 21 00    or  %o0, 0x100, %o1
0x02BCC    80 a0 a0 14    cmp  %g2, 0x14
0x02BD0    12 80 00 04    bne  0x2be0
0x02BD4    d2 24 80 00    st  %o1, [ %l2 ]
0x02BD8    10 80 00 03    b  0x2be4
0x02BDC    90 12 25 00    or  %o0, 0x500, %o0
0x02BE0    90 12 29 00    or  %o0, 0x900, %o0
0x02BE4    d0 24 80 00    st  %o0, [ %l2 ]
0x02BE8    d4 0f bf a1    ldub  [ %fp + -95 ], %o2
0x02BEC    d2 0f bf a2    ldub  [ %fp + -94 ], %o1
0x02BF0    80 a2 80 09    cmp  %o2, %o1
0x02BF4    28 80 00 07    bleu,a   0x2c10
0x02BF8    91 2a 60 05    sll  %o1, 5, %o0
0x02BFC    91 2a a0 05    sll  %o2, 5, %o0
0x02C00    90 22 00 0a    sub  %o0, %o2, %o0
0x02C04    91 2a 20 02    sll  %o0, 2, %o0
0x02C08    10 80 00 05    b  0x2c1c
0x02C0C    90 02 00 0a    add  %o0, %o2, %o0
0x02C10    90 22 00 09    sub  %o0, %o1, %o0
0x02C14    91 2a 20 02    sll  %o0, 2, %o0
0x02C18    90 02 00 09    add  %o0, %o1, %o0
0x02C1C    97 2a 20 03    sll  %o0, 3, %o3
0x02C20    d4 05 23 e8    ld  [ %l4 + 0x3e8 ], %o2
0x02C24    92 10 20 07    mov  7, %o1
0x02C28    91 2a a0 03    sll  %o2, 3, %o0
0x02C2C    10 80 00 03    b  0x2c38
0x02C30    90 22 00 0a    sub  %o0, %o2, %o0
0x02C34    92 02 60 01    inc  %o1
0x02C38    80 a2 60 0b    cmp  %o1, 0xb
0x02C3C    14 80 00 04    bg  0x2c4c
0x02C40    80 a2 c0 08    cmp  %o3, %o0
0x02C44    3a bf ff fc    bcc,a   0x2c34
0x02C48    90 02 00 0a    add  %o0, %o2, %o0
0x02C4C    80 a2 60 0b    cmp  %o1, 0xb
0x02C50    22 80 00 02    be,a   0x2c58
0x02C54    92 10 20 0a    mov  0xa, %o1
0x02C58    80 a2 60 0a    cmp  %o1, 0xa
0x02C5C    14 80 00 53    bg  0x2da8
0x02C60    b0 10 3f ff    mov  -1, %i0
0x02C64    90 02 7f f9    add  %o1, -7, %o0
0x02C68    d4 04 80 00    ld  [ %l2 ], %o2
0x02C6C    91 2a 20 0c    sll  %o0, 0xc, %o0
0x02C70    17 00 00 0c    sethi  %hi(0x3000), %o3
0x02C74    90 0a 00 0b    and  %o0, %o3, %o0
0x02C78    d2 0f bf a1    ldub  [ %fp + -95 ], %o1
0x02C7C    94 12 80 08    or  %o2, %o0, %o2
0x02C80    80 a2 60 00    cmp  %o1, 0
0x02C84    12 80 00 08    bne  0x2ca4
0x02C88    d4 24 80 00    st  %o2, [ %l2 ]
0x02C8C    d0 0f bf a2    ldub  [ %fp + -94 ], %o0
0x02C90    80 a2 20 00    cmp  %o0, 0
0x02C94    12 80 00 05    bne  0x2ca8
0x02C98    d2 0f bf 96    ldub  [ %fp + -106 ], %o1
0x02C9C    90 12 80 0b    or  %o2, %o3, %o0
0x02CA0    d0 24 80 00    st  %o0, [ %l2 ]
0x02CA4    d2 0f bf 96    ldub  [ %fp + -106 ], %o1
0x02CA8    a0 10 20 04    mov  4, %l0
0x02CAC    91 2a 60 05    sll  %o1, 5, %o0
0x02CB0    90 22 00 09    sub  %o0, %o1, %o0
0x02CB4    91 2a 20 02    sll  %o0, 2, %o0
0x02CB8    90 02 00 09    add  %o0, %o1, %o0
0x02CBC    f0 05 23 e8    ld  [ %l4 + 0x3e8 ], %i0
0x02CC0    a3 2a 20 01    sll  %o0, 1, %l1
0x02CC4    80 a4 20 07    cmp  %l0, 7
0x02CC8    14 80 00 08    bg  0x2ce8
0x02CCC    90 04 00 13    add  %l0, %l3, %o0
0x02CD0    7f ff f6 6b    call  0x67c
0x02CD4    92 10 00 18    mov  %i0, %o1
0x02CD8    80 a4 40 08    cmp  %l1, %o0
0x02CDC    3a bf ff fa    bcc,a   0x2cc4
0x02CE0    a0 04 20 01    inc  %l0
0x02CE4    80 a4 20 07    cmp  %l0, 7
0x02CE8    34 80 00 30    bg,a   0x2da8
0x02CEC    b0 10 3f ff    mov  -1, %i0
0x02CF0    90 04 3f fc    add  %l0, -4, %o0
0x02CF4    d2 04 80 00    ld  [ %l2 ], %o1
0x02CF8    91 2a 20 0e    sll  %o0, 0xe, %o0
0x02CFC    15 00 00 30    sethi  %hi(0xc000), %o2
0x02D00    d6 0f bf 84    ldub  [ %fp + -124 ], %o3
0x02D04    90 0a 00 0a    and  %o0, %o2, %o0
0x02D08    96 0a e0 7f    and  %o3, 0x7f, %o3
0x02D0C    92 12 40 08    or  %o1, %o0, %o1
0x02D10    80 a2 e0 05    cmp  %o3, 5
0x02D14    18 80 00 19    bgu  0x2d78
0x02D18    d2 24 80 00    st  %o1, [ %l2 ]
0x02D1C    11 0c 00 0a    sethi  %hi(0x30002800), %o0
0x02D20    90 12 23 b0    or  %o0, 0x3b0, %o0                    ! 0x30002bb0
0x02D24    93 2a e0 02    sll  %o3, 2, %o1
0x02D28    d4 02 00 09    ld  [ %o0 + %o1 ], %o2                 ! Load jump target from configuration jump table
0x02D2C    81 c2 80 00    jmp  %o2                               ! Indirect jump to selected case
0x02D30    01 00 00 00    nop

! 0x2D34: Configuration value table
! Choose a fixed timing/configuration constant based on parsed index.
0x02D34    11 00 3b 82    sethi  %hi(0xee0800), %o0
0x02D38    10 80 00 12    b  0x2d80
0x02D3C    90 12 21 80    or  %o0, 0x180, %o0                    ! 0xee0980
0x02D40    11 00 0e e0    sethi  %hi(0x3b8000), %o0
0x02D44    10 80 00 0f    b  0x2d80
0x02D48    90 12 22 60    or  %o0, 0x260, %o0                    ! 0x3b8260
0x02D4C    11 00 1d c1    sethi  %hi(0x770400), %o0
0x02D50    10 80 00 0c    b  0x2d80
0x02D54    90 12 20 c0    or  %o0, 0xc0, %o0                     ! 0x7704c0
0x02D58    11 00 77 04    sethi  %hi(0x1dc1000), %o0
0x02D5C    10 80 00 09    b  0x2d80
0x02D60    90 12 23 00    or  %o0, 0x300, %o0                    ! 0x1dc1300
0x02D64    11 00 ee 09    sethi  %hi(0x3b82400), %o0
0x02D68    10 80 00 06    b  0x2d80
0x02D6C    90 12 22 00    or  %o0, 0x200, %o0                    ! 0x3b82600
0x02D70    10 80 00 04    b  0x2d80
0x02D74    11 01 dc 13    sethi  %hi(0x7704c00), %o0

! 0x2D78: Error return
! Return -1 for unsupported or invalid configuration.
0x02D78    10 80 00 0c    b  0x2da8
0x02D7C    b0 10 3f ff    mov  -1, %i0
0x02D80    d2 05 23 e8    ld  [ %l4 + 0x3e8 ], %o1
0x02D84    7f ff f6 32    call  0x64c                            ! Call arithmetic helper with constant from selected case
0x02D88    b0 10 20 00    clr  %i0
0x02D8C    90 02 3f e8    add  %o0, -24, %o0
0x02D90    91 3a 20 06    sra  %o0, 6, %o0
0x02D94    91 2a 20 0a    sll  %o0, 0xa, %o0
0x02D98    13 00 00 3f    sethi  %hi(0xfc00), %o1
0x02D9C    90 0a 00 09    and  %o0, %o1, %o0
0x02DA0    90 12 21 e0    or  %o0, 0x1e0, %o0
0x02DA4    d0 24 a0 04    st  %o0, [ %l2 + 4 ]                   ! Store final computed configuration word

! 0x2DA8: Function epilogue
! Return selected status.
0x02DA8    81 c7 e0 08    ret
0x02DAC    81 e8 00 00    restore

! 0x2DB0–0x2DC4: Jump table used by the preceding routine
! Six 32-bit big-endian code addresses, not SPARC instructions.

0x02DB0    30 00 2b 34    .word 0x30002b34                       ! Entry 0 -> 0x2D34
0x02DB4    30 00 2b 40    .word 0x30002b40                       ! Entry 1 -> 0x2D40
0x02DB8    30 00 2b 4c    .word 0x30002b4c                       ! Entry 2 -> 0x2D4C
0x02DBC    30 00 2b 58    .word 0x30002b58                       ! Entry 3 -> 0x2D58
0x02DC0    30 00 2b 64    .word 0x30002b64                       ! Entry 4 -> 0x2D64
0x02DC4    30 00 2b 70    .word 0x30002b70                       ! Entry 5 -> 0x2D70

! 0x2DC8–0x2FB4: Initialize hardware registers and run a memory-mapped test
! Steps:
! 1. Initialize the controller and wait for its status flags.
! 2. Write configuration words prepared at 0x30003C60.
! 3. Wait for hardware to settle.
! 4. Write two test patterns and read them back.
! 5. Return 0 if both patterns match; otherwise return -1.

0x02DC8    9d e3 bf 98    save  %sp, -104, %sp
0x02DCC    11 08 00 08    sethi %hi(0x20002000), %o0
0x02DD0    90 12 20 2c    or    %o0, 0x2c, %o0                   ! 0x2000202C
0x02DD4    13 0c 00 0f    sethi %hi(0x30003c00), %o1
0x02DD8    94 10 20 1f    mov   0x1f, %o2
0x02DDC    96 10 00 08    mov   %o0, %o3
0x02DE0    b0 12 60 60    or    %o1, 0x60, %i0                   ! Configuration at 0x30003C60
0x02DE4    d4 22 00 00    st    %o2, [ %o0 ]                     ! Write 0x1F to control register
0x02DE8    d0 02 c0 00    ld    [ %o3 ], %o0
0x02DEC    80 8a 20 20    btst  0x20, %o0
0x02DF0    02 bf ff fe    be    0x2de8                           ! Wait for bit 5 to become set
0x02DF4    21 08 00 08    sethi %hi(0x20002000), %l0             ! Delay slot

0x02DF8    a0 14 20 0c    or    %l0, 0xc, %l0                    ! 0x2000200C
0x02DFC    90 10 20 08    mov   8, %o0
0x02E00    d0 24 00 00    st    %o0, [ %l0 ]
0x02E04    7f ff fe 4a    call  0x272c                           ! Busy-wait delay
0x02E08    90 10 20 05    mov   5, %o0                           ! Delay argument
0x02E0C    90 10 20 09    mov   9, %o0
0x02E10    92 10 00 10    mov   %l0, %o1
0x02E14    d0 24 00 00    st    %o0, [ %l0 ]
0x02E18    d0 02 40 00    ld    [ %o1 ], %o0
0x02E1C    80 8a 20 08    btst  8, %o0
0x02E20    12 bf ff fe    bne   0x2e18                           ! Wait for bit 3 to clear
0x02E24    11 00 00 08    sethi %hi(0x2000), %o0

0x02E28    13 08 00 08    sethi %hi(0x20002000), %o1
0x02E2C    94 12 60 08    or    %o1, 8, %o2                      ! 0x20002008
0x02E30    d0 22 80 00    st    %o0, [ %o2 ]                     ! Write 0x2000
0x02E34    92 12 60 0c    or    %o1, 0xc, %o1
0x02E38    90 10 20 0b    mov   0xb, %o0
0x02E3C    94 10 00 09    mov   %o1, %o2
0x02E40    d0 22 40 00    st    %o0, [ %o1 ]
0x02E44    d0 02 80 00    ld    [ %o2 ], %o0
0x02E48    80 8a 20 08    btst  8, %o0
0x02E4C    12 bf ff fe    bne   0x2e44                           ! Wait for command completion
0x02E50    01 00 00 00    nop

0x02E54    d0 06 20 14    ld    [ %i0 + 0x14 ], %o0              ! Configuration word 5
0x02E58    15 08 00 08    sethi %hi(0x20002000), %o2
0x02E5C    92 12 a0 08    or    %o2, 8, %o1
0x02E60    90 12 21 00    or    %o0, 0x100, %o0
0x02E64    d0 22 40 00    st    %o0, [ %o1 ]
0x02E68    94 12 a0 0c    or    %o2, 0xc, %o2
0x02E6C    90 10 20 0b    mov   0xb, %o0
0x02E70    92 10 00 0a    mov   %o2, %o1
0x02E74    d0 22 80 00    st    %o0, [ %o2 ]
0x02E78    d0 02 40 00    ld    [ %o1 ], %o0
0x02E7C    80 8a 20 08    btst  8, %o0
0x02E80    12 bf ff fe    bne   0x2e78
0x02E84    01 00 00 00    nop

0x02E88    7f ff fe 29    call  0x272c
0x02E8C    90 10 20 05    mov   5, %o0
0x02E90    11 08 00 08    sethi %hi(0x20002000), %o0
0x02E94    90 12 20 0c    or    %o0, 0xc, %o0
0x02E98    92 10 20 09    mov   9, %o1
0x02E9C    94 10 00 08    mov   %o0, %o2
0x02EA0    d2 22 00 00    st    %o1, [ %o0 ]
0x02EA4    d0 02 80 00    ld    [ %o2 ], %o0
0x02EA8    80 8a 20 08    btst  8, %o0
0x02EAC    12 bf ff fe    bne   0x2ea4
0x02EB0    11 08 00 08    sethi %hi(0x20002000), %o0
0x02EB4    90 12 20 0c    or    %o0, 0xc, %o0
0x02EB8    92 10 20 0a    mov   0xa, %o1
0x02EBC    94 10 00 08    mov   %o0, %o2
0x02EC0    d2 22 00 00    st    %o1, [ %o0 ]
0x02EC4    d0 02 80 00    ld    [ %o2 ], %o0
0x02EC8    80 8a 20 08    btst  8, %o0
0x02ECC    12 bf ff fe    bne   0x2ec4
0x02ED0    11 08 00 08    sethi %hi(0x20002000), %o0
0x02ED4    90 12 20 0c    or    %o0, 0xc, %o0
0x02ED8    92 10 20 0a    mov   0xa, %o1
0x02EDC    94 10 00 08    mov   %o0, %o2
0x02EE0    d2 22 00 00    st    %o1, [ %o0 ]
0x02EE4    d0 02 80 00    ld    [ %o2 ], %o0
0x02EE8    80 8a 20 08    btst  8, %o0
0x02EEC    12 bf ff fe    bne   0x2ee4

0x02EF0    13 08 00 08    sethi %hi(0x20002000), %o1
0x02EF4    d4 06 20 14    ld    [ %i0 + 0x14 ], %o2
0x02EF8    90 12 60 08    or    %o1, 8, %o0
0x02EFC    d4 22 00 00    st    %o2, [ %o0 ]                     ! Write configuration word 5
0x02F00    92 12 60 0c    or    %o1, 0xc, %o1
0x02F04    90 10 20 0b    mov   0xb, %o0
0x02F08    94 10 00 09    mov   %o1, %o2
0x02F0C    d0 22 40 00    st    %o0, [ %o1 ]
0x02F10    d0 02 80 00    ld    [ %o2 ], %o0
0x02F14    80 8a 20 08    btst  8, %o0
0x02F18    12 bf ff fe    bne   0x2f10

0x02F1C    13 08 00 08    sethi %hi(0x20002000), %o1
0x02F20    da 06 20 04    ld    [ %i0 + 4 ], %o5
0x02F24    96 12 60 08    or    %o1, 8, %o3
0x02F28    11 00 00 20    sethi %hi(0x8000), %o0
0x02F2C    d0 22 c0 00    st    %o0, [ %o3 ]                     ! Write 0x8000
0x02F30    d6 06 00 00    ld    [ %i0 ], %o3
0x02F34    94 12 60 04    or    %o1, 4, %o2
0x02F38    da 22 80 00    st    %o5, [ %o2 ]                     ! Configuration word 1
0x02F3C    d8 06 20 08    ld    [ %i0 + 8 ], %o4
0x02F40    90 12 60 10    or    %o1, 0x10, %o0
0x02F44    d6 22 40 00    st    %o3, [ %o1 ]                     ! Configuration word 0
0x02F48    d4 06 20 0c    ld    [ %i0 + 0xc ], %o2
0x02F4C    d8 22 00 00    st    %o4, [ %o0 ]                     ! Configuration word 2
0x02F50    d6 06 20 10    ld    [ %i0 + 0x10 ], %o3
0x02F54    90 12 60 14    or    %o1, 0x14, %o0
0x02F58    d4 22 00 00    st    %o2, [ %o0 ]                     ! Configuration word 3
0x02F5C    92 12 60 20    or    %o1, 0x20, %o1
0x02F60    11 00 00 30    sethi %hi(0xc000), %o0
0x02F64    d6 22 40 00    st    %o3, [ %o1 ]                     ! Configuration word 4
0x02F68    7f ff fd f1    call  0x272c
0x02F6C    90 12 23 50    or    %o0, 0x350, %o0                  ! Delay argument 0xC350

! Test two memory-mapped locations using fixed patterns.
0x02F70    15 00 00 15    sethi %hi(0x5400), %o2
0x02F74    13 20 00 00    sethi %hi(0x80000000), %o1
0x02F78    94 12 a1 aa    or    %o2, 0x1aa, %o2                  ! Pattern 0x55AA
0x02F7C    11 00 00 37    sethi %hi(0xdc00), %o0
0x02F80    96 12 22 ad    or    %o0, 0x2ad, %o3                  ! Pattern 0xDEAD
0x02F84    d4 22 40 00    st    %o2, [ %o1 ]                     ! [0x80000000] = 0x55AA
0x02F88    98 12 60 04    or    %o1, 4, %o4
0x02F8C    d6 23 00 00    st    %o3, [ %o4 ]                     ! [0x80000004] = 0xDEAD
0x02F90    d0 02 40 00    ld    [ %o1 ], %o0
0x02F94    80 a2 00 0a    cmp   %o0, %o2
0x02F98    12 80 00 06    bne   0x2fb0                           ! First pattern mismatch
0x02F9C    b0 10 3f ff    mov   -1, %i0                          ! Default result: failure
0x02FA0    d0 03 00 00    ld    [ %o4 ], %o0
0x02FA4    80 a2 00 0b    cmp   %o0, %o3
0x02FA8    22 80 00 02    be,a  0x2fb0                           ! Both patterns match
0x02FAC    b0 10 20 00    clr   %i0                              ! Success; annulled otherwise
0x02FB0    81 c7 e0 08    ret
0x02FB4    81 e8 00 00    restore

! 0x2FB8–0x3004: Wait for hardware status bit 0 to clear
! Steps:
! 1. Read the status register at 0x200000E0.
! 2. If bit 0 is clear, return immediately.
! 3. Otherwise poll with a bounded counter.
! 4. Call the error handler at 0x368C if the counter expires.
! 5. Return once the status bit clears.

0x02FB8    9d e3 bf 98    save  %sp, -104, %sp
0x02FBC    11 08 00 00    sethi %hi(0x20000000), %o0
0x02FC0    94 12 20 e0    or    %o0, 0xe0, %o2                   ! Status register 0x200000E0
0x02FC4    d2 02 80 00    ld    [ %o2 ], %o1
0x02FC8    11 00 01 24    sethi %hi(0x49000), %o0
0x02FCC    80 8a 60 01    btst  1, %o1
0x02FD0    02 80 00 0c    be    0x3000                           ! Already ready
0x02FD4    a0 12 23 e0    or    %o0, 0x3e0, %l0                  ! Counter = 0x493E0
0x02FD8    a2 10 00 0a    mov   %o2, %l1
0x02FDC    a0 84 3f ff    addcc %l0, -1, %l0
0x02FE0    12 80 00 04    bne   0x2ff0
0x02FE4    90 10 20 01    mov   1, %o0
0x02FE8    40 00 01 a9    call  0x368c                           ! Timeout/error handler
0x02FEC    92 10 20 0c    mov   0xc, %o1
0x02FF0    d0 04 40 00    ld    [ %l1 ], %o0
0x02FF4    80 8a 20 01    btst  1, %o0
0x02FF8    12 bf ff fa    bne   0x2fe0                           ! Continue while bit 0 is set
0x02FFC    a0 84 3f ff    addcc %l0, -1, %l0                     ! Counter decremented again

0x03000    81 c7 e0 08    ret
0x03004    81 e8 00 00    restore


! 0x3008: MMIO transfer write (four arguments)
! Write two data words and a packed command; wait for completion.
0x03008    9d e3 bf 98    save  %sp, -104, %sp
0x0300C    13 08 00 00    sethi  %hi(0x20000000), %o1
0x03010    90 12 60 d8    or  %o1, 0xd8, %o0                     ! 0x200000d8    ! MMIO data register 0x200000D8
0x03014    b6 06 ff ff    add  %i3, -1, %i3
0x03018    f2 22 00 00    st  %i1, [ %o0 ]                       ! Write first data word
0x0301C    b1 2e 20 01    sll  %i0, 1, %i0
0x03020    b7 2e e0 08    sll  %i3, 8, %i3                       ! Pack (count - 1) into command bits
0x03024    15 00 00 0a    sethi  %hi(0x2800), %o2
0x03028    90 12 60 dc    or  %o1, 0xdc, %o0
0x0302C    b6 16 c0 0a    or  %i3, %o2, %i3                      ! Add fixed command flags 0x2800
0x03030    b0 0e 20 fe    and  %i0, 0xfe, %i0
0x03034    b0 16 00 1b    or  %i0, %i3, %i0
0x03038    f4 22 00 00    st  %i2, [ %o0 ]                       ! Write second data word to 0x200000DC
0x0303C    92 12 60 d0    or  %o1, 0xd0, %o1
0x03040    f0 22 40 00    st  %i0, [ %o1 ]                       ! Start transfer via 0x200000D0
0x03044    7f ff ff dd    call  0x2fb8                           ! Wait until MMIO status bit 0 clears
0x03048    01 00 00 00    nop
0x0304C    81 c7 e0 08    ret
0x03050    81 e8 00 00    restore

! 0x3054: MMIO transfer read
! Issue a read command; store two returned words through caller pointers.
0x03054    9d e3 bf 98    save  %sp, -104, %sp
0x03058    b6 06 ff ff    add  %i3, -1, %i3                      ! Convert count to encoded (count - 1) field
0x0305C    b7 2e e0 08    sll  %i3, 8, %i3
0x03060    11 00 00 0a    sethi  %hi(0x2800), %o0
0x03064    b1 2e 20 01    sll  %i0, 1, %i0
0x03068    b6 16 c0 08    or  %i3, %o0, %i3
0x0306C    b0 0e 20 fe    and  %i0, 0xfe, %i0
0x03070    21 08 00 00    sethi  %hi(0x20000000), %l0
0x03074    b0 16 00 1b    or  %i0, %i3, %i0
0x03078    90 14 20 d0    or  %l0, 0xd0, %o0
0x0307C    b0 16 20 01    or  %i0, 1, %i0                        ! Set read-direction bit 0
0x03080    f0 22 00 00    st  %i0, [ %o0 ]                       ! Start read command
0x03084    7f ff ff cd    call  0x2fb8                           ! Wait for transfer completion
0x03088    01 00 00 00    nop
0x0308C    90 14 20 d8    or  %l0, 0xd8, %o0
0x03090    d2 02 00 00    ld  [ %o0 ], %o1                       ! Read first returned word
0x03094    a0 14 20 dc    or  %l0, 0xdc, %l0
0x03098    d2 26 40 00    st  %o1, [ %i1 ]                       ! Store first word through pointer i1
0x0309C    d0 04 00 00    ld  [ %l0 ], %o0                       ! Read second returned word
0x030A0    d0 26 80 00    st  %o0, [ %i2 ]                       ! Store second word through pointer i2
0x030A4    81 c7 e0 08    ret
0x030A8    81 e8 00 00    restore

! 0x30AC: MMIO status query
! Issue a command and return a Boolean derived from status bit 1.
0x030AC    9d e3 bf 98    save  %sp, -104, %sp
0x030B0    11 00 00 0a    sethi  %hi(0x2800), %o0
0x030B4    90 12 20 01    or  %o0, 1, %o0                        ! 0x2801    ! Command base 0x2801
0x030B8    b1 2e 20 01    sll  %i0, 1, %i0
0x030BC    21 08 00 00    sethi  %hi(0x20000000), %l0
0x030C0    b0 16 00 08    or  %i0, %o0, %i0
0x030C4    92 14 20 d0    or  %l0, 0xd0, %o1
0x030C8    f0 22 40 00    st  %i0, [ %o1 ]                       ! Start command
0x030CC    7f ff ff bb    call  0x2fb8                           ! Wait for completion
0x030D0    a0 14 20 e0    or  %l0, 0xe0, %l0
0x030D4    d0 04 00 00    ld  [ %l0 ], %o0                       ! Read status register 0x200000E0
0x030D8    90 0a 20 02    and  %o0, 2, %o0                       ! Extract status bit 1
0x030DC    80 a0 00 08    cmp  %g0, %o0
0x030E0    b0 60 3f ff    subx  %g0, -1, %i0                     ! Return 1 if bit set, 0 otherwise (carry-based)
0x030E4    81 c7 e0 08    ret
0x030E8    81 e8 00 00    restore

! 0x30EC: Hardware setup and external firmware call
! Initialize registers, choose one of two external entry points, store returned registers.
0x030EC    9d e3 bf 98    save  %sp, -104, %sp
0x030F0    07 08 00 0c    sethi  %hi(0x20003000), %g3
0x030F4    84 10 20 01    mov  1, %g2
0x030F8    c4 20 c0 00    st  %g2, [ %g3 ]                       ! Write 1 to 0x20003000
0x030FC    b2 10 20 02    mov  2, %i1
0x03100    f2 20 c0 00    st  %i1, [ %g3 ]                       ! Write 2 to 0x20003000
0x03104    86 10 e0 04    or  %g3, 4, %g3
0x03108    84 10 20 0a    mov  0xa, %g2
0x0310C    33 0c 00 0f    sethi  %hi(0x30003c00), %i1
0x03110    c4 20 c0 00    st  %g2, [ %g3 ]                       ! Write 10 to 0x20003004
0x03114    80 8e 20 ff    btst  0xff, %i0
0x03118    02 80 00 05    be  0x312c
0x0311C    f0 2e 60 7c    stb  %i0, [ %i1 + 0x7c ]               ! Save low byte of argument to 0x30003C7C (delay slot)
0x03120    05 10 00 00    sethi  %hi(0x40000000), %g2
0x03124    10 80 00 04    b  0x3134
0x03128    86 10 a3 f8    or  %g2, 0x3f8, %g3                    ! 0x400003f8    ! External entry 0x400003F8 for nonzero low byte
0x0312C    05 10 00 00    sethi  %hi(0x40000000), %g2
0x03130    86 10 a3 f0    or  %g2, 0x3f0, %g3                    ! 0x400003f0    ! External entry 0x400003F0 for zero low byte
0x03134    05 08 00 0c    sethi  %hi(0x20003000), %g2
0x03138    84 10 a0 08    or  %g2, 8, %g2                        ! 0x20003008
0x0313C    9f c0 c0 00    call  %g3                              ! Call firmware/ROM entry at 0x400003F0 or 0x400003F8
0x03140    01 00 00 00    nop
0x03144    d0 20 a0 00    st  %o0, [ %g2 ]                       ! Save returned register o0 to MMIO 0x20003008
0x03148    d2 20 a0 04    st  %o1, [ %g2 + 4 ]                   ! Save returned register o1
0x0314C    d4 20 a0 08    st  %o2, [ %g2 + 8 ]                   ! Save returned register o2
0x03150    d6 20 a0 0c    st  %o3, [ %g2 + 0xc ]                 ! Save returned register o3
0x03154    d8 20 a0 10    st  %o4, [ %g2 + 0x10 ]                ! Save returned register o4
0x03158    da 20 a0 14    st  %o5, [ %g2 + 0x14 ]                ! Save returned register o5
0x0315C    31 08 00 0a    sethi  %hi(0x20002800), %i0
0x03160    84 16 20 c4    or  %i0, 0xc4, %g2                     ! 0x200028c4
0x03164    c0 20 80 00    clr  [ %g2 ]                           ! Clear 0x200028C4
0x03168    b2 16 20 d4    or  %i0, 0xd4, %i1
0x0316C    07 00 00 20    sethi  %hi(0x8000), %g3
0x03170    c0 26 40 00    clr  [ %i1 ]                           ! Clear 0x200028D4
0x03174    86 10 e0 0a    or  %g3, 0xa, %g3
0x03178    84 16 20 c0    or  %i0, 0xc0, %g2
0x0317C    c6 20 80 00    st  %g3, [ %g2 ]                       ! Write 0x800A to 0x200028C0
0x03180    b0 16 20 d0    or  %i0, 0xd0, %i0
0x03184    c6 26 00 00    st  %g3, [ %i0 ]                       ! Write 0x800A to 0x200028D0
0x03188    81 c7 e0 08    ret
0x0318C    81 e8 00 00    restore

! 0x3190: Hardware operation and optional XOR transformation
! Program hardware, poll status with timeout, optionally XOR a buffer in 32-bit words.
0x03190    9d e3 bf 98    save  %sp, -104, %sp
0x03194    15 08 00 0a    sethi  %hi(0x20002800), %o2
0x03198    17 30 00 00    sethi  %hi(0xc0000000), %o3
0x0319C    b0 06 00 0b    add  %i0, %o3, %i0                     ! Translate first address with +0xC0000000
0x031A0    90 12 a0 d8    or  %o2, 0xd8, %o0
0x031A4    f0 22 00 00    st  %i0, [ %o0 ]                       ! Write translated address to 0x200028D8
0x031A8    90 12 a0 c8    or  %o2, 0xc8, %o0
0x031AC    96 06 40 0b    add  %i1, %o3, %o3                     ! Translate second address
0x031B0    d6 22 00 00    st  %o3, [ %o0 ]                       ! Write translated address to 0x200028C8
0x031B4    13 00 80 00    sethi  %hi(0x2000000), %o1
0x031B8    98 12 a0 c0    or  %o2, 0xc0, %o4
0x031BC    92 16 80 09    or  %i2, %o1, %o1
0x031C0    96 12 a0 dc    or  %o2, 0xdc, %o3
0x031C4    11 00 c0 00    sethi  %hi(0x3000000), %o0
0x031C8    d2 22 c0 00    st  %o1, [ %o3 ]                       ! Write length/flags to 0x200028DC
0x031CC    94 12 a0 cc    or  %o2, 0xcc, %o2
0x031D0    90 16 80 08    or  %i2, %o0, %o0
0x031D4    d0 22 80 00    st  %o0, [ %o2 ]                       ! Write length/flags to 0x200028CC
0x031D8    d2 03 00 00    ld  [ %o4 ], %o1                       ! Read controller status 0x200028C0
0x031DC    15 00 00 10    sethi  %hi(0x4000), %o2
0x031E0    80 8a 40 0a    btst  %o1, %o2                         ! Test busy bit 14
0x031E4    02 80 00 12    be  0x322c
0x031E8    b0 10 20 00    clr  %i0
0x031EC    11 00 18 f5    sethi  %hi(0x63d400), %o0              ! Load polling limit 0x63D76A
0x031F0    a4 12 23 6a    or  %o0, 0x36a, %l2                    ! 0x63d76a
0x031F4    a2 10 00 0c    mov  %o4, %l1
0x031F8    a0 10 00 0a    mov  %o2, %l0
0x031FC    7f ff fd 4c    call  0x272c                           ! Delay one unit before retry
0x03200    90 10 20 01    mov  1, %o0
0x03204    b0 06 20 01    inc  %i0
0x03208    80 a6 00 12    cmp  %i0, %l2                          ! Check timeout counter
0x0320C    08 80 00 04    bleu  0x321c
0x03210    01 00 00 00    nop
0x03214    10 80 00 18    b  0x3274
0x03218    b0 10 3f ff    mov  -1, %i0                           ! 0xffffffff    ! Timeout result = -1 (delay slot)
0x0321C    d0 04 40 00    ld  [ %l1 ], %o0
0x03220    80 8a 00 10    btst  %o0, %l0                         ! Test busy bit again
0x03224    12 bf ff f6    bne  0x31fc
0x03228    01 00 00 00    nop
0x0322C    11 0c 00 0f    sethi  %hi(0x30003c00), %o0
0x03230    d2 0a 20 7c    ldub  [ %o0 + 0x7c ], %o1              ! 0x30003c7c    ! Read option byte at 0x30003C7C
0x03234    80 a2 60 00    cmp  %o1, 0
0x03238    02 80 00 0e    be  0x3270
0x0323C    b0 10 20 00    clr  %i0
0x03240    80 a6 00 1a    cmp  %i0, %i2                          ! Check word offset against requested size
0x03244    1a 80 00 0c    bcc  0x3274
0x03248    11 30 7f 35    sethi  %hi(0xc1fcd400), %o0
0x0324C    94 12 20 08    or  %o0, 8, %o2                        ! 0xc1fcd408    ! XOR seed 0xC1FCD408
0x03250    d0 06 40 18    ld  [ %i1 + %i0 ], %o0                 ! Load 32-bit word from buffer
0x03254    92 06 00 0a    add  %i0, %o2, %o1
0x03258    90 1a 00 09    xor  %o0, %o1, %o0                     ! XOR word with seed + offset
0x0325C    d0 26 40 18    st  %o0, [ %i1 + %i0 ]                 ! Write transformed word in place
0x03260    b0 06 20 04    add  %i0, 4, %i0                       ! Advance four bytes
0x03264    80 a6 00 1a    cmp  %i0, %i2
0x03268    2a bf ff fb    bcs,a   0x3254                         ! Annulled branch; next word loaded only on loop
0x0326C    d0 06 40 18    ld  [ %i1 + %i0 ], %o0
0x03270    b0 10 20 00    clr  %i0                               ! Return success = 0
0x03274    81 c7 e0 08    ret
0x03278    81 e8 00 00    restore

! 0x327C: Hardware status/diagnostic routine
! Program registers, inspect status fields and call diagnostic handler.
0x0327C    9d e3 bf 98    save  %sp, -104, %sp
0x03280    21 08 00 00    sethi  %hi(0x20000000), %l0
0x03284    96 14 20 40    or  %l0, 0x40, %o3                     ! 0x20000040
0x03288    11 00 00 20    sethi  %hi(0x8000), %o0
0x0328C    d0 22 c0 00    st  %o0, [ %o3 ]                       ! Set MMIO 0x20000040 to 0x8000
0x03290    92 14 20 44    or  %l0, 0x44, %o1
0x03294    90 10 22 62    mov  0x262, %o0
0x03298    d0 22 40 00    st  %o0, [ %o1 ]                       ! Write 0x262 to 0x20000044
0x0329C    94 14 20 50    or  %l0, 0x50, %o2
0x032A0    11 00 00 6a    sethi  %hi(0x1a800), %o0
0x032A4    d0 22 80 00    st  %o0, [ %o2 ]                       ! Write 0x1A800 to 0x20000050
0x032A8    92 10 21 00    mov  0x100, %o1
0x032AC    d2 22 c0 00    st  %o1, [ %o3 ]                       ! Write 0x100 to 0x20000040
0x032B0    7f ff fd 1f    call  0x272c                           ! Wait using delay routine
0x032B4    90 10 23 e8    mov  0x3e8, %o0
0x032B8    92 14 20 c0    or  %l0, 0xc0, %o1
0x032BC    d0 02 40 00    ld  [ %o1 ], %o0                       ! Read 0x200000C0
0x032C0    80 8a 20 80    btst  0x80, %o0                        ! Check status bit 7
0x032C4    02 80 00 04    be  0x32d4
0x032C8    01 00 00 00    nop
0x032CC    10 80 00 39    b  0x33b0
0x032D0    b0 10 20 00    clr  %i0                               ! 0x0
0x032D4    d0 02 40 00    ld  [ %o1 ], %o0
0x032D8    80 8a 20 80    btst  0x80, %o0
0x032DC    12 80 00 33    bne  0x33a8
0x032E0    90 10 20 00    clr  %o0
0x032E4    94 14 20 4c    or  %l0, 0x4c, %o2
0x032E8    d2 02 80 00    ld  [ %o2 ], %o1                       ! Read status at 0x2000004C
0x032EC    11 00 3f fe    sethi  %hi(0xfff800), %o0
0x032F0    80 8a 40 08    btst  %o1, %o0                         ! Test upper status bits (mask 0xFFF800)
0x032F4    02 80 00 2d    be  0x33a8
0x032F8    90 10 20 00    clr  %o0
0x032FC    a2 10 00 10    mov  %l0, %l1
0x03300    a0 10 00 0a    mov  %o2, %l0
0x03304    d0 04 00 00    ld  [ %l0 ], %o0
0x03308    92 10 20 35    mov  0x35, %o1
0x0330C    91 32 20 0b    srl  %o0, 0xb, %o0                     ! Shift status field down 11 bits
0x03310    b0 22 40 08    sub  %o1, %o0, %i0                     ! Compute diagnostic value 0x35 - field
0x03314    80 a6 20 33    cmp  %i0, 0x33
0x03318    34 80 00 10    bg,a   0x3358
0x0331C    90 10 20 00    clr  %o0
0x03320    80 a6 20 31    cmp  %i0, 0x31
0x03324    14 80 00 08    bg  0x3344
0x03328    90 10 20 00    clr  %o0
0x0332C    80 a6 20 1f    cmp  %i0, 0x1f
0x03330    14 80 00 0a    bg  0x3358
0x03334    01 00 00 00    nop
0x03338    80 a6 20 1d    cmp  %i0, 0x1d
0x0333C    04 80 00 05    ble  0x3350
0x03340    80 a6 20 06    cmp  %i0, 6
0x03344    40 00 00 d2    call  0x368c                           ! Report diagnostic code 0xF
0x03348    92 10 20 0f    mov  0xf, %o1
0x0334C    30 80 00 0b    b,a   0x3378
0x03350    04 80 00 05    ble  0x3364
0x03354    90 10 20 00    clr  %o0
0x03358    40 00 00 cd    call  0x368c                           ! Report diagnostic code 0
0x0335C    92 10 20 00    clr  %o1
0x03360    30 80 00 06    b,a   0x3378
0x03364    80 a6 20 04    cmp  %i0, 4
0x03368    04 80 00 04    ble  0x3378
0x0336C    01 00 00 00    nop
0x03370    40 00 00 c7    call  0x368c                           ! Report diagnostic code 0xF
0x03374    92 10 20 0f    mov  0xf, %o1                          ! 0xf
0x03378    7f ff fc ed    call  0x272c
0x0337C    90 10 20 01    mov  1, %o0
0x03380    90 14 60 c0    or  %l1, 0xc0, %o0                     ! Re-read status register 0x200000C0
0x03384    d2 02 00 00    ld  [ %o0 ], %o1
0x03388    80 8a 60 80    btst  0x80, %o1
0x0338C    12 80 00 07    bne  0x33a8
0x03390    90 10 20 00    clr  %o0
0x03394    d2 04 00 00    ld  [ %l0 ], %o1                       ! Re-read status register 0x2000004C
0x03398    11 00 3f fe    sethi  %hi(0xfff800), %o0
0x0339C    80 8a 40 08    btst  %o1, %o0
0x033A0    12 bf ff d9    bne  0x3304                            ! Repeat while masked status remains set
0x033A4    90 10 20 00    clr  %o0
0x033A8    40 00 00 b9    call  0x368c                           ! Final diagnostic call
0x033AC    92 10 20 00    clr  %o1
0x033B0    81 c7 e0 08    ret
0x033B4    81 e8 00 00    restore

! 0x33B8: 512-byte block validation
! Check trailing marker and calculate a 16-bit word sum against 0xBEEF.
0x033B8    96 10 00 08    mov  %o0, %o3
0x033BC    c4 0a e1 fe    ldub  [ %o3 + 0x1fe ], %g2             ! Read byte at block offset 0x1FE
0x033C0    80 a0 a0 30    cmp  %g2, 0x30                         ! Require ASCII 0 (0x30)
0x033C4    12 80 00 06    bne  0x33dc
0x033C8    94 10 20 00    clr  %o2
0x033CC    c4 0a e1 ff    ldub  [ %o3 + 0x1ff ], %g2             ! Read byte at block offset 0x1FF
0x033D0    80 a0 a0 65    cmp  %g2, 0x65                         ! Require ASCII e (0x65)
0x033D4    02 80 00 04    be  0x33e4
0x033D8    92 10 21 00    mov  0x100, %o1
0x033DC    10 80 00 13    b  0x3428
0x033E0    90 10 20 01    mov  1, %o0                            ! Invalid marker -> return 1
0x033E4    85 2a 60 10    sll  %o1, 0x10, %g2
0x033E8    85 30 a0 10    srl  %g2, 0x10, %g2
0x033EC    92 02 60 02    add  %o1, 2, %o1
0x033F0    d0 12 c0 02    lduh  [ %o3 + %g2 ], %o0               ! Read unsigned 16-bit word from block
0x033F4    87 2a 60 10    sll  %o1, 0x10, %g3
0x033F8    84 02 80 08    add  %o2, %o0, %g2                     ! Accumulate 16-bit words
0x033FC    87 30 e0 10    srl  %g3, 0x10, %g3
0x03400    80 a0 e1 ff    cmp  %g3, 0x1ff                        ! Continue through offset 0x1FE
0x03404    08 bf ff f8    bleu  0x33e4
0x03408    94 10 00 02    mov  %g2, %o2                          ! Update sum in branch delay slot
0x0340C    87 28 a0 10    sll  %g2, 0x10, %g3
0x03410    05 00 00 2f    sethi  %hi(0xbc00), %g2
0x03414    87 30 e0 10    srl  %g3, 0x10, %g3
0x03418    84 10 a2 ef    or  %g2, 0x2ef, %g2                    ! Expected 16-bit sum = 0xBEEF
0x0341C    86 18 c0 02    xor  %g3, %g2, %g3                     ! Compare computed sum with 0xBEEF
0x03420    80 a0 00 03    cmp  %g0, %g3
0x03424    90 40 20 00    addx  %g0, 0, %o0                      ! Return 0 on match, 1 otherwise
0x03428    81 c3 e0 08    retl
0x0342C    01 00 00 00    nop

! 0x3430: Read, validate, and unpack NAND configuration page
! First read: NAND page 0x40 (64) -> RAM 0x87800000.
! If validation fails, read NAND page 0xE0 (224) and validate again.
! If that also fails, read page 0x40 once more (without an immediate
! third validation call in the shown code). These are PAGE INDICES,
! not byte counts. This is a configuration-data fallback, not proof
! of a dual-bootloader fallback mechanism.
0x03430    9d e3 bf 98    save  %sp, -104, %sp
0x03434    21 21 e0 00    sethi  %hi(0x87800000), %l0            ! External source buffer 0x87800000
0x03438    92 10 00 10    mov  %l0, %o1
0x0343C    7f ff fb 88    call  0x225c                           ! Read NAND page 0x40 (64) to RAM 0x87800000
0x03440    90 10 20 40    mov  0x40, %o0
0x03444    7f ff ff dd    call  0x33b8                           ! Validate source block at 0x87800000
0x03448    90 10 00 10    mov  %l0, %o0
0x0344C    90 0a 20 ff    and  %o0, 0xff, %o0
0x03450    80 a2 20 00    cmp  %o0, 0
0x03454    02 80 00 0d    be  0x3488
0x03458    23 20 00 00    sethi  %hi(0x80000000), %l1
0x0345C    92 10 00 10    mov  %l0, %o1
0x03460    7f ff fb 7f    call  0x225c                           ! Retry using alternate NAND page 0xE0 (224)
0x03464    90 10 20 e0    mov  0xe0, %o0
0x03468    7f ff ff d4    call  0x33b8                           ! Validate source block again
0x0346C    90 10 00 10    mov  %l0, %o0
0x03470    90 0a 20 ff    and  %o0, 0xff, %o0
0x03474    80 a2 20 00    cmp  %o0, 0
0x03478    02 80 00 04    be  0x3488
0x0347C    90 10 20 40    mov  0x40, %o0
0x03480    7f ff fb 77    call  0x225c                           ! Re-read NAND page 0x40 (not a byte count)
0x03484    92 10 00 10    mov  %l0, %o1
0x03488    d2 0c 21 06    ldub  [ %l0 + 0x106 ], %o1             ! Read first byte of 16-bit field at offsets 0x106..0x107
0x0348C    11 0c 00 0f    sethi  %hi(0x30003c00), %o0
0x03490    d4 0c 21 07    ldub  [ %l0 + 0x107 ], %o2
0x03494    93 2a 60 08    sll  %o1, 8, %o1
0x03498    d6 02 20 78    ld  [ %o0 + 0x78 ], %o3
0x0349C    94 12 80 09    or  %o2, %o1, %o2
0x034A0    11 0c 00 0f    sethi  %hi(0x30003c00), %o0
0x034A4    d4 24 60 04    st  %o2, [ %l1 + 4 ]                   ! Store combined field at 0x80000004
0x034A8    d6 24 40 00    st  %o3, [ %l1 ]                       ! Store value from 0x30003C78 at 0x80000000
0x034AC    84 12 20 80    or  %o0, 0x80, %g2
0x034B0    96 10 20 00    clr  %o3
0x034B4    9a 04 60 90    add  %l1, 0x90, %o5
0x034B8    86 04 60 b0    add  %l1, 0xb0, %g3
0x034BC    9e 04 60 d0    add  %l1, 0xd0, %o7
0x034C0    82 04 60 e4    add  %l1, 0xe4, %g1
0x034C4    98 14 60 08    or  %l1, 8, %o4
0x034C8    94 10 00 10    mov  %l0, %o2
0x034CC    d0 0a a1 00    ldub  [ %o2 + 0x100 ], %o0             ! Copy source bytes beginning at +0x100
0x034D0    d0 2b 00 0b    stb  %o0, [ %o4 + %o3 ]                ! Copy byte into destination at 0x80000008 + index
0x034D4    d2 0a a1 00    ldub  [ %o2 + 0x100 ], %o1
0x034D8    d2 28 80 0b    stb  %o1, [ %g2 + %o3 ]                ! Duplicate byte into 0x30003C80 + index
0x034DC    96 02 e0 01    inc  %o3
0x034E0    80 a2 e0 05    cmp  %o3, 5
0x034E4    04 bf ff fa    ble  0x34cc
0x034E8    94 02 a0 01    inc  %o2
0x034EC    92 10 00 0d    mov  %o5, %o1
0x034F0    96 10 20 00    clr  %o3
0x034F4    90 02 c0 10    add  %o3, %l0, %o0
0x034F8    d0 0a 21 08    ldub  [ %o0 + 0x108 ], %o0             ! Read text field at source +0x108
0x034FC    80 a2 20 0a    cmp  %o0, 0xa
0x03500    32 80 00 03    bne,a   0x350c                         ! Treat LF (0x0A) as terminator
0x03504    d0 2a 40 0b    stb  %o0, [ %o1 + %o3 ]                ! Annulled: copy non-LF byte
0x03508    c0 2a 40 0b    clrb  [ %o1 + %o3 ]                    ! Replace LF with NUL
0x0350C    96 02 e0 01    inc  %o3
0x03510    80 a2 e0 1f    cmp  %o3, 0x1f
0x03514    04 bf ff f9    ble  0x34f8
0x03518    90 02 c0 10    add  %o3, %l0, %o0
0x0351C    92 10 00 03    mov  %g3, %o1
0x03520    96 10 20 00    clr  %o3
0x03524    90 02 c0 10    add  %o3, %l0, %o0
0x03528    d0 0a 21 28    ldub  [ %o0 + 0x128 ], %o0             ! Read next text field at source +0x128
0x0352C    80 a2 20 0a    cmp  %o0, 0xa
0x03530    32 80 00 03    bne,a   0x353c
0x03534    d0 2a 40 0b    stb  %o0, [ %o1 + %o3 ]
0x03538    c0 2a 40 0b    clrb  [ %o1 + %o3 ]                    ! Replace LF with NUL
0x0353C    96 02 e0 01    inc  %o3
0x03540    80 a2 e0 1f    cmp  %o3, 0x1f
0x03544    04 bf ff f9    ble  0x3528
0x03548    90 02 c0 10    add  %o3, %l0, %o0
0x0354C    92 10 00 0f    mov  %o7, %o1
0x03550    96 10 20 00    clr  %o3
0x03554    90 02 c0 10    add  %o3, %l0, %o0
0x03558    d0 0a 21 48    ldub  [ %o0 + 0x148 ], %o0             ! Read text field at source +0x148
0x0355C    80 a2 20 0a    cmp  %o0, 0xa
0x03560    32 80 00 03    bne,a   0x356c
0x03564    d0 2a 40 0b    stb  %o0, [ %o1 + %o3 ]
0x03568    c0 2a 40 0b    clrb  [ %o1 + %o3 ]                    ! Replace LF with NUL
0x0356C    96 02 e0 01    inc  %o3
0x03570    80 a2 e0 0f    cmp  %o3, 0xf
0x03574    04 bf ff f9    ble  0x3558
0x03578    90 02 c0 10    add  %o3, %l0, %o0
0x0357C    94 10 00 01    mov  %g1, %o2
0x03580    96 10 20 00    clr  %o3
0x03584    90 02 c0 10    add  %o3, %l0, %o0
0x03588    d2 0a 21 80    ldub  [ %o0 + 0x180 ], %o1             ! Read source byte at +0x180 + index
0x0358C    d2 2a 80 0b    stb  %o1, [ %o2 + %o3 ]                ! Copy 128-byte payload to 0x800000E4 + index
0x03590    96 02 e0 01    inc  %o3
0x03594    80 a2 e0 7f    cmp  %o3, 0x7f
0x03598    04 bf ff fc    ble  0x3588
0x0359C    90 02 c0 10    add  %o3, %l0, %o0
0x035A0    d0 0c 21 80    ldub  [ %l0 + 0x180 ], %o0             ! Read payload type byte
0x035A4    80 a2 20 03    cmp  %o0, 3
0x035A8    32 80 00 07    bne,a   0x35c4                         ! If type is 3, take special MMIO action
0x035AC    d0 0c 21 77    ldub  [ %l0 + 0x177 ], %o0
0x035B0    11 08 00 02    sethi  %hi(0x20000800), %o0
0x035B4    90 12 20 0c    or  %o0, 0xc, %o0                      ! 0x2000080c
0x035B8    92 10 20 2f    mov  0x2f, %o1
0x035BC    d2 22 00 00    st  %o1, [ %o0 ]                       ! Write 0x2F to 0x2000080C
0x035C0    d0 0c 21 77    ldub  [ %l0 + 0x177 ], %o0             ! Read selector byte at source +0x177
0x035C4    80 a2 20 01    cmp  %o0, 1
0x035C8    12 80 00 04    bne  0x35d8
0x035CC    80 a2 20 02    cmp  %o0, 2
0x035D0    10 80 00 05    b  0x35e4
0x035D4    90 10 20 43    mov  0x43, %o0                         ! Selector 1 maps to ASCII C
0x035D8    12 80 00 03    bne  0x35e4
0x035DC    90 10 20 41    mov  0x41, %o0                         ! Selector 2 defaults to ASCII A
0x035E0    90 10 20 42    mov  0x42, %o0                         ! Selector 2 maps to ASCII B
0x035E4    d0 2c 60 0e    stb  %o0, [ %l1 + 0xe ]                ! Write selector character at 0x8000000E
0x035E8    d0 04 21 78    ld  [ %l0 + 0x178 ], %o0               ! Read source 32-bit field +0x178
0x035EC    d0 24 60 e0    st  %o0, [ %l1 + 0xe0 ]                ! Store field at 0x800000E0
0x035F0    81 c7 e0 08    ret
0x035F4    81 e8 00 00    restore

! 0x35F8: Diagnostic status reporting
! Print status messages and write a status code to shared RAM.
0x035F8    9d e3 bf 98    save  %sp, -104, %sp
0x035FC    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x03600    7f ff f4 ab    call  0x8ac                            ! Print text from 0x300039C8
0x03604    90 12 21 c8    or  %o0, 0x1c8, %o0                    ! 0x300039c8
0x03608    7f ff ff 1d    call  0x327c                           ! Run hardware diagnostic routine
0x0360C    21 20 00 00    sethi  %hi(0x80000000), %l0
0x03610    90 0a 20 ff    and  %o0, 0xff, %o0
0x03614    80 a2 20 31    cmp  %o0, 0x31                         ! Compare returned low byte to 0x31
0x03618    08 80 00 08    bleu  0x3638
0x0361C    80 a2 20 1d    cmp  %o0, 0x1d
0x03620    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x03624    7f ff f4 ad    call  0x8d8                            ! Print diagnostic text at 0x300039D0
0x03628    90 12 21 d0    or  %o0, 0x1d0, %o0                    ! 0x300039d0
0x0362C    92 10 20 09    mov  9, %o1
0x03630    10 80 00 15    b  0x3684
0x03634    d2 2c 20 0f    stb  %o1, [ %l0 + 0xf ]                ! Write status byte 9 to 0x8000000F
0x03638    08 80 00 08    bleu  0x3658
0x0363C    80 a2 20 04    cmp  %o0, 4
0x03640    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x03644    7f ff f4 a5    call  0x8d8                            ! Print diagnostic text at 0x300039E0
0x03648    90 12 21 e0    or  %o0, 0x1e0, %o0                    ! 0x300039e0
0x0364C    92 10 20 01    mov  1, %o1
0x03650    10 80 00 0d    b  0x3684
0x03654    d2 2c 20 0f    stb  %o1, [ %l0 + 0xf ]                ! Write status byte 1
0x03658    08 80 00 08    bleu  0x3678
0x0365C    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x03660    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x03664    7f ff f4 9d    call  0x8d8                            ! Print diagnostic text at 0x300039F8
0x03668    90 12 21 f8    or  %o0, 0x1f8, %o0                    ! 0x300039f8
0x0366C    92 10 20 07    mov  7, %o1
0x03670    10 80 00 05    b  0x3684
0x03674    d2 2c 20 0f    stb  %o1, [ %l0 + 0xf ]                ! Write status byte 7
0x03678    7f ff f4 98    call  0x8d8                            ! Print diagnostic text at 0x30003A10
0x0367C    90 12 22 10    or  %o0, 0x210, %o0
0x03680    c0 2c 20 0f    clrb  [ %l0 + 0xf ]                    ! Clear status byte at 0x8000000F
0x03684    81 c7 e0 08    ret
0x03688    81 e8 00 00    restore

! 0x368C: Hardware error/status signaling
! Drive a control register with pulses or bitfields, using timed delays.
0x0368C    9d e3 bf 98    save  %sp, -104, %sp
0x03690    90 06 7f fe    add  %i1, -2, %o0                      ! Compute error code minus 2
0x03694    90 0a 20 ff    and  %o0, 0xff, %o0
0x03698    2d 20 00 00    sethi  %hi(0x80000000), %l6
0x0369C    80 a2 20 02    cmp  %o0, 2
0x036A0    d2 0d a0 e4    ldub  [ %l6 + 0xe4 ], %o1              ! Read type byte at 0x800000E4 (delay slot)
0x036A4    90 40 20 00    addx  %g0, 0, %o0
0x036A8    ae 10 00 08    mov  %o0, %l7
0x036AC    80 a2 60 03    cmp  %o1, 3
0x036B0    12 80 00 03    bne  0x36bc
0x036B4    a6 10 00 19    mov  %i1, %l3
0x036B8    a6 38 00 19    xnor  %g0, %i1, %l3                    ! Invert error code when type is 3
0x036BC    90 0e 20 ff    and  %i0, 0xff, %o0                    ! Take low byte of first argument
0x036C0    80 a2 20 00    cmp  %o0, 0
0x036C4    02 80 00 05    be  0x36d8
0x036C8    a8 10 00 08    mov  %o0, %l4
0x036CC    11 08 00 02    sethi  %hi(0x20000800), %o0
0x036D0    90 12 20 08    or  %o0, 8, %o0                        ! 0x20000808
0x036D4    c0 22 00 00    clr  [ %o0 ]                           ! Clear MMIO 0x20000808 when requested
0x036D8    2b 08 00 02    sethi  %hi(0x20000800), %l5
0x036DC    d0 0d a0 0e    ldub  [ %l6 + 0xe ], %o0               ! Read selector at 0x8000000E
0x036E0    80 a2 20 41    cmp  %o0, 0x41
0x036E4    02 80 00 24    be  0x3774                             ! Select alternate signaling for ASCII A
0x036E8    80 a5 20 00    cmp  %l4, 0
0x036EC    02 80 00 22    be  0x3774
0x036F0    a2 0c e0 ff    and  %l3, 0xff, %l1
0x036F4    21 00 00 18    sethi  %hi(0x6000), %l0
0x036F8    b2 15 60 0c    or  %l5, 0xc, %i1
0x036FC    a4 10 20 ff    mov  0xff, %l2
0x03700    b0 10 20 02    mov  2, %i0
0x03704    7f ff fc 0a    call  0x272c                           ! Long delay before pulse
0x03708    90 14 21 a8    or  %l0, 0x1a8, %o0
0x0370C    e4 26 40 00    st  %l2, [ %i1 ]                       ! Write 0xFF to 0x2000080C
0x03710    7f ff fc 07    call  0x272c
0x03714    90 14 21 a8    or  %l0, 0x1a8, %o0
0x03718    c0 26 40 00    clr  [ %i1 ]                           ! Clear pulse register
0x0371C    b0 86 3f ff    addcc  %i0, -1, %i0
0x03720    1c bf ff f9    bpos  0x3704                           ! Repeat pulse sequence
0x03724    80 a4 60 00    cmp  %l1, 0
0x03728    02 80 00 0e    be  0x3760
0x0372C    b0 10 00 11    mov  %l1, %i0
0x03730    21 00 00 61    sethi  %hi(0x18400), %l0
0x03734    b2 15 60 0c    or  %l5, 0xc, %i1
0x03738    a2 10 20 01    mov  1, %l1
0x0373C    7f ff fb fc    call  0x272c
0x03740    90 14 22 a0    or  %l0, 0x2a0, %o0
0x03744    e2 26 40 00    st  %l1, [ %i1 ]                       ! Write 1 to 0x2000080C
0x03748    7f ff fb f9    call  0x272c
0x0374C    90 14 22 a0    or  %l0, 0x2a0, %o0
0x03750    c0 26 40 00    clr  [ %i1 ]                           ! Clear pulse register
0x03754    b0 86 3f ff    addcc  %i0, -1, %i0
0x03758    12 bf ff f9    bne  0x373c                            ! Repeat selected pulse count
0x0375C    01 00 00 00    nop
0x03760    11 00 00 49    sethi  %hi(0x12400), %o0
0x03764    7f ff fb f2    call  0x272c
0x03768    90 12 20 f8    or  %o0, 0xf8, %o0                     ! 0x124f8
0x0376C    10 80 00 14    b  0x37bc
0x03770    80 a5 20 00    cmp  %l4, 0
0x03774    94 15 60 0c    or  %l5, 0xc, %o2
0x03778    80 a5 20 00    cmp  %l4, 0
0x0377C    12 80 00 06    bne  0x3794
0x03780    92 0c e0 0f    and  %l3, 0xf, %o1
0x03784    d0 02 80 00    ld  [ %o2 ], %o0                       ! Read existing MMIO value
0x03788    90 0a 20 f0    and  %o0, 0xf0, %o0                    ! Preserve upper nibble
0x0378C    10 80 00 03    b  0x3798
0x03790    90 12 00 09    or  %o0, %o1, %o0
0x03794    90 10 00 09    mov  %o1, %o0
0x03798    d0 22 80 00    st  %o0, [ %o2 ]                       ! Write low-nibble status to 0x2000080C
0x0379C    80 8d e0 ff    btst  0xff, %l7
0x037A0    02 80 00 07    be  0x37bc
0x037A4    80 a5 20 00    cmp  %l4, 0
0x037A8    11 00 00 92    sethi  %hi(0x24800), %o0
0x037AC    7f ff fb e0    call  0x272c                           ! Delay before toggling status
0x037B0    90 12 21 f0    or  %o0, 0x1f0, %o0                    ! 0x249f0
0x037B4    a6 38 00 13    xnor  %g0, %l3, %l3                    ! Invert code for next cycle
0x037B8    80 a5 20 00    cmp  %l4, 0
0x037BC    32 bf ff c9    bne,a   0x36e0                         ! Loop if first argument nonzero; annulled delay slot
0x037C0    d0 0d a0 0e    ldub  [ %l6 + 0xe ], %o0
0x037C4    81 c7 e0 08    ret
0x037C8    81 e8 00 00    restore

! 0x37CC: Indirect jump to parsed address
! Parse an address string, align it and jump to it; does not return normally.
0x037CC    9d e3 bf 98    save  %sp, -104, %sp
0x037D0    d0 06 60 04    ld  [ %i1 + 4 ], %o0                   ! Read ASCII address pointer from argument structure
0x037D4    92 10 20 00    clr  %o1
0x037D8    7f ff f4 26    call  0x870                            ! Convert address string to integer using 0x870
0x037DC    94 10 20 00    clr  %o2
0x037E0    90 0a 3f fc    and  %o0, -4, %o0                      ! Force 4-byte alignment
0x037E4    15 00 00 c0    sethi  %hi(0x30000), %o2
0x037E8    92 10 20 c0    mov  0xc0, %o1
0x037EC    81 c2 00 00    jmp  %o0                               ! Indirect jump to parsed address
0x037F0    01 00 00 00    nop
0x037F4    81 c7 e0 08    ret
0x037F8    81 e8 00 00    restore

! 0x37FC–0x3B68: iBoot main initialization and interactive monitor
! Steps:
! 1. Configure MMIO and invoke initialization routines.
! 2. Load configuration, select hardware/boot mode, and try automatic boot.
! 3. On boot interruption/failure, read and parse commands from the UART.
! 4. Dispatch monitor commands; the next region contains data, not code.
0x037FC    9d e3 bf 30    save  %sp, -208, %sp                   ! Bootloader main routine: initialize hardware, select boot path, then command loop
0x03800    13 08 00 00    sethi  %hi(0x20000000), %o1
0x03804    11 00 00 04    sethi  %hi(0x1000), %o0
0x03808    92 12 61 00    or  %o1, 0x100, %o1
0x0380C    90 12 20 10    or  %o0, 0x10, %o0
0x03810    d0 22 40 00    st  %o0, [ %o1 ]                       ! Configure MMIO register 0x20000100
0x03814    23 20 00 00    sethi  %hi(0x80000000), %l1
0x03818    29 0c 00 0f    sethi  %hi(0x30003c00), %l4
0x0381C    31 0c 00 0e    sethi  %hi(0x30003800), %i0
0x03820    aa 07 bf 90    add  %fp, -112, %l5
0x03824    2d 0c 00 0e    sethi  %hi(0x30003800), %l6
0x03828    2f 0c 00 0e    sethi  %hi(0x30003800), %l7
0x0382C    92 10 20 13    mov  0x13, %o1
0x03830    92 82 7f ff    addcc  %o1, -1, %o1
0x03834    1c 80 00 00    bpos  0x3834                           ! Short spin loop; delay-slot decrement also executes
0x03838    92 82 7f ff    addcc  %o1, -1, %o1
0x0383C    13 08 00 02    sethi  %hi(0x20000800), %o1
0x03840    90 10 20 06    mov  6, %o0
0x03844    d0 22 40 00    st  %o0, [ %o1 ]                       ! Write 6 to MMIO 0x20000800
0x03848    94 12 60 08    or  %o1, 8, %o2
0x0384C    11 00 38 00    sethi  %hi(0xe00000), %o0
0x03850    d0 22 80 00    st  %o0, [ %o2 ]                       ! Configure MMIO 0x20000808
0x03854    92 12 60 0c    or  %o1, 0xc, %o1
0x03858    90 10 20 20    mov  0x20, %o0
0x0385C    d0 22 40 00    st  %o0, [ %o1 ]                       ! Write 0x20 to MMIO 0x2000080C
0x03860    7f ff fb bb    call  0x274c                           ! Run initialization helper
0x03864    01 00 00 00    nop
0x03868    80 a2 20 00    cmp  %o0, 0
0x0386C    02 80 00 04    be  0x387c
0x03870    90 10 20 01    mov  1, %o0
0x03874    7f ff ff 86    call  0x368c                           ! Report initialization status 2
0x03878    92 10 20 02    mov  2, %o1
0x0387C    7f ff fd 53    call  0x2dc8                           ! Run second initialization helper
0x03880    01 00 00 00    nop
0x03884    80 a2 20 00    cmp  %o0, 0
0x03888    02 80 00 04    be  0x3898
0x0388C    90 10 20 01    mov  1, %o0
0x03890    7f ff ff 7f    call  0x368c                           ! Report initialization status 3
0x03894    92 10 20 03    mov  3, %o1
0x03898    7f ff fa e6    call  0x2430                           ! Run next initialization helper
0x0389C    01 00 00 00    nop
0x038A0    80 a2 20 00    cmp  %o0, 0
0x038A4    02 80 00 04    be  0x38b4
0x038A8    90 10 20 00    clr  %o0
0x038AC    7f ff ff 78    call  0x368c                           ! Report initialization status 11
0x038B0    92 10 20 0b    mov  0xb, %o1
0x038B4    7f ff fb 00    call  0x24b4                           ! Try boot-source initialization
0x038B8    01 00 00 00    nop
0x038BC    80 a2 20 00    cmp  %o0, 0
0x038C0    02 80 00 06    be  0x38d8
0x038C4    13 0c 00 0f    sethi  %hi(0x30003c00), %o1
0x038C8    92 12 60 24    or  %o1, 0x24, %o1                     ! 0x30003c24
0x038CC    7f ff ff c0    call  0x37cc                           ! On failure, transfer control to parsed address (no return)
0x038D0    90 10 20 02    mov  2, %o0
0x038D4    30 80 00 13    b,a   0x3920                           ! Unconditional annulled branch skips following display sequence
0x038D8    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x038DC    7f ff f3 f4    call  0x8ac                            ! Print welcome text
0x038E0    90 12 22 b8    or  %o0, 0x2b8, %o0                    ! 0x30003ab8
0x038E4    21 0c 00 0e    sethi  %hi(0x30003800), %l0
0x038E8    a0 14 22 c8    or  %l0, 0x2c8, %l0                    ! 0x30003ac8
0x038EC    7f ff f3 f0    call  0x8ac                            ! Print bootloader identification
0x038F0    90 10 00 10    mov  %l0, %o0
0x038F4    94 14 60 10    or  %l1, 0x10, %o2
0x038F8    92 10 20 00    clr  %o1
0x038FC    d0 0c 00 09    ldub  [ %l0 + %o1 ], %o0
0x03900    d0 2a 80 09    stb  %o0, [ %o2 + %o1 ]                ! Copy bootloader banner bytes to 0x80000010
0x03904    92 02 60 01    inc  %o1
0x03908    80 a2 60 0e    cmp  %o1, 0xe
0x0390C    28 bf ff fd    bleu,a   0x3900
0x03910    d0 0c 00 09    ldub  [ %l0 + %o1 ], %o0               ! Annulled branch delay slot performs extra load on taken path
0x03914    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x03918    7f ff f3 e5    call  0x8ac
0x0391C    90 12 22 d8    or  %o0, 0x2d8, %o0                    ! 0x30003ad8
0x03920    7f ff fe c4    call  0x3430                           ! Load and validate configuration structure
0x03924    01 00 00 00    nop
0x03928    d0 0c 60 e4    ldub  [ %l1 + 0xe4 ], %o0
0x0392C    80 a2 20 01    cmp  %o0, 1
0x03930    12 80 00 0a    bne  0x3958
0x03934    15 08 00 1c    sethi  %hi(0x20007000), %o2
0x03938    90 12 a0 48    or  %o2, 0x48, %o0                     ! 0x20007048    ! Clear four MMIO registers when configuration byte == 1
0x0393C    c0 22 00 00    clr  [ %o0 ]
0x03940    92 12 a1 48    or  %o2, 0x148, %o1
0x03944    c0 22 40 00    clr  [ %o1 ]
0x03948    90 12 a2 48    or  %o2, 0x248, %o0
0x0394C    c0 22 00 00    clr  [ %o0 ]
0x03950    94 12 a3 48    or  %o2, 0x348, %o2
0x03954    c0 22 80 00    clr  [ %o2 ]
0x03958    7f ff ff 28    call  0x35f8                           ! Choose/display boot mode
0x0395C    01 00 00 00    nop
0x03960    d2 04 60 e0    ld  [ %l1 + 0xe0 ], %o1
0x03964    11 00 08 00    sethi  %hi(0x200000), %o0
0x03968    80 8a 40 08    btst  %o1, %o0
0x0396C    02 80 00 03    be  0x3978
0x03970    11 00 80 45    sethi  %hi(0x2011400), %o0
0x03974    11 00 80 41    sethi  %hi(0x2010400), %o0
0x03978    92 12 22 00    or  %o0, 0x200, %o1                    ! 0x2010600
0x0397C    90 10 20 69    mov  0x69, %o0
0x03980    94 10 20 00    clr  %o2
0x03984    7f ff fd a1    call  0x3008                           ! Configure hardware channel using helper 0x3008
0x03988    96 10 20 03    mov  3, %o3
0x0398C    d2 04 60 e0    ld  [ %l1 + 0xe0 ], %o1
0x03990    11 00 04 00    sethi  %hi(0x100000), %o0
0x03994    80 8a 40 08    btst  %o1, %o0
0x03998    02 80 00 03    be  0x39a4
0x0399C    13 00 c0 7d    sethi  %hi(0x301f400), %o1
0x039A0    13 00 c0 5d    sethi  %hi(0x3017400), %o1
0x039A4    94 10 20 00    clr  %o2
0x039A8    96 10 20 03    mov  3, %o3
0x039AC    7f ff fd 97    call  0x3008                           ! Configure second hardware channel
0x039B0    90 10 20 69    mov  0x69, %o0
0x039B4    7f ff fd ce    call  0x30ec                           ! Initialize peripheral controller
0x039B8    90 10 20 00    clr  %o0
0x039BC    7f ff f5 33    call  0xe88                            ! Initialize additional controller/device
0x039C0    01 00 00 00    nop
0x039C4    80 a2 20 00    cmp  %o0, 0
0x039C8    02 80 00 04    be  0x39d8
0x039CC    90 10 20 00    clr  %o0
0x039D0    7f ff ff 2f    call  0x368c                           ! Report status 13 if initialization fails
0x039D4    92 10 20 0d    mov  0xd, %o1
0x039D8    7f ff f4 89    call  0xbfc                            ! Check for serial boot-interrupt key (i/I)
0x039DC    01 00 00 00    nop
0x039E0    80 a2 20 00    cmp  %o0, 0
0x039E4    02 80 00 35    be  0x3ab8                             ! Enter interactive monitor if interrupt key received
0x039E8    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x039EC    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x039F0    d2 02 23 e4    ld  [ %o0 + 0x3e4 ], %o1               ! 0x30003be4    ! Read factory-default/boot-selection flag
0x039F4    80 a2 60 00    cmp  %o1, 0
0x039F8    22 80 00 0b    be,a   0x3a24
0x039FC    92 10 20 0a    mov  0xa, %o1
0x03A00    d0 0c 60 0f    ldub  [ %l1 + 0xf ], %o0
0x03A04    80 a2 20 09    cmp  %o0, 9
0x03A08    22 80 00 07    be,a   0x3a24
0x03A0C    92 10 20 0a    mov  0xa, %o1
0x03A10    90 10 20 01    mov  1, %o0
0x03A14    7f ff fa c3    call  0x2520                           ! Try automatic boot path via 0x2520
0x03A18    92 15 20 88    or  %l4, 0x88, %o1
0x03A1C    10 80 00 1f    b  0x3a98
0x03A20    25 0c 00 0f    sethi  %hi(0x30003c00), %l2
0x03A24    7f ff ff 1a    call  0x368c                           ! Set boot-mode indicator / controller state
0x03A28    90 10 20 00    clr  %o0
0x03A2C    7f ff fd b0    call  0x30ec
0x03A30    90 10 20 01    mov  1, %o0
0x03A34    21 0c 00 0e    sethi  %hi(0x30003800), %l0
0x03A38    23 0c 00 0f    sethi  %hi(0x30003c00), %l1
0x03A3C    10 80 00 04    b  0x3a4c
0x03A40    25 0c 00 0f    sethi  %hi(0x30003c00), %l2
0x03A44    7f ff f3 9a    call  0x8ac
0x03A48    01 00 00 00    nop
0x03A4C    92 14 23 ec    or  %l0, 0x3ec, %o1
0x03A50    7f ff f8 d8    call  0x1db0                           ! Run transfer/boot helper 0x1DB0 with mode 6
0x03A54    90 10 20 06    mov  6, %o0
0x03A58    13 0c 00 0e    sethi  %hi(0x30003800), %o1
0x03A5C    80 a2 20 00    cmp  %o0, 0
0x03A60    12 bf ff f9    bne  0x3a44                            ! Retry on nonzero return
0x03A64    90 12 62 e0    or  %o1, 0x2e0, %o0
0x03A68    10 80 00 04    b  0x3a78
0x03A6C    a0 10 00 09    mov  %o1, %l0
0x03A70    7f ff f3 8f    call  0x8ac
0x03A74    01 00 00 00    nop
0x03A78    90 10 20 06    mov  6, %o0                            ! 0x6
0x03A7C    7f ff f8 cd    call  0x1db0                           ! Run second transfer/boot helper with mode 6
0x03A80    92 14 60 04    or  %l1, 4, %o1
0x03A84    80 a2 20 00    cmp  %o0, 0
0x03A88    12 bf ff fa    bne  0x3a70                            ! Retry on nonzero return
0x03A8C    90 14 22 e0    or  %l0, 0x2e0, %o0
0x03A90    7f ff fd 97    call  0x30ec
0x03A94    90 10 20 00    clr  %o0
0x03A98    11 08 00 02    sethi  %hi(0x20000800), %o0
0x03A9C    90 12 20 08    or  %o0, 8, %o0                        ! 0x20000808
0x03AA0    13 00 30 00    sethi  %hi(0xc00000), %o1
0x03AA4    d2 22 00 00    st  %o1, [ %o0 ]                       ! Set MMIO boot control bitmask 0x00C00000
0x03AA8    92 14 a0 1c    or  %l2, 0x1c, %o1
0x03AAC    7f ff ff 48    call  0x37cc                           ! Jump to boot entry address via 0x37CC
0x03AB0    90 10 20 02    mov  2, %o0
0x03AB4    11 0c 00 0e    sethi  %hi(0x30003800), %o0
0x03AB8    7f ff f3 7d    call  0x8ac                            ! Print interactive boot prompt/message
0x03ABC    90 12 22 e8    or  %o0, 0x2e8, %o0                    ! 0x30003ae8
0x03AC0    11 0c 00 0f    sethi  %hi(0x30003c00), %o0
0x03AC4    a6 12 20 88    or  %o0, 0x88, %l3                     ! 0x30003c88
0x03AC8    a4 10 00 15    mov  %l5, %l2
0x03ACC    7f ff f3 78    call  0x8ac
0x03AD0    90 16 23 18    or  %i0, 0x318, %o0
0x03AD4    90 10 00 12    mov  %l2, %o0
0x03AD8    7f ff f4 14    call  0xb28                            ! Read up to 0x63 characters from UART
0x03ADC    92 10 20 63    mov  0x63, %o1
0x03AE0    90 10 00 12    mov  %l2, %o0
0x03AE4    92 10 00 13    mov  %l3, %o1
0x03AE8    7f ff f3 e5    call  0xa7c                            ! Split input into at most six arguments
0x03AEC    94 10 20 06    mov  6, %o2
0x03AF0    a0 92 20 00    orcc  %o0, 0, %l0
0x03AF4    02 bf ff f6    be  0x3acc                             ! Empty input: restart command prompt
0x03AF8    d0 05 20 88    ld  [ %l4 + 0x88 ], %o0
0x03AFC    7f ff f2 fa    call  0x6e4                            ! Compare first argument with command name at 0x30003A78
0x03B00    92 15 a2 78    or  %l6, 0x278, %o1
0x03B04    80 a2 20 00    cmp  %o0, 0
0x03B08    22 80 00 11    be,a   0x3b4c
0x03B0C    d0 05 20 88    ld  [ %l4 + 0x88 ], %o0
0x03B10    7f ff fd 77    call  0x30ec                           ! Set command-specific hardware state
0x03B14    90 10 20 01    mov  1, %o0
0x03B18    10 80 00 04    b  0x3b28
0x03B1C    23 0c 00 0e    sethi  %hi(0x30003800), %l1
0x03B20    7f ff f3 63    call  0x8ac
0x03B24    01 00 00 00    nop
0x03B28    90 10 00 10    mov  %l0, %o0
0x03B2C    7f ff f8 a1    call  0x1db0                           ! Execute command handler 0x1DB0
0x03B30    92 15 20 88    or  %l4, 0x88, %o1
0x03B34    80 a2 20 00    cmp  %o0, 0
0x03B38    12 bf ff fa    bne  0x3b20                            ! Retry while handler returns nonzero
0x03B3C    90 14 62 e0    or  %l1, 0x2e0, %o0
0x03B40    7f ff fd 6b    call  0x30ec
0x03B44    90 10 20 00    clr  %o0
0x03B48    30 bf ff e1    b,a   0x3acc
0x03B4C    7f ff f2 e6    call  0x6e4                            ! Compare first argument with command name at 0x30003AA0
0x03B50    92 15 e2 a0    or  %l7, 0x2a0, %o1
0x03B54    80 a2 20 00    cmp  %o0, 0
0x03B58    02 bf ff dd    be  0x3acc
0x03B5C    90 10 00 10    mov  %l0, %o0
0x03B60    7f ff ff 1b    call  0x37cc                           ! Jump to user-supplied address via 0x37CC
0x03B64    92 10 00 13    mov  %l3, %o1
0x03B68    30 bf ff d9    b,a   0x3acc                           ! Unconditional annulled branch: return to prompt

! 0x3B6C–0x3FFC: Embedded strings, network templates, pointer table and padding
! Original bytes and objdump text are preserved verbatim.
! These apparent SPARC instructions are data; comments identify recognizable structures.
0x03B6C    00 00 00 00    unimp  0                               ! Embedded data begins here; do not interpret as executable instructions
0x03B70    52 00 00 00    call  0x48003b70
0x03B74    00 00 00 00    unimp  0
0x03B78    44 00 00 00    call  0x10003b78
0x03B7C    00 00 00 00    unimp  0
0x03B80    4d 08 08 08    call  0x34205ba0
0x03B84    00 00 00 00    unimp  0
0x03B88    0a 41 42 54    unknown
0x03B8C    0a 00 00 00    unknown
0x03B90    0a 4f 4b 0a    unknown
0x03B94    00 00 00 00    unimp  0
0x03B98    76 6d 6c 69    call  0xd9b5ed3c                       ! ASCII: vmlinux.bin
0x03B9C    6e 75 78 2e    call  0xb9d61c54
0x03BA0    62 69 6e 00    call  0x89a5f3a0
0x03BA4    00 00 00 00    unimp  0
0x03BA8    69 6e 69 74    call  0xa5b9e178                       ! ASCII: initrd.img
0x03BAC    72 64 2e 69    call  0xc990f550
0x03BB0    6d 67 00 00    call  0xb59c3bb0
0x03BB4    00 00 00 00    unimp  0
0x03BB8    4c 64 6b 0a    call  0x3191e7e0
0x03BBC    00 00 00 00    unimp  0
0x03BC0    4c 64 69 0a    call  0x3191dfe8
0x03BC4    00 00 00 00    unimp  0
0x03BC8    52 65 61 73    call  0x4995c194                       ! ASCII: Reason:
0x03BCC    6f 6e 3a 00    call  0xbdb923cc
0x03BD0    08 54 46 54    unknown                                ! ASCII: TFTP Boot (leading control byte)
0x03BD4    50 20 42 6f    call  0x40814590
0x03BD8    6f 74 00 00    call  0xbdd03bd8
0x03BDC    00 00 00 00    unimp  0
0x03BE0    08 46 61 63    unknown                                ! ASCII: Factory Default (leading control byte)
0x03BE4    74 6f 72 79    call  0xd1be05c8
0x03BE8    20 44 65 66    unknown
0x03BEC    61 75 6c 74    call  0x85d5edbc
0x03BF0    00 00 00 00    unimp  0
0x03BF4    00 00 00 00    unimp  0
0x03BF8    08 52 65 69    unknown                                ! ASCII: Reinstalling FW (leading control byte)
0x03BFC    6e 73 74 61    call  0xb9ce0d80
0x03C00    6c 6c 69 6e    call  0xb1b1e1b8
0x03C04    67 20 46 57    call  0x9c815560
0x03C08    00 00 00 00    unimp  0
0x03C0C    00 00 00 00    unimp  0
0x03C10    09 08 42 6f    sethi  %hi(0x2109bc00), %g4            ! ASCII: Booting (leading control bytes)
0x03C14    6f 74 69 6e    call  0xbdd1e1cc
0x03C18    67 00 00 00    call  0x9c003c18
0x03C1C    00 00 00 00    unimp  0
0x03C20    30 78 38 30    unknown                                ! ASCII: 0x80004000
0x03C24    30 30 34 30    unknown
0x03C28    30 30 00 00    unknown
0x03C2C    00 00 00 00    unimp  0
0x03C30    6b 65 72 6e    call  0xad9605e8                       ! ASCII: kernel_init
0x03C34    65 6c 5f 69    call  0x95b1b9d8
0x03C38    6e 69 74 00    call  0xb9a60c38
0x03C3C    00 00 00 00    unimp  0
0x03C40    31 39 32 2e    sethi  %hi(0xe4c8b800), %i0            ! ASCII: 192.168.125.1
0x03C44    31 36 38 2e    sethi  %hi(0xd8e0b800), %i0
0x03C48    31 32 35 2e    sethi  %hi(0xc8d4b800), %i0
0x03C4C    31 00 00 00    sethi  %hi(0), %i0
0x03C50    31 39 32 2e    sethi  %hi(0xe4c8b800), %i0            ! ASCII: 192.168.125.33
0x03C54    31 36 38 2e    sethi  %hi(0xd8e0b800), %i0
0x03C58    31 32 35 2e    sethi  %hi(0xc8d4b800), %i0
0x03C5C    33 33 00 00    sethi  %hi(0xcc000000), %i1
0x03C60    30 30 3a 30    unknown                                ! ASCII: 00:0d:a3:01:03:07
0x03C64    64 3a 61 33    call  0x90e9c130
0x03C68    3a 30 31 3a    unknown
0x03C6C    30 33 3a 30    unknown
0x03C70    37 00 00 00    sethi  %hi(0), %i3
0x03C74    00 00 00 00    unimp  0
0x03C78    74 66 74 70    call  0xd19a0e38                       ! ASCII: tftp
0x03C7C    00 00 00 00    unimp  0
0x03C80    30 78 38 31    unknown                                ! ASCII: 0x81000000
0x03C84    30 30 30 30    unknown
0x03C88    30 30 00 00    unknown
0x03C8C    00 00 00 00    unimp  0
0x03C90    69 6e 69 74    call  0xa5b9e260                       ! ASCII: initrd_init
0x03C94    72 64 5f 69    call  0xc991ba38
0x03C98    6e 69 74 00    call  0xb9a60c98
0x03C9C    00 00 00 00    unimp  0
0x03CA0    67 6f 00 00    call  0x9dbc3ca0                       ! ASCII: go
0x03CA4    00 00 00 00    unimp  0
0x03CA8    30 78 38 37    unknown                                ! ASCII: 0x87830000
0x03CAC    38 33 30 30    unknown
0x03CB0    30 30 00 00    unknown
0x03CB4    00 00 00 00    unimp  0
0x03CB8    0a 57 65 6c    unknown                                ! ASCII: Welcome to
0x03CBC    63 6f 6d 65    call  0x8dbdf250
0x03CC0    20 74 6f 20    unknown
0x03CC4    00 00 00 00    unimp  0
0x03CC8    69 62 6f 6f    call  0xa589fa84                       ! ASCII: iboot 1.00z043
0x03CCC    74 20 31 2e    call  0xd0810184
0x03CD0    30 30 7a 30    unknown
0x03CD4    34 33 00 00    unknown
0x03CD8    0a 00 00 00    unknown
0x03CDC    00 00 00 00    unimp  0
0x03CE0    21 00 00 00    sethi  %hi(0), %l0
0x03CE4    00 00 00 00    unimp  0
0x03CE8    48 65 6c 70    call  0x2195eea8                       ! ASCII: Help: tftp MAC IP IPsvr file mem / nand / go mem
0x03CEC    3a 0a 74 66    unknown
0x03CF0    74 70 20 4d    call  0xd1c0be24
0x03CF4    41 43 20 49    call  0x50cbe18
0x03CF8    50 20 49 50    call  0x40816238
0x03CFC    73 76 72 20    call  0xcdda057c
0x03D00    66 69 6c 65    call  0x99a5ee94
0x03D04    20 6d 65 6d    unknown
0x03D08    0a 6e 61 6e    unknown
0x03D0C    64 0a 67 6f    call  0x9029dac8
0x03D10    20 6d 65 6d    unknown
0x03D14    0a 00 00 00    unknown
0x03D18    69 62 6f 6f    call  0xa589fad4                       ! ASCII: iboot>
0x03D1C    74 3e 20 00    call  0xd0f8bd1c
0x03D20    00 00 00 00    unimp  0
	...
0x03D40    12 34 68 09    unknown
0x03D44    77 07 00 00    call  0xdc1c3d44
0x03D48    00 00 04 56    unimp  0x456
	...
! Erased flash: 0x03D60-0x03D6B (12 bytes of FF); 3 words collapsed.
0x03D6C    08 06 00 01    unknown                                ! Ethernet + ARP request template: 0806, 0001, 0800, 06, 04, 0001
0x03D70    08 00 06 04    unknown
0x03D74    00 01 00 00    unimp  0x10000
	...
! Erased flash: 0x03DA0-0x03DAB (12 bytes of FF); 3 words collapsed.
0x03DAC    08 00 45 00    unknown                                ! Ethernet + IPv4 packet template: 0800, IPv4 header starts 4500
0x03DB0    00 00 d9 15    unimp  0xd915
0x03DB4    40 00 01 11    call  0x41f8
0x03DB8    00 00 00 00    unimp  0
0x03DBC    00 00 00 00    unimp  0
0x03DC0    00 00 11 11    unimp  0x1111
	...
0x03DE0    87 82 00 00    wr  %o0, %asr3                         ! Embedded data/possible descriptor fields, not code
0x03DE4    00 00 00 00    unimp  0
0x03DE8    00 00 1b e7    unimp  0x1be7
0x03DEC    30 00 3a 78    unknown                                ! RAM pointer table (0x30003Axx values)
0x03DF0    30 00 3a 60    unknown
0x03DF4    30 00 3a 50    unknown
0x03DF8    30 00 3a 40    unknown
0x03DFC    30 00 3a 30    unknown
0x03E00    30 00 3a 20    unknown
0x03E04    30 00 3a 78    unknown
0x03E08    30 00 3a 60    unknown
0x03E0C    30 00 3a 50    unknown
0x03E10    30 00 3a 40    unknown
0x03E14    30 00 3a 90    unknown
0x03E18    30 00 3a 80    unknown
0x03E1C    30 00 3a a0    unknown
0x03E20    30 00 3a 20    unknown
0x03E24    30 00 3a a0    unknown
0x03E28    30 00 3a a8    unknown
! Erased flash: 0x03E2C-0x03FFF (468 bytes of FF); 117 words collapsed.


0x08000    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x08010    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x08020    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x08030    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x08040    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x08050    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x08060    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x08070    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x08080    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x08090    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x080A0    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x080B0    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x080C0    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x080D0    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x080E0    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x080F0    ff ff ff ff    ff ff ff ff ff ff ff ff ff ff ff ff  ................
0x08100    e0 46 9a 72    7d 0f 00 00 4e 45 54 47 45 41 52 00  .F.r}...NETGEAR.
0x08110    00 00 00 00    00 00 00 00 00 00 00 00 00 00 00 00  ................
0x08120    00 00 00 00    00 00 00 00 52 65 61 64 79 4e 41 53  ........ReadyNAS
0x08130    20 44 75 6f    00 00 00 00 00 00 00 00 00 00 00 00   Duo............
0x08140    00 00 00 00    00 00 00 00 32 34 4d 34 31 36 37 35  ........24M41675
0x08150    30 30 35 30    30 00 00 00 30 00 00 00 00 00 00 00  00500...0.......
0x08160    00 00 00 00    00 00 00 00 00 00 00 00 00 00 00 00  ................
0x08170    01 00 00 00    01 00 7f 02 07 34 01 63 01 00 00 00  .........4.c....
0x08180    01 1a 32 82    00 21 00 21 ec 00 00 00 00 00 00 00  ..2.. ! .!........
0x08190    00 00 00 00    00 00 00 00 00 00 00 00 00 00 00 00  ................
0x081A0    00 00 00 00    00 00 00 00 00 00 00 00 00 00 00 25  ...............%
0x081B0    45 93 0b 00    00 00 00 00 00 00 00 00 00 00 00 00  E...............
0x081C0    00 00 00 00    00 00 00 00 00 00 00 00 00 00 00 00  ................
0x081D0    00 6a ff ff    ff 00 00 00 00 00 00 00 00 00 00 00  .j..............
0x081E0    00 00 00 00    00 00 00 00 00 00 00 00 00 00 00 00  ................
0x081F0    00 00 00 00    00 00 00 00 00 00 00 00 49 25 30 65  ............I%0e

! Erased flash: 0x08200-0x08FFF (3584 bytes of FF); 896 words collapsed.

! 0xC000: Boot entry, trap-vector stubs and UART output
! Steps:
! 1. Branch over reserved trap vectors to the startup sequence.
! 2. Provide window overflow/underflow branches and UART transmit helper.

0x0C000    10 80 00 29    b  0xc0a4                              ! Skip trap-vector area; startup begins at 0xC0A4
0x0C004    01 00 00 00    nop
0x0C008    01 00 00 00    nop
0x0C00C    01 00 00 00    nop
0x0C010    01 00 00 00    nop
0x0C014    01 00 00 00    nop
0x0C018    01 00 00 00    nop
0x0C01C    01 00 00 00    nop
0x0C020    01 00 00 00    nop
0x0C024    01 00 00 00    nop
0x0C028    01 00 00 00    nop
0x0C02C    01 00 00 00    nop
0x0C030    01 00 00 00    nop
0x0C034    01 00 00 00    nop
0x0C038    01 00 00 00    nop
0x0C03C    01 00 00 00    nop
0x0C040    01 00 00 00    nop
0x0C044    01 00 00 00    nop
0x0C048    01 00 00 00    nop
0x0C04C    01 00 00 00    nop
0x0C050    10 80 0e 83    b  0xfa5c                              ! Window overflow trap branch
0x0C054    a1 50 00 00    rd  %wim, %l0                          ! Read window invalid mask in delay slot
0x0C058    01 00 00 00    nop
0x0C05C    01 00 00 00    nop
0x0C060    10 80 0e 91    b  0xfaa4                              ! Window underflow trap branch
0x0C064    a1 50 00 00    rd  %wim, %l0                          ! Read WIM in delay slot
0x0C068    01 00 00 00    nop
0x0C06C    01 00 00 00    nop
0x0C070    2f 08 00 00    sethi  %hi(0x20000000), %l7            ! UART MMIO base
0x0C074    c2 05 e0 64    ld  [ %l7 + 0x64 ], %g1                ! Read UART status at 0x20000064
0x0C078    80 88 60 04    btst  4, %g1                           ! Test transmit-ready bit 2
0x0C07C    02 bf ff fe    be  0xc074                             ! Wait until transmitter is ready
0x0C080    01 00 00 00    nop
0x0C084    2f 08 00 00    sethi  %hi(0x20000000), %l7
0x0C088    ec 25 e0 60    st  %l6, [ %l7 + 0x60 ]                ! Write character to UART data port
0x0C08C    ae 10 21 00    mov  0x100, %l7
0x0C090    ae a5 e0 01    deccc  %l7
0x0C094    12 bf ff ff    bne  0xc090
0x0C098    01 00 00 00    nop
0x0C09C    81 c3 e0 08    retl                                   ! Return from UART output helper
0x0C0A0    01 00 00 00    nop

! 0xC0A4: Early CPU and board initialization
! Steps:
! 1. Reset TBR and inspect boot-state field via ASI_AIUP.
! 2. Handle alternate warm-start jump or initialize MMIO, PSR, WIM and stack.
! 3. Install RAM trap base and call the next initialization stage.

0x0C0A4    81 98 00 00    wr  %g0, %tbr                          ! Clear trap base register
0x0C0A8    01 00 00 00    nop
0x0C0AC    01 00 00 00    nop
0x0C0B0    01 00 00 00    nop
0x0C0B4    86 10 20 08    mov  8, %g3                            ! 0x8
0x0C0B8    82 10 20 04    mov  4, %g1
0x0C0BC    c4 80 42 00    lda  [ %g1 ] #ASI_AIUP, %g2            ! Read processor/boot-state field through alternate address space
0x0C0C0    85 30 a0 14    srl  %g2, 0x14, %g2
0x0C0C4    84 08 a0 0f    and  %g2, 0xf, %g2                     ! Keep four-bit boot-state selector
0x0C0C8    80 a0 a0 00    cmp  %g2, 0
0x0C0CC    02 80 00 10    be  0xc10c                             ! State zero: cold-start path
0x0C0D0    88 80 28 00    addcc  %g0, 0x800, %g4
0x0C0D4    12 80 00 00    bne  0xc0d4                            ! Spin on unexpected state (delay slot decrements counter)
0x0C0D8    88 a1 20 01    deccc  %g4
0x0C0DC    80 a0 a0 01    cmp  %g2, 1
0x0C0E0    02 80 00 04    be  0xc0f0
0x0C0E4    80 a0 a0 02    cmp  %g2, 2
0x0C0E8    02 80 00 04    be  0xc0f8
0x0C0EC    01 00 00 00    nop
0x0C0F0    10 80 00 00    b  0xc0f0                              ! State one: intentional infinite loop
0x0C0F4    01 00 00 00    nop
0x0C0F8    03 0c 00 1f    sethi  %hi(0x30007c00), %g1
0x0C0FC    82 10 63 fc    or  %g1, 0x3fc, %g1                    ! 0x30007ffc
0x0C100    c4 00 40 00    ld  [ %g1 ], %g2                       ! Read warm-start target from 0x30007FFC
0x0C104    81 c0 80 00    jmp  %g2                               ! Jump to stored warm-start address
0x0C108    c0 20 40 00    clr  [ %g1 ]                           ! Clear stored target in jump delay slot
0x0C10C    05 08 00 00    sethi  %hi(0x20000000), %g2
0x0C110    84 10 a0 94    or  %g2, 0x94, %g2                     ! 0x20000094
0x0C114    03 00 00 18    sethi  %hi(0x6000), %g1
0x0C118    c2 20 80 00    st  %g1, [ %g2 ]                       ! Configure MMIO register 0x20000094
0x0C11C    82 10 20 0c    mov  0xc, %g1
0x0C120    05 08 00 00    sethi  %hi(0x20000000), %g2
0x0C124    84 10 a0 d0    or  %g2, 0xd0, %g2                     ! 0x200000d0
0x0C128    c2 20 a0 04    st  %g1, [ %g2 + 4 ]
0x0C12C    c2 00 a0 10    ld  [ %g2 + 0x10 ], %g1                ! Poll controller busy bit 0
0x0C130    80 88 60 01    btst  1, %g1
0x0C134    12 bf ff fe    bne  0xc12c
0x0C138    03 02 80 60    sethi  %hi(0xa018000), %g1
0x0C13C    c2 20 a0 08    st  %g1, [ %g2 + 8 ]
0x0C140    03 00 00 0a    sethi  %hi(0x2800), %g1
0x0C144    82 10 62 d2    or  %g1, 0x2d2, %g1                    ! 0x2ad2
0x0C148    c2 20 a0 00    st  %g1, [ %g2 ]                       ! Issue controller command 0x2AD2
0x0C14C    c2 00 a0 10    ld  [ %g2 + 0x10 ], %g1
0x0C150    80 88 60 01    btst  1, %g1
0x0C154    12 bf ff fe    bne  0xc14c
0x0C158    03 00 40 61    sethi  %hi(0x1018400), %g1
0x0C15C    82 10 62 00    or  %g1, 0x200, %g1                    ! 0x1018600
0x0C160    c2 20 a0 08    st  %g1, [ %g2 + 8 ]
0x0C164    03 00 00 0a    sethi  %hi(0x2800), %g1
0x0C168    82 10 62 d2    or  %g1, 0x2d2, %g1                    ! 0x2ad2
0x0C16C    c2 20 a0 00    st  %g1, [ %g2 ]
0x0C170    c2 00 a0 10    ld  [ %g2 + 0x10 ], %g1
0x0C174    80 88 60 01    btst  1, %g1
0x0C178    12 bf ff fe    bne  0xc170
0x0C17C    03 04 40 47    sethi  %hi(0x11011c00), %g1
0x0C180    c2 20 a0 08    st  %g1, [ %g2 + 8 ]
0x0C184    03 00 00 0a    sethi  %hi(0x2800), %g1
0x0C188    82 10 62 d2    or  %g1, 0x2d2, %g1                    ! 0x2ad2
0x0C18C    c2 20 a0 00    st  %g1, [ %g2 ]
0x0C190    84 10 21 c0    mov  0x1c0, %g2
0x0C194    81 88 a0 00    wr  %g2, %psr                          ! Initialize PSR
0x0C198    01 00 00 00    nop
0x0C19C    01 00 00 00    nop
0x0C1A0    01 00 00 00    nop
0x0C1A4    82 10 20 02    mov  2, %g1                            ! 0x2
0x0C1A8    81 90 60 00    wr  %g1, %wim                          ! Set WIM to 2
0x0C1AC    01 00 00 00    nop
0x0C1B0    01 00 00 00    nop
0x0C1B4    01 00 00 00    nop
0x0C1B8    31 04 8d 15    sethi  %hi(0x12345400), %i0
0x0C1BC    b0 16 22 78    or  %i0, 0x278, %i0                    ! Test pattern 0x12345678
0x0C1C0    11 21 d9 50    sethi  %hi(0x87654000), %o0
0x0C1C4    90 12 23 21    or  %o0, 0x321, %o0                    ! Test pattern 0x87654321
0x0C1C8    07 00 00 c0    sethi  %hi(0x30000), %g3
0x0C1CC    c0 a0 c2 80    sta  %g0, [ %g3 ] #ASI_PHYS_USE_EC     ! Alternate-space store to physical location
0x0C1D0    0f 08 00 00    sethi  %hi(0x20000000), %g7
0x0C1D4    82 10 2f ff    mov  0xfff, %g1
0x0C1D8    c2 21 e0 88    st  %g1, [ %g7 + 0x88 ]
0x0C1DC    c0 21 e0 8c    clr  [ %g7 + 0x8c ]
0x0C1E0    03 01 b6 c1    sethi  %hi(0x6db0400), %g1
0x0C1E4    82 10 60 01    or  %g1, 1, %g1                        ! 0x6db0401
0x0C1E8    c2 21 e0 80    st  %g1, [ %g7 + 0x80 ]                ! Program hardware control register
0x0C1EC    c2 01 e0 80    ld  [ %g7 + 0x80 ], %g1
0x0C1F0    80 88 62 00    btst  0x200, %g1
0x0C1F4    02 bf ff fe    be  0xc1ec                             ! Wait for hardware status bit 9
0x0C1F8    01 00 00 00    nop
0x0C1FC    c0 21 e0 80    clr  [ %g7 + 0x80 ]
0x0C200    07 00 00 c0    sethi  %hi(0x30000), %g3
0x0C204    84 10 20 01    mov  1, %g2
0x0C208    c4 a0 c2 80    sta  %g2, [ %g3 ] #ASI_PHYS_USE_EC     ! Write 1 using ASI_PHYS_USE_EC
0x0C20C    86 10 20 1c    mov  0x1c, %g3
0x0C210    05 1e 00 00    sethi  %hi(0x78000000), %g2
0x0C214    c4 a0 c2 00    sta  %g2, [ %g3 ] #ASI_AIUP            ! Configure ASI_AIUP control
0x0C218    03 08 00 00    sethi  %hi(0x20000000), %g1
0x0C21C    82 10 60 1c    or  %g1, 0x1c, %g1                     ! 0x2000001c
0x0C220    88 10 3f ff    mov  -1, %g4
0x0C224    c8 20 40 00    st  %g4, [ %g1 ]
0x0C228    03 08 00 00    sethi  %hi(0x20000000), %g1
0x0C22C    82 10 60 18    or  %g1, 0x18, %g1                     ! 0x20000018
0x0C230    c8 20 40 00    st  %g4, [ %g1 ]
0x0C234    03 08 00 00    sethi  %hi(0x20000000), %g1
0x0C238    82 10 60 04    or  %g1, 4, %g1                        ! 0x20000004
0x0C23C    09 20 00 00    sethi  %hi(0x80000000), %g4
0x0C240    c0 20 40 00    clr  [ %g1 ]
0x0C244    03 08 00 00    sethi  %hi(0x20000000), %g1
0x0C248    88 10 24 00    mov  0x400, %g4
0x0C24C    c0 20 40 00    clr  [ %g1 ]
0x0C250    21 08 00 00    sethi  %hi(0x20000000), %l0
0x0C254    a0 14 20 c4    or  %l0, 0xc4, %l0                     ! 0x200000c4
0x0C258    23 00 00 2f    sethi  %hi(0xbc00), %l1
0x0C25C    a2 14 63 00    or  %l1, 0x300, %l1                    ! 0xbf00
0x0C260    e2 24 00 00    st  %l1, [ %l0 ]
0x0C264    21 08 00 00    sethi  %hi(0x20000000), %l0
0x0C268    a0 14 20 c0    or  %l0, 0xc0, %l0                     ! 0x200000c0
0x0C26C    23 00 03 00    sethi  %hi(0xc0000), %l1
0x0C270    e2 24 00 00    st  %l1, [ %l0 ]
0x0C274    23 00 00 40    sethi  %hi(0x10000), %l1
0x0C278    a2 a4 60 01    deccc  %l1
0x0C27C    12 80 00 00    bne  0xc27c
0x0C280    a2 a4 60 01    deccc  %l1
0x0C284    23 00 03 20    sethi  %hi(0xc8000), %l1
0x0C288    e2 24 00 00    st  %l1, [ %l0 ]
0x0C28C    23 00 00 40    sethi  %hi(0x10000), %l1
0x0C290    a2 a4 60 01    deccc  %l1
0x0C294    12 80 00 00    bne  0xc294
0x0C298    a2 a4 60 01    deccc  %l1
0x0C29C    a2 10 20 40    mov  0x40, %l1
0x0C2A0    21 08 00 00    sethi  %hi(0x20000000), %l0
0x0C2A4    a0 14 20 6c    or  %l0, 0x6c, %l0                     ! 0x2000006c
0x0C2A8    e2 24 00 00    st  %l1, [ %l0 ]
0x0C2AC    21 08 00 00    sethi  %hi(0x20000000), %l0
0x0C2B0    a0 14 20 68    or  %l0, 0x68, %l0                     ! 0x20000068
0x0C2B4    a2 10 23 03    mov  0x303, %l1
0x0C2B8    e2 24 00 00    st  %l1, [ %l0 ]
0x0C2BC    21 08 00 00    sethi  %hi(0x20000000), %l0
0x0C2C0    a0 14 20 64    or  %l0, 0x64, %l0                     ! 0x20000064
0x0C2C4    a2 10 20 0f    mov  0xf, %l1
0x0C2C8    e2 24 00 00    st  %l1, [ %l0 ]                       ! Configure UART status/control register
0x0C2CC    03 0c 00 00    sethi  %hi(0x30000000), %g1
0x0C2D0    05 00 00 1f    sethi  %hi(0x7c00), %g2
0x0C2D4    84 10 a3 80    or  %g2, 0x380, %g2                    ! 0x7f80
0x0C2D8    9c 00 40 02    add  %g1, %g2, %sp                     ! Stack pointer = 0x30007F80
0x0C2DC    bc 10 00 0e    mov  %sp, %fp
0x0C2E0    07 21 e0 c0    sethi  %hi(0x87830000), %g3
0x0C2E4    86 10 e0 00    mov  %g3, %g3                          ! 0x87830000
0x0C2E8    81 98 e0 00    wr  %g3, %tbr                          ! Set trap base to 0x87830000
0x0C2EC    01 00 00 00    nop
0x0C2F0    01 00 00 00    nop
0x0C2F4    01 00 00 00    nop
0x0C2F8    87 48 00 00    rd  %psr, %g3
0x0C2FC    81 88 e0 00    wr  %g3, %psr
0x0C300    01 00 00 00    nop
0x0C304    01 00 00 00    nop
0x0C308    01 00 00 00    nop
0x0C30C    81 88 e0 20    wr  %g3, 0x20, %psr
0x0C310    01 00 00 00    nop
0x0C314    01 00 00 00    nop
0x0C318    01 00 00 00    nop
0x0C31C    40 00 0f 17    call  0xff78                           ! Call later startup stage at 0xFF78
0x0C320    01 00 00 00    nop

! 0xC324: Secondary hardware setup
! Steps:
! 1. Initialize 0x20003000/04 and select external entry at 0x400003F0/F8.
! 2. Store six returned registers in MMIO and enable two channels.

0x0C324    9d e3 bf 98    save  %sp, -104, %sp                   ! Entry: initialize hardware interface
0x0C328    07 08 00 0c    sethi  %hi(0x20003000), %g3
0x0C32C    84 10 20 01    mov  1, %g2
0x0C330    c4 20 c0 00    st  %g2, [ %g3 ]
0x0C334    b2 10 20 02    mov  2, %i1
0x0C338    f2 20 c0 00    st  %i1, [ %g3 ]
0x0C33C    86 10 e0 04    or  %g3, 4, %g3
0x0C340    84 10 20 0a    mov  0xa, %g2
0x0C344    33 21 e0 dc    sethi  %hi(0x87837000), %i1
0x0C348    c4 20 c0 00    st  %g2, [ %g3 ]
0x0C34C    80 8e 20 ff    btst  0xff, %i0
0x0C350    02 80 00 05    be  0xc364
0x0C354    f0 2e 63 30    stb  %i0, [ %i1 + 0x330 ]              ! Save mode byte to 0x87837330 in branch delay slot
0x0C358    05 10 00 00    sethi  %hi(0x40000000), %g2
0x0C35C    10 80 00 04    b  0xc36c
0x0C360    86 10 a3 f8    or  %g2, 0x3f8, %g3                    ! External entry 0x400003F8
0x0C364    05 10 00 00    sethi  %hi(0x40000000), %g2
0x0C368    86 10 a3 f0    or  %g2, 0x3f0, %g3                    ! External entry 0x400003F0
0x0C36C    05 08 00 0c    sethi  %hi(0x20003000), %g2
0x0C370    84 10 a0 08    or  %g2, 8, %g2                        ! 0x20003008
0x0C374    9f c0 c0 00    call  %g3                              ! Indirect call to selected external routine
0x0C378    01 00 00 00    nop
0x0C37C    d0 20 a0 00    st  %o0, [ %g2 ]                       ! Store returned word 0
0x0C380    d2 20 a0 04    st  %o1, [ %g2 + 4 ]
0x0C384    d4 20 a0 08    st  %o2, [ %g2 + 8 ]
0x0C388    d6 20 a0 0c    st  %o3, [ %g2 + 0xc ]
0x0C38C    d8 20 a0 10    st  %o4, [ %g2 + 0x10 ]
0x0C390    da 20 a0 14    st  %o5, [ %g2 + 0x14 ]                ! Store returned word 5
0x0C394    31 08 00 0a    sethi  %hi(0x20002800), %i0
0x0C398    84 16 20 c4    or  %i0, 0xc4, %g2                     ! 0x200028c4
0x0C39C    c0 20 80 00    clr  [ %g2 ]
0x0C3A0    b2 16 20 d4    or  %i0, 0xd4, %i1
0x0C3A4    07 00 00 20    sethi  %hi(0x8000), %g3
0x0C3A8    c0 26 40 00    clr  [ %i1 ]
0x0C3AC    86 10 e0 0a    or  %g3, 0xa, %g3
0x0C3B0    84 16 20 c0    or  %i0, 0xc0, %g2
0x0C3B4    c6 20 80 00    st  %g3, [ %g2 ]                       ! Enable channel with value 0x800A
0x0C3B8    b0 16 20 d0    or  %i0, 0xd0, %i0
0x0C3BC    c6 26 00 00    st  %g3, [ %i0 ]
0x0C3C0    81 c7 e0 08    ret
0x0C3C4    81 e8 00 00    restore

! 0xC3C8: Hardware transfer and optional XOR transform
! Steps:
! 1. Program DMA-like controller addresses and length, then wait for busy to clear.
! 2. If mode byte is set, XOR the buffer with a position-dependent constant.

0x0C3C8    9d e3 bf 98    save  %sp, -104, %sp                   ! Entry: hardware transfer helper
0x0C3CC    15 08 00 0a    sethi  %hi(0x20002800), %o2
0x0C3D0    17 30 00 00    sethi  %hi(0xc0000000), %o3
0x0C3D4    b0 06 00 0b    add  %i0, %o3, %i0
0x0C3D8    90 12 a0 d8    or  %o2, 0xd8, %o0
0x0C3DC    f0 22 00 00    st  %i0, [ %o0 ]                       ! Program first address with 0xC0000000 bias
0x0C3E0    90 12 a0 c8    or  %o2, 0xc8, %o0
0x0C3E4    96 06 40 0b    add  %i1, %o3, %o3
0x0C3E8    d6 22 00 00    st  %o3, [ %o0 ]                       ! Program second address with same bias
0x0C3EC    13 00 80 00    sethi  %hi(0x2000000), %o1
0x0C3F0    98 12 a0 c0    or  %o2, 0xc0, %o4
0x0C3F4    92 16 80 09    or  %i2, %o1, %o1
0x0C3F8    96 12 a0 dc    or  %o2, 0xdc, %o3
0x0C3FC    11 00 c0 00    sethi  %hi(0x3000000), %o0
0x0C400    d2 22 c0 00    st  %o1, [ %o3 ]                       ! Write transfer flags/length
0x0C404    94 12 a0 cc    or  %o2, 0xcc, %o2
0x0C408    90 16 80 08    or  %i2, %o0, %o0
0x0C40C    d0 22 80 00    st  %o0, [ %o2 ]
0x0C410    d2 03 00 00    ld  [ %o4 ], %o1                       ! Read channel status
0x0C414    15 00 00 10    sethi  %hi(0x4000), %o2
0x0C418    80 8a 40 0a    btst  %o1, %o2
0x0C41C    02 80 00 12    be  0xc464                             ! Skip wait if bit 14 is clear
0x0C420    b0 10 20 00    clr  %i0
0x0C424    11 00 18 f5    sethi  %hi(0x63d400), %o0
0x0C428    a4 12 23 6a    or  %o0, 0x36a, %l2                    ! 0x63d76a
0x0C42C    a2 10 00 0c    mov  %o4, %l1
0x0C430    a0 10 00 0a    mov  %o2, %l0
0x0C434    6a 1f 3f f3    call  0xa87dc400                       ! Unusual call target; may require relocation or separate mapping
0x0C438    90 10 20 01    mov  1, %o0
0x0C43C    b0 06 20 01    inc  %i0
0x0C440    80 a6 00 12    cmp  %i0, %l2
0x0C444    08 80 00 04    bleu  0xc454                           ! Bounded polling timeout
0x0C448    01 00 00 00    nop
0x0C44C    10 80 00 18    b  0xc4ac
0x0C450    b0 10 3f ff    mov  -1, %i0                           ! Return -1 on timeout
0x0C454    d0 04 40 00    ld  [ %l1 ], %o0
0x0C458    80 8a 00 10    btst  %o0, %l0
0x0C45C    12 bf ff f6    bne  0xc434
0x0C460    01 00 00 00    nop
0x0C464    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0C468    d2 0a 23 30    ldub  [ %o0 + 0x330 ], %o1             ! 0x87837330
0x0C46C    80 a2 60 00    cmp  %o1, 0                            ! Check optional transform flag
0x0C470    02 80 00 0e    be  0xc4a8
0x0C474    b0 10 20 00    clr  %i0
0x0C478    80 a6 00 1a    cmp  %i0, %i2
0x0C47C    1a 80 00 0c    bcc  0xc4ac
0x0C480    11 30 7f 35    sethi  %hi(0xc1fcd400), %o0
0x0C484    94 12 20 08    or  %o0, 8, %o2                        ! 0xc1fcd408
0x0C488    d0 06 40 18    ld  [ %i1 + %i0 ], %o0                 ! Load buffer word
0x0C48C    92 06 00 0a    add  %i0, %o2, %o1
0x0C490    90 1a 00 09    xor  %o0, %o1, %o0                     ! XOR with 0xC1FCD408 + offset
0x0C494    d0 26 40 18    st  %o0, [ %i1 + %i0 ]                 ! Store transformed word
0x0C498    b0 06 20 04    add  %i0, 4, %i0
0x0C49C    80 a6 00 1a    cmp  %i0, %i2
0x0C4A0    2a bf ff fb    bcs,a   0xc48c
0x0C4A4    d0 06 40 18    ld  [ %i1 + %i0 ], %o0
0x0C4A8    b0 10 20 00    clr  %i0
0x0C4AC    81 c7 e0 08    ret
0x0C4B0    81 e8 00 00    restore

! 0xC4B4: Controller read/command transaction
! Steps:
! 1. Write packed device index and register to 0x2001041C.
! 2. Issue controller commands and poll completion bit 2.
! 3. Return 16-bit result or -1 on retry exhaustion.

0x0C4B4    9d e3 bf 98    save  %sp, -104, %sp                   ! Entry: controller read
0x0C4B8    13 08 00 41    sethi  %hi(0x20010400), %o1
0x0C4BC    b1 2e 20 08    sll  %i0, 8, %i0
0x0C4C0    94 12 60 1c    or  %o1, 0x1c, %o2
0x0C4C4    b0 16 00 19    or  %i0, %i1, %i0
0x0C4C8    11 00 0a 00    sethi  %hi(0x280000), %o0
0x0C4CC    f0 22 80 00    st  %i0, [ %o2 ]                       ! Write packed request to data/config port
0x0C4D0    92 12 60 18    or  %o1, 0x18, %o1
0x0C4D4    90 12 20 01    or  %o0, 1, %o0
0x0C4D8    94 10 00 09    mov  %o1, %o2
0x0C4DC    d0 22 40 00    st  %o0, [ %o1 ]                       ! Issue 0x00280001 command
0x0C4E0    d0 02 80 00    ld  [ %o2 ], %o0
0x0C4E4    80 8a 20 04    btst  4, %o0                           ! Poll command-complete bit 2
0x0C4E8    02 bf ff fe    be  0xc4e0
0x0C4EC    13 08 00 41    sethi  %hi(0x20010400), %o1
0x0C4F0    96 12 60 1c    or  %o1, 0x1c, %o3                     ! 0x2001041c
0x0C4F4    94 10 20 01    mov  1, %o2
0x0C4F8    11 00 09 00    sethi  %hi(0x240000), %o0
0x0C4FC    d4 22 c0 00    st  %o2, [ %o3 ]
0x0C500    92 12 60 18    or  %o1, 0x18, %o1
0x0C504    90 12 20 01    or  %o0, 1, %o0
0x0C508    94 10 00 09    mov  %o1, %o2
0x0C50C    d0 22 40 00    st  %o0, [ %o1 ]                       ! Issue 0x00240001 command
0x0C510    d0 02 80 00    ld  [ %o2 ], %o0
0x0C514    80 8a 20 04    btst  4, %o0
0x0C518    02 bf ff fe    be  0xc510
0x0C51C    01 00 00 00    nop
0x0C520    6a 1f 3f b8    call  0xa87dc400
0x0C524    90 10 20 05    mov  5, %o0                            ! 0x5
0x0C528    11 08 00 41    sethi  %hi(0x20010400), %o0
0x0C52C    94 12 20 1c    or  %o0, 0x1c, %o2                     ! 0x2001041c
0x0C530    13 00 09 00    sethi  %hi(0x240000), %o1
0x0C534    90 12 20 18    or  %o0, 0x18, %o0
0x0C538    c0 22 80 00    clr  [ %o2 ]
0x0C53C    92 12 60 01    or  %o1, 1, %o1
0x0C540    94 10 00 08    mov  %o0, %o2
0x0C544    d2 22 00 00    st  %o1, [ %o0 ]
0x0C548    d0 02 80 00    ld  [ %o2 ], %o0
0x0C54C    80 8a 20 04    btst  4, %o0
0x0C550    02 bf ff fe    be  0xc548
0x0C554    11 00 0d 00    sethi  %hi(0x340000), %o0
0x0C558    a6 12 20 03    or  %o0, 3, %l3                        ! 0x340003
0x0C55C    15 08 00 41    sethi  %hi(0x20010400), %o2
0x0C560    13 00 0c 00    sethi  %hi(0x300000), %o1
0x0C564    11 00 00 3f    sethi  %hi(0xfc00), %o0
0x0C568    aa 10 00 0a    mov  %o2, %l5
0x0C56C    a4 12 60 03    or  %o1, 3, %l2
0x0C570    a8 12 23 ff    or  %o0, 0x3ff, %l4
0x0C574    b2 12 a0 18    or  %o2, 0x18, %i1
0x0C578    a2 12 a0 1c    or  %o2, 0x1c, %l1
0x0C57C    a0 10 23 e8    mov  0x3e8, %l0
0x0C580    6a 1f 3f a0    call  0xa87dc400                       ! Delay before polling response
0x0C584    90 10 20 05    mov  5, %o0
0x0C588    e6 26 40 00    st  %l3, [ %i1 ]                       ! Issue 0x00340003 command
0x0C58C    d0 06 40 00    ld  [ %i1 ], %o0
0x0C590    80 8a 20 04    btst  4, %o0
0x0C594    02 bf ff fe    be  0xc58c
0x0C598    01 00 00 00    nop
0x0C59C    f0 04 40 00    ld  [ %l1 ], %i0
0x0C5A0    80 8e 20 01    btst  1, %i0                           ! Check data bit 0 for retry condition
0x0C5A4    32 80 00 0b    bne,a   0xc5d0
0x0C5A8    a0 04 3f ff    add  %l0, -1, %l0
0x0C5AC    e4 26 40 00    st  %l2, [ %i1 ]                       ! Issue 0x00300003 command
0x0C5B0    94 15 60 18    or  %l5, 0x18, %o2
0x0C5B4    d0 02 80 00    ld  [ %o2 ], %o0
0x0C5B8    80 8a 20 04    btst  4, %o0
0x0C5BC    02 bf ff fe    be  0xc5b4
0x0C5C0    01 00 00 00    nop
0x0C5C4    f0 04 40 00    ld  [ %l1 ], %i0
0x0C5C8    10 80 00 05    b  0xc5dc
0x0C5CC    b0 0e 00 14    and  %i0, %l4, %i0
0x0C5D0    80 a4 20 00    cmp  %l0, 0
0x0C5D4    14 bf ff eb    bg  0xc580
0x0C5D8    b0 10 3f ff    mov  -1, %i0                           ! Return -1 on exhausted retries
0x0C5DC    81 c7 e0 08    ret
0x0C5E0    81 e8 00 00    restore

! 0xC5E4: Controller write transaction
! Steps:
! 1. Optionally run setup when the saved mode is 0x28.
! 2. Send packed command and value, retry on busy, restore setup if needed.

0x0C5E4    9d e3 bf 98    save  %sp, -104, %sp                   ! Entry: controller write
0x0C5E8    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0C5EC    d2 12 20 00    lduh  [ %o0 ], %o1                     ! Read saved device/mode value
0x0C5F0    a0 10 00 18    mov  %i0, %l0
0x0C5F4    aa 10 00 08    mov  %o0, %l5
0x0C5F8    80 a2 60 28    cmp  %o1, 0x28
0x0C5FC    12 80 00 0c    bne  0xc62c                            ! Compare with mode 0x28
0x0C600    b0 10 3f ff    mov  -1, %i0
0x0C604    40 00 01 d2    call  0xcd4c                           ! Read device byte via helper
0x0C608    90 10 20 0c    mov  0xc, %o0
0x0C60C    a8 10 00 08    mov  %o0, %l4
0x0C610    13 00 00 0b    sethi  %hi(0x2c00), %o1
0x0C614    92 12 61 01    or  %o1, 0x101, %o1                    ! 0x2d01
0x0C618    40 00 01 dd    call  0xcd8c                           ! Write device byte via helper
0x0C61C    90 10 20 0c    mov  0xc, %o0
0x0C620    11 00 00 1d    sethi  %hi(0x7400), %o0
0x0C624    6a 1f 3f 77    call  0xa87dc400
0x0C628    90 12 21 30    or  %o0, 0x130, %o0                    ! 0x7530
0x0C62C    15 08 00 41    sethi  %hi(0x20010400), %o2
0x0C630    91 2c 20 08    sll  %l0, 8, %o0
0x0C634    96 12 a0 1c    or  %o2, 0x1c, %o3
0x0C638    90 12 00 19    or  %o0, %i1, %o0
0x0C63C    13 00 0a 00    sethi  %hi(0x280000), %o1
0x0C640    d0 22 c0 00    st  %o0, [ %o3 ]                       ! Write packed request
0x0C644    94 12 a0 18    or  %o2, 0x18, %o2
0x0C648    92 12 60 01    or  %o1, 1, %o1
0x0C64C    96 10 00 0a    mov  %o2, %o3
0x0C650    d2 22 80 00    st  %o1, [ %o2 ]                       ! Issue 0x00280001 command
0x0C654    d0 02 c0 00    ld  [ %o3 ], %o0
0x0C658    80 8a 20 04    btst  4, %o0
0x0C65C    02 bf ff fe    be  0xc654
0x0C660    11 08 00 41    sethi  %hi(0x20010400), %o0
0x0C664    13 00 0d 00    sethi  %hi(0x340000), %o1
0x0C668    15 00 0b 00    sethi  %hi(0x2c0000), %o2
0x0C66C    a2 10 00 08    mov  %o0, %l1
0x0C670    a4 12 60 03    or  %o1, 3, %l2
0x0C674    a6 12 a0 01    or  %o2, 1, %l3
0x0C678    b2 12 20 18    or  %o0, 0x18, %i1
0x0C67C    a0 10 23 e8    mov  0x3e8, %l0
0x0C680    6a 1f 3f 60    call  0xa87dc400
0x0C684    90 10 20 05    mov  5, %o0
0x0C688    e4 26 40 00    st  %l2, [ %i1 ]                       ! Issue 0x00340003 command
0x0C68C    d0 06 40 00    ld  [ %i1 ], %o0
0x0C690    80 8a 20 04    btst  4, %o0
0x0C694    02 bf ff fe    be  0xc68c
0x0C698    92 14 60 1c    or  %l1, 0x1c, %o1
0x0C69C    d0 02 40 00    ld  [ %o1 ], %o0
0x0C6A0    80 8a 20 01    btst  1, %o0
0x0C6A4    32 80 00 0b    bne,a   0xc6d0
0x0C6A8    a0 04 3f ff    add  %l0, -1, %l0
0x0C6AC    f4 22 40 00    st  %i2, [ %o1 ]                       ! Write payload to controller data port
0x0C6B0    e6 26 40 00    st  %l3, [ %i1 ]                       ! Issue 0x002C0001 command
0x0C6B4    92 14 60 18    or  %l1, 0x18, %o1
0x0C6B8    d0 02 40 00    ld  [ %o1 ], %o0
0x0C6BC    80 8a 20 04    btst  4, %o0
0x0C6C0    02 bf ff fe    be  0xc6b8
0x0C6C4    01 00 00 00    nop
0x0C6C8    10 80 00 05    b  0xc6dc
0x0C6CC    b0 10 20 00    clr  %i0                               ! 0x0
0x0C6D0    80 a4 20 00    cmp  %l0, 0
0x0C6D4    14 bf ff eb    bg  0xc680
0x0C6D8    01 00 00 00    nop
0x0C6DC    d0 15 60 00    lduh  [ %l5 ], %o0                     ! Read saved device/mode again
0x0C6E0    80 a2 20 28    cmp  %o0, 0x28
0x0C6E4    12 80 00 07    bne  0xc700
0x0C6E8    92 0d 20 ff    and  %l4, 0xff, %o1
0x0C6EC    40 00 01 a8    call  0xcd8c
0x0C6F0    90 10 20 0c    mov  0xc, %o0
0x0C6F4    11 00 00 1d    sethi  %hi(0x7400), %o0
0x0C6F8    6a 1f 3f 42    call  0xa87dc400
0x0C6FC    90 12 21 30    or  %o0, 0x130, %o0                    ! 0x7530
0x0C700    81 c7 e0 08    ret                                    ! Return status
0x0C704    81 e8 00 00    restore

! 0xC708: Controller initialization and device scan
! Steps:
! 1. Configure several MMIO blocks and issue controller commands.
! 2. Scan up to 32 devices for IDs 0x0141 or 0x000F.
! 3. Program selected device and finish interface configuration.

0x0C708    9d e3 bf 98    save  %sp, -104, %sp                   ! Entry: large hardware setup
0x0C70C    11 08 00 14    sethi  %hi(0x20005000), %o0
0x0C710    90 12 20 40    or  %o0, 0x40, %o0                     ! 0x20005040
0x0C714    21 08 00 41    sethi  %hi(0x20010400), %l0
0x0C718    c0 22 00 00    clr  [ %o0 ]                           ! Clear 0x20005040
0x0C71C    17 08 00 0a    sethi  %hi(0x20002800), %o3
0x0C720    92 14 20 28    or  %l0, 0x28, %o1
0x0C724    90 10 23 77    mov  0x377, %o0
0x0C728    d0 22 40 00    st  %o0, [ %o1 ]                       ! Write configuration to 0x20010428
0x0C72C    94 12 e0 04    or  %o3, 4, %o2
0x0C730    98 10 24 00    mov  0x400, %o4
0x0C734    d8 22 80 00    st  %o4, [ %o2 ]
0x0C738    92 12 e0 14    or  %o3, 0x14, %o1
0x0C73C    11 00 00 20    sethi  %hi(0x8000), %o0
0x0C740    d8 22 40 00    st  %o4, [ %o1 ]
0x0C744    90 12 20 0b    or  %o0, 0xb, %o0
0x0C748    d0 22 c0 00    st  %o0, [ %o3 ]                       ! Initialize channel A
0x0C74C    94 12 e0 10    or  %o3, 0x10, %o2
0x0C750    d0 22 80 00    st  %o0, [ %o2 ]                       ! Initialize channel B
0x0C754    d2 04 00 00    ld  [ %l0 ], %o1                       ! Read controller control register
0x0C758    90 10 20 0a    mov  0xa, %o0
0x0C75C    92 12 64 00    or  %o1, 0x400, %o1
0x0C760    d2 24 00 00    st  %o1, [ %l0 ]                       ! Set bit 10
0x0C764    6a 1f 3f 27    call  0xa87dc400
0x0C768    01 00 00 00    nop
0x0C76C    d0 04 00 00    ld  [ %l0 ], %o0
0x0C770    19 20 00 00    sethi  %hi(0x80000000), %o4
0x0C774    90 0a 3b ff    and  %o0, -1025, %o0
0x0C778    d0 24 00 00    st  %o0, [ %l0 ]                       ! Clear bit 10
0x0C77C    d2 04 00 00    ld  [ %l0 ], %o1
0x0C780    94 10 00 0c    mov  %o4, %o2
0x0C784    92 12 40 0c    or  %o1, %o4, %o1
0x0C788    d2 24 00 00    st  %o1, [ %l0 ]                       ! Set high control bit
0x0C78C    d0 04 00 00    ld  [ %l0 ], %o0
0x0C790    17 00 00 10    sethi  %hi(0x4000), %o3
0x0C794    94 2a 00 0a    andn  %o0, %o2, %o2
0x0C798    d4 24 00 00    st  %o2, [ %l0 ]                       ! Clear high control bit
0x0C79C    d0 04 00 00    ld  [ %l0 ], %o0
0x0C7A0    92 14 20 1c    or  %l0, 0x1c, %o1
0x0C7A4    90 12 00 0b    or  %o0, %o3, %o0
0x0C7A8    d0 24 00 00    st  %o0, [ %l0 ]                       ! Set bit 14
0x0C7AC    d8 22 40 00    st  %o4, [ %o1 ]
0x0C7B0    a0 14 20 18    or  %l0, 0x18, %l0
0x0C7B4    90 10 20 01    mov  1, %o0
0x0C7B8    92 10 00 10    mov  %l0, %o1
0x0C7BC    d0 24 00 00    st  %o0, [ %l0 ]                       ! Issue controller command
0x0C7C0    d0 02 40 00    ld  [ %o1 ], %o0
0x0C7C4    80 8a 20 04    btst  4, %o0
0x0C7C8    02 bf ff fe    be  0xc7c0                             ! Poll completion bit 2
0x0C7CC    01 00 00 00    nop
0x0C7D0    6a 1f 3f 0c    call  0xa87dc400
0x0C7D4    90 10 20 01    mov  1, %o0                            ! 0x1
0x0C7D8    11 08 00 41    sethi  %hi(0x20010400), %o0
0x0C7DC    90 12 20 18    or  %o0, 0x18, %o0                     ! 0x20010418
0x0C7E0    92 10 20 03    mov  3, %o1
0x0C7E4    94 10 00 08    mov  %o0, %o2
0x0C7E8    d2 22 00 00    st  %o1, [ %o0 ]
0x0C7EC    d0 02 80 00    ld  [ %o2 ], %o0
0x0C7F0    80 8a 20 04    btst  4, %o0
0x0C7F4    02 bf ff fe    be  0xc7ec
0x0C7F8    13 08 00 41    sethi  %hi(0x20010400), %o1
0x0C7FC    96 12 60 1c    or  %o1, 0x1c, %o3                     ! 0x2001041c
0x0C800    d4 02 c0 00    ld  [ %o3 ], %o2
0x0C804    11 20 00 00    sethi  %hi(0x80000000), %o0
0x0C808    90 2a 80 08    andn  %o2, %o0, %o0                    ! Clear bit 31 in controller data
0x0C80C    d0 22 c0 00    st  %o0, [ %o3 ]
0x0C810    92 12 60 18    or  %o1, 0x18, %o1
0x0C814    90 10 20 01    mov  1, %o0
0x0C818    94 10 00 09    mov  %o1, %o2
0x0C81C    d0 22 40 00    st  %o0, [ %o1 ]
0x0C820    d0 02 80 00    ld  [ %o2 ], %o0
0x0C824    80 8a 20 04    btst  4, %o0
0x0C828    02 bf ff fe    be  0xc820
0x0C82C    01 00 00 00    nop
0x0C830    6a 1f 3e f4    call  0xa87dc400
0x0C834    90 10 20 01    mov  1, %o0                            ! 0x1
0x0C838    11 08 00 41    sethi  %hi(0x20010400), %o0
0x0C83C    90 12 20 18    or  %o0, 0x18, %o0                     ! 0x20010418
0x0C840    92 10 20 03    mov  3, %o1
0x0C844    94 10 00 08    mov  %o0, %o2
0x0C848    d2 22 00 00    st  %o1, [ %o0 ]
0x0C84C    d0 02 80 00    ld  [ %o2 ], %o0
0x0C850    80 8a 20 04    btst  4, %o0
0x0C854    02 bf ff fe    be  0xc84c
0x0C858    13 08 00 41    sethi  %hi(0x20010400), %o1
0x0C85C    94 12 60 1c    or  %o1, 0x1c, %o2                     ! 0x2001041c
0x0C860    d0 02 80 00    ld  [ %o2 ], %o0
0x0C864    92 12 60 18    or  %o1, 0x18, %o1
0x0C868    90 12 20 01    or  %o0, 1, %o0
0x0C86C    d0 22 80 00    st  %o0, [ %o2 ]                       ! Set bit 0 in controller data
0x0C870    90 10 20 01    mov  1, %o0
0x0C874    94 10 00 09    mov  %o1, %o2
0x0C878    d0 22 40 00    st  %o0, [ %o1 ]
0x0C87C    d0 02 80 00    ld  [ %o2 ], %o0
0x0C880    80 8a 20 04    btst  4, %o0
0x0C884    02 bf ff fe    be  0xc87c
0x0C888    11 08 00 41    sethi  %hi(0x20010400), %o0
0x0C88C    90 12 20 18    or  %o0, 0x18, %o0                     ! 0x20010418
0x0C890    92 10 20 03    mov  3, %o1
0x0C894    94 10 00 08    mov  %o0, %o2
0x0C898    d2 22 00 00    st  %o1, [ %o0 ]
0x0C89C    d0 02 80 00    ld  [ %o2 ], %o0
0x0C8A0    80 8a 20 04    btst  4, %o0
0x0C8A4    02 bf ff fe    be  0xc89c
0x0C8A8    13 08 00 41    sethi  %hi(0x20010400), %o1
0x0C8AC    94 12 60 1c    or  %o1, 0x1c, %o2                     ! 0x2001041c
0x0C8B0    d0 02 80 00    ld  [ %o2 ], %o0
0x0C8B4    92 12 60 18    or  %o1, 0x18, %o1
0x0C8B8    90 12 20 04    or  %o0, 4, %o0
0x0C8BC    d0 22 80 00    st  %o0, [ %o2 ]                       ! Set bit 2 in controller data
0x0C8C0    90 10 20 01    mov  1, %o0
0x0C8C4    94 10 00 09    mov  %o1, %o2
0x0C8C8    d0 22 40 00    st  %o0, [ %o1 ]
0x0C8CC    d0 02 80 00    ld  [ %o2 ], %o0
0x0C8D0    80 8a 20 04    btst  4, %o0
0x0C8D4    02 bf ff fe    be  0xc8cc
0x0C8D8    01 00 00 00    nop
0x0C8DC    6a 1f 3e c9    call  0xa87dc400
0x0C8E0    90 10 20 01    mov  1, %o0                            ! 0x1
0x0C8E4    13 08 00 41    sethi  %hi(0x20010400), %o1
0x0C8E8    96 12 60 1c    or  %o1, 0x1c, %o3                     ! 0x2001041c
0x0C8EC    94 10 20 07    mov  7, %o2
0x0C8F0    11 00 08 00    sethi  %hi(0x200000), %o0
0x0C8F4    d4 22 c0 00    st  %o2, [ %o3 ]                       ! Write configuration value 7
0x0C8F8    92 12 60 18    or  %o1, 0x18, %o1
0x0C8FC    90 12 20 01    or  %o0, 1, %o0
0x0C900    94 10 00 09    mov  %o1, %o2
0x0C904    d0 22 40 00    st  %o0, [ %o1 ]
0x0C908    d0 02 80 00    ld  [ %o2 ], %o0
0x0C90C    80 8a 20 04    btst  4, %o0
0x0C910    02 bf ff fe    be  0xc908
0x0C914    01 00 00 00    nop
0x0C918    6a 1f 3e ba    call  0xa87dc400
0x0C91C    90 10 20 01    mov  1, %o0                            ! 0x1
0x0C920    15 08 00 41    sethi  %hi(0x20010400), %o2
0x0C924    11 04 84 44    sethi  %hi(0x12111000), %o0
0x0C928    96 12 a0 1c    or  %o2, 0x1c, %o3
0x0C92C    90 12 21 11    or  %o0, 0x111, %o0                    ! Write 0x12111111
0x0C930    13 00 10 00    sethi  %hi(0x400000), %o1
0x0C934    d0 22 c0 00    st  %o0, [ %o3 ]
0x0C938    94 12 a0 18    or  %o2, 0x18, %o2
0x0C93C    92 12 60 01    or  %o1, 1, %o1
0x0C940    96 10 00 0a    mov  %o2, %o3
0x0C944    d2 22 80 00    st  %o1, [ %o2 ]
0x0C948    d0 02 c0 00    ld  [ %o3 ], %o0
0x0C94C    80 8a 20 04    btst  4, %o0
0x0C950    02 bf ff fe    be  0xc948
0x0C954    13 08 00 41    sethi  %hi(0x20010400), %o1
0x0C958    96 12 60 1c    or  %o1, 0x1c, %o3                     ! 0x2001041c
0x0C95C    15 04 44 40    sethi  %hi(0x11110000), %o2
0x0C960    11 00 11 00    sethi  %hi(0x440000), %o0
0x0C964    d4 22 c0 00    st  %o2, [ %o3 ]                       ! Write 0x11110000
0x0C968    92 12 60 18    or  %o1, 0x18, %o1
0x0C96C    90 12 20 01    or  %o0, 1, %o0
0x0C970    94 10 00 09    mov  %o1, %o2
0x0C974    d0 22 40 00    st  %o0, [ %o1 ]
0x0C978    d0 02 80 00    ld  [ %o2 ], %o0
0x0C97C    80 8a 20 04    btst  4, %o0
0x0C980    02 bf ff fe    be  0xc978
0x0C984    11 0f 68 00    sethi  %hi(0x3da00000), %o0
0x0C988    90 12 23 02    or  %o0, 0x302, %o0                    ! 0x3da00302
0x0C98C    15 08 00 41    sethi  %hi(0x20010400), %o2
0x0C990    13 00 00 3f    sethi  %hi(0xfc00), %o1
0x0C994    a0 12 63 ff    or  %o1, 0x3ff, %l0                    ! 0xffff
0x0C998    d0 22 80 00    st  %o0, [ %o2 ]                       ! Write 0x3DA00302 to controller control
0x0C99C    a2 10 20 00    clr  %l1
0x0C9A0    80 a4 60 1f    cmp  %l1, 0x1f                         ! Scan index 0..31
0x0C9A4    18 80 00 0b    bgu  0xc9d0
0x0C9A8    90 10 00 11    mov  %l1, %o0
0x0C9AC    7f ff fe c2    call  0xc4b4                           ! Probe device via controller read
0x0C9B0    92 10 20 02    mov  2, %o1
0x0C9B4    a6 0a 00 10    and  %o0, %l0, %l3
0x0C9B8    80 a4 e1 41    cmp  %l3, 0x141                        ! Compare detected ID with 0x0141
0x0C9BC    02 80 00 04    be  0xc9cc
0x0C9C0    80 a4 e0 0f    cmp  %l3, 0xf                          ! Also accept ID 0x000F
0x0C9C4    32 bf ff f7    bne,a   0xc9a0
0x0C9C8    a2 04 60 01    inc  %l1
0x0C9CC    80 a4 60 1f    cmp  %l1, 0x1f
0x0C9D0    18 80 00 1c    bgu  0xca40
0x0C9D4    92 10 20 00    clr  %o1
0x0C9D8    7f ff fe b7    call  0xc4b4                           ! Read selected device status
0x0C9DC    90 10 00 11    mov  %l1, %o0
0x0C9E0    15 00 00 20    sethi  %hi(0x8000), %o2
0x0C9E4    a0 10 00 08    mov  %o0, %l0
0x0C9E8    a4 10 00 0a    mov  %o2, %l2
0x0C9EC    90 10 00 11    mov  %l1, %o0
0x0C9F0    92 10 20 00    clr  %o1
0x0C9F4    7f ff fe fc    call  0xc5e4                           ! Configure selected device
0x0C9F8    94 14 00 0a    or  %l0, %o2, %o2
0x0C9FC    b0 10 20 64    mov  0x64, %i0
0x0CA00    80 a6 20 00    cmp  %i0, 0                            ! Start bounded 100-iteration poll
0x0CA04    22 80 00 0c    be,a   0xca34
0x0CA08    25 00 00 20    sethi  %hi(0x8000), %l2
0x0CA0C    6a 1f 3e 7d    call  0xa87dc400
0x0CA10    90 10 20 32    mov  0x32, %o0
0x0CA14    90 10 00 11    mov  %l1, %o0
0x0CA18    7f ff fe a7    call  0xc4b4                           ! Read selected device status again
0x0CA1C    92 10 20 00    clr  %o1
0x0CA20    a0 10 00 08    mov  %o0, %l0
0x0CA24    80 8c 00 12    btst  %l0, %l2
0x0CA28    12 bf ff f6    bne  0xca00
0x0CA2C    b0 06 3f ff    add  %i0, -1, %i0
0x0CA30    25 00 00 20    sethi  %hi(0x8000), %l2
0x0CA34    80 8c 00 12    btst  %l0, %l2
0x0CA38    02 80 00 07    be  0xca54                             ! If busy bit remains set, fail
0x0CA3C    94 0c 3b ff    and  %l0, -1025, %o2
0x0CA40    10 80 00 74    b  0xcc10                              ! Failure exit status 1
0x0CA44    b0 10 20 01    mov  1, %i0
0x0CA48    90 10 20 01    mov  1, %o0
0x0CA4C    10 80 00 28    b  0xcaec
0x0CA50    d0 2a 63 72    stb  %o0, [ %o1 + 0x372 ]
0x0CA54    92 10 20 00    clr  %o1                               ! Reconfigure selected device
0x0CA58    7f ff fe e3    call  0xc5e4
0x0CA5C    90 10 00 11    mov  %l1, %o0
0x0CA60    92 10 20 00    clr  %o1
0x0CA64    7f ff fe 94    call  0xc4b4
0x0CA68    90 10 00 11    mov  %l1, %o0
0x0CA6C    13 00 00 04    sethi  %hi(0x1000), %o1
0x0CA70    92 12 63 00    or  %o1, 0x300, %o1                    ! 0x1300
0x0CA74    a0 12 00 09    or  %o0, %o1, %l0
0x0CA78    94 10 00 10    mov  %l0, %o2
0x0CA7C    92 10 20 00    clr  %o1
0x0CA80    7f ff fe d9    call  0xc5e4                           ! Write updated device setting
0x0CA84    90 10 00 11    mov  %l1, %o0
0x0CA88    15 08 00 00    sethi  %hi(0x20000000), %o2
0x0CA8C    96 12 a0 40    or  %o2, 0x40, %o3                     ! 0x20000040
0x0CA90    e4 22 c0 00    st  %l2, [ %o3 ]                       ! Set interface MMIO 0x20000040
0x0CA94    92 12 a0 44    or  %o2, 0x44, %o1
0x0CA98    90 10 22 62    mov  0x262, %o0
0x0CA9C    d0 22 40 00    st  %o0, [ %o1 ]
0x0CAA0    b0 12 a0 4c    or  %o2, 0x4c, %i0                     ! Write MMIO 0x20000044
0x0CAA4    94 12 a0 50    or  %o2, 0x50, %o2
0x0CAA8    11 00 00 10    sethi  %hi(0x4000), %o0
0x0CAAC    d0 22 80 00    st  %o0, [ %o2 ]
0x0CAB0    92 10 21 00    mov  0x100, %o1
0x0CAB4    d2 22 c0 00    st  %o1, [ %o3 ]                       ! Enable interface
0x0CAB8    21 00 3f fe    sethi  %hi(0xfff800), %l0
0x0CABC    6a 1f 3e 51    call  0xa87dc400
0x0CAC0    90 10 23 e8    mov  0x3e8, %o0
0x0CAC4    90 10 00 11    mov  %l1, %o0
0x0CAC8    7f ff fe 7b    call  0xc4b4
0x0CACC    92 10 20 01    mov  1, %o1                            ! Read device status
0x0CAD0    80 8a 20 04    btst  4, %o0
0x0CAD4    32 bf ff dd    bne,a   0xca48
0x0CAD8    13 21 e0 dc    sethi  %hi(0x87837000), %o1
0x0CADC    d0 06 00 00    ld  [ %i0 ], %o0
0x0CAE0    80 8a 00 10    btst  %o0, %l0                         ! Poll interface status bits
0x0CAE4    12 bf ff f6    bne  0xcabc
0x0CAE8    01 00 00 00    nop
0x0CAEC    80 a4 e1 41    cmp  %l3, 0x141                        ! Branch by detected device ID
0x0CAF0    12 80 00 27    bne  0xcb8c
0x0CAF4    92 10 20 1c    mov  0x1c, %o1
0x0CAF8    92 10 20 03    mov  3, %o1
0x0CAFC    7f ff fe 6e    call  0xc4b4
0x0CB00    90 10 00 11    mov  %l1, %o0
0x0CB04    91 3a 20 04    sra  %o0, 4, %o0
0x0CB08    90 0a 20 3f    and  %o0, 0x3f, %o0
0x0CB0C    13 21 e0 dc    sethi  %hi(0x87837000), %o1
0x0CB10    80 a2 20 28    cmp  %o0, 0x28
0x0CB14    12 80 00 12    bne  0xcb5c                            ! Check extracted device field 0x28
0x0CB18    d0 32 60 00    sth  %o0, [ %o1 ]                      ! Save field to 0x87837000
0x0CB1C    92 10 20 16    mov  0x16, %o1
0x0CB20    94 10 20 03    mov  3, %o2
0x0CB24    7f ff fe b0    call  0xc5e4                           ! Program device register 0x16
0x0CB28    90 10 00 11    mov  %l1, %o0
0x0CB2C    92 10 20 11    mov  0x11, %o1
0x0CB30    94 10 20 10    mov  0x10, %o2
0x0CB34    7f ff fe ac    call  0xc5e4                           ! Program device register 0x11
0x0CB38    90 10 00 11    mov  %l1, %o0
0x0CB3C    92 10 20 10    mov  0x10, %o1
0x0CB40    94 10 21 77    mov  0x177, %o2
0x0CB44    7f ff fe a8    call  0xc5e4                           ! Program device register 0x10
0x0CB48    90 10 00 11    mov  %l1, %o0
0x0CB4C    90 10 00 11    mov  %l1, %o0
0x0CB50    92 10 20 16    mov  0x16, %o1
0x0CB54    7f ff fe a4    call  0xc5e4                           ! Program device register 0x16
0x0CB58    94 10 20 00    clr  %o2
0x0CB5C    92 10 20 11    mov  0x11, %o1
0x0CB60    7f ff fe 55    call  0xc4b4
0x0CB64    90 10 00 11    mov  %l1, %o0
0x0CB68    92 10 00 08    mov  %o0, %o1
0x0CB6C    80 8a 64 00    btst  0x400, %o1                       ! Test device status bit 10
0x0CB70    02 80 00 04    be  0xcb80
0x0CB74    11 00 00 20    sethi  %hi(0x8000), %o0
0x0CB78    10 80 00 03    b  0xcb84
0x0CB7C    90 0a 40 08    and  %o1, %o0, %o0
0x0CB80    90 10 20 00    clr  %o0
0x0CB84    10 80 00 05    b  0xcb98
0x0CB88    92 10 00 08    mov  %o0, %o1
0x0CB8C    7f ff fe 4a    call  0xc4b4
0x0CB90    90 10 00 11    mov  %l1, %o0
0x0CB94    92 0a 20 10    and  %o0, 0x10, %o1
0x0CB98    80 a2 60 00    cmp  %o1, 0                            ! Select final configuration based on status
0x0CB9C    02 80 00 10    be  0xcbdc
0x0CBA0    15 08 00 41    sethi  %hi(0x20010400), %o2
0x0CBA4    11 00 00 3c    sethi  %hi(0xf000), %o0
0x0CBA8    96 12 a0 1c    or  %o2, 0x1c, %o3
0x0CBAC    90 12 22 05    or  %o0, 0x205, %o0
0x0CBB0    13 00 01 00    sethi  %hi(0x40000), %o1
0x0CBB4    d0 22 c0 00    st  %o0, [ %o3 ]                       ! Write final value 0xF205
0x0CBB8    94 12 a0 18    or  %o2, 0x18, %o2
0x0CBBC    92 12 60 01    or  %o1, 1, %o1
0x0CBC0    96 10 00 0a    mov  %o2, %o3
0x0CBC4    d2 22 80 00    st  %o1, [ %o2 ]
0x0CBC8    d0 02 c0 00    ld  [ %o3 ], %o0
0x0CBCC    80 8a 20 04    btst  4, %o0
0x0CBD0    02 bf ff fe    be  0xcbc8
0x0CBD4    b0 10 20 00    clr  %i0
0x0CBD8    30 80 00 0e    b,a   0xcc10
0x0CBDC    11 00 00 3c    sethi  %hi(0xf000), %o0
0x0CBE0    96 12 a0 1c    or  %o2, 0x1c, %o3
0x0CBE4    90 12 21 05    or  %o0, 0x105, %o0                    ! Write final value 0xF105
0x0CBE8    13 00 01 00    sethi  %hi(0x40000), %o1
0x0CBEC    d0 22 c0 00    st  %o0, [ %o3 ]
0x0CBF0    94 12 a0 18    or  %o2, 0x18, %o2
0x0CBF4    92 12 60 01    or  %o1, 1, %o1
0x0CBF8    96 10 00 0a    mov  %o2, %o3
0x0CBFC    d2 22 80 00    st  %o1, [ %o2 ]
0x0CC00    d0 02 c0 00    ld  [ %o3 ], %o0
0x0CC04    80 8a 20 04    btst  4, %o0
0x0CC08    02 bf ff fe    be  0xcc00
0x0CC0C    b0 10 20 00    clr  %i0
0x0CC10    81 c7 e0 08    ret                                    ! Return status
0x0CC14    81 e8 00 00    restore

! 0xCC18: Wait for MMIO command completion
! Steps:
! 1. Poll 0x200000E0 bit 0 with bounded counter.
! 2. Invoke status/error routine 0xFAF4 on timeout.

0x0CC18    9d e3 bf 98    save  %sp, -104, %sp                   ! Entry: wait for command completion
0x0CC1C    11 08 00 00    sethi  %hi(0x20000000), %o0
0x0CC20    94 12 20 e0    or  %o0, 0xe0, %o2                     ! 0x200000e0
0x0CC24    d2 02 80 00    ld  [ %o2 ], %o1                       ! Read status at 0x200000E0
0x0CC28    11 00 01 24    sethi  %hi(0x49000), %o0
0x0CC2C    80 8a 60 01    btst  1, %o1                           ! Test busy bit 0
0x0CC30    02 80 00 0c    be  0xcc60
0x0CC34    a0 12 23 e0    or  %o0, 0x3e0, %l0
0x0CC38    a2 10 00 0a    mov  %o2, %l1
0x0CC3C    a0 84 3f ff    addcc  %l0, -1, %l0
0x0CC40    12 80 00 04    bne  0xcc50                            ! Countdown with timeout branch
0x0CC44    90 10 20 01    mov  1, %o0
0x0CC48    40 00 0b ab    call  0xfaf4                           ! Call status/error handler 0xFAF4
0x0CC4C    92 10 20 0c    mov  0xc, %o1
0x0CC50    d0 04 40 00    ld  [ %l1 ], %o0
0x0CC54    80 8a 20 01    btst  1, %o0
0x0CC58    12 bf ff fa    bne  0xcc40
0x0CC5C    a0 84 3f ff    addcc  %l0, -1, %l0
0x0CC60    81 c7 e0 08    ret
0x0CC64    81 e8 00 00    restore

! 0xCC68: Write two controller data words
! Steps:
! 1. Pack channel and transfer count, write D8/DC and command D0.
! 2. Wait using 0xCC18.

0x0CC68    9d e3 bf 98    save  %sp, -104, %sp                   ! Entry: write controller data words
0x0CC6C    13 08 00 00    sethi  %hi(0x20000000), %o1
0x0CC70    90 12 60 d8    or  %o1, 0xd8, %o0                     ! 0x200000d8
0x0CC74    b6 06 ff ff    add  %i3, -1, %i3
0x0CC78    f2 22 00 00    st  %i1, [ %o0 ]                       ! Write first word to 0x200000D8
0x0CC7C    b1 2e 20 01    sll  %i0, 1, %i0
0x0CC80    b7 2e e0 08    sll  %i3, 8, %i3
0x0CC84    15 00 00 0a    sethi  %hi(0x2800), %o2
0x0CC88    90 12 60 dc    or  %o1, 0xdc, %o0
0x0CC8C    b6 16 c0 0a    or  %i3, %o2, %i3
0x0CC90    b0 0e 20 fe    and  %i0, 0xfe, %i0
0x0CC94    b0 16 00 1b    or  %i0, %i3, %i0
0x0CC98    f4 22 00 00    st  %i2, [ %o0 ]                       ! Write second word to 0x200000DC
0x0CC9C    92 12 60 d0    or  %o1, 0xd0, %o1
0x0CCA0    f0 22 40 00    st  %i0, [ %o1 ]                       ! Issue packed write command
0x0CCA4    7f ff ff dd    call  0xcc18                           ! Wait for completion
0x0CCA8    01 00 00 00    nop
0x0CCAC    81 c7 e0 08    ret
0x0CCB0    81 e8 00 00    restore

! 0xCCB4: Read two controller data words
! Steps:
! 1. Issue read command and wait.
! 2. Copy words from D8/DC to caller pointers.

0x0CCB4    9d e3 bf 98    save  %sp, -104, %sp                   ! Entry: read controller data words
0x0CCB8    b6 06 ff ff    add  %i3, -1, %i3
0x0CCBC    b7 2e e0 08    sll  %i3, 8, %i3
0x0CCC0    11 00 00 0a    sethi  %hi(0x2800), %o0
0x0CCC4    b1 2e 20 01    sll  %i0, 1, %i0
0x0CCC8    b6 16 c0 08    or  %i3, %o0, %i3
0x0CCCC    b0 0e 20 fe    and  %i0, 0xfe, %i0
0x0CCD0    21 08 00 00    sethi  %hi(0x20000000), %l0
0x0CCD4    b0 16 00 1b    or  %i0, %i3, %i0
0x0CCD8    90 14 20 d0    or  %l0, 0xd0, %o0
0x0CCDC    b0 16 20 01    or  %i0, 1, %i0
0x0CCE0    f0 22 00 00    st  %i0, [ %o0 ]                       ! Issue packed read command
0x0CCE4    7f ff ff cd    call  0xcc18                           ! Wait for completion
0x0CCE8    01 00 00 00    nop
0x0CCEC    90 14 20 d8    or  %l0, 0xd8, %o0
0x0CCF0    d2 02 00 00    ld  [ %o0 ], %o1                       ! Read first result word
0x0CCF4    a0 14 20 dc    or  %l0, 0xdc, %l0
0x0CCF8    d2 26 40 00    st  %o1, [ %i1 ]                       ! Store first word to caller pointer
0x0CCFC    d0 04 00 00    ld  [ %l0 ], %o0                       ! Read second result word
0x0CD00    d0 26 80 00    st  %o0, [ %i2 ]                       ! Store second word to caller pointer
0x0CD04    81 c7 e0 08    ret
0x0CD08    81 e8 00 00    restore

! 0xCD0C: Read controller status bit
! Steps:
! 1. Issue command, wait and return Boolean derived from E0 bit 1.

0x0CD0C    9d e3 bf 98    save  %sp, -104, %sp                   ! Entry: read status bit
0x0CD10    11 00 00 0a    sethi  %hi(0x2800), %o0
0x0CD14    90 12 20 01    or  %o0, 1, %o0                        ! 0x2801
0x0CD18    b1 2e 20 01    sll  %i0, 1, %i0
0x0CD1C    21 08 00 00    sethi  %hi(0x20000000), %l0
0x0CD20    b0 16 00 08    or  %i0, %o0, %i0
0x0CD24    92 14 20 d0    or  %l0, 0xd0, %o1
0x0CD28    f0 22 40 00    st  %i0, [ %o1 ]                       ! Issue packed status command
0x0CD2C    7f ff ff bb    call  0xcc18
0x0CD30    a0 14 20 e0    or  %l0, 0xe0, %l0
0x0CD34    d0 04 00 00    ld  [ %l0 ], %o0                       ! Read status register
0x0CD38    90 0a 20 02    and  %o0, 2, %o0                       ! Mask status bit 1
0x0CD3C    80 a0 00 08    cmp  %g0, %o0
0x0CD40    b0 60 3f ff    subx  %g0, -1, %i0                     ! Convert status flag to Boolean using carry
0x0CD44    81 c7 e0 08    ret
0x0CD48    81 e8 00 00    restore

! 0xCD4C: Read one device byte
! Steps:
! 1. Write packed request and return selected byte from D8.

0x0CD4C    9d e3 bf 98    save  %sp, -104, %sp                   ! Entry: read device byte
0x0CD50    13 08 00 00    sethi  %hi(0x20000000), %o1
0x0CD54    a0 12 60 d8    or  %o1, 0xd8, %l0                     ! 0x200000d8
0x0CD58    b1 2e 20 18    sll  %i0, 0x18, %i0
0x0CD5C    11 00 00 2a    sethi  %hi(0xa800), %o0
0x0CD60    f0 24 00 00    st  %i0, [ %l0 ]                       ! Write index in high byte
0x0CD64    92 12 60 d0    or  %o1, 0xd0, %o1
0x0CD68    90 12 21 d2    or  %o0, 0x1d2, %o0
0x0CD6C    d0 22 40 00    st  %o0, [ %o1 ]                       ! Issue command 0xA9D2
0x0CD70    7f ff ff aa    call  0xcc18
0x0CD74    01 00 00 00    nop
0x0CD78    f0 04 00 00    ld  [ %l0 ], %i0                       ! Read result word
0x0CD7C    b1 36 20 10    srl  %i0, 0x10, %i0
0x0CD80    b0 0e 20 ff    and  %i0, 0xff, %i0                    ! Extract byte
0x0CD84    81 c7 e0 08    ret
0x0CD88    81 e8 00 00    restore

! 0xCD8C: Write one device byte
! Steps:
! 1. Pack index/value and issue command through D0/D8.

0x0CD8C    9d e3 bf 98    save  %sp, -104, %sp                   ! Entry: write device byte
0x0CD90    b2 0e 60 ff    and  %i1, 0xff, %i1
0x0CD94    11 00 00 40    sethi  %hi(0x10000), %o0
0x0CD98    b3 2e 60 08    sll  %i1, 8, %i1
0x0CD9C    b2 16 40 08    or  %i1, %o0, %i1
0x0CDA0    15 08 00 00    sethi  %hi(0x20000000), %o2
0x0CDA4    b1 2e 20 18    sll  %i0, 0x18, %i0
0x0CDA8    90 12 a0 d8    or  %o2, 0xd8, %o0
0x0CDAC    b0 16 00 19    or  %i0, %i1, %i0
0x0CDB0    13 00 00 0a    sethi  %hi(0x2800), %o1
0x0CDB4    f0 22 00 00    st  %i0, [ %o0 ]                       ! Write packed index and byte
0x0CDB8    94 12 a0 d0    or  %o2, 0xd0, %o2
0x0CDBC    92 12 63 d2    or  %o1, 0x3d2, %o1
0x0CDC0    d2 22 80 00    st  %o1, [ %o2 ]                       ! Issue command 0x2BD2
0x0CDC4    7f ff ff 95    call  0xcc18
0x0CDC8    01 00 00 00    nop
0x0CDCC    81 c7 e0 08    ret
0x0CDD0    81 e8 00 00    restore

! 0xCDD4: Signed division helper
! Steps:
! 1. Set Y sign extension, divide, adjust overflow result.

0x0CDD4    95 3a 20 1f    sra  %o0, 0x1f, %o2                    ! Sign-extend dividend into Y
0x0CDD8    81 82 a0 00    wr  %o2, %y
0x0CDDC    01 00 00 00    nop
0x0CDE0    01 00 00 00    nop
0x0CDE4    01 00 00 00    nop
0x0CDE8    90 fa 00 09    sdivcc  %o0, %o1, %o0                  ! Signed divide
0x0CDEC    2e 80 00 02    bvs,a   0xcdf4
0x0CDF0    90 3a 00 00    xnor  %o0, %g0, %o0
0x0CDF4    81 c3 e0 08    retl
0x0CDF8    01 00 00 00    nop

! 0xCDFC: Unsigned division helper
! Steps:
! 1. Clear Y and divide.

0x0CDFC    81 80 20 00    wr  %g0, %y                            ! Clear Y for unsigned divide
0x0CE00    01 00 00 00    nop
0x0CE04    01 00 00 00    nop
0x0CE08    81 c3 e0 08    retl
0x0CE0C    90 72 00 09    udiv  %o0, %o1, %o0                    ! Unsigned divide in return delay slot

! 0xCE10: Signed multiplication helper
! Steps:
! 1. Multiply and return low/high halves in o0/o1.

0x0CE10    01 00 00 00    nop
0x0CE14    01 00 00 00    nop
0x0CE18    01 00 00 00    nop
0x0CE1C    90 5a 00 09    smul  %o0, %o1, %o0                    ! Signed multiply
0x0CE20    81 c3 e0 08    retl
0x0CE24    93 40 00 00    rd  %y, %o1                            ! Return high product word in delay slot

! 0xCE28: Unsigned multiplication helper
! Steps:
! 1. Multiply and return low/high halves in o0/o1.

0x0CE28    01 00 00 00    nop
0x0CE2C    01 00 00 00    nop
0x0CE30    01 00 00 00    nop
0x0CE34    90 52 00 09    umul  %o0, %o1, %o0                    ! Unsigned multiply
0x0CE38    81 c3 e0 08    retl
0x0CE3C    93 40 00 00    rd  %y, %o1                            ! Return high product word in delay slot

! 0xCE40: Signed remainder helper
! Steps:
! 1. Divide, multiply quotient and subtract.

0x0CE40    01 00 00 00    nop
0x0CE44    99 3a 20 1f    sra  %o0, 0x1f, %o4
0x0CE48    81 83 20 00    wr  %o4, %y
0x0CE4C    01 00 00 00    nop
0x0CE50    01 00 00 00    nop
0x0CE54    01 00 00 00    nop
0x0CE58    94 fa 00 09    sdivcc  %o0, %o1, %o2                  ! Signed divide for remainder
0x0CE5C    2e 80 00 02    bvs,a   0xce64
0x0CE60    94 3a 80 00    xnor  %o2, %g0, %o2
0x0CE64    94 5a 80 09    smul  %o2, %o1, %o2                    ! Multiply quotient by divisor
0x0CE68    81 c3 e0 08    retl
0x0CE6C    90 22 00 0a    sub  %o0, %o2, %o0                     ! Subtract to get remainder in return delay slot

! 0xCE70: Unsigned remainder helper
! Steps:
! 1. Divide, multiply quotient and subtract.

0x0CE70    01 00 00 00    nop
0x0CE74    81 80 20 00    wr  %g0, %y
0x0CE78    01 00 00 00    nop
0x0CE7C    01 00 00 00    nop
0x0CE80    01 00 00 00    nop
0x0CE84    94 72 00 09    udiv  %o0, %o1, %o2                    ! Unsigned divide for remainder
0x0CE88    94 52 80 09    umul  %o2, %o1, %o2
0x0CE8C    81 c3 e0 08    retl
0x0CE90    90 22 00 0a    sub  %o0, %o2, %o0                     ! Subtract to get remainder in return delay slot

! 0xCE94: Flash logical-to-physical address translation
! Steps:
! 1. If translation flag is set, scan up to 1024 mapping entries.
! 2. Preserve low five bits while substituting the translated page index.

0x0CE94    05 21 e0 dc    sethi  %hi(0x87837000), %g2            ! Entry: flash address translation
0x0CE98    c6 00 a0 c8    ld  [ %g2 + 0xc8 ], %g3                ! Read translation-enabled flag at 0x878370C8
0x0CE9C    80 a0 e0 00    cmp  %g3, 0
0x0CEA0    02 80 00 16    be  0xcef8
0x0CEA4    99 3a 20 05    sra  %o0, 5, %o4                       ! Original address divided by 32
0x0CEA8    92 10 20 00    clr  %o1
0x0CEAC    17 21 e0 dc    sethi  %hi(0x87837000), %o3
0x0CEB0    80 a2 63 ff    cmp  %o1, 0x3ff                        ! Scan up to 1024 entries
0x0CEB4    14 80 00 0b    bg  0xcee0
0x0CEB8    95 2a 60 02    sll  %o1, 2, %o2
0x0CEBC    c6 02 e0 04    ld  [ %o3 + 4 ], %g3
0x0CEC0    05 00 00 3f    sethi  %hi(0xfc00), %g2
0x0CEC4    c6 10 c0 0a    lduh  [ %g3 + %o2 ], %g3               ! Read 16-bit source page index
0x0CEC8    84 10 a3 ff    or  %g2, 0x3ff, %g2
0x0CECC    80 a0 c0 02    cmp  %g3, %g2
0x0CED0    02 80 00 0a    be  0xcef8                             ! Stop if 0xFFFF sentinel
0x0CED4    80 a0 c0 0c    cmp  %g3, %o4
0x0CED8    32 bf ff f6    bne,a   0xceb0
0x0CEDC    92 02 60 01    inc  %o1
0x0CEE0    c4 02 e0 04    ld  [ %o3 + 4 ], %g2                   ! Read translation-table pointer
0x0CEE4    86 0a 20 1f    and  %o0, 0x1f, %g3
0x0CEE8    84 00 80 0a    add  %g2, %o2, %g2
0x0CEEC    d0 10 a0 02    lduh  [ %g2 + 2 ], %o0                 ! Read translated 16-bit page index
0x0CEF0    91 2a 20 05    sll  %o0, 5, %o0                       ! Multiply translated page index by 32
0x0CEF4    90 12 00 03    or  %o0, %g3, %o0                      ! Preserve original low five bits
0x0CEF8    81 c3 e0 08    retl
0x0CEFC    01 00 00 00    nop

! 0xCF00: Flash address command
! Steps:
! 1. Translate address and emit command plus three address bytes to MMIO.

0x0CF00    9d e3 bf 98    save  %sp, -104, %sp                   ! Entry: issue flash command/address
0x0CF04    7f ff ff e4    call  0xce94                           ! Translate requested address
0x0CF08    90 10 00 19    mov  %i1, %o0
0x0CF0C    13 02 00 40    sethi  %hi(0x8010000), %o1
0x0CF10    f0 2a 40 00    stb  %i0, [ %o1 ]                      ! Write command byte to 0x08010000
0x0CF14    15 02 00 80    sethi  %hi(0x8020000), %o2
0x0CF18    c0 2a 80 00    clrb  [ %o2 ]
0x0CF1C    d0 2a 80 00    stb  %o0, [ %o2 ]                      ! Write first address byte to 0x08020000
0x0CF20    93 3a 20 10    sra  %o0, 0x10, %o1
0x0CF24    91 3a 20 08    sra  %o0, 8, %o0
0x0CF28    d0 2a 80 00    stb  %o0, [ %o2 ]                      ! Write second address byte to same port
0x0CF2C    92 0a 60 0f    and  %o1, 0xf, %o1
0x0CF30    d2 2a 80 00    stb  %o1, [ %o2 ]                      ! Write third address nibble to same port
0x0CF34    6a 1f 3d 33    call  0xa87dc400
0x0CF38    90 10 20 0c    mov  0xc, %o0
0x0CF3C    81 c7 e0 08    ret
0x0CF40    81 e8 00 00    restore

! 0xCF44: Read 512-byte flash page and optional postprocessing
! Steps:
! 1. Enable flash access, set page address and copy 128 words to destination.
! 2. Optionally transform two 256-byte halves through helpers at 0xD4DC and 0xD578.
! 3. Restore original controller register on exit.

0x0CF44    9d e3 bf 80    save  %sp, -128, %sp                   ! Entry: flash page read
0x0CF48    11 08 00 00    sethi  %hi(0x20000000), %o0
0x0CF4C    90 12 21 0c    or  %o0, 0x10c, %o0                    ! 0x2000010c
0x0CF50    e6 02 00 00    ld  [ %o0 ], %l3                       ! Save original control register
0x0CF54    92 14 e4 00    or  %l3, 0x400, %o1
0x0CF58    d2 22 00 00    st  %o1, [ %o0 ]                       ! Temporarily set control bit 10
0x0CF5C    92 10 00 18    mov  %i0, %o1
0x0CF60    7f ff ff e8    call  0xcf00                           ! Issue flash read command at requested address
0x0CF64    90 10 20 00    clr  %o0
0x0CF68    13 02 00 00    sethi  %hi(0x8000000), %o1
0x0CF6C    94 10 20 00    clr  %o2
0x0CF70    d0 02 40 00    ld  [ %o1 ], %o0                       ! Read 32-bit word from flash data window
0x0CF74    d0 26 40 0a    st  %o0, [ %i1 + %o2 ]                 ! Store into caller output buffer
0x0CF78    94 02 a0 04    add  %o2, 4, %o2
0x0CF7C    80 a2 a1 ff    cmp  %o2, 0x1ff
0x0CF80    04 bf ff fc    ble  0xcf70                            ! Continue until 512 bytes copied
0x0CF84    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0CF88    d2 4a 21 a0    ldsb  [ %o0 + 0x1a0 ], %o1             ! Check optional postprocessing flag
0x0CF8C    80 a2 60 00    cmp  %o1, 0
0x0CF90    02 80 00 21    be  0xd014
0x0CF94    94 10 20 00    clr  %o2
0x0CF98    a0 07 bf e0    add  %fp, -32, %l0
0x0CF9C    a2 06 61 00    add  %i1, 0x100, %l1
0x0CFA0    a4 07 bf e3    add  %fp, -29, %l2
0x0CFA4    96 07 bf f8    add  %fp, -8, %o3
0x0CFA8    19 02 00 00    sethi  %hi(0x8000000), %o4
0x0CFAC    92 02 c0 0a    add  %o3, %o2, %o1
0x0CFB0    d0 03 00 00    ld  [ %o4 ], %o0
0x0CFB4    94 02 a0 04    add  %o2, 4, %o2
0x0CFB8    80 a2 a0 0f    cmp  %o2, 0xf
0x0CFBC    04 bf ff fc    ble  0xcfac
0x0CFC0    d0 22 7f f0    st  %o0, [ %o1 + -16 ]
0x0CFC4    90 10 00 19    mov  %i1, %o0
0x0CFC8    40 00 01 45    call  0xd4dc                           ! Process first 256-byte half via helper
0x0CFCC    92 10 00 10    mov  %l0, %o1
0x0CFD0    90 10 00 11    mov  %l1, %o0
0x0CFD4    40 00 01 42    call  0xd4dc                           ! Process second 256-byte half via helper
0x0CFD8    92 10 00 12    mov  %l2, %o1
0x0CFDC    80 a6 20 1f    cmp  %i0, 0x1f
0x0CFE0    08 80 00 10    bleu  0xd020
0x0CFE4    94 10 00 19    mov  %i1, %o2
0x0CFE8    98 10 00 10    mov  %l0, %o4
0x0CFEC    90 10 00 18    mov  %i0, %o0
0x0CFF0    92 10 20 00    clr  %o1
0x0CFF4    40 00 01 61    call  0xd578                           ! Optional transformation of first half
0x0CFF8    96 07 bf ee    add  %fp, -18, %o3
0x0CFFC    90 10 00 18    mov  %i0, %o0
0x0D000    94 10 00 11    mov  %l1, %o2
0x0D004    98 10 00 12    mov  %l2, %o4
0x0D008    92 10 20 01    mov  1, %o1
0x0D00C    40 00 01 5b    call  0xd578                           ! Optional transformation of second half
0x0D010    96 07 bf f1    add  %fp, -15, %o3
0x0D014    11 08 00 00    sethi  %hi(0x20000000), %o0
0x0D018    90 12 21 0c    or  %o0, 0x10c, %o0                    ! 0x2000010c
0x0D01C    e6 22 00 00    st  %l3, [ %o0 ]                       ! Restore original PADRE_PCI_FEATURE value
0x0D020    81 c7 e0 08    ret                                    ! Return; function ends here
0x0D024    81 e8 00 00    restore
0x0D028    92 10 00 08    mov  %o0, %o1                          ! Start decimal conversion; no digit-range validation is visible.
0x0D02C    c4 4a 40 00    ldsb  [ %o1 ], %g2
0x0D030    86 10 20 00    clr  %g3
0x0D034    80 a0 a0 00    cmp  %g2, 0
0x0D038    02 80 00 0e    be  0xd070
0x0D03C    d4 0a 40 00    ldub  [ %o1 ], %o2
0x0D040    85 28 e0 02    sll  %g3, 2, %g2                       ! Accumulate decimal value as value * 10 + digit.
0x0D044    84 00 80 03    add  %g2, %g3, %g2
0x0D048    92 02 60 01    inc  %o1
0x0D04C    87 2a a0 18    sll  %o2, 0x18, %g3
0x0D050    85 28 a0 01    sll  %g2, 1, %g2
0x0D054    d0 4a 40 00    ldsb  [ %o1 ], %o0
0x0D058    84 00 bf d0    add  %g2, -48, %g2
0x0D05C    87 38 e0 18    sra  %g3, 0x18, %g3
0x0D060    d4 0a 40 00    ldub  [ %o1 ], %o2
0x0D064    80 a2 20 00    cmp  %o0, 0
0x0D068    12 bf ff f6    bne  0xd040
0x0D06C    86 00 80 03    add  %g2, %g3, %g3
0x0D070    81 c3 e0 08    retl                                   ! Return parsed integer in %o0 (delay slot).
0x0D074    90 10 00 03    mov  %g3, %o0


! 0xD078: Colon-delimited firmware metadata parser
! Steps:
! 1. Split an ASCII record into fields using colon delimiters.
! 2. Convert numeric fields and write the results through output pointers.

0x0D078    9d e3 bf 58    save  %sp, -168, %sp
0x0D07C    a0 10 00 18    mov  %i0, %l0
0x0D080    b0 10 20 00    clr  %i0
0x0D084    d6 0c 00 18    ldub  [ %l0 + %i0 ], %o3
0x0D088    92 10 00 19    mov  %i1, %o1
0x0D08C    94 10 20 00    clr  %o2
0x0D090    80 a2 e0 3a    cmp  %o3, 0x3a                         ! First field delimiter is ASCII colon.
0x0D094    02 80 00 0a    be  0xd0bc
0x0D098    a2 07 bf b8    add  %fp, -72, %l1
0x0D09C    98 10 00 11    mov  %l1, %o4
0x0D0A0    d6 2b 00 0a    stb  %o3, [ %o4 + %o2 ]
0x0D0A4    b0 06 20 01    inc  %i0
0x0D0A8    d0 4c 00 18    ldsb  [ %l0 + %i0 ], %o0
0x0D0AC    94 02 a0 01    inc  %o2
0x0D0B0    80 a2 20 3a    cmp  %o0, 0x3a
0x0D0B4    12 bf ff fb    bne  0xd0a0
0x0D0B8    d6 0c 00 18    ldub  [ %l0 + %i0 ], %o3
0x0D0BC    c0 2c 40 0a    clrb  [ %l1 + %o2 ]
0x0D0C0    40 00 05 f4    call  0xe890                           ! Parse first field using helper at 0xE890 (outside this block).
0x0D0C4    90 10 00 11    mov  %l1, %o0
0x0D0C8    80 a2 20 00    cmp  %o0, 0
0x0D0CC    12 80 00 04    bne  0xd0dc
0x0D0D0    b0 06 20 02    add  %i0, 2, %i0
0x0D0D4    10 80 00 2b    b  0xd180
0x0D0D8    c0 26 c0 00    clr  [ %i3 ]
0x0D0DC    d0 4c 00 18    ldsb  [ %l0 + %i0 ], %o0
0x0D0E0    94 10 20 00    clr  %o2
0x0D0E4    80 a2 20 3a    cmp  %o0, 0x3a
0x0D0E8    02 80 00 0a    be  0xd110
0x0D0EC    d2 0c 00 18    ldub  [ %l0 + %i0 ], %o1
0x0D0F0    96 10 00 11    mov  %l1, %o3
0x0D0F4    d2 2a c0 0a    stb  %o1, [ %o3 + %o2 ]
0x0D0F8    b0 06 20 01    inc  %i0
0x0D0FC    d0 4c 00 18    ldsb  [ %l0 + %i0 ], %o0
0x0D100    94 02 a0 01    inc  %o2
0x0D104    80 a2 20 3a    cmp  %o0, 0x3a
0x0D108    12 bf ff fb    bne  0xd0f4
0x0D10C    d2 0c 00 18    ldub  [ %l0 + %i0 ], %o1
0x0D110    c0 2c 40 0a    clrb  [ %l1 + %o2 ]
0x0D114    7f ff ff c5    call  0xd028                           ! Convert second field to decimal.
0x0D118    90 10 00 11    mov  %l1, %o0
0x0D11C    d0 26 80 00    st  %o0, [ %i2 ]
0x0D120    b0 06 20 02    add  %i0, 2, %i0
0x0D124    d0 4c 00 18    ldsb  [ %l0 + %i0 ], %o0
0x0D128    94 10 20 00    clr  %o2
0x0D12C    80 a2 20 0a    cmp  %o0, 0xa
0x0D130    02 80 00 0f    be  0xd16c
0x0D134    d2 0c 00 18    ldub  [ %l0 + %i0 ], %o1
0x0D138    80 a2 20 00    cmp  %o0, 0
0x0D13C    02 80 00 0c    be  0xd16c
0x0D140    96 10 00 11    mov  %l1, %o3
0x0D144    b0 06 20 01    inc  %i0
0x0D148    d0 4c 00 18    ldsb  [ %l0 + %i0 ], %o0
0x0D14C    d2 2a c0 0a    stb  %o1, [ %o3 + %o2 ]
0x0D150    d2 0c 00 18    ldub  [ %l0 + %i0 ], %o1
0x0D154    80 a2 20 0a    cmp  %o0, 0xa
0x0D158    02 80 00 05    be  0xd16c
0x0D15C    94 02 a0 01    inc  %o2
0x0D160    80 a2 20 00    cmp  %o0, 0
0x0D164    32 bf ff f9    bne,a   0xd148
0x0D168    b0 06 20 01    inc  %i0
0x0D16C    c0 2c 40 0a    clrb  [ %l1 + %o2 ]
0x0D170    7f ff ff ae    call  0xd028                           ! Convert final field to decimal.
0x0D174    90 10 00 11    mov  %l1, %o0
0x0D178    b0 06 20 01    inc  %i0
0x0D17C    d0 26 c0 00    st  %o0, [ %i3 ]
0x0D180    81 c7 e0 08    ret
0x0D184    81 e8 00 00    restore


! 0xD188: Read flash page-zero metadata marker
! Steps:
! 1. Read NAND page zero into RAM at 0x87800000.
! 2. Return the 32-bit word at page offset 0x1FC.

0x0D188    9d e3 bf 98    save  %sp, -104, %sp                   ! Reads flash page 0 into 0x87800000.
0x0D18C    21 21 e0 00    sethi  %hi(0x87800000), %l0
0x0D190    90 10 20 00    clr  %o0
0x0D194    7f ff ff 6c    call  0xcf44
0x0D198    92 10 00 10    mov  %l0, %o1
0x0D19C    f0 04 21 fc    ld  [ %l0 + 0x1fc ], %i0               ! Read marker at byte offset 0x1FC.
0x0D1A0    81 c7 e0 08    ret
0x0D1A4    81 e8 00 00    restore


! 0xD1A8: Initialize flash page mapping from DEAD marker
! Steps:
! 1. Reset mapping state and check the 0xDEADxxxx marker.
! 2. Load eight 512-byte pages into the mapping area; return status.

0x0D1A8    9d e3 bf 98    save  %sp, -104, %sp
0x0D1AC    13 21 e0 dc    sethi  %hi(0x87837000), %o1
0x0D1B0    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0D1B4    15 21 e0 dc    sethi  %hi(0x87837000), %o2
0x0D1B8    17 21 e0 dc    sethi  %hi(0x87837000), %o3
0x0D1BC    c0 32 61 a2    clrh  [ %o1 + 0x1a2 ]
0x0D1C0    c0 2a 21 a0    clrb  [ %o0 + 0x1a0 ]
0x0D1C4    c0 32 a1 a4    clrh  [ %o2 + 0x1a4 ]
0x0D1C8    7f ff ff f0    call  0xd188
0x0D1CC    c0 22 e1 a8    clr  [ %o3 + 0x1a8 ]
0x0D1D0    a0 10 00 08    mov  %o0, %l0
0x0D1D4    11 3f ff c0    sethi  %hi(0xffff0000), %o0            ! Mask upper half of marker for comparison.
0x0D1D8    90 0c 00 08    and  %l0, %o0, %o0
0x0D1DC    13 37 ab 40    sethi  %hi(0xdead0000), %o1
0x0D1E0    80 a2 00 09    cmp  %o0, %o1                          ! Check marker prefix 0xDEAD.
0x0D1E4    12 80 00 17    bne  0xd240
0x0D1E8    b0 10 20 01    mov  1, %i0
0x0D1EC    11 00 00 3f    sethi  %hi(0xfc00), %o0
0x0D1F0    90 12 23 ff    or  %o0, 0x3ff, %o0                    ! 0xffff
0x0D1F4    13 21 e0 dc    sethi  %hi(0x87837000), %o1
0x0D1F8    a0 0c 00 08    and  %l0, %o0, %l0                     ! Use low 16 marker bits as page-map count/offset input.
0x0D1FC    e2 02 60 04    ld  [ %o1 + 4 ], %l1
0x0D200    a1 2c 20 05    sll  %l0, 5, %l0                       ! Scale marker value by 32.
0x0D204    b0 10 20 00    clr  %i0
0x0D208    90 0e 20 ff    and  %i0, 0xff, %o0
0x0D20C    93 2a 20 09    sll  %o0, 9, %o1
0x0D210    90 04 00 08    add  %l0, %o0, %o0
0x0D214    7f ff ff 4c    call  0xcf44                           ! Read 512-byte flash page to mapped RAM destination.
0x0D218    92 04 40 09    add  %l1, %o1, %o1
0x0D21C    b0 06 20 01    inc  %i0
0x0D220    90 0e 20 ff    and  %i0, 0xff, %o0
0x0D224    80 a2 20 07    cmp  %o0, 7                            ! Loop over eight pages (0..7).
0x0D228    08 bf ff fa    bleu  0xd210
0x0D22C    93 2a 20 09    sll  %o0, 9, %o1
0x0D230    92 10 20 01    mov  1, %o1
0x0D234    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0D238    d2 22 20 c8    st  %o1, [ %o0 + 0xc8 ]                ! 0x878370c8  ! Mark page mapping initialized.
0x0D23C    b0 10 20 00    clr  %i0
0x0D240    81 c7 e0 08    ret
0x0D244    81 e8 00 00    restore


! 0xD248: Load kernel and initrd from NAND
! Steps:
! 1. Select flash image metadata and read its header into RAM.
! 2. Check the vm signature, parse kernel/initrd offsets and lengths.
! 3. Read kernel pages to 0x80004000 and initrd pages to 0x81000000.
! 4. Optionally apply hardware transformation and report errors.

0x0D248    9d e3 bf 88    save  %sp, -120, %sp
0x0D24C    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0D250    d2 4a 21 a0    ldsb  [ %o0 + 0x1a0 ], %o1             ! 0x878371a0
0x0D254    94 10 00 08    mov  %o0, %o2
0x0D258    a6 10 20 00    clr  %l3
0x0D25C    80 a2 60 00    cmp  %o1, 0
0x0D260    02 80 00 0c    be  0xd290
0x0D264    21 21 e0 40    sethi  %hi(0x87810000), %l0
0x0D268    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0D26C    d2 0a 23 72    ldub  [ %o0 + 0x372 ], %o1             ! 0x87837372  ! Read boot-selection state from RAM.
0x0D270    80 a2 60 00    cmp  %o1, 0
0x0D274    22 80 00 08    be,a   0xd294
0x0D278    11 21 e0 da    sethi  %hi(0x87836800), %o0
0x0D27C    11 21 e0 da    sethi  %hi(0x87836800), %o0
0x0D280    40 00 05 f6    call  0xea58
0x0D284    90 12 20 48    or  %o0, 0x48, %o0                     ! 0x87836848
0x0D288    10 80 00 07    b  0xd2a4
0x0D28C    90 10 28 00    mov  0x800, %o0
0x0D290    11 21 e0 da    sethi  %hi(0x87836800), %o0
0x0D294    c0 2a a1 a0    clrb  [ %o2 + 0x1a0 ]
0x0D298    40 00 05 f0    call  0xea58
0x0D29C    90 12 20 50    or  %o0, 0x50, %o0
0x0D2A0    90 10 28 00    mov  0x800, %o0
0x0D2A4    7f ff ff 28    call  0xcf44                           ! Read 0x800-byte header/metadata region.
0x0D2A8    13 21 e0 40    sethi  %hi(0x87810000), %o1
0x0D2AC    d0 0c 00 00    ldub  [ %l0 ], %o0
0x0D2B0    80 a2 20 76    cmp  %o0, 0x76                         ! Test first signature byte ASCII v.
0x0D2B4    12 80 00 07    bne  0xd2d0
0x0D2B8    11 21 e0 40    sethi  %hi(0x87810000), %o0
0x0D2BC    d0 0c 20 01    ldub  [ %l0 + 1 ], %o0
0x0D2C0    80 a2 20 6d    cmp  %o0, 0x6d                         ! Test second signature byte ASCII m.
0x0D2C4    02 80 00 18    be  0xd324
0x0D2C8    13 21 e0 da    sethi  %hi(0x87836800), %o1
0x0D2CC    11 21 e0 40    sethi  %hi(0x87810000), %o0
0x0D2D0    92 10 00 08    mov  %o0, %o1
0x0D2D4    7f ff fc 3d    call  0xc3c8                           ! Transform/validate 512-byte header through 0xC3C8.
0x0D2D8    94 10 22 00    mov  0x200, %o2
0x0D2DC    80 a2 20 00    cmp  %o0, 0
0x0D2E0    02 80 00 05    be  0xd2f4
0x0D2E4    a6 10 20 01    mov  1, %l3
0x0D2E8    90 10 20 01    mov  1, %o0
0x0D2EC    40 00 0a 02    call  0xfaf4
0x0D2F0    92 10 20 07    mov  7, %o1
0x0D2F4    d0 0c 00 00    ldub  [ %l0 ], %o0
0x0D2F8    80 a2 20 76    cmp  %o0, 0x76
0x0D2FC    12 80 00 07    bne  0xd318
0x0D300    90 10 20 01    mov  1, %o0
0x0D304    d0 0c 20 01    ldub  [ %l0 + 1 ], %o0
0x0D308    80 a2 20 6d    cmp  %o0, 0x6d
0x0D30C    02 80 00 06    be  0xd324
0x0D310    13 21 e0 da    sethi  %hi(0x87836800), %o1
0x0D314    90 10 20 01    mov  1, %o0
0x0D318    40 00 09 f7    call  0xfaf4
0x0D31C    92 10 20 05    mov  5, %o1
0x0D320    13 21 e0 da    sethi  %hi(0x87836800), %o1
0x0D324    94 07 bf f4    add  %fp, -12, %o2
0x0D328    96 07 bf f0    add  %fp, -16, %o3
0x0D32C    92 12 60 60    or  %o1, 0x60, %o1
0x0D330    7f ff ff 52    call  0xd078                           ! Parse first colon-delimited metadata record.
0x0D334    11 21 e0 40    sethi  %hi(0x87810000), %o0
0x0D338    13 21 e0 da    sethi  %hi(0x87836800), %o1
0x0D33C    92 12 60 70    or  %o1, 0x70, %o1                     ! 0x87836870
0x0D340    94 07 bf ec    add  %fp, -20, %o2
0x0D344    96 07 bf e8    add  %fp, -24, %o3
0x0D348    7f ff ff 4c    call  0xd078                           ! Parse second metadata record.
0x0D34C    90 04 00 08    add  %l0, %o0, %o0
0x0D350    d4 07 bf f0    ld  [ %fp + -16 ], %o2
0x0D354    11 21 e0 da    sethi  %hi(0x87836800), %o0
0x0D358    d2 07 bf e8    ld  [ %fp + -24 ], %o1
0x0D35C    94 02 a1 ff    add  %o2, 0x1ff, %o2                   ! Round length up to 512-byte page count.
0x0D360    92 02 61 ff    add  %o1, 0x1ff, %o1
0x0D364    93 32 60 09    srl  %o1, 9, %o1
0x0D368    95 32 a0 09    srl  %o2, 9, %o2
0x0D36C    d2 27 bf e8    st  %o1, [ %fp + -24 ]
0x0D370    90 12 20 80    or  %o0, 0x80, %o0
0x0D374    40 00 05 b9    call  0xea58
0x0D378    d4 27 bf f0    st  %o2, [ %fp + -16 ]
0x0D37C    13 21 e0 dc    sethi  %hi(0x87837000), %o1
0x0D380    d0 0a 63 b0    ldub  [ %o1 + 0x3b0 ], %o0             ! 0x878373b0
0x0D384    80 a2 20 00    cmp  %o0, 0
0x0D388    02 80 00 05    be  0xd39c
0x0D38C    a2 10 00 09    mov  %o1, %l1
0x0D390    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Conditional diagnostic/status output.
0x0D394    40 00 14 63    call  0x12520
0x0D398    90 12 20 88    or  %o0, 0x88, %o0                     ! 0x87836888
0x0D39C    d0 07 bf f0    ld  [ %fp + -16 ], %o0
0x0D3A0    a4 10 20 00    clr  %l2
0x0D3A4    80 a4 80 08    cmp  %l2, %o0
0x0D3A8    3a 80 00 19    bcc,a   0xd40c
0x0D3AC    11 21 e0 da    sethi  %hi(0x87836800), %o0
0x0D3B0    21 20 00 10    sethi  %hi(0x80004000), %l0            ! Kernel load destination 0x80004000.
0x0D3B4    d0 07 bf f4    ld  [ %fp + -12 ], %o0
0x0D3B8    92 10 00 10    mov  %l0, %o1
0x0D3BC    90 04 80 08    add  %l2, %o0, %o0
0x0D3C0    7f ff fe e1    call  0xcf44                           ! Read next NAND page into kernel RAM.
0x0D3C4    90 02 28 00    add  %o0, 0x800, %o0
0x0D3C8    80 8c e0 ff    btst  0xff, %l3
0x0D3CC    02 80 00 0a    be  0xd3f4
0x0D3D0    90 10 00 10    mov  %l0, %o0
0x0D3D4    92 10 00 10    mov  %l0, %o1
0x0D3D8    7f ff fb fc    call  0xc3c8                           ! Optional 512-byte post-processing.
0x0D3DC    94 10 22 00    mov  0x200, %o2
0x0D3E0    80 a2 20 00    cmp  %o0, 0
0x0D3E4    02 80 00 04    be  0xd3f4
0x0D3E8    90 10 20 01    mov  1, %o0
0x0D3EC    40 00 09 c2    call  0xfaf4
0x0D3F0    92 10 20 07    mov  7, %o1
0x0D3F4    d0 07 bf f0    ld  [ %fp + -16 ], %o0
0x0D3F8    a4 04 a0 01    inc  %l2
0x0D3FC    80 a4 80 08    cmp  %l2, %o0                          ! Advance destination by 512 bytes in branch delay slot.
0x0D400    0a bf ff ed    bcs  0xd3b4
0x0D404    a0 04 22 00    add  %l0, 0x200, %l0
0x0D408    11 21 e0 da    sethi  %hi(0x87836800), %o0
0x0D40C    40 00 05 93    call  0xea58
0x0D410    90 12 20 90    or  %o0, 0x90, %o0                     ! 0x87836890
0x0D414    d0 0c 63 b0    ldub  [ %l1 + 0x3b0 ], %o0
0x0D418    80 a2 20 00    cmp  %o0, 0
0x0D41C    02 80 00 04    be  0xd42c
0x0D420    11 21 e0 da    sethi  %hi(0x87836800), %o0
0x0D424    40 00 14 3f    call  0x12520
0x0D428    90 12 20 88    or  %o0, 0x88, %o0                     ! 0x87836888
0x0D42C    d0 07 bf e8    ld  [ %fp + -24 ], %o0
0x0D430    a4 10 20 00    clr  %l2
0x0D434    80 a4 80 08    cmp  %l2, %o0
0x0D438    1a 80 00 25    bcc  0xd4cc
0x0D43C    11 10 5d 51    sethi  %hi(0x41754400), %o0
0x0D440    a8 12 22 c0    or  %o0, 0x2c0, %l4                    ! 0x417546c0
0x0D444    21 20 40 00    sethi  %hi(0x81000000), %l0            ! Initrd load destination 0x81000000.
0x0D448    d0 07 bf ec    ld  [ %fp + -20 ], %o0
0x0D44C    92 10 00 10    mov  %l0, %o1
0x0D450    90 04 80 08    add  %l2, %o0, %o0                     ! Read next initrd page.
0x0D454    7f ff fe bc    call  0xcf44
0x0D458    90 02 28 00    add  %o0, 0x800, %o0
0x0D45C    80 a4 a0 00    cmp  %l2, 0
0x0D460    12 80 00 0b    bne  0xd48c
0x0D464    a2 0c e0 ff    and  %l3, 0xff, %l1
0x0D468    80 8c e0 ff    btst  0xff, %l3
0x0D46C    02 80 00 09    be  0xd490
0x0D470    80 a4 60 00    cmp  %l1, 0
0x0D474    d0 04 20 08    ld  [ %l0 + 8 ], %o0
0x0D478    80 a2 00 14    cmp  %o0, %l4                          ! Check 32-bit magic 0x417546C0 at initrd +8 (meaning not yet confirmed).
0x0D47C    02 80 00 05    be  0xd490
0x0D480    80 a4 60 00    cmp  %l1, 0
0x0D484    7f ff fb a8    call  0xc324
0x0D488    90 10 20 01    mov  1, %o0
0x0D48C    80 a4 60 00    cmp  %l1, 0
0x0D490    02 80 00 0a    be  0xd4b8
0x0D494    90 10 00 10    mov  %l0, %o0
0x0D498    92 10 00 10    mov  %l0, %o1                          ! Optional 512-byte post-processing.
0x0D49C    7f ff fb cb    call  0xc3c8
0x0D4A0    94 10 22 00    mov  0x200, %o2
0x0D4A4    80 a2 20 00    cmp  %o0, 0
0x0D4A8    02 80 00 04    be  0xd4b8
0x0D4AC    90 10 20 01    mov  1, %o0
0x0D4B0    40 00 09 91    call  0xfaf4
0x0D4B4    92 10 20 07    mov  7, %o1
0x0D4B8    d0 07 bf e8    ld  [ %fp + -24 ], %o0
0x0D4BC    a4 04 a0 01    inc  %l2
0x0D4C0    80 a4 80 08    cmp  %l2, %o0
0x0D4C4    0a bf ff e1    bcs  0xd448
0x0D4C8    a0 04 22 00    add  %l0, 0x200, %l0
0x0D4CC    7f ff fb 96    call  0xc324                           ! Finalize hardware state.
0x0D4D0    90 10 20 00    clr  %o0
0x0D4D4    81 c7 e0 08    ret
0x0D4D8    81 e8 00 00    restore


! 0xD4DC: Three-byte diagnostic/check field generator
! Steps:
! 1. Look up each input byte in a RAM table.
! 2. Accumulate bitwise parity/check values and encode a three-byte result.
! 3. A call with unusual encoding at 0xD540 needs independent verification.

0x0D4DC    9d e3 bf 98    save  %sp, -104, %sp
0x0D4E0    11 21 e0 da    sethi  %hi(0x87836800), %o0
0x0D4E4    86 12 20 98    or  %o0, 0x98, %g3                     ! 0x87836898
0x0D4E8    84 10 20 00    clr  %g2
0x0D4EC    98 10 20 00    clr  %o4
0x0D4F0    9a 10 20 00    clr  %o5
0x0D4F4    c0 2e 60 02    clrb  [ %i1 + 2 ]
0x0D4F8    c0 2e 60 01    clrb  [ %i1 + 1 ]
0x0D4FC    c0 2e 40 00    clrb  [ %i1 ]
0x0D500    96 10 20 00    clr  %o3
0x0D504    d0 0e 00 0b    ldub  [ %i0 + %o3 ], %o0
0x0D508    d4 08 c0 08    ldub  [ %g3 + %o0 ], %o2               ! Lookup indexed by input byte.
0x0D50C    92 0a a0 3f    and  %o2, 0x3f, %o1
0x0D510    a0 1b 40 09    xor  %o5, %o1, %l0
0x0D514    80 8a a0 40    btst  0x40, %o2                        ! Test table flag bit 0x40.
0x0D518    02 80 00 04    be  0xd528
0x0D51C    9a 10 00 10    mov  %l0, %o5
0x0D520    84 18 80 0b    xor  %g2, %o3, %g2
0x0D524    98 3b 00 0b    xnor  %o4, %o3, %o4
0x0D528    96 02 e0 01    inc  %o3
0x0D52C    80 a2 e0 ff    cmp  %o3, 0xff
0x0D530    24 bf ff f6    ble,a   0xd508                         ! Process 256 bytes (0 through 255).
0x0D534    d0 0e 00 0b    ldub  [ %i0 + %o3 ], %o0
0x0D538    90 0b 20 ff    and  %o4, 0xff, %o0
0x0D53C    92 08 a0 ff    and  %g2, 0xff, %o1
0x0D540    6a 1f 3e 28    call  0xa87dcde0                       ! Suspicious disassembly: call target 0xA87DCDE0; verify instruction encoding and execution context.
0x0D544    94 10 00 19    mov  %i1, %o2
0x0D548    d4 0e 40 00    ldub  [ %i1 ], %o2
0x0D54C    90 38 00 10    xnor  %g0, %l0, %o0
0x0D550    d2 0e 60 01    ldub  [ %i1 + 1 ], %o1
0x0D554    91 2a 20 02    sll  %o0, 2, %o0
0x0D558    94 38 00 0a    xnor  %g0, %o2, %o2
0x0D55C    92 38 00 09    xnor  %g0, %o1, %o1
0x0D560    90 12 20 03    or  %o0, 3, %o0
0x0D564    d0 2e 60 02    stb  %o0, [ %i1 + 2 ]                  ! Write three-byte check field.
0x0D568    d4 2e 40 00    stb  %o2, [ %i1 ]
0x0D56C    d2 2e 60 01    stb  %o1, [ %i1 + 1 ]
0x0D570    81 c7 e0 08    ret
0x0D574    81 e8 00 00    restore


! 0xD578: Three-byte syndrome comparison and correction
! Steps:
! 1. XOR two three-byte check fields.
! 2. If equal, increment success counter; otherwise inspect syndrome bits.
! 3. Attempt a single-bit correction and update diagnostic counters.
! 4. Emit serial diagnostics and report an error condition.

0x0D578    9d e3 bf 98    save  %sp, -104, %sp
0x0D57C    d2 0f 00 00    ldub  [ %i4 ], %o1
0x0D580    d0 0e c0 00    ldub  [ %i3 ], %o0
0x0D584    9e 1a 40 08    xor  %o1, %o0, %o7
0x0D588    d4 0f 20 01    ldub  [ %i4 + 1 ], %o2
0x0D58C    96 10 00 0f    mov  %o7, %o3
0x0D590    d0 0e e0 01    ldub  [ %i3 + 1 ], %o0
0x0D594    84 1a 80 08    xor  %o2, %o0, %g2
0x0D598    d2 0f 20 02    ldub  [ %i4 + 2 ], %o1
0x0D59C    94 13 c0 02    or  %o7, %g2, %o2
0x0D5A0    d0 0e e0 02    ldub  [ %i3 + 2 ], %o0
0x0D5A4    9a 10 00 02    mov  %g2, %o5
0x0D5A8    98 1a 40 08    xor  %o1, %o0, %o4
0x0D5AC    80 93 00 0a    orcc  %o4, %o2, %g0                    ! Compare XOR difference of three check bytes.
0x0D5B0    12 80 00 07    bne  0xd5cc
0x0D5B4    86 10 00 0c    mov  %o4, %g3
0x0D5B8    13 21 e0 dc    sethi  %hi(0x87837000), %o1
0x0D5BC    d0 02 61 a8    ld  [ %o1 + 0x1a8 ], %o0               ! 0x878371a8
0x0D5C0    90 02 20 01    inc  %o0                               ! Increment successful comparison counter.
0x0D5C4    10 80 00 9c    b  0xd834
0x0D5C8    d0 22 61 a8    st  %o0, [ %o1 + 0x1a8 ]
0x0D5CC    94 0a e0 ff    and  %o3, 0xff, %o2
0x0D5D0    92 0b 60 ff    and  %o5, 0xff, %o1
0x0D5D4    90 08 e0 ff    and  %g3, 0xff, %o0
0x0D5D8    a0 10 00 0a    mov  %o2, %l0
0x0D5DC    82 10 00 09    mov  %o1, %g1
0x0D5E0    88 10 00 08    mov  %o0, %g4
0x0D5E4    95 32 a0 01    srl  %o2, 1, %o2
0x0D5E8    94 1b c0 0a    xor  %o7, %o2, %o2
0x0D5EC    93 32 60 01    srl  %o1, 1, %o1
0x0D5F0    91 32 20 01    srl  %o0, 1, %o0
0x0D5F4    b8 0a a0 55    and  %o2, 0x55, %i4
0x0D5F8    92 18 80 09    xor  %g2, %o1, %o1
0x0D5FC    90 1b 00 08    xor  %o4, %o0, %o0
0x0D600    92 0a 60 55    and  %o1, 0x55, %o1
0x0D604    80 a7 20 55    cmp  %i4, 0x55                         ! Test syndrome bit pattern against 0x55.
0x0D608    12 80 00 41    bne  0xd70c
0x0D60C    94 0a 20 54    and  %o0, 0x54, %o2
0x0D610    80 a2 60 55    cmp  %o1, 0x55
0x0D614    12 80 00 3f    bne  0xd710
0x0D618    80 a4 20 00    cmp  %l0, 0
0x0D61C    80 a2 a0 54    cmp  %o2, 0x54
0x0D620    12 80 00 3c    bne  0xd710
0x0D624    80 a4 20 00    cmp  %l0, 0
0x0D628    b2 0e 60 ff    and  %i1, 0xff, %i1
0x0D62C    94 10 20 80    mov  0x80, %o2
0x0D630    98 10 20 00    clr  %o4
0x0D634    b8 10 20 80    mov  0x80, %i4
0x0D638    b6 10 20 00    clr  %i3
0x0D63C    23 21 e0 dc    sethi  %hi(0x87837000), %l1
0x0D640    25 21 e0 da    sethi  %hi(0x87836800), %l2
0x0D644    80 8a 80 0b    btst  %o2, %o3
0x0D648    32 80 00 02    bne,a   0xd650
0x0D64C    98 13 00 1c    or  %o4, %i4, %o4
0x0D650    b6 06 e0 01    inc  %i3
0x0D654    90 0f 20 ff    and  %i4, 0xff, %o0
0x0D658    92 0e e0 ff    and  %i3, 0xff, %o1
0x0D65C    b9 32 20 01    srl  %o0, 1, %i4
0x0D660    80 a2 60 03    cmp  %o1, 3
0x0D664    08 bf ff f8    bleu  0xd644
0x0D668    95 32 a0 02    srl  %o2, 2, %o2
0x0D66C    94 10 20 80    mov  0x80, %o2
0x0D670    b6 10 20 00    clr  %i3
0x0D674    80 8a 80 0d    btst  %o2, %o5
0x0D678    32 80 00 02    bne,a   0xd680
0x0D67C    98 13 00 1c    or  %o4, %i4, %o4
0x0D680    b6 06 e0 01    inc  %i3
0x0D684    90 0f 20 ff    and  %i4, 0xff, %o0
0x0D688    92 0e e0 ff    and  %i3, 0xff, %o1
0x0D68C    b9 32 20 01    srl  %o0, 1, %i4
0x0D690    80 a2 60 03    cmp  %o1, 3
0x0D694    08 bf ff f8    bleu  0xd674
0x0D698    95 32 a0 02    srl  %o2, 2, %o2
0x0D69C    a0 0b 20 ff    and  %o4, 0xff, %l0
0x0D6A0    96 10 20 00    clr  %o3
0x0D6A4    92 10 20 04    mov  4, %o1
0x0D6A8    94 10 20 80    mov  0x80, %o2
0x0D6AC    b6 10 20 00    clr  %i3
0x0D6B0    80 8a 80 03    btst  %o2, %g3
0x0D6B4    32 80 00 02    bne,a   0xd6bc
0x0D6B8    96 12 c0 09    or  %o3, %o1, %o3
0x0D6BC    b6 06 e0 01    inc  %i3
0x0D6C0    90 0e e0 ff    and  %i3, 0xff, %o0
0x0D6C4    80 a2 20 02    cmp  %o0, 2
0x0D6C8    95 32 a0 02    srl  %o2, 2, %o2
0x0D6CC    08 bf ff f9    bleu  0xd6b0
0x0D6D0    93 32 60 01    srl  %o1, 1, %o1
0x0D6D4    f8 0e 80 10    ldub  [ %i2 + %l0 ], %i4               ! Read byte at correction index.
0x0D6D8    92 10 20 01    mov  1, %o1
0x0D6DC    93 2a 40 0b    sll  %o1, %o3, %o1
0x0D6E0    92 1f 00 09    xor  %i4, %o1, %o1                     ! Flip selected bit in target buffer.
0x0D6E4    11 21 e0 da    sethi  %hi(0x87836800), %o0
0x0D6E8    90 12 21 98    or  %o0, 0x198, %o0                    ! 0x87836998
0x0D6EC    d2 2e 80 10    stb  %o1, [ %i2 + %l0 ]
0x0D6F0    40 00 04 da    call  0xea58
0x0D6F4    b8 10 00 09    mov  %o1, %i4
0x0D6F8    d0 14 61 a2    lduh  [ %l1 + 0x1a2 ], %o0             ! Increment corrected-error counter.
0x0D6FC    b6 10 20 00    clr  %i3
0x0D700    90 02 20 01    inc  %o0
0x0D704    10 80 00 34    b  0xd7d4
0x0D708    d0 34 61 a2    sth  %o0, [ %l1 + 0x1a2 ]
0x0D70C    80 a4 20 00    cmp  %l0, 0
0x0D710    b2 0e 60 ff    and  %i1, 0xff, %i1
0x0D714    b6 10 20 00    clr  %i3
0x0D718    02 80 00 0a    be  0xd740
0x0D71C    25 21 e0 da    sethi  %hi(0x87836800), %l2
0x0D720    80 8a e0 01    btst  1, %o3
0x0D724    32 80 00 02    bne,a   0xd72c
0x0D728    b6 06 e0 01    inc  %i3
0x0D72C    90 0a e0 ff    and  %o3, 0xff, %o0
0x0D730    97 32 20 01    srl  %o0, 1, %o3
0x0D734    80 a2 e0 00    cmp  %o3, 0
0x0D738    12 bf ff fb    bne  0xd724
0x0D73C    80 8a e0 01    btst  1, %o3
0x0D740    80 a0 60 00    cmp  %g1, 0
0x0D744    02 80 00 0b    be  0xd770
0x0D748    80 a1 20 00    cmp  %g4, 0
0x0D74C    80 8b 60 01    btst  1, %o5
0x0D750    32 80 00 02    bne,a   0xd758
0x0D754    b6 06 e0 01    inc  %i3
0x0D758    90 0b 60 ff    and  %o5, 0xff, %o0
0x0D75C    9b 32 20 01    srl  %o0, 1, %o5
0x0D760    80 a3 60 00    cmp  %o5, 0
0x0D764    12 bf ff fb    bne  0xd750
0x0D768    80 8b 60 01    btst  1, %o5
0x0D76C    80 a1 20 00    cmp  %g4, 0
0x0D770    02 80 00 0b    be  0xd79c
0x0D774    b4 0e e0 ff    and  %i3, 0xff, %i2
0x0D778    80 88 e0 01    btst  1, %g3
0x0D77C    32 80 00 02    bne,a   0xd784
0x0D780    b6 06 e0 01    inc  %i3
0x0D784    90 08 e0 ff    and  %g3, 0xff, %o0
0x0D788    87 32 20 01    srl  %o0, 1, %g3
0x0D78C    80 a0 e0 00    cmp  %g3, 0
0x0D790    12 bf ff fb    bne  0xd77c
0x0D794    80 88 e0 01    btst  1, %g3
0x0D798    b4 0e e0 ff    and  %i3, 0xff, %i2
0x0D79C    80 a6 a0 01    cmp  %i2, 1
0x0D7A0    12 80 00 0a    bne  0xd7c8
0x0D7A4    01 00 00 00    nop
0x0D7A8    40 00 04 ee    call  0xeb60                           ! Output diagnostic character I.
0x0D7AC    90 10 20 49    mov  0x49, %o0                         ! 0x49
0x0D7B0    13 21 e0 dc    sethi  %hi(0x87837000), %o1
0x0D7B4    d0 12 61 a4    lduh  [ %o1 + 0x1a4 ], %o0             ! 0x878371a4
0x0D7B8    a0 10 20 01    mov  1, %l0
0x0D7BC    90 02 20 01    inc  %o0
0x0D7C0    10 80 00 05    b  0xd7d4
0x0D7C4    d0 32 61 a4    sth  %o0, [ %o1 + 0x1a4 ]
0x0D7C8    40 00 04 e6    call  0xeb60                           ! Output diagnostic character B.
0x0D7CC    90 10 20 42    mov  0x42, %o0
0x0D7D0    a0 10 00 1a    mov  %i2, %l0
0x0D7D4    40 00 04 a1    call  0xea58                           ! Emit status values through UART helper routines.
0x0D7D8    90 14 a1 a0    or  %l2, 0x1a0, %o0
0x0D7DC    40 00 04 d8    call  0xeb3c
0x0D7E0    90 10 00 18    mov  %i0, %o0
0x0D7E4    40 00 04 df    call  0xeb60
0x0D7E8    90 10 20 20    mov  0x20, %o0
0x0D7EC    40 00 04 c4    call  0xeafc
0x0D7F0    90 10 00 19    mov  %i1, %o0
0x0D7F4    40 00 04 db    call  0xeb60
0x0D7F8    90 10 20 20    mov  0x20, %o0
0x0D7FC    40 00 04 c0    call  0xeafc
0x0D800    90 10 00 10    mov  %l0, %o0
0x0D804    40 00 04 d7    call  0xeb60
0x0D808    90 10 20 20    mov  0x20, %o0
0x0D80C    40 00 04 bc    call  0xeafc
0x0D810    90 0f 20 ff    and  %i4, 0xff, %o0
0x0D814    40 00 04 d3    call  0xeb60
0x0D818    90 10 20 0a    mov  0xa, %o0
0x0D81C    90 0e e0 ff    and  %i3, 0xff, %o0
0x0D820    80 a2 20 01    cmp  %o0, 1
0x0D824    08 80 00 04    bleu  0xd834
0x0D828    90 10 20 01    mov  1, %o0
0x0D82C    40 00 08 b2    call  0xfaf4
0x0D830    92 10 20 04    mov  4, %o1
0x0D834    81 c7 e0 08    ret
0x0D838    81 e8 00 00    restore


! 0xD83C: Hardware transmit helper
! Steps:
! 1. Program controller MMIO registers and transfer descriptors.
! 2. Poll hardware completion, capture status words and return error codes.

0x0D83C    9d e3 bf 98    save  %sp, -104, %sp                   ! Start MMIO send/transfer helper.
0x0D840    11 08 00 41    sethi  %hi(0x20010400), %o0            ! Controller status register 0x20010400.
0x0D844    e0 02 00 00    ld  [ %o0 ], %l0
0x0D848    19 00 00 04    sethi  %hi(0x1000), %o4
0x0D84C    80 8c 00 0c    btst  %l0, %o4
0x0D850    02 80 00 0b    be  0xd87c
0x0D854    96 10 00 08    mov  %o0, %o3
0x0D858    94 12 e0 20    or  %o3, 0x20, %o2                     ! Read controller FIFO at 0x20010420.
0x0D85C    d0 02 80 00    ld  [ %o2 ], %o0
0x0D860    d0 26 80 00    st  %o0, [ %i2 ]
0x0D864    d2 02 80 00    ld  [ %o2 ], %o1
0x0D868    d2 26 a0 04    st  %o1, [ %i2 + 4 ]
0x0D86C    e0 02 c0 00    ld  [ %o3 ], %l0
0x0D870    80 8c 00 0c    btst  %l0, %o4
0x0D874    12 bf ff fa    bne  0xd85c
0x0D878    01 00 00 00    nop
0x0D87C    19 08 00 41    sethi  %hi(0x20010400), %o4
0x0D880    d0 03 00 00    ld  [ %o4 ], %o0
0x0D884    17 08 00 00    sethi  %hi(0x20000000), %o3
0x0D888    80 8a 00 0b    btst  %o0, %o3
0x0D88C    12 80 00 0c    bne  0xd8bc
0x0D890    15 08 00 0a    sethi  %hi(0x20002800), %o2
0x0D894    94 12 a0 10    or  %o2, 0x10, %o2                     ! 0x20002810
0x0D898    90 10 20 0b    mov  0xb, %o0                          ! Write control commands to 0x20002810.
0x0D89C    13 00 00 20    sethi  %hi(0x8000), %o1
0x0D8A0    d0 22 80 00    st  %o0, [ %o2 ]
0x0D8A4    92 12 60 0b    or  %o1, 0xb, %o1
0x0D8A8    d2 22 80 00    st  %o1, [ %o2 ]
0x0D8AC    d0 03 00 00    ld  [ %o4 ], %o0
0x0D8B0    90 12 00 0b    or  %o0, %o3, %o0
0x0D8B4    d0 23 00 00    st  %o0, [ %o4 ]
0x0D8B8    15 08 00 0a    sethi  %hi(0x20002800), %o2
0x0D8BC    11 30 00 00    sethi  %hi(0xc0000000), %o0
0x0D8C0    90 06 00 08    add  %i0, %o0, %o0
0x0D8C4    96 12 a0 18    or  %o2, 0x18, %o3
0x0D8C8    d0 22 c0 00    st  %o0, [ %o3 ]                       ! Program DMA/control address register.
0x0D8CC    13 00 80 00    sethi  %hi(0x2000000), %o1
0x0D8D0    92 16 40 09    or  %i1, %o1, %o1
0x0D8D4    94 12 a0 1c    or  %o2, 0x1c, %o2
0x0D8D8    11 00 00 1d    sethi  %hi(0x7400), %o0
0x0D8DC    a4 12 21 30    or  %o0, 0x130, %l2                    ! 0x7530
0x0D8E0    d2 22 80 00    st  %o1, [ %o2 ]
0x0D8E4    b2 10 00 0c    mov  %o4, %i1
0x0D8E8    b0 10 20 00    clr  %i0
0x0D8EC    23 00 00 04    sethi  %hi(0x1000), %l1
0x0D8F0    b0 06 20 01    inc  %i0
0x0D8F4    e0 06 40 00    ld  [ %i1 ], %l0
0x0D8F8    80 a6 00 12    cmp  %i0, %l2
0x0D8FC    14 80 00 18    bg  0xd95c
0x0D900    01 00 00 00    nop
0x0D904    6a 1f 3a bf    call  0xa87dc400                       ! Suspicious call target 0xA87DC400; verify separately.
0x0D908    90 10 20 01    mov  1, %o0                            ! 0x1
0x0D90C    80 8c 00 11    btst  %l0, %l1
0x0D910    02 bf ff f9    be  0xd8f4
0x0D914    b0 06 20 01    inc  %i0
0x0D918    11 08 00 41    sethi  %hi(0x20010400), %o0
0x0D91C    90 12 20 20    or  %o0, 0x20, %o0                     ! 0x20010420
0x0D920    d8 02 00 00    ld  [ %o0 ], %o4                       ! Read transfer status words from FIFO.
0x0D924    13 00 20 00    sethi  %hi(0x800000), %o1
0x0D928    d8 26 80 00    st  %o4, [ %i2 ]
0x0D92C    d6 02 00 00    ld  [ %o0 ], %o3
0x0D930    80 8a c0 09    btst  %o3, %o1
0x0D934    02 80 00 1d    be  0xd9a8
0x0D938    d6 26 a0 04    st  %o3, [ %i2 + 4 ]
0x0D93C    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0D940    13 21 e0 dc    sethi  %hi(0x87837000), %o1
0x0D944    15 21 e0 dc    sethi  %hi(0x87837000), %o2
0x0D948    d6 22 23 3c    st  %o3, [ %o0 + 0x33c ]
0x0D94C    d8 22 63 38    st  %o4, [ %o1 + 0x338 ]
0x0D950    e0 22 a3 40    st  %l0, [ %o2 + 0x340 ]
0x0D954    10 80 00 16    b  0xd9ac
0x0D958    b0 10 20 00    clr  %i0
0x0D95C    d0 06 40 00    ld  [ %i1 ], %o0
0x0D960    17 08 00 00    sethi  %hi(0x20000000), %o3
0x0D964    90 12 00 0b    or  %o0, %o3, %o0
0x0D968    15 08 00 0a    sethi  %hi(0x20002800), %o2
0x0D96C    d0 26 40 00    st  %o0, [ %i1 ]
0x0D970    94 12 a0 10    or  %o2, 0x10, %o2
0x0D974    92 10 20 0b    mov  0xb, %o1
0x0D978    d2 22 80 00    st  %o1, [ %o2 ]
0x0D97C    d0 06 40 00    ld  [ %i1 ], %o0
0x0D980    13 00 00 20    sethi  %hi(0x8000), %o1
0x0D984    90 12 20 80    or  %o0, 0x80, %o0
0x0D988    d0 26 40 00    st  %o0, [ %i1 ]
0x0D98C    92 12 60 0b    or  %o1, 0xb, %o1
0x0D990    d2 22 80 00    st  %o1, [ %o2 ]
0x0D994    d0 06 40 00    ld  [ %i1 ], %o0
0x0D998    b0 10 3f ff    mov  -1, %i0                           ! Return -1 on timeout.
0x0D99C    90 12 00 0b    or  %o0, %o3, %o0
0x0D9A0    d0 26 40 00    st  %o0, [ %i1 ]
0x0D9A4    30 80 00 02    b,a   0xd9ac
0x0D9A8    b0 10 3f fd    mov  -3, %i0                           ! Return -3 on transfer-status failure.
0x0D9AC    81 c7 e0 08    ret
0x0D9B0    81 e8 00 00    restore


! 0xD9B4: Hardware receive and Ethernet packet parser
! Steps:
! 1. Configure MMIO receive engine and wait for completion.
! 2. Check Ethernet/ARP and IPv4 packet header fields.
! 3. Match destination addressing against RAM configuration.
! 4. Copy network metadata and return packet classification or error code.

0x0D9B4    9d e3 bf 90    save  %sp, -112, %sp                   ! Start hardware receive and packet decoder.
0x0D9B8    19 08 00 41    sethi  %hi(0x20010400), %o4
0x0D9BC    d0 03 00 00    ld  [ %o4 ], %o0
0x0D9C0    17 04 00 00    sethi  %hi(0x10000000), %o3
0x0D9C4    80 8a 00 0b    btst  %o0, %o3
0x0D9C8    12 80 00 11    bne  0xda0c
0x0D9CC    15 08 00 0a    sethi  %hi(0x20002800), %o2
0x0D9D0    92 10 20 0b    mov  0xb, %o1
0x0D9D4    d2 22 80 00    st  %o1, [ %o2 ]
0x0D9D8    d0 03 00 00    ld  [ %o4 ], %o0
0x0D9DC    13 00 00 20    sethi  %hi(0x8000), %o1
0x0D9E0    90 12 20 40    or  %o0, 0x40, %o0
0x0D9E4    d0 23 00 00    st  %o0, [ %o4 ]
0x0D9E8    92 12 60 0b    or  %o1, 0xb, %o1
0x0D9EC    d2 22 80 00    st  %o1, [ %o2 ]
0x0D9F0    d0 03 00 00    ld  [ %o4 ], %o0
0x0D9F4    90 0a 3f bf    and  %o0, -65, %o0
0x0D9F8    d0 23 00 00    st  %o0, [ %o4 ]
0x0D9FC    d2 03 00 00    ld  [ %o4 ], %o1
0x0DA00    92 12 40 0b    or  %o1, %o3, %o1
0x0DA04    d2 23 00 00    st  %o1, [ %o4 ]
0x0DA08    15 08 00 0a    sethi  %hi(0x20002800), %o2
0x0DA0C    11 30 00 00    sethi  %hi(0xc0000000), %o0
0x0DA10    90 06 00 08    add  %i0, %o0, %o0
0x0DA14    96 12 a0 08    or  %o2, 8, %o3
0x0DA18    d0 22 c0 00    st  %o0, [ %o3 ]
0x0DA1C    13 00 c0 00    sethi  %hi(0x3000000), %o1
0x0DA20    92 16 40 09    or  %i1, %o1, %o1
0x0DA24    94 12 a0 0c    or  %o2, 0xc, %o2
0x0DA28    11 00 00 1d    sethi  %hi(0x7400), %o0
0x0DA2C    a4 12 21 30    or  %o0, 0x130, %l2                    ! 0x7530
0x0DA30    d2 22 80 00    st  %o1, [ %o2 ]
0x0DA34    a2 10 00 0c    mov  %o4, %l1
0x0DA38    a0 10 20 00    clr  %l0
0x0DA3C    a0 04 20 01    inc  %l0
0x0DA40    f2 04 40 00    ld  [ %l1 ], %i1
0x0DA44    80 a4 00 12    cmp  %l0, %l2
0x0DA48    34 80 00 f1    bg,a   0xde0c
0x0DA4C    b0 10 3f ff    mov  -1, %i0
0x0DA50    6a 1f 3a 6c    call  0xa87dc400                       ! Suspicious call target 0xA87DC400; verify separately.
0x0DA54    90 10 20 01    mov  1, %o0
0x0DA58    80 8e 68 00    btst  0x800, %i1
0x0DA5C    22 bf ff f9    be,a   0xda40
0x0DA60    a0 04 20 01    inc  %l0
0x0DA64    11 08 00 41    sethi  %hi(0x20010400), %o0
0x0DA68    90 12 20 24    or  %o0, 0x24, %o0                     ! 0x20010424  ! Read receive FIFO at 0x20010424.
0x0DA6C    d2 02 00 00    ld  [ %o0 ], %o1
0x0DA70    15 00 20 00    sethi  %hi(0x800000), %o2
0x0DA74    d2 26 80 00    st  %o1, [ %i2 ]
0x0DA78    d0 02 00 00    ld  [ %o0 ], %o0
0x0DA7C    80 8a 40 0a    btst  %o1, %o2
0x0DA80    02 80 00 04    be  0xda90
0x0DA84    d0 26 a0 04    st  %o0, [ %i2 + 4 ]
0x0DA88    10 80 00 e1    b  0xde0c
0x0DA8C    b0 10 3f fe    mov  -2, %i0
0x0DA90    80 8a 00 0a    btst  %o0, %o2
0x0DA94    12 80 00 04    bne  0xdaa4
0x0DA98    a0 10 20 00    clr  %l0
0x0DA9C    10 80 00 dc    b  0xde0c
0x0DAA0    b0 10 3f fd    mov  -3, %i0
0x0DAA4    15 08 00 0a    sethi  %hi(0x20002800), %o2
0x0DAA8    13 00 05 dc    sethi  %hi(0x177000), %o1
0x0DAAC    11 00 00 10    sethi  %hi(0x4000), %o0
0x0DAB0    a0 04 20 01    inc  %l0
0x0DAB4    f2 02 80 00    ld  [ %o2 ], %i1
0x0DAB8    80 a4 00 09    cmp  %l0, %o1
0x0DABC    14 80 00 ab    bg  0xdd68
0x0DAC0    80 8e 40 08    btst  %i1, %o0
0x0DAC4    32 bf ff fc    bne,a   0xdab4
0x0DAC8    a0 04 20 01    inc  %l0
0x0DACC    d0 0e 00 00    ldub  [ %i0 ], %o0                     ! Inspect first packet byte (0xFF broadcast test).
0x0DAD0    80 a2 20 ff    cmp  %o0, 0xff
0x0DAD4    02 80 00 2a    be  0xdb7c
0x0DAD8    d8 0e 20 0c    ldub  [ %i0 + 0xc ], %o4
0x0DADC    80 a3 20 08    cmp  %o4, 8                            ! Check hardware address length 8.
0x0DAE0    12 80 00 28    bne  0xdb80
0x0DAE4    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DAE8    d0 0e 20 0d    ldub  [ %i0 + 0xd ], %o0
0x0DAEC    80 a2 20 06    cmp  %o0, 6                            ! Check protocol address length 6.
0x0DAF0    12 80 00 24    bne  0xdb80
0x0DAF4    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DAF8    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0DAFC    d4 0a 23 48    ldub  [ %o0 + 0x348 ], %o2             ! 0x87837348
0x0DB00    d2 0e 20 26    ldub  [ %i0 + 0x26 ], %o1              ! Compare destination IP bytes against configured address.
0x0DB04    80 a2 40 0a    cmp  %o1, %o2
0x0DB08    12 80 00 1d    bne  0xdb7c
0x0DB0C    96 12 23 48    or  %o0, 0x348, %o3
0x0DB10    d2 0e 20 27    ldub  [ %i0 + 0x27 ], %o1
0x0DB14    d0 0a e0 01    ldub  [ %o3 + 1 ], %o0
0x0DB18    80 a2 40 08    cmp  %o1, %o0
0x0DB1C    12 80 00 19    bne  0xdb80
0x0DB20    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DB24    d2 0e 20 28    ldub  [ %i0 + 0x28 ], %o1
0x0DB28    d0 0a e0 02    ldub  [ %o3 + 2 ], %o0
0x0DB2C    80 a2 40 08    cmp  %o1, %o0
0x0DB30    12 80 00 14    bne  0xdb80
0x0DB34    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DB38    d2 0a e0 03    ldub  [ %o3 + 3 ], %o1
0x0DB3C    d0 0e 20 29    ldub  [ %i0 + 0x29 ], %o0
0x0DB40    80 a2 00 09    cmp  %o0, %o1
0x0DB44    12 80 00 0f    bne  0xdb80
0x0DB48    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DB4C    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0DB50    94 12 23 58    or  %o0, 0x358, %o2                    ! 0x87837358
0x0DB54    96 10 20 00    clr  %o3
0x0DB58    90 02 c0 18    add  %o3, %i0, %o0                     ! Copy six address bytes from received packet.
0x0DB5C    d2 0a 20 16    ldub  [ %o0 + 0x16 ], %o1
0x0DB60    d2 2a 80 0b    stb  %o1, [ %o2 + %o3 ]
0x0DB64    96 02 e0 01    inc  %o3
0x0DB68    80 a2 e0 05    cmp  %o3, 5
0x0DB6C    04 bf ff fc    ble  0xdb5c
0x0DB70    90 02 c0 18    add  %o3, %i0, %o0
0x0DB74    10 80 00 a6    b  0xde0c
0x0DB78    b0 10 20 01    mov  1, %i0
0x0DB7C    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DB80    80 a2 20 08    cmp  %o0, 8
0x0DB84    12 80 00 7c    bne  0xdd74
0x0DB88    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DB8C    d0 0e 20 0d    ldub  [ %i0 + 0xd ], %o0
0x0DB90    80 a2 20 06    cmp  %o0, 6
0x0DB94    12 80 00 78    bne  0xdd74
0x0DB98    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DB9C    d0 0e 20 14    ldub  [ %i0 + 0x14 ], %o0              ! Check ARP opcode high byte 0.
0x0DBA0    80 a2 20 00    cmp  %o0, 0
0x0DBA4    12 80 00 74    bne  0xdd74
0x0DBA8    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DBAC    d0 0e 20 15    ldub  [ %i0 + 0x15 ], %o0              ! Check ARP opcode low byte 1 (request).
0x0DBB0    80 a2 20 01    cmp  %o0, 1
0x0DBB4    12 80 00 70    bne  0xdd74
0x0DBB8    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DBBC    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0DBC0    d4 0a 23 48    ldub  [ %o0 + 0x348 ], %o2             ! 0x87837348
0x0DBC4    d2 0e 20 26    ldub  [ %i0 + 0x26 ], %o1
0x0DBC8    80 a2 40 0a    cmp  %o1, %o2
0x0DBCC    12 80 00 69    bne  0xdd70
0x0DBD0    96 12 23 48    or  %o0, 0x348, %o3
0x0DBD4    d2 0e 20 27    ldub  [ %i0 + 0x27 ], %o1
0x0DBD8    d0 0a e0 01    ldub  [ %o3 + 1 ], %o0
0x0DBDC    80 a2 40 08    cmp  %o1, %o0
0x0DBE0    12 80 00 65    bne  0xdd74
0x0DBE4    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DBE8    d2 0e 20 28    ldub  [ %i0 + 0x28 ], %o1
0x0DBEC    d0 0a e0 02    ldub  [ %o3 + 2 ], %o0
0x0DBF0    80 a2 40 08    cmp  %o1, %o0
0x0DBF4    12 80 00 60    bne  0xdd74
0x0DBF8    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DBFC    d2 0a e0 03    ldub  [ %o3 + 3 ], %o1
0x0DC00    d0 0e 20 29    ldub  [ %i0 + 0x29 ], %o0
0x0DC04    80 a2 00 09    cmp  %o0, %o1
0x0DC08    12 80 00 5b    bne  0xdd74
0x0DC0C    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DC10    1b 21 e0 dc    sethi  %hi(0x87837000), %o5
0x0DC14    94 10 00 0d    mov  %o5, %o2
0x0DC18    96 10 20 00    clr  %o3
0x0DC1C    84 07 bf f0    add  %fp, -16, %g2
0x0DC20    d2 0e 00 0b    ldub  [ %i0 + %o3 ], %o1               ! Copy 42-byte packet header into output buffer.
0x0DC24    d0 02 a3 60    ld  [ %o2 + 0x360 ], %o0
0x0DC28    d2 2a 00 0b    stb  %o1, [ %o0 + %o3 ]
0x0DC2C    96 02 e0 01    inc  %o3
0x0DC30    80 a2 e0 2a    cmp  %o3, 0x2a
0x0DC34    26 bf ff fc    bl,a   0xdc24
0x0DC38    d2 0e 00 0b    ldub  [ %i0 + %o3 ], %o1
0x0DC3C    96 10 20 00    clr  %o3
0x0DC40    19 21 e0 dc    sethi  %hi(0x87837000), %o4
0x0DC44    90 02 c0 18    add  %o3, %i0, %o0                     ! Copy source MAC address from received packet.
0x0DC48    d4 0a 20 16    ldub  [ %o0 + 0x16 ], %o2
0x0DC4C    d2 03 23 60    ld  [ %o4 + 0x360 ], %o1
0x0DC50    d4 2a 40 0b    stb  %o2, [ %o1 + %o3 ]
0x0DC54    96 02 e0 01    inc  %o3
0x0DC58    80 a2 e0 05    cmp  %o3, 5
0x0DC5C    04 bf ff fb    ble  0xdc48
0x0DC60    90 02 c0 18    add  %o3, %i0, %o0
0x0DC64    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0DC68    98 12 20 20    or  %o0, 0x20, %o4                     ! 0x87837020
0x0DC6C    96 10 20 00    clr  %o3
0x0DC70    15 21 e0 dc    sethi  %hi(0x87837000), %o2
0x0DC74    d0 02 a3 60    ld  [ %o2 + 0x360 ], %o0               ! 0x87837360
0x0DC78    d2 0b 00 0b    ldub  [ %o4 + %o3 ], %o1
0x0DC7C    90 02 c0 08    add  %o3, %o0, %o0
0x0DC80    96 02 e0 01    inc  %o3
0x0DC84    80 a2 e0 05    cmp  %o3, 5
0x0DC88    04 bf ff fb    ble  0xdc74
0x0DC8C    d2 2a 20 06    stb  %o1, [ %o0 + 6 ]
0x0DC90    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0DC94    98 12 20 20    or  %o0, 0x20, %o4                     ! 0x87837020
0x0DC98    96 10 20 00    clr  %o3
0x0DC9C    15 21 e0 dc    sethi  %hi(0x87837000), %o2
0x0DCA0    d0 02 a3 60    ld  [ %o2 + 0x360 ], %o0               ! 0x87837360
0x0DCA4    d2 0b 00 0b    ldub  [ %o4 + %o3 ], %o1
0x0DCA8    90 02 c0 08    add  %o3, %o0, %o0
0x0DCAC    96 02 e0 01    inc  %o3
0x0DCB0    80 a2 e0 05    cmp  %o3, 5
0x0DCB4    04 bf ff fb    ble  0xdca0
0x0DCB8    d2 2a 20 16    stb  %o1, [ %o0 + 0x16 ]
0x0DCBC    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0DCC0    98 12 23 48    or  %o0, 0x348, %o4                    ! 0x87837348
0x0DCC4    96 10 20 00    clr  %o3
0x0DCC8    15 21 e0 dc    sethi  %hi(0x87837000), %o2
0x0DCCC    d0 02 a3 60    ld  [ %o2 + 0x360 ], %o0               ! 0x87837360
0x0DCD0    d2 0b 00 0b    ldub  [ %o4 + %o3 ], %o1
0x0DCD4    90 02 c0 08    add  %o3, %o0, %o0
0x0DCD8    96 02 e0 01    inc  %o3
0x0DCDC    80 a2 e0 03    cmp  %o3, 3
0x0DCE0    04 bf ff fb    ble  0xdccc
0x0DCE4    d2 2a 20 1c    stb  %o1, [ %o0 + 0x1c ]
0x0DCE8    96 10 20 00    clr  %o3
0x0DCEC    19 21 e0 dc    sethi  %hi(0x87837000), %o4
0x0DCF0    d0 03 23 60    ld  [ %o4 + 0x360 ], %o0               ! 0x87837360
0x0DCF4    92 02 c0 18    add  %o3, %i0, %o1
0x0DCF8    90 02 c0 08    add  %o3, %o0, %o0
0x0DCFC    d4 0a 60 16    ldub  [ %o1 + 0x16 ], %o2
0x0DD00    96 02 e0 01    inc  %o3
0x0DD04    80 a2 e0 05    cmp  %o3, 5
0x0DD08    04 bf ff fa    ble  0xdcf0
0x0DD0C    d4 2a 20 20    stb  %o2, [ %o0 + 0x20 ]
0x0DD10    96 10 20 00    clr  %o3
0x0DD14    19 21 e0 dc    sethi  %hi(0x87837000), %o4
0x0DD18    d0 03 23 60    ld  [ %o4 + 0x360 ], %o0               ! 0x87837360
0x0DD1C    92 02 c0 18    add  %o3, %i0, %o1
0x0DD20    90 02 c0 08    add  %o3, %o0, %o0
0x0DD24    d4 0a 60 1c    ldub  [ %o1 + 0x1c ], %o2
0x0DD28    96 02 e0 01    inc  %o3
0x0DD2C    80 a2 e0 03    cmp  %o3, 3
0x0DD30    04 bf ff fa    ble  0xdd18
0x0DD34    d4 2a 20 26    stb  %o2, [ %o0 + 0x26 ]
0x0DD38    d2 03 63 60    ld  [ %o5 + 0x360 ], %o1
0x0DD3C    90 10 20 02    mov  2, %o0
0x0DD40    d0 2a 60 15    stb  %o0, [ %o1 + 0x15 ]
0x0DD44    d0 03 63 60    ld  [ %o5 + 0x360 ], %o0
0x0DD48    94 10 00 02    mov  %g2, %o2                          ! Send 42-byte reply via hardware helper.
0x0DD4C    7f ff fe bc    call  0xd83c
0x0DD50    92 10 20 2a    mov  0x2a, %o1
0x0DD54    80 a2 20 00    cmp  %o0, 0
0x0DD58    12 80 00 2d    bne  0xde0c
0x0DD5C    b0 10 3f fb    mov  -5, %i0
0x0DD60    10 80 00 2b    b  0xde0c                              ! Return packet classification 2.
0x0DD64    b0 10 20 02    mov  2, %i0
0x0DD68    10 80 00 29    b  0xde0c
0x0DD6C    b0 10 3f fc    mov  -4, %i0
0x0DD70    90 0b 20 ff    and  %o4, 0xff, %o0
0x0DD74    80 a2 20 08    cmp  %o0, 8                            ! Fall through to alternative packet handling.
0x0DD78    32 80 00 25    bne,a   0xde0c
0x0DD7C    b0 10 20 00    clr  %i0
0x0DD80    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0DD84    d4 0a 23 48    ldub  [ %o0 + 0x348 ], %o2             ! 0x87837348
0x0DD88    d2 0e 20 1e    ldub  [ %i0 + 0x1e ], %o1
0x0DD8C    80 a2 40 0a    cmp  %o1, %o2
0x0DD90    12 80 00 1e    bne  0xde08
0x0DD94    96 12 23 48    or  %o0, 0x348, %o3
0x0DD98    d2 0e 20 1f    ldub  [ %i0 + 0x1f ], %o1
0x0DD9C    d0 0a e0 01    ldub  [ %o3 + 1 ], %o0
0x0DDA0    80 a2 40 08    cmp  %o1, %o0
0x0DDA4    32 80 00 1a    bne,a   0xde0c
0x0DDA8    b0 10 20 00    clr  %i0
0x0DDAC    d2 0e 20 20    ldub  [ %i0 + 0x20 ], %o1
0x0DDB0    d0 0a e0 02    ldub  [ %o3 + 2 ], %o0
0x0DDB4    80 a2 40 08    cmp  %o1, %o0
0x0DDB8    32 80 00 15    bne,a   0xde0c
0x0DDBC    b0 10 20 00    clr  %i0
0x0DDC0    d2 0a e0 03    ldub  [ %o3 + 3 ], %o1
0x0DDC4    d0 0e 20 21    ldub  [ %i0 + 0x21 ], %o0
0x0DDC8    80 a2 00 09    cmp  %o0, %o1
0x0DDCC    32 80 00 10    bne,a   0xde0c
0x0DDD0    b0 10 20 00    clr  %i0
0x0DDD4    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0DDD8    d4 02 20 28    ld  [ %o0 + 0x28 ], %o2                ! 0x87837028  ! Compare two bytes against configured port/address field.
0x0DDDC    d2 0e 20 24    ldub  [ %i0 + 0x24 ], %o1
0x0DDE0    91 32 a0 08    srl  %o2, 8, %o0
0x0DDE4    90 0a 20 ff    and  %o0, 0xff, %o0
0x0DDE8    80 a2 40 08    cmp  %o1, %o0
0x0DDEC    32 80 00 08    bne,a   0xde0c
0x0DDF0    b0 10 20 00    clr  %i0
0x0DDF4    d2 0e 20 25    ldub  [ %i0 + 0x25 ], %o1
0x0DDF8    90 0a a0 ff    and  %o2, 0xff, %o0
0x0DDFC    80 a2 40 08    cmp  %o1, %o0
0x0DE00    02 80 00 03    be  0xde0c
0x0DE04    b0 10 20 03    mov  3, %i0                            ! Return classification 3 (delay slot).
0x0DE08    b0 10 20 00    clr  %i0
0x0DE0C    81 c7 e0 08    ret
0x0DE10    81 e8 00 00    restore


! 0xDE14: Dotted-decimal IPv4 address parser
! Steps:
! 1. Convert decimal octets separated by dots into output bytes.

0x0DE14    98 10 20 00    clr  %o4                               ! Start dotted-decimal address conversion.
0x0DE18    96 10 20 00    clr  %o3
0x0DE1C    c6 4a 40 00    ldsb  [ %o1 ], %g3
0x0DE20    80 a0 e0 2e    cmp  %g3, 0x2e                         ! Dot separator check.
0x0DE24    02 80 00 06    be  0xde3c
0x0DE28    c4 0a 40 00    ldub  [ %o1 ], %g2
0x0DE2C    84 00 bf d0    add  %g2, -48, %g2
0x0DE30    80 a0 e0 00    cmp  %g3, 0
0x0DE34    12 80 00 06    bne  0xde4c
0x0DE38    94 08 a0 ff    and  %g2, 0xff, %o2
0x0DE3C    d6 2a 00 0c    stb  %o3, [ %o0 + %o4 ]
0x0DE40    98 03 20 01    inc  %o4
0x0DE44    10 80 00 09    b  0xde68
0x0DE48    96 10 20 00    clr  %o3
0x0DE4C    85 2a e0 03    sll  %o3, 3, %g2                       ! Accumulate decimal octet * 10 + digit.
0x0DE50    84 00 80 0b    add  %g2, %o3, %g2
0x0DE54    84 00 80 0b    add  %g2, %o3, %g2
0x0DE58    80 a2 a0 09    cmp  %o2, 9
0x0DE5C    18 80 00 03    bgu  0xde68
0x0DE60    84 00 bf d0    add  %g2, -48, %g2
0x0DE64    96 00 80 03    add  %g2, %g3, %o3
0x0DE68    c4 4a 40 00    ldsb  [ %o1 ], %g2
0x0DE6C    80 a0 a0 00    cmp  %g2, 0
0x0DE70    12 bf ff eb    bne  0xde1c
0x0DE74    92 02 60 01    inc  %o1
0x0DE78    81 c3 e0 08    retl
0x0DE7C    01 00 00 00    nop


! 0xDE80: Colon-separated hexadecimal MAC address parser
! Steps:
! 1. Convert pairs of hex digits separated by colons into output bytes.

0x0DE80    88 10 20 00    clr  %g4                               ! 0x0  ! Start MAC-address parser.
0x0DE84    82 10 20 00    clr  %g1
0x0DE88    d6 4a 40 00    ldsb  [ %o1 ], %o3
0x0DE8C    80 a2 e0 3a    cmp  %o3, 0x3a                         ! Colon separator check.
0x0DE90    02 80 00 06    be  0xdea8
0x0DE94    d4 0a 40 00    ldub  [ %o1 ], %o2
0x0DE98    84 02 bf d0    add  %o2, -48, %g2
0x0DE9C    80 a2 e0 00    cmp  %o3, 0
0x0DEA0    12 80 00 06    bne  0xdeb8
0x0DEA4    98 08 a0 ff    and  %g2, 0xff, %o4
0x0DEA8    c2 2a 00 04    stb  %g1, [ %o0 + %g4 ]
0x0DEAC    88 01 20 01    inc  %g4
0x0DEB0    10 80 00 17    b  0xdf0c
0x0DEB4    82 10 20 00    clr  %g1
0x0DEB8    85 28 60 04    sll  %g1, 4, %g2                       ! Accumulate hexadecimal nibble.
0x0DEBC    86 02 bf 9f    add  %o2, -97, %g3
0x0DEC0    84 00 bf d0    add  %g2, -48, %g2
0x0DEC4    80 a3 20 09    cmp  %o4, 9
0x0DEC8    18 80 00 04    bgu  0xded8
0x0DECC    9a 08 e0 ff    and  %g3, 0xff, %o5
0x0DED0    10 80 00 0f    b  0xdf0c
0x0DED4    82 00 80 0b    add  %g2, %o3, %g1
0x0DED8    85 28 60 04    sll  %g1, 4, %g2
0x0DEDC    86 02 bf bf    add  %o2, -65, %g3
0x0DEE0    84 00 80 0b    add  %g2, %o3, %g2
0x0DEE4    80 a3 60 05    cmp  %o5, 5
0x0DEE8    18 80 00 04    bgu  0xdef8
0x0DEEC    86 08 e0 ff    and  %g3, 0xff, %g3
0x0DEF0    10 80 00 07    b  0xdf0c
0x0DEF4    82 00 bf a9    add  %g2, -87, %g1
0x0DEF8    85 28 60 04    sll  %g1, 4, %g2
0x0DEFC    80 a0 e0 05    cmp  %g3, 5
0x0DF00    18 80 00 03    bgu  0xdf0c
0x0DF04    84 00 80 0b    add  %g2, %o3, %g2
0x0DF08    82 00 bf c9    add  %g2, -55, %g1
0x0DF0C    c4 4a 40 00    ldsb  [ %o1 ], %g2
0x0DF10    80 a0 a0 00    cmp  %g2, 0
0x0DF14    12 bf ff dd    bne  0xde88
0x0DF18    92 02 60 01    inc  %o1
0x0DF1C    81 c3 e0 08    retl
0x0DF20    01 00 00 00    nop


! 0xDF24: Build outgoing network frame (partial; continues at 0xE000)
! Steps:
! 1. Copy Ethernet/IP header templates into the frame buffer.
! 2. Fill MAC and IP address fields from firmware globals.
! 3. The function continues beyond the supplied disassembly.

0x0DF24    9d e3 bf 88    save  %sp, -120, %sp                   ! Start network frame construction; incomplete in this excerpt.
0x0DF28    a8 10 20 00    clr  %l4
0x0DF2C    80 a5 00 18    cmp  %l4, %i0
0x0DF30    36 80 00 64    bge,a   0xe0c0
0x0DF34    b0 10 20 02    mov  2, %i0
0x0DF38    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0DF3C    ac 12 20 40    or  %o0, 0x40, %l6                     ! 0x87837040
0x0DF40    27 21 e0 dc    sethi  %hi(0x87837000), %l3
0x0DF44    aa 07 bf f0    add  %fp, -16, %l5
0x0DF48    94 10 20 00    clr  %o2                               ! Copy 42-byte header template.
0x0DF4C    d2 0d 80 0a    ldub  [ %l6 + %o2 ], %o1
0x0DF50    d0 04 e3 60    ld  [ %l3 + 0x360 ], %o0
0x0DF54    d2 2a 00 0a    stb  %o1, [ %o0 + %o2 ]
0x0DF58    94 02 a0 01    inc  %o2
0x0DF5C    80 a2 a0 2a    cmp  %o2, 0x2a
0x0DF60    26 bf ff fc    bl,a   0xdf50
0x0DF64    d2 0d 80 0a    ldub  [ %l6 + %o2 ], %o1
0x0DF68    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0DF6C    98 12 20 20    or  %o0, 0x20, %o4                     ! 0x87837020
0x0DF70    94 10 20 00    clr  %o2
0x0DF74    17 21 e0 dc    sethi  %hi(0x87837000), %o3
0x0DF78    d0 02 e3 60    ld  [ %o3 + 0x360 ], %o0               ! 0x87837360  ! Fill destination MAC bytes.
0x0DF7C    d2 0b 00 0a    ldub  [ %o4 + %o2 ], %o1
0x0DF80    90 02 80 08    add  %o2, %o0, %o0
0x0DF84    94 02 a0 01    inc  %o2
0x0DF88    80 a2 a0 05    cmp  %o2, 5
0x0DF8C    04 bf ff fb    ble  0xdf78
0x0DF90    d2 2a 20 06    stb  %o1, [ %o0 + 6 ]
0x0DF94    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0DF98    98 12 20 20    or  %o0, 0x20, %o4                     ! 0x87837020
0x0DF9C    94 10 20 00    clr  %o2
0x0DFA0    17 21 e0 dc    sethi  %hi(0x87837000), %o3
0x0DFA4    d0 02 e3 60    ld  [ %o3 + 0x360 ], %o0               ! 0x87837360  ! Fill source MAC bytes.
0x0DFA8    d2 0b 00 0a    ldub  [ %o4 + %o2 ], %o1
0x0DFAC    90 02 80 08    add  %o2, %o0, %o0
0x0DFB0    94 02 a0 01    inc  %o2
0x0DFB4    80 a2 a0 05    cmp  %o2, 5
0x0DFB8    04 bf ff fb    ble  0xdfa4
0x0DFBC    d2 2a 20 16    stb  %o1, [ %o0 + 0x16 ]
0x0DFC0    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0DFC4    98 12 23 48    or  %o0, 0x348, %o4                    ! 0x87837348
0x0DFC8    94 10 20 00    clr  %o2
0x0DFCC    17 21 e0 dc    sethi  %hi(0x87837000), %o3
0x0DFD0    d0 02 e3 60    ld  [ %o3 + 0x360 ], %o0               ! 0x87837360  ! Fill four destination address bytes.
0x0DFD4    d2 0b 00 0a    ldub  [ %o4 + %o2 ], %o1
0x0DFD8    90 02 80 08    add  %o2, %o0, %o0
0x0DFDC    94 02 a0 01    inc  %o2
0x0DFE0    80 a2 a0 03    cmp  %o2, 3
0x0DFE4    04 bf ff fb    ble  0xdfd0
0x0DFE8    d2 2a 20 1c    stb  %o1, [ %o0 + 0x1c ]
0x0DFEC    11 21 e0 dc    sethi  %hi(0x87837000), %o0
0x0DFF0    98 12 23 50    or  %o0, 0x350, %o4                    ! 0x87837350
0x0DFF4    94 10 20 00    clr  %o2
0x0DFF8    17 21 e0 dc    sethi  %hi(0x87837000), %o3
0x0DFFC    d0 02 e3 60    ld  [ %o3 + 0x360 ], %o0               ! 0x87837360  ! More frame construction follows at 0xE000.
0x0E000    d2 0b 00 0a    ldub  [ %o4 + %o2 ], %o1
0x0E004    90 02 80 08    add  %o2, %o0, %o0
0x0E008    94 02 a0 01    inc  %o2
0x0E00C    80 a2 a0 03    cmp  %o2, 3
0x0E010    04 bf ff fb    ble  0xdffc                            ! Conditional/control branch; inspect delay slot.
0x0E014    d2 2a 20 26    stb  %o1, [ %o0 + 0x26 ]
0x0E018    94 10 20 00    clr  %o2
0x0E01C    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x0E020    d0 02 63 64    ld  [ %o1 + 0x364 ], %o0               ! 0x87837364
0x0E024    c0 2a 00 0a    clrb  [ %o0 + %o2 ]
0x0E028    94 02 a0 01    inc  %o2
0x0E02C    80 a2 a0 2a    cmp  %o2, 0x2a
0x0E030    06 bf ff fd    bl  0xe024                             ! Conditional/control branch; inspect delay slot.
0x0E034    d0 02 63 64    ld  [ %o1 + 0x364 ], %o0
0x0E038    d0 04 e3 60    ld  [ %l3 + 0x360 ], %o0
0x0E03C    92 10 20 2a    mov  0x2a, %o1
0x0E040    7f ff fd ff    call  0xd83c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E044    94 10 00 15    mov  %l5, %o2
0x0E048    80 a2 20 00    cmp  %o0, 0
0x0E04C    32 80 00 19    bne,a   0xe0b0                         ! Conditional/control branch; inspect delay slot.
0x0E050    a8 05 20 01    inc  %l4
0x0E054    d0 04 e3 60    ld  [ %l3 + 0x360 ], %o0
0x0E058    92 10 20 2a    mov  0x2a, %o1
0x0E05C    7f ff fd f8    call  0xd83c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E060    94 10 00 15    mov  %l5, %o2
0x0E064    80 a2 20 00    cmp  %o0, 0
0x0E068    32 80 00 12    bne,a   0xe0b0                         ! Conditional/control branch; inspect delay slot.
0x0E06C    a8 05 20 01    inc  %l4
0x0E070    a0 10 20 01    mov  1, %l0
0x0E074    25 21 e0 dc    sethi  %hi(0x87837000), %l2            ! Build high part of constant/address.
0x0E078    a2 07 bf e8    add  %fp, -24, %l1
0x0E07C    d0 04 a3 64    ld  [ %l2 + 0x364 ], %o0
0x0E080    92 10 28 00    mov  0x800, %o1
0x0E084    7f ff fe 4c    call  0xd9b4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E088    94 10 00 11    mov  %l1, %o2
0x0E08C    80 a2 20 01    cmp  %o0, 1
0x0E090    12 80 00 04    bne  0xe0a0                            ! Conditional/control branch; inspect delay slot.
0x0E094    90 10 00 10    mov  %l0, %o0
0x0E098    10 80 00 0a    b  0xe0c0                              ! Conditional/control branch; inspect delay slot.
0x0E09C    b0 10 20 00    clr  %i0
0x0E0A0    80 a2 20 20    cmp  %o0, 0x20
0x0E0A4    04 bf ff f6    ble  0xe07c                            ! Conditional/control branch; inspect delay slot.
0x0E0A8    a0 04 20 01    inc  %l0
0x0E0AC    a8 05 20 01    inc  %l4
0x0E0B0    80 a5 00 18    cmp  %l4, %i0
0x0E0B4    06 bf ff a6    bl  0xdf4c                             ! Conditional/control branch; inspect delay slot.
0x0E0B8    94 10 20 00    clr  %o2
0x0E0BC    b0 10 20 02    mov  2, %i0
0x0E0C0    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0E0C4    81 e8 00 00    restore                                ! Restore previous register window.
0x0E0C8    9d e3 bf 88    save  %sp, -120, %sp                   ! Enter register window; allocate stack frame.
0x0E0CC    19 21 e0 dc    sethi  %hi(0x87837000), %o4            ! Build high part of constant/address.
0x0E0D0    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0E0D4    9a 12 20 80    or  %o0, 0x80, %o5                     ! 0x87837080
0x0E0D8    94 10 00 0c    mov  %o4, %o2
0x0E0DC    96 10 20 00    clr  %o3
0x0E0E0    d2 0b 40 0b    ldub  [ %o5 + %o3 ], %o1
0x0E0E4    d0 02 a3 60    ld  [ %o2 + 0x360 ], %o0
0x0E0E8    d2 2a 00 0b    stb  %o1, [ %o0 + %o3 ]
0x0E0EC    96 02 e0 01    inc  %o3
0x0E0F0    80 a2 e0 29    cmp  %o3, 0x29
0x0E0F4    24 bf ff fc    ble,a   0xe0e4                         ! Conditional/control branch; inspect delay slot.
0x0E0F8    d2 0b 40 0b    ldub  [ %o5 + %o3 ], %o1
0x0E0FC    96 10 20 00    clr  %o3
0x0E100    80 a2 c0 1b    cmp  %o3, %i3
0x0E104    9a 06 e0 08    add  %i3, 8, %o5
0x0E108    85 3e a0 08    sra  %i2, 8, %g2
0x0E10C    9f 3e 60 08    sra  %i1, 8, %o7
0x0E110    82 06 e0 1c    add  %i3, 0x1c, %g1
0x0E114    16 80 00 0a    bge  0xe13c                            ! Conditional/control branch; inspect delay slot.
0x0E118    88 0f 20 01    and  %i4, 1, %g4
0x0E11C    15 21 e0 dc    sethi  %hi(0x87837000), %o2            ! Build high part of constant/address.
0x0E120    d0 02 a3 60    ld  [ %o2 + 0x360 ], %o0               ! 0x87837360
0x0E124    d2 0e 00 0b    ldub  [ %i0 + %o3 ], %o1
0x0E128    90 02 c0 08    add  %o3, %o0, %o0
0x0E12C    96 02 e0 01    inc  %o3
0x0E130    80 a2 c0 1b    cmp  %o3, %i3
0x0E134    06 bf ff fb    bl  0xe120                             ! Conditional/control branch; inspect delay slot.
0x0E138    d2 2a 20 2a    stb  %o1, [ %o0 + 0x2a ]
0x0E13C    d2 03 23 60    ld  [ %o4 + 0x360 ], %o1
0x0E140    91 3b 60 08    sra  %o5, 8, %o0
0x0E144    d0 2a 60 26    stb  %o0, [ %o1 + 0x26 ]
0x0E148    d4 03 23 60    ld  [ %o4 + 0x360 ], %o2
0x0E14C    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x0E150    da 2a a0 27    stb  %o5, [ %o2 + 0x27 ]
0x0E154    d0 03 23 60    ld  [ %o4 + 0x360 ], %o0
0x0E158    86 12 63 50    or  %o1, 0x350, %g3
0x0E15C    c4 2a 20 24    stb  %g2, [ %o0 + 0x24 ]
0x0E160    d2 03 23 60    ld  [ %o4 + 0x360 ], %o1
0x0E164    96 10 20 00    clr  %o3
0x0E168    f4 2a 60 25    stb  %i2, [ %o1 + 0x25 ]
0x0E16C    d4 03 23 60    ld  [ %o4 + 0x360 ], %o2
0x0E170    9a 10 00 0c    mov  %o4, %o5
0x0E174    de 2a a0 22    stb  %o7, [ %o2 + 0x22 ]
0x0E178    d0 03 23 60    ld  [ %o4 + 0x360 ], %o0
0x0E17C    f2 2a 20 23    stb  %i1, [ %o0 + 0x23 ]
0x0E180    d0 03 63 60    ld  [ %o5 + 0x360 ], %o0
0x0E184    d2 08 c0 0b    ldub  [ %g3 + %o3 ], %o1
0x0E188    90 02 c0 08    add  %o3, %o0, %o0
0x0E18C    96 02 e0 01    inc  %o3
0x0E190    80 a2 e0 03    cmp  %o3, 3
0x0E194    04 bf ff fb    ble  0xe180                            ! Conditional/control branch; inspect delay slot.
0x0E198    d2 2a 20 1e    stb  %o1, [ %o0 + 0x1e ]
0x0E19C    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0E1A0    9a 12 23 48    or  %o0, 0x348, %o5                    ! 0x87837348
0x0E1A4    96 10 20 00    clr  %o3
0x0E1A8    15 21 e0 dc    sethi  %hi(0x87837000), %o2            ! Build high part of constant/address.
0x0E1AC    d0 02 a3 60    ld  [ %o2 + 0x360 ], %o0               ! 0x87837360
0x0E1B0    d2 0b 40 0b    ldub  [ %o5 + %o3 ], %o1
0x0E1B4    90 02 c0 08    add  %o3, %o0, %o0
0x0E1B8    96 02 e0 01    inc  %o3
0x0E1BC    80 a2 e0 03    cmp  %o3, 3
0x0E1C0    04 bf ff fb    ble  0xe1ac                            ! Conditional/control branch; inspect delay slot.
0x0E1C4    d2 2a 20 1a    stb  %o1, [ %o0 + 0x1a ]
0x0E1C8    d2 03 23 60    ld  [ %o4 + 0x360 ], %o1
0x0E1CC    91 38 60 08    sra  %g1, 8, %o0
0x0E1D0    d0 2a 60 10    stb  %o0, [ %o1 + 0x10 ]
0x0E1D4    d4 03 23 60    ld  [ %o4 + 0x360 ], %o2
0x0E1D8    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0E1DC    c2 2a a0 11    stb  %g1, [ %o2 + 0x11 ]
0x0E1E0    9a 12 23 58    or  %o0, 0x358, %o5
0x0E1E4    96 10 20 00    clr  %o3
0x0E1E8    94 10 00 0c    mov  %o4, %o2
0x0E1EC    d2 0b 40 0b    ldub  [ %o5 + %o3 ], %o1
0x0E1F0    d0 02 a3 60    ld  [ %o2 + 0x360 ], %o0
0x0E1F4    d2 2a 00 0b    stb  %o1, [ %o0 + %o3 ]
0x0E1F8    96 02 e0 01    inc  %o3
0x0E1FC    80 a2 e0 05    cmp  %o3, 5
0x0E200    24 bf ff fc    ble,a   0xe1f0                         ! Conditional/control branch; inspect delay slot.
0x0E204    d2 0b 40 0b    ldub  [ %o5 + %o3 ], %o1
0x0E208    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0E20C    9a 12 20 20    or  %o0, 0x20, %o5                     ! 0x87837020
0x0E210    96 10 20 00    clr  %o3
0x0E214    15 21 e0 dc    sethi  %hi(0x87837000), %o2            ! Build high part of constant/address.
0x0E218    d0 02 a3 60    ld  [ %o2 + 0x360 ], %o0               ! 0x87837360
0x0E21C    d2 0b 40 0b    ldub  [ %o5 + %o3 ], %o1
0x0E220    90 02 c0 08    add  %o3, %o0, %o0
0x0E224    96 02 e0 01    inc  %o3
0x0E228    80 a2 e0 05    cmp  %o3, 5
0x0E22C    04 bf ff fb    ble  0xe218                            ! Conditional/control branch; inspect delay slot.
0x0E230    d2 2a 20 06    stb  %o1, [ %o0 + 6 ]
0x0E234    80 a1 20 00    cmp  %g4, 0
0x0E238    12 80 00 09    bne  0xe25c                            ! Conditional/control branch; inspect delay slot.
0x0E23C    80 8f 20 02    btst  2, %i4
0x0E240    d0 03 23 60    ld  [ %o4 + 0x360 ], %o0
0x0E244    92 06 e0 2a    add  %i3, 0x2a, %o1
0x0E248    7f ff fd 7d    call  0xd83c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E24C    94 07 bf f0    add  %fp, -16, %o2
0x0E250    80 a0 00 08    cmp  %g0, %o0
0x0E254    10 80 00 1b    b  0xe2c0                              ! Conditional/control branch; inspect delay slot.
0x0E258    b0 40 20 00    addx  %g0, 0, %i0
0x0E25C    02 80 00 0b    be  0xe288                             ! Conditional/control branch; inspect delay slot.
0x0E260    d0 03 23 60    ld  [ %o4 + 0x360 ], %o0
0x0E264    92 06 e0 2a    add  %i3, 0x2a, %o1
0x0E268    7f ff fd 75    call  0xd83c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E26C    94 07 bf f0    add  %fp, -16, %o2
0x0E270    80 a2 20 00    cmp  %o0, 0
0x0E274    02 80 00 05    be  0xe288                             ! Conditional/control branch; inspect delay slot.
0x0E278    b0 10 20 01    mov  1, %i0
0x0E27C    30 80 00 11    b,a   0xe2c0                           ! Conditional/control branch; inspect delay slot.
0x0E280    10 80 00 10    b  0xe2c0                              ! Conditional/control branch; inspect delay slot.
0x0E284    b0 10 20 00    clr  %i0
0x0E288    b0 10 20 01    mov  1, %i0
0x0E28C    35 21 e0 dc    sethi  %hi(0x87837000), %i2            ! Build high part of constant/address.
0x0E290    b2 07 bf e8    add  %fp, -24, %i1
0x0E294    d0 06 a3 64    ld  [ %i2 + 0x364 ], %o0
0x0E298    92 10 28 00    mov  0x800, %o1
0x0E29C    7f ff fd c6    call  0xd9b4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E2A0    94 10 00 19    mov  %i1, %o2
0x0E2A4    80 a2 20 03    cmp  %o0, 3
0x0E2A8    02 bf ff f6    be  0xe280                             ! Conditional/control branch; inspect delay slot.
0x0E2AC    90 10 00 18    mov  %i0, %o0
0x0E2B0    80 a2 20 20    cmp  %o0, 0x20
0x0E2B4    04 bf ff f8    ble  0xe294                            ! Conditional/control branch; inspect delay slot.
0x0E2B8    b0 06 20 01    inc  %i0
0x0E2BC    b0 10 20 01    mov  1, %i0
0x0E2C0    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0E2C4    81 e8 00 00    restore                                ! Restore previous register window.
0x0E2C8    9d e3 be 98    save  %sp, -360, %sp                   ! Enter register window; allocate stack frame.
0x0E2CC    15 08 00 0a    sethi  %hi(0x20002800), %o2            ! Build high part of constant/address.
0x0E2D0    90 10 20 0b    mov  0xb, %o0
0x0E2D4    d0 22 80 00    st  %o0, [ %o2 ]
0x0E2D8    1b 08 00 41    sethi  %hi(0x20010400), %o5            ! Build high part of constant/address.
0x0E2DC    d0 03 40 00    ld  [ %o5 ], %o0
0x0E2E0    13 00 00 20    sethi  %hi(0x8000), %o1                ! Build high part of constant/address.
0x0E2E4    90 12 20 40    or  %o0, 0x40, %o0
0x0E2E8    d0 23 40 00    st  %o0, [ %o5 ]
0x0E2EC    92 12 60 0b    or  %o1, 0xb, %o1
0x0E2F0    d2 22 80 00    st  %o1, [ %o2 ]
0x0E2F4    d2 03 40 00    ld  [ %o5 ], %o1
0x0E2F8    19 21 e0 dc    sethi  %hi(0x87837000), %o4            ! Build high part of constant/address.
0x0E2FC    d6 03 20 28    ld  [ %o4 + 0x28 ], %o3                ! 0x87837028
0x0E300    15 21 e0 dc    sethi  %hi(0x87837000), %o2            ! Build high part of constant/address.
0x0E304    11 21 e0 02    sethi  %hi(0x87800800), %o0            ! Build high part of constant/address.
0x0E308    92 0a 7f bf    and  %o1, -65, %o1
0x0E30C    d0 22 a3 60    st  %o0, [ %o2 + 0x360 ]
0x0E310    07 21 e0 dc    sethi  %hi(0x87837000), %g3            ! Build high part of constant/address.
0x0E314    d2 23 40 00    st  %o1, [ %o5 ]
0x0E318    96 02 e0 01    inc  %o3
0x0E31C    05 21 e0 00    sethi  %hi(0x87800000), %g2            ! Build high part of constant/address.
0x0E320    aa 10 00 0c    mov  %o4, %l5
0x0E324    ac 10 00 03    mov  %g3, %l6
0x0E328    d6 23 20 28    st  %o3, [ %o4 + 0x28 ]
0x0E32C    80 a6 20 06    cmp  %i0, 6
0x0E330    12 80 00 56    bne  0xe488                            ! Conditional/control branch; inspect delay slot.
0x0E334    c4 20 e3 64    st  %g2, [ %g3 + 0x364 ]
0x0E338    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0E33C    d2 06 60 04    ld  [ %i1 + 4 ], %o1
0x0E340    a4 12 20 20    or  %o0, 0x20, %l2
0x0E344    90 10 00 12    mov  %l2, %o0
0x0E348    7f ff fe ce    call  0xde80                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E34C    21 21 e0 dc    sethi  %hi(0x87837000), %l0            ! Build high part of constant/address.
0x0E350    a2 10 00 10    mov  %l0, %l1
0x0E354    d2 06 60 08    ld  [ %i1 + 8 ], %o1
0x0E358    a0 14 23 48    or  %l0, 0x348, %l0
0x0E35C    7f ff fe ae    call  0xde14                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E360    90 10 00 10    mov  %l0, %o0
0x0E364    d2 06 60 0c    ld  [ %i1 + 0xc ], %o1
0x0E368    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0E36C    7f ff fe aa    call  0xde14                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E370    90 12 23 50    or  %o0, 0x350, %o0                    ! 0x87837350
0x0E374    ee 06 60 10    ld  [ %i1 + 0x10 ], %l7
0x0E378    92 10 20 00    clr  %o1
0x0E37C    d0 06 60 14    ld  [ %i1 + 0x14 ], %o0
0x0E380    40 00 01 a7    call  0xea1c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E384    94 10 20 00    clr  %o2
0x0E388    d2 0c 20 02    ldub  [ %l0 + 2 ], %o1
0x0E38C    b2 10 00 08    mov  %o0, %i1
0x0E390    80 a2 60 7d    cmp  %o1, 0x7d
0x0E394    a6 10 00 19    mov  %i1, %l3
0x0E398    12 80 00 24    bne  0xe428                            ! Conditional/control branch; inspect delay slot.
0x0E39C    35 21 e0 dc    sethi  %hi(0x87837000), %i2            ! Build high part of constant/address.
0x0E3A0    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0E3A4    d2 0a 23 68    ldub  [ %o0 + 0x368 ], %o1             ! 0x87837368
0x0E3A8    98 10 00 08    mov  %o0, %o4
0x0E3AC    80 a2 60 00    cmp  %o1, 0
0x0E3B0    12 80 00 1e    bne  0xe428                            ! Conditional/control branch; inspect delay slot.
0x0E3B4    94 12 23 68    or  %o0, 0x368, %o2
0x0E3B8    d0 0a a0 01    ldub  [ %o2 + 1 ], %o0
0x0E3BC    80 a2 20 0d    cmp  %o0, 0xd
0x0E3C0    12 80 00 1b    bne  0xe42c                            ! Conditional/control branch; inspect delay slot.
0x0E3C4    d0 0e a3 b0    ldub  [ %i2 + 0x3b0 ], %o0
0x0E3C8    d0 0a a0 02    ldub  [ %o2 + 2 ], %o0
0x0E3CC    80 a2 20 a2    cmp  %o0, 0xa2
0x0E3D0    12 80 00 17    bne  0xe42c                            ! Conditional/control branch; inspect delay slot.
0x0E3D4    d0 0e a3 b0    ldub  [ %i2 + 0x3b0 ], %o0
0x0E3D8    92 10 00 0a    mov  %o2, %o1
0x0E3DC    96 10 00 12    mov  %l2, %o3
0x0E3E0    94 10 20 00    clr  %o2
0x0E3E4    d0 0a 40 0a    ldub  [ %o1 + %o2 ], %o0
0x0E3E8    d0 2a c0 0a    stb  %o0, [ %o3 + %o2 ]
0x0E3EC    94 02 a0 01    inc  %o2
0x0E3F0    80 a2 a0 05    cmp  %o2, 5
0x0E3F4    24 bf ff fd    ble,a   0xe3e8                         ! Conditional/control branch; inspect delay slot.
0x0E3F8    d0 0a 40 0a    ldub  [ %o1 + %o2 ], %o0
0x0E3FC    90 13 23 68    or  %o4, 0x368, %o0
0x0E400    d0 0a 20 05    ldub  [ %o0 + 5 ], %o0
0x0E404    92 0a 20 ff    and  %o0, 0xff, %o1
0x0E408    80 a2 60 09    cmp  %o1, 9
0x0E40C    08 80 00 05    bleu  0xe420                           ! Conditional/control branch; inspect delay slot.
0x0E410    94 14 63 48    or  %l1, 0x348, %o2
0x0E414    80 a2 60 fd    cmp  %o1, 0xfd
0x0E418    28 80 00 04    bleu,a   0xe428
0x0E41C    d0 2a a0 03    stb  %o0, [ %o2 + 3 ]
0x0E420    90 02 3f 80    add  %o0, -128, %o0
0x0E424    d0 2a a0 03    stb  %o0, [ %o2 + 3 ]
0x0E428    d0 0e a3 b0    ldub  [ %i2 + 0x3b0 ], %o0
0x0E42C    80 a2 20 00    cmp  %o0, 0
0x0E430    02 80 00 18    be  0xe490                             ! Conditional/control branch; inspect delay slot.
0x0E434    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0E438    40 00 10 3a    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E43C    90 12 21 a8    or  %o0, 0x1a8, %o0                    ! 0x878369a8
0x0E440    40 00 10 6e    call  0x125f8                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E444    d0 0c 63 48    ldub  [ %l1 + 0x348 ], %o0
0x0E448    21 21 e0 da    sethi  %hi(0x87836800), %l0            ! Build high part of constant/address.
0x0E44C    a0 14 21 b8    or  %l0, 0x1b8, %l0                    ! 0x878369b8
0x0E450    90 10 00 10    mov  %l0, %o0
0x0E454    40 00 10 33    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E458    a2 14 63 48    or  %l1, 0x348, %l1
0x0E45C    40 00 10 67    call  0x125f8                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E460    d0 0c 60 01    ldub  [ %l1 + 1 ], %o0
0x0E464    40 00 10 2f    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E468    90 10 00 10    mov  %l0, %o0
0x0E46C    40 00 10 63    call  0x125f8                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E470    d0 0c 60 02    ldub  [ %l1 + 2 ], %o0
0x0E474    40 00 10 2b    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E478    90 10 00 10    mov  %l0, %o0
0x0E47C    40 00 10 5f    call  0x125f8                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E480    d0 0c 60 03    ldub  [ %l1 + 3 ], %o0
0x0E484    30 80 00 03    b,a   0xe490                           ! Conditional/control branch; inspect delay slot.
0x0E488    10 80 00 c7    b  0xe7a4                              ! Conditional/control branch; inspect delay slot.
0x0E48C    b0 10 20 01    mov  1, %i0
0x0E490    7f ff fe a5    call  0xdf24                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E494    90 10 20 0a    mov  0xa, %o0
0x0E498    80 a2 20 00    cmp  %o0, 0
0x0E49C    02 80 00 09    be  0xe4c0                             ! Conditional/control branch; inspect delay slot.
0x0E4A0    d0 0e a3 b0    ldub  [ %i2 + 0x3b0 ], %o0
0x0E4A4    80 a2 20 00    cmp  %o0, 0
0x0E4A8    02 80 00 04    be  0xe4b8                             ! Conditional/control branch; inspect delay slot.
0x0E4AC    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0E4B0    40 00 10 1c    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E4B4    90 12 21 c0    or  %o0, 0x1c0, %o0                    ! 0x878369c0
0x0E4B8    10 80 00 bb    b  0xe7a4                              ! Conditional/control branch; inspect delay slot.
0x0E4BC    b0 10 20 02    mov  2, %i0
0x0E4C0    90 07 be f8    add  %fp, -264, %o0
0x0E4C4    94 10 20 01    mov  1, %o2
0x0E4C8    c0 2a 00 00    clrb  [ %o0 ]
0x0E4CC    b0 10 00 08    mov  %o0, %i0
0x0E4D0    d4 2a 00 0a    stb  %o2, [ %o0 + %o2 ]
0x0E4D4    98 10 00 18    mov  %i0, %o4
0x0E4D8    96 10 00 17    mov  %l7, %o3
0x0E4DC    94 10 20 02    mov  2, %o2
0x0E4E0    d0 0a c0 00    ldub  [ %o3 ], %o0
0x0E4E4    93 2a 20 18    sll  %o0, 0x18, %o1
0x0E4E8    d0 2b 00 0a    stb  %o0, [ %o4 + %o2 ]
0x0E4EC    80 a2 60 00    cmp  %o1, 0
0x0E4F0    96 02 e0 01    inc  %o3
0x0E4F4    12 bf ff fb    bne  0xe4e0                            ! Conditional/control branch; inspect delay slot.
0x0E4F8    94 02 a0 01    inc  %o2
0x0E4FC    90 10 20 6f    mov  0x6f, %o0
0x0E500    d0 2e 00 0a    stb  %o0, [ %i0 + %o2 ]
0x0E504    94 02 a0 01    inc  %o2
0x0E508    90 10 20 63    mov  0x63, %o0
0x0E50C    d0 2e 00 0a    stb  %o0, [ %i0 + %o2 ]
0x0E510    94 02 a0 01    inc  %o2
0x0E514    92 10 20 74    mov  0x74, %o1
0x0E518    d2 2e 00 0a    stb  %o1, [ %i0 + %o2 ]
0x0E51C    94 02 a0 01    inc  %o2
0x0E520    90 10 20 65    mov  0x65, %o0
0x0E524    d0 2e 00 0a    stb  %o0, [ %i0 + %o2 ]
0x0E528    94 02 a0 01    inc  %o2
0x0E52C    d2 2e 00 0a    stb  %o1, [ %i0 + %o2 ]
0x0E530    d2 05 60 28    ld  [ %l5 + 0x28 ], %o1
0x0E534    94 02 a0 01    inc  %o2
0x0E538    96 02 a0 01    add  %o2, 1, %o3
0x0E53C    c0 2e 00 0a    clrb  [ %i0 + %o2 ]
0x0E540    90 10 00 18    mov  %i0, %o0
0x0E544    94 10 20 45    mov  0x45, %o2
0x0E548    7f ff fe e0    call  0xe0c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E54C    98 10 20 03    mov  3, %o4
0x0E550    80 a2 20 00    cmp  %o0, 0
0x0E554    02 80 00 0c    be  0xe584                             ! Conditional/control branch; inspect delay slot.
0x0E558    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0E55C    40 00 01 3f    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E560    90 12 21 d0    or  %o0, 0x1d0, %o0                    ! 0x878369d0
0x0E564    d0 0e a3 b0    ldub  [ %i2 + 0x3b0 ], %o0
0x0E568    80 a2 20 00    cmp  %o0, 0
0x0E56C    02 80 00 04    be  0xe57c                             ! Conditional/control branch; inspect delay slot.
0x0E570    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0E574    40 00 0f eb    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E578    90 12 21 d8    or  %o0, 0x1d8, %o0                    ! 0x878369d8
0x0E57C    10 80 00 8a    b  0xe7a4                              ! Conditional/control branch; inspect delay slot.
0x0E580    b0 10 20 03    mov  3, %i0
0x0E584    a2 10 20 00    clr  %l1
0x0E588    a4 10 20 01    mov  1, %l2
0x0E58C    d6 05 a3 64    ld  [ %l6 + 0x364 ], %o3
0x0E590    d0 0a e0 2a    ldub  [ %o3 + 0x2a ], %o0
0x0E594    80 a2 20 00    cmp  %o0, 0
0x0E598    12 80 00 06    bne  0xe5b0                            ! Conditional/control branch; inspect delay slot.
0x0E59C    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0E5A0    d0 0a e0 2b    ldub  [ %o3 + 0x2b ], %o0
0x0E5A4    80 a2 20 03    cmp  %o0, 3
0x0E5A8    02 80 00 0c    be  0xe5d8                             ! Conditional/control branch; inspect delay slot.
0x0E5AC    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0E5B0    40 00 01 2a    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E5B4    90 12 21 e8    or  %o0, 0x1e8, %o0                    ! 0x878369e8
0x0E5B8    d0 0e a3 b0    ldub  [ %i2 + 0x3b0 ], %o0
0x0E5BC    80 a2 20 00    cmp  %o0, 0
0x0E5C0    02 80 00 78    be  0xe7a0                             ! Conditional/control branch; inspect delay slot.
0x0E5C4    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0E5C8    40 00 0f d6    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E5CC    90 12 21 f0    or  %o0, 0x1f0, %o0                    ! 0x878369f0
0x0E5D0    10 80 00 75    b  0xe7a4                              ! Conditional/control branch; inspect delay slot.
0x0E5D4    b0 10 20 04    mov  4, %i0
0x0E5D8    d0 0a e0 2c    ldub  [ %o3 + 0x2c ], %o0
0x0E5DC    d2 0a e0 2d    ldub  [ %o3 + 0x2d ], %o1
0x0E5E0    91 2a 20 08    sll  %o0, 8, %o0
0x0E5E4    94 12 00 09    or  %o0, %o1, %o2
0x0E5E8    80 a2 80 12    cmp  %o2, %l2
0x0E5EC    16 80 00 09    bge  0xe610                            ! Conditional/control branch; inspect delay slot.
0x0E5F0    d2 05 60 28    ld  [ %l5 + 0x28 ], %o1
0x0E5F4    90 10 00 18    mov  %i0, %o0
0x0E5F8    94 10 00 14    mov  %l4, %o2
0x0E5FC    96 10 20 04    mov  4, %o3
0x0E600    7f ff fe b2    call  0xe0c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E604    98 10 20 01    mov  1, %o4
0x0E608    10 bf ff e2    b  0xe590                              ! Conditional/control branch; inspect delay slot.
0x0E60C    d6 05 a3 64    ld  [ %l6 + 0x364 ], %o3
0x0E610    24 80 00 04    ble,a   0xe620                         ! Conditional/control branch; inspect delay slot.
0x0E614    d0 0a e0 26    ldub  [ %o3 + 0x26 ], %o0
0x0E618    10 80 00 63    b  0xe7a4                              ! Conditional/control branch; inspect delay slot.
0x0E61C    b0 10 20 05    mov  5, %i0
0x0E620    15 3f fc 00    sethi  %hi(0xfff00000), %o2            ! Build high part of constant/address.
0x0E624    d2 0a e0 27    ldub  [ %o3 + 0x27 ], %o1
0x0E628    91 2a 20 08    sll  %o0, 8, %o0
0x0E62C    a0 12 00 09    or  %o0, %o1, %l0
0x0E630    a0 04 3f f4    add  %l0, -12, %l0
0x0E634    a2 04 40 10    add  %l1, %l0, %l1
0x0E638    80 ac 40 0a    andncc  %l1, %o2, %g0
0x0E63C    12 80 00 07    bne  0xe658                            ! Conditional/control branch; inspect delay slot.
0x0E640    a4 04 a0 01    inc  %l2
0x0E644    40 00 01 2e    call  0xeafc                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E648    91 34 60 14    srl  %l1, 0x14, %o0
0x0E64C    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0E650    40 00 01 02    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E654    90 12 22 00    or  %o0, 0x200, %o0                    ! 0x87836a00
0x0E658    94 10 20 00    clr  %o2
0x0E65C    80 a2 80 10    cmp  %o2, %l0
0x0E660    36 80 00 0c    bge,a   0xe690                         ! Conditional/control branch; inspect delay slot.
0x0E664    d4 05 a3 64    ld  [ %l6 + 0x364 ], %o2
0x0E668    96 10 00 16    mov  %l6, %o3
0x0E66C    d0 02 e3 64    ld  [ %o3 + 0x364 ], %o0
0x0E670    90 02 80 08    add  %o2, %o0, %o0
0x0E674    d2 12 20 2e    lduh  [ %o0 + 0x2e ], %o1
0x0E678    94 02 a0 02    add  %o2, 2, %o2
0x0E67C    d2 34 c0 00    sth  %o1, [ %l3 ]
0x0E680    80 a2 80 10    cmp  %o2, %l0
0x0E684    06 bf ff fa    bl  0xe66c                             ! Conditional/control branch; inspect delay slot.
0x0E688    a6 04 e0 02    add  %l3, 2, %l3
0x0E68C    d4 05 a3 64    ld  [ %l6 + 0x364 ], %o2
0x0E690    90 10 20 04    mov  4, %o0
0x0E694    d0 2f be f9    stb  %o0, [ %fp + -263 ]
0x0E698    c0 2f be f8    clrb  [ %fp + -264 ]
0x0E69C    d2 0a a0 2c    ldub  [ %o2 + 0x2c ], %o1
0x0E6A0    80 a4 21 ff    cmp  %l0, 0x1ff
0x0E6A4    d2 2f be fa    stb  %o1, [ %fp + -262 ]
0x0E6A8    d0 0a a0 2d    ldub  [ %o2 + 0x2d ], %o0
0x0E6AC    d0 2f be fb    stb  %o0, [ %fp + -261 ]
0x0E6B0    d2 0a a0 22    ldub  [ %o2 + 0x22 ], %o1
0x0E6B4    d0 0a a0 23    ldub  [ %o2 + 0x23 ], %o0
0x0E6B8    93 2a 60 08    sll  %o1, 8, %o1
0x0E6BC    14 80 00 30    bg  0xe77c                             ! Conditional/control branch; inspect delay slot.
0x0E6C0    a8 12 40 08    or  %o1, %o0, %l4
0x0E6C4    d2 05 60 28    ld  [ %l5 + 0x28 ], %o1
0x0E6C8    90 10 00 18    mov  %i0, %o0
0x0E6CC    94 10 00 14    mov  %l4, %o2
0x0E6D0    96 10 20 04    mov  4, %o3
0x0E6D4    7f ff fe 7d    call  0xe0c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E6D8    98 10 20 02    mov  2, %o4
0x0E6DC    80 a2 20 00    cmp  %o0, 0
0x0E6E0    22 80 00 0e    be,a   0xe718                          ! Conditional/control branch; inspect delay slot.
0x0E6E4    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0E6E8    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0E6EC    40 00 00 db    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E6F0    90 12 22 08    or  %o0, 0x208, %o0                    ! 0x87836a08
0x0E6F4    d0 0e a3 b0    ldub  [ %i2 + 0x3b0 ], %o0
0x0E6F8    80 a2 20 00    cmp  %o0, 0
0x0E6FC    02 80 00 11    be  0xe740                             ! Conditional/control branch; inspect delay slot.
0x0E700    80 a4 60 00    cmp  %l1, 0
0x0E704    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0E708    40 00 0f 86    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E70C    90 12 22 10    or  %o0, 0x210, %o0                    ! 0x87836a10
0x0E710    10 80 00 0c    b  0xe740                              ! Conditional/control branch; inspect delay slot.
0x0E714    80 a4 60 00    cmp  %l1, 0
0x0E718    40 00 00 d0    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E71C    90 12 22 20    or  %o0, 0x220, %o0
0x0E720    d0 0e a3 b0    ldub  [ %i2 + 0x3b0 ], %o0
0x0E724    80 a2 20 00    cmp  %o0, 0
0x0E728    02 80 00 06    be  0xe740                             ! Conditional/control branch; inspect delay slot.
0x0E72C    80 a4 60 00    cmp  %l1, 0
0x0E730    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0E734    40 00 0f 7b    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E738    90 12 22 28    or  %o0, 0x228, %o0                    ! 0x87836a28
0x0E73C    80 a4 60 00    cmp  %l1, 0
0x0E740    02 80 00 19    be  0xe7a4                             ! Conditional/control branch; inspect delay slot.
0x0E744    b0 10 20 00    clr  %i0
0x0E748    80 a4 62 00    cmp  %l1, 0x200
0x0E74C    08 80 00 03    bleu  0xe758                           ! Conditional/control branch; inspect delay slot.
0x0E750    a0 10 00 11    mov  %l1, %l0
0x0E754    a0 10 22 00    mov  0x200, %l0
0x0E758    90 10 00 19    mov  %i1, %o0
0x0E75C    92 10 00 19    mov  %i1, %o1
0x0E760    7f ff f7 1a    call  0xc3c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E764    94 10 00 10    mov  %l0, %o2
0x0E768    a2 a4 40 10    subcc  %l1, %l0, %l1
0x0E76C    12 bf ff f7    bne  0xe748                            ! Conditional/control branch; inspect delay slot.
0x0E770    b2 06 40 10    add  %i1, %l0, %i1
0x0E774    10 80 00 0c    b  0xe7a4                              ! Conditional/control branch; inspect delay slot.
0x0E778    b0 10 20 00    clr  %i0
0x0E77C    d2 05 60 28    ld  [ %l5 + 0x28 ], %o1
0x0E780    90 10 00 18    mov  %i0, %o0
0x0E784    94 10 00 14    mov  %l4, %o2
0x0E788    96 10 20 04    mov  4, %o3
0x0E78C    7f ff fe 4f    call  0xe0c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E790    98 10 20 03    mov  3, %o4
0x0E794    80 a2 20 00    cmp  %o0, 0
0x0E798    02 bf ff 7e    be  0xe590                             ! Conditional/control branch; inspect delay slot.
0x0E79C    d6 05 a3 64    ld  [ %l6 + 0x364 ], %o3
0x0E7A0    b0 10 20 04    mov  4, %i0
0x0E7A4    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0E7A8    81 e8 00 00    restore                                ! Restore previous register window.
0x0E7AC    84 10 00 09    mov  %o1, %g2
0x0E7B0    80 a0 a0 0c    cmp  %g2, 0xc
0x0E7B4    04 80 00 03    ble  0xe7c0                            ! Conditional/control branch; inspect delay slot.
0x0E7B8    86 10 00 08    mov  %o0, %g3
0x0E7BC    84 10 20 0c    mov  0xc, %g2
0x0E7C0    80 a0 a0 03    cmp  %g2, 3
0x0E7C4    24 80 00 02    ble,a   0xe7cc                         ! Conditional/control branch; inspect delay slot.
0x0E7C8    84 10 20 04    mov  4, %g2
0x0E7CC    90 10 20 01    mov  1, %o0
0x0E7D0    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x0E7D4    91 2a 00 02    sll  %o0, %g2, %o0
0x0E7D8    c4 02 60 c0    ld  [ %o1 + 0xc0 ], %g2
0x0E7DC    90 02 3f ff    add  %o0, -1, %o0
0x0E7E0    84 00 80 08    add  %g2, %o0, %g2
0x0E7E4    90 28 80 08    andn  %g2, %o0, %o0
0x0E7E8    86 02 00 03    add  %o0, %g3, %g3
0x0E7EC    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x0E7F0    c6 22 60 c0    st  %g3, [ %o1 + 0xc0 ]
0x0E7F4    96 10 20 02    mov  2, %o3
0x0E7F8    80 a2 c0 0a    cmp  %o3, %o2
0x0E7FC    16 80 00 09    bge  0xe820                            ! Conditional/control branch; inspect delay slot.
0x0E800    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0E804    84 1a e0 03    xor  %o3, 3, %g2
0x0E808    c6 0a 40 02    ldub  [ %o1 + %g2 ], %g3
0x0E80C    96 02 e0 02    add  %o3, 2, %o3
0x0E810    c6 2a 00 00    stb  %g3, [ %o0 ]
0x0E814    80 a2 c0 0a    cmp  %o3, %o2
0x0E818    06 bf ff fb    bl  0xe804                             ! Conditional/control branch; inspect delay slot.
0x0E81C    90 02 20 01    inc  %o0
0x0E820    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x0E824    c0 2a 00 00    clrb  [ %o0 ]
0x0E828    94 02 60 03    add  %o1, 3, %o2
0x0E82C    94 8a bf fc    andcc  %o2, -4, %o2
0x0E830    04 80 00 16    ble  0xe888                            ! Conditional/control branch; inspect delay slot.
0x0E834    96 10 00 08    mov  %o0, %o3
0x0E838    05 00 00 3f    sethi  %hi(0xfc00), %g2                ! Build high part of constant/address.
0x0E83C    82 10 a3 00    or  %g2, 0x300, %g1                    ! 0xff00
0x0E840    1b 00 3f c0    sethi  %hi(0xff0000), %o5              ! Build high part of constant/address.
0x0E844    19 3f c0 00    sethi  %hi(0xff000000), %o4            ! Build high part of constant/address.
0x0E848    c6 02 c0 00    ld  [ %o3 ], %g3
0x0E84C    94 02 bf fc    add  %o2, -4, %o2
0x0E850    90 08 c0 01    and  %g3, %g1, %o0
0x0E854    85 28 e0 18    sll  %g3, 0x18, %g2
0x0E858    92 08 c0 0d    and  %g3, %o5, %o1
0x0E85C    91 2a 20 08    sll  %o0, 8, %o0
0x0E860    84 10 80 08    or  %g2, %o0, %g2
0x0E864    93 32 60 08    srl  %o1, 8, %o1
0x0E868    86 08 c0 0c    and  %g3, %o4, %g3
0x0E86C    84 10 80 09    or  %g2, %o1, %g2
0x0E870    87 30 e0 18    srl  %g3, 0x18, %g3
0x0E874    84 10 80 03    or  %g2, %g3, %g2
0x0E878    c4 22 c0 00    st  %g2, [ %o3 ]
0x0E87C    80 a2 a0 00    cmp  %o2, 0
0x0E880    14 bf ff f2    bg  0xe848                             ! Conditional/control branch; inspect delay slot.
0x0E884    96 02 e0 04    add  %o3, 4, %o3
0x0E888    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x0E88C    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0E890    c6 0a 40 00    ldub  [ %o1 ], %g3
0x0E894    d4 0a 00 00    ldub  [ %o0 ], %o2
0x0E898    86 22 80 03    sub  %o2, %g3, %g3
0x0E89C    85 28 e0 18    sll  %g3, 0x18, %g2
0x0E8A0    80 a0 a0 00    cmp  %g2, 0
0x0E8A4    12 80 00 06    bne  0xe8bc                            ! Conditional/control branch; inspect delay slot.
0x0E8A8    92 02 60 01    inc  %o1
0x0E8AC    80 a2 a0 00    cmp  %o2, 0
0x0E8B0    12 bf ff f8    bne  0xe890                            ! Conditional/control branch; inspect delay slot.
0x0E8B4    90 02 20 01    inc  %o0
0x0E8B8    85 28 e0 18    sll  %g3, 0x18, %g2
0x0E8BC    80 a0 00 02    cmp  %g0, %g2
0x0E8C0    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x0E8C4    90 60 3f ff    subx  %g0, -1, %o0
0x0E8C8    84 02 3f d0    add  %o0, -48, %g2
0x0E8CC    84 08 a0 ff    and  %g2, 0xff, %g2
0x0E8D0    80 a0 a0 09    cmp  %g2, 9
0x0E8D4    08 80 00 0b    bleu  0xe900                           ! Conditional/control branch; inspect delay slot.
0x0E8D8    86 10 20 00    clr  %g3
0x0E8DC    84 02 3f 9f    add  %o0, -97, %g2
0x0E8E0    84 08 a0 ff    and  %g2, 0xff, %g2
0x0E8E4    80 a0 a0 05    cmp  %g2, 5
0x0E8E8    08 80 00 06    bleu  0xe900                           ! Conditional/control branch; inspect delay slot.
0x0E8EC    84 02 3f bf    add  %o0, -65, %g2
0x0E8F0    84 08 a0 ff    and  %g2, 0xff, %g2
0x0E8F4    80 a0 a0 05    cmp  %g2, 5
0x0E8F8    18 80 00 03    bgu  0xe904                            ! Conditional/control branch; inspect delay slot.
0x0E8FC    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0E900    86 10 20 01    mov  1, %g3                            ! 0x1
0x0E904    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x0E908    90 10 00 03    mov  %g3, %o0
0x0E90C    90 02 3f d0    add  %o0, -48, %o0
0x0E910    90 0a 20 ff    and  %o0, 0xff, %o0
0x0E914    80 a2 20 0a    cmp  %o0, 0xa
0x0E918    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x0E91C    90 40 20 00    addx  %g0, 0, %o0
0x0E920    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0E924    80 a6 a0 00    cmp  %i2, 0
0x0E928    12 80 00 24    bne  0xe9b8                            ! Conditional/control branch; inspect delay slot.
0x0E92C    a0 10 20 00    clr  %l0
0x0E930    d0 4e 00 00    ldsb  [ %i0 ], %o0
0x0E934    80 a2 20 30    cmp  %o0, 0x30
0x0E938    12 80 00 20    bne  0xe9b8                            ! Conditional/control branch; inspect delay slot.
0x0E93C    b4 10 20 0a    mov  0xa, %i2
0x0E940    b0 06 20 01    inc  %i0
0x0E944    d0 4e 00 00    ldsb  [ %i0 ], %o0
0x0E948    80 a2 20 78    cmp  %o0, 0x78
0x0E94C    12 80 00 1b    bne  0xe9b8                            ! Conditional/control branch; inspect delay slot.
0x0E950    b4 10 20 08    mov  8, %i2
0x0E954    7f ff ff dd    call  0xe8c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E958    d0 0e 20 01    ldub  [ %i0 + 1 ], %o0
0x0E95C    80 a2 20 00    cmp  %o0, 0
0x0E960    02 80 00 16    be  0xe9b8                             ! Conditional/control branch; inspect delay slot.
0x0E964    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0E968    b0 06 20 01    inc  %i0
0x0E96C    10 80 00 13    b  0xe9b8                              ! Conditional/control branch; inspect delay slot.
0x0E970    b4 10 20 10    mov  0x10, %i2
0x0E974    02 80 00 0d    be  0xe9a8                             ! Conditional/control branch; inspect delay slot.
0x0E978    93 2c 20 01    sll  %l0, 1, %o1
0x0E97C    18 80 00 06    bgu  0xe994                            ! Conditional/control branch; inspect delay slot.
0x0E980    80 a6 a0 08    cmp  %i2, 8
0x0E984    02 80 00 0b    be  0xe9b0                             ! Conditional/control branch; inspect delay slot.
0x0E988    91 2c 20 03    sll  %l0, 3, %o0
0x0E98C    10 80 00 0b    b  0xe9b8                              ! Conditional/control branch; inspect delay slot.
0x0E990    b0 06 20 01    inc  %i0
0x0E994    80 a6 a0 10    cmp  %i2, 0x10
0x0E998    02 80 00 06    be  0xe9b0                             ! Conditional/control branch; inspect delay slot.
0x0E99C    91 2c 20 04    sll  %l0, 4, %o0
0x0E9A0    10 80 00 06    b  0xe9b8                              ! Conditional/control branch; inspect delay slot.
0x0E9A4    b0 06 20 01    inc  %i0
0x0E9A8    91 2c 20 03    sll  %l0, 3, %o0
0x0E9AC    90 02 00 09    add  %o0, %o1, %o0
0x0E9B0    a0 02 00 0a    add  %o0, %o2, %l0
0x0E9B4    b0 06 20 01    inc  %i0
0x0E9B8    7f ff ff c4    call  0xe8c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E9BC    d0 0e 00 00    ldub  [ %i0 ], %o0
0x0E9C0    80 a2 20 00    cmp  %o0, 0
0x0E9C4    02 80 00 12    be  0xea0c                             ! Conditional/control branch; inspect delay slot.
0x0E9C8    80 a6 60 00    cmp  %i1, 0
0x0E9CC    7f ff ff d0    call  0xe90c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0E9D0    d0 0e 00 00    ldub  [ %i0 ], %o0
0x0E9D4    80 a2 20 00    cmp  %o0, 0
0x0E9D8    22 80 00 05    be,a   0xe9ec                          ! Conditional/control branch; inspect delay slot.
0x0E9DC    d0 0e 00 00    ldub  [ %i0 ], %o0
0x0E9E0    d0 4e 00 00    ldsb  [ %i0 ], %o0
0x0E9E4    10 80 00 06    b  0xe9fc                              ! Conditional/control branch; inspect delay slot.
0x0E9E8    94 02 3f d0    add  %o0, -48, %o2
0x0E9EC    90 0a 3f df    and  %o0, -33, %o0
0x0E9F0    91 2a 20 18    sll  %o0, 0x18, %o0
0x0E9F4    91 3a 20 18    sra  %o0, 0x18, %o0
0x0E9F8    94 02 3f c9    add  %o0, -55, %o2
0x0E9FC    80 a2 80 1a    cmp  %o2, %i2
0x0EA00    0a bf ff dd    bcs  0xe974                            ! Conditional/control branch; inspect delay slot.
0x0EA04    80 a6 a0 0a    cmp  %i2, 0xa
0x0EA08    80 a6 60 00    cmp  %i1, 0
0x0EA0C    32 80 00 02    bne,a   0xea14                         ! Conditional/control branch; inspect delay slot.
0x0EA10    f0 26 40 00    st  %i0, [ %i1 ]
0x0EA14    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0EA18    91 e8 00 10    restore  %g0, %l0, %o0                 ! Restore previous register window.
0x0EA1C    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0EA20    d0 4e 00 00    ldsb  [ %i0 ], %o0
0x0EA24    92 10 00 19    mov  %i1, %o1
0x0EA28    80 a2 20 2d    cmp  %o0, 0x2d
0x0EA2C    02 80 00 06    be  0xea44                             ! Conditional/control branch; inspect delay slot.
0x0EA30    94 10 00 1a    mov  %i2, %o2
0x0EA34    7f ff ff bb    call  0xe920                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EA38    90 10 00 18    mov  %i0, %o0
0x0EA3C    10 80 00 05    b  0xea50                              ! Conditional/control branch; inspect delay slot.
0x0EA40    b0 10 00 08    mov  %o0, %i0
0x0EA44    7f ff ff b7    call  0xe920                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EA48    90 06 20 01    add  %i0, 1, %o0
0x0EA4C    b0 20 00 08    neg  %o0, %i0
0x0EA50    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0EA54    81 e8 00 00    restore                                ! Restore previous register window.
0x0EA58    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0EA5C    10 80 00 05    b  0xea70                              ! Conditional/control branch; inspect delay slot.
0x0EA60    d0 0e 00 00    ldub  [ %i0 ], %o0
0x0EA64    40 00 00 3f    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EA68    b0 06 20 01    inc  %i0
0x0EA6C    d0 0e 00 00    ldub  [ %i0 ], %o0
0x0EA70    80 a2 20 00    cmp  %o0, 0
0x0EA74    12 bf ff fc    bne  0xea64                            ! Conditional/control branch; inspect delay slot.
0x0EA78    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0EA7C    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0EA80    81 e8 00 00    restore                                ! Restore previous register window.
0x0EA84    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0EA88    d0 0e 00 00    ldub  [ %i0 ], %o0
0x0EA8C    80 a2 20 08    cmp  %o0, 8
0x0EA90    12 80 00 04    bne  0xeaa0                            ! Conditional/control branch; inspect delay slot.
0x0EA94    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0EA98    7f ff ff f0    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EA9C    90 06 20 01    add  %i0, 1, %o0
0x0EAA0    40 00 00 30    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EAA4    90 10 20 0a    mov  0xa, %o0
0x0EAA8    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0EAAC    d2 0a 23 b0    ldub  [ %o0 + 0x3b0 ], %o1             ! 0x878373b0
0x0EAB0    80 a2 60 00    cmp  %o1, 0
0x0EAB4    02 80 00 04    be  0xeac4                             ! Conditional/control branch; inspect delay slot.
0x0EAB8    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0EABC    40 00 0e 99    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EAC0    90 10 00 18    mov  %i0, %o0
0x0EAC4    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0EAC8    81 e8 00 00    restore                                ! Restore previous register window.
0x0EACC    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0EAD0    90 0e 20 0f    and  %i0, 0xf, %o0
0x0EAD4    80 a2 20 09    cmp  %o0, 9
0x0EAD8    18 80 00 05    bgu  0xeaec                            ! Conditional/control branch; inspect delay slot.
0x0EADC    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0EAE0    40 00 00 20    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EAE4    90 12 20 30    or  %o0, 0x30, %o0
0x0EAE8    30 80 00 03    b,a   0xeaf4                           ! Conditional/control branch; inspect delay slot.
0x0EAEC    40 00 00 1d    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EAF0    90 02 20 57    add  %o0, 0x57, %o0
0x0EAF4    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0EAF8    81 e8 00 00    restore                                ! Restore previous register window.
0x0EAFC    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0EB00    7f ff ff f3    call  0xeacc                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EB04    91 36 20 04    srl  %i0, 4, %o0
0x0EB08    7f ff ff f1    call  0xeacc                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EB0C    90 10 00 18    mov  %i0, %o0
0x0EB10    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0EB14    81 e8 00 00    restore                                ! Restore previous register window.
0x0EB18    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0EB1C    a0 10 20 0c    mov  0xc, %l0
0x0EB20    7f ff ff eb    call  0xeacc                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EB24    91 36 00 10    srl  %i0, %l0, %o0
0x0EB28    a0 84 3f fc    addcc  %l0, -4, %l0
0x0EB2C    1c bf ff fd    bpos  0xeb20                           ! Conditional/control branch; inspect delay slot.
0x0EB30    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0EB34    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0EB38    81 e8 00 00    restore                                ! Restore previous register window.
0x0EB3C    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0EB40    a0 10 20 1c    mov  0x1c, %l0
0x0EB44    7f ff ff e2    call  0xeacc                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EB48    91 36 00 10    srl  %i0, %l0, %o0
0x0EB4C    a0 84 3f fc    addcc  %l0, -4, %l0
0x0EB50    1c bf ff fd    bpos  0xeb44                           ! Conditional/control branch; inspect delay slot.
0x0EB54    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0EB58    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0EB5C    81 e8 00 00    restore                                ! Restore previous register window.
0x0EB60    84 0a 20 ff    and  %o0, 0xff, %g2
0x0EB64    80 a0 a0 0a    cmp  %g2, 0xa
0x0EB68    12 80 00 0b    bne  0xeb94                            ! Conditional/control branch; inspect delay slot.
0x0EB6C    05 08 00 00    sethi  %hi(0x20000000), %g2            ! Build high part of constant/address.
0x0EB70    86 10 a0 64    or  %g2, 0x64, %g3                     ! 0x20000064
0x0EB74    c4 00 c0 00    ld  [ %g3 ], %g2
0x0EB78    80 88 a0 04    btst  4, %g2
0x0EB7C    02 bf ff fe    be  0xeb74                             ! Conditional/control branch; inspect delay slot.
0x0EB80    05 08 00 00    sethi  %hi(0x20000000), %g2            ! Build high part of constant/address.
0x0EB84    84 10 a0 60    or  %g2, 0x60, %g2                     ! 0x20000060
0x0EB88    86 10 20 0d    mov  0xd, %g3
0x0EB8C    c6 20 80 00    st  %g3, [ %g2 ]
0x0EB90    05 08 00 00    sethi  %hi(0x20000000), %g2            ! Build high part of constant/address.
0x0EB94    86 10 a0 64    or  %g2, 0x64, %g3                     ! 0x20000064
0x0EB98    90 0a 20 ff    and  %o0, 0xff, %o0
0x0EB9C    c4 00 c0 00    ld  [ %g3 ], %g2
0x0EBA0    80 88 a0 04    btst  4, %g2
0x0EBA4    02 bf ff fe    be  0xeb9c                             ! Conditional/control branch; inspect delay slot.
0x0EBA8    05 08 00 00    sethi  %hi(0x20000000), %g2            ! Build high part of constant/address.
0x0EBAC    84 10 a0 60    or  %g2, 0x60, %g2                     ! 0x20000060
0x0EBB0    d0 20 80 00    st  %o0, [ %g2 ]
0x0EBB4    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x0EBB8    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0EBBC    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0EBC0    7f ff ff e8    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EBC4    90 10 20 08    mov  8, %o0
0x0EBC8    7f ff ff e6    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EBCC    90 10 20 20    mov  0x20, %o0
0x0EBD0    7f ff ff e4    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EBD4    90 10 20 08    mov  8, %o0
0x0EBD8    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0EBDC    81 e8 00 00    restore                                ! Restore previous register window.
0x0EBE0    07 08 00 00    sethi  %hi(0x20000000), %g3            ! Build high part of constant/address.
0x0EBE4    05 00 00 04    sethi  %hi(0x1000), %g2                ! Build high part of constant/address.
0x0EBE8    94 10 00 03    mov  %g3, %o2
0x0EBEC    96 10 a3 87    or  %g2, 0x387, %o3
0x0EBF0    86 10 e0 64    or  %g3, 0x64, %g3
0x0EBF4    84 10 20 00    clr  %g2
0x0EBF8    92 00 a0 01    add  %g2, 1, %o1
0x0EBFC    c4 00 c0 00    ld  [ %g3 ], %g2
0x0EC00    80 88 a0 04    btst  4, %g2
0x0EC04    02 bf ff fe    be  0xebfc                             ! Conditional/control branch; inspect delay slot.
0x0EC08    90 12 a0 64    or  %o2, 0x64, %o0
0x0EC0C    c4 02 00 00    ld  [ %o0 ], %g2
0x0EC10    80 88 a0 80    btst  0x80, %g2
0x0EC14    02 bf ff fe    be  0xec0c                             ! Conditional/control branch; inspect delay slot.
0x0EC18    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0EC1C    90 12 a0 64    or  %o2, 0x64, %o0
0x0EC20    c4 02 00 00    ld  [ %o0 ], %g2
0x0EC24    80 88 a0 02    btst  2, %g2
0x0EC28    02 bf ff fe    be  0xec20                             ! Conditional/control branch; inspect delay slot.
0x0EC2C    84 10 00 09    mov  %o1, %g2
0x0EC30    80 a0 80 0b    cmp  %g2, %o3
0x0EC34    04 bf ff f2    ble  0xebfc                            ! Conditional/control branch; inspect delay slot.
0x0EC38    92 00 a0 01    add  %g2, 1, %o1
0x0EC3C    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x0EC40    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0EC44    86 10 20 00    clr  %g3                               ! 0x0
0x0EC48    80 a0 c0 0a    cmp  %g3, %o2
0x0EC4C    34 80 00 27    bg,a   0xece8
0x0EC50    90 10 3f ff    mov  -1, %o0
0x0EC54    c4 4a 00 00    ldsb  [ %o0 ], %g2
0x0EC58    10 80 00 03    b  0xec64                              ! Conditional/control branch; inspect delay slot.
0x0EC5C    96 10 00 08    mov  %o0, %o3
0x0EC60    c4 4a 00 00    ldsb  [ %o0 ], %g2
0x0EC64    80 a0 a0 00    cmp  %g2, 0
0x0EC68    02 80 00 07    be  0xec84                             ! Conditional/control branch; inspect delay slot.
0x0EC6C    80 a0 a0 20    cmp  %g2, 0x20
0x0EC70    22 bf ff fc    be,a   0xec60                          ! Conditional/control branch; inspect delay slot.
0x0EC74    90 02 20 01    inc  %o0
0x0EC78    80 a0 a0 09    cmp  %g2, 9
0x0EC7C    22 bf ff f9    be,a   0xec60                          ! Conditional/control branch; inspect delay slot.
0x0EC80    90 02 20 01    inc  %o0
0x0EC84    80 a0 e0 00    cmp  %g3, 0
0x0EC88    02 80 00 03    be  0xec94                             ! Conditional/control branch; inspect delay slot.
0x0EC8C    c4 0a 00 00    ldub  [ %o0 ], %g2
0x0EC90    c0 2a c0 00    clrb  [ %o3 ]
0x0EC94    85 28 a0 18    sll  %g2, 0x18, %g2
0x0EC98    80 a0 a0 00    cmp  %g2, 0
0x0EC9C    02 80 00 12    be  0xece4                             ! Conditional/control branch; inspect delay slot.
0x0ECA0    85 28 e0 02    sll  %g3, 2, %g2
0x0ECA4    d0 22 40 02    st  %o0, [ %o1 + %g2 ]
0x0ECA8    c4 4a 00 00    ldsb  [ %o0 ], %g2
0x0ECAC    10 80 00 03    b  0xecb8                              ! Conditional/control branch; inspect delay slot.
0x0ECB0    86 00 e0 01    inc  %g3
0x0ECB4    c4 4a 00 00    ldsb  [ %o0 ], %g2
0x0ECB8    80 a0 a0 00    cmp  %g2, 0
0x0ECBC    02 80 00 06    be  0xecd4                             ! Conditional/control branch; inspect delay slot.
0x0ECC0    80 a0 a0 20    cmp  %g2, 0x20
0x0ECC4    02 80 00 04    be  0xecd4                             ! Conditional/control branch; inspect delay slot.
0x0ECC8    80 a0 a0 09    cmp  %g2, 9
0x0ECCC    32 bf ff fa    bne,a   0xecb4                         ! Conditional/control branch; inspect delay slot.
0x0ECD0    90 02 20 01    inc  %o0
0x0ECD4    c4 4a 00 00    ldsb  [ %o0 ], %g2
0x0ECD8    80 a0 a0 00    cmp  %g2, 0
0x0ECDC    12 bf ff dc    bne  0xec4c                            ! Conditional/control branch; inspect delay slot.
0x0ECE0    80 a0 c0 0a    cmp  %g3, %o2
0x0ECE4    90 10 00 03    mov  %g3, %o0
0x0ECE8    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x0ECEC    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0ECF0    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0ECF4    10 80 00 09    b  0xed18                              ! Conditional/control branch; inspect delay slot.
0x0ECF8    a0 10 20 00    clr  %l0
0x0ECFC    90 0a 60 ff    and  %o1, 0xff, %o0
0x0ED00    7f ff ff 98    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0ED04    a0 04 20 01    inc  %l0
0x0ED08    90 06 7f ff    add  %i1, -1, %o0
0x0ED0C    80 a4 00 08    cmp  %l0, %o0
0x0ED10    36 80 00 1d    bge,a   0xed84                         ! Conditional/control branch; inspect delay slot.
0x0ED14    c0 2e 00 10    clrb  [ %i0 + %l0 ]
0x0ED18    40 00 00 1d    call  0xed8c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0ED1C    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0ED20    92 10 00 08    mov  %o0, %o1
0x0ED24    91 2a 60 18    sll  %o1, 0x18, %o0
0x0ED28    91 3a 20 18    sra  %o0, 0x18, %o0
0x0ED2C    80 a2 20 08    cmp  %o0, 8
0x0ED30    12 80 00 0e    bne  0xed68                            ! Conditional/control branch; inspect delay slot.
0x0ED34    80 a2 20 0d    cmp  %o0, 0xd
0x0ED38    80 a4 20 00    cmp  %l0, 0
0x0ED3C    12 80 00 06    bne  0xed54                            ! Conditional/control branch; inspect delay slot.
0x0ED40    90 10 20 20    mov  0x20, %o0
0x0ED44    7f ff ff 87    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0ED48    90 10 20 07    mov  7, %o0
0x0ED4C    10 bf ff f0    b  0xed0c                              ! Conditional/control branch; inspect delay slot.
0x0ED50    90 06 7f ff    add  %i1, -1, %o0
0x0ED54    d0 2e 00 10    stb  %o0, [ %i0 + %l0 ]
0x0ED58    7f ff ff 99    call  0xebbc                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0ED5C    a0 04 3f ff    add  %l0, -1, %l0
0x0ED60    10 bf ff eb    b  0xed0c                              ! Conditional/control branch; inspect delay slot.
0x0ED64    90 06 7f ff    add  %i1, -1, %o0
0x0ED68    32 bf ff e5    bne,a   0xecfc                         ! Conditional/control branch; inspect delay slot.
0x0ED6C    d2 2e 00 10    stb  %o1, [ %i0 + %l0 ]
0x0ED70    7f ff ff 7c    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0ED74    90 0a 60 ff    and  %o1, 0xff, %o0
0x0ED78    7f ff ff 7a    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0ED7C    90 10 20 0a    mov  0xa, %o0
0x0ED80    c0 2e 00 10    clrb  [ %i0 + %l0 ]
0x0ED84    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0ED88    81 e8 00 00    restore                                ! Restore previous register window.
0x0ED8C    84 10 20 63    mov  0x63, %g2
0x0ED90    84 80 bf ff    addcc  %g2, -1, %g2
0x0ED94    1c 80 00 00    bpos  0xed94                           ! Conditional/control branch; inspect delay slot.
0x0ED98    84 80 bf ff    addcc  %g2, -1, %g2
0x0ED9C    05 08 00 00    sethi  %hi(0x20000000), %g2            ! Build high part of constant/address.
0x0EDA0    86 10 a0 64    or  %g2, 0x64, %g3                     ! 0x20000064
0x0EDA4    c4 00 c0 00    ld  [ %g3 ], %g2
0x0EDA8    80 88 a0 01    btst  1, %g2
0x0EDAC    02 bf ff fe    be  0xeda4                             ! Conditional/control branch; inspect delay slot.
0x0EDB0    05 08 00 00    sethi  %hi(0x20000000), %g2            ! Build high part of constant/address.
0x0EDB4    84 10 a0 60    or  %g2, 0x60, %g2                     ! 0x20000060
0x0EDB8    d0 00 80 00    ld  [ %g2 ], %o0
0x0EDBC    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x0EDC0    90 0a 20 ff    and  %o0, 0xff, %o0
0x0EDC4    86 10 20 63    mov  0x63, %g3
0x0EDC8    86 80 ff ff    addcc  %g3, -1, %g3
0x0EDCC    1c 80 00 00    bpos  0xedcc                           ! Conditional/control branch; inspect delay slot.
0x0EDD0    86 80 ff ff    addcc  %g3, -1, %g3
0x0EDD4    05 08 00 00    sethi  %hi(0x20000000), %g2            ! Build high part of constant/address.
0x0EDD8    9a 10 00 02    mov  %g2, %o5
0x0EDDC    98 10 a0 64    or  %g2, 0x64, %o4
0x0EDE0    96 10 a0 60    or  %g2, 0x60, %o3
0x0EDE4    86 10 20 00    clr  %g3
0x0EDE8    94 10 20 00    clr  %o2
0x0EDEC    c4 03 00 00    ld  [ %o4 ], %g2
0x0EDF0    80 88 a0 01    btst  1, %g2
0x0EDF4    12 80 00 0c    bne  0xee24                            ! Conditional/control branch; inspect delay slot.
0x0EDF8    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0EDFC    13 00 01 40    sethi  %hi(0x50000), %o1               ! Build high part of constant/address.
0x0EE00    90 13 60 64    or  %o5, 0x64, %o0
0x0EE04    86 00 e0 01    inc  %g3
0x0EE08    80 a0 c0 09    cmp  %g3, %o1
0x0EE0C    34 80 00 13    bg,a   0xee58
0x0EE10    90 10 20 ff    mov  0xff, %o0
0x0EE14    c4 02 00 00    ld  [ %o0 ], %g2
0x0EE18    80 88 a0 01    btst  1, %g2
0x0EE1C    22 bf ff fb    be,a   0xee08                          ! Conditional/control branch; inspect delay slot.
0x0EE20    86 00 e0 01    inc  %g3
0x0EE24    c4 02 c0 00    ld  [ %o3 ], %g2
0x0EE28    84 08 a0 ff    and  %g2, 0xff, %g2
0x0EE2C    80 a0 a0 69    cmp  %g2, 0x69
0x0EE30    02 80 00 04    be  0xee40                             ! Conditional/control branch; inspect delay slot.
0x0EE34    80 a0 a0 49    cmp  %g2, 0x49
0x0EE38    12 80 00 04    bne  0xee48                            ! Conditional/control branch; inspect delay slot.
0x0EE3C    94 02 a0 01    inc  %o2
0x0EE40    10 80 00 06    b  0xee58                              ! Conditional/control branch; inspect delay slot.
0x0EE44    90 10 20 00    clr  %o0
0x0EE48    84 0a a0 ff    and  %o2, 0xff, %g2
0x0EE4C    80 a0 a0 02    cmp  %g2, 2
0x0EE50    08 bf ff e7    bleu  0xedec                           ! Conditional/control branch; inspect delay slot.
0x0EE54    90 10 20 ff    mov  0xff, %o0
0x0EE58    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x0EE5C    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0EE60    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0EE64    21 08 00 00    sethi  %hi(0x20000000), %l0            ! Build high part of constant/address.
0x0EE68    94 14 20 40    or  %l0, 0x40, %o2                     ! 0x20000040
0x0EE6C    11 00 00 20    sethi  %hi(0x8000), %o0                ! Build high part of constant/address.
0x0EE70    d0 22 80 00    st  %o0, [ %o2 ]
0x0EE74    92 14 20 44    or  %l0, 0x44, %o1
0x0EE78    90 10 22 62    mov  0x262, %o0
0x0EE7C    d0 22 40 00    st  %o0, [ %o1 ]
0x0EE80    92 14 20 50    or  %l0, 0x50, %o1
0x0EE84    11 00 00 6a    sethi  %hi(0x1a800), %o0               ! Build high part of constant/address.
0x0EE88    d0 22 40 00    st  %o0, [ %o1 ]
0x0EE8C    29 21 e0 dc    sethi  %hi(0x87837000), %l4            ! Build high part of constant/address.
0x0EE90    e2 0d 23 b0    ldub  [ %l4 + 0x3b0 ], %l1             ! 0x878373b0
0x0EE94    90 10 21 00    mov  0x100, %o0
0x0EE98    d0 22 80 00    st  %o0, [ %o2 ]
0x0EE9C    6a 1f 35 59    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EEA0    90 10 23 e8    mov  0x3e8, %o0
0x0EEA4    aa 14 20 c0    or  %l0, 0xc0, %l5
0x0EEA8    d0 05 40 00    ld  [ %l5 ], %o0
0x0EEAC    a6 10 00 11    mov  %l1, %l3
0x0EEB0    80 8a 20 80    btst  0x80, %o0
0x0EEB4    02 80 00 04    be  0xeec4                             ! Conditional/control branch; inspect delay slot.
0x0EEB8    a4 10 00 11    mov  %l1, %l2
0x0EEBC    10 80 00 53    b  0xf008                              ! Conditional/control branch; inspect delay slot.
0x0EEC0    b0 10 20 00    clr  %i0
0x0EEC4    d0 0d 23 b0    ldub  [ %l4 + 0x3b0 ], %o0
0x0EEC8    80 a2 20 00    cmp  %o0, 0
0x0EECC    02 80 00 04    be  0xeedc                             ! Conditional/control branch; inspect delay slot.
0x0EED0    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0EED4    40 00 0d 93    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EED8    90 12 22 38    or  %o0, 0x238, %o0                    ! 0x87836a38
0x0EEDC    d0 05 40 00    ld  [ %l5 ], %o0
0x0EEE0    80 8a 20 80    btst  0x80, %o0
0x0EEE4    12 80 00 47    bne  0xf000                            ! Conditional/control branch; inspect delay slot.
0x0EEE8    90 10 20 00    clr  %o0
0x0EEEC    94 14 20 4c    or  %l0, 0x4c, %o2
0x0EEF0    d2 02 80 00    ld  [ %o2 ], %o1
0x0EEF4    11 00 3f fe    sethi  %hi(0xfff800), %o0              ! Build high part of constant/address.
0x0EEF8    80 8a 40 08    btst  %o1, %o0
0x0EEFC    02 80 00 41    be  0xf000                             ! Conditional/control branch; inspect delay slot.
0x0EF00    90 10 20 00    clr  %o0
0x0EF04    a8 10 00 10    mov  %l0, %l4
0x0EF08    a0 10 00 0a    mov  %o2, %l0
0x0EF0C    d0 04 00 00    ld  [ %l0 ], %o0
0x0EF10    92 10 20 35    mov  0x35, %o1
0x0EF14    91 32 20 0b    srl  %o0, 0xb, %o0
0x0EF18    b0 22 40 08    sub  %o1, %o0, %i0
0x0EF1C    80 a6 20 33    cmp  %i0, 0x33
0x0EF20    14 80 00 1e    bg  0xef98                             ! Conditional/control branch; inspect delay slot.
0x0EF24    90 10 20 00    clr  %o0
0x0EF28    80 a6 20 31    cmp  %i0, 0x31
0x0EF2C    04 80 00 0b    ble  0xef58                            ! Conditional/control branch; inspect delay slot.
0x0EF30    80 a6 20 1f    cmp  %i0, 0x1f
0x0EF34    40 00 02 f0    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EF38    92 10 20 0f    mov  0xf, %o1
0x0EF3C    80 a4 a0 00    cmp  %l2, 0
0x0EF40    02 80 00 24    be  0xefd0                             ! Conditional/control branch; inspect delay slot.
0x0EF44    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0EF48    90 12 22 48    or  %o0, 0x248, %o0                    ! 0x87836a48
0x0EF4C    40 00 0d 75    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EF50    a4 10 20 00    clr  %l2
0x0EF54    30 80 00 1f    b,a   0xefd0                           ! Conditional/control branch; inspect delay slot.
0x0EF58    14 80 00 10    bg  0xef98                             ! Conditional/control branch; inspect delay slot.
0x0EF5C    90 10 20 00    clr  %o0
0x0EF60    80 a6 20 1d    cmp  %i0, 0x1d
0x0EF64    04 80 00 0b    ble  0xef90                            ! Conditional/control branch; inspect delay slot.
0x0EF68    80 a6 20 06    cmp  %i0, 6
0x0EF6C    40 00 02 e2    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EF70    92 10 20 0f    mov  0xf, %o1
0x0EF74    80 a4 e0 00    cmp  %l3, 0
0x0EF78    02 80 00 16    be  0xefd0                             ! Conditional/control branch; inspect delay slot.
0x0EF7C    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0EF80    90 12 22 58    or  %o0, 0x258, %o0                    ! 0x87836a58
0x0EF84    40 00 0d 67    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EF88    a6 10 20 00    clr  %l3
0x0EF8C    30 80 00 11    b,a   0xefd0                           ! Conditional/control branch; inspect delay slot.
0x0EF90    04 80 00 05    ble  0xefa4                            ! Conditional/control branch; inspect delay slot.
0x0EF94    90 10 20 00    clr  %o0
0x0EF98    40 00 02 d7    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EF9C    92 10 20 00    clr  %o1
0x0EFA0    30 80 00 0c    b,a   0xefd0                           ! Conditional/control branch; inspect delay slot.
0x0EFA4    80 a6 20 04    cmp  %i0, 4
0x0EFA8    04 80 00 0a    ble  0xefd0                            ! Conditional/control branch; inspect delay slot.
0x0EFAC    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0EFB0    40 00 02 d1    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EFB4    92 10 20 0f    mov  0xf, %o1                          ! 0xf
0x0EFB8    80 a4 60 00    cmp  %l1, 0
0x0EFBC    02 80 00 05    be  0xefd0                             ! Conditional/control branch; inspect delay slot.
0x0EFC0    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0EFC4    90 12 22 70    or  %o0, 0x270, %o0                    ! 0x87836a70
0x0EFC8    40 00 0d 56    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EFCC    a2 10 20 00    clr  %l1
0x0EFD0    6a 1f 35 0c    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0EFD4    90 10 20 01    mov  1, %o0
0x0EFD8    90 15 20 c0    or  %l4, 0xc0, %o0
0x0EFDC    d2 02 00 00    ld  [ %o0 ], %o1
0x0EFE0    80 8a 60 80    btst  0x80, %o1
0x0EFE4    12 80 00 07    bne  0xf000                            ! Conditional/control branch; inspect delay slot.
0x0EFE8    90 10 20 00    clr  %o0
0x0EFEC    d2 04 00 00    ld  [ %l0 ], %o1
0x0EFF0    11 00 3f fe    sethi  %hi(0xfff800), %o0              ! Build high part of constant/address.
0x0EFF4    80 8a 40 08    btst  %o1, %o0
0x0EFF8    12 bf ff c5    bne  0xef0c                            ! Conditional/control branch; inspect delay slot.
0x0EFFC    90 10 20 00    clr  %o0

! ============================================================================
! 0x0F000: Dense executable-looking region; MMIO and RAM references recur.
! ============================================================================
0x0F000    40 00 02 bd    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F004    92 10 20 00    clr  %o1
0x0F008    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0F00C    81 e8 00 00    restore                                ! Restore previous register window.
0x0F010    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0F014    21 08 00 00    sethi  %hi(0x20000000), %l0            ! Build high part of constant/address.
0x0F018    94 14 20 40    or  %l0, 0x40, %o2                     ! 0x20000040
0x0F01C    11 00 00 20    sethi  %hi(0x8000), %o0                ! Build high part of constant/address.
0x0F020    d0 22 80 00    st  %o0, [ %o2 ]
0x0F024    92 14 20 44    or  %l0, 0x44, %o1
0x0F028    90 10 22 62    mov  0x262, %o0
0x0F02C    d0 22 40 00    st  %o0, [ %o1 ]
0x0F030    92 14 20 50    or  %l0, 0x50, %o1
0x0F034    11 00 00 10    sethi  %hi(0x4000), %o0                ! Build high part of constant/address.
0x0F038    d0 22 40 00    st  %o0, [ %o1 ]
0x0F03C    27 21 e0 dc    sethi  %hi(0x87837000), %l3            ! Build high part of constant/address.
0x0F040    e2 0c e3 b0    ldub  [ %l3 + 0x3b0 ], %l1             ! 0x878373b0
0x0F044    90 10 21 00    mov  0x100, %o0
0x0F048    d0 22 80 00    st  %o0, [ %o2 ]
0x0F04C    6a 1f 34 ed    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F050    90 10 23 e8    mov  0x3e8, %o0
0x0F054    a8 14 20 c0    or  %l0, 0xc0, %l4
0x0F058    d0 05 00 00    ld  [ %l4 ], %o0
0x0F05C    80 8a 20 01    btst  1, %o0
0x0F060    02 80 00 04    be  0xf070                             ! Conditional/control branch; inspect delay slot.
0x0F064    a4 10 00 11    mov  %l1, %l2
0x0F068    10 80 00 47    b  0xf184                              ! Conditional/control branch; inspect delay slot.
0x0F06C    b0 10 20 00    clr  %i0
0x0F070    d0 0c e3 b0    ldub  [ %l3 + 0x3b0 ], %o0
0x0F074    80 a2 20 00    cmp  %o0, 0
0x0F078    02 80 00 04    be  0xf088                             ! Conditional/control branch; inspect delay slot.
0x0F07C    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F080    40 00 0d 28    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F084    90 12 22 88    or  %o0, 0x288, %o0                    ! 0x87836a88
0x0F088    d0 05 00 00    ld  [ %l4 ], %o0
0x0F08C    80 8a 20 01    btst  1, %o0
0x0F090    12 80 00 3b    bne  0xf17c                            ! Conditional/control branch; inspect delay slot.
0x0F094    90 10 20 00    clr  %o0
0x0F098    94 14 20 4c    or  %l0, 0x4c, %o2
0x0F09C    d2 02 80 00    ld  [ %o2 ], %o1
0x0F0A0    11 00 3f fe    sethi  %hi(0xfff800), %o0              ! Build high part of constant/address.
0x0F0A4    80 8a 40 08    btst  %o1, %o0
0x0F0A8    02 80 00 35    be  0xf17c                             ! Conditional/control branch; inspect delay slot.
0x0F0AC    90 10 20 00    clr  %o0
0x0F0B0    a8 10 00 10    mov  %l0, %l4
0x0F0B4    a0 10 00 0a    mov  %o2, %l0
0x0F0B8    27 21 e0 da    sethi  %hi(0x87836800), %l3            ! Build high part of constant/address.
0x0F0BC    d0 04 00 00    ld  [ %l0 ], %o0
0x0F0C0    92 10 20 08    mov  8, %o1
0x0F0C4    91 32 20 0b    srl  %o0, 0xb, %o0
0x0F0C8    b0 22 40 08    sub  %o1, %o0, %i0
0x0F0CC    80 a6 20 07    cmp  %i0, 7
0x0F0D0    14 80 00 11    bg  0xf114                             ! Conditional/control branch; inspect delay slot.
0x0F0D4    90 10 20 00    clr  %o0
0x0F0D8    80 a6 20 05    cmp  %i0, 5
0x0F0DC    04 80 00 0c    ble  0xf10c                            ! Conditional/control branch; inspect delay slot.
0x0F0E0    80 a6 20 02    cmp  %i0, 2
0x0F0E4    40 00 02 84    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F0E8    92 10 20 0f    mov  0xf, %o1
0x0F0EC    90 0c a0 ff    and  %l2, 0xff, %o0
0x0F0F0    80 a2 20 00    cmp  %o0, 0
0x0F0F4    02 80 00 16    be  0xf14c                             ! Conditional/control branch; inspect delay slot.
0x0F0F8    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0F0FC    a4 10 20 00    clr  %l2                               ! 0x0
0x0F100    40 00 0d 08    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F104    90 14 e2 98    or  %l3, 0x298, %o0
0x0F108    30 80 00 11    b,a   0xf14c                           ! Conditional/control branch; inspect delay slot.
0x0F10C    04 80 00 05    ble  0xf120                            ! Conditional/control branch; inspect delay slot.
0x0F110    90 10 20 00    clr  %o0
0x0F114    40 00 02 78    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F118    92 10 20 00    clr  %o1
0x0F11C    30 80 00 0c    b,a   0xf14c                           ! Conditional/control branch; inspect delay slot.
0x0F120    80 a6 20 00    cmp  %i0, 0
0x0F124    04 80 00 0a    ble  0xf14c                            ! Conditional/control branch; inspect delay slot.
0x0F128    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0F12C    40 00 02 72    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F130    92 10 20 0f    mov  0xf, %o1                          ! 0xf
0x0F134    80 a4 60 00    cmp  %l1, 0
0x0F138    02 80 00 05    be  0xf14c                             ! Conditional/control branch; inspect delay slot.
0x0F13C    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F140    90 12 22 a8    or  %o0, 0x2a8, %o0                    ! 0x87836aa8
0x0F144    40 00 0c f7    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F148    a2 10 20 00    clr  %l1
0x0F14C    6a 1f 34 ad    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F150    90 10 20 01    mov  1, %o0
0x0F154    90 15 20 c0    or  %l4, 0xc0, %o0
0x0F158    d2 02 00 00    ld  [ %o0 ], %o1
0x0F15C    80 8a 60 01    btst  1, %o1
0x0F160    12 80 00 07    bne  0xf17c                            ! Conditional/control branch; inspect delay slot.
0x0F164    90 10 20 00    clr  %o0
0x0F168    d2 04 00 00    ld  [ %l0 ], %o1
0x0F16C    11 00 3f fe    sethi  %hi(0xfff800), %o0              ! Build high part of constant/address.
0x0F170    80 8a 40 08    btst  %o1, %o0
0x0F174    12 bf ff d2    bne  0xf0bc                            ! Conditional/control branch; inspect delay slot.
0x0F178    90 10 20 00    clr  %o0
0x0F17C    40 00 02 5e    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F180    92 10 20 00    clr  %o1
0x0F184    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0F188    81 e8 00 00    restore                                ! Restore previous register window.
0x0F18C    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0F190    21 08 00 00    sethi  %hi(0x20000000), %l0            ! Build high part of constant/address.
0x0F194    96 14 20 40    or  %l0, 0x40, %o3                     ! 0x20000040
0x0F198    11 00 00 20    sethi  %hi(0x8000), %o0                ! Build high part of constant/address.
0x0F19C    d0 22 c0 00    st  %o0, [ %o3 ]
0x0F1A0    92 14 20 44    or  %l0, 0x44, %o1
0x0F1A4    90 10 22 62    mov  0x262, %o0
0x0F1A8    d0 22 40 00    st  %o0, [ %o1 ]
0x0F1AC    94 14 20 50    or  %l0, 0x50, %o2
0x0F1B0    11 00 00 6a    sethi  %hi(0x1a800), %o0               ! Build high part of constant/address.
0x0F1B4    d0 22 80 00    st  %o0, [ %o2 ]
0x0F1B8    92 10 21 00    mov  0x100, %o1
0x0F1BC    d2 22 c0 00    st  %o1, [ %o3 ]
0x0F1C0    6a 1f 34 90    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F1C4    90 10 23 e8    mov  0x3e8, %o0
0x0F1C8    90 14 20 14    or  %l0, 0x14, %o0
0x0F1CC    d2 02 00 00    ld  [ %o0 ], %o1
0x0F1D0    b0 10 20 00    clr  %i0
0x0F1D4    80 8a 68 00    btst  0x800, %o1
0x0F1D8    02 80 00 6a    be  0xf380                             ! Conditional/control branch; inspect delay slot.
0x0F1DC    a2 10 20 00    clr  %l1
0x0F1E0    94 14 20 4c    or  %l0, 0x4c, %o2
0x0F1E4    d2 02 80 00    ld  [ %o2 ], %o1
0x0F1E8    11 00 3f fe    sethi  %hi(0xfff800), %o0              ! Build high part of constant/address.
0x0F1EC    80 8a 40 08    btst  %o1, %o0
0x0F1F0    02 80 00 65    be  0xf384                             ! Conditional/control branch; inspect delay slot.
0x0F1F4    90 10 20 00    clr  %o0
0x0F1F8    a4 10 00 10    mov  %l0, %l2
0x0F1FC    a6 14 20 1c    or  %l0, 0x1c, %l3
0x0F200    a0 10 00 0a    mov  %o2, %l0
0x0F204    d0 04 00 00    ld  [ %l0 ], %o0
0x0F208    92 10 20 35    mov  0x35, %o1
0x0F20C    91 32 20 0b    srl  %o0, 0xb, %o0
0x0F210    b0 22 40 08    sub  %o1, %o0, %i0
0x0F214    80 a6 20 05    cmp  %i0, 5
0x0F218    02 80 00 0c    be  0xf248                             ! Conditional/control branch; inspect delay slot.
0x0F21C    80 a6 20 0a    cmp  %i0, 0xa
0x0F220    02 80 00 0a    be  0xf248                             ! Conditional/control branch; inspect delay slot.
0x0F224    80 a6 20 0f    cmp  %i0, 0xf
0x0F228    02 80 00 08    be  0xf248                             ! Conditional/control branch; inspect delay slot.
0x0F22C    80 a6 20 14    cmp  %i0, 0x14
0x0F230    02 80 00 06    be  0xf248                             ! Conditional/control branch; inspect delay slot.
0x0F234    80 a6 20 19    cmp  %i0, 0x19
0x0F238    02 80 00 04    be  0xf248                             ! Conditional/control branch; inspect delay slot.
0x0F23C    80 a6 20 32    cmp  %i0, 0x32
0x0F240    32 80 00 07    bne,a   0xf25c                         ! Conditional/control branch; inspect delay slot.
0x0F244    90 10 20 00    clr  %o0
0x0F248    90 10 20 00    clr  %o0
0x0F24C    40 00 02 2a    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F250    92 10 20 0f    mov  0xf, %o1
0x0F254    10 80 00 05    b  0xf268                              ! Conditional/control branch; inspect delay slot.
0x0F258    90 10 28 00    mov  0x800, %o0
0x0F25C    40 00 02 26    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F260    92 10 20 00    clr  %o1
0x0F264    90 10 28 00    mov  0x800, %o0
0x0F268    d0 24 c0 00    st  %o0, [ %l3 ]
0x0F26C    6a 1f 34 65    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F270    90 10 20 01    mov  1, %o0
0x0F274    80 a6 00 11    cmp  %i0, %l1
0x0F278    24 80 00 39    ble,a   0xf35c                         ! Conditional/control branch; inspect delay slot.
0x0F27C    90 14 a0 14    or  %l2, 0x14, %o0
0x0F280    7f ff fe 1f    call  0xeafc                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F284    90 10 00 18    mov  %i0, %o0
0x0F288    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F28C    7f ff fd f3    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F290    90 12 22 b8    or  %o0, 0x2b8, %o0                    ! 0x87836ab8
0x0F294    80 a6 20 01    cmp  %i0, 1
0x0F298    12 80 00 07    bne  0xf2b4                            ! Conditional/control branch; inspect delay slot.
0x0F29C    a2 10 00 18    mov  %i0, %l1
0x0F2A0    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F2A4    40 00 0c 9f    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F2A8    90 12 22 c0    or  %o0, 0x2c0, %o0                    ! 0x87836ac0
0x0F2AC    10 80 00 2c    b  0xf35c                              ! Conditional/control branch; inspect delay slot.
0x0F2B0    90 14 a0 14    or  %l2, 0x14, %o0
0x0F2B4    80 a6 20 05    cmp  %i0, 5
0x0F2B8    12 80 00 07    bne  0xf2d4                            ! Conditional/control branch; inspect delay slot.
0x0F2BC    80 a6 20 0a    cmp  %i0, 0xa
0x0F2C0    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F2C4    40 00 0c 97    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F2C8    90 12 22 d0    or  %o0, 0x2d0, %o0                    ! 0x87836ad0
0x0F2CC    10 80 00 24    b  0xf35c                              ! Conditional/control branch; inspect delay slot.
0x0F2D0    90 14 a0 14    or  %l2, 0x14, %o0
0x0F2D4    12 80 00 07    bne  0xf2f0                            ! Conditional/control branch; inspect delay slot.
0x0F2D8    80 a6 20 0f    cmp  %i0, 0xf
0x0F2DC    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F2E0    40 00 0c 90    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F2E4    90 12 22 e8    or  %o0, 0x2e8, %o0                    ! 0x87836ae8
0x0F2E8    10 80 00 1d    b  0xf35c                              ! Conditional/control branch; inspect delay slot.
0x0F2EC    90 14 a0 14    or  %l2, 0x14, %o0
0x0F2F0    12 80 00 07    bne  0xf30c                            ! Conditional/control branch; inspect delay slot.
0x0F2F4    80 a6 20 14    cmp  %i0, 0x14
0x0F2F8    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F2FC    40 00 0c 89    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F300    90 12 22 f8    or  %o0, 0x2f8, %o0                    ! 0x87836af8
0x0F304    10 80 00 16    b  0xf35c                              ! Conditional/control branch; inspect delay slot.
0x0F308    90 14 a0 14    or  %l2, 0x14, %o0
0x0F30C    12 80 00 07    bne  0xf328                            ! Conditional/control branch; inspect delay slot.
0x0F310    80 a6 20 19    cmp  %i0, 0x19
0x0F314    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F318    40 00 0c 82    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F31C    90 12 23 10    or  %o0, 0x310, %o0                    ! 0x87836b10
0x0F320    10 80 00 0f    b  0xf35c                              ! Conditional/control branch; inspect delay slot.
0x0F324    90 14 a0 14    or  %l2, 0x14, %o0
0x0F328    12 80 00 07    bne  0xf344                            ! Conditional/control branch; inspect delay slot.
0x0F32C    80 a6 20 32    cmp  %i0, 0x32
0x0F330    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F334    40 00 0c 7b    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F338    90 12 23 20    or  %o0, 0x320, %o0                    ! 0x87836b20
0x0F33C    10 80 00 08    b  0xf35c                              ! Conditional/control branch; inspect delay slot.
0x0F340    90 14 a0 14    or  %l2, 0x14, %o0
0x0F344    32 80 00 06    bne,a   0xf35c                         ! Conditional/control branch; inspect delay slot.
0x0F348    90 14 a0 14    or  %l2, 0x14, %o0
0x0F34C    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F350    40 00 0c 74    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F354    90 12 22 48    or  %o0, 0x248, %o0                    ! 0x87836a48
0x0F358    90 14 a0 14    or  %l2, 0x14, %o0
0x0F35C    d2 02 00 00    ld  [ %o0 ], %o1
0x0F360    80 8a 68 00    btst  0x800, %o1
0x0F364    02 80 00 08    be  0xf384                             ! Conditional/control branch; inspect delay slot.
0x0F368    90 10 20 00    clr  %o0
0x0F36C    d2 04 00 00    ld  [ %l0 ], %o1
0x0F370    11 00 3f fe    sethi  %hi(0xfff800), %o0              ! Build high part of constant/address.
0x0F374    80 8a 40 08    btst  %o1, %o0
0x0F378    12 bf ff a3    bne  0xf204                            ! Conditional/control branch; inspect delay slot.
0x0F37C    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0F380    90 10 20 00    clr  %o0                               ! 0x0
0x0F384    40 00 01 dc    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F388    92 10 20 00    clr  %o1
0x0F38C    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0F390    81 e8 00 00    restore                                ! Restore previous register window.
0x0F394    96 10 00 08    mov  %o0, %o3
0x0F398    c4 0a e1 fe    ldub  [ %o3 + 0x1fe ], %g2
0x0F39C    80 a0 a0 30    cmp  %g2, 0x30
0x0F3A0    12 80 00 06    bne  0xf3b8                            ! Conditional/control branch; inspect delay slot.
0x0F3A4    94 10 20 00    clr  %o2
0x0F3A8    c4 0a e1 ff    ldub  [ %o3 + 0x1ff ], %g2
0x0F3AC    80 a0 a0 65    cmp  %g2, 0x65
0x0F3B0    02 80 00 04    be  0xf3c0                             ! Conditional/control branch; inspect delay slot.
0x0F3B4    92 10 21 00    mov  0x100, %o1
0x0F3B8    10 80 00 13    b  0xf404                              ! Conditional/control branch; inspect delay slot.
0x0F3BC    90 10 20 01    mov  1, %o0
0x0F3C0    85 2a 60 10    sll  %o1, 0x10, %g2
0x0F3C4    85 30 a0 10    srl  %g2, 0x10, %g2
0x0F3C8    92 02 60 02    add  %o1, 2, %o1
0x0F3CC    d0 12 c0 02    lduh  [ %o3 + %g2 ], %o0
0x0F3D0    87 2a 60 10    sll  %o1, 0x10, %g3
0x0F3D4    84 02 80 08    add  %o2, %o0, %g2
0x0F3D8    87 30 e0 10    srl  %g3, 0x10, %g3
0x0F3DC    80 a0 e1 ff    cmp  %g3, 0x1ff
0x0F3E0    08 bf ff f8    bleu  0xf3c0                           ! Conditional/control branch; inspect delay slot.
0x0F3E4    94 10 00 02    mov  %g2, %o2
0x0F3E8    87 28 a0 10    sll  %g2, 0x10, %g3
0x0F3EC    05 00 00 2f    sethi  %hi(0xbc00), %g2                ! Build high part of constant/address.
0x0F3F0    87 30 e0 10    srl  %g3, 0x10, %g3
0x0F3F4    84 10 a2 ef    or  %g2, 0x2ef, %g2
0x0F3F8    86 18 c0 02    xor  %g3, %g2, %g3
0x0F3FC    80 a0 00 03    cmp  %g0, %g3
0x0F400    90 40 20 00    addx  %g0, 0, %o0
0x0F404    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x0F408    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0F40C    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0F410    23 21 e0 00    sethi  %hi(0x87800000), %l1            ! Build high part of constant/address.
0x0F414    92 10 00 11    mov  %l1, %o1
0x0F418    7f ff f6 cb    call  0xcf44                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F41C    90 10 20 40    mov  0x40, %o0
0x0F420    7f ff ff dd    call  0xf394                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F424    90 10 00 11    mov  %l1, %o0
0x0F428    90 0a 20 ff    and  %o0, 0xff, %o0
0x0F42C    80 a2 20 00    cmp  %o0, 0
0x0F430    02 80 00 0d    be  0xf464                             ! Conditional/control branch; inspect delay slot.
0x0F434    25 20 00 00    sethi  %hi(0x80000000), %l2            ! Build high part of constant/address.
0x0F438    92 10 00 11    mov  %l1, %o1
0x0F43C    7f ff f6 c2    call  0xcf44                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F440    90 10 20 e0    mov  0xe0, %o0
0x0F444    7f ff ff d4    call  0xf394                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F448    90 10 00 11    mov  %l1, %o0
0x0F44C    90 0a 20 ff    and  %o0, 0xff, %o0
0x0F450    80 a2 20 00    cmp  %o0, 0
0x0F454    02 80 00 04    be  0xf464                             ! Conditional/control branch; inspect delay slot.
0x0F458    90 10 20 40    mov  0x40, %o0
0x0F45C    7f ff f6 ba    call  0xcf44                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F460    92 10 00 11    mov  %l1, %o1
0x0F464    d2 0c 61 06    ldub  [ %l1 + 0x106 ], %o1
0x0F468    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0F46C    d4 0c 61 07    ldub  [ %l1 + 0x107 ], %o2
0x0F470    93 2a 60 08    sll  %o1, 8, %o1
0x0F474    d6 02 23 a4    ld  [ %o0 + 0x3a4 ], %o3
0x0F478    94 12 80 09    or  %o2, %o1, %o2
0x0F47C    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0F480    d4 24 a0 04    st  %o2, [ %l2 + 4 ]
0x0F484    d6 24 80 00    st  %o3, [ %l2 ]
0x0F488    9a 12 23 68    or  %o0, 0x368, %o5
0x0F48C    a0 10 20 00    clr  %l0
0x0F490    98 04 a0 90    add  %l2, 0x90, %o4
0x0F494    84 04 a0 b0    add  %l2, 0xb0, %g2
0x0F498    86 04 a0 d0    add  %l2, 0xd0, %g3
0x0F49C    9e 04 a0 e4    add  %l2, 0xe4, %o7
0x0F4A0    27 21 e0 dc    sethi  %hi(0x87837000), %l3            ! Build high part of constant/address.
0x0F4A4    29 21 e0 dc    sethi  %hi(0x87837000), %l4            ! Build high part of constant/address.
0x0F4A8    96 14 a0 08    or  %l2, 8, %o3
0x0F4AC    94 10 00 11    mov  %l1, %o2
0x0F4B0    d0 0a a1 00    ldub  [ %o2 + 0x100 ], %o0
0x0F4B4    d0 2a c0 10    stb  %o0, [ %o3 + %l0 ]
0x0F4B8    d2 0a a1 00    ldub  [ %o2 + 0x100 ], %o1
0x0F4BC    d2 2b 40 10    stb  %o1, [ %o5 + %l0 ]
0x0F4C0    a0 04 20 01    inc  %l0
0x0F4C4    80 a4 20 05    cmp  %l0, 5
0x0F4C8    04 bf ff fa    ble  0xf4b0                            ! Conditional/control branch; inspect delay slot.
0x0F4CC    94 02 a0 01    inc  %o2
0x0F4D0    92 10 00 0c    mov  %o4, %o1
0x0F4D4    a0 10 20 00    clr  %l0
0x0F4D8    90 04 00 11    add  %l0, %l1, %o0
0x0F4DC    d0 0a 21 08    ldub  [ %o0 + 0x108 ], %o0
0x0F4E0    80 a2 20 0a    cmp  %o0, 0xa
0x0F4E4    32 80 00 03    bne,a   0xf4f0                         ! Conditional/control branch; inspect delay slot.
0x0F4E8    d0 2a 40 10    stb  %o0, [ %o1 + %l0 ]
0x0F4EC    c0 2a 40 10    clrb  [ %o1 + %l0 ]
0x0F4F0    a0 04 20 01    inc  %l0
0x0F4F4    80 a4 20 1f    cmp  %l0, 0x1f
0x0F4F8    04 bf ff f9    ble  0xf4dc                            ! Conditional/control branch; inspect delay slot.
0x0F4FC    90 04 00 11    add  %l0, %l1, %o0
0x0F500    92 10 00 02    mov  %g2, %o1
0x0F504    a0 10 20 00    clr  %l0
0x0F508    90 04 00 11    add  %l0, %l1, %o0
0x0F50C    d0 0a 21 28    ldub  [ %o0 + 0x128 ], %o0
0x0F510    80 a2 20 0a    cmp  %o0, 0xa
0x0F514    32 80 00 03    bne,a   0xf520                         ! Conditional/control branch; inspect delay slot.
0x0F518    d0 2a 40 10    stb  %o0, [ %o1 + %l0 ]
0x0F51C    c0 2a 40 10    clrb  [ %o1 + %l0 ]
0x0F520    a0 04 20 01    inc  %l0
0x0F524    80 a4 20 1f    cmp  %l0, 0x1f
0x0F528    04 bf ff f9    ble  0xf50c                            ! Conditional/control branch; inspect delay slot.
0x0F52C    90 04 00 11    add  %l0, %l1, %o0
0x0F530    92 10 00 03    mov  %g3, %o1
0x0F534    a0 10 20 00    clr  %l0
0x0F538    90 04 00 11    add  %l0, %l1, %o0
0x0F53C    d0 0a 21 48    ldub  [ %o0 + 0x148 ], %o0
0x0F540    80 a2 20 0a    cmp  %o0, 0xa
0x0F544    32 80 00 03    bne,a   0xf550                         ! Conditional/control branch; inspect delay slot.
0x0F548    d0 2a 40 10    stb  %o0, [ %o1 + %l0 ]
0x0F54C    c0 2a 40 10    clrb  [ %o1 + %l0 ]
0x0F550    a0 04 20 01    inc  %l0
0x0F554    80 a4 20 0f    cmp  %l0, 0xf
0x0F558    04 bf ff f9    ble  0xf53c                            ! Conditional/control branch; inspect delay slot.
0x0F55C    90 04 00 11    add  %l0, %l1, %o0
0x0F560    94 10 00 0f    mov  %o7, %o2
0x0F564    a0 10 20 00    clr  %l0
0x0F568    90 04 00 11    add  %l0, %l1, %o0
0x0F56C    d2 0a 21 80    ldub  [ %o0 + 0x180 ], %o1
0x0F570    d2 2a 80 10    stb  %o1, [ %o2 + %l0 ]
0x0F574    a0 04 20 01    inc  %l0
0x0F578    80 a4 20 7f    cmp  %l0, 0x7f
0x0F57C    04 bf ff fc    ble  0xf56c                            ! Conditional/control branch; inspect delay slot.
0x0F580    90 04 00 11    add  %l0, %l1, %o0
0x0F584    d0 0c 61 80    ldub  [ %l1 + 0x180 ], %o0
0x0F588    80 a2 20 03    cmp  %o0, 3
0x0F58C    32 80 00 07    bne,a   0xf5a8                         ! Conditional/control branch; inspect delay slot.
0x0F590    d0 0c 61 77    ldub  [ %l1 + 0x177 ], %o0
0x0F594    11 08 00 02    sethi  %hi(0x20000800), %o0            ! Build high part of constant/address.
0x0F598    90 12 20 0c    or  %o0, 0xc, %o0                      ! 0x2000080c
0x0F59C    92 10 20 2f    mov  0x2f, %o1
0x0F5A0    d2 22 00 00    st  %o1, [ %o0 ]
0x0F5A4    d0 0c 61 77    ldub  [ %l1 + 0x177 ], %o0
0x0F5A8    80 a2 20 01    cmp  %o0, 1
0x0F5AC    12 80 00 04    bne  0xf5bc                            ! Conditional/control branch; inspect delay slot.
0x0F5B0    80 a2 20 02    cmp  %o0, 2
0x0F5B4    10 80 00 05    b  0xf5c8                              ! Conditional/control branch; inspect delay slot.
0x0F5B8    90 10 20 43    mov  0x43, %o0
0x0F5BC    12 80 00 03    bne  0xf5c8                            ! Conditional/control branch; inspect delay slot.
0x0F5C0    90 10 20 41    mov  0x41, %o0
0x0F5C4    90 10 20 42    mov  0x42, %o0
0x0F5C8    d0 2c a0 0e    stb  %o0, [ %l2 + 0xe ]
0x0F5CC    d0 0c 61 88    ldub  [ %l1 + 0x188 ], %o0
0x0F5D0    a0 10 21 dc    mov  0x1dc, %l0
0x0F5D4    d2 04 61 78    ld  [ %l1 + 0x178 ], %o1
0x0F5D8    90 1a 20 ec    xor  %o0, 0xec, %o0
0x0F5DC    d8 0c 61 76    ldub  [ %l1 + 0x176 ], %o4
0x0F5E0    80 a0 00 08    cmp  %g0, %o0
0x0F5E4    d2 24 a0 e0    st  %o1, [ %l2 + 0xe0 ]
0x0F5E8    d6 0c 61 80    ldub  [ %l1 + 0x180 ], %o3
0x0F5EC    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0F5F0    94 60 3f ff    subx  %g0, -1, %o2
0x0F5F4    d4 2a 21 a0    stb  %o2, [ %o0 + 0x1a0 ]
0x0F5F8    d2 0c 61 83    ldub  [ %l1 + 0x183 ], %o1
0x0F5FC    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0F600    d6 2a 23 a8    stb  %o3, [ %o0 + 0x3a8 ]              ! 0x878373a8
0x0F604    d8 2c e3 70    stb  %o4, [ %l3 + 0x370 ]
0x0F608    d2 2d 23 71    stb  %o1, [ %l4 + 0x371 ]
0x0F60C    25 00 00 40    sethi  %hi(0x10000), %l2               ! Build high part of constant/address.
0x0F610    d4 0c 40 10    ldub  [ %l1 + %l0 ], %o2
0x0F614    90 0a a0 c0    and  %o2, 0xc0, %o0
0x0F618    80 a2 20 80    cmp  %o0, 0x80
0x0F61C    32 80 00 0d    bne,a   0xf650                         ! Conditional/control branch; inspect delay slot.
0x0F620    a0 04 20 02    add  %l0, 2, %l0
0x0F624    90 04 00 11    add  %l0, %l1, %o0
0x0F628    d2 0a 20 01    ldub  [ %o0 + 1 ], %o1
0x0F62C    95 2a a0 18    sll  %o2, 0x18, %o2
0x0F630    93 2a 60 08    sll  %o1, 8, %o1
0x0F634    92 12 40 12    or  %o1, %l2, %o1
0x0F638    92 12 80 09    or  %o2, %o1, %o1
0x0F63C    90 10 20 69    mov  0x69, %o0
0x0F640    94 10 20 00    clr  %o2
0x0F644    7f ff f5 89    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F648    96 10 20 03    mov  3, %o3
0x0F64C    a0 04 20 02    add  %l0, 2, %l0
0x0F650    80 a4 21 fb    cmp  %l0, 0x1fb
0x0F654    24 bf ff f0    ble,a   0xf614                         ! Conditional/control branch; inspect delay slot.
0x0F658    d4 0c 40 10    ldub  [ %l1 + %l0 ], %o2
0x0F65C    d0 0c e3 70    ldub  [ %l3 + 0x370 ], %o0
0x0F660    80 a2 20 ff    cmp  %o0, 0xff
0x0F664    22 80 00 02    be,a   0xf66c                          ! Conditional/control branch; inspect delay slot.
0x0F668    c0 2c e3 70    clrb  [ %l3 + 0x370 ]
0x0F66C    d0 0d 23 71    ldub  [ %l4 + 0x371 ], %o0
0x0F670    80 a2 20 ff    cmp  %o0, 0xff
0x0F674    22 80 00 02    be,a   0xf67c                          ! Conditional/control branch; inspect delay slot.
0x0F678    c0 2d 23 71    clrb  [ %l4 + 0x371 ]
0x0F67C    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0F680    81 e8 00 00    restore                                ! Restore previous register window.
0x0F684    9d e3 bf 90    save  %sp, -112, %sp                   ! Enter register window; allocate stack frame.
0x0F688    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F68C    7f ff fc f3    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F690    90 12 23 38    or  %o0, 0x338, %o0                    ! 0x87836b38
0x0F694    7f ff fd f3    call  0xee60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F698    25 20 00 00    sethi  %hi(0x80000000), %l2            ! Build high part of constant/address.
0x0F69C    90 0a 20 ff    and  %o0, 0xff, %o0
0x0F6A0    80 a2 20 31    cmp  %o0, 0x31
0x0F6A4    08 80 00 07    bleu  0xf6c0                           ! Conditional/control branch; inspect delay slot.
0x0F6A8    80 a2 20 1d    cmp  %o0, 0x1d
0x0F6AC    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F6B0    7f ff fc f5    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F6B4    90 12 23 40    or  %o0, 0x340, %o0                    ! 0x87836b40
0x0F6B8    10 80 00 ab    b  0xf964                              ! Conditional/control branch; inspect delay slot.
0x0F6BC    92 10 20 09    mov  9, %o1
0x0F6C0    08 80 00 07    bleu  0xf6dc                           ! Conditional/control branch; inspect delay slot.
0x0F6C4    80 a2 20 04    cmp  %o0, 4
0x0F6C8    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F6CC    7f ff fc ee    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F6D0    90 12 23 50    or  %o0, 0x350, %o0                    ! 0x87836b50
0x0F6D4    10 80 00 a4    b  0xf964                              ! Conditional/control branch; inspect delay slot.
0x0F6D8    92 10 20 01    mov  1, %o1
0x0F6DC    08 80 00 06    bleu  0xf6f4                           ! Conditional/control branch; inspect delay slot.
0x0F6E0    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F6E4    7f ff fc e8    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F6E8    90 12 23 68    or  %o0, 0x368, %o0                    ! 0x87836b68
0x0F6EC    10 80 00 9e    b  0xf964                              ! Conditional/control branch; inspect delay slot.
0x0F6F0    92 10 20 07    mov  7, %o1
0x0F6F4    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x0F6F8    a8 10 00 09    mov  %o1, %l4
0x0F6FC    90 10 23 e8    mov  0x3e8, %o0
0x0F700    21 08 00 00    sethi  %hi(0x20000000), %l0            ! Build high part of constant/address.
0x0F704    6a 1f 33 3f    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F708    c0 2a 61 10    clrb  [ %o1 + 0x110 ]
0x0F70C    ac 14 20 1c    or  %l0, 0x1c, %l6
0x0F710    aa 10 28 00    mov  0x800, %l5
0x0F714    90 10 23 e8    mov  0x3e8, %o0
0x0F718    ea 25 80 00    st  %l5, [ %l6 ]
0x0F71C    6a 1f 33 39    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F720    a0 14 20 14    or  %l0, 0x14, %l0
0x0F724    d0 04 00 00    ld  [ %l0 ], %o0
0x0F728    80 8a 28 00    btst  0x800, %o0
0x0F72C    02 80 00 4a    be  0xf854                             ! Conditional/control branch; inspect delay slot.
0x0F730    13 03 c0 00    sethi  %hi(0xf000000), %o1             ! Build high part of constant/address.
0x0F734    94 10 20 00    clr  %o2
0x0F738    96 10 20 01    mov  1, %o3
0x0F73C    7f ff f5 4b    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F740    90 10 20 68    mov  0x68, %o0
0x0F744    a0 07 bf f0    add  %fp, -16, %l0
0x0F748    a2 07 bf f4    add  %fp, -12, %l1
0x0F74C    94 10 00 11    mov  %l1, %o2
0x0F750    92 10 00 10    mov  %l0, %o1
0x0F754    96 10 20 01    mov  1, %o3
0x0F758    7f ff f5 57    call  0xccb4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F75C    90 10 20 68    mov  0x68, %o0
0x0F760    d4 0f bf f0    ldub  [ %fp + -16 ], %o2
0x0F764    13 03 80 00    sethi  %hi(0xe000000), %o1             ! Build high part of constant/address.
0x0F768    a6 0a a0 01    and  %o2, 1, %l3
0x0F76C    94 10 20 00    clr  %o2
0x0F770    96 10 20 01    mov  1, %o3
0x0F774    7f ff f5 3d    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F778    90 10 20 68    mov  0x68, %o0
0x0F77C    92 10 00 10    mov  %l0, %o1
0x0F780    90 10 20 68    mov  0x68, %o0
0x0F784    94 10 00 11    mov  %l1, %o2
0x0F788    7f ff f5 4b    call  0xccb4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F78C    96 10 20 01    mov  1, %o3
0x0F790    d2 0f bf f0    ldub  [ %fp + -16 ], %o1
0x0F794    80 8a 60 01    btst  1, %o1
0x0F798    02 80 00 2f    be  0xf854                             ! Conditional/control branch; inspect delay slot.
0x0F79C    80 a4 e0 00    cmp  %l3, 0
0x0F7A0    02 80 00 2d    be  0xf854                             ! Conditional/control branch; inspect delay slot.
0x0F7A4    13 03 80 00    sethi  %hi(0xe000000), %o1             ! Build high part of constant/address.
0x0F7A8    94 10 20 00    clr  %o2
0x0F7AC    96 10 20 01    mov  1, %o3
0x0F7B0    7f ff f5 2e    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F7B4    90 10 20 68    mov  0x68, %o0
0x0F7B8    92 10 00 10    mov  %l0, %o1
0x0F7BC    94 10 00 11    mov  %l1, %o2
0x0F7C0    96 10 20 01    mov  1, %o3
0x0F7C4    7f ff f5 3c    call  0xccb4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F7C8    90 10 20 68    mov  0x68, %o0
0x0F7CC    d2 0f bf f0    ldub  [ %fp + -16 ], %o1
0x0F7D0    11 03 80 00    sethi  %hi(0xe000000), %o0             ! Build high part of constant/address.
0x0F7D4    92 0a 60 fe    and  %o1, 0xfe, %o1
0x0F7D8    93 2a 60 10    sll  %o1, 0x10, %o1
0x0F7DC    92 12 40 08    or  %o1, %o0, %o1
0x0F7E0    94 10 20 00    clr  %o2
0x0F7E4    96 10 20 02    mov  2, %o3
0x0F7E8    7f ff f5 20    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F7EC    90 10 20 68    mov  0x68, %o0
0x0F7F0    13 03 c0 00    sethi  %hi(0xf000000), %o1             ! Build high part of constant/address.
0x0F7F4    94 10 20 00    clr  %o2
0x0F7F8    96 10 20 01    mov  1, %o3
0x0F7FC    7f ff f5 1b    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F800    90 10 20 68    mov  0x68, %o0
0x0F804    92 10 00 10    mov  %l0, %o1
0x0F808    94 10 00 11    mov  %l1, %o2
0x0F80C    96 10 20 01    mov  1, %o3
0x0F810    7f ff f5 29    call  0xccb4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F814    90 10 20 68    mov  0x68, %o0
0x0F818    d2 0f bf f0    ldub  [ %fp + -16 ], %o1
0x0F81C    11 03 c0 00    sethi  %hi(0xf000000), %o0             ! Build high part of constant/address.
0x0F820    92 0a 60 fe    and  %o1, 0xfe, %o1
0x0F824    93 2a 60 10    sll  %o1, 0x10, %o1
0x0F828    92 12 40 08    or  %o1, %o0, %o1
0x0F82C    94 10 20 00    clr  %o2
0x0F830    96 10 20 02    mov  2, %o3
0x0F834    7f ff f5 0d    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F838    90 10 20 68    mov  0x68, %o0
0x0F83C    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F840    ea 25 80 00    st  %l5, [ %l6 ]
0x0F844    7f ff fc 90    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F848    90 12 23 80    or  %o0, 0x380, %o0
0x0F84C    10 80 00 46    b  0xf964                              ! Conditional/control branch; inspect delay slot.
0x0F850    92 10 20 0b    mov  0xb, %o1
0x0F854    d0 0c a0 e4    ldub  [ %l2 + 0xe4 ], %o0
0x0F858    80 a2 20 01    cmp  %o0, 1
0x0F85C    12 80 00 13    bne  0xf8a8                            ! Conditional/control branch; inspect delay slot.
0x0F860    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0F864    7f ff fd eb    call  0xf010                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F868    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0F86C    90 0a 20 ff    and  %o0, 0xff, %o0
0x0F870    80 a2 20 04    cmp  %o0, 4
0x0F874    08 80 00 07    bleu  0xf890                           ! Conditional/control branch; inspect delay slot.
0x0F878    80 a2 20 00    cmp  %o0, 0
0x0F87C    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F880    7f ff fc 81    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F884    90 12 23 90    or  %o0, 0x390, %o0                    ! 0x87836b90
0x0F888    10 80 00 37    b  0xf964                              ! Conditional/control branch; inspect delay slot.
0x0F88C    92 10 20 0e    mov  0xe, %o1
0x0F890    02 80 00 06    be  0xf8a8                             ! Conditional/control branch; inspect delay slot.
0x0F894    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F898    7f ff fc 7b    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F89C    90 12 23 a0    or  %o0, 0x3a0, %o0                    ! 0x87836ba0
0x0F8A0    10 80 00 31    b  0xf964                              ! Conditional/control branch; inspect delay slot.
0x0F8A4    92 10 20 0d    mov  0xd, %o1
0x0F8A8    7f ff fe 39    call  0xf18c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F8AC    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0F8B0    90 0a 20 ff    and  %o0, 0xff, %o0
0x0F8B4    80 a2 20 31    cmp  %o0, 0x31
0x0F8B8    08 80 00 07    bleu  0xf8d4                           ! Conditional/control branch; inspect delay slot.
0x0F8BC    80 a2 20 18    cmp  %o0, 0x18
0x0F8C0    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F8C4    7f ff fc 70    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F8C8    90 12 23 40    or  %o0, 0x340, %o0                    ! 0x87836b40
0x0F8CC    10 80 00 26    b  0xf964                              ! Conditional/control branch; inspect delay slot.
0x0F8D0    92 10 20 09    mov  9, %o1
0x0F8D4    08 80 00 06    bleu  0xf8ec                           ! Conditional/control branch; inspect delay slot.
0x0F8D8    80 a2 20 13    cmp  %o0, 0x13
0x0F8DC    6a 1f 34 fb    call  0xa87dccc8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F8E0    90 10 20 08    mov  8, %o0
0x0F8E4    10 80 00 24    b  0xf974                              ! Conditional/control branch; inspect delay slot.
0x0F8E8    a2 10 20 00    clr  %l1
0x0F8EC    08 80 00 07    bleu  0xf908                           ! Conditional/control branch; inspect delay slot.
0x0F8F0    80 a2 20 0e    cmp  %o0, 0xe
0x0F8F4    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F8F8    7f ff fc 63    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F8FC    90 12 23 b0    or  %o0, 0x3b0, %o0                    ! 0x87836bb0
0x0F900    10 80 00 19    b  0xf964                              ! Conditional/control branch; inspect delay slot.
0x0F904    92 10 20 0c    mov  0xc, %o1
0x0F908    08 80 00 07    bleu  0xf924                           ! Conditional/control branch; inspect delay slot.
0x0F90C    80 a2 20 09    cmp  %o0, 9
0x0F910    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F914    7f ff fc 5c    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F918    90 12 23 c0    or  %o0, 0x3c0, %o0                    ! 0x87836bc0
0x0F91C    10 80 00 12    b  0xf964                              ! Conditional/control branch; inspect delay slot.
0x0F920    92 10 20 05    mov  5, %o1
0x0F924    08 80 00 0b    bleu  0xf950                           ! Conditional/control branch; inspect delay slot.
0x0F928    80 a2 20 04    cmp  %o0, 4
0x0F92C    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F930    7f ff fc 55    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F934    90 12 23 d0    or  %o0, 0x3d0, %o0                    ! 0x87836bd0
0x0F938    92 10 20 01    mov  1, %o1
0x0F93C    90 10 20 0a    mov  0xa, %o0
0x0F940    d2 2d 21 10    stb  %o1, [ %l4 + 0x110 ]
0x0F944    d0 2c a0 0f    stb  %o0, [ %l2 + 0xf ]
0x0F948    10 80 00 3d    b  0xfa3c                              ! Conditional/control branch; inspect delay slot.
0x0F94C    27 21 e0 dc    sethi  %hi(0x87837000), %l3            ! Build high part of constant/address.
0x0F950    08 80 00 08    bleu  0xf970                           ! Conditional/control branch; inspect delay slot.
0x0F954    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F958    7f ff fc 4b    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F95C    90 12 23 e0    or  %o0, 0x3e0, %o0                    ! 0x87836be0
0x0F960    92 10 20 06    mov  6, %o1
0x0F964    d2 2c a0 0f    stb  %o1, [ %l2 + 0xf ]
0x0F968    10 80 00 35    b  0xfa3c                              ! Conditional/control branch; inspect delay slot.
0x0F96C    27 21 e0 dc    sethi  %hi(0x87837000), %l3            ! Build high part of constant/address.
0x0F970    a2 10 20 00    clr  %l1
0x0F974    10 80 00 03    b  0xf980                              ! Conditional/control branch; inspect delay slot.
0x0F978    27 21 e0 dc    sethi  %hi(0x87837000), %l3            ! Build high part of constant/address.
0x0F97C    a2 04 60 01    inc  %l1
0x0F980    a0 0c 60 ff    and  %l1, 0xff, %l0
0x0F984    80 a4 20 03    cmp  %l0, 3
0x0F988    18 80 00 07    bgu  0xf9a4                            ! Conditional/control branch; inspect delay slot.
0x0F98C    80 a4 20 01    cmp  %l0, 1
0x0F990    7f ff f4 df    call  0xcd0c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F994    90 04 20 48    add  %l0, 0x48, %o0
0x0F998    80 a2 20 00    cmp  %o0, 0
0x0F99C    02 bf ff f8    be  0xf97c                             ! Conditional/control branch; inspect delay slot.
0x0F9A0    80 a4 20 01    cmp  %l0, 1
0x0F9A4    12 80 00 0a    bne  0xf9cc                            ! Conditional/control branch; inspect delay slot.
0x0F9A8    80 a4 20 02    cmp  %l0, 2
0x0F9AC    92 10 20 06    mov  6, %o1
0x0F9B0    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0F9B4    e0 2d 21 10    stb  %l0, [ %l4 + 0x110 ]
0x0F9B8    d2 2c a0 0f    stb  %o1, [ %l2 + 0xf ]
0x0F9BC    7f ff fc 32    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F9C0    90 12 23 f0    or  %o0, 0x3f0, %o0
0x0F9C4    10 80 00 1f    b  0xfa40                              ! Conditional/control branch; inspect delay slot.
0x0F9C8    d0 0c e3 b0    ldub  [ %l3 + 0x3b0 ], %o0
0x0F9CC    12 80 00 0b    bne  0xf9f8                            ! Conditional/control branch; inspect delay slot.
0x0F9D0    80 a4 20 03    cmp  %l0, 3
0x0F9D4    92 10 20 01    mov  1, %o1
0x0F9D8    94 10 20 05    mov  5, %o2
0x0F9DC    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x0F9E0    d2 2d 21 10    stb  %o1, [ %l4 + 0x110 ]
0x0F9E4    d4 2c a0 0f    stb  %o2, [ %l2 + 0xf ]
0x0F9E8    7f ff fc 27    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0F9EC    90 12 20 00    mov  %o0, %o0
0x0F9F0    10 80 00 14    b  0xfa40                              ! Conditional/control branch; inspect delay slot.
0x0F9F4    d0 0c e3 b0    ldub  [ %l3 + 0x3b0 ], %o0
0x0F9F8    02 80 00 08    be  0xfa18                             ! Conditional/control branch; inspect delay slot.
0x0F9FC    92 10 20 09    mov  9, %o1
0x0FA00    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0FA04    d2 02 20 c8    ld  [ %o0 + 0xc8 ], %o1                ! 0x878370c8
0x0FA08    80 a2 60 00    cmp  %o1, 0
0x0FA0C    32 80 00 09    bne,a   0xfa30                         ! Conditional/control branch; inspect delay slot.
0x0FA10    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x0FA14    92 10 20 09    mov  9, %o1
0x0FA18    11 21 e0 da    sethi  %hi(0x87836800), %o0            ! Build high part of constant/address.
0x0FA1C    d2 2c a0 0f    stb  %o1, [ %l2 + 0xf ]
0x0FA20    7f ff fc 19    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FA24    90 12 23 40    or  %o0, 0x340, %o0
0x0FA28    10 80 00 06    b  0xfa40                              ! Conditional/control branch; inspect delay slot.
0x0FA2C    d0 0c e3 b0    ldub  [ %l3 + 0x3b0 ], %o0
0x0FA30    7f ff fc 15    call  0xea84                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FA34    90 12 20 10    or  %o0, 0x10, %o0
0x0FA38    c0 2c a0 0f    clrb  [ %l2 + 0xf ]
0x0FA3C    d0 0c e3 b0    ldub  [ %l3 + 0x3b0 ], %o0
0x0FA40    80 a2 20 00    cmp  %o0, 0
0x0FA44    02 80 00 04    be  0xfa54                             ! Conditional/control branch; inspect delay slot.
0x0FA48    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x0FA4C    40 00 0a b5    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FA50    90 12 20 20    or  %o0, 0x20, %o0                     ! 0x87836c20
0x0FA54    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0FA58    81 e8 00 00    restore                                ! Restore previous register window.
0x0FA5C    a6 10 00 01    mov  %g1, %l3
0x0FA60    83 34 20 01    srl  %l0, 1, %g1
0x0FA64    a1 2c 20 07    sll  %l0, 7, %l0
0x0FA68    82 14 00 01    or  %l0, %g1, %g1
0x0FA6C    81 e0 00 00    save                                   ! Enter register window; allocate stack frame.
0x0FA70    81 90 40 00    wr  %g1, %wim
0x0FA74    e0 3b a0 00    std  %l0, [ %sp ]
0x0FA78    e4 3b a0 08    std  %l2, [ %sp + 8 ]
0x0FA7C    e8 3b a0 10    std  %l4, [ %sp + 0x10 ]
0x0FA80    ec 3b a0 18    std  %l6, [ %sp + 0x18 ]
0x0FA84    f0 3b a0 20    std  %i0, [ %sp + 0x20 ]
0x0FA88    f4 3b a0 28    std  %i2, [ %sp + 0x28 ]
0x0FA8C    f8 3b a0 30    std  %i4, [ %sp + 0x30 ]
0x0FA90    fc 3b a0 38    std  %fp, [ %sp + 0x38 ]
0x0FA94    81 e8 00 00    restore                                ! Restore previous register window.
0x0FA98    82 10 00 13    mov  %l3, %g1
0x0FA9C    81 c4 40 00    jmp  %l1
0x0FAA0    81 cc 80 00    rett  %l2
0x0FAA4    a7 2c 20 01    sll  %l0, 1, %l3
0x0FAA8    a1 34 20 07    srl  %l0, 7, %l0
0x0FAAC    81 94 00 13    wr  %l0, %l3, %wim
0x0FAB0    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0FAB4    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0FAB8    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0FABC    81 e8 00 00    restore                                ! Restore previous register window.
0x0FAC0    81 e8 00 00    restore                                ! Restore previous register window.
0x0FAC4    e0 1b a0 00    ldd  [ %sp ], %l0
0x0FAC8    e4 1b a0 08    ldd  [ %sp + 8 ], %l2
0x0FACC    e8 1b a0 10    ldd  [ %sp + 0x10 ], %l4
0x0FAD0    ec 1b a0 18    ldd  [ %sp + 0x18 ], %l6
0x0FAD4    f0 1b a0 20    ldd  [ %sp + 0x20 ], %i0
0x0FAD8    f4 1b a0 28    ldd  [ %sp + 0x28 ], %i2
0x0FADC    f8 1b a0 30    ldd  [ %sp + 0x30 ], %i4
0x0FAE0    fc 1b a0 38    ldd  [ %sp + 0x38 ], %fp
0x0FAE4    81 e0 00 00    save                                   ! Enter register window; allocate stack frame.
0x0FAE8    81 e0 00 00    save                                   ! Enter register window; allocate stack frame.
0x0FAEC    81 c4 40 00    jmp  %l1
0x0FAF0    81 cc 80 00    rett  %l2
0x0FAF4    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0FAF8    90 06 7f fe    add  %i1, -2, %o0
0x0FAFC    90 0a 20 ff    and  %o0, 0xff, %o0
0x0FB00    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x0FB04    80 a2 20 02    cmp  %o0, 2
0x0FB08    d4 0a 63 b0    ldub  [ %o1 + 0x3b0 ], %o2
0x0FB0C    90 40 20 00    addx  %g0, 0, %o0
0x0FB10    ae 10 00 08    mov  %o0, %l7
0x0FB14    80 a2 a0 00    cmp  %o2, 0
0x0FB18    02 80 00 10    be  0xfb58                             ! Conditional/control branch; inspect delay slot.
0x0FB1C    2d 20 00 00    sethi  %hi(0x80000000), %l6            ! Build high part of constant/address.
0x0FB20    90 0e 60 ff    and  %i1, 0xff, %o0
0x0FB24    80 a2 20 00    cmp  %o0, 0
0x0FB28    02 80 00 0c    be  0xfb58                             ! Conditional/control branch; inspect delay slot.
0x0FB2C    a4 10 00 08    mov  %o0, %l2
0x0FB30    80 a4 a0 0f    cmp  %l2, 0xf
0x0FB34    02 80 00 09    be  0xfb58                             ! Conditional/control branch; inspect delay slot.
0x0FB38    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x0FB3C    40 00 0a 79    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FB40    90 12 21 e0    or  %o0, 0x1e0, %o0                    ! 0x87836de0
0x0FB44    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x0FB48    92 12 61 ac    or  %o1, 0x1ac, %o1                    ! 0x878371ac
0x0FB4C    95 2c a0 02    sll  %l2, 2, %o2
0x0FB50    40 00 0a 74    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FB54    d0 02 40 0a    ld  [ %o1 + %o2 ], %o0
0x0FB58    d0 0d a0 e4    ldub  [ %l6 + 0xe4 ], %o0
0x0FB5C    80 a2 20 03    cmp  %o0, 3
0x0FB60    22 80 00 02    be,a   0xfb68                          ! Conditional/control branch; inspect delay slot.
0x0FB64    b2 38 00 19    xnor  %g0, %i1, %i1
0x0FB68    90 0e 20 ff    and  %i0, 0xff, %o0
0x0FB6C    80 a2 20 00    cmp  %o0, 0
0x0FB70    02 80 00 05    be  0xfb84                             ! Conditional/control branch; inspect delay slot.
0x0FB74    a8 10 00 08    mov  %o0, %l4
0x0FB78    11 08 00 02    sethi  %hi(0x20000800), %o0            ! Build high part of constant/address.
0x0FB7C    90 12 20 08    or  %o0, 8, %o0                        ! 0x20000808
0x0FB80    c0 22 00 00    clr  [ %o0 ]
0x0FB84    2b 08 00 02    sethi  %hi(0x20000800), %l5            ! Build high part of constant/address.
0x0FB88    d0 0d a0 0e    ldub  [ %l6 + 0xe ], %o0
0x0FB8C    80 a2 20 41    cmp  %o0, 0x41
0x0FB90    02 80 00 24    be  0xfc20                             ! Conditional/control branch; inspect delay slot.
0x0FB94    80 a5 20 00    cmp  %l4, 0
0x0FB98    02 80 00 22    be  0xfc20                             ! Conditional/control branch; inspect delay slot.
0x0FB9C    a4 0e 60 ff    and  %i1, 0xff, %l2
0x0FBA0    23 00 00 18    sethi  %hi(0x6000), %l1                ! Build high part of constant/address.
0x0FBA4    a0 15 60 0c    or  %l5, 0xc, %l0
0x0FBA8    a6 10 20 ff    mov  0xff, %l3
0x0FBAC    b0 10 20 02    mov  2, %i0
0x0FBB0    6a 1f 32 14    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FBB4    90 14 61 a8    or  %l1, 0x1a8, %o0
0x0FBB8    e6 24 00 00    st  %l3, [ %l0 ]
0x0FBBC    6a 1f 32 11    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FBC0    90 14 61 a8    or  %l1, 0x1a8, %o0
0x0FBC4    c0 24 00 00    clr  [ %l0 ]
0x0FBC8    b0 86 3f ff    addcc  %i0, -1, %i0
0x0FBCC    1c bf ff f9    bpos  0xfbb0                           ! Conditional/control branch; inspect delay slot.
0x0FBD0    80 a4 a0 00    cmp  %l2, 0
0x0FBD4    02 80 00 0e    be  0xfc0c                             ! Conditional/control branch; inspect delay slot.
0x0FBD8    b0 10 00 12    mov  %l2, %i0
0x0FBDC    23 00 00 61    sethi  %hi(0x18400), %l1               ! Build high part of constant/address.
0x0FBE0    a0 15 60 0c    or  %l5, 0xc, %l0
0x0FBE4    a4 10 20 01    mov  1, %l2
0x0FBE8    6a 1f 32 06    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FBEC    90 14 62 a0    or  %l1, 0x2a0, %o0
0x0FBF0    e4 24 00 00    st  %l2, [ %l0 ]
0x0FBF4    6a 1f 32 03    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FBF8    90 14 62 a0    or  %l1, 0x2a0, %o0
0x0FBFC    c0 24 00 00    clr  [ %l0 ]
0x0FC00    b0 86 3f ff    addcc  %i0, -1, %i0
0x0FC04    12 bf ff f9    bne  0xfbe8                            ! Conditional/control branch; inspect delay slot.
0x0FC08    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0FC0C    11 00 00 49    sethi  %hi(0x12400), %o0               ! Build high part of constant/address.
0x0FC10    6a 1f 31 fc    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FC14    90 12 20 f8    or  %o0, 0xf8, %o0                     ! 0x124f8
0x0FC18    10 80 00 14    b  0xfc68                              ! Conditional/control branch; inspect delay slot.
0x0FC1C    80 a5 20 00    cmp  %l4, 0
0x0FC20    94 15 60 0c    or  %l5, 0xc, %o2
0x0FC24    80 a5 20 00    cmp  %l4, 0
0x0FC28    12 80 00 06    bne  0xfc40                            ! Conditional/control branch; inspect delay slot.
0x0FC2C    92 0e 60 0f    and  %i1, 0xf, %o1
0x0FC30    d0 02 80 00    ld  [ %o2 ], %o0
0x0FC34    90 0a 20 f0    and  %o0, 0xf0, %o0
0x0FC38    10 80 00 03    b  0xfc44                              ! Conditional/control branch; inspect delay slot.
0x0FC3C    90 12 00 09    or  %o0, %o1, %o0
0x0FC40    90 10 00 09    mov  %o1, %o0
0x0FC44    d0 22 80 00    st  %o0, [ %o2 ]
0x0FC48    80 8d e0 ff    btst  0xff, %l7
0x0FC4C    02 80 00 07    be  0xfc68                             ! Conditional/control branch; inspect delay slot.
0x0FC50    80 a5 20 00    cmp  %l4, 0
0x0FC54    11 00 00 92    sethi  %hi(0x24800), %o0               ! Build high part of constant/address.
0x0FC58    6a 1f 31 ea    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FC5C    90 12 21 f0    or  %o0, 0x1f0, %o0                    ! 0x249f0
0x0FC60    b2 38 00 19    xnor  %g0, %i1, %i1
0x0FC64    80 a5 20 00    cmp  %l4, 0
0x0FC68    32 bf ff c9    bne,a   0xfb8c                         ! Conditional/control branch; inspect delay slot.
0x0FC6C    d0 0d a0 0e    ldub  [ %l6 + 0xe ], %o0
0x0FC70    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0FC74    81 e8 00 00    restore                                ! Restore previous register window.
0x0FC78    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0FC7C    d0 06 60 04    ld  [ %i1 + 4 ], %o0
0x0FC80    92 10 20 00    clr  %o1
0x0FC84    7f ff fb 66    call  0xea1c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FC88    94 10 20 00    clr  %o2
0x0FC8C    90 0a 3f fc    and  %o0, -4, %o0
0x0FC90    15 00 00 c0    sethi  %hi(0x30000), %o2               ! Build high part of constant/address.
0x0FC94    92 10 20 c0    mov  0xc0, %o1
0x0FC98    81 c2 00 00    jmp  %o0
0x0FC9C    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0FCA0    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0FCA4    81 e8 00 00    restore                                ! Restore previous register window.
0x0FCA8    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x0FCAC    90 06 3f ff    add  %i0, -1, %o0
0x0FCB0    90 0a 20 ff    and  %o0, 0xff, %o0
0x0FCB4    92 10 00 18    mov  %i0, %o1
0x0FCB8    80 a2 20 07    cmp  %o0, 7
0x0FCBC    18 80 00 ad    bgu  0xff70                            ! Conditional/control branch; inspect delay slot.
0x0FCC0    b8 10 00 19    mov  %i1, %i4
0x0FCC4    91 36 a0 10    srl  %i2, 0x10, %o0
0x0FCC8    b6 06 20 30    add  %i0, 0x30, %i3
0x0FCCC    b2 02 3f ff    add  %o0, -1, %i1
0x0FCD0    a8 0a 60 ff    and  %o1, 0xff, %l4
0x0FCD4    b5 36 a0 02    srl  %i2, 2, %i2
0x0FCD8    ac 10 20 00    clr  %l6
0x0FCDC    31 21 e0 dc    sethi  %hi(0x87837000), %i0            ! Build high part of constant/address.
0x0FCE0    80 a5 20 02    cmp  %l4, 2
0x0FCE4    22 80 00 14    be,a   0xfd34                          ! Conditional/control branch; inspect delay slot.
0x0FCE8    aa 10 3f ff    mov  -1, %l5
0x0FCEC    14 80 00 06    bg  0xfd04                             ! Conditional/control branch; inspect delay slot.
0x0FCF0    80 a5 20 03    cmp  %l4, 3
0x0FCF4    80 a5 20 01    cmp  %l4, 1
0x0FCF8    02 80 00 08    be  0xfd18                             ! Conditional/control branch; inspect delay slot.
0x0FCFC    80 a5 a0 00    cmp  %l6, 0
0x0FD00    30 80 00 0e    b,a   0xfd38                           ! Conditional/control branch; inspect delay slot.
0x0FD04    02 80 00 07    be  0xfd20                             ! Conditional/control branch; inspect delay slot.
0x0FD08    80 a5 20 04    cmp  %l4, 4
0x0FD0C    02 80 00 08    be  0xfd2c                             ! Conditional/control branch; inspect delay slot.
0x0FD10    80 a5 a0 00    cmp  %l6, 0
0x0FD14    30 80 00 09    b,a   0xfd38                           ! Conditional/control branch; inspect delay slot.
0x0FD18    10 80 00 07    b  0xfd34                              ! Conditional/control branch; inspect delay slot.
0x0FD1C    aa 10 20 00    clr  %l5
0x0FD20    11 2a 95 6a    sethi  %hi(0xaa55a800), %o0            ! Build high part of constant/address.
0x0FD24    10 80 00 04    b  0xfd34                              ! Conditional/control branch; inspect delay slot.
0x0FD28    aa 12 22 55    or  %o0, 0x255, %l5                    ! 0xaa55aa55
0x0FD2C    11 15 6a 95    sethi  %hi(0x55aa5400), %o0            ! Build high part of constant/address.
0x0FD30    aa 12 21 aa    or  %o0, 0x1aa, %l5                    ! 0x55aa55aa
0x0FD34    80 a5 a0 00    cmp  %l6, 0
0x0FD38    02 80 00 05    be  0xfd4c                             ! Conditional/control branch; inspect delay slot.
0x0FD3C    a0 10 20 10    mov  0x10, %l0
0x0FD40    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0FD44    10 80 00 05    b  0xfd58                              ! Conditional/control branch; inspect delay slot.
0x0FD48    a2 12 21 90    or  %o0, 0x190, %l1                    ! 0x87837190
0x0FD4C    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x0FD50    a2 12 21 80    or  %o0, 0x180, %l1                    ! 0x87837180
0x0FD54    a0 10 20 0f    mov  0xf, %l0
0x0FD58    90 04 00 11    add  %l0, %l1, %o0
0x0FD5C    f6 2a 3f fe    stb  %i3, [ %o0 + -2 ]
0x0FD60    7f ff fb 3e    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FD64    90 10 00 11    mov  %l1, %o0
0x0FD68    7f ff fb 7e    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FD6C    90 10 20 0a    mov  0xa, %o0
0x0FD70    d0 0e 23 b0    ldub  [ %i0 + 0x3b0 ], %o0
0x0FD74    80 a2 20 00    cmp  %o0, 0
0x0FD78    02 80 00 05    be  0xfd8c                             ! Conditional/control branch; inspect delay slot.
0x0FD7C    94 10 20 00    clr  %o2
0x0FD80    40 00 09 e8    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FD84    90 10 00 11    mov  %l1, %o0
0x0FD88    94 10 20 00    clr  %o2
0x0FD8C    a4 10 00 1c    mov  %i4, %l2
0x0FD90    80 a2 80 1a    cmp  %o2, %i2
0x0FD94    1a 80 00 6f    bcc  0xff50                            ! Conditional/control branch; inspect delay slot.
0x0FD98    ae 05 a0 01    add  %l6, 1, %l7
0x0FD9C    13 1e 1f 40    sethi  %hi(0x787d0000), %o1            ! Build high part of constant/address.
0x0FDA0    11 00 00 1f    sethi  %hi(0x7c00), %o0                ! Build high part of constant/address.
0x0FDA4    92 04 80 09    add  %l2, %o1, %o1
0x0FDA8    90 12 23 ff    or  %o0, 0x3ff, %o0
0x0FDAC    80 a2 40 08    cmp  %o1, %o0
0x0FDB0    a6 02 a0 01    add  %o2, 1, %l3
0x0FDB4    08 80 00 63    bleu  0xff40                           ! Conditional/control branch; inspect delay slot.
0x0FDB8    a2 04 a0 04    add  %l2, 4, %l1
0x0FDBC    80 a5 20 06    cmp  %l4, 6
0x0FDC0    22 80 00 17    be,a   0xfe1c                          ! Conditional/control branch; inspect delay slot.
0x0FDC4    aa 38 00 12    xnor  %g0, %l2, %l5
0x0FDC8    14 80 00 06    bg  0xfde0                             ! Conditional/control branch; inspect delay slot.
0x0FDCC    80 a5 20 07    cmp  %l4, 7
0x0FDD0    80 a5 20 05    cmp  %l4, 5
0x0FDD4    02 80 00 08    be  0xfdf4                             ! Conditional/control branch; inspect delay slot.
0x0FDD8    80 a5 a0 00    cmp  %l6, 0
0x0FDDC    30 80 00 11    b,a   0xfe20                           ! Conditional/control branch; inspect delay slot.
0x0FDE0    02 80 00 07    be  0xfdfc                             ! Conditional/control branch; inspect delay slot.
0x0FDE4    80 a5 20 08    cmp  %l4, 8
0x0FDE8    02 80 00 09    be  0xfe0c                             ! Conditional/control branch; inspect delay slot.
0x0FDEC    80 a5 a0 00    cmp  %l6, 0
0x0FDF0    30 80 00 0c    b,a   0xfe20                           ! Conditional/control branch; inspect delay slot.
0x0FDF4    10 80 00 0a    b  0xfe1c                              ! Conditional/control branch; inspect delay slot.
0x0FDF8    aa 10 00 12    mov  %l2, %l5
0x0FDFC    92 0a a0 1f    and  %o2, 0x1f, %o1
0x0FE00    90 10 20 01    mov  1, %o0
0x0FE04    10 80 00 06    b  0xfe1c                              ! Conditional/control branch; inspect delay slot.
0x0FE08    ab 2a 00 09    sll  %o0, %o1, %l5
0x0FE0C    92 0a a0 1f    and  %o2, 0x1f, %o1
0x0FE10    90 10 20 01    mov  1, %o0
0x0FE14    91 2a 00 09    sll  %o0, %o1, %o0
0x0FE18    aa 38 00 08    xnor  %g0, %o0, %l5
0x0FE1C    80 a5 a0 00    cmp  %l6, 0
0x0FE20    02 80 00 3b    be  0xff0c                             ! Conditional/control branch; inspect delay slot.
0x0FE24    90 0c bf fc    and  %l2, -4, %o0
0x0FE28    e0 02 00 00    ld  [ %o0 ], %l0
0x0FE2C    80 a4 00 15    cmp  %l0, %l5
0x0FE30    02 80 00 39    be  0xff14                             ! Conditional/control branch; inspect delay slot.
0x0FE34    a6 02 a0 01    add  %o2, 1, %l3
0x0FE38    7f ff fb 41    call  0xeb3c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FE3C    90 10 00 12    mov  %l2, %o0
0x0FE40    7f ff fb 48    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FE44    90 10 20 20    mov  0x20, %o0
0x0FE48    7f ff fb 3d    call  0xeb3c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FE4C    90 10 00 10    mov  %l0, %o0
0x0FE50    7f ff fb 44    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FE54    90 10 20 21    mov  0x21, %o0
0x0FE58    7f ff fb 42    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FE5C    90 10 20 3d    mov  0x3d, %o0
0x0FE60    7f ff fb 37    call  0xeb3c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FE64    90 10 00 15    mov  %l5, %o0
0x0FE68    7f ff fb 3e    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FE6C    90 10 20 0a    mov  0xa, %o0
0x0FE70    d0 0e 23 b0    ldub  [ %i0 + 0x3b0 ], %o0
0x0FE74    80 a2 20 00    cmp  %o0, 0
0x0FE78    02 80 00 1b    be  0xfee4                             ! Conditional/control branch; inspect delay slot.
0x0FE7C    23 21 e0 dc    sethi  %hi(0x87837000), %l1            ! Build high part of constant/address.
0x0FE80    40 00 09 2f    call  0x1233c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FE84    90 10 20 02    mov  2, %o0
0x0FE88    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x0FE8C    d0 02 61 b8    ld  [ %o1 + 0x1b8 ], %o0               ! 0x878371b8
0x0FE90    40 00 09 a4    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FE94    a0 10 20 00    clr  %l0
0x0FE98    40 00 09 29    call  0x1233c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FE9C    90 10 20 02    mov  2, %o0
0x0FEA0    94 14 61 80    or  %l1, 0x180, %o2
0x0FEA4    92 10 20 1c    mov  0x1c, %o1
0x0FEA8    91 34 80 09    srl  %l2, %o1, %o0
0x0FEAC    90 0a 20 0f    and  %o0, 0xf, %o0
0x0FEB0    80 a2 20 09    cmp  %o0, 9
0x0FEB4    24 80 00 03    ble,a   0xfec0                         ! Conditional/control branch; inspect delay slot.
0x0FEB8    90 02 20 30    add  %o0, 0x30, %o0
0x0FEBC    90 02 20 37    add  %o0, 0x37, %o0
0x0FEC0    d0 2a 80 10    stb  %o0, [ %o2 + %l0 ]
0x0FEC4    a0 04 20 01    inc  %l0
0x0FEC8    80 a4 20 07    cmp  %l0, 7
0x0FECC    04 bf ff f7    ble  0xfea8                            ! Conditional/control branch; inspect delay slot.
0x0FED0    92 02 7f fc    add  %o1, -4, %o1
0x0FED4    92 14 61 80    or  %l1, 0x180, %o1
0x0FED8    90 10 00 09    mov  %o1, %o0
0x0FEDC    40 00 09 91    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FEE0    c0 2a 60 08    clrb  [ %o1 + 8 ]
0x0FEE4    11 08 00 02    sethi  %hi(0x20000800), %o0            ! Build high part of constant/address.
0x0FEE8    a4 12 20 0c    or  %o0, 0xc, %l2                      ! 0x2000080c
0x0FEEC    a0 10 20 03    mov  3, %l0
0x0FEF0    23 00 00 92    sethi  %hi(0x24800), %l1               ! Build high part of constant/address.
0x0FEF4    90 0c 20 0f    and  %l0, 0xf, %o0
0x0FEF8    d0 24 80 00    st  %o0, [ %l2 ]
0x0FEFC    6a 1f 31 41    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FF00    90 14 61 f0    or  %l1, 0x1f0, %o0
0x0FF04    10 bf ff fc    b  0xfef4                              ! Conditional/control branch; inspect delay slot.
0x0FF08    a0 38 00 10    xnor  %g0, %l0, %l0
0x0FF0C    ea 22 00 00    st  %l5, [ %o0 ]
0x0FF10    a6 02 a0 01    add  %o2, 1, %l3
0x0FF14    80 8a 80 19    btst  %o2, %i1
0x0FF18    12 80 00 0a    bne  0xff40                            ! Conditional/control branch; inspect delay slot.
0x0FF1C    a2 04 a0 04    add  %l2, 4, %l1
0x0FF20    7f ff fb 07    call  0xeb3c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FF24    90 10 00 12    mov  %l2, %o0
0x0FF28    a0 10 20 07    mov  7, %l0
0x0FF2C    7f ff fb 0d    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FF30    90 10 20 08    mov  8, %o0
0x0FF34    a0 84 3f ff    addcc  %l0, -1, %l0
0x0FF38    1c bf ff fd    bpos  0xff2c                           ! Conditional/control branch; inspect delay slot.
0x0FF3C    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x0FF40    94 10 00 13    mov  %l3, %o2
0x0FF44    80 a2 80 1a    cmp  %o2, %i2
0x0FF48    0a bf ff 95    bcs  0xfd9c                            ! Conditional/control branch; inspect delay slot.
0x0FF4C    a4 10 00 11    mov  %l1, %l2
0x0FF50    7f ff fa fb    call  0xeb3c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FF54    90 10 00 12    mov  %l2, %o0
0x0FF58    ac 10 00 17    mov  %l7, %l6
0x0FF5C    80 a5 a0 01    cmp  %l6, 1
0x0FF60    04 bf ff 61    ble  0xfce4                            ! Conditional/control branch; inspect delay slot.
0x0FF64    80 a5 20 02    cmp  %l4, 2
0x0FF68    7f ff fa fe    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FF6C    90 10 20 0a    mov  0xa, %o0
0x0FF70    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x0FF74    91 e8 20 00    restore  %g0, 0, %o0                   ! Restore previous register window.
0x0FF78    9d e3 bf 30    save  %sp, -208, %sp                   ! Enter register window; allocate stack frame.
0x0FF7C    13 08 00 00    sethi  %hi(0x20000000), %o1            ! Build high part of constant/address.
0x0FF80    11 00 00 04    sethi  %hi(0x1000), %o0                ! Build high part of constant/address.
0x0FF84    92 12 61 00    or  %o1, 0x100, %o1
0x0FF88    90 12 20 10    or  %o0, 0x10, %o0
0x0FF8C    d0 22 40 00    st  %o0, [ %o1 ]
0x0FF90    2d 20 00 00    sethi  %hi(0x80000000), %l6            ! Build high part of constant/address.
0x0FF94    2b 21 e0 dc    sethi  %hi(0x87837000), %l5            ! Build high part of constant/address.
0x0FF98    25 21 e0 dc    sethi  %hi(0x87837000), %l2            ! Build high part of constant/address.
0x0FF9C    29 21 e0 dc    sethi  %hi(0x87837000), %l4            ! Build high part of constant/address.
0x0FFA0    b6 07 bf 90    add  %fp, -112, %i3
0x0FFA4    39 21 e0 db    sethi  %hi(0x87836c00), %i4            ! Build high part of constant/address.
0x0FFA8    3b 21 e0 db    sethi  %hi(0x87836c00), %i5            ! Build high part of constant/address.
0x0FFAC    a0 10 20 13    mov  0x13, %l0
0x0FFB0    a0 84 3f ff    addcc  %l0, -1, %l0
0x0FFB4    1c 80 00 00    bpos  0xffb4                           ! Conditional/control branch; inspect delay slot.
0x0FFB8    a0 84 3f ff    addcc  %l0, -1, %l0
0x0FFBC    13 08 00 02    sethi  %hi(0x20000800), %o1            ! Build high part of constant/address.
0x0FFC0    90 10 20 06    mov  6, %o0
0x0FFC4    d0 22 40 00    st  %o0, [ %o1 ]
0x0FFC8    94 12 60 08    or  %o1, 8, %o2
0x0FFCC    11 00 38 00    sethi  %hi(0xe00000), %o0              ! Build high part of constant/address.
0x0FFD0    d0 22 80 00    st  %o0, [ %o2 ]
0x0FFD4    92 12 60 0c    or  %o1, 0xc, %o1
0x0FFD8    90 10 20 20    mov  0x20, %o0
0x0FFDC    d0 22 40 00    st  %o0, [ %o1 ]
0x0FFE0    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x0FFE4    7f ff fa 9d    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x0FFE8    90 12 21 f0    or  %o0, 0x1f0, %o0                    ! 0x87836df0
0x0FFEC    19 21 e0 dc    sethi  %hi(0x87837000), %o4            ! Build high part of constant/address.
0x0FFF0    17 21 e0 dc    sethi  %hi(0x87837000), %o3            ! Build high part of constant/address.
0x0FFF4    a0 10 20 00    clr  %l0
0x0FFF8    a2 05 a0 10    add  %l6, 0x10, %l1
0x0FFFC    d0 02 e1 14    ld  [ %o3 + 0x114 ], %o0

! ============================================================================
! 0x10000: Continuation of active SPARC routines.
! ============================================================================
0x10000    d2 03 21 18    ld  [ %o4 + 0x118 ], %o1
0x10004    d4 0a 00 10    ldub  [ %o0 + %l0 ], %o2
0x10008    d4 2a 40 10    stb  %o2, [ %o1 + %l0 ]
0x1000C    a0 04 20 01    inc  %l0
0x10010    80 a4 2b ff    cmp  %l0, 0xbff
0x10014    04 bf ff fb    ble  0x10000                           ! Conditional/control branch; inspect delay slot.
0x10018    d0 02 e1 14    ld  [ %o3 + 0x114 ], %o0
0x1001C    40 00 09 ae    call  0x126d4                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10020    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10024    6a 1f 30 ff    call  0xa87dc420                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10028    d0 2d 63 b0    stb  %o0, [ %l5 + 0x3b0 ]
0x1002C    80 a2 20 00    cmp  %o0, 0
0x10030    02 80 00 04    be  0x10040                            ! Conditional/control branch; inspect delay slot.
0x10034    90 10 20 01    mov  1, %o0
0x10038    7f ff fe af    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1003C    92 10 20 02    mov  2, %o1
0x10040    6a 1f 32 97    call  0xa87dca9c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10044    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10048    80 a2 20 00    cmp  %o0, 0
0x1004C    02 80 00 04    be  0x1005c                            ! Conditional/control branch; inspect delay slot.
0x10050    90 10 20 01    mov  1, %o0
0x10054    7f ff fe a8    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10058    92 10 20 03    mov  3, %o1
0x1005C    7f ff f4 53    call  0xd1a8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10060    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10064    80 a2 20 00    cmp  %o0, 0
0x10068    22 80 00 06    be,a   0x10080                         ! Conditional/control branch; inspect delay slot.
0x1006C    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x10070    90 10 20 00    clr  %o0
0x10074    7f ff fe a0    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10078    92 10 20 0b    mov  0xb, %o1
0x1007C    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x10080    90 12 22 00    or  %o0, 0x200, %o0                    ! 0x87836e00
0x10084    7f ff fa 75    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10088    21 21 e0 db    sethi  %hi(0x87836c00), %l0            ! Build high part of constant/address.
0x1008C    a0 14 22 10    or  %l0, 0x210, %l0                    ! 0x87836e10
0x10090    7f ff fa 72    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10094    90 10 00 10    mov  %l0, %o0
0x10098    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x1009C    7f ff fa 6f    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x100A0    90 12 22 20    or  %o0, 0x220, %o0                    ! 0x87836e20
0x100A4    94 10 00 10    mov  %l0, %o2
0x100A8    92 10 00 11    mov  %l1, %o1
0x100AC    a0 10 20 00    clr  %l0
0x100B0    d0 0a 80 10    ldub  [ %o2 + %l0 ], %o0
0x100B4    d0 2a 40 10    stb  %o0, [ %o1 + %l0 ]
0x100B8    a0 04 20 01    inc  %l0
0x100BC    80 a4 20 0e    cmp  %l0, 0xe
0x100C0    28 bf ff fd    bleu,a   0x100b4
0x100C4    d0 0a 80 10    ldub  [ %o2 + %l0 ], %o0
0x100C8    d0 0d 63 b0    ldub  [ %l5 + 0x3b0 ], %o0
0x100CC    80 a2 20 00    cmp  %o0, 0
0x100D0    02 80 00 07    be  0x100ec                            ! Conditional/control branch; inspect delay slot.
0x100D4    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x100D8    40 00 09 12    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x100DC    90 12 22 40    or  %o0, 0x240, %o0                    ! 0x87836e40
0x100E0    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x100E4    40 00 09 0f    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x100E8    90 12 22 50    or  %o0, 0x250, %o0                    ! 0x87836e50
0x100EC    7f ff fc c8    call  0xf40c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x100F0    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x100F4    d0 0d a0 e4    ldub  [ %l6 + 0xe4 ], %o0
0x100F8    80 a2 20 01    cmp  %o0, 1
0x100FC    12 80 00 0c    bne  0x1012c                           ! Conditional/control branch; inspect delay slot.
0x10100    d0 0c a3 70    ldub  [ %l2 + 0x370 ], %o0
0x10104    15 08 00 1c    sethi  %hi(0x20007000), %o2            ! Build high part of constant/address.
0x10108    90 12 a0 48    or  %o2, 0x48, %o0                     ! 0x20007048
0x1010C    c0 22 00 00    clr  [ %o0 ]
0x10110    92 12 a1 48    or  %o2, 0x148, %o1
0x10114    c0 22 40 00    clr  [ %o1 ]
0x10118    90 12 a2 48    or  %o2, 0x248, %o0
0x1011C    c0 22 00 00    clr  [ %o0 ]
0x10120    94 12 a3 48    or  %o2, 0x348, %o2
0x10124    c0 22 80 00    clr  [ %o2 ]
0x10128    d0 0c a3 70    ldub  [ %l2 + 0x370 ], %o0
0x1012C    80 a2 20 00    cmp  %o0, 0
0x10130    02 80 00 4d    be  0x10264                            ! Conditional/control branch; inspect delay slot.
0x10134    21 21 e0 dc    sethi  %hi(0x87837000), %l0            ! Build high part of constant/address.
0x10138    7f ff f1 74    call  0xc708                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1013C    c0 2c 23 72    clrb  [ %l0 + 0x372 ]                  ! 0x87837372
0x10140    d2 0c 23 72    ldub  [ %l0 + 0x372 ], %o1
0x10144    80 a2 60 00    cmp  %o1, 0
0x10148    02 80 00 47    be  0x10264                            ! Conditional/control branch; inspect delay slot.
0x1014C    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10150    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x10154    7f ff fa 41    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10158    90 12 22 68    or  %o0, 0x268, %o0                    ! 0x87836e68
0x1015C    d0 0c a3 70    ldub  [ %l2 + 0x370 ], %o0
0x10160    7f ff fa 67    call  0xeafc                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10164    21 21 e0 dc    sethi  %hi(0x87837000), %l0            ! Build high part of constant/address.
0x10168    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x1016C    7f ff fa 3b    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10170    90 12 22 70    or  %o0, 0x270, %o0                    ! 0x87836e70
0x10174    d2 0c a3 70    ldub  [ %l2 + 0x370 ], %o1
0x10178    11 03 00 40    sethi  %hi(0xc010000), %o0             ! Build high part of constant/address.
0x1017C    93 2a 60 08    sll  %o1, 8, %o1
0x10180    92 12 40 08    or  %o1, %o0, %o1
0x10184    94 10 20 00    clr  %o2
0x10188    96 10 20 03    mov  3, %o3
0x1018C    7f ff f2 b7    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10190    90 10 20 69    mov  0x69, %o0
0x10194    d2 0c a3 70    ldub  [ %l2 + 0x370 ], %o1
0x10198    11 00 0a a8    sethi  %hi(0x2aa000), %o0              ! Build high part of constant/address.
0x1019C    92 02 61 08    add  %o1, 0x108, %o1
0x101A0    7f ff f3 0d    call  0xcdd4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x101A4    90 12 20 b3    or  %o0, 0xb3, %o0
0x101A8    6a 1f 30 9e    call  0xa87dc420                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x101AC    d0 24 20 cc    st  %o0, [ %l0 + 0xcc ]
0x101B0    80 a2 20 00    cmp  %o0, 0
0x101B4    02 80 00 04    be  0x101c4                            ! Conditional/control branch; inspect delay slot.
0x101B8    90 10 20 01    mov  1, %o0
0x101BC    7f ff fe 4e    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x101C0    92 10 20 02    mov  2, %o1
0x101C4    6a 1f 32 36    call  0xa87dca9c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x101C8    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x101CC    80 a2 20 00    cmp  %o0, 0
0x101D0    02 80 00 04    be  0x101e0                            ! Conditional/control branch; inspect delay slot.
0x101D4    90 10 20 01    mov  1, %o0
0x101D8    7f ff fe 47    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x101DC    92 10 20 03    mov  3, %o1
0x101E0    7f ff f3 f2    call  0xd1a8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x101E4    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x101E8    80 a2 20 00    cmp  %o0, 0
0x101EC    02 80 00 04    be  0x101fc                            ! Conditional/control branch; inspect delay slot.
0x101F0    90 10 20 00    clr  %o0
0x101F4    7f ff fe 40    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x101F8    92 10 20 0b    mov  0xb, %o1
0x101FC    7f ff fc 84    call  0xf40c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10200    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10204    d0 0c a3 70    ldub  [ %l2 + 0x370 ], %o0
0x10208    80 a2 20 01    cmp  %o0, 1
0x1020C    18 80 00 04    bgu  0x1021c                           ! Conditional/control branch; inspect delay slot.
0x10210    80 a2 20 36    cmp  %o0, 0x36
0x10214    10 80 00 0d    b  0x10248                             ! Conditional/control branch; inspect delay slot.
0x10218    90 10 20 16    mov  0x16, %o0
0x1021C    18 80 00 04    bgu  0x1022c                           ! Conditional/control branch; inspect delay slot.
0x10220    80 a2 20 6b    cmp  %o0, 0x6b
0x10224    10 80 00 09    b  0x10248                             ! Conditional/control branch; inspect delay slot.
0x10228    90 10 20 19    mov  0x19, %o0
0x1022C    18 80 00 04    bgu  0x1023c                           ! Conditional/control branch; inspect delay slot.
0x10230    80 a2 20 a0    cmp  %o0, 0xa0
0x10234    10 80 00 05    b  0x10248                             ! Conditional/control branch; inspect delay slot.
0x10238    90 10 20 17    mov  0x17, %o0
0x1023C    18 80 00 03    bgu  0x10248                           ! Conditional/control branch; inspect delay slot.
0x10240    90 10 20 1a    mov  0x1a, %o0
0x10244    90 10 20 1c    mov  0x1c, %o0
0x10248    91 2a 20 08    sll  %o0, 8, %o0
0x1024C    13 04 40 40    sethi  %hi(0x11010000), %o1            ! Build high part of constant/address.
0x10250    92 12 00 09    or  %o0, %o1, %o1
0x10254    90 10 20 69    mov  0x69, %o0
0x10258    94 10 20 00    clr  %o2
0x1025C    7f ff f2 83    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10260    96 10 20 03    mov  3, %o3
0x10264    7f ff fd 08    call  0xf684                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10268    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x1026C    d2 05 a0 e0    ld  [ %l6 + 0xe0 ], %o1
0x10270    11 00 08 00    sethi  %hi(0x200000), %o0              ! Build high part of constant/address.
0x10274    80 8a 40 08    btst  %o1, %o0
0x10278    02 80 00 03    be  0x10284                            ! Conditional/control branch; inspect delay slot.
0x1027C    11 00 80 45    sethi  %hi(0x2011400), %o0             ! Build high part of constant/address.
0x10280    11 00 80 41    sethi  %hi(0x2010400), %o0             ! Build high part of constant/address.
0x10284    92 12 22 00    or  %o0, 0x200, %o1                    ! 0x2010600
0x10288    90 10 20 69    mov  0x69, %o0
0x1028C    94 10 20 00    clr  %o2
0x10290    7f ff f2 76    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10294    96 10 20 03    mov  3, %o3
0x10298    d2 05 a0 e0    ld  [ %l6 + 0xe0 ], %o1
0x1029C    11 00 04 00    sethi  %hi(0x100000), %o0              ! Build high part of constant/address.
0x102A0    80 8a 40 08    btst  %o1, %o0
0x102A4    02 80 00 03    be  0x102b0                            ! Conditional/control branch; inspect delay slot.
0x102A8    13 00 c0 7d    sethi  %hi(0x301f400), %o1             ! Build high part of constant/address.
0x102AC    13 00 c0 5d    sethi  %hi(0x3017400), %o1             ! Build high part of constant/address.
0x102B0    94 10 20 00    clr  %o2
0x102B4    96 10 20 03    mov  3, %o3
0x102B8    7f ff f2 6c    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x102BC    90 10 20 69    mov  0x69, %o0
0x102C0    7f ff f0 19    call  0xc324                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x102C4    90 10 20 00    clr  %o0
0x102C8    7f ff f1 10    call  0xc708                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x102CC    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x102D0    80 a2 20 00    cmp  %o0, 0
0x102D4    02 80 00 04    be  0x102e4                            ! Conditional/control branch; inspect delay slot.
0x102D8    90 10 20 00    clr  %o0
0x102DC    7f ff fe 06    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x102E0    92 10 20 0d    mov  0xd, %o1
0x102E4    7f ff fa b8    call  0xedc4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x102E8    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x102EC    80 a2 20 00    cmp  %o0, 0
0x102F0    02 80 01 24    be  0x10780                            ! Conditional/control branch; inspect delay slot.
0x102F4    13 21 e0 db    sethi  %hi(0x87836c00), %o1            ! Build high part of constant/address.
0x102F8    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x102FC    d2 0a 23 a8    ldub  [ %o0 + 0x3a8 ], %o1             ! 0x878373a8
0x10300    ae 10 00 08    mov  %o0, %l7
0x10304    80 a2 60 00    cmp  %o1, 0
0x10308    02 80 00 2f    be  0x103c4                            ! Conditional/control branch; inspect delay slot.
0x1030C    27 21 e0 db    sethi  %hi(0x87836c00), %l3            ! Build high part of constant/address.
0x10310    17 08 00 00    sethi  %hi(0x20000000), %o3            ! Build high part of constant/address.
0x10314    94 12 e0 68    or  %o3, 0x68, %o2                     ! 0x20000068
0x10318    d0 02 80 00    ld  [ %o2 ], %o0
0x1031C    96 12 e0 c4    or  %o3, 0xc4, %o3
0x10320    90 0a 3f fc    and  %o0, -4, %o0
0x10324    d0 22 80 00    st  %o0, [ %o2 ]
0x10328    d2 02 c0 00    ld  [ %o3 ], %o1
0x1032C    15 00 00 20    sethi  %hi(0x8000), %o2                ! Build high part of constant/address.
0x10330    92 12 40 0a    or  %o1, %o2, %o1
0x10334    11 00 00 10    sethi  %hi(0x4000), %o0                ! Build high part of constant/address.
0x10338    90 2a 40 08    andn  %o1, %o0, %o0
0x1033C    d0 22 c0 00    st  %o0, [ %o3 ]
0x10340    a0 10 20 00    clr  %l0
0x10344    11 08 00 00    sethi  %hi(0x20000000), %o0            ! Build high part of constant/address.
0x10348    a2 12 20 c0    or  %o0, 0xc0, %l1                     ! 0x200000c0
0x1034C    13 00 03 20    sethi  %hi(0xc8000), %o1               ! Build high part of constant/address.
0x10350    90 10 25 dc    mov  0x5dc, %o0
0x10354    80 a4 20 04    cmp  %l0, 4
0x10358    14 80 00 11    bg  0x1039c                            ! Conditional/control branch; inspect delay slot.
0x1035C    25 00 00 10    sethi  %hi(0x4000), %l2                ! Build high part of constant/address.
0x10360    d2 24 40 00    st  %o1, [ %l1 ]
0x10364    6a 1f 30 27    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10368    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x1036C    d2 04 40 00    ld  [ %l1 ], %o1
0x10370    15 00 03 00    sethi  %hi(0xc0000), %o2               ! Build high part of constant/address.
0x10374    80 8a 40 12    btst  %o1, %l2
0x10378    12 80 00 09    bne  0x1039c                           ! Conditional/control branch; inspect delay slot.
0x1037C    90 10 25 dc    mov  0x5dc, %o0
0x10380    d4 24 40 00    st  %o2, [ %l1 ]
0x10384    6a 1f 30 1f    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10388    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x1038C    d0 04 40 00    ld  [ %l1 ], %o0
0x10390    80 8a 00 12    btst  %o0, %l2
0x10394    22 bf ff ec    be,a   0x10344                         ! Conditional/control branch; inspect delay slot.
0x10398    a0 04 20 01    inc  %l0
0x1039C    13 08 00 00    sethi  %hi(0x20000000), %o1            ! Build high part of constant/address.
0x103A0    92 12 60 68    or  %o1, 0x68, %o1                     ! 0x20000068
0x103A4    d0 02 40 00    ld  [ %o1 ], %o0
0x103A8    80 a4 20 05    cmp  %l0, 5
0x103AC    90 12 20 03    or  %o0, 3, %o0
0x103B0    d0 22 40 00    st  %o0, [ %o1 ]
0x103B4    12 80 00 04    bne  0x103c4                           ! Conditional/control branch; inspect delay slot.
0x103B8    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x103BC    6a 1f 32 43    call  0xa87dccc8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x103C0    90 10 20 18    mov  0x18, %o0                         ! 0x18
0x103C4    7f ff f9 a5    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x103C8    90 14 e2 78    or  %l3, 0x278, %o0
0x103CC    7f ff f9 cc    call  0xeafc                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x103D0    d0 0d e3 a8    ldub  [ %l7 + 0x3a8 ], %o0
0x103D4    7f ff f9 e3    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x103D8    90 10 20 0a    mov  0xa, %o0
0x103DC    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x103E0    d2 02 20 c8    ld  [ %o0 + 0xc8 ], %o1                ! 0x878370c8
0x103E4    80 a2 60 00    cmp  %o1, 0
0x103E8    02 80 00 98    be  0x10648                            ! Conditional/control branch; inspect delay slot.
0x103EC    92 10 20 0a    mov  0xa, %o1
0x103F0    d0 0d a0 0f    ldub  [ %l6 + 0xf ], %o0
0x103F4    80 a2 20 09    cmp  %o0, 9
0x103F8    02 80 00 94    be  0x10648                            ! Conditional/control branch; inspect delay slot.
0x103FC    94 10 00 08    mov  %o0, %o2
0x10400    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x10404    d2 0a 21 10    ldub  [ %o0 + 0x110 ], %o1             ! 0x87837110
0x10408    80 a2 60 00    cmp  %o1, 0
0x1040C    02 80 00 76    be  0x105e4                            ! Conditional/control branch; inspect delay slot.
0x10410    92 10 20 09    mov  9, %o1
0x10414    7f ff fd b8    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10418    90 10 20 00    clr  %o0
0x1041C    7f ff ef c2    call  0xc324                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10420    90 10 20 01    mov  1, %o0
0x10424    d2 0d a0 0f    ldub  [ %l6 + 0xf ], %o1
0x10428    80 a2 60 0a    cmp  %o1, 0xa
0x1042C    12 80 00 37    bne  0x10508                           ! Conditional/control branch; inspect delay slot.
0x10430    21 21 e0 dc    sethi  %hi(0x87837000), %l0            ! Build high part of constant/address.
0x10434    21 21 e0 dc    sethi  %hi(0x87837000), %l0            ! Build high part of constant/address.
0x10438    23 21 e0 dc    sethi  %hi(0x87837000), %l1            ! Build high part of constant/address.
0x1043C    33 21 e0 dc    sethi  %hi(0x87837000), %i1            ! Build high part of constant/address.
0x10440    31 21 e0 dc    sethi  %hi(0x87837000), %i0            ! Build high part of constant/address.
0x10444    2f 21 e0 dc    sethi  %hi(0x87837000), %l7            ! Build high part of constant/address.
0x10448    10 80 00 11    b  0x1048c                             ! Conditional/control branch; inspect delay slot.
0x1044C    35 21 e0 dc    sethi  %hi(0x87837000), %i2            ! Build high part of constant/address.
0x10450    7f ff f9 82    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10454    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10458    d2 0d 63 b0    ldub  [ %l5 + 0x3b0 ], %o1
0x1045C    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x10460    80 a2 60 00    cmp  %o1, 0
0x10464    02 80 00 0a    be  0x1048c                            ! Conditional/control branch; inspect delay slot.
0x10468    90 12 21 08    or  %o0, 0x108, %o0
0x1046C    40 00 08 2d    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10470    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10474    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x10478    40 00 08 2a    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1047C    90 12 20 e8    or  %o0, 0xe8, %o0                     ! 0x87836ce8
0x10480    11 00 01 a5    sethi  %hi(0x69400), %o0               ! Build high part of constant/address.
0x10484    6a 1f 2f df    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10488    90 12 23 e4    or  %o0, 0x3e4, %o0                    ! 0x697e4
0x1048C    92 14 21 4c    or  %l0, 0x14c, %o1
0x10490    7f ff f7 8e    call  0xe2c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10494    90 10 20 06    mov  6, %o0
0x10498    13 21 e0 db    sethi  %hi(0x87836c00), %o1            ! Build high part of constant/address.
0x1049C    80 a2 20 00    cmp  %o0, 0
0x104A0    12 bf ff ec    bne  0x10450                           ! Conditional/control branch; inspect delay slot.
0x104A4    90 12 62 80    or  %o1, 0x280, %o0
0x104A8    a6 10 00 09    mov  %o1, %l3
0x104AC    25 21 e0 db    sethi  %hi(0x87836c00), %l2            ! Build high part of constant/address.
0x104B0    10 80 00 0f    b  0x104ec                             ! Conditional/control branch; inspect delay slot.
0x104B4    21 21 e0 db    sethi  %hi(0x87836c00), %l0            ! Build high part of constant/address.
0x104B8    7f ff f9 68    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x104BC    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x104C0    d2 0d 63 b0    ldub  [ %l5 + 0x3b0 ], %o1
0x104C4    80 a2 60 00    cmp  %o1, 0
0x104C8    02 80 00 09    be  0x104ec                            ! Conditional/control branch; inspect delay slot.
0x104CC    90 14 a1 08    or  %l2, 0x108, %o0
0x104D0    40 00 08 14    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x104D4    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x104D8    40 00 08 12    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x104DC    90 14 20 f8    or  %l0, 0xf8, %o0
0x104E0    11 00 01 a5    sethi  %hi(0x69400), %o0               ! Build high part of constant/address.
0x104E4    6a 1f 2f c7    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x104E8    90 12 23 e4    or  %o0, 0x3e4, %o0                    ! 0x697e4
0x104EC    90 10 20 06    mov  6, %o0
0x104F0    7f ff f7 76    call  0xe2c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x104F4    92 14 61 64    or  %l1, 0x164, %o1
0x104F8    80 a2 20 00    cmp  %o0, 0
0x104FC    12 bf ff ef    bne  0x104b8                           ! Conditional/control branch; inspect delay slot.
0x10500    90 14 e2 80    or  %l3, 0x280, %o0
0x10504    30 80 00 34    b,a   0x105d4                          ! Conditional/control branch; inspect delay slot.
0x10508    23 21 e0 dc    sethi  %hi(0x87837000), %l1            ! Build high part of constant/address.
0x1050C    33 21 e0 dc    sethi  %hi(0x87837000), %i1            ! Build high part of constant/address.
0x10510    31 21 e0 dc    sethi  %hi(0x87837000), %i0            ! Build high part of constant/address.
0x10514    2f 21 e0 dc    sethi  %hi(0x87837000), %l7            ! Build high part of constant/address.
0x10518    10 80 00 11    b  0x1055c                             ! Conditional/control branch; inspect delay slot.
0x1051C    35 21 e0 dc    sethi  %hi(0x87837000), %i2            ! Build high part of constant/address.
0x10520    7f ff f9 4e    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10524    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10528    d2 0d 63 b0    ldub  [ %l5 + 0x3b0 ], %o1
0x1052C    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x10530    80 a2 60 00    cmp  %o1, 0
0x10534    02 80 00 0a    be  0x1055c                            ! Conditional/control branch; inspect delay slot.
0x10538    90 12 21 08    or  %o0, 0x108, %o0
0x1053C    40 00 07 f9    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10540    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10544    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x10548    40 00 07 f6    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1054C    90 12 20 c8    or  %o0, 0xc8, %o0                     ! 0x87836cc8
0x10550    11 00 01 a5    sethi  %hi(0x69400), %o0               ! Build high part of constant/address.
0x10554    6a 1f 2f ab    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10558    90 12 23 e4    or  %o0, 0x3e4, %o0                    ! 0x697e4
0x1055C    92 14 21 1c    or  %l0, 0x11c, %o1
0x10560    7f ff f7 5a    call  0xe2c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10564    90 10 20 06    mov  6, %o0
0x10568    13 21 e0 db    sethi  %hi(0x87836c00), %o1            ! Build high part of constant/address.
0x1056C    80 a2 20 00    cmp  %o0, 0
0x10570    12 bf ff ec    bne  0x10520                           ! Conditional/control branch; inspect delay slot.
0x10574    90 12 62 80    or  %o1, 0x280, %o0
0x10578    a6 10 00 09    mov  %o1, %l3
0x1057C    25 21 e0 db    sethi  %hi(0x87836c00), %l2            ! Build high part of constant/address.
0x10580    10 80 00 0f    b  0x105bc                             ! Conditional/control branch; inspect delay slot.
0x10584    21 21 e0 db    sethi  %hi(0x87836c00), %l0            ! Build high part of constant/address.
0x10588    7f ff f9 34    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1058C    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10590    d2 0d 63 b0    ldub  [ %l5 + 0x3b0 ], %o1
0x10594    80 a2 60 00    cmp  %o1, 0
0x10598    02 80 00 09    be  0x105bc                            ! Conditional/control branch; inspect delay slot.
0x1059C    90 14 a1 08    or  %l2, 0x108, %o0
0x105A0    40 00 07 e0    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x105A4    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x105A8    40 00 07 de    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x105AC    90 14 20 d8    or  %l0, 0xd8, %o0
0x105B0    11 00 01 a5    sethi  %hi(0x69400), %o0               ! Build high part of constant/address.
0x105B4    6a 1f 2f 93    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x105B8    90 12 23 e4    or  %o0, 0x3e4, %o0                    ! 0x697e4
0x105BC    90 10 20 06    mov  6, %o0
0x105C0    7f ff f7 42    call  0xe2c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x105C4    92 14 61 34    or  %l1, 0x134, %o1
0x105C8    80 a2 20 00    cmp  %o0, 0
0x105CC    12 bf ff ef    bne  0x10588                           ! Conditional/control branch; inspect delay slot.
0x105D0    90 14 e2 80    or  %l3, 0x280, %o0
0x105D4    7f ff ef 54    call  0xc324                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x105D8    90 10 20 00    clr  %o0
0x105DC    10 80 00 56    b  0x10734                             ! Conditional/control branch; inspect delay slot.
0x105E0    d4 0d 63 b0    ldub  [ %l5 + 0x3b0 ], %o2
0x105E4    80 a2 a0 0c    cmp  %o2, 0xc
0x105E8    32 80 00 11    bne,a   0x1062c                        ! Conditional/control branch; inspect delay slot.
0x105EC    90 10 20 01    mov  1, %o0
0x105F0    33 21 e0 dc    sethi  %hi(0x87837000), %i1            ! Build high part of constant/address.
0x105F4    31 21 e0 dc    sethi  %hi(0x87837000), %i0            ! Build high part of constant/address.
0x105F8    2f 21 e0 dc    sethi  %hi(0x87837000), %l7            ! Build high part of constant/address.
0x105FC    10 80 00 04    b  0x1060c                             ! Conditional/control branch; inspect delay slot.
0x10600    35 21 e0 dc    sethi  %hi(0x87837000), %i2            ! Build high part of constant/address.
0x10604    7f ff f9 15    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10608    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x1060C    40 00 04 ec    call  0x119bc                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10610    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10614    13 21 e0 db    sethi  %hi(0x87836c00), %o1            ! Build high part of constant/address.
0x10618    80 a2 20 00    cmp  %o0, 0
0x1061C    12 bf ff fa    bne  0x10604                           ! Conditional/control branch; inspect delay slot.
0x10620    90 12 62 88    or  %o1, 0x288, %o0
0x10624    10 80 00 44    b  0x10734                             ! Conditional/control branch; inspect delay slot.
0x10628    d4 0d 63 b0    ldub  [ %l5 + 0x3b0 ], %o2
0x1062C    7f ff f3 07    call  0xd248                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10630    92 15 23 74    or  %l4, 0x374, %o1
0x10634    33 21 e0 dc    sethi  %hi(0x87837000), %i1            ! Build high part of constant/address.
0x10638    31 21 e0 dc    sethi  %hi(0x87837000), %i0            ! Build high part of constant/address.
0x1063C    2f 21 e0 dc    sethi  %hi(0x87837000), %l7            ! Build high part of constant/address.
0x10640    10 80 00 3c    b  0x10730                             ! Conditional/control branch; inspect delay slot.
0x10644    35 21 e0 dc    sethi  %hi(0x87837000), %i2            ! Build high part of constant/address.
0x10648    7f ff fd 2b    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1064C    90 10 20 00    clr  %o0
0x10650    7f ff ef 35    call  0xc324                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10654    90 10 20 01    mov  1, %o0
0x10658    21 21 e0 dc    sethi  %hi(0x87837000), %l0            ! Build high part of constant/address.
0x1065C    23 21 e0 dc    sethi  %hi(0x87837000), %l1            ! Build high part of constant/address.
0x10660    33 21 e0 dc    sethi  %hi(0x87837000), %i1            ! Build high part of constant/address.
0x10664    31 21 e0 dc    sethi  %hi(0x87837000), %i0            ! Build high part of constant/address.
0x10668    2f 21 e0 dc    sethi  %hi(0x87837000), %l7            ! Build high part of constant/address.
0x1066C    10 80 00 11    b  0x106b0                             ! Conditional/control branch; inspect delay slot.
0x10670    35 21 e0 dc    sethi  %hi(0x87837000), %i2            ! Build high part of constant/address.
0x10674    7f ff f8 f9    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10678    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x1067C    d2 0d 63 b0    ldub  [ %l5 + 0x3b0 ], %o1
0x10680    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x10684    80 a2 60 00    cmp  %o1, 0
0x10688    02 80 00 0a    be  0x106b0                            ! Conditional/control branch; inspect delay slot.
0x1068C    90 12 21 08    or  %o0, 0x108, %o0
0x10690    40 00 07 a4    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10694    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10698    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x1069C    40 00 07 a1    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x106A0    90 12 20 40    or  %o0, 0x40, %o0                     ! 0x87836c40
0x106A4    11 00 01 a5    sethi  %hi(0x69400), %o0               ! Build high part of constant/address.
0x106A8    6a 1f 2f 56    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x106AC    90 12 23 e4    or  %o0, 0x3e4, %o0                    ! 0x697e4
0x106B0    92 14 20 d0    or  %l0, 0xd0, %o1
0x106B4    7f ff f7 05    call  0xe2c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x106B8    90 10 20 06    mov  6, %o0
0x106BC    13 21 e0 db    sethi  %hi(0x87836c00), %o1            ! Build high part of constant/address.
0x106C0    80 a2 20 00    cmp  %o0, 0
0x106C4    12 bf ff ec    bne  0x10674                           ! Conditional/control branch; inspect delay slot.
0x106C8    90 12 62 80    or  %o1, 0x280, %o0
0x106CC    a6 10 00 09    mov  %o1, %l3
0x106D0    25 21 e0 db    sethi  %hi(0x87836c00), %l2            ! Build high part of constant/address.
0x106D4    10 80 00 0f    b  0x10710                             ! Conditional/control branch; inspect delay slot.
0x106D8    21 21 e0 db    sethi  %hi(0x87836c00), %l0            ! Build high part of constant/address.
0x106DC    7f ff f8 df    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x106E0    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x106E4    d2 0d 63 b0    ldub  [ %l5 + 0x3b0 ], %o1
0x106E8    80 a2 60 00    cmp  %o1, 0
0x106EC    02 80 00 09    be  0x10710                            ! Conditional/control branch; inspect delay slot.
0x106F0    90 14 a1 08    or  %l2, 0x108, %o0
0x106F4    40 00 07 8b    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x106F8    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x106FC    40 00 07 89    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10700    90 14 20 a0    or  %l0, 0xa0, %o0
0x10704    11 00 01 a5    sethi  %hi(0x69400), %o0               ! Build high part of constant/address.
0x10708    6a 1f 2f 3e    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1070C    90 12 23 e4    or  %o0, 0x3e4, %o0                    ! 0x697e4
0x10710    90 10 20 06    mov  6, %o0
0x10714    7f ff f6 ed    call  0xe2c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10718    92 14 60 e8    or  %l1, 0xe8, %o1
0x1071C    80 a2 20 00    cmp  %o0, 0
0x10720    12 bf ff ef    bne  0x106dc                           ! Conditional/control branch; inspect delay slot.
0x10724    90 14 e2 80    or  %l3, 0x280, %o0
0x10728    7f ff ee ff    call  0xc324                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1072C    90 10 20 00    clr  %o0
0x10730    d4 0d 63 b0    ldub  [ %l5 + 0x3b0 ], %o2
0x10734    11 08 00 02    sethi  %hi(0x20000800), %o0            ! Build high part of constant/address.
0x10738    da 06 61 a8    ld  [ %i1 + 0x1a8 ], %o5
0x1073C    90 12 20 08    or  %o0, 8, %o0
0x10740    d8 16 21 a4    lduh  [ %i0 + 0x1a4 ], %o4
0x10744    13 00 30 00    sethi  %hi(0xc00000), %o1              ! Build high part of constant/address.
0x10748    d6 15 e1 a2    lduh  [ %l7 + 0x1a2 ], %o3
0x1074C    80 a2 a0 00    cmp  %o2, 0
0x10750    d2 22 00 00    st  %o1, [ %o0 ]
0x10754    da 25 a0 f0    st  %o5, [ %l6 + 0xf0 ]
0x10758    d8 35 a0 ee    sth  %o4, [ %l6 + 0xee ]
0x1075C    02 80 00 05    be  0x10770                            ! Conditional/control branch; inspect delay slot.
0x10760    d6 35 a0 f4    sth  %o3, [ %l6 + 0xf4 ]
0x10764    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x10768    40 00 07 6e    call  0x12520                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1076C    90 12 22 98    or  %o0, 0x298, %o0                    ! 0x87836e98
0x10770    92 16 a1 00    or  %i2, 0x100, %o1
0x10774    7f ff fd 41    call  0xfc78                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10778    90 10 20 02    mov  2, %o0
0x1077C    13 21 e0 db    sethi  %hi(0x87836c00), %o1            ! Build high part of constant/address.
0x10780    7f ff f8 b6    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10784    90 12 62 a0    or  %o1, 0x2a0, %o0                    ! 0x87836ea0
0x10788    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x1078C    a4 12 23 74    or  %o0, 0x374, %l2                    ! 0x87837374
0x10790    a6 10 00 1b    mov  %i3, %l3
0x10794    15 21 e0 db    sethi  %hi(0x87836c00), %o2            ! Build high part of constant/address.
0x10798    7f ff f8 b0    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1079C    90 12 a3 00    or  %o2, 0x300, %o0                    ! 0x87836f00
0x107A0    90 10 00 13    mov  %l3, %o0
0x107A4    7f ff f9 53    call  0xecf0                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x107A8    92 10 20 63    mov  0x63, %o1
0x107AC    90 10 00 13    mov  %l3, %o0
0x107B0    92 10 00 12    mov  %l2, %o1
0x107B4    7f ff f9 24    call  0xec44                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x107B8    94 10 20 06    mov  6, %o2
0x107BC    a0 92 20 00    orcc  %o0, 0, %l0
0x107C0    02 bf ff f6    be  0x10798                            ! Conditional/control branch; inspect delay slot.
0x107C4    15 21 e0 db    sethi  %hi(0x87836c00), %o2            ! Build high part of constant/address.
0x107C8    d0 05 23 74    ld  [ %l4 + 0x374 ], %o0
0x107CC    7f ff f8 31    call  0xe890                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x107D0    92 17 20 88    or  %i4, 0x88, %o1
0x107D4    80 a2 20 00    cmp  %o0, 0
0x107D8    22 80 00 12    be,a   0x10820                         ! Conditional/control branch; inspect delay slot.
0x107DC    d0 05 23 74    ld  [ %l4 + 0x374 ], %o0
0x107E0    7f ff ee d1    call  0xc324                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x107E4    90 10 20 01    mov  1, %o0
0x107E8    10 80 00 04    b  0x107f8                             ! Conditional/control branch; inspect delay slot.
0x107EC    23 21 e0 db    sethi  %hi(0x87836c00), %l1            ! Build high part of constant/address.
0x107F0    7f ff f8 9a    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x107F4    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x107F8    90 10 00 10    mov  %l0, %o0
0x107FC    7f ff f6 b3    call  0xe2c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10800    92 15 23 74    or  %l4, 0x374, %o1
0x10804    80 a2 20 00    cmp  %o0, 0
0x10808    12 bf ff fa    bne  0x107f0                           ! Conditional/control branch; inspect delay slot.
0x1080C    90 14 62 80    or  %l1, 0x280, %o0
0x10810    7f ff ee c5    call  0xc324                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10814    90 10 20 00    clr  %o0
0x10818    10 bf ff e0    b  0x10798                             ! Conditional/control branch; inspect delay slot.
0x1081C    15 21 e0 db    sethi  %hi(0x87836c00), %o2            ! Build high part of constant/address.
0x10820    7f ff f8 1c    call  0xe890                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10824    92 17 60 b0    or  %i5, 0xb0, %o1
0x10828    80 a2 20 00    cmp  %o0, 0
0x1082C    02 80 00 06    be  0x10844                            ! Conditional/control branch; inspect delay slot.
0x10830    90 10 00 10    mov  %l0, %o0
0x10834    7f ff fd 11    call  0xfc78                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10838    92 10 00 12    mov  %l2, %o1
0x1083C    10 bf ff d7    b  0x10798                             ! Conditional/control branch; inspect delay slot.
0x10840    15 21 e0 db    sethi  %hi(0x87836c00), %o2            ! Build high part of constant/address.
0x10844    15 21 e0 db    sethi  %hi(0x87836c00), %o2            ! Build high part of constant/address.
0x10848    d0 05 23 74    ld  [ %l4 + 0x374 ], %o0
0x1084C    7f ff f8 11    call  0xe890                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10850    92 12 a3 08    or  %o2, 0x308, %o1
0x10854    80 a2 20 00    cmp  %o0, 0
0x10858    02 80 00 06    be  0x10870                            ! Conditional/control branch; inspect delay slot.
0x1085C    90 10 00 10    mov  %l0, %o0
0x10860    7f ff f2 7a    call  0xd248                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10864    92 10 00 12    mov  %l2, %o1
0x10868    10 bf ff cc    b  0x10798                             ! Conditional/control branch; inspect delay slot.
0x1086C    15 21 e0 db    sethi  %hi(0x87836c00), %o2            ! Build high part of constant/address.
0x10870    15 21 e0 db    sethi  %hi(0x87836c00), %o2            ! Build high part of constant/address.
0x10874    d0 05 23 74    ld  [ %l4 + 0x374 ], %o0
0x10878    7f ff f8 06    call  0xe890                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1087C    92 12 a3 10    or  %o2, 0x310, %o1
0x10880    80 a2 20 00    cmp  %o0, 0
0x10884    22 80 00 06    be,a   0x1089c                         ! Conditional/control branch; inspect delay slot.
0x10888    15 21 e0 db    sethi  %hi(0x87836c00), %o2            ! Build high part of constant/address.
0x1088C    40 00 04 4c    call  0x119bc                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10890    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10894    10 bf ff c1    b  0x10798                             ! Conditional/control branch; inspect delay slot.
0x10898    15 21 e0 db    sethi  %hi(0x87836c00), %o2            ! Build high part of constant/address.
0x1089C    d0 05 23 74    ld  [ %l4 + 0x374 ], %o0
0x108A0    7f ff f7 fc    call  0xe890                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x108A4    92 12 a3 18    or  %o2, 0x318, %o1
0x108A8    80 a2 20 00    cmp  %o0, 0
0x108AC    02 80 00 0f    be  0x108e8                            ! Conditional/control branch; inspect delay slot.
0x108B0    92 10 20 00    clr  %o1
0x108B4    d0 04 a0 04    ld  [ %l2 + 4 ], %o0
0x108B8    7f ff f8 59    call  0xea1c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x108BC    94 10 20 00    clr  %o2
0x108C0    90 0a 20 ff    and  %o0, 0xff, %o0
0x108C4    91 2a 20 08    sll  %o0, 8, %o0
0x108C8    13 04 40 40    sethi  %hi(0x11010000), %o1            ! Build high part of constant/address.
0x108CC    92 12 00 09    or  %o0, %o1, %o1
0x108D0    90 10 20 69    mov  0x69, %o0
0x108D4    94 10 20 00    clr  %o2
0x108D8    7f ff f0 e4    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x108DC    96 10 20 03    mov  3, %o3
0x108E0    10 bf ff ae    b  0x10798                             ! Conditional/control branch; inspect delay slot.
0x108E4    15 21 e0 db    sethi  %hi(0x87836c00), %o2            ! Build high part of constant/address.
0x108E8    15 21 e0 db    sethi  %hi(0x87836c00), %o2            ! Build high part of constant/address.
0x108EC    d0 05 23 74    ld  [ %l4 + 0x374 ], %o0
0x108F0    7f ff f7 e8    call  0xe890                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x108F4    92 12 a3 20    or  %o2, 0x320, %o1
0x108F8    80 a2 20 00    cmp  %o0, 0
0x108FC    12 bf fe b8    bne  0x103dc                           ! Conditional/control branch; inspect delay slot.
0x10900    15 21 e0 db    sethi  %hi(0x87836c00), %o2            ! Build high part of constant/address.
0x10904    d0 05 23 74    ld  [ %l4 + 0x374 ], %o0
0x10908    7f ff f7 e2    call  0xe890                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1090C    92 12 a3 28    or  %o2, 0x328, %o1
0x10910    80 a2 20 00    cmp  %o0, 0
0x10914    02 80 00 07    be  0x10930                            ! Conditional/control branch; inspect delay slot.
0x10918    92 10 20 00    clr  %o1
0x1091C    d0 04 a0 04    ld  [ %l2 + 4 ], %o0
0x10920    7f ff f8 3f    call  0xea1c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10924    94 10 20 00    clr  %o2
0x10928    10 bf ff 9b    b  0x10794                             ! Conditional/control branch; inspect delay slot.
0x1092C    d0 2d a0 0f    stb  %o0, [ %l6 + 0xf ]
0x10930    13 21 e0 db    sethi  %hi(0x87836c00), %o1            ! Build high part of constant/address.
0x10934    7f ff f8 49    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10938    90 12 63 30    or  %o1, 0x330, %o0                    ! 0x87836f30
0x1093C    10 bf ff 97    b  0x10798                             ! Conditional/control branch; inspect delay slot.
0x10940    15 21 e0 db    sethi  %hi(0x87836c00), %o2            ! Build high part of constant/address.
0x10944    13 08 00 00    sethi  %hi(0x20000000), %o1            ! Build high part of constant/address.
0x10948    94 12 60 94    or  %o1, 0x94, %o2                     ! 0x20000094
0x1094C    c6 02 80 00    ld  [ %o2 ], %g3
0x10950    11 00 00 40    sethi  %hi(0x10000), %o0               ! Build high part of constant/address.
0x10954    90 28 c0 08    andn  %g3, %o0, %o0
0x10958    05 00 00 40    sethi  %hi(0x10000), %g2               ! Build high part of constant/address.
0x1095C    84 12 00 02    or  %o0, %g2, %g2
0x10960    07 00 00 0c    sethi  %hi(0x3000), %g3                ! Build high part of constant/address.
0x10964    c4 22 80 00    st  %g2, [ %o2 ]
0x10968    92 12 61 0c    or  %o1, 0x10c, %o1
0x1096C    86 10 e0 2c    or  %g3, 0x2c, %g3
0x10970    c6 22 40 00    st  %g3, [ %o1 ]
0x10974    d0 22 80 00    st  %o0, [ %o2 ]
0x10978    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x1097C    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10980    92 0a 60 1f    and  %o1, 0x1f, %o1
0x10984    05 20 00 00    sethi  %hi(0x80000000), %g2            ! Build high part of constant/address.
0x10988    90 0a 20 ff    and  %o0, 0xff, %o0
0x1098C    93 2a 60 0b    sll  %o1, 0xb, %o1
0x10990    92 12 40 02    or  %o1, %g2, %o1
0x10994    91 2a 20 10    sll  %o0, 0x10, %o0
0x10998    94 0a a0 07    and  %o2, 7, %o2
0x1099C    90 12 00 09    or  %o0, %o1, %o0
0x109A0    19 21 e0 dc    sethi  %hi(0x87837000), %o4            ! Build high part of constant/address.
0x109A4    95 2a a0 08    sll  %o2, 8, %o2
0x109A8    c6 03 21 f0    ld  [ %o4 + 0x1f0 ], %g3
0x109AC    90 12 00 0a    or  %o0, %o2, %o0
0x109B0    96 0a e0 fc    and  %o3, 0xfc, %o3
0x109B4    90 12 00 0b    or  %o0, %o3, %o0
0x109B8    d0 20 c0 00    st  %o0, [ %g3 ]
0x109BC    05 21 e0 dc    sethi  %hi(0x87837000), %g2            ! Build high part of constant/address.
0x109C0    c6 00 a1 f4    ld  [ %g2 + 0x1f4 ], %g3               ! 0x878371f4
0x109C4    d2 03 21 f0    ld  [ %o4 + 0x1f0 ], %o1
0x109C8    d0 00 c0 00    ld  [ %g3 ], %o0
0x109CC    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x109D0    c0 22 40 00    clr  [ %o1 ]
0x109D4    92 0a 60 1f    and  %o1, 0x1f, %o1
0x109D8    05 20 00 00    sethi  %hi(0x80000000), %g2            ! Build high part of constant/address.
0x109DC    90 0a 20 ff    and  %o0, 0xff, %o0
0x109E0    93 2a 60 0b    sll  %o1, 0xb, %o1
0x109E4    92 12 40 02    or  %o1, %g2, %o1
0x109E8    91 2a 20 10    sll  %o0, 0x10, %o0
0x109EC    90 12 00 09    or  %o0, %o1, %o0
0x109F0    94 0a a0 07    and  %o2, 7, %o2
0x109F4    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x109F8    95 2a a0 08    sll  %o2, 8, %o2
0x109FC    c6 02 61 f0    ld  [ %o1 + 0x1f0 ], %g3
0x10A00    90 12 00 0a    or  %o0, %o2, %o0
0x10A04    96 0a e0 fc    and  %o3, 0xfc, %o3
0x10A08    90 12 00 0b    or  %o0, %o3, %o0
0x10A0C    d0 20 c0 00    st  %o0, [ %g3 ]
0x10A10    05 21 e0 dc    sethi  %hi(0x87837000), %g2            ! Build high part of constant/address.
0x10A14    c6 00 a1 f4    ld  [ %g2 + 0x1f4 ], %g3               ! 0x878371f4
0x10A18    d8 20 c0 00    st  %o4, [ %g3 ]
0x10A1C    c4 02 61 f0    ld  [ %o1 + 0x1f0 ], %g2
0x10A20    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x10A24    c0 20 80 00    clr  [ %g2 ]
0x10A28    92 0a 60 1f    and  %o1, 0x1f, %o1
0x10A2C    05 20 00 00    sethi  %hi(0x80000000), %g2            ! Build high part of constant/address.
0x10A30    90 0a 20 ff    and  %o0, 0xff, %o0
0x10A34    93 2a 60 0b    sll  %o1, 0xb, %o1
0x10A38    92 12 40 02    or  %o1, %g2, %o1
0x10A3C    91 2a 20 10    sll  %o0, 0x10, %o0
0x10A40    90 12 00 09    or  %o0, %o1, %o0
0x10A44    94 0a a0 07    and  %o2, 7, %o2
0x10A48    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x10A4C    95 2a a0 08    sll  %o2, 8, %o2
0x10A50    c6 02 61 f0    ld  [ %o1 + 0x1f0 ], %g3
0x10A54    84 0a e0 fc    and  %o3, 0xfc, %g2
0x10A58    90 12 00 0a    or  %o0, %o2, %o0
0x10A5C    90 12 00 02    or  %o0, %g2, %o0
0x10A60    d0 20 c0 00    st  %o0, [ %g3 ]
0x10A64    05 21 e0 dc    sethi  %hi(0x87837000), %g2            ! Build high part of constant/address.
0x10A68    c6 00 a1 f4    ld  [ %g2 + 0x1f4 ], %g3               ! 0x878371f4
0x10A6C    80 8a e0 02    btst  2, %o3
0x10A70    c4 00 c0 00    ld  [ %g3 ], %g2
0x10A74    d0 02 61 f0    ld  [ %o1 + 0x1f0 ], %o0
0x10A78    02 80 00 03    be  0x10a84                            ! Conditional/control branch; inspect delay slot.
0x10A7C    c0 22 00 00    clr  [ %o0 ]
0x10A80    85 30 a0 10    srl  %g2, 0x10, %g2
0x10A84    91 28 a0 10    sll  %g2, 0x10, %o0
0x10A88    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x10A8C    91 32 20 10    srl  %o0, 0x10, %o0
0x10A90    92 0a 60 1f    and  %o1, 0x1f, %o1
0x10A94    05 20 00 00    sethi  %hi(0x80000000), %g2            ! Build high part of constant/address.
0x10A98    90 0a 20 ff    and  %o0, 0xff, %o0
0x10A9C    93 2a 60 0b    sll  %o1, 0xb, %o1
0x10AA0    92 12 40 02    or  %o1, %g2, %o1
0x10AA4    91 2a 20 10    sll  %o0, 0x10, %o0
0x10AA8    94 0a a0 07    and  %o2, 7, %o2
0x10AAC    90 12 00 09    or  %o0, %o1, %o0
0x10AB0    07 21 e0 dc    sethi  %hi(0x87837000), %g3            ! Build high part of constant/address.
0x10AB4    95 2a a0 08    sll  %o2, 8, %o2
0x10AB8    d2 00 e1 f0    ld  [ %g3 + 0x1f0 ], %o1
0x10ABC    84 0a e0 fc    and  %o3, 0xfc, %g2
0x10AC0    90 12 00 0a    or  %o0, %o2, %o0
0x10AC4    90 12 00 02    or  %o0, %g2, %o0
0x10AC8    d0 22 40 00    st  %o0, [ %o1 ]
0x10ACC    05 21 e0 dc    sethi  %hi(0x87837000), %g2            ! Build high part of constant/address.
0x10AD0    d2 00 a1 f4    ld  [ %g2 + 0x1f4 ], %o1               ! 0x878371f4
0x10AD4    9a 10 00 03    mov  %g3, %o5
0x10AD8    80 8a e0 02    btst  2, %o3
0x10ADC    02 80 00 09    be  0x10b00                            ! Conditional/control branch; inspect delay slot.
0x10AE0    d0 02 40 00    ld  [ %o1 ], %o0
0x10AE4    05 00 00 3f    sethi  %hi(0xfc00), %g2                ! Build high part of constant/address.
0x10AE8    84 10 a3 ff    or  %g2, 0x3ff, %g2                    ! 0xffff
0x10AEC    90 0a 00 02    and  %o0, %g2, %o0
0x10AF0    87 2b 20 10    sll  %o4, 0x10, %g3
0x10AF4    86 12 00 03    or  %o0, %g3, %g3
0x10AF8    10 80 00 08    b  0x10b18                             ! Conditional/control branch; inspect delay slot.
0x10AFC    c6 22 40 00    st  %g3, [ %o1 ]
0x10B00    85 2b 20 10    sll  %o4, 0x10, %g2
0x10B04    07 3f ff c0    sethi  %hi(0xffff0000), %g3            ! Build high part of constant/address.
0x10B08    90 0a 00 03    and  %o0, %g3, %o0
0x10B0C    85 30 a0 10    srl  %g2, 0x10, %g2
0x10B10    84 12 00 02    or  %o0, %g2, %g2
0x10B14    c4 22 40 00    st  %g2, [ %o1 ]
0x10B18    c4 03 61 f0    ld  [ %o5 + 0x1f0 ], %g2
0x10B1C    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x10B20    c0 20 80 00    clr  [ %g2 ]
0x10B24    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x10B28    90 10 22 00    mov  0x200, %o0
0x10B2C    7f ff f7 20    call  0xe7ac                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10B30    92 10 20 09    mov  9, %o1
0x10B34    94 92 20 00    orcc  %o0, 0, %o2
0x10B38    02 80 00 38    be  0x10c18                            ! Conditional/control branch; inspect delay slot.
0x10B3C    a4 10 00 0a    mov  %o2, %l2
0x10B40    94 04 a0 10    add  %l2, 0x10, %o2
0x10B44    e4 26 20 10    st  %l2, [ %i0 + 0x10 ]
0x10B48    90 10 20 01    mov  1, %o0
0x10B4C    13 10 00 00    sethi  %hi(0x40000000), %o1            ! Build high part of constant/address.
0x10B50    80 a2 80 09    cmp  %o2, %o1
0x10B54    18 80 00 04    bgu  0x10b64                           ! Conditional/control branch; inspect delay slot.
0x10B58    d0 24 80 00    st  %o0, [ %l2 ]
0x10B5C    10 80 00 06    b  0x10b74                             ! Conditional/control branch; inspect delay slot.
0x10B60    90 12 a0 01    or  %o2, 1, %o0
0x10B64    11 30 00 00    sethi  %hi(0xc0000000), %o0            ! Build high part of constant/address.
0x10B68    90 12 20 10    or  %o0, 0x10, %o0                     ! 0xc0000010
0x10B6C    90 04 80 08    add  %l2, %o0, %o0
0x10B70    90 12 20 01    or  %o0, 1, %o0
0x10B74    d0 24 a0 04    st  %o0, [ %l2 + 4 ]
0x10B78    a2 10 20 01    mov  1, %l1
0x10B7C    2b 10 00 00    sethi  %hi(0x40000000), %l5            ! Build high part of constant/address.
0x10B80    90 04 60 01    add  %l1, 1, %o0
0x10B84    a8 10 00 08    mov  %o0, %l4
0x10B88    90 0a 20 7f    and  %o0, 0x7f, %o0
0x10B8C    91 2a 20 04    sll  %o0, 4, %o0
0x10B90    90 04 80 08    add  %l2, %o0, %o0
0x10B94    80 a2 00 15    cmp  %o0, %l5
0x10B98    08 80 00 03    bleu  0x10ba4                          ! Conditional/control branch; inspect delay slot.
0x10B9C    93 2c 60 04    sll  %l1, 4, %o1
0x10BA0    90 22 00 15    sub  %o0, %l5, %o0
0x10BA4    90 12 20 01    or  %o0, 1, %o0
0x10BA8    d0 24 80 09    st  %o0, [ %l2 + %o1 ]
0x10BAC    a0 04 80 09    add  %l2, %o1, %l0
0x10BB0    c0 24 20 04    clr  [ %l0 + 4 ]
0x10BB4    c0 24 20 08    clr  [ %l0 + 8 ]
0x10BB8    90 10 24 00    mov  0x400, %o0
0x10BBC    7f ff f6 fc    call  0xe7ac                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10BC0    92 10 20 0a    mov  0xa, %o1
0x10BC4    94 92 20 00    orcc  %o0, 0, %o2
0x10BC8    02 80 00 14    be  0x10c18                            ! Conditional/control branch; inspect delay slot.
0x10BCC    93 2c 60 02    sll  %l1, 2, %o1
0x10BD0    90 06 20 14    add  %i0, 0x14, %o0
0x10BD4    d4 22 00 09    st  %o2, [ %o0 + %o1 ]
0x10BD8    27 10 00 00    sethi  %hi(0x40000000), %l3            ! Build high part of constant/address.
0x10BDC    80 a2 80 13    cmp  %o2, %l3
0x10BE0    08 80 00 04    bleu  0x10bf0                          ! Conditional/control branch; inspect delay slot.
0x10BE4    d4 24 20 0c    st  %o2, [ %l0 + 0xc ]
0x10BE8    90 22 80 13    sub  %o2, %l3, %o0
0x10BEC    d0 24 20 0c    st  %o0, [ %l0 + 0xc ]
0x10BF0    a2 10 00 14    mov  %l4, %l1
0x10BF4    80 a4 60 1f    cmp  %l1, 0x1f
0x10BF8    08 bf ff e3    bleu  0x10b84                          ! Conditional/control branch; inspect delay slot.
0x10BFC    90 04 60 01    add  %l1, 1, %o0
0x10C00    11 00 00 04    sethi  %hi(0x1000), %o0                ! Build high part of constant/address.
0x10C04    7f ff f6 ea    call  0xe7ac                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10C08    92 10 20 0c    mov  0xc, %o1
0x10C0C    80 a2 20 00    cmp  %o0, 0
0x10C10    12 80 00 04    bne  0x10c20                           ! Conditional/control branch; inspect delay slot.
0x10C14    d0 26 20 08    st  %o0, [ %i0 + 8 ]
0x10C18    10 80 00 18    b  0x10c78                             ! Conditional/control branch; inspect delay slot.
0x10C1C    b0 10 20 01    mov  1, %i0
0x10C20    92 10 00 08    mov  %o0, %o1
0x10C24    80 a2 40 13    cmp  %o1, %l3
0x10C28    38 80 00 02    bgu,a   0x10c30                        ! Conditional/control branch; inspect delay slot.
0x10C2C    92 22 40 13    sub  %o1, %l3, %o1
0x10C30    98 10 00 13    mov  %l3, %o4
0x10C34    90 24 80 0c    sub  %l2, %o4, %o0
0x10C38    90 12 20 02    or  %o0, 2, %o0
0x10C3C    d2 26 20 0c    st  %o1, [ %i0 + 0xc ]
0x10C40    a2 10 20 00    clr  %l1
0x10C44    96 14 a0 02    or  %l2, 2, %o3
0x10C48    d4 06 20 08    ld  [ %i0 + 8 ], %o2
0x10C4C    80 a4 80 0c    cmp  %l2, %o4
0x10C50    08 80 00 04    bleu  0x10c60                          ! Conditional/control branch; inspect delay slot.
0x10C54    93 2c 60 02    sll  %l1, 2, %o1
0x10C58    10 80 00 03    b  0x10c64                             ! Conditional/control branch; inspect delay slot.
0x10C5C    d0 22 80 09    st  %o0, [ %o2 + %o1 ]
0x10C60    d6 22 80 09    st  %o3, [ %o2 + %o1 ]
0x10C64    a2 04 60 01    inc  %l1
0x10C68    80 a4 63 ff    cmp  %l1, 0x3ff
0x10C6C    24 bf ff f8    ble,a   0x10c4c                        ! Conditional/control branch; inspect delay slot.
0x10C70    d4 06 20 08    ld  [ %i0 + 8 ], %o2
0x10C74    b0 10 20 00    clr  %i0
0x10C78    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x10C7C    81 e8 00 00    restore                                ! Restore previous register window.
0x10C80    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x10C84    e0 06 00 00    ld  [ %i0 ], %l0
0x10C88    92 10 20 04    mov  4, %o1
0x10C8C    a0 0c 3f fe    and  %l0, -2, %l0
0x10C90    11 00 00 39    sethi  %hi(0xe400), %o0                ! Build high part of constant/address.
0x10C94    90 12 22 78    or  %o0, 0x278, %o0                    ! 0xe678
0x10C98    d2 34 00 00    sth  %o1, [ %l0 ]
0x10C9C    6a 1f 2d d9    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10CA0    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10CA4    11 00 00 27    sethi  %hi(0x9c00), %o0                ! Build high part of constant/address.
0x10CA8    c0 34 00 00    clrh  [ %l0 ]
0x10CAC    6a 1f 2d d5    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10CB0    90 12 20 40    or  %o0, 0x40, %o0
0x10CB4    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x10CB8    81 e8 00 00    restore                                ! Restore previous register window.
0x10CBC    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x10CC0    e2 06 00 00    ld  [ %i0 ], %l1
0x10CC4    90 10 20 02    mov  2, %o0
0x10CC8    94 0c 7f fe    and  %l1, -2, %o2
0x10CCC    d0 32 80 00    sth  %o0, [ %o2 ]
0x10CD0    d2 12 80 00    lduh  [ %o2 ], %o1
0x10CD4    80 8a 60 02    btst  2, %o1
0x10CD8    02 80 00 10    be  0x10d18                            ! Conditional/control branch; inspect delay slot.
0x10CDC    a0 10 20 0a    mov  0xa, %l0
0x10CE0    a4 10 00 0a    mov  %o2, %l2
0x10CE4    27 21 e0 db    sethi  %hi(0x87836c00), %l3            ! Build high part of constant/address.
0x10CE8    a0 84 3f ff    addcc  %l0, -1, %l0
0x10CEC    12 80 00 05    bne  0x10d00                           ! Conditional/control branch; inspect delay slot.
0x10CF0    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10CF4    7f ff f7 59    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10CF8    90 14 e3 60    or  %l3, 0x360, %o0
0x10CFC    30 80 00 18    b,a   0x10d5c                          ! Conditional/control branch; inspect delay slot.
0x10D00    6a 1f 2d c0    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10D04    90 10 20 01    mov  1, %o0
0x10D08    d0 14 80 00    lduh  [ %l2 ], %o0
0x10D0C    80 8a 20 02    btst  2, %o0
0x10D10    32 bf ff f7    bne,a   0x10cec                        ! Conditional/control branch; inspect delay slot.
0x10D14    a0 84 3f ff    addcc  %l0, -1, %l0
0x10D18    11 00 00 09    sethi  %hi(0x2400), %o0                ! Build high part of constant/address.
0x10D1C    6a 1f 2d b9    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10D20    90 12 23 10    or  %o0, 0x310, %o0                    ! 0x2710
0x10D24    92 04 60 04    add  %l1, 4, %o1
0x10D28    92 0a 7f fe    and  %o1, -2, %o1
0x10D2C    94 10 20 0f    mov  0xf, %o2
0x10D30    90 04 60 06    add  %l1, 6, %o0
0x10D34    d4 32 40 00    sth  %o2, [ %o1 ]
0x10D38    90 0a 3f fe    and  %o0, -2, %o0
0x10D3C    c0 32 00 00    clrh  [ %o0 ]
0x10D40    d4 06 20 0c    ld  [ %i0 + 0xc ], %o2
0x10D44    90 04 60 08    add  %l1, 8, %o0
0x10D48    90 0a 3f fc    and  %o0, -4, %o0
0x10D4C    d4 22 00 00    st  %o2, [ %o0 ]
0x10D50    92 0c 7f fe    and  %l1, -2, %o1
0x10D54    90 10 20 c1    mov  0xc1, %o0
0x10D58    d0 32 40 00    sth  %o0, [ %o1 ]
0x10D5C    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x10D60    81 e8 00 00    restore                                ! Restore previous register window.
0x10D64    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x10D68    f0 06 00 00    ld  [ %i0 ], %i0
0x10D6C    80 8e 60 01    btst  1, %i1
0x10D70    02 80 00 03    be  0x10d7c                            ! Conditional/control branch; inspect delay slot.
0x10D74    a0 06 20 10    add  %i0, 0x10, %l0
0x10D78    a0 06 20 12    add  %i0, 0x12, %l0
0x10D7C    a0 0c 3f fe    and  %l0, -2, %l0
0x10D80    d2 14 00 00    lduh  [ %l0 ], %o1
0x10D84    23 00 00 3f    sethi  %hi(0xfc00), %l1                ! Build high part of constant/address.
0x10D88    a4 14 63 f5    or  %l1, 0x3f5, %l2                    ! 0xfff5
0x10D8C    92 0a 40 12    and  %o1, %l2, %o1
0x10D90    92 12 62 00    or  %o1, 0x200, %o1
0x10D94    11 00 00 12    sethi  %hi(0x4800), %o0                ! Build high part of constant/address.
0x10D98    d2 34 00 00    sth  %o1, [ %l0 ]
0x10D9C    6a 1f 2d 99    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10DA0    90 12 22 38    or  %o0, 0x238, %o0
0x10DA4    d0 14 00 00    lduh  [ %l0 ], %o0
0x10DA8    a2 14 61 f5    or  %l1, 0x1f5, %l1
0x10DAC    90 0a 00 11    and  %o0, %l1, %o0
0x10DB0    d0 34 00 00    sth  %o0, [ %l0 ]
0x10DB4    6a 1f 2d 93    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10DB8    90 10 20 0a    mov  0xa, %o0
0x10DBC    d0 14 00 00    lduh  [ %l0 ], %o0
0x10DC0    23 00 00 09    sethi  %hi(0x2400), %l1                ! Build high part of constant/address.
0x10DC4    90 0a 00 12    and  %o0, %l2, %o0
0x10DC8    90 12 20 04    or  %o0, 4, %o0
0x10DCC    d0 34 00 00    sth  %o0, [ %l0 ]
0x10DD0    6a 1f 2d 8c    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10DD4    90 14 63 10    or  %l1, 0x310, %o0
0x10DD8    d2 14 00 00    lduh  [ %l0 ], %o1
0x10DDC    90 14 63 10    or  %l1, 0x310, %o0
0x10DE0    92 12 60 0a    or  %o1, 0xa, %o1
0x10DE4    d2 34 00 00    sth  %o1, [ %l0 ]
0x10DE8    6a 1f 2d 86    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10DEC    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10DF0    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x10DF4    81 e8 00 00    restore                                ! Restore previous register window.
0x10DF8    c4 02 00 00    ld  [ %o0 ], %g2
0x10DFC    84 00 a0 06    add  %g2, 6, %g2
0x10E00    84 08 bf fe    and  %g2, -2, %g2
0x10E04    d0 10 80 00    lduh  [ %g2 ], %o0
0x10E08    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x10E0C    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x10E10    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x10E14    e6 06 00 00    ld  [ %i0 ], %l3
0x10E18    13 10 00 00    sethi  %hi(0x40000000), %o1            ! Build high part of constant/address.
0x10E1C    e2 04 e0 10    ld  [ %l3 + 0x10 ], %l1
0x10E20    84 10 20 01    mov  1, %g2
0x10E24    90 04 60 20    add  %l1, 0x20, %o0
0x10E28    80 a2 00 09    cmp  %o0, %o1
0x10E2C    08 80 00 03    bleu  0x10e38                          ! Conditional/control branch; inspect delay slot.
0x10E30    da 06 20 18    ld  [ %i0 + 0x18 ], %o5
0x10E34    90 22 00 09    sub  %o0, %o1, %o0
0x10E38    90 12 20 04    or  %o0, 4, %o0
0x10E3C    d0 24 60 10    st  %o0, [ %l1 + 0x10 ]
0x10E40    d4 06 20 0c    ld  [ %i0 + 0xc ], %o2
0x10E44    91 28 a0 04    sll  %g2, 4, %o0
0x10E48    13 00 38 00    sethi  %hi(0xe00000), %o1              ! Build high part of constant/address.
0x10E4C    96 04 40 08    add  %l1, %o0, %o3
0x10E50    95 2a a0 08    sll  %o2, 8, %o2
0x10E54    92 12 60 2d    or  %o1, 0x2d, %o1
0x10E58    94 12 80 09    or  %o2, %o1, %o2
0x10E5C    11 06 20 00    sethi  %hi(0x18800000), %o0            ! Build high part of constant/address.
0x10E60    d4 22 e0 08    st  %o2, [ %o3 + 8 ]
0x10E64    d0 22 e0 04    st  %o0, [ %o3 + 4 ]
0x10E68    d0 06 20 1c    ld  [ %i0 + 0x1c ], %o0
0x10E6C    15 10 00 00    sethi  %hi(0x40000000), %o2            ! Build high part of constant/address.
0x10E70    80 a2 00 0a    cmp  %o0, %o2
0x10E74    38 80 00 02    bgu,a   0x10e7c                        ! Conditional/control branch; inspect delay slot.
0x10E78    90 22 00 0a    sub  %o0, %o2, %o0
0x10E7C    d0 22 e0 0c    st  %o0, [ %o3 + 0xc ]
0x10E80    d0 06 20 0c    ld  [ %i0 + 0xc ], %o0
0x10E84    84 10 20 02    mov  2, %g2
0x10E88    d2 06 20 04    ld  [ %i0 + 4 ], %o1
0x10E8C    91 2a 20 08    sll  %o0, 8, %o0
0x10E90    80 a2 60 00    cmp  %o1, 0
0x10E94    02 80 00 03    be  0x10ea0                            ! Conditional/control branch; inspect delay slot.
0x10E98    96 12 20 69    or  %o0, 0x69, %o3
0x10E9C    96 12 20 e1    or  %o0, 0xe1, %o3
0x10EA0    d8 06 20 14    ld  [ %i0 + 0x14 ], %o4
0x10EA4    80 a3 00 0a    cmp  %o4, %o2
0x10EA8    08 80 00 03    bleu  0x10eb4                          ! Conditional/control branch; inspect delay slot.
0x10EAC    1f 0e 20 00    sethi  %hi(0x38800000), %o7            ! Build high part of constant/address.
0x10EB0    98 23 00 0a    sub  %o4, %o2, %o4
0x10EB4    80 a3 60 00    cmp  %o5, 0
0x10EB8    04 80 00 21    ble  0x10f3c                           ! Conditional/control branch; inspect delay slot.
0x10EBC    a4 04 60 10    add  %l1, 0x10, %l2
0x10EC0    21 00 02 00    sethi  %hi(0x80000), %l0               ! Build high part of constant/address.
0x10EC4    92 04 60 30    add  %l1, 0x30, %o1
0x10EC8    86 10 20 20    mov  0x20, %g3
0x10ECC    d0 06 20 08    ld  [ %i0 + 8 ], %o0
0x10ED0    80 a3 40 08    cmp  %o5, %o0
0x10ED4    04 80 00 03    ble  0x10ee0                           ! Conditional/control branch; inspect delay slot.
0x10ED8    94 10 00 0d    mov  %o5, %o2
0x10EDC    94 10 00 08    mov  %o0, %o2
0x10EE0    11 10 00 00    sethi  %hi(0x40000000), %o0            ! Build high part of constant/address.
0x10EE4    80 a2 40 08    cmp  %o1, %o0
0x10EE8    18 80 00 05    bgu  0x10efc                           ! Conditional/control branch; inspect delay slot.
0x10EEC    90 22 40 08    sub  %o1, %o0, %o0
0x10EF0    90 12 60 04    or  %o1, 4, %o0
0x10EF4    10 80 00 04    b  0x10f04                             ! Conditional/control branch; inspect delay slot.
0x10EF8    d0 22 7f f0    st  %o0, [ %o1 + -16 ]
0x10EFC    90 12 20 04    or  %o0, 4, %o0
0x10F00    d0 24 40 03    st  %o0, [ %l1 + %g3 ]
0x10F04    90 02 bf ff    add  %o2, -1, %o0
0x10F08    91 2a 20 15    sll  %o0, 0x15, %o0
0x10F0C    96 1a c0 10    xor  %o3, %l0, %o3
0x10F10    90 12 00 0b    or  %o0, %o3, %o0
0x10F14    d8 22 7f fc    st  %o4, [ %o1 + -4 ]
0x10F18    d0 22 7f f8    st  %o0, [ %o1 + -8 ]
0x10F1C    9a 23 40 0a    sub  %o5, %o2, %o5
0x10F20    de 22 7f f4    st  %o7, [ %o1 + -12 ]
0x10F24    92 02 60 10    add  %o1, 0x10, %o1
0x10F28    86 00 e0 10    add  %g3, 0x10, %g3
0x10F2C    84 00 a0 01    inc  %g2
0x10F30    80 a3 60 00    cmp  %o5, 0
0x10F34    14 bf ff e6    bg  0x10ecc                            ! Conditional/control branch; inspect delay slot.
0x10F38    98 03 00 0a    add  %o4, %o2, %o4
0x10F3C    91 28 a0 04    sll  %g2, 4, %o0
0x10F40    a8 10 00 08    mov  %o0, %l4
0x10F44    90 02 20 10    add  %o0, 0x10, %o0
0x10F48    90 04 40 08    add  %l1, %o0, %o0
0x10F4C    13 10 00 00    sethi  %hi(0x40000000), %o1            ! Build high part of constant/address.
0x10F50    80 a2 00 09    cmp  %o0, %o1
0x10F54    38 80 00 02    bgu,a   0x10f5c                        ! Conditional/control branch; inspect delay slot.
0x10F58    90 22 00 09    sub  %o0, %o1, %o0
0x10F5C    90 12 20 05    or  %o0, 5, %o0
0x10F60    d0 24 40 14    st  %o0, [ %l1 + %l4 ]
0x10F64    d0 06 20 04    ld  [ %i0 + 4 ], %o0
0x10F68    80 a2 20 00    cmp  %o0, 0
0x10F6C    02 80 00 04    be  0x10f7c                            ! Conditional/control branch; inspect delay slot.
0x10F70    96 0a ff 00    and  %o3, -256, %o3
0x10F74    10 80 00 03    b  0x10f80                             ! Conditional/control branch; inspect delay slot.
0x10F78    96 12 e0 69    or  %o3, 0x69, %o3
0x10F7C    96 12 e0 e1    or  %o3, 0xe1, %o3
0x10F80    11 00 02 00    sethi  %hi(0x80000), %o0               ! Build high part of constant/address.
0x10F84    96 12 c0 08    or  %o3, %o0, %o3
0x10F88    11 00 40 00    sethi  %hi(0x1000000), %o0             ! Build high part of constant/address.
0x10F8C    90 13 c0 08    or  %o7, %o0, %o0
0x10F90    92 04 40 14    add  %l1, %l4, %o1
0x10F94    15 3f f8 00    sethi  %hi(0xffe00000), %o2            ! Build high part of constant/address.
0x10F98    94 12 c0 0a    or  %o3, %o2, %o2
0x10F9C    d0 22 60 04    st  %o0, [ %o1 + 4 ]
0x10FA0    90 10 23 e8    mov  0x3e8, %o0
0x10FA4    d4 22 60 08    st  %o2, [ %o1 + 8 ]
0x10FA8    6a 1f 2d 16    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10FAC    aa 10 00 02    mov  %g2, %l5
0x10FB0    11 10 00 00    sethi  %hi(0x40000000), %o0            ! Build high part of constant/address.
0x10FB4    80 a4 80 08    cmp  %l2, %o0
0x10FB8    08 80 00 06    bleu  0x10fd0                          ! Conditional/control branch; inspect delay slot.
0x10FBC    90 0c bf fe    and  %l2, -2, %o0
0x10FC0    11 30 00 00    sethi  %hi(0xc0000000), %o0            ! Build high part of constant/address.
0x10FC4    90 12 20 10    or  %o0, 0x10, %o0                     ! 0xc0000010
0x10FC8    90 04 40 08    add  %l1, %o0, %o0
0x10FCC    90 0a 3f fe    and  %o0, -2, %o0
0x10FD0    d0 24 60 04    st  %o0, [ %l1 + 4 ]
0x10FD4    11 08 00 00    sethi  %hi(0x20000000), %o0            ! Build high part of constant/address.
0x10FD8    94 12 20 14    or  %o0, 0x14, %o2                     ! 0x20000014
0x10FDC    d2 02 80 00    ld  [ %o2 ], %o1
0x10FE0    d0 04 e0 04    ld  [ %l3 + 4 ], %o0
0x10FE4    80 8a 40 08    btst  %o1, %o0
0x10FE8    32 80 00 0f    bne,a   0x11024                        ! Conditional/control branch; inspect delay slot.
0x10FEC    d2 04 c0 00    ld  [ %l3 ], %o1
0x10FF0    a4 10 00 0a    mov  %o2, %l2
0x10FF4    a0 10 20 63    mov  0x63, %l0
0x10FF8    6a 1f 2d 02    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x10FFC    90 10 23 e8    mov  0x3e8, %o0

0x11000    d2 04 80 00    ld  [ %l2 ], %o1
0x11004    d0 04 e0 04    ld  [ %l3 + 4 ], %o0
0x11008    80 8a 40 08    btst  %o1, %o0
0x1100C    32 80 00 06    bne,a   0x11024                        ! Conditional/control branch; inspect delay slot.
0x11010    d2 04 c0 00    ld  [ %l3 ], %o1
0x11014    a0 84 3f ff    addcc  %l0, -1, %l0
0x11018    12 bf ff f8    bne  0x10ff8                           ! Conditional/control branch; inspect delay slot.
0x1101C    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x11020    d2 04 c0 00    ld  [ %l3 ], %o1
0x11024    15 08 00 00    sethi  %hi(0x20000000), %o2            ! Build high part of constant/address.
0x11028    92 02 60 02    add  %o1, 2, %o1
0x1102C    92 0a 7f fe    and  %o1, -2, %o1
0x11030    d0 12 40 00    lduh  [ %o1 ], %o0
0x11034    94 12 a0 1c    or  %o2, 0x1c, %o2
0x11038    96 10 00 08    mov  %o0, %o3
0x1103C    d6 32 40 00    sth  %o3, [ %o1 ]
0x11040    d0 04 c0 00    ld  [ %l3 ], %o0
0x11044    90 02 20 02    add  %o0, 2, %o0
0x11048    90 0a 3f fe    and  %o0, -2, %o0
0x1104C    d6 12 00 00    lduh  [ %o0 ], %o3
0x11050    d2 04 e0 04    ld  [ %l3 + 4 ], %o1
0x11054    d2 22 80 00    st  %o1, [ %o2 ]
0x11058    d0 04 60 04    ld  [ %l1 + 4 ], %o0
0x1105C    80 8a 20 01    btst  1, %o0
0x11060    12 80 00 19    bne  0x110c4                           ! Conditional/control branch; inspect delay slot.
0x11064    80 a5 60 02    cmp  %l5, 2
0x11068    98 0a 3f f0    and  %o0, -16, %o4
0x1106C    17 10 00 00    sethi  %hi(0x40000000), %o3            ! Build high part of constant/address.
0x11070    90 03 00 0b    add  %o4, %o3, %o0
0x11074    d4 02 20 04    ld  [ %o0 + 4 ], %o2
0x11078    13 00 10 00    sethi  %hi(0x400000), %o1              ! Build high part of constant/address.
0x1107C    80 8a 80 09    btst  %o2, %o1
0x11080    02 80 00 04    be  0x11090                            ! Conditional/control branch; inspect delay slot.
0x11084    11 00 20 00    sethi  %hi(0x800000), %o0              ! Build high part of constant/address.
0x11088    10 80 00 1d    b  0x110fc                             ! Conditional/control branch; inspect delay slot.
0x1108C    b0 10 20 01    mov  1, %i0
0x11090    80 8a 80 08    btst  %o2, %o0
0x11094    12 bf ff d1    bne  0x10fd8                           ! Conditional/control branch; inspect delay slot.
0x11098    11 08 00 00    sethi  %hi(0x20000000), %o0            ! Build high part of constant/address.
0x1109C    d0 03 00 0b    ld  [ %o4 + %o3 ], %o0
0x110A0    80 8a 20 01    btst  1, %o0
0x110A4    12 bf ff cd    bne  0x10fd8                           ! Conditional/control branch; inspect delay slot.
0x110A8    11 08 00 00    sethi  %hi(0x20000000), %o0            ! Build high part of constant/address.
0x110AC    90 04 40 14    add  %l1, %l4, %o0
0x110B0    80 a2 00 0b    cmp  %o0, %o3
0x110B4    08 bf ff c8    bleu  0x10fd4                          ! Conditional/control branch; inspect delay slot.
0x110B8    d0 24 60 04    st  %o0, [ %l1 + 4 ]
0x110BC    10 bf ff c5    b  0x10fd0                             ! Conditional/control branch; inspect delay slot.
0x110C0    90 22 00 0b    sub  %o0, %o3, %o0
0x110C4    04 80 00 0d    ble  0x110f8                           ! Conditional/control branch; inspect delay slot.
0x110C8    c0 26 20 20    clr  [ %i0 + 0x20 ]
0x110CC    94 04 60 24    add  %l1, 0x24, %o2
0x110D0    84 05 7f fe    add  %l5, -2, %g2
0x110D4    d2 02 80 00    ld  [ %o2 ], %o1
0x110D8    84 80 bf ff    addcc  %g2, -1, %g2
0x110DC    d0 06 20 20    ld  [ %i0 + 0x20 ], %o0
0x110E0    92 02 60 01    inc  %o1
0x110E4    92 0a 67 ff    and  %o1, 0x7ff, %o1
0x110E8    90 02 00 09    add  %o0, %o1, %o0
0x110EC    d0 26 20 20    st  %o0, [ %i0 + 0x20 ]
0x110F0    12 bf ff f9    bne  0x110d4                           ! Conditional/control branch; inspect delay slot.
0x110F4    94 02 a0 10    add  %o2, 0x10, %o2
0x110F8    b0 10 20 00    clr  %i0
0x110FC    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x11100    81 e8 00 00    restore                                ! Restore previous register window.
0x11104    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x11108    e4 06 00 00    ld  [ %i0 ], %l2
0x1110C    11 10 00 00    sethi  %hi(0x40000000), %o0            ! Build high part of constant/address.
0x11110    c2 06 20 14    ld  [ %i0 + 0x14 ], %g1
0x11114    88 10 20 01    mov  1, %g4
0x11118    e2 04 a0 10    ld  [ %l2 + 0x10 ], %l1
0x1111C    80 a0 40 08    cmp  %g1, %o0
0x11120    08 80 00 03    bleu  0x1112c                          ! Conditional/control branch; inspect delay slot.
0x11124    e0 06 20 18    ld  [ %i0 + 0x18 ], %l0
0x11128    82 20 40 08    sub  %g1, %o0, %g1
0x1112C    80 a4 20 00    cmp  %l0, 0
0x11130    04 80 00 37    ble  0x1120c                           ! Conditional/control branch; inspect delay slot.
0x11134    8e 04 60 10    add  %l1, 0x10, %g7
0x11138    84 10 00 07    mov  %g7, %g2
0x1113C    a6 10 20 10    mov  0x10, %l3
0x11140    9e 04 60 20    add  %l1, 0x20, %o7
0x11144    d0 06 20 10    ld  [ %i0 + 0x10 ], %o0
0x11148    d0 02 20 08    ld  [ %o0 + 8 ], %o0
0x1114C    80 a4 00 08    cmp  %l0, %o0
0x11150    04 80 00 03    ble  0x1115c                           ! Conditional/control branch; inspect delay slot.
0x11154    86 10 00 10    mov  %l0, %g3
0x11158    86 10 00 08    mov  %o0, %g3
0x1115C    11 10 00 00    sethi  %hi(0x40000000), %o0            ! Build high part of constant/address.
0x11160    80 a3 c0 08    cmp  %o7, %o0
0x11164    18 80 00 05    bgu  0x11178                           ! Conditional/control branch; inspect delay slot.
0x11168    90 23 c0 08    sub  %o7, %o0, %o0
0x1116C    90 13 e0 04    or  %o7, 4, %o0
0x11170    10 80 00 04    b  0x11180                             ! Conditional/control branch; inspect delay slot.
0x11174    d0 20 80 00    st  %o0, [ %g2 ]
0x11178    90 12 20 04    or  %o0, 4, %o0
0x1117C    d0 24 40 13    st  %o0, [ %l1 + %l3 ]
0x11180    d8 06 20 10    ld  [ %i0 + 0x10 ], %o4
0x11184    94 00 ff ff    add  %g3, -1, %o2
0x11188    d6 03 20 04    ld  [ %o4 + 4 ], %o3
0x1118C    95 2a a0 15    sll  %o2, 0x15, %o2
0x11190    d0 03 00 00    ld  [ %o4 ], %o0
0x11194    9a 0a e0 01    and  %o3, 1, %o5
0x11198    d2 06 20 0c    ld  [ %i0 + 0xc ], %o1
0x1119C    96 02 e0 01    inc  %o3
0x111A0    91 2a 20 0f    sll  %o0, 0xf, %o0
0x111A4    94 12 80 08    or  %o2, %o0, %o2
0x111A8    93 2a 60 08    sll  %o1, 8, %o1
0x111AC    d6 23 20 04    st  %o3, [ %o4 + 4 ]
0x111B0    94 12 80 09    or  %o2, %o1, %o2
0x111B4    80 a3 60 00    cmp  %o5, 0
0x111B8    02 80 00 04    be  0x111c8                            ! Conditional/control branch; inspect delay slot.
0x111BC    96 10 00 02    mov  %g2, %o3
0x111C0    11 00 02 00    sethi  %hi(0x80000), %o0               ! Build high part of constant/address.
0x111C4    94 12 80 08    or  %o2, %o0, %o2
0x111C8    d0 06 20 04    ld  [ %i0 + 4 ], %o0
0x111CC    80 a2 20 00    cmp  %o0, 0
0x111D0    02 80 00 03    be  0x111dc                            ! Conditional/control branch; inspect delay slot.
0x111D4    92 12 a0 69    or  %o2, 0x69, %o1
0x111D8    92 12 a0 e1    or  %o2, 0xe1, %o1
0x111DC    d2 22 e0 08    st  %o1, [ %o3 + 8 ]
0x111E0    11 06 20 00    sethi  %hi(0x18800000), %o0            ! Build high part of constant/address.
0x111E4    c2 20 a0 0c    st  %g1, [ %g2 + 0xc ]
0x111E8    d0 20 a0 04    st  %o0, [ %g2 + 4 ]
0x111EC    a0 24 00 03    sub  %l0, %g3, %l0
0x111F0    82 00 40 03    add  %g1, %g3, %g1
0x111F4    84 00 a0 10    add  %g2, 0x10, %g2
0x111F8    a6 04 e0 10    add  %l3, 0x10, %l3
0x111FC    9e 03 e0 10    add  %o7, 0x10, %o7
0x11200    80 a4 20 00    cmp  %l0, 0
0x11204    14 bf ff d0    bg  0x11144                            ! Conditional/control branch; inspect delay slot.
0x11208    88 01 20 01    inc  %g4
0x1120C    a8 01 3f ff    add  %g4, -1, %l4
0x11210    93 2d 20 04    sll  %l4, 4, %o1
0x11214    90 02 60 10    add  %o1, 0x10, %o0
0x11218    90 04 40 08    add  %l1, %o0, %o0
0x1121C    15 10 00 00    sethi  %hi(0x40000000), %o2            ! Build high part of constant/address.
0x11220    80 a2 00 0a    cmp  %o0, %o2
0x11224    38 80 00 02    bgu,a   0x1122c                        ! Conditional/control branch; inspect delay slot.
0x11228    90 22 00 0a    sub  %o0, %o2, %o0
0x1122C    90 12 20 05    or  %o0, 5, %o0
0x11230    d0 24 40 09    st  %o0, [ %l1 + %o1 ]
0x11234    91 2d 20 04    sll  %l4, 4, %o0
0x11238    aa 10 00 08    mov  %o0, %l5
0x1123C    90 04 40 08    add  %l1, %o0, %o0
0x11240    13 06 60 00    sethi  %hi(0x19800000), %o1            ! Build high part of constant/address.
0x11244    15 10 00 00    sethi  %hi(0x40000000), %o2            ! Build high part of constant/address.
0x11248    80 a1 c0 0a    cmp  %g7, %o2
0x1124C    18 80 00 04    bgu  0x1125c                           ! Conditional/control branch; inspect delay slot.
0x11250    d2 22 20 04    st  %o1, [ %o0 + 4 ]
0x11254    10 80 00 06    b  0x1126c                             ! Conditional/control branch; inspect delay slot.
0x11258    90 09 ff fe    and  %g7, -2, %o0
0x1125C    11 30 00 00    sethi  %hi(0xc0000000), %o0            ! Build high part of constant/address.
0x11260    90 12 20 10    or  %o0, 0x10, %o0                     ! 0xc0000010
0x11264    90 04 40 08    add  %l1, %o0, %o0
0x11268    90 0a 3f fe    and  %o0, -2, %o0
0x1126C    d0 24 60 04    st  %o0, [ %l1 + 4 ]
0x11270    11 08 00 00    sethi  %hi(0x20000000), %o0            ! Build high part of constant/address.
0x11274    94 12 20 14    or  %o0, 0x14, %o2                     ! 0x20000014
0x11278    d2 02 80 00    ld  [ %o2 ], %o1
0x1127C    d0 04 a0 04    ld  [ %l2 + 4 ], %o0
0x11280    80 8a 40 08    btst  %o1, %o0
0x11284    32 80 00 0f    bne,a   0x112c0                        ! Conditional/control branch; inspect delay slot.
0x11288    d2 04 80 00    ld  [ %l2 ], %o1
0x1128C    a6 10 00 0a    mov  %o2, %l3
0x11290    a0 10 20 63    mov  0x63, %l0
0x11294    6a 1f 2c 5b    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11298    90 10 23 e8    mov  0x3e8, %o0
0x1129C    d2 04 c0 00    ld  [ %l3 ], %o1
0x112A0    d0 04 a0 04    ld  [ %l2 + 4 ], %o0
0x112A4    80 8a 40 08    btst  %o1, %o0
0x112A8    32 80 00 06    bne,a   0x112c0                        ! Conditional/control branch; inspect delay slot.
0x112AC    d2 04 80 00    ld  [ %l2 ], %o1
0x112B0    a0 84 3f ff    addcc  %l0, -1, %l0
0x112B4    12 bf ff f8    bne  0x11294                           ! Conditional/control branch; inspect delay slot.
0x112B8    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x112BC    d2 04 80 00    ld  [ %l2 ], %o1
0x112C0    17 08 00 00    sethi  %hi(0x20000000), %o3            ! Build high part of constant/address.
0x112C4    92 02 60 02    add  %o1, 2, %o1
0x112C8    92 0a 7f fe    and  %o1, -2, %o1
0x112CC    d4 12 40 00    lduh  [ %o1 ], %o2
0x112D0    96 12 e0 1c    or  %o3, 0x1c, %o3
0x112D4    d4 32 40 00    sth  %o2, [ %o1 ]
0x112D8    d0 04 80 00    ld  [ %l2 ], %o0
0x112DC    90 02 20 02    add  %o0, 2, %o0
0x112E0    90 0a 3f fe    and  %o0, -2, %o0
0x112E4    d4 12 00 00    lduh  [ %o0 ], %o2
0x112E8    d2 04 a0 04    ld  [ %l2 + 4 ], %o1
0x112EC    d2 22 c0 00    st  %o1, [ %o3 ]
0x112F0    d4 04 60 04    ld  [ %l1 + 4 ], %o2
0x112F4    80 8a a0 01    btst  1, %o2
0x112F8    12 80 00 1b    bne  0x11364                           ! Conditional/control branch; inspect delay slot.
0x112FC    80 a5 20 01    cmp  %l4, 1
0x11300    9a 0a bf f0    and  %o2, -16, %o5
0x11304    19 10 00 00    sethi  %hi(0x40000000), %o4            ! Build high part of constant/address.
0x11308    90 03 40 0c    add  %o5, %o4, %o0
0x1130C    d6 02 20 04    ld  [ %o0 + 4 ], %o3
0x11310    13 00 10 00    sethi  %hi(0x400000), %o1              ! Build high part of constant/address.
0x11314    80 8a c0 09    btst  %o3, %o1
0x11318    02 80 00 05    be  0x1132c                            ! Conditional/control branch; inspect delay slot.
0x1131C    90 12 a0 01    or  %o2, 1, %o0
0x11320    d0 24 60 04    st  %o0, [ %l1 + 4 ]
0x11324    10 80 00 20    b  0x113a4                             ! Conditional/control branch; inspect delay slot.
0x11328    b0 10 20 01    mov  1, %i0
0x1132C    11 00 20 00    sethi  %hi(0x800000), %o0              ! Build high part of constant/address.
0x11330    80 8a c0 08    btst  %o3, %o0
0x11334    12 bf ff d0    bne  0x11274                           ! Conditional/control branch; inspect delay slot.
0x11338    11 08 00 00    sethi  %hi(0x20000000), %o0            ! Build high part of constant/address.
0x1133C    d0 03 40 0c    ld  [ %o5 + %o4 ], %o0
0x11340    80 8a 20 01    btst  1, %o0
0x11344    12 bf ff cc    bne  0x11274                           ! Conditional/control branch; inspect delay slot.
0x11348    11 08 00 00    sethi  %hi(0x20000000), %o0            ! Build high part of constant/address.
0x1134C    90 04 40 15    add  %l1, %l5, %o0
0x11350    80 a2 00 0c    cmp  %o0, %o4
0x11354    08 bf ff c7    bleu  0x11270                          ! Conditional/control branch; inspect delay slot.
0x11358    d0 24 60 04    st  %o0, [ %l1 + 4 ]
0x1135C    10 bf ff c4    b  0x1126c                             ! Conditional/control branch; inspect delay slot.
0x11360    90 22 00 0c    sub  %o0, %o4, %o0
0x11364    04 80 00 0f    ble  0x113a0                           ! Conditional/control branch; inspect delay slot.
0x11368    c0 26 20 20    clr  [ %i0 + 0x20 ]
0x1136C    94 04 60 14    add  %l1, 0x14, %o2
0x11370    88 05 3f ff    add  %l4, -1, %g4
0x11374    d0 02 80 00    ld  [ %o2 ], %o0
0x11378    88 81 3f ff    addcc  %g4, -1, %g4
0x1137C    90 02 20 01    inc  %o0
0x11380    90 0a 27 ff    and  %o0, 0x7ff, %o0
0x11384    d2 06 20 20    ld  [ %i0 + 0x20 ], %o1
0x11388    90 02 20 01    inc  %o0
0x1138C    90 0a 27 ff    and  %o0, 0x7ff, %o0
0x11390    92 02 40 08    add  %o1, %o0, %o1
0x11394    d2 26 20 20    st  %o1, [ %i0 + 0x20 ]
0x11398    12 bf ff f7    bne  0x11374                           ! Conditional/control branch; inspect delay slot.
0x1139C    94 02 a0 10    add  %o2, 0x10, %o2
0x113A0    b0 10 20 00    clr  %i0
0x113A4    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x113A8    81 e8 00 00    restore                                ! Restore previous register window.
0x113AC    96 10 20 00    clr  %o3
0x113B0    80 a2 a0 00    cmp  %o2, 0
0x113B4    04 80 00 35    ble  0x11488                           ! Conditional/control branch; inspect delay slot.
0x113B8    98 10 20 00    clr  %o4
0x113BC    c4 0a 60 01    ldub  [ %o1 + 1 ], %g2
0x113C0    80 a0 a0 04    cmp  %g2, 4
0x113C4    12 80 00 11    bne  0x11408                           ! Conditional/control branch; inspect delay slot.
0x113C8    80 a0 a0 05    cmp  %g2, 5
0x113CC    c4 0a 60 05    ldub  [ %o1 + 5 ], %g2
0x113D0    80 a0 a0 08    cmp  %g2, 8
0x113D4    12 80 00 0a    bne  0x113fc                           ! Conditional/control branch; inspect delay slot.
0x113D8    98 10 20 00    clr  %o4
0x113DC    c4 0a 60 06    ldub  [ %o1 + 6 ], %g2
0x113E0    80 a0 a0 06    cmp  %g2, 6
0x113E4    32 80 00 07    bne,a   0x11400                        ! Conditional/control branch; inspect delay slot.
0x113E8    c4 0a 60 02    ldub  [ %o1 + 2 ], %g2
0x113EC    c4 0a 60 07    ldub  [ %o1 + 7 ], %g2
0x113F0    84 18 a0 50    xor  %g2, 0x50, %g2
0x113F4    80 a0 00 02    cmp  %g0, %g2
0x113F8    98 60 3f ff    subx  %g0, -1, %o4
0x113FC    c4 0a 60 02    ldub  [ %o1 + 2 ], %g2
0x11400    10 80 00 1d    b  0x11474                             ! Conditional/control branch; inspect delay slot.
0x11404    c4 22 20 08    st  %g2, [ %o0 + 8 ]
0x11408    32 80 00 1c    bne,a   0x11478                        ! Conditional/control branch; inspect delay slot.
0x1140C    c4 0a 40 00    ldub  [ %o1 ], %g2
0x11410    c4 0a 60 03    ldub  [ %o1 + 3 ], %g2
0x11414    80 a0 a0 02    cmp  %g2, 2
0x11418    32 80 00 18    bne,a   0x11478                        ! Conditional/control branch; inspect delay slot.
0x1141C    c4 0a 40 00    ldub  [ %o1 ], %g2
0x11420    c4 0a 60 02    ldub  [ %o1 + 2 ], %g2
0x11424    80 88 a0 80    btst  0x80, %g2
0x11428    02 80 00 0b    be  0x11454                            ! Conditional/control branch; inspect delay slot.
0x1142C    96 02 e0 01    inc  %o3
0x11430    84 08 a0 7f    and  %g2, 0x7f, %g2
0x11434    c4 22 20 0c    st  %g2, [ %o0 + 0xc ]
0x11438    c0 22 20 10    clr  [ %o0 + 0x10 ]
0x1143C    c4 0a 60 05    ldub  [ %o1 + 5 ], %g2
0x11440    c6 0a 60 04    ldub  [ %o1 + 4 ], %g3
0x11444    85 28 a0 08    sll  %g2, 8, %g2
0x11448    84 10 80 03    or  %g2, %g3, %g2
0x1144C    10 80 00 0a    b  0x11474                             ! Conditional/control branch; inspect delay slot.
0x11450    c4 22 20 14    st  %g2, [ %o0 + 0x14 ]
0x11454    84 08 a0 ff    and  %g2, 0xff, %g2
0x11458    c4 22 20 18    st  %g2, [ %o0 + 0x18 ]
0x1145C    c0 22 20 1c    clr  [ %o0 + 0x1c ]
0x11460    c4 0a 60 05    ldub  [ %o1 + 5 ], %g2
0x11464    c6 0a 60 04    ldub  [ %o1 + 4 ], %g3
0x11468    85 28 a0 08    sll  %g2, 8, %g2
0x1146C    84 10 80 03    or  %g2, %g3, %g2
0x11470    c4 22 20 20    st  %g2, [ %o0 + 0x20 ]
0x11474    c4 0a 40 00    ldub  [ %o1 ], %g2
0x11478    94 22 80 02    sub  %o2, %g2, %o2
0x1147C    80 a2 a0 00    cmp  %o2, 0
0x11480    14 bf ff cf    bg  0x113bc                            ! Conditional/control branch; inspect delay slot.
0x11484    92 02 40 02    add  %o1, %g2, %o1
0x11488    80 a3 20 00    cmp  %o4, 0
0x1148C    02 80 00 03    be  0x11498                            ! Conditional/control branch; inspect delay slot.
0x11490    90 10 20 00    clr  %o0
0x11494    90 10 00 0b    mov  %o3, %o0
0x11498    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x1149C    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x114A0    9d e3 bf 70    save  %sp, -144, %sp                   ! Enter register window; allocate stack frame.
0x114A4    13 21 83 ff    sethi  %hi(0x860ffc00), %o1            ! Build high part of constant/address.
0x114A8    94 12 61 80    or  %o1, 0x180, %o2                    ! 0x860ffd80
0x114AC    90 10 20 08    mov  8, %o0
0x114B0    92 12 63 80    or  %o1, 0x380, %o1
0x114B4    d0 27 bf d8    st  %o0, [ %fp + -40 ]
0x114B8    f0 27 bf d0    st  %i0, [ %fp + -48 ]
0x114BC    f2 27 bf dc    st  %i1, [ %fp + -36 ]
0x114C0    d4 27 bf e4    st  %o2, [ %fp + -28 ]
0x114C4    d2 27 bf ec    st  %o1, [ %fp + -20 ]
0x114C8    90 10 21 02    mov  0x102, %o0
0x114CC    d0 32 60 02    sth  %o0, [ %o1 + 2 ]
0x114D0    f4 32 60 06    sth  %i2, [ %o1 + 6 ]
0x114D4    c0 32 60 04    clrh  [ %o1 + 4 ]
0x114D8    c0 32 40 00    clrh  [ %o1 ]
0x114DC    c0 27 bf d4    clr  [ %fp + -44 ]
0x114E0    c0 27 bf e8    clr  [ %fp + -24 ]
0x114E4    7f ff fe 4b    call  0x10e10                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x114E8    90 07 bf d0    add  %fp, -48, %o0
0x114EC    11 00 00 30    sethi  %hi(0xc000), %o0                ! Build high part of constant/address.
0x114F0    6a 1f 2b c4    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x114F4    90 12 23 50    or  %o0, 0x350, %o0                    ! 0xc350
0x114F8    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x114FC    81 e8 00 00    restore                                ! Restore previous register window.
0x11500    9d e3 bf 70    save  %sp, -144, %sp                   ! Enter register window; allocate stack frame.
0x11504    11 21 83 ff    sethi  %hi(0x860ffc00), %o0            ! Build high part of constant/address.
0x11508    a8 12 22 80    or  %o0, 0x280, %l4                    ! 0x860ffe80
0x1150C    a0 12 22 00    or  %o0, 0x200, %l0
0x11510    a6 07 bf d0    add  %fp, -48, %l3
0x11514    d6 06 00 00    ld  [ %i0 ], %o3
0x11518    92 0e e0 ff    and  %i3, 0xff, %o1
0x1151C    d4 06 20 04    ld  [ %i0 + 4 ], %o2
0x11520    a4 10 00 09    mov  %o1, %l2
0x11524    d6 27 bf d0    st  %o3, [ %fp + -48 ]
0x11528    11 10 d0 94    sethi  %hi(0x43425000), %o0            ! Build high part of constant/address.
0x1152C    d4 27 bf dc    st  %o2, [ %fp + -36 ]
0x11530    f2 27 bf e4    st  %i1, [ %fp + -28 ]
0x11534    c0 27 bf ec    clr  [ %fp + -20 ]
0x11538    90 12 23 55    or  %o0, 0x355, %o0
0x1153C    93 2a 60 09    sll  %o1, 9, %o1
0x11540    96 10 20 80    mov  0x80, %o3
0x11544    94 10 20 01    mov  1, %o2
0x11548    98 10 20 0a    mov  0xa, %o4
0x1154C    9a 10 20 28    mov  0x28, %o5
0x11550    85 36 a0 18    srl  %i2, 0x18, %g2
0x11554    87 36 a0 10    srl  %i2, 0x10, %g3
0x11558    9f 36 a0 08    srl  %i2, 8, %o7
0x1155C    d0 24 00 00    st  %o0, [ %l0 ]
0x11560    d2 24 20 08    st  %o1, [ %l0 + 8 ]
0x11564    d6 2c 20 0c    stb  %o3, [ %l0 + 0xc ]
0x11568    d4 24 20 04    st  %o2, [ %l0 + 4 ]
0x1156C    d8 2c 20 0e    stb  %o4, [ %l0 + 0xe ]
0x11570    da 2c 20 0f    stb  %o5, [ %l0 + 0xf ]
0x11574    c4 2c 20 11    stb  %g2, [ %l0 + 0x11 ]
0x11578    c6 2c 20 12    stb  %g3, [ %l0 + 0x12 ]
0x1157C    de 2c 20 13    stb  %o7, [ %l0 + 0x13 ]
0x11580    c0 2c 20 0d    clrb  [ %l0 + 0xd ]
0x11584    c0 2c 20 10    clrb  [ %l0 + 0x10 ]
0x11588    f4 2c 20 14    stb  %i2, [ %l0 + 0x14 ]
0x1158C    c0 2c 20 15    clrb  [ %l0 + 0x15 ]
0x11590    c0 2c 20 16    clrb  [ %l0 + 0x16 ]
0x11594    f6 2c 20 17    stb  %i3, [ %l0 + 0x17 ]
0x11598    c0 2c 20 18    clrb  [ %l0 + 0x18 ]
0x1159C    96 10 20 0a    mov  0xa, %o3
0x115A0    90 04 20 0c    add  %l0, 0xc, %o0
0x115A4    a2 06 20 18    add  %i0, 0x18, %l1
0x115A8    92 14 20 0f    or  %l0, 0xf, %o1
0x115AC    c0 2a 40 0b    clrb  [ %o1 + %o3 ]
0x115B0    96 02 e0 01    inc  %o3
0x115B4    80 a2 e0 0f    cmp  %o3, 0xf
0x115B8    24 bf ff fe    ble,a   0x115b0                        ! Conditional/control branch; inspect delay slot.
0x115BC    c0 2a 40 0b    clrb  [ %o1 + %o3 ]
0x115C0    7f ff f4 9a    call  0xe828                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x115C4    92 10 20 14    mov  0x14, %o1
0x115C8    90 10 20 1f    mov  0x1f, %o0
0x115CC    92 10 20 01    mov  1, %o1
0x115D0    d0 27 bf e8    st  %o0, [ %fp + -24 ]
0x115D4    d2 27 bf d4    st  %o1, [ %fp + -44 ]
0x115D8    e2 27 bf e0    st  %l1, [ %fp + -32 ]
0x115DC    e0 27 bf e4    st  %l0, [ %fp + -28 ]
0x115E0    7f ff fe c9    call  0x11104                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x115E4    90 10 00 13    mov  %l3, %o0
0x115E8    80 a2 20 00    cmp  %o0, 0
0x115EC    32 80 00 3e    bne,a   0x116e4                        ! Conditional/control branch; inspect delay slot.
0x115F0    b0 10 20 01    mov  1, %i0
0x115F4    a3 2c a0 09    sll  %l2, 9, %l1
0x115F8    a4 06 20 0c    add  %i0, 0xc, %l2
0x115FC    c0 27 bf d4    clr  [ %fp + -44 ]
0x11600    e2 27 bf e8    st  %l1, [ %fp + -24 ]
0x11604    f2 27 bf e4    st  %i1, [ %fp + -28 ]
0x11608    e4 27 bf e0    st  %l2, [ %fp + -32 ]
0x1160C    7f ff fe be    call  0x11104                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11610    90 10 00 13    mov  %l3, %o0
0x11614    80 a2 20 00    cmp  %o0, 0
0x11618    02 80 00 08    be  0x11638                            ! Conditional/control branch; inspect delay slot.
0x1161C    90 10 20 0d    mov  0xd, %o0
0x11620    d4 06 20 0c    ld  [ %i0 + 0xc ], %o2
0x11624    d0 07 bf d0    ld  [ %fp + -48 ], %o0
0x11628    b0 10 20 01    mov  1, %i0
0x1162C    7f ff ff 9d    call  0x114a0                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11630    d2 07 bf dc    ld  [ %fp + -36 ], %o1
0x11634    30 80 00 2c    b,a   0x116e4                          ! Conditional/control branch; inspect delay slot.
0x11638    d0 27 bf e8    st  %o0, [ %fp + -24 ]
0x1163C    e4 27 bf e0    st  %l2, [ %fp + -32 ]
0x11640    c0 27 bf d4    clr  [ %fp + -44 ]
0x11644    e8 27 bf e4    st  %l4, [ %fp + -28 ]
0x11648    7f ff fe af    call  0x11104                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1164C    90 10 00 13    mov  %l3, %o0
0x11650    80 a2 20 00    cmp  %o0, 0
0x11654    32 80 00 24    bne,a   0x116e4                        ! Conditional/control branch; inspect delay slot.
0x11658    b0 10 20 01    mov  1, %i0
0x1165C    d0 0d 20 0f    ldub  [ %l4 + 0xf ], %o0
0x11660    80 a2 20 01    cmp  %o0, 1
0x11664    22 bf ff ad    be,a   0x11518                         ! Conditional/control branch; inspect delay slot.
0x11668    d6 06 00 00    ld  [ %i0 ], %o3
0x1166C    14 80 00 06    bg  0x11684                            ! Conditional/control branch; inspect delay slot.
0x11670    80 a2 20 02    cmp  %o0, 2
0x11674    80 a2 20 00    cmp  %o0, 0
0x11678    02 80 00 06    be  0x11690                            ! Conditional/control branch; inspect delay slot.
0x1167C    b0 10 20 01    mov  1, %i0
0x11680    30 80 00 19    b,a   0x116e4                          ! Conditional/control branch; inspect delay slot.
0x11684    02 80 00 18    be  0x116e4                            ! Conditional/control branch; inspect delay slot.
0x11688    b0 10 20 01    mov  1, %i0
0x1168C    30 80 00 16    b,a   0x116e4                          ! Conditional/control branch; inspect delay slot.
0x11690    96 10 20 00    clr  %o3
0x11694    80 a2 c0 11    cmp  %o3, %l1
0x11698    16 80 00 13    bge  0x116e4                           ! Conditional/control branch; inspect delay slot.
0x1169C    b0 10 20 00    clr  %i0
0x116A0    98 10 00 11    mov  %l1, %o4
0x116A4    d0 0e 60 03    ldub  [ %i1 + 3 ], %o0
0x116A8    96 02 e0 04    add  %o3, 4, %o3
0x116AC    d2 0e 60 02    ldub  [ %i1 + 2 ], %o1
0x116B0    91 2a 20 18    sll  %o0, 0x18, %o0
0x116B4    d4 0e 60 01    ldub  [ %i1 + 1 ], %o2
0x116B8    93 2a 60 10    sll  %o1, 0x10, %o1
0x116BC    90 12 00 09    or  %o0, %o1, %o0
0x116C0    d2 0e 40 00    ldub  [ %i1 ], %o1
0x116C4    95 2a a0 08    sll  %o2, 8, %o2
0x116C8    90 12 00 0a    or  %o0, %o2, %o0
0x116CC    90 12 00 09    or  %o0, %o1, %o0
0x116D0    d0 26 40 00    st  %o0, [ %i1 ]
0x116D4    80 a2 c0 0c    cmp  %o3, %o4
0x116D8    06 bf ff f3    bl  0x116a4                            ! Conditional/control branch; inspect delay slot.
0x116DC    b2 06 60 04    add  %i1, 4, %i1
0x116E0    b0 10 20 00    clr  %i0
0x116E4    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x116E8    81 e8 00 00    restore                                ! Restore previous register window.
0x116EC    9d e3 bf 70    save  %sp, -144, %sp                   ! Enter register window; allocate stack frame.
0x116F0    d6 06 00 00    ld  [ %i0 ], %o3
0x116F4    19 21 e0 dc    sethi  %hi(0x87837000), %o4            ! Build high part of constant/address.
0x116F8    d4 06 20 04    ld  [ %i0 + 4 ], %o2
0x116FC    11 21 83 ff    sethi  %hi(0x860ffc00), %o0            ! Build high part of constant/address.
0x11700    d2 03 21 f8    ld  [ %o4 + 0x1f8 ], %o1
0x11704    a0 12 22 00    or  %o0, 0x200, %l0
0x11708    d6 27 bf d0    st  %o3, [ %fp + -48 ]
0x1170C    d4 27 bf dc    st  %o2, [ %fp + -36 ]
0x11710    f2 27 bf e4    st  %i1, [ %fp + -28 ]
0x11714    c0 27 bf ec    clr  [ %fp + -20 ]
0x11718    d2 24 20 04    st  %o1, [ %l0 + 4 ]
0x1171C    a2 12 22 80    or  %o0, 0x280, %l1
0x11720    11 10 d0 94    sethi  %hi(0x43425000), %o0            ! Build high part of constant/address.
0x11724    92 02 60 01    inc  %o1
0x11728    d2 23 21 f8    st  %o1, [ %o4 + 0x1f8 ]
0x1172C    90 12 23 55    or  %o0, 0x355, %o0
0x11730    d0 24 00 00    st  %o0, [ %l0 ]
0x11734    80 a6 e0 00    cmp  %i3, 0
0x11738    12 80 00 05    bne  0x1174c                           ! Conditional/control branch; inspect delay slot.
0x1173C    f4 24 20 08    st  %i2, [ %l0 + 8 ]
0x11740    90 10 20 80    mov  0x80, %o0
0x11744    10 80 00 03    b  0x11750                             ! Conditional/control branch; inspect delay slot.
0x11748    d0 2c 20 0c    stb  %o0, [ %l0 + 0xc ]
0x1174C    c0 2c 20 0c    clrb  [ %l0 + 0xc ]
0x11750    fa 2c 20 0e    stb  %i5, [ %l0 + 0xe ]
0x11754    c0 2c 20 0d    clrb  [ %l0 + 0xd ]
0x11758    d0 0f 00 00    ldub  [ %i4 ], %o0
0x1175C    92 10 20 14    mov  0x14, %o1
0x11760    d0 2c 20 0f    stb  %o0, [ %l0 + 0xf ]
0x11764    d6 0f 20 01    ldub  [ %i4 + 1 ], %o3
0x11768    90 14 20 0c    or  %l0, 0xc, %o0
0x1176C    d6 2c 20 10    stb  %o3, [ %l0 + 0x10 ]
0x11770    d4 0f 20 02    ldub  [ %i4 + 2 ], %o2
0x11774    d4 2c 20 11    stb  %o2, [ %l0 + 0x11 ]
0x11778    d6 0f 20 03    ldub  [ %i4 + 3 ], %o3
0x1177C    d6 2c 20 12    stb  %o3, [ %l0 + 0x12 ]
0x11780    d4 0f 20 04    ldub  [ %i4 + 4 ], %o2
0x11784    d4 2c 20 13    stb  %o2, [ %l0 + 0x13 ]
0x11788    d6 0f 20 05    ldub  [ %i4 + 5 ], %o3
0x1178C    d6 2c 20 14    stb  %o3, [ %l0 + 0x14 ]
0x11790    d4 0f 20 06    ldub  [ %i4 + 6 ], %o2
0x11794    d4 2c 20 15    stb  %o2, [ %l0 + 0x15 ]
0x11798    d6 0f 20 07    ldub  [ %i4 + 7 ], %o3
0x1179C    d6 2c 20 16    stb  %o3, [ %l0 + 0x16 ]
0x117A0    d4 0f 20 08    ldub  [ %i4 + 8 ], %o2
0x117A4    d4 2c 20 17    stb  %o2, [ %l0 + 0x17 ]
0x117A8    d6 0f 20 09    ldub  [ %i4 + 9 ], %o3
0x117AC    d6 2c 20 18    stb  %o3, [ %l0 + 0x18 ]
0x117B0    d4 0f 20 0a    ldub  [ %i4 + 0xa ], %o2
0x117B4    d4 2c 20 19    stb  %o2, [ %l0 + 0x19 ]
0x117B8    d6 0f 20 0b    ldub  [ %i4 + 0xb ], %o3
0x117BC    d6 2c 20 1a    stb  %o3, [ %l0 + 0x1a ]
0x117C0    d4 0f 20 0c    ldub  [ %i4 + 0xc ], %o2
0x117C4    d4 2c 20 1b    stb  %o2, [ %l0 + 0x1b ]
0x117C8    d6 0f 20 0d    ldub  [ %i4 + 0xd ], %o3
0x117CC    d6 2c 20 1c    stb  %o3, [ %l0 + 0x1c ]
0x117D0    d4 0f 20 0e    ldub  [ %i4 + 0xe ], %o2
0x117D4    d4 2c 20 1d    stb  %o2, [ %l0 + 0x1d ]
0x117D8    d6 0f 20 0f    ldub  [ %i4 + 0xf ], %o3
0x117DC    7f ff f4 13    call  0xe828                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x117E0    d6 2c 20 1e    stb  %o3, [ %l0 + 0x1e ]
0x117E4    b8 06 20 18    add  %i0, 0x18, %i4
0x117E8    90 07 bf d0    add  %fp, -48, %o0
0x117EC    92 10 20 01    mov  1, %o1
0x117F0    94 10 20 1f    mov  0x1f, %o2
0x117F4    ba 10 00 08    mov  %o0, %i5
0x117F8    d2 27 bf d4    st  %o1, [ %fp + -44 ]
0x117FC    d4 27 bf e8    st  %o2, [ %fp + -24 ]
0x11800    e0 27 bf e4    st  %l0, [ %fp + -28 ]
0x11804    7f ff fe 40    call  0x11104                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11808    f8 27 bf e0    st  %i4, [ %fp + -32 ]
0x1180C    80 a2 20 00    cmp  %o0, 0
0x11810    32 80 00 26    bne,a   0x118a8                        ! Conditional/control branch; inspect delay slot.
0x11814    b0 10 20 01    mov  1, %i0
0x11818    80 a6 a0 00    cmp  %i2, 0
0x1181C    02 80 00 14    be  0x1186c                            ! Conditional/control branch; inspect delay slot.
0x11820    80 a6 e0 00    cmp  %i3, 0
0x11824    f4 27 bf e8    st  %i2, [ %fp + -24 ]
0x11828    f2 27 bf e4    st  %i1, [ %fp + -28 ]
0x1182C    02 80 00 04    be  0x1183c                            ! Conditional/control branch; inspect delay slot.
0x11830    f6 27 bf d4    st  %i3, [ %fp + -44 ]
0x11834    10 80 00 04    b  0x11844                             ! Conditional/control branch; inspect delay slot.
0x11838    f8 27 bf e0    st  %i4, [ %fp + -32 ]
0x1183C    90 06 20 0c    add  %i0, 0xc, %o0
0x11840    d0 27 bf e0    st  %o0, [ %fp + -32 ]
0x11844    7f ff fe 30    call  0x11104                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11848    90 10 00 1d    mov  %i5, %o0
0x1184C    80 a2 20 00    cmp  %o0, 0
0x11850    02 80 00 07    be  0x1186c                            ! Conditional/control branch; inspect delay slot.
0x11854    d0 07 bf d0    ld  [ %fp + -48 ], %o0
0x11858    d4 06 20 18    ld  [ %i0 + 0x18 ], %o2
0x1185C    b0 10 20 01    mov  1, %i0
0x11860    7f ff ff 10    call  0x114a0                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11864    d2 07 bf dc    ld  [ %fp + -36 ], %o1
0x11868    30 80 00 10    b,a   0x118a8                          ! Conditional/control branch; inspect delay slot.
0x1186C    90 10 20 0d    mov  0xd, %o0
0x11870    92 06 20 0c    add  %i0, 0xc, %o1
0x11874    d0 27 bf e8    st  %o0, [ %fp + -24 ]
0x11878    d2 27 bf e0    st  %o1, [ %fp + -32 ]
0x1187C    90 10 00 1d    mov  %i5, %o0
0x11880    c0 27 bf d4    clr  [ %fp + -44 ]
0x11884    7f ff fe 20    call  0x11104                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11888    e2 27 bf e4    st  %l1, [ %fp + -28 ]
0x1188C    80 a2 20 00    cmp  %o0, 0
0x11890    12 80 00 06    bne  0x118a8                           ! Conditional/control branch; inspect delay slot.
0x11894    b0 10 20 01    mov  1, %i0
0x11898    d2 0c 60 0f    ldub  [ %l1 + 0xf ], %o1
0x1189C    b0 10 20 00    clr  %i0
0x118A0    d0 07 a0 5c    ld  [ %fp + 0x5c ], %o0
0x118A4    d2 2a 00 00    stb  %o1, [ %o0 ]
0x118A8    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x118AC    81 e8 00 00    restore                                ! Restore previous register window.
0x118B0    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x118B4    11 00 00 07    sethi  %hi(0x1c00), %o0                ! Build high part of constant/address.
0x118B8    90 12 23 ff    or  %o0, 0x3ff, %o0                    ! 0x1fff
0x118BC    b6 06 c0 08    add  %i3, %o0, %i3
0x118C0    b7 3e e0 0d    sra  %i3, 0xd, %i3
0x118C4    7f ff ea 98    call  0xc324                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x118C8    90 10 20 00    clr  %o0
0x118CC    a0 10 20 00    clr  %l0
0x118D0    80 a4 00 1b    cmp  %l0, %i3
0x118D4    1a 80 00 36    bcc  0x119ac                           ! Conditional/control branch; inspect delay slot.
0x118D8    11 10 5d 51    sethi  %hi(0x41754400), %o0            ! Build high part of constant/address.
0x118DC    a6 12 22 c0    or  %o0, 0x2c0, %l3                    ! 0x417546c0
0x118E0    95 2c 20 04    sll  %l0, 4, %o2
0x118E4    94 02 80 1a    add  %o2, %i2, %o2
0x118E8    90 10 00 18    mov  %i0, %o0
0x118EC    92 10 00 19    mov  %i1, %o1
0x118F0    7f ff ff 04    call  0x11500                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x118F4    96 10 20 10    mov  0x10, %o3
0x118F8    80 8f 20 ff    btst  0xff, %i4
0x118FC    02 80 00 0e    be  0x11934                            ! Conditional/control branch; inspect delay slot.
0x11900    23 21 e0 dc    sethi  %hi(0x87837000), %l1            ! Build high part of constant/address.
0x11904    80 a4 20 00    cmp  %l0, 0
0x11908    12 80 00 0c    bne  0x11938                           ! Conditional/control branch; inspect delay slot.
0x1190C    d0 04 63 28    ld  [ %l1 + 0x328 ], %o0
0x11910    80 a2 20 00    cmp  %o0, 0
0x11914    02 80 00 0b    be  0x11940                            ! Conditional/control branch; inspect delay slot.
0x11918    a4 04 20 01    add  %l0, 1, %l2
0x1191C    d0 06 60 08    ld  [ %i1 + 8 ], %o0
0x11920    80 a2 00 13    cmp  %o0, %l3
0x11924    02 80 00 06    be  0x1193c                            ! Conditional/control branch; inspect delay slot.
0x11928    d0 04 63 28    ld  [ %l1 + 0x328 ], %o0
0x1192C    7f ff ea 7e    call  0xc324                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11930    90 10 20 01    mov  1, %o0
0x11934    d0 04 63 28    ld  [ %l1 + 0x328 ], %o0
0x11938    a4 04 20 01    add  %l0, 1, %l2
0x1193C    80 a2 20 00    cmp  %o0, 0
0x11940    02 80 00 11    be  0x11984                            ! Conditional/control branch; inspect delay slot.
0x11944    a2 0c 20 3f    and  %l0, 0x3f, %l1
0x11948    a0 10 20 00    clr  %l0
0x1194C    90 10 00 19    mov  %i1, %o0
0x11950    92 10 00 19    mov  %i1, %o1
0x11954    7f ff ea 9d    call  0xc3c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11958    94 10 22 00    mov  0x200, %o2
0x1195C    80 a2 20 00    cmp  %o0, 0
0x11960    36 80 00 06    bge,a   0x11978                        ! Conditional/control branch; inspect delay slot.
0x11964    a0 04 20 01    inc  %l0
0x11968    90 10 20 01    mov  1, %o0
0x1196C    7f ff f8 62    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11970    92 10 20 07    mov  7, %o1
0x11974    a0 04 20 01    inc  %l0
0x11978    80 a4 20 0f    cmp  %l0, 0xf
0x1197C    08 bf ff f4    bleu  0x1194c                          ! Conditional/control branch; inspect delay slot.
0x11980    b2 06 62 00    add  %i1, 0x200, %i1
0x11984    80 a4 60 00    cmp  %l1, 0
0x11988    12 80 00 06    bne  0x119a0                           ! Conditional/control branch; inspect delay slot.
0x1198C    a0 10 00 12    mov  %l2, %l0
0x11990    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x11994    7f ff f4 31    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11998    90 12 23 70    or  %o0, 0x370, %o0                    ! 0x87836f70
0x1199C    a0 10 00 12    mov  %l2, %l0
0x119A0    80 a4 00 1b    cmp  %l0, %i3
0x119A4    0a bf ff d0    bcs  0x118e4                           ! Conditional/control branch; inspect delay slot.
0x119A8    95 2c 20 04    sll  %l0, 4, %o2
0x119AC    7f ff ea 5e    call  0xc324                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x119B0    90 10 20 00    clr  %o0
0x119B4    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x119B8    81 e8 00 00    restore                                ! Restore previous register window.
0x119BC    9d e3 bb f0    save  %sp, -1040, %sp                  ! Enter register window; allocate stack frame.
0x119C0    11 21 83 ff    sethi  %hi(0x860ffc00), %o0            ! Build high part of constant/address.
0x119C4    a4 12 23 00    or  %o0, 0x300, %l2                    ! 0x860fff00
0x119C8    90 07 be e8    add  %fp, -280, %o0
0x119CC    d0 27 bc 68    st  %o0, [ %fp + -920 ]
0x119D0    92 07 bd e8    add  %fp, -536, %o1
0x119D4    90 07 bc e8    add  %fp, -792, %o0
0x119D8    2d 20 00 04    sethi  %hi(0x80001000), %l6            ! Build high part of constant/address.
0x119DC    35 21 84 00    sethi  %hi(0x86100000), %i2            ! Build high part of constant/address.
0x119E0    c0 27 bc 6c    clr  [ %fp + -916 ]
0x119E4    a8 07 bc c0    add  %fp, -832, %l4
0x119E8    ae 07 bc 98    add  %fp, -872, %l7
0x119EC    d2 27 bc 60    st  %o1, [ %fp + -928 ]
0x119F0    d0 27 bc 5c    st  %o0, [ %fp + -932 ]
0x119F4    aa 07 bc 88    add  %fp, -888, %l5
0x119F8    b8 07 bc 87    add  %fp, -889, %i4
0x119FC    d2 07 bc 6c    ld  [ %fp + -916 ], %o1
0x11A00    80 a2 60 03    cmp  %o1, 3
0x11A04    34 80 00 02    bg,a   0x11a0c
0x11A08    c0 27 bc 6c    clr  [ %fp + -916 ]
0x11A0C    7f ff fb ce    call  0x10944                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11A10    a2 10 20 00    clr  %l1
0x11A14    d0 07 bc 6c    ld  [ %fp + -916 ], %o0
0x11A18    13 00 00 3f    sethi  %hi(0xfc00), %o1                ! Build high part of constant/address.
0x11A1C    ba 12 63 ff    or  %o1, 0x3ff, %i5                    ! 0xffff
0x11A20    92 02 20 01    add  %o0, 1, %o1
0x11A24    b7 3a 20 01    sra  %o0, 1, %i3
0x11A28    b2 0a 20 01    and  %o0, 1, %i1
0x11A2C    d2 27 bc 64    st  %o1, [ %fp + -924 ]
0x11A30    b0 10 20 00    clr  %i0
0x11A34    27 02 00 00    sethi  %hi(0x8000000), %l3             ! Build high part of constant/address.
0x11A38    92 10 20 17    mov  0x17, %o1
0x11A3C    90 10 20 00    clr  %o0
0x11A40    94 10 00 11    mov  %l1, %o2
0x11A44    7f ff fb cf    call  0x10980                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11A48    96 10 20 00    clr  %o3
0x11A4C    13 0c 0e 04    sethi  %hi(0x30381000), %o1            ! Build high part of constant/address.
0x11A50    92 12 61 06    or  %o1, 0x106, %o1                    ! 0x30381106
0x11A54    80 a2 00 09    cmp  %o0, %o1
0x11A58    32 80 00 33    bne,a   0x11b24                        ! Conditional/control branch; inspect delay slot.
0x11A5C    a2 04 60 01    inc  %l1
0x11A60    11 07 00 04    sethi  %hi(0x1c001000), %o0            ! Build high part of constant/address.
0x11A64    93 2c 60 05    sll  %l1, 5, %o1
0x11A68    92 02 40 08    add  %o1, %o0, %o1
0x11A6C    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x11A70    a0 12 21 fc    or  %o0, 0x1fc, %l0                    ! 0x878371fc
0x11A74    98 0a 40 1d    and  %o1, %i5, %o4
0x11A78    d2 24 00 18    st  %o1, [ %l0 + %i0 ]
0x11A7C    90 10 20 00    clr  %o0
0x11A80    92 10 20 17    mov  0x17, %o1
0x11A84    94 10 00 11    mov  %l1, %o2
0x11A88    7f ff fb d3    call  0x109d4                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11A8C    96 10 20 20    mov  0x20, %o3
0x11A90    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x11A94    d2 0a 23 a8    ldub  [ %o0 + 0x3a8 ], %o1             ! 0x878373a8
0x11A98    80 a2 60 01    cmp  %o1, 1
0x11A9C    12 80 00 05    bne  0x11ab0                           ! Conditional/control branch; inspect delay slot.
0x11AA0    80 a4 60 01    cmp  %l1, 1
0x11AA4    90 04 20 04    add  %l0, 4, %o0
0x11AA8    10 80 00 08    b  0x11ac8                             ! Conditional/control branch; inspect delay slot.
0x11AAC    e6 22 00 18    st  %l3, [ %o0 + %i0 ]
0x11AB0    12 80 00 05    bne  0x11ac4                           ! Conditional/control branch; inspect delay slot.
0x11AB4    92 04 20 04    add  %l0, 4, %o1
0x11AB8    11 01 00 00    sethi  %hi(0x4000000), %o0             ! Build high part of constant/address.
0x11ABC    10 80 00 03    b  0x11ac8                             ! Conditional/control branch; inspect delay slot.
0x11AC0    d0 22 40 18    st  %o0, [ %o1 + %i0 ]
0x11AC4    e6 22 40 18    st  %l3, [ %o1 + %i0 ]
0x11AC8    92 10 20 17    mov  0x17, %o1
0x11ACC    94 10 00 11    mov  %l1, %o2
0x11AD0    96 10 20 04    mov  4, %o3
0x11AD4    7f ff fb ab    call  0x10980                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11AD8    90 10 20 00    clr  %o0
0x11ADC    90 12 20 05    or  %o0, 5, %o0
0x11AE0    91 2a 20 10    sll  %o0, 0x10, %o0
0x11AE4    99 32 20 10    srl  %o0, 0x10, %o4
0x11AE8    90 10 20 00    clr  %o0
0x11AEC    92 10 20 17    mov  0x17, %o1
0x11AF0    94 10 00 11    mov  %l1, %o2
0x11AF4    7f ff fb e7    call  0x10a90                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11AF8    96 10 20 04    mov  4, %o3
0x11AFC    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x11B00    90 12 61 fc    or  %o1, 0x1fc, %o0                    ! 0x878371fc
0x11B04    7f ff fc 08    call  0x10b24                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11B08    90 06 00 08    add  %i0, %o0, %o0
0x11B0C    80 a2 20 00    cmp  %o0, 0
0x11B10    02 80 00 04    be  0x11b20                            ! Conditional/control branch; inspect delay slot.
0x11B14    90 10 20 01    mov  1, %o0
0x11B18    7f ff f7 f7    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11B1C    92 10 20 06    mov  6, %o1
0x11B20    a2 04 60 01    inc  %l1
0x11B24    80 a4 60 01    cmp  %l1, 1
0x11B28    04 bf ff c4    ble  0x11a38                           ! Conditional/control branch; inspect delay slot.
0x11B2C    b0 06 20 94    add  %i0, 0x94, %i0
0x11B30    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x11B34    a0 12 21 fc    or  %o0, 0x1fc, %l0                    ! 0x878371fc
0x11B38    7f ff fc 52    call  0x10c80                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11B3C    90 10 00 10    mov  %l0, %o0
0x11B40    a2 04 20 94    add  %l0, 0x94, %l1
0x11B44    7f ff fc 4f    call  0x10c80                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11B48    90 10 00 11    mov  %l1, %o0
0x11B4C    7f ff fc 5c    call  0x10cbc                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11B50    90 10 00 10    mov  %l0, %o0
0x11B54    7f ff fc 5a    call  0x10cbc                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11B58    90 10 00 11    mov  %l1, %o0
0x11B5C    92 0e e0 01    and  %i3, 1, %o1
0x11B60    91 2a 60 03    sll  %o1, 3, %o0
0x11B64    90 02 00 09    add  %o0, %o1, %o0
0x11B68    91 2a 20 02    sll  %o0, 2, %o0
0x11B6C    90 02 00 09    add  %o0, %o1, %o0
0x11B70    91 2a 20 02    sll  %o0, 2, %o0
0x11B74    d4 02 00 10    ld  [ %o0 + %l0 ], %o2
0x11B78    93 2e 60 01    sll  %i1, 1, %o1
0x11B7C    92 02 60 10    add  %o1, 0x10, %o1
0x11B80    94 02 80 09    add  %o2, %o1, %o2
0x11B84    a2 02 00 10    add  %o0, %l0, %l1
0x11B88    94 0a bf fe    and  %o2, -2, %o2
0x11B8C    d0 12 80 00    lduh  [ %o2 ], %o0
0x11B90    a6 10 20 02    mov  2, %l3
0x11B94    80 8a 20 01    btst  1, %o0
0x11B98    12 80 00 06    bne  0x11bb0                           ! Conditional/control branch; inspect delay slot.
0x11B9C    b0 10 20 08    mov  8, %i0
0x11BA0    d2 07 bc 6c    ld  [ %fp + -916 ], %o1
0x11BA4    92 02 60 01    inc  %o1
0x11BA8    10 bf ff 95    b  0x119fc                             ! Conditional/control branch; inspect delay slot.
0x11BAC    d2 27 bc 6c    st  %o1, [ %fp + -916 ]
0x11BB0    92 10 00 19    mov  %i1, %o1
0x11BB4    7f ff fc 6c    call  0x10d64                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11BB8    90 10 00 11    mov  %l1, %o0
0x11BBC    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x11BC0    13 21 e0 db    sethi  %hi(0x87836c00), %o1            ! Build high part of constant/address.
0x11BC4    e2 22 23 24    st  %l1, [ %o0 + 0x324 ]
0x11BC8    7f ff f3 a4    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11BCC    90 12 63 78    or  %o1, 0x378, %o0
0x11BD0    d0 07 bc 6c    ld  [ %fp + -916 ], %o0
0x11BD4    7f ff f3 ca    call  0xeafc                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11BD8    a0 10 20 08    mov  8, %l0
0x11BDC    7f ff f3 e1    call  0xeb60                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11BE0    90 10 20 0a    mov  0xa, %o0
0x11BE4    92 10 20 08    mov  8, %o1
0x11BE8    7f ff f7 c3    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11BEC    90 10 20 00    clr  %o0
0x11BF0    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x11BF4    d2 02 23 24    ld  [ %o0 + 0x324 ], %o1               ! 0x87837324
0x11BF8    c0 27 bc cc    clr  [ %fp + -820 ]
0x11BFC    d2 27 bc c0    st  %o1, [ %fp + -832 ]
0x11C00    e0 27 bc c8    st  %l0, [ %fp + -824 ]
0x11C04    f4 27 bc d4    st  %i2, [ %fp + -812 ]
0x11C08    e4 27 bc dc    st  %l2, [ %fp + -804 ]
0x11C0C    90 10 25 00    mov  0x500, %o0
0x11C10    d0 34 a0 02    sth  %o0, [ %l2 + 2 ]
0x11C14    e6 34 80 00    sth  %l3, [ %l2 ]
0x11C18    c0 34 a0 06    clrh  [ %l2 + 6 ]
0x11C1C    c0 34 a0 04    clrh  [ %l2 + 4 ]
0x11C20    90 10 20 01    mov  1, %o0
0x11C24    d0 27 bc c4    st  %o0, [ %fp + -828 ]
0x11C28    c0 27 bc d8    clr  [ %fp + -808 ]
0x11C2C    7f ff fc 79    call  0x10e10                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11C30    90 10 00 14    mov  %l4, %o0
0x11C34    d2 07 bc 64    ld  [ %fp + -924 ], %o1
0x11C38    80 a2 20 00    cmp  %o0, 0
0x11C3C    12 80 00 17    bne  0x11c98                           ! Conditional/control branch; inspect delay slot.
0x11C40    d2 27 bc 6c    st  %o1, [ %fp + -916 ]
0x11C44    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x11C48    d2 02 23 24    ld  [ %o0 + 0x324 ], %o1               ! 0x87837324
0x11C4C    e6 27 bc 9c    st  %l3, [ %fp + -868 ]
0x11C50    11 00 00 13    sethi  %hi(0x4c00), %o0                ! Build high part of constant/address.
0x11C54    e6 27 bc cc    st  %l3, [ %fp + -820 ]
0x11C58    d2 27 bc 98    st  %o1, [ %fp + -872 ]
0x11C5C    6a 1f 29 e9    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11C60    90 12 22 20    or  %o0, 0x220, %o0
0x11C64    a6 10 26 80    mov  0x680, %l3
0x11C68    a2 10 21 00    mov  0x100, %l1
0x11C6C    e6 34 a0 02    sth  %l3, [ %l2 + 2 ]
0x11C70    e2 34 80 00    sth  %l1, [ %l2 ]
0x11C74    c0 34 a0 06    clrh  [ %l2 + 6 ]
0x11C78    e0 34 a0 04    sth  %l0, [ %l2 + 4 ]
0x11C7C    e0 27 bc d8    st  %l0, [ %fp + -808 ]
0x11C80    c0 27 bc c4    clr  [ %fp + -828 ]
0x11C84    7f ff fc 63    call  0x10e10                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11C88    90 10 00 14    mov  %l4, %o0
0x11C8C    80 a2 20 00    cmp  %o0, 0
0x11C90    22 80 00 0a    be,a   0x11cb8                         ! Conditional/control branch; inspect delay slot.
0x11C94    d0 0e a0 04    ldub  [ %i2 + 4 ], %o0
0x11C98    90 10 20 00    clr  %o0
0x11C9C    7f ff f7 96    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11CA0    92 10 20 08    mov  8, %o1
0x11CA4    11 00 04 f5    sethi  %hi(0x13d400), %o0              ! Build high part of constant/address.
0x11CA8    6a 1f 29 d6    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11CAC    90 12 22 20    or  %o0, 0x220, %o0                    ! 0x13d620
0x11CB0    10 bf ff 54    b  0x11a00                             ! Conditional/control branch; inspect delay slot.
0x11CB4    d2 07 bc 6c    ld  [ %fp + -916 ], %o1
0x11CB8    92 10 20 12    mov  0x12, %o1
0x11CBC    d0 27 bc c8    st  %o0, [ %fp + -824 ]
0x11CC0    e2 34 80 00    sth  %l1, [ %l2 ]
0x11CC4    d2 34 a0 04    sth  %o1, [ %l2 + 4 ]
0x11CC8    e6 34 a0 02    sth  %l3, [ %l2 + 2 ]
0x11CCC    c0 34 a0 06    clrh  [ %l2 + 6 ]
0x11CD0    90 10 20 12    mov  0x12, %o0
0x11CD4    d0 27 bc d8    st  %o0, [ %fp + -808 ]
0x11CD8    c0 27 bc c4    clr  [ %fp + -828 ]
0x11CDC    7f ff fc 4d    call  0x10e10                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11CE0    90 10 00 14    mov  %l4, %o0
0x11CE4    80 a2 20 00    cmp  %o0, 0
0x11CE8    32 80 00 e7    bne,a   0x12084                        ! Conditional/control branch; inspect delay slot.
0x11CEC    90 10 20 00    clr  %o0
0x11CF0    d0 0e a0 0d    ldub  [ %i2 + 0xd ], %o0
0x11CF4    a0 10 22 00    mov  0x200, %l0
0x11CF8    d2 0e a0 0c    ldub  [ %i2 + 0xc ], %o1
0x11CFC    a2 10 00 08    mov  %o0, %l1
0x11D00    e6 34 a0 02    sth  %l3, [ %l2 + 2 ]
0x11D04    d0 0e a0 13    ldub  [ %i2 + 0x13 ], %o0
0x11D08    ba 10 00 09    mov  %o1, %i5
0x11D0C    e0 34 80 00    sth  %l0, [ %l2 ]
0x11D10    c0 34 a0 06    clrh  [ %l2 + 6 ]
0x11D14    f0 34 a0 04    sth  %i0, [ %l2 + 4 ]
0x11D18    b6 10 00 08    mov  %o0, %i3
0x11D1C    f0 27 bc d8    st  %i0, [ %fp + -808 ]
0x11D20    c0 27 bc c4    clr  [ %fp + -828 ]
0x11D24    7f ff fc 3b    call  0x10e10                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11D28    90 10 00 14    mov  %l4, %o0
0x11D2C    80 a2 20 00    cmp  %o0, 0
0x11D30    32 80 00 d5    bne,a   0x12084                        ! Conditional/control branch; inspect delay slot.
0x11D34    90 10 20 00    clr  %o0
0x11D38    d0 0e 80 00    ldub  [ %i2 ], %o0
0x11D3C    e0 34 80 00    sth  %l0, [ %l2 ]
0x11D40    d2 0e a0 01    ldub  [ %i2 + 1 ], %o1
0x11D44    91 2a 20 08    sll  %o0, 8, %o0
0x11D48    92 12 40 08    or  %o1, %o0, %o1
0x11D4C    e6 34 a0 02    sth  %l3, [ %l2 + 2 ]
0x11D50    c0 34 a0 06    clrh  [ %l2 + 6 ]
0x11D54    d2 34 a0 04    sth  %o1, [ %l2 + 4 ]
0x11D58    d2 27 bc d8    st  %o1, [ %fp + -808 ]
0x11D5C    c0 27 bc c4    clr  [ %fp + -828 ]
0x11D60    7f ff fc 2c    call  0x10e10                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11D64    90 10 00 14    mov  %l4, %o0
0x11D68    80 a2 20 00    cmp  %o0, 0
0x11D6C    32 80 00 c6    bne,a   0x12084                        ! Conditional/control branch; inspect delay slot.
0x11D70    90 10 20 00    clr  %o0
0x11D74    d2 07 bc e0    ld  [ %fp + -800 ], %o1
0x11D78    7f ff f2 ac    call  0xe828                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11D7C    11 21 84 00    sethi  %hi(0x86100000), %o0            ! Build high part of constant/address.
0x11D80    d4 07 bc e0    ld  [ %fp + -800 ], %o2
0x11D84    13 21 84 00    sethi  %hi(0x86100000), %o1            ! Build high part of constant/address.
0x11D88    7f ff fd 89    call  0x113ac                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11D8C    90 10 00 17    mov  %l7, %o0
0x11D90    92 10 29 00    mov  0x900, %o1
0x11D94    90 10 20 01    mov  1, %o0
0x11D98    d0 34 80 00    sth  %o0, [ %l2 ]
0x11D9C    d2 34 a0 02    sth  %o1, [ %l2 + 2 ]
0x11DA0    c0 34 a0 06    clrh  [ %l2 + 6 ]
0x11DA4    c0 34 a0 04    clrh  [ %l2 + 4 ]
0x11DA8    b2 10 20 01    mov  1, %i1
0x11DAC    f2 27 bc c4    st  %i1, [ %fp + -828 ]
0x11DB0    c0 27 bc d8    clr  [ %fp + -808 ]
0x11DB4    7f ff fc 17    call  0x10e10                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11DB8    90 10 00 14    mov  %l4, %o0
0x11DBC    80 a2 20 00    cmp  %o0, 0
0x11DC0    32 80 00 b1    bne,a   0x12084                        ! Conditional/control branch; inspect delay slot.
0x11DC4    90 10 20 00    clr  %o0
0x11DC8    90 10 23 00    mov  0x300, %o0
0x11DCC    d0 34 80 00    sth  %o0, [ %l2 ]
0x11DD0    92 10 20 04    mov  4, %o1
0x11DD4    d2 34 a0 04    sth  %o1, [ %l2 + 4 ]
0x11DD8    e6 34 a0 02    sth  %l3, [ %l2 + 2 ]
0x11DDC    c0 34 a0 06    clrh  [ %l2 + 6 ]
0x11DE0    90 10 20 04    mov  4, %o0
0x11DE4    d0 27 bc d8    st  %o0, [ %fp + -808 ]
0x11DE8    c0 27 bc c4    clr  [ %fp + -828 ]
0x11DEC    7f ff fc 09    call  0x10e10                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11DF0    90 10 00 14    mov  %l4, %o0
0x11DF4    80 a2 20 00    cmp  %o0, 0
0x11DF8    32 80 00 a3    bne,a   0x12084                        ! Conditional/control branch; inspect delay slot.
0x11DFC    90 10 20 00    clr  %o0
0x11E00    d0 0e 80 00    ldub  [ %i2 ], %o0
0x11E04    94 14 63 00    or  %l1, 0x300, %o2
0x11E08    d2 0e a0 01    ldub  [ %i2 + 1 ], %o1
0x11E0C    91 2a 20 08    sll  %o0, 8, %o0
0x11E10    a0 12 40 08    or  %o1, %o0, %l0
0x11E14    b0 10 20 ff    mov  0xff, %i0
0x11E18    d4 34 80 00    sth  %o2, [ %l2 ]
0x11E1C    e6 34 a0 02    sth  %l3, [ %l2 + 2 ]
0x11E20    e0 34 a0 06    sth  %l0, [ %l2 + 6 ]
0x11E24    f0 34 a0 04    sth  %i0, [ %l2 + 4 ]
0x11E28    a2 10 20 40    mov  0x40, %l1
0x11E2C    c0 27 bc c4    clr  [ %fp + -828 ]
0x11E30    e2 27 bc d8    st  %l1, [ %fp + -808 ]
0x11E34    7f ff fb f7    call  0x10e10                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11E38    90 10 00 14    mov  %l4, %o0
0x11E3C    80 a2 20 00    cmp  %o0, 0
0x11E40    12 80 00 91    bne  0x12084                           ! Conditional/control branch; inspect delay slot.
0x11E44    90 10 20 00    clr  %o0
0x11E48    d4 07 bc e0    ld  [ %fp + -800 ], %o2
0x11E4C    13 21 84 00    sethi  %hi(0x86100000), %o1            ! Build high part of constant/address.
0x11E50    7f ff f2 69    call  0xe7f4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11E54    d0 07 bc 68    ld  [ %fp + -920 ], %o0
0x11E58    92 16 e3 00    or  %i3, 0x300, %o1
0x11E5C    d2 34 80 00    sth  %o1, [ %l2 ]
0x11E60    e6 34 a0 02    sth  %l3, [ %l2 + 2 ]
0x11E64    e0 34 a0 06    sth  %l0, [ %l2 + 6 ]
0x11E68    f0 34 a0 04    sth  %i0, [ %l2 + 4 ]
0x11E6C    c0 27 bc c4    clr  [ %fp + -828 ]
0x11E70    e2 27 bc d8    st  %l1, [ %fp + -808 ]
0x11E74    7f ff fb e7    call  0x10e10                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11E78    90 10 00 14    mov  %l4, %o0
0x11E7C    80 a2 20 00    cmp  %o0, 0
0x11E80    12 80 00 81    bne  0x12084                           ! Conditional/control branch; inspect delay slot.
0x11E84    90 10 20 00    clr  %o0
0x11E88    d4 07 bc e0    ld  [ %fp + -800 ], %o2
0x11E8C    13 21 84 00    sethi  %hi(0x86100000), %o1            ! Build high part of constant/address.
0x11E90    7f ff f2 59    call  0xe7f4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11E94    d0 07 bc 60    ld  [ %fp + -928 ], %o0
0x11E98    92 17 63 00    or  %i5, 0x300, %o1
0x11E9C    e6 34 a0 02    sth  %l3, [ %l2 + 2 ]
0x11EA0    d2 34 80 00    sth  %o1, [ %l2 ]
0x11EA4    e0 34 a0 06    sth  %l0, [ %l2 + 6 ]
0x11EA8    f0 34 a0 04    sth  %i0, [ %l2 + 4 ]
0x11EAC    e2 27 bc d8    st  %l1, [ %fp + -808 ]
0x11EB0    c0 27 bc c4    clr  [ %fp + -828 ]
0x11EB4    7f ff fb d7    call  0x10e10                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11EB8    90 10 00 14    mov  %l4, %o0
0x11EBC    80 a2 20 00    cmp  %o0, 0
0x11EC0    12 80 00 71    bne  0x12084                           ! Conditional/control branch; inspect delay slot.
0x11EC4    90 10 20 00    clr  %o0
0x11EC8    d4 07 bc e0    ld  [ %fp + -800 ], %o2
0x11ECC    13 21 84 00    sethi  %hi(0x86100000), %o1            ! Build high part of constant/address.
0x11ED0    7f ff f2 49    call  0xe7f4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11ED4    d0 07 bc 5c    ld  [ %fp + -932 ], %o0
0x11ED8    13 00 00 3f    sethi  %hi(0xfc00), %o1                ! Build high part of constant/address.
0x11EDC    92 12 62 a1    or  %o1, 0x2a1, %o1                    ! 0xfea1
0x11EE0    d2 34 a0 02    sth  %o1, [ %l2 + 2 ]
0x11EE4    c0 34 80 00    clrh  [ %l2 ]
0x11EE8    d2 17 bc a2    lduh  [ %fp + -862 ], %o1
0x11EEC    90 10 00 14    mov  %l4, %o0
0x11EF0    d2 34 a0 06    sth  %o1, [ %l2 + 6 ]
0x11EF4    f2 34 a0 04    sth  %i1, [ %l2 + 4 ]
0x11EF8    f2 27 bc d8    st  %i1, [ %fp + -808 ]
0x11EFC    7f ff fb c5    call  0x10e10                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11F00    c0 27 bc c4    clr  [ %fp + -828 ]
0x11F04    80 a2 20 00    cmp  %o0, 0
0x11F08    12 80 00 5f    bne  0x12084                           ! Conditional/control branch; inspect delay slot.
0x11F0C    90 10 20 00    clr  %o0
0x11F10    90 05 60 0f    add  %l5, 0xf, %o0
0x11F14    92 10 00 15    mov  %l5, %o1
0x11F18    c0 2a 00 00    clrb  [ %o0 ]
0x11F1C    90 02 3f ff    add  %o0, -1, %o0
0x11F20    80 a2 00 09    cmp  %o0, %o1
0x11F24    36 bf ff fe    bge,a   0x11f1c                        ! Conditional/control branch; inspect delay slot.
0x11F28    c0 2a 00 00    clrb  [ %o0 ]
0x11F2C    90 10 20 12    mov  0x12, %o0
0x11F30    92 10 20 24    mov  0x24, %o1
0x11F34    d0 2f bc 88    stb  %o0, [ %fp + -888 ]
0x11F38    d2 2f bc 8c    stb  %o1, [ %fp + -884 ]
0x11F3C    f8 23 a0 5c    st  %i4, [ %sp + 0x5c ]
0x11F40    90 10 00 17    mov  %l7, %o0
0x11F44    13 21 84 00    sethi  %hi(0x86100000), %o1            ! Build high part of constant/address.
0x11F48    94 10 20 24    mov  0x24, %o2
0x11F4C    96 10 20 00    clr  %o3
0x11F50    98 10 00 15    mov  %l5, %o4
0x11F54    7f ff fd e6    call  0x116ec                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11F58    9a 10 20 0a    mov  0xa, %o5
0x11F5C    80 a2 20 00    cmp  %o0, 0
0x11F60    12 80 00 41    bne  0x12064                           ! Conditional/control branch; inspect delay slot.
0x11F64    90 10 20 00    clr  %o0
0x11F68    90 07 bc 97    add  %fp, -873, %o0
0x11F6C    92 10 00 15    mov  %l5, %o1
0x11F70    c0 2a 00 00    clrb  [ %o0 ]
0x11F74    90 02 3f ff    add  %o0, -1, %o0
0x11F78    80 a2 00 09    cmp  %o0, %o1
0x11F7C    36 bf ff fe    bge,a   0x11f74                        ! Conditional/control branch; inspect delay slot.
0x11F80    c0 2a 00 00    clrb  [ %o0 ]
0x11F84    c0 2f bc 88    clrb  [ %fp + -888 ]
0x11F88    f8 23 a0 5c    st  %i4, [ %sp + 0x5c ]
0x11F8C    90 10 00 17    mov  %l7, %o0
0x11F90    13 21 84 00    sethi  %hi(0x86100000), %o1            ! Build high part of constant/address.
0x11F94    94 10 20 00    clr  %o2
0x11F98    96 10 20 00    clr  %o3
0x11F9C    98 10 00 15    mov  %l5, %o4
0x11FA0    7f ff fd d3    call  0x116ec                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x11FA4    9a 10 20 06    mov  6, %o5
0x11FA8    80 a2 20 00    cmp  %o0, 0
0x11FAC    12 80 00 2e    bne  0x12064                           ! Conditional/control branch; inspect delay slot.
0x11FB0    90 10 20 00    clr  %o0
0x11FB4    d0 0f bc 87    ldub  [ %fp + -889 ], %o0
0x11FB8    80 a2 20 00    cmp  %o0, 0
0x11FBC    02 80 00 36    be  0x12094                            ! Conditional/control branch; inspect delay slot.
0x11FC0    90 07 bc 97    add  %fp, -873, %o0
0x11FC4    92 10 00 15    mov  %l5, %o1
0x11FC8    c0 2a 00 00    clrb  [ %o0 ]
0x11FCC    90 02 3f ff    add  %o0, -1, %o0
0x11FD0    80 a2 00 09    cmp  %o0, %o1
0x11FD4    36 bf ff fe    bge,a   0x11fcc                        ! Conditional/control branch; inspect delay slot.
0x11FD8    c0 2a 00 00    clrb  [ %o0 ]
0x11FDC    90 10 20 12    mov  0x12, %o0
0x11FE0    92 10 20 03    mov  3, %o1
0x11FE4    d0 2f bc 8c    stb  %o0, [ %fp + -884 ]
0x11FE8    d2 2f bc 88    stb  %o1, [ %fp + -888 ]
0x11FEC    f8 23 a0 5c    st  %i4, [ %sp + 0x5c ]
0x11FF0    90 10 00 17    mov  %l7, %o0
0x11FF4    13 21 84 00    sethi  %hi(0x86100000), %o1            ! Build high part of constant/address.
0x11FF8    94 10 20 12    mov  0x12, %o2
0x11FFC    96 10 20 00    clr  %o3

! ============================================================================
! 0x12000: Large routine continues from 0x11xxx.
! ============================================================================
0x12000    98 10 00 15    mov  %l5, %o4
0x12004    7f ff fd ba    call  0x116ec                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12008    9a 10 20 06    mov  6, %o5
0x1200C    80 a2 20 00    cmp  %o0, 0
0x12010    12 80 00 15    bne  0x12064                           ! Conditional/control branch; inspect delay slot.
0x12014    90 10 20 00    clr  %o0
0x12018    90 07 bc 97    add  %fp, -873, %o0
0x1201C    92 10 00 15    mov  %l5, %o1
0x12020    c0 2a 00 00    clrb  [ %o0 ]
0x12024    90 02 3f ff    add  %o0, -1, %o0
0x12028    80 a2 00 09    cmp  %o0, %o1
0x1202C    36 bf ff fe    bge,a   0x12024                        ! Conditional/control branch; inspect delay slot.
0x12030    c0 2a 00 00    clrb  [ %o0 ]
0x12034    c0 2f bc 88    clrb  [ %fp + -888 ]
0x12038    f8 23 a0 5c    st  %i4, [ %sp + 0x5c ]
0x1203C    90 10 00 17    mov  %l7, %o0
0x12040    13 21 84 00    sethi  %hi(0x86100000), %o1            ! Build high part of constant/address.
0x12044    94 10 20 00    clr  %o2
0x12048    96 10 20 00    clr  %o3
0x1204C    98 10 00 15    mov  %l5, %o4
0x12050    7f ff fd a7    call  0x116ec                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12054    9a 10 20 06    mov  6, %o5
0x12058    80 a2 20 00    cmp  %o0, 0
0x1205C    02 80 00 06    be  0x12074                            ! Conditional/control branch; inspect delay slot.
0x12060    90 10 20 00    clr  %o0
0x12064    7f ff f6 a4    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12068    92 10 20 08    mov  8, %o1
0x1206C    10 80 00 b2    b  0x12334                             ! Conditional/control branch; inspect delay slot.
0x12070    b0 10 20 01    mov  1, %i0
0x12074    d0 0f bc 87    ldub  [ %fp + -889 ], %o0
0x12078    80 a2 20 00    cmp  %o0, 0
0x1207C    02 80 00 06    be  0x12094                            ! Conditional/control branch; inspect delay slot.
0x12080    90 10 20 00    clr  %o0
0x12084    7f ff f6 9c    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12088    92 10 20 08    mov  8, %o1
0x1208C    10 bf fe 5d    b  0x11a00                             ! Conditional/control branch; inspect delay slot.
0x12090    d2 07 bc 6c    ld  [ %fp + -916 ], %o1
0x12094    90 10 00 17    mov  %l7, %o0
0x12098    13 20 00 04    sethi  %hi(0x80001000), %o1            ! Build high part of constant/address.
0x1209C    94 10 20 00    clr  %o2
0x120A0    7f ff fd 18    call  0x11500                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x120A4    96 10 20 01    mov  1, %o3
0x120A8    80 a2 20 00    cmp  %o0, 0
0x120AC    12 80 00 a2    bne  0x12334                           ! Conditional/control branch; inspect delay slot.
0x120B0    b0 10 20 01    mov  1, %i0
0x120B4    d0 0d a1 fe    ldub  [ %l6 + 0x1fe ], %o0
0x120B8    80 a2 20 55    cmp  %o0, 0x55
0x120BC    12 80 00 24    bne  0x1214c                           ! Conditional/control branch; inspect delay slot.
0x120C0    90 10 20 20    mov  0x20, %o0
0x120C4    d0 0d a1 ff    ldub  [ %l6 + 0x1ff ], %o0
0x120C8    80 a2 20 aa    cmp  %o0, 0xaa
0x120CC    12 80 00 20    bne  0x1214c                           ! Conditional/control branch; inspect delay slot.
0x120D0    90 10 20 20    mov  0x20, %o0
0x120D4    d0 0d a1 be    ldub  [ %l6 + 0x1be ], %o0
0x120D8    80 a2 20 80    cmp  %o0, 0x80
0x120DC    02 80 00 04    be  0x120ec                            ! Conditional/control branch; inspect delay slot.
0x120E0    80 a2 20 00    cmp  %o0, 0
0x120E4    12 80 00 1a    bne  0x1214c                           ! Conditional/control branch; inspect delay slot.
0x120E8    90 10 20 20    mov  0x20, %o0
0x120EC    d2 0d a1 c9    ldub  [ %l6 + 0x1c9 ], %o1
0x120F0    96 10 20 20    mov  0x20, %o3
0x120F4    d0 0d a1 c8    ldub  [ %l6 + 0x1c8 ], %o0
0x120F8    93 2a 60 18    sll  %o1, 0x18, %o1
0x120FC    d4 0d a1 c7    ldub  [ %l6 + 0x1c7 ], %o2
0x12100    91 2a 20 10    sll  %o0, 0x10, %o0
0x12104    92 12 40 08    or  %o1, %o0, %o1
0x12108    d0 0d a1 c6    ldub  [ %l6 + 0x1c6 ], %o0
0x1210C    95 2a a0 08    sll  %o2, 8, %o2
0x12110    92 12 40 0a    or  %o1, %o2, %o1
0x12114    90 12 00 09    or  %o0, %o1, %o0
0x12118    d0 27 bf e8    st  %o0, [ %fp + -24 ]
0x1211C    d6 27 bf ec    st  %o3, [ %fp + -20 ]
0x12120    c0 27 bf f0    clr  [ %fp + -16 ]
0x12124    10 80 00 0d    b  0x12158                             ! Conditional/control branch; inspect delay slot.
0x12128    a4 10 20 03    mov  3, %l2
0x1212C    f0 06 00 10    ld  [ %i0 + %l0 ], %i0
0x12130    10 80 00 35    b  0x12204                             ! Conditional/control branch; inspect delay slot.
0x12134    f0 27 bc 70    st  %i0, [ %fp + -912 ]
0x12138    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x1213C    90 10 20 01    mov  1, %o0
0x12140    e6 27 bc 70    st  %l3, [ %fp + -912 ]
0x12144    10 80 00 30    b  0x12204                             ! Conditional/control branch; inspect delay slot.
0x12148    d0 22 63 28    st  %o0, [ %o1 + 0x328 ]
0x1214C    d0 27 bf e8    st  %o0, [ %fp + -24 ]
0x12150    c0 27 bf ec    clr  [ %fp + -20 ]
0x12154    a4 10 20 02    mov  2, %l2
0x12158    a2 10 20 00    clr  %l1
0x1215C    80 a4 40 12    cmp  %l1, %l2
0x12160    1a 80 00 2a    bcc  0x12208                           ! Conditional/control branch; inspect delay slot.
0x12164    b0 07 bf e8    add  %fp, -24, %i0
0x12168    a6 10 00 18    mov  %i0, %l3
0x1216C    a0 10 20 00    clr  %l0
0x12170    d4 06 00 10    ld  [ %i0 + %l0 ], %o2
0x12174    90 10 00 17    mov  %l7, %o0
0x12178    13 20 00 04    sethi  %hi(0x80001000), %o1            ! Build high part of constant/address.
0x1217C    7f ff fc e1    call  0x11500                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12180    96 10 20 01    mov  1, %o3
0x12184    80 a2 20 00    cmp  %o0, 0
0x12188    32 80 00 6b    bne,a   0x12334                        ! Conditional/control branch; inspect delay slot.
0x1218C    b0 10 20 01    mov  1, %i0
0x12190    d0 0d 80 00    ldub  [ %l6 ], %o0
0x12194    80 a2 20 76    cmp  %o0, 0x76
0x12198    12 80 00 06    bne  0x121b0                           ! Conditional/control branch; inspect delay slot.
0x1219C    11 20 00 04    sethi  %hi(0x80001000), %o0            ! Build high part of constant/address.
0x121A0    d0 0d a0 01    ldub  [ %l6 + 1 ], %o0
0x121A4    80 a2 20 6d    cmp  %o0, 0x6d
0x121A8    02 bf ff e1    be  0x1212c                            ! Conditional/control branch; inspect delay slot.
0x121AC    11 20 00 04    sethi  %hi(0x80001000), %o0            ! Build high part of constant/address.
0x121B0    92 10 00 08    mov  %o0, %o1
0x121B4    7f ff e8 85    call  0xc3c8                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x121B8    94 10 22 00    mov  0x200, %o2
0x121BC    80 a2 20 00    cmp  %o0, 0
0x121C0    36 80 00 06    bge,a   0x121d8                        ! Conditional/control branch; inspect delay slot.
0x121C4    d0 0d 80 00    ldub  [ %l6 ], %o0
0x121C8    90 10 20 01    mov  1, %o0
0x121CC    7f ff f6 4a    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x121D0    92 10 20 07    mov  7, %o1
0x121D4    d0 0d 80 00    ldub  [ %l6 ], %o0
0x121D8    80 a2 20 76    cmp  %o0, 0x76
0x121DC    32 80 00 07    bne,a   0x121f8                        ! Conditional/control branch; inspect delay slot.
0x121E0    a2 04 60 01    inc  %l1
0x121E4    d0 0d a0 01    ldub  [ %l6 + 1 ], %o0
0x121E8    80 a2 20 6d    cmp  %o0, 0x6d
0x121EC    22 bf ff d3    be,a   0x12138                         ! Conditional/control branch; inspect delay slot.
0x121F0    e6 04 c0 10    ld  [ %l3 + %l0 ], %l3
0x121F4    a2 04 60 01    inc  %l1
0x121F8    80 a4 40 12    cmp  %l1, %l2
0x121FC    0a bf ff dd    bcs  0x12170                           ! Conditional/control branch; inspect delay slot.
0x12200    a0 04 20 04    add  %l0, 4, %l0
0x12204    80 a4 40 12    cmp  %l1, %l2
0x12208    32 80 00 06    bne,a   0x12220                        ! Conditional/control branch; inspect delay slot.
0x1220C    13 21 e0 db    sethi  %hi(0x87836c00), %o1            ! Build high part of constant/address.
0x12210    90 10 20 01    mov  1, %o0
0x12214    7f ff f6 38    call  0xfaf4                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12218    92 10 20 05    mov  5, %o1
0x1221C    13 21 e0 db    sethi  %hi(0x87836c00), %o1            ! Build high part of constant/address.
0x12220    94 07 bc 80    add  %fp, -896, %o2
0x12224    96 07 bc 7c    add  %fp, -900, %o3
0x12228    92 12 63 98    or  %o1, 0x398, %o1
0x1222C    7f ff eb 93    call  0xd078                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12230    11 20 00 04    sethi  %hi(0x80001000), %o0            ! Build high part of constant/address.
0x12234    13 21 e0 db    sethi  %hi(0x87836c00), %o1            ! Build high part of constant/address.
0x12238    94 07 bc 78    add  %fp, -904, %o2
0x1223C    96 07 bc 74    add  %fp, -908, %o3
0x12240    92 12 63 a8    or  %o1, 0x3a8, %o1
0x12244    7f ff eb 8d    call  0xd078                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12248    90 05 80 08    add  %l6, %o0, %o0
0x1224C    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x12250    7f ff f2 02    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12254    90 12 23 b8    or  %o0, 0x3b8, %o0                    ! 0x87836fb8
0x12258    d0 07 bc 70    ld  [ %fp + -912 ], %o0
0x1225C    13 20 00 10    sethi  %hi(0x80004000), %o1            ! Build high part of constant/address.
0x12260    d4 07 bc 80    ld  [ %fp + -896 ], %o2
0x12264    98 10 20 00    clr  %o4
0x12268    d6 07 bc 7c    ld  [ %fp + -900 ], %o3
0x1226C    94 02 80 08    add  %o2, %o0, %o2
0x12270    7f ff fd 90    call  0x118b0                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12274    90 10 00 17    mov  %l7, %o0
0x12278    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x1227C    7f ff f1 f7    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12280    90 12 23 d0    or  %o0, 0x3d0, %o0                    ! 0x87836fd0
0x12284    d2 07 bc 70    ld  [ %fp + -912 ], %o1
0x12288    90 10 00 17    mov  %l7, %o0
0x1228C    d4 07 bc 78    ld  [ %fp + -904 ], %o2
0x12290    98 10 20 01    mov  1, %o4
0x12294    94 02 80 09    add  %o2, %o1, %o2
0x12298    d6 07 bc 74    ld  [ %fp + -908 ], %o3
0x1229C    7f ff fd 85    call  0x118b0                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x122A0    13 20 40 00    sethi  %hi(0x81000000), %o1            ! Build high part of constant/address.
0x122A4    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x122A8    7f ff f1 ec    call  0xea58                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x122AC    90 12 23 e8    or  %o0, 0x3e8, %o0                    ! 0x87836fe8
0x122B0    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x122B4    92 12 61 fc    or  %o1, 0x1fc, %o1                    ! 0x878371fc
0x122B8    15 08 00 00    sethi  %hi(0x20000000), %o2            ! Build high part of constant/address.
0x122BC    11 00 00 3f    sethi  %hi(0xfc00), %o0                ! Build high part of constant/address.
0x122C0    a8 12 a0 1c    or  %o2, 0x1c, %l4
0x122C4    a6 12 23 fa    or  %o0, 0x3fa, %l3
0x122C8    a4 12 a0 04    or  %o2, 4, %l2
0x122CC    b0 10 00 09    mov  %o1, %i0
0x122D0    a2 10 20 00    clr  %l1
0x122D4    a0 02 60 04    add  %o1, 4, %l0
0x122D8    7f ff fa 6a    call  0x10c80                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x122DC    90 10 00 18    mov  %i0, %o0
0x122E0    94 10 00 11    mov  %l1, %o2
0x122E4    92 10 20 17    mov  0x17, %o1
0x122E8    96 10 20 04    mov  4, %o3
0x122EC    7f ff f9 a5    call  0x10980                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x122F0    90 10 20 00    clr  %o0
0x122F4    98 0a 00 13    and  %o0, %l3, %o4
0x122F8    94 10 00 11    mov  %l1, %o2
0x122FC    90 10 20 00    clr  %o0
0x12300    92 10 20 17    mov  0x17, %o1
0x12304    7f ff f9 e3    call  0x10a90                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12308    96 10 20 04    mov  4, %o3
0x1230C    d0 04 00 00    ld  [ %l0 ], %o0
0x12310    a2 04 60 01    inc  %l1
0x12314    d0 24 80 00    st  %o0, [ %l2 ]
0x12318    d2 04 00 00    ld  [ %l0 ], %o1
0x1231C    b0 06 20 94    add  %i0, 0x94, %i0
0x12320    d2 25 00 00    st  %o1, [ %l4 ]
0x12324    80 a4 60 01    cmp  %l1, 1
0x12328    04 bf ff ec    ble  0x122d8                           ! Conditional/control branch; inspect delay slot.
0x1232C    a0 04 20 94    add  %l0, 0x94, %l0
0x12330    b0 10 20 00    clr  %i0
0x12334    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x12338    81 e8 00 00    restore                                ! Restore previous register window.
0x1233C    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x12340    80 a6 20 02    cmp  %i0, 2
0x12344    12 80 00 2d    bne  0x123f8                           ! Conditional/control branch; inspect delay slot.
0x12348    25 21 e0 dc    sethi  %hi(0x87837000), %l2            ! Build high part of constant/address.
0x1234C    15 00 00 21    sethi  %hi(0x8400), %o2                ! Build high part of constant/address.
0x12350    92 10 20 80    mov  0x80, %o1
0x12354    94 12 a3 07    or  %o2, 0x307, %o2
0x12358    40 00 00 66    call  0x124f0                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1235C    90 10 20 00    clr  %o0
0x12360    d2 0c a3 2d    ldub  [ %l2 + 0x32d ], %o1
0x12364    a0 10 20 00    clr  %l0
0x12368    80 a4 00 09    cmp  %l0, %o1
0x1236C    36 80 00 14    bge,a   0x123bc                        ! Conditional/control branch; inspect delay slot.
0x12370    e0 0c a3 2d    ldub  [ %l2 + 0x32d ], %l0
0x12374    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x12378    a2 12 23 b8    or  %o0, 0x3b8, %l1                    ! 0x878373b8
0x1237C    d2 0c 40 10    ldub  [ %l1 + %l0 ], %o1
0x12380    90 10 20 01    mov  1, %o0
0x12384    40 00 00 3e    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12388    93 32 60 04    srl  %o1, 4, %o1
0x1238C    d2 0c 40 10    ldub  [ %l1 + %l0 ], %o1
0x12390    90 10 20 01    mov  1, %o0
0x12394    40 00 00 3a    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12398    92 0a 60 0f    and  %o1, 0xf, %o1
0x1239C    6a 1f 28 19    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x123A0    90 10 20 50    mov  0x50, %o0
0x123A4    d0 0c a3 2d    ldub  [ %l2 + 0x32d ], %o0
0x123A8    a0 04 20 01    inc  %l0
0x123AC    80 a4 00 08    cmp  %l0, %o0
0x123B0    26 bf ff f4    bl,a   0x12380
0x123B4    d2 0c 40 10    ldub  [ %l1 + %l0 ], %o1
0x123B8    e0 0c a3 2d    ldub  [ %l2 + 0x32d ], %l0
0x123BC    80 a4 20 0f    cmp  %l0, 0xf
0x123C0    14 80 00 0f    bg  0x123fc                            ! Conditional/control branch; inspect delay slot.
0x123C4    80 a6 20 00    cmp  %i0, 0
0x123C8    92 10 20 02    mov  2, %o1
0x123CC    40 00 00 2c    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x123D0    90 10 20 01    mov  1, %o0
0x123D4    92 10 20 00    clr  %o1
0x123D8    40 00 00 29    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x123DC    90 10 20 01    mov  1, %o0
0x123E0    6a 1f 28 08    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x123E4    90 10 20 50    mov  0x50, %o0
0x123E8    a0 04 20 01    inc  %l0
0x123EC    80 a4 20 0f    cmp  %l0, 0xf
0x123F0    04 bf ff f7    ble  0x123cc                           ! Conditional/control branch; inspect delay slot.
0x123F4    92 10 20 02    mov  2, %o1
0x123F8    80 a6 20 00    cmp  %i0, 0
0x123FC    02 80 00 03    be  0x12408                            ! Conditional/control branch; inspect delay slot.
0x12400    92 10 20 80    mov  0x80, %o1
0x12404    92 10 20 c0    mov  0xc0, %o1
0x12408    15 00 00 21    sethi  %hi(0x8400), %o2                ! Build high part of constant/address.
0x1240C    94 12 a3 07    or  %o2, 0x307, %o2                    ! 0x8707
0x12410    40 00 00 38    call  0x124f0                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12414    90 10 20 00    clr  %o0
0x12418    a0 10 20 0f    mov  0xf, %l0
0x1241C    92 10 20 02    mov  2, %o1
0x12420    40 00 00 17    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12424    90 10 20 01    mov  1, %o0
0x12428    92 10 20 00    clr  %o1
0x1242C    40 00 00 14    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12430    90 10 20 01    mov  1, %o0
0x12434    6a 1f 27 f3    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12438    90 10 20 50    mov  0x50, %o0
0x1243C    a0 84 3f ff    addcc  %l0, -1, %l0
0x12440    1c bf ff f8    bpos  0x12420                          ! Conditional/control branch; inspect delay slot.
0x12444    92 10 20 02    mov  2, %o1
0x12448    80 a6 20 00    cmp  %i0, 0
0x1244C    02 80 00 03    be  0x12458                            ! Conditional/control branch; inspect delay slot.
0x12450    92 10 20 80    mov  0x80, %o1
0x12454    92 10 20 c0    mov  0xc0, %o1
0x12458    94 10 20 50    mov  0x50, %o2
0x1245C    40 00 00 25    call  0x124f0                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12460    90 10 20 00    clr  %o0
0x12464    11 00 00 16    sethi  %hi(0x5800), %o0                ! Build high part of constant/address.
0x12468    6a 1f 27 e6    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1246C    90 12 23 a0    or  %o0, 0x3a0, %o0                    ! 0x5ba0
0x12470    c0 2c a3 2d    clrb  [ %l2 + 0x32d ]
0x12474    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x12478    81 e8 00 00    restore                                ! Restore previous register window.
0x1247C    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x12480    b2 0e 60 0f    and  %i1, 0xf, %i1
0x12484    80 a6 20 00    cmp  %i0, 0
0x12488    02 80 00 03    be  0x12494                            ! Conditional/control branch; inspect delay slot.
0x1248C    b3 2e 60 04    sll  %i1, 4, %i1
0x12490    b2 16 60 02    or  %i1, 2, %i1
0x12494    23 21 e0 dc    sethi  %hi(0x87837000), %l1            ! Build high part of constant/address.
0x12498    25 00 40 00    sethi  %hi(0x1000000), %l2             ! Build high part of constant/address.
0x1249C    a1 2e 60 10    sll  %i1, 0x10, %l0
0x124A0    a0 14 00 12    or  %l0, %l2, %l0
0x124A4    d0 0c 63 b1    ldub  [ %l1 + 0x3b1 ], %o0
0x124A8    92 10 00 10    mov  %l0, %o1
0x124AC    94 10 20 00    clr  %o2
0x124B0    7f ff e9 ee    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x124B4    96 10 20 02    mov  2, %o3
0x124B8    92 16 60 08    or  %i1, 8, %o1
0x124BC    93 2a 60 10    sll  %o1, 0x10, %o1
0x124C0    d0 0c 63 b1    ldub  [ %l1 + 0x3b1 ], %o0
0x124C4    92 12 40 12    or  %o1, %l2, %o1
0x124C8    94 10 20 00    clr  %o2
0x124CC    7f ff e9 e7    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x124D0    96 10 20 02    mov  2, %o3
0x124D4    d0 0c 63 b1    ldub  [ %l1 + 0x3b1 ], %o0
0x124D8    92 10 00 10    mov  %l0, %o1
0x124DC    94 10 20 00    clr  %o2
0x124E0    7f ff e9 e2    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x124E4    96 10 20 02    mov  2, %o3
0x124E8    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x124EC    81 e8 00 00    restore                                ! Restore previous register window.
0x124F0    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x124F4    93 3e 60 04    sra  %i1, 4, %o1
0x124F8    90 10 00 18    mov  %i0, %o0
0x124FC    7f ff ff e0    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12500    92 0a 60 0f    and  %o1, 0xf, %o1
0x12504    90 10 00 18    mov  %i0, %o0
0x12508    7f ff ff dd    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1250C    92 0e 60 0f    and  %i1, 0xf, %o1
0x12510    6a 1f 27 bc    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12514    90 10 00 1a    mov  %i2, %o0
0x12518    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x1251C    81 e8 00 00    restore                                ! Restore previous register window.
0x12520    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x12524    d2 0e 00 00    ldub  [ %i0 ], %o1
0x12528    80 a2 60 00    cmp  %o1, 0
0x1252C    02 80 00 2f    be  0x125e8                            ! Conditional/control branch; inspect delay slot.
0x12530    11 00 00 16    sethi  %hi(0x5800), %o0                ! Build high part of constant/address.
0x12534    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x12538    a0 12 23 b8    or  %o0, 0x3b8, %l0                    ! 0x878373b8
0x1253C    92 0a 60 ff    and  %o1, 0xff, %o1
0x12540    80 a2 60 0a    cmp  %o1, 0xa
0x12544    12 80 00 06    bne  0x1255c                           ! Conditional/control branch; inspect delay slot.
0x12548    80 a2 60 09    cmp  %o1, 9
0x1254C    7f ff ff 7c    call  0x1233c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12550    90 10 20 02    mov  2, %o0
0x12554    10 80 00 20    b  0x125d4                             ! Conditional/control branch; inspect delay slot.
0x12558    b0 06 20 01    inc  %i0
0x1255C    12 80 00 06    bne  0x12574                           ! Conditional/control branch; inspect delay slot.
0x12560    80 a2 60 08    cmp  %o1, 8
0x12564    7f ff ff 76    call  0x1233c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12568    90 10 20 01    mov  1, %o0
0x1256C    10 80 00 1a    b  0x125d4                             ! Conditional/control branch; inspect delay slot.
0x12570    b0 06 20 01    inc  %i0
0x12574    12 80 00 06    bne  0x1258c                           ! Conditional/control branch; inspect delay slot.
0x12578    93 32 60 04    srl  %o1, 4, %o1
0x1257C    7f ff ff 70    call  0x1233c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12580    90 10 20 00    clr  %o0
0x12584    10 80 00 14    b  0x125d4                             ! Conditional/control branch; inspect delay slot.
0x12588    b0 06 20 01    inc  %i0
0x1258C    7f ff ff bc    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12590    90 10 20 01    mov  1, %o0
0x12594    d2 0e 00 00    ldub  [ %i0 ], %o1
0x12598    90 10 20 01    mov  1, %o0
0x1259C    7f ff ff b8    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x125A0    92 0a 60 0f    and  %o1, 0xf, %o1
0x125A4    17 21 e0 dc    sethi  %hi(0x87837000), %o3            ! Build high part of constant/address.
0x125A8    d4 0a e3 2d    ldub  [ %o3 + 0x32d ], %o2             ! 0x8783732d
0x125AC    d2 0e 00 00    ldub  [ %i0 ], %o1
0x125B0    90 0a a0 ff    and  %o2, 0xff, %o0
0x125B4    80 a2 20 0f    cmp  %o0, 0xf
0x125B8    18 80 00 04    bgu  0x125c8                           ! Conditional/control branch; inspect delay slot.
0x125BC    d2 2c 00 08    stb  %o1, [ %l0 + %o0 ]
0x125C0    90 02 a0 01    add  %o2, 1, %o0
0x125C4    d0 2a e3 2d    stb  %o0, [ %o3 + 0x32d ]
0x125C8    6a 1f 27 8e    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x125CC    90 10 20 50    mov  0x50, %o0
0x125D0    b0 06 20 01    inc  %i0
0x125D4    d2 0e 00 00    ldub  [ %i0 ], %o1
0x125D8    80 a2 60 00    cmp  %o1, 0
0x125DC    12 bf ff d9    bne  0x12540                           ! Conditional/control branch; inspect delay slot.
0x125E0    92 0a 60 ff    and  %o1, 0xff, %o1
0x125E4    11 00 00 16    sethi  %hi(0x5800), %o0                ! Build high part of constant/address.
0x125E8    6a 1f 27 86    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x125EC    90 12 23 a0    or  %o0, 0x3a0, %o0                    ! 0x5ba0
0x125F0    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x125F4    81 e8 00 00    restore                                ! Restore previous register window.
0x125F8    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x125FC    92 10 20 64    mov  0x64, %o1
0x12600    7f ff e9 ff    call  0xcdfc                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12604    90 0e 20 ff    and  %i0, 0xff, %o0
0x12608    a2 10 00 08    mov  %o0, %l1
0x1260C    92 0c 60 ff    and  %l1, 0xff, %o1
0x12610    91 2a 60 01    sll  %o1, 1, %o0
0x12614    90 02 00 09    add  %o0, %o1, %o0
0x12618    91 2a 20 03    sll  %o0, 3, %o0
0x1261C    90 02 00 09    add  %o0, %o1, %o0
0x12620    91 2a 20 02    sll  %o0, 2, %o0
0x12624    b0 26 00 08    sub  %i0, %o0, %i0
0x12628    92 10 20 0a    mov  0xa, %o1
0x1262C    7f ff e9 f4    call  0xcdfc                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12630    90 0e 20 ff    and  %i0, 0xff, %o0
0x12634    a0 10 00 08    mov  %o0, %l0
0x12638    92 0c 20 ff    and  %l0, 0xff, %o1
0x1263C    91 2a 60 02    sll  %o1, 2, %o0
0x12640    90 02 00 09    add  %o0, %o1, %o0
0x12644    91 2a 20 01    sll  %o0, 1, %o0
0x12648    a2 04 60 30    add  %l1, 0x30, %l1
0x1264C    b0 26 00 08    sub  %i0, %o0, %i0
0x12650    92 0c 60 ff    and  %l1, 0xff, %o1
0x12654    a0 04 20 30    add  %l0, 0x30, %l0
0x12658    b0 06 20 30    add  %i0, 0x30, %i0
0x1265C    93 32 60 04    srl  %o1, 4, %o1
0x12660    7f ff ff 87    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12664    90 10 20 01    mov  1, %o0
0x12668    92 0c 60 0f    and  %l1, 0xf, %o1
0x1266C    7f ff ff 84    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12670    90 10 20 01    mov  1, %o0
0x12674    6a 1f 27 63    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12678    90 10 20 50    mov  0x50, %o0
0x1267C    92 10 00 10    mov  %l0, %o1
0x12680    92 0a 60 ff    and  %o1, 0xff, %o1
0x12684    93 32 60 04    srl  %o1, 4, %o1
0x12688    7f ff ff 7d    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1268C    90 10 20 01    mov  1, %o0
0x12690    92 0c 20 0f    and  %l0, 0xf, %o1
0x12694    7f ff ff 7a    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12698    90 10 20 01    mov  1, %o0
0x1269C    6a 1f 27 59    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x126A0    90 10 20 50    mov  0x50, %o0
0x126A4    92 10 00 18    mov  %i0, %o1
0x126A8    92 0a 60 ff    and  %o1, 0xff, %o1
0x126AC    93 32 60 04    srl  %o1, 4, %o1
0x126B0    7f ff ff 73    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x126B4    90 10 20 01    mov  1, %o0
0x126B8    90 10 20 01    mov  1, %o0
0x126BC    7f ff ff 70    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x126C0    92 0e 20 0f    and  %i0, 0xf, %o1
0x126C4    6a 1f 27 4f    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x126C8    90 10 20 50    mov  0x50, %o0
0x126CC    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x126D0    81 e8 00 00    restore                                ! Restore previous register window.
0x126D4    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x126D8    7f ff e9 8d    call  0xcd0c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x126DC    90 10 20 1f    mov  0x1f, %o0
0x126E0    80 a2 20 00    cmp  %o0, 0
0x126E4    02 80 00 04    be  0x126f4                            ! Conditional/control branch; inspect delay slot.
0x126E8    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x126EC    10 80 00 0a    b  0x12714                             ! Conditional/control branch; inspect delay slot.
0x126F0    90 10 20 1f    mov  0x1f, %o0
0x126F4    7f ff e9 86    call  0xcd0c                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x126F8    90 10 20 1b    mov  0x1b, %o0
0x126FC    80 a2 20 00    cmp  %o0, 0
0x12700    12 80 00 04    bne  0x12710                           ! Conditional/control branch; inspect delay slot.
0x12704    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x12708    10 80 00 4d    b  0x1283c                             ! Conditional/control branch; inspect delay slot.
0x1270C    b0 10 20 00    clr  %i0
0x12710    90 10 20 1b    mov  0x1b, %o0
0x12714    d0 2a 63 b1    stb  %o0, [ %o1 + 0x3b1 ]
0x12718    a0 10 00 09    mov  %o1, %l0
0x1271C    d0 0c 23 b1    ldub  [ %l0 + 0x3b1 ], %o0
0x12720    13 00 c0 00    sethi  %hi(0x3000000), %o1             ! Build high part of constant/address.
0x12724    94 10 20 00    clr  %o2
0x12728    7f ff e9 50    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1272C    96 10 20 02    mov  2, %o3
0x12730    d0 0c 23 b1    ldub  [ %l0 + 0x3b1 ], %o0
0x12734    13 02 cf 00    sethi  %hi(0xb3c0000), %o1             ! Build high part of constant/address.
0x12738    94 10 20 00    clr  %o2
0x1273C    7f ff e9 4b    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12740    96 10 20 02    mov  2, %o3
0x12744    d0 0c 23 b1    ldub  [ %l0 + 0x3b1 ], %o0
0x12748    13 00 80 00    sethi  %hi(0x2000000), %o1             ! Build high part of constant/address.
0x1274C    94 10 20 00    clr  %o2
0x12750    7f ff e9 46    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12754    96 10 20 02    mov  2, %o3
0x12758    d0 0c 23 b1    ldub  [ %l0 + 0x3b1 ], %o0
0x1275C    13 02 80 00    sethi  %hi(0xa000000), %o1             ! Build high part of constant/address.
0x12760    94 10 20 00    clr  %o2
0x12764    7f ff e9 41    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12768    96 10 20 02    mov  2, %o3
0x1276C    d0 0c 23 b1    ldub  [ %l0 + 0x3b1 ], %o0
0x12770    13 01 00 00    sethi  %hi(0x4000000), %o1             ! Build high part of constant/address.
0x12774    94 10 20 00    clr  %o2
0x12778    7f ff e9 3c    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1277C    96 10 20 02    mov  2, %o3
0x12780    d0 0c 23 b1    ldub  [ %l0 + 0x3b1 ], %o0
0x12784    96 10 20 02    mov  2, %o3
0x12788    94 10 20 00    clr  %o2
0x1278C    7f ff e9 37    call  0xcc68                           ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12790    13 03 00 00    sethi  %hi(0xc000000), %o1             ! Build high part of constant/address.
0x12794    92 10 20 03    mov  3, %o1
0x12798    7f ff ff 39    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1279C    90 10 20 00    clr  %o0
0x127A0    21 00 00 04    sethi  %hi(0x1000), %l0                ! Build high part of constant/address.
0x127A4    6a 1f 27 17    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x127A8    90 14 20 04    or  %l0, 4, %o0                        ! 0x1004
0x127AC    92 10 20 03    mov  3, %o1
0x127B0    7f ff ff 33    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x127B4    90 10 20 00    clr  %o0
0x127B8    6a 1f 27 12    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x127BC    90 10 20 64    mov  0x64, %o0
0x127C0    92 10 20 03    mov  3, %o1
0x127C4    7f ff ff 2e    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x127C8    90 10 20 00    clr  %o0
0x127CC    6a 1f 27 0d    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x127D0    90 14 20 04    or  %l0, 4, %o0
0x127D4    92 10 20 02    mov  2, %o1
0x127D8    7f ff ff 29    call  0x1247c                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x127DC    90 10 20 00    clr  %o0
0x127E0    6a 1f 27 08    call  0xa87dc400                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x127E4    90 10 20 64    mov  0x64, %o0
0x127E8    90 10 20 00    clr  %o0
0x127EC    92 10 20 2c    mov  0x2c, %o1
0x127F0    7f ff ff 40    call  0x124f0                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x127F4    94 10 20 50    mov  0x50, %o2
0x127F8    90 10 20 00    clr  %o0
0x127FC    92 10 20 08    mov  8, %o1

! ============================================================================
! 0x12800: Boundary review: subsequent bytes increasingly resemble non-code or embedded binary data.
! ============================================================================
0x12800    7f ff ff 3c    call  0x124f0                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12804    94 10 20 50    mov  0x50, %o2
0x12808    90 10 20 00    clr  %o0
0x1280C    92 10 20 01    mov  1, %o1
0x12810    7f ff ff 38    call  0x124f0                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12814    94 10 26 90    mov  0x690, %o2
0x12818    90 10 20 00    clr  %o0
0x1281C    92 10 20 06    mov  6, %o1
0x12820    7f ff ff 34    call  0x124f0                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12824    94 10 20 50    mov  0x50, %o2
0x12828    90 10 20 00    clr  %o0
0x1282C    92 10 20 0c    mov  0xc, %o1
0x12830    7f ff ff 30    call  0x124f0                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12834    94 10 20 50    mov  0x50, %o2
0x12838    b0 10 20 01    mov  1, %i0
0x1283C    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x12840    81 e8 00 00    restore                                ! Restore previous register window.
0x12844    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12848    45 43 43 20    call  0x150e34c8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1284C    4f 4e 0a 00    call  0x3d39504c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12850    45 43 43 20    call  0x150e34d0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12854    4f 46 46 0a    call  0x3d1a407c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12858    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x1285C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12860    76 6d 6c 69    call  0xd9b6da04                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12864    6e 75 78 2e    call  0xb9d7091c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12868    62 69 6e 00    call  0x89a6e068                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1286C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12870    69 6e 69 74    call  0xa5bace40                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12874    72 64 2e 69    call  0xc991e218                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12878    6d 67 00 00    call  0xb59d2878                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1287C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12880    4c 64 6b 0a    call  0x3192d4a8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12884    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12888    2e 00 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x1288C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12890    4c 64 69 0a    call  0x3192ccb8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12894    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12898    00 55 56 03    unknown                                ! Undecodable word; may be data or erased flash.
0x1289C    59 0c 0f 5a    call  0x64316604                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x128A0    5a 0f 0c 59    call  0x683d5a04                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x128A4    03 56 55 00    unknown                                ! Undecodable word; may be data or erased flash.
0x128A8    65 30 33 66    call  0x94c1f640                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x128AC    3c 69 6a 3f    unknown                                ! Undecodable word; may be data or erased flash.
0x128B0    3f 6a 69 3c    unknown                                ! Undecodable word; may be data or erased flash.
0x128B4    66 33 30 65    call  0x98cdea48                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x128B8    66 33 30 65    call  0x98cdea4c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x128BC    3f 6a 69 3c    unknown                                ! Undecodable word; may be data or erased flash.
0x128C0    3c 69 6a 3f    unknown                                ! Undecodable word; may be data or erased flash.
0x128C4    65 30 33 66    call  0x94c1f65c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x128C8    03 56 55 00    unknown                                ! Undecodable word; may be data or erased flash.
0x128CC    5a 0f 0c 59    call  0x683d5a30                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x128D0    59 0c 0f 5a    call  0x64316638                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x128D4    00 55 56 03    unknown                                ! Undecodable word; may be data or erased flash.
0x128D8    69 3c 3f 6a    call  0xa4f22680                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x128DC    30 65 66 33    unknown                                ! Undecodable word; may be data or erased flash.
0x128E0    33 66 65 30    unknown                                ! Undecodable word; may be data or erased flash.
0x128E4    6a 3f 3c 69    call  0xa8fe1a88                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x128E8    0c 59 5a 0f    unknown                                ! Undecodable word; may be data or erased flash.
0x128EC    55 00 03 56    call  0x54013644                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x128F0    56 03 00 55    call  0x580d2a44                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x128F4    0f 5a 59 0c    unknown                                ! Undecodable word; may be data or erased flash.
0x128F8    0f 5a 59 0c    unknown                                ! Undecodable word; may be data or erased flash.
0x128FC    56 03 00 55    call  0x580d2a50                       ! Call target; next instruction executes in delay slot. Verify target mapping.

! ============================================================================
! 0x12900: LIKELY DATA: anomalous branch/call targets; objdump is decoding arbitrary words as instructions.
! ============================================================================
0x12900    55 00 03 56    call  0x54013658                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12904    0c 59 5a 0f    unknown                                ! Undecodable word; may be data or erased flash.
0x12908    6a 3f 3c 69    call  0xa8fe1aac                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1290C    33 66 65 30    unknown                                ! Undecodable word; may be data or erased flash.
0x12910    30 65 66 33    unknown                                ! Undecodable word; may be data or erased flash.
0x12914    69 3c 3f 6a    call  0xa4f226bc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12918    6a 3f 3c 69    call  0xa8fe1abc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1291C    33 66 65 30    unknown                                ! Undecodable word; may be data or erased flash.
0x12920    30 65 66 33    unknown                                ! Undecodable word; may be data or erased flash.
0x12924    69 3c 3f 6a    call  0xa4f226cc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12928    0f 5a 59 0c    unknown                                ! Undecodable word; may be data or erased flash.
0x1292C    56 03 00 55    call  0x580d2a80                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12930    55 00 03 56    call  0x54013688                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12934    0c 59 5a 0f    unknown                                ! Undecodable word; may be data or erased flash.
0x12938    0c 59 5a 0f    unknown                                ! Undecodable word; may be data or erased flash.
0x1293C    55 00 03 56    call  0x54013694                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12940    56 03 00 55    call  0x580d2a94                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12944    0f 5a 59 0c    unknown                                ! Undecodable word; may be data or erased flash.
0x12948    69 3c 3f 6a    call  0xa4f226f0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1294C    30 65 66 33    unknown                                ! Undecodable word; may be data or erased flash.
0x12950    33 66 65 30    unknown                                ! Undecodable word; may be data or erased flash.
0x12954    6a 3f 3c 69    call  0xa8fe1af8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12958    03 56 55 00    unknown                                ! Undecodable word; may be data or erased flash.
0x1295C    5a 0f 0c 59    call  0x683d5ac0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12960    59 0c 0f 5a    call  0x643166c8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12964    00 55 56 03    unknown                                ! Undecodable word; may be data or erased flash.
0x12968    66 33 30 65    call  0x98cdeafc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1296C    3f 6a 69 3c    unknown                                ! Undecodable word; may be data or erased flash.
0x12970    3c 69 6a 3f    unknown                                ! Undecodable word; may be data or erased flash.
0x12974    65 30 33 66    call  0x94c1f70c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12978    65 30 33 66    call  0x94c1f710                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1297C    3c 69 6a 3f    unknown                                ! Undecodable word; may be data or erased flash.
0x12980    3f 6a 69 3c    unknown                                ! Undecodable word; may be data or erased flash.
0x12984    66 33 30 65    call  0x98cdeb18                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12988    00 55 56 03    unknown                                ! Undecodable word; may be data or erased flash.
0x1298C    59 0c 0f 5a    call  0x643166f4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12990    5a 0f 0c 59    call  0x683d5af4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12994    03 56 55 00    unknown                                ! Undecodable word; may be data or erased flash.
0x12998    43 20 00 00    call  0xc812998                        ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1299C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x129A0    20 45 43 43    unknown                                ! Undecodable word; may be data or erased flash.
0x129A4    20 00 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x129A8    0a 49 50 20    unknown                                ! Undecodable word; may be data or erased flash.
0x129AC    41 64 64 72    call  0x592bb74                        ! Call target; next instruction executes in delay slot. Verify target mapping.
0x129B0    65 73 73 3a    call  0x95cef698                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x129B4    0a 00 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x129B8    2e 00 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x129BC    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x129C0    0a 54 46 54    unknown                                ! Undecodable word; may be data or erased flash.
0x129C4    50 20 41 52    call  0x40822f0c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x129C8    50 20 45 52    call  0x40823f10                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x129CC    52 00 00 00    call  0x480129cc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x129D0    52 00 00 00    call  0x480129d0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x129D4    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x129D8    0a 46 69 6c    unknown                                ! Undecodable word; may be data or erased flash.
0x129DC    65 20 6e 6f    call  0x9482e398                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x129E0    74 20 66 6f    call  0xd082c39c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x129E4    75 6e 64 00    call  0xd5bab9e4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x129E8    44 00 00 00    call  0x100129e8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x129EC    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x129F0    0a 54 46 54    unknown                                ! Undecodable word; may be data or erased flash.
0x129F4    50 20 52 65    call  0x40827388                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x129F8    61 64 20 45    call  0x8591ab0c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x129FC    72 72 00 00    call  0xc9c929fc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A00    4d 08 08 08    call  0x34214a20                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A04    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12A08    0a 41 42 54    unknown                                ! Undecodable word; may be data or erased flash.
0x12A0C    0a 00 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x12A10    0a 54 46 54    unknown                                ! Undecodable word; may be data or erased flash.
0x12A14    50 20 41 62    call  0x40822f9c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A18    6f 72 74 65    call  0xbdcafbac                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A1C    64 00 00 00    call  0x90012a1c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A20    0a 4f 4b 0a    unknown                                ! Undecodable word; may be data or erased flash.
0x12A24    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12A28    0a 54 46 54    unknown                                ! Undecodable word; may be data or erased flash.
0x12A2C    50 20 4f 4b    call  0x40826758                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A30    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12A34    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12A38    09 08 52 65    sethi  %hi(0x21499400), %g4            ! Build high part of constant/address.
0x12A3C    73 65 74 20    call  0xcd96fabc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A40    53 77 69 74    call  0x4dded010                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A44    63 68 3a 00    call  0x8da21244                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A48    09 35 30 3a    sethi  %hi(0xd4c0e800), %g4            ! Build high part of constant/address.
0x12A4C    20 54 46 54    unknown                                ! Undecodable word; may be data or erased flash.
0x12A50    50 20 42 6f    call  0x4082340c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A54    6f 74 00 00    call  0xbdd12a54                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A58    09 33 30 3a    sethi  %hi(0xccc0e800), %g4            ! Build high part of constant/address.
0x12A5C    46 61 63 74    call  0x1986b82c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A60    6f 72 79 20    call  0xbdcb0ee0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A64    52 65 73 65    call  0x4996f7f8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A68    74 00 00 00    call  0xd0012a68                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A6C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12A70    09 35 3a 20    sethi  %hi(0xd4e88000), %g4            ! Build high part of constant/address.
0x12A74    4f 53 20 52    call  0x3d4dabbc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A78    65 69 6e 73    call  0x95a6e444                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A7C    74 61 6c 6c    call  0xd186dc2c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A80    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12A84    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12A88    09 08 41 55    sethi  %hi(0x21055400), %g4            ! Build high part of constant/address.
0x12A8C    58 20 53 77    call  0x60827868                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A90    69 74 63 68    call  0xa5d2b830                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12A94    3a 00 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x12A98    09 36 3a 20    sethi  %hi(0xd8e88000), %g4            ! Build high part of constant/address.
0x12A9C    55 73 65 72    call  0x55cec064                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12AA0    20 44 69 61    unknown                                ! Undecodable word; may be data or erased flash.
0x12AA4    67 00 00 00    call  0x9c012aa4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12AA8    09 31 3a 20    sethi  %hi(0xc4e88000), %g4            ! Build high part of constant/address.
0x12AAC    42 6f 6f 74    call  0x9bee87c                        ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12AB0    20 44 65 62    unknown                                ! Undecodable word; may be data or erased flash.
0x12AB4    75 67 00 00    call  0xd59d2ab4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12AB8    08 08 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x12ABC    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12AC0    09 08 50 6f    sethi  %hi(0x2141bc00), %g4            ! Build high part of constant/address.
0x12AC4    77 65 72 20    call  0xdd96f344                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12AC8    53 77 69 74    call  0x4dded098                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12ACC    63 68 3a 00    call  0x8da212cc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12AD0    09 35 3a 53    sethi  %hi(0xd4e94c00), %g4            ! Build high part of constant/address.
0x12AD4    6b 69 70 20    call  0xada6eb54                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12AD8    56 6f 6c 20    call  0x59bedb58                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12ADC    43 68 65 63    call  0xda2c068                        ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12AE0    6b 00 00 00    call  0xac012ae0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12AE4    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12AE8    09 31 30 3a    sethi  %hi(0xc4c0e800), %g4            ! Build high part of constant/address.
0x12AEC    20 54 46 54    unknown                                ! Undecodable word; may be data or erased flash.
0x12AF0    50 20 43 6f    call  0x408238ac                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12AF4    6e 66 00 00    call  0xb9992af4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12AF8    09 31 35 3a    sethi  %hi(0xc4d4e800), %g4            ! Build high part of constant/address.
0x12AFC    20 54 65 63    unknown                                ! Undecodable word; may be data or erased flash.
0x12B00    68 20 53 75    call  0xa08278d4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B04    70 70 6f 72    call  0xc1c2e8cc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B08    74 00 00 00    call  0xd0012b08                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B0C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12B10    09 32 30 3a    sethi  %hi(0xc8c0e800), %g4            ! Build high part of constant/address.
0x12B14    20 55 53 42    unknown                                ! Undecodable word; may be data or erased flash.
0x12B18    20 42 6f 6f    unknown                                ! Undecodable word; may be data or erased flash.
0x12B1C    74 00 00 00    call  0xd0012b1c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B20    09 32 35 3a    sethi  %hi(0xc8d4e800), %g4            ! Build high part of constant/address.
0x12B24    20 4d 65 6d    unknown                                ! Undecodable word; may be data or erased flash.
0x12B28    6f 72 79 20    call  0xbdcb0fa8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B2C    54 65 73 74    call  0x5196f8fc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B30    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12B34    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12B38    52 65 61 73    call  0x4996b104                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B3C    6f 6e 3a 00    call  0xbdba133c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B40    08 54 46 54    unknown                                ! Undecodable word; may be data or erased flash.
0x12B44    50 20 42 6f    call  0x40823500                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B48    6f 74 00 00    call  0xbdd12b48                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B4C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12B50    08 46 61 63    unknown                                ! Undecodable word; may be data or erased flash.
0x12B54    74 6f 72 79    call  0xd1bef538                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B58    20 44 65 66    unknown                                ! Undecodable word; may be data or erased flash.
0x12B5C    61 75 6c 74    call  0x85d6dd2c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B60    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12B64    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12B68    08 52 65 69    unknown                                ! Undecodable word; may be data or erased flash.
0x12B6C    6e 73 74 61    call  0xb9cefcf0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B70    6c 6c 69 6e    call  0xb1b2d128                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B74    67 20 46 57    call  0x9c8244d0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B78    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12B7C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12B80    08 53 63 68    unknown                                ! Undecodable word; may be data or erased flash.
0x12B84    65 64 75 6c    call  0x95930134                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B88    65 20 6f 6e    call  0x9482e940                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B8C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12B90    08 55 73 65    unknown                                ! Undecodable word; may be data or erased flash.
0x12B94    72 20 44 69    call  0xc8823d38                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B98    61 67 00 00    call  0x859d2b98                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12B9C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12BA0    08 42 6f 6f    unknown                                ! Undecodable word; may be data or erased flash.
0x12BA4    74 20 44 69    call  0xd0823d48                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12BA8    61 67 00 00    call  0x859d2ba8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12BAC    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12BB0    08 55 53 42    unknown                                ! Undecodable word; may be data or erased flash.
0x12BB4    20 42 6f 6f    unknown                                ! Undecodable word; may be data or erased flash.
0x12BB8    74 00 00 00    call  0xd0012bb8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12BBC    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12BC0    08 54 65 63    unknown                                ! Undecodable word; may be data or erased flash.
0x12BC4    68 20 53 75    call  0xa0827998                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12BC8    70 70 6f 72    call  0xc1c2e990                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12BCC    74 00 00 00    call  0xd0012bcc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12BD0    08 54 46 54    unknown                                ! Undecodable word; may be data or erased flash.
0x12BD4    50 20 43 6f    call  0x40823990                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12BD8    6e 66 00 00    call  0xb9992bd8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12BDC    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12BE0    08 53 6b 69    unknown                                ! Undecodable word; may be data or erased flash.
0x12BE4    70 20 56 6f    call  0xc08285a0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12BE8    6c 20 43 68    call  0xb0823988                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12BEC    65 63 6b 00    call  0x958ed7ec                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12BF0    08 54 46 54    unknown                                ! Undecodable word; may be data or erased flash.
0x12BF4    50 20 44 69    call  0x40823d98                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12BF8    61 67 31 00    call  0x859deff8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12BFC    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12C00    08 54 46 54    unknown                                ! Undecodable word; may be data or erased flash.
0x12C04    50 20 44 69    call  0x40823da8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12C08    61 67 00 00    call  0x859d2c08                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12C0C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12C10    09 08 42 6f    sethi  %hi(0x2109bc00), %g4            ! Build high part of constant/address.
0x12C14    6f 74 69 6e    call  0xbdd2d1cc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12C18    67 00 00 00    call  0x9c012c18                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12C1C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12C20    09 50 6c 65    unknown                                ! Undecodable word; may be data or erased flash.
0x12C24    61 73 65 20    call  0x85cec0a4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12C28    77 61 69 74    call  0xdd86d1f8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12C2C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12C30    30 78 38 30    unknown                                ! Undecodable word; may be data or erased flash.
0x12C34    30 30 34 30    unknown                                ! Undecodable word; may be data or erased flash.
0x12C38    30 30 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x12C3C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12C40    6b 65 72 6e    call  0xad96f5f8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12C44    65 6c 5f 69    call  0x95b2a9e8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12C48    6e 69 74 00    call  0xb9a6fc48                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12C4C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12C50    31 39 32 2e    sethi  %hi(0xe4c8b800), %i0            ! Build high part of constant/address.
0x12C54    31 36 38 2e    sethi  %hi(0xd8e0b800), %i0            ! Build high part of constant/address.
0x12C58    31 32 35 2e    sethi  %hi(0xc8d4b800), %i0            ! Build high part of constant/address.
0x12C5C    31 00 00 00    sethi  %hi(0), %i0                     ! Build high part of constant/address.
0x12C60    31 39 32 2e    sethi  %hi(0xe4c8b800), %i0            ! Build high part of constant/address.
0x12C64    31 36 38 2e    sethi  %hi(0xd8e0b800), %i0            ! Build high part of constant/address.
0x12C68    31 32 35 2e    sethi  %hi(0xc8d4b800), %i0            ! Build high part of constant/address.
0x12C6C    33 33 00 00    sethi  %hi(0xcc000000), %i1            ! Build high part of constant/address.
0x12C70    30 30 3a 30    unknown                                ! Undecodable word; may be data or erased flash.
0x12C74    64 3a 61 33    call  0x90eab140                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12C78    3a 30 31 3a    unknown                                ! Undecodable word; may be data or erased flash.
0x12C7C    30 33 3a 30    unknown                                ! Undecodable word; may be data or erased flash.
0x12C80    37 00 00 00    sethi  %hi(0), %i3                     ! Build high part of constant/address.
0x12C84    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12C88    74 66 74 70    call  0xd19afe48                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12C8C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12C90    30 78 38 31    unknown                                ! Undecodable word; may be data or erased flash.
0x12C94    30 30 30 30    unknown                                ! Undecodable word; may be data or erased flash.
0x12C98    30 30 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x12C9C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12CA0    69 6e 69 74    call  0xa5bad270                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CA4    72 64 5f 69    call  0xc992aa48                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CA8    6e 69 74 00    call  0xb9a6fca8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CAC    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12CB0    67 6f 00 00    call  0x9dbd2cb0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CB4    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12CB8    30 78 38 37    unknown                                ! Undecodable word; may be data or erased flash.
0x12CBC    38 33 30 30    unknown                                ! Undecodable word; may be data or erased flash.
0x12CC0    30 30 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x12CC4    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12CC8    6b 65 72 6e    call  0xad96f680                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CCC    65 6c 5f 74    call  0x95b2aa9c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CD0    65 73 74 00    call  0x95cefcd0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CD4    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12CD8    69 6e 69 74    call  0xa5bad2a8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CDC    72 64 5f 74    call  0xc992aaac                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CE0    65 73 74 00    call  0x95cefce0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CE4    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12CE8    6b 65 72 6e    call  0xad96f6a0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CEC    65 6c 5f 63    call  0x95b2aa78                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CF0    6f 6e 66 00    call  0xbdbac4f0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CF4    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12CF8    69 6e 69 74    call  0xa5bad2c8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12CFC    72 64 5f 63    call  0xc992aa88                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D00    6f 6e 66 00    call  0xbdbac500                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D04    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12D08    0a 54 46 54    unknown                                ! Undecodable word; may be data or erased flash.
0x12D0C    50 20 52 65    call  0x408276a0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D10    74 72 79 3a    call  0xd1cb11f8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D14    0a 00 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x12D18    45 74 68 20    call  0x15d2cd98                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D1C    4c 69 6e 6b    call  0x31a6e6c8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D20    20 46 61 69    unknown                                ! Undecodable word; may be data or erased flash.
0x12D24    6c 00 00 00    call  0xb0012d24                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D28    49 32 43 20    call  0x24ca39a8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D2C    42 75 73 20    call  0x9d6f9ac                        ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D30    45 72 72 6f    call  0x15caf6ec                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D34    72 00 00 00    call  0xc8012d34                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D38    42 42 54 20    call  0x90a7db8                        ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D3C    4e 6f 74 20    call  0x39befdbc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D40    46 6f 75 6e    call  0x19bf02f8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D44    64 00 00 00    call  0x90012d44                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D48    54 46 54 50    call  0x511a7e88                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D4C    20 49 6e 69    unknown                                ! Undecodable word; may be data or erased flash.
0x12D50    74 00 00 00    call  0xd0012d50                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D54    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12D58    54 46 54 50    call  0x511a7e98                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D5C    20 43 6f 6e    unknown                                ! Undecodable word; may be data or erased flash.
0x12D60    66 69 67 00    call  0x99a6c960                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D64    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12D68    55 53 42 20    call  0x554e35e8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D6C    49 6e 69 74    call  0x25bad33c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D70    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12D74    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12D78    43 69 70 68    call  0xda6ef18                        ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D7C    65 72 20 45    call  0x95c9ae90                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D80    72 72 6f 72    call  0xc9caeb48                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D84    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12D88    55 53 42 20    call  0x554e3608                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D8C    45 72 72 6f    call  0x15caf748                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D90    72 00 00 00    call  0xc8012d90                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D94    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12D98    4f 53 20 49    call  0x3d4daebc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12D9C    6e 64 65 78    call  0xb992c37c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12DA0    20 45 72 72    unknown                                ! Undecodable word; may be data or erased flash.
0x12DA4    6f 72 00 00    call  0xbdc92da4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12DA8    4e 41 4e 44    call  0x390666b8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12DAC    20 45 43 43    unknown                                ! Undecodable word; may be data or erased flash.
0x12DB0    20 46 61 69    unknown                                ! Undecodable word; may be data or erased flash.
0x12DB4    6c 00 00 00    call  0xb0012db4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12DB8    44 52 41 4d    call  0x114a32ec                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12DBC    20 54 65 73    unknown                                ! Undecodable word; may be data or erased flash.
0x12DC0    74 20 46 61    call  0xd0824744                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12DC4    69 6c 00 00    call  0xa5b12dc4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12DC8    44 49 4d 4d    call  0x112662fc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12DCC    20 53 50 44    unknown                                ! Undecodable word; may be data or erased flash.
0x12DD0    20 45 72 72    unknown                                ! Undecodable word; may be data or erased flash.
0x12DD4    6f 72 00 00    call  0xbdc92dd4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12DD8    3f 00 00 00    sethi  %hi(0), %i7                     ! Build high part of constant/address.
0x12DDC    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12DE0    0a 42 49 4f    unknown                                ! Undecodable word; may be data or erased flash.
0x12DE4    53 20 49 4e    call  0x4c82531c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12DE8    46 4f 3a 0a    call  0x193e1610                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12DEC    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12DF0    0a 4c 6f 61    unknown                                ! Undecodable word; may be data or erased flash.
0x12DF4    64 69 6e 67    call  0x91a6e790                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12DF8    20 2e 2e 2e    unknown                                ! Undecodable word; may be data or erased flash.
0x12DFC    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12E00    0a 57 65 6c    unknown                                ! Undecodable word; may be data or erased flash.
0x12E04    63 6f 6d 65    call  0x8dbee398                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E08    20 74 6f 20    unknown                                ! Undecodable word; may be data or erased flash.
0x12E0C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12E10    69 62 6f 6f    call  0xa58aebcc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E14    74 20 31 2e    call  0xd081f2cc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E18    30 30 61 30    unknown                                ! Undecodable word; may be data or erased flash.
0x12E1C    34 33 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x12E20    0a 62 75 69    unknown                                ! Undecodable word; may be data or erased flash.
0x12E24    6c 74 20 31    call  0xb1d1aee8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E28    35 3a 35 34    sethi  %hi(0xe8d4d000), %i2            ! Build high part of constant/address.
0x12E2C    20 32 30 30    unknown                                ! Undecodable word; may be data or erased flash.
0x12E30    38 2d 31 30    unknown                                ! Undecodable word; may be data or erased flash.
0x12E34    2d 30 31 0a    sethi  %hi(0xc0c42800), %l6            ! Build high part of constant/address.
0x12E40    08 57 65 6c    unknown                                ! Undecodable word; may be data or erased flash.
0x12E44    63 6f 6d 65    call  0x8dbee3d8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E48    20 74 6f 20    unknown                                ! Undecodable word; may be data or erased flash.
0x12E4C    74 68 65 00    call  0xd1a2c24c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E50    09 52 65 61    unknown                                ! Undecodable word; may be data or erased flash.
0x12E54    64 79 4e 41    call  0x91e66758                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E58    53 20 57 6f    call  0x4c828c14                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E5C    72 6c 64 21    call  0xc9b2bee0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E60    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12E64    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12E68    4f 43 5b 00    call  0x3d0e9a68                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E6C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12E70    5d 0a 00 00    call  0x74292e70                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E74    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12E78    62 69 64 20    call  0x89a6bef8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E7C    3d 20 00 00    sethi  %hi(0x80000000), %fp            ! Build high part of constant/address.
0x12E80    21 00 00 00    sethi  %hi(0), %l0                     ! Build high part of constant/address.
0x12E84    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12E88    55 53 42 20    call  0x554e3708                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E8C    52 65 74 72    call  0x49970054                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E90    79 0a 00 00    call  0xe4292e90                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12E94    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12E98    2e 00 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x12E9C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12EA0    48 65 6c 70    call  0x2196e060                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EA4    3a 0a 74 66    unknown                                ! Undecodable word; may be data or erased flash.
0x12EA8    74 70 20 4d    call  0xd1c1afdc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EAC    41 43 20 49    call  0x50dafd0                        ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EB0    50 20 49 50    call  0x408253f0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EB4    73 76 72 20    call  0xcddaf734                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EB8    66 69 6c 65    call  0x99a6e04c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EBC    20 6d 65 6d    unknown                                ! Undecodable word; may be data or erased flash.
0x12EC0    0a 6e 61 6e    unknown                                ! Undecodable word; may be data or erased flash.
0x12EC4    64 0a 75 73    call  0x902b0490                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EC8    62 0a 69 63    call  0x882ad454                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12ECC    73 20 76 31    call  0xcc830790                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12ED0    32 0a 49 43    unknown                                ! Undecodable word; may be data or erased flash.
0x12ED4    53 20 72 65    call  0x4c82f868                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12ED8    67 20 76 61    call  0x9c83085c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EDC    6c 0a 70 63    call  0xb02af068                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EE0    69 20 76 31    call  0xa48307a4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EE4    37 0a 72 65    sethi  %hi(0x29c99400), %i3            ! Build high part of constant/address.
0x12EE8    61 73 6f 6e    call  0x85ceeca0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EEC    20 78 0a 67    unknown                                ! Undecodable word; may be data or erased flash.
0x12EF0    6f 20 6d 65    call  0xbc82e484                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EF4    6d 0a 61 75    call  0xb42ab4c8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EF8    74 6f 0a 00    call  0xd1bd56f8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12EFC    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12F00    69 62 6f 6f    call  0xa58aecbc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F04    74 3e 20 00    call  0xd0f9af04                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F08    6e 61 6e 64    call  0xb986e898                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F0C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12F10    75 73 62 00    call  0xd5ceb710                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F14    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12F18    70 63 69 00    call  0xc18ed318                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F1C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12F20    61 75 74 6f    call  0x85d700dc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F24    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12F28    72 65 61 73    call  0xc996b4f4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F2C    6f 6e 00 00    call  0xbdb92f2c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F30    3f 0a 00 00    sethi  %hi(0x28000000), %i7            ! Build high part of constant/address.
0x12F34    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12F38    4d 65 6d 6f    call  0x3596e4f4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F3C    72 79 0a 00    call  0xc9e5573c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F40    0a 4d 65 6d    unknown                                ! Undecodable word; may be data or erased flash.
0x12F44    6f 72 79 20    call  0xbdcb13c4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F48    44 69 61 67    call  0x11a6b4e4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F4C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12F50    0a 4d 65 6d    unknown                                ! Undecodable word; may be data or erased flash.
0x12F54    6f 72 79 20    call  0xbdcb13d4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F58    4f 4b 00 00    call  0x3d2d2f58                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F5C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12F60    48 43 52 45    call  0x210e7874                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F64    53 45 54 20    call  0x4d167fe4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F68    54 4f 21 0a    call  0x513db390                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F6C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12F70    2e 00 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x12F74    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12F78    44 65 74 65    call  0x1197010c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F7C    63 74 69 6e    call  0x8dd2d534                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F80    67 20 55 53    call  0x9c8284cc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F84    42 20 62 6f    call  0x882b940                        ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F88    6f 74 20 64    call  0xbdd1b118                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F8C    65 76 69 63    call  0x95dad518                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F90    65 20 00 00    call  0x94812f90                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F94    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12F98    76 6d 6c 69    call  0xd9b6e13c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12F9C    6e 75 78 2e    call  0xb9d71054                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12FA0    62 69 6e 00    call  0x89a6e7a0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12FA4    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12FA8    69 6e 69 74    call  0xa5bad578                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12FAC    72 64 2e 69    call  0xc991e950                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12FB0    6d 67 00 00    call  0xb59d2fb0                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12FB4    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x12FB8    4c 6f 61 64    call  0x31beb548                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12FBC    20 6b 65 72    unknown                                ! Undecodable word; may be data or erased flash.
0x12FC0    6e 65 6c 20    call  0xb996e040                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12FC4    66 72 6f 6d    call  0x99caed78                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12FC8    20 55 53 42    unknown                                ! Undecodable word; may be data or erased flash.
0x12FCC    20 00 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x12FD0    0a 4c 6f 61    unknown                                ! Undecodable word; may be data or erased flash.
0x12FD4    64 20 69 6e    call  0x9082d58c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12FD8    69 74 72 64    call  0xa5d2f968                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12FDC    20 66 72 6f    unknown                                ! Undecodable word; may be data or erased flash.
0x12FE0    6d 20 55 53    call  0xb482852c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12FE4    42 20 00 00    call  0x8812fe4                        ! Call target; next instruction executes in delay slot. Verify target mapping.
0x12FE8    0a 00 00 00    unknown                                ! Undecodable word; may be data or erased flash.

! ============================================================================
! 0x13000: Sparse non-FF words within mostly erased NAND; do not assume executable code.
! ============================================================================
0x13000    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x13004    87 82 00 00    wr  %o0, %asr3
0x13020    12 34 68 09    unknown                                ! Undecodable word; may be data or erased flash.
0x13024    77 07 00 00    call  0xdc1d3024                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13028    00 00 04 56    unimp  0x456                           ! Unimplemented instruction encoding; may represent data.

! Erased NAND: 0x13040-0x1304B (12 bytes of FF); omitted.

0x1304C    08 06 00 01    unknown                                ! Undecodable word; may be data or erased flash.
0x13050    08 00 06 04    unknown                                ! Undecodable word; may be data or erased flash.
0x13054    00 01 00 00    unimp  0x10000                         ! Unimplemented instruction encoding; may represent data.

! Erased NAND: 0x13080-0x1308B (12 bytes of FF); omitted.

0x1308C    08 00 45 00    unknown                                ! Undecodable word; may be data or erased flash.
0x13090    00 00 d9 15    unimp  0xd915                          ! Unimplemented instruction encoding; may represent data.
0x13094    40 00 01 11    call  0x134d8                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13098    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x1309C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x130A0    00 00 11 11    unimp  0x1111                          ! Unimplemented instruction encoding; may represent data.
0x130C0    86 00 00 00    add  %g0, %g0, %g3
0x130CC    00 00 1b e7    unimp  0x1be7                          ! Unimplemented instruction encoding; may represent data.
0x130D0    87 83 6c 88    wr  %o5, 0xc88, %asr3
0x130D4    87 83 6c 70    wr  %o5, 0xc70, %asr3
0x130D8    87 83 6c 60    wr  %o5, 0xc60, %asr3
0x130DC    87 83 6c 50    wr  %o5, 0xc50, %asr3
0x130E0    87 83 6c 40    wr  %o5, 0xc40, %asr3
0x130E4    87 83 6c 30    wr  %o5, 0xc30, %asr3
0x130E8    87 83 6c 88    wr  %o5, 0xc88, %asr3
0x130EC    87 83 6c 70    wr  %o5, 0xc70, %asr3
0x130F0    87 83 6c 60    wr  %o5, 0xc60, %asr3
0x130F4    87 83 6c 50    wr  %o5, 0xc50, %asr3
0x130F8    87 83 6c a0    wr  %o5, 0xca0, %asr3
0x130FC    87 83 6c 90    wr  %o5, 0xc90, %asr3
0x13100    87 83 6c b0    wr  %o5, 0xcb0, %asr3
0x13104    87 83 6c 30    wr  %o5, 0xc30, %asr3
0x13108    87 83 6c b0    wr  %o5, 0xcb0, %asr3
0x1310C    87 83 6c b8    wr  %o5, 0xcb8, %asr3
0x13110    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x13114    87 83 74 00    wr  %o5, -3072, %asr3
0x13118    30 00 04 00    unknown                                ! Undecodable word; may be data or erased flash.
0x1311C    87 83 6c 88    wr  %o5, 0xc88, %asr3
0x13120    87 83 6c 70    wr  %o5, 0xc70, %asr3
0x13124    87 83 6c 60    wr  %o5, 0xc60, %asr3
0x13128    87 83 6c 50    wr  %o5, 0xc50, %asr3
0x1312C    87 83 6c c8    wr  %o5, 0xcc8, %asr3
0x13130    87 83 6c 30    wr  %o5, 0xc30, %asr3
0x13134    87 83 6c 88    wr  %o5, 0xc88, %asr3
0x13138    87 83 6c 70    wr  %o5, 0xc70, %asr3
0x1313C    87 83 6c 60    wr  %o5, 0xc60, %asr3
0x13140    87 83 6c 50    wr  %o5, 0xc50, %asr3
0x13144    87 83 6c d8    wr  %o5, 0xcd8, %asr3
0x13148    87 83 6c 90    wr  %o5, 0xc90, %asr3
0x1314C    87 83 6c 88    wr  %o5, 0xc88, %asr3
0x13150    87 83 6c 70    wr  %o5, 0xc70, %asr3
0x13154    87 83 6c 60    wr  %o5, 0xc60, %asr3
0x13158    87 83 6c 50    wr  %o5, 0xc50, %asr3
0x1315C    87 83 6c e8    wr  %o5, 0xce8, %asr3
0x13160    87 83 6c 30    wr  %o5, 0xc30, %asr3
0x13164    87 83 6c 88    wr  %o5, 0xc88, %asr3
0x13168    87 83 6c 70    wr  %o5, 0xc70, %asr3
0x1316C    87 83 6c 60    wr  %o5, 0xc60, %asr3
0x13170    87 83 6c 50    wr  %o5, 0xc50, %asr3
0x13174    87 83 6c f8    wr  %o5, 0xcf8, %asr3
0x13178    87 83 6c 90    wr  %o5, 0xc90, %asr3
0x1317C    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x13180    0a 57 72 69    unknown                                ! Undecodable word; may be data or erased flash.
0x13184    74 69 6e 67    call  0xd1a6eb20                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13188    20 70 61 74    unknown                                ! Undecodable word; may be data or erased flash.
0x1318C    20 20 00 00    unknown                                ! Undecodable word; may be data or erased flash.
0x13190    0a 43 68 65    unknown                                ! Undecodable word; may be data or erased flash.
0x13194    63 6b 69 6e    call  0x8daed74c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13198    67 20 70 61    call  0x9c82f31c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x1319C    74 20 20 00    call  0xd081b19c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x131A0    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x131AC    87 83 6d d8    wr  %o5, 0xdd8, %asr3
0x131B0    87 83 6d d8    wr  %o5, 0xdd8, %asr3
0x131B4    87 83 6d c8    wr  %o5, 0xdc8, %asr3
0x131B8    87 83 6d b8    wr  %o5, 0xdb8, %asr3
0x131BC    87 83 6d a8    wr  %o5, 0xda8, %asr3
0x131C0    87 83 6d 98    wr  %o5, 0xd98, %asr3
0x131C4    87 83 6d 88    wr  %o5, 0xd88, %asr3
0x131C8    87 83 6d 78    wr  %o5, 0xd78, %asr3
0x131CC    87 83 6d 68    wr  %o5, 0xd68, %asr3
0x131D0    87 83 6d 58    wr  %o5, 0xd58, %asr3
0x131D4    87 83 6d 48    wr  %o5, 0xd48, %asr3
0x131D8    87 83 6d 38    wr  %o5, 0xd38, %asr3
0x131DC    87 83 6d 28    wr  %o5, 0xd28, %asr3
0x131E0    87 83 6d 18    wr  %o5, 0xd18, %asr3
0x131E4    87 83 6d d8    wr  %o5, 0xdd8, %asr3
0x131E8    87 83 6d d8    wr  %o5, 0xdd8, %asr3
0x131EC    00 00 00 00    unimp  0                               ! Unimplemented instruction encoding; may represent data.
0x131F0    10 00 0c f8    unknown                                ! Undecodable word; may be data or erased flash.
0x131F4    10 00 0c fc    unknown                                ! Undecodable word; may be data or erased flash.
0x131F8    00 00 00 01    unimp  0x1                             ! Unimplemented instruction encoding; may represent data.
0x1332C    80 00 ff ff    add  %g3, -1, %g0

! Erased NAND: 0x13330-0x133FF (208 bytes of FF); omitted.


! ============================================================================
! 0x13400: Confirmed-looking small delay loop followed by additional routines.
! ============================================================================
0x13400    87 2a 20 05    sll  %o0, 5, %g3                       ! Delay loop: multiply input by 32.
0x13404    85 2a 20 06    sll  %o0, 6, %g2                       ! Delay loop: multiply input by 64.
0x13408    90 00 80 03    add  %g2, %g3, %o0                     ! Delay loop count = input * 96.
0x1340C    90 a2 20 01    deccc  %o0                             ! Decrement counter and set condition codes.
0x13410    12 bf ff ff    bne  0x1340c                           ! Repeat until counter reaches zero; zero input can wrap.
0x13414    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x13418    81 c3 e0 08    retl                                   ! Return to caller.
0x1341C    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x13420    9d e3 bf 10    save  %sp, -240, %sp                   ! Enter register window; allocate stack frame.
0x13424    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x13428    a4 12 23 8c    or  %o0, 0x38c, %l2                    ! 0x8783738c
0x1342C    55 e0 c2 38    call  0x57843d0c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13430    90 10 20 50    mov  0x50, %o0
0x13434    80 a2 20 00    cmp  %o0, 0
0x13438    02 80 01 85    be  0x13a4c                            ! Conditional/control branch; inspect delay slot.
0x1343C    a0 10 20 00    clr  %l0
0x13440    a6 07 bf 74    add  %fp, -140, %l3
0x13444    a2 07 bf 70    add  %fp, -144, %l1
0x13448    a8 07 bf 78    add  %fp, -136, %l4
0x1344C    b0 07 bf f8    add  %fp, -8, %i0
0x13450    93 2c 20 18    sll  %l0, 0x18, %o1
0x13454    94 10 20 00    clr  %o2
0x13458    96 10 20 01    mov  1, %o3
0x1345C    55 e0 c2 03    call  0x57843c68                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13460    90 10 20 50    mov  0x50, %o0
0x13464    92 10 00 13    mov  %l3, %o1
0x13468    90 10 20 50    mov  0x50, %o0
0x1346C    94 10 00 11    mov  %l1, %o2
0x13470    55 e0 c2 11    call  0x57843cb4                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13474    96 10 20 08    mov  8, %o3
0x13478    d2 07 bf 74    ld  [ %fp + -140 ], %o1
0x1347C    a0 04 20 08    add  %l0, 8, %l0
0x13480    d2 26 3f 80    st  %o1, [ %i0 + -128 ]
0x13484    d0 07 bf 70    ld  [ %fp + -144 ], %o0
0x13488    80 a4 20 7f    cmp  %l0, 0x7f
0x1348C    d0 26 3f 84    st  %o0, [ %i0 + -124 ]
0x13490    08 bf ff f0    bleu  0x13450                          ! Conditional/control branch; inspect delay slot.
0x13494    b0 06 20 08    add  %i0, 8, %i0
0x13498    d6 0f bf b7    ldub  [ %fp + -73 ], %o3
0x1349C    94 10 00 14    mov  %l4, %o2
0x134A0    92 10 20 00    clr  %o1
0x134A4    a0 10 20 00    clr  %l0
0x134A8    d0 0a 80 10    ldub  [ %o2 + %l0 ], %o0
0x134AC    a0 04 20 01    inc  %l0
0x134B0    80 a4 20 3e    cmp  %l0, 0x3e
0x134B4    08 bf ff fd    bleu  0x134a8                          ! Conditional/control branch; inspect delay slot.
0x134B8    92 02 40 08    add  %o1, %o0, %o1
0x134BC    90 0a 60 ff    and  %o1, 0xff, %o0
0x134C0    80 a2 00 0b    cmp  %o0, %o3
0x134C4    32 80 01 6e    bne,a   0x13a7c                        ! Conditional/control branch; inspect delay slot.
0x134C8    b0 10 3f ff    mov  -1, %i0
0x134CC    d0 0f bf 7a    ldub  [ %fp + -134 ], %o0
0x134D0    80 a2 20 07    cmp  %o0, 7
0x134D4    32 80 01 6a    bne,a   0x13a7c                        ! Conditional/control branch; inspect delay slot.
0x134D8    b0 10 3f ff    mov  -1, %i0
0x134DC    d0 0f bf 7e    ldub  [ %fp + -130 ], %o0
0x134E0    80 a2 20 40    cmp  %o0, 0x40
0x134E4    02 80 00 04    be  0x134f4                            ! Conditional/control branch; inspect delay slot.
0x134E8    80 a2 20 48    cmp  %o0, 0x48
0x134EC    32 80 01 64    bne,a   0x13a7c                        ! Conditional/control branch; inspect delay slot.
0x134F0    b0 10 3f ff    mov  -1, %i0
0x134F4    d0 0f bf 80    ldub  [ %fp + -128 ], %o0
0x134F8    80 a2 20 04    cmp  %o0, 4
0x134FC    32 80 01 60    bne,a   0x13a7c                        ! Conditional/control branch; inspect delay slot.
0x13500    b0 10 3f ff    mov  -1, %i0
0x13504    d0 0f bf 89    ldub  [ %fp + -119 ], %o0
0x13508    80 a2 20 04    cmp  %o0, 4
0x1350C    32 80 01 5c    bne,a   0x13a7c                        ! Conditional/control branch; inspect delay slot.
0x13510    b0 10 3f ff    mov  -1, %i0
0x13514    d2 0f bf 8a    ldub  [ %fp + -118 ], %o1
0x13518    90 0a 60 0c    and  %o1, 0xc, %o0
0x1351C    80 a2 20 00    cmp  %o0, 0
0x13520    02 80 01 4b    be  0x13a4c                            ! Conditional/control branch; inspect delay slot.
0x13524    80 8a 60 20    btst  0x20, %o1
0x13528    12 80 00 09    bne  0x1354c                           ! Conditional/control branch; inspect delay slot.
0x1352C    84 10 20 23    mov  0x23, %g2
0x13530    80 8a 60 10    btst  0x10, %o1
0x13534    12 80 00 06    bne  0x1354c                           ! Conditional/control branch; inspect delay slot.
0x13538    84 10 20 1e    mov  0x1e, %g2
0x1353C    80 8a 60 08    btst  8, %o1
0x13540    02 80 00 03    be  0x1354c                            ! Conditional/control branch; inspect delay slot.
0x13544    84 10 20 14    mov  0x14, %g2
0x13548    84 10 20 19    mov  0x19, %g2
0x1354C    d0 0f bf 8b    ldub  [ %fp + -117 ], %o0
0x13550    80 a2 20 01    cmp  %o0, 1
0x13554    12 80 01 4a    bne  0x13a7c                           ! Conditional/control branch; inspect delay slot.
0x13558    b0 10 3f ff    mov  -1, %i0
0x1355C    d0 0f bf 8c    ldub  [ %fp + -116 ], %o0
0x13560    80 a2 20 02    cmp  %o0, 2
0x13564    12 80 01 46    bne  0x13a7c                           ! Conditional/control branch; inspect delay slot.
0x13568    d4 0f bf a3    ldub  [ %fp + -93 ], %o2
0x1356C    80 a2 a0 00    cmp  %o2, 0
0x13570    02 80 00 0b    be  0x1359c                            ! Conditional/control branch; inspect delay slot.
0x13574    91 2a a0 05    sll  %o2, 5, %o0
0x13578    90 22 00 0a    sub  %o0, %o2, %o0
0x1357C    91 2a 20 02    sll  %o0, 2, %o0
0x13580    90 02 00 0a    add  %o0, %o2, %o0
0x13584    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x13588    d4 02 60 cc    ld  [ %o1 + 0xcc ], %o2                ! 0x878370cc
0x1358C    91 2a 20 01    sll  %o0, 1, %o0
0x13590    80 a2 00 0a    cmp  %o0, %o2
0x13594    0a 80 01 3a    bcs  0x13a7c                           ! Conditional/control branch; inspect delay slot.
0x13598    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x1359C    d0 0f bf 8d    ldub  [ %fp + -115 ], %o0
0x135A0    80 a2 20 20    cmp  %o0, 0x20
0x135A4    02 80 00 05    be  0x135b8                            ! Conditional/control branch; inspect delay slot.
0x135A8    c0 24 80 00    clr  [ %l2 ]
0x135AC    80 a2 20 24    cmp  %o0, 0x24
0x135B0    12 80 00 05    bne  0x135c4                           ! Conditional/control branch; inspect delay slot.
0x135B4    80 a2 20 26    cmp  %o0, 0x26
0x135B8    90 10 20 04    mov  4, %o0
0x135BC    10 80 00 04    b  0x135cc                             ! Conditional/control branch; inspect delay slot.
0x135C0    d0 24 80 00    st  %o0, [ %l2 ]
0x135C4    12 80 01 2e    bne  0x13a7c                           ! Conditional/control branch; inspect delay slot.
0x135C8    b0 10 3f ff    mov  -1, %i0
0x135CC    d2 0f bf 7b    ldub  [ %fp + -133 ], %o1
0x135D0    80 8a 60 f0    btst  0xf0, %o1
0x135D4    12 80 01 2a    bne  0x13a7c                           ! Conditional/control branch; inspect delay slot.
0x135D8    b0 10 3f ff    mov  -1, %i0
0x135DC    da 0f bf 7c    ldub  [ %fp + -132 ], %o5
0x135E0    80 8b 60 f0    btst  0xf0, %o5
0x135E4    12 80 01 26    bne  0x13a7c                           ! Conditional/control branch; inspect delay slot.
0x135E8    d8 0f bf 7d    ldub  [ %fp + -131 ], %o4
0x135EC    90 03 3f ff    add  %o4, -1, %o0
0x135F0    80 a2 20 01    cmp  %o0, 1
0x135F4    18 80 01 22    bgu  0x13a7c                           ! Conditional/control branch; inspect delay slot.
0x135F8    92 02 40 0d    add  %o1, %o5, %o1
0x135FC    96 02 60 05    add  %o1, 5, %o3
0x13600    92 02 7f f5    add  %o1, -11, %o1
0x13604    90 10 20 01    mov  1, %o0
0x13608    91 2a 00 09    sll  %o0, %o1, %o0
0x1360C    15 00 00 10    sethi  %hi(0x4000), %o2                ! Build high part of constant/address.
0x13610    92 02 00 0a    add  %o0, %o2, %o1
0x13614    94 12 c0 0a    or  %o3, %o2, %o2
0x13618    91 2b 00 0b    sll  %o4, %o3, %o0
0x1361C    d0 24 a0 18    st  %o0, [ %l2 + 0x18 ]
0x13620    d4 24 a0 08    st  %o2, [ %l2 + 8 ]
0x13624    80 a3 20 02    cmp  %o4, 2
0x13628    12 80 00 04    bne  0x13638                           ! Conditional/control branch; inspect delay slot.
0x1362C    d2 24 a0 0c    st  %o1, [ %l2 + 0xc ]
0x13630    90 12 40 0b    or  %o1, %o3, %o0
0x13634    d0 24 a0 0c    st  %o0, [ %l2 + 0xc ]
0x13638    90 03 7f f8    add  %o5, -8, %o0
0x1363C    80 a2 20 04    cmp  %o0, 4
0x13640    18 80 01 03    bgu  0x13a4c                           ! Conditional/control branch; inspect delay slot.
0x13644    90 03 7f fa    add  %o5, -6, %o0
0x13648    93 2a 20 04    sll  %o0, 4, %o1
0x1364C    80 a3 20 02    cmp  %o4, 2
0x13650    12 80 00 05    bne  0x13664                           ! Conditional/control branch; inspect delay slot.
0x13654    d2 24 a0 10    st  %o1, [ %l2 + 0x10 ]
0x13658    91 2a 20 07    sll  %o0, 7, %o0
0x1365C    90 12 40 08    or  %o1, %o0, %o0
0x13660    d0 24 a0 10    st  %o0, [ %l2 + 0x10 ]
0x13664    d2 0f bf 8f    ldub  [ %fp + -113 ], %o1
0x13668    29 21 e0 dc    sethi  %hi(0x87837000), %l4            ! Build high part of constant/address.
0x1366C    d8 0f bf 91    ldub  [ %fp + -111 ], %o4
0x13670    91 32 60 04    srl  %o1, 4, %o0
0x13674    9b 33 20 04    srl  %o4, 4, %o5
0x13678    95 2a 20 02    sll  %o0, 2, %o2
0x1367C    94 02 80 08    add  %o2, %o0, %o2
0x13680    97 2b 60 02    sll  %o5, 2, %o3
0x13684    92 0a 60 0f    and  %o1, 0xf, %o1
0x13688    96 02 c0 0d    add  %o3, %o5, %o3
0x1368C    95 2a a0 01    sll  %o2, 1, %o2
0x13690    94 02 80 09    add  %o2, %o1, %o2
0x13694    98 0b 20 0f    and  %o4, 0xf, %o4
0x13698    97 2a e0 01    sll  %o3, 1, %o3
0x1369C    96 02 c0 0c    add  %o3, %o4, %o3
0x136A0    93 2a a0 01    sll  %o2, 1, %o1
0x136A4    91 2a e0 01    sll  %o3, 1, %o0
0x136A8    92 02 40 0a    add  %o1, %o2, %o1
0x136AC    90 02 00 0b    add  %o0, %o3, %o0
0x136B0    93 2a 60 03    sll  %o1, 3, %o1
0x136B4    92 02 40 0a    add  %o1, %o2, %o1
0x136B8    91 2a 20 03    sll  %o0, 3, %o0
0x136BC    90 02 00 0b    add  %o0, %o3, %o0
0x136C0    99 2a 60 02    sll  %o1, 2, %o4
0x136C4    80 a3 20 00    cmp  %o4, 0
0x136C8    12 80 00 06    bne  0x136e0                           ! Conditional/control branch; inspect delay slot.
0x136CC    97 2a 20 02    sll  %o0, 2, %o3
0x136D0    d2 05 20 cc    ld  [ %l4 + 0xcc ], %o1
0x136D4    11 00 00 37    sethi  %hi(0xdc00), %o0                ! Build high part of constant/address.
0x136D8    90 12 22 ad    or  %o0, 0x2ad, %o0                    ! 0xdead
0x136DC    98 02 40 08    add  %o1, %o0, %o4
0x136E0    80 a2 e0 00    cmp  %o3, 0
0x136E4    12 80 00 06    bne  0x136fc                           ! Conditional/control branch; inspect delay slot.
0x136E8    d4 0f bf 81    ldub  [ %fp + -127 ], %o2
0x136EC    d2 05 20 cc    ld  [ %l4 + 0xcc ], %o1
0x136F0    11 00 00 37    sethi  %hi(0xdc00), %o0                ! Build high part of constant/address.
0x136F4    90 12 22 ad    or  %o0, 0x2ad, %o0                    ! 0xdead
0x136F8    96 02 40 08    add  %o1, %o0, %o3
0x136FC    91 32 a0 04    srl  %o2, 4, %o0
0x13700    93 2a 20 02    sll  %o0, 2, %o1
0x13704    92 02 40 08    add  %o1, %o0, %o1
0x13708    93 2a 60 01    sll  %o1, 1, %o1
0x1370C    94 0a a0 0f    and  %o2, 0xf, %o2
0x13710    92 02 40 0a    add  %o1, %o2, %o1
0x13714    91 2a 60 01    sll  %o1, 1, %o0
0x13718    90 02 00 09    add  %o0, %o1, %o0
0x1371C    91 2a 20 03    sll  %o0, 3, %o0
0x13720    90 02 00 09    add  %o0, %o1, %o0
0x13724    d2 05 20 cc    ld  [ %l4 + 0xcc ], %o1
0x13728    91 2a 20 02    sll  %o0, 2, %o0
0x1372C    80 a2 00 09    cmp  %o0, %o1
0x13730    18 80 00 c7    bgu  0x13a4c                           ! Conditional/control branch; inspect delay slot.
0x13734    90 08 a0 ff    and  %g2, 0xff, %o0
0x13738    80 a2 20 23    cmp  %o0, 0x23
0x1373C    12 80 00 07    bne  0x13758                           ! Conditional/control branch; inspect delay slot.
0x13740    84 10 20 14    mov  0x14, %g2
0x13744    80 a2 c0 09    cmp  %o3, %o1
0x13748    18 80 00 c1    bgu  0x13a4c                           ! Conditional/control branch; inspect delay slot.
0x1374C    84 10 20 19    mov  0x19, %g2
0x13750    10 80 00 0f    b  0x1378c                             ! Conditional/control branch; inspect delay slot.
0x13754    80 a0 a0 19    cmp  %g2, 0x19
0x13758    80 a2 20 1e    cmp  %o0, 0x1e
0x1375C    12 80 00 06    bne  0x13774                           ! Conditional/control branch; inspect delay slot.
0x13760    80 a2 20 19    cmp  %o0, 0x19
0x13764    80 a3 00 09    cmp  %o4, %o1
0x13768    18 80 00 b9    bgu  0x13a4c                           ! Conditional/control branch; inspect delay slot.
0x1376C    80 a2 c0 09    cmp  %o3, %o1
0x13770    30 80 00 04    b,a   0x13780                          ! Conditional/control branch; inspect delay slot.
0x13774    12 80 00 06    bne  0x1378c                           ! Conditional/control branch; inspect delay slot.
0x13778    80 a0 a0 19    cmp  %g2, 0x19
0x1377C    80 a3 00 09    cmp  %o4, %o1
0x13780    38 80 00 02    bgu,a   0x13788                        ! Conditional/control branch; inspect delay slot.
0x13784    84 10 20 19    mov  0x19, %g2
0x13788    80 a0 a0 19    cmp  %g2, 0x19
0x1378C    12 80 00 08    bne  0x137ac                           ! Conditional/control branch; inspect delay slot.
0x13790    90 10 20 21    mov  0x21, %o0
0x13794    d0 04 80 00    ld  [ %l2 ], %o0
0x13798    92 10 20 61    mov  0x61, %o1
0x1379C    90 12 20 08    or  %o0, 8, %o0
0x137A0    d0 24 80 00    st  %o0, [ %l2 ]
0x137A4    10 80 00 03    b  0x137b0                             ! Conditional/control branch; inspect delay slot.
0x137A8    d2 24 a0 14    st  %o1, [ %l2 + 0x14 ]
0x137AC    d0 24 a0 14    st  %o0, [ %l2 + 0x14 ]
0x137B0    d2 05 20 cc    ld  [ %l4 + 0xcc ], %o1
0x137B4    11 00 00 07    sethi  %hi(0x1c00), %o0                ! Build high part of constant/address.
0x137B8    90 12 21 4b    or  %o0, 0x14b, %o0                    ! 0x1d4b
0x137BC    80 a2 40 08    cmp  %o1, %o0
0x137C0    18 80 00 04    bgu  0x137d0                           ! Conditional/control branch; inspect delay slot.
0x137C4    d0 04 80 00    ld  [ %l2 ], %o0
0x137C8    10 80 00 03    b  0x137d4                             ! Conditional/control branch; inspect delay slot.
0x137CC    90 12 20 03    or  %o0, 3, %o0
0x137D0    90 12 20 02    or  %o0, 2, %o0
0x137D4    d0 24 80 00    st  %o0, [ %l2 ]
0x137D8    d2 0f bf 95    ldub  [ %fp + -107 ], %o1
0x137DC    a6 10 20 01    mov  1, %l3
0x137E0    91 2a 60 05    sll  %o1, 5, %o0
0x137E4    90 22 00 09    sub  %o0, %o1, %o0
0x137E8    91 2a 20 02    sll  %o0, 2, %o0
0x137EC    d4 05 20 cc    ld  [ %l4 + 0xcc ], %o2
0x137F0    90 02 00 09    add  %o0, %o1, %o0
0x137F4    92 10 00 0a    mov  %o2, %o1
0x137F8    10 80 00 03    b  0x13804                             ! Conditional/control branch; inspect delay slot.
0x137FC    91 2a 20 01    sll  %o0, 1, %o0
0x13800    a6 04 e0 01    inc  %l3
0x13804    80 a4 e0 04    cmp  %l3, 4
0x13808    14 80 00 04    bg  0x13818                            ! Conditional/control branch; inspect delay slot.
0x1380C    80 a2 00 0a    cmp  %o0, %o2
0x13810    3a bf ff fc    bcc,a   0x13800
0x13814    94 02 80 09    add  %o2, %o1, %o2
0x13818    80 a4 e0 04    cmp  %l3, 4
0x1381C    14 80 00 98    bg  0x13a7c                            ! Conditional/control branch; inspect delay slot.
0x13820    b0 10 3f ff    mov  -1, %i0
0x13824    d6 0f bf 93    ldub  [ %fp + -109 ], %o3
0x13828    92 04 ff ff    add  %l3, -1, %o1
0x1382C    91 2a e0 05    sll  %o3, 5, %o0
0x13830    d4 04 80 00    ld  [ %l2 ], %o2
0x13834    93 2a 60 04    sll  %o1, 4, %o1
0x13838    90 22 00 0b    sub  %o0, %o3, %o0
0x1383C    92 0a 60 30    and  %o1, 0x30, %o1
0x13840    91 2a 20 02    sll  %o0, 2, %o0
0x13844    94 12 80 09    or  %o2, %o1, %o2
0x13848    90 02 00 0b    add  %o0, %o3, %o0
0x1384C    d8 05 20 cc    ld  [ %l4 + 0xcc ], %o4
0x13850    93 2a 20 01    sll  %o0, 1, %o1
0x13854    9a 10 00 0c    mov  %o4, %o5
0x13858    d4 24 80 00    st  %o2, [ %l2 ]
0x1385C    10 80 00 03    b  0x13868                             ! Conditional/control branch; inspect delay slot.
0x13860    90 10 20 01    mov  1, %o0
0x13864    90 02 20 01    inc  %o0
0x13868    80 a2 20 04    cmp  %o0, 4
0x1386C    14 80 00 04    bg  0x1387c                            ! Conditional/control branch; inspect delay slot.
0x13870    80 a2 40 0c    cmp  %o1, %o4
0x13874    3a bf ff fc    bcc,a   0x13864
0x13878    98 03 00 0d    add  %o4, %o5, %o4
0x1387C    80 a2 20 04    cmp  %o0, 4
0x13880    14 80 00 7f    bg  0x13a7c                            ! Conditional/control branch; inspect delay slot.
0x13884    b0 10 3f ff    mov  -1, %i0
0x13888    90 02 3f ff    add  %o0, -1, %o0
0x1388C    d4 04 80 00    ld  [ %l2 ], %o2
0x13890    91 2a 20 06    sll  %o0, 6, %o0
0x13894    90 0a 20 c0    and  %o0, 0xc0, %o0
0x13898    90 12 80 08    or  %o2, %o0, %o0
0x1389C    92 12 21 00    or  %o0, 0x100, %o1
0x138A0    80 a0 a0 14    cmp  %g2, 0x14
0x138A4    12 80 00 04    bne  0x138b4                           ! Conditional/control branch; inspect delay slot.
0x138A8    d2 24 80 00    st  %o1, [ %l2 ]
0x138AC    10 80 00 03    b  0x138b8                             ! Conditional/control branch; inspect delay slot.
0x138B0    90 12 25 00    or  %o0, 0x500, %o0
0x138B4    90 12 29 00    or  %o0, 0x900, %o0
0x138B8    d0 24 80 00    st  %o0, [ %l2 ]
0x138BC    d4 0f bf a1    ldub  [ %fp + -95 ], %o2
0x138C0    d2 0f bf a2    ldub  [ %fp + -94 ], %o1
0x138C4    80 a2 80 09    cmp  %o2, %o1
0x138C8    28 80 00 07    bleu,a   0x138e4
0x138CC    91 2a 60 05    sll  %o1, 5, %o0
0x138D0    91 2a a0 05    sll  %o2, 5, %o0
0x138D4    90 22 00 0a    sub  %o0, %o2, %o0
0x138D8    91 2a 20 02    sll  %o0, 2, %o0
0x138DC    10 80 00 05    b  0x138f0                             ! Conditional/control branch; inspect delay slot.
0x138E0    90 02 00 0a    add  %o0, %o2, %o0
0x138E4    90 22 00 09    sub  %o0, %o1, %o0
0x138E8    91 2a 20 02    sll  %o0, 2, %o0
0x138EC    90 02 00 09    add  %o0, %o1, %o0
0x138F0    97 2a 20 03    sll  %o0, 3, %o3
0x138F4    d4 05 20 cc    ld  [ %l4 + 0xcc ], %o2
0x138F8    92 10 20 07    mov  7, %o1
0x138FC    91 2a a0 03    sll  %o2, 3, %o0
0x13900    10 80 00 03    b  0x1390c                             ! Conditional/control branch; inspect delay slot.
0x13904    90 22 00 0a    sub  %o0, %o2, %o0
0x13908    92 02 60 01    inc  %o1
0x1390C    80 a2 60 0b    cmp  %o1, 0xb
0x13910    14 80 00 04    bg  0x13920                            ! Conditional/control branch; inspect delay slot.
0x13914    80 a2 c0 08    cmp  %o3, %o0
0x13918    3a bf ff fc    bcc,a   0x13908
0x1391C    90 02 00 0a    add  %o0, %o2, %o0
0x13920    80 a2 60 0b    cmp  %o1, 0xb
0x13924    22 80 00 02    be,a   0x1392c                         ! Conditional/control branch; inspect delay slot.
0x13928    92 10 20 0a    mov  0xa, %o1
0x1392C    80 a2 60 0a    cmp  %o1, 0xa
0x13930    14 80 00 53    bg  0x13a7c                            ! Conditional/control branch; inspect delay slot.
0x13934    b0 10 3f ff    mov  -1, %i0
0x13938    90 02 7f f9    add  %o1, -7, %o0
0x1393C    d4 04 80 00    ld  [ %l2 ], %o2
0x13940    91 2a 20 0c    sll  %o0, 0xc, %o0
0x13944    17 00 00 0c    sethi  %hi(0x3000), %o3                ! Build high part of constant/address.
0x13948    90 0a 00 0b    and  %o0, %o3, %o0
0x1394C    d2 0f bf a1    ldub  [ %fp + -95 ], %o1
0x13950    94 12 80 08    or  %o2, %o0, %o2
0x13954    80 a2 60 00    cmp  %o1, 0
0x13958    12 80 00 08    bne  0x13978                           ! Conditional/control branch; inspect delay slot.
0x1395C    d4 24 80 00    st  %o2, [ %l2 ]
0x13960    d0 0f bf a2    ldub  [ %fp + -94 ], %o0
0x13964    80 a2 20 00    cmp  %o0, 0
0x13968    12 80 00 05    bne  0x1397c                           ! Conditional/control branch; inspect delay slot.
0x1396C    d2 0f bf 96    ldub  [ %fp + -106 ], %o1
0x13970    90 12 80 0b    or  %o2, %o3, %o0
0x13974    d0 24 80 00    st  %o0, [ %l2 ]
0x13978    d2 0f bf 96    ldub  [ %fp + -106 ], %o1
0x1397C    a0 10 20 04    mov  4, %l0
0x13980    91 2a 60 05    sll  %o1, 5, %o0
0x13984    90 22 00 09    sub  %o0, %o1, %o0
0x13988    91 2a 20 02    sll  %o0, 2, %o0
0x1398C    90 02 00 09    add  %o0, %o1, %o0
0x13990    f0 05 20 cc    ld  [ %l4 + 0xcc ], %i0
0x13994    a3 2a 20 01    sll  %o0, 1, %l1
0x13998    80 a4 20 07    cmp  %l0, 7
0x1399C    14 80 00 08    bg  0x139bc                            ! Conditional/control branch; inspect delay slot.
0x139A0    90 04 00 13    add  %l0, %l3, %o0
0x139A4    55 e0 c1 22    call  0x57843e2c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x139A8    92 10 00 18    mov  %i0, %o1
0x139AC    80 a4 40 08    cmp  %l1, %o0
0x139B0    3a bf ff fa    bcc,a   0x13998
0x139B4    a0 04 20 01    inc  %l0
0x139B8    80 a4 20 07    cmp  %l0, 7
0x139BC    34 80 00 30    bg,a   0x13a7c
0x139C0    b0 10 3f ff    mov  -1, %i0
0x139C4    90 04 3f fc    add  %l0, -4, %o0
0x139C8    d2 04 80 00    ld  [ %l2 ], %o1
0x139CC    91 2a 20 0e    sll  %o0, 0xe, %o0
0x139D0    15 00 00 30    sethi  %hi(0xc000), %o2                ! Build high part of constant/address.
0x139D4    d6 0f bf 84    ldub  [ %fp + -124 ], %o3
0x139D8    90 0a 00 0a    and  %o0, %o2, %o0
0x139DC    96 0a e0 7f    and  %o3, 0x7f, %o3
0x139E0    92 12 40 08    or  %o1, %o0, %o1
0x139E4    80 a2 e0 05    cmp  %o3, 5
0x139E8    18 80 00 19    bgu  0x13a4c                           ! Conditional/control branch; inspect delay slot.
0x139EC    d2 24 80 00    st  %o1, [ %l2 ]
0x139F0    11 0c 00 02    sethi  %hi(0x30000800), %o0            ! Build high part of constant/address.
0x139F4    90 12 22 84    or  %o0, 0x284, %o0                    ! 0x30000a84
0x139F8    93 2a e0 02    sll  %o3, 2, %o1
0x139FC    d4 02 00 09    ld  [ %o0 + %o1 ], %o2
0x13A00    81 c2 80 00    jmp  %o2
0x13A04    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x13A08    11 00 3b 82    sethi  %hi(0xee0800), %o0              ! Build high part of constant/address.
0x13A0C    10 80 00 12    b  0x13a54                             ! Conditional/control branch; inspect delay slot.
0x13A10    90 12 21 80    or  %o0, 0x180, %o0                    ! 0xee0980
0x13A14    11 00 0e e0    sethi  %hi(0x3b8000), %o0              ! Build high part of constant/address.
0x13A18    10 80 00 0f    b  0x13a54                             ! Conditional/control branch; inspect delay slot.
0x13A1C    90 12 22 60    or  %o0, 0x260, %o0                    ! 0x3b8260
0x13A20    11 00 1d c1    sethi  %hi(0x770400), %o0              ! Build high part of constant/address.
0x13A24    10 80 00 0c    b  0x13a54                             ! Conditional/control branch; inspect delay slot.
0x13A28    90 12 20 c0    or  %o0, 0xc0, %o0                     ! 0x7704c0
0x13A2C    11 00 77 04    sethi  %hi(0x1dc1000), %o0             ! Build high part of constant/address.
0x13A30    10 80 00 09    b  0x13a54                             ! Conditional/control branch; inspect delay slot.
0x13A34    90 12 23 00    or  %o0, 0x300, %o0                    ! 0x1dc1300
0x13A38    11 00 ee 09    sethi  %hi(0x3b82400), %o0             ! Build high part of constant/address.
0x13A3C    10 80 00 06    b  0x13a54                             ! Conditional/control branch; inspect delay slot.
0x13A40    90 12 22 00    or  %o0, 0x200, %o0                    ! 0x3b82600
0x13A44    10 80 00 04    b  0x13a54                             ! Conditional/control branch; inspect delay slot.
0x13A48    11 01 dc 13    sethi  %hi(0x7704c00), %o0             ! Build high part of constant/address.
0x13A4C    10 80 00 0c    b  0x13a7c                             ! Conditional/control branch; inspect delay slot.
0x13A50    b0 10 3f ff    mov  -1, %i0
0x13A54    d2 05 20 cc    ld  [ %l4 + 0xcc ], %o1
0x13A58    55 e0 c0 e9    call  0x57843dfc                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13A5C    b0 10 20 00    clr  %i0
0x13A60    90 02 3f e8    add  %o0, -24, %o0
0x13A64    91 3a 20 06    sra  %o0, 6, %o0
0x13A68    91 2a 20 0a    sll  %o0, 0xa, %o0
0x13A6C    13 00 00 3f    sethi  %hi(0xfc00), %o1                ! Build high part of constant/address.
0x13A70    90 0a 00 09    and  %o0, %o1, %o0
0x13A74    90 12 21 e0    or  %o0, 0x1e0, %o0
0x13A78    d0 24 a0 04    st  %o0, [ %l2 + 4 ]
0x13A7C    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x13A80    81 e8 00 00    restore                                ! Restore previous register window.
0x13A84    30 00 0a 08    unknown                                ! Undecodable word; may be data or erased flash.
0x13A88    30 00 0a 14    unknown                                ! Undecodable word; may be data or erased flash.
0x13A8C    30 00 0a 20    unknown                                ! Undecodable word; may be data or erased flash.
0x13A90    30 00 0a 2c    unknown                                ! Undecodable word; may be data or erased flash.
0x13A94    30 00 0a 38    unknown                                ! Undecodable word; may be data or erased flash.
0x13A98    30 00 0a 44    unknown                                ! Undecodable word; may be data or erased flash.
0x13A9C    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x13AA0    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x13AA4    92 12 23 8c    or  %o0, 0x38c, %o1                    ! 0x8783738c
0x13AA8    de 02 23 8c    ld  [ %o0 + 0x38c ], %o7
0x13AAC    31 0c 00 08    sethi  %hi(0x30002000), %i0            ! Build high part of constant/address.
0x13AB0    e0 02 60 18    ld  [ %o1 + 0x18 ], %l0
0x13AB4    15 08 00 08    sethi  %hi(0x20002000), %o2            ! Build high part of constant/address.
0x13AB8    c4 02 60 04    ld  [ %o1 + 4 ], %g2
0x13ABC    94 12 a0 2c    or  %o2, 0x2c, %o2
0x13AC0    da 02 60 08    ld  [ %o1 + 8 ], %o5
0x13AC4    86 10 20 1f    mov  0x1f, %g3
0x13AC8    d8 02 60 0c    ld  [ %o1 + 0xc ], %o4
0x13ACC    82 10 00 0a    mov  %o2, %g1
0x13AD0    d6 02 60 10    ld  [ %o1 + 0x10 ], %o3
0x13AD4    de 26 00 00    st  %o7, [ %i0 ]
0x13AD8    d0 02 60 14    ld  [ %o1 + 0x14 ], %o0
0x13ADC    c4 26 20 04    st  %g2, [ %i0 + 4 ]
0x13AE0    da 26 20 08    st  %o5, [ %i0 + 8 ]
0x13AE4    d8 26 20 0c    st  %o4, [ %i0 + 0xc ]
0x13AE8    d6 26 20 10    st  %o3, [ %i0 + 0x10 ]
0x13AEC    d0 26 20 14    st  %o0, [ %i0 + 0x14 ]
0x13AF0    e0 26 20 18    st  %l0, [ %i0 + 0x18 ]
0x13AF4    c6 22 80 00    st  %g3, [ %o2 ]
0x13AF8    d0 00 40 00    ld  [ %g1 ], %o0
0x13AFC    80 8a 20 20    btst  0x20, %o0
0x13B00    02 bf ff fe    be  0x13af8                            ! Conditional/control branch; inspect delay slot.
0x13B04    21 08 00 08    sethi  %hi(0x20002000), %l0            ! Build high part of constant/address.
0x13B08    a0 14 20 0c    or  %l0, 0xc, %l0                      ! 0x2000200c
0x13B0C    90 10 20 08    mov  8, %o0
0x13B10    d0 24 00 00    st  %o0, [ %l0 ]
0x13B14    7f ff fe 3b    call  0x13400                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13B18    90 10 20 05    mov  5, %o0
0x13B1C    90 10 20 09    mov  9, %o0
0x13B20    92 10 00 10    mov  %l0, %o1
0x13B24    d0 24 00 00    st  %o0, [ %l0 ]
0x13B28    d0 02 40 00    ld  [ %o1 ], %o0
0x13B2C    80 8a 20 08    btst  8, %o0
0x13B30    12 bf ff fe    bne  0x13b28                           ! Conditional/control branch; inspect delay slot.
0x13B34    11 00 00 08    sethi  %hi(0x2000), %o0                ! Build high part of constant/address.
0x13B38    13 08 00 08    sethi  %hi(0x20002000), %o1            ! Build high part of constant/address.
0x13B3C    94 12 60 08    or  %o1, 8, %o2                        ! 0x20002008
0x13B40    d0 22 80 00    st  %o0, [ %o2 ]
0x13B44    92 12 60 0c    or  %o1, 0xc, %o1
0x13B48    90 10 20 0b    mov  0xb, %o0
0x13B4C    94 10 00 09    mov  %o1, %o2
0x13B50    d0 22 40 00    st  %o0, [ %o1 ]
0x13B54    d0 02 80 00    ld  [ %o2 ], %o0
0x13B58    80 8a 20 08    btst  8, %o0
0x13B5C    12 bf ff fe    bne  0x13b54                           ! Conditional/control branch; inspect delay slot.
0x13B60    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x13B64    d0 06 20 14    ld  [ %i0 + 0x14 ], %o0
0x13B68    15 08 00 08    sethi  %hi(0x20002000), %o2            ! Build high part of constant/address.
0x13B6C    92 12 a0 08    or  %o2, 8, %o1                        ! 0x20002008
0x13B70    90 12 21 00    or  %o0, 0x100, %o0
0x13B74    d0 22 40 00    st  %o0, [ %o1 ]
0x13B78    94 12 a0 0c    or  %o2, 0xc, %o2
0x13B7C    90 10 20 0b    mov  0xb, %o0
0x13B80    92 10 00 0a    mov  %o2, %o1
0x13B84    d0 22 80 00    st  %o0, [ %o2 ]
0x13B88    d0 02 40 00    ld  [ %o1 ], %o0
0x13B8C    80 8a 20 08    btst  8, %o0
0x13B90    12 bf ff fe    bne  0x13b88                           ! Conditional/control branch; inspect delay slot.
0x13B94    01 00 00 00    nop                                    ! No operation (possibly delay slot or padding).
0x13B98    7f ff fe 1a    call  0x13400                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13B9C    90 10 20 05    mov  5, %o0                            ! 0x5
0x13BA0    11 08 00 08    sethi  %hi(0x20002000), %o0            ! Build high part of constant/address.
0x13BA4    90 12 20 0c    or  %o0, 0xc, %o0                      ! 0x2000200c
0x13BA8    92 10 20 09    mov  9, %o1
0x13BAC    94 10 00 08    mov  %o0, %o2
0x13BB0    d2 22 00 00    st  %o1, [ %o0 ]
0x13BB4    d0 02 80 00    ld  [ %o2 ], %o0
0x13BB8    80 8a 20 08    btst  8, %o0
0x13BBC    12 bf ff fe    bne  0x13bb4                           ! Conditional/control branch; inspect delay slot.
0x13BC0    11 08 00 08    sethi  %hi(0x20002000), %o0            ! Build high part of constant/address.
0x13BC4    90 12 20 0c    or  %o0, 0xc, %o0                      ! 0x2000200c
0x13BC8    92 10 20 0a    mov  0xa, %o1
0x13BCC    94 10 00 08    mov  %o0, %o2
0x13BD0    d2 22 00 00    st  %o1, [ %o0 ]
0x13BD4    d0 02 80 00    ld  [ %o2 ], %o0
0x13BD8    80 8a 20 08    btst  8, %o0
0x13BDC    12 bf ff fe    bne  0x13bd4                           ! Conditional/control branch; inspect delay slot.
0x13BE0    11 08 00 08    sethi  %hi(0x20002000), %o0            ! Build high part of constant/address.
0x13BE4    90 12 20 0c    or  %o0, 0xc, %o0                      ! 0x2000200c
0x13BE8    92 10 20 0a    mov  0xa, %o1
0x13BEC    94 10 00 08    mov  %o0, %o2
0x13BF0    d2 22 00 00    st  %o1, [ %o0 ]
0x13BF4    d0 02 80 00    ld  [ %o2 ], %o0
0x13BF8    80 8a 20 08    btst  8, %o0
0x13BFC    12 bf ff fe    bne  0x13bf4                           ! Conditional/control branch; inspect delay slot.
0x13C00    13 08 00 08    sethi  %hi(0x20002000), %o1            ! Build high part of constant/address.
0x13C04    d4 06 20 14    ld  [ %i0 + 0x14 ], %o2
0x13C08    90 12 60 08    or  %o1, 8, %o0
0x13C0C    d4 22 00 00    st  %o2, [ %o0 ]
0x13C10    92 12 60 0c    or  %o1, 0xc, %o1
0x13C14    90 10 20 0b    mov  0xb, %o0
0x13C18    94 10 00 09    mov  %o1, %o2
0x13C1C    d0 22 40 00    st  %o0, [ %o1 ]
0x13C20    d0 02 80 00    ld  [ %o2 ], %o0
0x13C24    80 8a 20 08    btst  8, %o0
0x13C28    12 bf ff fe    bne  0x13c20                           ! Conditional/control branch; inspect delay slot.
0x13C2C    13 08 00 08    sethi  %hi(0x20002000), %o1            ! Build high part of constant/address.
0x13C30    da 06 20 04    ld  [ %i0 + 4 ], %o5
0x13C34    96 12 60 08    or  %o1, 8, %o3
0x13C38    11 00 00 20    sethi  %hi(0x8000), %o0                ! Build high part of constant/address.
0x13C3C    d0 22 c0 00    st  %o0, [ %o3 ]
0x13C40    d6 06 00 00    ld  [ %i0 ], %o3
0x13C44    94 12 60 04    or  %o1, 4, %o2
0x13C48    da 22 80 00    st  %o5, [ %o2 ]
0x13C4C    d8 06 20 08    ld  [ %i0 + 8 ], %o4
0x13C50    90 12 60 10    or  %o1, 0x10, %o0
0x13C54    d6 22 40 00    st  %o3, [ %o1 ]
0x13C58    d4 06 20 0c    ld  [ %i0 + 0xc ], %o2
0x13C5C    d8 22 00 00    st  %o4, [ %o0 ]
0x13C60    d6 06 20 10    ld  [ %i0 + 0x10 ], %o3
0x13C64    90 12 60 14    or  %o1, 0x14, %o0
0x13C68    d4 22 00 00    st  %o2, [ %o0 ]
0x13C6C    92 12 60 20    or  %o1, 0x20, %o1
0x13C70    11 00 00 30    sethi  %hi(0xc000), %o0                ! Build high part of constant/address.
0x13C74    d6 22 40 00    st  %o3, [ %o1 ]
0x13C78    7f ff fd e2    call  0x13400                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13C7C    90 12 23 50    or  %o0, 0x350, %o0
0x13C80    15 00 00 15    sethi  %hi(0x5400), %o2                ! Build high part of constant/address.
0x13C84    13 20 00 00    sethi  %hi(0x80000000), %o1            ! Build high part of constant/address.
0x13C88    94 12 a1 aa    or  %o2, 0x1aa, %o2
0x13C8C    11 00 00 37    sethi  %hi(0xdc00), %o0                ! Build high part of constant/address.
0x13C90    96 12 22 ad    or  %o0, 0x2ad, %o3                    ! 0xdead
0x13C94    d4 22 40 00    st  %o2, [ %o1 ]
0x13C98    98 12 60 04    or  %o1, 4, %o4
0x13C9C    d6 23 00 00    st  %o3, [ %o4 ]
0x13CA0    d0 02 40 00    ld  [ %o1 ], %o0
0x13CA4    80 a2 00 0a    cmp  %o0, %o2
0x13CA8    12 80 00 06    bne  0x13cc0                           ! Conditional/control branch; inspect delay slot.
0x13CAC    b0 10 3f ff    mov  -1, %i0
0x13CB0    d0 03 00 00    ld  [ %o4 ], %o0
0x13CB4    80 a2 00 0b    cmp  %o0, %o3
0x13CB8    22 80 00 02    be,a   0x13cc0                         ! Conditional/control branch; inspect delay slot.
0x13CBC    b0 10 20 00    clr  %i0
0x13CC0    81 c7 e0 08    ret                                    ! Return; next instruction is the delay slot.
0x13CC4    81 e8 00 00    restore                                ! Restore previous register window.
0x13CC8    9d e3 bf 98    save  %sp, -104, %sp                   ! Enter register window; allocate stack frame.
0x13CCC    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x13CD0    55 e0 c7 62    call  0x57845a58                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13CD4    90 12 23 38    or  %o0, 0x338, %o0                    ! 0x87836f38
0x13CD8    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x13CDC    a2 12 23 8c    or  %o0, 0x38c, %l1                    ! 0x8783738c
0x13CE0    55 e0 c7 97    call  0x57845b3c                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13CE4    d0 04 60 18    ld  [ %l1 + 0x18 ], %o0
0x13CE8    13 21 e0 dc    sethi  %hi(0x87837000), %o1            ! Build high part of constant/address.
0x13CEC    d0 0a 63 b0    ldub  [ %o1 + 0x3b0 ], %o0             ! 0x878373b0
0x13CF0    80 a2 20 00    cmp  %o0, 0
0x13CF4    02 80 00 05    be  0x13d08                            ! Conditional/control branch; inspect delay slot.
0x13CF8    a6 10 00 09    mov  %o1, %l3
0x13CFC    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x13D00    55 e0 d6 08    call  0x57849520                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13D04    90 12 23 40    or  %o0, 0x340, %o0                    ! 0x87836f40
0x13D08    90 0e 20 ff    and  %i0, 0xff, %o0
0x13D0C    b0 92 20 00    orcc  %o0, 0, %i0
0x13D10    02 80 00 11    be  0x13d54                            ! Conditional/control branch; inspect delay slot.
0x13D14    a0 10 20 00    clr  %l0
0x13D18    11 08 00 02    sethi  %hi(0x20000800), %o0            ! Build high part of constant/address.
0x13D1C    a4 12 20 0c    or  %o0, 0xc, %l2                      ! 0x2000080c
0x13D20    92 0c 20 ff    and  %l0, 0xff, %o1
0x13D24    90 0a 60 07    and  %o1, 7, %o0
0x13D28    d4 04 60 18    ld  [ %l1 + 0x18 ], %o2
0x13D2C    92 02 60 01    inc  %o1
0x13D30    d2 24 80 00    st  %o1, [ %l2 ]
0x13D34    90 02 20 01    inc  %o0
0x13D38    55 e0 cb dc    call  0x57846ca8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13D3C    13 20 00 00    sethi  %hi(0x80000000), %o1            ! Build high part of constant/address.
0x13D40    a0 04 20 01    inc  %l0
0x13D44    90 0c 20 ff    and  %l0, 0xff, %o0
0x13D48    80 a2 00 18    cmp  %o0, %i0
0x13D4C    2a bf ff f6    bcs,a   0x13d24
0x13D50    92 0c 20 ff    and  %l0, 0xff, %o1
0x13D54    80 a6 20 18    cmp  %i0, 0x18
0x13D58    12 80 00 0c    bne  0x13d88                           ! Conditional/control branch; inspect delay slot.
0x13D5C    d0 0c e3 b0    ldub  [ %l3 + 0x3b0 ], %o0
0x13D60    11 21 e0 dc    sethi  %hi(0x87837000), %o0            ! Build high part of constant/address.
0x13D64    b0 12 23 8c    or  %o0, 0x38c, %i0                    ! 0x8783738c
0x13D68    a0 10 20 00    clr  %l0
0x13D6C    90 0c 20 07    and  %l0, 7, %o0
0x13D70    d4 06 20 18    ld  [ %i0 + 0x18 ], %o2
0x13D74    90 02 20 01    inc  %o0
0x13D78    55 e0 cb cc    call  0x57846ca8                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13D7C    13 20 00 00    sethi  %hi(0x80000000), %o1            ! Build high part of constant/address.
0x13D80    10 bf ff fb    b  0x13d6c                             ! Conditional/control branch; inspect delay slot.
0x13D84    a0 04 20 01    inc  %l0
0x13D88    80 a2 20 00    cmp  %o0, 0
0x13D8C    22 80 00 06    be,a   0x13da4                         ! Conditional/control branch; inspect delay slot.
0x13D90    11 08 00 02    sethi  %hi(0x20000800), %o0            ! Build high part of constant/address.
0x13D94    11 21 e0 db    sethi  %hi(0x87836c00), %o0            ! Build high part of constant/address.
0x13D98    55 e0 d5 e2    call  0x57849520                       ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13D9C    90 12 23 50    or  %o0, 0x350, %o0                    ! 0x87836f50
0x13DA0    11 08 00 02    sethi  %hi(0x20000800), %o0            ! Build high part of constant/address.
0x13DA4    13 08 00 00    sethi  %hi(0x20000000), %o1            ! Build high part of constant/address.
0x13DA8    90 12 20 0c    or  %o0, 0xc, %o0
0x13DAC    94 10 20 ff    mov  0xff, %o2
0x13DB0    a4 12 60 94    or  %o1, 0x94, %l2
0x13DB4    a2 12 60 14    or  %o1, 0x14, %l1
0x13DB8    d4 22 00 00    st  %o2, [ %o0 ]
0x13DBC    31 00 00 92    sethi  %hi(0x24800), %i0               ! Build high part of constant/address.
0x13DC0    a0 10 20 01    mov  1, %l0
0x13DC4    7f ff fd 8f    call  0x13400                          ! Call target; next instruction executes in delay slot. Verify target mapping.
0x13DC8    90 16 21 f0    or  %i0, 0x1f0, %o0
0x13DCC    d0 04 40 00    ld  [ %l1 ], %o0
0x13DD0    80 8a 28 00    btst  0x800, %o0
0x13DD4    32 bf ff fc    bne,a   0x13dc4                        ! Conditional/control branch; inspect delay slot.
0x13DD8    e0 24 80 00    st  %l0, [ %l2 ]
0x13DDC    30 bf ff fa    b,a   0x13dc4                          ! Conditional/control branch; inspect delay slot.
0x13DE0    86 10 20 80    mov  0x80, %g3
0x13DE4    96 10 20 80    mov  0x80, %o3
0x13DE8    82 10 20 00    clr  %g1
0x13DEC    9a 10 20 00    clr  %o5
0x13DF0    98 10 20 00    clr  %o4
0x13DF4    80 8a c0 09    btst  %o3, %o1
0x13DF8    32 80 00 02    bne,a   0x13e00                        ! Conditional/control branch; inspect delay slot.
0x13DFC    9a 13 40 03    or  %o5, %g3, %o5
0x13E00    85 30 e0 01    srl  %g3, 1, %g2
0x13E04    80 8a c0 08    btst  %o3, %o0
0x13E08    02 80 00 03    be  0x13e14                            ! Conditional/control branch; inspect delay slot.
0x13E0C    86 10 00 02    mov  %g2, %g3
0x13E10    9a 13 40 02    or  %o5, %g2, %o5
0x13E14    98 03 20 01    inc  %o4
0x13E18    84 0b 20 ff    and  %o4, 0xff, %g2
0x13E1C    80 a0 a0 03    cmp  %g2, 3
0x13E20    87 30 e0 01    srl  %g3, 1, %g3
0x13E24    08 bf ff f4    bleu  0x13df4                          ! Conditional/control branch; inspect delay slot.
0x13E28    97 32 e0 01    srl  %o3, 1, %o3
0x13E2C    86 10 20 80    mov  0x80, %g3
0x13E30    98 10 20 00    clr  %o4
0x13E34    80 8a c0 09    btst  %o3, %o1
0x13E38    32 80 00 02    bne,a   0x13e40                        ! Conditional/control branch; inspect delay slot.
0x13E3C    82 10 40 03    or  %g1, %g3, %g1
0x13E40    85 30 e0 01    srl  %g3, 1, %g2
0x13E44    80 8a c0 08    btst  %o3, %o0
0x13E48    02 80 00 03    be  0x13e54                            ! Conditional/control branch; inspect delay slot.
0x13E4C    86 10 00 02    mov  %g2, %g3
0x13E50    82 10 40 02    or  %g1, %g2, %g1
0x13E54    98 03 20 01    inc  %o4
0x13E58    84 0b 20 ff    and  %o4, 0xff, %g2
0x13E5C    80 a0 a0 03    cmp  %g2, 3
0x13E60    87 30 e0 01    srl  %g3, 1, %g3
0x13E64    08 bf ff f4    bleu  0x13e34                          ! Conditional/control branch; inspect delay slot.
0x13E68    97 32 e0 01    srl  %o3, 1, %o3
0x13E6C    c2 2a a0 01    stb  %g1, [ %o2 + 1 ]
0x13E70    81 c3 e0 08    retl                                   ! Return; next instruction is the delay slot.
0x13E74    da 2a 80 00    stb  %o5, [ %o2 ]

! Erased NAND: 0x13E78-0x13FFB (388 bytes of FF); omitted.

0x13FFC    3f d1 32 8f    cb012,a   0x460a38

/********************************************************************
 * Casm - some core utilities implemented in GNU assembly.
 *
 * Copyright 2020 Nick Pillitteri
 *
 * Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
 * http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
 * <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
 * option. This file may not be copied, modified, or distributed
 * except according to those terms.
 *******************************************************************/

    /* sync implementation */

    .data

help_msg:
    .ascii "Usage: sync [OPTION]... \n"
    .ascii "\n"
    .ascii "Synchronize cached writes to persitent storage.\n"
    .ascii "\n"
    .ascii "Options:\n"
    .ascii "\t--help\tShow this help\n"
    .byte  0

help_long:
    .asciz "--help"

    .text

    .global _start

/**
 * Entry point - synchronize cached writes to persitent storage or show help
 */
_start:
    /*
     * (rsp) = argc
     * (rsp + 8 + 8 * n ) = argv[n]
     *
     * r12 = argc
     * r13 = n loop variable
     */
    movq (%rsp), %r12
    movq $1, %r13 /* start at 1, skip argv[0] */

    cmp $1, %r12
    je .sync_writes  /* if there's only one argv value, sync */
    jmp .parse_cli_flags /* otherwise, parse CLI flags */

.parse_cli_flags:
    /* compare argv[n] to "--help" */
    movq 8(%rsp, %r13, 8), %rdi
    lea help_long, %rsi
    call c_str_eq
    cmp $0, %rax
    je .show_help

    /* if n is less than argc, try the next argument */
    inc %r13
    cmp %r12, %r13
    jl .parse_cli_flags

    /* we've parsed all CLI flags looking for "--help", sync */
    movq $1, %r13 /* reset n */
    jmp .sync_writes

.sync_writes:
    movq $162, %rax
    syscall
    jmp .exit_success

.show_help:
    lea help_msg, %rdi
    call print_c_str
    jmp .exit_success

.exit_success:
    call close_std_fds
    call exit_success

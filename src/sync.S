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
     * r12 = argc
     */
    movq (%rsp), %r12

    cmp $1, %r12
    je .sync_writes  /* if there's only one argv value, sync */
    jmp .parse_cli_flags /* otherwise, parse CLI flags */

.parse_cli_flags:
    /* check for a "--help" flag or just sync */
    movq %rsp, %rdi
    lea help_long, %rsi
    call cli_flag_exists

    cmp $1, %rax
    je .show_help
    jmp .sync_writes

.sync_writes:
    movq $162, %rax
    syscall
    jmp .exit_success

.show_help:
    lea help_msg, %rdi
    call c_str_print
    jmp .exit_success

.exit_success:
    call close_std_fds
    call exit_success

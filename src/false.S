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

    /* "false" implementation */

    .data

help_msg:
    .ascii "Usage: false [OPTION]... \n"
    .ascii "\n"
    .ascii "Immediately exit with an error.\n"
    .ascii "\n"
    .ascii "Options:\n"
    .ascii "\t--help\tShow this help\n"
    .byte  0

help_long:
    .asciz "--help"

    .text

    .global _start

/**
 * Entry point - exit with an error (status 1), optionally showing a help message
 */
_start:
    /*
     * r12 = argc
     */
    movq (%rsp), %r12
    cmp $1, %r12
    je .exit_error  /* if there's only one argv value, exit */

.parse_cli_flags:
    /* check for a "--help" flag or just exit */
    movq %rsp, %rdi
    movq $help_long, %rsi
    call cli_flag_exists

    cmp $1, %rax
    jge .show_help
    jmp .exit_error

.show_help:
    movq $help_msg, %rdi
    call c_str_print
    jmp .exit_error

.exit_error:
    call close_std_fds
    call exit_error

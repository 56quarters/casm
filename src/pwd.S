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

    /* pwd implementation */

    .data

/* 4K buffer for our path */
buf:
    .space 1024 * 4, 0x0
    buf_len = . - buf

help_msg:
    .ascii "Usage: pwd [OPTION]...\n"
    .ascii "\n"
    .ascii "Print the name of the current/working directory.\n"
    .ascii "\n"
    .ascii "Options:\n"
    .ascii "\t--help\tShow this help\n"
    .byte  0

help_long:
    .asciz "--help"

error_msg_bad_write:
    .asciz "pwd: write error\n"

error_msg_bad_call:
    .asciz "pwd: could not determine working directory\n"

    .text

    .global _start

/**
 * Entry point - print the current working directory and exit
 */
_start:
    /*
     * (rsp) = argc
     * (rsp + 8 + 8 * n ) = argv[n]
     *
     * r12 = argc
     * r13 = n loop variable
     * r14 = buffer address + offset
     */
    movq (%rsp), %r12
    movq $1, %r13 /* start at 1, skip argv[0] */
    movq $buf, %r14

    cmp $1, %r12
    je .print_directory

.parse_cli_flags:
    /* check for a "--help" flag */
    movq %rsp, %rdi
    movq $help_long, %rsi
    call cli_flag_exists

    cmp $1, %rax
    jge .show_help

.print_directory:
    movq $79, %rax
    movq $buf, %rdi
    movq $buf_len, %rsi
    syscall

    /* if the syscall fails for some reason */
    cmp $0, %rax
    jl .error_bad_call

    /* add the length of the string copied */
    add %rax, %r14
    /* add a newline as the last, byte replacing the final null
    byte the getcwd() added for some reason (by including it in
    the length returned) */
    dec %r14
    movb $'\n', (%r14)

    movq $buf, %rdi
    call c_str_print

    /* if we couldn't print to stdout, print to stderr and exit */
    cmp $0, %rax
    jl .error_write
    jmp .exit_success

.show_help:
    movq $help_msg, %rdi
    call c_str_print
    jmp .exit_success

.error_bad_call:
    movq $error_msg_bad_call, %rdi
    call c_str_eprint
    jmp .exit_error

.error_write:
    movq $error_msg_bad_write, %rdi
    call c_str_eprint
    jmp .exit_error

.exit_error:
    call close_std_fds
    call exit_error

.exit_success:
    call close_std_fds
    call exit_success

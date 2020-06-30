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

    /* sleep implementation */

    .data

/* struct timespec to pass to nanosleep() as requested or remaining time */
timespec:
    .space 8, 0x0 /* 8 bytes for "tv_sec" */
    .space 8, 0x0 /* 8 bytes for "tv_nsec" */

/* 4K buffer for arguments */
buf:
    .space 1024 * 4, 0x0
    buf_len = . - buf

help_msg:
    .ascii "Usage: sleep [OPTION]... [NUMBER][SUFFIX]...\n"
    .ascii "\n"
    .ascii "Sleep for NUMBER seconds (by default). SUFFIX can be s for seconds,\n"
    .ascii "m for minutes, h for hours, or d for days. If more than a single\n"
    .ascii "argument is given, sleep for the sum of their values.\n"
    .ascii "\n"
    .ascii "Options:\n"
    .ascii "\t--help\tShow this help\n"
    .byte  0

help_long:
    .asciz "--help"

error_msg_no_arguments:
    .asciz "sleep: no arguments supplied\n"

error_msg_bad_time:
    .asciz "sleep: invalid time supplied\n"

error_msg_bad_unit:
    .asciz "sleep: invalid time unit supplied\n"

    .text

    .global _start

/**
 * Entry point - sleep for a duration of time
 */
_start:
    /*
     * (rsp) = argc
     * (rsp + 8 + 8 * n ) = argv[n]
     *
     * r12 = argc
     * r13 = n loop variable
     * r14 = seconds to sleep per argument
     * r15 = seconds to sleep total
     */
    movq (%rsp), %r12
    movq $1, %r13 /* start at 1, skip argv[0] */

    cmp $1, %r12
     /* if there are no args, error */
    je .error_no_arguments

.parse_cli_flags:
    /* check for a "--help" flag */
    movq %rsp, %rdi
    lea help_long, %rsi
    call cli_flag_exists

    cmp $1, %rax
    je .show_help

.read_from_argv:
    /* parse each argv[n] into some number of seconds to sleep */
    movq  8(%rsp, %r13, 8), %rdi
    call c_str_to_number
    cmp $0, %rax
    je .error_invalid_time

    /* base number, not yet scaled by unit */
    movq %rax, %r14

    movq 8(%rsp, %r13, 8), %rdi
    call parse_unit
    cmp $0, %rax
    je .error_invalid_unit

    /* multiply the number by the unit scale, then add to total */
    imul %rax, %r14
    add %r14, %r15

    inc %r13
    cmp %r12, %r13
    jl .read_from_argv

.sleep_for_time:
    /* sleep the total amount from all arguments (stored in r15) */
    movq %r15, %rdi
    call sleep_time
    jmp .exit_success

.show_help:
    lea help_msg, %rdi
    call c_str_print
    jmp .exit_success

.error_no_arguments:
    lea error_msg_no_arguments, %rdi
    call c_str_eprint
    jmp .exit_error

.error_invalid_time:
    lea error_msg_bad_time, %rdi
    call c_str_eprint
    jmp .exit_error

.error_invalid_unit:
    lea error_msg_bad_unit, %rdi
    call c_str_eprint
    jmp .exit_error

.exit_error:
    call close_std_fds
    call exit_error

.exit_success:
    call close_std_fds
    call exit_success

/**
 * Determine the scaling factor of a time unit based on user input (c string)
 *
 * rdi = c string (null terminated) user input, probably something like '30s'
 * rax = return, scaling factor or 0 on error
 */
parse_unit:
    push %r12
    movq %rdi, %r12

.examine_byte:
    movb (%r12), %dil
    call is_digit
    cmp $0, %rax
    je .parse_str

.skip_byte:
    inc %r12
    jmp .examine_byte

.parse_str:
    movb (%r12), %dil
    call byte_to_unit

.end_parse_unit:
    pop %r12
    ret

/**
 * Determine the scale for a time unit based on an ascii byte, relative to seconds
 *
 * s -> seconds, 1
 * m -> minutes, 60
 * h -> hours, 3600
 * d -> days, 86400
 * [missing] -> seconds, 1
 * [invalid] -> error, 0
 *
 * dil = byte to convert to a scale
 * rax = return, scaling factor or 0 on error
 */
byte_to_unit:
    /* null byte? default to seconds */
    cmpb $0, %dil
    je .unit_second

    /* seconds? */
    cmpb $'s', %dil
    je .unit_second

    /* minutes? */
    cmpb $'m', %dil
    je .unit_minute

    /* hours? */
    cmpb $'h', %dil
    je .unit_hour

    /* days? */
    cmpb $'d', %dil
    je .unit_day

    /* fall through for invalid units */
.unit_invalid:
    movq $0, %rax
    ret
.unit_second:
    movq $1, %rax
    ret
.unit_minute:
    movq $60, %rax
    ret
.unit_hour:
    movq $3600, %rax
    ret
.unit_day:
    movq $86400, %rax
    ret

/**
 * Sleep for some number of seconds via nanosleep()
 *
 * rdi = number of seconds to sleep
 */
sleep_time:
    movq %rdi, %r10
    /*
     * Set our structure as the first argument and null as the second.
     * We don't care about restarting if our call is interrupted, this
     * is handled automatically by the kernel on Linux.
     *
     * See https://lwn.net/Articles/17744/
     */
    lea timespec, %rdi
    movq $0, %rsi

    /* set the number of seconds to sleep and 0 nano seconds */
    movq %r10, (%rdi)
    movq $0, 8(%rdi)
    movq $35, %rax
    syscall
    ret

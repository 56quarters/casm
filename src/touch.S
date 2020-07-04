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

    /* touch implementation */

    .data

/* fcntl.h constants we need for creating a file via open() */
O_WRONLY   = 00000001
O_CREAT    = 00000100
O_NOCTTY   = 00000400
O_NONBLOCK = 00004000

/* fcntl.h constant for passing to utimensat() */
AT_FDCWD = -100

help_msg:
    .ascii "Usage: touch [OPTION]... [FILE]...\n"
    .ascii "\n"
    .ascii "Change FILE(s) timestamps.\n"
    .ascii "\n"
    .ascii "Options:\n"
    .ascii "\t--help\tShow this help\n"
    .byte  0

help_long:
    .asciz "--help"

stdout_file:
    .asciz "-"

error_msg_no_arguments:
    .asciz "touch: missing file argument\n"

error_msg_bad_open:
    .asciz "touch: could not create or update file\n"

    .text

    .global _start

/**
 * Entry point - create or update timestamps of files provided via argv
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
    je .error_no_arguments /* no arguments, error. otherwise parse CLI flags */

.parse_cli_flags:
    /* check for a "--help" flag */
    movq %rsp, %rdi
    lea help_long, %rsi
    call cli_flag_exists
    cmp $1, %rax
    jge .show_help

.touch_from_argv:
    /* try to open() argv[n] as a file or stdout for the name "-" */
    movq 8(%rsp, %r13, 8), %rdi
    call open_and_update
    cmp $0, %rax
    jl .error_bad_open

    inc %r13
    cmp %r12, %r13
    jl .touch_from_argv
    jmp .exit_success

.show_help:
    lea help_msg, %rdi
    call c_str_print
    jmp .exit_success

.error_no_arguments:
    lea error_msg_no_arguments, %rdi
    call c_str_eprint
    jmp .exit_error

.error_bad_open:
    lea error_msg_bad_open, %rdi
    call c_str_eprint
    jmp .exit_error

.exit_success:
    call close_std_fds
    call exit_success

.exit_error:
    call close_std_fds
    call exit_error

/**
 * Open a file of the given name (creating it if needed) or stdout if the file is "-"
 *
 * rdi = pointer to file name
 * rax = return, file descriptor
 */
open_file:
    /*
     * r12 = pointer to file name
     */
    push %r12
    movq %rdi, %r12

    /* check if the file name is just "-" for stdout */
    lea stdout_file, %rsi
    call c_str_eq
    cmp $0, %rax
    jne .open_name

.open_stdout:
    movq $1, %rax
    jmp .end_open_file

.open_name:
    movq $2, %rax
    movq %r12, %rdi
    movq $0, %rsi
    orq $O_WRONLY, %rsi
    orq $O_CREAT, %rsi
    orq $O_NOCTTY, %rsi
    orq $O_NONBLOCK, %rsi
    /* default to a mode of 666 since this will be &~ with the process umask */
    movq $0666, %rdx
    syscall

.end_open_file:
    pop %r12
    ret

/**
 * Close the given file descriptor if it isn't stdout (fd 1)
 *
 * rdi = file descriptor
 */
close_file:
    /* if the fd is stdout, don't close it */
    cmp $1, %rdi
    je .end_close_file

    /* otherwise, try to close it */
    movq $3, %rax
    syscall

.end_close_file:
    ret

/**
 * Open a file, creating it if it does not exist, and update it's modification and
 * access times.
 *
 * rdi = file path to update times
 * rax = return, 0 for success, -1 otherwise
 */
open_and_update:
    /*
     * r12 = file path
     * r13 = file descriptor if open or -1
     * r14 = return of updating times
     */
    push %r12
    push %r13
    push %r14

    movq %rdi, %r12
    movq $-1, %r13

    call open_file
    movq %rax, %r13
    cmp $0, %r13
    jl .update_by_path

.update_by_fd:
    /* note that we're calling utimensat(2) with the file descriptor as the first
    argument instead of directory descriptor and passing NULL for the file path.
    this isn't documented as something that *should* work but it does, it's what
    GNU touch seems to do, and it's less racey than doing open/close/uptime via
    file paths */
    movq $280, %rax
    movq %r13, %rdi
    movq $0, %rsi
    movq $0, %rdx
    movq $0, %rcx
    syscall

    /* preserve the return value from the update while we close the fd */
    movq %rax, %r14

    /* close the file descriptor */
    movq %r13, %rdi
    call close_file

    /* restore return value from the update and return */
    movq %r14, %rax
    jmp .end_open_and_update

.update_by_path:
    /* call utimensat(2) the way it's documented and just give it the path to the
    file to update (this happens when we couldn't open the file in a writable mode
    such as when its permissions are 444 or similar). In this case, we'll still be
    able to update the modification times, just in a slightly more racey way */
    movq $280, %rax
    movq $AT_FDCWD, %rdi
    movq %r12, %rsi
    movq $0, %rdx
    movq $0, %rcx
    syscall

.end_open_and_update:
    pop %r14
    pop %r13
    pop %r12
    ret

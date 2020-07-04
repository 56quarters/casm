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

    /* CLI and process control methods */

    .text

    .global cli_flag_exists, close_std_fds, exit_success, exit_error

/**
 * Close stdin, stdout, and stderr
 */
close_std_fds:
    movq $3, %rax
    movq $0, %rdi
    syscall

    movq $3, %rax
    movq $1, %rdi
    syscall

    movq $3, %rax
    movq $2, %rdi
    syscall
    ret

/**
 * Exit the current process with status 0, killing all threads
 */
exit_success:
    /* exit_group() syscall with status 0 */
    movq $231, %rax
    movq $0, %rdi
    syscall
    ret

/**
 * Exit the current process with status 1, killing all threads
 */
exit_error:
    /* exit_group() syscall with status 1 */
    movq $231, %rax
    movq $1, %rdi
    syscall
    ret

/**
 * Return the number of times the CLI flag was passed as an on the stack
 *
 * rdi = process stack pointer, %rsp
 * rsi = pointer to c string (null terminated) for flag to check
 * rax = return, number of times the given flag appears in argv
 */
cli_flag_exists:
    /*
     * r12 = number of occurences
     * r13 = stack pointer
     * r14 = n (loop variable)
     * r15 = pointer to flag string
     */
    push %r12
    push %r13
    push %r14
    push %r15

    movq $0, %r12
    movq %rdi, %r13
    movq $1, %r14
    movq %rsi, %r15

    /* NOTE: we just deref the stack when we need to check argc */
    cmp $1, (%r13)
    je .end_cli_flag_exists

.check_each_arg:
    movq 8(%r13, %r14, 8), %rdi
    movq %r15, %rsi
    call c_str_eq
    cmp $0, %rax
    je .incr_found_count

.resume_check_each_arg:
    inc %r14
    cmp (%r13), %r14
    jl .check_each_arg
    jmp .end_cli_flag_exists

.incr_found_count:
    inc %r12
    jmp .resume_check_each_arg

.end_cli_flag_exists:
    movq %r12, %rax

    pop %r15
    pop %r14
    pop %r13
    pop %r12
    ret

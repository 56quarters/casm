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

    /* common methods */

    .text

    .global c_str_copy, c_str_eprint, c_str_eq, c_str_len, c_str_print
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
 * Return 0 if two c strings (null terminated) are equal, 1 otherwise
 *
 * rdi = pointer to first c string
 * rsi = pointer to second c string
 * rax = return
 */
c_str_eq:
    /*
     * r12 = pointer to first string
     * r13 = pointer to second string
     * r14b = scratch for char pointed to by r12
     */
    push %r12
    push %r13
    push %r14

    movq %rdi, %r12
    movq %rsi, %r13

.cmp_byte:
    /* if the current char isn't the same, not equal */
    mov (%r12), %r14b
    cmp %r14b, (%r13)
    jne .end_not_eq

    /* if the current char is null (we already know this holds for both strings), equal */
    cmpb $0, (%r12)
    je .end_eq

    /* otherwise, try the next byte */
    inc %r12
    inc %r13
    jmp .cmp_byte

.end_not_eq:
    movq $1, %rax
    jmp .end_c_str_eq

.end_eq:
    movq $0, %rax
    jmp .end_c_str_eq

.end_c_str_eq:
    pop %r14
    pop %r13
    pop %r12
    ret


/**
 * Write the contents of a c string (null terminated) to the given file descriptor
 *
 * rdi = pointer to c string to print
 * rsi = file descriptor
 */
c_str_write:
    /*
     * r12 = pointer to string to print
     * r13 = file descriptor
     */
    push %r12
    push %r13
    push %r14

    /* store the string + file descriptor for later */
    movq %rdi, %r12
    movq %rsi, %r13

    /* get the length of the string to give to write() */
    call c_str_len
    movq %rax, %r14

    /* write() the string to the given file descriptor */
    movq $1, %rax
    movq %r13, %rdi
    movq %r12, %rsi
    movq %r14, %rdx
    syscall

    pop %r14
    pop %r13
    pop %r12
    ret

/**
 * Print the contents of a c string (null terminated) to stdout
 *
 * rdi = pointer to c string to print
 */
c_str_print:
    movq $1, %rsi
    call c_str_write
    ret

/**
 * Print the contents of a c string (null terminated) to stderr
 *
 * rdi = pointer to c string to print
 */
c_str_eprint:
    movq $2, %rsi
    call c_str_write
    ret

/**
 * Return 1 if the given flag was passed as a CLI argument on the stack, 0 otherwise
 *
 * rdi = process stack pointer, %rsp
 * rsi = pointer to c string (null terminated) for flag to check
 * rax = return, 1 if the flag exists, 0 if it does not
 */
cli_flag_exists:
    /*
     * r12 = argc
     * r13 = stack pointer
     * r14 = n (loop variable)
     * r15 = pointer to flag string
     */
    push %r12
    push %r13
    push %r14
    push %r15

    movq (%rdi), %r12
    movq %rdi, %r13
    movq $1, %r14
    movq %rsi, %r15

    cmp $1, %r12
    je .flag_not_found
    jmp .check_each_arg

.check_each_arg:
    movq 8(%r13, %r14, 8), %rdi
    movq %r15, %rsi
    call c_str_eq
    cmp $0, %rax
    je .flag_found

    inc %r14
    cmp %r12, %r14
    jl .check_each_arg
    jmp .flag_not_found

.flag_found:
    movq $1, %rax
    jmp .end_cli_flag_exists

.flag_not_found:
    movq $0, %rax
    jmp .end_cli_flag_exists

.end_cli_flag_exists:
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    ret

/**
 * Return the number of bytes in a c string, not including the null byte
 *
 * rdi = pointer to a c string (null terminated)
 * rax = return, number of bytes in the string
 */
c_str_len:
    push %r12
    movq %rdi, %r12

.find_null:
    cmpb $0, (%r12)
    je .end_c_str_len
    inc %r12
    jmp .find_null

.end_c_str_len:
    /* length is r12 - rdi, stored in r12 */
    sub %rdi, %r12
    movq %r12, %rax
    pop %r12
    ret

/**
 * Copy the contents of a c string (null terminated) to a given buffer, omitting the null byte
 *
 * rdi = pointer to the c string to copy
 * rsi = pointer to the buffer to copy into
 * rax = return, the length of the c string copied not including the null byte
 */
c_str_copy:
    push %r12 /* source */
    push %r13 /* dest */
    push %r14 /* tmp */
    push %r15 /* length */

    movq %rdi, %r12
    movq %rsi, %r13
    movq $0, %r15

.copy_byte:
    movb (%r12), %r14b
    cmp $0, %r14b
    je .end_copy_c_str

    movb %r14b, (%r13)
    inc %r12
    inc %r13
    inc %r15
    jmp .copy_byte

.end_copy_c_str:
    movq %r15, %rax
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    ret

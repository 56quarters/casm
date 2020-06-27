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

    /* string methods */

    .text

    .global c_str_copy, c_str_eprint, c_str_eq, c_str_len, c_str_print, c_str_to_number, c_str_write, is_digit

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
 * rax = return, write result
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
 * rax = return, write result
 */
c_str_print:
    movq $1, %rsi
    call c_str_write
    ret

/**
 * Print the contents of a c string (null terminated) to stderr
 *
 * rdi = pointer to c string to print
 * rax = return, write result
 */
c_str_eprint:
    movq $2, %rsi
    call c_str_write
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
    /*
     * r12 = source pointer
     * r13 = destination pointer
     * r14 = string length
     * al = temporary byte
     */
    push %r12
    push %r13
    push %r14

    movq %rdi, %r12
    movq %rsi, %r13
    movq $0, %r14

.copy_byte:
    movb (%r12), %al
    cmp $0, %al
    je .end_copy_c_str

    movb %al, (%r13)
    inc %r12
    inc %r13
    inc %r14
    jmp .copy_byte

.end_copy_c_str:
    movq %r14, %rax
    pop %r14
    pop %r13
    pop %r12
    ret

/**
 * Convert a numeric c string (null terminated) to a positive integer, stopping as soon
 * as a non-digit is found. This method doesn't handle negative numbers or strings that
 * are completely non-numeric. In the case of non-numeric strings, 0 is returned
 *
 * Examples:
 * '12' => 12
 * '42s' => 42
 * '1x' => 1
 * 'a' => 0
 *
 * rdi = pointer to c string to convert to a number
 * rax = return, number represented by the string
 */
c_str_to_number:
    /*
     * r12 = pointer to c string
     * r13 = number result
     * r14 = tmp byte value
     */
    push %r12
    push %r13
    push %r14

    movq %rdi, %r12
    movq $0, %r13
    movq $0, %r14

.examine_byte:
    movb (%r12), %r14b

    movb %r14b, %dil
    call is_digit
    cmp $0, %rax
    je .end_c_str_to_number

    /* there's another digit so multiply our existing value
    by 10 and add the new value to it (after converting from
    an ascii number, 48 - 57, to the digit by subtracting 48) */
    imul $10, %r13
    sub $48, %r14b
    add %r14, %r13

    inc %r12
    jmp .examine_byte

.end_c_str_to_number:
    movq %r13, %rax
    pop %r14
    pop %r13
    pop %r12
    ret

/**
 * Return 1 if the given byte is an ascii digit, 0 otherwise
 *
 * dil = byte to check
 * rax = return, 1 for a digit 0 for non-digit
 */
is_digit:
    cmpb $48, %dil /* ascii 0 */
    jl .set_false
    cmpb $57, %dil /* ascii 9 */
    jg .set_false

    movq $1, %rax
    ret

.set_false:
    movq $0, %rax
    ret

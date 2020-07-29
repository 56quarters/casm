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

    /* base64 implementation */

    .data

/* 60K buffer for raw data. Note that this is evenly divisible by 3 (3:4 raw:encoded) */
raw_buf:
    .space 1024 * 60, 0x0
    raw_buf_len = . - raw_buf

/* 80k buffer for encoded data. Note that this is evenly divisible by 4 (3:4 raw:encoded) */
encoded_buf:
    .space 1024 * 80, 0x0
    encoded_buf_len = . - encoded_buf

/* array of base64 characters, indexed on the decimal value (0-63), mapped to their ascii character */
lookup:
    .byte \
      'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', \
      'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', \
      '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/'

help_msg:
    .ascii "Usage: base64 [OPTION]... [FILE]...\n"
    .ascii "\n"
    .ascii "Base64 encode or decode FILE(s) or standard input to standard output.\n"
    .ascii "\n"
    .ascii "When no FILE is provided or when FILE is -, read from standard input.\n"
    .ascii "\n"
    .ascii "Options:\n"
    .ascii "\t--help\t\tShow this help\n"
    .ascii "\t--decode\tDecode data instead of encoding\n"
    .ascii "\t--wrap\tWrap output at 76 columns\n"
    .byte  0

help_long:
    .asciz "--help"

decode_long:
    .asciz "--decode"

wrap_long:
    .asciz "--wrap"

decode_val:
    .quad 0

wrap_val:
    .quad 0

error_msg_bad_open:
    .asciz "base64: could not open file\n"

error_msg_bad_write:
    .asciz "base64: read/write error\n"

    .text

    .global _start

unimplemented_msg:
    .asciz "base64: decoding not implemented\n"

/**
 * Entry point - read from stdin or a file and write unwrapped base64 text to stdout.
 *
 * Exit when EOF is recieved on stdin or when the file passed via argv has been read.
 * If the file cannot be read, the program will exit with an error (non-zero) status.
 */
_start:
    /*
     * (rsp) = argc
     * (rsp + 8 + 8 * n ) = argv[n]
     *
     * r12 = argc
     * r13 = n loop variable
     * r14 = current file descriptor
     */
    mov (%rsp), %r12
    mov $1, %r13 /* start at 1, skip argv[0] */

.parse_cli_flags:
    /* check for a "--help" flag */
    mov %rsp, %rdi
    mov $help_long, %rsi
    call cli_flag_exists
    cmp $1, %rax
    jge .show_help

    /* check for "--decode" flag and potentially increment r13 (n) */
    mov %rsp, %rdi
    mov $decode_long, %rsi
    call cli_flag_exists
    mov %rax, decode_val
    add %rax, %r13

    /* check for "--wrap" flag and potentially increment r13 (n) */
    mov %rsp, %rdi
    mov $wrap_long, %rsi
    call cli_flag_exists
    mov %rax, wrap_val
    add %rax, %r13

.determine_read_source:
    /* if n is < argc, treat remaining arguments as files, otherwise read from stdin */
    cmp %r12, %r13
    jl .read_from_argv

.read_from_stdin:
    /* default to using fd 0 (stdin) for reads, fd 1 (stdout) for writes */
    mov $0, %rdi
    mov $1, %rsi
    call encode_or_decode
    cmp $0, %rax
    jne .error_write
    jmp .exit_success

.read_from_argv:
    /* try to open() argv[n] as a file or stdin for the name "-" */
    mov 8(%rsp, %r13, 8), %rdi
    call open_file

    /* save opened file descriptor */
    mov %rax, %r14
    cmp $0, %r14
    /* exit with an error if the fd is < 0 */
    jl .error_bad_open

    /* read just opened file descriptor, write to stdout */
    mov %r14, %rdi
    mov $1, %rsi
    call encode_or_decode
    cmp $0, %rax
    jne .error_write

    /* close file descriptor */
    mov %r14, %rdi
    call close_file

    /* if n is less than argc, open the next file */
    inc %r13
    cmp %r12, %r13
    jl .read_from_argv

    /* otherwise, exit successfully since we've read all files */
    jmp .exit_success

.show_help:
    mov $help_msg, %rdi
    call c_str_print
    jmp .exit_success

.error_bad_open:
    mov $error_msg_bad_open, %rdi
    call c_str_eprint
    jmp .exit_error

.error_write:
    mov $error_msg_bad_write, %rdi
    call c_str_eprint
    jmp .exit_error

.exit_success:
    call close_std_fds
    call exit_success

.exit_error:
    call close_std_fds
    call exit_error


uc_to_bits:
    /* uppercase ASCII is 65 to 90, in base64 it's 0 to 25 */
    movb %dil, %al
    subb $65, %al
    ret


lc_to_bits:
    /* lowercase ASCII is 97 to 122, in base64 it's 26 to 51 */
    movb %dil, %al
    subb $71, %al
    ret


digit_to_bits:
    /* digits in ASCII are 48 to 57, in base64 it's 52 to 61 */
    movb %dil, %al
    addb $4, %al
    ret


plus_to_bits:
    movb $62, %al
    ret


slash_to_bits:
    movb $63, %al
    ret




/**
 * Call either read_encode_write or read_decode_write based on the value of the
 * "--decode" CLI flag that is expected to be stored in the decode_val variable
 *
 * rdi = read file descriptor
 * rsi = write file descriptor
 * rax = return 0 for success, 1 for error
 */
encode_or_decode:
    /*
     * r8 = value of decode flag
     */
    mov decode_val, %r8
    cmp $0, %r8
    jne .call_decode
.call_encode:
    call read_encode_write
    ret
.call_decode:
    call read_decode_write
    ret

/**
 * Read raw bytes from an input buffer and write base64 encoded data to an
 * output buffer, returning the number of encoded bytes written. This method
 * assumes the output buffer has sufficient space for the encoded version of
 * the input.
 *
 * rdi = read buffer
 * rsi = length of read buffer
 * rdx = write buffer
 * rax = return, encoded bytes written
 */
encode:
    /*
     * r12 = read buffer pointer
     * r13 = write buffer pointer
     * r14 = ending pointer for read buffer
     * r15 = starting pointer for write buffer
     *
     * r8 = lookup table
     * r9 = up to three input bytes
     * r10 = masked value of input byte
     * r11 = translated character of masked value
     * rcx = bytes left to read (r14 - r12)
     */
    push %r12
    push %r13
    push %r14
    push %r15

    mov %rdi, %r12
    mov %rdx, %r13

    mov %rdi, %r14
    add %rsi, %r14
    mov %rdx, %r15
    mov $lookup, %r8

.encode_bytes:
    /* Based on the current read pointer (r12) and the pointer to the end
     * of the read buffer (r14), determine how many bytes are left to read
     * and encode. If there are three or more bytes left, load three into
     * a register and encode them as four, six-bit chunks with no padding.
     *
     * If there are two bytes left, encode them as three, six-bit chunks
     * with one character of padding.
     *
     * If there is a single byte left, encode it as two, six-bit chunks
     * and two characters padding.
     */
    mov %r14, %rcx
    sub %r12, %rcx

    cmp $0, %rcx
    je .end_encode

    cmp $2, %rcx
    jl .write_one_byte
    je .write_two_bytes

.write_three_bytes:
    /* Read three bytes of input and encode it as four characters of output.
     * This is the default chunk size since 24 bits the the least common
     * multiple of 8 bits (one byte of input) and 6 bits (number of bits
     * needed to encode something in base64).
     */
    mov $0, %r9
    movb (%r12), %r9b
    inc %r12

    shl $8, %r9
    movb (%r12), %r9b
    inc %r12

    shl $8, %r9
    movb (%r12), %r9b
    inc %r12

    /* Examine each 6 bit chunk of the input via masks */

    mov %r9, %r10
    and $0x00FC0000, %r10
    shr $18, %r10
    mov (%r8, %r10, 1), %r11 /* r11 := lookup[r10] */
    movb %r11b, (%r13)
    inc %r13

    mov %r9, %r10
    and $0x0003F000, %r10
    shr $12, %r10
    mov (%r8, %r10, 1), %r11
    movb %r11b, (%r13)
    inc %r13

    mov %r9, %r10
    and $0x00000FC0, %r10
    shr $6, %r10
    mov (%r8, %r10, 1), %r11
    movb %r11b, (%r13)
    inc %r13

    mov %r9, %r10
    and $0x0000003F, %r10
    mov (%r8, %r10, 1), %r11
    movb %r11b, (%r13)
    inc %r13

    jmp .encode_bytes

.write_two_bytes:
    /* Read two bytes of input and encode it as three characters of output
     * and one character of padding.
     */
    mov $0, %r9
    movb (%r12), %r9b
    inc %r12

    shl $8, %r9
    movb (%r12), %r9b
    inc %r12

    /* Examine each 6 bit chunk of the input via masks */

    mov %r9, %r10
    and $0x0000FC00, %r10
    shr $10, %r10
    mov (%r8, %r10, 1), %r11 /* r11 := lookup[r10] */
    movb %r11b, (%r13)
    inc %r13

    mov %r9, %r10
    and $0x000003F0, %r10
    shr $4, %r10
    mov (%r8, %r10, 1), %r11
    movb %r11b, (%r13)
    inc %r13

    mov %r9, %r10
    and $0x0000000F, %r10
    shl $2, %r10
    mov (%r8, %r10, 1), %r11
    movb %r11b, (%r13)
    inc %r13

    movb $'=', (%r13)
    inc %r13

    jmp .end_encode

.write_one_byte:
    /* Read one byte of input and encode it as two characters of output
     * and two characters of padding.
     */
    mov $0, %r9
    movb (%r12), %r9b
    inc %r12

    /* Examine each 6 bit chunk of the input via masks */

    mov %r9, %r10
    and $0x000000FC, %r10
    shr $2, %r10
    mov (%r8, %r10, 1), %r11 /* r11 := lookup[r10] */
    movb %r11b, (%r13)
    inc %r13

    mov %r9, %r10
    and $0x00000003, %r10
    shl $4, %r10
    mov (%r8, %r10, 1), %r11
    movb %r11b, (%r13)
    inc %r13

    movb $'=', (%r13)
    inc %r13
    movb $'=', (%r13)
    inc %r13

.end_encode:
    /* Return the number of bytes of encoded data written (r13 - r15) */
    sub %r15, %r13
    mov %r13, %rax

    pop %r15
    pop %r14
    pop %r13
    pop %r12
    ret

/**
 * Read base64 encode bytes from an input buffer and write raw data to an
 * output buffer, returning the number of raw bytes written. This method
 * assumes the output buffer has sufficient space for the decode version of
 * the input.
 *
 * rdi = read buffer
 * rsi = length of read buffer
 * rdx = write buffer
 * rax = return, raw bytes written
 */
decode:
    /* Short circuit for now */
    mov $unimplemented_msg, %rdi
    call c_str_eprint
    call exit_error

    /*
     * r12 = read buffer pointer
     * r13 = write buffer pointer
     * r14 = ending pointer for read buffer
     * r15 = starting pointer for write buffer
     */
    push %r12
    push %r13
    push %r14
    push %r15

    mov %rdi, %r12
    mov %rdx, %r13

    mov %rdi, %r14
    add %rsi, %r14
    mov %rdx, %r15

.decode_chars:
    /*
     * - figure out how many bytes left in read buffer
     * - if less than four, abort or something?
     */

.decode_four_chars:
    /* TODO:
     * - read byte from (r12) into register
     * - switch on the character with vaious is_ functions
     * - convert the character to 6 bits
     * - push those 6 bits into a register that will store 3 bytes
     * - shift
     * - read the rest of the characters
     * - copy each of the 3 bytes in the register to the write buffer
    */

.end_decode:
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    ret

/**
 * Read a file descriptor, base64 encode, and write to another file descriptor until EOF
 *
 * rdi = read file descriptor
 * rsi = write file descriptor
 * rax = return 0 for success, 1 for error
 */
read_encode_write:
    /*
     * r12 = read file descriptor
     * r13 = write file descriptor
     * r14 = bytes read
     */
    push %r12
    push %r13
    push %r14

    mov %rdi, %r12
    mov %rsi, %r13

.encode_read_buf:
    mov %r12, %rdi
    mov $raw_buf, %rsi
    mov $raw_buf_len, %rdx
    call read_from_fd

    cmp $0, %rax
    jl .encode_end_error   /* if bytes read is < 0, error */
    je .encode_end_success /* if bytes read == 0, end */
    /* otherwise, attempt to encode and write the results */
    mov %rax, %r14

.encode_buf:
    mov $raw_buf, %rdi
    mov %r14, %rsi
    mov $encoded_buf, %rdx
    call encode

    mov %rax, %r14 /* number of bytes encoded */

.encode_write_buf:
    mov %r13, %rdi
    mov $encoded_buf, %rsi
    mov %r14, %rdx
    call write_to_fd

    cmp $0, %rax
    jl .encode_end_error /* if bytes written < 0, error */
    jmp .encode_read_buf /* otherwise, attempt another read + write */

.encode_end_success:
    mov $0, %rax
    jmp .end_raw_to_encoded

.encode_end_error:
    mov $1, %rax
    jmp .end_raw_to_encoded

.end_raw_to_encoded:
    pop %r14
    pop %r13
    pop %r12
    ret

/**
 * Read a file descriptor, base64 decode, and write to another file descriptor until EOF
 *
 * rdi = read file descriptor
 * rsi = write file descriptor
 * rax = return 0 for success, 1 for error
 */
read_decode_write:
    /*
     * r12 = read file descriptor
     * r13 = write file descriptor
     * r14 = bytes read
     */
    push %r12
    push %r13
    push %r14

    mov %rdi, %r12
    mov %rsi, %r13

.decode_read_buf:
    mov %r12, %rdi
    mov $encoded_buf, %rsi
    mov $encoded_buf_len, %rdx
    call read_from_fd

    cmp $0, %rax
    jl .decode_end_error   /* if bytes read is < 0, error */
    je .decode_end_success /* if bytes read == 0, end */
    /* otherwise, attempt to decode and write the results */
    mov %rax, %r14

.decode_buf:
    mov $encoded_buf, %rdi
    mov %r14, %rsi
    mov $raw_buf, %rdx
    call decode

    mov %rax, %r14     /* number of bytes decoded */

.decode_write_buf:
    mov %r13, %rdi
    mov $raw_buf, %rsi
    mov %r14, %rdx
    call write_to_fd

    cmp $0, %rax
    jl .decode_end_error /* if bytes written < 0, error */
    jmp .decode_read_buf /* otherwise, attempt another read + write */

.decode_end_success:
    mov $0, %rax
    jmp .end_encoded_to_raw

.decode_end_error:
    mov $1, %rax
    jmp .end_encoded_to_raw

.end_encoded_to_raw:
    pop %r14
    pop %r13
    pop %r12
    ret


/**
 * Read a file descriptor until the given buffer is full or EOF
 *
 * Basically, just call `read(2)` in a loop trying to fill up the buffer.
 *
 * rdi = file descriptor
 * rsi = buffer
 * rdx = buffer length
 * rax = return, bytes read or -1 on error
 */
read_from_fd:
    /*
     * r12 = file descriptor
     * r13 = buffer + offset
     * r14 = buffer length left
     * r15 = bytes read
     */
    push %r12
    push %r13
    push %r14
    push %r15

    mov %rdi, %r12
    mov %rsi, %r13
    mov %rdx, %r14
    mov $0, %r15

.attempt_read_from_fd:
    /* read() syscall to read file descriptor into buffer */
    mov $0, %rax
    mov %r12, %rdi
    mov %r13, %rsi
    mov %r14, %rdx
    syscall

    add %rax, %r15

    cmp $0, %rax
    je .success_end_read_from_fd /* bytes read == 0, end of file */
    jl .error_end_read_from_fd /* bytes read < 0, error */

    cmp %rax, %r14
    je .success_end_read_from_fd /* bytes read == buffer size, success */

    /* Otherwise we need to attempt another read to make sure we fill up
    the buffer. The next read will either give us more data (good) or return
    0 so we know that we've hit EOF. It's important that we completely fill
    the buffer if possible to make sure we encode our bytes correctly and
    don't insert eroneous padding characters */
    add %rax, %r13
    sub %rax, %r14
    jmp .attempt_read_from_fd

.error_end_read_from_fd:
    mov $-1, %rax
    jmp .end_read_from_fd

.success_end_read_from_fd:
    mov %r15, %rax
    jmp .end_read_from_fd

.end_read_from_fd:
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    ret

/**
 * Write up to N bytes to a file descriptor from a given buffer
 *
 * Basically, just call `write(2)` in a loop trying to drain the buffer.
 *
 * rdi = file descriptor
 * rsi = buffer
 * rdx = buffer length
 * rax = return, bytes written
 */
write_to_fd:
    /*
     * r12 = file descriptor
     * r13 = buffer + offset
     * r14 = buffer length left
     * r15 = bytes written
     */
    push %r12
    push %r13
    push %r14
    push %r15

    mov %rdi, %r12
    mov %rsi, %r13
    mov %rdx, %r14
    mov $0, %r15

.attempt_write_to_fd:
    /* write() syscall to output file descriptor from buffer */
    mov $1, %rax
    mov %r12, %rdi
    mov %r13, %rsi
    mov %r14, %rdx
    syscall

    add %rax, %r15

    cmp $0, %rax
    jl .error_end_write_to_fd /* bytes written < 0, error */

    cmp %rax, %r14
    je .success_end_read_from_fd /* bytes written == buffer size, sucess */

    /* Otherwise, attempt another write to drain the rest of the buffer */
    add %rax, %r13
    sub %rax, %r14
    jmp .attempt_write_to_fd

.error_end_write_to_fd:
    mov $-1, %rax
    jmp .end_write_to_fd

.success_end_write_to_fd:
    mov %r15, %rax
    jmp .end_write_to_fd

.end_write_to_fd:
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    ret

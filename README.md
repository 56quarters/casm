# Casm

A bare bones implementation of the `cat` command written in GNU assembly.

Only supports x86-64 on GNU/Linux.

## Why did you do this?

I suddenly found myself with a lot of free time.

## Is it at least really fast?

No. It's about as fast as GNU `cat` in my limited testing except with far
fewer features and far less portable.

## Should I use this?

Absolutely not.

## But how would I use it?

It works like most `cat` commands.

* Reads from `stdin` or several files
* Writes to `stdout`
* Includes bonus features like the `--help` option

## How do I build this?

Building requires GCC, a linker, and Make.

In the project root:

```
make build
```

The binary is at `target/cat`. It will run on x86-64 GNU/Linux and requires
no libraries, not even libc.

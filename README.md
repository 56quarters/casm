# Casm

Some core utilities implemented in GNU assembly.

Only supports x86-64 on GNU/Linux.

## Why did you do this?

I suddenly found myself with a lot of free time.

## Are they at least really fast?

No. They're generally on par with existing implementations except with more
bugs, far fewer features, and far less portable.

## Should I use this stuff?

Absolutely not.

## How do I build this?

Building requires GCC, a linker, and Make.

In the project root:

```
make build
```

The binaries will be in the `target` directory. They'll run on x86-64 GNU/Linux
and require no libraries, not even libc.

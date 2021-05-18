# Casm

A subset of UNIX core utilities, implemented in GNU assembly (AT&T syntax).

Only supports x86-64 on GNU/Linux.

## Why did you do this?

I found myself with a lot of free time and I wanted to learn assembly. Lots of
people create implementations of core utilities in "high level", "modern", and
"productive" languages like Rust, Go, or Haskell. There aren't many assembly
implementations out there.

## Are they at least really fast?

No. They're generally on par with existing implementations except with more bugs,
fewer features, and (obviously) less portable. With the power of your imagination,
maybe they'll *feel* faster.

## Should I use this?

Absolutely not.

## How do I build this?

Building requires the GNU toolchain: `gcc`, `ld`, and `make`.

In the project root:

```
make build
```

The binaries will be in the `target` directory. They'll run on x86-64 GNU/Linux
and require no libraries, not even libc.

## Compatibility

No.

## Portability

CASM is very portable as long as you only want to run it on recent versions of GNU/Linux on x86-64.

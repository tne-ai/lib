# Files

These are the standard includes:

include.mk is required and has help and configuration used for all

The others are for specific purposes:

- include.python.mk is for python development
- include.airflow.mk for using Apache airflow
- include.docker.mk for docker managemen

For convenience there is also Jgrahamc's excellent Gnu Makefile Standard
Library which has a bunch of use functions in it kept as a submodule
gmsl. This has not been updated since 2018 so be aware of that. The
original code is at [Sourceforge](https://sourceforge.net/projects/gmsl/)

The v1.19 was downloaded manually on copied into our own fork for this so add
it with

```sh
# in your Makefile assuming you are in direct child of ./src
include ../lib/gmsl/gmsl
```

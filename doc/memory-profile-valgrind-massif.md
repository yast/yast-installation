## Massif Basics

Valgrind is an instrumentation framework that runs a program by simulating
every instruction.  It has several tools. Memcheck is the original one, used
for detecting memory errors. Massif is a memory profiler.

(The output it produces, example: https://gist.github.com/mvidner/4e8ed01c7dabb648a50e0dd5f0fdcc62 )

The basic invocation of Massif is simple,
`valgrind --tool=massif my_program its_arguments`, so for YaST it is

```console
# valgrind --tool=massif /usr/lib/YaST2/bin/y2start sw_single qt
```

Or, if we don't want to dig in the startup scripts, we use a bigger gun:

```console
# valgrind --tool=massif --trace-children=yes yast2 sw_single
```

That writes out massif.out.99999 where 99999 is process ID.
To make them somewhat more readable, use the included tool `ms_print`
which adds an ASCII graph and computes percentages:

```
ms_print massif.out.19015 >  massif.out.19015.txt
```

### Debuginfo

The backtraces will contain some names, at the boundaries of shared libraries
But to see names inside libraries Massif needs debuginfo files.

## Massif at Installation Time

tl;dr: Boot with `extend=gdb MASSIF=1`.

1. Install Massif. It is part of the [**gdb** extension][gdb-ext], so use
   `extend=gdb` at the boot prompt, or in an inst-sys shell.

2. Install Debuginfo. For Tumbleweed an automatic downloader is in place
   from <https://debuginfod.opensuse.org/>.

3. Wrap Massif around the main installer process.
   The [startup/YaST2.call script][PR935] will do it if the environment
   variable `MASSIF=1`, putting the logs where save_y2logs expects them.

[gdb-ext]: https://github.com/openSUSE/installation-images/blob/master/data/root/gdb.file_list
[PR935]: https://github.com/yast/yast-installation/pull/935

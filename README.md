# LL-Tracket
Low-level Application Performance and Memory Tracket

## Introduction

I needed an utility to allow me to measure the maximum memory allocation during the execution of an application.
This is it, it will give you the maximum memory size used by an application, plot it if needed and generate a JSON file with the data.

## Usage

As a usage example, lets say we want to compare the memory usage by racket initialization using versions 6.12, 7.1, 7.3 and 7.4CS  (chosen because they have reasonable differences both in time and in memory requirements).

We can run each of them separately using
```
$ ./tracket -j racket74cs.json -i 1 /home/pmatos/installs/racket-7.4_cs/bin/racket -e '(exit)'
Running command line /home/pmatos/installs/racket-7.4_cs/bin/racket -e (exit)
Page size for your system is 4096 bytes
Tracking process 25897
Process finished (in 443.0ms), gathered 192 records (once every 2.31ms)
Maximum virtual memory used: 437.35Mb
```

Run once for each version, gather the json and then do:
```
$ ./tracket-cmp --output racket-exit.png Racket6.12:racket612.json Racket7.1:racket71.json Racket7.3:racket73.json RacketCS7.4:racket74cs.json
Comparing:
Racket6.12: racket612.json
Racket7.1: racket71.json
Racket7.3: racket73.json
RacketCS7.4: racket74cs.json
Output: racket-exit.png
```

The file `racket-exit.png` will look similar to the following (if not, consider reporting an issue):

![Racket init timing](https://github.com/pmatos/LL-Tracket/blob/master/imgs/racket-exit.png)

## Disclaimer

This software is in its infancy, its results might be correct, off-by-one, off-by-many or totally wrong. I am dog-fooding this on a daily basis but cross-referencing with other tools. At least for my current experiments, the results match what I expect and what other tools report but then again, it might all be a big coincidence. :)

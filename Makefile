all: quantum 

SRCS := main.rkt $(wildcard quantum-lib/*.rkt)

quantum: $(SRCS)
	raco exe --vv -o quantum main.rkt

.PHONY: clean

clean:
	-rm -r compiled
	-rm quantum

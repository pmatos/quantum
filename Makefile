all: quantum

SRCS := main.rkt $(wildcard quantum/*.rkt)

qtm: $(SRCS)
	raco exe --vv -o qtm main.rkt

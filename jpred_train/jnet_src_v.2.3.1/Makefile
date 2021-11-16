NNOBJECTS=pssma1.o pssma2.o pssmb1.o pssmb2.o hmm1.o hmm2.o psisol25.o hmmsol25.o psisol0.o psisol5.o hmmsol0.o hmmsol5.o
OBJECTS=$(NNOBJECTS) jnet.o ./cmdline/cmdline.o

CC = gcc

# Normal compile
CFLAGS = -Wall -pedantic -O3 -ffast-math -fomit-frame-pointer
	#-O0 -ggdb3
LDFLAGS = -lm -Icmdline
	# -pg -lefence

all: jnet

./cmdline/cmdline.o: ./cmdline/cmdline.ggo
	$(MAKE) -C cmdline

jnet.c: ./cmdline/cmdline.o

jnet: $(OBJECTS)

.PHONY: clean veryclean test

clean:
	rm -f $(OBJECTS) jnet test.jnet

veryclean: clean
	$(MAKE) -C cmdline clean

test: test.jnet

# Test by running prediction on a single known sequence
# and check for any difference between the prediction and the known result
test.jnet: jnet
	./jnet --concise --hmm test/d1b65a_.hmm --pssm test/d1b65a_.pssm 2> /dev/null > test.jnet
	diff -q test/d1b65a_.jnet test.jnet
	rm -f test.jnet
	@echo "Test passed! Jnet binary is valid!"

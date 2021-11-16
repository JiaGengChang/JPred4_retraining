cmdline.o: cmdline.c cmdline.h

cmdline.c cmdline.h: cmdline.ggo
	gengetopt < $^

clean:
	rm -rf *.o *.c *.h

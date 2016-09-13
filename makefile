test: test.o cJSON.o
	gcc -o test.o -lm 
test.o:test.c cJSON.c
	gcc -c test.c -lm
cJSON.o:cJSON.c cJSON.h
	gcc -c cJSON.c -lm

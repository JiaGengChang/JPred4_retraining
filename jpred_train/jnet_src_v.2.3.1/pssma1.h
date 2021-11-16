/*********************************************************
  pssma1.h
  --------------------------------------------------------
  generated at Sat Oct  2 01:01:58 2021
  by snns2c ( Bernward Kett 1995 ) 
*********************************************************/

extern int pssma1(float *in, float *out, int init);

static struct {
  int NoOfInput;    /* Number of Input Units  */
  int NoOfOutput;   /* Number of Output Units */
  int(* propFunc)(float *, float*, int);
} pssma1REC = {340,3,pssma1};

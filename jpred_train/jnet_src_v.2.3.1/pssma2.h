/*********************************************************
  pssma2.h
  --------------------------------------------------------
  generated at Sat Oct  2 02:23:46 2021
  by snns2c ( Bernward Kett 1995 ) 
*********************************************************/

extern int pssma2(float *in, float *out, int init);

static struct {
  int NoOfInput;    /* Number of Input Units  */
  int NoOfOutput;   /* Number of Output Units */
  int(* propFunc)(float *, float*, int);
} pssma2REC = {57,3,pssma2};

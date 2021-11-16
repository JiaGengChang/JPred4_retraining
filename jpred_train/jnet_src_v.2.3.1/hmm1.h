/*********************************************************
  hmm1.h
  --------------------------------------------------------
  generated at Sat Oct  2 01:38:34 2021
  by snns2c ( Bernward Kett 1995 ) 
*********************************************************/

extern int hmm1(float *in, float *out, int init);

static struct {
  int NoOfInput;    /* Number of Input Units  */
  int NoOfOutput;   /* Number of Output Units */
  int(* propFunc)(float *, float*, int);
} hmm1REC = {408,3,hmm1};

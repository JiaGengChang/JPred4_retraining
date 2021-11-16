/*********************************************************
  hmmsol0.h
  --------------------------------------------------------
  generated at Fri Oct  1 15:37:07 2021
  by snns2c ( Bernward Kett 1995 ) 
*********************************************************/

extern int hmmsol0(float *in, float *out, int init);

static struct {
  int NoOfInput;    /* Number of Input Units  */
  int NoOfOutput;   /* Number of Output Units */
  int(* propFunc)(float *, float*, int);
} hmmsol0REC = {408,2,hmmsol0};

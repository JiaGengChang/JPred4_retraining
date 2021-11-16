/*********************************************************
  hmmsol25.h
  --------------------------------------------------------
  generated at Fri Oct  1 15:59:16 2021
  by snns2c ( Bernward Kett 1995 ) 
*********************************************************/

extern int hmmsol25(float *in, float *out, int init);

static struct {
  int NoOfInput;    /* Number of Input Units  */
  int NoOfOutput;   /* Number of Output Units */
  int(* propFunc)(float *, float*, int);
} hmmsol25REC = {408,2,hmmsol25};

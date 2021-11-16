/*********************************************************
  hmmsol5.h
  --------------------------------------------------------
  generated at Fri Oct  1 16:00:58 2021
  by snns2c ( Bernward Kett 1995 ) 
*********************************************************/

extern int hmmsol5(float *in, float *out, int init);

static struct {
  int NoOfInput;    /* Number of Input Units  */
  int NoOfOutput;   /* Number of Output Units */
  int(* propFunc)(float *, float*, int);
} hmmsol5REC = {408,2,hmmsol5};

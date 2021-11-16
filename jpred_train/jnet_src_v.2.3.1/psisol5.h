/*********************************************************
  psisol5.h
  --------------------------------------------------------
  generated at Fri Oct  1 15:41:09 2021
  by snns2c ( Bernward Kett 1995 ) 
*********************************************************/

extern int psisol5(float *in, float *out, int init);

static struct {
  int NoOfInput;    /* Number of Input Units  */
  int NoOfOutput;   /* Number of Output Units */
  int(* propFunc)(float *, float*, int);
} psisol5REC = {340,2,psisol5};

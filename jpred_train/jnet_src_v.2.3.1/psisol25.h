/*********************************************************
  psisol25.h
  --------------------------------------------------------
  generated at Fri Oct  1 15:33:46 2021
  by snns2c ( Bernward Kett 1995 ) 
*********************************************************/

extern int psisol25(float *in, float *out, int init);

static struct {
  int NoOfInput;    /* Number of Input Units  */
  int NoOfOutput;   /* Number of Output Units */
  int(* propFunc)(float *, float*, int);
} psisol25REC = {340,2,psisol25};

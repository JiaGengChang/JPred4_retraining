/*********************************************************
  pssmb1.h
  --------------------------------------------------------
  generated at Fri Oct  1 16:42:10 2021
  by snns2c ( Bernward Kett 1995 ) 
*********************************************************/

extern int pssmb1(float *in, float *out, int init);

static struct {
  int NoOfInput;    /* Number of Input Units  */
  int NoOfOutput;   /* Number of Output Units */
  int(* propFunc)(float *, float*, int);
} pssmb1REC = {340,3,pssmb1};

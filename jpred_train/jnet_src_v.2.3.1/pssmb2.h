/*********************************************************
  pssmb2.h
  --------------------------------------------------------
  generated at Fri Oct  1 16:54:43 2021
  by snns2c ( Bernward Kett 1995 ) 
*********************************************************/

extern int pssmb2(float *in, float *out, int init);

static struct {
  int NoOfInput;    /* Number of Input Units  */
  int NoOfOutput;   /* Number of Output Units */
  int(* propFunc)(float *, float*, int);
} pssmb2REC = {57,3,pssmb2};

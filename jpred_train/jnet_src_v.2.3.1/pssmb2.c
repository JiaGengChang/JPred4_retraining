/*********************************************************
  pssmb2.c
  --------------------------------------------------------
  generated at Fri Oct  1 16:54:43 2021
  by snns2c ( Bernward Kett 1995 ) 
*********************************************************/

#include <math.h>

#define Act_Logistic(sum, bias)  ( (sum+bias<10000.0) ? ( 1.0/(1.0 + exp(-sum-bias) ) ) : 0.0 )
#ifndef NULL
#define NULL (void *)0
#endif

typedef struct UT {
          float act;         /* Activation       */
          float Bias;        /* Bias of the Unit */
          int   NoOfSources; /* Number of predecessor units */
   struct UT   **sources; /* predecessor units */
          float *weights; /* weights from predecessor units */
        } UnitType, *pUnit;

  /* Forward Declaration for all unit types */
  static UnitType Units[81];
  /* Sources definition section */
  static pUnit Sources[] =  {
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, 
Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, 
Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, 
Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, 
Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, 
Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57, 
Units + 58, Units + 59, Units + 60, Units + 61, Units + 62, Units + 63, Units + 64, Units + 65, Units + 66, Units + 67, 
Units + 68, Units + 69, Units + 70, Units + 71, Units + 72, Units + 73, Units + 74, Units + 75, Units + 76, Units + 77, 

Units + 58, Units + 59, Units + 60, Units + 61, Units + 62, Units + 63, Units + 64, Units + 65, Units + 66, Units + 67, 
Units + 68, Units + 69, Units + 70, Units + 71, Units + 72, Units + 73, Units + 74, Units + 75, Units + 76, Units + 77, 

Units + 58, Units + 59, Units + 60, Units + 61, Units + 62, Units + 63, Units + 64, Units + 65, Units + 66, Units + 67, 
Units + 68, Units + 69, Units + 70, Units + 71, Units + 72, Units + 73, Units + 74, Units + 75, Units + 76, Units + 77, 


  };

  /* Weigths definition section */
  static float Weights[] =  {
-0.037900, 0.221520, 0.157530, 0.380150, 0.022000, -0.047290, 0.092940, 0.183360, 0.153930, 0.181520, 
0.231720, 0.059590, -0.002020, 0.132320, 0.025610, 0.062120, -0.320620, 0.103390, 0.151750, -0.071300, 
0.171840, 0.706240, -0.091840, 0.262630, 1.251070, -0.146850, 0.419820, 0.984210, -0.664690, 2.914730, 
-0.390390, -0.529720, 2.905400, -0.579080, -1.105500, 2.936580, -0.321710, -0.940170, 1.930130, 0.815650, 
-1.003880, 0.537220, 1.081340, -0.713870, -0.201920, 0.841700, -0.508090, -0.337380, 0.169950, -0.203310, 
-0.014790, 0.167980, -0.208710, 0.170500, -0.007460, 0.222490, -0.064060, 
-0.172600, 0.204360, -0.072950, -0.229720, 0.141250, 0.125540, -0.188810, 0.023490, 0.044500, 0.048360, 
-0.188380, 0.069740, 0.116090, -0.010400, -0.217040, 0.166070, 0.192490, -0.125560, 0.031850, 0.259280, 
-0.244040, 0.210140, 0.438590, -0.033420, 0.007150, 0.210250, 0.139600, -0.146060, -0.121180, 0.005550, 
0.396810, 0.325200, 0.203200, 0.288280, 0.130300, 0.132690, 0.130730, 0.150250, -0.001840, -0.043840, 
-0.016120, 0.220020, -0.085680, 0.238900, 0.136520, -0.009430, 0.280630, 0.159150, 0.019470, 0.176360, 
0.101870, 0.101010, 0.234350, 0.219880, 0.189560, 0.309750, -0.093320, 
-0.015280, 0.046630, -0.123180, 0.098380, -0.022600, -0.234210, -0.066660, -0.027830, -0.156350, -0.200610, 
0.113150, -0.239190, -0.102320, 0.216670, -0.138290, -0.186380, 0.198280, -0.335700, -0.171480, 0.146680, 
-0.020470, -0.528470, 0.025470, 0.106770, -1.075190, 0.033410, 0.296570, -0.859400, 0.313440, 0.192710, 
-1.091700, 0.079320, -0.045770, -0.690120, 0.113920, 0.123510, -0.280820, 0.075350, -0.099240, -0.009170, 
0.125680, -0.119610, -0.219810, 0.174150, -0.136470, -0.054800, 0.048240, -0.129540, -0.040710, -0.087020, 
-0.173220, 0.005290, -0.090430, -0.219580, -0.169960, 0.020140, -0.014040, 
0.316910, 0.202190, 0.478130, 0.072390, 0.067730, 0.195790, -0.004520, -0.226220, 0.267580, -0.036580, 
0.135900, 0.103950, -0.083530, -0.044950, 0.317750, -0.174740, 0.282760, 0.161580, -0.180150, 0.566170, 
0.106450, 0.284680, 0.893250, 0.522280, 0.692200, 0.802160, 0.564270, 0.532140, -0.451690, -0.649920, 
1.163170, 1.380990, 0.825440, 0.170300, 1.307470, 0.681800, -0.524090, 0.922450, 0.182820, -0.468070, 
0.246170, -0.163890, -0.343520, -0.167850, 0.042160, -0.262200, 0.090170, -0.203450, -0.211560, 0.144820, 
-0.393020, -0.336280, 0.164160, -0.205880, -0.102990, -0.037660, -0.176450, 
-0.109030, -0.276360, 0.218770, -0.221820, -0.256520, 0.240220, -0.331660, -0.359260, 0.140650, -0.000240, 
-0.476150, 0.106810, 0.163900, -0.382940, 0.058880, 0.130520, -0.095110, -0.303130, 0.109650, -0.271380, 
-0.308790, 0.137700, -0.510900, -0.081350, 0.076370, -0.637260, 0.175450, 0.139610, -0.721250, 0.119770, 
0.308910, -0.514530, -0.140470, 0.284340, -0.601550, -0.288990, 0.112810, -0.563810, -0.151030, 0.044950, 
-0.344080, -0.038770, -0.061890, -0.343200, 0.025600, -0.187810, -0.209690, -0.045230, -0.271280, -0.148270, 
-0.021490, -0.218740, -0.100750, -0.131640, -0.133180, -0.016970, -0.466830, 
0.063780, 0.368820, 0.374990, 0.022080, 0.626610, 0.098560, 0.067020, 0.506230, 0.291870, 0.273700, 
0.397100, 0.290040, 0.252500, 0.325460, 0.179900, 0.113460, 0.490140, 0.137260, -0.344370, 0.650940, 
0.532260, -0.744940, 0.351940, 0.657680, -0.689230, 0.096880, 1.519780, -0.296570, 0.413600, 2.161500, 
-1.154170, -0.439870, 1.770370, -0.963500, 0.176330, 0.605660, -0.832100, 0.540270, 0.206700, -0.116340, 
-0.017990, -0.364760, -0.610480, -0.016660, -0.140840, -0.115360, -0.348000, -0.118280, -0.169010, -0.243680, 
-0.246130, -0.116240, -0.301960, -0.120610, -0.233700, -0.106570, 0.081880, 
-0.213960, 0.087630, -0.403600, -0.181610, -0.082070, -0.251850, -0.004840, -0.115080, -0.201060, -0.112000, 
-0.117010, 0.013390, -0.233740, -0.046780, 0.111470, -0.243150, -0.205050, 0.172670, -0.422150, 0.161920, 
0.123910, -0.706580, 0.383370, 0.089330, -0.832630, 0.472500, -0.041710, -1.077030, -0.018700, -0.199600, 
-0.697240, 0.356170, 0.172970, -0.577980, 0.636690, 0.040230, -0.569140, 0.265180, 0.132510, -0.396100, 
0.088060, 0.052790, -0.359230, 0.104840, -0.009570, -0.275320, -0.011160, 0.072690, -0.140600, -0.105240, 
0.008620, -0.095810, -0.038970, -0.030840, -0.097890, -0.052960, -0.039360, 
0.442550, -0.349200, 0.021740, 0.190520, -0.152050, -0.163480, -0.024180, 0.129000, -0.454290, -0.270540, 
0.041700, -0.239670, -0.089340, -0.191690, -0.070020, 0.146520, -0.676190, 0.170870, 0.465580, -1.319820, 
0.466460, 0.949830, -0.978160, 0.132040, 1.049930, -0.681650, -0.295650, 0.659810, -1.211870, -0.552310, 
1.010410, -0.355120, 0.288240, 0.581350, -0.643720, 0.194790, 0.300280, -0.539200, -0.062780, 0.007530, 
-0.368490, -0.307670, 0.034430, -0.291020, -0.299670, 0.014770, -0.257770, -0.358470, 0.027250, -0.185650, 
-0.197170, -0.031020, -0.282950, -0.103330, 0.003460, -0.410710, -0.032920, 
-0.082980, 0.081140, -0.100010, -0.038090, -0.038440, -0.112530, 0.025770, -0.027420, -0.015230, 0.037520, 
-0.149050, -0.133490, 0.017740, 0.080160, -0.197210, -0.040550, 0.137970, -0.103460, 0.015390, 0.189510, 
-0.278630, 0.098420, 0.311590, -0.243650, -0.131130, 0.180100, -0.031080, -0.304840, -0.279850, 0.123140, 
0.023700, 0.206030, 0.120580, -0.039410, 0.303030, 0.134540, -0.103140, 0.003800, 0.126380, -0.102770, 
-0.239530, 0.302840, -0.069400, -0.040710, 0.215110, -0.190310, -0.105060, 0.316040, -0.074670, -0.073220, 
0.179840, 0.082720, -0.072000, 0.029790, 0.002310, -0.018910, -0.073260, 
-0.312660, -0.185370, 0.057660, -0.107670, 0.001840, 0.110600, -0.151940, -0.088160, 0.359680, 0.138250, 
-0.356880, 0.149310, 0.072680, -0.429200, 0.546460, 0.123830, -0.771760, 0.566100, 0.224690, -0.819320, 
0.554050, -0.134500, -0.905240, -0.129790, -0.604200, -0.818150, -0.133700, -0.628720, 0.024170, 0.708810, 
-0.893050, -0.477410, -0.737990, -0.339220, -0.322530, -0.592150, 0.215870, -0.274290, -0.116340, 0.122310, 
-0.129250, 0.143310, 0.374360, -0.061690, -0.156360, 0.213090, 0.269980, -0.241930, 0.042530, 0.101290, 
-0.246050, 0.043910, 0.191230, -0.036740, -0.068360, 0.101820, -0.136640, 
0.074300, 0.568450, -0.322030, 0.024630, 0.239540, -0.034520, 0.290390, 0.246150, -0.016500, 0.214530, 
0.115570, -0.241570, 0.369010, 0.269380, -0.533680, -0.298000, 0.152310, -0.546220, -0.330020, 0.078200, 
-1.261330, -0.333700, -0.821460, -1.567720, -0.981510, -1.363510, -0.538960, 0.291060, -0.271950, 0.589320, 
-0.778440, -1.240020, -1.473790, -0.590200, -0.499830, -1.603920, -0.194960, 0.161350, -0.738630, 0.066800, 
0.139290, -0.244040, 0.041500, 0.349090, -0.087840, 0.573480, 0.103810, -0.267340, 0.364680, 0.271140, 
-0.002300, -0.031750, 0.194930, 0.614890, 0.410290, 1.049740, 0.181980, 
-0.229900, -0.149550, 0.055530, -0.223210, -0.343000, 0.132650, -0.118160, -0.334190, 0.414670, -0.013170, 
-0.251770, 0.243670, 0.092270, -0.347340, 0.201390, -0.076350, -0.392420, 0.261480, -0.154550, -0.078160, 
0.017450, -0.690470, -0.065770, -0.067950, -0.343070, -0.232410, -0.025930, -0.213370, 0.199370, 0.801640, 
-0.572520, -0.290940, -0.153300, -0.452930, -0.059940, -0.385440, -0.077120, 0.040480, 0.072860, -0.167400, 
0.029210, 0.085480, -0.071630, -0.243890, 0.127090, -0.104680, -0.219400, 0.193110, -0.357150, -0.089310, 
0.129410, -0.301080, 0.102980, -0.083370, -0.203050, 0.142760, -0.114840, 
-0.190020, 0.099220, 0.200390, -0.111390, -0.059290, 0.030870, -0.135670, -0.122380, 0.021750, 0.017110, 
-0.120810, 0.095180, -0.014340, -0.138790, 0.251020, -0.006380, -0.116200, 0.549930, 0.159870, -0.080420, 
0.447310, 0.199070, 0.188150, 0.434550, 0.055060, 0.284660, 0.132350, -0.233210, -0.070300, -1.098240, 
0.804470, 0.510340, 0.151700, 0.820100, 0.564900, 0.022900, 0.516830, -0.136350, 0.167530, 0.277370, 
-0.121740, 0.085690, 0.331300, -0.042840, 0.140470, 0.140320, -0.011850, 0.088220, 0.239590, 0.075400, 
0.165410, 0.152270, 0.156330, 0.119180, 0.059570, 0.282370, 0.082920, 
0.079500, -0.262870, -0.159890, 0.074370, -0.133850, -0.176900, -0.037240, -0.261720, 0.052720, 0.307510, 
-0.659420, -0.051170, 0.397740, -0.518590, -0.128670, 0.712870, -0.729830, -0.053720, 0.715400, -0.744540, 
-0.077630, 0.733560, -0.450930, -0.011630, 0.697550, -0.342280, 0.079080, 0.176760, -0.599610, 0.097950, 
0.562150, -0.309410, 0.262410, 0.722780, -0.534250, -0.032240, 0.834400, -0.802050, -0.104270, 0.620890, 
-0.577820, -0.139790, 0.580260, -0.403930, -0.286640, 0.312370, -0.452460, 0.049390, 0.034980, -0.119050, 
-0.129670, 0.176670, -0.211910, 0.214240, 0.302180, -0.395930, 0.162700, 
-0.012830, 0.258790, -0.312710, -0.060180, 0.053630, -0.201130, 0.191270, -0.006790, -0.086240, 0.050040, 
0.072780, -0.102260, 0.181780, -0.005110, -0.024040, 0.444270, 0.103680, 0.079460, 0.350810, 0.308390, 
0.180860, 0.185330, 0.453420, 0.005300, -0.194750, 0.509860, -0.157400, -0.698920, 0.202680, -0.513820, 
-0.197690, 0.611950, 0.424390, 0.086470, 0.077390, 0.455950, -0.009260, 0.173330, 0.202410, -0.048070, 
-0.053900, 0.044680, -0.001840, 0.000660, -0.012080, -0.016390, 0.066620, 0.107420, -0.121190, 0.082670, 
-0.020600, -0.183710, -0.117420, 0.150560, -0.166290, -0.040800, 0.119170, 
-0.114960, -0.106610, 0.091110, -0.241570, 0.010400, 0.071140, -0.386790, 0.175910, 0.063440, -0.449610, 
0.441870, -0.199500, -0.597610, 0.601500, -0.313490, -0.607750, 0.653010, -0.713050, -0.186300, 0.933820, 
-1.570400, 0.450930, 0.689310, -2.201880, 0.350030, 0.068220, -2.283250, -0.549350, -0.191720, -2.220780, 
-0.464570, 0.538360, -0.689370, -0.581280, 0.670900, 0.163750, -0.696450, 0.166430, 0.419340, 0.186660, 
-0.379050, -0.090860, 0.091300, -0.282240, -0.079110, 0.141050, -0.162390, -0.416720, 0.045580, 0.073930, 
-0.003760, -0.204190, 0.056080, 0.064130, -0.200340, 0.190390, -0.125090, 
0.234230, -0.412940, 0.168830, 0.257000, -0.220050, 0.058530, 0.291560, -0.025360, 0.060290, 0.279280, 
-0.131520, -0.002630, 0.383530, 0.227900, 0.028480, 0.512110, 0.544830, -0.211350, 0.451650, 0.827840, 
-0.240350, 0.310820, 1.079240, 0.008080, 0.153430, 1.197800, -0.219350, -0.135920, 0.886460, -0.369510, 
0.526020, 0.832290, 0.199100, 0.789510, 0.454750, 0.028470, 0.895110, 0.100820, -0.283590, 0.845890, 
-0.089310, -0.248490, 0.613460, -0.134570, -0.062550, 0.354580, 0.001180, 0.134000, 0.315660, -0.004010, 
0.116160, 0.336010, -0.112120, 0.245880, 0.320920, -0.121720, 0.315540, 
-0.206370, 0.093900, -0.130690, -0.156420, 0.047300, -0.050870, -0.331680, -0.018570, 0.036840, -0.364200, 
0.044560, 0.001530, -0.530070, 0.136300, 0.065890, -0.501840, 0.276890, -0.037840, -0.610550, 0.289130, 
-0.006150, -0.725970, 0.292680, -0.119580, -0.697340, 0.503700, -0.244050, -0.634750, 0.273960, -0.208460, 
-0.554050, 0.228910, -0.197620, -0.490630, 0.055310, -0.064650, -0.499700, -0.046180, 0.043910, -0.351360, 
0.017690, 0.044520, -0.385950, -0.078610, 0.013180, -0.226380, -0.036330, 0.033730, -0.283520, -0.130970, 
-0.165270, -0.284140, 0.001990, -0.198940, -0.329390, -0.088350, -0.192630, 
-0.136120, -0.087440, -0.010410, 0.008020, 0.053310, -0.068750, -0.056500, 0.199490, -0.084440, 0.110800, 
0.202010, -0.200580, 0.108650, 0.389730, -0.357740, 0.015340, 0.324680, -0.356180, -0.144320, 0.125920, 
-0.104030, -0.537710, -0.112290, -0.156700, -1.043910, 0.099460, 0.086040, -0.970440, 0.284680, 0.452670, 
-1.118830, -0.175150, 0.028510, -0.531940, -0.111660, 0.029740, -0.066230, 0.070640, -0.090830, 0.273650, 
0.071860, -0.354300, 0.133210, 0.004680, -0.406470, 0.240740, 0.165280, -0.243760, 0.015980, 0.091450, 
-0.063610, 0.215240, -0.006650, -0.194780, 0.052800, -0.108950, 0.037000, 
0.155610, -0.049970, -0.214720, -0.061010, -0.032680, -0.040520, 0.213150, 0.064370, -0.156470, 0.049480, 
0.190340, -0.036240, -0.126020, 0.157900, -0.084160, -0.151960, 0.272920, -0.440580, -0.314970, -0.080420, 
-0.491060, -0.511320, -0.620820, -0.476560, -0.679800, -0.913210, -0.180270, 0.356250, -0.382310, 0.699770, 
-1.138840, -1.532060, -0.457420, -0.439400, -1.250380, -0.344080, -0.043710, -0.529760, 0.040580, 0.107520, 
-0.196200, 0.076080, -0.045330, -0.151400, 0.302260, -0.002230, 0.219770, 0.236490, 0.193950, 0.103640, 
-0.045110, -0.172450, 0.129800, 0.030390, -0.079630, 0.045970, -0.265710, 
2.417210, -0.044710, -1.512810, 1.672370, 0.290220, -1.701800, -1.582580, 0.247620, -0.360470, -1.596950, 
-1.527220, -1.337260, 0.603550, 0.828150, -0.506270, -1.935870, -0.805950, -1.802390, -1.415760, -1.475400, 

-2.305860, 0.461190, 0.069720, 0.509100, -0.959760, 0.204530, 0.501320, -2.514700, 0.539310, 0.015800, 
-1.327160, -0.135370, 1.102850, -2.082600, 1.087480, 2.207930, 1.473210, -0.161180, -0.117960, -1.382530, 

2.206870, -0.802500, 0.435660, -2.038330, -0.107660, 1.639020, -0.422170, -1.180960, -0.206190, 1.076790, 
1.602960, 0.874410, -1.292760, 0.287290, -0.338760, -1.855000, -0.856330, 0.063460, 0.802630, 1.662120, 


  };

  /* unit definition section (see also UnitType) */
  static UnitType Units[81] = 
  {
    { 0.0, 0.0, 0, NULL , NULL },
    { /* unit 1 (unit) */
      0.0, -0.013510, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 2 (unit) */
      0.0, -0.044710, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 3 (unit) */
      0.0, 0.098590, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 4 (unit) */
      0.0, -0.032060, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 5 (unit) */
      0.0, 0.093280, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 6 (unit) */
      0.0, -0.072860, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 7 (unit) */
      0.0, 0.093690, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 8 (unit) */
      0.0, 0.074390, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 9 (unit) */
      0.0, -0.054620, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 10 (unit) */
      0.0, -0.036190, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 11 (unit) */
      0.0, 0.010090, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 12 (unit) */
      0.0, 0.096920, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 13 (unit) */
      0.0, 0.033410, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 14 (unit) */
      0.0, 0.071310, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 15 (unit) */
      0.0, 0.052300, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 16 (unit) */
      0.0, 0.070510, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 17 (unit) */
      0.0, 0.023310, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 18 (unit) */
      0.0, -0.043350, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 19 (unit) */
      0.0, 0.071350, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 20 (unit) */
      0.0, -0.093780, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 21 (unit) */
      0.0, 0.064180, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 22 (unit) */
      0.0, -0.069620, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 23 (unit) */
      0.0, 0.059210, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 24 (unit) */
      0.0, 0.053610, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 25 (unit) */
      0.0, -0.084020, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 26 (unit) */
      0.0, 0.081310, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 27 (unit) */
      0.0, 0.069860, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 28 (unit) */
      0.0, 0.063130, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 29 (unit) */
      0.0, 0.082410, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 30 (unit) */
      0.0, -0.084400, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 31 (unit) */
      0.0, -0.045570, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 32 (unit) */
      0.0, 0.010950, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 33 (unit) */
      0.0, -0.092110, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 34 (unit) */
      0.0, 0.092210, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 35 (unit) */
      0.0, -0.003900, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 36 (unit) */
      0.0, 0.092760, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 37 (unit) */
      0.0, -0.055630, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 38 (unit) */
      0.0, 0.030760, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 39 (unit) */
      0.0, 0.077060, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 40 (unit) */
      0.0, -0.043990, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 41 (unit) */
      0.0, -0.096520, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 42 (unit) */
      0.0, 0.088200, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 43 (unit) */
      0.0, -0.082060, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 44 (unit) */
      0.0, -0.052140, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 45 (unit) */
      0.0, -0.043390, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 46 (unit) */
      0.0, -0.034670, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 47 (unit) */
      0.0, -0.028120, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 48 (unit) */
      0.0, -0.092590, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 49 (unit) */
      0.0, 0.037780, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 50 (unit) */
      0.0, 0.028600, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 51 (unit) */
      0.0, -0.087060, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 52 (unit) */
      0.0, -0.055000, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 53 (unit) */
      0.0, -0.065300, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 54 (unit) */
      0.0, 0.029870, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 55 (unit) */
      0.0, 0.072980, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 56 (unit) */
      0.0, -0.078630, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 57 (unit) */
      0.0, 0.049480, 0,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 58 (unit) */
      0.0, 3.363590, 57,
       &Sources[0] , 
       &Weights[0] , 
      },
    { /* unit 59 (unit) */
      0.0, -0.351560, 57,
       &Sources[57] , 
       &Weights[57] , 
      },
    { /* unit 60 (unit) */
      0.0, -0.400000, 57,
       &Sources[114] , 
       &Weights[114] , 
      },
    { /* unit 61 (unit) */
      0.0, -0.730670, 57,
       &Sources[171] , 
       &Weights[171] , 
      },
    { /* unit 62 (unit) */
      0.0, -0.442310, 57,
       &Sources[228] , 
       &Weights[228] , 
      },
    { /* unit 63 (unit) */
      0.0, 2.427230, 57,
       &Sources[285] , 
       &Weights[285] , 
      },
    { /* unit 64 (unit) */
      0.0, -1.202970, 57,
       &Sources[342] , 
       &Weights[342] , 
      },
    { /* unit 65 (unit) */
      0.0, -1.013140, 57,
       &Sources[399] , 
       &Weights[399] , 
      },
    { /* unit 66 (unit) */
      0.0, -0.517020, 57,
       &Sources[456] , 
       &Weights[456] , 
      },
    { /* unit 67 (unit) */
      0.0, 0.075030, 57,
       &Sources[513] , 
       &Weights[513] , 
      },
    { /* unit 68 (unit) */
      0.0, 0.856250, 57,
       &Sources[570] , 
       &Weights[570] , 
      },
    { /* unit 69 (unit) */
      0.0, 0.879330, 57,
       &Sources[627] , 
       &Weights[627] , 
      },
    { /* unit 70 (unit) */
      0.0, -1.600100, 57,
       &Sources[684] , 
       &Weights[684] , 
      },
    { /* unit 71 (unit) */
      0.0, -0.256510, 57,
       &Sources[741] , 
       &Weights[741] , 
      },
    { /* unit 72 (unit) */
      0.0, -1.016830, 57,
       &Sources[798] , 
       &Weights[798] , 
      },
    { /* unit 73 (unit) */
      0.0, -2.900660, 57,
       &Sources[855] , 
       &Weights[855] , 
      },
    { /* unit 74 (unit) */
      0.0, 0.225400, 57,
       &Sources[912] , 
       &Weights[912] , 
      },
    { /* unit 75 (unit) */
      0.0, -0.552930, 57,
       &Sources[969] , 
       &Weights[969] , 
      },
    { /* unit 76 (unit) */
      0.0, -0.215240, 57,
       &Sources[1026] , 
       &Weights[1026] , 
      },
    { /* unit 77 (unit) */
      0.0, 0.626300, 57,
       &Sources[1083] , 
       &Weights[1083] , 
      },
    { /* unit 78 (unit) */
      0.0, -0.308660, 20,
       &Sources[1140] , 
       &Weights[1140] , 
      },
    { /* unit 79 (unit) */
      0.0, -1.497700, 20,
       &Sources[1160] , 
       &Weights[1160] , 
      },
    { /* unit 80 (unit) */
      0.0, -1.034830, 20,
       &Sources[1180] , 
       &Weights[1180] , 
      }

  };



int pssmb2(float *in, float *out, int init)
{
  int member, source;
  float sum;
  enum{OK, Error, Not_Valid};
  pUnit unit;


  /* layer definition section (names & member units) */

  static pUnit Input[57] = {Units + 1, Units + 2, Units + 3, Units + 4, Units + 5, Units + 6, Units + 7, Units + 8, Units + 9, Units + 10, Units + 11, Units + 12, Units + 13, Units + 14, Units + 15, Units + 16, Units + 17, Units + 18, Units + 19, Units + 20, Units + 21, Units + 22, Units + 23, Units + 24, Units + 25, Units + 26, Units + 27, Units + 28, Units + 29, Units + 30, Units + 31, Units + 32, Units + 33, Units + 34, Units + 35, Units + 36, Units + 37, Units + 38, Units + 39, Units + 40, Units + 41, Units + 42, Units + 43, Units + 44, Units + 45, Units + 46, Units + 47, Units + 48, Units + 49, Units + 50, Units + 51, Units + 52, Units + 53, Units + 54, Units + 55, Units + 56, Units + 57}; /* members */

  static pUnit Hidden1[20] = {Units + 58, Units + 59, Units + 60, Units + 61, Units + 62, Units + 63, Units + 64, Units + 65, Units + 66, Units + 67, Units + 68, Units + 69, Units + 70, Units + 71, Units + 72, Units + 73, Units + 74, Units + 75, Units + 76, Units + 77}; /* members */

  static pUnit Output1[3] = {Units + 78, Units + 79, Units + 80}; /* members */

  static int Output[3] = {78, 79, 80};

  for(member = 0; member < 57; member++) {
    Input[member]->act = in[member];
  }

  for (member = 0; member < 20; member++) {
    unit = Hidden1[member];
    sum = 0.0;
    for (source = 0; source < unit->NoOfSources; source++) {
      sum += unit->sources[source]->act
             * unit->weights[source];
    }
    unit->act = Act_Logistic(sum, unit->Bias);
  };

  for (member = 0; member < 3; member++) {
    unit = Output1[member];
    sum = 0.0;
    for (source = 0; source < unit->NoOfSources; source++) {
      sum += unit->sources[source]->act
             * unit->weights[source];
    }
    unit->act = Act_Logistic(sum, unit->Bias);
  };

  for(member = 0; member < 3; member++) {
    out[member] = Units[Output[member]].act;
  }

  return(OK);
}

/************************************************************************
 *               Jnet - A consensus neural network protein              *
 *                      secondary structure prediction method           *
 *                                                                      *
 *  Copyright 1999,2009 James Cuff, Jonathan Barber and Christian Cole  *
 *                                                                      *
 ************************************************************************


-------------------------------------------------------------------------
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
-------------------------------------------------------------------------*/

/* Fri Nov 15 15:28:09 GMT 2002 Bug fixes by JDB */
/* WARNING: MUST BE PRESENTED WITH UPPERCASE DATA as lowercase 'n'
 * has a special internal meaning in seq2int
 * */

/*#define POST*/	/* Allow post processing of NN output */
/*#define FILTER*/	/* Allow string post processing of final output */

/** The profile-specific defines below are not independent of each other.
Especially check that the Jury set-up is correct! */
#define HMM    /* Do HMMer predictions */
#define PSSM   /* Do PSSM predicitons */
/*#define HMMONLY*/ /* For non-jury positions use the HMM prediction - only works when DOJURY is undefined */

/* The allowed value of the integers representing residues */
enum {
	WINAR = 30,			/* array size for winar */
	PSILEN = 20,		/* no. of elements per position in PSIBLAST PSSM */
	PROLEN = 24,		/* no. of elements per position for other profiles */
	HELIX = 1,			/* enums for sec. struct. states */
	SHEET = 0,
	COIL = 2,
	MAXSEQNUM = 1000,	/* Maximum number of sequences per alignment*/
	MAXSEQLEN = 5000,	/* Maximum Sequence Length */
	MAXBLOCK = 200    /* Maximum block size for human readable output */
};

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <ctype.h>
#include <assert.h>

#include "cmdline/cmdline.h"

#include "pssma1.h" /* Uses information from data.psimat, (PSSM) - 100 hidden nodes */
#include "pssma2.h" /* Second network for pssma1 - 100 hidden nodes */
#include "pssmb1.h" /* Uses information from data.psimat, (PSSM)  - 20 hidden nodes */
#include "pssmb2.h" /* Second network for pssmb1  - 20 hidden nodes */

#include "hmm1.h" /* First network for HMMER profile prediction */
#include "hmm2.h" /* Second network for hmm1 */

#include "hmmsol25.h"
#include "hmmsol5.h"
#include "hmmsol0.h"

#include "psisol25.h"
#include "psisol5.h"
#include "psisol0.h"

/* Main data structure for information about input data. Not all the fields are
 * used */
typedef struct alldata
{
  int lens;							/* length of sequences */
  int profmat[MAXSEQLEN][PROLEN];	/* BLOSUM frequencies from PSIBLAST alignment - unused but can't remove without segfault? */
  float psimat[MAXSEQLEN][PSILEN];	/* PSIBLAST PSSM */
  float hmmmat[MAXSEQLEN][PROLEN];	/* results from HMMER */
}
alldata;

/* Global Vars - used to specify which input profiles have been provided */
int NOPSI = 0;
int NOHMM = 0;
int HUMAN = 0;  /* toggle human readable output */
int BLOCK = 60; /* block size for human output */

/* PSSM-specific functions */
void readpsi (FILE * psifile, alldata * data);
void doprofpsi (const alldata * data, const int win, const int curpos, float
psiar[30][30]);

/* HMMer-specific functions */
void readhmm (FILE * hmmfile, alldata * data);
void doprofhmm (const alldata * data, const int win, const int curpos, float
psiar[30][30]);

/* General or non-specific functions */
void int2pred (const int *pred, char *letpred, const int length);
float doconf (const float confa, const float confb, const float confc);
void dowinsspsi (float seq2str[MAXSEQLEN][3], int win, int curpos, float
winarss[30][4], const alldata * data);
void dopred (const alldata * data);
void test_size (int size, int required_size, char *name);
void print_human (int length, char pred[MAXSEQLEN], float conf[MAXSEQLEN]);

/* Prediction post-processing functions - not be used anymore, but retained for testing */
/* Executing controlled by #define FILTER */
void filter (char inp[MAXSEQLEN], char outp[MAXSEQLEN]);
void StrReplStr (char *s1, char *s2, char *FromSStr, char *ToSStr);
char *Strncat (char *s1, char *s2, int len);

/*************************************************************/
int main (int argc, char **argv) {
   FILE *psifile, *hmmfile;
   alldata *data;

   /* Declared in cmdline/cmdline.h */
   struct gengetopt_args_info args_info;

   /* Set up the data structure for the input data */
   if ((data = malloc(sizeof(alldata))) == NULL) {
      fprintf(stderr, "Malloc failed at line %i\n", __LINE__);
      exit(EXIT_FAILURE);
   }

   /* Get the command line arguments */
   if (cmdline_parser (argc, argv, &args_info) != 0)
      exit(EXIT_FAILURE);

   /* Print version info - CMDLINE_PARSER_PACKAGE CMDLINE_PARSER_VERSION declared in cmdline/cmdline.h */
   fprintf(stderr, "%s %s\n", CMDLINE_PARSER_PACKAGE, CMDLINE_PARSER_VERSION);

   /* Read the HMMER file. Don't need to check if it is given as is a required option */
   if ((hmmfile = fopen(args_info.hmmer_arg, "r")) == NULL) {
      fprintf(stderr, "ERROR: Can't open HMMER file %s\n", args_info.hmmer_arg);
      exit(EXIT_FAILURE);
   } else {
      fprintf(stderr, "Found HMM profile data\n");
      readhmm(hmmfile, data);
      (void) fclose(hmmfile);
   }

   /* Read the PSIBLAST PSSM */
   if (args_info.pssm_given) {
      if ((psifile = fopen(args_info.pssm_arg, "r")) == NULL) {
         fprintf(stderr, "ERROR: Can't open PSSM profile file %s\n", args_info.pssm_arg);
         exit(EXIT_FAILURE);
      } else {
         fprintf (stderr, "Found PSSM profile file\n");
         readpsi(psifile, data);
         (void) fclose(psifile);
      }
   } else {
      NOPSI = 1;
   }

   /* check whether human readable output is required (set by --human) */
   if (args_info.human_given) {
      HUMAN = 1;
      if (args_info.human_orig!= NULL) {
         printf("human: %d\n", args_info.human_arg);
         printf("human orig: %s\n", args_info.human_orig);
         BLOCK = args_info.human_arg;
         if (BLOCK > MAXBLOCK) {
            fprintf(stderr, "ERROR - argument for --human is too large\n");
            exit(EXIT_FAILURE);
         }
      }
   }

   /* Do the prediction */
   fprintf(stderr, "Running final predictions!\n");
   dopred (data);

   /* Free memory */
   free(data);

   return EXIT_SUCCESS;
}


/* Replaces particular runs of secondary structure with something else */
void filter (char inp[MAXSEQLEN], char outp[MAXSEQLEN]) {
	int i;

	struct filter_pair {
		char *orig;
		char *final;
	} pairs[] = {
		{"EHHHE", "EEEEE"},
		{"-HHH-", "HHHHH"},
		{"EHHH-", "EHHHH"},
		{"HHHE-", "HHH--"},
		{"-EHHH", "--HHH"},
		{"EHHE",  "EEEE"},
		{"-HEH-", "-HHH-"},
		{"EHH-",  "EEE-"},
		{"-HHE",  "-EEE"},
		{"-HH-",  "----"},
		{"HEEH",  "EEEE"},
		{"-HE",   "--E"},
		{"EH-",   "E--"},
		{"-H-",   "---"},
		{"HEH",   "HHH"},
		{"-E-E-", "-EEE-"},
		{"E-E",   "EEE"},
		{"H-H",   "HHH"},
		{"EHE",   "EEE"},
		{ NULL, NULL}
	};

	for (i = 0; pairs[i].orig != NULL; i++) {
		StrReplStr(outp, inp, pairs[i].orig, pairs[i].final);
		strcpy(inp, outp);
	}
}

/* Reads in the PSIBLAST PSSM */
void readpsi (FILE * psifile, alldata * data) {
   int nlines = 0;

   while ((getc (psifile)) != EOF) {
     float tempval;
     int i;
     for (i = 0; i < 20; i++) {
       int npar = fscanf (psifile, "%f", &tempval);
       if (npar == -1) break;
       if (1 == npar) {
	 data->psimat[nlines][i] = tempval;
       } else {
	 fprintf (stderr, "ERROR: Can't read a value from PSSM file");
	 data->psimat[nlines][i] = 0.;
       }
     }
     nlines++;
   }

   /* check the data length matches that of the HMMer data */
   if (data->lens != nlines-1) {
      fprintf(stderr, "Error - PSSM data length doesn't match that for HMMer. Are both input files from the same alignment/sequence?\n");
      exit(EXIT_FAILURE);
   }
}


/* Reads in HMMER profile that was originally based upon ClustalW alignments */
/* Additionally, use this data to define the length of the sequence in the absence of an alignment */
void readhmm (FILE * hmmfile, alldata * data) {
   int nlines = 0;

   while ((getc (hmmfile)) != EOF) {
     int i;

     if (nlines > MAXSEQLEN) {
       fprintf (stderr, "ERROR! the HMMER profile is too long. Can't cope... must quit.\n");
       exit (EXIT_FAILURE);
     }

     for (i = 0; i < 24; i++) {
       float tempval;
       int npar = fscanf (hmmfile, "%f", &tempval);
       if (npar == -1) break;
       if (1 == npar) {
	 data->hmmmat[nlines][i] = tempval;
       } else {
	 fprintf (stderr, "ERROR: Can't read a value from HMMER profile file.\n");
	 data->hmmmat[nlines][i] = 0.;
       }
     }
     nlines++;
   }
   data->lens = nlines-1;   /* set the query sequence length */
}

/* Function to test whether the data array for input
   into the Neural Network function is of the expected size */
void test_size (int size, int required_size, char *name) {
	if (size != required_size) {
		fprintf(stderr, "Input array not of correct size for %s (%i vs. %i)\n", name, size, required_size);
		exit(EXIT_FAILURE);
	}
}



/***********************************************************************/
/* Functions below here haven't been checked */

void dowinsspsi (float seq2str[MAXSEQLEN][3], int win, int curpos, float winarss[30][4], const alldata * data) {
	int i, j;

	for (j = 0, i = (curpos - ((win - 1) / 2)); i <= (curpos + ((win - 1) / 2)); i++, j++) {

		if (i >= 0 && i < data->lens) {
         /* CC - changesd to make it more similar to network training */

			/* for (k = 0; k < 3; k++)
				winarss[j][k] = seq2str[i][k]; */

         if ((seq2str[i][0] > seq2str[i][1]) && (seq2str[i][0] > seq2str[i][2])) {
            winarss[j][0] = 1.0;
            winarss[j][1] = 0.0;
            winarss[j][2] = 0.0;
         } else if ((seq2str[i][1] > seq2str[i][0]) && (seq2str[i][1] > seq2str[i][2])) {
            winarss[j][0] = 0.0;
            winarss[j][1] = 1.0;
            winarss[j][2] = 0.0;
         } else if ((seq2str[i][2] > seq2str[i][0]) && (seq2str[i][2] > seq2str[i][1])) {
            winarss[j][0] = 0.0;
            winarss[j][1] = 0.0;
            winarss[j][2] = 1.0;
         } else {
            winarss[j][0] = 0.0;
            winarss[j][1] = 0.0;
            winarss[j][2] = 1.0;
         }
		}
		else if (i < 0 || i >= data->lens) {
			/* Setting winarss[j][2] to 1 increases q3 accuracy */
         /* CC - does it really??? */
			winarss[j][0] = 0.0;
			winarss[j][1] = 0.0;
			winarss[j][2] = 0.0;
		}
	}
}

/* Structure to hold data from networks */
typedef struct netdata {
	int ps1;
	float * netin;
	float * netprofin;
} netdata;

void dopred (const alldata * data) {
	extern int NOHMM, NOPSI;

	float psi2net[MAXSEQLEN][3];
	float hmmnet[MAXSEQLEN][3];

	float finalout[MAXSEQLEN][3];
	int psi2fin[MAXSEQLEN];
	int hmmfin[MAXSEQLEN];
	int consfin[MAXSEQLEN];

	char psi2let[MAXSEQLEN];
	char hmmlet[MAXSEQLEN];
	char finlet[MAXSEQLEN];

	char sollet25[MAXSEQLEN];
	char sollet5[MAXSEQLEN];
	char sollet0[MAXSEQLEN];

	float netprofin3[500];
	float confidence[MAXSEQLEN];		/* Array for holding the confidence
										   value calculated by doconf() */
	float psiar[WINAR][WINAR];
	int winar2[WINAR][WINAR];

	float solacc25[MAXSEQLEN][2];
	float solacc5[MAXSEQLEN][2];
	float solacc0[MAXSEQLEN][2];

	float winarss[WINAR][4];

	char letfilt[MAXSEQLEN];

	int i, t;
	char jury[MAXSEQLEN];

	float netprofin[MAXSEQLEN];
	memset(netprofin, 0x00, sizeof(float) * MAXSEQLEN);
	memset(winar2, 0x00, sizeof(winar2[0][0]) * WINAR * WINAR);

	letfilt[0] = '\0';

#ifdef HMM
	{
		float seq2str[MAXSEQLEN][3];
		int i, windows = 17;
		for (i = 0; i < data->lens; i++) {
			float nn_output[ 3 ];

			int y, j = 0;
			doprofhmm (data, windows, i, psiar);

			for (y = 0; y < windows; y++) {
				int z;
				for (z = 0; z < PROLEN; z++)
					netprofin3[j++] = psiar[y][z];
			}

			test_size(j, hmm1REC.NoOfInput, "hmm1");

			hmm1 (netprofin3, nn_output, 0);
			seq2str[i][0] = nn_output[0];
			seq2str[i][1] = nn_output[1];
			seq2str[i][2] = nn_output[2];
         /* printf("%5.2f %5.2f %5.2f\n", seq2str[i][0], seq2str[i][1], seq2str[i][2]); */
		}

     /*  printf("\n"); */
		windows = 19;
		for (i = 0; i < data->lens; i++) {
			int y, j = 0;
			float nn_output[ 3 ];
			float nn_input[ 19 * 3 ];

			dowinsspsi (seq2str, windows, i, winarss, data);

			for (y = 0; y < windows; y++) {
				int z;
				for (z = 0; z < 3; z++)
					nn_input[ j++ ] = winarss[y][z];
			}

			test_size(j, hmm2REC.NoOfInput, "hmm2");

			hmm2 (nn_input, nn_output, 0);
			hmmnet[i][0] = nn_output[0];
			hmmnet[i][1] = nn_output[1];
			hmmnet[i][2] = nn_output[2];
         /* printf("%5.2f %5.2f %5.2f\n", hmmnet[i][0], hmmnet[i][1], hmmnet[i][2]); */
		}
	}
#endif /* end ifdef HMM */

	if (NOHMM == 0) {
		int i, windows = 17;
		for (i = 0; i < data->lens; i++) {
			float nn_output[ 3 ];
			int y, j = 0;
			doprofhmm (data, windows, i, psiar);

			for (y = 0; y < windows; y++) {
				int z;
				for (z = 0; z < 24; z++)
					netprofin3[j++] = psiar[y][z];
			}

			test_size(j, hmmsol25REC.NoOfInput, "hmmsol25");

			hmmsol25 (netprofin3, nn_output, 0);
			solacc25[i][0] = nn_output[0];
			solacc25[i][1] = nn_output[1];

         test_size(j, hmmsol5REC.NoOfInput, "hmmsol5");

			hmmsol5 (netprofin3, nn_output, 0);
			solacc5[i][0] = nn_output[0];
			solacc5[i][1] = nn_output[1];

         test_size(j, hmmsol0REC.NoOfInput, "hmmsol0");

			hmmsol0 (netprofin3, nn_output, 0);
			solacc0[i][0] = nn_output[0];
			solacc0[i][1] = nn_output[1];
		}
	}

	if (NOPSI == 0) {
		int i, windows = 17;
		for (i = 0; i < data->lens; i++) {
			float nn_output[ 3 ];
			int y, j = 0;
			doprofpsi (data, windows, i, psiar);

			for (y = 0; y < windows; y++) {
				int z;
				for (z = 0; z < 20; z++)
					netprofin3[j++] = psiar[y][z];
			}

			test_size(j, psisol25REC.NoOfInput, "psisol25");

			psisol25 (netprofin3, nn_output, 0);
			solacc25[i][0] += nn_output[0];
			solacc25[i][1] += nn_output[1];

         test_size(j, psisol5REC.NoOfInput, "psisol5");

			psisol5 (netprofin3, nn_output, 0);
			solacc5[i][0] += nn_output[0];
			solacc5[i][1] += nn_output[1];

         test_size(j, psisol0REC.NoOfInput, "psisol0");

			psisol0 (netprofin3, nn_output, 0);
			solacc0[i][0] += nn_output[0];
			solacc0[i][1] += nn_output[1];
		}
	}

	for (i = 0; i < data->lens; i++) {
		if (solacc25[i][0] > solacc25[i][1]) {
			sollet25[i] = '-';
		}
		if (solacc25[i][1] > solacc25[i][0]) {
			sollet25[i] = 'B';
		}
		if (solacc5[i][0] > solacc5[i][1]) {
			sollet5[i] = '-';
		}
		if (solacc5[i][1] > solacc5[i][0]) {
			sollet5[i] = 'B';
		}
		if (solacc0[i][0] > solacc0[i][1]) {
			sollet0[i] = '-';
		}
		if (solacc0[i][1] > solacc0[i][0]) {
			sollet0[i] = 'B';
		}
	}

	if (NOPSI == 0) {
		float seq2str[MAXSEQLEN][3];
		int i, windows = 17;

		/* This is for the PSIBLAST PSSM, for which there are two networks for
		 * each layer */
		memset(psi2net, 0x00, MAXSEQLEN * 3);
#ifdef PSSM
		for (t = 0; t < 2; t++) {

			/* First network */
			windows = 17;
			for (i = 0; i < data->lens; i++) {
				int y, j = 0;
				float nn_output[ 3 ];

				doprofpsi (data, windows, i, psiar);

				for (y = 0; y < windows; y++) {
					int z;
					for (z = 0; z < 20; z++)
						netprofin[j++] = psiar[y][z];
				}


				if (t == 0) {
	            test_size(j, pssma1REC.NoOfInput, "pssma1");
					pssma1 (netprofin, nn_output, 0);
				} else if (t == 1) {
	            test_size(j, pssmb1REC.NoOfInput, "pssmb1");
					pssmb1 (netprofin, nn_output, 0);
				}

				seq2str[i][0] = nn_output[0];
				seq2str[i][1] = nn_output[1];
				seq2str[i][2] = nn_output[2];
			}

			/* Second network */
			windows = 19;
			for (i = 0; i < data->lens; i++) {
				int y, j = 0;
				float nn_output[ 3 ];
				float nn_input[ 19 * 3 ];

				dowinsspsi (seq2str, windows, i, winarss, data);

				for (y = 0; y < windows; y++) {
					int z;
					for (z = 0; z < 3; z++)
						nn_input[j++] = winarss[y][z];
				}


				if (t == 0) {
	            test_size(j, pssma2REC.NoOfInput, "pssma2");
					pssma2 (nn_input, nn_output, 0);
				} else if (t == 1) {
	            test_size(j, pssmb2REC.NoOfInput, "pssmb2");
					pssmb2 (nn_input, nn_output, 0);
				}

				psi2net[i][0] += nn_output[0];
				psi2net[i][1] += nn_output[1];
				psi2net[i][2] += nn_output[2];
			}
		}
      for (i = 0; i < data->lens; i++) {
         psi2net[i][0] /= 2;
         psi2net[i][1] /= 2;
         psi2net[i][2] /= 2;
      }
#else
		for (i = 0; i < data->lens; i++) {
			psi2net[i][0] = 0;
			psi2net[i][1] = 0;
			psi2net[i][2] = 0;
		}
#endif /* end of ifdef PSSM */
	}

	/* Work out the final output values for the various outputs
	 * There is some smoothing going on at the ends of the sequences
	 * Also, some of these are being done even if there is no data in them.
	 * */

   if (NOPSI == 0) {
#ifdef PSSM
      for (i = 0; i < data->lens; i++) {
         finalout[i][0] = psi2net[i][0];
         finalout[i][1] = psi2net[i][1];
         finalout[i][2] = psi2net[i][2];

#ifdef POST
         if (i <= 4)
            finalout[i][2] += (5 - i) * 0.2;
         else if (i >= (data->lens - 5))
            finalout[i][2] += (5 - ((data->lens - 1) - i)) * 0.2;
#endif

         if (finalout[i][0] > finalout[i][1] && finalout[i][0] > finalout[i][2])
            psi2fin[i] = SHEET;
         if (finalout[i][1] > finalout[i][0] && finalout[i][1] > finalout[i][2])
            psi2fin[i] = HELIX;
         if (finalout[i][2] > finalout[i][0] && finalout[i][2] > finalout[i][1])
            psi2fin[i] = COIL;
      }
      int2pred(psi2fin, psi2let, data->lens);
#endif /* end PSSM */
   }

#ifdef HMM
	if (NOHMM == 0) {
		for (i = 0; i < data->lens; i++) {
			finalout[i][0] = hmmnet[i][0];
			finalout[i][1] = hmmnet[i][1];
			finalout[i][2] = hmmnet[i][2];

#ifdef POST
			if (i <= 4)
				finalout[i][2] += (5 - i) * 0.2;
			else if (i >= (data->lens - 5))
				finalout[i][2] += (5 - ((data->lens - 1) - i)) * 0.2;
#endif

			if (finalout[i][0] > finalout[i][1] && finalout[i][0] > finalout[i][2])
				hmmfin[i] = SHEET;
			if (finalout[i][1] > finalout[i][0] && finalout[i][1] > finalout[i][2])
				hmmfin[i] = HELIX;
			if (finalout[i][2] > finalout[i][0] && finalout[i][2] > finalout[i][1])
				hmmfin[i] = COIL;
		}
		int2pred(hmmfin, hmmlet, data->lens);
	}
#endif /* end ifdef HMM */

	/* When all data is available use the 'cons' network to
    * decide all non-jury positions.
	 * Also calculate the confidence values */
	if (NOPSI == 0) {
		int j;
		for (j = 0; j < data->lens; j++) {

			/* Is there disagreement? */
         if (psi2let[j] == hmmlet[j]) { /* No - use the PSI networks */
            jury[j] = ' ';
            consfin[j] = psi2fin[j];

            confidence[j] = doconf (psi2net[j][0], psi2net[j][1], psi2net[j][2]);

         } else { /* yes - take the mean propensities of the HMM and PSI networks */
            jury[j] = '*';

#ifdef HMMONLY
            finalout[j][0] = hmmnet[j][0];
            finalout[j][1] = hmmnet[j][1];
            finalout[j][2] = hmmnet[j][2];
#else
            finalout[j][0] = (hmmnet[j][0] + psi2net[j][0])/2;
            finalout[j][1] = (hmmnet[j][1] + psi2net[j][1])/2;
            finalout[j][2] = (hmmnet[j][2] + psi2net[j][2])/2;
#endif  /* end HMMONLY */

            confidence[j] = doconf (finalout[j][0], finalout[j][1], finalout[j][2]);

            consfin[j] = COIL;

            if (finalout[j][0] > finalout[j][1] && finalout[j][0] > finalout[j][2])
               consfin[j] = SHEET;
            if (finalout[j][1] > finalout[j][0] && finalout[j][1] > finalout[j][2])
               consfin[j] = HELIX;
            if (finalout[j][2] > finalout[j][0] && finalout[j][2] > finalout[j][1])
               consfin[j] = COIL;

			} /* agreement if/else block */




		} /* end of sequence */
		consfin[data->lens] = 25;
	} /* end of if (NOHMM==0 && NOPSI==0) */

	/* Calculate the confidence values */
	if (NOPSI == 1) {
		fprintf (stderr,
				"\n\nWARNING!: Only using the HMM profile\nAccuracy will average 79.6%%\n\n");
		for (i = 0; i < data->lens; i++) {
			consfin[i] = hmmfin[i];

			confidence[i] =
				doconf ((hmmnet[i][0]), (hmmnet[i][1]), (hmmnet[i][2]));
		}
		consfin[data->lens] = 25;
	}

	if (NOPSI == 0) {
		fprintf (stderr,
				"\n\nBoth PSIBLAST and HMM profiles were found\nAccuracy will average 82.0%%\n\n");
	}
	int2pred(consfin, finlet, data->lens);
	finlet[ data->lens ] = '\0';

#ifdef FILTER
	/* Remove unlikely secondary structure */
	filter(finlet, letfilt);
	filter(finlet, letfilt);
	filter(finlet, letfilt);
#else
	memcpy(letfilt, finlet, sizeof(char) * MAXSEQLEN);
	/*memcpy(letfilt, finlet, data->lens);*/
#endif

	/* output predictions */
	if (HUMAN) /* print human readable and quit */
      print_human(data->lens, letfilt, confidence);

   printf ("\njnetpred:");
   for (i = 0; i < data->lens; i++)
      printf ("%c,", letfilt[i]);
   printf ("\nJNETCONF:");
   for (i = 0; i < data->lens; i++)
      printf ("%1.0f,", confidence[i]);
   printf ("\nJNETSOL25:");
   for (i = 0; i < data->lens; i++)
      printf ("%c,", sollet25[i]);
   printf ("\nJNETSOL5:");
   for (i = 0; i < data->lens; i++)
      printf ("%c,", sollet5[i]);
   printf ("\nJNETSOL0:");
   for (i = 0; i < data->lens; i++)
      printf ("%c,", sollet0[i]);
   printf ("\nJNETHMM:");
   for (i = 0; i < data->lens; i++)
      printf ("%c,", hmmlet[i]);

   if (NOPSI == 0) {
      printf ("\nJNETPSSM:");
      for (i = 0; i < data->lens; i++)
         printf ("%c,", psi2let[i]);
      printf ("\nJNETJURY:");
      for (i = 0; i < data->lens; i++)
         printf ("%c,", jury[i]);
   }

   printf ("\nJNETPROPE:");
   for (i = 0; i < data->lens; i++)
      printf ("%.4f,", hmmnet[i][0]);
   printf ("\nJNETPROPH:");
   for (i = 0; i < data->lens; i++)
      printf ("%.4f,", hmmnet[i][1]);
   printf ("\nJNETPROPC:");
   for (i = 0; i < data->lens; i++)
      printf ("%.4f,", hmmnet[i][2]);
   printf("\n");
}

/* Calculate confidence as for PHD method (Rost and Sander, JMB, 1993, v232,
 * p584)
 * */
float doconf (const float confa, const float confb, const float confc) {
	float whichout, maxout, maxnext, outconf;
	whichout = outconf = maxnext = 0;
	maxout = confc;

	if (confa > confb && confa > confc) {
		whichout = 0;
		maxout = confa;
	}
	if (confb > confa && confb > confc) {
		whichout = 1;
		maxout = confb;
	}
	if (confc > confa && confc > confb) {
		whichout = 2;
		maxout = confc;
	}

	if (whichout == 0) {
		if (confb > confc)
			maxnext = confb;
		if (confc > confb)
			maxnext = confc;
	}
	if (whichout == 1) {
		if (confc > confa)
			maxnext = confc;
		if (confa > confc)
			maxnext = confa;
	}
	if (whichout == 2) {
		if (confb > confa)
			maxnext = confb;
		if (confa > confb)
			maxnext = confa;
	}
	outconf = 10 * (maxout - maxnext);
	if (outconf > 9)
		outconf = 9;

	return outconf;
}

void StrReplStr (char *s1, char *s2, char *FromSStr, char *ToSStr) {
	char *ChP1, *ChP2;

	s1[0] = '\0';
	ChP1 = s2;

	while ((ChP2 = strstr (ChP1, FromSStr)) != NULL) {
		if (ChP1 != ChP2)
			Strncat (s1, ChP1, strlen (ChP1) - strlen (ChP2));
		strcat (s1, ToSStr);
		ChP1 = ChP2 + strlen (FromSStr);
	}
	strcat (s1, ChP1);
	return;
}

char *Strncat (char *s1, char *s2, int len) {
	int OrigLen = 0;
	if (len == 0) {
		fprintf (stderr, "Strncat error!");
		return s1;
	}

	if (s1 == NULL || s2 == NULL) {
		fprintf (stderr, "Strncat error!");
		return NULL;
	}
	OrigLen = strlen (s1);
	if (strncat (s1, s2, len) == NULL) {
		fprintf (stderr, "Strncat error!");
		return NULL;
	}

	s1[OrigLen + len] = '\0';

	return s1;
}

/* Finds the data around the current position in a window */
void doprofpsi (const alldata * data, const int win, const int curpos, float psiar[30][30]) {
	int i, j = 0;

	for (i = (curpos - ((win - 1) / 2)); i <= (curpos + ((win - 1) / 2)); i++) {
		int k;
		for (k = 0; k < 20; k++) {
			psiar[j][k] = data->psimat[i][k];
		}

		if (i < 0 || i >= data->lens)
			memset(psiar[j], 0x00, sizeof(psiar[0][0]) * 30);

		j++;
	}
}

/* Converts an array of predicted structure to a character array, not a null
 * terminated string */
void int2pred (const int *pred, char *letpred, const int length) {
	int i;

	for (i = 0; i < length; i++) {
		switch (pred[i]) {
			case HELIX: letpred[i] = 'H'; break;
			case SHEET: letpred[i] = 'E'; break;
			case COIL: letpred[i] = '-'; break;
			/*case 25: letpred[i] = '\0'; break;*/
			default:
				fprintf(stderr, "ERROR: unknown secondary structure type '%i' at position %i in int2pred \n", pred[i], i);
				exit(EXIT_FAILURE);
				break;
		}
	}
}

void doprofhmm (const alldata * data, const int win, const int curpos, float psiar[30][30]) {
	int i, j, k;
	j = k = i = 0;

	for (i = (curpos - ((win - 1) / 2)); i <= (curpos + ((win - 1) / 2)); i++) {
		for (k = 0; k < 24; k++)
			psiar[j][k] = data->hmmmat[i][k];

		if (i < 0 || i >= data->lens)
			for (k = 0; k < 24; k++)
				psiar[j][k] = 0;
		j++;
	}
}

/** print out a human readable version of the prediction and confidence **/
void print_human (int length, char pred[MAXSEQLEN], float conf[MAXSEQLEN]) {
   int i, j = 0, k; /* counters */

   float *confout; /* array pointers to temp storage of output lines */
   char *predout;

   /* allocate memory to array pointers */
   confout = malloc(BLOCK * sizeof(float));
   if (confout == NULL) {
      fprintf(stderr, "Out of memory\n");
      exit(EXIT_FAILURE);
   }

   predout = malloc(BLOCK * sizeof(char));
   if (predout == NULL) {
      fprintf(stderr, "Out of memory\n");
      exit(EXIT_FAILURE);
   }

   for (i = 0; i < length; i++) {
      confout[j] = conf[i]; /* store current conf value */
      predout[j] = pred[i]; /* store current prediction value */

      /* when reached end of block, print stuff out */
      if (i > 1 && i % BLOCK == 0) {
         printf("\n\npred:  ");
         for (k = 0; k < BLOCK; ++k)
            printf("%c", predout[k]);

         printf("\nconf:  ");
         for (k = 0; k < BLOCK; ++k)
            printf("%1.0f", confout[k]);

         j = 0; /* zero the block counter */
      }

      ++j;
   }

   /* catch any trailing blocks that are smaller than required */
   if (j)
      printf("\n\npred:  ");
   for (k = 0; k < j; ++k)
      printf("%c", predout[k]);

   printf("\nconf:  ");
   for (k = 0; k < j; ++k)
      printf("%1.0f", confout[k]);
   printf("\n");

   /* free memory and exit */
   free(confout);
   free(predout);
   exit(EXIT_SUCCESS);
}

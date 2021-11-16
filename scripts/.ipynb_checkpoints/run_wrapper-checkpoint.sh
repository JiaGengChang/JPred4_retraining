wdir="outputs/snns_cv_1_Oct";
path1="/cluster/homes/adrozdetskiy/Projects/jpredJnet231ReTrainingSummaryTable/scores/training/";
path2="/cluster/gjb_lab/2472402/$wdir";
cd $path2;
/cluster/gjb_lab/2472402/jpred_train/wrapper.pl -cross-val 7 -data $path1 -valid $path1 -wdir $path2 -out $wdir -debug 0 1>out 2>err & 

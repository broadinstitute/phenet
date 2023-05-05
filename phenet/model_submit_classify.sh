#!/bin/bash

script=$0
num_chunks=2

echo "script=$script"
echo "num_chunks=$num_chunks"

if [[ $SGE_TASK_ID ]]; then

  ######################
  ### Dotkit section ###
  ######################

  # This is required to use dotkits inside scripts
  source /broad/software/scripts/useuse

  # Use your dotkit
  reuse Python-3.9
  reuse Anaconda3

  source activate model
  ##################
  ### Run script ###
  ##################

  python /humgen/diabetes2/users/oliverr/git/phenet/phenet/multi_fit_new.py classify \
    --config-file /humgen/diabetes2/users/oliverr/git/phenet/cfg/lipo_base2_trained.cfg --pymc3 --debug-level 3 \
    --min-traits 3 \
    --num-chunks $num_chunks --chunk "$SGE_TASK_ID" \
    --delim ";" --output-file /humgen/diabetes2/users/oliverr/phenet/out/classifieds

else
    qsub -N phenet -l h_vmem=3G -l h_rt=4:00:00 -cwd -t 1-$num_chunks "$script"
fi


#!/bin/bash

options=$(getopt -l "num:" -o "n:" -a -- "$@")
eval set -- "$options"
while true; do
  case "$1" in
    -n|--num)
      shift
      export num_chunks=$1
      ;;
    --)
      shift
      break
      ;;
  esac
  shift
done

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
    --delim ";" --output-file /humgen/diabetes2/users/oliverr/phenet/out/classifieds

else
    qsub -N your_project_name -l h_vmem=2G -l h_rt=4:00:00 -cwd -j y -o your_log.log -t 1-$num_chunks run.sh
fi


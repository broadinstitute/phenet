#!/bin/bash

#############################
### Default UGER Requests ###
#############################

# This section specifies uger requests.  

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

python /humgen/diabetes2/users/oliverr/git/phenet/phenet/multi_fit_new.py classify --config-file /humgen/diabetes2/users/oliverr/git/phenet/cfg/lipo_base2_trained.cfg --pymc3 --debug-level 3 --delim ";" --output-file /humgen/diabetes2/users/oliverr/phenet/out/lipo_fit_all2.cfg

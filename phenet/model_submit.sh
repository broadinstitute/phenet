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
reuse Python-3.6
reuse Anaconda3

source activate model
##################
### Run script ###
##################

python /humgen/diabetes2/users/asayici/multi_fit_new.py train --config-file /humgen/diabetes2/users/asayici/config/lipo_base2.cfg --pymc3 --debug-level 3 --delim ";" --var-id-file /humgen/diabetes2/users/asayici/config/lipo_var_ids --output-file /humgen/diabetes2/users/asayici/lipo_fit_all2.cfg

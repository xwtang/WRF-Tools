#!/bin/bash
# source script to load P7-specific settings for pyWPS, WPS, and WRF
# created 06/07/2012 by Andre R. Erler, GPL v3

# load modules
module purge
#module load xlf/13.1 vacpp/11.1 pe/1.2.0.7 hdf5/187-v18-serial-xlc netcdf/4.1.3_hdf5_serial-xlc
module load xlf/14.1 vacpp/12.1 hdf5/187-v18-serial-xlc netcdf/4.1.3_hdf5_serial-xlc pe/1.2.0.7
# pyWPS.py specific modules
if [[ ${RUNPYWPS} == 1 ]]; then
    module load ncl/6.0.0 python/2.7.2
    #module load gcc/4.6.1 centos5-compat/lib64 ncl/6.0.0 python/2.7.2
fi
module list
echo

# cp-flag to prevent overwriting existing content
export NOCLOBBER='-n'

# RAM disk folder (cleared and recreated if needed)
export RAMDISK="/dev/shm/aerler/"

# launch executable
export HYBRIDRUN='poe' # evaluated by execWRF and execWPS

# WPS/preprocessing submission command (for next step)
export SUBMITWPS='ssh gpc01 "cd \"${INIDIR}\"; qsub ./${WPSSCRIPT} -v NEXTSTEP=${NEXTSTEP}"'

# archive submission command (for last step)
export SUBMITAR='ssh gpc-f104n084 "cd \"${INIDIR}\"; qsub ./${ARSCRIPT} -v TAGS=${ARTAG},MODE=BACKUP,INTERVAL=${ARINTERVAL}"'

# job submission command (for next step)
export RESUBJOB='ssh p7n01 "cd \"${INIDIR}\"; export NEXTSTEP=${NEXTSTEP}; llsubmit ./${WRFSCRIPT}"' # evaluated by resubJob

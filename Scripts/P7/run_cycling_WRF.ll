#!/bin/bash
# LoadLeveler submission script for SciNet P7

##=====================================
# @ job_name = test_2x128
# @ wall_clock_limit = 18:00:00
# @ node = 1
# @ tasks_per_node = 128
# @ notification = error
# @ output = $(job_name).$(jobid).out
# @ error = $(job_name).$(jobid).out
#@ environment = $NEXTSTEP; $NOWPS; MP_INFOLEVEL=1; MP_USE_BULK_XFER=yes; MP_BULK_MIN_MSG_SIZE=64K; \
#                MP_EAGER_LIMIT=64K; LAPI_DEBUG_ENABLE_AFFINITY=no; \
#                MP_RFIFO_SIZE=16777216; MP_EUIDEVELOP=min; \
#                MP_PULSE=0; MP_BUFFER_MEM=256M; MP_EUILIB=us; MP_EUIDEVICE=sn_all;\
#                XLSMPOPTS=parthds=1; MP_TASK_AFFINITY=CPU:1; MP_BINDPROC=yes
# #MP_FIFO_MTU=4K;
##=====================================
# @ job_type = parallel
# @ class = verylong
# @ node_usage = not_shared
# Specifies the name of the shell to use for the job
# @ shell = /bin/bash
##=====================================
## affinity settings
# #@ task_affinity=cpu(1)
# #@ cpus_per_core=4
# @ rset = rset_mcm_affinity
# @ mcm_affinity_options=mcm_distribute mcm_mem_req mcm_sni_none
##=====================================
## this is necessary in order to avoid core dumps for batch files
## which can cause the system to be overloaded
# ulimits
# @ core_limit = 0
#=====================================
## necessary to force use of infiniband network for MPI traffic
# #@ network.mpi = sn_single,not_shared,us,,instances=2
# #@ network.MPI = sn_all,not_shared,us, ,instances=1
# #@ network.MPI = sn_all,not_shared,US,HIGH
##=====================================
# @ queue

# check if $NEXTSTEP is set, and exit, if not
set -e # abort if anything goes wrong
if [[ -z "${NEXTSTEP}" ]]; then
  echo 'Environment variable $NEXTSTEP not set - aborting!'
  exit 1
fi
CURRENTSTEP="${NEXTSTEP}" # $NEXTSTEP will be overwritten
export NEXTSTEP
export CURRENTSTEP


## job settings
export JOBNAME="${LOADL_JOB_NAME}"
export WRFSCRIPT="run_cycling_WRF.ll" # WRF suffix assumed
export WPSSCRIPT="run_cycling_WPS.pbs" # run WPS on GPC (WPS suffix substituted for WRF): ${LOADL_JOB_NAME%_WRF}_WPS
export ARSCRIPT="" # archive script to be executed after WRF finishes
export ARINTERVAL="" # default: every time
export WAITFORWPS='WAIT' # stay on compute node until WPS for next step finished, in order to submit next WRF job
# run configuration
export NODES=$( echo "${LOADL_PROCESSOR_LIST}" | wc -w ) # infer from host list; set in LL section
export TASKS=128 # number of MPI task per node (Hpyerthreading!)
export THREADS=1 # number of OpenMP threads
# directory setup
export INIDIR="${LOADL_STEP_INITDIR}" # experiment root (launch directory)
export RUNNAME="${CURRENTSTEP}" # step name, not job name!
export WORKDIR="${INIDIR}/${RUNNAME}/" # step folder
export SCRIPTDIR="${INIDIR}/scripts/" # location of component scripts (pre/post processing etc.)
export BINDIR="${INIDIR}/bin/" # location of executables (WRF and WPS)
# N.B.: use absolute path for script and bin folders

echo
echo "Host list: ${LOADL_PROCESSOR_LIST}"
echo
module list
echo


###                                                                    ##
###   ***   Below this line nothing should be machine-specific   ***   ##
###                                                                    ##


# launch feedback
echo
hostname
uname
echo
echo "   ***   ${JOBNAME}   ***   "
echo


## real.exe settings
export RUNREAL=0 # don't run real.exe again (requires metgrid.exe output)
# optional arguments: $RUNREAL, $RAMIN, $RAMOUT
# folders: $REALIN, $REALOUT
# N.B.: RAMIN/OUT only works within a single node!

## WRF settings
# optional arguments: $RUNWRF, $GHG ($RAD, $LSM)
export GHG='' # GHG emission scenario
export RAD='' # radiation scheme
export LSM='' # land surface scheme
# folders: $WRFIN, $WRFOUT, $TABLES
export REALOUT="${WORKDIR}" # this should be default anyway
export WRFIN="${WORKDIR}" # same as $REALOUT
export WRFOUT="${INIDIR}/wrfout/" # output directory
export RSTDIR="${WRFOUT}"

## setup job environment
cd "${INIDIR}"
source "${SCRIPTDIR}/setup_WRF.sh" # load machine-specific stuff

## run WPS/pre-processing for next step
# read next step from stepfile
NEXTSTEP=$(python "${SCRIPTDIR}/cycling.py" "${CURRENTSTEP}")

# launch pre-processing for next step
eval "${SCRIPTDIR}/launchPreP.sh" # primarily for WPS and real.exe


## run WRF for this step
# N.B.: work in existing work dir, created by caller instance;
# i.e. don't remove namelist files in working directory!

# start timing
echo
echo "   ***   Launching WRF for current step: ${CURRENTSTEP}   ***   "
date
echo

# run script
eval "${SCRIPTDIR}/execWRF.sh"
ERR=$? # capture exit code
# mock restart files for testing (correct linking)
#if [[ -n "${NEXTSTEP}" ]]; then
#	touch "${WORKDIR}/wrfrst_d01_${NEXTSTEP}_00"
#	touch "${WORKDIR}/wrfrst_d01_${NEXTSTEP}_01"
#fi

if [[ $ERR != 0 ]]; then
  # end timing
  echo
  echo "   ###   WARNING: WRF step ${CURRENTSTEP} failed   ###   "
  date
  echo
  exit ${ERR}
fi # if error

# end timing
echo
echo "   ***   WRF step ${CURRENTSTEP} completed   ***   "
date
echo


## launch post-processing
eval "${SCRIPTDIR}/launchPostP.sh" # mainly archiving, but may include actual post-processing


## resubmit job for next step
eval "${SCRIPTDIR}/resubJob.sh" # requires submission command from setup script


# copy driver script into work dir to signal completion
cp "${INIDIR}/${WRFSCRIPT}" "${WORKDIR}"

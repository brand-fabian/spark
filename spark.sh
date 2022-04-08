#!/bin/bash

function usage {
  echo -e "$0\n\nStart a spark cluster within your slurm allocation.\n\nOptions:\n\t-i,--install-hail\tInstall hail in the context\n\t-s,--script\tExecutable to run within the new context (default: /bin/bash)\n\t--conda-env\tConda environment name to install hail to, if applicable.\n\t--hail-version\tHail version to install (default: main)\n\t--master-cores\tCores to reserve for the spark master (default: 1)\n\t-h,--help\tHelp";
}

options=$(getopt -o ihs: --long "install-hail help script: conda-env: hail-version: master-cores:" -- "$@")
[ $? -eq 0 ] || {
  usage
  echo "Invalid options provided"
  exit 1
}

export SCRIPT_DIR=/home/brand/scratch/misc/spark

export INSTALL_HAIL=1
export SCRIPT="/bin/bash"
export CONDA_ENV="xcat_spark"
export HAIL_VERSION="main"
export MASTER_RESERVED_CORES=1

eval set -- "$options"
while true; do
  case "$1" in
    -i | --install-hail)
      INSTALL_HAIL=0
      ;;
    -s | --script)
      shift
      SCRIPT="$1"
      ;;
    --conda-env)
      shift
      CONDA_ENV="xcat_spark"
      ;;
    --hail-version)
      shift
      HAIL_VERSION="$1"
      ;;
    --master-cores)
      shift
      MASTER_RESERVED_CORES="$1"
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
  esac
  shift
done

if [ -z "$SLURM_JOBID" ]; then
  echo "Not running in slurm job. Please run this script only inside a slurm job.";
  exit 1
fi

module use /software/easybuild/modules/all
module load foss/2021b lz4 Rust Anaconda3 Spark/3.1.1 

echo "Installing python & pip into $CONDA_ENV"
source $SCRIPT_DIR/create-env.sh

echo "Starting spark cluster in job"
source $SCRIPT_DIR/start-spark.sh

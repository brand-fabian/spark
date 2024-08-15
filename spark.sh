#!/bin/bash

export DEFAULT_SCRATCH_ROOT="${HOME}/scratch"

function usage {
  echo -e "$0\n\nStart a spark cluster within your slurm allocation.\n"
  echo -e "Options:"
  echo -e "\t-i,--install-hail\tInstall hail in the context"
  echo -e "\t-s,--script\t\tExecutable to run within the new context (default: /bin/bash)"
  echo -e "\t-X, --no-use-srun\tIf this flag is set, the script will be launched alongside the main spark task, otherwise srun is used to start it."
  echo -e "\t--conda-env\t\tConda environment name to install hail into, if applicable."
  echo -e "\t--conda-module\t\tConda easybuild module name (default: Miniconda3)."
  echo -e "\t--spark-module\t\tName of the spark lmod module to use."
  echo -e "\t--spark-version\t\tSpark version to use to create the cluster (default: auto-detect)."
  echo -e "\t--hail-version\t\tHail version to install (default: main)."
  echo -e "\t--spark-interface\tNetwork interface to bind for all spark daemons (default: ib0)."
  echo -e "\t--ipoib-domain\t\tChanged domain name for infiniband network addresses."
  echo -e "\t--master-cores\t\tCores to reserve for the spark master (default: 1)"
  echo -e "\t--scratch-dir\t\tScratch directory for temporary files generated by hail and / or Spark (default: ${DEFAULT_SCRATCH_ROOT})."
  echo -e "\t-h,--help\t\tPrint this help message"
}

options=$(getopt -o ihXs: --long "install-hail help no-use-srun script: conda-env: conda-module: hail-version: spark-module: spark-version: spark-interface: ipoib-domain: master-cores: scratch-dir:" -- "$@")
[ $? -eq 0 ] || {
  usage
  echo "Invalid options provided"
  exit 1
}

export SCRIPT_DIR=/home/brand/scratch/misc/spark

export INSTALL_HAIL=1
export SCRIPT="/bin/bash"
export CONDA_ENV="spark"
export CONDA_MODULE="Miniconda3"
export HAIL_VERSION="main"
export MASTER_RESERVED_CORES=1
export SPARK_MODULE="Spark"
export SPARK_VERSION=""
export SPARK_INTERFACE="ib0"
export IPOIB_DOMAIN=""
export SCRATCH_ROOT="$DEFAULT_SCRATCH_ROOT"
export USE_SRUN=0

eval set -- "$options"
while true; do
  case "$1" in
    -i | --install-hail)
      INSTALL_HAIL=0
      ;;
    -X | --no-use-srun)
      USE_SRUN=1
      ;;
    -s | --script)
      shift
      SCRIPT="$1"
      ;;
    --conda-env)
      shift
      CONDA_ENV="xcat_spark"
      ;;
    --conda-module)
      shift
      CONDA_MODULE="$1"
      ;;
    --hail-version)
      shift
      HAIL_VERSION="$1"
      ;;
    --spark-module)
      shift
      SPARK_MODULE="$1"
      ;;
    --spark-version)
      shift
      SPARK_VERSION="$1"
      ;;
    --spark-interface)
      shift
      SPARK_INTERFACE="$1"
      ;;
    --ipoib-domain)
      shift
      IPOIB_DOMAIN="$1"
      ;;
    --master-cores)
      shift
      MASTER_RESERVED_CORES="$1"
      ;;
    --scratch-dir)
      shift
      SCRATCH_ROOT="$(realpath $1)"
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

echo "Installing python & pip into $CONDA_ENV"
source $SCRIPT_DIR/create-env.sh

echo "Starting spark cluster in job"
source $SCRIPT_DIR/start-spark.sh

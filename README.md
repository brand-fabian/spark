# xcat/spark

Spark scripts to launch a spark cluster on xcat. Optionally, the script can
install hail and its dependencies into the job environment.

## Usage

End-users envisioned usage is to use the `spark.sh` as a wrapper for their
job script. Instead of the command line this can also be used in a sbatch
script submission or interactive job. 

Usage:

```
Start a spark cluster within your slurm allocation.

Options:
        -i,--install-hail       Install hail in the context
        -s,--script     Executable to run within the new context (default: /bin/bash)
        --conda-env     Conda environment name to install hail to, if applicable.
        --hail-version  Hail version to install (default: main)
        --master-cores  Cores to reserve for the spark master (default: 1)
        -h,--help       Help
```

Example:

```bash
sbatch --gres localtmp:15G --ntasks 30 --cpus-per-task 22 \
  --mem-per-cpu 4G --time 12:00:00 --partition batch \
  /home/brand/misc/spark/spark.sh --hail-version 0.2.89 \
  -is "/home/brand/scratch/conda/envs/xcat_spark/bin/python3 /ceph01/homedirs/brand/Projects/radarstudy/msdn_call/scripts/find_dnm/find_dnms.py -p output/spark.all/ac100 -f /ceph01/homedirs/brand/Projects/radarstudy/msdn_call/data/all.fam -R /ceph01/scratch/brand/library/human_g1k_v37_decoy.fasta --max-ac 100 INOVA:/ceph01/homedirs/brand/Projects/radarstudy/glnexus/output/inova.genome.vcf.bgz RADAR:/ceph01/homedirs/brand/Projects/radarstudy/glnexus/output/radar.grch37.final.vcf.bgz"
```

## Dependencies

A job launched via this script depends on some Easybuild-modules, namely
`foss/2021b lz4 Rust Anaconda3 Spark/3.1.1`. By default, a conda environment
is created to install python dependencies into (default name: `xcat_spark`). 
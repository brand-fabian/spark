#!/bin/python3

import hail as hl
import os

##
# Initialize hail with environment variables set in the `spark.sh`
# scripts.
hl.init(
    master=f"spark://{os.getenv('SPARK_MASTER_IP', None)}:{os.getenv('SPARK_MASTER_PORT', None)}",
    idempotent=True,
    tmp_dir=os.getenv("SPARK_LOCAL_DIRS", os.getcwd()),
    local_tmpdir=os.getenv("SCRATCH_DIR", "/tmp"),
    log=os.path.join(os.getenv("SPARK_LOCAL_DIRS", os.getcwd()), "hail.log"),
    # copy_spark_log_on_error=True,
    spark_conf={
        "spark.local.dir": os.getenv("SPARK_LOCAL_DIRS"),
        "spark.speculation": "true",
    },
)

##
# Execute the standard hail code example, no disk writes are being
# performed. Output should be a table containing gwas results p-values
# for the imputed snps.
# Source: https://hail.is/docs/0.2/install/other-cluster.html
mt = hl.balding_nichols_model(n_populations=3,
    n_samples=500,
    n_variants=500_000,
    n_partitions=32)
mt = mt.annotate_cols(drinks_coffee = hl.rand_bool(0.33))
gwas = hl.linear_regression_rows(y=mt.drinks_coffee,
    x=mt.GT.n_alt_alleles(),
    covariates=[1.0])
gwas.order_by(gwas.p_value).show(25)

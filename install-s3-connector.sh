# Install the Spark hadoop-AWS toolkit
# Adapted from: https://gist.github.com/danking/f8387f5681b03edc5babdf36e14140bc

module load "$SPARK_MODULE"
set -x

# Prepare a new spark home that can be written to at $spark_home,
# to install the aws-jdk and hadoop-aws jars
if [ ! -d "${spark_home}/jars" ]; then
    mkdir -p "${spark_home}/jars"
    ln -s "$SPARK_HOME/jars/"* "${spark_home}/jars/"
fi

if [ ! -d "${spark_home}/conf" ]; then
    mkdir -p "${spark_home}/conf"
fi

for d in bin data easybuild examples kubernetes lib lib64 python R sbin share yarn; do
    test -L "${spark_home}/$d" || ln -s "${SPARK_HOME}/$d" "${spark_home}/$d"
done

# Fetch the hadoop version loaded by Spark / Hail and download
# the corresponding versions of the hadoop-aws jar. Some guessing
# is required for the aws-jdk jar.
hadoop_client_jar=$(ls "${spark_home}/jars/" | grep "hadoop-client" | head -n 1)
hadoop_client_base=$(basename $hadoop_client_jar)
hadoop_client_name=${hadoop_client_base%.*}
hadoop_version=${hadoop_client_name##*-}
aws_java_sdk_version=$(curl -isSL https://hadoop.apache.org/docs/r$hadoop_version/hadoop-aws/dependency-analysis.html \
    | grep -A 1 "aws-java-sdk-bundle" \
    | tail -n 1 \
    | cut -d'>' -f2 \
    | cut -d'<' -f1)


if [ ! -e "${spark_home}/jars/hadoop-aws-$hadoop_version.jar" ]; then
    curl -sSL \
        "https://search.maven.org/remotecontent?filepath=org/apache/hadoop/hadoop-aws/$hadoop_version/hadoop-aws-$hadoop_version.jar" \
        > "${spark_home}/jars/hadoop-aws-$hadoop_version.jar"
fi

if [ ! -e "${spark_home}/jars/aws-java-sdk-bundle-$aws_java_sdk_version.jar" ]; then
    curl -sSL \
        https://search.maven.org/remotecontent?filepath=com/amazonaws/aws-java-sdk-bundle/$aws_java_sdk_version/aws-java-sdk-bundle-$aws_java_sdk_version.jar \
        > "${spark_home}/jars/aws-java-sdk-bundle-$aws_java_sdk_version.jar"
fi

export SPARK_HOME="${spark_home}"

# set default aws credentials providers that try, in order: aws cli credentials and anonymous credentials.
sed -i.bak \
    '/^### START: DO NOT EDIT, MANAGED BY: install-s3-connector.sh$/,/### END: DO NOT EDIT, MANAGED BY: install-s3-connector.sh/d' \
    ${spark_home}/conf/spark-defaults.conf
rm ${spark_home}/conf/spark-defaults.conf.bak
cat >> ${spark_home}/conf/spark-defaults.conf <<EOF
### START: DO NOT EDIT, MANAGED BY: install-s3-connector.sh
spark.hadoop.fs.s3a.aws.credentials.provider=com.amazonaws.auth.profile.ProfileCredentialsProvider,com.amazonaws.auth.profile.ProfileCredentialsProvider,org.apache.hadoop.fs.s3a.TemporaryAWSCredentialsProvider,org.apache.hadoop.fs.s3a.AnonymousAWSCredentialsProvider
### END: DO NOT EDIT, MANAGED BY: install-s3-connector.sh
EOF

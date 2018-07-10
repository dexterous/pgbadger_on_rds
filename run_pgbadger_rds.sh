#!/bin/bash

# set -o xtrace


#. ~/.bash_profile
# script to generate pgbadger reports
#Arguments = -i aws-instance-name -r aws-region-name  -c cron_or_not -v
usage() {
cat << EOF
usage: $0 options

This script will downalod the postgres rds log files and generate pgbadger reports

OPTIONS:
   -h      Show this message
   -i      DBInstanceIdentifier 
   -r      AWS Region 
   -c      Running as cron job?
   -v      Verbose
EOF
}

AWS_INSTANCE=
AWS_REGION=
IS_CRON=0

while getopts "hi:r:c::v" OPTION; do
  case $OPTION in
  h)
    usage
    exit 1
    ;;
  i)
    AWS_INSTANCE=$OPTARG
    ;;
  r)
    AWS_REGION=$OPTARG
    ;;
  c)
    IS_CRON=$OPTARG
    ;;
  v)
    set -o xtrace
    ;;
  ?)
    usage
    exit
    ;;
  esac
done

if [[ -z $AWS_INSTANCE ]] || [[ -z $AWS_REGION ]] 
then
     usage
     exit 1
fi

# let's put  date in a variable
TODAY=$(/bin/date '+%Y-%m-%d')
YESTERDAY=$(/bin/date -d '1 day ago' '+%Y-%m-%d')

# pgbadger home
PGBADGER_HOME=/var/www/html/pgbadger_reports/
mkdir -p "$PGBADGER_HOME"
mkdir -p "$PGBADGER_HOME/$AWS_INSTANCE" 


download_and_run_fun() {
  # remove file, if exists
  rm -f "$PGBADGER_HOME/$AWS_INSTANCE/postgresql.log.$1"

  # describe and downlowd log files for yesterday
  for filename  in $( aws rds describe-db-log-files --db-instance-identifier "$AWS_INSTANCE" --region "$AWS_REGION" --output text --query 'DescribeDBLogFiles[*].LogFileName')
  do
    echo "$filename"
    if [[ $filename == *$1* ]]; then
      aws rds download-db-log-file-portion --db-instance-identifier "$AWS_INSTANCE" --region "$AWS_REGION" --log-file-name "$filename" >>"$PGBADGER_HOME/$AWS_INSTANCE/postgresql.log.$1"
    fi
  done

  # run pgbadger report
  pgbadger -p '%t:%r:%u@%d:[%p]:' "$PGBADGER_HOME/$AWS_INSTANCE/postgresql.log.$1" -o "$PGBADGER_HOME/$AWS_INSTANCE/postgresql.log.$1.html"

  # remove log file
  rm "$PGBADGER_HOME/$AWS_INSTANCE/postgresql.log.$1" || /bin/true
 
  return 0
} 


# Download log files and run pgbadger report

if [ "$IS_CRON" -eq 0 ]
then
  download_and_run_fun "$TODAY"
else
  download_and_run_fun "$YESTERDAY"
fi

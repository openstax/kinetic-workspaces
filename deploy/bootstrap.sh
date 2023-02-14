#!/usr/bin/env bash

## create s3 bucket for storing terraform state
## bucket must exist before terraform runs and is thus the created using the aws cli
## this file MUST be updated whenever the values in state.tf are modified

usage() { echo "Usage: $0 [-e <sandbox|production>]" 1>&2; exit 0; }

while getopts ":h:e:" o; do
    case "${o}" in
        e)
            env=${OPTARG}
            [ $env == "sandbox" -o $env == "production" ] || usage
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "${env}" ]; then
    usage
fi

BUCKET=kinetic-$env-iac-state

if [[ ! -z $(aws s3api head-bucket --bucket $BUCKET 2>&1) ]]; then
  aws s3api create-bucket --region us-east-1 --acl private --bucket $BUCKET
  aws s3api put-bucket-tagging --bucket $BUCKET --tagging "TagSet=[{Key=Name, Value=ResearchIACState},{Key=Environment, Value=All},{Key=Project, Value=Research}]"
fi

terraform init -backend-config=${env}.conf

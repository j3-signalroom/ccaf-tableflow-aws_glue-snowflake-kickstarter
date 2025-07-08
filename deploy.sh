#!/bin/bash

#
# *** Script Syntax ***
# deploy.sh <create | delete> --profile=<SSO-PROFILE-NAME>
#                             --confluent_api_key=<CONFLUENT-API-KEY>
#                             --confluent_api_secret=<CONFLUENT-API-SECRET>
#                             --snowflake_warehouse=<SNOWFLAKE-WAREHOUSE>
#                             --day_count=<DAY-COUNT>
#
#

# Check required command (create or delete) was supplied
case $1 in
  create)
    create_action=true;;
  delete)
    create_action=false;;
  *)
    echo
    echo "(Error Message 001)  You did not specify one of the commands: create | delete."
    echo
    echo "Usage:  Require all four arguments ---> `basename $0` <create | delete> --profile=<SSO-PROFILE-NAME> --confluent-api-key=<CONFLUENT-API-KEY> --confluent-api-secret=<CONFLUENT-API-SECRET> --snowflake-warehouse=<SNOWFLAKE-WAREHOUSE> --day-count=<DAY-COUNT>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
    ;;
esac

# Get the arguments passed by shift to remove the first word
# then iterate over the rest of the arguments
shift
for arg in "$@" # $@ sees arguments as separate words
do
    case $arg in
        *"--profile="*)
            AWS_PROFILE=$arg;;
        *"--confluent-api-key="*)
            arg_length=20
            confluent_api_key=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--confluent-api-secret="*)
            arg_length=23
            confluent_api_secret=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--snowflake-warehouse="*)
            arg_length=22
            snowflake_warehouse=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--day-count="*)
            arg_length=12
            day_count=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
    esac
done

# Check required --profile argument was supplied
if [ -z $AWS_PROFILE ]
then
    echo
    echo "(Error Message 002)  You did not include the proper use of the --profile=<SSO-PROFILE-NAME> argument in the call."
    echo
    echo "Usage:  Require all four arguments ---> `basename $0 $1` --profile=<SSO-PROFILE-NAME> --confluent-api-key=<CONFLUENT-API-KEY> --confluent-api-secret=<CONFLUENT-API-SECRET> --snowflake-warehouse=<SNOWFLAKE-WAREHOUSE> --day-count=<DAY-COUNT>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --confluent-api-key argument was supplied
if [ -z $confluent_api_key ]
then
    echo
    echo "(Error Message 003)  You did not include the proper use of the --confluent-api-key=<CONFLUENT-API-KEY> argument in the call."
    echo
    echo "Usage:  Require all four arguments ---> `basename $0 $1` --profile=<SSO-PROFILE-NAME> --confluent-api-key=<CONFLUENT-API-KEY> --confluent-api-secret=<CONFLUENT-API-SECRET> --snowflake-warehouse=<SNOWFLAKE-WAREHOUSE> --day-count=<DAY-COUNT>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --confluent-api-secret argument was supplied
if [ -z $confluent_api_secret ]
then
    echo
    echo "(Error Message 004)  You did not include the proper use of the --confluent-api-secret=<CONFLUENT-API-SECRET> argument in the call."
    echo
    echo "Usage:  Require all four arguments ---> `basename $0 $1` --profile=<SSO-PROFILE-NAME> --confluent-api-key=<CONFLUENT-API-KEY> --confluent-api-secret=<CONFLUENT-API-SECRET> --snowflake-warehouse=<SNOWFLAKE-WAREHOUSE> --day-count=<DAY-COUNT>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --snowflake-warehouse argument was supplied
if [ -z $snowflake_warehouse ]
then
    echo
    echo "(Error Message 005)  You did not include the proper use of the --snowflake-warehouse=<SNOWFLAKE-WAREHOUSE> argument in the call."
    echo
    echo "Usage:  Require all four arguments ---> `basename $0 $1` --profile=<SSO-PROFILE-NAME> --confluent-api-key=<CONFLUENT-API-KEY> --confluent-api-secret=<CONFLUENT-API-SECRET> --snowflake-warehouse=<SNOWFLAKE-WAREHOUSE> --day-count=<DAY-COUNT>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --day-count argument was supplied
if [ -z $day_count ] && [ create_action = true ]
then
    echo
    echo "(Error Message 006)  You did not include the proper use of the --day-count=<DAY-COUNT> argument in the call."
    echo
    echo "Usage:  Require all four arguments ---> `basename $0 $1` --profile=<SSO-PROFILE-NAME> --confluent-api-key=<CONFLUENT-API-KEY> --confluent-api-secret=<CONFLUENT-API-SECRET> --snowflake-warehouse=<SNOWFLAKE-WAREHOUSE> --day-count=<DAY-COUNT>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Get the AWS SSO credential variables that are used by the AWS CLI commands to authenicate
aws sso login $AWS_PROFILE
eval $(aws2-wrap $AWS_PROFILE --export)
export AWS_REGION=$(aws configure get region $AWS_PROFILE)

# Create terraform.tfvars file
if [ create_action = true ]
then
    printf "aws_region=\"${AWS_REGION}\"\
    \naws_access_key_id=\"${AWS_ACCESS_KEY_ID}\"\
    \naws_secret_access_key=\"${AWS_SECRET_ACCESS_KEY}\"\
    \naws_session_token=\"${AWS_SESSION_TOKEN}\"\
    \nconfluent_api_key=\"${confluent_api_key}\"\
    \nconfluent_api_secret=\"${confluent_api_secret}\"\
    \nsnowflake_warehouse=\"${snowflake_warehouse}\"\
    \nday_count=${day_count}" > terraform.tfvars
else
    printf "aws_region=\"${AWS_REGION}\"\
    \naws_access_key_id=\"${AWS_ACCESS_KEY_ID}\"\
    \naws_secret_access_key=\"${AWS_SECRET_ACCESS_KEY}\"\
    \naws_session_token=\"${AWS_SESSION_TOKEN}\"\
    \nconfluent_api_key=\"${confluent_api_key}\"\
    \nconfluent_api_secret=\"${confluent_api_secret}\"\
    \nsnowflake_warehouse=\"${snowflake_warehouse}\"" > terraform.tfvars
fi

# Initialize the Terraform configuration
terraform init

if [ "$create_action" = true ]
then
    # Create/Update the Terraform configuration
    terraform plan -var-file=terraform.tfvars
    terraform apply -var-file=terraform.tfvars
else
    # Destroy the Terraform configuration
    terraform destroy -var-file=terraform.tfvars

    # Confluent Base Path
    confluent_base_path=/confluent_cloud_resource/tableflow_kickstarter

    # Snowflake Base Path
    snowflake_base_path=/snowflake_resource/tableflow_kickstarter

    # Force the delete of the AWS Secrets
    aws secretsmanager delete-secret --secret-id ${confluent_base_path}/schema_registry_cluster/python_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_base_path}/kafka_cluster/app_manager/python_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_base_path}/kafka_cluster/app_consumer/python_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_base_path}/kafka_cluster/app_producer/python_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_base_path}/flink --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_base_path}/tableflow --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${snowflake_base_path} --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${snowflake_base_path}/rsa_private_key_pem_1 --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${snowflake_base_path}/rsa_private_key_pem_2 --force-delete-without-recovery || true
fi
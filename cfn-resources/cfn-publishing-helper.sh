#!/usr/bin/env bash

# cfn-publishing-helper.sh
#
#
# This tool helps run the AWS CloudFormation cli & api's needed to
# both test and publish the resources for the CloudFormation Public Registry
# You should only run this tool with appropriate AWS account which is linked to the
# Marketplace
#
# There are some options.
#
# TEST_ONLY=true|false
# PUBLISH_ONLY=true|false
# LOG_LEVEL=logrus valid string loglevel
#
# Example with DEBUG logging enabled by default for set of resources:
# LOG_LEVEL=debug ./cfn-publishing-helper.sh project database-user project-ip-access-list cluster network-peering
#
#trap "exit" INT TERM ERR
#trap "kill 0" EXIT
#set -x
#set -o errexit
#set -o nounset
#set -o pipefail

. ./cfn-publishing-helper.config
env | grep CFN_PUBLISH_
env | grep AWS_DEFAULT_
echo "AWS_DEFAULT_PROFILE=${AWS_DEFAULT_PROFILE}"


_DRY_RUN=${DRY_RUN:-false}
_CFN_FLAGS=${CFN_FLAGS:---verbose}
_TEST_ONLY=${TEST_ONLY:-false}
_PUBLISH_ONLY=${PUBLISH_ONLY:-false}
_DEFAULT_LOG_LEVEL=${LOG_LEVEL:-info}
_CFN_TEST_LOG_BUCKET=${CFN_TEST_LOG_BUCKET:-mongodb-cfn-testing}
major_version=${CFN_PUBLISH_MAJOR_VERSION:-0}
minor_version=${CFN_PUBLISH_MINOR_VERSION:-0}
_AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-$(aws configure get region)}
_CFN_TEST_LOG_BUCKET="${_CFN_TEST_LOG_BUCKET}-${_AWS_DEFAULT_REGION}"

[[ "${_DRY_RUN}" == "true" ]] && echo "*************** DRY_RUN mode enabled **************"

# Default, find all the directory names with the json custom resource schema files.
resources="${1:-project database-user project-ip-access-list network-peering cluster}"
echo "$(basename "$0") running for the following resources: ${resources}"

echo "Step 1/2: cfn test in the cloud...."
<<<<<<< HEAD
if [ $(aws s3 ls "s3://$_CFN_TEST_LOG_BUCKET" | grep 'NoSuchBucket' &> /dev/null) == 0 ] 
then
    echo "aws s3 mb s3://${_CFN_TEST_LOG_BUCKET}"
		aws s3 mb "s3://${_CFN_TEST_LOG_BUCKET}"
=======

if aws s3 ls "s3://$_CFN_TEST_LOG_BUCKET" 2>&1 | grep -q 'An error occurred'
then
    aws s3 mb "s3://${_CFN_TEST_LOG_BUCKET}"
else
    echo "bucket ${_CFN_TEST_LOG_BUCKET} exists"
>>>>>>> 8e5fbba6f4137e6c2f2cb8d131e3a003def3d222
fi
for resource in ${resources};
do
    echo "Working on resource:${resource}"
    [[ "${_DRY_RUN}" == "true" ]] && echo "[dry-run] would have run make on:${resource}" && continue
    if [[ "${_PUBLISH_ONLY}" == "true" ]]; then
        echo "_PUBLISH_ONLY was true, not running 'cfn test' in cloud"
        continue
    fi
    cwd=$(pwd)
    cd "${resource}"
    echo "resource: ${resource}"
    jsonschema="mongodb-atlas-$(echo ${resource}| sed s/-//g).json"
    res_type=$(cat ${jsonschema}| jq -r '.typeName')
    echo "res_type=${res_type}"
    type_info=$(aws cloudformation list-types --output=json | jq --arg typeName "${res_type}" '.TypeSummaries[] | select(.TypeName==$typeName)')
    echo "type_info=${type_info}"
    version=$(echo ${type_info} | jq -r '.DefaultVersionId')
    echo "version=${version}"
    echo "aws uno test-type --type RESOURCE --type-name \"${res_type}\" --log-delivery-bucket \"${CFN_TEST_LOG_BUCKET}\" --version-id \"${version}\")
    test_type_resp=$(aws uno test-type --type RESOURCE --type-name "${res_type}" --log-delivery-bucket "${CFN_TEST_LOG_BUCKET}" --version-id "${version}")
    arn=$(echo ${test_type_resp} | jq -r '.TypeVersionArn')
    echo "Found arn:${arn}"
    # sit and watch the test----
    dt=$(aws uno describe-type --arn ${arn})
    echo "dt=${dt}"
    status=$(echo ${dt} | jq -r '.TypeTestsStatus')
    while [[ "$status" == "IN_PROGRESS" ]]; do
        sleep 3
        dt=$(aws uno describe-type --arn ${arn})
        echo "dt=${dt}"
        status=$(echo ${dt} | jq -r '.TypeTestsStatus')
        echo "status=${status}"
    done
    # Fetch the resource type
    cd -
done
if [[ "${_TEST_ONLY}" == "true" ]]; then
    echo "TEST_ONLY true, skipping testing with the CloudFormation CLI"
    exit 0
fi



echo "Step: Running 'publish-type' on ${resources}"
for resource in ${resources};
do
    cd "${resource}"
    echo "Working on resource:${resource}"
    [[ "${_DRY_RUN}" == "true" ]] && echo "[dry-run] would have run 'publish-type' for:${resource}" && continue
    jsonschema="mongodb-atlas-$(echo ${resource}| sed s/-//g).json"
    echo "jsonschema=${jsonschema}"
    type_name=$(cat ${jsonschema}| jq -r '.typeName')
    echo "type_name=${type_name}"
    type_info=$(aws cloudformation list-types --output=json | jq --arg typeName "${type_name}" '.TypeSummaries[] | select(.TypeName==$typeName)')
    echo "type_info=${type_info}"
    type_arn=$(echo ${type_info} | jq -r '.TypeArn')
    echo "type_arn=${type_arn}"
    version=$(echo ${type_info} | jq -r '.DefaultVersionId')
    echo "version=${version}"
    public_version_number="${major_version}.${minor_version}.$(echo $version | sed 's/^0*//')"
    echo "publish-command"
    #echo "aws uno publish-type --type RESOURCE --arn ${type_arn} --public-version-number ${public_version_number}"
    echo "aws uno publish-type --type RESOURCE --arn ${type_arn}"
    echo "publish-command-exe"
    aws uno publish-type --type RESOURCE --arn ${type_arn}
    #--public-version-number ${public_version_number}
    cd -
done



echo "Clean up afterwards"
for resource in ${resources};
do
    [[ "${_DRY_RUN}" == "true" ]] && echo "[dry-run] would have run clean-up step for:${resource}" && continue
    echo "running clean-up step for ${resource}"
done




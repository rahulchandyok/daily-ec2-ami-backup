#! /bin/bash

##################################################
# Take AMI of the EC2 instances and Delete the Older AMI Images after 7 Days #
# Author: Rahul Chandyok #
##################################################

# Global Variables Initialization
DELETE_DATE=`/bin/date +%Y%m%d --date="7 days ago"`
DATE=`/bin/date +%Y%m%d`
AWS="/bin/aws"
INSTANCE_ID="$1"
NAME="$2"
LOGFILE="/var/log/snapshot"


# If arguments are less, show help
if [ $# -lt 2 ]
then
        echo -e
        echo -e "USAGE: ${PROGNAME} Instance-Id & Ami-description"
        echo -e
        sleep 1
        exit 1
fi


# Subroutine Definition to create AMI
function create_ami ()
{
        AMI_ID=`${AWS} ec2 create-image --instance-id ${INSTANCE_ID} --name "${NAME}-${DATE}" --no-reboot --output=text | cut -f 2`
        # Check if the AMI is created successfully or not
        if [ $? -eq 0 ]
        then
                return 0
        else
        exit 1
        fi
}


# Check tag name
function check_tagname ()
{
TAG_NAME=`${AWS} ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" | jq -r .Tags[0].Key`
if [ $? -eq 0 ]
then
        return 0
else
exit 1
fi
}


# Check value of tag
function check_tagvalue ()
{
TAG_VALUE=`${AWS} ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" | jq -r .Tags[0].Value`
if [ $? -eq 0 ]
then
        return 0
else
exit 1
fi
}

# Create Tag for the instance
function create_tag ()
{
${AWS} ec2 create-tags --resources ${AMI_ID} --tags Key=${TAG_NAME},Value=${TAG_VALUE}
if [ $? -eq 0 ]
then
        return 0
else
exit 1
fi
}


create_ami
check_tagname
check_tagvalue
create_tag

# Create another tag for deletion
${AWS} ec2 create-tags --resources ${AMI_ID} --tags Key=create-by-script,Value=${DATE}


# Delete the Older AMI Image after 7 Days

DELETE_AMI=`${AWS} ec2 describe-images --filters Name=tag-key,Values=create-by-script Name=tag-value,Values=${DELETE_DATE} --query 'Images[*].{ID:ImageId}' --output=text | cut -f 2`


${AWS} ec2 deregister-image --image-id ${DELETE_AMI}

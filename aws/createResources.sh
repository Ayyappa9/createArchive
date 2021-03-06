#!/usr/bin/env bash

# Bucket name must be all lowercase, and start/end with lowecase letter or number
# $(echo...) code to work with versions of bash older than 4.0

echo -n "Enter the name for your resources (must be all lowercase with no spaces) and press [ENTER]: "
read ROOT_NAME

BUCKET_NAME=cognitosample-$(echo "$ROOT_NAME" | tr '[:upper:]' '[:lower:]')
TABLE_NAME=LoginTrail$ROOT_NAME

ROLE_NAME_PREFIX=$ROOT_NAME
POOL_NAME=$ROOT_NAME
IDENTITY_POOL_NAME=$ROOT_NAME
REGION=ap-northeast-1
EB_INSTANCE_TYPE=t2.small
EB_PLATFORM=node.js
CURR_DIR=$( cd $(dirname $0) ; pwd -P )
ROOT_DIR=$( cd $CURR_DIR; cd ..; pwd -P)
NPM_DIR=$ROOT_DIR/node_modules/

DDB_TABLE_ARN=""
IDENTITY_POOL_ID=""
USER_POOL_ID=""
USER_POOL_CLIENT_ID=""


createCognitoResources() {
    # Create a Cognito Identity and Set roles
    aws cognito-identity create-identity-pool --identity-pool-name $IDENTITY_POOL_NAME --allow-unauthenticated-identities --region $REGION| grep IdentityPoolId | awk '{print $2}' | xargs |sed -e 's/^"//'  -e 's/"$//' -e 's/,$//' > /tmp/poolId
    IDENTITY_POOL_ID=$(cat /tmp/poolId)
    echo "Created an identity pool with id of " $IDENTITY_POOL_ID

    # Create an IAM role for unauthenticated users
    cat unauthrole-trust-policy.json | sed 's/IDENTITY_POOL/'$IDENTITY_POOL_ID'/' > /tmp/unauthrole-trust-policy.json
    aws iam create-role --role-name $ROLE_NAME_PREFIX-unauthenticated-role --assume-role-policy-document file:///tmp/unauthrole-trust-policy.json > /tmp/iamUnauthRole
    if [ $? -eq 0 ]
    then
        echo "IAM unauthenticated role successfully created"
    else
        echo "Using the existing role ..."
        aws iam get-role --role-name $ROLE_NAME_PREFIX-unauthenticated-role  > /tmp/iamUnauthRole
        aws iam update-assume-role-policy --role-name $ROLE_NAME_PREFIX-unauthenticated-role --policy-document file:///tmp/unauthrole-trust-policy.json
    fi
    aws iam put-role-policy --role-name $ROLE_NAME_PREFIX-unauthenticated-role --policy-name CognitoPolicy --policy-document file://unauthrole.json

    # Create an IAM role for authenticated users
    cat authrole-trust-policy.json | sed 's/IDENTITY_POOL/'$IDENTITY_POOL_ID'/' > /tmp/authrole-trust-policy.json
    aws iam create-role --role-name $ROLE_NAME_PREFIX-authenticated-role --assume-role-policy-document file:///tmp/authrole-trust-policy.json > /tmp/iamAuthRole
    if [ $? -eq 0 ]
    then
        echo "IAM authenticated role successfully created"
    else
        echo "Using the existing role ..."
        aws iam get-role --role-name $ROLE_NAME_PREFIX-authenticated-role  > /tmp/iamAuthRole
        aws iam update-assume-role-policy --role-name $ROLE_NAME_PREFIX-authenticated-role --policy-document file:///tmp/authrole-trust-policy.json
    fi
    cat authrole.json | sed 's~DDB_TABLE_ARN~'$DDB_TABLE_ARN'~' > /tmp/authrole.json
    aws iam put-role-policy --role-name $ROLE_NAME_PREFIX-authenticated-role --policy-name CognitoPolicy --policy-document file:///tmp/authrole.json

    # Create the user pool
    aws cognito-idp create-user-pool --pool-name $POOL_NAME --auto-verified-attributes email --policies file://user-pool-policy.json --region $REGION > /tmp/$POOL_NAME-create-user-pool
    USER_POOL_ID=$(grep -E '"Id":' /tmp/$POOL_NAME-create-user-pool | awk -F'"' '{print $4}')
    echo "Created user pool with an id of " $USER_POOL_ID

    # Create the user pool client
    aws cognito-idp create-user-pool-client --user-pool-id $USER_POOL_ID --no-generate-secret --client-name webapp --region $REGION > /tmp/$POOL_NAME-create-user-pool-client
    USER_POOL_CLIENT_ID=$(grep -E '"ClientId":' /tmp/$POOL_NAME-create-user-pool-client | awk -F'"' '{print $4}')
    echo "Created user pool client with id of " $USER_POOL_CLIENT_ID

    # Add the user pool and user pool client id to the identity pool
    aws cognito-identity update-identity-pool --allow-unauthenticated-identities --identity-pool-id $IDENTITY_POOL_ID --identity-pool-name $IDENTITY_POOL_NAME \
        --cognito-identity-providers ProviderName=cognito-idp.$REGION.amazonaws.com/$USER_POOL_ID,ClientId=$USER_POOL_CLIENT_ID --region $REGION \
        > /tmp/$IDENTITY_POOL_ID-add-user-pool

    # Update cognito identity with the roles
    UNAUTH_ROLE_ARN=$(perl -nle 'print $& if m{"Arn":\s*"\K([^"]*)}' /tmp/iamUnauthRole | awk -F'"' '{print $1}')
    AUTH_ROLE_ARN=$(perl -nle 'print $& if m{"Arn":\s*"\K([^"]*)}' /tmp/iamAuthRole | awk -F'"' '{print $1}')
    aws cognito-identity set-identity-pool-roles --identity-pool-id $IDENTITY_POOL_ID --roles authenticated=$AUTH_ROLE_ARN,unauthenticated=$UNAUTH_ROLE_ARN --region $REGION
}

createDDBTable() {
    # Create DDB Table
    aws dynamodb create-table \
        --table-name $TABLE_NAME \
        --attribute-definitions \
            AttributeName=userId,AttributeType=S \
            AttributeName=activityDate,AttributeType=S \
        --key-schema AttributeName=userId,KeyType=HASH AttributeName=activityDate,KeyType=RANGE \
        --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
        --region $REGION \
        > /tmp/dynamoTable

    if [ $? -eq 0 ]
    then
        echo "DynamoDB table successfully created"
    else
        echo "Using the existing table ..."
        aws dynamodb describe-table --table-name $TABLE_NAME > /tmp/dynamoTable
    fi

    DDB_TABLE_ARN=$(perl -nle 'print $& if m{"TableArn":\s*"\K([^"]*)}' /tmp/dynamoTable | awk -F'"' '{print $1}')
}

createEBResources() {
    verifyEBCLI

    # Commit changes made
    cd $ROOT_DIR

    # Create Elastic Beanstalk application
    eb init $ROOT_NAME --region $REGION --platform $EB_PLATFORM
    sleep 1

    zip -r upload.zip . -x node_modules/\* *.git* *.idea* *.DS_Store*
cat <<EOT >> $ROOT_DIR/.elasticbeanstalk/config.yml
deploy:
  artifact: upload.zip
EOT

    sleep 1

    # Create Elastic Beanstalk environment
    eb create $ROOT_NAME -d --region $REGION --platform $EB_PLATFORM --instance_type $EB_INSTANCE_TYPE

    cd $CURR_DIR
}

createS3Bucket() {
    # Create the bucket
    aws s3 mb s3://$BUCKET_NAME/ --region $REGION 2>/tmp/s3-mb-status
    status=$?

    if [ $status -eq 0 ]
    then
        echo "S3 bucket successfully created. Uploading files to S3."
        uploadS3Bucket
    else
        if grep "BucketAlreadyOwnedByYou" /tmp/s3-mb-status > /dev/null
        then
            echo "Using the existing S3 bucket ..."
            uploadS3Bucket
        else
            echo -n "The requested S3 bucket name is not available. Please enter a different name and try again : "
            read newName
            BUCKET_NAME=cognitosample-$(echo "$newName" | tr '[:upper:]' '[:lower:]')
            echo "Attempting to create bucket named $BUCKET_NAME"
            createS3Bucket
        fi
    fi
}

uploadS3Bucket() {
    # Add the ‘website’ configuration and bucket policy
    aws s3 website s3://$BUCKET_NAME/ --index-document index.html --error-document index.html  --region $REGION
    cat s3-bucket-policy.json | sed 's/BUCKET_NAME/'$BUCKET_NAME'/' > /tmp/s3-bucket-policy.json
    aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file:///tmp/s3-bucket-policy.json  --region $REGION
    #Build the project and sync it up to the bucket
    if [ ! -d "$NPM_DIR" ]; then
        npm install
    fi
    cd ..
    echo "Building the project"
    ng build
    cd -
    echo "Syncing files to the S3 bucket from " $ROOT_DIR/dist/
    aws s3 sync $ROOT_DIR/dist/ s3://$BUCKET_NAME/  --region $REGION
}

printConfig() {
    echo "Region: " $REGION
    echo "Finished AWS resource creation. Status: SUCCESS"
}

provisionGlobalResources() {
    createDDBTable
    createCognitoResources
    writeConfigFiles
}

verifyEBCLI() {
    if command -v eb >/dev/null; then
        echo "Creating Elastic Beanstalk environment. This can take more than 10 min ..."
    else
        echo "Please install the Elastic Beanstalk Command Line Interface first"
        exit 1;
    fi
}

writeConfigFiles() {
(
cat <<EOF
export const environment = {
    production: false,

    region: '$REGION',

    identityPoolId: '$IDENTITY_POOL_ID',
    userPoolId: '$USER_POOL_ID',
    clientId: '$USER_POOL_CLIENT_ID',

    rekognitionBucket: 'rekognition-pics',
    albumName: "usercontent",
    bucketRegion: '$REGION',

    ddbTableName: '$TABLE_NAME'
};

EOF
) > $ROOT_DIR/src/environments/environment.ts

(
cat <<EOF
export const environment = {
    production: true,

    region: '$REGION',

    identityPoolId: '$IDENTITY_POOL_ID',
    userPoolId: '$USER_POOL_ID',
    clientId: '$USER_POOL_CLIENT_ID',

    rekognitionBucket: 'rekognition-pics',
    albumName: "usercontent",
    bucketRegion: '$REGION',

    ddbTableName: '$TABLE_NAME'
};

EOF
) > $ROOT_DIR/src/environments/environment.prod.ts

}



if [[ $ROOT_NAME =~ [[:upper:]]|[[:space:]] || -z "$ROOT_NAME" ]]; then
    echo "Invalid format"
    exit 1
else
    echo "All AWS resources will be created with [$ROOT_NAME] as part of their name"

    PS3='Where would you like to deploy your application? '
    options=("Elastic Beanstalk" "S3" "Quit")
    select opt in "${options[@]}"
    do
        case $opt in
            "Elastic Beanstalk")
                createEBResources
                printConfig
                break
                ;;
            "S3")
                provisionGlobalResources
                createS3Bucket
                printConfig
                break
                ;;
            "Quit")
                exit 1
                ;;
            *)
                echo "Invalid option"
                exit 1
                ;;
        esac
    done
fi

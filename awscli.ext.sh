#!/bin/bash

__now() {
    date +%s
}

#####
# ENV
#####

aws_env_clear() {
    # Official environment variables
    unset AWS_PROFILE
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN

    # Custom environment variables
    unset AWS_USER_NAME
    unset AWS_ACCOUNT_ALIAS
    # ...
    unset AWS_STS_EXPIRY_ISO8601
    unset AWS_STS_EXPIRY_EPOCH
}

aws_env_export_user_name() {
    local aws_user_name
    aws_user_name=$(aws iam get-user \
        --query 'User.UserName' \
        --output text)

    if [ $? -ne 0 ]; then
        echo 'WARNING: Failed to get AWS user from profile.'
        echo 'Please double check your AWS profile.'
    else
        export AWS_USER_NAME="$aws_user_name"
    fi
}

aws_env_export_account_alias() {
    local aws_account_alias
    aws_account_alias=$(
        aws iam list-account-aliases \
            --query 'AccountAliases[0]' \
            --output text)

    if [ $? -ne 0 ]; then
        echo 'WARNING: No account alias defined.'
        echo 'Please double check your AWS profile, or setup an AWS account alias.'
    else
        export AWS_ACCOUNT_ALIAS="$aws_account_alias"
    fi
}

aws_env_export() {
    export AWS_ACCESS_KEY_ID
    AWS_ACCESS_KEY_ID="$(aws configure get aws_access_key_id)"

    export AWS_SECRET_ACCESS_KEY
    AWS_SECRET_ACCESS_KEY="$(aws configure get aws_secret_access_key)"

    export AWS_DEFAULT_REGION
    AWS_DEFAULT_REGION="$(aws configure get region)"

    export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:=us-east-1}"

    aws_env_export_user_name
    aws_env_export_account_alias
}

aws_env_print_profile() {
    if [[ -z "$AWS_PROFILE" ]]; then
        echo 'AWS_PROFILE: <empty>'
    else
        echo "AWS_PROFILE: $AWS_PROFILE"
    fi
}

aws_env_print_default_region() {
    if [[ -z "$AWS_DEFAULT_REGION" ]]; then
        echo 'AWS_DEFAULT_REGION: <empty>'
    else
        echo "AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION"
    fi
}

aws_env_print_account_alias() {
    if [[ -z "$AWS_ACCOUNT_ALIAS" ]]; then
        echo 'AWS_ACCOUNT_ALIAS: <empty>'
    else
        echo "AWS_ACCOUNT_ALIAS: $AWS_ACCOUNT_ALIAS"
    fi
}

aws_env_print_user_name() {
    if [[ -z "$AWS_USER_NAME" ]]; then
        echo 'AWS_USER_NAME: <empty>'
    else
        echo "AWS_USER_NAME: $AWS_USER_NAME"
    fi
}

aws_env_print() {
    aws_env_print_profile
    aws_env_print_default_region
    aws_env_print_account_alias
    aws_env_print_user_name
}

#########
# PROFILE
#########

aws_profile_add() {
    local aws_profile
    aws_profile="$1"
    aws_profile=${aws_profile:=default}

    # Create/update an AWS profile in ~/.aws/credentials
    aws configure --profile $aws_profile
}

aws_profile_get() {
    if [ -z "$AWS_PROFILE" ]; then
        echo -n 'default'
    else
        echo "$AWS_PROFILE"
    fi
}

aws_profile_set() {
    local aws_profile
    aws_profile="$1"

    if [ -z "$aws_profile" ]; then
        echo 'ERROR: AWS profile is required as an argument!' > /dev/stderr
        return 1
    fi

    aws configure list --profile "$aws_profile" &> /dev/null

    if [ $? -ne 0 ]; then
        echo "ERROR: Unknown AWS profile ${aws_profile}!" > /dev/stderr
        return 1
    fi

    aws_env_clear
    export AWS_PROFILE="$aws_profile"
    aws_env_export
    aws_env_print
}

aws_profile_reset() {
    aws_profile_set "$(aws_profile_get)"
}

aws_profile_prompt() {
    echo -n "profile:$(aws_profile_get)"
    if [ ! -z "$AWS_ACCOUNT_ALIAS" ]; then
        echo -n " account:$AWS_ACCOUNT_ALIAS"
    fi
    if [ ! -z "$AWS_USER_NAME" ]; then
        echo -n " user:$AWS_USER_NAME"
    fi
}

#####
# STS
#####

aws_sts_remaining_seconds() {
    if [ -z "$AWS_STS_EXPIRY_EPOCH" ]; then
        echo 0
    else
        local remaining_seconds
        remaining_seconds=$(( AWS_STS_EXPIRY_EPOCH - $(__now) ))

        if [ $remaining_seconds -le 0 ]; then
            echo 0
        else
            echo $remaining_seconds
        fi
    fi
}

aws_sts_is_expired() {
    [ "$(aws_sts_remaining_seconds)" -eq 0 ]
}

aws_sts_get_session_token() {
    local duration_seconds
    duration_seconds=$1
    duration_seconds=${duration_seconds:=$(( 15 * 60 ))}  # Default of 15 minutes

    if [ ! -z "$AWS_SESSION_TOKEN" ]; then
        echo "WARNING: Session exists, attempting to restore original AWS profile."
        if ! aws_profile_reset; then
            echo 'ERROR: Failed to restore original AWS profile!' > /dev/stderr
            return 1
        fi
    fi

    local mfa_device_serial_number
    mfa_device_serial_number=$(
        aws iam list-mfa-devices \
            --query 'MFADevices[0].SerialNumber' \
            --output text)

    if [ $? -ne 0 ]; then
        echo 'ERROR: MFA devices could not be listed!' > /dev/stderr
        echo 'Either MFA is not configured for the AWS profile.' > /dev/stderr
        echo 'Or, the AWS profile is invalid.' > /dev/stderr
        return 1
    fi

    local token_code
    read -r -p 'OTP Code: ' token_code
    if [ -z "$token_code" ]; then
        echo 'ERROR: Missing token code!' > /dev/stderr
        return 1
    fi

    local session_token_response_text
    session_token_response_text="$(
        aws sts get-session-token \
            --serial-number "$mfa_device_serial_number" \
            --token-code "$token_code" \
            --duration-seconds "$duration_seconds" \
            --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken,Expiration]' \
            --output text)"

    if [ $? -ne 0 ]; then
        echo 'ERROR: Failed to get session token!' > /dev/stderr
        return 1
    fi

    local session_token_response_list
    read -r -a session_token_response_list <<< "$session_token_response_text"

    export AWS_ACCESS_KEY_ID=${session_token_response_list[0]}
    export AWS_SECRET_ACCESS_KEY=${session_token_response_list[1]}
    export AWS_SESSION_TOKEN=${session_token_response_list[2]}

    # Note its possible to parse this with GNU date, but its easier to support portability this way.
    export AWS_STS_EXPIRY_EPOCH=$(( $(__now) + duration_seconds ))  # Machine friendly; estimated value
    export AWS_STS_EXPIRY_ISO8601=${session_token_response_list[3]}  # Human friendly; absolute value

    aws_env_print
}

aws_sts_prompt() {
    if aws_sts_is_expired; then
        # Session expired, so show user a stop sign to represent session has stopped.
        echo -ne '\033[1;31m'  # Colour on
        echo -ne '⬢'
        echo -ne '\033[0m'  # Colour off
        echo -n ' '
    else
        # Session is not expired, so show user a triangle pointing up to represent "elevated" permissions.
        echo -ne '\033[1;33m'  # Colour on
        echo -ne '▲'
        echo -ne '\033[0m'  # Colour off
        echo -n ' '
        echo -n "[$(aws_sts_remaining_seconds)s]"
    fi
}

#####
# PS1
#####

aws_ps1() {
    aws_profile_prompt
    echo -n ' '
    aws_sts_prompt
}

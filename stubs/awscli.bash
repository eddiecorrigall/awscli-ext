#!/bin/bash

_now() {
    date +%s
}

_epoch_to_iso8601() {
    local epoch="$1"
    date -r "$epoch" -u +"%Y-%m-%dT%H:%M:%SZ"
}

function aws {
    local aws_args="$@"
    case "$aws_args" in
        *"configure"*"list"*)
            if [[ "$aws_args" == *"--profile europe"* ]] || [[ "$AWS_PROFILE" == 'europe' ]]; then
                return 0
            else
                return 0
            fi
            ;;
        *"configure"*"get"*"aws_access_key_id"*)
            if [[ "$aws_args" == *"--profile europe"* ]] || [[ "$AWS_PROFILE" == 'europe' ]]; then
                echo 'europe_aws_access_key_id'
                return 0
            else
                echo 'default_aws_access_key_id'
                return 0
            fi
            ;;
        *"configure"*"get"*"aws_secret_access_key"*)
            if [[ "$aws_args" == *"--profile europe"* ]] || [[ "$AWS_PROFILE" == 'europe' ]]; then
                echo 'europe_aws_secret_access_key'
                return 0
            else
                echo 'default_aws_secret_access_key'
                return 0
            fi
            ;;
        *"configure"*"get"*"region"*)
            if [[ "$aws_args" == *"--profile europe"* ]] || [[ "$AWS_PROFILE" == 'europe' ]]; then
                echo 'eu-central-1'
                return 0
            else
                return 0
            fi
            ;;
        *"iam"*"get-user"*)
            if [[ "$aws_args" == *"--output text"* ]]; then
                if [[ "$aws_args" == *"--query User.UserName"* ]]; then
                    echo 'firstname.lastname'
                    return 0
                fi
            fi
            ;;
        *"iam"*"list-account-aliases"*)
            if [[ "$aws_args" == *"--output text"* ]]; then
                if [[ "$aws_args" == *" --query AccountAliases[0]"* ]]; then
                    echo 'account.alias'
                    return 0
                fi
            fi
            ;;
        *"iam"*"list-mfa-devices"*)
            if [[ "$aws_args" == *"--output text"* ]]; then
                if [[ "$aws_args" == *"--query MFADevices[0].SerialNumber"* ]]; then
                    echo 'arn:aws:iam::123456789012:mfa/username'
                    return 0
                fi
            fi
            ;;
        *"sts"*"get-session-token"*)
            local aws_args_duration_seconds
            aws_args_duration_seconds=$(echo "$aws_args" | grep -E -o '\-\-duration\-seconds[[:space:]]+[[:digit:]]+' | awk '{ print $2 }')
            if [[ "$aws_args" == *"--output text"* ]]; then
                if [[ "$aws_args" == *"--query Credentials.[AccessKeyId,SecretAccessKey,SessionToken,Expiration]"* ]]; then
                    echo -n 'AKIAA1CDEFGHIJKLMNOP'
                    echo -n -e '\t'
                    echo -n '8SDsdjnfsjr3uaskj2903Ui147f987sD9fu23KJL'
                    echo -n -e '\t'
                    echo -n 'AWS_SESSION_TOKEN'
                    echo -n -e '\t'
                    echo -n "$(_epoch_to_iso8601 $(( $(_now) + aws_args_duration_seconds )))"
                    return 0
                fi
            fi
            ;;
    esac
    return 1
}

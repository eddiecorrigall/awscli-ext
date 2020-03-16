#!/usr/bin/env bats

# https://github.com/bats-core/bats-core
# Example: `bats awscli.ext.bats`

setup() {
    load "$PWD/awscli.ext.sh"

    mkdir -p "$BATS_TMPDIR/.aws/"

    export AWS_CONFIG_FILE="$BATS_TMPDIR/.aws/config"
    touch $AWS_CONFIG_FILE

    export AWS_SHARED_CREDENTIALS_FILE="$BATS_TMPDIR/.aws/credentials"
    touch $AWS_SHARED_CREDENTIALS_FILE
}

@test "aws_env_clear unsets official environment variables" {
    export AWS_PROFILE=AWS_PROFILE
    export AWS_ACCESS_KEY_ID=AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY=AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN=AWS_SESSION_TOKEN

    aws_env_clear

    [ -z "$AWS_PROFILE" ]
    [ -z "$AWS_ACCESS_KEY_ID" ]
    [ -z "$AWS_SECRET_ACCESS_KEY" ]
    [ -z "$AWS_SESSION_TOKEN" ]
}

@test "aws_env_clear unsets user name env var" {
    export AWS_USER_NAME=AWS_USER_NAME
    aws_env_clear
    [ -z "$AWS_USER_NAME" ]
}

@test "aws_env_clear unsets account alias env var" {
    export AWS_ACCOUNT_ALIAS=AWS_ACCOUNT_ALIAS
    aws_env_clear
    [ -z "$AWS_ACCOUNT_ALIAS" ]
}

@test "aws_env_clear unsets sts env vars" {
    export AWS_STS_EXPIRY_ISO8601=AWS_STS_EXPIRY_ISO8601
    export AWS_STS_EXPIRY_EPOCH=AWS_STS_EXPIRY_EPOCH
    aws_env_clear
    [ -z "$AWS_STS_EXPIRY_ISO8601" ]
    [ -z "$AWS_STS_EXPIRY_EPOCH" ]
}

@test "aws_profile_set exports a default profile" {
    load stubs/awscli

    [ -f "$AWS_CONFIG_FILE" ]
    [ -f "$AWS_SHARED_CREDENTIALS_FILE" ]

    aws_profile_set default

    [ "$AWS_PROFILE" = 'default' ]
    [ "$AWS_ACCESS_KEY_ID" = 'default_aws_access_key_id' ]
    [ "$AWS_SECRET_ACCESS_KEY" = 'default_aws_secret_access_key' ]
    # Given that the region in default profile is not set, expect it to be us-east-1
    [ "$AWS_DEFAULT_REGION" = 'us-east-1' ]
}

@test "aws_profile_set exports a europe profile" {
    load stubs/awscli

    [ -f "$AWS_CONFIG_FILE" ]
    [ -f "$AWS_SHARED_CREDENTIALS_FILE" ]

    aws_profile_set europe

    [ "$AWS_PROFILE" = 'europe' ]
    [ "$AWS_ACCESS_KEY_ID" = 'europe_aws_access_key_id' ]
    [ "$AWS_SECRET_ACCESS_KEY" = 'europe_aws_secret_access_key' ]
    [ "$AWS_DEFAULT_REGION" = 'eu-central-1' ]
}

@test "aws_profile_reset unsets sts session token env vars" {
    load stubs/awscli

    export AWS_PROFILE=europe
    export AWS_SESSION_TOKEN=TEMPORARY_AWS_SESSION_TOKEN

    aws_profile_reset

    [ "$AWS_PROFILE" = 'europe' ]
    [ -z "$AWS_SESSION_TOKEN" ]
}

@test "aws_profile_add new profile" {
    run aws_profile_add NEW_AWS_PROFILE <<EOF
NEW_AWS_ACCESS_KEY_ID
NEW_AWS_SECRET_ACCESS_KEY
NEW_AWS_DEFAULT_REGION
NEW_AWS_DEFAULT_OUTPUT
EOF

    grep 'NEW_AWS_ACCESS_KEY_ID' "$AWS_SHARED_CREDENTIALS_FILE"
    grep 'NEW_AWS_SECRET_ACCESS_KEY' "$AWS_SHARED_CREDENTIALS_FILE"

    grep 'NEW_AWS_DEFAULT_REGION' "$AWS_CONFIG_FILE"
    grep 'NEW_AWS_DEFAULT_OUTPUT' "$AWS_CONFIG_FILE"
}

@test "aws_sts_get_session_token returns zero when AWS_PROFILE is unset and token code is entered" {
    load stubs/awscli
    unset AWS_PROFILE
    run aws_sts_get_session_token <<< '123456' # With OTP Code
    [ "$status" -eq 0 ]
}

@test "aws_sts_get_session_token returns non-zero when token code is not entered" {
    load stubs/awscli
    export AWS_PROFILE=AWS_PROFILE
    run aws_sts_get_session_token <<< '' # Without OTP Code
    [ "$status" -ne 0 ]
}

@test "aws_sts_get_session_token returns zero when env var AWS_PROFILE is set and token code is entered" {
    load stubs/awscli
    export AWS_PROFILE=canada
    export AWS_DEFAULT_REGION=ca-central-1
    export AWS_ACCOUNT_ALIAS=homehardware-prod
    export AWS_USER_NAME=walter.hachborn
    run aws_sts_get_session_token <<< '123456' # With OTP Code
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "AWS_PROFILE: $AWS_PROFILE" ]
    [ "${lines[1]}" = "AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION" ]
    [ "${lines[2]}" = "AWS_ACCOUNT_ALIAS: $AWS_ACCOUNT_ALIAS" ]
    [ "${lines[3]}" = "AWS_USER_NAME: $AWS_USER_NAME" ]
}

@test "aws_sts_get_session_token returns zero and expires in future" {
    load stubs/awscli
    export AWS_PROFILE=AWS_PROFILE
    aws_sts_get_session_token <<< '123456' # With OTP Code
    [ -n "$AWS_STS_EXPIRY_ISO8601" ]
    if command -v gdate; then
        # If the user has gdate (GNU date) then a more accurate test can be performed
        [ $(gdate -d "$AWS_STS_EXPIRY_ISO8601" +%s) -eq $AWS_STS_EXPIRY_EPOCH ]
    else
        [ "$AWS_STS_EXPIRY_EPOCH" -gt $(date +%s) ]
    fi
}

@test "aws_sts_get_session_token return 0 and updates aws environment variables" {
    load stubs/awscli
    export AWS_PROFILE=AWS_PROFILE
    aws_sts_get_session_token <<< '123456' # With OTP Code
    [ "$AWS_ACCESS_KEY_ID" = 'AKIAA1CDEFGHIJKLMNOP' ]
    [ "$AWS_SECRET_ACCESS_KEY" = '8SDsdjnfsjr3uaskj2903Ui147f987sD9fu23KJL' ]
    [ "$AWS_SESSION_TOKEN" = 'AWS_SESSION_TOKEN' ]
}

@test "aws_sts_get_session_token invokes aws_profile_export when AWS_SESSION_TOKEN is set" {
    load stubs/awscli
    export AWS_PROFILE=europe
    export AWS_SESSION_TOKEN=AWS_SESSION_TOKEN
    aws_sts_get_session_token <<< '123456' # With OTP Code
}

@test "aws_sts_get_session_token can set token expiration" {
    load stubs/awscli
    export AWS_PROFILE=AWS_PROFILE
    export duration_seconds=1800  # 30 minutes
    aws_sts_get_session_token "$duration_seconds" <<< '123456' # With OTP Code
    [ "$AWS_STS_EXPIRY_EPOCH" -gt $(( $(date +%s) + duration_seconds - 3)) ]  # Minus a second since its an estimate
}

@test "aws_sts_remaining_seconds returns zero when AWS_STS_EXPIRY_EPOCH is unset" {
    unset AWS_STS_EXPIRY_EPOCH
    [ $(aws_sts_remaining_seconds) -eq 0 ]
}

@test "aws_sts_remaining_seconds returns zero when expired" {
    export AWS_STS_EXPIRY_EPOCH=$(( $(date +%s) - 1 ))
    [ -n "$AWS_STS_EXPIRY_EPOCH" ] && [ "$AWS_STS_EXPIRY_EPOCH" -gt 0 ]
    [ $(aws_sts_remaining_seconds) -eq 0 ]
}

@test "aws_sts_remaining_seconds returns remaining time in seconds when not expired" {
    local remaining_seconds=123
    export AWS_STS_EXPIRY_EPOCH=$(( $(date +%s) + $remaining_seconds ))
    [ -n "$AWS_STS_EXPIRY_EPOCH" ] && [ "$AWS_STS_EXPIRY_EPOCH" -gt 0 ]
    [ $(aws_sts_remaining_seconds) -eq "$remaining_seconds" ]
}

@test "aws_sts_is_expired returns zero when expired" {
    export AWS_STS_EXPIRY_EPOCH=$(( $(date +%s) - 1 ))
    [ -n "$AWS_STS_EXPIRY_EPOCH" ] && [ "$AWS_STS_EXPIRY_EPOCH" -gt 0 ]
    run aws_sts_is_expired
    [ "$status" -eq 0 ]
    [ -z "${lines[0]}" ]
}

@test "aws_sts_is_expired returns non-zero when not expired" {
    local remaining_seconds=123
    export AWS_STS_EXPIRY_EPOCH=$(( $(date +%s) + $remaining_seconds ))
    [ -n "$AWS_STS_EXPIRY_EPOCH" ] && [ "$AWS_STS_EXPIRY_EPOCH" -gt 0 ]
    run aws_sts_is_expired
    [ "$status" -ne 0 ]
    [ -z "${lines[0]}" ]
}

@test "aws_profile_prompt prints default when AWS_PROFILE is unset" {
    unset AWS_PROFILE

    run aws_profile_prompt
    [ "$status" -eq 0 ]
    [ "${lines[0]}" == 'profile:default' ]
}

@test "aws_profile_prompt prints account alias and user name when AWS_PROFILE is set" {
    export AWS_PROFILE=TEST_AWS_PROFILE
    export AWS_ACCOUNT_ALIAS=TEST_ACCOUNT_ALIAS
    export AWS_USER_NAME=TEST_USER_NAME

    run aws_profile_prompt
    [ "$status" -eq 0 ]
    [ "${lines[0]}" == "profile:$AWS_PROFILE account:$AWS_ACCOUNT_ALIAS user:$AWS_USER_NAME" ]
}

@test "aws_profile_prompt prints only AWS_PROFILE when AWS_ACCOUNT_ALIAS and AWS_USER_NAME are unset" {
    export AWS_PROFILE=TEST_AWS_PROFILE
    unset AWS_ACCOUNT_ALIAS
    unset AWS_USER_NAME

    run aws_profile_prompt
    [ "$status" -eq 0 ]
    [ "${lines[0]}" == "profile:$AWS_PROFILE" ]
}

@test "aws_sts_prompt prints a stop-sign when expired" {
    unset AWS_STS_EXPIRY_EPOCH
    run aws_sts_prompt
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == *"⬢"* ]]
}

@test "aws_sts_prompt prints an up-sign (elevator up) when not expired" {
    local remaining_seconds=123
    export AWS_STS_EXPIRY_EPOCH=$(( $(date +%s) + $remaining_seconds ))
    run aws_sts_prompt
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == *"▲"* ]]
    [[ "${lines[0]}" == *"$remaining_seconds"* ]]
}

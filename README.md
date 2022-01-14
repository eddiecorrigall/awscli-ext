# awscli-ext
Command-line extensions to awscli.

The purpose of these tools is to add functionality and usability where the awscli is lacking. Specifically a command-line user experience which helps the user know the context of the AWS profile. Without easily spotting which AWS profile and account you are using, it is easy to make assumptions and mistakes. Imagine thinking you are working with staging credentials, and accidentally applying changes to production.

Along with a pretty command-line prompt, these commands allow you to: administrate AWS User Groups with custom access policy.

## Installation

Ensure that the awscli is installed.

```bash
pip3 install --upgrade --user awscli
```

Add the following to `~/.bash_profile` if you are using OSX, otherwise add contents to `~/.bashrc`.

```bash
#!/bin/bash

if [[ -f /path/to/awscli.ext.sh ]]; then
    source /path/to/awscli.ext.sh
fi
```

### Install Prompt

Add the following command to `~/.bashrc` (or `~/.bash_profile` on OSX).

```bash
export PROMPT_COMMAND='echo $(aws_ps1)'
```

Open a new terminal window, the prompt should now look something like this,

```
profile:default ⬢
thehostname:~ theuser$
```

The red stop-sign (<span style="color:#FF0000">⬢</span>) means that the `AWS_SESSION_TOKEN` is empty, or has expired.

A green up-arrow (<span style="color:#32CD32;">▲</span>) means that the `AWS_SESSION_TOKEN` is set, and it has not expired. The prompt will include the remaining seconds that the token has left.

```bash
profile:default ▲ [403s]
thehost:~ theuser$
```

Alternatively, if your bash profile already has a `PROMPT_COMMAND` defined, you can incorporate helper commands or environment variables to design your own.

## Bash Functions

### AWS Environment Variable
- `aws_env_clear` (interactive)
- `aws_env_export_user_name` (interactive)
- `aws_env_export_account_alias` (interactive)
- `aws_env_export` (interactive)
- `aws_env_print_profile` (stdout text)
- `aws_env_print_default_region` (stdout text)
- `aws_env_print_account_alias` (stdout text)
- `aws_env_print_user_name` (stdout text)
- `aws_env_print` (stdout text)

### AWS Profile
- `aws_profile_add` (interactive)
- `aws_profile_get` (interactive)
- `aws_profile_set` (interactive)
- `aws_profile_reset` (interactive)
- `aws_profile_prompt` (stdout text)

### AWS Simple Token Service (STS)
- `aws_sts_remaining_seconds` (stdout number)
- `aws_sts_is_expired` (stdout boolean)
- `aws_sts_get_session_token` (interactive)
- `aws_sts_prompt` (stdout text)

### BASH PS1
- `aws_ps1` (stdout text)

## Environment Variables

Official AWS environment variables
- `AWS_PROFILE`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

Unofficial AWS environment variables:
- `AWS_USER_NAME`
- `AWS_ACCOUNT_ALIAS`
- `AWS_STS_EXPIRY_ISO8601`
- `AWS_STS_EXPIRY_EPOCH`

## Run tests

```bash
# https://github.com/bats-core/bats-core
bats awscli.ext.bats
```

## Use Case

### User Group Policy with Multi-factor Condition

Easily get STS tokens and setup the local environment variables to meet a MFA condition set in a policy and gain temporary credentials for write access to an AWS account.

Read more about conditional access policies [here](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_configure-api-require.html).

### Instructions

1. Use the AWS CloudFormation [employee access stack](cloudformation/employee-access-stack.yaml) to create user groups: billing, engineering, and readonly.
2. Navigate to the AWS IAM dashboard, and move users into the appropriate groups.
3. Have users [enabled MFA](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_enable_virtual.html) so they can perform self service.

#### Group: Billing

Users in this group can view billing portal.

#### Group: ReadOnly

Users in this group use the AWS Managaged Policy: IAMReadOnlyAccess.

#### Group: Engineering

Users in this group have IAMReadOnlyAccess, until MFA code is completed with AWS STS.

For example, when the user logs into the AWS Console and completes the MFA process, they will assume a custom policy: `AllowEngineeringAccess`. It is up to the user of this configuration to choose what this policy does. The example allows all AWS actions on all AWS resources.

For example, when the user requests an STS token and completes the process with an MFA code, they will assume the custom policy `AllowEngineeringAccess` as well.

By default a user in the Engineering Group that has generated an AWS Profile for CLI programmatic use, the AWS Profile assumes `IAMReadOnlyAccess`. The condition to use `AllowEngineeringAccess` is based on whether the user completes an STS token request with a valid MFA code for temporary access credentials.

### Demo

This example demonstrates that the holder of the AWS Secret Access Key must provide an MFA Code to gain write access to an AWS account. Otherwise the credentials will have read only access only.

1. Create a programmatic user called `developer` with the AWS IAM console,
1. Keep a copy of the AWS Access Key ID and AWS Secret Access Key for later steps.
1. Assign a MFA device. MFA Code is required for demo.
1. Add the new `developer` user into the `DeveloperAccess` IAM group.
1. Then open a terminal and enter the following commands.

```bash
aws_profile_add developer
# Prompted for:
#  AWS Access Key ID (secret)
#  AWS Secret Access Key (secret)
#  Default region name (eg. ca-central-1)
#  Default output format (eg. json)

# Set the AWS profile to developer
aws_profile_set developer

# List all s3 buckets visible to the user
aws s3 ls

# Attempt to create a bucket (should fail with AccessDenied)
aws s3 mb s3://some-unique-bucket-name

aws_sts_get_session_token
# Prompted for: One-time Password (MFA Code)

# Attempt to create a bucket again (should succeed)
aws s3 mb s3://some-unique-bucket-name

# Cleanup: remove bucket
aws s3 rb s3://some-unique-bucket-name

# Restore original profile, including the temporary access token
aws_profile_reset

# Attempt to create a bucket again (should fail with AccessDenied)
aws s3 mb s3://some-unique-bucket-name
```

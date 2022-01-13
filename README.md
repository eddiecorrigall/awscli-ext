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

- The red stop-sign (<span style="color:#FF0000">⬢</span>) means that the `AWS_SESSION_TOKEN` is empty, or has expired.

- A green up-arrow (<span style="color:#32CD32;">▲</span>) means that the `AWS_SESSION_TOKEN` is set, and it has not expired. The prompt will include the remaining seconds that the token has left.

```bash
profile:default ▲ [403s]
thehost:~ theuser$
```

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

1. Use the [user group cloudformation stack](cloudformation/user-group-stack.json) to create user groups: billing, engineering, and readonly.
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

# awscli-ext
Command-line extensions to awscli.

The purpose of these tools is to add functionality and usability where the awscli is lacking. Specifically a command-line user experience which helps the user know the context of the AWS profile. Without easily spotting which AWS profile and account you are using, it is easy to make assumptions and mistakes. Imagine thinking you are working with staging credentials, and accidentally applying changes to production.

Along with a pretty command-line prompt, these commands allow you to:

1. Use case: read-only IAM policy which can be elevated to super user.
Easily get STS tokens and setup the local environment variables to meet a MFA condition set in a policy and gain temporary credentials for write access to an AWS account.

## Run tests

```bash
# https://github.com/bats-core/bats-core
bats awscli.ext.bats
```

## Installation

Ensure that the awscli is installed.

```bash
pip3 install --upgrade --user awscli
```

If you are using OSX, please ensure that `~/.bash_profile` sources `~/.bashrc`.

```bash
#!/bin/bash

if [[ -f ~/.bashrc ]]; then
    source ~/.bashrc
fi
```

Add the following commands to `~/.bashrc`.

```bash
if [[ -f /path/to/awscli.ext.sh ]]; then
    source /path/to/awscli.ext.sh
fi
```

### Install Prompt

Add the following command to `~/.bashrc`.

```bash
export PROMPT_COMMAND='echo $(aws_ps1)'
```

Open a new terminal window, the prompt should now look something like this,

```bash
profile:default ⬢
thehostname:~ theuser$
```

The red stop-sign means that the AWS_SESSION_TOKEN is empty, or has expired.
A green up-arrow means that the AWS_SESSION_TOKEN is set, and it has not expired. The prompt will include the remaining seconds that the token has left.

```bash
profile:default ▲ [403s]
thehost:~ theuser$
```

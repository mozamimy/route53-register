# route53-register

This is a CloudFormation stack includes a Lambda function and a CloudWatch event to create/delete A record when launching/terminating EC2 instance.

## Required tools

You need to install following tools before develop and deploy this CloudFormation stack.

- [aws-sam-cli](https://github.com/awslabs/aws-sam-cli)
    - Run function locally, validate CloudFormation configuration and deploy.
- [jq](https://stedolan.github.io/jq/)
- [Jsonnet](https://jsonnet.org/)
    - CloudFormation configuration is written in Jsonnet for templating and make it simple.

## Required environment variables

### Common

- `DLQ_NAME`: A name of DLQ to send a message when an invocation of function is failed.
- `DNS_SUFFIX`: A suffix of DNS record.
    - If this value is `.apne1.aws.example.com` and launched instance name is `foo-001`, an A record `foo-001.apne1.aws.example.com` will be registered.
- `HOSTED_ZONE_ID`: A Hosted zone ID manipulated by this function.
- `LAMBDA_ROLE`: A role ARN to attach this function.
    - You should allow following IAM actions to the role.
        - `route53:ChangeResourceRecordSets`
        - `ec2:DescribeInstances`
        - `sqs:SendMessage`
            - Need to send a message to a dead letter queue.

### Only development

- `TEST_INSTANCE_ID`: An instance ID for testing. This ID is used to emulate CloudWatch Events and an A record is determined by the instance Name tag. Therefore, you need to specify actual EC2 instance ID.

### Only packaging and deploy

- `SAM_ARTIFACT_BUCKET`: A S3 bucket to put an artifact.
- `STACK_NAME`: A CloudFormation stack name you want to create.

## Development

This project uses a Docker image provided by [LambCI](http://lambci.org/) because make an environment building binary same as running environment. 

Therefore, you should create a Docker image before develop and deploy.

```sh
make init
```

After changing code, you can build a debug binary and run the Lambda function locally with following make tasks.

```sh
make build
make run-create-record # Emulate launching an EC2 instance
make run-delete-record # Emulate terminating and EC2 instance
```

## Package and deploy

You can build a release binary and package it with CloudFormation template. That is a simple wrapper to generate CloudFormation configuration from Jsonnet template and execute `sam validate`, `sam package` and `sam deploy` commands.

```sh
make release-build
make package
make plan # This task shows a changeset. It can fail when the CloudFormation stack is not created yet.
make deploy
```

Generated CloudFormation configuration will create a Lambda function and a CloudWatch event invoking the function.

## License

MIT

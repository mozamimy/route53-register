{
  AWSTemplateFormatVersion: '2010-09-09',
  Transform: 'AWS::Serverless-2016-10-31',
  Description: 'https://github.com/mozamimy/route53-register',

  Resources: {
    MainFunction: {
      Type: 'AWS::Serverless::Function',
      Properties: {
        CodeUri: std.extVar('codeUri'),
        Handler: 'bootstrap',
        MemorySize: 128,
        Role: std.extVar('lambdaRole'),
        Runtime: 'provided',
        Timeout: 3,
        AutoPublishAlias: 'active',
        Layers: [
          // https://aws.amazon.com/jp/blogs/compute/upcoming-updates-to-the-aws-lambda-execution-environment/
          'arn:aws:lambda:::awslayer:AmazonLinux1803',
        ],
        Environment: {
          Variables: {
            DNS_SUFFIX: std.extVar('dnsSuffix'),
            HOSTED_ZONE_ID: std.extVar('hostedZoneId'),
            RUST_LOG: 'info',
            RUST_BACKTRACE: '1',
          },
        },
        Events: {
          ChangeInstanceStatusEvent: {
            Type: 'CloudWatchEvent',
            Properties: {
              Pattern: {
                source: [
                  'aws.ec2',
                ],
                'detail-type': [
                  'EC2 Instance State-change Notification',
                ],
                detail: {
                  state: [
                    'running',
                    'shutting-down',
                  ],
                },
              },
            },
          },
        },
        DeadLetterQueue: {
          Type: 'SQS',
          TargetArn: { 'Fn::GetAtt': ['DLQ', 'Arn'] },
        },
      },
    },
    DLQ: {
      Type: 'AWS::SQS::Queue',
      Properties: {
        QueueName: std.extVar('dlqName'),
        MessageRetentionPeriod: 60 * 60 * 24 * 14,
      },
    },
  },
}

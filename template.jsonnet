{
  AWSTemplateFormatVersion: '2010-09-09',
  Transform: 'Aws::Serverless-2016-10-31',
  Description: 'https://github.com/mozamimy/route53-register',

  Resources: {
    MainFunction: {
      Type: 'AWS::Serverless::Function',
      Properties: {
        CodeUri: std.extVar('codeUri'),
        Handler: 'bootstrap',
        MemorySize: 128,
        Runtime: 'provided',
        Timeout: 3,
        AutoPublishAlias: 'active',
        Environment: {
          Variables: {
            RUST_LOG: 'info',
            RUST_BACKTRACE: '1',
          },
        },
      },
    },
  },
}

{
  version: '0',
  id: '7bf73129-1428-4cd3-a780-95db273d1602',
  'detail-type': 'EC2 Instance State-change Notification',
  source: 'aws.ec2',
  account: '123456789012',
  time: '2015-11-11T21:29:54Z',
  region: 'ap-northeast-1',
  resources: [
    std.format('arn:aws:ec2:ap-northeast-1:123456789012:instance/%s', std.extVar('instanceId')),
  ],
  detail: {
    'instance-id': std.extVar('instanceId'),
    state: std.extVar('state'),
  },
}

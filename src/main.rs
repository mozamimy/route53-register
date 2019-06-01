use aws_lambda_events::event::cloudwatch_events::CloudWatchEvent;
use lambda_runtime::lambda;
use rusoto_ec2::Ec2;
use rusoto_route53::Route53;
use serde_derive::{Deserialize, Serialize};

#[derive(Deserialize, Serialize)]
struct Ec2Event {
    #[serde(rename = "instance-id")]
    instance_id: String,
    state: String,
}

fn main() -> Result<(), failure::Error> {
    env_logger::try_init()?;
    lambda!(handler);

    Ok(())
}

fn handler(
    event: CloudWatchEvent<Ec2Event>,
    _: lambda_runtime::Context,
) -> Result<(), lambda_runtime::error::HandlerError> {
    let ec2 = rusoto_ec2::Ec2Client::new(rusoto_core::Region::default());
    let route53 = rusoto_route53::Route53Client::new(rusoto_core::Region::UsEast1);
    let dns_suffix = std::env::var("DNS_SUFFIX")?;
    let hosted_zone_id = std::env::var("HOSTED_ZONE_ID")?;

    match event.detail.state.as_str() {
        "running" => create_a_record(&event, &ec2, &route53, dns_suffix, hosted_zone_id)?,
        "shutting-down" => delete_a_record(&event, &ec2, &route53, dns_suffix, hosted_zone_id)?,
        _ => log::info!(
            "Skipped event: {} ({})",
            event.detail.instance_id,
            event.detail.state
        ),
    }
    Ok(())
}

fn create_a_record(
    event: &CloudWatchEvent<Ec2Event>,
    ec2: &rusoto_ec2::Ec2Client,
    route53: &rusoto_route53::Route53Client,
    dns_suffix: String,
    hosted_zone_id: String,
) -> Result<(), failure::Error> {
    let (fqdn, private_ip_address) =
        get_fqdn_and_ip_addr(event.detail.instance_id.as_str(), dns_suffix.as_str(), ec2)?;
    let route53_req = make_route53_request(hosted_zone_id, "UPSERT", fqdn, private_ip_address);

    match route53.change_resource_record_sets(route53_req).sync() {
        Ok(response) => {
            log::info!("{:?}", response);
            Ok(())
        }
        Err(e) => Err(failure::format_err!("{:?}", e)),
    }
}

fn delete_a_record(
    event: &CloudWatchEvent<Ec2Event>,
    ec2: &rusoto_ec2::Ec2Client,
    route53: &rusoto_route53::Route53Client,
    dns_suffix: String,
    hosted_zone_id: String,
) -> Result<(), failure::Error> {
    let (fqdn, private_ip_address) =
        get_fqdn_and_ip_addr(event.detail.instance_id.as_str(), dns_suffix.as_str(), ec2)?;
    let route53_req = make_route53_request(hosted_zone_id, "DELETE", fqdn, private_ip_address);

    match route53.change_resource_record_sets(route53_req).sync() {
        Ok(response) => {
            log::info!("{:?}", response);
            Ok(())
        }
        Err(e) => Err(failure::format_err!("{:?}", e)),
    }
}

fn get_fqdn_and_ip_addr(
    instance_id: &str,
    dns_suffix: &str,
    ec2: &rusoto_ec2::Ec2Client,
) -> Result<(String, String), failure::Error> {
    let ec2_req = rusoto_ec2::DescribeInstancesRequest {
        instance_ids: Some(vec![instance_id.to_string()]),
        ..Default::default()
    };

    let reservations = ec2.describe_instances(ec2_req).sync()?.reservations;
    let instance = match &reservations {
        Some(reservations) => match reservations.get(0) {
            Some(reservation) => match &reservation.instances {
                Some(instances) => match instances.get(0) {
                    Some(instance) => instance.clone(),
                    None => {
                        return Err(failure::format_err!(
                            "There is no instance for {:?}",
                            reservation
                        ))
                    }
                },
                None => {
                    return Err(failure::format_err!(
                        "There is no instances for {:?}",
                        reservation
                    ))
                }
            },
            None => return Err(failure::format_err!("Empty reservation.")),
        },
        None => {
            return Err(failure::format_err!(
                "There is no reservation for {}",
                instance_id,
            ))
        }
    };

    let tags = instance
        .tags
        .ok_or(failure::format_err!("There is no tags for {}", instance_id,))?;
    let mut instance_name = None;
    for tag in tags.iter() {
        if tag.key == Some("Name".to_string()) {
            instance_name = Some(tag.value.clone().unwrap());
        }
    }
    if instance_name.is_none() {
        return Err(failure::format_err!(
            "Instance {} has no Name tag.",
            instance_id
        ));
    }
    let fqdn = instance_name.unwrap() + dns_suffix;
    match instance.private_ip_address {
        Some(private_ip_address) => Ok((fqdn, private_ip_address)),
        None => {
            return Err(failure::format_err!(
                "No private IP address for {}",
                instance_id
            ))
        }
    }
}

fn make_route53_request(
    hosted_zone_id: String,
    action: &str,
    fqdn: String,
    private_ip_address: String,
) -> rusoto_route53::ChangeResourceRecordSetsRequest {
    rusoto_route53::ChangeResourceRecordSetsRequest {
        hosted_zone_id: hosted_zone_id.to_string(),
        change_batch: rusoto_route53::ChangeBatch {
            changes: vec![rusoto_route53::Change {
                action: action.to_string(),
                resource_record_set: rusoto_route53::ResourceRecordSet {
                    name: fqdn.to_string(),
                    type_: "A".to_string(),
                    ttl: Some(60),
                    resource_records: Some(vec![rusoto_route53::ResourceRecord {
                        value: private_ip_address.to_string(),
                    }]),
                    ..Default::default()
                },
            }],
            ..Default::default()
        },
    }
}

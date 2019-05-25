use lambda_runtime::lambda;
use serde_derive::Deserialize;

#[derive(Deserialize)]
struct CustomEvent {
    hello: String,
}

fn main() -> Result<(), failure::Error> {
    env_logger::try_init()?;
    lambda!(handler);

    Ok(())
}

fn handler(
    _: CustomEvent,
    _: lambda_runtime::Context,
) -> Result<(), lambda_runtime::error::HandlerError> {
    log::info!("hello");
    Ok(())
}

use base::{read_secret_from_kafka, send_secret_to_kafka};
use std::time::Duration;
use uuid::Uuid;

#[tokio::main]
async fn main() {
    let brokers = std::env::var("NIX_TESTS_KAFKA").unwrap();
    println!("Reaching kafka at {brokers}!");

    // Write and read a secret through kafka
    let topic = Uuid::new_v4().to_string();
    let secret = "I went through kafka";

    tokio::time::sleep(Duration::from_secs(10)).await;
    println!("Sending secret");
    let producer = send_secret_to_kafka(&brokers, &topic, secret).await;

    tokio::time::sleep(Duration::from_secs(10)).await;
    println!("Reading secret");
    let recovered_secret = read_secret_from_kafka(&brokers, &topic).await;
    println!("Read secret: {recovered_secret}");

    assert_eq!(secret, recovered_secret);
    producer.abort();
}

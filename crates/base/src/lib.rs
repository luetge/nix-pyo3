use rdkafka::config::ClientConfig;
use rdkafka::consumer::{Consumer, StreamConsumer};
use rdkafka::producer::{FutureProducer, FutureRecord};
use rdkafka::util::Timeout;
use rdkafka::Message;
use tokio::task::JoinHandle;
use uuid::Uuid;

pub fn hello() {
    let uuid = Uuid::new_v4();
    println!("Helloo! {:?}", uuid);
}

pub async fn send_secret_to_kafka(brokers: &str, topic_name: &str, msg: &str) -> JoinHandle<()> {
    let producer: FutureProducer = ClientConfig::new()
        .set("bootstrap.servers", brokers)
        .set("message.timeout.ms", "5000")
        .create()
        .expect("producer creation error");

    let topic_name = topic_name.to_owned();
    let msg = msg.to_owned();
    tokio::spawn(async move {
        for _ in 0..120 {
            if let Err(e) = producer
                .send(
                    FutureRecord::to(&topic_name.clone())
                        .payload(&msg)
                        .key("Secret"),
                    Timeout::Never,
                )
                .await
            {
                println!("could not send message: {:?}", e);
            }
            tokio::time::sleep(std::time::Duration::from_secs(1)).await;
        }
    })
}

pub async fn read_secret_from_kafka(brokers: &str, topic_name: &str) -> String {
    let consumer: StreamConsumer = ClientConfig::new()
        .set("group.id", Uuid::new_v4().to_string())
        .set("bootstrap.servers", brokers)
        .set("enable.partition.eof", "false")
        .set("session.timeout.ms", "6000")
        .set("enable.auto.commit", "true")
        .create()
        .expect("Consumer creation failed");

    consumer
        .subscribe(&[topic_name])
        .expect("Can't subscribe to specified topics");

    for _ in 0..100 {
        match consumer.recv().await {
            Err(e) => {
                println!("Kafka error: {}", e);
            }
            Ok(m) => {
                return match m.payload_view::<str>() {
                    None => "",
                    Some(Ok(s)) => s,
                    Some(Err(e)) => {
                        println!("Error while deserializing message payload: {:?}", e);
                        panic!("error deserializing")
                    }
                }
                .to_owned()
            }
        }
    }

    panic!("could not read message")
}

#[cfg(test)]
mod tests {
    #[test]
    fn always_succeed() {
        assert!(true);
    }
}

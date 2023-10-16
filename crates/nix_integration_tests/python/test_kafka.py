import os


def test_kafka_msgs():
    import heavy_computer

    msg = "hello!"
    kafka_brokers = os.environ["NIX_TESTS_KAFKA"]
    print(f"Reaching kafka at {kafka_brokers}")
    recovered_msg = heavy_computer.test_kafka(kafka_brokers, msg)
    assert msg == recovered_msg

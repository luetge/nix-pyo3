use base::{hello, read_secret_from_kafka, send_secret_to_kafka};
use pyo3::prelude::*;
use uuid::Uuid;

#[pyfunction]
fn hi() {
    hello();
}

#[pyfunction]
fn test_kafka(brokers: String, msg: String) -> PyResult<String> {
    let topic = Uuid::new_v4().to_string();

    tokio::runtime::Builder::new_current_thread()
        .enable_time()
        .build()
        .unwrap()
        .block_on(async move {
            let producer = send_secret_to_kafka(&brokers, &topic, &msg).await;
            let recovered_secret = read_secret_from_kafka(&brokers, &topic).await;
            producer.abort();

            Ok(recovered_secret)
        })
}

#[pyo3::pymodule]
fn heavy_computer(_py: pyo3::Python<'_>, m: &pyo3::types::PyModule) -> pyo3::PyResult<()> {
    m.add_function(wrap_pyfunction!(hi, m)?)?;
    m.add_function(wrap_pyfunction!(test_kafka, m)?)?;

    Ok(())
}

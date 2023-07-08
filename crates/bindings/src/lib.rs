use base::hello;
use pyo3::prelude::*;

#[pyfunction]
fn hi() {
    hello();
}

#[pyo3::pymodule]
fn heavy_computer(_py: pyo3::Python<'_>, m: &pyo3::types::PyModule) -> pyo3::PyResult<()> {
    m.add_function(wrap_pyfunction!(hi, m)?)?;

    Ok(())
}

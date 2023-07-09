use uuid::Uuid;

pub fn hello() {
    let uuid = Uuid::new_v4();
    println!("Helloo! {:?}", uuid);
}

#[cfg(test)]
mod tests {
    #[test]
    fn fail() {
        assert!(true);
    }
}
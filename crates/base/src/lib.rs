use uuid::Uuid;

pub fn hello() {
    let uuid = Uuid::new_v4();
    println!("Hello! {:?}", uuid);
}

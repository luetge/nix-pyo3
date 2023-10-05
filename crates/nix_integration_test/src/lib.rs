use proc_macro::{Delimiter, Group, TokenStream, TokenTree};

/// Skip compilation if the environment variable `RUN_NIX_INTEGRATION_TESTS` is undefined (check at runtime).
#[proc_macro_attribute]
pub fn nix_integration_test(_: TokenStream, item: TokenStream) -> TokenStream {
    let mut tokens: Vec<_> = item.into_iter().collect();

    // We assume the last token tree is the body of the function, and we
    // prepend some code checking environment variables to the function body
    let mut glue_code: TokenStream = r#"
    {
        if !std::env::var("RUN_NIX_INTEGRATION_TESTS").map(|value| (value == "1" || value == "true")).unwrap_or(false) {
            println!("\x1b[93mskipped nix integration tests. Set environment variable RUN_NIX_INTEGRATION_TESTS=1 to run them.\x1b[0m");
            return
        }
    }
    "#
    .parse()
    .unwrap();
    glue_code.extend(TokenStream::from_iter([tokens.pop().unwrap()]));

    // Add a brace expression around code, i.e. `{ $glue_code $original_code }`
    TokenStream::from_iter(tokens.into_iter().chain([TokenTree::Group(Group::new(
        Delimiter::Brace,
        TokenStream::from_iter([glue_code]),
    ))]))
}

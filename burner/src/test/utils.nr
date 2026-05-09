use aztec::{
    test::helpers::test_environment::TestEnvironment,
    protocol::address::AztecAddress,
};
use crate::Burner;
use token::Token;

/// @notice Deploys a token and burner contract into a fresh test environment.
/// @dev The deployer initializes both contracts, and `user` is the account used by burn tests.
pub unconstrained fn setup() -> (
    TestEnvironment,
    AztecAddress,
    AztecAddress,
    AztecAddress,
    AztecAddress,
) {
    let mut env = TestEnvironment::new();

    let deployer = env.create_light_account();
    let user = env.create_contract_account();

    let token_init = Token::interface().constructor(
        "MyToken000000000000000000000000",
        "MT00000000000000000000000000000",
        18,
    );

    let token_contract_address = env
        .deploy("@token/Token")
        .with_public_initializer(deployer, token_init);

    let burner_init = Burner::interface().constructor(token_contract_address);

    let burner_address = env
        .deploy("@burner/Burner")
        .with_public_initializer(deployer, burner_init);

    (env, deployer, user, token_contract_address, burner_address)
}

/// @notice Reads a user's private token balance through the token utility entrypoint.
pub unconstrained fn get_user_priv_balance(env: TestEnvironment, who:AztecAddress, token_contract_address:AztecAddress,) -> u128 { 

    env.execute_utility(Token::at(token_contract_address).balance_of_private(who))
}

use crate::{Burner, test::utils};
use token::Token;
use aztec::test::helpers::authwit:: add_private_authwit_from_call;

global MINT_AMOUNT: u128 = 2000;
global BURN_AMOUNT: u128 = 1000;
global FIELD_ONE: Field = 1;

/// @notice Burner cannot spend a user's private notes without the matching authwit.
#[test(should_fail_with = "Unknown auth witness for message hash")]
pub unconstrained fn test_private_burn_fails_no_authwit() {
    // Deploy token and burner, then mint private balance to the user.
    let (env, deployer, user, token_contract_address, burner_address) = utils::setup();
    let authwit_nonce = FIELD_ONE;

    env.call_private(deployer, Token::at(token_contract_address).private_mint(user, MINT_AMOUNT));

    // The burner attempts a private burn, but no authwit was registered for this call.
    env.call_private(user, Burner::at(burner_address).foo(user, BURN_AMOUNT, authwit_nonce));
   
}

/// @notice Burner spends the user's private balance when the user pre-authorizes the burn.
#[test]
pub unconstrained fn test_private_burn_with_authwit() {
    // Deploy token and burner, then mint private balance to the user.
    let (env, deployer, user, token_contract_address, burner_address) = utils::setup();
    let authwit_nonce = FIELD_ONE;

    env.call_private(deployer, Token::at(token_contract_address).private_mint(user, MINT_AMOUNT));

    // Build the token burn call the burner will execute and authorize it as the user.
    let burn_call = Token::at(token_contract_address).private_burn(user, BURN_AMOUNT, authwit_nonce);

    add_private_authwit_from_call(env, user, burner_address, burn_call);

    // With the authwit present, the burner can consume the user's private notes.
    env.call_private(user, Burner::at(burner_address).foo(user, BURN_AMOUNT, authwit_nonce));

    let user_balance = utils::get_user_priv_balance(env, user, token_contract_address);

    assert(user_balance.eq(MINT_AMOUNT - BURN_AMOUNT));
}

/// @notice Burner cannot replay a consumed private authwit with the same nonce.
#[test(should_fail_with = "Attempted to emit duplicate siloed nullifier")]
pub unconstrained fn test_private_burn_authwit_replay_fails() {
    // Deploy token and burner, then mint private balance to the user.
    let (env, deployer, user, token_contract_address, burner_address) = utils::setup();
    let authwit_nonce = FIELD_ONE;

    env.call_private(deployer, Token::at(token_contract_address).private_mint(user, MINT_AMOUNT));

    // Build the token burn call the burner will execute and authorize it as the user.
    let burn_call = Token::at(token_contract_address).private_burn(user, BURN_AMOUNT, authwit_nonce);

    add_private_authwit_from_call(env, user, burner_address, burn_call);

    // The first burn consumes the authwit.
    env.call_private(user, Burner::at(burner_address).foo(user, BURN_AMOUNT, authwit_nonce));

    // Reusing the same authorized call should fail once the authwit has been consumed.
    env.call_private(user, Burner::at(burner_address).foo(user, BURN_AMOUNT, authwit_nonce));
}

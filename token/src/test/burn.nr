use crate::test::utils;

global BURN_AMOUNT: u128 = 1000;
global MORE_BURN: u128 = 1001;
global MINT_AMOUNT: u128 = 2000;
global FIELD_ZERO: Field = 0;

// ---------------------------------------------------------------------
// burn -- public
// ---------------------------------------------------------------------

/// @notice Test public burn by the owner reduces the owner's public balance.
#[test]
pub unconstrained fn test_burn_public(){
    let (env, _deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    utils::public_burn(env, user, user, token_contract_address, BURN_AMOUNT, FIELD_ZERO);

    let user_balance = utils::get_user_pub_balance(env, user, token_contract_address);
    let balance = MINT_AMOUNT - BURN_AMOUNT;
    assert(user_balance.eq(balance));
}

/// @notice Test public burn rejects a zero amount.
#[test(should_fail_with = "cannot burn 0")]
pub unconstrained fn test_zero_burn_fails(){
    let (env, _deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    utils::public_burn(env, user, user, token_contract_address, 0, FIELD_ZERO);
}

/// @notice Test public burn reduces total supply.
#[test]
pub unconstrained fn test_public_burn_reduces_total_supply(){
    let (env, _deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    utils::public_burn(env, user, user, token_contract_address, BURN_AMOUNT, FIELD_ZERO);

    let total_supply = utils::get_total_supply(env, token_contract_address);
    assert(total_supply.eq(MINT_AMOUNT - BURN_AMOUNT));
}

/// @notice Test public burn rejects an amount above the holder's public balance.
#[test(should_fail_with = "Not enough balance")]
pub unconstrained fn test_public_burn_more_than_balance_fails(){
    let (env, _deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    utils::public_burn(env, user, user, token_contract_address, MINT_AMOUNT + 1, FIELD_ZERO);
}

/// @notice Test public burn reverts when a non-owner lacks authwit authorization.
#[test(should_fail_with = "Contract execution has reverted: Assertion failed: unauthorized 'true, authorized'")]
pub unconstrained fn test_non_owner_burn_fails () {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    utils::public_burn(env, deployer, user, token_contract_address, BURN_AMOUNT, FIELD_ZERO);
}

/// @notice Test public authwit lets an authorized non-owner burn the exact amount.
#[test]
pub unconstrained fn test_auth_allows_non_owner_burns_with_authwit () {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    let authwit_nonce: Field = 123;
    // The user authorizes the deployer to burn this amount from the user's balance.
    utils::public_burn_with_authwit(env, user, deployer, token_contract_address, BURN_AMOUNT, authwit_nonce);

    let user_balance = utils::get_user_pub_balance(env, user, token_contract_address);
    let balance = MINT_AMOUNT - BURN_AMOUNT;
    assert(user_balance.eq(balance));
}

/// @notice Test public authwit cannot be replayed with the same nonce after it is consumed.
#[test(should_fail_with = "unauthorized")]
pub unconstrained fn test_public_burn_authwit_replay_same_nonce_fails () {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    let authwit_nonce: Field = 123;
    utils::public_burn_with_authwit(env, user, deployer, token_contract_address, BURN_AMOUNT, authwit_nonce);

    let user_balance = utils::get_user_pub_balance(env, user, token_contract_address);
    let balance = MINT_AMOUNT - BURN_AMOUNT;
    assert(user_balance.eq(balance));

    utils::public_burn(env, deployer, user, token_contract_address, BURN_AMOUNT, authwit_nonce);
}

/// @notice Test authwit cannot be replayed for a larger public burn amount.
#[test(should_fail_with = "unauthorized")]
pub unconstrained fn test_fail_if_burn_attempt_more_than_auth () {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    let authwit_nonce: Field = 123;
    // Authorization is bound to BURN_AMOUNT, so MORE_BURN should not validate.
    utils::authorize_public_burn(env, user, deployer, token_contract_address, BURN_AMOUNT, authwit_nonce);
    utils::public_burn(env, deployer, user, token_contract_address, MORE_BURN, authwit_nonce);

    let user_balance = utils::get_user_pub_balance(env, user, token_contract_address);
    let balance = MINT_AMOUNT - BURN_AMOUNT;
    assert(user_balance.eq(balance));
}

// ---------------------------------------------------------------------
// burn -- private
// ---------------------------------------------------------------------

/// @notice Test private burn by the owner spends private notes and reduces private balance.
#[test]
pub unconstrained fn test_burn_private(){
    let (env, _deployer, user, token_contract_address) = utils::setup_with_private_mint(MINT_AMOUNT);

    utils::private_burn(env, user, user, token_contract_address, BURN_AMOUNT, FIELD_ZERO);

    let user_balance = utils::get_user_priv_balance(env, user, token_contract_address);
    let balance = MINT_AMOUNT - BURN_AMOUNT;
    assert(user_balance.eq(balance));
}


/// @notice Test private burn rejects a zero amount.
#[test(should_fail_with = "cannot burn 0")]
pub unconstrained fn test_zero_burn_fails_priv(){
    let (env, _deployer, user, token_contract_address) = utils::setup_with_private_mint(MINT_AMOUNT);

    utils::private_burn(env, user, user, token_contract_address, 0, FIELD_ZERO);
}

/// @notice Test private burn reduces total supply.
#[test]
pub unconstrained fn test_private_burn_reduces_total_supply(){
    let (env, _deployer, user, token_contract_address) = utils::setup_with_private_mint(MINT_AMOUNT);

    utils::private_burn(env, user, user, token_contract_address, BURN_AMOUNT, FIELD_ZERO);

    let total_supply = utils::get_total_supply(env, token_contract_address);
    assert(total_supply.eq(MINT_AMOUNT - BURN_AMOUNT));
}

/// @notice Test private burn rejects an amount above the holder's private balance.
#[test(should_fail_with = "balance too low")]
pub unconstrained fn test_private_burn_more_than_balance_fails(){
    let (env, _deployer, user, token_contract_address) = utils::setup_with_private_mint(MINT_AMOUNT);

    utils::private_burn(env, user, user, token_contract_address, MINT_AMOUNT + 1, FIELD_ZERO);
}


/// @notice Test private note spending fails when the tx caller cannot access the owner's note.
#[test(should_fail_with = "Assertion failed: Failed to get a note 'self.is_some()'")]
pub unconstrained fn test_direct_note_spending_call_fails() {
    let (env, deployer, user, token_contract_address) = utils::setup_user_contract_with_private_mint(MINT_AMOUNT);

    utils::private_burn(env, deployer, user, token_contract_address, BURN_AMOUNT, FIELD_ZERO);
}

// #[test]
// pub unconstrained fn test_auth_allows_non_owner_burns_priv () {
//     let (env, deployer, user, token_contract_address) = utils::setup_user_contract();
//     env.call_private(deployer, Token::at(token_contract_address).private_mint(user, MINT_AMOUNT));

//     let authwit_nonce: Field = 123;
//     let burn_call = Token::at(token_contract_address).private_burn(user, BURN_AMOUNT, authwit_nonce);

//     add_private_authwit_from_call(env, user, deployer, burn_call);
//     env.call_private(deployer, burn_call);

//     let user_balance = utils::get_user_priv_balance(env, user, token_contract_address);
//     let balance = MINT_AMOUNT - BURN_AMOUNT;
//     assert(user_balance.eq(balance));
// }

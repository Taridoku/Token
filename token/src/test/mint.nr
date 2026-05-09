use crate::test::utils;
use std::ops::WrappingSub;

global MINT_AMOUNT: u128 = 10000;
global ONE: u128 = 1;
global ZERO: u128 = 0;


// ---------------------------------------------------------------------
// mint -- public
// ---------------------------------------------------------------------



/// @notice Test minting in public increases balance and total supply by expected amount.
#[test]
pub unconstrained fn test_mint_to_public(){

    let (env, deployer, user, token_contract_address) = utils::setup();

    utils::public_mint(env, deployer, user, token_contract_address, MINT_AMOUNT);

    let user_balance = utils::get_user_pub_balance(env, user, token_contract_address);

    assert (user_balance.eq(MINT_AMOUNT), "Mint failed");

    let total_supply = utils::get_total_supply(env, token_contract_address); 

    assert(total_supply.eq(MINT_AMOUNT));
}

/// @notice Test public minting reverts if called by a non-minter.
#[test(should_fail_with = "caller is not a minter")]
pub unconstrained fn test_non_minter_mint_fail(){
    let (env, _deployer, user, token_contract_address) = utils::setup();

    utils::public_mint(env, user, user, token_contract_address, MINT_AMOUNT);
}

/// @notice Test public minting rejects a zero amount.
#[test(should_fail_with = "cannot mint 0")]
pub unconstrained fn test_zero_pub_mint_fail(){
    let (env, deployer, user, token_contract_address) = utils::setup();

    utils::public_mint(env, deployer, user, token_contract_address, ZERO);
}


/// @notice Test public minting reverts when the recipient balance would overflow.
#[test(should_fail_with = "Contract execution has reverted: Assertion failed: attempt to add with overflow 'self.storage.public_balance.at(who).read() + amount'")]
pub unconstrained fn test_mint_overflow_will_fail (){
    let (env, deployer, user, token_contract_address) = utils::setup();

    let mint_max_128 = (0 as u128).wrapping_sub(ONE);

    utils::public_mint(env, deployer, user, token_contract_address, mint_max_128);

    let user_balance = utils::get_user_pub_balance(env, user, token_contract_address);

    assert (user_balance.eq(mint_max_128), "user balance not max128");

    utils::public_mint(env, deployer, user, token_contract_address, ONE);
}



// ---------------------------------------------------------------------
// mint -- private
// ---------------------------------------------------------------------

/// @notice Test private minting creates notes that sum to the minted amount.
#[test]
pub unconstrained fn test_priv_mint(){
    let (env, deployer, user, token_contract_address) = utils::setup();

    utils::private_mint(env, deployer, user, token_contract_address, MINT_AMOUNT);

    let user_balance = utils::get_user_priv_balance(env, user, token_contract_address);

    assert(user_balance.eq(MINT_AMOUNT), "mint failed");
}

/// @notice Test private minting reverts if called by a non-minter.
#[test(should_fail_with = "caller is not a minter")]
pub unconstrained fn test_priv_mint_fail_if_not_minter(){
    
    let (env, _deployer, user, token_contract_address) = utils::setup();

    utils::private_mint(env, user, user, token_contract_address, MINT_AMOUNT);
}

/// @notice Test private minting rejects a zero amount.
#[test(should_fail_with = "cannot mint 0")]
pub unconstrained fn test_zero_priv_mint_fail(){
    let (env, deployer, user, token_contract_address) = utils::setup();

    utils::private_mint(env, deployer, user, token_contract_address, ZERO);
}

/// @notice Test private minting reverts when total supply would overflow.
#[test(should_fail_with = "Contract execution has reverted: Assertion failed: attempt to add with overflow 'self.storage.total_supply.read() + amount'")]
pub unconstrained fn test_priv_mint_overflow_will_fail (){
    let (env, deployer, user, token_contract_address) = utils::setup();

    let mint_max_128 = (0 as u128).wrapping_sub(ONE);

    utils::private_mint(env, deployer, user, token_contract_address, mint_max_128);

    let user_balance = utils::get_user_priv_balance(env, user, token_contract_address);

    assert (user_balance.eq(mint_max_128), "user balance not max128");

    utils::public_mint(env, deployer, user, token_contract_address, ONE);
}

use crate::test::utils;
use compressed_string::FieldCompressedString;

global BRIDGE_AMOUNT: u128 = 1;
global EXPECTED_DECIMAL: u8 = 18;

#[test]
pub unconstrained fn test_metadata_getters_return_constructor_values() {
    let (env, _deployer, _user, token_contract_address) = utils::setup();

    let expected_name = FieldCompressedString::from_string("MyToken000000000000000000000000");
    let expected_symbol = FieldCompressedString::from_string("MT00000000000000000000000000000");

    assert(utils::get_name(env, token_contract_address).is_eq(expected_name), "name mismatch");
    assert(
        utils::get_symbol(env, token_contract_address).is_eq(expected_symbol),
        "symbol mismatch",
    );
    assert(
        utils::get_decimal(env, token_contract_address).eq(EXPECTED_DECIMAL),
        "decimal mismatch",
    );
}

#[test(should_fail_with = "can only be called by the same contract")]
pub unconstrained fn test_direct_increase_total_supply_fails() {
    let (env, deployer, _user, token_contract_address) = utils::setup();

    utils::increase_total_supply(env, deployer, token_contract_address, BRIDGE_AMOUNT);
}

#[test(should_fail_with = "can only be called by the same contract")]
pub unconstrained fn test_direct_decrease_total_supply_fails() {
    let (env, deployer, _user, token_contract_address) = utils::setup();

    utils::decrease_total_supply(env, deployer, token_contract_address, BRIDGE_AMOUNT);
}

#[test(should_fail_with = "can only be called by the same contract")]
pub unconstrained fn test_direct_increase_public_balance_fails() {
    let (env, deployer, user, token_contract_address) = utils::setup();

    utils::increase_public_balance(env, deployer, user, token_contract_address, BRIDGE_AMOUNT);
}

#[test(should_fail_with = "can only be called by the same contract")]
pub unconstrained fn test_direct_decrease_public_balance_fails() {
    let (env, deployer, user, token_contract_address) = utils::setup();

    utils::decrease_public_balance(env, deployer, user, token_contract_address, BRIDGE_AMOUNT);
}

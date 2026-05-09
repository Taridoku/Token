use crate::test::utils;
use aztec::{
    note::constants::MAX_NOTES_PER_PAGE
};
use uint_note::UintNote;

global MINT_AMOUNT: u128 = 2000;
global TRANSFER_AMOUNT: u128 = 500;
global FIELD_ONE: Field = 1;
global TWELVE_COUNT: u128 = 12;
global TWO: u8 = 2;
global ONE: u8 = 1;
global ZERO: u8 = 0;

/// @notice Test delegated public transfer moves balance when authwit matches the call.
#[test]
unconstrained fn test_transfer_public_to_public() {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    // The user signs an authwit so deployer can move TRANSFER_AMOUNT to itself.
    utils::transfer_pub2pub_with_authwit(
        env,
        user,
        deployer,
        deployer,
        token_contract_address,
        TRANSFER_AMOUNT,
        FIELD_ONE,
    );

    let deployer_balance = utils::get_user_pub_balance(env, deployer, token_contract_address);
    assert(deployer_balance.eq(TRANSFER_AMOUNT));

    let user_balance = utils::get_user_pub_balance(env, user, token_contract_address);
    assert(user_balance.eq(MINT_AMOUNT - TRANSFER_AMOUNT));
}

/// @notice Test delegated public transfer reverts without the owner's authwit.
#[test(should_fail_with = "Assertion failed: unauthorized 'true, authorized'")]
unconstrained fn test_transfer_public_to_public_fails_no_authwit() {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    utils::transfer_pub2pub(env, deployer, user, deployer, token_contract_address, TRANSFER_AMOUNT, FIELD_ONE);

    let deployer_balance = utils::get_user_pub_balance(env, deployer, token_contract_address);
    assert(deployer_balance.eq(TRANSFER_AMOUNT));
}

/// @notice Test transfer_from moves public balance after allowance approval.
#[test]
unconstrained fn test_transfer_from_public_to_public() {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    utils::approve(env, user, deployer, token_contract_address, TRANSFER_AMOUNT);
    utils::transfer_from_pub2pub(env, deployer, user, deployer, token_contract_address, TRANSFER_AMOUNT);

    let deployer_balance = utils::get_user_pub_balance(env, deployer, token_contract_address);
    assert(deployer_balance.eq(TRANSFER_AMOUNT));

    let user_balance = utils::get_user_pub_balance(env, user, token_contract_address);
    assert(user_balance.eq(MINT_AMOUNT - TRANSFER_AMOUNT));
}

/// @notice Test transfer_from rejects an amount above the approved allowance.
#[test(should_fail_with = "insufficient allowance")]
unconstrained fn test_transfer_more_allowance_from_public_to_public() {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    utils::approve(env, user, deployer, token_contract_address, TRANSFER_AMOUNT);
    utils::transfer_from_pub2pub(env, deployer, user, deployer, token_contract_address, MINT_AMOUNT);
}

/// @notice Test allowance is consumed after transfer_from and cannot be reused.
#[test(should_fail_with = "insufficient allowance")]
unconstrained fn test_transfer_more_after_transferring_allowed() {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    utils::approve(env, user, deployer, token_contract_address, TRANSFER_AMOUNT);
    utils::transfer_from_pub2pub(env, deployer, user, deployer, token_contract_address, TRANSFER_AMOUNT);

    let deployer_balance = utils::get_user_pub_balance(env, deployer, token_contract_address);
    assert(deployer_balance.eq(TRANSFER_AMOUNT));

    let user_balance = utils::get_user_pub_balance(env, user, token_contract_address);
    assert(user_balance.eq(MINT_AMOUNT - TRANSFER_AMOUNT));

    utils::transfer_from_pub2pub(env, deployer, user, deployer, token_contract_address, TRANSFER_AMOUNT);
}


//// private
/// @notice Test forwarded private transfer spends the user's notes with private authwit.
#[test]
unconstrained fn test_transfer_private_to_private() {
    let (env, deployer, user, token_contract_address, caller_contract_address) =
        utils::deploy_caller_contract_with_private_mint(MINT_AMOUNT);

    // User authorizes the caller contract to forward the private note spend to deployer.
    utils::transfer_priv2priv_via_caller_contract(
        env,
        user,
        user,
        caller_contract_address,
        deployer,
        token_contract_address,
        TRANSFER_AMOUNT,
        FIELD_ONE,
    );

    let deployer_balance = utils::get_user_priv_balance(env, deployer, token_contract_address);
    assert(deployer_balance.eq(TRANSFER_AMOUNT));

    let user_balance = utils::get_user_priv_balance(env, user, token_contract_address);
    assert(user_balance.eq(MINT_AMOUNT - TRANSFER_AMOUNT));
    
}

/// @notice Test recursive private transfer aggregates many notes and returns the expected change note.
#[test]
unconstrained fn test_recursive_private_transfer() {
    let (env, deployer, user, token_contract_address, caller_contract_address) = utils::deploy_caller_contract_with_setup(); 

    let note_value = MINT_AMOUNT;
    let notes_count = TWELVE_COUNT;
    let total_amount = note_value * notes_count;

    // Create enough notes that transfer_priv2priv must recursively collect inputs.
    for _ in 0..notes_count {
        utils::private_mint(env, deployer, user, token_contract_address, MINT_AMOUNT);
    }

    // Leave one unit behind so the sender should receive a single private change note.
    let transfer_amount = total_amount - (ONE as u128);
    utils::transfer_priv2priv_via_caller_contract(
        env, 
        user, 
        user, 
        caller_contract_address, 
        deployer, 
        token_contract_address, 
        transfer_amount, 
        FIELD_ONE
    );

    let recipient_balance = utils::get_user_priv_balance(env, deployer, token_contract_address);
    assert(recipient_balance.eq(transfer_amount), "incorrect balance");
    
    // The recursive spend should consume the source notes and leave exactly one change note.
    let final_owner_notes: BoundedVec<UintNote, MAX_NOTES_PER_PAGE> = utils::get_private_balance_notes(env, token_contract_address, user, ZERO as u32);
    assert(final_owner_notes.len().eq(ONE as u32), "incorrect note count");
    assert(final_owner_notes.get(ZERO as u32).value.eq(total_amount - transfer_amount), "incorrect transferred note amount");

    utils::check_private_balance(env, token_contract_address, user, total_amount - transfer_amount);
    utils::check_private_balance(env, token_contract_address, deployer, transfer_amount);
}

/// @notice Test shielding public balance privately preserves total supply.
#[test]
unconstrained fn test_transfer_pub2priv_happy_path_total_supply_unchanged() {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);
    let total_supply_before = utils::get_total_supply(env, token_contract_address);

    utils::transfer_pub2priv(env, user, user, deployer, token_contract_address, TRANSFER_AMOUNT, ZERO as Field);

    let user_public_balance = utils::get_user_pub_balance(env, user, token_contract_address);
    assert(user_public_balance.eq(MINT_AMOUNT - TRANSFER_AMOUNT));

    let deployer_private_balance = utils::get_user_priv_balance(env, deployer, token_contract_address);
    assert(deployer_private_balance.eq(TRANSFER_AMOUNT));

    let total_supply_after = utils::get_total_supply(env, token_contract_address);
    assert(total_supply_after.eq(total_supply_before));
}

/// @notice Test unshielding private balance publicly preserves total supply.
#[test]
unconstrained fn test_transfer_priv2pub_happy_path_total_supply_unchanged() {
    let (env, deployer, user, token_contract_address) = utils::setup_with_private_mint(MINT_AMOUNT);
    let total_supply_before = utils::get_total_supply(env, token_contract_address);

    utils::transfer_priv2pub(env, user, user, deployer, token_contract_address, TRANSFER_AMOUNT, ZERO as Field);

    let user_private_balance = utils::get_user_priv_balance(env, user, token_contract_address);
    assert(user_private_balance.eq(MINT_AMOUNT - TRANSFER_AMOUNT));

    let deployer_public_balance = utils::get_user_pub_balance(env, deployer, token_contract_address);
    assert(deployer_public_balance.eq(TRANSFER_AMOUNT));

    let total_supply_after = utils::get_total_supply(env, token_contract_address);
    assert(total_supply_after.eq(total_supply_before));
}

/// @notice Test public-to-public transfer preserves total supply.
#[test]
unconstrained fn test_transfer_pub2pub_total_supply_unchanged() {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);
    let total_supply_before = utils::get_total_supply(env, token_contract_address);

    utils::transfer_pub2pub(env, user, user, deployer, token_contract_address, TRANSFER_AMOUNT, ZERO as Field);

    let total_supply_after = utils::get_total_supply(env, token_contract_address);
    assert(total_supply_after.eq(total_supply_before));
}

/// @notice Test allowance can be spent across multiple partial transfer_from calls.
#[test]
unconstrained fn test_transfer_from_partial_allowance_spent_in_two_chunks() {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);
    let chunk_amount = TRANSFER_AMOUNT / (TWO as u128);

    utils::approve(env, user, deployer, token_contract_address, TRANSFER_AMOUNT);
    utils::transfer_from_pub2pub(env, deployer, user, deployer, token_contract_address, chunk_amount);
    utils::transfer_from_pub2pub(env, deployer, user, deployer, token_contract_address, TRANSFER_AMOUNT - chunk_amount);

    let deployer_balance = utils::get_user_pub_balance(env, deployer, token_contract_address);
    assert(deployer_balance.eq(TRANSFER_AMOUNT));

    let user_balance = utils::get_user_pub_balance(env, user, token_contract_address);
    assert(user_balance.eq(MINT_AMOUNT - TRANSFER_AMOUNT));
}

/// @notice Test approving again overwrites the previous larger allowance.
#[test(should_fail_with = "insufficient allowance")]
unconstrained fn test_approval_overwrite_replaces_prior_allowance() {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    utils::approve(env, user, deployer, token_contract_address, MINT_AMOUNT);
    utils::approve(env, user, deployer, token_contract_address, TRANSFER_AMOUNT);

    utils::transfer_from_pub2pub(env, deployer, user, deployer, token_contract_address, MINT_AMOUNT);
}

/// @notice Test an owner can transfer_from its own public balance without approval.
#[test]
unconstrained fn test_owner_can_transfer_from_self_without_approval() {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    utils::transfer_from_pub2pub(env, user, user, deployer, token_contract_address, TRANSFER_AMOUNT);

    let deployer_balance = utils::get_user_pub_balance(env, deployer, token_contract_address);
    assert(deployer_balance.eq(TRANSFER_AMOUNT));

    let user_balance = utils::get_user_pub_balance(env, user, token_contract_address);
    assert(user_balance.eq(MINT_AMOUNT - TRANSFER_AMOUNT));
}

/// @notice Test transfer_from still requires enough public balance even with allowance.
#[test(should_fail_with = "Not enough balance")]
unconstrained fn test_transfer_from_with_sufficient_allowance_but_insufficient_balance_fails() {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);
    let overdraft_amount = MINT_AMOUNT + TRANSFER_AMOUNT;

    utils::approve(env, user, deployer, token_contract_address, overdraft_amount);
    utils::transfer_from_pub2pub(env, deployer, user, deployer, token_contract_address, overdraft_amount);
}

/// @notice Test a public transfer authwit cannot be replayed with the same nonce.
#[test(should_fail_with = "unauthorized")]
unconstrained fn test_transfer_pub2pub_authwit_replay_same_nonce_fails() {
    let (env, deployer, user, token_contract_address) = utils::setup_with_public_mint(MINT_AMOUNT);

    utils::transfer_pub2pub_with_authwit(
        env,
        user,
        deployer,
        deployer,
        token_contract_address,
        TRANSFER_AMOUNT,
        FIELD_ONE,
    );

    utils::transfer_pub2pub(env, deployer, user, deployer, token_contract_address, TRANSFER_AMOUNT, FIELD_ONE);
}

/// @notice Test a private transfer authwit forwarded through a caller contract cannot be replayed.
#[test(should_fail_with = "duplicate nullifiers")]
unconstrained fn test_transfer_priv2priv_caller_authwit_replay_same_nonce_fails() {
    let (env, deployer, user, token_contract_address, caller_contract_address) =
        utils::deploy_caller_contract_with_private_mint(MINT_AMOUNT);

    utils::transfer_priv2priv_via_caller_contract(
        env,
        user,
        user,
        caller_contract_address,
        deployer,
        token_contract_address,
        TRANSFER_AMOUNT,
        FIELD_ONE,
    );

    // Seed the exact same private authwit again; the nonce/nullifier should still prevent replay.
    utils::authorize_transfer_priv2priv_via_caller_contract(
        env,
        user,
        caller_contract_address,
        deployer,
        token_contract_address,
        TRANSFER_AMOUNT,
        FIELD_ONE,
    );

    utils::forward_transfer_priv2priv_via_caller_contract(
        env,
        user,
        user,
        caller_contract_address,
        deployer,
        token_contract_address,
        TRANSFER_AMOUNT,
        FIELD_ONE,
    );
}

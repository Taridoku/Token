use aztec::{
    state_vars::{OwnedStateVariable, PrivateSet},
    note::{constants::MAX_NOTES_PER_PAGE, note_viewer_options::NoteViewerOptions}, 
    test::helpers::authwit::{add_public_authwit_from_call, add_private_authwit_from_call},
    test::helpers::test_environment::TestEnvironment, 
    protocol::{address::AztecAddress, traits::Packable},
};
use crate::Token;
use caller_contract::CallerContract;
use compressed_string::FieldCompressedString;
use uint_note::UintNote;

// ---------------------------------------------------------------------
// Internal -- Public helpers
// ---------------------------------------------------------------------

/// @notice Creates a fresh environment, deployer, light-account user, and initialized token contract.
pub unconstrained fn setup() -> (TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {

    let mut env = TestEnvironment::new();

    let deployer = env.create_light_account();
    let user = env.create_light_account();

    let token_contract_address = deploy_token(env, deployer);

    (env, deployer, user, token_contract_address)
}

/// @notice Creates a fresh environment where the test user is a contract account.
pub unconstrained fn setup_user_contract() -> (TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {

    let mut env = TestEnvironment::new();

    let deployer = env.create_light_account();
    let user = env.create_contract_account();

    let token_contract_address = deploy_token(env, deployer);

    (env, deployer, user, token_contract_address)
}

/// @notice Deploys the token and a caller contract used to forward private calls.
pub unconstrained fn deploy_caller_contract_with_setup() -> (TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress) {
    let (env, deployer, user, token_contract_address) = setup_user_contract();

    let caller_contract_address = deploy_caller_contract(env);

    (env, deployer, user, token_contract_address, caller_contract_address)

}

/// @notice Sets up the token and gives the user an initial public balance.
pub unconstrained fn setup_with_public_mint(amount: u128) -> (TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    let (env, deployer, user, token_contract_address) = setup();
    public_mint(env, deployer, user, token_contract_address, amount);

    (env, deployer, user, token_contract_address)
}

/// @notice Sets up the token and gives the user an initial private-note balance.
pub unconstrained fn setup_with_private_mint(amount: u128) -> (TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    let (env, deployer, user, token_contract_address) = setup();
    private_mint(env, deployer, user, token_contract_address, amount);

    (env, deployer, user, token_contract_address)
}

/// @notice Sets up a contract-account user with an initial private-note balance.
pub unconstrained fn setup_user_contract_with_private_mint(amount: u128) -> (TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    let (env, deployer, user, token_contract_address) = setup_user_contract();
    private_mint(env, deployer, user, token_contract_address, amount);

    (env, deployer, user, token_contract_address)
}

/// @notice Sets up a private balance and caller contract for forwarded private-call tests.
pub unconstrained fn deploy_caller_contract_with_private_mint(amount: u128) -> (TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress) {
    let (env, deployer, user, token_contract_address, caller_contract_address) = deploy_caller_contract_with_setup();
    private_mint(env, deployer, user, token_contract_address, amount);

    (env, deployer, user, token_contract_address, caller_contract_address)
}


// ---------------------------------------------------------------------
// Deployment helpers
// ---------------------------------------------------------------------

/// @notice Deploys Token with fixed metadata and the deployer as initializer caller.
pub unconstrained fn deploy_token(mut env: TestEnvironment, deployer: AztecAddress) -> AztecAddress {
    let initializer_call_interface = Token::interface().constructor(
        "MyToken000000000000000000000000",
        "MT00000000000000000000000000000",
        18,
    );

    env.deploy("@token/Token").with_public_initializer(deployer, initializer_call_interface)
}

/// @notice Deploys the forwarding caller contract without an initializer.
pub unconstrained fn deploy_caller_contract(mut env: TestEnvironment) -> AztecAddress {
    env.deploy("@caller_contract/CallerContract").without_initializer()
}

// ---------------------------------------------------------------------
// Call helpers
// ---------------------------------------------------------------------

/// @notice Calls `public_mint` as `caller` and credits `to`.
pub unconstrained fn public_mint(
    env: TestEnvironment,
    caller: AztecAddress,
    to: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
) {
    env.call_public(caller, Token::at(token_contract_address).public_mint(to, amount));
}

/// @notice Calls `private_mint` as `caller` and creates private notes for `to`.
pub unconstrained fn private_mint(
    env: TestEnvironment,
    caller: AztecAddress,
    to: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
) {
    env.call_private(caller, Token::at(token_contract_address).private_mint(to, amount));
}

/// @notice Calls `public_burn` directly; `caller` must be `from` or have matching authwit.
pub unconstrained fn public_burn(
    env: TestEnvironment,
    caller: AztecAddress,
    from: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
    authwit_nonce: Field,
) {
    env.call_public(caller, Token::at(token_contract_address).public_burn(from, amount, authwit_nonce));
}

/// @notice Calls `private_burn` directly; `caller` must be able to spend `from`'s private notes.
pub unconstrained fn private_burn(
    env: TestEnvironment,
    caller: AztecAddress,
    from: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
    authwit_nonce: Field,
) {
    env.call_private(caller, Token::at(token_contract_address).private_burn(from, amount, authwit_nonce));
}

/// @notice Authorizes `caller` to burn from `from`'s public balance, then executes the burn.
pub unconstrained fn public_burn_with_authwit(
    env: TestEnvironment,
    from: AztecAddress,
    caller: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
    authwit_nonce: Field,
) {
    let burn_call = Token::at(token_contract_address).public_burn(from, amount, authwit_nonce);
    // The authwit commits to the exact burn call, including amount and nonce.
    add_public_authwit_from_call(env, from, caller, burn_call);
    env.call_public(caller, burn_call);
}

/// @notice Adds the public burn authwit without executing the burn.
pub unconstrained fn authorize_public_burn(
    env: TestEnvironment,
    from: AztecAddress,
    caller: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
    authwit_nonce: Field,
) {
    let burn_call = Token::at(token_contract_address).public_burn(from, amount, authwit_nonce);
    // Tests use this to prove altered call parameters do not satisfy the authwit.
    add_public_authwit_from_call(env, from, caller, burn_call);
}

/// @notice Approves `spender` to transfer `amount` from `owner`'s public balance.
pub unconstrained fn approve(
    env: TestEnvironment,
    owner: AztecAddress,
    spender: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
) {
    env.call_public(owner, Token::at(token_contract_address).approve(spender, amount));
}

/// @notice Calls `transfer_pub2pub` directly; `caller` must be `from` or have matching authwit.
pub unconstrained fn transfer_pub2pub(
    env: TestEnvironment,
    caller: AztecAddress,
    from: AztecAddress,
    to: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
    authwit_nonce: Field,
) {
    env.call_public(caller, Token::at(token_contract_address).transfer_pub2pub(from, to, amount, authwit_nonce));
}

/// @notice Authorizes `caller` for a public transfer from `from`, then executes it.
pub unconstrained fn transfer_pub2pub_with_authwit(
    env: TestEnvironment,
    from: AztecAddress,
    caller: AztecAddress,
    to: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
    authwit_nonce: Field,
) {
    let transfer_call = Token::at(token_contract_address).transfer_pub2pub(from, to, amount, authwit_nonce);
    // The authwit binds the delegated transfer to the recipient, amount, and nonce.
    add_public_authwit_from_call(env, from, caller, transfer_call);
    env.call_public(caller, transfer_call);
}

/// @notice Adds a public transfer authwit without executing the transfer.
pub unconstrained fn authorize_transfer_pub2pub(
    env: TestEnvironment,
    from: AztecAddress,
    caller: AztecAddress,
    to: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
    authwit_nonce: Field,
) {
    let transfer_call = Token::at(token_contract_address).transfer_pub2pub(from, to, amount, authwit_nonce);
    add_public_authwit_from_call(env, from, caller, transfer_call);
}

/// @notice Transfers public balance through an existing public allowance.
pub unconstrained fn transfer_from_pub2pub(
    env: TestEnvironment,
    caller: AztecAddress,
    from: AztecAddress,
    to: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
) {
    env.call_public(caller, Token::at(token_contract_address).transfer_from_pub2pub(from, to, amount));
}

/// @notice Shields public balance into a private note.
pub unconstrained fn transfer_pub2priv(
    env: TestEnvironment,
    caller: AztecAddress,
    from: AztecAddress,
    to: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
    authwit_nonce: Field,
) {
    env.call_private(caller, Token::at(token_contract_address).transfer_pub2priv(from, to, amount, authwit_nonce));
}

/// @notice Unshields private notes into public balance.
pub unconstrained fn transfer_priv2pub(
    env: TestEnvironment,
    caller: AztecAddress,
    from: AztecAddress,
    to: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
    authwit_nonce: Field,
) {
    env.call_private(caller, Token::at(token_contract_address).transfer_priv2pub(from, to, amount, authwit_nonce));
}

/// @notice Forwards a private transfer through `caller_contract` using `from`'s private authwit.
pub unconstrained fn transfer_priv2priv_via_caller_contract(
    env: TestEnvironment,
    tx_sender: AztecAddress,
    from: AztecAddress,
    caller_contract_address: AztecAddress,
    to: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
    authwit_nonce: Field,
) {
    let transfer_call = Token::at(token_contract_address).transfer_priv2priv(from, to, amount, authwit_nonce);
    // The owner authorizes the caller contract, not the tx sender, to spend matching notes.
    add_private_authwit_from_call(env, from, caller_contract_address, transfer_call);

    // The forwarded call exercises contract-to-contract private transfer authorization.
    env.call_private(
        tx_sender,
        CallerContract::at(caller_contract_address).forward_private_4(
            transfer_call.target_contract,
            transfer_call.selector,
            transfer_call.args,
        ),
    );
}

/// @notice Adds a private transfer authwit for a caller contract without executing it.
pub unconstrained fn authorize_transfer_priv2priv_via_caller_contract(
    env: TestEnvironment,
    from: AztecAddress,
    caller_contract_address: AztecAddress,
    to: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
    authwit_nonce: Field,
) {
    let transfer_call = Token::at(token_contract_address).transfer_priv2priv(from, to, amount, authwit_nonce);
    add_private_authwit_from_call(env, from, caller_contract_address, transfer_call);
}

/// @notice Forwards a private transfer through `caller_contract` without adding authwit.
pub unconstrained fn forward_transfer_priv2priv_via_caller_contract(
    env: TestEnvironment,
    tx_sender: AztecAddress,
    from: AztecAddress,
    caller_contract_address: AztecAddress,
    to: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
    authwit_nonce: Field,
) {
    let transfer_call = Token::at(token_contract_address).transfer_priv2priv(from, to, amount, authwit_nonce);

    env.call_private(
        tx_sender,
        CallerContract::at(caller_contract_address).forward_private_4(
            transfer_call.target_contract,
            transfer_call.selector,
            transfer_call.args,
        ),
    );
}

/// @notice Attempts to call the only-self total-supply increase bridge directly.
pub unconstrained fn increase_total_supply(
    env: TestEnvironment,
    caller: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
) {
    env.call_public(caller, Token::at(token_contract_address).increase_total_supply(amount));
}

/// @notice Attempts to call the only-self total-supply decrease bridge directly.
pub unconstrained fn decrease_total_supply(
    env: TestEnvironment,
    caller: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
) {
    env.call_public(caller, Token::at(token_contract_address).decrease_total_supply(amount));
}

/// @notice Attempts to call the only-self public-balance credit bridge directly.
pub unconstrained fn increase_public_balance(
    env: TestEnvironment,
    caller: AztecAddress,
    who: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
) {
    env.call_public(caller, Token::at(token_contract_address).increase_public_balance(who, amount));
}

/// @notice Attempts to call the only-self public-balance debit bridge directly.
pub unconstrained fn decrease_public_balance(
    env: TestEnvironment,
    caller: AztecAddress,
    who: AztecAddress,
    token_contract_address: AztecAddress,
    amount: u128,
) {
    env.call_public(caller, Token::at(token_contract_address).decrease_public_balance(who, amount));
}

/// @notice Asserts an account's computed private balance equals the expected amount.
pub unconstrained fn check_private_balance(
    env: TestEnvironment,
    token_contract_address: AztecAddress,
    who: AztecAddress,
    address_amount: u128,
) {
    let balance_of_private = get_user_priv_balance(env, who, token_contract_address);
    assert(balance_of_private == address_amount, "private balance is not correct");
}

// ---------------------------------------------------------------------
// View helpers
// ---------------------------------------------------------------------

/// @notice Returns `who`'s public balance from the public balance map.
pub unconstrained fn get_user_pub_balance (env:TestEnvironment, who:AztecAddress, token_contract_address:AztecAddress) -> u128 {

    env.view_public(Token::at(token_contract_address).balance_of_public(who))
}

/// @notice Returns `who`'s private balance by executing the utility balance view.
pub unconstrained fn get_user_priv_balance (env:TestEnvironment, who:AztecAddress, token_contract_address:AztecAddress) -> u128 {

    env.execute_utility(Token::at(token_contract_address).balance_of_private(who))
}

/// @notice Returns private balance notes for `account` at the requested pagination offset.
pub unconstrained fn get_private_balance_notes(
    env: TestEnvironment,
    token_contract_address: AztecAddress,
    account: AztecAddress,
    offset: u32,
) -> BoundedVec<UintNote, MAX_NOTES_PER_PAGE> {

    // Read the underlying PrivateSet directly so tests can assert note count and change-note value.
    let notes = env.utility_context_at(token_contract_address, |context|{

        let options = NoteViewerOptions::<UintNote, <UintNote as Packable>::N>::new().set_offset(offset);

        let private_balances_slot = Token::storage_layout().private_balance.slot;

        let set: PrivateSet <UintNote, _> = OwnedStateVariable::new(context, private_balances_slot, account);

        let notes: BoundedVec<UintNote, MAX_NOTES_PER_PAGE> = set.view_notes(options);

        notes
    });

    notes
}

/// @notice Returns total token supply from public storage.
pub unconstrained fn get_total_supply(env:TestEnvironment, token_contract_address:AztecAddress) -> u128 {

    env.view_public(Token::at(token_contract_address).total_supply())
}

/// @notice Returns the compressed token name.
pub unconstrained fn get_name(env:TestEnvironment, token_contract_address:AztecAddress) -> FieldCompressedString {

    env.view_public(Token::at(token_contract_address).name())
}

/// @notice Returns the compressed token symbol.
pub unconstrained fn get_symbol(env:TestEnvironment, token_contract_address:AztecAddress) -> FieldCompressedString {

    env.view_public(Token::at(token_contract_address).symbol())
}

/// @notice Returns token decimals.
pub unconstrained fn get_decimal(env:TestEnvironment, token_contract_address:AztecAddress) -> u8 {

    env.view_public(Token::at(token_contract_address).decimal())
}

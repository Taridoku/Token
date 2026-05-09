use aztec::macros::aztec;
mod test;

/// @title Token
/// @notice Fungible token example with public balances, private note balances, and authwit-enabled operations.
/// @dev Private balances are stored as `UintNote` notes through `BalanceSet`.
#[aztec]
pub contract Token {
    // ---------------------------------------------------------------------
    // Imports
    // ---------------------------------------------------------------------

    use aztec::{
        macros::{
            storage::storage,
            functions::{only_self, authorize_once, initializer, external, internal, view},
            events::event,
        },
        state_vars::{PublicImmutable, PublicMutable, Map, Owned},
        protocol::address::AztecAddress,
        messages::message_delivery::MessageDelivery,
    };
    use compressed_string::FieldCompressedString;
    use balance_set::BalanceSet;

    // ---------------------------------------------------------------------
    // Globals
    // ---------------------------------------------------------------------

    /// Max notes consumed in the first attempt of a private balance subtraction.
    global INITIAL_MAX_NOTES: u32 = 2;
    /// Max notes consumed per recursive frame after the initial attempt.
    global RECURSIVE_MAX_NOTES: u32 = 8;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    /// @notice Emitted when tokens are minted into a public balance.
    #[event]
    struct Mint {
        to: AztecAddress,
        amount: u128
    }

    /// @notice Emitted when tokens move between public balances.
    #[event]
    struct Transfer {
        from: AztecAddress,
        to: AztecAddress,
        amount: u128
    }

    /// @notice Emitted when tokens are burned from a public balance.
    #[event]
    struct Burn {
        from: AztecAddress,
        amount: u128
    }

    // ---------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------

    #[storage]
    struct Storage<Context> {
        /// @notice Human-readable token name.
        name: PublicImmutable<FieldCompressedString, Context>,
        /// @notice Human-readable token symbol.
        symbol: PublicImmutable<FieldCompressedString, Context>,
        /// @notice Number of decimals used by token amounts.
        decimals: PublicImmutable<u8, Context>,
        /// @notice Account allowed to mint new supply.
        minter: PublicImmutable<AztecAddress, Context>,
        /// @notice Public balances keyed by account address.
        public_balance: Map<AztecAddress, PublicMutable<u128, Context>, Context>,
        /// @notice Private balances keyed by owner and represented as note sets.
        private_balance: Owned<BalanceSet<Context>, Context>,
        /// @notice Public total supply.
        total_supply: PublicMutable<u128, Context>,
        /// @notice Public allowances keyed by owner then spender.
        allowances: Map<AztecAddress, Map<AztecAddress, PublicMutable<u128, Context>, Context>, Context>
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    /// @notice Initializes token metadata and assigns the deployer as the minter.
    /// @param name     The token name.
    /// @param symbol   The token symbol.
    /// @param decimals The number of decimals the token uses.
    #[external("public")]
    #[initializer]
    fn constructor(name: str<31>, symbol: str<31>, decimals: u8) {
        self.storage.name.initialize(FieldCompressedString::from_string(name));
        self.storage.symbol.initialize(FieldCompressedString::from_string(symbol));
        self.storage.decimals.initialize(decimals);
        self.storage.minter.initialize(self.msg_sender())
    }

    // ---------------------------------------------------------------------
    // External -- Public mint / burn
    // ---------------------------------------------------------------------

    /// @notice Mints public tokens to a recipient. Only the minter may call this.
    /// @param to     Recipient of the newly minted tokens.
    /// @param amount Amount to mint.
    #[external("public")]
    fn public_mint(to: AztecAddress, amount: u128) {
        assert(!amount.eq(0), "cannot mint 0");
        assert(self.storage.minter.read().eq(self.msg_sender()), "caller is not a minter");

        self.internal._increase_pub_balance(to, amount);
        self.internal._increase_total_supply(amount);

        self.emit(Mint { to, amount });
    }

    /// @notice Burns public tokens from `from`. Self-burn or via authwit allowance.
    /// @param from           Holder whose public balance is being burned.
    /// @param amount         Amount to burn.
    /// @param authwit_nonce  One-shot authwit nonce; 0 when `from == msg_sender`.
    #[authorize_once("from", "authwit_nonce")]
    #[external("public")]
    fn public_burn(from: AztecAddress, amount: u128, authwit_nonce: Field) {
        assert(!amount.eq(0), "cannot burn 0");

        self.internal._decrease_pub_balance(from, amount);
        self.internal._decrease_total_supply(amount);

        self.emit(Burn { from, amount });
    }

    // ---------------------------------------------------------------------
    // External -- Private mint / burn
    // ---------------------------------------------------------------------

    /// @notice Mints private tokens to a recipient. Only the minter may call this.
    /// @dev    No event is emitted, to preserve recipient privacy.
    /// @param to     Recipient of the newly minted tokens.
    /// @param amount Amount to mint.
    #[external("private")]
    fn private_mint(to: AztecAddress, amount: u128) {
        assert(!amount.eq(0), "cannot mint 0");
        assert(self.storage.minter.read().eq(self.msg_sender()), "caller is not a minter");

        self.internal._increase_priv_balance(to, amount);
        self.enqueue_self.increase_total_supply(amount);
    }

    /// @notice Burns private tokens from `from`. Self-burn or via authwit allowance.
    /// @dev    No event is emitted, to preserve holder privacy.
    /// @param from           Holder whose private balance is being burned.
    /// @param amount         Amount to burn.
    /// @param authwit_nonce  One-shot authwit nonce; 0 when `from == msg_sender`.
    #[authorize_once("from", "authwit_nonce")]
    #[external("private")]
    fn private_burn(from: AztecAddress, amount: u128, authwit_nonce: Field) {
        assert(!amount.eq(0), "cannot burn 0");

        self.internal._decrease_private_balance(from, amount);
        self.enqueue_self.decrease_total_supply(amount);
    }

    // ---------------------------------------------------------------------
    // External -- Approvals
    // ---------------------------------------------------------------------

    /// @notice Sets `spender`'s allowance over the caller's public balance.
    /// @param spender Account allowed to spend the caller's public balance.
    /// @param amount Maximum amount the spender may transfer.
    #[external("public")]
    fn approve (spender:AztecAddress, amount: u128){
        let owner = self.msg_sender();
        self.storage.allowances.at(owner).at(spender).write(amount);
    }

    // ---------------------------------------------------------------------
    // External -- Transfers
    // ---------------------------------------------------------------------

    /// @notice Transfers public tokens between two public balances.
    /// @param from           Source of the transfer.
    /// @param to             Destination of the transfer.
    /// @param amount         Amount to transfer.
    /// @param authwit_nonce  One-shot authwit nonce; 0 when `from == msg_sender`.
    #[authorize_once("from", "authwit_nonce")]
    #[external("public")]
    fn transfer_pub2pub(
        from: AztecAddress,
        to: AztecAddress,
        amount: u128,
        authwit_nonce: Field,
    ) {
        assert(!amount.eq(0), "cannot transfer 0");

        self.internal._decrease_pub_balance(from, amount);
        self.internal._increase_pub_balance(to, amount);

        self.emit(Transfer { from, to, amount });
    }

    /// @notice Transfers public tokens using the caller's allowance from `from`.
    /// @param from   Owner whose allowance and public balance are spent.
    /// @param to     Recipient of the public tokens.
    /// @param amount Amount to transfer.
    #[external("public")]
    fn transfer_from_pub2pub(
        from: AztecAddress,
        to: AztecAddress,
        amount: u128
    ) {
        assert(!amount.eq(0), "cannot transfer 0");
        self.internal._spendAllowance(from, self.msg_sender(), amount);

        self.internal._decrease_pub_balance(from, amount);
        self.internal._increase_pub_balance(to, amount);

        self.emit(Transfer { from, to, amount });
    }

    /// @notice Shields tokens: debits `from`'s public balance and credits `to` privately.
    /// @dev    No event emitted; emitting would leak that the destination is a private credit.
    /// @param from           Public source.
    /// @param to             Private destination.
    /// @param amount         Amount to transfer.
    /// @param authwit_nonce  One-shot authwit nonce; 0 when `from == msg_sender`.
    #[authorize_once("from", "authwit_nonce")]
    #[external("private")]
    fn transfer_pub2priv(
        from: AztecAddress,
        to: AztecAddress,
        amount: u128,
        authwit_nonce: Field,
    ) {
        assert(!amount.eq(0), "cannot transfer 0");

        self.internal._increase_priv_balance(to, amount);
        self.enqueue_self.decrease_public_balance(from, amount);
    }

    /// @notice Unshields tokens: debits `from`'s private balance and credits `to` publicly.
    /// @dev    No event emitted; emitting would leak that the source is a private debit.
    /// @param from           Private source.
    /// @param to             Public destination.
    /// @param amount         Amount to transfer.
    /// @param authwit_nonce  One-shot authwit nonce; 0 when `from == msg_sender`.
    #[authorize_once("from", "authwit_nonce")]
    #[external("private")]
    fn transfer_priv2pub(
        from: AztecAddress,
        to: AztecAddress,
        amount: u128,
        authwit_nonce: Field,
    ) {
        assert(!amount.eq(0), "cannot transfer 0");

        self.internal._decrease_private_balance(from, amount);
        self.enqueue_self.increase_public_balance(to, amount);
    }

    /// @notice Transfers private tokens between two private balances.
    /// @dev    No event emitted, to preserve participant privacy.
    /// @param from           Private source.
    /// @param to             Private destination.
    /// @param amount         Amount to transfer.
    /// @param authwit_nonce  One-shot authwit nonce; 0 when `from == msg_sender`.
    #[authorize_once("from", "authwit_nonce")]
    #[external("private")]
    fn transfer_priv2priv(
        from: AztecAddress,
        to: AztecAddress,
        amount: u128,
        authwit_nonce: Field,
    ) {
        assert(!amount.eq(0), "cannot transfer 0");
        
        self.internal._decrease_private_balance(from, amount);
        self.internal._increase_priv_balance(to, amount);
    }

    // ---------------------------------------------------------------------
    // External -- Self-callable bridges
    // ---------------------------------------------------------------------
    //
    // `#[only_self]` entry points used by `enqueue_self` (private -> public)
    // and `call_self` (private recursion). Authorization is enforced by the
    // calling private function; these helpers trust the caller is the contract.

    /// @notice Public-side bridge for a private -> public total-supply increase.
    /// @param amount Amount to add to total supply.
    #[external("public")]
    #[only_self]
    fn increase_total_supply(amount: u128) {
        self.internal._increase_total_supply(amount)
    }

    /// @notice Public-side bridge for a private -> public total-supply decrease.
    /// @param amount Amount to remove from total supply.
    #[external("public")]
    #[only_self]
    fn decrease_total_supply(amount: u128) {
        self.internal._decrease_total_supply(amount)
    }

    /// @notice Public-side bridge for a private -> public balance credit
    ///         (used by `transfer_priv2pub`).
    /// @param who    Account whose public balance is credited.
    /// @param amount Amount to credit.
    #[external("public")]
    #[only_self]
    fn increase_public_balance(who: AztecAddress, amount: u128) {
        self.internal._increase_pub_balance(who, amount)
    }

    /// @notice Public-side bridge for a private -> public balance debit
    ///         (used by `transfer_pub2priv`).
    /// @param who    Account whose public balance is debited.
    /// @param amount Amount to debit.
    #[external("public")]
    #[only_self]
    fn decrease_public_balance(who: AztecAddress, amount: u128) {
        self.internal._decrease_pub_balance(who, amount);
    }

    /// @notice Recursion entry for private balance subtraction across kernel frames.
    /// @dev    Each frame consumes up to `RECURSIVE_MAX_NOTES`; recurses again if
    ///         the running consumption is still short of `amount`.
    /// @param who    Owner whose private notes are consumed.
    /// @param amount Remaining amount to cover.
    /// @return The over-consumption (change) the caller must re-deposit as a note.
    #[external("private")]
    #[only_self]
    fn recurse_subtract_balance_internal(who: AztecAddress, amount: u128) -> u128 {
        self.internal.__subtract_balance(who, amount, RECURSIVE_MAX_NOTES)
    }

    // ---------------------------------------------------------------------
    // Internal -- Public helpers
    // ---------------------------------------------------------------------

    /// @notice Adds `amount` to `who`'s public balance.
    /// @param who    Account whose public balance is credited.
    /// @param amount Amount to add.
    #[internal("public")]
    fn _increase_pub_balance(who: AztecAddress, amount: u128) {
        let new_balance = self.storage.public_balance.at(who).read() + amount;
        self.storage.public_balance.at(who).write(new_balance);
    }

    /// @notice Subtracts `amount` from `who`'s public balance, reverting if insufficient.
    /// @param who    Account whose public balance is debited.
    /// @param amount Amount to remove.
    #[internal("public")]
    fn _decrease_pub_balance(who: AztecAddress, amount: u128) {
        let balance = self.storage.public_balance.at(who).read();
        assert(balance >= amount, "Not enough balance");
        self.storage.public_balance.at(who).write(balance - amount);
    }

    /// @notice Adds `amount` to the public total supply.
    /// @param amount Amount to add.
    #[internal("public")]
    fn _increase_total_supply(amount: u128) {
        let new_supply = self.storage.total_supply.read() + amount;
        self.storage.total_supply.write(new_supply);
    }

    /// @notice Subtracts `amount` from the public total supply.
    /// @param amount Amount to remove.
    #[internal("public")]
    fn _decrease_total_supply(amount: u128) {
        let new_supply = self.storage.total_supply.read() - amount;
        self.storage.total_supply.write(new_supply);
    }

    /// @notice Spends public allowance unless `owner` and `spender` are the same account.
    /// @param owner   Account that granted the allowance.
    /// @param spender Account spending the allowance.
    /// @param amount  Amount of allowance to consume.
    #[internal("public")]
    fn _spendAllowance(owner:AztecAddress, spender: AztecAddress, amount: u128){
        if !owner.eq(spender) {
            let allowance = self.storage.allowances.at(owner).at(spender).read();
            assert(allowance >= amount, "insufficient allowance");
            let balance = allowance - amount;
            self.storage.allowances.at(owner).at(spender).write(balance);
        }
    }

    // ---------------------------------------------------------------------
    // Internal -- Private helpers
    // ---------------------------------------------------------------------
    
    /// @notice Delivers a new private note of `amount` to `who`.
    /// @param who    Owner of the new private note.
    /// @param amount Value stored in the new note.
    #[internal("private")]
    fn _increase_priv_balance(who: AztecAddress, amount: u128) {
        self.storage.private_balance.at(who).add(amount).deliver(MessageDelivery.ONCHAIN_CONSTRAINED);
    }

    /// @notice Subtracts `amount` from `who`'s private balance and re-deposits the change.
    /// @param who    Owner whose private notes are consumed.
    /// @param amount Amount to remove from the private balance.
    #[internal("private")]
    fn _decrease_private_balance(who: AztecAddress, amount: u128) {
        let change = self.internal.__subtract_balance(who, amount, INITIAL_MAX_NOTES);
        self.storage.private_balance.at(who).add(change).deliver(MessageDelivery.ONCHAIN_CONSTRAINED);
    }

    /// @notice Consumes notes from `who` to cover `amount`, recursing across frames if needed.
    /// @dev    If a frame's `max_notes` budget is exhausted before reaching `amount`,
    ///         the remaining work is delegated to `recurse_subtract_balance_internal`
    ///         (a fresh kernel frame with `RECURSIVE_MAX_NOTES`).
    /// @param who       Owner whose private notes are consumed.
    /// @param amount    Amount to cover.
    /// @param max_notes Maximum notes this frame may consume.
    /// @return The over-consumption (change) the caller must re-deposit as a note.
    #[internal("private")]
    fn __subtract_balance(who: AztecAddress, amount: u128, max_notes: u32) -> u128 {
        let consumed_amount = self.storage.private_balance.at(who).try_sub(amount, max_notes);

        if consumed_amount >= amount {
            consumed_amount - amount
        } else {
            assert(consumed_amount > 0, "balance too low");
            let remaining_amount = amount - consumed_amount;
            self.call_self.recurse_subtract_balance_internal(who, remaining_amount)
        }
    }


    // ---------------------------------------------------------------------
    // Getters -- Public view
    // ---------------------------------------------------------------------
    
    /// @notice Reads `who`'s public balance.
    /// @param who Account whose public balance is read.
    /// @return The account's public token balance.
    #[external("public")]
    #[view]
    fn balance_of_public (who: AztecAddress) -> u128 {
        self.storage.public_balance.at(who).read()
    }

    /// @notice Reads the token's total supply.
    /// @return The current public total supply.
    #[external("public")]
    #[view]
    fn total_supply () -> u128 {
        self.storage.total_supply.read()
    }

    // ---------------------------------------------------------------------
    // Getters -- private view
    // ---------------------------------------------------------------------
    
    /// @notice Reads `who`'s private balance by summing active private notes.
    /// @dev Utility calls run locally and reveal the result only to the caller of the utility function.
    /// @param who Account whose private balance is read.
    /// @return The account's private token balance.
    #[external("utility")]
    unconstrained fn balance_of_private (who: AztecAddress) -> u128 {
        self.storage.private_balance.at(who).balance_of()
    }

    // ---------------------------------------------------------------------
    // Getters -- token metadata
    // ---------------------------------------------------------------------
    
    /// @notice Get token name.
    /// @return The compressed token name.
    #[external("public")]
    #[view]
    fn name () -> FieldCompressedString {
        self.storage.name.read()
    }

    /// @notice Get token symbol.
    /// @return The compressed token symbol.
    #[external("public")]
    #[view]
    fn symbol () -> FieldCompressedString {
        self.storage.symbol.read()
    }

    /// @notice Get token decimals.
    /// @return The number of decimals used by token amounts.
    #[external("public")]
    #[view]
    fn decimal () -> u8 {
        self.storage.decimals.read()
    }
}

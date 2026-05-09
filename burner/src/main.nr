use aztec::macros::aztec;
mod test;

/// @title Burner
/// @notice Helper contract that forwards private burn calls into a configured token contract.
/// @dev The token holder must authorize this contract with authwit before `foo` can burn on their behalf.
#[aztec]
contract Burner {
    use aztec::{
        macros::{functions::{external, initializer}, storage::storage}, 
        protocol::address::AztecAddress,
        state_vars::PublicImmutable
    };
    use token::Token;

    #[storage]
    struct Storage<Context> {
        /// @notice Token contract this burner forwards calls to.
        token: PublicImmutable<AztecAddress, Context>,
    }

    /// @notice Stores the token contract this burner will call.
    /// @param token_contract_address Address of the deployed token contract.
    #[external("public")]
    #[initializer]
    fn constructor(token_contract_address:AztecAddress) {
        self.storage.token.initialize(token_contract_address);
    }

    /// @notice Forwards a private burn request to the configured token.
    /// @dev `from` must have granted authwit for the token's `private_burn` call.
    /// @param from          Holder whose private balance should be burned.
    /// @param amount        Amount to burn.
    /// @param authwit_nonce One-shot authwit nonce used by the token.
    #[external("private")]
    fn foo(from: AztecAddress, amount: u128, authwit_nonce: Field) {
        let token = self.storage.token.read();
        self.call(Token::at(token).private_burn(from, amount, authwit_nonce));
    }
}

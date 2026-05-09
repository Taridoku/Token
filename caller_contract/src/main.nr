use aztec::macros::aztec;

/// @title CallerContract
/// @notice Generic private-call forwarder used by tests to exercise contract-to-contract private calls.
/// @dev Each forwarder accepts a fixed argument array length because Noir arrays are statically sized.
#[aztec]
pub contract CallerContract {
    use aztec::{
        macros::functions::external,
        protocol::{abis::function_selector::FunctionSelector, address::AztecAddress},
    };

    /// @notice Forwards a private call with no encoded arguments.
    /// @param target   Contract receiving the forwarded call.
    /// @param selector Function selector to invoke on the target contract.
    #[external("private")]
    fn forward_private_0(target: AztecAddress, selector: FunctionSelector) {
        let _ = self.context.call_private_function_no_args(target, selector);
    }

    /// @notice Forwards a private call with one encoded argument field.
    /// @param target   Contract receiving the forwarded call.
    /// @param selector Function selector to invoke on the target contract.
    /// @param args     Serialized call arguments.
    #[external("private")]
    fn forward_private_1(target: AztecAddress, selector: FunctionSelector, args: [Field; 1]) {
        let _ = self.context.call_private_function(target, selector, args);
    }

    /// @notice Forwards a private call with two encoded argument fields.
    /// @param target   Contract receiving the forwarded call.
    /// @param selector Function selector to invoke on the target contract.
    /// @param args     Serialized call arguments.
    #[external("private")]
    fn forward_private_2(target: AztecAddress, selector: FunctionSelector, args: [Field; 2]) {
        let _ = self.context.call_private_function(target, selector, args);
    }

    /// @notice Forwards a private call with three encoded argument fields.
    /// @param target   Contract receiving the forwarded call.
    /// @param selector Function selector to invoke on the target contract.
    /// @param args     Serialized call arguments.
    #[external("private")]
    fn forward_private_3(target: AztecAddress, selector: FunctionSelector, args: [Field; 3]) {
        let _ = self.context.call_private_function(target, selector, args);
    }

    /// @notice Forwards a private call with four encoded argument fields.
    /// @param target   Contract receiving the forwarded call.
    /// @param selector Function selector to invoke on the target contract.
    /// @param args     Serialized call arguments.
    #[external("private")]
    fn forward_private_4(target: AztecAddress, selector: FunctionSelector, args: [Field; 4]) {
        let _ = self.context.call_private_function(target, selector, args);
    }

    /// @notice Forwards a private call with four encoded argument fields and returns one field.
    /// @param target   Contract receiving the forwarded call.
    /// @param selector Function selector to invoke on the target contract.
    /// @param args     Serialized call arguments.
    /// @return The first field returned by the target call.
    #[external("private")]
    fn forward_private_4_and_return(
        target: AztecAddress,
        selector: FunctionSelector,
        args: [Field; 4],
    ) -> Field {
        let returns: Field =
            self.context.call_private_function(target, selector, args).get_preimage();
        returns
    }

    /// @notice Forwards a private call with five encoded argument fields.
    /// @param target   Contract receiving the forwarded call.
    /// @param selector Function selector to invoke on the target contract.
    /// @param args     Serialized call arguments.
    #[external("private")]
    fn forward_private_5(target: AztecAddress, selector: FunctionSelector, args: [Field; 5]) {
        let _ = self.context.call_private_function(target, selector, args);
    }

    /// @notice Forwards a private call with six encoded argument fields.
    /// @param target   Contract receiving the forwarded call.
    /// @param selector Function selector to invoke on the target contract.
    /// @param args     Serialized call arguments.
    #[external("private")]
    fn forward_private_6(target: AztecAddress, selector: FunctionSelector, args: [Field; 6]) {
        let _ = self.context.call_private_function(target, selector, args);
    }

    /// @notice Forwards a private call with seven encoded argument fields.
    /// @param target   Contract receiving the forwarded call.
    /// @param selector Function selector to invoke on the target contract.
    /// @param args     Serialized call arguments.
    #[external("private")]
    fn forward_private_7(target: AztecAddress, selector: FunctionSelector, args: [Field; 7]) {
        let _ = self.context.call_private_function(target, selector, args);
    }

    /// @notice Forwards a private call with eight encoded argument fields.
    /// @param target   Contract receiving the forwarded call.
    /// @param selector Function selector to invoke on the target contract.
    /// @param args     Serialized call arguments.
    #[external("private")]
    fn forward_private_8(target: AztecAddress, selector: FunctionSelector, args: [Field; 8]) {
        let _ = self.context.call_private_function(target, selector, args);
    }
}

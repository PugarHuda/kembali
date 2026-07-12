// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title HSPCanonical — canonical HSP v1 Mandate hashing, on-chain.
/// @notice Computes the real HSP `mandateHash` (= paymentId) with the spec-exact nested
///         `Signer(bytes32 profileId,bytes payload)` / `Recipient(uint8 kind,bytes payload)`
///         structs and `uint64 deadline`, per HSP.md §2.4.1 (typehash snapshot in hsp/core).
///         Proven byte-identical to the hsp/core reference SDK (see test/HSPCanonical.t.sol).
///         This is the on-chain counterpart to Kembali's gas-optimized flat mandate — it shows
///         Kembali can produce/verify the *canonical* HSP paymentId on-chain, not just off-chain.
contract HSPCanonical {
    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant SIGNER_TYPEHASH = keccak256("Signer(bytes32 profileId,bytes payload)");
    bytes32 private constant RECIPIENT_TYPEHASH = keccak256("Recipient(uint8 kind,bytes payload)");
    // Referenced structs are appended alphabetically: Recipient before Signer.
    bytes32 private constant MANDATE_TYPEHASH = keccak256(
        "Mandate(bytes32 nonce,Signer signer,bytes32 grantRef,bytes32 requirementRef,Recipient recipient,address token,uint256 amount,uint256 chainId,uint64 deadline,bytes32 settlementBinding,bytes32 requiredCapabilitiesHash)Recipient(uint8 kind,bytes payload)Signer(bytes32 profileId,bytes payload)"
    );

    struct Mandate {
        bytes32 nonce;
        bytes32 signerProfileId;
        bytes signerPayload;
        bytes32 grantRef;
        bytes32 requirementRef;
        uint8 recipientKind;
        bytes recipientPayload;
        address token;
        uint256 amount;
        uint256 chainId;
        uint64 deadline;
        bytes32 settlementBinding;
        bytes32 requiredCapabilitiesHash;
    }

    /// @return the canonical HSP mandateHash (EIP-712 digest) — == hsp/core's paymentId.
    function mandateHash(Mandate calldata m, string calldata name, string calldata version, address verifyingContract)
        external
        pure
        returns (bytes32)
    {
        bytes32 signerHash = keccak256(abi.encode(SIGNER_TYPEHASH, m.signerProfileId, keccak256(m.signerPayload)));
        bytes32 recipientHash =
            keccak256(abi.encode(RECIPIENT_TYPEHASH, uint256(m.recipientKind), keccak256(m.recipientPayload)));
        // split to avoid stack-too-deep; identical bytes for an all-static tuple.
        bytes memory head =
            abi.encode(MANDATE_TYPEHASH, m.nonce, signerHash, m.grantRef, m.requirementRef, recipientHash);
        bytes memory tail =
            abi.encode(m.token, m.amount, m.chainId, m.deadline, m.settlementBinding, m.requiredCapabilitiesHash);
        bytes32 structHash = keccak256(bytes.concat(head, tail));
        bytes32 domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes(version)), m.chainId, verifyingContract)
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

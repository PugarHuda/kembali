// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title HSPCanonical — canonical HSP v1 Mandate hashing + eip712-eoa verification, on-chain.
/// @notice Computes the real HSP `mandateHash` (= paymentId) with the spec-exact nested
///         `Signer(bytes32 profileId,bytes payload)` / `Recipient(uint8 kind,bytes payload)`
///         structs and `uint64 deadline` (HSP.md §2.4.1), AND verifies the `eip712-eoa.v1`
///         SignerProfile (HSP.md §4.1.6) on-chain: 65-byte r||s||v proof, v in {27,28}, low-s,
///         recovered address == abi.decode(signer.payload). Proven byte-identical to the hsp/core
///         reference SDK (hashing: test + 6-vector differential; verify: mirrors eip712EoaSigner.verify).
contract HSPCanonical {
    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant SIGNER_TYPEHASH = keccak256("Signer(bytes32 profileId,bytes payload)");
    bytes32 private constant RECIPIENT_TYPEHASH = keccak256("Recipient(uint8 kind,bytes payload)");
    bytes32 private constant MANDATE_TYPEHASH = keccak256(
        "Mandate(bytes32 nonce,Signer signer,bytes32 grantRef,bytes32 requirementRef,Recipient recipient,address token,uint256 amount,uint256 chainId,uint64 deadline,bytes32 settlementBinding,bytes32 requiredCapabilitiesHash)Recipient(uint8 kind,bytes payload)Signer(bytes32 profileId,bytes payload)"
    );
    bytes32 private constant EIP712_EOA = keccak256("eip712-eoa.v1");
    bytes32 private constant RECEIPT_TYPEHASH = keccak256(
        "ReceiptPreimage(bytes32 mandateHash,bytes32 adapterId,bytes32 adapterInstanceKey,uint64 seq,uint8 outcome,uint64 settledAt,bytes32 proofSchemaId,bytes32 adapterProofHash)"
    );
    bytes32 private constant GRANT_TYPEHASH = keccak256(
        "DelegationGrant(Signer principal,Signer agent,bytes32 onchainPermissionRef,bytes32[] payerRequiredCaps,bytes32[] payerAllowedCaps,uint64 notBefore,uint64 expiry,bytes32 nonce)Signer(bytes32 profileId,bytes payload)"
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

    // HSP Receipt (HSP.md §2.4.2) — an adapter's attestation of observed settlement.
    struct Receipt {
        bytes32 mandateHash;
        bytes32 adapterId;
        bytes32 adapterInstanceKey;
        uint64 seq;
        uint8 outcome;
        uint64 settledAt;
        bytes32 proofSchemaId;
        bytes adapterProof; // hashed on-chain
    }

    // HSP DelegationGrant (HSP.md §2.4.1a) — the Principal authorizes an Agent (standing agent budgets).
    struct Grant {
        bytes32 principalProfileId;
        bytes principalPayload;
        bytes32 agentProfileId;
        bytes agentPayload;
        bytes32 onchainPermissionRef;
        bytes32[] payerRequiredCaps;
        bytes32[] payerAllowedCaps;
        uint64 notBefore;
        uint64 expiry;
        bytes32 nonce;
    }

    /// @return the canonical HSP mandateHash (EIP-712 digest) — == hsp/core's paymentId.
    function mandateHash(Mandate calldata m, string calldata name, string calldata version, address verifyingContract)
        external
        pure
        returns (bytes32)
    {
        return _mandateHash(m, name, version, verifyingContract);
    }

    function _domain(string calldata name, string calldata version, uint256 chainId, address vc)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes(version)), chainId, vc));
    }

    /// @return the canonical HSP receiptHash (EIP-712) — == hsp/core's receiptHash (an adapter signs it).
    function receiptHash(Receipt calldata r, string calldata name, string calldata version, uint256 chainId, address vc)
        external
        pure
        returns (bytes32)
    {
        bytes memory head = abi.encode(RECEIPT_TYPEHASH, r.mandateHash, r.adapterId, r.adapterInstanceKey, r.seq);
        bytes memory tail = abi.encode(r.outcome, r.settledAt, r.proofSchemaId, keccak256(r.adapterProof));
        bytes32 structHash = keccak256(bytes.concat(head, tail));
        return keccak256(abi.encodePacked("\x19\x01", _domain(name, version, chainId, vc), structHash));
    }

    /// @return the canonical HSP grantHash (EIP-712) — == hsp/core's grantHash (the Principal signs it).
    function grantHash(Grant calldata g, string calldata name, string calldata version, uint256 chainId, address vc)
        external
        pure
        returns (bytes32)
    {
        bytes32 principalHash =
            keccak256(abi.encode(SIGNER_TYPEHASH, g.principalProfileId, keccak256(g.principalPayload)));
        bytes32 agentHash = keccak256(abi.encode(SIGNER_TYPEHASH, g.agentProfileId, keccak256(g.agentPayload)));
        bytes memory head = abi.encode(
            GRANT_TYPEHASH,
            principalHash,
            agentHash,
            g.onchainPermissionRef,
            keccak256(abi.encodePacked(g.payerRequiredCaps)),
            keccak256(abi.encodePacked(g.payerAllowedCaps))
        );
        bytes memory tail = abi.encode(g.notBefore, g.expiry, g.nonce);
        bytes32 structHash = keccak256(bytes.concat(head, tail));
        return keccak256(abi.encodePacked("\x19\x01", _domain(name, version, chainId, vc), structHash));
    }

    /// @notice Full eip712-eoa.v1 mandate verification, mirroring hsp/core's SignerProfile.verify.
    /// @return granted true iff the proof is a valid EOA signature over the canonical mandateHash.
    /// @return recovered the recovered signer address (address(0) on failure).
    function verify(
        Mandate calldata m,
        bytes calldata proof,
        string calldata name,
        string calldata version,
        address verifyingContract
    ) external pure returns (bool granted, address recovered) {
        if (m.signerProfileId != EIP712_EOA) return (false, address(0)); // this profile only
        if (m.signerPayload.length != 32) return (false, address(0)); // abi.encode(address)
        address claimed = abi.decode(m.signerPayload, (address));
        bytes32 digest = _mandateHash(m, name, version, verifyingContract);
        recovered = _recover(digest, proof);
        granted = recovered != address(0) && recovered == claimed;
    }

    function _mandateHash(Mandate calldata m, string calldata name, string calldata version, address verifyingContract)
        internal
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

    /// §4.1.6 strictness: 65-byte r||s||v, v in {27,28}, low-s (EIP-2), non-zero recovery.
    function _recover(bytes32 digest, bytes calldata sig) internal pure returns (address) {
        if (sig.length != 65) return address(0);
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 0x20))
            v := byte(0, calldataload(add(sig.offset, 0x40)))
        }
        if (v < 27) v += 27;
        if (v != 27 && v != 28) return address(0);
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) return address(0);
        return ecrecover(digest, v, r, s);
    }
}

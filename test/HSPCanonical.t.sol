// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HSPCanonical} from "../src/HSPCanonical.sol";

/// Proves the on-chain canonical mandateHash is BYTE-IDENTICAL to the hsp/core reference SDK.
/// Target produced by `hsp/canon.mts` (real hsp/core mandateHash for the same fixed inputs).
contract HSPCanonicalTest is Test {
    function test_MatchesReferenceSDK() public {
        HSPCanonical hsp = new HSPCanonical();
        address SIGNER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        address KEMBALI = 0xDea6Da93265871d828B20cace2BADd5F5e70209d;
        address USDC = 0x481fE34ed995603abdB9998b7eCc8811e2707d87;

        HSPCanonical.Mandate memory m = HSPCanonical.Mandate({
            nonce: keccak256("kembali-canon-1"),
            signerProfileId: keccak256("eip712-eoa.v1"),
            signerPayload: abi.encode(SIGNER),
            grantRef: bytes32(0),
            requirementRef: bytes32(0),
            recipientKind: 0,
            recipientPayload: abi.encode(KEMBALI),
            token: USDC,
            amount: 100000000,
            chainId: 177,
            deadline: 2000000000,
            settlementBinding: bytes32(0),
            requiredCapabilitiesHash: bytes32(0)
        });

        bytes32 got = hsp.mandateHash(m, "HSP", "1", KEMBALI);
        // reference: hsp/core mandateHash(...) for the exact same inputs
        assertEq(got, 0x623569a794a14af48f847d9a9dd64d92166494e160b14caccd4818524cb3933f, "on-chain != hsp/core");
    }

    function test_Verify_AcceptsValidSig_RejectsWrong() public {
        HSPCanonical hsp = new HSPCanonical();
        uint256 pk = 0xB0B;
        address signer = vm.addr(pk);
        HSPCanonical.Mandate memory m = HSPCanonical.Mandate({
            nonce: keccak256("verify-1"),
            signerProfileId: keccak256("eip712-eoa.v1"),
            signerPayload: abi.encode(signer),
            grantRef: bytes32(0),
            requirementRef: bytes32(0),
            recipientKind: 0,
            recipientPayload: abi.encode(address(0xCAFE)),
            token: address(0xDEAD),
            amount: 5_000000,
            chainId: 177,
            deadline: 2000000000,
            settlementBinding: bytes32(0),
            requiredCapabilitiesHash: bytes32(0)
        });
        bytes32 digest = hsp.mandateHash(m, "HSP", "1", address(this));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        (bool granted, address rec) = hsp.verify(m, abi.encodePacked(r, s, v), "HSP", "1", address(this));
        assertTrue(granted, "valid eip712-eoa proof must be granted");
        assertEq(rec, signer, "recovered == signer");

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(uint256(0xBAD), digest); // wrong key
        (bool g2,) = hsp.verify(m, abi.encodePacked(r2, s2, v2), "HSP", "1", address(this));
        assertFalse(g2, "wrong signer must be rejected");
    }
}

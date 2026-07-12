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

    function test_ReceiptHash_MatchesSDK() public {
        HSPCanonical hsp = new HSPCanonical();
        HSPCanonical.Receipt memory r = HSPCanonical.Receipt({
            mandateHash: keccak256("m"),
            adapterId: keccak256("adapter"),
            adapterInstanceKey: keccak256("instance"),
            seq: 1,
            outcome: 0,
            settledAt: 1700000000,
            proofSchemaId: keccak256("schema"),
            adapterProof: hex"abcd"
        });
        assertEq(
            hsp.receiptHash(r, "HSP", "1", 177, 0xDea6Da93265871d828B20cace2BADd5F5e70209d),
            0x050867a0c6e4c755f39a9fc076ff0dcd4152b4131d3a60003e103d28bb2bcad8,
            "receiptHash != hsp/core"
        );
    }

    function test_GrantHash_MatchesSDK() public {
        HSPCanonical hsp = new HSPCanonical();
        bytes32[] memory req = new bytes32[](1);
        req[0] = keccak256("attests:kyc:v1");
        bytes32[] memory allowed = new bytes32[](2);
        allowed[0] = keccak256("attests:kyc:v1");
        allowed[1] = keccak256("attests:sanctions:v1");
        HSPCanonical.Grant memory g = HSPCanonical.Grant({
            principalProfileId: keccak256("erc1271.v1"),
            principalPayload: abi.encode(address(0x1111111111111111111111111111111111111111)),
            agentProfileId: keccak256("eip712-eoa.v1"),
            agentPayload: abi.encode(address(0x2222222222222222222222222222222222222222)),
            onchainPermissionRef: keccak256("perm"),
            payerRequiredCaps: req,
            payerAllowedCaps: allowed,
            notBefore: 1000,
            expiry: 2000000000,
            nonce: keccak256("gnonce")
        });
        assertEq(
            hsp.grantHash(g, "HSP", "1", 177, 0xDea6Da93265871d828B20cace2BADd5F5e70209d),
            0xdd10729bb20cf74a75f1ca0a0608e388fc01cba07625b0a40fa4f44b2ebcc597,
            "grantHash != hsp/core"
        );
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

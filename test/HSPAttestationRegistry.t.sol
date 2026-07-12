// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HSPAttestationRegistry} from "../src/HSPAttestationRegistry.sol";

contract HSPAttestationRegistryTest is Test {
    HSPAttestationRegistry reg;
    address issuer = address(0x155);
    address alice = address(0xA11CE);
    bytes32 KYC;
    bytes32 SANC; // cached so the getter call doesn't consume vm.prank/expectRevert

    function setUp() public {
        reg = new HSPAttestationRegistry(issuer);
        KYC = reg.KYC();
        SANC = reg.SANCTIONS();
    }

    function test_AttestAndCompliant() public {
        bytes32[] memory req = new bytes32[](2);
        req[0] = KYC;
        req[1] = SANC;
        assertFalse(reg.compliant(alice, req), "not attested yet");

        vm.startPrank(issuer);
        reg.attest(alice, KYC, uint64(block.timestamp + 365 days));
        assertFalse(reg.compliant(alice, req), "only KYC so far");
        reg.attest(alice, SANC, uint64(block.timestamp + 365 days));
        vm.stopPrank();

        assertTrue(reg.has(alice, KYC));
        assertTrue(reg.compliant(alice, req), "both caps => compliant");
    }

    function test_OnlyIssuer() public {
        vm.expectRevert("ONLY_ISSUER");
        reg.attest(alice, KYC, uint64(block.timestamp + 1 days));
    }

    function test_Expiry() public {
        vm.prank(issuer);
        reg.attest(alice, KYC, uint64(block.timestamp + 1 days));
        assertTrue(reg.has(alice, KYC));
        vm.warp(block.timestamp + 2 days);
        assertFalse(reg.has(alice, KYC), "expired");
    }

    function test_Revoke() public {
        vm.startPrank(issuer);
        reg.attest(alice, KYC, uint64(block.timestamp + 1 days));
        assertTrue(reg.has(alice, KYC));
        reg.revoke(alice, KYC);
        vm.stopPrank();
        assertFalse(reg.has(alice, KYC), "revoked");
    }

    function test_BadExpiryRejected() public {
        vm.prank(issuer);
        vm.expectRevert("BAD_EXPIRY");
        reg.attest(alice, KYC, uint64(block.timestamp)); // not in the future
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Kembali} from "../src/Kembali.sol";
import {HSPAttestationRegistry} from "../src/HSPAttestationRegistry.sol";
import {CompliantEscrow} from "../src/CompliantEscrow.sol";
import {DemoUSDC} from "../src/mocks/DemoUSDC.sol";
import {DemoNFT} from "../src/mocks/DemoNFT.sol";

/// On-chain compliance gate: openCompliant() opens the real reversible escrow ONLY if the payer
/// holds the required HSP attestations — enforced by `require`, not off-chain JS.
contract CompliantEscrowTest is Test {
    Kembali k;
    HSPAttestationRegistry reg;
    CompliantEscrow ce;
    DemoUSDC usd;
    DemoNFT nft;

    uint256 constant PK = 0xA11CE;
    address payer;
    address merchant = address(0xB0B);
    uint256 constant AMT = 100_000000;
    uint64 constant WIN = 1 days;
    bytes32 KYC;
    bytes32 SANC;
    uint256 tid;

    function setUp() public {
        k = new Kembali();
        reg = new HSPAttestationRegistry(address(this)); // this test is the issuer
        ce = new CompliantEscrow(address(k), address(reg));
        usd = new DemoUSDC();
        nft = new DemoNFT();
        payer = vm.addr(PK);
        usd.mint(payer, AMT);
        tid = nft.mint(merchant);
        vm.prank(merchant);
        nft.setApprovalForAll(address(k), true);
        KYC = reg.KYC();
        SANC = reg.SANCTIONS();
    }

    function _build() internal view returns (Kembali.Mandate memory m, bytes memory sig) {
        m = Kembali.Mandate({
            nonce: keccak256("c1"), signer: payer, grantRef: bytes32(0), requirementRef: bytes32(0),
            recipient: address(k), token: address(usd), amount: AMT, chainId: block.chainid,
            deadline: block.timestamp + 1 days,
            settlementBinding: keccak256(abi.encode(merchant, address(nft), tid, Kembali.Kind.ERC721, WIN)),
            requiredCapabilitiesHash: keccak256("")
        });
        bytes32 id = k.hashMandate(m);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PK, id);
        sig = abi.encodePacked(r, s, v);
    }

    function _caps() internal view returns (bytes32[] memory c) {
        c = new bytes32[](2);
        c[0] = KYC;
        c[1] = SANC;
    }

    // the single guarded external call (no prank/approve here — the caller sets those)
    function _oc(Kembali.Mandate memory m, bytes memory sig, bytes32[] memory caps) internal returns (bytes32) {
        return ce.openCompliant(m, sig, merchant, address(nft), tid, Kembali.Kind.ERC721, WIN, caps);
    }

    function _attest(bytes32 cap, uint64 exp) internal { reg.attest(payer, cap, exp); }

    // uncompliant payer is rejected ON-CHAIN before any funds move
    function test_Uncompliant_Reverts() public {
        (Kembali.Mandate memory m, bytes memory sig) = _build();
        vm.prank(payer);
        vm.expectRevert("NOT_COMPLIANT");
        _oc(m, sig, _caps());
    }

    // partial attestation (KYC only, missing sanctions) still rejected
    function test_PartialCaps_Reverts() public {
        _attest(KYC, uint64(block.timestamp + 365 days));
        (Kembali.Mandate memory m, bytes memory sig) = _build();
        vm.prank(payer);
        vm.expectRevert("NOT_COMPLIANT");
        _oc(m, sig, _caps());
    }

    // fully attested payer opens the real reversible escrow, on-chain
    function test_Compliant_Opens() public {
        _attest(KYC, uint64(block.timestamp + 365 days));
        _attest(SANC, uint64(block.timestamp + 365 days));
        (Kembali.Mandate memory m, bytes memory sig) = _build();
        vm.prank(payer);
        usd.approve(address(k), AMT);
        vm.prank(payer);
        bytes32 id = _oc(m, sig, _caps());
        (,,,,,,,, Kembali.Status status) = k.payments(id);
        assertEq(uint8(status), uint8(Kembali.Status.HELD)); // real escrow is HELD
        assertEq(usd.balanceOf(address(k)), AMT);            // funds really pulled into escrow
    }

    // expired attestation is not compliant
    function test_ExpiredAttestation_Reverts() public {
        _attest(KYC, uint64(block.timestamp + 100));
        _attest(SANC, uint64(block.timestamp + 100));
        vm.warp(block.timestamp + 200); // both expire
        (Kembali.Mandate memory m, bytes memory sig) = _build();
        vm.prank(payer);
        vm.expectRevert("NOT_COMPLIANT");
        _oc(m, sig, _caps());
    }

    // empty caps is a misuse — a "compliant" open must require at least one capability
    function test_NoCaps_Reverts() public {
        _attest(KYC, uint64(block.timestamp + 365 days));
        (Kembali.Mandate memory m, bytes memory sig) = _build();
        bytes32[] memory none = new bytes32[](0);
        vm.prank(payer);
        vm.expectRevert("NO_CAPS");
        _oc(m, sig, none);
    }

    // revocation flips a previously-compliant payer back to blocked
    function test_RevokedAfterAttest_Reverts() public {
        _attest(KYC, uint64(block.timestamp + 365 days));
        _attest(SANC, uint64(block.timestamp + 365 days));
        reg.revoke(payer, SANC);
        (Kembali.Mandate memory m, bytes memory sig) = _build();
        vm.prank(payer);
        vm.expectRevert("NOT_COMPLIANT");
        _oc(m, sig, _caps());
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Kembali} from "./Kembali.sol";

/// @title CompliantEscrow — on-chain compliance gate in front of the reversible Kembali escrow.
/// @notice The regulated-DeFi path: a payment only opens if the payer holds the required HSP
///         attestations (KYC / sanctions) in HSPAttestationRegistry — checked ON-CHAIN, then the
///         real, audited Kembali escrow is opened. This is the actual "compliant + reversible, all
///         on-chain" flow: compliance is enforced by `require`, not by an off-chain JS branch.
/// @dev    Reuses the deployed, immutable Kembali (which itself only does public payments) rather than
///         forking it. The payer approves Kembali exactly as normal; open() pulls funds from the
///         mandate signer regardless of who submits, so routing through this gate changes nothing
///         about custody — it only adds the attestation check.
interface IRegistry {
    function compliant(address subject, bytes32[] calldata requiredCaps) external view returns (bool);
}

contract CompliantEscrow {
    Kembali public immutable kembali;
    IRegistry public immutable registry;

    event CompliantOpened(bytes32 indexed id, address indexed payer, uint256 caps);

    constructor(address _kembali, address _registry) {
        require(_kembali != address(0) && _registry != address(0), "ZERO_ADDR");
        kembali = Kembali(_kembali);
        registry = IRegistry(_registry);
    }

    /// @notice Open a reversible escrow only if the payer (mandate signer) is compliant on-chain.
    /// @param requiredCaps the HSP capability ids the payer must hold (e.g. KYC, SANCTIONS).
    function openCompliant(
        Kembali.Mandate calldata m,
        bytes calldata signature,
        address merchant,
        address asset,
        uint256 item,
        Kembali.Kind kind,
        uint64 window,
        bytes32[] calldata requiredCaps
    ) external returns (bytes32 id) {
        require(requiredCaps.length > 0, "NO_CAPS");                          // a compliant open must require something
        require(registry.compliant(m.signer, requiredCaps), "NOT_COMPLIANT"); // <-- on-chain compliance gate
        id = kembali.open(m, signature, merchant, asset, item, kind, window);
        emit CompliantOpened(id, m.signer, requiredCaps.length);
    }
}

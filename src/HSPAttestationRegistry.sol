// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title HSPAttestationRegistry — the compliance path for Kembali (HSP `attests:*` capabilities).
/// @notice A trusted issuer attests HSP capabilities (e.g. `attests:kyc:v1`, `attests:sanctions:v1`)
///         to subjects, with expiry. Compliant Kembali payments (non-empty requiredCapabilitiesHash)
///         can be gated on `compliant(subject, requiredCaps)` — fitting HashKey Chain's regulated-DeFi
///         thesis. Additive: does not touch the deployed Kembali/HSPCanonical.
contract HSPAttestationRegistry {
    /// Canonical HSP capability ids (verb:object:version), keccak256 of the string.
    bytes32 public constant KYC = keccak256("attests:kyc:v1");
    bytes32 public constant SANCTIONS = keccak256("attests:sanctions:v1");

    address public immutable issuer;
    /// subject => capability => unix expiry (0 = not attested).
    mapping(address => mapping(bytes32 => uint64)) public expiryOf;

    event Attested(address indexed subject, bytes32 indexed capability, uint64 expiry);
    event Revoked(address indexed subject, bytes32 indexed capability);

    constructor(address _issuer) {
        require(_issuer != address(0), "ZERO_ISSUER");
        issuer = _issuer;
    }

    modifier onlyIssuer() {
        require(msg.sender == issuer, "ONLY_ISSUER");
        _;
    }

    function attest(address subject, bytes32 capability, uint64 expiry) external onlyIssuer {
        require(expiry > block.timestamp, "BAD_EXPIRY");
        expiryOf[subject][capability] = expiry;
        emit Attested(subject, capability, expiry);
    }

    function revoke(address subject, bytes32 capability) external onlyIssuer {
        expiryOf[subject][capability] = 0;
        emit Revoked(subject, capability);
    }

    /// @return true iff `subject` holds a non-expired attestation for `capability`.
    function has(address subject, bytes32 capability) public view returns (bool) {
        uint64 e = expiryOf[subject][capability];
        return e != 0 && e >= block.timestamp;
    }

    /// @return true iff `subject` holds every required capability (non-expired).
    function compliant(address subject, bytes32[] calldata requiredCaps) external view returns (bool) {
        for (uint256 i; i < requiredCaps.length; i++) {
            if (!has(subject, requiredCaps[i])) return false;
        }
        return true;
    }
}

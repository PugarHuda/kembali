// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Mintable 6-decimal stand-in for USDC.e — lets you demo the full flow on mainnet 177
/// without spending real stablecoin (only gas). Production: use real USDC.e.
contract DemoUSDC {
    string public name = "Kembali Demo USD";
    string public symbol = "kUSD";
    uint8 public constant decimals = 6;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address to, uint256 a) external returns (bool) { balanceOf[msg.sender] -= a; balanceOf[to] += a; return true; }
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        allowance[f][msg.sender] -= a; balanceOf[f] -= a; balanceOf[t] += a; return true;
    }
}

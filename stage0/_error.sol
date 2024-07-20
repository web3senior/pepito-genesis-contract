// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error Unauthorized();
error PriceNotMet(uint256 councilMintPrice,uint256 publicMintPrice, uint256 amount);
error SupplyingLimitExceeded(uint256 totalSupply, uint256 maxSupply);
error NotUniqueAddress(address sender);
error TeamMintExceeded(uint256 counter, uint256);
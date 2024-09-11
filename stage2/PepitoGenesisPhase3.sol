// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import {_LSP4_TOKEN_TYPE_TOKEN, _LSP4_TOKEN_TYPE_COLLECTION, _LSP4_METADATA_KEY} from "@lukso/lsp4-contracts/contracts/LSP4Constants.sol";
import {ILSP8IdentifiableDigitalAsset as ILSP8} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/ILSP8IdentifiableDigitalAsset.sol";
import {ILSP7DigitalAsset as ILSP7} from "@lukso/lsp-smart-contracts/contracts/LSP7DigitalAsset/ILSP7DigitalAsset.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import "./_event.sol";
import "./_error.sol";
import {PEPITO_COIN, CONTRACT_STAGE1} from "./_constant.sol";
import "./_pausable.sol";

/// @title Pepito Genesis 🐸 => 📺 => 📺 => 👤
/// @author Aratta Labs
/// @notice Pepito Genesis stage 1-2
/// @dev You will find the deployed contract addresses in the repo
/// @custom:security-contact atenyun@gmail.com
contract PepitoGenesis is LSP8IdentifiableDigitalAsset("Pepito - Metamorphosis", "PEPH", msg.sender, _LSP4_TOKEN_TYPE_COLLECTION, _LSP4_TOKEN_TYPE_TOKEN), Pausable {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIdCounter;
    mapping(string => uint256) public price;

    ILSP8 GENESIS_CONTRACT_STAGE1 = ILSP8(CONTRACT_STAGE1);

    struct MetamorphosisPool {
        address sender;
        bytes32 tokenId;
        uint256 dt;
    }

    MetamorphosisPool[] public metamorphosisPool;

    mapping(string => bytes) public rawMetadata;

    constructor() {
        price["metamorphosis"] = 4000 ether;
        // Initial metadata
        rawMetadata["Metamorphosis"] = unicode'{"LSP4Metadata":{"name":"Pepito - Metamorphosis","description":"","links":[],"attributes":[],"icon":[],"backgroundImage":[],"assets":[],"images":[]}}';
    }

    function getMetadata(string memory _name) public view returns (bytes memory) {
        bytes memory verfiableURI = bytes.concat(hex"00006f357c6a0020", keccak256(rawMetadata[_name]), abi.encodePacked("data:application/json;base64,", Base64.encode(rawMetadata[_name])));
        return verfiableURI;
    }

    /// @notice Update the mint price
    function updatePrice(uint256 _price) public onlyOwner {
        price["metamorphosis"] = _price;

        // Log price updated
        emit PriceUpdated( _price, block.timestamp);
    }
    
    ///@notice Update metadata
    function updateMetadata(string memory _name, bytes memory _metadata) public onlyOwner {
        rawMetadata[_name] = _metadata;
        emit metadataChanged(_metadata);
    }

    ///@notice hatchlingEvolve
    function metamorphosisEvolve(bytes32 _tokenId) public whenNotPaused returns (bytes32) {
        if (GENESIS_CONTRACT_STAGE1.tokenOwnerOf(_tokenId) != _msgSender()) revert Unauthorized();

        // Burn the entered token id by sending to address(1) - Metamorphosis 🐸
        GENESIS_CONTRACT_STAGE1.transfer(_msgSender(), address(1), _tokenId, true, "");

        // Burn token
        ILSP7(PEPITO_COIN).transfer(_msgSender(), address(1), price["metamorphosis"], true, "");

        // Mint a new token - Metamorphosis
        _tokenIdCounter.increment();
        bytes32 newTokenId = bytes32(_tokenIdCounter.current());
        _mint({to: _msgSender(), tokenId: newTokenId, force: true, data: ""});

        // Set token's metadata
        _setDataForTokenId(newTokenId, _LSP4_METADATA_KEY, getMetadata("Metamorphosis"));

        // Add user to the evolution pool
        metamorphosisPool.push(MetamorphosisPool(_msgSender(), _tokenId, block.timestamp));

        // Return the last id
        return newTokenId;
    }

    function getTokenOperator(bytes32 _tokenId) public view returns (address[] memory) {
        return GENESIS_CONTRACT_STAGE1.getOperatorsOf(_tokenId);
    }

    ///@notice Withdraw the balance from this contract to the owner's address
    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = owner().call{value: amount}("");
        require(success, "Failed");
    }

    ///@notice Transfer balance from this contract to input address
    function transferBalance(address payable _to, uint256 _amount) public onlyOwner {
        // Note that "to" is declared as payable
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Failed");
    }

    /// @notice Return the balance of this contract
    function getBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    /// @notice Pause mint
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Unpause mint
    function unpause() public onlyOwner {
        _unpause();
    }
}

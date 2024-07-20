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
import {PEPITO_COIN, CONTRACT_STAGE0} from "./_constant.sol";
import "./_pausable.sol";

/// @title Pepito Genesis 🐸 => 📺 => 📺 => 👤
/// @author Aratta Labs
/// @notice Pepito Genesis stage 1-2
/// @dev You will find the deployed contract addresses in the repo
/// @custom:security-contact atenyun@gmail.com
contract PepitoGenesis is LSP8IdentifiableDigitalAsset("Pepito - Hatchling", "PEPH", msg.sender, _LSP4_TOKEN_TYPE_COLLECTION, _LSP4_TOKEN_TYPE_TOKEN), Pausable {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIdCounter;

    ILSP8 GENESIS_CONTRACT_STAGE0 = ILSP8(CONTRACT_STAGE0);

    bool public evolve = false;
    mapping(string => uint256) public price;

    struct HatchlingPool {
        address sender;
        bytes32 tokenId;
        uint256 dt;
    }

    HatchlingPool[] public hatchlingPool;

    struct MetamorphosisPool {
        address sender;
        bytes32 tokenId;
        uint256 dt;
    }

    MetamorphosisPool[] public metamorphosisPool;

    mapping(string => bytes) public rawMetadata;

    constructor() {
        price["hatchling_evolution"] = 0;
        price["metamorphosis_evolution"] = 6000;

        // Initial metadata
        rawMetadata["Hatchling"] = unicode'{"LSP4Metadata":{"name":"Pepito - Hatchling","description":"","links":[],"attributes":[],"icon":[],"backgroundImage":[],"assets":[],"images":[]}}';
        rawMetadata["Metamorphosis"] = unicode'{"LSP4Metadata":{"name":"Pepito - Metamorphosis","description":"","links":[],"attributes":[],"icon":[],"backgroundImage":[],"assets":[],"images":[]}}';
    }

    function getMetadata(string memory _name) public view returns (bytes memory) {
        bytes memory verfiableURI = bytes.concat(hex"00006f357c6a0020", keccak256(rawMetadata[_name]), abi.encodePacked("data:application/json;base64,", Base64.encode(rawMetadata[_name])));
        return verfiableURI;
    }

    ///@notice Update metadata
    function updateMetadata(string memory _name, bytes memory _metadata) public onlyOwner {
        rawMetadata[_name] = _metadata;

        if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked("Hatchling"))) {
            if (hatchlingPool.length > 0) {
                for (uint256 i = 0; i < hatchlingPool.length; i++) _setDataForTokenId(hatchlingPool[i].tokenId, _LSP4_METADATA_KEY, getMetadata(_name));
                emit metadataChanged(_metadata);
            }
        } else {
            if (metamorphosisPool.length > 0) {
                for (uint256 i = 0; i < metamorphosisPool.length; i++) _setDataForTokenId(metamorphosisPool[i].tokenId, _LSP4_METADATA_KEY, getMetadata(_name));
                emit metadataChanged(_metadata);
            }
        }
    }

    /// @notice Update the mint price
    function updatePrice(uint256 _hatchlingPrice, uint256 _metamorphosisPrice) public onlyOwner {
        price["hatchling_evolution"] = _hatchlingPrice;
        price["metamorphosis_evolution"] = _metamorphosisPrice;

        // Log price updated
        emit PriceUpdated(block.timestamp, _hatchlingPrice, _metamorphosisPrice);
    }

    ///@notice hatchlingEvolve
    function hatchlingEvolve(bytes32[] memory _tokenIds) public whenNotPaused returns (bytes32) {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (GENESIS_CONTRACT_STAGE0.tokenOwnerOf(_tokenIds[i]) != _msgSender()) revert Unauthorized();

            // Burn the entered token id by sending to address(1) - Spawn 🐸
            GENESIS_CONTRACT_STAGE0.transfer(_msgSender(), address(1), _tokenIds[i], true, "");

            // Mint a token from the new collection - Hatchling 🐣
            _tokenIdCounter.increment();
            bytes32 _tokenId = bytes32(_tokenIdCounter.current());
            _mint({to: _msgSender(), tokenId: _tokenId, force: true, data: ""});

            // Set token's metadata
            _setDataForTokenId(_tokenId, _LSP4_METADATA_KEY, getMetadata("Hatchling"));

            // Add user to the evolution pool
            hatchlingPool.push(HatchlingPool(_msgSender(), _tokenId, block.timestamp));
        }

        // Return the last id
        return bytes32(_tokenIdCounter.current());
    }

    ///@notice metamorphosisEvolve
    function metamorphosisEvolve(bytes32[] memory _tokenIds) public payable whenNotPaused returns (bytes32) {
        require(evolve, "This stage is not active yet.");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (GENESIS_CONTRACT_STAGE0.tokenOwnerOf(_tokenIds[i]) != _msgSender()) revert Unauthorized();

            // Authorize this contract as opertor of the LSP7
            //ILSP7(PEPITO_COIN).authorizeOperator(address(this), 6000, "");
            ILSP7(PEPITO_COIN).transfer(_msgSender(), address(1), price["metamorphosis_evolution"], true, "");

            // Set LSP8 metadata
            _setDataForTokenId(_tokenIds[i], _LSP4_METADATA_KEY, getMetadata("Metamorphosis"));

            // Add user to the evolution pool
            // TODO: add if hasn't evolved/ added before
            metamorphosisPool.push(MetamorphosisPool(_msgSender(), _tokenIds[i], block.timestamp));
        }

        // Return the last id
        return bytes32(_tokenIdCounter.current());
    }

    function getTokenOperator(bytes32 _tokenId) public view returns (address[] memory) {
        return GENESIS_CONTRACT_STAGE0.getOperatorsOf(_tokenId);
    }

    function toggleEvolve() public onlyOwner returns (bool) {
        evolve = !evolve;
        return evolve;
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

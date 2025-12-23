// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC721, IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title LighterTicket
 * @dev ERC721 NFT contract with metadata support, enumeration, and access control.
 * Designed to work with TokenBound Accounts (ERC-6551) for each token.
 */
contract LighterTicket is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    using Strings for uint256;

    // Base URI for token metadata
    string private _baseTokenUri;
    
    // Token counter for minting
    uint256 private _tokenIdCounter;

    // Events
    event TokenMinted(address indexed to, uint256 indexed tokenId, bytes32 nostrPubKey);
    event TokenBurned(uint256 indexed tokenId, string hexNostrPubKey);
    event BaseURIUpdated(string newBaseURI);

    /**
     * @dev Constructor to initialize the NFT collection
     * @param name_ Name of the NFT collection
     * @param symbol_ Symbol of the NFT collection
     * @param baseUri_ Base URI for token metadata
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseUri_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        _baseTokenUri = baseUri_;
        _tokenIdCounter = 1; // Start token IDs from 1
    }

    // /**
    //  * @dev Mint a single NFT to an address
    //  * @param to Address to mint the NFT to
    //  * @return tokenId The ID of the minted token
    //  */
    // function mint(address to) external onlyOwner returns (uint256) {
    //     uint256 tokenId = _tokenIdCounter;
    //     _tokenIdCounter++;
        
    //     _safeMint(to, tokenId);
        
    //     emit TokenMinted(to, tokenId, tokenURI(tokenId));
    //     return tokenId;
    // }

    /**
     * @dev Mint a single NFT with custom metadata URI
     * @param to Address to mint the NFT to
     * @param nostrPubKey Custom metadata URI for this token
     * @return tokenId The ID of the minted token
     */
    function mintWithURI(address to, bytes32 nostrPubKey) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        string memory metadataURI = LibString.toHexString(uint256(nostrPubKey));
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, metadataURI);
        
        emit TokenMinted(to, tokenId, nostrPubKey);
        return tokenId;
    }

    function burn(uint256 tokenId) external onlyOwner returns (string memory strNostrPubKey) {
        strNostrPubKey = tokenURI(tokenId);
        _burn(tokenId);
        emit TokenBurned(tokenId, strNostrPubKey);
    }

    /**
     * @dev Update the base URI for all tokens
     * @param newBaseURI New base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseTokenUri = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @dev Get the base URI
     * @return Base URI string
     */
    function baseURI() external view returns (string memory) {
        return _baseTokenUri;
    }

    /**
     * @dev Get the current token ID counter (next token to be minted)
     * @return Current counter value
     */
    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @dev Get all token IDs owned by an address
     * @param owner Address to query
     * @return Array of token IDs
     */
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokens = new uint256[](tokenCount);
        
        for (uint256 i = 0; i < tokenCount; i++) {
            tokens[i] = tokenOfOwnerByIndex(owner, i);
        }
        
        return tokens;
    }

    // Override functions required by Solidity

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenUri;
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}


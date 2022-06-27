// Sustain NFT token
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SustainNFT is ERC721 {
    using SafeMath for uint256;

    string public collection_name;
    string public collection_uri;
    bool public isPublic;
    address public factory;
    address public owner;

    struct Item {
        uint256 id;
        address creator;
        string uri;
    }
    uint256 public currentID;    
    mapping (uint256 => Item) public Items;


    event CollectionUriUpdated(string collection_uri);
    event ItemCreated(uint256 id, address creator, string uri);
    event CollectionNameUpdated(string collection_name);
    event CollectionPublicUpdated(bool isPublic);
    event TokenUriUpdated(uint256 id, string uri);

    constructor() ERC721("","") {
        factory = msg.sender;
    }

    /**
		Initialize from Swap contract
	 */
    function initialize(
        string memory _name,
        string memory _uri,
        address creator,
        bool bPublic
    ) external {
        require(msg.sender == factory, "Only for factory");
        collection_uri = _uri;
        collection_name = _name;
        owner = creator;
        isPublic = bPublic;
    }

    
    /**
		Change & Get Collection Information
	 */
    function setCollectionURI(string memory newURI) public onlyOwner {
        collection_uri = newURI;
        emit CollectionUriUpdated(newURI);
    }

    function setName(string memory newname) public onlyOwner {
        collection_name = newname;
        emit CollectionNameUpdated(newname);
    }

    function setPublic(bool bPublic) public onlyOwner {
        isPublic = bPublic;
        emit CollectionPublicUpdated(isPublic);
    }
    function getCollectionURI() external view returns (string memory) {
        return collection_uri;
    }
    function getCollectionName() external view returns (string memory) {
        return collection_name;
    }


    /**
		Change & Get Item Information
	 */
    function addItem(string memory _uri) public returns (uint256){
        currentID = currentID.add(1);        
        _safeMint(msg.sender, currentID);
        Items[currentID] = Item(currentID, msg.sender, _uri);
        emit ItemCreated(currentID, msg.sender, _uri);
        return currentID;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return Items[tokenId].uri;
    }

    function setTokenURI(uint256 _tokenId, string memory _newURI)
        public
        creatorOnly(_tokenId)
    {
        Items[_tokenId].uri = _newURI;
        emit TokenUriUpdated( _tokenId, _newURI);
    }

    function creatorOf(uint256 _tokenId) public view returns (address) {
        return Items[_tokenId].creator;
    }




    modifier onlyOwner() {
        require(owner == _msgSender(), "caller is not the owner");
        _;
    }
    /**
     * @dev Require _msgSender() to be the creator of the token id
     */
    modifier creatorOnly(uint256 _id) {
        require(
            Items[_id].creator == _msgSender(),
            "ERC721Tradable#creatorOnly: ONLY_CREATOR_ALLOWED"
        );
        _;
    }
}

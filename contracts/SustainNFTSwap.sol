// Sustain - NFT Swap contract
// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./SustainNFT.sol";

interface ISustainNFT {
	function initialize(string memory _name, string memory _uri, address creator, bool bPublic) external;
	function getCollectionURI() external view returns (string memory);
	function getCollectionName() external view returns (string memory);
    function creatorOf(uint256 id) external view returns (address);

	function getApproved(uint256 tokenId) external view returns (address);
	function safeTransferFrom(address from, 
			address to, 
			uint256 tokenId) external;
}

contract SustainNFTSwap is Ownable {
    using SafeMath for uint256;
	using EnumerableSet for EnumerableSet.AddressSet;

	uint256 constant public PERCENTS_DIVIDER = 1500;

	uint256 public feePorini = 75;
	uint256 public feeIucn = 75;
	uint256 public feeProtected = 100;

	address public poriniAddress; 
	address public iucnAddress; 
	address public protectedAddress; 
	

    IERC20 public sustainToken;

    /* Pairs to swap NFT _id => price */
	struct Pair {
		uint256 pair_id;
		address collection;
		uint256 token_id;
		address creator;
		address owner;
		uint256 price;		
	}

	address[] public collections;
	// collection address => creator address

	// token id => Pair mapping
    mapping(uint256 => Pair) public pairs;
	uint256 public currentPairId;
    
	uint256 public totalEarning; /* Total Sustain Token */
	uint256 public totalSwapped; /* Total swap count */



	/** Events */
    event CollectionCreated(address collection_address, address owner, string name, string uri, bool isPublic);
    event ItemListed(uint256 id, address collection, uint256 token_id, uint256 price, address creator, address owner);
	
    event Swapped(address buyer, uint256 id);

	constructor () {		
		
	}
	function initialize(
		address _tokenAddress, 
		address _nftAddress, 
		uint256 _feePorini, 
		address _poriniAddress, 
		uint256 _feeIucn, 
		address _iucnAddress, 
		uint256 _feeProtected, 
		address _protectedAddress) external onlyOwner {

		sustainToken = IERC20(_tokenAddress);
		
		feePorini = _feePorini;
		poriniAddress = _poriniAddress;
		feeIucn = _feeIucn;
		iucnAddress = _iucnAddress;
		feeProtected = _feeProtected;
		protectedAddress = _protectedAddress;

		collections.push(_nftAddress);	

		ISustainNFT sustainNFT = ISustainNFT(_nftAddress);
		emit CollectionCreated(_nftAddress, msg.sender, sustainNFT.getCollectionName(), sustainNFT.getCollectionURI(), true);//"Sustain","https://ipfs.io/ipfs/QmdwkN3PcjBC6j3nxbJ1i7mmShuLHRhud3X2eRyvcRXf4C"
	}    

	function setFee(uint256 _feePorini, 
		address _poriniAddress, 
		uint256 _feeIucn, 
		address _iucnAddress, 
		uint256 _feeProtected, 
		address _protectedAddress) external onlyOwner {
		
        feePorini = _feePorini;
		poriniAddress = _poriniAddress;
		feeIucn = _feeIucn;
		iucnAddress = _iucnAddress;
		feeProtected = _feeProtected;
		protectedAddress = _protectedAddress;
    }


	function createCollection(string memory _name, string memory _uri, bool bPublic) public returns(address collection) {
		bytes memory bytecode = type(SustainNFT).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_uri, _name, block.timestamp));
        assembly {
            collection := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ISustainNFT(collection).initialize(_name, _uri, msg.sender, bPublic);
		collections.push(collection);
		
		emit CollectionCreated(collection, msg.sender, _name, _uri, bPublic);
	}

    function list(address _collection, uint256 _token_id, uint256 _price) OnlyItemOwner(_collection,_token_id) public {
		require(_price > 0, "invalid price");		

		ISustainNFT nft = ISustainNFT(_collection);
		currentPairId = currentPairId.add(1);

		pairs[currentPairId].pair_id = currentPairId;
		pairs[currentPairId].collection = _collection;
		pairs[currentPairId].token_id = _token_id;
		pairs[currentPairId].creator = nft.creatorOf(_token_id);
		pairs[currentPairId].owner = msg.sender;		
		pairs[currentPairId].price = _price;		

        emit ItemListed(currentPairId, 
			_collection,
			_token_id, 
			_price, 
			pairs[currentPairId].creator,
			msg.sender
		);
    }

    function buy(uint256 _id) external ItemExists(_id) {
       
		Pair memory pair = pairs[_id];
		uint256 sustainAmount = pair.price;
		uint256 token_balance = sustainToken.balanceOf(msg.sender);
		require(token_balance >= sustainAmount, "insufficient token balance");

		// transfer Sustain token to poriniAddress
		require(sustainToken.transferFrom(msg.sender, poriniAddress, sustainAmount.mul(feePorini).div(PERCENTS_DIVIDER)), "failed to transfer Porini fee");
		
		// transfer Sustain token to iucnAddress
		require(sustainToken.transferFrom(msg.sender, iucnAddress, sustainAmount.mul(feeIucn).div(PERCENTS_DIVIDER)), "failed to transfer Iucn fee");
		
		// transfer Sustain token to protectedAddress
		require(sustainToken.transferFrom(msg.sender, protectedAddress, sustainAmount.mul(feeProtected).div(PERCENTS_DIVIDER)), "failed to transfer Protected Area fee");
		
		// transfer Sustain token to owner
		uint256 ownerPercent = PERCENTS_DIVIDER.sub(feePorini).sub(feeIucn).sub(feeProtected);
		require(sustainToken.transferFrom(msg.sender, pair.owner, sustainAmount.mul(ownerPercent).div(PERCENTS_DIVIDER)), "failed to transfer to owner");

		
		// transfer NFT token to buyer
		ISustainNFT(pairs[_id].collection).safeTransferFrom(pair.owner, msg.sender, pair.token_id);

		pairs[_id].owner = msg.sender;
		pairs[_id].price = sustainAmount.mul(PERCENTS_DIVIDER).div(1000);

		totalEarning = totalEarning.add(sustainAmount);
		totalSwapped = totalSwapped.add(1);

        emit Swapped(msg.sender, _id);		
    }

	modifier OnlyItemOwner(address tokenAddress, uint256 tokenId){
        ISustainNFT tokenContract = ISustainNFT(tokenAddress);
        require(tokenContract.creatorOf(tokenId) == msg.sender);
        _;
    }

    modifier ItemExists(uint256 id){
        require(id <= currentPairId && pairs[id].pair_id == id, "Could not find item");
        _;
    }

}
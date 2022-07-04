// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract EscrowOld is Ownable, IERC721Receiver {

    using Counters for Counters.Counter;
    Counters.Counter private _tradeIds;

    // Escrow fees paid per trader on each NFT
    uint public mbFee = 1e18; 
    uint public nonHolderFee = 5e18;
    uint public mbFeeONE = 10e18;
    uint public nonHolderFeeONE = 20e18;

    IERC721 private constant MOB_BOSS = IERC721(0x7857DCFF0405E3068443bc145375Ca6b09cAc2bB);
    IERC721 private constant RECRUIT = IERC721(0xB9FEf2499Fa2083Ea0B3b5957AC49577E306C5F2);

    IERC20 private constant GSM = IERC20(0xf4b0b1456990Fe87adaDAf9F7645587127a16a6c);
    
    bool public paused = false;

    /// @notice Represents a single NFT as a trade item
    struct Item {
        /// @notice NFT contract address
        address nft;

        /// @notice Token id of NFT
        uint tokenId;
    }
    
    struct Trade {
        /// @notice Trade initiator address
        address trader0;

        /// @notice Trade fulfiller address
        address trader1;

        /// @notice Items to be traded by trader0/initiator
        Item[] items0;

        /// @notice Items to be traded by trader1/fulfiller
        Item[] items1;

        /// @notice Trade ongoing marker
        bool active;
    }

    mapping(uint => Trade) private _idToTrade; 
    
    event TradeInitiated(uint indexed tradeId, address indexed trader0, address indexed trader1, uint creationTime);
    event TradeCompleted(uint indexed tradeId, uint completionTime);

    modifier notPaused() {
        require(paused == false, "Escrow: contract paused");
        _;
    }

    /// @dev Fetches data for a specific trade
    /// @param tradeId ID of trade to retrieve data about
    /// @return Trade data of the given id
    function fetchTradeData(uint tradeId) external view returns (Trade memory) {
        return _idToTrade[tradeId];
    }

    /// @notice Creates a new trade
    /// @param _trader1 address of the person to perform the trade with
    /// @param _items0 item(s) the caller will trade
    /// @param _items1 item(s) the other person will trade
    /// @return Trade id of the newly created trade
    function initiateTrade( 
        address _trader1,
        Item[] calldata _items0,
        Item[] calldata _items1
    ) external payable notPaused returns (uint) {
        require(_trader1 != address(0), "Escrow: trader cannot be zero address");
        require(_items0.length != 0 && _items1.length != 0, "Escrow: invalid items");
        _tradeIds.increment();
        uint currentId = _tradeIds.current();

        _idToTrade[currentId].trader0 = msg.sender;
        _idToTrade[currentId].trader1 = _trader1;
        _idToTrade[currentId].active = true;

        if(msg.value == 0){
            uint fee = _calculateFee(_items0.length+_items1.length,true);
            require(GSM.transferFrom(msg.sender,address(this),fee),"Fee not paid");
        }
        else{
            uint fee = _calculateFee(_items0.length+_items1.length,false);
            require(msg.value == fee,"Fee not paid");
        }

        for(uint i; i < _items0.length; i++) {
            if(_items0[i].nft == address(0)) 
                revert("Escrow: contract cannot be zero address");
            else {
                _idToTrade[currentId].items0.push(_items0[i]);
                IERC721(_items0[i].nft).safeTransferFrom(msg.sender, address(this), _items0[i].tokenId);
            }       
        }

        for(uint j; j < _items1.length; j++) {
            if(_items1[j].nft == address(0)) 
                revert("Escrow: contract cannot be zero address");
            else 
                _idToTrade[currentId].items1.push(_items1[j]);     
        }

        emit TradeInitiated(currentId, msg.sender, _trader1, block.timestamp);
        return currentId;
    }
    
    /// @notice Fulfills an active trade 
    /// @dev Transfers items between both parties
    /// @param tradeId ID of trade to fulfill
    function completeTrade(uint tradeId) external payable notPaused {
        Trade memory trade = _idToTrade[tradeId];
        require(msg.sender == trade.trader1, "Escrow: must be designated trader");
        require(trade.active, "Escrow: trade not active");

        _idToTrade[tradeId].active = false;

        
        if(msg.value == 0){
            uint fee = _calculateFee(trade.items0.length+trade.items1.length,true);
            require(GSM.transferFrom(msg.sender,address(this),fee),"Fee not paid");
        }
        else{
            uint fee = _calculateFee(trade.items0.length+trade.items1.length,false);
            require(msg.value == fee,"Fee not paid");
        }

        for(uint i; i < trade.items1.length; i++) {
            IERC721(trade.items1[i].nft).safeTransferFrom(msg.sender, trade.trader0, trade.items1[i].tokenId);
        }

        for(uint j; j < trade.items0.length; j++) {
            IERC721(trade.items0[j].nft).safeTransferFrom(address(this), msg.sender, trade.items0[j].tokenId);
        }

        emit TradeCompleted(tradeId, block.timestamp);
    }
    
    /// @notice Cancels a trade in case of an unresponsive trader
    /// @notice Returns initially received items to the caller/trade creator
    /// @param tradeId ID of the trade to cancel
    function cancelTrade(uint tradeId) external {
        Trade memory trade = _idToTrade[tradeId];
        require(msg.sender == trade.trader0, "Escrow: must be trade creator");
        require(trade.active, "Escrow: trade not active");

        delete _idToTrade[tradeId];

        for(uint i; i < trade.items0.length; i++) {
            IERC721(trade.items0[i].nft).safeTransferFrom(address(this), msg.sender, trade.items0[i].tokenId);
            //TODO: ADD REFUND ON FEE PAID
            //TODO: DIFFERENTIATE GURANTEED FEE AFTER TRADE IS COMPLETE SO OWNER DOESN'T RETRIEVE REFUNDABLE FEE
        }
    }

    /// @dev Calculated fees based on holding and net NFTs being traded
    function _calculateFee(uint totalItems,bool _gsmPayment) public view returns(uint feeAmt){
        if(_gsmPayment){
            if(MOB_BOSS.balanceOf(msg.sender) > 0) 
                feeAmt = mbFee * totalItems;
            else 
                feeAmt = nonHolderFee * totalItems;
        }
        else{
            if(MOB_BOSS.balanceOf(msg.sender) > 0) 
                feeAmt = mbFeeONE * totalItems;
            else 
                feeAmt = nonHolderFeeONE * totalItems;
        }
            
    }

    /* |--- ONLY OWNER ---| */

    /// @notice Transfers GSM token balance of the contract to the owner
    function collectFee() external onlyOwner {
        GSM.transfer(msg.sender, GSM.balanceOf(address(this))); 
    }

    /// @notice Change escrow fee for mob boss owners
    /// @param _mbFee new mob boss fee
    function setMobBossFee(uint _mbFee) external onlyOwner {
        mbFee = _mbFee;
    }

    /// @notice Change escrow fee for non holders
    /// @param _nonHolderFee new non holder fee
    function setNonHolderFee(uint _nonHolderFee) external onlyOwner {
        nonHolderFee = _nonHolderFee;
    }

    /// @notice Pauses contract functionality
    function pause() external onlyOwner {
        paused = true;
    }

    /// @notice Unpauses contract functionality
    function unpause() external onlyOwner {
        paused = false;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
}
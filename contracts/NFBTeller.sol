// SPDX-License-Identifier: WTFPL
pragma solidity 0.7.5;

import "./interfaces/IERC20.sol";
import "./interfaces/ITeller.sol";
import "./interfaces/IBondDepository.sol";

import "./libraries/NonFungibleToken.sol";
import "./libraries/SafeERC20.sol";

// @author Dionysus
contract NonFungibleBondTeller is NonFungibleToken("Olympus Bond", "BOND") {

    using SafeERC20 for IERC20;

    /////////////// storage  ///////////////

    // Interface sOHM
    IERC20 public sOHM;

    // Interface Teller
    ITeller public teller;

    // Interface Bond Depository
    IBondDepository public depository;

    // Total amount of NFB's minted cumulativly
    uint public totalNFBs;

    // NFB ID => Bond Index ID
    mapping ( uint => uint ) public NFBToIndex;


    /////////////// events ///////////////

    event BondMinted ( uint amount, uint maxPrice, address depositor, uint tokenId, uint index );

    event BondReemed ( address owner, uint dues );
    
    
    /////////////// construction ///////////////
    
    constructor(
        IERC20 _sOHM,
        ITeller _teller,
        IBondDepository _depo
    ) {
        sOHM = _sOHM;
        teller = _teller;
        depository = _depo;
    }
    
    
    /////////////// public logic  ///////////////

    /**
     * @notice deposit bond
     * @param _amount uint
     * @param _maxPrice uint
     * @param _depositor address
     * @param _BID uint
     * @param _FID uint
     * @return uint
     */
    function deposit(
        uint _amount, 
        uint _maxPrice,
        address _depositor,
        uint _BID,
        uint _FID
    ) external returns ( uint payout, uint tokenId, uint index ) {
        // fetch what principal is being used
        ( address principal, ) = depository.bondTypeInfo( _BID );
        // transfer users principal to this contract
        IERC20( principal ).safeTransferFrom( msg.sender, address( this ), _amount );
        // deposit to bond depo, ( this contract becomes proxy owner of purchased bond )
        ( payout, index ) = depository.deposit( _amount, _maxPrice, address( this ), _BID, _FID );
        // mint user a NFT that represents their proxied ownership
        _safeMint( _depositor, totalNFBs );
        // map the nft to the newly created bonds id 
        NFBToIndex[ totalNFBs ] = index;
        // set tokenId and increment totalNFBs by one
        tokenId = totalNFBs;
        totalNFBs += 1;
        // emit event with relevant details
        emit BondMinted ( _amount, _maxPrice, _depositor , tokenId, index );
    }

    /** 
     *  @notice redeem bond
     *  @param tokenIds uint[]
     *  @return total dues
     */
    function redeem( 
        uint[] calldata tokenIds
    ) external returns ( uint dues ) {
        for (uint i; i < tokenIds.length; i++) {
            // make sure the tokens exist, and caller is the owner
            require( _exists( i ) &&  msg.sender == ownerOf[ i ], "You're not the owner" );
            // if remaining payout is 0 burn the bond
            if ( teller.payoutFor( address( this ), NFBToIndex[ tokenIds[ i ] ] ) == 0 ) _burn( i );
            // redeem bond, and add dues to return
            dues += teller.redeem( address( this ), NFBToIndex[ tokenIds[ i ] ] );
            // emit redemption
            emit BondReemed ( msg.sender, dues );
        }
        // transfer owner their funds
        sOHM.safeTransfer( msg.sender, dues );
    }
}
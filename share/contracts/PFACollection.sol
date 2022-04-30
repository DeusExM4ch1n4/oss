// SPDX-License-Identifier: UNLICENSED
// ⣿⣿⣿⣿⣿⠀⠀⣰⣿⣿⣿⣷⡀⠀⠀⣶⣶⣶⣦⡀⠀⠀⠀⣶⣶⡄⠀⠀⣶⣶⡆⠀⠀⣶⣶⠀⠀⠀⠀⢰⣶⣶⣶⣶⢀⠀⠀⣤⣶⣶⣦⡀⠀⠀⠀⣴⣶⣶⣦⠀
// ⣿⣿⠀⠀⠀⠀⠀⣿⣿⠀⢸⣿⡇⠀⠀⣿⣿⠀⢻⣿⠀⠀⠀⣿⣿⣿⠀⢸⣿⣿⡇⠀⠀⣿⣿⠀⠀⠀⠀⢸⣿⡇⠀⠀⠀⠀⢸⣿⡇⠀⣿⣿⠀⠀⣾⣿⠁⠈⣿⡇
// ⣿⣿⠀⠀⠀⠀⠀⣿⣿⠀⢸⣿⡇⠀⠀⣿⣿⠀⣸⣿⠀⠀⠀⣿⣿⣿⡀⣿⡟⣿⡇⠀⠀⣿⣿⠀⠀⠀⠀⢸⣿⡇⠀⠀⠀⠀⠀⣿⣿⡀⠀⠀⠀⠀⠘⣿⣷⠀⠀⠀
// ⣿⣿⠿⠿⠀⠀⠀⣿⣿⠀⢸⣿⡇⠀⠀⣿⣿⣿⣿⡟⠀⠀⠀⣿⣿⣿⣷⣿⠀⣿⡇⠀⠀⣿⣿⠀⠀⠀⠀⢸⣿⡿⠿⠀⠀⠀⠀⠀⢿⣿⣦⠀⠀⠀⠀⠈⣿⣿⡄⠀
// ⣿⣿⠀⠀⠀⠀⠀⣿⣿⠀⢸⣿⡇⠀⠀⣿⣿⠈⣿⣷⠀⠀⠀⣿⣿⢸⣿⣿⠈⣿⡇⠀⠀⣿⣿⠀⠀⠀⠀⢸⣿⡇⠀⠀⠀⠀⢀⣀⠀⠙⣿⣧⠀⠀⣀⣀⠀⠻⣿⡆
// ⣿⣿⠀⠀⠀⠀⠀⢿⣿⣤⣾⣿⠇⠀⠀⣿⣿⠀⣿⣿⠀⠀⠀⣿⣿⠀⣿⡇⠈⣿⡇⠀⠀⣿⣿⣤⣤⡄⠀⢸⣿⣧⣤⣤⡄⠀⢸⣿⣆⠀⣿⣿⠀⠀⣿⣿⡀⢀⣿⣿
// ⠛⠛⠀⠀⠀⠀⠀⠈⠛⠿⠿⠛⠀⠀⠀⠛⠛⠀⠘⠛⠃⠀⠀⠛⠛⠀⠛⠀⠈⠛⠃⠀⠀⠛⠛⠛⠛⠃⠀⠘⠛⠛⠛⠛⠃⠀⠀⠙⠿⠿⠟⠁⠀⠀⠀⠛⠿⠿⠛⠀
// https://formless.xyz/opportunities
//
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./SHARE.sol";
import "./PFA.sol";
import "./libraries/CodeVerification.sol";
import "./libraries/Immutable.sol";
import "./interfaces/IPFACollection.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract PFACollection is PFA, IPFACollection, ERC721 {
    event Payment(
        address indexed from,
        address indexed recipient,
        uint256 indexed addressIndex,
        uint256 value
    );

    event ItemPaymentSkipped(address indexed owner, address indexed item);

    string public constant NAME = "PFA_COLLECTION";
    string public constant SYMBOL = "SHARE";
    uint256 private constant MAX_SIZE = 200;
    uint256 private constant UNIT_TOKEN_INDEX = 0;

    Immutable.AddressArray private _addresses;
    Immutable.AddressToBooleanMap private _addressMap;

    uint256 private _currentAddressIndex = 0;
    string internal _tokenURI;

    constructor()
        public
        ERC721(NAME, SYMBOL)
        LimitedOwnable(
            true, /* WALLET */
            false /* SPLIT */
        )
    {
        _safeMint(msg.sender, UNIT_TOKEN_INDEX);
    }

    function initialize(
        address[] memory addresses_,
        string memory tokenURI_,
        uint256 pricePerAccess_,
        uint256 grantTTL_,
        bool supportsLicensing_,
        address shareContractAddress_
    ) public onlyOwner {
        Immutable.setUnsignedInt256(_pricePerAccess, pricePerAccess_);
        Immutable.setUnsignedInt256(_grantTTL, grantTTL_);
        Immutable.setBoolean(_supportsLicensing, supportsLicensing_);
        _tokenURI = tokenURI_;
        setShareContractAddress(shareContractAddress_);
        SHARE protocol = SHARE(shareContractAddress_);

        require(addresses_.length < MAX_SIZE, "SHARE008");
        for (uint256 i = 0; i < addresses_.length; i++) {
            address itemAddress = addresses_[i];
            require(
                protocol.isApprovedBuild(
                    itemAddress,
                    CodeVerification.BuildType.PFA_UNIT
                ),
                "SHARE009"
            );
            PFA item = PFA(itemAddress);
            require(pricePerAccess_ >= item.pricePerAccess(), "SHARE015");
            Immutable.pushAddress(_addresses, addresses_[i]);
            Immutable.insertBooleanAtAddress(_addressMap, itemAddress, true);
        }
        _addresses.locked = true;
        setInitialized();
    }

    function addressIndex() public view afterInit returns (uint256) {
        return _currentAddressIndex;
    }

    function access(uint256 tokenId_, address recipient_)
        public
        override
        payable
        nonReentrant
        afterInit
    {
        SHARE protocol = SHARE(shareContractAddress());
        address itemAddress = _addresses.value[_currentAddressIndex];
        PFA item = PFA(itemAddress);
        address owner = owner(); /* collection owner */
        address itemOwner = item.owner();

        require(msg.value == _pricePerAccess.value, "SHARE010");

        _currentAddressIndex =
            (_currentAddressIndex + 1) %
            (_addresses.value.length);

        if (
            protocol.isApprovedBuild(
                itemOwner,
                CodeVerification.BuildType.WALLET
            ) ||
            protocol.isApprovedBuild(
                itemOwner,
                CodeVerification.BuildType.SPLIT
            )
        ) {
            // Pay for item access
            // We use call with encodeWithSignature here to guarantee
            // that a revert in the callee does not prevent the
            // caller state from updating, e.g. the counter
            // (_currentAddressIndex) must increment in this
            // transaction.
            uint256 payment = item.pricePerAccess();
            (bool itemPaymentSuccess, ) = payable(address(item)).call{
                value: payment
            }(
                abi.encodeWithSignature(
                    "access(uint256,address)",
                    tokenId_,
                    recipient_
                )
            );

            if (itemPaymentSuccess) {
                emit Payment(
                    msg.sender,
                    address(item),
                    _currentAddressIndex,
                    payment
                );
            } else {
                emit ItemPaymentSkipped(itemOwner, address(item));
            }

            // Pay the collection owner
            (bool ownerPaymentSuccess, ) = payable(owner).call{
                value: _pricePerAccess.value - item.pricePerAccess()
            }("");
            require(ownerPaymentSuccess, "SHARE021");

            emit Payment(
                msg.sender,
                owner,
                _currentAddressIndex,
                _pricePerAccess.value - item.pricePerAccess()
            );

            _grantTimestamps[recipient_] = block.timestamp;
            emit Grant(recipient_, UNIT_TOKEN_INDEX);
        } else {
            emit ItemPaymentSkipped(itemOwner, address(item));
        }
    }

    function contains(address account_) public view afterInit returns (bool) {
        return _addressMap.value[account_];
    }

    /**
     * @dev Returns the token URI for the asset.
     */
    function tokenURI(uint256 tokenId_)
        public
        override
        view
        returns (string memory)
    {
        require(tokenId_ == UNIT_TOKEN_INDEX, "SHARE004");
        return _tokenURI;
    }

    /**
     * @dev Sets the asset token URI.
     */
    function setTokenURI(string memory tokenURI_)
        public
        nonReentrant
        onlyOwner
    {
        _tokenURI = tokenURI_;
    }
}

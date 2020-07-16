pragma solidity ^0.6.2;

// SPDX-License-Identifier: UNLICENSED

import "../base/contracts/Initializable.sol";
import "../base/contracts/presets/ERC20PresetMinterPauser.sol";


contract SanuSilver is Initializable, ERC20PresetMinterPauserUpgradeSafe {

    // FEE CONTROLLER DATA
    // fee decimals is only set for informational purposes.
    // 1 feeRate = .000001 oz of silver
    uint8 public constant FEE_DECIMALS = 6;

    // feeRate is measured in 100th of a basis point (parts per 1,000,000)
    // ex: a fee rate of 200 = 0.02% of an oz of silver
    uint256 public constant FEE_PARTS = 1000000;
    uint256 public feeRate;
    address public feeController;
    address public feeRecipient;
    address public owner;
    mapping(address => bool) internal frozen;

    // FEE CONTROLLER EVENTS
    event FeeCollected(address indexed from, address indexed to, uint256 value);

    event FeeRateSet(
        uint256 indexed oldFeeRate,
        uint256 indexed newFeeRate
    );

    event FeeControllerSet(
        address indexed oldFeeController,
        address indexed newFeeController
    );

    event FeeRecipientSet(
        address indexed oldFeeRecipient,
        address indexed newFeeRecipient
    );

    // ASSET PROTECTION EVENTS
    event AddressFrozen(address indexed addr);
    event AddressUnfrozen(address indexed addr);
    event FrozenAddressWiped(address indexed addr);
    event AssetProtectionRoleSet (
        address indexed oldAssetProtectionRole,
        address indexed newAssetProtectionRole
    );

    modifier onlyFeeController() {
        require(msg.sender == feeController, "only FeeController");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only Owner");
        _;
    }

    // Overriding the initialize function to initialize more variables
    function initialize(string memory name, string memory symbol)public virtual override {
        feeController = msg.sender;
        feeRecipient = msg.sender;
        owner = msg.sender;
        super.initialize(name, symbol);
    }

    /**
    * @dev Transfer token to a specified address from msg.sender
    * Transfer additionally sends the fee to the fee controller
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function transfer(address to, uint256 value) public override returns (bool) {
        require(!frozen[to] && !frozen[msg.sender], "address frozen");
        uint256 fee = getFeeFor(value);
        uint256 principle = value.sub(fee);

        super.transfer(to, principle);

        if (fee != 0) {
            super.transfer(feeRecipient, fee);
            emit FeeCollected(msg.sender, feeRecipient, fee);
        }

        return true;
    }

    /**
     * @dev Transfer tokens from one address to another
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        require(!frozen[to] && !frozen[from], "address frozen");
        require(to != address(0), "cannot transfer to address zero");

        uint256 fee = getFeeFor(value);
        uint256 principle = value.sub(fee);

        super.transferFrom(from, to, principle);

        if (fee != 0) {
            super.transfer(feeRecipient, fee);
            emit FeeCollected(msg.sender, feeRecipient, fee);
        }

        return true;
    }

    /**
     * @dev Toggle the frozen state of an address
     * @param _addr The addresss
     */
    function toggleFreeze(address _addr) public onlyOwner {
        require(_addr != address(0), "cannot set frozen state of address zero");
        bool froze = !frozen[_addr]
        frozen[_addr] = froze;

        if (!froze) {
            emit AddressUnfrozen(_addr);
        } else {
            emit AddressFrozen(_addr);
        }
    }

    /**
     * @dev Wipes the balance of a frozen address, burning the tokens
     * and setting the approval to zero.
     * @param _addr The frozen address to wipe.
     */
    function wipeFrozenAddress(address _addr) public onlyOwner {
        require(frozen[_addr], "address is not frozen");
        uint256 _balance = super.balanceOf(_addr);
        super._approve(_addr, msg.sender, _balance);
        super.burnFrom(_addr, _balance);
        emit FrozenAddressWiped(_addr);
    }

    /**
    * @dev Gets whether the address is currently frozen.
    * @param _addr The address to check if frozen.
    * @return A bool representing whether the given address is frozen.
    */
    function isFrozen(address _addr) public view returns (bool) {
        return frozen[_addr];
    }

     /**
     * @dev Sets a new fee rate.
     // ex: a fee rate of 200 = 0.02%
     * @param _newFeeRate The new fee rate to collect as transfer fees for transfers.
     */
    function setFeeRate(uint256 _newFeeRate) public onlyFeeController {
        require(_newFeeRate <= FEE_PARTS, "cannot set fee rate above 100%");
        uint256 _oldFeeRate = feeRate;
        feeRate = _newFeeRate;
        emit FeeRateSet(_oldFeeRate, _newFeeRate);
    }

    /**
     * @dev Sets a new fee recipient address.
     * @param _newFeeRecipient The address allowed to collect transfer fees for transfers.
     */
    function setFeeRecipient(address _newFeeRecipient) public onlyFeeController {
        require(_newFeeRecipient != address(0), "cannot set fee recipient to address zero");
        address _oldFeeRecipient = feeRecipient;
        feeRecipient = _newFeeRecipient;
        emit FeeRecipientSet(_oldFeeRecipient, _newFeeRecipient);
    }

     /**
     * @dev Sets a new fee controller address.
     * @param _newFeeController The address allowed to set the fee rate and the fee recipient.
     */
    function setFeeController(address _newFeeController) public {
        require(msg.sender == feeController || msg.sender == owner, "only FeeController or Owner");
        require(_newFeeController != address(0), "cannot set fee controller to address zero");
        address _oldFeeController = feeController;
        feeController = _newFeeController;
        emit FeeControllerSet(_oldFeeController, _newFeeController);
    }

    /**
    * @dev Gets a fee for a given value
    * ex: given feeRate = 200 and FEE_PARTS = 1,000,000 then getFeeFor(10000) = 2
    * @param value The amount to get the fee for.
    */
    function getFeeFor(uint256 value) public view returns (uint256) {
        return value.mul(feeRate).div(FEE_PARTS);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../CloneLib.sol";
// TODO: switch to "@openzeppelin/contracts/access/Ownable.sol";
import "../Ownable.sol";

contract DataUnionFactory is Ownable {
    event DUCreated(address indexed mainnet, address indexed sidenet, address indexed owner, address template);
    event UpdateNewDUInitialEth(uint amount);
    event UpdateNewDUOwnerInitialEth(uint amount);
    event UpdateDefaultNewMemberInitialEth(uint amount);
    event DUInitialEthSent(uint amountWei);
    event OwnerInitialEthSent(uint amountWei);

    address public dataUnionTemplate;

    // when  DU is created, the factory sends a bit of sETH to the DU and the owner
    uint public newDUInitialEth;
    uint public newDUOwnerInitialEth;
    uint public defaultNewMemberEth;

    constructor(address _dataUnionTemplate) Ownable(msg.sender) {
        setTemplate(_dataUnionTemplate);
    }

    function setTemplate(address _dataUnionTemplate) public onlyOwner {
        dataUnionTemplate = _dataUnionTemplate;
    }

    // contract is payable so it can receive and hold the new member eth stipends
    receive() external payable {}

    function setNewDUInitialEth(uint val) public onlyOwner {
        newDUInitialEth = val;
        emit UpdateNewDUInitialEth(val);
    }

    function setNewDUOwnerInitialEth(uint val) public onlyOwner {
        newDUOwnerInitialEth = val;
        emit UpdateNewDUOwnerInitialEth(val);
    }

    function setNewMemberInitialEth(uint val) public onlyOwner {
        defaultNewMemberEth = val;
        emit UpdateDefaultNewMemberInitialEth(val);
    }

    /**
     * @dev This function is called over the bridge by the DataUnionMainnet.initialize function
     * @dev Hence must be called by the AMB. Use MockAMB for testing.
     * @dev CREATE2 salt = mainnet_address.
     */
    function deployNewDU(
        address token,
        address mediator,
        address payable owner,
        address[] memory agents,
        uint256 initialAdminFeeFraction,
        uint256 initialDataUnionFeeFraction,
        address initialDataUnionBeneficiary
    ) public returns (address) {
        require(msg.sender == address(amb(mediator)), "only_AMB");
        address duMainnet = amb(mediator).messageSender();
        bytes32 salt = bytes32(uint256(uint160(duMainnet)));
        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address,address,address[],address,uint256,uint256,uint256,address)",
            owner,
            token,
            mediator,
            agents,
            duMainnet,
            defaultNewMemberEth,
            initialAdminFeeFraction,
            initialDataUnionFeeFraction,
            initialDataUnionBeneficiary
        );
        address payable du = CloneLib.deployCodeAndInitUsingCreate2(CloneLib.cloneBytecode(dataUnionTemplate), data, salt);
        emit DUCreated(duMainnet, du, owner, dataUnionTemplate);

        // continue whether or not send succeeds
        if (newDUInitialEth != 0 && address(this).balance >= newDUInitialEth) {
            if (du.send(newDUInitialEth)) {
                emit DUInitialEthSent(newDUInitialEth);
            }
        }
        if (newDUOwnerInitialEth != 0 && address(this).balance >= newDUOwnerInitialEth) {
            // solhint-disable-next-line multiple-sends
            if (owner.send(newDUOwnerInitialEth)) {
                emit OwnerInitialEthSent(newDUOwnerInitialEth);
            }
        }
        return du;
    }
}

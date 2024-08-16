// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import "../lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract Tools is Test { 

    // - stimulates a timelock transaction
    // - creates gnosis transactions for it
    // - stimulates the timelock transaction
    function test_stimulate_timelock() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC"));
    
        TimelockController etherfiTimelock = TimelockController(payable(0x9f26d4C958fD811A1F59B01B86Be7dFFc9d20761));

        /// Detail the transaction to be executed here ///
        /// ******************************************* ///
        bytes memory data = abi.encodeWithSignature("updateWhitelistedToken(address,bool)", 0xDc400f3da3ea5Df0B7B6C127aE2e54CE55644CF3, false);
        address target = 0x9FFDF407cDe9a93c47611799DA23924Af3EF764F;
        uint256 value = 0;
        /// ******************************************* ///

        bytes32 predecessor = 0x0000000000000000000000000000000000000000000000000000000000000000;
        bytes32 salt = 0x0000000000000000000000000000000000000000000000000000000000000000;
        uint256 delay = 259200;

        // useful if you like to test just the transction without the gnosis
        // vm.startPrank(0xcdd57D11476c22d265722F68390b036f3DA48c21);
        // etherfiTimelock.schedule(target, value, data, predecessor, salt, delay);
        // vm.warp(block.timestamp + delay + 1);
        // etherfiTimelock.execute(target, value, data, predecessor, salt);

        // Generate the gnosis transactions
        string memory timelockTarget = iToHex(abi.encodePacked(0x9f26d4C958fD811A1F59B01B86Be7dFFc9d20761));
        string memory scheduleTransactionData = iToHex(abi.encodeWithSignature("schedule(address,uint256,bytes,bytes32,bytes32,uint256)", target, value, data, predecessor, salt, delay));
        string memory executeTransactionData = iToHex(abi.encodeWithSignature("execute(address,uint256,bytes,bytes32,bytes32)", target, value, data, predecessor, salt));

        string memory gnosisScheduleTransaction = _getGnosisHeader("1");
        gnosisScheduleTransaction = string.concat(gnosisScheduleTransaction, _getGnosisTransaction(timelockTarget, scheduleTransactionData, true));
        vm.writeJson(gnosisScheduleTransaction, "./scheduleTransaction.json");

        string memory gnosisExecuteTransaction = _getGnosisHeader("1");
        gnosisExecuteTransaction = string.concat(gnosisExecuteTransaction, _getGnosisTransaction(timelockTarget, executeTransactionData, true));
        vm.writeJson(gnosisExecuteTransaction, "./executeTransaction.json");

        // Execute the gnosis transactions
        executeGnosisTransactionBundle("./scheduleTransaction.json", 0xcdd57D11476c22d265722F68390b036f3DA48c21);
        vm.warp(block.timestamp + delay + 1);
        executeGnosisTransactionBundle("./executeTransaction.json", 0xcdd57D11476c22d265722F68390b036f3DA48c21);

        // Test state changes

    }


    // functions that can be used together to create a gnosis transaction
    function _getGnosisHeader(string memory chainId) internal pure returns (string memory) {
        return string.concat('{"chainId":"', chainId, '","meta": { "txBuilderVersion": "1.16.5" }, "transactions": [');
    }
    function _getGnosisTransaction(string memory to, string memory data, bool isLast) internal pure returns (string memory) {
        string memory suffix = isLast ? ']}' : ',';
        return string.concat('{"to":"', to, '","value":"0","data":"', data, '"}', suffix);
    }
    // takes raw bytes from gnosis and converts it to the hex string expected by the gnosis safe
    function iToHex(bytes memory buffer) public pure returns (string memory) {
        // Fixed buffer size for hexadecimal convertion
        bytes memory converted = new bytes(buffer.length * 2);

        bytes memory _base = "0123456789abcdef";

        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }

        return string(abi.encodePacked("0x", converted));
    }

    /**
     * @dev Simulations the execution of a gnosis transaction bundle on the current fork
     * @param transactionPath The path to the transaction bundle json file
     * @param sender The address of the gnosis safe that will execute the transaction
     */
    function executeGnosisTransactionBundle(string memory transactionPath, address sender) public {
        string memory json = vm.readFile(transactionPath);
        for (uint256 i = 0; vm.keyExistsJson(json, string.concat(".transactions[", Strings.toString(i), "]")); i++) {
            address to = vm.parseJsonAddress(json, string.concat(string.concat(".transactions[", Strings.toString(i)), "].to"));
            uint256 value = vm.parseJsonUint(json, string.concat(string.concat(".transactions[", Strings.toString(i)), "].value"));
            bytes memory data = vm.parseJsonBytes(json, string.concat(string.concat(".transactions[", Strings.toString(i)), "].data"));

            vm.prank(sender);
            (bool success,) = address(to).call{value: value}(data);
            require(success, "Transaction failed");
        }
    }
}

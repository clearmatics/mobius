pragma solidity ^0.4.19;

/*
 * Contract that is working with ERC223 tokens
**/

contract ERC223ReceivingContract {
    event ERROR(bytes32 idexed);

    function() payable {
        ERROR(0x1);
    }

    function tokenFallback(address _from, uint256 _value, bytes _data) public;
}

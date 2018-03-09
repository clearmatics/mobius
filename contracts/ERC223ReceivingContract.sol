solidity ^0.4.11;

/*
 * Contract that is working with ERC223 tokens
**/

contract ERC223ReceivingContract {
    event ERROR(bytes32 idexed);

    function() payable {
        ERROR(0x1);
    }

    function tokenFallback(address,uint256,bytes) public {
        // Custom tokenFallback to receive ERC223 tokens on the contract
    }
}

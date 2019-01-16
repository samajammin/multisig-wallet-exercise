pragma solidity ^0.5.0;

contract MultiSignatureWallet {
    event Submission(uint indexed transactionId);
    event Confirmation(address indexed sender, uint indexed transactionId);
    event Revokation(address indexed sender, uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);    
    
    address[] public owners;
    uint public required;
    mapping (address => bool) public isOwner;
    uint public transactionCount;
    mapping (uint => Transaction) public transactions;
    mapping (uint => mapping (address => bool)) public confirmations;

    struct Transaction {
        bool executed;
        address destination;
        uint value;
        bytes data;
    }
    
    modifier ownerExists(address owner) {
        if (!isOwner[owner])
            revert("Must be an owner.");
        _;
    }
    
    modifier transactionExists(uint transactionId) {
        if (transactions[transactionId].destination != address(0))
            revert("This transaction does not exist.");
        _;
    }

    modifier validRequirement(uint ownerCount, uint _required) {
        if (_required > ownerCount || _required == 0 || ownerCount == 0)
            revert("Invalid inputs.");
        _;
    }
    
    /// @dev Fallback function, which accepts ether when sent to contract
    function() external payable {}

    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(address[] memory _owners, uint _required) public 
      validRequirement(_owners.length, _required) 
    {
        for (uint i = 0; i < _owners.length; i++) {
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function submitTransaction(address destination, uint value, bytes memory data) 
        public
        ownerExists(msg.sender) 
        returns (uint transactionId) 
    {
        transactionId = addTransaction(destination, value, data);
        confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint transactionId)
        public 
        ownerExists(msg.sender) 
        // TODO why does transactionExists fail?
        // transactionExists(transactionId)
    {
        require(confirmations[transactionId][msg.sender] == false, "Transaction already confirmed.");
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId)
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
    {
        confirmations[transactionId][msg.sender] = false;
        emit Revokation(msg.sender, transactionId);
    }

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId) public ownerExists(msg.sender) {
        require(transactions[transactionId].executed == false, "Transaction already executed.");
        if (isConfirmed(transactionId)) {
            Transaction storage t = transactions[transactionId];
            (bool success, ) = t.destination.call.value(t.value)(t.data);
            if (success) {
                t.executed = true;
                emit Execution(transactionId);
            } else {
                emit ExecutionFailure(transactionId);
            }
        }
    }

    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint transactionId) internal view returns (bool) {
        uint confirmationCount;
        for (uint i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                confirmationCount++;
            }
            if (confirmationCount == required) {
                return true;
            }
        }
        return false;
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function addTransaction(address destination, uint value, bytes memory data)
        internal
        returns (uint transactionId) 
    {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false
        });
        transactionCount++;
        emit Submission(transactionId);
    }
}

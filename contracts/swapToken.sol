// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import Chainlink client from the OpenZeppelin library
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@biconomy/contracts/src/0.8.0/forwarder/BiconomyForwarder.sol";

contract TokenSwap {
    // Define the tokens that will be swapped
    address public token1;
    address public token2;

    // Define the Chainlink price oracle contract addresses for each token
    AggregatorV3Interface internal priceFeed1;
    AggregatorV3Interface internal priceFeed2;

    // Define the Biconomy Forwarder
    BiconomyForwarder public biconomy;

    // Define the constructor function
    constructor(
        address _token1,
        address _token2,
        address _priceFeed1,
        address _priceFeed2,
        address _biconomy
    ) {
        token1 = _token1;
        token2 = _token2;
        priceFeed1 = AggregatorV3Interface(_priceFeed1);
        priceFeed2 = AggregatorV3Interface(_priceFeed2);
        biconomy = BiconomyForwarder(_biconomy);
    }

    // Define the swapTokens function
    function swapTokens(
        uint256 _amount,
        bool _isToken1ToToken2,
        bytes calldata _data
    ) public {
        // Get the current price of each token from the Chainlink price oracle
        (, int256 price1, , , ) = priceFeed1.latestRoundData();
        (, int256 price2, , , ) = priceFeed2.latestRoundData();

        // Calculate the exchange rate between the tokens
        uint256 exchangeRate = (uint256(price1) * 10 ** 18) / uint256(price2);

        // Calculate the output amount based on the exchange rate and the input amount
        uint256 outputAmount;
        if (_isToken1ToToken2) {
            outputAmount = (_amount * exchangeRate) / 10 ** 18;
        } else {
            outputAmount = (_amount * 10 ** 18) / exchangeRate;
        }
        uint256 finalOutputAmount = outputAmount;

        // Transfer the input token to the Biconomy Forwarder contract
        require(
            IERC20(token1).transferFrom(msg.sender, address(biconomy), _amount),
            "Transfer failed"
        );

        // Prepare the parameters for the meta transaction
        address userAddress = msg.sender;
        address contractAddress = address(this);
        uint256 value = 0;
        uint256 gasLimit = gasleft();
        uint256 gasPrice = tx.gasprice;
        uint256 nonce = biconomy.getNonce(userAddress);

        // Send the meta transaction to the Biconomy Forwarder
        bytes memory functionSignature = abi.encodeWithSelector(
            this.swapTokensGasless.selector,
            _amount,
            _isToken1ToToken2
        );
        biconomy.execute{
            value: value,
            gas: gasLimit,
            gasPrice: gasPrice,
            nonce: nonce
        }(userAddress, functionSignature, contractAddress, _data);

        // Transfer the output token to the user
        if (_isToken1ToToken2) {
            require(
                IERC20(token2).transfer(msg.sender, finalOutputAmount),
                "Transfer failed"
            );
        } else {
            require(
                IERC20(token1).transfer(msg.sender, finalOutputAmount),
                "Transfer failed"
            );
        }
    }

    // Define the swapTokensGasless function
    function swapTokensGasless(
        uint256 _amount,
        bool _isToken1ToToken2,
        bytes calldata _signature,
        uint256 _nonce
    ) public {
        // Get the current price of each token from the Chainlink price oracle
        (, int256 price1, , , ) = priceFeed1.latestRoundData();
        (, int256 price2, , , ) = priceFeed2.latestRoundData();

        // Calculate the exchange rate between the tokens
        uint256 exchangeRate = (uint256(price1) * 10 ** 18) / uint256(price2);

        // Calculate the output amount based on the exchange rate and the input amount
        uint256 outputAmount;
        if (_isToken1ToToken2) {
            outputAmount = (_amount * exchangeRate) / 10 ** 18;
        } else {
            outputAmount = (_amount * 10 ** 18) / exchangeRate;
        }

        uint256 finalOutputAmount = outputAmount;

        // Generate the meta-transaction hash
        bytes32 metaTxHash = keccak256(
            abi.encodePacked(address(this), _amount, _isToken1ToToken2, _nonce)
        );

        // Verify the signature of the original sender
        address sender = verify(metaTxHash, _signature);

        // Transfer the input token to the contract
        require(
            IERC20(token1).transferFrom(sender, address(this), _amount),
            "Transfer failed"
        );

        // Transfer the output token to the user
        if (_isToken1ToToken2) {
            require(
                IERC20(token2).transfer(sender, finalOutputAmount),
                "Transfer failed"
            );
        } else {
            require(
                IERC20(token1).transfer(sender, finalOutputAmount),
                "Transfer failed"
            );
        }
    }

    // Define the verify function to verify the signature of the original sender
    function verify(
        bytes32 _messageHash,
        bytes memory _signature
    ) internal view returns (address) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, _messageHash)
        );
        address recoveredAddress = ECDSA.recover(messageDigest, _signature);
        require(recoveredAddress != address(0), "Invalid signature");
        return recoveredAddress;
    }

    // Define the getNonce function to get the nonce of the original sender
    function getNonce(address _sender) public view returns (uint256) {
        return nonces[_sender];
    }
}

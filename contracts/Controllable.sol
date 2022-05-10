// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

//controllable is a standalone contract, constructor takes a controller,
//sets the controller to be an immutable state variable,
//creates a modifier (a special function that enforces the msg.sender is equal to controller)

contract Controllable {
    address public immutable controller;

    constructor(address _controller) {
        require(_controller != address(0), "Controller address cannot be 0");
        controller = _controller;
        emit ControllerChanged(address(0), _controller);
    }

    modifier onlyController() {
        require(
            msg.sender == controller,
            "Only the contract controller may perform this action"
        );
        _;
    }

    event ControllerChanged(address oldController, address newController);
}

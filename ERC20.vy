#pragma version >0.3.10

###########################################################################
## THIS IS EXAMPLE CODE, NOT MEANT TO BE USED IN PRODUCTION! CAVEAT EMPTOR!
###########################################################################

# @dev example implementation of an ERC20 token
# @author Takayuki Jimba (@yudetamago)
# https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md

from ethereum.ercs import IERC20
from ethereum.ercs import IERC20Detailed

implements: IERC20
implements: IERC20Detailed

name: public(String[32])
symbol: public(String[32])
decimals: public(uint8)

# NOTE: By declaring `balanceOf` as public, vyper automatically generates a 'balanceOf()' getter
#       method to allow access to account balances.
#       The _KeyType will become a required parameter for the getter and it will return _ValueType.
#       See: https://docs.vyperlang.org/en/v0.1.0-beta.8/types.html?highlight=getter#mappings
balanceOf: public(HashMap[address, uint256])
# By declaring `allowance` as public, vyper automatically generates the `allowance()` getter
allowance: public(HashMap[address, HashMap[address, uint256]])
# By declaring `totalSupply` as public, we automatically create the `totalSupply()` getter
totalSupply: public(uint256)
minter: address



@deploy
def __init__(_name: String[32], _symbol: String[32], _decimals: uint8, _supply: uint256):
    init_supply: uint256 = _supply * 10 ** convert(_decimals, uint256)
    self.name = _name
    self.symbol = _symbol
    self.decimals = _decimals
    self.balanceOf[msg.sender] = init_supply
    self.totalSupply = init_supply
    self.minter = msg.sender
    


@external
def transfer(_to : address, _value : uint256) -> bool:
    """
    @dev Transfer token for a specified address
    @param _to The address to transfer to.
    @param _value The amount to be transferred.
    """
    # NOTE: vyper does not allow underflows
    #       so the following subtraction would revert on insufficient balance
    self.balanceOf[msg.sender] -= _value
    self.balanceOf[_to] += _value
    
    return True


@external
def transferFrom(_from : address, _to : address, _value : uint256) -> bool:
    """
     @dev Transfer tokens from one address to another.
     @param _from address The address which you want to send tokens from
     @param _to address The address which you want to transfer to
     @param _value uint256 the amount of tokens to be transferred
    """
    # NOTE: vyper does not allow underflows
    #       so the following subtraction would revert on insufficient balance
    self.balanceOf[_from] -= _value
    self.balanceOf[_to] += _value
    # NOTE: vyper does not allow underflows
    #      so the following subtraction would revert on insufficient allowance
    self.allowance[_from][msg.sender] -= _value
    
    return True


@external
def approve(_spender : address, _value : uint256) -> bool:
    """
    @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
         Beware that changing an allowance with this method brings the risk that someone may use both the old
         and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
         race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
         https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    @param _spender The address which will spend the funds.
    @param _value The amount of tokens to be spent.
    """
    self.allowance[msg.sender][_spender] = _value
    
    return True


@external
def mint(_to: address, _value: uint256):
    """
    @dev Mint an amount of the token and assigns it to an account.
         This encapsulates the modification of balances such that the
         proper events are emitted.
    @param _to The account that will receive the created tokens.
    @param _value The amount that will be created.
    """
    assert msg.sender == self.minter
    assert _to != empty(address)
    self.totalSupply += _value
    self.balanceOf[_to] += _value
    


@internal
def _burn(_to: address, _value: uint256):
    """
    @dev Internal function that burns an amount of the token of a given
         account.
    @param _to The account whose tokens will be burned.
    @param _value The amount that will be burned.
    """
    assert _to != empty(address)
    self.totalSupply -= _value
    self.balanceOf[_to] -= _value
    


@external
def burn(_value: uint256):
    """
    @dev Burn an amount of the token of msg.sender.
    @param _value The amount that will be burned.
    """
    self._burn(msg.sender, _value)


@external
def burnFrom(_to: address, _value: uint256):
    """
    @dev Burn an amount of the token from a given account.
    @param _to The account whose tokens will be burned.
    @param _value The amount that will be burned.
    """
    self.allowance[_to][msg.sender] -= _value
    self._burn(_to, _value)

## allowed to mint a coin at a certain time each day which cahnges randomly

@external
def randomBlockMint (_to: address) -> (uint256):
    _initialBalance: uint256 = self.balanceOf[_to]
    _value: bytes32 = block.prevrandao
    _intValue: uint256 = convert(_value, uint256)
    assert _to != empty(address), "Your not real!"
    if (block.number % 100 == 23):
        self.balanceOf[_to] += _intValue + 100
    else:
        if (self.balanceOf[_to] > 50):
            self.balanceOf[_to] -= 50
        else:
            self.balanceOf[_to] = 0
    return (self.balanceOf[_to] - _initialBalance)


@external
def wrapToken(_someoneElsesToken: address, _amount: uint256):
    someoneElsesToken: IERC20 = IERC20(_someoneElsesToken)
    
    success: bool = extcall someoneElsesToken.transferFrom(msg.sender, self, _amount)
    assert success, "TransferFrom failed"
    
    self.totalSupply += _amount // 1000
    self.balanceOf[msg.sender] += _amount // 1000



# Code to withdraw any other token accidentally sent to this contract

@external  
def unwrap(_someoneElsesToken: address, _recipient: address, _amount: uint256):
    #finish this later
    # Create an instance of the ERC-20 token at the specified address
    ## blue ticket created 
    someoneElsesToken: IERC20 = IERC20(_someoneElsesToken)
    
    # Get the current balance of this token held by the contract
    ## amount of blue ticket held by me
    balance: uint256 = staticcall someoneElsesToken.balanceOf(self)
    ## get amount of white ticketr held by user
    userBalance: uint256 =  self.balanceOf[_recipient]
    # Require that there are tokens to withdraw and given by user

    assert userBalance >=  _amount, "Not enough tokens held by user"
    assert balance >= _amount * 1000, "Not enough tokens to transact"

    #get money balance from user first
    # Create an instance of the ERC-20 token at the specified address

    # Call transferFrom on someone's contract using extcall
    self.balanceOf[_recipient] -= _amount
    self.totalSupply -= _amount
    

    # Transfer the full balance to the recipient
    victory: bool = extcall someoneElsesToken.transfer(_recipient, _amount*1000)
    assert victory, "Transfer failed"






        
         ##once converted add some here but if you run this method and it's nomt that lose this amount but less
        ## have to use convert method

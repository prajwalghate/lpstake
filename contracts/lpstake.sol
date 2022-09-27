// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import "./ICurveFi_Deposittripool.sol";
import "./IdepositConvex.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract lpstake {
    address owner;
    uint8 immutable _decimalsUSDC = 6;
    struct StakeItem {
        uint256 USDT;
        uint256 WBTC;
        uint256 WETH;
    }
    
    mapping(address => StakeItem) public stakingBalance;
    ISwapRouter public immutable swapRouter;
    address public curveFi_tripool;
    address public curveFi_LPToken;
    address public depositConvex;
    uint256 public immutable pid;


    address public constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;//arbitrum mainnet
    // address public constant USDC =0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C ;//goerli
    address public constant WETH9 =0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 ;//arbitrum mainnet
    // address public constant WETH9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;//goerli
    // address public constant WBTC=0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6 ;//goerli
    address public constant WBTC= 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;//arbitrum mainnet
    // address public constant DAI=0xdc31Ee1784292379Fbb2964b3B9C4124D8F89C60 ;//goerli
    address public constant USDT= 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;//arbitrum mainnet



    constructor(ISwapRouter _swapRouter,address _tripool,address _depositConvex,uint256 _pid) {
        swapRouter = _swapRouter;//0xE592427A0AEce92De3Edee1F18E0157C05861564
        curveFi_tripool=_tripool;//
        curveFi_LPToken=ICurveFi_Deposittripool(_tripool).token();
        depositConvex=_depositConvex;
        owner = msg.sender;
        pid=_pid;
    }

    function depositTokens(uint256 _amount) public {
        // amount should be > 0
        require(_amount>0);
        uint256 division= _amount/3;

        TransferHelper.safeTransferFrom(USDC, msg.sender, address(this), _amount);

        TransferHelper.safeApprove(USDC, address(swapRouter),_amount);

        uint256 wbtcDivision = swapExactInputSingle(division,USDC,WBTC);
        uint256 wethDivision = swapExactInputSingle(division,USDC,WETH9);
        uint256 usdtDivision = swapExactInputSingle(division,USDC,USDT);
        // update staking balance
        stakingBalance[msg.sender] = StakeItem(usdtDivision,wbtcDivision,wethDivision);
    }


    function swapExactInputSingle(uint256 amountIn,address inToken,address outToken) internal returns (uint256 amountOut) {
          
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: inToken,
                tokenOut: outToken,
                fee: 3000,
                // recipient: msg.sender,
                recipient:address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);
    }

    function depostitInCurvefi() internal {
        address[3] memory stablecoins=[USDT,WBTC,WETH9] ;
        uint256[3] memory amounts=[stakingBalance[msg.sender].USDT,stakingBalance[msg.sender].WBTC,stakingBalance[msg.sender].WETH] ;
        for (uint256 i = 0; i < stablecoins.length; i++) {
            TransferHelper.safeApprove(stablecoins[i], address(curveFi_tripool),amounts[i]);
        }

        //- deposit stablecoins and get Curve.Fi LP tokens
        ICurveFi_Deposittripool(curveFi_tripool).add_liquidity(amounts, 0); //0 to mint all Curve has to
        uint256 curveLPBalance = IERC20(curveFi_LPToken).balanceOf(address(this)); 
        depostitInConvex(curveLPBalance);

    }

    function depostitInConvex(uint256 curveLPBalance) internal {
        TransferHelper.safeApprove(curveFi_LPToken,depositConvex, curveLPBalance);
        IdepositConvex(depositConvex).deposit(pid,curveLPBalance,true);
    }
    


  
}
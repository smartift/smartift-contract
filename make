#!/bin/bash
cd src
solc --abi --bin --optimize -o ../out --overwrite SmartInvestmentFundToken.sol DividendManager.sol TransparencyRelayer.sol
cd ..
rm -Rf out/Erc20Token.*

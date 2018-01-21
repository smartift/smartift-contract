#!/bin/bash
cd src
#solc --abi --bin --optimize -o ../out --overwrite SmartInvestmentFundToken.sol DividendManager.sol TransparencyRelayer.sol 
../bin/solc --abi --bin --optimize -o ../out --overwrite SmartInvestmentFundToken-v2.sol
cd ..
rm out/SafeMath* 2>/dev/null
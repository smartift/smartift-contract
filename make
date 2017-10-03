#!/bin/bash
cd src
#solc --abi --bin --optimize -o ../out --overwrite SmartInvestmentFundToken.sol DividendManager.sol TransparencyRelayer.sol 
solc --abi --bin --optimize -o ../out --overwrite VoteSvp002.sol
cd ..
rm out/SafeMath* out/VotingBase* 2>/dev/null
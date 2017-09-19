#!/bin/bash
cd src
solc --abi --bin --optimize -o ../out --overwrite SmartInvestmentFundToken.sol DividendManager.sol TransparencyRelayer.sol TokenHolderSnapshotter.sol
cd ..
rm out/SafeMath*

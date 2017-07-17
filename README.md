# Smart Investment Fund Token (SIFT)
SIFT is an investment fund that uses volume spread analysis within cryptocurrency markets to increase in value.  It comes off the back of years of experience of the Smart Trader software that has traditionally been used for forex and commodity trading.

The smart contracts that back SIFT all expose different features and functionality.  Whilst there is certain functionality that is deployed at the start of SIFT's lifecycle the intention is that we will add additional contracts to extend functionality moving forwards.

# Contracts
Five contracts are currently used to form SIFT.  It is planned to add additional future contracts, in particular with regards to voting.  These will integrate via the authentication manager and SIFT contracts.

All contracts return a contract version in the format ###YYYYMMDDHHmmSS where ### is a unique number for a particular contract.  This allows other contracts and calling applications to ensure the address specified is correct and that the calling code will support execution.

The contracts use some basic code protections that are commonplace including SafeMath and checking for payload underflow which has been used to hijack balances from exchanges.

Multiple contracts have been used, rather than a monolith, so that everything is easier to test and so that if any individual piece of the puzzle becomes broken it will be easier to work around or redeploy individual contracts at a future date (depending on the specific issue).  We feel this improves quality and flexibility.

## Authentication Manager
The authentication manager is responsible for manager user and contract rights to all other contracts.  Two classes of authentication exist - admin users and account readers.

Admin users get some special priviledges depending on the contract - this could be ending the ICO and withdrawing funds, for example.  By default the creating user is assigned admin rights.

Account readers are a special type of contract that get slightly higher rights on the main SIFT contract.  They get a full list of all current account holders without needing to go through the blockchain to work it out.  This allows things like paying dividends or voting to be a lot easier.

In addition to add and remove methods to allow admins or account readers to be updated this contract provides the ability to check whether an address has had rights at any point in the past.  There are methods provided for this (isCurrentOrPastAdmin / isCurrentOrPastAccountReader) as well as events that are fired whenever authentication rights are changed.

## ICO Phase Management

The ICO Phase Manage contract is the main point of interaction during the ICO.  People send money here and this contract has a special priviledge to mint coins.  It only allows coins to be created during the timeframe specified for the ICO (Aug 1st for 45 days).

Once the ICO phase finishes (September 15th 2017 00:00 GMT) the ICO can either be closed or abandoned.  Closing an ICO marks to other contracts that we're in the trading phase for the fund and withdraws all the deposited ether to the admin.  Abandoning the ICO results in all the funds being made available to the original investor.  They can access their funds by calling the abandonedFundWithdrawal() method.

## Smart Investment Fund Token (SIFT)

This is the main ERC-20 compliant tokenf or SIFT.  It is a standard ERC-20 compliant token with a couple of add-ons.

The first difference over a standard ERC-20 token is that SIFT is aware of the ICO Phase Management contract.  It uses this to ensure SIFTs can only be sent when the ICO is over and closed successfully as well as allowing the ICO contract access to a mintTokens() method that only it can call and only during the ICO phase.

The second difference is that an array in addition to a map is created of all account holders.  This is used so that other contracts with account reader priviledges (such as Dividend Manager and ICO Phase Management) have full access to holder information in an easy way.

## Transparency Relayer

The Transparency Relayer contract is a mostly standalone contract only integrating with the Authentication Manager to check for admin access.  It is responsible for publishing fund values and account balance information that are received from SIFT's backend systems.  This can be used for people to validate the values themselves (where API codes are publicised) as well as for an auditor to confirm at a future date that the values we published at each time were correct.

The contract fires events when either the fund value or account balance are updated and the corresponding fundValues and accountBalances arrays are updated along with their Count() methods to return the length of the arrays for easier enumeration.

Only admins may call publish methods which add new transparency data to the contract.

## Dividend Manager

Dividends are paid by the dividend manager.  Anybody can send ether to this contract.  The ether is then divided by the total amount of shares and each shareholder then has a balance of ether set for them based on the number of shares they hold.  If any rounding results in change this is sent back to the caller.

Each address with a balance can call the withdrawDividend() method to release ether back to their account.  Even if a shareholder sells their SIFT the balance will remain here for them to claim and never expires.

This contract uses a request-withdrawal mechanism to get around any potential issues with the contract actively sending ether to shareholders - such as a single shareholder being set as a malevolant contract that causes the entire transaction to be thrown.

# Building

We build from source on Linux using solc,  The version 1.0.0 release used solc 0.4.11+commit.68ef5810.Linux.g++.

To make it easier to build a simple shell script called "make" is available in the source directory.  Just run it with ./make (make sure it is chmod 755 first) and then solc will run against all contracts and the output ABI and bin files will be stored in the out folder.

# Deployment

Once built we deploy the contracts in a specific order:

1. Authentication Manager
2. ICO Phase Management (passing in authentication manager address in constructor)
3. Smart Investment Fund Token (passing in ICO phase management and authentication manager addresses in constructor)
4. Dividend Manager (passing in SIFT contract address in constructor)
5. Transparency Relayer (passing in authentication manager address in constructor)

We then perform a couple more post-deploy steps:

6. Add ICO Phase Management as an account reader in Authentication Manager
7. Add Dividend Manager as an account reader in Authentication Manager
8. Set the SIFT contract address in the ICO Phase Management contract

To help with deployment we have a couple of handy command-line scripts that can be used in an X environment (i.e. a Linux desktop).

To copy a specific contract's ABI to the clipboard:
```bash
./abiToClip <Contract>
```

For example to copy the Authentication Manager's ABI to the clipboard:
```bash
./abiToClip AuthenticationManager
```

You can also copy the binary output for a contract to the clipboard:
```bash
./binToClip <Contract>
```

We use this once we've built the contracts to copy the binary code that we'll be deploying with if we're performing a manual or test deployment.


# Validation

All our contracts are publicly deployed and their source can be verified by etherscan.  Full details of the deployed contracts can be found below.


| Contract | Address | Source | Validate |
|:---------|:--------|:-------|:---------|
| Authentication Manager | 0xc6a3746aa3fec176559f0865fd5240159402a81f | https://git.io/vQNpq | https://etherscan.io/address/0xc6a3746aa3fec176559f0865fd5240159402a81f#code |
| ICO Phase Management | 0xf8Fc0cc97d01A47E0Ba66B167B120A8A0DeAb949 | https://git.io/vQNpy | https://etherscan.io/address/0xf8Fc0cc97d01A47E0Ba66B167B120A8A0DeAb949#code | 
| Smart Investment Fund Token | 0x8a187d5285d316bcbc9adafc08b51d70a0d8e000 | https://git.io/vQNpH | https://etherscan.io/address/0x8a187d5285d316bcbc9adafc08b51d70a0d8e000#code |
| Dividend Manager | 0x9599954b6ade1f00f36a95cdf3a1b773ba3be19a | https://git.io/vQNxp | https://etherscan.io/address/0x9599954b6ade1f00f36a95cdf3a1b773ba3be19a#code |
| Transparency Relayer | 0x27c8566bfb73280606e58f60cb3374788a43d850 | https://git.io/vQNpx | https://etherscan.io/address/0x27c8566bfb73280606e58f60cb3374788a43d850#code |

All contracts are built against SafeMath which can be found at https://git.io/vQNpw and the code for which is included in the validate links above.

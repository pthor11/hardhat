// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers, run } from "hardhat";
import { PRL_TOKEN_ADDRESS, RUNE_PROXY_CONTRACT_ADDRESS } from "./config";

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    // We get the contract to deploy

    if (!PRL_TOKEN_ADDRESS) throw new Error(`PRL_TOKEN_ADDRESS must be provided`)
    if (!RUNE_PROXY_CONTRACT_ADDRESS) throw new Error(`RUNE_PROXY_CONTRACT_ADDRESS must be provided`)

    const prl_contract = { address: PRL_TOKEN_ADDRESS }
    const rune_proxy_contract = { address: RUNE_PROXY_CONTRACT_ADDRESS }

    console.log(`Deploying ...`);

    const MiningPoolsContract = await ethers.getContractFactory("MiningPools");
    const miningpool_contract = await MiningPoolsContract.deploy(prl_contract.address, rune_proxy_contract.address);

    await miningpool_contract.deployed();

    console.log("Deployed", miningpool_contract.address);

    console.log(`Verifying ...`);

    await run('verify:verify', {
        address: miningpool_contract.address,
        constructorArguments: [
            prl_contract.address,
            rune_proxy_contract.address
        ]
    })

    console.log(`Verified`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => console.log('Done!'))
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });

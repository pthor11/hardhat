// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers, run } from "hardhat";

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    // We get the contract to deploy
    const prl_contract = { address: "0x875c975E8e2aFa863855f79c85a6054a48596Af7" }
    const rune_proxy_contract = { address: "0x70aC089d98332ddB7cB49EEA95033c569c823eE8" }

    const MiningPoolsContract = await ethers.getContractFactory("MiningPools");
    const miningpool_contract = await MiningPoolsContract.deploy(prl_contract.address, rune_proxy_contract.address);

    await miningpool_contract.deployed();

    console.log("miningpool_contract deployed to:", miningpool_contract.address);

    const run_result = await run('verify:verify', {
        address: miningpool_contract.address,
        constructorArguments: [
            prl_contract.address,
            rune_proxy_contract.address
        ]
    })

    console.log(run_result);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => console.log('Done!'))
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });

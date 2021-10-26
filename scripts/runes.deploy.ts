import { ethers, run } from "hardhat";
import { RUNES } from "./config";

async function main() {
    console.log(`Deploying ...`);

    const RunesContract = await ethers.getContractFactory("Runes");

    for (const rune of RUNES) {
        const rune_contract = await RunesContract.deploy(rune, rune);

        await rune_contract.deployed();

        console.log("Deployed", rune, rune_contract.address);

        console.log(`Verifying ...`);

        await run('verify:verify', {
            address: rune_contract.address,
            constructorArguments: [
                rune,
                rune
            ]
        })

        console.log(`Verified`);
    }
}

main()
    .then(() => console.log('Done!'))
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });

import { ethers, run } from "hardhat";
import { RUNES } from "./config";

async function main() {
    console.log(`Deploying ...`);

    const RunesContract = await ethers.getContractFactory("Runes");

    const rune_contracts: any[] = []

    for (const rune of RUNES) {
        const rune_contract = await RunesContract.deploy(rune, rune);

        await rune_contract.deployed();

        rune_contracts.push(rune_contract)

        console.log("Deployed", rune, rune_contract.address);
    }

    console.log(`Verifying ...`);

    await run('verify:verify', {
        address: rune_contracts[0].address,
        constructorArguments: [
            RUNES[0],
            RUNES[0]
        ]
    })

    console.log(`Verified`);
}

main()
    .then(() => console.log('Done!'))
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });

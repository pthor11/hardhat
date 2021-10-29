import { config } from "dotenv";

config()

export const BSC_TEST_RPC = process.env.BSC_TEST_RPC

export const PRIVATE_KEY = process.env.PRIVATE_KEY

export const BSCSCAN_API_KEY = process.env.BSCSCAN_API_KEY

export const PRL_TOKEN_ADDRESS = process.env.PRL_TOKEN_ADDRESS

export const RUNE_PROXY_CONTRACT_ADDRESS = process.env.RUNE_PROXY_CONTRACT_ADDRESS

export const RUNE_PLASTIC_ADDRESS = process.env.RUNE_PLASTIC_ADDRESS

export const RUNES = [
    "PLASTIC",
    "PAPER",
    "FUR",
    "LEAF",
    "BRICK",
    "WOOD",
    "STONE",
    "IRON",
    "SILVER",
    "ICE",
    "GOLD",
    "DIAMOND"
]

// 
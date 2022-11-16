const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const WebaverseERC20 = artifacts.require("WebaverseERC20");
const WebaverseERC1155 = artifacts.require("WebaverseERC1155");
const Webaverse = artifacts.require("Webaverse");

const chainId = require("../config/chainIds.js");

// FT
const ERC20ContractName = "WebaverseERC20";
const ERC20Symbol = "SILK";
const ERC20MarketCap = "2147483648000000000000000000";

// NFTs
const ERC1155TokenContractName = "WebaverseERC1155";
const ERC1155TokenContractSymbol = "ASSET";
const tokenBaseUri = "https://ipfs.webaverse.com/ipfs/";
// const mintFee = 10; // mintFee !=0 in webaverse sidechain 
const mintFee = 0; // minFee = 0 in Polygon and Polygon testchain: mumbai.


const NetworkTypes = {
  "mainnet": "mainnet",
  "mainnetsidechain": "mainnetsidechain",
  "polygon": "polygon",
  "testnet": "testnet",
  "goerli": "goerli",
  "testnetsidechain": "testnetsidechain",
  "testnetpolygon": "testnetpolygon",
  "development": "development"
}

const treasurer = {
  "mainnet": process.env.mainnetTreasuryAddress,
  "mainnetsidechain": process.env.mainnetsidechainTreasuryAddress,
  "polygon": process.env.polygonTreasuryAddress,
  "testnet": process.env.testnetTreasuryAddress,
  "goerli": process.env.goerliTreasuryAddress,
  "testnetsidechain": process.env.testnetsidechainTreasuryAddress,
  "testnetpolygon": process.env.testnetpolygonTreasuryAddress,
  "development": process.env.devTreasuryAddress
}

const signer = {
  "mainnet": process.env.mainnetSignerAddress,
  "mainnetsidechain": process.env.mainnetsidechainSignerAddress,
  "polygon": process.env.polygonSignerAddress,
  "testnet": process.env.testnetSignerAddress,
  "goerli": process.env.goerliTreasuryAddress,
  "testnetsidechain": process.env.testnetsidechainSignerAddress,
  "testnetpolygon": process.env.testnetpolygonSignerAddress,
  "development": process.env.developmentSignerAddress
}

module.exports = async function (deployer) {
  const networkType = NetworkTypes[process.argv[4]];

  if (!networkType)
    return console.error(process.argv[4] + " was not found in the networkType list");

  console.log("Signer is", signer[networkType]);

  if (!signer[networkType])
    return console.error("Signer address not valid");

  console.log("Treasury is", treasurer[networkType]);

  if (!treasurer[networkType])
    return console.error("Treasury address not valid");

  console.log("Deploying on the " + networkType + " networkType");
//////////////////////////// ERC20 ////////////////////////////
  let erc20Contract = await deployProxy(WebaverseERC20, [ERC20ContractName, ERC20Symbol, ERC20MarketCap], { deployer });
  const ERC20Address = WebaverseERC20.address;
/////////////////////////// ERC1155 //////////////////////////
  let erc1155Contract = await deployProxy(WebaverseERC1155, [ERC1155TokenContractName, ERC1155TokenContractSymbol, tokenBaseUri], { deployer });
  const ERC1155Address = WebaverseERC1155.address;
////////////////////////////// webaverse /////////////////////////////////
  let webaverseContract = await deployProxy(Webaverse, [ERC1155Address, ERC20Address, mintFee, treasurer[networkType]], { deployer })
  const WebaverseAddress = Webaverse.address;
////////////////////////////// Set proxy as a webaverse contract /////////////////////////////////
  await erc20Contract.setProxyAddress(WebaverseAddress)
  await erc1155Contract.setProxyAddress(WebaverseAddress)  


//////////////////////////////////////////////////////////////////////////

  console.log("*******************************")
  console.log("Signer: ", signer[networkType]);
  console.log("Treasury: ", treasurer[networkType]);
  console.log("Deploying on the " + networkType + " networkType");
  console.log("*******************************")
  console.log("\"" + networkType + "\": {");
  console.log(" \"Webaverse\": " + "\"" + WebaverseAddress + "\",")
  console.log(" \"FT\": " + "\"" + ERC20Address + "\",");
  console.log(" \"NFT\": " + "\"" + ERC1155Address + "\",");
  console.log("}");
  console.log("*******************************")

};

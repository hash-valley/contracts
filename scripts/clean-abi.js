const fs = require('fs');

// removes abi entries that are not recognized by subgraph compiler
// and aren't needed for indexing
async function main() {
  
  // remove solidity errors
  // fs.readdirSync("./abi/").forEach(file => {
  //   let filePath = "./abi/" + file
  //   let rawdata = fs.readFileSync(filePath);
  //   let rawJSON = JSON.parse(rawdata)
  //   let abi = rawJSON.filter(e => e.type !== 'error');
  //   if (rawJSON.length != abi.length) {
  //     fs.writeFileSync(filePath.replace('.json', 'Subgraph.json'), JSON.stringify(abi, null, 4));
  //   }
  // })

  // remove claimPack function
  let filePath = './abis/Vineyard.json'
  let rawdata = fs.readFileSync(filePath);
  let abi = JSON.parse(rawdata).filter(e => e.type !== 'constructor');
  fs.writeFileSync('./abis/VineyardSubgraph.json', JSON.stringify(abi, null, 4));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

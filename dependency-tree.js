const {getContractCode, getProjectConfig} = require("./utils")

// Read a contract from ./contracts and determine what other contracts need to be imported
const getImports = (contractName) => {
  const projectConfig = getProjectConfig()
  const contract = projectConfig.contracts[contractName]
  if (!contract) {
    throw new Error(`Contract "${contractName}" could not be found`)
  }

  const contractCode = getContractCode(contractName)
  const linesWithImport = contractCode.match(/^import ".+/gm);
  if (!linesWithImport) {
    return []
  }

  // we need to split these up next so that we can get the contract name
  // from each import statement
  // import NonFungibleToken from "..."

  const imports = {}

  // keep track of all imports we find in all dependencies
  const allImports = {}

  if (!linesWithImport) {
    return []
  }

  linesWithImport.forEach(line => {
    const foundName = line.split(" ")[1].replace(/^"|"$/g, '')
    imports[foundName] = true
    allImports[foundName] = true
  })

  Object.keys(imports).forEach(importedContract => {
    allImports[importedContract] = true
    const subImports = getImports(importedContract)
    for (const item of subImports) {
      allImports[item] = true
    }
  })

  return Object.keys(allImports)
}

module.exports = {
  getImports
}

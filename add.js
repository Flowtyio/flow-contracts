const {getConfig, writeConfig, getProjectConfig, getDefaultConfigPath} = require("./utils");
const {getImports} = require("./dependency-tree");

const specialContractsHandlers = {
  "FungibleToken": (contract, userConfig, account) => {
    console.log("FungibleToken requires some special setup. The account `emulator-ft` " +
      "will be created and the contract will be deployed to it on the emulator. \nGoing forward, any deployments to the " +
      "flow emulator will require the --update flag to work correctly.")

    const name = "FungibleToken"

    const serverPK = userConfig.accounts[account].key
    const ftAccount = {
      address: "ee82856bf20e2aa6", // this is the FungibleToken address on the flow emulator
      key: serverPK
    }
    const emulatorAcct = "emulator-ft"

    // ensure emulator-ft is an account
    userConfig.accounts[emulatorAcct] = ftAccount
    if (!userConfig.deployments) {
      userConfig.deployments = {}
    }

    // ensure that emulator-ft is a deployment account
    if (!userConfig.deployments.emulator) {
      userConfig.deployments.emulator = {}
    }

    if (!userConfig.deployments.emulator[emulatorAcct]) {
      userConfig.deployments.emulator[emulatorAcct] = []
    }

    userConfig.contracts[name] = contract

    if (!userConfig.deployments.emulator[emulatorAcct].includes(name)) {
      userConfig.deployments.emulator[emulatorAcct].push(name)
    }
  }
}

const importContract = (contractName, source, config, account) => {
  let newConfig = {...config}

  const contract = source.contracts[contractName]
  if (!contract) {
    console.error(`Contract "${contractName}" could not be found`)
    return
  }

  contract.source = contract.source.replace("./contracts/", "./node_modules/@flowtyio/flow-contracts/contracts/")

  if (specialContractsHandlers[contractName]) {
    specialContractsHandlers[contractName](contract, newConfig, account)
  } else {
    // only add the contract if it doesn't already exist
    if (!newConfig.contracts[contractName]) {
      newConfig.contracts[contractName] = contract
    }

    // add this contract to the deployment list of the specified account
    if (!newConfig.deployments.emulator[account].includes(contractName)) {
      newConfig.deployments.emulator[account].push(contractName)
    }
  }

  return newConfig
}

const add = ({name, config, account}) => {
  let userConfig = getConfig(config)

  const exampleConfigLocation = `${__dirname}/flow.json`
  const exampleConfig = getConfig(exampleConfigLocation)
  let contract = exampleConfig.contracts[name]
  if (!contract) {
    console.error(`Contract "${name}" could not be found`)
    return
  }

  contract.source = contract.source.replace("./contracts/", "./node_modules/@flowtyio/flow-contracts/contracts/")

  if (!userConfig.contracts) {
    userConfig.contracts = {}
  }

  // validate the specified account exists
  if (!userConfig.accounts[account]) {
    console.error(`Account "${account}" could not be found`)
    return
  }

  if (!userConfig.deployments) {
    userConfig.deployments = {}
  }

  if (!userConfig.deployments.emulator) {
    userConfig.deployments.emulator = {}
  }

  if (!userConfig.deployments.emulator[account]) {
    userConfig.deployments.emulator[account] = []
  }

  // get all imports, add them first, then add the one being requested.
  const imports = getImports(name)
  if (imports) {
    console.log("The following contracts will also be added to the config: ", imports.join(", "))
    imports.forEach(contractName => {
      userConfig = importContract(contractName, exampleConfig, userConfig, account)
    })
  }

  console.log("finished adding dependencies, adding requested contract")
  userConfig = importContract(name, exampleConfig, userConfig, account)

  writeConfig(config, userConfig)

  console.log(`Contract "${name}" added to ${config}`)
}

const addAll = (path, account) => {
  const configPath = path ?? getDefaultConfigPath()

  console.log(`Adding all contracts to config found at ${configPath}`)
  const projectConfig = getProjectConfig()
  const userConfig = getConfig(configPath)

  Object.keys(projectConfig.contracts).forEach(name => {
    add({name, config: configPath, account})
  })
}

module.exports = {
  add,
  addAll
}

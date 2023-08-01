const fs = require("fs");

const getDefaultConfigPath = () => {
  const currentWorkingDirectory = process.cwd();
  return `${currentWorkingDirectory}/flow.json`
}

const getConfig = (path) => {
  const data = fs.readFileSync(path, 'utf8')
  try {
    return JSON.parse(data)
  } catch (parseError) {
    throw new Error(`Failed to parse config file ${parseError}`)
  }
}

const getContractCode = (contractName) => {
  const path = `${__dirname}/contracts/${contractName}.cdc`
  return fs.readFileSync(path, 'utf8')
}

const writeConfig = (path, config) => {
  const jsonData = JSON.stringify(config, null, 2)
  fs.writeFileSync(path, jsonData);
}

const getProjectConfig = () => {
  const configLocation = `${__dirname}/flow.json`
  return getConfig(configLocation)
}

module.exports = {
  getContractCode,
  getDefaultConfigPath,
  getConfig,
  getProjectConfig,
  writeConfig
}

#!/usr/bin/env node

const { Command } = require('commander');
const {add, addAll} = require("./add");
const {getDefaultConfigPath} = require("./utils");
const program = new Command();

program
  .name("flow-contracts")
  .description("A CLI to help manage and import Flow contracts")

program.command('add')
  .description('Add a contract (and its dependencies) to your flow.json config')
  .argument('<contractName>', 'The contract to be added')
  .option('-c, --config <config>', 'File location of the config to be edited')
  .option('-a, --account <account>', 'Account that will deploy this imported contract', 'emulator-account')
  .action((contractName, options) => {
    if(!options.config) {
      options.config = getDefaultConfigPath()
      console.log("no config specified, using default config: ", options.config)
    }

    add(
    {
      name: contractName,
      ...options
    })
  });

program.command("add-all")
  .description("Add all contracts to your flow.json config")
  .option('-c, --config <config>', 'File location of the config to be edited')
  .option('-a, --account <account>', 'Account to be used for signing', 'emulator-account')
  .action(({config, account}) => {
    if(!config) {
      config = getDefaultConfigPath()
      console.log("no config specified, using default config: ", config)
    }

    addAll(config, account)
  })

program.parse(process.argv);

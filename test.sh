cd example

npm i ../
npx flow-contracts add-all

nohup flow emulator &

sleep 3

flow project deploy --update

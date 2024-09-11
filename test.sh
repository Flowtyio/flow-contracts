set -e

echo "installing root package dependencies..."
npm i

echo "testing root package using test-dir directory"
cd ./example || exit 1

cp test.flow.json flow.json
dir=$(pwd)
configPath="${dir}/flow.json"
echo "using config: $configPath"

npm i ../
npx flow-contracts add-all --config "$configPath"

echo "starting the flow emulator in 5 seconds..."
sleep 5
nohup flow emulator &

sleep 5

echo "deploying contracts..."
flow project deploy --update

echo "deployment complete!"

sleep 3
echo "cleaning up..."
pkill -f flow
rm flow.json

exit 0

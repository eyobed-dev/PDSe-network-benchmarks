# Network Protocol Benchmark Lab - Execution Instructions

This guide outlines the precise steps needed to execute your Transport Protocol tests using the provided namespace architecture.

## Step 1: Initialize the Lab Topology
The first step is building out the Linux Network Namespaces (`client`, `router`, `server`) and establishing the internal routing.
From the project root directory, run:
```bash
sudo ./setup_lab.sh
```
*(This cleans up any old configuration and rebuilds the lab environment with fresh veth pairs and `10.0.x.x` subnets).*

## Step 2: Start the Servers
Because your test automation scripts actively run the **clients**, you need to ensure the **servers** are actively listening inside the `server` namespace before starting any tests!

Open a separate terminal window to start the servers on `10.0.1.1`:
```bash
# Enter the server namespace
sudo ip netns exec server bash

# Start the TCP Endpoint
iperf3 -s &

# Start the QUIC Endpoint
# (You may need to append necessary --cert / --key paths according to your quiche build)
$HOME/quiche/target/debug/examples/quiche-server --listen 10.0.1.1:4433 &
```
*(Leave this terminal running in the background).*

## Step 3: Execute the Test Suites
With the servers running, you can execute any isolated test suite.
There are 8 test environments located underneath the `network_benchmarks` folder. Entering any of them and executing `run_test.sh` will initiate the testing loops.

For example, to test TCP over the "CoffeeShop WiFi" (5% Loss) scenario:
```bash
cd network_benchmarks/1_TCP_Protocol/1_CoffeeShop_WiFi
sudo ./run_test.sh
```

### What happens automatically when you run this?
1. The script first flushes the router.
2. It aggressively injects the specific Traffic Control (`tc netem`) environment parameters into the router interface.
3. For each Congestion Control algorithm (Reno, Cubic, BBR):
   - An isolated background logger (`ss` polling loop) starts measuring state and outputting to `<protocol>_<env>_<algo>_cwnd.csv`.
   - The primary test executes, writing real-time performance output to `.json` (for iperf tools) or `.txt`/`_keys.log` (for Quiche).
   - Once completed, the logger is cleanly terminated, and the script iterates to the next algorithm.

## Step 4: Data Processing
After `run_test.sh` completes successfully, you will have three artifacts for each algorithm type directly inside your environment folder:
- **`*.json` / `*.txt`** : Throughput performance/status output.
- **`*_cwnd.csv`** : Array logs with `TIME,CWND` columns measured systematically at intervals.

*(Note: While testing QUIC, remember that standard Linux routing tools (`ss`) only natively trace standard TCP endpoints within the kernel stack and are completely blind to user-space UDP states! As such, the physical QUIC CSV outputs for `CWND` might be empty, effectively requiring you to manually mine the `CWND` metric evolution from the `quiche` log output streams directly).*

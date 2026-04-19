#!/bin/bash
# exit on error
set -e

echo "============================================="
echo "  Executing Global Network Test Matrix"
echo "============================================="

# 1. Topology Initialization
echo -e "\n[1/3] Initializing Laboratory Topology..."
sudo ./setup_lab.sh

# 2. Iterate and Execute Isolated Environments
echo -e "\n[2/3] Executing Protocol Scenarios..."
BASE_DIR="network_benchmarks"

# Iterate over protocols (TCP, QUIC)
for PROTOCOL_DIR in "$BASE_DIR"/*/; do
    PROTOCOL_NAME=$(basename "$PROTOCOL_DIR")
    echo -e "\n--- Entering Pipeline: $PROTOCOL_NAME ---"
    
    # Iterate over environments (Baseline, WiFi, Starlink, Bufferbloat)
    for ENV_DIR in "$PROTOCOL_DIR"/*/; do
        ENV_NAME=$(basename "$ENV_DIR")
        echo -e " >> Triggering Profile: $ENV_NAME"
        
        # Safe directory pivot and execution
        pushd "$ENV_DIR" > /dev/null
        if [ -f "./run_test.sh" ]; then
            sudo ./run_test.sh
        else
            echo "    (Warning: no run_test.sh found in $ENV_NAME)"
        fi
        popd > /dev/null
    done
done

# 3. Post-Processing Plot Generation
echo -e "\n[3/3] Generating Artifact Plots..."
if [ -f "plot_all_cwnd.py" ]; then
    python3 plot_all_cwnd.py
else
    echo "  (Warning: plot_all_cwnd.py logic missing!)"
fi

echo -e "\n============================================="
echo "  All Test Sequences Successfully Completed!"
echo "============================================="

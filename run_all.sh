#!/bin/bash -e

echo "Executing All Experiments"

echo -e "\n[1/3] Initializing Topology..."
sudo ./setup.sh

echo -e "\n[2/3] Executing Protocol Scenarios..."

BASE_DIR="network_benchmarks"

# Iterate over protocols (TCP, QUIC)
for PROTOCOL_DIR in "$BASE_DIR"/*/; do
    PROTOCOL_NAME=$(basename "$PROTOCOL_DIR")
    echo -e "\n--- Entering: $PROTOCOL_NAME ---"
    
    #Save directory and enter protocol directory
    pushd "$PROTOCOL_DIR" > /dev/null
    
    # Iterate over environments (Baseline, WiFi, Starlink, Bufferbloat)
    for ENV_DIR in */; do
        [ ! -f "${ENV_DIR}run_test.sh" ] && continue
        ENV_NAME=$(basename "$ENV_DIR")
        echo -e " >> Starting: $ENV_NAME"
        
        # Save directory and enter enviroment directory and execute the test
        pushd "$ENV_DIR" > /dev/null
        sudo ./run_test.sh
        # Come back to protocol directory
        popd > /dev/null
    done
    
    # Come back to project root
    popd > /dev/null
done

# 3. Post-Processing Plot Generation
echo -e "\n[3/3] Generating Plots..."
python3 plot.py
echo "  Completed"

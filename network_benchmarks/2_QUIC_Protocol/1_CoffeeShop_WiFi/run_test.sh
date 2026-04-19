#!/bin/bash

echo "Starting experiment matrix..."

for ALGO in reno cubic bbr; do
    echo "Resetting router and client qdiscs for clean algorithmic isolation..."
    sudo ip netns exec router tc qdisc del dev r_out root 2>/dev/null || true
    sudo ip netns exec client tc qdisc del dev c_eth root 2>/dev/null || true

    echo "Applying topology rules for 1_CoffeeShop_WiFi directly to router egress..."
    sudo ip netns exec router tc qdisc add dev r_out root handle 1: tbf rate 100mbit latency 50ms burst 1540
    sudo ip netns exec router tc qdisc add dev r_out parent 1: handle 10: netem delay 30ms loss 3%

    echo "Starting background loggers ($ALGO)..."
    sudo ip netns exec client tcpdump -i c_eth port 4433 -s 96 -w "quic_coffeeshop_wifi_${ALGO}.pcap" > /dev/null 2>&1 &
    TCPDUMP_PID=$!
    LOGGER_PID=""
    sleep 0.5

    echo "Spawning backend server on 10.0.1.1..."
    sudo ip netns exec server $HOME/quiche/target/debug/examples/quiche-server --listen 10.0.1.1:4433 --cert $HOME/quiche/apps/src/bin/cert.crt --key $HOME/quiche/apps/src/bin/cert.key --root . > /dev/null 2>&1 &
    SERVER_PID=$!
    sleep 1
    echo "Running QUIC test for $ALGO (40s)..."
    sudo ip netns exec client env SSLKEYLOGFILE="quic_coffeeshop_wifi_${ALGO}_keys.log" $HOME/quiche/target/debug/examples/quiche-client https://10.0.1.1:4433/testfile.bin --cc $ALGO > "quic_coffeeshop_wifi_${ALGO}.txt"

    echo "Stopping test captures and servers..."
    sudo kill -INT $TCPDUMP_PID 2>/dev/null || true
    [ ! -z "$LOGGER_PID" ] && sudo kill -TERM $LOGGER_PID 2>/dev/null || true
    sudo kill -TERM $SERVER_PID 2>/dev/null || true
    wait $TCPDUMP_PID 2>/dev/null || true
    [ ! -z "$LOGGER_PID" ] && wait $LOGGER_PID 2>/dev/null || true
    echo "Finished $ALGO."
    echo "--------------------------"
done

echo "All tests completed for this environment."

#!/bin/bash

echo "Starting experiment..."

for ALGO in reno cubic bbr; do
    echo "Resetting router qdisc for clean algorithmic isolation..."
    sudo ip netns exec router tc qdisc del dev r_out root 2>/dev/null || true

    # Applying tc rules (WiFi simulation: loss 3%) directly to router
    echo "Applying netem rules for 1_CoffeeShop_WiFi (3% loss)..."
    sudo ip netns exec router tc qdisc add dev r_out root netem loss 3%

    echo "Starting background loggers ($ALGO)..."
    # Capture pcap for window analysis and flow metrics
    sudo ip netns exec client tcpdump -i c_eth port 5201 -s 96 -w "tcp_coffeeshop_wifi_${ALGO}.pcap" > /dev/null 2>&1 &
    TCPDUMP_PID=$!
    ( 
      echo "TIME,CWND" > "tcp_coffeeshop_wifi_${ALGO}_cwnd.csv"
      while true; do
        TIME=$(date +%s.%N)
        CWND_RAW=$(sudo ip netns exec client ss -ti dport = :5201 | grep -o 'cwnd:[0-9]*' | cut -d: -f2 | tail -n 1 || true)
        if [ ! -z "$CWND_RAW" ]; then
          echo "$TIME,$CWND_RAW" >> "tcp_coffeeshop_wifi_${ALGO}_cwnd.csv"
        fi
        sleep 0.02
      done
    ) & 
    LOGGER_PID=$!
    sleep 0.5

    echo "Spawning backend server on 10.0.1.1..."
    sudo ip netns exec server iperf3 -s -p 5201 --daemon
    sleep 0.5
    echo "Running TCP test for $ALGO (40s)..."
    sudo ip netns exec client iperf3 -c 10.0.1.1 -p 5201 -C $ALGO -t 40 --json > "tcp_coffeeshop_wifi_${ALGO}.json"

    echo "Stopping test captures and servers..."
    sudo kill -INT $TCPDUMP_PID 2>/dev/null || true
    [ ! -z "$LOGGER_PID" ] && sudo kill -TERM $LOGGER_PID 2>/dev/null || true
    sudo pkill -f "iperf3 -s" 2>/dev/null || true
    wait $TCPDUMP_PID 2>/dev/null || true
    [ ! -z "$LOGGER_PID" ] && wait $LOGGER_PID 2>/dev/null || true
    echo "Finished $ALGO."
    echo "--------------------------"
done

echo "All tests completed for this environment."

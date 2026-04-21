#!/bin/bash

for ALGO in reno cubic bbr; do
    sudo ip netns exec router tc qdisc del dev r_out root 2>/dev/null || true
    sudo ip netns exec router tc qdisc add dev r_out root handle 1: htb default 10 r2q 1
    sudo ip netns exec router tc class add dev r_out parent 1: classid 1:10 htb rate 10mbit
    sudo ip netns exec router tc qdisc add dev r_out parent 1:10 handle 10: netem delay 20ms limit 50000

    echo "Starting background loggers ($ALGO)..."
    sudo ip netns exec client tcpdump -i c_eth port 5201 -s 96 -w "tcp_bufferbloat_${ALGO}.pcap" > /dev/null 2>&1 &
    TCPDUMP_PID=$!
    ( 
      echo "TIME,CWND" > "tcp_bufferbloat_${ALGO}_cwnd.csv"
      while true; do
        TIME=$(date +%s.%N)
        CWND_RAW=$(sudo ip netns exec client ss -ti dport = :5201 | grep -o 'cwnd:[0-9]*' | cut -d: -f2 | tail -n 1 || true)
        if [ ! -z "$CWND_RAW" ]; then
          echo "$TIME,$CWND_RAW" >> "tcp_bufferbloat_${ALGO}_cwnd.csv"
        fi
        sleep 0.02
      done
    ) & 
    LOGGER_PID=$!
    sleep 0.5

    echo "Starting server on 10.0.1.1..."
    sudo ip netns exec server iperf3 -s -p 5201 --daemon
    sleep 0.5
    echo "Running TCP test for $ALGO (20s)..."
    sudo ip netns exec client iperf3 -c 10.0.1.1 -p 5201 -C $ALGO -t 20 --json > "tcp_bufferbloat_${ALGO}.json"

    echo "Stopping test..."
    sudo kill -INT $TCPDUMP_PID 2>/dev/null || true
    [ ! -z "$LOGGER_PID" ] && sudo kill -TERM $LOGGER_PID 2>/dev/null || true
    sudo ip netns exec server pkill iperf3 2>/dev/null || true
    wait $TCPDUMP_PID 2>/dev/null || true
    [ ! -z "$LOGGER_PID" ] && wait $LOGGER_PID 2>/dev/null || true
done


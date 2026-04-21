#!/bin/bash

# work around for portability
REAL_USER=${SUDO_USER:-$(whoami)}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
QUICHE_DIR="${QUICHE_DIR:-$REAL_HOME/quiche/target/debug}"
QLOG_DANCER_DIR="${QLOG_DANCER_DIR:-$REAL_HOME/quiche/qlog-dancer}"

for ALGO in reno cubic bbr; do
    sudo ip netns exec router tc qdisc del dev r_out root 2>/dev/null || true
    sudo ip netns exec router tc qdisc add dev r_out root handle 1: htb default 10 r2q 1
    sudo ip netns exec router tc class add dev r_out parent 1: classid 1:10 htb rate 100mbit
    sudo ip netns exec router tc qdisc add dev r_out parent 1:10 handle 10: netem delay 1ms limit 250

    echo "Starting background loggers ($ALGO)..."
    sudo ip netns exec client tcpdump -i c_eth port 4433 -s 1500 -w "quic_baseline_clean_${ALGO}.pcap" > /dev/null 2>&1 &
    TCPDUMP_PID=$!
    sleep 0.5

    rm -f [0-9a-f]*.sqlog

    echo "Starting server on 10.0.1.1..."
    sudo ip netns exec server env QLOGDIR=. ${QUICHE_DIR}/quiche-server --listen 10.0.1.1:4433 --cert ../certs/cert.crt --key ../certs/cert.key --root .. --cc-algorithm $ALGO > /dev/null 2>&1 &
    SERVER_PID=$!
    sleep 1

    echo "Running QUIC test for $ALGO (20s)..."
    sudo ip netns exec client timeout --signal=INT 20s env SSLKEYLOGFILE="quic_baseline_clean_${ALGO}_keys.log" QLOGDIR=. ${QUICHE_DIR}/quiche-client https://10.0.1.1:4433/testfile.bin --no-verify > /dev/null || true
    sleep 2

    echo "Stopping test..."
    sudo kill -INT $TCPDUMP_PID 2>/dev/null || true
    sudo kill -TERM $SERVER_PID 2>/dev/null || true
    sleep 1

    SQLOG_FILE="quic_baseline_clean_${ALGO}.sqlog"
    # Identify the server-side log (it contains the CWND data)
    SERVER_LOG=$(grep -l '"type":"server"' *.sqlog 2>/dev/null | head -n 1)
    if [ -n "$SERVER_LOG" ]; then
        mv "$SERVER_LOG" "$SQLOG_FILE"
    fi
    wait $TCPDUMP_PID 2>/dev/null || true

    echo "Generating qlog-dancer charts for $ALGO..."
    
    # Get the absolute path of the sqlog to pass to qlog-dancer safely
    ABS_SQLOG=$(realpath "$SQLOG_FILE")
    
    # Run qlog-dancer as the real user so rustup/cargo env resolves correctly.
    sudo -u "$REAL_USER" bash -lc "cd \"$QLOG_DANCER_DIR\" && cargo run --release -- --charts all \"$ABS_SQLOG\""

    echo "Charts generated in: ${QLOG_DANCER_DIR}"
done

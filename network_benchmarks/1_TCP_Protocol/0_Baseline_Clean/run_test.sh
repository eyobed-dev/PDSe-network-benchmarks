here is the updated script #!/bin/bash

echo "Starting experiment..."

for ALGO in reno cubic bbr; do
    echo "Resetting router qdisc for clean algorithmic isolation..."
    sudo ip netns exec router tc qdisc del dev r_out root 2>/dev/null || true

    echo "Starting logs for ($ALGO)..."
    #start tcpdump on port 5201(iperf3 server port) first 96 bytes and save to pcap file
    sudo ip netns exec client tcpdump -i c_eth port 5201 -s 96 -w "tcp_baseline_clean_${ALGO}.pcap" > /dev/null 2>&1 &
    #get the pid of the tcpdump process
    TCPDUMP_PID=$!
    ( 
      #creates a csv file with header TIME,CWND and logs the cwnd every 20ms
      echo "TIME,CWND" > "tcp_baseline_clean_${ALGO}_cwnd.csv"
      while true; do
        #get the current time in seconds with nanoseconds
        TIME=$(date +%s.%N)
        #get the cwnd from ss command(-i include internal info, grep to extract cwnd, cut to extract the value, tail to get the last value)
        CWND_RAW=$(sudo ip netns exec client ss -ti dport = :5201 | grep -o 'cwnd:[0-9]*' | cut -d: -f2 | tail -n 1 || true)
        #if cwnd is not empty, log it
        if [ ! -z "$CWND_RAW" ]; then
          echo "$TIME,$CWND_RAW" >> "tcp_baseline_clean_${ALGO}_cwnd.csv"
        fi
        sleep 0.02
      done
    ) & 
    #get the pid of the logger process
    LOGGER_PID=$!

    #wait for 0.5 seconds for the logger to be started
    sleep 0.5

    echo "Spawning server on 10.0.1.1..."
    sudo ip netns exec server iperf3 -s -p 5201 --daemon
    sleep 0.5

    #run iperf3 test for 40 seconds with the current congestion control algorithm
    echo "Running TCP test for $ALGO (40s)..."
    sudo ip netns exec client iperf3 -c 10.0.1.1 -p 5201 -C $ALGO -t 40 --json > "tcp_baseline_clean_${ALGO}.json"

    echo "Finishing..."
    #stop tcpdump
    sudo kill -INT $TCPDUMP_PID 2>/dev/null || true
    #kill logger
    [ ! -z "$LOGGER_PID" ] && sudo kill -TERM $LOGGER_PID 2>/dev/null || true
    #kill server
    sudo pkill -f "iperf3 -s" 2>/dev/null || true
    #wait for processes to finish
    wait $TCPDUMP_PID 2>/dev/null || true
    [ ! -z "$LOGGER_PID" ] && wait $LOGGER_PID 2>/dev/null || true
    echo "Finished $ALGO."
    echo "--------------------------"
done

echo "All tests completed."
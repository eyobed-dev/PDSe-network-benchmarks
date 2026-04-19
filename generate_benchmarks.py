import os

base_dir = "/home/eyobed/Documents/School/BUT/Semester 2/PDSe/Project"

envs = {
    "0_Baseline_Clean": [
        "sudo ip netns exec router tc qdisc add dev r_out root tbf rate 100mbit latency 50ms burst 1540"
    ],
    "1_CoffeeShop_WiFi": [
        "sudo ip netns exec router tc qdisc add dev r_out root handle 1: tbf rate 100mbit latency 50ms burst 1540",
        "sudo ip netns exec router tc qdisc add dev r_out parent 1: handle 10: netem delay 30ms loss 3%"
    ],
    "2_Starlink_Satellite": [
        "sudo ip netns exec router tc qdisc add dev r_out root handle 1: tbf rate 100mbit latency 50ms burst 1540",
        "sudo ip netns exec router tc qdisc add dev r_out parent 1: handle 10: netem delay 600ms 50ms distribution normal"
    ],
    "3_Bufferbloat": [
        "sudo ip netns exec router tc qdisc add dev r_out root handle 1: tbf rate 10mbit latency 50ms burst 1540",
        "sudo ip netns exec router tc qdisc add dev r_out parent 1: handle 10: netem delay 20ms limit 50000"
    ]
}

def write_script(path, content):
    with open(path, "w") as f:
        f.write(content)
    os.chmod(path, 0o755)

benchmarks_dir = os.path.join(base_dir, "network_benchmarks")

for protocol in ["1_TCP_Protocol", "2_QUIC_Protocol"]:
    is_tcp = (protocol == "1_TCP_Protocol")
    prot_str = "tcp" if is_tcp else "quic"
    target_port = "5201" if is_tcp else "4433"
    
    for env_name, rules in envs.items():
        env_dir = os.path.join(benchmarks_dir, protocol, env_name)
        os.makedirs(env_dir, exist_ok=True)
        
        short_env = env_name.split("_", 1)[1].lower()
        
        script = "#!/bin/bash\n\n"
        script += 'echo "Starting experiment matrix..."\n\n'
            
        script += 'for ALGO in reno cubic bbr; do\n'
        out_base = f"{prot_str}_{short_env}_${{ALGO}}"
        
        script += '    echo "Resetting router and client qdiscs for clean algorithmic isolation..."\n'
        script += '    sudo ip netns exec router tc qdisc del dev r_out root 2>/dev/null || true\n'
        script += '    sudo ip netns exec client tc qdisc del dev c_eth root 2>/dev/null || true\n\n'
        
        script += f'    echo "Applying topology rules for {env_name} directly to router egress..."\n'
        for rule in rules:
            script += f'    {rule}\n'
        script += '\n'
        
        script += f'    echo "Starting background loggers ($ALGO)..."\n'

        # 1. Start tcpdump filtered by port and truncated to headers
        script += f'    sudo ip netns exec client tcpdump -i c_eth port {target_port} -s 96 -w "{out_base}.pcap" > /dev/null 2>&1 &\n'
        script += '    TCPDUMP_PID=$!\n'
        
        # 2. Start async ss logger ONLY for TCP to capture CWND directly and quickly (50Hz)
        if is_tcp:
            script += '    ( \n'
            script += f'      echo "TIME,CWND" > "{out_base}_cwnd.csv"\n'
            script += '      while true; do\n'
            script += '        TIME=$(date +%s.%N)\n'
            script += f'        CWND_RAW=$(sudo ip netns exec client ss -ti dport = :{target_port} | grep -o \'cwnd:[0-9]*\' | cut -d: -f2 | tail -n 1 || true)\n'
            script += '        if [ ! -z "$CWND_RAW" ]; then\n'
            script += f'          echo "$TIME,$CWND_RAW" >> "{out_base}_cwnd.csv"\n'
            script += '        fi\n'
            script += '        sleep 0.02\n'
            script += '      done\n'
            script += '    ) & \n'
            script += '    LOGGER_PID=$!\n'
        else:
            script += '    LOGGER_PID=""\n'
            
        script += '    sleep 0.5\n\n'
        
        script += f'    echo "Spawning backend server on 10.0.1.1..."\n'
        if is_tcp:
            script += f'    sudo ip netns exec server iperf3 -s -p {target_port} --daemon\n'
            script += f'    sleep 0.5\n'
        else:
            script += f'    sudo ip netns exec server $HOME/quiche/target/debug/examples/quiche-server --listen 10.0.1.1:{target_port} --cert $HOME/quiche/apps/src/bin/cert.crt --key $HOME/quiche/apps/src/bin/cert.key --root . > /dev/null 2>&1 &\n'
            script += '    SERVER_PID=$!\n'
            script += f'    sleep 1\n'

        script += f'    echo "Running {prot_str.upper()} test for $ALGO (40s)..."\n'
        if is_tcp:
            script += f'    sudo ip netns exec client iperf3 -c 10.0.1.1 -p {target_port} -C $ALGO -t 40 --json > "{out_base}.json"\n'
        else:
            script += f'    sudo ip netns exec client env SSLKEYLOGFILE="{out_base}_keys.log" $HOME/quiche/target/debug/examples/quiche-client https://10.0.1.1:{target_port}/testfile.bin --cc $ALGO > "{out_base}.txt"\n'
        
        script += '\n    echo "Stopping test captures and servers..."\n'
        script += '    sudo kill -INT $TCPDUMP_PID 2>/dev/null || true\n'
        script += '    [ ! -z "$LOGGER_PID" ] && sudo kill -TERM $LOGGER_PID 2>/dev/null || true\n'
        if is_tcp:
            script += '    sudo pkill -f "iperf3 -s" 2>/dev/null || true\n'
        else:
            script += '    sudo kill -TERM $SERVER_PID 2>/dev/null || true\n'
        script += '    wait $TCPDUMP_PID 2>/dev/null || true\n'
        script += '    [ ! -z "$LOGGER_PID" ] && wait $LOGGER_PID 2>/dev/null || true\n'
        script += '    echo "Finished $ALGO."\n'
        script += '    echo "--------------------------"\n'
        script += 'done\n\n'
        script += 'echo "All tests completed for this environment."\n'
        
        script_path = os.path.join(env_dir, "run_test.sh")
        write_script(script_path, script)

print("Experiment harness fully rebuilt with rigorous isolation and metric fidelity.")

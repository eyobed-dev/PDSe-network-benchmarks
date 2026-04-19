# Comparative Analysis of Transport Protocols and Congestion Algorithms

## 1. Introduction
*Description of transport protocols (TCP vs QUIC) and an overview of congestion algorithms (Reno, Cubic, BBR).*

## 2. Topology & Monitoring Setup
*Detailed breakdown of the simulated network environment.*
* **Architecture:** Linux Network Namespaces (`client`, `router`, `server`) connected via virtual ethernet (`veth`) pairs.
* **Network Tuning (Traffic Control):**
  * **Coffee Shop Wi-Fi:** `delay 30ms`, `loss 3%`
  * **Starlink-style Satellite:** `delay 600ms 50ms`, `distribution normal`
  * **The Bufferbloat Trap:** `delay 20ms`, `rate 10mbit`, `limit 50000`
* **Software Tooling:** `iperf3`, `quiche-client/server`, `tc (netem)`, `ss` (Socket Statistics pacing), and `tcpdump`/Wireshark PCAP analysis.

## 3. Automation Scripts
*Explanation of the Bash/Python automation tools built for to configure the network endpoints, aggressively scrub legacy rules, iteratively sequence through target congestion algorithms, log CWND CSVs, and safely terminate isolated measurement instances.*

## 4. Methodology
*Detailed descriptions of the measurement parameters, isolation procedures, polling intervals (100ms vs <1ms), data validation (e.g. data-socket isolation versus control-socket baseline alias mapping), and normalization of execution metrics.*

## 5. CWND Visualization
*Time-series plots showing how the Congestion Window changed over time for each protocol.*
*(Insert `plot_cwnd.py` `.png` renderings here).*

## 6. Analysis & Findings
*In-depth explanation of protocol failures and successes.*
* **TCP Reno** vs **Coffee Shop Wi-Fi** (Discussion of packet-loss catastrophic halving curves).
* **TCP Cubic** vs **Satellite** (Discussion on why Cubic inherently struggles to map latency boundaries efficiently over sheer massive RTT scales).
* **TCP BBR** vs **Bufferbloat** (Discussion on bandwidth measuring to bypass deep-buffered queuing bottlenecks).
* **QUIC Analysis**

## 7. Proposed Optimizations
*Discussion on how to optimize Linux TCP configurations or QUIC configurations to perform reliably across these specific hostile vectors.*

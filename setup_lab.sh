#!/bin/bash
# exit on error
set -e

echo "Deleting existing namespaces"
sudo ip netns del client 2>/dev/null || true
sudo ip netns del router 2>/dev/null || true
sudo ip netns del server 2>/dev/null || true

echo "Creating namespaces: client, router, server"
sudo ip netns add client
sudo ip netns add router
sudo ip netns add server

echo "Creating veth pairs"
sudo ip link add c_eth type veth peer name r_in
sudo ip link add s_eth type veth peer name r_out

echo "Assigning veth pairs to namespaces"
sudo ip link set c_eth netns client
sudo ip link set r_in netns router
sudo ip link set r_out netns router
sudo ip link set s_eth netns server

echo "Assigning IP addresses"
sudo ip netns exec client ip addr add 10.0.0.1/24 dev c_eth
sudo ip netns exec router ip addr add 10.0.0.2/24 dev r_in
sudo ip netns exec router ip addr add 10.0.1.2/24 dev r_out
sudo ip netns exec server ip addr add 10.0.1.1/24 dev s_eth

echo "Bring up loopback interfaces"
sudo ip netns exec client ip link set lo up
sudo ip netns exec router ip link set lo up
sudo ip netns exec server ip link set lo up

echo "Bring up interfaces"
sudo ip netns exec client ip link set c_eth up
sudo ip netns exec router ip link set r_in  up
sudo ip netns exec router ip link set r_out up
sudo ip netns exec server ip link set s_eth up

echo "Enable IPv4 forwarding on the router"
sudo ip netns exec router sysctl -w net.ipv4.ip_forward=1 > /dev/null

echo "Set up routes"
sudo ip netns exec client ip route add 10.0.1.0/24 via 10.0.0.2
sudo ip netns exec server ip route add 10.0.0.0/24 via 10.0.1.2

echo "Disable hardware offloads"
sudo ip netns exec client  ethtool -K c_eth tso off gso off gro off 2>/dev/null || true
sudo ip netns exec router  ethtool -K r_in  tso off gso off gro off 2>/dev/null || true
sudo ip netns exec router  ethtool -K r_out tso off gso off gro off 2>/dev/null || true
sudo ip netns exec server  ethtool -K s_eth tso off gso off gro off 2>/dev/null || true

echo "Connectivity check"
sudo ip netns exec client ping -c 3 10.0.1.1 > /dev/null

echo "Lab setup complete!"

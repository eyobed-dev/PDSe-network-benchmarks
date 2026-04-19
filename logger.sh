# Delete the old junk data
rm cwnd_log.csv 2>/dev/null || true

# Start the smarter logger
while true; do
  TIME=$(date +%s.%N)

  # Extract all cwnds, sort them numerically, and grab the largest one
  CWND=$(sudo ip netns exec client ss -ti dst 10.0.1.1 | grep cwnd | awk -F'cwnd:' '{print $2}' | awk '{print $1}' | sort -n | tail -1)

  if [ ! -z "$CWND" ]; then
    echo "$TIME,$CWND" >> cwnd_log.csv
  fi
  sleep 0.1
done

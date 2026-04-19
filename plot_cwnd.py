import sys
import os
import pandas as pd
import matplotlib.pyplot as plt

# Get the target file from the command line, fallback to 'cwnd_log.csv'
file_path = sys.argv[1] if len(sys.argv) > 1 else 'cwnd_log.csv'

# 1. Load the CSV (Our new scripts include the TIME,CWND headers natively!)
df = pd.read_csv(file_path)

# 2. Convert timestamps to relative time (start at 0 seconds)
start_time = df['TIME'].iloc[0]
df['Relative_Time'] = df['TIME'] - start_time

# 3. Create the graph
plt.figure(figsize=(10, 6))
# Standard line plot with diamond markers to match traditional academic demonstrations!
plt.plot(df['Relative_Time'], df['CWND'], color='darkblue', marker='D', markersize=4, linestyle='-', linewidth=1.5)

# 4. Label everything
plt.title(f'TCP Congestion Window vs. Time ({os.path.basename(file_path)})')
plt.xlabel('Time (Seconds)')
plt.ylabel('Congestion Window (Packets)')
plt.grid(True, linestyle='--', alpha=0.7)

# 5. Show the graph 
plt.show()

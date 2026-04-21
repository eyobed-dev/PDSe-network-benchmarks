import os
import pandas as pd
import matplotlib.pyplot as plt

ROOT = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(ROOT, "network_benchmarks")
ASSETS = os.path.join(ROOT, "report", "assets", "plots")

PROTOCOLS = ["1_TCP_Protocol"]
ENVS      = ["0_Baseline_Clean", "1_CoffeeShop_WiFi", "2_Starlink_Satellite", "3_Bufferbloat"]
ALGOS     = ["reno", "cubic", "bbr"]

for proto in PROTOCOLS:
    prefix = "tcp"
    
    for env in ENVS:
        # Create matching output directory
        out_dir = os.path.join(ASSETS, proto, env)
        os.makedirs(out_dir, exist_ok=True)
        
        env_name = env.split("_", 1)[1]
        env_key  = env_name.lower()
        
        fig_comp, ax_comp = plt.subplots(figsize=(10, 6))
        has_comp_data = False

        for algo in ALGOS:
            csv = os.path.join(BASE, proto, env, f"{prefix}_{env_key}_{algo}_cwnd.csv")
            if os.path.exists(csv):
                df = pd.read_csv(csv)
                if not df.empty:
                    time = df['TIME'] - df['TIME'].min()
                    
                    # 1. Individual Plot
                    plt.figure(figsize=(8, 4))
                    plt.plot(time, df['CWND'], label=algo, marker='o', markersize=2, linewidth=1, color='blue')
                    plt.title(f"{proto.replace('_', ' ')}: {algo.upper()} - {env_name}")
                    plt.xlabel("Time (s)")
                    plt.ylabel("CWND")
                    plt.grid(True, linestyle='--')
                    plt.savefig(os.path.join(out_dir, f"{algo}.png"))
                    plt.close()
                    
                    # 2. Comparative Plot
                    ax_comp.plot(time, df['CWND'], label=algo.upper(), marker='o', markersize=2, linewidth=1)
                    has_comp_data = True

        if has_comp_data:
            ax_comp.set_title(f"{proto.replace('_', ' ')} Comparison - {env_name}")
            ax_comp.set_xlabel("Time (s)")
            ax_comp.set_ylabel("CWND (Segments)")
            ax_comp.legend()
            ax_comp.grid(True, linestyle='--')
            fig_comp.savefig(os.path.join(out_dir, "combined.png"))
        
        plt.close(fig_comp)

print("Plotting complete. Results organized in report/assets/plots/")

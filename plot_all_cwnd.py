import os
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker

BASE = "/home/eyobed/Documents/School/BUT/Semester 2/PDSe/Project/network_benchmarks"
OUT  = "/home/eyobed/Documents/School/BUT/Semester 2/PDSe/Project/report/assets/plots"
os.makedirs(OUT, exist_ok=True)

ALGO_STYLE = {
    "reno":  {"color": "#e74c3c", "label": "TCP Reno",  "linestyle": "-"},
    "cubic": {"color": "#2980b9", "label": "TCP CUBIC", "linestyle": "--"},
    "bbr":   {"color": "#27ae60", "label": "TCP BBR",   "linestyle": "-."},
}

ENVS = {
    "1_CoffeeShop_WiFi":   ("Coffee Shop Wi-Fi",   "coffeeshop_wifi"),
    "2_Starlink_Satellite": ("Starlink Satellite",  "starlink_satellite"),
    "3_Bufferbloat":        ("Bufferbloat Trap",    "bufferbloat"),
}

for env_dir, (env_title, env_key) in ENVS.items():
    fig, ax = plt.subplots(figsize=(11, 5))
    fig.patch.set_facecolor("#1a1a2e")
    ax.set_facecolor("#16213e")

    plotted = False
    for algo, style in ALGO_STYLE.items():
        csv = os.path.join(BASE, "1_TCP_Protocol", env_dir, f"tcp_{env_key}_{algo}_cwnd.csv")
        if not os.path.exists(csv):
            print(f"  MISSING: {csv}")
            continue
        df = pd.read_csv(csv)
        if df.empty or "TIME" not in df.columns or "CWND" not in df.columns:
            print(f"  EMPTY/INVALID: {csv}")
            continue
        df["TIME"] = pd.to_numeric(df["TIME"], errors="coerce")
        df["CWND"] = pd.to_numeric(df["CWND"], errors="coerce")
        df = df.dropna()
        if df.empty:
            continue
        t0 = df["TIME"].iloc[0]
        df["t"] = df["TIME"] - t0
        ax.plot(df["t"], df["CWND"],
                color=style["color"],
                label=style["label"],
                linestyle=style["linestyle"],
                linewidth=1.8,
                alpha=0.9)
        plotted = True

    if not plotted:
        print(f"No data for {env_title}, skipping.")
        plt.close(fig)
        continue

    ax.set_title(f"CWND vs. Time — {env_title}", color="white", fontsize=14, pad=12)
    ax.set_xlabel("Time (seconds)", color="#aaaaaa", fontsize=11)
    ax.set_ylabel("Congestion Window (segments)", color="#aaaaaa", fontsize=11)
    ax.tick_params(colors="#aaaaaa")
    ax.spines["bottom"].set_color("#444466")
    ax.spines["left"].set_color("#444466")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.grid(True, linestyle="--", alpha=0.25, color="#888888")
    ax.yaxis.set_major_locator(ticker.MaxNLocator(integer=True))
    legend = ax.legend(facecolor="#0f3460", edgecolor="#444466",
                       labelcolor="white", fontsize=10, loc="upper right")
    plt.tight_layout()
    out_path = os.path.join(OUT, f"tcp_{env_key}_cwnd.png")
    plt.savefig(out_path, dpi=150, bbox_inches="tight")
    print(f"Saved: {out_path}")
    plt.close(fig)

print("\nAll plots generated.")

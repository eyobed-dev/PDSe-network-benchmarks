import os
import json
import pandas as pd

ROOT = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(ROOT, "network_benchmarks", "1_TCP_Protocol")

ENVS = {
    "0_Baseline_Clean": "Baseline (Clean)",
    "1_CoffeeShop_WiFi": "CoffeeShop Wi-Fi",
    "2_Starlink_Satellite": "Starlink Satellite",
    "3_Bufferbloat": "Bufferbloat (10Mbps)"
}
ALGOS = ["reno", "cubic", "bbr"]

def extract_stats(proto_dir, env_dir, algo):
    env_path = os.path.join(proto_dir, env_dir)
    if not os.path.exists(env_path):
        return None, None
        
    for f in os.listdir(env_path):
        if f.endswith(".json") and algo in f:
            path = os.path.join(env_path, f)
            try:
                with open(path, 'r') as jf:
                    data = json.load(jf)
                    throughput = data['end']['sum_received']['bits_per_second'] / 1e6
                    retransmits = data['end']['sum_sent'].get('retransmits', 0)
                    return throughput, retransmits
            except Exception as e:
                return None, None
    return None, None

results = []
for env_dir, env_label in ENVS.items():
    row = {"Environment": env_label}
    for algo in ALGOS:
        thr, ret = extract_stats(BASE, env_dir, algo)
        row[f"{algo.capitalize()} Mbps"] = f"{thr:.2f}" if thr is not None else "0.00"
        row[f"{algo.capitalize()} Retx"] = str(ret) if ret is not None else "0"
    results.append(row)

df = pd.DataFrame(results)
print(df.to_markdown(index=False))

# Also generate LaTeX table section
print("\n--- LaTeX Table ---")
latex = "\\begin{table}[H]\n\\centering\n\\caption{TCP Throughput and Retransmissions Summary}\n"
latex += "\\label{tab:tcp_summary_all}\n"
latex += "\\begin{tabular}{|l|c|c|c|c|c|c|}\n\\hline\n"
latex += "\\textbf{Environment} & \\multicolumn{2}{c|}{\\textbf{Reno}} & \\multicolumn{2}{c|}{\\textbf{CUBIC}} & \\multicolumn{2}{c|}{\\textbf{BBR}} \\\\\n\\cline{2-7}\n"
latex += " & Mbps & Retx & Mbps & Retx & Mbps & Retx \\\\\n\\hline\n"
for res in results:
    latex += f"{res['Environment']} & {res['Reno Mbps']} & {res['Reno Retx']} & {res['Cubic Mbps']} & {res['Cubic Retx']} & {res['Bbr Mbps']} & {res['Bbr Retx']} \\\\\n"
latex += "\\hline\n\\end{tabular}\n\\end{table}"
print(latex)

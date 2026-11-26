import os 
import numpy as np 
import pandas as pd 
from scipy.stats import norm 
import matplotlib.pyplot as plt 
 
rng = np.random.default_rng(7) 
p_ctrl, p_treat, reps = 0.60, 0.64, 1000 
sample_sizes = [250, 500, 1000, 2000, 3000, 5000, 10000] 
# Positive effect at the two-sided 5 percent level 
z_crit = norm.ppf(0.975) 
 
rows = [] 
for n in sample_sizes: 
    c = rng.binomial(n, p_ctrl, size=reps) 
    t = rng.binomial(n, p_treat, size=reps) 
    p1, p2 = c / n, t / n 
    pool = (c + t) / (2 * n) 
    se = np.sqrt(pool * (1 - pool) * (2 / n)) 
    z = (p2 - p1) / se 
    power = float(np.mean(np.greater(z, z_crit))) * 100 
    rows.append({"users_per_arm": n, "power_pct": round(power, 1)}) 
 
res = pd.DataFrame(rows) 
print(res.to_string(index=False)) 
 
out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "charts", "power_table.png") 
plt.figure(figsize=(9, 4.5)) 
plt.plot(res["users_per_arm"], res["power_pct"], marker="o", linewidth=2) 
plt.axhline(80, linestyle="--", color="gray", label="80" + chr(37) + " target power (~2,400 users/arm)") 
for _, r in res.iterrows(): 
    lbl = f"{r['power_pct']:.0f}" + chr(37) 
    plt.annotate(lbl, (r["users_per_arm"], r["power_pct"]), textcoords="offset points", xytext=(0, 8), ha="center", fontsize=9) 
plt.ylim(0, 110) 
plt.xlabel("Users per arm") 
plt.ylabel("Statistical power (" + chr(37) + ")") 
plt.title("Simulated A/B Test Power Curve (+4 pp lift, 1,000 runs per sample size)") 
plt.legend(loc="lower right") 
plt.grid(True, alpha=0.3) 
plt.savefig(out_path, dpi=150, bbox_inches="tight") 

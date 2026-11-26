import numpy as np, pandas as pd, sqlite3
from statsmodels.stats.proportion import proportions_ztest

rng = np.random.default_rng(42)   # sabit seed = tekrar üretilebilir
N = 20000

# --- SİMÜLASYON VARSAYIMLARI (README'de belgelenecek) ---
BASE_RETRY      = 0.55   # kayıptan sonra 2 dk içinde tekrar deneme (varsayım)
NEAR_MISS_BONUS = 0.08   # near-miss etkisi (varsayım)
TREATMENT_LIFT  = 0.04   # PLANT EDİLEN etki: test grubuna kalan hedef mesajı
SPENDER_RATE    = 0.08

df = pd.DataFrame({
    "player_id": range(N),
    "variant": rng.choice(["control", "treatment"], N),
    "spender": rng.random(N) < SPENDER_RATE,
    "goal_remaining_pct": rng.choice(
        [5, 10, 15, 20, 25, 30, 40, 50, 60], N,
        p=[.12, .12, .12, .12, .12, .10, .10, .10, .10]),
})
df["near_miss"] = df["goal_remaining_pct"] <= 25

p_retry = (BASE_RETRY
           + NEAR_MISS_BONUS * df["near_miss"]
           + TREATMENT_LIFT * (df["variant"] == "treatment")
           + 0.03 * df["spender"])
df["retried_fast"] = rng.random(N) < p_retry

# guardrail: D7 geri dönüş, yalnızca tekrar deneme üzerinden etkileniyor
df["d7_return"] = rng.random(N) < (0.08 + 0.05 * df["retried_fast"])

# --- SQL tarafına aktar ---
con = sqlite3.connect("sim.db")
df.to_sql("sim_first_loss", con, if_exists="replace", index=False)

q = """
SELECT variant,
       COUNT(*) AS users,
       SUM(retried_fast) AS retried,
       ROUND(AVG(retried_fast), 4) AS retry_rate,
       ROUND(AVG(d7_return), 4) AS d7_rate
FROM sim_first_loss
GROUP BY variant;
"""
res = pd.read_sql(q, con)
print(res)

# --- İstatistik: iki oran z-testi + %95 güven aralığı ---
c = res.set_index("variant")
counts = [c.loc["treatment", "retried"], c.loc["control", "retried"]]
nobs   = [c.loc["treatment", "users"],   c.loc["control", "users"]]
z, p = proportions_ztest(counts, nobs)
p1, p2 = counts[0]/nobs[0], counts[1]/nobs[1]
se = (p1*(1-p1)/nobs[0] + p2*(1-p2)/nobs[1]) ** 0.5
print(f"fark = {p1-p2:.4f}, %95 GA = [{p1-p2-1.96*se:.4f}, {p1-p2+1.96*se:.4f}], p = {p:.4g}")
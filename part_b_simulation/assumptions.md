# Part B: Simulation Assumptions

> **All data in Part B is synthetic.** It was generated with a known, planted effect to validate an analysis pipeline (SQL aggregation, two-proportion z-test, confidence intervals, power analysis). None of these numbers are claims about real Royal Match players. Every value below is an assumption I chose, not a measurement.

## Purpose

If the analysis code recovers an effect I planted, I know the code can find that kind of effect. If it fails at small sample sizes, I learn how many users a real test would need. The simulation does not tell me whether the effect exists in a real game.

## Experiment design being simulated

| Element | Choice |
|---|---|
| Question | Does showing how close the player was to winning on the post-loss screen raise the share who retry within 2 minutes? |
| Unit of analysis | One player, using their **first loss** (a player's attempts are not independent, so I never count several per player) |
| Randomization | 50/50 by user into `control` and `treatment` |
| Primary metric | Retried within 2 minutes after the loss |
| Guardrail metric | Returned on day 7 (D7 return) |
| Population | 20,000 simulated players, fixed seed so results reproduce |

## Simulation parameters (`simulate.py`)

| Parameter | Value | Why this value |
|---|---|---|
| Players (N) | 20,000 | Large enough that the primary effect is clearly detectable |
| Random seed | 42 | Reproducibility |
| Baseline fast-retry rate | 0.55 | Arbitrary starting point for a casual puzzle game; **not a real rate** |
| Near-miss bonus | +0.08 | Encodes my hypothesis that near-miss losses increase retrying |
| Treatment lift | **+0.04** (planted) | The effect the pipeline should recover |
| Spender share | 8% | Illustrative share of paying players |
| Spender retry bonus | +0.03 | Illustrative |
| `goal_remaining_pct` values | 5, 10, 15, 20, 25 (12% each); 30, 40, 50, 60 (10% each) | Near-miss means 25% or less left, so 60% of losses are near-misses by construction |
| D7 return probability | 0.08 + 0.05 × (retried fast) | D7 is downstream of retrying by construction |

With these values the expected control retry rate is about 0.600 and the treatment rate about 0.640.

## Power analysis parameters (`power_analysis.py`)

| Parameter | Value |
|---|---|
| Control retry rate | 0.60 |
| Treatment retry rate | 0.64 (a 4 pp lift) |
| Repetitions per sample size | 1,000 simulated experiments |
| Random seed | 7 |
| Sample sizes (users per arm) | 250, 500, 1,000, 2,000, 3,000, 5,000, 10,000 |
| Test | Two-proportion z-test; an experiment counts as a detection when z exceeds the 97.5th percentile of the normal distribution (a positive effect at the two-sided 5% level) |
| Power | Share of the 1,000 experiments that detected the lift |

## Results

| Quantity | Value |
|---|---|
| Estimated lift in the 20,000-user run | +3.4 pp (planted: +4 pp) |
| 95% confidence interval | [2.1, 4.8] pp |
| p-value | below 0.001 |
| Users per arm for 80% power | about 2,400 |
| Closed-form check, 16·p(1−p)/δ² | about 2,400 |

| Users per arm | Power |
|---|---|
| 250 | 14% |
| 500 | 26% |
| 1,000 | 46% |
| 2,000 | 74% |
| 3,000 | 89% |
| 5,000 | 98% |
| 10,000 | 100% |

The power values are Monte Carlo estimates and carry roughly ±3 pp of simulation error. A different seed moves the effect estimate by a point or so, which is normal sampling noise.

## Guardrail caveat

With about 2,400 users per arm the D7 baseline of roughly 11% allows only a drop of about 2.5 pp to be detected. Detecting a 1 pp drop would need about 15,700 users per arm. In this simulation D7 rises slightly with the treatment (about +0.2 pp) because I made it depend on retrying. In a real game a loss-framed or closeness-framed screen could just as well lower retention, which is why the guardrail needs its own sample size.

## What this simulation cannot do

- Show that any real effect exists. I planted the effect.
- Estimate real baseline rates. Every baseline here is an assumption.
- Model network effects (teams, events), novelty effects or heterogeneous players.

## Files

- `simulate.py`: generates the data, loads it into SQLite, runs the aggregation query and the z-test
- `power_analysis.py`: runs the 1,000-repetition power simulation and saves `charts/power_table.png`

# Microgrid-MPC-Peak-Shaving
# Optimal Energy Management of a Commercial Microgrid
**Implementation of Quadratic MPC for Peak Shaving and Battery Longevity**

## Overview
This repository contains the MATLAB implementation of a Quadratic Model Predictive Control (MPC) framework designed for a commercial microgrid (e.g., a shopping mall). The system integrates Solar PV and a 250 kWh Battery Energy Storage System (BESS) to manage stochastic EV charging loads and eliminate industrial peak demand penalties.

## Key Features
* **Peak Shaving:** Limits grid demand to a 400 kW threshold, avoiding €100/kW penalties.
* **Health-Aware Control:** Utilizes a bimodal degradation model to maintain battery health near the 50% SOC "sweet spot."
* **Annual Financial Analysis:** Simulates 52 weeks of operation with a 95% round-trip efficiency factor.
* **Results:** Achieved **€16,898.35** in annual savings and a **97.68%** final State of Health (SOH).

## Project Structure
1. `init_data.m`: Sets system parameters, economic constants, and degradation coefficients.
2. `mpc_snapshot_weekly.m`: Performs a high-resolution simulation of a single week (June Week 4) to visualize peak shaving dynamics.
3. `mpc_annual_optimization.m`: The main execution script for the full-year simulation and cumulative financial reporting.
4. `PV_Data`: Dataset containing 15-minute interval solar generation and building load profiles.

## How to Run
1. Ensure all files are in the same MATLAB directory.
2. Run `init_data.m` to load the environment.
3. Run `mpc_annual_optimization.m` to generate the annual performance report and health-fade plots.

## Authors
* Kareem
* Daniel
* Anwar

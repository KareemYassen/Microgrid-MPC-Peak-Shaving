# Optimal Energy Management of a Commercial Microgrid
### **Implementation of Quadratic MPC for Peak Shaving and Battery Longevity**



## 1. Executive Summary
This repository presents a high-performance **Energy Management System (EMS)** utilizing **Model Predictive Control (MPC)** to optimize the operation of a grid-tied commercial microgrid. The system manages a **250 kW/250 kWh Battery Energy Storage System (BESS)** and a **500 kWp Solar PV array** to mitigate highly stochastic Electric Vehicle (EV) charging transients. 

The controller is formulated as a **Quadratic Programming (QP)** problem, designed to balance aggressive peak shaving with the preservation of battery asset health.

## 2. Technical Features
* **Quadratic Peak Shaving:** Implements a "soft" penalty on grid power $(P_{\text{Grid}})^2$ to prioritize the mitigation of high-magnitude spikes over minor fluctuations.
* **Stochastic Load Modeling:** Simulates non-deterministic EV arrivals and bimodal power demands (AC Level 2 and DC Fast Charging) reaching peaks of **610.22 kW**.
* **Health-Aware Dispatch:** Integrates a semi-empirical degradation model targeting the **50% SOC "sweet spot"** to minimize chemical plating and thermal stress.
* **Industrial Compliance:** Operates on a 15-minute billing resolution ($\Delta t = 0.25$ h) to align with standard utility demand charge structures.



## 3. Project Architecture & File Names
The repository is structured into a modular **Data Engineering** and **Optimization** pipeline:

1.  **`init_data.m`**: The initialization script that sets system parameters, economic constants, loads PVGIS-SARAH3 meteorological data, and synthesizes stochastic facility loads.
2.  **`mpc_snapshot_weekly.m`**: A high-resolution simulation of a single high-demand week (June Week 4) to visualize 168-hour horizon dynamics and peak-shaving efficacy.
3.  **`mpc_annual_optimization.m`**: The master execution script utilizing a **"State Handoff"** mechanism to simulate 52 sequential weeks of health fade and financial performance.
4.  **`PV_Data_Raw.csv`**: Time-series solar generation and baseline building demand profiles used by the initialization script.

## 4. How to Run the Code
Follow these steps to reproduce the simulation results:

1.  **Environment Setup:** Ensure you have MATLAB installed with the **Optimization Toolbox**. 
2.  **File Placement:** Keep all `.m` files and the `.csv` data file in the same working directory.
3.  **Initialization:** Run **`init_data.m`** first. This will process the raw data, generate the stochastic EV profiles, and load all parameters into the workspace.
4.  **Annual Simulation:** To generate the full-year results, financial reports, and battery health-fade plots, run **`mpc_annual_optimization.m`**.
5.  **Weekly Visualization:** To see a detailed "snapshot" of the controller's behavior during a specific peak week, run **`mpc_snapshot_weekly.m`**.

## 5. Key Performance Results
* **Annual Financial Savings:** **€16,898.35** reduction in total costs compared to reactive strategies.
* **Final State of Health (SOH):** **97.68%** preservation after 365 days of operation.
* **Peak Demand Penalty:** **€0.00** (Successful 100% mitigation of demand charges).
* **Grid Peak Reduction:** Maximum annual grid peak limited to **351.98 kW**.



## 6. Authors
* **Kareem**, **Daniel**, and **Anwar**

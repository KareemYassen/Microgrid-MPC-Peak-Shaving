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



## 3. Project Architecture
The repository is structured into a modular **Data Engineering** and **Optimization** pipeline:

1.  **`microgrid_data_engineering.m`**: Loads raw PVGIS-SARAH3 meteorological data (Gummersbach, Germany) and synthesizes stochastic facility loads.
2.  **`mpc_dispatch_snapshot.m`**: A high-resolution simulation of a single high-demand week (June Week 4) to visualize 168-hour horizon dynamics.
3.  **`mpc_annual_optimization_suite.m`**: The master execution script utilizing a **"State Handoff"** mechanism to simulate 52 sequential weeks of health fade and financial performance.
4.  **`PV_Data_Raw.csv`**: Time-series solar generation and baseline building demand profiles.

## 4. Key Performance Results
The system was benchmarked against a reactive (Naive) threshold controller over a 365-day operational window:

| Metric | Proposed MPC | Improvement |
| :--- | :--- | :--- |
| **Annual Financial Savings** | **€16,898.35** | +8.1% vs Naive |
| **Final State of Health (SOH)** | **97.68%** | +0.62% preservation |
| **Peak Demand Penalty** | **€0.00** | 100% mitigation |
| **Max Grid Peak** | **351.98 kW** | -42% reduction |



## 5. Deployment Instructions
1.  Clone the repository and ensure the MATLAB **Optimization Toolbox** is installed.
2.  Execute `microgrid_data_engineering.m` to generate the environment variables and stochastic profiles.
3.  Run `mpc_annual_optimization_suite.m` to generate the 52-week financial report and battery degradation plots.

## 6. Authors & Acknowledgments
* **Kareem**, **Daniel**, and **Anwar**
* This work utilizes solar data from the **EU Science Hub PVGIS-SARAH3** database.

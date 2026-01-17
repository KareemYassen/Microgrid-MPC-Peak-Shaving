%% ANNUAL_MASTER_RUN_FINAL_PRO.m
% Purpose: 52-Week Cumulative Battery Health and Detailed Financial Comparison
% Features: MPC Optimization, Peak Demand Tracking, Full Financial Report
% Team: Daniel, Anwar, Kareem
clear; clc; close all;

fprintf('====================================================\n');
fprintf('     ANNUAL ENERGY MANAGEMENT SYSTEM SIMULATION     \n');
fprintf('====================================================\n');

%% 1. Load Data & Constants
if isfile('init_data.m'), run('init_data.m'); else, error('init_data.m not found.'); end

% --- Simulation Parameters ---
dt = 0.25;                  
Battery_Cap_kWh = 250;      
Inverter_Limit_kW = 250;    
Grid_Max_kW = 400;          
Alpha = 0.5;                

% --- Economic Parameters ---
Base_Energy_Rate = 0.15;    % €/kWh 
Fine_Rate = 100;            % € per kW for the MAX peak of the year
Battery_Asset_Value = 50000;% 

% --- Realistic Degradation Coefficients ---
alpha_deg = 0.0005;         
beta_deg  = 0.0002;         
cal_age_factor = 0.000025;  

% --- Timing & Storage Arrays ---
Total_Weeks = 52;
Steps_Per_Week = 672;
total_steps = Total_Weeks * Steps_Per_Week;

SOH_MPC = ones(total_steps, 1) * 100;
SOH_Naive = ones(total_steps, 1) * 100;
SOC_History_MPC = zeros(total_steps, 1);   
SOC_History_Naive = zeros(total_steps, 1); 

% --- Accumulators ---
Energy_MPC = 0; Energy_Naive = 0;
Annual_Peak_MPC = 0;   % Tracks the single highest kW value for the year
Annual_Peak_Naive = 0; % Tracks the single highest kW value for the year

% --- Initial States ---
current_SOH_M = 100; current_SOH_N = 100;
last_SOC_M = 0.5; last_SOC_N = 0.5;

% Pre-calculate Static MPC Matrices (Speed Optimization)
N = Steps_Per_Week;
H = 2 * (1 + Alpha) * eye(N); 
A_cumsum = tril(ones(N));
C_conv = dt / Battery_Cap_kWh;
A_soc = [ (A_cumsum * C_conv); -(A_cumsum * C_conv) ];
LB = -Inverter_Limit_kW * ones(N, 1);
UB =  Inverter_Limit_kW * ones(N, 1);
options = optimoptions('quadprog','Display','off');

%% 2. The Annual Loop
fprintf('Optimizing 52 weeks (Peak Demand Logic)...\n');
for wk = 1:Total_Weeks
    idx = (wk-1)*N+1 : wk*N;
    if idx(end) > length(P_Load_15min), break; end
    
    P_Net_Wk = P_Load_15min(idx) - P_PV_15min(idx);
    
    %% 3. MPC Optimization
    f = -2 * P_Net_Wk;
    b_soc = [ (last_SOC_M - 0.1) * ones(N,1); (0.9 - last_SOC_M) * ones(N,1) ];
    P_Bat_M = quadprog(H, f, A_soc, b_soc, [], [], LB, UB, [], options);
    if isempty(P_Bat_M), P_Bat_M = zeros(N,1); end
    
    %% 4. Naive Simulation
    P_Bat_N = zeros(N,1); temp_soc_n = last_SOC_N;
    for t = 1:N 
        needed = P_Net_Wk(t) - Grid_Max_kW;
        if needed > 0 
            p_out = min([needed, Inverter_Limit_kW, (temp_soc_n - 0.1)*Battery_Cap_kWh/dt]);
        elseif P_Net_Wk(t) < 0 
            p_in = min(abs(P_Net_Wk(t)), Inverter_Limit_kW);
            p_out = -min(p_in, (0.9 - temp_soc_n)*Battery_Cap_kWh/dt);
        else
            p_out = 0;
        end
        P_Bat_N(t) = p_out;
        temp_soc_n = temp_soc_n - (p_out * dt / Battery_Cap_kWh);
    end
    
    %% 5. Financial & State Updates
    P_Grid_M = P_Net_Wk - P_Bat_M;
    P_Grid_N = P_Net_Wk - P_Bat_N;
    
    % Update the Annual Max Peak (Industrial Demand Charge Logic)
    Annual_Peak_MPC = max(Annual_Peak_MPC, max(P_Grid_M));
    Annual_Peak_Naive = max(Annual_Peak_Naive, max(P_Grid_N));
    
    % Calculate Energy Purchase Cost
    Energy_MPC = Energy_MPC + sum(max(0, P_Grid_M) * dt * Base_Energy_Rate);
    Energy_Naive = Energy_Naive + sum(max(0, P_Grid_N) * dt * Base_Energy_Rate);
    
    % Update SOC and History
    SOC_M = last_SOC_M - cumsum(P_Bat_M * dt) / Battery_Cap_kWh;
    SOC_N = last_SOC_N - cumsum(P_Bat_N * dt) / Battery_Cap_kWh;
    SOC_History_MPC(idx) = SOC_M;
    SOC_History_Naive(idx) = SOC_N;
    
    % Degradation Calculation
    Stress_M = alpha_deg*(SOC_M - 0.5).^2 + beta_deg*(P_Bat_M/Battery_Cap_kWh).^2 + cal_age_factor;
    Stress_N = alpha_deg*(SOC_N - 0.5).^2 + beta_deg*(P_Bat_N/Battery_Cap_kWh).^2 + cal_age_factor;
    
    SOH_MPC(idx) = current_SOH_M - cumsum(Stress_M);
    SOH_Naive(idx) = current_SOH_N - cumsum(Stress_N);
    
    % Transition to next week
    current_SOH_M = SOH_MPC(idx(end));
    current_SOH_N = SOH_Naive(idx(end));
    last_SOC_M = SOC_M(end); 
    last_SOC_N = SOC_N(end);
    
    if mod(wk, 10) == 0, fprintf('   Week %d done...\n', wk); end
end

%% 6. Final Financial Calculations
% Penalty based on the single highest peak over the limit for the whole year
Fine_MPC = max(0, Annual_Peak_MPC - Grid_Max_kW) * Fine_Rate;
Fine_Naive = max(0, Annual_Peak_Naive - Grid_Max_kW) * Fine_Rate;

Wear_Cost_MPC = (100 - current_SOH_M)/100 * Battery_Asset_Value;
Wear_Cost_Naive = (100 - current_SOH_N)/100 * Battery_Asset_Value;

Total_Cost_MPC = Energy_MPC + Fine_MPC + Wear_Cost_MPC;
Total_Cost_Naive = Energy_Naive + Fine_Naive + Wear_Cost_Naive;

%% 7. FULL COMPREHENSIVE REPORT
fprintf('\n%s\n', repmat('=', 1, 65));
fprintf('             ANNUAL INDUSTRIAL PERFORMANCE REPORT\n');
fprintf('%s\n', repmat('=', 1, 65));
fprintf('ITEM                       NAIVE STRATEGY     MPC MANAGED\n');
fprintf('%s\n', repmat('-', 1, 65));
fprintf('Energy Purchase Cost:      € %12.2f     € %12.2f\n', Energy_Naive, Energy_MPC);
fprintf('Peak Demand Penalty:       € %12.2f     € %12.2f\n', Fine_Naive, Fine_MPC);
fprintf('Battery Wear (Asset):      € %12.2f     € %12.2f\n', Wear_Cost_Naive, Wear_Cost_MPC);
fprintf('%s\n', repmat('-', 1, 65));
fprintf('TOTAL ANNUAL COST:         € %12.2f     € %12.2f\n', Total_Cost_Naive, Total_Cost_MPC);
fprintf('%s\n', repmat('=', 1, 65));
fprintf('\n>>> NET ANNUAL SAVINGS WITH MPC: € %.2f <<<\n', Total_Cost_Naive - Total_Cost_MPC);
fprintf('\nTECHNICAL SUMMARY:\n');
fprintf('Annual Max Grid Peak:      %7.2f kW        %7.2f kW\n', Annual_Peak_Naive, Annual_Peak_MPC);
fprintf('Final State of Health:      %6.2f%%           %6.2f%%\n', current_SOH_N, current_SOH_M);
fprintf('%s\n', repmat('=', 1, 65));

%% 8. FINAL VISUALIZATIONS
Time_Days = (1:total_steps) / 96;

% Plot 1: SOH Fade
figure('Name', 'Annual Health Analysis', 'Color', 'w');
plot(Time_Days, SOH_Naive, '--r', 'LineWidth', 1.2); hold on;
plot(Time_Days, SOH_MPC, 'b', 'LineWidth', 2);
title('Projected Annual Battery Health (SOH) Fade');
xlabel('Day of Year'); ylabel('SOH (%)');
legend('Naive Strategy', 'MPC Managed'); grid on;

% Plot 2: Financial Stacked Bar
figure('Name', 'Annual Financial Breakdown', 'Color', 'w');
bar_data = [Energy_Naive, Fine_Naive, Wear_Cost_Naive; Energy_MPC, Fine_MPC, Wear_Cost_MPC];
bar(bar_data, 'stacked');
set(gca, 'XTickLabel', {'Naive Strategy', 'MPC Managed'});
ylabel('Total Cost (€)'); title('Cost Distribution: Energy vs. Fines vs. Wear');
legend('Energy', 'Demand Fines', 'Battery Wear'); grid on;

% Plot 3: SOC Distribution (Probability Density)
figure('Name', 'SOC Usage Analysis', 'Color', 'w');
histogram(SOC_History_Naive*100, 50, 'Normalization', 'pdf', 'FaceColor', 'r', 'FaceAlpha', 0.3); hold on;
histogram(SOC_History_MPC*100, 50, 'Normalization', 'pdf', 'FaceColor', 'b', 'FaceAlpha', 0.5);
title('Yearly SOC Distribution (Why MPC is healthier)');
xlabel('State of Charge (%)'); ylabel('Density');
legend('Naive Strategy', 'MPC Managed'); grid on;
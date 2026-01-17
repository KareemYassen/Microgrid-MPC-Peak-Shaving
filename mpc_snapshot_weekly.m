%% MASTER_RUN_FINAL.m - Sustainable Energy Management System
%  Purpose: MPC-based Peak Shaving, Battery Health, & PV Analysis (Quadratic Optimization)
%  Authors: Daniel, Anwar, Kareem
clear; clc; close all;
fprintf('%s\n', repmat('=', 1, 50));
fprintf('      MPC ENERGY MANAGEMENT SYSTEM - STARTING       \n');
fprintf('%s\n', repmat('=', 1, 50));

%% --- STEP 1: DATA INITIALIZATION ---
fprintf('[1/10] Loading Dataset...');
if isfile('init_data.m')
    run('init_data.m'); 
else
    error('init_data.m not found.');
end
fprintf(' DONE.\n');

%% --- STEP 2: CONFIGURATION ---
Selected_Month      = 6;    
Selected_Week       = 4;    
Load_Scaling_Factor = 1.0;  
Inverter_Limit_kW   = 250;  
Battery_Cap_kWh     = 250;  
Eff_Batt            = 0.95; 
Grid_Max_kW         = 400;  
Alpha               = 0.5;  
dt                  = 0.25; 
% Financial Constants
Penalty_Rate_EUR    = 100;   % € per kW exceeded
Energy_Rate_EUR     = 0.15;  % €/kWh 

%% --- STEP 3: TEMPORAL LOGIC & WINDOWING ---
fprintf('[2/10] Segmenting Time Horizon...');
Days_In_Month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
Month_Names   = {'January', 'February', 'March', 'April', 'May', 'June', ...
                 'July', 'August', 'September', 'October', 'November', 'December'};
if Selected_Month == 1
    First_Day_Of_Month = 1;
else
    First_Day_Of_Month = sum(Days_In_Month(1:Selected_Month-1)) + 1;
end
Start_Day_Of_Year = First_Day_Of_Month + (Selected_Week - 1) * 7;
N = 7 * 24 * 4; 
Start_Index = (Start_Day_Of_Year - 1) * 96 + 1;
End_Index   = Start_Index + N - 1;
P_Load_Horizon = P_Load_15min(Start_Index:End_Index) * Load_Scaling_Factor; 
P_PV_Horizon   = P_PV_15min(Start_Index:End_Index);
P_Net          = P_Load_Horizon - P_PV_Horizon;
Time_Horizon   = Time_15min(Start_Index:End_Index); 
fprintf(' DONE (Analyzing: %s, Week %d).\n', Month_Names{Selected_Month}, Selected_Week);

%% --- STEP 4: MPC OPTIMIZATION (QUADRATIC COST) ---
fprintf('[3/10] Solving Quadratic Program (MPC)...');
H = 2 * (1 + Alpha) * eye(N); 
f = -2 * P_Net; 
LB = -Inverter_Limit_kW * ones(N, 1); 
UB =  Inverter_Limit_kW * ones(N, 1);
A_cumsum = tril(ones(N));
C_conv   = dt / Battery_Cap_kWh; 
SOC_Initial = 0.5;
A_soc = [ (A_cumsum * C_conv); -(A_cumsum * C_conv) ]; 
b_soc = [ (SOC_Initial - 0.1) * ones(N,1); (0.9 - SOC_Initial) * ones(N,1) ];
options = optimoptions('quadprog', 'Display', 'off');
[P_Bat_Optimal, ~, exitflag] = quadprog(H, f, A_soc, b_soc, [], [], LB, UB, [], options);
if exitflag ~= 1, error('Optimization failed.'); end
fprintf(' CONVERGED.\n');

%% --- STEP 5: VISUALIZATION: SYSTEM PERFORMANCE (WEEKLY ANALYSIS) ---
fprintf('[4/10] Generating Self-Explanatory Weekly Plots...');
figure('Name', 'MPC Weekly Energy Management Analysis', 'Color', 'w', 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.8]);
Time_Hours = (0:length(Time_Horizon)-1) * dt; 

% Subplot 1: Grid Power
subplot(3,1,1);
plot(Time_Hours, P_Net, 'Color', [0.7 0.7 0.7], 'LineWidth', 1, 'DisplayName', 'Unmanaged (Load - PV)'); hold on;
plot(Time_Hours, P_Net - P_Bat_Optimal, 'Color', [0 0.45 0.74], 'LineWidth', 2, 'DisplayName', 'MPC Managed Grid');
yline(Grid_Max_kW, '--r', 'Grid Limit (400kW)', 'LineWidth', 2);
text(5, Grid_Max_kW + 50, '\leftarrow MPC Shaves Peaks for the Week', 'Color', 'r', 'FontWeight', 'bold');
title(['Weekly Grid Power Demand (', Month_Names{Selected_Month}, ' Week ', num2str(Selected_Week), ')']);
ylabel('Power (kW)'); grid on; legend('Location', 'northeast');
xlim([0 168]);

% Subplot 2: Solar PV
subplot(3,1,2);
area(Time_Hours, P_PV_Horizon, 'FaceColor', [1 0.85 0], 'FaceAlpha', 0.6, 'DisplayName', 'Solar Power Input');
title('Weekly Renewable Energy: Solar PV Generation Profile');
ylabel('Power (kW)'); grid on; legend;
xlim([0 168]);

% Subplot 3: MPC Dispatch
subplot(3,1,3);
area(Time_Hours, P_Bat_Optimal, 'FaceColor', [0.47 0.67 0.19], 'FaceAlpha', 0.5);
hold on; yline(0, '-k', 'LineWidth', 0.5);
text(10, max(P_Bat_Optimal), 'Positive = Discharging \uparrow', 'Color', [0.2 0.4 0], 'FontWeight', 'bold');
text(10, min(P_Bat_Optimal)-20, 'Negative = Charging \downarrow', 'Color', [0.2 0.4 0], 'FontWeight', 'bold');
title('Weekly MPC Battery Dispatch Schedule (P_{bat})');
ylabel('Power (kW)'); xlabel('Time (Hours from Monday 00:00)'); grid on;
legend('Optimal Dispatch Signal', 'Location', 'northeast');
xlim([0 168]);
fprintf(' DONE.\n');
figure(1); 
saveas(gcf, 'fig_weekly_ops.pdf');

%% --- STEP 6: BATTERY HEALTH ANALYSIS ---
fprintf('[5/10] Analyzing Battery Longevity...');
SOC_Managed = SOC_Initial - cumsum(P_Bat_Optimal * dt) / Battery_Cap_kWh;
alpha_deg = 0.0001; beta_deg = 0.00001; 
Stress_M = alpha_deg*(SOC_Managed - 0.5).^2 + beta_deg*(P_Bat_Optimal/Battery_Cap_kWh).^2;
Health_M = 100 - cumsum(Stress_M * 10); 
fprintf(' DONE.\n');

%% --- STEP 7: SIMULINK MODEL BUILDING & SYNC ---
fprintf('[7/10] Synchronizing Simulink...');
Index_Vector = (0:N)'; 
assignin('base', 'ts_Load', timeseries([P_Load_Horizon; P_Load_Horizon(end)], Index_Vector));
assignin('base', 'ts_PV',   timeseries([P_PV_Horizon;   P_PV_Horizon(end)], Index_Vector));
assignin('base', 'ts_MPC_Signal', timeseries([P_Bat_Optimal;  P_Bat_Optimal(end)], Index_Vector));
modelName = 'ShoppingMall_MPC';
if isfile([modelName '.slx'])
    open_system(modelName);
    Simulink.BlockDiagram.deleteContents(modelName); 
else
    new_system(modelName);
    open_system(modelName);
end
set_param(modelName, 'StopTime', string(N), 'Solver', 'FixedStepDiscrete', 'FixedStep', '1');      
add_block('simulink/Sources/From Workspace', [modelName '/MPC Controller'], 'Position', [50, 310, 150, 340]);
add_block('simulink/Sources/From Workspace', [modelName '/Mall Load'], 'Position', [50, 150, 150, 200]);
add_block('simulink/Sources/From Workspace', [modelName '/PV Generation'], 'Position', [50, 50, 150, 100]);
add_block('simulink/Math Operations/Sum', [modelName '/Grid Calculation'], 'Position', [350, 100, 390, 250]);
add_block('simulink/Discrete/Discrete-Time Integrator', [modelName '/Battery Physics'], 'Position', [350, 300, 450, 350]);
add_block('simulink/Math Operations/Gain', [modelName '/Sign Fix'], 'Position', [200, 310, 250, 340]);
add_block('simulink/Sinks/Scope', [modelName '/Grid Performance'], 'Position', [550, 150, 600, 200]);
add_block('simulink/Sinks/Scope', [modelName '/SOC Scope'], 'Position', [550, 300, 600, 350]);
set_param([modelName '/MPC Controller'], 'VariableName', 'ts_MPC_Signal');
set_param([modelName '/Mall Load'], 'VariableName', 'ts_Load');
set_param([modelName '/PV Generation'], 'VariableName', 'ts_PV');
set_param([modelName '/Grid Calculation'], 'Inputs', '+--'); 
set_param([modelName '/Sign Fix'], 'Gain', '-1'); 
set_param([modelName '/Battery Physics'], ...
          'gainval', sprintf('%f/(%d*4)', Eff_Batt, Battery_Cap_kWh), ...
          'InitialCondition', '0.5', 'LimitOutput', 'on', 'UpperSaturationLimit', '0.9', 'LowerSaturationLimit', '0.1');
delete_line(find_system(modelName, 'FindAll', 'on', 'Type', 'line')); 
add_line(modelName, 'Mall Load/1', 'Grid Calculation/1');
add_line(modelName, 'PV Generation/1', 'Grid Calculation/2');
add_line(modelName, 'MPC Controller/1', 'Grid Calculation/3');
add_line(modelName, 'MPC Controller/1', 'Sign Fix/1');
add_line(modelName, 'Sign Fix/1', 'Battery Physics/1');
add_line(modelName, 'Grid Calculation/1', 'Grid Performance/1');
add_line(modelName, 'Battery Physics/1', 'SOC Scope/1');
save_system(modelName);
fprintf(' DONE.\n');

%% --- STEP 8: FINANCIAL BENCHMARKING ---
fprintf('[9/10] Calculating Financial Impact...');
P_Grid_Unmanaged = max(0, P_Net);
P_Grid_MPC       = max(0, P_Net - P_Bat_Optimal);
Peak_Unmanaged    = max(P_Grid_Unmanaged);
Peak_MPC          = max(P_Grid_MPC);
Penalty_Unmanaged = max(0, Peak_Unmanaged - Grid_Max_kW) * Penalty_Rate_EUR;
Penalty_MPC       = max(0, Peak_MPC - Grid_Max_kW) * Penalty_Rate_EUR;
Cost_Energy_Unmanaged = sum(P_Grid_Unmanaged * dt * Energy_Rate_EUR);
Cost_Energy_MPC       = sum(P_Grid_MPC * dt * Energy_Rate_EUR);
Total_Unmanaged = Cost_Energy_Unmanaged + Penalty_Unmanaged;
Total_MPC       = Cost_Energy_MPC + Penalty_MPC;
Total_Savings   = Total_Unmanaged - Total_MPC;
fprintf(' DONE.\n');

%% --- STEP 9: FINAL REPORT ---
fprintf('\n\n%s\n', repmat('=', 1, 50));
fprintf('       ECONOMIC IMPACT REPORT (Weekly)\n');
fprintf('%s\n', repmat('-', 1, 50));
fprintf('Metric            | Non-Managed  | MPC Managed\n');
fprintf('%s\n', repmat('-', 1, 50));
fprintf('Highest Peak (kW) | %10.2f | %10.2f\n', Peak_Unmanaged, Peak_MPC);
fprintf('Energy Cost (€)   | %10.2f | %10.2f\n', Cost_Energy_Unmanaged, Cost_Energy_MPC);
fprintf('Peak Penalty (€)  | %10.2f | %10.2f\n', Penalty_Unmanaged, Penalty_MPC);
fprintf('%s\n', repmat('-', 1, 50));
fprintf('TOTAL COST (€)    | %10.2f | %10.2f\n', Total_Unmanaged, Total_MPC);
fprintf('%s\n', repmat('=', 1, 50));
fprintf('TOTAL MONEY SAVED THIS WEEK: € %.2f\n', Total_Savings);
fprintf('%s\n', repmat('=', 1, 50));
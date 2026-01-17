%% init_data.m
%  Step 1 of Implementation: Data Engineering
%  Team: Daniel, Anwar, Kareem
%  Purpose: Loads raw PV data and generates synthetic EV load profile.
%  UPDATE: Added AC/DC History tracking for Figure 3 Histogram.
clear; clc; close all;
fprintf('=== STARTING DATA INITIALIZATION ===\n');

%% 1. PV Generation Data (The Sun)
filename = 'Timeseries_51.028_7.563_SA3_1kWp_crystSi_14_35deg_0deg_2023_2023.csv'; 
if ~isfile(filename)
    if isfile('PV_Data_Raw.csv'), filename = 'PV_Data_Raw.csv';
    else, error('File not found!'); end
end

opts = detectImportOptions(filename);
opts.DataLines = [11 Inf]; 
opts.VariableNamingRule = 'preserve';
raw_table = readtable(filename, opts);

if ismember('P', raw_table.Properties.VariableNames)
    P_1kW_unit = raw_table.P; 
else
    raw_matrix = readmatrix(filename);
    P_1kW_unit = raw_matrix(:, 2); 
end

P_1kW_unit = double(P_1kW_unit);
P_1kW_unit(isnan(P_1kW_unit)) = 0;
System_Size_kWp = 500; 
P_PV_kW = (P_1kW_unit * System_Size_kWp) / 1000;

Time_Hours = (0:length(P_PV_kW)-1)';
Time_15min = (0:0.25:(length(P_PV_kW)-1))';
P_PV_15min = interp1(Time_Hours, P_PV_kW, Time_15min, 'linear');

%% 2. Simulation Parameters
Battery_Capacity_kWh = 250;
Inverter_Power_kW = 250;
Grid_Limit_kW = 400;

%% 3. EV Load Generation (Independent Events)
fprintf('Generating Stochastic Load Profile (Dual-Mode)...\n');
Load_Building = 200 * ones(size(Time_15min)); 
Load_EV = zeros(size(Time_15min));

% --- NEW: Initialize History Arrays for Figure 3 ---
Load_AC_History = zeros(size(Time_15min));   
Load_DC_History = zeros(size(Time_15min));   

rng(42); 
for i = 1:length(Time_15min)
    hour_of_day = mod(Time_15min(i), 24);
    
    if hour_of_day >= 17 && hour_of_day <= 20
        prob_arrival = 0.30; 
    elseif hour_of_day >= 12 && hour_of_day <= 14
        prob_arrival = 0.10;
    else
        prob_arrival = 0.02;
    end
    
    % 1. Roll for Fast Chargers (DC)
    if rand() < prob_arrival && rand() < 0.2 
        Load_Fast = 150 + (rand() * 150); 
    else
        Load_Fast = 0;
    end
    
    % 2. Roll for AC Chargers
    if rand() < prob_arrival && rand() < 0.8 
        Load_AC = 11 * randi([5, 10]); 
    else
        Load_AC = 0;
    end
    
    % --- NEW: Store values in history vectors ---
    Load_AC_History(i) = Load_AC;
    Load_DC_History(i) = Load_Fast; 
    Load_EV(i) = Load_Fast + Load_AC; 
end

P_Load_15min = Load_Building + Load_EV;
fprintf('=== DATA INITIALIZATION COMPLETE ===\n');
fprintf('   > TOTAL MAX PEAK: %.2f kW\n', max(P_Load_15min));
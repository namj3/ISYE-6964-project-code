% System Parameters
num_steps = 20; % Number of simulation steps
demanded_power = 10; % Power demand in MWh
fine_rate = 100; % Fine rate per undelivered MWh
Team_Cost_A = 10; %
Team_Cost_B = 7; %
% Components and Failure Probabilities
components = {'generator', 'transformer1', 'transformer2', 'transformer3','transformer4', 'transformer5', 'transformer6','transmission1', 'transmission2', 'transmission3'};
num_components = length(components);

% Original and current failure probabilities
failure_prob = [0.05, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.15, 0.15, 0.15];
current_failure_prob = failure_prob;
original_failure_prob = failure_prob;

repair_probs_A = [0.8, 0.9 * ones(1, 6), 0.95 * ones(1, 3)];
repair_probs_B = [0.6, 0.75 * ones(1, 6), 0.7 * ones(1, 3)];
previous_state = zeros(num_components, 1);

% Connections in the Power System
connections = {
    8, [2, 3]; % Transmission Line 1 -> Transformers 1 and 2
    9, [4, 5]; % Transmission Line 2 -> Transformers 3 and 4
    10, [6, 7]; % Transmission Line 3 -> Transformers 5 and 6
};

% Initialize System States
states = zeros(num_components, num_steps); % 0: operational, 1: failed
best_policy = zeros(num_steps, 2); % [Team A target, Team B target]

depth = 5; % Maximum depth for forward search
operational_cost = 0; 
for step = 1:num_steps
    if step > 1
        states(:, step) = states(:, step - 1);
    end

    % Simulate failures
    for i = 1:num_components
        if states(i, step) == 0 % If the component is operational
            if rand < current_failure_prob(i)
                states(i, step) = 1; % Component fails
            end
        end
    end

    % Increment failure probabilities for all components
    for i = 1:num_components
        if states(i, step) == 0 % Component is operational
            if previous_state(i) == 1 % Component was repaired
                current_failure_prob(i) = original_failure_prob(i); % Reset probability
            else
                current_failure_prob(i) = current_failure_prob(i) + 0.0001; % Increment failure probability
            end
        else
            current_failure_prob(i) = current_failure_prob(i) + 0.0001; % Increment for broken component
        end
    end

    % Forward Search for Optimal Repair Policy
    current_state = states(:, step);
    [best_team_A, best_team_B] = forward_search(current_state, current_failure_prob, original_failure_prob, repair_probs_A, repair_probs_B, demanded_power, fine_rate, connections, depth, components);

    % Log broken components
    broken_components = find(current_state == 1);
    
    undelivered_power_temp = calculate_undelivered_power(current_state, demanded_power, connections);
    operational_cost = undelivered_power_temp*fine_rate;
    
    broken_names = cellfun(@(x) components{x}, num2cell(broken_components), 'UniformOutput', false);
    if isempty(broken_names)
        fprintf('Step %d: Broken components -> None\n', step);
    else
        fprintf('Step %d: Broken components -> %s\n', step, strjoin(broken_names, ', '));
    end

    % Log team actions
    if best_team_A > 0
        team_A_str = components{best_team_A};
        operational_cost = operational_cost + Team_Cost_A;
    else
        team_A_str = 'None';
    end

    if best_team_B > 0
        team_B_str = components{best_team_B};
        operational_cost = operational_cost + Team_Cost_B;
    else
        team_B_str = 'None';
    end

    fprintf('Step %d: Team A -> %s, Team B -> %s\n', step, team_A_str, team_B_str);

    % Apply repairs and preventive maintenance
    if best_team_A > 0
        current_failure_prob(best_team_A) = original_failure_prob(best_team_A); % Reset failure probability
        if states(best_team_A, step) == 1 % Repair if broken
            if rand < repair_probs_A(best_team_A)
                states(best_team_A, step) = 0; % Repair succeeds
            end
        end
    end

    if best_team_B > 0
        current_failure_prob(best_team_B) = original_failure_prob(best_team_B); % Reset failure probability
        if states(best_team_B, step) == 1 % Repair if broken
            if rand < repair_probs_B(best_team_B)
                states(best_team_B, step) = 0; % Repair succeeds
            end
        end
    end

    
    previous_state = states(:, step);
end

% Function for Forward Search
function [best_team_A, best_team_B] = forward_search(current_state, current_failure_prob, original_failure_prob, repair_probs_A, repair_probs_B, demanded_power, fine_rate, connections, depth, components)

    num_components = numel(current_state);

    % Generate all possible team assignments
    assignments = combvec(0:num_components, 0:num_components)';
    assignments = assignments(assignments(:, 1) ~= assignments(:, 2), :);

    best_cost = inf;
    best_team_A = 0;
    best_team_B = 0;

    for i = 1:size(assignments, 1)
        team_A = assignments(i, 1);
        team_B = assignments(i, 2);

        % Simulate forward search
        simulated_state = current_state;
        simulated_failure_prob = current_failure_prob;

        total_cost = 0;

        for step = 1:depth
            % Repair or maintain with Team A
            if team_A > 0
                simulated_failure_prob(team_A) = original_failure_prob(team_A); % Reset probability
                if simulated_state(team_A) == 1 && rand < repair_probs_A(team_A)
                    simulated_state(team_A) = 0; % Repair succeeds
                end
            end

            % Repair or maintain with Team B
            if team_B > 0
                simulated_failure_prob(team_B) = original_failure_prob(team_B); % Reset probability
                if simulated_state(team_B) == 1 && rand < repair_probs_B(team_B)
                    simulated_state(team_B) = 0; % Repair succeeds
                end
            end

            % Calculate undelivered power and associated costs
            undelivered_power = calculate_undelivered_power(simulated_state, demanded_power, connections);
            step_cost = fine_rate * undelivered_power;

        
%             if team_B == 0 && any(simulated_state == 1)
%                 step_cost = step_cost + fine_rate / 2;
%             end

            total_cost = total_cost + step_cost;

            % Simulate failures for next step
            for j = 1:num_components
                if simulated_state(j) == 0 && rand < simulated_failure_prob(j)
                    simulated_state(j) = 1; % Component fails
                end
            end
        end

        % Update best assignment if cost is lower
        if total_cost < best_cost
            best_cost = total_cost;
            best_team_A = team_A;
            best_team_B = team_B;
        end
    end

    % Ensure Team B is assigned to repair if failed components remain
    if best_team_B == 0 && any(current_state == 1)
        % Assign Team B to the first failed component not assigned to Team A
        remaining_failures = find(current_state == 1);
        if ~isempty(remaining_failures) && ~ismember(best_team_A, remaining_failures)
            best_team_B = remaining_failures(1);
        end
    end
end

% Function to Calculate Undelivered Power
% This is the only function that needs to be adjusted if you change system
% configuration (undelivered power calculation)
function undelivered_power = calculate_undelivered_power(state, demanded_power, connections)
    
    undelivered_power = 0;
    if state(1) == 1 % If generator fails, no power is delivered
        undelivered_power = demanded_power;
        return;
    end
    for i = 1:size(connections, 1)
        if state(connections{i, 1}) == 1 || any(state(connections{i, 2}) == 1)
            undelivered_power = undelivered_power + demanded_power / 3;
        end
    end
end
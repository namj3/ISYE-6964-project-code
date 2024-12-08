% Monte Carlo Tree Search
% System Parameters
num_steps = 10; % Number of simulation steps
demanded_power = 10; % Power demand in MWh
fine_rate = 100; % Fine rate per undelivered MWh
Team_Cost_A = 10; % Cost for Team A
Team_Cost_B = 7; % Cost for Team B

% Components and Failure Probabilities
components = {'generator', 'transformer1', 'transformer2', 'transformer3', 'transformer4', 'transformer5', 'transformer6', 'transmission1', 'transmission2', 'transmission3'};
num_components = length(components);

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
states = zeros(num_components, num_steps);
operational_cost = 0;

% Simulation Steps
for step = 1:num_steps
    if step > 1
        states(:, step) = states(:, step - 1);
    end

    % Simulate Failures
    for i = 1:num_components
        if states(i, step) == 0 && rand < current_failure_prob(i)
            states(i, step) = 1; % Component fails
        end
    end

    % Increment failure probabilities
    for i = 1:num_components
        if states(i, step) == 0 && previous_state(i) == 1
            current_failure_prob(i) = original_failure_prob(i);
        else
            current_failure_prob(i) = current_failure_prob(i) + 0.0001;
        end
    end

    % MCTS for Optimal Repair Policy
    current_state = states(:, step);
    [best_team_A, best_team_B] = mcts_search(current_state, current_failure_prob, repair_probs_A, repair_probs_B, demanded_power, fine_rate, connections, components);

    % Log Costs and Actions
    operational_cost = operational_cost + calculate_undelivered_power(current_state, demanded_power, connections) * fine_rate;
    operational_cost = operational_cost + (best_team_A > 0) * Team_Cost_A + (best_team_B > 0) * Team_Cost_B;
    
    
    
    %fprintf('Operational cost is -> %s\n', operational_cost);

    % Apply Repairs
    if best_team_A > 0
        current_failure_prob(best_team_A) = original_failure_prob(best_team_A);
        if states(best_team_A, step) == 1 && rand < repair_probs_A(best_team_A)
            states(best_team_A, step) = 0; % Repair succeeds
        end
    end

    if best_team_B > 0
        current_failure_prob(best_team_B) = original_failure_prob(best_team_B);
        if states(best_team_B, step) == 1 && rand < repair_probs_B(best_team_B)
            states(best_team_B, step) = 0; % Repair succeeds
        end
    end

    previous_state = states(:, step);
end
fprintf('Total operational cost is -> %s\n', operational_cost);

function [best_team_A, best_team_B] = mcts_search(current_state, current_failure_prob, repair_probs_A, repair_probs_B, demanded_power, fine_rate, connections, components)

    iterations = 100; % Number of MCTS iterations
    depth = 5; % Simulation depth
    num_components = numel(current_state);

    valid_assignments = [];
    for team_A = 0:num_components
        for team_B = 0:num_components
            if team_A ~= team_B || (team_A == 0 && team_B == 0) % Allow 'no action'
                valid_assignments = [valid_assignments; team_A, team_B];
            end
        end
    end

   
    Q = zeros(num_components + 1, num_components + 1); % Average cost
    N = zeros(num_components + 1, num_components + 1); % Visit counts
    %making sure Teams A and B are not assigned to the same node
    visit_penalty = zeros(num_components + 1, num_components + 1); 

    for iter = 1:iterations
        % Selection and Expansion
        idx = randi(size(valid_assignments, 1));
        team_A = valid_assignments(idx, 1);
        team_B = valid_assignments(idx, 2);

        % Simulation
        total_cost = simulate_path(current_state, current_failure_prob, ...
            team_A, team_B, repair_probs_A, repair_probs_B, demanded_power, fine_rate, ...
            connections, depth);

      
        regularized_cost = total_cost + 0.1 * visit_penalty(team_A + 1, team_B + 1);

        N(team_A + 1, team_B + 1) = N(team_A + 1, team_B + 1) + 1;
        Q(team_A + 1, team_B + 1) = Q(team_A + 1, team_B + 1) + (regularized_cost - Q(team_A + 1, team_B + 1)) / N(team_A + 1, team_B + 1);

        visit_penalty(team_A + 1, team_B + 1) = visit_penalty(team_A + 1, team_B + 1) + 1;
    end

    % Best Action Selection: Find the team assignments with the minimum average cost
    [~, idx] = min(Q(:));
    [best_team_A, best_team_B] = ind2sub(size(Q), idx);
    best_team_A = best_team_A - 1; 
    best_team_B = best_team_B - 1; 
end
% Simulate Trajectory
function total_cost = simulate_path(state, failure_prob, team_A, team_B, repair_probs_A, repair_probs_B, demanded_power, fine_rate, connections, depth)

    total_cost = 0;
    for t = 1:depth
        % Apply Repairs
        if team_A > 0 && state(team_A) == 1 && rand < repair_probs_A(team_A)
            state(team_A) = 0; % Repair succeeds
        end
        if team_B > 0 && state(team_B) == 1 && rand < repair_probs_B(team_B)
            state(team_B) = 0; % Repair succeeds
        end

        % Calculate Undelivered Power Cost
        total_cost = total_cost + calculate_undelivered_power(state, demanded_power, connections) * fine_rate;

        % Simulate Failures
        for i = 1:length(state)
            if state(i) == 0 && rand < failure_prob(i)
                state(i) = 1; % Component fails
            end
        end
    end
end

% Function to Calculate Undelivered Power
function undelivered_power = calculate_undelivered_power(state, demanded_power, connections)
    undelivered_power = 0;
    if state(1) == 1 % Generator fails
        undelivered_power = demanded_power;
        return;
    end
    for i = 1:size(connections, 1)
        if state(connections{i, 1}) == 1 || any(state(connections{i, 2}) == 1)
            undelivered_power = undelivered_power + demanded_power / 3;
        end
    end
end
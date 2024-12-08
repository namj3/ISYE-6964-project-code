% System Parameters
num_steps = 20; % Number of simulation steps
demanded_power = 10; % Power demand in MWh
fine_rate = 100; % Fine rate per undelivered MWh

% Components and Failure Probabilities
components = {'generator', 'transformer1', 'transformer2', 'transformer3', 'transformer4', 'transformer5', 'transformer6', 'transmission1', 'transmission2', 'transmission3'};
num_components = length(components);

failure_prob = [0.05, 0.08 * ones(1, 6), 0.15 * ones(1, 3)];
repair_probs_A = [0.8, 0.9 * ones(1, 6), 0.95 * ones(1, 3)];
repair_probs_B = [0.6, 0.75 * ones(1, 6), 0.7 * ones(1, 3)];

% Connections in the Power System
connections = {
    [2, 3, 8], % Transformers 1 & 2 and Transmission Line 1
    [4, 5, 9], % Transformers 3 & 4 and Transmission Line 2
    [6, 7, 10] % Transformers 5 & 6 and Transmission Line 3
};

% Initialize System States
states = zeros(num_components, num_steps); % 0: operational, 1: failed
best_policy = zeros(num_steps, 2); % [Team A target, Team B target]

% Simulate Failure Process
for step = 1:num_steps
    if step > 1
        states(:, step) = states(:, step - 1); % Carry forward the previous state
    end

    % Simulate failures
    for i = 1:num_components
        if states(i, step) == 0 && rand < failure_prob(i)
            states(i, step) = 1; % Component fails
        end
    end

    % Breadth-First Search for Optimal Repair Policy
    current_state = states(:, step);
    broken_components = find(current_state == 1); % Identify failed components

    broken_names = cellfun(@(x) components{x}, num2cell(broken_components), 'UniformOutput', false);

    if isempty(broken_components)
        best_team_A = 0;
        best_team_B = 0;
    else
        % Generate all possible assignments for BFS
        assignments = combvec([broken_components; 0], [broken_components; 0])'; % All combinations of actions
        assignments = assignments(assignments(:, 1) ~= assignments(:, 2), :); % Remove invalid cases where A and B target the same component

        % Initialize minimum cost
        min_cost = inf;
        best_assignment = [0, 0];

        % Evaluate each trajectory
        for i = 1:size(assignments, 1)
            trajectory = repmat(assignments(i, :), 5, 1); % Repeat assignment for depth 5
            total_cost = lookahead(current_state, trajectory, repair_probs_A, repair_probs_B, demanded_power, fine_rate, connections);

            % Update best assignment if cost is lower
            if total_cost < min_cost
                min_cost = total_cost;
                best_assignment = assignments(i, :);
            end
        end

        % Assign the best actions for this step
        best_team_A = best_assignment(1);
        best_team_B = best_assignment(2);
    end

    % Log broken components
    if isempty(broken_names)
        fprintf('Step %d: Broken components -> None\n', step);
    else
        fprintf('Step %d: Broken components -> %s\n', step, strjoin(broken_names, ', '));
    end

    % Log team actions
    if best_team_A > 0
        team_A_str = components{best_team_A};
    else
        team_A_str = 'None';
    end

    if best_team_B > 0
        team_B_str = components{best_team_B};
    else
        team_B_str = 'None';
    end

    fprintf('Step %d: Team A -> %s, Team B -> %s\n', step, team_A_str, team_B_str);

    % Simulate repairs
    if best_team_A > 0 && current_state(best_team_A) == 1
        if rand < repair_probs_A(best_team_A)
            current_state(best_team_A) = 0; % Repair succeeds
        end
    end

    if best_team_B > 0 && current_state(best_team_B) == 1
        if rand < repair_probs_B(best_team_B)
            current_state(best_team_B) = 0; % Repair succeeds
        end
    end

    % Update state for the next step
    states(:, step) = current_state;
end
% Evaluate Trajectory Function
function total_cost = lookahead(initial_state, trajectory, repair_probs_A, repair_probs_B, demanded_power, fine_rate, connections)
    current_state = initial_state;
    total_cost = 0;
    
    for t = 1:size(trajectory, 1)
        % Extract actions for Team A and Team B at this step
        team_A_target = trajectory(t, 1);
        team_B_target = trajectory(t, 2);

        % Simulate repairs
        if team_A_target > 0 && current_state(team_A_target) == 1
            if rand < repair_probs_A(team_A_target)
                current_state(team_A_target) = 0; % Repair succeeds
            end
        end
        if team_B_target > 0 && current_state(team_B_target) == 1
            if rand < repair_probs_B(team_B_target)
                current_state(team_B_target) = 0; % Repair succeeds
            end
        end

        % Calculate undelivered power for the current state
        undelivered_power = 0;
        if current_state(1) == 1 % Generator failed
            undelivered_power = demanded_power; % No power delivered
        else
            for conn_idx = 1:length(connections)
                connection = connections{conn_idx};
                if any(current_state(connection) == 1) % Any component in the connection failed
                    undelivered_power = undelivered_power + demanded_power / 3;
                end
            end
        end

        % Add cost for this step
        total_cost = total_cost + undelivered_power * fine_rate;
    end
end

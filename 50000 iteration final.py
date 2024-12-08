import random

def simulate(n, m, max_iterations=50000, failure_rate=0.08):
    turn_count = 0
    node_status = ["normal" for _ in range(n)]
    
    success_prob = [0.9 if i % 2 == 1 else 0.75 for i in range(m)]
    
    while turn_count < max_iterations:
        turn_count += 1
       
        for i in range(n):
            if node_status[i] != "broken" and random.random() < failure_rate:
                node_status[i] = "broken"
        
       
        if "broken" not in node_status:
            return turn_count
        
       
        broken_nodes = [i for i, status in enumerate(node_status) if status == "broken"]
        for i in range(min(len(broken_nodes), m)):
            node_index = broken_nodes[i]
            team_index = i % m
            if random.random() < success_prob[team_index]:
                node_status[node_index] = "normal"
    
   
    return max_iterations

if __name__ == "__main__":
    while True:
        
        while True:
            try:
                m = int(input("Enter the number of teams: "))
                if m > 0:
                    break
                else:
                    print("Please enter a positive integer.")
            except ValueError:
                print("Invalid input. Please enter a valid integer for the number of teams.")
        
        total_nodes = 0
        num_simulations = 10

        for _ in range(num_simulations):
            n = 1
            while True:
                iterations = simulate(n, m)
                if iterations < 50000:
                    n += 1
                else:
                    total_nodes += (n - 1)
                    break

        avg_nodes = total_nodes / num_simulations  
        print(f"For {m} teams, the average maximum number of nodes to avoid infinite iterations is: {avg_nodes}")

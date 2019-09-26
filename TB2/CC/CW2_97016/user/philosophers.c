
#include <philosophers.h>

/*
*   I use Dijkstra's approach, in which each fork has an order, and so
*   if each philosopher has to take the lowest ordered fork first, it
*   is impossible for all to hold the lowest ordered fork at the same time,
*   thus avoiding deadlock. My attempts to avoid starvation pretty much
*   failed as the low-pid philosophers didn't engage much
*   and the 'greedy' function created some deadlocks
*/

int forks[PHILOSOPHERS_N];  // Completely analogous to an array of semaphores
int pipes[PHILOSOPHERS_N]; // One pipe between each philosopher and the managing process
int ate[PHILOSOPHERS_N];
pid_t main_pid;
extern void main_philo();

int greedy(int i){
  for(int j = 0; j < PHILOSOPHERS_N; j++){
      if(ate[i]-ate[j] > 3) return 1;
  }
  return 0;
}

void monitor(){
    int f;
    while(1){
      for(int i = 0; i < PHILOSOPHERS_N; i++){
          f = read_pipe(pipes[i]);
          if(f >= REQ_FORK && f < REQ_FORK + PHILOSOPHERS_N){
            if(forks[f - REQ_FORK] /*&& !greedy(i)*/){
              // If semaphore says fork is available, grant
              forks[f - REQ_FORK]--; // Block fork
              write_pipe(pipes[i],F_YOURS); // Tell philosopher the fork is theirs
            }
          }
          else if (f >= RF_DOWN && f < RF_DOWN + PHILOSOPHERS_N){
            // Philosopher i wants to put forks down, always allow this
            forks[ f - RF_DOWN ]++;  // Fork is now availabe
            write_pipe( pipes[i], F_DOWN );  // Let philosopher know the fork is down
          }
          else if (f == I_ATE){
            // Philosopher has eaten, take note and let them know note was taken
            ate[i]++;
            write_pipe(pipes[i], YOU_ATE);
          }
      }
    }
}


void initialise(){
  pid_t main_pid, child;
  main_pid = get_pid();
  nice(main_pid,8);   // Set priority high to accelerate communications and creation of children

  for(int i = 0; i < PHILOSOPHERS_N; i++){
      ate[i] = 0; forks[i] = 1;

      child = fork();
      if(child == 0){ // Child process
        exec(&main_philo);
      }
      else{ // Parent process
          pipes[i] = create_pipe(child,main_pid);
          write_pipe(pipes[i],i); // Tell ith child what its left fork is
      }
  }
}

void main_philosophers(){

  // Fork PHILOSOPHERS_N philo processes
  initialise();

  // Act as 'waiter', monitoring requests and acting like a semaphore
  monitor();

  exit(EXIT_SUCCESS);
}

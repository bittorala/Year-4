// LO18144 - CANDIDATE NO. 97016

/*
*   Each philosopher is given two forks with different hierarchical order
*   Every time they attempt to eat, they have to take the fork with
*   lowest order first. If they get that, they try to get the second
*   fork. If they succeed, they eat, they try to put the forks down,
*   and they do some math before getting hungry again
*/

#include <philo.h>


int hcf(int a, int b){ // gcd of two positive integers
    if(a > b) return hcf(a-b,b);
    else if (b > a) return hcf(a,b-a);
    else return a;
}

int lcm(int a,int b){ // lcm of two nonzero integers
  return a*b/hcf(a,b);
}

void think(){
    for(int i = 13; i < 550; i++){
      for(int j = 17; j < 500; j++){
        lcm(i,j);
      }
    }
}



void main_philo(){

      const int PHILOSOPHERS_N = 16; // We could pass this by the pipe and
                                    // hide it from the philosophers

      pid_t pid = get_pid();
      char * message;
      int pipeno;
      char * greeting = "Philosopher    joined the table\n";
      greeting[12] = '0' + pid / 10;
      greeting[13] = '0' + pid % 10;
      write( STDOUT_FILENO, greeting, 32);


      // Find pipe between philo and the 'waiter' process
      pipeno = find_pipe(pid);
      while(pipeno == -1) pipeno = find_pipe(pid);

      // Learn what forks correspond to philo
      int read, first_fork, second_fork;
      read = read_pipe(pipeno);
      while(read == EMPTY_PIPE){
        read = read_pipe(pipeno);
      }

      if(read < (read + 1) % PHILOSOPHERS_N){
         first_fork = read;
         second_fork = (read + 1) % PHILOSOPHERS_N;
       }
      else{
          first_fork = (read + 1) % PHILOSOPHERS_N;
          second_fork = read;
       }

       if( first_fork < 0 ) first_fork += PHILOSOPHERS_N;
       if( second_fork < 0 ) second_fork += PHILOSOPHERS_N;


       if( pid == 3 ){
          char * error = "EE EE\n";
          error[0] = first_fork / 10;
          error[1] = first_fork % 10;

          error[3] = second_fork / 10;
          error[4] = second_fork % 10;
          write(STDOUT_FILENO, error, 6);
       }



      while(1){

        // Ask for first fork
        write_pipe( pipeno, REQ_FORK + first_fork );
        yield();  // Let the waiter do the job

        read = read_pipe(pipeno);
        while(read != F_YOURS){  // Wait until fork is secured
          read = read_pipe(pipeno);
        }
        // First fork taken
        message = "   took 1st fork\n";
        message[0] = '0' + pid / 10;
        message[1] = '0' + pid % 10;
        write(STDOUT_FILENO, message, 17);

        // Ask for second fork
        write_pipe( pipeno, REQ_FORK + second_fork );
        yield();  // Let waiter do the job
        while(read != F_YOURS){
          read = read_pipe(pipeno);
        }
        message = "   took 2nd fork\n";
        message[0] = '0' + pid / 10;
        message[1] = '0' + pid % 10;
        // Second fork taken
        write( STDOUT_FILENO, message, 17);

        message = "   is eating\n";
        message[0] = '0' + pid / 10;
        message[1] = '0' + pid % 10;
        // Philosopher has been given both forks
        write( STDOUT_FILENO, message, 13);

        write_pipe(pipeno, I_ATE);
        yield();
        while(read != YOU_ATE) read = read_pipe(pipeno);

        // Try to put first fork down
        write_pipe( pipeno, RF_DOWN + first_fork );
        yield();
        while(read != F_DOWN) read = read_pipe(pipeno);

        // First fork down
        message = "   put 1st fork down\n";
        message[0] = '0' + pid / 10;
        message[1] = '0' + pid % 10;
        write(STDOUT_FILENO, message, 21);

        // Try to put second fork down
        write_pipe( pipeno, RF_DOWN + second_fork );
        yield();
        while(read != F_DOWN) read = read_pipe(pipeno);

        // Second fork down
        message = "   put 2nd fork down\n";
        message[0] = '0' + pid / 10;
        message[1] = '0' + pid % 10;
        write(STDOUT_FILENO, message, 21);

        // Philosopher ate and put the forks down, now goes to think
        think();
      }
      exit(EXIT_SUCCESS);
}

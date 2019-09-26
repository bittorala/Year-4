#include "test.h"

extern void main_P3();
extern void main_P4();
void main_test(){

  nice(get_pid(),10);
  char * message;
  itoa(message,get_pid());
  write(STDOUT_FILENO,message,1);
  for(int i = 0; i < 16; i++){
    pid_t pid = fork();

    if(pid == 0){
      i % 2 ? exec( &main_P3 ) : exec( &main_P4);
    }
  }

  exit(EXIT_SUCCESS);
}

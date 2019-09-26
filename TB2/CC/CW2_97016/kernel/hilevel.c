/* Copyright (C) 2017 Daniel Page <csdsp@bristol.ac.uk>
 *
 * Use of this source code is restricted per the CC BY-NC-ND license, a copy of
 * which can be found via http://creativecommons.org (and should be included as
 * LICENSE.txt within the associated archive or repository).
 */


// LO18144 - CANDIDATE NO. 97016

#include "hilevel.h"

pcb_t pcb[ MAX_PR ]; pcb_t* current = NULL;
pipe_t pipes[ MAX_PIPES ];

int pr_N, pipes_N; // Number of processes and number of pipes

void dispatch( ctx_t* ctx, pcb_t* prev, pcb_t* next ) {
  char prev_pid = '?', next_pid = '?';
  char prev_pid1 = '?', next_pid1 = '?';

  if( NULL != prev ) {
    memcpy( &prev->ctx, ctx, sizeof( ctx_t ) ); // preserve execution context of P_{prev}
    prev_pid = '0' + (prev->pid % 10);
    prev_pid1 = '0' + prev->pid / 10;
  }
  if( NULL != next ) {
    memcpy( ctx, &next->ctx, sizeof( ctx_t ) ); // restore  execution context of P_{next}
    next_pid = '0' + next->pid % 10;
    next_pid1 = '0' + next->pid/10;
  }
/*
    PL011_putc( UART0, '[',      true );
    PL011_putc( UART0, prev_pid1, true );
    PL011_putc( UART0, prev_pid, true );
    PL011_putc( UART0, '-',      true );
    PL011_putc( UART0, '>',      true );
    PL011_putc( UART0, next_pid1, true );
    PL011_putc( UART0, next_pid, true );
    PL011_putc( UART0, ']',      true );
*/
    current = next;                             // update   executing index   to P_{next}

  return;
}

// Search for non-terminated process with highest priority
int most_priority(){
  int next = 0; // This assumes the console can always go on, never terminated
  for(int i = 1; i < pr_N; i++){
    if (pcb[i].priority + pcb[i].wt > pcb[next].priority + pcb[next].wt
          &&  pcb[i].status != STATUS_TERMINATED){
        // Look for the (non-terminated) process with highest sum of priority + waiting time
        next = i;
    }
  }
  return next;
}

// Increase waiting time of each process
void increase_wt(){
  for(int i = 0; i < pr_N; i++)
    pcb[i].wt++;
}

// Priority scheduler
void schedule( ctx_t* ctx ) {
  int next = most_priority();    // Find the process with most priority
  increase_wt();                // Increase waiting time of all processes
  pcb[next].wt = 0;             // Set waiting time or age to zero as it is just about to be executed
  if(current->status == STATUS_EXECUTING) current->status = STATUS_READY; // Prevent terminated processes from changing status
  dispatch(ctx,current,&pcb[next]);
  current->status = STATUS_EXECUTING;
  return;
}


// Assign values to initialise
void initialise_pcb(pid_t pid, status_t status, int priority){
      int pos = pid - 1;
      pcb[ pos ].pid      = pid;
      pcb[ pos ].status   = status;
      pcb[ pos ].priority = priority;
      pcb[ pos ].wt = 0;
}

// Terminate pipes with process pid
void shut_down_pipes(pid_t pid){
    for(int i = 0; i < pipes_N; i++)
      if(pipes[i].pid_A == pid || pipes[i].pid_B == pid) pipes[i].status = STATUS_TERMINATED;
}


extern void     main_console();
extern uint32_t tos_start;

void hilevel_handler_rst( ctx_t* ctx) {
  /*
   * - the CPSR value of 0x50 means the processor is switched into USR mode,
   *   with IRQ interrupts enabled, and
   * - the PC and SP values match the entry point and top of stack.
   */

//   TIMER0->Timer1Load  = 0x00100000; // select period = 2^20 ticks ~= 1 sec
   TIMER0->Timer1Load  = 0x00020000; // shorter period 2^17
   TIMER0->Timer1Ctrl  = 0x00000002; // select 32-bit   timer
   TIMER0->Timer1Ctrl |= 0x00000040; // select periodic timer
   TIMER0->Timer1Ctrl |= 0x00000080; // enable          timer
   TIMER0->Timer1Ctrl |= 0x00000020; // enable          timer interrupt

   GICC0->PMR          = 0x000000F0; // unmask all            interrupts
   GICD0->ISENABLER1  |= 0x00000010; // enable timer          interrupt
   GICC0->CTLR         = 0x00000001; // enable GIC interface
   GICD0->CTLR         = 0x00000001; // enable GIC distributor

   int_enable_irq();


   pr_N = 1;  // Set counter of processes to one
   pipes_N = 0; // Set counter of pipes to zero
   memset( &pcb[0], 0, sizeof( pcb_t ) );     // Clear the content of pcb[0]
   initialise_pcb(1,STATUS_CREATED,3);         // Initialise the PCB of the console, giving it priority 3
   pcb[ 0 ].ctx.cpsr = 0x50;
   pcb[ 0 ].ctx.pc   = (uint32_t) &main_console;
   pcb[ 0 ].ctx.sp   = (uint32_t) &tos_start;
  /* Once the PCBs are initialised, select the console to be executed
   * There is no need to preserve the execution context,
   * since it is is invalid on reset (i.e., no process will previously have
   * been executing).
   */
  dispatch( ctx, NULL, &pcb[ 0 ] );
  return;
}

void hilevel_handler_irq(ctx_t* ctx) {
  // Step 2: read  the interrupt identifier so we know the source.

  uint32_t id = GICC0->IAR;

  // Step 4: handle the interrupt, then clear (or reset) the source.

  if( id == GIC_SOURCE_TIMER0 ) {
//    PL011_putc( UART0, 'T', true );
    schedule( ctx );
    TIMER0->Timer1IntClr = 0x01;
  }

  // Step 5: write the interrupt identifier to signal we're done.

  GICC0->EOIR = id;

  return;
}

void hilevel_handler_svc( ctx_t* ctx, uint32_t id ) {
  /* Based on the identifier (i.e., the immediate operand) extracted from the
   * svc instruction,
   *
   * - read  the arguments from preserved usr mode registers,
   * - perform whatever is appropriate for this system call, then
   * - write any return value back to preserved usr mode registers.
   */

  switch( id ) {
    case 0x00 : { // 0x00 => yield()
      schedule( ctx );

      break;
    }

    case 0x01 : { // 0x01 => write( fd, x, n )
      int   fd = ( int   )( ctx->gpr[ 0 ] );
      char*  x = ( char* )( ctx->gpr[ 1 ] );
      int    n = ( int   )( ctx->gpr[ 2 ] );

      for( int i = 0; i < n; i++ ) {
        PL011_putc( UART0, *x++, true );
      }

      ctx->gpr[ 0 ] = n;

      break;
    }

    case 0x02: { // 0x02 => read( fd, x, n )
      int   fd = ( int   )( ctx->gpr[ 0 ] );
      char*  x = ( char* )( ctx->gpr[ 1 ] );
      int    n = ( int   )( ctx->gpr[ 2 ] );

      for(int i = 0; i < n; i++){
        *x++ = PL011_getc(UART0,true);
      }

      ctx->gpr[0] = n;

      break;
    }

    case 0x03: { // 0x03 => fork()
      // Find a spot in pcb table for the process. If a process is terminated, assign its position, otherwise append to the end
      int position = 0;
      while(position < pr_N && pcb[position].status != STATUS_TERMINATED) position++;   // Look for a terminated process
      if (position == pr_N) pr_N++;             // If there was no terminated process, there is one more process in the table

      initialise_pcb(position+1,STATUS_CREATED,2);
      memcpy( &pcb[position].ctx, ctx, sizeof( ctx_t ) ); // Copy execution context of parent
      pcb[ position ].ctx.gpr[0] = 0;   // Return 0 to child
      pcb[ position ].ctx.sp = (uint32_t) &tos_start + position*0x00001000;// Assign corresponding stack pointer
      ctx->gpr[0] = position + 1; // Return the child's pid to the parent
      current->status = STATUS_WAITING; // Set parent process as waiting
      dispatch(ctx,current,&pcb[ position ]); // SET CHILD PROCESS AS RUNNING
      current->status = STATUS_EXECUTING;
      break;
    }

    case 0x04: { // 0x04 => exit( x )
      int x = ctx->gpr[0];
      if(x == 0){ // If exit called with EXIT_SUCCESS terminate process
        shut_down_pipes(current->pid);
        current->status = STATUS_TERMINATED;
        schedule(ctx);
      }
      break;
    }

    case 0x05: { // 0x05 => exec()
      ctx->pc = (uint32_t) ctx->gpr[0];
      break;
    }

    case 0x06: { // 0x06 => kill()
      pid_t pid = ( pid_t ) ( ctx->gpr[0] );
      if(pid != 1 && pid > 0 && pid <= pr_N){ // Keeps console from being terminated
        shut_down_pipes(current->pid);
        pcb[ pid - 1 ].status = STATUS_TERMINATED;
        if (pid == current->pid) schedule(ctx); // If running process is killed, schedule
      }
      break;
    }

    case 0x07: { // 0x07 => nice()
      pid_t pid = ( pid_t ) ( ctx->gpr[0] );
      int x = ( int ) ( ctx->gpr[1] );
      pcb[pid-1].priority = x; // Update priority of process with that pid
      break;
    }

    case 0x08: { // 0x08 => create_pipe(idA,idB)
        int j = 0;
        // Find a spot for new pipe
        while( j < pipes_N && pipes[j].status != STATUS_TERMINATED ) j++;
        if(j == pipes_N) pipes_N++;

        // Initialise data of pipe
        pipes[j].pid_A = ctx->gpr[0];
        pipes[j].pid_B = ctx->gpr[1];
        pipes[j].status = STATUS_EXECUTING;
        pipes[j].message = EMPTY_PIPE;

        // Return the position of pipe
        ctx->gpr[0] = j;
        break;
    }

    case 0x09: { // 0x09 => write_pipe(id,message)
        int pos = ctx->gpr[0];
        int message = ctx->gpr[1];

        // Write message to pipe
        pipes[pos].message = message;
        break;
    }

    case 0x0A: { // 0x0A => read_pipe(id)
        // Return message of pipe[id]
        ctx->gpr[0] = pipes[ctx->gpr[0]].message;
        break;
    }

    case 0x0B: { // 0x0B => get_pid()
        // Return pid of running process
        ctx->gpr[0] = current->pid;
        break;
    }

    case 0x0C: {  // 0x0C => find_pipe(pid)

        // Find first pipe with pid. Note that this will only be
        // satisfactory in case there is only one such pipe exists and
        // that is the one we are looking for. This can be easily
        // improved by adding a parent pid for each process and sending both
        // arguments here
        pid_t pid = ctx->gpr[0];
        int pos = 0;
        while(pos < pipes_N && pipes[pos].pid_A != pid && pipes[pos].pid_B != pid) ++pos;
        ctx->gpr[0] = pos < pipes_N ? pos : -1; // If none was found return -1
        break;
    }

    default   : { // 0x?? => unknown/unsupported
      break;
    }
  }

  return;
}

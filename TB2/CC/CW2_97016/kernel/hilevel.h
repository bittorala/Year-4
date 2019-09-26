/* Copyright (C) 2017 Daniel Page <csdsp@bristol.ac.uk>
 *
 * Use of this source code is restricted per the CC BY-NC-ND license, a copy of
 * which can be found via http://creativecommons.org (and should be included as
 * LICENSE.txt within the associated archive or repository).
 */

 // LO18144 - CANDIDATE NO. 97016


#ifndef __HILEVEL_H
#define __HILEVEL_H

// Include functionality relating to newlib (the standard C library).

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include <string.h>

// Include functionality relating to the platform.

#include   "GIC.h"
#include "PL011.h"
#include "SP804.h"

// Include functionality relating to the   kernel.

#include "lolevel.h"
#include     "int.h"

#define MAX_PR 32
#define MAX_PIPES 32 // 32*31 would be the real one but that is too much memory

#define EMPTY_PIPE -4096

/* The kernel source code is made simpler and more consistent by using
 * some human-readable type definitions:
 *
 * - a type that captures a Process IDentifier (PID), which is really
 *   just an integer,
 * - an enumerated type that captures the status of a process, e.g.,
 *   whether it is currently executing,
 * - a type that captures each component of an execution context (i.e.,
 *   processor state) in a compatible order wrt. the low-level handler
 *   preservation and restoration prologue and epilogue, and
 * - a type that captures a process PCB.
 */

typedef int pid_t;

typedef enum {
  STATUS_CREATED,
  STATUS_READY,
  STATUS_EXECUTING,
  STATUS_WAITING,
  STATUS_TERMINATED
} status_t;

typedef struct {
  uint32_t cpsr, pc, gpr[ 13 ], sp, lr;   // current program status register, program counter, general
                                          // purpose registers, stack pointer, link register
} ctx_t;

typedef struct {
     pid_t    pid;
  status_t status;
     ctx_t    ctx;
     int priority;  // Original priority of process
     int wt;    // Time a process has been waiting (to avoid starvation)
} pcb_t;        // process control block with identifier, status and context

typedef struct{
    int pid_A,pid_B;
    int message;
    status_t status;
} pipe_t;


#endif

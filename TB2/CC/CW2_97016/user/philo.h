

#ifndef __PHILO_H
#define __PHILO_H

#define REQ_FORK    64    // A fork request will be in {64, 64+1, ..., 64+FORK_N-1}
#define RF_DOWN     512   // Equivalent to request that a fork be put down
#define F_YOURS     -1    // Fork is granted
#define F_DOWN      -2    // Fork is put down
#define I_ATE       -3    // Philosopher says it ate
#define YOU_ATE     -4    // I_ATE message was received
#define EMPTY_PIPE  -4096 // Empty pipe mark

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "PL011.h"

#include "libc.h"

#endif

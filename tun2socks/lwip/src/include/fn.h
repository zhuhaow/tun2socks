#include "lwip/tcp.h"

#ifndef fn_h
#define fn_h

void tcp_accepted_c(struct tcp_pcb *pcb);

void tcp_accepted_c(struct tcp_pcb *pcb) {
    tcp_accepted(pcb);
}

#endif /* fn_h */

/* $Id: utils.h,v 1.15 2002/02/14 21:21:20 bwess Exp $ */

#ifndef _UTILS_H
#define _UTILS_H

void *xmalloc(int size);
void log_exit();
void run_command(char *buf);
void free_conn_data();
void free_dns_cache();
void free_hosts();
void free_exclude_data();
void init_line();
void mode_error();
void build_time(char *smonth, int day, int hour, int minute, int second);
unsigned char convert_ip(char *ip, struct in_addr *addr);
void add_known_host(char *ip);
void add_exclude_hp(char *input, unsigned char mode);

#endif

/* $Id: output.h,v 1.20 2002/02/14 21:55:19 bwess Exp $ */

#ifndef _OUTPUT_H
#define _OUTPUT_H

#include "main.h"

void output_timediff(time_t start, time_t end, char *td);
void output_html(struct conn_data *input);
void output_plain(struct conn_data *input);
void output_html_header();
void output_html_table();
void output_html_footer();
void output_raw_data(struct conn_data *input);

#endif

/* $Id: netfilter.l,v 1.1 2002/02/14 21:15:36 bwess Exp $ */

%option prefix="nf"
%option outfile="netfilter.c"
%option noyywrap

%{
#define YY_NO_UNPUT

#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include "main.h"
#include "utils.h"

extern struct options opt;

void nf_parse_start(char *input);
void nf_parse_ip(char *input, unsigned char mode);
void nf_parse_proto(char *input);
%}

MONTH	"Jan"|"Feb"|"Mar"|"Apr"|"May"|"Jun"|"Jul"|"Aug"|"Sep"|"Oct"|"Nov"|"Dec"
STRING	[a-zA-Z][a-zA-Z0-9.-]*
ISTRING	[a-zA-HJ-Z0-9.-]*
LOGHOST	[0-9.a-zA-Z_-]*
DIGIT	[0-9]
NUMBER	{DIGIT}+
OCTET	{DIGIT}{1,3}
PORT	{DIGIT}{1,5}
HEXDIGIT	[0-9a-fA-F]
HEXNUM	"0x"{HEXDIGIT}+
PROTO	"TCP"|"UDP"|"ICMP"|"ESP"|"AH"|{NUMBER}

%%

{MONTH}[ ]{1,2}{DIGIT}{1,2}[ ]{DIGIT}{2}:{DIGIT}{2}:{DIGIT}{2}[ ]{LOGHOST}" kernel: "{ISTRING}	nf_parse_start(nftext);
"IN="{STRING}?		{ strncpy(opt.line->interface, nftext+3, SHORTLEN); opt.parser=opt.parser|NF_IN; }
"OUT="{STRING}?		/* ignore */
"MAC="(({HEXDIGIT}{HEXDIGIT}:){13}{HEXDIGIT}{HEXDIGIT})?	/* ignore */
"SRC="{OCTET}"."{OCTET}"."{OCTET}"."{OCTET}	nf_parse_ip(nftext+4, NF_SRC);
"DST="{OCTET}"."{OCTET}"."{OCTET}"."{OCTET}	nf_parse_ip(nftext+4, NF_DST);
"LEN="{NUMBER}		opt.line->datalen = atoi(nftext+4);
"TOS="{HEXNUM}		/* ignore */
"PREC="{HEXNUM}		/* ignore */
"TTL="{NUMBER}		/* ignore */
"ID="{NUMBER}		/* ignore */
"CE"			/* ignore */
"DF"			/* ignore */
"MF"			/* ignore */
"FRAG:"{NUMBER}		/* ignore */
"PROTO="{PROTO}		nf_parse_proto(nftext+6);
"INCOMPLETE ["{NUMBER}" bytes]"	/* ignore */
"TYPE="{NUMBER}		{ opt.line->sport = atoi(nftext+5); opt.parser=opt.parser|NF_TYPE; }
"CODE="{NUMBER}		/* ignore */
"SEQ="{NUMBER}		/* ignore */
"ACK="{NUMBER}		/* ignore */
"SPT="{PORT}		{ opt.line->sport = atoi(nftext+4); opt.parser=opt.parser|NF_SPT; }
"DPT="{PORT}		{ opt.line->dport = atoi(nftext+4); opt.parser=opt.parser|NF_DPT; }
"WINDOW="{NUMBER}	/* ignore */
"RES="{HEXNUM}		/* ignore */
"URG"			opt.line->flags = opt.line->flags | TCP_URG;
"ACK"			opt.line->flags = opt.line->flags | TCP_ACK;
"PSH"			opt.line->flags = opt.line->flags | TCP_PSH;
"RST"			opt.line->flags = opt.line->flags | TCP_RST;
"SYN"			opt.line->flags = opt.line->flags | TCP_SYN;
"FIN"			opt.line->flags = opt.line->flags | TCP_FIN;
"URGP="{NUMBER}		/* ignore */
"OPT ("[0-9A-F]*")"	/* ignore */
"SPI="{HEXNUM}		/* ignore */
[ ]+			/* ignore whitespace */
[\n]			return 0;
{STRING}		fprintf(stderr, "Unrecognized token: %s\n", nftext);
.			fprintf(stderr, "Unrecognized character: %s\n", nftext);

%%

void nf_parse_start(char *input)
{
  int retval, day, hour, minute, second;
  char smonth[3];

  retval = sscanf(input,
#ifdef LONG_NAMES
		  "%3s %2d %2d:%2d:%2d %32s kernel: %30s",
#else
		  "%3s %2d %2d:%2d:%2d %32s kernel: %10s",
#endif
		  smonth, &day, &hour, &minute, &second,
		  opt.line->hostname,
		  opt.line->chainlabel);
  if (retval != 7) {
    if (retval == 6) {
      strncpy(opt.line->chainlabel, "-", SHORTLEN);
    } else {
      return;
    }
  }

  build_time(smonth, day, hour, minute, second);

  opt.parser=opt.parser|NF_DATE;
}

void nf_parse_ip(char *input, unsigned char mode)
{
  if (mode == NF_SRC) {
    if(convert_ip(input, &opt.line->shost) == IN_ADDR_ERROR) return;
    opt.parser=opt.parser|NF_SRC;
  } else {
    if(convert_ip(input, &opt.line->dhost) == IN_ADDR_ERROR) return;
    opt.parser=opt.parser|NF_DST;
  }
}

void nf_parse_proto(char *input)
{
  if(isdigit((int)input[0])) {
    opt.line->protocol = atoi(input);
  } else {
    if(strncmp(input, "TCP", 3) == 0) opt.line->protocol = 6;
    else if(strncmp(input, "UDP", 3) == 0) opt.line->protocol = 17;
    else if(strncmp(input, "ICMP", 4) == 0) opt.line->protocol = 1;
    else if(strncmp(input, "ESP", 3) == 0) opt.line->protocol = 50;
    else if(strncmp(input, "AH", 2) == 0) opt.line->protocol = 51;
  }

  if (opt.line->protocol != 0)
    opt.parser=opt.parser|NF_PROTO;
}

unsigned char flex_netfilter(char *input, int linenum)
{
  opt.parser = 0;
  init_line();
  nf_scan_string(input);
  nflex();

  strncpy(opt.line->branchname, "-", SHORTLEN);
  opt.line->count = 1;

  if (((opt.line->protocol == 6) || (opt.line->protocol == 17)) && (opt.parser == (NF_DATE|NF_PROTO|NF_IN|NF_SRC|NF_DST|NF_SPT|NF_DPT))) {
    return PARSE_OK;
  }
  if ((opt.line->protocol == 1) && (opt.parser == (NF_DATE|NF_PROTO|NF_IN|NF_SRC|NF_DST|NF_TYPE))) {
    return PARSE_OK;
  }
  if(opt.verbose)
    fprintf(stderr, "netfilter parse error in line %d, ignoring.\n", linenum);
  return PARSE_WRONG_FORMAT;
}
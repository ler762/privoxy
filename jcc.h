#ifndef JCC_H_INCLUDED
#define JCC_H_INCLUDED
/*********************************************************************
 *
 * File        :  $Source: /cvsroot/ijbswa/current/jcc.h,v $
 *
 * Purpose     :  Main file.  Contains main() method, main loop, and
 *                the main connection-handling function.
 *
 * Copyright   :  Written by and Copyright (C) 2001-2014 the
 *                Privoxy team. http://www.privoxy.org/
 *
 *                Based on the Internet Junkbuster originally written
 *                by and Copyright (C) 1997 Anonymous Coders and
 *                Junkbusters Corporation.  http://www.junkbusters.com
 *
 *                This program is free software; you can redistribute it
 *                and/or modify it under the terms of the GNU General
 *                Public License as published by the Free Software
 *                Foundation; either version 2 of the License, or (at
 *                your option) any later version.
 *
 *                This program is distributed in the hope that it will
 *                be useful, but WITHOUT ANY WARRANTY; without even the
 *                implied warranty of MERCHANTABILITY or FITNESS FOR A
 *                PARTICULAR PURPOSE.  See the GNU General Public
 *                License for more details.
 *
 *                The GNU General Public License should be included with
 *                this file.  If not, you can view it at
 *                http://www.gnu.org/copyleft/gpl.html
 *                or write to the Free Software Foundation, Inc., 59
 *                Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 *********************************************************************/


struct client_state;
struct file_list;

/* Global variables */

#ifdef FEATURE_STATISTICS
extern int urls_read;
extern int urls_rejected;

#define numIosizeCounters 29
  /* ref: May 24, 2017 "TODO 157" ijbswa-developers msg from Fabian Keil
   *  ... a buffer that is too large can actually reduce the throughput.
   * showing a buffer size of 524288 had better thruput than a buffer
   * size of 1048576.  So don't worry about having to deal with buffer
   * sizes >= 1M.
   */
extern unsigned int iosizeRunLen[numIosizeCounters];
extern unsigned int iosizeCounter[numIosizeCounters];
  /* XXX: is it reasonable to use 32 bit counters???
   * max 32bit unsigned int = 4294967295
   * 100Mb ethernet can do 8127 [full size] packets per second
   * 4294967295 / 8127 = 528481 seconds or a bit over 6 days
   * averaging 10% busy on a 100Mb link would take about 2 months to overflow a 32 bit counter
   * Who's going to _average_ 10% busy each and every day for 2 months?
   */
extern char iosizeCounterDesc[numIosizeCounters][16];
extern size_t max_buffer_size;
extern size_t prevReadSize;
#endif /*def FEATURE_STATISTICS*/

extern struct client_states clients[1];
extern struct file_list    files[1];

#ifdef unix
extern const char *pidfile;
#endif
extern int daemon_mode;

#ifdef FEATURE_GRACEFUL_TERMINATION
extern int g_terminate;
#endif

#if defined(FEATURE_PTHREAD) || defined(_WIN32)
#define MUTEX_LOCKS_AVAILABLE

#ifdef FEATURE_PTHREAD
#include <pthread.h>

typedef pthread_mutex_t privoxy_mutex_t;

#else

typedef CRITICAL_SECTION privoxy_mutex_t;

#endif

extern void privoxy_mutex_lock(privoxy_mutex_t *mutex);
extern void privoxy_mutex_unlock(privoxy_mutex_t *mutex);

extern privoxy_mutex_t log_mutex;
extern privoxy_mutex_t log_init_mutex;
extern privoxy_mutex_t connection_reuse_mutex;

#ifdef FEATURE_EXTERNAL_FILTERS
extern privoxy_mutex_t external_filter_mutex;
#endif

#ifdef FEATURE_CLIENT_TAGS
extern privoxy_mutex_t client_tags_mutex;
#endif

#ifndef HAVE_GMTIME_R
extern privoxy_mutex_t gmtime_mutex;
#endif /* ndef HAVE_GMTIME_R */

#ifndef HAVE_LOCALTIME_R
extern privoxy_mutex_t localtime_mutex;
#endif /* ndef HAVE_GMTIME_R */

#if !defined(HAVE_GETHOSTBYADDR_R) || !defined(HAVE_GETHOSTBYNAME_R)
extern privoxy_mutex_t resolver_mutex;
#endif /* !defined(HAVE_GETHOSTBYADDR_R) || !defined(HAVE_GETHOSTBYNAME_R) */

#ifndef HAVE_RANDOM
extern privoxy_mutex_t rand_mutex;
#endif /* ndef HAVE_RANDOM */

#ifdef LIMIT_MUTEX_NUMBER
   extern privoxy_mutex_t certificates_mutexes[32];
#else
   extern privoxy_mutex_t certificates_mutexes[65536];
#endif /* LIMIT_MUTEX_NUMBER */
extern privoxy_mutex_t rng_mutex;

#endif /* FEATURE_PTHREAD */

/* Functions */

#ifdef __MINGW32__
int real_main(int argc, char **argv);
#else
int main(int argc, char **argv);
#endif

#ifdef FUZZ
extern int fuzz_client_request(struct client_state *csp, char *fuzz_input_file);
extern int fuzz_server_response(struct client_state *csp, char *fuzz_input_file);
extern int fuzz_chunked_transfer_encoding(struct client_state *csp, char *fuzz_input_file);
#endif

#endif /* ndef JCC_H_INCLUDED */

/*
  Local Variables:
  tab-width: 3
  end:
*/

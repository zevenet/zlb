/* config.h.  Generated from config.h.in by configure.  */
/* config.h.in.  Generated from configure.ac by autoheader.  */

/* Define if building universal (internal helper macro) */
/* #undef AC_APPLE_UNIVERSAL_BUILD */

/* Backtracing facility */
/* #undef BACKTRACES_ENABLED */

/* configure arguments */
#define CHEROKEE_CONFIG_ARGS " '--prefix=/usr/local/zenloadbalancer/app/cherokee/' '--disable-ipv6' '--with-wwwroot=/usr/local/zenloadbalancer/www' '--with-cgiroot=/usr/local/zenloadbalancer/www' '--with-wwwuser=root'"

/* Define to 1 if the `closedir' function returns void instead of `int'. */
/* #undef CLOSEDIR_VOID */

/* L2 cache line size */
#define CPU_CACHE_LINE 64

/* Define if crypt_r has uses CRYPTD */
/* #undef CRYPT_R_CRYPTD */

/* Define if crypt_r uses struct crypt_data */
#define CRYPT_R_STRUCT_CRYPT_DATA 1

/* Whether the Darwin sendfile() API is available */
/* #undef DARWIN_SENDFILE_API */

/* Whether the FreeBSD sendfile() API is available */
/* #undef FREEBSD_SENDFILE_API */

/* Define to 1 if you have the <arpa/inet.h> header file. */
#define HAVE_ARPA_INET_H 1

/* Define to 1 if you have the `backtrace' function. */
#define HAVE_BACKTRACE 1

/* Define to 1 if you have the `bcopy' function. */
#define HAVE_BCOPY 1

/* Define if setsockopt(SO_RCVTIMEO) is broken */
/* #undef HAVE_BROKEN_SO_RCVTIMEO */

/* Have crypt function */
#define HAVE_CRYPT 1

/* Define to 1 if you have the <crypt.h> header file. */
#define HAVE_CRYPT_H 1

/* Have crypt_r function */
#define HAVE_CRYPT_R 1

/* Define to 1 if you have the declaration of `tzname', and to 0 if you don't.
   */
/* #undef HAVE_DECL_TZNAME */

/* Define to 1 if you have the <dirent.h> header file, and it defines `DIR'.
   */
#define HAVE_DIRENT_H 1

/* Define to 1 if you have the <dlfcn.h> header file. */
#define HAVE_DLFCN_H 1

/* Define to 1 if you don't have `vprintf' but do have `_doprnt.' */
/* #undef HAVE_DOPRNT */

/* Define to 1 if you have the <endian.h> header file. */
#define HAVE_ENDIAN_H 1

/* Have epoll */
#define HAVE_EPOLL 1

/* Define to 1 if you have the <error.h> header file. */
#define HAVE_ERROR_H 1

/* Define to 1 if you have the <execinfo.h> header file. */
#define HAVE_EXECINFO_H 1

/* Define to 1 if you have the <fcntl.h> header file. */
#define HAVE_FCNTL_H 1

/* Define to 1 if you have the `flockfile' function. */
#define HAVE_FLOCKFILE 1

/* Define to 1 if you have the `fork' function. */
#define HAVE_FORK 1

/* Define to 1 if you have the `funlockfile' function. */
#define HAVE_FUNLOCKFILE 1

/* Define to 1 if you have the <GeoIP.h> header file. */
/* #undef HAVE_GEOIP_H */

/* Define if getaddrinfo exists and works well enough for APR */
#define HAVE_GETADDRINFO 1

/* Define to 1 if you have the `getdtablesize' function. */
#define HAVE_GETDTABLESIZE 1

/* Some sys tems have getgrgid_r */
#define HAVE_GETGRGID_R 1

/* Some systems have getgrgid_r */
/* #undef HAVE_GETGRGID_R_4 */

/* Some systems have getgrgid_r */
#define HAVE_GETGRGID_R_5 1

/* Some systems have getgrnam_r */
#define HAVE_GETGRNAM_R 1

/* Some systems have getgrnam_r */
/* #undef HAVE_GETGRNAM_R_4 */

/* Some systems have getgrnam_r */
#define HAVE_GETGRNAM_R_5 1

/* Define to 1 if you have the `gethostbyname' function. */
#define HAVE_GETHOSTBYNAME 1

/* Define to 1 if you have the `gethostbyname_r' function. */
#define HAVE_GETHOSTBYNAME_R 1

/* Define to 1 if you have the `gethostname' function. */
#define HAVE_GETHOSTNAME 1

/* Define if getnameinfo exists */
#define HAVE_GETNAMEINFO 1

/* Define to 1 if you have the <getopt.h> header file. */
#define HAVE_GETOPT_H 1

/* Define to 1 if you have the `getpagesize' function. */
#define HAVE_GETPAGESIZE 1

/* Some systems have getpwnam_r */
#define HAVE_GETPWNAM_R 1

/* Some systems have getpwnam_r */
/* #undef HAVE_GETPWNAM_R_4 */

/* Some systems have getpwnam_r */
#define HAVE_GETPWNAM_R_5 1

/* Some sys tems have getpwuid_r */
#define HAVE_GETPWUID_R 1

/* Some systems have getpwuid_r */
/* #undef HAVE_GETPWUID_R_4 */

/* Some systems have getpwuid_r */
#define HAVE_GETPWUID_R_5 1

/* Define to 1 if you have the `getrlimit' function. */
#define HAVE_GETRLIMIT 1

/* Define to 1 if you have glibc. */
#define HAVE_GLIBC 1

/* Define to 1 if you have the `gmtime' function. */
#define HAVE_GMTIME 1

/* Define to 1 if you have the `gmtime_r' function. */
#define HAVE_GMTIME_R 1

/* Define to 1 if you have the <grp.h> header file. */
#define HAVE_GRP_H 1

/* Define to 1 if you have the `inet_addr' function. */
#define HAVE_INET_ADDR 1

/* Define to 1 if you have the `inet_ntop' function. */
#define HAVE_INET_NTOP 1

/* Define to 1 if you have the `inet_pton' function. */
#define HAVE_INET_PTON 1

/* Compile supports inline */
#define HAVE_INLINE 1

/* Define to 1 if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H 1

/* Set to 1 if you have the global variable timezone */
#define HAVE_INT_TIMEZONE /**/

/* Define if you have IPv6 support. */
/* #undef HAVE_IPV6 */

/* Have kqueue */
/* #undef HAVE_KQUEUE */

/* Define to 1 if you have the `advapi32' library (-ladvapi32). */
/* #undef HAVE_LIBADVAPI32 */

/* Define to 1 if you have the <libavformat/avformat.h> header file. */
/* #undef HAVE_LIBAVFORMAT_AVFORMAT_H */

/* Define to 1 if you have the `crypto' library (-lcrypto). */
#define HAVE_LIBCRYPTO 1

/* Define to 1 if you have the `gen' library (-lgen). */
/* #undef HAVE_LIBGEN */

/* Define to 1 if you have the `inet' library (-linet). */
/* #undef HAVE_LIBINET */

/* Define to 1 if you have the `net' library (-lnet). */
/* #undef HAVE_LIBNET */

/* Define to 1 if you have the `nsl' library (-lnsl). */
/* #undef HAVE_LIBNSL */

/* Define to 1 if you have the `nsl_s' library (-lnsl_s). */
/* #undef HAVE_LIBNSL_S */

/* Define to 1 if you have the `sendfile' library (-lsendfile). */
/* #undef HAVE_LIBSENDFILE */

/* Define to 1 if you have the `socket' library (-lsocket). */
/* #undef HAVE_LIBSOCKET */

/* Define to 1 if you have the `ws2_32' library (-lws2_32). */
/* #undef HAVE_LIBWS2_32 */

/* Define to 1 if you have the `localtime' function. */
#define HAVE_LOCALTIME 1

/* Define to 1 if you have the `localtime_r' function. */
#define HAVE_LOCALTIME_R 1

/* Whether the host supports long long' */
#define HAVE_LONGLONG 1

/* Define to 1 if you have the <machine/endian.h> header file. */
/* #undef HAVE_MACHINE_ENDIAN_H */

/* Define to 1 if your system has a GNU libc compatible `malloc' function, and
   to 0 otherwise. */
#define HAVE_MALLOC 1

/* Define to 1 if you have the `memmove' function. */
#define HAVE_MEMMOVE 1

/* Define to 1 if you have the <memory.h> header file. */
#define HAVE_MEMORY_H 1

/* Define to 1 if you have a working `mmap' system call. */
#define HAVE_MMAP 1

/* Define to 1 if you have the <ndir.h> header file, and it defines `DIR'. */
/* #undef HAVE_NDIR_H */

/* Define to 1 if you have the <netdb.h> header file. */
#define HAVE_NETDB_H 1

/* Define to 1 if you have the <netinet/in.h> header file. */
#define HAVE_NETINET_IN_H 1

/* Define to 1 if you have the <netinet/tcp.h> header file. */
#define HAVE_NETINET_TCP_H 1

/* Whether off64_t is available */
/* #undef HAVE_OFF64_T */

/* Have OpenSSL library */
#define HAVE_OPENSSL 1

/* Define to 1 if you have the <openssl/engine.h> header file. */
#define HAVE_OPENSSL_ENGINE_H 1

/* Have _pam_dispatch function */
/* #undef HAVE_PAM_DISPATCH */

/* Have poll */
#define HAVE_POLL 1

/* Define to 1 if you have the <poll.h> header file. */
#define HAVE_POLL_H 1

/* Have event ports */
/* #undef HAVE_PORT */

/* Have pthread support */
#define HAVE_PTHREAD 1

/* Define to 1 if you have the <pthread.h> header file. */
#define HAVE_PTHREAD_H 1

/* Define to 1 if you have the `pthread_mutexattr_setkind_np' function. */
#define HAVE_PTHREAD_MUTEXATTR_SETKIND_NP 1

/* Define to 1 if you have the `pthread_mutexattr_settype' function. */
#define HAVE_PTHREAD_MUTEXATTR_SETTYPE 1

/* Define if your pthread library includes pthread_rwlock_t */
#define HAVE_PTHREAD_RWLOCK_T 1

/* Pthread support pthread_attr_setschedpolicy */
#define HAVE_PTHREAD_SETSCHEDPOLICY 1

/* Define to 1 if you have the <pwd.h> header file. */
#define HAVE_PWD_H 1

/* Define to 1 if you have the `random' function. */
#define HAVE_RANDOM 1

/* Define to 1 if you have the `readdir' function. */
#define HAVE_READDIR 1

/* Define to 1 if you have the `readdir_r' function. */
#define HAVE_READDIR_R 1

/* readdir_r takes 2 arguments */
/* #undef HAVE_READDIR_R_2 */

/* readdir_r takes 3 arguments */
#define HAVE_READDIR_R_3 1

/* Define to 1 if your system has a GNU libc compatible `realloc' function,
   and to 0 otherwise. */
#define HAVE_REALLOC 1

/* Define to 1 if you have the <resource.h> header file. */
/* #undef HAVE_RESOURCE_H */

/* Have RTDL_GLOBAL */
#define HAVE_RTLDGLOBAL /**/

/* Have RTDL_LOCAL */
#define HAVE_RTLDLOCAL /**/

/* Have RTDL_NEXT */
#define HAVE_RTLDNEXT /**/

/* Have RTDL_NOW */
#define HAVE_RTLDNOW /**/

/* Define to 1 if you have the <sched.h> header file. */
#define HAVE_SCHED_H 1

/* Define to 1 if you have the `sched_yield' function. */
#define HAVE_SCHED_YIELD 1

/* Define to 1 if you have the <security/pam_appl.h> header file. */
/* #undef HAVE_SECURITY_PAM_APPL_H */

/* Define to 1 if you have the <security/_pam_macros.h> header file. */
/* #undef HAVE_SECURITY__PAM_MACROS_H */

/* Have select */
#define HAVE_SELECT 1

/* Define if sys/sem.h defines struct semun */
/* #undef HAVE_SEMUN */

/* Whether sendfile() is available */
/* #undef HAVE_SENDFILE */

/* Whether sendfile64() is available */
#define HAVE_SENDFILE64 1

/* Whether sendfilev() is available */
/* #undef HAVE_SENDFILEV */

/* Whether sendfilev64() is available */
/* #undef HAVE_SENDFILEV64 */

/* HAVE_SOCKADDR_IN6 */
#define HAVE_SOCKADDR_IN6 1

/* HAVE_SOCKADDR_UN */
#define HAVE_SOCKADDR_UN 1

/* Define to 1 if you have the `srandom' function. */
#define HAVE_SRANDOM 1

/* Define to 1 if you have the `srandomdev' function. */
/* #undef HAVE_SRANDOMDEV */

/* Define to 1 if you have the <stdarg.h> header file. */
#define HAVE_STDARG_H 1

/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1

/* Define to 1 if you have the <stdlib.h> header file. */
#define HAVE_STDLIB_H 1

/* Define to 1 if you have the `strcasestr' function. */
#define HAVE_STRCASESTR 1

/* Define to 1 if you have the `strerror' function. */
#define HAVE_STRERROR 1

/* Define to 1 if you have the <strings.h> header file. */
#define HAVE_STRINGS_H 1

/* Define to 1 if you have the <string.h> header file. */
#define HAVE_STRING_H 1

/* Define to 1 if you have the `strlcat' function. */
/* #undef HAVE_STRLCAT */

/* Define to 1 if you have the `strnstr' function. */
/* #undef HAVE_STRNSTR */

/* Define to 1 if you have the `strsep' function. */
#define HAVE_STRSEP 1

/* Define to 1 if `st_rdev' is a member of `struct stat'. */
#define HAVE_STRUCT_STAT_ST_RDEV 1

/* gmtoff in struct tm */
#define HAVE_STRUCT_TM_GMTOFF 1

/* Define to 1 if `tm_zone' is a member of `struct tm'. */
#define HAVE_STRUCT_TM_TM_ZONE 1

/* Define to 1 if your `struct stat' has `st_rdev'. Deprecated, use
   `HAVE_STRUCT_STAT_ST_RDEV' instead. */
#define HAVE_ST_RDEV 1

/* Define to 1 if you have the `syslog' function. */
#define HAVE_SYSLOG 1

/* Define to 1 if you have the <syslog.h> header file. */
#define HAVE_SYSLOG_H 1

/* Define to 1 to use SYSV semaphores */
#define HAVE_SYSV_SEMAPHORES 1

/* Define to 1 if you have the <sys/dir.h> header file, and it defines `DIR'.
   */
/* #undef HAVE_SYS_DIR_H */

/* Define to 1 if you have the <sys/endian.h> header file. */
/* #undef HAVE_SYS_ENDIAN_H */

/* Define to 1 if you have the <sys/filio.h> header file. */
/* #undef HAVE_SYS_FILIO_H */

/* Define to 1 if you have the <sys/ioctl.h> header file. */
#define HAVE_SYS_IOCTL_H 1

/* Define to 1 if you have the <sys/isa_defs.h> header file. */
/* #undef HAVE_SYS_ISA_DEFS_H */

/* Define to 1 if you have the <sys/machine.h> header file. */
/* #undef HAVE_SYS_MACHINE_H */

/* Define to 1 if you have the <sys/mman.h> header file. */
#define HAVE_SYS_MMAN_H 1

/* Define to 1 if you have the <sys/ndir.h> header file, and it defines `DIR'.
   */
/* #undef HAVE_SYS_NDIR_H */

/* Define to 1 if you have the <sys/ofcntl.h> header file. */
/* #undef HAVE_SYS_OFCNTL_H */

/* Define to 1 if you have the <sys/param.h> header file. */
#define HAVE_SYS_PARAM_H 1

/* Define to 1 if you have the <sys/poll.h> header file. */
#define HAVE_SYS_POLL_H 1

/* Define to 1 if you have the <sys/resource.h> header file. */
#define HAVE_SYS_RESOURCE_H 1

/* Define to 1 if you have the <sys/select.h> header file. */
#define HAVE_SYS_SELECT_H 1

/* Define to 1 if you have the <sys/socket.h> header file. */
#define HAVE_SYS_SOCKET_H 1

/* Define to 1 if you have the <sys/stat.h> header file. */
#define HAVE_SYS_STAT_H 1

/* Define to 1 if you have the <sys/time.h> header file. */
#define HAVE_SYS_TIME_H 1

/* Define to 1 if you have the <sys/types.h> header file. */
#define HAVE_SYS_TYPES_H 1

/* Define to 1 if you have the <sys/uio.h> header file. */
#define HAVE_SYS_UIO_H 1

/* Define to 1 if you have the <sys/un.h> header file. */
#define HAVE_SYS_UN_H 1

/* Define to 1 if you have the <sys/utsname.h> header file. */
#define HAVE_SYS_UTSNAME_H 1

/* Define to 1 if you have the <sys/varargs.h> header file. */
/* #undef HAVE_SYS_VARARGS_H */

/* Define to 1 if you have <sys/wait.h> that is POSIX.1 compatible. */
#define HAVE_SYS_WAIT_H 1

/* TCP_CORK was found and will be used */
#define HAVE_TCP_CORK 1

/* TCP_NOPUSH was found and will be used */
/* #undef HAVE_TCP_NOPUSH */

/* Define to 1 if your `struct tm' has `tm_zone'. Deprecated, use
   `HAVE_STRUCT_TM_TM_ZONE' instead. */
#define HAVE_TM_ZONE 1

/* Define to 1 if you don't have `tm_zone' but do have the external array
   `tzname'. */
/* #undef HAVE_TZNAME */

/* Define to 1 if you have the `uname' function. */
#define HAVE_UNAME 1

/* Define to 1 if you have the <unistd.h> header file. */
#define HAVE_UNISTD_H 1

/* va_list works copying an array */
#define HAVE_VA_LIST_AS_ARRAY /**/

/* Define to 1 if you have the `vfork' function. */
#define HAVE_VFORK 1

/* Define to 1 if you have the <vfork.h> header file. */
/* #undef HAVE_VFORK_H */

/* Define to 1 if you have the `vprintf' function. */
#define HAVE_VPRINTF 1

/* Define to 1 if you have the `vsyslog' function. */
#define HAVE_VSYSLOG 1

/* Define to 1 if `fork' works. */
#define HAVE_WORKING_FORK 1

/* Define to 1 if `vfork' works. */
#define HAVE_WORKING_VFORK 1

/* Whether the hpux sendfile() API is available */
/* #undef HPUX_SENDFILE_API */

/* It is SGI Irix */
/* #undef IRIX */

/* Define if you have ldap_start_tls_s */
/* #undef LDAP_HAVE_START_TLS_S */

/* Whether (linux) sendfile() is broken */
/* #undef LINUX_BROKEN_SENDFILE_API */

/* Whether linux sendfile() API is available */
#define LINUX_SENDFILE_API 1

/* Define to the sub-directory in which libtool stores uninstalled libraries.
   */
#define LT_OBJDIR ".libs/"

/* Dynamic modules extension */
#define MOD_SUFFIX "so"

/* OS type */
#define OS_TYPE "UNIX"

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT "http://bugs.cherokee-project.com/"

/* Version string */
#define PACKAGE_MAJOR_VERSION "1"

/* Version string */
#define PACKAGE_MICRO_VERSION "104"

/* Version string */
#define PACKAGE_MINOR_VERSION "2"

/* Define to the full name of this package. */
#define PACKAGE_NAME "cherokee"

/* Version string */
#define PACKAGE_PATCH_VERSION ""

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "cherokee 1.2.104"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "cherokee"

/* Define to the home page for this package. */
#define PACKAGE_URL ""

/* Package version */
#define PACKAGE_VERSION "1.2.104"

/* setenv function is thread safe */
/* #undef SETENV_IS_THREADSAFE */

/* The size of `int', as computed by sizeof. */
#define SIZEOF_INT 4

/* The size of `long', as computed by sizeof. */
#define SIZEOF_LONG 8

/* The size of `off_t', as computed by sizeof. */
#define SIZEOF_OFF_T 8

/* The size of `size_t', as computed by sizeof. */
#define SIZEOF_SIZE_T 8

/* The size of `time_t', as computed by sizeof. */
#define SIZEOF_TIME_T 8

/* The size of `unsigned int', as computed by sizeof. */
#define SIZEOF_UNSIGNED_INT 4

/* The size of `unsigned long', as computed by sizeof. */
#define SIZEOF_UNSIGNED_LONG 8

/* The size of `unsigned long long', as computed by sizeof. */
#define SIZEOF_UNSIGNED_LONG_LONG 8

/* It is Solaris */
/* #undef SOLARIS */

/* Whether the solaris sendfile() API is available */
/* #undef SOLARIS_SENDFILE_API */

/* Dynamic loading libraries extension */
#define SO_SUFFIX "so"

/* Define to 1 if you have the ANSI C header files. */
#define STDC_HEADERS 1

/* Define to 1 if you can safely include both <sys/time.h> and <time.h>. */
#define TIME_WITH_SYS_TIME 1

/* Temporal directory */
#define TMPDIR "/tmp"

/* Define to 1 if your <sys/time.h> declares `struct tm'. */
/* #undef TM_IN_SYS_TIME */

/* Trace facility */
/* #undef TRACE_ENABLED */

/* Whether to use FFMpeg */
/* #undef USE_FFMPEG */

/* Software version */
/* #undef VERSION */

/* Whether to include sendfile() support */
#define WITH_SENDFILE 1

/* Define WORDS_BIGENDIAN to 1 if your processor stores words with the most
   significant byte first (like Motorola and SPARC, unlike Intel). */
#if defined AC_APPLE_UNIVERSAL_BUILD
# if defined __BIG_ENDIAN__
#  define WORDS_BIGENDIAN 1
# endif
#else
# ifndef WORDS_BIGENDIAN
/* #  undef WORDS_BIGENDIAN */
# endif
#endif

/* Enable large inode numbers on Mac OS X 10.5.  */
#ifndef _DARWIN_USE_64_BIT_INODE
# define _DARWIN_USE_64_BIT_INODE 1
#endif

/* Number of bits in a file offset, on hosts where this is settable. */
/* #undef _FILE_OFFSET_BITS */

/* Define to 1 if you have glibc. */
#define _GNU_SOURCE 1

/* Define for large files, on AIX-style hosts. */
/* #undef _LARGE_FILES */

/* Define to appropriate substitue if compiler doesnt have __func__ */
/* #undef __func__ */

/* Define to empty if `const' does not conform to ANSI C. */
/* #undef const */

/* Define to `int' if <sys/types.h> doesn't define. */
/* #undef gid_t */

/* Define to `__inline__' or `__inline' if that's what the C compiler
   calls it, or to nothing if 'inline' is not supported under any name.  */
#ifndef __cplusplus
/* #undef inline */
#endif

/* Define to `unsigned' if <sys/types.h> does not define. */
/* #undef ino_t */

/* Define to `off_t' if <sys/types.h> does not define. */
/* #undef loff_t */

/* Define to rpl_malloc if the replacement function should be used. */
/* #undef malloc */

/* Define to `int' if <sys/types.h> does not define. */
/* #undef mode_t */

/* Define to `long int' if <sys/types.h> does not define. */
/* #undef off_t */

/* Define to `loff_t' if <sys/types.h> does not define. */
#define offset_t loff_t

/* Define to `int' if <sys/types.h> does not define. */
/* #undef pid_t */

/* Define to rpl_realloc if the replacement function should be used. */
/* #undef realloc */

/* Define to `unsigned int' if <sys/types.h> does not define. */
/* #undef size_t */

/* Substitute for socklen_t */
/* #undef socklen_t */

/* Define to `int' if <sys/types.h> does not define. */
/* #undef ssize_t */

/* Define to `int' if <sys/types.h> doesn't define. */
/* #undef uid_t */

/* Define as `fork' if `vfork' does not work. */
/* #undef vfork */

/* Define to `unsigned short' if <sys/types.h> does not define. */
/* #undef wchar_t */


/* Give us an unsigned 32-bit data type. */
#if SIZEOF_UNSIGNED_LONG==4
#define UWORD32 unsigned long
#elif SIZEOF_UNSIGNED_INT==4
#define UWORD32 unsigned int
#else
#error I do not know what to use for a UWORD32.
#endif


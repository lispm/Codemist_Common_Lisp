/*
 * fileops.c                 Copyright (C) Codemist Ltd 1994/95
 *
 *      cross-platform support for filenames etc
 *
 *                            A C Norman
 */

/* Signature: 52987356 08-Nov-1995 */

#include "sys.h"

/*
 * datestamps that I put in archives have given me significant
 * trouble with regard to portability - so now I deal with times by
 * talking to the system in terms of broken down local time (struct tm).
 * I then pack things up for myself to get 32-bit timestamps. The
 * encoding I use aims at simplicity - it treats all months as 31 days
 * and thus does not have to worry about leap years etc.
 */

void unpack_date(unsigned long int r,
                 int *year, int *mon, int *day,
                 int *hour, int *min, int *sec)
{
    *sec  = r%60; r = r/60;
    *min  = r%60; r = r/60;
    *hour = r%24; r = r/24;
    *day  = r%32; r = r/32;
    *mon  = r%12; r = r/12;
    *year = 70+r;
}

unsigned long int pack_date(int year, int mon, int day,
                            int hour, int min, int sec)
{
    unsigned long int r = (year-70)*12 + mon;
    r = r*32 + day;
    r = r*24 + hour;
    r = r*60 + min;
    return r*60 + sec;
}

#ifdef __arm

/*
 * The following structure MUST match the layout of a FILE as used by
 * the library that is linked with.
 */

struct FILE_COPY
{ int icnt;      /* two separate _cnt fields so we can police ...        */
  unsigned char *ptr;
  int ocnt;      /* ... restrictions that read/write are fseek separated */
  int flag;
  unsigned char *base;     /* buffer base */
  int file;                /* RISCOS/Arthur/Brazil file handle */
  long pos;                /* position in file */
  int bufsiz;              /* maximum buffer size */
  int signature;           /* used with temporary files */
  unsigned char lilbuf[2]; /* single byte buffer for them that want it   */
                           /* plus an unget char is put in __lilbuf[1]   */
  long lspos;              /* what __pos should be (set after lazy seek) */
  unsigned char *extent;   /* extent of writes into the current buffer   */
  int buflim;              /* used size of buffer                        */
  int icnt_save;           /* after unget contains old icnt              */
  int ocnt_save;           /* after unget contains old ocnt              */
};

int truncate_file(FILE *f, long int where)
{
    os_regset R;
    if (fflush(f) != 0) return 1;
    R.r[0] = 3;
    R.r[1] = (int)((struct FILE_COPY *)f)->file;
    R.r[2] = (int)where;
    os_args(&R);
    return 0;
}

int Cmkdir(char *name)
{
    os_filestr osf;
    osf.action = 8;
    osf.name = name;
    osf.loadaddr = osf.execaddr = osf.start = osf.end = 0;
    os_file(&osf);  /* create directory */
    return 1;
}

/*
 * I would like archives produced by this program to be portable
 * from one machine to another - and to this end I convert filenames
 * into a (partially) standard form based on the conventions used by
 * Unix.
 */

static char *implicit_dirs[] =
/*
 * If I find a directory with one of these names (when I am creating
 * an archive) I map files in it onto suffixed names in the archive -
 * thus for instance a file abc.xyz.lsp.pqr will be known as abc/xyz/pqr.lsp
 * in the archive.  When unloading files from an archive this rule takes
 * precedence over the "leave_suffixes" one shown below.
 */
{
    "!",        /* Used by ACN as a place for scratch files */
    "c",        /* C source code                            */
    "f",        /* Fortran source code                      */
    "h",        /* C header files                           */
    "l",        /* Listings generated by the C compiler     */
    "o",        /* Object code                              */
    "p",        /* Pascal?                                  */
    "s",        /* Assembly code                            */
    "lsp",      /* Used with CSL                            */
    "sl",       /* Used with CSL/REDUCE                     */
    "red",      /* REDUCE sources                           */
    "fsl",      /* CSL fast-load files                      */
    "log",      /* I guess this is the hardest case         */
    "tst",      /* REDUCE test files                        */
    "doc",      /* Another hard case                        */
    "cpp",      /* C++ files                                */
    "hpp",      /* C++ header files                         */
    "txt",      /* to help me with som MSDOS transfers      */
    "bak",      /* Ditto.                                   */
    NULL
};

static char *leave_suffixes[] =
/*
 * If one of these names appears as the leaf name of a file in a directory
 * when I am creating an archive the leaf name is left as a suffix.  Thus
 * abc.xyz.pqr.tex gets stored as abc/xyz/pqr.tex
 */
{
    "300pk",    /* Most of these arise with the Archimedes  */
    "aux",      /* port of TeX, where files are clustered   */
    "bat",      /* into a directory that relates to a single*/
    "bbl",      /* document.                                */
    "bib",
    "blg",
    "doc",
    "dvi",
    "dvi-alw",
    "exe",      /* Used when I store MSDOS images.          */
    "img",      /* Used when I store MSDOS CSL checkpoints  */
    "log",      /* "doc" and "log" are in both lists...     */
    "sty",      /* The effect is that xxx.yyy.log will get  */
    "tex",      /* inserted in the archive as xxx/yyy.log,  */
    "tfm",      /* and re-loaded as xxx.log.yyy             */
    "toc",      /* Some cases I can not win.                */
    "rof",      /* for "doc/scope.rof" in Reduce!           */
    NULL
};

static bool namematch(char *s, char *t)
{   int a, b;
    while ((a = *s++, b = *t++) != 0)
    {
        /* I make this a case-insensitive match */
        if (isupper(a)) a = tolower(a);
        if (isupper(b)) b = tolower(b);
        if (a != b) return FALSE;
    }
/*
 * Since I am matching a component of a file name I allow the string
 * I am looking at to terminate either at string-end (0), or at one
 * of the characters that might separate parts of a file-name.  This extra
 * generality may help me when packing up Acorn names - I guess it can give
 * problems if a '/' or '\' appears embedded in a name...
 */
    if (a == 0 || a == '.' || a == '/' || a == '\\') return TRUE;
    else return FALSE;
}

static bool member(char *s, char **table)
{
    char *t;
    while ((t = *table++) != NULL)
        if (namematch(s, t)) return TRUE;
    return FALSE;
}

void adjust_file_name(char *filename, char *old)
/*
 * This maps a filename that is in the Unix style into one suitable
 * for the Archimedes.  In particular a name of the form ppp/qqq.r will
 * be mapped onto ppp.r.qqq where the directory r will be created
 * automatically.  Also fully rooted Unix names, as in /aaa/bbb get
 * turned into $.aaa.bbb
 * I turn a name-component of the form ".." into "^", so that
 * parent-directory references work.
 */
{
    int j, k, n = strlen(old);
    bool suffix = FALSE;
    char *res = filename;
    if (*old == '/') *res++ = '$'; /* Fully rooted case */
    for (j=n-1; j>=0; j--)
        if (old[j] == '/') break; /* only check last component for suffix */
        else if (old[j] == '.')
        {   suffix = TRUE;
            break;
        }
/*
 * Maybe I found a name of the form xxxx.yyyy, and old[j] is the '.'.
 * If the suffix is in the implicit_dirs list I do a flip.
 */
    if (suffix)
    {   if (member(&old[j+1], implicit_dirs))
        {   int i;
            for (k=j-1; k>=0; k--) if (old[k] == '/') break;
            if (k>=0) memcpy(res, old, k+1);
            memcpy(&res[k+1], &old[j+1], n-j-1);
            for (i=0; i<k+n-j; i++)
            {   int c = res[i];
                if (c == '/') res[i] = '.';
                else if (c == '.') res[i] = '/';
            }
            res[k+n-j] = '.';
            memcpy(&res[k+n-j+1], &old[k+1], j-k-1);
            res[n] = 0;
        }
        else if (member(&old[j+1], leave_suffixes))
        {
            old[j] = '/';
            suffix = FALSE;
        }
        else suffix = FALSE;
    }
    if (!suffix)
    {   for (j=0; j<=n; j++) /* Remember to transfer the final '\0' */
        {   int c = old[j];
            if (c == '/') c = '.';
            else if (c == '.') c = '/';
            res[j] = c;
        }
    }
/*
 * Now if in the Unix world I had a component '..' in the file it will
 * appear something like //.aaa.bbb or aaa.//.bbb
 * Similarly I map an isolated '.' (now an isolated '/') into '@'.
 */
    j = k = 0;
    for (;;)
    {   int c = res[j];
        if (c == '.' || c == 0)
        {   if (j == k+1 && res[k] == '/') res[k] = '@';
            else if (j == k + 2 && res[k] == '/' && res[k+1] == '/')
            {   int c1;
                res[k++] = '^';
                do
                {   c1 = res[k+1];
                    res[k++] = c1;
                } while (c1 != 0);
            }
            k = j+1;
        }
        if (c == 0) break;
        j++;
    }
/*
 * Now one more attempt to be helpful - I will truncate each component of the
 * resulting file name to be at most 10 characters long.
 */    
    j = 0;
    for (;;)
    {   k = j;
        while (res[k] != 0 && res[k] != '.') k++;
        if (k - j > 10)
        {   int p1 = j + 10, p2 = k;
            for (;;)
            {   int c = res[p2++];
                res[p1++] = c;
                if (c == 0) break;
            }
        }
        if (res[k] == 0) break;
        j = k + 1;
    }
}

static void unadjust1(char *filename, char *old, int n)
/*
 * Convert '.' characters into '/' as part of the process of Unixifying
 * file-names.  I also convert the other way ('/' -> '.') in case some
 * clown has filenames that contain '/'.
 */
{
    while (n-- >= 0)
    {   int c = *old++;
        if (c == '.') c = '/';
        else if (c == '/') c = '.';
        *filename++ = c;
    }
}

static void unadjust2(char *filename)
/*
 * This maps any '^' in a filename into '..', but does not bother to
 * look for context, or for any other special softs of file-name.
 */
{
    int j=0, k, c, c1;
    while ((c = filename[j]) != 0)
    {   if (c == '^')
        {   filename[j] = '.';
            k = j+1;
            c1 = '.';
            do
            {   c = filename[k];
                filename[k++] = c1;
                c1 = c;
            } while (c != 0);
        }
        j++;
    }
}

void unadjust_file_name(char *filename, char *old)
/*
 * This procedure maps filenames from Acorn format to Unix format,
 * allowing single-character directories to map onto extensions,
 * together with special cases for RED, LSP, LOG, FSL etc etc
 */
{
    int j, k, n = strlen(old);
    for (j=n-1; j>=0; j--) if (old[j] == '.') break;
    if (j < 0)
    {   strcpy(filename, old);
        unadjust2(filename);
        return;     /* No '.' found, so no conversion needed */
    }
/* Find the last '.' in the file name */
    for (k=j-1; k>=0; k--) if (old[k] == '.') break;
/*
 * Test to see if penultimate component of file-name is one of the
 * special "implicit-directory" names.
 */
    if (member(&old[k+1], implicit_dirs))
/*
 * If so turn "." to "/" in the root part of the name, and flip the order
 * of the name and extension.
 */
    {   unadjust1(filename, old, k);
        memcpy(&filename[k+1], &old[j+1], n-j-1);
        filename[k+n-j] = '.';
        memcpy(&filename[k+n-j+1], &old[k+1], j-k-1);
    }
/*
 * If the leaf name is in the second list of special cases leave it in
 * the converted name as a suffix.
 */
    else if (member(&old[j+1], leave_suffixes))
    {   old[j] = '/';
        unadjust1(filename, old, n);
        old[j] = '.';
    }
/* Otherwise just map "." onto "/" throughout the name */
    else unadjust1(filename, old, n);
    filename[n] = 0;
/*
 * Files that started off as $.xxx now look like $/xxx, and should be
 * just "/xxx" - fix that case up.
 */
    if (filename[0] == '$' && filename[1] == '/')
        memmove(&filename[0], &filename[1], n);
    unadjust2(filename);
    return;
}

/* Reinstate date and filetype... */
void set_filedate(char *name, unsigned long int datestamp,
                              unsigned long int filetype)
{   os_filestr ctrl;
    time_t t0;
    unsigned32 high, low;
    struct tm st;
    unpack_date(datestamp, &st.tm_year, &st.tm_mon, &st.tm_mday,
                           &st.tm_hour, &st.tm_min, &st.tm_sec);
    st.tm_isdst = -1;
    t0 = mktime(&st);
    low = t0 + (70*365+17)*24*60*60u;
    high = 100*(low >> 16);
/* If the filetype looks odd I map it into a "text" file */
    if (filetype <= 0xe00) filetype = 0xfff;
    low = 100*(unsigned32)(low & 0xffffU);
    high = high + (low >> 16);
    low = (high << 16) | (low & 0xffffU);
    high = (high >> 16) & 0xff;     /* Now in Acorn format */
    high |= 0xfff00000U | ((filetype & 0xfff) << 8);
    if (datestamp == 0) low = high = 0;
    ctrl.action = 1;
    ctrl.name = name;
    ctrl.loadaddr = (int)high;
    ctrl.execaddr = (int)low;
    ctrl.end = 3;                   /* Readable & writeable */
    os_file(&ctrl);                 /* Reset date & type */
}

void put_fileinfo(date_and_type *p, char *name)
{
    unsigned long int datestamp, filetype;
    os_filestr parms;
/*
 * Read file parameters...
 */
    parms.action = 5;
    parms.name = name;
    os_file(&parms); /* load & exec -> type & datestamp */
    if ((parms.loadaddr & 0xfff00000U) == 0xfff00000U)
/*
 * Acorn keep datestamps accurate to 0.01 second - here I reduce it to
 * a resolution of just one second.
 */
    {   unsigned32 dhi = parms.loadaddr & 0xff;
        unsigned32 dlo = parms.execaddr;
        struct tm *st;
        dhi = (dhi << 16) | (dlo >> 16);
        dlo = ((dhi % 100) << 16) | (dlo & 0xffffU);
        dhi = dhi / 100;
        datestamp = (dhi << 16) | (dlo / 100U);
        datestamp -= ((70*(unsigned32)365 + 17)*24)*60*60;  /* Base 1970 now */
        filetype = ((int32)parms.loadaddr >> 8) & 0xfff;
        st = localtime(&datestamp);
        datestamp = pack_date(st->tm_year, st->tm_mon, st->tm_mday,
                              st->tm_hour, st->tm_min, st->tm_sec);
    }
    else
    {   datestamp = 0;
        filetype = 0;
    }
    p->date = datestamp;
    p->type = filetype;
}

#else  /* __arm */

#ifdef WINDOWS_NT
/*
 * This version is for Windows NT 3.1 with Microsoft VC++, Windows 95,
 * NT 3.5 etc etc, also with Watcom C
 */

int Cmkdir(char *name)
{
    SECURITY_ATTRIBUTES s;
    s.nLength = sizeof(s);
    s.lpSecurityDescriptor = NULL;
    s.bInheritHandle = FALSE;
    return CreateDirectory(name, &s);
}

int truncate_file(FILE *f, long int where)
{
    if (fflush(f) != 0) return 1;
    return _chsize(fileno(f), where);  /* Returns zero if successs */
}

/*
 * For NT all I do to normalise names is swop '/' and '\' characters.
 * Note that this is assuming that I will be using a FAT file system
 */
void adjust_file_name(char *filename, char *old)
{
    int j, n = strlen(old);
    strcpy(filename, old);
    for (j=0; j<n; j++)
        if (filename[j] == '/') filename[j] = '\\';
        else if (filename[j] == '\\') filename[j] = '/';
    return;
}

void unadjust_file_name(char *filename, char *old)
{
    int j, n = strlen(old);
    strcpy(filename, old);
    for (j=0; j<n; j++)
        if (filename[j] == '/') filename[j] = '\\';
        else if (filename[j] == '\\') filename[j] = '/';
    return;
}

void set_filedate(char *name, unsigned long int datestamp,
                              unsigned long int filetype)
{   HANDLE h = CreateFile(name, GENERIC_WRITE, 0, NULL,
                         OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    SYSTEMTIME st;
    FILETIME ft;
    int yr, mon, day, hr, min, sec;
/*
 * Here datestamp is a time expressed in seconds since the start of 1970.
 * I need to convert it into a broken-down SYSTEMTIME so that I can then
 * re-pack it as a Windows-NT FILETIME....
 */
    unpack_date(datestamp, &yr, &mon, &day, &hr, &min, &sec);
    st.wMilliseconds = 0;
    st.wYear = yr + 1900;
    st.wMonth = mon + 1;
    st.wDay = day;
    st.wHour = hr;
    st.wMinute = min;
    st.wSecond = sec;
    SystemTimeToFileTime(&st, &ft);
    SetFileTime(h, NULL, NULL, &ft);
    CloseHandle(h);
}

void put_fileinfo(date_and_type *p, char *name)
{
    unsigned long int datestamp, filetype;
    struct stat file_info;
    struct tm *st;
/*
 * Read file parameters...  Maybe I should use a Windows-style not a Unix-style
 * call here?
 */
    stat(name, &file_info);
    st = localtime(&(file_info.st_mtime));
    datestamp = pack_date(st->tm_year, st->tm_mon, st->tm_mday,
                          st->tm_hour, st->tm_min, st->tm_sec);
    filetype = 0xfff;
    p->date = datestamp;
    p->type = filetype;
}

#else /* WINDOWS_NT */

#ifdef MS_DOS

int truncate_file(FILE *f, long int where)
{
    if (fflush(f) != 0) return 1;
#ifndef __WATCOMC__
#define fileno(fp) ((fp)->_file)      /* see <stdio.h>            */
#endif
    return chsize(fileno(f), where);  /* Returns zero if successs */
}

int Cmkdir(char *s)
{
    return mkdir(s);
}

/*
 * For MSDOS all I do to normalise names is swop '/' and '\' characters.
 */

void adjust_file_name(char *filename, char *old)
{
    int j, n = strlen(old);
    strcpy(filename, old);
    for (j=0; j<n; j++)
        if (filename[j] == '/') filename[j] = '\\';
        else if (filename[j] == '\\') filename[j] = '/';
    return;
}

void unadjust_file_name(char *filename, char *old)
{
    int j, n = strlen(old);
    strcpy(filename, old);
    for (j=0; j<n; j++)
        if (filename[j] == '/') filename[j] = '\\';
        else if (filename[j] == '\\') filename[j] = '/';
    return;
}

void set_filedate(char *name, unsigned long int datestamp,
                              unsigned long int filetype)
{
#ifdef __WATCOMC__
    struct utimbuf tt;
#else
    time_t tt[2];
#endif
    time_t t0;
    struct tm st;
    filetype = filetype;
    unpack_date(datestamp, &st.tm_year, &st.tm_mon, &st.tm_mday,
                           &st.tm_hour, &st.tm_min, &st.tm_sec);
    st.tm_isdst = -1;
    t0 = mktime(&st);
#ifdef __WATCOMC__
    tt.actime = tt.modtime = t0;
    utime(name, &tt);
#else
    tt[0] = tt[1] = t0;
    utime(name, tt);
#endif
}

extern int stat(const char *, struct stat*);

void put_fileinfo(date_and_type *p, char *name)
{
    unsigned long int datestamp, filetype;
    struct stat file_info;
    struct tm *st;
/*
 * Read file parameters...
 */
    stat(name, &file_info);
    st = localtime(&(file_info.st_mtime));
    datestamp = pack_date(st->tm_year, st->tm_mon, st->tm_mday,
                          st->tm_hour, st->tm_min, st->tm_sec);
    filetype = 0xfff;
    p->date = datestamp;
    p->type = filetype;
}

#else /* MS_DOS */

#ifdef UNIX

extern ftruncate(int, int);

int truncate_file(FILE *f, long int where)
{
#ifdef NCC_LIB
#define SYS_ftruncate (130)
    extern int _syscall2(int, int, int);
    extern int _fileno(FILE *);
#endif
    if (fflush(f) != 0) return 1;
#ifdef NCC_LIB
    /* Returns zero if successs */
    return _syscall2(SYS_ftruncate, _fileno(f), (int)where);
#else
    return ftruncate(fileno(f), where);  /* Returns zero if successs */
#endif
}

/* extern void mkdir(const char *, unsigned short int); */

int Cmkdir(char *s)
{
    mkdir(s, 0774);
    return 1;
}

void adjust_file_name(char *filename, char *old)
{
    strcpy(filename, old);
    return;
}

void unadjust_file_name(char *filename, char *old)
{
    strcpy(filename, old);
    return;
}

void set_filedate(char *name, unsigned long int datestamp,
                              unsigned long int filetype)
{   struct utimbuf tt;
    time_t t0;
    struct tm st;
    unpack_date(datestamp, &st.tm_year, &st.tm_mon, &st.tm_mday,
                           &st.tm_hour, &st.tm_min, &st.tm_sec);
    st.tm_isdst = -1;
    t0 = mktime(&st);
    tt.actime = tt.modtime = t0;
    utime(name, &tt);
}

void put_fileinfo(date_and_type *p, char *name)
{
    unsigned long int datestamp, filetype;
    struct stat file_info;
    struct tm *st;
/*
 * Read file parameters...
 */
    stat(name, &file_info);
    st = localtime(&(file_info.st_mtime));
    datestamp = pack_date(st->tm_year, st->tm_mon, st->tm_mday,
                          st->tm_hour, st->tm_min, st->tm_sec);
    filetype = 0xfff;  /* should get access status here? */
    p->date = datestamp;
    p->type = filetype;
}

#else /* UNIX */

#ifdef ATARI

int truncate_file(FILE *f, long int where)
{
    if (fflush(f) != 0) return 1;
#define fileno(fp) ((fp)->_file)      /* see <stdio.h>            */
    return chsize(fileno(f), where);  /* Returns zero if successs */
}

int Cmkdir(char *s)
{
    mkdir(s);
    return 1;
}

/*
 * For TOS all I do to normalise names is swop '/' and '\' characters.
 */
void adjust_file_name(char *filename, char *old)
{
    int j, n = strlen(old);
    strcpy(filename, old);
    for (j=0; j<n; j++)
        if (filename[j] == '/') filename[j] = '\\';
        else if (filename[j] == '\\') filename[j] = '/';
    return;
}

void unadjust_file_name(char *filename, char *old)
{
    int j, n = strlen(old);
    strcpy(filename, old);
    for (j=0; j<n; j++)
        if (filename[j] == '/') filename[j] = '\\';
        else if (filename[j] == '\\') filename[j] = '/';
    return;
}

/* No file date support for ATARI yet */

#else /* ATARI */

#ifdef macintosh

int Cmkdir(char *s)
{
    mkdir(s);
    return 1;
}

/*
 * For the Macintosh I normalise names by swopping '/' and ':' characters.
 */
void adjust_file_name(char *filename, char *old)
{
    int c, j, n = strlen(old);
    filename[0] = ':';
    strcpy(filename+1, old);
    for (j=1; j<=n; j++)
        if (filename[j] == '/') filename[j] = ':';
        else if (filename[j] == ':') filename[j] = '/';
/*
 * Now if I find a pattern :..: in the string I just squash it to read ::,
 * since that is how that Mac indicates a parent directory.  Note that
 * I always have an initial : at the start of a name, so nothing special
 * is needed there.
 */
    j = 0;
    while ((c = filename[j]) != 0)
    {   if (c == ':' && filename[j+1] == '.' &&
            filename[j+2] == '.' && filename[j+3] == ':')
        {   int k = j+1;
            do
            {   c = filename[k+2];
                filename[k++] = c;
            } while (c != 0);
        }
        j++;
    }
    return;
}

void unadjust_file_name(char *filename, char *old)
{
    int j, n = strlen(old);
    filename[0] = ':'
    strcpy(filename+1, old);
    for (j=1; j<=n; j++)
        if (filename[j] == '/') filename[j] = ':';
        else if (filename[j] == ':') filename[j] = '/';
    return;
}

/* No file date services on Macintosh yet */

#endif /* macintosh */
#endif /* ATARI */
#endif /* UNIX */
#endif /* MS_DOS */
#endif /* WINDOWS_NT */
#endif /* __arm */

/* End of fileops.c */


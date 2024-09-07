class UgrepHead < Formula
  desc "Ultra fast grep with query UI, fuzzy search, archive search, and more"
  homepage "https://github.com/Genivia/ugrep"
  license "BSD-3-Clause"
  head "https://github.com/Genivia/ugrep.git", branch: "master"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :head
  depends_on "boost" => :build
  depends_on "brotli" => :build
  depends_on "bzip2" => :build
  depends_on "bzip3" => :build
  depends_on "lz4" => :build
  depends_on "pcre2" => :build
  depends_on "xz" => :build
  depends_on "zlib" => :build
  depends_on "zstd" => :build

  # 'configure' configures ugrep 6.3.0 to adapt to many kinds of systems.
  #
  # Usage: ./configure [OPTION]... [VAR=VALUE]...
  #
  # To assign environment variables (e.g., CC, CFLAGS...), specify them as
  # VAR=VALUE.  See below for descriptions of some of the useful variables.
  #
  # Defaults for the options are specified in brackets.
  #
  # Configuration:
  #   -h, --help              display this help and exit
  #       --help=short        display options specific to this package
  #       --help=recursive    display the short help of all the included packages
  #   -V, --version           display version information and exit
  #   -q, --quiet, --silent   do not print 'checking ...' messages
  #       --cache-file=FILE   cache test results in FILE [disabled]
  #   -C, --config-cache      alias for '--cache-file=config.cache'
  #   -n, --no-create         do not create output files
  #       --srcdir=DIR        find the sources in DIR [configure dir or '..']
  #
  # Installation directories:
  #   --prefix=PREFIX         install architecture-independent files in PREFIX
  #                           [/usr/local]
  #   --exec-prefix=EPREFIX   install architecture-dependent files in EPREFIX
  #                           [PREFIX]
  #
  # By default, 'make install' will install all the files in
  # '/usr/local/bin', '/usr/local/lib' etc.  You can specify
  # an installation prefix other than '/usr/local' using '--prefix',
  # for instance '--prefix=$HOME'.
  #
  # For better control, use the options below.
  #
  # Fine tuning of the installation directories:
  #   --bindir=DIR            user executables [EPREFIX/bin]
  #   --sbindir=DIR           system admin executables [EPREFIX/sbin]
  #   --libexecdir=DIR        program executables [EPREFIX/libexec]
  #   --sysconfdir=DIR        read-only single-machine data [PREFIX/etc]
  #   --sharedstatedir=DIR    modifiable architecture-independent data [PREFIX/com]
  #   --localstatedir=DIR     modifiable single-machine data [PREFIX/var]
  #   --runstatedir=DIR       modifiable per-process data [LOCALSTATEDIR/run]
  #   --libdir=DIR            object code libraries [EPREFIX/lib]
  #   --includedir=DIR        C header files [PREFIX/include]
  #   --oldincludedir=DIR     C header files for non-gcc [/usr/include]
  #   --datarootdir=DIR       read-only arch.-independent data root [PREFIX/share]
  #   --datadir=DIR           read-only architecture-independent data [DATAROOTDIR]
  #   --infodir=DIR           info documentation [DATAROOTDIR/info]
  #   --localedir=DIR         locale-dependent data [DATAROOTDIR/locale]
  #   --mandir=DIR            man documentation [DATAROOTDIR/man]
  #   --docdir=DIR            documentation root [DATAROOTDIR/doc/ugrep]
  #   --htmldir=DIR           html documentation [DOCDIR]
  #   --dvidir=DIR            dvi documentation [DOCDIR]
  #   --pdfdir=DIR            pdf documentation [DOCDIR]
  #   --psdir=DIR             ps documentation [DOCDIR]
  #
  # Program names:
  #   --program-prefix=PREFIX            prepend PREFIX to installed program names
  #   --program-suffix=SUFFIX            append SUFFIX to installed program names
  #   --program-transform-name=PROGRAM   run sed PROGRAM on installed program names
  #
  # System types:
  #   --build=BUILD     configure for building on BUILD [guessed]
  #   --host=HOST       cross-compile to build programs to run on HOST [BUILD]
  #
  # Optional Features:
  #   --disable-option-checking  ignore unrecognized --enable/--with options
  #   --disable-FEATURE       do not include FEATURE (same as --enable-FEATURE=no)
  #   --enable-FEATURE[=ARG]  include FEATURE [ARG=yes]
  #   --enable-silent-rules   less verbose build output (undo: "make V=1")
  #   --disable-silent-rules  verbose build output (undo: "make V=0")
  #   --enable-dependency-tracking
  #                           do not reject slow dependency extractors
  #   --disable-dependency-tracking
  #                           speeds up one-time build
  #   --disable-sse2          disable SSE2 CPU extensions
  #   --disable-avx2          disable AVX2/AVX512BW CPU extensions
  #   --disable-neon          disable NEON CPU extensions
  #   --disable-7zip          to disable 7zip and no longer search .7z files (7z
  #                           requires more memory and takes long to decompress)
  #   --enable-static         build static ugrep binaries
  #   --disable-auto-color    disable automatic colors, otherwise colors are
  #                           enabled by default
  #   --enable-color          deprecated, use --disable-auto-color
  #   --enable-pretty         enable pretty output by default without requiring
  #                           ugrep flag --pretty
  #   --enable-pager          enable the pager by default without requiring ugrep
  #                           flag --pager
  #   --enable-hidden         enable searching hidden files and directories by
  #                           default unless explicitly disabled with ugrep flag
  #                           --no-hidden
  #   --disable-mmap          disable memory mapped files unless explicitly
  #                           enabled with --mmap
  #
  # Optional Packages:
  #   --with-PACKAGE[=ARG]    use PACKAGE [ARG=yes]
  #   --without-PACKAGE       do not use PACKAGE (same as --with-PACKAGE=no)
  #   --with-pcre2=DIR        root directory path of PCRE2 installation [defaults to
  #                           /usr/local or /usr if not found in /usr/local]
  #   --without-pcre2         to disable PCRE2 usage completely
  #   --with-boost-regex[=special-lib]
  #                           use the Regex library from boost - it is possible to
  #                           specify a path to include/boost and
  #                           lib/libboost_regex-mt e.g.
  #                           --with-boost-regex=/opt/local
  #   --with-zlib=DIR         root directory path of zlib installation [defaults to
  #                           /usr/local or /usr if not found in /usr/local]
  #   --without-zlib          to disable zlib usage completely
  #   --with-bzlib=DIR        root directory path of bzlib installation [defaults to
  #                           /usr/local or /usr if not found in /usr/local]
  #   --without-bzlib         to disable bzlib usage completely
  #   --with-lzma=DIR         root directory path of lzma installation [defaults to
  #                           /usr/local or /usr if not found in /usr/local]
  #   --without-lzma          to disable lzma usage completely
  #   --with-lz4=DIR          root directory path of lz4 installation [defaults to
  #                           /usr/local or /usr if not found in /usr/local]
  #   --without-lz4           to disable lz4 usage completely
  #   --with-zstd=DIR         root directory path of zstd installation [defaults to
  #                           /usr/local or /usr if not found in /usr/local]
  #   --without-zstd          to disable zstd usage completely
  #   --with-brotli=DIR       root directory path of brotli library installation
  #                           [defaults to /usr/local or /usr if not found in
  #                           /usr/local]
  #   --without-brotli        to disable brotli library usage completely
  #   --with-bzip3            to enable bzip3 library to decompress .bz3 files
  #   --with-bzip3=DIR        root directory path of bzip3 library installation
  #                           [defaults to /usr/local or /usr if not found in
  #                           /usr/local]
  #   --without-bzip3         to disable bzip3 library usage completely
  #   --with-bash-completion-dir=PATH
  #                           install the bash auto-completion script in this
  #                           directory. [default=yes]
  #   --with-fish-completion-dir=PATH
  #                           install the fish auto-completion script in this
  #                           directory. [default=yes]
  #   --with-zsh-completion-dir=PATH
  #                           install the zsh auto-completion script in this
  #                           directory. [default=yes]
  #   --with-grep-path=GREP_PATH
  #                           specifies the GREP_PATH if different than the
  #                           default DATAROOTDIR/ugrep/patterns
  #   --with-grep-colors="GREP_COLORS"
  #                           specifies the default ANSI SGR color parameters when
  #                           variable GREP_COLORS is undefined
  #
  # Some influential environment variables:
  #   CXX         C++ compiler command
  #   CXXFLAGS    C++ compiler flags
  #   LDFLAGS     linker flags, e.g. -L<lib dir> if you have libraries in a
  #               nonstandard directory <lib dir>
  #   LIBS        libraries to pass to the linker, e.g. -l<library>
  #   CPPFLAGS    (Objective) C/C++ preprocessor flags, e.g. -I<include dir> if
  #               you have headers in a nonstandard directory <include dir>
  #   CC          C compiler command
  #   CFLAGS      C compiler flags
  #   CPP         C preprocessor
  #   PKG_CONFIG  path to pkg-config utility
  #   PKG_CONFIG_PATH
  #               directories to add to pkg-config's search path
  #   PKG_CONFIG_LIBDIR
  #               path overriding pkg-config's built-in search path
  #   BASH_COMPLETION_CFLAGS
  #               C compiler flags for BASH_COMPLETION, overriding pkg-config
  #   BASH_COMPLETION_LIBS
  #               linker flags for BASH_COMPLETION, overriding pkg-config
  #   FISH_COMPLETION_CFLAGS
  #               C compiler flags for FISH_COMPLETION, overriding pkg-config
  #   FISH_COMPLETION_LIBS
  #               linker flags for FISH_COMPLETION, overriding pkg-config
  #
  # Use these variables to override the choices made by 'configure' or to help
  # it to find libraries and programs with nonstandard names/locations.
  #
  # Report bugs to <https://github.com/Genivia/ugrep/issues>.
  # ugrep home page: <https://ugrep.com>.

  # depends_on "boost"
  # depends_on "brotli"
  # depends_on "bzip2"
  # depends_on "bzip3"
  # depends_on "lz4"
  # depends_on "pcre2"
  # depends_on "xz"
  # depends_on "zlib"
  # depends_on "zstd"

  # ./configure --disable-dependency-tracking --disable-silent-rules --with-pcre2=/usr/local/opt/pcre2 --with-boost-regex=/usr/local/opt/boost --with-zlib=/usr/local/opt/zlib --with-bzlib=/usr/local/opt/bzip2 --with-lzma=/usr/local/opt/xz --with-lz4=/usr/local/opt/lz4 --with-zstd=/usr/local/opt/zstd --with-brotli=/usr/local/opt/brotli --with-bzip3=/usr/local/opt/bzip3 --with-bash-completion-dir --with-fish-completion-dir --with-zsh-completion-dir LIBS='/usr/local/opt/pcre2/lib/libpcre2-8.a /usr/local/opt/zlib/lib/libz.a /usr/local/opt/bzip2/lib/libbz2.a /usr/local/opt/xz/lib/liblzma.a /usr/local/opt/lz4/lib/liblz4.a /usr/local/opt/zstd/lib/libzstd.a /usr/local/opt/bzip3/lib/libbzip3.a'
  def install
    system "autoreconf", "-fiv"

    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --with-boost-regex=#{Formula["boost"].opt_prefix}
      --with-brotli=#{Formula["brotli"].opt_prefix}
      --with-bzlib=#{Formula["bzip2"].opt_prefix}
      --with-bzip3=#{Formula["bzip3"].opt_prefix}
      --with-lz4=#{Formula["lz4"].opt_prefix}
      --with-pcre2=#{Formula["pcre2"].opt_prefix}
      --with-lzma=#{Formula["xz"].opt_prefix}
      --with-zlib=#{Formula["zlib"].opt_prefix}
      --with-zstd=#{Formula["zstd"].opt_prefix}
      --with-bash-completion-dir
      --with-fish-completion-dir
      --with-zsh-completion-dir
    ]
    ENV.append "CFLAGS", '-march=native -Ofast -flto -mavx -mavx2 -mavx512f -mavx512cd -mavx512dq -mavx512bw -mavx512vl -mavx512vnni'
    ENV.append "CXXFLAGS", '-march=native -Ofast -flto -mavx -mavx2 -mavx512f -mavx512cd -mavx512dq -mavx512bw -mavx512vl -mavx512vnni'
    ENV.append "LIBS", "#{Formula["pcre2"].opt_lib}/libpcre2-8.a #{Formula["zlib"].opt_lib}/libz.a #{Formula["bzip2"].opt_lib}/libbz2.a #{Formula["xz"].opt_lib}/liblzma.a #{Formula["lz4"].opt_lib}/liblz4.a #{Formula["zstd"].opt_lib}/libzstd.a #{Formula["bzip3"].opt_lib}/libbzip3.a"
    # ENV.append "LDFLAGS", '/usr/local/opt/bzip2/lib/libbz2.a'

    system "./configure", *args
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"Hello.txt").write("Hello World!")
    assert_match "Hello World!", shell_output("#{bin}/ug 'Hello' '#{testpath}'").strip
    assert_match "Hello World!", shell_output("#{bin}/ugrep 'World' '#{testpath}'").strip
  end
end

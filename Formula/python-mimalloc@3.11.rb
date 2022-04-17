class PythonMimallocAT311 < Formula
  desc "Interpreted, interactive, object-oriented programming language"
  homepage "https://www.python.org/"
  url "https://www.python.org/ftp/python/3.11.0/Python-3.11.0a7.tgz"
  sha256 "6cc20b9b53a8e7a29e0fd56a0d502ff64a5677507fcf2c503decf732a31c513d"
  license "Python-2.0"
  head "https://github.com/python/cpython.git", branch: "main"

  livecheck do
    url "https://www.python.org/ftp/python/"
    regex(%r{href=.*?v?(3\.11(?:\.\d+)*)/?["' >]}i)
  end

  # setuptools remembers the build flags python is built with and uses them to
  # build packages later. Xcode-only systems need different flags.
  pour_bottle? only_if: :clt_installed

  keg_only :versioned_formula

  depends_on "pkg-config" => :build
  depends_on "gdbm"
  depends_on "mpdecimal"
  depends_on "openssl@1.1"
  depends_on "readline"
  depends_on "sqlite"
  depends_on "xz"

  uses_from_macos "bzip2"
  uses_from_macos "expat"
  uses_from_macos "libffi"
  uses_from_macos "ncurses"
  uses_from_macos "unzip"
  uses_from_macos "zlib"

  skip_clean "bin/pip3", "bin/pip-3.4", "bin/pip-3.5", "bin/pip-3.6", "bin/pip-3.7", "bin/pip-3.8", "bin/pip-3.9",
              "bin/pip-3.10"
  skip_clean "bin/easy_install3", "bin/easy_install-3.4", "bin/easy_install-3.5", "bin/easy_install-3.6",
              "bin/easy_install-3.7", "bin/easy_install-3.8", "bin/easy_install-3.9", "bin/easy_install-3.10"

  resource "setuptools" do
    url "https://files.pythonhosted.org/packages/1e/00/05f51ceab8d3b9be4295000d8be4c830c53e5477755888994e9825606cd9/setuptools-58.5.3.tar.gz"
    sha256 "dae6b934a965c8a59d6d230d3867ec408bb95e73bd538ff77e71fedf1eaca729"
  end

  resource "pip" do
    url "https://files.pythonhosted.org/packages/da/f6/c83229dcc3635cdeb51874184241a9508ada15d8baa337a41093fab58011/pip-21.3.1.tar.gz"
    sha256 "fd11ba3d0fdb4c07fbc5ecbba0b1b719809420f25038f8ee3cd913d3faa3033a"
  end

  resource "wheel" do
    url "https://files.pythonhosted.org/packages/4e/be/8139f127b4db2f79c8b117c80af56a3078cc4824b5b94250c7f81a70e03b/wheel-0.37.0.tar.gz"
    sha256 "e2ef7239991699e3355d54f8e968a21bb940a1dbf34a4d226741e64462516fad"
  end

  patch :DATA

  def lib_cellar
    on_macos do
      return prefix/"Frameworks/Python.framework/Versions/#{version.major_minor}/lib/python#{version.major_minor}"
    end
    on_linux do
      return prefix/"lib/python#{version.major_minor}"
    end
  end

  def site_packages_cellar
    lib_cellar/"site-packages"
  end

  # The HOMEBREW_PREFIX location of site-packages.
  def site_packages
    HOMEBREW_PREFIX/"lib/python#{version.major_minor}/site-packages"
  end

  def install
    # Unset these so that installing pip and setuptools puts them where we want
    # and not into some other Python the user has installed.
    ENV["PYTHONHOME"] = nil
    ENV["PYTHONPATH"] = nil

    # Override the auto-detection in setup.py, which assumes a universal build.
    if OS.mac?
      ENV["PYTHON_DECIMAL_WITH_MACHINE"] = Hardware::CPU.arm? ? "uint128" : "x64"
    end

    # The --enable-optimization and --with-lto flags diverge from what upstream
    # python does for their macOS binary releases. They have chosen not to apply
    # these flags because they want one build that will work across many macOS
    # releases. Homebrew is not so constrained because the bottling
    # infrastructure specializes for each macOS major release.
    args = %W[
      --prefix=#{prefix}
      --enable-ipv6
      --datarootdir=#{share}
      --datadir=#{share}
      --without-ensurepip
      --enable-loadable-sqlite-extensions
      --with-openssl=#{Formula["openssl@1.1"].opt_prefix}
      --with-dbmliborder=gdbm:ndbm
      --enable-optimizations
      --with-lto
      --with-experimental-isolated-subinterpreters
      --with-mimalloc
      --enable-mimalloc-secure=no
      --with-system-expat
      --with-system-ffi
      --with-system-libmpdec
    ]

    if OS.mac?
      args << "--enable-framework=#{frameworks}"
      args << "--with-dtrace"
    else
      args << "--enable-shared"
    end

    # Python re-uses flags when building native modules.
    # Since we don't want native modules prioritizing the brew
    # include path, we move them to [C|LD]FLAGS_NODIST.
    # Note: Changing CPPFLAGS causes issues with dbm, so we
    # leave it as-is.
    cflags         = ["-DINTERNED_STRINGS"]
    cflags_nodist  = ["-I#{HOMEBREW_PREFIX}/include"]
    ldflags        = []
    ldflags_nodist = ["-L#{HOMEBREW_PREFIX}/lib", "-Wl,-rpath,#{HOMEBREW_PREFIX}/lib"]
    cppflags       = ["-I#{HOMEBREW_PREFIX}/include"]

    if MacOS.sdk_path_if_needed
      # Help Python's build system (setuptools/pip) to build things on SDK-based systems
      # The setup.py looks at "-isysroot" to get the sysroot (and not at --sysroot)
      cflags  << "-isysroot #{MacOS.sdk_path}"
      ldflags << "-isysroot #{MacOS.sdk_path}"
    end
    # Avoid linking to libgcc https://mail.python.org/pipermail/python-dev/2012-February/116205.html
    args << "MACOSX_DEPLOYMENT_TARGET=#{MacOS.version}"

    # Disable _tkinter - this is built in a separate formula python-tk
    inreplace "setup.py", "DISABLED_MODULE_LIST = []", "DISABLED_MODULE_LIST = ['_tkinter']"

    # We want our readline! This is just to outsmart the detection code,
    # superenv makes cc always find includes/libs!
    inreplace "setup.py",
      /do_readline = self.compiler.find_library_file\(self.lib_dirs,\s*readline_lib\)/,
      "do_readline = '#{Formula["readline"].opt_lib}/#{shared_library("libhistory")}'"

    # inreplace "setup.py" do |s|
    #   s.gsub! "sqlite_setup_debug = False", "sqlite_setup_debug = True"
    #   s.gsub! "for d_ in self.inc_dirs + sqlite_inc_paths:",
    #           "for d_ in ['#{Formula["sqlite"].opt_include}']:"
    # end

    if OS.linux?
      # Python's configure adds the system ncurses include entry to CPPFLAGS
      # when doing curses header check. The check may fail when there exists
      # a 32-bit system ncurses (conflicts with the brewed 64-bit one).
      # See https://github.com/Homebrew/linuxbrew-core/pull/22307#issuecomment-781896552
      # We want our ncurses! Override system ncurses includes!
      inreplace "configure",
        'CPPFLAGS="$CPPFLAGS -I/usr/include/ncursesw"',
        "CPPFLAGS=\"$CPPFLAGS -I#{Formula["ncurses"].opt_include}\""
    end

    # Allow python modules to use ctypes.find_library to find homebrew's stuff
    # even if homebrew is not a /usr/local/lib. Try this with:
    # `brew install enchant && pip install pyenchant`
    inreplace "./Lib/ctypes/macholib/dyld.py" do |f|
      f.gsub! "DEFAULT_LIBRARY_FALLBACK = [",
              "DEFAULT_LIBRARY_FALLBACK = [ '#{HOMEBREW_PREFIX}/lib', '#{Formula["openssl@1.1"].opt_lib}',"
      f.gsub! "DEFAULT_FRAMEWORK_FALLBACK = [", "DEFAULT_FRAMEWORK_FALLBACK = [ '#{HOMEBREW_PREFIX}/Frameworks',"
    end

    args << "CFLAGS=#{cflags.join(" ")}" unless cflags.empty?
    args << "CFLAGS_NODIST=#{cflags_nodist.join(" ")}" unless cflags_nodist.empty?
    args << "LDFLAGS=#{ldflags.join(" ")}" unless ldflags.empty?
    args << "LDFLAGS_NODIST=#{ldflags_nodist.join(" ")}" unless ldflags_nodist.empty?
    args << "CPPFLAGS=#{cppflags.join(" ")}" unless cppflags.empty?

    system "./configure", *args
    system "make"

    ENV.deparallelize do
      # Tell Python not to install into /Applications (default for framework builds)
      system "make", "install", "PYTHONAPPSDIR=#{prefix}"
      system "make", "frameworkinstallextras", "PYTHONAPPSDIR=#{pkgshare}" if OS.mac?
    end

    # Any .app get a " 3" attached, so it does not conflict with python 2.x.
    Dir.glob("#{prefix}/*.app") { |app| mv app, app.sub(/\.app$/, " 3.app") }

    if OS.mac?
      # Prevent third-party packages from building against fragile Cellar paths
      inreplace Dir[lib_cellar/"**/_sysconfigdata__darwin_darwin.py",
                    lib_cellar/"config*/Makefile",
                    frameworks/"Python.framework/Versions/3*/lib/pkgconfig/python-3.?.pc"],
                prefix, opt_prefix

      # Help third-party packages find the Python framework
      inreplace Dir[lib_cellar/"config*/Makefile"],
                /^LINKFORSHARED=(.*)PYTHONFRAMEWORKDIR(.*)/,
                "LINKFORSHARED=\\1PYTHONFRAMEWORKINSTALLDIR\\2"

      # Fix for https://github.com/Homebrew/homebrew-core/issues/21212
      inreplace Dir[lib_cellar/"**/_sysconfigdata__darwin_darwin.py"],
                %r{('LINKFORSHARED': .*?)'(Python.framework/Versions/3.\d+/Python)'}m,
                "\\1'#{opt_prefix}/Frameworks/\\2'"
    else
      # Prevent third-party packages from building against fragile Cellar paths
      inreplace Dir[lib_cellar/"**/_sysconfigdata_*linux_x86_64-*.py",
                    lib_cellar/"config*/Makefile",
                    bin/"python#{version.major_minor}-config",
                    lib/"pkgconfig/python-3.?.pc"],
                prefix, opt_prefix

      inreplace bin/"python#{version.major_minor}-config",
                'prefix_real=$(installed_prefix "$0")',
                "prefix_real=#{opt_prefix}"
    end

    # Symlink the pkgconfig files into HOMEBREW_PREFIX so they're accessible.
    (lib/"pkgconfig").install_symlink Dir["#{frameworks}/Python.framework/Versions/#{version.major_minor}/lib/pkgconfig/*"]

    # Remove the site-packages that Python created in its Cellar.
    site_packages_cellar.rmtree

    # Prepare a wheel of wheel to install later.
    common_pip_args = %w[
      -v
      --no-deps
      --no-binary :all:
      --no-index
      --no-build-isolation
    ]
    whl_build = buildpath/"whl_build"
    system bin/"python3", "-m", "venv", whl_build
    resource("wheel").stage do
      system whl_build/"bin/pip3", "install", *common_pip_args, "."
      system whl_build/"bin/pip3", "wheel", *common_pip_args,
                                            "--wheel-dir=#{libexec}",
                                            "."
    end

    # Replace bundled setuptools/pip with our own.
    rm Dir["#{lib_cellar}/ensurepip/_bundled/{setuptools,pip}-*.whl"]
    %w[setuptools pip].each do |r|
      resource(r).stage do
        system whl_build/"bin/pip3", "wheel", *common_pip_args,
                                              "--wheel-dir=#{lib_cellar}/ensurepip/_bundled",
                                              "."
      end
    end

    # Patch ensurepip to bootstrap our updated versions of setuptools/pip
    inreplace lib_cellar/"ensurepip/__init__.py" do |s|
      s.gsub!(/_SETUPTOOLS_VERSION = .*/, "_SETUPTOOLS_VERSION = \"#{resource("setuptools").version}\"")
      s.gsub!(/_PIP_VERSION = .*/, "_PIP_VERSION = \"#{resource("pip").version}\"")
    end

    # Write out sitecustomize.py
    (lib_cellar/"sitecustomize.py").atomic_write(sitecustomize)

    # Install unversioned symlinks in libexec/bin.
    {
      "idle"          => "idle3",
      "pydoc"         => "pydoc3",
      "python"        => "python3",
      "python-config" => "python3-config",
    }.each do |unversioned_name, versioned_name|
      (libexec/"bin").install_symlink (bin/versioned_name).realpath => unversioned_name
    end
  end

  def post_install
    ENV.delete "PYTHONPATH"

    # Fix up the site-packages so that user-installed Python software survives
    # minor updates, such as going from 3.3.2 to 3.3.3:

    # Create a site-packages in HOMEBREW_PREFIX/lib/python#{version.major_minor}/site-packages
    site_packages.mkpath

    # Symlink the prefix site-packages into the cellar.
    site_packages_cellar.unlink if site_packages_cellar.exist?
    site_packages_cellar.parent.install_symlink site_packages

    # Remove old sitecustomize.py. Now stored in the cellar.
    rm_rf Dir["#{site_packages}/sitecustomize.py[co]"]

    # Remove old setuptools installations that may still fly around and be
    # listed in the easy_install.pth. This can break setuptools build with
    # zipimport.ZipImportError: bad local file header
    # setuptools-0.9.8-py3.3.egg
    rm_rf Dir["#{site_packages}/setuptools[-_.][0-9]*", "#{site_packages}/setuptools"]
    rm_rf Dir["#{site_packages}/distribute[-_.][0-9]*", "#{site_packages}/distribute"]
    rm_rf Dir["#{site_packages}/pip[-_.][0-9]*", "#{site_packages}/pip"]
    rm_rf Dir["#{site_packages}/wheel[-_.][0-9]*", "#{site_packages}/wheel"]

    system bin/"python3", "-m", "ensurepip"

    # Install desired versions of setuptools, pip, wheel using the version of
    # pip bootstrapped by ensurepip.
    # Note that while we replaced the ensurepip wheels, there's no guarantee
    # ensurepip actually used them, since other existing installations could
    # have been picked up (and we can't pass --ignore-installed).
    bundled = lib_cellar/"ensurepip/_bundled"
    system bin/"python3", "-m", "pip", "install", "-v",
            "--no-deps",
            "--no-index",
            "--upgrade",
            "--isolated",
            "--target=#{site_packages}",
            bundled/"setuptools-#{resource("setuptools").version}-py3-none-any.whl",
            bundled/"pip-#{resource("pip").version}-py3-none-any.whl",
            libexec/"wheel-#{resource("wheel").version}-py2.py3-none-any.whl"

    # pip install with --target flag will just place the bin folder into the
    # target, so move its contents into the appropriate location
    mv (site_packages/"bin").children, bin
    rmdir site_packages/"bin"

    rm_rf bin/"pip"
    mv bin/"wheel", bin/"wheel3"

    # Install unversioned symlinks in libexec/bin.
    {
      "pip"   => "pip3",
      "wheel" => "wheel3",
    }.each do |unversioned_name, versioned_name|
      (libexec/"bin").install_symlink (bin/versioned_name).realpath => unversioned_name
    end

    # post_install happens after link
    %W[python#{version.major_minor}].each do |e|
      (HOMEBREW_PREFIX/"bin").install_symlink bin/e
    end

    # Help distutils find brewed stuff when building extensions
    include_dirs = [HOMEBREW_PREFIX/"include", Formula["openssl@1.1"].opt_include,
                    Formula["sqlite"].opt_include]
    library_dirs = [HOMEBREW_PREFIX/"lib", Formula["openssl@1.1"].opt_lib,
                    Formula["sqlite"].opt_lib]

    cfg = lib_cellar/"distutils/distutils.cfg"

    cfg.atomic_write <<~EOS
      [install]
      prefix=#{HOMEBREW_PREFIX}
      [build_ext]
      include_dirs=#{include_dirs.join ":"}
      library_dirs=#{library_dirs.join ":"}
    EOS
  end

  def sitecustomize
    <<~EOS
      # This file is created by Homebrew and is executed on each python startup.
      # Don't print from here, or else python command line scripts may fail!
      # <https://docs.brew.sh/Homebrew-and-Python>
      import re
      import os
      import sys
      if sys.version_info[:2] != (#{version.major}, #{version.minor}):
          # This can only happen if the user has set the PYTHONPATH to a mismatching site-packages directory.
          # Every Python looks at the PYTHONPATH variable and we can't fix it here in sitecustomize.py,
          # because the PYTHONPATH is evaluated after the sitecustomize.py. Many modules (e.g. PyQt4) are
          # built only for a specific version of Python and will fail with cryptic error messages.
          # In the end this means: Don't set the PYTHONPATH permanently if you use different Python versions.
          exit('Your PYTHONPATH points to a site-packages dir for Python #{version.major_minor} but you are running Python ' +
                str(sys.version_info[0]) + '.' + str(sys.version_info[1]) + '!\\n     PYTHONPATH is currently: "' + str(os.environ['PYTHONPATH']) + '"\\n' +
                '     You should `unset PYTHONPATH` to fix this.')
      # Only do this for a brewed python:
      if os.path.realpath(sys.executable).startswith('#{rack}'):
          # Shuffle /Library site-packages to the end of sys.path
          library_site = '/Library/Python/#{version.major_minor}/site-packages'
          library_packages = [p for p in sys.path if p.startswith(library_site)]
          sys.path = [p for p in sys.path if not p.startswith(library_site)]
          # .pth files have already been processed so don't use addsitedir
          sys.path.extend(library_packages)
          # the Cellar site-packages is a symlink to the HOMEBREW_PREFIX
          # site_packages; prefer the shorter paths
          long_prefix = re.compile(r'#{rack}/[0-9\._abrc]+/Frameworks/Python\.framework/Versions/#{version.major_minor}/lib/python#{version.major_minor}/site-packages')
          sys.path = [long_prefix.sub('#{HOMEBREW_PREFIX/"lib/python#{version.major_minor}/site-packages"}', p) for p in sys.path]
          # Set the sys.executable to use the opt_prefix. Only do this if PYTHONEXECUTABLE is not
          # explicitly set and we are not in a virtualenv:
          if 'PYTHONEXECUTABLE' not in os.environ and sys.prefix == sys.base_prefix:
              sys.executable = sys._base_executable = '#{opt_bin}/python#{version.major_minor}'
      if 'PYTHONHOME' not in os.environ:
          cellar_prefix = re.compile(r'#{rack}/[0-9\._abrc]+/')
          if os.path.realpath(sys.base_prefix).startswith('#{rack}'):
              new_prefix = cellar_prefix.sub('#{opt_prefix}/', sys.base_prefix)
              if sys.prefix == sys.base_prefix:
                  sys.prefix = new_prefix
              sys.base_prefix = new_prefix
          if os.path.realpath(sys.base_exec_prefix).startswith('#{rack}'):
              new_exec_prefix = cellar_prefix.sub('#{opt_prefix}/', sys.base_exec_prefix)
              if sys.exec_prefix == sys.base_exec_prefix:
                  sys.exec_prefix = new_exec_prefix
              sys.base_exec_prefix = new_exec_prefix
      # Check for and add the python-tk prefix.
      tkinter_prefix = "#{HOMEBREW_PREFIX}/opt/python-tk@#{version.major_minor}/libexec"
      if os.path.isdir(tkinter_prefix):
          sys.path.append(tkinter_prefix)
    EOS
  end

  def caveats
    <<~EOS
      Python has been installed as
        #{opt_bin}/python3

      Unversioned symlinks `python`, `python-config`, `pip` etc. pointing to
      `python3`, `python3-config`, `pip3` etc., respectively, have been installed into
        #{opt_libexec}/bin

      You can install Python packages with
        #{opt_bin}/pip3 install <package>
      They will install into the site-package directory
        #{HOMEBREW_PREFIX/"lib/python#{version.major_minor}/site-packages"}

      tkinter is no longer included with this formula

      See: https://docs.brew.sh/Homebrew-and-Python
    EOS
  end

  test do
    # Check if sqlite is ok, because we build with --enable-loadable-sqlite-extensions
    # and it can occur that building sqlite silently fails if OSX's sqlite is used.
    system "#{bin}/python#{version.major_minor}", "-c", "import sqlite3"

    # check to see if we can create a venv
    system "#{bin}/python#{version.major_minor}", "-m", "venv", testpath/"myvenv"

    # Check if some other modules import. Then the linked libs are working.
    system "#{bin}/python#{version.major_minor}", "-c", "import _ctypes"
    system "#{bin}/python#{version.major_minor}", "-c", "import _decimal"
    system "#{bin}/python#{version.major_minor}", "-c", "import _gdbm"
    system "#{bin}/python#{version.major_minor}", "-c", "import pyexpat"
    system "#{bin}/python#{version.major_minor}", "-c", "import zlib"

    # tkinter is provided in a separate formula
    assert_match "ModuleNotFoundError: No module named '_tkinter'",
                  shell_output("#{bin}/python#{version.major_minor} -Sc 'import tkinter' 2>&1", 1)

    # Verify that the selected DBM interface works
    (testpath/"dbm_test.py").write <<~EOS
      import dbm

      with dbm.ndbm.open("test", "c") as db:
          db[b"foo \\xbd"] = b"bar \\xbd"
      with dbm.ndbm.open("test", "r") as db:
          assert list(db.keys()) == [b"foo \\xbd"]
          assert b"foo \\xbd" in db
          assert db[b"foo \\xbd"] == b"bar \\xbd"
    EOS
    system "#{bin}/python#{version.major_minor}", "dbm_test.py"

    system bin/"pip3", "list", "--format=columns"
  end
end

__END__
diff --git a/Doc/c-api/init_config.rst b/Doc/c-api/init_config.rst
index bab5313dd9ec7..e4dec19ce3432 100644
--- a/Doc/c-api/init_config.rst
+++ b/Doc/c-api/init_config.rst
@@ -243,15 +243,28 @@ PyPreConfig
       * ``PYMEM_ALLOCATOR_PYMALLOC_DEBUG`` (``6``): :ref:`Python pymalloc
         memory allocator <pymalloc>` with :ref:`debug hooks
         <pymem-debug-hooks>`.
+      * ``PYMEM_ALLOCATOR_MIMALLOC`` (``7``): :ref:`mimalloc
+        memory allocator <mimalloc>`.
+      * ``PYMEM_ALLOCATOR_MIMALLOC_DEBUG`` (``8``): :ref:`mimalloc
+        memory allocator <mimalloc>` with :ref:`debug hooks
+        <pymem-debug-hooks>`.
 
       ``PYMEM_ALLOCATOR_PYMALLOC`` and ``PYMEM_ALLOCATOR_PYMALLOC_DEBUG`` are
       not supported if Python is :option:`configured using --without-pymalloc
       <--without-pymalloc>`.
 
+      ``PYMEM_ALLOCATOR_MIMALLOC`` and ``PYMEM_ALLOCATOR_MIMALLOC_DEBUG`` are
+      not supported unless Python is :option:`configured using --with-mimalloc
+      <--with-mimalloc>`.
+
       See :ref:`Memory Management <memory>`.
 
       Default: ``PYMEM_ALLOCATOR_NOT_SET``.
 
+      .. versionchanged:: 3.11
+         Added ``PYMEM_ALLOCATOR_MIMALLOC`` and
+         ``PYMEM_ALLOCATOR_MIMALLOC_DEBUG``.
+
    .. c:member:: int configure_locale
 
       Set the LC_CTYPE locale to the user preferred locale?
diff --git a/Doc/c-api/memory.rst b/Doc/c-api/memory.rst
index e81a246cb75cc..cd3322c5f9650 100644
--- a/Doc/c-api/memory.rst
+++ b/Doc/c-api/memory.rst
@@ -377,10 +377,12 @@ Default memory allocators:
 ===============================  ====================  ==================  =====================  ====================
 Configuration                    Name                  PyMem_RawMalloc     PyMem_Malloc           PyObject_Malloc
 ===============================  ====================  ==================  =====================  ====================
-Release build                    ``"pymalloc"``        ``malloc``          ``pymalloc``           ``pymalloc``
-Debug build                      ``"pymalloc_debug"``  ``malloc`` + debug  ``pymalloc`` + debug   ``pymalloc`` + debug
-Release build, without pymalloc  ``"malloc"``          ``malloc``          ``malloc``             ``malloc``
-Debug build, without pymalloc    ``"malloc_debug"``    ``malloc`` + debug  ``malloc`` + debug     ``malloc`` + debug
+Release build, with mimalloc     ``"mimalloc"``        ``mimalloc``        ``mimalloc``           ``mimalloc``
+Debug build, with mimalloc       ``"mimalloc_debug"``  ``malloc`` + debug  ``mimalloc`` + debug   ``mimalloc`` + debug
+Release build, without mimalloc  ``"pymalloc"``        ``malloc``          ``pymalloc``           ``pymalloc``
+Debug build, without mimalloc    ``"pymalloc_debug"``  ``malloc`` + debug  ``pymalloc`` + debug   ``pymalloc`` + debug
+Release build, without both      ``"malloc"``          ``malloc``          ``malloc``             ``malloc``
+Debug build, without both        ``"malloc_debug"``    ``malloc`` + debug  ``malloc`` + debug     ``malloc`` + debug
 ===============================  ====================  ==================  =====================  ====================
 
 Legend:
@@ -389,6 +391,7 @@ Legend:
 * ``malloc``: system allocators from the standard C library, C functions:
   :c:func:`malloc`, :c:func:`calloc`, :c:func:`realloc` and :c:func:`free`.
 * ``pymalloc``: :ref:`pymalloc memory allocator <pymalloc>`.
+* ``mimalloc``: :ref:`mimalloc memory allocator <mimalloc>`.
 * "+ debug": with :ref:`debug hooks on the Python memory allocators
   <pymem-debug-hooks>`.
 * "Debug build": :ref:`Python build in debug mode <debug-build>`.
@@ -643,6 +646,21 @@ Customize pymalloc Arena Allocator
    Set the arena allocator.
 
 
+.. _mimalloc:
+
+The mimalloc allocator
+======================
+
+`mimalloc (pronounced "me-malloc") <https://github.com/microsoft/mimalloc>`_
+is a general purpose allocator with excellent performance characteristics.
+
+This allocator is disabled by default unless Python is configured with the
+:option:`--with-mimalloc` option. It can also be disabled at runtime using
+the :envvar:`PYTHONMALLOC` environment variable (ex: ``PYTHONMALLOC=malloc``).
+If Python is configured with both :ref:`pymalloc <pymalloc>` and mimalloc, then
+mimalloc is preferred.
+
+
 tracemalloc C API
 =================
 
diff --git a/Doc/using/cmdline.rst b/Doc/using/cmdline.rst
index d341ea8bb43c8..861c526f8b98b 100644
--- a/Doc/using/cmdline.rst
+++ b/Doc/using/cmdline.rst
@@ -817,6 +817,10 @@ conflict.
    * ``pymalloc``: use the :ref:`pymalloc allocator <pymalloc>` for
      :c:data:`PYMEM_DOMAIN_MEM` and :c:data:`PYMEM_DOMAIN_OBJ` domains and use
      the :c:func:`malloc` function for the :c:data:`PYMEM_DOMAIN_RAW` domain.
+   * ``mimalloc``: use the :ref:`mimalloc allocator <mimalloc>` for
+     all domains (in debug mode :c:data:`PYMEM_DOMAIN_RAW` uses :c:func:`malloc`
+     function).
+
 
    Install :ref:`debug hooks <pymem-debug-hooks>`:
 
@@ -824,6 +828,10 @@ conflict.
      allocators <default-memory-allocators>`.
    * ``malloc_debug``: same as ``malloc`` but also install debug hooks.
    * ``pymalloc_debug``: same as ``pymalloc`` but also install debug hooks.
+   * ``mimalloc_debug``: same as ``mimalloc`` but also install debug hooks.
+
+   .. versionchanged:: 3.11
+      Added the ``"mimalloc"`` and ``"mimalloc_debug"`` allocators
 
    .. versionchanged:: 3.7
       Added the ``"default"`` allocator.
diff --git a/Doc/using/configure.rst b/Doc/using/configure.rst
index b46157cc6ad59..74183c29a68e0 100644
--- a/Doc/using/configure.rst
+++ b/Doc/using/configure.rst
@@ -243,6 +243,30 @@ recommended for best performance.
 
    See also :envvar:`PYTHONMALLOC` environment variable.
 
+.. cmdoption:: --with-mimalloc
+
+   Enable :ref:`mimalloc <mimalloc>` memory allocator. mimalloc is enabled
+   by default when compiler and platform provide C11 ``stdatomic.h``.
+
+   See also :envvar:`PYTHONMALLOC` environment variable.
+
+   .. versionadded:: 3.11
+
+.. cmdoption:: --enable-mimalloc-secure[=yes|no|1|2|3|4]
+
+   Enable mimalloc's secure mode and various mitigations against exploits.
+   Secure mode comes with small performance penalty and uses additional
+   memory for guard pages. Each level includes the previous levels. *yes*
+   enables the highest security level.
+
+   * *1* enables guard pages around metadata
+   * *2* enables guard pages around mimalloc page
+   * *3* enables encoded free lists and detects corrupted free lists as
+     well as invalid pointer frees.
+   * *4* enables expensive checks for double free.
+
+   .. versionadded:: 3.11
+
 .. cmdoption:: --without-doc-strings
 
    Disable static documentation strings to reduce the memory footprint (enabled
diff --git a/Include/cpython/pymem.h b/Include/cpython/pymem.h
index d1054d76520b9..05b52f5842dbe 100644
--- a/Include/cpython/pymem.h
+++ b/Include/cpython/pymem.h
@@ -41,6 +41,10 @@ typedef enum {
     PYMEM_ALLOCATOR_PYMALLOC = 5,
     PYMEM_ALLOCATOR_PYMALLOC_DEBUG = 6,
 #endif
+#ifdef WITH_MIMALLOC
+    PYMEM_ALLOCATOR_MIMALLOC = 7,
+    PYMEM_ALLOCATOR_MIMALLOC_DEBUG = 8,
+#endif
 } PyMemAllocatorName;
 
 
diff --git a/Include/internal/mimalloc/mimalloc-atomic.h b/Include/internal/mimalloc/mimalloc-atomic.h
new file mode 100644
index 0000000000000..e07df84d6931a
--- /dev/null
+++ b/Include/internal/mimalloc/mimalloc-atomic.h
@@ -0,0 +1,332 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2021 Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+#pragma once
+#ifndef MIMALLOC_ATOMIC_H
+#define MIMALLOC_ATOMIC_H
+
+// --------------------------------------------------------------------------------------------
+// Atomics
+// We need to be portable between C, C++, and MSVC.
+// We base the primitives on the C/C++ atomics and create a mimimal wrapper for MSVC in C compilation mode. 
+// This is why we try to use only `uintptr_t` and `<type>*` as atomic types. 
+// To gain better insight in the range of used atomics, we use explicitly named memory order operations 
+// instead of passing the memory order as a parameter.
+// -----------------------------------------------------------------------------------------------
+
+#if defined(__cplusplus)
+// Use C++ atomics
+#include <atomic>
+#define  _Atomic(tp)            std::atomic<tp>
+#define  mi_atomic(name)        std::atomic_##name
+#define  mi_memory_order(name)  std::memory_order_##name
+#elif defined(_MSC_VER)
+// Use MSVC C wrapper for C11 atomics
+#define  _Atomic(tp)            tp 
+#define  ATOMIC_VAR_INIT(x)     x
+#define  mi_atomic(name)        mi_atomic_##name
+#define  mi_memory_order(name)  mi_memory_order_##name
+#else
+// Use C11 atomics
+#include <stdatomic.h>
+#define  mi_atomic(name)        atomic_##name
+#define  mi_memory_order(name)  memory_order_##name
+#endif
+
+// Various defines for all used memory orders in mimalloc
+#define mi_atomic_cas_weak(p,expected,desired,mem_success,mem_fail)  \
+  mi_atomic(compare_exchange_weak_explicit)(p,expected,desired,mem_success,mem_fail)
+
+#define mi_atomic_cas_strong(p,expected,desired,mem_success,mem_fail)  \
+  mi_atomic(compare_exchange_strong_explicit)(p,expected,desired,mem_success,mem_fail)
+
+#define mi_atomic_load_acquire(p)                mi_atomic(load_explicit)(p,mi_memory_order(acquire))
+#define mi_atomic_load_relaxed(p)                mi_atomic(load_explicit)(p,mi_memory_order(relaxed))
+#define mi_atomic_store_release(p,x)             mi_atomic(store_explicit)(p,x,mi_memory_order(release))
+#define mi_atomic_store_relaxed(p,x)             mi_atomic(store_explicit)(p,x,mi_memory_order(relaxed))
+#define mi_atomic_exchange_release(p,x)          mi_atomic(exchange_explicit)(p,x,mi_memory_order(release))
+#define mi_atomic_exchange_acq_rel(p,x)          mi_atomic(exchange_explicit)(p,x,mi_memory_order(acq_rel))
+#define mi_atomic_cas_weak_release(p,exp,des)    mi_atomic_cas_weak(p,exp,des,mi_memory_order(release),mi_memory_order(relaxed))
+#define mi_atomic_cas_weak_acq_rel(p,exp,des)    mi_atomic_cas_weak(p,exp,des,mi_memory_order(acq_rel),mi_memory_order(acquire))
+#define mi_atomic_cas_strong_release(p,exp,des)  mi_atomic_cas_strong(p,exp,des,mi_memory_order(release),mi_memory_order(relaxed))
+#define mi_atomic_cas_strong_acq_rel(p,exp,des)  mi_atomic_cas_strong(p,exp,des,mi_memory_order(acq_rel),mi_memory_order(acquire))
+
+#define mi_atomic_add_relaxed(p,x)               mi_atomic(fetch_add_explicit)(p,x,mi_memory_order(relaxed))
+#define mi_atomic_sub_relaxed(p,x)               mi_atomic(fetch_sub_explicit)(p,x,mi_memory_order(relaxed))
+#define mi_atomic_add_acq_rel(p,x)               mi_atomic(fetch_add_explicit)(p,x,mi_memory_order(acq_rel))
+#define mi_atomic_sub_acq_rel(p,x)               mi_atomic(fetch_sub_explicit)(p,x,mi_memory_order(acq_rel))
+#define mi_atomic_and_acq_rel(p,x)               mi_atomic(fetch_and_explicit)(p,x,mi_memory_order(acq_rel))
+#define mi_atomic_or_acq_rel(p,x)                mi_atomic(fetch_or_explicit)(p,x,mi_memory_order(acq_rel))
+
+#define mi_atomic_increment_relaxed(p)           mi_atomic_add_relaxed(p,(uintptr_t)1)
+#define mi_atomic_decrement_relaxed(p)           mi_atomic_sub_relaxed(p,(uintptr_t)1)
+#define mi_atomic_increment_acq_rel(p)           mi_atomic_add_acq_rel(p,(uintptr_t)1)
+#define mi_atomic_decrement_acq_rel(p)           mi_atomic_sub_acq_rel(p,(uintptr_t)1)
+
+static inline void mi_atomic_yield(void);
+static inline intptr_t mi_atomic_addi(_Atomic(intptr_t)*p, intptr_t add);
+static inline intptr_t mi_atomic_subi(_Atomic(intptr_t)*p, intptr_t sub);
+
+
+#if defined(__cplusplus) || !defined(_MSC_VER)
+
+// In C++/C11 atomics we have polymorphic atomics so can use the typed `ptr` variants (where `tp` is the type of atomic value)
+// We use these macros so we can provide a typed wrapper in MSVC in C compilation mode as well
+#define mi_atomic_load_ptr_acquire(tp,p)                mi_atomic_load_acquire(p)
+#define mi_atomic_load_ptr_relaxed(tp,p)                mi_atomic_load_relaxed(p)
+
+// In C++ we need to add casts to help resolve templates if NULL is passed
+#if defined(__cplusplus)
+#define mi_atomic_store_ptr_release(tp,p,x)             mi_atomic_store_release(p,(tp*)x)
+#define mi_atomic_store_ptr_relaxed(tp,p,x)             mi_atomic_store_relaxed(p,(tp*)x)
+#define mi_atomic_cas_ptr_weak_release(tp,p,exp,des)    mi_atomic_cas_weak_release(p,exp,(tp*)des)
+#define mi_atomic_cas_ptr_weak_acq_rel(tp,p,exp,des)    mi_atomic_cas_weak_acq_rel(p,exp,(tp*)des)
+#define mi_atomic_cas_ptr_strong_release(tp,p,exp,des)  mi_atomic_cas_strong_release(p,exp,(tp*)des)
+#define mi_atomic_exchange_ptr_release(tp,p,x)          mi_atomic_exchange_release(p,(tp*)x)
+#define mi_atomic_exchange_ptr_acq_rel(tp,p,x)          mi_atomic_exchange_acq_rel(p,(tp*)x)
+#else
+#define mi_atomic_store_ptr_release(tp,p,x)             mi_atomic_store_release(p,x)
+#define mi_atomic_store_ptr_relaxed(tp,p,x)             mi_atomic_store_relaxed(p,x)
+#define mi_atomic_cas_ptr_weak_release(tp,p,exp,des)    mi_atomic_cas_weak_release(p,exp,des)
+#define mi_atomic_cas_ptr_weak_acq_rel(tp,p,exp,des)    mi_atomic_cas_weak_acq_rel(p,exp,des)
+#define mi_atomic_cas_ptr_strong_release(tp,p,exp,des)  mi_atomic_cas_strong_release(p,exp,des)
+#define mi_atomic_exchange_ptr_release(tp,p,x)          mi_atomic_exchange_release(p,x)
+#define mi_atomic_exchange_ptr_acq_rel(tp,p,x)          mi_atomic_exchange_acq_rel(p,x)
+#endif
+
+// These are used by the statistics
+static inline int64_t mi_atomic_addi64_relaxed(volatile int64_t* p, int64_t add) {
+  return mi_atomic(fetch_add_explicit)((_Atomic(int64_t)*)p, add, mi_memory_order(relaxed));
+}
+static inline void mi_atomic_maxi64_relaxed(volatile int64_t* p, int64_t x) {
+  int64_t current = mi_atomic_load_relaxed((_Atomic(int64_t)*)p);
+  while (current < x && !mi_atomic_cas_weak_release((_Atomic(int64_t)*)p, &current, x)) { /* nothing */ };
+}
+
+// Used by timers
+#define mi_atomic_loadi64_acquire(p)    mi_atomic(load_explicit)(p,mi_memory_order(acquire))
+#define mi_atomic_loadi64_relaxed(p)    mi_atomic(load_explicit)(p,mi_memory_order(relaxed))
+#define mi_atomic_storei64_release(p,x) mi_atomic(store_explicit)(p,x,mi_memory_order(release))
+#define mi_atomic_storei64_relaxed(p,x) mi_atomic(store_explicit)(p,x,mi_memory_order(relaxed))
+
+
+
+#elif defined(_MSC_VER)
+
+// MSVC C compilation wrapper that uses Interlocked operations to model C11 atomics.
+#define WIN32_LEAN_AND_MEAN
+#include <windows.h>
+#include <intrin.h>
+#ifdef _WIN64
+typedef LONG64   msc_intptr_t;
+#define MI_64(f) f##64
+#else
+typedef LONG     msc_intptr_t;
+#define MI_64(f) f
+#endif
+
+typedef enum mi_memory_order_e {
+  mi_memory_order_relaxed,
+  mi_memory_order_consume,
+  mi_memory_order_acquire,
+  mi_memory_order_release,
+  mi_memory_order_acq_rel,
+  mi_memory_order_seq_cst
+} mi_memory_order;
+
+static inline uintptr_t mi_atomic_fetch_add_explicit(_Atomic(uintptr_t)*p, uintptr_t add, mi_memory_order mo) {
+  (void)(mo);
+  return (uintptr_t)MI_64(_InterlockedExchangeAdd)((volatile msc_intptr_t*)p, (msc_intptr_t)add);
+}
+static inline uintptr_t mi_atomic_fetch_sub_explicit(_Atomic(uintptr_t)*p, uintptr_t sub, mi_memory_order mo) {
+  (void)(mo);
+  return (uintptr_t)MI_64(_InterlockedExchangeAdd)((volatile msc_intptr_t*)p, -((msc_intptr_t)sub));
+}
+static inline uintptr_t mi_atomic_fetch_and_explicit(_Atomic(uintptr_t)*p, uintptr_t x, mi_memory_order mo) {
+  (void)(mo);
+  return (uintptr_t)MI_64(_InterlockedAnd)((volatile msc_intptr_t*)p, (msc_intptr_t)x);
+}
+static inline uintptr_t mi_atomic_fetch_or_explicit(_Atomic(uintptr_t)*p, uintptr_t x, mi_memory_order mo) {
+  (void)(mo);
+  return (uintptr_t)MI_64(_InterlockedOr)((volatile msc_intptr_t*)p, (msc_intptr_t)x);
+}
+static inline bool mi_atomic_compare_exchange_strong_explicit(_Atomic(uintptr_t)*p, uintptr_t* expected, uintptr_t desired, mi_memory_order mo1, mi_memory_order mo2) {
+  (void)(mo1); (void)(mo2);
+  uintptr_t read = (uintptr_t)MI_64(_InterlockedCompareExchange)((volatile msc_intptr_t*)p, (msc_intptr_t)desired, (msc_intptr_t)(*expected));
+  if (read == *expected) {
+    return true;
+  }
+  else {
+    *expected = read;
+    return false;
+  }
+}
+static inline bool mi_atomic_compare_exchange_weak_explicit(_Atomic(uintptr_t)*p, uintptr_t* expected, uintptr_t desired, mi_memory_order mo1, mi_memory_order mo2) {
+  return mi_atomic_compare_exchange_strong_explicit(p, expected, desired, mo1, mo2);
+}
+static inline uintptr_t mi_atomic_exchange_explicit(_Atomic(uintptr_t)*p, uintptr_t exchange, mi_memory_order mo) {
+  (void)(mo);
+  return (uintptr_t)MI_64(_InterlockedExchange)((volatile msc_intptr_t*)p, (msc_intptr_t)exchange);
+}
+static inline void mi_atomic_thread_fence(mi_memory_order mo) {
+  (void)(mo);
+  _Atomic(uintptr_t) x = 0;
+  mi_atomic_exchange_explicit(&x, 1, mo);
+}
+static inline uintptr_t mi_atomic_load_explicit(_Atomic(uintptr_t) const* p, mi_memory_order mo) {
+  (void)(mo);
+#if defined(_M_IX86) || defined(_M_X64)
+  return *p;
+#else
+  uintptr_t x = *p;
+  if (mo > mi_memory_order_relaxed) {
+    while (!mi_atomic_compare_exchange_weak_explicit(p, &x, x, mo, mi_memory_order_relaxed)) { /* nothing */ };
+  }
+  return x;
+#endif
+}
+static inline void mi_atomic_store_explicit(_Atomic(uintptr_t)*p, uintptr_t x, mi_memory_order mo) {
+  (void)(mo);
+#if defined(_M_IX86) || defined(_M_X64)
+  *p = x;
+#else
+  mi_atomic_exchange_explicit(p, x, mo);
+#endif
+}
+static inline int64_t mi_atomic_loadi64_explicit(_Atomic(int64_t)*p, mi_memory_order mo) {
+  (void)(mo);
+#if defined(_M_X64)
+  return *p;
+#else
+  int64_t old = *p;
+  int64_t x = old;
+  while ((old = InterlockedCompareExchange64(p, x, old)) != x) {
+    x = old;
+  }
+  return x;
+#endif
+}
+static inline void mi_atomic_storei64_explicit(_Atomic(int64_t)*p, int64_t x, mi_memory_order mo) {
+  (void)(mo);
+#if defined(x_M_IX86) || defined(_M_X64)
+  *p = x;
+#else
+  InterlockedExchange64(p, x);
+#endif
+}
+
+// These are used by the statistics
+static inline int64_t mi_atomic_addi64_relaxed(volatile _Atomic(int64_t)*p, int64_t add) {
+#ifdef _WIN64
+  return (int64_t)mi_atomic_addi((int64_t*)p, add);
+#else
+  int64_t current;
+  int64_t sum;
+  do {
+    current = *p;
+    sum = current + add;
+  } while (_InterlockedCompareExchange64(p, sum, current) != current);
+  return current;
+#endif
+}
+static inline void mi_atomic_maxi64_relaxed(volatile _Atomic(int64_t)*p, int64_t x) {
+  int64_t current;
+  do {
+    current = *p;
+  } while (current < x && _InterlockedCompareExchange64(p, x, current) != current);
+}
+
+// The pointer macros cast to `uintptr_t`.
+#define mi_atomic_load_ptr_acquire(tp,p)                (tp*)mi_atomic_load_acquire((_Atomic(uintptr_t)*)(p))
+#define mi_atomic_load_ptr_relaxed(tp,p)                (tp*)mi_atomic_load_relaxed((_Atomic(uintptr_t)*)(p))
+#define mi_atomic_store_ptr_release(tp,p,x)             mi_atomic_store_release((_Atomic(uintptr_t)*)(p),(uintptr_t)(x))
+#define mi_atomic_store_ptr_relaxed(tp,p,x)             mi_atomic_store_relaxed((_Atomic(uintptr_t)*)(p),(uintptr_t)(x))
+#define mi_atomic_cas_ptr_weak_release(tp,p,exp,des)    mi_atomic_cas_weak_release((_Atomic(uintptr_t)*)(p),(uintptr_t*)exp,(uintptr_t)des)
+#define mi_atomic_cas_ptr_weak_acq_rel(tp,p,exp,des)    mi_atomic_cas_weak_acq_rel((_Atomic(uintptr_t)*)(p),(uintptr_t*)exp,(uintptr_t)des)
+#define mi_atomic_cas_ptr_strong_release(tp,p,exp,des)  mi_atomic_cas_strong_release((_Atomic(uintptr_t)*)(p),(uintptr_t*)exp,(uintptr_t)des)
+#define mi_atomic_exchange_ptr_release(tp,p,x)          (tp*)mi_atomic_exchange_release((_Atomic(uintptr_t)*)(p),(uintptr_t)x)
+#define mi_atomic_exchange_ptr_acq_rel(tp,p,x)          (tp*)mi_atomic_exchange_acq_rel((_Atomic(uintptr_t)*)(p),(uintptr_t)x)
+
+#define mi_atomic_loadi64_acquire(p)    mi_atomic(loadi64_explicit)(p,mi_memory_order(acquire))
+#define mi_atomic_loadi64_relaxed(p)    mi_atomic(loadi64_explicit)(p,mi_memory_order(relaxed))
+#define mi_atomic_storei64_release(p,x) mi_atomic(storei64_explicit)(p,x,mi_memory_order(release))
+#define mi_atomic_storei64_relaxed(p,x) mi_atomic(storei64_explicit)(p,x,mi_memory_order(relaxed))
+
+
+#endif
+
+
+// Atomically add a signed value; returns the previous value.
+static inline intptr_t mi_atomic_addi(_Atomic(intptr_t)*p, intptr_t add) {
+  return (intptr_t)mi_atomic_add_acq_rel((_Atomic(uintptr_t)*)p, (uintptr_t)add);
+}
+
+// Atomically subtract a signed value; returns the previous value.
+static inline intptr_t mi_atomic_subi(_Atomic(intptr_t)*p, intptr_t sub) {
+  return (intptr_t)mi_atomic_addi(p, -sub);
+}
+
+// Yield 
+#if defined(__cplusplus)
+#include <thread>
+static inline void mi_atomic_yield(void) {
+  std::this_thread::yield();
+}
+#elif defined(_WIN32)
+#define WIN32_LEAN_AND_MEAN
+#include <windows.h>
+static inline void mi_atomic_yield(void) {
+  YieldProcessor();
+}
+#elif defined(__SSE2__)
+#include <emmintrin.h>
+static inline void mi_atomic_yield(void) {
+  _mm_pause();
+}
+#elif (defined(__GNUC__) || defined(__clang__)) && \
+      (defined(__x86_64__) || defined(__i386__) || defined(__arm__) || defined(__armel__) || defined(__ARMEL__) || \
+       defined(__aarch64__) || defined(__powerpc__) || defined(__ppc__) || defined(__PPC__))
+#if defined(__x86_64__) || defined(__i386__)
+static inline void mi_atomic_yield(void) {
+  __asm__ volatile ("pause" ::: "memory");
+}
+#elif defined(__aarch64__)
+static inline void mi_atomic_yield(void) {
+  __asm__ volatile("wfe");
+}
+#elif (defined(__arm__) && __ARM_ARCH__ >= 7)
+static inline void mi_atomic_yield(void) {
+  __asm__ volatile("yield" ::: "memory");
+}
+#elif defined(__powerpc__) || defined(__ppc__) || defined(__PPC__)
+static inline void mi_atomic_yield(void) {
+  __asm__ __volatile__ ("or 27,27,27" ::: "memory");
+}
+#elif defined(__armel__) || defined(__ARMEL__)
+static inline void mi_atomic_yield(void) {
+  __asm__ volatile ("nop" ::: "memory");
+}
+#endif
+#elif defined(__sun)
+// Fallback for other archs
+#include <synch.h>
+static inline void mi_atomic_yield(void) {
+  smt_pause();
+}
+#elif defined(__wasi__)
+#include <sched.h>
+static inline void mi_atomic_yield(void) {
+  sched_yield();
+}
+#else
+#include <unistd.h>
+static inline void mi_atomic_yield(void) {
+  sleep(0);
+}
+#endif
+
+
+#endif // __MIMALLOC_ATOMIC_H
diff --git a/Include/internal/mimalloc/mimalloc-internal.h b/Include/internal/mimalloc/mimalloc-internal.h
new file mode 100644
index 0000000000000..1d0dc53907839
--- /dev/null
+++ b/Include/internal/mimalloc/mimalloc-internal.h
@@ -0,0 +1,1049 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2022, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+#pragma once
+#ifndef MIMALLOC_INTERNAL_H
+#define MIMALLOC_INTERNAL_H
+
+#include "mimalloc-types.h"
+
+#if (MI_DEBUG>0)
+#define mi_trace_message(...)  _mi_trace_message(__VA_ARGS__)
+#else
+#define mi_trace_message(...)
+#endif
+
+#define MI_CACHE_LINE          64
+#if defined(_MSC_VER)
+#pragma warning(disable:4127)   // suppress constant conditional warning (due to MI_SECURE paths)
+#pragma warning(disable:26812)  // unscoped enum warning
+#define mi_decl_noinline        __declspec(noinline)
+#define mi_decl_thread          __declspec(thread)
+#define mi_decl_cache_align     __declspec(align(MI_CACHE_LINE))
+#elif (defined(__GNUC__) && (__GNUC__ >= 3)) || defined(__clang__) // includes clang and icc
+#define mi_decl_noinline        __attribute__((noinline))
+#define mi_decl_thread          __thread
+#define mi_decl_cache_align     __attribute__((aligned(MI_CACHE_LINE)))
+#else
+#define mi_decl_noinline
+#define mi_decl_thread          __thread        // hope for the best :-)
+#define mi_decl_cache_align
+#endif
+
+#if defined(__EMSCRIPTEN__) && !defined(__wasi__)
+#define __wasi__
+#endif
+
+#if defined(__cplusplus)
+#define mi_decl_externc       extern "C"
+#else
+#define mi_decl_externc  
+#endif
+
+#if !defined(_WIN32) && !defined(__wasi__) 
+#define  MI_USE_PTHREADS
+#include <pthread.h>
+#endif
+
+// "options.c"
+void       _mi_fputs(mi_output_fun* out, void* arg, const char* prefix, const char* message);
+void       _mi_fprintf(mi_output_fun* out, void* arg, const char* fmt, ...);
+void       _mi_warning_message(const char* fmt, ...);
+void       _mi_verbose_message(const char* fmt, ...);
+void       _mi_trace_message(const char* fmt, ...);
+void       _mi_options_init(void);
+void       _mi_error_message(int err, const char* fmt, ...);
+
+// random.c
+void       _mi_random_init(mi_random_ctx_t* ctx);
+void       _mi_random_split(mi_random_ctx_t* ctx, mi_random_ctx_t* new_ctx);
+uintptr_t  _mi_random_next(mi_random_ctx_t* ctx);
+uintptr_t  _mi_heap_random_next(mi_heap_t* heap);
+uintptr_t  _mi_os_random_weak(uintptr_t extra_seed);
+static inline uintptr_t _mi_random_shuffle(uintptr_t x);
+
+// init.c
+extern mi_decl_cache_align mi_stats_t       _mi_stats_main;
+extern mi_decl_cache_align const mi_page_t  _mi_page_empty;
+bool       _mi_is_main_thread(void);
+size_t     _mi_current_thread_count(void);
+bool       _mi_preloading(void);  // true while the C runtime is not ready
+
+// os.c
+size_t     _mi_os_page_size(void);
+void       _mi_os_init(void);                                      // called from process init
+void*      _mi_os_alloc(size_t size, mi_stats_t* stats);           // to allocate thread local data
+void       _mi_os_free(void* p, size_t size, mi_stats_t* stats);   // to free thread local data
+
+bool       _mi_os_protect(void* addr, size_t size);
+bool       _mi_os_unprotect(void* addr, size_t size);
+bool       _mi_os_commit(void* addr, size_t size, bool* is_zero, mi_stats_t* stats);
+bool       _mi_os_decommit(void* p, size_t size, mi_stats_t* stats);
+bool       _mi_os_reset(void* p, size_t size, mi_stats_t* stats);
+// bool       _mi_os_unreset(void* p, size_t size, bool* is_zero, mi_stats_t* stats);
+size_t     _mi_os_good_alloc_size(size_t size);
+bool       _mi_os_has_overcommit(void);
+
+// arena.c
+void*      _mi_arena_alloc_aligned(size_t size, size_t alignment, bool* commit, bool* large, bool* is_pinned, bool* is_zero, size_t* memid, mi_os_tld_t* tld);
+void*      _mi_arena_alloc(size_t size, bool* commit, bool* large, bool* is_pinned, bool* is_zero, size_t* memid, mi_os_tld_t* tld);
+void       _mi_arena_free(void* p, size_t size, size_t memid, bool is_committed, mi_os_tld_t* tld);
+
+// "segment-cache.c"
+void*      _mi_segment_cache_pop(size_t size, mi_commit_mask_t* commit_mask, mi_commit_mask_t* decommit_mask, bool* large, bool* is_pinned, bool* is_zero, size_t* memid, mi_os_tld_t* tld);
+bool       _mi_segment_cache_push(void* start, size_t size, size_t memid, const mi_commit_mask_t* commit_mask, const mi_commit_mask_t* decommit_mask, bool is_large, bool is_pinned, mi_os_tld_t* tld);
+void       _mi_segment_cache_collect(bool force, mi_os_tld_t* tld);
+void       _mi_segment_map_allocated_at(const mi_segment_t* segment);
+void       _mi_segment_map_freed_at(const mi_segment_t* segment);
+
+// "segment.c"
+mi_page_t* _mi_segment_page_alloc(mi_heap_t* heap, size_t block_wsize, mi_segments_tld_t* tld, mi_os_tld_t* os_tld);
+void       _mi_segment_page_free(mi_page_t* page, bool force, mi_segments_tld_t* tld);
+void       _mi_segment_page_abandon(mi_page_t* page, mi_segments_tld_t* tld);
+bool       _mi_segment_try_reclaim_abandoned( mi_heap_t* heap, bool try_all, mi_segments_tld_t* tld);
+void       _mi_segment_thread_collect(mi_segments_tld_t* tld);
+void       _mi_segment_huge_page_free(mi_segment_t* segment, mi_page_t* page, mi_block_t* block);
+
+uint8_t*   _mi_segment_page_start(const mi_segment_t* segment, const mi_page_t* page, size_t* page_size); // page start for any page
+void       _mi_abandoned_reclaim_all(mi_heap_t* heap, mi_segments_tld_t* tld);
+void       _mi_abandoned_await_readers(void);
+void       _mi_abandoned_collect(mi_heap_t* heap, bool force, mi_segments_tld_t* tld);
+
+
+
+// "page.c"
+void*      _mi_malloc_generic(mi_heap_t* heap, size_t size)  mi_attr_noexcept mi_attr_malloc;
+
+void       _mi_page_retire(mi_page_t* page) mi_attr_noexcept;                  // free the page if there are no other pages with many free blocks
+void       _mi_page_unfull(mi_page_t* page);
+void       _mi_page_free(mi_page_t* page, mi_page_queue_t* pq, bool force);   // free the page
+void       _mi_page_abandon(mi_page_t* page, mi_page_queue_t* pq);            // abandon the page, to be picked up by another thread...
+void       _mi_heap_delayed_free(mi_heap_t* heap);
+void       _mi_heap_collect_retired(mi_heap_t* heap, bool force);
+
+void       _mi_page_use_delayed_free(mi_page_t* page, mi_delayed_t delay, bool override_never);
+size_t     _mi_page_queue_append(mi_heap_t* heap, mi_page_queue_t* pq, mi_page_queue_t* append);
+void       _mi_deferred_free(mi_heap_t* heap, bool force);
+
+void       _mi_page_free_collect(mi_page_t* page,bool force);
+void       _mi_page_reclaim(mi_heap_t* heap, mi_page_t* page);   // callback from segments
+
+size_t     _mi_bin_size(uint8_t bin);           // for stats
+uint8_t    _mi_bin(size_t size);                // for stats
+
+// "heap.c"
+void       _mi_heap_destroy_pages(mi_heap_t* heap);
+void       _mi_heap_collect_abandon(mi_heap_t* heap);
+void       _mi_heap_set_default_direct(mi_heap_t* heap);
+
+// "stats.c"
+void       _mi_stats_done(mi_stats_t* stats);
+
+mi_msecs_t  _mi_clock_now(void);
+mi_msecs_t  _mi_clock_end(mi_msecs_t start);
+mi_msecs_t  _mi_clock_start(void);
+
+// "alloc.c"
+void*       _mi_page_malloc(mi_heap_t* heap, mi_page_t* page, size_t size) mi_attr_noexcept;  // called from `_mi_malloc_generic`
+void*       _mi_heap_malloc_zero(mi_heap_t* heap, size_t size, bool zero);
+void*       _mi_heap_realloc_zero(mi_heap_t* heap, void* p, size_t newsize, bool zero);
+mi_block_t* _mi_page_ptr_unalign(const mi_segment_t* segment, const mi_page_t* page, const void* p);
+bool        _mi_free_delayed_block(mi_block_t* block);
+void        _mi_block_zero_init(const mi_page_t* page, void* p, size_t size);
+
+#if MI_DEBUG>1
+bool        _mi_page_is_valid(mi_page_t* page);
+#endif
+
+
+// ------------------------------------------------------
+// Branches
+// ------------------------------------------------------
+
+#if defined(__GNUC__) || defined(__clang__)
+#define mi_unlikely(x)     __builtin_expect(!!(x),false)
+#define mi_likely(x)       __builtin_expect(!!(x),true)
+#else
+#define mi_unlikely(x)     (x)
+#define mi_likely(x)       (x)
+#endif
+
+#ifndef __has_builtin
+#define __has_builtin(x)  0
+#endif
+
+
+/* -----------------------------------------------------------
+  Error codes passed to `_mi_fatal_error`
+  All are recoverable but EFAULT is a serious error and aborts by default in secure mode.
+  For portability define undefined error codes using common Unix codes:
+  <https://www-numi.fnal.gov/offline_software/srt_public_context/WebDocs/Errors/unix_system_errors.html>
+----------------------------------------------------------- */
+#include <errno.h>
+#ifndef EAGAIN         // double free
+#define EAGAIN (11)
+#endif
+#ifndef ENOMEM         // out of memory
+#define ENOMEM (12)
+#endif
+#ifndef EFAULT         // corrupted free-list or meta-data
+#define EFAULT (14)
+#endif
+#ifndef EINVAL         // trying to free an invalid pointer
+#define EINVAL (22)
+#endif
+#ifndef EOVERFLOW      // count*size overflow
+#define EOVERFLOW (75)
+#endif
+
+
+/* -----------------------------------------------------------
+  Inlined definitions
+----------------------------------------------------------- */
+#define MI_UNUSED(x)     (void)(x)
+#if (MI_DEBUG>0)
+#define MI_UNUSED_RELEASE(x)
+#else
+#define MI_UNUSED_RELEASE(x)  MI_UNUSED(x)
+#endif
+
+#define MI_INIT4(x)   x(),x(),x(),x()
+#define MI_INIT8(x)   MI_INIT4(x),MI_INIT4(x)
+#define MI_INIT16(x)  MI_INIT8(x),MI_INIT8(x)
+#define MI_INIT32(x)  MI_INIT16(x),MI_INIT16(x)
+#define MI_INIT64(x)  MI_INIT32(x),MI_INIT32(x)
+#define MI_INIT128(x) MI_INIT64(x),MI_INIT64(x)
+#define MI_INIT256(x) MI_INIT128(x),MI_INIT128(x)
+
+
+// Is `x` a power of two? (0 is considered a power of two)
+static inline bool _mi_is_power_of_two(uintptr_t x) {
+  return ((x & (x - 1)) == 0);
+}
+
+// Align upwards
+static inline uintptr_t _mi_align_up(uintptr_t sz, size_t alignment) {
+  mi_assert_internal(alignment != 0);
+  uintptr_t mask = alignment - 1;
+  if ((alignment & mask) == 0) {  // power of two?
+    return ((sz + mask) & ~mask);
+  }
+  else {
+    return (((sz + mask)/alignment)*alignment);
+  }
+}
+
+// Align downwards
+static inline uintptr_t _mi_align_down(uintptr_t sz, size_t alignment) {
+  mi_assert_internal(alignment != 0);
+  uintptr_t mask = alignment - 1;
+  if ((alignment & mask) == 0) { // power of two?
+    return (sz & ~mask);
+  }
+  else {
+    return ((sz / alignment) * alignment);
+  }
+}
+
+// Divide upwards: `s <= _mi_divide_up(s,d)*d < s+d`.
+static inline uintptr_t _mi_divide_up(uintptr_t size, size_t divider) {
+  mi_assert_internal(divider != 0);
+  return (divider == 0 ? size : ((size + divider - 1) / divider));
+}
+
+// Is memory zero initialized?
+static inline bool mi_mem_is_zero(void* p, size_t size) {
+  for (size_t i = 0; i < size; i++) {
+    if (((uint8_t*)p)[i] != 0) return false;
+  }
+  return true;
+}
+
+
+// Align a byte size to a size in _machine words_,
+// i.e. byte size == `wsize*sizeof(void*)`.
+static inline size_t _mi_wsize_from_size(size_t size) {
+  mi_assert_internal(size <= SIZE_MAX - sizeof(uintptr_t));
+  return (size + sizeof(uintptr_t) - 1) / sizeof(uintptr_t);
+}
+
+// Overflow detecting multiply
+#if __has_builtin(__builtin_umul_overflow) || (defined(__GNUC__) && (__GNUC__ >= 5))
+#include <limits.h>      // UINT_MAX, ULONG_MAX
+#if defined(_CLOCK_T)    // for Illumos
+#undef _CLOCK_T
+#endif
+static inline bool mi_mul_overflow(size_t count, size_t size, size_t* total) {
+  #if (SIZE_MAX == ULONG_MAX)
+    return __builtin_umull_overflow(count, size, (unsigned long *)total);
+  #elif (SIZE_MAX == UINT_MAX)
+    return __builtin_umul_overflow(count, size, (unsigned int *)total);
+  #else
+    return __builtin_umulll_overflow(count, size, (unsigned long long *)total);
+  #endif
+}
+#else /* __builtin_umul_overflow is unavailable */
+static inline bool mi_mul_overflow(size_t count, size_t size, size_t* total) {
+  #define MI_MUL_NO_OVERFLOW ((size_t)1 << (4*sizeof(size_t)))  // sqrt(SIZE_MAX)
+  *total = count * size;
+  return ((size >= MI_MUL_NO_OVERFLOW || count >= MI_MUL_NO_OVERFLOW)
+    && size > 0 && (SIZE_MAX / size) < count);
+}
+#endif
+
+// Safe multiply `count*size` into `total`; return `true` on overflow.
+static inline bool mi_count_size_overflow(size_t count, size_t size, size_t* total) {
+  if (count==1) {  // quick check for the case where count is one (common for C++ allocators)
+    *total = size;
+    return false;
+  }
+  else if (mi_unlikely(mi_mul_overflow(count, size, total))) {
+    _mi_error_message(EOVERFLOW, "allocation request is too large (%zu * %zu bytes)\n", count, size);
+    *total = SIZE_MAX;
+    return true;
+  }
+  else return false;
+}
+
+
+/* ----------------------------------------------------------------------------------------
+The thread local default heap: `_mi_get_default_heap` returns the thread local heap.
+On most platforms (Windows, Linux, FreeBSD, NetBSD, etc), this just returns a
+__thread local variable (`_mi_heap_default`). With the initial-exec TLS model this ensures
+that the storage will always be available (allocated on the thread stacks).
+On some platforms though we cannot use that when overriding `malloc` since the underlying
+TLS implementation (or the loader) will call itself `malloc` on a first access and recurse.
+We try to circumvent this in an efficient way:
+- macOSX : we use an unused TLS slot from the OS allocated slots (MI_TLS_SLOT). On OSX, the
+           loader itself calls `malloc` even before the modules are initialized.
+- OpenBSD: we use an unused slot from the pthread block (MI_TLS_PTHREAD_SLOT_OFS).
+- DragonFly: defaults are working but seem slow compared to freeBSD (see PR #323)
+------------------------------------------------------------------------------------------- */
+
+extern const mi_heap_t _mi_heap_empty;  // read-only empty heap, initial value of the thread local default heap
+extern bool _mi_process_is_initialized;
+mi_heap_t*  _mi_heap_main_get(void);    // statically allocated main backing heap
+
+#if defined(MI_MALLOC_OVERRIDE)
+#if defined(__APPLE__) // macOS
+#define MI_TLS_SLOT               89  // seems unused? 
+// #define MI_TLS_RECURSE_GUARD 1     
+// other possible unused ones are 9, 29, __PTK_FRAMEWORK_JAVASCRIPTCORE_KEY4 (94), __PTK_FRAMEWORK_GC_KEY9 (112) and __PTK_FRAMEWORK_OLDGC_KEY9 (89)
+// see <https://github.com/rweichler/substrate/blob/master/include/pthread_machdep.h>
+#elif defined(__OpenBSD__)
+// use end bytes of a name; goes wrong if anyone uses names > 23 characters (ptrhread specifies 16) 
+// see <https://github.com/openbsd/src/blob/master/lib/libc/include/thread_private.h#L371>
+#define MI_TLS_PTHREAD_SLOT_OFS   (6*sizeof(int) + 4*sizeof(void*) + 24)  
+// #elif defined(__DragonFly__)
+// #warning "mimalloc is not working correctly on DragonFly yet."
+// #define MI_TLS_PTHREAD_SLOT_OFS   (4 + 1*sizeof(void*))  // offset `uniqueid` (also used by gdb?) <https://github.com/DragonFlyBSD/DragonFlyBSD/blob/master/lib/libthread_xu/thread/thr_private.h#L458>
+#elif defined(__ANDROID__)
+// See issue #381
+#define MI_TLS_PTHREAD
+#endif
+#endif
+
+#if defined(MI_TLS_SLOT)
+static inline void* mi_tls_slot(size_t slot) mi_attr_noexcept;   // forward declaration
+#elif defined(MI_TLS_PTHREAD_SLOT_OFS)
+static inline mi_heap_t** mi_tls_pthread_heap_slot(void) {
+  pthread_t self = pthread_self();
+  #if defined(__DragonFly__)
+  if (self==NULL) {
+    mi_heap_t* pheap_main = _mi_heap_main_get();
+    return &pheap_main;
+  }
+  #endif
+  return (mi_heap_t**)((uint8_t*)self + MI_TLS_PTHREAD_SLOT_OFS);
+}
+#elif defined(MI_TLS_PTHREAD)
+extern pthread_key_t _mi_heap_default_key;
+#endif
+
+// Default heap to allocate from (if not using TLS- or pthread slots).
+// Do not use this directly but use through `mi_heap_get_default()` (or the unchecked `mi_get_default_heap`).
+// This thread local variable is only used when neither MI_TLS_SLOT, MI_TLS_PTHREAD, or MI_TLS_PTHREAD_SLOT_OFS are defined.
+// However, on the Apple M1 we do use the address of this variable as the unique thread-id (issue #356).
+extern mi_decl_thread mi_heap_t* _mi_heap_default;  // default heap to allocate from
+
+static inline mi_heap_t* mi_get_default_heap(void) {
+#if defined(MI_TLS_SLOT)
+  mi_heap_t* heap = (mi_heap_t*)mi_tls_slot(MI_TLS_SLOT);
+  if (mi_unlikely(heap == NULL)) {
+    #ifdef __GNUC__
+    __asm(""); // prevent conditional load of the address of _mi_heap_empty
+    #endif
+    heap = (mi_heap_t*)&_mi_heap_empty;    
+  }
+  return heap;
+#elif defined(MI_TLS_PTHREAD_SLOT_OFS)
+  mi_heap_t* heap = *mi_tls_pthread_heap_slot();
+  return (mi_unlikely(heap == NULL) ? (mi_heap_t*)&_mi_heap_empty : heap);
+#elif defined(MI_TLS_PTHREAD)
+  mi_heap_t* heap = (mi_unlikely(_mi_heap_default_key == (pthread_key_t)(-1)) ? _mi_heap_main_get() : (mi_heap_t*)pthread_getspecific(_mi_heap_default_key));
+  return (mi_unlikely(heap == NULL) ? (mi_heap_t*)&_mi_heap_empty : heap);
+#else
+  #if defined(MI_TLS_RECURSE_GUARD)  
+  if (mi_unlikely(!_mi_process_is_initialized)) return _mi_heap_main_get();
+  #endif
+  return _mi_heap_default;
+#endif
+}
+
+static inline bool mi_heap_is_default(const mi_heap_t* heap) {
+  return (heap == mi_get_default_heap());
+}
+
+static inline bool mi_heap_is_backing(const mi_heap_t* heap) {
+  return (heap->tld->heap_backing == heap);
+}
+
+static inline bool mi_heap_is_initialized(mi_heap_t* heap) {
+  mi_assert_internal(heap != NULL);
+  return (heap != &_mi_heap_empty);
+}
+
+static inline uintptr_t _mi_ptr_cookie(const void* p) {
+  extern mi_heap_t _mi_heap_main;
+  mi_assert_internal(_mi_heap_main.cookie != 0);
+  return ((uintptr_t)p ^ _mi_heap_main.cookie);
+}
+
+/* -----------------------------------------------------------
+  Pages
+----------------------------------------------------------- */
+
+static inline mi_page_t* _mi_heap_get_free_small_page(mi_heap_t* heap, size_t size) {
+  mi_assert_internal(size <= (MI_SMALL_SIZE_MAX + MI_PADDING_SIZE));
+  const size_t idx = _mi_wsize_from_size(size);
+  mi_assert_internal(idx < MI_PAGES_DIRECT);
+  return heap->pages_free_direct[idx];
+}
+
+// Get the page belonging to a certain size class
+static inline mi_page_t* _mi_get_free_small_page(size_t size) {
+  return _mi_heap_get_free_small_page(mi_get_default_heap(), size);
+}
+
+// Segment that contains the pointer
+static inline mi_segment_t* _mi_ptr_segment(const void* p) {
+  // mi_assert_internal(p != NULL);
+  return (mi_segment_t*)((uintptr_t)p & ~MI_SEGMENT_MASK);
+}
+
+static inline mi_page_t* mi_slice_to_page(mi_slice_t* s) {
+  mi_assert_internal(s->slice_offset== 0 && s->slice_count > 0);
+  return (mi_page_t*)(s);
+}
+
+static inline mi_slice_t* mi_page_to_slice(mi_page_t* p) {
+  mi_assert_internal(p->slice_offset== 0 && p->slice_count > 0);
+  return (mi_slice_t*)(p);
+}
+
+// Segment belonging to a page
+static inline mi_segment_t* _mi_page_segment(const mi_page_t* page) {
+  mi_segment_t* segment = _mi_ptr_segment(page); 
+  mi_assert_internal(segment == NULL || ((mi_slice_t*)page >= segment->slices && (mi_slice_t*)page < segment->slices + segment->slice_entries));
+  return segment;
+}
+
+static inline mi_slice_t* mi_slice_first(const mi_slice_t* slice) {
+  mi_slice_t* start = (mi_slice_t*)((uint8_t*)slice - slice->slice_offset);
+  mi_assert_internal(start >= _mi_ptr_segment(slice)->slices);
+  mi_assert_internal(start->slice_offset == 0);
+  mi_assert_internal(start + start->slice_count > slice);
+  return start;
+}
+
+// Get the page containing the pointer
+static inline mi_page_t* _mi_segment_page_of(const mi_segment_t* segment, const void* p) {
+  ptrdiff_t diff = (uint8_t*)p - (uint8_t*)segment;
+  mi_assert_internal(diff >= 0 && diff < (ptrdiff_t)MI_SEGMENT_SIZE);
+  size_t idx = (size_t)diff >> MI_SEGMENT_SLICE_SHIFT;
+  mi_assert_internal(idx < segment->slice_entries);
+  mi_slice_t* slice0 = (mi_slice_t*)&segment->slices[idx];
+  mi_slice_t* slice = mi_slice_first(slice0);  // adjust to the block that holds the page data
+  mi_assert_internal(slice->slice_offset == 0);
+  mi_assert_internal(slice >= segment->slices && slice < segment->slices + segment->slice_entries);
+  return mi_slice_to_page(slice);
+}
+
+// Quick page start for initialized pages
+static inline uint8_t* _mi_page_start(const mi_segment_t* segment, const mi_page_t* page, size_t* page_size) {
+  return _mi_segment_page_start(segment, page, page_size);
+}
+
+// Get the page containing the pointer
+static inline mi_page_t* _mi_ptr_page(void* p) {
+  return _mi_segment_page_of(_mi_ptr_segment(p), p);
+}
+
+// Get the block size of a page (special case for huge objects)
+static inline size_t mi_page_block_size(const mi_page_t* page) {
+  const size_t bsize = page->xblock_size;
+  mi_assert_internal(bsize > 0);
+  if (mi_likely(bsize < MI_HUGE_BLOCK_SIZE)) {
+    return bsize;
+  }
+  else {
+    size_t psize;
+    _mi_segment_page_start(_mi_page_segment(page), page, &psize);
+    return psize;
+  }
+}
+
+// Get the usable block size of a page without fixed padding.
+// This may still include internal padding due to alignment and rounding up size classes.
+static inline size_t mi_page_usable_block_size(const mi_page_t* page) {
+  return mi_page_block_size(page) - MI_PADDING_SIZE;
+}
+
+// size of a segment
+static inline size_t mi_segment_size(mi_segment_t* segment) {
+  return segment->segment_slices * MI_SEGMENT_SLICE_SIZE;
+}
+
+static inline uint8_t* mi_segment_end(mi_segment_t* segment) {
+  return (uint8_t*)segment + mi_segment_size(segment);
+}
+
+// Thread free access
+static inline mi_block_t* mi_page_thread_free(const mi_page_t* page) {
+  return (mi_block_t*)(mi_atomic_load_relaxed(&((mi_page_t*)page)->xthread_free) & ~3);
+}
+
+static inline mi_delayed_t mi_page_thread_free_flag(const mi_page_t* page) {
+  return (mi_delayed_t)(mi_atomic_load_relaxed(&((mi_page_t*)page)->xthread_free) & 3);
+}
+
+// Heap access
+static inline mi_heap_t* mi_page_heap(const mi_page_t* page) {
+  return (mi_heap_t*)(mi_atomic_load_relaxed(&((mi_page_t*)page)->xheap));
+}
+
+static inline void mi_page_set_heap(mi_page_t* page, mi_heap_t* heap) {
+  mi_assert_internal(mi_page_thread_free_flag(page) != MI_DELAYED_FREEING);
+  mi_atomic_store_release(&page->xheap,(uintptr_t)heap);
+}
+
+// Thread free flag helpers
+static inline mi_block_t* mi_tf_block(mi_thread_free_t tf) {
+  return (mi_block_t*)(tf & ~0x03);
+}
+static inline mi_delayed_t mi_tf_delayed(mi_thread_free_t tf) {
+  return (mi_delayed_t)(tf & 0x03);
+}
+static inline mi_thread_free_t mi_tf_make(mi_block_t* block, mi_delayed_t delayed) {
+  return (mi_thread_free_t)((uintptr_t)block | (uintptr_t)delayed);
+}
+static inline mi_thread_free_t mi_tf_set_delayed(mi_thread_free_t tf, mi_delayed_t delayed) {
+  return mi_tf_make(mi_tf_block(tf),delayed);
+}
+static inline mi_thread_free_t mi_tf_set_block(mi_thread_free_t tf, mi_block_t* block) {
+  return mi_tf_make(block, mi_tf_delayed(tf));
+}
+
+// are all blocks in a page freed?
+// note: needs up-to-date used count, (as the `xthread_free` list may not be empty). see `_mi_page_collect_free`.
+static inline bool mi_page_all_free(const mi_page_t* page) {
+  mi_assert_internal(page != NULL);
+  return (page->used == 0);
+}
+
+// are there any available blocks?
+static inline bool mi_page_has_any_available(const mi_page_t* page) {
+  mi_assert_internal(page != NULL && page->reserved > 0);
+  return (page->used < page->reserved || (mi_page_thread_free(page) != NULL));
+}
+
+// are there immediately available blocks, i.e. blocks available on the free list.
+static inline bool mi_page_immediate_available(const mi_page_t* page) {
+  mi_assert_internal(page != NULL);
+  return (page->free != NULL);
+}
+
+// is more than 7/8th of a page in use?
+static inline bool mi_page_mostly_used(const mi_page_t* page) {
+  if (page==NULL) return true;
+  uint16_t frac = page->reserved / 8U;
+  return (page->reserved - page->used <= frac);
+}
+
+static inline mi_page_queue_t* mi_page_queue(const mi_heap_t* heap, size_t size) {
+  return &((mi_heap_t*)heap)->pages[_mi_bin(size)];
+}
+
+
+
+//-----------------------------------------------------------
+// Page flags
+//-----------------------------------------------------------
+static inline bool mi_page_is_in_full(const mi_page_t* page) {
+  return page->flags.x.in_full;
+}
+
+static inline void mi_page_set_in_full(mi_page_t* page, bool in_full) {
+  page->flags.x.in_full = in_full;
+}
+
+static inline bool mi_page_has_aligned(const mi_page_t* page) {
+  return page->flags.x.has_aligned;
+}
+
+static inline void mi_page_set_has_aligned(mi_page_t* page, bool has_aligned) {
+  page->flags.x.has_aligned = has_aligned;
+}
+
+
+/* -------------------------------------------------------------------
+Encoding/Decoding the free list next pointers
+
+This is to protect against buffer overflow exploits where the
+free list is mutated. Many hardened allocators xor the next pointer `p`
+with a secret key `k1`, as `p^k1`. This prevents overwriting with known
+values but might be still too weak: if the attacker can guess
+the pointer `p` this  can reveal `k1` (since `p^k1^p == k1`).
+Moreover, if multiple blocks can be read as well, the attacker can
+xor both as `(p1^k1) ^ (p2^k1) == p1^p2` which may reveal a lot
+about the pointers (and subsequently `k1`).
+
+Instead mimalloc uses an extra key `k2` and encodes as `((p^k2)<<<k1)+k1`.
+Since these operations are not associative, the above approaches do not
+work so well any more even if the `p` can be guesstimated. For example,
+for the read case we can subtract two entries to discard the `+k1` term,
+but that leads to `((p1^k2)<<<k1) - ((p2^k2)<<<k1)` at best.
+We include the left-rotation since xor and addition are otherwise linear
+in the lowest bit. Finally, both keys are unique per page which reduces
+the re-use of keys by a large factor.
+
+We also pass a separate `null` value to be used as `NULL` or otherwise
+`(k2<<<k1)+k1` would appear (too) often as a sentinel value.
+------------------------------------------------------------------- */
+
+static inline bool mi_is_in_same_segment(const void* p, const void* q) {
+  return (_mi_ptr_segment(p) == _mi_ptr_segment(q));
+}
+
+static inline bool mi_is_in_same_page(const void* p, const void* q) {
+  mi_segment_t* segment = _mi_ptr_segment(p);
+  if (_mi_ptr_segment(q) != segment) return false;
+  // assume q may be invalid // return (_mi_segment_page_of(segment, p) == _mi_segment_page_of(segment, q));
+  mi_page_t* page = _mi_segment_page_of(segment, p);
+  size_t psize;
+  uint8_t* start = _mi_segment_page_start(segment, page, &psize);
+  return (start <= (uint8_t*)q && (uint8_t*)q < start + psize);
+}
+
+static inline uintptr_t mi_rotl(uintptr_t x, uintptr_t shift) {
+  shift %= MI_INTPTR_BITS;
+  return (shift==0 ? x : ((x << shift) | (x >> (MI_INTPTR_BITS - shift))));
+}
+static inline uintptr_t mi_rotr(uintptr_t x, uintptr_t shift) {
+  shift %= MI_INTPTR_BITS;
+  return (shift==0 ? x : ((x >> shift) | (x << (MI_INTPTR_BITS - shift))));
+}
+
+static inline void* mi_ptr_decode(const void* null, const mi_encoded_t x, const uintptr_t* keys) {
+  void* p = (void*)(mi_rotr(x - keys[0], keys[0]) ^ keys[1]);
+  return (mi_unlikely(p==null) ? NULL : p);
+}
+
+static inline mi_encoded_t mi_ptr_encode(const void* null, const void* p, const uintptr_t* keys) {
+  uintptr_t x = (uintptr_t)(mi_unlikely(p==NULL) ? null : p);
+  return mi_rotl(x ^ keys[1], keys[0]) + keys[0];
+}
+
+static inline mi_block_t* mi_block_nextx( const void* null, const mi_block_t* block, const uintptr_t* keys ) {
+  #ifdef MI_ENCODE_FREELIST
+  return (mi_block_t*)mi_ptr_decode(null, block->next, keys);
+  #else
+  MI_UNUSED(keys); MI_UNUSED(null);
+  return (mi_block_t*)block->next;
+  #endif
+}
+
+static inline void mi_block_set_nextx(const void* null, mi_block_t* block, const mi_block_t* next, const uintptr_t* keys) {
+  #ifdef MI_ENCODE_FREELIST
+  block->next = mi_ptr_encode(null, next, keys);
+  #else
+  MI_UNUSED(keys); MI_UNUSED(null);
+  block->next = (mi_encoded_t)next;
+  #endif
+}
+
+static inline mi_block_t* mi_block_next(const mi_page_t* page, const mi_block_t* block) {
+  #ifdef MI_ENCODE_FREELIST
+  mi_block_t* next = mi_block_nextx(page,block,page->keys);
+  // check for free list corruption: is `next` at least in the same page?
+  // TODO: check if `next` is `page->block_size` aligned?
+  if (mi_unlikely(next!=NULL && !mi_is_in_same_page(block, next))) {
+    _mi_error_message(EFAULT, "corrupted free list entry of size %zub at %p: value 0x%zx\n", mi_page_block_size(page), block, (uintptr_t)next);
+    next = NULL;
+  }
+  return next;
+  #else
+  MI_UNUSED(page);
+  return mi_block_nextx(page,block,NULL);
+  #endif
+}
+
+static inline void mi_block_set_next(const mi_page_t* page, mi_block_t* block, const mi_block_t* next) {
+  #ifdef MI_ENCODE_FREELIST
+  mi_block_set_nextx(page,block,next, page->keys);
+  #else
+  MI_UNUSED(page);
+  mi_block_set_nextx(page,block,next,NULL);
+  #endif
+}
+
+
+// -------------------------------------------------------------------
+// commit mask
+// -------------------------------------------------------------------
+
+static inline void mi_commit_mask_create_empty(mi_commit_mask_t* cm) {
+  for (size_t i = 0; i < MI_COMMIT_MASK_FIELD_COUNT; i++) {
+    cm->mask[i] = 0;
+  }
+}
+
+static inline void mi_commit_mask_create_full(mi_commit_mask_t* cm) {
+  for (size_t i = 0; i < MI_COMMIT_MASK_FIELD_COUNT; i++) {
+    cm->mask[i] = ~((size_t)0);
+  }
+}
+
+static inline bool mi_commit_mask_is_empty(const mi_commit_mask_t* cm) {
+  for (size_t i = 0; i < MI_COMMIT_MASK_FIELD_COUNT; i++) {
+    if (cm->mask[i] != 0) return false;
+  }
+  return true;
+}
+
+static inline bool mi_commit_mask_is_full(const mi_commit_mask_t* cm) {
+  for (size_t i = 0; i < MI_COMMIT_MASK_FIELD_COUNT; i++) {
+    if (cm->mask[i] != ~((size_t)0)) return false;
+  }
+  return true;
+}
+
+// defined in `segment.c`:
+size_t _mi_commit_mask_committed_size(const mi_commit_mask_t* cm, size_t total);
+size_t _mi_commit_mask_next_run(const mi_commit_mask_t* cm, size_t* idx);
+
+#define mi_commit_mask_foreach(cm,idx,count) \
+  idx = 0; \
+  while ((count = _mi_commit_mask_next_run(cm,&idx)) > 0) { 
+        
+#define mi_commit_mask_foreach_end() \
+    idx += count; \
+  }
+      
+
+
+
+// -------------------------------------------------------------------
+// Fast "random" shuffle
+// -------------------------------------------------------------------
+
+static inline uintptr_t _mi_random_shuffle(uintptr_t x) {
+  if (x==0) { x = 17; }   // ensure we don't get stuck in generating zeros
+#if (MI_INTPTR_SIZE==8)
+  // by Sebastiano Vigna, see: <http://xoshiro.di.unimi.it/splitmix64.c>
+  x ^= x >> 30;
+  x *= 0xbf58476d1ce4e5b9UL;
+  x ^= x >> 27;
+  x *= 0x94d049bb133111ebUL;
+  x ^= x >> 31;
+#elif (MI_INTPTR_SIZE==4)
+  // by Chris Wellons, see: <https://nullprogram.com/blog/2018/07/31/>
+  x ^= x >> 16;
+  x *= 0x7feb352dUL;
+  x ^= x >> 15;
+  x *= 0x846ca68bUL;
+  x ^= x >> 16;
+#endif
+  return x;
+}
+
+// -------------------------------------------------------------------
+// Optimize numa node access for the common case (= one node)
+// -------------------------------------------------------------------
+
+int    _mi_os_numa_node_get(mi_os_tld_t* tld);
+size_t _mi_os_numa_node_count_get(void);
+
+extern _Atomic(size_t) _mi_numa_node_count;
+static inline int _mi_os_numa_node(mi_os_tld_t* tld) {
+  if (mi_likely(mi_atomic_load_relaxed(&_mi_numa_node_count) == 1)) return 0;
+  else return _mi_os_numa_node_get(tld);
+}
+static inline size_t _mi_os_numa_node_count(void) {
+  const size_t count = mi_atomic_load_relaxed(&_mi_numa_node_count);
+  if (mi_likely(count>0)) return count;
+  else return _mi_os_numa_node_count_get();
+}
+
+
+// -------------------------------------------------------------------
+// Getting the thread id should be performant as it is called in the
+// fast path of `_mi_free` and we specialize for various platforms.
+// We only require _mi_threadid() to return a unique id for each thread.
+// -------------------------------------------------------------------
+#if defined(_WIN32)
+
+#define WIN32_LEAN_AND_MEAN
+#include <windows.h>
+static inline mi_threadid_t _mi_thread_id(void) mi_attr_noexcept {
+  // Windows: works on Intel and ARM in both 32- and 64-bit
+  return (uintptr_t)NtCurrentTeb();
+}
+
+// We use assembly for a fast thread id on the main platforms. The TLS layout depends on 
+// both the OS and libc implementation so we use specific tests for each main platform.
+// If you test on another platform and it works please send a PR :-)
+// see also https://akkadia.org/drepper/tls.pdf for more info on the TLS register.
+#elif defined(__GNUC__) && ( \
+           (defined(__GLIBC__)   && (defined(__x86_64__) || defined(__i386__) || defined(__arm__) || defined(__aarch64__))) \
+        || (defined(__APPLE__)   && (defined(__x86_64__) || defined(__aarch64__))) \
+        || (defined(__BIONIC__)  && (defined(__x86_64__) || defined(__i386__) || defined(__arm__) || defined(__aarch64__))) \
+        || (defined(__FreeBSD__) && (defined(__x86_64__) || defined(__i386__) || defined(__aarch64__))) \
+        || (defined(__OpenBSD__) && (defined(__x86_64__) || defined(__i386__) || defined(__aarch64__))) \
+      )
+
+static inline void* mi_tls_slot(size_t slot) mi_attr_noexcept {
+  void* res;
+  const size_t ofs = (slot*sizeof(void*));
+  #if defined(__i386__)
+    __asm__("movl %%gs:%1, %0" : "=r" (res) : "m" (*((void**)ofs)) : );  // x86 32-bit always uses GS
+  #elif defined(__APPLE__) && defined(__x86_64__)
+    __asm__("movq %%gs:%1, %0" : "=r" (res) : "m" (*((void**)ofs)) : );  // x86_64 macOSX uses GS
+  #elif defined(__x86_64__) && (MI_INTPTR_SIZE==4)
+    __asm__("movl %%fs:%1, %0" : "=r" (res) : "m" (*((void**)ofs)) : );  // x32 ABI
+  #elif defined(__x86_64__)
+    __asm__("movq %%fs:%1, %0" : "=r" (res) : "m" (*((void**)ofs)) : );  // x86_64 Linux, BSD uses FS
+  #elif defined(__arm__)
+    void** tcb; MI_UNUSED(ofs);
+    __asm__ volatile ("mrc p15, 0, %0, c13, c0, 3\nbic %0, %0, #3" : "=r" (tcb));
+    res = tcb[slot];
+  #elif defined(__aarch64__)
+    void** tcb; MI_UNUSED(ofs);
+    #if defined(__APPLE__) // M1, issue #343
+    __asm__ volatile ("mrs %0, tpidrro_el0\nbic %0, %0, #7" : "=r" (tcb));
+    #else
+    __asm__ volatile ("mrs %0, tpidr_el0" : "=r" (tcb));
+    #endif
+    res = tcb[slot];
+  #endif
+  return res;
+}
+
+// setting a tls slot is only used on macOS for now
+static inline void mi_tls_slot_set(size_t slot, void* value) mi_attr_noexcept {
+  const size_t ofs = (slot*sizeof(void*));
+  #if defined(__i386__)
+    __asm__("movl %1,%%gs:%0" : "=m" (*((void**)ofs)) : "rn" (value) : );  // 32-bit always uses GS
+  #elif defined(__APPLE__) && defined(__x86_64__)
+    __asm__("movq %1,%%gs:%0" : "=m" (*((void**)ofs)) : "rn" (value) : );  // x86_64 macOS uses GS
+  #elif defined(__x86_64__) && (MI_INTPTR_SIZE==4)
+    __asm__("movl %1,%%fs:%0" : "=m" (*((void**)ofs)) : "rn" (value) : );  // x32 ABI
+  #elif defined(__x86_64__)
+    __asm__("movq %1,%%fs:%0" : "=m" (*((void**)ofs)) : "rn" (value) : );  // x86_64 Linux, BSD uses FS
+  #elif defined(__arm__)
+    void** tcb; MI_UNUSED(ofs);
+    __asm__ volatile ("mrc p15, 0, %0, c13, c0, 3\nbic %0, %0, #3" : "=r" (tcb));
+    tcb[slot] = value;
+  #elif defined(__aarch64__)
+    void** tcb; MI_UNUSED(ofs);
+    #if defined(__APPLE__) // M1, issue #343
+    __asm__ volatile ("mrs %0, tpidrro_el0\nbic %0, %0, #7" : "=r" (tcb));
+    #else
+    __asm__ volatile ("mrs %0, tpidr_el0" : "=r" (tcb));
+    #endif
+    tcb[slot] = value;
+  #endif
+}
+
+static inline mi_threadid_t _mi_thread_id(void) mi_attr_noexcept {
+  #if defined(__BIONIC__)
+    // issue #384, #495: on the Bionic libc (Android), slot 1 is the thread id
+    // see: https://github.com/aosp-mirror/platform_bionic/blob/c44b1d0676ded732df4b3b21c5f798eacae93228/libc/platform/bionic/tls_defines.h#L86
+    return (uintptr_t)mi_tls_slot(1);
+  #else
+    // in all our other targets, slot 0 is the thread id
+    // glibc: https://sourceware.org/git/?p=glibc.git;a=blob_plain;f=sysdeps/x86_64/nptl/tls.h
+    // apple: https://github.com/apple/darwin-xnu/blob/main/libsyscall/os/tsd.h#L36
+    return (uintptr_t)mi_tls_slot(0);
+  #endif
+}
+
+#else
+
+// otherwise use portable C, taking the address of a thread local variable (this is still very fast on most platforms).
+static inline mi_threadid_t _mi_thread_id(void) mi_attr_noexcept {
+  return (uintptr_t)&_mi_heap_default;
+}
+
+#endif
+
+
+// -----------------------------------------------------------------------
+// Count bits: trailing or leading zeros (with MI_INTPTR_BITS on all zero)
+// -----------------------------------------------------------------------
+
+#if defined(__GNUC__)
+
+#include <limits.h>       // LONG_MAX
+#define MI_HAVE_FAST_BITSCAN
+static inline size_t mi_clz(uintptr_t x) {
+  if (x==0) return MI_INTPTR_BITS;
+#if (INTPTR_MAX == LONG_MAX)
+  return __builtin_clzl(x);
+#else
+  return __builtin_clzll(x);
+#endif
+}
+static inline size_t mi_ctz(uintptr_t x) {
+  if (x==0) return MI_INTPTR_BITS;
+#if (INTPTR_MAX == LONG_MAX)
+  return __builtin_ctzl(x);
+#else
+  return __builtin_ctzll(x);
+#endif
+}
+
+#elif defined(_MSC_VER) 
+
+#include <limits.h>       // LONG_MAX
+#define MI_HAVE_FAST_BITSCAN
+static inline size_t mi_clz(uintptr_t x) {
+  if (x==0) return MI_INTPTR_BITS;
+  unsigned long idx;
+#if (INTPTR_MAX == LONG_MAX)
+  _BitScanReverse(&idx, x);
+#else
+  _BitScanReverse64(&idx, x);
+#endif  
+  return ((MI_INTPTR_BITS - 1) - idx);
+}
+static inline size_t mi_ctz(uintptr_t x) {
+  if (x==0) return MI_INTPTR_BITS;
+  unsigned long idx;
+#if (INTPTR_MAX == LONG_MAX)
+  _BitScanForward(&idx, x);
+#else
+  _BitScanForward64(&idx, x);
+#endif  
+  return idx;
+}
+
+#else
+static inline size_t mi_ctz32(uint32_t x) {
+  // de Bruijn multiplication, see <http://supertech.csail.mit.edu/papers/debruijn.pdf>
+  static const unsigned char debruijn[32] = {
+    0, 1, 28, 2, 29, 14, 24, 3, 30, 22, 20, 15, 25, 17, 4, 8,
+    31, 27, 13, 23, 21, 19, 16, 7, 26, 12, 18, 6, 11, 5, 10, 9
+  };
+  if (x==0) return 32;
+  return debruijn[((x & -(int32_t)x) * 0x077CB531UL) >> 27];
+}
+static inline size_t mi_clz32(uint32_t x) {
+  // de Bruijn multiplication, see <http://supertech.csail.mit.edu/papers/debruijn.pdf>
+  static const uint8_t debruijn[32] = {
+    31, 22, 30, 21, 18, 10, 29, 2, 20, 17, 15, 13, 9, 6, 28, 1,
+    23, 19, 11, 3, 16, 14, 7, 24, 12, 4, 8, 25, 5, 26, 27, 0
+  };
+  if (x==0) return 32;
+  x |= x >> 1;
+  x |= x >> 2;
+  x |= x >> 4;
+  x |= x >> 8;
+  x |= x >> 16;
+  return debruijn[(uint32_t)(x * 0x07C4ACDDUL) >> 27];
+}
+
+static inline size_t mi_clz(uintptr_t x) {
+  if (x==0) return MI_INTPTR_BITS;  
+#if (MI_INTPTR_BITS <= 32)
+  return mi_clz32((uint32_t)x);
+#else
+  size_t count = mi_clz32((uint32_t)(x >> 32));
+  if (count < 32) return count;
+  return (32 + mi_clz32((uint32_t)x));
+#endif
+}
+static inline size_t mi_ctz(uintptr_t x) {
+  if (x==0) return MI_INTPTR_BITS;
+#if (MI_INTPTR_BITS <= 32)
+  return mi_ctz32((uint32_t)x);
+#else
+  size_t count = mi_ctz32((uint32_t)x);
+  if (count < 32) return count;
+  return (32 + mi_ctz32((uint32_t)(x>>32)));
+#endif
+}
+
+#endif
+
+// "bit scan reverse": Return index of the highest bit (or MI_INTPTR_BITS if `x` is zero)
+static inline size_t mi_bsr(uintptr_t x) {
+  return (x==0 ? MI_INTPTR_BITS : MI_INTPTR_BITS - 1 - mi_clz(x));
+}
+
+
+// ---------------------------------------------------------------------------------
+// Provide our own `_mi_memcpy` for potential performance optimizations.
+//
+// For now, only on Windows with msvc/clang-cl we optimize to `rep movsb` if 
+// we happen to run on x86/x64 cpu's that have "fast short rep movsb" (FSRM) support 
+// (AMD Zen3+ (~2020) or Intel Ice Lake+ (~2017). See also issue #201 and pr #253. 
+// ---------------------------------------------------------------------------------
+
+#if defined(_WIN32) && (defined(_M_IX86) || defined(_M_X64))
+#include <intrin.h>
+#include <string.h>
+extern bool _mi_cpu_has_fsrm;
+static inline void _mi_memcpy(void* dst, const void* src, size_t n) {
+  if (_mi_cpu_has_fsrm) {
+    __movsb((unsigned char*)dst, (const unsigned char*)src, n);
+  }
+  else {
+    memcpy(dst, src, n); // todo: use noinline?
+  }
+}
+#else
+#include <string.h>
+static inline void _mi_memcpy(void* dst, const void* src, size_t n) {
+  memcpy(dst, src, n);
+}
+#endif
+
+
+// -------------------------------------------------------------------------------
+// The `_mi_memcpy_aligned` can be used if the pointers are machine-word aligned 
+// This is used for example in `mi_realloc`.
+// -------------------------------------------------------------------------------
+
+#if (defined(__GNUC__) && (__GNUC__ >= 4)) || defined(__clang__)
+// On GCC/CLang we provide a hint that the pointers are word aligned.
+#include <string.h>
+static inline void _mi_memcpy_aligned(void* dst, const void* src, size_t n) {
+  mi_assert_internal(((uintptr_t)dst % MI_INTPTR_SIZE == 0) && ((uintptr_t)src % MI_INTPTR_SIZE == 0));
+  void* adst = __builtin_assume_aligned(dst, MI_INTPTR_SIZE);
+  const void* asrc = __builtin_assume_aligned(src, MI_INTPTR_SIZE);
+  memcpy(adst, asrc, n);
+}
+#else
+// Default fallback on `_mi_memcpy`
+static inline void _mi_memcpy_aligned(void* dst, const void* src, size_t n) {
+  mi_assert_internal(((uintptr_t)dst % MI_INTPTR_SIZE == 0) && ((uintptr_t)src % MI_INTPTR_SIZE == 0));
+  _mi_memcpy(dst, src, n);
+}
+#endif
+
+
+#endif
diff --git a/Include/internal/mimalloc/mimalloc-types.h b/Include/internal/mimalloc/mimalloc-types.h
new file mode 100644
index 0000000000000..310fb92b25960
--- /dev/null
+++ b/Include/internal/mimalloc/mimalloc-types.h
@@ -0,0 +1,602 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2021, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+#pragma once
+#ifndef MIMALLOC_TYPES_H
+#define MIMALLOC_TYPES_H
+
+#include <stddef.h>   // ptrdiff_t
+#include <stdint.h>   // uintptr_t, uint16_t, etc
+#include "mimalloc-atomic.h"  // _Atomic
+
+#ifdef _MSC_VER
+#pragma warning(disable:4214) // bitfield is not int
+#endif 
+
+// Minimal alignment necessary. On most platforms 16 bytes are needed
+// due to SSE registers for example. This must be at least `sizeof(void*)`
+#ifndef MI_MAX_ALIGN_SIZE
+#define MI_MAX_ALIGN_SIZE  16   // sizeof(max_align_t)
+#endif
+
+// ------------------------------------------------------
+// Variants
+// ------------------------------------------------------
+
+// Define NDEBUG in the release version to disable assertions.
+// #define NDEBUG
+
+// Define MI_STAT as 1 to maintain statistics; set it to 2 to have detailed statistics (but costs some performance).
+// #define MI_STAT 1
+
+// Define MI_SECURE to enable security mitigations
+// #define MI_SECURE 1  // guard page around metadata
+// #define MI_SECURE 2  // guard page around each mimalloc page
+// #define MI_SECURE 3  // encode free lists (detect corrupted free list (buffer overflow), and invalid pointer free)
+// #define MI_SECURE 4  // checks for double free. (may be more expensive)
+
+#if !defined(MI_SECURE)
+#define MI_SECURE 0
+#endif
+
+// Define MI_DEBUG for debug mode
+// #define MI_DEBUG 1  // basic assertion checks and statistics, check double free, corrupted free list, and invalid pointer free.
+// #define MI_DEBUG 2  // + internal assertion checks
+// #define MI_DEBUG 3  // + extensive internal invariant checking (cmake -DMI_DEBUG_FULL=ON)
+#if !defined(MI_DEBUG)
+#if !defined(NDEBUG) || defined(_DEBUG)
+#define MI_DEBUG 2
+#else
+#define MI_DEBUG 0
+#endif
+#endif
+
+// Reserve extra padding at the end of each block to be more resilient against heap block overflows.
+// The padding can detect byte-precise buffer overflow on free.
+#if !defined(MI_PADDING) && (MI_DEBUG>=1)
+#define MI_PADDING  1
+#endif
+
+
+// Encoded free lists allow detection of corrupted free lists
+// and can detect buffer overflows, modify after free, and double `free`s.
+#if (MI_SECURE>=3 || MI_DEBUG>=1 || MI_PADDING > 0)
+#define MI_ENCODE_FREELIST  1
+#endif
+
+
+// ------------------------------------------------------
+// Platform specific values
+// ------------------------------------------------------
+
+// ------------------------------------------------------
+// Size of a pointer.
+// We assume that `sizeof(void*)==sizeof(intptr_t)`
+// and it holds for all platforms we know of.
+//
+// However, the C standard only requires that:
+//  p == (void*)((intptr_t)p))
+// but we also need:
+//  i == (intptr_t)((void*)i)
+// or otherwise one might define an intptr_t type that is larger than a pointer...
+// ------------------------------------------------------
+
+#if INTPTR_MAX > INT64_MAX
+# define MI_INTPTR_SHIFT (4)  // assume 128-bit  (as on arm CHERI for example)
+#elif INTPTR_MAX == INT64_MAX
+# define MI_INTPTR_SHIFT (3)
+#elif INTPTR_MAX == INT32_MAX
+# define MI_INTPTR_SHIFT (2)
+#else
+#error platform pointers must be 32, 64, or 128 bits
+#endif
+
+#if SIZE_MAX == UINT64_MAX
+# define MI_SIZE_SHIFT (3)
+typedef int64_t  mi_ssize_t;
+#elif SIZE_MAX == UINT32_MAX
+# define MI_SIZE_SHIFT (2)
+typedef int32_t  mi_ssize_t;
+#else
+#error platform objects must be 32 or 64 bits
+#endif
+
+#if (SIZE_MAX/2) > LONG_MAX
+# define MI_ZU(x)  x##ULL
+# define MI_ZI(x)  x##LL
+#else
+# define MI_ZU(x)  x##UL
+# define MI_ZI(x)  x##L
+#endif
+
+#define MI_INTPTR_SIZE  (1<<MI_INTPTR_SHIFT)
+#define MI_INTPTR_BITS  (MI_INTPTR_SIZE*8)
+
+#define MI_SIZE_SIZE  (1<<MI_SIZE_SHIFT)
+#define MI_SIZE_BITS  (MI_SIZE_SIZE*8)
+
+#define MI_KiB     (MI_ZU(1024))
+#define MI_MiB     (MI_KiB*MI_KiB)
+#define MI_GiB     (MI_MiB*MI_KiB)
+
+
+// ------------------------------------------------------
+// Main internal data-structures
+// ------------------------------------------------------
+
+// Main tuning parameters for segment and page sizes
+// Sizes for 64-bit (usually divide by two for 32-bit)
+#define MI_SEGMENT_SLICE_SHIFT            (13 + MI_INTPTR_SHIFT)         // 64KiB  (32KiB on 32-bit)
+
+#if MI_INTPTR_SIZE > 4
+#define MI_SEGMENT_SHIFT                  (10 + MI_SEGMENT_SLICE_SHIFT)  // 64MiB
+#else
+#define MI_SEGMENT_SHIFT                  ( 7 + MI_SEGMENT_SLICE_SHIFT)  // 4MiB on 32-bit
+#endif
+
+#define MI_SMALL_PAGE_SHIFT               (MI_SEGMENT_SLICE_SHIFT)       // 64KiB
+#define MI_MEDIUM_PAGE_SHIFT              ( 3 + MI_SMALL_PAGE_SHIFT)     // 512KiB
+
+
+// Derived constants
+#define MI_SEGMENT_SIZE                   (MI_ZU(1)<<MI_SEGMENT_SHIFT)
+#define MI_SEGMENT_ALIGN                  MI_SEGMENT_SIZE
+#define MI_SEGMENT_MASK                   (MI_SEGMENT_SIZE - 1)
+#define MI_SEGMENT_SLICE_SIZE             (MI_ZU(1)<< MI_SEGMENT_SLICE_SHIFT)
+#define MI_SLICES_PER_SEGMENT             (MI_SEGMENT_SIZE / MI_SEGMENT_SLICE_SIZE) // 1024
+
+#define MI_SMALL_PAGE_SIZE                (MI_ZU(1)<<MI_SMALL_PAGE_SHIFT)
+#define MI_MEDIUM_PAGE_SIZE               (MI_ZU(1)<<MI_MEDIUM_PAGE_SHIFT)
+
+#define MI_SMALL_OBJ_SIZE_MAX             (MI_SMALL_PAGE_SIZE/4)   // 8KiB on 64-bit
+#define MI_MEDIUM_OBJ_SIZE_MAX            (MI_MEDIUM_PAGE_SIZE/4)  // 128KiB on 64-bit
+#define MI_MEDIUM_OBJ_WSIZE_MAX           (MI_MEDIUM_OBJ_SIZE_MAX/MI_INTPTR_SIZE)   
+#define MI_LARGE_OBJ_SIZE_MAX             (MI_SEGMENT_SIZE/2)      // 32MiB on 64-bit
+#define MI_LARGE_OBJ_WSIZE_MAX            (MI_LARGE_OBJ_SIZE_MAX/MI_INTPTR_SIZE)
+#define MI_HUGE_OBJ_SIZE_MAX              (2*MI_INTPTR_SIZE*MI_SEGMENT_SIZE)        // (must match MI_REGION_MAX_ALLOC_SIZE in memory.c)
+
+// Maximum number of size classes. (spaced exponentially in 12.5% increments)
+#define MI_BIN_HUGE  (73U)
+
+#if (MI_MEDIUM_OBJ_WSIZE_MAX >= 655360)
+#error "mimalloc internal: define more bins"
+#endif
+#if (MI_ALIGNMENT_MAX > MI_SEGMENT_SIZE/2)
+#error "mimalloc internal: the max aligned boundary is too large for the segment size"
+#endif
+#if (MI_ALIGNED_MAX % MI_SEGMENT_SLICE_SIZE != 0)
+#error "mimalloc internal: the max aligned boundary must be an integral multiple of the segment slice size"
+#endif
+
+// Maximum slice offset (15)
+#define MI_MAX_SLICE_OFFSET               ((MI_ALIGNMENT_MAX / MI_SEGMENT_SLICE_SIZE) - 1)
+
+// Used as a special value to encode block sizes in 32 bits.
+#define MI_HUGE_BLOCK_SIZE                ((uint32_t)MI_HUGE_OBJ_SIZE_MAX)
+
+// blocks up to this size are always allocated aligned
+#define MI_MAX_ALIGN_GUARANTEE            (8*MI_MAX_ALIGN_SIZE)  
+
+
+
+
+// ------------------------------------------------------
+// Mimalloc pages contain allocated blocks
+// ------------------------------------------------------
+
+// The free lists use encoded next fields
+// (Only actually encodes when MI_ENCODED_FREELIST is defined.)
+typedef uintptr_t  mi_encoded_t;
+
+// thread id's
+typedef size_t     mi_threadid_t;
+
+// free lists contain blocks
+typedef struct mi_block_s {
+  mi_encoded_t next;
+} mi_block_t;
+
+
+// The delayed flags are used for efficient multi-threaded free-ing
+typedef enum mi_delayed_e {
+  MI_USE_DELAYED_FREE   = 0, // push on the owning heap thread delayed list
+  MI_DELAYED_FREEING    = 1, // temporary: another thread is accessing the owning heap
+  MI_NO_DELAYED_FREE    = 2, // optimize: push on page local thread free queue if another block is already in the heap thread delayed free list
+  MI_NEVER_DELAYED_FREE = 3  // sticky, only resets on page reclaim
+} mi_delayed_t;
+
+
+// The `in_full` and `has_aligned` page flags are put in a union to efficiently
+// test if both are false (`full_aligned == 0`) in the `mi_free` routine.
+#if !MI_TSAN
+typedef union mi_page_flags_s {
+  uint8_t full_aligned;
+  struct {
+    uint8_t in_full : 1;
+    uint8_t has_aligned : 1;
+  } x;
+} mi_page_flags_t;
+#else
+// under thread sanitizer, use a byte for each flag to suppress warning, issue #130
+typedef union mi_page_flags_s {
+  uint16_t full_aligned;
+  struct {
+    uint8_t in_full;
+    uint8_t has_aligned;
+  } x;
+} mi_page_flags_t;
+#endif
+
+// Thread free list.
+// We use the bottom 2 bits of the pointer for mi_delayed_t flags
+typedef uintptr_t mi_thread_free_t;
+
+// A page contains blocks of one specific size (`block_size`).
+// Each page has three list of free blocks:
+// `free` for blocks that can be allocated,
+// `local_free` for freed blocks that are not yet available to `mi_malloc`
+// `thread_free` for freed blocks by other threads
+// The `local_free` and `thread_free` lists are migrated to the `free` list
+// when it is exhausted. The separate `local_free` list is necessary to
+// implement a monotonic heartbeat. The `thread_free` list is needed for
+// avoiding atomic operations in the common case.
+//
+//
+// `used - |thread_free|` == actual blocks that are in use (alive)
+// `used - |thread_free| + |free| + |local_free| == capacity`
+//
+// We don't count `freed` (as |free|) but use `used` to reduce
+// the number of memory accesses in the `mi_page_all_free` function(s).
+//
+// Notes: 
+// - Access is optimized for `mi_free` and `mi_page_alloc` (in `alloc.c`)
+// - Using `uint16_t` does not seem to slow things down
+// - The size is 8 words on 64-bit which helps the page index calculations
+//   (and 10 words on 32-bit, and encoded free lists add 2 words. Sizes 10 
+//    and 12 are still good for address calculation)
+// - To limit the structure size, the `xblock_size` is 32-bits only; for 
+//   blocks > MI_HUGE_BLOCK_SIZE the size is determined from the segment page size
+// - `thread_free` uses the bottom bits as a delayed-free flags to optimize
+//   concurrent frees where only the first concurrent free adds to the owning
+//   heap `thread_delayed_free` list (see `alloc.c:mi_free_block_mt`).
+//   The invariant is that no-delayed-free is only set if there is
+//   at least one block that will be added, or as already been added, to 
+//   the owning heap `thread_delayed_free` list. This guarantees that pages
+//   will be freed correctly even if only other threads free blocks.
+typedef struct mi_page_s {
+  // "owned" by the segment
+  uint32_t              slice_count;       // slices in this page (0 if not a page)
+  uint32_t              slice_offset;      // distance from the actual page data slice (0 if a page)
+  uint8_t               is_reset : 1;        // `true` if the page memory was reset
+  uint8_t               is_committed : 1;    // `true` if the page virtual memory is committed
+  uint8_t               is_zero_init : 1;    // `true` if the page was zero initialized
+
+  // layout like this to optimize access in `mi_malloc` and `mi_free`
+  uint16_t              capacity;          // number of blocks committed, must be the first field, see `segment.c:page_clear`
+  uint16_t              reserved;          // number of blocks reserved in memory
+  mi_page_flags_t       flags;             // `in_full` and `has_aligned` flags (8 bits)
+  uint8_t               is_zero : 1;         // `true` if the blocks in the free list are zero initialized
+  uint8_t               retire_expire : 7;   // expiration count for retired blocks
+
+  mi_block_t*           free;              // list of available free blocks (`malloc` allocates from this list)
+  #ifdef MI_ENCODE_FREELIST
+  uintptr_t             keys[2];           // two random keys to encode the free lists (see `_mi_block_next`)
+  #endif
+  uint32_t              used;              // number of blocks in use (including blocks in `local_free` and `thread_free`)
+  uint32_t              xblock_size;       // size available in each block (always `>0`) 
+
+  mi_block_t* local_free;                  // list of deferred free blocks by this thread (migrates to `free`)
+  _Atomic(mi_thread_free_t) xthread_free;  // list of deferred free blocks freed by other threads
+  _Atomic(uintptr_t)        xheap;
+
+  struct mi_page_s* next;                  // next page owned by this thread with the same `block_size`
+  struct mi_page_s* prev;                  // previous page owned by this thread with the same `block_size`
+
+  // 64-bit 9 words, 32-bit 12 words, (+2 for secure)
+  #if MI_INTPTR_SIZE==8
+  uintptr_t padding[1];
+  #endif
+} mi_page_t;
+
+
+
+typedef enum mi_page_kind_e {
+  MI_PAGE_SMALL,    // small blocks go into 64KiB pages inside a segment
+  MI_PAGE_MEDIUM,   // medium blocks go into medium pages inside a segment
+  MI_PAGE_LARGE,    // larger blocks go into a page of just one block
+  MI_PAGE_HUGE,     // huge blocks (> 16 MiB) are put into a single page in a single segment.
+} mi_page_kind_t;
+
+typedef enum mi_segment_kind_e {
+  MI_SEGMENT_NORMAL, // MI_SEGMENT_SIZE size with pages inside.
+  MI_SEGMENT_HUGE,   // > MI_LARGE_SIZE_MAX segment with just one huge page inside.
+} mi_segment_kind_t;
+
+// ------------------------------------------------------
+// A segment holds a commit mask where a bit is set if
+// the corresponding MI_COMMIT_SIZE area is committed.
+// The MI_COMMIT_SIZE must be a multiple of the slice
+// size. If it is equal we have the most fine grained 
+// decommit (but setting it higher can be more efficient).
+// The MI_MINIMAL_COMMIT_SIZE is the minimal amount that will
+// be committed in one go which can be set higher than
+// MI_COMMIT_SIZE for efficiency (while the decommit mask
+// is still tracked in fine-grained MI_COMMIT_SIZE chunks)
+// ------------------------------------------------------
+
+#define MI_MINIMAL_COMMIT_SIZE      (2*MI_MiB)
+#define MI_COMMIT_SIZE              (MI_SEGMENT_SLICE_SIZE)              // 64KiB
+#define MI_COMMIT_MASK_BITS         (MI_SEGMENT_SIZE / MI_COMMIT_SIZE)  
+#define MI_COMMIT_MASK_FIELD_BITS    MI_SIZE_BITS
+#define MI_COMMIT_MASK_FIELD_COUNT  (MI_COMMIT_MASK_BITS / MI_COMMIT_MASK_FIELD_BITS)
+
+#if (MI_COMMIT_MASK_BITS != (MI_COMMIT_MASK_FIELD_COUNT * MI_COMMIT_MASK_FIELD_BITS))
+#error "the segment size must be exactly divisible by the (commit size * size_t bits)"
+#endif
+
+typedef struct mi_commit_mask_s {
+  size_t mask[MI_COMMIT_MASK_FIELD_COUNT];
+} mi_commit_mask_t;
+
+typedef mi_page_t  mi_slice_t;
+typedef int64_t    mi_msecs_t;
+
+
+// Segments are large allocated memory blocks (8mb on 64 bit) from
+// the OS. Inside segments we allocated fixed size _pages_ that
+// contain blocks.
+typedef struct mi_segment_s {
+  size_t            memid;              // memory id for arena allocation
+  bool              mem_is_pinned;      // `true` if we cannot decommit/reset/protect in this memory (i.e. when allocated using large OS pages)    
+  bool              mem_is_large;       // in large/huge os pages?
+  bool              mem_is_committed;   // `true` if the whole segment is eagerly committed
+
+  bool              allow_decommit;     
+  mi_msecs_t        decommit_expire;
+  mi_commit_mask_t  decommit_mask;
+  mi_commit_mask_t  commit_mask;
+
+  _Atomic(struct mi_segment_s*) abandoned_next;
+
+  // from here is zero initialized
+  struct mi_segment_s* next;            // the list of freed segments in the cache (must be first field, see `segment.c:mi_segment_init`)
+  
+  size_t            abandoned;          // abandoned pages (i.e. the original owning thread stopped) (`abandoned <= used`)
+  size_t            abandoned_visits;   // count how often this segment is visited in the abandoned list (to force reclaim it it is too long)
+  size_t            used;               // count of pages in use
+  uintptr_t         cookie;             // verify addresses in debug mode: `mi_ptr_cookie(segment) == segment->cookie`  
+
+  size_t            segment_slices;      // for huge segments this may be different from `MI_SLICES_PER_SEGMENT`
+  size_t            segment_info_slices; // initial slices we are using segment info and possible guard pages.
+
+  // layout like this to optimize access in `mi_free`
+  mi_segment_kind_t kind;
+  _Atomic(mi_threadid_t) thread_id;      // unique id of the thread owning this segment
+  size_t            slice_entries;       // entries in the `slices` array, at most `MI_SLICES_PER_SEGMENT`
+  mi_slice_t        slices[MI_SLICES_PER_SEGMENT];
+} mi_segment_t;
+
+
+// ------------------------------------------------------
+// Heaps
+// Provide first-class heaps to allocate from.
+// A heap just owns a set of pages for allocation and
+// can only be allocate/reallocate from the thread that created it.
+// Freeing blocks can be done from any thread though.
+// Per thread, the segments are shared among its heaps.
+// Per thread, there is always a default heap that is
+// used for allocation; it is initialized to statically
+// point to an empty heap to avoid initialization checks
+// in the fast path.
+// ------------------------------------------------------
+
+// Thread local data
+typedef struct mi_tld_s mi_tld_t;
+
+// Pages of a certain block size are held in a queue.
+typedef struct mi_page_queue_s {
+  mi_page_t* first;
+  mi_page_t* last;
+  size_t     block_size;
+} mi_page_queue_t;
+
+#define MI_BIN_FULL  (MI_BIN_HUGE+1)
+
+// Random context
+typedef struct mi_random_cxt_s {
+  uint32_t input[16];
+  uint32_t output[16];
+  int      output_available;
+} mi_random_ctx_t;
+
+
+// In debug mode there is a padding structure at the end of the blocks to check for buffer overflows
+#if (MI_PADDING)
+typedef struct mi_padding_s {
+  uint32_t canary; // encoded block value to check validity of the padding (in case of overflow)
+  uint32_t delta;  // padding bytes before the block. (mi_usable_size(p) - delta == exact allocated bytes)
+} mi_padding_t;
+#define MI_PADDING_SIZE   (sizeof(mi_padding_t))
+#define MI_PADDING_WSIZE  ((MI_PADDING_SIZE + MI_INTPTR_SIZE - 1) / MI_INTPTR_SIZE)
+#else
+#define MI_PADDING_SIZE   0
+#define MI_PADDING_WSIZE  0
+#endif
+
+#define MI_PAGES_DIRECT   (MI_SMALL_WSIZE_MAX + MI_PADDING_WSIZE + 1)
+
+
+// A heap owns a set of pages.
+struct mi_heap_s {
+  mi_tld_t*             tld;
+  mi_page_t*            pages_free_direct[MI_PAGES_DIRECT];  // optimize: array where every entry points a page with possibly free blocks in the corresponding queue for that size.
+  mi_page_queue_t       pages[MI_BIN_FULL + 1];              // queue of pages for each size class (or "bin")
+  _Atomic(mi_block_t*)  thread_delayed_free;
+  mi_threadid_t         thread_id;                           // thread this heap belongs too
+  uintptr_t             cookie;                              // random cookie to verify pointers (see `_mi_ptr_cookie`)
+  uintptr_t             keys[2];                             // two random keys used to encode the `thread_delayed_free` list
+  mi_random_ctx_t       random;                              // random number context used for secure allocation
+  size_t                page_count;                          // total number of pages in the `pages` queues.
+  size_t                page_retired_min;                    // smallest retired index (retired pages are fully free, but still in the page queues)
+  size_t                page_retired_max;                    // largest retired index into the `pages` array.
+  mi_heap_t*            next;                                // list of heaps per thread
+  bool                  no_reclaim;                          // `true` if this heap should not reclaim abandoned pages
+};
+
+
+
+// ------------------------------------------------------
+// Debug
+// ------------------------------------------------------
+
+#if !defined(MI_DEBUG_UNINIT)
+#define MI_DEBUG_UNINIT     (0xD0)
+#endif
+#if !defined(MI_DEBUG_FREED)
+#define MI_DEBUG_FREED      (0xDF)
+#endif
+#if !defined(MI_DEBUG_PADDING)
+#define MI_DEBUG_PADDING    (0xDE)
+#endif
+
+#if (MI_DEBUG)
+// use our own assertion to print without memory allocation
+void _mi_assert_fail(const char* assertion, const char* fname, unsigned int line, const char* func );
+#define mi_assert(expr)     ((expr) ? (void)0 : _mi_assert_fail(#expr,__FILE__,__LINE__,__func__))
+#else
+#define mi_assert(x)
+#endif
+
+#if (MI_DEBUG>1)
+#define mi_assert_internal    mi_assert
+#else
+#define mi_assert_internal(x)
+#endif
+
+#if (MI_DEBUG>2)
+#define mi_assert_expensive   mi_assert
+#else
+#define mi_assert_expensive(x)
+#endif
+
+// ------------------------------------------------------
+// Statistics
+// ------------------------------------------------------
+
+#ifndef MI_STAT
+#if (MI_DEBUG>0)
+#define MI_STAT 2
+#else
+#define MI_STAT 0
+#endif
+#endif
+
+typedef struct mi_stat_count_s {
+  int64_t allocated;
+  int64_t freed;
+  int64_t peak;
+  int64_t current;
+} mi_stat_count_t;
+
+typedef struct mi_stat_counter_s {
+  int64_t total;
+  int64_t count;
+} mi_stat_counter_t;
+
+typedef struct mi_stats_s {
+  mi_stat_count_t segments;
+  mi_stat_count_t pages;
+  mi_stat_count_t reserved;
+  mi_stat_count_t committed;
+  mi_stat_count_t reset;
+  mi_stat_count_t page_committed;
+  mi_stat_count_t segments_abandoned;
+  mi_stat_count_t pages_abandoned;
+  mi_stat_count_t threads;
+  mi_stat_count_t normal;
+  mi_stat_count_t huge;
+  mi_stat_count_t large;
+  mi_stat_count_t malloc;
+  mi_stat_count_t segments_cache;
+  mi_stat_counter_t pages_extended;
+  mi_stat_counter_t mmap_calls;
+  mi_stat_counter_t commit_calls;
+  mi_stat_counter_t page_no_retire;
+  mi_stat_counter_t searches;
+  mi_stat_counter_t normal_count;
+  mi_stat_counter_t huge_count;
+  mi_stat_counter_t large_count;
+#if MI_STAT>1
+  mi_stat_count_t normal_bins[MI_BIN_HUGE+1];
+#endif
+} mi_stats_t;
+
+
+void _mi_stat_increase(mi_stat_count_t* stat, size_t amount);
+void _mi_stat_decrease(mi_stat_count_t* stat, size_t amount);
+void _mi_stat_counter_increase(mi_stat_counter_t* stat, size_t amount);
+
+#if (MI_STAT)
+#define mi_stat_increase(stat,amount)         _mi_stat_increase( &(stat), amount)
+#define mi_stat_decrease(stat,amount)         _mi_stat_decrease( &(stat), amount)
+#define mi_stat_counter_increase(stat,amount) _mi_stat_counter_increase( &(stat), amount)
+#else
+#define mi_stat_increase(stat,amount)         (void)0
+#define mi_stat_decrease(stat,amount)         (void)0
+#define mi_stat_counter_increase(stat,amount) (void)0
+#endif
+
+#define mi_heap_stat_counter_increase(heap,stat,amount)  mi_stat_counter_increase( (heap)->tld->stats.stat, amount)
+#define mi_heap_stat_increase(heap,stat,amount)  mi_stat_increase( (heap)->tld->stats.stat, amount)
+#define mi_heap_stat_decrease(heap,stat,amount)  mi_stat_decrease( (heap)->tld->stats.stat, amount)
+
+// ------------------------------------------------------
+// Thread Local data
+// ------------------------------------------------------
+
+// A "span" is is an available range of slices. The span queues keep
+// track of slice spans of at most the given `slice_count` (but more than the previous size class).
+typedef struct mi_span_queue_s {
+  mi_slice_t* first;
+  mi_slice_t* last;
+  size_t      slice_count;
+} mi_span_queue_t;
+
+#define MI_SEGMENT_BIN_MAX (35)     // 35 == mi_segment_bin(MI_SLICES_PER_SEGMENT)
+
+// OS thread local data
+typedef struct mi_os_tld_s {
+  size_t                region_idx;   // start point for next allocation
+  mi_stats_t*           stats;        // points to tld stats
+} mi_os_tld_t;
+
+
+// Segments thread local data
+typedef struct mi_segments_tld_s {
+  mi_span_queue_t     spans[MI_SEGMENT_BIN_MAX+1];  // free slice spans inside segments
+  size_t              count;        // current number of segments;
+  size_t              peak_count;   // peak number of segments
+  size_t              current_size; // current size of all segments
+  size_t              peak_size;    // peak size of all segments
+  size_t              cache_count;  // number of segments in the cache
+  size_t              cache_size;   // total size of all segments in the cache
+  mi_segment_t*       cache;        // (small) cache of segments
+  mi_stats_t*         stats;        // points to tld stats
+  mi_os_tld_t*        os;           // points to os stats
+} mi_segments_tld_t;
+
+// Thread local data
+struct mi_tld_s {
+  unsigned long long  heartbeat;     // monotonic heartbeat count
+  bool                recurse;       // true if deferred was called; used to prevent infinite recursion.
+  mi_heap_t*          heap_backing;  // backing heap of this thread (cannot be deleted)
+  mi_heap_t*          heaps;         // list of heaps in this thread (so we can abandon all when the thread terminates)
+  mi_segments_tld_t   segments;      // segment tld
+  mi_os_tld_t         os;            // os tld
+  mi_stats_t          stats;         // statistics
+};
+
+#endif
diff --git a/Include/internal/mimalloc/mimalloc.h b/Include/internal/mimalloc/mimalloc.h
new file mode 100644
index 0000000000000..83debd2aac540
--- /dev/null
+++ b/Include/internal/mimalloc/mimalloc.h
@@ -0,0 +1,450 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2022, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+#pragma once
+#ifndef MIMALLOC_H
+#define MIMALLOC_H
+
+#define MI_MALLOC_VERSION 205   // major + 2 digits minor
+
+// ------------------------------------------------------
+// Compiler specific attributes
+// ------------------------------------------------------
+
+#ifdef __cplusplus
+  #if (__cplusplus >= 201103L) || (_MSC_VER > 1900)  // C++11
+    #define mi_attr_noexcept   noexcept
+  #else
+    #define mi_attr_noexcept   throw()
+  #endif
+#else
+  #define mi_attr_noexcept
+#endif
+
+#if defined(__cplusplus) && (__cplusplus >= 201703)
+  #define mi_decl_nodiscard    [[nodiscard]]
+#elif (defined(__GNUC__) && (__GNUC__ >= 4)) || defined(__clang__)  // includes clang, icc, and clang-cl
+  #define mi_decl_nodiscard    __attribute__((warn_unused_result))
+#elif (_MSC_VER >= 1700)
+  #define mi_decl_nodiscard    _Check_return_
+#else
+  #define mi_decl_nodiscard
+#endif
+
+#if defined(_MSC_VER) || defined(__MINGW32__)
+  #if !defined(MI_SHARED_LIB)
+    #define mi_decl_export
+  #elif defined(MI_SHARED_LIB_EXPORT)
+    #define mi_decl_export              __declspec(dllexport)
+  #else
+    #define mi_decl_export              __declspec(dllimport)
+  #endif
+  #if defined(__MINGW32__)
+    #define mi_decl_restrict
+    #define mi_attr_malloc              __attribute__((malloc))
+  #else
+    #if (_MSC_VER >= 1900) && !defined(__EDG__)
+      #define mi_decl_restrict          __declspec(allocator) __declspec(restrict)
+    #else
+      #define mi_decl_restrict          __declspec(restrict)
+    #endif
+    #define mi_attr_malloc
+  #endif
+  #define mi_cdecl                      __cdecl
+  #define mi_attr_alloc_size(s)
+  #define mi_attr_alloc_size2(s1,s2)
+  #define mi_attr_alloc_align(p)
+#elif defined(__GNUC__)                 // includes clang and icc
+  #if defined(MI_SHARED_LIB) && defined(MI_SHARED_LIB_EXPORT)
+    #define mi_decl_export              __attribute__((visibility("default")))
+  #else
+    #define mi_decl_export
+  #endif
+  #define mi_cdecl                      // leads to warnings... __attribute__((cdecl))
+  #define mi_decl_restrict
+  #define mi_attr_malloc                __attribute__((malloc))
+  #if (defined(__clang_major__) && (__clang_major__ < 4)) || (__GNUC__ < 5)
+    #define mi_attr_alloc_size(s)
+    #define mi_attr_alloc_size2(s1,s2)
+    #define mi_attr_alloc_align(p)
+  #elif defined(__INTEL_COMPILER)
+    #define mi_attr_alloc_size(s)       __attribute__((alloc_size(s)))
+    #define mi_attr_alloc_size2(s1,s2)  __attribute__((alloc_size(s1,s2)))
+    #define mi_attr_alloc_align(p)
+  #else
+    #define mi_attr_alloc_size(s)       __attribute__((alloc_size(s)))
+    #define mi_attr_alloc_size2(s1,s2)  __attribute__((alloc_size(s1,s2)))
+    #define mi_attr_alloc_align(p)      __attribute__((alloc_align(p)))
+  #endif
+#else
+  #define mi_cdecl
+  #define mi_decl_export
+  #define mi_decl_restrict
+  #define mi_attr_malloc
+  #define mi_attr_alloc_size(s)
+  #define mi_attr_alloc_size2(s1,s2)
+  #define mi_attr_alloc_align(p)
+#endif
+
+// ------------------------------------------------------
+// Includes
+// ------------------------------------------------------
+
+#include <stddef.h>     // size_t
+#include <stdbool.h>    // bool
+
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+// ------------------------------------------------------
+// Standard malloc interface
+// ------------------------------------------------------
+
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_malloc(size_t size)  mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(1);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_calloc(size_t count, size_t size)  mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size2(1,2);
+mi_decl_nodiscard mi_decl_export void* mi_realloc(void* p, size_t newsize)      mi_attr_noexcept mi_attr_alloc_size(2);
+mi_decl_export void* mi_expand(void* p, size_t newsize)                         mi_attr_noexcept mi_attr_alloc_size(2);
+
+mi_decl_export void mi_free(void* p) mi_attr_noexcept;
+mi_decl_nodiscard mi_decl_export mi_decl_restrict char* mi_strdup(const char* s) mi_attr_noexcept mi_attr_malloc;
+mi_decl_nodiscard mi_decl_export mi_decl_restrict char* mi_strndup(const char* s, size_t n) mi_attr_noexcept mi_attr_malloc;
+mi_decl_nodiscard mi_decl_export mi_decl_restrict char* mi_realpath(const char* fname, char* resolved_name) mi_attr_noexcept mi_attr_malloc;
+
+// ------------------------------------------------------
+// Extended functionality
+// ------------------------------------------------------
+#define MI_SMALL_WSIZE_MAX  (128)
+#define MI_SMALL_SIZE_MAX   (MI_SMALL_WSIZE_MAX*sizeof(void*))
+
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_malloc_small(size_t size) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(1);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_zalloc_small(size_t size) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(1);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_zalloc(size_t size)       mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(1);
+
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_mallocn(size_t count, size_t size) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size2(1,2);
+mi_decl_nodiscard mi_decl_export void* mi_reallocn(void* p, size_t count, size_t size)        mi_attr_noexcept mi_attr_alloc_size2(2,3);
+mi_decl_nodiscard mi_decl_export void* mi_reallocf(void* p, size_t newsize)                   mi_attr_noexcept mi_attr_alloc_size(2);
+
+mi_decl_nodiscard mi_decl_export size_t mi_usable_size(const void* p) mi_attr_noexcept;
+mi_decl_nodiscard mi_decl_export size_t mi_good_size(size_t size)     mi_attr_noexcept;
+
+
+// ------------------------------------------------------
+// Internals
+// ------------------------------------------------------
+
+typedef void (mi_cdecl mi_deferred_free_fun)(bool force, unsigned long long heartbeat, void* arg);
+mi_decl_export void mi_register_deferred_free(mi_deferred_free_fun* deferred_free, void* arg) mi_attr_noexcept;
+
+typedef void (mi_cdecl mi_output_fun)(const char* msg, void* arg);
+mi_decl_export void mi_register_output(mi_output_fun* out, void* arg) mi_attr_noexcept;
+
+typedef void (mi_cdecl mi_error_fun)(int err, void* arg);
+mi_decl_export void mi_register_error(mi_error_fun* fun, void* arg);
+
+mi_decl_export void mi_collect(bool force)    mi_attr_noexcept;
+mi_decl_export int  mi_version(void)          mi_attr_noexcept;
+mi_decl_export void mi_stats_reset(void)      mi_attr_noexcept;
+mi_decl_export void mi_stats_merge(void)      mi_attr_noexcept;
+mi_decl_export void mi_stats_print(void* out) mi_attr_noexcept;  // backward compatibility: `out` is ignored and should be NULL
+mi_decl_export void mi_stats_print_out(mi_output_fun* out, void* arg) mi_attr_noexcept;
+
+mi_decl_export void mi_process_init(void)     mi_attr_noexcept;
+mi_decl_export void mi_thread_init(void)      mi_attr_noexcept;
+mi_decl_export void mi_thread_done(void)      mi_attr_noexcept;
+mi_decl_export void mi_thread_stats_print_out(mi_output_fun* out, void* arg) mi_attr_noexcept;
+
+mi_decl_export void mi_process_info(size_t* elapsed_msecs, size_t* user_msecs, size_t* system_msecs, 
+                                    size_t* current_rss, size_t* peak_rss, 
+                                    size_t* current_commit, size_t* peak_commit, size_t* page_faults) mi_attr_noexcept;
+
+// -------------------------------------------------------------------------------------
+// Aligned allocation
+// Note that `alignment` always follows `size` for consistency with unaligned
+// allocation, but unfortunately this differs from `posix_memalign` and `aligned_alloc`.
+// -------------------------------------------------------------------------------------
+#define MI_ALIGNMENT_MAX   (1024*1024UL)    // maximum supported alignment is 1MiB
+
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_malloc_aligned(size_t size, size_t alignment) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(1) mi_attr_alloc_align(2);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_malloc_aligned_at(size_t size, size_t alignment, size_t offset) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(1);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_zalloc_aligned(size_t size, size_t alignment) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(1) mi_attr_alloc_align(2);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_zalloc_aligned_at(size_t size, size_t alignment, size_t offset) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(1);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_calloc_aligned(size_t count, size_t size, size_t alignment) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size2(1,2) mi_attr_alloc_align(3);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_calloc_aligned_at(size_t count, size_t size, size_t alignment, size_t offset) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size2(1,2);
+mi_decl_nodiscard mi_decl_export void* mi_realloc_aligned(void* p, size_t newsize, size_t alignment) mi_attr_noexcept mi_attr_alloc_size(2) mi_attr_alloc_align(3);
+mi_decl_nodiscard mi_decl_export void* mi_realloc_aligned_at(void* p, size_t newsize, size_t alignment, size_t offset) mi_attr_noexcept mi_attr_alloc_size(2);
+
+
+// -------------------------------------------------------------------------------------
+// Heaps: first-class, but can only allocate from the same thread that created it.
+// -------------------------------------------------------------------------------------
+
+struct mi_heap_s;
+typedef struct mi_heap_s mi_heap_t;
+
+mi_decl_nodiscard mi_decl_export mi_heap_t* mi_heap_new(void);
+mi_decl_export void       mi_heap_delete(mi_heap_t* heap);
+mi_decl_export void       mi_heap_destroy(mi_heap_t* heap);
+mi_decl_export mi_heap_t* mi_heap_set_default(mi_heap_t* heap);
+mi_decl_export mi_heap_t* mi_heap_get_default(void);
+mi_decl_export mi_heap_t* mi_heap_get_backing(void);
+mi_decl_export void       mi_heap_collect(mi_heap_t* heap, bool force) mi_attr_noexcept;
+
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_heap_malloc(mi_heap_t* heap, size_t size) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(2);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_heap_zalloc(mi_heap_t* heap, size_t size) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(2);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_heap_calloc(mi_heap_t* heap, size_t count, size_t size) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size2(2, 3);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_heap_mallocn(mi_heap_t* heap, size_t count, size_t size) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size2(2, 3);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_heap_malloc_small(mi_heap_t* heap, size_t size) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(2);
+
+mi_decl_nodiscard mi_decl_export void* mi_heap_realloc(mi_heap_t* heap, void* p, size_t newsize)              mi_attr_noexcept mi_attr_alloc_size(3);
+mi_decl_nodiscard mi_decl_export void* mi_heap_reallocn(mi_heap_t* heap, void* p, size_t count, size_t size)  mi_attr_noexcept mi_attr_alloc_size2(3,4);
+mi_decl_nodiscard mi_decl_export void* mi_heap_reallocf(mi_heap_t* heap, void* p, size_t newsize)             mi_attr_noexcept mi_attr_alloc_size(3);
+
+mi_decl_nodiscard mi_decl_export mi_decl_restrict char* mi_heap_strdup(mi_heap_t* heap, const char* s)            mi_attr_noexcept mi_attr_malloc;
+mi_decl_nodiscard mi_decl_export mi_decl_restrict char* mi_heap_strndup(mi_heap_t* heap, const char* s, size_t n) mi_attr_noexcept mi_attr_malloc;
+mi_decl_nodiscard mi_decl_export mi_decl_restrict char* mi_heap_realpath(mi_heap_t* heap, const char* fname, char* resolved_name) mi_attr_noexcept mi_attr_malloc;
+
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_heap_malloc_aligned(mi_heap_t* heap, size_t size, size_t alignment) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(2) mi_attr_alloc_align(3);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_heap_malloc_aligned_at(mi_heap_t* heap, size_t size, size_t alignment, size_t offset) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(2);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_heap_zalloc_aligned(mi_heap_t* heap, size_t size, size_t alignment) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(2) mi_attr_alloc_align(3);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_heap_zalloc_aligned_at(mi_heap_t* heap, size_t size, size_t alignment, size_t offset) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(2);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_heap_calloc_aligned(mi_heap_t* heap, size_t count, size_t size, size_t alignment) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size2(2, 3) mi_attr_alloc_align(4);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_heap_calloc_aligned_at(mi_heap_t* heap, size_t count, size_t size, size_t alignment, size_t offset) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size2(2, 3);
+mi_decl_nodiscard mi_decl_export void* mi_heap_realloc_aligned(mi_heap_t* heap, void* p, size_t newsize, size_t alignment) mi_attr_noexcept mi_attr_alloc_size(3) mi_attr_alloc_align(4);
+mi_decl_nodiscard mi_decl_export void* mi_heap_realloc_aligned_at(mi_heap_t* heap, void* p, size_t newsize, size_t alignment, size_t offset) mi_attr_noexcept mi_attr_alloc_size(3);
+
+
+// --------------------------------------------------------------------------------
+// Zero initialized re-allocation.
+// Only valid on memory that was originally allocated with zero initialization too.
+// e.g. `mi_calloc`, `mi_zalloc`, `mi_zalloc_aligned` etc.
+// see <https://github.com/microsoft/mimalloc/issues/63#issuecomment-508272992>
+// --------------------------------------------------------------------------------
+
+mi_decl_nodiscard mi_decl_export void* mi_rezalloc(void* p, size_t newsize)                mi_attr_noexcept mi_attr_alloc_size(2);
+mi_decl_nodiscard mi_decl_export void* mi_recalloc(void* p, size_t newcount, size_t size)  mi_attr_noexcept mi_attr_alloc_size2(2,3);
+
+mi_decl_nodiscard mi_decl_export void* mi_rezalloc_aligned(void* p, size_t newsize, size_t alignment) mi_attr_noexcept mi_attr_alloc_size(2) mi_attr_alloc_align(3);
+mi_decl_nodiscard mi_decl_export void* mi_rezalloc_aligned_at(void* p, size_t newsize, size_t alignment, size_t offset) mi_attr_noexcept mi_attr_alloc_size(2);
+mi_decl_nodiscard mi_decl_export void* mi_recalloc_aligned(void* p, size_t newcount, size_t size, size_t alignment) mi_attr_noexcept mi_attr_alloc_size2(2,3) mi_attr_alloc_align(4);
+mi_decl_nodiscard mi_decl_export void* mi_recalloc_aligned_at(void* p, size_t newcount, size_t size, size_t alignment, size_t offset) mi_attr_noexcept mi_attr_alloc_size2(2,3);
+
+mi_decl_nodiscard mi_decl_export void* mi_heap_rezalloc(mi_heap_t* heap, void* p, size_t newsize)                mi_attr_noexcept mi_attr_alloc_size(3);
+mi_decl_nodiscard mi_decl_export void* mi_heap_recalloc(mi_heap_t* heap, void* p, size_t newcount, size_t size)  mi_attr_noexcept mi_attr_alloc_size2(3,4);
+
+mi_decl_nodiscard mi_decl_export void* mi_heap_rezalloc_aligned(mi_heap_t* heap, void* p, size_t newsize, size_t alignment) mi_attr_noexcept mi_attr_alloc_size(3) mi_attr_alloc_align(4);
+mi_decl_nodiscard mi_decl_export void* mi_heap_rezalloc_aligned_at(mi_heap_t* heap, void* p, size_t newsize, size_t alignment, size_t offset) mi_attr_noexcept mi_attr_alloc_size(3);
+mi_decl_nodiscard mi_decl_export void* mi_heap_recalloc_aligned(mi_heap_t* heap, void* p, size_t newcount, size_t size, size_t alignment) mi_attr_noexcept mi_attr_alloc_size2(3,4) mi_attr_alloc_align(5);
+mi_decl_nodiscard mi_decl_export void* mi_heap_recalloc_aligned_at(mi_heap_t* heap, void* p, size_t newcount, size_t size, size_t alignment, size_t offset) mi_attr_noexcept mi_attr_alloc_size2(3,4);
+
+
+// ------------------------------------------------------
+// Analysis
+// ------------------------------------------------------
+
+mi_decl_export bool mi_heap_contains_block(mi_heap_t* heap, const void* p);
+mi_decl_export bool mi_heap_check_owned(mi_heap_t* heap, const void* p);
+mi_decl_export bool mi_check_owned(const void* p);
+
+// An area of heap space contains blocks of a single size.
+typedef struct mi_heap_area_s {
+  void*  blocks;      // start of the area containing heap blocks
+  size_t reserved;    // bytes reserved for this area (virtual)
+  size_t committed;   // current available bytes for this area
+  size_t used;        // number of allocated blocks
+  size_t block_size;  // size in bytes of each block
+} mi_heap_area_t;
+
+typedef bool (mi_cdecl mi_block_visit_fun)(const mi_heap_t* heap, const mi_heap_area_t* area, void* block, size_t block_size, void* arg);
+
+mi_decl_export bool mi_heap_visit_blocks(const mi_heap_t* heap, bool visit_all_blocks, mi_block_visit_fun* visitor, void* arg);
+
+// Experimental
+mi_decl_nodiscard mi_decl_export bool mi_is_in_heap_region(const void* p) mi_attr_noexcept;
+mi_decl_nodiscard mi_decl_export bool mi_is_redirected(void) mi_attr_noexcept;
+
+mi_decl_export int mi_reserve_huge_os_pages_interleave(size_t pages, size_t numa_nodes, size_t timeout_msecs) mi_attr_noexcept;
+mi_decl_export int mi_reserve_huge_os_pages_at(size_t pages, int numa_node, size_t timeout_msecs) mi_attr_noexcept;
+
+mi_decl_export int  mi_reserve_os_memory(size_t size, bool commit, bool allow_large) mi_attr_noexcept;
+mi_decl_export bool mi_manage_os_memory(void* start, size_t size, bool is_committed, bool is_large, bool is_zero, int numa_node) mi_attr_noexcept;
+
+mi_decl_export void mi_debug_show_arenas(void) mi_attr_noexcept;
+
+// deprecated
+mi_decl_export int  mi_reserve_huge_os_pages(size_t pages, double max_secs, size_t* pages_reserved) mi_attr_noexcept;
+
+
+// ------------------------------------------------------
+// Convenience
+// ------------------------------------------------------
+
+#define mi_malloc_tp(tp)                ((tp*)mi_malloc(sizeof(tp)))
+#define mi_zalloc_tp(tp)                ((tp*)mi_zalloc(sizeof(tp)))
+#define mi_calloc_tp(tp,n)              ((tp*)mi_calloc(n,sizeof(tp)))
+#define mi_mallocn_tp(tp,n)             ((tp*)mi_mallocn(n,sizeof(tp)))
+#define mi_reallocn_tp(p,tp,n)          ((tp*)mi_reallocn(p,n,sizeof(tp)))
+#define mi_recalloc_tp(p,tp,n)          ((tp*)mi_recalloc(p,n,sizeof(tp)))
+
+#define mi_heap_malloc_tp(hp,tp)        ((tp*)mi_heap_malloc(hp,sizeof(tp)))
+#define mi_heap_zalloc_tp(hp,tp)        ((tp*)mi_heap_zalloc(hp,sizeof(tp)))
+#define mi_heap_calloc_tp(hp,tp,n)      ((tp*)mi_heap_calloc(hp,n,sizeof(tp)))
+#define mi_heap_mallocn_tp(hp,tp,n)     ((tp*)mi_heap_mallocn(hp,n,sizeof(tp)))
+#define mi_heap_reallocn_tp(hp,p,tp,n)  ((tp*)mi_heap_reallocn(hp,p,n,sizeof(tp)))
+#define mi_heap_recalloc_tp(hp,p,tp,n)  ((tp*)mi_heap_recalloc(hp,p,n,sizeof(tp)))
+
+
+// ------------------------------------------------------
+// Options
+// ------------------------------------------------------
+
+typedef enum mi_option_e {
+  // stable options
+  mi_option_show_errors,
+  mi_option_show_stats,
+  mi_option_verbose,
+  // some of the following options are experimental
+  // (deprecated options are kept for binary backward compatibility with v1.x versions)
+  mi_option_eager_commit,
+  mi_option_deprecated_eager_region_commit,
+  mi_option_deprecated_reset_decommits,
+  mi_option_large_os_pages,           // use large (2MiB) OS pages, implies eager commit
+  mi_option_reserve_huge_os_pages,    // reserve N huge OS pages (1GiB) at startup
+  mi_option_reserve_huge_os_pages_at, // reserve huge OS pages at a specific NUMA node
+  mi_option_reserve_os_memory,        // reserve specified amount of OS memory at startup
+  mi_option_segment_cache,
+  mi_option_page_reset,
+  mi_option_abandoned_page_decommit,
+  mi_option_deprecated_segment_reset,
+  mi_option_eager_commit_delay,
+  mi_option_decommit_delay,
+  mi_option_use_numa_nodes,           // 0 = use available numa nodes, otherwise use at most N nodes.
+  mi_option_limit_os_alloc,           // 1 = do not use OS memory for allocation (but only reserved arenas)
+  mi_option_os_tag,
+  mi_option_max_errors,
+  mi_option_max_warnings,
+  mi_option_allow_decommit,
+  mi_option_segment_decommit_delay,  
+  mi_option_decommit_extend_delay,
+  _mi_option_last
+} mi_option_t;
+
+
+mi_decl_nodiscard mi_decl_export bool mi_option_is_enabled(mi_option_t option);
+mi_decl_export void mi_option_enable(mi_option_t option);
+mi_decl_export void mi_option_disable(mi_option_t option);
+mi_decl_export void mi_option_set_enabled(mi_option_t option, bool enable);
+mi_decl_export void mi_option_set_enabled_default(mi_option_t option, bool enable);
+
+mi_decl_nodiscard mi_decl_export long mi_option_get(mi_option_t option);
+mi_decl_export void mi_option_set(mi_option_t option, long value);
+mi_decl_export void mi_option_set_default(mi_option_t option, long value);
+
+
+// -------------------------------------------------------------------------------------------------------
+// "mi" prefixed implementations of various posix, Unix, Windows, and C++ allocation functions.
+// (This can be convenient when providing overrides of these functions as done in `mimalloc-override.h`.)
+// note: we use `mi_cfree` as "checked free" and it checks if the pointer is in our heap before free-ing.
+// -------------------------------------------------------------------------------------------------------
+
+mi_decl_export void  mi_cfree(void* p) mi_attr_noexcept;
+mi_decl_export void* mi__expand(void* p, size_t newsize) mi_attr_noexcept;
+mi_decl_nodiscard mi_decl_export size_t mi_malloc_size(const void* p)        mi_attr_noexcept;
+mi_decl_nodiscard mi_decl_export size_t mi_malloc_good_size(size_t size)     mi_attr_noexcept;
+mi_decl_nodiscard mi_decl_export size_t mi_malloc_usable_size(const void *p) mi_attr_noexcept;
+
+mi_decl_export int mi_posix_memalign(void** p, size_t alignment, size_t size)   mi_attr_noexcept;
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_memalign(size_t alignment, size_t size) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(2) mi_attr_alloc_align(1);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_valloc(size_t size)  mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(1);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_pvalloc(size_t size) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(1);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_aligned_alloc(size_t alignment, size_t size) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(2) mi_attr_alloc_align(1);
+
+mi_decl_nodiscard mi_decl_export void* mi_reallocarray(void* p, size_t count, size_t size) mi_attr_noexcept mi_attr_alloc_size2(2,3);
+mi_decl_nodiscard mi_decl_export int   mi_reallocarr(void* p, size_t count, size_t size) mi_attr_noexcept;
+mi_decl_nodiscard mi_decl_export void* mi_aligned_recalloc(void* p, size_t newcount, size_t size, size_t alignment) mi_attr_noexcept;
+mi_decl_nodiscard mi_decl_export void* mi_aligned_offset_recalloc(void* p, size_t newcount, size_t size, size_t alignment, size_t offset) mi_attr_noexcept;
+
+mi_decl_nodiscard mi_decl_export mi_decl_restrict unsigned short* mi_wcsdup(const unsigned short* s) mi_attr_noexcept mi_attr_malloc;
+mi_decl_nodiscard mi_decl_export mi_decl_restrict unsigned char*  mi_mbsdup(const unsigned char* s)  mi_attr_noexcept mi_attr_malloc;
+mi_decl_export int mi_dupenv_s(char** buf, size_t* size, const char* name)                      mi_attr_noexcept;
+mi_decl_export int mi_wdupenv_s(unsigned short** buf, size_t* size, const unsigned short* name) mi_attr_noexcept;
+
+mi_decl_export void mi_free_size(void* p, size_t size)                           mi_attr_noexcept;
+mi_decl_export void mi_free_size_aligned(void* p, size_t size, size_t alignment) mi_attr_noexcept;
+mi_decl_export void mi_free_aligned(void* p, size_t alignment)                   mi_attr_noexcept;
+
+// The `mi_new` wrappers implement C++ semantics on out-of-memory instead of directly returning `NULL`.
+// (and call `std::get_new_handler` and potentially raise a `std::bad_alloc` exception).
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_new(size_t size)                   mi_attr_malloc mi_attr_alloc_size(1);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_new_aligned(size_t size, size_t alignment) mi_attr_malloc mi_attr_alloc_size(1) mi_attr_alloc_align(2);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_new_nothrow(size_t size)           mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(1);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_new_aligned_nothrow(size_t size, size_t alignment) mi_attr_noexcept mi_attr_malloc mi_attr_alloc_size(1) mi_attr_alloc_align(2);
+mi_decl_nodiscard mi_decl_export mi_decl_restrict void* mi_new_n(size_t count, size_t size)   mi_attr_malloc mi_attr_alloc_size2(1, 2);
+mi_decl_nodiscard mi_decl_export void* mi_new_realloc(void* p, size_t newsize)                mi_attr_alloc_size(2);
+mi_decl_nodiscard mi_decl_export void* mi_new_reallocn(void* p, size_t newcount, size_t size) mi_attr_alloc_size2(2, 3);
+
+#ifdef __cplusplus
+}
+#endif
+
+// ---------------------------------------------------------------------------------------------
+// Implement the C++ std::allocator interface for use in STL containers.
+// (note: see `mimalloc-new-delete.h` for overriding the new/delete operators globally)
+// ---------------------------------------------------------------------------------------------
+#ifdef __cplusplus
+
+#include <cstddef>     // std::size_t
+#include <cstdint>     // PTRDIFF_MAX
+#if (__cplusplus >= 201103L) || (_MSC_VER > 1900)  // C++11
+#include <type_traits> // std::true_type
+#include <utility>     // std::forward
+#endif
+
+template<class T> struct mi_stl_allocator {
+  typedef T                 value_type;
+  typedef std::size_t       size_type;
+  typedef std::ptrdiff_t    difference_type;
+  typedef value_type&       reference;
+  typedef value_type const& const_reference;
+  typedef value_type*       pointer;
+  typedef value_type const* const_pointer;
+  template <class U> struct rebind { typedef mi_stl_allocator<U> other; };
+
+  mi_stl_allocator()                                             mi_attr_noexcept = default;
+  mi_stl_allocator(const mi_stl_allocator&)                      mi_attr_noexcept = default;
+  template<class U> mi_stl_allocator(const mi_stl_allocator<U>&) mi_attr_noexcept { }
+  mi_stl_allocator  select_on_container_copy_construction() const { return *this; }
+  void              deallocate(T* p, size_type) { mi_free(p); }
+
+  #if (__cplusplus >= 201703L)  // C++17
+  mi_decl_nodiscard T* allocate(size_type count) { return static_cast<T*>(mi_new_n(count, sizeof(T))); }
+  mi_decl_nodiscard T* allocate(size_type count, const void*) { return allocate(count); }
+  #else
+  mi_decl_nodiscard pointer allocate(size_type count, const void* = 0) { return static_cast<pointer>(mi_new_n(count, sizeof(value_type))); }
+  #endif
+
+  #if ((__cplusplus >= 201103L) || (_MSC_VER > 1900))  // C++11
+  using propagate_on_container_copy_assignment = std::true_type;
+  using propagate_on_container_move_assignment = std::true_type;
+  using propagate_on_container_swap            = std::true_type;
+  using is_always_equal                        = std::true_type;
+  template <class U, class ...Args> void construct(U* p, Args&& ...args) { ::new(p) U(std::forward<Args>(args)...); }
+  template <class U> void destroy(U* p) mi_attr_noexcept { p->~U(); }
+  #else
+  void construct(pointer p, value_type const& val) { ::new(p) value_type(val); }
+  void destroy(pointer p) { p->~value_type(); }
+  #endif
+
+  size_type     max_size() const mi_attr_noexcept { return (PTRDIFF_MAX/sizeof(value_type)); }
+  pointer       address(reference x) const        { return &x; }
+  const_pointer address(const_reference x) const  { return &x; }
+};
+
+template<class T1,class T2> bool operator==(const mi_stl_allocator<T1>& , const mi_stl_allocator<T2>& ) mi_attr_noexcept { return true; }
+template<class T1,class T2> bool operator!=(const mi_stl_allocator<T1>& , const mi_stl_allocator<T2>& ) mi_attr_noexcept { return false; }
+#endif // __cplusplus
+
+#endif
diff --git a/Include/internal/pycore_mimalloc.h b/Include/internal/pycore_mimalloc.h
new file mode 100644
index 0000000000000..6d4868758c597
--- /dev/null
+++ b/Include/internal/pycore_mimalloc.h
@@ -0,0 +1,290 @@
+#ifndef Py_INTERNAL_MIMALLOC_H
+#define Py_INTERNAL_MIMALLOC_H
+
+#ifndef Py_BUILD_CORE
+#  error "this header requires Py_BUILD_CORE define"
+#endif
+
+#if defined(MIMALLOC_H) || defined(MIMALLOC_TYPES_H)
+#  error "pycore_mimalloc.h must be included before mimalloc.h"
+#endif
+
+#include "pycore_pymem.h"
+#define MI_DEBUG_UNINIT     PYMEM_CLEANBYTE
+#define MI_DEBUG_FREED      PYMEM_DEADBYTE
+#define MI_DEBUG_PADDING    PYMEM_FORBIDDENBYTE
+
+ /* ASAN builds don't use MI_DEBUG.
+  *
+  * ASAN + MI_DEBUG triggers additional checks, which can cause mimalloc
+  * to print warnings to stderr. The warnings break some tests.
+  *
+  *   mi_usable_size: pointer might not point to a valid heap region:
+  *   ...
+  *   yes, the previous pointer ... was valid after all
+  */
+#if defined(__has_feature)
+#  if __has_feature(address_sanitizer)
+#    define MI_DEBUG 0
+#  endif
+#elif defined(__GNUC__) && defined(__SANITIZE_ADDRESS__)
+#  define MI_DEBUG 0
+#endif
+
+#ifdef Py_DEBUG
+/* Debug: Perform additional checks in debug builds, see mimalloc-types.h
+ * - enable basic and internal assertion checks with MI_DEBUG 2
+ * - check for double free, invalid pointer free
+ * - use guard pages to check for buffer overflows
+ */
+#  ifndef MI_DEBUG
+#    define MI_DEBUG 2
+#  endif
+#  define MI_SECURE 4
+#else
+// Production: no debug checks, secure depends on --enable-mimalloc-secure
+#  ifndef MI_DEBUG
+#    define MI_DEBUG 0
+#  endif
+#  if defined(PY_MIMALLOC_SECURE)
+#    define MI_SECURE PY_MIMALLOC_SECURE
+#  else
+#    define MI_SECURE 0
+#  endif
+#endif
+
+/* Prefix all non-static symbols with "_Py_"
+ * nm Objects/obmalloc.o | grep -E "[CRT] _?mi" | awk '{print "#define " $3 " _Py_" $3}' | sort
+ */
+#if 1
+#define _mi_abandoned_await_readers _Py__mi_abandoned_await_readers
+#define _mi_abandoned_collect _Py__mi_abandoned_collect
+#define _mi_abandoned_reclaim_all _Py__mi_abandoned_reclaim_all
+#define mi_aligned_alloc _Py_mi_aligned_alloc
+#define mi_aligned_offset_recalloc _Py_mi_aligned_offset_recalloc
+#define mi_aligned_recalloc _Py_mi_aligned_recalloc
+#define _mi_arena_alloc_aligned _Py__mi_arena_alloc_aligned
+#define _mi_arena_alloc _Py__mi_arena_alloc
+#define _mi_arena_free _Py__mi_arena_free
+#define _mi_bin _Py__mi_bin
+#define _mi_bin_size _Py__mi_bin_size
+#define _mi_bitmap_claim_across _Py__mi_bitmap_claim_across
+#define _mi_bitmap_claim _Py__mi_bitmap_claim
+#define _mi_bitmap_is_any_claimed_across _Py__mi_bitmap_is_any_claimed_across
+#define _mi_bitmap_is_any_claimed _Py__mi_bitmap_is_any_claimed
+#define _mi_bitmap_is_claimed_across _Py__mi_bitmap_is_claimed_across
+#define _mi_bitmap_is_claimed _Py__mi_bitmap_is_claimed
+#define _mi_bitmap_try_find_claim_field _Py__mi_bitmap_try_find_claim_field
+#define _mi_bitmap_try_find_from_claim_across _Py__mi_bitmap_try_find_from_claim_across
+#define _mi_bitmap_try_find_from_claim _Py__mi_bitmap_try_find_from_claim
+#define _mi_bitmap_unclaim_across _Py__mi_bitmap_unclaim_across
+#define _mi_bitmap_unclaim _Py__mi_bitmap_unclaim
+#define _mi_block_zero_init _Py__mi_block_zero_init
+#define mi_calloc_aligned_at _Py_mi_calloc_aligned_at
+#define mi_calloc_aligned _Py_mi_calloc_aligned
+#define mi_calloc _Py_mi_calloc
+#define mi_cfree _Py_mi_cfree
+#define mi_check_owned _Py_mi_check_owned
+#define _mi_clock_end _Py__mi_clock_end
+#define _mi_clock_now _Py__mi_clock_now
+#define _mi_clock_start _Py__mi_clock_start
+#define mi_collect _Py_mi_collect
+#define _mi_commit_mask_committed_size _Py__mi_commit_mask_committed_size
+#define _mi_commit_mask_next_run _Py__mi_commit_mask_next_run
+#define _mi_current_thread_count _Py__mi_current_thread_count
+#define mi_debug_show_arenas _Py_mi_debug_show_arenas
+#define _mi_deferred_free _Py__mi_deferred_free
+#define mi_dupenv_s _Py_mi_dupenv_s
+#define _mi_error_message _Py__mi_error_message
+#define mi__expand _Py_mi__expand
+#define mi_expand _Py_mi_expand
+#define _mi_fprintf _Py__mi_fprintf
+#define _mi_fputs _Py__mi_fputs
+#define mi_free_aligned _Py_mi_free_aligned
+#define _mi_free_delayed_block _Py__mi_free_delayed_block
+#define mi_free _Py_mi_free
+#define mi_free_size_aligned _Py_mi_free_size_aligned
+#define mi_free_size _Py_mi_free_size
+#define mi_good_size _Py_mi_good_size
+#define mi_heap_calloc_aligned_at _Py_mi_heap_calloc_aligned_at
+#define mi_heap_calloc_aligned _Py_mi_heap_calloc_aligned
+#define mi_heap_calloc _Py_mi_heap_calloc
+#define mi_heap_check_owned _Py_mi_heap_check_owned
+#define _mi_heap_collect_abandon _Py__mi_heap_collect_abandon
+#define mi_heap_collect _Py_mi_heap_collect
+#define _mi_heap_collect_retired _Py__mi_heap_collect_retired
+#define mi_heap_contains_block _Py_mi_heap_contains_block
+#define _mi_heap_delayed_free _Py__mi_heap_delayed_free
+#define mi_heap_delete _Py_mi_heap_delete
+#define _mi_heap_destroy_pages _Py__mi_heap_destroy_pages
+#define mi_heap_destroy _Py_mi_heap_destroy
+#define _mi_heap_empty _Py__mi_heap_empty
+#define mi_heap_get_backing _Py_mi_heap_get_backing
+#define mi_heap_get_default _Py_mi_heap_get_default
+#define _mi_heap_main_get _Py__mi_heap_main_get
+#define mi_heap_malloc_aligned_at _Py_mi_heap_malloc_aligned_at
+#define mi_heap_malloc_aligned _Py_mi_heap_malloc_aligned
+#define mi_heap_mallocn _Py_mi_heap_mallocn
+#define mi_heap_malloc _Py_mi_heap_malloc
+#define mi_heap_malloc_small _Py_mi_heap_malloc_small
+#define _mi_heap_malloc_zero _Py__mi_heap_malloc_zero
+#define mi_heap_new _Py_mi_heap_new
+#define _mi_heap_random_next _Py__mi_heap_random_next
+#define mi_heap_realloc_aligned_at _Py_mi_heap_realloc_aligned_at
+#define mi_heap_realloc_aligned _Py_mi_heap_realloc_aligned
+#define mi_heap_reallocf _Py_mi_heap_reallocf
+#define mi_heap_reallocn _Py_mi_heap_reallocn
+#define mi_heap_realloc _Py_mi_heap_realloc
+#define _mi_heap_realloc_zero _Py__mi_heap_realloc_zero
+#define mi_heap_realpath _Py_mi_heap_realpath
+#define mi_heap_recalloc_aligned_at _Py_mi_heap_recalloc_aligned_at
+#define mi_heap_recalloc_aligned _Py_mi_heap_recalloc_aligned
+#define mi_heap_recalloc _Py_mi_heap_recalloc
+#define mi_heap_rezalloc_aligned_at _Py_mi_heap_rezalloc_aligned_at
+#define mi_heap_rezalloc_aligned _Py_mi_heap_rezalloc_aligned
+#define mi_heap_rezalloc _Py_mi_heap_rezalloc
+#define _mi_heap_set_default_direct _Py__mi_heap_set_default_direct
+#define mi_heap_set_default _Py_mi_heap_set_default
+#define mi_heap_strdup _Py_mi_heap_strdup
+#define mi_heap_strndup _Py_mi_heap_strndup
+#define mi_heap_visit_blocks _Py_mi_heap_visit_blocks
+#define mi_heap_zalloc_aligned_at _Py_mi_heap_zalloc_aligned_at
+#define mi_heap_zalloc_aligned _Py_mi_heap_zalloc_aligned
+#define mi_heap_zalloc _Py_mi_heap_zalloc
+#define mi_is_in_heap_region _Py_mi_is_in_heap_region
+#define _mi_is_main_thread _Py__mi_is_main_thread
+#define mi_is_redirected _Py_mi_is_redirected
+#define mi_malloc_aligned_at _Py_mi_malloc_aligned_at
+#define mi_malloc_aligned _Py_mi_malloc_aligned
+#define _mi_malloc_generic _Py__mi_malloc_generic
+#define mi_malloc_good_size _Py_mi_malloc_good_size
+#define mi_mallocn _Py_mi_mallocn
+#define mi_malloc _Py_mi_malloc
+#define mi_malloc_size _Py_mi_malloc_size
+#define mi_malloc_small _Py_mi_malloc_small
+#define mi_malloc_usable_size _Py_mi_malloc_usable_size
+#define mi_manage_os_memory _Py_mi_manage_os_memory
+#define mi_mbsdup _Py_mi_mbsdup
+#define mi_memalign _Py_mi_memalign
+#define mi_new_aligned_nothrow _Py_mi_new_aligned_nothrow
+#define mi_new_aligned _Py_mi_new_aligned
+#define mi_new_nothrow _Py_mi_new_nothrow
+#define mi_new_n _Py_mi_new_n
+#define mi_new _Py_mi_new
+#define mi_new_reallocn _Py_mi_new_reallocn
+#define mi_new_realloc _Py_mi_new_realloc
+#define mi_option_disable _Py_mi_option_disable
+#define mi_option_enable _Py_mi_option_enable
+#define mi_option_get _Py_mi_option_get
+#define mi_option_is_enabled _Py_mi_option_is_enabled
+#define mi_option_set_default _Py_mi_option_set_default
+#define mi_option_set_enabled_default _Py_mi_option_set_enabled_default
+#define mi_option_set_enabled _Py_mi_option_set_enabled
+#define mi_option_set _Py_mi_option_set
+#define _mi_options_init _Py__mi_options_init
+#define _mi_os_alloc_aligned _Py__mi_os_alloc_aligned
+#define _mi_os_alloc_huge_os_pages _Py__mi_os_alloc_huge_os_pages
+#define _mi_os_alloc _Py__mi_os_alloc
+#define _mi_os_commit _Py__mi_os_commit
+#define _mi_os_decommit _Py__mi_os_decommit
+#define _mi_os_free_ex _Py__mi_os_free_ex
+#define _mi_os_free_huge_pages _Py__mi_os_free_huge_pages
+#define _mi_os_free _Py__mi_os_free
+#define _mi_os_good_alloc_size _Py__mi_os_good_alloc_size
+#define _mi_os_has_overcommit _Py__mi_os_has_overcommit
+#define _mi_os_init _Py__mi_os_init
+#define _mi_os_large_page_size _Py__mi_os_large_page_size
+#define _mi_os_numa_node_count_get _Py__mi_os_numa_node_count_get
+#define _mi_os_numa_node_get _Py__mi_os_numa_node_get
+#define _mi_os_page_size _Py__mi_os_page_size
+#define _mi_os_protect _Py__mi_os_protect
+#define _mi_os_random_weak _Py__mi_os_random_weak
+#define _mi_os_reset _Py__mi_os_reset
+#define _mi_os_shrink _Py__mi_os_shrink
+#define _mi_os_unprotect _Py__mi_os_unprotect
+#define _mi_page_abandon _Py__mi_page_abandon
+#define _mi_page_empty _Py__mi_page_empty
+#define _mi_page_free_collect _Py__mi_page_free_collect
+#define _mi_page_free _Py__mi_page_free
+#define _mi_page_malloc _Py__mi_page_malloc
+#define _mi_page_ptr_unalign _Py__mi_page_ptr_unalign
+#define _mi_page_queue_append _Py__mi_page_queue_append
+#define _mi_page_reclaim _Py__mi_page_reclaim
+#define _mi_page_retire _Py__mi_page_retire
+#define _mi_page_unfull _Py__mi_page_unfull
+#define _mi_page_use_delayed_free _Py__mi_page_use_delayed_free
+#define mi_posix_memalign _Py_mi_posix_memalign
+#define _mi_preloading _Py__mi_preloading
+#define mi_process_info _Py_mi_process_info
+#define mi_process_init _Py_mi_process_init
+#define mi_pvalloc _Py_mi_pvalloc
+#define _mi_random_init _Py__mi_random_init
+#define _mi_random_next _Py__mi_random_next
+#define _mi_random_split _Py__mi_random_split
+#define mi_realloc_aligned_at _Py_mi_realloc_aligned_at
+#define mi_realloc_aligned _Py_mi_realloc_aligned
+#define mi_reallocarray _Py_mi_reallocarray
+#define mi_reallocarr _Py_mi_reallocarr
+#define mi_reallocf _Py_mi_reallocf
+#define mi_reallocn _Py_mi_reallocn
+#define mi_realloc _Py_mi_realloc
+#define mi_realpath _Py_mi_realpath
+#define mi_recalloc_aligned_at _Py_mi_recalloc_aligned_at
+#define mi_recalloc_aligned _Py_mi_recalloc_aligned
+#define mi_recalloc _Py_mi_recalloc
+#define mi_register_deferred_free _Py_mi_register_deferred_free
+#define mi_register_error _Py_mi_register_error
+#define mi_register_output _Py_mi_register_output
+#define mi_reserve_huge_os_pages_at _Py_mi_reserve_huge_os_pages_at
+#define mi_reserve_huge_os_pages_interleave _Py_mi_reserve_huge_os_pages_interleave
+#define mi_reserve_huge_os_pages _Py_mi_reserve_huge_os_pages
+#define mi_reserve_os_memory _Py_mi_reserve_os_memory
+#define mi_rezalloc_aligned_at _Py_mi_rezalloc_aligned_at
+#define mi_rezalloc_aligned _Py_mi_rezalloc_aligned
+#define mi_rezalloc _Py_mi_rezalloc
+#define _mi_segment_cache_collect _Py__mi_segment_cache_collect
+#define _mi_segment_cache_pop _Py__mi_segment_cache_pop
+#define _mi_segment_cache_push _Py__mi_segment_cache_push
+#define _mi_segment_huge_page_free _Py__mi_segment_huge_page_free
+#define _mi_segment_map_allocated_at _Py__mi_segment_map_allocated_at
+#define _mi_segment_map_freed_at _Py__mi_segment_map_freed_at
+#define _mi_segment_page_abandon _Py__mi_segment_page_abandon
+#define _mi_segment_page_alloc _Py__mi_segment_page_alloc
+#define _mi_segment_page_free _Py__mi_segment_page_free
+#define _mi_segment_page_start _Py__mi_segment_page_start
+#define _mi_segment_thread_collect _Py__mi_segment_thread_collect
+#define _mi_stat_counter_increase _Py__mi_stat_counter_increase
+#define _mi_stat_decrease _Py__mi_stat_decrease
+#define _mi_stat_increase _Py__mi_stat_increase
+#define _mi_stats_done _Py__mi_stats_done
+#define mi_stats_merge _Py_mi_stats_merge
+#define mi_stats_print_out _Py_mi_stats_print_out
+#define mi_stats_print _Py_mi_stats_print
+#define mi_stats_reset _Py_mi_stats_reset
+#define mi_strdup _Py_mi_strdup
+#define mi_strndup _Py_mi_strndup
+#define mi_thread_done _Py_mi_thread_done
+#define mi_thread_init _Py_mi_thread_init
+#define mi_thread_stats_print_out _Py_mi_thread_stats_print_out
+#define _mi_trace_message _Py__mi_trace_message
+#define mi_usable_size _Py_mi_usable_size
+#define mi_valloc _Py_mi_valloc
+#define _mi_verbose_message _Py__mi_verbose_message
+#define mi_version _Py_mi_version
+#define _mi_warning_message _Py__mi_warning_message
+#define mi_wcsdup _Py_mi_wcsdup
+#define mi_wdupenv_s _Py_mi_wdupenv_s
+#define mi_zalloc_aligned_at _Py_mi_zalloc_aligned_at
+#define mi_zalloc_aligned _Py_mi_zalloc_aligned
+#define mi_zalloc _Py_mi_zalloc
+#define mi_zalloc_small _Py_mi_zalloc_small
+#endif
+
+#define _mi_assert_fail _Py__mi_assert_fail
+#define _mi_numa_node_count _Py__mi_numa_node_count
+#define _ZSt15get_new_handlerv _Py__ZSt15get_new_handlerv
+
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+
+#endif /* !Py_INTERNAL_MIMALLOC_H */
diff --git a/Include/internal/pycore_pymem.h b/Include/internal/pycore_pymem.h
index b9eea9d4b30ad..2388553897778 100644
--- a/Include/internal/pycore_pymem.h
+++ b/Include/internal/pycore_pymem.h
@@ -103,7 +103,7 @@ void _PyObject_VirtualFree(void *, size_t size);
 PyAPI_FUNC(Py_ssize_t) _Py_GetAllocatedBlocks(void);
 
 /* Macros */
-#ifdef WITH_PYMALLOC
+#if defined(WITH_PYMALLOC) || defined(WITH_MIMALLOC)
 // Export the symbol for the 3rd party guppy3 project
 PyAPI_FUNC(int) _PyObject_DebugMallocStats(FILE *out);
 #endif
diff --git a/Lib/test/support/__init__.py b/Lib/test/support/__init__.py
index c5666d66f4782..464ff776ff3d7 100644
--- a/Lib/test/support/__init__.py
+++ b/Lib/test/support/__init__.py
@@ -1911,8 +1911,11 @@ def restore(self):
 
 
 def with_pymalloc():
-    import _testcapi
-    return _testcapi.WITH_PYMALLOC
+    return sys._malloc_info.with_pymalloc
+
+
+def with_mimalloc():
+    return sys._malloc_info.with_mimalloc
 
 
 class _ALWAYS_EQ:
diff --git a/Lib/test/test_cmd_line.py b/Lib/test/test_cmd_line.py
index 84eab71f97701..62777ce5af7fd 100644
--- a/Lib/test/test_cmd_line.py
+++ b/Lib/test/test_cmd_line.py
@@ -713,7 +713,9 @@ def test_xdev(self):
             code = "import _testcapi; print(_testcapi.pymem_getallocatorsname())"
             with support.SuppressCrashReport():
                 out = self.run_xdev("-c", code, check_exitcode=False)
-            if support.with_pymalloc():
+            if support.with_mimalloc():
+                alloc_name = "mimalloc_debug"
+            elif support.with_pymalloc():
                 alloc_name = "pymalloc_debug"
             else:
                 alloc_name = "malloc_debug"
@@ -791,7 +793,11 @@ def check_pythonmalloc(self, env_var, name):
     def test_pythonmalloc(self):
         # Test the PYTHONMALLOC environment variable
         pymalloc = support.with_pymalloc()
-        if pymalloc:
+        mimalloc = support.with_mimalloc()
+        if mimalloc:
+            default_name = 'mimalloc_debug' if Py_DEBUG else 'mimalloc'
+            default_name_debug = 'mimalloc_debug'
+        elif pymalloc:
             default_name = 'pymalloc_debug' if Py_DEBUG else 'pymalloc'
             default_name_debug = 'pymalloc_debug'
         else:
@@ -804,6 +810,11 @@ def test_pythonmalloc(self):
             ('malloc', 'malloc'),
             ('malloc_debug', 'malloc_debug'),
         ]
+        if mimalloc:
+            tests.extend((
+                ('mimalloc', 'mimalloc'),
+                ('mimalloc_debug', 'mimalloc_debug'),
+            ))
         if pymalloc:
             tests.extend((
                 ('pymalloc', 'pymalloc'),
diff --git a/Lib/test/test_decimal.py b/Lib/test/test_decimal.py
index b68cfbef23f16..d5ca6be81a22e 100644
--- a/Lib/test/test_decimal.py
+++ b/Lib/test/test_decimal.py
@@ -5510,6 +5510,11 @@ def __abs__(self):
     @unittest.skipIf(check_sanitizer(address=True, memory=True),
                      "ASAN/MSAN sanitizer defaults to crashing "
                      "instead of returning NULL for malloc failure.")
+    @unittest.skipIf(
+        sys._malloc_info.allocator.startswith("mimalloc") and
+        os.name == "posix" and os.uname().machine == "s390x",
+        reason="Test segfaults on s390x under mimalloc"
+    )
     def test_maxcontext_exact_arith(self):
 
         # Make sure that exact operations do not raise MemoryError due
diff --git a/Lib/test/test_sys.py b/Lib/test/test_sys.py
index f4deb1763b95f..517b78a4a40a0 100644
--- a/Lib/test/test_sys.py
+++ b/Lib/test/test_sys.py
@@ -10,7 +10,7 @@
 import sysconfig
 import test.support
 from test import support
-from test.support import os_helper
+from test.support import missing_compiler_executable, os_helper
 from test.support.script_helper import assert_python_ok, assert_python_failure
 from test.support import threading_helper
 from test.support import import_helper
@@ -898,17 +898,30 @@ def test_debugmallocstats(self):
         # The sysconfig vars are not available on Windows.
         if sys.platform != "win32":
             with_freelists = sysconfig.get_config_var("WITH_FREELISTS")
-            with_pymalloc = sysconfig.get_config_var("WITH_PYMALLOC")
+            pymalloc = sys._malloc_info.allocator.startswith("pymalloc")
+            mimalloc = sys._malloc_info.allocator.startswith("mimalloc")
             if with_freelists:
                 self.assertIn(b"free PyDictObjects", err)
-            if with_pymalloc:
+            if pymalloc:
                 self.assertIn(b'Small block threshold', err)
-            if not with_freelists and not with_pymalloc:
+            if mimalloc:
+                self.assertIn(b'mimalloc (version:', err)
+            if not with_freelists and not pymalloc and not mimalloc:
                 self.assertFalse(err)
 
         # The function has no parameter
         self.assertRaises(TypeError, sys._debugmallocstats, True)
 
+    @test.support.cpython_only
+    def test_malloc_info(self):
+        info = sys._malloc_info
+        self.assertEqual(len(info), 5)
+        self.assertIsInstance(info.allocator, str)
+        self.assertIsInstance(info.with_pymalloc, bool)
+        self.assertIsInstance(info.with_mimalloc, bool)
+        self.assertIsInstance(info.mimalloc_secure, int)
+        self.assertIsInstance(info.mimalloc_debug, int)
+
     @unittest.skipUnless(hasattr(sys, "getallocatedblocks"),
                          "sys.getallocatedblocks unavailable on this build")
     def test_getallocatedblocks(self):
diff --git a/Makefile.pre.in b/Makefile.pre.in
index d9b96f52ec9f7..cbd2f3eb443bc 100644
--- a/Makefile.pre.in
+++ b/Makefile.pre.in
@@ -55,6 +55,7 @@ DTRACE=         @DTRACE@
 DFLAGS=         @DFLAGS@
 DTRACE_HEADERS= @DTRACE_HEADERS@
 DTRACE_OBJS=    @DTRACE_OBJS@
+WITH_MIMALLOC=	@WITH_MIMALLOC@
 
 GNULD=		@GNULD@
 
@@ -339,6 +340,34 @@ IO_OBJS=	\
 
 LIBFFI_INCLUDEDIR=	@LIBFFI_INCLUDEDIR@
 
+##########################################################################
+# mimalloc
+
+MIMALLOC_HEADERS = \
+		$(srcdir)/Include/internal/pycore_mimalloc.h \
+		$(srcdir)/Include/internal/mimalloc/mimalloc-atomic.h \
+		$(srcdir)/Include/internal/mimalloc/mimalloc.h \
+		$(srcdir)/Include/internal/mimalloc/mimalloc-internal.h \
+		$(srcdir)/Include/internal/mimalloc/mimalloc-types.h \
+
+MIMALLOC_INCLUDES = \
+		$(srcdir)/Objects/mimalloc/alloc-aligned.c \
+		$(srcdir)/Objects/mimalloc/alloc-posix.c \
+		$(srcdir)/Objects/mimalloc/alloc.c \
+		$(srcdir)/Objects/mimalloc/arena.c \
+		$(srcdir)/Objects/mimalloc/bitmap.c \
+		$(srcdir)/Objects/mimalloc/heap.c \
+		$(srcdir)/Objects/mimalloc/init.c \
+		$(srcdir)/Objects/mimalloc/options.c \
+		$(srcdir)/Objects/mimalloc/os.c \
+		$(srcdir)/Objects/mimalloc/page.c \
+		$(srcdir)/Objects/mimalloc/random.c \
+		$(srcdir)/Objects/mimalloc/region.c \
+		$(srcdir)/Objects/mimalloc/segment.c \
+		$(srcdir)/Objects/mimalloc/segment-cache.c \
+		$(srcdir)/Objects/mimalloc/static.c \
+		$(srcdir)/Objects/mimalloc/stats.c
+
 ##########################################################################
 # Parser
 
@@ -1254,8 +1283,9 @@ Python/dynload_hpux.o: $(srcdir)/Python/dynload_hpux.c Makefile
 		-DSHLIB_EXT='"$(EXT_SUFFIX)"' \
 		-o $@ $(srcdir)/Python/dynload_hpux.c
 
-Python/sysmodule.o: $(srcdir)/Python/sysmodule.c Makefile $(srcdir)/Include/pydtrace.h
+Python/sysmodule.o: $(srcdir)/Python/sysmodule.c Makefile $(srcdir)/Include/pydtrace.h @MIMALLOC_INCLUDES@
 	$(CC) -c $(PY_CORE_CFLAGS) \
+		-I$(srcdir)/Include/internal/mimalloc \
 		-DABIFLAGS='"$(ABIFLAGS)"' \
 		$(MULTIARCH_CPPFLAGS) \
 		-o $@ $(srcdir)/Python/sysmodule.c
@@ -1616,10 +1646,10 @@ PYTHON_HEADERS= \
 		$(srcdir)/Include/internal/pycore_unionobject.h \
 		$(srcdir)/Include/internal/pycore_unicodeobject.h \
 		$(srcdir)/Include/internal/pycore_warnings.h \
+		$(srcdir)/Python/stdlib_module_names.h \
 		$(DTRACE_HEADERS) \
 		@PLATFORM_HEADERS@ \
-		\
-		$(srcdir)/Python/stdlib_module_names.h
+		@MIMALLOC_HEADERS@
 
 $(LIBRARY_OBJS) $(MODOBJS) Programs/python.o: $(PYTHON_HEADERS)
 
@@ -2121,6 +2151,11 @@ inclinstall:
 		echo $(INSTALL_DATA) $$i $(INCLUDEPY)/internal; \
 		$(INSTALL_DATA) $$i $(DESTDIR)$(INCLUDEPY)/internal; \
 	done
+	@for i in $(srcdir)/Include/internal/mimalloc/*.h; \
+	do \
+		echo $(INSTALL_DATA) $$i $(INCLUDEPY)/internal/mimalloc; \
+		$(INSTALL_DATA) $$i $(DESTDIR)$(INCLUDEPY)/internal/mimalloc; \
+	done
 	$(INSTALL_DATA) pyconfig.h $(DESTDIR)$(CONFINCLUDEPY)/pyconfig.h
 
 # Install the library and miscellaneous stuff needed for extending/embedding
@@ -2288,6 +2323,10 @@ config.status:	$(srcdir)/configure
 Python/dtoa.o: Python/dtoa.c
 	$(CC) -c $(PY_CORE_CFLAGS) $(CFLAGS_ALIASING) -o $@ $<
 
+# obmalloc includes mimalloc
+Objects/obmalloc.o: Objects/obmalloc.c @MIMALLOC_INCLUDES@
+	$(CC) -c $(PY_CORE_CFLAGS) -I$(srcdir)/Include/internal/mimalloc -o $@ $<
+
 # Run reindent on the library
 reindent:
 	./$(BUILDPYTHON) $(srcdir)/Tools/scripts/reindent.py -r $(srcdir)/Lib
diff --git a/Misc/NEWS.d/next/Core and Builtins/2022-02-06-15-50-11.bpo-46657.xea1T_.rst b/Misc/NEWS.d/next/Core and Builtins/2022-02-06-15-50-11.bpo-46657.xea1T_.rst
new file mode 100644
index 0000000000000..2da4fc18bed76
--- /dev/null
+++ b/Misc/NEWS.d/next/Core and Builtins/2022-02-06-15-50-11.bpo-46657.xea1T_.rst	
@@ -0,0 +1 @@
+[WIP] Add mimalloc memory allocator support.
diff --git a/Misc/valgrind-python.supp b/Misc/valgrind-python.supp
index c9c45ba7ed6de..b1037aa4d0bf1 100644
--- a/Misc/valgrind-python.supp
+++ b/Misc/valgrind-python.supp
@@ -497,3 +497,59 @@
    fun:PyUnicode_FSConverter
 }
 
+# mimalloc
+
+{
+   Use of uninitialised value
+   Memcheck:Value8
+   fun:_Py_DECREF
+   fun:PyUnicode_InternInPlace
+   fun:PyUnicode_InternFromString
+}
+
+{
+   Page malloc generic
+   Memcheck:Addr8
+   fun:_Py__mi_page_malloc
+   fun:_Py__mi_malloc_generic
+   fun:_Py_mi_heap_malloc
+}
+
+{
+   Page malloc small
+   Memcheck:Addr8
+   fun:_Py__mi_page_malloc
+   fun:_Py_mi_heap_malloc_small
+   fun:_Py_mi_heap_malloc
+}
+
+{
+   Realloc aligned
+   Memcheck:Addr8
+   fun:memmove
+   fun:_mi_memcpy_aligned
+   fun:_Py__mi_heap_realloc_zero
+   fun:_Py_mi_heap_realloc
+}
+
+{
+   Malloc zero
+   Memcheck:Addr8
+   fun:memset
+   fun:_Py__mi_block_zero_init
+}
+
+{
+   Page free collect
+   Memcheck:Addr8
+   fun:mi_block_nextx
+   fun:mi_block_next
+}
+
+{
+   Page free collect set
+   Memcheck:Addr8
+   fun:mi_block_set_nextx
+   fun:mi_block_set_next
+}
+
diff --git a/Objects/mimalloc/LICENSE b/Objects/mimalloc/LICENSE
new file mode 100644
index 0000000000000..670b668a0c928
--- /dev/null
+++ b/Objects/mimalloc/LICENSE
@@ -0,0 +1,21 @@
+MIT License
+
+Copyright (c) 2018-2021 Microsoft Corporation, Daan Leijen
+
+Permission is hereby granted, free of charge, to any person obtaining a copy
+of this software and associated documentation files (the "Software"), to deal
+in the Software without restriction, including without limitation the rights
+to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
+copies of the Software, and to permit persons to whom the Software is
+furnished to do so, subject to the following conditions:
+
+The above copyright notice and this permission notice shall be included in all
+copies or substantial portions of the Software.
+
+THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
+IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
+FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
+AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
+LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
+OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
+SOFTWARE.
diff --git a/Objects/mimalloc/alloc-aligned.c b/Objects/mimalloc/alloc-aligned.c
new file mode 100644
index 0000000000000..fce0fd7498527
--- /dev/null
+++ b/Objects/mimalloc/alloc-aligned.c
@@ -0,0 +1,261 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2021, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+
+#include <string.h>  // memset
+
+// ------------------------------------------------------
+// Aligned Allocation
+// ------------------------------------------------------
+
+// Fallback primitive aligned allocation -- split out for better codegen
+static mi_decl_noinline void* mi_heap_malloc_zero_aligned_at_fallback(mi_heap_t* const heap, const size_t size, const size_t alignment, const size_t offset, const bool zero) mi_attr_noexcept
+{
+  mi_assert_internal(size <= PTRDIFF_MAX);
+  mi_assert_internal(alignment!=0 && _mi_is_power_of_two(alignment) && alignment <= MI_ALIGNMENT_MAX);
+
+  const uintptr_t align_mask = alignment-1;  // for any x, `(x & align_mask) == (x % alignment)`
+  const size_t padsize = size + MI_PADDING_SIZE;
+
+  // use regular allocation if it is guaranteed to fit the alignment constraints
+  if (offset==0 && alignment<=padsize && padsize<=MI_MAX_ALIGN_GUARANTEE && (padsize&align_mask)==0) {
+    void* p = _mi_heap_malloc_zero(heap, size, zero);
+    mi_assert_internal(p == NULL || ((uintptr_t)p % alignment) == 0);
+    return p;
+  }
+
+  // otherwise over-allocate
+  void* p = _mi_heap_malloc_zero(heap, size + alignment - 1, zero);
+  if (p == NULL) return NULL;
+
+  // .. and align within the allocation
+  uintptr_t adjust = alignment - (((uintptr_t)p + offset) & align_mask);
+  mi_assert_internal(adjust <= alignment);
+  void* aligned_p = (adjust == alignment ? p : (void*)((uintptr_t)p + adjust));
+  if (aligned_p != p) mi_page_set_has_aligned(_mi_ptr_page(p), true);
+  mi_assert_internal(((uintptr_t)aligned_p + offset) % alignment == 0);
+  mi_assert_internal(p == _mi_page_ptr_unalign(_mi_ptr_segment(aligned_p), _mi_ptr_page(aligned_p), aligned_p));
+  return aligned_p;
+}
+
+// Primitive aligned allocation
+static void* mi_heap_malloc_zero_aligned_at(mi_heap_t* const heap, const size_t size, const size_t alignment, const size_t offset, const bool zero) mi_attr_noexcept
+{
+  // note: we don't require `size > offset`, we just guarantee that the address at offset is aligned regardless of the allocated size.
+  mi_assert(alignment > 0);
+  if (mi_unlikely(alignment==0 || !_mi_is_power_of_two(alignment))) { // require power-of-two (see <https://en.cppreference.com/w/c/memory/aligned_alloc>)
+    #if MI_DEBUG > 0
+    _mi_error_message(EOVERFLOW, "aligned allocation requires the alignment to be a power-of-two (size %zu, alignment %zu)\n", size, alignment);
+    #endif
+    return NULL;
+  }
+  if (mi_unlikely(alignment > MI_ALIGNMENT_MAX)) {  // we cannot align at a boundary larger than this (or otherwise we cannot find segment headers)
+    #if MI_DEBUG > 0
+    _mi_error_message(EOVERFLOW, "aligned allocation has a maximum alignment of %zu (size %zu, alignment %zu)\n", MI_ALIGNMENT_MAX, size, alignment);
+    #endif
+    return NULL;
+  }
+  if (mi_unlikely(size > PTRDIFF_MAX)) {          // we don't allocate more than PTRDIFF_MAX (see <https://sourceware.org/ml/libc-announce/2019/msg00001.html>)                                                    
+    #if MI_DEBUG > 0
+    _mi_error_message(EOVERFLOW, "aligned allocation request is too large (size %zu, alignment %zu)\n", size, alignment);
+    #endif
+    return NULL;
+  }
+  const uintptr_t align_mask = alignment-1;       // for any x, `(x & align_mask) == (x % alignment)`
+  const size_t padsize = size + MI_PADDING_SIZE;  // note: cannot overflow due to earlier size > PTRDIFF_MAX check
+
+  // try first if there happens to be a small block available with just the right alignment
+  if (mi_likely(padsize <= MI_SMALL_SIZE_MAX)) {
+    mi_page_t* page = _mi_heap_get_free_small_page(heap, padsize);
+    const bool is_aligned = (((uintptr_t)page->free+offset) & align_mask)==0;
+    if (mi_likely(page->free != NULL && is_aligned))
+    {
+      #if MI_STAT>1
+      mi_heap_stat_increase(heap, malloc, size);
+      #endif
+      void* p = _mi_page_malloc(heap, page, padsize); // TODO: inline _mi_page_malloc
+      mi_assert_internal(p != NULL);
+      mi_assert_internal(((uintptr_t)p + offset) % alignment == 0);
+      if (zero) { _mi_block_zero_init(page, p, size); }
+      return p;
+    }
+  }
+  // fallback
+  return mi_heap_malloc_zero_aligned_at_fallback(heap, size, alignment, offset, zero);
+}
+
+
+// ------------------------------------------------------
+// Optimized mi_heap_malloc_aligned / mi_malloc_aligned
+// ------------------------------------------------------
+
+mi_decl_restrict void* mi_heap_malloc_aligned_at(mi_heap_t* heap, size_t size, size_t alignment, size_t offset) mi_attr_noexcept {
+  return mi_heap_malloc_zero_aligned_at(heap, size, alignment, offset, false);
+}
+
+mi_decl_restrict void* mi_heap_malloc_aligned(mi_heap_t* heap, size_t size, size_t alignment) mi_attr_noexcept {
+  #if !MI_PADDING
+  // without padding, any small sized allocation is naturally aligned (see also `_mi_segment_page_start`)
+  if (!_mi_is_power_of_two(alignment)) return NULL;
+  if (mi_likely(_mi_is_power_of_two(size) && size >= alignment && size <= MI_SMALL_SIZE_MAX))
+  #else
+  // with padding, we can only guarantee this for fixed alignments
+  if (mi_likely((alignment == sizeof(void*) || (alignment == MI_MAX_ALIGN_SIZE && size > (MI_MAX_ALIGN_SIZE/2)))
+                && size <= MI_SMALL_SIZE_MAX))
+  #endif
+  {
+    // fast path for common alignment and size
+    return mi_heap_malloc_small(heap, size);
+  }
+  else {
+    return mi_heap_malloc_aligned_at(heap, size, alignment, 0);
+  }
+}
+
+// ------------------------------------------------------
+// Aligned Allocation
+// ------------------------------------------------------
+
+mi_decl_restrict void* mi_heap_zalloc_aligned_at(mi_heap_t* heap, size_t size, size_t alignment, size_t offset) mi_attr_noexcept {
+  return mi_heap_malloc_zero_aligned_at(heap, size, alignment, offset, true);
+}
+
+mi_decl_restrict void* mi_heap_zalloc_aligned(mi_heap_t* heap, size_t size, size_t alignment) mi_attr_noexcept {
+  return mi_heap_zalloc_aligned_at(heap, size, alignment, 0);
+}
+
+mi_decl_restrict void* mi_heap_calloc_aligned_at(mi_heap_t* heap, size_t count, size_t size, size_t alignment, size_t offset) mi_attr_noexcept {
+  size_t total;
+  if (mi_count_size_overflow(count, size, &total)) return NULL;
+  return mi_heap_zalloc_aligned_at(heap, total, alignment, offset);
+}
+
+mi_decl_restrict void* mi_heap_calloc_aligned(mi_heap_t* heap, size_t count, size_t size, size_t alignment) mi_attr_noexcept {
+  return mi_heap_calloc_aligned_at(heap,count,size,alignment,0);
+}
+
+mi_decl_restrict void* mi_malloc_aligned_at(size_t size, size_t alignment, size_t offset) mi_attr_noexcept {
+  return mi_heap_malloc_aligned_at(mi_get_default_heap(), size, alignment, offset);
+}
+
+mi_decl_restrict void* mi_malloc_aligned(size_t size, size_t alignment) mi_attr_noexcept {
+  return mi_heap_malloc_aligned(mi_get_default_heap(), size, alignment);
+}
+
+mi_decl_restrict void* mi_zalloc_aligned_at(size_t size, size_t alignment, size_t offset) mi_attr_noexcept {
+  return mi_heap_zalloc_aligned_at(mi_get_default_heap(), size, alignment, offset);
+}
+
+mi_decl_restrict void* mi_zalloc_aligned(size_t size, size_t alignment) mi_attr_noexcept {
+  return mi_heap_zalloc_aligned(mi_get_default_heap(), size, alignment);
+}
+
+mi_decl_restrict void* mi_calloc_aligned_at(size_t count, size_t size, size_t alignment, size_t offset) mi_attr_noexcept {
+  return mi_heap_calloc_aligned_at(mi_get_default_heap(), count, size, alignment, offset);
+}
+
+mi_decl_restrict void* mi_calloc_aligned(size_t count, size_t size, size_t alignment) mi_attr_noexcept {
+  return mi_heap_calloc_aligned(mi_get_default_heap(), count, size, alignment);
+}
+
+
+// ------------------------------------------------------
+// Aligned re-allocation
+// ------------------------------------------------------
+
+static void* mi_heap_realloc_zero_aligned_at(mi_heap_t* heap, void* p, size_t newsize, size_t alignment, size_t offset, bool zero) mi_attr_noexcept {
+  mi_assert(alignment > 0);
+  if (alignment <= sizeof(uintptr_t)) return _mi_heap_realloc_zero(heap,p,newsize,zero);
+  if (p == NULL) return mi_heap_malloc_zero_aligned_at(heap,newsize,alignment,offset,zero);
+  size_t size = mi_usable_size(p);
+  if (newsize <= size && newsize >= (size - (size / 2))
+      && (((uintptr_t)p + offset) % alignment) == 0) {
+    return p;  // reallocation still fits, is aligned and not more than 50% waste
+  }
+  else {
+    void* newp = mi_heap_malloc_aligned_at(heap,newsize,alignment,offset);
+    if (newp != NULL) {
+      if (zero && newsize > size) {
+        const mi_page_t* page = _mi_ptr_page(newp);
+        if (page->is_zero) {
+          // already zero initialized
+          mi_assert_expensive(mi_mem_is_zero(newp,newsize));
+        }
+        else {
+          // also set last word in the previous allocation to zero to ensure any padding is zero-initialized
+          size_t start = (size >= sizeof(intptr_t) ? size - sizeof(intptr_t) : 0);
+          memset((uint8_t*)newp + start, 0, newsize - start);
+        }
+      }
+      _mi_memcpy_aligned(newp, p, (newsize > size ? size : newsize));
+      mi_free(p); // only free if successful
+    }
+    return newp;
+  }
+}
+
+static void* mi_heap_realloc_zero_aligned(mi_heap_t* heap, void* p, size_t newsize, size_t alignment, bool zero) mi_attr_noexcept {
+  mi_assert(alignment > 0);
+  if (alignment <= sizeof(uintptr_t)) return _mi_heap_realloc_zero(heap,p,newsize,zero);
+  size_t offset = ((uintptr_t)p % alignment); // use offset of previous allocation (p can be NULL)
+  return mi_heap_realloc_zero_aligned_at(heap,p,newsize,alignment,offset,zero);
+}
+
+void* mi_heap_realloc_aligned_at(mi_heap_t* heap, void* p, size_t newsize, size_t alignment, size_t offset) mi_attr_noexcept {
+  return mi_heap_realloc_zero_aligned_at(heap,p,newsize,alignment,offset,false);
+}
+
+void* mi_heap_realloc_aligned(mi_heap_t* heap, void* p, size_t newsize, size_t alignment) mi_attr_noexcept {
+  return mi_heap_realloc_zero_aligned(heap,p,newsize,alignment,false);
+}
+
+void* mi_heap_rezalloc_aligned_at(mi_heap_t* heap, void* p, size_t newsize, size_t alignment, size_t offset) mi_attr_noexcept {
+  return mi_heap_realloc_zero_aligned_at(heap, p, newsize, alignment, offset, true);
+}
+
+void* mi_heap_rezalloc_aligned(mi_heap_t* heap, void* p, size_t newsize, size_t alignment) mi_attr_noexcept {
+  return mi_heap_realloc_zero_aligned(heap, p, newsize, alignment, true);
+}
+
+void* mi_heap_recalloc_aligned_at(mi_heap_t* heap, void* p, size_t newcount, size_t size, size_t alignment, size_t offset) mi_attr_noexcept {
+  size_t total;
+  if (mi_count_size_overflow(newcount, size, &total)) return NULL;
+  return mi_heap_rezalloc_aligned_at(heap, p, total, alignment, offset);
+}
+
+void* mi_heap_recalloc_aligned(mi_heap_t* heap, void* p, size_t newcount, size_t size, size_t alignment) mi_attr_noexcept {
+  size_t total;
+  if (mi_count_size_overflow(newcount, size, &total)) return NULL;
+  return mi_heap_rezalloc_aligned(heap, p, total, alignment);
+}
+
+void* mi_realloc_aligned_at(void* p, size_t newsize, size_t alignment, size_t offset) mi_attr_noexcept {
+  return mi_heap_realloc_aligned_at(mi_get_default_heap(), p, newsize, alignment, offset);
+}
+
+void* mi_realloc_aligned(void* p, size_t newsize, size_t alignment) mi_attr_noexcept {
+  return mi_heap_realloc_aligned(mi_get_default_heap(), p, newsize, alignment);
+}
+
+void* mi_rezalloc_aligned_at(void* p, size_t newsize, size_t alignment, size_t offset) mi_attr_noexcept {
+  return mi_heap_rezalloc_aligned_at(mi_get_default_heap(), p, newsize, alignment, offset);
+}
+
+void* mi_rezalloc_aligned(void* p, size_t newsize, size_t alignment) mi_attr_noexcept {
+  return mi_heap_rezalloc_aligned(mi_get_default_heap(), p, newsize, alignment);
+}
+
+void* mi_recalloc_aligned_at(void* p, size_t newcount, size_t size, size_t alignment, size_t offset) mi_attr_noexcept {
+  return mi_heap_recalloc_aligned_at(mi_get_default_heap(), p, newcount, size, alignment, offset);
+}
+
+void* mi_recalloc_aligned(void* p, size_t newcount, size_t size, size_t alignment) mi_attr_noexcept {
+  return mi_heap_recalloc_aligned(mi_get_default_heap(), p, newcount, size, alignment);
+}
+
diff --git a/Objects/mimalloc/alloc-override-osx.c b/Objects/mimalloc/alloc-override-osx.c
new file mode 100644
index 0000000000000..9c331cae62867
--- /dev/null
+++ b/Objects/mimalloc/alloc-override-osx.c
@@ -0,0 +1,458 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2022, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+
+#if defined(MI_MALLOC_OVERRIDE)
+
+#if !defined(__APPLE__)
+#error "this file should only be included on macOS"
+#endif
+
+/* ------------------------------------------------------
+   Override system malloc on macOS
+   This is done through the malloc zone interface.
+   It seems to be most robust in combination with interposing
+   though or otherwise we may get zone errors as there are could
+   be allocations done by the time we take over the 
+   zone. 
+------------------------------------------------------ */
+
+#include <AvailabilityMacros.h>
+#include <malloc/malloc.h>
+#include <string.h>  // memset
+#include <stdlib.h>
+
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+#if defined(MAC_OS_X_VERSION_10_6) && (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6)
+// only available from OSX 10.6
+extern malloc_zone_t* malloc_default_purgeable_zone(void) __attribute__((weak_import));
+#endif
+
+/* ------------------------------------------------------
+   malloc zone members
+------------------------------------------------------ */
+
+static size_t zone_size(malloc_zone_t* zone, const void* p) {
+  MI_UNUSED(zone);
+  if (!mi_is_in_heap_region(p)){ return 0; } // not our pointer, bail out
+  return mi_usable_size(p);
+}
+
+static void* zone_malloc(malloc_zone_t* zone, size_t size) {
+  MI_UNUSED(zone);
+  return mi_malloc(size);
+}
+
+static void* zone_calloc(malloc_zone_t* zone, size_t count, size_t size) {
+  MI_UNUSED(zone);
+  return mi_calloc(count, size);
+}
+
+static void* zone_valloc(malloc_zone_t* zone, size_t size) {
+  MI_UNUSED(zone);
+  return mi_malloc_aligned(size, _mi_os_page_size());
+}
+
+static void zone_free(malloc_zone_t* zone, void* p) {
+  MI_UNUSED(zone);
+  mi_free(p);
+}
+
+static void* zone_realloc(malloc_zone_t* zone, void* p, size_t newsize) {
+  MI_UNUSED(zone);
+  return mi_realloc(p, newsize);
+}
+
+static void* zone_memalign(malloc_zone_t* zone, size_t alignment, size_t size) {
+  MI_UNUSED(zone);
+  return mi_malloc_aligned(size,alignment);
+}
+
+static void zone_destroy(malloc_zone_t* zone) {
+  MI_UNUSED(zone);
+  // todo: ignore for now?
+}
+
+static unsigned zone_batch_malloc(malloc_zone_t* zone, size_t size, void** ps, unsigned count) {
+  size_t i;
+  for (i = 0; i < count; i++) {
+    ps[i] = zone_malloc(zone, size);
+    if (ps[i] == NULL) break;
+  }
+  return i;
+}
+
+static void zone_batch_free(malloc_zone_t* zone, void** ps, unsigned count) {
+  for(size_t i = 0; i < count; i++) {
+    zone_free(zone, ps[i]);
+    ps[i] = NULL;
+  }
+}
+
+static size_t zone_pressure_relief(malloc_zone_t* zone, size_t size) {
+  MI_UNUSED(zone); MI_UNUSED(size);
+  mi_collect(false);
+  return 0;
+}
+
+static void zone_free_definite_size(malloc_zone_t* zone, void* p, size_t size) {
+  MI_UNUSED(size);
+  zone_free(zone,p);
+}
+
+static boolean_t zone_claimed_address(malloc_zone_t* zone, void* p) {
+  MI_UNUSED(zone);
+  return mi_is_in_heap_region(p);
+}
+
+
+/* ------------------------------------------------------
+   Introspection members
+------------------------------------------------------ */
+
+static kern_return_t intro_enumerator(task_t task, void* p,
+                            unsigned type_mask, vm_address_t zone_address,
+                            memory_reader_t reader,
+                            vm_range_recorder_t recorder)
+{
+  // todo: enumerate all memory
+  MI_UNUSED(task); MI_UNUSED(p); MI_UNUSED(type_mask); MI_UNUSED(zone_address);
+  MI_UNUSED(reader); MI_UNUSED(recorder);
+  return KERN_SUCCESS;
+}
+
+static size_t intro_good_size(malloc_zone_t* zone, size_t size) {
+  MI_UNUSED(zone);
+  return mi_good_size(size);
+}
+
+static boolean_t intro_check(malloc_zone_t* zone) {
+  MI_UNUSED(zone);
+  return true;
+}
+
+static void intro_print(malloc_zone_t* zone, boolean_t verbose) {
+  MI_UNUSED(zone); MI_UNUSED(verbose);
+  mi_stats_print(NULL);
+}
+
+static void intro_log(malloc_zone_t* zone, void* p) {
+  MI_UNUSED(zone); MI_UNUSED(p);
+  // todo?
+}
+
+static void intro_force_lock(malloc_zone_t* zone) {
+  MI_UNUSED(zone);
+  // todo?
+}
+
+static void intro_force_unlock(malloc_zone_t* zone) {
+  MI_UNUSED(zone);
+  // todo?
+}
+
+static void intro_statistics(malloc_zone_t* zone, malloc_statistics_t* stats) {
+  MI_UNUSED(zone);
+  // todo...
+  stats->blocks_in_use = 0;
+  stats->size_in_use = 0;
+  stats->max_size_in_use = 0;
+  stats->size_allocated = 0;
+}
+
+static boolean_t intro_zone_locked(malloc_zone_t* zone) {
+  MI_UNUSED(zone);
+  return false;
+}
+
+
+/* ------------------------------------------------------
+  At process start, override the default allocator
+------------------------------------------------------ */
+
+#if defined(__GNUC__) && !defined(__clang__)
+#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
+#endif
+
+#if defined(__clang__)
+#pragma clang diagnostic ignored "-Wc99-extensions"
+#endif
+
+static malloc_introspection_t mi_introspect = {
+  .enumerator = &intro_enumerator,
+  .good_size = &intro_good_size,
+  .check = &intro_check,
+  .print = &intro_print,
+  .log = &intro_log,
+  .force_lock = &intro_force_lock,
+  .force_unlock = &intro_force_unlock,
+#if defined(MAC_OS_X_VERSION_10_6) && (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6)
+  .statistics = &intro_statistics,
+  .zone_locked = &intro_zone_locked,
+#endif
+};
+
+static malloc_zone_t mi_malloc_zone = {
+  // note: even with designators, the order is important for C++ compilation
+  //.reserved1 = NULL,
+  //.reserved2 = NULL,
+  .size = &zone_size,
+  .malloc = &zone_malloc,
+  .calloc = &zone_calloc,
+  .valloc = &zone_valloc,
+  .free = &zone_free,
+  .realloc = &zone_realloc,
+  .destroy = &zone_destroy,
+  .zone_name = "mimalloc",
+  .batch_malloc = &zone_batch_malloc,
+  .batch_free = &zone_batch_free,
+  .introspect = &mi_introspect,  
+#if defined(MAC_OS_X_VERSION_10_6) && (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6)
+  #if defined(MAC_OS_X_VERSION_10_14) && (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_14)
+  .version = 10,
+  #else
+  .version = 9,
+  #endif
+  // switch to version 9+ on OSX 10.6 to support memalign.
+  .memalign = &zone_memalign,
+  .free_definite_size = &zone_free_definite_size,
+  .pressure_relief = &zone_pressure_relief,
+  #if defined(MAC_OS_X_VERSION_10_14) && (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_14)
+  .claimed_address = &zone_claimed_address,
+  #endif
+#else
+  .version = 4,
+#endif
+};
+
+#ifdef __cplusplus
+}
+#endif
+
+
+#if defined(MI_OSX_INTERPOSE) && defined(MI_SHARED_LIB_EXPORT)
+
+// ------------------------------------------------------
+// Override malloc_xxx and malloc_zone_xxx api's to use only 
+// our mimalloc zone. Since even the loader uses malloc
+// on macOS, this ensures that all allocations go through
+// mimalloc (as all calls are interposed).
+// The main `malloc`, `free`, etc calls are interposed in `alloc-override.c`,
+// Here, we also override macOS specific API's like
+// `malloc_zone_calloc` etc. see <https://github.com/aosm/libmalloc/blob/master/man/malloc_zone_malloc.3>
+// ------------------------------------------------------
+
+static inline malloc_zone_t* mi_get_default_zone(void)
+{
+  static bool init;
+  if (mi_unlikely(!init)) { 
+    init = true;
+    malloc_zone_register(&mi_malloc_zone);  // by calling register we avoid a zone error on free (see <http://eatmyrandom.blogspot.com/2010/03/mallocfree-interception-on-mac-os-x.html>)
+  }
+  return &mi_malloc_zone;
+}
+
+mi_decl_externc int  malloc_jumpstart(uintptr_t cookie);
+mi_decl_externc void _malloc_fork_prepare(void);
+mi_decl_externc void _malloc_fork_parent(void);
+mi_decl_externc void _malloc_fork_child(void);
+
+
+static malloc_zone_t* mi_malloc_create_zone(vm_size_t size, unsigned flags) {
+  MI_UNUSED(size); MI_UNUSED(flags);
+  return mi_get_default_zone();
+}
+
+static malloc_zone_t* mi_malloc_default_zone (void) {   
+  return mi_get_default_zone();
+}
+
+static malloc_zone_t* mi_malloc_default_purgeable_zone(void) {
+  return mi_get_default_zone();
+}
+
+static void mi_malloc_destroy_zone(malloc_zone_t* zone) {
+  MI_UNUSED(zone);
+  // nothing.
+}
+
+static kern_return_t mi_malloc_get_all_zones (task_t task, memory_reader_t mr, vm_address_t** addresses, unsigned* count) {
+  MI_UNUSED(task); MI_UNUSED(mr);
+  if (addresses != NULL) *addresses = NULL;
+  if (count != NULL) *count = 0;
+  return KERN_SUCCESS;
+}
+
+static const char* mi_malloc_get_zone_name(malloc_zone_t* zone) {  
+  return (zone == NULL ? mi_malloc_zone.zone_name : zone->zone_name);
+}
+
+static void mi_malloc_set_zone_name(malloc_zone_t* zone, const char* name) {  
+  MI_UNUSED(zone); MI_UNUSED(name);
+}
+
+static int mi_malloc_jumpstart(uintptr_t cookie) {
+  MI_UNUSED(cookie);
+  return 1; // or 0 for no error?
+}
+
+static void mi__malloc_fork_prepare(void) {
+  // nothing  
+}
+static void mi__malloc_fork_parent(void) {
+  // nothing
+}
+static void mi__malloc_fork_child(void) {
+  // nothing
+}
+
+static void mi_malloc_printf(const char* fmt, ...) {
+  MI_UNUSED(fmt);
+}
+
+static bool zone_check(malloc_zone_t* zone) {
+  MI_UNUSED(zone);
+  return true;
+}
+
+static malloc_zone_t* zone_from_ptr(const void* p) {
+  MI_UNUSED(p);
+  return mi_get_default_zone();
+}
+
+static void zone_log(malloc_zone_t* zone, void* p) {
+  MI_UNUSED(zone); MI_UNUSED(p);
+}
+
+static void zone_print(malloc_zone_t* zone, bool b) {
+  MI_UNUSED(zone); MI_UNUSED(b);
+}
+
+static void zone_print_ptr_info(void* p) {
+  MI_UNUSED(p);
+}
+
+static void zone_register(malloc_zone_t* zone) {
+  MI_UNUSED(zone);
+}
+
+static void zone_unregister(malloc_zone_t* zone) {
+  MI_UNUSED(zone);
+}
+
+// use interposing so `DYLD_INSERT_LIBRARIES` works without `DYLD_FORCE_FLAT_NAMESPACE=1`
+// See: <https://books.google.com/books?id=K8vUkpOXhN4C&pg=PA73>
+struct mi_interpose_s {
+  const void* replacement;
+  const void* target;
+};
+#define MI_INTERPOSE_FUN(oldfun,newfun) { (const void*)&newfun, (const void*)&oldfun }
+#define MI_INTERPOSE_MI(fun)            MI_INTERPOSE_FUN(fun,mi_##fun)
+#define MI_INTERPOSE_ZONE(fun)          MI_INTERPOSE_FUN(malloc_##fun,fun)
+__attribute__((used)) static const struct mi_interpose_s _mi_zone_interposes[]  __attribute__((section("__DATA, __interpose"))) =
+{
+
+  MI_INTERPOSE_MI(malloc_create_zone),
+  MI_INTERPOSE_MI(malloc_default_purgeable_zone),
+  MI_INTERPOSE_MI(malloc_default_zone),
+  MI_INTERPOSE_MI(malloc_destroy_zone),
+  MI_INTERPOSE_MI(malloc_get_all_zones),
+  MI_INTERPOSE_MI(malloc_get_zone_name),
+  MI_INTERPOSE_MI(malloc_jumpstart),  
+  MI_INTERPOSE_MI(malloc_printf),
+  MI_INTERPOSE_MI(malloc_set_zone_name),
+  MI_INTERPOSE_MI(_malloc_fork_child),
+  MI_INTERPOSE_MI(_malloc_fork_parent),
+  MI_INTERPOSE_MI(_malloc_fork_prepare),
+
+  MI_INTERPOSE_ZONE(zone_batch_free),
+  MI_INTERPOSE_ZONE(zone_batch_malloc),
+  MI_INTERPOSE_ZONE(zone_calloc),
+  MI_INTERPOSE_ZONE(zone_check),
+  MI_INTERPOSE_ZONE(zone_free),
+  MI_INTERPOSE_ZONE(zone_from_ptr),
+  MI_INTERPOSE_ZONE(zone_log),
+  MI_INTERPOSE_ZONE(zone_malloc),
+  MI_INTERPOSE_ZONE(zone_memalign),
+  MI_INTERPOSE_ZONE(zone_print),
+  MI_INTERPOSE_ZONE(zone_print_ptr_info),
+  MI_INTERPOSE_ZONE(zone_realloc),
+  MI_INTERPOSE_ZONE(zone_register),
+  MI_INTERPOSE_ZONE(zone_unregister),
+  MI_INTERPOSE_ZONE(zone_valloc)
+};
+
+
+#else
+
+// ------------------------------------------------------
+// hook into the zone api's without interposing
+// This is the official way of adding an allocator but
+// it seems less robust than using interpose.
+// ------------------------------------------------------
+
+static inline malloc_zone_t* mi_get_default_zone(void)
+{
+  // The first returned zone is the real default
+  malloc_zone_t** zones = NULL;
+  unsigned count = 0;
+  kern_return_t ret = malloc_get_all_zones(0, NULL, (vm_address_t**)&zones, &count);
+  if (ret == KERN_SUCCESS && count > 0) {
+    return zones[0];
+  }
+  else {
+    // fallback
+    return malloc_default_zone();
+  }
+}
+
+#if defined(__clang__)
+__attribute__((constructor(0))) 
+#else
+__attribute__((constructor))      // seems not supported by g++-11 on the M1
+#endif
+static void _mi_macos_override_malloc() {
+  malloc_zone_t* purgeable_zone = NULL;
+
+  #if defined(MAC_OS_X_VERSION_10_6) && (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6)
+  // force the purgeable zone to exist to avoid strange bugs
+  if (malloc_default_purgeable_zone) {
+    purgeable_zone = malloc_default_purgeable_zone();
+  }
+  #endif
+
+  // Register our zone.
+  // thomcc: I think this is still needed to put us in the zone list.
+  malloc_zone_register(&mi_malloc_zone);
+  // Unregister the default zone, this makes our zone the new default
+  // as that was the last registered.
+  malloc_zone_t *default_zone = mi_get_default_zone();
+  // thomcc: Unsure if the next test is *always* false or just false in the
+  // cases I've tried. I'm also unsure if the code inside is needed. at all
+  if (default_zone != &mi_malloc_zone) {
+    malloc_zone_unregister(default_zone);
+
+    // Reregister the default zone so free and realloc in that zone keep working.
+    malloc_zone_register(default_zone);
+  }
+
+  // Unregister, and re-register the purgeable_zone to avoid bugs if it occurs
+  // earlier than the default zone.
+  if (purgeable_zone != NULL) {
+    malloc_zone_unregister(purgeable_zone);
+    malloc_zone_register(purgeable_zone);
+  }
+
+}
+#endif  // MI_OSX_INTERPOSE
+
+#endif // MI_MALLOC_OVERRIDE
diff --git a/Objects/mimalloc/alloc-override.c b/Objects/mimalloc/alloc-override.c
new file mode 100644
index 0000000000000..6bbe4aac74a55
--- /dev/null
+++ b/Objects/mimalloc/alloc-override.c
@@ -0,0 +1,274 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2021, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+
+#if !defined(MI_IN_ALLOC_C)
+#error "this file should be included from 'alloc.c' (so aliases can work)"
+#endif
+
+#if defined(MI_MALLOC_OVERRIDE) && defined(_WIN32) && !(defined(MI_SHARED_LIB) && defined(_DLL))
+#error "It is only possible to override "malloc" on Windows when building as a DLL (and linking the C runtime as a DLL)"
+#endif
+
+#if defined(MI_MALLOC_OVERRIDE) && !(defined(_WIN32)) 
+
+#if defined(__APPLE__)
+mi_decl_externc void   vfree(void* p);
+mi_decl_externc size_t malloc_size(const void* p);
+mi_decl_externc size_t malloc_good_size(size_t size);
+#endif
+
+// helper definition for C override of C++ new
+typedef struct mi_nothrow_s { int _tag; } mi_nothrow_t;
+
+// ------------------------------------------------------
+// Override system malloc
+// ------------------------------------------------------
+
+#if (defined(__GNUC__) || defined(__clang__)) && !defined(__APPLE__) && !defined(MI_VALGRIND)
+  // gcc, clang: use aliasing to alias the exported function to one of our `mi_` functions
+  #if (defined(__GNUC__) && __GNUC__ >= 9)
+    #pragma GCC diagnostic ignored "-Wattributes"  // or we get warnings that nodiscard is ignored on a forward
+    #define MI_FORWARD(fun)      __attribute__((alias(#fun), used, visibility("default"), copy(fun)));
+  #else
+    #define MI_FORWARD(fun)      __attribute__((alias(#fun), used, visibility("default")));
+  #endif
+  #define MI_FORWARD1(fun,x)      MI_FORWARD(fun)
+  #define MI_FORWARD2(fun,x,y)    MI_FORWARD(fun)
+  #define MI_FORWARD3(fun,x,y,z)  MI_FORWARD(fun)
+  #define MI_FORWARD0(fun,x)      MI_FORWARD(fun)
+  #define MI_FORWARD02(fun,x,y)   MI_FORWARD(fun)
+#else
+  // otherwise use forwarding by calling our `mi_` function 
+  #define MI_FORWARD1(fun,x)      { return fun(x); }
+  #define MI_FORWARD2(fun,x,y)    { return fun(x,y); }
+  #define MI_FORWARD3(fun,x,y,z)  { return fun(x,y,z); }
+  #define MI_FORWARD0(fun,x)      { fun(x); }
+  #define MI_FORWARD02(fun,x,y)   { fun(x,y); }
+#endif
+
+#if defined(__APPLE__) && defined(MI_SHARED_LIB_EXPORT) && defined(MI_OSX_INTERPOSE)    
+  // define MI_OSX_IS_INTERPOSED as we should not provide forwarding definitions for 
+  // functions that are interposed (or the interposing does not work)
+  #define MI_OSX_IS_INTERPOSED
+
+  // use interposing so `DYLD_INSERT_LIBRARIES` works without `DYLD_FORCE_FLAT_NAMESPACE=1`
+  // See: <https://books.google.com/books?id=K8vUkpOXhN4C&pg=PA73>
+  struct mi_interpose_s {
+    const void* replacement;
+    const void* target;
+  };
+  #define MI_INTERPOSE_FUN(oldfun,newfun) { (const void*)&newfun, (const void*)&oldfun }
+  #define MI_INTERPOSE_MI(fun)            MI_INTERPOSE_FUN(fun,mi_##fun)
+  
+  __attribute__((used)) static struct mi_interpose_s _mi_interposes[]  __attribute__((section("__DATA, __interpose"))) =
+  {
+    MI_INTERPOSE_MI(malloc),
+    MI_INTERPOSE_MI(calloc),
+    MI_INTERPOSE_MI(realloc),
+    MI_INTERPOSE_MI(strdup),
+    MI_INTERPOSE_MI(strndup),
+    MI_INTERPOSE_MI(realpath),
+    MI_INTERPOSE_MI(posix_memalign),
+    MI_INTERPOSE_MI(reallocf),
+    MI_INTERPOSE_MI(valloc),
+    MI_INTERPOSE_MI(malloc_size),
+    MI_INTERPOSE_MI(malloc_good_size),
+    MI_INTERPOSE_MI(aligned_alloc),
+    #ifdef MI_OSX_ZONE
+    // we interpose malloc_default_zone in alloc-override-osx.c so we can use mi_free safely
+    MI_INTERPOSE_MI(free),
+    MI_INTERPOSE_FUN(vfree,mi_free),
+    #else
+    // sometimes code allocates from default zone but deallocates using plain free :-( (like NxHashResizeToCapacity <https://github.com/nneonneo/osx-10.9-opensource/blob/master/objc4-551.1/runtime/hashtable2.mm>)
+    MI_INTERPOSE_FUN(free,mi_cfree), // use safe free that checks if pointers are from us
+    MI_INTERPOSE_FUN(vfree,mi_cfree),
+    #endif
+  };
+
+  #ifdef __cplusplus
+  extern "C" {
+    void  _ZdlPv(void* p);   // delete
+    void  _ZdaPv(void* p);   // delete[]
+    void  _ZdlPvm(void* p, size_t n);  // delete
+    void  _ZdaPvm(void* p, size_t n);  // delete[]
+    void* _Znwm(size_t n);  // new
+    void* _Znam(size_t n);  // new[]
+    void* _ZnwmRKSt9nothrow_t(size_t n, mi_nothrow_t tag); // new nothrow
+    void* _ZnamRKSt9nothrow_t(size_t n, mi_nothrow_t tag); // new[] nothrow
+  }  
+  __attribute__((used)) static struct mi_interpose_s _mi_cxx_interposes[]  __attribute__((section("__DATA, __interpose"))) =
+  {
+    MI_INTERPOSE_FUN(_ZdlPv,mi_free),
+    MI_INTERPOSE_FUN(_ZdaPv,mi_free),
+    MI_INTERPOSE_FUN(_ZdlPvm,mi_free_size),
+    MI_INTERPOSE_FUN(_ZdaPvm,mi_free_size),
+    MI_INTERPOSE_FUN(_Znwm,mi_new),
+    MI_INTERPOSE_FUN(_Znam,mi_new),
+    MI_INTERPOSE_FUN(_ZnwmRKSt9nothrow_t,mi_new_nothrow),
+    MI_INTERPOSE_FUN(_ZnamRKSt9nothrow_t,mi_new_nothrow),
+  };
+  #endif // __cplusplus
+
+#elif defined(_MSC_VER)
+  // cannot override malloc unless using a dll.
+  // we just override new/delete which does work in a static library.
+#else
+  // On all other systems forward to our API  
+  void* malloc(size_t size)              MI_FORWARD1(mi_malloc, size)
+  void* calloc(size_t size, size_t n)    MI_FORWARD2(mi_calloc, size, n)
+  void* realloc(void* p, size_t newsize) MI_FORWARD2(mi_realloc, p, newsize)
+  void  free(void* p)                    MI_FORWARD0(mi_free, p)
+#endif
+
+#if (defined(__GNUC__) || defined(__clang__)) && !defined(__APPLE__)
+#pragma GCC visibility push(default)
+#endif
+
+// ------------------------------------------------------
+// Override new/delete
+// This is not really necessary as they usually call
+// malloc/free anyway, but it improves performance.
+// ------------------------------------------------------
+#ifdef __cplusplus
+  // ------------------------------------------------------
+  // With a C++ compiler we override the new/delete operators.
+  // see <https://en.cppreference.com/w/cpp/memory/new/operator_new>
+  // ------------------------------------------------------
+  #include <new>
+
+  #ifndef MI_OSX_IS_INTERPOSED
+    void operator delete(void* p) noexcept              MI_FORWARD0(mi_free,p)
+    void operator delete[](void* p) noexcept            MI_FORWARD0(mi_free,p)
+
+    void* operator new(std::size_t n) noexcept(false)   MI_FORWARD1(mi_new,n)
+    void* operator new[](std::size_t n) noexcept(false) MI_FORWARD1(mi_new,n)
+
+    void* operator new  (std::size_t n, const std::nothrow_t& tag) noexcept { MI_UNUSED(tag); return mi_new_nothrow(n); }
+    void* operator new[](std::size_t n, const std::nothrow_t& tag) noexcept { MI_UNUSED(tag); return mi_new_nothrow(n); }
+
+    #if (__cplusplus >= 201402L || _MSC_VER >= 1916)
+    void operator delete  (void* p, std::size_t n) noexcept MI_FORWARD02(mi_free_size,p,n)
+    void operator delete[](void* p, std::size_t n) noexcept MI_FORWARD02(mi_free_size,p,n)
+    #endif
+  #endif
+
+  #if (__cplusplus > 201402L && defined(__cpp_aligned_new)) && (!defined(__GNUC__) || (__GNUC__ > 5))
+  void operator delete  (void* p, std::align_val_t al) noexcept { mi_free_aligned(p, static_cast<size_t>(al)); }
+  void operator delete[](void* p, std::align_val_t al) noexcept { mi_free_aligned(p, static_cast<size_t>(al)); }
+  void operator delete  (void* p, std::size_t n, std::align_val_t al) noexcept { mi_free_size_aligned(p, n, static_cast<size_t>(al)); };
+  void operator delete[](void* p, std::size_t n, std::align_val_t al) noexcept { mi_free_size_aligned(p, n, static_cast<size_t>(al)); };
+
+  void* operator new( std::size_t n, std::align_val_t al)   noexcept(false) { return mi_new_aligned(n, static_cast<size_t>(al)); }
+  void* operator new[]( std::size_t n, std::align_val_t al) noexcept(false) { return mi_new_aligned(n, static_cast<size_t>(al)); }
+  void* operator new  (std::size_t n, std::align_val_t al, const std::nothrow_t&) noexcept { return mi_new_aligned_nothrow(n, static_cast<size_t>(al)); }
+  void* operator new[](std::size_t n, std::align_val_t al, const std::nothrow_t&) noexcept { return mi_new_aligned_nothrow(n, static_cast<size_t>(al)); }
+  #endif
+
+#elif (defined(__GNUC__) || defined(__clang__)) 
+  // ------------------------------------------------------
+  // Override by defining the mangled C++ names of the operators (as
+  // used by GCC and CLang).
+  // See <https://itanium-cxx-abi.github.io/cxx-abi/abi.html#mangling>
+  // ------------------------------------------------------
+  
+  void _ZdlPv(void* p)            MI_FORWARD0(mi_free,p) // delete
+  void _ZdaPv(void* p)            MI_FORWARD0(mi_free,p) // delete[]
+  void _ZdlPvm(void* p, size_t n) MI_FORWARD02(mi_free_size,p,n)
+  void _ZdaPvm(void* p, size_t n) MI_FORWARD02(mi_free_size,p,n)
+  void _ZdlPvSt11align_val_t(void* p, size_t al)            { mi_free_aligned(p,al); }
+  void _ZdaPvSt11align_val_t(void* p, size_t al)            { mi_free_aligned(p,al); }
+  void _ZdlPvmSt11align_val_t(void* p, size_t n, size_t al) { mi_free_size_aligned(p,n,al); }
+  void _ZdaPvmSt11align_val_t(void* p, size_t n, size_t al) { mi_free_size_aligned(p,n,al); }
+  
+  #if (MI_INTPTR_SIZE==8)
+    void* _Znwm(size_t n)                             MI_FORWARD1(mi_new,n)  // new 64-bit
+    void* _Znam(size_t n)                             MI_FORWARD1(mi_new,n)  // new[] 64-bit
+    void* _ZnwmRKSt9nothrow_t(size_t n, mi_nothrow_t tag) { MI_UNUSED(tag); return mi_new_nothrow(n); }
+    void* _ZnamRKSt9nothrow_t(size_t n, mi_nothrow_t tag) { MI_UNUSED(tag); return mi_new_nothrow(n); }     
+    void* _ZnwmSt11align_val_t(size_t n, size_t al)   MI_FORWARD2(mi_new_aligned, n, al)
+    void* _ZnamSt11align_val_t(size_t n, size_t al)   MI_FORWARD2(mi_new_aligned, n, al)
+    void* _ZnwmSt11align_val_tRKSt9nothrow_t(size_t n, size_t al, mi_nothrow_t tag) { MI_UNUSED(tag); return mi_new_aligned_nothrow(n,al); }
+    void* _ZnamSt11align_val_tRKSt9nothrow_t(size_t n, size_t al, mi_nothrow_t tag) { MI_UNUSED(tag); return mi_new_aligned_nothrow(n,al); }
+  #elif (MI_INTPTR_SIZE==4)
+    void* _Znwj(size_t n)                             MI_FORWARD1(mi_new,n)  // new 64-bit
+    void* _Znaj(size_t n)                             MI_FORWARD1(mi_new,n)  // new[] 64-bit
+    void* _ZnwjRKSt9nothrow_t(size_t n, mi_nothrow_t tag) { MI_UNUSED(tag); return mi_new_nothrow(n); }
+    void* _ZnajRKSt9nothrow_t(size_t n, mi_nothrow_t tag) { MI_UNUSED(tag); return mi_new_nothrow(n); }   
+    void* _ZnwjSt11align_val_t(size_t n, size_t al)   MI_FORWARD2(mi_new_aligned, n, al)
+    void* _ZnajSt11align_val_t(size_t n, size_t al)   MI_FORWARD2(mi_new_aligned, n, al)
+    void* _ZnwjSt11align_val_tRKSt9nothrow_t(size_t n, size_t al, mi_nothrow_t tag) { MI_UNUSED(tag); return mi_new_aligned_nothrow(n,al); }
+    void* _ZnajSt11align_val_tRKSt9nothrow_t(size_t n, size_t al, mi_nothrow_t tag) { MI_UNUSED(tag); return mi_new_aligned_nothrow(n,al); }
+  #else
+    #error "define overloads for new/delete for this platform (just for performance, can be skipped)"
+  #endif
+#endif // __cplusplus
+
+// ------------------------------------------------------
+// Further Posix & Unix functions definitions
+// ------------------------------------------------------
+
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+#ifndef MI_OSX_IS_INTERPOSED
+  // Forward Posix/Unix calls as well
+  void*  reallocf(void* p, size_t newsize) MI_FORWARD2(mi_reallocf,p,newsize)
+  size_t malloc_size(const void* p)        MI_FORWARD1(mi_usable_size,p)
+  #if !defined(__ANDROID__) && !defined(__FreeBSD__)
+  size_t malloc_usable_size(void *p)       MI_FORWARD1(mi_usable_size,p)
+  #else
+  size_t malloc_usable_size(const void *p) MI_FORWARD1(mi_usable_size,p)
+  #endif
+
+  // No forwarding here due to aliasing/name mangling issues
+  void*  valloc(size_t size)               { return mi_valloc(size); }
+  void   vfree(void* p)                    { mi_free(p); }                
+  size_t malloc_good_size(size_t size)     { return mi_malloc_good_size(size); }
+  int    posix_memalign(void** p, size_t alignment, size_t size) { return mi_posix_memalign(p, alignment, size); }
+  
+  // `aligned_alloc` is only available when __USE_ISOC11 is defined.
+  // Note: Conda has a custom glibc where `aligned_alloc` is declared `static inline` and we cannot
+  // override it, but both _ISOC11_SOURCE and __USE_ISOC11 are undefined in Conda GCC7 or GCC9.
+  // Fortunately, in the case where `aligned_alloc` is declared as `static inline` it
+  // uses internally `memalign`, `posix_memalign`, or `_aligned_malloc` so we  can avoid overriding it ourselves.
+  #if __USE_ISOC11 
+  void* aligned_alloc(size_t alignment, size_t size) { return mi_aligned_alloc(alignment, size); }
+  #endif
+#endif
+
+// no forwarding here due to aliasing/name mangling issues
+void  cfree(void* p)                                    { mi_free(p); } 
+void* pvalloc(size_t size)                              { return mi_pvalloc(size); }
+void* reallocarray(void* p, size_t count, size_t size)  { return mi_reallocarray(p, count, size); }
+int   reallocarr(void* p, size_t count, size_t size)    { return mi_reallocarr(p, count, size); }
+void* memalign(size_t alignment, size_t size)           { return mi_memalign(alignment, size); }
+void* _aligned_malloc(size_t alignment, size_t size)    { return mi_aligned_alloc(alignment, size); }
+
+#if defined(__GLIBC__) && defined(__linux__)
+  // forward __libc interface (needed for glibc-based Linux distributions)
+  void* __libc_malloc(size_t size)                      MI_FORWARD1(mi_malloc,size)
+  void* __libc_calloc(size_t count, size_t size)        MI_FORWARD2(mi_calloc,count,size)
+  void* __libc_realloc(void* p, size_t size)            MI_FORWARD2(mi_realloc,p,size)
+  void  __libc_free(void* p)                            MI_FORWARD0(mi_free,p)
+  void  __libc_cfree(void* p)                           MI_FORWARD0(mi_free,p)
+
+  void* __libc_valloc(size_t size)                      { return mi_valloc(size); }
+  void* __libc_pvalloc(size_t size)                     { return mi_pvalloc(size); }
+  void* __libc_memalign(size_t alignment, size_t size)  { return mi_memalign(alignment,size); }
+  int   __posix_memalign(void** p, size_t alignment, size_t size) { return mi_posix_memalign(p,alignment,size); }
+#endif
+
+#ifdef __cplusplus
+}
+#endif
+
+#if (defined(__GNUC__) || defined(__clang__)) && !defined(__APPLE__)
+#pragma GCC visibility pop
+#endif
+
+#endif // MI_MALLOC_OVERRIDE && !_WIN32
diff --git a/Objects/mimalloc/alloc-posix.c b/Objects/mimalloc/alloc-posix.c
new file mode 100644
index 0000000000000..ee5babe192cec
--- /dev/null
+++ b/Objects/mimalloc/alloc-posix.c
@@ -0,0 +1,181 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2021, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+
+// ------------------------------------------------------------------------
+// mi prefixed publi definitions of various Posix, Unix, and C++ functions
+// for convenience and used when overriding these functions.
+// ------------------------------------------------------------------------
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+
+// ------------------------------------------------------
+// Posix & Unix functions definitions
+// ------------------------------------------------------
+
+#include <errno.h>
+#include <string.h>  // memset
+#include <stdlib.h>  // getenv
+
+#ifdef _MSC_VER
+#pragma warning(disable:4996)  // getenv _wgetenv
+#endif
+
+#ifndef EINVAL
+#define EINVAL 22
+#endif
+#ifndef ENOMEM
+#define ENOMEM 12
+#endif
+
+
+size_t mi_malloc_size(const void* p) mi_attr_noexcept {
+  //if (!mi_is_in_heap_region(p)) return 0;
+  return mi_usable_size(p);
+}
+
+size_t mi_malloc_usable_size(const void *p) mi_attr_noexcept {
+  //if (!mi_is_in_heap_region(p)) return 0;
+  return mi_usable_size(p);
+}
+
+size_t mi_malloc_good_size(size_t size) mi_attr_noexcept {
+  return mi_good_size(size);
+}
+
+void mi_cfree(void* p) mi_attr_noexcept {
+  if (mi_is_in_heap_region(p)) {
+    mi_free(p);
+  }
+}
+
+int mi_posix_memalign(void** p, size_t alignment, size_t size) mi_attr_noexcept {
+  // Note: The spec dictates we should not modify `*p` on an error. (issue#27)
+  // <http://man7.org/linux/man-pages/man3/posix_memalign.3.html>
+  if (p == NULL) return EINVAL;
+  if (alignment % sizeof(void*) != 0) return EINVAL;                   // natural alignment
+  if (alignment==0 || !_mi_is_power_of_two(alignment)) return EINVAL;  // not a power of 2
+  void* q = mi_malloc_aligned(size, alignment);
+  if (q==NULL && size != 0) return ENOMEM;
+  mi_assert_internal(((uintptr_t)q % alignment) == 0);
+  *p = q;
+  return 0;
+}
+
+mi_decl_restrict void* mi_memalign(size_t alignment, size_t size) mi_attr_noexcept {
+  void* p = mi_malloc_aligned(size, alignment);
+  mi_assert_internal(((uintptr_t)p % alignment) == 0);
+  return p;
+}
+
+mi_decl_restrict void* mi_valloc(size_t size) mi_attr_noexcept {
+  return mi_memalign( _mi_os_page_size(), size );
+}
+
+mi_decl_restrict void* mi_pvalloc(size_t size) mi_attr_noexcept {
+  size_t psize = _mi_os_page_size();
+  if (size >= SIZE_MAX - psize) return NULL; // overflow
+  size_t asize = _mi_align_up(size, psize);
+  return mi_malloc_aligned(asize, psize);
+}
+
+mi_decl_restrict void* mi_aligned_alloc(size_t alignment, size_t size) mi_attr_noexcept {
+  if (mi_unlikely((size&(alignment-1)) != 0)) { // C11 requires alignment>0 && integral multiple, see <https://en.cppreference.com/w/c/memory/aligned_alloc>
+    #if MI_DEBUG > 0
+    _mi_error_message(EOVERFLOW, "(mi_)aligned_alloc requires the size to be an integral multiple of the alignment (size %zu, alignment %zu)\n", size, alignment);
+    #endif
+    return NULL;
+  }
+  // C11 also requires alignment to be a power-of-two which is checked in mi_malloc_aligned
+  void* p = mi_malloc_aligned(size, alignment);
+  mi_assert_internal(((uintptr_t)p % alignment) == 0);
+  return p;
+}
+
+void* mi_reallocarray( void* p, size_t count, size_t size ) mi_attr_noexcept {  // BSD
+  void* newp = mi_reallocn(p,count,size);
+  if (newp==NULL) { errno = ENOMEM; }
+  return newp;
+}
+
+int mi_reallocarr( void* p, size_t count, size_t size ) mi_attr_noexcept { // NetBSD
+  mi_assert(p != NULL);
+  if (p == NULL) {
+    errno = EINVAL;
+    return EINVAL;
+  }
+  void** op = (void**)p;  
+  void* newp = mi_reallocarray(*op, count, size);
+  if (mi_unlikely(newp == NULL)) return errno;
+  *op = newp;
+  return 0;
+}
+
+void* mi__expand(void* p, size_t newsize) mi_attr_noexcept {  // Microsoft
+  void* res = mi_expand(p, newsize);
+  if (res == NULL) { errno = ENOMEM; }
+  return res;
+}
+
+mi_decl_restrict unsigned short* mi_wcsdup(const unsigned short* s) mi_attr_noexcept {
+  if (s==NULL) return NULL;
+  size_t len;
+  for(len = 0; s[len] != 0; len++) { }
+  size_t size = (len+1)*sizeof(unsigned short);
+  unsigned short* p = (unsigned short*)mi_malloc(size);
+  if (p != NULL) {
+    _mi_memcpy(p,s,size);
+  }
+  return p;
+}
+
+mi_decl_restrict unsigned char* mi_mbsdup(const unsigned char* s)  mi_attr_noexcept {
+  return (unsigned char*)mi_strdup((const char*)s);
+}
+
+int mi_dupenv_s(char** buf, size_t* size, const char* name) mi_attr_noexcept {
+  if (buf==NULL || name==NULL) return EINVAL;
+  if (size != NULL) *size = 0;
+  char* p = getenv(name);        // mscver warning 4996
+  if (p==NULL) {
+    *buf = NULL;
+  }
+  else {
+    *buf = mi_strdup(p);
+    if (*buf==NULL) return ENOMEM;
+    if (size != NULL) *size = strlen(p);
+  }
+  return 0;
+}
+
+int mi_wdupenv_s(unsigned short** buf, size_t* size, const unsigned short* name) mi_attr_noexcept {
+  if (buf==NULL || name==NULL) return EINVAL;
+  if (size != NULL) *size = 0;
+#if !defined(_WIN32) || (defined(WINAPI_FAMILY) && (WINAPI_FAMILY != WINAPI_FAMILY_DESKTOP_APP))
+  // not supported
+  *buf = NULL;
+  return EINVAL;
+#else
+  unsigned short* p = (unsigned short*)_wgetenv((const wchar_t*)name);  // msvc warning 4996
+  if (p==NULL) {
+    *buf = NULL;
+  }
+  else {
+    *buf = mi_wcsdup(p);
+    if (*buf==NULL) return ENOMEM;
+    if (size != NULL) *size = wcslen((const wchar_t*)p);
+  }
+  return 0;
+#endif
+}
+
+void* mi_aligned_offset_recalloc(void* p, size_t newcount, size_t size, size_t alignment, size_t offset) mi_attr_noexcept { // Microsoft
+  return mi_recalloc_aligned_at(p, newcount, size, alignment, offset);
+}
+
+void* mi_aligned_recalloc(void* p, size_t newcount, size_t size, size_t alignment) mi_attr_noexcept { // Microsoft
+  return mi_recalloc_aligned(p, newcount, size, alignment);
+}
diff --git a/Objects/mimalloc/alloc.c b/Objects/mimalloc/alloc.c
new file mode 100644
index 0000000000000..8cf72429e5767
--- /dev/null
+++ b/Objects/mimalloc/alloc.c
@@ -0,0 +1,914 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2022, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+#ifndef _DEFAULT_SOURCE
+#define _DEFAULT_SOURCE   // for realpath() on Linux
+#endif
+
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+#include "mimalloc-atomic.h"
+
+#include <string.h>  // memset, strlen
+#include <stdlib.h>  // malloc, exit
+
+#define MI_IN_ALLOC_C
+#include "alloc-override.c"
+#undef MI_IN_ALLOC_C
+
+// ------------------------------------------------------
+// Allocation
+// ------------------------------------------------------
+
+// Fast allocation in a page: just pop from the free list.
+// Fall back to generic allocation only if the list is empty.
+extern inline void* _mi_page_malloc(mi_heap_t* heap, mi_page_t* page, size_t size) mi_attr_noexcept {
+  mi_assert_internal(page->xblock_size==0||mi_page_block_size(page) >= size);
+  mi_block_t* const block = page->free;
+  if (mi_unlikely(block == NULL)) {
+    return _mi_malloc_generic(heap, size); 
+  }
+  mi_assert_internal(block != NULL && _mi_ptr_page(block) == page);
+  // pop from the free list
+  page->used++;
+  page->free = mi_block_next(page, block);
+  mi_assert_internal(page->free == NULL || _mi_ptr_page(page->free) == page);
+
+#if (MI_DEBUG>0)
+  if (!page->is_zero) { memset(block, MI_DEBUG_UNINIT, size); }
+#elif (MI_SECURE!=0)
+  block->next = 0;  // don't leak internal data
+#endif
+
+#if (MI_STAT>0)
+  const size_t bsize = mi_page_usable_block_size(page);
+  if (bsize <= MI_LARGE_OBJ_SIZE_MAX) {
+    mi_heap_stat_increase(heap, normal, bsize);
+    mi_heap_stat_counter_increase(heap, normal_count, 1);
+#if (MI_STAT>1)
+    const size_t bin = _mi_bin(bsize);
+    mi_heap_stat_increase(heap, normal_bins[bin], 1);
+#endif
+  }
+#endif
+
+#if (MI_PADDING > 0) && defined(MI_ENCODE_FREELIST)
+  mi_padding_t* const padding = (mi_padding_t*)((uint8_t*)block + mi_page_usable_block_size(page));
+  ptrdiff_t delta = ((uint8_t*)padding - (uint8_t*)block - (size - MI_PADDING_SIZE));
+  mi_assert_internal(delta >= 0 && mi_page_usable_block_size(page) >= (size - MI_PADDING_SIZE + delta));
+  padding->canary = (uint32_t)(mi_ptr_encode(page,block,page->keys));
+  padding->delta  = (uint32_t)(delta);
+  uint8_t* fill = (uint8_t*)padding - delta;
+  const size_t maxpad = (delta > MI_MAX_ALIGN_SIZE ? MI_MAX_ALIGN_SIZE : delta); // set at most N initial padding bytes
+  for (size_t i = 0; i < maxpad; i++) { fill[i] = MI_DEBUG_PADDING; }
+#endif
+
+  return block;
+}
+
+// allocate a small block
+extern inline mi_decl_restrict void* mi_heap_malloc_small(mi_heap_t* heap, size_t size) mi_attr_noexcept {
+  mi_assert(heap!=NULL);
+  mi_assert(heap->thread_id == 0 || heap->thread_id == _mi_thread_id()); // heaps are thread local
+  mi_assert(size <= MI_SMALL_SIZE_MAX);
+  #if (MI_PADDING)
+  if (size == 0) {
+    size = sizeof(void*);
+  }
+  #endif
+  mi_page_t* page = _mi_heap_get_free_small_page(heap,size + MI_PADDING_SIZE);
+  void* p = _mi_page_malloc(heap, page, size + MI_PADDING_SIZE);
+  mi_assert_internal(p==NULL || mi_usable_size(p) >= size);
+  #if MI_STAT>1
+  if (p != NULL) {
+    if (!mi_heap_is_initialized(heap)) { heap = mi_get_default_heap(); }
+    mi_heap_stat_increase(heap, malloc, mi_usable_size(p));
+  }
+  #endif
+  return p;
+}
+
+extern inline mi_decl_restrict void* mi_malloc_small(size_t size) mi_attr_noexcept {
+  return mi_heap_malloc_small(mi_get_default_heap(), size);
+}
+
+// The main allocation function
+extern inline mi_decl_restrict void* mi_heap_malloc(mi_heap_t* heap, size_t size) mi_attr_noexcept {
+  if (mi_likely(size <= MI_SMALL_SIZE_MAX)) {
+    return mi_heap_malloc_small(heap, size);
+  }
+  else {
+    mi_assert(heap!=NULL);
+    mi_assert(heap->thread_id == 0 || heap->thread_id == _mi_thread_id()); // heaps are thread local
+    void* const p = _mi_malloc_generic(heap, size + MI_PADDING_SIZE);      // note: size can overflow but it is detected in malloc_generic
+    mi_assert_internal(p == NULL || mi_usable_size(p) >= size);
+    #if MI_STAT>1
+    if (p != NULL) {
+      if (!mi_heap_is_initialized(heap)) { heap = mi_get_default_heap(); }
+      mi_heap_stat_increase(heap, malloc, mi_usable_size(p));
+    }
+    #endif
+    return p;
+  }
+}
+
+extern inline mi_decl_restrict void* mi_malloc(size_t size) mi_attr_noexcept {
+  return mi_heap_malloc(mi_get_default_heap(), size);
+}
+
+
+void _mi_block_zero_init(const mi_page_t* page, void* p, size_t size) {
+  // note: we need to initialize the whole usable block size to zero, not just the requested size,
+  // or the recalloc/rezalloc functions cannot safely expand in place (see issue #63)
+  MI_UNUSED(size);
+  mi_assert_internal(p != NULL);
+  mi_assert_internal(mi_usable_size(p) >= size); // size can be zero
+  mi_assert_internal(_mi_ptr_page(p)==page);
+  if (page->is_zero && size > sizeof(mi_block_t)) {
+    // already zero initialized memory
+    ((mi_block_t*)p)->next = 0;  // clear the free list pointer
+    mi_assert_expensive(mi_mem_is_zero(p, mi_usable_size(p)));
+  }
+  else {
+    // otherwise memset
+    memset(p, 0, mi_usable_size(p));
+  }
+}
+
+// zero initialized small block
+mi_decl_restrict void* mi_zalloc_small(size_t size) mi_attr_noexcept {
+  void* p = mi_malloc_small(size);
+  if (p != NULL) {
+    _mi_block_zero_init(_mi_ptr_page(p), p, size);  // todo: can we avoid getting the page again?
+  }
+  return p;
+}
+
+void* _mi_heap_malloc_zero(mi_heap_t* heap, size_t size, bool zero) {
+  void* p = mi_heap_malloc(heap,size);
+  if (zero && p != NULL) {
+    _mi_block_zero_init(_mi_ptr_page(p),p,size);  // todo: can we avoid getting the page again?
+  }
+  return p;
+}
+
+extern inline mi_decl_restrict void* mi_heap_zalloc(mi_heap_t* heap, size_t size) mi_attr_noexcept {
+  return _mi_heap_malloc_zero(heap, size, true);
+}
+
+mi_decl_restrict void* mi_zalloc(size_t size) mi_attr_noexcept {
+  return mi_heap_zalloc(mi_get_default_heap(),size);
+}
+
+
+// ------------------------------------------------------
+// Check for double free in secure and debug mode
+// This is somewhat expensive so only enabled for secure mode 4
+// ------------------------------------------------------
+
+#if (MI_ENCODE_FREELIST && (MI_SECURE>=4 || MI_DEBUG!=0))
+// linear check if the free list contains a specific element
+static bool mi_list_contains(const mi_page_t* page, const mi_block_t* list, const mi_block_t* elem) {
+  while (list != NULL) {
+    if (elem==list) return true;
+    list = mi_block_next(page, list);
+  }
+  return false;
+}
+
+static mi_decl_noinline bool mi_check_is_double_freex(const mi_page_t* page, const mi_block_t* block) {
+  // The decoded value is in the same page (or NULL).
+  // Walk the free lists to verify positively if it is already freed
+  if (mi_list_contains(page, page->free, block) ||
+      mi_list_contains(page, page->local_free, block) ||
+      mi_list_contains(page, mi_page_thread_free(page), block))
+  {
+    _mi_error_message(EAGAIN, "double free detected of block %p with size %zu\n", block, mi_page_block_size(page));
+    return true;
+  }
+  return false;
+}
+
+static inline bool mi_check_is_double_free(const mi_page_t* page, const mi_block_t* block) {
+  mi_block_t* n = mi_block_nextx(page, block, page->keys); // pretend it is freed, and get the decoded first field
+  if (((uintptr_t)n & (MI_INTPTR_SIZE-1))==0 &&  // quick check: aligned pointer?
+      (n==NULL || mi_is_in_same_page(block, n))) // quick check: in same page or NULL?
+  {
+    // Suspicous: decoded value a in block is in the same page (or NULL) -- maybe a double free?
+    // (continue in separate function to improve code generation)
+    return mi_check_is_double_freex(page, block);
+  }
+  return false;
+}
+#else
+static inline bool mi_check_is_double_free(const mi_page_t* page, const mi_block_t* block) {
+  MI_UNUSED(page);
+  MI_UNUSED(block);
+  return false;
+}
+#endif
+
+// ---------------------------------------------------------------------------
+// Check for heap block overflow by setting up padding at the end of the block
+// ---------------------------------------------------------------------------
+
+#if (MI_PADDING>0) && defined(MI_ENCODE_FREELIST)
+static bool mi_page_decode_padding(const mi_page_t* page, const mi_block_t* block, size_t* delta, size_t* bsize) {
+  *bsize = mi_page_usable_block_size(page);
+  const mi_padding_t* const padding = (mi_padding_t*)((uint8_t*)block + *bsize);
+  *delta = padding->delta;
+  return ((uint32_t)mi_ptr_encode(page,block,page->keys) == padding->canary && *delta <= *bsize);
+}
+
+// Return the exact usable size of a block.
+static size_t mi_page_usable_size_of(const mi_page_t* page, const mi_block_t* block) {
+  size_t bsize;
+  size_t delta;
+  bool ok = mi_page_decode_padding(page, block, &delta, &bsize);
+  mi_assert_internal(ok); mi_assert_internal(delta <= bsize);
+  return (ok ? bsize - delta : 0);
+}
+
+static bool mi_verify_padding(const mi_page_t* page, const mi_block_t* block, size_t* size, size_t* wrong) {
+  size_t bsize;
+  size_t delta;
+  bool ok = mi_page_decode_padding(page, block, &delta, &bsize);
+  *size = *wrong = bsize;
+  if (!ok) return false;
+  mi_assert_internal(bsize >= delta);
+  *size = bsize - delta;
+  uint8_t* fill = (uint8_t*)block + bsize - delta;
+  const size_t maxpad = (delta > MI_MAX_ALIGN_SIZE ? MI_MAX_ALIGN_SIZE : delta); // check at most the first N padding bytes
+  for (size_t i = 0; i < maxpad; i++) {
+    if (fill[i] != MI_DEBUG_PADDING) {
+      *wrong = bsize - delta + i;
+      return false;
+    }
+  }
+  return true;
+}
+
+static void mi_check_padding(const mi_page_t* page, const mi_block_t* block) {
+  size_t size;
+  size_t wrong;
+  if (!mi_verify_padding(page,block,&size,&wrong)) {
+    _mi_error_message(EFAULT, "buffer overflow in heap block %p of size %zu: write after %zu bytes\n", block, size, wrong );
+  }
+}
+
+// When a non-thread-local block is freed, it becomes part of the thread delayed free
+// list that is freed later by the owning heap. If the exact usable size is too small to
+// contain the pointer for the delayed list, then shrink the padding (by decreasing delta)
+// so it will later not trigger an overflow error in `mi_free_block`.
+static void mi_padding_shrink(const mi_page_t* page, const mi_block_t* block, const size_t min_size) {
+  size_t bsize;
+  size_t delta;
+  bool ok = mi_page_decode_padding(page, block, &delta, &bsize);
+  mi_assert_internal(ok);
+  if (!ok || (bsize - delta) >= min_size) return;  // usually already enough space
+  mi_assert_internal(bsize >= min_size);
+  if (bsize < min_size) return;  // should never happen
+  size_t new_delta = (bsize - min_size);
+  mi_assert_internal(new_delta < bsize);
+  mi_padding_t* padding = (mi_padding_t*)((uint8_t*)block + bsize);
+  padding->delta = (uint32_t)new_delta;
+}
+#else
+static void mi_check_padding(const mi_page_t* page, const mi_block_t* block) {
+  MI_UNUSED(page);
+  MI_UNUSED(block);
+}
+
+static size_t mi_page_usable_size_of(const mi_page_t* page, const mi_block_t* block) {
+  MI_UNUSED(block);
+  return mi_page_usable_block_size(page);
+}
+
+static void mi_padding_shrink(const mi_page_t* page, const mi_block_t* block, const size_t min_size) {
+  MI_UNUSED(page);
+  MI_UNUSED(block);
+  MI_UNUSED(min_size);
+}
+#endif
+
+// only maintain stats for smaller objects if requested
+#if (MI_STAT>0)
+static void mi_stat_free(const mi_page_t* page, const mi_block_t* block) {
+#if (MI_STAT < 2)  
+  MI_UNUSED(block);
+#endif
+  mi_heap_t* const heap = mi_heap_get_default();
+  const size_t bsize = mi_page_usable_block_size(page);  
+#if (MI_STAT>1)
+  const size_t usize = mi_page_usable_size_of(page, block);
+  mi_heap_stat_decrease(heap, malloc, usize);
+#endif  
+  if (bsize <= MI_LARGE_OBJ_SIZE_MAX) {
+    mi_heap_stat_decrease(heap, normal, bsize);
+#if (MI_STAT > 1)
+    mi_heap_stat_decrease(heap, normal_bins[_mi_bin(bsize)], 1);
+#endif
+  }
+}
+#else
+static void mi_stat_free(const mi_page_t* page, const mi_block_t* block) {
+  MI_UNUSED(page); MI_UNUSED(block);
+}
+#endif
+
+#if (MI_STAT>0)
+// maintain stats for huge objects
+static void mi_stat_huge_free(const mi_page_t* page) {
+  mi_heap_t* const heap = mi_heap_get_default();
+  const size_t bsize = mi_page_block_size(page); // to match stats in `page.c:mi_page_huge_alloc`
+  if (bsize <= MI_LARGE_OBJ_SIZE_MAX) {
+    mi_heap_stat_decrease(heap, large, bsize);
+  }
+  else {
+    mi_heap_stat_decrease(heap, huge, bsize);
+  }
+}
+#else
+static void mi_stat_huge_free(const mi_page_t* page) {
+  MI_UNUSED(page);
+}
+#endif
+
+// ------------------------------------------------------
+// Free
+// ------------------------------------------------------
+
+// multi-threaded free
+static mi_decl_noinline void _mi_free_block_mt(mi_page_t* page, mi_block_t* block)
+{
+  // The padding check may access the non-thread-owned page for the key values.
+  // that is safe as these are constant and the page won't be freed (as the block is not freed yet).
+  mi_check_padding(page, block);
+  mi_padding_shrink(page, block, sizeof(mi_block_t)); // for small size, ensure we can fit the delayed thread pointers without triggering overflow detection
+  #if (MI_DEBUG!=0)
+  memset(block, MI_DEBUG_FREED, mi_usable_size(block));
+  #endif
+
+  // huge page segments are always abandoned and can be freed immediately
+  mi_segment_t* segment = _mi_page_segment(page);
+  if (segment->kind==MI_SEGMENT_HUGE) {
+    mi_stat_huge_free(page);
+    _mi_segment_huge_page_free(segment, page, block);
+    return;
+  }
+
+  // Try to put the block on either the page-local thread free list, or the heap delayed free list.
+  mi_thread_free_t tfreex;
+  bool use_delayed;
+  mi_thread_free_t tfree = mi_atomic_load_relaxed(&page->xthread_free);
+  do {
+    use_delayed = (mi_tf_delayed(tfree) == MI_USE_DELAYED_FREE);
+    if (mi_unlikely(use_delayed)) {
+      // unlikely: this only happens on the first concurrent free in a page that is in the full list
+      tfreex = mi_tf_set_delayed(tfree,MI_DELAYED_FREEING);
+    }
+    else {
+      // usual: directly add to page thread_free list
+      mi_block_set_next(page, block, mi_tf_block(tfree));
+      tfreex = mi_tf_set_block(tfree,block);
+    }
+  } while (!mi_atomic_cas_weak_release(&page->xthread_free, &tfree, tfreex));
+
+  if (mi_unlikely(use_delayed)) {
+    // racy read on `heap`, but ok because MI_DELAYED_FREEING is set (see `mi_heap_delete` and `mi_heap_collect_abandon`)
+    mi_heap_t* const heap = (mi_heap_t*)(mi_atomic_load_acquire(&page->xheap)); //mi_page_heap(page);
+    mi_assert_internal(heap != NULL);
+    if (heap != NULL) {
+      // add to the delayed free list of this heap. (do this atomically as the lock only protects heap memory validity)
+      mi_block_t* dfree = mi_atomic_load_ptr_relaxed(mi_block_t, &heap->thread_delayed_free);
+      do {
+        mi_block_set_nextx(heap,block,dfree, heap->keys);
+      } while (!mi_atomic_cas_ptr_weak_release(mi_block_t,&heap->thread_delayed_free, &dfree, block));
+    }
+
+    // and reset the MI_DELAYED_FREEING flag
+    tfree = mi_atomic_load_relaxed(&page->xthread_free);
+    do {
+      tfreex = tfree;
+      mi_assert_internal(mi_tf_delayed(tfree) == MI_DELAYED_FREEING);
+      tfreex = mi_tf_set_delayed(tfree,MI_NO_DELAYED_FREE);
+    } while (!mi_atomic_cas_weak_release(&page->xthread_free, &tfree, tfreex));
+  }
+}
+
+// regular free
+static inline void _mi_free_block(mi_page_t* page, bool local, mi_block_t* block)
+{
+  // and push it on the free list
+  if (mi_likely(local)) {
+    // owning thread can free a block directly
+    if (mi_unlikely(mi_check_is_double_free(page, block))) return;
+    mi_check_padding(page, block);
+    #if (MI_DEBUG!=0)
+    memset(block, MI_DEBUG_FREED, mi_page_block_size(page));
+    #endif
+    mi_block_set_next(page, block, page->local_free);
+    page->local_free = block;
+    page->used--;
+    if (mi_unlikely(mi_page_all_free(page))) {
+      _mi_page_retire(page);
+    }
+    else if (mi_unlikely(mi_page_is_in_full(page))) {
+      _mi_page_unfull(page);
+    }
+  }
+  else {
+    _mi_free_block_mt(page,block);
+  }
+}
+
+
+// Adjust a block that was allocated aligned, to the actual start of the block in the page.
+mi_block_t* _mi_page_ptr_unalign(const mi_segment_t* segment, const mi_page_t* page, const void* p) {
+  mi_assert_internal(page!=NULL && p!=NULL);
+  const size_t diff   = (uint8_t*)p - _mi_page_start(segment, page, NULL);
+  const size_t adjust = (diff % mi_page_block_size(page));
+  return (mi_block_t*)((uintptr_t)p - adjust);
+}
+
+
+static void mi_decl_noinline mi_free_generic(const mi_segment_t* segment, bool local, void* p) mi_attr_noexcept {
+  mi_page_t* const page = _mi_segment_page_of(segment, p);
+  mi_block_t* const block = (mi_page_has_aligned(page) ? _mi_page_ptr_unalign(segment, page, p) : (mi_block_t*)p);
+  mi_stat_free(page, block);
+  _mi_free_block(page, local, block);
+}
+
+// Get the segment data belonging to a pointer
+// This is just a single `and` in assembly but does further checks in debug mode
+// (and secure mode) if this was a valid pointer.
+static inline mi_segment_t* mi_checked_ptr_segment(const void* p, const char* msg) 
+{
+  MI_UNUSED(msg);
+#if (MI_DEBUG>0)
+  if (mi_unlikely(((uintptr_t)p & (MI_INTPTR_SIZE - 1)) != 0)) {
+    _mi_error_message(EINVAL, "%s: invalid (unaligned) pointer: %p\n", msg, p);
+    return NULL;
+  }
+#endif
+
+  mi_segment_t* const segment = _mi_ptr_segment(p);
+  if (mi_unlikely(segment == NULL)) return NULL;  // checks also for (p==NULL)
+
+#if (MI_DEBUG>0)
+  if (mi_unlikely(!mi_is_in_heap_region(p))) {
+    _mi_warning_message("%s: pointer might not point to a valid heap region: %p\n"
+      "(this may still be a valid very large allocation (over 64MiB))\n", msg, p);
+    if (mi_likely(_mi_ptr_cookie(segment) == segment->cookie)) {
+      _mi_warning_message("(yes, the previous pointer %p was valid after all)\n", p);
+    }
+  }
+#endif
+#if (MI_DEBUG>0 || MI_SECURE>=4)
+  if (mi_unlikely(_mi_ptr_cookie(segment) != segment->cookie)) {
+    _mi_error_message(EINVAL, "%s: pointer does not point to a valid heap space: %p\n", msg, p);
+  }
+#endif
+  return segment;
+}
+
+// Free a block 
+void mi_free(void* p) mi_attr_noexcept
+{
+  mi_segment_t* const segment = mi_checked_ptr_segment(p,"mi_free");
+  if (mi_unlikely(segment == NULL)) return; 
+
+  mi_threadid_t tid = _mi_thread_id();
+  mi_page_t* const page = _mi_segment_page_of(segment, p);
+  
+  if (mi_likely(tid == mi_atomic_load_relaxed(&segment->thread_id) && page->flags.full_aligned == 0)) {  // the thread id matches and it is not a full page, nor has aligned blocks
+    // local, and not full or aligned
+    mi_block_t* block = (mi_block_t*)(p);
+    if (mi_unlikely(mi_check_is_double_free(page,block))) return;
+    mi_check_padding(page, block);
+    mi_stat_free(page, block);
+    #if (MI_DEBUG!=0)
+    memset(block, MI_DEBUG_FREED, mi_page_block_size(page));
+    #endif
+    mi_block_set_next(page, block, page->local_free);
+    page->local_free = block;
+    if (mi_unlikely(--page->used == 0)) {   // using this expression generates better code than: page->used--; if (mi_page_all_free(page))    
+      _mi_page_retire(page);
+    }
+  }
+  else {
+    // non-local, aligned blocks, or a full page; use the more generic path
+    // note: recalc page in generic to improve code generation
+    mi_free_generic(segment, tid == segment->thread_id, p);
+  }
+}
+
+bool _mi_free_delayed_block(mi_block_t* block) {
+  // get segment and page
+  const mi_segment_t* const segment = _mi_ptr_segment(block);
+  mi_assert_internal(_mi_ptr_cookie(segment) == segment->cookie);
+  mi_assert_internal(_mi_thread_id() == segment->thread_id);
+  mi_page_t* const page = _mi_segment_page_of(segment, block);
+
+  // Clear the no-delayed flag so delayed freeing is used again for this page.
+  // This must be done before collecting the free lists on this page -- otherwise
+  // some blocks may end up in the page `thread_free` list with no blocks in the
+  // heap `thread_delayed_free` list which may cause the page to be never freed!
+  // (it would only be freed if we happen to scan it in `mi_page_queue_find_free_ex`)
+  _mi_page_use_delayed_free(page, MI_USE_DELAYED_FREE, false /* dont overwrite never delayed */);
+
+  // collect all other non-local frees to ensure up-to-date `used` count
+  _mi_page_free_collect(page, false);
+
+  // and free the block (possibly freeing the page as well since used is updated)
+  _mi_free_block(page, true, block);
+  return true;
+}
+
+// Bytes available in a block
+static size_t _mi_usable_size(const void* p, const char* msg) mi_attr_noexcept {
+  const mi_segment_t* const segment = mi_checked_ptr_segment(p,msg);
+  if (segment==NULL) return 0;
+  const mi_page_t* const page = _mi_segment_page_of(segment, p);
+  const mi_block_t* block = (const mi_block_t*)p;
+  if (mi_unlikely(mi_page_has_aligned(page))) {
+    block = _mi_page_ptr_unalign(segment, page, p);
+    size_t size = mi_page_usable_size_of(page, block);
+    ptrdiff_t const adjust = (uint8_t*)p - (uint8_t*)block;
+    mi_assert_internal(adjust >= 0 && (size_t)adjust <= size);
+    return (size - adjust);
+  }
+  else {
+    return mi_page_usable_size_of(page, block);
+  }
+}
+
+size_t mi_usable_size(const void* p) mi_attr_noexcept {
+  return _mi_usable_size(p, "mi_usable_size");
+}
+
+
+// ------------------------------------------------------
+// ensure explicit external inline definitions are emitted!
+// ------------------------------------------------------
+
+#ifdef __cplusplus
+void* _mi_externs[] = {
+  (void*)&_mi_page_malloc,
+  (void*)&mi_malloc,
+  (void*)&mi_malloc_small,
+  (void*)&mi_zalloc_small,
+  (void*)&mi_heap_malloc,
+  (void*)&mi_heap_zalloc,
+  (void*)&mi_heap_malloc_small
+};
+#endif
+
+
+// ------------------------------------------------------
+// Allocation extensions
+// ------------------------------------------------------
+
+void mi_free_size(void* p, size_t size) mi_attr_noexcept {
+  MI_UNUSED_RELEASE(size);
+  mi_assert(p == NULL || size <= _mi_usable_size(p,"mi_free_size"));
+  mi_free(p);
+}
+
+void mi_free_size_aligned(void* p, size_t size, size_t alignment) mi_attr_noexcept {
+  MI_UNUSED_RELEASE(alignment);
+  mi_assert(((uintptr_t)p % alignment) == 0);
+  mi_free_size(p,size);
+}
+
+void mi_free_aligned(void* p, size_t alignment) mi_attr_noexcept {
+  MI_UNUSED_RELEASE(alignment);
+  mi_assert(((uintptr_t)p % alignment) == 0);
+  mi_free(p);
+}
+
+extern inline mi_decl_restrict void* mi_heap_calloc(mi_heap_t* heap, size_t count, size_t size) mi_attr_noexcept {
+  size_t total;
+  if (mi_count_size_overflow(count,size,&total)) return NULL;
+  return mi_heap_zalloc(heap,total);
+}
+
+mi_decl_restrict void* mi_calloc(size_t count, size_t size) mi_attr_noexcept {
+  return mi_heap_calloc(mi_get_default_heap(),count,size);
+}
+
+// Uninitialized `calloc`
+extern mi_decl_restrict void* mi_heap_mallocn(mi_heap_t* heap, size_t count, size_t size) mi_attr_noexcept {
+  size_t total;
+  if (mi_count_size_overflow(count, size, &total)) return NULL;
+  return mi_heap_malloc(heap, total);
+}
+
+mi_decl_restrict void* mi_mallocn(size_t count, size_t size) mi_attr_noexcept {
+  return mi_heap_mallocn(mi_get_default_heap(),count,size);
+}
+
+// Expand in place or fail
+void* mi_expand(void* p, size_t newsize) mi_attr_noexcept {
+  if (p == NULL) return NULL;
+  size_t size = _mi_usable_size(p,"mi_expand");
+  if (newsize > size) return NULL;
+  return p; // it fits
+}
+
+void* _mi_heap_realloc_zero(mi_heap_t* heap, void* p, size_t newsize, bool zero) {
+  if (p == NULL) return _mi_heap_malloc_zero(heap,newsize,zero);
+  size_t size = _mi_usable_size(p,"mi_realloc");
+  if (newsize <= size && newsize >= (size / 2)) {
+    return p;  // reallocation still fits and not more than 50% waste
+  }
+  void* newp = mi_heap_malloc(heap,newsize);
+  if (mi_likely(newp != NULL)) {
+    if (zero && newsize > size) {
+      // also set last word in the previous allocation to zero to ensure any padding is zero-initialized
+      size_t start = (size >= sizeof(intptr_t) ? size - sizeof(intptr_t) : 0);
+      memset((uint8_t*)newp + start, 0, newsize - start);
+    }
+    _mi_memcpy_aligned(newp, p, (newsize > size ? size : newsize));
+    mi_free(p); // only free if successful
+  }
+  return newp;
+}
+
+void* mi_heap_realloc(mi_heap_t* heap, void* p, size_t newsize) mi_attr_noexcept {
+  return _mi_heap_realloc_zero(heap, p, newsize, false);
+}
+
+void* mi_heap_reallocn(mi_heap_t* heap, void* p, size_t count, size_t size) mi_attr_noexcept {
+  size_t total;
+  if (mi_count_size_overflow(count, size, &total)) return NULL;
+  return mi_heap_realloc(heap, p, total);
+}
+
+
+// Reallocate but free `p` on errors
+void* mi_heap_reallocf(mi_heap_t* heap, void* p, size_t newsize) mi_attr_noexcept {
+  void* newp = mi_heap_realloc(heap, p, newsize);
+  if (newp==NULL && p!=NULL) mi_free(p);
+  return newp;
+}
+
+void* mi_heap_rezalloc(mi_heap_t* heap, void* p, size_t newsize) mi_attr_noexcept {
+  return _mi_heap_realloc_zero(heap, p, newsize, true);
+}
+
+void* mi_heap_recalloc(mi_heap_t* heap, void* p, size_t count, size_t size) mi_attr_noexcept {
+  size_t total;
+  if (mi_count_size_overflow(count, size, &total)) return NULL;
+  return mi_heap_rezalloc(heap, p, total);
+}
+
+
+void* mi_realloc(void* p, size_t newsize) mi_attr_noexcept {
+  return mi_heap_realloc(mi_get_default_heap(),p,newsize);
+}
+
+void* mi_reallocn(void* p, size_t count, size_t size) mi_attr_noexcept {
+  return mi_heap_reallocn(mi_get_default_heap(),p,count,size);
+}
+
+// Reallocate but free `p` on errors
+void* mi_reallocf(void* p, size_t newsize) mi_attr_noexcept {
+  return mi_heap_reallocf(mi_get_default_heap(),p,newsize);
+}
+
+void* mi_rezalloc(void* p, size_t newsize) mi_attr_noexcept {
+  return mi_heap_rezalloc(mi_get_default_heap(), p, newsize);
+}
+
+void* mi_recalloc(void* p, size_t count, size_t size) mi_attr_noexcept {
+  return mi_heap_recalloc(mi_get_default_heap(), p, count, size);
+}
+
+
+
+// ------------------------------------------------------
+// strdup, strndup, and realpath
+// ------------------------------------------------------
+
+// `strdup` using mi_malloc
+mi_decl_restrict char* mi_heap_strdup(mi_heap_t* heap, const char* s) mi_attr_noexcept {
+  if (s == NULL) return NULL;
+  size_t n = strlen(s);
+  char* t = (char*)mi_heap_malloc(heap,n+1);
+  if (t != NULL) _mi_memcpy(t, s, n + 1);
+  return t;
+}
+
+mi_decl_restrict char* mi_strdup(const char* s) mi_attr_noexcept {
+  return mi_heap_strdup(mi_get_default_heap(), s);
+}
+
+// `strndup` using mi_malloc
+mi_decl_restrict char* mi_heap_strndup(mi_heap_t* heap, const char* s, size_t n) mi_attr_noexcept {
+  if (s == NULL) return NULL;
+  const char* end = (const char*)memchr(s, 0, n);  // find end of string in the first `n` characters (returns NULL if not found)
+  const size_t m = (end != NULL ? (size_t)(end - s) : n);  // `m` is the minimum of `n` or the end-of-string
+  mi_assert_internal(m <= n);
+  char* t = (char*)mi_heap_malloc(heap, m+1);
+  if (t == NULL) return NULL;
+  _mi_memcpy(t, s, m);
+  t[m] = 0;
+  return t;
+}
+
+mi_decl_restrict char* mi_strndup(const char* s, size_t n) mi_attr_noexcept {
+  return mi_heap_strndup(mi_get_default_heap(),s,n);
+}
+
+#ifndef __wasi__
+// `realpath` using mi_malloc
+#ifdef _WIN32
+#ifndef PATH_MAX
+#define PATH_MAX MAX_PATH
+#endif
+#include <windows.h>
+mi_decl_restrict char* mi_heap_realpath(mi_heap_t* heap, const char* fname, char* resolved_name) mi_attr_noexcept {
+  // todo: use GetFullPathNameW to allow longer file names
+  char buf[PATH_MAX];
+  DWORD res = GetFullPathNameA(fname, PATH_MAX, (resolved_name == NULL ? buf : resolved_name), NULL);
+  if (res == 0) {
+    errno = GetLastError(); return NULL;
+  }
+  else if (res > PATH_MAX) {
+    errno = EINVAL; return NULL;
+  }
+  else if (resolved_name != NULL) {
+    return resolved_name;
+  }
+  else {
+    return mi_heap_strndup(heap, buf, PATH_MAX);
+  }
+}
+#else
+#include <unistd.h>  // pathconf
+static size_t mi_path_max(void) {
+  static size_t path_max = 0;
+  if (path_max <= 0) {
+    long m = pathconf("/",_PC_PATH_MAX);
+    if (m <= 0) path_max = 4096;      // guess
+    else if (m < 256) path_max = 256; // at least 256
+    else path_max = m;
+  }
+  return path_max;
+}
+
+char* mi_heap_realpath(mi_heap_t* heap, const char* fname, char* resolved_name) mi_attr_noexcept {
+  if (resolved_name != NULL) {
+    return realpath(fname,resolved_name);
+  }
+  else {
+    size_t n  = mi_path_max();
+    char* buf = (char*)mi_malloc(n+1);
+    if (buf==NULL) return NULL;
+    char* rname  = realpath(fname,buf);
+    char* result = mi_heap_strndup(heap,rname,n); // ok if `rname==NULL`
+    mi_free(buf);
+    return result;
+  }
+}
+#endif
+
+mi_decl_restrict char* mi_realpath(const char* fname, char* resolved_name) mi_attr_noexcept {
+  return mi_heap_realpath(mi_get_default_heap(),fname,resolved_name);
+}
+#endif
+
+/*-------------------------------------------------------
+C++ new and new_aligned
+The standard requires calling into `get_new_handler` and
+throwing the bad_alloc exception on failure. If we compile
+with a C++ compiler we can implement this precisely. If we
+use a C compiler we cannot throw a `bad_alloc` exception
+but we call `exit` instead (i.e. not returning).
+-------------------------------------------------------*/
+
+#ifdef __cplusplus
+#include <new>
+static bool mi_try_new_handler(bool nothrow) {
+  #if defined(_MSC_VER) || (__cplusplus >= 201103L)
+    std::new_handler h = std::get_new_handler();
+  #else
+    std::new_handler h = std::set_new_handler();
+    std::set_new_handler(h);
+  #endif  
+  if (h==NULL) {
+    _mi_error_message(ENOMEM, "out of memory in 'new'");      
+    if (!nothrow) {
+      throw std::bad_alloc();
+    }
+    return false;
+  }
+  else {
+    h();
+    return true;
+  }
+}
+#else
+typedef void (*std_new_handler_t)(void);
+
+#if (defined(__GNUC__) || defined(__clang__))
+std_new_handler_t __attribute((weak)) _ZSt15get_new_handlerv(void) {
+  return NULL;
+}
+static std_new_handler_t mi_get_new_handler(void) {
+  return _ZSt15get_new_handlerv();
+}
+#else
+// note: on windows we could dynamically link to `?get_new_handler@std@@YAP6AXXZXZ`.
+static std_new_handler_t mi_get_new_handler() {
+  return NULL;
+}
+#endif
+
+static bool mi_try_new_handler(bool nothrow) {
+  std_new_handler_t h = mi_get_new_handler();
+  if (h==NULL) {
+    _mi_error_message(ENOMEM, "out of memory in 'new'");       
+    if (!nothrow) {
+      abort();  // cannot throw in plain C, use abort
+    }
+    return false;
+  }
+  else {
+    h();
+    return true;
+  }
+}
+#endif
+
+static mi_decl_noinline void* mi_try_new(size_t size, bool nothrow ) {
+  void* p = NULL;
+  while(p == NULL && mi_try_new_handler(nothrow)) {
+    p = mi_malloc(size);
+  }
+  return p;
+}
+
+mi_decl_restrict void* mi_new(size_t size) {
+  void* p = mi_malloc(size);
+  if (mi_unlikely(p == NULL)) return mi_try_new(size,false);
+  return p;
+}
+
+mi_decl_restrict void* mi_new_nothrow(size_t size) mi_attr_noexcept {
+  void* p = mi_malloc(size);
+  if (mi_unlikely(p == NULL)) return mi_try_new(size, true);
+  return p;
+}
+
+mi_decl_restrict void* mi_new_aligned(size_t size, size_t alignment) {
+  void* p;
+  do {
+    p = mi_malloc_aligned(size, alignment);
+  }
+  while(p == NULL && mi_try_new_handler(false));
+  return p;
+}
+
+mi_decl_restrict void* mi_new_aligned_nothrow(size_t size, size_t alignment) mi_attr_noexcept {
+  void* p;
+  do {
+    p = mi_malloc_aligned(size, alignment);
+  }
+  while(p == NULL && mi_try_new_handler(true));
+  return p;
+}
+
+mi_decl_restrict void* mi_new_n(size_t count, size_t size) {
+  size_t total;
+  if (mi_unlikely(mi_count_size_overflow(count, size, &total))) {
+    mi_try_new_handler(false);  // on overflow we invoke the try_new_handler once to potentially throw std::bad_alloc
+    return NULL;
+  }
+  else {
+    return mi_new(total);
+  }
+}
+
+void* mi_new_realloc(void* p, size_t newsize) {
+  void* q;
+  do {
+    q = mi_realloc(p, newsize);
+  } while (q == NULL && mi_try_new_handler(false));
+  return q;
+}
+
+void* mi_new_reallocn(void* p, size_t newcount, size_t size) {
+  size_t total;
+  if (mi_unlikely(mi_count_size_overflow(newcount, size, &total))) {
+    mi_try_new_handler(false);  // on overflow we invoke the try_new_handler once to potentially throw std::bad_alloc
+    return NULL;
+  }
+  else {
+    return mi_new_realloc(p, total);
+  }
+}
diff --git a/Objects/mimalloc/arena.c b/Objects/mimalloc/arena.c
new file mode 100644
index 0000000000000..6b1e951f34212
--- /dev/null
+++ b/Objects/mimalloc/arena.c
@@ -0,0 +1,446 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2019-2021, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+
+/* ----------------------------------------------------------------------------
+"Arenas" are fixed area's of OS memory from which we can allocate
+large blocks (>= MI_ARENA_MIN_BLOCK_SIZE, 4MiB).
+In contrast to the rest of mimalloc, the arenas are shared between
+threads and need to be accessed using atomic operations.
+
+Currently arenas are only used to for huge OS page (1GiB) reservations,
+or direct OS memory reservations -- otherwise it delegates to direct allocation from the OS.
+In the future, we can expose an API to manually add more kinds of arenas
+which is sometimes needed for embedded devices or shared memory for example.
+(We can also employ this with WASI or `sbrk` systems to reserve large arenas
+ on demand and be able to reuse them efficiently).
+
+The arena allocation needs to be thread safe and we use an atomic bitmap to allocate.
+-----------------------------------------------------------------------------*/
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+#include "mimalloc-atomic.h"
+
+#include <string.h>  // memset
+#include <errno.h> // ENOMEM
+
+#include "bitmap.h"  // atomic bitmap
+
+
+// os.c
+void* _mi_os_alloc_aligned(size_t size, size_t alignment, bool commit, bool* large, mi_stats_t* stats);
+void  _mi_os_free_ex(void* p, size_t size, bool was_committed, mi_stats_t* stats);
+
+void* _mi_os_alloc_huge_os_pages(size_t pages, int numa_node, mi_msecs_t max_secs, size_t* pages_reserved, size_t* psize);
+void  _mi_os_free_huge_pages(void* p, size_t size, mi_stats_t* stats);
+
+bool  _mi_os_commit(void* p, size_t size, bool* is_zero, mi_stats_t* stats);
+bool  _mi_os_decommit(void* addr, size_t size, mi_stats_t* stats);
+
+
+/* -----------------------------------------------------------
+  Arena allocation
+----------------------------------------------------------- */
+
+
+// Block info: bit 0 contains the `in_use` bit, the upper bits the
+// size in count of arena blocks.
+typedef uintptr_t mi_block_info_t;
+#define MI_ARENA_BLOCK_SIZE   (MI_SEGMENT_SIZE)        // 8MiB  (must be at least MI_SEGMENT_ALIGN)
+#define MI_ARENA_MIN_OBJ_SIZE (MI_ARENA_BLOCK_SIZE/2)  // 4MiB
+#define MI_MAX_ARENAS         (64)                     // not more than 256 (since we use 8 bits in the memid)
+
+// A memory arena descriptor
+typedef struct mi_arena_s {
+  _Atomic(uint8_t*) start;                // the start of the memory area
+  size_t   block_count;                   // size of the area in arena blocks (of `MI_ARENA_BLOCK_SIZE`)
+  size_t   field_count;                   // number of bitmap fields (where `field_count * MI_BITMAP_FIELD_BITS >= block_count`)
+  int      numa_node;                     // associated NUMA node
+  bool     is_zero_init;                  // is the arena zero initialized?
+  bool     allow_decommit;                // is decommit allowed? if true, is_large should be false and blocks_committed != NULL
+  bool     is_large;                      // large- or huge OS pages (always committed)
+  _Atomic(size_t) search_idx;             // optimization to start the search for free blocks
+  mi_bitmap_field_t* blocks_dirty;        // are the blocks potentially non-zero?
+  mi_bitmap_field_t* blocks_committed;    // are the blocks committed? (can be NULL for memory that cannot be decommitted)
+  mi_bitmap_field_t  blocks_inuse[1];     // in-place bitmap of in-use blocks (of size `field_count`)
+} mi_arena_t;
+
+
+// The available arenas
+static mi_decl_cache_align _Atomic(mi_arena_t*) mi_arenas[MI_MAX_ARENAS];
+static mi_decl_cache_align _Atomic(size_t)      mi_arena_count; // = 0
+
+
+/* -----------------------------------------------------------
+  Arena allocations get a memory id where the lower 8 bits are
+  the arena index +1, and the upper bits the block index.
+----------------------------------------------------------- */
+
+// Use `0` as a special id for direct OS allocated memory.
+#define MI_MEMID_OS   0
+
+static size_t mi_arena_id_create(size_t arena_index, mi_bitmap_index_t bitmap_index) {
+  mi_assert_internal(arena_index < 0xFE);
+  mi_assert_internal(((bitmap_index << 8) >> 8) == bitmap_index); // no overflow?
+  return ((bitmap_index << 8) | ((arena_index+1) & 0xFF));
+}
+
+static void mi_arena_id_indices(size_t memid, size_t* arena_index, mi_bitmap_index_t* bitmap_index) {
+  mi_assert_internal(memid != MI_MEMID_OS);
+  *arena_index = (memid & 0xFF) - 1;
+  *bitmap_index = (memid >> 8);
+}
+
+static size_t mi_block_count_of_size(size_t size) {
+  return _mi_divide_up(size, MI_ARENA_BLOCK_SIZE);
+}
+
+/* -----------------------------------------------------------
+  Thread safe allocation in an arena
+----------------------------------------------------------- */
+static bool mi_arena_alloc(mi_arena_t* arena, size_t blocks, mi_bitmap_index_t* bitmap_idx)
+{
+  size_t idx = 0; // mi_atomic_load_relaxed(&arena->search_idx);  // start from last search; ok to be relaxed as the exact start does not matter
+  if (_mi_bitmap_try_find_from_claim_across(arena->blocks_inuse, arena->field_count, idx, blocks, bitmap_idx)) {
+    mi_atomic_store_relaxed(&arena->search_idx, mi_bitmap_index_field(*bitmap_idx));  // start search from found location next time around
+    return true;
+  };
+  return false;
+}
+
+
+/* -----------------------------------------------------------
+  Arena Allocation
+----------------------------------------------------------- */
+
+static mi_decl_noinline void* mi_arena_alloc_from(mi_arena_t* arena, size_t arena_index, size_t needed_bcount,
+                                                  bool* commit, bool* large, bool* is_pinned, bool* is_zero, size_t* memid, mi_os_tld_t* tld)
+{
+  mi_bitmap_index_t bitmap_index;
+  if (!mi_arena_alloc(arena, needed_bcount, &bitmap_index)) return NULL;
+
+  // claimed it! set the dirty bits (todo: no need for an atomic op here?)
+  void* p    = arena->start + (mi_bitmap_index_bit(bitmap_index)*MI_ARENA_BLOCK_SIZE);
+  *memid     = mi_arena_id_create(arena_index, bitmap_index);
+  *is_zero   = _mi_bitmap_claim_across(arena->blocks_dirty, arena->field_count, needed_bcount, bitmap_index, NULL);
+  *large     = arena->is_large;
+  *is_pinned = (arena->is_large || !arena->allow_decommit);
+  if (arena->blocks_committed == NULL) {
+    // always committed
+    *commit = true;
+  }
+  else if (*commit) {
+    // arena not committed as a whole, but commit requested: ensure commit now
+    bool any_uncommitted;
+    _mi_bitmap_claim_across(arena->blocks_committed, arena->field_count, needed_bcount, bitmap_index, &any_uncommitted);
+    if (any_uncommitted) {
+      bool commit_zero;
+      _mi_os_commit(p, needed_bcount * MI_ARENA_BLOCK_SIZE, &commit_zero, tld->stats);
+      if (commit_zero) *is_zero = true;
+    }
+  }
+  else {
+    // no need to commit, but check if already fully committed
+    *commit = _mi_bitmap_is_claimed_across(arena->blocks_committed, arena->field_count, needed_bcount, bitmap_index);
+  }
+  return p;
+}
+
+static mi_decl_noinline void* mi_arena_allocate(int numa_node, size_t size, size_t alignment, bool* commit, bool* large, bool* is_pinned, bool* is_zero, size_t* memid, mi_os_tld_t* tld)
+{  
+  MI_UNUSED_RELEASE(alignment);
+  mi_assert_internal(alignment <= MI_SEGMENT_ALIGN);
+  const size_t max_arena = mi_atomic_load_relaxed(&mi_arena_count);  
+  const size_t bcount = mi_block_count_of_size(size);
+  if (mi_likely(max_arena == 0)) return NULL;
+  mi_assert_internal(size <= bcount*MI_ARENA_BLOCK_SIZE);
+
+  // try numa affine allocation
+  for (size_t i = 0; i < max_arena; i++) {
+    mi_arena_t* arena = mi_atomic_load_ptr_relaxed(mi_arena_t, &mi_arenas[i]);
+    if (arena==NULL) break; // end reached
+    if ((arena->numa_node<0 || arena->numa_node==numa_node) && // numa local?
+      (*large || !arena->is_large)) // large OS pages allowed, or arena is not large OS pages
+    {
+      void* p = mi_arena_alloc_from(arena, i, bcount, commit, large, is_pinned, is_zero, memid, tld);
+      mi_assert_internal((uintptr_t)p % alignment == 0);
+      if (p != NULL) {
+        return p;
+      }
+    }
+  }
+
+  // try from another numa node instead..
+  for (size_t i = 0; i < max_arena; i++) {
+    mi_arena_t* arena = mi_atomic_load_ptr_relaxed(mi_arena_t, &mi_arenas[i]);
+    if (arena==NULL) break; // end reached
+    if ((arena->numa_node>=0 && arena->numa_node!=numa_node) && // not numa local!
+      (*large || !arena->is_large)) // large OS pages allowed, or arena is not large OS pages
+    {
+      void* p = mi_arena_alloc_from(arena, i, bcount, commit, large, is_pinned, is_zero, memid, tld);
+      mi_assert_internal((uintptr_t)p % alignment == 0);
+      if (p != NULL) {
+        return p;
+      }
+    }
+  }
+  return NULL;
+}
+
+
+void* _mi_arena_alloc_aligned(size_t size, size_t alignment, bool* commit, bool* large, bool* is_pinned, bool* is_zero,
+                              size_t* memid, mi_os_tld_t* tld)
+{
+  mi_assert_internal(commit != NULL && is_pinned != NULL && is_zero != NULL && memid != NULL && tld != NULL);
+  mi_assert_internal(size > 0);
+  *memid   = MI_MEMID_OS;
+  *is_zero = false;
+  *is_pinned = false;
+
+  bool default_large = false;
+  if (large==NULL) large = &default_large;     // ensure `large != NULL`
+  const int numa_node = _mi_os_numa_node(tld); // current numa node
+
+  // try to allocate in an arena if the alignment is small enough and the object is not too small (as for heap meta data)
+  if (size >= MI_ARENA_MIN_OBJ_SIZE && alignment <= MI_SEGMENT_ALIGN) {
+    void* p = mi_arena_allocate(numa_node, size, alignment, commit, large, is_pinned, is_zero, memid, tld);
+    if (p != NULL) return p;
+  }
+
+  // finally, fall back to the OS
+  if (mi_option_is_enabled(mi_option_limit_os_alloc)) {
+    errno = ENOMEM;
+    return NULL;
+  }
+  *is_zero = true;
+  *memid   = MI_MEMID_OS;  
+  void* p = _mi_os_alloc_aligned(size, alignment, *commit, large, tld->stats);
+  if (p != NULL) *is_pinned = *large;
+  return p;
+}
+
+void* _mi_arena_alloc(size_t size, bool* commit, bool* large, bool* is_pinned, bool* is_zero, size_t* memid, mi_os_tld_t* tld)
+{
+  return _mi_arena_alloc_aligned(size, MI_ARENA_BLOCK_SIZE, commit, large, is_pinned, is_zero, memid, tld);
+}
+
+/* -----------------------------------------------------------
+  Arena free
+----------------------------------------------------------- */
+
+void _mi_arena_free(void* p, size_t size, size_t memid, bool all_committed, mi_os_tld_t* tld) {
+  mi_assert_internal(size > 0 && tld->stats != NULL);
+  if (p==NULL) return;
+  if (size==0) return;
+
+  if (memid == MI_MEMID_OS) {
+    // was a direct OS allocation, pass through
+    _mi_os_free_ex(p, size, all_committed, tld->stats);
+  }
+  else {
+    // allocated in an arena
+    size_t arena_idx;
+    size_t bitmap_idx;
+    mi_arena_id_indices(memid, &arena_idx, &bitmap_idx);
+    mi_assert_internal(arena_idx < MI_MAX_ARENAS);
+    mi_arena_t* arena = mi_atomic_load_ptr_relaxed(mi_arena_t,&mi_arenas[arena_idx]);
+    mi_assert_internal(arena != NULL);
+    const size_t blocks = mi_block_count_of_size(size);
+    // checks
+    if (arena == NULL) {
+      _mi_error_message(EINVAL, "trying to free from non-existent arena: %p, size %zu, memid: 0x%zx\n", p, size, memid);
+      return;
+    }
+    mi_assert_internal(arena->field_count > mi_bitmap_index_field(bitmap_idx));
+    if (arena->field_count <= mi_bitmap_index_field(bitmap_idx)) {
+      _mi_error_message(EINVAL, "trying to free from non-existent arena block: %p, size %zu, memid: 0x%zx\n", p, size, memid);
+      return;
+    }
+    // potentially decommit
+    if (!arena->allow_decommit || arena->blocks_committed == NULL) {
+      mi_assert_internal(all_committed); // note: may be not true as we may "pretend" to be not committed (in segment.c)
+    }
+    else {
+      mi_assert_internal(arena->blocks_committed != NULL);
+      _mi_os_decommit(p, blocks * MI_ARENA_BLOCK_SIZE, tld->stats); // ok if this fails
+      _mi_bitmap_unclaim_across(arena->blocks_committed, arena->field_count, blocks, bitmap_idx);
+    }
+    // and make it available to others again 
+    bool all_inuse = _mi_bitmap_unclaim_across(arena->blocks_inuse, arena->field_count, blocks, bitmap_idx);
+    if (!all_inuse) {
+      _mi_error_message(EAGAIN, "trying to free an already freed block: %p, size %zu\n", p, size);
+      return;
+    };
+  }
+}
+
+/* -----------------------------------------------------------
+  Add an arena.
+----------------------------------------------------------- */
+
+static bool mi_arena_add(mi_arena_t* arena) {
+  mi_assert_internal(arena != NULL);
+  mi_assert_internal((uintptr_t)mi_atomic_load_ptr_relaxed(uint8_t,&arena->start) % MI_SEGMENT_ALIGN == 0);
+  mi_assert_internal(arena->block_count > 0);
+
+  size_t i = mi_atomic_increment_acq_rel(&mi_arena_count);
+  if (i >= MI_MAX_ARENAS) {
+    mi_atomic_decrement_acq_rel(&mi_arena_count);
+    return false;
+  }
+  mi_atomic_store_ptr_release(mi_arena_t,&mi_arenas[i], arena);
+  return true;
+}
+
+bool mi_manage_os_memory(void* start, size_t size, bool is_committed, bool is_large, bool is_zero, int numa_node) mi_attr_noexcept
+{
+  if (size < MI_ARENA_BLOCK_SIZE) return false;
+
+  if (is_large) {
+    mi_assert_internal(is_committed);
+    is_committed = true;
+  }
+  
+  const size_t bcount = size / MI_ARENA_BLOCK_SIZE; 
+  const size_t fields = _mi_divide_up(bcount, MI_BITMAP_FIELD_BITS);
+  const size_t bitmaps = (is_committed ? 2 : 3);
+  const size_t asize  = sizeof(mi_arena_t) + (bitmaps*fields*sizeof(mi_bitmap_field_t));
+  mi_arena_t* arena   = (mi_arena_t*)_mi_os_alloc(asize, &_mi_stats_main); // TODO: can we avoid allocating from the OS?
+  if (arena == NULL) return false;
+
+  arena->block_count = bcount;
+  arena->field_count = fields;
+  arena->start = (uint8_t*)start;
+  arena->numa_node    = numa_node; // TODO: or get the current numa node if -1? (now it allows anyone to allocate on -1)
+  arena->is_large     = is_large;
+  arena->is_zero_init = is_zero;
+  arena->allow_decommit = !is_large && !is_committed; // only allow decommit for initially uncommitted memory
+  arena->search_idx   = 0;
+  arena->blocks_dirty = &arena->blocks_inuse[fields]; // just after inuse bitmap
+  arena->blocks_committed = (!arena->allow_decommit ? NULL : &arena->blocks_inuse[2*fields]); // just after dirty bitmap
+  // the bitmaps are already zero initialized due to os_alloc
+  // initialize committed bitmap?
+  if (arena->blocks_committed != NULL && is_committed) {
+    memset((void*)arena->blocks_committed, 0xFF, fields*sizeof(mi_bitmap_field_t)); // cast to void* to avoid atomic warning
+  }
+  // and claim leftover blocks if needed (so we never allocate there)
+  ptrdiff_t post = (fields * MI_BITMAP_FIELD_BITS) - bcount;
+  mi_assert_internal(post >= 0);
+  if (post > 0) {
+    // don't use leftover bits at the end
+    mi_bitmap_index_t postidx = mi_bitmap_index_create(fields - 1, MI_BITMAP_FIELD_BITS - post);
+    _mi_bitmap_claim(arena->blocks_inuse, fields, post, postidx, NULL);
+  }
+
+  mi_arena_add(arena);
+  return true;
+}
+
+// Reserve a range of regular OS memory
+int mi_reserve_os_memory(size_t size, bool commit, bool allow_large) mi_attr_noexcept 
+{
+  size = _mi_align_up(size, MI_ARENA_BLOCK_SIZE); // at least one block
+  bool large = allow_large;
+  void* start = _mi_os_alloc_aligned(size, MI_SEGMENT_ALIGN, commit, &large, &_mi_stats_main);
+  if (start==NULL) return ENOMEM;
+  if (!mi_manage_os_memory(start, size, (large || commit), large, true, -1)) {
+    _mi_os_free_ex(start, size, commit, &_mi_stats_main);
+    _mi_verbose_message("failed to reserve %zu k memory\n", _mi_divide_up(size,1024));
+    return ENOMEM;
+  }
+  _mi_verbose_message("reserved %zu KiB memory%s\n", _mi_divide_up(size,1024), large ? " (in large os pages)" : "");
+  return 0;
+}
+
+static size_t mi_debug_show_bitmap(const char* prefix, mi_bitmap_field_t* fields, size_t field_count ) {
+  size_t inuse_count = 0;
+  for (size_t i = 0; i < field_count; i++) {
+    char buf[MI_BITMAP_FIELD_BITS + 1];
+    uintptr_t field = mi_atomic_load_relaxed(&fields[i]);
+    for (size_t bit = 0; bit < MI_BITMAP_FIELD_BITS; bit++) {
+      bool inuse = ((((uintptr_t)1 << bit) & field) != 0);
+      if (inuse) inuse_count++;
+      buf[MI_BITMAP_FIELD_BITS - 1 - bit] = (inuse ? 'x' : '.');
+    }
+    buf[MI_BITMAP_FIELD_BITS] = 0;
+    _mi_verbose_message("%s%s\n", prefix, buf);
+  }
+  return inuse_count;
+}
+
+void mi_debug_show_arenas(void) mi_attr_noexcept {
+  size_t max_arenas = mi_atomic_load_relaxed(&mi_arena_count);
+  for (size_t i = 0; i < max_arenas; i++) {
+    mi_arena_t* arena = mi_atomic_load_ptr_relaxed(mi_arena_t, &mi_arenas[i]);
+    if (arena == NULL) break;
+    size_t inuse_count = 0;
+    _mi_verbose_message("arena %zu: %zu blocks with %zu fields\n", i, arena->block_count, arena->field_count);
+    inuse_count += mi_debug_show_bitmap("  ", arena->blocks_inuse, arena->field_count);
+    _mi_verbose_message("  blocks in use ('x'): %zu\n", inuse_count);
+  }
+}
+
+/* -----------------------------------------------------------
+  Reserve a huge page arena.
+----------------------------------------------------------- */
+// reserve at a specific numa node
+int mi_reserve_huge_os_pages_at(size_t pages, int numa_node, size_t timeout_msecs) mi_attr_noexcept {
+  if (pages==0) return 0;
+  if (numa_node < -1) numa_node = -1;
+  if (numa_node >= 0) numa_node = numa_node % _mi_os_numa_node_count();
+  size_t hsize = 0;
+  size_t pages_reserved = 0;
+  void* p = _mi_os_alloc_huge_os_pages(pages, numa_node, timeout_msecs, &pages_reserved, &hsize);
+  if (p==NULL || pages_reserved==0) {
+    _mi_warning_message("failed to reserve %zu GiB huge pages\n", pages);
+    return ENOMEM;
+  }
+  _mi_verbose_message("numa node %i: reserved %zu GiB huge pages (of the %zu GiB requested)\n", numa_node, pages_reserved, pages);
+
+  if (!mi_manage_os_memory(p, hsize, true, true, true, numa_node)) {
+    _mi_os_free_huge_pages(p, hsize, &_mi_stats_main);
+    return ENOMEM;
+  }
+  return 0;
+}
+
+
+// reserve huge pages evenly among the given number of numa nodes (or use the available ones as detected)
+int mi_reserve_huge_os_pages_interleave(size_t pages, size_t numa_nodes, size_t timeout_msecs) mi_attr_noexcept {
+  if (pages == 0) return 0;
+
+  // pages per numa node
+  size_t numa_count = (numa_nodes > 0 ? numa_nodes : _mi_os_numa_node_count());
+  if (numa_count <= 0) numa_count = 1;
+  const size_t pages_per = pages / numa_count;
+  const size_t pages_mod = pages % numa_count;
+  const size_t timeout_per = (timeout_msecs==0 ? 0 : (timeout_msecs / numa_count) + 50);
+
+  // reserve evenly among numa nodes
+  for (size_t numa_node = 0; numa_node < numa_count && pages > 0; numa_node++) {
+    size_t node_pages = pages_per;  // can be 0
+    if (numa_node < pages_mod) node_pages++;
+    int err = mi_reserve_huge_os_pages_at(node_pages, (int)numa_node, timeout_per);
+    if (err) return err;
+    if (pages < node_pages) {
+      pages = 0;
+    }
+    else {
+      pages -= node_pages;
+    }
+  }
+
+  return 0;
+}
+
+int mi_reserve_huge_os_pages(size_t pages, double max_secs, size_t* pages_reserved) mi_attr_noexcept {
+  MI_UNUSED(max_secs);
+  _mi_warning_message("mi_reserve_huge_os_pages is deprecated: use mi_reserve_huge_os_pages_interleave/at instead\n");
+  if (pages_reserved != NULL) *pages_reserved = 0;
+  int err = mi_reserve_huge_os_pages_interleave(pages, 0, (size_t)(max_secs * 1000.0));
+  if (err==0 && pages_reserved!=NULL) *pages_reserved = pages;
+  return err;
+}
diff --git a/Objects/mimalloc/bitmap.c b/Objects/mimalloc/bitmap.c
new file mode 100644
index 0000000000000..af6de0a12c41d
--- /dev/null
+++ b/Objects/mimalloc/bitmap.c
@@ -0,0 +1,395 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2019-2021 Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+
+/* ----------------------------------------------------------------------------
+Concurrent bitmap that can set/reset sequences of bits atomically,
+represeted as an array of fields where each field is a machine word (`size_t`)
+
+There are two api's; the standard one cannot have sequences that cross
+between the bitmap fields (and a sequence must be <= MI_BITMAP_FIELD_BITS).
+(this is used in region allocation)
+
+The `_across` postfixed functions do allow sequences that can cross over
+between the fields. (This is used in arena allocation)
+---------------------------------------------------------------------------- */
+
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+#include "bitmap.h"
+
+/* -----------------------------------------------------------
+  Bitmap definition
+----------------------------------------------------------- */
+
+// The bit mask for a given number of blocks at a specified bit index.
+static inline size_t mi_bitmap_mask_(size_t count, size_t bitidx) {
+  mi_assert_internal(count + bitidx <= MI_BITMAP_FIELD_BITS);
+  mi_assert_internal(count > 0);
+  if (count >= MI_BITMAP_FIELD_BITS) return MI_BITMAP_FIELD_FULL;
+  if (count == 0) return 0;
+  return ((((size_t)1 << count) - 1) << bitidx);
+}
+
+
+/* -----------------------------------------------------------
+  Claim a bit sequence atomically
+----------------------------------------------------------- */
+
+// Try to atomically claim a sequence of `count` bits in a single
+// field at `idx` in `bitmap`. Returns `true` on success.
+inline bool _mi_bitmap_try_find_claim_field(mi_bitmap_t bitmap, size_t idx, const size_t count, mi_bitmap_index_t* bitmap_idx)
+{
+  mi_assert_internal(bitmap_idx != NULL);
+  mi_assert_internal(count <= MI_BITMAP_FIELD_BITS);
+  mi_assert_internal(count > 0);
+  mi_bitmap_field_t* field = &bitmap[idx];
+  size_t map  = mi_atomic_load_relaxed(field);
+  if (map==MI_BITMAP_FIELD_FULL) return false; // short cut
+
+  // search for 0-bit sequence of length count
+  const size_t mask = mi_bitmap_mask_(count, 0);
+  const size_t bitidx_max = MI_BITMAP_FIELD_BITS - count;
+
+#ifdef MI_HAVE_FAST_BITSCAN
+  size_t bitidx = mi_ctz(~map);    // quickly find the first zero bit if possible
+#else
+  size_t bitidx = 0;               // otherwise start at 0
+#endif
+  size_t m = (mask << bitidx);     // invariant: m == mask shifted by bitidx
+
+  // scan linearly for a free range of zero bits
+  while (bitidx <= bitidx_max) {
+    const size_t mapm = map & m;
+    if (mapm == 0) {  // are the mask bits free at bitidx?
+      mi_assert_internal((m >> bitidx) == mask); // no overflow?
+      const size_t newmap = map | m;
+      mi_assert_internal((newmap^map) >> bitidx == mask);
+      if (!mi_atomic_cas_weak_acq_rel(field, &map, newmap)) {  // TODO: use strong cas here?
+        // no success, another thread claimed concurrently.. keep going (with updated `map`)
+        continue;
+      }
+      else {
+        // success, we claimed the bits!
+        *bitmap_idx = mi_bitmap_index_create(idx, bitidx);
+        return true;
+      }
+    }
+    else {
+      // on to the next bit range
+#ifdef MI_HAVE_FAST_BITSCAN
+      const size_t shift = (count == 1 ? 1 : mi_bsr(mapm) - bitidx + 1);
+      mi_assert_internal(shift > 0 && shift <= count);
+#else
+      const size_t shift = 1;
+#endif
+      bitidx += shift;
+      m <<= shift;
+    }
+  }
+  // no bits found
+  return false;
+}
+
+// Find `count` bits of 0 and set them to 1 atomically; returns `true` on success.
+// Starts at idx, and wraps around to search in all `bitmap_fields` fields.
+// `count` can be at most MI_BITMAP_FIELD_BITS and will never cross fields.
+bool _mi_bitmap_try_find_from_claim(mi_bitmap_t bitmap, const size_t bitmap_fields, const size_t start_field_idx, const size_t count, mi_bitmap_index_t* bitmap_idx) {
+  size_t idx = start_field_idx;
+  for (size_t visited = 0; visited < bitmap_fields; visited++, idx++) {
+    if (idx >= bitmap_fields) idx = 0; // wrap
+    if (_mi_bitmap_try_find_claim_field(bitmap, idx, count, bitmap_idx)) {
+      return true;
+    }
+  }
+  return false;
+}
+
+/*
+// Find `count` bits of 0 and set them to 1 atomically; returns `true` on success.
+// For now, `count` can be at most MI_BITMAP_FIELD_BITS and will never span fields.
+bool _mi_bitmap_try_find_claim(mi_bitmap_t bitmap, const size_t bitmap_fields, const size_t count, mi_bitmap_index_t* bitmap_idx) {
+  return _mi_bitmap_try_find_from_claim(bitmap, bitmap_fields, 0, count, bitmap_idx);
+}
+*/
+
+// Set `count` bits at `bitmap_idx` to 0 atomically
+// Returns `true` if all `count` bits were 1 previously.
+bool _mi_bitmap_unclaim(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx) {
+  const size_t idx = mi_bitmap_index_field(bitmap_idx);
+  const size_t bitidx = mi_bitmap_index_bit_in_field(bitmap_idx);
+  const size_t mask = mi_bitmap_mask_(count, bitidx);
+  mi_assert_internal(bitmap_fields > idx); MI_UNUSED(bitmap_fields);
+  // mi_assert_internal((bitmap[idx] & mask) == mask);
+  size_t prev = mi_atomic_and_acq_rel(&bitmap[idx], ~mask);
+  return ((prev & mask) == mask);
+}
+
+
+// Set `count` bits at `bitmap_idx` to 1 atomically
+// Returns `true` if all `count` bits were 0 previously. `any_zero` is `true` if there was at least one zero bit.
+bool _mi_bitmap_claim(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx, bool* any_zero) {
+  const size_t idx = mi_bitmap_index_field(bitmap_idx);
+  const size_t bitidx = mi_bitmap_index_bit_in_field(bitmap_idx);
+  const size_t mask = mi_bitmap_mask_(count, bitidx);
+  mi_assert_internal(bitmap_fields > idx); MI_UNUSED(bitmap_fields);
+  //mi_assert_internal(any_zero != NULL || (bitmap[idx] & mask) == 0);
+  size_t prev = mi_atomic_or_acq_rel(&bitmap[idx], mask);
+  if (any_zero != NULL) *any_zero = ((prev & mask) != mask);
+  return ((prev & mask) == 0);
+}
+
+// Returns `true` if all `count` bits were 1. `any_ones` is `true` if there was at least one bit set to one.
+static bool mi_bitmap_is_claimedx(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx, bool* any_ones) {
+  const size_t idx = mi_bitmap_index_field(bitmap_idx);
+  const size_t bitidx = mi_bitmap_index_bit_in_field(bitmap_idx);
+  const size_t mask = mi_bitmap_mask_(count, bitidx);
+  mi_assert_internal(bitmap_fields > idx); MI_UNUSED(bitmap_fields);
+  size_t field = mi_atomic_load_relaxed(&bitmap[idx]);
+  if (any_ones != NULL) *any_ones = ((field & mask) != 0);
+  return ((field & mask) == mask);
+}
+
+bool _mi_bitmap_is_claimed(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx) {
+  return mi_bitmap_is_claimedx(bitmap, bitmap_fields, count, bitmap_idx, NULL);
+}
+
+bool _mi_bitmap_is_any_claimed(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx) {
+  bool any_ones;
+  mi_bitmap_is_claimedx(bitmap, bitmap_fields, count, bitmap_idx, &any_ones);
+  return any_ones;
+}
+
+
+//--------------------------------------------------------------------------
+// the `_across` functions work on bitmaps where sequences can cross over
+// between the fields. This is used in arena allocation
+//--------------------------------------------------------------------------
+
+// Try to atomically claim a sequence of `count` bits starting from the field 
+// at `idx` in `bitmap` and crossing into subsequent fields. Returns `true` on success.
+static bool mi_bitmap_try_find_claim_field_across(mi_bitmap_t bitmap, size_t bitmap_fields, size_t idx, const size_t count, const size_t retries, mi_bitmap_index_t* bitmap_idx)
+{
+  mi_assert_internal(bitmap_idx != NULL);
+  
+  // check initial trailing zeros
+  mi_bitmap_field_t* field = &bitmap[idx];
+  size_t map = mi_atomic_load_relaxed(field);  
+  const size_t initial = mi_clz(map);  // count of initial zeros starting at idx
+  mi_assert_internal(initial <= MI_BITMAP_FIELD_BITS);
+  if (initial == 0)     return false;
+  if (initial >= count) return _mi_bitmap_try_find_claim_field(bitmap, idx, count, bitmap_idx);     // no need to cross fields
+  if (_mi_divide_up(count - initial, MI_BITMAP_FIELD_BITS) >= (bitmap_fields - idx)) return false; // not enough entries
+
+  // scan ahead
+  size_t found = initial;
+  size_t mask = 0;     // mask bits for the final field
+  while(found < count) {
+    field++;
+    map = mi_atomic_load_relaxed(field);
+    const size_t mask_bits = (found + MI_BITMAP_FIELD_BITS <= count ? MI_BITMAP_FIELD_BITS : (count - found));
+    mask = mi_bitmap_mask_(mask_bits, 0);
+    if ((map & mask) != 0) return false;
+    found += mask_bits;
+  }
+  mi_assert_internal(field < &bitmap[bitmap_fields]);
+
+  // found range of zeros up to the final field; mask contains mask in the final field
+  // now claim it atomically
+  mi_bitmap_field_t* const final_field = field;
+  const size_t final_mask = mask;
+  mi_bitmap_field_t* const initial_field = &bitmap[idx];
+  const size_t initial_mask = mi_bitmap_mask_(initial, MI_BITMAP_FIELD_BITS - initial);
+
+  // initial field
+  size_t newmap;
+  field = initial_field;
+  map = mi_atomic_load_relaxed(field);
+  do {
+    newmap = map | initial_mask;
+    if ((map & initial_mask) != 0) { goto rollback; };
+  } while (!mi_atomic_cas_strong_acq_rel(field, &map, newmap));
+  
+  // intermediate fields
+  while (++field < final_field) {
+    newmap = MI_BITMAP_FIELD_FULL;
+    map = 0;
+    if (!mi_atomic_cas_strong_acq_rel(field, &map, newmap)) { goto rollback; }
+  }
+  
+  // final field
+  mi_assert_internal(field == final_field);
+  map = mi_atomic_load_relaxed(field);
+  do {
+    newmap = map | final_mask;
+    if ((map & final_mask) != 0) { goto rollback; }
+  } while (!mi_atomic_cas_strong_acq_rel(field, &map, newmap));
+
+  // claimed!
+  *bitmap_idx = mi_bitmap_index_create(idx, MI_BITMAP_FIELD_BITS - initial);
+  return true;
+
+rollback: 
+  // roll back intermediate fields
+  while (--field > initial_field) {
+    newmap = 0;
+    map = MI_BITMAP_FIELD_FULL;
+    mi_assert_internal(mi_atomic_load_relaxed(field) == map);
+    mi_atomic_store_release(field, newmap);
+  }
+  if (field == initial_field) {
+    map = mi_atomic_load_relaxed(field);
+    do {
+      mi_assert_internal((map & initial_mask) == initial_mask);
+      newmap = map & ~initial_mask;
+    } while (!mi_atomic_cas_strong_acq_rel(field, &map, newmap));
+  }  
+  // retry? (we make a recursive call instead of goto to be able to use const declarations)
+  if (retries < 4) {
+    return mi_bitmap_try_find_claim_field_across(bitmap, bitmap_fields, idx, count, retries+1, bitmap_idx);
+  }
+  else {
+    return false;
+  }
+}
+
+
+// Find `count` bits of zeros and set them to 1 atomically; returns `true` on success.
+// Starts at idx, and wraps around to search in all `bitmap_fields` fields.
+bool _mi_bitmap_try_find_from_claim_across(mi_bitmap_t bitmap, const size_t bitmap_fields, const size_t start_field_idx, const size_t count, mi_bitmap_index_t* bitmap_idx) {
+  mi_assert_internal(count > 0);
+  if (count==1) return _mi_bitmap_try_find_from_claim(bitmap, bitmap_fields, start_field_idx, count, bitmap_idx);
+  size_t idx = start_field_idx;
+  for (size_t visited = 0; visited < bitmap_fields; visited++, idx++) {
+    if (idx >= bitmap_fields) idx = 0; // wrap
+    // try to claim inside the field
+    if (count <= MI_BITMAP_FIELD_BITS) {
+      if (_mi_bitmap_try_find_claim_field(bitmap, idx, count, bitmap_idx)) {
+        return true;
+      }
+    }
+    // try to claim across fields
+    if (mi_bitmap_try_find_claim_field_across(bitmap, bitmap_fields, idx, count, 0, bitmap_idx)) {
+      return true;
+    }
+  }
+  return false;
+}
+
+// Helper for masks across fields; returns the mid count, post_mask may be 0
+static size_t mi_bitmap_mask_across(mi_bitmap_index_t bitmap_idx, size_t bitmap_fields, size_t count, size_t* pre_mask, size_t* mid_mask, size_t* post_mask) {
+  MI_UNUSED_RELEASE(bitmap_fields);
+  const size_t bitidx = mi_bitmap_index_bit_in_field(bitmap_idx);
+  if (mi_likely(bitidx + count <= MI_BITMAP_FIELD_BITS)) {
+    *pre_mask = mi_bitmap_mask_(count, bitidx);
+    *mid_mask = 0;
+    *post_mask = 0;
+    mi_assert_internal(mi_bitmap_index_field(bitmap_idx) < bitmap_fields);
+    return 0;
+  }
+  else {
+    const size_t pre_bits = MI_BITMAP_FIELD_BITS - bitidx;
+    mi_assert_internal(pre_bits < count);
+    *pre_mask = mi_bitmap_mask_(pre_bits, bitidx);
+    count -= pre_bits;
+    const size_t mid_count = (count / MI_BITMAP_FIELD_BITS);
+    *mid_mask = MI_BITMAP_FIELD_FULL;
+    count %= MI_BITMAP_FIELD_BITS;
+    *post_mask = (count==0 ? 0 : mi_bitmap_mask_(count, 0));
+    mi_assert_internal(mi_bitmap_index_field(bitmap_idx) + mid_count + (count==0 ? 0 : 1) < bitmap_fields);
+    return mid_count;
+  }
+}
+
+// Set `count` bits at `bitmap_idx` to 0 atomically
+// Returns `true` if all `count` bits were 1 previously.
+bool _mi_bitmap_unclaim_across(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx) {
+  size_t idx = mi_bitmap_index_field(bitmap_idx);
+  size_t pre_mask;
+  size_t mid_mask;
+  size_t post_mask;
+  size_t mid_count = mi_bitmap_mask_across(bitmap_idx, bitmap_fields, count, &pre_mask, &mid_mask, &post_mask);  
+  bool all_one = true;
+  mi_bitmap_field_t* field = &bitmap[idx];
+  size_t prev = mi_atomic_and_acq_rel(field++, ~pre_mask);
+  if ((prev & pre_mask) != pre_mask) all_one = false;
+  while(mid_count-- > 0) {
+    prev = mi_atomic_and_acq_rel(field++, ~mid_mask);
+    if ((prev & mid_mask) != mid_mask) all_one = false;
+  }
+  if (post_mask!=0) {
+    prev = mi_atomic_and_acq_rel(field, ~post_mask);
+    if ((prev & post_mask) != post_mask) all_one = false;
+  }
+  return all_one;  
+}
+
+// Set `count` bits at `bitmap_idx` to 1 atomically
+// Returns `true` if all `count` bits were 0 previously. `any_zero` is `true` if there was at least one zero bit.
+bool _mi_bitmap_claim_across(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx, bool* pany_zero) {
+  size_t idx = mi_bitmap_index_field(bitmap_idx);
+  size_t pre_mask;
+  size_t mid_mask;
+  size_t post_mask;
+  size_t mid_count = mi_bitmap_mask_across(bitmap_idx, bitmap_fields, count, &pre_mask, &mid_mask, &post_mask);
+  bool all_zero = true;
+  bool any_zero = false;
+  _Atomic(size_t)*field = &bitmap[idx];
+  size_t prev = mi_atomic_or_acq_rel(field++, pre_mask);
+  if ((prev & pre_mask) != 0) all_zero = false;
+  if ((prev & pre_mask) != pre_mask) any_zero = true;
+  while (mid_count-- > 0) {
+    prev = mi_atomic_or_acq_rel(field++, mid_mask);
+    if ((prev & mid_mask) != 0) all_zero = false;
+    if ((prev & mid_mask) != mid_mask) any_zero = true;
+  }
+  if (post_mask!=0) {
+    prev = mi_atomic_or_acq_rel(field, post_mask);
+    if ((prev & post_mask) != 0) all_zero = false;
+    if ((prev & post_mask) != post_mask) any_zero = true;
+  }
+  if (pany_zero != NULL) *pany_zero = any_zero;
+  return all_zero;
+}
+
+
+// Returns `true` if all `count` bits were 1. 
+// `any_ones` is `true` if there was at least one bit set to one.
+static bool mi_bitmap_is_claimedx_across(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx, bool* pany_ones) {
+  size_t idx = mi_bitmap_index_field(bitmap_idx);
+  size_t pre_mask;
+  size_t mid_mask;
+  size_t post_mask;
+  size_t mid_count = mi_bitmap_mask_across(bitmap_idx, bitmap_fields, count, &pre_mask, &mid_mask, &post_mask);
+  bool all_ones = true;
+  bool any_ones = false;
+  mi_bitmap_field_t* field = &bitmap[idx];
+  size_t prev = mi_atomic_load_relaxed(field++);
+  if ((prev & pre_mask) != pre_mask) all_ones = false;
+  if ((prev & pre_mask) != 0) any_ones = true;
+  while (mid_count-- > 0) {
+    prev = mi_atomic_load_relaxed(field++);
+    if ((prev & mid_mask) != mid_mask) all_ones = false;
+    if ((prev & mid_mask) != 0) any_ones = true;
+  }
+  if (post_mask!=0) {
+    prev = mi_atomic_load_relaxed(field);
+    if ((prev & post_mask) != post_mask) all_ones = false;
+    if ((prev & post_mask) != 0) any_ones = true;
+  }  
+  if (pany_ones != NULL) *pany_ones = any_ones;
+  return all_ones;
+}
+
+bool _mi_bitmap_is_claimed_across(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx) {
+  return mi_bitmap_is_claimedx_across(bitmap, bitmap_fields, count, bitmap_idx, NULL);
+}
+
+bool _mi_bitmap_is_any_claimed_across(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx) {
+  bool any_ones;
+  mi_bitmap_is_claimedx_across(bitmap, bitmap_fields, count, bitmap_idx, &any_ones);
+  return any_ones;
+}
diff --git a/Objects/mimalloc/bitmap.h b/Objects/mimalloc/bitmap.h
new file mode 100644
index 0000000000000..7bd3106c9c9b6
--- /dev/null
+++ b/Objects/mimalloc/bitmap.h
@@ -0,0 +1,107 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2019-2020 Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+
+/* ----------------------------------------------------------------------------
+Concurrent bitmap that can set/reset sequences of bits atomically,
+represeted as an array of fields where each field is a machine word (`size_t`)
+
+There are two api's; the standard one cannot have sequences that cross
+between the bitmap fields (and a sequence must be <= MI_BITMAP_FIELD_BITS).
+(this is used in region allocation)
+
+The `_across` postfixed functions do allow sequences that can cross over
+between the fields. (This is used in arena allocation)
+---------------------------------------------------------------------------- */
+#pragma once
+#ifndef MI_BITMAP_H
+#define MI_BITMAP_H
+
+/* -----------------------------------------------------------
+  Bitmap definition
+----------------------------------------------------------- */
+
+#define MI_BITMAP_FIELD_BITS   (8*MI_SIZE_SIZE)
+#define MI_BITMAP_FIELD_FULL   (~((size_t)0))   // all bits set
+
+// An atomic bitmap of `size_t` fields
+typedef _Atomic(size_t)  mi_bitmap_field_t;
+typedef mi_bitmap_field_t*  mi_bitmap_t;
+
+// A bitmap index is the index of the bit in a bitmap.
+typedef size_t mi_bitmap_index_t;
+
+// Create a bit index.
+static inline mi_bitmap_index_t mi_bitmap_index_create(size_t idx, size_t bitidx) {
+  mi_assert_internal(bitidx < MI_BITMAP_FIELD_BITS);
+  return (idx*MI_BITMAP_FIELD_BITS) + bitidx;
+}
+
+// Create a bit index.
+static inline mi_bitmap_index_t mi_bitmap_index_create_from_bit(size_t full_bitidx) {  
+  return mi_bitmap_index_create(full_bitidx / MI_BITMAP_FIELD_BITS, full_bitidx % MI_BITMAP_FIELD_BITS);
+}
+
+// Get the field index from a bit index.
+static inline size_t mi_bitmap_index_field(mi_bitmap_index_t bitmap_idx) {
+  return (bitmap_idx / MI_BITMAP_FIELD_BITS);
+}
+
+// Get the bit index in a bitmap field
+static inline size_t mi_bitmap_index_bit_in_field(mi_bitmap_index_t bitmap_idx) {
+  return (bitmap_idx % MI_BITMAP_FIELD_BITS);
+}
+
+// Get the full bit index
+static inline size_t mi_bitmap_index_bit(mi_bitmap_index_t bitmap_idx) {
+  return bitmap_idx;
+}
+
+/* -----------------------------------------------------------
+  Claim a bit sequence atomically
+----------------------------------------------------------- */
+
+// Try to atomically claim a sequence of `count` bits in a single
+// field at `idx` in `bitmap`. Returns `true` on success.
+bool _mi_bitmap_try_find_claim_field(mi_bitmap_t bitmap, size_t idx, const size_t count, mi_bitmap_index_t* bitmap_idx);
+
+// Starts at idx, and wraps around to search in all `bitmap_fields` fields.
+// For now, `count` can be at most MI_BITMAP_FIELD_BITS and will never cross fields.
+bool _mi_bitmap_try_find_from_claim(mi_bitmap_t bitmap, const size_t bitmap_fields, const size_t start_field_idx, const size_t count, mi_bitmap_index_t* bitmap_idx);
+
+// Set `count` bits at `bitmap_idx` to 0 atomically
+// Returns `true` if all `count` bits were 1 previously.
+bool _mi_bitmap_unclaim(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx);
+
+// Set `count` bits at `bitmap_idx` to 1 atomically
+// Returns `true` if all `count` bits were 0 previously. `any_zero` is `true` if there was at least one zero bit.
+bool _mi_bitmap_claim(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx, bool* any_zero);
+
+bool _mi_bitmap_is_claimed(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx);
+bool _mi_bitmap_is_any_claimed(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx);
+
+
+//--------------------------------------------------------------------------
+// the `_across` functions work on bitmaps where sequences can cross over
+// between the fields. This is used in arena allocation
+//--------------------------------------------------------------------------
+
+// Find `count` bits of zeros and set them to 1 atomically; returns `true` on success.
+// Starts at idx, and wraps around to search in all `bitmap_fields` fields.
+bool _mi_bitmap_try_find_from_claim_across(mi_bitmap_t bitmap, const size_t bitmap_fields, const size_t start_field_idx, const size_t count, mi_bitmap_index_t* bitmap_idx);
+
+// Set `count` bits at `bitmap_idx` to 0 atomically
+// Returns `true` if all `count` bits were 1 previously.
+bool _mi_bitmap_unclaim_across(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx);
+
+// Set `count` bits at `bitmap_idx` to 1 atomically
+// Returns `true` if all `count` bits were 0 previously. `any_zero` is `true` if there was at least one zero bit.
+bool _mi_bitmap_claim_across(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx, bool* pany_zero);
+
+bool _mi_bitmap_is_claimed_across(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx);
+bool _mi_bitmap_is_any_claimed_across(mi_bitmap_t bitmap, size_t bitmap_fields, size_t count, mi_bitmap_index_t bitmap_idx);
+
+#endif
diff --git a/Objects/mimalloc/heap.c b/Objects/mimalloc/heap.c
new file mode 100644
index 0000000000000..4fdfb0b96bf96
--- /dev/null
+++ b/Objects/mimalloc/heap.c
@@ -0,0 +1,577 @@
+/*----------------------------------------------------------------------------
+Copyright (c) 2018-2021, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+#include "mimalloc-atomic.h"
+
+#include <string.h>  // memset, memcpy
+
+#if defined(_MSC_VER) && (_MSC_VER < 1920)
+#pragma warning(disable:4204)  // non-constant aggregate initializer
+#endif
+
+/* -----------------------------------------------------------
+  Helpers
+----------------------------------------------------------- */
+
+// return `true` if ok, `false` to break
+typedef bool (heap_page_visitor_fun)(mi_heap_t* heap, mi_page_queue_t* pq, mi_page_t* page, void* arg1, void* arg2);
+
+// Visit all pages in a heap; returns `false` if break was called.
+static bool mi_heap_visit_pages(mi_heap_t* heap, heap_page_visitor_fun* fn, void* arg1, void* arg2)
+{
+  if (heap==NULL || heap->page_count==0) return 0;
+
+  // visit all pages
+  #if MI_DEBUG>1
+  size_t total = heap->page_count;
+  #endif
+  size_t count = 0;
+  for (size_t i = 0; i <= MI_BIN_FULL; i++) {
+    mi_page_queue_t* pq = &heap->pages[i];
+    mi_page_t* page = pq->first;
+    while(page != NULL) {
+      mi_page_t* next = page->next; // save next in case the page gets removed from the queue
+      mi_assert_internal(mi_page_heap(page) == heap);
+      count++;
+      if (!fn(heap, pq, page, arg1, arg2)) return false;
+      page = next; // and continue
+    }
+  }
+  mi_assert_internal(count == total);
+  return true;
+}
+
+
+#if MI_DEBUG>=2
+static bool mi_heap_page_is_valid(mi_heap_t* heap, mi_page_queue_t* pq, mi_page_t* page, void* arg1, void* arg2) {
+  MI_UNUSED(arg1);
+  MI_UNUSED(arg2);
+  MI_UNUSED(pq);
+  mi_assert_internal(mi_page_heap(page) == heap);
+  mi_segment_t* segment = _mi_page_segment(page);
+  mi_assert_internal(segment->thread_id == heap->thread_id);
+  mi_assert_expensive(_mi_page_is_valid(page));
+  return true;
+}
+#endif
+#if MI_DEBUG>=3
+static bool mi_heap_is_valid(mi_heap_t* heap) {
+  mi_assert_internal(heap!=NULL);
+  mi_heap_visit_pages(heap, &mi_heap_page_is_valid, NULL, NULL);
+  return true;
+}
+#endif
+
+
+
+
+/* -----------------------------------------------------------
+  "Collect" pages by migrating `local_free` and `thread_free`
+  lists and freeing empty pages. This is done when a thread
+  stops (and in that case abandons pages if there are still
+  blocks alive)
+----------------------------------------------------------- */
+
+typedef enum mi_collect_e {
+  MI_NORMAL,
+  MI_FORCE,
+  MI_ABANDON
+} mi_collect_t;
+
+
+static bool mi_heap_page_collect(mi_heap_t* heap, mi_page_queue_t* pq, mi_page_t* page, void* arg_collect, void* arg2 ) {
+  MI_UNUSED(arg2);
+  MI_UNUSED(heap);
+  mi_assert_internal(mi_heap_page_is_valid(heap, pq, page, NULL, NULL));
+  mi_collect_t collect = *((mi_collect_t*)arg_collect);
+  _mi_page_free_collect(page, collect >= MI_FORCE);
+  if (mi_page_all_free(page)) {
+    // no more used blocks, free the page. 
+    // note: this will free retired pages as well.
+    _mi_page_free(page, pq, collect >= MI_FORCE);
+  }
+  else if (collect == MI_ABANDON) {
+    // still used blocks but the thread is done; abandon the page
+    _mi_page_abandon(page, pq);
+  }
+  return true; // don't break
+}
+
+static bool mi_heap_page_never_delayed_free(mi_heap_t* heap, mi_page_queue_t* pq, mi_page_t* page, void* arg1, void* arg2) {
+  MI_UNUSED(arg1);
+  MI_UNUSED(arg2);
+  MI_UNUSED(heap);
+  MI_UNUSED(pq);
+  _mi_page_use_delayed_free(page, MI_NEVER_DELAYED_FREE, false);
+  return true; // don't break
+}
+
+static void mi_heap_collect_ex(mi_heap_t* heap, mi_collect_t collect)
+{
+  if (heap==NULL || !mi_heap_is_initialized(heap)) return;
+
+  const bool force = collect >= MI_FORCE;  
+  _mi_deferred_free(heap, force);
+
+  // note: never reclaim on collect but leave it to threads that need storage to reclaim 
+  const bool force_main = 
+    #ifdef NDEBUG
+      collect == MI_FORCE
+    #else
+      collect >= MI_FORCE
+    #endif
+      && _mi_is_main_thread() && mi_heap_is_backing(heap) && !heap->no_reclaim;
+
+  if (force_main) {
+    // the main thread is abandoned (end-of-program), try to reclaim all abandoned segments.
+    // if all memory is freed by now, all segments should be freed.
+    _mi_abandoned_reclaim_all(heap, &heap->tld->segments);
+  }
+  
+  // if abandoning, mark all pages to no longer add to delayed_free
+  if (collect == MI_ABANDON) {
+    mi_heap_visit_pages(heap, &mi_heap_page_never_delayed_free, NULL, NULL);
+  }
+
+  // free thread delayed blocks.
+  // (if abandoning, after this there are no more thread-delayed references into the pages.)
+  _mi_heap_delayed_free(heap);
+
+  // collect retired pages
+  _mi_heap_collect_retired(heap, force);
+
+  // collect all pages owned by this thread
+  mi_heap_visit_pages(heap, &mi_heap_page_collect, &collect, NULL);
+  mi_assert_internal( collect != MI_ABANDON || mi_atomic_load_ptr_acquire(mi_block_t,&heap->thread_delayed_free) == NULL );
+
+  // collect abandoned segments (in particular, decommit expired parts of segments in the abandoned segment list)
+  // note: forced decommit can be quite expensive if many threads are created/destroyed so we do not force on abandonment
+  _mi_abandoned_collect(heap, collect == MI_FORCE /* force? */, &heap->tld->segments);
+
+  // collect segment local caches
+  if (force) {
+    _mi_segment_thread_collect(&heap->tld->segments);
+  }
+
+  // decommit in global segment caches
+  // note: forced decommit can be quite expensive if many threads are created/destroyed so we do not force on abandonment
+  _mi_segment_cache_collect( collect == MI_FORCE, &heap->tld->os);  
+
+  // collect regions on program-exit (or shared library unload)
+  if (force && _mi_is_main_thread() && mi_heap_is_backing(heap)) {
+    //_mi_mem_collect(&heap->tld->os);
+  }
+}
+
+void _mi_heap_collect_abandon(mi_heap_t* heap) {
+  mi_heap_collect_ex(heap, MI_ABANDON);
+}
+
+void mi_heap_collect(mi_heap_t* heap, bool force) mi_attr_noexcept {
+  mi_heap_collect_ex(heap, (force ? MI_FORCE : MI_NORMAL));
+}
+
+void mi_collect(bool force) mi_attr_noexcept {
+  mi_heap_collect(mi_get_default_heap(), force);
+}
+
+
+/* -----------------------------------------------------------
+  Heap new
+----------------------------------------------------------- */
+
+mi_heap_t* mi_heap_get_default(void) {
+  mi_thread_init();
+  return mi_get_default_heap();
+}
+
+mi_heap_t* mi_heap_get_backing(void) {
+  mi_heap_t* heap = mi_heap_get_default();
+  mi_assert_internal(heap!=NULL);
+  mi_heap_t* bheap = heap->tld->heap_backing;
+  mi_assert_internal(bheap!=NULL);
+  mi_assert_internal(bheap->thread_id == _mi_thread_id());
+  return bheap;
+}
+
+mi_heap_t* mi_heap_new(void) {
+  mi_heap_t* bheap = mi_heap_get_backing();
+  mi_heap_t* heap = mi_heap_malloc_tp(bheap, mi_heap_t);  // todo: OS allocate in secure mode?
+  if (heap==NULL) return NULL;
+  _mi_memcpy_aligned(heap, &_mi_heap_empty, sizeof(mi_heap_t));
+  heap->tld = bheap->tld;
+  heap->thread_id = _mi_thread_id();
+  _mi_random_split(&bheap->random, &heap->random);
+  heap->cookie  = _mi_heap_random_next(heap) | 1;
+  heap->keys[0] = _mi_heap_random_next(heap);
+  heap->keys[1] = _mi_heap_random_next(heap);
+  heap->no_reclaim = true;  // don't reclaim abandoned pages or otherwise destroy is unsafe
+  // push on the thread local heaps list
+  heap->next = heap->tld->heaps;
+  heap->tld->heaps = heap;
+  return heap;
+}
+
+uintptr_t _mi_heap_random_next(mi_heap_t* heap) {
+  return _mi_random_next(&heap->random);
+}
+
+// zero out the page queues
+static void mi_heap_reset_pages(mi_heap_t* heap) {
+  mi_assert_internal(heap != NULL);
+  mi_assert_internal(mi_heap_is_initialized(heap));
+  // TODO: copy full empty heap instead?
+  memset(&heap->pages_free_direct, 0, sizeof(heap->pages_free_direct));
+#ifdef MI_MEDIUM_DIRECT
+  memset(&heap->pages_free_medium, 0, sizeof(heap->pages_free_medium));
+#endif
+  _mi_memcpy_aligned(&heap->pages, &_mi_heap_empty.pages, sizeof(heap->pages));
+  heap->thread_delayed_free = NULL;
+  heap->page_count = 0;
+}
+
+// called from `mi_heap_destroy` and `mi_heap_delete` to free the internal heap resources.
+static void mi_heap_free(mi_heap_t* heap) {
+  mi_assert(heap != NULL);
+  mi_assert_internal(mi_heap_is_initialized(heap));
+  if (heap==NULL || !mi_heap_is_initialized(heap)) return;
+  if (mi_heap_is_backing(heap)) return; // dont free the backing heap
+
+  // reset default
+  if (mi_heap_is_default(heap)) {
+    _mi_heap_set_default_direct(heap->tld->heap_backing);
+  }
+
+  // remove ourselves from the thread local heaps list
+  // linear search but we expect the number of heaps to be relatively small
+  mi_heap_t* prev = NULL;
+  mi_heap_t* curr = heap->tld->heaps; 
+  while (curr != heap && curr != NULL) {
+    prev = curr;
+    curr = curr->next;
+  }
+  mi_assert_internal(curr == heap);
+  if (curr == heap) {
+    if (prev != NULL) { prev->next = heap->next; }
+                 else { heap->tld->heaps = heap->next; }
+  }
+  mi_assert_internal(heap->tld->heaps != NULL);
+
+  // and free the used memory
+  mi_free(heap);
+}
+
+
+/* -----------------------------------------------------------
+  Heap destroy
+----------------------------------------------------------- */
+
+static bool _mi_heap_page_destroy(mi_heap_t* heap, mi_page_queue_t* pq, mi_page_t* page, void* arg1, void* arg2) {
+  MI_UNUSED(arg1);
+  MI_UNUSED(arg2);
+  MI_UNUSED(heap);
+  MI_UNUSED(pq);
+
+  // ensure no more thread_delayed_free will be added
+  _mi_page_use_delayed_free(page, MI_NEVER_DELAYED_FREE, false);
+
+  // stats
+  const size_t bsize = mi_page_block_size(page);
+  if (bsize > MI_MEDIUM_OBJ_SIZE_MAX) {
+    if (bsize <= MI_LARGE_OBJ_SIZE_MAX) {
+      mi_heap_stat_decrease(heap, large, bsize);
+    }
+    else {
+      mi_heap_stat_decrease(heap, huge, bsize);
+    }
+  }
+#if (MI_STAT)
+  _mi_page_free_collect(page, false);  // update used count
+  const size_t inuse = page->used;
+  if (bsize <= MI_LARGE_OBJ_SIZE_MAX) {
+    mi_heap_stat_decrease(heap, normal, bsize * inuse);
+#if (MI_STAT>1)
+    mi_heap_stat_decrease(heap, normal_bins[_mi_bin(bsize)], inuse);
+#endif
+  }
+  mi_heap_stat_decrease(heap, malloc, bsize * inuse);  // todo: off for aligned blocks...
+#endif
+
+  /// pretend it is all free now
+  mi_assert_internal(mi_page_thread_free(page) == NULL);
+  page->used = 0;
+
+  // and free the page
+  // mi_page_free(page,false);
+  page->next = NULL;
+  page->prev = NULL;
+  _mi_segment_page_free(page,false /* no force? */, &heap->tld->segments);
+
+  return true; // keep going
+}
+
+void _mi_heap_destroy_pages(mi_heap_t* heap) {
+  mi_heap_visit_pages(heap, &_mi_heap_page_destroy, NULL, NULL);
+  mi_heap_reset_pages(heap);
+}
+
+void mi_heap_destroy(mi_heap_t* heap) {
+  mi_assert(heap != NULL);
+  mi_assert(mi_heap_is_initialized(heap));
+  mi_assert(heap->no_reclaim);
+  mi_assert_expensive(mi_heap_is_valid(heap));
+  if (heap==NULL || !mi_heap_is_initialized(heap)) return;
+  if (!heap->no_reclaim) {
+    // don't free in case it may contain reclaimed pages
+    mi_heap_delete(heap);
+  }
+  else {
+    // free all pages
+    _mi_heap_destroy_pages(heap);
+    mi_heap_free(heap);
+  }
+}
+
+
+
+/* -----------------------------------------------------------
+  Safe Heap delete
+----------------------------------------------------------- */
+
+// Transfer the pages from one heap to the other
+static void mi_heap_absorb(mi_heap_t* heap, mi_heap_t* from) {
+  mi_assert_internal(heap!=NULL);
+  if (from==NULL || from->page_count == 0) return;
+
+  // reduce the size of the delayed frees
+  _mi_heap_delayed_free(from);
+  
+  // transfer all pages by appending the queues; this will set a new heap field 
+  // so threads may do delayed frees in either heap for a while.
+  // note: appending waits for each page to not be in the `MI_DELAYED_FREEING` state
+  // so after this only the new heap will get delayed frees
+  for (size_t i = 0; i <= MI_BIN_FULL; i++) {
+    mi_page_queue_t* pq = &heap->pages[i];
+    mi_page_queue_t* append = &from->pages[i];
+    size_t pcount = _mi_page_queue_append(heap, pq, append);
+    heap->page_count += pcount;
+    from->page_count -= pcount;
+  }
+  mi_assert_internal(from->page_count == 0);
+
+  // and do outstanding delayed frees in the `from` heap  
+  // note: be careful here as the `heap` field in all those pages no longer point to `from`,
+  // turns out to be ok as `_mi_heap_delayed_free` only visits the list and calls a 
+  // the regular `_mi_free_delayed_block` which is safe.
+  _mi_heap_delayed_free(from);  
+  #if !defined(_MSC_VER) || (_MSC_VER > 1900) // somehow the following line gives an error in VS2015, issue #353
+  mi_assert_internal(mi_atomic_load_ptr_relaxed(mi_block_t,&from->thread_delayed_free) == NULL);
+  #endif
+
+  // and reset the `from` heap
+  mi_heap_reset_pages(from);  
+}
+
+// Safe delete a heap without freeing any still allocated blocks in that heap.
+void mi_heap_delete(mi_heap_t* heap)
+{
+  mi_assert(heap != NULL);
+  mi_assert(mi_heap_is_initialized(heap));
+  mi_assert_expensive(mi_heap_is_valid(heap));
+  if (heap==NULL || !mi_heap_is_initialized(heap)) return;
+
+  if (!mi_heap_is_backing(heap)) {
+    // tranfer still used pages to the backing heap
+    mi_heap_absorb(heap->tld->heap_backing, heap);
+  }
+  else {
+    // the backing heap abandons its pages
+    _mi_heap_collect_abandon(heap);
+  }
+  mi_assert_internal(heap->page_count==0);
+  mi_heap_free(heap);
+}
+
+mi_heap_t* mi_heap_set_default(mi_heap_t* heap) {
+  mi_assert(heap != NULL);
+  mi_assert(mi_heap_is_initialized(heap));
+  if (heap==NULL || !mi_heap_is_initialized(heap)) return NULL;
+  mi_assert_expensive(mi_heap_is_valid(heap));
+  mi_heap_t* old = mi_get_default_heap();
+  _mi_heap_set_default_direct(heap);
+  return old;
+}
+
+
+
+
+/* -----------------------------------------------------------
+  Analysis
+----------------------------------------------------------- */
+
+// static since it is not thread safe to access heaps from other threads.
+static mi_heap_t* mi_heap_of_block(const void* p) {
+  if (p == NULL) return NULL;
+  mi_segment_t* segment = _mi_ptr_segment(p);
+  bool valid = (_mi_ptr_cookie(segment) == segment->cookie);
+  mi_assert_internal(valid);
+  if (mi_unlikely(!valid)) return NULL;
+  return mi_page_heap(_mi_segment_page_of(segment,p));
+}
+
+bool mi_heap_contains_block(mi_heap_t* heap, const void* p) {
+  mi_assert(heap != NULL);
+  if (heap==NULL || !mi_heap_is_initialized(heap)) return false;
+  return (heap == mi_heap_of_block(p));
+}
+
+
+static bool mi_heap_page_check_owned(mi_heap_t* heap, mi_page_queue_t* pq, mi_page_t* page, void* p, void* vfound) {
+  MI_UNUSED(heap);
+  MI_UNUSED(pq);
+  bool* found = (bool*)vfound;
+  mi_segment_t* segment = _mi_page_segment(page);
+  void* start = _mi_page_start(segment, page, NULL);
+  void* end   = (uint8_t*)start + (page->capacity * mi_page_block_size(page));
+  *found = (p >= start && p < end);
+  return (!*found); // continue if not found
+}
+
+bool mi_heap_check_owned(mi_heap_t* heap, const void* p) {
+  mi_assert(heap != NULL);
+  if (heap==NULL || !mi_heap_is_initialized(heap)) return false;
+  if (((uintptr_t)p & (MI_INTPTR_SIZE - 1)) != 0) return false;  // only aligned pointers
+  bool found = false;
+  mi_heap_visit_pages(heap, &mi_heap_page_check_owned, (void*)p, &found);
+  return found;
+}
+
+bool mi_check_owned(const void* p) {
+  return mi_heap_check_owned(mi_get_default_heap(), p);
+}
+
+/* -----------------------------------------------------------
+  Visit all heap blocks and areas
+  Todo: enable visiting abandoned pages, and
+        enable visiting all blocks of all heaps across threads
+----------------------------------------------------------- */
+
+// Separate struct to keep `mi_page_t` out of the public interface
+typedef struct mi_heap_area_ex_s {
+  mi_heap_area_t area;
+  mi_page_t*     page;
+} mi_heap_area_ex_t;
+
+static bool mi_heap_area_visit_blocks(const mi_heap_area_ex_t* xarea, mi_block_visit_fun* visitor, void* arg) {
+  mi_assert(xarea != NULL);
+  if (xarea==NULL) return true;
+  const mi_heap_area_t* area = &xarea->area;
+  mi_page_t* page = xarea->page;
+  mi_assert(page != NULL);
+  if (page == NULL) return true;
+
+  _mi_page_free_collect(page,true);
+  mi_assert_internal(page->local_free == NULL);
+  if (page->used == 0) return true;
+
+  const size_t bsize = mi_page_block_size(page);
+  size_t   psize;
+  uint8_t* pstart = _mi_page_start(_mi_page_segment(page), page, &psize);
+
+  if (page->capacity == 1) {
+    // optimize page with one block
+    mi_assert_internal(page->used == 1 && page->free == NULL);
+    return visitor(mi_page_heap(page), area, pstart, bsize, arg);
+  }
+
+  // create a bitmap of free blocks.
+  #define MI_MAX_BLOCKS   (MI_SMALL_PAGE_SIZE / sizeof(void*))
+  uintptr_t free_map[MI_MAX_BLOCKS / sizeof(uintptr_t)];
+  memset(free_map, 0, sizeof(free_map));
+
+  size_t free_count = 0;
+  for (mi_block_t* block = page->free; block != NULL; block = mi_block_next(page,block)) {
+    free_count++;
+    mi_assert_internal((uint8_t*)block >= pstart && (uint8_t*)block < (pstart + psize));
+    size_t offset = (uint8_t*)block - pstart;
+    mi_assert_internal(offset % bsize == 0);
+    size_t blockidx = offset / bsize;  // Todo: avoid division?
+    mi_assert_internal( blockidx < MI_MAX_BLOCKS);
+    size_t bitidx = (blockidx / sizeof(uintptr_t));
+    size_t bit = blockidx - (bitidx * sizeof(uintptr_t));
+    free_map[bitidx] |= ((uintptr_t)1 << bit);
+  }
+  mi_assert_internal(page->capacity == (free_count + page->used));
+
+  // walk through all blocks skipping the free ones
+  size_t used_count = 0;
+  for (size_t i = 0; i < page->capacity; i++) {
+    size_t bitidx = (i / sizeof(uintptr_t));
+    size_t bit = i - (bitidx * sizeof(uintptr_t));
+    uintptr_t m = free_map[bitidx];
+    if (bit == 0 && m == UINTPTR_MAX) {
+      i += (sizeof(uintptr_t) - 1); // skip a run of free blocks
+    }
+    else if ((m & ((uintptr_t)1 << bit)) == 0) {
+      used_count++;
+      uint8_t* block = pstart + (i * bsize);
+      if (!visitor(mi_page_heap(page), area, block, bsize, arg)) return false;
+    }
+  }
+  mi_assert_internal(page->used == used_count);
+  return true;
+}
+
+typedef bool (mi_heap_area_visit_fun)(const mi_heap_t* heap, const mi_heap_area_ex_t* area, void* arg);
+
+
+static bool mi_heap_visit_areas_page(mi_heap_t* heap, mi_page_queue_t* pq, mi_page_t* page, void* vfun, void* arg) {
+  MI_UNUSED(heap);
+  MI_UNUSED(pq);
+  mi_heap_area_visit_fun* fun = (mi_heap_area_visit_fun*)vfun;
+  mi_heap_area_ex_t xarea;
+  const size_t bsize = mi_page_block_size(page);
+  xarea.page = page;
+  xarea.area.reserved = page->reserved * bsize;
+  xarea.area.committed = page->capacity * bsize;
+  xarea.area.blocks = _mi_page_start(_mi_page_segment(page), page, NULL);
+  xarea.area.used = page->used;
+  xarea.area.block_size = bsize;
+  return fun(heap, &xarea, arg);
+}
+
+// Visit all heap pages as areas
+static bool mi_heap_visit_areas(const mi_heap_t* heap, mi_heap_area_visit_fun* visitor, void* arg) {
+  if (visitor == NULL) return false;
+  return mi_heap_visit_pages((mi_heap_t*)heap, &mi_heap_visit_areas_page, (void*)(visitor), arg); // note: function pointer to void* :-{
+}
+
+// Just to pass arguments
+typedef struct mi_visit_blocks_args_s {
+  bool  visit_blocks;
+  mi_block_visit_fun* visitor;
+  void* arg;
+} mi_visit_blocks_args_t;
+
+static bool mi_heap_area_visitor(const mi_heap_t* heap, const mi_heap_area_ex_t* xarea, void* arg) {
+  mi_visit_blocks_args_t* args = (mi_visit_blocks_args_t*)arg;
+  if (!args->visitor(heap, &xarea->area, NULL, xarea->area.block_size, args->arg)) return false;
+  if (args->visit_blocks) {
+    return mi_heap_area_visit_blocks(xarea, args->visitor, args->arg);
+  }
+  else {
+    return true;
+  }
+}
+
+// Visit all blocks in a heap
+bool mi_heap_visit_blocks(const mi_heap_t* heap, bool visit_blocks, mi_block_visit_fun* visitor, void* arg) {
+  mi_visit_blocks_args_t args = { visit_blocks, visitor, arg };
+  return mi_heap_visit_areas(heap, &mi_heap_area_visitor, &args);
+}
diff --git a/Objects/mimalloc/init.c b/Objects/mimalloc/init.c
new file mode 100644
index 0000000000000..4ab465227d986
--- /dev/null
+++ b/Objects/mimalloc/init.c
@@ -0,0 +1,637 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2022, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+
+#include <string.h>  // memcpy, memset
+#include <stdlib.h>  // atexit
+
+// Empty page used to initialize the small free pages array
+const mi_page_t _mi_page_empty = {
+  0, false, false, false, false,
+  0,       // capacity
+  0,       // reserved capacity
+  { 0 },   // flags
+  false,   // is_zero
+  0,       // retire_expire
+  NULL,    // free
+  #if MI_ENCODE_FREELIST
+  { 0, 0 },
+  #endif
+  0,       // used
+  0,       // xblock_size
+  NULL,    // local_free
+  ATOMIC_VAR_INIT(0), // xthread_free
+  ATOMIC_VAR_INIT(0), // xheap
+  NULL, NULL
+  #if MI_INTPTR_SIZE==8
+  , { 0 }  // padding
+  #endif
+};
+
+#define MI_PAGE_EMPTY() ((mi_page_t*)&_mi_page_empty)
+
+#if (MI_PADDING>0) && (MI_INTPTR_SIZE >= 8)
+#define MI_SMALL_PAGES_EMPTY  { MI_INIT128(MI_PAGE_EMPTY), MI_PAGE_EMPTY(), MI_PAGE_EMPTY() }
+#elif (MI_PADDING>0)
+#define MI_SMALL_PAGES_EMPTY  { MI_INIT128(MI_PAGE_EMPTY), MI_PAGE_EMPTY(), MI_PAGE_EMPTY(), MI_PAGE_EMPTY() }
+#else
+#define MI_SMALL_PAGES_EMPTY  { MI_INIT128(MI_PAGE_EMPTY), MI_PAGE_EMPTY() }
+#endif
+
+
+// Empty page queues for every bin
+#define QNULL(sz)  { NULL, NULL, (sz)*sizeof(uintptr_t) }
+#define MI_PAGE_QUEUES_EMPTY \
+  { QNULL(1), \
+    QNULL(     1), QNULL(     2), QNULL(     3), QNULL(     4), QNULL(     5), QNULL(     6), QNULL(     7), QNULL(     8), /* 8 */ \
+    QNULL(    10), QNULL(    12), QNULL(    14), QNULL(    16), QNULL(    20), QNULL(    24), QNULL(    28), QNULL(    32), /* 16 */ \
+    QNULL(    40), QNULL(    48), QNULL(    56), QNULL(    64), QNULL(    80), QNULL(    96), QNULL(   112), QNULL(   128), /* 24 */ \
+    QNULL(   160), QNULL(   192), QNULL(   224), QNULL(   256), QNULL(   320), QNULL(   384), QNULL(   448), QNULL(   512), /* 32 */ \
+    QNULL(   640), QNULL(   768), QNULL(   896), QNULL(  1024), QNULL(  1280), QNULL(  1536), QNULL(  1792), QNULL(  2048), /* 40 */ \
+    QNULL(  2560), QNULL(  3072), QNULL(  3584), QNULL(  4096), QNULL(  5120), QNULL(  6144), QNULL(  7168), QNULL(  8192), /* 48 */ \
+    QNULL( 10240), QNULL( 12288), QNULL( 14336), QNULL( 16384), QNULL( 20480), QNULL( 24576), QNULL( 28672), QNULL( 32768), /* 56 */ \
+    QNULL( 40960), QNULL( 49152), QNULL( 57344), QNULL( 65536), QNULL( 81920), QNULL( 98304), QNULL(114688), QNULL(131072), /* 64 */ \
+    QNULL(163840), QNULL(196608), QNULL(229376), QNULL(262144), QNULL(327680), QNULL(393216), QNULL(458752), QNULL(524288), /* 72 */ \
+    QNULL(MI_MEDIUM_OBJ_WSIZE_MAX + 1  /* 655360, Huge queue */), \
+    QNULL(MI_MEDIUM_OBJ_WSIZE_MAX + 2) /* Full queue */ }
+
+#define MI_STAT_COUNT_NULL()  {0,0,0,0}
+
+// Empty statistics
+#if MI_STAT>1
+#define MI_STAT_COUNT_END_NULL()  , { MI_STAT_COUNT_NULL(), MI_INIT32(MI_STAT_COUNT_NULL) }
+#else
+#define MI_STAT_COUNT_END_NULL()
+#endif
+
+#define MI_STATS_NULL  \
+  MI_STAT_COUNT_NULL(), MI_STAT_COUNT_NULL(), \
+  MI_STAT_COUNT_NULL(), MI_STAT_COUNT_NULL(), \
+  MI_STAT_COUNT_NULL(), MI_STAT_COUNT_NULL(), \
+  MI_STAT_COUNT_NULL(), MI_STAT_COUNT_NULL(), \
+  MI_STAT_COUNT_NULL(), MI_STAT_COUNT_NULL(), \
+  MI_STAT_COUNT_NULL(), MI_STAT_COUNT_NULL(), \
+  MI_STAT_COUNT_NULL(), MI_STAT_COUNT_NULL(), \
+  { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 },     \
+  { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } \
+  MI_STAT_COUNT_END_NULL()
+
+
+// Empty slice span queues for every bin
+#define SQNULL(sz)  { NULL, NULL, sz }
+#define MI_SEGMENT_SPAN_QUEUES_EMPTY \
+  { SQNULL(1), \
+    SQNULL(     1), SQNULL(     2), SQNULL(     3), SQNULL(     4), SQNULL(     5), SQNULL(     6), SQNULL(     7), SQNULL(    10), /*  8 */ \
+    SQNULL(    12), SQNULL(    14), SQNULL(    16), SQNULL(    20), SQNULL(    24), SQNULL(    28), SQNULL(    32), SQNULL(    40), /* 16 */ \
+    SQNULL(    48), SQNULL(    56), SQNULL(    64), SQNULL(    80), SQNULL(    96), SQNULL(   112), SQNULL(   128), SQNULL(   160), /* 24 */ \
+    SQNULL(   192), SQNULL(   224), SQNULL(   256), SQNULL(   320), SQNULL(   384), SQNULL(   448), SQNULL(   512), SQNULL(   640), /* 32 */ \
+    SQNULL(   768), SQNULL(   896), SQNULL(  1024) /* 35 */ }
+
+
+// --------------------------------------------------------
+// Statically allocate an empty heap as the initial
+// thread local value for the default heap,
+// and statically allocate the backing heap for the main
+// thread so it can function without doing any allocation
+// itself (as accessing a thread local for the first time
+// may lead to allocation itself on some platforms)
+// --------------------------------------------------------
+
+mi_decl_cache_align const mi_heap_t _mi_heap_empty = {
+  NULL,
+  MI_SMALL_PAGES_EMPTY,
+  MI_PAGE_QUEUES_EMPTY,
+  ATOMIC_VAR_INIT(NULL),
+  0,                // tid
+  0,                // cookie
+  { 0, 0 },         // keys
+  { {0}, {0}, 0 },
+  0,                // page count
+  MI_BIN_FULL, 0,   // page retired min/max
+  NULL,             // next
+  false
+};
+
+#define tld_empty_stats  ((mi_stats_t*)((uint8_t*)&tld_empty + offsetof(mi_tld_t,stats)))
+#define tld_empty_os     ((mi_os_tld_t*)((uint8_t*)&tld_empty + offsetof(mi_tld_t,os)))
+
+mi_decl_cache_align static const mi_tld_t tld_empty = {
+  0,
+  false,
+  NULL, NULL,
+  { MI_SEGMENT_SPAN_QUEUES_EMPTY, 0, 0, 0, 0, 0, 0, NULL, tld_empty_stats, tld_empty_os }, // segments
+  { 0, tld_empty_stats }, // os
+  { MI_STATS_NULL }       // stats
+};
+
+// the thread-local default heap for allocation
+mi_decl_thread mi_heap_t* _mi_heap_default = (mi_heap_t*)&_mi_heap_empty;
+
+extern mi_heap_t _mi_heap_main;
+
+static mi_tld_t tld_main = {
+  0, false,
+  &_mi_heap_main, & _mi_heap_main,
+  { MI_SEGMENT_SPAN_QUEUES_EMPTY, 0, 0, 0, 0, 0, 0, NULL, &tld_main.stats, &tld_main.os }, // segments
+  { 0, &tld_main.stats },  // os
+  { MI_STATS_NULL }       // stats
+};
+
+mi_heap_t _mi_heap_main = {
+  &tld_main,
+  MI_SMALL_PAGES_EMPTY,
+  MI_PAGE_QUEUES_EMPTY,
+  ATOMIC_VAR_INIT(NULL),
+  0,                // thread id
+  0,                // initial cookie
+  { 0, 0 },         // the key of the main heap can be fixed (unlike page keys that need to be secure!)
+  { {0x846ca68b}, {0}, 0 },  // random
+  0,                // page count
+  MI_BIN_FULL, 0,   // page retired min/max
+  NULL,             // next heap
+  false             // can reclaim
+};
+
+bool _mi_process_is_initialized = false;  // set to `true` in `mi_process_init`.
+
+mi_stats_t _mi_stats_main = { MI_STATS_NULL };
+
+
+static void mi_heap_main_init(void) {
+  if (_mi_heap_main.cookie == 0) {
+    _mi_heap_main.thread_id = _mi_thread_id();
+    _mi_heap_main.cookie = _mi_os_random_weak((uintptr_t)&mi_heap_main_init);
+    _mi_random_init(&_mi_heap_main.random);
+    _mi_heap_main.keys[0] = _mi_heap_random_next(&_mi_heap_main);
+    _mi_heap_main.keys[1] = _mi_heap_random_next(&_mi_heap_main);
+  }
+}
+
+mi_heap_t* _mi_heap_main_get(void) {
+  mi_heap_main_init();
+  return &_mi_heap_main;
+}
+
+
+/* -----------------------------------------------------------
+  Initialization and freeing of the thread local heaps
+----------------------------------------------------------- */
+
+// note: in x64 in release build `sizeof(mi_thread_data_t)` is under 4KiB (= OS page size).
+typedef struct mi_thread_data_s {
+  mi_heap_t  heap;  // must come first due to cast in `_mi_heap_done`
+  mi_tld_t   tld;
+} mi_thread_data_t;
+
+// Initialize the thread local default heap, called from `mi_thread_init`
+static bool _mi_heap_init(void) {
+  if (mi_heap_is_initialized(mi_get_default_heap())) return true;
+  if (_mi_is_main_thread()) {
+    // mi_assert_internal(_mi_heap_main.thread_id != 0);  // can happen on freeBSD where alloc is called before any initialization
+    // the main heap is statically allocated
+    mi_heap_main_init();
+    _mi_heap_set_default_direct(&_mi_heap_main);
+    //mi_assert_internal(_mi_heap_default->tld->heap_backing == mi_get_default_heap());
+  }
+  else {
+    // use `_mi_os_alloc` to allocate directly from the OS
+    mi_thread_data_t* td = (mi_thread_data_t*)_mi_os_alloc(sizeof(mi_thread_data_t), &_mi_stats_main); // Todo: more efficient allocation?
+    if (td == NULL) {
+      // if this fails, try once more. (issue #257)
+      td = (mi_thread_data_t*)_mi_os_alloc(sizeof(mi_thread_data_t), &_mi_stats_main);
+      if (td == NULL) {
+        // really out of memory
+        _mi_error_message(ENOMEM, "unable to allocate thread local heap metadata (%zu bytes)\n", sizeof(mi_thread_data_t));
+        return false;
+      }
+    }
+    // OS allocated so already zero initialized
+    mi_tld_t*  tld = &td->tld;
+    mi_heap_t* heap = &td->heap;
+    _mi_memcpy_aligned(tld, &tld_empty, sizeof(*tld));
+    _mi_memcpy_aligned(heap, &_mi_heap_empty, sizeof(*heap));
+    heap->thread_id = _mi_thread_id();
+    _mi_random_init(&heap->random);
+    heap->cookie  = _mi_heap_random_next(heap) | 1;
+    heap->keys[0] = _mi_heap_random_next(heap);
+    heap->keys[1] = _mi_heap_random_next(heap);
+    heap->tld = tld;
+    tld->heap_backing = heap;
+    tld->heaps = heap;
+    tld->segments.stats = &tld->stats;
+    tld->segments.os = &tld->os;
+    tld->os.stats = &tld->stats;
+    _mi_heap_set_default_direct(heap);    
+  }
+  return false;
+}
+
+// Free the thread local default heap (called from `mi_thread_done`)
+static bool _mi_heap_done(mi_heap_t* heap) {
+  if (!mi_heap_is_initialized(heap)) return true;
+
+  // reset default heap
+  _mi_heap_set_default_direct(_mi_is_main_thread() ? &_mi_heap_main : (mi_heap_t*)&_mi_heap_empty);
+
+  // switch to backing heap
+  heap = heap->tld->heap_backing;
+  if (!mi_heap_is_initialized(heap)) return false;
+
+  // delete all non-backing heaps in this thread
+  mi_heap_t* curr = heap->tld->heaps;
+  while (curr != NULL) {
+    mi_heap_t* next = curr->next; // save `next` as `curr` will be freed
+    if (curr != heap) {
+      mi_assert_internal(!mi_heap_is_backing(curr));
+      mi_heap_delete(curr);
+    }
+    curr = next;
+  }
+  mi_assert_internal(heap->tld->heaps == heap && heap->next == NULL);
+  mi_assert_internal(mi_heap_is_backing(heap));
+
+  // collect if not the main thread
+  if (heap != &_mi_heap_main) {
+    _mi_heap_collect_abandon(heap);
+  }
+  
+  // merge stats
+  _mi_stats_done(&heap->tld->stats);  
+
+  // free if not the main thread
+  if (heap != &_mi_heap_main) {
+    // the following assertion does not always hold for huge segments as those are always treated
+    // as abondened: one may allocate it in one thread, but deallocate in another in which case
+    // the count can be too large or negative. todo: perhaps not count huge segments? see issue #363
+    // mi_assert_internal(heap->tld->segments.count == 0 || heap->thread_id != _mi_thread_id());
+    _mi_os_free(heap, sizeof(mi_thread_data_t), &_mi_stats_main);
+  }
+#if 0  
+  // never free the main thread even in debug mode; if a dll is linked statically with mimalloc,
+  // there may still be delete/free calls after the mi_fls_done is called. Issue #207
+  else {
+    _mi_heap_destroy_pages(heap);
+    mi_assert_internal(heap->tld->heap_backing == &_mi_heap_main);
+  }
+#endif
+  return false;
+}
+
+
+
+// --------------------------------------------------------
+// Try to run `mi_thread_done()` automatically so any memory
+// owned by the thread but not yet released can be abandoned
+// and re-owned by another thread.
+//
+// 1. windows dynamic library:
+//     call from DllMain on DLL_THREAD_DETACH
+// 2. windows static library:
+//     use `FlsAlloc` to call a destructor when the thread is done
+// 3. unix, pthreads:
+//     use a pthread key to call a destructor when a pthread is done
+//
+// In the last two cases we also need to call `mi_process_init`
+// to set up the thread local keys.
+// --------------------------------------------------------
+
+static void _mi_thread_done(mi_heap_t* default_heap);
+
+#if defined(_WIN32) && defined(MI_SHARED_LIB)
+  // nothing to do as it is done in DllMain
+#elif defined(_WIN32) && !defined(MI_SHARED_LIB)
+  // use thread local storage keys to detect thread ending
+  #include <windows.h>
+  #include <fibersapi.h>
+  #if (_WIN32_WINNT < 0x600)  // before Windows Vista 
+  WINBASEAPI DWORD WINAPI FlsAlloc( _In_opt_ PFLS_CALLBACK_FUNCTION lpCallback );
+  WINBASEAPI PVOID WINAPI FlsGetValue( _In_ DWORD dwFlsIndex );
+  WINBASEAPI BOOL  WINAPI FlsSetValue( _In_ DWORD dwFlsIndex, _In_opt_ PVOID lpFlsData );
+  WINBASEAPI BOOL  WINAPI FlsFree(_In_ DWORD dwFlsIndex);
+  #endif
+  static DWORD mi_fls_key = (DWORD)(-1);
+  static void NTAPI mi_fls_done(PVOID value) {
+    if (value!=NULL) _mi_thread_done((mi_heap_t*)value);
+  }
+#elif defined(MI_USE_PTHREADS)
+  // use pthread local storage keys to detect thread ending
+  // (and used with MI_TLS_PTHREADS for the default heap)
+  pthread_key_t _mi_heap_default_key = (pthread_key_t)(-1);
+  static void mi_pthread_done(void* value) {
+    if (value!=NULL) _mi_thread_done((mi_heap_t*)value);
+  }
+#elif defined(__wasi__)
+// no pthreads in the WebAssembly Standard Interface
+#else
+  #pragma message("define a way to call mi_thread_done when a thread is done")
+#endif
+
+// Set up handlers so `mi_thread_done` is called automatically
+static void mi_process_setup_auto_thread_done(void) {
+  static bool tls_initialized = false; // fine if it races
+  if (tls_initialized) return;
+  tls_initialized = true;
+  #if defined(_WIN32) && defined(MI_SHARED_LIB)
+    // nothing to do as it is done in DllMain
+  #elif defined(_WIN32) && !defined(MI_SHARED_LIB)
+    mi_fls_key = FlsAlloc(&mi_fls_done);
+  #elif defined(MI_USE_PTHREADS)
+    mi_assert_internal(_mi_heap_default_key == (pthread_key_t)(-1));
+    pthread_key_create(&_mi_heap_default_key, &mi_pthread_done);
+  #endif
+  _mi_heap_set_default_direct(&_mi_heap_main);
+}
+
+
+bool _mi_is_main_thread(void) {
+  return (_mi_heap_main.thread_id==0 || _mi_heap_main.thread_id == _mi_thread_id());
+}
+
+static _Atomic(size_t) thread_count = ATOMIC_VAR_INIT(1);
+
+size_t  _mi_current_thread_count(void) {
+  return mi_atomic_load_relaxed(&thread_count);
+}
+
+// This is called from the `mi_malloc_generic`
+void mi_thread_init(void) mi_attr_noexcept
+{
+  // ensure our process has started already
+  mi_process_init();
+  
+  // initialize the thread local default heap
+  // (this will call `_mi_heap_set_default_direct` and thus set the
+  //  fiber/pthread key to a non-zero value, ensuring `_mi_thread_done` is called)
+  if (_mi_heap_init()) return;  // returns true if already initialized
+
+  _mi_stat_increase(&_mi_stats_main.threads, 1);
+  mi_atomic_increment_relaxed(&thread_count);
+  //_mi_verbose_message("thread init: 0x%zx\n", _mi_thread_id());
+}
+
+void mi_thread_done(void) mi_attr_noexcept {
+  _mi_thread_done(mi_get_default_heap());
+}
+
+static void _mi_thread_done(mi_heap_t* heap) {
+  mi_atomic_decrement_relaxed(&thread_count);
+  _mi_stat_decrease(&_mi_stats_main.threads, 1);
+
+  // check thread-id as on Windows shutdown with FLS the main (exit) thread may call this on thread-local heaps...
+  if (heap->thread_id != _mi_thread_id()) return;
+  
+  // abandon the thread local heap
+  if (_mi_heap_done(heap)) return;  // returns true if already ran
+}
+
+void _mi_heap_set_default_direct(mi_heap_t* heap)  {
+  mi_assert_internal(heap != NULL);
+  #if defined(MI_TLS_SLOT)
+  mi_tls_slot_set(MI_TLS_SLOT,heap);
+  #elif defined(MI_TLS_PTHREAD_SLOT_OFS)
+  *mi_tls_pthread_heap_slot() = heap;
+  #elif defined(MI_TLS_PTHREAD)
+  // we use _mi_heap_default_key
+  #else
+  _mi_heap_default = heap;
+  #endif
+
+  // ensure the default heap is passed to `_mi_thread_done`
+  // setting to a non-NULL value also ensures `mi_thread_done` is called.
+  #if defined(_WIN32) && defined(MI_SHARED_LIB)
+    // nothing to do as it is done in DllMain
+  #elif defined(_WIN32) && !defined(MI_SHARED_LIB)
+    mi_assert_internal(mi_fls_key != 0);
+    FlsSetValue(mi_fls_key, heap);
+  #elif defined(MI_USE_PTHREADS)
+  if (_mi_heap_default_key != (pthread_key_t)(-1)) {  // can happen during recursive invocation on freeBSD
+    pthread_setspecific(_mi_heap_default_key, heap);
+  }
+  #endif
+}
+
+
+// --------------------------------------------------------
+// Run functions on process init/done, and thread init/done
+// --------------------------------------------------------
+static void mi_process_done(void);
+
+static bool os_preloading = true;    // true until this module is initialized
+static bool mi_redirected = false;   // true if malloc redirects to mi_malloc
+
+// Returns true if this module has not been initialized; Don't use C runtime routines until it returns false.
+bool _mi_preloading(void) {
+  return os_preloading;
+}
+
+bool mi_is_redirected(void) mi_attr_noexcept {
+  return mi_redirected;
+}
+
+// Communicate with the redirection module on Windows
+#if defined(_WIN32) && defined(MI_SHARED_LIB)
+#ifdef __cplusplus
+extern "C" {
+#endif
+mi_decl_export void _mi_redirect_entry(DWORD reason) {
+  // called on redirection; careful as this may be called before DllMain
+  if (reason == DLL_PROCESS_ATTACH) {
+    mi_redirected = true;
+  }
+  else if (reason == DLL_PROCESS_DETACH) {
+    mi_redirected = false;
+  }
+  else if (reason == DLL_THREAD_DETACH) {
+    mi_thread_done();
+  }
+}
+__declspec(dllimport) bool mi_allocator_init(const char** message);
+__declspec(dllimport) void mi_allocator_done(void);
+#ifdef __cplusplus
+}
+#endif
+#else
+static bool mi_allocator_init(const char** message) {
+  if (message != NULL) *message = NULL;
+  return true;
+}
+static void mi_allocator_done(void) {
+  // nothing to do
+}
+#endif
+
+// Called once by the process loader
+static void mi_process_load(void) {
+  mi_heap_main_init();
+  #if defined(MI_TLS_RECURSE_GUARD)
+  volatile mi_heap_t* dummy = _mi_heap_default; // access TLS to allocate it before setting tls_initialized to true;
+  MI_UNUSED(dummy);
+  #endif
+  os_preloading = false;
+  #if !(defined(_WIN32) && defined(MI_SHARED_LIB))  // use Dll process detach (see below) instead of atexit (issue #521)
+  atexit(&mi_process_done);  
+  #endif
+  _mi_options_init();
+  mi_process_init();
+  //mi_stats_reset();-
+  if (mi_redirected) _mi_verbose_message("malloc is redirected.\n");
+
+  // show message from the redirector (if present)
+  const char* msg = NULL;
+  mi_allocator_init(&msg);
+  if (msg != NULL && (mi_option_is_enabled(mi_option_verbose) || mi_option_is_enabled(mi_option_show_errors))) {
+    _mi_fputs(NULL,NULL,NULL,msg);
+  }
+}
+
+#if defined(_WIN32) && (defined(_M_IX86) || defined(_M_X64))
+#include <intrin.h>
+mi_decl_cache_align bool _mi_cpu_has_fsrm = false;
+
+static void mi_detect_cpu_features(void) {
+  // FSRM for fast rep movsb support (AMD Zen3+ (~2020) or Intel Ice Lake+ (~2017))
+  int32_t cpu_info[4];
+  __cpuid(cpu_info, 7);
+  _mi_cpu_has_fsrm = ((cpu_info[3] & (1 << 4)) != 0); // bit 4 of EDX : see <https ://en.wikipedia.org/wiki/CPUID#EAX=7,_ECX=0:_Extended_Features>
+}
+#else
+static void mi_detect_cpu_features(void) {
+  // nothing
+}
+#endif
+
+// Initialize the process; called by thread_init or the process loader
+void mi_process_init(void) mi_attr_noexcept {
+  // ensure we are called once
+  if (_mi_process_is_initialized) return;
+  _mi_verbose_message("process init: 0x%zx\n", _mi_thread_id());
+  _mi_process_is_initialized = true;
+  mi_process_setup_auto_thread_done();
+
+  
+  mi_detect_cpu_features();
+  _mi_os_init();
+  mi_heap_main_init();
+  #if (MI_DEBUG)
+  _mi_verbose_message("debug level : %d\n", MI_DEBUG);
+  #endif
+  _mi_verbose_message("secure level: %d\n", MI_SECURE);
+  mi_thread_init();
+
+  #if defined(_WIN32) && !defined(MI_SHARED_LIB)
+  // When building as a static lib the FLS cleanup happens to early for the main thread.
+  // To avoid this, set the FLS value for the main thread to NULL so the fls cleanup
+  // will not call _mi_thread_done on the (still executing) main thread. See issue #508.
+  FlsSetValue(mi_fls_key, NULL);
+  #endif
+
+  mi_stats_reset();  // only call stat reset *after* thread init (or the heap tld == NULL)
+
+  if (mi_option_is_enabled(mi_option_reserve_huge_os_pages)) {
+    size_t pages = mi_option_get(mi_option_reserve_huge_os_pages);
+    long reserve_at = mi_option_get(mi_option_reserve_huge_os_pages_at);
+    if (reserve_at != -1) {
+      mi_reserve_huge_os_pages_at(pages, reserve_at, pages*500);
+    } else {
+      mi_reserve_huge_os_pages_interleave(pages, 0, pages*500);
+    }
+  } 
+  if (mi_option_is_enabled(mi_option_reserve_os_memory)) {
+    long ksize = mi_option_get(mi_option_reserve_os_memory);
+    if (ksize > 0) {
+      mi_reserve_os_memory((size_t)ksize*MI_KiB, true /* commit? */, true /* allow large pages? */);
+    }
+  }
+}
+
+// Called when the process is done (through `at_exit`)
+static void mi_process_done(void) {
+  // only shutdown if we were initialized
+  if (!_mi_process_is_initialized) return;
+  // ensure we are called once
+  static bool process_done = false;
+  if (process_done) return;
+  process_done = true;
+
+  #if defined(_WIN32) && !defined(MI_SHARED_LIB)
+  FlsFree(mi_fls_key);  // call thread-done on all threads (except the main thread) to prevent dangling callback pointer if statically linked with a DLL; Issue #208
+  #endif
+  
+  #ifndef MI_SKIP_COLLECT_ON_EXIT
+    #if (MI_DEBUG != 0) || !defined(MI_SHARED_LIB)  
+    // free all memory if possible on process exit. This is not needed for a stand-alone process
+    // but should be done if mimalloc is statically linked into another shared library which
+    // is repeatedly loaded/unloaded, see issue #281.
+    mi_collect(true /* force */ );
+    #endif
+  #endif
+
+  if (mi_option_is_enabled(mi_option_show_stats) || mi_option_is_enabled(mi_option_verbose)) {
+    mi_stats_print(NULL);
+  }
+  mi_allocator_done();  
+  _mi_verbose_message("process done: 0x%zx\n", _mi_heap_main.thread_id);
+  os_preloading = true; // don't call the C runtime anymore
+}
+
+
+
+#if defined(_WIN32) && defined(MI_SHARED_LIB)
+  // Windows DLL: easy to hook into process_init and thread_done
+  __declspec(dllexport) BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved) {
+    MI_UNUSED(reserved);
+    MI_UNUSED(inst);
+    if (reason==DLL_PROCESS_ATTACH) {
+      mi_process_load();
+    }
+    else if (reason==DLL_PROCESS_DETACH) {
+      mi_process_done();
+    }
+    else if (reason==DLL_THREAD_DETACH) {
+      if (!mi_is_redirected()) {
+        mi_thread_done();
+      }
+    }    
+    return TRUE;
+  }
+
+#elif defined(_MSC_VER)
+  // MSVC: use data section magic for static libraries
+  // See <https://www.codeguru.com/cpp/misc/misc/applicationcontrol/article.php/c6945/Running-Code-Before-and-After-Main.htm>
+  static int _mi_process_init(void) {
+    mi_process_load();
+    return 0;
+  }
+  typedef int(*_mi_crt_callback_t)(void);
+  #if defined(_M_X64) || defined(_M_ARM64)
+    __pragma(comment(linker, "/include:" "_mi_msvc_initu"))
+    #pragma section(".CRT$XIU", long, read)
+  #else
+    __pragma(comment(linker, "/include:" "__mi_msvc_initu"))
+  #endif
+  #pragma data_seg(".CRT$XIU")
+  mi_decl_externc _mi_crt_callback_t _mi_msvc_initu[] = { &_mi_process_init };
+  #pragma data_seg()
+
+#elif defined(__cplusplus)
+  // C++: use static initialization to detect process start
+  static bool _mi_process_init(void) {
+    mi_process_load();
+    return (_mi_heap_main.thread_id != 0);
+  }
+  static bool mi_initialized = _mi_process_init();
+
+#elif defined(__GNUC__) || defined(__clang__)
+  // GCC,Clang: use the constructor attribute
+  static void __attribute__((constructor)) _mi_process_init(void) {
+    mi_process_load();
+  }
+
+#else
+#pragma message("define a way to call mi_process_load on your platform")
+#endif
diff --git a/Objects/mimalloc/options.c b/Objects/mimalloc/options.c
new file mode 100644
index 0000000000000..d2e6121899136
--- /dev/null
+++ b/Objects/mimalloc/options.c
@@ -0,0 +1,591 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2021, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+#include "mimalloc-atomic.h"
+
+#include <stdio.h>
+#include <stdlib.h> // strtol
+#include <string.h> // strncpy, strncat, strlen, strstr
+#include <ctype.h>  // toupper
+#include <stdarg.h>
+
+#ifdef _MSC_VER
+#pragma warning(disable:4996)   // strncpy, strncat
+#endif
+
+
+static size_t mi_max_error_count   = 16; // stop outputting errors after this
+static size_t mi_max_warning_count = 16; // stop outputting warnings after this
+
+static void mi_add_stderr_output(void);
+
+int mi_version(void) mi_attr_noexcept {
+  return MI_MALLOC_VERSION;
+}
+
+#ifdef _WIN32
+#include <conio.h>
+#endif
+
+// --------------------------------------------------------
+// Options
+// These can be accessed by multiple threads and may be
+// concurrently initialized, but an initializing data race
+// is ok since they resolve to the same value.
+// --------------------------------------------------------
+typedef enum mi_init_e {
+  UNINIT,       // not yet initialized
+  DEFAULTED,    // not found in the environment, use default value
+  INITIALIZED   // found in environment or set explicitly
+} mi_init_t;
+
+typedef struct mi_option_desc_s {
+  long        value;  // the value
+  mi_init_t   init;   // is it initialized yet? (from the environment)
+  mi_option_t option; // for debugging: the option index should match the option
+  const char* name;   // option name without `mimalloc_` prefix
+  const char* legacy_name; // potential legacy v1.x option name
+} mi_option_desc_t;
+
+#define MI_OPTION(opt)                  mi_option_##opt, #opt, NULL
+#define MI_OPTION_LEGACY(opt,legacy)    mi_option_##opt, #opt, #legacy
+
+static mi_option_desc_t options[_mi_option_last] =
+{
+  // stable options
+  #if MI_DEBUG || defined(MI_SHOW_ERRORS)
+  { 1, UNINIT, MI_OPTION(show_errors) },
+  #else
+  { 0, UNINIT, MI_OPTION(show_errors) },
+  #endif
+  { 0, UNINIT, MI_OPTION(show_stats) },
+  { 0, UNINIT, MI_OPTION(verbose) },
+
+  // Some of the following options are experimental and not all combinations are valid. Use with care.
+  { 1, UNINIT, MI_OPTION(eager_commit) },        // commit per segment directly (8MiB)  (but see also `eager_commit_delay`)
+  { 0, UNINIT, MI_OPTION(deprecated_eager_region_commit) },
+  { 0, UNINIT, MI_OPTION(deprecated_reset_decommits) },
+  { 0, UNINIT, MI_OPTION(large_os_pages) },      // use large OS pages, use only with eager commit to prevent fragmentation of VMA's
+  { 0, UNINIT, MI_OPTION(reserve_huge_os_pages) },  // per 1GiB huge pages
+  { -1, UNINIT, MI_OPTION(reserve_huge_os_pages_at) }, // reserve huge pages at node N
+  { 0, UNINIT, MI_OPTION(reserve_os_memory)     },
+  { 0, UNINIT, MI_OPTION(segment_cache) },       // cache N segments per thread
+  { 0, UNINIT, MI_OPTION(page_reset) },          // reset page memory on free
+  { 0, UNINIT, MI_OPTION_LEGACY(abandoned_page_decommit, abandoned_page_reset) },// decommit free page memory when a thread terminates  
+  { 0, UNINIT, MI_OPTION(deprecated_segment_reset) },
+  #if defined(__NetBSD__)
+  { 0, UNINIT, MI_OPTION(eager_commit_delay) },  // the first N segments per thread are not eagerly committed
+  #elif defined(_WIN32)
+  { 4, UNINIT, MI_OPTION(eager_commit_delay) },  // the first N segments per thread are not eagerly committed (but per page in the segment on demand)
+  #else
+  { 1, UNINIT, MI_OPTION(eager_commit_delay) },  // the first N segments per thread are not eagerly committed (but per page in the segment on demand)
+  #endif
+  { 25,   UNINIT, MI_OPTION_LEGACY(decommit_delay, reset_delay) }, // page decommit delay in milli-seconds
+  { 0,    UNINIT, MI_OPTION(use_numa_nodes) },    // 0 = use available numa nodes, otherwise use at most N nodes. 
+  { 0,    UNINIT, MI_OPTION(limit_os_alloc) },    // 1 = do not use OS memory for allocation (but only reserved arenas)
+  { 100,  UNINIT, MI_OPTION(os_tag) },            // only apple specific for now but might serve more or less related purpose
+  { 16,   UNINIT, MI_OPTION(max_errors) },        // maximum errors that are output
+  { 16,   UNINIT, MI_OPTION(max_warnings) },      // maximum warnings that are output
+  { 1,    UNINIT, MI_OPTION(allow_decommit) },    // decommit slices when no longer used (after decommit_delay milli-seconds)
+  { 500,  UNINIT, MI_OPTION(segment_decommit_delay) }, // decommit delay in milli-seconds for freed segments
+  { 2,    UNINIT, MI_OPTION(decommit_extend_delay) }  
+};
+
+static void mi_option_init(mi_option_desc_t* desc);
+
+void _mi_options_init(void) {
+  // called on process load; should not be called before the CRT is initialized!
+  // (e.g. do not call this from process_init as that may run before CRT initialization)
+  mi_add_stderr_output(); // now it safe to use stderr for output
+  for(int i = 0; i < _mi_option_last; i++ ) {
+    mi_option_t option = (mi_option_t)i;
+    long l = mi_option_get(option); MI_UNUSED(l); // initialize
+    if (option != mi_option_verbose) {
+      mi_option_desc_t* desc = &options[option];
+      _mi_verbose_message("option '%s': %ld\n", desc->name, desc->value);
+    }
+  }
+  mi_max_error_count = mi_option_get(mi_option_max_errors);
+  mi_max_warning_count = mi_option_get(mi_option_max_warnings);
+}
+
+mi_decl_nodiscard long mi_option_get(mi_option_t option) {
+  mi_assert(option >= 0 && option < _mi_option_last);
+  mi_option_desc_t* desc = &options[option];
+  mi_assert(desc->option == option);  // index should match the option
+  if (mi_unlikely(desc->init == UNINIT)) {
+    mi_option_init(desc);
+  }
+  return desc->value;
+}
+
+void mi_option_set(mi_option_t option, long value) {
+  mi_assert(option >= 0 && option < _mi_option_last);
+  mi_option_desc_t* desc = &options[option];
+  mi_assert(desc->option == option);  // index should match the option
+  desc->value = value;
+  desc->init = INITIALIZED;
+}
+
+void mi_option_set_default(mi_option_t option, long value) {
+  mi_assert(option >= 0 && option < _mi_option_last);
+  mi_option_desc_t* desc = &options[option];
+  if (desc->init != INITIALIZED) {
+    desc->value = value;
+  }
+}
+
+mi_decl_nodiscard bool mi_option_is_enabled(mi_option_t option) {
+  return (mi_option_get(option) != 0);
+}
+
+void mi_option_set_enabled(mi_option_t option, bool enable) {
+  mi_option_set(option, (enable ? 1 : 0));
+}
+
+void mi_option_set_enabled_default(mi_option_t option, bool enable) {
+  mi_option_set_default(option, (enable ? 1 : 0));
+}
+
+void mi_option_enable(mi_option_t option) {
+  mi_option_set_enabled(option,true);
+}
+
+void mi_option_disable(mi_option_t option) {
+  mi_option_set_enabled(option,false);
+}
+
+
+static void mi_out_stderr(const char* msg, void* arg) {
+  MI_UNUSED(arg);
+  #ifdef _WIN32
+  // on windows with redirection, the C runtime cannot handle locale dependent output
+  // after the main thread closes so we use direct console output.
+  if (!_mi_preloading()) { _cputs(msg); }
+  #else
+  fputs(msg, stderr);
+  #endif
+}
+
+// Since an output function can be registered earliest in the `main`
+// function we also buffer output that happens earlier. When
+// an output function is registered it is called immediately with
+// the output up to that point.
+#ifndef MI_MAX_DELAY_OUTPUT
+#define MI_MAX_DELAY_OUTPUT ((size_t)(32*1024))
+#endif
+static char out_buf[MI_MAX_DELAY_OUTPUT+1];
+static _Atomic(size_t) out_len;
+
+static void mi_out_buf(const char* msg, void* arg) {
+  MI_UNUSED(arg);
+  if (msg==NULL) return;
+  if (mi_atomic_load_relaxed(&out_len)>=MI_MAX_DELAY_OUTPUT) return;
+  size_t n = strlen(msg);
+  if (n==0) return;
+  // claim space
+  size_t start = mi_atomic_add_acq_rel(&out_len, n);
+  if (start >= MI_MAX_DELAY_OUTPUT) return;
+  // check bound
+  if (start+n >= MI_MAX_DELAY_OUTPUT) {
+    n = MI_MAX_DELAY_OUTPUT-start-1;
+  }
+  _mi_memcpy(&out_buf[start], msg, n);
+}
+
+static void mi_out_buf_flush(mi_output_fun* out, bool no_more_buf, void* arg) {
+  if (out==NULL) return;
+  // claim (if `no_more_buf == true`, no more output will be added after this point)
+  size_t count = mi_atomic_add_acq_rel(&out_len, (no_more_buf ? MI_MAX_DELAY_OUTPUT : 1));
+  // and output the current contents
+  if (count>MI_MAX_DELAY_OUTPUT) count = MI_MAX_DELAY_OUTPUT;
+  out_buf[count] = 0;
+  out(out_buf,arg);
+  if (!no_more_buf) {
+    out_buf[count] = '\n'; // if continue with the buffer, insert a newline
+  }
+}
+
+
+// Once this module is loaded, switch to this routine
+// which outputs to stderr and the delayed output buffer.
+static void mi_out_buf_stderr(const char* msg, void* arg) {
+  mi_out_stderr(msg,arg);
+  mi_out_buf(msg,arg);
+}
+
+
+
+// --------------------------------------------------------
+// Default output handler
+// --------------------------------------------------------
+
+// Should be atomic but gives errors on many platforms as generally we cannot cast a function pointer to a uintptr_t.
+// For now, don't register output from multiple threads.
+static mi_output_fun* volatile mi_out_default; // = NULL
+static _Atomic(void*) mi_out_arg; // = NULL
+
+static mi_output_fun* mi_out_get_default(void** parg) {
+  if (parg != NULL) { *parg = mi_atomic_load_ptr_acquire(void,&mi_out_arg); }
+  mi_output_fun* out = mi_out_default;
+  return (out == NULL ? &mi_out_buf : out);
+}
+
+void mi_register_output(mi_output_fun* out, void* arg) mi_attr_noexcept {
+  mi_out_default = (out == NULL ? &mi_out_stderr : out); // stop using the delayed output buffer
+  mi_atomic_store_ptr_release(void,&mi_out_arg, arg);
+  if (out!=NULL) mi_out_buf_flush(out,true,arg);         // output all the delayed output now
+}
+
+// add stderr to the delayed output after the module is loaded
+static void mi_add_stderr_output() {
+  mi_assert_internal(mi_out_default == NULL);
+  mi_out_buf_flush(&mi_out_stderr, false, NULL); // flush current contents to stderr
+  mi_out_default = &mi_out_buf_stderr;           // and add stderr to the delayed output
+}
+
+// --------------------------------------------------------
+// Messages, all end up calling `_mi_fputs`.
+// --------------------------------------------------------
+static _Atomic(size_t) error_count;   // = 0;  // when >= max_error_count stop emitting errors
+static _Atomic(size_t) warning_count; // = 0;  // when >= max_warning_count stop emitting warnings
+
+// When overriding malloc, we may recurse into mi_vfprintf if an allocation
+// inside the C runtime causes another message.
+// In some cases (like on macOS) the loader already allocates which
+// calls into mimalloc; if we then access thread locals (like `recurse`)
+// this may crash as the access may call _tlv_bootstrap that tries to 
+// (recursively) invoke malloc again to allocate space for the thread local
+// variables on demand. This is why we use a _mi_preloading test on such
+// platforms. However, C code generator may move the initial thread local address
+// load before the `if` and we therefore split it out in a separate funcion.
+static mi_decl_thread bool recurse = false;
+
+static mi_decl_noinline bool mi_recurse_enter_prim(void) {
+  if (recurse) return false;
+  recurse = true;
+  return true;
+}
+
+static mi_decl_noinline void mi_recurse_exit_prim(void) {
+  recurse = false;
+}
+
+static bool mi_recurse_enter(void) {
+  #if defined(__APPLE__) || defined(MI_TLS_RECURSE_GUARD)
+  if (_mi_preloading()) return true;
+  #endif
+  return mi_recurse_enter_prim();
+}
+
+static void mi_recurse_exit(void) {
+  #if defined(__APPLE__) || defined(MI_TLS_RECURSE_GUARD)
+  if (_mi_preloading()) return;
+  #endif
+  mi_recurse_exit_prim();
+}
+
+void _mi_fputs(mi_output_fun* out, void* arg, const char* prefix, const char* message) {
+  if (out==NULL || (FILE*)out==stdout || (FILE*)out==stderr) { // TODO: use mi_out_stderr for stderr?
+    if (!mi_recurse_enter()) return;
+    out = mi_out_get_default(&arg);
+    if (prefix != NULL) out(prefix, arg);
+    out(message, arg);
+    mi_recurse_exit();
+  }
+  else {
+    if (prefix != NULL) out(prefix, arg);
+    out(message, arg);
+  }
+}
+
+// Define our own limited `fprintf` that avoids memory allocation.
+// We do this using `snprintf` with a limited buffer.
+static void mi_vfprintf( mi_output_fun* out, void* arg, const char* prefix, const char* fmt, va_list args ) {
+  char buf[512];
+  if (fmt==NULL) return;
+  if (!mi_recurse_enter()) return;
+  vsnprintf(buf,sizeof(buf)-1,fmt,args);
+  mi_recurse_exit();
+  _mi_fputs(out,arg,prefix,buf);
+}
+
+void _mi_fprintf( mi_output_fun* out, void* arg, const char* fmt, ... ) {
+  va_list args;
+  va_start(args,fmt);
+  mi_vfprintf(out,arg,NULL,fmt,args);
+  va_end(args);
+}
+
+void _mi_trace_message(const char* fmt, ...) {
+  if (mi_option_get(mi_option_verbose) <= 1) return;  // only with verbose level 2 or higher
+  va_list args;
+  va_start(args, fmt);
+  mi_vfprintf(NULL, NULL, "mimalloc: ", fmt, args);
+  va_end(args);
+}
+
+void _mi_verbose_message(const char* fmt, ...) {
+  if (!mi_option_is_enabled(mi_option_verbose)) return;
+  va_list args;
+  va_start(args,fmt);
+  mi_vfprintf(NULL, NULL, "mimalloc: ", fmt, args);
+  va_end(args);
+}
+
+static void mi_show_error_message(const char* fmt, va_list args) {
+  if (!mi_option_is_enabled(mi_option_show_errors) && !mi_option_is_enabled(mi_option_verbose)) return;
+  if (mi_atomic_increment_acq_rel(&error_count) > mi_max_error_count) return;
+  mi_vfprintf(NULL, NULL, "mimalloc: error: ", fmt, args);
+}
+
+void _mi_warning_message(const char* fmt, ...) {
+  if (!mi_option_is_enabled(mi_option_show_errors) && !mi_option_is_enabled(mi_option_verbose)) return;
+  if (mi_atomic_increment_acq_rel(&warning_count) > mi_max_warning_count) return;
+  va_list args;
+  va_start(args,fmt);
+  mi_vfprintf(NULL, NULL, "mimalloc: warning: ", fmt, args);
+  va_end(args);
+}
+
+
+#if MI_DEBUG
+void _mi_assert_fail(const char* assertion, const char* fname, unsigned line, const char* func ) {
+  _mi_fprintf(NULL, NULL, "mimalloc: assertion failed: at \"%s\":%u, %s\n  assertion: \"%s\"\n", fname, line, (func==NULL?"":func), assertion);
+  abort();
+}
+#endif
+
+// --------------------------------------------------------
+// Errors
+// --------------------------------------------------------
+
+static mi_error_fun* volatile  mi_error_handler; // = NULL
+static _Atomic(void*) mi_error_arg;     // = NULL
+
+static void mi_error_default(int err) {
+  MI_UNUSED(err);
+#if (MI_DEBUG>0) 
+  if (err==EFAULT) {
+    #ifdef _MSC_VER
+    __debugbreak();
+    #endif
+    abort();
+  }
+#endif
+#if (MI_SECURE>0)
+  if (err==EFAULT) {  // abort on serious errors in secure mode (corrupted meta-data)
+    abort();
+  }
+#endif
+#if defined(MI_XMALLOC)
+  if (err==ENOMEM || err==EOVERFLOW) { // abort on memory allocation fails in xmalloc mode
+    abort();
+  }
+#endif
+}
+
+void mi_register_error(mi_error_fun* fun, void* arg) {
+  mi_error_handler = fun;  // can be NULL
+  mi_atomic_store_ptr_release(void,&mi_error_arg, arg);
+}
+
+void _mi_error_message(int err, const char* fmt, ...) {
+  // show detailed error message
+  va_list args;
+  va_start(args, fmt);
+  mi_show_error_message(fmt, args);
+  va_end(args);
+  // and call the error handler which may abort (or return normally)
+  if (mi_error_handler != NULL) {
+    mi_error_handler(err, mi_atomic_load_ptr_acquire(void,&mi_error_arg));
+  }
+  else {
+    mi_error_default(err);
+  }
+}
+
+// --------------------------------------------------------
+// Initialize options by checking the environment
+// --------------------------------------------------------
+
+static void mi_strlcpy(char* dest, const char* src, size_t dest_size) {
+  if (dest==NULL || src==NULL || dest_size == 0) return;
+  // copy until end of src, or when dest is (almost) full
+  while (*src != 0 && dest_size > 1) {
+    *dest++ = *src++;
+    dest_size--;
+  }
+  // always zero terminate
+  *dest = 0;
+}
+
+static void mi_strlcat(char* dest, const char* src, size_t dest_size) {
+  if (dest==NULL || src==NULL || dest_size == 0) return;
+  // find end of string in the dest buffer
+  while (*dest != 0 && dest_size > 1) {
+    dest++;
+    dest_size--;
+  }
+  // and catenate
+  mi_strlcpy(dest, src, dest_size);
+}
+
+#ifdef MI_NO_GETENV
+static bool mi_getenv(const char* name, char* result, size_t result_size) {
+  MI_UNUSED(name);
+  MI_UNUSED(result);
+  MI_UNUSED(result_size);
+  return false;
+}
+#else
+static inline int mi_strnicmp(const char* s, const char* t, size_t n) {
+  if (n==0) return 0;
+  for (; *s != 0 && *t != 0 && n > 0; s++, t++, n--) {
+    if (toupper(*s) != toupper(*t)) break;
+  }
+  return (n==0 ? 0 : *s - *t);
+}
+#if defined _WIN32
+// On Windows use GetEnvironmentVariable instead of getenv to work
+// reliably even when this is invoked before the C runtime is initialized.
+// i.e. when `_mi_preloading() == true`.
+// Note: on windows, environment names are not case sensitive.
+#include <windows.h>
+static bool mi_getenv(const char* name, char* result, size_t result_size) {
+  result[0] = 0;
+  size_t len = GetEnvironmentVariableA(name, result, (DWORD)result_size);
+  return (len > 0 && len < result_size);
+}
+#elif !defined(MI_USE_ENVIRON) || (MI_USE_ENVIRON!=0)
+// On Posix systemsr use `environ` to acces environment variables 
+// even before the C runtime is initialized.
+#if defined(__APPLE__) && defined(__has_include) && __has_include(<crt_externs.h>)
+#include <crt_externs.h>
+static char** mi_get_environ(void) {
+  return (*_NSGetEnviron());
+}
+#else 
+extern char** environ;
+static char** mi_get_environ(void) {
+  return environ;
+}
+#endif
+static bool mi_getenv(const char* name, char* result, size_t result_size) {
+  if (name==NULL) return false;  
+  const size_t len = strlen(name);
+  if (len == 0) return false;  
+  char** env = mi_get_environ();
+  if (env == NULL) return false;
+  // compare up to 256 entries
+  for (int i = 0; i < 256 && env[i] != NULL; i++) {
+    const char* s = env[i];
+    if (mi_strnicmp(name, s, len) == 0 && s[len] == '=') { // case insensitive
+      // found it
+      mi_strlcpy(result, s + len + 1, result_size);
+      return true;
+    }
+  }
+  return false;
+}
+#else  
+// fallback: use standard C `getenv` but this cannot be used while initializing the C runtime
+static bool mi_getenv(const char* name, char* result, size_t result_size) {
+  // cannot call getenv() when still initializing the C runtime.
+  if (_mi_preloading()) return false;
+  const char* s = getenv(name);
+  if (s == NULL) {
+    // we check the upper case name too.
+    char buf[64+1];
+    size_t len = strlen(name);
+    if (len >= sizeof(buf)) len = sizeof(buf) - 1;
+    for (size_t i = 0; i < len; i++) {
+      buf[i] = toupper(name[i]);
+    }
+    buf[len] = 0;
+    s = getenv(buf);
+  }
+  if (s != NULL && strlen(s) < result_size) {
+    mi_strlcpy(result, s, result_size);
+    return true;
+  }
+  else {
+    return false;
+  }
+}
+#endif  // !MI_USE_ENVIRON
+#endif  // !MI_NO_GETENV
+
+static void mi_option_init(mi_option_desc_t* desc) {  
+  // Read option value from the environment
+  char s[64+1];
+  char buf[64+1];
+  mi_strlcpy(buf, "mimalloc_", sizeof(buf));
+  mi_strlcat(buf, desc->name, sizeof(buf));
+  bool found = mi_getenv(buf,s,sizeof(s));
+  if (!found && desc->legacy_name != NULL) {
+    mi_strlcpy(buf, "mimalloc_", sizeof(buf));
+    mi_strlcat(buf, desc->legacy_name, sizeof(buf));
+    found = mi_getenv(buf,s,sizeof(s));
+    if (found) {
+      _mi_warning_message("environment option \"mimalloc_%s\" is deprecated -- use \"mimalloc_%s\" instead.\n", desc->legacy_name, desc->name );
+    }    
+  }
+
+  if (found) {
+    size_t len = strlen(s);
+    if (len >= sizeof(buf)) len = sizeof(buf) - 1;
+    for (size_t i = 0; i < len; i++) {
+      buf[i] = (char)toupper(s[i]);
+    }
+    buf[len] = 0;
+    if (buf[0]==0 || strstr("1;TRUE;YES;ON", buf) != NULL) {
+      desc->value = 1;
+      desc->init = INITIALIZED;
+    }
+    else if (strstr("0;FALSE;NO;OFF", buf) != NULL) {
+      desc->value = 0;
+      desc->init = INITIALIZED;
+    }
+    else {
+      char* end = buf;
+      long value = strtol(buf, &end, 10);
+      if (desc->option == mi_option_reserve_os_memory) {
+        // this option is interpreted in KiB to prevent overflow of `long`
+        if (*end == 'K') { end++; }
+        else if (*end == 'M') { value *= MI_KiB; end++; }
+        else if (*end == 'G') { value *= MI_MiB; end++; }
+        else { value = (value + MI_KiB - 1) / MI_KiB; }
+        if (end[0] == 'I' && end[1] == 'B') { end += 2; }
+        else if (*end == 'B') { end++; }
+      }
+      if (*end == 0) {
+        desc->value = value;
+        desc->init = INITIALIZED;
+      }
+      else {
+        // set `init` first to avoid recursion through _mi_warning_message on mimalloc_verbose.
+        desc->init = DEFAULTED;
+        if (desc->option == mi_option_verbose && desc->value == 0) {
+          // if the 'mimalloc_verbose' env var has a bogus value we'd never know
+          // (since the value defaults to 'off') so in that case briefly enable verbose
+          desc->value = 1;
+          _mi_warning_message("environment option mimalloc_%s has an invalid value.\n", desc->name );
+          desc->value = 0;
+        }
+        else {
+          _mi_warning_message("environment option mimalloc_%s has an invalid value.\n", desc->name );
+        }
+      }
+    }
+    mi_assert_internal(desc->init != UNINIT);
+  }
+  else if (!_mi_preloading()) {
+    desc->init = DEFAULTED;
+  }
+}
diff --git a/Objects/mimalloc/os.c b/Objects/mimalloc/os.c
new file mode 100644
index 0000000000000..4171aae94d82d
--- /dev/null
+++ b/Objects/mimalloc/os.c
@@ -0,0 +1,1435 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2021, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+#ifndef _DEFAULT_SOURCE
+#define _DEFAULT_SOURCE   // ensure mmap flags are defined
+#endif
+
+#if defined(__sun)
+// illumos provides new mman.h api when any of these are defined
+// otherwise the old api based on caddr_t which predates the void pointers one.
+// stock solaris provides only the former, chose to atomically to discard those
+// flags only here rather than project wide tough.
+#undef _XOPEN_SOURCE
+#undef _POSIX_C_SOURCE
+#endif
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+#include "mimalloc-atomic.h"
+
+#include <string.h>  // strerror
+
+#ifdef _MSC_VER
+#pragma warning(disable:4996)  // strerror
+#endif
+
+#if defined(__wasi__)
+#define MI_USE_SBRK
+#endif
+
+#if defined(_WIN32)
+#include <windows.h>
+#elif defined(__wasi__)
+#include <unistd.h>    // sbrk
+#else
+#include <sys/mman.h>  // mmap
+#include <unistd.h>    // sysconf
+#if defined(__linux__)
+#include <features.h>
+#include <fcntl.h>
+#if defined(__GLIBC__)
+#include <linux/mman.h> // linux mmap flags
+#else
+#include <sys/mman.h>
+#endif
+#endif
+#if defined(__APPLE__)
+#include <TargetConditionals.h>
+#if !TARGET_IOS_IPHONE && !TARGET_IOS_SIMULATOR
+#include <mach/vm_statistics.h>
+#endif
+#endif
+#if defined(__FreeBSD__) || defined(__DragonFly__)
+#include <sys/param.h>
+#if __FreeBSD_version >= 1200000
+#include <sys/cpuset.h>
+#include <sys/domainset.h>
+#endif
+#include <sys/sysctl.h>
+#endif
+#endif
+
+/* -----------------------------------------------------------
+  Initialization.
+  On windows initializes support for aligned allocation and
+  large OS pages (if MIMALLOC_LARGE_OS_PAGES is true).
+----------------------------------------------------------- */
+bool    _mi_os_decommit(void* addr, size_t size, mi_stats_t* stats);
+
+static void* mi_align_up_ptr(void* p, size_t alignment) {
+  return (void*)_mi_align_up((uintptr_t)p, alignment);
+}
+
+static void* mi_align_down_ptr(void* p, size_t alignment) {
+  return (void*)_mi_align_down((uintptr_t)p, alignment);
+}
+
+
+// page size (initialized properly in `os_init`)
+static size_t os_page_size = 4096;
+
+// minimal allocation granularity
+static size_t os_alloc_granularity = 4096;
+
+// if non-zero, use large page allocation
+static size_t large_os_page_size = 0;
+
+// is memory overcommit allowed? 
+// set dynamically in _mi_os_init (and if true we use MAP_NORESERVE)
+static bool os_overcommit = true;
+
+bool _mi_os_has_overcommit(void) {
+  return os_overcommit;
+}
+
+// OS (small) page size
+size_t _mi_os_page_size() {
+  return os_page_size;
+}
+
+// if large OS pages are supported (2 or 4MiB), then return the size, otherwise return the small page size (4KiB)
+size_t _mi_os_large_page_size(void) {
+  return (large_os_page_size != 0 ? large_os_page_size : _mi_os_page_size());
+}
+
+#if !defined(MI_USE_SBRK) && !defined(__wasi__)
+static bool use_large_os_page(size_t size, size_t alignment) {
+  // if we have access, check the size and alignment requirements
+  if (large_os_page_size == 0 || !mi_option_is_enabled(mi_option_large_os_pages)) return false;
+  return ((size % large_os_page_size) == 0 && (alignment % large_os_page_size) == 0);
+}
+#endif
+
+// round to a good OS allocation size (bounded by max 12.5% waste)
+size_t _mi_os_good_alloc_size(size_t size) {
+  size_t align_size;
+  if (size < 512*MI_KiB) align_size = _mi_os_page_size();
+  else if (size < 2*MI_MiB) align_size = 64*MI_KiB;
+  else if (size < 8*MI_MiB) align_size = 256*MI_KiB;
+  else if (size < 32*MI_MiB) align_size = 1*MI_MiB;
+  else align_size = 4*MI_MiB;
+  if (mi_unlikely(size >= (SIZE_MAX - align_size))) return size; // possible overflow?
+  return _mi_align_up(size, align_size);
+}
+
+#if defined(_WIN32)
+// We use VirtualAlloc2 for aligned allocation, but it is only supported on Windows 10 and Windows Server 2016.
+// So, we need to look it up dynamically to run on older systems. (use __stdcall for 32-bit compatibility)
+// NtAllocateVirtualAllocEx is used for huge OS page allocation (1GiB)
+//
+// We hide MEM_EXTENDED_PARAMETER to compile with older SDK's.
+#include <winternl.h>
+typedef PVOID    (__stdcall *PVirtualAlloc2)(HANDLE, PVOID, SIZE_T, ULONG, ULONG, /* MEM_EXTENDED_PARAMETER* */ void*, ULONG);
+typedef NTSTATUS (__stdcall *PNtAllocateVirtualMemoryEx)(HANDLE, PVOID*, SIZE_T*, ULONG, ULONG, /* MEM_EXTENDED_PARAMETER* */ PVOID, ULONG);
+static PVirtualAlloc2 pVirtualAlloc2 = NULL;
+static PNtAllocateVirtualMemoryEx pNtAllocateVirtualMemoryEx = NULL;
+
+// Similarly, GetNumaProcesorNodeEx is only supported since Windows 7
+#if (_WIN32_WINNT < 0x601)  // before Win7
+typedef struct _PROCESSOR_NUMBER { WORD Group; BYTE Number; BYTE Reserved; } PROCESSOR_NUMBER, *PPROCESSOR_NUMBER;
+#endif
+typedef VOID (__stdcall *PGetCurrentProcessorNumberEx)(PPROCESSOR_NUMBER ProcNumber);
+typedef BOOL (__stdcall *PGetNumaProcessorNodeEx)(PPROCESSOR_NUMBER Processor, PUSHORT NodeNumber);
+typedef BOOL (__stdcall* PGetNumaNodeProcessorMaskEx)(USHORT Node, PGROUP_AFFINITY ProcessorMask);
+static PGetCurrentProcessorNumberEx pGetCurrentProcessorNumberEx = NULL;
+static PGetNumaProcessorNodeEx      pGetNumaProcessorNodeEx = NULL;
+static PGetNumaNodeProcessorMaskEx  pGetNumaNodeProcessorMaskEx = NULL;
+
+static bool mi_win_enable_large_os_pages()
+{
+  if (large_os_page_size > 0) return true;
+
+  // Try to see if large OS pages are supported
+  // To use large pages on Windows, we first need access permission
+  // Set "Lock pages in memory" permission in the group policy editor
+  // <https://devblogs.microsoft.com/oldnewthing/20110128-00/?p=11643>
+  unsigned long err = 0;
+  HANDLE token = NULL;
+  BOOL ok = OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &token);
+  if (ok) {
+    TOKEN_PRIVILEGES tp;
+    ok = LookupPrivilegeValue(NULL, TEXT("SeLockMemoryPrivilege"), &tp.Privileges[0].Luid);
+    if (ok) {
+      tp.PrivilegeCount = 1;
+      tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
+      ok = AdjustTokenPrivileges(token, FALSE, &tp, 0, (PTOKEN_PRIVILEGES)NULL, 0);
+      if (ok) {
+        err = GetLastError();
+        ok = (err == ERROR_SUCCESS);
+        if (ok) {
+          large_os_page_size = GetLargePageMinimum();
+        }
+      }
+    }
+    CloseHandle(token);
+  }
+  if (!ok) {
+    if (err == 0) err = GetLastError();
+    _mi_warning_message("cannot enable large OS page support, error %lu\n", err);
+  }
+  return (ok!=0);
+}
+
+void _mi_os_init(void) 
+{
+  os_overcommit = false;
+  // get the page size
+  SYSTEM_INFO si;
+  GetSystemInfo(&si);
+  if (si.dwPageSize > 0) os_page_size = si.dwPageSize;
+  if (si.dwAllocationGranularity > 0) os_alloc_granularity = si.dwAllocationGranularity;
+  // get the VirtualAlloc2 function
+  HINSTANCE  hDll;
+  hDll = LoadLibrary(TEXT("kernelbase.dll"));
+  if (hDll != NULL) {
+    // use VirtualAlloc2FromApp if possible as it is available to Windows store apps
+    pVirtualAlloc2 = (PVirtualAlloc2)(void (*)(void))GetProcAddress(hDll, "VirtualAlloc2FromApp");
+    if (pVirtualAlloc2==NULL) pVirtualAlloc2 = (PVirtualAlloc2)(void (*)(void))GetProcAddress(hDll, "VirtualAlloc2");
+    FreeLibrary(hDll);
+  }
+  // NtAllocateVirtualMemoryEx is used for huge page allocation
+  hDll = LoadLibrary(TEXT("ntdll.dll"));
+  if (hDll != NULL) {
+    pNtAllocateVirtualMemoryEx = (PNtAllocateVirtualMemoryEx)(void (*)(void))GetProcAddress(hDll, "NtAllocateVirtualMemoryEx");
+    FreeLibrary(hDll);
+  }
+  // Try to use Win7+ numa API
+  hDll = LoadLibrary(TEXT("kernel32.dll"));
+  if (hDll != NULL) {
+    pGetCurrentProcessorNumberEx = (PGetCurrentProcessorNumberEx)(void (*)(void))GetProcAddress(hDll, "GetCurrentProcessorNumberEx");
+    pGetNumaProcessorNodeEx = (PGetNumaProcessorNodeEx)(void (*)(void))GetProcAddress(hDll, "GetNumaProcessorNodeEx");
+    pGetNumaNodeProcessorMaskEx = (PGetNumaNodeProcessorMaskEx)(void (*)(void))GetProcAddress(hDll, "GetNumaNodeProcessorMaskEx");
+    FreeLibrary(hDll);
+  }
+  if (mi_option_is_enabled(mi_option_large_os_pages) || mi_option_is_enabled(mi_option_reserve_huge_os_pages)) {
+    mi_win_enable_large_os_pages();
+  }
+}
+#elif defined(__wasi__)
+void _mi_os_init() {
+  os_overcommit = false;
+  os_page_size = 64*MI_KiB; // WebAssembly has a fixed page size: 64KiB
+  os_alloc_granularity = 16;
+}
+
+#else  // generic unix
+
+static void os_detect_overcommit(void) {
+#if defined(__linux__)
+  int fd = open("/proc/sys/vm/overcommit_memory", O_RDONLY);
+        if (fd < 0) return;
+  char buf[32];
+  ssize_t nread = read(fd, &buf, sizeof(buf));
+        close(fd);
+  // <https://www.kernel.org/doc/Documentation/vm/overcommit-accounting>
+  // 0: heuristic overcommit, 1: always overcommit, 2: never overcommit (ignore NORESERVE)
+  if (nread >= 1) {
+    os_overcommit = (buf[0] == '0' || buf[0] == '1');
+  }
+#elif defined(__FreeBSD__)
+  int val = 0;
+  size_t olen = sizeof(val);
+  if (sysctlbyname("vm.overcommit", &val, &olen, NULL, 0) == 0) {
+    os_overcommit = (val != 0);
+  }  
+#else
+  // default: overcommit is true  
+#endif
+}
+
+void _mi_os_init() {
+  // get the page size
+  long result = sysconf(_SC_PAGESIZE);
+  if (result > 0) {
+    os_page_size = (size_t)result;
+    os_alloc_granularity = os_page_size;
+  }
+  large_os_page_size = 2*MI_MiB; // TODO: can we query the OS for this?
+  os_detect_overcommit();
+}
+#endif
+
+
+#if defined(MADV_NORMAL)
+static int mi_madvise(void* addr, size_t length, int advice) {
+  #if defined(__sun)
+  return madvise((caddr_t)addr, length, advice);  // Solaris needs cast (issue #520)
+  #else
+  return madvise(addr, length, advice);
+  #endif
+}
+#endif
+
+
+/* -----------------------------------------------------------
+  free memory
+-------------------------------------------------------------- */
+
+static bool mi_os_mem_free(void* addr, size_t size, bool was_committed, mi_stats_t* stats)
+{
+  if (addr == NULL || size == 0) return true; // || _mi_os_is_huge_reserved(addr)
+  bool err = false;
+#if defined(_WIN32)
+  err = (VirtualFree(addr, 0, MEM_RELEASE) == 0);
+#elif defined(MI_USE_SBRK) || defined(__wasi__)
+  err = 0; // sbrk heap cannot be shrunk
+#else
+  err = (munmap(addr, size) == -1);
+#endif
+  if (was_committed) _mi_stat_decrease(&stats->committed, size);
+  _mi_stat_decrease(&stats->reserved, size);
+  if (err) {
+    _mi_warning_message("munmap failed: %s, addr 0x%8li, size %lu\n", strerror(errno), (size_t)addr, size);
+    return false;
+  }
+  else {
+    return true;
+  }
+}
+
+#if !(defined(__wasi__) || defined(MI_USE_SBRK) || defined(MAP_ALIGNED))
+static void* mi_os_get_aligned_hint(size_t try_alignment, size_t size);
+#endif
+
+/* -----------------------------------------------------------
+  Raw allocation on Windows (VirtualAlloc) 
+-------------------------------------------------------------- */
+
+#ifdef _WIN32
+ 
+#define MEM_COMMIT_RESERVE  (MEM_COMMIT|MEM_RESERVE)
+
+static void* mi_win_virtual_allocx(void* addr, size_t size, size_t try_alignment, DWORD flags) {
+#if (MI_INTPTR_SIZE >= 8)
+  // on 64-bit systems, try to use the virtual address area after 2TiB for 4MiB aligned allocations
+  if (addr == NULL) {
+    void* hint = mi_os_get_aligned_hint(try_alignment,size);
+    if (hint != NULL) {
+      void* p = VirtualAlloc(hint, size, flags, PAGE_READWRITE);
+      if (p != NULL) return p;
+      // for robustness always fall through in case of an error
+      /*
+      DWORD err = GetLastError();
+      if (err != ERROR_INVALID_ADDRESS &&   // If linked with multiple instances, we may have tried to allocate at an already allocated area (#210)
+          err != ERROR_INVALID_PARAMETER) { // Windows7 instability (#230)
+        return NULL;
+      }
+      */
+      _mi_warning_message("unable to allocate hinted aligned OS memory (%zu bytes, error code: %x, address: %p, alignment: %d, flags: %x)\n", size, GetLastError(), hint, try_alignment, flags);
+    }
+  } 
+#endif
+#if defined(MEM_EXTENDED_PARAMETER_TYPE_BITS)
+  // on modern Windows try use VirtualAlloc2 for aligned allocation
+  if (try_alignment > 1 && (try_alignment % _mi_os_page_size()) == 0 && pVirtualAlloc2 != NULL) {
+    MEM_ADDRESS_REQUIREMENTS reqs = { 0, 0, 0 };
+    reqs.Alignment = try_alignment;
+    MEM_EXTENDED_PARAMETER param = { {0, 0}, {0} };
+    param.Type = MemExtendedParameterAddressRequirements;
+    param.Pointer = &reqs;
+    void* p = (*pVirtualAlloc2)(GetCurrentProcess(), addr, size, flags, PAGE_READWRITE, &param, 1);
+    if (p != NULL) return p;
+    _mi_warning_message("unable to allocate aligned OS memory (%zu bytes, error code: %x, address: %p, alignment: %d, flags: %x)\n", size, GetLastError(), addr, try_alignment, flags);
+    // fall through on error
+  }
+#endif
+  // last resort
+  return VirtualAlloc(addr, size, flags, PAGE_READWRITE);
+}
+
+static void* mi_win_virtual_alloc(void* addr, size_t size, size_t try_alignment, DWORD flags, bool large_only, bool allow_large, bool* is_large) {
+  mi_assert_internal(!(large_only && !allow_large));
+  static _Atomic(size_t) large_page_try_ok; // = 0;
+  void* p = NULL;
+  if ((large_only || use_large_os_page(size, try_alignment))
+      && allow_large && (flags&MEM_COMMIT)!=0 && (flags&MEM_RESERVE)!=0) {
+    size_t try_ok = mi_atomic_load_acquire(&large_page_try_ok);
+    if (!large_only && try_ok > 0) {
+      // if a large page allocation fails, it seems the calls to VirtualAlloc get very expensive.
+      // therefore, once a large page allocation failed, we don't try again for `large_page_try_ok` times.
+      mi_atomic_cas_strong_acq_rel(&large_page_try_ok, &try_ok, try_ok - 1);
+    }
+    else {
+      // large OS pages must always reserve and commit.
+      *is_large = true;
+      p = mi_win_virtual_allocx(addr, size, try_alignment, flags | MEM_LARGE_PAGES);
+      if (large_only) return p;
+      // fall back to non-large page allocation on error (`p == NULL`).
+      if (p == NULL) {
+        mi_atomic_store_release(&large_page_try_ok,10UL);  // on error, don't try again for the next N allocations
+      }
+    }
+  }
+  if (p == NULL) {
+    *is_large = ((flags&MEM_LARGE_PAGES) != 0);
+    p = mi_win_virtual_allocx(addr, size, try_alignment, flags);
+  }
+  if (p == NULL) {
+    _mi_warning_message("unable to allocate OS memory (%zu bytes, error code: %i, address: %p, large only: %d, allow large: %d)\n", size, GetLastError(), addr, large_only, allow_large);
+  }
+  return p;
+}
+
+/* -----------------------------------------------------------
+  Raw allocation using `sbrk` or `wasm_memory_grow`
+-------------------------------------------------------------- */
+
+#elif defined(MI_USE_SBRK) || defined(__wasi__)
+#if defined(MI_USE_SBRK) 
+  static void* mi_memory_grow( size_t size ) {
+    void* p = sbrk(size);
+    if (p == (void*)(-1)) return NULL;
+    #if !defined(__wasi__) // on wasi this is always zero initialized already (?)
+    memset(p,0,size); 
+    #endif
+    return p;
+  }
+#elif defined(__wasi__)
+  static void* mi_memory_grow( size_t size ) {
+    size_t base = (size > 0 ? __builtin_wasm_memory_grow(0,_mi_divide_up(size, _mi_os_page_size()))
+                            : __builtin_wasm_memory_size(0));
+    if (base == SIZE_MAX) return NULL;     
+    return (void*)(base * _mi_os_page_size());    
+  }
+#endif
+
+#if defined(MI_USE_PTHREADS)
+static pthread_mutex_t mi_heap_grow_mutex = PTHREAD_MUTEX_INITIALIZER;
+#endif
+
+static void* mi_heap_grow(size_t size, size_t try_alignment) {
+  void* p = NULL;
+  if (try_alignment <= 1) {
+    // `sbrk` is not thread safe in general so try to protect it (we could skip this on WASM but leave it in for now)
+    #if defined(MI_USE_PTHREADS) 
+    pthread_mutex_lock(&mi_heap_grow_mutex);
+    #endif
+    p = mi_memory_grow(size);
+    #if defined(MI_USE_PTHREADS)
+    pthread_mutex_unlock(&mi_heap_grow_mutex);
+    #endif
+  }
+  else {
+    void* base = NULL;
+    size_t alloc_size = 0;
+    // to allocate aligned use a lock to try to avoid thread interaction
+    // between getting the current size and actual allocation
+    // (also, `sbrk` is not thread safe in general)
+    #if defined(MI_USE_PTHREADS)
+    pthread_mutex_lock(&mi_heap_grow_mutex);
+    #endif
+    {
+      void* current = mi_memory_grow(0);  // get current size
+      if (current != NULL) {
+        void* aligned_current = mi_align_up_ptr(current, try_alignment);  // and align from there to minimize wasted space
+        alloc_size = _mi_align_up( ((uint8_t*)aligned_current - (uint8_t*)current) + size, _mi_os_page_size());
+        base = mi_memory_grow(alloc_size);        
+      }
+    }
+    #if defined(MI_USE_PTHREADS)
+    pthread_mutex_unlock(&mi_heap_grow_mutex);
+    #endif
+    if (base != NULL) {
+      p = mi_align_up_ptr(base, try_alignment);
+      if ((uint8_t*)p + size > (uint8_t*)base + alloc_size) {
+        // another thread used wasm_memory_grow/sbrk in-between and we do not have enough
+        // space after alignment. Give up (and waste the space as we cannot shrink :-( )
+        // (in `mi_os_mem_alloc_aligned` this will fall back to overallocation to align)
+        p = NULL;
+      }
+    }
+  }
+  if (p == NULL) {
+    _mi_warning_message("unable to allocate sbrk/wasm_memory_grow OS memory (%zu bytes, %zu alignment)\n", size, try_alignment);    
+    errno = ENOMEM;
+    return NULL;
+  }
+  mi_assert_internal( try_alignment == 0 || (uintptr_t)p % try_alignment == 0 );
+  return p;
+}
+
+/* -----------------------------------------------------------
+  Raw allocation on Unix's (mmap)
+-------------------------------------------------------------- */
+#else 
+#define MI_OS_USE_MMAP
+static void* mi_unix_mmapx(void* addr, size_t size, size_t try_alignment, int protect_flags, int flags, int fd) {
+  MI_UNUSED(try_alignment);  
+  #if defined(MAP_ALIGNED)  // BSD
+  if (addr == NULL && try_alignment > 1 && (try_alignment % _mi_os_page_size()) == 0) {
+    size_t n = mi_bsr(try_alignment);
+    if (((size_t)1 << n) == try_alignment && n >= 12 && n <= 30) {  // alignment is a power of 2 and 4096 <= alignment <= 1GiB
+      flags |= MAP_ALIGNED(n);
+      void* p = mmap(addr, size, protect_flags, flags | MAP_ALIGNED(n), fd, 0);
+      if (p!=MAP_FAILED) return p;
+      // fall back to regular mmap
+    }
+  }
+  #elif defined(MAP_ALIGN)  // Solaris
+  if (addr == NULL && try_alignment > 1 && (try_alignment % _mi_os_page_size()) == 0) {
+    void* p = mmap((void*)try_alignment, size, protect_flags, flags | MAP_ALIGN, fd, 0);  // addr parameter is the required alignment
+    if (p!=MAP_FAILED) return p;
+    // fall back to regular mmap
+  }
+  #endif
+  #if (MI_INTPTR_SIZE >= 8) && !defined(MAP_ALIGNED)
+  // on 64-bit systems, use the virtual address area after 2TiB for 4MiB aligned allocations
+  if (addr == NULL) {
+    void* hint = mi_os_get_aligned_hint(try_alignment, size);
+    if (hint != NULL) {
+      void* p = mmap(hint, size, protect_flags, flags, fd, 0);
+      if (p!=MAP_FAILED) return p;
+      // fall back to regular mmap
+    }
+  }
+  #endif
+  // regular mmap
+  void* p = mmap(addr, size, protect_flags, flags, fd, 0);
+  if (p!=MAP_FAILED) return p;  
+  // failed to allocate
+  return NULL;
+}
+
+static int mi_unix_mmap_fd(void) {
+#if defined(VM_MAKE_TAG)
+  // macOS: tracking anonymous page with a specific ID. (All up to 98 are taken officially but LLVM sanitizers had taken 99)
+  int os_tag = (int)mi_option_get(mi_option_os_tag);
+  if (os_tag < 100 || os_tag > 255) os_tag = 100;
+  return VM_MAKE_TAG(os_tag);
+#else
+  return -1;
+#endif
+}
+
+static void* mi_unix_mmap(void* addr, size_t size, size_t try_alignment, int protect_flags, bool large_only, bool allow_large, bool* is_large) {
+  void* p = NULL;
+  #if !defined(MAP_ANONYMOUS)
+  #define MAP_ANONYMOUS  MAP_ANON
+  #endif
+  #if !defined(MAP_NORESERVE)
+  #define MAP_NORESERVE  0
+  #endif
+  const int fd = mi_unix_mmap_fd();
+  int flags = MAP_PRIVATE | MAP_ANONYMOUS;
+  if (_mi_os_has_overcommit()) {
+    flags |= MAP_NORESERVE;
+  }  
+  #if defined(PROT_MAX)
+  protect_flags |= PROT_MAX(PROT_READ | PROT_WRITE); // BSD
+  #endif    
+  // huge page allocation
+  if ((large_only || use_large_os_page(size, try_alignment)) && allow_large) {
+    static _Atomic(size_t) large_page_try_ok; // = 0;
+    size_t try_ok = mi_atomic_load_acquire(&large_page_try_ok);
+    if (!large_only && try_ok > 0) {
+      // If the OS is not configured for large OS pages, or the user does not have
+      // enough permission, the `mmap` will always fail (but it might also fail for other reasons).
+      // Therefore, once a large page allocation failed, we don't try again for `large_page_try_ok` times
+      // to avoid too many failing calls to mmap.
+      mi_atomic_cas_strong_acq_rel(&large_page_try_ok, &try_ok, try_ok - 1);
+    }
+    else {
+      int lflags = flags & ~MAP_NORESERVE;  // using NORESERVE on huge pages seems to fail on Linux
+      int lfd = fd;
+      #ifdef MAP_ALIGNED_SUPER
+      lflags |= MAP_ALIGNED_SUPER;
+      #endif
+      #ifdef MAP_HUGETLB
+      lflags |= MAP_HUGETLB;
+      #endif
+      #ifdef MAP_HUGE_1GB
+      static bool mi_huge_pages_available = true;
+      if ((size % MI_GiB) == 0 && mi_huge_pages_available) {
+        lflags |= MAP_HUGE_1GB;
+      }
+      else
+      #endif
+      {
+        #ifdef MAP_HUGE_2MB
+        lflags |= MAP_HUGE_2MB;
+        #endif
+      }
+      #ifdef VM_FLAGS_SUPERPAGE_SIZE_2MB
+      lfd |= VM_FLAGS_SUPERPAGE_SIZE_2MB;
+      #endif
+      if (large_only || lflags != flags) {
+        // try large OS page allocation
+        *is_large = true;
+        p = mi_unix_mmapx(addr, size, try_alignment, protect_flags, lflags, lfd);
+        #ifdef MAP_HUGE_1GB
+        if (p == NULL && (lflags & MAP_HUGE_1GB) != 0) {
+          mi_huge_pages_available = false; // don't try huge 1GiB pages again
+          _mi_warning_message("unable to allocate huge (1GiB) page, trying large (2MiB) pages instead (error %i)\n", errno);
+          lflags = ((lflags & ~MAP_HUGE_1GB) | MAP_HUGE_2MB);
+          p = mi_unix_mmapx(addr, size, try_alignment, protect_flags, lflags, lfd);
+        }
+        #endif
+        if (large_only) return p;
+        if (p == NULL) {
+          mi_atomic_store_release(&large_page_try_ok, (size_t)8);  // on error, don't try again for the next N allocations
+        }
+      }
+    }
+  }
+  // regular allocation
+  if (p == NULL) {
+    *is_large = false;
+    p = mi_unix_mmapx(addr, size, try_alignment, protect_flags, flags, fd);
+    if (p != NULL) {
+      #if defined(MADV_HUGEPAGE)
+      // Many Linux systems don't allow MAP_HUGETLB but they support instead
+      // transparent huge pages (THP). Generally, it is not required to call `madvise` with MADV_HUGE
+      // though since properly aligned allocations will already use large pages if available
+      // in that case -- in particular for our large regions (in `memory.c`).
+      // However, some systems only allow THP if called with explicit `madvise`, so
+      // when large OS pages are enabled for mimalloc, we call `madvise` anyways.
+      if (allow_large && use_large_os_page(size, try_alignment)) {
+        if (mi_madvise(p, size, MADV_HUGEPAGE) == 0) {
+          *is_large = true; // possibly
+        };
+      }
+      #elif defined(__sun)
+      if (allow_large && use_large_os_page(size, try_alignment)) {
+        struct memcntl_mha cmd = {0};
+        cmd.mha_pagesize = large_os_page_size;
+        cmd.mha_cmd = MHA_MAPSIZE_VA;
+        if (memcntl((caddr_t)p, size, MC_HAT_ADVISE, (caddr_t)&cmd, 0, 0) == 0) {
+          *is_large = true;
+        }
+      }      
+      #endif
+    }
+  }
+  if (p == NULL) {
+    _mi_warning_message("unable to allocate OS memory (%zu bytes, error code: %i, address: %p, large only: %d, allow large: %d)\n", size, errno, addr, large_only, allow_large);
+  }
+  return p;
+}
+#endif
+
+// On 64-bit systems, we can do efficient aligned allocation by using
+// the 2TiB to 30TiB area to allocate them.
+#if (MI_INTPTR_SIZE >= 8) && (defined(_WIN32) || defined(MI_OS_USE_MMAP))
+static mi_decl_cache_align _Atomic(uintptr_t) aligned_base;
+
+// Return a 4MiB aligned address that is probably available.
+// If this returns NULL, the OS will determine the address but on some OS's that may not be 
+// properly aligned which can be more costly as it needs to be adjusted afterwards.
+// For a size > 1GiB this always returns NULL in order to guarantee good ASLR randomization; 
+// (otherwise an initial large allocation of say 2TiB has a 50% chance to include (known) addresses 
+//  in the middle of the 2TiB - 6TiB address range (see issue #372))
+
+#define MI_HINT_BASE ((uintptr_t)2 << 40)  // 2TiB start
+#define MI_HINT_AREA ((uintptr_t)4 << 40)  // upto 6TiB   (since before win8 there is "only" 8TiB available to processes)
+#define MI_HINT_MAX  ((uintptr_t)30 << 40) // wrap after 30TiB (area after 32TiB is used for huge OS pages)
+
+static void* mi_os_get_aligned_hint(size_t try_alignment, size_t size) 
+{
+  if (try_alignment <= 1 || try_alignment > MI_SEGMENT_SIZE) return NULL;
+  size = _mi_align_up(size, MI_SEGMENT_SIZE);
+  if (size > 1*MI_GiB) return NULL;  // guarantee the chance of fixed valid address is at most 1/(MI_HINT_AREA / 1<<30) = 1/4096.
+  #if (MI_SECURE>0)
+  size += MI_SEGMENT_SIZE;        // put in `MI_SEGMENT_SIZE` virtual gaps between hinted blocks; this splits VLA's but increases guarded areas.
+  #endif
+
+  uintptr_t hint = mi_atomic_add_acq_rel(&aligned_base, size);
+  if (hint == 0 || hint > MI_HINT_MAX) {   // wrap or initialize
+    uintptr_t init = MI_HINT_BASE;
+    #if (MI_SECURE>0 || MI_DEBUG==0)       // security: randomize start of aligned allocations unless in debug mode
+    uintptr_t r = _mi_heap_random_next(mi_get_default_heap());
+    init = init + ((MI_SEGMENT_SIZE * ((r>>17) & 0xFFFFF)) % MI_HINT_AREA);  // (randomly 20 bits)*4MiB == 0 to 4TiB
+    #endif
+    uintptr_t expected = hint + size;
+    mi_atomic_cas_strong_acq_rel(&aligned_base, &expected, init);
+    hint = mi_atomic_add_acq_rel(&aligned_base, size); // this may still give 0 or > MI_HINT_MAX but that is ok, it is a hint after all
+  }
+  if (hint%try_alignment != 0) return NULL;
+  return (void*)hint;
+}
+#elif defined(__wasi__) || defined(MI_USE_SBRK) || defined(MAP_ALIGNED)
+// no need for mi_os_get_aligned_hint
+#else
+static void* mi_os_get_aligned_hint(size_t try_alignment, size_t size) {
+  MI_UNUSED(try_alignment); MI_UNUSED(size);
+  return NULL;
+}
+#endif
+
+/* -----------------------------------------------------------
+   Primitive allocation from the OS.
+-------------------------------------------------------------- */
+
+// Note: the `try_alignment` is just a hint and the returned pointer is not guaranteed to be aligned.
+static void* mi_os_mem_alloc(size_t size, size_t try_alignment, bool commit, bool allow_large, bool* is_large, mi_stats_t* stats) {
+  mi_assert_internal(size > 0 && (size % _mi_os_page_size()) == 0);
+  if (size == 0) return NULL;
+  if (!commit) allow_large = false;
+  if (try_alignment == 0) try_alignment = 1; // avoid 0 to ensure there will be no divide by zero when aligning
+
+  void* p = NULL;
+  /*
+  if (commit && allow_large) {
+    p = _mi_os_try_alloc_from_huge_reserved(size, try_alignment);
+    if (p != NULL) {
+      *is_large = true;
+      return p;
+    }
+  }
+  */
+
+  #if defined(_WIN32)
+    int flags = MEM_RESERVE;
+    if (commit) flags |= MEM_COMMIT;
+    p = mi_win_virtual_alloc(NULL, size, try_alignment, flags, false, allow_large, is_large);
+  #elif defined(MI_USE_SBRK) || defined(__wasi__)
+    MI_UNUSED(allow_large);
+    *is_large = false;
+    p = mi_heap_grow(size, try_alignment);
+  #else
+    int protect_flags = (commit ? (PROT_WRITE | PROT_READ) : PROT_NONE);
+    p = mi_unix_mmap(NULL, size, try_alignment, protect_flags, false, allow_large, is_large);
+  #endif
+  mi_stat_counter_increase(stats->mmap_calls, 1);
+  if (p != NULL) {
+    _mi_stat_increase(&stats->reserved, size);
+    if (commit) { _mi_stat_increase(&stats->committed, size); }
+  }
+  return p;
+}
+
+
+// Primitive aligned allocation from the OS.
+// This function guarantees the allocated memory is aligned.
+static void* mi_os_mem_alloc_aligned(size_t size, size_t alignment, bool commit, bool allow_large, bool* is_large, mi_stats_t* stats) {
+  mi_assert_internal(alignment >= _mi_os_page_size() && ((alignment & (alignment - 1)) == 0));
+  mi_assert_internal(size > 0 && (size % _mi_os_page_size()) == 0);
+  if (!commit) allow_large = false;
+  if (!(alignment >= _mi_os_page_size() && ((alignment & (alignment - 1)) == 0))) return NULL;
+  size = _mi_align_up(size, _mi_os_page_size());
+
+  // try first with a hint (this will be aligned directly on Win 10+ or BSD)
+  void* p = mi_os_mem_alloc(size, alignment, commit, allow_large, is_large, stats);
+  if (p == NULL) return NULL;
+
+  // if not aligned, free it, overallocate, and unmap around it
+  if (((uintptr_t)p % alignment != 0)) {
+    mi_os_mem_free(p, size, commit, stats);
+    if (size >= (SIZE_MAX - alignment)) return NULL; // overflow
+    size_t over_size = size + alignment;
+
+#if _WIN32
+    // over-allocate and than re-allocate exactly at an aligned address in there.
+    // this may fail due to threads allocating at the same time so we
+    // retry this at most 3 times before giving up.
+    // (we can not decommit around the overallocation on Windows, because we can only
+    //  free the original pointer, not one pointing inside the area)
+    int flags = MEM_RESERVE;
+    if (commit) flags |= MEM_COMMIT;
+    for (int tries = 0; tries < 3; tries++) {
+      // over-allocate to determine a virtual memory range
+      p = mi_os_mem_alloc(over_size, alignment, commit, false, is_large, stats);
+      if (p == NULL) return NULL; // error
+      if (((uintptr_t)p % alignment) == 0) {
+        // if p happens to be aligned, just decommit the left-over area
+        _mi_os_decommit((uint8_t*)p + size, over_size - size, stats);
+        break;
+      }
+      else {
+        // otherwise free and allocate at an aligned address in there
+        mi_os_mem_free(p, over_size, commit, stats);
+        void* aligned_p = mi_align_up_ptr(p, alignment);
+        p = mi_win_virtual_alloc(aligned_p, size, alignment, flags, false, allow_large, is_large);
+        if (p != NULL) {
+          _mi_stat_increase(&stats->reserved, size);
+          if (commit) { _mi_stat_increase(&stats->committed, size); }
+        }
+        if (p == aligned_p) break; // success!
+        if (p != NULL) { // should not happen?
+          mi_os_mem_free(p, size, commit, stats);
+          p = NULL;
+        }
+      }
+    }
+#else
+    // overallocate...
+    p = mi_os_mem_alloc(over_size, 1, commit, false, is_large, stats);
+    if (p == NULL) return NULL;
+    // and selectively unmap parts around the over-allocated area. (noop on sbrk)
+    void* aligned_p = mi_align_up_ptr(p, alignment);
+    size_t pre_size = (uint8_t*)aligned_p - (uint8_t*)p;
+    size_t mid_size = _mi_align_up(size, _mi_os_page_size());
+    size_t post_size = over_size - pre_size - mid_size;
+    mi_assert_internal(pre_size < over_size && post_size < over_size && mid_size >= size);
+    if (pre_size > 0)  mi_os_mem_free(p, pre_size, commit, stats);
+    if (post_size > 0) mi_os_mem_free((uint8_t*)aligned_p + mid_size, post_size, commit, stats);
+    // we can return the aligned pointer on `mmap` (and sbrk) systems
+    p = aligned_p;
+#endif
+  }
+
+  mi_assert_internal(p == NULL || (p != NULL && ((uintptr_t)p % alignment) == 0));
+  return p;
+}
+
+/* -----------------------------------------------------------
+  OS API: alloc, free, alloc_aligned
+----------------------------------------------------------- */
+
+void* _mi_os_alloc(size_t size, mi_stats_t* tld_stats) {
+  MI_UNUSED(tld_stats);
+  mi_stats_t* stats = &_mi_stats_main;
+  if (size == 0) return NULL;
+  size = _mi_os_good_alloc_size(size);
+  bool is_large = false;
+  return mi_os_mem_alloc(size, 0, true, false, &is_large, stats);
+}
+
+void  _mi_os_free_ex(void* p, size_t size, bool was_committed, mi_stats_t* tld_stats) {
+  MI_UNUSED(tld_stats);
+  mi_stats_t* stats = &_mi_stats_main;
+  if (size == 0 || p == NULL) return;
+  size = _mi_os_good_alloc_size(size);
+  mi_os_mem_free(p, size, was_committed, stats);
+}
+
+void  _mi_os_free(void* p, size_t size, mi_stats_t* stats) {
+  _mi_os_free_ex(p, size, true, stats);
+}
+
+void* _mi_os_alloc_aligned(size_t size, size_t alignment, bool commit, bool* large, mi_stats_t* tld_stats)
+{
+  MI_UNUSED(tld_stats);
+  if (size == 0) return NULL;
+  size = _mi_os_good_alloc_size(size);
+  alignment = _mi_align_up(alignment, _mi_os_page_size());
+  bool allow_large = false;
+  if (large != NULL) {
+    allow_large = *large;
+    *large = false;
+  }
+  return mi_os_mem_alloc_aligned(size, alignment, commit, allow_large, (large!=NULL?large:&allow_large), &_mi_stats_main /*tld->stats*/ );
+}
+
+
+
+/* -----------------------------------------------------------
+  OS memory API: reset, commit, decommit, protect, unprotect.
+----------------------------------------------------------- */
+
+
+// OS page align within a given area, either conservative (pages inside the area only),
+// or not (straddling pages outside the area is possible)
+static void* mi_os_page_align_areax(bool conservative, void* addr, size_t size, size_t* newsize) {
+  mi_assert(addr != NULL && size > 0);
+  if (newsize != NULL) *newsize = 0;
+  if (size == 0 || addr == NULL) return NULL;
+
+  // page align conservatively within the range
+  void* start = (conservative ? mi_align_up_ptr(addr, _mi_os_page_size())
+    : mi_align_down_ptr(addr, _mi_os_page_size()));
+  void* end = (conservative ? mi_align_down_ptr((uint8_t*)addr + size, _mi_os_page_size())
+    : mi_align_up_ptr((uint8_t*)addr + size, _mi_os_page_size()));
+  ptrdiff_t diff = (uint8_t*)end - (uint8_t*)start;
+  if (diff <= 0) return NULL;
+
+  mi_assert_internal((conservative && (size_t)diff <= size) || (!conservative && (size_t)diff >= size));
+  if (newsize != NULL) *newsize = (size_t)diff;
+  return start;
+}
+
+static void* mi_os_page_align_area_conservative(void* addr, size_t size, size_t* newsize) {
+  return mi_os_page_align_areax(true, addr, size, newsize);
+}
+
+static void mi_mprotect_hint(int err) {
+#if defined(MI_OS_USE_MMAP) && (MI_SECURE>=2) // guard page around every mimalloc page
+  if (err == ENOMEM) {
+    _mi_warning_message("the previous warning may have been caused by a low memory map limit.\n"
+                        "  On Linux this is controlled by the vm.max_map_count. For example:\n"
+                        "  > sudo sysctl -w vm.max_map_count=262144\n");
+  }
+#else
+  MI_UNUSED(err);
+#endif
+}
+
+// Commit/Decommit memory.
+// Usually commit is aligned liberal, while decommit is aligned conservative.
+// (but not for the reset version where we want commit to be conservative as well)
+static bool mi_os_commitx(void* addr, size_t size, bool commit, bool conservative, bool* is_zero, mi_stats_t* stats) {
+  // page align in the range, commit liberally, decommit conservative
+  if (is_zero != NULL) { *is_zero = false; }
+  size_t csize;
+  void* start = mi_os_page_align_areax(conservative, addr, size, &csize);
+  if (csize == 0) return true;  // || _mi_os_is_huge_reserved(addr))
+  int err = 0;
+  if (commit) {
+    _mi_stat_increase(&stats->committed, size);  // use size for precise commit vs. decommit
+    _mi_stat_counter_increase(&stats->commit_calls, 1);
+  }
+  else {
+    _mi_stat_decrease(&stats->committed, size);
+  }
+
+  #if defined(_WIN32)
+  if (commit) {
+    // *is_zero = true;  // note: if the memory was already committed, the call succeeds but the memory is not zero'd
+    void* p = VirtualAlloc(start, csize, MEM_COMMIT, PAGE_READWRITE);
+    err = (p == start ? 0 : GetLastError());
+  }
+  else {
+    BOOL ok = VirtualFree(start, csize, MEM_DECOMMIT);
+    err = (ok ? 0 : GetLastError());
+  }
+  #elif defined(__wasi__)
+  // WebAssembly guests can't control memory protection
+  #elif 0 && defined(MAP_FIXED) && !defined(__APPLE__)
+  // Linux: disabled for now as mmap fixed seems much more expensive than MADV_DONTNEED (and splits VMA's?)
+  if (commit) {
+    // commit: just change the protection
+    err = mprotect(start, csize, (PROT_READ | PROT_WRITE));
+    if (err != 0) { err = errno; }
+  } 
+  else {
+    // decommit: use mmap with MAP_FIXED to discard the existing memory (and reduce rss)
+    const int fd = mi_unix_mmap_fd();
+    void* p = mmap(start, csize, PROT_NONE, (MAP_FIXED | MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE), fd, 0);
+    if (p != start) { err = errno; }
+  }
+  #else
+  // Linux, macOSX and others.
+  if (commit) {
+    // commit: ensure we can access the area    
+    err = mprotect(start, csize, (PROT_READ | PROT_WRITE));
+    if (err != 0) { err = errno; }
+  } 
+  else {
+    #if defined(MADV_DONTNEED) && MI_DEBUG == 0 && MI_SECURE == 0
+    // decommit: use MADV_DONTNEED as it decreases rss immediately (unlike MADV_FREE)
+    // (on the other hand, MADV_FREE would be good enough.. it is just not reflected in the stats :-( )
+    err = madvise(start, csize, MADV_DONTNEED);
+    #else
+    // decommit: just disable access (also used in debug and secure mode to trap on illegal access)
+    err = mprotect(start, csize, PROT_NONE);
+    if (err != 0) { err = errno; }
+    #endif
+    //#if defined(MADV_FREE_REUSE)
+    //  while ((err = mi_madvise(start, csize, MADV_FREE_REUSE)) != 0 && errno == EAGAIN) { errno = 0; }
+    //#endif
+  }
+  #endif
+  if (err != 0) {
+    _mi_warning_message("%s error: start: %p, csize: 0x%zx, err: %i\n", commit ? "commit" : "decommit", start, csize, err);
+    mi_mprotect_hint(err);
+  }
+  mi_assert_internal(err == 0);
+  return (err == 0);
+}
+
+bool _mi_os_commit(void* addr, size_t size, bool* is_zero, mi_stats_t* tld_stats) {
+  MI_UNUSED(tld_stats);
+  mi_stats_t* stats = &_mi_stats_main;
+  return mi_os_commitx(addr, size, true, false /* liberal */, is_zero, stats);
+}
+
+bool _mi_os_decommit(void* addr, size_t size, mi_stats_t* tld_stats) {
+  MI_UNUSED(tld_stats);
+  mi_stats_t* stats = &_mi_stats_main;
+  bool is_zero;
+  return mi_os_commitx(addr, size, false, true /* conservative */, &is_zero, stats);
+}
+
+/*
+static bool mi_os_commit_unreset(void* addr, size_t size, bool* is_zero, mi_stats_t* stats) {  
+  return mi_os_commitx(addr, size, true, true // conservative
+                      , is_zero, stats);
+}
+*/
+
+// Signal to the OS that the address range is no longer in use
+// but may be used later again. This will release physical memory
+// pages and reduce swapping while keeping the memory committed.
+// We page align to a conservative area inside the range to reset.
+static bool mi_os_resetx(void* addr, size_t size, bool reset, mi_stats_t* stats) {
+  // page align conservatively within the range
+  size_t csize;
+  void* start = mi_os_page_align_area_conservative(addr, size, &csize);
+  if (csize == 0) return true;  // || _mi_os_is_huge_reserved(addr)
+  if (reset) _mi_stat_increase(&stats->reset, csize);
+        else _mi_stat_decrease(&stats->reset, csize);
+  if (!reset) return true; // nothing to do on unreset!
+
+  #if (MI_DEBUG>1)
+  if (MI_SECURE==0) {
+    memset(start, 0, csize); // pretend it is eagerly reset
+  }
+  #endif
+
+#if defined(_WIN32)
+  // Testing shows that for us (on `malloc-large`) MEM_RESET is 2x faster than DiscardVirtualMemory
+  void* p = VirtualAlloc(start, csize, MEM_RESET, PAGE_READWRITE);
+  mi_assert_internal(p == start);
+  #if 1
+  if (p == start && start != NULL) {
+    VirtualUnlock(start,csize); // VirtualUnlock after MEM_RESET removes the memory from the working set
+  }
+  #endif
+  if (p != start) return false;
+#else
+#if defined(MADV_FREE)
+  static _Atomic(size_t) advice = ATOMIC_VAR_INIT(MADV_FREE);
+  int oadvice = (int)mi_atomic_load_relaxed(&advice);
+  int err;
+  while ((err = mi_madvise(start, csize, oadvice)) != 0 && errno == EAGAIN) { errno = 0;  };
+  if (err != 0 && errno == EINVAL && oadvice == MADV_FREE) {  
+    // if MADV_FREE is not supported, fall back to MADV_DONTNEED from now on
+    mi_atomic_store_release(&advice, (size_t)MADV_DONTNEED);
+    err = mi_madvise(start, csize, MADV_DONTNEED);
+  }
+#elif defined(__wasi__)
+  int err = 0;
+#else
+  int err = mi_madvise(start, csize, MADV_DONTNEED);
+#endif
+  if (err != 0) {
+    _mi_warning_message("madvise reset error: start: %p, csize: 0x%zx, errno: %i\n", start, csize, errno);
+  }
+  //mi_assert(err == 0);
+  if (err != 0) return false;
+#endif
+  return true;
+}
+
+// Signal to the OS that the address range is no longer in use
+// but may be used later again. This will release physical memory
+// pages and reduce swapping while keeping the memory committed.
+// We page align to a conservative area inside the range to reset.
+bool _mi_os_reset(void* addr, size_t size, mi_stats_t* tld_stats) {
+  MI_UNUSED(tld_stats);
+  mi_stats_t* stats = &_mi_stats_main;
+  return mi_os_resetx(addr, size, true, stats);
+}
+
+/*
+bool _mi_os_unreset(void* addr, size_t size, bool* is_zero, mi_stats_t* tld_stats) {
+  MI_UNUSED(tld_stats);
+  mi_stats_t* stats = &_mi_stats_main;
+  if (mi_option_is_enabled(mi_option_reset_decommits)) {
+    return mi_os_commit_unreset(addr, size, is_zero, stats);  // re-commit it (conservatively!)
+  }
+  else {
+    *is_zero = false;
+    return mi_os_resetx(addr, size, false, stats);
+  }
+}
+*/
+
+// Protect a region in memory to be not accessible.
+static  bool mi_os_protectx(void* addr, size_t size, bool protect) {
+  // page align conservatively within the range
+  size_t csize = 0;
+  void* start = mi_os_page_align_area_conservative(addr, size, &csize);
+  if (csize == 0) return false;
+  /*
+  if (_mi_os_is_huge_reserved(addr)) {
+          _mi_warning_message("cannot mprotect memory allocated in huge OS pages\n");
+  }
+  */
+  int err = 0;
+#ifdef _WIN32
+  DWORD oldprotect = 0;
+  BOOL ok = VirtualProtect(start, csize, protect ? PAGE_NOACCESS : PAGE_READWRITE, &oldprotect);
+  err = (ok ? 0 : GetLastError());
+#elif defined(__wasi__)
+  err = 0;
+#else
+  err = mprotect(start, csize, protect ? PROT_NONE : (PROT_READ | PROT_WRITE));
+  if (err != 0) { err = errno; }
+#endif
+  if (err != 0) {
+    _mi_warning_message("mprotect error: start: %p, csize: 0x%zx, err: %i\n", start, csize, err);
+    mi_mprotect_hint(err);
+  }
+  return (err == 0);
+}
+
+bool _mi_os_protect(void* addr, size_t size) {
+  return mi_os_protectx(addr, size, true);
+}
+
+bool _mi_os_unprotect(void* addr, size_t size) {
+  return mi_os_protectx(addr, size, false);
+}
+
+
+
+bool _mi_os_shrink(void* p, size_t oldsize, size_t newsize, mi_stats_t* stats) {
+  // page align conservatively within the range
+  mi_assert_internal(oldsize > newsize && p != NULL);
+  if (oldsize < newsize || p == NULL) return false;
+  if (oldsize == newsize) return true;
+
+  // oldsize and newsize should be page aligned or we cannot shrink precisely
+  void* addr = (uint8_t*)p + newsize;
+  size_t size = 0;
+  void* start = mi_os_page_align_area_conservative(addr, oldsize - newsize, &size);
+  if (size == 0 || start != addr) return false;
+
+#ifdef _WIN32
+  // we cannot shrink on windows, but we can decommit
+  return _mi_os_decommit(start, size, stats);
+#else
+  return mi_os_mem_free(start, size, true, stats);
+#endif
+}
+
+
+/* ----------------------------------------------------------------------------
+Support for allocating huge OS pages (1Gib) that are reserved up-front
+and possibly associated with a specific NUMA node. (use `numa_node>=0`)
+-----------------------------------------------------------------------------*/
+#define MI_HUGE_OS_PAGE_SIZE  (MI_GiB)
+
+#if defined(_WIN32) && (MI_INTPTR_SIZE >= 8)
+static void* mi_os_alloc_huge_os_pagesx(void* addr, size_t size, int numa_node)
+{
+  mi_assert_internal(size%MI_GiB == 0);
+  mi_assert_internal(addr != NULL);
+  const DWORD flags = MEM_LARGE_PAGES | MEM_COMMIT | MEM_RESERVE;
+
+  mi_win_enable_large_os_pages();
+
+  #if defined(MEM_EXTENDED_PARAMETER_TYPE_BITS)
+  MEM_EXTENDED_PARAMETER params[3] = { {{0,0},{0}},{{0,0},{0}},{{0,0},{0}} };
+  // on modern Windows try use NtAllocateVirtualMemoryEx for 1GiB huge pages
+  static bool mi_huge_pages_available = true;
+  if (pNtAllocateVirtualMemoryEx != NULL && mi_huge_pages_available) {
+    #ifndef MEM_EXTENDED_PARAMETER_NONPAGED_HUGE
+    #define MEM_EXTENDED_PARAMETER_NONPAGED_HUGE  (0x10)
+    #endif
+    params[0].Type = 5; // == MemExtendedParameterAttributeFlags;
+    params[0].ULong64 = MEM_EXTENDED_PARAMETER_NONPAGED_HUGE;
+    ULONG param_count = 1;
+    if (numa_node >= 0) {
+      param_count++;
+      params[1].Type = MemExtendedParameterNumaNode;
+      params[1].ULong = (unsigned)numa_node;
+    }
+    SIZE_T psize = size;
+    void* base = addr;
+    NTSTATUS err = (*pNtAllocateVirtualMemoryEx)(GetCurrentProcess(), &base, &psize, flags, PAGE_READWRITE, params, param_count);
+    if (err == 0 && base != NULL) {
+      return base;
+    }
+    else {
+      // fall back to regular large pages
+      mi_huge_pages_available = false; // don't try further huge pages
+      _mi_warning_message("unable to allocate using huge (1GiB) pages, trying large (2MiB) pages instead (status 0x%lx)\n", err);
+    }
+  }
+  // on modern Windows try use VirtualAlloc2 for numa aware large OS page allocation
+  if (pVirtualAlloc2 != NULL && numa_node >= 0) {
+    params[0].Type = MemExtendedParameterNumaNode;
+    params[0].ULong = (unsigned)numa_node;
+    return (*pVirtualAlloc2)(GetCurrentProcess(), addr, size, flags, PAGE_READWRITE, params, 1);
+  }
+  #else
+    MI_UNUSED(numa_node);
+  #endif
+  // otherwise use regular virtual alloc on older windows
+  return VirtualAlloc(addr, size, flags, PAGE_READWRITE);
+}
+
+#elif defined(MI_OS_USE_MMAP) && (MI_INTPTR_SIZE >= 8) && !defined(__HAIKU__)
+#include <sys/syscall.h>
+#ifndef MPOL_PREFERRED
+#define MPOL_PREFERRED 1
+#endif
+#if defined(SYS_mbind)
+static long mi_os_mbind(void* start, unsigned long len, unsigned long mode, const unsigned long* nmask, unsigned long maxnode, unsigned flags) {
+  return syscall(SYS_mbind, start, len, mode, nmask, maxnode, flags);
+}
+#else
+static long mi_os_mbind(void* start, unsigned long len, unsigned long mode, const unsigned long* nmask, unsigned long maxnode, unsigned flags) {
+  MI_UNUSED(start); MI_UNUSED(len); MI_UNUSED(mode); MI_UNUSED(nmask); MI_UNUSED(maxnode); MI_UNUSED(flags);
+  return 0;
+}
+#endif
+static void* mi_os_alloc_huge_os_pagesx(void* addr, size_t size, int numa_node) {
+  mi_assert_internal(size%MI_GiB == 0);
+  bool is_large = true;
+  void* p = mi_unix_mmap(addr, size, MI_SEGMENT_SIZE, PROT_READ | PROT_WRITE, true, true, &is_large);
+  if (p == NULL) return NULL;
+  if (numa_node >= 0 && numa_node < 8*MI_INTPTR_SIZE) { // at most 64 nodes
+    unsigned long numa_mask = (1UL << numa_node);
+    // TODO: does `mbind` work correctly for huge OS pages? should we
+    // use `set_mempolicy` before calling mmap instead?
+    // see: <https://lkml.org/lkml/2017/2/9/875>
+    long err = mi_os_mbind(p, size, MPOL_PREFERRED, &numa_mask, 8*MI_INTPTR_SIZE, 0);
+    if (err != 0) {
+      _mi_warning_message("failed to bind huge (1GiB) pages to numa node %d: %s\n", numa_node, strerror(errno));
+    }
+  }
+  return p;
+}
+#else
+static void* mi_os_alloc_huge_os_pagesx(void* addr, size_t size, int numa_node) {
+  MI_UNUSED(addr); MI_UNUSED(size); MI_UNUSED(numa_node);
+  return NULL;
+}
+#endif
+
+#if (MI_INTPTR_SIZE >= 8)
+// To ensure proper alignment, use our own area for huge OS pages
+static mi_decl_cache_align _Atomic(uintptr_t)  mi_huge_start; // = 0
+
+// Claim an aligned address range for huge pages
+static uint8_t* mi_os_claim_huge_pages(size_t pages, size_t* total_size) {
+  if (total_size != NULL) *total_size = 0;
+  const size_t size = pages * MI_HUGE_OS_PAGE_SIZE;
+
+  uintptr_t start = 0;
+  uintptr_t end = 0;
+  uintptr_t huge_start = mi_atomic_load_relaxed(&mi_huge_start);
+  do {
+    start = huge_start;
+    if (start == 0) {
+      // Initialize the start address after the 32TiB area
+      start = ((uintptr_t)32 << 40);  // 32TiB virtual start address
+#if (MI_SECURE>0 || MI_DEBUG==0)      // security: randomize start of huge pages unless in debug mode
+      uintptr_t r = _mi_heap_random_next(mi_get_default_heap());
+      start = start + ((uintptr_t)MI_HUGE_OS_PAGE_SIZE * ((r>>17) & 0x0FFF));  // (randomly 12bits)*1GiB == between 0 to 4TiB
+#endif
+    }
+    end = start + size;
+    mi_assert_internal(end % MI_SEGMENT_SIZE == 0);
+  } while (!mi_atomic_cas_strong_acq_rel(&mi_huge_start, &huge_start, end));
+
+  if (total_size != NULL) *total_size = size;
+  return (uint8_t*)start;
+}
+#else
+static uint8_t* mi_os_claim_huge_pages(size_t pages, size_t* total_size) {
+  MI_UNUSED(pages);
+  if (total_size != NULL) *total_size = 0;
+  return NULL;
+}
+#endif
+
+// Allocate MI_SEGMENT_SIZE aligned huge pages
+void* _mi_os_alloc_huge_os_pages(size_t pages, int numa_node, mi_msecs_t max_msecs, size_t* pages_reserved, size_t* psize) {
+  if (psize != NULL) *psize = 0;
+  if (pages_reserved != NULL) *pages_reserved = 0;
+  size_t size = 0;
+  uint8_t* start = mi_os_claim_huge_pages(pages, &size);
+  if (start == NULL) return NULL; // or 32-bit systems
+
+  // Allocate one page at the time but try to place them contiguously
+  // We allocate one page at the time to be able to abort if it takes too long
+  // or to at least allocate as many as available on the system.
+  mi_msecs_t start_t = _mi_clock_start();
+  size_t page;
+  for (page = 0; page < pages; page++) {
+    // allocate a page
+    void* addr = start + (page * MI_HUGE_OS_PAGE_SIZE);
+    void* p = mi_os_alloc_huge_os_pagesx(addr, MI_HUGE_OS_PAGE_SIZE, numa_node);
+
+    // Did we succeed at a contiguous address?
+    if (p != addr) {
+      // no success, issue a warning and break
+      if (p != NULL) {
+        _mi_warning_message("could not allocate contiguous huge page %zu at %p\n", page, addr);
+        _mi_os_free(p, MI_HUGE_OS_PAGE_SIZE, &_mi_stats_main);
+      }
+      break;
+    }
+
+    // success, record it
+    _mi_stat_increase(&_mi_stats_main.committed, MI_HUGE_OS_PAGE_SIZE);
+    _mi_stat_increase(&_mi_stats_main.reserved, MI_HUGE_OS_PAGE_SIZE);
+
+    // check for timeout
+    if (max_msecs > 0) {
+      mi_msecs_t elapsed = _mi_clock_end(start_t);
+      if (page >= 1) {
+        mi_msecs_t estimate = ((elapsed / (page+1)) * pages);
+        if (estimate > 2*max_msecs) { // seems like we are going to timeout, break
+          elapsed = max_msecs + 1;
+        }
+      }
+      if (elapsed > max_msecs) {
+        _mi_warning_message("huge page allocation timed out\n");
+        break;
+      }
+    }
+  }
+  mi_assert_internal(page*MI_HUGE_OS_PAGE_SIZE <= size);
+  if (pages_reserved != NULL) { *pages_reserved = page; }
+  if (psize != NULL) { *psize = page * MI_HUGE_OS_PAGE_SIZE; }
+  return (page == 0 ? NULL : start);
+}
+
+// free every huge page in a range individually (as we allocated per page)
+// note: needed with VirtualAlloc but could potentially be done in one go on mmap'd systems.
+void _mi_os_free_huge_pages(void* p, size_t size, mi_stats_t* stats) {
+  if (p==NULL || size==0) return;
+  uint8_t* base = (uint8_t*)p;
+  while (size >= MI_HUGE_OS_PAGE_SIZE) {
+    _mi_os_free(base, MI_HUGE_OS_PAGE_SIZE, stats);
+    size -= MI_HUGE_OS_PAGE_SIZE;
+    base += MI_HUGE_OS_PAGE_SIZE;
+  }
+}
+
+/* ----------------------------------------------------------------------------
+Support NUMA aware allocation
+-----------------------------------------------------------------------------*/
+#ifdef _WIN32  
+static size_t mi_os_numa_nodex() {
+  USHORT numa_node = 0;
+  if (pGetCurrentProcessorNumberEx != NULL && pGetNumaProcessorNodeEx != NULL) {
+    // Extended API is supported
+    PROCESSOR_NUMBER pnum;
+    (*pGetCurrentProcessorNumberEx)(&pnum);
+    USHORT nnode = 0;
+    BOOL ok = (*pGetNumaProcessorNodeEx)(&pnum, &nnode);
+    if (ok) numa_node = nnode;
+  }
+  else {
+    // Vista or earlier, use older API that is limited to 64 processors. Issue #277
+    DWORD pnum = GetCurrentProcessorNumber();
+    UCHAR nnode = 0;
+    BOOL ok = GetNumaProcessorNode((UCHAR)pnum, &nnode);
+    if (ok) numa_node = nnode;    
+  }
+  return numa_node;
+}
+
+static size_t mi_os_numa_node_countx(void) {
+  ULONG numa_max = 0;
+  GetNumaHighestNodeNumber(&numa_max);
+  // find the highest node number that has actual processors assigned to it. Issue #282
+  while(numa_max > 0) {
+    if (pGetNumaNodeProcessorMaskEx != NULL) {
+      // Extended API is supported
+      GROUP_AFFINITY affinity;
+      if ((*pGetNumaNodeProcessorMaskEx)((USHORT)numa_max, &affinity)) {
+        if (affinity.Mask != 0) break;  // found the maximum non-empty node
+      }
+    }
+    else {
+      // Vista or earlier, use older API that is limited to 64 processors.
+      ULONGLONG mask;
+      if (GetNumaNodeProcessorMask((UCHAR)numa_max, &mask)) {
+        if (mask != 0) break; // found the maximum non-empty node
+      };
+    }
+    // max node was invalid or had no processor assigned, try again
+    numa_max--;
+  }
+  return ((size_t)numa_max + 1);
+}
+#elif defined(__linux__)
+#include <sys/syscall.h>  // getcpu
+#include <stdio.h>        // access
+
+static size_t mi_os_numa_nodex(void) {
+#ifdef SYS_getcpu
+  unsigned long node = 0;
+  unsigned long ncpu = 0;
+  long err = syscall(SYS_getcpu, &ncpu, &node, NULL);
+  if (err != 0) return 0;
+  return node;
+#else
+  return 0;
+#endif
+}
+static size_t mi_os_numa_node_countx(void) {
+  char buf[128];
+  unsigned node = 0;
+  for(node = 0; node < 256; node++) {
+    // enumerate node entries -- todo: it there a more efficient way to do this? (but ensure there is no allocation)
+    snprintf(buf, 127, "/sys/devices/system/node/node%u", node + 1);
+    if (access(buf,R_OK) != 0) break;
+  }
+  return (node+1);
+}
+#elif defined(__FreeBSD__) && __FreeBSD_version >= 1200000
+static size_t mi_os_numa_nodex(void) {
+  domainset_t dom;
+  size_t node;
+  int policy;
+  if (cpuset_getdomain(CPU_LEVEL_CPUSET, CPU_WHICH_PID, -1, sizeof(dom), &dom, &policy) == -1) return 0ul;
+  for (node = 0; node < MAXMEMDOM; node++) {
+    if (DOMAINSET_ISSET(node, &dom)) return node;
+  }
+  return 0ul;
+}
+static size_t mi_os_numa_node_countx(void) {
+  size_t ndomains = 0;
+  size_t len = sizeof(ndomains);
+  if (sysctlbyname("vm.ndomains", &ndomains, &len, NULL, 0) == -1) return 0ul;
+  return ndomains;
+}
+#elif defined(__DragonFly__)
+static size_t mi_os_numa_nodex(void) {
+  // TODO: DragonFly does not seem to provide any userland means to get this information.
+  return 0ul;
+}
+static size_t mi_os_numa_node_countx(void) {
+  size_t ncpus = 0, nvirtcoresperphys = 0;
+  size_t len = sizeof(size_t);
+  if (sysctlbyname("hw.ncpu", &ncpus, &len, NULL, 0) == -1) return 0ul;
+  if (sysctlbyname("hw.cpu_topology_ht_ids", &nvirtcoresperphys, &len, NULL, 0) == -1) return 0ul;
+  return nvirtcoresperphys * ncpus;
+}
+#else
+static size_t mi_os_numa_nodex(void) {
+  return 0;
+}
+static size_t mi_os_numa_node_countx(void) {
+  return 1;
+}
+#endif
+
+_Atomic(size_t)  _mi_numa_node_count; // = 0   // cache the node count
+
+size_t _mi_os_numa_node_count_get(void) {
+  size_t count = mi_atomic_load_acquire(&_mi_numa_node_count);
+  if (count <= 0) {
+    long ncount = mi_option_get(mi_option_use_numa_nodes); // given explicitly?
+    if (ncount > 0) {
+      count = (size_t)ncount;
+    }
+    else {
+      count = mi_os_numa_node_countx(); // or detect dynamically
+      if (count == 0) count = 1;
+    }    
+    mi_atomic_store_release(&_mi_numa_node_count, count); // save it
+    _mi_verbose_message("using %zd numa regions\n", count);
+  }
+  return count;
+}
+
+int _mi_os_numa_node_get(mi_os_tld_t* tld) {
+  MI_UNUSED(tld);
+  size_t numa_count = _mi_os_numa_node_count();
+  if (numa_count<=1) return 0; // optimize on single numa node systems: always node 0
+  // never more than the node count and >= 0
+  size_t numa_node = mi_os_numa_nodex();
+  if (numa_node >= numa_count) { numa_node = numa_node % numa_count; }
+  return (int)numa_node;
+}
diff --git a/Objects/mimalloc/page-queue.c b/Objects/mimalloc/page-queue.c
new file mode 100644
index 0000000000000..92f933c2a0d79
--- /dev/null
+++ b/Objects/mimalloc/page-queue.c
@@ -0,0 +1,331 @@
+/*----------------------------------------------------------------------------
+Copyright (c) 2018-2020, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+
+/* -----------------------------------------------------------
+  Definition of page queues for each block size
+----------------------------------------------------------- */
+
+#ifndef MI_IN_PAGE_C
+#error "this file should be included from 'page.c'"
+#endif
+
+/* -----------------------------------------------------------
+  Minimal alignment in machine words (i.e. `sizeof(void*)`)
+----------------------------------------------------------- */
+
+#if (MI_MAX_ALIGN_SIZE > 4*MI_INTPTR_SIZE)
+  #error "define alignment for more than 4x word size for this platform"
+#elif (MI_MAX_ALIGN_SIZE > 2*MI_INTPTR_SIZE)
+  #define MI_ALIGN4W   // 4 machine words minimal alignment
+#elif (MI_MAX_ALIGN_SIZE > MI_INTPTR_SIZE)
+  #define MI_ALIGN2W   // 2 machine words minimal alignment
+#else
+  // ok, default alignment is 1 word
+#endif
+
+
+/* -----------------------------------------------------------
+  Queue query
+----------------------------------------------------------- */
+
+
+static inline bool mi_page_queue_is_huge(const mi_page_queue_t* pq) {
+  return (pq->block_size == (MI_MEDIUM_OBJ_SIZE_MAX+sizeof(uintptr_t)));
+}
+
+static inline bool mi_page_queue_is_full(const mi_page_queue_t* pq) {
+  return (pq->block_size == (MI_MEDIUM_OBJ_SIZE_MAX+(2*sizeof(uintptr_t))));
+}
+
+static inline bool mi_page_queue_is_special(const mi_page_queue_t* pq) {
+  return (pq->block_size > MI_MEDIUM_OBJ_SIZE_MAX);
+}
+
+/* -----------------------------------------------------------
+  Bins
+----------------------------------------------------------- */
+
+// Return the bin for a given field size.
+// Returns MI_BIN_HUGE if the size is too large.
+// We use `wsize` for the size in "machine word sizes",
+// i.e. byte size == `wsize*sizeof(void*)`.
+static inline uint8_t mi_bin(size_t size) {
+  size_t wsize = _mi_wsize_from_size(size);
+  uint8_t bin;
+  if (wsize <= 1) {
+    bin = 1;
+  }
+  #if defined(MI_ALIGN4W)
+  else if (wsize <= 4) {
+    bin = (uint8_t)((wsize+1)&~1); // round to double word sizes
+  }
+  #elif defined(MI_ALIGN2W)
+  else if (wsize <= 8) {
+    bin = (uint8_t)((wsize+1)&~1); // round to double word sizes
+  }
+  #else
+  else if (wsize <= 8) {
+    bin = (uint8_t)wsize;
+  }
+  #endif
+  else if (wsize > MI_MEDIUM_OBJ_WSIZE_MAX) {
+    bin = MI_BIN_HUGE;
+  }
+  else {
+    #if defined(MI_ALIGN4W)
+    if (wsize <= 16) { wsize = (wsize+3)&~3; } // round to 4x word sizes
+    #endif
+    wsize--;
+    // find the highest bit
+    uint8_t b = (uint8_t)mi_bsr(wsize);  // note: wsize != 0
+    // and use the top 3 bits to determine the bin (~12.5% worst internal fragmentation).
+    // - adjust with 3 because we use do not round the first 8 sizes
+    //   which each get an exact bin
+    bin = ((b << 2) + (uint8_t)((wsize >> (b - 2)) & 0x03)) - 3;
+    mi_assert_internal(bin < MI_BIN_HUGE);
+  }
+  mi_assert_internal(bin > 0 && bin <= MI_BIN_HUGE);
+  return bin;
+}
+
+
+
+/* -----------------------------------------------------------
+  Queue of pages with free blocks
+----------------------------------------------------------- */
+
+uint8_t _mi_bin(size_t size) {
+  return mi_bin(size);
+}
+
+size_t _mi_bin_size(uint8_t bin) {
+  return _mi_heap_empty.pages[bin].block_size;
+}
+
+// Good size for allocation
+size_t mi_good_size(size_t size) mi_attr_noexcept {
+  if (size <= MI_MEDIUM_OBJ_SIZE_MAX) {
+    return _mi_bin_size(mi_bin(size));
+  }
+  else {
+    return _mi_align_up(size,_mi_os_page_size());
+  }
+}
+
+#if (MI_DEBUG>1)
+static bool mi_page_queue_contains(mi_page_queue_t* queue, const mi_page_t* page) {
+  mi_assert_internal(page != NULL);
+  mi_page_t* list = queue->first;
+  while (list != NULL) {
+    mi_assert_internal(list->next == NULL || list->next->prev == list);
+    mi_assert_internal(list->prev == NULL || list->prev->next == list);
+    if (list == page) break;
+    list = list->next;
+  }
+  return (list == page);
+}
+
+#endif
+
+#if (MI_DEBUG>1)
+static bool mi_heap_contains_queue(const mi_heap_t* heap, const mi_page_queue_t* pq) {
+  return (pq >= &heap->pages[0] && pq <= &heap->pages[MI_BIN_FULL]);
+}
+#endif
+
+static mi_page_queue_t* mi_page_queue_of(const mi_page_t* page) {
+  uint8_t bin = (mi_page_is_in_full(page) ? MI_BIN_FULL : mi_bin(page->xblock_size));
+  mi_heap_t* heap = mi_page_heap(page);
+  mi_assert_internal(heap != NULL && bin <= MI_BIN_FULL);
+  mi_page_queue_t* pq = &heap->pages[bin];
+  mi_assert_internal(bin >= MI_BIN_HUGE || page->xblock_size == pq->block_size);
+  mi_assert_expensive(mi_page_queue_contains(pq, page));
+  return pq;
+}
+
+static mi_page_queue_t* mi_heap_page_queue_of(mi_heap_t* heap, const mi_page_t* page) {
+  uint8_t bin = (mi_page_is_in_full(page) ? MI_BIN_FULL : mi_bin(page->xblock_size));
+  mi_assert_internal(bin <= MI_BIN_FULL);
+  mi_page_queue_t* pq = &heap->pages[bin];
+  mi_assert_internal(mi_page_is_in_full(page) || page->xblock_size == pq->block_size);
+  return pq;
+}
+
+// The current small page array is for efficiency and for each
+// small size (up to 256) it points directly to the page for that
+// size without having to compute the bin. This means when the
+// current free page queue is updated for a small bin, we need to update a
+// range of entries in `_mi_page_small_free`.
+static inline void mi_heap_queue_first_update(mi_heap_t* heap, const mi_page_queue_t* pq) {
+  mi_assert_internal(mi_heap_contains_queue(heap,pq));
+  size_t size = pq->block_size;
+  if (size > MI_SMALL_SIZE_MAX) return;
+
+  mi_page_t* page = pq->first;
+  if (pq->first == NULL) page = (mi_page_t*)&_mi_page_empty;
+
+  // find index in the right direct page array
+  size_t start;
+  size_t idx = _mi_wsize_from_size(size);
+  mi_page_t** pages_free = heap->pages_free_direct;
+
+  if (pages_free[idx] == page) return;  // already set
+
+  // find start slot
+  if (idx<=1) {
+    start = 0;
+  }
+  else {
+    // find previous size; due to minimal alignment upto 3 previous bins may need to be skipped
+    uint8_t bin = mi_bin(size);
+    const mi_page_queue_t* prev = pq - 1;
+    while( bin == mi_bin(prev->block_size) && prev > &heap->pages[0]) {
+      prev--;
+    }
+    start = 1 + _mi_wsize_from_size(prev->block_size);
+    if (start > idx) start = idx;
+  }
+
+  // set size range to the right page
+  mi_assert(start <= idx);
+  for (size_t sz = start; sz <= idx; sz++) {
+    pages_free[sz] = page;
+  }
+}
+
+/*
+static bool mi_page_queue_is_empty(mi_page_queue_t* queue) {
+  return (queue->first == NULL);
+}
+*/
+
+static void mi_page_queue_remove(mi_page_queue_t* queue, mi_page_t* page) {
+  mi_assert_internal(page != NULL);
+  mi_assert_expensive(mi_page_queue_contains(queue, page));
+  mi_assert_internal(page->xblock_size == queue->block_size || (page->xblock_size > MI_MEDIUM_OBJ_SIZE_MAX && mi_page_queue_is_huge(queue))  || (mi_page_is_in_full(page) && mi_page_queue_is_full(queue)));
+  mi_heap_t* heap = mi_page_heap(page);
+
+  if (page->prev != NULL) page->prev->next = page->next;
+  if (page->next != NULL) page->next->prev = page->prev;
+  if (page == queue->last)  queue->last = page->prev;
+  if (page == queue->first) {
+    queue->first = page->next;
+    // update first
+    mi_assert_internal(mi_heap_contains_queue(heap, queue));
+    mi_heap_queue_first_update(heap,queue);
+  }
+  heap->page_count--;
+  page->next = NULL;
+  page->prev = NULL;
+  // mi_atomic_store_ptr_release(mi_atomic_cast(void*, &page->heap), NULL);
+  mi_page_set_in_full(page,false);
+}
+
+
+static void mi_page_queue_push(mi_heap_t* heap, mi_page_queue_t* queue, mi_page_t* page) {
+  mi_assert_internal(mi_page_heap(page) == heap);
+  mi_assert_internal(!mi_page_queue_contains(queue, page));
+
+  mi_assert_internal(_mi_page_segment(page)->kind != MI_SEGMENT_HUGE);
+  mi_assert_internal(page->xblock_size == queue->block_size ||
+                      (page->xblock_size > MI_MEDIUM_OBJ_SIZE_MAX) ||
+                        (mi_page_is_in_full(page) && mi_page_queue_is_full(queue)));
+
+  mi_page_set_in_full(page, mi_page_queue_is_full(queue));
+  // mi_atomic_store_ptr_release(mi_atomic_cast(void*, &page->heap), heap);
+  page->next = queue->first;
+  page->prev = NULL;
+  if (queue->first != NULL) {
+    mi_assert_internal(queue->first->prev == NULL);
+    queue->first->prev = page;
+    queue->first = page;
+  }
+  else {
+    queue->first = queue->last = page;
+  }
+
+  // update direct
+  mi_heap_queue_first_update(heap, queue);
+  heap->page_count++;
+}
+
+
+static void mi_page_queue_enqueue_from(mi_page_queue_t* to, mi_page_queue_t* from, mi_page_t* page) {
+  mi_assert_internal(page != NULL);
+  mi_assert_expensive(mi_page_queue_contains(from, page));
+  mi_assert_expensive(!mi_page_queue_contains(to, page));
+
+  mi_assert_internal((page->xblock_size == to->block_size && page->xblock_size == from->block_size) ||
+                     (page->xblock_size == to->block_size && mi_page_queue_is_full(from)) ||
+                     (page->xblock_size == from->block_size && mi_page_queue_is_full(to)) ||
+                     (page->xblock_size > MI_LARGE_OBJ_SIZE_MAX && mi_page_queue_is_huge(to)) ||
+                     (page->xblock_size > MI_LARGE_OBJ_SIZE_MAX && mi_page_queue_is_full(to)));
+
+  mi_heap_t* heap = mi_page_heap(page);
+  if (page->prev != NULL) page->prev->next = page->next;
+  if (page->next != NULL) page->next->prev = page->prev;
+  if (page == from->last)  from->last = page->prev;
+  if (page == from->first) {
+    from->first = page->next;
+    // update first
+    mi_assert_internal(mi_heap_contains_queue(heap, from));
+    mi_heap_queue_first_update(heap, from);
+  }
+
+  page->prev = to->last;
+  page->next = NULL;
+  if (to->last != NULL) {
+    mi_assert_internal(heap == mi_page_heap(to->last));
+    to->last->next = page;
+    to->last = page;
+  }
+  else {
+    to->first = page;
+    to->last = page;
+    mi_heap_queue_first_update(heap, to);
+  }
+
+  mi_page_set_in_full(page, mi_page_queue_is_full(to));
+}
+
+// Only called from `mi_heap_absorb`.
+size_t _mi_page_queue_append(mi_heap_t* heap, mi_page_queue_t* pq, mi_page_queue_t* append) {
+  mi_assert_internal(mi_heap_contains_queue(heap,pq));
+  mi_assert_internal(pq->block_size == append->block_size);
+
+  if (append->first==NULL) return 0;
+
+  // set append pages to new heap and count
+  size_t count = 0;
+  for (mi_page_t* page = append->first; page != NULL; page = page->next) {
+    // inline `mi_page_set_heap` to avoid wrong assertion during absorption;
+    // in this case it is ok to be delayed freeing since both "to" and "from" heap are still alive.
+    mi_atomic_store_release(&page->xheap, (uintptr_t)heap); 
+    // set the flag to delayed free (not overriding NEVER_DELAYED_FREE) which has as a
+    // side effect that it spins until any DELAYED_FREEING is finished. This ensures
+    // that after appending only the new heap will be used for delayed free operations.
+    _mi_page_use_delayed_free(page, MI_USE_DELAYED_FREE, false);
+    count++;
+  }
+
+  if (pq->last==NULL) {
+    // take over afresh
+    mi_assert_internal(pq->first==NULL);
+    pq->first = append->first;
+    pq->last = append->last;
+    mi_heap_queue_first_update(heap, pq);
+  }
+  else {
+    // append to end
+    mi_assert_internal(pq->last!=NULL);
+    mi_assert_internal(append->first!=NULL);
+    pq->last->next = append->first;
+    append->first->prev = pq->last;
+    pq->last = append->last;
+  }
+  return count;
+}
diff --git a/Objects/mimalloc/page.c b/Objects/mimalloc/page.c
new file mode 100644
index 0000000000000..2d9a70331a837
--- /dev/null
+++ b/Objects/mimalloc/page.c
@@ -0,0 +1,880 @@
+/*----------------------------------------------------------------------------
+Copyright (c) 2018-2020, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+
+/* -----------------------------------------------------------
+  The core of the allocator. Every segment contains
+  pages of a certain block size. The main function
+  exported is `mi_malloc_generic`.
+----------------------------------------------------------- */
+
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+#include "mimalloc-atomic.h"
+
+/* -----------------------------------------------------------
+  Definition of page queues for each block size
+----------------------------------------------------------- */
+
+#define MI_IN_PAGE_C
+#include "page-queue.c"
+#undef MI_IN_PAGE_C
+
+
+/* -----------------------------------------------------------
+  Page helpers
+----------------------------------------------------------- */
+
+// Index a block in a page
+static inline mi_block_t* mi_page_block_at(const mi_page_t* page, void* page_start, size_t block_size, size_t i) {
+  MI_UNUSED(page);
+  mi_assert_internal(page != NULL);
+  mi_assert_internal(i <= page->reserved);
+  return (mi_block_t*)((uint8_t*)page_start + (i * block_size));
+}
+
+static void mi_page_init(mi_heap_t* heap, mi_page_t* page, size_t size, mi_tld_t* tld);
+static void mi_page_extend_free(mi_heap_t* heap, mi_page_t* page, mi_tld_t* tld);
+
+#if (MI_DEBUG>=3)
+static size_t mi_page_list_count(mi_page_t* page, mi_block_t* head) {
+  size_t count = 0;
+  while (head != NULL) {
+    mi_assert_internal(page == _mi_ptr_page(head));
+    count++;
+    head = mi_block_next(page, head);
+  }
+  return count;
+}
+
+/*
+// Start of the page available memory
+static inline uint8_t* mi_page_area(const mi_page_t* page) {
+  return _mi_page_start(_mi_page_segment(page), page, NULL);
+}
+*/
+
+static bool mi_page_list_is_valid(mi_page_t* page, mi_block_t* p) {
+  size_t psize;
+  uint8_t* page_area = _mi_page_start(_mi_page_segment(page), page, &psize);
+  mi_block_t* start = (mi_block_t*)page_area;
+  mi_block_t* end   = (mi_block_t*)(page_area + psize);
+  while(p != NULL) {
+    if (p < start || p >= end) return false;
+    p = mi_block_next(page, p);
+  }
+  return true;
+}
+
+static bool mi_page_is_valid_init(mi_page_t* page) {
+  mi_assert_internal(page->xblock_size > 0);
+  mi_assert_internal(page->used <= page->capacity);
+  mi_assert_internal(page->capacity <= page->reserved);
+
+  mi_segment_t* segment = _mi_page_segment(page);
+  uint8_t* start = _mi_page_start(segment,page,NULL);
+  mi_assert_internal(start == _mi_segment_page_start(segment,page,NULL));
+  //const size_t bsize = mi_page_block_size(page);
+  //mi_assert_internal(start + page->capacity*page->block_size == page->top);
+
+  mi_assert_internal(mi_page_list_is_valid(page,page->free));
+  mi_assert_internal(mi_page_list_is_valid(page,page->local_free));
+
+  #if MI_DEBUG>3 // generally too expensive to check this
+  if (page->is_zero) {
+    const size_t ubsize = mi_page_usable_block_size(page);
+    for(mi_block_t* block = page->free; block != NULL; block = mi_block_next(page,block)) {
+      mi_assert_expensive(mi_mem_is_zero(block + 1, ubsize - sizeof(mi_block_t)));
+    }
+  }
+  #endif
+
+  mi_block_t* tfree = mi_page_thread_free(page);
+  mi_assert_internal(mi_page_list_is_valid(page, tfree));
+  //size_t tfree_count = mi_page_list_count(page, tfree);
+  //mi_assert_internal(tfree_count <= page->thread_freed + 1);
+
+  size_t free_count = mi_page_list_count(page, page->free) + mi_page_list_count(page, page->local_free);
+  mi_assert_internal(page->used + free_count == page->capacity);
+
+  return true;
+}
+
+bool _mi_page_is_valid(mi_page_t* page) {
+  mi_assert_internal(mi_page_is_valid_init(page));
+  #if MI_SECURE
+  mi_assert_internal(page->keys[0] != 0);
+  #endif
+  if (mi_page_heap(page)!=NULL) {
+    mi_segment_t* segment = _mi_page_segment(page);
+
+    mi_assert_internal(!_mi_process_is_initialized || segment->thread_id==0 || segment->thread_id == mi_page_heap(page)->thread_id);
+    if (segment->kind != MI_SEGMENT_HUGE) {
+      mi_page_queue_t* pq = mi_page_queue_of(page);
+      mi_assert_internal(mi_page_queue_contains(pq, page));
+      mi_assert_internal(pq->block_size==mi_page_block_size(page) || mi_page_block_size(page) > MI_MEDIUM_OBJ_SIZE_MAX || mi_page_is_in_full(page));
+      mi_assert_internal(mi_heap_contains_queue(mi_page_heap(page),pq));
+    }
+  }
+  return true;
+}
+#endif
+
+void _mi_page_use_delayed_free(mi_page_t* page, mi_delayed_t delay, bool override_never) {
+  mi_thread_free_t tfreex;
+  mi_delayed_t     old_delay;
+  mi_thread_free_t tfree;  
+  do {
+    tfree = mi_atomic_load_acquire(&page->xthread_free); // note: must acquire as we can break/repeat this loop and not do a CAS;
+    tfreex = mi_tf_set_delayed(tfree, delay);
+    old_delay = mi_tf_delayed(tfree);
+    if (mi_unlikely(old_delay == MI_DELAYED_FREEING)) {
+      mi_atomic_yield(); // delay until outstanding MI_DELAYED_FREEING are done.
+      // tfree = mi_tf_set_delayed(tfree, MI_NO_DELAYED_FREE); // will cause CAS to busy fail
+    }
+    else if (delay == old_delay) {
+      break; // avoid atomic operation if already equal
+    }
+    else if (!override_never && old_delay == MI_NEVER_DELAYED_FREE) {
+      break; // leave never-delayed flag set
+    }
+  } while ((old_delay == MI_DELAYED_FREEING) ||
+           !mi_atomic_cas_weak_release(&page->xthread_free, &tfree, tfreex));
+}
+
+/* -----------------------------------------------------------
+  Page collect the `local_free` and `thread_free` lists
+----------------------------------------------------------- */
+
+// Collect the local `thread_free` list using an atomic exchange.
+// Note: The exchange must be done atomically as this is used right after
+// moving to the full list in `mi_page_collect_ex` and we need to
+// ensure that there was no race where the page became unfull just before the move.
+static void _mi_page_thread_free_collect(mi_page_t* page)
+{
+  mi_block_t* head;
+  mi_thread_free_t tfreex;
+  mi_thread_free_t tfree = mi_atomic_load_relaxed(&page->xthread_free);
+  do {
+    head = mi_tf_block(tfree);
+    tfreex = mi_tf_set_block(tfree,NULL);
+  } while (!mi_atomic_cas_weak_acq_rel(&page->xthread_free, &tfree, tfreex));
+
+  // return if the list is empty
+  if (head == NULL) return;
+
+  // find the tail -- also to get a proper count (without data races)
+  uint32_t max_count = page->capacity; // cannot collect more than capacity
+  uint32_t count = 1;
+  mi_block_t* tail = head;
+  mi_block_t* next;
+  while ((next = mi_block_next(page,tail)) != NULL && count <= max_count) {
+    count++;
+    tail = next;
+  }
+  // if `count > max_count` there was a memory corruption (possibly infinite list due to double multi-threaded free)
+  if (count > max_count) {
+    _mi_error_message(EFAULT, "corrupted thread-free list\n");
+    return; // the thread-free items cannot be freed
+  }
+
+  // and append the current local free list
+  mi_block_set_next(page,tail, page->local_free);
+  page->local_free = head;
+
+  // update counts now
+  page->used -= count;
+}
+
+void _mi_page_free_collect(mi_page_t* page, bool force) {
+  mi_assert_internal(page!=NULL);
+
+  // collect the thread free list
+  if (force || mi_page_thread_free(page) != NULL) {  // quick test to avoid an atomic operation
+    _mi_page_thread_free_collect(page);
+  }
+
+  // and the local free list
+  if (page->local_free != NULL) {
+    if (mi_likely(page->free == NULL)) {
+      // usual case
+      page->free = page->local_free;
+      page->local_free = NULL;
+      page->is_zero = false;
+    }
+    else if (force) {
+      // append -- only on shutdown (force) as this is a linear operation
+      mi_block_t* tail = page->local_free;
+      mi_block_t* next;
+      while ((next = mi_block_next(page, tail)) != NULL) {
+        tail = next;
+      }
+      mi_block_set_next(page, tail, page->free);
+      page->free = page->local_free;
+      page->local_free = NULL;
+      page->is_zero = false;
+    }
+  }
+
+  mi_assert_internal(!force || page->local_free == NULL);
+}
+
+
+
+/* -----------------------------------------------------------
+  Page fresh and retire
+----------------------------------------------------------- */
+
+// called from segments when reclaiming abandoned pages
+void _mi_page_reclaim(mi_heap_t* heap, mi_page_t* page) {
+  mi_assert_expensive(mi_page_is_valid_init(page));
+
+  mi_assert_internal(mi_page_heap(page) == heap);
+  mi_assert_internal(mi_page_thread_free_flag(page) != MI_NEVER_DELAYED_FREE);
+  mi_assert_internal(_mi_page_segment(page)->kind != MI_SEGMENT_HUGE);
+  mi_assert_internal(!page->is_reset);
+  // TODO: push on full queue immediately if it is full?
+  mi_page_queue_t* pq = mi_page_queue(heap, mi_page_block_size(page));
+  mi_page_queue_push(heap, pq, page);
+  mi_assert_expensive(_mi_page_is_valid(page));
+}
+
+// allocate a fresh page from a segment
+static mi_page_t* mi_page_fresh_alloc(mi_heap_t* heap, mi_page_queue_t* pq, size_t block_size) {
+  mi_assert_internal(pq==NULL||mi_heap_contains_queue(heap, pq));
+  mi_page_t* page = _mi_segment_page_alloc(heap, block_size, &heap->tld->segments, &heap->tld->os);
+  if (page == NULL) {
+    // this may be out-of-memory, or an abandoned page was reclaimed (and in our queue)
+    return NULL;
+  }
+  mi_assert_internal(pq==NULL || _mi_page_segment(page)->kind != MI_SEGMENT_HUGE);
+  mi_page_init(heap, page, block_size, heap->tld);
+  _mi_stat_increase(&heap->tld->stats.pages, 1);
+  if (pq!=NULL) mi_page_queue_push(heap, pq, page); // huge pages use pq==NULL
+  mi_assert_expensive(_mi_page_is_valid(page));
+  return page;
+}
+
+// Get a fresh page to use
+static mi_page_t* mi_page_fresh(mi_heap_t* heap, mi_page_queue_t* pq) {
+  mi_assert_internal(mi_heap_contains_queue(heap, pq));
+  mi_page_t* page = mi_page_fresh_alloc(heap, pq, pq->block_size);
+  if (page==NULL) return NULL;
+  mi_assert_internal(pq->block_size==mi_page_block_size(page));
+  mi_assert_internal(pq==mi_page_queue(heap, mi_page_block_size(page)));
+  return page;
+}
+
+/* -----------------------------------------------------------
+   Do any delayed frees
+   (put there by other threads if they deallocated in a full page)
+----------------------------------------------------------- */
+void _mi_heap_delayed_free(mi_heap_t* heap) {
+  // take over the list (note: no atomic exchange since it is often NULL)
+  mi_block_t* block = mi_atomic_load_ptr_relaxed(mi_block_t, &heap->thread_delayed_free);
+  while (block != NULL && !mi_atomic_cas_ptr_weak_acq_rel(mi_block_t, &heap->thread_delayed_free, &block, NULL)) { /* nothing */ };
+
+  // and free them all
+  while(block != NULL) {
+    mi_block_t* next = mi_block_nextx(heap,block, heap->keys);
+    // use internal free instead of regular one to keep stats etc correct
+    if (!_mi_free_delayed_block(block)) {
+      // we might already start delayed freeing while another thread has not yet
+      // reset the delayed_freeing flag; in that case delay it further by reinserting.
+      mi_block_t* dfree = mi_atomic_load_ptr_relaxed(mi_block_t, &heap->thread_delayed_free);
+      do {
+        mi_block_set_nextx(heap, block, dfree, heap->keys);
+      } while (!mi_atomic_cas_ptr_weak_release(mi_block_t,&heap->thread_delayed_free, &dfree, block));
+    }
+    block = next;
+  }
+}
+
+/* -----------------------------------------------------------
+  Unfull, abandon, free and retire
+----------------------------------------------------------- */
+
+// Move a page from the full list back to a regular list
+void _mi_page_unfull(mi_page_t* page) {
+  mi_assert_internal(page != NULL);
+  mi_assert_expensive(_mi_page_is_valid(page));
+  mi_assert_internal(mi_page_is_in_full(page));
+  if (!mi_page_is_in_full(page)) return;
+
+  mi_heap_t* heap = mi_page_heap(page);
+  mi_page_queue_t* pqfull = &heap->pages[MI_BIN_FULL];
+  mi_page_set_in_full(page, false); // to get the right queue
+  mi_page_queue_t* pq = mi_heap_page_queue_of(heap, page);
+  mi_page_set_in_full(page, true);
+  mi_page_queue_enqueue_from(pq, pqfull, page);
+}
+
+static void mi_page_to_full(mi_page_t* page, mi_page_queue_t* pq) {
+  mi_assert_internal(pq == mi_page_queue_of(page));
+  mi_assert_internal(!mi_page_immediate_available(page));
+  mi_assert_internal(!mi_page_is_in_full(page));
+
+  if (mi_page_is_in_full(page)) return;
+  mi_page_queue_enqueue_from(&mi_page_heap(page)->pages[MI_BIN_FULL], pq, page);
+  _mi_page_free_collect(page,false);  // try to collect right away in case another thread freed just before MI_USE_DELAYED_FREE was set
+}
+
+
+// Abandon a page with used blocks at the end of a thread.
+// Note: only call if it is ensured that no references exist from
+// the `page->heap->thread_delayed_free` into this page.
+// Currently only called through `mi_heap_collect_ex` which ensures this.
+void _mi_page_abandon(mi_page_t* page, mi_page_queue_t* pq) {
+  mi_assert_internal(page != NULL);
+  mi_assert_expensive(_mi_page_is_valid(page));
+  mi_assert_internal(pq == mi_page_queue_of(page));
+  mi_assert_internal(mi_page_heap(page) != NULL);
+
+  mi_heap_t* pheap = mi_page_heap(page);
+
+  // remove from our page list
+  mi_segments_tld_t* segments_tld = &pheap->tld->segments;
+  mi_page_queue_remove(pq, page);
+
+  // page is no longer associated with our heap
+  mi_assert_internal(mi_page_thread_free_flag(page)==MI_NEVER_DELAYED_FREE);
+  mi_page_set_heap(page, NULL);
+
+#if MI_DEBUG>1
+  // check there are no references left..
+  for (mi_block_t* block = (mi_block_t*)pheap->thread_delayed_free; block != NULL; block = mi_block_nextx(pheap, block, pheap->keys)) {
+    mi_assert_internal(_mi_ptr_page(block) != page);
+  }
+#endif
+
+  // and abandon it
+  mi_assert_internal(mi_page_heap(page) == NULL);
+  _mi_segment_page_abandon(page,segments_tld);
+}
+
+
+// Free a page with no more free blocks
+void _mi_page_free(mi_page_t* page, mi_page_queue_t* pq, bool force) {
+  mi_assert_internal(page != NULL);
+  mi_assert_expensive(_mi_page_is_valid(page));
+  mi_assert_internal(pq == mi_page_queue_of(page));
+  mi_assert_internal(mi_page_all_free(page));
+  mi_assert_internal(mi_page_thread_free_flag(page)!=MI_DELAYED_FREEING);
+
+  // no more aligned blocks in here
+  mi_page_set_has_aligned(page, false);
+
+  mi_heap_t* heap = mi_page_heap(page);
+  const size_t bsize = mi_page_block_size(page);
+  if (bsize > MI_MEDIUM_OBJ_SIZE_MAX) {
+    if (bsize <= MI_LARGE_OBJ_SIZE_MAX) {      
+      _mi_stat_decrease(&heap->tld->stats.large, bsize);
+    }
+    else {
+      // not strictly necessary as we never get here for a huge page
+      mi_assert_internal(false);
+      _mi_stat_decrease(&heap->tld->stats.huge, bsize);      
+    }
+  }
+
+  // remove from the page list
+  // (no need to do _mi_heap_delayed_free first as all blocks are already free)
+  mi_segments_tld_t* segments_tld = &heap->tld->segments;
+  mi_page_queue_remove(pq, page);
+
+  // and free it
+  mi_page_set_heap(page,NULL);
+  _mi_segment_page_free(page, force, segments_tld);
+}
+
+// Retire parameters
+#define MI_MAX_RETIRE_SIZE    MI_MEDIUM_OBJ_SIZE_MAX  
+#define MI_RETIRE_CYCLES      (8)
+
+// Retire a page with no more used blocks
+// Important to not retire too quickly though as new
+// allocations might coming.
+// Note: called from `mi_free` and benchmarks often
+// trigger this due to freeing everything and then
+// allocating again so careful when changing this.
+void _mi_page_retire(mi_page_t* page) mi_attr_noexcept {
+  mi_assert_internal(page != NULL);
+  mi_assert_expensive(_mi_page_is_valid(page));
+  mi_assert_internal(mi_page_all_free(page));
+  
+  mi_page_set_has_aligned(page, false);
+
+  // don't retire too often..
+  // (or we end up retiring and re-allocating most of the time)
+  // NOTE: refine this more: we should not retire if this
+  // is the only page left with free blocks. It is not clear
+  // how to check this efficiently though...
+  // for now, we don't retire if it is the only page left of this size class.
+  mi_page_queue_t* pq = mi_page_queue_of(page);
+  if (mi_likely(page->xblock_size <= MI_MAX_RETIRE_SIZE && !mi_page_is_in_full(page))) {
+    if (pq->last==page && pq->first==page) { // the only page in the queue?
+      mi_stat_counter_increase(_mi_stats_main.page_no_retire,1);
+      page->retire_expire = 1 + (page->xblock_size <= MI_SMALL_OBJ_SIZE_MAX ? MI_RETIRE_CYCLES : MI_RETIRE_CYCLES/4);      
+      mi_heap_t* heap = mi_page_heap(page);
+      mi_assert_internal(pq >= heap->pages);
+      const size_t index = pq - heap->pages;
+      mi_assert_internal(index < MI_BIN_FULL && index < MI_BIN_HUGE);
+      if (index < heap->page_retired_min) heap->page_retired_min = index;
+      if (index > heap->page_retired_max) heap->page_retired_max = index;
+      mi_assert_internal(mi_page_all_free(page));
+      return; // dont't free after all
+    }
+  }
+  _mi_page_free(page, pq, false);
+}
+
+// free retired pages: we don't need to look at the entire queues
+// since we only retire pages that are at the head position in a queue.
+void _mi_heap_collect_retired(mi_heap_t* heap, bool force) {
+  size_t min = MI_BIN_FULL;
+  size_t max = 0;
+  for(size_t bin = heap->page_retired_min; bin <= heap->page_retired_max; bin++) {
+    mi_page_queue_t* pq   = &heap->pages[bin];
+    mi_page_t*       page = pq->first;
+    if (page != NULL && page->retire_expire != 0) {
+      if (mi_page_all_free(page)) {
+        page->retire_expire--;
+        if (force || page->retire_expire == 0) {
+          _mi_page_free(pq->first, pq, force);
+        }
+        else {
+          // keep retired, update min/max
+          if (bin < min) min = bin;
+          if (bin > max) max = bin;
+        }
+      }
+      else {
+        page->retire_expire = 0;
+      }
+    }
+  }
+  heap->page_retired_min = min;
+  heap->page_retired_max = max;
+}
+
+
+/* -----------------------------------------------------------
+  Initialize the initial free list in a page.
+  In secure mode we initialize a randomized list by
+  alternating between slices.
+----------------------------------------------------------- */
+
+#define MI_MAX_SLICE_SHIFT  (6)   // at most 64 slices
+#define MI_MAX_SLICES       (1UL << MI_MAX_SLICE_SHIFT)
+#define MI_MIN_SLICES       (2)
+
+static void mi_page_free_list_extend_secure(mi_heap_t* const heap, mi_page_t* const page, const size_t bsize, const size_t extend, mi_stats_t* const stats) {
+  MI_UNUSED(stats);
+  #if (MI_SECURE<=2)
+  mi_assert_internal(page->free == NULL);
+  mi_assert_internal(page->local_free == NULL);
+  #endif
+  mi_assert_internal(page->capacity + extend <= page->reserved);
+  mi_assert_internal(bsize == mi_page_block_size(page));
+  void* const page_area = _mi_page_start(_mi_page_segment(page), page, NULL);
+
+  // initialize a randomized free list
+  // set up `slice_count` slices to alternate between
+  size_t shift = MI_MAX_SLICE_SHIFT;
+  while ((extend >> shift) == 0) {
+    shift--;
+  }
+  const size_t slice_count = (size_t)1U << shift;
+  const size_t slice_extend = extend / slice_count;
+  mi_assert_internal(slice_extend >= 1);
+  mi_block_t* blocks[MI_MAX_SLICES];   // current start of the slice
+  size_t      counts[MI_MAX_SLICES];   // available objects in the slice
+  for (size_t i = 0; i < slice_count; i++) {
+    blocks[i] = mi_page_block_at(page, page_area, bsize, page->capacity + i*slice_extend);
+    counts[i] = slice_extend;
+  }
+  counts[slice_count-1] += (extend % slice_count);  // final slice holds the modulus too (todo: distribute evenly?)
+
+  // and initialize the free list by randomly threading through them
+  // set up first element
+  const uintptr_t r = _mi_heap_random_next(heap);
+  size_t current = r % slice_count;
+  counts[current]--;
+  mi_block_t* const free_start = blocks[current];
+  // and iterate through the rest; use `random_shuffle` for performance
+  uintptr_t rnd = _mi_random_shuffle(r|1); // ensure not 0
+  for (size_t i = 1; i < extend; i++) {
+    // call random_shuffle only every INTPTR_SIZE rounds
+    const size_t round = i%MI_INTPTR_SIZE;
+    if (round == 0) rnd = _mi_random_shuffle(rnd);
+    // select a random next slice index
+    size_t next = ((rnd >> 8*round) & (slice_count-1));
+    while (counts[next]==0) {                            // ensure it still has space
+      next++;
+      if (next==slice_count) next = 0;
+    }
+    // and link the current block to it
+    counts[next]--;
+    mi_block_t* const block = blocks[current];
+    blocks[current] = (mi_block_t*)((uint8_t*)block + bsize);  // bump to the following block
+    mi_block_set_next(page, block, blocks[next]);   // and set next; note: we may have `current == next`
+    current = next;
+  }
+  // prepend to the free list (usually NULL)
+  mi_block_set_next(page, blocks[current], page->free);  // end of the list
+  page->free = free_start;
+}
+
+static mi_decl_noinline void mi_page_free_list_extend( mi_page_t* const page, const size_t bsize, const size_t extend, mi_stats_t* const stats)
+{
+  MI_UNUSED(stats);
+  #if (MI_SECURE <= 2)
+  mi_assert_internal(page->free == NULL);
+  mi_assert_internal(page->local_free == NULL);
+  #endif
+  mi_assert_internal(page->capacity + extend <= page->reserved);
+  mi_assert_internal(bsize == mi_page_block_size(page));
+  void* const page_area = _mi_page_start(_mi_page_segment(page), page, NULL );
+
+  mi_block_t* const start = mi_page_block_at(page, page_area, bsize, page->capacity);
+
+  // initialize a sequential free list
+  mi_block_t* const last = mi_page_block_at(page, page_area, bsize, page->capacity + extend - 1);
+  mi_block_t* block = start;
+  while(block <= last) {
+    mi_block_t* next = (mi_block_t*)((uint8_t*)block + bsize);
+    mi_block_set_next(page,block,next);
+    block = next;
+  }
+  // prepend to free list (usually `NULL`)
+  mi_block_set_next(page, last, page->free);
+  page->free = start;
+}
+
+/* -----------------------------------------------------------
+  Page initialize and extend the capacity
+----------------------------------------------------------- */
+
+#define MI_MAX_EXTEND_SIZE    (4*1024)      // heuristic, one OS page seems to work well.
+#if (MI_SECURE>0)
+#define MI_MIN_EXTEND         (8*MI_SECURE) // extend at least by this many
+#else
+#define MI_MIN_EXTEND         (1)
+#endif
+
+// Extend the capacity (up to reserved) by initializing a free list
+// We do at most `MI_MAX_EXTEND` to avoid touching too much memory
+// Note: we also experimented with "bump" allocation on the first
+// allocations but this did not speed up any benchmark (due to an
+// extra test in malloc? or cache effects?)
+static void mi_page_extend_free(mi_heap_t* heap, mi_page_t* page, mi_tld_t* tld) {
+  MI_UNUSED(tld); 
+  mi_assert_expensive(mi_page_is_valid_init(page));
+  #if (MI_SECURE<=2)
+  mi_assert(page->free == NULL);
+  mi_assert(page->local_free == NULL);
+  if (page->free != NULL) return;
+  #endif
+  if (page->capacity >= page->reserved) return;
+
+  size_t page_size;
+  _mi_page_start(_mi_page_segment(page), page, &page_size);
+  mi_stat_counter_increase(tld->stats.pages_extended, 1);
+
+  // calculate the extend count
+  const size_t bsize = (page->xblock_size < MI_HUGE_BLOCK_SIZE ? page->xblock_size : page_size);
+  size_t extend = page->reserved - page->capacity;
+  mi_assert_internal(extend > 0);
+
+  size_t max_extend = (bsize >= MI_MAX_EXTEND_SIZE ? MI_MIN_EXTEND : MI_MAX_EXTEND_SIZE/(uint32_t)bsize);
+  if (max_extend < MI_MIN_EXTEND) { max_extend = MI_MIN_EXTEND; }
+  mi_assert_internal(max_extend > 0);
+    
+  if (extend > max_extend) {
+    // ensure we don't touch memory beyond the page to reduce page commit.
+    // the `lean` benchmark tests this. Going from 1 to 8 increases rss by 50%.
+    extend = max_extend;
+  }
+
+  mi_assert_internal(extend > 0 && extend + page->capacity <= page->reserved);
+  mi_assert_internal(extend < (1UL<<16));
+
+  // and append the extend the free list
+  if (extend < MI_MIN_SLICES || MI_SECURE==0) { //!mi_option_is_enabled(mi_option_secure)) {
+    mi_page_free_list_extend(page, bsize, extend, &tld->stats );
+  }
+  else {
+    mi_page_free_list_extend_secure(heap, page, bsize, extend, &tld->stats);
+  }
+  // enable the new free list
+  page->capacity += (uint16_t)extend;
+  mi_stat_increase(tld->stats.page_committed, extend * bsize);
+
+  // extension into zero initialized memory preserves the zero'd free list
+  if (!page->is_zero_init) {
+    page->is_zero = false;
+  }
+  mi_assert_expensive(mi_page_is_valid_init(page));
+}
+
+// Initialize a fresh page
+static void mi_page_init(mi_heap_t* heap, mi_page_t* page, size_t block_size, mi_tld_t* tld) {
+  mi_assert(page != NULL);
+  mi_segment_t* segment = _mi_page_segment(page);
+  mi_assert(segment != NULL);
+  mi_assert_internal(block_size > 0);
+  // set fields
+  mi_page_set_heap(page, heap);
+  page->xblock_size = (block_size < MI_HUGE_BLOCK_SIZE ? (uint32_t)block_size : MI_HUGE_BLOCK_SIZE); // initialize before _mi_segment_page_start
+  size_t page_size;
+  _mi_segment_page_start(segment, page, &page_size);
+  mi_assert_internal(mi_page_block_size(page) <= page_size);
+  mi_assert_internal(page_size <= page->slice_count*MI_SEGMENT_SLICE_SIZE);
+  mi_assert_internal(page_size / block_size < (1L<<16));
+  page->reserved = (uint16_t)(page_size / block_size);
+  #ifdef MI_ENCODE_FREELIST
+  page->keys[0] = _mi_heap_random_next(heap);
+  page->keys[1] = _mi_heap_random_next(heap);
+  #endif
+  #if MI_DEBUG > 0
+  page->is_zero = false; // ensure in debug mode we initialize with MI_DEBUG_UNINIT, see issue #501
+  #else
+  page->is_zero = page->is_zero_init;
+  #endif
+
+  mi_assert_internal(page->is_committed);
+  mi_assert_internal(!page->is_reset);
+  mi_assert_internal(page->capacity == 0);
+  mi_assert_internal(page->free == NULL);
+  mi_assert_internal(page->used == 0);
+  mi_assert_internal(page->xthread_free == 0);
+  mi_assert_internal(page->next == NULL);
+  mi_assert_internal(page->prev == NULL);
+  mi_assert_internal(page->retire_expire == 0);
+  mi_assert_internal(!mi_page_has_aligned(page));
+  #if (MI_ENCODE_FREELIST)
+  mi_assert_internal(page->keys[0] != 0);
+  mi_assert_internal(page->keys[1] != 0);
+  #endif
+  mi_assert_expensive(mi_page_is_valid_init(page));
+
+  // initialize an initial free list
+  mi_page_extend_free(heap,page,tld);
+  mi_assert(mi_page_immediate_available(page));
+}
+
+
+/* -----------------------------------------------------------
+  Find pages with free blocks
+-------------------------------------------------------------*/
+
+// Find a page with free blocks of `page->block_size`.
+static mi_page_t* mi_page_queue_find_free_ex(mi_heap_t* heap, mi_page_queue_t* pq, bool first_try)
+{
+  // search through the pages in "next fit" order
+  size_t count = 0;
+  mi_page_t* page = pq->first;
+  while (page != NULL)
+  {
+    mi_page_t* next = page->next; // remember next
+    count++;
+
+    // 0. collect freed blocks by us and other threads
+    _mi_page_free_collect(page, false);
+
+    // 1. if the page contains free blocks, we are done
+    if (mi_page_immediate_available(page)) {
+      break;  // pick this one
+    }
+
+    // 2. Try to extend
+    if (page->capacity < page->reserved) {
+      mi_page_extend_free(heap, page, heap->tld);
+      mi_assert_internal(mi_page_immediate_available(page));
+      break;
+    }
+
+    // 3. If the page is completely full, move it to the `mi_pages_full`
+    // queue so we don't visit long-lived pages too often.
+    mi_assert_internal(!mi_page_is_in_full(page) && !mi_page_immediate_available(page));
+    mi_page_to_full(page, pq);
+
+    page = next;
+  } // for each page
+
+  mi_stat_counter_increase(heap->tld->stats.searches, count);
+
+  if (page == NULL) {
+    _mi_heap_collect_retired(heap, false); // perhaps make a page available?
+    page = mi_page_fresh(heap, pq);
+    if (page == NULL && first_try) {
+      // out-of-memory _or_ an abandoned page with free blocks was reclaimed, try once again
+      page = mi_page_queue_find_free_ex(heap, pq, false);      
+    }
+  }
+  else {
+    mi_assert(pq->first == page);
+    page->retire_expire = 0;
+  }
+  mi_assert_internal(page == NULL || mi_page_immediate_available(page));
+  return page;
+}
+
+
+
+// Find a page with free blocks of `size`.
+static inline mi_page_t* mi_find_free_page(mi_heap_t* heap, size_t size) {
+  mi_page_queue_t* pq = mi_page_queue(heap,size);
+  mi_page_t* page = pq->first;
+  if (page != NULL) {
+   #if (MI_SECURE>=3) // in secure mode, we extend half the time to increase randomness      
+    if (page->capacity < page->reserved && ((_mi_heap_random_next(heap) & 1) == 1)) {
+      mi_page_extend_free(heap, page, heap->tld);
+      mi_assert_internal(mi_page_immediate_available(page));
+    }
+    else 
+   #endif
+    {
+      _mi_page_free_collect(page,false);
+    }
+    
+    if (mi_page_immediate_available(page)) {
+      page->retire_expire = 0;
+      return page; // fast path
+    }
+  }
+  return mi_page_queue_find_free_ex(heap, pq, true);
+}
+
+
+/* -----------------------------------------------------------
+  Users can register a deferred free function called
+  when the `free` list is empty. Since the `local_free`
+  is separate this is deterministically called after
+  a certain number of allocations.
+----------------------------------------------------------- */
+
+static mi_deferred_free_fun* volatile deferred_free = NULL;
+static _Atomic(void*) deferred_arg; // = NULL
+
+void _mi_deferred_free(mi_heap_t* heap, bool force) {
+  heap->tld->heartbeat++;
+  if (deferred_free != NULL && !heap->tld->recurse) {
+    heap->tld->recurse = true;
+    deferred_free(force, heap->tld->heartbeat, mi_atomic_load_ptr_relaxed(void,&deferred_arg));
+    heap->tld->recurse = false;
+  }
+}
+
+void mi_register_deferred_free(mi_deferred_free_fun* fn, void* arg) mi_attr_noexcept {
+  deferred_free = fn;
+  mi_atomic_store_ptr_release(void,&deferred_arg, arg);
+}
+
+
+/* -----------------------------------------------------------
+  General allocation
+----------------------------------------------------------- */
+
+// Large and huge page allocation.
+// Huge pages are allocated directly without being in a queue.
+// Because huge pages contain just one block, and the segment contains
+// just that page, we always treat them as abandoned and any thread
+// that frees the block can free the whole page and segment directly.
+static mi_page_t* mi_large_huge_page_alloc(mi_heap_t* heap, size_t size) {
+  size_t block_size = _mi_os_good_alloc_size(size);
+  mi_assert_internal(mi_bin(block_size) == MI_BIN_HUGE);
+  bool is_huge = (block_size > MI_LARGE_OBJ_SIZE_MAX);
+  mi_page_queue_t* pq = (is_huge ? NULL : mi_page_queue(heap, block_size));
+  mi_page_t* page = mi_page_fresh_alloc(heap, pq, block_size);
+  if (page != NULL) {
+    const size_t bsize = mi_page_block_size(page);  // note: not `mi_page_usable_block_size` as `size` includes padding
+    mi_assert_internal(mi_page_immediate_available(page));
+    mi_assert_internal(bsize >= size);
+
+    if (pq == NULL) {
+      // huge pages are directly abandoned
+      mi_assert_internal(_mi_page_segment(page)->kind == MI_SEGMENT_HUGE);
+      mi_assert_internal(_mi_page_segment(page)->used==1);
+      mi_assert_internal(_mi_page_segment(page)->thread_id==0); // abandoned, not in the huge queue
+      mi_page_set_heap(page, NULL);
+    }
+    else {
+      mi_assert_internal(_mi_page_segment(page)->kind != MI_SEGMENT_HUGE);
+    }
+    if (bsize <= MI_LARGE_OBJ_SIZE_MAX) {
+      _mi_stat_increase(&heap->tld->stats.large, bsize);
+      _mi_stat_counter_increase(&heap->tld->stats.large_count, 1);
+    }
+    else {
+      _mi_stat_increase(&heap->tld->stats.huge, bsize);
+      _mi_stat_counter_increase(&heap->tld->stats.huge_count, 1);
+    }
+  }
+  return page;
+}
+
+
+// Allocate a page
+// Note: in debug mode the size includes MI_PADDING_SIZE and might have overflowed.
+static mi_page_t* mi_find_page(mi_heap_t* heap, size_t size) mi_attr_noexcept {
+  // huge allocation?
+  const size_t req_size = size - MI_PADDING_SIZE;  // correct for padding_size in case of an overflow on `size`  
+  if (mi_unlikely(req_size > (MI_MEDIUM_OBJ_SIZE_MAX - MI_PADDING_SIZE) )) {
+    if (mi_unlikely(req_size > PTRDIFF_MAX)) {  // we don't allocate more than PTRDIFF_MAX (see <https://sourceware.org/ml/libc-announce/2019/msg00001.html>)
+      _mi_error_message(EOVERFLOW, "allocation request is too large (%zu bytes)\n", req_size);
+      return NULL;
+    }
+    else {
+      return mi_large_huge_page_alloc(heap,size);
+    }
+  }
+  else {
+    // otherwise find a page with free blocks in our size segregated queues
+    mi_assert_internal(size >= MI_PADDING_SIZE);
+    return mi_find_free_page(heap, size);
+  }
+}
+
+// Generic allocation routine if the fast path (`alloc.c:mi_page_malloc`) does not succeed.
+// Note: in debug mode the size includes MI_PADDING_SIZE and might have overflowed.
+void* _mi_malloc_generic(mi_heap_t* heap, size_t size) mi_attr_noexcept
+{
+  mi_assert_internal(heap != NULL);
+
+  // initialize if necessary
+  if (mi_unlikely(!mi_heap_is_initialized(heap))) {
+    mi_thread_init(); // calls `_mi_heap_init` in turn
+    heap = mi_get_default_heap();
+    if (mi_unlikely(!mi_heap_is_initialized(heap))) { return NULL; }
+  }
+  mi_assert_internal(mi_heap_is_initialized(heap));
+
+  // call potential deferred free routines
+  _mi_deferred_free(heap, false);
+
+  // free delayed frees from other threads
+  _mi_heap_delayed_free(heap);
+
+  // find (or allocate) a page of the right size
+  mi_page_t* page = mi_find_page(heap, size);
+  if (mi_unlikely(page == NULL)) { // first time out of memory, try to collect and retry the allocation once more
+    mi_heap_collect(heap, true /* force */);
+    page = mi_find_page(heap, size);
+  }
+
+  if (mi_unlikely(page == NULL)) { // out of memory
+    const size_t req_size = size - MI_PADDING_SIZE;  // correct for padding_size in case of an overflow on `size`  
+    _mi_error_message(ENOMEM, "unable to allocate memory (%zu bytes)\n", req_size);
+    return NULL;
+  }
+
+  mi_assert_internal(mi_page_immediate_available(page));
+  mi_assert_internal(mi_page_block_size(page) >= size);
+
+  // and try again, this time succeeding! (i.e. this should never recurse)
+  return _mi_page_malloc(heap, page, size);
+}
diff --git a/Objects/mimalloc/random.c b/Objects/mimalloc/random.c
new file mode 100644
index 0000000000000..0b44c8b97e169
--- /dev/null
+++ b/Objects/mimalloc/random.c
@@ -0,0 +1,366 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2019-2021, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+#ifndef _DEFAULT_SOURCE
+#define _DEFAULT_SOURCE   // for syscall() on Linux
+#endif
+
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+
+#include <string.h> // memset
+
+/* ----------------------------------------------------------------------------
+We use our own PRNG to keep predictable performance of random number generation
+and to avoid implementations that use a lock. We only use the OS provided
+random source to initialize the initial seeds. Since we do not need ultimate
+performance but we do rely on the security (for secret cookies in secure mode)
+we use a cryptographically secure generator (chacha20).
+-----------------------------------------------------------------------------*/
+
+#define MI_CHACHA_ROUNDS (20)   // perhaps use 12 for better performance?
+
+
+/* ----------------------------------------------------------------------------
+Chacha20 implementation as the original algorithm with a 64-bit nonce
+and counter: https://en.wikipedia.org/wiki/Salsa20
+The input matrix has sixteen 32-bit values:
+Position  0 to  3: constant key
+Position  4 to 11: the key
+Position 12 to 13: the counter.
+Position 14 to 15: the nonce.
+
+The implementation uses regular C code which compiles very well on modern compilers.
+(gcc x64 has no register spills, and clang 6+ uses SSE instructions)
+-----------------------------------------------------------------------------*/
+
+static inline uint32_t rotl(uint32_t x, uint32_t shift) {
+  return (x << shift) | (x >> (32 - shift));
+}
+
+static inline void qround(uint32_t x[16], size_t a, size_t b, size_t c, size_t d) {
+  x[a] += x[b]; x[d] = rotl(x[d] ^ x[a], 16);
+  x[c] += x[d]; x[b] = rotl(x[b] ^ x[c], 12);
+  x[a] += x[b]; x[d] = rotl(x[d] ^ x[a], 8);
+  x[c] += x[d]; x[b] = rotl(x[b] ^ x[c], 7);
+}
+
+static void chacha_block(mi_random_ctx_t* ctx)
+{
+  // scramble into `x`
+  uint32_t x[16];
+  for (size_t i = 0; i < 16; i++) {
+    x[i] = ctx->input[i];
+  }
+  for (size_t i = 0; i < MI_CHACHA_ROUNDS; i += 2) {
+    qround(x, 0, 4,  8, 12);
+    qround(x, 1, 5,  9, 13);
+    qround(x, 2, 6, 10, 14);
+    qround(x, 3, 7, 11, 15);
+    qround(x, 0, 5, 10, 15);
+    qround(x, 1, 6, 11, 12);
+    qround(x, 2, 7,  8, 13);
+    qround(x, 3, 4,  9, 14);
+  }
+
+  // add scrambled data to the initial state
+  for (size_t i = 0; i < 16; i++) {
+    ctx->output[i] = x[i] + ctx->input[i];
+  }
+  ctx->output_available = 16;
+
+  // increment the counter for the next round
+  ctx->input[12] += 1;
+  if (ctx->input[12] == 0) {
+    ctx->input[13] += 1;
+    if (ctx->input[13] == 0) {  // and keep increasing into the nonce
+      ctx->input[14] += 1;
+    }
+  }
+}
+
+static uint32_t chacha_next32(mi_random_ctx_t* ctx) {
+  if (ctx->output_available <= 0) {
+    chacha_block(ctx);
+    ctx->output_available = 16; // (assign again to suppress static analysis warning)
+  }
+  const uint32_t x = ctx->output[16 - ctx->output_available];
+  ctx->output[16 - ctx->output_available] = 0; // reset once the data is handed out
+  ctx->output_available--;
+  return x;
+}
+
+static inline uint32_t read32(const uint8_t* p, size_t idx32) {
+  const size_t i = 4*idx32;
+  return ((uint32_t)p[i+0] | (uint32_t)p[i+1] << 8 | (uint32_t)p[i+2] << 16 | (uint32_t)p[i+3] << 24);
+}
+
+static void chacha_init(mi_random_ctx_t* ctx, const uint8_t key[32], uint64_t nonce)
+{
+  // since we only use chacha for randomness (and not encryption) we
+  // do not _need_ to read 32-bit values as little endian but we do anyways
+  // just for being compatible :-)
+  memset(ctx, 0, sizeof(*ctx));
+  for (size_t i = 0; i < 4; i++) {
+    const uint8_t* sigma = (uint8_t*)"expand 32-byte k";
+    ctx->input[i] = read32(sigma,i);
+  }
+  for (size_t i = 0; i < 8; i++) {
+    ctx->input[i + 4] = read32(key,i);
+  }
+  ctx->input[12] = 0;
+  ctx->input[13] = 0;
+  ctx->input[14] = (uint32_t)nonce;
+  ctx->input[15] = (uint32_t)(nonce >> 32);
+}
+
+static void chacha_split(mi_random_ctx_t* ctx, uint64_t nonce, mi_random_ctx_t* ctx_new) {
+  memset(ctx_new, 0, sizeof(*ctx_new));
+  _mi_memcpy(ctx_new->input, ctx->input, sizeof(ctx_new->input));
+  ctx_new->input[12] = 0;
+  ctx_new->input[13] = 0;
+  ctx_new->input[14] = (uint32_t)nonce;
+  ctx_new->input[15] = (uint32_t)(nonce >> 32);
+  mi_assert_internal(ctx->input[14] != ctx_new->input[14] || ctx->input[15] != ctx_new->input[15]); // do not reuse nonces!
+  chacha_block(ctx_new);
+}
+
+
+/* ----------------------------------------------------------------------------
+Random interface
+-----------------------------------------------------------------------------*/
+
+#if MI_DEBUG>1
+static bool mi_random_is_initialized(mi_random_ctx_t* ctx) {
+  return (ctx != NULL && ctx->input[0] != 0);
+}
+#endif
+
+void _mi_random_split(mi_random_ctx_t* ctx, mi_random_ctx_t* ctx_new) {
+  mi_assert_internal(mi_random_is_initialized(ctx));
+  mi_assert_internal(ctx != ctx_new);
+  chacha_split(ctx, (uintptr_t)ctx_new /*nonce*/, ctx_new);
+}
+
+uintptr_t _mi_random_next(mi_random_ctx_t* ctx) {
+  mi_assert_internal(mi_random_is_initialized(ctx));
+  #if MI_INTPTR_SIZE <= 4
+    return chacha_next32(ctx);
+  #elif MI_INTPTR_SIZE == 8
+    return (((uintptr_t)chacha_next32(ctx) << 32) | chacha_next32(ctx));
+  #else
+  # error "define mi_random_next for this platform"
+  #endif
+}
+
+
+/* ----------------------------------------------------------------------------
+To initialize a fresh random context we rely on the OS:
+- Windows     : BCryptGenRandom (or RtlGenRandom)
+- macOS       : CCRandomGenerateBytes, arc4random_buf
+- bsd,wasi    : arc4random_buf
+- Linux       : getrandom,/dev/urandom
+If we cannot get good randomness, we fall back to weak randomness based on a timer and ASLR.
+-----------------------------------------------------------------------------*/
+
+#if defined(_WIN32)
+
+#if !defined(MI_USE_RTLGENRANDOM)
+// We prefer to use BCryptGenRandom instead of RtlGenRandom but it can lead to a deadlock 
+// under the VS debugger when using dynamic overriding.
+#pragma comment (lib,"bcrypt.lib")
+#include <bcrypt.h>
+static bool os_random_buf(void* buf, size_t buf_len) {
+  return (BCryptGenRandom(NULL, (PUCHAR)buf, (ULONG)buf_len, BCRYPT_USE_SYSTEM_PREFERRED_RNG) >= 0);
+}
+#else
+// Use (unofficial) RtlGenRandom
+#pragma comment (lib,"advapi32.lib")
+#define RtlGenRandom  SystemFunction036
+#ifdef __cplusplus
+extern "C" {
+#endif
+BOOLEAN NTAPI RtlGenRandom(PVOID RandomBuffer, ULONG RandomBufferLength);
+#ifdef __cplusplus
+}
+#endif
+static bool os_random_buf(void* buf, size_t buf_len) {
+  return (RtlGenRandom(buf, (ULONG)buf_len) != 0);
+}
+#endif
+
+#elif defined(__APPLE__)
+#include <AvailabilityMacros.h>
+#if defined(MAC_OS_X_VERSION_10_10) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_10
+#include <CommonCrypto/CommonRandom.h>
+#endif
+static bool os_random_buf(void* buf, size_t buf_len) {
+  #if defined(MAC_OS_X_VERSION_10_15) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_15
+    // We prefere CCRandomGenerateBytes as it returns an error code while arc4random_buf
+    // may fail silently on macOS. See PR #390, and <https://opensource.apple.com/source/Libc/Libc-1439.40.11/gen/FreeBSD/arc4random.c.auto.html>      
+    return (CCRandomGenerateBytes(buf, buf_len) == kCCSuccess);
+  #else
+    // fall back on older macOS
+    arc4random_buf(buf, buf_len);
+    return true;
+  #endif
+}
+
+#elif defined(__ANDROID__) || defined(__DragonFly__) || \
+      defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__) || \
+      defined(__sun) // todo: what to use with __wasi__?
+#include <stdlib.h>
+static bool os_random_buf(void* buf, size_t buf_len) {
+  arc4random_buf(buf, buf_len);
+  return true;
+}
+#elif defined(__linux__) || defined(__HAIKU__)
+#if defined(__linux__)
+#include <sys/syscall.h>
+#endif
+#include <unistd.h>
+#include <sys/types.h>
+#include <sys/stat.h>
+#include <fcntl.h>
+#include <errno.h>
+static bool os_random_buf(void* buf, size_t buf_len) {
+  // Modern Linux provides `getrandom` but different distributions either use `sys/random.h` or `linux/random.h`
+  // and for the latter the actual `getrandom` call is not always defined.
+  // (see <https://stackoverflow.com/questions/45237324/why-doesnt-getrandom-compile>)
+  // We therefore use a syscall directly and fall back dynamically to /dev/urandom when needed.
+#ifdef SYS_getrandom
+  #ifndef GRND_NONBLOCK
+  #define GRND_NONBLOCK (1)
+  #endif
+  static _Atomic(uintptr_t) no_getrandom; // = 0
+  if (mi_atomic_load_acquire(&no_getrandom)==0) {
+    ssize_t ret = syscall(SYS_getrandom, buf, buf_len, GRND_NONBLOCK);
+    if (ret >= 0) return (buf_len == (size_t)ret);
+    if (errno != ENOSYS) return false;
+    mi_atomic_store_release(&no_getrandom, 1UL); // don't call again, and fall back to /dev/urandom
+  }
+#endif
+  int flags = O_RDONLY;
+  #if defined(O_CLOEXEC)
+  flags |= O_CLOEXEC;
+  #endif
+  int fd = open("/dev/urandom", flags, 0);
+  if (fd < 0) return false;
+  size_t count = 0;
+  while(count < buf_len) {
+    ssize_t ret = read(fd, (char*)buf + count, buf_len - count);
+    if (ret<=0) {
+      if (errno!=EAGAIN && errno!=EINTR) break;
+    }
+    else {
+      count += ret;
+    }
+  }
+  close(fd);
+  return (count==buf_len);
+}
+#else
+static bool os_random_buf(void* buf, size_t buf_len) {
+  return false;
+}
+#endif
+
+#if defined(_WIN32)
+#include <windows.h>
+#elif defined(__APPLE__)
+#include <mach/mach_time.h>
+#else
+#include <time.h>
+#endif
+
+uintptr_t _mi_os_random_weak(uintptr_t extra_seed) {
+  uintptr_t x = (uintptr_t)&_mi_os_random_weak ^ extra_seed; // ASLR makes the address random
+  
+  #if defined(_WIN32)
+    LARGE_INTEGER pcount;
+    QueryPerformanceCounter(&pcount);
+    x ^= (uintptr_t)(pcount.QuadPart);
+  #elif defined(__APPLE__)
+    x ^= (uintptr_t)mach_absolute_time();
+  #else
+    struct timespec time;
+    clock_gettime(CLOCK_MONOTONIC, &time);
+    x ^= (uintptr_t)time.tv_sec;
+    x ^= (uintptr_t)time.tv_nsec;
+  #endif
+  // and do a few randomization steps
+  uintptr_t max = ((x ^ (x >> 17)) & 0x0F) + 1;
+  for (uintptr_t i = 0; i < max; i++) {
+    x = _mi_random_shuffle(x);
+  }
+  mi_assert_internal(x != 0);
+  return x;
+}
+
+void _mi_random_init(mi_random_ctx_t* ctx) {
+  uint8_t key[32];
+  if (!os_random_buf(key, sizeof(key))) {
+    // if we fail to get random data from the OS, we fall back to a
+    // weak random source based on the current time
+    #if !defined(__wasi__)
+    _mi_warning_message("unable to use secure randomness\n");
+    #endif
+    uintptr_t x = _mi_os_random_weak(0);
+    for (size_t i = 0; i < 8; i++) {  // key is eight 32-bit words.
+      x = _mi_random_shuffle(x);
+      ((uint32_t*)key)[i] = (uint32_t)x;
+    }
+  }
+  chacha_init(ctx, key, (uintptr_t)ctx /*nonce*/ );
+}
+
+/* --------------------------------------------------------
+test vectors from <https://tools.ietf.org/html/rfc8439>
+----------------------------------------------------------- */
+/*
+static bool array_equals(uint32_t* x, uint32_t* y, size_t n) {
+  for (size_t i = 0; i < n; i++) {
+    if (x[i] != y[i]) return false;
+  }
+  return true;
+}
+static void chacha_test(void)
+{
+  uint32_t x[4] = { 0x11111111, 0x01020304, 0x9b8d6f43, 0x01234567 };
+  uint32_t x_out[4] = { 0xea2a92f4, 0xcb1cf8ce, 0x4581472e, 0x5881c4bb };
+  qround(x, 0, 1, 2, 3);
+  mi_assert_internal(array_equals(x, x_out, 4));
+
+  uint32_t y[16] = {
+       0x879531e0,  0xc5ecf37d,  0x516461b1,  0xc9a62f8a,
+       0x44c20ef3,  0x3390af7f,  0xd9fc690b,  0x2a5f714c,
+       0x53372767,  0xb00a5631,  0x974c541a,  0x359e9963,
+       0x5c971061,  0x3d631689,  0x2098d9d6,  0x91dbd320 };
+  uint32_t y_out[16] = {
+       0x879531e0,  0xc5ecf37d,  0xbdb886dc,  0xc9a62f8a,
+       0x44c20ef3,  0x3390af7f,  0xd9fc690b,  0xcfacafd2,
+       0xe46bea80,  0xb00a5631,  0x974c541a,  0x359e9963,
+       0x5c971061,  0xccc07c79,  0x2098d9d6,  0x91dbd320 };
+  qround(y, 2, 7, 8, 13);
+  mi_assert_internal(array_equals(y, y_out, 16));
+
+  mi_random_ctx_t r = {
+    { 0x61707865, 0x3320646e, 0x79622d32, 0x6b206574,
+      0x03020100, 0x07060504, 0x0b0a0908, 0x0f0e0d0c,
+      0x13121110, 0x17161514, 0x1b1a1918, 0x1f1e1d1c,
+      0x00000001, 0x09000000, 0x4a000000, 0x00000000 },
+    {0},
+    0
+  };
+  uint32_t r_out[16] = {
+       0xe4e7f110, 0x15593bd1, 0x1fdd0f50, 0xc47120a3,
+       0xc7f4d1c7, 0x0368c033, 0x9aaa2204, 0x4e6cd4c3,
+       0x466482d2, 0x09aa9f07, 0x05d7c214, 0xa2028bd9,
+       0xd19c12b5, 0xb94e16de, 0xe883d0cb, 0x4e3c50a2 };
+  chacha_block(&r);
+  mi_assert_internal(array_equals(r.output, r_out, 16));
+}
+*/
diff --git a/Objects/mimalloc/region.c b/Objects/mimalloc/region.c
new file mode 100644
index 0000000000000..2d73025e09d0b
--- /dev/null
+++ b/Objects/mimalloc/region.c
@@ -0,0 +1,505 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2019-2020, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+
+/* ----------------------------------------------------------------------------
+This implements a layer between the raw OS memory (VirtualAlloc/mmap/sbrk/..)
+and the segment and huge object allocation by mimalloc. There may be multiple
+implementations of this (one could be the identity going directly to the OS,
+another could be a simple cache etc), but the current one uses large "regions".
+In contrast to the rest of mimalloc, the "regions" are shared between threads and
+need to be accessed using atomic operations.
+We need this memory layer between the raw OS calls because of:
+1. on `sbrk` like systems (like WebAssembly) we need our own memory maps in order
+   to reuse memory effectively.
+2. It turns out that for large objects, between 1MiB and 32MiB (?), the cost of
+   an OS allocation/free is still (much) too expensive relative to the accesses 
+   in that object :-( (`malloc-large` tests this). This means we need a cheaper 
+   way to reuse memory.
+3. This layer allows for NUMA aware allocation.
+
+Possible issues:
+- (2) can potentially be addressed too with a small cache per thread which is much
+  simpler. Generally though that requires shrinking of huge pages, and may overuse
+  memory per thread. (and is not compatible with `sbrk`).
+- Since the current regions are per-process, we need atomic operations to
+  claim blocks which may be contended
+- In the worst case, we need to search the whole region map (16KiB for 256GiB)
+  linearly. At what point will direct OS calls be faster? Is there a way to
+  do this better without adding too much complexity?
+-----------------------------------------------------------------------------*/
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+#include "mimalloc-atomic.h"
+
+#include <string.h>  // memset
+
+#include "bitmap.h"
+
+// Internal raw OS interface
+size_t  _mi_os_large_page_size(void);
+bool    _mi_os_protect(void* addr, size_t size);
+bool    _mi_os_unprotect(void* addr, size_t size);
+bool    _mi_os_commit(void* p, size_t size, bool* is_zero, mi_stats_t* stats);
+bool    _mi_os_decommit(void* p, size_t size, mi_stats_t* stats);
+bool    _mi_os_reset(void* p, size_t size, mi_stats_t* stats);
+bool    _mi_os_unreset(void* p, size_t size, bool* is_zero, mi_stats_t* stats);
+
+// arena.c
+void    _mi_arena_free(void* p, size_t size, size_t memid, bool all_committed, mi_stats_t* stats);
+void*   _mi_arena_alloc(size_t size, bool* commit, bool* large, bool* is_pinned, bool* is_zero, size_t* memid, mi_os_tld_t* tld);
+void*   _mi_arena_alloc_aligned(size_t size, size_t alignment, bool* commit, bool* large, bool* is_pinned, bool* is_zero, size_t* memid, mi_os_tld_t* tld);
+
+
+
+// Constants
+#if (MI_INTPTR_SIZE==8)
+#define MI_HEAP_REGION_MAX_SIZE    (256 * MI_GiB)  // 64KiB for the region map 
+#elif (MI_INTPTR_SIZE==4)
+#define MI_HEAP_REGION_MAX_SIZE    (3 * MI_GiB)    // ~ KiB for the region map
+#else
+#error "define the maximum heap space allowed for regions on this platform"
+#endif
+
+#define MI_SEGMENT_ALIGN          MI_SEGMENT_SIZE
+
+#define MI_REGION_MAX_BLOCKS      MI_BITMAP_FIELD_BITS
+#define MI_REGION_SIZE            (MI_SEGMENT_SIZE * MI_BITMAP_FIELD_BITS)    // 256MiB  (64MiB on 32 bits)
+#define MI_REGION_MAX             (MI_HEAP_REGION_MAX_SIZE / MI_REGION_SIZE)  // 1024  (48 on 32 bits)
+#define MI_REGION_MAX_OBJ_BLOCKS  (MI_REGION_MAX_BLOCKS/4)                    // 64MiB
+#define MI_REGION_MAX_OBJ_SIZE    (MI_REGION_MAX_OBJ_BLOCKS*MI_SEGMENT_SIZE)  
+
+// Region info 
+typedef union mi_region_info_u {
+  size_t value;      
+  struct {
+    bool  valid;        // initialized?
+    bool  is_large:1;   // allocated in fixed large/huge OS pages
+    bool  is_pinned:1;  // pinned memory cannot be decommitted
+    short numa_node;    // the associated NUMA node (where -1 means no associated node)
+  } x;
+} mi_region_info_t;
+
+
+// A region owns a chunk of REGION_SIZE (256MiB) (virtual) memory with
+// a bit map with one bit per MI_SEGMENT_SIZE (4MiB) block.
+typedef struct mem_region_s {
+  _Atomic(size_t)           info;        // mi_region_info_t.value
+  _Atomic(void*)            start;       // start of the memory area 
+  mi_bitmap_field_t         in_use;      // bit per in-use block
+  mi_bitmap_field_t         dirty;       // track if non-zero per block
+  mi_bitmap_field_t         commit;      // track if committed per block
+  mi_bitmap_field_t         reset;       // track if reset per block
+  _Atomic(size_t)           arena_memid; // if allocated from a (huge page) arena
+  _Atomic(size_t)           padding;     // round to 8 fields (needs to be atomic for msvc, see issue #508)
+} mem_region_t;
+
+// The region map
+static mem_region_t regions[MI_REGION_MAX];
+
+// Allocated regions
+static _Atomic(size_t) regions_count; // = 0;        
+
+
+/* ----------------------------------------------------------------------------
+Utility functions
+-----------------------------------------------------------------------------*/
+
+// Blocks (of 4MiB) needed for the given size.
+static size_t mi_region_block_count(size_t size) {
+  return _mi_divide_up(size, MI_SEGMENT_SIZE);
+}
+
+/*
+// Return a rounded commit/reset size such that we don't fragment large OS pages into small ones.
+static size_t mi_good_commit_size(size_t size) {
+  if (size > (SIZE_MAX - _mi_os_large_page_size())) return size;
+  return _mi_align_up(size, _mi_os_large_page_size());
+}
+*/
+
+// Return if a pointer points into a region reserved by us.
+bool mi_is_in_heap_region(const void* p) mi_attr_noexcept {
+  if (p==NULL) return false;
+  size_t count = mi_atomic_load_relaxed(&regions_count);
+  for (size_t i = 0; i < count; i++) {
+    uint8_t* start = (uint8_t*)mi_atomic_load_ptr_relaxed(uint8_t, &regions[i].start);
+    if (start != NULL && (uint8_t*)p >= start && (uint8_t*)p < start + MI_REGION_SIZE) return true;
+  }
+  return false;
+}
+
+
+static void* mi_region_blocks_start(const mem_region_t* region, mi_bitmap_index_t bit_idx) {
+  uint8_t* start = (uint8_t*)mi_atomic_load_ptr_acquire(uint8_t, &((mem_region_t*)region)->start);
+  mi_assert_internal(start != NULL);
+  return (start + (bit_idx * MI_SEGMENT_SIZE));  
+}
+
+static size_t mi_memid_create(mem_region_t* region, mi_bitmap_index_t bit_idx) {
+  mi_assert_internal(bit_idx < MI_BITMAP_FIELD_BITS);
+  size_t idx = region - regions;
+  mi_assert_internal(&regions[idx] == region);
+  return (idx*MI_BITMAP_FIELD_BITS + bit_idx)<<1;
+}
+
+static size_t mi_memid_create_from_arena(size_t arena_memid) {
+  return (arena_memid << 1) | 1;
+}
+
+
+static bool mi_memid_is_arena(size_t id, mem_region_t** region, mi_bitmap_index_t* bit_idx, size_t* arena_memid) {
+  if ((id&1)==1) {
+    if (arena_memid != NULL) *arena_memid = (id>>1);
+    return true;
+  }
+  else {
+    size_t idx = (id >> 1) / MI_BITMAP_FIELD_BITS;
+    *bit_idx   = (mi_bitmap_index_t)(id>>1) % MI_BITMAP_FIELD_BITS;
+    *region    = &regions[idx];
+    return false;
+  }
+}
+
+
+/* ----------------------------------------------------------------------------
+  Allocate a region is allocated from the OS (or an arena)
+-----------------------------------------------------------------------------*/
+
+static bool mi_region_try_alloc_os(size_t blocks, bool commit, bool allow_large, mem_region_t** region, mi_bitmap_index_t* bit_idx, mi_os_tld_t* tld)
+{
+  // not out of regions yet?
+  if (mi_atomic_load_relaxed(&regions_count) >= MI_REGION_MAX - 1) return false;
+
+  // try to allocate a fresh region from the OS
+  bool region_commit = (commit && mi_option_is_enabled(mi_option_eager_region_commit));
+  bool region_large = (commit && allow_large);
+  bool is_zero = false;
+  bool is_pinned = false;
+  size_t arena_memid = 0;
+  void* const start = _mi_arena_alloc_aligned(MI_REGION_SIZE, MI_SEGMENT_ALIGN, &region_commit, &region_large, &is_pinned, &is_zero, &arena_memid, tld);
+  if (start == NULL) return false;
+  mi_assert_internal(!(region_large && !allow_large));
+  mi_assert_internal(!region_large || region_commit);
+
+  // claim a fresh slot
+  const size_t idx = mi_atomic_increment_acq_rel(&regions_count);
+  if (idx >= MI_REGION_MAX) {
+    mi_atomic_decrement_acq_rel(&regions_count);
+    _mi_arena_free(start, MI_REGION_SIZE, arena_memid, region_commit, tld->stats);
+    _mi_warning_message("maximum regions used: %zu GiB (perhaps recompile with a larger setting for MI_HEAP_REGION_MAX_SIZE)", _mi_divide_up(MI_HEAP_REGION_MAX_SIZE, MI_GiB));
+    return false;
+  }
+
+  // allocated, initialize and claim the initial blocks
+  mem_region_t* r = &regions[idx];
+  r->arena_memid  = arena_memid;
+  mi_atomic_store_release(&r->in_use, (size_t)0);
+  mi_atomic_store_release(&r->dirty, (is_zero ? 0 : MI_BITMAP_FIELD_FULL));
+  mi_atomic_store_release(&r->commit, (region_commit ? MI_BITMAP_FIELD_FULL : 0));
+  mi_atomic_store_release(&r->reset, (size_t)0);
+  *bit_idx = 0;
+  _mi_bitmap_claim(&r->in_use, 1, blocks, *bit_idx, NULL);
+  mi_atomic_store_ptr_release(void,&r->start, start);
+
+  // and share it 
+  mi_region_info_t info;
+  info.value = 0;                        // initialize the full union to zero
+  info.x.valid = true;
+  info.x.is_large = region_large;
+  info.x.is_pinned = is_pinned;
+  info.x.numa_node = (short)_mi_os_numa_node(tld);
+  mi_atomic_store_release(&r->info, info.value); // now make it available to others
+  *region = r;
+  return true;
+}
+
+/* ----------------------------------------------------------------------------
+  Try to claim blocks in suitable regions
+-----------------------------------------------------------------------------*/
+
+static bool mi_region_is_suitable(const mem_region_t* region, int numa_node, bool allow_large ) {
+  // initialized at all?
+  mi_region_info_t info;
+  info.value = mi_atomic_load_relaxed(&((mem_region_t*)region)->info);
+  if (info.value==0) return false;
+
+  // numa correct
+  if (numa_node >= 0) {  // use negative numa node to always succeed
+    int rnode = info.x.numa_node;
+    if (rnode >= 0 && rnode != numa_node) return false;
+  }
+
+  // check allow-large
+  if (!allow_large && info.x.is_large) return false;
+
+  return true;
+}
+
+
+static bool mi_region_try_claim(int numa_node, size_t blocks, bool allow_large, mem_region_t** region, mi_bitmap_index_t* bit_idx, mi_os_tld_t* tld)
+{
+  // try all regions for a free slot  
+  const size_t count = mi_atomic_load_relaxed(&regions_count); // monotonic, so ok to be relaxed
+  size_t idx = tld->region_idx; // Or start at 0 to reuse low addresses? Starting at 0 seems to increase latency though
+  for (size_t visited = 0; visited < count; visited++, idx++) {
+    if (idx >= count) idx = 0;  // wrap around
+    mem_region_t* r = &regions[idx];
+    // if this region suits our demand (numa node matches, large OS page matches)
+    if (mi_region_is_suitable(r, numa_node, allow_large)) {
+      // then try to atomically claim a segment(s) in this region
+      if (_mi_bitmap_try_find_claim_field(&r->in_use, 0, blocks, bit_idx)) {
+        tld->region_idx = idx;    // remember the last found position
+        *region = r;
+        return true;
+      }
+    }
+  }
+  return false;
+}
+
+
+static void* mi_region_try_alloc(size_t blocks, bool* commit, bool* large, bool* is_pinned, bool* is_zero, size_t* memid, mi_os_tld_t* tld)
+{
+  mi_assert_internal(blocks <= MI_BITMAP_FIELD_BITS);
+  mem_region_t* region;
+  mi_bitmap_index_t bit_idx;
+  const int numa_node = (_mi_os_numa_node_count() <= 1 ? -1 : _mi_os_numa_node(tld));
+  // try to claim in existing regions
+  if (!mi_region_try_claim(numa_node, blocks, *large, &region, &bit_idx, tld)) {
+    // otherwise try to allocate a fresh region and claim in there
+    if (!mi_region_try_alloc_os(blocks, *commit, *large, &region, &bit_idx, tld)) {
+      // out of regions or memory
+      return NULL;
+    }
+  }
+  
+  // ------------------------------------------------
+  // found a region and claimed `blocks` at `bit_idx`, initialize them now
+  mi_assert_internal(region != NULL);
+  mi_assert_internal(_mi_bitmap_is_claimed(&region->in_use, 1, blocks, bit_idx));
+
+  mi_region_info_t info;
+  info.value = mi_atomic_load_acquire(&region->info);
+  uint8_t* start = (uint8_t*)mi_atomic_load_ptr_acquire(uint8_t,&region->start);
+  mi_assert_internal(!(info.x.is_large && !*large));
+  mi_assert_internal(start != NULL);
+
+  *is_zero   = _mi_bitmap_claim(&region->dirty, 1, blocks, bit_idx, NULL);  
+  *large     = info.x.is_large;
+  *is_pinned = info.x.is_pinned;
+  *memid     = mi_memid_create(region, bit_idx);
+  void* p = start + (mi_bitmap_index_bit_in_field(bit_idx) * MI_SEGMENT_SIZE);
+
+  // commit
+  if (*commit) {
+    // ensure commit
+    bool any_uncommitted;
+    _mi_bitmap_claim(&region->commit, 1, blocks, bit_idx, &any_uncommitted);
+    if (any_uncommitted) {
+      mi_assert_internal(!info.x.is_large && !info.x.is_pinned);
+      bool commit_zero = false;
+      if (!_mi_mem_commit(p, blocks * MI_SEGMENT_SIZE, &commit_zero, tld)) {
+        // failed to commit! unclaim and return
+        mi_bitmap_unclaim(&region->in_use, 1, blocks, bit_idx);
+        return NULL;
+      }
+      if (commit_zero) *is_zero = true;      
+    }
+  }
+  else {
+    // no need to commit, but check if already fully committed
+    *commit = _mi_bitmap_is_claimed(&region->commit, 1, blocks, bit_idx);
+  }  
+  mi_assert_internal(!*commit || _mi_bitmap_is_claimed(&region->commit, 1, blocks, bit_idx));
+
+  // unreset reset blocks
+  if (_mi_bitmap_is_any_claimed(&region->reset, 1, blocks, bit_idx)) {
+    // some blocks are still reset
+    mi_assert_internal(!info.x.is_large && !info.x.is_pinned);
+    mi_assert_internal(!mi_option_is_enabled(mi_option_eager_commit) || *commit || mi_option_get(mi_option_eager_commit_delay) > 0); 
+    mi_bitmap_unclaim(&region->reset, 1, blocks, bit_idx);
+    if (*commit || !mi_option_is_enabled(mi_option_reset_decommits)) { // only if needed
+      bool reset_zero = false;
+      _mi_mem_unreset(p, blocks * MI_SEGMENT_SIZE, &reset_zero, tld);
+      if (reset_zero) *is_zero = true;
+    }
+  }
+  mi_assert_internal(!_mi_bitmap_is_any_claimed(&region->reset, 1, blocks, bit_idx));
+  
+  #if (MI_DEBUG>=2)
+  if (*commit) { ((uint8_t*)p)[0] = 0; }
+  #endif
+  
+  // and return the allocation  
+  mi_assert_internal(p != NULL);  
+  return p;
+}
+
+
+/* ----------------------------------------------------------------------------
+ Allocation
+-----------------------------------------------------------------------------*/
+
+// Allocate `size` memory aligned at `alignment`. Return non NULL on success, with a given memory `id`.
+// (`id` is abstract, but `id = idx*MI_REGION_MAP_BITS + bitidx`)
+void* _mi_mem_alloc_aligned(size_t size, size_t alignment, bool* commit, bool* large, bool* is_pinned, bool* is_zero, size_t* memid, mi_os_tld_t* tld)
+{
+  mi_assert_internal(memid != NULL && tld != NULL);
+  mi_assert_internal(size > 0);
+  *memid = 0;
+  *is_zero = false;
+  *is_pinned = false;
+  bool default_large = false;
+  if (large==NULL) large = &default_large;  // ensure `large != NULL`  
+  if (size == 0) return NULL;
+  size = _mi_align_up(size, _mi_os_page_size());
+
+  // allocate from regions if possible
+  void* p = NULL;
+  size_t arena_memid;
+  const size_t blocks = mi_region_block_count(size);
+  if (blocks <= MI_REGION_MAX_OBJ_BLOCKS && alignment <= MI_SEGMENT_ALIGN) {
+    p = mi_region_try_alloc(blocks, commit, large, is_pinned, is_zero, memid, tld);    
+    if (p == NULL) {
+      _mi_warning_message("unable to allocate from region: size %zu\n", size);
+    }
+  }
+  if (p == NULL) {
+    // and otherwise fall back to the OS
+    p = _mi_arena_alloc_aligned(size, alignment, commit, large, is_pinned, is_zero, &arena_memid, tld);
+    *memid = mi_memid_create_from_arena(arena_memid);
+  }
+
+  if (p != NULL) {
+    mi_assert_internal((uintptr_t)p % alignment == 0);
+#if (MI_DEBUG>=2)
+    if (*commit) { ((uint8_t*)p)[0] = 0; } // ensure the memory is committed
+#endif
+  }
+  return p;
+}
+
+
+
+/* ----------------------------------------------------------------------------
+Free
+-----------------------------------------------------------------------------*/
+
+// Free previously allocated memory with a given id.
+void _mi_mem_free(void* p, size_t size, size_t id, bool full_commit, bool any_reset, mi_os_tld_t* tld) {
+  mi_assert_internal(size > 0 && tld != NULL);
+  if (p==NULL) return;
+  if (size==0) return;
+  size = _mi_align_up(size, _mi_os_page_size());
+  
+  size_t arena_memid = 0;
+  mi_bitmap_index_t bit_idx;
+  mem_region_t* region;
+  if (mi_memid_is_arena(id,&region,&bit_idx,&arena_memid)) {
+   // was a direct arena allocation, pass through
+    _mi_arena_free(p, size, arena_memid, full_commit, tld->stats);
+  }
+  else {
+    // allocated in a region
+    mi_assert_internal(size <= MI_REGION_MAX_OBJ_SIZE); if (size > MI_REGION_MAX_OBJ_SIZE) return;
+    const size_t blocks = mi_region_block_count(size);
+    mi_assert_internal(blocks + bit_idx <= MI_BITMAP_FIELD_BITS);
+    mi_region_info_t info;
+    info.value = mi_atomic_load_acquire(&region->info);
+    mi_assert_internal(info.value != 0);
+    void* blocks_start = mi_region_blocks_start(region, bit_idx);
+    mi_assert_internal(blocks_start == p); // not a pointer in our area?
+    mi_assert_internal(bit_idx + blocks <= MI_BITMAP_FIELD_BITS);
+    if (blocks_start != p || bit_idx + blocks > MI_BITMAP_FIELD_BITS) return; // or `abort`?
+
+    // committed?
+    if (full_commit && (size % MI_SEGMENT_SIZE) == 0) {
+      _mi_bitmap_claim(&region->commit, 1, blocks, bit_idx, NULL);
+    }
+
+    if (any_reset) {
+      // set the is_reset bits if any pages were reset
+      _mi_bitmap_claim(&region->reset, 1, blocks, bit_idx, NULL);
+    }
+
+    // reset the blocks to reduce the working set.
+    if (!info.x.is_large && !info.x.is_pinned && mi_option_is_enabled(mi_option_segment_reset) 
+       && (mi_option_is_enabled(mi_option_eager_commit) ||
+           mi_option_is_enabled(mi_option_reset_decommits))) // cannot reset halfway committed segments, use only `option_page_reset` instead            
+    {
+      bool any_unreset;
+      _mi_bitmap_claim(&region->reset, 1, blocks, bit_idx, &any_unreset);
+      if (any_unreset) {
+        _mi_abandoned_await_readers(); // ensure no more pending write (in case reset = decommit)
+        _mi_mem_reset(p, blocks * MI_SEGMENT_SIZE, tld);
+      }
+    }    
+
+    // and unclaim
+    bool all_unclaimed = mi_bitmap_unclaim(&region->in_use, 1, blocks, bit_idx);
+    mi_assert_internal(all_unclaimed); MI_UNUSED(all_unclaimed);
+  }
+}
+
+
+/* ----------------------------------------------------------------------------
+  collection
+-----------------------------------------------------------------------------*/
+void _mi_mem_collect(mi_os_tld_t* tld) {
+  // free every region that has no segments in use.
+  size_t rcount = mi_atomic_load_relaxed(&regions_count);
+  for (size_t i = 0; i < rcount; i++) {
+    mem_region_t* region = &regions[i];
+    if (mi_atomic_load_relaxed(&region->info) != 0) {
+      // if no segments used, try to claim the whole region
+      size_t m = mi_atomic_load_relaxed(&region->in_use);
+      while (m == 0 && !mi_atomic_cas_weak_release(&region->in_use, &m, MI_BITMAP_FIELD_FULL)) { /* nothing */ };
+      if (m == 0) {
+        // on success, free the whole region
+        uint8_t* start = (uint8_t*)mi_atomic_load_ptr_acquire(uint8_t,&regions[i].start);
+        size_t arena_memid = mi_atomic_load_relaxed(&regions[i].arena_memid);
+        size_t commit = mi_atomic_load_relaxed(&regions[i].commit);
+        memset((void*)&regions[i], 0, sizeof(mem_region_t));  // cast to void* to avoid atomic warning
+        // and release the whole region
+        mi_atomic_store_release(&region->info, (size_t)0);
+        if (start != NULL) { // && !_mi_os_is_huge_reserved(start)) {         
+          _mi_abandoned_await_readers(); // ensure no pending reads
+          _mi_arena_free(start, MI_REGION_SIZE, arena_memid, (~commit == 0), tld->stats);
+        }
+      }
+    }
+  }
+}
+
+
+/* ----------------------------------------------------------------------------
+  Other
+-----------------------------------------------------------------------------*/
+
+bool _mi_mem_reset(void* p, size_t size, mi_os_tld_t* tld) {
+  return _mi_os_reset(p, size, tld->stats);
+}
+
+bool _mi_mem_unreset(void* p, size_t size, bool* is_zero, mi_os_tld_t* tld) {
+  return _mi_os_unreset(p, size, is_zero, tld->stats);
+}
+
+bool _mi_mem_commit(void* p, size_t size, bool* is_zero, mi_os_tld_t* tld) {
+  return _mi_os_commit(p, size, is_zero, tld->stats);
+}
+
+bool _mi_mem_decommit(void* p, size_t size, mi_os_tld_t* tld) {
+  return _mi_os_decommit(p, size, tld->stats);
+}
+
+bool _mi_mem_protect(void* p, size_t size) {
+  return _mi_os_protect(p, size);
+}
+
+bool _mi_mem_unprotect(void* p, size_t size) {
+  return _mi_os_unprotect(p, size);
+}
diff --git a/Objects/mimalloc/segment-cache.c b/Objects/mimalloc/segment-cache.c
new file mode 100644
index 0000000000000..93908c8f881c7
--- /dev/null
+++ b/Objects/mimalloc/segment-cache.c
@@ -0,0 +1,360 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2020, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+
+/* ----------------------------------------------------------------------------
+  Implements a cache of segments to avoid expensive OS calls and to reuse
+  the commit_mask to optimize the commit/decommit calls.
+  The full memory map of all segments is also implemented here.
+-----------------------------------------------------------------------------*/
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+#include "mimalloc-atomic.h"
+
+#include "bitmap.h"  // atomic bitmap
+
+//#define MI_CACHE_DISABLE 1    // define to completely disable the segment cache
+
+#define MI_CACHE_FIELDS     (16)
+#define MI_CACHE_MAX        (MI_BITMAP_FIELD_BITS*MI_CACHE_FIELDS)       // 1024 on 64-bit
+
+#define BITS_SET()          ATOMIC_VAR_INIT(UINTPTR_MAX)
+#define MI_CACHE_BITS_SET   MI_INIT16(BITS_SET)                          // note: update if MI_CACHE_FIELDS changes
+
+typedef struct mi_cache_slot_s {
+  void*               p;
+  size_t              memid;
+  bool                is_pinned;
+  mi_commit_mask_t    commit_mask;
+  mi_commit_mask_t    decommit_mask;
+  _Atomic(mi_msecs_t) expire;
+} mi_cache_slot_t;
+
+static mi_decl_cache_align mi_cache_slot_t cache[MI_CACHE_MAX];    // = 0
+
+static mi_decl_cache_align mi_bitmap_field_t cache_available[MI_CACHE_FIELDS] = { MI_CACHE_BITS_SET };        // zero bit = available!
+static mi_decl_cache_align mi_bitmap_field_t cache_available_large[MI_CACHE_FIELDS] = { MI_CACHE_BITS_SET };
+static mi_decl_cache_align mi_bitmap_field_t cache_inuse[MI_CACHE_FIELDS];   // zero bit = free
+
+
+mi_decl_noinline void* _mi_segment_cache_pop(size_t size, mi_commit_mask_t* commit_mask, mi_commit_mask_t* decommit_mask, bool* large, bool* is_pinned, bool* is_zero, size_t* memid, mi_os_tld_t* tld)
+{
+#ifdef MI_CACHE_DISABLE
+  return NULL;
+#else
+
+  // only segment blocks
+  if (size != MI_SEGMENT_SIZE) return NULL;
+
+  // numa node determines start field
+  const int numa_node = _mi_os_numa_node(tld);
+  size_t start_field = 0;
+  if (numa_node > 0) {
+    start_field = (MI_CACHE_FIELDS / _mi_os_numa_node_count())*numa_node;
+    if (start_field >= MI_CACHE_FIELDS) start_field = 0;
+  }
+
+  // find an available slot
+  mi_bitmap_index_t bitidx = 0;
+  bool claimed = false;
+  if (*large) {  // large allowed?
+    claimed = _mi_bitmap_try_find_from_claim(cache_available_large, MI_CACHE_FIELDS, start_field, 1, &bitidx);
+    if (claimed) *large = true;
+  }
+  if (!claimed) {
+    claimed = _mi_bitmap_try_find_from_claim(cache_available, MI_CACHE_FIELDS, start_field, 1, &bitidx);
+    if (claimed) *large = false;
+  }
+
+  if (!claimed) return NULL;
+
+  // found a slot
+  mi_cache_slot_t* slot = &cache[mi_bitmap_index_bit(bitidx)];
+  void* p = slot->p;
+  *memid = slot->memid;
+  *is_pinned = slot->is_pinned;
+  *is_zero = false;
+  *commit_mask = slot->commit_mask;     
+  *decommit_mask = slot->decommit_mask;
+  slot->p = NULL;
+  mi_atomic_storei64_release(&slot->expire,(mi_msecs_t)0);
+  
+  // mark the slot as free again
+  mi_assert_internal(_mi_bitmap_is_claimed(cache_inuse, MI_CACHE_FIELDS, 1, bitidx));
+  _mi_bitmap_unclaim(cache_inuse, MI_CACHE_FIELDS, 1, bitidx);
+  return p;
+#endif
+}
+
+static mi_decl_noinline void mi_commit_mask_decommit(mi_commit_mask_t* cmask, void* p, size_t total, mi_stats_t* stats)
+{
+  if (mi_commit_mask_is_empty(cmask)) {
+    // nothing
+  }
+  else if (mi_commit_mask_is_full(cmask)) {
+    _mi_os_decommit(p, total, stats);
+  }
+  else {
+    // todo: one call to decommit the whole at once?
+    mi_assert_internal((total%MI_COMMIT_MASK_BITS)==0);
+    size_t part = total/MI_COMMIT_MASK_BITS;
+    size_t idx;
+    size_t count;    
+    mi_commit_mask_foreach(cmask, idx, count) {
+      void*  start = (uint8_t*)p + (idx*part);
+      size_t size = count*part;
+      _mi_os_decommit(start, size, stats);
+    }
+    mi_commit_mask_foreach_end()
+  }
+  mi_commit_mask_create_empty(cmask);
+}
+
+#define MI_MAX_PURGE_PER_PUSH  (4)
+
+static mi_decl_noinline void mi_segment_cache_purge(bool force, mi_os_tld_t* tld)
+{
+  MI_UNUSED(tld);
+  if (!mi_option_is_enabled(mi_option_allow_decommit)) return;
+  mi_msecs_t now = _mi_clock_now();
+  size_t purged = 0;
+  const size_t max_visits = (force ? MI_CACHE_MAX /* visit all */ : MI_CACHE_FIELDS /* probe at most N (=16) slots */);
+  size_t idx              = (force ? 0 : _mi_random_shuffle((uintptr_t)now) % MI_CACHE_MAX /* random start */ );
+  for (size_t visited = 0; visited < max_visits; visited++,idx++) {  // visit N slots
+    if (idx >= MI_CACHE_MAX) idx = 0; // wrap
+    mi_cache_slot_t* slot = &cache[idx];
+    mi_msecs_t expire = mi_atomic_loadi64_relaxed(&slot->expire);
+    if (expire != 0 && (force || now >= expire)) {  // racy read
+      // seems expired, first claim it from available
+      purged++;
+      mi_bitmap_index_t bitidx = mi_bitmap_index_create_from_bit(idx);
+      if (_mi_bitmap_claim(cache_available, MI_CACHE_FIELDS, 1, bitidx, NULL)) {
+        // was available, we claimed it
+        expire = mi_atomic_loadi64_acquire(&slot->expire);
+        if (expire != 0 && (force || now >= expire)) {  // safe read
+          // still expired, decommit it
+          mi_atomic_storei64_relaxed(&slot->expire,(mi_msecs_t)0);
+          mi_assert_internal(!mi_commit_mask_is_empty(&slot->commit_mask) && _mi_bitmap_is_claimed(cache_available_large, MI_CACHE_FIELDS, 1, bitidx));
+          _mi_abandoned_await_readers();  // wait until safe to decommit
+          // decommit committed parts
+          // TODO: instead of decommit, we could also free to the OS?
+          mi_commit_mask_decommit(&slot->commit_mask, slot->p, MI_SEGMENT_SIZE, tld->stats);
+          mi_commit_mask_create_empty(&slot->decommit_mask);
+        }
+        _mi_bitmap_unclaim(cache_available, MI_CACHE_FIELDS, 1, bitidx); // make it available again for a pop
+      }
+      if (!force && purged > MI_MAX_PURGE_PER_PUSH) break;  // bound to no more than N purge tries per push
+    }
+  }
+}
+
+void _mi_segment_cache_collect(bool force, mi_os_tld_t* tld) {
+  mi_segment_cache_purge(force, tld );
+}
+
+mi_decl_noinline bool _mi_segment_cache_push(void* start, size_t size, size_t memid, const mi_commit_mask_t* commit_mask, const mi_commit_mask_t* decommit_mask, bool is_large, bool is_pinned, mi_os_tld_t* tld)
+{
+#ifdef MI_CACHE_DISABLE
+  return false;
+#else
+
+  // only for normal segment blocks
+  if (size != MI_SEGMENT_SIZE || ((uintptr_t)start % MI_SEGMENT_ALIGN) != 0) return false;
+
+  // numa node determines start field
+  int numa_node = _mi_os_numa_node(NULL);
+  size_t start_field = 0;
+  if (numa_node > 0) {
+    start_field = (MI_CACHE_FIELDS / _mi_os_numa_node_count())*numa_node;
+    if (start_field >= MI_CACHE_FIELDS) start_field = 0;
+  }
+
+  // purge expired entries
+  mi_segment_cache_purge(false /* force? */, tld);
+
+  // find an available slot
+  mi_bitmap_index_t bitidx;
+  bool claimed = _mi_bitmap_try_find_from_claim(cache_inuse, MI_CACHE_FIELDS, start_field, 1, &bitidx);
+  if (!claimed) return false;
+
+  mi_assert_internal(_mi_bitmap_is_claimed(cache_available, MI_CACHE_FIELDS, 1, bitidx));
+  mi_assert_internal(_mi_bitmap_is_claimed(cache_available_large, MI_CACHE_FIELDS, 1, bitidx));
+#if MI_DEBUG>1
+  if (is_pinned || is_large) {
+    mi_assert_internal(mi_commit_mask_is_full(commit_mask));
+  }
+#endif
+
+  // set the slot
+  mi_cache_slot_t* slot = &cache[mi_bitmap_index_bit(bitidx)];
+  slot->p = start;
+  slot->memid = memid;
+  slot->is_pinned = is_pinned;
+  mi_atomic_storei64_relaxed(&slot->expire,(mi_msecs_t)0);
+  slot->commit_mask = *commit_mask;
+  slot->decommit_mask = *decommit_mask;
+  if (!mi_commit_mask_is_empty(commit_mask) && !is_large && !is_pinned && mi_option_is_enabled(mi_option_allow_decommit)) {
+    long delay = mi_option_get(mi_option_segment_decommit_delay);
+    if (delay == 0) {
+      _mi_abandoned_await_readers(); // wait until safe to decommit
+      mi_commit_mask_decommit(&slot->commit_mask, start, MI_SEGMENT_SIZE, tld->stats);
+      mi_commit_mask_create_empty(&slot->decommit_mask);
+    }
+    else {
+      mi_atomic_storei64_release(&slot->expire, _mi_clock_now() + delay);
+    }
+  }
+
+  // make it available
+  _mi_bitmap_unclaim((is_large ? cache_available_large : cache_available), MI_CACHE_FIELDS, 1, bitidx);
+  return true;
+#endif
+}
+
+
+/* -----------------------------------------------------------
+  The following functions are to reliably find the segment or
+  block that encompasses any pointer p (or NULL if it is not
+  in any of our segments).
+  We maintain a bitmap of all memory with 1 bit per MI_SEGMENT_SIZE (64MiB)
+  set to 1 if it contains the segment meta data.
+----------------------------------------------------------- */
+
+
+#if (MI_INTPTR_SIZE==8)
+#define MI_MAX_ADDRESS    ((size_t)20 << 40)  // 20TB
+#else
+#define MI_MAX_ADDRESS    ((size_t)2 << 30)   // 2Gb
+#endif
+
+#define MI_SEGMENT_MAP_BITS  (MI_MAX_ADDRESS / MI_SEGMENT_SIZE)
+#define MI_SEGMENT_MAP_SIZE  (MI_SEGMENT_MAP_BITS / 8)
+#define MI_SEGMENT_MAP_WSIZE (MI_SEGMENT_MAP_SIZE / MI_INTPTR_SIZE)
+
+static _Atomic(uintptr_t) mi_segment_map[MI_SEGMENT_MAP_WSIZE + 1];  // 2KiB per TB with 64MiB segments
+
+static size_t mi_segment_map_index_of(const mi_segment_t* segment, size_t* bitidx) {
+  mi_assert_internal(_mi_ptr_segment(segment) == segment); // is it aligned on MI_SEGMENT_SIZE?
+  if ((uintptr_t)segment >= MI_MAX_ADDRESS) {
+    *bitidx = 0;
+    return MI_SEGMENT_MAP_WSIZE;
+  }
+  else {
+    const uintptr_t segindex = ((uintptr_t)segment) / MI_SEGMENT_SIZE;
+    *bitidx = segindex % MI_INTPTR_BITS;
+    const size_t mapindex = segindex / MI_INTPTR_BITS;
+    mi_assert_internal(mapindex < MI_SEGMENT_MAP_WSIZE);
+    return mapindex;
+  }
+}
+
+void _mi_segment_map_allocated_at(const mi_segment_t* segment) {
+  size_t bitidx;
+  size_t index = mi_segment_map_index_of(segment, &bitidx);
+  mi_assert_internal(index <= MI_SEGMENT_MAP_WSIZE);
+  if (index==MI_SEGMENT_MAP_WSIZE) return;
+  uintptr_t mask = mi_atomic_load_relaxed(&mi_segment_map[index]);
+  uintptr_t newmask;
+  do {
+    newmask = (mask | ((uintptr_t)1 << bitidx));
+  } while (!mi_atomic_cas_weak_release(&mi_segment_map[index], &mask, newmask));
+}
+
+void _mi_segment_map_freed_at(const mi_segment_t* segment) {
+  size_t bitidx;
+  size_t index = mi_segment_map_index_of(segment, &bitidx);
+  mi_assert_internal(index <= MI_SEGMENT_MAP_WSIZE);
+  if (index == MI_SEGMENT_MAP_WSIZE) return;
+  uintptr_t mask = mi_atomic_load_relaxed(&mi_segment_map[index]);
+  uintptr_t newmask;
+  do {
+    newmask = (mask & ~((uintptr_t)1 << bitidx));
+  } while (!mi_atomic_cas_weak_release(&mi_segment_map[index], &mask, newmask));
+}
+
+// Determine the segment belonging to a pointer or NULL if it is not in a valid segment.
+static mi_segment_t* _mi_segment_of(const void* p) {
+  mi_segment_t* segment = _mi_ptr_segment(p);
+  if (segment == NULL) return NULL; 
+  size_t bitidx;
+  size_t index = mi_segment_map_index_of(segment, &bitidx);
+  // fast path: for any pointer to valid small/medium/large object or first MI_SEGMENT_SIZE in huge
+  const uintptr_t mask = mi_atomic_load_relaxed(&mi_segment_map[index]);
+  if (mi_likely((mask & ((uintptr_t)1 << bitidx)) != 0)) {
+    return segment; // yes, allocated by us
+  }
+  if (index==MI_SEGMENT_MAP_WSIZE) return NULL;
+
+  // TODO: maintain max/min allocated range for efficiency for more efficient rejection of invalid pointers?
+
+  // search downwards for the first segment in case it is an interior pointer
+  // could be slow but searches in MI_INTPTR_SIZE * MI_SEGMENT_SIZE (512MiB) steps trough
+  // valid huge objects
+  // note: we could maintain a lowest index to speed up the path for invalid pointers?
+  size_t lobitidx;
+  size_t loindex;
+  uintptr_t lobits = mask & (((uintptr_t)1 << bitidx) - 1);
+  if (lobits != 0) {
+    loindex = index;
+    lobitidx = mi_bsr(lobits);    // lobits != 0
+  }
+  else if (index == 0) {
+    return NULL;
+  }
+  else {
+    mi_assert_internal(index > 0);
+    uintptr_t lomask = mask;
+    loindex = index;
+    do {
+      loindex--;  
+      lomask = mi_atomic_load_relaxed(&mi_segment_map[loindex]);      
+    } while (lomask != 0 && loindex > 0);
+    if (lomask == 0) return NULL;
+    lobitidx = mi_bsr(lomask);    // lomask != 0
+  }
+  mi_assert_internal(loindex < MI_SEGMENT_MAP_WSIZE);
+  // take difference as the addresses could be larger than the MAX_ADDRESS space.
+  size_t diff = (((index - loindex) * (8*MI_INTPTR_SIZE)) + bitidx - lobitidx) * MI_SEGMENT_SIZE;
+  segment = (mi_segment_t*)((uint8_t*)segment - diff);
+
+  if (segment == NULL) return NULL;
+  mi_assert_internal((void*)segment < p);
+  bool cookie_ok = (_mi_ptr_cookie(segment) == segment->cookie);
+  mi_assert_internal(cookie_ok);
+  if (mi_unlikely(!cookie_ok)) return NULL;
+  if (((uint8_t*)segment + mi_segment_size(segment)) <= (uint8_t*)p) return NULL; // outside the range
+  mi_assert_internal(p >= (void*)segment && (uint8_t*)p < (uint8_t*)segment + mi_segment_size(segment));
+  return segment;
+}
+
+// Is this a valid pointer in our heap?
+static bool  mi_is_valid_pointer(const void* p) {
+  return (_mi_segment_of(p) != NULL);
+}
+
+mi_decl_nodiscard mi_decl_export bool mi_is_in_heap_region(const void* p) mi_attr_noexcept {
+  return mi_is_valid_pointer(p);
+}
+
+/*
+// Return the full segment range belonging to a pointer
+static void* mi_segment_range_of(const void* p, size_t* size) {
+  mi_segment_t* segment = _mi_segment_of(p);
+  if (segment == NULL) {
+    if (size != NULL) *size = 0;
+    return NULL;
+  }
+  else {
+    if (size != NULL) *size = segment->segment_size;
+    return segment;
+  }
+  mi_assert_expensive(page == NULL || mi_segment_is_valid(_mi_page_segment(page),tld));
+  mi_assert_internal(page == NULL || (mi_segment_page_size(_mi_page_segment(page)) - (MI_SECURE == 0 ? 0 : _mi_os_page_size())) >= block_size);
+  mi_reset_delayed(tld);
+  mi_assert_internal(page == NULL || mi_page_not_in_queue(page, tld));
+  return page;
+}
+*/
diff --git a/Objects/mimalloc/segment.c b/Objects/mimalloc/segment.c
new file mode 100644
index 0000000000000..8d3eebe5f3f29
--- /dev/null
+++ b/Objects/mimalloc/segment.c
@@ -0,0 +1,1609 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2020, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+#include "mimalloc-atomic.h"
+
+#include <string.h>  // memset
+#include <stdio.h>
+
+#define MI_PAGE_HUGE_ALIGN  (256*1024)
+
+static void mi_segment_delayed_decommit(mi_segment_t* segment, bool force, mi_stats_t* stats);
+
+
+// -------------------------------------------------------------------
+// commit mask 
+// -------------------------------------------------------------------
+
+static bool mi_commit_mask_all_set(const mi_commit_mask_t* commit, const mi_commit_mask_t* cm) {
+  for (size_t i = 0; i < MI_COMMIT_MASK_FIELD_COUNT; i++) {
+    if ((commit->mask[i] & cm->mask[i]) != cm->mask[i]) return false;
+  }
+  return true;
+}
+
+static bool mi_commit_mask_any_set(const mi_commit_mask_t* commit, const mi_commit_mask_t* cm) {
+  for (size_t i = 0; i < MI_COMMIT_MASK_FIELD_COUNT; i++) {
+    if ((commit->mask[i] & cm->mask[i]) != 0) return true;
+  }
+  return false;
+}
+
+static void mi_commit_mask_create_intersect(const mi_commit_mask_t* commit, const mi_commit_mask_t* cm, mi_commit_mask_t* res) {
+  for (size_t i = 0; i < MI_COMMIT_MASK_FIELD_COUNT; i++) {
+    res->mask[i] = (commit->mask[i] & cm->mask[i]);
+  }
+}
+
+static void mi_commit_mask_clear(mi_commit_mask_t* res, const mi_commit_mask_t* cm) {
+  for (size_t i = 0; i < MI_COMMIT_MASK_FIELD_COUNT; i++) {
+    res->mask[i] &= ~(cm->mask[i]);
+  }
+}
+
+static void mi_commit_mask_set(mi_commit_mask_t* res, const mi_commit_mask_t* cm) {
+  for (size_t i = 0; i < MI_COMMIT_MASK_FIELD_COUNT; i++) {
+    res->mask[i] |= cm->mask[i];
+  }
+}
+
+static void mi_commit_mask_create(size_t bitidx, size_t bitcount, mi_commit_mask_t* cm) {
+  mi_assert_internal(bitidx < MI_COMMIT_MASK_BITS);
+  mi_assert_internal((bitidx + bitcount) <= MI_COMMIT_MASK_BITS);
+  if (bitcount == MI_COMMIT_MASK_BITS) {
+    mi_assert_internal(bitidx==0);
+    mi_commit_mask_create_full(cm);
+  }
+  else if (bitcount == 0) {
+    mi_commit_mask_create_empty(cm);
+  }
+  else {
+    mi_commit_mask_create_empty(cm);
+    size_t i = bitidx / MI_COMMIT_MASK_FIELD_BITS;
+    size_t ofs = bitidx % MI_COMMIT_MASK_FIELD_BITS;
+    while (bitcount > 0) {
+      mi_assert_internal(i < MI_COMMIT_MASK_FIELD_COUNT);
+      size_t avail = MI_COMMIT_MASK_FIELD_BITS - ofs;
+      size_t count = (bitcount > avail ? avail : bitcount);
+      size_t mask = (count >= MI_COMMIT_MASK_FIELD_BITS ? ~((size_t)0) : (((size_t)1 << count) - 1) << ofs);
+      cm->mask[i] = mask;
+      bitcount -= count;
+      ofs = 0;
+      i++;
+    }
+  }
+}
+
+size_t _mi_commit_mask_committed_size(const mi_commit_mask_t* cm, size_t total) {
+  mi_assert_internal((total%MI_COMMIT_MASK_BITS)==0);
+  size_t count = 0;
+  for (size_t i = 0; i < MI_COMMIT_MASK_FIELD_COUNT; i++) {
+    size_t mask = cm->mask[i];
+    if (~mask == 0) {
+      count += MI_COMMIT_MASK_FIELD_BITS;
+    }
+    else {
+      for (; mask != 0; mask >>= 1) {  // todo: use popcount
+        if ((mask&1)!=0) count++;
+      }
+    }
+  }
+  // we use total since for huge segments each commit bit may represent a larger size
+  return ((total / MI_COMMIT_MASK_BITS) * count);
+}
+
+
+size_t _mi_commit_mask_next_run(const mi_commit_mask_t* cm, size_t* idx) {
+  size_t i = (*idx) / MI_COMMIT_MASK_FIELD_BITS;
+  size_t ofs = (*idx) % MI_COMMIT_MASK_FIELD_BITS;
+  size_t mask = 0;
+  // find first ones
+  while (i < MI_COMMIT_MASK_FIELD_COUNT) {
+    mask = cm->mask[i];
+    mask >>= ofs;
+    if (mask != 0) {
+      while ((mask&1) == 0) {
+        mask >>= 1;
+        ofs++;
+      }
+      break;
+    }
+    i++;
+    ofs = 0;
+  }
+  if (i >= MI_COMMIT_MASK_FIELD_COUNT) {
+    // not found
+    *idx = MI_COMMIT_MASK_BITS;
+    return 0;
+  }
+  else {
+    // found, count ones
+    size_t count = 0;
+    *idx = (i*MI_COMMIT_MASK_FIELD_BITS) + ofs;
+    do {
+      mi_assert_internal(ofs < MI_COMMIT_MASK_FIELD_BITS && (mask&1) == 1);
+      do {
+        count++;
+        mask >>= 1;
+      } while ((mask&1) == 1);
+      if ((((*idx + count) % MI_COMMIT_MASK_FIELD_BITS) == 0)) {
+        i++;
+        if (i >= MI_COMMIT_MASK_FIELD_COUNT) break;
+        mask = cm->mask[i];
+        ofs = 0;
+      }
+    } while ((mask&1) == 1);
+    mi_assert_internal(count > 0);
+    return count;
+  }
+}
+
+
+/* --------------------------------------------------------------------------------
+  Segment allocation
+
+  If a  thread ends, it "abandons" pages with used blocks
+  and there is an abandoned segment list whose segments can
+  be reclaimed by still running threads, much like work-stealing.
+-------------------------------------------------------------------------------- */
+
+
+/* -----------------------------------------------------------
+   Slices
+----------------------------------------------------------- */
+
+
+static const mi_slice_t* mi_segment_slices_end(const mi_segment_t* segment) {
+  return &segment->slices[segment->slice_entries];
+}
+
+static uint8_t* mi_slice_start(const mi_slice_t* slice) {
+  mi_segment_t* segment = _mi_ptr_segment(slice);
+  mi_assert_internal(slice >= segment->slices && slice < mi_segment_slices_end(segment));
+  return ((uint8_t*)segment + ((slice - segment->slices)*MI_SEGMENT_SLICE_SIZE));
+}
+
+
+/* -----------------------------------------------------------
+   Bins
+----------------------------------------------------------- */
+// Use bit scan forward to quickly find the first zero bit if it is available
+
+static inline size_t mi_slice_bin8(size_t slice_count) {
+  if (slice_count<=1) return slice_count;
+  mi_assert_internal(slice_count <= MI_SLICES_PER_SEGMENT);
+  slice_count--;
+  size_t s = mi_bsr(slice_count);  // slice_count > 1
+  if (s <= 2) return slice_count + 1;
+  size_t bin = ((s << 2) | ((slice_count >> (s - 2))&0x03)) - 4;
+  return bin;
+}
+
+static inline size_t mi_slice_bin(size_t slice_count) {
+  mi_assert_internal(slice_count*MI_SEGMENT_SLICE_SIZE <= MI_SEGMENT_SIZE);
+  mi_assert_internal(mi_slice_bin8(MI_SLICES_PER_SEGMENT) <= MI_SEGMENT_BIN_MAX);
+  size_t bin = mi_slice_bin8(slice_count);
+  mi_assert_internal(bin <= MI_SEGMENT_BIN_MAX);
+  return bin;
+}
+
+static inline size_t mi_slice_index(const mi_slice_t* slice) {
+  mi_segment_t* segment = _mi_ptr_segment(slice);
+  ptrdiff_t index = slice - segment->slices;
+  mi_assert_internal(index >= 0 && index < (ptrdiff_t)segment->slice_entries);
+  return index;
+}
+
+
+/* -----------------------------------------------------------
+   Slice span queues
+----------------------------------------------------------- */
+
+static void mi_span_queue_push(mi_span_queue_t* sq, mi_slice_t* slice) {
+  // todo: or push to the end?
+  mi_assert_internal(slice->prev == NULL && slice->next==NULL);
+  slice->prev = NULL; // paranoia
+  slice->next = sq->first;
+  sq->first = slice;
+  if (slice->next != NULL) slice->next->prev = slice;
+                     else sq->last = slice;
+  slice->xblock_size = 0; // free
+}
+
+static mi_span_queue_t* mi_span_queue_for(size_t slice_count, mi_segments_tld_t* tld) {
+  size_t bin = mi_slice_bin(slice_count);
+  mi_span_queue_t* sq = &tld->spans[bin];
+  mi_assert_internal(sq->slice_count >= slice_count);
+  return sq;
+}
+
+static void mi_span_queue_delete(mi_span_queue_t* sq, mi_slice_t* slice) {
+  mi_assert_internal(slice->xblock_size==0 && slice->slice_count>0 && slice->slice_offset==0);
+  // should work too if the queue does not contain slice (which can happen during reclaim)
+  if (slice->prev != NULL) slice->prev->next = slice->next;
+  if (slice == sq->first) sq->first = slice->next;
+  if (slice->next != NULL) slice->next->prev = slice->prev;
+  if (slice == sq->last) sq->last = slice->prev;
+  slice->prev = NULL;
+  slice->next = NULL;
+  slice->xblock_size = 1; // no more free
+}
+
+
+/* -----------------------------------------------------------
+ Invariant checking
+----------------------------------------------------------- */
+
+static bool mi_slice_is_used(const mi_slice_t* slice) {
+  return (slice->xblock_size > 0);
+}
+
+
+#if (MI_DEBUG>=3)
+static bool mi_span_queue_contains(mi_span_queue_t* sq, mi_slice_t* slice) {
+  for (mi_slice_t* s = sq->first; s != NULL; s = s->next) {
+    if (s==slice) return true;
+  }
+  return false;
+}
+
+static bool mi_segment_is_valid(mi_segment_t* segment, mi_segments_tld_t* tld) {
+  mi_assert_internal(segment != NULL);
+  mi_assert_internal(_mi_ptr_cookie(segment) == segment->cookie);
+  mi_assert_internal(segment->abandoned <= segment->used);
+  mi_assert_internal(segment->thread_id == 0 || segment->thread_id == _mi_thread_id());
+  mi_assert_internal(mi_commit_mask_all_set(&segment->commit_mask, &segment->decommit_mask)); // can only decommit committed blocks
+  //mi_assert_internal(segment->segment_info_size % MI_SEGMENT_SLICE_SIZE == 0);
+  mi_slice_t* slice = &segment->slices[0];
+  const mi_slice_t* end = mi_segment_slices_end(segment);
+  size_t used_count = 0;
+  mi_span_queue_t* sq;
+  while(slice < end) {
+    mi_assert_internal(slice->slice_count > 0);
+    mi_assert_internal(slice->slice_offset == 0);
+    size_t index = mi_slice_index(slice);
+    size_t maxindex = (index + slice->slice_count >= segment->slice_entries ? segment->slice_entries : index + slice->slice_count) - 1;
+    if (mi_slice_is_used(slice)) { // a page in use, we need at least MAX_SLICE_OFFSET valid back offsets
+      used_count++;
+      for (size_t i = 0; i <= MI_MAX_SLICE_OFFSET && index + i <= maxindex; i++) {
+        mi_assert_internal(segment->slices[index + i].slice_offset == i*sizeof(mi_slice_t));
+        mi_assert_internal(i==0 || segment->slices[index + i].slice_count == 0);
+        mi_assert_internal(i==0 || segment->slices[index + i].xblock_size == 1);
+      }
+      // and the last entry as well (for coalescing)
+      const mi_slice_t* last = slice + slice->slice_count - 1;
+      if (last > slice && last < mi_segment_slices_end(segment)) {
+        mi_assert_internal(last->slice_offset == (slice->slice_count-1)*sizeof(mi_slice_t));
+        mi_assert_internal(last->slice_count == 0);
+        mi_assert_internal(last->xblock_size == 1);
+      }
+    }
+    else {  // free range of slices; only last slice needs a valid back offset
+      mi_slice_t* last = &segment->slices[maxindex];
+      if (segment->kind != MI_SEGMENT_HUGE || slice->slice_count <= (segment->slice_entries - segment->segment_info_slices)) {
+        mi_assert_internal((uint8_t*)slice == (uint8_t*)last - last->slice_offset);
+      }
+      mi_assert_internal(slice == last || last->slice_count == 0 );
+      mi_assert_internal(last->xblock_size == 0 || (segment->kind==MI_SEGMENT_HUGE && last->xblock_size==1));
+      if (segment->kind != MI_SEGMENT_HUGE && segment->thread_id != 0) { // segment is not huge or abandoned
+        sq = mi_span_queue_for(slice->slice_count,tld);
+        mi_assert_internal(mi_span_queue_contains(sq,slice));
+      }
+    }
+    slice = &segment->slices[maxindex+1];
+  }
+  mi_assert_internal(slice == end);
+  mi_assert_internal(used_count == segment->used + 1);
+  return true;
+}
+#endif
+
+/* -----------------------------------------------------------
+ Segment size calculations
+----------------------------------------------------------- */
+
+static size_t mi_segment_info_size(mi_segment_t* segment) {
+  return segment->segment_info_slices * MI_SEGMENT_SLICE_SIZE;
+}
+
+static uint8_t* _mi_segment_page_start_from_slice(const mi_segment_t* segment, const mi_slice_t* slice, size_t xblock_size, size_t* page_size)
+{
+  ptrdiff_t idx = slice - segment->slices;
+  size_t psize = (size_t)slice->slice_count * MI_SEGMENT_SLICE_SIZE;
+  // make the start not OS page aligned for smaller blocks to avoid page/cache effects
+  size_t start_offset = (xblock_size >= MI_INTPTR_SIZE && xblock_size <= 1024 ? MI_MAX_ALIGN_GUARANTEE : 0); 
+  if (page_size != NULL) { *page_size = psize - start_offset; }
+  return (uint8_t*)segment + ((idx*MI_SEGMENT_SLICE_SIZE) + start_offset);
+}
+
+// Start of the page available memory; can be used on uninitialized pages
+uint8_t* _mi_segment_page_start(const mi_segment_t* segment, const mi_page_t* page, size_t* page_size)
+{
+  const mi_slice_t* slice = mi_page_to_slice((mi_page_t*)page);
+  uint8_t* p = _mi_segment_page_start_from_slice(segment, slice, page->xblock_size, page_size);  
+  mi_assert_internal(page->xblock_size > 0 || _mi_ptr_page(p) == page);
+  mi_assert_internal(_mi_ptr_segment(p) == segment);
+  return p;
+}
+
+
+static size_t mi_segment_calculate_slices(size_t required, size_t* pre_size, size_t* info_slices) {
+  size_t page_size = _mi_os_page_size();
+  size_t isize     = _mi_align_up(sizeof(mi_segment_t), page_size);
+  size_t guardsize = 0;
+
+  if (MI_SECURE>0) {
+    // in secure mode, we set up a protected page in between the segment info
+    // and the page data (and one at the end of the segment)
+    guardsize =  page_size;
+    required  = _mi_align_up(required, page_size);
+  }
+
+  if (pre_size != NULL) *pre_size = isize;
+  isize = _mi_align_up(isize + guardsize, MI_SEGMENT_SLICE_SIZE);
+  if (info_slices != NULL) *info_slices = isize / MI_SEGMENT_SLICE_SIZE;
+  size_t segment_size = (required==0 ? MI_SEGMENT_SIZE : _mi_align_up( required + isize + guardsize, MI_SEGMENT_SLICE_SIZE) );  
+  mi_assert_internal(segment_size % MI_SEGMENT_SLICE_SIZE == 0);
+  return (segment_size / MI_SEGMENT_SLICE_SIZE);
+}
+
+
+/* ----------------------------------------------------------------------------
+Segment caches
+We keep a small segment cache per thread to increase local
+reuse and avoid setting/clearing guard pages in secure mode.
+------------------------------------------------------------------------------- */
+
+static void mi_segments_track_size(long segment_size, mi_segments_tld_t* tld) {
+  if (segment_size>=0) _mi_stat_increase(&tld->stats->segments,1);
+                  else _mi_stat_decrease(&tld->stats->segments,1);
+  tld->count += (segment_size >= 0 ? 1 : -1);
+  if (tld->count > tld->peak_count) tld->peak_count = tld->count;
+  tld->current_size += segment_size;
+  if (tld->current_size > tld->peak_size) tld->peak_size = tld->current_size;
+}
+
+static void mi_segment_os_free(mi_segment_t* segment, mi_segments_tld_t* tld) {
+  segment->thread_id = 0;
+  _mi_segment_map_freed_at(segment);
+  mi_segments_track_size(-((long)mi_segment_size(segment)),tld);
+  if (MI_SECURE>0) {
+    // _mi_os_unprotect(segment, mi_segment_size(segment)); // ensure no more guard pages are set
+    // unprotect the guard pages; we cannot just unprotect the whole segment size as part may be decommitted
+    size_t os_pagesize = _mi_os_page_size();
+    _mi_os_unprotect((uint8_t*)segment + mi_segment_info_size(segment) - os_pagesize, os_pagesize);
+    uint8_t* end = (uint8_t*)segment + mi_segment_size(segment) - os_pagesize;
+    _mi_os_unprotect(end, os_pagesize);
+  }
+
+  // purge delayed decommits now? (no, leave it to the cache)
+  // mi_segment_delayed_decommit(segment,true,tld->stats);
+  
+  // _mi_os_free(segment, mi_segment_size(segment), /*segment->memid,*/ tld->stats);
+  const size_t size = mi_segment_size(segment);
+  if (size != MI_SEGMENT_SIZE || !_mi_segment_cache_push(segment, size, segment->memid, &segment->commit_mask, &segment->decommit_mask, segment->mem_is_large, segment->mem_is_pinned, tld->os)) {
+    const size_t csize = _mi_commit_mask_committed_size(&segment->commit_mask, size);
+    if (csize > 0 && !segment->mem_is_pinned) _mi_stat_decrease(&_mi_stats_main.committed, csize);
+    _mi_abandoned_await_readers();  // wait until safe to free
+    _mi_arena_free(segment, mi_segment_size(segment), segment->memid, segment->mem_is_pinned /* pretend not committed to not double count decommits */, tld->os);
+  }
+}
+
+
+// The thread local segment cache is limited to be at most 1/8 of the peak size of segments in use,
+#define MI_SEGMENT_CACHE_FRACTION (8)
+
+// note: returned segment may be partially reset
+static mi_segment_t* mi_segment_cache_pop(size_t segment_slices, mi_segments_tld_t* tld) {
+  if (segment_slices != 0 && segment_slices != MI_SLICES_PER_SEGMENT) return NULL;
+  mi_segment_t* segment = tld->cache;
+  if (segment == NULL) return NULL;
+  tld->cache_count--;
+  tld->cache = segment->next;
+  segment->next = NULL;
+  mi_assert_internal(segment->segment_slices == MI_SLICES_PER_SEGMENT);
+  _mi_stat_decrease(&tld->stats->segments_cache, 1);
+  return segment;
+}
+
+static bool mi_segment_cache_full(mi_segments_tld_t* tld)
+{
+  // if (tld->count == 1 && tld->cache_count==0) return false; // always cache at least the final segment of a thread
+  size_t max_cache = mi_option_get(mi_option_segment_cache);
+  if (tld->cache_count < max_cache
+       && tld->cache_count < (1 + (tld->peak_count / MI_SEGMENT_CACHE_FRACTION)) // at least allow a 1 element cache
+     ) {
+    return false;
+  }
+  // take the opportunity to reduce the segment cache if it is too large (now)
+  // TODO: this never happens as we check against peak usage, should we use current usage instead?
+  while (tld->cache_count > max_cache) { //(1 + (tld->peak_count / MI_SEGMENT_CACHE_FRACTION))) {
+    mi_segment_t* segment = mi_segment_cache_pop(0,tld);
+    mi_assert_internal(segment != NULL);
+    if (segment != NULL) mi_segment_os_free(segment, tld);
+  }
+  return true;
+}
+
+static bool mi_segment_cache_push(mi_segment_t* segment, mi_segments_tld_t* tld) {
+  mi_assert_internal(segment->next == NULL);
+  if (segment->segment_slices != MI_SLICES_PER_SEGMENT || mi_segment_cache_full(tld)) {
+    return false;
+  }
+  // mi_segment_delayed_decommit(segment, true, tld->stats);  
+  mi_assert_internal(segment->segment_slices == MI_SLICES_PER_SEGMENT);
+  mi_assert_internal(segment->next == NULL);  
+  segment->next = tld->cache;
+  tld->cache = segment;
+  tld->cache_count++;
+  _mi_stat_increase(&tld->stats->segments_cache,1);
+  return true;
+}
+
+// called by threads that are terminating to free cached segments
+void _mi_segment_thread_collect(mi_segments_tld_t* tld) {
+  mi_segment_t* segment;
+  while ((segment = mi_segment_cache_pop(0,tld)) != NULL) {
+    mi_segment_os_free(segment, tld);
+  }
+  mi_assert_internal(tld->cache_count == 0);
+  mi_assert_internal(tld->cache == NULL);  
+}
+
+
+
+/* -----------------------------------------------------------
+   Span management
+----------------------------------------------------------- */
+
+static void mi_segment_commit_mask(mi_segment_t* segment, bool conservative, uint8_t* p, size_t size, uint8_t** start_p, size_t* full_size, mi_commit_mask_t* cm) {
+  mi_assert_internal(_mi_ptr_segment(p) == segment);
+  mi_assert_internal(segment->kind != MI_SEGMENT_HUGE);
+  mi_commit_mask_create_empty(cm);
+  if (size == 0 || size > MI_SEGMENT_SIZE || segment->kind == MI_SEGMENT_HUGE) return;
+  const size_t segstart = mi_segment_info_size(segment);
+  const size_t segsize = mi_segment_size(segment);
+  if (p >= (uint8_t*)segment + segsize) return;
+
+  size_t pstart = (p - (uint8_t*)segment);
+  mi_assert_internal(pstart + size <= segsize);
+
+  size_t start;
+  size_t end;
+  if (conservative) {
+    // decommit conservative
+    start = _mi_align_up(pstart, MI_COMMIT_SIZE);
+    end   = _mi_align_down(pstart + size, MI_COMMIT_SIZE);
+    mi_assert_internal(start >= segstart);
+    mi_assert_internal(end <= segsize);
+  }
+  else {
+    // commit liberal
+    start = _mi_align_down(pstart, MI_MINIMAL_COMMIT_SIZE);
+    end   = _mi_align_up(pstart + size, MI_MINIMAL_COMMIT_SIZE);
+  }
+  if (pstart >= segstart && start < segstart) {  // note: the mask is also calculated for an initial commit of the info area
+    start = segstart;
+  }
+  if (end > segsize) {
+    end = segsize;
+  }
+
+  mi_assert_internal(start <= pstart && (pstart + size) <= end);
+  mi_assert_internal(start % MI_COMMIT_SIZE==0 && end % MI_COMMIT_SIZE == 0);
+  *start_p   = (uint8_t*)segment + start;
+  *full_size = (end > start ? end - start : 0);
+  if (*full_size == 0) return;
+
+  size_t bitidx = start / MI_COMMIT_SIZE;
+  mi_assert_internal(bitidx < MI_COMMIT_MASK_BITS);
+  
+  size_t bitcount = *full_size / MI_COMMIT_SIZE; // can be 0
+  if (bitidx + bitcount > MI_COMMIT_MASK_BITS) {
+    _mi_warning_message("commit mask overflow: idx=%zu count=%zu start=%zx end=%zx p=0x%p size=%zu fullsize=%zu\n", bitidx, bitcount, start, end, p, size, *full_size);
+  }
+  mi_assert_internal((bitidx + bitcount) <= MI_COMMIT_MASK_BITS);
+  mi_commit_mask_create(bitidx, bitcount, cm);
+}
+
+
+static bool mi_segment_commitx(mi_segment_t* segment, bool commit, uint8_t* p, size_t size, mi_stats_t* stats) {    
+  mi_assert_internal(mi_commit_mask_all_set(&segment->commit_mask, &segment->decommit_mask));
+
+  // try to commit in at least MI_MINIMAL_COMMIT_SIZE sizes.
+  /*
+  if (commit && size > 0) {
+    const size_t csize = _mi_align_up(size, MI_MINIMAL_COMMIT_SIZE);
+    if (p + csize <= mi_segment_end(segment)) {
+      size = csize;
+    }
+  }
+  */
+  // commit liberal, but decommit conservative
+  uint8_t* start = NULL;
+  size_t   full_size = 0;
+  mi_commit_mask_t mask;
+  mi_segment_commit_mask(segment, !commit/*conservative*/, p, size, &start, &full_size, &mask);
+  if (mi_commit_mask_is_empty(&mask) || full_size==0) return true;
+
+  if (commit && !mi_commit_mask_all_set(&segment->commit_mask, &mask)) {
+    bool is_zero = false;
+    mi_commit_mask_t cmask;
+    mi_commit_mask_create_intersect(&segment->commit_mask, &mask, &cmask);
+    _mi_stat_decrease(&_mi_stats_main.committed, _mi_commit_mask_committed_size(&cmask, MI_SEGMENT_SIZE)); // adjust for overlap
+    if (!_mi_os_commit(start,full_size,&is_zero,stats)) return false;    
+    mi_commit_mask_set(&segment->commit_mask, &mask);     
+  }
+  else if (!commit && mi_commit_mask_any_set(&segment->commit_mask, &mask)) {
+    mi_assert_internal((void*)start != (void*)segment);
+    //mi_assert_internal(mi_commit_mask_all_set(&segment->commit_mask, &mask));
+
+    mi_commit_mask_t cmask;
+    mi_commit_mask_create_intersect(&segment->commit_mask, &mask, &cmask);
+    _mi_stat_increase(&_mi_stats_main.committed, full_size - _mi_commit_mask_committed_size(&cmask, MI_SEGMENT_SIZE)); // adjust for overlap
+    if (segment->allow_decommit) { 
+      _mi_os_decommit(start, full_size, stats); // ok if this fails
+    } 
+    mi_commit_mask_clear(&segment->commit_mask, &mask);
+  }
+  // increase expiration of reusing part of the delayed decommit
+  if (commit && mi_commit_mask_any_set(&segment->decommit_mask, &mask)) {
+    segment->decommit_expire = _mi_clock_now() + mi_option_get(mi_option_decommit_delay);
+  }
+  // always undo delayed decommits
+  mi_commit_mask_clear(&segment->decommit_mask, &mask);
+  return true;
+}
+
+static bool mi_segment_ensure_committed(mi_segment_t* segment, uint8_t* p, size_t size, mi_stats_t* stats) {
+  mi_assert_internal(mi_commit_mask_all_set(&segment->commit_mask, &segment->decommit_mask));
+  // note: assumes commit_mask is always full for huge segments as otherwise the commit mask bits can overflow
+  if (mi_commit_mask_is_full(&segment->commit_mask) && mi_commit_mask_is_empty(&segment->decommit_mask)) return true; // fully committed
+  return mi_segment_commitx(segment,true,p,size,stats);
+}
+
+static void mi_segment_perhaps_decommit(mi_segment_t* segment, uint8_t* p, size_t size, mi_stats_t* stats) {
+  if (!segment->allow_decommit) return;
+  if (mi_option_get(mi_option_decommit_delay) == 0) {
+    mi_segment_commitx(segment, false, p, size, stats);
+  }
+  else {
+    // register for future decommit in the decommit mask
+    uint8_t* start = NULL;
+    size_t   full_size = 0;
+    mi_commit_mask_t mask; 
+    mi_segment_commit_mask(segment, true /*conservative*/, p, size, &start, &full_size, &mask);
+    if (mi_commit_mask_is_empty(&mask) || full_size==0) return;
+    
+    // update delayed commit
+    mi_assert_internal(segment->decommit_expire > 0 || mi_commit_mask_is_empty(&segment->decommit_mask));      
+    mi_commit_mask_t cmask;
+    mi_commit_mask_create_intersect(&segment->commit_mask, &mask, &cmask);  // only decommit what is committed; span_free may try to decommit more
+    mi_commit_mask_set(&segment->decommit_mask, &cmask);
+    mi_msecs_t now = _mi_clock_now();    
+    if (segment->decommit_expire == 0) {
+      // no previous decommits, initialize now
+      segment->decommit_expire = now + mi_option_get(mi_option_decommit_delay);
+    }
+    else if (segment->decommit_expire <= now) {
+      // previous decommit mask already expired
+      // mi_segment_delayed_decommit(segment, true, stats);
+      segment->decommit_expire = now + mi_option_get(mi_option_decommit_extend_delay); // (mi_option_get(mi_option_decommit_delay) / 8); // wait a tiny bit longer in case there is a series of free's
+    }
+    else {
+      // previous decommit mask is not yet expired, increase the expiration by a bit.
+      segment->decommit_expire += mi_option_get(mi_option_decommit_extend_delay);
+    }
+  }  
+}
+
+static void mi_segment_delayed_decommit(mi_segment_t* segment, bool force, mi_stats_t* stats) {
+  if (!segment->allow_decommit || mi_commit_mask_is_empty(&segment->decommit_mask)) return;
+  mi_msecs_t now = _mi_clock_now();
+  if (!force && now < segment->decommit_expire) return;
+
+  mi_commit_mask_t mask = segment->decommit_mask;
+  segment->decommit_expire = 0;
+  mi_commit_mask_create_empty(&segment->decommit_mask);
+
+  size_t idx;
+  size_t count;
+  mi_commit_mask_foreach(&mask, idx, count) {
+    // if found, decommit that sequence
+    if (count > 0) {
+      uint8_t* p = (uint8_t*)segment + (idx*MI_COMMIT_SIZE);
+      size_t size = count * MI_COMMIT_SIZE;
+      mi_segment_commitx(segment, false, p, size, stats);
+    }
+  }
+  mi_commit_mask_foreach_end()
+  mi_assert_internal(mi_commit_mask_is_empty(&segment->decommit_mask));
+}
+
+
+static bool mi_segment_is_abandoned(mi_segment_t* segment) {
+  return (segment->thread_id == 0);
+}
+
+// note: can be called on abandoned segments
+static void mi_segment_span_free(mi_segment_t* segment, size_t slice_index, size_t slice_count, mi_segments_tld_t* tld) {
+  mi_assert_internal(slice_index < segment->slice_entries);
+  mi_span_queue_t* sq = (segment->kind == MI_SEGMENT_HUGE || mi_segment_is_abandoned(segment) 
+                          ? NULL : mi_span_queue_for(slice_count,tld));
+  if (slice_count==0) slice_count = 1;
+  mi_assert_internal(slice_index + slice_count - 1 < segment->slice_entries);
+
+  // set first and last slice (the intermediates can be undetermined)
+  mi_slice_t* slice = &segment->slices[slice_index];
+  slice->slice_count = (uint32_t)slice_count;
+  mi_assert_internal(slice->slice_count == slice_count); // no overflow?
+  slice->slice_offset = 0;
+  if (slice_count > 1) {
+    mi_slice_t* last = &segment->slices[slice_index + slice_count - 1];
+    last->slice_count = 0;
+    last->slice_offset = (uint32_t)(sizeof(mi_page_t)*(slice_count - 1));
+    last->xblock_size = 0;
+  }
+
+  // perhaps decommit
+  mi_segment_perhaps_decommit(segment,mi_slice_start(slice),slice_count*MI_SEGMENT_SLICE_SIZE,tld->stats);
+  
+  // and push it on the free page queue (if it was not a huge page)
+  if (sq != NULL) mi_span_queue_push( sq, slice );
+             else slice->xblock_size = 0; // mark huge page as free anyways
+}
+
+/*
+// called from reclaim to add existing free spans
+static void mi_segment_span_add_free(mi_slice_t* slice, mi_segments_tld_t* tld) {
+  mi_segment_t* segment = _mi_ptr_segment(slice);
+  mi_assert_internal(slice->xblock_size==0 && slice->slice_count>0 && slice->slice_offset==0);
+  size_t slice_index = mi_slice_index(slice);
+  mi_segment_span_free(segment,slice_index,slice->slice_count,tld);
+}
+*/
+
+static void mi_segment_span_remove_from_queue(mi_slice_t* slice, mi_segments_tld_t* tld) {
+  mi_assert_internal(slice->slice_count > 0 && slice->slice_offset==0 && slice->xblock_size==0);
+  mi_assert_internal(_mi_ptr_segment(slice)->kind != MI_SEGMENT_HUGE);
+  mi_span_queue_t* sq = mi_span_queue_for(slice->slice_count, tld);
+  mi_span_queue_delete(sq, slice);
+}
+
+// note: can be called on abandoned segments
+static mi_slice_t* mi_segment_span_free_coalesce(mi_slice_t* slice, mi_segments_tld_t* tld) {
+  mi_assert_internal(slice != NULL && slice->slice_count > 0 && slice->slice_offset == 0);
+  mi_segment_t* segment = _mi_ptr_segment(slice);
+  bool is_abandoned = mi_segment_is_abandoned(segment);
+
+  // for huge pages, just mark as free but don't add to the queues
+  if (segment->kind == MI_SEGMENT_HUGE) {
+    mi_assert_internal(segment->used == 1);  // decreased right after this call in `mi_segment_page_clear`
+    slice->xblock_size = 0;  // mark as free anyways
+    // we should mark the last slice `xblock_size=0` now to maintain invariants but we skip it to 
+    // avoid a possible cache miss (and the segment is about to be freed)
+    return slice;
+  }
+
+  // otherwise coalesce the span and add to the free span queues
+  size_t slice_count = slice->slice_count;
+  mi_slice_t* next = slice + slice->slice_count;
+  mi_assert_internal(next <= mi_segment_slices_end(segment));
+  if (next < mi_segment_slices_end(segment) && next->xblock_size==0) {
+    // free next block -- remove it from free and merge
+    mi_assert_internal(next->slice_count > 0 && next->slice_offset==0);
+    slice_count += next->slice_count; // extend
+    if (!is_abandoned) { mi_segment_span_remove_from_queue(next, tld); }
+  }
+  if (slice > segment->slices) {
+    mi_slice_t* prev = mi_slice_first(slice - 1);
+    mi_assert_internal(prev >= segment->slices);
+    if (prev->xblock_size==0) {
+      // free previous slice -- remove it from free and merge
+      mi_assert_internal(prev->slice_count > 0 && prev->slice_offset==0);
+      slice_count += prev->slice_count;
+      if (!is_abandoned) { mi_segment_span_remove_from_queue(prev, tld); }
+      slice = prev;
+    }
+  }
+
+  // and add the new free page
+  mi_segment_span_free(segment, mi_slice_index(slice), slice_count, tld);
+  return slice;
+}
+
+
+static void mi_segment_slice_split(mi_segment_t* segment, mi_slice_t* slice, size_t slice_count, mi_segments_tld_t* tld) {
+  mi_assert_internal(_mi_ptr_segment(slice)==segment);
+  mi_assert_internal(slice->slice_count >= slice_count);
+  mi_assert_internal(slice->xblock_size > 0); // no more in free queue
+  if (slice->slice_count <= slice_count) return;
+  mi_assert_internal(segment->kind != MI_SEGMENT_HUGE);
+  size_t next_index = mi_slice_index(slice) + slice_count;
+  size_t next_count = slice->slice_count - slice_count;
+  mi_segment_span_free(segment, next_index, next_count, tld);
+  slice->slice_count = (uint32_t)slice_count;
+}
+
+// Note: may still return NULL if committing the memory failed
+static mi_page_t* mi_segment_span_allocate(mi_segment_t* segment, size_t slice_index, size_t slice_count, mi_segments_tld_t* tld) {
+  mi_assert_internal(slice_index < segment->slice_entries);
+  mi_slice_t* slice = &segment->slices[slice_index];
+  mi_assert_internal(slice->xblock_size==0 || slice->xblock_size==1);
+
+  // commit before changing the slice data
+  if (!mi_segment_ensure_committed(segment, _mi_segment_page_start_from_slice(segment, slice, 0, NULL), slice_count * MI_SEGMENT_SLICE_SIZE, tld->stats)) {
+    return NULL;  // commit failed!
+  }
+
+  // convert the slices to a page
+  slice->slice_offset = 0;
+  slice->slice_count = (uint32_t)slice_count;
+  mi_assert_internal(slice->slice_count == slice_count);
+  const size_t bsize = slice_count * MI_SEGMENT_SLICE_SIZE;
+  slice->xblock_size = (uint32_t)(bsize >= MI_HUGE_BLOCK_SIZE ? MI_HUGE_BLOCK_SIZE : bsize);
+  mi_page_t*  page = mi_slice_to_page(slice);
+  mi_assert_internal(mi_page_block_size(page) == bsize);
+
+  // set slice back pointers for the first MI_MAX_SLICE_OFFSET entries
+  size_t extra = slice_count-1;
+  if (extra > MI_MAX_SLICE_OFFSET) extra = MI_MAX_SLICE_OFFSET;
+  if (slice_index + extra >= segment->slice_entries) extra = segment->slice_entries - slice_index - 1;  // huge objects may have more slices than avaiable entries in the segment->slices
+  slice++;
+  for (size_t i = 1; i <= extra; i++, slice++) {
+    slice->slice_offset = (uint32_t)(sizeof(mi_slice_t)*i);
+    slice->slice_count = 0;
+    slice->xblock_size = 1;
+  }
+
+  // and also for the last one (if not set already) (the last one is needed for coalescing)
+  // note: the cast is needed for ubsan since the index can be larger than MI_SLICES_PER_SEGMENT for huge allocations (see #543)
+  mi_slice_t* last = &((mi_slice_t*)segment->slices)[slice_index + slice_count - 1]; 
+  if (last < mi_segment_slices_end(segment) && last >= slice) {
+    last->slice_offset = (uint32_t)(sizeof(mi_slice_t)*(slice_count-1));
+    last->slice_count = 0;
+    last->xblock_size = 1;
+  }
+  
+  // and initialize the page
+  page->is_reset = false;
+  page->is_committed = true;
+  segment->used++;
+  return page;
+}
+
+static mi_page_t* mi_segments_page_find_and_allocate(size_t slice_count, mi_segments_tld_t* tld) {
+  mi_assert_internal(slice_count*MI_SEGMENT_SLICE_SIZE <= MI_LARGE_OBJ_SIZE_MAX);
+  // search from best fit up
+  mi_span_queue_t* sq = mi_span_queue_for(slice_count, tld);
+  if (slice_count == 0) slice_count = 1;
+  while (sq <= &tld->spans[MI_SEGMENT_BIN_MAX]) {
+    for (mi_slice_t* slice = sq->first; slice != NULL; slice = slice->next) {
+      if (slice->slice_count >= slice_count) {
+        // found one
+        mi_span_queue_delete(sq, slice);
+        mi_segment_t* segment = _mi_ptr_segment(slice);
+        if (slice->slice_count > slice_count) {
+          mi_segment_slice_split(segment, slice, slice_count, tld);
+        }
+        mi_assert_internal(slice != NULL && slice->slice_count == slice_count && slice->xblock_size > 0);
+        mi_page_t* page = mi_segment_span_allocate(segment, mi_slice_index(slice), slice->slice_count, tld);
+        if (page == NULL) {
+          // commit failed; return NULL but first restore the slice
+          mi_segment_span_free_coalesce(slice, tld);
+          return NULL;
+        }
+        return page;        
+      }
+    }
+    sq++;
+  }
+  // could not find a page..
+  return NULL;
+}
+
+
+/* -----------------------------------------------------------
+   Segment allocation
+----------------------------------------------------------- */
+
+// Allocate a segment from the OS aligned to `MI_SEGMENT_SIZE` .
+static mi_segment_t* mi_segment_init(mi_segment_t* segment, size_t required, mi_segments_tld_t* tld, mi_os_tld_t* os_tld, mi_page_t** huge_page)
+{
+  mi_assert_internal((required==0 && huge_page==NULL) || (required>0 && huge_page != NULL));
+  mi_assert_internal((segment==NULL) || (segment!=NULL && required==0));
+  // calculate needed sizes first
+  size_t info_slices;
+  size_t pre_size;
+  const size_t segment_slices = mi_segment_calculate_slices(required, &pre_size, &info_slices);
+  const size_t slice_entries = (segment_slices > MI_SLICES_PER_SEGMENT ? MI_SLICES_PER_SEGMENT : segment_slices);
+  const size_t segment_size = segment_slices * MI_SEGMENT_SLICE_SIZE;
+
+  // Commit eagerly only if not the first N lazy segments (to reduce impact of many threads that allocate just a little)
+  const bool eager_delay = (// !_mi_os_has_overcommit() &&             // never delay on overcommit systems
+                            _mi_current_thread_count() > 1 &&       // do not delay for the first N threads
+                            tld->count < (size_t)mi_option_get(mi_option_eager_commit_delay));
+  const bool eager = !eager_delay && mi_option_is_enabled(mi_option_eager_commit);
+  bool commit = eager || (required > 0); 
+  
+  // Try to get from our cache first
+  bool is_zero = false;
+  const bool commit_info_still_good = (segment != NULL);
+  mi_commit_mask_t commit_mask;
+  mi_commit_mask_t decommit_mask;
+  if (segment != NULL) {
+    commit_mask = segment->commit_mask;
+    decommit_mask = segment->decommit_mask;
+  }
+  else {
+    mi_commit_mask_create_empty(&commit_mask);
+    mi_commit_mask_create_empty(&decommit_mask);
+  }
+  if (segment==NULL) {
+    // Allocate the segment from the OS
+    bool mem_large = (!eager_delay && (MI_SECURE==0)); // only allow large OS pages once we are no longer lazy    
+    bool is_pinned = false;
+    size_t memid = 0;
+    segment = (mi_segment_t*)_mi_segment_cache_pop(segment_size, &commit_mask, &decommit_mask, &mem_large, &is_pinned, &is_zero, &memid, os_tld);
+    if (segment==NULL) {
+      segment = (mi_segment_t*)_mi_arena_alloc_aligned(segment_size, MI_SEGMENT_SIZE, &commit, &mem_large, &is_pinned, &is_zero, &memid, os_tld);
+      if (segment == NULL) return NULL;  // failed to allocate
+      if (commit) {
+        mi_commit_mask_create_full(&commit_mask);
+      }
+      else {
+        mi_commit_mask_create_empty(&commit_mask);
+      }
+    }    
+    mi_assert_internal(segment != NULL && (uintptr_t)segment % MI_SEGMENT_SIZE == 0);
+
+    const size_t commit_needed = _mi_divide_up(info_slices*MI_SEGMENT_SLICE_SIZE, MI_COMMIT_SIZE);
+    mi_assert_internal(commit_needed>0);
+    mi_commit_mask_t commit_needed_mask;
+    mi_commit_mask_create(0, commit_needed, &commit_needed_mask);
+    if (!mi_commit_mask_all_set(&commit_mask, &commit_needed_mask)) {
+      // at least commit the info slices
+      mi_assert_internal(commit_needed*MI_COMMIT_SIZE >= info_slices*MI_SEGMENT_SLICE_SIZE);
+      bool ok = _mi_os_commit(segment, commit_needed*MI_COMMIT_SIZE, &is_zero, tld->stats);
+      if (!ok) return NULL; // failed to commit   
+      mi_commit_mask_set(&commit_mask, &commit_needed_mask); 
+    }
+    segment->memid = memid;
+    segment->mem_is_pinned = is_pinned;
+    segment->mem_is_large = mem_large;
+    segment->mem_is_committed = mi_commit_mask_is_full(&commit_mask);
+    mi_segments_track_size((long)(segment_size), tld);
+    _mi_segment_map_allocated_at(segment);
+  }
+
+  // zero the segment info? -- not always needed as it is zero initialized from the OS 
+  mi_atomic_store_ptr_release(mi_segment_t, &segment->abandoned_next, NULL);  // tsan
+  if (!is_zero) {
+    ptrdiff_t ofs = offsetof(mi_segment_t, next);
+    size_t    prefix = offsetof(mi_segment_t, slices) - ofs;
+    memset((uint8_t*)segment+ofs, 0, prefix + sizeof(mi_slice_t)*segment_slices);
+  }
+
+  if (!commit_info_still_good) {
+    segment->commit_mask = commit_mask; // on lazy commit, the initial part is always committed
+    segment->allow_decommit = (mi_option_is_enabled(mi_option_allow_decommit) && !segment->mem_is_pinned && !segment->mem_is_large);    
+    if (segment->allow_decommit) {
+      segment->decommit_expire = _mi_clock_now() + mi_option_get(mi_option_decommit_delay);
+      segment->decommit_mask = decommit_mask;
+      mi_assert_internal(mi_commit_mask_all_set(&segment->commit_mask, &segment->decommit_mask));
+      #if MI_DEBUG>2
+      const size_t commit_needed = _mi_divide_up(info_slices*MI_SEGMENT_SLICE_SIZE, MI_COMMIT_SIZE);
+      mi_commit_mask_t commit_needed_mask;
+      mi_commit_mask_create(0, commit_needed, &commit_needed_mask);
+      mi_assert_internal(!mi_commit_mask_any_set(&segment->decommit_mask, &commit_needed_mask));
+      #endif
+    }    
+    else {
+      mi_assert_internal(mi_commit_mask_is_empty(&decommit_mask));
+      segment->decommit_expire = 0;
+      mi_commit_mask_create_empty( &segment->decommit_mask );
+      mi_assert_internal(mi_commit_mask_is_empty(&segment->decommit_mask));
+    }
+  }
+  
+
+  // initialize segment info
+  segment->segment_slices = segment_slices;
+  segment->segment_info_slices = info_slices;
+  segment->thread_id = _mi_thread_id();
+  segment->cookie = _mi_ptr_cookie(segment);
+  segment->slice_entries = slice_entries;
+  segment->kind = (required == 0 ? MI_SEGMENT_NORMAL : MI_SEGMENT_HUGE);
+
+  // memset(segment->slices, 0, sizeof(mi_slice_t)*(info_slices+1));
+  _mi_stat_increase(&tld->stats->page_committed, mi_segment_info_size(segment));
+
+  // set up guard pages
+  size_t guard_slices = 0;
+  if (MI_SECURE>0) {
+    // in secure mode, we set up a protected page in between the segment info
+    // and the page data
+    size_t os_pagesize = _mi_os_page_size();    
+    mi_assert_internal(mi_segment_info_size(segment) - os_pagesize >= pre_size);
+    _mi_os_protect((uint8_t*)segment + mi_segment_info_size(segment) - os_pagesize, os_pagesize);
+    uint8_t* end = (uint8_t*)segment + mi_segment_size(segment) - os_pagesize;
+    mi_segment_ensure_committed(segment, end, os_pagesize, tld->stats);
+    _mi_os_protect(end, os_pagesize);
+    if (slice_entries == segment_slices) segment->slice_entries--; // don't use the last slice :-(
+    guard_slices = 1;
+  }
+
+  // reserve first slices for segment info
+  mi_page_t* page0 = mi_segment_span_allocate(segment, 0, info_slices, tld);
+  mi_assert_internal(page0!=NULL); if (page0==NULL) return NULL; // cannot fail as we always commit in advance  
+  mi_assert_internal(segment->used == 1);
+  segment->used = 0; // don't count our internal slices towards usage
+  
+  // initialize initial free pages
+  if (segment->kind == MI_SEGMENT_NORMAL) { // not a huge page
+    mi_assert_internal(huge_page==NULL);
+    mi_segment_span_free(segment, info_slices, segment->slice_entries - info_slices, tld);
+  }
+  else {
+    mi_assert_internal(huge_page!=NULL);
+    mi_assert_internal(mi_commit_mask_is_empty(&segment->decommit_mask));
+    mi_assert_internal(mi_commit_mask_is_full(&segment->commit_mask));
+    *huge_page = mi_segment_span_allocate(segment, info_slices, segment_slices - info_slices - guard_slices, tld);
+    mi_assert_internal(*huge_page != NULL); // cannot fail as we commit in advance 
+  }
+
+  mi_assert_expensive(mi_segment_is_valid(segment,tld));
+  return segment;
+}
+
+
+// Allocate a segment from the OS aligned to `MI_SEGMENT_SIZE` .
+static mi_segment_t* mi_segment_alloc(size_t required, mi_segments_tld_t* tld, mi_os_tld_t* os_tld, mi_page_t** huge_page) {
+  return mi_segment_init(NULL, required, tld, os_tld, huge_page);
+}
+
+
+static void mi_segment_free(mi_segment_t* segment, bool force, mi_segments_tld_t* tld) {
+  mi_assert_internal(segment != NULL);
+  mi_assert_internal(segment->next == NULL);
+  mi_assert_internal(segment->used == 0);
+
+  // Remove the free pages
+  mi_slice_t* slice = &segment->slices[0];
+  const mi_slice_t* end = mi_segment_slices_end(segment);
+  size_t page_count = 0;
+  while (slice < end) {
+    mi_assert_internal(slice->slice_count > 0);
+    mi_assert_internal(slice->slice_offset == 0);
+    mi_assert_internal(mi_slice_index(slice)==0 || slice->xblock_size == 0); // no more used pages ..
+    if (slice->xblock_size == 0 && segment->kind != MI_SEGMENT_HUGE) {
+      mi_segment_span_remove_from_queue(slice, tld);
+    }
+    page_count++;
+    slice = slice + slice->slice_count;
+  }
+  mi_assert_internal(page_count == 2); // first page is allocated by the segment itself
+
+  // stats
+  _mi_stat_decrease(&tld->stats->page_committed, mi_segment_info_size(segment));
+
+  if (!force && mi_segment_cache_push(segment, tld)) {
+    // it is put in our cache
+  }
+  else {
+    // otherwise return it to the OS
+    mi_segment_os_free(segment,  tld);
+  }
+}
+
+
+/* -----------------------------------------------------------
+   Page Free
+----------------------------------------------------------- */
+
+static void mi_segment_abandon(mi_segment_t* segment, mi_segments_tld_t* tld);
+
+// note: can be called on abandoned pages
+static mi_slice_t* mi_segment_page_clear(mi_page_t* page, mi_segments_tld_t* tld) {
+  mi_assert_internal(page->xblock_size > 0);
+  mi_assert_internal(mi_page_all_free(page));
+  mi_segment_t* segment = _mi_ptr_segment(page);
+  mi_assert_internal(segment->used > 0);
+  
+  size_t inuse = page->capacity * mi_page_block_size(page);
+  _mi_stat_decrease(&tld->stats->page_committed, inuse);
+  _mi_stat_decrease(&tld->stats->pages, 1);
+
+  // reset the page memory to reduce memory pressure?
+  if (!segment->mem_is_pinned && !page->is_reset && mi_option_is_enabled(mi_option_page_reset)) {
+    size_t psize;
+    uint8_t* start = _mi_page_start(segment, page, &psize);
+    page->is_reset = true;
+    _mi_os_reset(start, psize, tld->stats);
+  }
+
+  // zero the page data, but not the segment fields
+  page->is_zero_init = false;
+  ptrdiff_t ofs = offsetof(mi_page_t, capacity);
+  memset((uint8_t*)page + ofs, 0, sizeof(*page) - ofs);
+  page->xblock_size = 1;
+
+  // and free it
+  mi_slice_t* slice = mi_segment_span_free_coalesce(mi_page_to_slice(page), tld);  
+  segment->used--;
+  // cannot assert segment valid as it is called during reclaim
+  // mi_assert_expensive(mi_segment_is_valid(segment, tld));
+  return slice;
+}
+
+void _mi_segment_page_free(mi_page_t* page, bool force, mi_segments_tld_t* tld)
+{
+  mi_assert(page != NULL);
+
+  mi_segment_t* segment = _mi_page_segment(page);
+  mi_assert_expensive(mi_segment_is_valid(segment,tld));
+
+  // mark it as free now
+  mi_segment_page_clear(page, tld);
+  mi_assert_expensive(mi_segment_is_valid(segment, tld));
+
+  if (segment->used == 0) {
+    // no more used pages; remove from the free list and free the segment
+    mi_segment_free(segment, force, tld);
+  }
+  else if (segment->used == segment->abandoned) {
+    // only abandoned pages; remove from free list and abandon
+    mi_segment_abandon(segment,tld);
+  }
+}
+
+
+/* -----------------------------------------------------------
+Abandonment
+
+When threads terminate, they can leave segments with
+live blocks (reachable through other threads). Such segments
+are "abandoned" and will be reclaimed by other threads to
+reuse their pages and/or free them eventually
+
+We maintain a global list of abandoned segments that are
+reclaimed on demand. Since this is shared among threads
+the implementation needs to avoid the A-B-A problem on
+popping abandoned segments: <https://en.wikipedia.org/wiki/ABA_problem>
+We use tagged pointers to avoid accidentially identifying
+reused segments, much like stamped references in Java.
+Secondly, we maintain a reader counter to avoid resetting
+or decommitting segments that have a pending read operation.
+
+Note: the current implementation is one possible design;
+another way might be to keep track of abandoned segments
+in the arenas/segment_cache's. This would have the advantage of keeping
+all concurrent code in one place and not needing to deal
+with ABA issues. The drawback is that it is unclear how to
+scan abandoned segments efficiently in that case as they
+would be spread among all other segments in the arenas.
+----------------------------------------------------------- */
+
+// Use the bottom 20-bits (on 64-bit) of the aligned segment pointers
+// to put in a tag that increments on update to avoid the A-B-A problem.
+#define MI_TAGGED_MASK   MI_SEGMENT_MASK
+typedef uintptr_t        mi_tagged_segment_t;
+
+static mi_segment_t* mi_tagged_segment_ptr(mi_tagged_segment_t ts) {
+  return (mi_segment_t*)(ts & ~MI_TAGGED_MASK);
+}
+
+static mi_tagged_segment_t mi_tagged_segment(mi_segment_t* segment, mi_tagged_segment_t ts) {
+  mi_assert_internal(((uintptr_t)segment & MI_TAGGED_MASK) == 0);
+  uintptr_t tag = ((ts & MI_TAGGED_MASK) + 1) & MI_TAGGED_MASK;
+  return ((uintptr_t)segment | tag);
+}
+
+// This is a list of visited abandoned pages that were full at the time.
+// this list migrates to `abandoned` when that becomes NULL. The use of
+// this list reduces contention and the rate at which segments are visited.
+static mi_decl_cache_align _Atomic(mi_segment_t*)       abandoned_visited; // = NULL
+
+// The abandoned page list (tagged as it supports pop)
+static mi_decl_cache_align _Atomic(mi_tagged_segment_t) abandoned;         // = NULL
+
+// Maintain these for debug purposes (these counts may be a bit off)
+static mi_decl_cache_align _Atomic(size_t)           abandoned_count; 
+static mi_decl_cache_align _Atomic(size_t)           abandoned_visited_count;
+
+// We also maintain a count of current readers of the abandoned list
+// in order to prevent resetting/decommitting segment memory if it might
+// still be read.
+static mi_decl_cache_align _Atomic(size_t)           abandoned_readers; // = 0
+
+// Push on the visited list
+static void mi_abandoned_visited_push(mi_segment_t* segment) {
+  mi_assert_internal(segment->thread_id == 0);
+  mi_assert_internal(mi_atomic_load_ptr_relaxed(mi_segment_t,&segment->abandoned_next) == NULL);
+  mi_assert_internal(segment->next == NULL);
+  mi_assert_internal(segment->used > 0);
+  mi_segment_t* anext = mi_atomic_load_ptr_relaxed(mi_segment_t, &abandoned_visited);
+  do {
+    mi_atomic_store_ptr_release(mi_segment_t, &segment->abandoned_next, anext);
+  } while (!mi_atomic_cas_ptr_weak_release(mi_segment_t, &abandoned_visited, &anext, segment));
+  mi_atomic_increment_relaxed(&abandoned_visited_count);
+}
+
+// Move the visited list to the abandoned list.
+static bool mi_abandoned_visited_revisit(void)
+{
+  // quick check if the visited list is empty
+  if (mi_atomic_load_ptr_relaxed(mi_segment_t, &abandoned_visited) == NULL) return false;
+
+  // grab the whole visited list
+  mi_segment_t* first = mi_atomic_exchange_ptr_acq_rel(mi_segment_t, &abandoned_visited, NULL);
+  if (first == NULL) return false;
+
+  // first try to swap directly if the abandoned list happens to be NULL
+  mi_tagged_segment_t afirst;
+  mi_tagged_segment_t ts = mi_atomic_load_relaxed(&abandoned);
+  if (mi_tagged_segment_ptr(ts)==NULL) {
+    size_t count = mi_atomic_load_relaxed(&abandoned_visited_count);
+    afirst = mi_tagged_segment(first, ts);
+    if (mi_atomic_cas_strong_acq_rel(&abandoned, &ts, afirst)) {
+      mi_atomic_add_relaxed(&abandoned_count, count);
+      mi_atomic_sub_relaxed(&abandoned_visited_count, count);
+      return true;
+    }
+  }
+
+  // find the last element of the visited list: O(n)
+  mi_segment_t* last = first;
+  mi_segment_t* next;
+  while ((next = mi_atomic_load_ptr_relaxed(mi_segment_t, &last->abandoned_next)) != NULL) {
+    last = next;
+  }
+
+  // and atomically prepend to the abandoned list
+  // (no need to increase the readers as we don't access the abandoned segments)
+  mi_tagged_segment_t anext = mi_atomic_load_relaxed(&abandoned);
+  size_t count;
+  do {
+    count = mi_atomic_load_relaxed(&abandoned_visited_count);
+    mi_atomic_store_ptr_release(mi_segment_t, &last->abandoned_next, mi_tagged_segment_ptr(anext));
+    afirst = mi_tagged_segment(first, anext);
+  } while (!mi_atomic_cas_weak_release(&abandoned, &anext, afirst));
+  mi_atomic_add_relaxed(&abandoned_count, count);
+  mi_atomic_sub_relaxed(&abandoned_visited_count, count);
+  return true;
+}
+
+// Push on the abandoned list.
+static void mi_abandoned_push(mi_segment_t* segment) {
+  mi_assert_internal(segment->thread_id == 0);
+  mi_assert_internal(mi_atomic_load_ptr_relaxed(mi_segment_t, &segment->abandoned_next) == NULL);
+  mi_assert_internal(segment->next == NULL);
+  mi_assert_internal(segment->used > 0);
+  mi_tagged_segment_t next;
+  mi_tagged_segment_t ts = mi_atomic_load_relaxed(&abandoned);
+  do {
+    mi_atomic_store_ptr_release(mi_segment_t, &segment->abandoned_next, mi_tagged_segment_ptr(ts));
+    next = mi_tagged_segment(segment, ts);
+  } while (!mi_atomic_cas_weak_release(&abandoned, &ts, next));
+  mi_atomic_increment_relaxed(&abandoned_count);
+}
+
+// Wait until there are no more pending reads on segments that used to be in the abandoned list
+// called for example from `arena.c` before decommitting
+void _mi_abandoned_await_readers(void) {
+  size_t n;
+  do {
+    n = mi_atomic_load_acquire(&abandoned_readers);
+    if (n != 0) mi_atomic_yield();
+  } while (n != 0);
+}
+
+// Pop from the abandoned list
+static mi_segment_t* mi_abandoned_pop(void) {
+  mi_segment_t* segment;
+  // Check efficiently if it is empty (or if the visited list needs to be moved)
+  mi_tagged_segment_t ts = mi_atomic_load_relaxed(&abandoned);
+  segment = mi_tagged_segment_ptr(ts);
+  if (mi_likely(segment == NULL)) {
+    if (mi_likely(!mi_abandoned_visited_revisit())) { // try to swap in the visited list on NULL
+      return NULL;
+    }
+  }
+
+  // Do a pop. We use a reader count to prevent
+  // a segment to be decommitted while a read is still pending,
+  // and a tagged pointer to prevent A-B-A link corruption.
+  // (this is called from `region.c:_mi_mem_free` for example)
+  mi_atomic_increment_relaxed(&abandoned_readers);  // ensure no segment gets decommitted
+  mi_tagged_segment_t next = 0;
+  ts = mi_atomic_load_acquire(&abandoned);
+  do {
+    segment = mi_tagged_segment_ptr(ts);
+    if (segment != NULL) {
+      mi_segment_t* anext = mi_atomic_load_ptr_relaxed(mi_segment_t, &segment->abandoned_next);
+      next = mi_tagged_segment(anext, ts); // note: reads the segment's `abandoned_next` field so should not be decommitted
+    }
+  } while (segment != NULL && !mi_atomic_cas_weak_acq_rel(&abandoned, &ts, next));
+  mi_atomic_decrement_relaxed(&abandoned_readers);  // release reader lock
+  if (segment != NULL) {
+    mi_atomic_store_ptr_release(mi_segment_t, &segment->abandoned_next, NULL);
+    mi_atomic_decrement_relaxed(&abandoned_count);
+  }
+  return segment;
+}
+
+/* -----------------------------------------------------------
+   Abandon segment/page
+----------------------------------------------------------- */
+
+static void mi_segment_abandon(mi_segment_t* segment, mi_segments_tld_t* tld) {
+  mi_assert_internal(segment->used == segment->abandoned);
+  mi_assert_internal(segment->used > 0);
+  mi_assert_internal(mi_atomic_load_ptr_relaxed(mi_segment_t, &segment->abandoned_next) == NULL);
+  mi_assert_internal(segment->abandoned_visits == 0);
+  mi_assert_expensive(mi_segment_is_valid(segment,tld));
+  
+  // remove the free pages from the free page queues
+  mi_slice_t* slice = &segment->slices[0];
+  const mi_slice_t* end = mi_segment_slices_end(segment);
+  while (slice < end) {
+    mi_assert_internal(slice->slice_count > 0);
+    mi_assert_internal(slice->slice_offset == 0);
+    if (slice->xblock_size == 0) { // a free page
+      mi_segment_span_remove_from_queue(slice,tld);
+      slice->xblock_size = 0; // but keep it free
+    }
+    slice = slice + slice->slice_count;
+  }
+
+  // perform delayed decommits
+  mi_segment_delayed_decommit(segment, mi_option_is_enabled(mi_option_abandoned_page_decommit) /* force? */, tld->stats);    
+  
+  // all pages in the segment are abandoned; add it to the abandoned list
+  _mi_stat_increase(&tld->stats->segments_abandoned, 1);
+  mi_segments_track_size(-((long)mi_segment_size(segment)), tld);
+  segment->thread_id = 0;
+  mi_atomic_store_ptr_release(mi_segment_t, &segment->abandoned_next, NULL);
+  segment->abandoned_visits = 1;   // from 0 to 1 to signify it is abandoned
+  mi_abandoned_push(segment);
+}
+
+void _mi_segment_page_abandon(mi_page_t* page, mi_segments_tld_t* tld) {
+  mi_assert(page != NULL);
+  mi_assert_internal(mi_page_thread_free_flag(page)==MI_NEVER_DELAYED_FREE);
+  mi_assert_internal(mi_page_heap(page) == NULL);
+  mi_segment_t* segment = _mi_page_segment(page);
+
+  mi_assert_expensive(mi_segment_is_valid(segment,tld));
+  segment->abandoned++;  
+
+  _mi_stat_increase(&tld->stats->pages_abandoned, 1);
+  mi_assert_internal(segment->abandoned <= segment->used);
+  if (segment->used == segment->abandoned) {
+    // all pages are abandoned, abandon the entire segment
+    mi_segment_abandon(segment, tld);
+  }
+}
+
+/* -----------------------------------------------------------
+  Reclaim abandoned pages
+----------------------------------------------------------- */
+
+static mi_slice_t* mi_slices_start_iterate(mi_segment_t* segment, const mi_slice_t** end) {
+  mi_slice_t* slice = &segment->slices[0];
+  *end = mi_segment_slices_end(segment);
+  mi_assert_internal(slice->slice_count>0 && slice->xblock_size>0); // segment allocated page
+  slice = slice + slice->slice_count; // skip the first segment allocated page
+  return slice;
+}
+
+// Possibly free pages and check if free space is available
+static bool mi_segment_check_free(mi_segment_t* segment, size_t slices_needed, size_t block_size, mi_segments_tld_t* tld) 
+{
+  mi_assert_internal(block_size < MI_HUGE_BLOCK_SIZE);
+  mi_assert_internal(mi_segment_is_abandoned(segment));
+  bool has_page = false;
+  
+  // for all slices
+  const mi_slice_t* end;
+  mi_slice_t* slice = mi_slices_start_iterate(segment, &end);
+  while (slice < end) {
+    mi_assert_internal(slice->slice_count > 0);
+    mi_assert_internal(slice->slice_offset == 0);
+    if (mi_slice_is_used(slice)) { // used page
+      // ensure used count is up to date and collect potential concurrent frees
+      mi_page_t* const page = mi_slice_to_page(slice);
+      _mi_page_free_collect(page, false);
+      if (mi_page_all_free(page)) {
+        // if this page is all free now, free it without adding to any queues (yet) 
+        mi_assert_internal(page->next == NULL && page->prev==NULL);
+        _mi_stat_decrease(&tld->stats->pages_abandoned, 1);
+        segment->abandoned--;
+        slice = mi_segment_page_clear(page, tld); // re-assign slice due to coalesce!
+        mi_assert_internal(!mi_slice_is_used(slice));
+        if (slice->slice_count >= slices_needed) {
+          has_page = true;
+        }
+      }
+      else {
+        if (page->xblock_size == block_size && mi_page_has_any_available(page)) {
+          // a page has available free blocks of the right size
+          has_page = true;
+        }
+      }      
+    }
+    else {
+      // empty span
+      if (slice->slice_count >= slices_needed) {
+        has_page = true;
+      }
+    }
+    slice = slice + slice->slice_count;
+  }
+  return has_page;
+}
+
+// Reclaim an abandoned segment; returns NULL if the segment was freed
+// set `right_page_reclaimed` to `true` if it reclaimed a page of the right `block_size` that was not full.
+static mi_segment_t* mi_segment_reclaim(mi_segment_t* segment, mi_heap_t* heap, size_t requested_block_size, bool* right_page_reclaimed, mi_segments_tld_t* tld) {
+  mi_assert_internal(mi_atomic_load_ptr_relaxed(mi_segment_t, &segment->abandoned_next) == NULL);
+  mi_assert_expensive(mi_segment_is_valid(segment, tld));
+  if (right_page_reclaimed != NULL) { *right_page_reclaimed = false; }
+
+  segment->thread_id = _mi_thread_id();
+  segment->abandoned_visits = 0;
+  mi_segments_track_size((long)mi_segment_size(segment), tld);
+  mi_assert_internal(segment->next == NULL);
+  _mi_stat_decrease(&tld->stats->segments_abandoned, 1);
+  
+  // for all slices
+  const mi_slice_t* end;
+  mi_slice_t* slice = mi_slices_start_iterate(segment, &end);
+  while (slice < end) {
+    mi_assert_internal(slice->slice_count > 0);
+    mi_assert_internal(slice->slice_offset == 0);
+    if (mi_slice_is_used(slice)) {
+      // in use: reclaim the page in our heap
+      mi_page_t* page = mi_slice_to_page(slice);
+      mi_assert_internal(!page->is_reset);
+      mi_assert_internal(page->is_committed);
+      mi_assert_internal(mi_page_thread_free_flag(page)==MI_NEVER_DELAYED_FREE);
+      mi_assert_internal(mi_page_heap(page) == NULL);
+      mi_assert_internal(page->next == NULL && page->prev==NULL);
+      _mi_stat_decrease(&tld->stats->pages_abandoned, 1);
+      segment->abandoned--;
+      // set the heap again and allow delayed free again
+      mi_page_set_heap(page, heap);
+      _mi_page_use_delayed_free(page, MI_USE_DELAYED_FREE, true); // override never (after heap is set)
+      _mi_page_free_collect(page, false); // ensure used count is up to date
+      if (mi_page_all_free(page)) {
+        // if everything free by now, free the page
+        slice = mi_segment_page_clear(page, tld);   // set slice again due to coalesceing
+      }
+      else {
+        // otherwise reclaim it into the heap
+        _mi_page_reclaim(heap, page);
+        if (requested_block_size == page->xblock_size && mi_page_has_any_available(page)) {
+          if (right_page_reclaimed != NULL) { *right_page_reclaimed = true; }
+        }
+      }
+    }
+    else {
+      // the span is free, add it to our page queues
+      slice = mi_segment_span_free_coalesce(slice, tld); // set slice again due to coalesceing
+    }
+    mi_assert_internal(slice->slice_count>0 && slice->slice_offset==0);
+    slice = slice + slice->slice_count;
+  }
+
+  mi_assert(segment->abandoned == 0);
+  if (segment->used == 0) {  // due to page_clear
+    mi_assert_internal(right_page_reclaimed == NULL || !(*right_page_reclaimed));
+    mi_segment_free(segment, false, tld);
+    return NULL;
+  }
+  else {
+    return segment;
+  }
+}
+
+
+void _mi_abandoned_reclaim_all(mi_heap_t* heap, mi_segments_tld_t* tld) {
+  mi_segment_t* segment;
+  while ((segment = mi_abandoned_pop()) != NULL) {
+    mi_segment_reclaim(segment, heap, 0, NULL, tld);
+  }
+}
+
+static mi_segment_t* mi_segment_try_reclaim(mi_heap_t* heap, size_t needed_slices, size_t block_size, bool* reclaimed, mi_segments_tld_t* tld)
+{
+  *reclaimed = false;
+  mi_segment_t* segment;
+  int max_tries = 8;     // limit the work to bound allocation times
+  while ((max_tries-- > 0) && ((segment = mi_abandoned_pop()) != NULL)) {
+    segment->abandoned_visits++;
+    bool has_page = mi_segment_check_free(segment,needed_slices,block_size,tld); // try to free up pages (due to concurrent frees)
+    if (segment->used == 0) {
+      // free the segment (by forced reclaim) to make it available to other threads.
+      // note1: we prefer to free a segment as that might lead to reclaiming another
+      // segment that is still partially used.
+      // note2: we could in principle optimize this by skipping reclaim and directly
+      // freeing but that would violate some invariants temporarily)
+      mi_segment_reclaim(segment, heap, 0, NULL, tld);
+    }
+    else if (has_page) {
+      // found a large enough free span, or a page of the right block_size with free space 
+      // we return the result of reclaim (which is usually `segment`) as it might free
+      // the segment due to concurrent frees (in which case `NULL` is returned).
+      return mi_segment_reclaim(segment, heap, block_size, reclaimed, tld);
+    }
+    else if (segment->abandoned_visits > 3) {  
+      // always reclaim on 3rd visit to limit the abandoned queue length.
+      mi_segment_reclaim(segment, heap, 0, NULL, tld);
+    }
+    else {
+      // otherwise, push on the visited list so it gets not looked at too quickly again
+      mi_segment_delayed_decommit(segment, true /* force? */, tld->stats); // forced decommit if needed as we may not visit soon again
+      mi_abandoned_visited_push(segment);
+    }
+  }
+  return NULL;
+}
+
+
+void _mi_abandoned_collect(mi_heap_t* heap, bool force, mi_segments_tld_t* tld)
+{
+  mi_segment_t* segment;
+  int max_tries = (force ? 16*1024 : 1024); // limit latency
+  if (force) {
+    mi_abandoned_visited_revisit(); 
+  }
+  while ((max_tries-- > 0) && ((segment = mi_abandoned_pop()) != NULL)) {
+    mi_segment_check_free(segment,0,0,tld); // try to free up pages (due to concurrent frees)
+    if (segment->used == 0) {
+      // free the segment (by forced reclaim) to make it available to other threads.
+      // note: we could in principle optimize this by skipping reclaim and directly
+      // freeing but that would violate some invariants temporarily)
+      mi_segment_reclaim(segment, heap, 0, NULL, tld);
+    }
+    else {
+      // otherwise, decommit if needed and push on the visited list 
+      // note: forced decommit can be expensive if many threads are destroyed/created as in mstress.
+      mi_segment_delayed_decommit(segment, force, tld->stats);
+      mi_abandoned_visited_push(segment);
+    }
+  }
+}
+
+/* -----------------------------------------------------------
+   Reclaim or allocate
+----------------------------------------------------------- */
+
+static mi_segment_t* mi_segment_reclaim_or_alloc(mi_heap_t* heap, size_t needed_slices, size_t block_size, mi_segments_tld_t* tld, mi_os_tld_t* os_tld) 
+{
+  mi_assert_internal(block_size < MI_HUGE_BLOCK_SIZE);
+  mi_assert_internal(block_size <= MI_LARGE_OBJ_SIZE_MAX);
+  // 1. try to get a segment from our cache
+  mi_segment_t* segment = mi_segment_cache_pop(MI_SEGMENT_SIZE, tld);
+  if (segment != NULL) {
+    mi_segment_init(segment, 0, tld, os_tld, NULL);
+    return segment;
+  }
+  // 2. try to reclaim an abandoned segment
+  bool reclaimed;
+  segment = mi_segment_try_reclaim(heap, needed_slices, block_size, &reclaimed, tld);
+  if (reclaimed) {
+    // reclaimed the right page right into the heap
+    mi_assert_internal(segment != NULL);
+    return NULL; // pretend out-of-memory as the page will be in the page queue of the heap with available blocks
+  }
+  else if (segment != NULL) {
+    // reclaimed a segment with a large enough empty span in it
+    return segment;
+  }
+  // 3. otherwise allocate a fresh segment
+  return mi_segment_alloc(0, tld, os_tld, NULL);  
+}
+
+
+/* -----------------------------------------------------------
+   Page allocation
+----------------------------------------------------------- */
+
+static mi_page_t* mi_segments_page_alloc(mi_heap_t* heap, mi_page_kind_t page_kind, size_t required, size_t block_size, mi_segments_tld_t* tld, mi_os_tld_t* os_tld)
+{
+  mi_assert_internal(required <= MI_LARGE_OBJ_SIZE_MAX && page_kind <= MI_PAGE_LARGE);
+
+  // find a free page
+  size_t page_size = _mi_align_up(required, (required > MI_MEDIUM_PAGE_SIZE ? MI_MEDIUM_PAGE_SIZE : MI_SEGMENT_SLICE_SIZE));
+  size_t slices_needed = page_size / MI_SEGMENT_SLICE_SIZE;
+  mi_assert_internal(slices_needed * MI_SEGMENT_SLICE_SIZE == page_size);
+  mi_page_t* page = mi_segments_page_find_and_allocate(slices_needed, tld); //(required <= MI_SMALL_SIZE_MAX ? 0 : slices_needed), tld);
+  if (page==NULL) {
+    // no free page, allocate a new segment and try again
+    if (mi_segment_reclaim_or_alloc(heap, slices_needed, block_size, tld, os_tld) == NULL) {
+      // OOM or reclaimed a good page in the heap
+      return NULL;  
+    }
+    else {
+      // otherwise try again
+      return mi_segments_page_alloc(heap, page_kind, required, block_size, tld, os_tld);
+    }
+  }
+  mi_assert_internal(page != NULL && page->slice_count*MI_SEGMENT_SLICE_SIZE == page_size);
+  mi_assert_internal(_mi_ptr_segment(page)->thread_id == _mi_thread_id());
+  mi_segment_delayed_decommit(_mi_ptr_segment(page), false, tld->stats);
+  return page;
+}
+
+
+
+/* -----------------------------------------------------------
+   Huge page allocation
+----------------------------------------------------------- */
+
+static mi_page_t* mi_segment_huge_page_alloc(size_t size, mi_segments_tld_t* tld, mi_os_tld_t* os_tld)
+{
+  mi_page_t* page = NULL;
+  mi_segment_t* segment = mi_segment_alloc(size,tld,os_tld,&page);
+  if (segment == NULL || page==NULL) return NULL;
+  mi_assert_internal(segment->used==1);
+  mi_assert_internal(mi_page_block_size(page) >= size);  
+  segment->thread_id = 0; // huge segments are immediately abandoned
+  return page;
+}
+
+// free huge block from another thread
+void _mi_segment_huge_page_free(mi_segment_t* segment, mi_page_t* page, mi_block_t* block) {
+  // huge page segments are always abandoned and can be freed immediately by any thread
+  mi_assert_internal(segment->kind==MI_SEGMENT_HUGE);
+  mi_assert_internal(segment == _mi_page_segment(page));
+  mi_assert_internal(mi_atomic_load_relaxed(&segment->thread_id)==0);
+
+  // claim it and free
+  mi_heap_t* heap = mi_heap_get_default(); // issue #221; don't use the internal get_default_heap as we need to ensure the thread is initialized.
+  // paranoia: if this it the last reference, the cas should always succeed
+  size_t expected_tid = 0;
+  if (mi_atomic_cas_strong_acq_rel(&segment->thread_id, &expected_tid, heap->thread_id)) {
+    mi_block_set_next(page, block, page->free);
+    page->free = block;
+    page->used--;
+    page->is_zero = false;
+    mi_assert(page->used == 0);
+    mi_tld_t* tld = heap->tld;
+    _mi_segment_page_free(page, true, &tld->segments);
+  }
+#if (MI_DEBUG!=0)
+  else {
+    mi_assert_internal(false);
+  }
+#endif
+}
+
+/* -----------------------------------------------------------
+   Page allocation and free
+----------------------------------------------------------- */
+mi_page_t* _mi_segment_page_alloc(mi_heap_t* heap, size_t block_size, mi_segments_tld_t* tld, mi_os_tld_t* os_tld) {
+  mi_page_t* page;
+  if (block_size <= MI_SMALL_OBJ_SIZE_MAX) {
+    page = mi_segments_page_alloc(heap,MI_PAGE_SMALL,block_size,block_size,tld,os_tld);
+  }
+  else if (block_size <= MI_MEDIUM_OBJ_SIZE_MAX) {
+    page = mi_segments_page_alloc(heap,MI_PAGE_MEDIUM,MI_MEDIUM_PAGE_SIZE,block_size,tld, os_tld);
+  }
+  else if (block_size <= MI_LARGE_OBJ_SIZE_MAX) {
+    page = mi_segments_page_alloc(heap,MI_PAGE_LARGE,block_size,block_size,tld, os_tld);
+  }
+  else {
+    page = mi_segment_huge_page_alloc(block_size,tld,os_tld);
+  }
+  mi_assert_expensive(page == NULL || mi_segment_is_valid(_mi_page_segment(page),tld));
+  return page;
+}
+
+
diff --git a/Objects/mimalloc/static.c b/Objects/mimalloc/static.c
new file mode 100644
index 0000000000000..5b34ddbb6ce0b
--- /dev/null
+++ b/Objects/mimalloc/static.c
@@ -0,0 +1,39 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2020, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+#ifndef _DEFAULT_SOURCE
+#define _DEFAULT_SOURCE
+#endif
+#if defined(__sun)
+// same remarks as os.c for the static's context.
+#undef _XOPEN_SOURCE
+#undef _POSIX_C_SOURCE
+#endif
+
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+
+// For a static override we create a single object file
+// containing the whole library. If it is linked first
+// it will override all the standard library allocation
+// functions (on Unix's).
+#include "stats.c"
+#include "random.c"
+#include "os.c"
+#include "bitmap.c"
+#include "arena.c"
+#include "segment-cache.c"
+#include "segment.c"
+#include "page.c"
+#include "heap.c"
+#include "alloc.c"
+#include "alloc-aligned.c"
+#include "alloc-posix.c"
+#if MI_OSX_ZONE
+#include "alloc-override-osx.c"
+#endif
+#include "init.c"
+#include "options.c"
diff --git a/Objects/mimalloc/stats.c b/Objects/mimalloc/stats.c
new file mode 100644
index 0000000000000..134a7bcb6b977
--- /dev/null
+++ b/Objects/mimalloc/stats.c
@@ -0,0 +1,584 @@
+/* ----------------------------------------------------------------------------
+Copyright (c) 2018-2021, Microsoft Research, Daan Leijen
+This is free software; you can redistribute it and/or modify it under the
+terms of the MIT license. A copy of the license can be found in the file
+"LICENSE" at the root of this distribution.
+-----------------------------------------------------------------------------*/
+#include "mimalloc.h"
+#include "mimalloc-internal.h"
+#include "mimalloc-atomic.h"
+
+#include <stdio.h>  // fputs, stderr
+#include <string.h> // memset
+
+#if defined(_MSC_VER) && (_MSC_VER < 1920)
+#pragma warning(disable:4204)  // non-constant aggregate initializer
+#endif
+
+/* -----------------------------------------------------------
+  Statistics operations
+----------------------------------------------------------- */
+
+static bool mi_is_in_main(void* stat) {
+  return ((uint8_t*)stat >= (uint8_t*)&_mi_stats_main
+         && (uint8_t*)stat < ((uint8_t*)&_mi_stats_main + sizeof(mi_stats_t)));  
+}
+
+static void mi_stat_update(mi_stat_count_t* stat, int64_t amount) {
+  if (amount == 0) return;
+  if (mi_is_in_main(stat))
+  {
+    // add atomically (for abandoned pages)
+    int64_t current = mi_atomic_addi64_relaxed(&stat->current, amount);
+    mi_atomic_maxi64_relaxed(&stat->peak, current + amount);
+    if (amount > 0) {
+      mi_atomic_addi64_relaxed(&stat->allocated,amount);
+    }
+    else {
+      mi_atomic_addi64_relaxed(&stat->freed, -amount);
+    }
+  }
+  else {
+    // add thread local
+    stat->current += amount;
+    if (stat->current > stat->peak) stat->peak = stat->current;
+    if (amount > 0) {
+      stat->allocated += amount;
+    }
+    else {
+      stat->freed += -amount;
+    }
+  }
+}
+
+void _mi_stat_counter_increase(mi_stat_counter_t* stat, size_t amount) {  
+  if (mi_is_in_main(stat)) {
+    mi_atomic_addi64_relaxed( &stat->count, 1 );
+    mi_atomic_addi64_relaxed( &stat->total, (int64_t)amount );
+  }
+  else {
+    stat->count++;
+    stat->total += amount;
+  }
+}
+
+void _mi_stat_increase(mi_stat_count_t* stat, size_t amount) {
+  mi_stat_update(stat, (int64_t)amount);
+}
+
+void _mi_stat_decrease(mi_stat_count_t* stat, size_t amount) {
+  mi_stat_update(stat, -((int64_t)amount));
+}
+
+// must be thread safe as it is called from stats_merge
+static void mi_stat_add(mi_stat_count_t* stat, const mi_stat_count_t* src, int64_t unit) {
+  if (stat==src) return;
+  if (src->allocated==0 && src->freed==0) return;
+  mi_atomic_addi64_relaxed( &stat->allocated, src->allocated * unit);
+  mi_atomic_addi64_relaxed( &stat->current, src->current * unit);
+  mi_atomic_addi64_relaxed( &stat->freed, src->freed * unit);
+  // peak scores do not work across threads.. 
+  mi_atomic_addi64_relaxed( &stat->peak, src->peak * unit);
+}
+
+static void mi_stat_counter_add(mi_stat_counter_t* stat, const mi_stat_counter_t* src, int64_t unit) {
+  if (stat==src) return;
+  mi_atomic_addi64_relaxed( &stat->total, src->total * unit);
+  mi_atomic_addi64_relaxed( &stat->count, src->count * unit);
+}
+
+// must be thread safe as it is called from stats_merge
+static void mi_stats_add(mi_stats_t* stats, const mi_stats_t* src) {
+  if (stats==src) return;
+  mi_stat_add(&stats->segments, &src->segments,1);
+  mi_stat_add(&stats->pages, &src->pages,1);
+  mi_stat_add(&stats->reserved, &src->reserved, 1);
+  mi_stat_add(&stats->committed, &src->committed, 1);
+  mi_stat_add(&stats->reset, &src->reset, 1);
+  mi_stat_add(&stats->page_committed, &src->page_committed, 1);
+
+  mi_stat_add(&stats->pages_abandoned, &src->pages_abandoned, 1);
+  mi_stat_add(&stats->segments_abandoned, &src->segments_abandoned, 1);
+  mi_stat_add(&stats->threads, &src->threads, 1);
+
+  mi_stat_add(&stats->malloc, &src->malloc, 1);
+  mi_stat_add(&stats->segments_cache, &src->segments_cache, 1);
+  mi_stat_add(&stats->normal, &src->normal, 1);
+  mi_stat_add(&stats->huge, &src->huge, 1);
+  mi_stat_add(&stats->large, &src->large, 1);
+
+  mi_stat_counter_add(&stats->pages_extended, &src->pages_extended, 1);
+  mi_stat_counter_add(&stats->mmap_calls, &src->mmap_calls, 1);
+  mi_stat_counter_add(&stats->commit_calls, &src->commit_calls, 1);
+
+  mi_stat_counter_add(&stats->page_no_retire, &src->page_no_retire, 1);
+  mi_stat_counter_add(&stats->searches, &src->searches, 1);
+  mi_stat_counter_add(&stats->normal_count, &src->normal_count, 1);
+  mi_stat_counter_add(&stats->huge_count, &src->huge_count, 1);
+  mi_stat_counter_add(&stats->large_count, &src->large_count, 1);
+#if MI_STAT>1
+  for (size_t i = 0; i <= MI_BIN_HUGE; i++) {
+    if (src->normal_bins[i].allocated > 0 || src->normal_bins[i].freed > 0) {
+      mi_stat_add(&stats->normal_bins[i], &src->normal_bins[i], 1);
+    }
+  }
+#endif
+}
+
+/* -----------------------------------------------------------
+  Display statistics
+----------------------------------------------------------- */
+
+// unit > 0 : size in binary bytes 
+// unit == 0: count as decimal
+// unit < 0 : count in binary
+static void mi_printf_amount(int64_t n, int64_t unit, mi_output_fun* out, void* arg, const char* fmt) {
+  char buf[32]; buf[0] = 0;  
+  int  len = 32;
+  const char* suffix = (unit <= 0 ? " " : "B");
+  const int64_t base = (unit == 0 ? 1000 : 1024);
+  if (unit>0) n *= unit;
+
+  const int64_t pos = (n < 0 ? -n : n);
+  if (pos < base) {
+    if (n!=1 || suffix[0] != 'B') {  // skip printing 1 B for the unit column
+      snprintf(buf, len, "%d %-3s", (int)n, (n==0 ? "" : suffix));
+    }
+  }
+  else {
+    int64_t divider = base;    
+    const char* magnitude = "K";
+    if (pos >= divider*base) { divider *= base; magnitude = "M"; }
+    if (pos >= divider*base) { divider *= base; magnitude = "G"; }
+    const int64_t tens = (n / (divider/10));
+    const long whole = (long)(tens/10);
+    const long frac1 = (long)(tens%10);
+    char unitdesc[8];
+    snprintf(unitdesc, 8, "%s%s%s", magnitude, (base==1024 ? "i" : ""), suffix);
+    snprintf(buf, len, "%ld.%ld %-3s", whole, (frac1 < 0 ? -frac1 : frac1), unitdesc);
+  }
+  _mi_fprintf(out, arg, (fmt==NULL ? "%11s" : fmt), buf);
+}
+
+
+static void mi_print_amount(int64_t n, int64_t unit, mi_output_fun* out, void* arg) {
+  mi_printf_amount(n,unit,out,arg,NULL);
+}
+
+static void mi_print_count(int64_t n, int64_t unit, mi_output_fun* out, void* arg) {
+  if (unit==1) _mi_fprintf(out, arg, "%11s"," ");
+          else mi_print_amount(n,0,out,arg);
+}
+
+static void mi_stat_print(const mi_stat_count_t* stat, const char* msg, int64_t unit, mi_output_fun* out, void* arg ) {
+  _mi_fprintf(out, arg,"%10s:", msg);
+  if (unit>0) {
+    mi_print_amount(stat->peak, unit, out, arg);
+    mi_print_amount(stat->allocated, unit, out, arg);
+    mi_print_amount(stat->freed, unit, out, arg);
+    mi_print_amount(stat->current, unit, out, arg);
+    mi_print_amount(unit, 1, out, arg);
+    mi_print_count(stat->allocated, unit, out, arg);
+    if (stat->allocated > stat->freed)
+      _mi_fprintf(out, arg, "  not all freed!\n");
+    else
+      _mi_fprintf(out, arg, "  ok\n");
+  }
+  else if (unit<0) {
+    mi_print_amount(stat->peak, -1, out, arg);
+    mi_print_amount(stat->allocated, -1, out, arg);
+    mi_print_amount(stat->freed, -1, out, arg);
+    mi_print_amount(stat->current, -1, out, arg);
+    if (unit==-1) {
+      _mi_fprintf(out, arg, "%22s", "");
+    }
+    else {
+      mi_print_amount(-unit, 1, out, arg);
+      mi_print_count((stat->allocated / -unit), 0, out, arg);
+    }
+    if (stat->allocated > stat->freed)
+      _mi_fprintf(out, arg, "  not all freed!\n");
+    else
+      _mi_fprintf(out, arg, "  ok\n");
+  }
+  else {
+    mi_print_amount(stat->peak, 1, out, arg);
+    mi_print_amount(stat->allocated, 1, out, arg);
+    _mi_fprintf(out, arg, "%11s", " ");  // no freed 
+    mi_print_amount(stat->current, 1, out, arg);
+    _mi_fprintf(out, arg, "\n");
+  }
+}
+
+static void mi_stat_counter_print(const mi_stat_counter_t* stat, const char* msg, mi_output_fun* out, void* arg ) {
+  _mi_fprintf(out, arg, "%10s:", msg);
+  mi_print_amount(stat->total, -1, out, arg);
+  _mi_fprintf(out, arg, "\n");
+}
+
+static void mi_stat_counter_print_avg(const mi_stat_counter_t* stat, const char* msg, mi_output_fun* out, void* arg) {
+  const int64_t avg_tens = (stat->count == 0 ? 0 : (stat->total*10 / stat->count)); 
+  const long avg_whole = (long)(avg_tens/10);
+  const long avg_frac1 = (long)(avg_tens%10);
+  _mi_fprintf(out, arg, "%10s: %5ld.%ld avg\n", msg, avg_whole, avg_frac1);
+}
+
+
+static void mi_print_header(mi_output_fun* out, void* arg ) {
+  _mi_fprintf(out, arg, "%10s: %10s %10s %10s %10s %10s %10s\n", "heap stats", "peak   ", "total   ", "freed   ", "current   ", "unit   ", "count   ");
+}
+
+#if MI_STAT>1
+static void mi_stats_print_bins(const mi_stat_count_t* bins, size_t max, const char* fmt, mi_output_fun* out, void* arg) {
+  bool found = false;
+  char buf[64];
+  for (size_t i = 0; i <= max; i++) {
+    if (bins[i].allocated > 0) {
+      found = true;
+      int64_t unit = _mi_bin_size((uint8_t)i);
+      snprintf(buf, 64, "%s %3lu", fmt, (long)i);
+      mi_stat_print(&bins[i], buf, unit, out, arg);
+    }
+  }
+  if (found) {
+    _mi_fprintf(out, arg, "\n");
+    mi_print_header(out, arg);
+  }
+}
+#endif
+
+
+
+//------------------------------------------------------------
+// Use an output wrapper for line-buffered output
+// (which is nice when using loggers etc.)
+//------------------------------------------------------------
+typedef struct buffered_s {
+  mi_output_fun* out;   // original output function
+  void*          arg;   // and state
+  char*          buf;   // local buffer of at least size `count+1`
+  size_t         used;  // currently used chars `used <= count`  
+  size_t         count; // total chars available for output
+} buffered_t;
+
+static void mi_buffered_flush(buffered_t* buf) {
+  buf->buf[buf->used] = 0;
+  _mi_fputs(buf->out, buf->arg, NULL, buf->buf);
+  buf->used = 0;
+}
+
+static void mi_buffered_out(const char* msg, void* arg) {
+  buffered_t* buf = (buffered_t*)arg;
+  if (msg==NULL || buf==NULL) return;
+  for (const char* src = msg; *src != 0; src++) {
+    char c = *src;
+    if (buf->used >= buf->count) mi_buffered_flush(buf);
+    mi_assert_internal(buf->used < buf->count);
+    buf->buf[buf->used++] = c;
+    if (c == '\n') mi_buffered_flush(buf);
+  }
+}
+
+//------------------------------------------------------------
+// Print statistics
+//------------------------------------------------------------
+
+static void mi_stat_process_info(mi_msecs_t* elapsed, mi_msecs_t* utime, mi_msecs_t* stime, size_t* current_rss, size_t* peak_rss, size_t* current_commit, size_t* peak_commit, size_t* page_faults);
+
+static void _mi_stats_print(mi_stats_t* stats, mi_output_fun* out0, void* arg0) mi_attr_noexcept {
+  // wrap the output function to be line buffered
+  char buf[256];
+  buffered_t buffer = { out0, arg0, NULL, 0, 255 };
+  buffer.buf = buf;
+  mi_output_fun* out = &mi_buffered_out;
+  void* arg = &buffer;
+
+  // and print using that
+  mi_print_header(out,arg);
+  #if MI_STAT>1
+  mi_stats_print_bins(stats->normal_bins, MI_BIN_HUGE, "normal",out,arg);
+  #endif
+  #if MI_STAT
+  mi_stat_print(&stats->normal, "normal", (stats->normal_count.count == 0 ? 1 : -(stats->normal.allocated / stats->normal_count.count)), out, arg);
+  mi_stat_print(&stats->large, "large", (stats->large_count.count == 0 ? 1 : -(stats->large.allocated / stats->large_count.count)), out, arg);
+  mi_stat_print(&stats->huge, "huge", (stats->huge_count.count == 0 ? 1 : -(stats->huge.allocated / stats->huge_count.count)), out, arg);
+  mi_stat_count_t total = { 0,0,0,0 };
+  mi_stat_add(&total, &stats->normal, 1);
+  mi_stat_add(&total, &stats->large, 1);
+  mi_stat_add(&total, &stats->huge, 1);
+  mi_stat_print(&total, "total", 1, out, arg);
+  #endif
+  #if MI_STAT>1
+  mi_stat_print(&stats->malloc, "malloc req", 1, out, arg);
+  _mi_fprintf(out, arg, "\n");
+  #endif
+  mi_stat_print(&stats->reserved, "reserved", 1, out, arg);
+  mi_stat_print(&stats->committed, "committed", 1, out, arg);
+  mi_stat_print(&stats->reset, "reset", 1, out, arg);
+  mi_stat_print(&stats->page_committed, "touched", 1, out, arg);
+  mi_stat_print(&stats->segments, "segments", -1, out, arg);
+  mi_stat_print(&stats->segments_abandoned, "-abandoned", -1, out, arg);
+  mi_stat_print(&stats->segments_cache, "-cached", -1, out, arg);
+  mi_stat_print(&stats->pages, "pages", -1, out, arg);
+  mi_stat_print(&stats->pages_abandoned, "-abandoned", -1, out, arg);
+  mi_stat_counter_print(&stats->pages_extended, "-extended", out, arg);
+  mi_stat_counter_print(&stats->page_no_retire, "-noretire", out, arg);
+  mi_stat_counter_print(&stats->mmap_calls, "mmaps", out, arg);
+  mi_stat_counter_print(&stats->commit_calls, "commits", out, arg);
+  mi_stat_print(&stats->threads, "threads", -1, out, arg);
+  mi_stat_counter_print_avg(&stats->searches, "searches", out, arg);
+  _mi_fprintf(out, arg, "%10s: %7zu\n", "numa nodes", _mi_os_numa_node_count());
+  
+  mi_msecs_t elapsed;
+  mi_msecs_t user_time;
+  mi_msecs_t sys_time;
+  size_t current_rss;
+  size_t peak_rss;
+  size_t current_commit;
+  size_t peak_commit;
+  size_t page_faults;
+  mi_stat_process_info(&elapsed, &user_time, &sys_time, &current_rss, &peak_rss, &current_commit, &peak_commit, &page_faults);
+  _mi_fprintf(out, arg, "%10s: %7ld.%03ld s\n", "elapsed", elapsed/1000, elapsed%1000);
+  _mi_fprintf(out, arg, "%10s: user: %ld.%03ld s, system: %ld.%03ld s, faults: %lu, rss: ", "process",
+              user_time/1000, user_time%1000, sys_time/1000, sys_time%1000, (unsigned long)page_faults );
+  mi_printf_amount((int64_t)peak_rss, 1, out, arg, "%s");
+  if (peak_commit > 0) {
+    _mi_fprintf(out, arg, ", commit: ");
+    mi_printf_amount((int64_t)peak_commit, 1, out, arg, "%s");
+  }
+  _mi_fprintf(out, arg, "\n");  
+}
+
+static mi_msecs_t mi_process_start; // = 0
+
+static mi_stats_t* mi_stats_get_default(void) {
+  mi_heap_t* heap = mi_heap_get_default();
+  return &heap->tld->stats;
+}
+
+static void mi_stats_merge_from(mi_stats_t* stats) {
+  if (stats != &_mi_stats_main) {
+    mi_stats_add(&_mi_stats_main, stats);
+    memset(stats, 0, sizeof(mi_stats_t));
+  }
+}
+
+void mi_stats_reset(void) mi_attr_noexcept {
+  mi_stats_t* stats = mi_stats_get_default();
+  if (stats != &_mi_stats_main) { memset(stats, 0, sizeof(mi_stats_t)); }
+  memset(&_mi_stats_main, 0, sizeof(mi_stats_t));
+  if (mi_process_start == 0) { mi_process_start = _mi_clock_start(); };
+}
+
+void mi_stats_merge(void) mi_attr_noexcept {
+  mi_stats_merge_from( mi_stats_get_default() );
+}
+
+void _mi_stats_done(mi_stats_t* stats) {  // called from `mi_thread_done`
+  mi_stats_merge_from(stats);
+}
+
+void mi_stats_print_out(mi_output_fun* out, void* arg) mi_attr_noexcept {
+  mi_stats_merge_from(mi_stats_get_default());
+  _mi_stats_print(&_mi_stats_main, out, arg);
+}
+
+void mi_stats_print(void* out) mi_attr_noexcept {
+  // for compatibility there is an `out` parameter (which can be `stdout` or `stderr`)
+  mi_stats_print_out((mi_output_fun*)out, NULL);
+}
+
+void mi_thread_stats_print_out(mi_output_fun* out, void* arg) mi_attr_noexcept {
+  _mi_stats_print(mi_stats_get_default(), out, arg);
+}
+
+
+// ----------------------------------------------------------------
+// Basic timer for convenience; use milli-seconds to avoid doubles
+// ----------------------------------------------------------------
+#ifdef _WIN32
+#include <windows.h>
+static mi_msecs_t mi_to_msecs(LARGE_INTEGER t) {
+  static LARGE_INTEGER mfreq; // = 0
+  if (mfreq.QuadPart == 0LL) {
+    LARGE_INTEGER f;
+    QueryPerformanceFrequency(&f);
+    mfreq.QuadPart = f.QuadPart/1000LL;
+    if (mfreq.QuadPart == 0) mfreq.QuadPart = 1;
+  }
+  return (mi_msecs_t)(t.QuadPart / mfreq.QuadPart);  
+}
+
+mi_msecs_t _mi_clock_now(void) {
+  LARGE_INTEGER t;
+  QueryPerformanceCounter(&t);
+  return mi_to_msecs(t);
+}
+#else
+#include <time.h>
+#if defined(CLOCK_REALTIME) || defined(CLOCK_MONOTONIC)
+mi_msecs_t _mi_clock_now(void) {
+  struct timespec t;
+  #ifdef CLOCK_MONOTONIC
+  clock_gettime(CLOCK_MONOTONIC, &t);
+  #else  
+  clock_gettime(CLOCK_REALTIME, &t);
+  #endif
+  return ((mi_msecs_t)t.tv_sec * 1000) + ((mi_msecs_t)t.tv_nsec / 1000000);
+}
+#else
+// low resolution timer
+mi_msecs_t _mi_clock_now(void) {
+  return ((mi_msecs_t)clock() / ((mi_msecs_t)CLOCKS_PER_SEC / 1000));
+}
+#endif
+#endif
+
+
+static mi_msecs_t mi_clock_diff;
+
+mi_msecs_t _mi_clock_start(void) {
+  if (mi_clock_diff == 0.0) {
+    mi_msecs_t t0 = _mi_clock_now();
+    mi_clock_diff = _mi_clock_now() - t0;
+  }
+  return _mi_clock_now();
+}
+
+mi_msecs_t _mi_clock_end(mi_msecs_t start) {
+  mi_msecs_t end = _mi_clock_now();
+  return (end - start - mi_clock_diff);
+}
+
+
+// --------------------------------------------------------
+// Basic process statistics
+// --------------------------------------------------------
+
+#if defined(_WIN32)
+#include <windows.h>
+#include <psapi.h>
+#pragma comment(lib,"psapi.lib")
+
+static mi_msecs_t filetime_msecs(const FILETIME* ftime) {
+  ULARGE_INTEGER i;
+  i.LowPart = ftime->dwLowDateTime;
+  i.HighPart = ftime->dwHighDateTime;
+  mi_msecs_t msecs = (i.QuadPart / 10000); // FILETIME is in 100 nano seconds
+  return msecs;
+}
+
+static void mi_stat_process_info(mi_msecs_t* elapsed, mi_msecs_t* utime, mi_msecs_t* stime, size_t* current_rss, size_t* peak_rss, size_t* current_commit, size_t* peak_commit, size_t* page_faults) 
+{
+  *elapsed = _mi_clock_end(mi_process_start);
+  FILETIME ct;
+  FILETIME ut;
+  FILETIME st;
+  FILETIME et;
+  GetProcessTimes(GetCurrentProcess(), &ct, &et, &st, &ut);
+  *utime = filetime_msecs(&ut);
+  *stime = filetime_msecs(&st);
+  PROCESS_MEMORY_COUNTERS info;
+  GetProcessMemoryInfo(GetCurrentProcess(), &info, sizeof(info));
+  *current_rss    = (size_t)info.WorkingSetSize;
+  *peak_rss       = (size_t)info.PeakWorkingSetSize;
+  *current_commit = (size_t)info.PagefileUsage;
+  *peak_commit    = (size_t)info.PeakPagefileUsage;
+  *page_faults    = (size_t)info.PageFaultCount;  
+}
+
+#elif !defined(__wasi__) && (defined(__unix__) || defined(__unix) || defined(unix) || defined(__APPLE__) || defined(__HAIKU__))
+#include <stdio.h>
+#include <unistd.h>
+#include <sys/resource.h>
+
+#if defined(__APPLE__)
+#include <mach/mach.h>
+#endif
+
+#if defined(__HAIKU__)
+#include <kernel/OS.h>
+#endif
+
+static mi_msecs_t timeval_secs(const struct timeval* tv) {
+  return ((mi_msecs_t)tv->tv_sec * 1000L) + ((mi_msecs_t)tv->tv_usec / 1000L);
+}
+
+static void mi_stat_process_info(mi_msecs_t* elapsed, mi_msecs_t* utime, mi_msecs_t* stime, size_t* current_rss, size_t* peak_rss, size_t* current_commit, size_t* peak_commit, size_t* page_faults)
+{
+  *elapsed = _mi_clock_end(mi_process_start);
+  struct rusage rusage;
+  getrusage(RUSAGE_SELF, &rusage);
+  *utime = timeval_secs(&rusage.ru_utime);
+  *stime = timeval_secs(&rusage.ru_stime);
+#if !defined(__HAIKU__)
+  *page_faults = rusage.ru_majflt;
+#endif
+  // estimate commit using our stats
+  *peak_commit    = (size_t)(mi_atomic_loadi64_relaxed((_Atomic(int64_t)*)&_mi_stats_main.committed.peak));
+  *current_commit = (size_t)(mi_atomic_loadi64_relaxed((_Atomic(int64_t)*)&_mi_stats_main.committed.current));
+  *current_rss    = *current_commit;  // estimate 
+#if defined(__HAIKU__)
+  // Haiku does not have (yet?) a way to
+  // get these stats per process
+  thread_info tid;
+  area_info mem;
+  ssize_t c;
+  get_thread_info(find_thread(0), &tid);
+  while (get_next_area_info(tid.team, &c, &mem) == B_OK) {
+    *peak_rss += mem.ram_size;
+  }
+  *page_faults = 0;
+#elif defined(__APPLE__)
+  *peak_rss = rusage.ru_maxrss;         // BSD reports in bytes
+  struct mach_task_basic_info info;
+  mach_msg_type_number_t infoCount = MACH_TASK_BASIC_INFO_COUNT;
+  if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &infoCount) == KERN_SUCCESS) {
+    *current_rss = (size_t)info.resident_size;
+  }
+#else
+  *peak_rss = rusage.ru_maxrss * 1024;  // Linux reports in KiB
+#endif  
+}
+
+#else
+#ifndef __wasi__
+// WebAssembly instances are not processes
+#pragma message("define a way to get process info")
+#endif
+
+static void mi_stat_process_info(mi_msecs_t* elapsed, mi_msecs_t* utime, mi_msecs_t* stime, size_t* current_rss, size_t* peak_rss, size_t* current_commit, size_t* peak_commit, size_t* page_faults)
+{
+  *elapsed = _mi_clock_end(mi_process_start);
+  *peak_commit    = (size_t)(mi_atomic_loadi64_relaxed((_Atomic(int64_t)*)&_mi_stats_main.committed.peak));
+  *current_commit = (size_t)(mi_atomic_loadi64_relaxed((_Atomic(int64_t)*)&_mi_stats_main.committed.current));
+  *peak_rss    = *peak_commit;
+  *current_rss = *current_commit;
+  *page_faults = 0;
+  *utime = 0;
+  *stime = 0;
+}
+#endif
+
+
+mi_decl_export void mi_process_info(size_t* elapsed_msecs, size_t* user_msecs, size_t* system_msecs, size_t* current_rss, size_t* peak_rss, size_t* current_commit, size_t* peak_commit, size_t* page_faults) mi_attr_noexcept
+{
+  mi_msecs_t elapsed = 0;
+  mi_msecs_t utime = 0;
+  mi_msecs_t stime = 0;
+  size_t current_rss0 = 0;
+  size_t peak_rss0 = 0;
+  size_t current_commit0 = 0;
+  size_t peak_commit0 = 0;
+  size_t page_faults0 = 0;  
+  mi_stat_process_info(&elapsed,&utime, &stime, &current_rss0, &peak_rss0, &current_commit0, &peak_commit0, &page_faults0);
+  if (elapsed_msecs!=NULL)  *elapsed_msecs = (elapsed < 0 ? 0 : (elapsed < (mi_msecs_t)PTRDIFF_MAX ? (size_t)elapsed : PTRDIFF_MAX));
+  if (user_msecs!=NULL)     *user_msecs     = (utime < 0 ? 0 : (utime < (mi_msecs_t)PTRDIFF_MAX ? (size_t)utime : PTRDIFF_MAX));
+  if (system_msecs!=NULL)   *system_msecs   = (stime < 0 ? 0 : (stime < (mi_msecs_t)PTRDIFF_MAX ? (size_t)stime : PTRDIFF_MAX));
+  if (current_rss!=NULL)    *current_rss    = current_rss0;
+  if (peak_rss!=NULL)       *peak_rss       = peak_rss0;
+  if (current_commit!=NULL) *current_commit = current_commit0;
+  if (peak_commit!=NULL)    *peak_commit    = peak_commit0;
+  if (page_faults!=NULL)    *page_faults    = page_faults0;
+}
+
diff --git a/Objects/obmalloc.c b/Objects/obmalloc.c
index 560e1c59a9c58..9c3b7b30fcbcb 100644
--- a/Objects/obmalloc.c
+++ b/Objects/obmalloc.c
@@ -3,13 +3,17 @@
 #include "pycore_code.h"         // stats
 
 #include <stdbool.h>
+#ifdef WITH_MIMALLOC
+#include "pycore_mimalloc.h"
+#include "mimalloc/static.c"
+#else
 #include <stdlib.h>               // malloc()
+#endif
 
 
 /* Defined in tracemalloc.c */
 extern void _PyMem_DumpTraceback(int fd, const void *ptr);
 
-
 /* Python's malloc wrappers (see pymem.h) */
 
 #undef  uint
@@ -130,6 +134,46 @@ _PyMem_RawFree(void *ctx, void *ptr)
 }
 
 
+#ifdef WITH_MIMALLOC
+
+static void *
+_PyMimalloc_Malloc(void *ctx, size_t size)
+{
+    if (size == 0)
+        size = 1;
+    void *r = mi_malloc(size);
+    return r;
+}
+
+static void *
+_PyMimalloc_Calloc(void *ctx, size_t nelem, size_t elsize)
+{
+    if (nelem == 0 || elsize == 0) {
+        nelem = 1;
+        elsize = 1;
+    }
+    void *r = mi_calloc(nelem, elsize);
+    return r;
+}
+
+static void *
+_PyMimalloc_Realloc(void *ctx, void *ptr, size_t size)
+{
+
+    if (size == 0)
+        size = 1;
+    return mi_realloc(ptr, size);
+}
+
+static void
+_PyMimalloc_Free(void *ctx, void *ptr)
+{
+    mi_free(ptr);
+}
+
+#endif // WITH_MIMALLOC
+
+
 #ifdef MS_WINDOWS
 static void *
 _PyObject_ArenaVirtualAlloc(void *ctx, size_t size)
@@ -178,17 +222,34 @@ _PyObject_ArenaFree(void *ctx, void *ptr, size_t size)
 #endif
 
 #define MALLOC_ALLOC {NULL, _PyMem_RawMalloc, _PyMem_RawCalloc, _PyMem_RawRealloc, _PyMem_RawFree}
+#ifdef WITH_MIMALLOC
+#  define MIMALLOC_ALLOC {NULL, _PyMimalloc_Malloc, _PyMimalloc_Calloc, _PyMimalloc_Realloc, _PyMimalloc_Free}
+#endif
 #ifdef WITH_PYMALLOC
 #  define PYMALLOC_ALLOC {NULL, _PyObject_Malloc, _PyObject_Calloc, _PyObject_Realloc, _PyObject_Free}
 #endif
 
-#define PYRAW_ALLOC MALLOC_ALLOC
-#ifdef WITH_PYMALLOC
+#ifdef WITH_MIMALLOC
+// XXX: MIMALLOC_ALLOC as raw malloc breaks tests in debug mode
+// alloc_for_runtime() initializes PYMEM_DOMAIN_RAW before the env var
+// PYTHONMALLOC is parsed.
+#  ifdef Py_DEBUG
+#    define PYRAW_ALLOC MALLOC_ALLOC
+#  else
+#    define PYRAW_ALLOC MIMALLOC_ALLOC
+#  endif
+#  define PYOBJ_ALLOC MIMALLOC_ALLOC
+#  define PYMEM_ALLOC MIMALLOC_ALLOC
+#elif defined(WITH_PYMALLOC)
+#  define PYRAW_ALLOC MALLOC_ALLOC
 #  define PYOBJ_ALLOC PYMALLOC_ALLOC
+#  define PYMEM_ALLOC PYMALLOC_ALLOC
 #else
+#  define PYRAW_ALLOC MALLOC_ALLOC
 #  define PYOBJ_ALLOC MALLOC_ALLOC
-#endif
-#define PYMEM_ALLOC PYOBJ_ALLOC
+#  define PYMEM_ALLOC MALLOC_ALLOC
+#endif // WITH_MIMALLOC
+
 
 typedef struct {
     /* We tag each block with an API ID in order to tag API violations */
@@ -290,6 +351,14 @@ _PyMem_GetAllocatorName(const char *name, PyMemAllocatorName *allocator)
     else if (strcmp(name, "pymalloc_debug") == 0) {
         *allocator = PYMEM_ALLOCATOR_PYMALLOC_DEBUG;
     }
+#endif
+#ifdef WITH_MIMALLOC
+    else if (strcmp(name, "mimalloc") == 0) {
+        *allocator = PYMEM_ALLOCATOR_MIMALLOC;
+    }
+    else if (strcmp(name, "mimalloc_debug") == 0) {
+        *allocator = PYMEM_ALLOCATOR_MIMALLOC_DEBUG;
+    }
 #endif
     else if (strcmp(name, "malloc") == 0) {
         *allocator = PYMEM_ALLOCATOR_MALLOC;
@@ -342,7 +411,27 @@ _PyMem_SetupAllocators(PyMemAllocatorName allocator)
         break;
     }
 #endif
+#ifdef WITH_MIMALLOC
+    case PYMEM_ALLOCATOR_MIMALLOC:
+    case PYMEM_ALLOCATOR_MIMALLOC_DEBUG:
+    {
+        PyMemAllocatorEx mimalloc = MIMALLOC_ALLOC;
+#ifdef Py_DEBUG
+        PyMemAllocatorEx malloc_alloc = MALLOC_ALLOC;
+        PyMem_SetAllocator(PYMEM_DOMAIN_RAW, &malloc_alloc);
+#else
+        PyMem_SetAllocator(PYMEM_DOMAIN_RAW, &mimalloc);
+#endif
+        PyMem_SetAllocator(PYMEM_DOMAIN_MEM, &mimalloc);
+        PyMem_SetAllocator(PYMEM_DOMAIN_OBJ, &mimalloc);
 
+        if (allocator == PYMEM_ALLOCATOR_MIMALLOC_DEBUG) {
+            PyMem_SetupDebugHooks();
+        }
+
+        break;
+    }
+#endif
     case PYMEM_ALLOCATOR_MALLOC:
     case PYMEM_ALLOCATOR_MALLOC_DEBUG:
     {
@@ -379,6 +468,9 @@ _PyMem_GetCurrentAllocatorName(void)
 #ifdef WITH_PYMALLOC
     PyMemAllocatorEx pymalloc = PYMALLOC_ALLOC;
 #endif
+#ifdef WITH_MIMALLOC
+    PyMemAllocatorEx mimalloc = MIMALLOC_ALLOC;
+#endif
 
     if (pymemallocator_eq(&_PyMem_Raw, &malloc_alloc) &&
         pymemallocator_eq(&_PyMem, &malloc_alloc) &&
@@ -394,6 +486,19 @@ _PyMem_GetCurrentAllocatorName(void)
         return "pymalloc";
     }
 #endif
+#ifdef WITH_MIMALLOC
+    if (
+#ifdef Py_DEBUG
+        pymemallocator_eq(&_PyMem_Raw, &malloc_alloc) &&
+#else
+        pymemallocator_eq(&_PyMem_Raw, &mimalloc) &&
+#endif
+        pymemallocator_eq(&_PyMem, &mimalloc) &&
+        pymemallocator_eq(&_PyObject, &mimalloc))
+    {
+        return "mimalloc";
+    }
+#endif
 
     PyMemAllocatorEx dbg_raw = PYDBGRAW_ALLOC;
     PyMemAllocatorEx dbg_mem = PYDBGMEM_ALLOC;
@@ -417,6 +522,19 @@ _PyMem_GetCurrentAllocatorName(void)
         {
             return "pymalloc_debug";
         }
+#endif
+#ifdef WITH_MIMALLOC
+        if (
+#ifdef Py_DEBUG
+            pymemallocator_eq(&_PyMem_Debug.raw.alloc, &malloc_alloc) &&
+#else
+            pymemallocator_eq(&_PyMem_Debug.raw.alloc, &mimalloc) &&
+#endif
+            pymemallocator_eq(&_PyMem_Debug.mem.alloc, &mimalloc) &&
+            pymemallocator_eq(&_PyMem_Debug.obj.alloc, &mimalloc))
+        {
+            return "mimalloc_debug";
+        }
 #endif
     }
     return NULL;
@@ -425,6 +543,7 @@ _PyMem_GetCurrentAllocatorName(void)
 
 #undef MALLOC_ALLOC
 #undef PYMALLOC_ALLOC
+#undef MIMALLOC_ALLOC
 #undef PYRAW_ALLOC
 #undef PYMEM_ALLOC
 #undef PYOBJ_ALLOC
@@ -443,13 +562,27 @@ static PyObjectArenaAllocator _PyObject_Arena = {NULL,
 #endif
     };
 
-#ifdef WITH_PYMALLOC
+#if defined(WITH_PYMALLOC) || defined(WITH_MIMALLOC)
 static int
 _PyMem_DebugEnabled(void)
 {
     return (_PyObject.malloc == _PyMem_DebugMalloc);
 }
 
+#ifdef WITH_MIMALLOC
+static int
+_PyMem_MimallocEnabled(void)
+{
+    if (_PyMem_DebugEnabled()) {
+        return (_PyMem_Debug.obj.alloc.malloc == _PyMimalloc_Malloc);
+    }
+    else {
+        return (_PyObject.malloc == _PyMimalloc_Malloc);
+    }
+}
+#endif
+
+#ifdef WITH_PYMALLOC
 static int
 _PyMem_PymallocEnabled(void)
 {
@@ -461,7 +594,7 @@ _PyMem_PymallocEnabled(void)
     }
 }
 #endif
-
+#endif // WITH_PYMALLOC || WITH_MIMALLOC
 
 static void
 _PyMem_SetupDebugHooksDomain(PyMemAllocatorDomain domain)
@@ -2908,6 +3041,22 @@ _PyDebugAllocatorStats(FILE *out,
     (void)printone(out, buf2, num_blocks * sizeof_block);
 }
 
+#ifdef WITH_MIMALLOC
+
+static void
+mimalloc_output(const char *msg, void *arg) {
+    fputs(msg, (FILE *)arg);
+}
+
+static int
+_PyObject_DebugMimallocStats(FILE *out) {
+    fprintf(out, "mimalloc (version: %i)\n", mi_version());
+    mi_stats_print_out(mimalloc_output, (void *)out);
+    fputc('\n', out);
+    return 0;
+}
+#endif
+
 
 #ifdef WITH_PYMALLOC
 
@@ -2939,13 +3088,9 @@ pool_is_in_list(const poolp target, poolp list)
  * Return 0 if the memory debug hooks are not installed or no statistics was
  * written into out, return 1 otherwise.
  */
-int
-_PyObject_DebugMallocStats(FILE *out)
+static int
+_PyObject_DebugObjectMallocStats(FILE *out)
 {
-    if (!_PyMem_PymallocEnabled()) {
-        return 0;
-    }
-
     uint i;
     const uint numclasses = SMALL_REQUEST_THRESHOLD >> ALIGNMENT_SHIFT;
     /* # of pools, allocated blocks, and free blocks per class index */
@@ -3102,3 +3247,23 @@ _PyObject_DebugMallocStats(FILE *out)
 }
 
 #endif /* #ifdef WITH_PYMALLOC */
+
+
+/* Print summary info to "out" about the state of mimalloc/pymalloc
+ */
+
+int
+_PyObject_DebugMallocStats(FILE *out)
+{
+#ifdef WITH_PYMALLOC
+    if (_PyMem_PymallocEnabled()) {
+        return _PyObject_DebugObjectMallocStats(out);
+    }
+#endif
+#ifdef WITH_MIMALLOC
+    if (_PyMem_MimallocEnabled()) {
+        return _PyObject_DebugMimallocStats(out);
+    }
+#endif
+    return 0;
+}
diff --git a/PC/pyconfig.h b/PC/pyconfig.h
index e8649be568420..173256d02d826 100644
--- a/PC/pyconfig.h
+++ b/PC/pyconfig.h
@@ -457,6 +457,9 @@ Py_NO_ENABLE_SHARED to find out.  Also support MS_NO_COREDLL for b/w compat */
 /* Define if you want to use the GNU readline library */
 /* #define WITH_READLINE 1 */
 
+/* Define Python uses mimalloc memory allocator. */
+#define WITH_MIMALLOC 1
+
 /* Use Python's own small-block memory-allocator. */
 #define WITH_PYMALLOC 1
 
diff --git a/Python/pylifecycle.c b/Python/pylifecycle.c
index 273f6d62b2a20..0bb8591b6412f 100644
--- a/Python/pylifecycle.c
+++ b/Python/pylifecycle.c
@@ -1785,7 +1785,7 @@ Py_FinalizeEx(void)
     int dump_refs = tstate->interp->config.dump_refs;
     wchar_t *dump_refs_file = tstate->interp->config.dump_refs_file;
 #endif
-#ifdef WITH_PYMALLOC
+#if defined(WITH_PYMALLOC) || defined(WITH_MIMALLOC)
     int malloc_stats = tstate->interp->config.malloc_stats;
 #endif
 
@@ -1918,7 +1918,7 @@ Py_FinalizeEx(void)
         fclose(dump_refs_fp);
     }
 #endif /* Py_TRACE_REFS */
-#ifdef WITH_PYMALLOC
+#if defined(WITH_PYMALLOC) || defined(WITH_MIMALLOC)
     if (malloc_stats) {
         _PyObject_DebugMallocStats(stderr);
     }
diff --git a/Python/sysmodule.c b/Python/sysmodule.c
index de4e10a7e110c..af7f8cd24a74d 100644
--- a/Python/sysmodule.c
+++ b/Python/sysmodule.c
@@ -20,6 +20,9 @@ Data members:
 #include "pycore_code.h"          // _Py_QuickenedCount
 #include "pycore_frame.h"         // _PyInterpreterFrame
 #include "pycore_initconfig.h"    // _PyStatus_EXCEPTION()
+#ifdef WITH_MIMALLOC
+#  include "pycore_mimalloc.h"    // MI_SECURE, MI_DEBUG
+#endif
 #include "pycore_namespace.h"     // _PyNamespace_New()
 #include "pycore_object.h"        // _PyObject_IS_GC()
 #include "pycore_pathconfig.h"    // _PyPathConfig_ComputeSysPath0()
@@ -1862,7 +1865,7 @@ static PyObject *
 sys__debugmallocstats_impl(PyObject *module)
 /*[clinic end generated code: output=ec3565f8c7cee46a input=33c0c9c416f98424]*/
 {
-#ifdef WITH_PYMALLOC
+#if defined(WITH_PYMALLOC) || defined(WITH_MIMALLOC)
     if (_PyObject_DebugMallocStats(stderr)) {
         fputc('\n', stderr);
     }
@@ -1872,6 +1875,88 @@ sys__debugmallocstats_impl(PyObject *module)
     Py_RETURN_NONE;
 }
 
+PyDoc_STRVAR(malloc_info__doc__,
+"sys._malloc_info\n\
+\n\
+Memory allocator info as a named tuple.");
+
+static PyTypeObject MallocInfoType;
+
+static PyStructSequence_Field malloc_info_fields[] = {
+    {"allocator", "current memory allocator"},
+    {"with_pymalloc", "supports pymalloc (aka obmalloc)"},
+    {"with_mimalloc", "supports mimalloc"},
+    {"mimalloc_secure", "mimalloc security level"},
+    {"mimalloc_debug", "mimalloc debug level"},
+    {0}
+};
+
+static PyStructSequence_Desc malloc_info_desc = {
+    "sys._malloc_info",     /* name */
+    malloc_info__doc__ ,    /* doc */
+    malloc_info_fields,     /* fields */
+    5
+};
+
+static PyObject *
+make_malloc_info(void)
+{
+    PyObject *malloc_info;
+    const char *name;
+    PyObject *v;
+    int pos = 0;
+
+    malloc_info = PyStructSequence_New(&MallocInfoType);
+    if (malloc_info == NULL) {
+        return NULL;
+    }
+
+#define SetIntItem(flag) \
+    PyStructSequence_SET_ITEM(malloc_info, pos++, PyLong_FromLong(flag))
+
+    name = _PyMem_GetCurrentAllocatorName();
+    if (name == NULL) {
+        name = "unknown";
+    }
+    v = PyUnicode_FromString(name);
+    if (v == NULL) {
+        Py_DECREF(malloc_info);
+        return NULL;
+    }
+
+    PyStructSequence_SET_ITEM(malloc_info, pos++, v);
+
+#ifdef WITH_PYMALLOC
+    v = Py_True;
+#else
+    v = Py_False;
+#endif
+    PyStructSequence_SET_ITEM(malloc_info, pos++, _Py_NewRef(v));
+
+#ifdef WITH_MIMALLOC
+    v = Py_True;
+#else
+    v = Py_False;
+#endif
+    PyStructSequence_SET_ITEM(malloc_info, pos++, _Py_NewRef(v));
+
+#ifdef WITH_MIMALLOC
+    SetIntItem(MI_SECURE);
+    SetIntItem(MI_DEBUG);
+#else
+    SetIntItem(-1);
+    SetIntItem(-1);
+#endif
+
+#undef SetIntItem
+
+    if (PyErr_Occurred()) {
+        Py_CLEAR(malloc_info);
+        return NULL;
+    }
+    return malloc_info;
+}
+
 #ifdef Py_TRACE_REFS
 /* Defined in objects.c because it uses static globals in that file */
 extern PyObject *_Py_GetObjects(PyObject *, PyObject *);
@@ -2814,6 +2899,16 @@ _PySys_InitCore(PyThreadState *tstate, PyObject *sysdict)
 
     SET_SYS("thread_info", PyThread_GetInfo());
 
+    /* malloc_info */
+    if (MallocInfoType.tp_name == NULL) {
+        if (_PyStructSequence_InitType(&MallocInfoType,
+                                       &malloc_info_desc,
+                                       Py_TPFLAGS_DISALLOW_INSTANTIATION) < 0) {
+            goto type_init_failed;
+        }
+    }
+    SET_SYS("_malloc_info", make_malloc_info());
+
     /* initialize asyncgen_hooks */
     if (AsyncGenHooksType.tp_name == NULL) {
         if (PyStructSequence_InitType2(
@@ -3067,6 +3162,7 @@ _PySys_Fini(PyInterpreterState *interp)
 #endif
         _PyStructSequence_FiniType(&Hash_InfoType);
         _PyStructSequence_FiniType(&AsyncGenHooksType);
+        _PyStructSequence_FiniType(&MallocInfoType);
     }
 }
 
diff --git a/configure b/configure
index 69b12309de578..270c75cec1a11 100755
--- a/configure
+++ b/configure
@@ -823,6 +823,8 @@ DTRACE_OBJS
 DTRACE_HEADERS
 DFLAGS
 DTRACE
+MIMALLOC_INCLUDES
+MIMALLOC_HEADERS
 GDBM_LIBS
 GDBM_CFLAGS
 X11_LIBS
@@ -1042,6 +1044,8 @@ enable_loadable_sqlite_extensions
 with_dbmliborder
 enable_ipv6
 with_doc_strings
+with_mimalloc
+enable_mimalloc_secure
 with_pymalloc
 with_freelists
 with_c_locale_coercion
@@ -1746,6 +1750,10 @@ Optional Features:
                           see Doc/library/sqlite3.rst (default is no)
   --enable-ipv6           enable ipv6 (with ipv4) support, see
                           Doc/library/socket.rst (default is yes if supported)
+  --enable-mimalloc-secure[=yes|no|1|2|3|4]
+                          enable mimalloc security mitigations (default is
+                          no), 1: guard metadata, 2: guard pages, 3: encode
+                          freelists, 4/yes: detect double free
   --enable-big-digits[=15|30]
                           use big digits (30 or 15 bits) for Python longs
                           (default is 30)]
@@ -1818,6 +1826,8 @@ Optional Packages:
                           value is a colon separated string with the backend
                           names `ndbm', `gdbm' and `bdb'.
   --with-doc-strings      enable documentation strings (default is yes)
+  --with-mimalloc         build with mimalloc memory allocator (default is yes
+                          if C11 stdatomic.h is available.)
   --with-pymalloc         enable specialized mallocs (default is yes)
   --with-freelists        enable object freelists (default is yes)
   --with-c-locale-coercion
@@ -14447,6 +14457,158 @@ fi
 { $as_echo "$as_me:${as_lineno-$LINENO}: result: $with_doc_strings" >&5
 $as_echo "$with_doc_strings" >&6; }
 
+# Check for stdatomic.h, required for mimalloc.
+{ $as_echo "$as_me:${as_lineno-$LINENO}: checking for stdatomic.h" >&5
+$as_echo_n "checking for stdatomic.h... " >&6; }
+if ${ac_cv_header_stdatomic_h+:} false; then :
+  $as_echo_n "(cached) " >&6
+else
+
+cat confdefs.h - <<_ACEOF >conftest.$ac_ext
+/* end confdefs.h.  */
+
+
+    #include <stdatomic.h>
+    atomic_int int_var;
+    atomic_uintptr_t uintptr_var;
+    int main() {
+      atomic_store_explicit(&int_var, 5, memory_order_relaxed);
+      atomic_store_explicit(&uintptr_var, 0, memory_order_relaxed);
+      int loaded_value = atomic_load_explicit(&int_var, memory_order_seq_cst);
+      return 0;
+    }
+
+
+_ACEOF
+if ac_fn_c_try_link "$LINENO"; then :
+  ac_cv_header_stdatomic_h=yes
+else
+  ac_cv_header_stdatomic_h=no
+fi
+rm -f core conftest.err conftest.$ac_objext \
+    conftest$ac_exeext conftest.$ac_ext
+
+fi
+{ $as_echo "$as_me:${as_lineno-$LINENO}: result: $ac_cv_header_stdatomic_h" >&5
+$as_echo "$ac_cv_header_stdatomic_h" >&6; }
+
+if test "x$ac_cv_header_stdatomic_h" = xyes; then :
+
+
+$as_echo "#define HAVE_STD_ATOMIC 1" >>confdefs.h
+
+
+fi
+
+# Check for GCC >= 4.7 and clang __atomic builtin functions
+{ $as_echo "$as_me:${as_lineno-$LINENO}: checking for builtin __atomic_load_n and __atomic_store_n functions" >&5
+$as_echo_n "checking for builtin __atomic_load_n and __atomic_store_n functions... " >&6; }
+if ${ac_cv_builtin_atomic+:} false; then :
+  $as_echo_n "(cached) " >&6
+else
+
+cat confdefs.h - <<_ACEOF >conftest.$ac_ext
+/* end confdefs.h.  */
+
+
+    int val;
+    int main() {
+      __atomic_store_n(&val, 1, __ATOMIC_SEQ_CST);
+      (void)__atomic_load_n(&val, __ATOMIC_SEQ_CST);
+      return 0;
+    }
+
+
+_ACEOF
+if ac_fn_c_try_link "$LINENO"; then :
+  ac_cv_builtin_atomic=yes
+else
+  ac_cv_builtin_atomic=no
+fi
+rm -f core conftest.err conftest.$ac_objext \
+    conftest$ac_exeext conftest.$ac_ext
+
+fi
+{ $as_echo "$as_me:${as_lineno-$LINENO}: result: $ac_cv_builtin_atomic" >&5
+$as_echo "$ac_cv_builtin_atomic" >&6; }
+
+if test "x$ac_cv_builtin_atomic" = xyes; then :
+
+
+$as_echo "#define HAVE_BUILTIN_ATOMIC 1" >>confdefs.h
+
+
+fi
+
+# --with-mimalloc
+{ $as_echo "$as_me:${as_lineno-$LINENO}: checking for --with-mimalloc" >&5
+$as_echo_n "checking for --with-mimalloc... " >&6; }
+
+# Check whether --with-mimalloc was given.
+if test "${with_mimalloc+set}" = set; then :
+  withval=$with_mimalloc;
+else
+  with_mimalloc="$ac_cv_header_stdatomic_h"
+
+fi
+
+
+if test "$with_mimalloc" != no; then
+  if test "$ac_cv_header_stdatomic_h" != yes; then
+    # mimalloc-atomic.h wants C11 stdatomic.h on POSIX
+    as_fn_error $? "mimalloc requires stdatomic.h, use --without-mimalloc to disable mimalloc." "$LINENO" 5
+  fi
+  with_mimalloc=yes
+
+$as_echo "#define WITH_MIMALLOC 1" >>confdefs.h
+
+  MIMALLOC_HEADERS='$(MIMALLOC_HEADERS)'
+
+  MIMALLOC_INCLUDES='$(MIMALLOC_INCLUDES)'
+
+fi
+{ $as_echo "$as_me:${as_lineno-$LINENO}: result: $with_mimalloc" >&5
+$as_echo "$with_mimalloc" >&6; }
+
+{ $as_echo "$as_me:${as_lineno-$LINENO}: checking for --enable-mimalloc-secure" >&5
+$as_echo_n "checking for --enable-mimalloc-secure... " >&6; }
+# Check whether --enable-mimalloc-secure was given.
+if test "${enable_mimalloc_secure+set}" = set; then :
+  enableval=$enable_mimalloc_secure;
+    case $enable_mimalloc_secure in #(
+  yes) :
+    enable_mimalloc_secure=4 ;; #(
+  1|2|3|4) :
+     ;; #(
+  no) :
+     ;; #(
+  *) :
+    enable_mimalloc_secure=invalid
+     ;;
+esac
+    if test "x$enable_mimalloc_secure" = xinvalid; then :
+  as_fn_error $? "bad value $enable_mimalloc_secure for --enable-mimalloc-secure" "$LINENO" 5
+fi
+
+else
+  enable_mimalloc_secure="no"
+
+fi
+
+
+if test "$enable_mimalloc_secure" != "no"; then
+  if test "x$with_mimalloc" = xno; then :
+  as_fn_error $? "--with-mimalloc-secure requires --with-mimalloc" "$LINENO" 5
+fi
+
+cat >>confdefs.h <<_ACEOF
+#define PY_MIMALLOC_SECURE $enable_mimalloc_secure
+_ACEOF
+
+fi
+{ $as_echo "$as_me:${as_lineno-$LINENO}: result: $enable_mimalloc_secure" >&5
+$as_echo "$enable_mimalloc_secure" >&6; }
+
 # Check for Python-specific malloc support
 { $as_echo "$as_me:${as_lineno-$LINENO}: checking for --with-pymalloc" >&5
 $as_echo_n "checking for --with-pymalloc... " >&6; }
@@ -21215,6 +21377,7 @@ SRCDIRS="\
   Modules/cjkcodecs \
   Modules/expat \
   Objects \
+  Objects/mimalloc \
   Parser \
   Programs \
   Python \
@@ -21365,89 +21528,6 @@ $as_echo "#define HAVE_IPA_PURE_CONST_BUG 1" >>confdefs.h
     esac
 fi
 
-# Check for stdatomic.h
-{ $as_echo "$as_me:${as_lineno-$LINENO}: checking for stdatomic.h" >&5
-$as_echo_n "checking for stdatomic.h... " >&6; }
-if ${ac_cv_header_stdatomic_h+:} false; then :
-  $as_echo_n "(cached) " >&6
-else
-
-cat confdefs.h - <<_ACEOF >conftest.$ac_ext
-/* end confdefs.h.  */
-
-
-    #include <stdatomic.h>
-    atomic_int int_var;
-    atomic_uintptr_t uintptr_var;
-    int main() {
-      atomic_store_explicit(&int_var, 5, memory_order_relaxed);
-      atomic_store_explicit(&uintptr_var, 0, memory_order_relaxed);
-      int loaded_value = atomic_load_explicit(&int_var, memory_order_seq_cst);
-      return 0;
-    }
-
-
-_ACEOF
-if ac_fn_c_try_link "$LINENO"; then :
-  ac_cv_header_stdatomic_h=yes
-else
-  ac_cv_header_stdatomic_h=no
-fi
-rm -f core conftest.err conftest.$ac_objext \
-    conftest$ac_exeext conftest.$ac_ext
-
-fi
-{ $as_echo "$as_me:${as_lineno-$LINENO}: result: $ac_cv_header_stdatomic_h" >&5
-$as_echo "$ac_cv_header_stdatomic_h" >&6; }
-
-if test "x$ac_cv_header_stdatomic_h" = xyes; then :
-
-
-$as_echo "#define HAVE_STD_ATOMIC 1" >>confdefs.h
-
-
-fi
-
-# Check for GCC >= 4.7 and clang __atomic builtin functions
-{ $as_echo "$as_me:${as_lineno-$LINENO}: checking for builtin __atomic_load_n and __atomic_store_n functions" >&5
-$as_echo_n "checking for builtin __atomic_load_n and __atomic_store_n functions... " >&6; }
-if ${ac_cv_builtin_atomic+:} false; then :
-  $as_echo_n "(cached) " >&6
-else
-
-cat confdefs.h - <<_ACEOF >conftest.$ac_ext
-/* end confdefs.h.  */
-
-
-    int val;
-    int main() {
-      __atomic_store_n(&val, 1, __ATOMIC_SEQ_CST);
-      (void)__atomic_load_n(&val, __ATOMIC_SEQ_CST);
-      return 0;
-    }
-
-
-_ACEOF
-if ac_fn_c_try_link "$LINENO"; then :
-  ac_cv_builtin_atomic=yes
-else
-  ac_cv_builtin_atomic=no
-fi
-rm -f core conftest.err conftest.$ac_objext \
-    conftest$ac_exeext conftest.$ac_ext
-
-fi
-{ $as_echo "$as_me:${as_lineno-$LINENO}: result: $ac_cv_builtin_atomic" >&5
-$as_echo "$ac_cv_builtin_atomic" >&6; }
-
-if test "x$ac_cv_builtin_atomic" = xyes; then :
-
-
-$as_echo "#define HAVE_BUILTIN_ATOMIC 1" >>confdefs.h
-
-
-fi
-
 # ensurepip option
 { $as_echo "$as_me:${as_lineno-$LINENO}: checking for ensurepip" >&5
 $as_echo_n "checking for ensurepip... " >&6; }
@@ -26290,3 +26370,8 @@ If you want a release build with all stable optimizations active (PGO, etc),
 please run ./configure --enable-optimizations
 " >&6;}
 fi
+
+if test "$ac_cv_header_stdatomic_h" != "yes"; then
+  { $as_echo "$as_me:${as_lineno-$LINENO}: Your compiler or platform does have a working C11 stdatomic.h. A future version of Python may require stdatomic.h." >&5
+$as_echo "$as_me: Your compiler or platform does have a working C11 stdatomic.h. A future version of Python may require stdatomic.h." >&6;}
+fi
diff --git a/configure.ac b/configure.ac
index 5860595b752c8..6826f405365d0 100644
--- a/configure.ac
+++ b/configure.ac
@@ -4168,6 +4168,95 @@ then
 fi
 AC_MSG_RESULT($with_doc_strings)
 
+# Check for stdatomic.h, required for mimalloc.
+AC_CACHE_CHECK([for stdatomic.h], [ac_cv_header_stdatomic_h], [
+AC_LINK_IFELSE(
+[
+  AC_LANG_SOURCE([[
+    #include <stdatomic.h>
+    atomic_int int_var;
+    atomic_uintptr_t uintptr_var;
+    int main() {
+      atomic_store_explicit(&int_var, 5, memory_order_relaxed);
+      atomic_store_explicit(&uintptr_var, 0, memory_order_relaxed);
+      int loaded_value = atomic_load_explicit(&int_var, memory_order_seq_cst);
+      return 0;
+    }
+  ]])
+],[ac_cv_header_stdatomic_h=yes],[ac_cv_header_stdatomic_h=no])
+])
+
+AS_VAR_IF([ac_cv_header_stdatomic_h], [yes], [
+    AC_DEFINE(HAVE_STD_ATOMIC, 1,
+              [Has stdatomic.h with atomic_int and atomic_uintptr_t])
+])
+
+# Check for GCC >= 4.7 and clang __atomic builtin functions
+AC_CACHE_CHECK([for builtin __atomic_load_n and __atomic_store_n functions], [ac_cv_builtin_atomic], [
+AC_LINK_IFELSE(
+[
+  AC_LANG_SOURCE([[
+    int val;
+    int main() {
+      __atomic_store_n(&val, 1, __ATOMIC_SEQ_CST);
+      (void)__atomic_load_n(&val, __ATOMIC_SEQ_CST);
+      return 0;
+    }
+  ]])
+],[ac_cv_builtin_atomic=yes],[ac_cv_builtin_atomic=no])
+])
+
+AS_VAR_IF([ac_cv_builtin_atomic], [yes], [
+    AC_DEFINE(HAVE_BUILTIN_ATOMIC, 1, [Has builtin __atomic_load_n() and __atomic_store_n() functions])
+])
+
+# --with-mimalloc
+AC_MSG_CHECKING([for --with-mimalloc])
+AC_ARG_WITH([mimalloc],
+  [AS_HELP_STRING([--with-mimalloc],
+                 [build with mimalloc memory allocator (default is yes if C11 stdatomic.h is available.)])],
+  [],
+  [with_mimalloc="$ac_cv_header_stdatomic_h"]
+)
+
+if test "$with_mimalloc" != no; then
+  if test "$ac_cv_header_stdatomic_h" != yes; then
+    # mimalloc-atomic.h wants C11 stdatomic.h on POSIX
+    AC_MSG_ERROR([mimalloc requires stdatomic.h, use --without-mimalloc to disable mimalloc.])
+  fi
+  with_mimalloc=yes
+  AC_DEFINE([WITH_MIMALLOC], [1], [Define if you want to compile in mimalloc memory allocator.])
+  AC_SUBST([MIMALLOC_HEADERS], ['$(MIMALLOC_HEADERS)'])
+  AC_SUBST([MIMALLOC_INCLUDES], ['$(MIMALLOC_INCLUDES)'])
+fi
+AC_MSG_RESULT([$with_mimalloc])
+
+AC_MSG_CHECKING([for --enable-mimalloc-secure])
+AC_ARG_ENABLE([mimalloc-secure],
+  [AS_HELP_STRING([--enable-mimalloc-secure@<:@=yes|no|1|2|3|4@:>@],
+                  [enable mimalloc security mitigations (default is no), 1: guard metadata, 2: guard pages, 3: encode freelists, 4/yes: detect double free])],
+  [
+    AS_CASE([$enable_mimalloc_secure],
+      [yes], [enable_mimalloc_secure=4],
+      [1|2|3|4], [],
+      [no], [],
+      [enable_mimalloc_secure=invalid]
+    )
+    AS_VAR_IF([enable_mimalloc_secure], [invalid], [AC_MSG_ERROR([bad value $enable_mimalloc_secure for --enable-mimalloc-secure])])
+  ],
+  [enable_mimalloc_secure="no"]
+)
+
+if test "$enable_mimalloc_secure" != "no"; then
+  AS_VAR_IF([with_mimalloc], [no], [AC_MSG_ERROR([--with-mimalloc-secure requires --with-mimalloc])])
+  AC_DEFINE_UNQUOTED(
+    [PY_MIMALLOC_SECURE],
+    [$enable_mimalloc_secure],
+    [Define to 1, 2, 3, or 4 to enable mimalloc's security mitigations (Py_DEBUG forces 4)]
+    )
+fi
+AC_MSG_RESULT([$enable_mimalloc_secure])
+
 # Check for Python-specific malloc support
 AC_MSG_CHECKING(for --with-pymalloc)
 AC_ARG_WITH(pymalloc,
@@ -6088,6 +6177,7 @@ SRCDIRS="\
   Modules/cjkcodecs \
   Modules/expat \
   Objects \
+  Objects/mimalloc \
   Parser \
   Programs \
   Python \
@@ -6183,48 +6273,6 @@ if test "$ac_cv_gcc_asm_for_x87" = yes; then
     esac
 fi
 
-# Check for stdatomic.h
-AC_CACHE_CHECK([for stdatomic.h], [ac_cv_header_stdatomic_h], [
-AC_LINK_IFELSE(
-[
-  AC_LANG_SOURCE([[
-    #include <stdatomic.h>
-    atomic_int int_var;
-    atomic_uintptr_t uintptr_var;
-    int main() {
-      atomic_store_explicit(&int_var, 5, memory_order_relaxed);
-      atomic_store_explicit(&uintptr_var, 0, memory_order_relaxed);
-      int loaded_value = atomic_load_explicit(&int_var, memory_order_seq_cst);
-      return 0;
-    }
-  ]])
-],[ac_cv_header_stdatomic_h=yes],[ac_cv_header_stdatomic_h=no])
-])
-
-AS_VAR_IF([ac_cv_header_stdatomic_h], [yes], [
-    AC_DEFINE(HAVE_STD_ATOMIC, 1,
-              [Has stdatomic.h with atomic_int and atomic_uintptr_t])
-])
-
-# Check for GCC >= 4.7 and clang __atomic builtin functions
-AC_CACHE_CHECK([for builtin __atomic_load_n and __atomic_store_n functions], [ac_cv_builtin_atomic], [
-AC_LINK_IFELSE(
-[
-  AC_LANG_SOURCE([[
-    int val;
-    int main() {
-      __atomic_store_n(&val, 1, __ATOMIC_SEQ_CST);
-      (void)__atomic_load_n(&val, __ATOMIC_SEQ_CST);
-      return 0;
-    }
-  ]])
-],[ac_cv_builtin_atomic=yes],[ac_cv_builtin_atomic=no])
-])
-
-AS_VAR_IF([ac_cv_builtin_atomic], [yes], [
-    AC_DEFINE(HAVE_BUILTIN_ATOMIC, 1, [Has builtin __atomic_load_n() and __atomic_store_n() functions])
-])
-
 # ensurepip option
 AC_MSG_CHECKING(for ensurepip)
 AC_ARG_WITH(ensurepip,
@@ -6911,3 +6959,10 @@ If you want a release build with all stable optimizations active (PGO, etc),
 please run ./configure --enable-optimizations
 ])
 fi
+
+if test "$ac_cv_header_stdatomic_h" != "yes"; then
+  AC_MSG_NOTICE(m4_normalize([
+    Your compiler or platform does have a working C11 stdatomic.h. A future
+    version of Python may require stdatomic.h.
+  ]))
+fi
\ No newline at end of file
diff --git a/pyconfig.h.in b/pyconfig.h.in
index 4ac054a28d8ef..1c55e6838b230 100644
--- a/pyconfig.h.in
+++ b/pyconfig.h.in
@@ -1503,6 +1503,10 @@
 /* Define to printf format modifier for Py_ssize_t */
 #undef PY_FORMAT_SIZE_T
 
+/* Define to 1, 2, 3, or 4 to enable mimalloc's security mitigations (Py_DEBUG
+   forces 4) */
+#undef PY_MIMALLOC_SECURE
+
 /* Define to 1 to build the sqlite module with loadable extensions support. */
 #undef PY_SQLITE_ENABLE_LOAD_EXTENSION
 
@@ -1666,6 +1670,9 @@
 /* Define to 1 if libintl is needed for locale functions. */
 #undef WITH_LIBINTL
 
+/* Define if you want to compile in mimalloc memory allocator. */
+#undef WITH_MIMALLOC
+
 /* Define if you want to produce an OpenStep/Rhapsody framework (shared
    library plus accessory files). */
 #undef WITH_NEXT_FRAMEWORK

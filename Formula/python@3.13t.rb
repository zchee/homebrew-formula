class PythonAT313t < Formula
  desc "Interpreted, interactive, object-oriented programming language"
  homepage "https://www.python.org/"
  url "https://www.python.org/ftp/python/3.13.0/Python-3.13.0.tgz"
  sha256 "12445c7b3db3126c41190bfdc1c8239c39c719404e844babbd015a1bc3fafcd4"
  license "Python-2.0"

  livecheck do
    url "https://www.python.org/ftp/python/"
    regex(%r{href=.*?v?(3\.13(?:\.\d+)*)/?["' >]}i)
  end

  # setuptools remembers the build flags python is built with and uses them to
  # build packages later. Xcode-only systems need different flags.
  pour_bottle? only_if: :clt_installed

  depends_on "pkg-config" => :build
  depends_on "mpdecimal"
  depends_on "openssl@3"
  depends_on "sqlite"
  depends_on "xz"

  uses_from_macos "bzip2"
  uses_from_macos "expat"
  uses_from_macos "libedit"
  uses_from_macos "libffi", since: :catalina
  uses_from_macos "libxcrypt"
  uses_from_macos "ncurses"
  uses_from_macos "unzip"
  uses_from_macos "zlib"

  on_linux do
    depends_on "berkeley-db@5"
    depends_on "libnsl"
    depends_on "libtirpc"
  end

  depends_on "llvm@18" => :build # for --enable-experimental-jit
  depends_on "ncurses-head"
  depends_on "readline"

  env :std

  link_overwrite "bin/2to3"
  link_overwrite "bin/idle3"
  link_overwrite "bin/pip3"
  link_overwrite "bin/pydoc3"
  link_overwrite "bin/python3"
  link_overwrite "bin/python3-config"
  link_overwrite "bin/wheel3"
  link_overwrite "share/man/man1/python3.1"
  link_overwrite "lib/libpython3.so"
  link_overwrite "lib/pkgconfig/python3.pc"
  link_overwrite "lib/pkgconfig/python3-embed.pc"
  link_overwrite "Frameworks/Python.framework/Headers"
  link_overwrite "Frameworks/Python.framework/Python"
  link_overwrite "Frameworks/Python.framework/Resources"
  link_overwrite "Frameworks/Python.framework/Versions/Current"

  # Always update to latest release
  resource "flit-core" do
    url "https://files.pythonhosted.org/packages/c4/e6/c1ac50fe3eebb38a155155711e6e864e254ce4b6e17fe2429b4c4d5b9e80/flit_core-3.9.0.tar.gz"
    sha256 "72ad266176c4a3fcfab5f2930d76896059851240570ce9a98733b658cb786eba"
  end

  resource "pip" do
    url "https://files.pythonhosted.org/packages/4d/87/fb90046e096a03aeab235e139436b3fe804cdd447ed2093b0d70eba3f7f8/pip-24.2.tar.gz"
    sha256 "5b5e490b5e9cb275c879595064adce9ebd31b854e3e803740b72f9ccf34a45b8"
  end

  resource "setuptools" do
    url "https://files.pythonhosted.org/packages/27/b8/f21073fde99492b33ca357876430822e4800cdf522011f18041351dfa74b/setuptools-75.1.0.tar.gz"
    sha256 "d59a21b17a275fb872a9c3dae73963160ae079f1049ed956880cd7c09b120538"
  end

  resource "wheel" do
    url "https://files.pythonhosted.org/packages/b7/a0/95e9e962c5fd9da11c1e28aa4c0d8210ab277b1ada951d2aee336b505813/wheel-0.44.0.tar.gz"
    sha256 "a29c3f2817e95ab89aa4660681ad547c0e9547f20e75b0562fe7723c9a2a9d49"
  end

  # Modify default sysconfig to match the brew install layout.
  # Remove when a non-patching mechanism is added (https://bugs.python.org/issue43976).
  # We (ab)use osx_framework_library to exploit pip behaviour to allow --prefix to still work.
  patch do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/8b5bcbb262d1ea4e572bba55043bf7d2341a6821/python/3.13-sysconfig.diff"
    sha256 "e1c2699cf3e39731a19207ed69400a67336cda7767aa08f6f46029f26b1d733b"
  end

  def lib_cellar
    on_macos do
      return frameworks/"Python.framework/Versions"/version.major_minor/"lib/python#{version.major_minor}t"
    end
    on_linux do
      return lib/"python#{version.major_minor}t"
    end
  end

  def site_packages_cellar
    lib_cellar/"site-packages"
  end

  # The HOMEBREW_PREFIX location of site-packages.
  def site_packages
    HOMEBREW_PREFIX/"lib/python#{version.major_minor}t/site-packages"
  end

  def python3
    bin/"python#{version.major_minor}t"
  end

  def install
    # Unset these so that installing pip and setuptools puts them where we want
    # and not into some other Python the user has installed.
    ENV["PYTHONHOME"] = nil
    ENV["PYTHONPATH"] = nil

    # Override the auto-detection of libmpdec, which assumes a universal build.
    # This is currently an inreplace due to https://github.com/python/cpython/issues/98557.
    if OS.mac?
      inreplace "configure", "libmpdec_machine=universal",
                "libmpdec_machine=#{ENV["PYTHON_DECIMAL_WITH_MACHINE"] = Hardware::CPU.arm? ? "uint128" : "x64"}"
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
      --with-openssl=#{Formula["openssl@3"].opt_prefix}
      --enable-optimizations
      --with-system-expat
      --with-system-libmpdec

      --enable-experimental-jit=yes
      --disable-gil
      --with-mimalloc=yes
      --with-readline=readline
    ]
      # TODO(zchee): enable
      # --enable-bolt

    # Python re-uses flags when building native modules.
    # Since we don't want native modules prioritizing the brew
    # include path, we move them to [C|LD]FLAGS_NODIST.
    # Note: Changing CPPFLAGS causes issues with dbm, so we
    # leave it as-is.
    cflags         = []
    cflags_nodist  = ["-I#{HOMEBREW_PREFIX}/include"]
    ldflags        = ["-L#{Formula["llvm@18"].opt_lib}/c++", "-L#{Formula["llvm@18"].opt_lib}", "-lunwind"]
    ldflags_nodist = ["-L#{HOMEBREW_PREFIX}/lib", "-Wl,-rpath,#{HOMEBREW_PREFIX}/lib"]
    cppflags       = ["-I#{HOMEBREW_PREFIX}/include", "-I#{Formula["llvm@18"].opt_include}"]

    if OS.mac?
      # for --enable-experimental-jit
      ENV.append_path "PATH", "#{Formula["llvm@18"].opt_bin}"
      ENV["CC"] = "#{Formula["llvm@18"].opt_bin}/clang-18"

      if MacOS.sdk_path_if_needed
        # Help Python's build system (setuptools/pip) to build things on SDK-based systems
        # The setup.py looks at "-isysroot" to get the sysroot (and not at --sysroot)
        cflags  << "-isysroot #{MacOS.sdk_path}"
        ldflags << "-isysroot #{MacOS.sdk_path}"
      end

      # Enabling LTO on Linux makes libpython3.*.a unusable for anyone whose GCC
      # install does not match the one in CI _exactly_ (major and minor version).
      # https://github.com/orgs/Homebrew/discussions/3734
      args << "--with-lto"
      args << "--enable-framework=#{frameworks}"
      args << "--with-dtrace"
      args << "--with-dbmliborder=ndbm"

      # Avoid linking to libgcc https://mail.python.org/pipermail/python-dev/2012-February/116205.html
      args << "MACOSX_DEPLOYMENT_TARGET=#{MacOS.version}"
    else
      args << "--enable-shared"
      args << "--with-dbmliborder=bdb"
    end

    # Resolve HOMEBREW_PREFIX in our sysconfig modification.
    inreplace "Lib/sysconfig/__init__.py", "@@HOMEBREW_PREFIX@@", HOMEBREW_PREFIX

    # Allow python modules to use ctypes.find_library to find homebrew's stuff
    # even if homebrew is not a /usr/local/lib. Try this with:
    # `brew install enchant && pip install pyenchant`
    inreplace "./Lib/ctypes/macholib/dyld.py" do |f|
      f.gsub! "DEFAULT_LIBRARY_FALLBACK = [",
              "DEFAULT_LIBRARY_FALLBACK = [ '#{HOMEBREW_PREFIX}/lib', '#{Formula["openssl@3"].opt_lib}',"
      f.gsub! "DEFAULT_FRAMEWORK_FALLBACK = [", "DEFAULT_FRAMEWORK_FALLBACK = [ '#{HOMEBREW_PREFIX}/Frameworks',"
    end

    args << "CFLAGS=#{cflags.join(" ")}" unless cflags.empty?
    args << "CFLAGS_NODIST=#{cflags_nodist.join(" ")}" unless cflags_nodist.empty?
    args << "LDFLAGS=#{ldflags.join(" ")}" unless ldflags.empty?
    args << "LDFLAGS_NODIST=#{ldflags_nodist.join(" ")}" unless ldflags_nodist.empty?
    args << "CPPFLAGS=#{cppflags.join(" ")}" unless cppflags.empty?

    # Disabled modules - provided in separate formulae
    args += %w[
      py_cv_module__tkinter=disabled
    ]

    system "./configure", *args
    system "make"

    ENV.deparallelize do
      # Tell Python not to install into /Applications (default for framework builds)
      system "make", "install", "PYTHONAPPSDIR=#{prefix}"
      system "make", "frameworkinstallextras", "PYTHONAPPSDIR=#{pkgshare}" if OS.mac?
    end

    if OS.mac?
      # Any .app get a " 3" attached, so it does not conflict with python 2.x.
      prefix.glob("*.app") { |app| mv app, app.to_s.sub(/\.app$/, " 3.app") }

      pc_dir = frameworks/"Python.framework/Versions/#{version.major_minor}/lib/pkgconfig"
      # Symlink the pkgconfig files into HOMEBREW_PREFIX so they're accessible.
      (lib/"pkgconfig").install_symlink pc_dir.children

      # Prevent third-party packages from building against fragile Cellar paths
      bad_cellar_path_files = [
        # lib_cellar/"_sysconfigdata__darwin_darwin.py",
        lib_cellar/"config-#{version.major_minor}t-darwin/Makefile",
        pc_dir/"python-#{version.major_minor}t.pc",
        pc_dir/"python-#{version.major_minor}t-embed.pc",
      ]
      inreplace bad_cellar_path_files, prefix, opt_prefix

      # Help third-party packages find the Python framework
      inreplace lib_cellar/"config-#{version.major_minor}t-darwin/Makefile",
                /^LINKFORSHARED=(.*)PYTHONFRAMEWORKDIR(.*)/,
                "LINKFORSHARED=\\1PYTHONFRAMEWORKINSTALLDIR\\2"

      # Symlink the pkgconfig files into HOMEBREW_PREFIX so they're accessible.
      (lib/"pkgconfig").install_symlink pc_dir.children

      # Error: inreplace failed
      # /usr/local/Cellar/python@3.13t/3.13.0/Frameworks/Python.framework/Versions/3.13/lib/python3.13/_sysconfigdata__darwin_darwin.py:
      #   expected replacement of "/usr/local/Cellar/python@3.13t/3.13.0" with "/usr/local/opt/python@3.13t"
      # /usr/local/Cellar/python@3.13t/3.13.0/Frameworks/Python.framework/Versions/3.13/lib/python3.13/config-3.13-darwin/Makefile:
      #   expected replacement of "/usr/local/Cellar/python@3.13t/3.13.0" with "/usr/local/opt/python@3.13t"
      # /usr/local/Homebrew/Library/Homebrew/ignorable.rb:27:in `block in raise'
      
      # system "cat", "/usr/local/Cellar/python@3.13t/3.13.0/Frameworks/Python.framework/Versions/3.13/lib/python3.13/_sysconfigdata__darwin_darwin.py"
      # system "cat", "/usr/local/Cellar/python@3.13t/3.13.0/Frameworks/Python.framework/Versions/3.13/lib/python3.13/config-3.13-darwin/Makefile"

      # Fix for https://github.com/Homebrew/homebrew-core/issues/21212
      # inreplace lib_cellar/"_sysconfigdata__darwin_darwin.py",
      #           %r{('LINKFORSHARED': .*?) (Python.framework/Versions/3.\d+/Python)'}m,
      #           "\\1 #{opt_prefix}/Frameworks/\\2'"
    else
      # Prevent third-party packages from building against fragile Cellar paths
      inreplace Dir[lib_cellar/"**/_sysconfigdata_*linux_x86_64-*.py",
                    lib_cellar/"config*/Makefile",
                    bin/"python#{version.major_minor}t-config",
                    lib/"pkgconfig/python-3*.pc"],
                prefix, opt_prefix

      inreplace bin/"python#{version.major_minor}t-config",
                'prefix_real=$(installed_prefix "$0")',
                "prefix_real=#{opt_prefix}"
    end

    # Remove the site-packages that Python created in its Cellar.
    rm_r(site_packages_cellar)

    # Prepare a wheel of wheel to install later.
    common_pip_args = %w[
      -v
      --no-deps
      --no-binary :all:
      --no-index
      --no-build-isolation
    ]
    whl_build = buildpath/"whl_build"
    system python3, "-m", "venv", whl_build
    %w[flit-core wheel setuptools].each do |r|
      resource(r).stage do
        system whl_build/"bin/pip3", "install", *common_pip_args, "."
      end
    end
    resource("wheel").stage do
      system whl_build/"bin/pip3", "wheel", *common_pip_args,
                                            "--wheel-dir=#{libexec}",
                                            "."
    end

    # Replace bundled pip with our own.
    rm lib_cellar.glob("ensurepip/_bundled/pip-*.whl")
    %w[pip].each do |r|
      resource(r).stage do
        system whl_build/"bin/pip3", "wheel", *common_pip_args,
                                              "--wheel-dir=#{lib_cellar}/ensurepip/_bundled",
                                              "."
      end
    end

    # Patch ensurepip to bootstrap our updated version of pip
    inreplace lib_cellar/"ensurepip/__init__.py" do |s|
      s.gsub!(/_PIP_VERSION = .*/, "_PIP_VERSION = \"#{resource("pip").version}\"")
    end

    # Write out sitecustomize.py
    (lib_cellar/"sitecustomize.py").atomic_write(sitecustomize)

    # Install unversioned symlinks in libexec/bin.
    {
      "idle"          => "idle#{version.major_minor}",
      "pydoc"         => "pydoc#{version.major_minor}",
      "python"        => "python#{version.major_minor}",
      "python-config" => "python#{version.major_minor}-config",
    }.each do |short_name, long_name|
      (libexec/"bin").install_symlink (bin/long_name).realpath => short_name
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
    rm_r(Dir["#{site_packages}/sitecustomize.py[co]"])

    # Remove old setuptools installations that may still fly around and be
    # listed in the easy_install.pth. This can break setuptools build with
    # zipimport.ZipImportError: bad local file header
    # setuptools-0.9.8-py3.3.egg
    rm_r(Dir["#{site_packages}/distribute[-_.][0-9]*", "#{site_packages}/distribute"])
    rm_r(Dir["#{site_packages}/pip[-_.][0-9]*", "#{site_packages}/pip"])
    rm_r(Dir["#{site_packages}/wheel[-_.][0-9]*", "#{site_packages}/wheel"])

    (lib_cellar/"EXTERNALLY-MANAGED").unlink if (lib_cellar/"EXTERNALLY-MANAGED").exist?
    system python3, "-Im", "ensurepip"

    # Install desired versions of pip, wheel using the version of
    # pip bootstrapped by ensurepip.
    # Note that while we replaced the ensurepip wheels, there's no guarantee
    # ensurepip actually used them, since other existing installations could
    # have been picked up (and we can't pass --ignore-installed).
    bundled = lib_cellar/"ensurepip/_bundled"
    system python3, "-Im", "pip", "install", "-v",
           "--no-deps",
           "--no-index",
           "--upgrade",
           "--isolated",
           "--target=#{site_packages}",
           bundled/"pip-#{resource("pip").version}-py3-none-any.whl",
           libexec/"wheel-#{resource("wheel").version}-py3-none-any.whl"

    # pip install with --target flag will just place the bin folder into the
    # target, so move its contents into the appropriate location
    mv (site_packages/"bin").children, bin
    rmdir site_packages/"bin"

    rm_r(bin/"pip")
    mv bin/"wheel", bin/"wheel#{version.major_minor}"
    bin.install_symlink "wheel#{version.major_minor}" => "wheel3"

    # Install unversioned symlinks in libexec/bin.
    {
      "pip"   => "pip#{version.major_minor}",
      "wheel" => "wheel#{version.major_minor}",
    }.each do |short_name, long_name|
      (libexec/"bin").install_symlink (bin/long_name).realpath => short_name
    end

    # post_install happens after link
    %W[wheel3 pip3 wheel#{version.major_minor} pip#{version.major_minor}].each do |e|
      (HOMEBREW_PREFIX/"bin").install_symlink bin/e
    end

    # Mark Homebrew python as externally managed: https://peps.python.org/pep-0668/#marking-an-interpreter-as-using-an-external-package-manager
    # Placed after ensurepip since it invokes pip in isolated mode, meaning
    # we can't pass --break-system-packages.
    (lib_cellar/"EXTERNALLY-MANAGED").write <<~EOS
      [externally-managed]
      Error=To install Python packages system-wide, try brew install
       xyz, where xyz is the package you are trying to
       install.

       If you wish to install a Python library that isn't in Homebrew,
       use a virtual environment:

         python3 -m venv path/to/venv
         source path/to/venv/bin/activate
         python3 -m pip install xyz

       If you wish to install a Python application that isn't in Homebrew,
       it may be easiest to use 'pipx install xyz', which will manage a
       virtual environment for you. You can install pipx with

         brew install pipx

       You may restore the old behavior of pip by passing
       the '--break-system-packages' flag to pip, or by adding
       'break-system-packages = true' to your pip.conf file. The latter
       will permanently disable this error.

       If you disable this error, we STRONGLY recommend that you additionally
       pass the '--user' flag to pip, or set 'user = true' in your pip.conf
       file. Failure to do this can result in a broken Homebrew installation.

       Read more about this behavior here: <https://peps.python.org/pep-0668/>
    EOS
  end

  def sitecustomize
    <<~EOS
      # This file is created by Homebrew and is executed on each python startup.
      # Don't print from here, or else python command line scripts may fail!
      # <https://docs.brew.sh/Homebrew-and-Python>
      import re
      import os
      import site
      import sys
      if sys.version_info[:2] != (#{version.major}, #{version.minor}):
          # This can only happen if the user has set the PYTHONPATH to a mismatching site-packages directory.
          # Every Python looks at the PYTHONPATH variable and we can't fix it here in sitecustomize.py,
          # because the PYTHONPATH is evaluated after the sitecustomize.py. Many modules (e.g. PyQt4) are
          # built only for a specific version of Python and will fail with cryptic error messages.
          # In the end this means: Don't set the PYTHONPATH permanently if you use different Python versions.
          exit(f'Your PYTHONPATH points to a site-packages dir for Python #{version.major_minor}t '
               f'but you are running Python {sys.version_info[0]}.{sys.version_info[1]}!\\n'
               f'     PYTHONPATH is currently: "{os.environ["PYTHONPATH"]}"\\n'
               f'     You should `unset PYTHONPATH` to fix this.')
      # Only do this for a brewed python:
      if os.path.realpath(sys.executable).startswith('#{rack}'):
          # Shuffle /Library site-packages to the end of sys.path
          library_site = '/Library/Python/#{version.major_minor}t/site-packages'
          library_packages = [p for p in sys.path if p.startswith(library_site)]
          sys.path = [p for p in sys.path if not p.startswith(library_site)]
          # .pth files have already been processed so don't use addsitedir
          sys.path.extend(library_packages)
          # the Cellar site-packages is a symlink to the HOMEBREW_PREFIX
          # site_packages; prefer the shorter paths
          long_prefix = re.compile(r'#{rack}/[0-9\\._abrc]+/Frameworks/Python\\.framework/Versions/#{version.major_minor}t/lib/python#{version.major_minor}t/site-packages')
          sys.path = [long_prefix.sub('#{site_packages}', p) for p in sys.path]
          # Set the sys.executable to use the opt_prefix. Only do this if PYTHONEXECUTABLE is not
          # explicitly set and we are not in a virtualenv:
          if 'PYTHONEXECUTABLE' not in os.environ and sys.prefix == sys.base_prefix:
              sys.executable = sys._base_executable = '#{opt_bin}/python#{version.major_minor}t'
      if 'PYTHONHOME' not in os.environ:
          cellar_prefix = re.compile(r'#{rack}/[0-9\\._abrc]+/')
          if os.path.realpath(sys.base_prefix).startswith('#{rack}'):
              new_prefix = cellar_prefix.sub('#{opt_prefix}/', sys.base_prefix)
              if sys.prefix == sys.base_prefix:
                  site.PREFIXES[:] = [new_prefix if x == sys.prefix else x for x in site.PREFIXES]
                  sys.prefix = new_prefix
              sys.base_prefix = new_prefix
          if os.path.realpath(sys.base_exec_prefix).startswith('#{rack}'):
              new_exec_prefix = cellar_prefix.sub('#{opt_prefix}/', sys.base_exec_prefix)
              if sys.exec_prefix == sys.base_exec_prefix:
                  site.PREFIXES[:] = [new_exec_prefix if x == sys.exec_prefix else x for x in site.PREFIXES]
                  sys.exec_prefix = new_exec_prefix
              sys.base_exec_prefix = new_exec_prefix
      # Check for and add the prefix of split Python formulae.
      for split_module in ["tk", "gdbm"]:
          split_prefix = f"#{HOMEBREW_PREFIX}/opt/python-{split_module}@#{version.major_minor}t/libexec"
          if os.path.isdir(split_prefix):
              sys.path.append(split_prefix)
    EOS
  end

  def caveats
    <<~EOS
      Python is installed as
        #{HOMEBREW_PREFIX}/bin/python3

      Unversioned symlinks `python`, `python-config`, `pip` etc. pointing to
      `python3`, `python3-config`, `pip3` etc., respectively, are installed into
        #{opt_libexec}/bin

      See: https://docs.brew.sh/Homebrew-and-Python
    EOS
  end

  test do
    # Check if sqlite is ok, because we build with --enable-loadable-sqlite-extensions
    # and it can occur that building sqlite silently fails if OSX's sqlite is used.
    system python3, "-c", "import sqlite3"

    # check to see if we can create a venv
    system python3, "-m", "venv", testpath/"myvenv"

    # Check if some other modules import. Then the linked libs are working.
    system python3, "-c", "import _ctypes"
    system python3, "-c", "import _decimal"
    system python3, "-c", "import pyexpat"
    system python3, "-c", "import readline"
    system python3, "-c", "import zlib"

    # tkinter is provided in a separate formula
    assert_match "ModuleNotFoundError: No module named '_tkinter'",
                 shell_output("#{python3} -Sc 'import tkinter' 2>&1", 1)

    # gdbm is provided in a separate formula
    assert_match "ModuleNotFoundError: No module named '_gdbm'",
                 shell_output("#{python3} -Sc 'import _gdbm' 2>&1", 1)
    assert_match "ModuleNotFoundError: No module named '_gdbm'",
                 shell_output("#{python3} -Sc 'import dbm.gnu' 2>&1", 1)

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
    system python3, "dbm_test.py"

    system bin/"pip#{version.major_minor}t", "list", "--format=columns"

    # Verify our sysconfig patches
    sysconfig_path = "import sysconfig; print(sysconfig.get_paths(\"osx_framework_library\")[\"data\"])"
    assert_equal HOMEBREW_PREFIX.to_s, shell_output("#{python3} -c '#{sysconfig_path}'").strip
    linkforshared_var = "import sysconfig; print(sysconfig.get_config_var(\"LINKFORSHARED\"))"
    assert_match opt_prefix.to_s, shell_output("#{python3} -c '#{linkforshared_var}'") if OS.mac?

    # Check our externally managed marker
    assert_match "If you wish to install a Python library",
                 shell_output("#{python3} -m pip install pip 2>&1", 1)
  end
end

# Optional Features:
#   --disable-option-checking  ignore unrecognized --enable/--with options
#   --disable-FEATURE       do not include FEATURE (same as --enable-FEATURE=no)
#   --enable-FEATURE[=ARG]  include FEATURE [ARG=yes]
#   --enable-universalsdk[=SDKDIR]
#                           create a universal binary build. SDKDIR specifies
#                           which macOS SDK should be used to perform the build,
#                           see Mac/README.rst. (default is no)
#   --enable-framework[=INSTALLDIR]
#                           create a Python.framework rather than a traditional
#                           Unix install. optional INSTALLDIR specifies the
#                           installation path. see Mac/README.rst (default is
#                           no)
#   --enable-wasm-dynamic-linking
#                           Enable dynamic linking support for WebAssembly
#                           (default is no)
#   --enable-wasm-pthreads  Enable pthread emulation for WebAssembly (default is
#                           no)
#   --enable-shared         enable building a shared Python library (default is
#                           no)
#   --enable-profiling      enable C-level code profiling with gprof (default is
#                           no)
#   --disable-gil           enable experimental support for running without the
#                           GIL (default is no)
#   --enable-pystats        enable internal statistics gathering (default is no)
#   --enable-experimental-jit[=no|yes|yes-off|interpreter]
#                           build the experimental just-in-time compiler
#                           (default is no)
#   --enable-optimizations  enable expensive, stable optimizations (PGO, etc.)
#                           (default is no)
#   --enable-bolt           enable usage of the llvm-bolt post-link optimizer
#                           (default is no)
#   --enable-loadable-sqlite-extensions
#                           support loadable extensions in the sqlite3 module,
#                           see Doc/library/sqlite3.rst (default is no)
#   --enable-ipv6           enable ipv6 (with ipv4) support, see
#                           Doc/library/socket.rst (default is yes if supported)
#   --enable-big-digits[=15|30]
#                           use big digits (30 or 15 bits) for Python longs
#                           (default is 30)]
#   --disable-test-modules  don't build nor install test modules
#
# Optional Packages:
#   --with-PACKAGE[=ARG]    use PACKAGE [ARG=yes]
#   --without-PACKAGE       do not use PACKAGE (same as --with-PACKAGE=no)
#   --with-build-python=python3.13
#                           path to build python binary for cross compiling
#                           (default: _bootstrap_python or python3.13)
#   --with-pkg-config=[yes|no|check]
#                           use pkg-config to detect build options (default is
#                           check)
#   --with-universal-archs=ARCH
#                           specify the kind of macOS universal binary that
#                           should be created. This option is only valid when
#                           --enable-universalsdk is set; options are:
#                           ("universal2", "intel-64", "intel-32", "intel",
#                           "32-bit", "64-bit", "3-way", or "all") see
#                           Mac/README.rst
#   --with-framework-name=FRAMEWORK
#                           specify the name for the python framework on macOS
#                           only valid when --enable-framework is set. see
#                           Mac/README.rst (default is 'Python')
#   --with-app-store-compliance=[PATCH-FILE]
#                           Enable any patches required for compiliance with app
#                           stores. Optional PATCH-FILE specifies the custom
#                           patch to apply.
#   --with-emscripten-target=[browser|node]
#                           Emscripten platform
#   --with-suffix=SUFFIX    set executable suffix to SUFFIX (default is empty,
#                           yes is mapped to '.exe')
#   --without-static-libpython
#                           do not build libpythonMAJOR.MINOR.a and do not
#                           install python.o (default is yes)
#   --with-pydebug          build with Py_DEBUG defined (default is no)
#   --with-trace-refs       enable tracing references for debugging purpose
#                           (default is no)
#   --with-assertions       build with C assertions enabled (default is no)
#   --with-lto=[full|thin|no|yes]
#                           enable Link-Time-Optimization in any build (default
#                           is no)
#   --with-strict-overflow  if 'yes', add -fstrict-overflow to CFLAGS, else add
#                           -fno-strict-overflow (default is no)
#   --with-dsymutil         link debug information into final executable with
#                           dsymutil in macOS (default is no)
#   --with-address-sanitizer
#                           enable AddressSanitizer memory error detector,
#                           'asan' (default is no)
#   --with-memory-sanitizer enable MemorySanitizer allocation error detector,
#                           'msan' (default is no)
#   --with-undefined-behavior-sanitizer
#                           enable UndefinedBehaviorSanitizer undefined
#                           behaviour detector, 'ubsan' (default is no)
#   --with-thread-sanitizer enable ThreadSanitizer data race detector, 'tsan'
#                           (default is no)
#   --with-hash-algorithm=[fnv|siphash13|siphash24]
#                           select hash algorithm for use in Python/pyhash.c
#                           (default is SipHash13)
#   --with-tzpath=<list of absolute paths separated by pathsep>
#                           Select the default time zone search path for
#                           zoneinfo.TZPATH
#   --with-libs='lib1 ...'  link against additional libs (default is no)
#   --with-system-expat     build pyexpat module using an installed expat
#                           library, see Doc/library/pyexpat.rst (default is no)
#   --with-system-libmpdec  build _decimal module using an installed mpdecimal
#                           library, see Doc/library/decimal.rst (default is
#                           yes)
#   --with-decimal-contextvar
#                           build _decimal module using a coroutine-local rather
#                           than a thread-local context (default is yes)
#   --with-dbmliborder=db1:db2:...
#                           override order to check db backends for dbm; a valid
#                           value is a colon separated string with the backend
#                           names `ndbm', `gdbm' and `bdb'.
#   --with-doc-strings      enable documentation strings (default is yes)
#   --with-mimalloc         build with mimalloc memory allocator (default is yes
#                           if C11 stdatomic.h is available.)
#   --with-pymalloc         enable specialized mallocs (default is yes)
#   --with-freelists        enable object freelists (default is yes)
#   --with-c-locale-coercion
#                           enable C locale coercion to a UTF-8 based locale
#                           (default is yes)
#   --with-valgrind         enable Valgrind support (default is no)
#   --with-dtrace           enable DTrace support (default is no)
#   --with-libm=STRING      override libm math library to STRING (default is
#                           system-dependent)
#   --with-libc=STRING      override libc C library to STRING (default is
#                           system-dependent)
#   --with-platlibdir=DIRNAME
#                           Python library directory name (default is "lib")
#   --with-wheel-pkg-dir=PATH
#                           Directory of wheel packages used by ensurepip
#                           (default: none)
#   --with(out)-readline[=editline|readline|no]
#                           use libedit for backend or disable readline module
#   --with-computed-gotos   enable computed gotos in evaluation loop (enabled by
#                           default on supported compilers)
#   --with-ensurepip[=install|upgrade|no]
#                           "install" or "upgrade" using bundled pip (default is
#                           upgrade)
#   --with-openssl=DIR      root of the OpenSSL directory
#   --with-openssl-rpath=[DIR|auto|no]
#                           Set runtime library directory (rpath) for OpenSSL
#                           libraries, no (default): don't set rpath, auto:
#                           auto-detect rpath from --with-openssl and
#                           pkg-config, DIR: set an explicit rpath
#   --with-ssl-default-suites=[python|openssl|STRING]
#                           override default cipher suites string, python: use
#                           Python's preferred selection (default), openssl:
#                           leave OpenSSL's defaults untouched, STRING: use a
#                           custom string, python and STRING also set TLS 1.2 as
#                           minimum TLS version
#   --with-builtin-hashlib-hashes=md5,sha1,sha2,sha3,blake2
#                           builtin hash modules, md5, sha1, sha2, sha3 (with
#                           shake), blake2
#
# Some influential environment variables:
#   PKG_CONFIG  path to pkg-config utility
#   PKG_CONFIG_PATH
#               directories to add to pkg-config's search path
#   PKG_CONFIG_LIBDIR
#               path overriding pkg-config's built-in search path
#   MACHDEP     name for machine-dependent library files
#   CC          C compiler command
#   CFLAGS      C compiler flags
#   LDFLAGS     linker flags, e.g. -L<lib dir> if you have libraries in a
#               nonstandard directory <lib dir>
#   LIBS        libraries to pass to the linker, e.g. -l<library>
#   CPPFLAGS    (Objective) C/C++ preprocessor flags, e.g. -I<include dir> if
#               you have headers in a nonstandard directory <include dir>
#   CPP         C preprocessor
#   HOSTRUNNER  Program to run CPython for the host platform
#   PROFILE_TASK
#               Python args for PGO generation task
#   BOLT_INSTRUMENT_FLAGS
#               Arguments to llvm-bolt when instrumenting binaries
#   BOLT_APPLY_FLAGS
#               Arguments to llvm-bolt when creating a BOLT optimized binary
#   LIBUUID_CFLAGS
#               C compiler flags for LIBUUID, overriding pkg-config
#   LIBUUID_LIBS
#               linker flags for LIBUUID, overriding pkg-config
#   LIBFFI_CFLAGS
#               C compiler flags for LIBFFI, overriding pkg-config
#   LIBFFI_LIBS linker flags for LIBFFI, overriding pkg-config
#   LIBMPDEC_CFLAGS
#               C compiler flags for LIBMPDEC, overriding pkg-config
#   LIBMPDEC_LIBS
#               linker flags for LIBMPDEC, overriding pkg-config
#   LIBSQLITE3_CFLAGS
#               C compiler flags for LIBSQLITE3, overriding pkg-config
#   LIBSQLITE3_LIBS
#               linker flags for LIBSQLITE3, overriding pkg-config
#   TCLTK_CFLAGS
#               C compiler flags for TCLTK, overriding pkg-config
#   TCLTK_LIBS  linker flags for TCLTK, overriding pkg-config
#   X11_CFLAGS  C compiler flags for X11, overriding pkg-config
#   X11_LIBS    linker flags for X11, overriding pkg-config
#   GDBM_CFLAGS C compiler flags for gdbm
#   GDBM_LIBS   additional linker flags for gdbm
#   ZLIB_CFLAGS C compiler flags for ZLIB, overriding pkg-config
#   ZLIB_LIBS   linker flags for ZLIB, overriding pkg-config
#   BZIP2_CFLAGS
#               C compiler flags for BZIP2, overriding pkg-config
#   BZIP2_LIBS  linker flags for BZIP2, overriding pkg-config
#   LIBLZMA_CFLAGS
#               C compiler flags for LIBLZMA, overriding pkg-config
#   LIBLZMA_LIBS
#               linker flags for LIBLZMA, overriding pkg-config
#   LIBREADLINE_CFLAGS
#               C compiler flags for LIBREADLINE, overriding pkg-config
#   LIBREADLINE_LIBS
#               linker flags for LIBREADLINE, overriding pkg-config
#   LIBEDIT_CFLAGS
#               C compiler flags for LIBEDIT, overriding pkg-config
#   LIBEDIT_LIBS
#               linker flags for LIBEDIT, overriding pkg-config
#   CURSES_CFLAGS
#               C compiler flags for CURSES, overriding pkg-config
#   CURSES_LIBS linker flags for CURSES, overriding pkg-config
#   PANEL_CFLAGS
#               C compiler flags for PANEL, overriding pkg-config
#   PANEL_LIBS  linker flags for PANEL, overriding pkg-config
#   LIBB2_CFLAGS
#               C compiler flags for LIBB2, overriding pkg-config
#   LIBB2_LIBS  linker flags for LIBB2, overriding pkg-config

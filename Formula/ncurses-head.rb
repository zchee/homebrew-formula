class NcursesHead < Formula
  desc "Text-based UI library"
  homepage "https://www.gnu.org/software/ncurses/"
  head "https://github.com/ThomasDickey/ncurses-snapshots.git"
  license "MIT"

  depends_on "pkg-config" => :build
  depends_on "pcre2" => :build

  def install
    args = [
      "--prefix=#{prefix}",
      "--enable-pc-files",
      "--with-pkg-config-libdir=#{lib}/pkgconfig",
      "--enable-sigwinch",
      "--enable-symlinks",
      "--enable-widec",
      "--with-shared",
      "--with-gpm=no",
      "--without-ada",
      \
      "--without-tests",
      "--without-develop",
      "--without-debug",
      "--enable-ext-funcs",
      "--enable-colorfgbg",
      "--enable-ext-colors",
      "--enable-ext-mouse",
      "--enable-reentrant",
      "--enable-sp-funcs",
      "--enable-term-driver",
      "--with-pcre2",
      "--with-pthread"
    ]
    args << "--with-terminfo-dirs=#{share}/terminfo:/etc/terminfo:/lib/terminfo:/usr/share/terminfo" if OS.linux?

    ENV["TERMINFO"] = ""
    system "./configure", *args
    system "make", "install"
    make_libncurses_symlinks

    prefix.install "test"
    (prefix/"test").install "install-sh", "config.sub", "config.guess"
  end

  def make_libncurses_symlinks
    major = "6"

    %w[form menu ncurses panel].each do |name|
      on_macos do
        lib.install_symlink "lib#{name}tw.#{major}.dylib" => "lib#{name}.dylib"
        lib.install_symlink "lib#{name}tw.#{major}.dylib" => "lib#{name}.#{major}.dylib"
        lib.install_symlink "lib#{name}tw.#{major}.dylib" => "lib#{name}w.dylib"
        lib.install_symlink "lib#{name}tw.#{major}.dylib" => "lib#{name}w.#{major}.dylib"
      end
      on_linux do
        lib.install_symlink "lib#{name}tw.so.#{major}" => "lib#{name}.so"
        lib.install_symlink "lib#{name}tw.so.#{major}" => "lib#{name}.so.#{major}"
      end
      lib.install_symlink "lib#{name}tw.a" => "lib#{name}.a"
      lib.install_symlink "lib#{name}tw.a" => "lib#{name}w.a"
    end

    # TODO(zchee): make libncurses++*.a C++ static library
    # lib.install_symlink "libncurses++tw.a" => "libncurses++.a"
    # lib.install_symlink "libncurses++tw.a" => "libncurses++w.a"
    lib.install_symlink "libncurses.a" => "libcurses.a"
    lib.install_symlink shared_library("libncurses") => shared_library("libcurses")
    on_linux do
      # libtermcap and libtinfo are provided by ncurses and have the
      # same api. Help some older packages to find these dependencies.
      # https://bugs.centos.org/view.php?id=11423
      # https://bugs.launchpad.net/ubuntu/+source/ncurses/+bug/259139
      lib.install_symlink "libncurses.so" => "libtermcap.so"
      lib.install_symlink "libncurses.so" => "libtinfo.so"
    end

    (lib/"pkgconfig").install_symlink "ncursesw.pc" => "ncurses.pc"
    (lib/"pkgconfig").install_symlink "formw.pc" => "form.pc"
    (lib/"pkgconfig").install_symlink "menuw.pc" => "menu.pc"
    (lib/"pkgconfig").install_symlink "panelw.pc" => "panel.pc"

    bin.install_symlink "ncursestw#{major}-config" => "ncurses#{major}-config"
    bin.install_symlink "ncursestw#{major}-config" => "ncursesw#{major}-config"

    # (include/"ncursesw").install_symlink (bin/versioned_name).realpath => unversioned_name
    include.install_symlink [
      "ncursestw/curses.h", "ncursestw/form.h", "ncursestw/ncurses.h",
      "ncursestw/panel.h", "ncursestw/term.h", "ncursestw/termcap.h"
    ]
    mkdir "#{include}/ncursesw"
    (include/"ncursesw").install_symlink [
      "../ncursestw/curses.h", "../ncursestw/form.h", "../ncursestw/ncurses.h",
      "../ncursestw/panel.h", "../ncursestw/term.h", "../ncursestw/termcap.h"
    ]
  end

  test do
    ENV["TERM"] = "xterm"

    system prefix/"test/configure", "--prefix=#{testpath}/test",
                                    "--with-curses-dir=#{prefix}"
    system "make", "install"

    system testpath/"test/bin/keynames"
    system testpath/"test/bin/test_arrays"
    system testpath/"test/bin/test_vidputs"
  end
end

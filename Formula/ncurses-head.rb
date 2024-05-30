class NcursesHead < Formula
  desc "Text-based UI library"
  homepage "https://invisible-island.net/ncurses/announce.html"
  head "https://github.com/ThomasDickey/ncurses-snapshots.git", branch: "master"
  license "MIT"

  depends_on "libtool" => :build
  depends_on "pcre2" => :build
  depends_on "pkg-config" => :build

  on_linux do
    depends_on "gpatch" => :build
  end

  def install
    # Workaround for
    # macOS: mkdir: /usr/lib/pkgconfig:/opt/homebrew/Library/Homebrew/os/mac/pkgconfig/12: Operation not permitted
    # Linux: configure: error: expected a pathname, not ""
    (lib/"pkgconfig").mkpath

    args = [
      "--prefix=#{prefix}",
      "--enable-pc-files",
      "--with-pkg-config-libdir=#{lib}/pkgconfig",
      "--enable-sigwinch",
      "--enable-symlinks",
      "--enable-widec",
      "--with-shared",
      "--with-cxx-shared",
      "--with-gpm=no",
      "--without-ada",
    ]
    args << "--with-terminfo-dirs=#{share}/terminfo:/etc/terminfo:/lib/terminfo:/usr/share/terminfo" if OS.linux?

    ENV["TERMINFO"] = ""
    system "./configure", *args
    system "make", "install"
    make_libncurses_symlinks

    # Avoid hardcoding Cellar paths in client software.
    inreplace bin/"ncursesw6-config", prefix, opt_prefix
    pkgshare.install "test"
    (pkgshare/"test").install "install-sh", "config.sub", "config.guess"
  end

  def make_libncurses_symlinks
    major = version.major.to_s

    %w[form menu ncurses panel ncurses++].each do |name|
      lib.install_symlink shared_library("lib#{name}w", major) => shared_library("lib#{name}")
      lib.install_symlink shared_library("lib#{name}w", major) => shared_library("lib#{name}", major)
      lib.install_symlink "lib#{name}w.a" => "lib#{name}.a"
      lib.install_symlink "lib#{name}w_g.a" => "lib#{name}_g.a"
    end

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

    bin.install_symlink "ncursesw#{major}-config" => "ncurses#{major}-config"

    include.install_symlink "ncursesw" => "ncurses"
    include.install_symlink [
      "ncursesw/curses.h", "ncursesw/form.h", "ncursesw/ncurses.h",
      "ncursesw/panel.h", "ncursesw/term.h", "ncursesw/termcap.h"
    ]
  end

  test do
    refute_match prefix.to_s, shell_output("#{bin}/ncursesw6-config --prefix")
    refute_match share.to_s, shell_output("#{bin}/ncursesw6-config --terminfo-dirs")

    ENV["TERM"] = "xterm"

    system pkgshare/"test/configure", "--prefix=#{testpath}",
                                      "--with-curses-dir=#{prefix}"
    system "make", "install"
    system testpath/"bin/ncurses-examples"
  end
end

class NinjaHead < Formula
  desc "Small build system for use with gyp or CMake"
  homepage "https://ninja-build.org/"
  license "Apache-2.0"
  head "https://github.com/ninja-build/ninja.git"

  livecheck do
    url "https://github.com/ninja-build/ninja/releases/latest"
    regex(%r{href=.*?/tag/v?(\d+(?:\.\d+)+)["' >]}i)
  end

  bottle :unneeded

  depends_on "python@3.9"

  def install
    py = Formula["python@3.9"].opt_bin/"python3"
    system py, "./configure.py", "--bootstrap", "--verbose", "--with-python=#{py}"

    bin.install "ninja"
    bash_completion.install "misc/bash-completion" => "ninja-completion.sh"
    zsh_completion.install "misc/zsh-completion" => "_ninja"
  end

  test do
    (testpath/"build.ninja").write <<~EOS
      cflags = -Wall

      rule cc
        command = gcc $cflags -c $in -o $out

      build foo.o: cc foo.c
    EOS
    system bin/"ninja", "-t", "targets"
    port = free_port
    fork do
      exec bin/"ninja", "-t", "browse", "--port=#{port}", "--no-browser", "foo.o"
    end
    sleep 2
    assert_match "foo.c", shell_output("curl -s http://localhost:#{port}?foo.o")
  end
end

class BearHead < Formula
  desc "Generate compilation database for clang tooling"
  homepage "https://github.com/rizsotto/Bear"
  head "https://github.com/rizsotto/Bear.git"

  depends_on "cmake" => :build
  # `bear-head` currently depends on Python 3.7
  depends_on "python"

  def install
    args = std_cmake_args + %W[
      -DPYTHON_EXECUTABLE=#{Formula["python"].opt_bin}/python3
    ]
    system "cmake", ".", *args
    inreplace "shell-completion/bash/cmake_install.cmake" do |s|
      s.gsub! %r{file\(INSTALL DESTINATION.*}, ""
    end
    system "make", "install"
    bash_completion.install "shell-completion/bash/bear"
  end

  test do
    system "#{bin}/bear", "true"
    assert_predicate testpath/"compile_commands.json", :exist?
  end
end

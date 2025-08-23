class BatHead < Formula
  desc "Clone of cat(1) with syntax highlighting and Git integration"
  homepage "https://github.com/sharkdp/bat"
  license any_of: ["Apache-2.0", "MIT"]
  head "https://github.com/sharkdp/bat.git", branch: "master"

  depends_on "pkgconf" => :build
  depends_on "libgit2" => :build
  depends_on "oniguruma" => :build
  depends_on "zlib" => :build

  env :std

  def install
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : "apple-latest"
    # setup nightly cargo with rustup
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-cpu=#{target_cpu}"

    ENV["LIBGIT2_NO_VENDOR"] = "1"
    ENV["RUSTONIG_DYNAMIC_LIBONIG"] = "1"
    ENV["RUSTONIG_SYSTEM_LIBONIG"] = "1"

    system "rustup", "run", "nightly", "cargo", "install", "--features", "default", "--root", prefix, "--path", "."

    assets = buildpath.glob("target/release/build/bat-*/out/assets").first
    man1.install assets/"manual/bat.1"
    generate_completions_from_executable(bin/"bat", "--completion")
  end

  test do
    require "utils/linkage"

    pdf = test_fixtures("test.pdf")
    output = shell_output("#{bin}/bat #{pdf} --color=never")
    assert_match "Homebrew test", output

    [
      Formula["libgit2"].opt_lib/shared_library("libgit2"),
      Formula["oniguruma"].opt_lib/shared_library("libonig"),
    ].each do |library|
      assert Utils.binary_linked_to_library?(bin/"bat", library),
             "No linkage with #{library.basename}! Cargo is likely using a vendored version."
    end
  end
end

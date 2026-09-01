class BatHead < Formula
  desc "Clone of cat(1) with syntax highlighting and Git integration"
  homepage "https://github.com/sharkdp/bat"
  license any_of: ["Apache-2.0", "MIT"]
  head "https://github.com/sharkdp/bat.git", branch: "master"

  env :std

  depends_on "pkgconf" => :build
  depends_on "libgit2" => :build
  depends_on "oniguruma" => :build
  depends_on "zlib" => :build

  def install
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    target_cpu = Hardware::CPU.intel? ? "native" : `sysctl -n machdep.cpu.brand_string | awk '{ print tolower($1"-"$2) }'`
    target_feature = Hardware::CPU.intel? ? "" : "+neon"
    rustflags = %W[
      -C target-cpu=#{target_cpu}
      -C target-feature=#{target_feature}
      -C opt-level=3
      -C codegen-units=1
      -C lto=thin
      -C panic=abort
      -C force-frame-pointers=on
      -C embed-bitcode=yes
      -Z dylib-lto
      -Z mir-opt-level=4
      -Z inline-mir=yes
      -C llvm-args=-unroll-threshold=500
      -C llvm-args=-enable-dfa-jump-thread
      -C link-arg=-Wl,-dead_strip
    ]
    ENV["RUSTFLAGS"] = rustflags.join(" ")

    ENV["LIBGIT2_NO_VENDOR"] = "1"
    ENV["RUSTONIG_DYNAMIC_LIBONIG"] = "1"
    ENV["RUSTONIG_SYSTEM_LIBONIG"] = "1"

    features = %w[
      build-assets
      clap
      etcetera
      paging
      regex-onig
      wild
      git
      shell-words
      grep-cli
      minus
      lessopen
    ]
    system "rustup", "run", "nightly", "cargo", "install", *std_cargo_args(features: features)

    assets = buildpath.glob("target/release/build/bat/*/out/assets").first
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

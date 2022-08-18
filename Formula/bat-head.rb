class BatHead < Formula
  desc "Clone of cat(1) with syntax highlighting and Git integration"
  homepage "https://github.com/sharkdp/bat"
  head "https://github.com/sharkdp/bat.git", branch: "master"
  license any_of: ["Apache-2.0", "MIT"]

  depends_on "rust" => :build

  uses_from_macos "zlib"

  def install
    ENV["SHELL_COMPLETIONS_DIR"] = buildpath

    ENV["RUSTC_WRAPPER"] = Formula["sccache"].opt_bin/"sccache"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-feature=+aes,avx,avx2,avx512f,avx512dq,avx512cd,avx512bw,avx512vl -C opt-level=3 -C force-frame-pointers=on -C debug-assertions=off -C incremental=on -C overflow-checks=off"
    system "cargo", "update", "--aggressive"
    system "cargo", "install", "-v", "--all-features", *std_cargo_args

    assets_dir = Dir["target/release/build/bat-*/out/assets"].first
    man1.install "#{assets_dir}/manual/bat.1"
    bash_completion.install "#{assets_dir}/completions/bat.bash" => "bat"
    fish_completion.install "#{assets_dir}/completions/bat.fish"
    zsh_completion.install "#{assets_dir}/completions/bat.zsh" => "_bat"
  end

  test do
    pdf = test_fixtures("test.pdf")
    output = shell_output("#{bin}/bat #{pdf} --color=never")
    assert_match "Homebrew test", output
  end
end

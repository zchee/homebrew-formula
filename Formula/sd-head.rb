class SdHead < Formula
  desc "Intuitive find & replace CLI"
  homepage "https://github.com/chmln/sd"
  head "https://github.com/chmln/sd.git", branch: "master"
  license "MIT"

  depends_on "rust" => :build

  def install
    ENV["RUSTC_WRAPPER"] = Formula["sccache"].opt_bin/"sccache"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-feature=+aes,+avx,+avx2,+avx512f,+avx512dq,+avx512cd,+avx512bw,+avx512vl -C opt-level=3 -C force-frame-pointers=on -C debug-assertions=off -C incremental=on -C overflow-checks=off"
    system "cargo", "install", "-v", *std_cargo_args, "--all-features"

    # Completion scripts and manpage are generated in the crate's build
    # directory, which includes a fingerprint hash. Try to locate it first
    out_dir = Dir["target/release/build/sd-*/out"].first
    man1.install "#{out_dir}/sd.1"
    bash_completion.install "#{out_dir}/sd.bash"
    fish_completion.install "#{out_dir}/sd.fish"
    zsh_completion.install "#{out_dir}/_sd"
  end

  test do
    assert_equal "after", pipe_output("#{bin}/sd before after", "before")
  end
end

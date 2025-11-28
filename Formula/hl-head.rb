class HlHead < Formula
  desc "Fast and powerful log viewer and processor"
  homepage "https://github.com/pamburus/hl"
  license "MIT"
  head "https://github.com/pamburus/hl.git", branch: "master"

  env :std

  depends_on "sccache" => :build

  def install
    # setup nightly cargo with rustup
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : "apple-latest"
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-cpu=#{target_cpu} -C opt-level=3 -C force-frame-pointers=on -C debug-assertions=off -C incremental=on -C overflow-checks=off"

    # setup sccache
    sccache_cache = HOMEBREW_CACHE/"sccache_cache"
    mkdir_p sccache_cache
    ENV["RUSTC_WRAPPER"] = "#{Formula["sccache"].opt_bin}/sccache"
    ENV["SCCACHE_DIR"] = sccache_cache

    system "rustup", "run", "nightly", "cargo", "install", *std_cargo_args

    generate_completions_from_executable(bin/"hl", "--shell-completions", shells: [:zsh, :fish])
    (man1/"hl.1").write Utils.safe_popen_read(bin/"hl", "--man-page")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/hl --version")

    (testpath/"sample.log").write <<~EOS
      time="2025-02-17 12:00:00" level=INFO msg="Starting process"
      time="2025-02-17 12:01:00" level=ERROR msg="An error occurred"
      time="2025-02-17 12:02:00" level=INFO msg="Process completed"
    EOS

    output = shell_output("#{bin}/hl --level ERROR sample.log")
    assert_equal "Feb 17 12:01:00.000 [ERR] An error occurred", output.chomp
  end
end

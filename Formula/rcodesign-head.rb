class RcodesignHead < Formula
  desc "Sign and notarize Apple programs"
  homepage "https://gregoryszorc.com/docs/apple-codesign/main/apple_codesign_rcodesign.html"
  license "MPL-2.0"
  head "https://github.com/indygreg/apple-platform-rs.git", branch: "main"

  env :std

  def install
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : "apple-latest"

    # setup nightly cargo with rustup
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-cpu=#{target_cpu} -C opt-level=3 -C force-frame-pointers=on -C debug-assertions=off -C incremental=on -C overflow-checks=off"

    system "rustup", "run", "nightly", "cargo", "install", "--features", "notarize,smartcard", "--root", prefix, "--bin", "rcodesign", "--path", "apple-codesign"
  end
end

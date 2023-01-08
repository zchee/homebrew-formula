class StyluaHead < Formula
  desc "Opinionated Lua code formatter"
  homepage "https://github.com/JohnnyMorganz/StyLua"
  license "MPL-2.0"
  head "https://github.com/JohnnyMorganz/StyLua.git", branch: "main"

  depends_on "rust" => :build
  depends_on "sccache" => :build

  def install
    ENV["RUSTC_WRAPPER"] = Formula["sccache"].opt_bin/"sccache"
    ENV["RUSTFLAGS"] = "-C target-cpu=x86-64-v4 -C target-feature=+aes,+avx,+avx2,+avx512f,+avx512dq,+avx512cd,+avx512bw,+avx512vl -C opt-level=3 -C force-frame-pointers=on -C debug-assertions=off -C incremental=on -C overflow-checks=off"

    system "cargo", "install", "-v", "--all-features", *std_cargo_args
  end

  test do
    (testpath/"test.lua").write("local  foo  = {'bar'}")
    system bin/"stylua", "test.lua"
    assert_equal "local foo = { \"bar\" }\n", (testpath/"test.lua").read
  end
end

class LuaLanguageServerHead < Formula
  desc "Language Server for the Lua language"
  homepage "https://github.com/LuaLS/lua-language-server"
  license "MIT"
  head "https://github.com/LuaLS/lua-language-server.git", branch: "master"

  no_autobump! because: :requires_manual_review

  depends_on "ninja" => :build

  def install
    ENV.cxx11

    # add `<algorithm>` for `std::copy`
    # upstream PR to bump bee.lua version, https://github.com/LuaLS/lua-language-server/pull/3210
    inreplace buildpath.glob("**/fmt/fmt/color.h") do |s|
      s.gsub!("    const auto& value = arg.value;\n", "")
      s.gsub!("out = std::copy(emphasis.begin(), emphasis.end(), out);", "out = detail::copy<Char>(emphasis.begin(), emphasis.end(), out);")
      s.gsub!("out = std::copy(foreground.begin(), foreground.end(), out);", "out = detail::copy<Char>(foreground.begin(), foreground.end(), out);")
      s.gsub!("out = std::copy(background.begin(), background.end(), out);", "out = detail::copy<Char>(background.begin(), background.end(), out);")
      s.gsub!("out = formatter<T, Char>::format(value, ctx);", "out = formatter<T, Char>::format(arg.value, ctx);")
      s.gsub!("out = std::copy(reset_color.begin(), reset_color.end(), out);", "out = detail::copy<Char>(reset_color.begin(), reset_color.end(), out);")
    end
    # disable all tests by build script (fail in build environment)
    inreplace buildpath.glob("**/3rd/bee.lua/test/test.lua"),
      "os.exit(lt.run(), true)",
      "os.exit(true, true)"

    chdir "3rd/luamake" do
      system "compile/build.sh"
    end
    system "3rd/luamake/luamake", "rebuild"

    (libexec/"bin").install "bin/lua-language-server", "bin/main.lua"
    libexec.install "main.lua", "debugger.lua", "locale", "meta", "script"

    # Make sure `lua-language-server` does not need to write into the Cellar.
    (bin/"lua-language-server").write <<~BASH
      #!/bin/bash
      exec -a lua-language-server #{libexec}/bin/lua-language-server \
        --logpath="${XDG_CACHE_HOME:-${HOME}/.cache}/lua-language-server/log" \
        --metapath="${XDG_CACHE_HOME:-${HOME}/.cache}/lua-language-server/meta" \
        "$@"
    BASH
  end

  test do
    pid = spawn bin/"lua-language-server", "--logpath=."
    sleep 5
    assert_path_exists testpath/"service.log"
    refute_predicate testpath/"service.log", :empty?
  ensure
    Process.kill "TERM", pid
  end
end

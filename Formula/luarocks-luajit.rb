class LuarocksLuajit < Formula
  desc "Package manager for the Lua programming language"
  homepage "https://luarocks.org/"
  license "MIT"
  head "https://github.com/luarocks/luarocks.git", branch: "main"

  livecheck do
    url :homepage
    regex(%r{/luarocks[._-]v?(\d+(?:\.\d+)+)\.t}i)
  end

  depends_on "luajit-openresty"

  uses_from_macos "unzip"

  def install
    # Fix the lua config file missing issue for luarocks-admin build
    ENV.deparallelize

    system "./configure", "--prefix=#{prefix}",
                          "--sysconfdir=#{etc}",
                          "--rocks-tree=#{HOMEBREW_PREFIX}",
                          "--with-lua=#{Formula["luajit-openresty"].opt_prefix}",
                          "--with-lua-bin=#{Formula["luajit-openresty"].opt_bin}",
                          "--lua-version=5.1",
                          "--with-lua-include=#{Formula["luajit-openresty"].opt_include}/luajit-2.1",
                          "--with-lua-lib=#{Formula["luajit-openresty"].opt_lib}"
    system "make", "install"
    generate_completions_from_executable(bin/"luarocks", "completion", base_name: "luarocks-luajit")

    inreplace_files = %w[
      cmd/config
      cmd/which
      core/cfg
      deps
    ].map { |file| share/"lua/5.1/luarocks/#{file}.lua" }
    inreplace inreplace_files, "/usr/local", HOMEBREW_PREFIX

    mv bin/"luarocks", bin/"luarocks-luajit"
    mv bin/"luarocks-admin", bin/"luarocks-admin-luajit"
    mv share/"lua/5.1/luarocks", share/"lua/5.1/luarocks-luajit"

    inreplace Dir.glob("**/*.lua", base: share/"lua/5.1/luarocks-luajit").map do |f|
      f.gsub! 'require("luarocks', 'require("luarocks-luajit'
    end
    inreplace bin/"luarocks-luajit", '"luarocks', '"luarocks-luajit'
  end

  def caveats
    <<~EOS
      LuaRocks supports multiple versions of Lua. By default it is configured
      to use Lua#{Formula["luajit-openresty"].version.major_minor}, but you can require it to use another version at runtime
      with the `--lua-dir` flag, like this:

        luarocks --lua-dir=#{Formula["luajit-openresty"].opt_prefix} install say
    EOS
  end

  test do
    luas = [
      Formula["lua"],
      Formula["luajit"],
    ]

    luas.each do |lua|
      luaversion, luaexec = case lua.name
      when "luajit" then ["5.1", lua.opt_bin/"luajit"]
      else [lua.version.major_minor, lua.opt_bin/"lua-#{lua.version.major_minor}"]
      end

      ENV["LUA_PATH"] = "#{testpath}/share/lua/#{luaversion}/?.lua"
      ENV["LUA_CPATH"] = "#{testpath}/lib/lua/#{luaversion}/?.so"

      system bin/"luarocks", "install",
                                "luafilesystem",
                                "--tree=#{testpath}",
                                "--lua-dir=#{lua.opt_prefix}"

      system luaexec, "-e", "require('lfs')"

      case luaversion
      when "5.1"
        (testpath/"lfs_#{luaversion}test.lua").write <<~LUA
          require("lfs")
          lfs.mkdir("blank_space")
        LUA

        system luaexec, "lfs_#{luaversion}test.lua"
        assert_predicate testpath/"blank_space", :directory?,
          "Luafilesystem failed to create the expected directory"
      else
        (testpath/"lfs_#{luaversion}test.lua").write <<~LUA
          require("lfs")
          print(lfs.currentdir())
        LUA

        assert_match testpath.to_s, shell_output("#{luaexec} lfs_#{luaversion}test.lua")
      end
    end
  end
end

class LuarocksLuajit < Formula
  desc "Package manager for the Lua programming language"
  homepage "https://luarocks.org/"
  url "https://luarocks.org/releases/luarocks-3.7.0.tar.gz"
  sha256 "9255d97fee95cec5b54fc6ac718b11bf5029e45bed7873e053314919cd448551"
  license "MIT"
  head "https://github.com/luarocks/luarocks.git"

  depends_on "openresty/brew/openresty"

  uses_from_macos "unzip"

  def install
    system "./configure", "--prefix=#{prefix}",
                          "--sysconfdir=#{etc}",
                          "--rocks-tree=#{HOMEBREW_PREFIX}",
                          "--with-lua=#{Formula["openresty/brew/openresty"].opt_prefix}/luajit",
                          "--with-lua-bin=#{Formula["openresty/brew/openresty"].opt_prefix}/luajit/bin",
                          "--lua-version=5.1",
                          "--with-lua-include=#{Formula["openresty/brew/openresty"].opt_prefix}/luajit/include/luajit-2.1",
                          "--with-lua-lib=#{Formula["openresty/brew/openresty"].opt_prefix}/luajit/lib"

    system "make", "install"

    mv bin/"luarocks", bin/"luarocks-luajit"
    mv bin/"luarocks-admin", bin/"luarocks-admin-luajit"
    # mv share/"lua/5.1/luarocks", share/"lua/5.1/luarocks-luajit"
  end

  def caveats
    <<~EOS
      LuaRocks supports multiple versions of Lua. By default it is configured
      to use Lua#{Formula["lua"].version.major_minor}, but you can require it to use another version at runtime
      with the `--lua-dir` flag, like this:

        luarocks --lua-dir=#{Formula["lua@5.1"].opt_prefix} install say
    EOS
  end

  test do
    luas = [
      Formula["luajit-openresty"],
    ]

    luas.each do |lua|
      luaversion = lua.version.major_minor
      luaexec = "#{lua.bin}/lua-#{luaversion}"
      ENV["LUA_PATH"] = "#{testpath}/share/lua/#{luaversion}/?.lua"
      ENV["LUA_CPATH"] = "#{testpath}/lib/lua/#{luaversion}/?.so"

      system "#{bin}/luarocks", "install",
                                "luafilesystem",
                                "--tree=#{testpath}",
                                "--lua-dir=#{lua.opt_prefix}"

      system luaexec, "-e", "require('lfs')"

      case luaversion
      when "5.1"
        (testpath/"lfs_#{luaversion}test.lua").write <<~EOS
          require("lfs")
          lfs.mkdir("blank_space")
        EOS

        system luaexec, "lfs_#{luaversion}test.lua"
        assert_predicate testpath/"blank_space", :directory?,
          "Luafilesystem failed to create the expected directory"

        # LuaJIT is compatible with lua5.1, so we can also test it here
        unless Hardware::CPU.arm?
          rmdir testpath/"blank_space"
          system "#{Formula["luajit"].bin}/luajit", "lfs_#{luaversion}test.lua"
          assert_predicate testpath/"blank_space", :directory?,
            "Luafilesystem failed to create the expected directory"
        end
      else
        (testpath/"lfs_#{luaversion}test.lua").write <<~EOS
          require("lfs")
          print(lfs.currentdir())
        EOS

        assert_match testpath.to_s, shell_output("#{luaexec} lfs_#{luaversion}test.lua")
      end
    end
  end
end

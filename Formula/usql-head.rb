class UsqlHead < Formula
  desc "universal command-line SQL client interface"
  homepage "https://github.com/xo/usql"
  head "https://github.com/xo/usql.git", branch: "master"

  option "with-odbc", "Build with ODBC (unixodbc) support"

  depends_on "go" => :build
  depends_on "icu4c" => :build

  def install
    (buildpath/"src/github.com/xo/usql").install buildpath.children

    tags = %W[most sqlite_app_armor sqlite_fts5 sqlite_introspect sqlite_json1 sqlite_math_functions sqlite_stat4 sqlite_userauth sqlite_vtable no_adodb]
    if build.with? "odbc" then
      tags += %w[%w[NO_OPENSSL=1 APPLE_COMMON_CRYPTO=1]]
      depends_on "unixodbc"
    end

    cd "src/github.com/xo/usql" do
      revision = Utils.git_short_head

      system "go", "mod", "tidy", "-v"
      system "go", "build",
        "-trimpath",
        "-tags=#{tags.join(" ")}",
        "-ldflags", "-s -w -X github.com/xo/usql/text.CommandVersion=#{revision}",
        "-o",       bin/"usql"
    end
  end

  test do
    output = shell_output("#{bin}/usql --version")
    assert_match "usql #{self.version}", output
  end
end

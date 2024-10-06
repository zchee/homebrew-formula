$pkg     = "github.com/xo/usql"
$tags    = %w(most sqlite_app_armor sqlite_fts5 sqlite_introspect sqlite_json1 sqlite_math_functions sqlite_stat4 sqlite_userauth sqlite_vtable no_adodb)
class UsqlHead < Formula
  desc "universal command-line SQL client interface"
  homepage "https://#{$pkg}"
  head "https://#{$pkg}.git"

  option "with-odbc", "Build with ODBC (unixodbc) support"

  depends_on "go" => :build
  depends_on "icu4c" => :build

  if build.with? "odbc" then
    $tags   << "odbc"
    depends_on "unixodbc"
  end

  def install
    (buildpath/"src/#{$pkg}").install buildpath.children

    cd "src/#{$pkg}" do
      revision = Utils.git_short_head

      inreplace "go.mod" do |s|
        s.gsub! "	github.com/xo/chartfmt v0.0.0", ""
        s.gsub! "replace github.com/xo/chartfmt => ../chartfmt", ""
      end

      system "go", "mod", "tidy", "-v"
      system "go", "build",
        "-trimpath",
        "-tags",    $tags.join(" "),
        "-ldflags", "-s -w -X #{$pkg}/text.CommandVersion=#{revision}",
        "-o",       bin/"usql"
    end
  end

  test do
    output = shell_output("#{bin}/usql --version")
    assert_match "usql #{self.version}", output
  end
end

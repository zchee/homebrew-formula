class Icmake < Formula
  desc "Icmake: a make alternative"
  homepage "http://icmake.sourceforge.net/"
  url "https://downloads.sourceforge.net/project/icmake/icmake/7.22.01/icmake_7.22.01.orig.tar.gz"
  sha256 "b522e7937e9d4f0bec738dfce371673e3c4a8bc9f4d209a51631e5ed59ba66c7"

  depends_on "gnu-sed"

  patch :DATA

  def install
    inreplace "INSTALL.im" do |s|
      s.gsub! /usr/, prefix
      s.gsub! /etc/, "#{prefix}/etc"
    end

    inreplace "icm_prepare" do |s|
      s.gsub! %r{\. scripts/conversions\n\n}, ""
    end

    inreplace "icm_install" do |s|
      s.gsub! %r{\. scripts/conversions\n\n}, ""
    end

    if `/usr/bin/which gsed`
      opoo "Using gnu-sed"
      inreplace "scripts/convert" do |s|
        s.gsub! /sed/, "gsed"
        s.gsub! %r{\. scripts/conversions\n\n}, ""
      end
    end

    ENV["ROOT"] = ""
    ENV["BINDIR"] = bin
    ENV["SKELDIR"] = "#{share}/icmake"
    ENV["MANDIR"] = "#{man}"
    ENV["LIBDIR"] = "#{lib}/icmake"
    ENV["CONFDIR"] = "#{prefix}/etc"
    ENV["DOCDIR"] = "#{share}/doc/icmake"
    ENV["DOCDOCDIR"] = "#{share}/doc/icmake/icmake-doc"
    ENV["VERSION"] = `cat VERSION | grep VERSION | awk -F '[= ]*'' '{print $2}'`.chomp
    ENV["YEARS"] = `cat VERSION | grep YEARS | awk -v RS="" -F '[= ]*'' '{print $2}'`.chomp

    # lexer.c should be rebuilt, because it was created for a linux system.
    # See also the patch.
    system "/usr/bin/flex", "-o", "comp/lexer.c", "comp/lexer"
    system "./icm_bootstrap", "/"

    system "./icm_install", "all"
  end
end

__END__
diff --git a/comp/iccomp.h b/comp/iccomp.h
index a2a40ec..1e47b47 100644
--- a/comp/iccomp.h
+++ b/comp/iccomp.h
@@ -149,9 +149,11 @@ extern FILE
 extern int
     initialization,                         /* for initialization expr. */
     yy_init,                                /* yylex() initializer: 1 to init. */
-    yyleng,                                 /* strlen(yytext) */
     yynerrs;                                /* number of parse errors so far */
 
+extern size_t
+    yyleng;                                 /* strlen(yytext) */
+
 extern int
     yylineno;                               /* yylex() line counter */


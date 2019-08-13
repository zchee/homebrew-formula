class Yodl < Formula
  desc "Your Own Documentation Language"
  homepage "http://yodl.sourceforge.net/"
  url "https://downloads.sourceforge.net/project/yodl/yodl/3.05.01/yodl_3.05.01.orig.tar.gz"
  sha256 "5a3d0e1b2abbba87217cfdc6cd354a00df8d782572495bbddbdfbd4f47fe0d3e"

  depends_on "ghostscript"
  depends_on "icmake"
  depends_on "gnu-sed"

  patch :DATA

  def install
    inreplace "INSTALL.im", %r{"/usr"}, "\"#{prefix}\""
    inreplace "build", %r{/usr/bin/icmake}, "/usr\/local\/bin\/icmake"

    if `/usr/bin/which gsed`
      opoo "Using gnu-sed"
      inreplace "scripts/configreplacements", "sed", "gsed"
    end

    # To also copy .dSYM directories, use recursive copy.
    inreplace "icmake/install", /run\("cp " \+ g_install \+ BIN/, 'run("cp -R " + g_install + BIN'

    system "./build", "programs"
    system "./build", "macros"
    system "./build", "man"

    system "./build", "install", "programs"
    system "./build", "install", "macros"
    system "./build", "install", "man"
    unless `/usr/bin/which latex`
      system "./build", "manual"
      system "./build", "install", "manual"
    end
    system "./build", "install", "programs"
  end
end

__END__
diff --git a/scripts/yodl2whatever.in b/scripts/yodl2whatever.in
index c9b5b15..9567817 100755
--- a/scripts/yodl2whatever.in
+++ b/scripts/yodl2whatever.in
@@ -97,7 +97,7 @@ if [ "$?" == "4" ] ; then
         -- "$@"`
 else
     # Poor man's getopt. Only single-char flags supported.
-    TEMP=`getopt D:d:ghi:I:kl:m:n:o:p:r:tVvWw  -- "$@"`
+    TEMP=`getopt D:d:ghi:I:kl:m:n:o:p:r:tVvWw "$@"`
 fi
 
 if [ $? != 0 ] ; then echo "getopt error in $base" ; exit 1 ; fi


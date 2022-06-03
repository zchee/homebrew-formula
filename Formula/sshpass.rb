class Sshpass < Formula
  desc "Non-interactive ssh password auth"
  homepage "http://sourceforge.net/projects/sshpass"
  head "https://git.code.sf.net/p/sshpass/code-git.git", branch: "main"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build

  patch :DATA

  def install
    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
    ]

    system "./bootstrap" if build.head?
    system "./configure", *args
    system "make", "install"
  end

  test do
    system "sshpass"
  end
end

__END__
diff --git a/main.c b/main.c
index 3f65352..af7b30b 100644
--- a/main.c
+++ b/main.c
@@ -234,6 +234,23 @@ static int masterpt;
 int childpid;
 int termsig;
 
+void term_child(int signum)
+{
+    fflush(stdout);
+    switch(signum) {
+    case SIGINT:
+        reliable_write(masterpt, "\x03", 1);
+        break;
+    case SIGTSTP:
+        reliable_write(masterpt, "\x1a", 1);
+        break;
+    default:
+        if( childpid>0 ) {
+            kill( childpid, signum );
+        }
+    }
+}
+
 int runprogram( int argc, char *argv[] )
 {
     struct winsize ttysize; // The size of our tty
@@ -580,23 +597,6 @@ void term_handler(int signum)
     termsig = signum;
 }
 
-void term_child(int signum);
-{
-    fflush(stdout);
-    switch(signum) {
-    case SIGINT:
-        reliable_write(masterpt, "\x03", 1);
-        break;
-    case SIGTSTP:
-        reliable_write(masterpt, "\x1a", 1);
-        break;
-    default:
-        if( childpid>0 ) {
-            kill( childpid, signum );
-        }
-    }
-}
-
 void reliable_write( int fd, const void *data, size_t size )
 {
     ssize_t result = write( fd, data, size );

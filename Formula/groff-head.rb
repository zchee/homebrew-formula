class GroffHead < Formula
  desc "GNU troff text-formatting system"
  homepage "https://www.gnu.org/software/groff/"
  head "https://git.savannah.gnu.org/git/groff.git"
  license "GPL-3.0-or-later"

  bottle :unneeded

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "gawk" => :build
  depends_on "ghostscript" => :build
  depends_on "libtool" => :build
  depends_on "netpbm" => :build
  depends_on "pkg-config" => :build
  depends_on "psutils" => :build
  depends_on "texinfo" => :build
  depends_on "uchardet" => :build

  uses_from_macos "bison" => :build
  uses_from_macos "perl"

  on_linux do
    depends_on "glib"
  end

  # See https://savannah.gnu.org/bugs/index.php?59276
  # Fixed in 1.23.0
  patch :DATA

  def install
    system "./bootstrap", "--skip-po"
    system "./configure", "--prefix=#{prefix}", "--without-x", "--with-doc=info", "--with-uchardet", "--with-gs=#{Formula["ghostscript"].bin}/gs", "--with-awk=#{Formula["gawk"].bin}/gawk"
    system "make" # Separate steps required
    system "make", "install"
  end

  test do
    assert_match "homebrew\n",
      pipe_output("#{bin}/groff -a", "homebrew\n")
  end
end

__END__
--- a/src/libs/libgroff/assert.cpp
+++ b/src/libs/libgroff/assert.cpp
@@ -16,6 +16,10 @@ for more details.
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
 #include <stdio.h>
 #include <stdlib.h>
 #include "assert.h"
--- a/src/libs/libgroff/errarg.cpp
+++ b/src/libs/libgroff/errarg.cpp
@@ -17,6 +17,10 @@ for more details.
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
 #include <stdio.h>
 #include "assert.h"
 #include "errarg.h"
--- a/src/libs/libgroff/error.cpp
+++ b/src/libs/libgroff/error.cpp
@@ -17,6 +17,10 @@ for more details.
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
 #include <stdio.h>
 #include <stdlib.h>
 #include <string.h>
--- a/src/libs/libgroff/curtime.cpp
+++ b/src/libs/libgroff/curtime.cpp
@@ -15,6 +15,10 @@
 The GNU General Public License version 2 (GPL2) is available in the
 internet at <http://www.gnu.org/licenses/gpl-2.0.txt>. */

+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
 #include <errno.h>
 #include <limits.h>
 #include <stdlib.h>
--- a/src/libs/libgroff/device.cpp
+++ b/src/libs/libgroff/device.cpp
@@ -17,6 +17,7 @@ for more details.
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

+#include "config.h"
 #include <stdlib.h>
 #include "device.h"
 #include "defs.h"
--- a/src/libs/libgroff/fatal.cpp
+++ b/src/libs/libgroff/fatal.cpp
@@ -16,6 +16,7 @@ for more details.
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

+#include "config.h"
 #include <stdlib.h>

 #define FATAL_ERROR_EXIT_CODE 3
--- a/src/libs/libgroff/string.cpp
+++ b/src/libs/libgroff/string.cpp
@@ -17,6 +17,10 @@ for more details.
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
 #include <stdlib.h>

 #include "lib.h"
--- a/src/libs/libgroff/strsave.cpp
+++ b/src/libs/libgroff/strsave.cpp
@@ -17,6 +17,7 @@ for more details.
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

+#include "config.h"
 #include <string.h>
 #include <stdlib.h>

--- a/src/preproc/eqn/text.cpp
+++ b/src/preproc/eqn/text.cpp
@@ -17,6 +17,7 @@ for more details.
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

+#include "config.h"
 #include <ctype.h>
 #include <stdlib.h>
 #include "eqn.h"
--- a/src/preproc/eqn/other.cpp
+++ b/src/preproc/eqn/other.cpp
@@ -17,6 +17,7 @@ for more details.
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

+#include "config.h"
 #include <stdlib.h>

 #include "eqn.h"
--- a/src/preproc/pic/object.cpp
+++ b/src/preproc/pic/object.cpp
@@ -17,6 +17,8 @@ for more details.
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

+#include "config.h"
+
 #include <stdlib.h>

 #include "pic.h"
{"mode":"full","isActive":false}

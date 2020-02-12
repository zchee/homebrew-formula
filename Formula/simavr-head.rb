class SimavrHead < Formula
  desc "Lean, mean and hackable AVR simulator for Linux & macOS"
  homepage "https://github.com/buserror/simavr"
  head "https://github.com/buserror/simavr.git"

  depends_on "avr-gcc"
  depends_on "libelf"

  patch :DATA

  def install
    ENV.deparallelize
    system "make", "all", "HOMEBREW_PREFIX=#{HOMEBREW_PREFIX}", "RELEASE=1"
    system "make", "install", "DESTDIR=#{prefix}", "HOMEBREW_PREFIX=#{HOMEBREW_PREFIX}", "RELEASE=1"
    prefix.install "examples"
  end

  test do
    system "true"
  end
end

__END__
diff --git a/Makefile.common b/Makefile.common
index 60df96a..cf93ed4 100644
--- a/Makefile.common
+++ b/Makefile.common
@@ -50,19 +50,6 @@ ifeq (${shell uname}, Darwin)
  CC			= clang
  AVR_ROOT 	:= "/Applications/Arduino.app/Contents/Java/hardware/tools/avr/"
  AVR 		:= ${AVR_ROOT}/bin/avr-
- # Thats for MacPorts libelf
- ifeq (${shell test -d /opt/local && echo Exists}, Exists)
-  ifneq (${shell test -d /opt/local/avr && echo Exists}, Exists)
-   $(error Please install avr-gcc: port install avr-gcc avr-libc)
-  endif
-  ifneq (${shell test -d /opt/local/include/libelf && echo Exists}, Exists)
-   $(error Please install libelf: port install libelf)
-  endif
-  CC		= clang
-  IPATH		+= /opt/local/include /opt/local/include/libelf
-  LFLAGS	= -L/opt/local/lib/
-  AVR 		:= /opt/local/bin/avr-
- else
   # That's for Homebrew libelf and avr-gcc support
   HOMEBREW_PREFIX ?= /usr/local
   ifeq (${shell test -d $(HOMEBREW_PREFIX)/Cellar && echo Exists}, Exists)
@@ -79,7 +66,6 @@ ifeq (${shell uname}, Darwin)
    AVR_ROOT		:= $(firstword $(wildcard $(HOMEBREW_PREFIX)/Cellar/avr-libc/*/))
    AVR			:= $(HOMEBREW_PREFIX)/bin/avr-
   endif
- endif
 else
  AVR 		:= avr-
 endif

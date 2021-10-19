class QemuVirtio9p < Formula
  desc "Emulator for x86 and PowerPC with virtio-9p support for darwin/amd64"
  homepage "https://www.qemu.org/"
  url "https://download.qemu.org/qemu-6.1.0.tar.xz"
  sha256 "eebc089db3414bbeedf1e464beda0a7515aad30f73261abc246c9b27503a3c96"
  license "GPL-2.0-only"

  depends_on "libtool" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build

  depends_on "glib"
  depends_on "gnutls"
  depends_on "jpeg"
  depends_on "libpng"
  depends_on "libslirp"
  depends_on "libssh"
  depends_on "libusb"
  depends_on "lzo"
  depends_on "ncurses"
  depends_on "nettle"
  depends_on "pixman"
  depends_on "snappy"
  depends_on "vde"

  conflicts_with "qemu", because: "qemu also ships a qemu binary, but without virtio-9p support"

  fails_with gcc: "5"

  # 820KB floppy disk image file of FreeDOS 1.2, used to test QEMU
  resource "test-image" do
    url "https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.2/FD12FLOPPY.zip"
    sha256 "81237c7b42dc0ffc8b32a2f5734e3480a3f9a470c50c14a9c4576a2561a35807"
  end

  if Hardware::CPU.arm?
    patch do
      url "https://patchwork.kernel.org/series/548227/mbox/"
      sha256 "5b9c9779374839ce6ade1b60d1377c3fc118bc43e8482d0d3efa64383e11b6d3"
    end
    # allwinner-h3: Switch to SMC as PSCI conduit
    patch do
      url "https://patchwork.kernel.org/series/550031/mbox/"
      sha256 "793b6676902c5c64501730bce8a839ef26b9d6b8cf9b4fa8032bdcc1d26de565"
    end
  end
  # hvf: Determine slot count from struct layout
  patch do
    url "https://patchwork.kernel.org/series/559687/mbox/"
    sha256 "d9d732ec009325dfb23a0160984a385fdbf77e34ca66d04c855f21362a4cfbd2"
  end

  patch :DATA

  def install
    ENV["LIBTOOL"] = "glibtool"
    ENV.append "CFLAGS", "-arch x86_64 -m64 -march=native -mavx -mavx2 -mavx512ifma -mavx512bw -mavx512cd -mavx512dq -mavx512f -mavx512vl"
    ENV.append "CXXFLAGS", "-arch x86_64 -m64 -march=native -mavx -mavx2 -mavx512ifma -mavx512bw -mavx512cd -mavx512dq -mavx512f -mavx512vl"
    ENV.append "LDFLAGS", "-arch x86_64 -m64"

    args = %W[
      --prefix=#{prefix}
      --cc=#{ENV.cc}
      --host-cc=#{ENV.cc}
      --enable-hvf
      --enable-virtfs
      --disable-bsd-user
      --disable-guest-agent
      --enable-curses
      --enable-libssh
      --enable-slirp=system
      --enable-vde
      --extra-cflags=-DNCURSES_WIDECHAR=1
      --disable-sdl
      --disable-gtk
      --enable-avx2
      --enable-avx512f
      --enable-tools
    ]
    # Sharing Samba directories in QEMU requires the samba.org smbd which is
    # incompatible with the macOS-provided version. This will lead to
    # silent runtime failures, so we set it to a Homebrew path in order to
    # obtain sensible runtime errors. This will also be compatible with
    # Samba installations from external taps.
    args << "--smbd=#{HOMEBREW_PREFIX}/sbin/samba-dot-org-smbd"

    args << "--enable-cocoa" if OS.mac?

    system "./configure", *args
    system "make", "V=1", "install"
  end

  test do
    expected = build.stable? ? version.to_s : "QEMU Project"
    assert_match expected, shell_output("#{bin}/qemu-system-aarch64 --version")
    assert_match expected, shell_output("#{bin}/qemu-system-alpha --version")
    assert_match expected, shell_output("#{bin}/qemu-system-arm --version")
    assert_match expected, shell_output("#{bin}/qemu-system-cris --version")
    assert_match expected, shell_output("#{bin}/qemu-system-hppa --version")
    assert_match expected, shell_output("#{bin}/qemu-system-i386 --version")
    assert_match expected, shell_output("#{bin}/qemu-system-m68k --version")
    assert_match expected, shell_output("#{bin}/qemu-system-microblaze --version")
    assert_match expected, shell_output("#{bin}/qemu-system-microblazeel --version")
    assert_match expected, shell_output("#{bin}/qemu-system-mips --version")
    assert_match expected, shell_output("#{bin}/qemu-system-mips64 --version")
    assert_match expected, shell_output("#{bin}/qemu-system-mips64el --version")
    assert_match expected, shell_output("#{bin}/qemu-system-mipsel --version")
    assert_match expected, shell_output("#{bin}/qemu-system-nios2 --version")
    assert_match expected, shell_output("#{bin}/qemu-system-or1k --version")
    assert_match expected, shell_output("#{bin}/qemu-system-ppc --version")
    assert_match expected, shell_output("#{bin}/qemu-system-ppc64 --version")
    assert_match expected, shell_output("#{bin}/qemu-system-riscv32 --version")
    assert_match expected, shell_output("#{bin}/qemu-system-riscv64 --version")
    assert_match expected, shell_output("#{bin}/qemu-system-rx --version")
    assert_match expected, shell_output("#{bin}/qemu-system-s390x --version")
    assert_match expected, shell_output("#{bin}/qemu-system-sh4 --version")
    assert_match expected, shell_output("#{bin}/qemu-system-sh4eb --version")
    assert_match expected, shell_output("#{bin}/qemu-system-sparc --version")
    assert_match expected, shell_output("#{bin}/qemu-system-sparc64 --version")
    assert_match expected, shell_output("#{bin}/qemu-system-tricore --version")
    assert_match expected, shell_output("#{bin}/qemu-system-x86_64 --version")
    assert_match expected, shell_output("#{bin}/qemu-system-xtensa --version")
    assert_match expected, shell_output("#{bin}/qemu-system-xtensaeb --version")
    resource("test-image").stage testpath
    assert_match "file format: raw", shell_output("#{bin}/qemu-img info FLOPPY.img")
  end
end

__END__
diff --git a/fsdev/file-op-9p.h b/fsdev/file-op-9p.h
index 42f677cf38..d9d058b756 100644
--- a/fsdev/file-op-9p.h
+++ b/fsdev/file-op-9p.h
@@ -16,7 +16,7 @@
 
 #include <dirent.h>
 #include <utime.h>
-#include <sys/vfs.h>
+#include "qemu/statfs.h"
 #include "qemu-fsdev-throttle.h"
 
 #define SM_LOCAL_MODE_BITS    0600
diff --git a/fsdev/meson.build b/fsdev/meson.build
index adf57cc43e..b632b66348 100644
--- a/fsdev/meson.build
+++ b/fsdev/meson.build
@@ -7,6 +7,7 @@ fsdev_ss.add(when: ['CONFIG_FSDEV_9P'], if_true: files(
   'qemu-fsdev.c',
 ), if_false: files('qemu-fsdev-dummy.c'))
 softmmu_ss.add_all(when: 'CONFIG_LINUX', if_true: fsdev_ss)
+softmmu_ss.add_all(when: 'CONFIG_DARWIN', if_true: fsdev_ss)
 
 if have_virtfs_proxy_helper
   executable('virtfs-proxy-helper',
diff --git a/fsdev/virtfs-proxy-helper.c b/fsdev/virtfs-proxy-helper.c
index 15c0e79b06..ccef551cf8 100644
--- a/fsdev/virtfs-proxy-helper.c
+++ b/fsdev/virtfs-proxy-helper.c
@@ -13,14 +13,19 @@
 #include <sys/resource.h>
 #include <getopt.h>
 #include <syslog.h>
+#include <sys/ioctl.h>
+#ifdef CONFIG_DARWIN
+#include <unistd.h>
+#include <sys/xattr.h>
+#else
 #include <sys/fsuid.h>
 #include <sys/vfs.h>
-#include <sys/ioctl.h>
 #include <linux/fs.h>
+#include <cap-ng.h>
+#endif
 #ifdef CONFIG_LINUX_MAGIC_H
 #include <linux/magic.h>
 #endif
-#include <cap-ng.h>
 #include "qemu-common.h"
 #include "qemu/sockets.h"
 #include "qemu/xattr.h"
@@ -81,6 +86,7 @@ static void do_perror(const char *string)
 
 static int init_capabilities(void)
 {
+#ifndef CONFIG_DARWIN
     /* helper needs following capabilities only */
     int cap_list[] = {
         CAP_CHOWN,
@@ -118,6 +124,8 @@ static int init_capabilities(void)
             return -1;
         }
     }
+#endif
+
     return 0;
 }
 
@@ -263,6 +271,71 @@ static int send_status(int sockfd, struct iovec *iovec, int status)
     return 0;
 }
 
+#ifdef CONFIG_DARWIN
+/*
+ * from man 7 capabilities, section
+ * Effect of User ID Changes on Capabilities:
+ * If the effective user ID is changed from nonzero to 0, then the permitted
+ * set is copied to the effective set.  If the effective user ID is changed
+ * from 0 to nonzero, then all capabilities are are cleared from the effective
+ * set.
+ *
+ * The setfsuid/setfsgid man pages warn that changing the effective user ID may
+ * expose the program to unwanted signals, but this is not true anymore: for an
+ * unprivileged (without CAP_KILL) program to send a signal, the real or
+ * effective user ID of the sending process must equal the real or saved user
+ * ID of the target process.  Even when dropping privileges, it is enough to
+ * keep the saved UID to a "privileged" value and virtfs-proxy-helper won't
+ * be exposed to signals.  So just use setresuid/setresgid.
+ */
+static int setugid(int uid, int gid, int *suid, int *sgid)
+{
+    int retval;
+
+    *suid = geteuid();
+    *sgid = getegid();
+
+    if (setregid(-1, gid) == -1) {
+        return -errno;
+    }
+
+    if (setreuid(-1, uid) == -1) {
+        retval = -errno;
+        goto err_sgid;
+    }
+
+    if (uid == 0 && gid == 0) {
+        /* Linux has already copied the permitted set to the effective set.  */
+        return 0;
+    }
+
+    return 0;
+
+err_suid:
+    if (setreuid(-1, *suid) == -1) {
+        abort();
+    }
+err_sgid:
+    if (setregid(-1, *sgid) == -1) {
+        abort();
+    }
+    return retval;
+}
+
+/*
+ * This is used to reset the ugid back with the saved values
+ * There is nothing much we can do checking error values here.
+ */
+static void resetugid(int suid, int sgid)
+{
+    if (setregid(-1, sgid) == -1) {
+        abort();
+    }
+    if (setreuid(-1, suid) == -1) {
+        abort();
+    }
+}
+#else
 /*
  * from man 7 capabilities, section
  * Effect of User ID Changes on Capabilities:
@@ -337,6 +410,7 @@ static void resetugid(int suid, int sgid)
         abort();
     }
 }
+#endif
 
 /*
  * send response in two parts
@@ -445,7 +519,11 @@ static int do_getxattr(int type, struct iovec *iovec, struct iovec *out_iovec)
         v9fs_string_init(&name);
         retval = proxy_unmarshal(iovec, offset, "s", &name);
         if (retval > 0) {
+#ifdef CONFIG_DARWIN
+            retval = getxattr(path.data, name.data, xattr.data, size, 0, XATTR_NOFOLLOW);
+#else
             retval = lgetxattr(path.data, name.data, xattr.data, size);
+#endif
             if (retval < 0) {
                 retval = -errno;
             } else {
@@ -455,7 +533,11 @@ static int do_getxattr(int type, struct iovec *iovec, struct iovec *out_iovec)
         v9fs_string_free(&name);
         break;
     case T_LLISTXATTR:
+#ifdef CONFIG_DARWIN
+        retval = listxattr(path.data, xattr.data, size, XATTR_NOFOLLOW);
+#else
         retval = llistxattr(path.data, xattr.data, size);
+#endif
         if (retval < 0) {
             retval = -errno;
         } else {
@@ -492,14 +574,24 @@ static void stat_to_prstat(ProxyStat *pr_stat, struct stat *stat)
     pr_stat->st_size = stat->st_size;
     pr_stat->st_blksize = stat->st_blksize;
     pr_stat->st_blocks = stat->st_blocks;
+#ifdef CONFIG_DARWIN
+    pr_stat->st_atim_sec = stat->st_atimespec.tv_sec;
+    pr_stat->st_atim_nsec = stat->st_atimespec.tv_nsec;
+    pr_stat->st_mtim_sec = stat->st_mtimespec.tv_sec;
+    pr_stat->st_mtim_nsec = stat->st_mtimespec.tv_nsec;
+    pr_stat->st_ctim_sec = stat->st_ctimespec.tv_sec;
+    pr_stat->st_ctim_nsec = stat->st_ctimespec.tv_nsec;
+#else
     pr_stat->st_atim_sec = stat->st_atim.tv_sec;
     pr_stat->st_atim_nsec = stat->st_atim.tv_nsec;
     pr_stat->st_mtim_sec = stat->st_mtim.tv_sec;
     pr_stat->st_mtim_nsec = stat->st_mtim.tv_nsec;
     pr_stat->st_ctim_sec = stat->st_ctim.tv_sec;
     pr_stat->st_ctim_nsec = stat->st_ctim.tv_nsec;
+#endif
 }
 
+#ifndef CONFIG_DARWIN
 static void statfs_to_prstatfs(ProxyStatFS *pr_stfs, struct statfs *stfs)
 {
     memset(pr_stfs, 0, sizeof(*pr_stfs));
@@ -515,6 +607,7 @@ static void statfs_to_prstatfs(ProxyStatFS *pr_stfs, struct statfs *stfs)
     pr_stfs->f_namelen = stfs->f_namelen;
     pr_stfs->f_frsize = stfs->f_frsize;
 }
+#endif
 
 /*
  * Gets stat/statfs information and packs in out_iovec structure
@@ -526,9 +619,11 @@ static int do_stat(int type, struct iovec *iovec, struct iovec *out_iovec)
     int retval;
     V9fsString path;
     ProxyStat pr_stat;
-    ProxyStatFS pr_stfs;
     struct stat st_buf;
+#ifndef CONFIG_DARWIN
+    ProxyStatFS pr_stfs;
     struct statfs stfs_buf;
+#endif
 
     v9fs_string_init(&path);
     retval = proxy_unmarshal(iovec, PROXY_HDR_SZ, "s", &path);
@@ -556,6 +651,9 @@ static int do_stat(int type, struct iovec *iovec, struct iovec *out_iovec)
         }
         break;
     case T_STATFS:
+#ifdef CONFIG_DARWIN
+        retval = -errno;
+#else
         retval = statfs(path.data, &stfs_buf);
         if (retval < 0) {
             retval = -errno;
@@ -569,6 +667,7 @@ static int do_stat(int type, struct iovec *iovec, struct iovec *out_iovec)
                                    pr_stfs.f_fsid[0], pr_stfs.f_fsid[1],
                                    pr_stfs.f_namelen, pr_stfs.f_frsize);
         }
+#endif
         break;
     }
     v9fs_string_free(&path);
@@ -978,8 +1077,13 @@ static int process_requests(int sock)
             retval = proxy_unmarshal(&in_iovec, PROXY_HDR_SZ, "sssdd", &path,
                                      &name, &value, &size, &flags);
             if (retval > 0) {
+#ifdef CONFIG_DARWIN
+                retval = setxattr(path.data,
+                                  name.data, value.data, size, 0, flags | XATTR_NOFOLLOW);
+#else
                 retval = lsetxattr(path.data,
                                    name.data, value.data, size, flags);
+#endif
                 if (retval < 0) {
                     retval = -errno;
                 }
@@ -994,7 +1098,11 @@ static int process_requests(int sock)
             retval = proxy_unmarshal(&in_iovec,
                                      PROXY_HDR_SZ, "ss", &path, &name);
             if (retval > 0) {
+#ifdef CONFIG_DARWIN
+                retval = removexattr(path.data, name.data, XATTR_NOFOLLOW);
+#else
                 retval = lremovexattr(path.data, name.data);
+#endif
                 if (retval < 0) {
                     retval = -errno;
                 }
diff --git a/hw/9pfs/9p-local.c b/hw/9pfs/9p-local.c
index 210d9e7705..42b65e143b 100644
--- a/hw/9pfs/9p-local.c
+++ b/hw/9pfs/9p-local.c
@@ -32,10 +32,12 @@
 #include "qemu/error-report.h"
 #include "qemu/option.h"
 #include <libgen.h>
+#ifdef CONFIG_LINUX
 #include <linux/fs.h>
 #ifdef CONFIG_LINUX_MAGIC_H
 #include <linux/magic.h>
 #endif
+#endif
 #include <sys/ioctl.h>
 
 #ifndef XFS_SUPER_MAGIC
@@ -671,7 +673,7 @@ static int local_mknod(FsContext *fs_ctx, V9fsPath *dir_path,
 
     if (fs_ctx->export_flags & V9FS_SM_MAPPED ||
         fs_ctx->export_flags & V9FS_SM_MAPPED_FILE) {
-        err = mknodat(dirfd, name, fs_ctx->fmode | S_IFREG, 0);
+        err = qemu_mknodat(dirfd, name, fs_ctx->fmode | S_IFREG, 0);
         if (err == -1) {
             goto out;
         }
@@ -686,7 +688,7 @@ static int local_mknod(FsContext *fs_ctx, V9fsPath *dir_path,
         }
     } else if (fs_ctx->export_flags & V9FS_SM_PASSTHROUGH ||
                fs_ctx->export_flags & V9FS_SM_NONE) {
-        err = mknodat(dirfd, name, credp->fc_mode, credp->fc_rdev);
+        err = qemu_mknodat(dirfd, name, credp->fc_mode, credp->fc_rdev);
         if (err == -1) {
             goto out;
         }
@@ -699,6 +701,7 @@ static int local_mknod(FsContext *fs_ctx, V9fsPath *dir_path,
 
 err_end:
     unlinkat_preserve_errno(dirfd, name, 0);
+
 out:
     close_preserve_errno(dirfd);
     return err;
@@ -779,16 +782,20 @@ static int local_fstat(FsContext *fs_ctx, int fid_type,
         mode_t tmp_mode;
         dev_t tmp_dev;
 
-        if (fgetxattr(fd, "user.virtfs.uid", &tmp_uid, sizeof(uid_t)) > 0) {
+        if (qemu_fgetxattr(fd, "user.virtfs.uid",
+                           &tmp_uid, sizeof(uid_t)) > 0) {
             stbuf->st_uid = le32_to_cpu(tmp_uid);
         }
-        if (fgetxattr(fd, "user.virtfs.gid", &tmp_gid, sizeof(gid_t)) > 0) {
+        if (qemu_fgetxattr(fd, "user.virtfs.gid",
+                           &tmp_gid, sizeof(gid_t)) > 0) {
             stbuf->st_gid = le32_to_cpu(tmp_gid);
         }
-        if (fgetxattr(fd, "user.virtfs.mode", &tmp_mode, sizeof(mode_t)) > 0) {
+        if (qemu_fgetxattr(fd, "user.virtfs.mode",
+                           &tmp_mode, sizeof(mode_t)) > 0) {
             stbuf->st_mode = le32_to_cpu(tmp_mode);
         }
-        if (fgetxattr(fd, "user.virtfs.rdev", &tmp_dev, sizeof(dev_t)) > 0) {
+        if (qemu_fgetxattr(fd, "user.virtfs.rdev",
+                           &tmp_dev, sizeof(dev_t)) > 0) {
             stbuf->st_rdev = le64_to_cpu(tmp_dev);
         }
     } else if (fs_ctx->export_flags & V9FS_SM_MAPPED_FILE) {
@@ -1070,7 +1077,7 @@ static int local_utimensat(FsContext *s, V9fsPath *fs_path,
         goto out;
     }
 
-    ret = utimensat(dirfd, name, buf, AT_SYMLINK_NOFOLLOW);
+    ret = utimensat_nofollow(dirfd, name, buf);
     close_preserve_errno(dirfd);
 out:
     g_free(dirpath);
diff --git a/hw/9pfs/9p-proxy.c b/hw/9pfs/9p-proxy.c
index 09bd9f1464..be1546c1be 100644
--- a/hw/9pfs/9p-proxy.c
+++ b/hw/9pfs/9p-proxy.c
@@ -123,10 +123,15 @@ static void prstatfs_to_statfs(struct statfs *stfs, ProxyStatFS *prstfs)
     stfs->f_bavail = prstfs->f_bavail;
     stfs->f_files = prstfs->f_files;
     stfs->f_ffree = prstfs->f_ffree;
+#ifdef CONFIG_DARWIN
+    stfs->f_fsid.val[0] = prstfs->f_fsid[0] & 0xFFFFFFFFU;
+    stfs->f_fsid.val[1] = prstfs->f_fsid[1] >> 32 & 0xFFFFFFFFU;
+#else
     stfs->f_fsid.__val[0] = prstfs->f_fsid[0] & 0xFFFFFFFFU;
     stfs->f_fsid.__val[1] = prstfs->f_fsid[1] >> 32 & 0xFFFFFFFFU;
     stfs->f_namelen = prstfs->f_namelen;
     stfs->f_frsize = prstfs->f_frsize;
+#endif
 }
 
 /* Converts proxy_stat structure to VFS stat structure */
@@ -143,12 +148,18 @@ static void prstat_to_stat(struct stat *stbuf, ProxyStat *prstat)
    stbuf->st_size = prstat->st_size;
    stbuf->st_blksize = prstat->st_blksize;
    stbuf->st_blocks = prstat->st_blocks;
-   stbuf->st_atim.tv_sec = prstat->st_atim_sec;
-   stbuf->st_atim.tv_nsec = prstat->st_atim_nsec;
+   stbuf->st_atime = prstat->st_atim_sec;
    stbuf->st_mtime = prstat->st_mtim_sec;
-   stbuf->st_mtim.tv_nsec = prstat->st_mtim_nsec;
    stbuf->st_ctime = prstat->st_ctim_sec;
+#ifdef CONFIG_DARWIN
+   stbuf->st_atimespec.tv_nsec = prstat->st_atim_nsec;
+   stbuf->st_mtimespec.tv_nsec = prstat->st_mtim_nsec;
+   stbuf->st_ctimespec.tv_nsec = prstat->st_ctim_nsec;
+#else
+   stbuf->st_atim.tv_nsec = prstat->st_atim_nsec;
+   stbuf->st_mtim.tv_nsec = prstat->st_mtim_nsec;
    stbuf->st_ctim.tv_nsec = prstat->st_ctim_nsec;
+#endif
 }
 
 /*
diff --git a/hw/9pfs/9p-synth.c b/hw/9pfs/9p-synth.c
index b38088e066..09b9c25288 100644
--- a/hw/9pfs/9p-synth.c
+++ b/hw/9pfs/9p-synth.c
@@ -222,7 +222,9 @@ static void synth_direntry(V9fsSynthNode *node,
 {
     strcpy(entry->d_name, node->name);
     entry->d_ino = node->attr->inode;
+#ifndef CONFIG_DARWIN
     entry->d_off = off + 1;
+#endif
 }
 
 static struct dirent *synth_get_dentry(V9fsSynthNode *dir,
@@ -427,7 +429,9 @@ static int synth_statfs(FsContext *s, V9fsPath *fs_path,
     stbuf->f_bsize = 512;
     stbuf->f_blocks = 0;
     stbuf->f_files = synth_node_count;
+#ifndef CONFIG_DARWIN
     stbuf->f_namelen = NAME_MAX;
+#endif
     return 0;
 }
 
diff --git a/hw/9pfs/9p-util-darwin.c b/hw/9pfs/9p-util-darwin.c
new file mode 100644
index 0000000000..194f068f00
--- /dev/null
+++ b/hw/9pfs/9p-util-darwin.c
@@ -0,0 +1,191 @@
+/*
+ * 9p utilities (Darwin Implementation)
+ *
+ * This work is licensed under the terms of the GNU GPL, version 2 or later.
+ * See the COPYING file in the top-level directory.
+ */
+
+#include "qemu/osdep.h"
+#include "qemu/xattr.h"
+#include "9p-util.h"
+
+ssize_t fgetxattrat_nofollow(int dirfd, const char *filename, const char *name,
+                             void *value, size_t size)
+{
+    int ret;
+    int fd = openat_file(dirfd, filename,
+                         O_RDONLY | O_PATH_9P_UTIL | O_NOFOLLOW, 0);
+    if (fd == -1) {
+        return -1;
+    }
+    ret = fgetxattr(fd, name, value, size, 0, 0);
+    close_preserve_errno(fd);
+    return ret;
+}
+
+ssize_t flistxattrat_nofollow(int dirfd, const char *filename,
+                              char *list, size_t size)
+{
+    int ret;
+    int fd = openat_file(dirfd, filename,
+                         O_RDONLY | O_PATH_9P_UTIL | O_NOFOLLOW, 0);
+    if (fd == -1) {
+        return -1;
+    }
+    ret = flistxattr(fd, list, size, 0);
+    close_preserve_errno(fd);
+    return ret;
+}
+
+ssize_t fremovexattrat_nofollow(int dirfd, const char *filename,
+                                const char *name)
+{
+    int ret;
+    int fd = openat_file(dirfd, filename, O_PATH_9P_UTIL | O_NOFOLLOW, 0);
+    if (fd == -1) {
+        return -1;
+    }
+    ret = fremovexattr(fd, name, 0);
+    close_preserve_errno(fd);
+    return ret;
+}
+
+int fsetxattrat_nofollow(int dirfd, const char *filename, const char *name,
+                         void *value, size_t size, int flags)
+{
+    int ret;
+    int fd = openat_file(dirfd, filename, O_PATH_9P_UTIL | O_NOFOLLOW, 0);
+    if (fd == -1) {
+        return -1;
+    }
+    ret = fsetxattr(fd, name, value, size, 0, flags);
+    close_preserve_errno(fd);
+    return ret;
+}
+
+#ifndef __has_builtin
+#define __has_builtin(x) 0
+#endif
+
+static int update_times_from_stat(int fd, struct timespec times[2],
+                                  int update0, int update1)
+{
+    struct stat buf;
+    int ret = fstat(fd, &buf);
+    if (ret == -1) {
+        return ret;
+    }
+    if (update0) {
+        times[0] = buf.st_atimespec;
+    }
+    if (update1) {
+        times[1] = buf.st_mtimespec;
+    }
+    return 0;
+}
+
+int utimensat_nofollow(int dirfd, const char *filename,
+                       const struct timespec times_in[2])
+{
+    int ret, fd;
+    int special0, special1;
+    struct timeval futimes_buf[2];
+    struct timespec times[2];
+    memcpy(times, times_in, 2 * sizeof(struct timespec));
+
+/* Check whether we have an SDK version that defines utimensat */
+#if defined(__MAC_10_13)
+# if __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_13
+#  define UTIMENSAT_AVAILABLE 1
+# elif __has_builtin(__builtin_available)
+#  define UTIMENSAT_AVAILABLE __builtin_available(macos 10.13, *)
+# else
+#  define UTIMENSAT_AVAILABLE 0
+# endif
+    if (UTIMENSAT_AVAILABLE) {
+        return utimensat(dirfd, filename, times, AT_SYMLINK_NOFOLLOW);
+    }
+#endif
+
+    /* utimensat not available. Use futimes. */
+    fd = openat_file(dirfd, filename, O_PATH_9P_UTIL | O_NOFOLLOW, 0);
+    if (fd == -1) {
+        return -1;
+    }
+
+    special0 = times[0].tv_nsec == UTIME_OMIT;
+    special1 = times[1].tv_nsec == UTIME_OMIT;
+    if (special0 || special1) {
+        /* If both are set, nothing to do */
+        if (special0 && special1) {
+            ret = 0;
+            goto done;
+        }
+
+        ret = update_times_from_stat(fd, times, special0, special1);
+        if (ret < 0) {
+            goto done;
+        }
+    }
+
+    special0 = times[0].tv_nsec == UTIME_NOW;
+    special1 = times[1].tv_nsec == UTIME_NOW;
+    if (special0 || special1) {
+        ret = futimes(fd, NULL);
+        if (ret < 0) {
+            goto done;
+        }
+
+        /* If both are set, we are done */
+        if (special0 && special1) {
+            ret = 0;
+            goto done;
+        }
+
+        ret = update_times_from_stat(fd, times, special0, special1);
+        if (ret < 0) {
+            goto done;
+        }
+    }
+
+    futimes_buf[0].tv_sec = times[0].tv_sec;
+    futimes_buf[0].tv_usec = times[0].tv_nsec / 1000;
+    futimes_buf[1].tv_sec = times[1].tv_sec;
+    futimes_buf[1].tv_usec = times[1].tv_nsec / 1000;
+    ret = futimes(fd, futimes_buf);
+
+done:
+    close_preserve_errno(fd);
+    return ret;
+}
+
+#ifndef SYS___pthread_fchdir
+# define SYS___pthread_fchdir 349
+#endif
+
+// This is an undocumented OS X syscall. It would be best to avoid it,
+// but there doesn't seem to be another safe way to implement mknodat.
+// Dear Apple, please implement mknodat before you remove this syscall.
+static int fchdir_thread_local(int fd)
+{
+#pragma clang diagnostic push
+#pragma clang diagnostic ignored "-Wdeprecated-declarations"
+    return syscall(SYS___pthread_fchdir, fd);
+#pragma clang diagnostic pop
+}
+
+int qemu_mknodat(int dirfd, const char *filename, mode_t mode, dev_t dev)
+{
+    int preserved_errno, err;
+    if (fchdir_thread_local(dirfd) < 0) {
+        return -1;
+    }
+    err = mknod(filename, mode, dev);
+    preserved_errno = errno;
+    /* Stop using the thread-local cwd */
+    fchdir_thread_local(-1);
+    if (err < 0) {
+        errno = preserved_errno;
+    }
+    return err;
+}
diff --git a/hw/9pfs/9p-util.c b/hw/9pfs/9p-util.c
index 3221d9b498..4f57d8c047 100644
--- a/hw/9pfs/9p-util.c
+++ b/hw/9pfs/9p-util.c
@@ -1,5 +1,5 @@
 /*
- * 9p utilities
+ * 9p utilities (Linux Implementation)
  *
  * Copyright IBM, Corp. 2017
  *
@@ -62,3 +62,14 @@ int fsetxattrat_nofollow(int dirfd, const char *filename, const char *name,
     g_free(proc_path);
     return ret;
 }
+
+int utimensat_nofollow(int dirfd, const char *filename,
+                       const struct timespec times[2])
+{
+    return utimensat(dirfd, filename, times, AT_SYMLINK_NOFOLLOW);
+}
+
+int qemu_mknodat(int dirfd, const char *filename, mode_t mode, dev_t dev)
+{
+    return mknodat(dirfd, filename, mode, dev);
+}
diff --git a/hw/9pfs/9p-util.h b/hw/9pfs/9p-util.h
index 546f46dc7d..cac682d335 100644
--- a/hw/9pfs/9p-util.h
+++ b/hw/9pfs/9p-util.h
@@ -19,6 +19,29 @@
 #define O_PATH_9P_UTIL 0
 #endif
 
+#ifdef CONFIG_DARWIN
+#define qemu_fgetxattr(...) fgetxattr(__VA_ARGS__, 0, 0)
+#define qemu_lgetxattr(...) getxattr(__VA_ARGS__, 0, XATTR_NOFOLLOW)
+#define qemu_llistxattr(...) listxattr(__VA_ARGS__, XATTR_NOFOLLOW)
+#define qemu_lremovexattr(...) removexattr(__VA_ARGS__, XATTR_NOFOLLOW)
+static inline int qemu_lsetxattr(const char *path, const char *name,
+                                 const void *value, size_t size, int flags) {
+    return setxattr(path, name, value, size, 0, flags | XATTR_NOFOLLOW);
+}
+#else
+#define qemu_fgetxattr fgetxattr
+#define qemu_lgetxattr lgetxattr
+#define qemu_llistxattr llistxattr
+#define qemu_lremovexattr lremovexattr
+#define qemu_lsetxattr lsetxattr
+#endif
+
+/* Compatibility with old SDK Versions for Darwin */
+#if defined(CONFIG_DARWIN) && !defined(UTIME_NOW)
+#define UTIME_NOW -1
+#define UTIME_OMIT -2
+#endif
+
 static inline void close_preserve_errno(int fd)
 {
     int serrno = errno;
@@ -41,6 +64,7 @@ again:
     fd = openat(dirfd, name, flags | O_NOFOLLOW | O_NOCTTY | O_NONBLOCK,
                 mode);
     if (fd == -1) {
+#ifndef CONFIG_DARWIN
         if (errno == EPERM && (flags & O_NOATIME)) {
             /*
              * The client passed O_NOATIME but we lack permissions to honor it.
@@ -53,6 +77,7 @@ again:
             flags &= ~O_NOATIME;
             goto again;
         }
+#endif
         return -1;
     }
 
@@ -77,5 +102,9 @@ ssize_t flistxattrat_nofollow(int dirfd, const char *filename,
                               char *list, size_t size);
 ssize_t fremovexattrat_nofollow(int dirfd, const char *filename,
                                 const char *name);
+int utimensat_nofollow(int dirfd, const char *filename,
+                       const struct timespec times[2]);
+
+int qemu_mknodat(int dirfd, const char *filename, mode_t mode, dev_t dev);
 
 #endif
diff --git a/hw/9pfs/9p.c b/hw/9pfs/9p.c
index 2815257f42..dc2e6c93c0 100644
--- a/hw/9pfs/9p.c
+++ b/hw/9pfs/9p.c
@@ -27,12 +27,13 @@
 #include "virtio-9p.h"
 #include "fsdev/qemu-fsdev.h"
 #include "9p-xattr.h"
+#include "9p-util.h"
 #include "coth.h"
 #include "trace.h"
 #include "migration/blocker.h"
 #include "qemu/xxhash.h"
 #include <math.h>
-#include <linux/limits.h>
+#include <limits.h>
 
 int open_fd_hw;
 int total_open_fd;
@@ -131,11 +132,18 @@ static int dotl_to_open_flags(int flags)
         { P9_DOTL_NONBLOCK, O_NONBLOCK } ,
         { P9_DOTL_DSYNC, O_DSYNC },
         { P9_DOTL_FASYNC, FASYNC },
+#ifndef CONFIG_DARWIN
+        { P9_DOTL_NOATIME, O_NOATIME },
+        /* On Darwin, we could map to F_NOCACHE, which is
+           similar, but doesn't quite have the same
+           semantics. However, we don't support O_DIRECT
+           even on linux at the moment, so we just ignore
+           it here. */
         { P9_DOTL_DIRECT, O_DIRECT },
+#endif
         { P9_DOTL_LARGEFILE, O_LARGEFILE },
         { P9_DOTL_DIRECTORY, O_DIRECTORY },
         { P9_DOTL_NOFOLLOW, O_NOFOLLOW },
-        { P9_DOTL_NOATIME, O_NOATIME },
         { P9_DOTL_SYNC, O_SYNC },
     };
 
@@ -164,10 +172,12 @@ static int get_dotl_openflags(V9fsState *s, int oflags)
      */
     flags = dotl_to_open_flags(oflags);
     flags &= ~(O_NOCTTY | O_ASYNC | O_CREAT);
+#ifndef CONFIG_DARWIN
     /*
      * Ignore direct disk access hint until the server supports it.
      */
     flags &= ~O_DIRECT;
+#endif
     return flags;
 }
 
@@ -1276,11 +1286,17 @@ static int stat_to_v9stat_dotl(V9fsPDU *pdu, const struct stat *stbuf,
     v9lstat->st_blksize = stbuf->st_blksize;
     v9lstat->st_blocks = stbuf->st_blocks;
     v9lstat->st_atime_sec = stbuf->st_atime;
-    v9lstat->st_atime_nsec = stbuf->st_atim.tv_nsec;
     v9lstat->st_mtime_sec = stbuf->st_mtime;
-    v9lstat->st_mtime_nsec = stbuf->st_mtim.tv_nsec;
     v9lstat->st_ctime_sec = stbuf->st_ctime;
+#ifdef CONFIG_DARWIN
+    v9lstat->st_atime_nsec = stbuf->st_atimespec.tv_nsec;
+    v9lstat->st_mtime_nsec = stbuf->st_mtimespec.tv_nsec;
+    v9lstat->st_ctime_nsec = stbuf->st_ctimespec.tv_nsec;
+#else
+    v9lstat->st_atime_nsec = stbuf->st_atim.tv_nsec;
+    v9lstat->st_mtime_nsec = stbuf->st_mtim.tv_nsec;
     v9lstat->st_ctime_nsec = stbuf->st_ctim.tv_nsec;
+#endif
     /* Currently we only support BASIC fields in stat */
     v9lstat->st_result_mask = P9_STATS_BASIC;
 
@@ -2197,6 +2213,25 @@ static int v9fs_xattr_read(V9fsState *s, V9fsPDU *pdu, V9fsFidState *fidp,
     return offset;
 }
 
+/**
+ * Get the seek offset of a dirent. If not available from the structure itself,
+ * obtain it by calling telldir.
+ */
+static int v9fs_dent_telldir(V9fsPDU *pdu, V9fsFidState *fidp,
+                             struct dirent *dent)
+{
+#ifdef CONFIG_DARWIN
+    /*
+     * Darwin has d_seekoff, which appears to function similarly to d_off.
+     * However, it does not appear to be supported on all file systems,
+     * so use telldir for correctness.
+     */
+    return v9fs_co_telldir(pdu, fidp);
+#else
+    return dent->d_off;
+#endif
+}
+
 static int coroutine_fn v9fs_do_readdir_with_stat(V9fsPDU *pdu,
                                                   V9fsFidState *fidp,
                                                   uint32_t max_count)
@@ -2260,7 +2295,11 @@ static int coroutine_fn v9fs_do_readdir_with_stat(V9fsPDU *pdu,
         count += len;
         v9fs_stat_free(&v9stat);
         v9fs_path_free(&path);
-        saved_dir_pos = dent->d_off;
+        saved_dir_pos = v9fs_dent_telldir(pdu, fidp, dent);
+        if (saved_dir_pos < 0) {
+            err = saved_dir_pos;
+            break;
+        }
     }
 
     v9fs_readdir_unlock(&fidp->fs.dir);
@@ -2399,6 +2438,7 @@ static int coroutine_fn v9fs_do_readdir(V9fsPDU *pdu, V9fsFidState *fidp,
     V9fsString name;
     int len, err = 0;
     int32_t count = 0;
+    off_t off;
     struct dirent *dent;
     struct stat *st;
     struct V9fsDirEnt *entries = NULL;
@@ -2459,12 +2499,17 @@ static int coroutine_fn v9fs_do_readdir(V9fsPDU *pdu, V9fsFidState *fidp,
             qid.version = 0;
         }
 
+        off = v9fs_dent_telldir(pdu, fidp, dent);
+        if (off < 0) {
+            err = off;
+            break;
+        }
         v9fs_string_init(&name);
         v9fs_string_sprintf(&name, "%s", dent->d_name);
 
         /* 11 = 7 + 4 (7 = start offset, 4 = space for storing count) */
         len = pdu_marshal(pdu, 11 + count, "Qqbs",
-                          &qid, dent->d_off,
+                          &qid, off,
                           dent->d_type, &name);
 
         v9fs_string_free(&name);
@@ -3504,9 +3549,15 @@ static int v9fs_fill_statfs(V9fsState *s, V9fsPDU *pdu, struct statfs *stbuf)
     f_bavail = stbuf->f_bavail / bsize_factor;
     f_files  = stbuf->f_files;
     f_ffree  = stbuf->f_ffree;
+#ifdef CONFIG_DARWIN
+    fsid_val = (unsigned int)stbuf->f_fsid.val[0] |
+               (unsigned long long)stbuf->f_fsid.val[1] << 32;
+    f_namelen = MAXNAMLEN;
+#else
     fsid_val = (unsigned int) stbuf->f_fsid.__val[0] |
                (unsigned long long)stbuf->f_fsid.__val[1] << 32;
     f_namelen = stbuf->f_namelen;
+#endif
 
     return pdu_marshal(pdu, offset, "ddqqqqqqd",
                        f_type, f_bsize, f_blocks, f_bfree,
@@ -3876,6 +3927,13 @@ out_nofid:
     v9fs_string_free(&name);
 }
 
+#if defined(CONFIG_DARWIN) && !defined(XATTR_SIZE_MAX)
+/* Darwin doesn't seem to define a maximum xattr size in its user
+   user space header, but looking at the kernel source, HFS supports
+   up to INT32_MAX, so use that as the maximum.
+*/
+#define XATTR_SIZE_MAX INT32_MAX
+#endif
 static void coroutine_fn v9fs_xattrcreate(void *opaque)
 {
     int flags, rflags = 0;
diff --git a/hw/9pfs/codir.c b/hw/9pfs/codir.c
index 032cce04c4..d2423c8b21 100644
--- a/hw/9pfs/codir.c
+++ b/hw/9pfs/codir.c
@@ -167,7 +167,11 @@ static int do_readdir_many(V9fsPDU *pdu, V9fsFidState *fidp,
         }
 
         size += len;
+#ifdef CONFIG_DARWIN
+        saved_dir_pos = v9fs_co_telldir(pdu, fidp);
+#else
         saved_dir_pos = dent->d_off;
+#endif
     }
 
     /* restore (last) saved position */
diff --git a/hw/9pfs/meson.build b/hw/9pfs/meson.build
index 99be5d9119..12443b6ad5 100644
--- a/hw/9pfs/meson.build
+++ b/hw/9pfs/meson.build
@@ -4,7 +4,6 @@ fs_ss.add(files(
   '9p-posix-acl.c',
   '9p-proxy.c',
   '9p-synth.c',
-  '9p-util.c',
   '9p-xattr-user.c',
   '9p-xattr.c',
   '9p.c',
@@ -14,6 +13,8 @@ fs_ss.add(files(
   'coth.c',
   'coxattr.c',
 ))
+fs_ss.add(when: 'CONFIG_LINUX', if_true: files('9p-util.c'))
+fs_ss.add(when: 'CONFIG_DARWIN', if_true: files('9p-util-darwin.c'))
 fs_ss.add(when: 'CONFIG_XEN', if_true: files('xen-9p-backend.c'))
 softmmu_ss.add_all(when: 'CONFIG_FSDEV_9P', if_true: fs_ss)
 
diff --git a/include/qemu/statfs.h b/include/qemu/statfs.h
new file mode 100644
index 0000000000..dde289f9bb
--- /dev/null
+++ b/include/qemu/statfs.h
@@ -0,0 +1,19 @@
+/*
+ * Host statfs header abstraction
+ *
+ * This work is licensed under the terms of the GNU GPL, version 2, or any
+ * later version.  See the COPYING file in the top-level directory.
+ *
+ */
+#ifndef QEMU_STATFS_H
+#define QEMU_STATFS_H
+
+#ifdef CONFIG_LINUX
+# include <sys/vfs.h>
+#endif
+#ifdef CONFIG_DARWIN
+# include <sys/param.h>
+# include <sys/mount.h>
+#endif
+
+#endif
diff --git a/include/qemu/xattr.h b/include/qemu/xattr.h
index a83fe8e749..f1d0f7be74 100644
--- a/include/qemu/xattr.h
+++ b/include/qemu/xattr.h
@@ -22,7 +22,9 @@
 #ifdef CONFIG_LIBATTR
 #  include <attr/xattr.h>
 #else
-#  define ENOATTR ENODATA
+#  if !defined(ENOATTR)
+#    define ENOATTR ENODATA
+#  endif
 #  include <sys/xattr.h>
 #endif
 
diff --git a/meson.build b/meson.build
index b3e7ec0e92..ec36698fb7 100644
--- a/meson.build
+++ b/meson.build
@@ -1201,16 +1201,19 @@ have_host_block_device = (targetos != 'darwin' or
 # config-host.h #
 #################
 
-have_virtfs = (targetos == 'linux' and
-    have_system and
-    libattr.found() and
-    libcap_ng.found())
+if targetos == 'linux'
+  have_virtfs = (have_system and
+      libattr.found() and
+      libcap_ng.found())
+elif targetos == 'darwin'
+  have_virtfs = have_system
+endif
 
-have_virtfs_proxy_helper = have_virtfs and have_tools
+have_virtfs_proxy_helper = (targetos == 'linux' or targetos == 'darwin') and have_virtfs and have_tools
 
 if get_option('virtfs').enabled()
   if not have_virtfs
-    if targetos != 'linux'
+    if targetos != 'linux' and targetos != 'darwin'
       error('virtio-9p (virtfs) requires Linux')
     elif not libcap_ng.found() or not libattr.found()
       error('virtio-9p (virtfs) requires libcap-ng-devel and libattr-devel')

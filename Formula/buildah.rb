class Buildah < Formula
  desc "Tool that facilitates building OCI images"
  homepage "https://buildah.io"
  url "https://github.com/slp/buildah/archive/v1.19.2.macos_unpriv.tar.gz"
  sha256 "80a2e0899106da4e2b4ebf1f5135417533d57acd5f5643f58c422d91bff143a4"
  license "Apache-2.0"

  head do
    url "https://github.com/containers/buildah.git", branch: "main"

    patch :DATA
  end

  depends_on "go" => :build
  depends_on "go-md2man" => :build
  depends_on "gpgme"

  def install
    system "make"
    bin.install "bin/buildah" => "buildah"
    man1.install Dir["docs/*.1"]
  end

  test do
    assert_match "buildah version", shell_output("#{bin}/buildah -v")
  end
end

__END__
From fa1dd9918d6ea99f6dc05a7a78b43d95c75527eb Mon Sep 17 00:00:00 2001
From: Sergio Lopez <slp@sinrega.org>
Date: Mon, 25 Jan 2021 13:55:10 +0100
Subject: [PATCH 1/3] Support managing images as an unpriv user on macOS

Support managing images as an unprivileged user on macOS, by storing
user ownership and file mode bits as extended attributes. This is
mainly intended to be used on libkrun-based lightweight VMs, where its
virtio-fs implementation reads those attributes and translates them
for the Guest.

Signed-off-by: Sergio Lopez <slp@redhat.com>
---
 .../storage/drivers/driver_darwin.go          | 14 ++++
 .../storage/drivers/driver_unsupported.go     |  2 +-
 .../containers/storage/pkg/archive/archive.go | 46 ++++++++++
 .../storage/pkg/archive/archive_unix.go       | 26 ++++--
 .../pkg/chrootarchive/archive_darwin.go       | 21 +++++
 .../storage/pkg/chrootarchive/archive_unix.go |  2 +-
 .../storage/pkg/chrootarchive/chroot_unix.go  |  2 +-
 .../storage/pkg/chrootarchive/diff_darwin.go  | 41 +++++++++
 .../storage/pkg/chrootarchive/diff_unix.go    |  2 +-
 .../storage/pkg/chrootarchive/init_darwin.go  |  4 +
 .../storage/pkg/chrootarchive/init_unix.go    |  2 +-
 .../containers/storage/pkg/idtools/idtools.go | 27 ++++++
 .../storage/pkg/system/xattrs_darwin.go       | 84 +++++++++++++++++++
 .../storage/pkg/system/xattrs_unsupported.go  |  2 +-
 .../storage/pkg/unshare/unshare_darwin.go     | 53 ++++++++++++
 .../pkg/unshare/unshare_unsupported.go        |  2 +-
 16 files changed, 317 insertions(+), 13 deletions(-)
 create mode 100644 vendor/github.com/containers/storage/drivers/driver_darwin.go
 create mode 100644 vendor/github.com/containers/storage/pkg/chrootarchive/archive_darwin.go
 create mode 100644 vendor/github.com/containers/storage/pkg/chrootarchive/diff_darwin.go
 create mode 100644 vendor/github.com/containers/storage/pkg/chrootarchive/init_darwin.go
 create mode 100644 vendor/github.com/containers/storage/pkg/system/xattrs_darwin.go
 create mode 100644 vendor/github.com/containers/storage/pkg/unshare/unshare_darwin.go

diff --git a/vendor/github.com/containers/storage/drivers/driver_darwin.go b/vendor/github.com/containers/storage/drivers/driver_darwin.go
new file mode 100644
index 0000000000..357851543e
--- /dev/null
+++ b/vendor/github.com/containers/storage/drivers/driver_darwin.go
@@ -0,0 +1,14 @@
+package graphdriver
+
+var (
+	// Slice of drivers that should be used in order
+	priority = []string{
+		"vfs",
+	}
+)
+
+// GetFSMagic returns the filesystem id given the path.
+func GetFSMagic(rootpath string) (FsMagic, error) {
+	// Note it is OK to return FsMagicUnsupported on Windows.
+	return FsMagicUnsupported, nil
+}
diff --git a/vendor/github.com/containers/storage/drivers/driver_unsupported.go b/vendor/github.com/containers/storage/drivers/driver_unsupported.go
index 4a875608b0..3932c3ea5c 100644
--- a/vendor/github.com/containers/storage/drivers/driver_unsupported.go
+++ b/vendor/github.com/containers/storage/drivers/driver_unsupported.go
@@ -1,4 +1,4 @@
-// +build !linux,!windows,!freebsd,!solaris
+// +build !linux,!windows,!freebsd,!solaris,!darwin
 
 package graphdriver
 
diff --git a/vendor/github.com/containers/storage/pkg/archive/archive.go b/vendor/github.com/containers/storage/pkg/archive/archive.go
index aa4875c648..eb1f1ec5b7 100644
--- a/vendor/github.com/containers/storage/pkg/archive/archive.go
+++ b/vendor/github.com/containers/storage/pkg/archive/archive.go
@@ -12,6 +12,7 @@ import (
 	"os"
 	"path/filepath"
 	"runtime"
+	"strconv"
 	"strings"
 	"sync"
 	"syscall"
@@ -74,6 +75,7 @@ const (
 	tarExt                  = "tar"
 	solaris                 = "solaris"
 	windows                 = "windows"
+	darwin                  = "darwin"
 	containersOverrideXattr = "user.containers.override_stat"
 )
 
@@ -437,6 +439,31 @@ func ReadUserXattrToTarHeader(path string, hdr *tar.Header) error {
 	return nil
 }
 
+// ReadVirtiofsXattrToTarHeader reads user.* xattr from filesystem to a tar header
+func ReadVirtiofsXattrToTarHeader(path string, hdr *tar.Header) error {
+	xattrs, err := system.Llistxattr(path)
+	if err != nil && !errors.Is(err, system.EOPNOTSUPP) && err != system.ErrNotSupportedPlatform {
+		return err
+	}
+	for _, key := range xattrs {
+		if strings.HasPrefix(key, "virtiofs.") {
+			value, err := system.Lgetxattr(path, key)
+			if err != nil {
+				if errors.Is(err, system.E2BIG) {
+					logrus.Errorf("archive: Skipping xattr for file %s since value is too big: %s", path, key)
+					continue
+				}
+				return err
+			}
+			if hdr.Xattrs == nil {
+				hdr.Xattrs = make(map[string]string)
+			}
+			hdr.Xattrs[key] = string(value)
+		}
+	}
+	return nil
+}
+
 type TarWhiteoutHandler interface {
 	Setxattr(path, name string, value []byte) error
 	Mknod(path string, mode uint32, dev int) error
@@ -514,6 +541,11 @@ func (ta *tarAppender) addTarFile(path, name string) error {
 	if err := ReadUserXattrToTarHeader(path, hdr); err != nil {
 		return err
 	}
+	if runtime.GOOS == darwin && os.Getuid() != 0 {
+		if err := ReadVirtiofsXattrToTarHeader(path, hdr); err != nil {
+			return err
+		}
+	}
 	if ta.CopyPass {
 		copyPassHeader(hdr)
 	}
@@ -615,6 +647,8 @@ func createTarFile(path, extractDir string, hdr *tar.Header, reader io.Reader, L
 	mask := hdrInfo.Mode()
 	if forceMask != nil {
 		mask = *forceMask
+	} else if runtime.GOOS == darwin && os.Getuid() != 0 {
+		mask = os.FileMode(0700)
 	}
 
 	switch hdr.Typeflag {
@@ -1291,6 +1325,18 @@ func remapIDs(readIDMappings, writeIDMappings *idtools.IDMappings, chownOpts *id
 			if err != nil {
 				return err
 			}
+		} else if runtime.GOOS == darwin && os.Getuid() != 0 {
+			uid, gid = hdr.Uid, hdr.Gid
+			if val, ok := hdr.Xattrs["virtiofs.uid"]; ok {
+				if xuid, err := strconv.Atoi(val); err == nil {
+					uid = xuid
+				}
+			}
+			if val, ok := hdr.Xattrs["virtiofs.gid"]; ok {
+				if xgid, err := strconv.Atoi(val); err == nil {
+					gid = xgid
+				}
+			}
 		} else {
 			uid, gid = hdr.Uid, hdr.Gid
 		}
diff --git a/vendor/github.com/containers/storage/pkg/archive/archive_unix.go b/vendor/github.com/containers/storage/pkg/archive/archive_unix.go
index ecb704b64b..ec50f709f2 100644
--- a/vendor/github.com/containers/storage/pkg/archive/archive_unix.go
+++ b/vendor/github.com/containers/storage/pkg/archive/archive_unix.go
@@ -7,6 +7,8 @@ import (
 	"errors"
 	"os"
 	"path/filepath"
+	"runtime"
+	"strconv"
 	"syscall"
 
 	"github.com/containers/storage/pkg/idtools"
@@ -111,15 +113,27 @@ func handleLChmod(hdr *tar.Header, path string, hdrInfo os.FileInfo, forceMask *
 	if forceMask != nil {
 		permissionsMask = *forceMask
 	}
-	if hdr.Typeflag == tar.TypeLink {
-		if fi, err := os.Lstat(hdr.Linkname); err == nil && (fi.Mode()&os.ModeSymlink == 0) {
-			if err := os.Chmod(path, permissionsMask); err != nil {
+	if runtime.GOOS == "darwin" && os.Getuid() != 0 {
+		if val, ok := hdr.Xattrs["virtiofs.mode"]; ok {
+			if err := system.Lsetxattr(path, "virtiofs.mode", []byte(val), 0); err != nil {
+				return err
+			}
+		} else {
+			if err := system.Lsetxattr(path, "virtiofs.mode", []byte(strconv.Itoa(int(hdr.Mode) & 0777)), 0); err != nil {
 				return err
 			}
 		}
-	} else if hdr.Typeflag != tar.TypeSymlink {
-		if err := os.Chmod(path, permissionsMask); err != nil {
-			return err
+	} else {
+		if hdr.Typeflag == tar.TypeLink {
+			if fi, err := os.Lstat(hdr.Linkname); err == nil && (fi.Mode()&os.ModeSymlink == 0) {
+				if err := os.Chmod(path, permissionsMask); err != nil {
+					return err
+				}
+			}
+		} else if hdr.Typeflag != tar.TypeSymlink {
+			if err := os.Chmod(path, permissionsMask); err != nil {
+				return err
+			}
 		}
 	}
 	return nil
diff --git a/vendor/github.com/containers/storage/pkg/chrootarchive/archive_darwin.go b/vendor/github.com/containers/storage/pkg/chrootarchive/archive_darwin.go
new file mode 100644
index 0000000000..d257cc8e94
--- /dev/null
+++ b/vendor/github.com/containers/storage/pkg/chrootarchive/archive_darwin.go
@@ -0,0 +1,21 @@
+package chrootarchive
+
+import (
+	"io"
+
+	"github.com/containers/storage/pkg/archive"
+)
+
+func chroot(path string) error {
+	return nil
+}
+
+func invokeUnpack(decompressedArchive io.ReadCloser,
+	dest string,
+	options *archive.TarOptions, root string) error {
+	return archive.Unpack(decompressedArchive, dest, options)
+}
+
+func invokePack(srcPath string, options *archive.TarOptions, root string) (io.ReadCloser, error) {
+	return archive.TarWithOptions(srcPath, options)
+}
diff --git a/vendor/github.com/containers/storage/pkg/chrootarchive/archive_unix.go b/vendor/github.com/containers/storage/pkg/chrootarchive/archive_unix.go
index 630826db1e..bc6676fafb 100644
--- a/vendor/github.com/containers/storage/pkg/chrootarchive/archive_unix.go
+++ b/vendor/github.com/containers/storage/pkg/chrootarchive/archive_unix.go
@@ -1,4 +1,4 @@
-// +build !windows
+// +build !windows,!darwin
 
 package chrootarchive
 
diff --git a/vendor/github.com/containers/storage/pkg/chrootarchive/chroot_unix.go b/vendor/github.com/containers/storage/pkg/chrootarchive/chroot_unix.go
index 83278ee505..d5aedd002e 100644
--- a/vendor/github.com/containers/storage/pkg/chrootarchive/chroot_unix.go
+++ b/vendor/github.com/containers/storage/pkg/chrootarchive/chroot_unix.go
@@ -1,4 +1,4 @@
-// +build !windows,!linux
+// +build !windows,!linux,!darwin
 
 package chrootarchive
 
diff --git a/vendor/github.com/containers/storage/pkg/chrootarchive/diff_darwin.go b/vendor/github.com/containers/storage/pkg/chrootarchive/diff_darwin.go
new file mode 100644
index 0000000000..5624f9633e
--- /dev/null
+++ b/vendor/github.com/containers/storage/pkg/chrootarchive/diff_darwin.go
@@ -0,0 +1,41 @@
+package chrootarchive
+
+import (
+	"fmt"
+	"io"
+	"io/ioutil"
+	"os"
+	"path/filepath"
+
+	"github.com/containers/storage/pkg/archive"
+)
+
+// applyLayerHandler parses a diff in the standard layer format from `layer`, and
+// applies it to the directory `dest`. Returns the size in bytes of the
+// contents of the layer.
+func applyLayerHandler(dest string, layer io.Reader, options *archive.TarOptions, decompress bool) (size int64, err error) {
+	dest = filepath.Clean(dest)
+
+	if decompress {
+		decompressed, err := archive.DecompressStream(layer)
+		if err != nil {
+			return 0, err
+		}
+		defer decompressed.Close()
+
+		layer = decompressed
+	}
+
+	tmpDir, err := ioutil.TempDir(os.Getenv("temp"), "temp-storage-extract")
+	if err != nil {
+		return 0, fmt.Errorf("ApplyLayer failed to create temp-storage-extract under %s. %s", dest, err)
+	}
+
+	s, err := archive.UnpackLayer(dest, layer, nil)
+	os.RemoveAll(tmpDir)
+	if err != nil {
+		return 0, fmt.Errorf("ApplyLayer %s failed UnpackLayer to %s: %s", layer, dest, err)
+	}
+
+	return s, nil
+}
diff --git a/vendor/github.com/containers/storage/pkg/chrootarchive/diff_unix.go b/vendor/github.com/containers/storage/pkg/chrootarchive/diff_unix.go
index 4369f30c99..cf14987c0f 100644
--- a/vendor/github.com/containers/storage/pkg/chrootarchive/diff_unix.go
+++ b/vendor/github.com/containers/storage/pkg/chrootarchive/diff_unix.go
@@ -1,4 +1,4 @@
-//+build !windows
+//+build !windows,!darwin
 
 package chrootarchive
 
diff --git a/vendor/github.com/containers/storage/pkg/chrootarchive/init_darwin.go b/vendor/github.com/containers/storage/pkg/chrootarchive/init_darwin.go
new file mode 100644
index 0000000000..fa17c9bf83
--- /dev/null
+++ b/vendor/github.com/containers/storage/pkg/chrootarchive/init_darwin.go
@@ -0,0 +1,4 @@
+package chrootarchive
+
+func init() {
+}
diff --git a/vendor/github.com/containers/storage/pkg/chrootarchive/init_unix.go b/vendor/github.com/containers/storage/pkg/chrootarchive/init_unix.go
index ea08135e4d..45caec9722 100644
--- a/vendor/github.com/containers/storage/pkg/chrootarchive/init_unix.go
+++ b/vendor/github.com/containers/storage/pkg/chrootarchive/init_unix.go
@@ -1,4 +1,4 @@
-// +build !windows
+// +build !windows,!darwin
 
 package chrootarchive
 
diff --git a/vendor/github.com/containers/storage/pkg/idtools/idtools.go b/vendor/github.com/containers/storage/pkg/idtools/idtools.go
index 0cd386929a..617cf448fc 100644
--- a/vendor/github.com/containers/storage/pkg/idtools/idtools.go
+++ b/vendor/github.com/containers/storage/pkg/idtools/idtools.go
@@ -5,6 +5,7 @@ import (
 	"fmt"
 	"os"
 	"os/user"
+	"runtime"
 	"sort"
 	"strconv"
 	"strings"
@@ -307,6 +308,19 @@ func checkChownErr(err error, name string, uid, gid int) error {
 }
 
 func SafeChown(name string, uid, gid int) error {
+	if runtime.GOOS == "darwin" {
+		var ruid = os.Getuid()
+		if ruid != 0 {
+			if err := system.Lsetxattr(name, "virtiofs.uid", []byte(strconv.Itoa(uid)), 0); err != nil {
+				return err;
+			}
+			if err := system.Lsetxattr(name, "virtiofs.gid", []byte(strconv.Itoa(gid)), 0); err != nil {
+				return err;
+			}
+			uid = ruid;
+			gid = os.Getgid()
+		}
+	}
 	if stat, statErr := system.Stat(name); statErr == nil {
 		if stat.UID() == uint32(uid) && stat.GID() == uint32(gid) {
 			return nil
@@ -316,6 +330,19 @@ func SafeChown(name string, uid, gid int) error {
 }
 
 func SafeLchown(name string, uid, gid int) error {
+	if runtime.GOOS == "darwin" {
+		var ruid = os.Getuid()
+		if ruid != 0 {
+			if err := system.Lsetxattr(name, "virtiofs.uid", []byte(strconv.Itoa(uid)), 0); err != nil {
+				return err;
+			}
+			if err := system.Lsetxattr(name, "virtiofs.gid", []byte(strconv.Itoa(gid)), 0); err != nil {
+				return err;
+			}
+			uid = ruid;
+			gid = os.Getgid()
+		}
+	}
 	if stat, statErr := system.Lstat(name); statErr == nil {
 		if stat.UID() == uint32(uid) && stat.GID() == uint32(gid) {
 			return nil
diff --git a/vendor/github.com/containers/storage/pkg/system/xattrs_darwin.go b/vendor/github.com/containers/storage/pkg/system/xattrs_darwin.go
new file mode 100644
index 0000000000..75275b964e
--- /dev/null
+++ b/vendor/github.com/containers/storage/pkg/system/xattrs_darwin.go
@@ -0,0 +1,84 @@
+package system
+
+import (
+	"bytes"
+	"os"
+
+	"golang.org/x/sys/unix"
+)
+
+const (
+	// Value is larger than the maximum size allowed
+	E2BIG unix.Errno = unix.E2BIG
+
+	// Operation not supported
+	EOPNOTSUPP unix.Errno = unix.EOPNOTSUPP
+)
+
+// Lgetxattr retrieves the value of the extended attribute identified by attr
+// and associated with the given path in the file system.
+// Returns a []byte slice if the xattr is set and nil otherwise.
+func Lgetxattr(path string, attr string) ([]byte, error) {
+	// Start with a 128 length byte array
+	dest := make([]byte, 128)
+	sz, errno := unix.Lgetxattr(path, attr, dest)
+
+	for errno == unix.ERANGE {
+		// Buffer too small, use zero-sized buffer to get the actual size
+		sz, errno = unix.Lgetxattr(path, attr, []byte{})
+		if errno != nil {
+			return nil, &os.PathError{Op: "lgetxattr", Path: path, Err: errno}
+		}
+		dest = make([]byte, sz)
+		sz, errno = unix.Lgetxattr(path, attr, dest)
+	}
+
+	switch {
+	case errno == unix.ENOATTR:
+		return nil, nil
+	case errno != nil:
+		return nil, &os.PathError{Op: "lgetxattr", Path: path, Err: errno}
+	}
+
+	return dest[:sz], nil
+}
+
+// Lsetxattr sets the value of the extended attribute identified by attr
+// and associated with the given path in the file system.
+func Lsetxattr(path string, attr string, data []byte, flags int) error {
+	if err := unix.Lsetxattr(path, attr, data, flags); err != nil {
+		return &os.PathError{Op: "lsetxattr", Path: path, Err: err}
+	}
+
+	return nil
+}
+
+// Llistxattr lists extended attributes associated with the given path
+// in the file system.
+func Llistxattr(path string) ([]string, error) {
+	dest := make([]byte, 128)
+	sz, errno := unix.Llistxattr(path, dest)
+
+	for errno == unix.ERANGE {
+		// Buffer too small, use zero-sized buffer to get the actual size
+		sz, errno = unix.Llistxattr(path, []byte{})
+		if errno != nil {
+			return nil, &os.PathError{Op: "llistxattr", Path: path, Err: errno}
+		}
+
+		dest = make([]byte, sz)
+		sz, errno = unix.Llistxattr(path, dest)
+	}
+	if errno != nil {
+		return nil, &os.PathError{Op: "llistxattr", Path: path, Err: errno}
+	}
+
+	var attrs []string
+	for _, token := range bytes.Split(dest[:sz], []byte{0}) {
+		if len(token) > 0 {
+			attrs = append(attrs, string(token))
+		}
+	}
+
+	return attrs, nil
+}
diff --git a/vendor/github.com/containers/storage/pkg/system/xattrs_unsupported.go b/vendor/github.com/containers/storage/pkg/system/xattrs_unsupported.go
index bc8b8e3a5f..af1f7011c1 100644
--- a/vendor/github.com/containers/storage/pkg/system/xattrs_unsupported.go
+++ b/vendor/github.com/containers/storage/pkg/system/xattrs_unsupported.go
@@ -1,4 +1,4 @@
-// +build !linux
+// +build !linux,!darwin
 
 package system
 
diff --git a/vendor/github.com/containers/storage/pkg/unshare/unshare_darwin.go b/vendor/github.com/containers/storage/pkg/unshare/unshare_darwin.go
new file mode 100644
index 0000000000..01cf33bde7
--- /dev/null
+++ b/vendor/github.com/containers/storage/pkg/unshare/unshare_darwin.go
@@ -0,0 +1,53 @@
+// +build darwin
+
+package unshare
+
+import (
+	"os"
+
+	"github.com/containers/storage/pkg/idtools"
+	"github.com/opencontainers/runtime-spec/specs-go"
+)
+
+const (
+	// UsernsEnvName is the environment variable, if set indicates in rootless mode
+	UsernsEnvName = "_CONTAINERS_USERNS_CONFIGURED"
+)
+
+// IsRootless tells us if we are running in rootless mode
+func IsRootless() bool {
+	return true
+}
+
+// GetRootlessUID returns the UID of the user in the parent userNS
+func GetRootlessUID() int {
+	return os.Getuid()
+}
+
+// RootlessEnv returns the environment settings for the rootless containers
+func RootlessEnv() []string {
+	return append(os.Environ(), UsernsEnvName+"=")
+}
+
+// MaybeReexecUsingUserNamespace re-exec the process in a new namespace
+func MaybeReexecUsingUserNamespace(evenForRoot bool) {
+}
+
+// GetHostIDMappings reads mappings for the specified process (or the current
+// process if pid is "self" or an empty string) from the kernel.
+func GetHostIDMappings(pid string) ([]specs.LinuxIDMapping, []specs.LinuxIDMapping, error) {
+	return nil, nil, nil
+}
+
+// ParseIDMappings parses mapping triples.
+func ParseIDMappings(uidmap, gidmap []string) ([]idtools.IDMap, []idtools.IDMap, error) {
+	uid, err := idtools.ParseIDMap(uidmap, "userns-uid-map")
+	if err != nil {
+		return nil, nil, err
+	}
+	gid, err := idtools.ParseIDMap(gidmap, "userns-gid-map")
+	if err != nil {
+		return nil, nil, err
+	}
+	return uid, gid, nil
+}
diff --git a/vendor/github.com/containers/storage/pkg/unshare/unshare_unsupported.go b/vendor/github.com/containers/storage/pkg/unshare/unshare_unsupported.go
index bf4d567b8a..6ecd7e5229 100644
--- a/vendor/github.com/containers/storage/pkg/unshare/unshare_unsupported.go
+++ b/vendor/github.com/containers/storage/pkg/unshare/unshare_unsupported.go
@@ -1,4 +1,4 @@
-// +build !linux
+// +build !linux,!darwin
 
 package unshare
 

From 202bb6ec1066001bdfd282a6b252c4b05708e312 Mon Sep 17 00:00:00 2001
From: Sergio Lopez <slp@sinrega.org>
Date: Mon, 25 Jan 2021 14:01:01 +0100
Subject: [PATCH 2/3] On non-Linux systems return a valid
 DefaultNamespaceOptions

On non-Linux systems, return a valid DefualtNamespaceOptions with all
namespaces disabled, so we can at least create and mount images.

Signed-off-by: Sergio Lopez <slp@redhat.com>
---
 run_unix.go | 12 +++++++++++-
 1 file changed, 11 insertions(+), 1 deletion(-)

diff --git a/run_unix.go b/run_unix.go
index 54ca122a42..c2a2471433 100644
--- a/run_unix.go
+++ b/run_unix.go
@@ -4,6 +4,7 @@ package buildah
 
 import (
 	"github.com/containers/buildah/define"
+	"github.com/opencontainers/runtime-spec/specs-go"
 	"github.com/pkg/errors"
 )
 
@@ -20,5 +21,14 @@ func (b *Builder) Run(command []string, options RunOptions) error {
 	return errors.New("function not supported on non-linux systems")
 }
 func DefaultNamespaceOptions() (NamespaceOptions, error) {
-	return NamespaceOptions{}, errors.New("function not supported on non-linux systems")
+	options := NamespaceOptions{
+		{Name: string(specs.CgroupNamespace), Host: false},
+		{Name: string(specs.IPCNamespace), Host: false},
+		{Name: string(specs.MountNamespace), Host: false},
+		{Name: string(specs.NetworkNamespace), Host: false},
+		{Name: string(specs.PIDNamespace), Host: false},
+		{Name: string(specs.UserNamespace), Host: false},
+		{Name: string(specs.UTSNamespace), Host: false},
+	}
+	return options, nil
 }

From 49ff4d58400f1d748aa8194cb6750e3e6c5f42a2 Mon Sep 17 00:00:00 2001
From: Sergio Lopez <slp@sinrega.org>
Date: Mon, 25 Jan 2021 14:55:06 +0100
Subject: [PATCH 3/3] Makefile: allow building without .git

Use the same strategy as podman for obtaining the commit id, so we
don't fail if this is a release without the ".git" directory.

Signed-off-by: Sergio Lopez <slp@redhat.com>
---
 Makefile | 3 ++-
 1 file changed, 2 insertions(+), 1 deletion(-)

diff --git a/Makefile b/Makefile
index 2768a29176..024c2226c0 100644
--- a/Makefile
+++ b/Makefile
@@ -23,7 +23,8 @@ export GO_BUILD=$(GO) build
 endif
 RACEFLAGS := $(shell $(GO_TEST) -race ./pkg/dummy > /dev/null 2>&1 && echo -race)
 
-GIT_COMMIT ?= $(if $(shell git rev-parse --short HEAD),$(shell git rev-parse --short HEAD),$(error "git failed"))
+COMMIT_NO ?= $(shell git rev-parse HEAD 2> /dev/null || true)
+GIT_COMMIT ?= $(if $(shell git status --porcelain --untracked-files=no),${COMMIT_NO}-dirty,${COMMIT_NO})
 SOURCE_DATE_EPOCH ?= $(if $(shell date +%s),$(shell date +%s),$(error "date failed"))
 STATIC_STORAGETAGS = "containers_image_openpgp exclude_graphdriver_devicemapper $(STORAGE_TAGS)"
 

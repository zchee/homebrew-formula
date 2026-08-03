class ChromeCliHead < Formula
  desc "Control Google Chrome from the command-line"
  homepage "https://github.com/prasmussen/chrome-cli"
  license "MIT"
  head "https://github.com/prasmussen/chrome-cli.git", branch: "master"

  depends_on xcode: :build
  depends_on :macos

  patch :DATA

  def install
    # Release builds
    macosx_deployment_target = `sw_vers -productVersion`.chomp
    xcodebuild "-arch", Hardware::CPU.arch.to_s, "SYMROOT=build", "MACOSX_DEPLOYMENT_TARGET=#{macosx_deployment_target}"
    bin.install "build/Release/chrome-cli"

    # Install wrapper scripts for chrome compatible browsers
    bin.install "scripts/chrome-canary-cli"
    bin.install "scripts/chromium-cli"
    bin.install "scripts/brave-cli"
    bin.install "scripts/vivaldi-cli"
    bin.install "scripts/edge-cli"
    bin.install "scripts/arc-cli"
  end

  test do
    system bin/"chrome-cli", "version"
  end
end

__END__
diff --git a/chrome-cli/App.h b/chrome-cli/App.h
index ae3a7b9..fea59ce 100644
--- a/chrome-cli/App.h
+++ b/chrome-cli/App.h
@@ -20,10 +20,12 @@ typedef enum {
 
 - (id)initWithBundleIdentifier:(NSString *)bundleIdentifier outputFormat:(OutputFormat)outputFormat;
 - (void)listWindows:(Arguments *)args;
+- (void)listWindowsQuiet:(Arguments *)args;
 - (void)listTabs:(Arguments *)args;
 - (void)listTabsLinks:(Arguments *)args;
 - (void)listTabsInWindow:(Arguments *)args;
 - (void)listTabsLinksInWindow:(Arguments *)args;
+- (void)listTabsLinksInWindowQuiet:(Arguments *)args;
 - (void)listTabsWithLink:(Arguments *)args;
 - (void)printActiveTabInfo:(Arguments *)args;
 - (void)printTabInfo:(Arguments *)args;
diff --git a/chrome-cli/App.m b/chrome-cli/App.m
index 52202f1..de4e245 100644
--- a/chrome-cli/App.m
+++ b/chrome-cli/App.m
@@ -84,6 +84,31 @@ static NSString * const kJsPrintSource = @"(function() { return document.getElem
 
 }
 
+
+- (void)listWindowsQuiet:(Arguments *)args {
+    if (self->outputFormat == kOutputFormatJSON) {
+        NSMutableArray *windowInfos = [[NSMutableArray alloc] init];
+
+        for (chromeWindow *window in self.chrome.windows) {
+            NSDictionary *windowInfo = @{
+                @"id" : window.id,
+                @"name" : window.name,
+            };
+            [windowInfos addObject:windowInfo];
+        }
+
+        NSDictionary *output = @{
+            @"windows" : windowInfos,
+        };
+        [self printJSON:output];
+    } else {
+        for (chromeWindow *window in self.chrome.windows) {
+            printf("%s: %s\n", window.id.UTF8String, window.name.UTF8String);
+        }
+    }
+
+}
+
 - (void)listTabs:(Arguments *)args {
     if (self->outputFormat == kOutputFormatJSON) {
         NSMutableArray *tabInfos = [[NSMutableArray alloc] init];
@@ -251,6 +276,39 @@ static NSString * const kJsPrintSource = @"(function() { return document.getElem
     }
 }
 
+- (void)listTabsLinksInWindowQuiet:(Arguments *)args {
+  NSInteger windowId = [args asInteger:@"id"];
+  chromeWindow *window = [self findWindow:windowId];
+
+  if (!window) {
+    return;
+  }
+
+  if (self->outputFormat == kOutputFormatJSON) {
+    NSMutableArray *tabInfos = [[NSMutableArray alloc] init];
+
+    for (chromeTab *tab in window.tabs) {
+      NSDictionary *tabInfo = @{
+        @"windowId" : window.id,
+        @"windowName" : window.name,
+        @"id" : tab.id,
+        @"title" : tab.title,
+        @"url" : tab.URL,
+      };
+      [tabInfos addObject:tabInfo];
+    }
+
+    NSDictionary *output = @{
+      @"tabs" : tabInfos,
+    };
+    [self printJSON:output];
+  } else {
+    for (chromeTab *tab in window.tabs) {
+      printf("%s\n", tab.URL.UTF8String);
+    }
+  }
+}
+
 - (void)printActiveTabInfo:(Arguments *)args {
     chromeTab *tab = [self activeTab];
     [self printInfo:tab];
diff --git a/chrome-cli/main.m b/chrome-cli/main.m
index 4dfe618..1c84fc7 100644
--- a/chrome-cli/main.m
+++ b/chrome-cli/main.m
@@ -37,10 +37,12 @@ int main(int argc, const char * argv[])
     [argonaut add:@"help" target:argonaut action:@selector(printUsage:) description:@"Print help"];
 
     [argonaut add:@"list windows" target:app action:@selector(listWindows:) description:@"List all windows"];
+    [argonaut add:@"list windows -q" target:app action:@selector(listWindowsQuiet:) description:@"List all windows with quiet"];
     [argonaut add:@"list tabs" target:app action:@selector(listTabs:) description:@"List all tabs"];
     [argonaut add:@"list tabs -w <id>" target:app action:@selector(listTabsInWindow:) description:@"List tabs in specific window"];
     [argonaut add:@"list links" target:app action:@selector(listTabsLinks:) description:@"List all tabs' link"];
     [argonaut add:@"list links -w <id>" target:app action:@selector(listTabsLinksInWindow:) description:@"List tabs' link in specific window"];
+    [argonaut add:@"list links -q -w <id>" target:app action:@selector(listTabsLinksInWindowQuiet:) description:@"List tabs' link in specific window with quiet"];
     [argonaut add:@"list tablinks" target:app action:@selector(listTabsWithLink:) description:@"List tabs' with the link"];
 
 

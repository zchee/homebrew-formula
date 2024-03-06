class CircleciHead < Formula
  desc "Enables you to reproduce the CircleCI environment locally"
  homepage "https://circleci.com/docs/2.0/local-cli/"
  license "MIT"
  head "https://github.com/CircleCI-Public/circleci-cli.git", branch: "main"

  depends_on "go" => :build

  patch :DATA

  def install
    ldflags = %W[
      -s -w
      -X github.com/CircleCI-Public/circleci-cli/version.packageManager=homebrew
      -X github.com/CircleCI-Public/circleci-cli/version.Version=#{version}
      -X github.com/CircleCI-Public/circleci-cli/version.Commit=#{Utils.git_short_head}
      -X github.com/CircleCI-Public/circleci-cli/telemetry.SegmentEndpoint=https://api.segment.io
    ]
    system "go", "build", *std_go_args(output: bin/"circleci", ldflags: ldflags)

    generate_completions_from_executable(bin/"circleci", "--skip-update-check", "completion",
                                        shells: [:bash, :zsh], base_name: "circleci")
  end

  test do
    ENV["CIRCLECI_CLI_TELEMETRY_OPTOUT"] = "1"
    # assert basic script execution
    assert_match(/#{version}\+.{7}/, shell_output("#{bin}/circleci version").strip)
    (testpath/".circleci.yml").write("{version: 2.1}")
    output = shell_output("#{bin}/circleci config pack #{testpath}/.circleci.yml")
    assert_match "version: 2.1", output
    # assert update is not included in output of help meaning it was not included in the build
    assert_match(/update.+This command is unavailable on your platform/, shell_output("#{bin}/circleci help 2>&1"))
    assert_match "update is not available because this tool was installed using homebrew.",
      shell_output("#{bin}/circleci update")
  end
end

__END__
diff --git a/cmd/admin.go b/cmd/admin.go
index bd3e682..13939bb 100644
--- a/cmd/admin.go
+++ b/cmd/admin.go
@@ -25,9 +25,9 @@ func newAdminCommand(config *settings.Config) *cobra.Command {
 		Args: cobra.MinimumNArgs(1),
 	}
 	importOrbCommand.Flags().BoolVar(&orbOpts.integrationTesting, "integration-testing", false, "Enable test mode to bypass interactive UI.")
-	if err := importOrbCommand.Flags().MarkHidden("integration-testing"); err != nil {
-		panic(err)
-	}
+	// if err := importOrbCommand.Flags().MarkHidden("integration-testing"); err != nil {
+	// 	panic(err)
+	// }
 	importOrbCommand.Flags().BoolVar(&orbOpts.noPrompt, "no-prompt", false, "Disable prompt to bypass interactive UI.")
 
 	renameCommand := &cobra.Command{
@@ -79,9 +79,9 @@ Example:
 	deleteAliasCommand.Annotations["<name>"] = "The name of the alias to delete"
 	deleteAliasCommand.Flags().BoolVar(&nsOpts.noPrompt, "no-prompt", false, "Disable prompt to bypass interactive UI.")
 	deleteAliasCommand.Flags().BoolVar(&nsOpts.integrationTesting, "integration-testing", false, "Enable test mode to bypass interactive UI.")
-	if err := deleteAliasCommand.Flags().MarkHidden("integration-testing"); err != nil {
-		panic(err)
-	}
+	// if err := deleteAliasCommand.Flags().MarkHidden("integration-testing"); err != nil {
+	// 	panic(err)
+	// }
 
 	deleteNamespaceCommand := &cobra.Command{
 		Use:   "delete-namespace <name>",
diff --git a/cmd/config.go b/cmd/config.go
index 8fdba61..269dc62 100644
--- a/cmd/config.go
+++ b/cmd/config.go
@@ -93,9 +93,9 @@ func newConfigCommand(globalConfig *settings.Config) *cobra.Command {
 	validateCommand.PersistentFlags().BoolVarP(&verboseOutput, "verbose", "v", false, "Enable verbose output")
 	validateCommand.PersistentFlags().BoolVar(&ignoreDeprecatedImages, "ignore-deprecated-images", false, "ignores the deprecated images error")
 
-	if err := validateCommand.PersistentFlags().MarkHidden("config"); err != nil {
-		panic(err)
-	}
+	// if err := validateCommand.PersistentFlags().MarkHidden("config"); err != nil {
+	// 	panic(err)
+	// }
 	validateCommand.Flags().StringP("org-slug", "o", "", "organization slug (for example: github/example-org), used when a config depends on private orbs belonging to that org")
 	validateCommand.Flags().String("org-id", "", "organization id used when a config depends on private orbs belonging to that org")
 
diff --git a/cmd/context.go b/cmd/context.go
index f359885..8452492 100644
--- a/cmd/context.go
+++ b/cmd/context.go
@@ -134,9 +134,9 @@ are injected at runtime.`,
 	}
 	storeCommand.Flags().StringVar(&orgID, "org-id", "", orgIDUsage)
 	storeCommand.Flags().BoolVar(&integrationTesting, "integration-testing", false, "Enable test mode to setup rest API")
-	if err := storeCommand.Flags().MarkHidden("integration-testing"); err != nil {
-		panic(err)
-	}
+	// if err := storeCommand.Flags().MarkHidden("integration-testing"); err != nil {
+	// 	panic(err)
+	// }
 
 	removeCommand := &cobra.Command{
 		Short:   "Remove an environment variable from the named context",
@@ -164,9 +164,9 @@ are injected at runtime.`,
 	}
 	createContextCommand.Flags().StringVar(&orgID, "org-id", "", orgIDUsage)
 	createContextCommand.Flags().BoolVar(&integrationTesting, "integration-testing", false, "Enable test mode to setup rest API")
-	if err := createContextCommand.Flags().MarkHidden("integration-testing"); err != nil {
-		panic(err)
-	}
+	// if err := createContextCommand.Flags().MarkHidden("integration-testing"); err != nil {
+	// 	panic(err)
+	// }
 
 	force := false
 	deleteContextCommand := &cobra.Command{
diff --git a/cmd/namespace.go b/cmd/namespace.go
index aa90b3e..38612d3 100644
--- a/cmd/namespace.go
+++ b/cmd/namespace.go
@@ -92,9 +92,9 @@ Please note that at this time all namespaces created in the registry are world-r
 	createCmd.Annotations["<name>"] = "The name to give your new namespace"
 
 	createCmd.Flags().BoolVar(&opts.integrationTesting, "integration-testing", false, "Enable test mode to bypass interactive UI.")
-	if err := createCmd.Flags().MarkHidden("integration-testing"); err != nil {
-		panic(err)
-	}
+	// if err := createCmd.Flags().MarkHidden("integration-testing"); err != nil {
+	// 	panic(err)
+	// }
 	createCmd.Flags().BoolVar(&opts.noPrompt, "no-prompt", false, "Disable prompt to bypass interactive UI.")
 	opts.orgID = createCmd.Flags().String("org-id", "", "The id of your organization.")
 
diff --git a/cmd/orb.go b/cmd/orb.go
index 332b451..1a5f317 100644
--- a/cmd/orb.go
+++ b/cmd/orb.go
@@ -132,9 +132,9 @@ func newOrbCommand(config *settings.Config) *cobra.Command {
 	listCommand.PersistentFlags().BoolVar(&opts.listJSON, "json", false, "print output as json instead of human-readable")
 	listCommand.PersistentFlags().BoolVarP(&opts.listDetails, "details", "d", false, "output all the commands, executors, and jobs, along with a tree of their parameters")
 	listCommand.PersistentFlags().BoolVarP(&opts.private, "private", "", false, "exclusively list private orbs within a namespace")
-	if err := listCommand.PersistentFlags().MarkHidden("json"); err != nil {
-		panic(err)
-	}
+	// if err := listCommand.PersistentFlags().MarkHidden("json"); err != nil {
+	// 	panic(err)
+	// }
 
 	validateCommand := &cobra.Command{
 		Use:   "validate <path>",
@@ -333,9 +333,9 @@ Please note that at this time all orbs created in the registry are world-readabl
 	}
 
 	listCategoriesCommand.PersistentFlags().BoolVar(&opts.listJSON, "json", false, "print output as json instead of human-readable")
-	if err := listCategoriesCommand.PersistentFlags().MarkHidden("json"); err != nil {
-		panic(err)
-	}
+	// if err := listCategoriesCommand.PersistentFlags().MarkHidden("json"); err != nil {
+	// 	panic(err)
+	// }
 
 	addCategorizationToOrbCommand := &cobra.Command{
 		Use:   "add-to-category <namespace>/<orb> \"<category-name>\"",
@@ -379,9 +379,9 @@ Please note that at this time all orbs created in the registry are world-readabl
 	orbDiff.PersistentFlags().StringVar(&opts.color, "color", "auto", "Show colored diff. Can be one of \"always\", \"never\", or \"auto\"")
 
 	orbCreate.Flags().BoolVar(&opts.integrationTesting, "integration-testing", false, "Enable test mode to bypass interactive UI.")
-	if err := orbCreate.Flags().MarkHidden("integration-testing"); err != nil {
-		panic(err)
-	}
+	// if err := orbCreate.Flags().MarkHidden("integration-testing"); err != nil {
+	// 	panic(err)
+	// }
 	orbCreate.Flags().BoolVar(&opts.noPrompt, "no-prompt", false, "Disable prompt to bypass interactive UI.")
 
 	orbCommand := &cobra.Command{
diff --git a/cmd/root.go b/cmd/root.go
index aab8c7f..22f565e 100644
--- a/cmd/root.go
+++ b/cmd/root.go
@@ -196,13 +196,13 @@ func MakeCommands() *cobra.Command {
 	flags.BoolVar(&rootOptions.SkipUpdateCheck, "skip-update-check", skipUpdateByDefault(), "Skip the check for updates check run before every command.")
 	flags.StringVar(&rootOptions.MockTelemetry, "mock-telemetry", "", "The path where telemetry must be written")
 
-	hidden := []string{"github-api", "debug", "endpoint", "mock-telemetry"}
-
-	for _, f := range hidden {
-		if err := flags.MarkHidden(f); err != nil {
-			panic(err)
-		}
-	}
+	// hidden := []string{"github-api", "debug", "endpoint", "mock-telemetry"}
+	//
+	// for _, f := range hidden {
+	// 	if err := flags.MarkHidden(f); err != nil {
+	// 		panic(err)
+	// 	}
+	// }
 
 	// Cobra has a peculiar default behaviour:
 	// https://github.com/spf13/cobra/issues/340
diff --git a/cmd/setup.go b/cmd/setup.go
index bda0843..63cc25e 100644
--- a/cmd/setup.go
+++ b/cmd/setup.go
@@ -149,21 +149,21 @@ func newSetupCommand(config *settings.Config) *cobra.Command {
 	}
 
 	setupCommand.Flags().BoolVar(&opts.integrationTesting, "integration-testing", false, "Enable test mode to bypass interactive UI.")
-	if err := setupCommand.Flags().MarkHidden("integration-testing"); err != nil {
-		panic(err)
-	}
+	// if err := setupCommand.Flags().MarkHidden("integration-testing"); err != nil {
+	// 	panic(err)
+	// }
 
 	setupCommand.Flags().BoolVar(&opts.noPrompt, "no-prompt", false, "Disable prompt to bypass interactive UI. (MUST supply --host and --token)")
 
 	setupCommand.Flags().StringVar(&opts.host, "host", "", "URL to your CircleCI host")
-	if err := setupCommand.Flags().MarkHidden("host"); err != nil {
-		panic(err)
-	}
+	// if err := setupCommand.Flags().MarkHidden("host"); err != nil {
+	// 	panic(err)
+	// }
 
 	setupCommand.Flags().StringVar(&opts.token, "token", "", "your token for using CircleCI")
-	if err := setupCommand.Flags().MarkHidden("token"); err != nil {
-		panic(err)
-	}
+	// if err := setupCommand.Flags().MarkHidden("token"); err != nil {
+	// 	panic(err)
+	// }
 
 	return setupCommand
 }


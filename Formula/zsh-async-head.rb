class ZshAsyncHead < Formula
  desc "Perform tasks asynchronously without external tools"
  homepage "https://github.com/mafredri/zsh-async"
  head "https://github.com/mafredri/zsh-async.git", branch: "main"
  license "MIT"

  uses_from_macos "zsh"

  def install
    zsh_function.install "async.zsh" => "async"
  end

  test do
    example = <<~ZSH
      source #{zsh_function}/async
      async_init

      # Initialize a new worker (with notify option)
      async_start_worker my_worker -n

      # Create a callback function to process results
      COMPLETED=0
      completed_callback() {
        COMPLETED=$(( COMPLETED + 1 ))
        print $@
      }

      # Register callback function for the workers completed jobs
      async_register_callback my_worker completed_callback

      # Give the worker some tasks to perform
      async_job my_worker print hello
      async_job my_worker sleep 0.3

      # Wait for the two tasks to be completed
      while (( COMPLETED < 2 )); do
        print "Waiting..."
        sleep 0.1
      done

      print "Completed $COMPLETED tasks!"
    ZSH
    assert_match "Completed 2 tasks!", shell_output("zsh -c '#{example}'")
  end
end

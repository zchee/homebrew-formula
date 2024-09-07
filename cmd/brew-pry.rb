# ref: https://github.com/guoxiao/homebrew-pry/blob/master/cmd/brew-pry.rb

require "formula"
require "keg"
begin
  require "pry"
rescue => e
  odie "You should run 'gem install pry' first"
end

class Symbol
  def f(*args)
    Formulary.factory(to_s, *args)
  end
end

class String
  def f(*args)
    Formulary.factory(self, *args)
  end
end

if ARGV.include? "--examples"
  puts "'v8'.f # => instance of the v8 formula"
  puts ":hub.f.installed?"
  puts ":lua.f.methods - 1.methods"
  puts ":mpd.f.recursive_dependencies.reject(&:installed?)"
else
  ohai "Interactive Homebrew Shell"
  puts "Example commands available with: brew pry --examples"
  Pry.start
end

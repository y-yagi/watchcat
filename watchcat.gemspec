# frozen_string_literal: true

require_relative "lib/watchcat/version"

Gem::Specification.new do |spec|
  spec.name = "watchcat"
  spec.version = Watchcat::VERSION
  spec.authors = ["Yuji Yaginuma"]
  spec.email = ["yuuji.yaginuma@gmail.com"]

  spec.summary = "Simple filesystem notification library for Ruby. "
  spec.homepage = "https://github.com/y-yagi/watchcat"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features|benchmark)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/watchcat/extconf.rb"]

  spec.add_dependency "rb_sys"
  spec.add_dependency "drb"
  spec.add_development_dependency "debug"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-retry"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rake-compiler"
  spec.add_development_dependency "ruby_memcheck"
  spec.add_development_dependency "listen"
end

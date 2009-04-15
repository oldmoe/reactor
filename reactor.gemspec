Gem::Specification.new do |s|
  s.name     = "reactor"
  s.version  = "0.1.3"
  s.date     = "2009-04-11"
  s.summary  = "A pure Ruby reactor library"
  s.email    = "oldmoe@gmail.com"
  s.homepage = "http://github.com/oldmoe/reactor"
  s.description = "A simple, fast reactor library in pure Ruby"
  s.has_rdoc = true
  s.authors  = ["Muhammad A. Ali"]
  s.platform = Gem::Platform::RUBY
  s.files    = [ 
		"reactor.gemspec", 
		"README",
		"lib/reactor.rb"
	]
  s.rdoc_options = ["--main", "README"]
  s.extra_rdoc_files = ["README"]
end


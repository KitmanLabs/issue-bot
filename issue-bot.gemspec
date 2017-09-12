Gem::Specification.new do |s|
  s.name        = 'issue-bot'
  s.version     = '0.0.2'
  s.date        = '2017-01-01'
  s.summary     = "Reaps Github Issues"
  s.description = "Github Issue Reaper"
  s.authors     = ["Felix Krause", "Colm Doyle"]
  s.email       = 'colm@kitmanlabs.com'
  s.files       = ["lib/**"]
  s.homepage    =
    'https://github.com/KitmanLabs/issue-bot'
  s.license = 'MIT'

  s.add_runtime_dependency "octokit", "~> 4.0"
  s.add_runtime_dependency "pry"
  s.add_runtime_dependency "excon"
  s.add_runtime_dependency "colored"
  s.add_runtime_dependency "rake"
  s.add_runtime_dependency "rubocop"
end

require 'foodcritic'

FoodCritic::Rake::LintTask.new
task default: [:foodcritic]

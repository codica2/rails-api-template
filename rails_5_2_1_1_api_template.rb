# rails _5.2.1.1_ new APPLICATION_NAME --api --database=postgresql -m rails_5_2_1_1_api_template.rb -T

# Adding useful gems
gem 'rack-cors', require: 'rack/cors'
gem 'fast_jsonapi'

gem_group :development do
  gem 'annotate'
  gem 'overcommit'
  gem 'rubocop', require: false
end

gem_group :development, :test do
  gem 'rspec-rails'
end

gem_group :test do
  gem 'database_cleaner'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'shoulda-matchers'
  gem 'simplecov', require: false
end

after_bundle do
  run 'rspec --init'
end

# Update files
def databse_config(app_name)
  <<-CODE
default: &default
  adapter: postgresql
  encoding: unicode
  pool: 5
  username: postgres
  password:
development:
  <<: *default
  database: #{app_name}_development
test:
  <<: *default
  database: #{app_name}_test
production:
  <<: *default
  database: #{app_name}_production
  CODE
end

run 'rm -f config/database.yml'
run 'rm -f .rubocop.yml'
run 'rm -f .gitignore'

file 'config/database.yml.example', databse_config('application')

file 'spec/spec_helper.rb', <<-CODE
require 'simplecov'
SimpleCov.start do
  add_filter ['/spec/', '/config/']
end

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)

abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.before(:each) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
  end

  config.use_transactional_fixtures = false

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
CODE

file '.rubocop.yml', <<-CODE
AllCops:
  Exclude:
    - 'db/**/*'
    - 'bin/*'
    - 'config/**/*'
    - 'public/**/*'
    - 'spec/**/*'
    - 'test/**/*'
    - 'vendor/**/*'
    - 'spec/fixtures/**/*'
    - 'tmp/**/*'

Style/FrozenStringLiteralComment:
  Enabled: false

Style/Documentation:
  Enabled: false

Layout/EmptyLinesAroundModuleBody:
  EnforcedStyle: empty_lines

Layout/EmptyLinesAroundClassBody:
  EnforcedStyle: empty_lines

Metrics/LineLength:
  Max: 120

Metrics/ClassLength:
  Max: 250

Metrics/ModuleLength:
  Max: 250

Metrics/AbcSize:
  Max: 25

Metrics/MethodLength:
  Max: 20

Metrics/CyclomaticComplexity:
  Max: 7

Rails:
  Enabled: true
CODE

file '.gitignore', <<-CODE
/.bundle
# Ignore all logfiles and tempfiles.
.idea/*
/log/*
/tmp/*
# Ignore uploaded files in development
/storage/*
# Ignore master key for decrypting credentials and more.
/config/master.key
/node_modules
/yarn-error.log
.byebug_history
.ruby-version
.ruby-gemset
config/database.yml
coverage/
public/system/*
public/uploads/*
.env
CODE

file '.overcommit.yml', <<-CODE
PreCommit:
  ALL:
    problem_on_unmodified_line: ignore
    required: false
    quiet: false
  RuboCop:
    enabled: true
    on_warn: fail # Treat all warnings as failures
CODE

if yes?('Create database.yml? (yes/no)')
  app_name = ask('What is your db name?')
  file 'config/database.yml', databse_config(app_name)
  rails_command 'db:create'
end

run 'rubocop -a'

after_bundle do
  git :init
  git add: '.'
  git commit: "-a -m 'Initial commit'"
  run 'overcommit --install'
end

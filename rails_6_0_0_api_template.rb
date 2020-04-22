# rails _6.0.0_ new APPLICATION_NAME --api --database=postgresql -m rails_6_0_0_api_template.rb -T

# Adding useful gems

ruby '2.6.3'

# State machines for Ruby classes
gem 'aasm'

# The official AWS SDK for Ruby.
gem 'aws-sdk-s3', require: false

# The bcrypt Ruby gem provides a simple wrapper for safely handling passwords
gem 'bcrypt'

# A ruby implementation of the RFC 7519 OAuth JSON Web Token (JWT) standard.
gem 'jwt'

# Provides helpers which guide you in leveraging regular Ruby classes and object oriented design patterns to build a simple, robust and scalable authorization system.
gem 'pundit'

# Very simple Roles library without any authorization enforcement supporting scope on resource object.
gem 'rolify'

gem 'rack-cors', require: 'rack/cors'

# A lightning fast JSON:API serializer for Ruby Objects
gem 'fast_jsonapi'

gem 'sidekiq'

# Apitome is a API documentation tool for Rails built on top of the great RSpec DSL
gem 'apitome'

# Generate pretty API docs for your Rails APIs.
gem 'rspec_api_documentation'

gem_group :development do
  # Show emails for development mode http://localhost:3000/letter_opener
  gem 'letter_opener'
  gem 'letter_opener_web', '~> 1.0'

  # static analysis tool which checks Ruby on Rails applications for security vulnerabilities.
  gem 'brakeman'
  gem 'annotate'
  gem 'overcommit'
  gem 'rubocop', require: false
end

gem_group :development, :test do
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'database_cleaner'
  gem 'dotenv-rails'
  gem 'factory_bot_rails'
  gem 'rspec-rails', '~> 3.8'
  gem 'shoulda-matchers'
  gem 'simplecov'

  # This gem is a port of Perl's Data::Faker library that generates fake data
  gem 'faker'
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

file 'lib/json_web_token.rb', <<-CODE
require 'jwt'

class JsonWebToken

  class << self

    SECRET_KEY = Rails.application.credentials.secret_key_base

    def encode(payload)
      payload.reverse_merge!(meta)

      JWT.encode(payload, SECRET_KEY)
    end

    def decode(token)
      JWT.decode(token, SECRET_KEY).first
    end

    def meta
      { exp: 7.days.from_now.to_i }
    end

  end

end
CODE

file 'app/auth/authenticate_user.rb', <<-CODE
require 'json_web_token'

class AuthenticateUser

  prepend SimpleCommand
  attr_accessor :email, :password

  def initialize(email, password)
    @email = email
    @password = password
  end

  def call
    return unless user

    JsonWebToken.encode(user_id: user.id)
  end

  private

  def user
    current_user = User.find_by(email: email)

    return current_user if current_user && current_user.authenticate(password)

    errors.add(:user_authentication, 'Invalid credentials')
  end
end
CODE

file 'app/auth/authorize_api_request.rb', <<-CODE
class AuthorizeApiRequest

  prepend SimpleCommand

  def initialize(headers = {})
    @headers = headers
  end

  def call
    @user ||= User.find(decoded_auth_token[:user_id]) if decoded_auth_token
    @user || errors.add(:token, 'Invalid token')
  end

  private

  attr_reader :headers

  def decoded_auth_token
    @decoded_auth_token ||= JsonWebToken.decode(http_auth_header)
  end

  def http_auth_header
    return headers['Authorization'].split(' ').last if headers['Authorization'].present?

    errors.add(:token, 'Missing token')
  end

end
CODE

run 'rubocop -a'

after_bundle do
  git :init
  git add: '.'
  git commit: "-a -m 'Initial commit'"
  run 'overcommit --install'
end

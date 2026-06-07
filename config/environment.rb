require 'bundler/setup'
require 'sinatra/base'
require 'json'
require 'fileutils'
require 'securerandom'

# Load gems
Bundler.require(:default, ENV['RACK_ENV'] || :development)

# Set base path
APP_ROOT = File.expand_path('..', __dir__)

# Ensure directories exist
FileUtils.mkdir_p(File.join(APP_ROOT, 'storage'))
FileUtils.mkdir_p(File.join(APP_ROOT, 'storage', 'uploads'))
FileUtils.mkdir_p(File.join(APP_ROOT, 'storage', 'reports'))

# Add app directories to load path
$LOAD_PATH.unshift(File.join(APP_ROOT, 'app'))

# Load helpers first, then models, analyzers, services, and controllers
Dir[File.join(APP_ROOT, 'app', 'helpers', '*.rb')].each { |f| require f }
Dir[File.join(APP_ROOT, 'app', 'models', '*.rb')].each { |f| require f }
Dir[File.join(APP_ROOT, 'app', 'analyzers', '*.rb')].each { |f| require f }
Dir[File.join(APP_ROOT, 'app', 'services', '*.rb')].each { |f| require f }
Dir[File.join(APP_ROOT, 'app', 'controllers', '*.rb')].each { |f| require f }

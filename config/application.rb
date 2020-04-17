# Use bundler to load gems from Gemfile
require 'bundler'
Bundler.require

# For parsing dates and timestamps
require 'date'

# For compressing images
# require 'RMagick'

# FileUtils for handling file uploads
require 'fileutils'

# JSON
require 'json'

# Load the app
require_relative '../app/models/Database.rb'
require_relative 'settings.rb'
require_relative 'monkey_patch.rb'
Dir["app/*/*.rb"].each { |file| require_relative "../" + file }
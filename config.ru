#Use bundler to load gems
require 'bundler'

#Load gems from Gemfile
Bundler.require

#Load the app
require_relative 'app.rb'

#Slim HTML formatting
# Slim::Engine.set_options pretty: true, sort_attrs: false

#For parsing dates and timestamps
require 'date'

#FileUtils for handling file uploads
require 'fileutils'

#Run the app
run App

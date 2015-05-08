require 'rubygems'
require 'bundler/setup'
Bundler.require

REDIS = Redis.new

require 'sinatra'
require 'json'

post '/' do
  REDIS.publish 'Kaz:input', params.to_json
end


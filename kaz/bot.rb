require 'bundler'
Bundler.require
require 'forwardable'
require 'yaml'
require 'json'

class NilClass; alias_method :empty?, :nil?; end

PLUGINS = [
  {:file => 'ping', :class => 'Ping'}
]

module Bot

  # Load the config file
  require File.expand_path "../lib/config", __FILE__

  # Load the plugins
  PLUGINS.each do |p|
    require File.expand_path "../plugins/#{p[:file]}", __FILE__
  end

  # Set up the R object so plugins can use Redis
  require File.expand_path "../lib/redis-send", __FILE__

  # Set up the separate thread for listening on the "input" Redis channel
  require File.expand_path "../lib/redis-api", __FILE__

  class << self
    include Cinch::Helpers

    def report msg
      Channel(CONFIG[:irc][:admin_channel]).send msg
    end

    def bot
      unless @bot
        @bot = Cinch::Bot.new do
          configure do |c|
            c.channels = (CONFIG[:irc][:channels] + [CONFIG[:irc][:admin_channel]]).uniq
            c.nick = CONFIG[:irc][:nick]
            c.plugins.plugins = PLUGINS.map {|p| Bot.const_get p[:class]}
            c.server = CONFIG[:irc][:server]
          end

          on :connect do
            # Subscribe to the Redis channel to set up the API
            Bot::SubscriptionReactor.singleton.async.redis_subscribe unless Bot::SubscriptionReactor.singleton.subscribed?
          end
        end

        # Configure logging
        if CONFIG[:irc][:log_file]
          root = File.expand_path '../..', __FILE__
          log_file = File.open File.join(root, CONFIG[:irc][:log_file]), "a"
          @bot.loggers[0] = Cinch::Logger::FormattedLogger.new(log_file)
          Celluloid.logger = Logger.new log_file
        end
      end
      @bot
    end
  end

end

Bot.bot.start

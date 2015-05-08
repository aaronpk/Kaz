module Bot

  class SubscriptionReactor
    include Celluloid::IO

    def self.singleton
      @sub ||= SubscriptionReactor.new
    end

    def initialize
      @redis = ::Redis::Namespace.new CONFIG[:irc][:nick], redis: ::Redis.new(:driver => :celluloid)
      @subscribed = false
    end

    def subscribed?; @subscribed; end

    def redis_subscribe
      @subscribed = true
      @redis.subscribe(:input) do |on|
        on.subscribe do |channel, subscriptions|
          puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
        end

        # Define the Redis listeners so we can control the bot remotely
        on.message do |channel, msg_string|
          puts "Incoming from Redis: ##{channel}: #{msg_string}"
          message = JSON.parse msg_string
          case message['type']
          when 'text'
            if message['channel'] and message['text']
              Bot.Channel(message['channel']).send(message['text'])
            end
          when 'action'
            if message['channel'] and message['action']
              Bot.Channel(message['channel']).action(message['action'])
            end
          when 'topic'
            if message['channel'] and message['topic']
              Bot.Channel(message['channel']).topic = message['topic']
            end
          when 'op'
            if message['channel'] and message['nick']
              Bot.Channel(message['channel']).op(message['nick'])
            end
          when 'deop'
            if message['channel'] and message['nick']
              Bot.Channel(message['channel']).deop(message['nick'])
            end
          when 'voice'
            if message['channel'] and message['nick']
              Bot.Channel(message['channel']).voice(message['nick'])
            end
          when 'devoice'
            if message['channel'] and message['nick']
              Bot.Channel(message['channel']).devoice(message['nick'])
            end
          when 'kick'
            if message['channel'] and message['nick']
              Bot.Channel(message['channel']).kick(message['nick'])
            end
          when 'join'
            if message['channel']
              Bot.bot.join message['channel']
            end
          when 'part'
            if message['channel']
              Bot.bot.part message['channel'], message['text']
            end
          when 'oper'
            if message['password']
              Bot.bot.oper message['password'], message['user']
            end
          when 'mode'
            if message['mode']
              Bot.bot.set_mode message['mode']
            end
          when 'unset_mode'
            if message['mode']
              Bot.bot.unset_mode message['mode']
            end
          when 'nick'
            if message['nick']
              Bot.report "Setting nick to #{message['nick']}"
              Bot.bot.nick = message['nick']
            end
          when 'raw'
            if message['cmd']
              Bot.bot.irc.send message['cmd']
            end
          end
        end
      end
    rescue => e
      puts e.message
    ensure
      @subscribed = false
    end

  end

end
require 'rubygems'
require 'bundler/setup'
Bundler.require
require 'yaml'

AppConfig = YAML.load_file('config.yml')
DB = Sequel.connect(AppConfig['db'])
TwilioClient = Twilio::REST::Client.new AppConfig['twilio']['sid'], AppConfig['twilio']['token']

def my_nick
  Regexp.escape(AppConfig['irc']['nick'])
end




def redis_subscribe

  redis = Redis.new(:driver => :celluloid)

  redis.subscribe(:cass_irc) do |on|
    on.subscribe do |channel, subscriptions|
      puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
    end

    on.message do |channel, msg_string|
      puts "##{channel}: #{msg_string}"
      message = JSON.parse msg_string
      server = DB[:ircservers].where(:id => message['server']).first
      room = DB[:rooms].where(:id => message['room']).first
      if room
        if message['text']
          Channel(room[:irc_channel]).send(message['text'])
        elsif message['action']
          Channel(room[:irc_channel]).action(message['action'])
        end
      else
        puts "Message arrived for an invalid room: #{message['room']}"
      end
    end
  end

end


def start_irc

  bot = Cinch::Bot.new do
    configure do |c|
      c.nick = AppConfig['irc']['nick']
      c.user = AppConfig['irc']['nick']
      c.server = AppConfig['irc']['server']
      c.channels = AppConfig['irc']['channels']
    end

    on :connect do
      redis_subscribe
    end

    on :message, /^#{my_nick}: ([^ ]+) is ([^ ]+)$/i do |m, ident, nick|
      if nick == 'me'
        nick = m.user.nick
      end

      server = DB[:ircservers].where(:id => AppConfig['irc']['server_id']).first
      caller = DB[:callers]
        .join(:rooms, :id => :room_id)
        .where(:ircserver_id => server[:id])
        .where(:ident => ident).first
      if caller
        DB[:callers]
          .where(:id => caller[:id])
          .update(:nickname => nick, :date_nick_set => DateTime.now)
        m.reply "Okay, #{nick} is on #{ident}"
      else
        m.reply "Sorry, I don't see #{ident}"
      end
    end

    on :message, /^#{my_nick}: who is on the call\??$/i do |m, ident, nick|

      room = DB[:rooms]
        .where(:ircserver_id => AppConfig['irc']['server_id'])
        .where(:irc_channel => m.channel.name)
        .first

      if room
        m.reply "I'll check for you"
        conferences = TwilioClient.account.conferences.list(
          :FriendlyName => room[:dial_code],
          :Status => 'in-progress'
        )
        puts conferences.inspect
      else
        m.reply "Sorry, I don't see a conference code configured for this IRC channel"
      end
    end

  end
  bot.start

end





start_irc



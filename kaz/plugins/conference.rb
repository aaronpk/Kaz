module Bot
  class Conference
    include Cinch::Plugin

    # Use a lambda for the prefix so that if the bot nick changes it can still match it
    set :prefix, lambda{|m| Regexp.new("^" + Regexp.escape(m.bot.nick) + "[:,] ")}

    match /hello$/, method: :greet
    def greet(m)
      m.reply "Hello to you, too, #{m.user.nick}."
    end

    match /([^ ]+) is ([^ ]+)$/i, method: :set_user
    def set_user(m, ident, nick)
      db = db_connect

      if nick == 'me'
        nick = m.user.nick
      end

      server = db[:ircservers].where(:id => CONFIG[:irc][:server_id]).first
      caller = db[:callers]
        .select_all(:callers)
        .join(:rooms, :id => :room_id)
        .where(:ircserver_id => server[:id])
        .where(:ident => ident).first
      if caller
        db[:callers]
          .where(:id => caller[:id])
          .update(:nickname => nick, :date_nick_set => DateTime.now)
        m.reply "Okay, #{nick} is on #{ident}"
      else
        m.reply "Sorry, I don't see #{ident} on the call"
      end

    end

    match /who is on the call\??$/i, method: :who_is_here
    def who_is_here(m)
      db = db_connect

      room = db[:rooms]
        .where(:ircserver_id => CONFIG[:irc][:server_id])
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
end
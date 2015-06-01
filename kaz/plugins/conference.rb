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
        # First remove the nick from any other records in this room
        db[:callers]
          .where(:room_id => caller[:room_id])
          .where(:nick => nick)
          .update(:nick => nil, :date_nick_set => nil)

        # Add the nick to the current caller
        db[:callers]
          .where(:id => caller[:id])
          .update(:nick => nick, :date_nick_set => DateTime.now)
        m.reply "Okay, #{nick} is on #{ident}"
        m.reply "+#{nick}"

        # Give the IRC user voice as well
        voice_nick m.channel.name, nick

        # Add the callerid -> nick mapping for the future
        remember = db[:remember_me]
          .where(:caller_id => caller[:caller_id])
          .first
        if remember
          db[:remember_me]
            .where(:id => remember[:id])
            .update({
              :nick => nick,
              :date_lastseen => DateTime.now
            })
        else
          db[:remember_me] << {
            :caller_id => caller[:caller_id],
            :nick => nick,
            :date_added => DateTime.now,
            :date_lastseen => DateTime.now
          }
        end

      else
        m.reply "Sorry, I don't see #{ident} on the call"
      end

    end

    match /(?:what is|what's) the code\??$/i, method: :what_is_the_code
    def what_is_the_code(m)
      db = db_connect

      room = ConfHelper.room_for_channel db, m
      return unless room

      m.reply "#{room[:dial_code]}"
    end

    match /(?:who is|who's) on the (?:call?|phone)\??$/i, method: :who_is_here
    def who_is_here(m)
      db = db_connect

      room = ConfHelper.room_for_channel db, m
      return unless room

      conference = ConfHelper.current_conference db, room

      if !conference
        return m.reply "There is no active call for this conference code"
      elsif conference.class == SocketError
        return m.reply "Something went wrong trying to reach the phone system"
      end

      participants = []
      conference.participants.list.each do |p|
        sid = p.uri.match(/Participants\/(.+)\.json/)[1]
        caller = db[:callers].where(:room_id => room[:id], :call_sid => sid).first
        if caller
          string = "#{caller[:nick] ? caller[:nick] : caller[:ident]}"
          if p.muted
            string += " (muted)"
          end
          participants << string
        else
          participants << "#{sid} (not tracked)"
        end
      end

      m.reply "On the call: #{participants.join(', ')}"
    end

    match /this is ([a-z0-9]{4})$/i, method: :set_conference_code
    def set_conference_code(m, code)
      db = db_connect

      room = ConfHelper.room_for_channel db, m
      return unless room


    end

    match /(mute|unmute) ([^ ]+)$/, method: :mute
    def mute(m, action, name)
      db = db_connect

      room = ConfHelper.room_for_channel db, m
      return unless room

      # Allow users to mute themselves with "mute me"
      if name == 'me'
        name = m.user.nick
      end

      caller = ConfHelper.caller_for_name db, room[:id], name
      if !caller
        return m.reply "Sorry, I don't see #{name} on the call"
      end

      nick = caller[:nick] ? caller[:nick] : nil
      display_name = caller[:nick] ? caller[:nick] : caller[:ident]

      conference = ConfHelper.current_conference db, room
      if !conference
        return m.reply "There is no active call for this conference code"
      elsif conference.class == SocketError
        return m.reply "Something went wrong trying to reach the phone system"
      end

      if action == 'mute'
        result = ConfHelper.mute db, conference, caller[:call_sid]
        Bot.Channel(m.channel.name).devoice(nick) if nick
        m.reply "#{display_name} should now be muted" # TODO: say if already muted
      else
        ConfHelper.unmute db, conference, caller[:call_sid]
        Bot.Channel(m.channel.name).voice(nick) if nick
        m.reply "#{display_name} should now be unmuted"
      end

    end

  end
end
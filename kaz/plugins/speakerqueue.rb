module Bot
  class SpeakerQueue
    include Cinch::Plugin
    $queue = {}

    listen_to :channel

    def listen(m)
      m.message.match /^(who( is|'s|s) on (the )?)?q(ueue)?\?$/i do
        show_queue(m)
      end

      m.message.match /^q(ueue)?\+( (?<nick>[^ ]+))?( to (?<topic>.*))?$/i do |result|
        add_to_queue(m, result['nick'], result['topic'])
      end
      m.message.match /^sees ((?<nick>[^ ]+)) raise hand$/i do |result|
        add_to_queue(m, result['nick'], nil)
      end
      m.message.match /^((?<nick>[^ ]+)) raises hand$/i do |result|
        add_to_queue(m, result['nick'], nil)
      end

      m.message.match /^q(ueue)?-( (?<nick>[^ ]+))?$/i do |result|
        remove_from_queue(m, result['nick'])
      end
      m.message.match /^sees ((?<nick>[^ ]+)) lower hand$/i do |result|
        remove_from_queue(m, result['nick'])
      end
      m.message.match /^((?<nick>[^ ]+)) lowers hand$/i do |result|
        remove_from_queue(m, result['nick'])
      end

      m.message.match /^acks? (?<nick>[^ ]+)$/i do |result|
        ack_speaker(m, result['nick'])
      end
      m.message.match /^recognizes? (?<nick>[^ ]+)$/i do |result|
        ack_speaker(m, result['nick'])
      end

      m.message.match /^q=( ?(?<nicks>[^ ]+(, [^ ]+)*))?$/i do |result|
        set_queue(m, result['nicks'])
      end
      m.message.match /^queue=( ?(?<nicks>[^ ]+(, [^ ]+)*))?$/i do |result|
        set_queue(m, result['nicks'], true)
      end

    end

    def show_queue(m)
      create_queue_storage(m)
      if $queue[m.channel].empty? then
        nicklist = 'no one'
      else 
        nicklist = $queue[m.channel].keys.join ', '
      end
      m.action_reply "sees #{nicklist} on the speaker queue"
    end

    def add_to_queue(m, nick, topic)
      create_queue_storage(m)
      nick = m.user.nick if nick.nil? or nick.empty?
      nick = m.user.nick if nick == 'me'
      if $queue[m.channel].keys.member? nick then
        m.action_reply "already sees #{nick} on the speaker queue"
      else 
        $queue[m.channel][nick] = topic
        show_queue(m)
      end
    end

    def remove_from_queue(m, nick)
      create_queue_storage(m)
      nick = m.user.nick if nick.nil? or nick.empty?
      nick = m.user.nick if nick == 'me'
      if $queue[m.channel].keys.member? nick then
        $queue[m.channel].delete nick
        show_queue(m)
      end
    end

    def set_queue(m, nicks, allowEmpty=false)
      create_queue_storage(m)
      if nicks.nil? or nicks.empty? then
        if allowEmpty then
          $queue[m.channel] = {}
          show_queue(m)
        else
          m.action_reply "#{m.user.nick}, if you meant to query the queue, please say 'q?'; if you meant to replace the queue, please say 'queue= ..."
        end
      else
        $queue[m.channel] = {}
        nicks.split(', ').each do |nick|
          $queue[m.channel][nick] = nil
        end
        show_queue(m)
      end
    end

    def ack_speaker(m, nick)
      create_queue_storage(m)
      if $queue[m.channel].keys.member? nick then

        db = db_connect

        # If there is a caller for this nick, unmute them
        room = ConfHelper.room_for_channel db, m
        if room
          caller = ConfHelper.caller_for_name db, room[:id], nick
          if caller
            conference = ConfHelper.current_conference db, room
            if conference and conference.class != SocketError
              ConfHelper.unmute db, conference, caller[:call_sid]
              Bot.Channel(m.channel.name).voice(nick) if nick
              m.reply "#{display_name} should now be unmuted"
            end
          end
        end

        # Remove from queue and respond in the channel
        if $queue[m.channel][nick].nil? or $queue[m.channel][nick].empty? then
          $queue[m.channel].delete nick
          show_queue(m)
        else 
          topic = $queue[m.channel].delete nick
          if topic.empty? then
            show_queue(m)
          else
            m.reply "#{nick}, you wanted to #{topic}"
          end
        end
      end
    end

    def create_queue_storage(m)
      if $queue.nil? then
        $queue = {}
      end
      if $queue[m.channel].nil? then
        $queue[m.channel] = {}
      end
    end
  end
end
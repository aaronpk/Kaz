module Bot
  class SpeakerQueue
    include Cinch::Plugin
    $queue = {}

    listen_to :channel

    def listen(m)
      m.message.match /^(who( is|'s) on (the )?)?q(ueue)?\?$/i do
        self.showQueue(m)
      end

      m.message.match /^q(ueue)?\+( (?<nick>[^ ]+))?( to (?<topic>.*))?$/i do |result|
        self.addQueue(m, result['nick'], result['topic'])
      end
      m.message.match /^sees ((?<nick>[^ ]+)) raise hand$/i do |result|
        self.addQueue(m, result['nick'], nil)
      end
      m.message.match /^((?<nick>[^ ]+)) raises hand$/i do |result|
        self.addQueue(m, result['nick'], nil)
      end

      m.message.match /^q(ueue)?-( (?<nick>[^ ]+))?$/i do |result|
        self.remQueue(m, result['nick'])
      end
      m.message.match /^sees ((?<nick>[^ ]+)) lower hand$/i do |result|
        self.remQueue(m, result['nick'])
      end
      m.message.match /^((?<nick>[^ ]+)) lowers hand$/i do |result|
        self.remQueue(m, result['nick'])
      end

      m.message.match /^acks? (?<nick>[^ ]+)$/i do |result|
        self.ackSpeaker(m, result['nick'])
      end
      m.message.match /^recognizes? (?<nick>[^ ]+)$/i do |result|
        self.ackSpeaker(m, result['nick'])
      end

      m.message.match /^q=( ?(?<nicks>[^ ]+(, [^ ]+)*))?$/i do |result|
        self.setQueue(m, result['nicks'])
      end
      m.message.match /^queue=( ?(?<nicks>[^ ]+(, [^ ]+)*))?$/i do |result|
        self.setQueue(m, result['nicks'], true)
      end

    end

    def showQueue(m)
      self.checkAndCreate(m)
      if $queue[m.channel].empty? then
        nicklist = 'no one'
      else 
        nicklist = $queue[m.channel].keys.join ', '
      end
      m.action_reply "sees #{nicklist} on the speaker queue"
    end

    def addQueue(m, nick, topic)
      self.checkAndCreate(m)
      nick = m.user.nick if nick.nil? or nick.empty?
      nick = m.user.nick if nick == 'me'
      if $queue[m.channel].keys.member? nick then
          m.action_reply "already sees #{nick} on the speaker queue"
      else 
          $queue[m.channel][nick] = topic
          self.showQueue(m)
      end
    end

    def remQueue(m, nick)
      self.checkAndCreate(m)
      nick = m.user.nick if nick.nil? or nick.empty?
      nick = m.user.nick if nick == 'me'
      if $queue[m.channel].keys.member? nick then
          $queue[m.channel].delete nick
          self.showQueue(m)
      end
    end
    def setQueue(m, nicks, allowEmpty=false)
      self.checkAndCreate(m)
      if nicks.nil? or nicks.empty? then
          if allowEmpty then
            $queue[m.channel] = {}
            self.showQueue(m)
          else
             m.action_reply "#{m.user.nick}, if you meant to query the queue, please say 'q?'; if you meant to replace the queue, please say 'queue= ..."
          end
      else
          $queue[m.channel] = {}
          nicks.split(', ').each do |nick|
              $queue[m.channel][nick] = nil
          end
          self.showQueue(m)
      end
    end

    def ackSpeaker(m, nick)
      self.checkAndCreate(m)
      if $queue[m.channel].keys.member? nick then
        if $queue[m.channel][nick].nil? or $queue[m.channel][nick].empty? then
          $queue[m.channel].delete nick
          self.showQueue(m)
        else 
          topic = $queue[m.channel].delete nick
          if topic.empty? then
            self.showQueue(m)
          else
            m.reply "#{nick}, you wanted to #{topic}"
          end
        end
      end
    end

    def checkAndCreate(m)
        if $queue.nil? then
            $queue = {}
        end
        if $queue[m.channel].nil? then
            $queue[m.channel] = {}
        end
    end
  end
end
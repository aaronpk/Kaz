require 'rubygems'
require 'bundler/setup'
Bundler.require
require 'yaml'
require 'json'

CONFIG_FILE = File.expand_path '../config.yml', __FILE__
begin
  CONFIG = YAML.load_file CONFIG_FILE
rescue => e
  STDERR.puts "unable to read: #{CONFIG_FILE}"
  STDERR.puts e
  exit 1
end

REDIS = ::Redis::Namespace.new CONFIG[:irc][:nick], redis: ::Redis.new(:driver => :celluloid)
DB = Sequel.connect(CONFIG[:db])
TwilioClient = Twilio::REST::Client.new CONFIG[:twilio][:sid], CONFIG[:twilio][:token]

require File.expand_path "../lib/aliases", __FILE__
require File.expand_path "../lib/conference", __FILE__

class App < Sinatra::Base

  class Config
    def self.receive_url
      CONFIG[:base_url] + "/call/digits"
    end

    def self.conference_callback_url
      CONFIG[:base_url] + "/call/callback"
    end
  end

  def join_conference(call_sid, caller_id, type, gateway, code)
    # Look up conference code to find the IRC room
    room = DB[:rooms]
      .select_all(:rooms)
      .join(:ircservers, :id => :ircserver_id)
      .join(:gateways, :ircserver_id => :ircservers__id)
      .where(:gateways__type => type)
      .where(:gateways__value => gateway)
      .where(:dial_code => code)
      .first

    if room
      server = DB[:ircservers].where(:id => room[:ircserver_id]).first

      # if type=phone, generate a random 4-char suffix, show that plus the rest of the number as the display name
      if type == 'phone'
        # Find the number of callers already on the call
        num_callers = DB[:callers]
         .where(:room_id => room[:id])
         .count
        # Get an alias for this newest caller
        ident = Alias::generate num_callers+1

        trunc_caller_id = caller_id[0..-5]

        # If the truncated caller ID matches a US phone number, add dots
        if m=trunc_caller_id.match(/^1(\d{3})(\d{3})/ )
          trunc_caller_id = "1.#{m[1]}.#{m[2]}."
        end
        display_name = trunc_caller_id + ident

      else
        ident = caller_id[-4..-1]
        display_name = ident
      end

      # Log the participant in the room
      caller = DB[:callers]
                .where(:room_id => room[:id])
                .where(:caller_id => caller_id)
                .first
      if caller
        DB[:callers]
          .where(:id => caller[:id])
          .update(:date_joined => DateTime.now, :ident => ident, :call_sid => call_sid)
      else
        cid = DB[:callers].insert({
          :room_id => room[:id],
          :caller_id => caller_id,
          :ident => ident,
          :call_sid => call_sid,
          :date_joined => DateTime.now
        })
        caller = DB[:callers].where(:id => cid).first
      end

      # if type=phone or sip, look up the caller ID in the nick cache
      if type == 'phone' # or sip
        remembered = DB[:remember_me]
                      .where(:caller_id => caller[:caller_id])
                      .first
        if remembered
          display_name = remembered[:nick]
          DB[:callers]
            .where(:id => caller[:id])
            .update(:nick => remembered[:nick])
        end
      end

      # Send a message to IRC that the caller joined
      message = "+#{display_name}"
      REDIS.publish 'input', {:type => 'text', :channel => room[:irc_channel], :text => message}.to_json
      # If the caller corresponds to an IRC user, give them voice
      if caller[:nick]
        REDIS.publish 'input', {:type => 'voice', :channel => room[:irc_channel], :nick => caller[:nick]}.to_json
      end

      xml = Twilio::TwiML::Response.new do |r|
        r.Dial({
          :action => Config.conference_callback_url+"?room="+room[:id].to_s,
          :method => 'POST'  
        }) do |d|
          d.Conference(code, {
            :beep => 'true',
            :startConferenceOnEnter => 'true'
          })
        end
      end.text
      puts xml
      xml
    else
      Twilio::TwiML::Response.new do |r|
        r.say 'Sorry, that is not a valid code'
      end.text
    end
  end

  def get_caller_id(params)
    if params[:To] == ''
      params[:CallSid]
    else
      params[:From]
    end
  end

  get '/' do
    'Hello world, I am Kaz, your friendly telcon robot!'
  end

  get '/call' do
    erb :call
  end

  post '/irc' do
    REDIS.publish 'input', params.to_json
  end

  get '/call/participants' do
    room = DB[:rooms].where(:id => params[:room]).first

    if room
      conference = ConfHelper.current_conference DB, room
      if conference
        response = []
        conference.participants.list.each do |p|
          sid = p.uri.match(/Participants\/(.+)\.json/)[1]
          caller = DB[:callers].where(:room_id => room[:id], :call_sid => sid).first
          response << {
            :date_created => p.date_created,
            :muted => p.muted,
            :uri => p.uri,
            :sid => sid,
            :caller => caller
          }
        end
        response.to_json
      else
        'no call in progress'
      end
    end
  end

  post '/call/incoming' do
    jj params

    # if To is blank, it was from a browser phone
    if params[:To] == ''
      return join_conference params[:CallSid], params[:CallSid], 'browser', params[:ApplicationSid], params[:code]
    else
      # TODO: SIP!
      gateway = params[:To]
      type = 'phone'
    end

    Twilio::TwiML::Response.new do |r|
      r.Say 'This is Kaz, your friendly telcon robot.'
      r.Gather :numDigits => 4, :action => Config.receive_url+'?To='+gateway+'&type='+type, :method => 'post' do |g|
        g.Say 'Please enter your four digit conference code.'
      end
    end.text
  end

  post '/call/digits' do
    join_conference params[:CallSid], params[:From], params[:type], params[:To], params[:Digits]
  end

  post '/call/callback' do
    room = DB[:rooms].where(:id => params[:room]).first

    if room
      server = DB[:ircservers].where(:id => room[:ircserver_id]).first
      jj params
      if params[:CallStatus] == 'completed'
        caller_id = get_caller_id params
        caller = DB[:callers]
          .where(:room_id => room[:id])
          .where(:caller_id => caller_id)

        record = caller.first
        if !record
          puts "Caller disconnected but wasn't already on the call"
          puts "#{room[:id]} #{caller_id}"
          return
        end

        if record[:nick]
          display_name = record[:nick]
        else
          display_name = record[:ident]
        end
        caller.delete

        message = "-#{display_name}"
        REDIS.publish 'input', {:type => 'text', :channel => room[:irc_channel], :text => message}.to_json

        # If the caller is on IRC, devoice them as well
        if record[:nick]
          REDIS.publish 'input', {:type => 'devoice', :channel => room[:irc_channel], :nick => record[:nick]}.to_json
        end
      end
    end

    Twilio::TwiML::Response.new do |r|
      r.Say 'Goodbye'
    end.text    
  end

end

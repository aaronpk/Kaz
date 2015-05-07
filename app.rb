require 'rubygems'
require 'bundler/setup'
Bundler.require
require 'yaml'

AppConfig = YAML.load_file('config.yml')
DB = Sequel.connect(AppConfig['db'])
REDIS = Redis.new
TwilioClient = Twilio::REST::Client.new AppConfig['twilio']['sid'], AppConfig['twilio']['token']

class App < Sinatra::Base

  class Config
    def self.receive_url
      AppConfig['base_url'] + "/call/digits"
    end

    def self.conference_callback_url
      AppConfig['base_url'] + "/call/callback"
    end
  end

  def join_conference(caller_id, type, called_id, code)
    # Look up conference code to find the IRC room
    room = DB[:rooms]
      .select_all(:rooms)
      .join(:ircservers, :id => :ircserver_id)
      .join(:gateways, :ircserver_id => :ircservers__id)
      .where(:gateways__type => type)
      .where(:gateways__value => called_id)
      .where(:dial_code => code)
      .first

    if room
      server = DB[:ircservers].where(:id => room[:ircserver_id]).first

      # TODO: if type=phone look up the caller ID in the nick cache

      ident = caller_id[-4..-1]

      # Log the participant in the room
      caller = DB[:callers]
        .where(:room_id => room[:id])
        .where(:caller_id => caller_id)
        .first
      if caller
        DB[:callers]
          .where(:id => caller[:id])
          .update(:date_joined => DateTime.now, :ident => ident)
      else
        DB[:callers] << {
          :room_id => room[:id],
          :caller_id => caller_id,
          :ident => ident,
          :date_joined => DateTime.now
        }
      end

      # Send a message to IRC that the caller joined
      message = "+#{ident}"
      REDIS.publish 'cass_irc', {:server => server[:id], :room => room[:id], :text => message}.to_json

      xml = Twilio::TwiML::Response.new do |r|
        r.Dial({
          :action => Config.conference_callback_url+"?room="+room[:id].to_s,
          :method => 'POST'  
        }) do |d|
          d.Conference(code, {
            :enterSound => 'beep:1',
            :exitSound => 'beep:2',
            :startConferenceOnEnter => 'true'
          })
        end
      end.text
      puts xml
      xml
    else
      Twilio::TwiML::Response.new do |r|
        r.say 'Sorry, that is not a valid room'
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
    'Hello world, I am Cass, your friendly telcon robot!'
  end

  post '/call/incoming' do
    jj params

    # if To is blank, it was from a browser phone
    if params[:To] == ''
      called_id = params[:ApplicationSid]
      type = 'browser'
      puts "WHAT IS GOING ON"
      return join_conference params[:CallSid], 'browser', called_id, params[:code]
    else
      called_id = params[:To]
      type = 'phone'
    end

    Twilio::TwiML::Response.new do |r|
      r.Say 'This is Cass, your friendly telcon robot.'
      r.Gather :numDigits => 4, :action => Config.receive_url+'?called_id='+called_id+'&type='+type, :method => 'post' do |g|
        g.Say 'Please enter your four digit conference code.'
      end
    end.text
  end

  post '/call/digits' do
    join_conference params[:From], params[:type], params[:called_id], params[:Digits]
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

        ident = caller.first[:ident]
        caller.delete

        message = "-#{ident}"
        REDIS.publish 'cass_irc', {:server => server[:id], :room => room[:id], :text => message}.to_json
      end
    end

    Twilio::TwiML::Response.new do |r|
      r.Say 'Goodbye'
    end.text    
  end

end

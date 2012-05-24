require 'rubygems'
require 'sinatra/base'
require 'rack/websocket'
require 'json'

USERS = {}
class App < Sinatra::Base
  get '/' do
    send_file File.expand_path('../webrtc_test.html', __FILE__);
  end
end


class User
  def initialize(name, ws)
    @name = name
    @ws = ws
  end
  
  def to_json(*a)
    @name.inspect
  end  
  
  attr_reader :name, :ws
end    

class WebSocketApp < Rack::WebSocket::Application
  def on_open(env)
    @uid = (rand*10**5).to_i
    puts "creating an instance with #{@uid}"
    send_data({current_peers: USERS})
  end
  
  def on_close(env)
    user = USERS.delete @uid
    USERS.values.each {|other_user| other_user.ws.send_data "remove_user" => @uid}
    puts "removing user #{@uid} with name #{user.to_json}"
  end
  
  def on_message(env, msg)
    data = JSON.parse(msg)
    data.each {|k,v| self.send(k.to_sym, env, v)}
  end
  
  def connect(env, data)
    new_user = User.new(data['name'], self)
    USERS.values.each {|other_user| other_user.ws.send_data "new_user" => {@uid => new_user}}
    USERS[@uid] = new_user
    puts "now I have #{USERS.to_json}.inspect"
  end  
  
  def send_data(data)
    super(data.to_json)
  end
  
  def peermsg(env, data)
    peer = USERS[data['peer_id']]
    puts data['peer_id'].inspect
    
    peer.ws.send_data "peermsg" => {:uid => @uid, :data => data['data']}
  end    

  def on_error(env, error)
      puts "Error occured: " + error.message
  end    
end

map '/ws' do
  run WebSocketApp.new
end
map '/' do
  run App
end


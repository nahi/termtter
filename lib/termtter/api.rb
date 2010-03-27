# -*- coding: utf-8 -*-

config.set_default(:host, 'api.twitter.com')
if ENV.has_key?('HTTP_PROXY')
  require 'uri'
  proxy = ENV['HTTP_PROXY']
  proxy = "http://" + proxy if proxy !~ /^http:\/\//
  u = URI.parse(proxy)
  config.proxy.set_default(:host, u.host)
  config.proxy.set_default(:port, u.port.to_s)

  if u.userinfo.nil?
    config.proxy.set_default(:host, nil)
    config.proxy.set_default(:port, nil)
  else
    user_name,password = u.userinfo.split(/:/)
    config.proxy.set_default(:user_name, user_name)
    config.proxy.set_default(:password, password)
  end
else
  config.proxy.set_default(:host, nil)
  config.proxy.set_default(:port, nil)
end
config.proxy.set_default(:user_name, nil)
config.proxy.set_default(:password, nil)
config.set_default(:enable_ssl, true)

module Termtter
  module API
    class << self
      attr_reader :connection, :twitter
      def setup
        3.times do
          begin
            if twitter = try_auth
              @twitter = twitter
              # NOTE: for compatible
              @connection = twitter.instance_variable_get(:@connection)
              break
            end
          rescue Timeout::Error
            puts TermColor.parse("<red>Time out :(</red>")
            exit!
          end
        end

        exit! unless twitter
      end

      def try_auth
        if config.user_name.empty? || need_password?
          puts 'Please enter your Twitter login:'
        end

        ui = create_highline

        if config.user_name.empty?
          config.user_name = ui.ask('Username: ')
        else
          puts "Username: #{config.user_name}"
        end
        if need_password?
          config.password = ui.ask('Password: ') { |q| q.echo = false}
        end

        twitter = RubytterProxy.new(config, twitter_option)
        begin
          twitter.verify_credentials
          return twitter
        rescue Rubytter::APIError
          config.__clear__(:password)
        end
        return nil
      end

      def twitter_option
        {
          :app_name => config.app_name.empty? ? Termtter::APP_NAME : config.app_name,
          :host => config.host,
          :header => {
            'User-Agent' => 'Termtter http://github.com/jugyo/termtter',
            'X-Twitter-Client' => 'Termtter',
            'X-Twitter-Client-URL' => 'http://github.com/jugyo/termtter',
            'X-Twitter-Client-Version' => Termtter::VERSION
          },
          :enable_ssl => config.enable_ssl,
          :proxy_host => config.proxy.host,
          :proxy_port => config.proxy.port,
          :proxy_user_name => config.proxy.user_name,
          :proxy_password => config.proxy.password,
          :wiredump => config.wiredump
        }
      end

      def need_password?
        params = config.rubytter_driver_params
        config.password.empty? &&
          params && params.key?(:password) && params[:password].nil?
      end
    end
  end
end
# Termtter::API.connection, Termtter::API.twitter can be accessed.

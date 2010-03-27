# -*- coding: utf-8 -*-
config.set_default(:memory_cache_size, 10000)

module Termtter
  class RubytterProxy
    include Hookable

    attr_reader :rubytter

    def initialize(config, options)
      rubytter = config.rubytter_driver || 'Rubytter'
      params = config.rubytter_driver_params.merge(:user_name => config.user_name)
      params[:password] ||= config.password if params.key?(:password)
      @rubytter = const_from_name(rubytter).new(params, options)
    end

    def method_missing(method, *args, &block)
      if @rubytter.respond_to?(method)
        result = nil
        begin
          modified_args = args
          hooks = self.class.get_hooks("pre_#{method}")
          hooks.each do |hook|
            modified_args = hook.call(*modified_args)
          end

          from = Time.now
          Termtter::Client.logger.debug(
            "rubytter_proxy: #{method}(#{modified_args.inspect[1...-1]})")
          result = call_rubytter_or_use_cache(method, *modified_args, &block)
          Termtter::Client.logger.debug(
            "rubytter_proxy: #{method}(#{modified_args.inspect[1...-1]}), " +
            "%.2fsec" % (Time.now - from))

          self.class.call_hooks("post_#{method}", *args)
        rescue HookCanceled
        rescue TimeoutError => e
          Termtter::Client.logger.debug(
            "rubytter_proxy: #{method}(#{modified_args.inspect[1...-1]}) " +
            "#{e.message} #{'%.2fsec' % (Time.now - from)}")
          raise e
        rescue => e
          Termtter::Client.logger.debug(
            "rubytter_proxy: #{method}(#{modified_args.inspect[1...-1]}) #{e.message}")
          raise e
        end
        result
      else
        super
      end
    end

    def status_cache_store
      # TODO: DB store とかにうまいこと切り替えられるようにしたい
      @status_cache_store ||= MemoryCache.new(config.memory_cache_size)
    end

    def users_cache_store
      @users_cache_store ||= MemoryCache.new(config.memory_cache_size)
    end

    def cached_user(screen_name)
      users_cache_store[screen_name]
    end

    def cached_status(id)
      status_cache_store[id.to_i]
    end

    def call_rubytter_or_use_cache(method, *args, &block)
      case method
      when :show
        unless status = cached_status(args[0])
          status = call_rubytter(method, *args, &block)
          store_status_cache(status)
        end
        status
      when :home_timeline, :user_timeline, :friends_timeline, :search
        statuses = call_rubytter(method, *args, &block)
        statuses.each do |status|
          store_status_cache(status)
        end
        statuses
      else
        call_rubytter(method, *args, &block)
      end
    end

    def store_status_cache(status)
      return if status_cache_store.key?(status.id)
      status_cache_store[status.id] = status
      store_user_cache(status.user)
    end

    def store_user_cache(user)
      return if users_cache_store.key?(user.screen_name)
      users_cache_store[user.screen_name] = user
    end

    def call_rubytter(method, *args, &block)
      config.retry.times do
        begin
          timeout(config.timeout) do
            return @rubytter.__send__(method, *args, &block)
          end
        rescue TimeoutError
        end
      end
      raise TimeoutError, 'execution expired'
    end

    def const_from_name(fqname)
      fqname.split("::").inject(Kernel) { |klass, name| klass.const_get(name) }
    end
  end
end

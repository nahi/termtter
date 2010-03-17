# -*- coding: utf-8 -*-
require 'rubytter'

module Termtter
  class ActiveRubytter
    def initialize(data)
      self.attributes = data
    end

    def id
      @data[:id]
    end

    def [](key)
      @data[key]
    end

    def method_missing(name, *args)
      if @data.key?(name)
        return @data[name]
      else
        super
      end
    end

    def attributes=(raw_hash)
      @data = {}
      raw_hash.each do |key, value|
        key_symbol = key.to_s.to_sym
        if value.kind_of? Hash
          @data[key_symbol] = ActiveRubytter.new(raw_hash[key])
        else
          @data[key_symbol] = raw_hash[key]
        end
      end
    end

    def to_hash
      @data.inject({}) do |memo, (key, value)|
        memo[key] =
          (value.kind_of? self.class) ? value.to_hash : value
        memo
      end
    end

    def retweeted_status
      nil
    end
  end
end

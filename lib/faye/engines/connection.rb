module Faye
  module Engine

    class Connection
      include Deferrable
      include Timeouts
      include Logging

      attr_accessor :socket

      def initialize(engine, id, options = {})
        @engine  = engine
        @id      = id
        @options = options
        @inbox   = Set.new
      end

      def deliver(message)
        message.delete('clientId')
        return @socket.send(message) if @socket
        return unless @inbox.add?(message)
        begin_delivery_timeout
      end

      def connect(options, &block)
        debug('? calling Faye::Engine::Connection#connect', @id)
        options = options || {}
        timeout = options['timeout'] ? options['timeout'] / 1000.0 : @engine.timeout

        set_deferred_status(:unknown)
        callback(&block)

        begin_delivery_timeout
        begin_connection_timeout(timeout)
      end

      def flush
        debug('? calling Faye::Engine::Connection#flush', @id)
        remove_timeout(:connection)
        remove_timeout(:delivery)
        debug('? Faye::Engine::Connection#flush timeouts removed', @id)

        set_deferred_status(:succeeded, @inbox.entries)
        debug('? Faye::Engine::Connection#flush set deferred status to succeeded', @id)
        @inbox = []

        @engine.close_connection(@id) unless @socket
      end

    private

      def begin_delivery_timeout
        debug('? calling Faye::Engine::Connection#begin_delivery_timeout', @id)
        return if @inbox.empty?
        debug('? Faye::Engine::Connection#begin_delivery_timeout after inbox check', @id)
        add_timeout(:delivery, MAX_DELAY) { flush }
      end

      def begin_connection_timeout(timeout)
        debug('? calling Faye::Engine::Connection#begin_connection_timeout', @id)
        add_timeout(:connection, timeout) { flush }
      end
    end

  end
end

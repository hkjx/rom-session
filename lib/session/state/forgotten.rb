module Session
  class State
    # An State that represents a forgotten domain object. It is no longer state tracked.
    class Forgotten < self
      # Initialized forgotten object state
      #
      # @param [Object] object the forgotten domain object
      # @param [Object] remote_key the last remote key
      #
      # @api private
      #
      def initialize(object, remote_key)
        @object, @remote_key = object,remote_key
      end

      # Remove object from identity map
      #
      # @param [Hash] identity_map
      #
      # @return [self]
      #
      # @api private
      #
      def update_identity(identity_map)
        identity_map.delete(@remote_key)

        self
      end

      # Remove object from tracking
      #
      # @param [Tracker] tracker
      #
      # @return [self]
      #
      # @api private
      #
      def update_tracker(tracker)
        tracker.delete(@object)

        self
      end
    end
  end
end
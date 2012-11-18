module DataMapper
  class Session
    class State

      # Persistance state that is potentially dirty
      class Dirty < self

        # Return old state
        #
        # @return [State]
        #
        # @api private
        #
        attr_reader :old

        # Test if object is dirty
        #
        # @return [true]
        #   if object is dirty
        #
        # @return [false]
        #   otherwise
        #
        # @api private
        #
        def clean?
          dump == old.dump
        end
        memoize :clean?

        # Persist changes to dirty object (if any)
        #
        # @return [State]
        #
        # @api private
        #
        def persist
          old = self.old

          return old if clean?

          mapper.update(self, old)

          Loaded.new(self)
        end

      private

        # Initialize object
        #
        # @param [State] old
        #
        # @return [undefined]
        #
        # @api private
        #
        def initialize(old)
          @old = old
          super(old.mapping)
        end

      end
    end
  end
end
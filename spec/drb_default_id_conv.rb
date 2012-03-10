require 'drb'

if defined?(JRUBY_VERSION)
  require 'jruby'
  if JRuby.runtime.is1_9 # only changing for jruby --1.9 !
    
    require 'weakref'
    class DRb::WeakRefDRbIdConv
      
      def initialize
        @id2ref = {}
      end

      # Convert an object reference id to an object.
      #
      # This implementation looks up the reference id in the local object
      # space and returns the object it refers to.
      def to_obj(ref)
        _get(ref) || super
      end

      # Convert an object into a reference id.
      #
      # This implementation returns the object's __id__ in the local
      # object space.
      def to_id(obj)
        (obj.nil? ? nil : _put(obj)) || super
      end

      def _clean
        dead = []
        @id2ref.each {|id,weakref| dead << id unless weakref.weakref_alive?}
        dead.each {|id| @id2ref.delete(id)}
      end

      def _put(obj)
        _clean
        @id2ref[obj.__id__] = WeakRef.new(obj)
        obj.__id__
      end

      def _get(id)
        weakref = @id2ref[id]
        if weakref
          result = weakref.__getobj__ rescue nil
          if result
            return result
          else
            @id2ref.delete id
          end
        end
        nil
      end
      private :_clean, :_put, :_get
      
    end
    
    # NOTE: the same default object id converter #DRb::DRbIdConv as in 1.8 mode 
    # (not relying on ObjectSpace which is what #DRb::DRbIdConv does in 1.9) :
    DRb::DRbServer.default_id_conv(DRb::WeakRefDRbIdConv.new)
    
  end
end
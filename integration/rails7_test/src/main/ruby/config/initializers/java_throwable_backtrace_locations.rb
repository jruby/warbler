if defined?(Java)
  Java::JavaLang::Throwable.class_eval do
    # Ruby's #backtrace_locations isn't defined on Java Throwables. Rails 7.2's
    # ActionDispatch::ExceptionWrapper#build_backtrace assumes it exists, and the
    # NoMethodError it raises masks the real underlying Java exception (see actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:269)
    # https://github.com/jruby/jruby/blob/2e078cd889f0a025ff607d9919f3dfdf9bf24390/core/src/main/java/org/jruby/javasupport/ext/JavaLang.java#L221
    #
    # This at least allows us to get the message, even though there is no backtrace.
    def backtrace_locations
      warn "unsupported backtrace_locations access for #{self.inspect}, dumping normal backtrace; and returning empty"
      puts self.backtrace
      return []
    end
  end
end

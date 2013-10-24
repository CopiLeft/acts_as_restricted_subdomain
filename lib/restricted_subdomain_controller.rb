require 'action_controller'

module RestrictedSubdomain
  module Controller
    ##
    # == General
    #
    # Enables subdomain restrictions by adding a before_filter and helper to
    # access the current subdomain through current_subdomain in the
    # controller.
    #
    # == Usage
    #
    # Takes two arguments: :through and :by. :through should be a class of the
    # model used to represent the subdomain (defaults to Agency) and the :by
    # should be the column name of the field containing the subdomain
    # (defaults to :code).
    #
    # Optional argument :global. This is a subdomain (or array) that should not
    # perform a subdomain lookup. Instead, the current subdomain will be left blank
    # and your application code will run "globally", with access to all agencies.
    # E.g. a login portal.
    #
    # == Working Example
    #
    # For example, the usage of Agency and :code will work out thusly:
    #
    # In app/controllers/application.rb (or any other!) add:
    #   use_restricted_subdomains :through => 'Agency', :by => :code
    #
    # 1. Request hits http://secksi.example.com/login
    # 2. Subdomain becomes 'secksi'
    # 3. The corresponding 'Agency' with a ':code' of 'secksi' becomes the
    #    current subdomain. If it's not found, an RestrictedSubdomain::SubdomainNotFound
    #    is thrown to automatically raise a 404 not found.
    #
    # == account_location
    #
    # This plugin is very similar to the functionality of the account_location
    # plugin written by DHH. There are three basic differences between them,
    # though. This plugin allows for any model and any column, not just
    # @account.username like account_plugin. I also wanted epic failure if a
    # subdomain was not found, not just pretty "uh oh" or a default page.
    # There should be no choice -- just finished. The plugin also integrates
    # with the model, you cannot access information outside of your domain
    # for any model tagged with subdomain restrictions. If your users are
    # limited to a subdomain, you cannot in any way access the users from
    # another subdomain simply by typing User.find(params[:random_id]).
    # It should also provide an epic failure.
    #
    # This plugin provides that kind of separation. It was designed to provide
    # separation of data in a medical application so as to run _n_ different
    # instances of an application in _1_ instance of the application, with
    # software restrictions that explicitly and implicitly forbid access
    # outside of your natural subdomain.
    #
    # Funny story: I actually completely finished this part of the plugin...
    # Then i discovered that account_location existed and did pretty much the
    # same thing without any meta-programming. Good times :)
    #
    def use_restricted_subdomains(opts = {})
      options = {
        :through => 'Agency',
        :by => :code,
        :global => [],
      }.merge(opts)
      
      respond_to?(:prepend_around_action) ? prepend_around_action(:within_request_subdomain) : prepend_around_filter(:within_request_subdomain)
      
      cattr_accessor :subdomain_klass, :subdomain_column, :global_subdomains
      self.subdomain_klass = options[:through].constantize
      self.subdomain_column = options[:by]
      self.global_subdomains = options[:global].is_a?(Array) ? options[:global] : [options[:global]]
      helper_method :current_subdomain
      
      include InstanceMethods
    end
  
    module InstanceMethods
      ##
      # Sets the current subdomain model to the subdomain specified by #request_subdomain.
      #
      def within_request_subdomain
        if self.global_subdomains.include?(request_subdomain) or (self.subdomain_klass.current = request_subdomain)
          yield if block_given?
        else
          raise RestrictedSubdomain::SubdomainNotFound
        end
      ensure
        self.subdomain_klass.current = nil
      end

      ##
      # Use as a before_filter to make sure there's a current_subdomain.
      # Useful if you're using global subdomains - e.g. a certain controller shouldn't be accessible from a global subdomain.
      #
      def require_subdomain
        raise RestrictedSubdomain::SubdomainNotFound if current_subdomain.nil?
      end

      ##
      # Use as a before_filter to make sure there ISN'T a current_subdomain.
      # Useful if you're using global subdomains - e.g. a certain controller shouldn ONLY be accessible from a global subdomain.
      #
      def require_no_subdomain
        raise RestrictedSubdomain::SubdomainNotFound if current_subdomain
      end

      ##
      # Returns the current subdomain model, or nil if none.
      # It respects Agency.each_subdomain, Agency.with_subdomain and Agency.without_subdomain.
      #
      def current_subdomain
        self.subdomain_klass.current
      end
    
      ##
      # Returns a symbol of the current subdomain. So, something like
      # http://secksi.example.com returns :secksi
      #
      def current_subdomain_symbol
        if current_subdomain
          current_subdomain.send(self.subdomain_column).to_sym
        else
          nil
        end
      end
    
      ##
      # Overwrite the default accessor that will force all session access to
      # a subhash keyed on the restricted subdomain symbol. If the current 
      # current subdomain is not set, it gracefully degrades to the normal session.
      #
      def session
        if current_subdomain
          request.session[current_subdomain_symbol] ||= {}
          request.session[current_subdomain_symbol] 
        else
          request.session
        end
      end

      ##
      # Forces all session assignments to a subhash keyed on the current
      # subdomain symbol, if found. Otherwise works just like normal.
      #
      def session=(*args)
        if current_subdomain
          request.session[current_subdomain_symbol] ||= {}
          request.session[current_subdomain_symbol] = args
        else
          request.session = args
        end
      end

      ##
      # Overwrite the default method so that session data from *other*
      # subdomains is kept.
      #
      def reset_session
        if current_subdomain
          copier = lambda { |sess, (key, val)| sess[key] = val unless key == current_subdomain_symbol; sess }
          new_session = request.session.inject({}, &copier)
          super
          new_session.inject(request.session, &copier)
        else
          super
        end
      end

      # Returns the subdomain from the current request. Inspects request.host to figure out
      # the subdomain by splitting on periods and using the first entry. This
      # implies that the subdomain should *never* have a period in the name.
      #
      # It can be useful to override this for testing with Capybara et all.
      #
      def request_subdomain
        request.host.split(/\./).first
      end
    end
  end

  SubdomainNotFound = Class.new(ActiveRecord::RecordNotFound)
end

ActionController::Base.send :extend, RestrictedSubdomain::Controller

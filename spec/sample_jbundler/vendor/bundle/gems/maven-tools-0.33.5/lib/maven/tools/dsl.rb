require 'fileutils'
require 'maven/tools/gemspec_dependencies'
require 'maven/tools/artifact'
require 'maven/tools/jarfile'
require 'maven/tools/versions'

module Maven
  module Tools
    module DSL

      def tesla( &block )
        @model = Model.new
        @model.model_version = '4.0.0'
        @model.name = File.basename( basedir )
        @model.group_id = 'dummy'
        @model.artifact_id = model.name
        @model.version = '0.0.0'
        @context = :project
        nested_block( :project, @model, block ) if block
        result = @model
        @context = nil
        @model = nil
        result
      end

      def maven( val = nil, &block )
        if @context == nil
          tesla( &block )
        else
          @current.maven = val
        end
      end
      
      def model
        @model
      end

      def eval_pom( src, reference_file = '.' )
        @source = reference_file
        eval( src )
      ensure
        @source = nil
        @basedir = nil
      end

      def basedir( basedir = nil )
        @basedir ||= basedir if basedir
        if @source
          @basedir ||= File.directory?( @source ) ? @source : 
            File.dirname( File.expand_path( @source ) )
        end
        @basedir ||= File.expand_path( '.' )
      end

      def artifact( a )
        if a.is_a?( String )
          a = Maven::Tools::Artifact.from_coordinate( a )
        end
        self.send a[:type].to_sym, a
      end

      def source(*args)
        warn "ignore source #{args}" if !(args[0].to_s =~ /^https?:\/\/rubygems.org/) && args[0] != :rubygems
      end

      def ruby( *args )
        # ignore
      end

      def path( *args )
        warn 'path block not implemented'
      end

      def git( *args )
        warn 'git block not implemented'
      end

      def is_jruby_platform( *args )
        args.detect { |a| :jruby == a.to_sym }
      end
      private :is_jruby_platform

      def platforms( *args )
        if is_jruby_platform( *args )
          yield
        end
      end

      def group( *args )
        @group = args[ 0 ]
        yield
      ensure
        @group = nil
      end

      def gemfile( name = 'Gemfile', options = {} )
        if name.is_a? Hash
          options = name
          name = 'Gemfile'
        end
        name = File.join( basedir, name ) unless File.exists?( name )
        basedir = File.dirname( name ) unless basedir

        @gemfile_options = options
        FileUtils.cd( basedir ) do
          eval( File.read( File.expand_path( name ) ) )
        end

        if @gemfile_options
          @gemfile_options = nil
          setup_gem_support( options )
        end

        if @has_path or @has_git
          gem 'bundler', :scope => :provided unless gem? 'bundler'
          jruby_plugin :gem do
            execute_goal :exec, :filename => 'bundle', :args => 'install'
          end
        end
      ensure
        @has_path = nil
        @has_git = nil
      end

      def setup_gem_support( options, spec = nil, config = {} )
        if spec.nil?
          require_path = '.'
          name = File.basename( File.expand_path( '.' ) )
        else
          require_path = spec.require_path
          name = spec.name
        end
        
        unless model.repositories.detect { |r| r.id == 'rubygems-releases' }
          repository( 'http://rubygems-proxy.torquebox.org/releases',
                      :id => 'rubygems-releases' )
        end

        setup_jruby_plugins_version

        if options.key?( :jar ) || options.key?( 'jar' )
          jarpath = options[ :jar ] || options[ 'jar' ]
          if jarpath
            jar = File.basename( jarpath ).sub( /.jar$/, '' )
            output = "#{require_path}/#{jarpath.sub( /#{jar}/, '' )}".sub( /\/$/, '' )
          end
        else
          jar = "#{name}"
          output = "#{require_path}"
        end
        if options.key?( :source ) || options.key?( 'source' )
          source = options[ :source ] || options[ 'source' ]
          build do
            source_directory source
          end
        end
        if jar && ( source || 
                    File.exists?( File.join( basedir, 'src', 'main', 'java' ) ) )
          plugin( :jar, VERSIONS[ :jar_plugin ],
                  :outputDirectory => output,
                  :finalName => jar ) do
            execute_goals :jar, :phase => 'prepare-package'
          end
          plugin( :clean, VERSIONS[ :clean_plugin ],
                  :filesets => [ { :directory => output,
                                   :includes => [ "#{jar}.jar" ] } ] )
        end
      end
      private :setup_gem_support

      def setup_jruby( jruby, jruby_scope = :provided )
        jruby ||= VERSIONS[ :jruby_version ]
        scope( jruby_scope ) do
          if ( jruby < '1.7' )
            warn 'jruby version below 1.7 uses jruby-complete'
            jar 'org.jruby:jruby-core', jruby
          elsif ( jruby < '1.7.5' )
            jar 'org.jruby:jruby-core', jruby
          else
            jar 'org.jruby:jruby', jruby
          end
        end
      end
      private :setup_jruby
      
      def jarfile( file = 'Jarfile', options = {} )
        if file.is_a? Hash 
          options = file
          file = 'Jarfile'
        end
        unless file.is_a?( Maven::Tools::Jarfile )
          file = Maven::Tools::Jarfile.new( File.expand_path( file ) )
        end

        if options[ :skip_locked ] or not file.exists_lock?
          file.populate_unlocked do |dsl|
            setup_jruby( dsl.jruby )
            dsl.artifacts.each do |a|
              dependency a
            end
          end
        else
          file.locked.each do |dep|
            artifact( dep )
          end
          file.populate_unlocked do |dsl|
            setup_jruby( dsl.jruby )
            dsl.artifacts.each do |a|
              if a[ :system_path ]
                dependeny a
              end
            end
          end
        end
      end

      def gemspec( name = nil, options = @gemfile_options || {} )
        unless model.properties.member?( 'project.build.sourceEncoding' )
          properties( 'project.build.sourceEncoding' => 'utf-8' ) 
        end

        @gemfile_options = nil
        if name.is_a? Hash
          options = name
          name = nil
        end
        if name
          name = File.join( basedir, name )
        else name
          gemspecs = Dir[ File.join( basedir, "*.gemspec" ) ]
          raise "more then one gemspec file found" if gemspecs.size > 1
          raise "no gemspec file found" if gemspecs.size == 0
          name = gemspecs.first
        end
        spec = nil
        FileUtils.cd( basedir ) do
          spec = eval( File.read( File.expand_path( name ) ) )
        end

        if @context == :project
          build.directory = '${basedir}/pkg'
          id "rubygems:#{spec.name}:#{spec.version}"
          name( spec.summary || spec.name )
          description spec.description
          packaging 'gem'
          url spec.homepage
          extension 'de.saumya.mojo:gem-extension:${jruby.plugins.version}'
        end

        setup_gem_support( options, spec )
        
        config = { :gemspec => name.sub( /^#{basedir}\/?/, '' ) }
        if options[ :include_jars ] || options[ 'include_jars' ] 
          config[ :includeDependencies ] = true
        end
        plugin( 'de.saumya.mojo:gem-maven-plugin:${jruby.plugins.version}',
                config )
      
        deps = Maven::Tools::GemspecDependencies.new( spec )
        deps.runtime.each do |d|
          gem d
        end
        unless deps.development.empty?
          scope :test do
            deps.development.each do |d|
              gem d
            end          
          end
        end
        unless deps.java_runtime.empty?
          deps.java_runtime.each do |d|
            dependency Maven::Tools::Artifact.new( *d )
          end
        end
      end

      def build( &block )
        build = @current.build ||= Build.new
        nested_block( :build, build, block ) if block
        build
      end

      def organization( *args, &block )
        if @context == :project
          args, options = args_and_options( *args )
          org = ( @current.organization ||= Organization.new )
          org.name = args[ 0 ]
          org.url = args[ 1 ]
          fill_options( org, options )
          nested_block( :organization, org, block ) if block
          org
        else
          @current.organization = args[ 0 ]
        end
      end

      def license( *args, &block )
        args, options = args_and_options( *args )
        license = License.new
        license.name = args[ 0 ]
        license.url = args[ 1 ]
        fill_options( license, options )
        nested_block( :license, license, block ) if block
        @current.licenses << license
        license
      end

      def project( *args, &block )
        raise 'mixed up hierachy' unless @current == model
        args, options = args_and_options( *args )
        @current.name = args[ 0 ]
        @current.url = args[ 1 ]
        fill_options( @current, options )
        nested_block(:project, @current, block) if block
      end

      def id( *args )
        args, options = args_and_options( *args )
        if @context == :project
          # reset version + groupId
          @current.version = nil
          @current.group_id = nil
          fill_gav( @current, *args )
          fill_options( @current, options )
          reduce_id
        else
          @current.id = args[ 0 ]
        end
      end

      def site( url = nil, options = {} )
        site = Site.new
        options.merge!( :url => url )
        fill_options( site, options )
        @current.site = site
      end

      def source_control( url = nil, options = {} )
        scm = Scm.new
        options.merge!( :url => url )
        fill_options( scm, options )
        @current.scm = scm
      end
      alias :scm :source_control

      def issue_management( url, system = nil )
        issues = IssueManagement.new
        issues.url = url
        issues.system = system
        @current.issue_management = issues
        issues
      end

      def mailing_list( *args, &block )
        list = MailingList.new
        args, options = args_and_options( *args )
        list.name = args[ 0 ]
        fill_options( list, options )
        nested_block( :mailing_list, list, block ) if block
        @current.mailing_lists <<  list
        list
      end

      def prerequisites( *args, &block )
        pre = Prerequisites.new
        args, options = args_and_options( *args )
        fill_options( pre, options )
        nested_block( :prerequisites, pre, block ) if block
        @current.prerequisites = pre
        pre
      end

      def archives( *archives )
        @current.archive = archives.shift
        @current.other_archives = archives
      end

      def other_archives( *archives )
        @current.other_archives = archives
      end

      def developer( *args, &block )
        dev = Developer.new
        args, options = args_and_options( *args )
        dev.id = args[ 0 ]
        dev.name = args[ 1 ]
        dev.url = args[ 2 ]
        dev.email = args[ 3 ]
        fill_options( dev, options )
        nested_block( :developer, dev, block ) if block
        @current.developers << dev
        dev
      end

      def contributor( *args, &block )
        con = Contributor.new
        args, options = args_and_options( *args )
        con.name = args[ 0 ]
        con.url = args[ 1 ]
        con.email = args[ 2 ]
        fill_options( con, options )
        nested_block( :contributor, con, block ) if block
        @current.contributors << con
        con
      end
      
      def roles( *roles )
        @current.roles = roles
      end

      def property( options )
        prop = ActivationProperty.new
        prop.name = options[ :name ] || options[ 'name' ]
        prop.value = options[ :value ] || options[ 'value' ]
        @current.property = prop
      end

      def file( options )
        file = ActivationFile.new
        file.missing = options[ :missing ] || options[ 'missing' ]
        file.exists = options[ :exists ] || options[ 'exists' ]
        @current.file = file
      end

      def activation( &block )
        activation = Activation.new
        nested_block( :activation, activation, block ) if block
        @current.activation = activation
      end

      def distribution( val = nil, &block )
        if @context == :license
          @current.distribution = val
        else
          dist = DistributionManagement.new
          nested_block( :distribution, dist, block ) if block
          @current.distribution_management = dist
        end
      end
      alias :distribution_management :distribution

      def includes( *items )
        @current.includes = items.flatten
      end

      def excludes( *items )
        @current.excludes = items.flatten
      end

      def test_resource( &block )
        # strange behaviour when calling specs from Rakefile
        return if @current.nil?
        resource = Resource.new
        nested_block( :resource, resource, block ) if block
        if @context == :project
          ( @current.build ||= Build.new ).test_resources << resource
        else
          @current.test_resources << resource
        end
      end

      def resource( &block )
        resource = Resource.new
        nested_block( :resource, resource, block ) if block
        if @context == :project
          ( @current.build ||= Build.new ).resources << resource
        else
          @current.resources << resource
        end
      end

      def repository( url, options = {}, &block )
        do_repository( :repository=, url, options, block )
      end

      def plugin_repository( url, options = {}, &block )
        do_repository( :plugin, url, options, block )
      end

      def snapshot_repository( url, options = {}, &block )
        do_repository( :snapshot_repository=, url, options, block )
      end

      def releases( config )
        respository_policy( :releases=, config )
      end

      def snapshots( config )
        respository_policy( :snapshots=, config )
      end

      def respository_policy( method, config )
        rp = RepositoryPolicy.new
        case config
        when Hash
          rp.enabled = snapshot[ :enabled ]
          rp.update_policy = snapshot[ :update ]
          rp.checksum_policy = snapshot[ :checksum ]
        when TrueClass
          rp.enabled = true
        when FalseClass
          rp.enabled = false
        else
          rp.enabled = 'true' == config
        end
        @current.send( method, rp )
      end

      def args_and_options( *args )
        if args.last.is_a? Hash
          [ args[0..-2], args.last ]
        else
          [ args, {} ]
        end
      end

      def fill_options( receiver, options )
        options.each do |k,v|
          receiver.send( "#{k}=".to_sym, v )
        end
      end

      def fill( receiver, method, args )
        receiver.send( "#{method}=".to_sym, args )
      rescue
        begin
          old = @current
          @current = receiver
          # assume v is an array
          send( method, *args )
        ensure
          @current = old
        end
      end

      def inherit( *args, &block )
        args, options = args_and_options( *args )
        parent = ( @current.parent = fill_gav( Parent, *args ) )
        fill_options( parent, options )
        nested_block( :parent, parent, block ) if block
        reduce_id
        parent
      end
      alias :parent :inherit

      def properties(props = {})
        props.each do |k,v|
          @current.properties[k.to_s] = v.to_s
        end
        @current.properties
      end

      def extension( *gav )
        @current.build ||= Build.new
        gav = gav.join( ':' )
        ext = fill_gav( Extension, gav)
        @current.build.extensions << ext
        ext
      end

      def setup_jruby_plugins_version
        unless @current.properties.key?( 'jruby.plugins.version' )
          properties( 'jruby.plugins.version' => VERSIONS[ :jruby_plugins ] )
        end
      end

      def jruby_plugin( *gav, &block )
        gav[ 0 ] = "de.saumya.mojo:#{gav[ 0 ]}-maven-plugin"
        if gav.size == 1 || gav[ 1 ].is_a?( Hash )
          setup_jruby_plugins_version
          gav.insert( 1, '${jruby.plugins.version}' )
        end
        plugin( *gav, &block )
      end

      def plugin!( *gav, &block )
        gav, options = plugin_gav( *gav )
        pl = plugins.detect do |p|
          "#{p.group_id}:#{p.artifact_id}:#{p.version}" == gav
        end
        if pl
          do_plugin( false, pl, options, &block )
        else
          plugin = fill_gav( @context == :reporting ? ReportPlugin : Plugin,
                             gav)

          do_plugin( true, plugin, options, &block )
        end
      end

      def plugin_gav( *gav )
        if gav.last.is_a? Hash
          options = gav.last
          gav = gav[ 0..-2 ]
        else
          options = {}
        end
        unless gav.first.match( /:/ )
          gav[ 0 ] = "org.apache.maven.plugins:maven-#{gav.first}-plugin"
        end
        [ gav.join( ':' ), options ]
      end
      private :plugin_gav

      def plugins
        if @current.respond_to? :build
          @current.build ||= Build.new
          if @context == :overrides
            @current.build.plugin_management ||= PluginManagement.new
            @current.build.plugin_management.plugins
          else
            @current.build.plugins
          end
        else
          @current.plugins
        end
      end
      private :plugins

      def plugin( *gav, &block )
        gav, options = plugin_gav( *gav )
        plugin = fill_gav( @context == :reporting ? ReportPlugin : Plugin,
                           gav)

        do_plugin( true, plugin, options, &block )
      end

      def do_plugin( add_plugin, plugin, options, &block )
        set_config( plugin, options )
        plugins << plugin if add_plugin
        nested_block(:plugin, plugin, block) if block
        plugin
      end
      private :do_plugin

      def overrides(&block)
        nested_block(:overrides, @current, block) if block
      end
      alias :plugin_management :overrides
      alias :dependency_management :overrides

      def execute( id = nil, phase = nil, options = {}, &block )
        if block
          raise 'can not be inside a plugin' if @current == :plugin
          if phase.is_a? Hash
            options = phase
          else
            options[ :phase ] = phase
          end
          if id.is_a? Hash
            options = id
          else
            options[ :id ] = id
          end
          options[ :taskId ] = options[ :id ] || options[ 'id' ]
          if @source
            options[ :nativePom ] = File.expand_path( @source ).sub( /#{basedir}./, '' )
          end
	  
          add_execute_task( options, &block )
        else
          # just act like execute_goals
          execute_goals( id )
        end
      end

      # hook for polyglot maven to register those tasks
      def add_execute_task( options, &block )
        plugin!( 'io.tesla.polyglot:tesla-polyglot-maven-plugin',
                 VERSIONS[ :tesla_version ] ) do
          execute_goal( :execute, options )
          
          jar!( 'io.tesla.polyglot:tesla-polyglot-ruby',
                VERSIONS[ :tesla_version ] )
        end
      end

      def retrieve_phase( options )
        if @phase
          if options[ :phase ] || options[ 'phase' ]
            raise 'inside phase block and phase option given'
          end
          @phase
        else
          options.delete( :phase ) || options.delete( 'phase' )
        end
      end
      private :retrieve_phase

      def execute_goal( goal, options = {}, &block )
        if goal.is_a? Hash
          execute_goals( goal, &block )
        else
          execute_goals( goal, options, &block )
        end
      end

      def execute_goals( *goals, &block )
        if goals.last.is_a? Hash
          options = goals.last
          goals = goals[ 0..-2 ]
        else
          options = {}
        end
        exec = Execution.new
        # keep the original default of id
        id = options.delete( :id ) || options.delete( 'id' )
        exec.id = id if id
        exec.phase = retrieve_phase( options )
        exec.goals = goals.collect { |g| g.to_s }
        set_config( exec, options )
        @current.executions << exec
        nested_block(:execution, exec, block) if block
        exec
      end

      def dependency( type, *args )
        do_dependency( false, type, *args )
      end

      def dependency!( type, *args )
        do_dependency( true, type, *args )
      end

      def dependency?( type, *args )
        find_dependency( dependency_container,
                         retrieve_dependency( type, *args ) ) != nil
      end

      def find_dependency( container, dep )
        container.detect do |d|
          dep.group_id == d.group_id && dep.artifact_id == d.artifact_id && dep.classifier == d.classifier
        end
      end
         
      def dependency_set( bang, container, dep )
        if bang
          dd = do_dependency?( container, dep )
          if index = container.index( dd )
            container[ index ] = dep
          else
            container << dep
          end
        else
          container << dep
        end
      end

      def retrieve_dependency( type, *args )
        if args.empty?
          a = type
          type = a[ :type ]
          options = a
        elsif args[ 0 ].is_a?( ::Maven::Tools::Artifact )
          a = args[ 0 ]
          type = a[ :type ]
          options = a
        else
          a = ::Maven::Tools::Artifact.from( type, *args )
        end
        d = fill_gav( Dependency, 
                      a ? a.gav : args.join( ':' ) )
        d.type = type.to_s
        d
      end

      def dependency_container
        if @context == :overrides
          @current.dependency_management ||= DependencyManagement.new
          @current.dependency_management.dependencies
        else
          @current.dependencies
        end
      end

      def do_dependency( bang, type, *args )
        d = retrieve_dependency( type, *args )
        container = dependency_container

        if bang
          dd = find_dependency( container, d )
          if index = container.index( dd )
            container[ index ] = d
          else
            container << d
          end
        else
          container << d
        end

        if args.last.is_a?( Hash )
          options = args.last
        end
        if options || @scope
          options ||= {}
          if @scope
            if options[ :scope ] || options[ 'scope' ]
              raise "scope block and scope option given"
            end
            options[ :scope ] = @scope
          end
          exclusions = options.delete( :exclusions ) ||
            options.delete( "exclusions" )
          case exclusions
          when Array
            exclusions.each do |v|
              d.exclusions << fill_gav( Exclusion, v )
            end
          when String
            d.exclusions << fill_gav( Exclusion, exclusions )
          end
          options.each do |k,v|
            d.send( "#{k}=".to_sym, v ) unless d.send( k.to_sym )
          end
        end
        d
      end

      def scope( name )
        @scope = name
        yield
        @scope = nil
      end

      def phase( name )
        @phase = name
        yield
        @phase = nil
      end

      def profile( id, &block )
        profile = Profile.new
        profile.id = id if id
        @current.profiles << profile
        nested_block( :profile, profile, block ) if block
      end

      def report_set( *reports, &block )
        set = ReportSet.new
        case reports.last
        when Hash
          options = reports.last
          reports = reports[ 0..-2 ]
          id = options.delete( :id ) || options.delete( 'id' )
          set.id = id if id
          inherited = options.delete( :inherited ) ||
            options.delete( 'inherited' )
          set.inherited = inherited if inherited
        end
        set_config( set, options )
        set.reports = reports#.to_java
        @current.report_sets << set
      end

      def reporting( &block )
        reporting = Reporting.new
        @current.reporting = reporting
        nested_block( :reporting, reporting, block ) if block
      end
      
      def gem?( name )
        @current.dependencies.detect do |d|
          d.group_id == 'rubygems' && d.artifact_id == name && d.type == :gem
        end
      end

      def jar!( *args )
        dependency!( :jar, *args )
      end

      def gem( *args )
        do_gem( false, *args )
      end
      
      # TODO useful ?
      def gem!( *args )
        do_gem( true, *args )
      end

      def do_gem( bang, *args )
        # in some setup that gem could overload the Kernel gem
        return if @current.nil?
        unless args[ 0 ].match( /:/ )
          args[ 0 ] = "rubygems:#{args[ 0 ] }"
        end
        if args.last.is_a?(Hash)
          options = args.last
          if options.key?( :git )
            @has_git = true
          elsif options.key?( :path )
            @has_path = true
          else
            platform = options.delete( :platform ) || options.delete( 'platform' )
            group = options.delete( :group ) || options.delete( 'group' ) || @group || nil
             if group
               case group.to_sym
               when :test
                 options[ :scope ] = :test 
               when :development
                 options[ :scope ] = :provided
               end
             end
            if platform.nil? || is_jruby_platform( platform )
              options[ :version ] = '[0,)' if args.size == 2 && options[ :version ].nil? && options[ 'version' ].nil?
              do_dependency( bang, :gem, *args )
            end
          end
        else
          args << { :version => '[0,)' } if args.size == 1
          do_dependency( bang, :gem, *args )
        end
      end

      def local( path, options = {} )
        path = File.expand_path( path )
        dependency( :jar,
                    Maven::Tools::Artifact.new_local( path, :jar, options ) )
      end

      def method_missing( method, *args, &block )
        if @context
          m = "#{method}=".to_sym
          if @current.respond_to? m
            #p @context
            #p m
            #p args
            begin

              if defined?(JRUBY_VERSION) and
                  not RUBY_VERSION =~ /1.8/ and
                  args.size > 1

                @current.send( m, args, &block )

              else
                @current.send( m, *args, &block )
              end
            rescue TypeError
              # assume single argument
              @current.send( m, args[0].to_s, &block )              
            rescue ArgumentError
              begin
                @current.send( m, args )
              rescue ArgumentError => e
                if @current.respond_to? method
                  @current.send( method, *args )
                end
              end
            end
            @current
          else
            if ( args.size > 0 &&
                 args[0].is_a?( String ) &&
                 args[0] =~ /^[${}0-9a-zA-Z._-]+(:[${}0-9a-zA-Z._-]+)+$/ ) ||
                ( args.size == 1 && args[0].is_a?( Hash ) )
              mm = method.to_s
              case mm[ (mm.size - 1)..-1 ]
              when '?'
                dependency?( method.to_s[0..-2].to_sym, *args )
              when '!'
                dependency!( method.to_s[0..-2].to_sym, *args )
              else
                dependency( method, *args )
              end
              # elsif @current.respond_to? method
              #   @current.send( method, *args )
              #   @current
            else
              p @context
              p m
              p args
            end
          end
        else
          super
        end
      end

      def xml( xml )
        raise  'Xpp3DomBuilder.build( java.io.StringReader.new( xml ) )'
      end

      def set_config(  receiver, options )
        receiver.configuration = options
      end

      private

      def do_repository( method, url = nil, options = {}, block = nil )
        if @current.respond_to?( method )
          r = DeploymentRepository.new
        else
          r = Repository.new
        end
        # if config = ( options.delete( :snapshot ) ||
        #               options.delete( 'snapshot' ) )
        #   r.snapshot( repository_policy( config ) )
        # end
        # if config = ( options.delete( :release ) ||
        #               options.delete( 'release' ) )
        #   r.snapshot( repository_policy( config ) )
        # end
        nested_block( :repository, r, block ) if block
        options.merge!( :url => url )
        fill_options( r, options )
        case method
        when :plugin
          @current.plugin_repositories << r
        else
          if @current.respond_to?( method )
            @current.send method, r
          else
            @current.repositories << r
          end
        end
      end

      def reduce_id
        if parent = @current.parent
          @current.version = nil if parent.version == @current.version
          @current.group_id = nil if parent.group_id == @current.group_id
        end
      end

      def nested_block(context, receiver, block)
        old_ctx = @context
        old = @current

        @context = context
        @current = receiver

        block.call

        @current = old
        @context = old_ctx
      end

      def fill_gav(receiver, *gav)
        if receiver.is_a? Class
          receiver = receiver.new
        end
        if gav.size > 0
          gav = gav[0].split(':') if gav.size == 1
          case gav.size
          when 0
            # do nothing - will be filled later
          when 1
            receiver.artifact_id = gav[0]
          when 2
            if gav[ 0 ] =~ /:/
              receiver.group_id, receiver.artifact_id = gav[ 0 ].split /:/
              receiver.version = gav[ 1 ]
            else
              receiver.group_id, receiver.artifact_id = gav
            end
          when 3
            receiver.group_id, receiver.artifact_id, receiver.version = gav
          when 4
            receiver.group_id, receiver.artifact_id, receiver.version, receiver.classifier = gav
          else
            raise "can not assign such an array #{gav.inspect}"
          end
        end
        receiver
      end
    end
  end
end

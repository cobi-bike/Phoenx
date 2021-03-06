module Phoenx

	class TargetBuilder
	
		attr_reader :project
		
		attr_reader :target_spec
		attr_reader :project_spec
		attr_reader :framework_files
		
		def initialize(project, target_spec, project_spec)
			@project = project
			@target_spec = target_spec
			@project_spec = project_spec
			@framework_files = []
		end
		
		def add_support_files
			files = Phoenx.merge_files_array(@target_spec.support_files, @target_spec.excluded_support_files)
			Phoenx.get_or_add_files(@project, files)
		end

		def clean_target
			self.target.frameworks_build_phases.clear
		end
		
		def add_frameworks_and_libraries
			# Add Framework dependencies
			frameworks_group = @project.main_group.find_subpath(FRAMEWORKS_ROOT, true)
			Phoenx.add_groups_for_files(@project,@target_spec.frameworks)
			frameworks = Phoenx.merge_files_array(@target_spec.frameworks)
			frameworks.each do |framework|
				file = Phoenx.get_or_add_file(@project,framework)
				@framework_files << file
				self.target.frameworks_build_phases.add_file_reference(file)
			end
			Phoenx.add_groups_for_files(@project, @target_spec.libraries)
			libraries = Phoenx.merge_files_array(@target_spec.libraries)
			libraries.each do |framework|
				file = Phoenx.get_or_add_file(@project,framework)
				self.target.frameworks_build_phases.add_file_reference(file)
			end
		end
		
		def add_build_phase_scripts
			@target_spec.pre_build_scripts.each do |script|
				phase = self.target.new_shell_script_build_phase(script[:name])
				phase.shell_script = script[:script]
				self.target.build_phases.move(phase, 0)
			end
			@target_spec.post_build_scripts.each do |script|
				phase = self.target.new_shell_script_build_phase(script[:name])
				phase.shell_script = script[:script]
				self.target.build_phases.move(phase, self.target.build_phases.count - 1)
			end
		end
		
		def add_system_dependencies
			# Add Framework dependencies
			@target_spec.system_frameworks.each do |framework|
				self.target.add_system_framework(framework)
			end
			@target_spec.system_libraries.each do |library|
				self.target.add_system_library(library)
			end
		end
		
		def add_resources
			# Add Resource files
			resources = Phoenx.merge_files_array(@target_spec.resources, @target_spec.excluded_resources)
			unless !@target_spec.resources || @target_spec.resources.empty? || !resources.empty?
				puts "No resources found".yellow
			end
			Phoenx.add_groups_for_files(@project, resources)
			resources.each do |source|
				file = nil
				if Phoenx.is_bundle?(source)
					parts = source.split("/")
					group = @project.main_group
					parts.each do |part|
						if Phoenx.is_bundle?(part)
							file = group.find_file_by_path(part)
							unless file != nil
								file = group.new_file(part)
								self.target.resources_build_phase.add_file_reference(file)
							end
							break
						else
							group = group.find_subpath(part, false)
						end
					end
				elsif Phoenx.is_translation_folder?(source)
					parts = source.split("/")
					translation_folder_index = parts.index { |part| Phoenx.is_translation_folder?(part) }
					parent_path = parts[0..translation_folder_index - 1].join('/')
					parent_group = @project.main_group.find_subpath(parent_path)
					base_folder = File.join(parent_path, "Base.lproj", File.basename(source,".*")) + ".{intentdefinition}"
					is_intent = !Dir[base_folder].empty?
					if is_intent
					    group_name = File.basename(Dir[base_folder].first)
					else
					    group_name = File.basename(source)
					end

					variant_group = parent_group[group_name]
					if variant_group == nil
						variant_group = parent_group.new_variant_group(group_name)
					end
					if not is_intent and not self.target.resources_build_phase.include?(variant_group)
						self.target.resources_build_phase.add_file_reference(variant_group)
					end
					if is_intent and not self.target.source_build_phase.include?(variant_group)
						self.target.source_build_phase.add_file_reference(variant_group)
					end
					file_path = parts[translation_folder_index..parts.count].join('/')
					unless variant_group.find_file_by_path(file_path) != nil
						variant_group.new_file(file_path)
					end
				else
					group = @project.main_group.find_subpath(File.dirname(source), false)
					unless group == nil
						file = group.find_file_by_path(File.basename(source))
						unless file != nil
							file = group.new_file(File.basename(source))
							self.target.resources_build_phase.add_file_reference(file)
						end
					end
				end
			end
		end
		
		def add_sources
			# Add Source files
			sources = Phoenx.merge_files_array(@target_spec.sources, @target_spec.excluded_sources)
			unless !@target_spec.sources || @target_spec.sources.empty? || !sources.empty?
				puts "No sources found".yellow
			end
			Phoenx.add_groups_for_files(@project, sources)
			sources.each do |source|
				file = Phoenx.get_or_add_file(@project,source)
				# Add to Compile sources phase
				unless File.extname(source) == ".h" || File.extname(source) == ".pch"
					self.target.add_file_references([file])
				end
			end
		end
		
		def add_config_files
			# Add configuration group
			Phoenx.add_groups_for_files(@project, @target_spec.config_files.values)
			@target_spec.config_files.each do |config,file_name|
				unless file_name == nil
					file = Phoenx.get_or_add_file(@project,file_name)
					configuration = self.target.build_configuration_list[config]
					unless configuration
						abort "Config file assigned to invalid configuration '#{config}' ".red + file_name.bold
					end
					configuration.base_configuration_reference = file
				end
			end
		end
		
		def configure_target
			Phoenx.set_target_build_settings_defaults(self.target)
			Phoenx.set_project_build_settings_defaults(@project)
		end
		
		def build
		
		end
		
		def target
			return nil
		end
	
	end

	class TestableTargetBuilder < TargetBuilder
	
		:test_targets
		:schemes
		
		def generate_target_scheme
			# Generate main scheme
			scheme = Xcodeproj::XCScheme.new
			self.configure_scheme(scheme, @target_spec)
			@target_spec.test_targets.each do |test_target_spec|
				test_target_spec.additional_test_targets.each do |additional_target|
					proj = Phoenx.open_project(additional_target.path)
					target = Phoenx.target_for_name(proj, additional_target.target_name)
					scheme.test_action.add_testable Xcodeproj::XCScheme::TestAction::TestableReference.new(target, @project) if target
				end
			end
			
			@schemes << scheme
			scheme.save_as @project_spec.project_file_name, @target_spec.name
			return scheme
		end
		
		def sort_build_phases
			self.target.build_phases.objects.each do |phase|
				phase.sort
			end
		end
		
		def add_sub_projects
			frameworks_group = @project.main_group.find_subpath(FRAMEWORKS_ROOT,false)
			@target_spec.dependencies.each do |dp|
				proj = nil
				if dp.path == nil
					proj = @project
				else
					abort "Missing dependency ".red + dp.path.bold unless File.exists?(dp.path)
					file_ref = frameworks_group.find_file_by_path(dp.path)
					unless file_ref != nil
						frameworks_group.new_file(dp.path)
					end
					proj = Phoenx.open_project(dp.path)
				end
				target = Phoenx.target_for_name(proj,dp.target_name)
				abort "Missing target for dependency '#{dp.path}' ".red + dp.target_name.bold unless target
				self.target.add_dependency(target)
			end
		end
		
		def add_schemes
			@target_spec.schemes.each do |s|
				scheme = Xcodeproj::XCScheme.new 
				self.configure_scheme(scheme, s)

				@schemes << scheme
				scheme.save_as @project_spec.project_file_name, s.name
			end
		end

		def configure_scheme(scheme, spec, launch_target = true)
			scheme.configure_with_targets(self.target, nil, :launch_target => launch_target)
			@test_targets.each do |test_target|
				scheme.build_action.add_entry Xcodeproj::XCScheme::BuildAction::Entry.new(test_target)
      			scheme.test_action.add_testable Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target)
			end
			scheme.test_action.code_coverage_enabled = @target_spec.code_coverage_enabled

			if spec.archive_configuration
				archive_configuration = self.target.build_configuration_list[spec.archive_configuration]
				unless archive_configuration
					abort "Invalid archive configuration assigned for scheme '#{spec.name}' ".red + s.archive_configuration.bold
				end
				scheme.archive_action.build_configuration = archive_configuration
			end

			if spec.launch_configuration
				launch_configuration = self.target.build_configuration_list[spec.launch_configuration]
				unless launch_configuration
					abort "Invalid launch configuration assigned for scheme '#{spec.name}' ".red + spec.launch_configuration.bold
				end
				scheme.launch_action.build_configuration = launch_configuration
			end

			if spec.analyze_configuration
				analyze_configuration = self.target.build_configuration_list[spec.analyze_configuration]
				unless analyze_configuration
					abort "Invalid analyze configuration assigned for scheme '#{spec.name}' ".red + spec.analyze_configuration.bold
				end
				scheme.analyze_action.build_configuration = analyze_configuration
			end

			if spec.profile_configuration
				profile_configuration = self.target.build_configuration_list[spec.profile_configuration]
				unless profile_configuration
					abort "Invalid profile configuration assigned for scheme '#{spec.name}' ".red + spec.profile_configuration.bold
				end
				scheme.profile_action.build_configuration = profile_configuration
			end
		end
		
		def add_test_targets
			@target_spec.test_targets.each do |test_target_spec|
				builder = TestTargetBuilder.new(@target, @project, test_target_spec, @project_spec, @target_spec, self.framework_files)
				builder.build
				@test_targets << builder.target
			end	
		end
		
		def build
			@schemes = []
			@test_targets = []
			puts ">> Target ".green + @target_spec.name.bold
			self.clean_target
			self.add_sub_projects
			self.add_sources
			Phoenx::Target::HeaderBuilder.new(@project, @target, @target_spec).build
			self.add_resources
			self.add_config_files
			self.add_system_dependencies
			self.add_frameworks_and_libraries
			self.add_build_phase_scripts
			self.add_test_targets
			self.generate_target_scheme
			self.add_schemes
			self.add_support_files
			self.sort_build_phases
			self.configure_target
		end
	
	end
	
	class ApplicationTargetBuilder < TestableTargetBuilder
		:target
		:copy_frameworks
		
		def add_sub_projects
			super
			frameworks_group = @project.main_group.find_subpath(FRAMEWORKS_ROOT,false)
			@target_spec.dependencies.each do |dp|
				file = nil
				if dp.embed == false
					next
				end
				if dp.path == nil
					# Copy internal references
					target = Phoenx.target_for_name(@project,dp.target_name)
					build_file = @copy_frameworks.add_file_reference(target.product_reference)
					build_file.settings = ATTRIBUTES_CODE_SIGN_ON_COPY
				else
					# Copy external products
					proj_file = frameworks_group.find_file_by_path(dp.path)
					proj = Phoenx.open_project(dp.path)
					target = Phoenx.target_for_name(proj,dp.target_name)
					proj_file.file_reference_proxies.each do |e|
						if e.remote_ref.remote_global_id_string == target.product_reference.uuid
							build_file = @copy_frameworks.add_file_reference(e)
							build_file.settings = ATTRIBUTES_CODE_SIGN_ON_COPY
						end
					end
				end
			end
		end

		def add_watch_targets
			return if @target_spec.watch_apps.empty?

			embed_watch_app_build_phase = @target.new_copy_files_build_phase "Embed Watch Content"
			embed_watch_app_build_phase.symbol_dst_subfolder_spec = :products_directory
			embed_watch_app_build_phase.dst_path = "$(CONTENTS_FOLDER_PATH)/Watch"

			@target_spec.watch_apps.each do |watch_app_spec|
				builder = WatchTargetBuilder.new @project, watch_app_spec, @project_spec
				builder.build
				@target.add_dependency(builder.target)

				file = @project.products_group.find_file_by_path(watch_app_spec.name + '.' + APP_EXTENSION)
				embed_watch_app_build_phase.add_file_reference(file)

				builder.schemes.each do |scheme|
					scheme.add_build_target(@target, true)
					scheme.save!
				end
			end	
		end

		def add_extension_targets
			return if @target_spec.extensions.empty?

			embed_extension_build_phase = @target.new_copy_files_build_phase "Embed App Extensions"
			embed_extension_build_phase.symbol_dst_subfolder_spec = :plug_ins

			@target_spec.extensions.each do |extension_target_spec|
				extension_target_spec.target_type = :app_extension
				extension_target_spec.platform = self.target_spec.platform
				extension_target_spec.version = self.target_spec.version
				builder = ExtensionTargetBuilder.new @project, extension_target_spec, @project_spec
				builder.build
				@target.add_dependency(builder.target)

				file = @project.products_group.find_file_by_path(extension_target_spec.name + '.' + EXTENSION_EXTENSION)
				embed_extension_build_phase.add_file_reference(file)

				builder.schemes.each do |scheme|
					scheme.add_build_target(@target, true)
					scheme.save!
				end
			end	
		end

		def build
			@target = @project.new_target(@target_spec.target_type, @target_spec.name, @target_spec.platform, @target_spec.version)
			@copy_frameworks = @target.new_copy_files_build_phase "Embed Frameworks"
			@copy_frameworks.symbol_dst_subfolder_spec = :frameworks
			super()
			self.add_watch_targets
			self.add_extension_targets
			self.framework_files.each do |file|
				build_file = @copy_frameworks.add_file_reference(file)
				build_file.settings = ATTRIBUTES_CODE_SIGN_ON_COPY
			end
		end
		
		def target
			return @target
		end
	
		def schemes
			return @schemes
		end

	end
	
	class FrameworkTargetBuilder < TestableTargetBuilder
		:target
	
		def build
			@target = @project.new_target(@target_spec.target_type, @target_spec.name, @target_spec.platform, @target_spec.version)
			super()
		end
		
		def target
			return @target
		end
	
	end

	class WatchTargetBuilder < TestableTargetBuilder
		:target

		def validate
			unless @target_spec.target_type == :watch_app or @target_spec.target_type == :watch2_app
				abort "Watch target '#{@target_spec.name}' has to be of type :watch_app or :watch2_app".red
			end
		end
	
		def generate_target_scheme
			# Generate main scheme
			scheme = Xcodeproj::XCScheme.new 
			scheme.build_action.add_entry Xcodeproj::XCScheme::BuildAction::Entry.new(@target)
			scheme.launch_action.buildable_product_runnable = Xcodeproj::XCScheme::RemoteRunnable.new(@target, 2, 'com.apple.Carousel')
      		scheme.profile_action.buildable_product_runnable = Xcodeproj::XCScheme::RemoteRunnable.new(@target, 2, 'com.apple.Carousel')

			self.configure_scheme(scheme, @target_spec, false)
			
			@schemes << scheme
			scheme.save_as @project_spec.project_file_name, @target_spec.name, false
			return scheme
		end

		def add_extension_targets
			embed_extension_build_phase = @target.new_copy_files_build_phase "Embed App Extensions"
			embed_extension_build_phase.symbol_dst_subfolder_spec = :plug_ins

			@target_spec.extensions.each do |extension_target_spec|
				extension_target_spec.target_type = @target_spec.target_type == :watch2_app ? :watch2_extension : :watch_extension
				extension_target_spec.platform = self.target_spec.platform
				extension_target_spec.version = self.target_spec.version
				builder = ExtensionTargetBuilder.new @project, extension_target_spec, @project_spec
				builder.build
				@target.add_dependency(builder.target)

				file = @project.products_group.find_file_by_path(extension_target_spec.name + '.' + EXTENSION_EXTENSION)
				embed_extension_build_phase.add_file_reference(file)
			end	
		end

		def build
			self.validate
			@target = @project.new_target(@target_spec.target_type, @target_spec.name, @target_spec.platform, @target_spec.version)
			super()
			self.add_extension_targets
		end
		
		def target
			return @target
		end

		def schemes
			return @schemes
		end
	
	end

	class ExtensionTargetBuilder < ApplicationTargetBuilder
		:target

		def generate_target_scheme
			scheme = super
			scheme.launch_action.launch_automatically_substyle = "2"
			scheme.save!
			return scheme
		end

		def build
			super
		end
		
		def target
			return @target
		end
	
		def schemes
			return @schemes
		end

	end

	class TestTargetBuilder < TargetBuilder
		:target
		:main_target
		:main_target_spec
		:main_target_frameworks_files
		
		def initialize(main_target, project, target_spec, project_spec, main_target_spec, main_target_frameworks_files)
			super(project, target_spec, project_spec)
			@main_target = main_target
			@main_target_spec = main_target_spec
			@main_target_frameworks_files = main_target_frameworks_files
		end
	
		def build
			@target = @project.new(Xcodeproj::Project::PBXNativeTarget)
			@project.targets << @target
			@target.name = @target_spec.name
			@target.product_name = @target_spec.name
			if @target_spec.type == :ui_test
				@target.product_type = Xcodeproj::Constants::PRODUCT_TYPE_UTI[:ui_test_bundle]
			else
				@target.product_type = Xcodeproj::Constants::PRODUCT_TYPE_UTI[:unit_test_bundle]
			end
			@target.build_configuration_list = Xcodeproj::Project::ProjectHelper.configuration_list(@project, @main_target_spec.platform, @main_target_spec.version)
			product_ref = @project.products_group.new_reference(@target_spec.name + '.' + XCTEST_EXTENSION, :built_products)
			product_ref.include_in_index = '0'
			product_ref.set_explicit_file_type
			@target.product_reference = product_ref
			@target.build_phases << @project.new(Xcodeproj::Project::PBXSourcesBuildPhase)
			@target.build_phases << @project.new(Xcodeproj::Project::PBXFrameworksBuildPhase)
			@target.build_phases << @project.new(Xcodeproj::Project::PBXResourcesBuildPhase)
			self.clean_target
			self.add_sources
			self.add_config_files
			self.add_frameworks_and_libraries
			self.add_system_dependencies
			self.add_build_phase_scripts
			self.add_resources
			self.add_support_files
			copy_frameworks = @target.new_copy_files_build_phase "Embed Frameworks"
			copy_frameworks.symbol_dst_subfolder_spec = :frameworks
			frameworks_group = @project.main_group.find_subpath(FRAMEWORKS_ROOT, false)
			self.framework_files.each do |file|
				build_file = copy_frameworks.add_file_reference(file)
				build_file.settings = ATTRIBUTES_CODE_SIGN_ON_COPY
			end
			@main_target_frameworks_files.each do |file|
				build_file = copy_frameworks.add_file_reference(file)
				build_file.settings = ATTRIBUTES_CODE_SIGN_ON_COPY
			end
			# Add target dependency.
			@target.add_dependency(@main_target)
			@target.frameworks_build_phase.add_file_reference(@main_target.product_reference)
			self.configure_target
		end
		
		def target
			return @target
		end
	
	end

end
require 'xcodeproj'

module Phoenx

	def Phoenx.is_bundle?(file)
		return file.include?('xcassets') || file.include?('bundle') || file.include?('playground')
	end

	def Phoenx.is_translation_folder?(file)
		return file.include?('lproj')
	end

	def Phoenx.add_groups_for_files(project,files)
		files.each do |path|
			abort "Missing file ".red + path.bold unless File.exists?(path)
			groups = File.dirname(path).split("/")
			concate = ""
			groups.each do |g|
				if Phoenx.is_bundle?(g) || Phoenx.is_translation_folder?(g)
					break
				end
				concate +=  g + "/"
				group_ref = project.main_group.find_subpath(concate, true)
				group_ref.set_path(g)
			end
		end
	end
	
	def Phoenx.get_or_add_files(project, files)
		resources = Phoenx.merge_files_array(files)
		Phoenx.add_groups_for_files(project, resources)
		resources.each do |source|
			Phoenx.get_or_add_file(project,source)
		end
	end
	
	def Phoenx.get_or_add_file(project,file)
		abort "Missing file ".red + path.bold unless File.exists?(file)
		filename = File.basename(file)
		dir = File.dirname(file)
		group = project.main_group.find_subpath(dir, false)
		file_ref = group.find_file_by_path(filename)
		unless file_ref != nil
			file_ref = group.new_file(filename)
		end	
		return file_ref
	
	end
	
	def Phoenx.set_target_build_settings_defaults(target)
		target.build_configuration_list.build_configurations.each do |config|
			config.build_settings = {}
		end
	end
	
	def Phoenx.set_project_build_settings_defaults(project)
		project.build_configuration_list.build_configurations.each do |config|
			config.build_settings = {}
		end
	end
	
	def Phoenx.target_for_name(project,name)
		project.targets.each do |t|
			if t.name == name
				return t
			end
		end
		return nil
	end

	$global_project_cache = Hash.new

	def Phoenx.open_project(path)
		name = path.split('/').last 
		if $global_project_cache.key?(name)
			return $global_project_cache[name]
		end
		project = Xcodeproj::Project::open(path)
		$global_project_cache[name] = project
		return project
	end

	def Phoenx.create_project(name)
		project = Xcodeproj::Project::new(name)
		$global_project_cache[name] = project
		return project
	end

end
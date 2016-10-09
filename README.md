[![Gem Version](https://badge.fury.io/rb/phoenx.svg)](https://badge.fury.io/rb/phoenx)
[![Build Status](https://travis-ci.org/jensmeder/Phoenx.svg?branch=master)](https://travis-ci.org/jensmeder/Phoenx)
[![codecov.io](https://codecov.io/github/jensmeder/Phoenx/coverage.svg?branch=master)](https://codecov.io/github/jensmeder/Phoenx?branch=master)

# Phoenx

Phoenx generates Xcode projects (`*.xcodeproj`) and workspaces (`*.xcworkspace`) for iOS, OSX, and tvOS using specification and xcconfig files. Specify your project once and never worry about broken Xcode projects or merge conflicts in pbxproj files ever again. 

#### Example

```ruby

Phoenx::Project.new do |s|
		
	s.project_name = "DarkLightning"
	
	# Set up project wide xcconfig files
	
	s.config_files["Debug"] = "Configuration/Shared/debug.xcconfig"
	s.config_files["Release"] = "Configuration/Shared/release.xcconfig"
	
	# Add a new OSX framework target
	
	s.target "OSX", :framework, :osx, '10.11' do |target|
	
		target.config_files["Debug"] = "Configuration/OSX/debug.xcconfig"
		target.config_files["Release"] = "Configuration/OSX/release.xcconfig"
		
		# Add files to target
		
		target.support_files = ["Configuration/**/*.{xcconfig,plist}"]
		target.sources = "Source/Sockets/**/*.{h,m}", "Source/USB/**/*.{h,m,c}","Source/PacketProtocol/**/*.{h,m}", "Source/Internal/**/*.{h,m}"
		target.public_headers = "Source/OSX/**/*.{h}","Source/USB/*.{h}","Source/PacketProtocol/**/*.{h}","Source/USB/Connections/**/*.{h}"
		target.private_headers = ["Source/Sockets/**/*.{h}", "Source/USB/USBMux/**/*.{h}"]
		
		# Add a unit test target
		
		target.test_target "OSX-Tests" do |t|
		
			t.sources = ["Tests/**/*.{h,m,c}"]
			t.frameworks = ["Frameworks/Kiwi/Kiwi.framework"]
			t.config_files["Debug"] = "Configuration/OSXTests/debug.xcconfig"
			t.config_files["Release"] = "Configuration/OSXTests/release.xcconfig"
		
		end
	
	end

end

```

## Overview

1. [Features](README.md#1-features)
2. [Requirements](README.md#2-requirements)
3. [Installation](README.md#3-installation)
4. [Documentation](README.md#4-documentation)
5. [Credits](README.md#5-credits)
6. [License](README.md#6-license)

## 1. Features

* non intrusive: If you decide to skip using Phoenx there is no need to change anything in your projects or workspaces. 
* extract build settings from xcodeproj to xcconfig files
* generate xcodeproj and xcworkspace files using `pxproject` and `pxworkspace` specification files

## 2. Requirements

* Ruby 2.0.0 or higher
* Xcode 7 or higher

## 3. Installation

Phoenx is built with Ruby and can be installed via ruby gems. If you use the default Ruby installation on Mac OS X, `gem install` can require you to use `sudo` when installing gems. 

```ruby
$ gem install phoenx
```

## 4. Documentation

## 5. Credits

## 6. License

The MIT License (MIT)

Copyright (c) 2016 Jens Meder

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

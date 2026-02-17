#!/usr/bin/env ruby

require 'fileutils'
require 'xcodeproj'

PROJECT_NAME = 'macfuseGui'
PROJECT_PATH = "#{PROJECT_NAME}.xcodeproj"

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes['TargetAttributes'] ||= {}

app_target = project.new_target(:application, PROJECT_NAME, :osx, '13.0')
test_target = project.new_target(:unit_test_bundle, "#{PROJECT_NAME}Tests", :osx, '13.0')
test_target.add_dependency(app_target)

app_target.product_reference.name = "#{PROJECT_NAME}.app"
test_target.product_reference.name = "#{PROJECT_NAME}Tests.xctest"

project.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.9'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'NO'
end

app_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.visualweb.macfusegui'
  config.build_settings['INFOPLIST_FILE'] = 'macfuseGui/Resources/Info.plist'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/../Frameworks'
  config.build_settings['SWIFT_OBJC_BRIDGING_HEADER'] = 'macfuseGui/Resources/macfuseGui-Bridging-Header.h'
  config.build_settings['HEADER_SEARCH_PATHS'] = [
    '$(inherited)',
    '$(SRCROOT)/macfuseGui/Services/Browser',
    '$(SRCROOT)/build/third_party/libssh2/include',
    '/opt/homebrew/opt/libssh2/include',
    '/usr/local/opt/libssh2/include'
  ]
  config.build_settings['LIBRARY_SEARCH_PATHS'] = [
    '$(inherited)',
    '$(SRCROOT)/build/third_party/libssh2/lib',
    '/opt/homebrew/opt/libssh2/lib',
    '/usr/local/opt/libssh2/lib',
    '/opt/homebrew/opt/openssl@3/lib',
    '/usr/local/opt/openssl@3/lib'
  ]
  config.build_settings['OTHER_LDFLAGS'] = '$(inherited) -lssh2 -lcrypto -lz'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['PRODUCT_NAME'] = PROJECT_NAME
  config.build_settings['SWIFT_VERSION'] = '5.9'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
end

# macOS app unit tests are hosted by the app executable.
test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.visualweb.macfusegui.tests'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/macfuseGui.app/Contents/MacOS/macfuseGui'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @loader_path/../Frameworks @executable_path/../Frameworks'
  config.build_settings['SWIFT_VERSION'] = '5.9'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
end

main_group = project.main_group
app_group = main_group.new_group(PROJECT_NAME, PROJECT_NAME)

app_subgroups = {
  'App' => app_group.new_group('App', 'App'),
  'Models' => app_group.new_group('Models', 'Models'),
  'Services' => app_group.new_group('Services', 'Services'),
  'ViewModels' => app_group.new_group('ViewModels', 'ViewModels'),
  'Views' => app_group.new_group('Views', 'Views'),
  'MenuBar' => app_group.new_group('MenuBar', 'MenuBar'),
  'Resources' => app_group.new_group('Resources', 'Resources')
}

source_extensions = %w[.swift .c .m .mm]
header_extensions = %w[.h]
resource_globs = [
  'macfuseGui/Resources/**/*.xcassets'
]

source_files = Dir.glob('macfuseGui/{App,Models,Services,ViewModels,Views,MenuBar}/**/*')
  .select { |path| File.file?(path) && source_extensions.include?(File.extname(path)) }
  .sort

header_files = Dir.glob('macfuseGui/{App,Models,Services,ViewModels,Views,MenuBar}/**/*')
  .select { |path| File.file?(path) && header_extensions.include?(File.extname(path)) }
  .sort

resource_files = resource_globs.flat_map { |glob| Dir.glob(glob) }
  .select { |path| File.exist?(path) }
  .uniq
  .sort

source_files.each do |path|
  subgroup_name = path.split('/')[1]
  subgroup = app_subgroups[subgroup_name] || app_group
  relative_path = path.split('/')[2..].join('/')
  file_ref = subgroup.new_file(relative_path)
  app_target.add_file_references([file_ref])
end

header_files.each do |path|
  subgroup_name = path.split('/')[1]
  subgroup = app_subgroups[subgroup_name] || app_group
  relative_path = path.split('/')[2..].join('/')
  subgroup.new_file(relative_path)
end

resource_files.each do |path|
  subgroup_name = path.split('/')[1]
  subgroup = app_subgroups[subgroup_name] || app_group
  relative_path = path.split('/')[2..].join('/')
  file_ref = subgroup.new_file(relative_path)
  app_target.resources_build_phase.add_file_reference(file_ref, true)
end

info_file = app_subgroups['Resources'].new_file('Info.plist')

# Ensure Info.plist is visible in project navigator but not copied as a runtime resource.
app_target.resources_build_phase.files_references.delete(info_file)

tests_group = main_group.new_group("#{PROJECT_NAME}Tests", "#{PROJECT_NAME}Tests")

test_files = Dir.glob('macfuseGuiTests/**/*.swift').select { |path| File.file?(path) }.sort

test_files.each do |path|
  file_ref = tests_group.new_file(path.sub('macfuseGuiTests/', ''))
  test_target.add_file_references([file_ref])
end

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.add_test_target(test_target)
scheme.set_launch_target(app_target)
scheme.save_as(PROJECT_PATH, PROJECT_NAME, true)

project.save

workspace_dir = File.join(PROJECT_PATH, 'project.xcworkspace')
FileUtils.mkdir_p(workspace_dir)
File.write(
  File.join(workspace_dir, 'contents.xcworkspacedata'),
  <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <Workspace version = "1.0">
      <FileRef location = "self:"/>
    </Workspace>
  XML
)

puts "Generated #{PROJECT_PATH}"

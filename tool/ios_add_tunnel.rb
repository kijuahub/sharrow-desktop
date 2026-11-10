# Adds the PacketTunnel Network Extension target to ios/Runner.xcodeproj.
# Run on macOS after `tool/fetch_core.sh ios`:  ruby tool/ios_add_tunnel.rb
# Requires the xcodeproj gem (bundled with CocoaPods).
require 'xcodeproj'

root = File.expand_path('..', __dir__)
ios = File.join(root, 'ios')
project = Xcodeproj::Project.open(File.join(ios, 'Runner.xcodeproj'))
exit 0 if project.targets.any? { |t| t.name == 'PacketTunnel' }

version = File.read(File.join(root, 'pubspec.yaml'))[/^version:\s*([^\s+]+)(?:\+(\d+))?/]
name, build = $1, ($2 || '1')

runner = project.targets.find { |t| t.name == 'Runner' }
app_id = runner.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER']

ext = project.new_target(:app_extension, 'PacketTunnel', :ios, '15.0', nil, :swift)

group = project.main_group.find_subpath('PacketTunnel', true)
group.set_source_tree('<group>')
group.set_path('PacketTunnel')
ext.add_file_references([group.new_reference('PacketTunnelProvider.swift')])
group.new_reference('Info.plist')
group.new_reference('PacketTunnel.entitlements')
Dir[File.join(ios, 'PacketTunnel', 'Resources', '*.dat')].sort.each do |f|
  ext.add_resources([group.new_reference("Resources/#{File.basename(f)}")])
end

libxray = project.frameworks_group.new_reference('Frameworks/LibXray.xcframework')
libxray.set_source_tree('<group>')
ext.frameworks_build_phase.add_file_reference(libxray)
ext.add_system_framework('NetworkExtension')

ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{app_id}.PacketTunnel"
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = 'PacketTunnel/Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = 'PacketTunnel/PacketTunnel.entitlements'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['SWIFT_VERSION'] = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['SKIP_INSTALL'] = 'YES'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['MARKETING_VERSION'] = name
  s['CURRENT_PROJECT_VERSION'] = build
  s['FRAMEWORK_SEARCH_PATHS'] = ['$(inherited)', '$(PROJECT_DIR)/Frameworks']
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['OTHER_LDFLAGS'] = ['$(inherited)', '-lresolv']
end

runner.build_configurations.each { |c| c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements' }
project.main_group.find_subpath('Runner', false)&.new_reference('Runner.entitlements')

runner.add_dependency(ext)
embed = runner.new_copy_files_build_phase('Embed App Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(ext.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# Embedding after Flutter's "Thin Binary" script creates a build cycle.
runner.build_phases.delete(embed)
thin = runner.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
runner.build_phases.insert(thin || runner.build_phases.size, embed)

project.save
puts "PacketTunnel target added (#{app_id}.PacketTunnel, #{name}+#{build})"

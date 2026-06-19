#!/usr/bin/env ruby
require 'xcodeproj'

PROJECT_NAME = 'bt-kbd'
proj = Xcodeproj::Project.new("#{PROJECT_NAME}.xcodeproj")

SHARED_FILES = Dir['Shared/*.swift'].sort

# ── Shared group ──────────────────────────────────────────────────────────────
shared_group = proj.main_group.new_group('Shared', 'Shared')
shared_refs  = SHARED_FILES.map { |p| shared_group.new_file(File.basename(p)) }

# ── Helper ────────────────────────────────────────────────────────────────────
def add_shared(target, refs)
  refs.each { |r| target.source_build_phase.add_file_reference(r) }
end

# ── macOS app ─────────────────────────────────────────────────────────────────
mac_target = proj.new_target(:application, 'bt-kbd-Mac', :osx, '13.0')
mac_group  = proj.main_group.new_group('bt-kbd-Mac', 'bt-kbd-Mac')

Dir['bt-kbd-Mac/*.swift'].sort.each do |path|
  ref = mac_group.new_file(File.basename(path))
  mac_target.source_build_phase.add_file_reference(ref)
end
add_shared(mac_target, shared_refs)

mac_target.build_configurations.each do |c|
  c.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.btkbd.mac',
    'PRODUCT_NAME'              => 'bt-kbd',
    'SWIFT_VERSION'             => '5.9',
    'MACOSX_DEPLOYMENT_TARGET'  => '13.0',
    'INFOPLIST_FILE'            => 'bt-kbd-Mac/Info.plist',
    'CODE_SIGN_ENTITLEMENTS'    => 'bt-kbd-Mac/bt-kbd-Mac.entitlements',
    'ENABLE_HARDENED_RUNTIME'   => 'YES',
    'LD_RUNPATH_SEARCH_PATHS'   => '$(inherited) @executable_path/../Frameworks',
  })
end

# ── iOS companion app ─────────────────────────────────────────────────────────
ios_target = proj.new_target(:application, 'bt-kbd-iOS', :ios, '16.0')
ios_group  = proj.main_group.new_group('bt-kbd-iOS', 'bt-kbd-iOS')

Dir['bt-kbd-iOS/*.swift'].sort.each do |path|
  ref = ios_group.new_file(File.basename(path))
  ios_target.source_build_phase.add_file_reference(ref)
end

ios_target.build_configurations.each do |c|
  c.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER'  => 'com.btkbd.ios',
    'PRODUCT_NAME'               => 'bt-kbd',
    'SWIFT_VERSION'              => '5.9',
    'IPHONEOS_DEPLOYMENT_TARGET' => '16.0',
    'INFOPLIST_FILE'             => 'bt-kbd-iOS/Info.plist',
    'TARGETED_DEVICE_FAMILY'     => '1',
    'LD_RUNPATH_SEARCH_PATHS'    => '$(inherited) @executable_path/Frameworks',
  })
end

# ── iOS keyboard extension ────────────────────────────────────────────────────
kb_target = proj.new_target(:app_extension, 'bt-kbd-Keyboard', :ios, '16.0')
kb_group  = proj.main_group.new_group('bt-kbd-Keyboard', 'bt-kbd-Keyboard')

Dir['bt-kbd-Keyboard/*.swift'].sort.each do |path|
  ref = kb_group.new_file(File.basename(path))
  kb_target.source_build_phase.add_file_reference(ref)
end
add_shared(kb_target, shared_refs)

kb_target.build_configurations.each do |c|
  c.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER'  => 'com.btkbd.ios.keyboard',
    'PRODUCT_NAME'               => 'bt-kbd-Keyboard',
    'SWIFT_VERSION'              => '5.9',
    'IPHONEOS_DEPLOYMENT_TARGET' => '16.0',
    'INFOPLIST_FILE'             => 'bt-kbd-Keyboard/Info.plist',
    'TARGETED_DEVICE_FAMILY'     => '1',
    'LD_RUNPATH_SEARCH_PATHS'    => '$(inherited) @executable_path/../../Frameworks',
  })
end

# Make iOS app depend on the keyboard extension and embed it
ios_target.add_dependency(kb_target)

embed = ios_target.new_copy_files_build_phase('Embed App Extensions')
embed.dst_subfolder_spec = '13'
bf = embed.add_file_reference(kb_target.product_reference)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

proj.save
puts "Generated #{PROJECT_NAME}.xcodeproj"

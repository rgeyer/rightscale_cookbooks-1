#
# Cookbook Name:: block_device
#
# Copyright RightScale, Inc. All rights reserved.  All access and use subject to the
# RightScale Terms of Service available at http://www.rightscale.com/terms.php and,
# if applicable, other agreements such as a RightScale Master Subscription Agreement.

rightscale_marker :begin

class Chef::Recipe
  include RightScale::BlockDeviceHelper
end

class Chef::Resource::BlockDevice
  include RightScale::BlockDeviceHelper
end

do_for_block_devices node[:block_device] do |device|
  log "  Attempting to restore from backup or create a blank block device for device #{device}..."
  lineage = get_device_or_default(node, device, :backup, :lineage)
  lineage_override = get_device_or_default(node, device, :backup, :lineage_override)
  restore_lineage = lineage_override == nil || lineage_override.empty? ? lineage : lineage_override
  restore_timestamp_override = get_device_or_default(node, device, :backup, :timestamp_override)
  log "  Input lineage #{restore_lineage.inspect}"
  log "  Input lineage_override #{lineage_override.inspect}"
  log "  Using lineage #{restore_lineage.inspect}"
  log "  Input timestamp_override #{restore_timestamp_override.inspect}"
  restore_timestamp_override ||= ""
  restore_or_create_action = nil
  restore_sources = node[:block_device][:devices][:restore_source][:preferred_order]

  bd = block_device get_device_or_default(node, device, :nickname) do
    lineage restore_lineage
    timestamp_override restore_timestamp_override

    secondary_cloud get_device_or_default(node, device, :backup, :secondary, :cloud)
    secondary_endpoint get_device_or_default(node, device, :backup, :secondary, :endpoint)
    secondary_container get_device_or_default(node, device, :backup, :secondary, :container)
    secondary_user get_device_or_default(node, device, :backup, :secondary, :cred, :user)
    secondary_secret get_device_or_default(node, device, :backup, :secondary, :cred, :secret)

    action :nothing
  end

  backups = bd.run_action(:list_backups)
  log "  Found the following backups for device #{device}..."
  log "  #{JSON::pretty_generate(backups)}"

  # Remove ignored restore sources from the preferred source/order list.
  get_device_or_default(node, device, :restore_source, :ignore).each do |restore_ignore|
    restore_sources.delete(restore_ignore.to_sym)
  end

  log "  Going to attempt to restore/create in this order... #{JSON::pretty_generate(restore_sources)}"

  restore_sources.each do |restore_source|
    if restore_source == 'create'
      # Create should always be the last option in the :preferred_order array.
      # Therefore there's no need to break out of the loop here
      log "  Creating a new block device for device #{device}"
      restore_or_create_action = :create
    else
      log "  Attempting to restore from #{restore_source} for device #{device}"
      if backups[restore_source.to_sym] && backups[restore_source.to_sym][:backups].count > 0
        restore_or_create_action = "#{restore_source}_restore".to_sym
        break
      else
        log "  There were no backups in #{restore_source} to restore from for device #{device}"
      end
    end
  end

  raise "Unable to restore or create a block device.  Perhaps there are no suitable backups and you excluded \"create\" from the restore sources?" unless restore_or_create_action

  log "  Choose to take the following restore action: #{restore_or_create_action}"

  bd.run_action(restore_or_create_action)

end

rightscale_marker :end

#
# Cookbook Name:: db
#
# Copyright RightScale, Inc. All rights reserved.  All access and use subject to the
# RightScale Terms of Service available at http://www.rightscale.com/terms.php and,
# if applicable, other agreements such as a RightScale Master Subscription Agreement.

rightscale_marker :begin

if node[:db][:init_slave_at_boot] == "true"
  log "  Initializing slave at boot..."
  include_recipe "db::do_primary_init_slave"
else
  log "  Initialize slave at boot [skipped]"
end
rightscale_marker :end

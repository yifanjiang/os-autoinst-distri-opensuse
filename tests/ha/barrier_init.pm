# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initialize barriers used in HA cluster tests
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use mmapi;

# This tells the module whether the test is running in a supportserver or in node1
sub is_not_supportserver_scenario {
    return (get_var('HOSTNAME') =~ /node01$/ and !get_var('USE_SUPPORT_SERVER'));
}

sub run {
    my $cluster_infos = get_required_var('CLUSTER_INFOS');

    for my $cluster_info (split(/,/, $cluster_infos)) {
        # The CLUSTER_INFOS variable for support_server also contains the number of node
        my ($cluster_name, $num_nodes) = split(/:/, $cluster_info);

        # Number of node is a mandatory variable!
        die 'A valid number of nodes is mandatory' if ($num_nodes lt '2');

        # Create mutex for HA clusters
        mutex_create 'csync2';
        mutex_create 'cluster_restart';

        # BARRIER_HA_ needs to also wait the support-server
        if (is_not_supportserver_scenario) {
            mutex_create 'iscsi';
            barrier_create("BARRIER_HA_$cluster_name",                       $num_nodes);
            barrier_create("BARRIER_HA_NFS_SUPPORT_DIR_SETUP_$cluster_name", $num_nodes);
            barrier_create("BARRIER_HA_HOSTS_FILES_READY_$cluster_name",     $num_nodes);
            barrier_create("BARRIER_HA_LUNS_FILES_READY_$cluster_name",      $num_nodes);
            barrier_create("BARRIER_HA_NONSS_FILES_SYNCED_$cluster_name",    $num_nodes);
        }
        else {
            barrier_create("BARRIER_HA_$cluster_name", $num_nodes + 1);
        }

        # Create barriers for HA clusters
        barrier_create("CLUSTER_INITIALIZED_$cluster_name",         $num_nodes);
        barrier_create("NODE_JOINED_$cluster_name",                 $num_nodes);
        barrier_create("DLM_INIT_$cluster_name",                    $num_nodes);
        barrier_create("DLM_GROUPS_CREATED_$cluster_name",          $num_nodes);
        barrier_create("DLM_CHECKED_$cluster_name",                 $num_nodes);
        barrier_create("DRBD_INIT_$cluster_name",                   $num_nodes);
        barrier_create("DRBD_CREATE_CONF_$cluster_name",            $num_nodes);
        barrier_create("DRBD_ACTIVATE_DEVICE_$cluster_name",        $num_nodes);
        barrier_create("DRBD_CREATE_DEVICE_$cluster_name",          $num_nodes);
        barrier_create("DRBD_CHECK_ONE_DONE_$cluster_name",         $num_nodes);
        barrier_create("DRBD_CHECK_TWO_DONE_$cluster_name",         $num_nodes);
        barrier_create("DRBD_DOWN_DONE_$cluster_name",              $num_nodes);
        barrier_create("DRBD_MIGRATION_DONE_$cluster_name",         $num_nodes);
        barrier_create("DRBD_REVERT_DONE_$cluster_name",            $num_nodes);
        barrier_create("DRBD_RESOURCE_CREATED_$cluster_name",       $num_nodes);
        barrier_create("DRBD_RESOURCE_RESTARTED_$cluster_name",     $num_nodes);
        barrier_create("DRBD_SETUP_DONE_$cluster_name",             $num_nodes);
        barrier_create("LOCK_INIT_$cluster_name",                   $num_nodes);
        barrier_create("LOCK_RESOURCE_CREATED_$cluster_name",       $num_nodes);
        barrier_create("LOGS_CHECKED_$cluster_name",                $num_nodes);
        barrier_create("CHECK_AFTER_REBOOT_BEGIN_$cluster_name",    $num_nodes);
        barrier_create("CHECK_AFTER_REBOOT_END_$cluster_name",      $num_nodes);
        barrier_create("CHECK_BEFORE_FENCING_BEGIN_$cluster_name",  $num_nodes);
        barrier_create("CHECK_BEFORE_FENCING_END_$cluster_name",    $num_nodes);
        barrier_create("CLUSTER_MD_INIT_$cluster_name",             $num_nodes);
        barrier_create("CLUSTER_MD_CREATED_$cluster_name",          $num_nodes);
        barrier_create("CLUSTER_MD_STARTED_$cluster_name",          $num_nodes);
        barrier_create("CLUSTER_MD_RESOURCE_CREATED_$cluster_name", $num_nodes);
        barrier_create("CLUSTER_MD_CHECKED_$cluster_name",          $num_nodes);
        barrier_create("HAWK_INIT_$cluster_name",                   $num_nodes);
        barrier_create("HAWK_CHECKED_$cluster_name",                $num_nodes);
        barrier_create("SLE11_UPGRADE_INIT_$cluster_name",          $num_nodes);
        barrier_create("SLE11_UPGRADE_START_$cluster_name",         $num_nodes);
        barrier_create("SLE11_UPGRADE_DONE_$cluster_name",          $num_nodes);
        barrier_create("HAPROXY_INIT_$cluster_name",                $num_nodes);
        barrier_create("HAPROXY_DONE_$cluster_name",                $num_nodes);
        barrier_create("REMOVE_NODE_BY_IP_INIT_$cluster_name",      $num_nodes);
        barrier_create("REMOVE_NODE_BY_IP_DONE_$cluster_name",      $num_nodes);
        barrier_create("REMOVE_NODE_BY_HOST_INIT_$cluster_name",    $num_nodes);
        barrier_create("REMOVE_NODE_BY_HOST_DONE_$cluster_name",    $num_nodes);
        barrier_create("JOIN_NODE_BY_HOST_DONE_$cluster_name",      $num_nodes);
        barrier_create("JOIN_NODE_BY_IP_DONE_$cluster_name",        $num_nodes);
        barrier_create("REMOVE_NODE_FINAL_JOIN_$cluster_name",      $num_nodes);
        barrier_create("RSC_REMOVE_INIT_$cluster_name",             $num_nodes);
        barrier_create("RSC_REMOVE_DONE_$cluster_name",             $num_nodes);
        barrier_create("CSYNC2_CONFIGURED_$cluster_name",           $num_nodes);
        barrier_create("CSYNC2_SYNC_$cluster_name",                 $num_nodes);
        barrier_create("SBD_DONE_$cluster_name",                    $num_nodes);
        barrier_create("SSH_KEY_CONFIGURED_$cluster_name",          $num_nodes);

        # PACEMAKER_TEST_ barriers also have to wait in the client
        barrier_create("PACEMAKER_CTS_INIT_$cluster_name",    $num_nodes + 1);
        barrier_create("PACEMAKER_CTS_CHECKED_$cluster_name", $num_nodes + 1);

        # HAWK_GUI_ barriers also have to wait in the client
        barrier_create("HAWK_GUI_INIT_$cluster_name",    $num_nodes + 1);
        barrier_create("HAWK_GUI_CHECKED_$cluster_name", $num_nodes + 1);
        barrier_create("HAWK_FENCE_$cluster_name",       $num_nodes + 1);

        # Create barriers for multiple tests
        foreach my $fs_tag ('LUN', 'CLUSTER_MD', 'DRBD_PASSIVE', 'DRBD_ACTIVE') {
            barrier_create("VG_INIT_${fs_tag}_$cluster_name",             $num_nodes);
            barrier_create("PV_VG_LV_CREATED_${fs_tag}_$cluster_name",    $num_nodes);
            barrier_create("VG_RESOURCE_CREATED_${fs_tag}_$cluster_name", $num_nodes);
            barrier_create("VG_RW_CHECKED_${fs_tag}_$cluster_name",       $num_nodes);
            barrier_create("VG_MD5SUM_${fs_tag}_$cluster_name",           $num_nodes);
            barrier_create("FS_INIT_${fs_tag}_$cluster_name",             $num_nodes);
            barrier_create("FS_MKFS_DONE_${fs_tag}_$cluster_name",        $num_nodes);
            barrier_create("FS_GROUP_ADDED_${fs_tag}_$cluster_name",      $num_nodes);
            barrier_create("FS_RESOURCE_STOPPED_${fs_tag}_$cluster_name", $num_nodes);
            barrier_create("FS_DATA_COPIED_${fs_tag}_$cluster_name",      $num_nodes);
            barrier_create("FS_CHECKED_${fs_tag}_$cluster_name",          $num_nodes);
        }

        # Create barriers for SAP cluster
        # Note: we always create these barries even if they are not used, mainly
        # because it's not easy to know at this stage that we are testing a SAP cluster...
        barrier_create("ASCS_INSTALLED_$cluster_name",       $num_nodes);
        barrier_create("ERS_INSTALLED_$cluster_name",        $num_nodes);
        barrier_create("NW_CLUSTER_HOSTS_$cluster_name",     $num_nodes);
        barrier_create("NW_CLUSTER_INSTALL_$cluster_name",   $num_nodes);
        barrier_create("NW_INIT_CONF_$cluster_name",         $num_nodes);
        barrier_create("NW_CREATED_CONF_$cluster_name",      $num_nodes);
        barrier_create("NW_LOADED_CONF_$cluster_name",       $num_nodes);
        barrier_create("NW_RA_RESTART_$cluster_name",        $num_nodes);
        barrier_create("HANA_CLUSTER_INSTALL_$cluster_name", $num_nodes);
        barrier_create("HANA_INIT_CONF_$cluster_name",       $num_nodes);
        barrier_create("HANA_CREATED_CONF_$cluster_name",    $num_nodes);
        barrier_create("HANA_LOADED_CONF_$cluster_name",     $num_nodes);
        barrier_create("HANA_RA_RESTART_$cluster_name",      $num_nodes);
    }

    # Wait for all children to start
    # Children are server/test suites that use the PARALLEL_WITH variable
    wait_for_children_to_start;

    # Finish early if running in node 1 instead of supportserver
    return if is_not_supportserver_scenario;

    # For getting informations from iSCSI server
    my $target_iqn     = script_output 'lio_node --listtargetnames 2>/dev/null';
    my $target_ip_port = script_output "ls /sys/kernel/config/target/iscsi/${target_iqn}/tpgt_1/np 2>/dev/null";
    my $dev_by_path    = '/dev/disk/by-path';
    my $index          = get_var('ISCSI_LUN_INDEX', 0);

    for my $cluster_info (split(/,/, $cluster_infos)) {
        # The CLUSTER_INFOS variable for support_server also contains the number of LUN
        my ($cluster_name, $num_nodes, $num_luns) = split(/:/, $cluster_info);

        # Export LUN name if needed
        if (defined $num_luns) {
            # Create a file that contains the list of LUN for each cluster
            my $lun_list_file = "/tmp/$cluster_name-lun.list";
            foreach my $i (0 .. ($num_luns - 1)) {
                my $lun_id = $i + $index;
                script_run "echo '${dev_by_path}/ip-${target_ip_port}-iscsi-${target_iqn}-lun-${lun_id}' >> $lun_list_file";
            }
            $index += $num_luns;
        }

        # Synchronize all nodes (including  the support server)
        barrier_wait("BARRIER_HA_$cluster_name");
    }
}

1;

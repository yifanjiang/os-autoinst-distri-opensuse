# SUSE's SLES4SAP openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure HANA-SR cluster
# Maintainer: Ricardo Branco <rbranco@suse.de>

use base "sles4sap";
use testapi;
use lockapi;
use hacluster;
use utils qw(systemctl file_content_replace);
use strict;
use warnings;

sub run {
    my ($self)       = @_;
    my $instance_id  = get_required_var('INSTANCE_ID');
    my $sid          = get_required_var('INSTANCE_SID');
    my $cluster_name = get_cluster_name;
    my ($virtual_ip, $virtual_netmask) = split '/', get_required_var('VIRTUAL_IP_CIDR');

    # Set SAP variables
    my $pscmd  = $self->set_ps_cmd("HDB");
    my $sapadm = $self->set_sap_info($sid, $instance_id);

    # Synchronize the nodes
    barrier_wait "HANA_CLUSTER_INSTALL_$cluster_name";

    $self->select_serial_terminal;

    # Create the resource configuration
    my $cluster_conf = 'hana_cluster.conf';
    assert_script_run "curl -f -v " . autoinst_url . "/data/sles4sap/$cluster_conf -o /tmp/$cluster_conf";
    $cluster_conf = "/tmp/" . $cluster_conf;

    # Initiate the template
    file_content_replace($cluster_conf, '--sed-modifier' => 'g',
        '%SID%'                => $sid,
        '%HDB_INSTANCE%'       => $instance_id,
        '%AUTOMATED_REGISTER%' => get_required_var('AUTOMATED_REGISTER'),
        '%VIRTUAL_IP_ADDRESS%' => $virtual_ip,
        '%VIRTUAL_IP_NETMASK%' => $virtual_netmask);

    # Avoid hostname change on reboot.  See bsc#1153402
    file_content_replace('/etc/sysconfig/network/dhcp', 'DHCLIENT_SET_HOSTNAME="yes"' => 'DHCLIENT_SET_HOSTNAME="no"');

    my $node1 = choose_node(1);
    my $node2 = choose_node(2);

    if (is_node(1)) {
        foreach ($node1, $node2) {
            add_to_known_hosts($_);
        }
        assert_script_run "scp -qr /usr/sap/$sid/SYS/global/security/rsecssfs/* root\@$node2:/usr/sap/$sid/SYS/global/security/rsecssfs/";
        my $password = get_required_var('PASSWORD');
        assert_script_run qq(su - $sapadm -c "hdbsql -u system -p $password -i $instance_id -d SYSTEMDB \\"BACKUP DATA FOR FULL SYSTEM USING FILE ('backup')\\""), 300;
        assert_script_run "su - $sapadm -c 'hdbnsutil -sr_enable --name=NODE1'";

        # Synchronize the nodes
        barrier_wait "HANA_INIT_CONF_$cluster_name";
        barrier_wait "HANA_CREATED_CONF_$cluster_name";

        # Upload the configuration into the cluster
        assert_script_run 'crm configure property maintenance-mode=true';
        assert_script_run "crm configure load update $cluster_conf";
        assert_script_run 'crm configure property maintenance-mode=false';
    }
    else {
        # Synchronize the nodes
        barrier_wait "HANA_INIT_CONF_$cluster_name";

        assert_script_run "su - $sapadm -c 'sapcontrol -nr $instance_id -function StopSystem HDB'";
        sleep 10;
        assert_script_run "su - $sapadm -c 'hdbnsutil -sr_register --remoteHost=$node1 -remoteInstance=$instance_id --replicationMode=sync --name=NODE2 --operationMode=logreplay'";
        assert_script_run "su - $sapadm -c 'sapcontrol -nr $instance_id -function StartSystem HDB'";
        sleep 10;

        # Synchronize the nodes
        barrier_wait "HANA_CREATED_CONF_$cluster_name";
    }

    # Synchronize the nodes
    barrier_wait "HANA_LOADED_CONF_$cluster_name";

    # Wait for resources to be started
    wait_until_resources_started(timeout => 300);

    # And check for the state of the whole cluster
    check_cluster_state;
}

1;

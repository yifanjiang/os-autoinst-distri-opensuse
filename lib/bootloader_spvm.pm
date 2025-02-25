=head1 bootloader_spvm

Library for spvm backend to boot and install SLES

=cut
# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package bootloader_spvm;

use base Exporter;
use Exporter;

use strict;
use warnings;

use testapi;
use bootloader_setup;
use registration 'registration_bootloader_params';
use utils qw(get_netboot_mirror type_string_slow);

our @EXPORT = qw(
  boot_spvm
);

=head2 get_into_net_boot

 get_into_net_boot();

Get into SMS menu for booting from net.

=cut
sub get_into_net_boot {
    assert_screen 'pvm-bootmenu';

    # 5.   Select Boot Options
    type_string "5\n";
    assert_screen 'pvm-bootmenu-boot-order';

    # 1.   Select Install/Boot Device
    type_string "1\n";
    assert_screen 'pvm-bootmenu-boot-device-type';

    # 4.   Network
    type_string "4\n";
    assert_screen 'pvm-bootmenu-boot-network-service';

    # 1.   BOOTP
    type_string "1\n";
    assert_screen 'pvm-bootmenu-boot-select-device';

    # primary disk
    type_string "1\n";
    assert_screen 'pvm-bootmenu-boot-mode';

    # 2.   Normal Mode Boot
    type_string "2\n";
    assert_screen 'pvm-bootmenu-boot-exit';

    type_string "1\n";
    assert_screen ["pvm-grub", "novalink-failed-first-boot"];
}

=head2 boot_spvm

 boot_spvm();

Boot from spvm backend via novalink and switch to installation console (ssh or vnc).

=cut
sub boot_spvm {
    my $lpar_id  = get_required_var('NOVALINK_LPAR_ID');
    my $novalink = select_console 'novalink-ssh';

    # detach possibly attached terminals - might be left over
    type_string "rmvterm --id $lpar_id && echo 'DONE'\n";
    assert_screen 'pvm-vterm-closed';

    # power off the machine if it's still running - and don't give it a 2nd chance
    type_string " pvmctl lpar power-off -i id=$lpar_id --hard\n";
    assert_screen [qw(pvm-poweroff-successful pvm-poweroff-not-running)], 180;

    # make sure that the default boot mode is 'Normal' and not 'System_Management_Services'
    # see https://progress.opensuse.org/issues/39785#note-14
    type_string " pvmctl lpar update -i id=$lpar_id --set-field LogicalPartition.bootmode=Normal && echo 'BOOTMODE_SET_TO_NORMAL'\n";
    assert_screen 'pvm-bootmode-set-normal';

    # proceed with normal boot if is system already installed, use sms boot for installation
    my $bootmode = get_var('BOOT_HDD_IMAGE') ? "norm" : "sms";
    type_string " pvmctl lpar power-on -i id=$lpar_id --bootmode ${bootmode}\n";
    assert_screen "pvm-poweron-successful";

    # don't wait for it, otherwise we miss the menu
    type_string " mkvterm --id $lpar_id\n";
    # skip installation if is system already installed
    return if get_var('BOOT_HDD_IMAGE');
    get_into_net_boot;

    # the grub on powerVM has a rather strange feature that it will boot
    # into the firmware if the lpar was reconfigured in between and the
    # first menu entry was used to enter the command line. So we need to
    # reset the LPAR manually
    if (match_has_tag('novalink-failed-first-boot')) {
        type_string "set-default ibm,fw-nbr-reboots\n";
        type_string "reset-all\n";
        assert_screen 'pvm-firmware-prompt';
        send_key '1';
        get_into_net_boot;
    }
    # try 3 times but wait a long time in between - if we're too eager
    # we end with ccc in the prompt
    send_key_until_needlematch('pvm-grub-command-line', 'c', 3, 5);

    # clear the prompt (and create an error) in case the above went wrong
    type_string "\n";

    my $repo     = get_required_var('REPO_0');
    my $mirror   = get_netboot_mirror;
    my $mntpoint = "mnt/openqa/repo/$repo/boot/ppc64le";
    assert_screen "pvm-grub-command-line-fresh-prompt", no_wait => 1;
    type_string_slow "linux $mntpoint/linux vga=normal install=$mirror ";
    bootmenu_default_params;
    bootmenu_network_source;
    specific_bootmenu_params;
    registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED);
    type_string_slow remote_install_bootmenu_params;
    type_string_slow "\n";

    assert_screen "pvm-grub-command-line-fresh-prompt", 180, no_wait => 1;    # kernel is downloaded while waiting
    type_string_slow "initrd $mntpoint/initrd\n";

    assert_screen "pvm-grub-command-line-fresh-prompt", 180, no_wait => 1;    # initrd is downloaded while waiting
    type_string "boot\n";
    save_screenshot;

    assert_screen("novalink-successful-first-boot", 120);
    assert_screen("run-yast-ssh",                   120);

    # Delete partition table before starting installation
    select_console('install-shell');
    foreach my $disk (split(',', get_var('DISK_DEVICES', 'sda'))) {
        script_run("wipefs -a /dev/$disk");
        # For cryptlvm+activate existing scenario, create empty enrypted partition
        create_encrypted_part("$disk") if get_var('ENCRYPT_ACTIVATE_EXISTING');
    }
    # Switch to installation console (ssh or vnc)
    select_console('installation');
    # We need to start installer only if it's pure ssh installation
    type_string("yast.ssh\n") if get_var('VIDEOMODE', '') =~ /ssh-x|text/;
    wait_still_screen;
}

1;

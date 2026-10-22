CompuLab interactive mwifiex RF test console

Run on the DUT:
    cd /opt/compulab/rf-test
    ./rf_test.py

Or from your host:
    ssh -t root@192.168.8.10 /opt/compulab/rf-test/rf_test.py

Preview commands without writing to the driver:
    ./rf_test.py --dry-run

Select a menu number for guided parameters, or type a procfs command directly.
Use docs to display the original README chapter, status for driver output,
stop to disable all TX/trigger modes, and quit to leave. All commands and
driver readbacks are recorded in rf-test.log next to the script.
Choose another adapter with --config /proc/mwlan/adapter1/config.

Before RF testing (run these commands as root on the DUT):

Use Ethernet for SSH; normal Wi-Fi cannot operate in RF mode. Disconnect
Wi-Fi and stop the uAP BSS before entering RF mode. If hostapd is running,
stop it and remember to restore it after testing:
    systemctl is-active hostapd
    # Only if active:
    systemctl stop hostapd

Release all Wi-Fi interfaces from NetworkManager and bring them down:
    for iface in wlan0 uap0 wfd0; do
        nmcli device set "$iface" managed no
        ip link set "$iface" down
    done

Check that all three interfaces are down:
    ip -br link show wlan0
    ip -br link show uap0
    ip -br link show wfd0

Start the console using one of the commands above, then enter
rf_test_mode=1 at its prompt. These preparation commands do not affect
the Ethernet interface used for SSH.

Example session (issue each line at the rf-test> prompt):
    rf_test_mode=1
    radio_mode=11 0
    tx_antenna=1
    rx_antenna=1
    band=0
    bw=0
    channel=6
    tx_power=16 2 0
    tx_continuous=1 1 0xAAA 0 3 7
    stop
    get_and_reset_per
    rf_test_mode=0
    quit

After RF testing:

At the rf-test> prompt, stop transmission and leave RF mode:
    stop
    rf_test_mode=0
    quit

The firmware must be reset before normal Wi-Fi can resume. The console
does not unload drivers or reset firmware. Rebooting the DUT performs the
reset and disconnects SSH:
    reboot

Reconnect over Ethernet after the DUT boots. Restore NetworkManager
control if needed (run as root on the DUT):
    for iface in wlan0 uap0 wfd0; do
        nmcli device set "$iface" managed yes
    done

If hostapd was active before testing and has not restarted after reboot:
    systemctl start hostapd

TX frame menu offers ax (22 arguments), legacy (15 arguments), or short
(4 arguments, as used in the README trigger transmission example). Stop
forms tx_frame=0, tx_continuous=0, he_tb_tx=0 and trigger_frame=0 are supported.
All 33 trigger frame fields can be entered through its guided menu.

The console writes commands directly to procfs, without a shell. Input is
checked against the documented enums and ranges. Rate indexes and radio
modes remain chipset dependent. Each successful write is followed by the
driver config readback; firmware rejection may also appear in dmesg.
An accepted procfs write does not prove that the chipset supports a command.

On quit, EOF, Ctrl-C or SIGTERM, the console attempts to stop TX/trigger
operations started in this session, then exits RF mode if entered here.
It does not take ownership of RF mode that was already active at startup.
Cleanup errors are printed. SIGKILL/power loss cannot run cleanup.
One console session per adapter is allowed.

README example corrections:
* The TX-frame examples have five-octet BSSIDs. Prompts require six octets.
* he_tb_tx example power 10 exceeds the stated -11..9 dBm range; default is 9.

Source: https://github.com/nxp-imx/mwifiex/blob/lf-6.18.20_2.0.0/README, section 6,
"FOR RF test mode commands:". RF_COMMANDS.txt is a verbatim copy of that
chapter at installation time. No RF writes were made during installation.

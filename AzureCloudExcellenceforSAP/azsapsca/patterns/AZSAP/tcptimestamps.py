#!/usr/bin/python3

# Title:       Check for tcp timestamp value
# Description: make sure tcp timestamp value is correct
# Modified:    2021 Nov 3
#
import os
import Core

META_CLASS = "AZSAP"
META_CATEGORY = "Kernel"
META_COMPONENT = "Network"
PATTERN_ID = os.path.basename(__file__)
PRIMARY_LINK = "META_LINK_TID"
OVERALL = Core.WARN
OVERALL_INFO = "NOT SET"
OTHER_LINKS = "META_LINK_TID=https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability#manual-deployment"

Core.init(META_CLASS, META_CATEGORY, META_COMPONENT, PATTERN_ID, PRIMARY_LINK, OVERALL, OVERALL_INFO, OTHER_LINKS)

try:
    fileOpen = "env.txt"
    section = "/sbin/sysctl -a"
    VALUE = -1
    content = {}

    if Core.getSection(fileOpen, section, content):
        for line in content:
            if "net.ipv4.tcp_timestamps" in content[line]:
                RP_LIST = content[line].split('=')
                VALUE = int(RP_LIST[1].strip())

    if (VALUE == 0):
        Core.updateStatus(Core.SUCC , "tcp_timestamps is correctly zero");
    else:
        Core.updateStatus(Core.CRIT, "tcp_timestamps should be zero");

except Exception as error:
        Core.updateStatus(Core.ERROR, "Outside the network scope: " + str(error))

Core.printPatternResults()
